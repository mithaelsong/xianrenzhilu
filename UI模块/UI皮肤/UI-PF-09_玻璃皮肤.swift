// MARK: - 玻璃皮肤
// 功能编号: UI-PF-09
// 版本: 3.0.0
// 职责: 统一视觉基座玻璃皮肤。所有参数集中可配，不动代码只改参数。
// 架构铁律: 皮肤文件只实现皮肤逻辑；公共协议/公共模型引用 UI-02_公共类型定义.swift。
// 辅助文件: UI-PF-09_玻璃皮肤辅助.swift (参数常量/工具/手势/音效)

import Foundation
import AppKit
import QuartzCore
import os

private let glassSkinPanelLogger = Logger(subsystem: "com.xianrenzhilu.ui", category: "GlassSkinPanel")

// MARK: - GlassSkin

public final class GlassSkin: NSObject, UISkinProtocol {
    public let skinId = "com.app.glass"
    public let skinName = "玻璃皮肤"
    public let skinVersion = "3.0.0"

    private weak var mainWindow: NSWindow?
    private weak var rootView: NSView?
    private weak var toolbarView: GlassToolbarView?
    private weak var settingsPanelView: GlassSettingsPanelView?
    private weak var edgeGestureView: GlassEdgeGestureView?
    private var settingsOutsideClickMonitor: Any?
    private var resizeObserver: NSObjectProtocol?

    public required override init() {
        super.init()
    }

    deinit {
        removeSettingsOutsideClickMonitor()
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
    }

    public func isSupported() -> Bool { true }

    public func apply(to window: NSWindow) {
        mainWindow = window
        window.title = "仙人指路"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // 关键：让内容视图真正占满标题栏区域。否则即使标题栏透明，系统仍会保留一段标题栏安全区，
        // 窗口拖到屏幕顶部时视觉 UI 会离菜单栏/桌面功能栏差一截，表现为“顶不到最上面”。
        window.styleMask.insert(.fullSizeContentView)
        // 拖动范围必须收口到功能栏：内容区点击/拖动不能移动窗口。
        // 真实拖动由 GlassToolbarView.mouseDown -> window.performDrag(with:) 处理。
        window.isMovableByWindowBackground = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.toolbar = nil
        // 使用 unified 工具栏样式，红绿灯位置匹配 Safari 标准
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unifiedCompact
        }

        // 设置最小窗口尺寸
        window.minSize = NSSize(
            width: GlassSkinConstants.windowMinWidth,
            height: GlassSkinConstants.windowMinHeight
        )

        window.appearance = GlassThemeHelper.nsAppearance()
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unifiedCompact
        }
        // 延迟执行交通灯对齐，确保窗口帧布局完成
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            window.layoutIfNeeded()
            self.alignTrafficLightButtons(in: window)
        }
    }

    public func apply(to view: NSView) {
        rootView = view
        view.wantsLayer = true
        view.appearance = GlassThemeHelper.nsAppearance()
        view.layer?.backgroundColor = NSColor.clear.cgColor
        // 根内容层必须裁剪圆角；否则 clear window + 矩形材质层会把顶部两个角盖成直角。
        view.layer?.cornerRadius = GlassSkinConstants.windowCornerRadius
        view.layer?.masksToBounds = true
        if #available(macOS 10.13, *) {
            view.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }

        // 移除旧的重复玻璃chrome
        removeDuplicateGlassChrome(from: view)

        // 添加背景玻璃材质
        ensureBrightGlassBackground(in: view)

        // 添加功能栏（含分割线、齿轮按钮）
        ensureToolbar(in: view)

        // 添加内容容器（非无限画布，随窗口自适应）
        ensureContentView(in: view)

        // 添加边缘手势
        ensureEdgeGesture(in: view)

        // 注册窗口大小变化监听
        installResizeObserverIfNeeded(for: view)

        // 布局子视图
        layoutGlassSubviews(in: view)
    }

    // MARK: - 设置面板控制

    public func openSettingsPanel(in window: NSWindow) {
        guard let root = rootView ?? window.contentView else { return }
        glassSkinPanelLogger.info("设置面板打开请求 root=\(root.bounds.width, privacy: .public)x\(root.bounds.height, privacy: .public)")
        // 如果已存在，先收起再重新打开（保证布局重新计算）
        if settingsPanelView != nil {
            closeSettingsPanel()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self, weak window] in
                guard let self, let window else { return }
                self.openSettingsPanel(in: window)
            }
            return
        }

        // 计算面板宽度，根据卡片数量自适应
        let cards = buildModuleCards()
        let contentWidth = calculatePanelContentWidth(for: cards,
                                                      containerHeight: max(0, root.bounds.height - GlassSkinConstants.toolbarHeight))
        let panelWidth = min(
            GlassSkinConstants.panelMaxWidth,
            max(GlassSkinConstants.panelMinWidth, min(contentWidth, root.bounds.width * GlassSkinConstants.panelWidthRatio))
        )

        let contentHeight = max(0, root.bounds.height - GlassSkinConstants.toolbarHeight)
        let panelHeight = max(GlassSkinConstants.cardHeight + GlassSkinConstants.panelScrollViewTopMargin + GlassSkinConstants.panelScrollViewBottomMargin, contentHeight)
        let targetFrame = NSRect(
            x: max(0, root.bounds.width - panelWidth),
            y: 0,
            width: panelWidth,
            height: min(panelHeight, contentHeight)
        )
        let startFrame = NSRect(
            x: root.bounds.width,
            y: 0,
            width: panelWidth,
            height: targetFrame.height
        )

        let panel = GlassSettingsPanelView(frame: startFrame)
        panel.identifier = NSUserInterfaceItemIdentifier("settingsPanel")
        panel.autoresizingMask = [.minXMargin, .height]
        panel.onKlineRequested = { [weak self] in
            KXUI08Entry.setPanelEnabled(!KXUI08Entry.isPanelEnabled())
            let cards = self?.buildModuleCards() ?? []
            panel.setCards(cards)
        }
        // 加入父视图前先隐藏，避免第一帧露出未应用弧度的直线状态
        panel.alphaValue = 0
        root.addSubview(panel, positioned: .above, relativeTo: nil)
        settingsPanelView = panel

        // 必须先加入真实视图层级，再设置卡片并强制布局。
        // 打开动画开始前就把卡片最终弧度/层级状态应用好。
        panel.layoutSubtreeIfNeeded()
        panel.setCards(cards)
        panel.layoutSubtreeIfNeeded()
        panel.applyInitialCardState()

        glassSkinPanelLogger.info("设置面板开始滑入 target=(x:\(targetFrame.origin.x, privacy: .public), y:\(targetFrame.origin.y, privacy: .public), w:\(targetFrame.width, privacy: .public), h:\(targetFrame.height, privacy: .public)) cards=\(cards.count, privacy: .public)")
        panel.animateIn(to: targetFrame)
        installSettingsOutsideClickMonitor()
    }

    public func closeSettingsPanel() {
        glassSkinPanelLogger.info("设置面板关闭请求")
        guard let panel = settingsPanelView, let root = rootView else {
            settingsPanelView = nil
            removeSettingsOutsideClickMonitor()
            return
        }
        let endFrame = NSRect(
            x: root.bounds.width,
            y: panel.frame.minY,
            width: panel.frame.width,
            height: panel.frame.height
        )
        settingsPanelView = nil
        removeSettingsOutsideClickMonitor()
        glassSkinPanelLogger.info("设置面板开始滑出 end=(x:\(endFrame.origin.x, privacy: .public), y:\(endFrame.origin.y, privacy: .public), w:\(endFrame.width, privacy: .public), h:\(endFrame.height, privacy: .public))")
        panel.animateOut(to: endFrame)
    }

    private func installSettingsOutsideClickMonitor() {
        removeSettingsOutsideClickMonitor()
        settingsOutsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self,
                  let root = self.rootView,
                  let panel = self.settingsPanelView,
                  let window = root.window,
                  event.window === window
            else { return event }

            let rootPoint = root.convert(event.locationInWindow, from: nil)
            if panel.frame.contains(rootPoint) { return event }
            if self.isPointInsideSettingsButton(rootPoint, in: root) { return event }

            glassSkinPanelLogger.info("点击设置面板外，触发设置面板收回 point=(\(rootPoint.x, privacy: .public), \(rootPoint.y, privacy: .public))")
            self.closeSettingsPanel()
            return event
        }
    }

    private func removeSettingsOutsideClickMonitor() {
        if let monitor = settingsOutsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            settingsOutsideClickMonitor = nil
        }
    }

    private func isPointInsideSettingsButton(_ point: NSPoint, in root: NSView) -> Bool {
        guard let toolbar = toolbarView else { return false }
        let toolbarPoint = toolbar.convert(point, from: root)
        return toolbar.settingsButtonFrameInToolbar.contains(toolbarPoint)
    }

    fileprivate func toggleSettingsPanel() {
        guard let window = mainWindow ?? rootView?.window else { return }
        if settingsPanelView == nil {
            openSettingsPanel(in: window)
        } else {
            closeSettingsPanel()
        }
    }

    fileprivate func edgeSwipeOpenSettings() {
        guard let window = mainWindow ?? rootView?.window else { return }
        openSettingsPanel(in: window)
    }

    fileprivate func edgeSwipeCloseSettings() {
        closeSettingsPanel()
    }

    // MARK: - 布局

    fileprivate func layoutGlassSubviews(in root: NSView) {
        if let window = mainWindow ?? root.window {
            alignTrafficLightButtons(in: window)
        }
        let toolbarFrame = NSRect(
            x: 0,
            y: max(0, root.bounds.height - GlassSkinConstants.toolbarHeight),
            width: root.bounds.width,
            height: GlassSkinConstants.toolbarHeight
        )
        toolbarView?.frame = toolbarFrame

        if let background = root.subviews.first(where: { $0.identifier?.rawValue == "glass.root.material" }) {
            background.frame = root.bounds
        }

        // 内容容器（非无限画布，充满功能栏下方区域）
        if let content = root.subviews.first(where: { $0.identifier?.rawValue == "glass.content.view" }) {
            content.frame = NSRect(
                x: 0,
                y: 0,
                width: root.bounds.width,
                height: max(0, root.bounds.height - GlassSkinConstants.toolbarHeight)
            )
            content.appearance = GlassThemeHelper.nsAppearance()
            content.layer?.backgroundColor = GlassThemeHelper.contentBackgroundColor()
        }

        // 边缘手势
        edgeGestureView?.frame = NSRect(
            x: max(0, root.bounds.width - GlassSkinConstants.edgeGestureWidth),
            y: 0,
            width: GlassSkinConstants.edgeGestureWidth,
            height: max(0, root.bounds.height - GlassSkinConstants.toolbarHeight)
        )

        // 设置面板自适应布局
        if let panel = settingsPanelView {
            let cards = buildModuleCards()
            let contentWidth = calculatePanelContentWidth(for: cards,
                                                          containerHeight: max(0, root.bounds.height - GlassSkinConstants.toolbarHeight))
            let panelWidth = min(
                GlassSkinConstants.panelMaxWidth,
                max(GlassSkinConstants.panelMinWidth, min(contentWidth, root.bounds.width * GlassSkinConstants.panelWidthRatio))
            )
            let contentHeight = max(0, root.bounds.height - GlassSkinConstants.toolbarHeight)
            panel.frame = NSRect(
                x: max(0, root.bounds.width - panelWidth),
                y: 0,
                width: panelWidth,
                height: contentHeight
            )
        }
    }

    // MARK: - 私有工具

    private func alignTrafficLightButtons(in window: NSWindow) {
        guard
            let close = window.standardWindowButton(.closeButton),
            let mini = window.standardWindowButton(.miniaturizeButton),
            let zoom = window.standardWindowButton(.zoomButton)
        else { return }

        let x = GlassSkinConstants.leftPadding
        let spacing = GlassSkinConstants.buttonSpacing
        let y = GlassSkinConstants.trafficLightTopMargin

        close.setFrameOrigin(NSPoint(x: x, y: y))
        mini.setFrameOrigin(NSPoint(x: x + spacing, y: y))
        zoom.setFrameOrigin(NSPoint(x: x + spacing * 2, y: y))
    }

    private func removeDuplicateGlassChrome(from view: NSView) {
        let ownedIdentifiers: Set<String> = [
            "glass.root.material",
            "glass.toolbar",
            "glass.edgeGesture",
            "glass.content.view"
        ]
        var seen: Set<String> = []
        for subview in view.subviews {
            guard let raw = subview.identifier?.rawValue, ownedIdentifiers.contains(raw) else { continue }
            if seen.contains(raw) {
                subview.removeFromSuperview()
            } else {
                seen.insert(raw)
            }
        }
    }

    private func installResizeObserverIfNeeded(for view: NSView) {
        guard resizeObserver == nil, let window = mainWindow ?? view.window else { return }
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self, weak view] _ in
            guard let self, let view else { return }
            self.layoutGlassSubviews(in: view)
        }
    }

    private func ensureBrightGlassBackground(in view: NSView) {
        if view.subviews.contains(where: { $0.identifier?.rawValue == "glass.root.material" }) { return }

        let material = NSVisualEffectView(frame: view.bounds)
        material.identifier = NSUserInterfaceItemIdentifier("glass.root.material")
        material.autoresizingMask = [.width, .height]
        material.material = .underWindowBackground
        material.blendingMode = .behindWindow
        material.state = .active
        material.appearance = GlassThemeHelper.nsAppearance()
        material.wantsLayer = true
        material.layer?.cornerRadius = GlassSkinConstants.windowCornerRadius
        material.layer?.masksToBounds = true
        material.layer?.backgroundColor = GlassThemeHelper.contentBackgroundColor()
        view.addSubview(material, positioned: .below, relativeTo: nil)
    }

    private func ensureToolbar(in view: NSView) {
        if toolbarView != nil { return }
        let toolbar = GlassToolbarView(
            frame: NSRect(
                x: 0,
                y: max(0, view.bounds.height - GlassSkinConstants.toolbarHeight),
                width: view.bounds.width,
                height: GlassSkinConstants.toolbarHeight
            )
        )
        toolbar.identifier = NSUserInterfaceItemIdentifier("glass.toolbar")
        toolbar.autoresizingMask = [.width, .minYMargin]
        toolbar.onSettings = { [weak self] in self?.toggleSettingsPanel() }
        view.addSubview(toolbar, positioned: .above, relativeTo: nil)
        toolbarView = toolbar
    }

    /// 内容容器（非无限画布）
    private func ensureContentView(in view: NSView) {
        if view.subviews.contains(where: { $0.identifier?.rawValue == "glass.content.view" }) { return }
        let content = GlassContentView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: view.bounds.width,
                height: max(0, view.bounds.height - GlassSkinConstants.toolbarHeight)
            )
        )
        content.identifier = NSUserInterfaceItemIdentifier("glass.content.view")
        content.autoresizingMask = [.width, .height]
        content.layer?.backgroundColor = GlassThemeHelper.contentBackgroundColor()
        if let background = view.subviews.first(where: { $0.identifier?.rawValue == "glass.root.material" }) {
            view.addSubview(content, positioned: .above, relativeTo: background)
        } else {
            view.addSubview(content, positioned: .below, relativeTo: nil)
        }
    }

    private func ensureEdgeGesture(in view: NSView) {
        if edgeGestureView != nil { return }
        let edge = GlassEdgeGestureView(
            frame: NSRect(
                x: max(0, view.bounds.width - GlassSkinConstants.edgeGestureWidth),
                y: 0,
                width: GlassSkinConstants.edgeGestureWidth,
                height: max(0, view.bounds.height - GlassSkinConstants.toolbarHeight)
            )
        )
        edge.identifier = NSUserInterfaceItemIdentifier("glass.edgeGesture")
        edge.autoresizingMask = [.minXMargin, .height]
        edge.onSwipeLeft = { [weak self] in self?.edgeSwipeOpenSettings() }
        edge.onSwipeRight = { [weak self] in self?.edgeSwipeCloseSettings() }
        view.addSubview(edge, positioned: .above, relativeTo: nil)
        edgeGestureView = edge
    }

    /// 计算卡片水平堆叠所需的内容宽度
    private func calculatePanelContentWidth(for cards: [GlassModuleCardModel], containerHeight: CGFloat) -> CGFloat {
        guard !cards.isEmpty else { return GlassSkinConstants.panelMinWidth }
        let rowCount = max(1, cards.count)
        // 水平堆叠：每张卡片偏移 cardStackOffset，加上卡片本身宽度
        let contentWidth = GlassSkinConstants.cardWidth + CGFloat(rowCount - 1) * GlassSkinConstants.cardStackOffset + GlassSkinConstants.panelScrollViewLeftMargin * 2
        return contentWidth
    }

    private func buildModuleCards() -> [GlassModuleCardModel] {
        var cards = [
            GlassModuleCardModel(id: "theme", title: "主题设置", subtitle: "玻璃、浅色、深色与辅助主题", symbolName: "paintpalette.fill", accent: NSColor.systemBlue),
            GlassModuleCardModel(id: "kline", title: "K线模块", subtitle: "开关打开后固定显示在 UI 工作区，并自动恢复位置排列", symbolName: "chart.xyaxis.line", accent: NSColor.systemGreen, isSwitchable: true, isEnabled: KXUI08Entry.isPanelEnabled()),
            GlassModuleCardModel(id: "indicator", title: "指标模块", subtitle: "技术指标、参数与模板", symbolName: "waveform.path.ecg", accent: NSColor.systemPurple),
            GlassModuleCardModel(id: "backtest", title: "回测模块", subtitle: "策略、样本与绩效分析", symbolName: "arrow.triangle.2.circlepath", accent: NSColor.systemTeal),
            GlassModuleCardModel(id: "pattern", title: "K线形态识别模块", subtitle: "形态库、信号与识别规则", symbolName: "sparkles", accent: NSColor.systemPink)
        ]

        let knownTitles = Set(cards.map { $0.title })
        let dynamicCards = KJModuleRegistry.shared.allModuleNames
            .filter { isBusinessModuleName($0) }
            .filter { !knownTitles.contains(displayName(forBusinessModule: $0)) }
            .sorted()
            .map { moduleName in
                GlassModuleCardModel(
                    id: moduleName,
                    title: displayName(forBusinessModule: moduleName),
                    subtitle: "已接入框架的业务模块",
                    symbolName: "square.grid.2x2.fill",
                    accent: NSColor.controlAccentColor,
                    isSwitchable: false,
                    isEnabled: false
                )
            }
        cards.append(contentsOf: dynamicCards)
        return cards
    }

    private func isBusinessModuleName(_ name: String) -> Bool {
        let blockedPrefixes = ["KJ-", "UI-", "UI_", "Skin-", "framework", "App"]
        if blockedPrefixes.contains(where: { name.hasPrefix($0) }) { return false }
        let lowercased = name.lowercased()
        return ["kline", "kl", "indicator", "backtest", "pattern", "module", "模块"].contains { lowercased.contains($0) || name.contains($0) }
    }

    private func displayName(forBusinessModule name: String) -> String {
        if name.localizedCaseInsensitiveContains("kline") || name.contains("K线") || name.hasPrefix("KL") { return "K线模块" }
        if name.localizedCaseInsensitiveContains("indicator") || name.contains("指标") { return "指标模块" }
        if name.localizedCaseInsensitiveContains("backtest") || name.contains("回测") { return "回测模块" }
        if name.localizedCaseInsensitiveContains("pattern") || name.contains("形态") { return "K线形态识别模块" }
        return name
    }
}

