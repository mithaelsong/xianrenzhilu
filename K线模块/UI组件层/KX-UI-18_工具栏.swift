//
//  KX-UI-18_工具栏.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：OKX风格完整工具栏，包含交易对选择、时间框架、指标选择等所有功能
//  禁止事项：禁止直接请求OKX、禁止直接读写数据库
//

import AppKit
import Foundation
import SwiftUI

// MARK: - OKX风格工具栏主视图

public class KXUI18ToolbarView: NSView {
    private var contentViews: [NSView] = []
    private var instrumentSelector: KLTradingPairSelectorView!
    private var timeframeSelector: KXUI11TimeframeSelectorView!
    private var indicatorButton: NSButton!
    private var settingsButton: NSButton!
    private var isMinimized: Bool = false
    private var normalLayoutConstraints: [NSLayoutConstraint] = []
    private var minimizedLayoutConstraints: [NSLayoutConstraint] = []
    private var isDraggingContainer = false
    private var dragStartContainerFrame: NSRect = .zero
    private var dragStartMouseInContainerSuperview: NSPoint = .zero

    public var selectedTimeframe: KXTimeframe = .oneHour {
        didSet { updateTimeframeHighlight() }
    }

    public var onMarketTypeChanged: ((KLMarketType) -> Void)?
    public var onInstrumentSelected: ((String) -> Void)?
    public var onTimeframeSelected: ((KXTimeframe) -> Void)?
    /// 顶部快捷周期集合变更（弹层多选确认后触发）。用于多画布：新增周期建画布，移除周期销毁画布。
    public var onVisibleTimeframesChanged: (([KXTimeframe]) -> Void)?
    public var onIndicatorSelected: ((KLTechnicalIndicator) -> Void)?
    public var onDisplaySettingsChanged: (([String: Any]) -> Void)?
    public var onMinimizeToggled: ((Bool) -> Void)?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // 先应用玻璃效果
        applyGlassEffect()

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        setupStackView()
        setupToolbarComponents()
        setupConstraints()
        setupButtonStyles()
        applyTheme()

