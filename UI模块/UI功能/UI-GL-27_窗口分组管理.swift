// 功能19B: 窗口分组管理
// 对应: 窗口分组（将多个窗口关联为一个组，组内统一操作）
// 优先级: P2

import AppKit
import Foundation
import os.log

// MARK: - 通知名称
/// 窗口分组管理相关通知
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能19B：窗口分组管理 — 单元测试
/// 覆盖：组创建/窗口加入离开/锁/布局/悬浮/透明度/热键/持久化
func test_windowGroup() {
    let manager = UIWindowGroupManager.shared
    let testWindowID = "test.window.001"
    
    print("\n🧪 测试1: 创建窗口组")
    let group = manager.createGroup(name: "测试组", tagColor: NSColor.blue)
    guard !group.groupID.isEmpty else {
        fatalError("❌ 测试1失败: 组创建失败")
    }
    print("✅ 测试1通过: 组创建成功，ID=\(group.groupID.prefix(8))")
    
    print("\n🧪 测试2: 窗口加入组")
    let joined = manager.addWindowToGroup(windowID: testWindowID, groupID: group.groupID)
    guard joined == true else {
        fatalError("❌ 测试2失败: 加入失败")
    }
    let inGroup = manager.isWindowInGroup(testWindowID)
    guard inGroup else {
        fatalError("❌ 测试2失败: 窗口应已在组中")
    }
    print("✅ 测试2通过: 窗口加入成功")
    
    print("\n🧪 测试3: 查询组信息")
    let fetched = manager.group(for: group.groupID)
    guard fetched?.name == "测试组" else {
        fatalError("❌ 测试3失败: 组名不匹配")
    }
    print("✅ 测试3通过: 组查询正确")
    
    print("\n🧪 测试4: 锁定组")
    let locked = manager.lockGroup(groupID: group.groupID)
    guard locked, (manager.isGroupLocked(groupID: group.groupID)) else {
        fatalError("❌ 测试4失败: 锁定失败")
    }
    print("✅ 测试4通过: 组锁定成功")
    
    print("\n🧪 测试5: 解锁组")
    let unlocked = manager.unlockGroup(groupID: group.groupID)
    guard unlocked, !manager.isGroupLocked(groupID: group.groupID) else {
        fatalError("❌ 测试5失败: 解锁失败")
    }
    print("✅ 测试5通过: 组解锁成功")
    
    print("\n🧪 测试6: 重命名")
    let renamed = manager.setGroupName(groupID: group.groupID, name: "新名称")
    guard renamed, manager.group(for: group.groupID)?.name == "新名称" else {
        fatalError("❌ 测试6失败: 重命名失败")
    }
    print("✅ 测试6通过: 重命名成功")
    
    print("\n🧪 测试7: 布局模式")
    let layoutCount = manager.applyLayout(groupID: group.groupID, mode: .horizontalTile)
    guard layoutCount >= 0 else {
        fatalError("❌ 测试7失败: 布局应用失败")
    }
    print("✅ 测试7通过: 布局应用成功")
    
    print("\n🧪 测试8: 悬浮模式")
    let floated = manager.setGroupFloating(groupID: group.groupID, floating: true)
    guard floated else {
        fatalError("❌ 测试8失败: 悬浮设置失败")
    }
    print("✅ 测试8通过: 悬浮模式成功")
    
    print("\n🧪 测试9: 透明度联动")
    let opacityCount = manager.setGroupOpacity(groupID: group.groupID, alpha: 0.5)
    guard opacityCount >= 0 else {
        fatalError("❌ 测试9失败: 透明度设置失败")
    }
    print("✅ 测试9通过: 透明度联动成功")
    
    print("\n🧪 测试10: 窗口离开组")
    let removed = manager.removeWindowFromGroup(windowID: testWindowID, groupID: group.groupID)
    guard removed, !manager.isWindowInGroup(testWindowID) else {
        fatalError("❌ 测试10失败: 离开组失败")
    }
    print("✅ 测试10通过: 窗口离开组成功")
    
    print("\n=== 全部窗口分组管理测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWindowGroup
public class UIWindowGroup: Codable , @unchecked Sendable{

    /// 组唯一标识
    public let groupID: String
    /// 组名称
    public var name: String
    /// 组标签颜色（NSColor的RGB值，编码为Data）
    public var tagColorData: Data?
    /// 组内窗口ID列表
    public var windowIDs: [String] = []
    /// 是否锁定组关系（防止意外解散）
    public var isLocked: Bool = false
    /// 是否悬浮模式（组内窗口一起置顶）
    public var isFloating: Bool = false
    /// 当前布局模式
    public var layoutMode: UIWindowGroupLayoutMode = .none
    /// 组内统一透明度值（0.0 ~ 1.0，nil表示不联动）
    public var unifiedOpacity: CGFloat? = nil
    /// 创建时间
    public let creationTime: Date
    /// 最后修改时间
    public var lastModifiedTime: Date

    /// 编码键
    enum UICodingKeys: String, CodingKey {
        case groupID, name, tagColorData, windowIDs, isLocked, isFloating
        case layoutMode, unifiedOpacity, creationTime, lastModifiedTime
    }

    public init(groupID: String, name: String, tagColor: NSColor? = nil) {
        self.groupID = groupID
        self.name = name
        self.creationTime = Date()
        self.lastModifiedTime = Date()
        if let color = tagColor {
            self.tagColorData = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
        }
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: UICodingKeys.self)
        groupID = try container.decode(String.self, forKey: .groupID)
        name = try container.decode(String.self, forKey: .name)
        tagColorData = try container.decodeIfPresent(Data.self, forKey: .tagColorData)
        windowIDs = try container.decode([String].self, forKey: .windowIDs)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        isFloating = try container.decode(Bool.self, forKey: .isFloating)
        layoutMode = try container.decode(UIWindowGroupLayoutMode.self, forKey: .layoutMode)
        if let opacity = try container.decodeIfPresent(CGFloat.self, forKey: .unifiedOpacity) {
            unifiedOpacity = opacity
        }
        creationTime = try container.decode(Date.self, forKey: .creationTime)
        lastModifiedTime = try container.decode(Date.self, forKey: .lastModifiedTime)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: UICodingKeys.self)
        try container.encode(groupID, forKey: .groupID)
        try container.encode(name, forKey: .name)
        try container.encode(tagColorData, forKey: .tagColorData)
        try container.encode(windowIDs, forKey: .windowIDs)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(isFloating, forKey: .isFloating)
        try container.encode(layoutMode, forKey: .layoutMode)
        try container.encode(unifiedOpacity, forKey: .unifiedOpacity)
        try container.encode(creationTime, forKey: .creationTime)
        try container.encode(lastModifiedTime, forKey: .lastModifiedTime)
    }

    // MARK: - 标签颜色

    /// 标签颜色（NSColor）
    public var tagColor: NSColor? {
        get {
            guard let data = tagColorData else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        }
        set {
            if let color = newValue {
                tagColorData = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
            } else {
                tagColorData = nil
            }
            touch()
        }
    }

    /// 更新最后修改时间
    private func touch() {
        lastModifiedTime = Date()
    }

    /// 添加窗口到组
    public func addWindow(_ windowID: String) {
        guard !windowIDs.contains(windowID) else { return }
        windowIDs.append(windowID)
        touch()
    }

    /// 从组移除窗口
    public func removeWindow(_ windowID: String) {
        windowIDs.removeAll { $0 == windowID }
        touch()
    }

    /// 检查窗口是否在组内
    public func containsWindow(_ windowID: String) -> Bool {
        return windowIDs.contains(windowID)
    }

    /// 窗口数量
    public var count: Int {
        return windowIDs.count
    }

    /// 是否为空组
    public var isEmpty: Bool {
        return windowIDs.isEmpty
    }
}