// MARK: - 卡片数据模型

private struct GlassModuleCardModel: Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let accent: NSColor
    var isSwitchable: Bool = false
    var isEnabled: Bool = false

    static func == (lhs: GlassModuleCardModel, rhs: GlassModuleCardModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 顶部功能栏

private final class GlassToolbarView: NSView {
    var onSettings: (() -> Void)?

    private let materialView = NSVisualEffectView()
    private let darkBaseView = NSView()
    private let titleLabel = NSTextField(labelWithString: "仙人指路")
    private let settingsButton = GlassSettingsButton(frame: NSRect(x: 0, y: 0, width: GlassSkinConstants.settingsButtonSize, height: GlassSkinConstants.settingsButtonSize))
    private let separator = CALayer()
    private let topSheen = CAGradientLayer()

    var settingsButtonFrameInToolbar: NSRect { settingsButton.frame }

    private enum TrafficLightHit {
        case close
        case miniaturize
        case zoom
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var allowsVibrancy: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = GlassSkinConstants.windowCornerRadius
        layer?.masksToBounds = true
        if #available(macOS 10.13, *) {
            layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }

        // 功能栏 NSVisualEffectView
        materialView.frame = bounds
        materialView.autoresizingMask = [.width, .height]
        materialView.material = .headerView
        materialView.blendingMode = .withinWindow
        materialView.state = .active
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = GlassSkinConstants.windowCornerRadius
        materialView.layer?.masksToBounds = true
        if #available(macOS 10.13, *) {
            materialView.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.layer?.backgroundColor = GlassThemeHelper.toolbarBackgroundColor()
        addSubview(materialView)

        darkBaseView.wantsLayer = true
        darkBaseView.layer?.backgroundColor = NSColor.clear.cgColor
        darkBaseView.autoresizingMask = [.width, .height]
        addSubview(darkBaseView)

        // 标题
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .left
        titleLabel.frame = NSRect(x: 82, y: 17, width: 220, height: 22)
        titleLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        addSubview(titleLabel)

        // 齿轮按钮
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked(_:))
        addSubview(settingsButton)

        // 顶部高光渐变
        topSheen.colors = [
            NSColor.white.withAlphaComponent(GlassSkinConstants.sheenOpacity1).cgColor,
            NSColor.white.withAlphaComponent(GlassSkinConstants.sheenOpacity2).cgColor,
            NSColor.white.withAlphaComponent(GlassSkinConstants.sheenOpacity3).cgColor
        ]
        topSheen.startPoint = CGPoint(x: 0, y: 1)
        topSheen.endPoint = CGPoint(x: 1, y: 0)
        wantsLayer = true
        layer?.addSublayer(topSheen)

        // 底部分割线
        separator.backgroundColor = GlassThemeHelper.separatorColor()
        layer?.addSublayer(separator)
    }

    fileprivate func refreshThemeAppearance() {
        appearance = GlassThemeHelper.nsAppearance()
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.layer?.backgroundColor = GlassThemeHelper.toolbarBackgroundColor()
        darkBaseView.layer?.backgroundColor = GlassThemeHelper.isDarkAppearance()
            ? GlassThemeHelper.toolbarBackgroundColor()
            : NSColor.clear.cgColor
        layer?.backgroundColor = GlassThemeHelper.toolbarBackgroundColor()
        titleLabel.textColor = GlassThemeHelper.isDarkAppearance() ? .white.withAlphaComponent(0.92) : .labelColor
        separator.backgroundColor = GlassThemeHelper.separatorColor()
        needsDisplay = true
        needsLayout = true
    }

    override func layout() {
        super.layout()
        materialView.frame = bounds
        darkBaseView.frame = bounds

        // 根据主题更新颜色：深色时不能只依赖 NSVisualEffectView，它会把纯黑洗成灰；上层黑色玻璃底直接保证真黑。
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.layer?.backgroundColor = GlassThemeHelper.toolbarBackgroundColor()
        darkBaseView.layer?.backgroundColor = GlassThemeHelper.isDarkAppearance()
            ? GlassThemeHelper.toolbarBackgroundColor()
            : NSColor.clear.cgColor
        titleLabel.textColor = GlassThemeHelper.isDarkAppearance() ? .white.withAlphaComponent(0.92) : .labelColor
        if GlassThemeHelper.isDarkAppearance() {
            topSheen.colors = [
                NSColor.white.withAlphaComponent(GlassSkinConstants.darkToolbarSheenOpacity1).cgColor,
                NSColor.white.withAlphaComponent(GlassSkinConstants.darkToolbarSheenOpacity2).cgColor,
                NSColor.white.withAlphaComponent(GlassSkinConstants.darkToolbarSheenOpacity3).cgColor
            ]
        } else {
            topSheen.colors = [
                NSColor.white.withAlphaComponent(GlassSkinConstants.sheenOpacity1).cgColor,
                NSColor.white.withAlphaComponent(GlassSkinConstants.sheenOpacity2).cgColor,
                NSColor.white.withAlphaComponent(GlassSkinConstants.sheenOpacity3).cgColor
            ]
        }
        separator.backgroundColor = GlassThemeHelper.separatorColor()

        let labelY = floor((bounds.height - 22) / 2)
        titleLabel.frame = NSRect(x: 82, y: labelY, width: 220, height: 22)

        let btnY = floor((bounds.height - GlassSkinConstants.settingsButtonSize) / 2)
        settingsButton.frame = NSRect(
            x: max(10, bounds.width - GlassSkinConstants.settingsButtonSize - GlassSkinConstants.settingsButtonRightMargin),
            y: btnY,
            width: GlassSkinConstants.settingsButtonSize,
            height: GlassSkinConstants.settingsButtonSize
        )

        topSheen.frame = CGRect(
            x: 0,
            y: max(0, bounds.height - GlassSkinConstants.sheenHeight),
            width: bounds.width,
            height: GlassSkinConstants.sheenHeight
        )
        separator.frame = CGRect(x: 0, y: 0, width: bounds.width, height: GlassSkinConstants.separatorHeight)
    }

    @objc private func settingsClicked(_ sender: GlassSettingsButton) {
        sender.performClickBounce()
        onSettings?()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // 系统红绿灯区域被自绘功能栏覆盖时，必须主动转发为窗口动作。
        // 否则点击红/黄/绿会被功能栏当成拖动事件吃掉，看起来像按钮没有连接功能。
        if let hit = trafficLightHit(at: point) {
            performTrafficLightAction(hit)
            return
        }

        // 按钮区域保留按钮点击，不触发窗口拖动。
        if settingsButton.frame.contains(point) {
            super.mouseDown(with: event)
            return
        }

        // 只有按住功能栏空白区域才允许移动整个 UI 窗口。
        window?.performDrag(with: event)
    }

    private func trafficLightHit(at point: NSPoint) -> TrafficLightHit? {
        guard point.x >= 0, point.x <= GlassSkinConstants.leftPadding + GlassSkinConstants.buttonSpacing * 2 + 18 else {
            return nil
        }

        let buttonY = bounds.height + GlassSkinConstants.trafficLightTopMargin
        let centerY = buttonY + 7
        let toleranceY: CGFloat = 16
        guard abs(point.y - centerY) <= toleranceY else { return nil }

        let centers: [(TrafficLightHit, CGFloat)] = [
            (.close, GlassSkinConstants.leftPadding + 7),
            (.miniaturize, GlassSkinConstants.leftPadding + GlassSkinConstants.buttonSpacing + 7),
            (.zoom, GlassSkinConstants.leftPadding + GlassSkinConstants.buttonSpacing * 2 + 7)
        ]
        return centers.first { _, centerX in abs(point.x - centerX) <= 10 }?.0
    }

    private func performTrafficLightAction(_ hit: TrafficLightHit) {
        guard let window else { return }
        switch hit {
        case .close:
            window.performClose(nil)
        case .miniaturize:
            window.performMiniaturize(nil)
        case .zoom:
            window.performZoom(nil)
        }
    }
}

// MARK: - 玻璃设置按钮（圆形齿轮）

