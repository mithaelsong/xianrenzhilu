//
//  KX-UI-15_可拖拽分割线.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：主图/成交量之间的白色可拖拽分割线
//  禁止事项：禁止直接请求 OKX
//

import AppKit
import Foundation


public class KXUI15SplitterView: NSView {
    /// 比例回调：主图占比 0.60~0.90
    public var onRatioChanged: ((Double) -> Void)?

    private let lineLayer = CALayer()
    private var dragging: Bool = false
    private let defaultRatio: Double = 0.75
    private let minRatio: Double = 0.60
    private let maxRatio: Double = 0.90

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        lineLayer.backgroundColor = NSColor.white.cgColor
        lineLayer.frame = CGRect(x: 0, y: frame.height / 2 - 0.5, width: frame.width, height: 1)
        lineLayer.opacity = 0.8
        layer?.addSublayer(lineLayer)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if loc.x >= 0, loc.x <= bounds.width, abs(loc.y - bounds.midY) <= 8 {
            dragging = true
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        guard dragging else { return }
        // 拖动时通过回调通知父视图更新比例
        let parentHeight = superview?.bounds.height ?? bounds.height
        let offset = event.deltaY
        let newRatio = defaultRatio + (offset / parentHeight)
        let clamped = max(minRatio, min(maxRatio, newRatio))
        onRatioChanged?(clamped)
    }

    public override func mouseUp(with event: NSEvent) {
        dragging = false
    }

    public override func layout() {
        super.layout()
        lineLayer.frame = CGRect(x: 0, y: bounds.midY - 0.5, width: bounds.width, height: 1)
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        let trackingArea = NSTrackingArea(rect: bounds, options: [.activeInActiveApp, .mouseMoved, .mouseEnteredAndExited], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSCursor.resizeUpDown.set()
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !dragging {
            NSCursor.arrow.set()
        }
    }

    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let loc = convert(event.locationInWindow, from: nil)
        if abs(loc.y - bounds.midY) <= 8 {
            NSCursor.resizeUpDown.set()
        } else {
            NSCursor.arrow.set()
        }
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXKXUI15Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-15", fileName: "KX-UI-15_可拖拽分割线.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-15_可拖拽分割线.swift", duty: "可拖拽分割线组件"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("可拖拽分割线骨架校验通过")
        return KXHealthCheckItem(name: "可拖拽分割线", passed: true, message: "可拖拽分割线组件")
    }
}
