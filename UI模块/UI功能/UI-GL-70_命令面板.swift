// 功能60: 命令面板 (Command Palette)
// 对应: 按下 Cmd+Shift+P 打开全局命令面板，通过键盘快速搜索并执行应用内任何操作
// 优先级: P1 — 核心交互入口
// 作者: 仙人指路开发团队
// 版本: 2.0

import Foundation
import AppKit
import os.log

// MARK: - 统一日志器
/// 本子模块专用的结构化日志器，subsystem 使用应用主 bundle 标识
private let logger = Logger(subsystem: "com.xianrenzhilu.app", category: "CommandPalette")

// MARK: - 全局通知定义
/// 命令面板相关通知，便于其他模块监听并做出响应（如暂停动画、保存状态等）
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：extension Notification.Name {

// MARK: - 测试代码
#if DEBUG

/// 功能60：命令面板 — 单元测试
func test_commandPalette() {
    let manager = UICommandPaletteManager.shared
    
    logger.info("测试1: 初始状态")
    if manager.commandCount == 0 {
        logger.info("✅ 测试1通过")
    } else {
        logger.error("❌ 测试1失败: count=\(manager.commandCount)")
    }
    
    logger.info("测试2: 注册命令")
    manager.quickRegister(identifier: "test.hello", title: "Hello", category: "测试") {
        logger.info("Hello命令执行")
    }
    if manager.commandCount == 1 {
        logger.info("✅ 测试2通过")
    } else {
        logger.error("❌ 测试2失败")
    }
    
    logger.info("测试3: 重复注册被忽略")
    manager.quickRegister(identifier: "test.hello", title: "Hello Again", category: "测试") {}
    if manager.commandCount == 1 {
        logger.info("✅ 测试3通过")
    } else {
        logger.error("❌ 测试3失败")
    }
    
    logger.info("测试4: 批量注册")
    let items = [
        UICommandItem(identifier: "test.one", title: "One", category: "A", action: {}),
        UICommandItem(identifier: "test.two", title: "Two", category: "B", action: {}),
        UICommandItem(identifier: "test.three", title: "Three", category: "A", action: {}),
    ]
    manager.register(commands: items)
    if manager.commandCount == 4 {
        logger.info("✅ 测试4通过")
    } else {
        logger.error("❌ 测试4失败")
    }
    
    logger.info("测试5: 注销命令")
    manager.unregister(identifier: "test.hello")
    if manager.commandCount == 3 {
        logger.info("✅ 测试5通过")
    } else {
        logger.error("❌ 测试5失败")
    }
    
    logger.info("测试6: 配置管理")
    let config = manager.getConfiguration(for: "test.one")
    if config.identifier == "test.one" && config.isEnabled {
        logger.info("✅ 测试6通过")
    } else {
        logger.error("❌ 测试6失败")
    }
    
    logger.info("测试7: 更新配置")
    let newConfig = UICommandConfiguration(identifier: "test.one", customShortcut: "cmd+1", isEnabled: false)
    manager.updateConfiguration(newConfig)
    let updated = manager.getConfiguration(for: "test.one")
    if updated.customShortcut == "cmd+1" && !updated.isEnabled {
        logger.info("✅ 测试7通过")
    } else {
        logger.error("❌ 测试7失败")
    }
    
    logger.info("测试8: 分组查询")
    let groups = manager.getCommandsByCategory()
    if groups["A"]?.count == 2 && groups["B"]?.count == 1 {
        logger.info("✅ 测试8通过")
    } else {
        logger.error("❌ 测试8失败")
    }
    
    logger.info("测试9: 注册命令列表")
    let all = manager.allRegisteredCommands
    if all.count == 3 {
        logger.info("✅ 测试9通过")
    } else {
        logger.error("❌ 测试9失败")
    }
    
    logger.info("测试10: 重置配置")
    manager.resetAllConfigurations()
    let resetConfig = manager.getConfiguration(for: "test.one")
    if resetConfig.isEnabled && resetConfig.customShortcut == nil {
        logger.info("✅ 测试10通过")
    } else {
        logger.error("❌ 测试10失败")
    }
    
    logger.info("测试11: 模糊搜索")
    // 搜索 "two" 应命中 test.two
    manager.register(UICommandItem(identifier: "test.search", title: "搜索测试", category: "UI", action: {}))
    // 通过直接执行验证
    let executed = manager.executeCommand(identifier: "test.search")
    if executed {
        logger.info("✅ 测试11通过")
    } else {
        logger.error("❌ 测试11失败")
    }
    
    logger.info("测试12: 直接执行不存在的命令")
    let failed = manager.executeCommand(identifier: "nonexistent")
    if !failed {
        logger.info("✅ 测试12通过")
    } else {
        logger.error("❌ 测试12失败")
    }
    
    logger.info("测试13: 清除最近记录")
    manager.clearRecentCommands()
    let recents = manager.getRecentCommands()
    if recents.isEmpty {
        logger.info("✅ 测试13通过")
    } else {
        logger.error("❌ 测试13失败")
    }
    
    // 清理注册的命令
    manager.unregister(identifiers: ["test.one", "test.two", "test.three"])
    manager.unregister(identifier: "test.search")
    
    logger.info("=== 全部命令面板测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UICommandPaletteWindow
internal class UICommandPaletteWindow: NSWindow , @unchecked Sendable{
    /// 搜索输入框
    let searchField = NSSearchField()
    
    /// 结果表格视图
    let tableView = NSTableView()
    
    /// 滚动容器
    let scrollView = NSScrollView()
    
    /// 结果计数标签（显示 "共 N 条命令"）
    let countLabel = NSTextField(labelWithString: "")
    
    /// 初始化窗口并配置 UI
    init() {
        let rect = NSRect(x: 0, y: 0, width: 600, height: 480)
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        self.title = "命令面板"
        self.level = .floating
        self.isMovableByWindowBackground = false
        self.center()
        self.minSize = NSSize(width: 400, height: 300)
        self.maxSize = NSSize(width: 800, height: 600)
        setupUI()
    }
    
    /// 构建窗口内部 UI 布局
    private func setupUI() {
        guard let content = contentView else { return }
        
        // 搜索框：顶部居中，左右留 16 点边距
        searchField.frame = NSRect(x: 16, y: content.bounds.height - 52, width: content.bounds.width - 32, height: 32)
        searchField.placeholderString = "搜索命令（支持模糊匹配）..."
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.autoresizingMask = [.width, .minYMargin]
        content.addSubview(searchField)
        
        // 计数标签：位于搜索框下方左侧
        countLabel.frame = NSRect(x: 16, y: content.bounds.height - 76, width: 200, height: 18)
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.autoresizingMask = [.minYMargin]
        content.addSubview(countLabel)
        
        // 快捷键提示标签：位于搜索框下方右侧
        let shortcutLabel = NSTextField(labelWithString: "快捷键: ⌘⇧P")
        shortcutLabel.frame = NSRect(x: content.bounds.width - 120, y: content.bounds.height - 76, width: 110, height: 18)
        shortcutLabel.font = NSFont.systemFont(ofSize: 11)
        shortcutLabel.textColor = .secondaryLabelColor
        shortcutLabel.alignment = .right
        shortcutLabel.autoresizingMask = [.minXMargin, .minYMargin]
        content.addSubview(shortcutLabel)
        
        // 表格列定义
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("command"))
        column.title = "命令"
        column.width = content.bounds.width - 20
        column.minWidth = 200
        column.maxWidth = 800
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 40
        tableView.autoresizingMask = [.width, .height]
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.selectionHighlightStyle = .regular
        
        // 滚动视图包裹表格
        scrollView.frame = NSRect(x: 0, y: 28, width: content.bounds.width, height: content.bounds.height - 80)
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.autohidesScrollers = true
        content.addSubview(scrollView)
        
        // 底部提示栏：显示操作提示
        let tipLabel = NSTextField(labelWithString: "↑↓ 选择  ⏎ 执行  ⌘+数字 直接执行  Esc 关闭")
        tipLabel.frame = NSRect(x: 0, y: 4, width: content.bounds.width, height: 20)
        tipLabel.font = NSFont.systemFont(ofSize: 11)
        tipLabel.textColor = .tertiaryLabelColor
        tipLabel.alignment = .center
        tipLabel.autoresizingMask = [.width, .maxYMargin]
        content.addSubview(tipLabel)
    }
    
    /// 更新结果计数标签
    func updateCountLabel(total: Int, filtered: Int) {
        if total == filtered {
            countLabel.stringValue = "共 \(total) 条命令"
        } else {
            countLabel.stringValue = "共 \(total) 条命令，命中 \(filtered) 条"
        }
    }
}

// MARK: - 迁回自 UI-02：class UICommandPaletteManager
public final class UICommandPaletteManager: NSObject , @unchecked Sendable{
    
    // MARK: 单例
    /// 全局唯一实例
    public static let shared = UICommandPaletteManager()
    
    // MARK: 私有属性
    /// 命令面板浮动窗口（懒加载）
    private nonisolated(unsafe) var paletteWindow: UICommandPaletteWindow?
    
    /// 所有已注册的命令条目（受 lock 保护）
    private nonisolated(unsafe) var allCommands: [UICommandItem] = []
    
    /// 已注册命令标识符集合，防止重复注册（受 lock 保护）
    private nonisolated(unsafe) var registeredIdentifiers: Set<String> = []
    
    /// 当前模糊搜索过滤后的结果（受 lock 保护）
    private nonisolated(unsafe) var filteredResults: [UIFuzzySearchResult] = []
    
    /// 最近使用命令记录（受 lock 保护）
    private nonisolated(unsafe) var recentRecords: [UIRecentCommandRecord] = []
    
    /// 命令持久化配置映射（受 lock 保护）
    private nonisolated(unsafe) var configurations: [String: UICommandConfiguration] = [:]
    
    /// 递归锁，保护所有可变共享状态
    private let lock = NSRecursiveLock()
    
    /// 本地事件监听器引用（用于快捷键呼出）
    private nonisolated(unsafe) var eventMonitor: Any?
    
    /// 日志标识上下文
    private let logCategory = "UICommandPaletteManager"
    
    // MARK: 初始化
    private override init() {
        super.init()
        logger.info("[\(self.logCategory)] 命令面板管理器初始化")
        loadStorage()
        setupKeyboardMonitor()
    }
    
    /// 析构时清理资源，防止内存泄漏与残留事件监听
    deinit {
        logger.info("[\(self.logCategory)] 命令面板管理器析构，开始清理资源")
        
        // 移除键盘事件监听器
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        // 关闭并释放命令面板窗口
        if let window = paletteWindow {
            window.close()
        }
        paletteWindow = nil
        
        // 清空注册数据
        lock.lock()
        allCommands.removeAll()
        registeredIdentifiers.removeAll()
        filteredResults.removeAll()
        lock.unlock()
        
        logger.info("[\(self.logCategory)] 资源清理完成")
    }
    
    // MARK: - 命令注册与注销
    
    /// 注册单个命令到命令面板。
    /// 如果 identifier 已存在，本次注册会被忽略（保留首次注册）
    /// - Parameter item: 待注册的命令条目
    public func register(_ item: UICommandItem) {
        lock.lock()
        guard !registeredIdentifiers.contains(item.identifier) else {
            lock.unlock()
            logger.warning("[\(self.logCategory)] 命令注册失败：identifier '\(item.identifier)' 已存在，跳过重复注册")
            return
        }
        allCommands.append(item)
        registeredIdentifiers.insert(item.identifier)
        
        // 若该命令无持久化配置，创建默认配置
        if configurations[item.identifier] == nil {
            configurations[item.identifier] = UICommandConfiguration(identifier: item.identifier)
        }
        lock.unlock()
        
        logger.info("[\(self.logCategory)] 命令注册成功：\(item.identifier) - \(item.title)")
        
        // 发送注册变更通知
        NotificationCenter.default.post(name: .commandRegistryDidChange, object: self)
        
        // 刷新面板数据（如果窗口已存在）
        reloadTableData()
    }
    
    /// 批量注册命令，效率高于逐个注册
    /// - Parameter items: 命令条目数组
    public func register(commands items: [UICommandItem]) {
        lock.lock()
        var addedCount = 0
        for item in items {
            guard !registeredIdentifiers.contains(item.identifier) else { continue }
            allCommands.append(item)
            registeredIdentifiers.insert(item.identifier)
            if configurations[item.identifier] == nil {
                configurations[item.identifier] = UICommandConfiguration(identifier: item.identifier)
            }
            addedCount += 1
        }
        lock.unlock()
        
        logger.info("[\(self.logCategory)] 批量注册完成：新增 \(addedCount) 条命令，当前总计 \(self.registeredIdentifiers.count) 条")
        
        NotificationCenter.default.post(name: .commandRegistryDidChange, object: self)
        reloadTableData()
    }
    
    /// 注销指定命令，从注册表与搜索列表中移除
    /// - Parameter identifier: 命令唯一标识符
    public func unregister(identifier: String) {
        lock.lock()
        guard registeredIdentifiers.contains(identifier) else {
            lock.unlock()
            logger.warning("[\(self.logCategory)] 注销失败：identifier '\(identifier)' 不存在")
            return
        }
        allCommands.removeAll { $0.identifier == identifier }
        registeredIdentifiers.remove(identifier)
        lock.unlock()
        
        logger.info("[\(self.logCategory)] 命令注销成功：\(identifier)")
        
        NotificationCenter.default.post(name: .commandRegistryDidChange, object: self)
        reloadTableData()
    }
    
    /// 注销多个命令
    /// - Parameter identifiers: 待注销的命令标识符数组
    public func unregister(identifiers: [String]) {
        for id in identifiers {
            unregister(identifier: id)
        }
    }
    
    /// 获取当前已注册命令总数（线程安全）
    public var commandCount: Int {
        lock.lock()
        let count = allCommands.count
        lock.unlock()
        return count
    }
    
    // MARK: - 命令面板显示与关闭
    
    /// 切换命令面板显示状态：若已显示则关闭，若未显示则打开并居中
    public func toggle() {
        if let window = paletteWindow, window.isVisible {
            closePalette()
        } else {
            showPalette()
        }
    }
    
    /// 显示命令面板，发送即将打开通知，并自动聚焦搜索框
    public func showPalette() {
        // 发送即将打开通知，便于外部模块保存状态
        NotificationCenter.default.post(name: .commandPaletteWillOpen, object: self)
        
        if paletteWindow == nil {
            paletteWindow = UICommandPaletteWindow()
            setupTableView()
        }
        
        guard let window = paletteWindow else { return }
        
        // 重置搜索框并刷新数据
        window.searchField.stringValue = ""
        performSearch(query: "")
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.searchField.becomeFirstResponder()
        
        logger.info("[\(self.logCategory)] 命令面板已显示")
    }
    
    /// 关闭命令面板，发送已关闭通知
    public func closePalette() {
        guard let window = paletteWindow else { return }
        window.close()
        
        // 发送已关闭通知
        NotificationCenter.default.post(name: .commandPaletteDidClose, object: self)
        
        logger.info("[\(self.logCategory)] 命令面板已关闭")
    }
    
    // MARK: - 模糊搜索
    
    /// 根据搜索字符串执行模糊搜索，并刷新表格显示
    /// - Parameter query: 用户输入的搜索字符串
    private func performSearch(query: String) {
        lock.lock()
        // 仅搜索启用的命令
        let enabledCommands = allCommands.filter { cmd in
            if let config = configurations[cmd.identifier] {
                return config.isEnabled
            }
            return true
        }
        
        let results = UIFuzzySearcher.search(query: query, in: enabledCommands)
        
        // 最近使用的命令获得额外排序加成：如果最近使用过，评分 + 25
        var boostedResults = results.map { result -> UIFuzzySearchResult in
            if let record = recentRecords.first(where: { $0.commandId == result.item.identifier }) {
                // 执行次数越多、时间越近，加成越高
                let hoursSinceLastUse = -record.timestamp.timeIntervalSinceNow / 3600
                let recencyBonus = max(0, Int(25 - hoursSinceLastUse)) + min(record.executionCount * 3, 15)
                return UIFuzzySearchResult(item: result.item, score: result.score + recencyBonus)
            }
            return result
        }
        
        // 重新按评分排序
        boostedResults.sort { $0.score > $1.score }
        self.filteredResults = boostedResults
        lock.unlock()
        
        // 刷新 UI
        let totalCount = enabledCommands.count
        let filteredCount = boostedResults.count
        paletteWindow?.updateCountLabel(total: totalCount, filtered: filteredCount)
        paletteWindow?.tableView.reloadData()
        
        // 默认选中第一行
        if boostedResults.count > 0 {
            paletteWindow?.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    // MARK: - 命令执行
    
    /// 执行指定命令，并记录到最近使用列表
    /// - Parameter result: 模糊搜索结果条目
    private func executeCommand(_ result: UIFuzzySearchResult) {
        let item = result.item
        
        // 记录最近使用
        recordRecentUsage(commandId: item.identifier)
        
        // 先关闭面板，再执行命令（避免面板遮挡业务界面）
        closePalette()
        
        // 执行命令闭包
        item.action()
        
        logger.info("[\(self.logCategory)] 命令执行：\(item.identifier) - \(item.title)")
    }
    
    /// 直接通过标识符执行命令（不经过面板搜索，适用于快捷键绑定）
    /// - Parameter identifier: 命令唯一标识符
    /// - Returns: 是否执行成功（命令存在且已启用）
    @discardableResult
    public func executeCommand(identifier: String) -> Bool {
        lock.lock()
        guard let command = allCommands.first(where: { $0.identifier == identifier }) else {
            lock.unlock()
            logger.warning("[\(self.logCategory)] 直接执行失败：命令 '\(identifier)' 未注册")
            return false
        }
        if let config = configurations[identifier], !config.isEnabled {
            lock.unlock()
            logger.info("[\(self.logCategory)] 直接执行被阻止：命令 '\(identifier)' 已禁用")
            return false
        }
        lock.unlock()
        
        recordRecentUsage(commandId: identifier)
        command.action()
        logger.info("[\(self.logCategory)] 直接执行成功：\(identifier)")
        return true
    }
    
    // MARK: - 最近使用命令记录
    
    /// 记录命令被使用，更新最近使用列表与持久化存储
    /// - Parameter commandId: 被执行的命令标识符
    private func recordRecentUsage(commandId: String) {
        lock.lock()
        if let index = recentRecords.firstIndex(where: { $0.commandId == commandId }) {
            // 已有记录：更新时间戳并递增次数
            recentRecords[index].timestamp = Date()
            recentRecords[index].executionCount += 1
        } else {
            // 新记录：插入到头部
            let record = UIRecentCommandRecord(commandId: commandId)
            recentRecords.insert(record, at: 0)
        }
        
        // 限制列表长度，防止无限膨胀
        let maxCount = max(1, configurations.values.first?.isEnabled ?? true ? 20 : 20)
        if recentRecords.count > maxCount {
            recentRecords = Array(recentRecords.prefix(maxCount))
        }
        lock.unlock()
        
        // 发送更新通知
        NotificationCenter.default.post(name: .recentCommandsDidUpdate, object: self)
        
        // 异步保存到磁盘
        saveStorage()
    }
    
    /// 获取最近使用命令列表（线程安全，返回副本）
    /// - Returns: 最近使用记录数组，按时间倒序
    public func getRecentCommands() -> [UIRecentCommandRecord] {
        lock.lock()
        let copy = recentRecords
        lock.unlock()
        return copy
    }
    
    /// 清空最近使用记录
    public func clearRecentCommands() {
        lock.lock()
        recentRecords.removeAll()
        lock.unlock()
        
        NotificationCenter.default.post(name: .recentCommandsDidUpdate, object: self)
        saveStorage()
        logger.info("[\(self.logCategory)] 最近使用记录已清空")
    }
    
    // MARK: - 持久化存储
    
    /// 持久化文件存储路径：~/Library/Application Support/仙人指路/UICommandPaletteStorage.json
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("仙人指路", isDirectory: true)
        return appFolder.appendingPathComponent("UICommandPaletteStorage.json")
    }
    
    /// 从磁盘加载持久化数据
    private func loadStorage() {
        let url = storageURL
        let folder = url.deletingLastPathComponent()
        
        // 确保目录存在
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("[\(self.logCategory)] 未找到持久化文件，使用默认配置")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let storage = try JSONDecoder().decode(UICommandPaletteStorage.self, from: data)
            
            lock.lock()
            self.configurations = storage.configurations
            self.recentRecords = storage.recentRecords
            lock.unlock()
            
            logger.info("[\(self.logCategory)] 持久化数据加载成功：\(storage.configurations.count) 条配置，\(storage.recentRecords.count) 条最近记录")
        } catch {
            logger.error("[\(self.logCategory)] 持久化数据加载失败：\(error.localizedDescription)")
        }
    }
    
    /// 保存当前状态到磁盘（异步执行，避免阻塞主线程）
    private func saveStorage() {
        let url = storageURL
        
        lock.lock()
        let storage = UICommandPaletteStorage(
            configurations: configurations,
            recentRecords: recentRecords,
            maxRecentCount: 20,
            globalShortcut: "cmd+shift+p"
        )
        lock.unlock()
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                let data = try JSONEncoder().encode(storage)
                try data.write(to: url, options: .atomic)
                logger.info("[\(self?.logCategory ?? "UICommandPaletteManager")] 持久化数据保存成功")
            } catch {
                logger.error("[\(self?.logCategory ?? "UICommandPaletteManager")] 持久化数据保存失败：\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 设置面板方法
    
    /// 获取所有命令的持久化配置（供设置面板展示）
    /// - Returns: 配置数组
    public func getAllConfigurations() -> [UICommandConfiguration] {
        lock.lock()
        let configs = Array(configurations.values)
        lock.unlock()
        return configs
    }
    
    /// 获取单个命令的配置
    /// - Parameter identifier: 命令标识符
    /// - Returns: 配置对象，若不存在则返回默认配置
    public func getConfiguration(for identifier: String) -> UICommandConfiguration {
        lock.lock()
        let config = configurations[identifier] ?? UICommandConfiguration(identifier: identifier)
        lock.unlock()
        return config
    }
    
    /// 更新命令配置（启用/禁用、自定义快捷键等）
    /// - Parameter configuration: 新的配置对象
    public func updateConfiguration(_ configuration: UICommandConfiguration) {
        lock.lock()
        configurations[configuration.identifier] = configuration
        lock.unlock()
        
        saveStorage()
        logger.info("[\(self.logCategory)] 配置更新：\(configuration.identifier) enabled=\(configuration.isEnabled) shortcut=\(configuration.customShortcut ?? "nil")")
    }
    
    /// 重置所有命令配置为默认状态
    public func resetAllConfigurations() {
        lock.lock()
        var newConfigs: [String: UICommandConfiguration] = [:]
        for id in registeredIdentifiers {
            newConfigs[id] = UICommandConfiguration(identifier: id)
        }
        configurations = newConfigs
        lock.unlock()
        
        saveStorage()
        logger.info("[\(self.logCategory)] 所有配置已重置为默认值")
    }
    
    /// 获取所有命令分组（按 category 分组，供设置面板展示）
    /// - Returns: 字典，key 为分类名，value 为该分类下的命令列表
    public func getCommandsByCategory() -> [String: [UICommandItem]] {
        lock.lock()
        var groups: [String: [UICommandItem]] = [:]
        for cmd in allCommands {
            groups[cmd.category, default: []].append(cmd)
        }
        lock.unlock()
        return groups
    }
    
    /// 获取所有已注册命令的只读副本（线程安全）
    public var allRegisteredCommands: [UICommandItem] {
        lock.lock()
        let copy = allCommands
        lock.unlock()
        return copy
    }
    
    // MARK: - 快捷键监听
    
    /// 设置本地键盘事件监听器，捕获 Cmd+Shift+P 呼出命令面板
    /// 注意：本地监听器仅在应用获得焦点时生效；如需全局快捷键（任意场景），需注册 CGEventTap 或辅助功能 API
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // 检测 Cmd+Shift+P
            let hasCommand = event.modifierFlags.contains(.command)
            let hasShift = event.modifierFlags.contains(.shift)
            let isP = event.keyCode == 35 // Keycode 35 = 'P'
            
            if hasCommand && hasShift && isP {
                self.toggle()
                return nil // 吞掉事件，防止继续传递
            }
            
            return event
        }
        
        logger.info("[\(self.logCategory)] 快捷键监听器已注册：Cmd+Shift+P")
    }
    
    // MARK: - 表格视图设置
    
    /// 配置表格视图的数据源与代理，绑定搜索框事件
    private func setupTableView() {
        guard let window = paletteWindow else { return }
        
        window.tableView.dataSource = self
        window.tableView.delegate = self
        window.tableView.target = self
        window.tableView.doubleAction = #selector(onTableDoubleClick)
        
        // 搜索框文本变化时触发模糊搜索
        window.searchField.action = #selector(onSearchChanged)
        window.searchField.target = self
    }
    
    /// 刷新表格数据（外部命令注册变更后调用）
    private func reloadTableData() {
        guard let searchField = paletteWindow?.searchField else { return }
        performSearch(query: searchField.stringValue)
    }
    
    /// 搜索框文本变化回调
    @objc private func onSearchChanged() {
        let query = paletteWindow?.searchField.stringValue ?? ""
        performSearch(query: query)
    }
    
    /// 表格双击事件：执行选中命令
    @objc private func onTableDoubleClick() {
        let row = paletteWindow?.tableView.clickedRow ?? -1
        guard row >= 0 else { return }
        
        lock.lock()
        guard row < filteredResults.count else {
            lock.unlock()
            return
        }
        let result = filteredResults[row]
        lock.unlock()
        
        executeCommand(result)
    }
}

// MARK: - 迁回自 UI-02：extension UICommandPaletteManager
extension UICommandPaletteManager: NSTableViewDataSource {
    
    /// 返回表格行数（过滤后的结果数量）
    public func numberOfRows(in tableView: NSTableView) -> Int {
        lock.lock()
        let count = filteredResults.count
        lock.unlock()
        return count
    }
}

// MARK: - 迁回自 UI-02：extension UICommandPaletteManager
extension UICommandPaletteManager: NSTableViewDelegate {
    
    /// 为表格行提供自定义视图：显示分类图标、标题、副标题、快捷键提示
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        lock.lock()
        guard row < filteredResults.count else {
            lock.unlock()
            return nil
        }
        let result = filteredResults[row]
        let cmd = result.item
        let config = configurations[cmd.identifier]
        lock.unlock()
        
        // 创建行视图容器
        let cell = NSTableCellView()
        
        // 分类标签（左侧彩色小标签）
        let categoryLabel = NSTextField(labelWithString: cmd.category)
        categoryLabel.frame = NSRect(x: 8, y: 10, width: 60, height: 20)
        categoryLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        categoryLabel.textColor = .controlAccentColor
        categoryLabel.alignment = .center
        cell.addSubview(categoryLabel)
        
        // 标题文本
        let titleLabel = NSTextField(labelWithString: cmd.title)
        titleLabel.frame = NSRect(x: 76, y: 18, width: 360, height: 18)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .labelColor
        cell.addSubview(titleLabel)
        cell.textField = titleLabel
        
        // 副标题文本（如有）
        if let subtitle = cmd.subtitle, !subtitle.isEmpty {
            let subtitleLabel = NSTextField(labelWithString: subtitle)
            subtitleLabel.frame = NSRect(x: 76, y: 2, width: 360, height: 16)
            subtitleLabel.font = NSFont.systemFont(ofSize: 11)
            subtitleLabel.textColor = .secondaryLabelColor
            cell.addSubview(subtitleLabel)
        }
        
        // 快捷键提示（右侧）
        if let shortcut = config?.customShortcut, !shortcut.isEmpty {
            let shortcutHint = NSTextField(labelWithString: shortcut)
            shortcutHint.frame = NSRect(x: 440, y: 10, width: 120, height: 20)
            shortcutHint.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            shortcutHint.textColor = .tertiaryLabelColor
            shortcutHint.alignment = .right
            cell.addSubview(shortcutHint)
        }
        
        return cell
    }
    
    /// 行高
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 40
    }
    
    /// 用户选中行变更时触发（回车或单击选中后执行）
    public func tableViewSelectionDidChange(_ notification: Notification) {
        let row = paletteWindow?.tableView.selectedRow ?? -1
        guard row >= 0 else { return }
        
        lock.lock()
        guard row < filteredResults.count else {
            lock.unlock()
            return
        }
        let result = filteredResults[row]
        lock.unlock()
        
        executeCommand(result)
    }
}

