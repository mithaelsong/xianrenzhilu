//
//  KX-UI-04_画线工具适配.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：为画线工具提供吸附点和坐标转换数据
//  禁止事项：禁止实现画线工具管理器、禁止 UI 绘制、禁止网络请求、禁止数据库读写
//  依赖规则：仅依赖 KL-02 公共类型，不依赖任何功能层/数据层文件
//

import Foundation


// MARK: - 画线工具数据适配骨架

public struct KXUI04Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-04",
        fileName: "KX-UI-04_画线工具数据适配.swift",
        layer: .uiAdapter,
        relativePath: "UI数据适配层/KX-UI-04_画线工具数据适配.swift",
        duty: "为画线工具提供吸附点和坐标转换数据"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "画线工具数据适配", passed: true, message: "已实现画线工具坐标点 DTO、吸附阈值适配、吸附点排序、距离计算、线类型提示、自包含坐标映射")
    }

    public static func placeholder() {
        // 本文件已补充纯逻辑实现：画线工具的 DTO、吸附适配器、坐标转换、距离计算、线类型枚举。
        // 不包含 UI 绘制、画线工具管理器、网络请求、数据库读写。
    }
}

// MARK: - 画线工具线类型

public enum KXUI04LineKind: String, Codable, Sendable, CaseIterable, Hashable {
    /// 趋势线
    case trend
    /// 水平线
    case horizontal
    /// 垂直线
    case vertical
    /// 平行通道
    case parallelChannel
    /// 斐波那契回撤
    case fibonacciRetracement
    /// 斐波那契扩展
    case fibonacciExtension
    /// 射线（从起点出发向右延伸）
    case ray
    /// 箭头标记线
    case arrow
    /// 自定义线段
    case custom

    /// 是否为需要至少2个锚点的线型
    public var requiresTwoOrMoreAnchors: Bool {
        switch self {
        case .trend, .parallelChannel, .ray:
            return true
        case .fibonacciRetracement, .fibonacciExtension:
            return true
        default:
            return false
        }
    }

    /// 是否为水平/垂直单锚点线
    public var isSingleAnchorLine: Bool {
        switch self {
        case .horizontal, .vertical:
            return true
        default:
            return false
        }
    }
}

// MARK: - 画线锚点 DTO

/// 画线工具中的一个锚点。UI 通过此 DTO 获取需要在屏幕上渲染的锚点信息。
public struct KXUI04AnchorPoint: Codable, Equatable, Sendable {
    /// 锚点的吸附源（来自哪根 K线的什么价位）
    public let snapKind: KXUI04SnapKind
    /// 图表坐标（时间/index/价格/屏幕点）
    public let chartCoordinate: KLChartCoordinate
    /// 绑定到此锚点的 K线 ID（如有）
    public let candleID: KLCandleID?
    /// 用户自定义偏移（气泡、标签位置微调）
    public let labelOffset: KLChartPoint?

    public init(
        snapKind: KXUI04SnapKind,
        chartCoordinate: KLChartCoordinate,
        candleID: KLCandleID? = nil,
        labelOffset: KLChartPoint? = nil
    ) {
        self.snapKind = snapKind
        self.chartCoordinate = chartCoordinate
        self.candleID = candleID
        self.labelOffset = labelOffset
    }
}

// MARK: - 画线点 DTO

/// 画线工具中一个已确认的坐标点（包含锚点信息和用户可编辑的位置）。
public struct KXUI04DrawingPoint: Codable, Equatable, Sendable {
    /// 此点在画线段中的序号
    public let sequenceNumber: Int
    /// 锚点信息
    public let anchor: KXUI04AnchorPoint
    /// 用户手动调整后的偏移（屏幕坐标偏移量，用于微调）
    public let userOffset: KLChartPoint?
    /// 此点是否为锁定状态（UI 不应拖动）
    public let isLocked: Bool

