//
//  KX-MK-00_标记层入口.swift
//  仙人指路测试项目｜K线模块｜标记层
//
//  职责：标记层统一入口。K线图主渲染器只把 overlay 交给这里，具体标记功能由各 KX-MK-xx 文件负责。
//  边界：不计算指标、不识别形态、不读取数据库、不修改 viewport、不触发 refreshData。
//  扩展规则：新增一种标记显示能力时，新建一个 KX-MK-xx 文件；本入口只做轻量分发。
//

import AppKit
import Foundation

struct KXMKPatternHitResult {
    let payload: KLCandlePatternMarkerPayload
    let rect: CGRect
}

enum KXMK00MarkerLayerDispatcher {
    static func draw(
        overlay: KLExternalChartOverlay,
        ctx: CGContext,
        candles: [KLCandlePoint],
        viewport: KLViewportAdjustResult,
        bounds: CGRect,
        xForIndex: (Int) -> CGFloat,
        yForPrice: (Double) -> CGFloat,
        timeIndexMap: [Date: Int],
        avoidCandleRects: [CGRect],
        occupiedTagFrames: inout [CGRect]
    ) {
        guard overlay.visible else { return }
        switch overlay.payload {
        case .candlePatternMarker(let payload):
            KXMK01CandlePatternMarkerRenderer.draw(
                payload: payload,
                style: overlay.style,
                ctx: ctx,
                candles: candles,
                viewport: viewport,
                bounds: bounds,
                xForIndex: xForIndex,
                yForPrice: yForPrice,
                timeIndexMap: timeIndexMap,
                avoidCandleRects: avoidCandleRects,
                occupiedTagFrames: &occupiedTagFrames
            )
        case .indicatorLabel(let payload):
            KXMK02IndicatorLabelMarkerRenderer.draw(
                payload: payload,
                style: overlay.style,
                ctx: ctx,
                candles: candles,
                bounds: bounds,
                xForIndex: xForIndex,
                yForPrice: yForPrice,
                timeIndexMap: timeIndexMap
            )
        default:
            return
        }
    }

    static func hitTest(
        overlay: KLExternalChartOverlay,
        point: CGPoint,
        candles: [KLCandlePoint],
        viewport: KLViewportAdjustResult,
        bounds: CGRect,
        xForIndex: (Int) -> CGFloat,
        yForPrice: (Double) -> CGFloat,
        timeIndexMap: [Date: Int],
        avoidCandleRects: [CGRect],
        occupiedTagFrames: [CGRect]
    ) -> KXMKPatternHitResult? {
        guard overlay.visible else { return nil }
        switch overlay.payload {
        case .candlePatternMarker(let payload):
            return KXMK01CandlePatternMarkerRenderer.hitTest(
                payload: payload,
                point: point,
                candles: candles,
                viewport: viewport,
                bounds: bounds,
                xForIndex: xForIndex,
                yForPrice: yForPrice,
                timeIndexMap: timeIndexMap,
                avoidCandleRects: avoidCandleRects,
                occupiedTagFrames: occupiedTagFrames
            )
        default:
            return nil
        }
    }


    static func tagFrame(
        overlay: KLExternalChartOverlay,
        candles: [KLCandlePoint],
        viewport: KLViewportAdjustResult,
        bounds: CGRect,
        xForIndex: (Int) -> CGFloat,
        yForPrice: (Double) -> CGFloat,
        timeIndexMap: [Date: Int],
        avoidCandleRects: [CGRect],
        occupiedTagFrames: [CGRect]
    ) -> CGRect? {
        guard overlay.visible else { return nil }
        switch overlay.payload {
        case .candlePatternMarker(let payload):
            return KXMK01CandlePatternMarkerRenderer.tagFrame(
                payload: payload,
                candles: candles,
                viewport: viewport,
                bounds: bounds,
                xForIndex: xForIndex,
                yForPrice: yForPrice,
                timeIndexMap: timeIndexMap,
                avoidCandleRects: avoidCandleRects,
                occupiedTagFrames: occupiedTagFrames
            )
        default:
            return nil
        }
    }

}

public enum KXMK00Skeleton: KXFileSkeletonProtocol {
    public static let version = "1.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-MK-00", fileName: "KX-MK-00_标记层入口.swift", layer: .ui,
        relativePath: "标记层/KX-MK-00_标记层入口.swift", duty: "标记层统一分发入口"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("标记层入口骨架校验通过")
        return KXHealthCheckItem(name: "标记层入口", passed: true, message: "已实现标记层统一分发入口")
    }
}
