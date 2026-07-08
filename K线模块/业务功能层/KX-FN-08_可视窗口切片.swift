//
//  KX-FN-08_可视窗口切片.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：按 UI 可视窗口返回 K线切片的接口骨架
//  禁止事项：禁止全量加载历史数据、禁止 UI 绘制
//

import Foundation


// MARK: - K线可视窗口切片结果模型

/// KX-FN-08 本文件内的可视窗口切片结果。
///
/// 说明：KL-02 现有 `KLVisibleWindowSlicingProtocol` 只要求返回 `[KLCandlePoint]`，无法携带纠正后的窗口、缓冲区和摘要。
/// 因此本文件补充结果模型，不修改 KL-02；调用方只需要协议结果时可使用 `slice(candles:window:)`。
public struct KXFN08VisibleWindowSlice: Codable, Equatable, Sendable {
    public let visibleCandles: [KLCandlePoint]
    public let leftBufferCandles: [KLCandlePoint]
    public let rightBufferCandles: [KLCandlePoint]
    public let combinedCandles: [KLCandlePoint]
    public let summary: KXFN08VisibleWindowSliceSummary

    public init(
        visibleCandles: [KLCandlePoint],
        leftBufferCandles: [KLCandlePoint],
        rightBufferCandles: [KLCandlePoint],
        summary: KXFN08VisibleWindowSliceSummary
    ) {
        self.visibleCandles = visibleCandles
        self.leftBufferCandles = leftBufferCandles
        self.rightBufferCandles = rightBufferCandles
        self.combinedCandles = leftBufferCandles + visibleCandles + rightBufferCandles
        self.summary = summary
    }
}

/// 可视窗口切片摘要：用于 UI、调试与验收判断，不承担缓存职责。
public struct KXFN08VisibleWindowSliceSummary: Codable, Equatable, Sendable {
    public let totalInputCount: Int
    public let visibleCount: Int
    public let leftBufferCount: Int
    public let rightBufferCount: Int
    public let combinedCount: Int
    public let requestedIndexRange: KLIndexRange?
    public let correctedIndexRange: KLIndexRange?
    public let requestedTimeRange: KLTimeRange?
    public let correctedTimeRange: KLTimeRange?
    public let firstVisibleTime: Date?
    public let lastVisibleTime: Date?
    public let hasDataBefore: Bool
    public let hasDataAfter: Bool
    public let isEmpty: Bool
    public let isRangeCorrected: Bool
    public let strategy: KXFN08SliceStrategy

    public init(
        totalInputCount: Int,
        visibleCount: Int,
        leftBufferCount: Int,
        rightBufferCount: Int,
        requestedIndexRange: KLIndexRange?,
        correctedIndexRange: KLIndexRange?,
        requestedTimeRange: KLTimeRange?,
        correctedTimeRange: KLTimeRange?,
        firstVisibleTime: Date?,
        lastVisibleTime: Date?,
        hasDataBefore: Bool,
        hasDataAfter: Bool,
        isRangeCorrected: Bool,
        strategy: KXFN08SliceStrategy
    ) {
        self.totalInputCount = totalInputCount
        self.visibleCount = visibleCount
        self.leftBufferCount = leftBufferCount
        self.rightBufferCount = rightBufferCount
        self.combinedCount = leftBufferCount + visibleCount + rightBufferCount
        self.requestedIndexRange = requestedIndexRange
        self.correctedIndexRange = correctedIndexRange
        self.requestedTimeRange = requestedTimeRange
        self.correctedTimeRange = correctedTimeRange
        self.firstVisibleTime = firstVisibleTime
        self.lastVisibleTime = lastVisibleTime
        self.hasDataBefore = hasDataBefore
        self.hasDataAfter = hasDataAfter
        self.isEmpty = visibleCount == 0 && leftBufferCount == 0 && rightBufferCount == 0
        self.isRangeCorrected = isRangeCorrected
        self.strategy = strategy
    }
}

public enum KXFN08SliceStrategy: String, Codable, Sendable, CaseIterable {
    /// 已知索引范围，直接按 ArraySlice 边界切片，避免遍历全量数据。
    case indexRange
    /// 已知时间范围且输入按 openTime 升序时，用二分定位边界，避免全量复制/过滤。
    case binaryTimeRange
    /// 无法安全二分时，仅遍历定位索引，最后仍按 ArraySlice 一次性复制目标小片段。
    case linearTimeRange
    /// 输入为空或请求范围与数据无交集。
    case empty
}

public struct KXFN08SliceOptions: Codable, Equatable, Sendable {
    public let leftBufferCount: Int
    public let rightBufferCount: Int
    public let assumesSortedByOpenTime: Bool
    public let shouldFilterSymbolAndTimeframe: Bool

