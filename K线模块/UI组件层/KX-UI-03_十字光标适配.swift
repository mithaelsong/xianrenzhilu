//
//  KX-UI-03_十字光标适配.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：为十字光标提供时间、价格、成交量映射数据与吸附/触线能力
//  禁止事项：禁止画 UI、禁止请求网络、禁止读写数据库、禁止实现十字光标管理器
//

import Foundation



// MARK: - 本地坐标映射工具（不依赖功能层）

public extension KXUI03CrosshairDataAdapter {
    /// 通过 index 计算 x 坐标
    static func _x(forIndex index: Int, in window: KLVisibleWindow) -> Double? {
        guard window.candleWidth.isFinite, window.candleWidth > 0,
              window.indexRange.startIndex <= window.indexRange.endIndex,
              window.contentOffsetX.isFinite else { return nil }
        return (Double(index - window.indexRange.startIndex) + 0.5) * window.candleWidth - window.contentOffsetX
    }

    /// 通过 index 反查 x（允许超出窗口范围）
    static func _x(forIndex index: Int, in window: KLVisibleWindow, allowOutside: Bool) -> Double? {
        if !allowOutside {
            guard index >= window.indexRange.startIndex, index <= window.indexRange.endIndex else { return nil }
        }
        return _x(forIndex: index, in: window)
    }

    /// 通过屏幕 x 反查最近 index
    static func _nearestIndex(atX x: Double, in window: KLVisibleWindow, clampToWindow: Bool) -> Int? {
        guard window.candleWidth.isFinite, window.candleWidth > 0,
              window.indexRange.startIndex <= window.indexRange.endIndex else { return nil }
        let fractionalIndex = Double(window.indexRange.startIndex) + (x + window.contentOffsetX) / window.candleWidth - 0.5
        var index = Int(fractionalIndex.rounded())
        if clampToWindow {
            index = max(window.indexRange.startIndex, min(window.indexRange.endIndex, index))
        }
        return index
    }

    /// 价格 → y 坐标
    static func _y(forPrice price: KXDecimal, in window: KLVisibleWindow, clampToViewport: Bool = true) -> Double? {
        guard let priceRange = window.priceRange, window.viewportHeight.isFinite, window.viewportHeight > 0 else { return nil }
        let minP = min(priceRange.minPrice, priceRange.maxPrice)
        let maxP = max(priceRange.minPrice, priceRange.maxPrice)
        let pv = NSDecimalNumber(decimal: price).doubleValue
        let minD = NSDecimalNumber(decimal: minP).doubleValue
        let maxD = NSDecimalNumber(decimal: maxP).doubleValue
        guard minD.isFinite, maxD.isFinite, pv.isFinite else { return nil }
        let range = maxD - minD
        if range == 0 { return window.viewportHeight / 2 }
        return (maxD - pv) / range * window.viewportHeight
    }

    /// y → 价格
    static func _price(atY y: Double, in window: KLVisibleWindow, clampToRange: Bool = true) -> KXDecimal? {
        guard let priceRange = window.priceRange, window.viewportHeight.isFinite, window.viewportHeight > 0 else { return nil }
        let minP = NSDecimalNumber(decimal: min(priceRange.minPrice, priceRange.maxPrice)).doubleValue
        let maxP = NSDecimalNumber(decimal: max(priceRange.minPrice, priceRange.maxPrice)).doubleValue
        guard minP.isFinite, maxP.isFinite, y.isFinite else { return nil }
        let ratio = y / window.viewportHeight
        return NSDecimalNumber(value: maxP - ratio * (maxP - minP)).decimalValue
    }
}

// MARK: - 十字光标数据适配骨架

public enum KXUI03Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-03",
        fileName: "KX-UI-03_十字光标数据适配.swift",
        layer: .uiAdapter,
        relativePath: "UI数据适配层/KX-UI-03_十字光标数据适配.swift",
        duty: "为十字光标提供时间、价格、成交量映射数据与吸附/触线能力"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "十字光标数据适配", passed: true, message: "已实现：坐标反查、触线吸附、OHLC摘要、偏离程度、X轴时间标签、Y轴价格标签、成交量标签")
    }

    public static func placeholder() {
        // 本文件已补充完整实现：通过 KXFN10CoordinateMapper 与 KXFN11SnapPointDataSource 提供十字光标所需的所有数据适配。
        // 不包含 UI 绘制、网络请求、数据库读写、十字光标管理器。
    }
}