// MARK: - 迁回自 UI-02：class UIWindowGroupManager
public final class UIWindowGroupManager : @unchecked Sendable {


    public static let shared = UIWindowGroupManager()

    /// 日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu.group", category: "UIWindowGroupManager")

    /// 线程安全锁
    private let lock = NSRecursiveLock()

    /// 所有窗口组：组ID -> 组
    private var groups: [String: UIWindowGroup] = [:]

    /// 窗口到组的映射：窗口ID -> 组ID
    private var windowToGroup: [String: String] = [:]

    /// 热键绑定：热键标识符 -> 热键配置
    private var hotkeys: [String: UIWindowGroupHotkey] = [:]

    /// UserDefaults 持久化键
    private let saveKey = "com.xianrenzhilu.windowGroups"

    /// 布局偏移常量（层叠模式用）
    private let cascadeOffset: CGFloat = 30.0

    /// 窗口组移动时的相对偏移记录（窗口ID -> 原始位置）
    private var moveOriginalFrames: [String: NSRect] = [:]

    // MARK: - 生命周期

    private init() {
        loadGroups()
        logger.info("[窗口分组] UIWindowGroupManager 单例初始化完成")
    }

    // MARK: - 组创建与删除

    /// 创建新窗口组
    /// - Parameters:
    ///   - name: 组名称
    ///   - tagColor: 标签颜色（可选）
    ///   - windowIDs: 初始窗口ID列表（可选）
    /// - Returns: 创建的窗口组
    @discardableResult
    public func createGroup(name: String, tagColor: NSColor? = nil, windowIDs: [String] = []) -> UIWindowGroup {
        let groupID = UUID().uuidString
        let group = UIWindowGroup(groupID: groupID, name: name, tagColor: tagColor)

        lock.lock()
        groups[groupID] = group
        for windowID in windowIDs {
            group.addWindow(windowID)
            windowToGroup[windowID] = groupID
        }
        lock.unlock()

        logger.info("[窗口分组] 已创建组 '\(name)'（ID: \(groupID)），包含 \(windowIDs.count) 个窗口")

        // 发送通知
        NotificationCenter.default.post(
            name: .windowGroupDidCreate,
            object: self,
            userInfo: ["groupID": groupID, "name": name, "windowCount": windowIDs.count]
        )

        return group
    }

    /// 删除窗口组
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - force: 是否强制删除（忽略锁定）
    /// - Returns: 是否成功删除
    @discardableResult
    public func deleteGroup(groupID: String, force: Bool = false) -> Bool {
        lock.lock()
        guard let group = groups[groupID] else {
            lock.unlock()
            logger.warning("[窗口分组] 删除失败：组 '\(groupID)' 不存在")
            return false
        }

        if group.isLocked && !force {
            lock.unlock()
            logger.warning("[窗口分组] 删除失败：组 '\(group.name)' 已锁定，请先解锁")
            return false
        }

        // 清除窗口到组的映射
        for windowID in group.windowIDs {
            windowToGroup.removeValue(forKey: windowID)
        }
        groups.removeValue(forKey: groupID)
        lock.unlock()

        logger.info("[窗口分组] 已删除组 '\(group.name)'（ID: \(groupID)）")

        NotificationCenter.default.post(
            name: .windowGroupDidDelete,
            object: self,
            userInfo: ["groupID": groupID, "name": group.name]
        )

        return true
    }

    // MARK: - 窗口加入与离开

    /// 将窗口加入组
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - groupID: 目标组ID
    /// - Returns: 是否成功加入
    @discardableResult
    public func addWindowToGroup(windowID: String, groupID: String) -> Bool {
        lock.lock()
        guard let group = groups[groupID] else {
            lock.unlock()
            logger.warning("[窗口分组] 加入失败：组 '\(groupID)' 不存在")
            return false
        }

        if group.isLocked {
            lock.unlock()
            logger.warning("[窗口分组] 加入失败：组 '\(group.name)' 已锁定")
            return false
        }

        // 如果窗口已在其他组，先移除
        if let oldGroupID = windowToGroup[windowID], oldGroupID != groupID {
            groups[oldGroupID]?.removeWindow(windowID)
        }

        group.addWindow(windowID)
        windowToGroup[windowID] = groupID
        lock.unlock()

        logger.info("[窗口分组] 窗口 '\(windowID)' 已加入组 '\(group.name)'")

        NotificationCenter.default.post(
            name: .windowDidJoinGroup,
            object: self,
            userInfo: ["windowID": windowID, "groupID": groupID, "groupName": group.name]
        )

        return true
    }

    /// 将窗口从组中移除
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - groupID: 组ID（可选，nil时自动查找）
    /// - Returns: 是否成功移除
    @discardableResult
    public func removeWindowFromGroup(windowID: String, groupID: String? = nil) -> Bool {
        lock.lock()
        let targetGroupID = groupID ?? windowToGroup[windowID]
        guard let gid = targetGroupID, let group = groups[gid] else {
            lock.unlock()
            logger.warning("[窗口分组] 移除失败：窗口 '\(windowID)' 不在任何组中")
            return false
        }

        if group.isLocked {
            lock.unlock()
            logger.warning("[窗口分组] 移除失败：组 '\(group.name)' 已锁定")
            return false
        }

        group.removeWindow(windowID)
        windowToGroup.removeValue(forKey: windowID)
        lock.unlock()

        logger.info("[窗口分组] 窗口 '\(windowID)' 已从组 '\(group.name)' 移除")

        NotificationCenter.default.post(
            name: .windowDidLeaveGroup,
            object: self,
            userInfo: ["windowID": windowID, "groupID": gid, "groupName": group.name]
        )

        return true
    }

