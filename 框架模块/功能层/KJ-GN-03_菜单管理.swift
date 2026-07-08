// 功能18: 菜单管理
// 对应: 主菜单栏的动态添加/移除（模块可以添加自己的菜单项）
// 优先级: P2

import AppKit
import os


// MARK: - 菜单管理器

/// 菜单管理器 (功能18)
/// 管理主菜单栏中各模块的菜单注册与注销
/// 使用 os_unfair_lock 保证线程安全
public final class KJMenuManager: @unchecked Sendable {
    
    // MARK: - 单例
    public static let shared = KJMenuManager()
    
    // MARK: - 私有状态
    private var menuItems: [String: KJMenuItemDefinition] = [:]
    private var moduleMenus: [String: [String]] = [:]
    private var lock = os_unfair_lock()
    private let logger = KJModuleLogger.shared
    
    private init() {}
    
    // MARK: - 注册 / 注销
    
    /// 注册菜单项
    /// - Parameters:
    ///   - definition: 菜单项定义
    ///   - moduleName: 模块名称
    /// - Returns: 是否注册成功
    @discardableResult
    public func registerItem(_ definition: KJMenuItemDefinition, for moduleName: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        guard !definition.identifier.isEmpty, !moduleName.isEmpty else {
            logger.warning("KJMenuManager", "注册失败: 标识符或模块名不能为空")
            return false
        }
        
        // 如果标识符已存在，先从旧模块的列表中移除
        if let oldModule = moduleMenus.first(where: { $0.value.contains(definition.identifier) })?.key {
            moduleMenus[oldModule]?.removeAll { $0 == definition.identifier }
        }
        
        menuItems[definition.identifier] = definition
        moduleMenus[moduleName, default: []].append(definition.identifier)
        
        logger.info("KJMenuManager", "菜单项 '\(definition.title)' 已注册到模块 \(moduleName)")
        return true
    }
    
    /// 注销指定标识符的菜单项
    /// - Parameter identifier: 菜单项标识符
    /// - Returns: 是否注销成功
    @discardableResult
    public func unregisterItem(identifier: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        guard menuItems[identifier] != nil else {
            logger.warning("KJMenuManager", "注销失败: 菜单项 '\(identifier)' 不存在")
            return false
        }
        
        menuItems.removeValue(forKey: identifier)
        
        // 从所有模块的列表中移除
        for (module, var items) in moduleMenus {
            items.removeAll { $0 == identifier }
            moduleMenus[module] = items
        }
        
        logger.info("KJMenuManager", "菜单项 '\(identifier)' 已注销")
        return true
    }
    
    /// 注销指定模块的所有菜单项
    /// - Parameter moduleName: 模块名称
    /// - Returns: 注销的菜单项数量
    @discardableResult
    public func unregisterAllItems(for moduleName: String) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        guard let items = moduleMenus[moduleName] else {
            return 0
        }
        
        for identifier in items {
            menuItems.removeValue(forKey: identifier)
        }
        
        moduleMenus.removeValue(forKey: moduleName)
        
        logger.info("KJMenuManager", "模块 \(moduleName) 的 \(items.count) 个菜单项已注销")
        return items.count
    }
    
    // MARK: - 查询
    
    /// 获取所有菜单项标识符
    public var allItemIdentifiers: [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return Array(menuItems.keys)
    }
    
    /// 获取指定模块的菜单项标识符
    /// - Parameter moduleName: 模块名称
    /// - Returns: 菜单项标识符列表
    public func itemIdentifiers(for moduleName: String) -> [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return moduleMenus[moduleName] ?? []
    }
    
    /// 获取菜单项定义
    /// - Parameter identifier: 菜单项标识符
    /// - Returns: 菜单项定义
    public func definition(for identifier: String) -> KJMenuItemDefinition? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return menuItems[identifier]
    }
    
    /// 检查菜单项是否存在
    /// - Parameter identifier: 菜单项标识符
    /// - Returns: 是否存在
    public func hasItem(_ identifier: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return menuItems[identifier] != nil
    }
    
    // MARK: - 构建菜单
    
    /// 为指定模块构建NSMenu
    /// - Parameter moduleName: 模块名称
    /// - Returns: NSMenu对象
    public func buildMenu(for moduleName: String) -> NSMenu? {
        os_unfair_lock_lock(&lock)
        let identifiers = moduleMenus[moduleName] ?? []
        let definitions = identifiers.compactMap { menuItems[$0] }
        os_unfair_lock_unlock(&lock)
        
        guard !definitions.isEmpty else { return nil }
        
        let menu = NSMenu(title: moduleName)
        for definition in definitions {
            let item = NSMenuItem(
                title: definition.title,
                action: definition.action,
                keyEquivalent: definition.keyEquivalent
            )
            item.target = definition.target
            item.identifier = NSUserInterfaceItemIdentifier(definition.identifier)
            menu.addItem(item)
        }
        
        return menu
    }
    
    /// 构建包含所有模块菜单的主菜单
    /// - Returns: NSMenu对象
    public func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu(title: "主菜单")
        
        os_unfair_lock_lock(&lock)
        let modules = Array(moduleMenus.keys).sorted()
        os_unfair_lock_unlock(&lock)
        
        for moduleName in modules {
            if let menu = buildMenu(for: moduleName) {
                let menuItem = NSMenuItem(title: moduleName, action: nil, keyEquivalent: "")
                menuItem.submenu = menu
                mainMenu.addItem(menuItem)
            }
        }
        
        return mainMenu
    }
}
