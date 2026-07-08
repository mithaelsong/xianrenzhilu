//
//  KX-IN-02_EMA.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：EMA（指数移动平均线）统一计算实现，同时服务老 KXIndicatorProtocol 与新 KXProfessionalIndicatorTemplate
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型
//

import Foundation

// MARK: - 统一计算函数

public enum KXEMACalculator {
    public static func calculateEMA(values: [Double], period: Int) -> [Double] {
        guard !values.isEmpty, period > 0 else { return [] }
        let k = 2.0 / (Double(period) + 1.0)
        var ema = [Double](repeating: 0, count: values.count)
        ema[0] = values[0]
        for i in 1..<values.count {
            ema[i] = values[i] * k + ema[i - 1] * (1 - k)
        }
        return ema
    }

    public static func calculate(for candles: [KLCandlePoint], period: Int) -> [KLIndicatorPoint] {
        guard candles.count >= period else { return [] }
        let closes = candles.map { $0.close.dbl }
        let ema = calculateEMA(values: closes, period: period)
        return ema.enumerated().map { KLIndicatorPoint(time: candles[$0.offset].openTime, value: Decimal($0.element)) }
    }

    public static func priceCrossSignals(candles: [KLCandlePoint], values: [KLIndicatorPoint]) -> [KXSignal] {
        guard candles.count >= 2 else { return [] }
        let aligned = alignIndicatorPoints(values, to: candles)
        var signals: [KXSignal] = []
        for i in 1..<candles.count {
            guard let prevEMA = aligned[i - 1], let currEMA = aligned[i] else { continue }
            let prevPrice = candles[i - 1].close.dbl
            let currPrice = candles[i].close.dbl
            let prevAbove = prevPrice > prevEMA
            let currAbove = currPrice > currEMA
            if !prevAbove && currAbove {
                signals.append(KXSignal(index: i, type: .buy, price: candles[i].close))
            } else if prevAbove && !currAbove {
                signals.append(KXSignal(index: i, type: .sell, price: candles[i].close))
            }
        }
        return signals
    }
}

// MARK: - 老协议兼容计算器

public struct EMACalculator: KXIndicatorProtocol {
    public var identifier: String { "KX-IN-02" }
    public var name: String { "EMA" }
    public var englishName: String { "Exponential Moving Average" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 12.0
        ]
    }

    public init(parameters: KXIndicatorParameters = .defaultEMA) {
        self.parameters = parameters
    }

    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 12)
        let points = KXEMACalculator.calculate(for: candles, period: period)
        let aligned = alignIndicatorPoints(points, to: candles)
        let signals = KXEMACalculator.priceCrossSignals(candles: candles, values: points)
        return KXIndicatorResult(values: aligned, signals: signals)
    }
}

public extension KXIndicatorParameters {
    static var defaultEMA: KXIndicatorParameters {
        KXIndicatorParameters(values: ["period": 12])
    }
}

// MARK: - 新专业指标模板

public struct KXIN_EMA_Template: KXProfessionalIndicatorTemplate {
    public let indicatorID = "ema"
    public let name = "EMA"
    public let defaultPane: KLOverlayPane = .main

    public var parameterSchema: [KXIndicatorParameterSchema] {
        [KXIndicatorParameterSchema(key: "period", title: "周期", kind: .integer,
                                    defaultValue: .int(12), min: 1, max: 500, step: 1)]
    }

    public var styleSchema: [KXIndicatorParameterSchema] {
        [
            KXIndicatorParameterSchema(key: "color", title: "颜色", kind: .color, defaultValue: .colorHex("#64D2FFFF")),
            KXIndicatorParameterSchema(key: "lineWidth", title: "线宽", kind: .lineWidth, defaultValue: .double(1.5)),
            KXIndicatorParameterSchema(key: "opacity", title: "透明度", kind: .opacity, defaultValue: .double(1.0))
        ]
    }

    public var figureSchema: [KXIndicatorFigureSchema] {
        [KXIndicatorFigureSchema(key: "ema", title: "EMA", type: .line, pane: .main, styleKey: "color", zIndex: 40)]
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
        let period = intParam(instance.params, key: "period", default: 12)
        let values = KXEMACalculator.calculate(for: context.candles, period: period)
        let latest = values.last?.value ?? Decimal(0)
        let signals = KXEMACalculator.priceCrossSignals(candles: context.candles, values: values)
        return KXIndicatorCalculationOutput(series: ["ema": values], latestValues: ["ema": latest], signals: signals)
    }

    public func makeOverlays(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance, target: KLOverlayTarget) -> [KLExternalChartOverlay] {
        KXIndicatorOverlayAdapter.adapt(output: output, instance: instance, figureSchema: figureSchema, target: target)
    }

    public func makeTooltip(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance) -> KXIndicatorTooltipSnapshot {
        let period = intParam(instance.params, key: "period", default: 12)
        return KXIndicatorTooltipSnapshot(text: "EMA(\(period))", colorHex: colorHexFromValue(instance.styles["color"]))
    }

    private func intParam(_ params: [String: KXIndicatorParameterValue], key: String, default: Int) -> Int {
        guard let value = params[key] else { return `default` }
        switch value {
        case .int(let v): return v
        case .double(let v): return Int(v)
        default: return `default`
        }
    }

    private func colorHexFromValue(_ value: KXIndicatorParameterValue?) -> String? {
        guard let value else { return nil }
        switch value {
        case .colorHex(let hex): return hex
        case .string(let str): return str
        default: return nil
        }
    }
}

private extension Decimal {
    var dbl: Double { NSDecimalNumber(decimal: self).doubleValue }
}

private func alignIndicatorPoints(_ points: [KLIndicatorPoint], to candles: [KLCandlePoint]) -> [Double?] {
    var result: [Double?] = Array(repeating: nil, count: candles.count)
    let timeIndexMap = Dictionary(uniqueKeysWithValues: candles.enumerated().map { ($1.openTime, $0) })
    for p in points {
        if let idx = timeIndexMap[p.time] {
            result[idx] = p.value.dbl
        }
    }
    return result
}

// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN02EMA: KXFileSkeletonProtocol {
    public static let version = "2.1"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-02", fileName: "KX-IN-02_EMA.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-02_EMA.swift", duty: "EMA 统一计算实现"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "EMA", passed: true, message: "EMA统一计算实现完成")
    }
}
