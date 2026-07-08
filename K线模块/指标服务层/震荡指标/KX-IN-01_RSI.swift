//
//  KX-IN-01_RSI.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：RSI 统一计算实现，同时服务老 KXIndicatorProtocol 与新 KXProfessionalIndicatorTemplate
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

// MARK: - 统一计算函数

public enum KXRSICalculator {
    public static func calculate(for candles: [KLCandlePoint], period: Int) -> [KLIndicatorPoint] {
        guard candles.count >= period + 1 else { return [] }
        let closes = candles.map { $0.close.dbl }
        
        var values: [KLIndicatorPoint] = []
        values.reserveCapacity(max(0, closes.count - period))
        
        var gainSum: Double = 0
        var lossSum: Double = 0
        for i in 1...period {
            let change = closes[i] - closes[i - 1]
            gainSum += max(change, 0)
            lossSum += max(-change, 0)
        }
        
        var avgGain = gainSum / Double(period)
        var avgLoss = lossSum / Double(period)
        let firstRSI = 100 - (100 / (1 + avgGain / max(avgLoss, 0.00000001)))
        values.append(KLIndicatorPoint(time: candles[period].openTime, value: Decimal(firstRSI)))
        
        for i in (period + 1)..<closes.count {
            let change = closes[i] - closes[i - 1]
            avgGain = (avgGain * Double(period - 1) + max(change, 0)) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + max(-change, 0)) / Double(period)
            let rs = avgGain / max(avgLoss, 0.00000001)
            let rsi = 100 - (100 / (1 + rs))
            values.append(KLIndicatorPoint(time: candles[i].openTime, value: Decimal(rsi)))
        }
        return values
    }

    public static func thresholdSignals(
        candles: [KLCandlePoint],
        values: [KLIndicatorPoint],
        overbought: Double,
        oversold: Double
    ) -> [KXSignal] {
        guard candles.count >= 2 else { return [] }
        let aligned = alignIndicatorPoints(values, to: candles)
        var signals: [KXSignal] = []
        for i in 1..<candles.count {
            guard let prev = aligned[i - 1], let curr = aligned[i] else { continue }
            if prev <= oversold && curr > oversold {
                signals.append(KXSignal(index: i, type: .buy, price: candles[i].close))
            } else if prev >= overbought && curr < overbought {
                signals.append(KXSignal(index: i, type: .sell, price: candles[i].close))
            }
        }
        return signals
    }
}

// MARK: - 老协议兼容计算器

public struct RSICalculator: KXIndicatorProtocol {
    public var identifier: String { "KX-IN-01" }
    public var name: String { "RSI" }
    public var englishName: String { "Relative Strength Index" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 14.0,
            "overbought": 70.0,
            "oversold": 30.0
        ]
    }

    public init(parameters: KXIndicatorParameters = .defaultRSI) {
        self.parameters = parameters
    }

    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 14)
        let overbought = parameters.values["overbought"] ?? 70.0
        let oversold = parameters.values["oversold"] ?? 30.0
        let points = KXRSICalculator.calculate(for: candles, period: period)
        let aligned = alignIndicatorPoints(points, to: candles)
        let signals = KXRSICalculator.thresholdSignals(candles: candles, values: points, overbought: overbought, oversold: oversold)
        return KXIndicatorResult(values: aligned, signals: signals)
    }
}

public extension KXIndicatorParameters {
    static var defaultRSI: KXIndicatorParameters {
        KXIndicatorParameters(values: ["period": 14, "overbought": 70.0, "oversold": 30.0])
    }
}

// MARK: - 新专业指标模板

public struct KXIN_RSI_Template: KXProfessionalIndicatorTemplate {
    public let indicatorID = "rsi"
    public let name = "RSI"
    public let defaultPane: KLOverlayPane = .sub

    public var parameterSchema: [KXIndicatorParameterSchema] {
        [
            KXIndicatorParameterSchema(key: "period", title: "周期", kind: .integer,
                                       defaultValue: .int(14), min: 2, max: 100, step: 1, help: "RSI 计算周期"),
            KXIndicatorParameterSchema(key: "overbought", title: "超买线", kind: .decimal,
                                       defaultValue: .double(70), min: 50, max: 100, step: 1, help: "超买阈值"),
            KXIndicatorParameterSchema(key: "oversold", title: "超卖线", kind: .decimal,
                                       defaultValue: .double(30), min: 0, max: 50, step: 1, help: "超卖阈值")
        ]
    }