    /// 将窗口从当前组移到另一个组
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - targetGroupID: 目标组ID
    /// - Returns: 是否成功移动
    @discardableResult
    public func moveWindowToGroup(windowID: String, targetGroupID: String) -> Bool {
        guard let _ = group(for: targetGroupID) else {
            logger.warning("[窗口分组] 移动失败：目标组 '\(targetGroupID)' 不存在")
            return false
        }
        _ = removeWindowFromGroup(windowID: windowID)
        return addWindowToGroup(windowID: windowID, groupID: targetGroupID)
    }

    // MARK: - 查询

    /// 通过ID获取窗口组
    /// - Parameter groupID: 组ID
    /// - Returns: 窗口组，不存在时返回nil
    public func group(for groupID: String) -> UIWindowGroup? {
        lock.lock()
        let g = groups[groupID]
        lock.unlock()
        return g
    }

    /// 获取窗口所属的组
    /// - Parameter windowID: 窗口ID
    /// - Returns: 窗口组，未加入任何组时返回nil
    public func groupForWindow(_ windowID: String) -> UIWindowGroup? {
        lock.lock()
        guard let groupID = windowToGroup[windowID] else {
            lock.unlock()
            return nil
        }
        let g = groups[groupID]
        lock.unlock()
        return g
    }

    /// 获取窗口所属组的ID
    /// - Parameter windowID: 窗口ID
    /// - Returns: 组ID，未加入任何组时返回nil
    public func groupIDForWindow(_ windowID: String) -> String? {
        lock.lock()
        let gid = windowToGroup[windowID]
        lock.unlock()
        return gid
    }

    /// 检查窗口是否在组中
    /// - Parameter windowID: 窗口ID
    /// - Returns: 是否在组中
    public func isWindowInGroup(_ windowID: String) -> Bool {
        lock.lock()
        let inGroup = windowToGroup[windowID] != nil
        lock.unlock()
        return inGroup
    }

    /// 所有窗口组
    public var allGroups: [UIWindowGroup] {
        lock.lock()
        let result = Array(groups.values)
        lock.unlock()
        return result
    }

    /// 组数量
    public var groupCount: Int {
        lock.lock()
        let count = groups.count
        lock.unlock()
        return count
    }

    /// 获取指定组的所有窗口实例
    /// - Parameter groupID: 组ID
    /// - Returns: 窗口实例数组
    public func windowsInGroup(groupID: String) -> [NSWindow] {
        guard let group = group(for: groupID) else { return [] }
        return group.windowIDs.compactMap { UIWindowRegistry.shared.window(for: $0) }
    }

    // MARK: - 组锁管理

    /// 锁定组（防止解散和修改成员）
    /// - Parameter groupID: 组ID
    /// - Returns: 是否成功锁定
    @discardableResult
    public func lockGroup(groupID: String) -> Bool {
        lock.lock()
        guard let group = groups[groupID] else {
            lock.unlock()
            return false
        }
        group.isLocked = true
        lock.unlock()

        logger.info("[窗口分组] 组 '\(group.name)' 已锁定")

        NotificationCenter.default.post(
            name: .windowGroupDidLock,
            object: self,
            userInfo: ["groupID": groupID, "name": group.name]
        )

        return true
    }

    /// 解锁组
    /// - Parameter groupID: 组ID
    /// - Returns: 是否成功解锁
    @discardableResult
    public func unlockGroup(groupID: String) -> Bool {
        lock.lock()
        guard let group = groups[groupID] else {
            lock.unlock()
            return false
        }
        group.isLocked = false
        lock.unlock()

        logger.info("[窗口分组] 组 '\(group.name)' 已解锁")

        NotificationCenter.default.post(
            name: .windowGroupDidUnlock,
            object: self,
            userInfo: ["groupID": groupID, "name": group.name]
        )

        return true
    }

    /// 切换组锁定状态
    /// - Parameter groupID: 组ID
    /// - Returns: 新的锁定状态
    @discardableResult
    public func toggleLock(groupID: String) -> Bool {
        guard let group = group(for: groupID) else { return false }
        if group.isLocked {
            return unlockGroup(groupID: groupID)
        } else {
            return lockGroup(groupID: groupID)
        }
    }

    /// 检查组是否被锁定
    /// - Parameter groupID: 组ID
    /// - Returns: 是否锁定（不存在返回false）
    public func isGroupLocked(groupID: String) -> Bool {
        return group(for: groupID)?.isLocked ?? false
    }

    // MARK: - 组标签与命名

    /// 设置组名称
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - name: 新名称
    /// - Returns: 是否成功设置
    @discardableResult
    public func setGroupName(groupID: String, name: String) -> Bool {
        lock.lock()
        guard let group = groups[groupID] else {
            lock.unlock()
            return false
        }
        group.name = name
        lock.unlock()

        logger.info("[窗口分组] 组名称已设为 '\(name)'")
        return true
    }

    /// 设置组标签颜色
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - color: 标签颜色（nil表示清除）
    /// - Returns: 是否成功设置
    @discardableResult
    public func setGroupTagColor(groupID: String, color: NSColor?) -> Bool {
        lock.lock()
        guard let group = groups[groupID] else {
            lock.unlock()
            return false
        }
        group.tagColor = color
        lock.unlock()

        logger.info("[窗口分组] 组 '\(group.name)' 标签颜色已\(color != nil ? "设置" : "清除")")
        return true
    }

    /// 获取组标签颜色
    /// - Parameter groupID: 组ID
    /// - Returns: 标签颜色，不存在返回nil
    public func tagColorForGroup(groupID: String) -> NSColor? {
        return group(for: groupID)?.tagColor
    }

    // MARK: - 组操作（统一操作）

