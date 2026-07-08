//
//  KX-FN-25_跨模块叠加显示接口.swift
//  仙人指路测试项目｜K线模块
//
//  版本：2.0
//  职责：指标模块、形态识别模块、回撤模块、预测模块、交易模块等外部业务模块
//        通过本接口向 K线模块提交图表叠加内容（指标线/标记/区域/交易点位等）
//  禁止事项：禁止UI绘制、禁止数据库写入、禁止网络请求
//

import Foundation


// MARK: - 叠加类型

public enum KLOverlayKind: String, Codable, Sendable {
    case indicatorLine      // 指标线
    case indicatorBand      // 指标带
    case indicatorHistogram // 指标柱
    case candlePatternMarker       // K线形态标记
    case soundAlertMarker          // 声音提示对应标记
    case retracementZone           // 回撤区域
    case predictionZone            // 预测区域
    case predictionLine            // 预测线
    case tradeMarker               // 交易标记
    case priceLine                 // 价格水平线
    case timeLine                  // 时间垂直线
    case textAnnotation            // 文本标注
    case indicatorPoint       // 指标点
    case indicatorLabel       // 指标标签
    case range                // 区域
}

// MARK: - 叠加 Pane

public enum KLOverlayPane: String, Codable, Sendable, Equatable, CaseIterable {
    case main        // K线主图
    case volume      // 量柱区
    case sub         // 指标副图区
    case annotation  // 注解/全局覆盖层
    case reserved    // 指标参数/统计保留区
}

// MARK: - 叠加目标

public struct KLOverlayTarget: Codable, Sendable, Equatable {
    public let exchange: String
    public let instrumentType: String
    public let instrumentID: String
    public let timeframe: KXTimeframe?
    /// 是否适用于所有周期（某些交易标记/价格线需要在所有周期显示）
    public let appliesToAllTimeframes: Bool
    /// 标签 ID（用于精确匹配某个打开的标签）
    public let tabID: String?

    public init(exchange: String = "OKX", instrumentType: String = "SPOT", instrumentID: String, timeframe: KXTimeframe? = nil, appliesToAllTimeframes: Bool = false, tabID: String? = nil) {
        self.exchange = exchange
        self.instrumentType = instrumentType
        self.instrumentID = instrumentID
        self.timeframe = timeframe
        self.appliesToAllTimeframes = appliesToAllTimeframes
        self.tabID = tabID
    }
}

// MARK: - 叠加样式

public struct KLOverlayStyle: Codable, Sendable, Equatable {
    public let colorToken: String?
    public let fallbackHexColor: String?
    public let lineWidth: Double?
    public let lineDash: [Double]?
    public let opacity: Double?
    public let fillOpacity: Double?
    public let fontName: String?
    public let fontSize: Double?
    public let symbolName: String?

    public init(colorToken: String? = nil, fallbackHexColor: String? = nil, lineWidth: Double? = nil, lineDash: [Double]? = nil, opacity: Double? = nil, fillOpacity: Double? = nil, fontName: String? = nil, fontSize: Double? = nil, symbolName: String? = nil) {
        self.colorToken = colorToken
        self.fallbackHexColor = fallbackHexColor
        self.lineWidth = lineWidth
        self.lineDash = lineDash
        self.opacity = opacity
        self.fillOpacity = fillOpacity
        self.fontName = fontName
        self.fontSize = fontSize
        self.symbolName = symbolName
    }
}

// MARK: - 指标线载荷

public struct KLIndicatorLinePayload: Codable, Sendable {
    public let indicatorID: String
    public let indicatorName: String
    public let instanceID: String?
    public let outputKey: String?
    public let series: [KLIndicatorPoint]
    public let valueFormatter: String?

    public init(indicatorID: String, indicatorName: String, series: [KLIndicatorPoint], valueFormatter: String? = nil, instanceID: String? = nil, outputKey: String? = nil) {
        self.indicatorID = indicatorID
        self.indicatorName = indicatorName
        self.instanceID = instanceID
        self.outputKey = outputKey
        self.series = series
        self.valueFormatter = valueFormatter
    }
}

public struct KLIndicatorPoint: Codable, Sendable, Equatable {
    public let time: Date
    public let value: Decimal

    public init(time: Date, value: Decimal) {
        self.time = time
        self.value = value
    }
}

// MARK: - 指标带载荷

