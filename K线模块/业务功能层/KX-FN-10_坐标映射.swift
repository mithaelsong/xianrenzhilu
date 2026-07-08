//
//  KX-FN-10_坐标映射.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：时间价格与屏幕坐标的映射纯逻辑
//  禁止事项：禁止 UI 绘制、禁止访问数据库
//

import Foundation


// MARK: - K线坐标映射

public enum KXFN10Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-10",
        fileName: "KX-FN-10_坐标映射.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-10_坐标映射.swift",
        duty: "时间价格与屏幕坐标的映射纯逻辑"
    )

    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("K线坐标映射骨架校验通过")
        return KXHealthCheckItem(name: "K线坐标映射", passed: true, message: "已实现时间/index/价格与屏幕坐标的纯逻辑映射")
    }

    public static func placeholder() {
        // 本文件已补充纯逻辑实现：时间/index 到 x 坐标、价格到 y 坐标、坐标反查 index/价格。
        // 不包含 UI 绘制、SwiftUI View、数据库读写、网络请求、缓存实现。
    }
}

// MARK: - 纯逻辑坐标映射器

public struct KXFN10CoordinateMapper: KLCoordinateMappingProtocol, Sendable {
    public init() {}

    /// 结构：candle 的 open/high/low/close 四个价格的 y 坐标（不含 x）。
    public struct KXFN10CandlePriceCoordinates: Sendable {
        public let openY: Double?
        public let highY: Double?
        public let lowY: Double?
        public let closeY: Double?

        public init(openY: Double?, highY: Double?, lowY: Double?, closeY: Double?) {
            self.openY = openY
            self.highY = highY
            self.lowY = lowY
            self.closeY = closeY
        }
    }

    /// 完整映射：返回 candle 的 open/high/low/close 全部 y 坐标。
    /// - 不改变原 coordinate(for:candle:in:) 行为。
    /// - 返回的自定义结构只在文件内定义，不改 KL-02。
    public func coordinateFull(for candle: KLCandlePoint, in window: KLVisibleWindow) -> KXFN10CandlePriceCoordinates {
        let openY  = Self.y(forPrice: candle.open,  in: window, clampToViewport: false)
        let highY  = Self.y(forPrice: candle.high,  in: window, clampToViewport: false)
        let lowY   = Self.y(forPrice: candle.low,   in: window, clampToViewport: false)
        let closeY = Self.y(forPrice: candle.close, in: window, clampToViewport: false)
        return KXFN10CandlePriceCoordinates(openY: openY, highY: highY, lowY: lowY, closeY: closeY)
    }

    /// 将单根 K线映射为图表坐标。
    /// - 说明：公共 KLCandlePoint 不携带序号，因此优先通过 window.timeRange 估算 index；若无有效时间窗口，则只映射价格。
    public func coordinate(for candle: KLCandlePoint, in window: KLVisibleWindow) -> KLChartCoordinate {
        let mappedIndex = Self.index(for: candle.openTime, in: window)
        let x = mappedIndex.flatMap { Self.x(forIndex: $0, in: window, allowOutside: true) }
        let y = Self.y(forPrice: candle.close, in: window, clampToViewport: false)
        let point: KLChartPoint?

        if let x, let y {
            point = KLChartPoint(x: x, y: y)
        } else {
            point = nil
        }

        return KLChartCoordinate(time: candle.openTime, index: mappedIndex, price: candle.close, point: point)
    }

    /// 从屏幕点反查最近的 K线 index。越界点会按窗口 index 范围夹紧，窗口无效时返回 nil。
    public func candleIndex(at point: KLChartPoint, in window: KLVisibleWindow) -> Int? {
        Self.nearestIndex(atX: point.x, in: window, clampToWindow: true)
    }

    /// index -> x 坐标。默认只接受窗口内 index。
    public static func x(forIndex index: Int, in window: KLVisibleWindow, allowOutside: Bool = false) -> Double? {
        guard let metrics = Metrics(window: window) else { return nil }
        guard allowOutside || metrics.contains(index: index) else { return nil }

        return (Double(index - metrics.startIndex) + 0.5) * metrics.candleWidth - metrics.contentOffsetX
    }

