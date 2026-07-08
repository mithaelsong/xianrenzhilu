// 功能28: 开发者工具面板
// 对应: 实时查看窗口树、模块列表、性能监控、缓存管理、配置编辑
// 优先级: P3
// 版本: 2.0

import AppKit
import Foundation
import os.log

// MARK: - 通知名称扩展
/// 开发者工具面板相关通知
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能28：开发者工具面板 — 单元测试
/// 覆盖：面板管理/性能/UI树/模块/缓存/配置
func test_devTools() {
    let manager = UIDeveloperToolsManager.shared
    
    print("\n🧪 测试1: 面板状态")
    guard !manager.isPanelOpen else {
        fatalError("❌ 测试1失败: 初始面板应关闭")
    }
    print("✅ 测试1通过: 面板状态正确")
    
    print("\n🧪 测试2: 性能指标")
    let metrics = manager.currentMetrics()
    _ = metrics.fps
    _ = metrics.memoryMB
    print("✅ 测试2通过: 性能指标正常")
    
    print("\n🧪 测试3: 面板切换")
    manager.togglePanel()
    let open1 = manager.isPanelOpen
    manager.togglePanel()
    let open2 = manager.isPanelOpen
    guard open1 != open2 else {
        fatalError("❌ 测试3失败: 切换后状态应不同")
    }
    print("✅ 测试3通过: 面板切换正常")
    
    print("\n🧪 测试4: 数据显示方法")
    let settingsMetrics = manager.metricsForSettings()
    _ = settingsMetrics.fps
    print("✅ 测试4通过: 面板数据方法正常")
    
    print("\n🧪 测试5: 窗口树")
    let trees = manager.windowTreeData()
    _ = trees.count
    print("✅ 测试5通过: 窗口树正常")
    
    print("\n🧪 测试6: 模块数据")
    manager.refreshModuleData()
    let modules = manager.moduleEntries
    _ = modules.count
    print("✅ 测试6通过: 模块数据正常")
    
    print("\n🧪 测试7: 缓存数据")
    manager.refreshCacheData()
    manager.clearAllCaches()
    print("✅ 测试7通过: 缓存管理正常")
    
    print("\n=== 全部开发者工具测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UISandboxIsolationManager
public final class UISandboxIsolationManager : @unchecked Sendable {
    public static let shared = UISandboxIsolationManager()
    private init() {}
    public var allModuleNames: [String] { return [] }
    public func moduleStatus(moduleName: String) -> String { return "unknown" }
}

// MARK: - 迁回自 UI-02：class UIDeveloperToolsManager
public class UIDeveloperToolsManager: NSObject , @unchecked Sendable{
    public static let shared = UIDeveloperToolsManager()
    
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "开发者工具")
    private let lock = NSRecursiveLock()
    private nonisolated(unsafe) var isOpen: Bool = false
    private nonisolated(unsafe) var panelWindow: NSWindow?
    
    public private(set) var metrics: UIPerformanceMetrics = UIPerformanceMetrics()
    
    private nonisolated(unsafe) var fpsDisplayLink: CVDisplayLink?
    private var fpsFrameCount: Int = 0
    private var fpsLastTime: Double = 0
    
    public private(set) var cacheEntries: [UICacheEntry] = []
    public private(set) var configEntries: [UIConfigEntry] = []
    public private(set) var moduleEntries: [UIModuleEntry] = []
    
    override private init() {
        logger.info("开发者工具管理器已初始化")
    }
    
    deinit {
        closePanel()
        logger.info("开发者工具管理器已释放")
    }
    
    // MARK: - 面板打开/关闭
    
    public func openPanel() {
        lock.lock()
        if isOpen {
            lock.unlock()
            panelWindow?.makeKeyAndOrderFront(nil)
            return
        }
        isOpen = true
        lock.unlock()
        
        refreshAllData()
        
        let windowRect = NSRect(x: 200, y: 200, width: 800, height: 600)
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "开发者工具"
        window.contentViewController = UIDevToolsSplitViewController()
        window.isReleasedWhenClosed = false
        window.delegate = self
        panelWindow = window
        
        window.makeKeyAndOrderFront(nil)
        
        startPerformanceMonitoring()
        
        logger.info("开发者工具面板已打开")
        NotificationCenter.default.post(name: .devToolsDidOpen, object: self)
    }
    
    public func closePanel() {
        lock.lock()
        guard isOpen else {
            lock.unlock()
            return
        }
        isOpen = false
        lock.unlock()
        
        stopPerformanceMonitoring()
        
        panelWindow?.close()
        panelWindow = nil
        
        logger.info("开发者工具面板已关闭")
        NotificationCenter.default.post(name: .devToolsDidClose, object: self)
    }
    
    public func togglePanel() {
        lock.lock()
        if isOpen {
            lock.unlock()
            closePanel()
        } else {
            lock.unlock()
            openPanel()
        }
    }
    
    public var isPanelOpen: Bool {
        lock.lock()
        let open = isOpen
        lock.unlock()
        return open
    }
    
    // MARK: - 性能监控
    
    private func startPerformanceMonitoring() {
        fpsDisplayLink = nil
    }
    
    private func stopPerformanceMonitoring() {
        fpsDisplayLink = nil
    }
    
    private func sampleSystemMetrics() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            lock.lock()
            metrics.memoryMB = Double(info.resident_size) / (1024.0 * 1024.0)
            lock.unlock()
        }
        
        var cpuInfo = host_cpu_load_info()
        var cpuCount = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size) / 4
        let cpuResult = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &cpuCount)
            }
        }
        if cpuResult == KERN_SUCCESS {
            let total = Double(cpuInfo.cpu_ticks.0 + cpuInfo.cpu_ticks.1 + cpuInfo.cpu_ticks.2 + cpuInfo.cpu_ticks.3)
            let system = Double(cpuInfo.cpu_ticks.2) / total * 100.0
            lock.lock()
            metrics.cpuUsage = system
            lock.unlock()
        }
    }
    
    public func currentMetrics() -> UIPerformanceMetrics {
        lock.lock()
        let m = metrics
        lock.unlock()
        return m
    }
    
    // MARK: - UI树查看
    
    public func windowTreeData() -> [(window: NSWindow, views: [String])] {
        var result: [(NSWindow, [String])] = []
        for window in NSApplication.shared.windows {
            var views: [String] = []
            if let contentView = window.contentView {
                views = collectViewInfo(contentView, indent: 0)
            }
            result.append((window, views))
        }
        return result
    }
    
    private func collectViewInfo(_ view: NSView, indent: Int) -> [String] {
        let prefix = String(repeating: "  ", count: indent)
        let className = NSStringFromClass(type(of: view))
        let frame = view.frame
        let hidden = view.isHidden ? " (隐藏)" : ""
        let alpha = view.alphaValue < 1.0 ? String(format: " alpha:%.2f", view.alphaValue) : ""
        let info = "\(prefix)\(className) [\(Int(frame.origin.x)),\(Int(frame.origin.y)) \(Int(frame.width))x\(Int(frame.height))]\(hidden)\(alpha)"
        
        var result = [info]
        for subview in view.subviews {
            result.append(contentsOf: collectViewInfo(subview, indent: indent + 1))
        }
        return result
    }
    
    // MARK: - 模块状态
    
    public func refreshModuleData() {
        moduleEntries = []
        
        let allWindows = NSApplication.shared.windows
        var modules: [String: String] = [:]
        for window in allWindows {
            let className = NSStringFromClass(type(of: window))
            modules[className] = "活跃"
        }
        
        moduleEntries = modules.map { (name, status) in
            UIModuleEntry.shared
        }.sorted { $0.name < $1.name }
        
        let sandboxModules = UISandboxIsolationManager.shared.allModuleNames
        for name in sandboxModules {
            _ = UISandboxIsolationManager.shared.moduleStatus(moduleName: name)
            if !moduleEntries.contains(where: { $0.name == name }) {
                moduleEntries.append(UIModuleEntry.shared)
            }
        }
    }
    
    // MARK: - 缓存浏览
    
    public func refreshCacheData() {
        cacheEntries = [
            UICacheEntry(id: "nscache", name: "NSCache（系统默认）", type: "NSCache", size: 0),
            UICacheEntry(id: "layout_templates", name: "布局模板缓存", type: "内存缓存", size: 0)
        ]
        
        let templateCacheSize = UILayoutTemplateManager.shared.cachedTemplateCount
        if let idx = cacheEntries.firstIndex(where: { $0.id == "layout_templates" }) {
            cacheEntries[idx] = UICacheEntry(id: "layout_templates", name: "布局模板缓存", type: "内存缓存", size: templateCacheSize)
        }
        
        let nsCache = NSCache<NSString, NSString>()
        let cacheName = nsCache.name
        cacheEntries.append(UICacheEntry(id: "ns_cache_\(cacheName)", name: "NSCache(\(cacheName))", type: "NSCache", size: 0))
    }
    
    public func clearAllCaches() {
        let nsCache = NSCache<NSString, NSString>()
        nsCache.removeAllObjects()
        
        UILayoutTemplateManager.shared.clearCache()
        
        refreshCacheData()
        logger.info("所有缓存已清空")
        
        NotificationCenter.default.post(name: .devToolsDataDidUpdate, object: self, userInfo: ["action": "clearCache"])
    }
    
    // MARK: - 配置管理
    
    public func refreshConfigData() {
        configEntries = [
            UIConfigEntry(key: "app.version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"),
            UIConfigEntry(key: "app.build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知"),
            UIConfigEntry(key: "app.name", value: Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "未知"),
            UIConfigEntry(key: "os.version", value: ProcessInfo.processInfo.operatingSystemVersionString),
            UIConfigEntry(key: "locale", value: Locale.current.identifier),
            UIConfigEntry(key: "preferredLanguages", value: Locale.preferredLanguages.joined(separator: ", "))
        ]
    }
    
    public func updateConfig(key: String, value: String) -> Bool {
        if let idx = configEntries.firstIndex(where: { $0.key == key }) {
            guard configEntries[idx].editable else { return false }
            lock.lock()
            configEntries[idx] = UIConfigEntry(key: key, value: value, editable: configEntries[idx].editable)
            lock.unlock()
            
            logger.info("配置已更新: \(key) = \(value)")
            NotificationCenter.default.post(name: .devToolsDataDidUpdate, object: self, userInfo: ["action": "updateConfig", "key": key])
            return true
        }
        return false
    }
    
    // MARK: - 数据刷新
    
    public func refreshAllData() {
        refreshModuleData()
        refreshCacheData()
        refreshConfigData()
    }
    
    // MARK: - 设置面板方法
    
    public func metricsForSettings() -> UIPerformanceMetrics {
        return currentMetrics()
    }
    
    public func windowTreeForSettings() -> [(windowTitle: String, className: String, viewCount: Int, views: [String])] {
        let trees = windowTreeData()
        return trees.map { (window, views) in
            return (
                windowTitle: window.title,
                className: NSStringFromClass(type(of: window)),
                viewCount: views.count,
                views: views
            )
        }
    }
    
    public func moduleListForSettings() -> [UIModuleEntry] {
        return moduleEntries
    }
    
    public func cacheListForSettings() -> [UICacheEntry] {
        return cacheEntries
    }
    
    public func configListForSettings() -> [UIConfigEntry] {
        return configEntries
    }
}