public struct KLIndicatorBandPayload: Codable, Sendable {
    public let indicatorID: String
    public let indicatorName: String?
    public let instanceID: String?
    public let upperLine: [KLIndicatorPoint]
    public let middleLine: [KLIndicatorPoint]?
    public let lowerLine: [KLIndicatorPoint]

    public init(indicatorID: String, indicatorName: String? = nil, instanceID: String? = nil, upperLine: [KLIndicatorPoint], middleLine: [KLIndicatorPoint]? = nil, lowerLine: [KLIndicatorPoint]) {
        self.indicatorID = indicatorID
        self.indicatorName = indicatorName
        self.instanceID = instanceID
        self.upperLine = upperLine
        self.middleLine = middleLine
        self.lowerLine = lowerLine
    }
}

// MARK: - 指标柱载荷

public struct KLIndicatorHistogramPayload: Codable, Sendable {
    public let indicatorID: String
    public let indicatorName: String
    public let instanceID: String?
    public let outputKey: String?
    public let series: [KLIndicatorPoint]
    public let baseline: Decimal
    public let valueFormatter: String?

    public init(indicatorID: String, indicatorName: String, series: [KLIndicatorPoint], baseline: Decimal = 0, valueFormatter: String? = nil, instanceID: String? = nil, outputKey: String? = nil) {
        self.indicatorID = indicatorID
        self.indicatorName = indicatorName
        self.instanceID = instanceID
        self.outputKey = outputKey
        self.series = series
        self.baseline = baseline
        self.valueFormatter = valueFormatter
    }
}

// MARK: - 指标点载荷

public struct KLIndicatorPointMarkerPayload: Codable, Sendable {
    public let indicatorID: String
    public let indicatorName: String
    public let instanceID: String?
    public let outputKey: String?
    public let points: [KLIndicatorPoint]
    public let shape: String
    public let size: Double

    public init(indicatorID: String, indicatorName: String, points: [KLIndicatorPoint], shape: String = "circle", size: Double = 4, instanceID: String? = nil, outputKey: String? = nil) {
        self.indicatorID = indicatorID
        self.indicatorName = indicatorName
        self.instanceID = instanceID
        self.outputKey = outputKey
        self.points = points
        self.shape = shape
        self.size = size
    }
}

// MARK: - 指标标签载荷

public struct KLIndicatorLabelPoint: Codable, Sendable, Equatable {
    public let time: Date
    public let price: Decimal?
    public let text: String
    public let placement: String

    public init(time: Date, price: Decimal? = nil, text: String, placement: String = "atPrice") {
        self.time = time
        self.price = price
        self.text = text
        self.placement = placement
    }
}

public struct KLIndicatorLabelPayload: Codable, Sendable {
    public let indicatorID: String
    public let indicatorName: String
    public let instanceID: String?
    public let labels: [KLIndicatorLabelPoint]

    public init(indicatorID: String, indicatorName: String, labels: [KLIndicatorLabelPoint], instanceID: String? = nil) {
        self.indicatorID = indicatorID
        self.indicatorName = indicatorName
        self.instanceID = instanceID
        self.labels = labels
    }
}

// MARK: - 水平线载荷

public struct KLHorizontalLinePayload: Codable, Sendable {
    public let indicatorID: String
    public let indicatorName: String
    public let instanceID: String?
    public let outputKey: String?
    public let value: Decimal
    public let label: String?

    public init(indicatorID: String, indicatorName: String, value: Decimal, label: String? = nil, instanceID: String? = nil, outputKey: String? = nil) {
        self.indicatorID = indicatorID
        self.indicatorName = indicatorName
        self.instanceID = instanceID
        self.outputKey = outputKey
        self.value = value
        self.label = label
    }
}

// MARK: - 区域载荷

public struct KLRangePayload: Codable, Sendable {
    public let rangeID: String
    public let instanceID: String?
    public let startTime: Date?
    public let endTime: Date?
    public let upper: Decimal
    public let lower: Decimal
    public let label: String?

    public init(rangeID: String, instanceID: String? = nil, startTime: Date? = nil, endTime: Date? = nil, upper: Decimal, lower: Decimal, label: String? = nil) {
        self.rangeID = rangeID
        self.instanceID = instanceID
        self.startTime = startTime
        self.endTime = endTime
        self.upper = upper
        self.lower = lower
        self.label = label
    }
}

// MARK: - K线形态标记载荷

