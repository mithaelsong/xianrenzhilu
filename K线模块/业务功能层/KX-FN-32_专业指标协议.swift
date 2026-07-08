//
//  KX-FN-32_专业指标协议.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：定义专业指标系统的模板协议、计算上下文、输出结构
//  禁止事项：禁止 UI 绘制、禁止数据库写入、禁止网络请求
//

import Foundation

// MARK: - 参数值类型

public enum KXIndicatorParameterValue: Codable, Sendable, Equatable {
    case int(Int)
    case double(Double)
    case bool(Bool)
    case string(String)
    case option(String)
    case colorHex(String)

    private enum CodingKeys: String, CodingKey {
        case type, int, double, bool, string, option, colorHex
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "int": self = .int(try c.decode(Int.self, forKey: .int))
        case "double": self = .double(try c.decode(Double.self, forKey: .double))
        case "bool": self = .bool(try c.decode(Bool.self, forKey: .bool))
        case "string": self = .string(try c.decode(String.self, forKey: .string))
        case "option": self = .option(try c.decode(String.self, forKey: .option))
        case "colorHex": self = .colorHex(try c.decode(String.self, forKey: .colorHex))
        default: self = .string("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .int(let v): try c.encode("int", forKey: .type); try c.encode(v, forKey: .int)
        case .double(let v): try c.encode("double", forKey: .type); try c.encode(v, forKey: .double)
        case .bool(let v): try c.encode("bool", forKey: .type); try c.encode(v, forKey: .bool)
        case .string(let v): try c.encode("string", forKey: .type); try c.encode(v, forKey: .string)
        case .option(let v): try c.encode("option", forKey: .type); try c.encode(v, forKey: .option)
        case .colorHex(let v): try c.encode("colorHex", forKey: .type); try c.encode(v, forKey: .colorHex)
        }
    }
}

// MARK: - 参数类型

public enum KXIndicatorParameterKind: String, Codable, Sendable, Equatable, CaseIterable {
    case integer
    case decimal
    case dataSource
    case option
    case boolean
    case color
    case lineWidth
    case lineStyle
    case opacity
}

// MARK: - 参数选项

public struct KXIndicatorOption: Codable, Sendable, Equatable {
    public let value: String
    public let label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

// MARK: - 参数 Schema

public struct KXIndicatorParameterSchema: Codable, Sendable, Equatable {
    public let key: String
    public let title: String
    public let kind: KXIndicatorParameterKind
    public let defaultValue: KXIndicatorParameterValue
    public let min: Double?
    public let max: Double?
    public let step: Double?
    public let options: [KXIndicatorOption]
    public let help: String?

    public init(
        key: String,
        title: String,
        kind: KXIndicatorParameterKind,
        defaultValue: KXIndicatorParameterValue,
        min: Double? = nil,
        max: Double? = nil,
        step: Double? = nil,
        options: [KXIndicatorOption] = [],
        help: String? = nil
    ) {
        self.key = key
        self.title = title
        self.kind = kind
        self.defaultValue = defaultValue
        self.min = min
        self.max = max
        self.step = step
        self.options = options
        self.help = help
    }
}

// MARK: - Figure 类型

public enum KXIndicatorFigureType: String, Codable, Sendable, Equatable, CaseIterable {
    case line
    case bar
    case band
    case point
    case label
    case range
    case horizontalLine
    case area
}

// MARK: - Figure Schema

public struct KXIndicatorFigureSchema: Codable, Sendable, Equatable {
    public let key: String
    public let title: String
    public let type: KXIndicatorFigureType
    public let pane: KLOverlayPane
    public let styleKey: String
    public let zIndex: Int
    public let autoscalePolicy: String?

