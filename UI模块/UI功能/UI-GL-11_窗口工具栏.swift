// 功能10A: 窗口工具栏
// 对应: 管理多窗口工具栏实例，支持动态添加/移除/启用/禁用工具项，切换显示模式与风格
// 优先级: P0
// 版本: 2.0

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "10A_窗口工具栏")

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能10A：窗口工具栏 — 单元测试
/// 覆盖：数据模型创建、配置默认值、管理器状态
func test_windowToolbar() {
    print("\n🧪 测试1: UIToolbarItemDefinition创建")
    let def = UIToolbarItemDefinition(
        identifier: "test_btn",
        label: "测试按钮",
        iconName: "gearshape",
        tooltip: "这是一个测试按钮",
        isEnabled: true,
        tag: 100
    )
    guard def.identifier == "test_btn" else {
        fatalError("❌ 测试1失败: identifier不匹配")
    }
    guard def.label == "测试按钮" else {
        fatalError("❌ 测试1失败: label不匹配")
    }
    guard def.tag == 100 else {
        fatalError("❌ 测试1失败: tag不匹配")
    }
    guard def.isEnabled else {
        fatalError("❌ 测试1失败: isEnabled应为true")
    }
    print("✅ 测试1通过: UIToolbarItemDefinition创建正确")
    
    print("\n🧪 测试2: UIToolbarConfiguration默认值")
    let config = UIToolbarConfiguration(identifier: "default.toolbar")
    guard config.identifier == "default.toolbar" else {
        fatalError("❌ 测试2失败: identifier不匹配")
    }
    guard config.displayMode == .iconAndLabel else {
        fatalError("❌ 测试2失败: 默认displayMode应为iconAndLabel")
    }
    guard config.isVisible else {
        fatalError("❌ 测试2失败: 默认isVisible应为true")
    }
    guard config.allowsUserCustomization else {
        fatalError("❌ 测试2失败: 默认allowsUserCustomization应为true")
    }
    print("✅ 测试2通过: UIToolbarConfiguration默认值正确")
    
    print("\n🧪 测试3: 自定义配置")
    let customConfig = UIToolbarConfiguration(
        identifier: "custom.toolbar",
        displayMode: .iconOnly,
        isVisible: false,
        allowsUserCustomization: false,
        autosavesConfiguration: false,
        showsBaselineSeparator: false
    )
    guard customConfig.displayMode == .iconOnly else {
        fatalError("❌ 测试3失败: 自定义displayMode不匹配")
    }
    guard !customConfig.isVisible else {
        fatalError("❌ 测试3失败: 自定义isVisible应为false")
    }
    print("✅ 测试3通过: 自定义配置正确")
    
    print("\n🧪 测试4: 管理器初始状态")
    let manager = UIWindowToolbarManager.shared
    let windowIDs = manager.allWindowIDs
    guard windowIDs.isEmpty else {
        fatalError("❌ 测试4失败: 初始应无工具栏")
    }
    print("✅ 测试4通过: 管理器初始无工具栏")
    
    print("\n=== 全部工具栏测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIToolbarItemWrapper
internal class UIToolbarItemWrapper : @unchecked Sendable {
    let definition: UIToolbarItemDefinition
    weak var item: NSToolbarItem?
    var isEnabled: Bool

    init(definition: UIToolbarItemDefinition) {
        self.definition = definition
        self.isEnabled = definition.isEnabled
    }
}

// MARK: - 迁回自 UI-02：class UIToolbarInstanceWrapper
internal class UIToolbarInstanceWrapper : @unchecked Sendable {
    let toolbar: NSToolbar
    let window: NSWindow
    let configuration: UIToolbarConfiguration
    var itemWrappers: [String: UIToolbarItemWrapper] = [:]   // 标识符 -> 项包装器
    var orderedIdentifiers: [String] = []                   // 项的显示顺序
    weak var delegate: UIToolbarInstanceDelegate?
    let lock = NSRecursiveLock()                            // 实例级线程锁

    init(toolbar: NSToolbar, window: NSWindow, configuration: UIToolbarConfiguration) {
        self.toolbar = toolbar
        self.window = window
        self.configuration = configuration
    }
}

// MARK: - 迁回自 UI-02：class UIToolbarInstanceDelegate
internal class UIToolbarInstanceDelegate: NSObject, NSToolbarDelegate , @unchecked Sendable{
    weak var wrapper: UIToolbarInstanceWrapper?

    init(wrapper: UIToolbarInstanceWrapper) {
        self.wrapper = wrapper
        super.init()
    }

    // MARK: - 默认项标识符
    /// 返回工具栏默认显示的项标识符列表
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        guard let wrapper = wrapper else { return [] }
        wrapper.lock.lock()
        defer { wrapper.lock.unlock() }

        let ids = wrapper.orderedIdentifiers.map { NSToolbarItem.Identifier($0) }
        logger.info("返回默认项标识符: \(ids.map { $0.rawValue })")
        return ids
    }

    // MARK: - 允许项标识符
    /// 返回工具栏允许显示的所有项标识符列表（包括定制面板中可用的）
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        guard let wrapper = wrapper else { return [] }
        wrapper.lock.lock()
        defer { wrapper.lock.unlock() }

        var ids: [NSToolbarItem.Identifier] = [
            .flexibleSpace,
            .space,
            NSToolbarItem.Identifier("ui.custom.separator")
        ]
        for identifier in wrapper.orderedIdentifiers {
            ids.append(NSToolbarItem.Identifier(identifier))
        }
        logger.info("返回允许项标识符: \(ids.map { $0.rawValue })")
        return ids
    }

    // MARK: - 创建工具栏项
    /// 根据标识符创建对应的 NSToolbarItem 实例
    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let wrapper = wrapper else { return nil }
        wrapper.lock.lock()
        defer { wrapper.lock.unlock() }

        let rawId = itemIdentifier.rawValue

        // 处理系统内置项
        if itemIdentifier == .flexibleSpace {
            logger.info("创建弹性空间项")
            return NSToolbarItem(itemIdentifier: .flexibleSpace)
        }
        if itemIdentifier == .space {
            logger.info("创建固定空间项")
            return NSToolbarItem(itemIdentifier: .space)
        }
        if itemIdentifier.rawValue == "NSToolbarSeparatorItem" || itemIdentifier.rawValue == "ui.custom.separator" {
            logger.info("创建分隔符项")
            return NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("ui.custom.separator"))
        }

        guard let itemWrapper = wrapper.itemWrappers[rawId] else {
            logger.info("未找到标识符对应的项定义: \(rawId)")
            return nil
        }

        let def = itemWrapper.definition
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = def.label
        item.paletteLabel = def.paletteLabel ?? def.label
        item.toolTip = def.tooltip
        item.isBordered = def.isBordered
        item.tag = def.tag
        item.target = def.target
        item.action = def.action
        item.isEnabled = itemWrapper.isEnabled

        // 设置图标
        if let iconName = def.iconName {
            let image = NSImage(systemSymbolName: iconName, accessibilityDescription: def.label)
            item.image = image
        }

        itemWrapper.item = item
        logger.info("创建工具栏项: \(def.label) (标识符: \(rawId), 启用: \(itemWrapper.isEnabled))")
        return item
    }

    // MARK: - 可选代理方法
    /// 工具栏项即将被插入时的回调
    func toolbarWillAddItem(_ notification: Notification) {
        if let item = notification.userInfo?["item"] as? NSToolbarItem {
            logger.info("即将添加项: \(item.itemIdentifier.rawValue)")
        }
    }

    /// 工具栏项即将被移除时的回调
    func toolbarDidRemoveItem(_ notification: Notification) {
        if let item = notification.userInfo?["item"] as? NSToolbarItem {
            logger.info("已移除项: \(item.itemIdentifier.rawValue)")
        }
    }
}

