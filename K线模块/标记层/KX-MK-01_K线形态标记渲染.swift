//
//  KX-MK-01_K线形态标记渲染.swift
//  仙人指路测试项目｜K线模块｜标记层
//
//  职责：只渲染 K线形态标记（标签、垂直连接线、触发范围提示、文字颜色、避让布局）。
//  边界：不计算形态、不读取数据库、不修改 viewport、不触发 refreshData、不处理 K线拖动缩放。
//  接入：KX-UI-19 只负责分发 candlePatternMarker overlay 到本文件。
//

import AppKit
import Foundation

enum KXMK01CandlePatternMarkerRenderer {
    private enum MinimalPatternTagLayout { case microCapsule, pinBadge, railDot, underline, codeBox }

    private struct PatternTagPlacement {
        let rect: CGRect
        let isAbove: Bool
        let triggerHighY: CGFloat
        let triggerLowY: CGFloat
    }

    static func draw(
        payload: KLCandlePatternMarkerPayload,
        style: KLOverlayStyle,
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
        guard let idx = timeIndexMap[payload.anchorTime], candles.indices.contains(idx) else { return }
        KXMK01ColorContext.install(ctx) {
            let direction = normalizedDirection(payload.direction)
            let color = patternColor(direction: direction, style: style)
            let text = compactPatternName(payload.patternName)
            let code = compactPatternCode(payload.patternID, fallbackName: payload.patternName, confidence: payload.confidence)
            let layout = patternLayout(for: payload.patternID, candleCount: payload.candleTimes.count)
            let triggerRange = triggerIndexRange(payload, currentIndex: idx, timeIndexMap: timeIndexMap)
            let triggerMidX = (xForIndex(triggerRange.lowerBound) + xForIndex(triggerRange.upperBound)) / 2
            let triggerHighY = triggerRange.compactMap { candles.indices.contains($0) ? yForPrice(candles[$0].high.kxmkDouble) : nil }.max() ?? yForPrice(payload.anchorPrice?.kxmkDouble ?? candles[idx].high.kxmkDouble)
            let triggerLowY = triggerRange.compactMap { candles.indices.contains($0) ? yForPrice(candles[$0].low.kxmkDouble) : nil }.min() ?? yForPrice(payload.anchorPrice?.kxmkDouble ?? candles[idx].low.kxmkDouble)

            let tagText: String
            switch layout {
            case .microCapsule:
                tagText = "\(text)\(Int(payload.confidence * 100))"
            case .pinBadge:
                tagText = text
            case .railDot, .underline, .codeBox:
                tagText = code
            }

            let tagSize = estimatedTagSize(layout: layout, text: tagText)
            let placement = placePatternTag(
                centerX: triggerMidX,
                size: tagSize,
                triggerHighY: triggerHighY,
                triggerLowY: triggerLowY,
                bounds: bounds,
                avoidCandleRects: avoidCandleRects,
                occupied: occupiedTagFrames
            )
            occupiedTagFrames.append(placement.rect.insetBy(dx: -3, dy: -3))

            drawTriggerGuide(
                payload,
                currentIndex: idx,
                placement: placement,
                color: color,
                ctx: ctx,
                xForIndex: xForIndex,
                timeIndexMap: timeIndexMap
            )

            switch layout {
            case .microCapsule:
                drawMicroCapsule(text: tagText, x: placement.rect.midX, y: placement.rect.minY, color: color, bounds: bounds, ctx: ctx)
            case .pinBadge:
                drawPinBadge(text: tagText, x: placement.rect.midX, y: placement.rect.minY, isAbove: placement.isAbove, color: color, bounds: bounds, ctx: ctx)
            case .railDot:
                drawRailDot(text: tagText, x: placement.rect.minX + 4, y: placement.rect.midY, color: color, bounds: bounds, ctx: ctx)
            case .underline:
                drawUnderlineTag(text: tagText, x: placement.rect.midX, y: placement.rect.minY, color: color, bounds: bounds, ctx: ctx)
            case .codeBox:
                drawCodeBox(text: tagText, x: placement.rect.midX, y: placement.rect.minY, color: color, bounds: bounds, ctx: ctx)
            }
        }
    }


