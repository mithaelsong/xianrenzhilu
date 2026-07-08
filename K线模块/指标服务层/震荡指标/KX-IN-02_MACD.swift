//
//  KX-IN-02_MACD.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：MACD 统一计算实现，同时服务老 KXIndicatorProtocol 与新 KXProfessionalIndicatorTemplate
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

// MARK: - 统一计算函数

public enum KXMACDCalculator {
    public static func calculate(
        for candles: [KLCandlePoint],
        fastPeriod: Int,
        slowPeriod: Int,
        signalPeriod: Int
    ) -> (dif: [KLIndicatorPoint], dea: [KLIndicatorPoint], hist: [KLIndicatorPoint]) {
        guard candles.count >= slowPeriod + signalPeriod else { return ([], [], []) }
        let closes = candles.map { $0.close.dbl }

        let fastEMA = KXEMACalculator.calculateEMA(values: closes, period: fastPeriod)
        let slowEMA = KXEMACalculator.calculateEMA(values: closes, period: slowPeriod)

        var difValues: [Double] = []
        for i in (slowPeriod - 1)..<closes.count {
            difValues.append(fastEMA[i] - slowEMA[i])
        }

        let signalEMA = KXEMACalculator.calculateEMA(values: difValues, period: signalPeriod)

        var difPoints: [KLIndicatorPoint] = []
        var deaPoints: [KLIndicatorPoint] = []
        var histPoints: [KLIndicatorPoint] = []

        for i in 0..<difValues.count {
            let candleIdx = i + (slowPeriod - 1)
            guard candleIdx < candles.count else { continue }
            let dif = difValues[i]
            let dea = i >= (signalPeriod - 1) ? signalEMA[i - (signalPeriod - 1)] : 0
            let hist = (dif - dea) * 2.0
            difPoints.append(KLIndicatorPoint(time: candles[candleIdx].openTime, value: Decimal(dif)))
            if i >= (signalPeriod - 1) {
                deaPoints.append(KLIndicatorPoint(time: candles[candleIdx].openTime, value: Decimal(dea)))
                histPoints.append(KLIndicatorPoint(time: candles[candleIdx].openTime, value: Decimal(hist)))
            }
        }
        return (difPoints, deaPoints, histPoints)
    }

    public static func crossSignals(
        candles: [KLCandlePoint],
        dif: [KLIndicatorPoint],
        dea: [KLIndicatorPoint]
    ) -> [KXSignal] {
        guard candles.count >= 2 else { return [] }
        let difAligned = alignIndicatorPoints(dif, to: candles)
        let deaAligned = alignIndicatorPoints(dea, to: candles)
        var signals: [KXSignal] = []
        for i in 1..<candles.count {
            guard let prevDif = difAligned[i - 1], let currDif = difAligned[i],
                  let prevDea = deaAligned[i - 1], let currDea = deaAligned[i] else { continue }
            if prevDif <= prevDea && currDif > currDea {
                signals.append(KXSignal(index: i, type: .buy, price: candles[i].close))
            } else if prevDif >= prevDea && currDif < currDea {
                signals.append(KXSignal(index: i, type: .sell, price: candles[i].close))
            }
        }
        return signals
    }
}

// MARK: - 老协议兼容计算器

public struct MACDCalculator: KXIndicatorProtocol {
    public var identifier: String { "KX-IN-02" }
    public var name: String { "MACD" }
    public var englishName: String { "Moving Average Convergence Divergence" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "fastPeriod": 12.0,
            "slowPeriod": 26.0,
            "signalPeriod": 9.0
        ]
    }

    public init(parameters: KXIndicatorParameters = .defaultMACD) {
        self.parameters = parameters
    }

    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let fastPeriod = Int(parameters.values["fastPeriod"] ?? 12)
        let slowPeriod = Int(parameters.values["slowPeriod"] ?? 26)
        let signalPeriod = Int(parameters.values["signalPeriod"] ?? 9)
        let result = KXMACDCalculator.calculate(for: candles, fastPeriod: fastPeriod, slowPeriod: slowPeriod, signalPeriod: signalPeriod)

        let difAligned = alignIndicatorPoints(result.dif, to: candles)
        let deaAligned = alignIndicatorPoints(result.dea, to: candles)
        let histAligned = alignIndicatorPoints(result.hist, to: candles)
        let signals = KXMACDCalculator.crossSignals(candles: candles, dif: result.dif, dea: result.dea)

        return KXIndicatorResult(
            values: difAligned,
            namedValues: ["dif": difAligned, "dea": deaAligned, "hist": histAligned],
            signals: signals
        )
    }
}

