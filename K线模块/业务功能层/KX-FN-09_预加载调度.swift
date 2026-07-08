//
//  KX-FN-09_预加载调度.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：按滚动方向生成预加载请求和缓存预热计划
//  禁止事项：禁止真实数据库写入、禁止直接网络请求
//

import Foundation


// MARK: - K线预加载调度模型

/// 滚动方向：只描述调度意图，不绑定任何 UI 手势实现。
public enum KXFN09ScrollDirection: String, Codable, Sendable, CaseIterable {
    /// 向左查看更早 K线。
    case left
    /// 向右查看更新 K线。
    case right
    /// 首次进入或主动预热时，两侧都生成候选计划。
    case both
    /// 无滚动意图；默认不生成请求。
    case none
}

/// 预加载侧向。
public enum KXFN09PreloadSide: String, Codable, Sendable, CaseIterable {
    /// 当前窗口左侧，更早的数据。
    case earlier
    /// 当前窗口右侧，更新的数据。
    case later
}

/// 被过滤掉的候选计划原因，用于验收"缓存命中不请求、重复请求不请求"。
public enum KXFN09SkippedPreloadReason: String, Codable, Sendable, CaseIterable {
    case invalidWindow
    case zeroBufferCount
    case cacheHit
    case duplicateInInput
    case duplicateInBatch
    case limitedByMaxRequestCount
}

/// 预加载配置。
///
/// 说明：最终预加载根数 = max(visibleCount * bufferRatio 向上取整, fixedBufferCount, minimumBufferCount)，
/// 再受 maximumCandlesPerRequest 上限约束。
public struct KXFN09PreloadConfiguration: Codable, Equatable, Sendable {
    public let bufferRatio: Double
    public let fixedBufferCount: Int?
    public let minimumBufferCount: Int
    public let maximumCandlesPerRequest: Int?
    public let maximumRequestCount: Int?
    public let includeUnclosed: Bool

    public init(
        bufferRatio: Double = 0.5,
        fixedBufferCount: Int? = nil,
        minimumBufferCount: Int = 20,
        maximumCandlesPerRequest: Int? = 300,
        maximumRequestCount: Int? = nil,
        includeUnclosed: Bool = true
    ) {
        self.bufferRatio = bufferRatio.isFinite ? max(0, bufferRatio) : 0
        self.fixedBufferCount = fixedBufferCount.map { max(0, $0) }
        self.minimumBufferCount = max(0, minimumBufferCount)
        self.maximumCandlesPerRequest = maximumCandlesPerRequest.map { max(0, $0) }
        self.maximumRequestCount = maximumRequestCount.map { max(0, $0) }
        self.includeUnclosed = includeUnclosed
    }

    public static let `default` = KXFN09PreloadConfiguration()
}

/// 已缓存覆盖范围描述。
///
/// 本结构只是"外部传入的缓存覆盖事实"，本文件不会读取、写入或持有真实缓存。
public struct KXFN09CacheCoverageRange: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let indexRange: KLIndexRange?
    public let timeRange: KLTimeRange?
    public let quality: KLDataQuality

    public init(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        indexRange: KLIndexRange? = nil,
        timeRange: KLTimeRange? = nil,
        quality: KLDataQuality = .unknown
    ) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.indexRange = indexRange
        self.timeRange = timeRange
        self.quality = quality
    }

    public func fullyCovers(symbol: KXSymbol, timeframe: KXTimeframe, indexRange: KLIndexRange, timeRange: KLTimeRange?) -> Bool {
        guard self.symbol == symbol, self.timeframe == timeframe else { return false }
        guard quality != .invalid else { return false }

        if let cachedIndexRange = self.indexRange {
            let coversIndex = cachedIndexRange.startIndex <= indexRange.startIndex && cachedIndexRange.endIndex >= indexRange.endIndex
            if coversIndex { return true }
        }

        if let cachedTimeRange = self.timeRange, let timeRange {
            return cachedTimeRange.startTime <= timeRange.startTime && cachedTimeRange.endTime >= timeRange.endTime
        }

        return false
    }
}

