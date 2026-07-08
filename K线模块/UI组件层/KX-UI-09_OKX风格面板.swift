//
//  KX-UI-09_OKX风格面板.swift
//  仙人指路2-min|K线模块
//
//  版本:2.3
//  职责:K线模块主面板视图。组合:交易板块选择 + 币对选择 + 时间框架 + 指标占位 + 图表容器
//  禁止事项:禁止创建独立 NSWindow、禁止接管 App 生命周期、禁止 UI 直接查库/请求 OKX
//

import AppKit
import Foundation
import os.log

// 导入K线日志工具

// 日志实例
private let logger = klineLogger


// MARK: - K线 UI 主题桥接

public enum KLUITheme {
    // ⚠️ 2026-06-22:主题判断统一读取 UI 模块权威 GlassThemeHelper(包含手动切换的视觉主题 id),
    // 不再直读 NSApp.effectiveAppearance;否则手动切深色时 K线收不到、内容区不变色。
    public static var isDark: Bool {
        GlassThemeHelper.isDarkAppearance()
    }

    public static var panelBackground: NSColor {
        isDark ? NSColor(calibratedRed: 0.035, green: 0.039, blue: 0.050, alpha: 1) : NSColor.windowBackgroundColor
    }

    public static var toolbarBackground: NSColor {
        isDark ? NSColor(calibratedRed: 0.018, green: 0.020, blue: 0.026, alpha: 1) : NSColor.white
    }

    /// 二级功能栏背景：浅色主题比内容区略深，以区分一级栏(白)和内容区(灰白)；深色保持与一级栏一致
    public static var subToolbarBackground: NSColor {
        isDark ? NSColor(calibratedRed: 0.018, green: 0.020, blue: 0.026, alpha: 1) : NSColor(calibratedWhite: 0.88, alpha: 1)
    }

    // ⚠️ 2026-06-30:K线图表绘制层会用 chartBackground 直接 fill(bounds)。
    // 浅色主题不能直接使用 GlassThemeHelper.contentBackgroundColor() 的半透明玻璃色,
    // 否则 CoreGraphics 在 K线 CALayer 内叠加后会变成偏灰内容区。
    // 因此:深色继续跟随玻璃内容区;浅色使用与 UI 浅色界面一致的实底浅色。
    public static var chartBackground: NSColor {
        if isDark {
            return NSColor(cgColor: GlassThemeHelper.contentBackgroundColor())
                ?? NSColor(calibratedRed: 0.070, green: 0.078, blue: 0.094, alpha: 1)
        }
        // 浅色主题：与 UI 内容区域一致的灰白色
        return NSColor(calibratedWhite: 0.94, alpha: 1)
    }

    public static var gridColor: NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.10)
    }

    public static var axisText: NSColor {
        // ⚠️ 2026-06-30:K线轴文字/十字标签最终会转 CGColor 给 CALayer/CGContext。
        // 浅色主题不能用 NSColor.secondaryLabelColor 这类动态系统色;在 K线面板 appearance
        // 时序不一致时会被解析成白色,导致白底白字。这里改为显式深灰。
        isDark ? NSColor(calibratedWhite: 0.72, alpha: 1) : NSColor(calibratedWhite: 0.22, alpha: 1)
    }

    public static var candleUp: NSColor { NSColor.systemGreen }
    public static var candleDown: NSColor { NSColor.systemRed }
    public static var crosshair: NSColor { isDark ? NSColor.white.withAlphaComponent(0.90) : NSColor.black.withAlphaComponent(0.70) }
    public static var splitter: NSColor { isDark ? NSColor.white.withAlphaComponent(0.32) : NSColor.black.withAlphaComponent(0.22) }
}

// MARK: - 主面板 View 扩展(主实现在 KX-UI-08)

public extension KXUI09KLinePanelView {
    /// 初始化面板布局(含两级菜单工具栏)
    func setupPanelLayout() {
        if toolbarView != nil, chartContainer != nil { return }
        wantsLayer = true
        applyPanelTheme()

        // ✅ 玻璃皮肤效果由 UIContainerView(UI模块)统一提供
        // ❌ 不需要自己再加一层玻璃效果,两层叠加会变成白板
        // 只需要设置面板自己背景透明就好了
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // 1. 币对标签栏
        let tabBar = KXUI10PairTabBarView(frame: .zero)
        tabBar.wantsLayer = true
        tabBar.layer?.backgroundColor = KLUITheme.toolbarBackground.cgColor
        tabBar.autoresizingMask = [.width, .minYMargin]
        tabBar.tabs = [panelContext.initialInstrumentID, "ETH-USDT", "SOL-USDT", "DOGE-USDT"]
        tabBar.activeTabID = panelContext.initialInstrumentID
        tabBar.onTabSelected = { [weak self] instID in
            logger.info("[KLine][UI][Panel] onTabSelected instID=\(instID)")
            self?.switchInstrument(instID)
        }
        tabBar.onTabClosed = { [weak self] instID in
            logger.info("[KLine][UI][Panel] onTabClosed instID=\(instID)")
            self?.closeInstrumentTab(instID)
        }
        tabBar.onCollapseRequested = {
            UIDockingManager.shared.togglePanelExpandCollapse("KL_Main")
        }
        addSubview(tabBar)

        // 2. 工具栏
        let toolbar = NSView(frame: .zero)
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = KLUITheme.subToolbarBackground.cgColor
        toolbar.autoresizingMask = [.width, .minYMargin]
        addSubview(toolbar)
        toolbarView = toolbar
        buildToolbarContent(in: toolbar)

        // 3. 图表容器
        let chartArea = NSView(frame: .zero)
        chartArea.wantsLayer = true
        chartArea.layer?.backgroundColor = KLUITheme.chartBackground.cgColor
        chartArea.autoresizingMask = [.width, .height]
        addSubview(chartArea)
        chartContainer = chartArea

        let initialTimeframe = timeframeForInstrument(panelContext.initialInstrumentID)
        let openedSymbols = tabBar.tabs
        logger.info("[KLine][Panel] initial sync openedSymbols=\(openedSymbols.joined(separator: ",")) active=\(panelContext.initialInstrumentID) timeframe=\(initialTimeframe.rawValue)")
        rememberTimeframe(initialTimeframe, for: panelContext.initialInstrumentID)
        KLDefaultStartupPipeline.shared.syncOpenedSymbols(timeframeBySymbol: timeframeMap(for: openedSymbols), activeSymbol: panelContext.initialInstrumentID, orderedSymbols: openedSymbols)
        // 多画布:初始画布也走统一的 showCanvas 创建+加载;随后错峰预建当前可见周期。
        showCanvas(symbol: panelContext.initialInstrumentID, timeframe: initialTimeframe)
        scheduleVisibleCanvasPrebuild(symbol: panelContext.initialInstrumentID, visibleTimeframes: activeVisibleTimeframes(), selectedTimeframe: initialTimeframe)

        setupDockingStateObservers()
        // ⚠️ 2026-06-22:调用 UI 模块统一主题监听机制(K线不自建监听)。
        // 手动切换主题 / 系统深浅切换时,UI 模块会回调此闭包,统一刷新面板+工具栏+标签栏+画布。
        UIThemeSwitchManager.shared.registerThemeAwareView(self) { [weak self] in
            self?.refreshKLineThemeColors()
        }
        layoutSubtreeIfNeeded()
        logPanelSnapshot()
    }