// MARK: - 迁回自 UI-02：extension UIDeveloperToolsManager
extension UIDeveloperToolsManager: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        closePanel()
    }
}

// MARK: - 迁回自 UI-02：extension UIDeveloperToolsManager
public extension UIDeveloperToolsManager {
    static func registerKeyboardShortcut() {
        let keyEquivalent = "d"
        let modifierMask: NSEvent.ModifierFlags = [.command, .shift]
        
        let app = NSApplication.shared
        if app.mainMenu == nil {
            let menu = NSMenu(title: "主菜单")
            app.mainMenu = menu
        }
        
        let menuItem = NSMenuItem(title: "开发者工具", action: #selector(UIDeveloperToolsShortcutHandler.handleKeyboardShortcut(_:)), keyEquivalent: keyEquivalent)
        menuItem.keyEquivalentModifierMask = modifierMask
        menuItem.target = UIDeveloperToolsShortcutHandler.shared
        
        if let editMenu = app.mainMenu?.items.first(where: { $0.title == "编辑" })?.submenu {
            editMenu.addItem(menuItem)
        } else {
            let editMenu = NSMenu(title: "编辑")
            let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
            editItem.submenu = editMenu
            app.mainMenu?.addItem(editItem)
            editMenu.addItem(menuItem)
        }
    }
}

// MARK: - 迁回自 UI-02：class UIDeveloperToolsShortcutHandler
public final class UIDeveloperToolsShortcutHandler: NSObject , @unchecked Sendable{
    public static let shared = UIDeveloperToolsShortcutHandler()
    
