//
//  KX-UI-10_币对标签栏.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：浏览器式多币对标签栏视图
//  禁止事项：禁止直接请求 OKX、禁止直接查库
//

import AppKit
import Foundation

private let logger = klineLogger


public class KXUI10PairTabBarView: NSView {
    private var buttons: [NSButton] = []
    private var closeButtons: [NSButton] = []
    private let collapsePreviewButton = KXUI10RoundArrowButton(frame: .zero)
    public var tabs: [String] = [] {
        didSet { rebuildTabs(); needsLayout = true }
    }
    public var activeTabID: String = "" {
        didSet { updateHighlight() }
    }

    private let tabHeight: CGFloat = 32
    private let tabPadding: CGFloat = 8

    public var onTabSelected: ((String) -> Void)? {
        didSet {
            logger.info("[KLine][UI][Tab] onTabSelected registered")
        }
    }
    public var onTabClosed: ((String) -> Void)? {
        didSet {
            logger.info("[KLine][UI][Tab] onTabClosed registered")
        }
    }
    public var onCollapseRequested: (() -> Void)?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        collapsePreviewButton.toolTip = "折叠K线模块"
        collapsePreviewButton.target = self
        collapsePreviewButton.action = #selector(previewCollapseButtonClicked)
        addSubview(collapsePreviewButton)
    }

    /// ⚠️ 2026-06-22 崩溃根治(码农,lldb+崩溃报告取证)：
    /// 原 layout() 每次都 removeFromSuperview 删光所有标签再 addSubview 重建。
    /// 在 layout()(显示周期)内增删子视图是 AppKit 头号大忌：removeFromSuperview 会触发
    /// setNeedsUpdateConstraints 向上冒泡 → _postWindowNeedsUpdateConstraints → 在显示提交阶段重入 → 招异常崩溃。
    /// 修复：子视图只在 tabs 数据变化时由 rebuildTabs() 增删(显示周期外)；layout() 只设 frame/title/isHidden，绝不增删。
    private func rebuildTabs() {
        // 多余的标签移除(仅数据变化时)
        while buttons.count > tabs.count {
            buttons.removeLast().removeFromSuperview()
            closeButtons.removeLast().removeFromSuperview()
        }
        // 不足的补足
        while buttons.count < tabs.count {
            let btn = NSButton(frame: .zero)
            btn.bezelStyle = .rounded
            btn.setButtonType(.pushOnPushOff)
            btn.target = self
            btn.action = #selector(tabClicked(_:))
            addSubview(btn)
            buttons.append(btn)

            let closeBtn = NSButton(frame: .zero)
            closeBtn.title = "×"
            closeBtn.bezelStyle = .smallSquare
            closeBtn.font = NSFont.systemFont(ofSize: 10)
            closeBtn.target = self
            closeBtn.action = #selector(closeTabClicked(_:))
            addSubview(closeBtn)
            closeButtons.append(closeBtn)
        }
    }

    public override func layout() {
        super.layout()

        // 右侧折叠按钮固定位置
        let buttonSize: CGFloat = 30
        collapsePreviewButton.frame = CGRect(
            x: max(8, bounds.width - buttonSize - 10),
            y: (bounds.height - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        )
        collapsePreviewButton.setNeedsDisplay(collapsePreviewButton.bounds)

        // 安全网：若子视图与数据不一致，补齐后再摆(rebuildTabs 不在显示周期增删)。
        if buttons.count != tabs.count || closeButtons.count != tabs.count {
            rebuildTabs()
        }
        guard !tabs.isEmpty else { return }

        let startX: CGFloat = 4
        let maxContentX = max(startX, collapsePreviewButton.frame.minX - 10)
        let available = maxContentX - startX
        guard available > 0 else {
            for b in buttons { b.isHidden = true }
            for c in closeButtons { c.isHidden = true }
            return
        }

        let count = tabs.count
        let minTabWidth: CGFloat = 80      // 最小标签宽度
        let maxTabWidth: CGFloat = 180     // 最大标签宽度（类似 Safari）
        let interGap: CGFloat = tabPadding // 标签间距
        let closeBtnWidth: CGFloat = 16    // 关闭按钮宽度
        let closeBtnGap: CGFloat = 2       // 关闭按钮与标签间距

        // 完全等宽的 slot 宽度
        let totalGap = interGap * CGFloat(max(0, count - 1))
        var slotWidth = (available - totalGap) / CGFloat(count)
        slotWidth = min(maxTabWidth, max(minTabWidth, slotWidth))

        let sysFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let textAttrs: [NSAttributedString.Key: Any] = [.font: sysFont]

        var x = startX
        var stop = false
        for (index, tab) in tabs.enumerated() {
            let btn = buttons[index]
            let closeBtn = closeButtons[index]

            // 空间不够：隐藏本标签及后面所有(仅设 isHidden，不删子视图)
            if stop || x + slotWidth > maxContentX + 0.5 {
                stop = true
                btn.isHidden = true
                closeBtn.isHidden = true
                continue
            }

            let labelWidth = slotWidth - closeBtnWidth - closeBtnGap
            let displayTitle = Self.truncateTitle(tab, maxWidth: labelWidth - 16, attrs: textAttrs)

            btn.isHidden = false
            btn.title = displayTitle
            btn.tag = index
            btn.state = (tab == activeTabID) ? .on : .off
            btn.frame = CGRect(x: x, y: (bounds.height - tabHeight) / 2, width: labelWidth, height: tabHeight)

            closeBtn.isHidden = false
            closeBtn.tag = index
            closeBtn.frame = CGRect(x: x + labelWidth + closeBtnGap, y: (bounds.height - 16) / 2, width: closeBtnWidth, height: 16)

            x += slotWidth + interGap
        }
    }

    private static func truncateTitle(_ title: String, maxWidth: CGFloat, attrs: [NSAttributedString.Key: Any]) -> String {
        guard maxWidth > 0, (title as NSString).size(withAttributes: attrs).width > maxWidth else { return title }
        let ellipsis = "…"
        let budget = maxWidth - (ellipsis as NSString).size(withAttributes: attrs).width
        guard budget > 0 else { return ellipsis }
        var chars = Array(title)
        while chars.count > 1 {
            chars.removeLast()
            if (String(chars) as NSString).size(withAttributes: attrs).width <= budget {
                return String(chars) + ellipsis
            }
        }
        return ellipsis
    }

    @objc private func tabClicked(_ sender: NSButton) {
        guard let idx = buttons.firstIndex(of: sender) else { return }
        let tabID = tabs[idx]
        logger.info("[KLine][UI][Tab] tabClicked symbol=\(tabID) index=\(idx) activeTab=\(activeTabID)")
        activeTabID = tabID
        onTabSelected?(tabID)
    }

    @objc private func closeTabClicked(_ sender: NSButton) {
        guard let idx = closeButtons.firstIndex(of: sender) else { return }
        let tabID = tabs[idx]
        logger.info("[KLine][UI][Tab] closeTabClicked symbol=\(tabID) index=\(idx) activeTab=\(activeTabID)")
        onTabClosed?(tabID)
    }

    public func closeTab(id: String) {
        onTabClosed?(id)
    }

    @objc private func previewCollapseButtonClicked() {
        collapsePreviewButton.playPopAnimation()
        onCollapseRequested?()
    }

    public func setCollapsedVisualState(_ collapsed: Bool) {
        collapsePreviewButton.setPreviewState(collapsed)
    }

    /// ⚠️ 2026-06-22：供面板（由 UI 模块主题监听机制驱动）调用的主题刷新入口。
    /// 标签按钮与关闭按钮重绘，重新布局，避免主题切换后颜色不跟。
    public func refreshTheme() {
        // 背景色由面板 applyPanelTheme 统一设置，此处只刷新按钮重绘+重布局。
        for btn in buttons { btn.needsDisplay = true }
        for closeBtn in closeButtons { closeBtn.needsDisplay = true }
        collapsePreviewButton.needsDisplay = true
        needsLayout = true
        needsDisplay = true
    }

    private func updateHighlight() {
        // tabs 变更后 layout 之前，buttons 仍可能是旧数组。
        // 关闭第一个/中间标签时如果直接 tabs[idx]，会因旧按钮数量大于新 tabs 数量而越界崩溃。
        for (idx, btn) in buttons.enumerated() {
            guard idx < tabs.count else {
                btn.state = .off
                continue
            }
            btn.state = tabs[idx] == activeTabID ? .on : .off
        }
    }
}