/// 已知缺数据片段。只用于标记"应该触发补洞"，不执行补洞。
public struct KXFN09MissingDataSegment: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let indexRange: KLIndexRange?
    public let timeRange: KLTimeRange?
    public let reason: String?

    public init(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        indexRange: KLIndexRange? = nil,
        timeRange: KLTimeRange? = nil,
        reason: String? = nil
    ) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.indexRange = indexRange
        self.timeRange = timeRange
        self.reason = reason
    }

    public func intersects(symbol: KXSymbol, timeframe: KXTimeframe, indexRange: KLIndexRange, timeRange: KLTimeRange?) -> Bool {
        guard self.symbol == symbol, self.timeframe == timeframe else { return false }

        if let missingIndexRange = self.indexRange, Self.intersects(lhs: missingIndexRange, rhs: indexRange) {
            return true
        }

        if let missingTimeRange = self.timeRange, let timeRange, Self.intersects(lhs: missingTimeRange, rhs: timeRange) {
            return true
        }

        return false
    }

    private static func intersects(lhs: KLIndexRange, rhs: KLIndexRange) -> Bool {
        lhs.startIndex <= rhs.endIndex && rhs.startIndex <= lhs.endIndex
    }

    private static func intersects(lhs: KLTimeRange, rhs: KLTimeRange) -> Bool {
        lhs.startTime < rhs.endTime && rhs.startTime < lhs.endTime
    }
}

/// 单条预加载请求计划。
///
/// query 是供后续数据层/同步层消费的描述；本文件不执行 query。
public struct KXFN09PreloadRequestPlan: Codable, Equatable, Sendable {
    public let id: String
    public let side: KXFN09PreloadSide
    public let query: KLKLineQuery
    public let indexRange: KLIndexRange
    public let timeRange: KLTimeRange?
    public let cacheKey: KLCacheKey
    public let deduplicationKey: String
    public let requestedCandleCount: Int
    public let shouldTriggerBackfill: Bool
    public let backfillGaps: [KLGapRange]
    public let reason: String

    public init(
        id: String,
        side: KXFN09PreloadSide,
        query: KLKLineQuery,
        indexRange: KLIndexRange,
        timeRange: KLTimeRange?,
        cacheKey: KLCacheKey,
        deduplicationKey: String,
        requestedCandleCount: Int,
        shouldTriggerBackfill: Bool,
        backfillGaps: [KLGapRange],
        reason: String
    ) {
        self.id = id
        self.side = side
        self.query = query
        self.indexRange = indexRange
        self.timeRange = timeRange
        self.cacheKey = cacheKey
        self.deduplicationKey = deduplicationKey
        self.requestedCandleCount = max(0, requestedCandleCount)
        self.shouldTriggerBackfill = shouldTriggerBackfill
        self.backfillGaps = backfillGaps
        self.reason = reason
    }
}

/// 批量预加载调度结果。
public struct KXFN09PreloadBatchPlan: Codable, Equatable, Sendable {
    public let requests: [KXFN09PreloadRequestPlan]
    public let skippedReasons: [KXFN09SkippedPreloadReason: Int]
    public let generatedAt: Date
    public let direction: KXFN09ScrollDirection
    public let bufferCandleCount: Int
    public let visibleCandleCount: Int

    public init(
        requests: [KXFN09PreloadRequestPlan],
        skippedReasons: [KXFN09SkippedPreloadReason: Int] = [:],
        generatedAt: Date = Date(),
        direction: KXFN09ScrollDirection,
        bufferCandleCount: Int,
        visibleCandleCount: Int
    ) {
        self.requests = requests
        self.skippedReasons = skippedReasons.filter { $0.value > 0 }
        self.generatedAt = generatedAt
        self.direction = direction
        self.bufferCandleCount = max(0, bufferCandleCount)
        self.visibleCandleCount = max(0, visibleCandleCount)
    }

    public var shouldTriggerBackfill: Bool {
        requests.contains { $0.shouldTriggerBackfill }
    }
}

// MARK: - K线预加载调度骨架与实现

public struct KXFN09Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-09",
        fileName: "KX-FN-09_K线预加载调度.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-09_K线预加载调度.swift",
        duty: "按滚动方向生成预加载请求和缓存预热计划"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "K线预加载调度", passed: true, message: "已实现按可视窗口、滚动方向、缓冲比例/数量生成纯调度计划；不访问数据库、网络、UI 或真实缓存")
    }

    public static func placeholder() {
        // 本文件已实现：根据当前可视窗口、滚动方向、缓冲比例/数量生成前后预加载请求计划。
        // 禁止行为保持不变：不查询数据库、不请求 OKX、不绘制 UI、不实现真实缓存、不执行补洞。
    }
}

/// K线预加载纯调度器。
public struct KXFN09PreloadScheduler: Sendable {
    public init() {}

