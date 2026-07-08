//
//  KX-IN-01_MA.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：MA（简单移动平均线）统一计算实现，同时服务老 KXIndicatorProtocol 与新 KXProfessionalIndicatorTemplate
//  显示位置：K线主图叠加
//  依赖：KX-03_公共类型定义
//

import Foundation

// MARK: - 统一计算函数

public enum KXMACalculator {
    public static func calculate(
        for candles: [KLCandlePoint],
        period: Int,
        source: String = "close",
        offset: Int = 0
    ) -> [KLIndicatorPoint] {
        guard period > 0, candles.count >= period else { return [] }

        let values = sourceValues(from: candles, source: source)
        guard values.count >= period else { return [] }
        
        var result: [KLIndicatorPoint] = []
        result.reserveCapacity(values.count - period + 1)
        
        // 滑动窗口求和：O(N) 而非 O(N*period)
        var windowSum = values[0..<period].reduce(0, +)
        for i in period..<values.count {
            let ma = windowSum / Double(period)
            let targetIndex = i - 1 + offset
            if targetIndex >= 0 && targetIndex < candles.count {
                result.append(KLIndicatorPoint(time: candles[targetIndex].openTime, value: Decimal(ma)))
            }
            windowSum += values[i] - values[i - period]
        }
        // 最后一项
        let ma = windowSum / Double(period)
        let targetIndex = values.count - 1 + offset
        if targetIndex >= 0 && targetIndex < candles.count {
            result.append(KLIndicatorPoint(time: candles[targetIndex].openTime, value: Decimal(ma)))
        }
        return result
    }

    public static func priceCrossSignals(
        candles: [KLCandlePoint],
        maValues: [KLIndicatorPoint]
    ) -> [KXSignal] {
        guard candles.count >= 2 else { return [] }
        let aligned = alignValues(maValues, to: candles)
        var signals: [KXSignal] = []
        for i in 1..<candles.count {
            guard let prevMA = aligned[i - 1], let currMA = aligned[i] else { continue }
            let prevPrice = candles[i - 1].close.dbl
            let currPrice = candles[i].close.dbl
            let prevAbove = prevPrice > prevMA
            let currAbove = currPrice > currMA
            if !prevAbove && currAbove {
                signals.append(KXSignal(index: i, type: .buy, price: candles[i].close))
            } else if prevAbove && !currAbove {
                signals.append(KXSignal(index: i, type: .sell, price: candles[i].close))
            }
        }
        return signals
    }

    private static func sourceValues(from candles: [KLCandlePoint], source: String) -> [Double] {
        switch source {
        case "open": return candles.map { $0.open.dbl }
        case "high": return candles.map { $0.high.dbl }
        case "low": return candles.map { $0.low.dbl }
        case "hl2": return candles.map { ($0.high.dbl + $0.low.dbl) / 2 }
        case "hlc3": return candles.map { ($0.high.dbl + $0.low.dbl + $0.close.dbl) / 3 }
        case "ohlc4": return candles.map { ($0.open.dbl + $0.high.dbl + $0.low.dbl + $0.close.dbl) / 4 }
        default: return candles.map { $0.close.dbl }
        }
    }

    private static func alignValues(_ values: [KLIndicatorPoint], to candles: [KLCandlePoint]) -> [Double?] {
        var result: [Double?] = Array(repeating: nil, count: candles.count)
        let timeIndexMap = Dictionary(uniqueKeysWithValues: candles.enumerated().map { ($1.openTime, $0) })
        for v in values {
            if let idx = timeIndexMap[v.time] {
                result[idx] = v.value.dbl
            }
        }
        return result
    }
}

// MARK: - 老协议兼容计算器

public struct MACalculator: KXIndicatorProtocol {
    public var identifier: String { "KX-IN-01" }
    public var name: String { "MA" }
    public var englishName: String { "Simple Moving Average" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 20.0
        ]
    }

    public init(parameters: KXIndicatorParameters = .defaultMA) {
        self.parameters = parameters
    }

    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 20)
        let points = KXMACalculator.calculate(for: candles, period: period)
        let aligned = alignIndicatorPoints(points, to: candles)
        let signals = KXMACalculator.priceCrossSignals(candles: candles, maValues: points)
        return KXIndicatorResult(values: aligned, signals: signals)
    }
}

public extension KXIndicatorParameters {
    static var defaultMA: KXIndicatorParameters {
        var params = KXIndicatorParameters()
        params.values["period"] = 20
        return params
    }
}

// MARK: - 新专业指标模板