// MARK: - 迁回自 UI-02：class UIWindowToolbarManager
public final class UIWindowToolbarManager : @unchecked Sendable {
    deinit {
        logger.info("UIWindowToolbarManager 已释放")
    }


    // MARK: - 单例
    /// 全局共享实例
    public static let shared = UIWindowToolbarManager()

    // MARK: - 属性
    /// 存储所有已管理的工具栏实例，键为窗口标识符
    private var toolbars: [String: UIToolbarInstanceWrapper] = [:]
    /// 全局线程锁，保护 toolbars 字典的并发访问
    private let globalLock = NSRecursiveLock()

    // MARK: - 初始化
    /// 私有初始化，确保单例模式
    private init() {
        logger.info("单例初始化完成")
    }

    // MARK: - 添加工具栏
    /// 为指定窗口添加并配置工具栏
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - configuration: 工具栏配置，默认为标准配置
    ///   - windowID: 窗口标识符，用于后续管理，默认为窗口描述字符串
    /// - Returns: 是否成功添加
    @discardableResult
    public func addToolbar(to window: NSWindow,
                           configuration: UIToolbarConfiguration = UIToolbarConfiguration(identifier: "default.toolbar"),
                           windowID: String? = nil) -> Bool {
        let id = windowID ?? "window_\(window.hash)"
        
        // 先创建 NSToolbar 和包装器，不在锁内避免触发系统回调
        let toolbar = NSToolbar(identifier: configuration.identifier)
        toolbar.displayMode = configuration.displayMode
        toolbar.isVisible = configuration.isVisible
        toolbar.allowsUserCustomization = configuration.allowsUserCustomization
        toolbar.autosavesConfiguration = configuration.autosavesConfiguration
        
        let wrapper = UIToolbarInstanceWrapper(toolbar: toolbar, window: window, configuration: configuration)
        let delegate = UIToolbarInstanceDelegate(wrapper: wrapper)
        toolbar.delegate = delegate
        wrapper.delegate = delegate
        
        // 锁内只操作 toolbars 字典
        globalLock.lock()
        guard toolbars[id] == nil else {
            globalLock.unlock()
            logger.info("窗口已存在工具栏，无法重复添加 (窗口ID: \(id))")
            return false
        }
        toolbars[id] = wrapper
        globalLock.unlock()
        
        // 解锁后才设置 window.toolbar，避免锁内触发系统回调
        window.toolbar = toolbar
        
        logger.info("已为窗口添加工具栏 (窗口ID: \(id), 标识符: \(configuration.identifier))")
        return true
    }