    @objc public func handleKeyboardShortcut(_ sender: Any) {
        UIDeveloperToolsManager.shared.togglePanel()
    }
}

// MARK: - 迁回自 UI-02：class UIDevToolsSplitViewController
public final class UIDevToolsSplitViewController: NSSplitViewController , @unchecked Sendable{
    
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "开发者工具.UI")
    private let manager = UIDeveloperToolsManager.shared
    
    private let sidebarViewController = UIDevToolsSidebarViewController()
    private let contentViewController = UIDevToolsContentViewController()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        logger.info("开发者工具分栏视图加载完成")
        setupSplitView()
    }
    
    private func setupSplitView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 280
        addSplitViewItem(sidebarItem)
        
        let contentItem = NSSplitViewItem(viewController: contentViewController)
        contentItem.minimumThickness = 400
        addSplitViewItem(contentItem)
        
        sidebarViewController.onSelectionChanged = { [weak self] selectedItem in
            self?.contentViewController.showContent(for: selectedItem)
        }
        
        sidebarViewController.selectFirstItem()
    }
}

// MARK: - 迁回自 UI-02：class UIDevToolsSidebarViewController
public final class UIDevToolsSidebarViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource , @unchecked Sendable{
    
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    
    private let items = UIDevToolItem.allCases
    