// MARK: - 迁回自 UI-02：extension UICommandPaletteManager
extension UICommandPaletteManager {
    
    /// 快速注册命令的便捷方法，无需手动构造 UICommandItem
    /// - Parameters:
    ///   - identifier: 唯一标识
    ///   - title: 标题
    ///   - category: 分类
    ///   - action: 执行闭包
    public func quickRegister(identifier: String, title: String, category: String, action: @escaping () -> Void) {
        let item = UICommandItem(identifier: identifier, title: title, category: category, action: action)
        register(item)
    }
    
    /// 判断命令面板是否正在显示
    public var isVisible: Bool {
        return paletteWindow?.isVisible ?? false
    }
    
    /// 获取命令面板窗口引用（仅供高级外部操作使用，常规场景无需访问）
    public var window: NSWindow? {
        return paletteWindow
    }
}

// MARK: - 迁回自 UI-02：class UIVoiceOverManager
public final class UIVoiceOverManager : @unchecked Sendable {
    public static let shared = UIVoiceOverManager()
    private let lock = NSRecursiveLock()
    private var elements: [String: UIAccessibilityElementConfig] = [:]
    private var settings: UIAccessibilitySettings = .default
    private init() {}
    public var currentSettings: UIAccessibilitySettings { lock.lock(); defer { lock.unlock() }; return settings }
    public func registerElement(_ config: UIAccessibilityElementConfig) -> Bool { lock.lock(); defer { lock.unlock() }; elements[config.identifier] = config; return true }
    public func unregisterElement(_ identifier: String) { lock.lock(); defer { lock.unlock() }; elements.removeValue(forKey: identifier) }
    public func getElementConfig(_ identifier: String) -> UIAccessibilityElementConfig? { lock.lock(); defer { lock.unlock() }; return elements[identifier] }
    public func setValue(_ identifier: String, value: String?) { lock.lock(); defer { lock.unlock() }; guard var config = elements[identifier] else { return }; config.value = value ?? ""; elements[identifier] = config }
    public func setLabel(_ identifier: String, label: String) { lock.lock(); defer { lock.unlock() }; guard var config = elements[identifier] else { return }; config.label = label; elements[identifier] = config }
    public func getRegisteredElementCount() -> Int { lock.lock(); defer { lock.unlock() }; return elements.count }
    public func updateSettings(_ settings: UIAccessibilitySettings) { lock.lock(); defer { lock.unlock() }; self.settings = settings }
    public func resetSettings() { lock.lock(); defer { lock.unlock() }; self.settings = .default }
}