    /// 时间 -> x 坐标。需要有效 timeRange；时间越界时默认返回 nil。
    public static func x(forTime time: Date, in window: KLVisibleWindow, allowOutside: Bool = false) -> Double? {
        guard let index = fractionalIndex(for: time, in: window, allowOutside: allowOutside) else { return nil }
        return x(forFractionalIndex: index, in: window, allowOutside: allowOutside)
    }

    /// 价格 -> y 坐标。价格越高 y 越小；可选夹紧到视口高度范围。
    public static func y(forPrice price: KXDecimal, in window: KLVisibleWindow, clampToViewport: Bool = false) -> Double? {
        guard let priceMetrics = PriceMetrics(window: window) else { return nil }

        let priceValue = Self.double(from: price)
        guard priceValue.isFinite else { return nil }

        let rawY: Double
        if priceMetrics.range == 0 {
            rawY = priceMetrics.viewportHeight / 2
        } else {
            let ratio = (priceMetrics.maxPrice - priceValue) / priceMetrics.range
            rawY = ratio * priceMetrics.viewportHeight
        }

        guard rawY.isFinite else { return nil }
        return clampToViewport ? Self.clamp(rawY, lower: 0, upper: priceMetrics.viewportHeight) : rawY
    }

    /// x 坐标 -> 最近 K线 index。默认夹紧到窗口 index 范围，以安全处理越界坐标。
    public static func nearestIndex(atX x: Double, in window: KLVisibleWindow, clampToWindow: Bool = true) -> Int? {
        guard let metrics = Metrics(window: window), x.isFinite else { return nil }

        let rawSlot = (x + metrics.contentOffsetX) / metrics.candleWidth
        guard rawSlot.isFinite else { return nil }

        let rawIndex = metrics.startIndex + Int(floor(rawSlot))
        if clampToWindow {
            return Self.clamp(rawIndex, lower: metrics.startIndex, upper: metrics.endIndex)
        }

        return metrics.contains(index: rawIndex) ? rawIndex : nil
    }

    /// y 坐标 -> 价格。越界 y 会按视口高度夹紧，避免产生窗口价格区间外的异常值。
    public static func price(atY y: Double, in window: KLVisibleWindow, clampToRange: Bool = true) -> KXDecimal? {
        guard let priceMetrics = PriceMetrics(window: window), y.isFinite else { return nil }

        if priceMetrics.range == 0 {
            return window.priceRange?.minPrice
        }

        let effectiveY = clampToRange ? Self.clamp(y, lower: 0, upper: priceMetrics.viewportHeight) : y
        let ratio = effectiveY / priceMetrics.viewportHeight
        let priceValue = priceMetrics.maxPrice - ratio * priceMetrics.range

        guard priceValue.isFinite else { return nil }
        return KXDecimal(priceValue)
    }

    /// 时间 -> 估算 index。需要有效 timeRange；默认只接受窗口时间范围内的时间。
    public static func index(for time: Date, in window: KLVisibleWindow, allowOutside: Bool = false) -> Int? {
        guard let fractional = fractionalIndex(for: time, in: window, allowOutside: allowOutside) else { return nil }
        let rounded = Int(fractional.rounded())

        guard let metrics = Metrics(window: window) else { return nil }
        if allowOutside {
            return rounded
        }
        return metrics.contains(index: rounded) ? rounded : nil
    }

    /// 同时映射 index 与价格，便于十字线、标记、吸附等上层模块直接组装 KLChartCoordinate。
    public static func coordinate(index: Int, price: KXDecimal, time: Date? = nil, in window: KLVisibleWindow, allowOutside: Bool = false) -> KLChartCoordinate {
        let x = x(forIndex: index, in: window, allowOutside: allowOutside)
        let y = y(forPrice: price, in: window, clampToViewport: false)
        let point: KLChartPoint?

        if let x, let y {
            point = KLChartPoint(x: x, y: y)
        } else {
            point = nil
        }

        return KLChartCoordinate(time: time, index: index, price: price, point: point)
    }

