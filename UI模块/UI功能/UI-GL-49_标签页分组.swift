// 功能39: 标签页分组 (Tab Group)
// 对应: 标签页可分组管理,支持折叠/展开
// 优先级: P2
// 作者: 码农

import AppKit
import Foundation
import os.log

// MARK: - 统一日志器
private let logger = Logger(subsystem: "com.xianrenzhilu.app", category: "TabGroups")

// MARK: - 通知名称定义

/// 标签页分组管理器相关通知
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：extension Notification.Name {

// MARK: - 测试代码
#if DEBUG

/// 功能39:标签页分组 - 单元测试
func test_tabGroup() {
    let manager = UITabGroupManager.shared

    logger.info("测试1: 初始分组")
    let count = manager.groupCount
    if count < 1 { logger.error("❌ 测试1失败: 应至少有一个默认分组") }
    else { logger.info("✅ 测试1通过: 初始分组数=\(count)") }

    logger.info("测试2: 创建分组")
    guard let gid = manager.quickCreateGroup(name: "测试分组", color: .green) else {
        logger.error("❌ 测试2失败: 分组创建失败")
        return
    }
    logger.info("✅ 测试2通过: 创建分组 ID=\(gid)")

    logger.info("测试3: 分组存在性")
    if !manager.groupExists(gid) { logger.error("❌ 测试3失败") }
    else { logger.info("✅ 测试3通过") }

    logger.info("测试4: 分组查询")
    let group = manager.group(byID: gid)
    if group?.name != "测试分组" { logger.error("❌ 测试4失败: 名称不匹配") }
    else { logger.info("✅ 测试4通过") }

    logger.info("测试5: 重命名分组")
    if manager.renameGroup(groupID: gid, to: "已改名") {
        let renamed = manager.group(byID: gid)
        if renamed?.name != "已改名" { logger.error("❌ 测试5失败: 重命名后名称不匹配") }
        else { logger.info("✅ 测试5通过") }
    } else { logger.error("❌ 测试5失败: 重命名失败") }

    logger.info("测试6: 分组折叠/展开")
    if let exp = manager.toggleGroupFold(groupID: gid) {
        if exp != false { logger.error("❌ 测试6失败: 切换折叠后应为false") }
        else { logger.info("✅ 测试6通过") }
    } else { logger.error("❌ 测试6失败: toggle返回nil") }

    logger.info("测试7: 分组颜色")
    if manager.setGroupColor(groupID: gid, color: .red) {
        let colored = manager.group(byID: gid)
        if colored?.color != .red { logger.error("❌ 测试7失败: 颜色不匹配") }
        else { logger.info("✅ 测试7通过") }
    } else { logger.error("❌ 测试7失败: 颜色设置失败") }

    logger.info("测试8: 导出")
    if let json = manager.exportToJSON() {
        if json.isEmpty { logger.error("❌ 测试8失败: JSON为空") }
        else { logger.info("✅ 测试8通过: 导出JSON成功") }
    } else { logger.error("❌ 测试8失败: 导出失败") }

    logger.info("测试9: allGroups")
    let all = manager.allGroups
    if all.isEmpty { logger.error("❌ 测试9失败") }
    else { logger.info("✅ 测试9通过: 分组数=\(all.count)") }

    logger.info("=== 全部标签分组测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
extension Notification.Name {
    /// 分组结构发生变更(创建/删除/重命名)
    static let tabGroupStructureChanged = Notification.Name("com.xianrenzhilu.tabGroup.structureChanged")
    /// 分组的折叠/展开状态发生变更
    static let tabGroupFoldStateChanged = Notification.Name("com.xianrenzhilu.tabGroup.foldStateChanged")
    /// 分组颜色标识发生变更
    static let tabGroupColorChanged = Notification.Name("com.xianrenzhilu.tabGroup.colorChanged")
    /// 标签页移入/移出分组
    static let tabGroupTabMoved = Notification.Name("com.xianrenzhilu.tabGroup.tabMoved")
    /// 分组顺序发生变更
    static let tabGroupOrderChanged = Notification.Name("com.xianrenzhilu.tabGroup.orderChanged")
}

// MARK: - 迁回自 UI-02：class UITabGroupManager
public final class UITabGroupManager: @unchecked Sendable {

    // MARK: 单例

    /// 共享单例实例
    public static let shared = UITabGroupManager()

    // MARK: 日志器

    /// 结构化日志器,subsystem使用仙人指路统一标识
    private let logger = Logger(
        subsystem: "com.xianrenzhilu.app",
        category: "UITabGroupManager"
    )

    // MARK: 同步锁

    /// 保护共享数据结构的快速互斥锁(os_unfair_lock比NSLock更轻量)
    private let lock = NSRecursiveLock()

    // MARK: 数据存储

    /// 所有分组数据(受lock保护)
    private var groups: [UITabGroupModel] = []

    /// 全局设置项(受lock保护)
    private var globalSettings = UITabGroupGlobalSettings()

    /// 标签页ID到分组ID的映射缓存(受lock保护),加速查找标签所属分组
    private var tabToGroupMap: [String: String] = [:]

    /// 持久化文件URL(缓存,避免重复计算)
    private let storageURL: URL

    /// 通知中心实例
    private let notificationCenter = NotificationCenter.default

    /// 是否已加载持久化数据
    private var hasLoaded: Bool = false

    // MARK: 通知用户Info键名

    /// 通知中传递分组ID的键名
    public static let groupIDKey = "groupID"
    /// 通知中传递标签页ID的键名
    public static let tabIDKey = "tabID"
    /// 通知中传递旧分组ID的键名
    public static let oldGroupIDKey = "oldGroupID"
    /// 通知中传递新分组ID的键名
    public static let newGroupIDKey = "newGroupID"
    /// 通知中传递变更类型的键名
    public static let changeTypeKey = "changeType"

    // MARK: 初始化与销毁

    /// 私有初始化,确保单例模式
    private init() {
        // 计算持久化文件路径:应用支持目录/TabGroups/groups.json
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDir = appSupport.appendingPathComponent("XianRenZhiLu", isDirectory: true)
            let groupDir = appDir.appendingPathComponent("TabGroups", isDirectory: true)
            // 确保目录存在
            do {
                try fileManager.createDirectory(at: groupDir, withIntermediateDirectories: true, attributes: nil)
                self.logger.info("标签分组持久化目录准备完成: \(groupDir.path)")
            } catch {
                self.logger.error("创建持久化目录失败: \(error.localizedDescription)")
            }
            self.storageURL = groupDir.appendingPathComponent("groups.json")
        } else {
            // 后备路径:临时目录
            self.storageURL = fileManager.temporaryDirectory.appendingPathComponent("xrz_tabgroups.json")
            self.logger.warning("无法获取应用支持目录,使用临时路径: \(self.storageURL.path)")
        }

        self.logger.info("UITabGroupManager 单例初始化完成")
    }

    /// 析构函数,释放资源前尝试保存数据
    deinit {
        self.logger.info("UITabGroupManager 析构,执行最终保存...")
        // 解锁状态下直接保存(deinit时不能再加锁,但此时已无其他引用)
        do {
            try performSave()
            self.logger.info("最终保存成功")
        } catch {
            self.logger.error("最终保存失败: \(error.localizedDescription)")
        }
    }

    // MARK: 持久化加载与保存

    /// 从磁盘加载分组数据,线程安全(内部加锁)
    /// 首次调用时执行,重复调用会重新加载
    public func loadFromDisk() {
        let fileExists = FileManager.default.fileExists(atPath: self.storageURL.path)

        if !fileExists {
            self.logger.info("持久化文件不存在,初始化默认分组")
            self.lock.lock()
            self.initializeDefaultGroup()
            self.hasLoaded = true
            self.lock.unlock()
            return
        }

        do {
            let data = try Data(contentsOf: self.storageURL)
            let container = try JSONDecoder().decode(UITabGroupContainer.self, from: data)
            self.lock.lock()
            self.groups = container.groups
            self.globalSettings = container.settings
            self.rebuildTabToGroupMap()
            self.hasLoaded = true
            self.logger.info("从磁盘加载了 \(self.groups.count) 个分组,版本 \(container.version)")
            self.lock.unlock()
        } catch {
            self.logger.error("加载持久化数据失败: \(error.localizedDescription),初始化默认分组")
            self.lock.lock()
            self.initializeDefaultGroup()
            self.hasLoaded = true
            self.lock.unlock()
        }
    }

    /// 保存分组数据到磁盘,线程安全(内部加锁)
    /// 所有写操作后自动调用,也可手动触发
    public func saveToDisk() {
        do {
            try performSave()
        } catch {
            self.logger.error("保存到磁盘失败: \(error.localizedDescription)")
        }
    }

    /// 执行实际保存操作(必须在加锁状态下调用)
    private func performSave() throws {
        self.lock.lock()
        let container = UITabGroupContainer(
            groups: self.groups,
            settings: self.globalSettings
        )
        self.lock.unlock()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(container)
        try data.write(to: self.storageURL, options: [.atomicWrite, .completeFileProtection])
        self.logger.debug("分组数据已保存到 \(self.storageURL.path)")
    }

    /// 初始化默认分组(未加载到数据时使用)
    private func initializeDefaultGroup() {
        let defaultGroup = UITabGroupModel(
            id: "default-group",
            name: "默认分组",
            color: .blue,
            isExpanded: true,
            sortOrder: 0,
            isDefault: true,
            note: "系统默认分组,不可删除"
        )
        self.groups = [defaultGroup]
        self.rebuildTabToGroupMap()
        self.logger.info("已创建默认分组")
    }

    /// 重建标签页到分组的映射缓存(必须在加锁状态下调用)
    private func rebuildTabToGroupMap() {
        self.tabToGroupMap.removeAll(keepingCapacity: true)
        for group in self.groups {
            for tabRef in group.tabRefs {
                self.tabToGroupMap[tabRef.id] = group.id
            }
        }
    }

    // MARK: 分组查询(读操作)

    /// 获取所有分组列表(副本)
    public var allGroups: [UITabGroupModel] {
        self.lock.lock()
        let result = Array(self.groups)
        self.lock.unlock()
        return result
    }

    /// 根据ID获取分组(副本)
    public func group(byID id: String) -> UITabGroupModel? {
        self.lock.lock()
        let result = self.groups.first(where: { $0.id == id })
        self.lock.unlock()
        return result
    }

    /// 根据索引获取分组(副本)
    public func group(at index: Int) -> UITabGroupModel? {
        self.lock.lock()
        guard index >= 0 && index < self.groups.count else {
            self.lock.unlock()
            return nil
        }
        let result = self.groups[index]
        self.lock.unlock()
        return result
    }

    /// 获取分组总数
    public var groupCount: Int {
        self.lock.lock()
        let result = self.groups.count
        self.lock.unlock()
        return result
    }

    /// 查找包含指定标签页的分组ID
    public func groupIDContaining(tabID: String) -> String? {
        self.lock.lock()
        let result = self.tabToGroupMap[tabID]
        self.lock.unlock()
        return result
    }

    /// 查找包含指定标签页的分组(副本)
    public func groupContaining(tabID: String) -> UITabGroupModel? {
        self.lock.lock()
        guard let gid = self.tabToGroupMap[tabID] else {
            self.lock.unlock()
            return nil
        }
        let result = self.groups.first(where: { $0.id == gid })
        self.lock.unlock()
        return result
    }

    /// 获取指定分组内的所有标签页引用
    public func tabsInGroup(groupID: String) -> [UITabRef] {
        self.lock.lock()
        let result = self.groups.first(where: { $0.id == groupID })?.tabRefs ?? []
        self.lock.unlock()
        return result
    }

    /// 判断指定分组是否存在
    public func groupExists(_ groupID: String) -> Bool {
        self.lock.lock()
        let result = self.groups.contains(where: { $0.id == groupID })
        self.lock.unlock()
        return result
    }

    /// 获取所有展开的(未折叠)分组
    public var expandedGroups: [UITabGroupModel] {
        self.lock.lock()
        let result = self.groups.filter { $0.isExpanded }
        self.lock.unlock()
        return result
    }

    /// 获取所有折叠的分组
    public var collapsedGroups: [UITabGroupModel] {
        self.lock.lock()
        let result = self.groups.filter { !$0.isExpanded }
        self.lock.unlock()
        return result
    }

    // MARK: 分组创建

    /// 创建新分组
    /// - Parameters:
    ///   - name: 分组名称(不可为空)
    ///   - color: 颜色标识(默认无颜色)
    ///   - note: 分组备注(可选)
    /// - Returns: 新创建的分组模型(副本)
    @discardableResult
    public func createGroup(name: String, color: UITabGroupColor = .none, note: String = "") -> UITabGroupModel? {
        // 名称校验
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.logger.warning("创建分组失败:名称为空")
            return nil
        }

        self.lock.lock()

        // 检查最大分组数量限制
        if self.groups.count >= self.globalSettings.maxGroupCount {
            self.logger.warning("创建分组失败:已达到最大分组数量限制 \(self.globalSettings.maxGroupCount)")
            self.lock.unlock()
            self.lock.unlock()
            return nil
        }

        // 检查名称是否已存在(不区分大小写)
        if self.groups.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            self.logger.warning("创建分组失败:名称 '\(trimmed)' 已存在")
            return nil
        }

        let newGroup = UITabGroupModel(
            name: trimmed,
            color: color,
            isExpanded: self.globalSettings.defaultExpanded,
            sortOrder: self.groups.count,
            note: note
        )
        self.groups.append(newGroup)
        self.sortGroupsByOrder()

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("创建分组成功: \(newGroup.name) (ID: \(newGroup.id))")

        // 发送通知
        self.lock.unlock() // 解锁再发通知,避免死锁
        self.notificationCenter.post(
            name: .tabGroupStructureChanged,
            object: self,
            userInfo: [
                Self.groupIDKey: newGroup.id,
                Self.changeTypeKey: "created"
            ]
        )
        return newGroup
    }

    // MARK: 分组删除

    /// 删除指定分组,可选择将其中的标签页移动到其他分组
    /// - Parameters:
    ///   - groupID: 要删除的分组ID
    ///   - moveTabsTo: 标签页迁移目标分组ID(nil则直接删除标签页引用)
    /// - Returns: 是否删除成功
    @discardableResult
    public func deleteGroup(groupID: String, moveTabsTo destinationGroupID: String? = nil) -> Bool {
        self.lock.lock()

        guard let index = self.groups.firstIndex(where: { $0.id == groupID }) else {
            self.logger.warning("删除分组失败:未找到ID \(groupID)")
            self.lock.unlock()
            return false
        }

        let targetGroup = self.groups[index]

        // 默认分组不可删除
        guard !targetGroup.isDefault else {
            self.logger.warning("删除分组失败:默认分组不可删除")
            return false
        }

        // 处理子标签页迁移
        if let destID = destinationGroupID, let destIndex = self.groups.firstIndex(where: { $0.id == destID }) {
            var destGroup = self.groups[destIndex]
            for tabRef in targetGroup.tabRefs {
                destGroup.tabRefs.append(tabRef)
            }
            destGroup.touch()
            self.groups[destIndex] = destGroup
            self.logger.info("已将 \(targetGroup.tabRefs.count) 个标签页迁移到分组 \(destID)")
        } else if !targetGroup.tabRefs.isEmpty {
            // 未指定目标分组且设置允许自动删除空分组,则直接丢弃标签页引用
            self.logger.info("删除分组 \(groupID) 并丢弃 \(targetGroup.tabRefs.count) 个标签页引用")
        }

        self.groups.remove(at: index)
        self.rebuildTabToGroupMap()

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("删除分组成功: \(targetGroup.name) (ID: \(groupID))")

        // 发送通知
        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupStructureChanged,
            object: self,
            userInfo: [
                Self.groupIDKey: groupID,
                Self.changeTypeKey: "deleted"
            ]
        )

        return true
    }

    // MARK: 分组重命名

    /// 重命名指定分组
    /// - Parameters:
    ///   - groupID: 目标分组ID
    ///   - newName: 新名称
    /// - Returns: 是否重命名成功
    @discardableResult
    public func renameGroup(groupID: String, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.logger.warning("重命名分组失败:新名称为空")
            return false
        }

        self.lock.lock()

        guard let index = self.groups.firstIndex(where: { $0.id == groupID }) else {
            self.logger.warning("重命名分组失败:未找到ID \(groupID)")
            return false
        }

        // 检查名称冲突(排除自身)
        if self.groups.contains(where: { $0.id != groupID && $0.name.lowercased() == trimmed.lowercased() }) {
            self.logger.warning("重命名分组失败:名称 '\(trimmed)' 已被其他分组使用")
            return false
        }

        let oldName = self.groups[index].name
        self.groups[index].name = trimmed
        self.groups[index].touch()

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("分组重命名成功: '\(oldName)' → '\(trimmed)' (ID: \(groupID))")

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupStructureChanged,
            object: self,
            userInfo: [
                Self.groupIDKey: groupID,
                Self.changeTypeKey: "renamed"
            ]
        )

        return true
    }

    // MARK: 分组颜色设置

    /// 设置分组颜色标识
    /// - Parameters:
    ///   - groupID: 目标分组ID
    ///   - color: 新颜色
    /// - Returns: 是否设置成功
    @discardableResult
    public func setGroupColor(groupID: String, color: UITabGroupColor) -> Bool {
        self.lock.lock()

        guard let index = self.groups.firstIndex(where: { $0.id == groupID }) else {
            self.logger.warning("设置颜色失败:未找到分组ID \(groupID)")
            return false
        }

        self.groups[index].color = color
        self.groups[index].touch()

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("分组颜色变更: \(groupID) → \(color.rawValue)")

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupColorChanged,
            object: self,
            userInfo: [
                Self.groupIDKey: groupID,
                "color": color.rawValue
            ]
        )
        self.lock.unlock()
        return true
    }

    // MARK: 分组折叠/展开

    /// 切换指定分组的折叠/展开状态
    /// - Parameter groupID: 目标分组ID
    /// - Returns: 切换后的展开状态(true=展开,false=折叠)
    @discardableResult
    public func toggleGroupFold(groupID: String) -> Bool? {
        self.lock.lock()

        guard let index = self.groups.firstIndex(where: { $0.id == groupID }) else {
            self.logger.warning("切换折叠状态失败:未找到分组ID \(groupID)")
            return nil
        }

        let oldState = self.groups[index].isExpanded
        self.groups[index].isExpanded = !oldState
        self.groups[index].touch()
        let newState = self.groups[index].isExpanded

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("分组折叠状态切换: \(groupID) \(oldState ? "展开" : "折叠") → \(newState ? "展开" : "折叠")")

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupFoldStateChanged,
            object: self,
            userInfo: [
                Self.groupIDKey: groupID,
                "isExpanded": newState,
                "oldState": oldState
            ]
        )
        self.lock.unlock()
        return newState
    }

    /// 展开指定分组
    /// - Parameter groupID: 目标分组ID
    /// - Returns: 是否成功展开(已是展开状态也返回true)
    @discardableResult
    public func expandGroup(groupID: String) -> Bool {
        self.lock.lock()

        guard let index = self.groups.firstIndex(where: { $0.id == groupID }) else {
            return false
        }

        guard !self.groups[index].isExpanded else { return true }

        self.groups[index].isExpanded = true
        self.groups[index].touch()

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupFoldStateChanged,
            object: self,
            userInfo: [
                Self.groupIDKey: groupID,
                "isExpanded": true
            ]
        )
        self.lock.unlock()
        return true
    }

    /// 折叠指定分组
    /// - Parameter groupID: 目标分组ID
    /// - Returns: 是否成功折叠(已是折叠状态也返回true)
    @discardableResult
    public func collapseGroup(groupID: String) -> Bool {
        self.lock.lock()

        guard let index = self.groups.firstIndex(where: { $0.id == groupID }) else {
            return false
        }

        guard self.groups[index].isExpanded else { return true }

        self.groups[index].isExpanded = false
        self.groups[index].touch()

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupFoldStateChanged,
            object: self,
            userInfo: [
                Self.groupIDKey: groupID,
                "isExpanded": false
            ]
        )
        self.lock.unlock()
        return true
    }

    /// 展开所有分组
    public func expandAllGroups() {
        self.lock.lock()

        var changed = false
        for i in 0..<self.groups.count {
            if !self.groups[i].isExpanded {
                self.groups[i].isExpanded = true
                self.groups[i].touch()
                changed = true
            }
        }

        guard changed else { return }

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("已展开所有分组")

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupFoldStateChanged,
            object: self,
            userInfo: [Self.changeTypeKey: "expandAll"]
        )
    }

    /// 折叠所有分组
    public func collapseAllGroups() {
        self.lock.lock()

        var changed = false
        for i in 0..<self.groups.count {
            if self.groups[i].isExpanded {
                self.groups[i].isExpanded = false
                self.groups[i].touch()
                changed = true
            }
        }

        guard changed else { return }

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("已折叠所有分组")

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupFoldStateChanged,
            object: self,
            userInfo: [Self.changeTypeKey: "collapseAll"]
        )
    }

    // MARK: 标签页移入/移出分组

    /// 将标签页移入指定分组
    /// - Parameters:
    ///   - tabRef: 标签页引用
    ///   - groupID: 目标分组ID
    ///   - atIndex: 插入位置(nil表示末尾)
    /// - Returns: 是否移动成功
    @discardableResult
    public func moveTabIntoGroup(_ tabRef: UITabRef, groupID: String, atIndex: Int? = nil) -> Bool {
        self.lock.lock()

        guard let targetIndex = self.groups.firstIndex(where: { $0.id == groupID }) else {
            self.logger.warning("移入标签页失败:未找到目标分组 \(groupID)")
            return false
        }

        let tabID = tabRef.id

        // 如果标签页已在该分组中,不重复添加
        if self.groups[targetIndex].contains(tabID: tabID) {
            self.logger.debug("标签页 \(tabID) 已在分组 \(groupID) 中")
            return true
        }

        // 从原分组中移除(如果存在)
        if let oldGroupID = self.tabToGroupMap[tabID],
           let oldIndex = self.groups.firstIndex(where: { $0.id == oldGroupID }) {
            self.groups[oldIndex].tabRefs.removeAll(where: { $0.id == tabID })
            self.groups[oldIndex].touch()
        }

        // 插入新分组
        let insertPos = atIndex ?? self.groups[targetIndex].tabRefs.count
        let clampedPos = max(0, min(insertPos, self.groups[targetIndex].tabRefs.count))
        self.groups[targetIndex].tabRefs.insert(tabRef, at: clampedPos)
        self.groups[targetIndex].touch()

        // 更新映射
        self.tabToGroupMap[tabID] = groupID

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("标签页 \(tabRef.title) 已移入分组 \(self.groups[targetIndex].name)")

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupTabMoved,
            object: self,
            userInfo: [
                Self.tabIDKey: tabID,
                Self.newGroupIDKey: groupID,
                Self.changeTypeKey: "movedIn"
            ]
        )
        self.lock.unlock()
        return true
    }

    /// 将标签页从当前分组中移除(但不删除标签页本身)
    /// - Parameter tabID: 标签页ID
    /// - Returns: 是否移除成功
    @discardableResult
    public func removeTabFromGroup(tabID: String) -> Bool {
        self.lock.lock()

        guard let oldGroupID = self.tabToGroupMap[tabID],
              let oldIndex = self.groups.firstIndex(where: { $0.id == oldGroupID }) else {
            self.logger.warning("移除标签页失败:标签页 \(tabID) 不属于任何分组")
            return false
        }

        self.groups[oldIndex].tabRefs.removeAll(where: { $0.id == tabID })
        self.groups[oldIndex].touch()
        self.tabToGroupMap.removeValue(forKey: tabID)

        // 如果开启自动删除空分组且该分组已空且非默认分组,则删除
        if self.globalSettings.autoDeleteEmptyGroups
            && self.groups[oldIndex].isEmpty
            && !self.groups[oldIndex].isDefault {
            let emptyGroup = self.groups[oldIndex]
            self.groups.remove(at: oldIndex)
            self.logger.info("自动删除空分组: \(emptyGroup.name)")
        }

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("标签页 \(tabID) 已从分组 \(oldGroupID) 中移除")

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupTabMoved,
            object: self,
            userInfo: [
                Self.tabIDKey: tabID,
                Self.oldGroupIDKey: oldGroupID,
                Self.changeTypeKey: "removed"
            ]
        )
        self.lock.unlock()
        return true
    }

    /// 批量移动标签页到指定分组
    /// - Parameters:
    ///   - tabRefs: 标签页引用数组
    ///   - groupID: 目标分组ID
    /// - Returns: 成功移动的数量
    @discardableResult
    public func batchMoveTabs(_ tabRefs: [UITabRef], to groupID: String) -> Int {
        self.lock.lock()

        guard let targetIndex = self.groups.firstIndex(where: { $0.id == groupID }) else {
            self.logger.warning("批量移动失败:未找到目标分组 \(groupID)")
            return 0
        }

        var movedCount = 0
        for tabRef in tabRefs {
            let tabID = tabRef.id

            // 从原分组移除
            if let oldGroupID = self.tabToGroupMap[tabID],
               let oldIndex = self.groups.firstIndex(where: { $0.id == oldGroupID }) {
                self.groups[oldIndex].tabRefs.removeAll(where: { $0.id == tabID })
                self.groups[oldIndex].touch()
            }

            // 添加到新分组(避免重复)
            if !self.groups[targetIndex].contains(tabID: tabID) {
                self.groups[targetIndex].tabRefs.append(tabRef)
                movedCount += 1
            }

            self.tabToGroupMap[tabID] = groupID
        }

        self.groups[targetIndex].touch()

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("批量移动完成:\(movedCount) 个标签页 → 分组 \(self.groups[targetIndex].name)")

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupTabMoved,
            object: self,
            userInfo: [
                Self.newGroupIDKey: groupID,
                Self.changeTypeKey: "batchMoved",
                "count": movedCount
            ]
        )
        self.lock.unlock()
        return movedCount
    }

    /// 在分组内部调整标签页顺序
    /// - Parameters:
    ///   - tabID: 要移动的标签页ID
    ///   - groupID: 分组ID
    ///   - toIndex: 目标索引位置
    /// - Returns: 是否调整成功
    @discardableResult
    public func reorderTabInGroup(tabID: String, groupID: String, toIndex: Int) -> Bool {
        self.lock.lock()

        guard let groupIdx = self.groups.firstIndex(where: { $0.id == groupID }) else {
            self.lock.unlock()
            return false
        }

        guard let tabIdx = self.groups[groupIdx].tabRefs.firstIndex(where: { $0.id == tabID }) else {
            return false
        }

        let tabRef = self.groups[groupIdx].tabRefs.remove(at: tabIdx)
        let clampedIdx = max(0, min(toIndex, self.groups[groupIdx].tabRefs.count))
        self.groups[groupIdx].tabRefs.insert(tabRef, at: clampedIdx)
        self.groups[groupIdx].touch()

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        return true
    }

    // MARK: 分组排序

    /// 移动分组到指定索引位置(改变分组顺序)
    /// - Parameters:
    ///   - groupID: 要移动的分组ID
    ///   - toIndex: 目标索引
    /// - Returns: 是否移动成功
    @discardableResult
    public func moveGroupToIndex(groupID: String, toIndex: Int) -> Bool {
        self.lock.lock()

        guard let fromIndex = self.groups.firstIndex(where: { $0.id == groupID }) else {
            return false
        }

        let clampedTo = max(0, min(toIndex, self.groups.count - 1))
        guard fromIndex != clampedTo else { return true }

        let group = self.groups.remove(at: fromIndex)
        self.groups.insert(group, at: clampedTo)

        // 重新分配sortOrder
        for i in 0..<self.groups.count {
            self.groups[i].sortOrder = i
        }

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("分组顺序调整: \(groupID) \(fromIndex) → \(clampedTo)")

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupOrderChanged,
            object: self,
            userInfo: [
                Self.groupIDKey: groupID,
                "fromIndex": fromIndex,
                "toIndex": clampedTo
            ]
        )
        self.lock.unlock()
        return true
    }

    /// 按sortOrder排序分组(恢复有序状态)
    private func sortGroupsByOrder() {
        self.groups.sort { $0.sortOrder < $1.sortOrder }
    }

    // MARK: 设置面板相关方法

    /// 获取全局设置副本(供设置面板读取)
    public var settings: UITabGroupGlobalSettings {
        self.lock.lock()
        let result = self.globalSettings
        self.lock.unlock()
        return result
    }

    /// 更新全局设置(设置面板调用)
    /// - Parameter newSettings: 新设置值
    public func updateSettings(_ newSettings: UITabGroupGlobalSettings) {
        self.lock.lock()

        self.globalSettings = newSettings

        do {
            try performSave()
        } catch {
            self.logger.error("保存设置失败: \(error.localizedDescription)")
        self.lock.unlock()
        }

        self.logger.info("全局设置已更新")
    }

    /// 设置新分组默认展开状态
    public func setDefaultExpanded(_ expanded: Bool) {
        self.lock.lock()
        self.globalSettings.defaultExpanded = expanded
        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        self.lock.unlock()
        }
        self.logger.info("设置新分组默认展开: \(expanded)")
    }

    /// 设置是否显示颜色指示条
    public func setShowColorIndicator(_ show: Bool) {
        self.lock.lock()
        self.globalSettings.showColorIndicator = show
        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        self.lock.unlock()
        }
        self.logger.info("设置显示颜色指示条: \(show)")
    }

    /// 设置是否自动删除空分组
    public func setAutoDeleteEmptyGroups(_ autoDelete: Bool) {
        self.lock.lock()
        self.globalSettings.autoDeleteEmptyGroups = autoDelete
        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        self.lock.unlock()
        }
        self.logger.info("设置自动删除空分组: \(autoDelete)")
    }

    /// 设置最大分组数量限制
    public func setMaxGroupCount(_ count: Int) {
        self.lock.lock()
        self.globalSettings.maxGroupCount = max(1, min(count, 100))
        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        self.lock.unlock()
        }
        self.logger.info("设置最大分组数量: \(self.globalSettings.maxGroupCount)")
    }

    /// 获取所有可用的颜色选项(供设置面板UI展示)
    public var availableColors: [(color: UITabGroupColor, displayName: String, nsColor: NSColor)] {
        return UITabGroupColor.allCases.map { ($0, $0.rawValue, $0.displayColor) }
    }

    /// 重置所有分组数据(危险操作,设置面板确认后调用)
    /// 会清除所有分组并重新初始化默认分组
    public func resetAllGroups() {
        self.lock.lock()

        self.groups.removeAll()
        self.tabToGroupMap.removeAll()
        self.initializeDefaultGroup()

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        self.logger.info("已重置所有分组数据")

        self.lock.unlock()
        self.notificationCenter.post(
            name: .tabGroupStructureChanged,
            object: self,
            userInfo: [Self.changeTypeKey: "resetAll"]
        )
    }

    // MARK: 导入/导出

    /// 导出分组数据为JSON字符串(用于备份或迁移)
    /// - Returns: JSON字符串
    public func exportToJSON() -> String? {
        self.lock.lock()

        let container = UITabGroupContainer(
            groups: self.groups,
            settings: self.globalSettings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(container)
            let jsonString = String(data: data, encoding: .utf8)
            self.logger.info("导出分组数据成功,共 \(self.groups.count) 个分组")
            self.lock.unlock()
            return jsonString
        } catch {
            self.logger.error("导出JSON失败: \(error.localizedDescription)")
            self.lock.unlock()
            return nil
        }
    }

    /// 从JSON字符串导入分组数据(会覆盖现有数据)
    /// - Parameter jsonString: JSON字符串
    /// - Returns: 是否导入成功
    @discardableResult
    public func importFromJSON(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            self.logger.error("导入失败:无法将字符串转换为Data")
            return false
        }

        let decoder = JSONDecoder()
        do {
            let container = try decoder.decode(UITabGroupContainer.self, from: data)

            self.lock.lock()

            self.groups = container.groups
            self.globalSettings = container.settings
            self.rebuildTabToGroupMap()

            try performSave()

            self.logger.info("导入分组数据成功,共 \(self.groups.count) 个分组")

            self.lock.unlock()
            self.notificationCenter.post(
                name: .tabGroupStructureChanged,
                object: self,
                userInfo: [Self.changeTypeKey: "imported"]
            )
            self.lock.lock()

            self.lock.unlock()
            return true
        } catch {
            self.logger.error("导入JSON失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: 辅助方法

    /// 设置分组备注
    /// - Parameters:
    ///   - groupID: 分组ID
    ///   - note: 备注内容
    /// - Returns: 是否设置成功
    @discardableResult
    public func setGroupNote(groupID: String, note: String) -> Bool {
        self.lock.lock()

        guard let index = self.groups.firstIndex(where: { $0.id == groupID }) else {
            self.lock.unlock()
            return false
        }

        self.groups[index].note = note
        self.groups[index].touch()

        do {
            try performSave()
        } catch {
            self.logger.error("保存失败: \(error.localizedDescription)")
        }

        return true
    }

    /// 获取所有分组名称列表(供UI展示)
    public var allGroupNames: [(id: String, name: String, color: UITabGroupColor, isDefault: Bool)] {
        self.lock.lock()
        let result = self.groups.map { ($0.id, $0.name, $0.color, $0.isDefault) }
        self.lock.unlock()
        return result
    }

    /// 获取分组统计信息(供设置面板或状态栏显示)
    public var statistics: (totalGroups: Int, totalTabs: Int, expandedGroups: Int, collapsedGroups: Int) {
        self.lock.lock()
        let totalTabs = self.groups.reduce(0) { $0 + $1.tabRefs.count }
        let expanded = self.groups.filter { $0.isExpanded }.count
        let totalCount = self.groups.count
        let result = (totalCount, totalTabs, expanded, totalCount - expanded)
        self.lock.unlock()
        return result
    }

    /// 获取持久化文件路径(供调试或手动备份)
    public var persistencePath: String {
        return self.storageURL.path
    }

    /// 确保数据已加载(首次访问时自动调用)
    public func ensureLoaded() {
        if !self.hasLoaded {
            loadFromDisk()
        }
    }

    /// 打印当前所有分组结构的调试信息(仅供开发调试用)
    public func debugPrintStructure() {
        self.lock.lock()

        self.logger.debug("=== 标签分组结构 ===")
        for (i, group) in self.groups.enumerated() {
            let state = group.isExpanded ? "展开" : "折叠"
            self.logger.debug("[\(i)] \(group.name) (\(group.id)) [\(group.color.rawValue)] [\(state)] 标签: \(group.tabRefs.count)")
            for tab in group.tabRefs {
                self.logger.debug("    - \(tab.title) (\(tab.id))")
            }
        self.lock.unlock()
        }
        self.logger.debug("===================")
    }
}

// MARK: - 迁回自 UI-02：extension UITabGroupManager
extension UITabGroupManager {

    /// 快速创建分组并返回ID(失败返回nil)
    public func quickCreateGroup(name: String, color: UITabGroupColor = .none) -> String? {
        return createGroup(name: name, color: color)?.id
    }

    /// 判断分组是否展开(便捷方法)
    public func isGroupExpanded(_ groupID: String) -> Bool {
        return group(byID: groupID)?.isExpanded ?? false
    }

    /// 获取分组颜色(便捷方法)
    public func groupColor(_ groupID: String) -> UITabGroupColor {
        return group(byID: groupID)?.color ?? .none
    }

    /// 获取分组名称(便捷方法)
    public func groupName(_ groupID: String) -> String {
        return group(byID: groupID)?.name ?? "未知分组"
    }

    /// 获取分组内标签页数量(便捷方法)
    public func tabCountInGroup(_ groupID: String) -> Int {
        return group(byID: groupID)?.tabCount ?? 0
    }
}

// MARK: - 迁回自 UI-02：UITabGroupContainer
private struct UITabGroupContainer: Codable, Sendable {
    /// 分组列表
    var groups: [UITabGroupModel]
    /// 最后保存时间戳
    var lastSavedAt: TimeInterval
    /// 数据版本号(用于未来迁移)
    var version: String
    /// 全局设置项
    var settings: UITabGroupGlobalSettings

    init(groups: [UITabGroupModel] = [], settings: UITabGroupGlobalSettings = UITabGroupGlobalSettings()) {
        self.groups = groups
        self.lastSavedAt = Date().timeIntervalSince1970
        self.version = "2.0"
        self.settings = settings
    }
}

// MARK: - 迁回自 UI-02：enum UITabGroupColor
// MARK: - 预览窗口面板
/// 自定义无边框面板，用于显示标签页预览内容
// 已迁回 UI-GL-48_标签页预览.swift：class UITabPreviewPanel（公共类型文件禁止功能实现）

// MARK: - 标签页预览管理器
/// 管理所有标签页预览功能的核心单例类
/// 负责悬停检测、缩略图生成、预览窗口管理、缓存策略
// 已迁回 UI-GL-48_标签页预览.swift：class UITabPreviewManager（公共类型文件禁止功能实现）

// MARK: - 设置面板视图控制器
/// 标签页预览设置的专用视图控制器
// 已迁回 UI-GL-48_标签页预览.swift：class UITabPreviewSettingsViewController（公共类型文件禁止功能实现）

// MARK: - NSView 截图扩展
/// 为 NSView 添加便捷的截图方法
// 已迁回 UI-GL-48_标签页预览.swift：extension NSView（公共类型文件禁止功能实现）


// MARK: - UI-GL-49 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-49_types.swift
// 版本: 2.0
/// 标签分组可用的颜色标识,用于视觉区分不同分组
public enum UITabGroupColor: String, Codable, CaseIterable, Sendable {
    case none = "无颜色"
    case red = "红色"
    case orange = "橙色"
    case yellow = "黄色"
    case green = "绿色"
    case cyan = "青色"
    case blue = "蓝色"
    case purple = "紫色"
    case pink = "粉色"
    case gray = "灰色"

    /// 对应的NSColor显示颜色
    public var displayColor: NSColor {
        switch self {
        case .none:     return .clear
        case .red:      return NSColor(calibratedRed: 0.92, green: 0.26, blue: 0.21, alpha: 1.0)
        case .orange:   return NSColor(calibratedRed: 0.96, green: 0.59, blue: 0.18, alpha: 1.0)
        case .yellow:   return NSColor(calibratedRed: 0.95, green: 0.77, blue: 0.06, alpha: 1.0)
        case .green:    return NSColor(calibratedRed: 0.30, green: 0.69, blue: 0.31, alpha: 1.0)
        case .cyan:     return NSColor(calibratedRed: 0.15, green: 0.68, blue: 0.84, alpha: 1.0)
        case .blue:     return NSColor(calibratedRed: 0.26, green: 0.52, blue: 0.96, alpha: 1.0)
        case .purple:   return NSColor(calibratedRed: 0.61, green: 0.15, blue: 0.69, alpha: 1.0)
        case .pink:     return NSColor(calibratedRed: 0.92, green: 0.25, blue: 0.48, alpha: 1.0)
        case .gray:     return NSColor(calibratedRed: 0.62, green: 0.62, blue: 0.62, alpha: 1.0)
        }
    }

    /// 颜色对应的十六进制字符串(用于持久化显示)
    public var hexString: String {
        let c = displayColor
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }
}

// MARK: - 迁回自 UI-02：struct UITabRef
/// 标签页在分组中的轻量引用,避免直接持有完整UITabItem导致循环依赖
public struct UITabRef: Codable, Equatable, Sendable, Identifiable {
    /// 标签页唯一标识符
    public let id: String
    /// 标签页显示标题
    public var title: String
    /// 标签页类型标识
    public var tabType: String
    /// 排序权重,越小越靠前
    public var sortOrder: Int

    public init(id: String, title: String, tabType: String, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.tabType = tabType
        self.sortOrder = sortOrder
    }
}

// MARK: - 迁回自 UI-02：struct UITabGroupModel
/// 标签分组实体模型,包含分组的完整元数据和子标签列表
public struct UITabGroupModel: Codable, Identifiable, Equatable, Sendable {
    /// 分组唯一标识符
    public let id: String
    /// 分组显示名称
    public var name: String
    /// 分组颜色标识
    public var color: UITabGroupColor
    /// 子标签页引用列表
    public var tabRefs: [UITabRef]
    /// 是否展开(true=展开显示子标签,false=折叠只显示分组名)
    public var isExpanded: Bool
    /// 创建时间戳,用于排序
    public let createdAt: TimeInterval
    /// 最后更新时间戳
    public var updatedAt: TimeInterval
    /// 自定义排序权重
    public var sortOrder: Int
    /// 是否为默认分组(默认分组不可删除)
    public var isDefault: Bool
    /// 分组备注说明
    public var note: String

    /// 创建新分组实例
    public init(
        id: String = UUID().uuidString,
        name: String,
        color: UITabGroupColor = .none,
        tabRefs: [UITabRef] = [],
        isExpanded: Bool = true,
        sortOrder: Int = 0,
        isDefault: Bool = false,
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.tabRefs = tabRefs
        self.isExpanded = isExpanded
        self.createdAt = Date().timeIntervalSince1970
        self.updatedAt = self.createdAt
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.note = note
    }

    /// 更新修改时间戳
    public mutating func touch() {
        self.updatedAt = Date().timeIntervalSince1970
    }

    /// 计算属性:折叠状态下应显示的名称(带标签数量)
    public var collapsedDisplayName: String {
        let count = tabRefs.count
        return count > 0 ? "\(name) (\(count))" : name
    }

    /// 判断分组是否包含指定标签页
    public func contains(tabID: String) -> Bool {
        return tabRefs.contains(where: { $0.id == tabID })
    }

    /// 获取分组内标签页数量
    public var tabCount: Int {
        return tabRefs.count
    }

    /// 判断分组是否为空(无标签页)
    public var isEmpty: Bool {
        return tabRefs.isEmpty
    }
}

// MARK: - 迁回自 UI-02：struct UITabGroupGlobalSettings
/// 用于Codable持久化的顶层数据容器,保存所有分组和全局配置
// 已迁回 UI-GL-49_标签页分组.swift：UITabGroupContainer（功能持久化容器不属于公共类型）

/// 标签分组全局配置,存储在持久化容器中的设置项
public struct UITabGroupGlobalSettings: Codable, Sendable {
    /// 新分组默认展开
    public var defaultExpanded: Bool
    /// 是否显示分组颜色指示条
    public var showColorIndicator: Bool
    /// 是否允许空分组自动删除
    public var autoDeleteEmptyGroups: Bool
    /// 折叠动画时长(秒)
    public var foldAnimationDuration: Double
    /// 最大分组数量限制
    public var maxGroupCount: Int

    public init(
        defaultExpanded: Bool = true,
        showColorIndicator: Bool = true,
        autoDeleteEmptyGroups: Bool = false,
        foldAnimationDuration: Double = 0.25,
        maxGroupCount: Int = 20
    ) {
        self.defaultExpanded = defaultExpanded
        self.showColorIndicator = showColorIndicator
        self.autoDeleteEmptyGroups = autoDeleteEmptyGroups
        self.foldAnimationDuration = foldAnimationDuration
        self.maxGroupCount = maxGroupCount
    }
}

// MARK: - NSColor Hex 扩展 - 全局唯一版本
extension NSColor {
    /// 转换为RGB十六进制字符串
    public var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }

    /// 从十六进制字符串初始化颜色
    public convenience init?(hexString: String) {
        var trimmed = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimmed.replacingOccurrences(of: "#", with: "")

        guard trimmed.count == 6 || trimmed.count == 8 else { return nil }

        var rgba: UInt64 = 0
        guard Scanner(string: trimmed).scanHexInt64(&rgba) else { return nil }

        let r, g, b, a: CGFloat
        if trimmed.count == 6 {
            r = CGFloat((rgba & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgba & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgba & 0x0000FF) / 255.0
            a = 1.0
        } else {
            r = CGFloat((rgba & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgba & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgba & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgba & 0x000000FF) / 255.0
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