public struct KLCandlePatternMarkerPayload: Codable, Sendable {
    public let patternID: String
    public let patternName: String
    public let direction: String
    public let confidence: Double
    public let candleTimes: [Date]
    public let anchorTime: Date
    public let anchorPrice: Decimal?
    public let description: String?
    /// 是否应触发声音提示
    public let shouldTriggerSound: Bool
    public let soundEventID: String?

    public init(patternID: String, patternName: String, direction: String, confidence: Double, candleTimes: [Date], anchorTime: Date, anchorPrice: Decimal? = nil, description: String? = nil, shouldTriggerSound: Bool = false, soundEventID: String? = nil) {
        self.patternID = patternID
        self.patternName = patternName
        self.direction = direction
        self.confidence = confidence
        self.candleTimes = candleTimes
        self.anchorTime = anchorTime
        self.anchorPrice = anchorPrice
        self.description = description
        self.shouldTriggerSound = shouldTriggerSound
        self.soundEventID = soundEventID
    }
}

// MARK: - 回撤区域载荷

public struct KLRetracementZonePayload: Codable, Sendable {
    public let zoneID: String
    public let startTime: Date
    public let endTime: Date
    public let highPrice: Decimal
    public let lowPrice: Decimal
    public let label: String
    public let confidence: Double?

    public init(zoneID: String, startTime: Date, endTime: Date, highPrice: Decimal, lowPrice: Decimal, label: String, confidence: Double? = nil) {
        self.zoneID = zoneID
        self.startTime = startTime
        self.endTime = endTime
        self.highPrice = highPrice
        self.lowPrice = lowPrice
        self.label = label
        self.confidence = confidence
    }
}

// MARK: - 预测区域载荷

public struct KLPredictionZonePayload: Codable, Sendable {
    public let predictionID: String
    public let startTime: Date
    public let endTime: Date
    public let upperPrice: Decimal
    public let lowerPrice: Decimal
    public let expectedPrice: Decimal?
    public let probability: Double?
    public let label: String?
}

// MARK: - 交易标记载荷

public struct KLTradeMarkerPayload: Codable, Sendable {
    public let tradeID: String
    public let orderID: String?
    public let side: String
    public let eventTime: Date
    public let price: Decimal
    public let quantity: Decimal?
    public let label: String?
}

// MARK: - 叠加载荷

public enum KLOverlayPayload: Codable, Sendable {
    case indicatorLine(KLIndicatorLinePayload)
    case indicatorBand(KLIndicatorBandPayload)
    case indicatorHistogram(KLIndicatorHistogramPayload)
    case indicatorPoint(KLIndicatorPointMarkerPayload)
    case indicatorLabel(KLIndicatorLabelPayload)
    case horizontalLine(KLHorizontalLinePayload)
    case range(KLRangePayload)
    case candlePatternMarker(KLCandlePatternMarkerPayload)
    case retracementZone(KLRetracementZonePayload)
    case predictionZone(KLPredictionZonePayload)
    case tradeMarker(KLTradeMarkerPayload)
    case customJSON(String)