    public init(
        sequenceNumber: Int,
        anchor: KXUI04AnchorPoint,
        userOffset: KLChartPoint? = nil,
        isLocked: Bool = false
    ) {
        self.sequenceNumber = sequenceNumber
        self.anchor = anchor
        self.userOffset = userOffset
        self.isLocked = isLocked
    }

    /// 此点的最终屏幕坐标（chartCoordinate + userOffset）
    public func finalScreenPoint() -> KLChartPoint? {
        guard let basePoint = anchor.chartCoordinate.point else { return nil }
        guard let offset = userOffset else { return basePoint }
        return KLChartPoint(x: basePoint.x + offset.x, y: basePoint.y + offset.y)
    }
}

// MARK: - 吸附类型枚举

/// 画线工具锚点吸附的价位类型
public enum KXUI04SnapKind: String, Codable, Sendable, CaseIterable, Hashable {
    case high
    case low
    case open
    case close
    case volumeSpike
    case customPrice
    case candleMidpoint
    case none
}

// MARK: - 吸附阈值配置

/// 画线工具吸附行为的阈值配置，仅使用 KL-02 公共类型，不依赖功能层。
public struct KXUI04SnapConfig: Codable, Equatable, Sendable {
    /// 屏幕坐标吸附阈值（点）
    public let maxPointDistance: Double
    /// 是否启用价格吸附
    public let enablePriceSnap: Bool
    /// 是否启用时间吸附
    public let enableTimeSnap: Bool
    /// 是否启用 Index 吸附
    public let enableIndexSnap: Bool
    /// 可吸附价位类型
    public let allowedSnapKinds: Set<KXUI04SnapKind>
    /// 启用成交量异常点吸附
    public let enableVolumeSpikeSnap: Bool

    public static let `default` = KXUI04SnapConfig()

    public init(
        maxPointDistance: Double = 12,
        enablePriceSnap: Bool = true,
        enableTimeSnap: Bool = true,
        enableIndexSnap: Bool = true,
        allowedSnapKinds: Set<KXUI04SnapKind> = [.high, .low, .open, .close],
        enableVolumeSpikeSnap: Bool = false
    ) {
        self.maxPointDistance = maxPointDistance
        self.enablePriceSnap = enablePriceSnap
        self.enableTimeSnap = enableTimeSnap
        self.enableIndexSnap = enableIndexSnap
        self.allowedSnapKinds = allowedSnapKinds
        self.enableVolumeSpikeSnap = enableVolumeSpikeSnap
    }
}

// MARK: - 吸附结果排序

/// 排序策略
public enum KXUI04SortStrategy: String, Sendable, CaseIterable {
    /// 按距离升序（最近优先）
    case byDistance
    /// 按价格升序
    case byPrice
    /// 按时间升序
    case byTime
    /// 按 K线 index 升序
    case byIndex
}

/// 吸附结果排序描述
public struct KXUI04SortDescriptor: Sendable {
    public let strategy: KXUI04SortStrategy
    public let ascending: Bool

    public init(strategy: KXUI04SortStrategy = .byDistance, ascending: Bool = true) {
        self.strategy = strategy
        self.ascending = ascending
    }

    public static let nearest = KXUI04SortDescriptor(strategy: .byDistance, ascending: true)
}

// MARK: - 坐标点距离计算

public enum KXUI04DistanceCalculator: Sendable {
    /// 两点之间的欧几里得距离（屏幕坐标）
    public static func euclideanDistance(from a: KLChartPoint, to b: KLChartPoint) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// 点到水平线的垂直距离
    public static func verticalDistance(from point: KLChartPoint, to y: Double) -> Double {
        abs(point.y - y)
    }

    /// 点到垂直线的水平距离
    public static func horizontalDistance(from point: KLChartPoint, to x: Double) -> Double {
        abs(point.x - x)
    }

    /// 两点之间的价格差绝对值（需有有效价格）
    public static func priceDistance(_ lhs: KXDecimal, _ rhs: KXDecimal) -> KXDecimal {
        abs(lhs - rhs)
    }