    /// 同时反查 x/y 坐标，返回最近 index 与对应价格。
    public static func coordinate(at point: KLChartPoint, in window: KLVisibleWindow, clampToWindow: Bool = true) -> KLChartCoordinate {
        let index = nearestIndex(atX: point.x, in: window, clampToWindow: clampToWindow)
        let price = price(atY: point.y, in: window, clampToRange: clampToWindow)

        return KLChartCoordinate(time: nil, index: index, price: price, point: point)
    }
}

// MARK: - 内部计算辅助

private extension KXFN10CoordinateMapper {
    struct Metrics: Sendable {
        let startIndex: Int
        let endIndex: Int
        let candleWidth: Double
        let contentOffsetX: Double

        init?(window: KLVisibleWindow) {
            guard window.indexRange.startIndex <= window.indexRange.endIndex else { return nil }
            guard window.candleWidth.isFinite, window.candleWidth > 0 else { return nil }
            guard window.contentOffsetX.isFinite else { return nil }
            guard window.viewportWidth.isFinite, window.viewportWidth >= 0 else { return nil }
            guard window.viewportHeight.isFinite, window.viewportHeight > 0 else { return nil }

            self.startIndex = window.indexRange.startIndex
            self.endIndex = window.indexRange.endIndex
            self.candleWidth = window.candleWidth
            self.contentOffsetX = window.contentOffsetX
        }

        var count: Int { endIndex - startIndex + 1 }

        func contains(index: Int) -> Bool {
            index >= startIndex && index <= endIndex
        }
    }

    struct PriceMetrics: Sendable {
        let minPrice: Double
        let maxPrice: Double
        let range: Double
        let viewportHeight: Double

        init?(window: KLVisibleWindow) {
            guard let priceRange = window.priceRange else { return nil }
            guard window.viewportHeight.isFinite, window.viewportHeight > 0 else { return nil }

            let rawMin = KXFN10CoordinateMapper.double(from: priceRange.minPrice)
            let rawMax = KXFN10CoordinateMapper.double(from: priceRange.maxPrice)
            guard rawMin.isFinite, rawMax.isFinite else { return nil }

            self.minPrice = min(rawMin, rawMax)
            self.maxPrice = max(rawMin, rawMax)
            self.range = self.maxPrice - self.minPrice
            self.viewportHeight = window.viewportHeight
        }
    }

    static func fractionalIndex(for time: Date, in window: KLVisibleWindow, allowOutside: Bool) -> Double? {
        guard let metrics = Metrics(window: window), let timeRange = window.timeRange else { return nil }

        let start = timeRange.startTime.timeIntervalSinceReferenceDate
        let end = timeRange.endTime.timeIntervalSinceReferenceDate
        let value = time.timeIntervalSinceReferenceDate
        guard start.isFinite, end.isFinite, value.isFinite else { return nil }
        guard start <= end else { return nil }

        if start == end {
            guard allowOutside || value == start else { return nil }
            return Double(metrics.startIndex)
        }

        if !allowOutside, (value < start || value > end) {
            return nil
        }

        let ratio = (value - start) / (end - start)
        let span = Double(max(metrics.count - 1, 0))
        return Double(metrics.startIndex) + ratio * span
    }

    static func x(forFractionalIndex index: Double, in window: KLVisibleWindow, allowOutside: Bool) -> Double? {
        guard let metrics = Metrics(window: window), index.isFinite else { return nil }
        let lower = Double(metrics.startIndex)
        let upper = Double(metrics.endIndex)
        guard allowOutside || (index >= lower && index <= upper) else { return nil }

        return (index - lower + 0.5) * metrics.candleWidth - metrics.contentOffsetX
    }

    static func double(from decimal: KXDecimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }

    static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    static func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