    public init(
        leftBufferCount: Int = 0,
        rightBufferCount: Int = 0,
        assumesSortedByOpenTime: Bool = true,
        shouldFilterSymbolAndTimeframe: Bool = true
    ) {
        self.leftBufferCount = max(0, leftBufferCount)
        self.rightBufferCount = max(0, rightBufferCount)
        self.assumesSortedByOpenTime = assumesSortedByOpenTime
        self.shouldFilterSymbolAndTimeframe = shouldFilterSymbolAndTimeframe
    }
}

// MARK: - K线可视窗口切片骨架与实现

public struct KXFN08Skeleton: KXFileSkeletonProtocol, KLVisibleWindowSlicingProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-08",
        fileName: "KX-FN-08_K线可视窗口切片.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-08_K线可视窗口切片.swift",
        duty: "按 UI 可视窗口返回 K线切片的接口骨架"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "K线可视窗口切片", passed: true, message: "已实现索引/时间范围切片、范围纠正、左右缓冲与摘要返回")
    }

    public static func placeholder() {
        // 本文件已实现纯逻辑切片计算：不查数据库、不请求 OKX、不绘制 UI、不做缓存实现。
    }

    public init() {}

    /// 满足 KL-02 中 `KLVisibleWindowSlicingProtocol` 的公共协议签名。
    /// 默认返回"可视范围 + 左右各 0 根缓冲"的组合切片；如需摘要和缓冲拆分，请使用 `makeSlice`。
    public func slice(candles: [KLCandlePoint], window: KLVisibleWindow) -> [KLCandlePoint] {
        Self.makeSlice(candles: candles, window: window).combinedCandles
    }

    /// 根据 KLVisibleWindow 的索引范围切片，并按 options 返回左右缓冲与摘要。
    public static func makeSlice(
        candles: [KLCandlePoint],
        window: KLVisibleWindow,
        options: KXFN08SliceOptions = KXFN08SliceOptions()
    ) -> KXFN08VisibleWindowSlice {
        let preparedCandles = prepareCandles(candles, symbol: window.symbol, timeframe: window.timeframe, shouldFilter: options.shouldFilterSymbolAndTimeframe)
        return makeSliceByIndexRange(
            candles: preparedCandles,
            requestedRange: window.indexRange,
            requestedTimeRange: window.timeRange,
            leftBufferCount: options.leftBufferCount,
            rightBufferCount: options.rightBufferCount
        )
    }

    /// 直接按索引范围切片。索引越界、反向范围、空数据均会被安全纠正。
    public static func makeSlice(
        candles: [KLCandlePoint],
        indexRange: KLIndexRange,
        leftBufferCount: Int = 0,
        rightBufferCount: Int = 0
    ) -> KXFN08VisibleWindowSlice {
        makeSliceByIndexRange(
            candles: candles,
            requestedRange: indexRange,
            requestedTimeRange: nil,
            leftBufferCount: max(0, leftBufferCount),
            rightBufferCount: max(0, rightBufferCount)
        )
    }

    /// 按时间范围切片。输入按 openTime 升序时默认二分定位；无序输入可传 `assumesSortedByOpenTime: false`。
    public static func makeSlice(
        candles: [KLCandlePoint],
        timeRange: KLTimeRange,
        leftBufferCount: Int = 0,
        rightBufferCount: Int = 0,
        assumesSortedByOpenTime: Bool = true
    ) -> KXFN08VisibleWindowSlice {
        makeSliceByTimeRange(
            candles: candles,
            requestedTimeRange: timeRange,
            leftBufferCount: max(0, leftBufferCount),
            rightBufferCount: max(0, rightBufferCount),
            assumesSortedByOpenTime: assumesSortedByOpenTime
        )
    }
}

// MARK: - 内部切片实现

