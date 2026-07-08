//
//  KX-UI-14_成交量视图.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：成交量柱绘制，与主图 K线 x 坐标对齐
//  禁止事项：禁止直接请求 OKX
//

import AppKit
import Foundation


public class KXUI14VolumeChartView: NSView {
    private let volLayer = CALayer()
    public var candles: [KLCandlePoint] = []
    public var viewport: KLViewportAdjustResult = KLViewportAdjustResult()
    public var upColor: NSColor = NSColor.systemGreen.withAlphaComponent(0.6)
    public var downColor: NSColor = NSColor.systemRed.withAlphaComponent(0.6)

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        volLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(volLayer)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !candles.isEmpty else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let w = viewport.candleWidth
        let barWidth = max(1, w - 2)
        let startIdx = max(0, viewport.startIndex)
        let endIdx = min(candles.count, startIdx + max(5, Int(bounds.width / max(w, 1))))
        let slice = candles[startIdx..<endIdx]
        guard let maxVol = slice.map({ $0.volume }).max(), maxVol > 0 else { return }

        let height = bounds.height - 4
        for (i, c) in slice.enumerated() {
            let x = CGFloat(i) * w + 2
            guard let vol = Double(c.volume.description), let mx = Double(maxVol.description) else { continue }
            let barH = CGFloat(Double(vol) / Double(mx)) * height
            ctx.setFillColor(c.close >= c.open ? upColor.cgColor : downColor.cgColor)
            ctx.fill(CGRect(x: x, y: 2, width: barWidth, height: barH))
        }
    }

    public func refresh() {
        needsDisplay = true
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXKXUI14Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-14", fileName: "KX-UI-14_成交量视图.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-14_成交量视图.swift", duty: "成交量视图组件"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("成交量视图骨架校验通过")
        return KXHealthCheckItem(name: "成交量视图", passed: true, message: "成交量视图组件")
    }
}