    /// ⚠️ 2026-06-22:主题变化时统一刷新 K线所有颜色(由 UI 模块主题监听机制回调驱动)。
    func refreshKLineThemeColors() {
        applyPanelTheme()
        // 工具栏内部控件(按钮/选择器)刷新
        (toolbarView as? KXUI18ToolbarView)?.refreshTheme()
        // 一级标签栏按钮刷新
        subviews.compactMap { $0 as? KXUI10PairTabBarView }.first?.refreshTheme()
    }

    /// 构建工具栏内部子视图
    private func buildToolbarContent(in toolbar: NSView) {
        let toolbarView = KXUI18ToolbarView(frame: .zero)
        toolbarView.autoresizingMask = [.width, .height]
        toolbarView.onMarketTypeChanged = { [weak self] type in
            guard let self = self else { return }
            self.onMarketTypeChanged?(type)
            logger.info("[KLine][Panel] marketType changed type=\(type.rawValue)")
        }
        toolbarView.onInstrumentSelected = { [weak self] instID in
            guard let self = self else { return }
            self.openInstrumentTab(instID)
        }
        toolbarView.onTimeframeSelected = { [weak self] timeframe in
            guard let self = self else { return }
            self.switchTimeframe(timeframe)
        }
        toolbarView.onVisibleTimeframesChanged = { [weak self] timeframes in
            guard let self = self else { return }
            self.handleVisibleTimeframesChanged(timeframes)
        }
        toolbarView.onIndicatorSelected = { [weak self] indicator in
            guard let self = self else { return }
            self.indicatorButtonClicked(indicator)
        }
        toolbarView.onDisplaySettingsChanged = { [weak self] settings in
            guard let self = self else { return }
            self.onDisplaySettingsChanged?(settings)
        }
        toolbarView.onMinimizeToggled = { [weak self] _ in
            // 二级栏旧按钮后端逻辑已掐掉:状态强制复位,折叠入口统一交给一级栏新按钮。
            guard let toolbarView = self?.toolbarView as? KXUI18ToolbarView else { return }
            toolbarView.setMinimized(false)
        }
        toolbar.addSubview(toolbarView)
        self.toolbarView = toolbarView
    }

    /// 布局子视图
    func layoutPanelSubviews(tabBarHeight: CGFloat = 44) {
        let bounds = self.bounds
        let minimized = isPanelMinimized()
        let tbH: CGFloat = tabBarHeight
        let toolH: CGFloat = minimized ? 0 : 32

        if let tabBar = subviews.compactMap({ $0 as? KXUI10PairTabBarView }).first {
            // 顶部锚定:一级功能栏永远贴住面板顶部,不随下方图表区伸缩漂移。
            tabBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: tbH)
        }

        if let toolbar = toolbarView {
            // toolbarView 保存的是二级功能栏内部的 KXUI18ToolbarView;它外面还有一层 toolbar 宿主 NSView。
            // 必须移动宿主视图,而不是把内部工具栏直接按面板坐标摆放,否则宿主层仍受旧 autoresizing 影响,视觉上会漂移。
            let toolbarHost = (toolbar.superview?.superview === self) ? toolbar.superview : toolbar
            toolbarHost?.frame = CGRect(x: 0, y: tbH, width: bounds.width, height: toolH)
            if let toolbarHost { layoutToolbarContent(in: toolbarHost) }
        }

