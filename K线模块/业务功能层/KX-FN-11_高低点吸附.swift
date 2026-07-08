//
//  KX-FN-11_高低点吸附.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：为画线工具提供高点、低点、开收盘等吸附点
//  禁止事项：禁止实现画线工具管理器
//

import Foundation


// MARK: - K线高低点吸附数据源骨架

public enum KXFN11Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-11",
        fileName: "KX-FN-11_高低点吸附.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-11_高低点吸附.swift",
        duty: "为画线工具提供高点、低点、开收盘等吸附点"
    )

    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("K线高低点吸附骨架校验通过")
        return KXHealthCheckItem(name: "K线高低点吸附", passed: true, message: "已实现画线工具可吸附点提取、窗口过滤与最近点查询纯逻辑")
    }

    public static func placeholder() {
        // 本文件已补充纯逻辑实现：从 KLCandlePoint 提取高点、低点、开盘、收盘、成交量异常点。
        // 不包含 UI 绘制、网络请求、数据库读写、缓存实现或画线工具管理器。
    }
}

// MARK: - 吸附点模型

public enum KXFN11SnapPointKind: String, Codable, Sendable, CaseIterable, Hashable {
    case high
    case low
    case open
    case close
    case volumeSpike
}

public struct KXFN11SnapPoint: Codable, Equatable, Sendable {
    public let kind: KXFN11SnapPointKind
    public let candle: KLCandlePoint
    public let candleIndex: Int
    public let coordinate: KLChartCoordinate
    public let price: KXDecimal?
    public let volume: KXDecimal?
    public let metadata: [String: String]

    public init(
        kind: KXFN11SnapPointKind,
        candle: KLCandlePoint,
        candleIndex: Int,
        coordinate: KLChartCoordinate,
        price: KXDecimal?,
        volume: KXDecimal? = nil,
        metadata: [String: String] = [:]
    ) {
        self.kind = kind
        self.candle = candle
        self.candleIndex = candleIndex
        self.coordinate = coordinate
        self.price = price
        self.volume = volume
        self.metadata = metadata
    }
}

public struct KXFN11SnapPointFilter: Sendable {
    public let kinds: Set<KXFN11SnapPointKind>
    public let includeUnclosedCandles: Bool

    public init(
        kinds: Set<KXFN11SnapPointKind> = Set(KXFN11SnapPointKind.allCases),
        includeUnclosedCandles: Bool = true
    ) {
        self.kinds = kinds
        self.includeUnclosedCandles = includeUnclosedCandles
    }

    public static let all = KXFN11SnapPointFilter()
}

public struct KXFN11SnapThreshold: Sendable {
    /// 屏幕坐标吸附阈值，单位为点；nil 表示坐标查询不限制距离。
    public let maxPointDistance: Double?
    /// 价格吸附阈值；nil 表示价格查询不限制价格差。
    public let maxPriceDistance: KXDecimal?
    /// index 吸附阈值；nil 表示 index 查询不限制距离。
    public let maxIndexDistance: Int?
    /// 时间吸附阈值，单位秒；nil 表示时间查询不限制距离。
    public let maxTimeDistance: TimeInterval?

    public init(
        maxPointDistance: Double? = 12,
        maxPriceDistance: KXDecimal? = nil,
        maxIndexDistance: Int? = nil,
        maxTimeDistance: TimeInterval? = nil
    ) {
        self.maxPointDistance = maxPointDistance
        self.maxPriceDistance = maxPriceDistance
        self.maxIndexDistance = maxIndexDistance
        self.maxTimeDistance = maxTimeDistance
    }

    public static let unlimited = KXFN11SnapThreshold(
        maxPointDistance: nil,
        maxPriceDistance: nil,
        maxIndexDistance: nil,
        maxTimeDistance: nil
    )
}

public struct KXFN11VolumeSpikeRule: Sendable {
    public let lookbackCount: Int
    public let multiplier: Double
    public let minimumBaselineSamples: Int

    public init(lookbackCount: Int = 20, multiplier: Double = 2.0, minimumBaselineSamples: Int = 5) {
        self.lookbackCount = max(1, lookbackCount)
        self.multiplier = max(0, multiplier)
        self.minimumBaselineSamples = max(1, minimumBaselineSamples)
    }
}