private final class GlassSettingsButton: NSButton {
    private var tracking: NSTrackingArea?
    private let highlight = CAGradientLayer()
    private let rim = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var allowsVibrancy: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setup() {
        title = ""
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        let size = min(bounds.width, bounds.height)
        layer?.cornerRadius = size / 2
        layer?.masksToBounds = false

        // 背景颜色根据主题动态设置
        layer?.backgroundColor = GlassThemeHelper.settingsButtonBackgroundColor()

        // 边框
        layer?.borderWidth = GlassSkinConstants.borderWidth
        if GlassThemeHelper.isDarkAppearance() {
            layer?.borderColor = NSColor(calibratedWhite: 0.60, alpha: GlassSkinConstants.borderOpacity).cgColor
        } else {
            layer?.borderColor = NSColor.white.withAlphaComponent(GlassSkinConstants.borderOpacity).cgColor
        }

        // 阴影
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = GlassSkinConstants.shadowOpacity
        layer?.shadowRadius = GlassSkinConstants.shadowRadius
        layer?.shadowOffset = GlassSkinConstants.shadowOffset

        // 内部高光
        highlight.colors = [
            NSColor.white.withAlphaComponent(0.82).cgColor,
            NSColor.white.withAlphaComponent(0.18).cgColor,
            NSColor.white.withAlphaComponent(0.04).cgColor
        ]
        highlight.startPoint = CGPoint(x: 0.2, y: 1)
        highlight.endPoint = CGPoint(x: 0.9, y: 0)
        highlight.cornerRadius = size / 2
        layer?.addSublayer(highlight)

        // 边缘光晕（rim）
        rim.fillColor = NSColor.clear.cgColor
        if GlassThemeHelper.isDarkAppearance() {
            rim.strokeColor = NSColor(calibratedWhite: 0.60, alpha: GlassSkinConstants.borderOpacity).cgColor
        } else {
            rim.strokeColor = NSColor.white.withAlphaComponent(GlassSkinConstants.borderOpacity).cgColor
        }
        rim.lineWidth = 1
        layer?.addSublayer(rim)

        // SF Symbol 齿轮
        let gearSize = GlassSkinConstants.gearIconSize
        if let image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "设置") {
            image.size = NSSize(width: gearSize, height: gearSize)
            self.image = image
            imageScaling = .scaleProportionallyDown
            imagePosition = .imageOnly
            if GlassThemeHelper.isDarkAppearance() {
                contentTintColor = NSColor(calibratedWhite: 0.85, alpha: 0.90)
            } else {
                contentTintColor = NSColor.labelColor.withAlphaComponent(0.78)
            }
        } else {
            title = "⚙"
            font = NSFont.systemFont(ofSize: 25, weight: .medium)
        }
    }

    override func layout() {
        super.layout()
        let size = min(bounds.width, bounds.height)
        layer?.cornerRadius = size / 2
        highlight.frame = bounds
        highlight.cornerRadius = size / 2
        rim.path = CGPath(ellipseIn: bounds.insetBy(dx: 0.75, dy: 0.75), transform: nil)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let next = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(next)
        tracking = next
    }

    override func mouseEntered(with event: NSEvent) {
        animateHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        animateHover(false)
    }

    override func mouseDown(with event: NSEvent) {
        let scale = GlassSkinConstants.buttonPressScale
        animateScale(to: scale, duration: GlassSkinConstants.buttonPressDuration)
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        performClickBounce()
        super.mouseUp(with: event)
    }

    func performClickBounce() {
        guard let layer else { return }
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = GlassSkinConstants.buttonPressScale
        spring.toValue = 1.0
        spring.mass = GlassSkinConstants.buttonBounceMass
        spring.stiffness = GlassSkinConstants.buttonBounceStiffness
        spring.damping = GlassSkinConstants.buttonBounceDamping
        spring.initialVelocity = GlassSkinConstants.buttonBounceVelocity
        spring.duration = spring.settlingDuration
        layer.add(spring, forKey: "glass.button.bounce")
        layer.transform = CATransform3DIdentity
    }

    private func animateHover(_ inside: Bool) {
        let scale = inside ? GlassSkinConstants.buttonHoverScale : 1.0
        let duration = inside ? GlassSkinConstants.buttonHoverDuration : GlassSkinConstants.buttonHoverExitDuration
        animateScale(to: scale, duration: duration)

        let shadowOp = inside ? GlassSkinConstants.shadowHoverOpacity : GlassSkinConstants.shadowOpacity
        animateLayerValue(keyPath: "shadowOpacity", to: CGFloat(shadowOp), duration: duration)
        animateLayerValue(keyPath: "shadowRadius", to: inside ? GlassSkinConstants.shadowHoverRadius : GlassSkinConstants.shadowRadius, duration: duration)

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        if inside {
            layer?.backgroundColor = GlassThemeHelper.settingsButtonHoverBackgroundColor()
        } else {
            layer?.backgroundColor = GlassThemeHelper.settingsButtonBackgroundColor()
        }
        CATransaction.commit()
    }

    private func animateScale(to value: CGFloat, duration: CFTimeInterval) {
        guard let layer else { return }
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = layer.presentation()?.value(forKeyPath: "transform.scale") ?? 1
        animation.toValue = value
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: "glass.button.scale")
        layer.transform = CATransform3DMakeScale(value, value, 1)
    }

    private func animateLayerValue(keyPath: String, to value: CGFloat, duration: CFTimeInterval) {
        guard let layer else { return }
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.toValue = value
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: "glass.button.\(keyPath)")
        layer.setValue(value, forKeyPath: keyPath)
    }
}

// MARK: - 设置面板
// 包含：GlassSettingsPanelView（面板）+ GlassModuleCardView（卡片）

import Foundation
import AppKit
import QuartzCore

// MARK: - 设置面板

private final class GlassSettingsPanelView: NSView {
    private let clippedContainer = NSView()
    private let materialView = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "设置")
    private let subtitleLabel = NSTextField(labelWithString: "模块一级菜单")
    private let scrollView = NSScrollView()
    private let cardHostView = FlippedView()
    private let borderLayer = CAShapeLayer()
    private let edgeLineLayer = CAGradientLayer()
    private let glowLayer = CAGradientLayer()
    private var cardViews: [GlassModuleCardView] = []
    private var tracking: NSTrackingArea?
    private var hoveredCardIndex: Int?
    private var expandedThemeOverlay: GlassModuleCardView?
    private var expandedThemeClickMonitor: Any?
    var onKlineRequested: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        removeExpandedThemeClickMonitor()
    }

    override var allowsVibrancy: Bool { true }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = GlassSkinConstants.panelShadowOpacity
        layer?.shadowRadius = GlassSkinConstants.panelShadowRadius
        layer?.shadowOffset = GlassSkinConstants.panelShadowOffset

        // 外层只负责阴影；内层负责圆角裁切，避免圆角处露出白色直角底板
        clippedContainer.frame = bounds
        clippedContainer.autoresizingMask = [.width, .height]
        clippedContainer.wantsLayer = true
        clippedContainer.layer?.cornerRadius = GlassSkinConstants.panelCornerRadius
        clippedContainer.layer?.masksToBounds = true
        clippedContainer.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(clippedContainer)

        // NSVisualEffectView
        materialView.frame = clippedContainer.bounds
        materialView.autoresizingMask = [.width, .height]
        materialView.material = .popover
        materialView.blendingMode = .withinWindow
        materialView.state = .active
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = GlassSkinConstants.panelCornerRadius
        materialView.layer?.masksToBounds = true
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.layer?.backgroundColor = GlassThemeHelper.panelBackgroundColor()
        clippedContainer.addSubview(materialView)

        // 顶部高光
        glowLayer.colors = [
            NSColor.white.withAlphaComponent(0.95).cgColor,
            NSColor.white.withAlphaComponent(0.28).cgColor,
            NSColor.white.withAlphaComponent(0.05).cgColor
        ]
        glowLayer.startPoint = CGPoint(x: 0, y: 1)
        glowLayer.endPoint = CGPoint(x: 1, y: 0)
        glowLayer.cornerRadius = GlassSkinConstants.panelCornerRadius
        clippedContainer.layer?.addSublayer(glowLayer)

        // 边框
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.strokeColor = GlassThemeHelper.panelBorderColor()
        borderLayer.lineWidth = GlassSkinConstants.panelBorderWidth
        layer?.addSublayer(borderLayer)

        // 左侧边缘高光线
        edgeLineLayer.colors = [
            NSColor.white.withAlphaComponent(0.98).cgColor,
            NSColor(calibratedWhite: 0.58, alpha: 0.58).cgColor,
            NSColor.white.withAlphaComponent(0.40).cgColor
        ]
        edgeLineLayer.startPoint = CGPoint(x: 0.5, y: 1)
        edgeLineLayer.endPoint = CGPoint(x: 0.5, y: 0)
        clippedContainer.layer?.addSublayer(edgeLineLayer)

        // 标题
        titleLabel.font = NSFont.systemFont(ofSize: GlassSkinConstants.panelTitleFontSize, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.drawsBackground = false
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        clippedContainer.addSubview(titleLabel)

        // 副标题
        subtitleLabel.font = NSFont.systemFont(ofSize: GlassSkinConstants.panelSubtitleFontSize, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.drawsBackground = false
        subtitleLabel.isBezeled = false
        subtitleLabel.isEditable = false
        clippedContainer.addSubview(subtitleLabel)

        // 滚动区域（水平滚动，宽度自适应）
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.scrollerStyle = .overlay
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.clear.cgColor
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layer?.backgroundColor = NSColor.clear.cgColor

        cardHostView.wantsLayer = true
        cardHostView.layer?.backgroundColor = NSColor.clear.cgColor
        scrollView.documentView = cardHostView
        clippedContainer.addSubview(scrollView)
    }

    func setCards(_ items: [GlassModuleCardModel]) {
        glassSkinPanelLogger.info("设置面板卡片初始化 count=\(items.count, privacy: .public)")
        cardViews.forEach { $0.removeFromSuperview() }
        cardViews = items.map { GlassModuleCardView(model: $0) }
        for card in cardViews { cardHostView.addSubview(card) }
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    fileprivate func refreshThemeAppearance() {
        appearance = GlassThemeHelper.nsAppearance()
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.layer?.backgroundColor = GlassThemeHelper.panelBackgroundColor()
        clippedContainer.layer?.borderColor = GlassThemeHelper.panelBorderColor()
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        clippedContainer.frame = bounds
        clippedContainer.layer?.cornerRadius = GlassSkinConstants.panelCornerRadius
        clippedContainer.layer?.masksToBounds = true
        materialView.frame = clippedContainer.bounds
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.layer?.backgroundColor = GlassThemeHelper.panelBackgroundColor()
        glowLayer.frame = clippedContainer.bounds

        let inset: CGFloat = 0.8
        borderLayer.path = CGPath(roundedRect: bounds.insetBy(dx: inset, dy: inset),
                                  cornerWidth: GlassSkinConstants.panelCornerRadius,
                                  cornerHeight: GlassSkinConstants.panelCornerRadius,
                                  transform: nil)
        borderLayer.strokeColor = GlassThemeHelper.panelBorderColor()

        edgeLineLayer.frame = CGRect(x: 0, y: 12, width: 2, height: max(0, bounds.height - 24))

        titleLabel.frame = NSRect(
            x: GlassSkinConstants.panelTitleLeftMargin,
            y: bounds.height - 58,
            width: bounds.width - 56,
            height: 30
        )
        subtitleLabel.frame = NSRect(
            x: GlassSkinConstants.panelSubtitleLeftMargin,
            y: bounds.height - 78,
            width: bounds.width - 58,
            height: 18
        )

        let scrollFrame = NSRect(
            x: GlassSkinConstants.panelScrollViewLeftMargin,
            y: GlassSkinConstants.panelScrollViewBottomMargin,
            width: max(60, bounds.width - GlassSkinConstants.panelScrollViewLeftMargin * 2),
            height: max(GlassSkinConstants.cardHeight + 24,
                        bounds.height - GlassSkinConstants.panelScrollViewTopMargin - GlassSkinConstants.panelScrollViewBottomMargin)
        )
        scrollView.frame = scrollFrame

        layoutCardsHorizontalStack()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let next = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(next)
        tracking = next
    }

    override func mouseMoved(with event: NSEvent) {
        // 放大主题面板打开后，一级卡片系统冻结；鼠标事件不再穿透到底下卡片。
        if expandedThemeOverlay != nil { return }

        let point = cardHostView.convert(event.locationInWindow, from: nil)
        guard cardHostView.bounds.intersects(NSRect(origin: point, size: NSSize(width: 1, height: 1))) else {
            resetCardsHoverIfNeeded()
            return
        }

        // 命中判断必须使用稳定的 baseFrame，不能使用正在跟随鼠标动画变化的 frame，避免穿透到底层卡片。
        // 如果已经选中某张卡，只要鼠标还在这张卡的稳定命中区内，就锁定当前卡片。
        if let lockedIndex = hoveredCardIndex, cardViews.indices.contains(lockedIndex) {
            let lockedCard = cardViews[lockedIndex]
            if stableHitFrame(for: lockedCard).contains(point) {
                applyMoveHover(to: lockedCard, cardIndex: lockedIndex, mousePoint: point)
                return
            }
        }

        // 从视觉最上层往下命中，但命中区使用 baseFrame，避免 hover 位移导致误命中下面的卡片。
        for (index, card) in cardViews.enumerated().reversed() {
            if stableHitFrame(for: card).contains(point) {
                if hoveredCardIndex != index {
                    let previousIndex = hoveredCardIndex
                    hoveredCardIndex = index
                    if let previousIndex, cardViews.indices.contains(previousIndex) {
                        let previousCard = cardViews[previousIndex]
                        previousCard.animateToBaseWithSpring()
                        previousCard.layer?.zPosition = CGFloat(previousCard.baseZIndex)
                    }
                    glassSkinPanelLogger.info("卡片 hover 切换 index=\(index, privacy: .public) id=\(card.model.id, privacy: .public) title=\(card.model.title, privacy: .public)")
                    GlassSoundManager.shared.playHoverTick()
                }
                // 鼠标移动阶段：只让当前卡片跟随，不重排其他卡片
                applyMoveHover(to: card, cardIndex: index, mousePoint: point)
                return
            }
        }
        resetCardsHoverIfNeeded()
    }

    override func mouseExited(with event: NSEvent) {
        resetCardsHoverIfNeeded()
    }

    override func mouseDown(with event: NSEvent) {
        if expandedThemeOverlay != nil {
            glassSkinPanelLogger.info("一级卡片点击忽略：主题放大 overlay 已打开")
            return
        }

        let point = cardHostView.convert(event.locationInWindow, from: nil)
        glassSkinPanelLogger.info("一级卡片 mouseDown point=(\(point.x, privacy: .public), \(point.y, privacy: .public)) hovered=\(self.hoveredCardIndex ?? -1, privacy: .public)")

        // 点击必须优先使用当前 hover 锁定的卡片，避免重叠卡片重新命中导致“第一次点主题不放大”。
        if let lockedIndex = hoveredCardIndex,
           cardViews.indices.contains(lockedIndex) {
            let lockedCard = cardViews[lockedIndex]
            if stableHitFrame(for: lockedCard).contains(point) {
                glassSkinPanelLogger.info("点击命中 hover 锁定卡片 index=\(lockedIndex, privacy: .public) id=\(lockedCard.model.id, privacy: .public) title=\(lockedCard.model.title, privacy: .public)")
                activateCard(lockedCard, index: lockedIndex)
                return
            }
        }

        // 如果没有 hover 锁定，再按当前视觉层级命中；不要只按数组顺序，避免重叠穿透。
        let ordered = cardViews.enumerated().sorted { lhs, rhs in
            let lz = lhs.element.layer?.zPosition ?? CGFloat(lhs.offset)
            let rz = rhs.element.layer?.zPosition ?? CGFloat(rhs.offset)
            return lz > rz
        }
        for (index, card) in ordered {
            if stableHitFrame(for: card).contains(point) {
                glassSkinPanelLogger.info("点击命中 zPosition 排序卡片 index=\(index, privacy: .public) id=\(card.model.id, privacy: .public) title=\(card.model.title, privacy: .public)")
                activateCard(card, index: index)
                return
            }
        }
        glassSkinPanelLogger.warning("一级卡片 mouseDown 未命中任何卡片 point=(\(point.x, privacy: .public), \(point.y, privacy: .public))")
        super.mouseDown(with: event)
    }

    func animateIn(to targetFrame: NSRect, completion: (() -> Void)? = nil) {
        // 直接动画 frame，而不是动画 layer.position。
        // 这样起点就是当前 frame（窗口内容区右边缘外侧），终点就是最终静止 frame，路径不会从右上角冒出来。
        layoutSubtreeIfNeeded()
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = GlassSkinConstants.panelSlideInDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.84, 0.22, 1.0)
            animator().frame = targetFrame
            animator().alphaValue = 1
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.frame = targetFrame
            self.alphaValue = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + GlassSkinConstants.cardInitialCurveApplyDelay) { [weak self] in
                self?.applyInitialCurveOnly()
            }
            completion?()
        }
    }

    func animateOut(to endFrame: NSRect) {
        // 与弹入保持一致：直接动画 frame，从当前位置向窗口右边缘收回。
        // 不再动画 layer.position，避免右上角残影/斜向收回。
        NSAnimationContext.runAnimationGroup { context in
            context.duration = GlassSkinConstants.panelSlideOutDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.84, 0.22, 1.0)
            animator().frame = endFrame
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.frame = endFrame
            self?.removeFromSuperview()
        }
    }

    // MARK: - 卡片水平堆叠布局

    func layoutCardsHorizontalStack() {
        let count = cardViews.count
        guard count > 0 else { return }
        let scrollBounds = scrollView.bounds

        let cardW = GlassSkinConstants.cardWidth
        let cardH = GlassSkinConstants.cardHeight
        let centerY = scrollBounds.midY - cardH / 2
        let startX: CGFloat = 20

        // 每张卡片水平偏移 + 卡片宽度 + 右边距 = 内容总宽度
        let totalWidth = startX + cardW + CGFloat(count - 1) * GlassSkinConstants.cardStackOffset + 80
        cardHostView.frame = NSRect(x: 0, y: 0, width: totalWidth, height: scrollBounds.height)

        for (index, card) in cardViews.enumerated() {
            let x = startX + CGFloat(index) * GlassSkinConstants.cardStackOffset
            // 微错落：偶数卡片稍高一点，奇数稍低一点
            let y = centerY + (CGFloat(index % 2) - 0.5) * 6
            let rotation = (CGFloat(index) - CGFloat(count) / 2.0) * GlassSkinConstants.cardStackRotation
            card.baseFrame = NSRect(x: x, y: y, width: cardW, height: cardH)
            card.baseRotation = rotation
            card.baseZIndex = index
            card.resetToBase(animated: false)
        }

        // 初始滚动到最左边
        scrollView.contentView.scroll(to: .zero)
    }

    func applyInitialCardState(animated: Bool = false) {
        layoutCardsHorizontalStack()
        for card in cardViews {
            card.resetToBase(animated: animated)
        }
    }

    func applyInitialCurveOnly() {
        for card in cardViews {
            card.animateBaseCurveOnly()
        }
    }

    // MARK: - 入场动画

    private func animateCardsIn() {
        for (index, card) in cardViews.enumerated() {
            card.alphaValue = 0
            let target = card.baseFrame
            card.frame = target.offsetBy(dx: 0, dy: GlassSkinConstants.cardEntryStartOffset)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * GlassSkinConstants.cardEntryDelay) {
                card.alphaValue = 1
                card.animateToBaseWithSpring()
            }
        }
    }

    // MARK: - 鼠标悬停处理

    private func stableHitFrame(for card: GlassModuleCardView) -> NSRect {
        // 稳定命中区基于 baseFrame，而不是当前 frame；给一点容错边距，避免边缘抖动。
        return card.baseFrame.insetBy(dx: -8, dy: -8)
    }

    private func showPatternExpandedOverlay(from sourceCard: GlassModuleCardView) {
        expandedThemeOverlay?.removeFromSuperview()
        let sourceFrameInPanel = clippedContainer.convert(sourceCard.frame, from: cardHostView)
        let targetWidth = max(GlassSkinConstants.cardWidth,
                              clippedContainer.bounds.width - GlassSkinConstants.themeExpandedCardHorizontalMargin * 2)
        let maxTargetHeight = max(GlassSkinConstants.cardHeight,
                                  clippedContainer.bounds.height * GlassSkinConstants.themeExpandedCardMaxHeightRatio)
        let naturalTargetHeight = targetWidth * GlassSkinConstants.cardHeight / GlassSkinConstants.cardWidth
        let targetHeight = min(maxTargetHeight,
                               max(GlassSkinConstants.cardHeight, naturalTargetHeight))
        let targetFrame = NSRect(
            x: GlassSkinConstants.themeExpandedCardHorizontalMargin,
            y: max(GlassSkinConstants.themeExpandedCardVerticalMargin,
                   (clippedContainer.bounds.height - targetHeight) / 2 - 12),
            width: targetWidth,
            height: targetHeight
        )
        let overlay = GlassModuleCardView(model: sourceCard.model)
        overlay.frame = sourceFrameInPanel
        overlay.baseFrame = sourceFrameInPanel
        overlay.baseRotation = sourceCard.baseRotation
        overlay.baseZIndex = 999
        overlay.resetToBase(animated: false)
        overlay.layer?.zPosition = 220
        clippedContainer.addSubview(overlay, positioned: .above, relativeTo: nil)
        expandedThemeOverlay = overlay
        glassSkinPanelLogger.info("形态 overlay 已创建")
        installExpandedThemeClickMonitor()
        overlay.animateExpandedMenuFrame(to: targetFrame)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { [weak overlay] in
            overlay?.configurePatternMenuContents()
        }
    }

    private func showThemeExpandedOverlay(from sourceCard: GlassModuleCardView) {
        // 点击放大属于独立二级菜单程序：创建覆盖副本，不修改原卡片的 hover/排列状态。
        // 放大副本必须脱离 scrollView/cardHostView，放到 clippedContainer 顶层，避免被滚动区裁切和事件穿透。
        expandedThemeOverlay?.removeFromSuperview()

        let sourceFrameInPanel = clippedContainer.convert(sourceCard.frame, from: cardHostView)
        glassSkinPanelLogger.info("主题 overlay 创建请求 sourceFrame=(x:\(sourceFrameInPanel.origin.x, privacy: .public), y:\(sourceFrameInPanel.origin.y, privacy: .public), w:\(sourceFrameInPanel.width, privacy: .public), h:\(sourceFrameInPanel.height, privacy: .public))")
        let targetWidth = max(GlassSkinConstants.cardWidth,
                              clippedContainer.bounds.width - GlassSkinConstants.themeExpandedCardHorizontalMargin * 2)
        let maxTargetHeight = max(GlassSkinConstants.cardHeight,
                                  clippedContainer.bounds.height * GlassSkinConstants.themeExpandedCardMaxHeightRatio)
        let naturalTargetHeight = targetWidth * GlassSkinConstants.cardHeight / GlassSkinConstants.cardWidth
        let targetHeight = min(maxTargetHeight,
                               max(GlassSkinConstants.cardHeight, naturalTargetHeight))
        let targetFrame = NSRect(
            x: GlassSkinConstants.themeExpandedCardHorizontalMargin,
            y: max(GlassSkinConstants.themeExpandedCardVerticalMargin,
                   (clippedContainer.bounds.height - targetHeight) / 2 - 12),
            width: targetWidth,
            height: targetHeight
        )

        let overlay = GlassModuleCardView(model: sourceCard.model)
        overlay.frame = sourceFrameInPanel
        overlay.baseFrame = sourceFrameInPanel
        overlay.baseRotation = sourceCard.baseRotation
        overlay.baseZIndex = 999
        overlay.resetToBase(animated: false)
        overlay.layer?.zPosition = 220
        clippedContainer.addSubview(overlay, positioned: .above, relativeTo: nil)
        expandedThemeOverlay = overlay
        glassSkinPanelLogger.info("主题 overlay 已创建 targetFrame=(x:\(targetFrame.origin.x, privacy: .public), y:\(targetFrame.origin.y, privacy: .public), w:\(targetFrame.width, privacy: .public), h:\(targetFrame.height, privacy: .public))")
        installExpandedThemeClickMonitor()
        overlay.animateExpandedMenuFrame(to: targetFrame)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { [weak overlay] in
            overlay?.configureThemeMenuContents()
        }
    }

    private func installExpandedThemeClickMonitor() {
        removeExpandedThemeClickMonitor()
        expandedThemeClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event -> NSEvent? in
            guard let self,
                  let overlay = self.expandedThemeOverlay,
                  let window = self.window,
                  event.window === window
            else { return event }

            let panelPoint = self.convert(event.locationInWindow, from: nil)
            let point = self.clippedContainer.convert(event.locationInWindow, from: nil)
            if overlay.frame.contains(point) {
                glassSkinPanelLogger.info("主题 overlay 内部点击 point=(\(point.x, privacy: .public), \(point.y, privacy: .public))")
                // 放大卡片内部：后续交给二级菜单自己的按钮/手势处理，不穿透到底层卡片。
                return event
            }

            if self.bounds.contains(panelPoint) {
                // 点放大卡片外、但仍在设置面板内部：只缩回二级卡片，并消费这次点击，避免触发底层一级卡片。
                glassSkinPanelLogger.info("主题 overlay 外部点击但仍在设置面板内，缩回 overlay point=(\(point.x, privacy: .public), \(point.y, privacy: .public))")
                self.collapseExpandedThemeOverlay()
                return nil
            }

            // 点设置面板外：先缩回二级卡片，但不消费事件，让外层“点击面板外关闭设置面板”逻辑继续执行。
            glassSkinPanelLogger.info("点击设置面板外，缩回主题 overlay 并放行给设置面板关闭逻辑 point=(\(point.x, privacy: .public), \(point.y, privacy: .public))")
            self.collapseExpandedThemeOverlay()
            return event
        }
    }

    private func removeExpandedThemeClickMonitor() {
        if let monitor = expandedThemeClickMonitor {
            NSEvent.removeMonitor(monitor)
            expandedThemeClickMonitor = nil
        }
    }

    private func collapseExpandedThemeOverlay() {
        guard let overlay = expandedThemeOverlay else {
            glassSkinPanelLogger.info("主题 overlay 缩回请求忽略：当前无 overlay")
            return
        }
        glassSkinPanelLogger.info("主题 overlay 开始缩回 frame=(x:\(overlay.frame.origin.x, privacy: .public), y:\(overlay.frame.origin.y, privacy: .public), w:\(overlay.frame.width, privacy: .public), h:\(overlay.frame.height, privacy: .public))")
        expandedThemeOverlay = nil
        removeExpandedThemeClickMonitor()
        overlay.animateToBaseWithSpring()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak overlay] in
            glassSkinPanelLogger.info("主题 overlay 已移除")
            overlay?.removeFromSuperview()
        }
    }

    private func activateCard(_ card: GlassModuleCardView, index: Int) {
        switch card.model.id {
        case "theme":
            hoveredCardIndex = index
            showThemeExpandedOverlay(from: card)
        case "pattern":
            hoveredCardIndex = index
            showPatternExpandedOverlay(from: card)
        case "kline":
            glassSkinPanelLogger.info("K线模块入口已点击，准备通过 KXUI08Entry.openPanel 加载 K线面板")
            onKlineRequested?()
        default:
            glassSkinPanelLogger.info("模块卡片已点击，但当前未绑定打开动作 id=\(card.model.id, privacy: .public) title=\(card.model.title, privacy: .public)")
        }
    }

    private func applyMoveHover(to hovered: GlassModuleCardView, cardIndex: Int, mousePoint: NSPoint) {
        let localPoint = cardHostView.convert(mousePoint, to: hovered)
        hovered.animateHover(mousePoint: localPoint)
        hovered.layer?.zPosition = 100

        // 最终交互：hover 只抽出当前卡片；不再做停留后飘动/重排。
    }

    private func resetCardsHoverIfNeeded() {
        // 鼠标刚进入设置面板但还没进入卡片时，不触发整组重置动画。
        // 只有已经 hover/停留过卡片，离开卡片区域后才恢复。
        guard hoveredCardIndex != nil else { return }
        resetCardsHover()
    }

    private func resetCardsHover() {
        let previousIndex = hoveredCardIndex
        hoveredCardIndex = nil

        // 鼠标移走时，只让当前抽出的那一张卡片插回去。
        // 其他卡片已经在基础堆叠位置，不再整组重新动画，避免整体下移再弹回。
        if let previousIndex, cardViews.indices.contains(previousIndex) {
            let card = cardViews[previousIndex]
            card.animateToBaseWithSpring()
            card.layer?.zPosition = CGFloat(card.baseZIndex)
        }
    }
}