    /// 对组内所有窗口执行统一操作
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - operation: 操作类型
    ///   - parameter: 操作参数（移动用CGPoint偏移、缩放用CGSize等）
    /// - Returns: 成功操作的窗口数量
    @discardableResult
    public func performOperation(groupID: String, operation: UIWindowGroupOperation, parameter: Any? = nil) -> Int {
        guard let group = group(for: groupID) else {
            logger.warning("[窗口分组] 操作失败：组 '\(groupID)' 不存在")
            return 0
        }

        let windows = group.windowIDs.compactMap { UIWindowRegistry.shared.window(for: $0) }
        var successCount = 0

        switch operation {
        case .move:
            if let offset = parameter as? NSPoint {
                successCount = moveWindows(windows: windows, offset: offset)
            }
        case .resize:
            if let size = parameter as? NSSize {
                successCount = resizeWindows(windows: windows, size: size)
            }
        case .minimize:
            for window in windows {
                window.miniaturize(nil as AnyObject?)
                successCount += 1
            }
        case .close:
            for window in windows {
                window.close()
                successCount += 1
            }
            // 关闭后从组中移除
            for windowID in group.windowIDs {
                _ = removeWindowFromGroup(windowID: windowID, groupID: groupID)
            }
        case .bringFront:
            for window in windows {
                window.makeKeyAndOrderFront(nil as AnyObject?)
                successCount += 1
            }
        case .sendBack:
            for window in windows {
                window.orderBack(nil as AnyObject?)
                successCount += 1
            }
        case .maximize:
            for window in windows {
                if let screen = window.screen {
                    window.setFrame(screen.visibleFrame, display: true, animate: true)
                    successCount += 1
                }
            }
        case .restore:
            for window in windows {
                window.zoom(nil as AnyObject?)
                successCount += 1
            }
        case .hide:
            for window in windows {
                window.orderOut(nil as AnyObject?)
                successCount += 1
            }
        case .show:
            for window in windows {
                window.makeKeyAndOrderFront(nil as AnyObject?)
                successCount += 1
            }
        case .float:
            for window in windows {
                window.level = NSWindow.Level.floating
                successCount += 1
            }
            setGroupFloating(groupID: groupID, floating: true)
        case .unfloat:
            for window in windows {
                window.level = NSWindow.Level.normal
                successCount += 1
            }
            setGroupFloating(groupID: groupID, floating: false)
        }

        logger.info("[窗口分组] 组 '\(group.name)' 执行 '\(operation.displayName)'，成功 \(successCount)/\(windows.count) 个窗口")

        NotificationCenter.default.post(
            name: .windowGroupDidPerformOperation,
            object: self,
            userInfo: [
                "groupID": groupID,
                "operation": operation.rawValue,
                "successCount": successCount,
                "totalCount": windows.count
            ]
        )

        return successCount
    }

    /// 统一移动组内窗口
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - offsetX: X方向偏移
    ///   - offsetY: Y方向偏移
    /// - Returns: 成功移动的窗口数量
    @discardableResult
    public func moveGroup(groupID: String, offsetX: CGFloat, offsetY: CGFloat) -> Int {
        let offset = NSPoint(x: offsetX, y: offsetY)
        return performOperation(groupID: groupID, operation: .move, parameter: offset)
    }

    /// 统一缩放组内窗口
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - widthDelta: 宽度变化
    ///   - heightDelta: 高度变化
    /// - Returns: 成功缩放的窗口数量
    @discardableResult
    public func resizeGroup(groupID: String, widthDelta: CGFloat, heightDelta: CGFloat) -> Int {
        let size = NSSize(width: widthDelta, height: heightDelta)
        return performOperation(groupID: groupID, operation: .resize, parameter: size)
    }

    /// 统一最小化组内窗口
    /// - Parameter groupID: 组ID
    /// - Returns: 成功最小化的窗口数量
    @discardableResult
    public func minimizeGroup(groupID: String) -> Int {
        return performOperation(groupID: groupID, operation: .minimize)
    }

    /// 统一关闭组内窗口
    /// - Parameter groupID: 组ID
    /// - Returns: 成功关闭的窗口数量
    @discardableResult
    public func closeGroup(groupID: String) -> Int {
        return performOperation(groupID: groupID, operation: .close)
    }

    /// 统一置顶组内窗口
    /// - Parameter groupID: 组ID
    /// - Returns: 成功置顶的窗口数量
    @discardableResult
    public func bringGroupToFront(groupID: String) -> Int {
        return performOperation(groupID: groupID, operation: .bringFront)
    }

    /// 统一置底组内窗口
    /// - Parameter groupID: 组ID
    /// - Returns: 成功置底的窗口数量
    @discardableResult
    public func sendGroupToBack(groupID: String) -> Int {
        return performOperation(groupID: groupID, operation: .sendBack)
    }

    /// 统一隐藏组内窗口
    /// - Parameter groupID: 组ID
    /// - Returns: 成功隐藏的窗口数量
    @discardableResult
    public func hideGroup(groupID: String) -> Int {
        return performOperation(groupID: groupID, operation: .hide)
    }

    /// 统一显示组内窗口
    /// - Parameter groupID: 组ID
    /// - Returns: 成功显示的窗口数量
    @discardableResult
    public func showGroup(groupID: String) -> Int {
        return performOperation(groupID: groupID, operation: .show)
    }

    // MARK: - 内部移动/缩放实现

    private func moveWindows(windows: [NSWindow], offset: NSPoint) -> Int {
        var count = 0
        for window in windows {
            var frame = window.frame
            frame.origin.x += offset.x
            frame.origin.y += offset.y
            window.setFrame(frame, display: true, animate: true)
            count += 1
        }
        return count
    }

    private func resizeWindows(windows: [NSWindow], size: NSSize) -> Int {
        var count = 0
        for window in windows {
            var frame = window.frame
            frame.size.width += size.width
            frame.size.height += size.height
            frame.size.width = max(100, frame.size.width)
            frame.size.height = max(100, frame.size.height)
            window.setFrame(frame, display: true, animate: true)
            count += 1
        }
        return count
    }

    // MARK: - 组排列布局

    /// 应用布局模式到组内窗口
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - mode: 布局模式
    /// - Returns: 成功排列的窗口数量
    @discardableResult
    public func applyLayout(groupID: String, mode: UIWindowGroupLayoutMode) -> Int {
        guard let group = group(for: groupID) else { return 0 }
        let windows = group.windowIDs.compactMap { UIWindowRegistry.shared.window(for: $0) }
        guard !windows.isEmpty else { return 0 }

        // 保存当前布局模式
        lock.lock()
        group.layoutMode = mode
        lock.unlock()

        var successCount = 0

        switch mode {
        case .none:
            successCount = windows.count  // 自由排列，不做任何操作
        case .horizontalTile:
            successCount = applyHorizontalTile(windows: windows)
        case .verticalTile:
            successCount = applyVerticalTile(windows: windows)
        case .gridTile:
            successCount = applyGridTile(windows: windows)
        case .cascade:
            successCount = applyCascade(windows: windows)
        case .stack:
            successCount = applyStack(windows: windows)
        case .center:
            successCount = applyCenter(windows: windows)
        }

        logger.info("[窗口分组] 组 '\(group.name)' 应用布局 '\(mode.displayName)'，成功 \(successCount) 个窗口")

        NotificationCenter.default.post(
            name: .windowGroupLayoutDidChange,
            object: self,
            userInfo: ["groupID": groupID, "layoutMode": mode.rawValue, "successCount": successCount]
        )

        return successCount
    }