public struct KXIN_MA_Template: KXProfessionalIndicatorTemplate {
    public let indicatorID = "ma"
    public let name = "MA"
    public let defaultPane: KLOverlayPane = .main

    public var parameterSchema: [KXIndicatorParameterSchema] {
        [
            KXIndicatorParameterSchema(key: "period", title: "周期", kind: .integer,
                                       defaultValue: .int(20), min: 1, max: 500, step: 1, help: "移动平均周期"),
            KXIndicatorParameterSchema(key: "source", title: "数据源", kind: .dataSource,
                                       defaultValue: .option("close"),
                                       options: [
                                           KXIndicatorOption(value: "close", label: "收盘价"),
                                           KXIndicatorOption(value: "open", label: "开盘价"),
                                           KXIndicatorOption(value: "high", label: "最高价"),
                                           KXIndicatorOption(value: "low", label: "最低价"),
                                           KXIndicatorOption(value: "hl2", label: "高低平均"),
                                           KXIndicatorOption(value: "hlc3", label: "高低收平均"),
                                           KXIndicatorOption(value: "ohlc4", label: "开高收低平均")
                                       ], help: "计算数据源"),
            KXIndicatorParameterSchema(key: "offset", title: "偏移", kind: .integer,
                                       defaultValue: .int(0), min: -500, max: 500, step: 1, help: "向前或向后偏移")
        ]
    }

    public var styleSchema: [KXIndicatorParameterSchema] {
        [
            KXIndicatorParameterSchema(key: "color", title: "颜色", kind: .color, defaultValue: .colorHex("#00FFFF")),
            KXIndicatorParameterSchema(key: "lineWidth", title: "线宽", kind: .lineWidth, defaultValue: .double(1.5)),
            KXIndicatorParameterSchema(key: "lineStyle", title: "线型", kind: .lineStyle,
                                       defaultValue: .option("solid"),
                                       options: [
                                           KXIndicatorOption(value: "solid", label: "实线"),
                                           KXIndicatorOption(value: "dashed", label: "虚线"),
                                           KXIndicatorOption(value: "dotted", label: "点线")
                                       ]),
            KXIndicatorParameterSchema(key: "opacity", title: "透明度", kind: .opacity, defaultValue: .double(1.0), min: 0, max: 1, step: 0.1),
            KXIndicatorParameterSchema(key: "visible", title: "显示", kind: .boolean, defaultValue: .bool(true))
        ]
    }

    public var figureSchema: [KXIndicatorFigureSchema] {
        [KXIndicatorFigureSchema(key: "ma", title: "MA", type: .line, pane: .main, styleKey: "ma", zIndex: 40)]
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
        let source = stringParam(instance.params, key: "source", default: "close")
        let offset = intParam(instance.params, key: "offset", default: 0)
        let values = KXMACalculator.calculate(for: context.candles, period: period, source: source, offset: offset)
        let latest = values.last?.value ?? Decimal(0)
        let signals = KXMACalculator.priceCrossSignals(candles: context.candles, maValues: values)
        return KXIndicatorCalculationOutput(series: ["ma": values], latestValues: ["ma": latest], signals: signals)
    }

    public func makeOverlays(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance, target: KLOverlayTarget) -> [KLExternalChartOverlay] {
        KXIndicatorOverlayAdapter.adapt(output: output, instance: instance, figureSchema: figureSchema, target: target)
    }

    public func makeTooltip(output: KXIndicatorCalculationOutput, instance: KXProfessionalIndicatorInstance) -> KXIndicatorTooltipSnapshot {
        let period = intParam(instance.params, key: "period", default: 20)
        return KXIndicatorTooltipSnapshot(text: "MA(\(period))", colorHex: colorHexFromValue(instance.styles["color"]))
    }

    private func intParam(_ params: [String: KXIndicatorParameterValue], key: String, default: Int) -> Int {
        guard let value = params[key] else { return `default` }
        switch value {
        case .int(let v): return v
        case .double(let v): return Int(v)
        default: return `default`
        }
    }

    private func stringParam(_ params: [String: KXIndicatorParameterValue], key: String, default: String) -> String {
        guard let value = params[key] else { return `default` }
        switch value {
        case .string(let v): return v
        case .option(let v): return v
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
    for p in points {
        if let idx = candles.firstIndex(where: { $0.openTime == p.time }) {
            result[idx] = p.value.dbl
        }
    }
    return result
}

// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN01MA: KXFileSkeletonProtocol {
    public static let version = "2.1"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-01", fileName: "KX-IN-01_MA.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-01_MA.swift", duty: "MA 统一计算实现"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "MA", passed: true, message: "MA统一计算实现完成")
    }
}