// MARK: - 翻转坐标系视图

private class FlippedView: NSView {
    override var isFlipped: Bool { true }
    override var allowsVibrancy: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}

// MARK: - 主题选项按钮

private final class GlassThemeOptionButton: NSControl {
    let skinId: String
    var onSelect: ((String) -> Void)?
    var isMiniMode: Bool = false

    private let symbolView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let backgroundLayer = CALayer()
    private let borderLayer = CAShapeLayer()
    private let selectedGlowLayer = CALayer()
    private let checkView = NSImageView()
    private var isOptionSelected = false

    init(title: String, skinId: String, symbolName: String) {
        self.skinId = skinId
        super.init(frame: .zero)
        setup(title: title, symbolName: symbolName)
    }

    required init?(coder: NSCoder) {
        self.skinId = ""
        super.init(coder: coder)
        setup(title: "主题", symbolName: "paintpalette.fill")
    }

    override var allowsVibrancy: Bool { true }

    private func setup(title: String, symbolName: String) {
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.addSublayer(backgroundLayer)
        layer?.addSublayer(selectedGlowLayer)
        layer?.addSublayer(borderLayer)

        titleLabel.stringValue = title
        titleLabel.alignment = .center
        titleLabel.font = .systemFont(ofSize: GlassSkinConstants.themeOptionTitleFontSize, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.backgroundColor = .clear
        addSubview(titleLabel)

        symbolView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        symbolView.contentTintColor = .labelColor
        symbolView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(symbolView)

        checkView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "已选中")
        checkView.contentTintColor = GlassSkinConstants.themeOptionSelectedColor
        checkView.imageScaling = .scaleProportionallyUpOrDown
        checkView.isHidden = true
        addSubview(checkView)
    }

    override func layout() {
        super.layout()
        let radius = min(GlassSkinConstants.themeOptionButtonCornerRadius, bounds.height / 2)
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = radius
        backgroundLayer.backgroundColor = GlassThemeHelper.cardBackgroundColor()
        backgroundLayer.opacity = 0.92

        selectedGlowLayer.frame = bounds.insetBy(dx: -4, dy: -4)
        selectedGlowLayer.cornerRadius = radius + 4
        selectedGlowLayer.backgroundColor = GlassSkinConstants.themeOptionSelectedColor.cgColor
        selectedGlowLayer.opacity = isOptionSelected ? Float(GlassSkinConstants.themeOptionSelectedGlowOpacity) : 0

        borderLayer.frame = bounds
        borderLayer.path = CGPath(roundedRect: bounds.insetBy(dx: 1.0, dy: 1.0),
                                  cornerWidth: radius,
                                  cornerHeight: radius,
                                  transform: nil)
        borderLayer.fillColor = NSColor.clear.cgColor
        let normalBorder = GlassThemeHelper.isDarkAppearance()
            ? NSColor.white.withAlphaComponent(max(0.55, GlassSkinConstants.themeOptionNormalBorderAlpha))
            : NSColor(calibratedWhite: 0.30, alpha: max(0.46, GlassSkinConstants.themeOptionNormalBorderAlpha))
        borderLayer.strokeColor = (isOptionSelected
                                   ? GlassSkinConstants.themeOptionSelectedColor
                                   : normalBorder).cgColor
        borderLayer.lineWidth = isOptionSelected ? GlassSkinConstants.themeOptionSelectedBorderWidth : GlassSkinConstants.themeOptionNormalBorderWidth

        if isMiniMode {
            let iconSize = min(22, bounds.height * 0.42)
            symbolView.frame = NSRect(x: (bounds.width - iconSize) / 2, y: (bounds.height - iconSize) / 2 + 3, width: iconSize, height: iconSize)
            checkView.frame = NSRect(x: bounds.width - 14, y: bounds.height - 14, width: 10, height: 10)
            titleLabel.isHidden = bounds.height < 30
            if !titleLabel.isHidden {
                titleLabel.font = .systemFont(ofSize: 9, weight: .medium)
                titleLabel.frame = NSRect(x: 2, y: 2, width: bounds.width - 4, height: 12)
                titleLabel.alignment = .center
            }
        } else {
            symbolView.frame = NSRect(x: 18, y: (bounds.height - 26) / 2, width: 26, height: 26)
            checkView.frame = NSRect(x: bounds.width - 34, y: (bounds.height - 22) / 2, width: 22, height: 22)
            titleLabel.isHidden = false
            titleLabel.font = .systemFont(ofSize: GlassSkinConstants.themeOptionTitleFontSize, weight: .semibold)
            titleLabel.frame = NSRect(x: 50, y: (bounds.height - 24) / 2, width: bounds.width - 92, height: 24)
        }
    }