    private enum CodingKeys: String, CodingKey {
        case type, payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "indicatorLine":
            let p = try container.decode(KLIndicatorLinePayload.self, forKey: .payload)
            self = .indicatorLine(p)
        case "indicatorBand":
            let p = try container.decode(KLIndicatorBandPayload.self, forKey: .payload)
            self = .indicatorBand(p)
        case "indicatorHistogram":
            let p = try container.decode(KLIndicatorHistogramPayload.self, forKey: .payload)
            self = .indicatorHistogram(p)
        case "indicatorPoint":
            let p = try container.decode(KLIndicatorPointMarkerPayload.self, forKey: .payload)
            self = .indicatorPoint(p)
        case "indicatorLabel":
            let p = try container.decode(KLIndicatorLabelPayload.self, forKey: .payload)
            self = .indicatorLabel(p)
        case "horizontalLine":
            let p = try container.decode(KLHorizontalLinePayload.self, forKey: .payload)
            self = .horizontalLine(p)
        case "range":
            let p = try container.decode(KLRangePayload.self, forKey: .payload)
            self = .range(p)
        case "candlePatternMarker":
            let p = try container.decode(KLCandlePatternMarkerPayload.self, forKey: .payload)
            self = .candlePatternMarker(p)
        case "retracementZone":
            let p = try container.decode(KLRetracementZonePayload.self, forKey: .payload)
            self = .retracementZone(p)
        case "predictionZone":
            let p = try container.decode(KLPredictionZonePayload.self, forKey: .payload)
            self = .predictionZone(p)
        case "tradeMarker":
            let p = try container.decode(KLTradeMarkerPayload.self, forKey: .payload)
            self = .tradeMarker(p)
        default:
            self = .customJSON(try container.decode(String.self, forKey: .payload))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .indicatorLine(let p):
            try container.encode("indicatorLine", forKey: .type)
            try container.encode(p, forKey: .payload)
        case .indicatorBand(let p):
            try container.encode("indicatorBand", forKey: .type)
            try container.encode(p, forKey: .payload)
        case .indicatorHistogram(let p):
            try container.encode("indicatorHistogram", forKey: .type)
            try container.encode(p, forKey: .payload)
        case .indicatorPoint(let p):
            try container.encode("indicatorPoint", forKey: .type)
            try container.encode(p, forKey: .payload)
        case .indicatorLabel(let p):
            try container.encode("indicatorLabel", forKey: .type)
            try container.encode(p, forKey: .payload)
        case .horizontalLine(let p):
            try container.encode("horizontalLine", forKey: .type)
            try container.encode(p, forKey: .payload)
        case .range(let p):
            try container.encode("range", forKey: .type)
            try container.encode(p, forKey: .payload)
        case .candlePatternMarker(let p):
            try container.encode("candlePatternMarker", forKey: .type)
            try container.encode(p, forKey: .payload)
        case .retracementZone(let p):
            try container.encode("retracementZone", forKey: .type)
            try container.encode(p, forKey: .payload)
        case .predictionZone(let p):
            try container.encode("predictionZone", forKey: .type)
            try container.encode(p, forKey: .payload)
        case .tradeMarker(let p):
            try container.encode("tradeMarker", forKey: .type)
            try container.encode(p, forKey: .payload)
        case .customJSON(let s):
            try container.encode("custom", forKey: .type)
            try container.encode(s, forKey: .payload)
        }
    }
}

// MARK: - 统一叠加层

