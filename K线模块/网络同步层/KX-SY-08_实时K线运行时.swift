//
//  KX-SY-08_实时K线运行时.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：运行期只订阅 OKX public trades，用成交明细“增量”更新每个周期当前未闭合的最后一根 K线。
//        历史/已闭合 K线由 REST + DB 补齐链路负责，是死数据、永不重算；本文件绝不重新扫描历史窗口。
//  规则：每笔成交 O(周期数) 更新各周期“当前桶”；跨桶时闭合旧 K线一次、再开新桶。
//        <15m 只进内存；>=15m 闭合后由持久化链路落库；所有目标周期均通知 UI/跨模块监听者。
//

import Foundation

import os.log
import class os.OSLog

// 日志工具初始化
private let logger = klineLogger

public extension Notification.Name {
    static let KLRealtimeCandleUpdated = Notification.Name("KLRealtimeCandleUpdated")
}

public struct KLRealtimeCandleNotificationKey {
    public static let exchange = "exchange"
    public static let instrumentID = "instrumentID"
    public static let timeframe = "timeframe"
    public static let candle = "candle"
}

public struct KLRealtimeRuntimeSnapshot: Sendable, CustomStringConvertible {
    public let activeSymbol: String
    public let activeTimeframe: KXTimeframe
    public let hasWebSocket: Bool
    public let isConnecting: Bool
    public let tradeCount: Int
    public let cache1s: Int
    public let cache1m: Int
    public let cache5m: Int
    public let cache15m: Int

    public var description: String {
        "symbol=\(activeSymbol) timeframe=\(activeTimeframe.rawValue) ws=\(hasWebSocket) connecting=\(isConnecting) trades=\(tradeCount) cache{1s=\(cache1s),1m=\(cache1m),5m=\(cache5m),15m=\(cache15m)}"
    }
}

public final class KLOKXRealtimeKLineRuntime: @unchecked Sendable {
    public static let shared = KLOKXRealtimeKLineRuntime()

    private let queue = DispatchQueue(label: "com.xianren.kline.okx.trade-aggregation.runtime")
    private var ws: KLOKXDefaultWSExecutor?
    private var activeSymbol: String = "BTC-USDT"
    private var activeTimeframe: KXTimeframe = .oneHour
    private var openedSymbols: Set<String> = ["BTC-USDT"]
    private var subscribedTradeSymbols: Set<String> = []
    private var isConnecting = false
    private var tradeCount = 0
    /// 每个 (币对|周期) 当前正在跳动、尚未闭合的最后一根 K线。实时只更新这一根（O(周期数)）。
    private var currentCandles: [String: KLCandlePoint] = [:]
    /// 已闭合并已发布的 K线去重键，避免重复落库/通知。
    private var publishedClosedCandleKeys: Set<String> = []
    /// 每个 (币对|周期) 最近一次向 UI 推送未闭合 K线的时间，用于节流。
    private var lastNotifyAtByKey: [String: Date] = [:]
    private let aggregationScheduler = KXFN03KLineAggregationScheduler()

    private let memoryTimeframes: [KXTimeframe] = KLOKXTimeframePolicyCatalog.memoryOnlyTimeframes
    private let persistentTimeframes: [KXTimeframe] = KLOKXTimeframePolicyCatalog.persistentTimeframes

    private init() {}

    /// 开启/切换运行期成交聚合。
    /// 注意：历史K线补齐不在这里做，应由打开币对时的 DB/REST 启动恢复管道完成。
    public func start(symbol: String, timeframe: KXTimeframe) {
        queue.async { [weak self] in
            guard let self else { return }
            self.activeSymbol = symbol
            self.activeTimeframe = timeframe
            if self.ws == nil {
                self.createAndConnectLocked(symbol: symbol)
            } else {
                self.subscribeTradesLocked(symbol: symbol)
            }
        }
    }

    public func switchSubscription(symbol: String, timeframe: KXTimeframe) {
        start(symbol: symbol, timeframe: timeframe)
    }