        // 监听主题变更
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: NSNotification.Name("KXUIThemeDidChange"),
            object: nil
        )
    }

    private func applyGlassEffect() {
        // 移除现有的玻璃效果
        for subview in subviews where subview is NSVisualEffectView {
            subview.removeFromSuperview()
        }

        let isDark = GlassThemeHelper.isDarkAppearance()
        let config = UIGlassEffectConfiguration()

        let glassEffect = NSVisualEffectView(frame: bounds)
        glassEffect.material = config.material.nsMaterial
        glassEffect.blendingMode = config.blendingMode.nsBlendingMode
        glassEffect.state = config.state.nsState
        glassEffect.wantsLayer = true
        glassEffect.layer?.cornerRadius = config.cornerRadius
        glassEffect.layer?.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner]
        glassEffect.autoresizingMask = [.width, .height]
        // 浅色主题：降低玻璃效果透明度，让底层 subToolbarBackground 颜色透出来，与一级栏(纯白)形成区分
        glassEffect.alphaValue = isDark ? config.materialStrength : 0.35
        addSubview(glassEffect, positioned: .below, relativeTo: nil)
    }

    @objc private func themeDidChange() {
        applyTheme()
    }

    /// ⚠️ 2026-06-22：供面板（由 UI 模块主题监听机制驱动）调用的统一刷新入口。
    /// 刷新工具栏自身背景+所有内部控件（按钮/选择器），避免主题切换后凌乱。
    public func refreshTheme() {
        applyTheme()
        // 刷新玻璃背景层
        for subview in subviews where subview is NSVisualEffectView {
            subview.needsDisplay = true
        }
        // 递归触发内部控件重绘（选择器内部自己读主题色）
        for v in contentViews {
            v.needsDisplay = true
            v.needsLayout = true
            v.subviews.forEach { $0.needsDisplay = true }
        }
        needsLayout = true
        needsDisplay = true
    }

    private func applyTheme() {
        // 主题读取 UI 模块权威 GlassThemeHelper（含手动切换主题），不再直读 NSApp.effectiveAppearance。
        let isDark = GlassThemeHelper.isDarkAppearance()
        let tintColor = isDark ? NSColor.white.withAlphaComponent(0.86) : NSColor.labelColor

        // 更新按钮样式
        for button in [indicatorButton, settingsButton] where button != nil {
            if let btn = button {
                let btnBg = isDark ? NSColor(calibratedWhite: 0.2, alpha: 0.3) : NSColor(calibratedWhite: 0.85, alpha: 0.3)
                btn.layer?.backgroundColor = btnBg.cgColor
                btn.alphaValue = 0.9
                btn.contentTintColor = tintColor
            }
        }
    }

    private func setupStackView() {
        // ⚠️ 2026-06-22 彻底修复：工具栏不再用 NSStackView。
        // NSStackView 内部会生成 required 的间距/边距约束，叠加子控件的 required 尺寸约束(宽132/宽32)，
        // 当容器在显示周期某一瞬尺寸=0 时与之冲突 → 不可满足约束 → 重入崩溃。
        // 改为纯 frame 手动摆放子控件(见 layout())，工具栏里一条 Auto Layout 都没有。
    }

    private func setupToolbarComponents() {
        // 纯 frame 布局：子控件直接 addSubview、用 frame 摆放，不加任何跨层 Auto Layout 约束。
        // 1. 时间框架选择器
        timeframeSelector = KXUI11TimeframeSelectorView()
        timeframeSelector.selectedTimeframe = selectedTimeframe
        timeframeSelector.translatesAutoresizingMaskIntoConstraints = true
        addSubview(timeframeSelector)

        // 2. 交易/币对复合选择器
        instrumentSelector = KLTradingPairSelectorView(initialType: .spot)
        instrumentSelector.translatesAutoresizingMaskIntoConstraints = true
        addSubview(instrumentSelector)

        // 3. 技术指标按钮
        indicatorButton = createToolbarButton(title: "指标", icon: "chevron.down")
        indicatorButton.target = self
        indicatorButton.action = #selector(showIndicatorMenu)
        indicatorButton.translatesAutoresizingMaskIntoConstraints = true
        addSubview(indicatorButton)

        // 4. 显示设置按钮
        settingsButton = createToolbarButton(title: "设置", icon: "chevron.down")
        settingsButton.target = self
        settingsButton.action = #selector(showSettingsMenu)
        settingsButton.translatesAutoresizingMaskIntoConstraints = true
        addSubview(settingsButton)

        // 5. （已删除）最小化按钮：废弃的二级栏方形折叠箭头，折叠入口已由一级栏圆形按钮接管。

        // 左→右顺序
        contentViews = [timeframeSelector, instrumentSelector, indicatorButton, settingsButton]

        // 绑定回调
        setupBindings()
    }

    private func createToolbarButton(title: String, icon: String) -> NSButton {
        let btn = NSButton(title: title, target: nil, action: nil)
        btn.bezelStyle = .rounded
        btn.setButtonType(.momentaryPushIn)
        btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        // Note: NSButton.contentInsets not available on macOS - using frame-based layout instead
        btn.imagePosition = .imageLeading
        btn.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        btn.alignment = .center

        // 苹果风格按钮样式
        btn.layer?.cornerRadius = 6
        btn.layer?.masksToBounds = true
        btn.wantsLayer = true

        // 正常状态
        let isDark = GlassThemeHelper.isDarkAppearance()
        let btnBg = isDark ? NSColor(calibratedWhite: 0.2, alpha: 0.3) : NSColor(calibratedWhite: 0.85, alpha: 0.3)
        btn.layer?.backgroundColor = btnBg.cgColor
        btn.alphaValue = 0.9

        return btn
    }

    private func setupButtonStyles() {
        // 为所有按钮添加悬停效果
        for button in [indicatorButton, settingsButton] where button != nil {
            if let btn = button {
                btn.addTrackingArea(NSTrackingArea(rect: btn.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil))
            }
        }
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        if hit === self { return self }
        if hit is NSVisualEffectView || hit === self { return self }
        if !isInteractiveToolbarHit(hit) { return self }
        return hit
    }

    private func isInteractiveToolbarHit(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let node = current, node !== self {
            if node is NSControl || node is NSPopUpButton || node is NSSegmentedControl || node is NSScrollView || node is KXUI11TimeframeSelectorView || node is KLTradingPairSelectorView {
                return true
            }
            current = node.superview
        }
        return false
    }

    public override func mouseDown(with event: NSEvent) {
        guard let container = enclosingUIContainer(), let parent = container.superview else {
            super.mouseDown(with: event)
            return
        }
        isDraggingContainer = true
        dragStartContainerFrame = container.frame
        dragStartMouseInContainerSuperview = parent.convert(event.locationInWindow, from: nil)
        NSCursor.closedHand.set()
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDraggingContainer, let container = enclosingUIContainer(), let parent = container.superview else {
            super.mouseDragged(with: event)
            return
        }
        let currentMouse = parent.convert(event.locationInWindow, from: nil)
        let deltaX = currentMouse.x - dragStartMouseInContainerSuperview.x
        let deltaY = currentMouse.y - dragStartMouseInContainerSuperview.y
        var next = dragStartContainerFrame
        next.origin.x += deltaX
        next.origin.y += deltaY
        container.frame = constrainedContainerFrame(next, in: parent.bounds)
        container.needsLayout = true
    }

    public override func mouseUp(with event: NSEvent) {
        if isDraggingContainer, let container = enclosingUIContainer() {
            container.persistLayoutState()
        }
        isDraggingContainer = false
        NSCursor.openHand.set()
        super.mouseUp(with: event)
    }

    private func enclosingUIContainer() -> UIContainerView? {
        var current = superview
        while let node = current {
            if let container = node as? UIContainerView { return container }
            current = node.superview
        }
        return nil
    }

    private func constrainedContainerFrame(_ frame: NSRect, in parentBounds: NSRect) -> NSRect {
        var result = frame
        result.size.width = min(result.width, parentBounds.width)
        result.size.height = min(result.height, parentBounds.height)
        result.origin.x = min(max(result.origin.x, parentBounds.minX), parentBounds.maxX - result.width)
        result.origin.y = min(max(result.origin.y, parentBounds.minY), parentBounds.maxY - result.height)
        return result
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if let button = event.trackingArea?.owner as? NSButton, button == indicatorButton || button == settingsButton {
            animateButtonHover(button, entering: true)
        }
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if let button = event.trackingArea?.owner as? NSButton, button == indicatorButton || button == settingsButton {
            animateButtonHover(button, entering: false)
        }
    }

    private func animateButtonHover(_ button: NSButton, entering: Bool) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            if entering {
                let isDark = GlassThemeHelper.isDarkAppearance()
                let hoverBg = isDark ? NSColor(calibratedWhite: 0.3, alpha: 0.4) : NSColor(calibratedWhite: 0.75, alpha: 0.4)
                button.layer?.backgroundColor = hoverBg.cgColor
                button.alphaValue = 1.0
                button.layer?.transform = CATransform3DMakeScale(1.05, 1.05, 1.0)
            } else {
                let isDark = GlassThemeHelper.isDarkAppearance()
                let normalBg = isDark ? NSColor(calibratedWhite: 0.2, alpha: 0.3) : NSColor(calibratedWhite: 0.85, alpha: 0.3)
                button.layer?.backgroundColor = normalBg.cgColor
                button.alphaValue = 0.9
                button.layer?.transform = CATransform3DIdentity
            }
        }, completionHandler: nil)
    }

    private func setupBindings() {
        instrumentSelector.onMarketTypeChanged = { [weak self] type in
            self?.onMarketTypeChanged?(type)
        }

        instrumentSelector.onInstrumentSelected = { [weak self] instrument in
            self?.onInstrumentSelected?(instrument)
        }

        timeframeSelector.onTimeframeSelected = { [weak self] timeframe in
            self?.selectedTimeframe = timeframe
            self?.onTimeframeSelected?(timeframe)
        }
        timeframeSelector.onVisibleTimeframesChanged = { [weak self] timeframes in
            self?.onVisibleTimeframesChanged?(timeframes)
        }
    }

    private func setupConstraints() {
        // ⚠️ 2026-06-22 彻底修复：工具栏内零 Auto Layout。所有子控件用 frame 摆放(见 layout())。
        needsLayout = true
    }

    /// 纯 frame 摆放所有子控件（零 Auto Layout）。左起：周期|币对|指标|设置。
    public override func layout() {
        super.layout()
        let h = bounds.height
        let w = bounds.width
        guard h > 0, w > 0 else { return }

        let vInset: CGFloat = 4
        let hInset: CGFloat = 8
        let gap: CGFloat = 8
        let instrumentW: CGFloat = 132

        func controlSize(_ v: NSView, defaultW: CGFloat) -> CGSize {
            let fit = v.fittingSize
            let cw = fit.width > 1 ? fit.width : defaultW
            let chMax = max(0, h - vInset * 2)
            let ch = fit.height > 1 ? min(fit.height, chMax) : chMax
            return CGSize(width: cw, height: ch)
        }
        func place(_ v: NSView, x: CGFloat, width: CGFloat) {
            let chMax = max(0, h - vInset * 2)
            let fit = v.fittingSize
            let ch = fit.height > 1 ? min(fit.height, chMax) : chMax
            let y = (h - ch) / 2
            v.frame = CGRect(x: x, y: y, width: width, height: ch)
        }

        // 最小化态：全部隐藏（折叠入口已移交一级栏圆形按钮，二级栏不再有折叠按钮）。
        if isMinimized {
            for v in contentViews { v.isHidden = true }
            return
        }

        for v in contentViews { v.isHidden = false }

        // 左侧依次摆放，占满整行。
        var x = hInset
        let rightLimit = w - hInset
        for v in contentViews {
            let isInstrument = (v === instrumentSelector)
            let size = controlSize(v, defaultW: isInstrument ? instrumentW : 60)
            let cw = isInstrument ? instrumentW : size.width
            if x + cw > rightLimit {
                // 空间不够：本控件及后面的可裁切（仅 frame，不崩）
                let avail = max(0, rightLimit - x)
                place(v, x: x, width: avail)
                x += avail + gap
                continue
            }
            place(v, x: x, width: cw)
            x += cw + gap
        }
    }

    private func updateLayoutForMinimizedState() {
        // frame 定位下，最小化只需重新布局。
        needsLayout = true
        self.setNeedsDisplay(self.bounds)
    }

    private func updateTimeframeHighlight() {
        timeframeSelector.selectedTimeframe = selectedTimeframe
    }

    @objc private func showIndicatorMenu() {
        let menu = NSMenu(title: "技术指标")

        // 按真实功能分类顺序分组
        let indicatorManager = KXTechnicalIndicatorManager.shared

        for category in KLIndicatorCategory.displayOrder {
            let indicators = indicatorManager.indicators(for: category)
            guard !indicators.isEmpty else { continue }

            let submenu = NSMenu()
            submenu.title = category.rawValue

            for indicator in indicators {
                let item = NSMenuItem(title: indicator.name, action: #selector(indicatorMenuItemSelected(_:)), keyEquivalent: "")
                item.representedObject = indicator.id
                item.target = self
                item.toolTip = indicator.description
                submenu.addItem(item)
            }

            let groupItem = NSMenuItem(title: "\(category.rawValue) · \(indicators.count)", action: nil, keyEquivalent: "")
            groupItem.submenu = submenu
            menu.addItem(groupItem)
        }

        menu.addItem(NSMenuItem.separator())
        let addCustomItem = NSMenuItem(title: "添加/管理自定义指标...", action: #selector(addCustomIndicator), keyEquivalent: "")
        addCustomItem.target = self
        menu.addItem(addCustomItem)

        // 在按钮位置显示菜单
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: indicatorButton.bounds.height + 8), in: indicatorButton)
    }

    @objc private func indicatorMenuItemSelected(_ sender: NSMenuItem) {
        guard let indicatorId = sender.representedObject as? String,
              let indicator = KXTechnicalIndicatorManager.shared.indicator(withId: indicatorId) else {
            return
        }

        onIndicatorSelected?(indicator)
    }

    @objc private func addCustomIndicator() {
        let alert = NSAlert()
        alert.messageText = "添加自定义指标"
        alert.informativeText = "暂不支持自定义指标创建，请等待后续版本更新"
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    @objc private func showSettingsMenu() {
        let menu = NSMenu(title: "显示设置")

        // 网格显示
        let gridItem = NSMenuItem(title: "显示网格", action: #selector(toggleGrid(_:)), keyEquivalent: "")
        gridItem.target = self
        gridItem.state = .on
        menu.addItem(gridItem)

        // 十字光标
        let crosshairItem = NSMenuItem(title: "显示十字光标", action: #selector(toggleCrosshair(_:)), keyEquivalent: "")
        crosshairItem.target = self
        crosshairItem.state = .on
        menu.addItem(crosshairItem)

        // 成交量面板
        let volumeItem = NSMenuItem(title: "显示成交量", action: #selector(toggleVolume(_:)), keyEquivalent: "")
        volumeItem.target = self
        volumeItem.state = .on
        menu.addItem(volumeItem)

        // 分隔线
        menu.addItem(NSMenuItem.separator())

        // 主题设置
        let themeMenu = NSMenu()
        themeMenu.title = "主题"

        let themeItems = [
            ("浅色主题", "light"),
            ("深色主题", "dark"),
            ("跟随系统", "system")
        ]

        for item in themeItems {
            let menuItem = NSMenuItem(title: item.0, action: #selector(changeTheme(_:)), keyEquivalent: "")
            menuItem.representedObject = item.1
            menuItem.target = self
            if item.1 == "dark" {
                menuItem.state = .on
            }
            themeMenu.addItem(menuItem)
        }

        let themeGroupItem = NSMenuItem(title: "主题", action: nil, keyEquivalent: "")
        themeGroupItem.submenu = themeMenu
        menu.addItem(themeGroupItem)

        // 在按钮位置显示菜单
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: settingsButton.bounds.height + 8), in: settingsButton)
    }

    @objc private func toggleGrid(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        onDisplaySettingsChanged?(["grid": sender.state == .on])
    }

    @objc private func toggleCrosshair(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        onDisplaySettingsChanged?(["crosshair": sender.state == .on])
    }

    @objc private func toggleVolume(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        onDisplaySettingsChanged?(["volume": sender.state == .on])
    }

    @objc private func changeTheme(_ sender: NSMenuItem) {
        // 重置所有主题选项
        if let submenu = sender.menu {
            for item in submenu.items {
                item.state = .off
            }
        }

        sender.state = .on
        if let themeId = sender.representedObject as? String {
            onDisplaySettingsChanged?(["theme": themeId])
        }
    }

    @objc private func toggleMinimize() {
        isMinimized.toggle()

        // 更新布局约束
        updateLayoutForMinimizedState()

        // 通知父视图状态变更
        onMinimizeToggled?(isMinimized)

        // 更新自身布局
        invalidateIntrinsicContentSize()
    }

    public func setMinimized(_ minimized: Bool) {
        isMinimized = minimized

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            self.updateLayoutForMinimizedState()
            self.invalidateIntrinsicContentSize()

            // 动画效果
            if minimized {
                self.contentViews.forEach { $0.animator().alphaValue = 0.7 }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    self.layer?.transform = CATransform3DMakeScale(0.96, 0.96, 1.0)
                })
            } else {
                self.contentViews.forEach { $0.animator().alphaValue = 1.0 }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    self.layer?.transform = CATransform3DIdentity
                })
            }
        }, completionHandler: nil)
    }

    // MARK: - 公共接口

    public func updateSelectedInstrument(_ instrument: String) {
        instrumentSelector.updateSelectedInstrument(instrument)
    }

    public func switchMarketType(_ type: KLMarketType) {
        instrumentSelector.switchMarketType(type)
    }
}