    /// 生成预加载计划。
    ///
    /// - Parameters:
    ///   - window: 当前可视窗口。
    ///   - direction: 滚动方向。left 只生成更早数据，right 只生成更新数据，both 双向预热。
    ///   - configuration: 缓冲比例/固定数量/请求上限配置。
    ///   - cacheCoverage: 外部传入的已缓存覆盖范围；命中时不生成请求。
    ///   - existingRequestKeys: 外部传入的已在途请求去重键；命中时不生成重复请求。
    ///   - missingSegments: 外部传入的缺数据片段；命中时只标记触发补洞，不执行补洞。
    ///   - generatedAt: 生成时间，测试可传固定值。
    public static func makePreloadPlan(
        window: KLVisibleWindow,
        direction: KXFN09ScrollDirection,
        configuration: KXFN09PreloadConfiguration = .default,
        cacheCoverage: [KXFN09CacheCoverageRange] = [],
        existingRequestKeys: Set<String> = [],
        missingSegments: [KXFN09MissingDataSegment] = [],
        generatedAt: Date = Date()
    ) -> KXFN09PreloadBatchPlan {
        guard isValid(window: window) else {
            return KXFN09PreloadBatchPlan(
                requests: [],
                skippedReasons: [.invalidWindow: 1],
                generatedAt: generatedAt,
                direction: direction,
                bufferCandleCount: 0,
                visibleCandleCount: 0
            )
        }

        let visibleCount = visibleCandleCount(in: window)
        let bufferCount = bufferCandleCount(visibleCandleCount: visibleCount, configuration: configuration)
        guard bufferCount > 0 else {
            return KXFN09PreloadBatchPlan(
                requests: [],
                skippedReasons: [.zeroBufferCount: 1],
                generatedAt: generatedAt,
                direction: direction,
                bufferCandleCount: 0,
                visibleCandleCount: visibleCount
            )
        }

        let sides = preloadSides(for: direction)
        var requests: [KXFN09PreloadRequestPlan] = []
        var skipped: [KXFN09SkippedPreloadReason: Int] = [:]
        var batchKeys = Set<String>()

        for side in sides {
            let candidate = makeCandidate(
                window: window,
                side: side,
                candleCount: bufferCount,
                includeUnclosed: configuration.includeUnclosed,
                missingSegments: missingSegments
            )

            if cacheCoverage.contains(where: { $0.fullyCovers(symbol: window.symbol, timeframe: window.timeframe, indexRange: candidate.indexRange, timeRange: candidate.timeRange) }) {
                increment(&skipped, reason: .cacheHit)
                continue
            }

            if existingRequestKeys.contains(candidate.deduplicationKey) {
                increment(&skipped, reason: .duplicateInInput)
                continue
            }

            guard batchKeys.insert(candidate.deduplicationKey).inserted else {
                increment(&skipped, reason: .duplicateInBatch)
                continue
            }

            if let limit = configuration.maximumRequestCount, requests.count >= limit {
                increment(&skipped, reason: .limitedByMaxRequestCount)
                continue
            }

            requests.append(candidate)
        }

        return KXFN09PreloadBatchPlan(
            requests: requests,
            skippedReasons: skipped,
            generatedAt: generatedAt,
            direction: direction,
            bufferCandleCount: bufferCount,
            visibleCandleCount: visibleCount
        )
    }

    public func makePreloadPlan(
        window: KLVisibleWindow,
        direction: KXFN09ScrollDirection,
        configuration: KXFN09PreloadConfiguration = .default,
        cacheCoverage: [KXFN09CacheCoverageRange] = [],
        existingRequestKeys: Set<String> = [],
        missingSegments: [KXFN09MissingDataSegment] = [],
        generatedAt: Date = Date()
    ) -> KXFN09PreloadBatchPlan {
        Self.makePreloadPlan(
            window: window,
            direction: direction,
            configuration: configuration,
            cacheCoverage: cacheCoverage,
            existingRequestKeys: existingRequestKeys,
            missingSegments: missingSegments,
            generatedAt: generatedAt
        )
    }

    /// 计算最终缓冲 K线数量，便于单元测试直接验收缓冲比例与数量。
    public static func bufferCandleCount(visibleCandleCount: Int, configuration: KXFN09PreloadConfiguration) -> Int {
        let visible = max(0, visibleCandleCount)
        let ratioCount = Int(ceil(Double(visible) * configuration.bufferRatio))
        let fixedCount = configuration.fixedBufferCount ?? 0
        var result = max(ratioCount, fixedCount, configuration.minimumBufferCount)

        if let maximum = configuration.maximumCandlesPerRequest {
            result = min(result, maximum)
        }

        return max(0, result)
    }