    static func hitTest(
        payload: KLCandlePatternMarkerPayload,
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
        guard let idx = timeIndexMap[payload.anchorTime], candles.indices.contains(idx) else { return nil }
        let text = compactPatternName(payload.patternName)
        let code = compactPatternCode(payload.patternID, fallbackName: payload.patternName, confidence: payload.confidence)
        let layout = patternLayout(for: payload.patternID, candleCount: payload.candleTimes.count)
        let triggerRange = triggerIndexRange(payload, currentIndex: idx, timeIndexMap: timeIndexMap)
        let triggerMidX = (xForIndex(triggerRange.lowerBound) + xForIndex(triggerRange.upperBound)) / 2
        let triggerHighY = triggerRange.compactMap { candles.indices.contains($0) ? yForPrice(candles[$0].high.kxmkDouble) : nil }.max() ?? yForPrice(payload.anchorPrice?.kxmkDouble ?? candles[idx].high.kxmkDouble)
        let triggerLowY = triggerRange.compactMap { candles.indices.contains($0) ? yForPrice(candles[$0].low.kxmkDouble) : nil }.min() ?? yForPrice(payload.anchorPrice?.kxmkDouble ?? candles[idx].low.kxmkDouble)

        let tagText: String
        switch layout {
        case .microCapsule:
            tagText = "\(text)\(Int(payload.confidence * 100))"
        case .pinBadge:
            tagText = text
        case .railDot, .underline, .codeBox:
            tagText = code
        }

        let tagSize = estimatedTagSize(layout: layout, text: tagText)
        let placement = placePatternTag(
            centerX: triggerMidX,
            size: tagSize,
            triggerHighY: triggerHighY,
            triggerLowY: triggerLowY,
            bounds: bounds,
            avoidCandleRects: avoidCandleRects,
            occupied: occupiedTagFrames
        )
        let hitRect = placement.rect.insetBy(dx: -5, dy: -5)
        guard hitRect.contains(point) else { return nil }
        return KXMKPatternHitResult(payload: payload, rect: placement.rect)
    }


    static func tagFrame(
        payload: KLCandlePatternMarkerPayload,
        candles: [KLCandlePoint],
        viewport: KLViewportAdjustResult,
        bounds: CGRect,
        xForIndex: (Int) -> CGFloat,
        yForPrice: (Double) -> CGFloat,
        timeIndexMap: [Date: Int],
        avoidCandleRects: [CGRect],
        occupiedTagFrames: [CGRect]
    ) -> CGRect? {
        guard let idx = timeIndexMap[payload.anchorTime], candles.indices.contains(idx) else { return nil }
        let text = compactPatternName(payload.patternName)
        let code = compactPatternCode(payload.patternID, fallbackName: payload.patternName, confidence: payload.confidence)
        let layout = patternLayout(for: payload.patternID, candleCount: payload.candleTimes.count)
        let triggerRange = triggerIndexRange(payload, currentIndex: idx, timeIndexMap: timeIndexMap)
        let triggerMidX = (xForIndex(triggerRange.lowerBound) + xForIndex(triggerRange.upperBound)) / 2
        let triggerHighY = triggerRange.compactMap { candles.indices.contains($0) ? yForPrice(candles[$0].high.kxmkDouble) : nil }.max() ?? yForPrice(payload.anchorPrice?.kxmkDouble ?? candles[idx].high.kxmkDouble)
        let triggerLowY = triggerRange.compactMap { candles.indices.contains($0) ? yForPrice(candles[$0].low.kxmkDouble) : nil }.min() ?? yForPrice(payload.anchorPrice?.kxmkDouble ?? candles[idx].low.kxmkDouble)
        let tagText: String
        switch layout {
        case .microCapsule:
            tagText = "\(text)\(Int(payload.confidence * 100))"
        case .pinBadge:
            tagText = text
        case .railDot, .underline, .codeBox:
            tagText = code
        }
        let tagSize = estimatedTagSize(layout: layout, text: tagText)
        return placePatternTag(
            centerX: triggerMidX,
            size: tagSize,
            triggerHighY: triggerHighY,
            triggerLowY: triggerLowY,
            bounds: bounds,
            avoidCandleRects: avoidCandleRects,
            occupied: occupiedTagFrames
        ).rect
    }

