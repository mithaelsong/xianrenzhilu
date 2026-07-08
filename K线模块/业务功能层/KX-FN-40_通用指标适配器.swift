//
//  KX-FN-40_通用指标适配器.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.2
//  职责：通用指标输出适配器，将老 KXIndicatorProtocol 计算结果转成 KXIndicatorCalculationOutput
//  禁止事项：禁止直接绘制 UI、禁止修改 K线视图
//

import Foundation

// MARK: - 一、输出形态配置

public struct KXIN_OutputMapping: Sendable {
    public let key: String
    public let title: String
    public let type: KXIndicatorFigureType
    public let styleKey: String

    public init(key: String, title: String, type: KXIndicatorFigureType, styleKey: String) {
        self.key = key
        self.title = title
        self.type = type
        self.styleKey = styleKey
    }
}

// MARK: - 二、通用指标输出适配协议

public protocol KXIndicatorOutputAdapter: Sendable {
    var indicatorID: String { get }
    var name: String { get }
    var defaultPane: KLOverlayPane { get }
    var parameterSchema: [KXIndicatorParameterSchema] { get }
    var styleSchema: [KXIndicatorParameterSchema] { get }
    var figureSchema: [KXIndicatorFigureSchema] { get }

    func adapt(result: KXIndicatorResult, candles: [KLCandlePoint], params: [String: Double]) -> KXIndicatorCalculationOutput
}

// MARK: - 三、统一输出适配器

/// 将老 `KXIndicatorProtocol` 计算器的 `KXIndicatorResult` 转换为 `KXIndicatorCalculationOutput`。
/// 通过 `mappings` 描述每个输出序列的形态（line/bar/band/point 等），不复制算法代码。
public struct KXIN_LegacyOutputAdapter: KXIndicatorOutputAdapter {
    public let indicatorID: String
    public let name: String
    public let defaultPane: KLOverlayPane
    public let mappings: [KXIN_OutputMapping]
    public let parameterSchema: [KXIndicatorParameterSchema]
    public let styleSchema: [KXIndicatorParameterSchema]

    public var figureSchema: [KXIndicatorFigureSchema] {
        mappings.map {
            KXIndicatorFigureSchema(key: $0.key, title: $0.title, type: $0.type, pane: defaultPane, styleKey: $0.styleKey)
        }
    }

    public init(
        indicatorID: String,
        name: String,
        defaultPane: KLOverlayPane,
        mappings: [KXIN_OutputMapping],
        parameterSchema: [KXIndicatorParameterSchema],
        styleSchema: [KXIndicatorParameterSchema]
    ) {
        self.indicatorID = indicatorID
        self.name = name
        self.defaultPane = defaultPane
        self.mappings = mappings
        self.parameterSchema = parameterSchema
        self.styleSchema = styleSchema
    }

    public func adapt(result: KXIndicatorResult, candles: [KLCandlePoint], params: [String: Double]) -> KXIndicatorCalculationOutput {
        let namedValues = result.namedValues ?? [:]
        var seriesDict: [String: [KLIndicatorPoint]] = [:]
        var latestDict: [String: Decimal] = [:]

        for mapping in mappings {
            let values = namedValues[mapping.key] ?? (mapping.key == "main" ? result.values : [])
            let series = zip(candles, values).compactMap { (candle, value) -> KLIndicatorPoint? in
                guard let v = value else { return nil }
                return KLIndicatorPoint(time: candle.openTime, value: Decimal(v))
            }
            seriesDict[mapping.key] = series
            latestDict[mapping.key] = values.last.flatMap({ Decimal($0) }) ?? Decimal()

            // 对 band 形态的老指标，尝试把 namedValues 中的 upper/lower/middle 映射成 overlay 层期望的 key.upper/key.lower
            if mapping.type == .band {
                let bandKeys = ["upper", "lower", "middle"]
                for bandKey in bandKeys {
                    let outputKey = "\(mapping.key).\(bandKey)"
                    guard seriesDict[outputKey] == nil else { continue }
                    if let bandValues = namedValues[bandKey], bandValues.count == candles.count {
                        let bandSeries = zip(candles, bandValues).compactMap { (candle, value) -> KLIndicatorPoint? in
                            guard let v = value else { return nil }
                            return KLIndicatorPoint(time: candle.openTime, value: Decimal(v))
                        }
                        seriesDict[outputKey] = bandSeries
                        latestDict[outputKey] = bandValues.last.flatMap({ Decimal($0) }) ?? Decimal()
                    }
                }
            }
        }

        return KXIndicatorCalculationOutput(series: seriesDict, latestValues: latestDict, signals: result.signals)
    }
}

