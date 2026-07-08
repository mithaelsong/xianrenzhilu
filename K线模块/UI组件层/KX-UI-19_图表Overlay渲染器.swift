//
//  KX-UI-19_图表Overlay渲染器.swift
//  仙人指路测试项目｜K线模块
//
//  版本：2.0
//  职责：消费 KLExternalChartOverlay 并渲染 line/bar/band/point/label/range/horizontalLine
//  禁止事项：禁止直接计算指标、禁止维护指标业务状态、禁止修改 candleLayer/volumeLayer frame
//

import AppKit
import Foundation
import os.log

// 使用 klineLogger 以便日志写入 KLineModule.log 文件
private let logger = klineLogger

public final class KXUI19ChartOverlayRendererLayer: CALayer {
    public var candles: [KLCandlePoint] = []
    public var viewport = KLViewportAdjustResult()
    public var overlays: [KLExternalChartOverlay] = []
    public var pane: KLOverlayPane = .main
    public var theme = KLChartThemeBundle()
    
    // 缓存：避免每帧 draw 重复计算 Decimal→Double 和 timeIndexMap
    private var lastDrawSignature: String = ""
    private var cachedTimeIndexMap: [Date: Int] = [:]
    private var cachedCandleDoubles: [(high: Double, low: Double, open: Double, close: Double)] = []
    // 水平参考线标签层（CATextLayer 更可靠）
    private var horizontalLineTextLayers: [String: CATextLayer] = [:]

    public func apply(overlays: [KLExternalChartOverlay]) {
        self.overlays = overlays
        logger.info("[DIAG][KX-UI-19] apply called pane=\(String(describing: self.pane)) overlays=\(overlays.count)")
        // 清理旧的水平参考线标签层
        for (_, layer) in horizontalLineTextLayers {
            layer.removeFromSuperlayer()
        }
        horizontalLineTextLayers.removeAll()
        // 为新的 horizontalLine overlay 创建 CATextLayer
        for overlay in overlays {
            if case .horizontalLine(let payload) = overlay.payload,
               let label = payload.label, !label.isEmpty {
                let textLayer = CATextLayer()
                textLayer.string = label
                textLayer.fontSize = 10
                textLayer.foregroundColor = NSColor.labelColor.cgColor
                textLayer.alignmentMode = .right
                textLayer.contentsScale = self.contentsScale
                textLayer.isHidden = true
                self.addSublayer(textLayer)
                horizontalLineTextLayers[overlay.id] = textLayer
            }
        }
        setNeedsDisplay()
    }

    public override func draw(in ctx: CGContext) {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 1 { logger.info("[PERF][KX-UI-19] draw total ms=\(dt) overlays=\(self.overlays.count) candles=\(self.candles.count)") }
        }
        // 诊断日志：每次 draw 都记录 pane 和 overlay 数量
        logger.info("[DIAG][KX-UI-19] draw called pane=\(String(describing: self.pane)) overlays=\(self.overlays.count) bounds=\(String(describing: self.bounds))")
        guard !candles.isEmpty, bounds.width > 8, bounds.height > 8 else { return }

        let candleWidth = max(CGFloat(viewport.candleWidth), 1.5)
        let startIdx = max(0, min(viewport.startIndex, max(0, candles.count - 1)))
        let visibleCount = max(1, Int(bounds.width / candleWidth) + 2)
        let endIdx = min(candles.count, startIdx + visibleCount)
        guard startIdx < endIdx else { return }
        
        // 诊断日志：记录副图中 horizontalLine 的 label 情况
        if pane == .sub {
            let hLines = overlays.filter { if case .horizontalLine = $0.payload { return true } else { return false } }
            if !hLines.isEmpty {
                let labels = hLines.compactMap { ov -> String? in
                    if case .horizontalLine(let p) = ov.payload { return p.label }
                    return nil
                }
                logger.info("[DIAG][KX-UI-19] sub pane draw horizontalLines=\(hLines.count) labels=\(labels)")
            }
        }
        
        // 缓存签名：candles 数量 + 视口参数 + 最后一根 close，避免每帧重复计算
        let currentSignature = "\(candles.count)|\(startIdx)|\(visibleCount)|\(Int(candleWidth*100))|\(candles.last?.close.description ?? "nil")"
        let timeIndexMap: [Date: Int]
        let candleDoubles: [(high: Double, low: Double, open: Double, close: Double)]
        if currentSignature == lastDrawSignature {
            timeIndexMap = cachedTimeIndexMap
            candleDoubles = cachedCandleDoubles
        } else {
            let visibleCandles = Array(candles[startIdx..<endIdx])
            timeIndexMap = Dictionary(uniqueKeysWithValues: visibleCandles.enumerated().map { (idx, c) in (c.openTime, startIdx + idx) })
            candleDoubles = visibleCandles.map { (high: $0.high.dbl, low: $0.low.dbl, open: $0.open.dbl, close: $0.close.dbl) }
            cachedTimeIndexMap = timeIndexMap
            cachedCandleDoubles = candleDoubles
            lastDrawSignature = currentSignature
        }
        