    // MARK: - 移除工具栏
    /// 从指定窗口移除工具栏
    /// - Parameter windowID: 窗口标识符
    /// - Returns: 是否成功移除
    @discardableResult
    public func removeToolbar(from windowID: String) -> Bool {
        let wrapper: UIToolbarInstanceWrapper?
        globalLock.lock()
        wrapper = toolbars.removeValue(forKey: windowID)
        globalLock.unlock()
        
        guard let w = wrapper else {
            logger.info("未找到窗口的工具栏，无法移除 (窗口ID: \(windowID))")
            return false
        }
        
        w.lock.lock()
        w.window.toolbar = nil
        w.lock.unlock()
        
        logger.info("已移除窗口的工具栏 (窗口ID: \(windowID))")
        return true
    }

    // MARK: - 添加工具栏项
    /// 向指定窗口的工具栏添加一个项
    /// - Parameters:
    ///   - definition: 工具栏项定义
    ///   - windowID: 窗口标识符
    ///   - atIndex: 插入位置，nil 表示追加到末尾
    /// - Returns: 是否成功添加
    @discardableResult
    public func addItem(_ definition: UIToolbarItemDefinition,
                        to windowID: String,
                        atIndex: Int? = nil) -> Bool {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            logger.info("未找到窗口，无法添加项 (窗口ID: \(windowID), 项: \(definition.label))")
            return false
        }
        globalLock.unlock()

        wrapper.lock.lock()
        defer { wrapper.lock.unlock() }

        guard wrapper.itemWrappers[definition.identifier] == nil else {
            logger.info("项标识符已存在，无法重复添加 (窗口ID: \(windowID), 标识符: \(definition.identifier))")
            return false
        }

        let itemWrapper = UIToolbarItemWrapper(definition: definition)
        wrapper.itemWrappers[definition.identifier] = itemWrapper

        if let index = atIndex, index >= 0, index <= wrapper.orderedIdentifiers.count {
            wrapper.orderedIdentifiers.insert(definition.identifier, at: index)
        } else {
            wrapper.orderedIdentifiers.append(definition.identifier)
        }