    /// 面板当前打开的币对集合都要订阅 trades；用户可见币对只是 activeSymbol。
    public func setOpenedSymbols(_ symbols: [String], activeSymbol: String, activeTimeframe: KXTimeframe) {
        let normalized = Set(symbols.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        queue.async { [weak self] in
            guard let self else { return }
            self.openedSymbols = normalized.isEmpty ? [activeSymbol] : normalized
            self.activeSymbol = activeSymbol
            self.activeTimeframe = activeTimeframe
            if self.ws == nil {
                self.createAndConnectLocked(symbol: activeSymbol)
            } else {
                self.subscribeOpenedTradesLocked()
            }
            logger.info("opened symbols=\(Array(self.openedSymbols).sorted().joined(separator: ",")) active=\(activeSymbol) timeframe=\(activeTimeframe.rawValue)")
        }
    }

    /// 多画布改造：关闭某币对（该币对最后一个画布都关了）时发退订信号。
    /// 聚合器从此不再收该币对成交，也就不再为它算 K线。其他币对不受影响。
    /// 注意：聚合器是按币对订阅 trades（不分周期），所以只有该币对全部周期画布都关闭才应调本方法。
    public func unsubscribe(symbol rawSymbol: String) {
        let symbol = rawSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !symbol.isEmpty else { return }
        queue.async { [weak self] in
            guard let self else { return }
            self.openedSymbols.remove(symbol)
            let wasSubscribed = self.subscribedTradeSymbols.remove(symbol) != nil
            // 清掉该币对所有周期的在进行桶 / 闭合去重键 / 节流记录（key 前缀 "symbol|"）。
            let prefix = "\(symbol)|"
            for key in self.currentCandles.keys where key.hasPrefix(prefix) { self.currentCandles.removeValue(forKey: key) }
            for key in self.publishedClosedCandleKeys where key.hasPrefix(prefix) { self.publishedClosedCandleKeys.remove(key) }
            for key in self.lastNotifyAtByKey.keys where key.hasPrefix(prefix) { self.lastNotifyAtByKey.removeValue(forKey: key) }
            // 给 OKX 发 trades 退订帧。
            if wasSubscribed, let ws = self.ws {
                Task.detached(priority: .userInitiated) { [weak ws] in
                    do {
                        try await ws?.unsubscribe(channel: "trades", instID: symbol)
                        logger.info("unsubscribe channel=trades instID=\(symbol)")
                    } catch {
                        logger.error("unsubscribe trades failed instID=\(symbol): \(error.localizedDescription)")
                    }
                }
            }
            logger.info("unsubscribed symbol=\(symbol) remaining=\(Array(self.openedSymbols).sorted().joined(separator: ","))")
        }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.ws?.disconnect()
            self?.ws = nil
            self?.isConnecting = false
            self?.subscribedTradeSymbols.removeAll()
            self?.tradeCount = 0
            self?.currentCandles.removeAll()
            self?.lastNotifyAtByKey.removeAll()
            self?.publishedClosedCandleKeys.removeAll()
            logger.info("realtime runtime stopped")
        }
    }

    public func snapshot() -> KLRealtimeRuntimeSnapshot {
        queue.sync {
            KLRealtimeRuntimeSnapshot(
                activeSymbol: activeSymbol,
                activeTimeframe: activeTimeframe,
                hasWebSocket: ws != nil,
                isConnecting: isConnecting,
                tradeCount: tradeCount,
                cache1s: KLLowTimeframeCache.shared.count(exchange: "OKX", instrumentID: activeSymbol, timeframe: .oneSecond),
                cache1m: KLLowTimeframeCache.shared.count(exchange: "OKX", instrumentID: activeSymbol, timeframe: .oneMinute),
                cache5m: KLLowTimeframeCache.shared.count(exchange: "OKX", instrumentID: activeSymbol, timeframe: .fiveMinutes),
                cache15m: KLLowTimeframeCache.shared.count(exchange: "OKX", instrumentID: activeSymbol, timeframe: .fifteenMinutes)
            )
        }
    }

    public func logSnapshot(reason: String) {
        let snap = snapshot()
        logger.info("reason=\(reason) \(snap)")
    }