public extension KXIndicatorParameters {
    static var defaultMACD: KXIndicatorParameters {
        KXIndicatorParameters(values: ["fastPeriod": 12, "slowPeriod": 26, "signalPeriod": 9])
    }
}

// MARK: - 新专业指标模板

public struct KXIN_MACD_Template: KXProfessionalIndicatorTemplate {
    public let indicatorID = "macd"
    public let name = "MACD"
    public let defaultPane: KLOverlayPane = .sub

    public var parameterSchema: [KXIndicatorParameterSchema] {
        [
            KXIndicatorParameterSchema(key: "fastPeriod", title: "快线周期", kind: .integer,
                                       defaultValue: .int(12), min: 1, max: 200, step: 1),
            KXIndicatorParameterSchema(key: "slowPeriod", title: "慢线周期", kind: .integer,
                                       defaultValue: .int(26), min: 2, max: 500, step: 1),
            KXIndicatorParameterSchema(key: "signalPeriod", title: "信号周期", kind: .integer,
                                       defaultValue: .int(9), min: 1, max: 200, step: 1)
        ]
    }

    public var styleSchema: [KXIndicatorParameterSchema] {
        [
            KXIndicatorParameterSchema(key: "difColor", title: "DIF颜色", kind: .color, defaultValue: .colorHex("#00FFFFFF")),
            KXIndicatorParameterSchema(key: "deaColor", title: "DEA颜色", kind: .color, defaultValue: .colorHex("#FF9500FF")),
            KXIndicatorParameterSchema(key: "barColor", title: "柱颜色", kind: .color, defaultValue: .colorHex("#30D158FF")),
            KXIndicatorParameterSchema(key: "lineWidth", title: "线宽", kind: .lineWidth, defaultValue: .double(1.5)),
            KXIndicatorParameterSchema(key: "opacity", title: "透明度", kind: .opacity, defaultValue: .double(1.0))
        ]
    }

    public var figureSchema: [KXIndicatorFigureSchema] {
        [
            KXIndicatorFigureSchema(key: "dif", title: "DIF", type: .line, pane: .sub, styleKey: "difColor", zIndex: 40),
            KXIndicatorFigureSchema(key: "dea", title: "DEA", type: .line, pane: .sub, styleKey: "deaColor", zIndex: 40),
            KXIndicatorFigureSchema(key: "hist", title: "MACD", type: .bar, pane: .sub, styleKey: "barColor", zIndex: 40)
        ]
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
        let fast = intParam(instance.params, key: "fastPeriod", default: 12)
        let slow = intParam(instance.params, key: "slowPeriod", default: 26)
        let signal = intParam(instance.params, key: "signalPeriod", default: 9)
        let result = KXMACDCalculator.calculate(for: context.candles, fastPeriod: fast, slowPeriod: slow, signalPeriod: signal)
        let signals = KXMACDCalculator.crossSignals(candles: context.candles, dif: result.dif, dea: result.dea)
        return KXIndicatorCalculationOutput(
            series: ["dif": result.dif, "dea": result.dea, "hist": result.hist],
            latestValues: [
                "dif": result.dif.last?.value ?? Decimal(0),
                "dea": result.dea.last?.value ?? Decimal(0),
                "hist": result.hist.last?.value ?? Decimal(0)
            ],
            signals: signals
        )
    }

    public func makeOverlays(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance, target: KLOverlayTarget) -> [KLExternalChartOverlay] {
        KXIndicatorOverlayAdapter.adapt(output: output, instance: instance, figureSchema: figureSchema, target: target)
    }

    public func makeTooltip(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance) -> KXIndicatorTooltipSnapshot {
        return KXIndicatorTooltipSnapshot(text: "MACD", colorHex: colorHexFromValue(instance.styles["difColor"]))
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

public enum KX震荡指标KXIN02MACD: KXFileSkeletonProtocol {
    public static let version = "2.1"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-02", fileName: "KX-IN-02_MACD.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-02_MACD.swift", duty: "MACD 统一计算实现"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "MACD", passed: true, message: "MACD统一计算实现完成")
    }
}