// MARK: - 十字光标本地吸附点类型

/// 十字光标触线吸附时命中的具体价位类型。
/// UI 层自包含枚举，不依赖功能层 KXFN11SnapPointKind。
public enum KXUI03SnapKind: String, Codable, Sendable, CaseIterable, Hashable {
    /// 高点（最高价）
    case high
    /// 低点（最低价）
    case low
    /// 开盘价
    case open
    /// 收盘价
    case close
    /// 成交量异常点
    case volumeSpike
    /// 自定义价格
    case customPrice
    /// K 线中点（(高+低)/2）
    case candleMidpoint
    /// 未吸附到任何特殊价位
    case none
}

// MARK: - 十字光标查询结果

/// 十字光标在屏幕某个位置命中 K 线后返回的完整结果。
public struct KXUI03CrosshairHit: Codable, Equatable, Sendable {
    /// 命中的 K 线原始数据
    public let candle: KLCandlePoint
    /// 命中 K 线在完整序列中的 index
    public let candleIndex: Int
    /// 光标在屏幕上的原始位置（像素）
    public let screenPoint: KLChartPoint
    /// 吸附后的屏幕坐标（如果是触线吸附模式，则吸附到最近 K 线中心 X）
    public let snappedPoint: KLChartPoint
    /// X 轴时间标签信息
    public let timeLabel: KXUI03TimeAxisLabel
    /// Y 轴价格标签信息
    public let priceLabel: KXUI03PriceAxisLabel
    /// 成交量标签信息
    public let volumeLabel: KXUI03VolumeLabel
    /// OHLC 摘要信息
    public let ohlcSummary: KXUI03OHLCSummary
    /// 光标偏离当前 K 线的程度（像素）
    public let deviation: KXUI03Deviation
    /// 是否成功吸附到某根 K 线
    public let isSnapped: Bool
    /// 当前可视窗口快照
    public let visibleWindow: KLVisibleWindow
    /// 是否强制吸附至触线位置（非最近 K 线中心，而是高点/低点）
    public let isSnappedToExtreme: Bool
    /// 触线吸附时命中的具体价位类型
    public let snappedExtremeKind: KXUI03SnapKind?

    public init(
        candle: KLCandlePoint,
        candleIndex: Int,
        screenPoint: KLChartPoint,
        snappedPoint: KLChartPoint,
        timeLabel: KXUI03TimeAxisLabel,
        priceLabel: KXUI03PriceAxisLabel,
        volumeLabel: KXUI03VolumeLabel,
        ohlcSummary: KXUI03OHLCSummary,
        deviation: KXUI03Deviation,
        isSnapped: Bool,
        visibleWindow: KLVisibleWindow,
        isSnappedToExtreme: Bool = false,
        snappedExtremeKind: KXUI03SnapKind? = nil
    ) {
        self.candle = candle
        self.candleIndex = candleIndex
        self.screenPoint = screenPoint
        self.snappedPoint = snappedPoint
        self.timeLabel = timeLabel
        self.priceLabel = priceLabel
        self.volumeLabel = volumeLabel
        self.ohlcSummary = ohlcSummary
        self.deviation = deviation
        self.isSnapped = isSnapped
        self.visibleWindow = visibleWindow
        self.isSnappedToExtreme = isSnappedToExtreme
        self.snappedExtremeKind = snappedExtremeKind
    }
}

// MARK: - X 轴时间标签

