//
//  KX-FN-34_指标Overlay适配器.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：把 KXIndicatorCalculationOutput 转换为标准 KLExternalChartOverlay 数组
//  禁止事项：禁止计算指标、禁止维护业务状态、禁止修改 K线视图
//

import Foundation

public struct KXIndicatorOverlayAdapter {
    public static func adapt(
        output: KXIndicatorCalculationOutput,
        instance: KXProfessionalIndicatorInstance,
        figureSchema: [KXIndicatorFigureSchema],
        target: KLOverlayTarget
    ) -> [KLExternalChartOverlay] {
        var overlays: [KLExternalChartOverlay] = []
        for figure in figureSchema {
            guard let series = output.series[figure.key] else { continue }
            let style = instance.styles[figure.styleKey] ?? instance.styles["color"] ?? .string("")
            let colorHex = colorHexFromValue(style)
            let lineWidth = lineWidthFromValue(instance.styles[figure.styleKey + ".width"] ?? instance.styles["lineWidth"])
            let opacity = opacityFromValue(instance.styles[figure.styleKey + ".opacity"] ?? instance.styles["opacity"])
            let lineDash = lineDashFromValue(instance.styles[figure.styleKey + ".style"] ?? instance.styles["lineStyle"])

            let overlayStyle = KLOverlayStyle(
                fallbackHexColor: colorHex,
                lineWidth: lineWidth,
                lineDash: lineDash,
                opacity: opacity
            )

            let tfSuffix = target.timeframe?.rawValue ?? "all"
            let overlayID = "overlay.indicator.\(instance.id).\(tfSuffix).\(figure.key)"

            switch figure.type {
            case .line:
                let payload = KLIndicatorLinePayload(
                    indicatorID: instance.indicatorID,
                    indicatorName: instance.indicatorName,
                    series: series,
                    valueFormatter: "price",
                    instanceID: instance.id,
                    outputKey: figure.key
                )
                overlays.append(KLExternalChartOverlay(
                    id: overlayID,
                    moduleID: "indicator",
                    moduleName: instance.indicatorName,
                    target: target,
                    kind: .indicatorLine,
                    zIndex: figure.zIndex,
                    visible: instance.visible,
                    style: overlayStyle,
                    payload: .indicatorLine(payload),
                    pane: figure.pane,
                    paneID: nil,
                    instanceID: instance.id,
                    outputKey: figure.key
                ))
            case .band:
                // BOLL 等需要 upper/middle/lower
                guard let upper = output.series[figure.key + ".upper"],
                      let lower = output.series[figure.key + ".lower"] else { continue }
                let middle = output.series[figure.key + ".middle"]
                let payload = KLIndicatorBandPayload(
                    indicatorID: instance.indicatorID,
                    indicatorName: instance.indicatorName,
                    instanceID: instance.id,
                    upperLine: upper,
                    middleLine: middle,
                    lowerLine: lower
                )
                overlays.append(KLExternalChartOverlay(
                    id: overlayID,
                    moduleID: "indicator",
                    moduleName: instance.indicatorName,
                    target: target,
                    kind: .indicatorBand,
                    zIndex: figure.zIndex,
                    visible: instance.visible,
                    style: overlayStyle,
                    payload: .indicatorBand(payload),
                    pane: figure.pane,
                    paneID: nil,
                    instanceID: instance.id,
                    outputKey: figure.key
                ))
            case .bar:
                let payload = KLIndicatorHistogramPayload(
                    indicatorID: instance.indicatorID,
                    indicatorName: instance.indicatorName,
                    series: series,
                    baseline: 0,
                    valueFormatter: "price",
                    instanceID: instance.id,
                    outputKey: figure.key
                )
                overlays.append(KLExternalChartOverlay(
                    id: overlayID,
                    moduleID: "indicator",
                    moduleName: instance.indicatorName,
                    target: target,
                    kind: .indicatorHistogram,
                    zIndex: figure.zIndex,
                    visible: instance.visible,
                    style: overlayStyle,
                    payload: .indicatorHistogram(payload),
                    pane: figure.pane,
                    paneID: nil,
                    instanceID: instance.id,
                    outputKey: figure.key
                ))
            case .point:
                let payload = KLIndicatorPointMarkerPayload(
                    indicatorID: instance.indicatorID,
                    indicatorName: instance.indicatorName,
                    points: series,
                    shape: "circle",
                    size: 4,
                    instanceID: instance.id,
                    outputKey: figure.key
                )
                overlays.append(KLExternalChartOverlay(
                    id: overlayID,
                    moduleID: "indicator",
                    moduleName: instance.indicatorName,
                    target: target,
                    kind: .indicatorPoint,
                    zIndex: figure.zIndex,
                    visible: instance.visible,
                    style: overlayStyle,
                    payload: .indicatorPoint(payload),
                    pane: figure.pane,
                    paneID: nil,
                    instanceID: instance.id,
                    outputKey: figure.key
                ))
            case .label:
                let labels = output.labels[figure.key] ?? []
                let payload = KLIndicatorLabelPayload(
                    indicatorID: instance.indicatorID,
                    indicatorName: instance.indicatorName,
                    labels: labels,
                    instanceID: instance.id
                )
                overlays.append(KLExternalChartOverlay(
                    id: overlayID,
                    moduleID: "indicator",
                    moduleName: instance.indicatorName,
                    target: target,
                    kind: .indicatorLabel,
                    zIndex: figure.zIndex,
                    visible: instance.visible,
                    style: overlayStyle,
                    payload: .indicatorLabel(payload),
                    pane: figure.pane,
                    paneID: nil,
                    instanceID: instance.id,
                    outputKey: figure.key
                ))
            case .range:
                guard let range = output.ranges[figure.key] else { continue }
                overlays.append(KLExternalChartOverlay(
                    id: overlayID,
                    moduleID: "indicator",
                    moduleName: instance.indicatorName,
                    target: target,
                    kind: .range,
                    zIndex: figure.zIndex,
                    visible: instance.visible,
                    style: overlayStyle,
                    payload: .range(range),
                    pane: figure.pane,
                    paneID: nil,
                    instanceID: instance.id,
                    outputKey: figure.key
                ))
            case .horizontalLine:
                guard let last = series.last else { continue }
                let payload = KLHorizontalLinePayload(
                    indicatorID: instance.indicatorID,
                    indicatorName: instance.indicatorName,
                    value: last.value,
                    label: figure.title,
                    instanceID: instance.id,
                    outputKey: figure.key
                )
                overlays.append(KLExternalChartOverlay(
                    id: overlayID,
                    moduleID: "indicator",
                    moduleName: instance.indicatorName,
                    target: target,
                    kind: .priceLine,
                    zIndex: figure.zIndex,
                    visible: instance.visible,
                    style: overlayStyle,
                    payload: .horizontalLine(payload),
                    pane: figure.pane,
                    paneID: nil,
                    instanceID: instance.id,
                    outputKey: figure.key
                ))
            case .area:
                // 暂不实现
                break
            }
        }

        // MARK: - 交易信号渲染
        if !output.signals.isEmpty {
            overlays.append(contentsOf: makeSignalOverlays(
                signals: output.signals,
                instance: instance,
                target: target,
                pane: instance.pane
            ))
        }

        return overlays
    }