        // 刷新工具栏显示
        wrapper.toolbar.validateVisibleItems()
        wrapper.toolbar.insertItem(withItemIdentifier: NSToolbarItem.Identifier(definition.identifier), at: atIndex ?? wrapper.toolbar.items.count)

        logger.info("已添加项 (窗口ID: \(windowID), 项: \(definition.label), 位置: \(atIndex ?? wrapper.orderedIdentifiers.count - 1))")
        return true
    }

    // MARK: - 移除工具栏项
    /// 从指定窗口的工具栏移除一个项
    /// - Parameters:
    ///   - identifier: 项标识符
    ///   - windowID: 窗口标识符
    /// - Returns: 是否成功移除
    @discardableResult
    public func removeItem(_ identifier: String, from windowID: String) -> Bool {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            logger.info("未找到窗口，无法移除项 (窗口ID: \(windowID), 标识符: \(identifier))")
            return false
        }
        globalLock.unlock()

        wrapper.lock.lock()
        defer { wrapper.lock.unlock() }

        guard wrapper.itemWrappers.removeValue(forKey: identifier) != nil else {
            logger.info("未找到项，无法移除 (窗口ID: \(windowID), 标识符: \(identifier))")
            return false
        }

        if let index = wrapper.orderedIdentifiers.firstIndex(of: identifier) {
            wrapper.orderedIdentifiers.remove(at: index)
        }

        // 从工具栏中移除对应的实例
        if let itemIndex = wrapper.toolbar.items.firstIndex(where: { $0.itemIdentifier.rawValue == identifier }) {
            wrapper.toolbar.removeItem(at: itemIndex)
        }

        wrapper.toolbar.validateVisibleItems()

        logger.info("已移除项 (窗口ID: \(windowID), 标识符: \(identifier))")
        return true
    }

    // MARK: - 启用工具栏项
    /// 启用指定窗口工具栏中的某个项
    /// - Parameters:
    ///   - identifier: 项标识符
    ///   - windowID: 窗口标识符
    /// - Returns: 是否成功启用
    @discardableResult
    public func enableItem(_ identifier: String, in windowID: String) -> Bool {
        return setItemEnabled(true, identifier: identifier, windowID: windowID)
    }

    // MARK: - 禁用工具栏项
    /// 禁用指定窗口工具栏中的某个项
    /// - Parameters:
    ///   - identifier: 项标识符
    ///   - windowID: 窗口标识符
    /// - Returns: 是否成功禁用
    @discardableResult
    public func disableItem(_ identifier: String, in windowID: String) -> Bool {
        return setItemEnabled(false, identifier: identifier, windowID: windowID)
    }

    // MARK: - 设置项启用状态（内部方法）
    /// 设置指定项的启用状态
    private func setItemEnabled(_ enabled: Bool, identifier: String, windowID: String) -> Bool {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            logger.info("未找到窗口，无法设置项状态 (窗口ID: \(windowID), 标识符: \(identifier))")
            return false
        }
        globalLock.unlock()

        wrapper.lock.lock()
        defer { wrapper.lock.unlock() }

        guard let itemWrapper = wrapper.itemWrappers[identifier] else {
            logger.info("未找到项，无法设置状态 (窗口ID: \(windowID), 标识符: \(identifier))")
            return false
        }

        itemWrapper.isEnabled = enabled
        itemWrapper.item?.isEnabled = enabled
        wrapper.toolbar.validateVisibleItems()

        let stateText = enabled ? "启用" : "禁用"
        logger.info("已\(stateText)项 (窗口ID: \(windowID), 标识符: \(identifier))")
        return true
    }

    // MARK: - 设置显示模式
    /// 设置指定窗口工具栏的显示模式
    /// - Parameters:
    ///   - mode: 目标模式（iconAndLabel / iconOnly / labelOnly / default）
    ///   - windowID: 窗口标识符
    /// - Returns: 是否成功设置
    @discardableResult
    public func setDisplayMode(_ mode: NSToolbar.DisplayMode, for windowID: String) -> Bool {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            logger.info("未找到窗口，无法设置显示模式 (窗口ID: \(windowID))")
            return false
        }
        globalLock.unlock()

        wrapper.lock.lock()
        wrapper.toolbar.displayMode = mode
        wrapper.lock.unlock()

        let modeName: String
        switch mode {
        case .iconAndLabel: modeName = "图标和文字"
        case .iconOnly:     modeName = "仅图标"
        case .labelOnly:    modeName = "仅文字"
        case .default:      modeName = "默认"
        @unknown default:   modeName = "未知"
        }

        logger.info("已设置显示模式为 \(modeName) (窗口ID: \(windowID))")
        return true
    }

    // MARK: - 设置可见性
    /// 设置指定窗口工具栏的可见性
    /// - Parameters:
    ///   - visible: 是否可见
    ///   - windowID: 窗口标识符
    /// - Returns: 是否成功设置
    @discardableResult
    public func setIsVisible(_ visible: Bool, for windowID: String) -> Bool {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            logger.info("未找到窗口，无法设置可见性 (窗口ID: \(windowID))")
            return false
        }
        globalLock.unlock()

        wrapper.lock.lock()
        wrapper.toolbar.isVisible = visible
        wrapper.lock.unlock()

        let stateText = visible ? "显示" : "隐藏"
        logger.info("已\(stateText)工具栏 (窗口ID: \(windowID))")
        return true
    }

    // MARK: - 自定义工具栏
    /// 打开工具栏定制面板，允许用户拖拽重排按钮
    /// - Parameter windowID: 窗口标识符
    /// - Returns: 是否成功打开定制面板
    @discardableResult
    public func customToolbar(for windowID: String) -> Bool {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            logger.info("未找到窗口，无法打开定制面板 (窗口ID: \(windowID))")
            return false
        }
        globalLock.unlock()

        wrapper.lock.lock()
        wrapper.toolbar.runCustomizationPalette(nil)
        wrapper.lock.unlock()

        logger.info("已打开工具栏定制面板 (窗口ID: \(windowID))")
        return true
    }

    // MARK: - 查询方法
    /// 获取指定窗口的所有项定义
    /// - Parameter windowID: 窗口标识符
    /// - Returns: 项定义数组
    public func itemDefinitions(in windowID: String) -> [UIToolbarItemDefinition] {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            return []
        }
        globalLock.unlock()

        wrapper.lock.lock()
        let defs = wrapper.orderedIdentifiers.compactMap { wrapper.itemWrappers[$0]?.definition }
        wrapper.lock.unlock()
        return defs
    }

    /// 获取指定窗口的项数量
    /// - Parameter windowID: 窗口标识符
    /// - Returns: 项数量
    public func itemCount(in windowID: String) -> Int {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            return 0
        }
        globalLock.unlock()

        wrapper.lock.lock()
        let count = wrapper.orderedIdentifiers.count
        wrapper.lock.unlock()
        return count
    }

    /// 检查指定项是否已启用
    /// - Parameters:
    ///   - identifier: 项标识符
    ///   - windowID: 窗口标识符
    /// - Returns: 是否启用，若未找到返回 nil
    public func isItemEnabled(_ identifier: String, in windowID: String) -> Bool? {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            return nil
        }
        globalLock.unlock()

        wrapper.lock.lock()
        let enabled = wrapper.itemWrappers[identifier]?.isEnabled
        wrapper.lock.unlock()
        return enabled
    }

    /// 获取所有已管理的窗口标识符
    /// - Returns: 窗口标识符数组
    public var allWindowIDs: [String] {
        globalLock.lock()
        let ids = Array(toolbars.keys)
        globalLock.unlock()
        return ids
    }

    // MARK: - 批量操作
    /// 批量添加工具栏项
    /// - Parameters:
    ///   - definitions: 工具栏项定义数组
    ///   - windowID: 窗口标识符
    /// - Returns: 成功添加的项数量
    @discardableResult
    public func addItems(_ definitions: [UIToolbarItemDefinition], to windowID: String) -> Int {
        var successCount = 0
        for (index, def) in definitions.enumerated() {
            if addItem(def, to: windowID, atIndex: index) {
                successCount += 1
            }
        }
        logger.info("批量添加完成，成功 \(successCount)/\(definitions.count) 项 (窗口ID: \(windowID))")
        return successCount
    }

    /// 批量移除工具栏项
    /// - Parameters:
    ///   - identifiers: 项标识符数组
    ///   - windowID: 窗口标识符
    /// - Returns: 成功移除的项数量
    @discardableResult
    public func removeItems(_ identifiers: [String], from windowID: String) -> Int {
        var successCount = 0
        for id in identifiers {
            if removeItem(id, from: windowID) {
                successCount += 1
            }
        }
        logger.info("批量移除完成，成功 \(successCount)/\(identifiers.count) 项 (窗口ID: \(windowID))")
        return successCount
    }

    // MARK: - 弹性空间与分隔符
    /// 向工具栏添加弹性空间项
    /// - Parameters:
    ///   - windowID: 窗口标识符
    ///   - atIndex: 插入位置
    /// - Returns: 是否成功添加
    @discardableResult
    public func addFlexibleSpace(to windowID: String, atIndex: Int? = nil) -> Bool {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            logger.info("未找到窗口，无法添加弹性空间 (窗口ID: \(windowID))")
            return false
        }
        globalLock.unlock()

        wrapper.lock.lock()
        let index = atIndex ?? wrapper.toolbar.items.count
        wrapper.toolbar.insertItem(withItemIdentifier: .flexibleSpace, at: index)
        wrapper.lock.unlock()

        logger.info("已添加弹性空间 (窗口ID: \(windowID), 位置: \(index))")
        return true
    }

    /// 向工具栏添加固定空间项
    /// - Parameters:
    ///   - windowID: 窗口标识符
    ///   - atIndex: 插入位置
    /// - Returns: 是否成功添加
    @discardableResult
    public func addFixedSpace(to windowID: String, atIndex: Int? = nil) -> Bool {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            logger.info("未找到窗口，无法添加固定空间 (窗口ID: \(windowID))")
            return false
        }
        globalLock.unlock()

        wrapper.lock.lock()
        let index = atIndex ?? wrapper.toolbar.items.count
        wrapper.toolbar.insertItem(withItemIdentifier: .space, at: index)
        wrapper.lock.unlock()

        logger.info("已添加固定空间 (窗口ID: \(windowID), 位置: \(index))")
        return true
    }

    /// 向工具栏添加分隔符
    /// - Parameters:
    ///   - windowID: 窗口标识符
    ///   - atIndex: 插入位置
    /// - Returns: 是否成功添加
    @discardableResult
    public func addSeparator(to windowID: String, atIndex: Int? = nil) -> Bool {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            logger.info("未找到窗口，无法添加分隔符 (窗口ID: \(windowID))")
            return false
        }
        globalLock.unlock()

        wrapper.lock.lock()
        let index = atIndex ?? wrapper.toolbar.items.count
        wrapper.toolbar.insertItem(withItemIdentifier: NSToolbarItem.Identifier("ui.custom.separator"), at: index)
        wrapper.lock.unlock()

        logger.info("已添加分隔符 (窗口ID: \(windowID), 位置: \(index))")
        return true
    }

    // MARK: - 重置与清理
    /// 重置指定窗口的工具栏到初始状态
    /// - Parameter windowID: 窗口标识符
    /// - Returns: 是否成功重置
    @discardableResult
    public func resetToolbar(for windowID: String) -> Bool {
        globalLock.lock()
        guard let wrapper = toolbars[windowID] else {
            globalLock.unlock()
            logger.info("未找到窗口，无法重置 (窗口ID: \(windowID))")
            return false
        }
        globalLock.unlock()

        wrapper.lock.lock()
        // 移除所有项
        while wrapper.toolbar.items.count > 0 {
            wrapper.toolbar.removeItem(at: 0)
        }
        wrapper.itemWrappers.removeAll()
        wrapper.orderedIdentifiers.removeAll()
        wrapper.lock.unlock()

        logger.info("已重置工具栏 (窗口ID: \(windowID))")
        return true
    }

    /// 移除所有管理的工具栏实例，清理所有资源
    public func removeAllToolbars() {
        globalLock.lock()
        let allIDs = Array(toolbars.keys)
        globalLock.unlock()

        for id in allIDs {
            removeToolbar(from: id)
        }

        logger.info("已清理所有工具栏实例")
    }
}