        func xForIndex(_ index: Int) -> CGFloat {
            CGFloat(index - startIdx) * candleWidth + candleWidth / 2
        }
        
        // 主图用价格范围；副图用 overlay 数据值范围（包含水平参考线）
        let (minValue, maxValue): (Double, Double)
        if pane == .main {
            minValue = candleDoubles.map { $0.low }.min() ?? 0
            maxValue = candleDoubles.map { $0.high }.max() ?? 1
        } else {
            var values: [Double] = []
            for overlay in overlays where overlay.visible {
                switch overlay.payload {
                case .indicatorLine(let p): values.append(contentsOf: p.series.map { $0.value.dbl })
                case .indicatorBand(let p):
                    values.append(contentsOf: p.upperLine.map { $0.value.dbl })
                    values.append(contentsOf: p.lowerLine.map { $0.value.dbl })
                    values.append(contentsOf: (p.middleLine ?? []).map { $0.value.dbl })
                case .indicatorHistogram(let p): values.append(contentsOf: p.series.map { $0.value.dbl })
                case .indicatorPoint(let p): values.append(contentsOf: p.points.map { $0.value.dbl })
                case .horizontalLine(let p): values.append(p.value.dbl)
                case .range(let p):
                    values.append(p.upper.dbl)
                    values.append(p.lower.dbl)
                default: break
                }
            }
            // 副图始终包含 0 基线（MACD/成交量风格）
            values.append(0)
            minValue = values.min() ?? 0
            maxValue = values.max() ?? 1
        }
        let valueRange = max(maxValue - minValue, 0.00000001)
        
        func yForValue(_ value: Double) -> CGFloat {
            let plotH = max(bounds.height - 16, 1)
            let top: CGFloat = 8
            return top + plotH * CGFloat((value - minValue) / valueRange)
        }
        
        let avoidCandleRects: [CGRect] = (startIdx..<endIdx).enumerated().compactMap { (offset, candleIndex) in
            guard candles.indices.contains(candleIndex) else { return nil }
            let cd = candleDoubles[offset]
            let x = xForIndex(candleIndex)
            let highY = yForValue(cd.high)
            let lowY = yForValue(cd.low)
            let bodyTop = max(yForValue(cd.open), yForValue(cd.close))
            let bodyBottom = min(yForValue(cd.open), yForValue(cd.close))
            let y0 = min(lowY, bodyBottom)
            let y1 = max(highY, bodyTop)
            let width = max(CGFloat(viewport.candleWidth) * 0.86, 8)
            return CGRect(x: x - width / 2, y: y0 - 4, width: width, height: (y1 - y0) + 8)
        }

