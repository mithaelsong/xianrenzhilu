// 功能19: 工具栏管理
// 对应: 模块可以添加工具栏按钮
// 优先级: P2

import AppKit
import os


// MARK: - 工具栏管理器
/// 工具栏管理器 (功能19)
/// 管理窗口工具栏的注册、注销与展示
/// 实现 NSToolbarDelegate 以动态提供工具栏项
public final class KJToolbarManager: NSObject, NSToolbarDelegate , @unchecked Sendable{
    public static let shared = KJToolbarManager()

    private var items: [String: KJToolbarItemDefinition] = [:]
    private var moduleItems: [String: [String]] = [:]
    private weak var toolbar: NSToolbar?
    private var lock = os_unfair_lock()
    private let logger = KJModuleLogger.shared

    public override init() {}

    // MARK: - 设置工具栏

    /// 为指定窗口设置并配置工具栏
    /// - Parameter window: 目标窗口
    public func setupToolbar(for window: NSWindow) {
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true

        window.toolbar = toolbar
        self.toolbar = toolbar

        logger.info("KJToolbarManager", "已设置窗口工具栏: \(window.title)")
    }

    // MARK: - 注册工具栏项

    /// 注册工具栏项
    /// - Parameters:
    ///   - definition: 工具栏项定义
    ///   - module: 所属模块名称（不能为空）
    public func registerItem(_ definition: KJToolbarItemDefinition, for module: String) {
        guard !module.isEmpty, !definition.identifier.isEmpty else {
            logger.warning("KJToolbarManager", "registerItem失败: 模块名或标识符为空")
            return
        }

        os_unfair_lock_lock(&lock)
        items[definition.identifier] = definition
        moduleItems[module, default: []].append(definition.identifier)
        os_unfair_lock_unlock(&lock)

        // 若工具栏已绑定窗口，插入新项
        if let toolbar = toolbar {
            toolbar.insertItem(withItemIdentifier: NSToolbarItem.Identifier(definition.identifier), at: items.count - 1)
        }

        logger.info("KJToolbarManager", "已注册工具栏项 '\(definition.identifier)' 模块: \(module)")
    }

    // MARK: - 移除工具栏项

    /// 移除指定模块的所有工具栏项
    /// - Parameter module: 模块名称
    public func unregisterItems(for module: String) {
        os_unfair_lock_lock(&lock)
        let ids = moduleItems.removeValue(forKey: module) ?? []
        for id in ids {
            items.removeValue(forKey: id)
        }
        os_unfair_lock_unlock(&lock)

        // 从工具栏移除
        if let toolbar = toolbar {
            for id in ids {
                if let index = toolbar.items.firstIndex(where: { $0.itemIdentifier.rawValue == id }) {
                    toolbar.removeItem(at: index)
                }
            }
        }

        if !ids.isEmpty {
            logger.info("KJToolbarManager", "已注销模块 \(module) 的 \(ids.count) 个工具栏项")
        }
    }

    /// 移除所有工具栏项
    public func unregisterAllItems() {
        os_unfair_lock_lock(&lock)
        let ids = Array(items.keys)
        items.removeAll()
        moduleItems.removeAll()
        os_unfair_lock_unlock(&lock)

        // 清空工具栏
        if let toolbar = toolbar {
            while toolbar.items.count > 0 {
                toolbar.removeItem(at: 0)
            }
        }

        logger.info("KJToolbarManager", "已注销所有工具栏项 (数量: \(ids.count))")
    }

    // MARK: - 查询

    /// 获取指定模块的工具栏项标识符列表
    /// - Parameter module: 模块名称
    /// - Returns: 标识符数组
    public func toolbarItems(for module: String) -> [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return moduleItems[module] ?? []
    }

    /// 获取所有已注册的工具栏项标识符
    /// - Returns: 标识符数组
    public func allItemIdentifiers() -> [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return Array(items.keys)
    }

    /// 获取工具栏项定义
    /// - Parameter identifier: 标识符
    /// - Returns: 定义对象，不存在时返回 nil
    public func definition(for identifier: String) -> KJToolbarItemDefinition? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return items[identifier]
    }

    // MARK: - NSToolbarDelegate

    public func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        os_unfair_lock_lock(&lock)
        let definition = items[itemIdentifier.rawValue]
        os_unfair_lock_unlock(&lock)

        guard let def = definition else { return nil }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = def.label
        item.toolTip = def.tooltip

        if let icon = def.icon {
            item.image = icon
        }

        item.target = self
        item.action = #selector(handleToolbarAction(_:))
        item.tag = itemIdentifier.rawValue.hashValue

        return item
    }

    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        os_unfair_lock_lock(&lock)
        let ids = items.keys.map { NSToolbarItem.Identifier($0) }
        os_unfair_lock_unlock(&lock)
        return ids
    }

    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }

    public func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return []
    }

    // MARK: - 动作处理

    @objc private func handleToolbarAction(_ sender: NSToolbarItem) {
        let id = sender.itemIdentifier.rawValue

        os_unfair_lock_lock(&lock)
        let definition = items[id]
        os_unfair_lock_unlock(&lock)

        definition?.action?()

        logger.debug("KJToolbarManager", "工具栏动作已触发: \(id)")
    }
}