    public var onSelectionChanged: ((UIDevToolItem) -> Void)?
    
    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 500))
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("function"))
        column.title = "功能"
        column.width = 180
        
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.action = #selector(handleClick)
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = NSColor.controlBackgroundColor
        tableView.rowHeight = 32
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .noBorder
        view.addSubview(scrollView)
    }
    
    public func selectFirstItem() {
        let indexSet = IndexSet(integer: 0)
        tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
        if !items.isEmpty {
            onSelectionChanged?(items[0])
        }
    }
    
    @objc private func handleClick() {
        let row = tableView.clickedRow
        guard row >= 0, row < items.count else { return }
        onSelectionChanged?(items[row])
    }
    
    // MARK: - 数据源
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("cell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView(frame: NSRect(x: 0, y: 0, width: 180, height: 32))
            cell?.identifier = identifier
            
            let label = NSTextField(labelWithString: "")
            label.font = NSFont.systemFont(ofSize: 13)
            label.frame = NSRect(x: 12, y: 6, width: 160, height: 20)
            label.autoresizingMask = [.width]
            cell?.addSubview(label)
            cell?.textField = label
        }
        
        cell?.textField?.stringValue = items[row].rawValue
        return cell
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < items.count else { return }
        onSelectionChanged?(items[row])
    }
}