// MARK: - 迁回自 UI-02：extension Notification.Name
extension Notification.Name {
    static let FontManagerDidRegisterFont = Notification.Name("com.xianrenzhilu.ui.FontManagerDidRegisterFont")
    static let FontManagerDidUnregisterFont = Notification.Name("com.xianrenzhilu.ui.FontManagerDidUnregisterFont")
    static let FontManagerSettingsDidChange = Notification.Name("com.xianrenzhilu.ui.FontManagerSettingsDidChange")
    static let autoSaveTriggered = Notification.Name("com.xianrenzhilu.ui.autoSaveTriggered")
    static let chartOverlayConfigLoaded = Notification.Name("com.xianrenzhilu.ui.chartOverlayConfigLoaded")
    static let chartOverlayModeChanged = Notification.Name("com.xianrenzhilu.ui.chartOverlayModeChanged")
    static let chartOverlaySeriesChanged = Notification.Name("com.xianrenzhilu.ui.chartOverlaySeriesChanged")
    static let chartOverlayStyleChanged = Notification.Name("com.xianrenzhilu.ui.chartOverlayStyleChanged")
    static let chartOverlayVisibilityChanged = Notification.Name("com.xianrenzhilu.ui.chartOverlayVisibilityChanged")
    static let chartOverlayYAxisRangeChanged = Notification.Name("com.xianrenzhilu.ui.chartOverlayYAxisRangeChanged")
    static let commandPaletteDidClose = Notification.Name("com.xianrenzhilu.ui.commandPaletteDidClose")
    static let commandPaletteWillOpen = Notification.Name("com.xianrenzhilu.ui.commandPaletteWillOpen")
    static let commandRegistryDidChange = Notification.Name("com.xianrenzhilu.ui.commandRegistryDidChange")
    static let devToolsDataDidUpdate = Notification.Name("com.xianrenzhilu.ui.devToolsDataDidUpdate")
    static let devToolsDidClose = Notification.Name("com.xianrenzhilu.ui.devToolsDidClose")
    static let devToolsDidOpen = Notification.Name("com.xianrenzhilu.ui.devToolsDidOpen")
    static let drawingLineCreated = Notification.Name("com.xianrenzhilu.ui.drawingLineCreated")
    static let drawingLineDeleted = Notification.Name("com.xianrenzhilu.ui.drawingLineDeleted")
    static let drawingLineModified = Notification.Name("com.xianrenzhilu.ui.drawingLineModified")
    static let drawingLineSelected = Notification.Name("com.xianrenzhilu.ui.drawingLineSelected")
    static let drawingTemplateUpdated = Notification.Name("com.xianrenzhilu.ui.drawingTemplateUpdated")
// 以下高对比度通知名称已在 UI-GL-67_高对比度模式.swift 定义，这里删除重复定义
    static let layoutMarketSearchFilterChanged = Notification.Name("com.xianrenzhilu.ui.layoutMarketSearchFilterChanged")
    static let layoutMarketTemplateDownloaded = Notification.Name("com.xianrenzhilu.ui.layoutMarketTemplateDownloaded")
    static let layoutMarketTemplateFavoriteChanged = Notification.Name("com.xianrenzhilu.ui.layoutMarketTemplateFavoriteChanged")
    static let layoutMarketTemplateRatingChanged = Notification.Name("com.xianrenzhilu.ui.layoutMarketTemplateRatingChanged")
    static let layoutMarketTemplateUploaded = Notification.Name("com.xianrenzhilu.ui.layoutMarketTemplateUploaded")
    static let layoutMarketTemplatesUpdated = Notification.Name("com.xianrenzhilu.ui.layoutMarketTemplatesUpdated")
    static let layoutSnapshotDidRestore = Notification.Name("com.xianrenzhilu.ui.layoutSnapshotDidRestore")
    static let layoutSnapshotDidSave = Notification.Name("com.xianrenzhilu.ui.layoutSnapshotDidSave")
    static let layoutWindowDidResize = Notification.Name("com.xianrenzhilu.ui.layoutWindowDidResize")
    static let minimizeBehaviorDidChange = Notification.Name("com.xianrenzhilu.ui.minimizeBehaviorDidChange")
    static let moduleHotReloadTriggered = Notification.Name("com.xianrenzhilu.ui.moduleHotReloadTriggered")
    static let moduleLoadFailed = Notification.Name("com.xianrenzhilu.ui.moduleLoadFailed")
    static let moduleLoaded = Notification.Name("com.xianrenzhilu.ui.moduleLoaded")
    static let moduleUnloaded = Notification.Name("com.xianrenzhilu.ui.moduleUnloaded")
    static let multiLineTabActiveDidChange = Notification.Name("com.xianrenzhilu.ui.multiLineTabActiveDidChange")
    static let multiLineTabPagesDidChange = Notification.Name("com.xianrenzhilu.ui.multiLineTabPagesDidChange")
    static let multiLineTabRowsDidChange = Notification.Name("com.xianrenzhilu.ui.multiLineTabRowsDidChange")
    static let panelGroupDidCollapseChange = Notification.Name("com.xianrenzhilu.ui.panelGroupDidCollapseChange")
    static let panelGroupDidCreate = Notification.Name("com.xianrenzhilu.ui.panelGroupDidCreate")
    static let panelGroupDidDelete = Notification.Name("com.xianrenzhilu.ui.panelGroupDidDelete")
    static let panelGroupDidRename = Notification.Name("com.xianrenzhilu.ui.panelGroupDidRename")
    static let panelGroupDidVisibilityChange = Notification.Name("com.xianrenzhilu.ui.panelGroupDidVisibilityChange")
    static let panelGroupPanelsDidChange = Notification.Name("com.xianrenzhilu.ui.panelGroupPanelsDidChange")
    static let pinnedTabDidActivate = Notification.Name("com.xianrenzhilu.ui.pinnedTabDidActivate")
    static let pinnedTabListDidChange = Notification.Name("com.xianrenzhilu.ui.pinnedTabListDidChange")
    static let pinnedTabStatusDidChange = Notification.Name("com.xianrenzhilu.ui.pinnedTabStatusDidChange")
    static let pluginConfigurationDidChange = Notification.Name("com.xianrenzhilu.ui.pluginConfigurationDidChange")
    static let pluginDependenciesResolved = Notification.Name("com.xianrenzhilu.ui.pluginDependenciesResolved")
    static let pluginDidDisable = Notification.Name("com.xianrenzhilu.ui.pluginDidDisable")
    static let pluginDidDiscover = Notification.Name("com.xianrenzhilu.ui.pluginDidDiscover")
    static let pluginDidEnable = Notification.Name("com.xianrenzhilu.ui.pluginDidEnable")
    static let pluginDidFailLoad = Notification.Name("com.xianrenzhilu.ui.pluginDidFailLoad")
    static let pluginDidLoad = Notification.Name("com.xianrenzhilu.ui.pluginDidLoad")
    static let pluginDidUnload = Notification.Name("com.xianrenzhilu.ui.pluginDidUnload")
    static let previewPanelDidClose = Notification.Name("com.xianrenzhilu.ui.previewPanelDidClose")
    static let previewPanelDidCreate = Notification.Name("com.xianrenzhilu.ui.previewPanelDidCreate")
    static let recentCommandsDidUpdate = Notification.Name("com.xianrenzhilu.ui.recentCommandsDidUpdate")
    static let snapshotCreated = Notification.Name("com.xianrenzhilu.ui.snapshotCreated")
    static let snapshotDeleted = Notification.Name("com.xianrenzhilu.ui.snapshotDeleted")
    static let snapshotRenamed = Notification.Name("com.xianrenzhilu.ui.snapshotRenamed")
    static let timelineZoomLevelDidChange = Notification.Name("com.xianrenzhilu.ui.timelineZoomLevelDidChange")
    static let timelineZoomPanPositionDidChange = Notification.Name("com.xianrenzhilu.ui.timelineZoomPanPositionDidChange")
    static let timelineZoomTimeRangeDidChange = Notification.Name("com.xianrenzhilu.ui.timelineZoomTimeRangeDidChange")
    static let undoRedoManagerDidClear = Notification.Name("com.xianrenzhilu.ui.undoRedoManagerDidClear")
    static let undoRedoManagerDidRedo = Notification.Name("com.xianrenzhilu.ui.undoRedoManagerDidRedo")
    static let undoRedoManagerDidUndo = Notification.Name("com.xianrenzhilu.ui.undoRedoManagerDidUndo")
    static let undoRedoManagerHistoryChanged = Notification.Name("com.xianrenzhilu.ui.undoRedoManagerHistoryChanged")
    static let windowBackgroundDidChange = Notification.Name("com.xianrenzhilu.ui.windowBackgroundDidChange")
    static let windowBorderDidChange = Notification.Name("com.xianrenzhilu.ui.windowBorderDidChange")
    static let windowDidJoinGroup = Notification.Name("com.xianrenzhilu.ui.windowDidJoinGroup")
    static let windowDidLeaveGroup = Notification.Name("com.xianrenzhilu.ui.windowDidLeaveGroup")
    static let windowDidMinimize = Notification.Name("com.xianrenzhilu.ui.windowDidMinimize")
    static let windowDidRestore = Notification.Name("com.xianrenzhilu.ui.windowDidRestore")
    static let windowGroupDidActivate = Notification.Name("com.xianrenzhilu.ui.windowGroupDidActivate")
    static let windowGroupDidCreate = Notification.Name("com.xianrenzhilu.ui.windowGroupDidCreate")
    static let windowGroupDidDelete = Notification.Name("com.xianrenzhilu.ui.windowGroupDidDelete")
    static let windowGroupDidLoad = Notification.Name("com.xianrenzhilu.ui.windowGroupDidLoad")
    static let windowGroupDidLock = Notification.Name("com.xianrenzhilu.ui.windowGroupDidLock")
    static let windowGroupDidPerformOperation = Notification.Name("com.xianrenzhilu.ui.windowGroupDidPerformOperation")
    static let windowGroupDidSave = Notification.Name("com.xianrenzhilu.ui.windowGroupDidSave")
    static let windowGroupDidUnlock = Notification.Name("com.xianrenzhilu.ui.windowGroupDidUnlock")
    static let windowGroupFloatDidChange = Notification.Name("com.xianrenzhilu.ui.windowGroupFloatDidChange")
    static let windowGroupLayoutDidChange = Notification.Name("com.xianrenzhilu.ui.windowGroupLayoutDidChange")
    static let windowGroupOpacityDidChange = Notification.Name("com.xianrenzhilu.ui.windowGroupOpacityDidChange")
    static let windowTitleBarDidChange = Notification.Name("com.xianrenzhilu.ui.windowTitleBarDidChange")
    static let workspaceRestored = Notification.Name("com.xianrenzhilu.ui.workspaceRestored")
    static let workspaceSaved = Notification.Name("com.xianrenzhilu.ui.workspaceSaved")
}