    func setSelected(_ selected: Bool) {
        isOptionSelected = selected
        checkView.isHidden = !selected
        needsLayout = true
    }

    fileprivate func refreshThemeAppearance() {
        appearance = GlassThemeHelper.nsAppearance()
        titleLabel.textColor = GlassThemeHelper.isDarkAppearance() ? .white.withAlphaComponent(0.90) : .labelColor
        symbolView.contentTintColor = GlassThemeHelper.isDarkAppearance() ? .white.withAlphaComponent(0.90) : .labelColor
        needsDisplay = true
        needsLayout = true
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?(skinId)
    }
}

// MARK: - 模块卡片

private final class GlassModuleCardView: NSView {
    let model: GlassModuleCardModel
    var baseFrame: NSRect = .zero
    var baseRotation: CGFloat = 0
    var baseZIndex: Int = 0

    private let materialView = NSVisualEffectView()
    private let symbolView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let switchLabel = NSTextField(labelWithString: "")
    private let switchTrackLayer = CAShapeLayer()
    private let switchKnobLayer = CAShapeLayer()
    private let highlightLayer = CAGradientLayer()
    private let accentGlowLayer = CAGradientLayer()
    private let borderLayer = CAShapeLayer()
    private var themeOptionButtons: [GlassThemeOptionButton] = []
    private var themeSubtitleLabel: NSTextField?
    private var patternOptionViews: [GlassPatternOptionView] = []
    private var patternPreviewViews: [GlassPatternOptionView] = []
    private var patternScrollView: NSScrollView?
    private let patternDocumentView = NSView()

    init(model: GlassModuleCardModel) {
        self.model = model
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.model = GlassModuleCardModel(id: "unknown", title: "模块", subtitle: "", symbolName: "square.grid.2x2.fill", accent: .controlAccentColor, isSwitchable: false, isEnabled: false)
        super.init(coder: coder)
        setup()
    }

    override var allowsVibrancy: Bool { true }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = GlassSkinConstants.cardShadowOpacity
        layer?.shadowRadius = GlassSkinConstants.cardShadowRadius
        layer?.shadowOffset = GlassSkinConstants.cardShadowOffset

        // NSVisualEffectView
        materialView.frame = bounds
        materialView.autoresizingMask = [.width, .height]
        materialView.material = .contentBackground
        materialView.blendingMode = .withinWindow
        materialView.state = .active
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = GlassSkinConstants.cardCornerRadius
        materialView.layer?.masksToBounds = true
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.layer?.backgroundColor = GlassThemeHelper.cardBackgroundColor()
        addSubview(materialView)

        // 高光渐变
        highlightLayer.colors = [
            NSColor.white.withAlphaComponent(0.86).cgColor,
            model.accent.withAlphaComponent(0.16).cgColor,
            NSColor.white.withAlphaComponent(0.06).cgColor
        ]
        highlightLayer.startPoint = CGPoint(x: 0, y: 1)
        highlightLayer.endPoint = CGPoint(x: 1, y: 0)
        highlightLayer.cornerRadius = GlassSkinConstants.cardCornerRadius
        layer?.addSublayer(highlightLayer)