// MARK: - 四、老指标桥接模板

/// 将 `KXIN_LegacyOutputAdapter` 包装为 `KXProfessionalIndicatorTemplate`，
/// 使其能被 `KXProfessionalIndicatorInstanceManager` 注册和使用。
/// 内部调用老 `KXIndicatorProtocol` 计算器，不复制算法。
public struct KXIN_LegacyIndicatorTemplate: KXProfessionalIndicatorTemplate {
    public let indicatorID: String
    public let name: String
    public let defaultPane: KLOverlayPane
    public let parameterSchema: [KXIndicatorParameterSchema]
    public let styleSchema: [KXIndicatorParameterSchema]
    public let figureSchema: [KXIndicatorFigureSchema]

    private let adapter: KXIN_LegacyOutputAdapter

    public init(adapter: KXIN_LegacyOutputAdapter) {
        self.adapter = adapter
        self.indicatorID = adapter.indicatorID
        self.name = adapter.name
        self.defaultPane = adapter.defaultPane
        self.parameterSchema = adapter.parameterSchema
        self.styleSchema = adapter.styleSchema
        self.figureSchema = adapter.figureSchema
    }

    public func makeDefaultInstance(zIndex: Int) -> KXProfessionalIndicatorInstance {
        var params: [String: KXIndicatorParameterValue] = [:]
        var styles: [String: KXIndicatorParameterValue] = [:]
        parameterSchema.forEach { params[$0.key] = $0.defaultValue }
        styleSchema.forEach { styles[$0.key] = $0.defaultValue }
        return KXProfessionalIndicatorInstance(
            indicatorID: indicatorID, indicatorName: name,
            params: params, styles: styles,
            visible: true, pane: defaultPane, zIndex: zIndex
        )
    }

    public func calculate(context: KXIndicatorCalculationContext, instance: KXProfessionalIndicatorInstance) throws -> KXIndicatorCalculationOutput {
        guard let indicator = KXTechnicalIndicatorManager.shared.indicator(withId: indicatorID),
              let calculator = KXTechnicalIndicatorManager.shared.calculator(for: indicator) else {
            return KXIndicatorCalculationOutput()
        }
        let params: [String: Double] = instance.params.reduce(into: [:]) { result, pair in
            result[pair.key] = pair.value.doubleValue
        }
        let result = try calculator.calculate(for: context.candles, parameters: KXIndicatorParameters(values: params))
        return adapter.adapt(result: result, candles: context.candles, params: params)
    }

    public func makeOverlays(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance, target: KLOverlayTarget) -> [KLExternalChartOverlay] {
        KXIndicatorOverlayAdapter.adapt(output: output, instance: instance, figureSchema: figureSchema, target: target)
    }

    public func makeTooltip(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance) -> KXIndicatorTooltipSnapshot {
        let firstKey = figureSchema.first?.key ?? indicatorID
        let latest = output.latestValues[firstKey] ?? Decimal()
        let text = "\(name) \(latest)"
        return KXIndicatorTooltipSnapshot(text: text, colorHex: colorHexFromValue(instance.styles["color"]))
    }
}

// MARK: - 五、通用参数/样式 Schema 构造便利函数

public enum KXIN_LegacySchemaFactory {
    public static func colorStyle(key: String, title: String, defaultHex: String) -> KXIndicatorParameterSchema {
        KXIndicatorParameterSchema(key: key, title: title, kind: .color, defaultValue: .colorHex(defaultHex))
    }

    public static func lineWidthStyle(key: String = "lineWidth") -> KXIndicatorParameterSchema {
        KXIndicatorParameterSchema(key: key, title: "线宽", kind: .lineWidth, defaultValue: .double(1.5))
    }

    public static func opacityStyle(key: String = "opacity") -> KXIndicatorParameterSchema {
        KXIndicatorParameterSchema(key: key, title: "透明度", kind: .opacity, defaultValue: .double(1.0))
    }

    public static func integerParam(key: String, title: String, defaultValue: Int, min: Int, max: Int, step: Int = 1) -> KXIndicatorParameterSchema {
        KXIndicatorParameterSchema(key: key, title: title, kind: .integer,
                                   defaultValue: .int(defaultValue), min: Double(min), max: Double(max), step: Double(step))
    }