// MARK: - 迁回自 UI-02：struct UIToolbarItemDefinition
// MARK: - 窗口阴影管理器
/// 窗口阴影管理器（单例）
/// 负责统一管理应用内所有窗口的自定义阴影效果
/// 线程安全：所有公开方法均通过 NSRecursiveLock 加锁保护
// 已迁回 UI-GL-07_窗口阴影自定义.swift：class UIWindowShadowManager（公共类型文件禁止功能实现）


// MARK: - UI功能公共类型批量去重合并（UI-GL-08~70，顶层解析版）
// 策略：先索引 UI-02 已有公共定义，再合并迁移定义中不重复的顶层类型/别名/扩展。
// 版本: 2.0


// MARK: - UI-GL-11 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-11_types.swift
// 版本: 2.0
// MARK: - 工具栏项定义
/// 工具栏项定义，描述一个工具栏按钮的完整信息
public struct UIToolbarItemDefinition {
    public let identifier: String          // 唯一标识符
    public let label: String               // 显示标签
    public let paletteLabel: String?       // 定制面板中的标签
    public let iconName: String?           // SF Symbol 名称
    public let tooltip: String?            // 鼠标悬停提示
    public let isBordered: Bool            // 是否有边框
    public let target: AnyObject?          // 点击目标
    public let action: Selector?           // 点击动作
    public var isEnabled: Bool             // 是否启用
    public let tag: Int                    // 标记值，用于区分功能