    public init(
        key: String,
        title: String,
        type: KXIndicatorFigureType,
        pane: KLOverlayPane,
        styleKey: String,
        zIndex: Int = 40,
        autoscalePolicy: String? = nil
    ) {
        self.key = key
        self.title = title
        self.type = type
        self.pane = pane
        self.styleKey = styleKey
        self.zIndex = zIndex
        self.autoscalePolicy = autoscalePolicy
    }
}

// MARK: - 计算上下文

public struct KXIndicatorCalculationContext: Sendable {
    public let candles: [KLCandlePoint]
    public let ohlcv: KLIndicatorOHLCVSeries
    public let query: KLKLineQuery
    public let target: KLOverlayTarget

    public init(candles: [KLCandlePoint], ohlcv: KLIndicatorOHLCVSeries, query: KLKLineQuery, target: KLOverlayTarget) {
        self.candles = candles
        self.ohlcv = ohlcv
        self.query = query
        self.target = target
    }
}

// MARK: - 计算输出

public struct KXIndicatorCalculationOutput: Sendable {
    public let series: [String: [KLIndicatorPoint]]
    public let labels: [String: [KLIndicatorLabelPoint]]
    public let ranges: [String: KLRangePayload]
    public let latestValues: [String: Decimal]
    public let signals: [KXSignal]

    public init(
        series: [String: [KLIndicatorPoint]] = [:],
        labels: [String: [KLIndicatorLabelPoint]] = [:],
        ranges: [String: KLRangePayload] = [:],
        latestValues: [String: Decimal] = [:],
        signals: [KXSignal] = []
    ) {
        self.series = series
        self.labels = labels
        self.ranges = ranges
        self.latestValues = latestValues
        self.signals = signals
    }
}

// MARK: - Tooltip 快照

public struct KXIndicatorTooltipSnapshot: Sendable {
    public let text: String
    public let colorHex: String?

    public init(text: String, colorHex: String? = nil) {
        self.text = text
        self.colorHex = colorHex
    }
}

// MARK: - 专业指标模板协议

public protocol KXProfessionalIndicatorTemplate: Sendable {
    var indicatorID: String { get }
    var name: String { get }
    var defaultPane: KLOverlayPane { get }
    var parameterSchema: [KXIndicatorParameterSchema] { get }
    var styleSchema: [KXIndicatorParameterSchema] { get }
    var figureSchema: [KXIndicatorFigureSchema] { get }

    func makeDefaultInstance(zIndex: Int) -> KXProfessionalIndicatorInstance
    func calculate(context: KXIndicatorCalculationContext, instance: KXProfessionalIndicatorInstance) throws -> KXIndicatorCalculationOutput
    func makeOverlays(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance, target: KLOverlayTarget) -> [KLExternalChartOverlay]
    func makeTooltip(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance) -> KXIndicatorTooltipSnapshot
}

// MARK: - 专业指标实例

public struct KXProfessionalIndicatorInstance: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let indicatorID: String
    public let indicatorName: String
    public var params: [String: KXIndicatorParameterValue]
    public var styles: [String: KXIndicatorParameterValue]
    public var visible: Bool
    public var pane: KLOverlayPane
    public var zIndex: Int
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        indicatorID: String,
        indicatorName: String,
        params: [String: KXIndicatorParameterValue] = [:],
        styles: [String: KXIndicatorParameterValue] = [:],
        visible: Bool = true,
        pane: KLOverlayPane = .main,
        zIndex: Int = 40,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.indicatorID = indicatorID
        self.indicatorName = indicatorName
        self.params = params
        self.styles = styles
        self.visible = visible
        self.pane = pane
        self.zIndex = zIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 便利计算属性

extension KXIndicatorParameterValue {
    var intValue: Int {
        switch self {
        case .int(let v): return v
        case .double(let v): return Int(v)
        default: return 0
        }
    }
    var doubleValue: Double {
        switch self {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return 0.0
        }
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN32Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-32", fileName: "KX-FN-32_专业指标协议.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-32_专业指标协议.swift", duty: "专业指标系统模板协议、计算上下文、输出结构"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("专业指标协议骨架校验通过")
        return KXHealthCheckItem(name: "专业指标协议", passed: true, message: "已实现专业指标系统模板协议")
    }
}