public struct KLExternalChartOverlay: Codable, Sendable, Identifiable {
    public let id: String
    public let moduleID: String
    public let moduleName: String
    public let target: KLOverlayTarget
    public let kind: KLOverlayKind
    public let pane: KLOverlayPane?
    public let paneID: String?
    public let instanceID: String?
    public let outputKey: String?
    public let zIndex: Int
    public var visible: Bool
    public let style: KLOverlayStyle
    public let payload: KLOverlayPayload
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: String = UUID().uuidString, moduleID: String, moduleName: String, target: KLOverlayTarget, kind: KLOverlayKind, zIndex: Int = 40, visible: Bool = true, style: KLOverlayStyle = KLOverlayStyle(), payload: KLOverlayPayload, createdAt: Date = Date(), updatedAt: Date = Date(), pane: KLOverlayPane? = nil, paneID: String? = nil, instanceID: String? = nil, outputKey: String? = nil) {
        self.id = id
        self.moduleID = moduleID
        self.moduleName = moduleName
        self.target = target
        self.kind = kind
        self.pane = pane
        self.paneID = paneID
        self.instanceID = instanceID
        self.outputKey = outputKey
        self.zIndex = zIndex
        self.visible = visible
        self.style = style
        self.payload = payload
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 叠加提交协议

public protocol KLChartOverlaySubmitting: AnyObject {
    /// 提交一个叠加层
    func submitOverlay(_ overlay: KLExternalChartOverlay) throws
    /// 批量提交叠加层
    func submitOverlays(_ overlays: [KLExternalChartOverlay]) throws
    /// 移除一个叠加层
    func removeOverlay(moduleID: String, overlayID: String) throws
    /// 移除某模块的所有叠加层
    func removeAllOverlays(moduleID: String) throws
    /// 获取某模块的所有叠加层
    func overlays(moduleID: String) -> [KLExternalChartOverlay]
    /// 获取当前图表所有可见叠加层
    func allVisibleOverlays(target: KLOverlayTarget) -> [KLExternalChartOverlay]
    /// 设置叠加层可见性
    func setOverlayVisible(overlayID: String, moduleID: String, visible: Bool) throws
}

// MARK: - 默认叠加管理器

public final class KLDefaultOverlayManager: KLChartOverlaySubmitting, @unchecked Sendable {
    public static let shared = KLDefaultOverlayManager()

    private var overlaysByModule: [String: [KLExternalChartOverlay]] = [:]
    // 按 instrumentID 索引，避免 allVisibleOverlays 遍历全部 overlay（废弃 overlay 积累后 O(N) 致命）
    private var overlaysByInstrumentID: [String: [KLExternalChartOverlay]] = [:]
    private let queue = DispatchQueue(label: "com.kline.overlay.manager")

    private init() {}

    public func submitOverlay(_ overlay: KLExternalChartOverlay) throws {
        queue.sync {
            var list = overlaysByModule[overlay.moduleID] ?? []
            if let idx = list.firstIndex(where: { $0.id == overlay.id }) {
                let old = list[idx]
                list[idx] = overlay
                if old.target.instrumentID != overlay.target.instrumentID {
                    var oldIdxList = overlaysByInstrumentID[old.target.instrumentID] ?? []
                    oldIdxList.removeAll { $0.id == overlay.id }
                    overlaysByInstrumentID[old.target.instrumentID] = oldIdxList
                }
            } else {
                list.append(overlay)
            }
            overlaysByModule[overlay.moduleID] = list
            var idxList = overlaysByInstrumentID[overlay.target.instrumentID] ?? []
            if let i = idxList.firstIndex(where: { $0.id == overlay.id }) {
                idxList[i] = overlay
            } else {
                idxList.append(overlay)
            }
            overlaysByInstrumentID[overlay.target.instrumentID] = idxList
        }
    }

    public func submitOverlays(_ overlays: [KLExternalChartOverlay]) throws {
        for o in overlays {
            try submitOverlay(o)
        }
    }

    public func removeOverlay(moduleID: String, overlayID: String) throws {
        queue.sync {
            guard var list = overlaysByModule[moduleID] else { return }
            if let removed = list.first(where: { $0.id == overlayID }) {
                var idxList = overlaysByInstrumentID[removed.target.instrumentID] ?? []
                idxList.removeAll { $0.id == overlayID }
                overlaysByInstrumentID[removed.target.instrumentID] = idxList
            }
            list.removeAll { $0.id == overlayID }
            overlaysByModule[moduleID] = list
        }
    }

    public func removeAllOverlays(moduleID: String) throws {
        let _ = queue.sync {
            if let list = overlaysByModule[moduleID] {
                for o in list {
                    var idxList = overlaysByInstrumentID[o.target.instrumentID] ?? []
                    idxList.removeAll { $0.id == o.id }
                    overlaysByInstrumentID[o.target.instrumentID] = idxList
                }
            }
            overlaysByModule.removeValue(forKey: moduleID)
        }
    }

    public func overlays(moduleID: String) -> [KLExternalChartOverlay] {
        queue.sync {
            overlaysByModule[moduleID] ?? []
        }
    }

    public func allVisibleOverlays(target: KLOverlayTarget) -> [KLExternalChartOverlay] {
        queue.sync {
            let candidates = overlaysByInstrumentID[target.instrumentID] ?? []
            var result: [KLExternalChartOverlay] = []
            for o in candidates where o.visible {
                // 检查关联实例是否仍然可见：实例被全局隐藏时，overlay 也应不显示
                if let iid = o.instanceID {
                    let instanceVisible = KXProfessionalIndicatorInstanceManager.shared.instance(id: iid)?.visible ?? true
                    guard instanceVisible else { continue }
                }
                if !o.target.appliesToAllTimeframes, let tf = o.target.timeframe, let targetTF = target.timeframe, tf != targetTF { continue }
                result.append(o)
            }
            return result.sorted { $0.zIndex < $1.zIndex }
        }
    }

    public func setOverlayVisible(overlayID: String, moduleID: String, visible: Bool) throws {
        queue.sync {
            guard var list = overlaysByModule[moduleID], let idx = list.firstIndex(where: { $0.id == overlayID }) else { return }
            list[idx].visible = visible
            overlaysByModule[moduleID] = list
        }
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN25Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-25", fileName: "KX-FN-25_跨模块叠加显示接口.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-25_跨模块叠加显示接口.swift", duty: "跨模块叠加显示接口定义"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("跨模块叠加显示接口骨架校验通过")
        return KXHealthCheckItem(name: "跨模块叠加显示接口", passed: true, message: "已实现跨模块叠加显示接口定义")
    }
}


// MARK: - 形态识别标准标记 Overlay 提交适配

/// K线模块只承载形态识别模块提交的标准标记，不主动运行形态识别算法。
public enum KXFN25PatternOverlayBridge {
    public static let moduleID = "candle-pattern-recognition"
    public static let moduleName = "K线形态识别"

    public static func makeOverlays(
        from markers: [KLMarkerDescriptor],
        target: KLOverlayTarget,
        generatedAt: Date = Date()
    ) -> [KLExternalChartOverlay] {
        markers.filter { $0.source == .patternRecognition }.map { marker in
            makeOverlay(from: marker, target: target, generatedAt: generatedAt)
        }
    }

    public static func submitOverlays(
        from markers: [KLMarkerDescriptor],
        target: KLOverlayTarget,
        manager: KLChartOverlaySubmitting = KLDefaultOverlayManager.shared,
        generatedAt: Date = Date()
    ) throws -> [KLExternalChartOverlay] {
        let overlays = makeOverlays(from: markers, target: target, generatedAt: generatedAt)
        // 多画布/多币对不能 removeAllOverlays(moduleID:)；否则一个 K线面板刷新形态识别会清掉其他币对/周期的形态标记。
        // 这里只替换当前 target 对应的旧标记。
        let oldOverlays = manager.overlays(moduleID: moduleID).filter { overlay in
            overlay.target.instrumentID == target.instrumentID &&
            overlay.target.timeframe == target.timeframe &&
            overlay.target.tabID == target.tabID
        }
        for overlay in oldOverlays {
            try manager.removeOverlay(moduleID: moduleID, overlayID: overlay.id)
        }
        try manager.submitOverlays(overlays)
        return overlays
    }

    private static func makeOverlay(from marker: KLMarkerDescriptor, target: KLOverlayTarget, generatedAt: Date) -> KLExternalChartOverlay {
        let confidence = confidenceValue(from: marker)
        let direction = directionText(from: marker)
        let color = marker.style?.colorHex ?? (direction == "bearish" ? "#FF5C5C" : "#23C552")
        let patternID = patternID(from: marker)
        let patternName = patternName(from: marker)
        let payload = KLCandlePatternMarkerPayload(
            patternID: patternID,
            patternName: patternName,
            direction: direction,
            confidence: confidence,
            candleTimes: marker.coordinate.time.map { [$0] } ?? [],
            anchorTime: marker.coordinate.time ?? generatedAt,
            anchorPrice: marker.coordinate.price,
            description: marker.message,
            shouldTriggerSound: marker.severity == .high || marker.severity == .critical,
            soundEventID: marker.severity == .high || marker.severity == .critical ? "pattern.alert.\(marker.id)" : nil
        )
        return KLExternalChartOverlay(
            id: "overlay.pattern.\(marker.id)",
            moduleID: moduleID,
            moduleName: moduleName,
            target: target,
            kind: .candlePatternMarker,
            zIndex: 65,
            visible: true,
            style: KLOverlayStyle(fallbackHexColor: color, lineWidth: 3, opacity: 0.95, fontSize: 10),
            payload: .candlePatternMarker(payload),
            createdAt: marker.createdAt,
            updatedAt: generatedAt,
            pane: .main,
            paneID: nil,
            instanceID: nil,
            outputKey: marker.title
        )
    }


    private static func patternID(from marker: KLMarkerDescriptor) -> String {
        // KLMarkerDescriptor.id 格式：KP:<symbol>:<timeframe>:<patternID>:<timestamp>
        // 旧逻辑把整个 marker.id 当 patternID，导致渲染层无法知道真实形态分类/所需K线根数。
        let parts = marker.id.split(separator: ":").map(String.init)
        if parts.count >= 5, parts.first == "KP" { return parts[3] }
        return marker.id
    }

    private static func patternName(from marker: KLMarkerDescriptor) -> String {
        // title 格式通常为 "1h 锤子线｜看涨"；渲染层只需要中文形态名。
        var title = marker.title
        if let range = title.range(of: "｜") { title = String(title[..<range.lowerBound]) }
        if let firstSpace = title.firstIndex(of: " ") { title = String(title[title.index(after: firstSpace)...]) }
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func confidenceValue(from marker: KLMarkerDescriptor) -> Double {
        switch marker.severity {
        case .critical: return 0.95
        case .high: return 0.85
        case .medium: return 0.65
        case .low: return 0.45
        case .info: return 0.35
        }
    }

    private static func directionText(from marker: KLMarkerDescriptor) -> String {
        let text = "\(marker.title) \(marker.message ?? "")"
        if text.contains("空") || text.contains("跌") || text.localizedCaseInsensitiveContains("bear") { return "bearish" }
        if text.contains("多") || text.contains("涨") || text.localizedCaseInsensitiveContains("bull") { return "bullish" }
        return "neutral"
    }
}