    /// 生成请求去重键。格式稳定，不依赖 Swift Hash 随机化。
    public static func deduplicationKey(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        side: KXFN09PreloadSide,
        indexRange: KLIndexRange,
        timeRange: KLTimeRange?
    ) -> String {
        let timePart: String
        if let timeRange {
            timePart = "\(millisecondsString(timeRange.startTime))-\(millisecondsString(timeRange.endTime))"
        } else {
            timePart = "no-time"
        }

        return [
            symbol,
            timeframe.rawValue,
            side.rawValue,
            "idx:\(indexRange.startIndex)-\(indexRange.endIndex)",
            "time:\(timePart)"
        ].joined(separator: "|")
    }
}

// MARK: - 内部计算辅助

private extension KXFN09PreloadScheduler {
    static func isValid(window: KLVisibleWindow) -> Bool {
        let symbol = window.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !symbol.isEmpty else { return false }
        guard window.indexRange.startIndex <= window.indexRange.endIndex else { return false }
        guard window.candleWidth.isFinite, window.candleWidth > 0 else { return false }
        guard window.viewportWidth.isFinite, window.viewportWidth >= 0 else { return false }
        guard window.viewportHeight.isFinite, window.viewportHeight >= 0 else { return false }

        if let timeRange = window.timeRange {
            guard timeRange.startTime <= timeRange.endTime else { return false }
        }

        return true
    }

    static func visibleCandleCount(in window: KLVisibleWindow) -> Int {
        max(0, window.indexRange.endIndex - window.indexRange.startIndex + 1)
    }

    static func preloadSides(for direction: KXFN09ScrollDirection) -> [KXFN09PreloadSide] {
        switch direction {
        case .left:
            return [.earlier]
        case .right:
            return [.later]
        case .both:
            return [.earlier, .later]
        case .none:
            return []
        }
    }

    static func makeCandidate(
        window: KLVisibleWindow,
        side: KXFN09PreloadSide,
        candleCount: Int,
        includeUnclosed: Bool,
        missingSegments: [KXFN09MissingDataSegment]
    ) -> KXFN09PreloadRequestPlan {
        let indexRange = preloadIndexRange(window: window, side: side, candleCount: candleCount)
        let timeRange = preloadTimeRange(window: window, side: side, candleCount: candleCount)
        let query = KLKLineQuery(
            symbol: window.symbol,
            timeframe: window.timeframe,
            startTime: timeRange?.startTime,
            endTime: timeRange?.endTime,
            limit: candleCount,
            order: side == .earlier ? .descending : .ascending,
            includeUnclosed: includeUnclosed
        )
        let variant = "preload:\(side.rawValue):idx:\(indexRange.startIndex)-\(indexRange.endIndex)"
        let cacheKey = KLCacheKey(
            namespace: .candles,
            symbol: window.symbol,
            timeframe: window.timeframe,
            startTime: timeRange?.startTime,
            endTime: timeRange?.endTime,
            variant: variant
        )
        let key = deduplicationKey(
            symbol: window.symbol,
            timeframe: window.timeframe,
            side: side,
            indexRange: indexRange,
            timeRange: timeRange
        )
        let intersectedMissingSegments = missingSegments.filter {
            $0.intersects(symbol: window.symbol, timeframe: window.timeframe, indexRange: indexRange, timeRange: timeRange)
        }
        let gaps = makeBackfillGaps(
            symbol: window.symbol,
            timeframe: window.timeframe,
            fallbackTimeRange: timeRange,
            fallbackCount: candleCount,
            missingSegments: intersectedMissingSegments
        )

        return KXFN09PreloadRequestPlan(
            id: "klfn09_\(stableIDComponent(from: key))",
            side: side,
            query: query,
            indexRange: indexRange,
            timeRange: timeRange,
            cacheKey: cacheKey,
            deduplicationKey: key,
            requestedCandleCount: candleCount,
            shouldTriggerBackfill: !intersectedMissingSegments.isEmpty,
            backfillGaps: gaps,
            reason: reasonText(side: side, hasMissingData: !intersectedMissingSegments.isEmpty)
        )
    }

    static func preloadIndexRange(window: KLVisibleWindow, side: KXFN09PreloadSide, candleCount: Int) -> KLIndexRange {
        let count = max(0, candleCount)
        switch side {
        case .earlier:
            return KLIndexRange(
                startIndex: window.indexRange.startIndex - count,
                endIndex: window.indexRange.startIndex - 1
            )
        case .later:
            return KLIndexRange(
                startIndex: window.indexRange.endIndex + 1,
                endIndex: window.indexRange.endIndex + count
            )
        }
    }