    private static func patternLayout(for patternID: String, candleCount: Int) -> MinimalPatternTagLayout {
        let id = normalizedPatternID(patternID)
        if candleCount >= 5 || id.contains("three-methods") { return .codeBox }
        if candleCount >= 3 || ["morning-star", "evening-star", "abandoned-baby", "three-black-crows", "three-white-soldiers"].contains(id) { return .pinBadge }
        if candleCount >= 2 || ["engulfing", "harami", "piercing-line", "dark-cloud-cover", "tweezer", "gap", "separating"].contains(where: { id.contains($0) }) { return .pinBadge }
        if ["doji", "spinning-top"].contains(where: { id.contains($0) }) { return .railDot }
        if ["long-lower-shadow", "long-upper-shadow", "marubozu"].contains(id) { return .underline }
        if ["hammer", "hanging-man", "dragonfly-doji", "gravestone-doji"].contains(id) { return .microCapsule }
        return .microCapsule
    }

    private static func triggerIndexRange(_ payload: KLCandlePatternMarkerPayload, currentIndex: Int, timeIndexMap: [Date: Int]) -> ClosedRange<Int> {
        let indices = payload.candleTimes.compactMap { timeIndexMap[$0] }.sorted()
        let startIndex = indices.first ?? max(0, currentIndex - max(payload.candleTimes.count - 1, 0))
        let endIndex = indices.last ?? currentIndex
        return min(startIndex, endIndex)...max(startIndex, endIndex)
    }

    private static func estimatedTagSize(layout: MinimalPatternTagLayout, text: String) -> CGSize {
        switch layout {
        case .microCapsule:
            let attrs = tagAttributes(size: 9.0, weight: .semibold)
            return CGSize(width: min(max(NSString(string: text).size(withAttributes: attrs).width + 18, 35), 62), height: 18)
        case .pinBadge:
            return CGSize(width: 25, height: 22)
        case .railDot:
            let attrs = tagAttributes(size: 8.5, weight: .semibold)
            return CGSize(width: min(max(NSString(string: text).size(withAttributes: attrs).width + 18, 34), 54), height: 18)
        case .underline:
            let attrs = tagAttributes(size: 9.0, weight: .semibold)
            return CGSize(width: min(max(NSString(string: text).size(withAttributes: attrs).width + 8, 32), 56), height: 18)
        case .codeBox:
            let attrs = tagAttributes(size: 8.8, weight: .bold)
            return CGSize(width: min(max(NSString(string: text).size(withAttributes: attrs).width + 12, 30), 48), height: 17)
        }
    }