    /// 获取当前布局模式
    /// - Parameter groupID: 组ID
    /// - Returns: 布局模式
    public func currentLayoutMode(for groupID: String) -> UIWindowGroupLayoutMode {
        return group(for: groupID)?.layoutMode ?? .none
    }

    /// 水平平铺布局
    private func applyHorizontalTile(windows: [NSWindow]) -> Int {
        guard let screen = windows.first?.screen else { return 0 }
        let visibleFrame = screen.visibleFrame
        let count = CGFloat(windows.count)
        let width = visibleFrame.width / count
        var x = visibleFrame.origin.x

        for window in windows {
            var frame = window.frame
            frame.origin.x = x
            frame.origin.y = visibleFrame.origin.y
            frame.size.width = width
            frame.size.height = visibleFrame.height
            window.setFrame(frame, display: true, animate: true)
            x += width
        }
        return windows.count
    }

    /// 垂直平铺布局
    private func applyVerticalTile(windows: [NSWindow]) -> Int {
        guard let screen = windows.first?.screen else { return 0 }
        let visibleFrame = screen.visibleFrame
        let count = CGFloat(windows.count)
        let height = visibleFrame.height / count
        var y = visibleFrame.origin.y + visibleFrame.height - height

        for window in windows {
            var frame = window.frame
            frame.origin.x = visibleFrame.origin.x
            frame.origin.y = y
            frame.size.width = visibleFrame.width
            frame.size.height = height
            window.setFrame(frame, display: true, animate: true)
            y -= height
        }
        return windows.count
    }