private extension KXFN08Skeleton {
    static func makeSliceByIndexRange(
        candles: [KLCandlePoint],
        requestedRange: KLIndexRange,
        requestedTimeRange: KLTimeRange?,
        leftBufferCount: Int,
        rightBufferCount: Int
    ) -> KXFN08VisibleWindowSlice {
        guard !candles.isEmpty else {
            return emptySlice(
                totalInputCount: candles.count,
                requestedIndexRange: requestedRange,
                requestedTimeRange: requestedTimeRange,
                strategy: .empty
            )
        }

        let normalizedRequestedRange = normalize(requestedRange)
        guard let correctedVisibleRange = clamp(normalizedRequestedRange, count: candles.count) else {
            return emptySlice(
                totalInputCount: candles.count,
                requestedIndexRange: requestedRange,
                requestedTimeRange: requestedTimeRange,
                hasDataBefore: normalizedRequestedRange.startIndex >= candles.count,
                hasDataAfter: normalizedRequestedRange.endIndex < 0,
                strategy: .empty
            )
        }

        let bufferRange = bufferedRange(visibleRange: correctedVisibleRange, count: candles.count, leftBufferCount: leftBufferCount, rightBufferCount: rightBufferCount)
        let leftRange = bufferRange.lowerBound..<correctedVisibleRange.lowerBound
        let visibleRange = correctedVisibleRange.lowerBound..<(correctedVisibleRange.upperBound + 1)
        let rightRange = (correctedVisibleRange.upperBound + 1)..<bufferRange.upperBound

        let visibleCandles = Array(candles[visibleRange])
        let leftBufferCandles = Array(candles[leftRange])
        let rightBufferCandles = Array(candles[rightRange])
        let correctedIndexRange = KLIndexRange(startIndex: correctedVisibleRange.lowerBound, endIndex: correctedVisibleRange.upperBound)

        return KXFN08VisibleWindowSlice(
            visibleCandles: visibleCandles,
            leftBufferCandles: leftBufferCandles,
            rightBufferCandles: rightBufferCandles,
            summary: KXFN08VisibleWindowSliceSummary(
                totalInputCount: candles.count,
                visibleCount: visibleCandles.count,
                leftBufferCount: leftBufferCandles.count,
                rightBufferCount: rightBufferCandles.count,
                requestedIndexRange: requestedRange,
                correctedIndexRange: correctedIndexRange,
                requestedTimeRange: requestedTimeRange,
                correctedTimeRange: timeRange(for: visibleCandles),
                firstVisibleTime: visibleCandles.first?.openTime,
                lastVisibleTime: visibleCandles.last?.openTime,
                hasDataBefore: correctedVisibleRange.lowerBound > 0,
                hasDataAfter: correctedVisibleRange.upperBound < candles.count - 1,
                isRangeCorrected: requestedRange != correctedIndexRange,
                strategy: .indexRange
            )
        )
    }

    static func makeSliceByTimeRange(
        candles: [KLCandlePoint],
        requestedTimeRange: KLTimeRange,
        leftBufferCount: Int,
        rightBufferCount: Int,
        assumesSortedByOpenTime: Bool
    ) -> KXFN08VisibleWindowSlice {
        guard !candles.isEmpty else {
            return emptySlice(totalInputCount: candles.count, requestedTimeRange: requestedTimeRange, strategy: .empty)
        }

        let normalizedTimeRange = normalize(requestedTimeRange)
        let visibleBounds: ClosedRange<Int>?
        let strategy: KXFN08SliceStrategy

        if assumesSortedByOpenTime {
            let lower = lowerBoundOpenTime(in: candles, target: normalizedTimeRange.startTime)
            let upperExclusive = upperBoundOpenTime(in: candles, target: normalizedTimeRange.endTime)
            if lower < upperExclusive {
                visibleBounds = lower...(upperExclusive - 1)
                strategy = .binaryTimeRange
            } else {
                visibleBounds = nil
                strategy = .empty
            }
        } else {
            visibleBounds = linearBounds(in: candles, timeRange: normalizedTimeRange)
            strategy = visibleBounds == nil ? .empty : .linearTimeRange
        }

        guard let visibleBounds else {
            return emptySlice(
                totalInputCount: candles.count,
                requestedTimeRange: requestedTimeRange,
                correctedTimeRange: normalizedTimeRange,
                hasDataBefore: candles.contains { $0.openTime < normalizedTimeRange.startTime },
                hasDataAfter: candles.contains { $0.openTime > normalizedTimeRange.endTime },
                strategy: strategy
            )
        }

        let bufferRange = bufferedRange(visibleRange: visibleBounds, count: candles.count, leftBufferCount: leftBufferCount, rightBufferCount: rightBufferCount)
        let leftRange = bufferRange.lowerBound..<visibleBounds.lowerBound
        let visibleRange = visibleBounds.lowerBound..<(visibleBounds.upperBound + 1)
        let rightRange = (visibleBounds.upperBound + 1)..<bufferRange.upperBound

        let visibleCandles = Array(candles[visibleRange])
        let leftBufferCandles = Array(candles[leftRange])
        let rightBufferCandles = Array(candles[rightRange])
        let correctedIndexRange = KLIndexRange(startIndex: visibleBounds.lowerBound, endIndex: visibleBounds.upperBound)
        let correctedTimeRange = timeRange(for: visibleCandles)

        return KXFN08VisibleWindowSlice(
            visibleCandles: visibleCandles,
            leftBufferCandles: leftBufferCandles,
            rightBufferCandles: rightBufferCandles,
            summary: KXFN08VisibleWindowSliceSummary(
                totalInputCount: candles.count,
                visibleCount: visibleCandles.count,
                leftBufferCount: leftBufferCandles.count,
                rightBufferCount: rightBufferCandles.count,
                requestedIndexRange: nil,
                correctedIndexRange: correctedIndexRange,
                requestedTimeRange: requestedTimeRange,
                correctedTimeRange: correctedTimeRange,
                firstVisibleTime: visibleCandles.first?.openTime,
                lastVisibleTime: visibleCandles.last?.openTime,
                hasDataBefore: visibleBounds.lowerBound > 0,
                hasDataAfter: visibleBounds.upperBound < candles.count - 1,
                isRangeCorrected: requestedTimeRange != normalizedTimeRange || correctedTimeRange != normalizedTimeRange,
                strategy: strategy
            )
        )
    }