/// X 轴时间标签所需的信息。
public struct KXUI03TimeAxisLabel: Codable, Equatable, Sendable {
    /// 日期部分（如 "2026-06-11"）
    public let dateString: String
    /// 时间部分（如 "14:30"）
    public let timeString: String
    /// 格式化完整字符串（如 "2026-06-11 14:30"）
    public let fullString: String
    /// 时间标签在 X 轴上的锚点坐标（像素）
    public let anchorX: Double
    /// 标签在 X 轴的可见性（边缘时可能超出视口）
    public let isVisible: Bool

    public init(dateString: String, timeString: String, fullString: String, anchorX: Double, isVisible: Bool) {
        self.dateString = dateString
        self.timeString = timeString
        self.fullString = fullString
        self.anchorX = anchorX
        self.isVisible = isVisible
    }
}

// MARK: - Y 轴价格标签

/// Y 轴价格标签所需的信息。
public struct KXUI03PriceAxisLabel: Codable, Equatable, Sendable {
    /// 当前价格（原始值）
    public let price: KXDecimal
    /// 格式化价格字符串（如 "42,056.32"）
    public let formattedPrice: String
    /// 涨跌方向："up" / "down" / "flat"
    public let direction: String
    /// 价格标签在 Y 轴上的锚点坐标（像素）
    public let anchorY: Double
    /// 标签在 Y 轴是否可见
    public let isVisible: Bool

    public init(price: KXDecimal, formattedPrice: String, direction: String, anchorY: Double, isVisible: Bool) {
        self.price = price
        self.formattedPrice = formattedPrice
        self.direction = direction
        self.anchorY = anchorY
        self.isVisible = isVisible
    }
}

// MARK: - 成交量标签

/// 成交量标签所需的信息。
public struct KXUI03VolumeLabel: Codable, Equatable, Sendable {
    /// 成交量（原始值）
    public let volume: KXDecimal
    /// 格式化成交量字符串（如 "12.5K"）
    public let formattedVolume: String
    /// 成交量柱状体顶部在图表下方的 Y 坐标（像素）
    public let anchorY: Double
    /// 成交量占当前视口成交量的比例（用于 UI 渲染柱状高度）
    public let volumeRatio: Double

    public init(volume: KXDecimal, formattedVolume: String, anchorY: Double, volumeRatio: Double) {
        self.volume = volume
        self.formattedVolume = formattedVolume
        self.anchorY = anchorY
        self.volumeRatio = volumeRatio
    }
}

// MARK: - OHLC 摘要

/// 当前 K 线的 OHLC 摘要。
public struct KXUI03OHLCSummary: Codable, Equatable, Sendable {
    /// 开盘价
    public let open: KXDecimal
    /// 最高价
    public let high: KXDecimal
    /// 最低价
    public let low: KXDecimal
    /// 收盘价
    public let close: KXDecimal
    /// vs 上一根 K 线收盘的涨跌幅（百分比，如 2.35 表示 +2.35%）
    public let changePercent: Double
    /// 涨跌额 vs 上一根 K 线收盘
    public let changeAmount: KXDecimal
    /// 本根 K 线实体上下影线占整体振幅比例
    public let bodyRatio: Double

    public init(open: KXDecimal, high: KXDecimal, low: KXDecimal, close: KXDecimal, changePercent: Double, changeAmount: KXDecimal, bodyRatio: Double) {
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.changePercent = changePercent
        self.changeAmount = changeAmount
        self.bodyRatio = bodyRatio
    }
}

// MARK: - 偏离程度

/// 光标偏离命中所选 K 线中心或触线点的程度（像素），用于 UI 确定是否要显示吸附动画。
public struct KXUI03Deviation: Codable, Equatable, Sendable {
    /// 水平偏移量（像素），绝对值
    public let horizontalPixels: Double
    /// 垂直偏移量（像素），绝对值
    public let verticalPixels: Double
    /// 欧几里得总偏移（像素）
    public let totalPixels: Double

    public init(horizontalPixels: Double, verticalPixels: Double, totalPixels: Double) {
        self.horizontalPixels = horizontalPixels
        self.verticalPixels = verticalPixels
        self.totalPixels = totalPixels
    }
}

// MARK: - 十字光标数据适配器

