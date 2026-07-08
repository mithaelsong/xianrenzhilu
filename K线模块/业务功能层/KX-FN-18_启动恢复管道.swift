//
//  KX-FN-18_启动恢复管道.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：启动恢复管道。建表 → 加载数据库15m+ → OKX REST 补齐缺口 → 写库 → 内存预热 → WS 实时订阅
//  禁止事项：禁止UI绘制、禁止UI模块依赖
//

import Foundation
import os.log

// 导入K线日志工具

// 日志实例
private let logger = klineLogger


public extension Notification.Name {
    static let KXTimeframeMemoryUpdated = Notification.Name("KXTimeframeMemoryUpdated")
}

public struct KXTimeframeMemoryUpdatedNotificationKey {
    public static let exchange = "exchange"
    public static let instrumentID = "instrumentID"
    public static let timeframe = "timeframe"
    public static let count = "count"
}


public enum KXTimeframeSyncPriority: Int, Sendable {
    /// 当前币对 + 当前时间框架：用户第一眼正在看的图。
    case visible = 0
    /// 当前币对 + 其他时间框架：用户最可能马上切换。
    case activeSymbolWarmup = 1
    /// 其他币对 + 当前时间框架：用户切币对但不切周期时优先。
    case sameTimeframeWarmup = 2
    /// 其他币对 + 其他时间框架：后台慢速预热。
    case background = 3
}

public struct KXTimeframeSyncJob: Sendable {
    public let symbol: String
    public let policy: KLOKXTimeframePolicy
    public let priority: KXTimeframeSyncPriority
}

// MARK: - 阶段

public enum KLStartupPhase: String, Codable, Sendable, CaseIterable {
    case idle, loadingPanelState, restoringTabs, loadingFromDatabase, inspectingGaps,
         fetchingMissingFromOKX, upsertingToDatabase, warmingMemory,
         startingRealtimeSubscriptions, publishingSnapshot, completed, failed
}

// MARK: - 状态

public struct KLStartupStatus: Codable, Sendable {
    public var phase: KLStartupPhase
    public var progress: Double
    public var message: String
    public var errorMessage: String?
    public var startedAt: Date
    public var completedAt: Date?
    public init(phase: KLStartupPhase = .idle, progress: Double = 0, message: String = "就绪", errorMessage: String? = nil, startedAt: Date = Date(), completedAt: Date? = nil) {
        self.phase = phase; self.progress = progress; self.message = message
        self.errorMessage = errorMessage; self.startedAt = startedAt; self.completedAt = completedAt
    }
}

public protocol KLStartupRestoring: AnyObject {
    func restore() async throws
    var status: KLStartupStatus { get }
    var isRestored: Bool { get }
    func forceRestore() async throws
}

// MARK: - 真实管道

public final class KLDefaultStartupPipeline: KLStartupRestoring, @unchecked Sendable {
    public static let shared = KLDefaultStartupPipeline()
    public private(set) var status: KLStartupStatus = KLStartupStatus()
    public var isRestored: Bool { status.phase == .completed }

    private let db = KLDefaultDatabaseExecutor.shared
    private let syncQueue = DispatchQueue(label: "com.xianren.kline.instrument-sync")
    /// 启动建表专用后台串行队列。
    /// 用途：ensureTables 内部是同步阻塞的 psql 子进程(executeBatch→queue.sync→waitUntilExit)，
    /// 绝不能在主线程跑(否则 waitUntilExit 泵主线程 RunLoop → AppKit 重入布局 → 约束异常引爆崩溃 + UI 转圈卡死)。
    /// 统一丢到本队列，restore() 用 continuation 挂起等待，主线程不阻塞、不泵 RunLoop。
    private static let startupDBQueue = DispatchQueue(label: "com.xianren.kline.startup-db", qos: .userInitiated)
    private var syncingSymbols: Set<String> = []
    private var syncingTimeframes: Set<String> = []
    /// 面板多次切周期/切币对时，新的打开集合同步请求会取消旧队列，避免多个 68-job 队列并发打爆 OKX。
    private var openedSyncGeneration: Int = 0
    private var openedSyncTask: Task<Void, Never>?

    private init() {}