    private func createAndConnectLocked(symbol: String) {
        guard !isConnecting else { return }
        isConnecting = true

        // OKX trades 属于 public WS，不在 business WS。
        let publicConfig = KLOKXWSConfig(
            baseURL: "wss://ws.okx.com:8443/ws/v5/public",
            apiKey: "",
            secretKey: "",
            passphrase: "",
            reconnectDelay: 2.0
        )
        let executor = KLOKXDefaultWSExecutor(config: publicConfig)
        executor.onMessage = { [weak self] data in
            self?.handleMessage(data)
        }
        executor.onConnected = { [weak self] in
            self?.queue.async {
                self?.isConnecting = false
                if let self {
                    logger.info("public trades WS connected symbols=\(Array(self.openedSymbols).sorted().joined(separator: ","))")
                    self.subscribeOpenedTradesLocked()
                }
            }
        }
        executor.onDisconnected = { [weak self] error in
            self?.queue.async { self?.isConnecting = false }
            if let error {
                logger.error("public trades WS disconnected: \(error.localizedDescription)")
            }
        }
        ws = executor

        Task.detached(priority: .userInitiated) { [weak executor, weak self] in
            do {
                try await executor?.connect()
            } catch {
                self?.queue.async { self?.isConnecting = false }
                logger.error("public trades WS connect failed: \(error.localizedDescription)")
            }
        }
    }

    private func subscribeTradesLocked(symbol: String) {
        openedSymbols.insert(symbol)
        subscribeOpenedTradesLocked()
    }