/// 十字光标数据适配器：接收 KLCandlePoint 数组 + KLVisibleWindow + 屏幕光标位置(x,y)，
/// 返回命中 K 线的完整数据（OHLC、时间、价格、成交量、偏离程度）。
///
/// 依赖：
/// - KXFN10CoordinateMapper — 坐标映射与反查
/// - KXFN11SnapPointDataSource — 触线吸附
///
/// 不保存状态（纯函数式 struct），可安全跨线程使用。
public struct KXUI03CrosshairDataAdapter: Sendable {
    /// 触线吸附阈值（像素），即光标距 K 线高点/低点在此范围内自动吸附。
    public let extremeSnapThresholdPixels: Double
    /// 是否默认开启触线吸附
    public let extremeSnapEnabled: Bool

    public init(extremeSnapThresholdPixels: Double = 6.0, extremeSnapEnabled: Bool = true) {
        self.extremeSnapThresholdPixels = max(0, extremeSnapThresholdPixels)
        self.extremeSnapEnabled = extremeSnapEnabled
    }
}

// MARK: - 核心查询

extension KXUI03CrosshairDataAdapter {
    /// 查询十字光标在指定位置的命中结果。
    /// - Parameters:
    ///   - screenPoint: 光标在屏幕上的像素坐标 (x, y)
    ///   - candles: 当前可视窗口范围内的 KLCandlePoint 数组
    ///   - previousCandle: 前一根 K 线（用于计算涨跌幅，可选）
    ///   - window: 当前可视窗口
    /// - Returns: 十字光标命中结果；若无法反查到任何有效 K 线则返回 nil
    public func query(
        at screenPoint: KLChartPoint,
        candles: [KLCandlePoint],
        previousCandle: KLCandlePoint?,
        window: KLVisibleWindow
    ) -> KXUI03CrosshairHit? {
        guard !candles.isEmpty else { return nil }

        // 1. 反查最近 K 线 index（取 index 后再通过 window 找 candles 中的对应位置）
        let nearestIndex = KXUI03CrosshairDataAdapter._nearestIndex(atX: screenPoint.x, in: window, clampToWindow: true)
        guard let nearestIndex else { return nil }

        // 2. 在 candles 数组中找到匹配的 candle
        guard let matched = findCandle(at: nearestIndex, in: candles, window: window) else { return nil }

        let matchedCandle = matched.candle
        let matchedArrayIndex = matched.arrayIndex

        // 3. 计算该 K 线的准确 X 坐标（中心）
        let candleCenterX = KXUI03CrosshairDataAdapter._x(forIndex: nearestIndex, in: window, allowOutside: false)

        // 4. 尝试触线吸附
        let snapResult = tryExtremeSnap(
            screenPoint: screenPoint,
            candles: candles,
            matchedCandle: matchedCandle,
            matchedArrayIndex: matchedArrayIndex,
            matchedIndex: nearestIndex,
            window: window
        )

        // 5. 确认吸附后的屏幕坐标
        let snappedX: Double
        let snappedY: Double
        let isSnappedToExtreme: Bool
        let snappedExtremeKind: KXUI03SnapKind?

        if let snapResult {
            snappedX = snapResult.point.x
            snappedY = snapResult.point.y
            isSnappedToExtreme = true
            snappedExtremeKind = snapResult.kind
        } else {
            // 没有触线吸附：吸附到最近 K 线中心 X，Y 取 cursor Y
            snappedX = candleCenterX ?? screenPoint.x
            snappedY = screenPoint.y
            isSnappedToExtreme = false
            snappedExtremeKind = nil
        }

        let snappedPoint = KLChartPoint(x: snappedX, y: snappedY)

        // 6. 反查吸附点的价格
        let snappedPrice: KXDecimal
        if isSnappedToExtreme {
            // 触线吸附模式：价格已在 snapResult 中确定
            switch snapResult!.kind {
            case .high: snappedPrice = matchedCandle.high
            case .low:  snappedPrice = matchedCandle.low
            case .open: snappedPrice = matchedCandle.open
            case .close: snappedPrice = matchedCandle.close
            case .volumeSpike: snappedPrice = matchedCandle.close
            case .customPrice, .candleMidpoint, .none: snappedPrice = matchedCandle.close
            }
        } else {
            // 普通模式：由 cursor Y 反查价格
            snappedPrice = KXUI03CrosshairDataAdapter._price(atY: screenPoint.y, in: window, clampToRange: true)
                ?? matchedCandle.close
        }

        // 7. 组装各标签
        let timeLabel = makeTimeLabel(for: matchedCandle.openTime, anchorX: snappedX, viewportWidth: window.viewportWidth)
        let priceLabel = makePriceLabel(
            for: snappedPrice,
            anchorY: snappedY,
            viewportHeight: window.viewportHeight,
            previousCandle: previousCandle
        )
        let volumeLabel = makeVolumeLabel(for: matchedCandle.volume, in: candles, viewportHeight: window.viewportHeight)
        let ohlcSummary = makeOHLCSummary(candle: matchedCandle, previousCandle: previousCandle)
        let deviation = computeDeviation(screenPoint: screenPoint, snappedPoint: snappedPoint)

        let isSnapped = candleCenterX.map { abs(screenPoint.x - $0) <= 0.001 } ?? false
        let actualIsSnapped = isSnapped || isSnappedToExtreme

        return KXUI03CrosshairHit(
            candle: matchedCandle,
            candleIndex: nearestIndex,
            screenPoint: screenPoint,
            snappedPoint: snappedPoint,
            timeLabel: timeLabel,
            priceLabel: priceLabel,
            volumeLabel: volumeLabel,
            ohlcSummary: ohlcSummary,
            deviation: deviation,
            isSnapped: actualIsSnapped,
            visibleWindow: window,
            isSnappedToExtreme: isSnappedToExtreme,
            snappedExtremeKind: snappedExtremeKind
        )
    }
}