public struct KXFN11SnapExtractionOptions: Sendable {
    public let filter: KXFN11SnapPointFilter
    public let volumeSpikeRule: KXFN11VolumeSpikeRule

    public init(
        filter: KXFN11SnapPointFilter = .all,
        volumeSpikeRule: KXFN11VolumeSpikeRule = KXFN11VolumeSpikeRule()
    ) {
        self.filter = filter
        self.volumeSpikeRule = volumeSpikeRule
    }

    public static let `default` = KXFN11SnapExtractionOptions()
}

public struct KXFN11SnapQuery: Sendable {
    public let point: KLChartPoint?
    public let price: KXDecimal?
    public let time: Date?
    public let candleIndex: Int?
    public let threshold: KXFN11SnapThreshold
    public let filter: KXFN11SnapPointFilter

    public init(
        point: KLChartPoint? = nil,
        price: KXDecimal? = nil,
        time: Date? = nil,
        candleIndex: Int? = nil,
        threshold: KXFN11SnapThreshold = KXFN11SnapThreshold(),
        filter: KXFN11SnapPointFilter = .all
    ) {
        self.point = point
        self.price = price
        self.time = time
        self.candleIndex = candleIndex
        self.threshold = threshold
        self.filter = filter
    }
}

public struct KXFN11SnapMatch: Equatable, Sendable {
    public let point: KXFN11SnapPoint
    public let pointDistance: Double?
    public let priceDistance: KXDecimal?
    public let indexDistance: Int?
    public let timeDistance: TimeInterval?
    public let score: Double

    public init(
        point: KXFN11SnapPoint,
        pointDistance: Double? = nil,
        priceDistance: KXDecimal? = nil,
        indexDistance: Int? = nil,
        timeDistance: TimeInterval? = nil,
        score: Double
    ) {
        self.point = point
        self.pointDistance = pointDistance
        self.priceDistance = priceDistance
        self.indexDistance = indexDistance
        self.timeDistance = timeDistance
        self.score = score
    }
}

// MARK: - 纯逻辑吸附数据源

public struct KXFN11SnapPointDataSource: Sendable {
    public init() {}

    /// 从 KLCandlePoint 数组提取可吸附点，并按可视窗口、类型、未闭合 K线策略过滤。
    public func snapPoints(
        from candles: [KLCandlePoint],
        in window: KLVisibleWindow?,
        options: KXFN11SnapExtractionOptions = .default
    ) -> [KXFN11SnapPoint] {
        Self.snapPoints(from: candles, in: window, options: options)
    }

    /// 在已提取的吸附点中查找离查询条件最近的点。
    public func nearestSnapPoint(
        in points: [KXFN11SnapPoint],
        query: KXFN11SnapQuery
    ) -> KXFN11SnapMatch? {
        Self.nearestSnapPoint(in: points, query: query)
    }

    /// 便利方法：先提取窗口内吸附点，再查找最近点。
    public func nearestSnapPoint(
        from candles: [KLCandlePoint],
        in window: KLVisibleWindow?,
        query: KXFN11SnapQuery,
        extractionOptions: KXFN11SnapExtractionOptions = .default
    ) -> KXFN11SnapMatch? {
        let points = Self.snapPoints(from: candles, in: window, options: extractionOptions)
        return Self.nearestSnapPoint(in: points, query: query)
    }