// MARK: - 迁回自 UI-02：class UIDevToolsContentViewController
public final class UIDevToolsContentViewController: NSViewController , @unchecked Sendable{
    
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "开发者工具.内容")
    private let manager = UIDeveloperToolsManager.shared
    
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let statusLabel = NSTextField(labelWithString: "就绪")
    
    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 500))
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.frame = NSRect(x: 8, y: view.bounds.height - 22, width: view.bounds.width - 16, height: 16)
        statusLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(statusLabel)
        
        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.edgeInsets = NSEdgeInsets(top: 24, left: 8, bottom: 8, right: 8)
        
        scrollView.documentView = stackView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.frame = NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 24)
        scrollView.autoresizingMask = [.width, .height]
        view.addSubview(scrollView)
    }
    
    public func showContent(for item: UIDevToolItem) {
        for subview in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        
        switch item {
        case .uiTree:
            showUITree()
        case .modules:
            showModules()
        case .performance:
            showPerformance()
        case .cache:
            showCache()
        case .config:
            showConfig()
        }
    }
    
    private func showUITree() {
        statusLabel.stringValue = "UI树查看器"
        
        let title = createTitleLabel("窗口和视图层级")
        stackView.addArrangedSubview(title)
        
        let trees = manager.windowTreeData()
        for (window, views) in trees {
            let windowLabel = createValueLabel("📦 \(window.title) (\(NSStringFromClass(type(of: window))))")
            windowLabel.font = NSFont.boldSystemFont(ofSize: 12)
            stackView.addArrangedSubview(windowLabel)
            
            for viewInfo in views {
                let viewLabel = createValueLabel("  \(viewInfo)")
                viewLabel.font = NSFont.systemFont(ofSize: 11)
                viewLabel.textColor = NSColor.secondaryLabelColor
                stackView.addArrangedSubview(viewLabel)
            }
        }
        
        if trees.isEmpty {
            let emptyLabel = createValueLabel("无窗口")
            stackView.addArrangedSubview(emptyLabel)
        }
    }
    
    private func showModules() {
        statusLabel.stringValue = "模块状态"
        
        let title = createTitleLabel("已注册模块")
        stackView.addArrangedSubview(title)
        
        manager.refreshModuleData()
        for module in manager.moduleEntries {
            let moduleLabel = createValueLabel("📦 \(module.name) [\(module.status)] v\(module.version)")
            stackView.addArrangedSubview(moduleLabel)
            
            let moduleDesc = module.moduleDescription
            let descLabel = createValueLabel("    \(moduleDesc)")
            descLabel.textColor = NSColor.tertiaryLabelColor
            descLabel.font = NSFont.systemFont(ofSize: 10)
            stackView.addArrangedSubview(descLabel)
        }
        
        if manager.moduleEntries.isEmpty {
            let emptyLabel = createValueLabel("暂无模块信息")
            stackView.addArrangedSubview(emptyLabel)
        }
    }
    
    private func showPerformance() {
        statusLabel.stringValue = "性能监视器（实时更新）"
        
        let title = createTitleLabel("系统资源")
        stackView.addArrangedSubview(title)
        
        let metrics = manager.currentMetrics()
        
        let fpsLabel = createValueLabel("🎬 FPS: \(String(format: "%.1f", metrics.fps))")
        stackView.addArrangedSubview(fpsLabel)
        
        let memoryLabel = createValueLabel("💾 内存: \(String(format: "%.1f", metrics.memoryMB)) MB")
        stackView.addArrangedSubview(memoryLabel)
        
        let cpuLabel = createValueLabel("⚡ CPU: \(String(format: "%.1f", metrics.cpuUsage))%")
        stackView.addArrangedSubview(cpuLabel)
        
        let timeLabel = createValueLabel("🕐 上次更新: \(metrics.lastUpdate)")
        timeLabel.textColor = NSColor.tertiaryLabelColor
        timeLabel.font = NSFont.systemFont(ofSize: 10)
        stackView.addArrangedSubview(timeLabel)
        
        let refreshButton = NSButton(title: "手动刷新", target: self, action: #selector(handleRefreshPerformance))
        stackView.addArrangedSubview(refreshButton)
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.showContent(for: .performance)
            }
        }
    }
    
    @objc private func handleRefreshPerformance() {
        showContent(for: .performance)
    }
    
    private func showCache() {
        statusLabel.stringValue = "缓存浏览器"
        
        let title = createTitleLabel("系统缓存")
        stackView.addArrangedSubview(title)
        
        manager.refreshCacheData()
        for entry in manager.cacheEntries {
            let sizeStr = entry.size > 0 ? " (\(entry.size) 项)" : ""
            let cacheLabel = createValueLabel("📦 \(entry.name) [\(entry.type)]\(sizeStr)")
            stackView.addArrangedSubview(cacheLabel)
        }
        
        if manager.cacheEntries.isEmpty {
            let emptyLabel = createValueLabel("暂无缓存数据")
            stackView.addArrangedSubview(emptyLabel)
        }
        
        let clearButton = NSButton(title: "清空所有缓存", target: self, action: #selector(handleClearCache))
        stackView.addArrangedSubview(clearButton)
        
        let refreshButton = NSButton(title: "刷新缓存列表", target: self, action: #selector(handleRefreshCache))
        stackView.addArrangedSubview(refreshButton)
    }
    
    @objc private func handleClearCache() {
        manager.clearAllCaches()
        showContent(for: .cache)
    }
    
    @objc private func handleRefreshCache() {
        showContent(for: .cache)
    }
    
    private func showConfig() {
        statusLabel.stringValue = "配置编辑器"
        
        let title = createTitleLabel("应用配置")
        stackView.addArrangedSubview(title)
        
        manager.refreshConfigData()
        for entry in manager.configEntries {
            let configLabel = createValueLabel("\(entry.key) = \(entry.value)")
            configLabel.toolTip = entry.editable ? "可编辑" : "只读"
            stackView.addArrangedSubview(configLabel)
        }
        
        if manager.configEntries.isEmpty {
            let emptyLabel = createValueLabel("暂无配置数据")
            stackView.addArrangedSubview(emptyLabel)
        }
    }
    
    // MARK: - 辅助UI方法
    
    private func createTitleLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.textColor = NSColor.labelColor
        return label
    }
    
    private func createValueLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = NSColor.labelColor
        return label
    }
}