// MARK: - 触线吸附

private extension KXUI03CrosshairDataAdapter {
    /// 尝试在光标附近触线吸附到 K 线高点/低点/开/收盘。
    /// 返回 (吸附点坐标, 吸附类型)。如果没触发吸附则返回 nil。
    func tryExtremeSnap(
        screenPoint: KLChartPoint,
        candles: [KLCandlePoint],
        matchedCandle: KLCandlePoint,
        matchedArrayIndex: Int,
        matchedIndex: Int,
        window: KLVisibleWindow
    ) -> (point: KLChartPoint, kind: KXUI03SnapKind)? {
        guard extremeSnapEnabled else { return nil }

        // 构造该 K 线的几个可吸附点
        let candidates: [(price: KXDecimal, kind: KXUI03SnapKind)] = [
            (matchedCandle.high, .high),
            (matchedCandle.low, .low),
            (matchedCandle.open, .open),
            (matchedCandle.close, .close)
        ]

        // 找出 Y 距离最近的吸附点
        var best: (y: Double, dx: Double, kind: KXUI03SnapKind)? = nil
        var bestPxDistance: Double = extremeSnapThresholdPixels

        for candidate in candidates {
            // 目标 Y
            guard let targetY = KXUI03CrosshairDataAdapter._y(forPrice: candidate.price, in: window, clampToViewport: false)
            else { continue }

            // 目标 X 为 K 线中心
            guard let targetX = KXUI03CrosshairDataAdapter._x(forIndex: matchedIndex, in: window, allowOutside: false)
            else { continue }

            let dx = abs(screenPoint.x - targetX)
            let dy = abs(screenPoint.y - targetY)
            let distance = sqrt(dx * dx + dy * dy)

            // 如果水平超出半根 K 线宽度则跳过（防止吸附到错误的 K 线）
            if dx > window.candleWidth * 0.5 { continue }

            if distance < bestPxDistance {
                bestPxDistance = distance
                best = (y: targetY, dx: dx, kind: candidate.kind)
            }
        }

        guard let best else { return nil }

        let centerX = KXUI03CrosshairDataAdapter._x(forIndex: matchedIndex, in: window, allowOutside: false) ?? screenPoint.x
        return (point: KLChartPoint(x: centerX, y: best.y), kind: best.kind)
    }

