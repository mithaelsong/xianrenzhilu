//
//  KX-MK-02_指标标签标记渲染.swift
//  仙人指路测试项目｜K线模块｜标记层
//
//  职责：只渲染 indicatorLabel overlay 的文字标签。
//  边界：不计算指标、不生成标签内容、不读取数据库、不修改 viewport、不触发 refreshData。
//

import AppKit
import Foundation

enum KXMK02IndicatorLabelMarkerRenderer {
    static func draw(
        payload: KLIndicatorLabelPayload,
        style: KLOverlayStyle,
        ctx: CGContext,
        candles: [KLCandlePoint],
        bounds: CGRect,
        xForIndex: (Int) -> CGFloat,
        yForPrice: (Double) -> CGFloat,
        timeIndexMap: [Date: Int]
    ) {
        // 浅/深主题下不能使用 NSColor.labelColor 动态色转 CGColor 作为兜底，
        // 否则标记层在 CALayer 绘制时可能不会跟随主题正确解析。
        let color = style.fallbackHexColor.flatMap { colorFromHex($0) } ?? KLUITheme.axisText
        let alpha = CGFloat(style.opacity ?? 1.0)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: color.withAlphaComponent(alpha)
        ]

        for label in payload.labels {
            guard let idx = timeIndexMap[label.time] else { continue }
            let x = xForIndex(idx)
            let y: CGFloat
            if let price = label.price {
                y = yForPrice(price.kxmk2Double)
            } else if label.placement == "aboveCandle", candles.indices.contains(idx) {
                y = yForPrice(candles[idx].high.kxmk2Double) - 12
            } else if label.placement == "belowCandle", candles.indices.contains(idx) {
                y = yForPrice(candles[idx].low.kxmk2Double) + 12
            } else {
                y = bounds.midY
            }
            let nsStr = NSString(string: label.text)
            let size = nsStr.size(withAttributes: attrs)
            KXMK02ColorContext.withSavedContext(ctx) {
                nsStr.draw(at: CGPoint(x: x - size.width / 2, y: y), withAttributes: attrs)
            }
        }
    }

    private static func colorFromHex(_ hex: String) -> NSColor? {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch trimmed.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

private enum KXMK02ColorContext {
    static func withSavedContext(_ cgContext: CGContext, _ block: () -> Void) {
        let old = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        block()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.current = old
    }
}

private extension Decimal {
    var kxmk2Double: Double { NSDecimalNumber(decimal: self).doubleValue }
}

public enum KXMK02Skeleton: KXFileSkeletonProtocol {
    public static let version = "1.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-MK-02", fileName: "KX-MK-02_指标标签标记渲染.swift", layer: .ui,
        relativePath: "标记层/KX-MK-02_指标标签标记渲染.swift", duty: "独立渲染指标/模块输出文字标签"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("指标标签标记渲染骨架校验通过")
        return KXHealthCheckItem(name: "指标标签标记渲染", passed: true, message: "已实现指标标签标记渲染")
    }
}