    public init(identifier: String, label: String, paletteLabel: String? = nil,
                iconName: String? = nil, tooltip: String? = nil,
                isBordered: Bool = true, target: AnyObject? = nil,
                action: Selector? = nil, isEnabled: Bool = true, tag: Int = 0) {
        self.identifier = identifier
        self.label = label
        self.paletteLabel = paletteLabel ?? label
        self.iconName = iconName
        self.tooltip = tooltip
        self.isBordered = isBordered
        self.target = target
        self.action = action
        self.isEnabled = isEnabled
        self.tag = tag
    }
}

// MARK: - 迁回自 UI-02：struct UIToolbarConfiguration
// MARK: - UIWindowBackgroundManager
/// 窗口背景与边框管理器
/// 全局单例，管理所有窗口的背景样式、边框、圆角和标题栏外观
/// 支持纯色背景、渐变背景、图片背景、自定义边框、圆角裁剪、标题栏自定义
/// 线程安全：所有公开API使用 NSRecursiveLock 保护
// 已迁回 UI-GL-09_窗口背景与边框.swift：class UIWindowBackgroundManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-10 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-10_types.swift
// 版本: 2.0
// MARK: - 面板停靠管理器
/// 管理面板的拖拽吸附、停靠、并排和堆叠
// 已迁回 UI-GL-10_面板停靠吸附.swift：class UIPanelDockManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-11 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-11_types.swift
// 版本: 2.0
// MARK: - 工具栏配置
/// 单个工具栏的配置信息
public struct UIToolbarConfiguration {
    public var identifier: String                  // 工具栏标识符
    public var displayMode: NSToolbar.DisplayMode    // 显示模式
    public var isVisible: Bool                     // 是否可见
    public var allowsUserCustomization: Bool      // 是否允许用户定制
    public var autosavesConfiguration: Bool        // 是否自动保存配置
    public var showsBaselineSeparator: Bool        // 是否显示基线分隔符

    public init(identifier: String,
                displayMode: NSToolbar.DisplayMode = .iconAndLabel,
                isVisible: Bool = true,
                allowsUserCustomization: Bool = true,
                autosavesConfiguration: Bool = true,
                showsBaselineSeparator: Bool = true) {
        self.identifier = identifier
        self.displayMode = displayMode
        self.isVisible = isVisible
        self.allowsUserCustomization = allowsUserCustomization
        self.autosavesConfiguration = autosavesConfiguration
        self.showsBaselineSeparator = showsBaselineSeparator
    }
}