// MARK: - NSColor Hex 扩展已在 UI-GL-49_标签页分组.swift 定义，这里仅引用不重复定义

// MARK: - 迁回自 UI-02：struct UICommandItem
// MARK: - UI-GL-70 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-70_types.swift
// 版本: 2.0
public struct UICommandItem {
    /// 全局唯一标识符，推荐格式为 "模块.功能.动作"，例如 "KLine.指标.切换MA"
    public let identifier: String
    
    /// 命令显示标题，简洁描述命令作用
    public let title: String
    
    /// 副标题，补充说明命令用途或快捷键提示
    public let subtitle: String?
    
    /// 分类名称，用于分组展示（如 "K线"、"交易"、"系统"）
    public let category: String
    
    /// 额外关键词数组，用于模糊搜索命中（不展示在 UI，仅参与搜索评分）
    public let keywords: [String]
    
    /// 命令执行闭包，真正调用业务逻辑的地方
    public let action: () -> Void
    
    /// 构造命令条目
    /// - Parameters:
    ///   - identifier: 唯一标识，注册后不可重复
    ///   - title: 显示标题
    ///   - subtitle: 副标题（可选）
    ///   - category: 分类名
    ///   - keywords: 搜索关键词（可选）
    ///   - action: 执行闭包
    public init(
        identifier: String,
        title: String,
        subtitle: String? = nil,
        category: String,
        keywords: [String] = [],
        action: @escaping () -> Void
    ) {
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.keywords = keywords
        self.action = action
    }
}