    public static func snapPoints(
        from candles: [KLCandlePoint],
        in window: KLVisibleWindow?,
        options: KXFN11SnapExtractionOptions = .default
    ) -> [KXFN11SnapPoint] {
        guard !candles.isEmpty else { return [] }

        let filter = options.filter
        var result: [KXFN11SnapPoint] = []
        result.reserveCapacity(candles.count * max(filter.kinds.count, 1))

        for (arrayIndex, candle) in candles.enumerated() {
            guard let chartIndex = effectiveIndex(for: candle, arrayIndex: arrayIndex, window: window) else { continue }
            guard shouldInclude(candle: candle, chartIndex: chartIndex, window: window, filter: filter) else { continue }

            appendPricePoint(kind: .high, price: candle.high, candle: candle, chartIndex: chartIndex, window: window, filter: filter, result: &result)
            appendPricePoint(kind: .low, price: candle.low, candle: candle, chartIndex: chartIndex, window: window, filter: filter, result: &result)
            appendPricePoint(kind: .open, price: candle.open, candle: candle, chartIndex: chartIndex, window: window, filter: filter, result: &result)
            appendPricePoint(kind: .close, price: candle.close, candle: candle, chartIndex: chartIndex, window: window, filter: filter, result: &result)

            if filter.kinds.contains(.volumeSpike), isVolumeSpike(at: arrayIndex, in: candles, rule: options.volumeSpikeRule) {
                let metadata = volumeSpikeMetadata(at: arrayIndex, in: candles, rule: options.volumeSpikeRule)
                let coordinate = coordinate(for: candle, chartIndex: chartIndex, price: candle.close, window: window)
                result.append(
                    KXFN11SnapPoint(
                        kind: .volumeSpike,
                        candle: candle,
                        candleIndex: chartIndex,
                        coordinate: coordinate,
                        price: candle.close,
                        volume: candle.volume,
                        metadata: metadata
                    )
                )
            }
        }

        return result
    }

    public static func visibleSnapPoints(
        _ points: [KXFN11SnapPoint],
        in window: KLVisibleWindow?,
        filter: KXFN11SnapPointFilter = .all
    ) -> [KXFN11SnapPoint] {
        points.filter { point in
            filter.kinds.contains(point.kind)
            && (filter.includeUnclosedCandles || point.candle.isClosed)
            && shouldInclude(candle: point.candle, chartIndex: point.candleIndex, window: window, filter: filter)
        }
    }

    public static func nearestSnapPoint(
        in points: [KXFN11SnapPoint],
        query: KXFN11SnapQuery
    ) -> KXFN11SnapMatch? {
        points
            .lazy
            .filter { query.filter.kinds.contains($0.kind) && (query.filter.includeUnclosedCandles || $0.candle.isClosed) }
            .compactMap { match(for: $0, query: query) }
            .min { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.point.candleIndex < rhs.point.candleIndex
                }
                return lhs.score < rhs.score
            }
    }

    public static func nearestSnapPoint(
        to chartPoint: KLChartPoint,
        from candles: [KLCandlePoint],
        in window: KLVisibleWindow,
        threshold: KXFN11SnapThreshold = KXFN11SnapThreshold(),
        kinds: Set<KXFN11SnapPointKind> = Set(KXFN11SnapPointKind.allCases)
    ) -> KXFN11SnapMatch? {
        let filter = KXFN11SnapPointFilter(kinds: kinds)
        let query = KXFN11SnapQuery(point: chartPoint, threshold: threshold, filter: filter)
        return KXFN11SnapPointDataSource().nearestSnapPoint(from: candles, in: window, query: query)
    }

    public static func nearestSnapPoint(
        to price: KXDecimal,
        from candles: [KLCandlePoint],
        in window: KLVisibleWindow?,
        threshold: KXFN11SnapThreshold = KXFN11SnapThreshold(maxPointDistance: nil),
        kinds: Set<KXFN11SnapPointKind> = Set(KXFN11SnapPointKind.allCases)
    ) -> KXFN11SnapMatch? {
        let filter = KXFN11SnapPointFilter(kinds: kinds)
        let query = KXFN11SnapQuery(price: price, threshold: threshold, filter: filter)
        return KXFN11SnapPointDataSource().nearestSnapPoint(from: candles, in: window, query: query)
    }

    public static func nearestSnapPoint(
        to time: Date,
        from candles: [KLCandlePoint],
        in window: KLVisibleWindow?,
        threshold: KXFN11SnapThreshold = KXFN11SnapThreshold(maxPointDistance: nil),
        kinds: Set<KXFN11SnapPointKind> = Set(KXFN11SnapPointKind.allCases)
    ) -> KXFN11SnapMatch? {
        let filter = KXFN11SnapPointFilter(kinds: kinds)
        let query = KXFN11SnapQuery(time: time, threshold: threshold, filter: filter)
        return KXFN11SnapPointDataSource().nearestSnapPoint(from: candles, in: window, query: query)
    }

    public static func nearestSnapPoint(
        toCandleIndex candleIndex: Int,
        from candles: [KLCandlePoint],
        in window: KLVisibleWindow?,
        threshold: KXFN11SnapThreshold = KXFN11SnapThreshold(maxPointDistance: nil),
        kinds: Set<KXFN11SnapPointKind> = Set(KXFN11SnapPointKind.allCases)
    ) -> KXFN11SnapMatch? {
        let filter = KXFN11SnapPointFilter(kinds: kinds)
        let query = KXFN11SnapQuery(candleIndex: candleIndex, threshold: threshold, filter: filter)
        return KXFN11SnapPointDataSource().nearestSnapPoint(from: candles, in: window, query: query)
    }
}

