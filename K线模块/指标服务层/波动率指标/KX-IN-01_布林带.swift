//
//  KX-IN-01_布林带.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：布林带 (Bollinger Bands) 统一计算实现，同时服务老 KXIndicatorProtocol 与新 KXProfessionalIndicatorTemplate
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型
//

import Foundation

// MARK: - 统一计算函数

public enum KXBollingerBandsCalculator {
    public static func calculate(
        for candles: [KLCandlePoint],
        period: Int,
        multiplier: Double
    ) -> (mid: [KLIndicatorPoint], upper: [KLIndicatorPoint], lower: [KLIndicatorPoint]) {
        guard candles.count >= period else { return ([], [], []) }
        let closes = candles.map { $0.close.dbl }

        var midPoints: [KLIndicatorPoint] = []
        var upperPoints: [KLIndicatorPoint] = []
        var lowerPoints: [KLIndicatorPoint] = []

        for i in (period - 1)..<closes.count {
            let slice = closes[(i - period + 1)...i]
            let mean = slice.reduce(0, +) / Double(period)
            let variance = slice.map { pow($0 - mean, 2) }.reduce(0, +) / Double(period)
            let sd = sqrt(variance)
            let upper = mean + multiplier * sd
            let lower = mean - multiplier * sd
            midPoints.append(KLIndicatorPoint(time: candles[i].openTime, value: Decimal(mean)))
            upperPoints.append(KLIndicatorPoint(time: candles[i].openTime, value: Decimal(upper)))
            lowerPoints.append(KLIndicatorPoint(time: candles[i].openTime, value: Decimal(lower)))
        }
        return (midPoints, upperPoints, lowerPoints)
    }

    public static func bandSignals(
        candles: [KLCandlePoint],
        upper: [KLIndicatorPoint],
        lower: [KLIndicatorPoint]
    ) -> [KXSignal] {
        guard candles.count >= 2 else { return [] }
        let upperAligned = alignIndicatorPoints(upper, to: candles)
        let lowerAligned = alignIndicatorPoints(lower, to: candles)
        var signals: [KXSignal] = []
        for i in 0..<candles.count {
            let close = candles[i].close.dbl
            if let lowerValue = lowerAligned[i], close <= lowerValue {
                signals.append(KXSignal(index: i, type: .buy, price: candles[i].close))
            }
            if let upperValue = upperAligned[i], close >= upperValue {
                signals.append(KXSignal(index: i, type: .sell, price: candles[i].close))
            }
        }
        return signals
    }
}

// MARK: - 老协议兼容计算器

public struct BollingerBandsCalculator: KXIndicatorProtocol {
    public var identifier: String { "KX-IN-01" }
    public var name: String { "布林带" }
    public var englishName: String { "Bollinger Bands" }
    public var category: KXIndicatorCategory { .volatility }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 20.0,
            "multiplier": 2.0
        ]
    }

    public init(parameters: KXIndicatorParameters = .defaultBollingerBands) {
        self.parameters = parameters
    }

    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 20)
        let multiplier = parameters.values["multiplier"] ?? 2.0
        let result = KXBollingerBandsCalculator.calculate(for: candles, period: period, multiplier: multiplier)
        let midAligned = alignIndicatorPoints(result.mid, to: candles)
        let upperAligned = alignIndicatorPoints(result.upper, to: candles)
        let lowerAligned = alignIndicatorPoints(result.lower, to: candles)
        let signals = KXBollingerBandsCalculator.bandSignals(candles: candles, upper: result.upper, lower: result.lower)
        return KXIndicatorResult(
            values: midAligned,
            namedValues: ["mid": midAligned, "upper": upperAligned, "lower": lowerAligned],
            signals: signals
        )
    }
}

public extension KXIndicatorParameters {
    static var defaultBollingerBands: KXIndicatorParameters {
        KXIndicatorParameters(values: ["period": 20, "multiplier": 2.0])
    }
}

// MARK: - 新专业指标模板

public struct KXIN_BOLL_Template: KXProfessionalIndicatorTemplate {
    public let indicatorID = "boll"
    public let name = "布林带"
    public let defaultPane: KLOverlayPane = .main

    public var parameterSchema: [KXIndicatorParameterSchema] {
        [
            KXIndicatorParameterSchema(key: "period", title: "周期", kind: .integer,
                                       defaultValue: .int(20), min: 2, max: 500, step: 1),
            KXIndicatorParameterSchema(key: "multiplier", title: "标准差倍数", kind: .decimal,
                                       defaultValue: .double(2.0), min: 0.1, max: 10, step: 0.1)
        ]
    }

    public var styleSchema: [KXIndicatorParameterSchema] {
        [
            KXIndicatorParameterSchema(key: "midColor", title: "中轨颜色", kind: .color, defaultValue: .colorHex("#FFD60AFF")),
            KXIndicatorParameterSchema(key: "bandColor", title: "轨道颜色", kind: .color, defaultValue: .colorHex("#64D2FFFF")),
            KXIndicatorParameterSchema(key: "lineWidth", title: "线宽", kind: .lineWidth, defaultValue: .double(1.2)),
            KXIndicatorParameterSchema(key: "opacity", title: "透明度", kind: .opacity, defaultValue: .double(1.0))
        ]
    }

    public var figureSchema: [KXIndicatorFigureSchema] {
        [
            KXIndicatorFigureSchema(key: "mid", title: "MID", type: .line, pane: .main, styleKey: "midColor", zIndex: 40),
            KXIndicatorFigureSchema(key: "upper", title: "UP", type: .band, pane: .main, styleKey: "bandColor", zIndex: 40),
            KXIndicatorFigureSchema(key: "lower", title: "DN", type: .band, pane: .main, styleKey: "bandColor", zIndex: 40)
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
        let period = intParam(instance.params, key: "period", default: 20)
        let multiplier = doubleParam(instance.params, key: "multiplier", default: 2.0)
        let result = KXBollingerBandsCalculator.calculate(for: context.candles, period: period, multiplier: multiplier)
        let signals = KXBollingerBandsCalculator.bandSignals(candles: context.candles, upper: result.upper, lower: result.lower)
        return KXIndicatorCalculationOutput(
            series: ["mid": result.mid, "upper": result.upper, "lower": result.lower],
            latestValues: [
                "mid": result.mid.last?.value ?? Decimal(0),
                "upper": result.upper.last?.value ?? Decimal(0),
                "lower": result.lower.last?.value ?? Decimal(0)
            ],
            signals: signals
        )
    }

    public func makeOverlays(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance, target: KLOverlayTarget) -> [KLExternalChartOverlay] {
        KXIndicatorOverlayAdapter.adapt(output: output, instance: instance, figureSchema: figureSchema, target: target)
    }

    public func makeTooltip(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance) -> KXIndicatorTooltipSnapshot {
        return KXIndicatorTooltipSnapshot(text: "BOLL", colorHex: colorHexFromValue(instance.styles["midColor"]))
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

public enum KX重叠指标KXIN01布林带: KXFileSkeletonProtocol {
    public static let version = "2.1"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-01", fileName: "KX-IN-01_布林带.swift", layer: .indicator,
        relativePath: "指标服务层/波动率指标/KX-IN-01_布林带.swift", duty: "布林带 统一计算实现"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "布林带", passed: true, message: "布林带统一计算实现完成")
    }
}