        // 更新水平参考线 CATextLayer 位置
        for overlay in overlays where overlay.visible {
            if case .horizontalLine(let payload) = overlay.payload,
               let label = payload.label, !label.isEmpty,
               let textLayer = horizontalLineTextLayers[overlay.id] {
                let y = yForValue(payload.value.dbl)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: NSColor.black
                ]
                let attrText = NSAttributedString(string: label, attributes: attrs)
                let textSize = attrText.size()
                let textX: CGFloat = 4
                let textY = y - textSize.height / 2
                textLayer.frame = CGRect(x: textX, y: textY, width: textSize.width, height: textSize.height)
                textLayer.alignmentMode = .left
                textLayer.isHidden = false
            }
        }

        var patternTagFrames: [CGRect] = []
        for overlay in overlays.sorted(by: { $0.zIndex < $1.zIndex }) where overlay.visible {
            switch overlay.payload {
            case .indicatorLine(let p):
                drawLine(p, style: overlay.style, ctx: ctx, xForIndex: xForIndex, yForPrice: yForValue, timeIndexMap: timeIndexMap)
            case .indicatorBand(let p):
                drawBand(p, style: overlay.style, ctx: ctx, xForIndex: xForIndex, yForPrice: yForValue, timeIndexMap: timeIndexMap)
            case .indicatorHistogram(let p):
                drawHistogram(p, style: overlay.style, ctx: ctx, xForIndex: xForIndex, yForPrice: yForValue, timeIndexMap: timeIndexMap, minPrice: minValue, maxPrice: maxValue)
            case .horizontalLine(let p):
                drawHorizontalLine(p, style: overlay.style, ctx: ctx, yForPrice: yForValue)
            case .indicatorPoint(let p):
                drawPoints(p, style: overlay.style, ctx: ctx, xForIndex: xForIndex, yForPrice: yForValue, timeIndexMap: timeIndexMap)
            case .indicatorLabel:
                KXMK00MarkerLayerDispatcher.draw(
                    overlay: overlay,
                    ctx: ctx,
                    candles: candles,
                    viewport: viewport,
                    bounds: bounds,
                    xForIndex: xForIndex,
                    yForPrice: yForValue,
                    timeIndexMap: timeIndexMap,
                    avoidCandleRects: avoidCandleRects,
                    occupiedTagFrames: &patternTagFrames
                )
            case .range(let p):
                drawRange(p, style: overlay.style, ctx: ctx, xForIndex: xForIndex, yForPrice: yForValue, timeIndexMap: timeIndexMap)
            case .candlePatternMarker:
                KXMK00MarkerLayerDispatcher.draw(
                    overlay: overlay,
                    ctx: ctx,
                    candles: candles,
                    viewport: viewport,
                    bounds: bounds,
                    xForIndex: xForIndex,
                    yForPrice: yForValue,
                    timeIndexMap: timeIndexMap,
                    avoidCandleRects: avoidCandleRects,
                    occupiedTagFrames: &patternTagFrames
                )
            default:
                break
            }
        }
    }


    public func hitTestCandlePattern(at point: CGPoint) -> KLCandlePatternMarkerPayload? {
        guard !candles.isEmpty, bounds.width > 8, bounds.height > 8 else { return nil }

        let candleWidth = max(CGFloat(viewport.candleWidth), 1.5)
        let startIdx = max(0, min(viewport.startIndex, max(0, candles.count - 1)))
        let visibleCount = max(1, Int(bounds.width / candleWidth) + 2)
        let endIdx = min(candles.count, startIdx + visibleCount)
        guard startIdx < endIdx else { return nil }

        let visibleCandles = Array(candles[startIdx..<endIdx])
        let minPrice = visibleCandles.map { $0.low.dbl }.min() ?? 0
        let maxPrice = visibleCandles.map { $0.high.dbl }.max() ?? 1
        let priceRange = max(maxPrice - minPrice, 0.00000001)
        let timeIndexMap = Dictionary(uniqueKeysWithValues: visibleCandles.enumerated().map { (idx, c) in (c.openTime, startIdx + idx) })

        func xForIndex(_ index: Int) -> CGFloat {
            CGFloat(index - startIdx) * candleWidth + candleWidth / 2
        }
        func yForPrice(_ value: Double) -> CGFloat {
            let plotH = max(bounds.height - 16, 1)
            let top: CGFloat = 8
            return top + plotH * CGFloat((value - minPrice) / priceRange)
        }

        let avoidCandleRects: [CGRect] = (startIdx..<endIdx).compactMap { candleIndex in
            guard candles.indices.contains(candleIndex) else { return nil }
            let candle = candles[candleIndex]
            let x = xForIndex(candleIndex)
            let highY = yForPrice(candle.high.dbl)
            let lowY = yForPrice(candle.low.dbl)
            let bodyTop = max(yForPrice(candle.open.dbl), yForPrice(candle.close.dbl))
            let bodyBottom = min(yForPrice(candle.open.dbl), yForPrice(candle.close.dbl))
            let y0 = min(lowY, bodyBottom)
            let y1 = max(highY, bodyTop)
            let width = max(CGFloat(viewport.candleWidth) * 0.86, 8)
            return CGRect(x: x - width / 2, y: y0 - 4, width: width, height: (y1 - y0) + 8)
        }

        var occupied: [CGRect] = []
        for overlay in overlays.sorted(by: { $0.zIndex < $1.zIndex }) where overlay.visible {
            guard case .candlePatternMarker(let payload) = overlay.payload else { continue }
            guard let frame = KXMK00MarkerLayerDispatcher.tagFrame(
                overlay: overlay,
                candles: candles,
                viewport: viewport,
                bounds: bounds,
                xForIndex: xForIndex,
                yForPrice: yForPrice,
                timeIndexMap: timeIndexMap,
                avoidCandleRects: avoidCandleRects,
                occupiedTagFrames: occupied
            ) else { continue }
            if frame.insetBy(dx: -5, dy: -5).contains(point) { return payload }
            occupied.append(frame.insetBy(dx: -3, dy: -3))
        }
        return nil
    }

    private func drawLine(_ payload: KLIndicatorLinePayload, style: KLOverlayStyle, ctx: CGContext, xForIndex: (Int) -> CGFloat, yForPrice: (Double) -> CGFloat, timeIndexMap: [Date: Int]) {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 0.5 { logger.info("[PERF][KX-UI-19] drawLine ms=\(dt) points=\(payload.series.count)") }
        }
        guard payload.series.count >= 2 else { return }
        let color = style.fallbackHexColor.flatMap { NSColor(hex: $0) } ?? NSColor.systemCyan
        let lineWidth = CGFloat(style.lineWidth ?? 1.0)
        let alpha = CGFloat(style.opacity ?? 1.0)

        ctx.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(lineWidth)
        if let dash = style.lineDash, dash.count >= 2 {
            ctx.setLineDash(phase: 0, lengths: dash.map { CGFloat($0) })
        } else {
            ctx.setLineDash(phase: 0, lengths: [])
        }

        var started = false
        for point in payload.series {
            guard let idx = timeIndexMap[point.time] else { continue }
            let x = xForIndex(idx)
            let y = yForPrice(point.value.dbl)
            if !started {
                ctx.move(to: CGPoint(x: x, y: y))
                started = true
            } else {
                ctx.addLine(to: CGPoint(x: x, y: y))
            }
        }
        ctx.strokePath()
    }

    private func drawBand(_ payload: KLIndicatorBandPayload, style: KLOverlayStyle, ctx: CGContext, xForIndex: (Int) -> CGFloat, yForPrice: (Double) -> CGFloat, timeIndexMap: [Date: Int]) {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 0.5 { logger.info("[PERF][KX-UI-19] drawBand ms=\(dt)") }
        }
        guard payload.upperLine.count >= 2, payload.lowerLine.count >= 2 else { return }
        let fillOpacity = CGFloat(style.fillOpacity ?? 0.15)
        let color = style.fallbackHexColor.flatMap { NSColor(hex: $0) } ?? NSColor.systemCyan

        var upperPoints: [CGPoint] = []
        var lowerPoints: [CGPoint] = []

        for point in payload.upperLine {
            guard let idx = timeIndexMap[point.time] else { continue }
            upperPoints.append(CGPoint(x: xForIndex(idx), y: yForPrice(point.value.dbl)))
        }
        for point in payload.lowerLine {
            guard let idx = timeIndexMap[point.time] else { continue }
            lowerPoints.append(CGPoint(x: xForIndex(idx), y: yForPrice(point.value.dbl)))
        }

        guard upperPoints.count >= 2, lowerPoints.count >= 2 else { return }

        ctx.beginPath()
        ctx.move(to: upperPoints[0])
        for pt in upperPoints.dropFirst() { ctx.addLine(to: pt) }
        for pt in lowerPoints.reversed() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.setFillColor(color.withAlphaComponent(fillOpacity).cgColor)
        ctx.fillPath()

        // upper line
        drawLineSeries(payload.upperLine, style: style, ctx: ctx, xForIndex: xForIndex, yForPrice: yForPrice, timeIndexMap: timeIndexMap)
        // lower line
        drawLineSeries(payload.lowerLine, style: style, ctx: ctx, xForIndex: xForIndex, yForPrice: yForPrice, timeIndexMap: timeIndexMap)
        // middle line
        if let middle = payload.middleLine {
            drawLineSeries(middle, style: style, ctx: ctx, xForIndex: xForIndex, yForPrice: yForPrice, timeIndexMap: timeIndexMap)
        }
    }



    private func drawLineSeries(_ series: [KLIndicatorPoint], style: KLOverlayStyle, ctx: CGContext, xForIndex: (Int) -> CGFloat, yForPrice: (Double) -> CGFloat, timeIndexMap: [Date: Int]) {
        guard series.count >= 2 else { return }
        let color = style.fallbackHexColor.flatMap { NSColor(hex: $0) } ?? NSColor.systemCyan
        let lineWidth = CGFloat(style.lineWidth ?? 1.0)
        let alpha = CGFloat(style.opacity ?? 1.0)
        ctx.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineDash(phase: 0, lengths: [])
        var started = false
        for point in series {
            guard let idx = timeIndexMap[point.time] else { continue }
            let x = xForIndex(idx)
            let y = yForPrice(point.value.dbl)
            if !started { ctx.move(to: CGPoint(x: x, y: y)); started = true }
            else { ctx.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.strokePath()
    }

    private func drawHistogram(_ payload: KLIndicatorHistogramPayload, style: KLOverlayStyle, ctx: CGContext, xForIndex: (Int) -> CGFloat, yForPrice: (Double) -> CGFloat, timeIndexMap: [Date: Int], minPrice: Double, maxPrice: Double) {
        let baseline = payload.baseline.dbl
        let y0 = yForPrice(baseline)
        let barWidth = max(1, CGFloat(viewport.candleWidth) * 0.6)

        for point in payload.series {
            guard let idx = timeIndexMap[point.time] else { continue }
            let x = xForIndex(idx)
            let y1 = yForPrice(point.value.dbl)
            let isUp = point.value.dbl >= baseline
            let color = isUp ? NSColor.systemGreen : NSColor.systemRed
            let alpha = CGFloat(style.opacity ?? 1.0)
            let rect = CGRect(x: x - barWidth / 2, y: min(y0, y1), width: barWidth, height: abs(y1 - y0))
            ctx.setFillColor(color.withAlphaComponent(alpha).cgColor)
            ctx.fill(rect)
        }
    }

    private func drawHorizontalLine(_ payload: KLHorizontalLinePayload, style: KLOverlayStyle, ctx: CGContext, yForPrice: (Double) -> CGFloat) {
        let y = yForPrice(payload.value.dbl)
        let color = style.fallbackHexColor.flatMap { NSColor(hex: $0) } ?? NSColor.systemGray
        let lineWidth = CGFloat(style.lineWidth ?? 1.0)
        let alpha = CGFloat(style.opacity ?? 1.0)
        ctx.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(lineWidth)
        if let dash = style.lineDash, dash.count >= 2 {
            ctx.setLineDash(phase: 0, lengths: dash.map { CGFloat($0) })
        } else {
            ctx.setLineDash(phase: 0, lengths: [4, 3])
        }
        ctx.move(to: CGPoint(x: 0, y: y))
        ctx.addLine(to: CGPoint(x: bounds.width, y: y))
        ctx.strokePath()
        
        // CATextLayer 标签位置在 draw(in:) 末尾统一更新
    }

    private func drawPoints(_ payload: KLIndicatorPointMarkerPayload, style: KLOverlayStyle, ctx: CGContext, xForIndex: (Int) -> CGFloat, yForPrice: (Double) -> CGFloat, timeIndexMap: [Date: Int]) {
        let color = style.fallbackHexColor.flatMap { NSColor(hex: $0) } ?? NSColor.systemCyan
        let alpha = CGFloat(style.opacity ?? 1.0)
        let size = CGFloat(payload.size)
        ctx.setFillColor(color.withAlphaComponent(alpha).cgColor)

        for point in payload.points {
            guard let idx = timeIndexMap[point.time] else { continue }
            let x = xForIndex(idx)
            let y = yForPrice(point.value.dbl)
            let rect = CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
            ctx.fillEllipse(in: rect)
        }
    }

    private func drawRange(_ payload: KLRangePayload, style: KLOverlayStyle, ctx: CGContext, xForIndex: (Int) -> CGFloat, yForPrice: (Double) -> CGFloat, timeIndexMap: [Date: Int]) {
        let color = style.fallbackHexColor.flatMap { NSColor(hex: $0) } ?? NSColor.systemCyan
        let fillOpacity = CGFloat(style.fillOpacity ?? 0.15)
        let alpha = CGFloat(style.opacity ?? 1.0)

        let upperY = yForPrice(payload.upper.dbl)
        let lowerY = yForPrice(payload.lower.dbl)

        var startX: CGFloat = 0
        var endX: CGFloat = bounds.width

        if let startTime = payload.startTime, let idx = timeIndexMap[startTime] {
            startX = xForIndex(idx)
        }
        if let endTime = payload.endTime, let idx = timeIndexMap[endTime] {
            endX = xForIndex(idx)
        }

        let rect = CGRect(x: startX, y: min(upperY, lowerY), width: endX - startX, height: CGFloat(abs(upperY - lowerY)))
        ctx.setFillColor(color.withAlphaComponent(fillOpacity).cgColor)
        ctx.fill(rect)
        ctx.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(CGFloat(style.lineWidth ?? 1.0))
        ctx.stroke(rect)
    }
}



// MARK: - NSColor hex helper

private extension Decimal {
    var dbl: Double { NSDecimalNumber(decimal: self).doubleValue }
}

private extension NSColor {
    convenience init?(hex: String) {
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
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXUI19Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-19", fileName: "KX-UI-19_图表Overlay渲染器.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-19_图表Overlay渲染器.swift", duty: "消费 KLExternalChartOverlay 并渲染各类指标图形"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("图表Overlay渲染器骨架校验通过")
        return KXHealthCheckItem(name: "图表Overlay渲染器", passed: true, message: "已实现图表Overlay渲染器")
    }
}