// MARK: - 内部辅助

private extension KXFN11SnapPointDataSource {
    static func appendPricePoint(
        kind: KXFN11SnapPointKind,
        price: KXDecimal,
        candle: KLCandlePoint,
        chartIndex: Int,
        window: KLVisibleWindow?,
        filter: KXFN11SnapPointFilter,
        result: inout [KXFN11SnapPoint]
    ) {
        guard filter.kinds.contains(kind) else { return }
        guard isPriceVisible(price, in: window) else { return }
        result.append(
            KXFN11SnapPoint(
                kind: kind,
                candle: candle,
                candleIndex: chartIndex,
                coordinate: coordinate(for: candle, chartIndex: chartIndex, price: price, window: window),
                price: price
            )
        )
    }

    static func coordinate(for candle: KLCandlePoint, chartIndex: Int, price: KXDecimal, window: KLVisibleWindow?) -> KLChartCoordinate {
        guard let window else {
            return KLChartCoordinate(time: candle.openTime, index: chartIndex, price: price, point: nil)
        }

        return KXFN10CoordinateMapper.coordinate(index: chartIndex, price: price, time: candle.openTime, in: window, allowOutside: false)
    }

    static func effectiveIndex(for candle: KLCandlePoint, arrayIndex: Int, window: KLVisibleWindow?) -> Int? {
        guard let window else { return arrayIndex }
        return KXFN10CoordinateMapper.index(for: candle.openTime, in: window, allowOutside: false) ?? arrayIndex
    }

    static func shouldInclude(candle: KLCandlePoint, chartIndex: Int, window: KLVisibleWindow?, filter: KXFN11SnapPointFilter) -> Bool {
        guard filter.includeUnclosedCandles || candle.isClosed else { return false }
        guard let window else { return true }
        guard candle.symbol == window.symbol, candle.timeframe == window.timeframe else { return false }
        guard chartIndex >= window.indexRange.startIndex, chartIndex <= window.indexRange.endIndex else { return false }

        if let timeRange = window.timeRange {
            guard candle.openTime >= timeRange.startTime, candle.openTime <= timeRange.endTime else { return false }
        }

        return true
    }

    static func isPriceVisible(_ price: KXDecimal, in window: KLVisibleWindow?) -> Bool {
        guard let priceRange = window?.priceRange else { return true }
        let value = decimalDouble(price)
        let minPrice = min(decimalDouble(priceRange.minPrice), decimalDouble(priceRange.maxPrice))
        let maxPrice = max(decimalDouble(priceRange.minPrice), decimalDouble(priceRange.maxPrice))
        guard value.isFinite, minPrice.isFinite, maxPrice.isFinite else { return false }
        return value >= minPrice && value <= maxPrice
    }

    static func isVolumeSpike(at index: Int, in candles: [KLCandlePoint], rule: KXFN11VolumeSpikeRule) -> Bool {
        guard index > 0 else { return false }
        let current = decimalDouble(candles[index].volume)
        guard current.isFinite, current > 0 else { return false }
        guard let baseline = averageVolume(before: index, in: candles, rule: rule) else { return false }
        return baseline > 0 && current >= baseline * rule.multiplier
    }

    static func averageVolume(before index: Int, in candles: [KLCandlePoint], rule: KXFN11VolumeSpikeRule) -> Double? {
        let start = max(0, index - rule.lookbackCount)
        guard start < index else { return nil }

        let samples = candles[start..<index]
            .map { decimalDouble($0.volume) }
            .filter { $0.isFinite && $0 >= 0 }
        guard samples.count >= rule.minimumBaselineSamples else { return nil }

        let sum = samples.reduce(0, +)
        return sum / Double(samples.count)
    }