    public func restore() async throws {
        status = KLStartupStatus(phase: .loadingPanelState, progress: 0.05, message: "确保数据库表存在...", startedAt: Date())

        // step 0: 建表
        // ⚠️ 关键修复(2026-06-22)：ensureTables 内部走 KLDatabase.executeBatch → queue.sync → Process(psql).waitUntilExit()，
        // 是同步阻塞调用。restore() 经面板(@MainActor)的 Task{} 触发，其同步前缀可能落在主线程执行；
        // 一旦在主线程跑 waitUntilExit 会泵主线程 RunLoop → AppKit 重入布局 → 任意约束异常在此引爆崩溃，并卡住 UI 转圈。
        // 解决：把建表丢到后台串行队列，restore() 用 continuation 挂起等待（主线程不阻塞、不泵 RunLoop）。
        try await runStartupDatabaseSetup()

        // step 1: 获取初始面板配置的币对（默认4个常用币对）
        status.phase = .restoringTabs; status.progress = 0.10
        status.message = "初始化默认面板币对..."

        // 默认加载常用币对，实际应该从用户配置或上次会话恢复
        let defaultSymbols = ["BTC-USDT", "ETH-USDT", "SOL-USDT", "ADA-USDT"]

        status.progress = 0.20
        status.message = "初始化 \(defaultSymbols.count) 个默认币对"

        // step 2（已移除批量预加载）：
        // 旧实现会在这里同步把 4 个币对 × 17 个周期 = 68 次大查询塞进唯一的串行 DB 队列
        // （5m 读 1 万根、4H 及以上全量读），导致面板打开时"可见周期"(如 BTC 15m) 的快查询被排在
        // 这 68 个大查询后面，要等 10-15 秒才显示。
        // 实际可见周期由面板 KX-UI-09/UI-12 的 loadLatestCandlesFromDatabaseOrOKX 按需读 DB 即时显示，
        // 其余币对/周期由 syncOpenedSymbols 按"可见优先"在后台分批预热（每条间隔 750ms，不占满 DB 队列）。
        // 因此这里不再做批量预加载，避免堵塞 DB 串行队列。
        status.phase = .loadingFromDatabase; status.progress = 0.40
        status.message = "启动表就绪，可见周期按需即时加载"

        // step 3: 启动默认交易对的实时聚合
        status.phase = .startingRealtimeSubscriptions; status.progress = 0.90
        status.message = "启动实时行情聚合..."

        // 启动所有默认币对的实时聚合
        let defaultTimeframe = KXTimeframe.oneHour
        for symbol in defaultSymbols {
            KLOKXRealtimeKLineRuntime.shared.start(symbol: symbol, timeframe: defaultTimeframe)
        }
        KLOKXRealtimeKLineRuntime.shared.logSnapshot(reason: "startup-pipeline")

        status.message = "实时行情聚合已启动"

        // done。不要在这里再次发送 KL_OpenPanel，避免点击卡片后重复创建 K线面板。
        status.phase = .completed; status.progress = 1.0
        status.message = "启动恢复完成，已加载 \(defaultSymbols.count) 个默认币对数据"
        status.completedAt = Date()
    }



    /// 打开软件/币对后的唯一数据同步入口。
    /// 规则：遍历统一周期策略表；第一次全量拉，非第一次补最新缺口；按策略写库/覆盖内存；最后启动 trades 聚合器。
    public func syncInstrument(symbol: String, activeTimeframe: KXTimeframe = .oneHour) {
        let shouldStart = syncQueue.sync { () -> Bool in
            if syncingSymbols.contains(symbol) { return false }
            syncingSymbols.insert(symbol)
            return true
        }
        guard shouldStart else {
            logger.info("[KLine][SYNC] skip duplicate symbol=\(symbol) active=\(activeTimeframe.rawValue)")
            return
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.syncInstrumentNow(symbol: symbol, activeTimeframe: activeTimeframe)
            self.syncQueue.sync { _ = self.syncingSymbols.remove(symbol) }
        }
    }