    /// 两点之间的时间间隔（秒）
    public static func timeDistance(_ lhs: Date, _ rhs: Date) -> TimeInterval {
        abs(lhs.timeIntervalSince(rhs))
    }
}

// MARK: - 画线吸附适配器（自包含，不依赖功能层）

/// 画线工具的吸附数据适配器。自包含实现，不依赖 KX-FN-10 / KX-FN-11 等功能层文件。
public struct KXUI04SnapAdapter: Sendable {

    public init() {}

    // MARK: 本地坐标映射（替代对 KXFN10CoordinateMapper 的依赖）

    /// 通过 index 计算 x 坐标
    public static func x(forIndex index: Int, in window: KLVisibleWindow) -> Double? {
        guard window.candleWidth.isFinite, window.candleWidth > 0,
              window.indexRange.startIndex <= window.indexRange.endIndex,
              window.contentOffsetX.isFinite else { return nil }
        return (Double(index - window.indexRange.startIndex) + 0.5) * window.candleWidth - window.contentOffsetX
    }

    /// 通过 index 计算 x 坐标（可选是否允许超出窗口范围）
    public static func x(forIndex index: Int, in window: KLVisibleWindow, allowOutside: Bool) -> Double? {
        if !allowOutside {
            guard index >= window.indexRange.startIndex, index <= window.indexRange.endIndex else { return nil }
        }
        return x(forIndex: index, in: window)
    }