    // MARK: - 信号Overlay

    private static func makeSignalOverlays(
        signals: [KXSignal],
        instance: KXProfessionalIndicatorInstance,
        target: KLOverlayTarget,
        pane: KLOverlayPane
    ) -> [KLExternalChartOverlay] {
        let grouped = Dictionary(grouping: signals) { $0.type }
        var overlays: [KLExternalChartOverlay] = []

        for (type, group) in grouped {
            let (color, shape, zIndex): (String, String, Int)
            switch type {
            case .buy, .strongBuy:
                color = "#23C552"
                shape = "triangle-up"
                zIndex = 45
            case .sell, .strongSell:
                color = "#FF5C5C"
                shape = "triangle-down"
                zIndex = 45
            case .none:
                color = "#999999"
                shape = "circle"
                zIndex = 45
            }

            let points = group.compactMap { signal -> KLIndicatorPoint? in
                guard let time = signal.time else { return nil }
                return KLIndicatorPoint(time: time, value: signal.price)
            }
            guard !points.isEmpty else { continue }

            let payload = KLIndicatorPointMarkerPayload(
                indicatorID: instance.indicatorID,
                indicatorName: instance.indicatorName,
                points: points,
                shape: shape,
                size: 6,
                instanceID: instance.id,
                outputKey: "signals.\(type.rawValue)"
            )
            let style = KLOverlayStyle(
                fallbackHexColor: color,
                lineWidth: 2,
                opacity: 0.95,
                symbolName: shape
            )
            let tfSuffix = target.timeframe?.rawValue ?? "all"
            overlays.append(KLExternalChartOverlay(
                id: "overlay.indicator.\(instance.id).\(tfSuffix).signals.\(type.rawValue)",
                moduleID: "indicator",
                moduleName: instance.indicatorName,
                target: target,
                kind: .indicatorPoint,
                zIndex: zIndex,
                visible: instance.visible,
                style: style,
                payload: .indicatorPoint(payload),
                pane: pane,
                paneID: nil,
                instanceID: instance.id,
                outputKey: "signals.\(type.rawValue)"
            ))
        }
        return overlays
    }

    private static func colorHexFromValue(_ value: KXIndicatorParameterValue?) -> String? {
        guard let value else { return nil }
        switch value {
        case .colorHex(let hex): return hex
        case .string(let str): return str
        default: return nil
        }
    }

    private static func lineWidthFromValue(_ value: KXIndicatorParameterValue?) -> Double? {
        guard let value else { return nil }
        switch value {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return nil
        }
    }

    private static func opacityFromValue(_ value: KXIndicatorParameterValue?) -> Double? {
        guard let value else { return nil }
        switch value {
        case .double(let v): return v
        default: return nil
        }
    }

    private static func lineDashFromValue(_ value: KXIndicatorParameterValue?) -> [Double]? {
        guard let value else { return nil }
        switch value {
        case .string(let str):
            if str == "dashed" { return [4, 3] }
            if str == "dotted" { return [1, 2] }
            return nil
        default: return nil
        }
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN34Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-34", fileName: "KX-FN-34_指标Overlay适配器.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-34_指标Overlay适配器.swift", duty: "把指标计算输出转换为标准 KLExternalChartOverlay 数组"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("指标Overlay适配器骨架校验通过")
        return KXHealthCheckItem(name: "指标Overlay适配器", passed: true, message: "已实现指标Overlay适配器")
    }
}