    private func subscribeOpenedTradesLocked() {
        guard let ws else {
            createAndConnectLocked(symbol: activeSymbol)
            return
        }
        let symbols = Array(openedSymbols.subtracting(subscribedTradeSymbols)).sorted()
        guard !symbols.isEmpty else { return }
        for symbol in symbols { subscribedTradeSymbols.insert(symbol) }
        let subscriptions = symbols.map { KLOKXWSSubscription(channel: "trades", instID: $0) }
        Task.detached(priority: .userInitiated) { [weak ws, weak self] in
            logger.info("subscribe batch channel=trades instIDs=\(symbols.joined(separator: ","))")
            do {
                try await ws?.subscribeMultiple(subscriptions)
            } catch {
                self?.queue.async {
                    for symbol in symbols { self?.subscribedTradeSymbols.remove(symbol) }
                }
                logger.error("subscribe trades batch failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleMessage(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let event = object["event"] as? String {
            if event == "subscribe" || event == "error" {
                logger.debug("ws event: \(object)")
            }
            return
        }
        guard let arg = object["arg"] as? [String: Any],
              let channel = arg["channel"] as? String,
              channel == "trades",
              let instID = arg["instId"] as? String,
              let rows = object["data"] as? [[String: Any]] else { return }

        let trades = rows.compactMap { parseTradeTick($0, symbol: instID) }
        guard !trades.isEmpty else { return }

        queue.async { [weak self] in
            guard let self else { return }
            self.tradeCount += trades.count
            if self.tradeCount <= 10 || self.tradeCount % 1000 == 0 {
                logger.info("recv trades instID=\(instID) batch=\(trades.count) total=\(self.tradeCount)")
            }
            self.processTradesLocked(trades, symbol: instID)
        }
    }

    private func parseTradeTick(_ row: [String: Any], symbol: String) -> KLTradeTick? {
        guard let tradeID = stringValue(row["tradeId"] ?? row["tradeID"]),
              let pxText = stringValue(row["px"]), let price = Decimal(string: pxText),
              let szText = stringValue(row["sz"]), let size = Decimal(string: szText),
              let tsText = stringValue(row["ts"]), let ts = Double(tsText) else { return nil }
        let sideText = stringValue(row["side"]) ?? "unknown"
        let side = KLTradeSide(rawValue: sideText) ?? .unknown
        return KLTradeTick(symbol: symbol, tradeID: tradeID, price: price, size: size, side: side, timestamp: Date(timeIntervalSince1970: ts / 1000))
    }

    private func stringValue(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        if let i = value as? Int { return String(i) }
        if let d = value as? Double { return String(d) }
        return nil
    }

    private func processTradesLocked(_ trades: [KLTradeTick], symbol: String) {
        // 增量聚合：每笔成交只更新“每个周期当前未闭合的那一根”K线（O(周期数)）。
        // 已闭合的历史 K线是死数据，永不重算；这里绝不重新扫描历史窗口。
        let sorted = trades.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
            return lhs.tradeID < rhs.tradeID
        }
        let allTimeframes = memoryTimeframes + persistentTimeframes
        for trade in sorted {
            for tf in allTimeframes {
                applyTradeToCurrentCandleLocked(trade, symbol: symbol, timeframe: tf)
            }
        }

        // 把每个周期当前未闭合 K线推给 UI（按 key 节流，避免高频成交时刷爆主线程）。
        let now = Date()
        for tf in allTimeframes {
            let key = currentCandleKey(symbol: symbol, timeframe: tf)
            guard let candle = currentCandles[key] else { continue }
            let last = lastNotifyAtByKey[key] ?? .distantPast
            if now.timeIntervalSince(last) >= 0.15 {
                lastNotifyAtByKey[key] = now
                persistAndNotifyLocked(candle, exchange: "OKX", instrumentID: symbol, timeframe: tf)
            }
        }

        if tradeCount <= 10 || tradeCount % 1000 == 0 {
            let c1s = KLLowTimeframeCache.shared.count(exchange: "OKX", instrumentID: symbol, timeframe: .oneSecond)
            let c1m = KLLowTimeframeCache.shared.count(exchange: "OKX", instrumentID: symbol, timeframe: .oneMinute)
            let c5m = KLLowTimeframeCache.shared.count(exchange: "OKX", instrumentID: symbol, timeframe: .fiveMinutes)
            let c15m = KLLowTimeframeCache.shared.count(exchange: "OKX", instrumentID: symbol, timeframe: .fifteenMinutes)
            logger.info("cache instID=\(symbol) 1s=\(c1s) 1m=\(c1m) 5m=\(c5m) 15m=\(c15m)")
        }
    }

    private func currentCandleKey(symbol: String, timeframe: KXTimeframe) -> String {
        "\(symbol)|\(timeframe.rawValue)"
    }

    /// 用单笔成交增量更新指定周期“当前未闭合 K线”。跨桶时先闭合旧 K线再开新 K线。
    private func applyTradeToCurrentCandleLocked(_ trade: KLTradeTick, symbol: String, timeframe: KXTimeframe) {
        let bucketOpen = bucketOpenTime(for: trade.timestamp, timeframe: timeframe)
        let key = currentCandleKey(symbol: symbol, timeframe: timeframe)

        guard let current = currentCandles[key] else {
            currentCandles[key] = makeFreshCandle(symbol: symbol, timeframe: timeframe, bucketOpen: bucketOpen, trade: trade)
            return
        }

        if current.openTime == bucketOpen {
            // 同一根：只更新 high/low/close/volume，O(1)。
            currentCandles[key] = KLCandlePoint(
                id: current.id,
                symbol: symbol,
                timeframe: timeframe,
                openTime: bucketOpen,
                closeTime: nil,
                open: current.open,
                high: max(current.high, trade.price),
                low: min(current.low, trade.price),
                close: trade.price,
                volume: current.volume + trade.size,
                quoteVolume: (current.quoteVolume ?? 0) + trade.price * trade.size,
                tradeCount: (current.tradeCount ?? 0) + 1,
                isClosed: false,
                source: "OKX trades runtime"
            )
        } else if bucketOpen > current.openTime {
            // 进入新桶：先闭合旧 K线（只发布一次），再开当前桶。
            let closed = KLCandlePoint(
                id: current.id,
                symbol: symbol,
                timeframe: timeframe,
                openTime: current.openTime,
                closeTime: bucketCloseTime(for: current.openTime, timeframe: timeframe),
                open: current.open,
                high: current.high,
                low: current.low,
                close: current.close,
                volume: current.volume,
                quoteVolume: current.quoteVolume,
                tradeCount: current.tradeCount,
                isClosed: true,
                source: "OKX trades runtime closed"
            )
            if markClosedCandleIfNeeded(exchange: "OKX", instrumentID: symbol, timeframe: timeframe, openTime: current.openTime) {
                persistAndNotifyLocked(closed, exchange: "OKX", instrumentID: symbol, timeframe: timeframe)
                if tradeCount <= 10 || tradeCount % 1000 == 0 {
                    logger.info("closed instID=\(symbol) tf=\(timeframe.rawValue) open=\(closed.openTime) close=\(closed.close)")
                }
            }
            currentCandles[key] = makeFreshCandle(symbol: symbol, timeframe: timeframe, bucketOpen: bucketOpen, trade: trade)
        }
        // bucketOpen < current.openTime：迟到的过期成交，忽略。
    }

    private func makeFreshCandle(symbol: String, timeframe: KXTimeframe, bucketOpen: Date, trade: KLTradeTick) -> KLCandlePoint {
        KLCandlePoint(
            id: "okx:\(symbol):\(timeframe.rawValue):\(Int(bucketOpen.timeIntervalSince1970))",
            symbol: symbol,
            timeframe: timeframe,
            openTime: bucketOpen,
            closeTime: nil,
            open: trade.price,
            high: trade.price,
            low: trade.price,
            close: trade.price,
            volume: trade.size,
            quoteVolume: trade.price * trade.size,
            tradeCount: 1,
            isClosed: false,
            source: "OKX trades runtime"
        )
    }

    private func bucketOpenTime(for date: Date, timeframe: KXTimeframe) -> Date {
        if let seconds = KXFN02TimeframeManager.seconds(for: timeframe), seconds > 0 {
            return Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / Double(seconds)) * Double(seconds))
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        switch timeframe {
        case .oneMonth:
            let comps = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: comps) ?? date
        case .threeMonths:
            let comps = calendar.dateComponents([.year, .month], from: date)
            let month = comps.month ?? 1
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            return calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: comps.year, month: quarterStartMonth, day: 1)) ?? date
        default:
            return Date(timeIntervalSince1970: floor(date.timeIntervalSince1970))
        }
    }

    private func bucketCloseTime(for openTime: Date, timeframe: KXTimeframe) -> Date? {
        if let seconds = KXFN02TimeframeManager.seconds(for: timeframe), seconds > 0 {
            return openTime.addingTimeInterval(TimeInterval(seconds))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        switch timeframe {
        case .oneMonth:
            return calendar.date(byAdding: .month, value: 1, to: openTime)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: 3, to: openTime)
        default:
            return nil
        }
    }

    private func markClosedCandleIfNeeded(exchange: String, instrumentID: String, timeframe: KXTimeframe, openTime: Date) -> Bool {
        let key = "\(exchange)|\(instrumentID)|\(timeframe.rawValue)|\(Int(openTime.timeIntervalSince1970))"
        if publishedClosedCandleKeys.contains(key) { return false }
        publishedClosedCandleKeys.insert(key)
        if publishedClosedCandleKeys.count > 200_000 {
            publishedClosedCandleKeys = Set(publishedClosedCandleKeys.suffix(100_000))
        }
        return true
    }

    private func persistAndNotifyLocked(_ candle: KLCandlePoint, exchange: String, instrumentID: String, timeframe: KXTimeframe) {
        if KLOKXTimeframePolicyCatalog.isMemoryOnly(timeframe) {
            KLLowTimeframeCache.shared.upsert(candles: [candle], exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
        } else {
            // 持久化周期禁止由 trades 实时聚合结果写库。
            // trades 聚合只包含程序启动后收到的成交，可能缺少该周期前半段成交；若写库会污染官方 REST K线的 open/volume。
            // 持久化周期的数据库权威来源只能是 OKX REST candles；实时结果只用于当前图表跳动。
            KLLowTimeframeCache.shared.upsert(candles: [candle], exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
        }

        // 所有已打开币对、所有目标周期都通知 UI。
        // UI 层自行按当前 symbol/timeframe 过滤；这样用户切换任意币对/周期时，
        // 对应周期的最后一根未闭合 K线已经在内存中持续跳动，不会只让 activeTimeframe 有实时刷新。
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .KLRealtimeCandleUpdated,
                object: nil,
                userInfo: [
                    KLRealtimeCandleNotificationKey.exchange: exchange,
                    KLRealtimeCandleNotificationKey.instrumentID: instrumentID,
                    KLRealtimeCandleNotificationKey.timeframe: timeframe,
                    KLRealtimeCandleNotificationKey.candle: candle
                ]
            )
        }
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXSY08Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-SY-08", fileName: "KX-SY-08_实时K线运行时.swift", layer: .sync,
        relativePath: "网络同步层/KX-SY-08_实时K线运行时.swift", duty: "实时K线运行时"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("实时K线运行时骨架校验通过")
        return KXHealthCheckItem(name: "实时K线运行时", passed: true, message: "已实现OKX实时成交聚合与多周期K线生成")
    }
}