        // 主题色辉光
        accentGlowLayer.colors = [
            model.accent.withAlphaComponent(0.34).cgColor,
            NSColor.white.withAlphaComponent(0.10).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
        accentGlowLayer.startPoint = CGPoint(x: 0, y: 1)
        accentGlowLayer.endPoint = CGPoint(x: 1, y: 0)
        accentGlowLayer.cornerRadius = GlassSkinConstants.cardCornerRadius
        layer?.addSublayer(accentGlowLayer)

        // 边框
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.strokeColor = GlassThemeHelper.cardBorderColor()
        borderLayer.lineWidth = GlassSkinConstants.cardBorderWidth
        layer?.addSublayer(borderLayer)

        // SF Symbol
        if let image = NSImage(systemSymbolName: model.symbolName, accessibilityDescription: model.title) {
            symbolView.image = image
            symbolView.contentTintColor = model.accent
        }
        addSubview(symbolView)

        // 标题（NSTextField 默认配置为透明背景）
        titleLabel.stringValue = model.title
        titleLabel.font = NSFont.systemFont(ofSize: GlassSkinConstants.cardTitleFontSize, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.drawsBackground = false
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        addSubview(titleLabel)

        // 副标题
        subtitleLabel.stringValue = model.subtitle
        subtitleLabel.font = NSFont.systemFont(ofSize: GlassSkinConstants.cardSubtitleFontSize, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.drawsBackground = false
        addSubview(subtitleLabel)

        // 模块启用开关：开关状态由设置面板卡片模型驱动。
        if model.isSwitchable {
            switchLabel.stringValue = model.isEnabled ? "已开启" : "已关闭"
            switchLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            switchLabel.textColor = model.isEnabled ? model.accent : .tertiaryLabelColor
            switchLabel.drawsBackground = false
            switchLabel.isBezeled = false
            switchLabel.isEditable = false
            addSubview(switchLabel)

            switchTrackLayer.fillColor = (model.isEnabled ? model.accent.withAlphaComponent(0.88) : NSColor.quaternaryLabelColor.withAlphaComponent(0.48)).cgColor
            switchTrackLayer.strokeColor = NSColor.white.withAlphaComponent(0.38).cgColor
            switchTrackLayer.lineWidth = 0.8
            layer?.addSublayer(switchTrackLayer)

            switchKnobLayer.fillColor = NSColor.white.withAlphaComponent(0.96).cgColor
            switchKnobLayer.shadowColor = NSColor.black.cgColor
            switchKnobLayer.shadowOpacity = 0.20
            switchKnobLayer.shadowRadius = 2.0
            switchKnobLayer.shadowOffset = CGSize(width: 0, height: -0.5)
            layer?.addSublayer(switchKnobLayer)
        }

        // 主题卡片：预创建缩小版选项按钮（一级卡片映射二级菜单布局）
        if model.id == "theme" {
            preconfigureThemeMiniButtons()
        }
        // 形态识别卡片：一级菜单只映射二级菜单最上面一页（三列预览），不滚动。
        if model.id == "pattern" {
            preconfigurePatternPreviewCards()
        }
    }

    fileprivate func refreshThemeAppearance() {
        appearance = GlassThemeHelper.nsAppearance()
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.layer?.backgroundColor = GlassThemeHelper.cardBackgroundColor()
        layer?.borderColor = GlassThemeHelper.cardBorderColor()
        if model.id == "theme" {
            updateThemeOptionSelection()
        }
        if model.id == "pattern" {
            patternOptionViews.forEach { $0.refreshThemeAppearance() }
            patternPreviewViews.forEach { $0.refreshThemeAppearance() }
        }
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        materialView.frame = bounds
        materialView.appearance = GlassThemeHelper.nsAppearance()
        materialView.layer?.backgroundColor = GlassThemeHelper.cardBackgroundColor()
        materialView.layer?.cornerRadius = GlassSkinConstants.cardCornerRadius
        highlightLayer.frame = bounds
        highlightLayer.cornerRadius = GlassSkinConstants.cardCornerRadius
        accentGlowLayer.frame = NSRect(x: 0, y: bounds.height - 58, width: bounds.width, height: 58)
        accentGlowLayer.cornerRadius = GlassSkinConstants.cardCornerRadius
        borderLayer.path = CGPath(roundedRect: bounds.insetBy(dx: 0.6, dy: 0.6),
                                  cornerWidth: GlassSkinConstants.cardCornerRadius,
                                  cornerHeight: GlassSkinConstants.cardCornerRadius,
                                  transform: nil)
        borderLayer.strokeColor = GlassThemeHelper.cardBorderColor()
        symbolView.frame = NSRect(
            x: GlassSkinConstants.cardSymbolLeftMargin,
            y: bounds.height - 48,
            width: GlassSkinConstants.cardSymbolSize,
            height: GlassSkinConstants.cardSymbolSize
        )
        titleLabel.frame = NSRect(
            x: GlassSkinConstants.cardTitleLeftMargin,
            y: bounds.height - 42,
            width: bounds.width - 80,
            height: 24
        )
        subtitleLabel.frame = NSRect(
            x: 20,
            y: GlassSkinConstants.cardSubtitleBottomMargin,
            width: bounds.width - 40,
            height: 38
        )

        // 一级卡片的主题卡片：隐藏副标题，把空间留给缩小版选项按钮网格
        let isMiniThemeCard = model.id == "theme" && !themeOptionButtons.isEmpty && bounds.width <= GlassSkinConstants.cardWidth * 1.2
        subtitleLabel.isHidden = isMiniThemeCard

        if model.isSwitchable {
            let trackFrame = NSRect(x: bounds.width - 72, y: bounds.height - 45, width: 44, height: 24)
            switchTrackLayer.path = CGPath(roundedRect: trackFrame,
                                           cornerWidth: 12,
                                           cornerHeight: 12,
                                           transform: nil)
            switchTrackLayer.fillColor = (model.isEnabled ? model.accent.withAlphaComponent(0.88) : NSColor.quaternaryLabelColor.withAlphaComponent(0.48)).cgColor
            let knobX = model.isEnabled ? trackFrame.maxX - 21 : trackFrame.minX + 3
            let knobFrame = NSRect(x: knobX, y: trackFrame.minY + 3, width: 18, height: 18)
            switchKnobLayer.path = CGPath(ellipseIn: knobFrame, transform: nil)
            switchLabel.frame = NSRect(x: bounds.width - 78, y: trackFrame.minY - 22, width: 64, height: 16)
        }

        // 更新高光透明度（深色主题下降低高光强度）
        if GlassThemeHelper.isDarkAppearance() {
            highlightLayer.opacity = 0.5
        } else {
            highlightLayer.opacity = 1.0
        }
        layoutThemeMenuContentsIfNeeded()
        layoutPatternMenuContentsIfNeeded()
    }

    private func layoutThemeMenuContentsIfNeeded() {
        guard model.id == "theme" else { return }

        let isExpanded = bounds.width > GlassSkinConstants.cardWidth * 1.2

        if isExpanded {
            titleLabel.frame = NSRect(
                x: GlassSkinConstants.themeMenuTitleLeft,
                y: bounds.height - GlassSkinConstants.themeMenuTitleTop - 30,
                width: bounds.width - GlassSkinConstants.themeMenuTitleLeft * 2,
                height: 32
            )
            themeSubtitleLabel?.frame = NSRect(
                x: GlassSkinConstants.themeMenuTitleLeft,
                y: titleLabel.frame.minY - GlassSkinConstants.themeMenuSubtitleTopGap - 20,
                width: bounds.width - GlassSkinConstants.themeMenuTitleLeft * 2,
                height: 20
            )

            guard !themeOptionButtons.isEmpty else { return }
            let cols = 3
            let buttonW = min(GlassSkinConstants.themeOptionButtonWidth,
                              max(150, (bounds.width - GlassSkinConstants.themeMenuContentInsetX * 2 - GlassSkinConstants.themeOptionHorizontalGap * 2) / CGFloat(cols)))
            let buttonH = GlassSkinConstants.themeOptionButtonHeight
            let totalW = CGFloat(cols) * buttonW + CGFloat(cols - 1) * GlassSkinConstants.themeOptionHorizontalGap
            let startX = (bounds.width - totalW) / 2
            let topY = (themeSubtitleLabel?.frame.minY ?? (bounds.height - 90)) - GlassSkinConstants.themeOptionTopFromSubtitle - buttonH

            for (idx, button) in themeOptionButtons.enumerated() {
                let row = idx / cols
                let col = idx % cols
                button.frame = NSRect(
                    x: startX + CGFloat(col) * (buttonW + GlassSkinConstants.themeOptionHorizontalGap),
                    y: topY - CGFloat(row) * (buttonH + GlassSkinConstants.themeOptionVerticalGap),
                    width: buttonW,
                    height: buttonH
                )
                button.isMiniMode = false
            }
        } else {
            // 一级卡片状态：缩小映射布局（3列2行，放在卡片下半部）
            let cols = 3
            let marginX: CGFloat = 12
            let gapX: CGFloat = 6
            let gapY: CGFloat = 4
            let titleAreaHeight: CGFloat = 52
            let topSpacing: CGFloat = 4

            let availableW = bounds.width - marginX * 2
            let buttonW = (availableW - gapX * CGFloat(cols - 1)) / CGFloat(cols)

            let buttonAreaTop = bounds.height - titleAreaHeight - topSpacing
            let buttonAreaBottom: CGFloat = 8
            let buttonAreaH = buttonAreaTop - buttonAreaBottom
            let buttonH = (buttonAreaH - gapY) / 2

            let startX = marginX
            let bottomRowY = buttonAreaBottom
            let topRowY = bottomRowY + buttonH + gapY

            for (idx, button) in themeOptionButtons.enumerated() {
                let row = idx / cols
                let col = idx % cols
                let y = row == 0 ? topRowY : bottomRowY
                button.frame = NSRect(
                    x: startX + CGFloat(col) * (buttonW + gapX),
                    y: y,
                    width: buttonW,
                    height: buttonH
                )
                button.isMiniMode = true
            }
        }
    }

    private func preconfigurePatternPreviewCards() {
        guard patternPreviewViews.isEmpty else { return }
        for item in GlassPatternMenuItem.builtinItems().prefix(3) {
            let preview = GlassPatternOptionView(item: item)
            addSubview(preview)
            patternPreviewViews.append(preview)
        }
    }

    private func preconfigureThemeMiniButtons() {
        let options: [(String, String, String)] = [
            ("浅色", "built-in-light", "sun.max.fill"),
            ("深色", "built-in-dark", "moon.fill"),
            ("跟随系统", "system", "desktopcomputer"),
            ("高对比度", "built-in-highcontrast", "circle.lefthalf.filled"),
            ("红色色盲", "built-in-protanopia", "eye.fill"),
            ("绿色色盲", "built-in-deuteranopia", "eye.trianglebadge.exclamationmark.fill")
        ]
        for option in options {
            let button = GlassThemeOptionButton(title: option.0, skinId: option.1, symbolName: option.2)
            button.isMiniMode = true
            addSubview(button)
            themeOptionButtons.append(button)
        }
        updateThemeOptionSelection()
    }

    func configureThemeMenuContents() {
        guard model.id == "theme" else { return }
        glassSkinPanelLogger.info("开始配置主题二级大卡片按钮")

        titleLabel.stringValue = "主题设置"
        titleLabel.font = .systemFont(ofSize: GlassSkinConstants.themeMenuTitleFontSize, weight: .bold)
        subtitleLabel.isHidden = true
        symbolView.isHidden = true

        if themeSubtitleLabel == nil {
            let subtitle = NSTextField(labelWithString: "选择界面外观与辅助视觉")
            subtitle.font = .systemFont(ofSize: GlassSkinConstants.themeMenuSubtitleFontSize, weight: .regular)
            subtitle.textColor = .secondaryLabelColor
            subtitle.isBezeled = false
            subtitle.isEditable = false
            subtitle.backgroundColor = .clear
            addSubview(subtitle)
            themeSubtitleLabel = subtitle
        }

        if themeOptionButtons.isEmpty {
            let options: [(String, String, String)] = [
                ("浅色", "built-in-light", "sun.max.fill"),
                ("深色", "built-in-dark", "moon.fill"),
                ("跟随系统", "system", "desktopcomputer"),
                ("高对比度", "built-in-highcontrast", "circle.lefthalf.filled"),
                ("红色色盲", "built-in-protanopia", "eye.fill"),
                ("绿色色盲", "built-in-deuteranopia", "eye.trianglebadge.exclamationmark.fill")
            ]
            for option in options {
                let button = GlassThemeOptionButton(title: option.0, skinId: option.1, symbolName: option.2)
                button.onSelect = { [weak self] themeId in
                    self?.applyThemeOption(themeId: themeId)
                }
                addSubview(button)
                themeOptionButtons.append(button)
            }
        } else {
            // 复用一级卡片预创建的按钮，更新交互回调
            for button in themeOptionButtons {
                button.onSelect = { [weak self] themeId in
                    self?.applyThemeOption(themeId: themeId)
                }
                button.isMiniMode = false
            }
        }
        updateThemeOptionSelection()
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    // MARK: - 形态识别二级菜单
    func configurePatternMenuContents() {
        guard model.id == "pattern" else { return }
        glassSkinPanelLogger.info("开始配置形态识别二级菜单")

        titleLabel.stringValue = "形态识别"
        titleLabel.font = .systemFont(ofSize: GlassSkinConstants.themeMenuTitleFontSize, weight: .bold)
        subtitleLabel.isHidden = true
        symbolView.isHidden = true
        patternPreviewViews.forEach { $0.isHidden = true }

        themeSubtitleLabel?.isHidden = true

        if patternScrollView == nil {
            let scrollView = NSScrollView(frame: .zero)
            scrollView.drawsBackground = false
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            scrollView.borderType = .noBorder
            scrollView.wantsLayer = true
            scrollView.layer?.cornerRadius = 14
            scrollView.documentView = patternDocumentView
            addSubview(scrollView)
            patternScrollView = scrollView
        }

        if patternOptionViews.isEmpty {
            for item in GlassPatternMenuItem.builtinItems() {
                let card = GlassPatternOptionView(item: item)
                card.onStateChanged = { state in
                    var states = KPPatternSettingsStore.loadStates()
                    states[state.id] = state
                    KPPatternSettingsStore.saveStates(states)
                    NotificationCenter.default.post(
                        name: .KPPatternSettingsDidChange,
                        object: state.id,
                        userInfo: ["state": state]
                    )
                    glassSkinPanelLogger.info("形态识别设置已保存 id=\(state.id, privacy: .public) enabled=\(state.enabled, privacy: .public) timeframes=\(state.selectedTimeframes.sorted().joined(separator: ","), privacy: .public)")
                }
                patternDocumentView.addSubview(card)
                patternOptionViews.append(card)
            }
        }

        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func layoutPatternMenuContentsIfNeeded() {
        guard model.id == "pattern" else { return }

        let isExpanded = bounds.width > GlassSkinConstants.cardWidth * 1.2
        guard isExpanded else {
            patternScrollView?.isHidden = true
            patternOptionViews.forEach { $0.isHidden = true }
            guard !patternPreviewViews.isEmpty else { return }
            subtitleLabel.isHidden = true
            symbolView.isHidden = false
            titleLabel.frame = NSRect(
                x: GlassSkinConstants.cardTitleLeftMargin,
                y: bounds.height - 42,
                width: bounds.width - 80,
                height: 24
            )
            let cols = 3
            let marginX: CGFloat = 12
            let gapX: CGFloat = 6
            let topY = bounds.height - 62
            let bottomY: CGFloat = 10
            let cardH = max(96, topY - bottomY)
            let cardW = floor((bounds.width - marginX * 2 - gapX * CGFloat(cols - 1)) / CGFloat(cols))
            for (idx, card) in patternPreviewViews.enumerated() {
                let x = marginX + CGFloat(idx) * (cardW + gapX)
                card.isHidden = false
                card.frame = NSRect(x: x, y: bottomY, width: cardW, height: cardH)
            }
            return
        }

        titleLabel.frame = NSRect(
            x: GlassSkinConstants.themeMenuTitleLeft,
            y: bounds.height - GlassSkinConstants.themeMenuTitleTop - 30,
            width: bounds.width - GlassSkinConstants.themeMenuTitleLeft * 2,
            height: 32
        )
        themeSubtitleLabel?.isHidden = true

        guard let scrollView = patternScrollView, !patternOptionViews.isEmpty else { return }
        scrollView.isHidden = false
        patternOptionViews.forEach { $0.isHidden = false }

        let contentInsetX: CGFloat = 24
        let contentInsetBottom: CGFloat = 20
        let topGap: CGFloat = 8
        let scrollTop = titleLabel.frame.minY - topGap
        let scrollBottom: CGFloat = contentInsetBottom
        let scrollHeight = max(120, scrollTop - scrollBottom)
        scrollView.frame = NSRect(
            x: contentInsetX,
            y: scrollBottom,
            width: max(100, bounds.width - contentInsetX * 2),
            height: scrollHeight
        )

        let cols = 3
        let marginX: CGFloat = 12
        let marginTop: CGFloat = 4
        let marginBottom: CGFloat = 12
        let columnGap: CGFloat = 12
        let rowGap: CGFloat = 12
        let cardWidth = floor((scrollView.contentSize.width - marginX * 2 - columnGap * CGFloat(cols - 1)) / CGFloat(cols))
        let cardHeight = max(118, min(144, cardWidth * 0.72))
        let rows = Int(ceil(Double(patternOptionViews.count) / Double(cols)))
        let documentHeight = max(scrollView.contentSize.height,
                                 marginTop + marginBottom + CGFloat(rows) * cardHeight + CGFloat(max(0, rows - 1)) * rowGap)
        patternDocumentView.frame = NSRect(x: 0, y: 0, width: scrollView.contentSize.width, height: documentHeight)

        for (idx, card) in patternOptionViews.enumerated() {
            let row = idx / cols
            let col = idx % cols
            let x = marginX + CGFloat(col) * (cardWidth + columnGap)
            let y = documentHeight - marginTop - CGFloat(row + 1) * cardHeight - CGFloat(row) * rowGap
            card.frame = NSRect(x: x, y: y, width: cardWidth, height: cardHeight)
        }
    }

    private func applyThemeOption(themeId: String) {
        let resolvedThemeId: String
        if themeId == "system" {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            resolvedThemeId = isDark ? "built-in-dark" : "built-in-light"
            UserDefaults.standard.set(true, forKey: "com.xianrenzhilu.theme.followSystemEnabled")
        } else {
            resolvedThemeId = GlassThemeHelper.normalizeThemeId(themeId)
            UserDefaults.standard.set(false, forKey: "com.xianrenzhilu.theme.followSystemEnabled")
        }
        glassSkinPanelLogger.info("主题按钮点击 themeId=\(themeId, privacy: .public) resolved=\(resolvedThemeId, privacy: .public)")
        // 玻璃皮肤是 UI 基座，不能切走 com.app.glass；这里只切换玻璃内部主题。
        UserDefaults.standard.set("com.app.glass", forKey: "com.xianrenzhilu.skin.currentSkinId")
        UserDefaults.standard.set(resolvedThemeId, forKey: "com.xianrenzhilu.theme.currentThemeId")
        UserDefaults.standard.set(resolvedThemeId, forKey: "com.xianrenzhilu.glass.visualThemeId")
        UserDefaults.standard.set(resolvedThemeId, forKey: "com.xianrenzhilu.glass.visualSkinId") // 兼容旧键
        _ = UIUnifiedRegistry.shared.applyTheme(id: resolvedThemeId)
        glassSkinPanelLogger.info("主题按钮应用玻璃内部主题 themeId=\(themeId, privacy: .public) resolved=\(resolvedThemeId, privacy: .public)")
        updateThemeOptionSelection(selectedLogicalId: themeId)
        refreshGlassAppearanceTree()
    }

    private func refreshGlassAppearanceTree() {
        let root = window?.contentView ?? self
        applyCurrentThemeAppearanceTree(from: root)
        root.needsLayout = true
        root.layoutSubtreeIfNeeded()
        root.needsDisplay = true
    }

    /// 运行中切换主题时，必须同步刷新已存在的 NSVisualEffectView.appearance 和玻璃背景色。
    /// 否则 UserDefaults 已变，但材质仍停留在旧主题/系统外观，看起来像“切了一半”。
    private func applyCurrentThemeAppearanceTree(from view: NSView) {
        let appearance = GlassThemeHelper.nsAppearance()
        view.appearance = appearance

        if let effect = view as? NSVisualEffectView {
            effect.appearance = appearance
        }

        switch view.identifier?.rawValue {
        case "glass.root.material":
            view.layer?.backgroundColor = GlassThemeHelper.contentBackgroundColor()
        case "glass.toolbar":
            view.layer?.backgroundColor = GlassThemeHelper.toolbarBackgroundColor()
        case "glass.content.view", "glass.content.document.view":
            view.layer?.backgroundColor = GlassThemeHelper.contentBackgroundColor()
        default:
            break
        }

        if let toolbar = view as? GlassToolbarView {
            toolbar.refreshThemeAppearance()
        }
        if let panel = view as? GlassSettingsPanelView {
            panel.refreshThemeAppearance()
        }
        if let card = view as? GlassModuleCardView {
            card.refreshThemeAppearance()
        }
        if let option = view as? GlassThemeOptionButton {
            option.refreshThemeAppearance()
        }
        if let patternCard = view as? GlassPatternOptionView {
            patternCard.refreshThemeAppearance()
        }

        view.needsLayout = true
        view.needsDisplay = true
        view.layer?.setNeedsDisplay()
        view.subviews.forEach { applyCurrentThemeAppearanceTree(from: $0) }
    }

    private func updateThemeOptionSelection(selectedLogicalId: String? = nil) {
        let followSystem = UserDefaults.standard.bool(forKey: "com.xianrenzhilu.theme.followSystemEnabled")
        let current = GlassThemeHelper.currentThemeId()
        for button in themeOptionButtons {
            let selected: Bool
            if button.skinId == "system" {
                selected = selectedLogicalId == "system" || (selectedLogicalId == nil && followSystem)
            } else {
                selected = selectedLogicalId == button.skinId || (selectedLogicalId == nil && !followSystem && current == button.skinId)
            }
            button.setSelected(selected)
        }
    }

    // MARK: - 卡片变换

    /// 恢复到基准位置（包括旋转和偏移）
    func resetToBase(animated: Bool) {
        var transform = CATransform3DIdentity
        transform = CATransform3DRotate(transform, baseRotation * .pi / 180, 0, 0, 1)
        if animated {
            guard let layer else {
                frame = baseFrame
                return
            }
            let fromPos = layer.presentation()?.position ?? layer.position
            let targetPos = CGPoint(x: baseFrame.midX, y: baseFrame.midY)
            frame = baseFrame
            let spring = GlassAnimationTools.springAnimation(
                keyPath: "position",
                from: fromPos, to: targetPos,
                mass: GlassSkinConstants.cardSpringMass,
                stiffness: GlassSkinConstants.cardSpringStiffness,
                damping: GlassSkinConstants.cardSpringDamping,
                velocity: GlassSkinConstants.cardSpringVelocity
            )
            CATransaction.begin()
            CATransaction.setAnimationDuration(spring.settlingDuration)
            layer.zPosition = CGFloat(baseZIndex)
            layer.add(spring, forKey: "glass.card.reset.position")
            let txAnim = CABasicAnimation(keyPath: "transform")
            txAnim.toValue = transform
            txAnim.duration = GlassSkinConstants.cardTransitionDuration
            txAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(txAnim, forKey: "glass.card.reset.transform")
            layer.transform = transform
            layer.shadowOpacity = GlassSkinConstants.cardShadowOpacity
            layer.shadowRadius = GlassSkinConstants.cardShadowRadius
            CATransaction.commit()
        } else {
            frame = baseFrame
            layer?.zPosition = CGFloat(baseZIndex)
            layer?.transform = transform
            layer?.shadowOpacity = GlassSkinConstants.cardShadowOpacity
            layer?.shadowRadius = GlassSkinConstants.cardShadowRadius
        }
    }

    func animateToBaseWithSpring() {
        resetToBase(animated: true)
    }

    /// 初始弧度过渡：只动画旋转/层级/阴影，不移动 position，避免整组卡片右下偏移后再弹回。
    func animateBaseCurveOnly() {
        guard let layer else { return }
        var transform = CATransform3DIdentity
        transform = CATransform3DRotate(transform, baseRotation * .pi / 180, 0, 0, 1)

        let txAnim = CABasicAnimation(keyPath: "transform")
        txAnim.fromValue = layer.presentation()?.value(forKeyPath: "transform") ?? layer.transform
        txAnim.toValue = transform
        txAnim.duration = GlassSkinConstants.cardTransitionDuration * 1.6
        txAnim.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.84, 0.22, 1.0)

        CATransaction.begin()
        CATransaction.setAnimationDuration(txAnim.duration)
        layer.zPosition = CGFloat(baseZIndex)
        layer.add(txAnim, forKey: "glass.card.initial.curveOnly")
        layer.transform = transform
        layer.shadowOpacity = GlassSkinConstants.cardShadowOpacity
        layer.shadowRadius = GlassSkinConstants.cardShadowRadius
        CATransaction.commit()
    }

    /// 鼠标悬停效果（跟随鼠标位移+倾斜+放大阴影）
    func animateHover(mousePoint: NSPoint) {
        let dx = ((mousePoint.x / max(bounds.width, 1)) - 0.5) * GlassSkinConstants.cardHoverMaxDx
        let dy = ((mousePoint.y / max(bounds.height, 1)) - 0.5) * GlassSkinConstants.cardHoverMaxDy
        let target = baseFrame.offsetBy(dx: dx, dy: dy + GlassSkinConstants.cardHoverElevation)
        var transform = CATransform3DIdentity
        transform.m34 = GlassSkinConstants.cardHoverM34
        let scale = 1.0 + GlassSkinConstants.cardHoverScaleIncrease
        transform = CATransform3DScale(transform, scale, scale, 1)
        transform = CATransform3DRotate(transform, -dy * .pi / 900, 1, 0, 0)
        transform = CATransform3DRotate(transform, dx * .pi / 900, 0, 1, 0)

        guard let layer else {
            frame = target
            return
        }
        let oldPos = layer.presentation()?.position ?? layer.position
        frame = target

        // 鼠标移动是高频事件，不能每次都叠加长弹簧动画；用短跟随动画替代，避免来回扫卡片时乱跳。
        layer.removeAnimation(forKey: "glass.card.hover.position")
        layer.removeAnimation(forKey: "glass.card.hover.transform")
        let posAnim = CABasicAnimation(keyPath: "position")
        posAnim.fromValue = oldPos
        posAnim.toValue = layer.position
        posAnim.duration = GlassSkinConstants.cardHoverFollowDuration
        posAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let transformAnim = CABasicAnimation(keyPath: "transform")
        transformAnim.toValue = transform
        transformAnim.duration = GlassSkinConstants.cardHoverFollowDuration
        transformAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let shadowOp = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOp.toValue = GlassSkinConstants.cardHoverShadowOpacity
        shadowOp.duration = GlassSkinConstants.cardHoverFollowDuration
        shadowOp.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let shadowR = CABasicAnimation(keyPath: "shadowRadius")
        shadowR.toValue = GlassSkinConstants.cardHoverShadowRadius
        shadowR.duration = GlassSkinConstants.cardHoverFollowDuration
        shadowR.timingFunction = CAMediaTimingFunction(name: .easeOut)

        CATransaction.begin()
        CATransaction.setAnimationDuration(GlassSkinConstants.cardHoverFollowDuration)
        layer.add(posAnim, forKey: "glass.card.hover.position")
        layer.add(transformAnim, forKey: "glass.card.hover.transform")
        layer.add(shadowOp, forKey: "glass.card.hover.shadowOpacity")
        layer.add(shadowR, forKey: "glass.card.hover.shadowRadius")
        layer.transform = transform
        layer.shadowOpacity = GlassSkinConstants.cardHoverShadowOpacity
        layer.shadowRadius = GlassSkinConstants.cardHoverShadowRadius
        CATransaction.commit()
    }

    /// 点击后放大成二级菜单容器：只在点击主题设置卡片后触发，hover 不触发。
    func animateExpandedMenuFrame(to targetFrame: NSRect) {
        guard let layer else {
            frame = targetFrame
            return
        }
        let fromPosition = layer.presentation()?.position ?? layer.position
        let fromTransform = layer.presentation()?.value(forKeyPath: "transform") ?? layer.transform
        frame = targetFrame
        var targetTransform = CATransform3DIdentity
        targetTransform.m34 = GlassSkinConstants.cardHoverM34

        let posAnim = CABasicAnimation(keyPath: "position")
        posAnim.fromValue = fromPosition
        posAnim.toValue = layer.position
        posAnim.duration = GlassSkinConstants.cardTransitionDuration * 2.2
        posAnim.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.84, 0.22, 1.0)

        let boundsAnim = CABasicAnimation(keyPath: "bounds")
        boundsAnim.fromValue = layer.presentation()?.bounds ?? NSRect(origin: .zero, size: targetFrame.size)
        boundsAnim.toValue = layer.bounds
        boundsAnim.duration = posAnim.duration
        boundsAnim.timingFunction = posAnim.timingFunction

        let transformAnim = CABasicAnimation(keyPath: "transform")
        transformAnim.fromValue = fromTransform
        transformAnim.toValue = targetTransform
        transformAnim.duration = posAnim.duration
        transformAnim.timingFunction = posAnim.timingFunction

        CATransaction.begin()
        CATransaction.setAnimationDuration(posAnim.duration)
        layer.zPosition = 220
        layer.add(posAnim, forKey: "glass.card.expand.frame.position")
        layer.add(boundsAnim, forKey: "glass.card.expand.frame.bounds")
        layer.add(transformAnim, forKey: "glass.card.expand.frame.transform")
        layer.transform = targetTransform
        layer.shadowOpacity = GlassSkinConstants.cardHoverShadowOpacity
        layer.shadowRadius = GlassSkinConstants.cardHoverShadowRadius + 12
        CATransaction.commit()
    }

    /// 点击后按比例放大；保留备用，不接入 hover。
    func animateExpandedMenuState() {
        guard let layer else { return }
        let scale = 1.0 + GlassSkinConstants.themeCardExpandedScaleIncrease
        var transform = CATransform3DIdentity
        transform.m34 = GlassSkinConstants.cardHoverM34
        transform = CATransform3DScale(transform, scale, scale, 1)

        let transformAnim = CABasicAnimation(keyPath: "transform")
        transformAnim.fromValue = layer.presentation()?.value(forKeyPath: "transform") ?? layer.transform
        transformAnim.toValue = transform
        transformAnim.duration = GlassSkinConstants.cardTransitionDuration * 1.7
        transformAnim.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.84, 0.22, 1.0)

        CATransaction.begin()
        CATransaction.setAnimationDuration(transformAnim.duration)
        layer.zPosition = 160
        layer.add(transformAnim, forKey: "glass.card.expand.menu")
        layer.transform = transform
        layer.shadowOpacity = GlassSkinConstants.cardHoverShadowOpacity
        layer.shadowRadius = GlassSkinConstants.cardHoverShadowRadius + 10
        CATransaction.commit()
    }

    /// 散开效果（其他卡片偏移+缩小）
    func animateScatter(dx: CGFloat, dy: CGFloat, scale: CGFloat) {
        let target = baseFrame.offsetBy(dx: dx, dy: dy)
        var transform = CATransform3DIdentity
        transform = CATransform3DScale(transform, scale, scale, 1)
        transform = CATransform3DRotate(transform, baseRotation * .pi / 180, 0, 0, 1)

        guard let layer else {
            frame = target
            return
        }
        let oldPos = layer.presentation()?.position ?? layer.position
        frame = target

        let spring = GlassAnimationTools.springAnimation(
            keyPath: "position", from: oldPos, to: layer.position,
            mass: GlassSkinConstants.cardSpringMass,
            stiffness: GlassSkinConstants.cardSpringStiffness,
            damping: GlassSkinConstants.cardSpringDamping,
            velocity: GlassSkinConstants.cardSpringVelocity
        )
        let transformAnim = CABasicAnimation(keyPath: "transform")
        transformAnim.toValue = transform
        transformAnim.duration = GlassSkinConstants.cardTransitionDuration
        transformAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let shadowOp = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOp.toValue = GlassSkinConstants.cardShadowOpacity * 0.6
        shadowOp.duration = GlassSkinConstants.cardTransitionDuration
        shadowOp.timingFunction = CAMediaTimingFunction(name: .easeOut)

        CATransaction.begin()
        CATransaction.setAnimationDuration(max(spring.settlingDuration, GlassSkinConstants.cardTransitionDuration))
        layer.add(spring, forKey: "glass.card.scatter.position")
        layer.add(transformAnim, forKey: "glass.card.scatter.transform")
        layer.add(shadowOp, forKey: "glass.card.scatter.shadowOpacity")
        layer.transform = transform
        layer.shadowOpacity = GlassSkinConstants.cardShadowOpacity * 0.6
        CATransaction.commit()
    }
}

// MARK: - K线形态识别二级菜单卡片

private struct GlassPatternMenuItem {
    let id: String
    let name: String
    let category: String
    let kind: String
    let defaultEnabled: Bool
    let selectedTimeframes: Set<String>
    let helpText: String