private final class KXUI10RoundArrowButton: NSButton {
    private var isHovering = false
    private var isPressedPreview = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        title = ""
        isBordered = false
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 6
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        image = nil
        contentTintColor = NSColor.labelColor
        alphaValue = 0.96
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        animateHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        animateHover(false)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        let rect = bounds.insetBy(dx: 1.0, dy: 1.0)
        let path = NSBezierPath(ovalIn: rect)

        // Apple 风格：半透明系统灰 + 细描边 + 柔和内高光，不使用彩色渐变。
        // 玻璃效果灰色：浅色主题用中灰底色+半透明，深色主题保持原逻辑
        let isDark = GlassThemeHelper.isDarkAppearance()
        let fillColor: NSColor
        if isDark {
            if isHovering {
                fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.86)
            } else {
                fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72)
            }
        } else {
            if isHovering {
                fillColor = NSColor(calibratedWhite: 0.72, alpha: 0.80)
            } else {
                fillColor = NSColor(calibratedWhite: 0.78, alpha: 0.72)
            }
        }
        fillColor.setFill()
        path.fill()

        // 描边：浅色主题用白色细边增加玻璃感，深色主题保持原逻辑
        let strokeColor = isDark ? NSColor.white.withAlphaComponent(isHovering ? 0.42 : 0.28) : NSColor.white.withAlphaComponent(isHovering ? 0.55 : 0.40)
        strokeColor.setStroke()
        path.lineWidth = 0.8
        path.stroke()

        let inner = NSBezierPath(ovalIn: rect.insetBy(dx: 1.0, dy: 1.0))
        NSColor.black.withAlphaComponent(isHovering ? 0.10 : 0.07).setStroke()
        inner.lineWidth = 0.6
        inner.stroke()

        drawChevron(in: rect)
    }

    private func drawChevron(in rect: NSRect) {
        let arrow = NSBezierPath()
        let centerX = rect.midX
        let centerY = rect.midY
        let halfWidth: CGFloat = 5.4
        let halfHeight: CGFloat = 3.4

        if isPressedPreview {
            // 折叠预览态：向下箭头
            arrow.move(to: NSPoint(x: centerX - halfWidth, y: centerY + halfHeight / 2))
            arrow.line(to: NSPoint(x: centerX, y: centerY - halfHeight))
            arrow.line(to: NSPoint(x: centerX + halfWidth, y: centerY + halfHeight / 2))
        } else {
            // 展开态：向上箭头
            arrow.move(to: NSPoint(x: centerX - halfWidth, y: centerY - halfHeight / 2))
            arrow.line(to: NSPoint(x: centerX, y: centerY + halfHeight))
            arrow.line(to: NSPoint(x: centerX + halfWidth, y: centerY - halfHeight / 2))
        }

        arrow.lineWidth = 2.15
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        NSColor.labelColor.withAlphaComponent(0.88).setStroke()
        arrow.stroke()
    }

    private func animateHover(_ hovering: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = hovering ? 1.0 : 0.96
        }
        layer?.shadowOpacity = hovering ? 0.24 : 0.18
        layer?.shadowRadius = hovering ? 8 : 6
        needsDisplay = true
    }

    func playPopAnimation() {
        runPopAnimation()
    }

    func setPreviewState(_ collapsed: Bool) {
        isPressedPreview = collapsed
        needsDisplay = true
    }

    private func runPopAnimation() {
        guard let layer else { return }
        let down = CABasicAnimation(keyPath: "transform.scale")
        down.fromValue = 1.0
        down.toValue = 0.88
        down.duration = 0.07
        down.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let pop = CASpringAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.88
        pop.toValue = 1.0
        pop.mass = 0.55
        pop.stiffness = 360
        pop.damping = 18
        pop.initialVelocity = 9
        pop.beginTime = down.duration
        pop.duration = pop.settlingDuration

        let group = CAAnimationGroup()
        group.animations = [down, pop]
        group.duration = down.duration + pop.duration
        group.isRemovedOnCompletion = true
        layer.add(group, forKey: "kx.apple.pop")
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXKXUI10Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-10", fileName: "KX-UI-10_币对标签栏.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-10_币对标签栏.swift", duty: "币对标签栏"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("币对标签栏骨架校验通过")
        return KXHealthCheckItem(name: "币对标签栏", passed: true, message: "币对标签栏")
    }
}