// MARK: - 辅助扩展

extension KXUI18ToolbarView {
    /// 创建标准OKX风格工具栏按钮
    static func createStandardButton(title: String, target: Any?, action: Selector?) -> NSButton {
        let btn = NSButton(title: title, target: target, action: action)
        btn.bezelStyle = .inline
        btn.setButtonType(.momentaryPushIn)
        btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        // Note: NSButton.contentInsets not available on macOS - using frame-based layout instead
        return btn
    }
}

// MARK: - 预览

struct KXUI18ToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        struct KXUI18ToolbarViewRepresentable: NSViewRepresentable {
            func makeNSView(context: Context) -> KXUI18ToolbarView {
                let view = KXUI18ToolbarView(frame: CGRect(x: 0, y: 0, width: 800, height: 40))
                return view
            }

            func updateNSView(_ nsView: KXUI18ToolbarView, context: Context) {
                // Update the view if needed
            }
        }

        return KXUI18ToolbarViewRepresentable()
            .frame(width: 800, height: 40)
    }
}
// MARK: - KXFileSkeletonProtocol

public enum KXKXUI18Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-18", fileName: "KX-UI-18_工具栏.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-18_工具栏.swift", duty: "工具栏组件"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("工具栏骨架校验通过")
        return KXHealthCheckItem(name: "工具栏", passed: true, message: "工具栏组件")
    }
}