    public var styleSchema: [KXIndicatorParameterSchema] {
        [
            KXIndicatorParameterSchema(key: "color", title: "颜色", kind: .color, defaultValue: .colorHex("#FF9500")),
            KXIndicatorParameterSchema(key: "lineWidth", title: "线宽", kind: .lineWidth, defaultValue: .double(1.5)),
            KXIndicatorParameterSchema(key: "visible", title: "显示", kind: .boolean, defaultValue: .bool(true))
        ]
    }

    public var figureSchema: [KXIndicatorFigureSchema] {
        [KXIndicatorFigureSchema(key: "rsi", title: "RSI", type: .line, pane: .sub, styleKey: "color", zIndex: 40)]
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
        let period = intParam(instance.params, key: "period", default: 14)
        let overbought = doubleParam(instance.params, key: "overbought", default: 70)
        let oversold = doubleParam(instance.params, key: "oversold", default: 30)
        let values = KXRSICalculator.calculate(for: context.candles, period: period)
        let latest = values.last?.value ?? Decimal(0)
        let signals = KXRSICalculator.thresholdSignals(
            candles: context.candles, values: values,
            overbought: overbought, oversold: oversold
        )
        return KXIndicatorCalculationOutput(series: ["rsi": values], latestValues: ["rsi": latest], signals: signals)
    }

    public func makeOverlays(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance, target: KLOverlayTarget) -> [KLExternalChartOverlay] {
        var overlays = KXIndicatorOverlayAdapter.adapt(output: output, instance: instance, figureSchema: figureSchema, target: target)
        let refStyle = KLOverlayStyle(fallbackHexColor: "#666666", lineWidth: 1, lineDash: [4, 4], opacity: 0.5)
        let overbought = doubleParam(instance.params, key: "overbought", default: 70)
        let oversold = doubleParam(instance.params, key: "oversold", default: 30)

        overlays.append(KLExternalChartOverlay(
            id: "overlay.indicator.\(instance.id).\(target.timeframe?.rawValue ?? "all").middle",
            moduleID: "indicator.rsi", moduleName: "RSI", target: target,
            kind: .priceLine, zIndex: 39, visible: true, style: refStyle,
            payload: .horizontalLine(KLHorizontalLinePayload(
                indicatorID: "rsi", indicatorName: "RSI", value: Decimal(50), label: "50"
            )),
            pane: .sub,
            instanceID: instance.id
        ))
        overlays.append(KLExternalChartOverlay(
            id: "overlay.indicator.\(instance.id).\(target.timeframe?.rawValue ?? "all").overbought",
            moduleID: "indicator.rsi", moduleName: "RSI", target: target,
            kind: .priceLine, zIndex: 39, visible: true, style: refStyle,
            payload: .horizontalLine(KLHorizontalLinePayload(
                indicatorID: "rsi", indicatorName: "RSI", value: Decimal(overbought), label: "\(Int(overbought))"
            )),
            pane: .sub,
            instanceID: instance.id
        ))
        overlays.append(KLExternalChartOverlay(
            id: "overlay.indicator.\(instance.id).\(target.timeframe?.rawValue ?? "all").oversold",
            moduleID: "indicator.rsi", moduleName: "RSI", target: target,
            kind: .priceLine, zIndex: 39, visible: true, style: refStyle,
            payload: .horizontalLine(KLHorizontalLinePayload(
                indicatorID: "rsi", indicatorName: "RSI", value: Decimal(oversold), label: "\(Int(oversold))"
            )),
            pane: .sub,
            instanceID: instance.id
        ))
        return overlays
    }

    public func makeTooltip(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance) -> KXIndicatorTooltipSnapshot {
        let period = intParam(instance.params, key: "period", default: 14)
        return KXIndicatorTooltipSnapshot(text: "RSI(\(period))", colorHex: colorHexFromValue(instance.styles["color"]))
    }

    private func intParam(_ params: [String: KXIndicatorParameterValue], key: String, default: Int) -> Int {
        guard let value = params[key] else { return `default` }
        switch value {
        case .int(let v): return v
        case .double(let v): return Int(v)
        default: return `default`
        }
    }

    private func doubleParam(_ params: [String: KXIndicatorParameterValue], key: String, default: Double) -> Double {
        guard let value = params[key] else { return `default` }
        switch value {
        case .double(let v): return v
        case .int(let v): return Double(v)
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

public enum KX震荡指标KXIN01RSI: KXFileSkeletonProtocol {
    public static let version = "2.1"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-01", fileName: "KX-IN-01_RSI.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-01_RSI.swift", duty: "RSI 统一计算实现"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "RSI", passed: true, message: "RSI统一计算实现完成")
    }
}