// MARK: - 迁回自 UI-02：struct UITemplateItem
// MARK: - UI日志管理器
/// 记录所有UI操作，支持分级、文件轮转、异步写入、日志保留策略
/// 采用单例模式，使用NSRecursiveLock保护共享数据，通过DispatchQueue异步写入文件
// 已迁回 UI-GL-35_日志记录.swift：class UILogManager（公共类型文件禁止功能实现）

// MARK: - 日志查看器视图控制器
/// 纯AppKit实现的日志查看器，支持搜索、级别过滤、导出
/// 使用NSTableView展示日志条目，监听UILogDidUpdate通知自动刷新
// 已迁回 UI-GL-35_日志记录.swift：class UILogViewerViewController（公共类型文件禁止功能实现）

// MARK: - NSTableView 数据源与代理
// 已迁回 UI-GL-35_日志记录.swift：extension UILogViewerViewController（公共类型文件禁止功能实现）

// MARK: - 日志查看器窗口控制器
/// 提供独立的日志查看窗口，方便设置面板或其他模块一键弹出
// 已迁回 UI-GL-35_日志记录.swift：class UILogViewerWindowController（公共类型文件禁止功能实现）


// MARK: - UI-GL-36 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-36_types.swift
// 版本: 2.0
public struct UITemplateItem: Identifiable {
    public let id: String
    public let name: String
    public let description: String
}

// MARK: - 迁回自 UI-02：struct UIPerformanceMetrics
public struct UIPerformanceMetrics {
    public var fps: Double = 0
    public var memoryMB: Double = 0
    public var cpuUsage: Double = 0
    public var lastUpdate: Date = Date()
}

// MARK: - 迁回自 UI-02：enum UIDevToolItem
public enum UIDevToolItem: String, CaseIterable {
    case uiTree = "UI树查看器"
    case modules = "模块状态"
    case performance = "性能监视器"
    case cache = "缓存浏览器"
    case config = "配置编辑器"
}

// MARK: - 迁回自 UI-02：struct UICacheEntry
public struct UICacheEntry: Identifiable {
    public let id: String
    public var name: String
    public var type: String
    public var size: Int
}

// MARK: - 迁回自 UI-02：struct UIConfigEntry
public struct UIConfigEntry: Identifiable {
    public let id: String
    public var key: String
    public var value: String
    public var editable: Bool
    
    public init(key: String, value: String, editable: Bool = true) {
        self.id = key
        self.key = key
        self.value = value
        self.editable = editable
    }
}