    static func volumeSpikeMetadata(at index: Int, in candles: [KLCandlePoint], rule: KXFN11VolumeSpikeRule) -> [String: String] {
        guard let baseline = averageVolume(before: index, in: candles, rule: rule), baseline > 0 else { return [:] }
        let current = decimalDouble(candles[index].volume)
        let ratio = current / baseline
        return [
            "baselineVolume": String(baseline),
            "volumeRatio": String(ratio),
            "lookbackCount": String(rule.lookbackCount),
            "multiplier": String(rule.multiplier)
        ]
    }

    static func match(for point: KXFN11SnapPoint, query: KXFN11SnapQuery) -> KXFN11SnapMatch? {
        var score = 0.0
        var matchedConditionCount = 0

        let pointDistance = distance(from: query.point, to: point.coordinate.point)
        if let queryPoint = query.point {
            guard point.coordinate.point != nil else { return nil }
            guard let pointDistance, pointDistance.isFinite else { return nil }
            if let maxPointDistance = query.threshold.maxPointDistance {
                guard maxPointDistance.isFinite, pointDistance <= maxPointDistance else { return nil }
                score += normalized(pointDistance, by: max(maxPointDistance, 0.000_001))
            } else {
                score += pointDistance
            }
            _ = queryPoint
            matchedConditionCount += 1
        }

        let priceDistance = decimalDistance(query.price, point.price)
        if query.price != nil {
            guard let priceDistance else { return nil }
            if let maxPriceDistance = query.threshold.maxPriceDistance {
                guard priceDistance <= maxPriceDistance else { return nil }
                score += normalized(decimalDouble(priceDistance), by: max(decimalDouble(maxPriceDistance), 0.000_001))
            } else {
                score += decimalDouble(priceDistance)
            }
            matchedConditionCount += 1
        }

        let indexDistance = query.candleIndex.map { abs(point.candleIndex - $0) }
        if query.candleIndex != nil {
            guard let indexDistance else { return nil }
            if let maxIndexDistance = query.threshold.maxIndexDistance {
                guard indexDistance <= maxIndexDistance else { return nil }
                score += normalized(Double(indexDistance), by: Double(max(maxIndexDistance, 1)))
            } else {
                score += Double(indexDistance)
            }
            matchedConditionCount += 1
        }

        let timeDistance = query.time.map { abs(point.candle.openTime.timeIntervalSince($0)) }
        if query.time != nil {
            guard let timeDistance, timeDistance.isFinite else { return nil }
            if let maxTimeDistance = query.threshold.maxTimeDistance {
                guard maxTimeDistance.isFinite, timeDistance <= maxTimeDistance else { return nil }
                score += normalized(timeDistance, by: max(maxTimeDistance, 0.000_001))
            } else {
                score += timeDistance
            }
            matchedConditionCount += 1
        }

        guard matchedConditionCount > 0 else { return nil }
        return KXFN11SnapMatch(
            point: point,
            pointDistance: pointDistance,
            priceDistance: priceDistance,
            indexDistance: indexDistance,
            timeDistance: timeDistance,
            score: score / Double(matchedConditionCount)
        )
    }

    static func distance(from queryPoint: KLChartPoint?, to snapPoint: KLChartPoint?) -> Double? {
        guard let queryPoint, let snapPoint else { return nil }
        let dx = queryPoint.x - snapPoint.x
        let dy = queryPoint.y - snapPoint.y
        return (dx * dx + dy * dy).squareRoot()
    }

    static func decimalDistance(_ lhs: KXDecimal?, _ rhs: KXDecimal?) -> KXDecimal? {
        guard let lhs, let rhs else { return nil }
        return abs(lhs - rhs)
    }

    static func decimalDouble(_ decimal: KXDecimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }

    static func normalized(_ value: Double, by denominator: Double) -> Double {
        guard value.isFinite, denominator.isFinite, denominator > 0 else { return Double.greatestFiniteMagnitude }
        return value / denominator
    }
}