    private static func placePatternTag(centerX: CGFloat, size: CGSize, triggerHighY: CGFloat, triggerLowY: CGFloat, bounds: CGRect, avoidCandleRects: [CGRect], occupied: [CGRect]) -> PatternTagPlacement {
        func clampedX(_ cx: CGFloat) -> CGFloat { min(max(2, cx - size.width / 2), max(2, bounds.width - size.width - 2)) }
        func overlapsTags(_ rect: CGRect) -> Bool { occupied.contains { $0.intersects(rect.insetBy(dx: -3, dy: -3)) } }
        func overlapsCandles(_ rect: CGRect) -> Bool {
            let expanded = rect.insetBy(dx: -2, dy: -2)
            return avoidCandleRects.contains { $0.intersects(expanded) }
        }
        func valid(_ rect: CGRect, above: Bool) -> Bool {
            guard rect.minX >= 0, rect.maxX <= bounds.width, rect.minY >= 2, rect.maxY <= bounds.height - 2 else { return false }
            if above, rect.minY < triggerHighY + 12 { return false }
            if !above, rect.maxY > triggerLowY - 12 { return false }
            return !overlapsCandles(rect) && !overlapsTags(rect)
        }

        // 标签归属必须清楚：属于哪根K线，就只能在这根K线正上方或正下方；连接线只能垂直。
        let verticalOffsets: [CGFloat] = [0, 10, 20, 32, 46, 62, 80, 102, 126, 154, 186]
        let aboveHasRoom = triggerHighY + 12 + size.height <= bounds.height - 2
        let belowHasRoom = triggerLowY - 12 - size.height >= 2
        let orders: [Bool] = aboveHasRoom ? [true, false] : [false, true]
        for above in orders {
            if above && !aboveHasRoom { continue }
            if !above && !belowHasRoom { continue }
            for dy in verticalOffsets {
                let x = clampedX(centerX)
                let y = above ? (triggerHighY + 12 + dy) : (triggerLowY - 12 - size.height - dy)
                let rect = CGRect(x: x, y: y, width: size.width, height: size.height)
                if valid(rect, above: above) {
                    return PatternTagPlacement(rect: rect, isAbove: above, triggerHighY: triggerHighY, triggerLowY: triggerLowY)
                }
            }
        }

        let fallbackYsAbove = stride(from: bounds.height - size.height - 2, through: max(2, triggerHighY + 12), by: -10).map { CGFloat($0) }
        let fallbackYsBelow = stride(from: max(2, triggerLowY - 12 - size.height), through: 2, by: -10).map { CGFloat($0) }
        for above in orders {
            let ys = above ? fallbackYsAbove : fallbackYsBelow
            for y in ys {
                let rect = CGRect(x: clampedX(centerX), y: y, width: size.width, height: size.height)
                if !overlapsCandles(rect) && !overlapsTags(rect) {
                    return PatternTagPlacement(rect: rect, isAbove: above, triggerHighY: triggerHighY, triggerLowY: triggerLowY)
                }
            }
        }

        if aboveHasRoom {
            let rect = CGRect(x: clampedX(centerX), y: min(bounds.height - size.height - 2, triggerHighY + 12), width: size.width, height: size.height)
            return PatternTagPlacement(rect: rect, isAbove: true, triggerHighY: triggerHighY, triggerLowY: triggerLowY)
        }
        let rect = CGRect(x: clampedX(centerX), y: max(2, triggerLowY - 12 - size.height), width: size.width, height: size.height)
        return PatternTagPlacement(rect: rect, isAbove: false, triggerHighY: triggerHighY, triggerLowY: triggerLowY)
    }

    private static func drawTriggerGuide(_ payload: KLCandlePatternMarkerPayload, currentIndex: Int, placement: PatternTagPlacement, color: NSColor, ctx: CGContext, xForIndex: (Int) -> CGFloat, timeIndexMap: [Date: Int]) {
        let range = triggerIndexRange(payload, currentIndex: currentIndex, timeIndexMap: timeIndexMap)
        let startX = xForIndex(range.lowerBound)
        let endX = xForIndex(range.upperBound)
        let midX = (startX + endX) / 2
        let count = max(payload.candleTimes.count, range.upperBound - range.lowerBound + 1)
        let anchorY = placement.isAbove ? placement.triggerHighY : placement.triggerLowY
        let labelEdgeY = placement.isAbove ? placement.rect.minY : placement.rect.maxY

        ctx.setStrokeColor(color.withAlphaComponent(0.62).cgColor)
        ctx.setFillColor(color.withAlphaComponent(0.70).cgColor)
        ctx.setLineWidth(1.35)
        ctx.setLineDash(phase: 0, lengths: [3, 3])
        let linkX = midX
        ctx.move(to: CGPoint(x: linkX, y: anchorY))
        ctx.addLine(to: CGPoint(x: linkX, y: labelEdgeY))
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.fillEllipse(in: CGRect(x: linkX - 1.9, y: anchorY - 1.9, width: 3.8, height: 3.8))

        ctx.setStrokeColor(color.withAlphaComponent(0.74).cgColor)
        ctx.setLineWidth(1.0)
        if count <= 1 {
            return
        } else if count <= 3 {
            let bracketY = placement.isAbove ? (placement.triggerHighY + 4) : (placement.triggerLowY - 4)
            let tick: CGFloat = placement.isAbove ? -8 : 8
            ctx.move(to: CGPoint(x: startX, y: bracketY + tick))
            ctx.addLine(to: CGPoint(x: startX, y: bracketY))
            ctx.addLine(to: CGPoint(x: endX, y: bracketY))
            ctx.addLine(to: CGPoint(x: endX, y: bracketY + tick))
            ctx.strokePath()
        } else {
            let railY = placement.isAbove ? (placement.triggerHighY + 4) : (placement.triggerLowY - 7)
            let rect = CGRect(x: min(startX, endX), y: railY, width: max(abs(endX - startX), 6), height: 3)
            ctx.setFillColor(color.withAlphaComponent(0.32).cgColor)
            ctx.fill(rect)
        }
    }