    /// 检查某根 K 线的成交量是否为局部极值（大于前后各一根）。
    func isLocalVolumeExtreme(at index: Int, in candles: [KLCandlePoint]) -> Bool {
        guard index >= 0, index < candles.count else { return false }
        let current = NSDecimalNumber(decimal: candles[index].volume).doubleValue

        let prevVolume: Double = (index > 0)
            ? NSDecimalNumber(decimal: candles[index - 1].volume).doubleValue
            : current
        let nextVolume: Double = (index < candles.count - 1)
            ? NSDecimalNumber(decimal: candles[index + 1].volume).doubleValue
            : current

        return current > prevVolume && current > nextVolume
    }
}

// MARK: - 内部辅助

private extension KXUI03CrosshairDataAdapter {
    /// 在 candles 数组中寻找 index 匹配的 K 线。
    /// 优先通过 window.timeRange 的时间匹配，其次通过数组偏移。
    func findCandle(at chartIndex: Int, in candles: [KLCandlePoint], window: KLVisibleWindow) -> (candle: KLCandlePoint, arrayIndex: Int)? {
        // 优先通过时间匹配
        if let timeRange = window.timeRange {
            let estimatedTime = timeRange.startTime.addingTimeInterval(
                Double(chartIndex - window.indexRange.startIndex) * timeframeSeconds(window.timeframe)
            )
            // 在 candles 中找最接近的时间
            var best: (candle: KLCandlePoint, index: Int, diff: TimeInterval)? = nil
            for (i, c) in candles.enumerated() {
                let diff = abs(c.openTime.timeIntervalSince(estimatedTime))
                if diff < (best?.diff ?? .infinity) {
                    best = (c, i, diff)
                }
            }
            if let best, best.diff < timeframeSeconds(window.timeframe) * 2 {
                return (candle: best.candle, arrayIndex: best.index)
            }
        }

        // 降级：通过数组偏移匹配
        let arrayOffset = chartIndex - window.indexRange.startIndex
        guard arrayOffset >= 0, arrayOffset < candles.count else { return nil }
        return (candle: candles[arrayOffset], arrayIndex: arrayOffset)
    }

    /// 周期对应秒数（简化实现，只覆盖主要周期）
    func timeframeSeconds(_ tf: KXTimeframe) -> Double {
        switch tf {
        case .oneSecond:       return 1
        case .oneMinute:       return 60
        case .threeMinutes:    return 180
        case .fiveMinutes:     return 300
        case .fifteenMinutes:  return 900
        case .thirtyMinutes:   return 1800
        case .oneHour:         return 3600
        case .twoHours:        return 7200
        case .fourHours:       return 14400
        case .sixHours:        return 21600
        case .twelveHours:     return 43200
        case .oneDay:          return 86400
        case .twoDays:         return 172800
        case .threeDays:       return 259200
        case .oneWeek:         return 604800
        case .oneMonth:        return 2592000
        case .threeMonths:     return 0
        }
    }

    /// 构建 X 轴时间标签
    func makeTimeLabel(for time: Date, anchorX: Double, viewportWidth: Double) -> KXUI03TimeAxisLabel {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")

        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: time)

        dateFormatter.dateFormat = "HH:mm"
        let timeString = dateFormatter.string(from: time)

        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let fullString = dateFormatter.string(from: time)

        // 可见性检查：anchorX 在 [-50, viewportWidth + 50] 之间（50pt 缓冲）
        let isVisible = anchorX >= -50 && anchorX <= viewportWidth + 50