    /// 通过屏幕 x 反查最近 index
    public static func nearestIndex(atX x: Double, in window: KLVisibleWindow, clampToWindow: Bool) -> Int? {
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
    public static func y(forPrice price: KXDecimal, in window: KLVisibleWindow, clampToViewport: Bool = true) -> Double? {
        guard let priceRange = window.priceRange, window.viewportHeight.isFinite, window.viewportHeight > 0 else { return nil }
        let minP = min(priceRange.minPrice, priceRange.maxPrice)
        let maxP = max(priceRange.minPrice, priceRange.maxPrice)
        let pv = NSDecimalNumber(decimal: price).doubleValue
        let minD = NSDecimalNumber(decimal: minP).doubleValue
        let maxD = NSDecimalNumber(decimal: maxP).doubleValue
        guard pv.isFinite, minD.isFinite, maxD.isFinite, (maxD - minD) != 0 else { return nil }
        let rawY = (maxD - pv) / (maxD - minD) * window.viewportHeight
        if clampToViewport {
            return max(0, min(window.viewportHeight, rawY))
        }
        return rawY
    }

    /// y → 价格
    public static func price(atY y: Double, in window: KLVisibleWindow, clampToRange: Bool = true) -> KXDecimal? {
        guard let priceRange = window.priceRange, window.viewportHeight.isFinite, window.viewportHeight > 0 else { return nil }
        let minP = NSDecimalNumber(decimal: min(priceRange.minPrice, priceRange.maxPrice)).doubleValue
        let maxP = NSDecimalNumber(decimal: max(priceRange.minPrice, priceRange.maxPrice)).doubleValue
        guard minP.isFinite, maxP.isFinite, y.isFinite else { return nil }
        let ratio = y / window.viewportHeight
        return NSDecimalNumber(value: maxP - ratio * (maxP - minP)).decimalValue
    }

    /// 将屏幕坐标反查为图表坐标（不吸附，仅坐标转换）
    public static func chartCoordinate(
        at screenPoint: KLChartPoint,
        in window: KLVisibleWindow
    ) -> KLChartCoordinate {
        guard let index = nearestIndex(atX: screenPoint.x, in: window, clampToWindow: true),
              let price = price(atY: screenPoint.y, in: window, clampToRange: true) else {
            return KLChartCoordinate(time: nil, index: nil, price: nil, point: screenPoint)
        }
        return KLChartCoordinate(
            time: nil,
            index: index,
            price: price,
            point: KLChartPoint(x: screenPoint.x, y: screenPoint.y)
        )
    }

    /// 将 index + 价格转换为屏幕坐标
    public static func screenCoordinate(
        index: Int,
        price: KXDecimal,
        in window: KLVisibleWindow
    ) -> KLChartCoordinate {
        let pointX = x(forIndex: index, in: window, allowOutside: false)
        let pointY = y(forPrice: price, in: window, clampToViewport: false)
        if let px = pointX, let py = pointY {
            return KLChartCoordinate(
                time: nil,
                index: index,
                price: price,
                point: KLChartPoint(x: px, y: py)
            )
        }
        return KLChartCoordinate(time: nil, index: index, price: price, point: nil)
    }

    // MARK: 吸附功能（自包含，不依赖 KX-FN-11）

    /// 从 K线数组中提取所有可吸附点，转为 UI 友好的 KXUI04AnchorPoint 数组。
    /// 自包含实现，不依赖 KXFN11SnapPointDataSource。
    public func anchorCandidates(
        from candles: [KLCandlePoint],
        in window: KLVisibleWindow?,
        snapConfig: KXUI04SnapConfig = .default
    ) -> [KXUI04AnchorPoint] {
        guard let window else {
            return fallbackNoWindowAnchors(from: candles, snapConfig: snapConfig)
        }

        return candles.enumerated().flatMap { (index, candle) -> [KXUI04AnchorPoint] in
            var anchors: [KXUI04AnchorPoint] = []
            let allowed = snapConfig.allowedSnapKinds
            let hasVolumeSpike = snapConfig.enableVolumeSpikeSnap && allowed.contains(.volumeSpike)

            for kind in allowed {
                let price: KXDecimal?
                switch kind {
                case .high:       price = candle.high
                case .low:        price = candle.low
                case .open:       price = candle.open
                case .close:      price = candle.close
                case .volumeSpike:
                    price = nil // 成交量异常点在后续处理
                case .customPrice,
                     .candleMidpoint,
                     .none:
                    price = nil
                }
                if let p = price {
                    let coord = KXUI04SnapAdapter.screenCoordinate(index: index, price: p, in: window)
                    anchors.append(
                        KXUI04AnchorPoint(
                            snapKind: kind,
                            chartCoordinate: coord,
                            candleID: candle.id,
                            labelOffset: nil
                        )
                    )
                }
            }

            // 如果启用了成交量异常吸附，生成一个自定义标签的锚点
            if hasVolumeSpike {
                let coord = KXUI04SnapAdapter.screenCoordinate(
                    index: index,
                    price: candle.close,
                    in: window
                )
                anchors.append(
                    KXUI04AnchorPoint(
                        snapKind: .volumeSpike,
                        chartCoordinate: coord,
                        candleID: candle.id,
                        labelOffset: nil
                    )
                )
            }

            return anchors
        }
    }

    /// 在已有吸附点中查找离输入屏幕点最近的锚点。
    public func nearestAnchor(
        in candidates: [KXUI04AnchorPoint],
        from screenPoint: KLChartPoint,
        snapConfig: KXUI04SnapConfig = .default
    ) -> KXUI04AnchorPoint? {
        let sorted = sortedAnchors(candidates, from: screenPoint, strategy: .byDistance)
        return sorted.first { candidate in
            guard let point = candidate.chartCoordinate.point else { return false }
            let distance = KXUI04DistanceCalculator.euclideanDistance(from: screenPoint, to: point)
            return distance <= snapConfig.maxPointDistance
        }
    }

    /// 在 K线数组中一步查找输入屏幕点的最近吸附锚点。
    public func nearestAnchor(
        from screenPoint: KLChartPoint,
        candles: [KLCandlePoint],
        in window: KLVisibleWindow,
        snapConfig: KXUI04SnapConfig = .default
    ) -> KXUI04AnchorPoint? {
        let candidates = anchorCandidates(from: candles, in: window, snapConfig: snapConfig)
        return nearestAnchor(in: candidates, from: screenPoint, snapConfig: snapConfig)
    }
}

// MARK: - 排序扩展

public extension KXUI04SnapAdapter {
    /// 对吸附锚点数组按指定策略排序
    func sortedAnchors(
        _ anchors: [KXUI04AnchorPoint],
        from referencePoint: KLChartPoint,
        strategy: KXUI04SortStrategy = .byDistance,
        ascending: Bool = true
    ) -> [KXUI04AnchorPoint] {
        anchors.sorted { lhs, rhs in
            let comparison: Bool
            switch strategy {
            case .byDistance:
                let ld = lhs.chartCoordinate.point.flatMap { KXUI04DistanceCalculator.euclideanDistance(from: referencePoint, to: $0) } ?? .greatestFiniteMagnitude
                let rd = rhs.chartCoordinate.point.flatMap { KXUI04DistanceCalculator.euclideanDistance(from: referencePoint, to: $0) } ?? .greatestFiniteMagnitude
                comparison = ld < rd
            case .byPrice:
                let lp = lhs.chartCoordinate.price ?? KXDecimal(0)
                let rp = rhs.chartCoordinate.price ?? KXDecimal(0)
                comparison = lp < rp
            case .byTime:
                let lt = lhs.chartCoordinate.time ?? Date.distantPast
                let rt = rhs.chartCoordinate.time ?? Date.distantPast
                comparison = lt < rt
            case .byIndex:
                let li = lhs.chartCoordinate.index ?? Int.max
                let ri = rhs.chartCoordinate.index ?? Int.max
                comparison = li < ri
            }
            return ascending ? comparison : !comparison
        }
    }
}

// MARK: - 线型提示数据

public extension KXUI04LineKind {
    /// 线型的中文名称（供 UI 显示）
    var displayNameCN: String {
        switch self {
        case .trend:               return "趋势线"
        case .horizontal:          return "水平线"
        case .vertical:            return "垂直线"
        case .parallelChannel:     return "平行通道"
        case .fibonacciRetracement: return "斐波那契回撤"
        case .fibonacciExtension:  return "斐波那契扩展"
        case .ray:                 return "射线"
        case .arrow:               return "箭头"
        case .custom:              return "自定义"
        }
    }