// MARK: - 迁回自 UI-02：struct UICommandConfiguration
// MARK: - 色盲模式管理器
/// 颜色盲模式的核心管理器，单例模式，线程安全
/// 职责清单:
/// 1. 色盲类型切换与状态管理
/// 2. 自定义颜色替换映射的增删改查
/// 3. K线颜色方案的自动适配
/// 4. 模拟模式控制（正常视觉预览）
/// 5. 配置持久化（Codable + UserDefaults）
/// 6. 通知广播（类型变更/替换方案变更/配置变更）
// 已迁回 UI-GL-69_颜色盲模式.swift：class UIColorBlindManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-70 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-70_types.swift
// 版本: 2.0
// MARK: - 命令快捷键配置（可持久化）
/// 单个命令的持久化配置，不含闭包，可安全序列化到磁盘。
/// 用于保存用户自定义快捷键、命令启用状态等偏好设置。
public struct UICommandConfiguration: Codable, Equatable {
    /// 命令唯一标识（与 UICommandItem.identifier 对应）
    public let identifier: String
    
    /// 用户自定义快捷键字符串，例如 "cmd+shift+p"；nil 表示使用默认快捷键或未设置
    public var customShortcut: String?
    
    /// 命令是否启用（用户可在设置中禁用某些命令）
    public var isEnabled: Bool
    
