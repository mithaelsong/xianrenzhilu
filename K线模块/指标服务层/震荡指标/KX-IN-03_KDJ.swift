//
//  KX-IN-03_KDJ.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：KDJ（随机指标）统一计算实现，同时服务老 KXIndicatorProtocol 与新 KXProfessionalIndicatorTemplate
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

// MARK: - 统一计算函数

public enum KXKDJCalculator {
    public static func calculate(
        for candles: [KLCandlePoint],
        kPeriod: Int,
        dPeriod: Int
    ) -> (k: [KLIndicatorPoint], d: [KLIndicatorPoint], j: [KLIndicatorPoint]) {
        guard candles.count >= kPeriod else { return ([], [], []) }

        var rsv: [Double] = []
        for i in (kPeriod - 1)..<candles.count {
            let slice = candles[(i - kPeriod + 1)...i]
            let lowest = slice.map { $0.low.dbl }.min() ?? 0
            let highest = slice.map { $0.high.dbl }.max() ?? 0
            let close = candles[i].close.dbl
            if highest == lowest {
                rsv.append(50)
            } else {
                rsv.append((close - lowest) / (highest - lowest) * 100)
            }
        }

        let k = sma(rsv, period: kPeriod)
        let d = sma(k, period: dPeriod)
        let start = kPeriod + kPeriod - 2

        var kPoints: [KLIndicatorPoint] = []
        var dPoints: [KLIndicatorPoint] = []
        var jPoints: [KLIndicatorPoint] = []

        for i in 0..<min(k.count, d.count) {
            let candleIdx = i + start
            guard candleIdx < candles.count else { continue }
            let jv = 3 * k[i] - 2 * d[i]
            kPoints.append(KLIndicatorPoint(time: candles[candleIdx].openTime, value: Decimal(k[i])))
            dPoints.append(KLIndicatorPoint(time: candles[candleIdx].openTime, value: Decimal(d[i])))
            jPoints.append(KLIndicatorPoint(time: candles[candleIdx].openTime, value: Decimal(jv)))
        }
        return (kPoints, dPoints, jPoints)
    }

    public static func crossSignals(
        candles: [KLCandlePoint],
        k: [KLIndicatorPoint],
        d: [KLIndicatorPoint],
        overbought: Double,
        oversold: Double,
        j: [KLIndicatorPoint]
    ) -> [KXSignal] {
        guard candles.count >= 2 else { return [] }
        let kAligned = alignIndicatorPoints(k, to: candles)
        let dAligned = alignIndicatorPoints(d, to: candles)
        let jAligned = alignIndicatorPoints(j, to: candles)
        var signals: [KXSignal] = []
        for i in 1..<candles.count {
            guard let prevK = kAligned[i - 1], let currK = kAligned[i],
                  let prevD = dAligned[i - 1], let currD = dAligned[i] else { continue }
            if prevK <= prevD && currK > currD {
                signals.append(KXSignal(index: i, type: .buy, price: candles[i].close))
            } else if prevK >= prevD && currK < currD {
                signals.append(KXSignal(index: i, type: .sell, price: candles[i].close))
            }
            if let currJ = jAligned[i] {
                if currJ > overbought {
                    signals.append(KXSignal(index: i, type: .strongSell, price: candles[i].close))
                }
                if currJ < oversold {
                    signals.append(KXSignal(index: i, type: .strongBuy, price: candles[i].close))
                }
            }
        }
        return signals
    }

    private static func sma(_ values: [Double], period: Int) -> [Double] {
        guard values.count >= period else { return [] }
        var result: [Double] = []
        for i in (period - 1)..<values.count {
            let avg = values[(i - period + 1)...i].reduce(0, +) / Double(period)
            result.append(avg)
        }
        return result
    }
}

// MARK: - 老协议兼容计算器

public struct KDJCalculator: KXIndicatorProtocol {
    public var identifier: String { "KX-IN-03" }
    public var name: String { "KDJ" }
    public var englishName: String { "KDJ" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "kPeriod": 9.0,
            "dPeriod": 3.0,
            "overbought": 80.0,
            "oversold": 20.0
        ]
    }

    public init(parameters: KXIndicatorParameters = .defaultKDJ) {
        self.parameters = parameters
    }

    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let kPeriod = Int(parameters.values["kPeriod"] ?? 9)
        let dPeriod = Int(parameters.values["dPeriod"] ?? 3)
        let overbought = parameters.values["overbought"] ?? 80.0
        let oversold = parameters.values["oversold"] ?? 20.0
        let result = KXKDJCalculator.calculate(for: candles, kPeriod: kPeriod, dPeriod: dPeriod)
        let signals = KXKDJCalculator.crossSignals(
            candles: candles, k: result.k, d: result.d,
            overbought: overbought, oversold: oversold, j: result.j
        )
        let kAligned = alignIndicatorPoints(result.k, to: candles)
        let dAligned = alignIndicatorPoints(result.d, to: candles)
        let jAligned = alignIndicatorPoints(result.j, to: candles)
        return KXIndicatorResult(
            values: kAligned,
            namedValues: ["K": kAligned, "D": dAligned, "J": jAligned],
            signals: signals
        )
    }
}

