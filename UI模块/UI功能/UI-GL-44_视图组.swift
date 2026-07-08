// 功能34B: 视图组 (View Group)
// 对应: 多个视图可编组,拖拽/关闭/缩放时作为一个整体操作
// 优先级: P2

import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "34B_视图组")

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能34B:视图组 - 单元测试
func test_viewGroup() {
    let manager = UIViewGroupManager.shared
    var allPassed = true

    logger.info("测试1: 创建编组")
    let group = manager.createGroup(groupID: "test", name: "测试组")
    if group.name != "测试组" {
        logger.error("❌ 测试1失败: 组名不匹配")
        allPassed = false
    } else {
        logger.info("✅ 测试1通过: 创建成功")
    }

    logger.info("测试2: 添加成员")
    let v = NSView()
    group.addMember(v)
    if group.count != 1 {
        logger.error("❌ 测试2失败: 应有一个成员")
        allPassed = false
    } else {
        logger.info("✅ 测试2通过: 添加成员成功")
    }

    if allPassed {
        logger.info("=== 全部视图组测试通过 ✅ ===")
    } else {
        logger.error("=== 部分视图组测试失败 ❌ ===")
    }
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIViewGroup
public final class UIViewGroup : @unchecked Sendable {

    public let groupID: String
    public let name: String
    private var _isLocked: Bool = false
    private var _isCollapsed: Bool = false

    /// 是否锁定(线程安全)
    public var isLocked: Bool {
        lock.lock()
        let v = _isLocked
        lock.unlock()
        return v
    }

    /// 是否折叠(线程安全)
    public var isCollapsed: Bool {
        lock.lock()
        let v = _isCollapsed
        lock.unlock()
        return v
    }

    private var memberViews: [NSView] = []
    private let lock = NSRecursiveLock()

    public init(groupID: String, name: String) {
        self.groupID = groupID
        self.name = name
    }

    /// 设置锁定状态(线程安全)
    public func setIsLocked(_ locked: Bool) {
        lock.lock()
        _isLocked = locked
        lock.unlock()
    }

    /// 设置折叠状态(线程安全)
    public func setIsCollapsed(_ collapsed: Bool) {
        lock.lock()
        _isCollapsed = collapsed
        lock.unlock()
    }

    /// 添加成员视图
    public func addMember(_ view: NSView) {
        lock.lock()
        if !memberViews.contains(where: { $0 === view }) {
            memberViews.append(view)
        }
        lock.unlock()
    }

    /// 移除成员视图
    public func removeMember(_ view: NSView) {
        lock.lock()
        memberViews.removeAll { $0 == view }
        lock.unlock()
    }

    /// 获取所有成员
    public var members: [NSView] {
        lock.lock()
        let result = Array(memberViews)
        lock.unlock()
        return result
    }

    /// 整体显示
    public func showAll() {
        for v in members { v.isHidden = false }
    }

    /// 整体隐藏
    public func hideAll() {
        for v in members { v.isHidden = true }
    }

    /// 组成员数量
    public var count: Int {
        lock.lock()
        let c = memberViews.count
        lock.unlock()
        return c
    }
}

// MARK: - 迁回自 UI-02：class UIViewGroupManager
public final class UIViewGroupManager : @unchecked Sendable {

    public static let shared = UIViewGroupManager()

    private var groups: [String: UIViewGroup] = [:]
    private let lock = NSRecursiveLock()

    private init() {}

    deinit {
        logger.info("UIViewGroupManager 已释放")
    }

    /// 创建编组
    public func createGroup(groupID: String, name: String) -> UIViewGroup {
        let group = UIViewGroup(groupID: groupID, name: name)
        lock.lock()
        groups[groupID] = group
        lock.unlock()
        return group
    }

    /// 获取编组
    public func group(for groupID: String) -> UIViewGroup? {
        lock.lock()
        let g = groups[groupID]
        lock.unlock()
        return g
    }

    /// 删除编组
    public func deleteGroup(groupID: String) {
        lock.lock()
        groups.removeValue(forKey: groupID)
        lock.unlock()
    }

    /// 所有编组ID
    public var allGroupIDs: [String] {
        lock.lock()
        let ids = Array(groups.keys)
        lock.unlock()
        return ids
    }
}