    static var timeframes: [String] { KPPatternSettingsCatalog.timeframes }

    static func builtinItems() -> [GlassPatternMenuItem] {
        let states = KPPatternSettingsStore.loadStates()
        return KPPatternSettingsCatalog.builtinOptions().map { option in
            let state = states[option.id]
            return GlassPatternMenuItem(
                id: option.id,
                name: option.name,
                category: option.category,
                kind: option.illustrationKind,
                defaultEnabled: state?.enabled ?? option.defaultEnabled,
                selectedTimeframes: state?.selectedTimeframes ?? option.selectedTimeframes,
                helpText: KPPatternSettingsCatalog.helpText(for: option)
            )
        }
    }
}
private final class GlassPatternOptionView: NSView {
    private let item: GlassPatternMenuItem
    private let categoryLabel = NSTextField(labelWithString: "")
    private let nameLabel = NSTextField(labelWithString: "")
    private let illustrationView: GlassPatternIllustrationView
    private let toggleView: GlassPatternToggleView
    private let helpButton = GlassPatternHelpButton()
    private let helpBubble = GlassPatternHelpBubbleView()
    private var timeframeButtons: [GlassPatternTimeframeButton] = []
    private var isHelpVisible = false
    var onStateChanged: ((KPPatternSettingState) -> Void)?

    init(item: GlassPatternMenuItem) {
        self.item = item
        self.illustrationView = GlassPatternIllustrationView(kind: item.kind)
        self.toggleView = GlassPatternToggleView(isOn: item.defaultEnabled)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = false

        categoryLabel.isHidden = true

        nameLabel.stringValue = item.name
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.isBezeled = false
        nameLabel.drawsBackground = false
        nameLabel.isEditable = false
        addSubview(nameLabel)

        for timeframe in GlassPatternMenuItem.timeframes {
            let button = GlassPatternTimeframeButton(title: timeframe, isSelected: item.selectedTimeframes.contains(timeframe))
            timeframeButtons.append(button)
            addSubview(button)
        }
        addSubview(toggleView)
        addSubview(illustrationView)
        helpButton.onClick = { [weak self] in self?.toggleHelpBubble() }
        addSubview(helpButton)
        helpBubble.configure(text: item.helpText)
        helpBubble.isHidden = true
        addSubview(helpBubble)
        refreshThemeAppearance()
    }

    func refreshThemeAppearance() {
        let isDark = GlassThemeHelper.isDarkAppearance()
        layer?.backgroundColor = (isDark ? NSColor.white.withAlphaComponent(0.070) : NSColor.white.withAlphaComponent(0.72)).cgColor
        layer?.borderWidth = toggleView.isOn ? 1.25 : 0.8
        layer?.borderColor = (toggleView.isOn ? NSColor.systemGreen.withAlphaComponent(0.72) : NSColor.separatorColor.withAlphaComponent(0.45)).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = isDark ? 0.22 : 0.10
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        nameLabel.textColor = isDark ? .white.withAlphaComponent(0.92) : .labelColor
        timeframeButtons.forEach { $0.refreshThemeAppearance() }
        toggleView.refreshThemeAppearance()
        helpButton.refreshThemeAppearance()
        helpBubble.refreshThemeAppearance()
        illustrationView.refreshThemeAppearance()
        illustrationView.isHidden = isHelpVisible
        helpBubble.isHidden = !isHelpVisible
        needsDisplay = true
        needsLayout = true
    }

    private func toggleHelpBubble() {
        isHelpVisible.toggle()
        refreshThemeAppearance()
    }

    func currentState() -> KPPatternSettingState {
        KPPatternSettingState(
            id: item.id,
            enabled: toggleView.isOn,
            selectedTimeframes: Set(timeframeButtons.filter { $0.isSelected }.map { $0.timeframe })
        )
    }

    func persistStateFromControls() {
        onStateChanged?(currentState())
        refreshThemeAppearance()
    }

    override func layout() {
        super.layout()
        let inset: CGFloat = 8
        let nameH: CGFloat = 20
        let leftW: CGFloat = min(76, max(64, bounds.width * 0.34))
        let buttonW = floor((leftW - 6) / 2)
        let buttonH: CGFloat = 18
        let gap: CGFloat = 3
        let topY = bounds.height - inset - buttonH

        categoryLabel.frame = .zero
        for (idx, button) in timeframeButtons.enumerated() {
            let row = idx / 2
            let col = idx % 2
            let y = topY - CGFloat(row) * (buttonH + gap)
            let x = inset + CGFloat(col) * (buttonW + 6)
            button.frame = NSRect(x: x, y: y, width: buttonW, height: buttonH)
        }
        toggleView.frame = NSRect(x: inset + (leftW - 42) / 2, y: 6, width: 42, height: 20)
        let chartX = inset + leftW + 10
        let contentFrame = NSRect(x: chartX, y: inset + nameH + 2, width: max(42, bounds.width - chartX - inset), height: max(42, bounds.height - inset * 2 - nameH - 2))
        illustrationView.frame = contentFrame
        helpBubble.frame = contentFrame
        helpButton.frame = NSRect(x: bounds.maxX - inset - 18, y: bounds.maxY - inset - 18, width: 18, height: 18)
        nameLabel.frame = NSRect(x: chartX, y: inset - 1, width: max(42, bounds.width - chartX - inset), height: nameH)
    }
}

private final class GlassPatternHelpButton: NSView {
    var onClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 9
        refreshThemeAppearance()
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: GlassThemeHelper.isDarkAppearance() ? NSColor.white.withAlphaComponent(0.94) : NSColor.labelColor
        ]
        let text = NSString(string: "?")
        let size = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attrs)
    }

    func refreshThemeAppearance() {
        layer?.backgroundColor = (GlassThemeHelper.isDarkAppearance() ? NSColor.systemBlue.withAlphaComponent(0.38) : NSColor.systemBlue.withAlphaComponent(0.16)).cgColor
        layer?.borderWidth = 0.8
        layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.65).cgColor
        needsDisplay = true
    }
}

private final class GlassPatternHelpBubbleView: NSView {
    private let textView = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        textView.font = .systemFont(ofSize: 10, weight: .regular)
        textView.maximumNumberOfLines = 0
        textView.isBezeled = false
        textView.drawsBackground = false
        textView.isEditable = false
        addSubview(textView)
        refreshThemeAppearance()
    }

    required init?(coder: NSCoder) { nil }

    func configure(text: String) {
        textView.stringValue = text
    }

    override func layout() {
        super.layout()
        textView.frame = bounds.insetBy(dx: 8, dy: 7)
    }

    func refreshThemeAppearance() {
        let isDark = GlassThemeHelper.isDarkAppearance()
        layer?.backgroundColor = (isDark ? NSColor.black.withAlphaComponent(0.48) : NSColor.white.withAlphaComponent(0.86)).cgColor
        layer?.borderWidth = 0.8
        layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.42).cgColor
        textView.textColor = isDark ? .white.withAlphaComponent(0.92) : .labelColor
        needsDisplay = true
    }
}

private final class GlassPatternTimeframeButton: NSView {
    private let label = NSTextField(labelWithString: "")
    let timeframe: String
    private(set) var isSelected: Bool

    init(title: String, isSelected: Bool) {
        self.timeframe = title
        self.isSelected = isSelected
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        label.stringValue = title
        label.font = .systemFont(ofSize: 9, weight: .semibold)
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        addSubview(label)
        refreshThemeAppearance()
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 2, dy: 2)
    }

    override func mouseDown(with event: NSEvent) {
        isSelected.toggle()
        refreshThemeAppearance()
        if let parent = superview as? GlassPatternOptionView {
            parent.persistStateFromControls()
        }
    }

    func refreshThemeAppearance() {
        let fill = isSelected ? NSColor.systemGreen.withAlphaComponent(0.82) : (GlassThemeHelper.isDarkAppearance() ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.055))
        layer?.backgroundColor = fill.cgColor
        layer?.borderWidth = isSelected ? 0 : 0.6
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        label.textColor = isSelected ? .white : .secondaryLabelColor
        needsDisplay = true
    }
}