        return KXUI03TimeAxisLabel(
            dateString: dateString,
            timeString: timeString,
            fullString: fullString,
            anchorX: anchorX,
            isVisible: isVisible
        )
    }

    /// 构建 Y 轴价格标签
    func makePriceLabel(
        for price: KXDecimal,
        anchorY: Double,
        viewportHeight: Double,
        previousCandle: KLCandlePoint?
    ) -> KXUI03PriceAxisLabel {
        let formatted = formatPrice(price)
        let direction: String

        if let prev = previousCandle {
            let diff = price - prev.close
            if diff > 0 {
                direction = "up"
            } else if diff < 0 {
                direction = "down"
            } else {
                direction = "flat"
            }
        } else {
            direction = "flat"
        }

        // 可见性：anchorY 在 [-50, viewportHeight + 50] 之间
        let isVisible = anchorY >= -50 && anchorY <= viewportHeight + 50

        return KXUI03PriceAxisLabel(
            price: price,
            formattedPrice: formatted,
            direction: direction,
            anchorY: anchorY,
            isVisible: isVisible
        )
    }

    /// 构建成交量标签
    func makeVolumeLabel(
        for volume: KXDecimal,
        in candles: [KLCandlePoint],
        viewportHeight: Double
    ) -> KXUI03VolumeLabel {
        let formatted = formatVolume(volume)

        // 计算可视窗口内最大成交量
        let maxVolume = candles
            .map { NSDecimalNumber(decimal: $0.volume).doubleValue }
            .max() ?? 0

        // 成交量区域的 Y（假设图表底部 20% 为成交量区）
        let volumeAreaHeight = viewportHeight * 0.2
        let volumeAreaTop = viewportHeight - volumeAreaHeight

        // 成交量柱比率
        let volDouble = NSDecimalNumber(decimal: volume).doubleValue
        let ratio: Double = maxVolume > 0 ? min(volDouble / maxVolume, 1.0) : 0
        let anchorY = volumeAreaTop + volumeAreaHeight * (1 - ratio)

        return KXUI03VolumeLabel(
            volume: volume,
            formattedVolume: formatted,
            anchorY: anchorY,
            volumeRatio: ratio
        )
    }

    /// 构建 OHLC 摘要
    func makeOHLCSummary(candle: KLCandlePoint, previousCandle: KLCandlePoint?) -> KXUI03OHLCSummary {
        let open = candle.open
        let high = candle.high
        let low = candle.low
        let close = candle.close

        var changePercent: Double = 0
        var changeAmount: KXDecimal = 0

        if let prev = previousCandle, prev.close != 0 {
            let prevClose = NSDecimalNumber(decimal: prev.close).doubleValue
            let curClose = NSDecimalNumber(decimal: close).doubleValue
            if prevClose > 0 {
                changePercent = ((curClose - prevClose) / prevClose) * 100
            }
            changeAmount = close - prev.close
        }

        // 实体占振幅比例
        let range = NSDecimalNumber(decimal: high - low).doubleValue
        let body = NSDecimalNumber(decimal: abs(close - open)).doubleValue
        let bodyRatio: Double = range > 0 ? min(body / range, 1.0) : 0

        return KXUI03OHLCSummary(
            open: open,
            high: high,
            low: low,
            close: close,
            changePercent: changePercent,
            changeAmount: changeAmount,
            bodyRatio: bodyRatio
        )
    }

    /// 计算屏幕偏移量
    func computeDeviation(screenPoint: KLChartPoint, snappedPoint: KLChartPoint) -> KXUI03Deviation {
        let dx = abs(screenPoint.x - snappedPoint.x)
        let dy = abs(screenPoint.y - snappedPoint.y)
        let total = sqrt(dx * dx + dy * dy)
        return KXUI03Deviation(horizontalPixels: dx, verticalPixels: dy, totalPixels: total)
    }
}

// MARK: - 格式化工具（纯函数）