        if let chart = chartContainer {
            // 只有图表区域承接面板缩放后的剩余高度。
            let chartHeight = max(0, bounds.height - tbH - toolH)
            chart.frame = CGRect(x: 0, y: tbH + toolH, width: bounds.width, height: chartHeight)
            // 多画布:所有画布都跟随容器 bounds(隐藏的也要,下次显示才不错位)。
            for c in canvasByKey.values { c.frame = chart.bounds }
        }
    }

    override func layout() {
        super.layout()
        layoutPanelSubviews()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // 统一走全量刷新(含工具栏内部控件与一级标签栏),避免只刷一半造成凌乱。
        refreshKLineThemeColors()
    }

    private func layoutToolbarContent(in toolbar: NSView) {
        let bw = toolbar.bounds.width
        let h = toolbar.bounds.height

        if let toolbarView = toolbar.subviews.compactMap({ $0 as? KXUI18ToolbarView }).first {
            toolbarView.frame = CGRect(x: 0, y: 0, width: bw, height: h)
        }
    }

    private func applyPanelTheme() {
        // ⚠️ 2026-06-23:启动时两套主题源(全局 NSApp.appearance 与权威 GlassThemeHelper)可能不同步,
        // 导致 K线深色背景叠加跟随全局 aqua 的黑色文字 → 黑底黑字看不见。
        // 这里把 K线面板子树的 appearance 钉死为权威主题 appearance,
        // 使按钮/标签文字等动态颜色按权威主题解析(深色→白字),与背景一致。
        appearance = GlassThemeHelper.nsAppearance()

        layer?.backgroundColor = KLUITheme.panelBackground.cgColor

        // 更新所有子视图的主题
        toolbarView?.layer?.backgroundColor = KLUITheme.subToolbarBackground.cgColor
        chartContainer?.layer?.backgroundColor = KLUITheme.chartBackground.cgColor
        subviews.compactMap { $0 as? KXUI10PairTabBarView }.first?.layer?.backgroundColor = KLUITheme.toolbarBackground.cgColor
        canvasByKey.values.forEach { $0.applyTheme() }
    }

    private func onDisplaySettingsChanged(_ settings: [String: Any]) {
        // 处理显示设置变更(多画布:应用到所有画布保持一致)
        if let gridEnabled = settings["grid"] as? Bool {
            canvasByKey.values.forEach { $0.showGrid(gridEnabled) }
        }
        if let crosshairEnabled = settings["crosshair"] as? Bool {
            canvasByKey.values.forEach { $0.showCrosshair(crosshairEnabled) }
        }
        if let volumeEnabled = settings["volume"] as? Bool {
            canvasByKey.values.forEach { $0.showVolumePanel(volumeEnabled) }
        }
        if let theme = settings["theme"] as? String {
            applyTheme(theme)
        }
    }

    private func applyTheme(_ theme: String) {
        // 应用主题变更
        switch theme {
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "system":
            NSApp.appearance = nil
        default:
            break
        }
    }

    // MARK: - 面板最小化功能

    private func setupDockingStateObservers() {
        NotificationCenter.default.addObserver(forName: .kxKLineDockingTransitionWillBegin, object: nil, queue: .main) { [weak self] note in
            guard (note.userInfo?["panelID"] as? String) == "KL_Main" else { return }
            let collapsed = note.userInfo?["collapsed"] as? Bool ?? false
            self?.prepareDockingTransition(collapsed: collapsed)
        }
        NotificationCenter.default.addObserver(forName: .dockablePanelDidCollapse, object: nil, queue: .main) { [weak self] note in
            guard (note.userInfo?["panelID"] as? String) == "KL_Main" else { return }
            self?.applyDockingState(collapsed: true)
        }
        NotificationCenter.default.addObserver(forName: .dockablePanelDidExpand, object: nil, queue: .main) { [weak self] note in
            guard (note.userInfo?["panelID"] as? String) == "KL_Main" else { return }
            self?.applyDockingState(collapsed: false)
        }
    }

    private func prepareDockingTransition(collapsed: Bool) {
        activeTabBar()?.isHidden = false
        activeTabBar()?.alphaValue = 1.0

        if collapsed {
            // 折叠动画开始前不能先隐藏 body;否则 UI 模块没有"从二级功能栏开始往上收"的动画对象,
            // 视觉上就只剩外层容器带着一级栏变化。这里保持二级栏和图表可见,交给 UI 模块从 fixedHeader 下口裁剪收起。
            panelIsMinimized = false
            activeTabBar()?.setCollapsedVisualState(true)
            toolbarView?.superview?.isHidden = false
            chartContainer?.isHidden = false
            toolbarView?.superview?.alphaValue = 1
            chartContainer?.alphaValue = 1
            needsLayout = true
            layoutPanelSubviews()
            layoutSubtreeIfNeeded()
        } else {
            // 展开动画开始前也先恢复 body,让 UI 模块从一级栏下口往下弹出内容区。
            panelIsMinimized = false
            activeTabBar()?.setCollapsedVisualState(false)
            toolbarView?.superview?.isHidden = false
            chartContainer?.isHidden = false
            toolbarView?.superview?.alphaValue = 1
            chartContainer?.alphaValue = 1
            needsLayout = true
            layoutPanelSubviews()
            layoutSubtreeIfNeeded()
        }
    }

    private func togglePanelMinimization(_ isMinimized: Bool) {
        // 兼容旧入口:业务模块不直接实现折叠,只向 UI 模块提交折叠/展开请求。
        if isMinimized {
            UIDockingManager.shared.collapsePanel("KL_Main")
        } else {
            UIDockingManager.shared.expandPanel("KL_Main")
        }
    }

    private func applyDockingState(collapsed: Bool) {
        panelIsMinimized = collapsed
        activeTabBar()?.setCollapsedVisualState(collapsed)
        if collapsed {
            toolbarView?.superview?.isHidden = true
            chartContainer?.isHidden = true
            toolbarView?.superview?.alphaValue = 0
            chartContainer?.alphaValue = 0
            needsLayout = true
            layoutPanelSubviews()
            layoutSubtreeIfNeeded()
        } else {
            toolbarView?.superview?.isHidden = false
            chartContainer?.isHidden = false
            toolbarView?.superview?.alphaValue = 0
            chartContainer?.alphaValue = 0
            needsLayout = true
            layoutPanelSubviews()
            layoutSubtreeIfNeeded()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.toolbarView?.superview?.animator().alphaValue = 1
                self.chartContainer?.animator().alphaValue = 1
            }
        }
        if let toolbarView = toolbarView as? KXUI18ToolbarView {
            toolbarView.setMinimized(false)
        }
    }

    func isPanelMinimized() -> Bool {
        panelIsMinimized
    }

    private func activeTabBar() -> KXUI10PairTabBarView? {
        subviews.compactMap { $0 as? KXUI10PairTabBarView }.first
    }

    private func activeTimeframeSelector() -> KXUI11TimeframeSelectorView? {
        func find(in view: NSView?) -> KXUI11TimeframeSelectorView? {
            guard let view else { return nil }
            if let tf = view as? KXUI11TimeframeSelectorView { return tf }
            for sub in view.subviews { if let found = find(in: sub) { return found } }
            return nil
        }
        return find(in: toolbarView)
    }

    private func activeVisibleTimeframes() -> [KXTimeframe] {
        // 读当前币对自己的可见集合(每币对独立),不再依赖全局选择器单一属性。
        let instID = activeTabBar()?.activeTabID ?? panelContext.initialInstrumentID
        return visibleTimeframesForInstrument(instID)
    }

    /// 顶部快捷周期集合变化:新增周期=为当前币对建画布并加载一次;移除周期=销毁该(币对×周期)画布。
    /// 注意:聚合器按币对订阅trades,移除单个周期不退订该币对。
    private func handleVisibleTimeframesChanged(_ timeframes: [KXTimeframe]) {
        let instID = activeTabBar()?.activeTabID ?? panelContext.initialInstrumentID
        // 关键:只保存到当前币对自己的可见集合,不影响其他币对。
        rememberVisibleTimeframes(timeframes, for: instID)
        let next = Set(timeframes.map { $0.rawValue })
        let existingKeys = canvasByKey.keys.filter { $0.hasPrefix("\(instID)|") }
        for key in existingKeys {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if !next.contains(parts[1]), let tf = KXTimeframe(rawValue: parts[1]) {
                destroyCanvas(symbol: instID, timeframe: tf)
            }
        }
        // 新增周期:当前周期立即显示/确保存在,其余周期错峰预建,避免一次性卡死。
        var current = timeframeForInstrument(instID)
        if !timeframes.contains(current), let first = timeframes.first {
            current = first
            rememberTimeframe(first, for: instID)
            activeTimeframeSelector()?.selectedTimeframe = first
        }
        _ = showCanvas(symbol: instID, timeframe: current)
        scheduleVisibleCanvasPrebuild(symbol: instID, visibleTimeframes: timeframes, selectedTimeframe: current)
        logger.info("[KLine][Canvas] visible timeframes changed instID=\(instID) count=\(timeframes.count)")
    }

    private func openInstrumentTab(_ instID: String) {
        guard let tabBar = activeTabBar() else { return }
        if !tabBar.tabs.contains(instID) {
            tabBar.tabs.append(instID)
            rememberTimeframe(timeframeForInstrument(instID), for: instID)
        }
        tabBar.activeTabID = instID
        tabBar.needsLayout = true
        switchInstrument(instID)
    }

    private func closeInstrumentTab(_ instID: String) {
        guard let tabBar = activeTabBar() else { return }
        // K线模块必须至少保留一个有效标签;最后一个标签不允许关闭,避免 activeTabID 为空或指向已删除标签。
        guard tabBar.tabs.count > 1 else {
            logger.info("[KLine][Panel] ignore close last tab instID=\(instID)")
            return
        }
        guard let closingIndex = tabBar.tabs.firstIndex(of: instID) else { return }

        let oldTabs = tabBar.tabs
        let remainingTabs = oldTabs.filter { $0 != instID }
        guard !remainingTabs.isEmpty else { return }

        let shouldSwitchActive = tabBar.activeTabID == instID || !remainingTabs.contains(tabBar.activeTabID)
        let nextActive: String = {
            if !shouldSwitchActive { return tabBar.activeTabID }
            let preferredIndex = min(closingIndex, remainingTabs.count - 1)
            return remainingTabs[preferredIndex]
        }()

        // 先写入新的 tabs,再写入一个一定存在于 tabs 中的 activeTabID。
        // 标签栏 updateHighlight 已做下标保护,但这里仍保持状态一致,避免 UI/同步管道读到已删除 active。
        tabBar.tabs = remainingTabs
        tabBar.activeTabID = nextActive
        tabBar.needsLayout = true

        forgetTimeframe(for: instID)
        // 多画布改造:关闭币对标签时发退订信号,聚合器不再为该币对算 K线(其他币对不受影响)。
        KLOKXRealtimeKLineRuntime.shared.unsubscribe(symbol: instID)
        // 销毁该币对的所有周期画布(释放内存)。
        destroyCanvases(forSymbol: instID)
        if shouldSwitchActive {
            switchInstrument(nextActive)
        } else {
            KLDefaultStartupPipeline.shared.syncOpenedSymbols(timeframeBySymbol: timeframeMap(for: remainingTabs), activeSymbol: nextActive, orderedSymbols: remainingTabs)
        }
        persistLayoutState()
        logPanelSnapshot()
    }

    // MARK: - 多画布管理(一个 币对×周期 = 一张独立画布)

    private func canvasKey(_ symbol: String, _ timeframe: KXTimeframe) -> String {
        "\(symbol)|\(timeframe.rawValue)"
    }

    /// 显示某 (币对×周期) 的画布:已存在直接显示(不重画/不读库),不存在则新建并加载一次画好。
    /// 切换 = 目标 isHidden=false、其余 isHidden=true。隐藏画布数据仍由各自实时观察者保持新鲜,但隐藏期间不会真正重绘(AppKit 隐藏视图延迟绘制)。
    @discardableResult
    private func showCanvas(symbol: String, timeframe: KXTimeframe, makeVisible: Bool = true) -> KXUI12KLineChartView? {
        logger.info("[KLine][UI][Panel] showCanvas symbol=\(symbol) tf=\(timeframe.rawValue) makeVisible=\(makeVisible) existing=\(canvasByKey.count)")
        guard let container = chartContainer else { return nil }
        let key = canvasKey(symbol, timeframe)
        var map = canvasByKey
        let canvas: KXUI12KLineChartView
        var isNew = false
        if let existing = map[key] {
            canvas = existing
        } else {
            let c = KXUI12KLineChartView(frame: container.bounds)
            c.autoresizingMask = [.width, .height]
            c.symbol = symbol
            c.timeframe = timeframe
            container.addSubview(c)
            map[key] = c
            canvasByKey = map
            canvas = c
            isNew = true
        }
        if makeVisible {
            // 显隐切换:只显示目标画布,其余隐藏(不销毁、不重画)。
            for (k, c) in map { c.isHidden = (k != key) }
            // 目标画布置顶 z-order:消除多画布叠加时的层级不确定(间歇性"切了但没显示"的根源)。
            // 用 macOS 原生 reorder API,不是 UI-GL-70 那种先 remove 后取 nil superview 的错误写法。
            if canvas.superview === container {
                container.addSubview(canvas, positioned: .above, relativeTo: nil)
            }
            // 当前可见画布 = 各功能(主题/指标/光标/成交量/置顶)转发目标。
            klineChartView = canvas
        } else {
            // 预建画布:先隐藏加载/画好,不抢当前显示。
            canvas.isHidden = true
        }
        canvas.frame = container.bounds
        if isNew {
            canvas.applyTheme()
            // 同步同一币对最新指标到新画布（收集所有其他画布的指标并集）
            let allIDs = canvasByKey
                .filter { $0.key.hasPrefix("\(symbol)|") && $0.value !== canvas }
                .reduce(Set<String>()) { $0.union($1.value.currentProfessionalIndicatorInstanceIDs) }
            if !allIDs.isEmpty {
                canvas.syncProfessionalIndicatorInstanceIDs(allIDs)
                // 不在这里预计算指标：新画布 candles 尚为空，预算会导致空数据 overlay 闪烁。
                // 指标计算推迟到 loadLatestCandlesFromDatabaseOrOKX 数据加载后，由 candles.didSet 自动触发 refreshData。
                canvas.loadPersistedProfessionalIndicators()
                logger.info("[KLine][Canvas] synced \(allIDs.count) indicators to new canvas \(key)")
            } else {
                canvas.loadPersistedProfessionalIndicators()
            }
            // 多画布叠在同一 container 靠 isHidden 切换，不需要"点击置顶"；
            // 且 UI-GL-70 handleClickForBringToFront 先 removeFromSuperview 后取 superview(已nil)，
            // 会把画布永久移出视图树导致不显示，故画布不注册点击置顶。
            // 仅首次创建时加载一次，把闭合K线画好；之后切回来直接显示，不再读库重画。
            // 预建画布(makeVisible=false)只 hydrate 限行出图，不触发 syncTimeframe 重路径(REST全量补缺口+全量查库)；
            // 补缺口等用户真正切到该周期(makeVisible=true)时再做，避免启动期 6 个周期同时拉网+全 parse。
            canvas.loadLatestCandlesFromDatabaseOrOKX(symbol: symbol, timeframe: timeframe, triggerSyncIfMissing: makeVisible)
            var pk = prebuiltOnlyKeys
            if makeVisible { pk.remove(key) } else { pk.insert(key) }
            prebuiltOnlyKeys = pk
            let mode = makeVisible ? "create+load" : "prebuild+load"
            logger.info("[KLine][Canvas] \(mode) symbol=\(symbol) timeframe=\(timeframe.rawValue) total=\(self.canvasByKey.count)")
        } else if makeVisible {
            // 隐藏期间可能收过 tick(只更新了数据未绘制),显示时补一次刷新同步画面。
            canvas.refreshIfNeededOnShow()
            // 强制立即重绘:消除 AppKit 隐藏视图变可见时"不立即刷新"导致的间歇性切不过去(需点几次)。
            canvas.needsDisplay = true
            canvas.displayIfNeeded()
            
            // 关键修复：同步同一币对最新指标实例到新/旧画布，确保切换时间框架后指标一致
            let allIDs = canvasByKey
                .filter { $0.key.hasPrefix("\(symbol)|") && $0.value !== canvas }
                .reduce(Set<String>()) { $0.union($1.value.currentProfessionalIndicatorInstanceIDs) }
            if !allIDs.isEmpty {
                let currentIDs = canvas.currentProfessionalIndicatorInstanceIDs
                let missingIDs = allIDs.subtracting(currentIDs)
                if !missingIDs.isEmpty {
                    canvas.syncProfessionalIndicatorInstanceIDs(missingIDs)
                    canvas.loadPersistedProfessionalIndicators()
                    canvas.recalculateAllProfessionalIndicators()
                    canvas.rebuildIndicatorHeader()
                    canvas.reloadExternalOverlays()
                    logger.info("[KLine][Canvas] synced \(missingIDs.count) missing indicators to existing canvas \(key)")
                }
            }
            
            // 诊断日志:切回某周期后该画布真实状态。
            logger.info("[KLine][DIAG] show cached symbol=\(symbol) tf=\(timeframe.rawValue) candles=\(canvas.candles.count) isHidden=\(canvas.isHidden) inSuper=\(canvas.superview != nil) frame=\(NSStringFromRect(canvas.frame)) containerBounds=\(NSStringFromRect(container.bounds))")
            // 若该周期之前只预建未补缺口,现在用户真正看了,补一次 syncTimeframe(补关机期间缺口)。
            if prebuiltOnlyKeys.contains(key) {
                var pk = prebuiltOnlyKeys; pk.remove(key); prebuiltOnlyKeys = pk
                KLDefaultStartupPipeline.shared.syncTimeframe(symbol: symbol, timeframe: timeframe)
                logger.info("[KLine][Canvas] backfill-sync on first show symbol=\(symbol) timeframe=\(timeframe.rawValue)")
            }
            logger.info("[KLine][Canvas] show cached symbol=\(symbol) timeframe=\(timeframe.rawValue) (no redraw)")
        } else {
            logger.info("[KLine][Canvas] prebuild cached symbol=\(symbol) timeframe=\(timeframe.rawValue)")
        }
        return canvas
    }

    /// 销毁某币对的所有周期画布(关闭币对标签时调用)。
    private func destroyCanvases(forSymbol symbol: String) {
        var map = canvasByKey
        let prefix = "\(symbol)|"
        var removed = 0
        var pk = prebuiltOnlyKeys
        for (k, c) in map where k.hasPrefix(prefix) {
            c.removeFromSuperview()   // 触发 deinit:移除该画布自己的观察者(已不再误停全局引擎)
            map.removeValue(forKey: k)
            pk.remove(k)              // 同步清理预建脏标记,避免销毁后重建触发多余 backfill sync。
            removed += 1
        }
        canvasByKey = map
        prebuiltOnlyKeys = pk
        if removed > 0 { logger.info("[KLine][Canvas] destroy symbol=\(symbol) removed=\(removed) remaining=\(map.count)") }
    }

    /// 销毁某 (币对×周期) 单张画布(取消勾选某周期时调用;不影响该币对其他周期画布)。
    private func destroyCanvas(symbol: String, timeframe: KXTimeframe) {
        var map = canvasByKey
        let key = canvasKey(symbol, timeframe)
        if let c = map[key] {
            c.removeFromSuperview()
            map.removeValue(forKey: key)
            canvasByKey = map
            var pk = prebuiltOnlyKeys; pk.remove(key); prebuiltOnlyKeys = pk   // 同步清理预建脏标记
            logger.info("[KLine][Canvas] destroy single \(key) remaining=\(map.count)")
        }
    }

    /// 错峰预建当前币对的所有可见周期画布。
    /// 当前可见画布优先立即 showCanvas;剩余周期串行、每张间隔 0.2s,避免一次性建多张卡 UI。
    private func scheduleVisibleCanvasPrebuild(symbol: String, visibleTimeframes: [KXTimeframe], selectedTimeframe: KXTimeframe) {
        canvasPrebuildGeneration += 1
        let generation = canvasPrebuildGeneration
        let normalized = visibleTimeframes.isEmpty ? [selectedTimeframe] : visibleTimeframes
        let ordered = ([selectedTimeframe] + normalized).reduce(into: [KXTimeframe]()) { acc, tf in
            if !acc.contains(tf) { acc.append(tf) }
        }
        logger.info("[KLine][Canvas] prebuild schedule symbol=\(symbol) selected=\(selectedTimeframe.rawValue) count=\(ordered.count) generation=\(generation)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            var firstPrebuilt = true
            for tf in ordered {
                if self.canvasPrebuildGeneration != generation { return }
                if tf == selectedTimeframe {
                    // selected 已由 switch/show 负责,确保存在即可。
                    if self.canvasByKey[self.canvasKey(symbol, tf)] == nil { _ = self.showCanvas(symbol: symbol, timeframe: tf, makeVisible: true) }
                    continue
                }
                if self.canvasByKey[self.canvasKey(symbol, tf)] != nil { continue }
                // 首张预建前先静置,让首图绘制+启动同步先消化;之后每张 0.6s 慢铺,不集中各错峰。
                let napNs: UInt64 = firstPrebuilt ? 2_500_000_000 : 1_000_000_000
                firstPrebuilt = false
                try? await Task.sleep(nanoseconds: napNs)
                if self.canvasPrebuildGeneration != generation { return }
                _ = self.showCanvas(symbol: symbol, timeframe: tf, makeVisible: false)
            }
            logger.info("[KLine][Canvas] prebuild finished symbol=\(symbol) generation=\(generation) total=\(self.canvasByKey.count)")
        }
    }

    private func switchInstrument(_ instID: String) {
        let timeframe = timeframeForInstrument(instID)
        guard lastSwitchedInstrumentID != instID || lastSwitchedTimeframe != timeframe else {
            logger.info("[KLine][Panel] ignore duplicate switch instrument instID=\(instID) timeframe=\(timeframe.rawValue)")
            return
        }
        lastSwitchedInstrumentID = instID
        lastSwitchedTimeframe = timeframe
        // 切币对时恢复该币对自己的选中周期 + 可见周期集合,不用全局选择器当前值。
        let visibleTFs = visibleTimeframesForInstrument(instID)
        if let selector = activeTimeframeSelector() {
            selector.visibleTimeframes = visibleTFs   // 恢复顶部快捷栏为该币对自己的集合
            selector.selectedTimeframe = timeframe
        }
        let openedSymbols = activeTabBar()?.tabs ?? [instID]
        let allVisibleReady = visibleTFs.allSatisfy { canvasByKey[canvasKey(instID, $0)] != nil }
        logger.info("[KLine][Panel] switch instrument sync openedSymbols=\(openedSymbols.joined(separator: ",")) active=\(instID) timeframe=\(timeframe.rawValue) visible=\(visibleTFs.count) allVisibleReady=\(allVisibleReady)")
        KLOKXRealtimeKLineRuntime.shared.setOpenedSymbols(openedSymbols, activeSymbol: instID, activeTimeframe: timeframe)
        if !allVisibleReady {
            KLDefaultStartupPipeline.shared.syncOpenedSymbols(timeframeBySymbol: timeframeMap(for: openedSymbols), activeSymbol: instID, orderedSymbols: openedSymbols)
        }
        // 多画布:切到该(币对×周期)画布(已存在直接显示不重画),随后错峰预建该币对可见周期。
        showCanvas(symbol: instID, timeframe: timeframe)
        scheduleVisibleCanvasPrebuild(symbol: instID, visibleTimeframes: visibleTFs, selectedTimeframe: timeframe)
        logPanelSnapshot()
    }

    private func switchTimeframe(_ timeframe: KXTimeframe) {
        let instID = activeTabBar()?.activeTabID ?? panelContext.initialInstrumentID
        guard lastSwitchedInstrumentID != instID || lastSwitchedTimeframe != timeframe else {
            logger.info("[KLine][Panel] ignore duplicate switch timeframe instID=\(instID) timeframe=\(timeframe.rawValue)")
            return
        }
        lastSwitchedInstrumentID = instID
        lastSwitchedTimeframe = timeframe
        rememberTimeframe(timeframe, for: instID)
        // 切周期只更新当前币对自己的周期;若画布已缓存,不再触发数据同步/读库。
        let openedSymbols = activeTabBar()?.tabs ?? [instID]
        let existed = canvasByKey[canvasKey(instID, timeframe)] != nil
        logger.info("[KLine][Panel] switch timeframe sync-visible openedSymbols=\(openedSymbols.joined(separator: ",")) active=\(instID) timeframe=\(timeframe.rawValue) cached=\(existed)")
        KLOKXRealtimeKLineRuntime.shared.setOpenedSymbols(openedSymbols, activeSymbol: instID, activeTimeframe: timeframe)
        // 多画布:切到该(币对×周期)画布;sync 决策统一收敛到 showCanvas(isNew可见→loadLatest触发;预建后首次显示→backfill-sync),不在这里重复调。
        // 不再 post .KLChartTimeframeSelected:每张画布周期固定,全局通知会让同币对多周期画布互抢。
        showCanvas(symbol: instID, timeframe: timeframe)
        scheduleVisibleCanvasPrebuild(symbol: instID, visibleTimeframes: activeVisibleTimeframes(), selectedTimeframe: timeframe)
        logPanelSnapshot()
    }

    /// 指标按钮点击
    func indicatorButtonClicked(_ indicator: KLTechnicalIndicator) {
        logger.info("[KLine][UI][Panel] indicatorButtonClicked type=\(indicator)")
        guard let chartView = klineChartView else { return }
        chartView.addTechnicalIndicator(indicator)
        logger.info("[KLine] 已添加指标到图表: \(indicator.name)")
        logPanelSnapshot()
    }

    // MARK: - 点击置顶功能

    /// 为面板的所有子视图添加点击置顶功能
    func setupAllClickToFront() {
        // 为标签栏添加点击置顶
        if let tabBar = subviews.compactMap({ $0 as? KXUI10PairTabBarView }).first {
            tabBar.addClickToFront()
        }

        // 为工具栏添加点击置顶
        if let toolbar = toolbarView {
            toolbar.addClickToFront()
        }

        // 为图表容器添加点击置顶
        if let chartContainer = chartContainer {
            chartContainer.addClickToFront()
        }

        // 图表画布不加点击置顶:多画布叠加靠 isHidden 切换,UI-GL-70 的置顶会把画布移出视图树。
        _ = klineChartView

        logger.info("[KLine] K线面板所有子视图已添加点击置顶功能")
    }

    /// 清理面板
    func cleanupPanelExtended() {
        subviews.forEach { $0.removeFromSuperview() }
    }

    // MARK: - 状态持久化


    private func enclosingKLineContainer() -> NSView? {
        var view: NSView? = self
        while let current = view {
            if current.identifier?.rawValue == "KL_Main" || String(describing: type(of: current)).contains("UIContainerView") {
                return current
            }
            view = current.superview
        }
        return nil
    }

    /// 保存当前面板布局状态
    func persistLayoutState() {
        guard let containerView = enclosingKLineContainer() else {
            return
        }

        let windowID = "KL_Main"
        let frame = containerView.frame
        let isMiniaturized = UIDockingManager.shared.getPanel("KL_Main")?.isExpanded == false

        // 1. 容器 frame 统一保存到 UISerializationManager（与 openPanel() 同一数据源，避免双重持久化不一致）
        UISerializationManager.shared.saveContainerFrame(
            identifier: windowID,
            frame: frame
        )

        // 2. 面板内部状态保存到 UIWorkspaceManager（币对、周期、标签等）
        let windowState = UIPersistentWindowStateModel(
            windowID: windowID,
            frame: frame,
            isVisible: containerView.isHidden == false,
            isMainWindow: false,
            screenIdentifier: nil,
            isFullScreen: false,
            isMiniaturized: isMiniaturized
        )

        let panelState = exportState()

        let moduleState = UIModuleStateModel(
            moduleName: "kline",
            windowID: windowID,
            position: frame.origin,
            size: frame.size,
            isVisible: containerView.isHidden == false,
            configuration: panelState,
            zIndex: 0
        )

        UIWorkspaceManager.shared.saveCurrentState(
            layoutName: "K线模块",
            symbol: activeTabBar()?.activeTabID ?? panelContext.initialInstrumentID,
            period: activeTimeframeSelector()?.selectedTimeframe.rawValue ?? "1h",
            colorScheme: KLUITheme.isDark ? "dark" : "light",
            windowStates: [windowID: windowState],
            moduleStates: ["kline": moduleState],
            dockedPanels: [:],
            openModuleNames: activeTabBar()?.tabs ?? [],
            globalSettings: [
                "isMiniaturized": String(isMiniaturized),
                "panelWidth": String(describing: frame.width),
                "panelHeight": String(describing: frame.height)
            ]
        )

        logger.info("[KLine] K线面板布局状态已保存: \(frame.width)x\(frame.height), 折叠: \(isMiniaturized) (UISerializationManager + UIWorkspaceManager)")
    }

    /// 恢复面板布局状态
    func restoreLayoutState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 1. 容器 frame 统一从 UISerializationManager 读取（与 openPanel() 同一数据源，避免双重持久化不一致）
            if let containerView = self.enclosingKLineContainer() {
                let restoredFrame = UISerializationManager.shared.restoredContainerFrame(
                    identifier: "KL_Main",
                    fallback: containerView.frame
                )
                // 最小高度保护
                var finalFrame = restoredFrame
                if finalFrame.height < 320 {
                    finalFrame.size.height = max(containerView.frame.height, 480)
                }
                // bounds clamp：防止超出父视图
                if let parent = containerView.superview {
                    let b = parent.bounds
                    finalFrame.size.width = min(finalFrame.size.width, b.width)
                    finalFrame.size.height = min(finalFrame.size.height, b.height)
                    finalFrame.origin.x = max(0, min(finalFrame.origin.x, b.width - finalFrame.size.width))
                    finalFrame.origin.y = max(0, min(finalFrame.origin.y, b.height - finalFrame.size.height))
                }
                containerView.frame = finalFrame
                containerView.needsLayout = true
                containerView.layoutSubtreeIfNeeded()
                self.needsLayout = true
                self.layoutSubtreeIfNeeded()
                logger.info("[KLine] 容器 frame 已从 UISerializationManager 恢复: \(finalFrame.width)x\(finalFrame.height)")
            }

            // 2. 面板内部状态（币对、周期、标签等）仍从 UIWorkspaceManager 读取
            let layout = UIWorkspaceManager.shared.restoreState(name: "K线模块")
            if let panelState = layout?.moduleStates["kline"]?.configuration as? [String: String] {
                self.restoreState(from: panelState)
                logger.info("[KLine] 面板内部状态已从 UIWorkspaceManager 恢复")
            } else {
                logger.info("[KLine] 未找到面板内部状态，使用默认")
            }
        }
    }
}