    /// 网格平铺布局
    private func applyGridTile(windows: [NSWindow]) -> Int {
        guard let screen = windows.first?.screen else { return 0 }
        let visibleFrame = screen.visibleFrame
        let count = windows.count
        let cols = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))
        let width = visibleFrame.width / CGFloat(cols)
        let height = visibleFrame.height / CGFloat(rows)

        for (index, window) in windows.enumerated() {
            let col = index % cols
            let row = index / cols
            var frame = window.frame
            frame.origin.x = visibleFrame.origin.x + CGFloat(col) * width
            frame.origin.y = visibleFrame.origin.y + visibleFrame.height - CGFloat(row + 1) * height
            frame.size.width = width
            frame.size.height = height
            window.setFrame(frame, display: true, animate: true)
        }
        return windows.count
    }

    /// 层叠布局
    private func applyCascade(windows: [NSWindow]) -> Int {
        guard let screen = windows.first?.screen else { return 0 }
        let visibleFrame = screen.visibleFrame
        var x = visibleFrame.origin.x + 50
        var y = visibleFrame.origin.y + visibleFrame.height - 50

        for window in windows {
            var frame = window.frame
            frame.origin.x = x
            frame.origin.y = y - frame.size.height
            window.setFrame(frame, display: true, animate: true)
            x += cascadeOffset
            y -= cascadeOffset
        }
        return windows.count
    }

    /// 堆栈布局（只显示第一个，其他重叠在后面）
    private func applyStack(windows: [NSWindow]) -> Int {
        guard let firstWindow = windows.first else { return 0 }
        let baseFrame = firstWindow.frame

        for (index, window) in windows.enumerated() {
            var frame = baseFrame
            // 轻微偏移以便区分
            frame.origin.x += CGFloat(index) * 2
            frame.origin.y -= CGFloat(index) * 2
            window.setFrame(frame, display: true, animate: true)
        }
        // 将第一个窗口置顶
        firstWindow.makeKeyAndOrderFront(nil)
        return windows.count
    }

    /// 居中排列（所有窗口中心点对齐）
    private func applyCenter(windows: [NSWindow]) -> Int {
        guard let screen = windows.first?.screen else { return 0 }
        let centerX = screen.visibleFrame.midX
        let centerY = screen.visibleFrame.midY

        for window in windows {
            var frame = window.frame
            frame.origin.x = centerX - frame.size.width / 2
            frame.origin.y = centerY - frame.size.height / 2
            window.setFrame(frame, display: true, animate: true)
        }
        return windows.count
    }

    // MARK: - 组悬浮模式

    /// 设置组悬浮状态
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - floating: 是否悬浮
    /// - Returns: 是否成功设置
    @discardableResult
    public func setGroupFloating(groupID: String, floating: Bool) -> Bool {
        guard let group = group(for: groupID) else { return false }
        let windows = group.windowIDs.compactMap { UIWindowRegistry.shared.window(for: $0) }

        lock.lock()
        group.isFloating = floating
        lock.unlock()

        for window in windows {
            window.level = floating ? NSWindow.Level.floating : NSWindow.Level.normal
        }

        logger.info("[窗口分组] 组 '\(group.name)' 悬浮模式已\(floating ? "启用" : "禁用")")

        NotificationCenter.default.post(
            name: .windowGroupFloatDidChange,
            object: self,
            userInfo: ["groupID": groupID, "isFloating": floating]
        )

        return true
    }

    /// 切换组悬浮状态
    /// - Parameter groupID: 组ID
    /// - Returns: 新的悬浮状态
    @discardableResult
    public func toggleGroupFloating(groupID: String) -> Bool {
        let current = group(for: groupID)?.isFloating ?? false
        setGroupFloating(groupID: groupID, floating: !current)
        return !current
    }

    /// 检查组是否处于悬浮模式
    /// - Parameter groupID: 组ID
    /// - Returns: 是否悬浮
    public func isGroupFloating(groupID: String) -> Bool {
        return group(for: groupID)?.isFloating ?? false
    }

    // MARK: - 组透明度联动

    /// 设置组内窗口统一透明度
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - alpha: 透明度值（0.0 ~ 1.0），nil表示取消联动
    /// - Returns: 成功设置的窗口数量
    @discardableResult
    public func setGroupOpacity(groupID: String, alpha: CGFloat?) -> Int {
        guard let group = group(for: groupID) else { return 0 }
        let windows = group.windowIDs.compactMap { UIWindowRegistry.shared.window(for: $0) }

        lock.lock()
        group.unifiedOpacity = alpha
        lock.unlock()

        var count = 0
        for window in windows {
            if let alphaValue = alpha {
                let clampedAlpha = min(1.0, max(0.0, alphaValue))
                window.alphaValue = clampedAlpha
                window.isOpaque = (clampedAlpha >= 1.0)
            } else {
                // 取消联动，恢复不透明
                window.alphaValue = 1.0
                window.isOpaque = true
            }
            count += 1
        }

        logger.info("[窗口分组] 组 '\(group.name)' 透明度联动已\(alpha != nil ? "设为 \(alpha!)" : "取消")，影响 \(count) 个窗口")

        NotificationCenter.default.post(
            name: .windowGroupOpacityDidChange,
            object: self,
            userInfo: [
                "groupID": groupID,
                "opacity": alpha ?? -1.0,
                "windowCount": count
            ]
        )

        return count
    }

    /// 调整组内窗口透明度
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - delta: 变化量（正值增加，负值减少）
    /// - Returns: 成功调整的窗口数量
    @discardableResult
    public func adjustGroupOpacity(groupID: String, delta: CGFloat) -> Int {
        guard let group = group(for: groupID) else { return 0 }
        let currentAlpha = group.unifiedOpacity ?? 1.0
        let newAlpha = min(1.0, max(0.0, currentAlpha + delta))
        return setGroupOpacity(groupID: groupID, alpha: newAlpha)
    }

    /// 获取组当前统一透明度
    /// - Parameter groupID: 组ID
    /// - Returns: 统一透明度值，nil表示未设置
    public func groupOpacity(groupID: String) -> CGFloat? {
        return group(for: groupID)?.unifiedOpacity
    }

    // MARK: - 组热键

    /// 为组绑定热键
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - keyEquivalent: 按键字符
    ///   - modifierFlags: 修饰键
    /// - Returns: 热键配置，冲突时返回nil
    public func bindHotkey(groupID: String, keyEquivalent: String, modifierFlags: NSEvent.ModifierFlags = [.command, .shift]) -> UIWindowGroupHotkey? {
        guard group(for: groupID) != nil else { return nil }

        // 冲突检测
        lock.lock()
        for (_, existing) in hotkeys {
            if existing.keyEquivalent == keyEquivalent && existing.modifierFlags == modifierFlags.rawValue {
                lock.unlock()
                logger.warning("[窗口分组] 热键绑定冲突：\(existing.displayString) 已被组 '\(existing.groupID)' 使用")
                return nil
            }
        }

        let identifier = "group.hotkey.\(groupID)"
        let hotkey = UIWindowGroupHotkey(
            identifier: identifier,
            groupID: groupID,
            keyEquivalent: keyEquivalent,
            modifierFlags: modifierFlags
        )
        hotkeys[identifier] = hotkey
        lock.unlock()

        logger.info("[窗口分组] 已为组绑定热键 \(hotkey.displayString)")
        return hotkey
    }

    /// 解绑组热键
    /// - Parameter groupID: 组ID
    public func unbindHotkey(groupID: String) {
        let identifier = "group.hotkey.\(groupID)"
        lock.lock()
        hotkeys.removeValue(forKey: identifier)
        lock.unlock()
        logger.info("[窗口分组] 已解绑组 '\(groupID)' 的热键")
    }

    /// 通过热键激活组（显示所有窗口并置顶）
    /// - Parameter identifier: 热键标识符
    /// - Returns: 是否成功激活
    @discardableResult
    public func activateGroupByHotkey(identifier: String) -> Bool {
        lock.lock()
        guard let hotkey = hotkeys[identifier], hotkey.isEnabled else {
            lock.unlock()
            return false
        }
        let groupID = hotkey.groupID
        lock.unlock()

        guard let group = group(for: groupID) else { return false }
        let count = showGroup(groupID: groupID)
        _ = bringGroupToFront(groupID: groupID)

        logger.info("[窗口分组] 热键激活组 '\(group.name)'，显示 \(count) 个窗口")

        NotificationCenter.default.post(
            name: .windowGroupDidActivate,
            object: self,
            userInfo: ["groupID": groupID, "hotkeyIdentifier": identifier, "windowCount": count]
        )

        return count > 0
    }

    /// 获取组的热键配置
    /// - Parameter groupID: 组ID
    /// - Returns: 热键配置，未绑定返回nil
    public func hotkeyForGroup(groupID: String) -> UIWindowGroupHotkey? {
        let identifier = "group.hotkey.\(groupID)"
        lock.lock()
        let hk = hotkeys[identifier]
        lock.unlock()
        return hk
    }

    /// 所有热键绑定
    public var allHotkeys: [UIWindowGroupHotkey] {
        lock.lock()
        let result = Array(hotkeys.values)
        lock.unlock()
        return result
    }

    /// 启用/禁用热键
    /// - Parameters:
    ///   - identifier: 热键标识符
    ///   - enabled: 是否启用
    /// - Returns: 是否成功
    @discardableResult
    public func setHotkeyEnabled(identifier: String, enabled: Bool) -> Bool {
        lock.lock()
        guard var hotkey = hotkeys[identifier] else {
            lock.unlock()
            return false
        }
        hotkey.isEnabled = enabled
        hotkeys[identifier] = hotkey
        lock.unlock()
        return true
    }

    // MARK: - 保存与加载

    /// 保存所有窗口组配置到 UserDefaults
    /// - Returns: 是否成功保存
    @discardableResult
    public func saveGroups() -> Bool {
        lock.lock()
        let saveData = UIWindowGroupSaveData(groups: Array(groups.values), hotkeys: Array(hotkeys.values))
        lock.unlock()

        do {
            let data = try JSONEncoder().encode(saveData)
            UserDefaults.standard.set(data, forKey: saveKey)

            logger.info("[窗口分组] 已保存 \(saveData.groups.count) 个组和 \(saveData.hotkeys.count) 个热键")

            NotificationCenter.default.post(
                name: .windowGroupDidSave,
                object: self,
                userInfo: ["groupCount": saveData.groups.count, "hotkeyCount": saveData.hotkeys.count]
            )

            return true
        } catch {
            logger.error("[窗口分组] 保存失败：\(error.localizedDescription)")
            return false
        }
    }

    /// 从 UserDefaults 加载窗口组配置
    /// - Returns: 是否成功加载
    @discardableResult
    public func loadGroups() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else {
            logger.info("[窗口分组] 没有找到已保存的组配置")
            return false
        }

        do {
            let saveData = try JSONDecoder().decode(UIWindowGroupSaveData.self, from: data)

            lock.lock()
            groups.removeAll()
            windowToGroup.removeAll()
            hotkeys.removeAll()

            for group in saveData.groups {
                groups[group.groupID] = group
                for windowID in group.windowIDs {
                    windowToGroup[windowID] = group.groupID
                }
            }

            for hotkey in saveData.hotkeys {
                hotkeys[hotkey.identifier] = hotkey
            }
            lock.unlock()

            logger.info("[窗口分组] 已加载 \(saveData.groups.count) 个组和 \(saveData.hotkeys.count) 个热键")

            NotificationCenter.default.post(
                name: .windowGroupDidLoad,
                object: self,
                userInfo: ["groupCount": saveData.groups.count, "hotkeyCount": saveData.hotkeys.count]
            )

            return true
        } catch {
            logger.error("[窗口分组] 加载失败：\(error.localizedDescription)")
            return false
        }
    }

    /// 导出组配置到文件
    /// - Parameter url: 文件URL
    /// - Returns: 是否成功导出
    @discardableResult
    public func exportToFile(url: URL) -> Bool {
        lock.lock()
        let saveData = UIWindowGroupSaveData(groups: Array(groups.values), hotkeys: Array(hotkeys.values))
        lock.unlock()

        do {
            let data = try JSONEncoder().encode(saveData)
            try data.write(to: url)
            logger.info("[窗口分组] 已导出到 \(url.path)")
            return true
        } catch {
            logger.error("[窗口分组] 导出失败：\(error.localizedDescription)")
            return false
        }
    }

    /// 从文件导入组配置
    /// - Parameter url: 文件URL
    /// - Returns: 是否成功导入
    @discardableResult
    public func importFromFile(url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let saveData = try JSONDecoder().decode(UIWindowGroupSaveData.self, from: data)

            lock.lock()
            for group in saveData.groups {
                groups[group.groupID] = group
                for windowID in group.windowIDs {
                    windowToGroup[windowID] = group.groupID
                }
            }
            for hotkey in saveData.hotkeys {
                hotkeys[hotkey.identifier] = hotkey
            }
            lock.unlock()

            logger.info("[窗口分组] 已从 \(url.path) 导入 \(saveData.groups.count) 个组")
            return true
        } catch {
            logger.error("[窗口分组] 导入失败：\(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 设置面板方法

    /// 创建新组的设置面板方法
    /// - Parameters:
    ///   - name: 组名称
    ///   - tagColor: 标签颜色
    ///   - windowIDs: 窗口ID列表
    /// - Returns: 创建的组
    public func createGroupSetting(name: String, tagColor: NSColor? = nil, windowIDs: [String] = []) -> UIWindowGroup {
        return createGroup(name: name, tagColor: tagColor, windowIDs: windowIDs)
    }

    /// 删除组的设置面板方法
    /// - Parameter groupID: 组ID
    public func deleteGroupSetting(groupID: String) {
        _ = deleteGroup(groupID: groupID, force: false)
    }

    /// 重命名组的设置面板方法
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - name: 新名称
    public func renameGroupSetting(groupID: String, name: String) {
        _ = setGroupName(groupID: groupID, name: name)
    }

    /// 设置标签颜色的设置面板方法
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - color: 标签颜色
    public func setTagColorSetting(groupID: String, color: NSColor) {
        _ = setGroupTagColor(groupID: groupID, color: color)
    }

    /// 锁定/解锁组的设置面板方法
    /// - Parameter groupID: 组ID
    public func toggleLockSetting(groupID: String) {
        _ = toggleLock(groupID: groupID)
    }

    /// 悬浮模式设置面板方法
    /// - Parameter groupID: 组ID
    public func toggleFloatSetting(groupID: String) {
        _ = toggleGroupFloating(groupID: groupID)
    }

    /// 布局模式设置面板方法
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - mode: 布局模式
    public func applyLayoutSetting(groupID: String, mode: UIWindowGroupLayoutMode) {
        _ = applyLayout(groupID: groupID, mode: mode)
    }

    /// 透明度联动设置面板方法
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - alpha: 透明度值（0.0 ~ 1.0）
    public func setOpacitySetting(groupID: String, alpha: CGFloat) {
        _ = setGroupOpacity(groupID: groupID, alpha: alpha)
    }

    /// 热键绑定设置面板方法
    /// - Parameters:
    ///   - groupID: 组ID
    ///   - keyEquivalent: 按键字符
    ///   - modifierFlags: 修饰键
    /// - Returns: 热键配置
    public func bindHotkeySetting(groupID: String, keyEquivalent: String, modifierFlags: NSEvent.ModifierFlags) -> UIWindowGroupHotkey? {
        return bindHotkey(groupID: groupID, keyEquivalent: keyEquivalent, modifierFlags: modifierFlags)
    }

    /// 保存配置设置面板方法
    public func saveSetting() {
        _ = saveGroups()
    }

    /// 加载配置设置面板方法
    public func loadSetting() {
        _ = loadGroups()
    }

    /// 导出配置设置面板方法
    /// - Parameter url: 文件URL
    public func exportSetting(url: URL) {
        _ = exportToFile(url: url)
    }

    /// 导入配置设置面板方法
    /// - Parameter url: 文件URL
    public func importSetting(url: URL) {
        _ = importFromFile(url: url)
    }

    // MARK: - 统计与信息

    /// 获取所有组的状态描述
    public var statusDescription: String {
        lock.lock()
        var lines: [String] = []
        lines.append("窗口分组总数：\(groups.count)")
        lines.append("热键绑定数：\(hotkeys.count)")
        lines.append("")

        for (_, group) in groups.sorted(by: { $0.value.creationTime < $1.value.creationTime }) {
            let lockStatus = group.isLocked ? "🔒" : ""
            let floatStatus = group.isFloating ? "📌" : ""
            let opacityStr = group.unifiedOpacity != nil ? String(format: "透明度%.2f", group.unifiedOpacity!) : ""
            lines.append("[\(group.groupID.prefix(8))] \(group.name) \(lockStatus)\(floatStatus) - \(group.count)个窗口 \(group.layoutMode.displayName) \(opacityStr)")
        }
        lock.unlock()

        return lines.joined(separator: "\n")
    }

    /// 获取指定组的详细描述
    /// - Parameter groupID: 组ID
    /// - Returns: 描述字符串
    public func descriptionForGroup(groupID: String) -> String {
        guard let group = group(for: groupID) else { return "组不存在" }

        var lines: [String] = []
        lines.append("=== 组详情 ===")
        lines.append("ID: \(group.groupID)")
        lines.append("名称: \(group.name)")
        lines.append("窗口数: \(group.count)")
        lines.append("锁定: \(group.isLocked ? "是" : "否")")
        lines.append("悬浮: \(group.isFloating ? "是" : "否")")
        lines.append("布局: \(group.layoutMode.displayName)")
        lines.append("透明度联动: \(group.unifiedOpacity != nil ? String(format: "%.2f", group.unifiedOpacity!) : "未设置")")
        lines.append("创建时间: \(group.creationTime)")
        lines.append("最后修改: \(group.lastModifiedTime)")
        lines.append("窗口列表:")
        for windowID in group.windowIDs {
            if let record = UIWindowRegistry.shared.record(for: windowID) {
                let title = record.window.title
                lines.append("  - \(windowID): \(title)")
            } else {
                lines.append("  - \(windowID): [未注册]")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 清理与维护

    /// 清理无效窗口引用（窗口已关闭或注销）
    /// - Returns: 清理的窗口数量
    @discardableResult
    public func purgeInvalidWindows() -> Int {
        lock.lock()
        var removedCount = 0
        for (_, group) in groups {
            let validIDs = group.windowIDs.filter { windowID in
                return UIWindowRegistry.shared.isRegistered(windowID)
            }
            removedCount += group.windowIDs.count - validIDs.count
            group.windowIDs = validIDs
            for windowID in group.windowIDs {
                windowToGroup[windowID] = group.groupID
            }
        }
        lock.unlock()

        if removedCount > 0 {
            logger.info("[窗口分组] 已清理 \(removedCount) 个无效窗口引用")
        }
        return removedCount
    }

    /// 删除空组（不包含任何窗口的组）
    /// - Returns: 删除的组数量
    @discardableResult
    public func purgeEmptyGroups() -> Int {
        var removedCount = 0
        lock.lock()
        let emptyGroupIDs = groups.compactMap { (id, group) -> String? in
            return group.isEmpty ? id : nil
        }
        lock.unlock()

        for groupID in emptyGroupIDs {
            if deleteGroup(groupID: groupID, force: true) {
                removedCount += 1
            }
        }

        if removedCount > 0 {
            logger.info("[窗口分组] 已删除 \(removedCount) 个空组")
        }
        return removedCount
    }

    /// 重置所有组（删除所有组，清空配置）
    public func resetAll() {
        lock.lock()
        let allIDs = Array(groups.keys)
        lock.unlock()

        for groupID in allIDs {
            _ = deleteGroup(groupID: groupID, force: true)
        }

        hotkeys.removeAll()
        UserDefaults.standard.removeObject(forKey: saveKey)

        logger.info("[窗口分组] 已重置所有组配置")
    }

    deinit {
        logger.info("UIWindowGroupManager 已释放")
    }
}

// MARK: - 迁回自 UI-02：enum UIWindowGroupLayoutMode
// MARK: - 通信管理器
/// 模块间通信管理器，封装UIGlobalEventBus提供请求-响应模式
// 已迁回 UI-GL-25_模块间通信协议.swift：class UICommunicationManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-27 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-27_types.swift
// 版本: 2.0
// MARK: - 组排列布局模式
/// 组内窗口自动排列的预设布局模式
public enum UIWindowGroupLayoutMode: Int, Codable, CaseIterable {
    /// 无布局（自由排列）
    case none = 0
    /// 水平平铺（窗口并排）
    case horizontalTile = 1
    /// 垂直平铺（窗口上下排列）
    case verticalTile = 2
    /// 网格平铺（自动计算行列）
    case gridTile = 3
    /// 层叠（窗口重叠，有偏移）
    case cascade = 4
    /// 堆栈（窗口堆叠，仅显示一个）
    case stack = 5
    /// 居中排列（所有窗口中心对齐）
    case center = 6

    /// 显示名称
    public var displayName: String {
        switch self {
        case .none:           return "自由排列"
        case .horizontalTile: return "水平平铺"
        case .verticalTile:   return "垂直平铺"
        case .gridTile:       return "网格平铺"
        case .cascade:        return "层叠"
        case .stack:          return "堆栈"
        case .center:         return "居中排列"
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIWindowGroupOperation
// MARK: - 窗口组操作类型
/// 组内统一操作类型
public enum UIWindowGroupOperation: String, Codable {
    case move       = "move"
    case resize     = "resize"
    case minimize   = "minimize"
    case close      = "close"
    case bringFront = "bringFront"
    case sendBack   = "sendBack"
    case maximize   = "maximize"
    case restore    = "restore"
    case hide       = "hide"
    case show       = "show"
    case float      = "float"
    case unfloat    = "unfloat"

    /// 显示名称
    public var displayName: String {
        switch self {
        case .move:       return "统一移动"
        case .resize:     return "统一缩放"
        case .minimize:   return "统一最小化"
        case .close:      return "统一关闭"
        case .bringFront: return "统一置顶"
        case .sendBack:   return "统一置底"
        case .maximize:   return "统一最大化"
        case .restore:    return "统一恢复"
        case .hide:       return "统一隐藏"
        case .show:       return "统一显示"
        case .float:      return "统一悬浮"
        case .unfloat:    return "统一取消悬浮"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIWindowGroupHotkey
// MARK: - 窗口组热键配置
/// 窗口组热键绑定配置
public struct UIWindowGroupHotkey: Codable, Equatable {
    /// 热键标识符
    public let identifier: String
    /// 关联的组ID
    public let groupID: String
    /// 按键字符
    public var keyEquivalent: String
    /// 修饰键掩码（NSEvent.ModifierFlags.rawValue）
    public var modifierFlags: UInt
    /// 是否启用
    public var isEnabled: Bool
    /// 创建时间
    public let creationTime: Date

    public init(identifier: String, groupID: String, keyEquivalent: String,
                modifierFlags: NSEvent.ModifierFlags = [.command, .shift], isEnabled: Bool = true) {
        self.identifier = identifier
        self.groupID = groupID
        self.keyEquivalent = keyEquivalent
        self.modifierFlags = modifierFlags.rawValue
        self.isEnabled = isEnabled
        self.creationTime = Date()
    }

    /// 快捷键显示字符串
    public var displayString: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var parts: [String] = []
        if flags.contains(.command)  { parts.append("⌘") }
        if flags.contains(.shift)    { parts.append("⇧") }
        if flags.contains(.option)   { parts.append("⌥") }
        if flags.contains(.control)  { parts.append("⌃") }
        if !keyEquivalent.isEmpty {
            parts.append(keyEquivalent.uppercased())
        }
        return parts.joined(separator: "+")
    }
}

// MARK: - 迁回自 UI-02：enum UICodingKeys
// MARK: - 窗口组数据模型
/// 单个窗口组的数据模型
// 已迁回 UI-GL-27_窗口分组管理.swift：class UIWindowGroup（公共类型文件禁止功能实现）

enum UICodingKeys: String, CodingKey {
        case groupID, name, tagColorData, windowIDs, isLocked, isFloating
        case layoutMode, unifiedOpacity, creationTime, lastModifiedTime
    }

// MARK: - 迁回自 UI-02：struct UIWindowGroupSaveData
// MARK: - 窗口组保存数据
/// 用于持久化的窗口组配置数据
public struct UIWindowGroupSaveData: Codable {
    /// 所有窗口组
    public var groups: [UIWindowGroup]
    /// 热键绑定
    public var hotkeys: [UIWindowGroupHotkey]
    /// 保存时间
    public var saveTime: Date

    public init(groups: [UIWindowGroup], hotkeys: [UIWindowGroupHotkey]) {
        self.groups = groups
        self.hotkeys = hotkeys
        self.saveTime = Date()
    }
}