    public static func decimalParam(key: String, title: String, defaultValue: Double, min: Double, max: Double, step: Double) -> KXIndicatorParameterSchema {
        KXIndicatorParameterSchema(key: key, title: title, kind: .decimal,
                                   defaultValue: .double(defaultValue), min: min, max: max, step: step)
    }

    /// 根据老指标默认参数构造通用 parameterSchema。
    /// 整数参数（无小数部分且在合理范围）使用 .integer，否则使用 .decimal。
    public static func parameterSchema(from values: [String: Double]) -> [KXIndicatorParameterSchema] {
        values.map { key, value in
            let isInteger = value.truncatingRemainder(dividingBy: 1.0) == 0
            let title = parameterTitle(for: key)
            if isInteger {
                return KXIndicatorParameterSchema(
                    key: key, title: title, kind: .integer,
                    defaultValue: .int(Int(value)), min: 1, max: 500, step: 1
                )
            } else {
                return KXIndicatorParameterSchema(
                    key: key, title: title, kind: .decimal,
                    defaultValue: .double(value), min: -1000, max: 1000, step: 0.1
                )
            }
        }.sorted { $0.key < $1.key }
    }

    private static func parameterTitle(for key: String) -> String {
        switch key {
        case "period": return "周期"
        case "fastPeriod": return "快线周期"
        case "slowPeriod": return "慢线周期"
        case "signalPeriod": return "信号周期"
        case "multiplier": return "倍数"
        case "overbought": return "超买"
        case "oversold": return "超卖"
        case "kPeriod": return "K周期"
        case "dPeriod": return "D周期"
        case "rsiPeriod": return "RSI周期"
        case "stochPeriod": return "Stoch周期"
        case "fast": return "快常数"
        case "slow": return "慢常数"
        case "period1": return "周期1"
        case "period2": return "周期2"
        case "period3": return "周期3"
        case "weight1": return "权重1"
        case "weight2": return "权重2"
        case "weight3": return "权重3"
        case "tenkan": return "转换线周期"
        case "kijun": return "基准线周期"
        case "senkouB": return "先行B周期"
        case "displacement": return "位移"
        case "acceleration": return "加速因子"
        case "accelerationMax": return "最大加速"
        case "accelerationIncrement": return "加速增量"
        case "longPeriod": return "长期周期"
        case "shortPeriod": return "短期周期"
        case "wmaPeriod": return "WMA周期"
        case "emaPeriod": return "EMA周期"
        case "buyThreshold": return "买入阈值"
        case "sellThreshold": return "卖出阈值"
        case "trendThreshold": return "趋势阈值"
        case "strongTrendThreshold": return "强趋势阈值"
        case "strongThreshold": return "强阈值"
        case "weakThreshold": return "弱阈值"
        case "overboughtThreshold": return "超买阈值"
        case "oversoldThreshold": return "超卖阈值"
        case "swingThreshold": return "摆动阈值"
        case "numBins": return "分箱数"
        case "basePeriod": return "基础周期"
        case "atrPeriod": return "ATR周期"
        case "method": return "方法"
        case "changeThreshold": return "变化阈值"
        case "euphoria": return "狂热阈值"
        case "capitulation": return "投降阈值"
        case "highPositive": return "多头阈值"
        case "highNegative": return "空头阈值"
        default: return key
        }
    }

    public static var commonLineStyles: [KXIndicatorParameterSchema] {
        [
            colorStyle(key: "color", title: "颜色", defaultHex: "#64D2FFFF"),
            lineWidthStyle(),
            opacityStyle()
        ]
    }
}

// MARK: - 六、Helpers

private func colorHexFromValue(_ value: KXIndicatorParameterValue?) -> String? {
    guard let value else { return nil }
    switch value {
    case .colorHex(let hex): return hex
    case .string(let str): return str
    default: return nil
    }
}

private extension Decimal {
    init?(_ value: Double?) {
        guard let value else { return nil }
        self.init(value)
    }
}

// MARK: - 七、KXFileSkeletonProtocol

public enum KXFN40Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.2"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-40",
        fileName: "KX-FN-40_通用指标适配器.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-40_通用指标适配器.swift",
        duty: "通用指标输出适配器，将老 KXIndicatorProtocol 计算结果转成 KXIndicatorCalculationOutput"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("通用指标适配器骨架校验通过")
        return KXHealthCheckItem(name: "通用指标适配器", passed: true, message: "已提供统一老指标桥接能力")
    }
}
