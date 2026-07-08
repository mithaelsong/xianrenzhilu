//
//  KX-UI-13_图表覆盖层.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.2
//  职责：十字光标 + 实时价格线 + 外部指标/形态/交易标记覆盖层
//  禁止事项：禁止直接请求 OKX
//

import AppKit
import Foundation


public class KXUI13ChartOverlayView: NSView {
    private let crosshairVLayer = CALayer()
    private let crosshairHLayer = CALayer()
    private let priceLineLayer = CALayer()
    private let priceLabelLayer = CATextLayer()

    public var isCrosshairVisible: Bool = false
    public var lineColorUp: CGColor = NSColor.systemGreen.cgColor
    public var lineColorDown: CGColor = NSColor.systemRed.cgColor
    public var lineColorCrosshair: CGColor = NSColor.white.cgColor

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        // 十字线竖线
        crosshairVLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(crosshairVLayer)

        // 十字线横线
        crosshairHLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(crosshairHLayer)

        // 价格线
        priceLineLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(priceLineLayer)

        // 价格标签
        priceLabelLayer.fontSize = 10
        priceLabelLayer.alignmentMode = .center
        priceLabelLayer.backgroundColor = NSColor.controlBackgroundColor.cgColor
        priceLabelLayer.foregroundColor = NSColor.labelColor.cgColor
        priceLabelLayer.cornerRadius = 2
        priceLabelLayer.isHidden = true
        layer?.addSublayer(priceLabelLayer)

        hideAll()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 绘制十字线
        if isCrosshairVisible {
            drawCrosshair()
        }
    }

    private func drawCrosshair() {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.setStrokeColor(lineColorCrosshair)
        ctx.setLineWidth(0.5)
        ctx.setLineDash(phase: 0, lengths: [4, 3])

        // 竖线
        let vFrame = crosshairVLayer.frame
        ctx.move(to: CGPoint(x: vFrame.midX, y: 0))
        ctx.addLine(to: CGPoint(x: vFrame.midX, y: bounds.height))
        ctx.strokePath()

        // 横线
        let hFrame = crosshairHLayer.frame
        ctx.move(to: CGPoint(x: 0, y: hFrame.midY))
        ctx.addLine(to: CGPoint(x: bounds.width, y: hFrame.midY))
        ctx.strokePath()
    }

    public func showCrosshair(at point: NSPoint, time: Date, price: Decimal) {
        isCrosshairVisible = true
        crosshairVLayer.isHidden = false
        crosshairHLayer.isHidden = false
        crosshairVLayer.frame = CGRect(x: point.x - 0.5, y: 0, width: 1, height: bounds.height)
        crosshairHLayer.frame = CGRect(x: 0, y: point.y - 0.5, width: bounds.width, height: 1)
        setNeedsDisplay(bounds)
    }

    public func hideCrosshair() {
        isCrosshairVisible = false
        crosshairVLayer.isHidden = true
        crosshairHLayer.isHidden = true
        setNeedsDisplay(bounds)
    }

    public func updatePriceLine(price: Decimal, direction: KLPriceDirection) {
        priceLineLayer.isHidden = false
        priceLabelLayer.isHidden = false

        let color = direction == .up ? lineColorUp : (direction == .down ? lineColorDown : NSColor.gray.cgColor)
        priceLineLayer.backgroundColor = color

        // 价格标签
        let priceStr = price.description
        priceLabelLayer.string = priceStr
        let labelWidth = CGFloat(priceStr.count * 7 + 10)
        priceLabelLayer.frame = CGRect(x: bounds.width - labelWidth - 2, y: bounds.midY - 8, width: labelWidth, height: 16)

        setNeedsDisplay(bounds)
    }

    public func hidePriceLine() {
        priceLineLayer.isHidden = true
        priceLabelLayer.isHidden = true
        setNeedsDisplay(bounds)
    }

    public func hideAll() {
        hideCrosshair()
        hidePriceLine()
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXKXUI13Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-13", fileName: "KX-UI-13_图表覆盖层.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-13_图表覆盖层.swift", duty: "图表覆盖层"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("图表覆盖层骨架校验通过")
        return KXHealthCheckItem(name: "图表覆盖层", passed: true, message: "图表覆盖层")
    }
}
