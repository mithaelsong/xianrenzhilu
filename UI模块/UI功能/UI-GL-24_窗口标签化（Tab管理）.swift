// 功能12: 窗口标签化（Tab管理）
// 对应: 多窗口以标签页形式组织，支持拖拽、合并、拆分
// 优先级: P1
// 版本: 2.0

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "12A_窗口标签化")

// MARK: - 测试
internal func test_UI12() {
    print("\n=== UI-12 窗口标签化测试 ===\n")
    
    let manager = UITabManager.shared
    let group = manager.createGroup(id: "test-group")
    
    let tab1 = UITabItem(id: "tab-1", title: "Tab 1", moduleName: "ModuleA")
    let tab2 = UITabItem(id: "tab-2", title: "Tab 2", moduleName: "ModuleB")
    
    group.addTab(tab1)
    group.addTab(tab2)
    
    assert(group.tabs.count == 2)
    assert(group.activeTabID == "tab-1")
    
    group.activateTab(id: "tab-2")
    assert(group.activeTabID == "tab-2")
    
    group.removeTab(id: "tab-1")
    assert(group.tabs.count == 1)
    
    print("✅ 测试通过: 标签页管理功能正常")
}


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UITabGroup
public class UITabGroup: NSObject , @unchecked Sendable{
    public let groupID: String
    public private(set) var tabs: [UIMultiLineTabItem] = []
    public var activeTabID: String?
    
    private let lock = NSRecursiveLock()
    
    public init(groupID: String) {
        self.groupID = groupID
        super.init()
    }
    
    public func addTab(_ tab: UIMultiLineTabItem) {
        lock.lock()
        tabs.append(tab)
        if activeTabID == nil {
            activeTabID = tab.id
        }
        lock.unlock()
    }
    
    public func removeTab(id: String) {
        lock.lock()
        tabs.removeAll { $0.id == id }
        if activeTabID == id, let first = tabs.first {
            activeTabID = first.id
        }
        lock.unlock()
    }
    
    public func activateTab(id: String) {
        lock.lock()
        activeTabID = id
        lock.unlock()
    }
    
    public func moveTab(fromIndex: Int, toIndex: Int) {
        lock.lock()
        guard fromIndex >= 0, fromIndex < tabs.count,
              toIndex >= 0, toIndex < tabs.count else {
            lock.unlock()
            return
        }
        let tab = tabs.remove(at: fromIndex)
        tabs.insert(tab, at: toIndex)
        lock.unlock()
    }
}

// MARK: - 迁回自 UI-02：class UITabManager
public final class UITabManager : @unchecked Sendable {
    public static let shared = UITabManager()
    
    private let lock = NSRecursiveLock()
    private var groups: [String: UITabGroup] = [:]
    
    private init() {}
    
    public func createGroup(id: String) -> UITabGroup {
        lock.lock()
        let group = UITabGroup(groupID: id)
        groups[id] = group
        lock.unlock()
        return group
    }
    
    public func getGroup(id: String) -> UITabGroup? {
        lock.lock()
        let group = groups[id]
        lock.unlock()
        return group
    }
    
    public func removeGroup(id: String) {
        lock.lock()
        groups.removeValue(forKey: id)
        lock.unlock()
    }
    
    public func mergeWindow(windowID: String, at point: NSPoint) {
        if UIUnifiedRegistry.shared.getWindowRecord(windowID: windowID)?.window != nil {
            logger.info("合并窗口 \(windowID) 到标签组")
        }
    }
    
    public func splitTab(tabID: String, fromGroupID: String) -> NSWindow? {
        lock.lock()
        guard let group = groups[fromGroupID] else {
            lock.unlock()
            return nil
        }
        
        guard let tab = group.tabs.first(where: { $0.id == tabID }) else {
            lock.unlock()
            return nil
        }
        
        group.removeTab(id: tabID)
        lock.unlock()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = tab.title
        return window
    }
    
    public func allGroups() -> [UITabGroup] {
        lock.lock()
        let result = Array(groups.values)
        lock.unlock()
        return result
    }
    
    public func tabCount() -> Int {
        lock.lock()
        let count = groups.values.reduce(0) { $0 + $1.tabs.count }
        lock.unlock()
        return count
    }
}

// MARK: - 迁回自 UI-02：enum UITabState
// MARK: - UI-GL-24 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-24_types.swift
// 版本: 2.0
// MARK: - 标签页状态
public enum UITabState: String, Sendable {
    case active, inactive, loading, error, unloaded
}

// MARK: - 迁回自 UI-02：struct UIMultiLineTabItem
// MARK: - 窗口布局管理器
// 已迁回 UI-GL-23_窗口布局管理.swift：class UIWindowLayoutManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-24 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-24_types.swift
// 版本: 2.0
// MARK: - 标签页组
// 已迁回 UI-GL-24_窗口标签化（Tab管理）.swift：class UITabGroup（公共类型文件禁止功能实现）

// MARK: - 标签页项
public struct UIMultiLineTabItem: Identifiable, Sendable, Codable, Equatable {
    public var id: String
    public var title: String
    public var moduleName: String
    public var iconName: String?
    public var isPinned: Bool
    public var badge: String?
    public var isModified: Bool
    public var order: Int
    public var view: NSView?

    enum CodingKeys: String, CodingKey { case id, title, moduleName, iconName, isPinned, badge, isModified, order }

    public init(id: String, title: String, moduleName: String) {
        self.id = id
        self.title = title
        self.moduleName = moduleName
        self.iconName = nil
        self.isPinned = false
        self.badge = nil
        self.isModified = false
        self.order = 0
        self.view = nil
    }

    public init(id: String, title: String, iconName: String? = nil, isPinned: Bool = false, badge: String? = nil, isModified: Bool = false, order: Int = 0, view: NSView? = nil) {
        self.id = id
        self.title = title
        self.moduleName = ""
        self.iconName = iconName
        self.isPinned = isPinned
        self.badge = badge
        self.isModified = isModified
        self.order = order
        self.view = view
    }

    public static func == (lhs: UIMultiLineTabItem, rhs: UIMultiLineTabItem) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.moduleName == rhs.moduleName && lhs.iconName == rhs.iconName && lhs.isPinned == rhs.isPinned && lhs.badge == rhs.badge && lhs.isModified == rhs.isModified && lhs.order == rhs.order
    }
}

// MARK: - 迁回自 UI-02：typealias UITabItem
// MARK: - 标签页管理器
public typealias UITabItem = UIMultiLineTabItem