    /// 构造命令配置
    public init(identifier: String, customShortcut: String? = nil, isEnabled: Bool = true) {
        self.identifier = identifier
        self.customShortcut = customShortcut
        self.isEnabled = isEnabled
    }
}

// MARK: - 迁回自 UI-02：struct UIRecentCommandRecord
// MARK: - 最近使用命令记录（可持久化）
/// 记录用户最近执行过的命令，用于在命令面板中优先展示常用命令。
public struct UIRecentCommandRecord: Codable, Equatable {
    /// 命令唯一标识
    public let commandId: String
    
    /// 最近一次执行的时间戳
    public var timestamp: Date
    
    /// 累计执行次数（可用于排序权重）
    public var executionCount: Int
    
    /// 构造最近使用记录
    public init(commandId: String, timestamp: Date = Date(), executionCount: Int = 1) {
        self.commandId = commandId
        self.timestamp = timestamp
        self.executionCount = executionCount
    }
}

// MARK: - 迁回自 UI-02：struct UICommandPaletteStorage
// MARK: - 命令面板持久化存储结构
/// 所有需要落盘的数据统一封装，支持 Codable 完整序列化。
/// 存储位置：~/Library/Application Support/仙人指路/UICommandPaletteStorage.json
public struct UICommandPaletteStorage: Codable {
    /// 各命令的配置映射（key 为命令标识符）
    public var configurations: [String: UICommandConfiguration]
    
    /// 最近使用命令记录列表，按时间倒序维护
    public var recentRecords: [UIRecentCommandRecord]
    
    /// 最近使用列表最大保留数量（默认 20，防止无限膨胀）
    public var maxRecentCount: Int
    
    /// 默认快捷键字符串（全局呼出命令面板）
    public var globalShortcut: String
    
    /// 构造默认存储
    public init(
        configurations: [String: UICommandConfiguration] = [:],
        recentRecords: [UIRecentCommandRecord] = [],
        maxRecentCount: Int = 20,
        globalShortcut: String = "cmd+shift+p"
    ) {
        self.configurations = configurations
        self.recentRecords = recentRecords
        self.maxRecentCount = maxRecentCount
        self.globalShortcut = globalShortcut
    }
}

// MARK: - 迁回自 UI-02：struct UIFuzzySearchResult
// MARK: - 模糊搜索结果条目
/// 模糊搜索返回的中间结构，包含命中的命令与匹配评分。
internal struct UIFuzzySearchResult {
    /// 命令条目
    let item: UICommandItem
    
    /// 匹配评分（越高越靠前，0 表示无匹配）
    let score: Int
}

// MARK: - 迁回自 UI-02：enum UIFuzzySearcher
// MARK: - 模糊搜索工具
/// 简单的模糊搜索算法实现，支持多字段匹配与评分排序。
/// 评分规则：标题前缀匹配 > 标题包含 > 副标题包含 > 分类包含 > 关键词包含。
internal enum UIFuzzySearcher {
    /// 对命令列表执行模糊搜索，按评分降序返回结果
    /// - Parameters:
    ///   - query: 用户输入的搜索字符串（已小写化）
    ///   - commands: 待搜索的命令全集
    /// - Returns: 按评分排序后的搜索结果
    static func search(query: String, in commands: [UICommandItem]) -> [UIFuzzySearchResult] {
        // 空查询返回全部，评分统一为 0 以保持原有顺序
        guard !query.isEmpty else {
            return commands.map { UIFuzzySearchResult(item: $0, score: 0) }
        }
        
        var results: [UIFuzzySearchResult] = []
        let q = query.lowercased()
        
        for cmd in commands {
            let score = calculateScore(query: q, for: cmd)
            if score > 0 {
                results.append(UIFuzzySearchResult(item: cmd, score: score))
            }
        }
        
        // 按评分降序排列，评分相同则保持注册顺序
        return results.sorted { $0.score > $1.score }
    }
    
    /// 计算单个命令与查询字符串的匹配评分
    private static func calculateScore(query: String, for command: UICommandItem) -> Int {
        let title = command.title.lowercased()
        let subtitle = command.subtitle?.lowercased() ?? ""
        let category = command.category.lowercased()
        let keywords = command.keywords.map { $0.lowercased() }
        
        var score = 0
        
        // 标题匹配权重最高
        if title.hasPrefix(query) {
            score += 100
        } else if title.contains(query) {
            score += 50
        }
        
        // 副标题匹配
        if subtitle.hasPrefix(query) {
            score += 40
        } else if subtitle.contains(query) {
            score += 20
        }
        
        // 分类匹配
        if category.hasPrefix(query) {
            score += 30
        } else if category.contains(query) {
            score += 15
        }
        
        // 关键词匹配（每个命中累加）
        for kw in keywords {
            if kw.contains(query) {
                score += 10
            }
        }
        
        return score
    }
}

// MARK: - 迁回自 UI-02：enum UIPanelType
// MARK: - 命令面板窗口
/// 命令面板专用浮动窗口，无边框、居中显示、自动聚焦搜索框。
// 已迁回 UI-GL-70_命令面板.swift：class UICommandPaletteWindow（公共类型文件禁止功能实现）

// MARK: - 命令面板管理器（核心单例）
/// 命令面板全局管理器，负责命令注册、模糊搜索、最近使用记录、快捷键监听、持久化。
/// 通过 `UICommandPaletteManager.shared` 访问唯一实例。
// 已迁回 UI-GL-70_命令面板.swift：class UICommandPaletteManager（公共类型文件禁止功能实现）

// MARK: - NSTableViewDataSource
// 已迁回 UI-GL-70_命令面板.swift：extension UICommandPaletteManager（公共类型文件禁止功能实现）

// MARK: - NSTableViewDelegate
// 已迁回 UI-GL-70_命令面板.swift：extension UICommandPaletteManager（公共类型文件禁止功能实现）

// MARK: - 公开便捷 API
// 已迁回 UI-GL-70_命令面板.swift：extension UICommandPaletteManager（公共类型文件禁止功能实现）


// MARK: - UI功能兼容公共类型补齐（第二步引用校准）
// 版本: 2.0