private final class GlassPatternToggleView: NSView {
    private(set) var isOn: Bool

    init(isOn: Bool) {
        self.isOn = isOn
        super.init(frame: .zero)
        wantsLayer = true
        refreshThemeAppearance()
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        refreshThemeAppearance()
        superview?.needsDisplay = true
        if let parent = superview as? GlassPatternOptionView {
            parent.persistStateFromControls()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let track = bounds.insetBy(dx: 1, dy: 2)
        let trackPath = NSBezierPath(roundedRect: track, xRadius: track.height / 2, yRadius: track.height / 2)
        (isOn ? NSColor.systemGreen : NSColor.quaternaryLabelColor).withAlphaComponent(isOn ? 0.90 : 0.55).setFill()
        trackPath.fill()
        let knobSide = track.height - 4
        let knobX = isOn ? track.maxX - knobSide - 2 : track.minX + 2
        let knobRect = NSRect(x: knobX, y: track.minY + 2, width: knobSide, height: knobSide)
        NSColor.white.withAlphaComponent(0.96).setFill()
        NSBezierPath(ovalIn: knobRect).fill()
    }

    func refreshThemeAppearance() {
        needsDisplay = true
    }
}

private final class GlassPatternIllustrationView: NSView {
    private let kind: String

    init(kind: String) {
        self.kind = kind
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        refreshThemeAppearance()
    }

    required init?(coder: NSCoder) { nil }

    func refreshThemeAppearance() {
        layer?.backgroundColor = (GlassThemeHelper.isDarkAppearance() ? NSColor.black.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.38)).cgColor
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawGuideLines()
        switch kind {
        case "hammer": drawHammer(bullish: true)
        case "hangingMan": drawHangingMan()
        case "doji": drawDoji(longLegged: false)
        case "longLeggedDoji": drawLongLeggedDoji()
        case "gravestone": drawGravestone()
        case "dragonfly": drawDragonfly()
        case "marubozu": drawMarubozu()
        case "spinning": drawSpinningTop()
        case "lowerShadow": drawLongShadow(lower: true)
        case "upperShadow": drawLongShadow(lower: false)
        case "engulfingBull": drawEngulfing(bullish: true)
        case "engulfingBear": drawEngulfing(bullish: false)
        case "piercing": drawPair(secondBullish: true, strongSecond: true)
        case "darkCloud": drawPair(secondBullish: false, strongSecond: true)
        case "haramiBull", "haramiBear", "haramiCross": drawHarami()
        case "tweezerTop": drawTweezer(top: true)
        case "tweezerBottom": drawTweezer(top: false)
        case "gap": drawGap()
        case "separatingBull": drawPair(secondBullish: true, strongSecond: false)
        case "separatingBear": drawPair(secondBullish: false, strongSecond: false)
        case "morningStar": drawStar(bullish: true)
        case "eveningStar": drawStar(bullish: false)
        case "abandonedBaby": drawAbandonedBaby()
        case "threeBear": drawThree(soldiers: false)
        case "threeBull": drawThree(soldiers: true)
        case "risingThree": drawThreeMethods(rising: true)
        case "fallingThree": drawThreeMethods(rising: false)
        case "custom": drawCustom()
        default: drawDoji(longLegged: true)
        }
    }

    private func drawGuideLines() {
        NSColor.separatorColor.withAlphaComponent(0.20).setStroke()
        for frac in [0.25, 0.5, 0.75] {
            let y = bounds.height * CGFloat(frac)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 6, y: y))
            path.line(to: NSPoint(x: bounds.width - 6, y: y))
            path.lineWidth = 0.5
            path.stroke()
        }
    }

    private var bullColor: NSColor { NSColor.systemGreen.withAlphaComponent(0.92) }
    private var bearColor: NSColor { NSColor.systemRed.withAlphaComponent(0.90) }
    private var neutralColor: NSColor { NSColor.systemYellow.withAlphaComponent(0.92) }

    private func candle(x: CGFloat, bodyY: CGFloat, bodyH: CGFloat, wickLow: CGFloat, wickHigh: CGFloat, color: NSColor, width: CGFloat = 10) {
        color.setStroke()
        let wick = NSBezierPath()
        wick.move(to: NSPoint(x: x, y: wickLow))
        wick.line(to: NSPoint(x: x, y: wickHigh))
        wick.lineWidth = 1.2
        wick.stroke()
        color.setFill()
        let h = max(2, bodyH)
        NSBezierPath(roundedRect: NSRect(x: x - width / 2, y: bodyY, width: width, height: h), xRadius: 2, yRadius: 2).fill()
    }

    private func xs(_ values: Int) -> [CGFloat] {
        guard values > 1 else { return [bounds.midX] }
        // K线示意图按真实K线观感居中紧凑排列，不能铺满整个图标宽度。
        // 2/3/5 根组合都使用固定近距，避免两根线、三根线被拉得像分散图标。
        let gap = min(max(bounds.width * 0.13, 10), 14)
        let totalWidth = CGFloat(values - 1) * gap
        let startX = bounds.midX - totalWidth / 2
        return (0..<values).map { startX + CGFloat($0) * gap }
    }

    private func drawHammer(bullish: Bool) { candle(x: bounds.midX, bodyY: bounds.height * 0.58, bodyH: 13, wickLow: bounds.height * 0.16, wickHigh: bounds.height * 0.74, color: bullish ? bullColor : bearColor, width: 13) }

    private func drawHangingMan() {
        // 吊颈线与锤子线外形相近，但语义是上涨后顶部看跌，设置面板必须视觉区分。
        // 这里用红色长下影小实体 + 顶部压力线 + 小型上升波段提示，避免和锤子线一模一样。
        let topY = bounds.height * 0.79
        let left = bounds.midX - 18
        let right = bounds.midX + 18
        let resistance = NSBezierPath()
        resistance.move(to: NSPoint(x: left, y: topY))
        resistance.line(to: NSPoint(x: right, y: topY))
        bearColor.withAlphaComponent(0.82).setStroke()
        resistance.lineWidth = 1.4
        resistance.stroke()

        let trend = NSBezierPath()
        trend.move(to: NSPoint(x: bounds.midX - 22, y: bounds.height * 0.22))
        trend.line(to: NSPoint(x: bounds.midX - 10, y: bounds.height * 0.38))
        trend.line(to: NSPoint(x: bounds.midX - 2, y: bounds.height * 0.52))
        bearColor.withAlphaComponent(0.38).setStroke()
        trend.lineWidth = 1.1
        trend.stroke()

        candle(x: bounds.midX + 8, bodyY: bounds.height * 0.61, bodyH: 12, wickLow: bounds.height * 0.22, wickHigh: bounds.height * 0.76, color: bearColor, width: 13)
    }

    private func drawDoji(longLegged: Bool) { candle(x: bounds.midX, bodyY: bounds.midY - 1, bodyH: 2, wickLow: longLegged ? bounds.height * 0.15 : bounds.height * 0.30, wickHigh: longLegged ? bounds.height * 0.85 : bounds.height * 0.70, color: neutralColor, width: 18) }
    private func drawLongLeggedDoji() {
        // 长腿十字星：与普通十字星区分；按用户要求，下影更长、上影更短，仍保持十字实体极小。
        candle(x: bounds.midX, bodyY: bounds.height * 0.58, bodyH: 2, wickLow: bounds.height * 0.10, wickHigh: bounds.height * 0.78, color: neutralColor, width: 18)
    }
    private func drawGravestone() { candle(x: bounds.midX, bodyY: bounds.height * 0.28, bodyH: 2, wickLow: bounds.height * 0.26, wickHigh: bounds.height * 0.84, color: bearColor, width: 18) }
    private func drawDragonfly() { candle(x: bounds.midX, bodyY: bounds.height * 0.70, bodyH: 2, wickLow: bounds.height * 0.16, wickHigh: bounds.height * 0.72, color: bullColor, width: 18) }
    private func drawMarubozu() { candle(x: bounds.midX, bodyY: bounds.height * 0.22, bodyH: bounds.height * 0.56, wickLow: bounds.height * 0.22, wickHigh: bounds.height * 0.78, color: bullColor, width: 16) }
    private func drawSpinningTop() { candle(x: bounds.midX, bodyY: bounds.midY - 6, bodyH: 12, wickLow: bounds.height * 0.20, wickHigh: bounds.height * 0.82, color: neutralColor, width: 13) }
    private func drawLongShadow(lower: Bool) { candle(x: bounds.midX, bodyY: lower ? bounds.height * 0.58 : bounds.height * 0.34, bodyH: 12, wickLow: lower ? bounds.height * 0.12 : bounds.height * 0.32, wickHigh: lower ? bounds.height * 0.72 : bounds.height * 0.88, color: lower ? bullColor : bearColor, width: 13) }

    private func drawEngulfing(bullish: Bool) {
        let x = xs(2)
        candle(x: x[0], bodyY: bounds.height * (bullish ? 0.45 : 0.28), bodyH: bounds.height * 0.24, wickLow: bounds.height * 0.25, wickHigh: bounds.height * 0.75, color: bullish ? bearColor : bullColor, width: 10)
        candle(x: x[1], bodyY: bounds.height * (bullish ? 0.25 : 0.34), bodyH: bounds.height * 0.50, wickLow: bounds.height * 0.18, wickHigh: bounds.height * 0.82, color: bullish ? bullColor : bearColor, width: 16)
    }

    private func drawPair(secondBullish: Bool, strongSecond: Bool) {
        let x = xs(2)
        candle(x: x[0], bodyY: bounds.height * 0.34, bodyH: bounds.height * 0.36, wickLow: bounds.height * 0.24, wickHigh: bounds.height * 0.78, color: secondBullish ? bearColor : bullColor, width: 13)
        candle(x: x[1], bodyY: bounds.height * (secondBullish ? 0.28 : 0.30), bodyH: bounds.height * (strongSecond ? 0.42 : 0.34), wickLow: bounds.height * 0.18, wickHigh: bounds.height * 0.82, color: secondBullish ? bullColor : bearColor, width: 13)
    }

    private func drawHarami() {
        let x = xs(2)
        candle(x: x[0], bodyY: bounds.height * 0.24, bodyH: bounds.height * 0.54, wickLow: bounds.height * 0.18, wickHigh: bounds.height * 0.84, color: bearColor, width: 16)
        candle(x: x[1], bodyY: bounds.height * 0.44, bodyH: bounds.height * 0.16, wickLow: bounds.height * 0.36, wickHigh: bounds.height * 0.70, color: bullColor, width: 10)
    }

    private func drawTweezer(top: Bool) {
        let x = xs(2)
        candle(x: x[0], bodyY: top ? bounds.height * 0.45 : bounds.height * 0.26, bodyH: bounds.height * 0.22, wickLow: bounds.height * 0.20, wickHigh: top ? bounds.height * 0.82 : bounds.height * 0.68, color: top ? bullColor : bearColor, width: 11)
        candle(x: x[1], bodyY: top ? bounds.height * 0.36 : bounds.height * 0.38, bodyH: bounds.height * 0.24, wickLow: top ? bounds.height * 0.26 : bounds.height * 0.20, wickHigh: top ? bounds.height * 0.82 : bounds.height * 0.68, color: top ? bearColor : bullColor, width: 11)
    }

    private func drawGap() {
        let x = xs(2)
        candle(x: x[0], bodyY: bounds.height * 0.24, bodyH: bounds.height * 0.25, wickLow: bounds.height * 0.20, wickHigh: bounds.height * 0.56, color: bullColor, width: 12)
        candle(x: x[1], bodyY: bounds.height * 0.58, bodyH: bounds.height * 0.25, wickLow: bounds.height * 0.52, wickHigh: bounds.height * 0.88, color: bullColor, width: 12)
    }

    private func drawStar(bullish: Bool) {
        let x = xs(3)
        candle(x: x[0], bodyY: bullish ? bounds.height * 0.44 : bounds.height * 0.22, bodyH: bounds.height * 0.38, wickLow: bounds.height * 0.18, wickHigh: bounds.height * 0.86, color: bullish ? bearColor : bullColor, width: 13)
        candle(x: x[1], bodyY: bounds.midY - 2, bodyH: 4, wickLow: bounds.height * 0.38, wickHigh: bounds.height * 0.64, color: neutralColor, width: 9)
        candle(x: x[2], bodyY: bullish ? bounds.height * 0.22 : bounds.height * 0.44, bodyH: bounds.height * 0.38, wickLow: bounds.height * 0.16, wickHigh: bounds.height * 0.84, color: bullish ? bullColor : bearColor, width: 13)
    }

    private func drawAbandonedBaby() { drawStar(bullish: true) }
    private func drawThree(soldiers: Bool) {
        let x = xs(3)
        for i in 0..<3 {
            let base = soldiers ? (0.22 + CGFloat(i) * 0.10) : (0.55 - CGFloat(i) * 0.10)
            candle(x: x[i], bodyY: bounds.height * base, bodyH: bounds.height * 0.25, wickLow: bounds.height * (base - 0.08), wickHigh: bounds.height * (base + 0.34), color: soldiers ? bullColor : bearColor, width: 11)
        }
    }

    private func drawThreeMethods(rising: Bool) {
        let x = xs(5)
        candle(x: x[0], bodyY: rising ? bounds.height * 0.24 : bounds.height * 0.52, bodyH: bounds.height * 0.34, wickLow: bounds.height * 0.18, wickHigh: bounds.height * 0.86, color: rising ? bullColor : bearColor, width: 11)
        for i in 1...3 { candle(x: x[i], bodyY: bounds.height * (rising ? 0.46 : 0.34), bodyH: bounds.height * 0.12, wickLow: bounds.height * 0.30, wickHigh: bounds.height * 0.70, color: neutralColor.withAlphaComponent(0.80), width: 8) }
        candle(x: x[4], bodyY: rising ? bounds.height * 0.22 : bounds.height * 0.50, bodyH: bounds.height * 0.38, wickLow: bounds.height * 0.16, wickHigh: bounds.height * 0.88, color: rising ? bullColor : bearColor, width: 11)
    }

    private func drawCustom() {
        NSColor.systemBlue.withAlphaComponent(0.85).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 2
        path.move(to: NSPoint(x: bounds.width * 0.20, y: bounds.height * 0.35))
        path.line(to: NSPoint(x: bounds.width * 0.42, y: bounds.height * 0.66))
        path.line(to: NSPoint(x: bounds.width * 0.58, y: bounds.height * 0.44))
        path.line(to: NSPoint(x: bounds.width * 0.80, y: bounds.height * 0.72))
        path.stroke()
        let plus = NSBezierPath()
        plus.lineWidth = 2
        plus.move(to: NSPoint(x: bounds.midX - 8, y: bounds.midY))
        plus.line(to: NSPoint(x: bounds.midX + 8, y: bounds.midY))
        plus.move(to: NSPoint(x: bounds.midX, y: bounds.midY - 8))
        plus.line(to: NSPoint(x: bounds.midX, y: bounds.midY + 8))
        plus.stroke()
    }
}