    static func prepareCandles(_ candles: [KLCandlePoint], symbol: KXSymbol, timeframe: KXTimeframe, shouldFilter: Bool) -> [KLCandlePoint] {
        guard shouldFilter else { return candles }
        return candles.filter { $0.symbol == symbol && $0.timeframe == timeframe }
    }

    static func normalize(_ range: KLIndexRange) -> KLIndexRange {
        KLIndexRange(startIndex: min(range.startIndex, range.endIndex), endIndex: max(range.startIndex, range.endIndex))
    }

    static func normalize(_ range: KLTimeRange) -> KLTimeRange {
        if range.startTime <= range.endTime { return range }
        return KLTimeRange(startTime: range.endTime, endTime: range.startTime)
    }

    static func clamp(_ range: KLIndexRange, count: Int) -> ClosedRange<Int>? {
        guard count > 0 else { return nil }
        let lower = max(0, range.startIndex)
        let upper = min(count - 1, range.endIndex)
        guard lower <= upper else { return nil }
        return lower...upper
    }

    /// 返回半开区间，覆盖左缓冲 + 可视区 + 右缓冲。
    static func bufferedRange(visibleRange: ClosedRange<Int>, count: Int, leftBufferCount: Int, rightBufferCount: Int) -> Range<Int> {
        let lower = max(0, visibleRange.lowerBound - max(0, leftBufferCount))
        let upperExclusive = min(count, visibleRange.upperBound + max(0, rightBufferCount) + 1)
        return lower..<upperExclusive
    }

    static func lowerBoundOpenTime(in candles: [KLCandlePoint], target: Date) -> Int {
        var lower = 0
        var upper = candles.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if candles[middle].openTime < target {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    static func upperBoundOpenTime(in candles: [KLCandlePoint], target: Date) -> Int {
        var lower = 0
        var upper = candles.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if candles[middle].openTime <= target {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    static func linearBounds(in candles: [KLCandlePoint], timeRange: KLTimeRange) -> ClosedRange<Int>? {
        var first: Int?
        var last: Int?

        for (index, candle) in candles.enumerated() where candle.openTime >= timeRange.startTime && candle.openTime <= timeRange.endTime {
            if first == nil { first = index }
            last = index
        }

        guard let first, let last else { return nil }
        return first...last
    }

    static func timeRange(for candles: [KLCandlePoint]) -> KLTimeRange? {
        guard let first = candles.first, let last = candles.last else { return nil }
        return KLTimeRange(startTime: first.openTime, endTime: last.openTime)
    }

    static func emptySlice(
        totalInputCount: Int,
        requestedIndexRange: KLIndexRange? = nil,
        requestedTimeRange: KLTimeRange? = nil,
        correctedTimeRange: KLTimeRange? = nil,
        hasDataBefore: Bool = false,
        hasDataAfter: Bool = false,
        strategy: KXFN08SliceStrategy
    ) -> KXFN08VisibleWindowSlice {
        KXFN08VisibleWindowSlice(
            visibleCandles: [],
            leftBufferCandles: [],
            rightBufferCandles: [],
            summary: KXFN08VisibleWindowSliceSummary(
                totalInputCount: totalInputCount,
                visibleCount: 0,
                leftBufferCount: 0,
                rightBufferCount: 0,
                requestedIndexRange: requestedIndexRange,
                correctedIndexRange: nil,
                requestedTimeRange: requestedTimeRange,
                correctedTimeRange: correctedTimeRange,
                firstVisibleTime: nil,
                lastVisibleTime: nil,
                hasDataBefore: hasDataBefore,
                hasDataAfter: hasDataAfter,
                isRangeCorrected: true,
                strategy: strategy
            )
        )
    }
}