    private static func drawMicroCapsule(text: String, x: CGFloat, y: CGFloat, color: NSColor, bounds: CGRect, ctx: CGContext) {
        let fillAlpha: CGFloat = KLUITheme.isDark ? 0.32 : 0.18
        let foreground = readableTextColor(on: color, fillAlpha: fillAlpha)
        let attrs = tagAttributes(size: 9.0, weight: .semibold, foreground: foreground)
        let w = min(max(NSString(string: text).size(withAttributes: attrs).width + 18, 35), 62)
        let rect = clampedRect(centerX: x, y: y, width: w, height: 18, bounds: bounds)
        fillRounded(rect, radius: 5, fill: color.withAlphaComponent(fillAlpha), stroke: color.withAlphaComponent(KLUITheme.isDark ? 0.96 : 0.88), lineWidth: 1.0)
        KXMK01ColorContext.withSavedContext(ctx) {
            color.setFill()
            NSBezierPath(ovalIn: CGRect(x: rect.minX + 5, y: rect.midY - 3.2, width: 6.4, height: 6.4)).fill()
            NSString(string: text).draw(at: CGPoint(x: rect.minX + 14, y: rect.minY + 3.0), withAttributes: attrs)
        }
    }

    private static func drawPinBadge(text: String, x: CGFloat, y: CGFloat, isAbove: Bool, color: NSColor, bounds: CGRect, ctx: CGContext) {
        let attrs = tagAttributes(size: 9.0, weight: .bold, foreground: readableTextColor(on: color, fillAlpha: 0.94))
        let rect = clampedRect(centerX: x, y: y, width: 25, height: 17, bounds: bounds)
        fillRounded(rect, radius: 5, fill: color.withAlphaComponent(0.94), stroke: color.withAlphaComponent(0.94), lineWidth: 0.8)
        let tri = NSBezierPath()
        if isAbove {
            // 标签在K线上方：小尖尖朝下，从标签底部向下指向K线
            tri.move(to: CGPoint(x: rect.midX - 4, y: rect.minY + 0.2))
            tri.line(to: CGPoint(x: rect.midX + 4, y: rect.minY + 0.2))
            tri.line(to: CGPoint(x: rect.midX, y: rect.minY - 5))
        } else {
            // 标签在K线下方：小尖尖朝上，从标签顶部向上指向K线
            tri.move(to: CGPoint(x: rect.midX - 4, y: rect.maxY - 0.2))
            tri.line(to: CGPoint(x: rect.midX + 4, y: rect.maxY - 0.2))
            tri.line(to: CGPoint(x: rect.midX, y: rect.maxY + 5))
        }
        tri.close()
        KXMK01ColorContext.withSavedContext(ctx) { color.withAlphaComponent(0.94).setFill(); tri.fill() }
        let t = String(text.prefix(2))
        let size = NSString(string: t).size(withAttributes: attrs)
        KXMK01ColorContext.withSavedContext(ctx) {
            NSString(string: t).draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.minY + 2), withAttributes: attrs)
        }
    }

    private static func drawRailDot(text: String, x: CGFloat, y: CGFloat, color: NSColor, bounds: CGRect, ctx: CGContext) {
        KXMK01ColorContext.withSavedContext(ctx) {
            color.withAlphaComponent(0.95).setFill()
            NSBezierPath(ovalIn: CGRect(x: x - 4.5, y: y - 4.5, width: 9, height: 9)).fill()
            let attrs = tagAttributes(size: 8.5, weight: .semibold, foreground: color)
            NSString(string: text).draw(at: CGPoint(x: min(bounds.width - 42, x + 7), y: y - 6), withAttributes: attrs)
        }
    }

    private static func drawUnderlineTag(text: String, x: CGFloat, y: CGFloat, color: NSColor, bounds: CGRect, ctx: CGContext) {
        let attrs = tagAttributes(size: 9.0, weight: .semibold, foreground: color)
        let size = NSString(string: text).size(withAttributes: attrs)
        let drawX = min(max(2, x - size.width / 2), max(2, bounds.width - size.width - 2))
        KXMK01ColorContext.withSavedContext(ctx) {
            NSString(string: text).draw(at: CGPoint(x: drawX, y: y), withAttributes: attrs)
        }
        ctx.setStrokeColor(color.withAlphaComponent(0.9).cgColor)
        ctx.setLineWidth(2.0)
        ctx.move(to: CGPoint(x: drawX, y: y + size.height + 1))
        ctx.addLine(to: CGPoint(x: drawX + size.width, y: y + size.height + 1))
        ctx.strokePath()
    }

    private static func drawCodeBox(text: String, x: CGFloat, y: CGFloat, color: NSColor, bounds: CGRect, ctx: CGContext) {
        let foreground = themeLabelTextColor()
        let attrs = tagAttributes(size: 8.8, weight: .bold, foreground: foreground)
        let w = min(max(NSString(string: text).size(withAttributes: attrs).width + 12, 30), 48)
        let rect = clampedRect(centerX: x, y: y, width: w, height: 17, bounds: bounds)
        let fill = KLUITheme.isDark ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.055)
        fillRounded(rect, radius: 3, fill: fill, stroke: color.withAlphaComponent(KLUITheme.isDark ? 0.98 : 0.86), lineWidth: 1.2)
        let size = NSString(string: text).size(withAttributes: attrs)
        KXMK01ColorContext.withSavedContext(ctx) {
            NSString(string: text).draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.minY + 2), withAttributes: attrs)
        }
    }

    private static func clampedRect(centerX: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, bounds: CGRect) -> CGRect {
        let x = min(max(2, centerX - width / 2), max(2, bounds.width - width - 2))
        return CGRect(x: x, y: min(max(2, y), max(2, bounds.height - height - 2)), width: width, height: height)
    }

    private static func fillRounded(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor, lineWidth: CGFloat) {
        KXMK01ColorContext.withCurrentContext { ctx in
            let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            ctx.setFillColor(fill.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
            ctx.setStrokeColor(stroke.cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.addPath(path)
            ctx.strokePath()
        }
    }

    private static func readableTextColor(on color: NSColor, fillAlpha: CGFloat) -> NSColor {
        let c = color.usingColorSpace(.deviceRGB) ?? color
        let bg = KLUITheme.chartBackground.usingColorSpace(.deviceRGB) ?? KLUITheme.chartBackground
        let bgR = c.redComponent * fillAlpha + bg.redComponent * (1.0 - fillAlpha)
        let bgG = c.greenComponent * fillAlpha + bg.greenComponent * (1.0 - fillAlpha)
        let bgB = c.blueComponent * fillAlpha + bg.blueComponent * (1.0 - fillAlpha)
        let luminance = 0.2126 * bgR + 0.7152 * bgG + 0.0722 * bgB
        if luminance > 0.56 { return NSColor.black.withAlphaComponent(0.88) }
        return NSColor.white.withAlphaComponent(0.96)
    }

    private static func themeLabelTextColor() -> NSColor {
        KLUITheme.isDark ? NSColor.white.withAlphaComponent(0.94) : NSColor.black.withAlphaComponent(0.86)
    }

    private static func tagAttributes(size: CGFloat, weight: NSFont.Weight, foreground: NSColor? = nil) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: foreground ?? themeLabelTextColor()]
    }

    private static func patternColor(direction: String, style: KLOverlayStyle) -> NSColor {
        // K线形态标签颜色以信号方向为最高优先级：看涨绿、看跌红、中性黄、延续蓝。
        // 上游 overlay style 只能作为 unknown 兜底，不能覆盖 bearish/bullish 语义，避免看跌标签被统一画成绿色。
        switch direction {
        case "bearish": return colorFromHex("#EF4444") ?? .systemRed
        case "bullish": return colorFromHex("#22C55E") ?? .systemGreen
        case "neutral", "reversal": return colorFromHex("#F59E0B") ?? .systemYellow
        case "continuation": return colorFromHex("#38BDF8") ?? .systemBlue
        default:
            if let hex = style.fallbackHexColor, let color = colorFromHex(hex) { return color }
            return colorFromHex("#F59E0B") ?? .systemYellow
        }
    }

    private static func normalizedDirection(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("bear") || text.contains("跌") || text.contains("空") { return "bearish" }
        if lower.contains("bull") || text.contains("涨") || text.contains("多") { return "bullish" }
        if lower.contains("neutral") || text.contains("中性") { return "neutral" }
        if lower.contains("continuation") || text.contains("延续") { return "continuation" }
        if lower.contains("reversal") || text.contains("反转") { return "reversal" }
        return "unknown"
    }

    private static func normalizedPatternID(_ patternID: String) -> String {
        if patternID.hasPrefix("KP:") {
            let parts = patternID.split(separator: ":").map(String.init)
            if parts.count >= 5 { return parts[3] }
        }
        return patternID
    }

    private static func compactPatternCode(_ patternID: String, fallbackName: String, confidence: Double) -> String {
        let id = normalizedPatternID(patternID)
        let pct = Int(confidence * 100)
        let prefix: String
        switch id {
        case "hammer": prefix = "H"
        case "hanging-man": prefix = "HM"
        case "doji": prefix = "D"
        case "long-legged-doji": prefix = "LD"
        case "gravestone-doji": prefix = "GD"
        case "dragonfly-doji": prefix = "DD"
        case "marubozu": prefix = "M"
        case "spinning-top": prefix = "ST"
        case "long-lower-shadow": prefix = "LLS"
        case "long-upper-shadow": prefix = "LUS"
        case "bullish-engulfing", "bearish-engulfing": prefix = "E"
        case "piercing-line": prefix = "PL"
        case "dark-cloud-cover": prefix = "DC"
        case "bullish-harami", "bearish-harami", "harami-cross": prefix = "HA"
        case "tweezer-top", "tweezer-bottom": prefix = "TW"
        case "gap": prefix = "G"
        case "morning-star", "evening-star": prefix = "S"
        case "three-black-crows": prefix = "3C"
        case "three-white-soldiers": prefix = "3S"
        case "rising-three-methods", "falling-three-methods": prefix = "3M"
        default: prefix = String(compactPatternName(fallbackName).prefix(2))
        }
        return "\(prefix)\(pct)"
    }

    private static func compactPatternName(_ name: String) -> String {
        switch name {
        case "锤子线": return "锤"
        case "上吊线": return "吊"
        case "十字星": return "十"
        case "长腿十字星": return "长十"
        case "墓碑十字星": return "墓"
        case "蜻蜓十字星": return "蜓"
        case "光头光脚线": return "光脚"
        case "纺锤线": return "纺"
        case "长下影线": return "下影"
        case "长上影线": return "上影"
        case "看涨吞没": return "吞涨"
        case "看跌吞没": return "吞跌"
        case "刺透线": return "刺"
        case "乌云盖顶": return "乌云"
        case "看涨孕线": return "孕涨"
        case "看跌孕线": return "孕跌"
        case "孕线十字": return "孕十"
        case "平头顶部": return "平顶"
        case "平头底部": return "平底"
        case "缺口": return "缺"
        case "看涨分离线": return "分涨"
        case "看跌分离线": return "分跌"
        case "启明星": return "启明"
        case "黄昏星": return "黄昏"
        case "弃婴形态": return "弃婴"
        case "三只乌鸦": return "三鸦"
        case "三白兵": return "三兵"
        case "上升三法": return "升三"
        case "下降三法": return "降三"
        default:
            return String(name.prefix(2))
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

private enum KXMK01ColorContext {
    private static var currentCGContext: CGContext?

    static func install(_ cgContext: CGContext, _ block: () -> Void) {
        let previous = currentCGContext
        currentCGContext = cgContext
        block()
        currentCGContext = previous
    }

    static func withCurrentContext(_ block: (CGContext) -> Void) {
        if let ctx = currentCGContext { block(ctx) }
    }

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
    var kxmkDouble: Double { NSDecimalNumber(decimal: self).doubleValue }
}

public enum KXMK01Skeleton: KXFileSkeletonProtocol {
    public static let version = "1.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-MK-01", fileName: "KX-MK-01_K线形态标记渲染.swift", layer: .ui,
        relativePath: "标记层/KX-MK-01_K线形态标记渲染.swift", duty: "独立渲染K线形态标记标签、连接线与避让布局"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("K线形态标记渲染骨架校验通过")
        return KXHealthCheckItem(name: "K线形态标记渲染", passed: true, message: "已实现K线形态标记渲染")
    }
}