// MARK: - 私有关联属性

private var indicatorBtnKey: UInt8 = 0
private var toolbarViewKey: UInt8 = 0
private var chartContainerKey: UInt8 = 0
private var klineChartViewKey: UInt8 = 0
private var canvasByKeyKey: UInt8 = 0
private var canvasPrebuildGenerationKey: UInt8 = 0
private var prebuiltOnlyKeysKey: UInt8 = 0
private var timeframeByInstrumentKey: UInt8 = 0
private var visibleTimeframesByInstrumentKey: UInt8 = 0
private var panelIsMinimizedKey: UInt8 = 0
private var workspacePersistenceObserverTokensKey: UInt8 = 0
private var lastSwitchInstrumentIDKey: UInt8 = 0
private var lastSwitchTimeframeKey: UInt8 = 0

extension Notification.Name {
    static let kxKLineDockingTransitionWillBegin = Notification.Name("kxKLineDockingTransitionWillBegin")
}

extension KXUI09KLinePanelView {
    var indicatorBtn: NSButton? {
        get { objc_getAssociatedObject(self, &indicatorBtnKey) as? NSButton }
        set { objc_setAssociatedObject(self, &indicatorBtnKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var toolbarView: NSView? {
        get { objc_getAssociatedObject(self, &toolbarViewKey) as? NSView }
        set { objc_setAssociatedObject(self, &toolbarViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var chartContainer: NSView? {
        get { objc_getAssociatedObject(self, &chartContainerKey) as? NSView }
        set { objc_setAssociatedObject(self, &chartContainerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var klineChartView: KXUI12KLineChartView? {
        get { objc_getAssociatedObject(self, &klineChartViewKey) as? KXUI12KLineChartView }
        set { objc_setAssociatedObject(self, &klineChartViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 多画布缓存:key="symbol|timeframe.rawValue" → 独立画布实例。
    /// 一个(币对×周期)=一张独立画布,加载一次画好后缓存;切换只切显隐不重画。
    var canvasByKey: [String: KXUI12KLineChartView] {
        get { objc_getAssociatedObject(self, &canvasByKeyKey) as? [String: KXUI12KLineChartView] ?? [:] }
        set { objc_setAssociatedObject(self, &canvasByKeyKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 预建任务代号:切币对/改周期集合时递增,旧预建队列自动停止,避免后台乱建。
    private var canvasPrebuildGeneration: Int {
        get { objc_getAssociatedObject(self, &canvasPrebuildGenerationKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &canvasPrebuildGenerationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 仅预建、尚未补缺口同步的 (币对|周期) key。用户真正切到该周期时补一次 syncTimeframe。
    private var prebuiltOnlyKeys: Set<String> {
        get { objc_getAssociatedObject(self, &prebuiltOnlyKeysKey) as? Set<String> ?? [] }
        set { objc_setAssociatedObject(self, &prebuiltOnlyKeysKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var timeframeByInstrument: [String: KXTimeframe] {
        get { objc_getAssociatedObject(self, &timeframeByInstrumentKey) as? [String: KXTimeframe] ?? [:] }
        set { objc_setAssociatedObject(self, &timeframeByInstrumentKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 每个币对独立的"可见时间框架集合"。增减某币对的周期不影响其他币对。
    private var visibleTimeframesByInstrument: [String: [KXTimeframe]] {
        get { objc_getAssociatedObject(self, &visibleTimeframesByInstrumentKey) as? [String: [KXTimeframe]] ?? [:] }
        set { objc_setAssociatedObject(self, &visibleTimeframesByInstrumentKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var panelIsMinimized: Bool {
        get { objc_getAssociatedObject(self, &panelIsMinimizedKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &panelIsMinimizedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var workspacePersistenceObserverTokens: [NSObjectProtocol] {
        get { objc_getAssociatedObject(self, &workspacePersistenceObserverTokensKey) as? [NSObjectProtocol] ?? [] }
        set { objc_setAssociatedObject(self, &workspacePersistenceObserverTokensKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var lastSwitchedInstrumentID: String? {
        get { objc_getAssociatedObject(self, &lastSwitchInstrumentIDKey) as? String }
        set { objc_setAssociatedObject(self, &lastSwitchInstrumentIDKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var lastSwitchedTimeframe: KXTimeframe? {
        get { objc_getAssociatedObject(self, &lastSwitchTimeframeKey) as? KXTimeframe }
        set { objc_setAssociatedObject(self, &lastSwitchTimeframeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 打开 UI 模块已有的持久化能力:
    /// 1. UI-GL-42 保存/恢复容器 frame,保证关闭前摆放位置下次打开不乱。
    /// 2. UI-GL-28 保存/恢复 K线内部配置,保证币对、周期、标签等参数不丢。
    /// 3. 父窗口 resize 后由 autoresizingMask/约束自适应,退出前写入最终状态。
    public func installWorkspacePersistenceHooks() {
        guard workspacePersistenceObserverTokens.isEmpty else { return }

        let center = NotificationCenter.default
        let terminateToken = center.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.persistLayoutState()
        }

        let resizeToken = center.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // ⚠️ 移除 layoutSubtreeIfNeeded(),避免递归布局死循环!
            // 窗口 resize 时,autoresizingMask/约束已经自动处理布局了
            self.persistLayoutState()
        }

        workspacePersistenceObserverTokens = [terminateToken, resizeToken]
        logger.info("[KLine] 已接入 UI 模块工作区持久化与自适应钩子")
    }

    fileprivate func timeframeForInstrument(_ instID: String) -> KXTimeframe {
        timeframeByInstrument[instID] ?? .oneHour
    }

    /// 某币对的可见周期集合;未设过返回默认原始集合(每个新币对都从这个默认开始,互不影响)。
    fileprivate func visibleTimeframesForInstrument(_ instID: String) -> [KXTimeframe] {
        visibleTimeframesByInstrument[instID] ?? [.fifteenMinutes, .oneHour, .fourHours, .oneDay, .oneWeek, .oneMonth]
    }

    fileprivate func rememberVisibleTimeframes(_ timeframes: [KXTimeframe], for instID: String) {
        var map = visibleTimeframesByInstrument
        map[instID] = timeframes
        visibleTimeframesByInstrument = map
    }

    /// 规则1:给同步管道提供"每个币对各自 tab 选中的周期"。
    fileprivate func timeframeMap(for symbols: [String]) -> [String: KXTimeframe] {
        var map: [String: KXTimeframe] = [:]
        for s in symbols { map[s] = timeframeForInstrument(s) }
        return map
    }

    fileprivate func rememberTimeframe(_ timeframe: KXTimeframe, for instID: String) {
        var map = timeframeByInstrument
        map[instID] = timeframe
        timeframeByInstrument = map
    }

    fileprivate func forgetTimeframe(for instID: String) {
        var map = timeframeByInstrument
        map.removeValue(forKey: instID)
        timeframeByInstrument = map
        var vmap = visibleTimeframesByInstrument
        vmap.removeValue(forKey: instID)   // 关标签同步清理该币对的可见集合,下次重开回默认
        visibleTimeframesByInstrument = vmap
    }
}

// MARK: - 面板快照

private extension KXUI09KLinePanelView {
    func logPanelSnapshot() {
        let tabBar = activeTabBar()
        let allTabs = tabBar?.tabs ?? []
        let activeID = tabBar?.activeTabID ?? panelContext.initialInstrumentID
        let activeTF = timeframeForInstrument(activeID)
        let subpaneCount = canvasByKey.values.first?.subpaneSlotCount() ?? 0
        let subpaneNames = canvasByKey.values.first?.subpaneIndicatorNames() ?? []
        logger.info("[KLine][Panel][Snapshot] tabs=\(allTabs.count):\(allTabs.joined(separator: ",")) active=\(activeID) tf=\(activeTF.rawValue) subpanes=\(subpaneCount):\(subpaneNames.joined(separator: ","))")
        let snapshotLine = "\(ISO8601DateFormatter().string(from: Date()))|\(allTabs.joined(separator: ","))|\(activeID)|\(activeTF.rawValue)|subpanes=\(subpaneCount):\(subpaneNames.joined(separator: ","))\n"
        try? snapshotLine.write(toFile: "/tmp/kline_panel_state.txt", atomically: true, encoding: String.Encoding.utf8)
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXKXUI09Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-09", fileName: "KX-UI-09_OKX风格面板.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-09_OKX风格面板.swift", duty: "OKX风格K线主面板视图"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("OKX风格面板骨架校验通过")
        return KXHealthCheckItem(name: "OKX风格面板", passed: true, message: "OKX风格K线主面板视图")
    }
}