    /// 线型对应的锚点最小数量
    var minimumAnchorCount: Int {
        switch self {
        case .trend:               return 2
        case .horizontal:          return 1
        case .vertical:            return 1
        case .parallelChannel:     return 2
        case .fibonacciRetracement: return 2
        case .fibonacciExtension:  return 2
        case .ray:                 return 2
        case .arrow:               return 1
        case .custom:              return 1
        }
    }

    /// 是否需要价格信息
    var requiresPriceData: Bool {
        switch self {
        case .horizontal, .fibonacciRetracement, .fibonacciExtension:
            return true
        default:
            return false
        }
    }
}

// MARK: - 内部辅助

private extension KXUI04SnapAdapter {
    /// 当 window 为 nil 时的兜底：直接用 K线数据生成锚点（不含屏幕坐标）
    func fallbackNoWindowAnchors(from candles: [KLCandlePoint], snapConfig: KXUI04SnapConfig) -> [KXUI04AnchorPoint] {
        candles.enumerated().flatMap { (index, candle) -> [KXUI04AnchorPoint] in
            var anchors: [KXUI04AnchorPoint] = []
            let allowed = snapConfig.allowedSnapKinds
            for kind in allowed {
                let price: KXDecimal?
                switch kind {
                case .high:  price = candle.high
                case .low:   price = candle.low
                case .open:  price = candle.open
                case .close: price = candle.close
                default:     price = nil
                }
                guard let price else { continue }
                anchors.append(
                    KXUI04AnchorPoint(
                        snapKind: kind,
                        chartCoordinate: KLChartCoordinate(
                            time: candle.openTime,
                            index: index,
                            price: price,
                            point: nil
                        ),
                        candleID: candle.id
                    )
                )
            }
            return anchors
        }
    }
}