    static func preloadTimeRange(window: KLVisibleWindow, side: KXFN09PreloadSide, candleCount: Int) -> KLTimeRange? {
        guard let visibleTimeRange = window.timeRange else { return nil }
        let count = max(0, candleCount)

        switch side {
        case .earlier:
            guard let start = shiftedDate(visibleTimeRange.startTime, timeframe: window.timeframe, steps: -count) else { return nil }
            return KLTimeRange(startTime: start, endTime: visibleTimeRange.startTime)
        case .later:
            guard let start = shiftedDate(visibleTimeRange.endTime, timeframe: window.timeframe, steps: 1),
                  let end = shiftedDate(visibleTimeRange.endTime, timeframe: window.timeframe, steps: count + 1) else { return nil }
            return KLTimeRange(startTime: start, endTime: end)
        }
    }

    static func makeBackfillGaps(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        fallbackTimeRange: KLTimeRange?,
        fallbackCount: Int,
        missingSegments: [KXFN09MissingDataSegment]
    ) -> [KLGapRange] {
        guard !missingSegments.isEmpty else { return [] }

        var gaps: [KLGapRange] = []
        var seen = Set<String>()

        for segment in missingSegments {
            let range = segment.timeRange ?? fallbackTimeRange
            guard let range else { continue }

            let expectedCount = max(1, estimatedCandleCount(timeRange: range, timeframe: timeframe) ?? fallbackCount)
            let gap = KLGapRange(
                symbol: symbol,
                timeframe: timeframe,
                startTime: range.startTime,
                endTime: range.endTime,
                expectedCount: expectedCount,
                actualCount: 0,
                reason: segment.reason ?? "preload_detected_missing_segment"
            )
            let key = "\(millisecondsString(gap.startTime))-\(millisecondsString(gap.endTime))-\(gap.reason ?? "")"
            if seen.insert(key).inserted {
                gaps.append(gap)
            }
        }

        return gaps
    }

    static func estimatedCandleCount(timeRange: KLTimeRange, timeframe: KXTimeframe) -> Int? {
        guard timeRange.startTime < timeRange.endTime else { return nil }

        if let seconds = fixedSeconds(for: timeframe), seconds > 0 {
            let duration = timeRange.endTime.timeIntervalSince(timeRange.startTime)
            guard duration.isFinite, duration > 0 else { return nil }
            return max(1, Int(ceil(duration / Double(seconds))))
        }

        var count = 0
        var cursor = timeRange.startTime
        while cursor < timeRange.endTime, count < 100_000 {
            guard let next = shiftedDate(cursor, timeframe: timeframe, steps: 1), next > cursor else { return nil }
            cursor = next
            count += 1
        }
        return max(1, count)
    }

    static func shiftedDate(_ date: Date, timeframe: KXTimeframe, steps: Int) -> Date? {
        guard steps != 0 else { return date }

        if let seconds = fixedSeconds(for: timeframe) {
            return date.addingTimeInterval(TimeInterval(seconds * steps))
        }

        switch timeframe {
        case .oneMonth:
            return Calendar(identifier: .gregorian).date(byAdding: .month, value: steps, to: date)
        default:
            return nil
        }
    }

    static func fixedSeconds(for timeframe: KXTimeframe) -> Int? {
        switch timeframe {
        case .oneSecond:
            return 1
        case .oneMinute:
            return 60
        case .threeMinutes:
            return 3 * 60
        case .fiveMinutes:
            return 5 * 60
        case .fifteenMinutes:
            return 15 * 60
        case .thirtyMinutes:
            return 30 * 60
        case .oneHour:
            return 60 * 60
        case .twoHours:
            return 2 * 60 * 60
        case .fourHours:
            return 4 * 60 * 60
        case .sixHours:
            return 6 * 60 * 60
        case .twelveHours:
            return 12 * 60 * 60
        case .oneDay:
            return 24 * 60 * 60
        case .twoDays:
            return 2 * 24 * 60 * 60
        case .threeDays:
            return 3 * 24 * 60 * 60
        case .oneWeek:
            return 7 * 24 * 60 * 60
        case .oneMonth:
            return nil
        case .threeMonths:
            return nil
        }
    }

    static func reasonText(side: KXFN09PreloadSide, hasMissingData: Bool) -> String {
        let base: String
        switch side {
        case .earlier:
            base = "visible_window_left_buffer_preload"
        case .later:
            base = "visible_window_right_buffer_preload"
        }

        return hasMissingData ? "\(base);missing_segment_marked_for_backfill" : base
    }

    static func increment(_ dictionary: inout [KXFN09SkippedPreloadReason: Int], reason: KXFN09SkippedPreloadReason) {
        dictionary[reason, default: 0] += 1
    }

    static func millisecondsString(_ date: Date) -> String {
        String(Int64((date.timeIntervalSince1970 * 1000).rounded()))
    }

    static func stableIDComponent(from text: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