public extension KXIndicatorParameters {
    static var defaultKDJ: KXIndicatorParameters {
        KXIndicatorParameters(values: [
            "kPeriod": 9, "dPeriod": 3, "jPeriod": 3,
            "overbought": 80.0, "oversold": 20.0
        ])
    }
}

// MARK: - 新专业指标模板

public struct KXIN_KDJ_Template: KXProfessionalIndicatorTemplate {
    public let indicatorID = "kdj"
    public let name = "KDJ"
    public let defaultPane: KLOverlayPane = .sub

    public var parameterSchema: [KXIndicatorParameterSchema] {
        [
            KXIndicatorParameterSchema(key: "kPeriod", title: "K周期", kind: .integer,
                                       defaultValue: .int(9), min: 1, max: 200, step: 1),
            KXIndicatorParameterSchema(key: "dPeriod", title: "D周期", kind: .integer,
                                       defaultValue: .int(3), min: 1, max: 100, step: 1),
            KXIndicatorParameterSchema(key: "overbought", title: "超买", kind: .decimal,
                                       defaultValue: .double(80), min: 50, max: 100, step: 1),
            KXIndicatorParameterSchema(key: "oversold", title: "超卖", kind: .decimal,
                                       defaultValue: .double(20), min: 0, max: 50, step: 1)
        ]
    }

    public var styleSchema: [KXIndicatorParameterSchema] {
        [
            KXIndicatorParameterSchema(key: "kColor", title: "K颜色", kind: .color, defaultValue: .colorHex("#FFCC00FF")),
            KXIndicatorParameterSchema(key: "dColor", title: "D颜色", kind: .color, defaultValue: .colorHex("#00FFFFFF")),
            KXIndicatorParameterSchema(key: "jColor", title: "J颜色", kind: .color, defaultValue: .colorHex("#BF5AF2FF")),
            KXIndicatorParameterSchema(key: "lineWidth", title: "线宽", kind: .lineWidth, defaultValue: .double(1.5)),
            KXIndicatorParameterSchema(key: "opacity", title: "透明度", kind: .opacity, defaultValue: .double(1.0))
        ]
    }

    public var figureSchema: [KXIndicatorFigureSchema] {
        [
            KXIndicatorFigureSchema(key: "K", title: "K", type: .line, pane: .sub, styleKey: "kColor", zIndex: 40),
            KXIndicatorFigureSchema(key: "D", title: "D", type: .line, pane: .sub, styleKey: "dColor", zIndex: 40),
            KXIndicatorFigureSchema(key: "J", title: "J", type: .line, pane: .sub, styleKey: "jColor", zIndex: 40)
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
        let kPeriod = intParam(instance.params, key: "kPeriod", default: 9)
        let dPeriod = intParam(instance.params, key: "dPeriod", default: 3)
        let overbought = doubleParam(instance.params, key: "overbought", default: 80)
        let oversold = doubleParam(instance.params, key: "oversold", default: 20)
        let result = KXKDJCalculator.calculate(for: context.candles, kPeriod: kPeriod, dPeriod: dPeriod)
        let signals = KXKDJCalculator.crossSignals(
            candles: context.candles, k: result.k, d: result.d,
            overbought: overbought, oversold: oversold, j: result.j
        )
        return KXIndicatorCalculationOutput(
            series: ["K": result.k, "D": result.d, "J": result.j],
            latestValues: [
                "K": result.k.last?.value ?? Decimal(0),
                "D": result.d.last?.value ?? Decimal(0),
                "J": result.j.last?.value ?? Decimal(0)
            ],
            signals: signals
        )
    }

    public func makeOverlays(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance, target: KLOverlayTarget) -> [KLExternalChartOverlay] {
        KXIndicatorOverlayAdapter.adapt(output: output, instance: instance, figureSchema: figureSchema, target: target)
    }

    public func makeTooltip(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance) -> KXIndicatorTooltipSnapshot {
        return KXIndicatorTooltipSnapshot(text: "KDJ", colorHex: colorHexFromValue(instance.styles["kColor"]))
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

public enum KX震荡指标KXIN03KDJ: KXFileSkeletonProtocol {
    public static let version = "2.1"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-03", fileName: "KX-IN-03_KDJ.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-03_KDJ.swift", duty: "KDJ 统一计算实现"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "KDJ", passed: true, message: "KDJ统一计算实现完成")
    }
}