private extension KXUI03CrosshairDataAdapter {
    /// 格式化价格：保留合理精度，不截断位数。
    func formatPrice(_ price: KXDecimal) -> String {
        let doubleVal = NSDecimalNumber(decimal: price).doubleValue
        guard doubleVal.isFinite else { return "--" }

        // 根据价格量级自适应精度
        let precision: Int
        if doubleVal >= 10000 {
            precision = 2 // 大数只保留两位小数
        } else if doubleVal >= 1 {
            precision = 4
        } else if doubleVal >= 0.01 {
            precision = 6
        } else {
            precision = 8
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = precision
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "\(price)"
    }

    /// 格式化成交量：自动选择 K/M/B 单位。
    func formatVolume(_ volume: KXDecimal) -> String {
        let doubleVal = NSDecimalNumber(decimal: volume).doubleValue
        guard doubleVal.isFinite, doubleVal > 0 else { return "0" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "zh_CN")

        if doubleVal >= 1_000_000_000 {
            formatter.maximumFractionDigits = 2
            return (formatter.string(from: NSNumber(value: doubleVal / 1_000_000_000)).map { "\($0)B" } ?? "--B")
        } else if doubleVal >= 1_000_000 {
            formatter.maximumFractionDigits = 2
            return (formatter.string(from: NSNumber(value: doubleVal / 1_000_000)).map { "\($0)M" } ?? "--M")
        } else if doubleVal >= 1_000 {
            formatter.maximumFractionDigits = 1
            return (formatter.string(from: NSNumber(value: doubleVal / 1_000)).map { "\($0)K" } ?? "--K")
        } else {
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSDecimalNumber(decimal: volume)) ?? "\(volume)"
        }
    }
}

// MARK: - 便利查询（类方法）

extension KXUI03CrosshairDataAdapter {
    /// 类方法：快捷查询。默认使用 `extremeSnapThresholdPixels: 6.0, extremeSnapEnabled: true`。
    public static func query(
        at screenPoint: KLChartPoint,
        candles: [KLCandlePoint],
        previousCandle: KLCandlePoint?,
        window: KLVisibleWindow,
        extremeSnapThresholdPixels: Double = 6.0,
        extremeSnapEnabled: Bool = true
    ) -> KXUI03CrosshairHit? {
        let adapter = KXUI03CrosshairDataAdapter(
            extremeSnapThresholdPixels: extremeSnapThresholdPixels,
            extremeSnapEnabled: extremeSnapEnabled
        )
        return adapter.query(at: screenPoint, candles: candles, previousCandle: previousCandle, window: window)
    }
}

// MARK: - 十字光标快照组装

extension KXUI03CrosshairDataAdapter {
    /// 从 `KXUI03CrosshairHit` 组装 `KLCrosshairSnapshot`，供 UI 层直接消费。
    public static func makeSnapshot(from hit: KXUI03CrosshairHit) -> KLCrosshairSnapshot {
        let coordinate = KLChartCoordinate(
            time: hit.candle.openTime,
            index: hit.candleIndex,
            price: hit.priceLabel.price,
            point: hit.snappedPoint
        )
        return KLCrosshairSnapshot(
            coordinate: coordinate,
            candle: hit.candle,
            visibleWindow: hit.visibleWindow
        )
    }
}

// MARK: - 批量查询（拖拽/滑动连续反馈）

extension KXUI03CrosshairDataAdapter {
    /// 批量查询多个光标位置，常用于拖拽滑动连续反馈。
    /// - Parameters:
    ///   - screenPoints: 光标位置的数组
    ///   - candles: 当前可视窗口范围内的 KLCandlePoint 数组
    ///   - previousCandle: 前一根 K 线
    ///   - window: 当前可视窗口
    ///   - deduplicate: 是否对同一 K 线去重（默认 true，避免同一 K 线重复计算）
    /// - Returns: 去重后的命中结果数组（按 K 线 index 升序）
    public func batchQuery(
        at screenPoints: [KLChartPoint],
        candles: [KLCandlePoint],
        previousCandle: KLCandlePoint?,
        window: KLVisibleWindow,
        deduplicate: Bool = true
    ) -> [KXUI03CrosshairHit] {
        var results: [KXUI03CrosshairHit] = []
        results.reserveCapacity(screenPoints.count)

        for point in screenPoints {
            guard let hit = query(at: point, candles: candles, previousCandle: previousCandle, window: window)
            else { continue }
            results.append(hit)
        }

        guard deduplicate else { return results }

        // 按 candleIndex 去重，保留第一次出现
        var seen = Set<Int>()
        return results.filter { seen.insert($0.candleIndex).inserted }
            .sorted { $0.candleIndex < $1.candleIndex }
    }
}