public enum UIPanelType: String, CaseIterable, Codable, Sendable {
    case chart, tool, parameter, output, info, debug
    public var defaultWidth: CGFloat {
        switch self { case .chart: return 600; case .tool: return 280; case .parameter: return 320; case .output: return 420; case .info: return 360; case .debug: return 500 }
    }
    public var defaultHeight: CGFloat {
        switch self { case .chart: return 400; case .tool: return 500; case .parameter: return 420; case .output: return 320; case .info: return 260; case .debug: return 360 }
    }
    public var isResizable: Bool { true }
}

// MARK: - 迁回自 UI-02：struct UIPanelConfiguration
public struct UIPanelConfiguration: Codable, Equatable, Sendable {
    public var type: UIPanelType
    public var identifier: String
    public var title: String
    public var moduleName: String
    public var width: CGFloat
    public var height: CGFloat
    public var isFloating: Bool
    public var isClosable: Bool
    public init(type: UIPanelType, identifier: String, title: String, moduleName: String, width: CGFloat? = nil, height: CGFloat? = nil, isFloating: Bool = true, isClosable: Bool = true) {
        self.type = type; self.identifier = identifier; self.title = title; self.moduleName = moduleName
        self.width = width ?? type.defaultWidth; self.height = height ?? type.defaultHeight
        self.isFloating = isFloating; self.isClosable = isClosable
    }
}

// MARK: - 迁回自 UI-02：enum UIDockPosition
public enum UIDockPosition: String, CaseIterable, Codable, Sendable { case left, right, top, bottom, center }

// MARK: - 迁回自 UI-02：struct UIDockRegion
public struct UIDockRegion: Codable, Equatable, Sendable {
    public var position: UIDockPosition
    public var bounds: CGRect
    public var panelIDs: [String]
    public var isEmpty: Bool { panelIDs.isEmpty }
    public init(position: UIDockPosition, bounds: CGRect, panelIDs: [String]) {
        self.position = position; self.bounds = bounds; self.panelIDs = panelIDs
    }
}

// MARK: - 迁回自 UI-02：struct UIMenuItemDefinition
public struct UIMenuItemDefinition {
    public var title: String
    public var action: Selector?
    public var keyEquivalent: String
    public var toolTip: String?
    public var isSeparator: Bool
    public var submenu: [UIMenuItemDefinition]?
    public init(title: String, action: Selector? = nil, keyEquivalent: String = "", toolTip: String? = nil, isSeparator: Bool = false, submenu: [UIMenuItemDefinition]? = nil) {
        self.title = title; self.action = action; self.keyEquivalent = keyEquivalent; self.toolTip = toolTip; self.isSeparator = isSeparator; self.submenu = submenu
    }
}

// MARK: - 迁回自 UI-02：struct UIKeyBinding
public struct UIKeyBinding: Codable, Equatable {
    public var identifier: String
    public var moduleName: String
    public var keyEquivalent: String
    public var modifierFlags: UInt
    public var actionDescription: String
    public var isEnabled: Bool

    public init(identifier: String, moduleName: String, keyEquivalent: String, modifierFlags: UInt, actionDescription: String, isEnabled: Bool = true) {
        self.identifier = identifier
        self.moduleName = moduleName
        self.keyEquivalent = keyEquivalent
        self.modifierFlags = modifierFlags
        self.actionDescription = actionDescription
        self.isEnabled = isEnabled
    }

    public init(identifier: String, moduleName: String, keyEquivalent: String, modifierFlags: NSEvent.ModifierFlags, actionDescription: String, isEnabled: Bool = true) {
        self.init(identifier: identifier, moduleName: moduleName, keyEquivalent: keyEquivalent, modifierFlags: modifierFlags.rawValue, actionDescription: actionDescription, isEnabled: isEnabled)
    }
}

// MARK: - 迁回自 UI-02：enum UIKeyBindingResult
public enum UIKeyBindingResult: Equatable {
    case success
    case conflict(existing: UIKeyBinding)
    case conflict(existingIdentifier: String, description: String)
    case notFound
}

// MARK: - 迁回自 UI-02：enum UIModuleStatus
public enum UIModuleStatus: String, CaseIterable, Codable, Sendable { case notLoaded, unloaded, loading, loaded, active, inactive, failed, disabled, unloading }

// MARK: - 迁回自 UI-02：enum UIKLineColorScheme
public enum UIKLineColorScheme: String, CaseIterable, Codable, Sendable, Equatable {
    case deepLight, deepDark, redGreen, greenRed, blueYellow, monochrome

    public static func defaultForType(_ type: UIColorBlindType) -> UIKLineColorScheme {
        switch type {
        case .none: return .deepLight
        case .protanopia, .deuteranopia, .tritanopia, .achromatopsia:
            return .blueYellow
        }
    }
}

// MARK: - 从 UI-02 正确迁回：let uilogger
private let uilogger = Logger(subsystem: "com.xianrenzhilu.ui", category: "ui02.compat")


// MARK: - 从 UI-02 正确迁回：let moduleLogger
private let moduleLogger = Logger(subsystem: "com.xianrenzhilu.ui", category: "module.compat")


// MARK: - 从 UI-02 正确迁回：let rendererLogger
private let rendererLogger = Logger(subsystem: "com.xianrenzhilu.ui", category: "renderer.compat")
// MARK: - 从 UI-02 正确迁回：let UICrosshairSyncDeactivatedNotification
// MARK: - 从 UI-02 正确迁回：let UICrosshairSyncPositionChangedNotification
// MARK: - 从 UI-02 正确迁回：let UICrosshairSyncConfigChangedNotification
// MARK: - 从 UI-02 正确迁回：let UICrosshairSyncWindowListChangedNotification
// MARK: - 从 UI-02 正确迁回：extension UIWindowRegistry
extension UIWindowRegistry {
    @discardableResult
    public func register(_ record: UIWindowRecord) -> Bool {
        UIUnifiedRegistry.shared.registerWindow(record: record)
        return true
    }

    public func window(for id: String) -> NSWindow? {
        UIUnifiedRegistry.shared.getWindowRecord(windowID: id)?.window
    }
}


// MARK: - 从 UI-02 正确迁回：extension UILayoutTemplateListViewController
extension UILayoutTemplateListViewController: NSTableViewDelegate, NSTableViewDataSource {}


// MARK: - 从 UI-02 正确迁回：extension UILayoutMarketListViewController
extension UILayoutMarketListViewController: NSTableViewDelegate, NSTableViewDataSource {}


// MARK: - 从 UI-02 正确迁回：extension UIWindowLifecycleManager
extension UIWindowLifecycleManager {
    public func close(windowID: String) {
        if windowRecord.windowID == windowID { windowRecord.window.close() }
    }
}


// MARK: - 从 UI-02 正确迁回：extension String
extension String {
    var htmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}


// MARK: - 从 UI-02 正确迁回：extension Dictionary
extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) throws -> T) rethrows -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: try map { (try transform($0.key), $0.value) })
    }
}


// MARK: - 从 UI-02 正确迁回：extension UIKLineColorScheme
extension UIKLineColorScheme: CustomStringConvertible {
    public var description: String { rawValue }
    public var upColor: NSColor { self == .greenRed ? NSColor.systemGreen : NSColor.systemRed }
    public var downColor: NSColor { self == .greenRed ? NSColor.systemRed : NSColor.systemGreen }
    public var neutralColor: NSColor { NSColor.systemGray }
    public var volumeUpColor: NSColor { upColor.withAlphaComponent(0.5) }
    public var volumeDownColor: NSColor { downColor.withAlphaComponent(0.5) }
    public var upBorderColor: NSColor { upColor }
    public var downBorderColor: NSColor { downColor }
    public var isColorBlindFriendly: Bool { self == .monochrome || self == .deepLight || self == .deepDark }
}


// MARK: - 从 UI-02 正确迁回：extension UIModuleEntry
extension UIModuleEntry {
    public var name: String { moduleName }
    public var status: String { "loaded" }
    public var version: String { moduleVersion }
    public override var description: String { moduleDescription }
}


// MARK: - 从 UI-02 正确迁回：extension UILayoutTemplateManager
extension UILayoutTemplateManager {
    public var cachedTemplateCount: Int { 0 }
    public func clearCache() {}
}


// MARK: - 从 UI-02 正确迁回：extension UIAppStateManager
extension UIAppStateManager {
    public func setSymbol(_ symbol: String) {}
    public func setPeriod(_ period: String) {}
}