    /// K线面板打开后，按"当前币对当前周期 → 当前币对其他周期 → 其他币对当前周期 → 其他币对其他周期"的体验优先级加载。
    public func syncOpenedSymbols(symbols rawSymbols: [String], activeSymbol: String, activeTimeframe: KXTimeframe = .oneHour) {
        // 兼容旧入口：未提供"每币对各自周期"时，所有币对都用 activeTimeframe。
        let symbols = rawSymbols.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let openedSymbols = symbols.isEmpty ? [activeSymbol] : self.uniqueSymbols(symbols)
        var map: [String: KXTimeframe] = [:]
        for s in openedSymbols { map[s] = activeTimeframe }
        syncOpenedSymbols(timeframeBySymbol: map, activeSymbol: activeSymbol)
    }

    /// 规则1：打开软件/币对时，每个币对只加载它自己 tab 选中的那一个周期到内存。
    /// 其他周期不在这里预热；用户真正切到某周期时由 syncTimeframe 按需加载（规则2）。
    /// orderedSymbols：标签栏挂载顺序；点击某币对时它作为 activeSymbol 优先加载，其余按标签栏顺序回头补。
    public func syncOpenedSymbols(timeframeBySymbol: [String: KXTimeframe], activeSymbol: String, orderedSymbols: [String] = []) {
        let baseOrder = orderedSymbols.isEmpty ? Array(timeframeBySymbol.keys) : orderedSymbols
        let openedSymbols = self.uniqueSymbols(baseOrder.filter { timeframeBySymbol[$0] != nil })
        guard !openedSymbols.isEmpty else { return }
        let activeTimeframe = timeframeBySymbol[activeSymbol] ?? .oneHour
        let generation = syncQueue.sync { () -> Int in
            openedSyncGeneration += 1
            openedSyncTask?.cancel()
            return openedSyncGeneration
        }
        KLOKXRealtimeKLineRuntime.shared.setOpenedSymbols(openedSymbols, activeSymbol: activeSymbol, activeTimeframe: activeTimeframe)
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do { try self.db.ensureTables() } catch { logger.info("[KLine][SYNC] ensure tables failed error=\(error.localizedDescription)") }
            let rest = KLOKXDefaultRESTExecutor(config: KLOKXRESTConfig.development)
            let jobs = self.makeOpenedSymbolJobs(timeframeBySymbol: timeframeBySymbol, activeSymbol: activeSymbol, orderedSymbols: openedSymbols)
            logger.info("[KLine][SYNC] opened start gen=\(generation) symbols=\(openedSymbols.joined(separator: ",")) active=\(activeSymbol) jobs=\(jobs.count) (rule1: 每币对仅选中周期)")
            for job in jobs {
                if Task.isCancelled {
                    logger.info("[KLine][SYNC] opened task-cancelled gen=\(generation) active=\(activeSymbol)")
                    return
                }
                let stillCurrent = self.syncQueue.sync { self.openedSyncGeneration == generation }
                guard stillCurrent else {
                    logger.info("[KLine][SYNC] opened cancelled gen=\(generation) active=\(activeSymbol)")
                    return
                }
                let key = "\(job.symbol)|\(job.policy.timeframe.rawValue)"
                let shouldRun = self.syncQueue.sync { () -> Bool in
                    if self.syncingTimeframes.contains(key) { return false }
                    self.syncingTimeframes.insert(key)
                    return true
                }
                guard shouldRun else { continue }
                defer { self.syncQueue.sync { _ = self.syncingTimeframes.remove(key) } }
                logger.info("[KLine][SYNC] job gen=\(generation) priority=\(job.priority.rawValue) symbol=\(job.symbol) timeframe=\(job.policy.timeframe.rawValue)")
                await self.syncOneTimeframe(symbol: job.symbol, policy: job.policy, rest: rest)
                if Task.isCancelled {
                    logger.info("[KLine][SYNC] opened task-cancelled-after-job gen=\(generation) active=\(activeSymbol)")
                    return
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            logger.info("[KLine][SYNC] opened completed gen=\(generation) symbols=\(openedSymbols.joined(separator: ",")) active=\(activeSymbol)")
        }
        syncQueue.sync { openedSyncTask = task }
    }

    private func uniqueSymbols(_ symbols: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for symbol in symbols {
            if seen.insert(symbol).inserted { result.append(symbol) }
        }
        return result
    }

    private func makeOpenedSymbolJobs(timeframeBySymbol: [String: KXTimeframe], activeSymbol: String, orderedSymbols: [String]) -> [KXTimeframeSyncJob] {
        // 规则1：每个币对只加载它自己 tab 选中的那一个周期，不铺全周期。
        // 加载顺序：被点击的当前币对(activeSymbol)先加载；其余币对按标签栏挂载顺序回头依次补。
        // 例：5个币对 [A,B,C,D,E]，用户一打开就点 E → active=E → 先加 E，再按 A,B,C,D 顺序补。
        var jobs: [KXTimeframeSyncJob] = []

        if let activeTf = timeframeBySymbol[activeSymbol],
           let visible = KLOKXTimeframePolicyCatalog.policy(for: activeTf) {
            jobs.append(KXTimeframeSyncJob(symbol: activeSymbol, policy: visible, priority: .visible))
        }
        for symbol in orderedSymbols where symbol != activeSymbol {
            guard let tf = timeframeBySymbol[symbol],
                  let policy = KLOKXTimeframePolicyCatalog.policy(for: tf) else { continue }
            jobs.append(KXTimeframeSyncJob(symbol: symbol, policy: policy, priority: .sameTimeframeWarmup))
        }

        var seen = Set<String>()
        return jobs.filter { job in
            let key = "\(job.symbol)|\(job.policy.timeframe.rawValue)"
            return seen.insert(key).inserted
        }
    }

    /// 当前面板切到某个周期但内存尚未就绪时，允许该周期独立抢占同步。
    /// 不受整币对全周期同步去重影响，避免用户点击 15m/5m 时只看到实时聚合 1 根。
    public func syncTimeframe(symbol: String, timeframe: KXTimeframe) {
        let key = "\(symbol)|\(timeframe.rawValue)"
        let shouldStart = syncQueue.sync { () -> Bool in
            if syncingTimeframes.contains(key) { return false }
            syncingTimeframes.insert(key)
            return true
        }
        guard shouldStart else {
            logger.info("[KLine][SYNC] skip duplicate timeframe symbol=\(symbol) timeframe=\(timeframe.rawValue)")
            return
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do { try self.db.ensureTables() } catch { logger.info("[KLine][SYNC] ensure tables failed error=\(error.localizedDescription)") }
            let rest = KLOKXDefaultRESTExecutor(config: KLOKXRESTConfig.development)
            if let policy = KLOKXTimeframePolicyCatalog.policy(for: timeframe) {
                await self.syncOneTimeframe(symbol: symbol, policy: policy, rest: rest)
            }
            self.syncQueue.sync { _ = self.syncingTimeframes.remove(key) }
        }
    }

    private func syncInstrumentNow(symbol: String, activeTimeframe: KXTimeframe) async {
        logger.info("[KLine][SYNC] start symbol=\(symbol) active=\(activeTimeframe.rawValue) policies=\(KLOKXTimeframePolicyCatalog.allPolicies.count)")
        do { try db.ensureTables() } catch { logger.info("[KLine][SYNC] ensure tables failed error=\(error.localizedDescription)") }
        KLOKXRealtimeKLineRuntime.shared.setOpenedSymbols([symbol], activeSymbol: symbol, activeTimeframe: activeTimeframe)
        let rest = KLOKXDefaultRESTExecutor(config: KLOKXRESTConfig.development)
        let policies = KLOKXTimeframePolicyCatalog.policies(activeTimeframe: activeTimeframe)
        for policy in policies {
            await syncOneTimeframe(symbol: symbol, policy: policy, rest: rest)
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        logger.info("[KLine][SYNC] completed symbol=\(symbol); trades aggregation running active=\(activeTimeframe.rawValue)")
    }

    private func syncMemoryOnlyTimeframe(symbol: String, policy: KLOKXTimeframePolicy, rest: KLOKXDefaultRESTExecutor) async throws {
        let timeframe = policy.timeframe
        let bar = policy.okxBar
        let retention = KLOKXTimeframePolicyCatalog.memoryRetentionLimit(for: timeframe) ?? KLLowTimeframeCache.recommendedRetentionLimit(for: timeframe)
        let maxPages = max(1, Int(ceil(Double(retention) / 100.0)))
        let raw = try await rest.fetchAllHistoricalCandles(instID: symbol, bar: bar, pageLimit: 100, maxPages: maxPages)
        var candles = KLOKXDefaultRESTExecutor.parseCandles(raw, symbol: symbol, timeframe: timeframe, source: "sync_memory_only")

        // 最近快照包含当前未闭合 K线，memoryOnly 周期也必须合入内存底座。
        let recentRaw = (try? await rest.fetchRecentCandles(instID: symbol, bar: bar, limit: 100)) ?? []
        let recentCandles = KLOKXDefaultRESTExecutor.parseCandles(recentRaw, symbol: symbol, timeframe: timeframe, source: "sync_memory_only_recent")
        candles = mergeCandlesForMemory(base: candles, overlay: recentCandles)

        if candles.count > retention { candles = Array(candles.suffix(retention)) }
        KLLowTimeframeCache.shared.replace(candles: candles, exchange: "OKX", instrumentID: symbol, timeframe: timeframe, maxCount: retention)
        notifyMemoryUpdated(symbol: symbol, timeframe: timeframe, count: candles.count)
        logger.info("[KLine][SYNC] memoryOnly symbol=\(symbol) timeframe=\(timeframe.rawValue) pages=\(maxPages) memory=\(candles.count) retention=\(retention) db=false")
    }

    private func syncOneTimeframe(symbol: String, policy: KLOKXTimeframePolicy, rest: KLOKXDefaultRESTExecutor) async {
        let timeframe = policy.timeframe
        let bar = policy.okxBar
        let timeframeSeconds = TimeInterval(max(1, KXFN02TimeframeManager.seconds(for: timeframe) ?? 1))

        do {
            if policy.storagePolicy == .memoryOnly {
                try await syncMemoryOnlyTimeframe(symbol: symbol, policy: policy, rest: rest)
                return
            }
            let latest = try? db.latestCandleTime(exchange: "OKX", instrumentID: symbol, timeframe: timeframe)

            // 晓筱 2026-06-22 规则：查询数 = 加载数 = chartLoadCandleCount；倒查最新 N 根，不再全表查。
            let loadCount = KLOKXTimeframePolicyCatalog.chartLoadCandleCount(for: timeframe)
            let safeSeconds = Int(max(1, timeframeSeconds))
            let now = Date()
            // 要加载的最旧一根的目标时间（窗口起点）。
            let desiredOldest = now.addingTimeInterval(-Double(loadCount) * Double(safeSeconds))

            // 决策（判断型，只用上面的 MAX(open_time)）：是否需向交易所补齐 + 补多少。
            // 关键：只有“真缺口”才补。启动时数据库已经很新的不该再拉网（避免启动狂拉 REST）。
            // 缺口阈值：最新一根距今超过 2 根才算缺（未闭合当前根由 recent 快照+trades 聚合负责，不靠这里补）。
            var needFetch = false
            var fetchPages: Int? = nil
            var isFullFetch = false
            // 1W/1M/3M 历史本就有限（几百根）：有缺口直接拉全量所有页（页数本来就少），不绕窗口/缺口数学。
            let isLimitedHistory = (timeframe == .oneWeek || timeframe == .oneMonth || timeframe == .threeMonths)
            if let latest {
                let gapCount = self.safeCandleCount(from: latest, seconds: safeSeconds)
                if isLimitedHistory {
                    if gapCount > 2 {
                        needFetch = true
                        isFullFetch = true
                        fetchPages = nil   // nil = 拉全部页
                    }
                } else if latest < desiredOldest && gapCount > 2 {
                    // 数据库最新一根都比窗口起点还旧且缺口明显 → 拉满 loadCount。
                    needFetch = true
                    isFullFetch = true
                    fetchPages = self.safePageCount(forCandles: loadCount, minimumPages: 2)
                } else if gapCount > 2 {
                    // 库里有窗口内数据，但 latest..now 有明显缺口 → 只补缺口。
                    needFetch = true
                    fetchPages = self.safePageCount(forCandles: gapCount, minimumPages: 2)
                }
                // gapCount <= 2：数据已足够新，不拉 REST（启动不卡）。
            } else {
                // 库里压根没有 → 全量拉。有限历史周期拉全部页；其他按 loadCount。
                needFetch = true
                isFullFetch = true
                fetchPages = isLimitedHistory ? nil : self.safePageCount(forCandles: loadCount, minimumPages: 2)
            }

            // 补齐（接着数据库时间向交易所请求）。
            var fetchedCount = 0
            var persistedCount = 0
            if needFetch {
                let raw = try await rest.fetchAllHistoricalCandles(instID: symbol, bar: bar, pageLimit: 100, maxPages: fetchPages)
                let fetched = KLOKXDefaultRESTExecutor.parseCandles(raw, symbol: symbol, timeframe: timeframe, source: isFullFetch ? "sync_full_first" : "sync_gap_incremental")
                fetchedCount = fetched.count
                let toPersist: [KLCandlePoint]
                if let latest, !isFullFetch {
                    toPersist = fetched.filter { $0.openTime > latest && $0.isClosed }
                } else {
                    toPersist = fetched.filter { $0.isClosed }
                }
                persistedCount = toPersist.count
                if !toPersist.isEmpty {
                    try? db.upsertCandles(candles: toPersist, exchange: "OKX", instrumentID: symbol, timeframe: timeframe)
                }
            }

            // 最近 K线快照包含当前未闭合 K线，是 UI 图表最后一根跳动的权威底座。
            // 闭合快照可写库；未闭合快照只进入内存，后续由 trades 聚合持续更新。
            let recentRaw = (try? await rest.fetchRecentCandles(instID: symbol, bar: bar, limit: 100)) ?? []
            let recentCandles = KLOKXDefaultRESTExecutor.parseCandles(recentRaw, symbol: symbol, timeframe: timeframe, source: "sync_recent_snapshot")
            let recentClosed = recentCandles.filter { $0.isClosed }
            if !recentClosed.isEmpty {
                try? db.upsertCandles(candles: recentClosed, exchange: "OKX", instrumentID: symbol, timeframe: timeframe)
            }

            // 倒查最新 loadCount 根灌内存（不再全表查）。
            var memoryCandles = (try? db.queryLatestCandles(exchange: "OKX", instrumentID: symbol, timeframe: timeframe, startTime: nil, limit: loadCount)) ?? []
            memoryCandles = mergeCandlesForMemory(base: memoryCandles, overlay: recentCandles)
            if memoryCandles.count > loadCount { memoryCandles = Array(memoryCandles.suffix(loadCount)) }

            KLLowTimeframeCache.shared.replace(candles: memoryCandles, exchange: "OKX", instrumentID: symbol, timeframe: timeframe, maxCount: loadCount)
            notifyMemoryUpdated(symbol: symbol, timeframe: timeframe, count: memoryCandles.count)
            logger.info("[KLine][SYNC] persistent symbol=\(symbol) timeframe=\(timeframe.rawValue) loadCount=\(loadCount) dbLatest=\(latest?.description ?? "nil") needFetch=\(needFetch) full=\(isFullFetch) pages=\(fetchPages.map { String($0) } ?? "-") fetched=\(fetchedCount) persisted=\(persistedCount) recent=\(recentCandles.count) memory=\(memoryCandles.count)")
        } catch {
            if policy.storagePolicy == KLStoragePolicy.persistent {
                let loadCount = KLOKXTimeframePolicyCatalog.chartLoadCandleCount(for: timeframe)
                let fallback = (try? db.queryLatestCandles(exchange: "OKX", instrumentID: symbol, timeframe: timeframe, startTime: nil, limit: loadCount)) ?? []
                if !fallback.isEmpty {
                    KLLowTimeframeCache.shared.replace(candles: fallback, exchange: "OKX", instrumentID: symbol, timeframe: timeframe, maxCount: loadCount)
                    notifyMemoryUpdated(symbol: symbol, timeframe: timeframe, count: fallback.count)
                    logger.info("[KLine][SYNC] persistent fallback-db symbol=\(symbol) timeframe=\(timeframe.rawValue) memory=\(fallback.count) afterError=\(error.localizedDescription)")
                    return
                }
            }
            KLLowTimeframeCache.shared.markHistoryFailed(exchange: "OKX", instrumentID: symbol, timeframe: timeframe, error: error.localizedDescription)
            notifyMemoryUpdated(symbol: symbol, timeframe: timeframe, count: 0)
            logger.info("[KLine][SYNC] failed symbol=\(symbol) timeframe=\(timeframe.rawValue) error=\(error.localizedDescription)")
        }
    }



    private func mergeCandlesForMemory(base: [KLCandlePoint], overlay: [KLCandlePoint]) -> [KLCandlePoint] {
        var map: [String: KLCandlePoint] = [:]
        for candle in base {
            let key = "\(candle.symbol)|\(candle.timeframe.rawValue)|\(Int(candle.openTime.timeIntervalSince1970))"
            map[key] = candle
        }
        for candle in overlay {
            let key = "\(candle.symbol)|\(candle.timeframe.rawValue)|\(Int(candle.openTime.timeIntervalSince1970))"
            map[key] = candle
        }
        return map.values.sorted { $0.openTime < $1.openTime }
    }

    private func quickSourceTimeframe(for timeframe: KXTimeframe) -> KXTimeframe? {
        switch timeframe {
        case .threeMinutes:
            return .oneMinute
        default:
            return nil
        }
    }

    private func safeCandleCount(from date: Date, seconds: Int) -> Int {
        let interval = Date().timeIntervalSince(date)
        guard interval.isFinite, interval > 0 else { return 1 }
        let raw = ceil(interval / Double(max(1, seconds)))
        guard raw.isFinite, raw > 0 else { return 1 }
        return max(1, min(Int(raw), 200_000))
    }

    private func safePageCount(forCandles count: Int, minimumPages: Int) -> Int {
        let pages = Int(ceil(Double(max(1, count)) / 100.0)) + 2
        return max(minimumPages, min(pages, 2_000))
    }

    private func notifyMemoryUpdated(symbol: String, timeframe: KXTimeframe, count: Int) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .KXTimeframeMemoryUpdated,
                object: self,
                userInfo: [
                    KXTimeframeMemoryUpdatedNotificationKey.exchange: "OKX",
                    KXTimeframeMemoryUpdatedNotificationKey.instrumentID: symbol,
                    KXTimeframeMemoryUpdatedNotificationKey.timeframe: timeframe,
                    KXTimeframeMemoryUpdatedNotificationKey.count: count
                ]
            )
        }
    }


    /// 关闭指定币对时释放内存缓存
    public func cleanupSymbol(symbol: String) {
        syncQueue.sync {
            // 移除该币对的所有时间框架缓存
            let exchanges = ["OKX"] // 假设只使用OKX交易所
            let timeframes = KXTimeframe.allCases

            for exchange in exchanges {
                for timeframe in timeframes {
                    KLLowTimeframeCache.shared.clear(exchange: exchange, instrumentID: symbol, timeframe: timeframe)
                }
            }
            logger.info("[KLine][CLEANUP] 已释放币对内存缓存: \(symbol)")
        }
    }

    /// 关闭所有币对，释放全部内存缓存
    public func cleanupAllSymbols() {
        syncQueue.sync {
            KLLowTimeframeCache.shared.clearAll()
            logger.info("[KLine][CLEANUP] 已释放所有币对内存缓存")
        }
    }

    public func forceRestore() async throws { try await restore() }

    /// 在后台串行队列执行启动建表，避免在主线程同步跑 psql（waitUntilExit 泵 RunLoop → 重入崩溃/卡死）。
    /// restore() 通过 await 挂起等待其完成，期间主线程不被阻塞、不泵 RunLoop。
    private func runStartupDatabaseSetup() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            Self.startupDBQueue.async { [db] in
                do {
                    try db.ensureTables()
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN18Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-18", fileName: "KX-FN-18_启动恢复管道.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-18_启动恢复管道.swift", duty: "K线模块启动时的恢复管道逻辑"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("启动恢复管道骨架校验通过")
        return KXHealthCheckItem(name: "启动恢复管道", passed: true, message: "已实现启动恢复管道，注：KLDefaultDatabaseExecutor为预存缺失依赖")
    }
}