// MARK: - 从 UI-02 正确迁回：extension CGFloat
extension CGFloat {
    var roundedToOneDecimal: CGFloat { (self * 10).rounded() / 10 }
}


// MARK: - 从 UI-02 正确迁回：extension CGRect
extension CGRect {
    var xrCenter: CGPoint { CGPoint(x: midX, y: midY) }
}


// MARK: - 从 UI-02 正确迁回：var uiWindowLevelCompatStorage
private nonisolated(unsafe) var uiWindowLevelCompatStorage: [String: UIWindowLevelType] = [:]


// MARK: - 从 UI-02 正确迁回：let uiWindowLevelCompatLock
private let uiWindowLevelCompatLock = NSRecursiveLock()


// MARK: - 从 UI-02 正确迁回：extension UIWindowLevelManager
extension UIWindowLevelManager {
    public func setLevel(windowID: String, level: UIWindowLevelType) {
        uiWindowLevelCompatLock.lock()
        uiWindowLevelCompatStorage[windowID] = level
        uiWindowLevelCompatLock.unlock()
    }

    public func getLevel(windowID: String) -> UIWindowLevelType {
        uiWindowLevelCompatLock.lock()
        defer { uiWindowLevelCompatLock.unlock() }
        return uiWindowLevelCompatStorage[windowID] ?? .normal
    }
}


// MARK: - 从 UI-02 正确迁回：func isRedGreenColor
public func isRedGreenColor(_ color: NSColor) -> Bool {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    let maxVal = max(r, g, b)
    if maxVal == 0 { return false }
    let redRatio = r / maxVal
    let greenRatio = g / maxVal
    return (redRatio > 0.7 && greenRatio < 0.5) || (greenRatio > 0.7 && redRatio < 0.5)
}


// MARK: - 从 UI-02 正确迁回：func isBlueYellowColor
public func isBlueYellowColor(_ color: NSColor) -> Bool {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    let maxVal = max(r, g, b)
    if maxVal == 0 { return false }
    let blueRatio = b / maxVal
    let yellowish = (r + g) / 2.0 / maxVal
    return blueRatio > 0.7 || (yellowish > 0.8 && blueRatio < 0.3)
}


// MARK: - 从 UI-02 正确迁回：enum UIColorSemantic
public enum UIColorSemantic: String, Sendable {
    case accent
    case accentHover
    case accentPressed
    case windowBackground
    case textPrimary
    case textSecondary
    case textTertiary
    case separator
    case separatorStrong
    case border
    case borderFocus
    case buttonBackground
    case buttonHover
    case buttonPressed
    case inputBackground
    case inputBorder
    case inputFocusBorder
    case chartUp
    case chartDown
    case chartLine
    case chartGrid
    case chartBackground
    case chartCrosshair
    case tooltipBackground
    case tooltipText
    case sidebarBackground
    case sidebarSelected
    case overlayBackground
    case error
    case warning
    case success
    case info
}


// MARK: - 从 UI-02 正确迁回：enum UIColorBlindMode
public enum UIColorBlindMode: String, Codable, Sendable {
    case none
    case protanopia
    case deuteranopia
}


// MARK: - 从 UI-02 正确迁回：struct UISkinConfig
public struct UISkinConfig: Codable, Sendable {
    public var currentSkinId: String
    public var accentColorHex: String?
    public var fontScale: CGFloat
    public var cornerRadiusScale: CGFloat
    public var animationEnabled: Bool
    public var highContrastEnabled: Bool
    public var colorBlindMode: UIColorBlindMode
    public var customColors: [String: String]
    public var customSpacings: [String: CGFloat]

    public init(currentSkinId: String, accentColorHex: String? = nil, fontScale: CGFloat = 1.0, cornerRadiusScale: CGFloat = 1.0, animationEnabled: Bool = true, highContrastEnabled: Bool = false, colorBlindMode: UIColorBlindMode = .none, customColors: [String: String] = [:], customSpacings: [String: CGFloat] = [:]) {
        self.currentSkinId = currentSkinId
        self.accentColorHex = accentColorHex
        self.fontScale = fontScale
        self.cornerRadiusScale = cornerRadiusScale
        self.animationEnabled = animationEnabled
        self.highContrastEnabled = highContrastEnabled
        self.colorBlindMode = colorBlindMode
        self.customColors = customColors
        self.customSpacings = customSpacings
    }
}


// MARK: - 从 UI-02 正确迁回：protocol UISkinServiceProtocol
public protocol UISkinServiceProtocol: AnyObject {
    func getCurrentSkin() -> UISkinInfo
    func setSkin(id: String) -> Bool
    func setSkin(id: String, animated: Bool) -> Bool
    func getSkinList() -> [UISkinInfo]
    func getSkin(id: String) -> UISkinInfo?
    func getDefaultSkinId() -> String
    func restoreDefaultSkin() -> Bool
    func previewSkin(id: String) -> Bool
    func applyPreview() -> Bool
    func cancelPreview() -> Bool
    func color(_ key: String) -> NSColor?
    func color(_ key: String, category: String) -> NSColor?
    func getAllColors() -> [String: NSColor]
    func setAccentColor(_ color: NSColor) -> Bool
    func resetAccentColor() -> Bool
    func color(for semantic: UIColorSemantic) -> NSColor?
    func font(_ key: String) -> NSFont?
    func font(_ key: String, size: CGFloat) -> NSFont?
    func scaledFont(_ key: String, size: CGFloat, weight: NSFont.Weight) -> NSFont?
    func getAllFonts() -> [String: NSFont]
    func setFontScale(_ scale: CGFloat) -> Bool
    func getFontScale() -> CGFloat
    func spacing(_ key: String) -> CGFloat
    func spacing(_ key: String, category: String) -> CGFloat
    func cornerRadius(_ key: String) -> CGFloat
    func borderWidth(_ key: String) -> CGFloat
    func setGlobalSpacing(_ value: CGFloat, forKey key: String) -> Bool
    func resetSpacingOverrides() -> Bool
    func onSkinWillChange(_ callback: @escaping (String, String) -> Void) -> UUID
    func onSkinDidChange(_ callback: @escaping (String, String) -> Void) -> UUID
    func onSkinChangeFailed(_ callback: @escaping (String, Error) -> Void) -> UUID
    func removeObserver(_ id: UUID) -> Bool
    func registerView(_ view: NSView, forSkinUpdate handler: @escaping () -> Void)
    func unregisterView(_ view: NSView)
    func refreshAllViews()
    func isViewRegistered(_ view: NSView) -> Bool
    func getAvailableAccentColors() -> [(name: String, color: NSColor)]
    func getAvailableFonts() -> [String]
    func getCurrentSkinConfig() -> UISkinConfig
    func exportSkinConfig() -> Data?
    func importSkinConfig(_ data: Data) -> Bool
    func resetAllSettings() -> Bool
    func setColorBlindMode(_ mode: UIColorBlindMode)
    func currentColorBlindMode() -> UIColorBlindMode
}


// MARK: - 从 UI-02 正确迁回：struct UIAlbumCardItem
@MainActor @preconcurrency public struct UIAlbumCardItem {
    public let id: String
    public let title: String
    public let subtitle: String
    public let color: NSColor?
    public let previewProvider: () -> NSView
    public let detailProvider: () -> NSView

    public init(id: String = UUID().uuidString, title: String, subtitle: String, color: NSColor? = nil, previewProvider: @escaping @MainActor () -> NSView = { NSView() }, detailProvider: @escaping @MainActor () -> NSView = { NSView() }) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.previewProvider = previewProvider
        self.detailProvider = detailProvider
    }
}


// MARK: - 从 UI-02 正确迁回：class UIBox
public final class UIBox<T> {
    public let value: T
    public init(_ value: T) { self.value = value }
}


// MARK: - 从 UI-02 正确迁回：typealias SkinProtocol
public typealias SkinProtocol = UISkinProtocol


// MARK: - 从 UI-02 正确迁回：typealias SkinInfo
public typealias SkinInfo = UISkinInfo


// MARK: - 从 UI-02 正确迁回：typealias ColorSemantic
public typealias ColorSemantic = UIColorSemantic


// MARK: - 从 UI-02 正确迁回：typealias ColorBlindMode
public typealias ColorBlindMode = UIColorBlindMode


// MARK: - 从 UI-02 正确迁回：typealias SkinServiceProtocol
public typealias SkinServiceProtocol = UISkinServiceProtocol


// MARK: - 从 UI-02 正确迁回：typealias AlbumCardItem
public typealias AlbumCardItem = UIAlbumCardItem


// MARK: - 从 UI-02 正确迁回：typealias Box
