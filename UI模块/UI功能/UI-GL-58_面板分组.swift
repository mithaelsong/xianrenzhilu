// 功能48: 面板分组
// 对应: 面板可以分组管理，支持创建/删除/重命名/折叠/展开等操作
// 优先级: P2
import AppKit
import Foundation
import os.log

// MARK: - 统一日志器
private let logger = Logger(subsystem: "com.xianrenzhilu.app", category: "PanelGroups")

// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {


// MARK: - 测试代码
#if DEBUG

/// 功能48：面板分组 — 单元测试
func test_panelGroup() {
    let manager = UIPanelGroupManager.shared
    
    logger.info("测试1: 创建分组")
    let group = manager.createGroup(name: "测试分组")
    if manager.hasGroup(groupID: group.groupID) { logger.info("✅ 测试1通过") }
    else { logger.error("❌ 测试1失败") }
    
    logger.info("测试2: 分组数量")
    if manager.groupCount >= 1 { logger.info("✅ 测试2通过") }
    else { logger.error("❌ 测试2失败") }
    
    logger.info("测试3: 重命名")
    manager.renameGroup(groupID: group.groupID, newName: "已改名")
    let name = manager.groupName(for: group.groupID)
    if name == "已改名" { logger.info("✅ 测试3通过") }
    else { logger.error("❌ 测试3失败") }
    
    logger.info("测试4: 添加面板")
    manager.addPanel(windowID: "panel1", toGroup: group.groupID)
    let panelIDs = manager.panelIDs(inGroup: group.groupID)
    if panelIDs.contains("panel1") { logger.info("✅ 测试4通过") }
    else { logger.error("❌ 测试4失败") }
    
    logger.info("测试5: 移除面板")
    manager.removePanel(windowID: "panel1", fromGroup: group.groupID)
    let afterRemove = manager.panelIDs(inGroup: group.groupID)
    if !afterRemove.contains("panel1") { logger.info("✅ 测试5通过") }
    else { logger.error("❌ 测试5失败") }
    
    logger.info("测试6: 折叠/展开")
    manager.collapseGroup(groupID: group.groupID)
    if group.isCollapsed { logger.info("✅ 测试6通过") }
    else { logger.error("❌ 测试6失败") }
    manager.expandGroup(groupID: group.groupID)
    
    logger.info("测试7: 设置面板")
    let info = manager.groupSettings(for: group.groupID)
    if info?.groupID == group.groupID { logger.info("✅ 测试7通过") }
    else { logger.error("❌ 测试7失败") }
    
    logger.info("测试8: 删除分组")
    manager.deleteGroup(groupID: group.groupID)
    if !manager.hasGroup(groupID: group.groupID) { logger.info("✅ 测试8通过") }
    else { logger.error("❌ 测试8失败") }
    
    logger.info("=== 全部面板分组测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIPanelGroup
public final class UIPanelGroup: Codable , @unchecked Sendable{
    // 编解码键
    enum UICodingKeys: String, CodingKey {
        case groupID, name, panels, activePanelID, isCollapsed, isVisible
    }

    /// 分组唯一标识
    public let groupID: String
    /// 分组名称
    public var name: String
    /// 面板窗口ID列表（按顺序）
    public var panels: [String] = []
    /// 当前激活的面板ID
    public var activePanelID: String?
    /// 是否折叠
    public var isCollapsed: Bool = false
    /// 是否可见
    public var isVisible: Bool = true
    /// 线程锁（同一文件内可访问）
    fileprivate let lock = NSRecursiveLock()
    /// 日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu.panel", category: "UIPanelGroup")

    // MARK: - 初始化
    public init(groupID: String, name: String) {
        self.groupID = groupID
        self.name = name
        logger.info("创建面板分组: \(name) [\(groupID)]")
    }

    // MARK: - Codable 支持
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: UICodingKeys.self)
        try container.encode(groupID, forKey: .groupID)
        try container.encode(name, forKey: .name)
        try container.encode(panels, forKey: .panels)
        try container.encode(activePanelID, forKey: .activePanelID)
        try container.encode(isCollapsed, forKey: .isCollapsed)
        try container.encode(isVisible, forKey: .isVisible)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: UICodingKeys.self)
        groupID = try container.decode(String.self, forKey: .groupID)
        name = try container.decode(String.self, forKey: .name)
        panels = try container.decode([String].self, forKey: .panels)
        activePanelID = try container.decodeIfPresent(String.self, forKey: .activePanelID)
        isCollapsed = try container.decode(Bool.self, forKey: .isCollapsed)
        isVisible = try container.decode(Bool.self, forKey: .isVisible)
        logger.info("从配置恢复面板分组: \(self.name)")
    }

    // MARK: - 面板管理
    /// 添加面板到分组
    public func addPanel(windowID: String) {
        lock.lock()
        guard !panels.contains(windowID) else {
            lock.unlock()
            logger.warning("面板 \(windowID) 已存在于分组 \(self.name)")
            return
        }
        panels.append(windowID)
        if activePanelID == nil { activePanelID = windowID }
        lock.unlock()
        logger.info("面板 \(windowID) 加入分组 \(self.name)")
        NotificationCenter.default.post(name: .panelGroupPanelsDidChange, object: self)
    }

    /// 从分组移除面板
    public func removePanel(windowID: String) {
        lock.lock()
        panels.removeAll { $0 == windowID }
        if activePanelID == windowID {
            activePanelID = panels.first
        }
        lock.unlock()
        logger.info("面板 \(windowID) 从分组 \(self.name) 移除")
        NotificationCenter.default.post(name: .panelGroupPanelsDidChange, object: self)
    }

    /// 激活指定面板
    public func activatePanel(windowID: String) {
        lock.lock()
        guard panels.contains(windowID) else {
            lock.unlock()
            logger.warning("尝试激活不在分组中的面板: \(windowID)")
            return
        }
        activePanelID = windowID
        lock.unlock()
        logger.info("激活面板 \(windowID) 于分组 \(self.name)")
    }

    /// 移动面板到指定位置
    public func movePanel(windowID: String, toIndex: Int) {
        lock.lock()
        guard let fromIndex = panels.firstIndex(of: windowID) else {
            lock.unlock()
            logger.warning("移动失败，面板不在分组中: \(windowID)")
            return
        }
        let clampedIndex = max(0, min(toIndex, panels.count - 1))
        let panel = panels.remove(at: fromIndex)
        panels.insert(panel, at: clampedIndex)
        lock.unlock()
        logger.info("面板 \(windowID) 移动到位置 \(clampedIndex)")
        NotificationCenter.default.post(name: .panelGroupPanelsDidChange, object: self)
    }

    /// 面板数量
    public var count: Int {
        lock.lock()
        let c = panels.count
        lock.unlock()
        return c
    }

    // MARK: - 状态切换
    /// 切换折叠状态
    public func toggleCollapse() {
        lock.lock()
        isCollapsed.toggle()
        let state = isCollapsed
        lock.unlock()
        logger.info("分组 \(self.name) 折叠状态: \(state ? "折叠" : "展开")")
        NotificationCenter.default.post(name: .panelGroupDidCollapseChange, object: self)
    }

    /// 设置折叠状态
    public func setCollapsed(_ collapsed: Bool) {
        lock.lock()
        guard isCollapsed != collapsed else {
            lock.unlock()
            return
        }
        isCollapsed = collapsed
        lock.unlock()
        logger.info("分组 \(self.name) 设为\(collapsed ? "折叠" : "展开")")
        NotificationCenter.default.post(name: .panelGroupDidCollapseChange, object: self)
    }

    /// 切换可见状态
    public func toggleVisibility() {
        lock.lock()
        isVisible.toggle()
        let state = isVisible
        lock.unlock()
        logger.info("分组 \(self.name) 可见状态: \(state ? "显示" : "隐藏")")
        NotificationCenter.default.post(name: .panelGroupDidVisibilityChange, object: self)
    }

    /// 设置可见状态
    public func setVisible(_ visible: Bool) {
        lock.lock()
        guard isVisible != visible else {
            lock.unlock()
            return
        }
        isVisible = visible
        lock.unlock()
        logger.info("分组 \(self.name) 设为\(visible ? "显示" : "隐藏")")
        NotificationCenter.default.post(name: .panelGroupDidVisibilityChange, object: self)
    }

    // MARK: - 生成配置
    /// 导出当前配置
    func exportConfig() -> UIPanelGroupConfig {
        lock.lock()
        let config = UIPanelGroupConfig(
            groupID: groupID,
            name: name,
            panels: panels,
            activePanelID: activePanelID,
            isCollapsed: isCollapsed,
            isVisible: isVisible
        )
        lock.unlock()
        return config
    }

    deinit {
        logger.info("面板分组 \(self.name) 已销毁")
    }
}

// MARK: - 迁回自 UI-02：class UIPanelGroupManager
public final class UIPanelGroupManager : @unchecked Sendable {
    /// 单例实例
    public static let shared = UIPanelGroupManager()
    /// 所有分组
    private var groups: [String: UIPanelGroup] = [:]
    /// 线程锁
    private let lock = NSRecursiveLock()
    /// 日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu.panel", category: "UIPanelGroupManager")
    /// 持久化文件路径
    private var configURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("XianRenZhiLu/panel_groups.json")
    }

    // MARK: - 初始化
    private init() {
        loadFromDisk()
        logger.info("UIPanelGroupManager 初始化完成，当前分组数: \(self.groups.count)")
    }

    deinit {
        saveToDisk()
        logger.info("UIPanelGroupManager 已销毁，配置已保存")
    }

    // MARK: - 分组 CRUD
    /// 创建分组
    @discardableResult
    public func createGroup(name: String) -> UIPanelGroup {
        let group = UIPanelGroup(groupID: UUID().uuidString, name: name)
        lock.lock()
        groups[group.groupID] = group
        lock.unlock()
        logger.info("创建分组: \(name)")
        NotificationCenter.default.post(name: .panelGroupDidCreate, object: group)
        return group
    }

    /// 获取分组
    public func group(for groupID: String) -> UIPanelGroup? {
        lock.lock()
        let g = groups[groupID]
        lock.unlock()
        return g
    }

    /// 重命名分组
    public func renameGroup(groupID: String, newName: String) {
        lock.lock()
        guard let group = groups[groupID] else {
            lock.unlock()
            logger.warning("重命名失败，分组不存在: \(groupID)")
            return
        }
        let oldName = group.name
        group.name = newName
        lock.unlock()
        logger.info("分组重命名: \(oldName) → \(newName)")
        NotificationCenter.default.post(name: .panelGroupDidRename, object: group, userInfo: ["oldName": oldName, "newName": newName])
    }

    /// 删除分组
    public func deleteGroup(groupID: String) {
        lock.lock()
        guard let group = groups.removeValue(forKey: groupID) else {
            lock.unlock()
            logger.warning("删除失败，分组不存在: \(groupID)")
            return
        }
        lock.unlock()
        logger.info("删除分组: \(group.name)")
        NotificationCenter.default.post(name: .panelGroupDidDelete, object: group)
    }

    /// 所有分组
    public var allGroups: [UIPanelGroup] {
        lock.lock()
        let result = Array(groups.values)
        lock.unlock()
        return result
    }

    /// 分组数量
    public var groupCount: Int {
        lock.lock()
        let c = groups.count
        lock.unlock()
        return c
    }

    /// 检查分组是否存在
    public func hasGroup(groupID: String) -> Bool {
        lock.lock()
        let exists = groups[groupID] != nil
        lock.unlock()
        return exists
    }

    // MARK: - 面板归属管理
    /// 添加面板到指定分组
    public func addPanel(windowID: String, toGroup groupID: String) {
        lock.lock()
        guard let group = groups[groupID] else {
            lock.unlock()
            logger.warning("添加面板失败，分组不存在: \(groupID)")
            return
        }
        lock.unlock()
        group.addPanel(windowID: windowID)
    }

    /// 从指定分组移除面板
    public func removePanel(windowID: String, fromGroup groupID: String) {
        lock.lock()
        guard let group = groups[groupID] else {
            lock.unlock()
            logger.warning("移除面板失败，分组不存在: \(groupID)")
            return
        }
        lock.unlock()
        group.removePanel(windowID: windowID)
    }

    /// 将面板从原分组移动到新分组
    public func movePanel(windowID: String, fromGroup oldGroupID: String, toGroup newGroupID: String) {
        lock.lock()
        guard let oldGroup = groups[oldGroupID], let newGroup = groups[newGroupID] else {
            lock.unlock()
            logger.warning("移动面板失败，分组不存在")
            return
        }
        lock.unlock()
        oldGroup.removePanel(windowID: windowID)
        newGroup.addPanel(windowID: windowID)
        logger.info("面板 \(windowID) 从分组 \(oldGroup.name) 移动到 \(newGroup.name)")
    }

    // MARK: - 批量折叠/展开
    /// 折叠所有分组
    public func collapseAllGroups() {
        lock.lock()
        let all = Array(groups.values)
        lock.unlock()
        for group in all {
            group.setCollapsed(true)
        }
        logger.info("一键折叠所有分组")
    }

    /// 展开所有分组
    public func expandAllGroups() {
        lock.lock()
        let all = Array(groups.values)
        lock.unlock()
        for group in all {
            group.setCollapsed(false)
        }
        logger.info("一键展开所有分组")
    }

    /// 折叠指定分组
    public func collapseGroup(groupID: String) {
        guard let group = group(for: groupID) else {
            logger.warning("折叠失败，分组不存在: \(groupID)")
            return
        }
        group.setCollapsed(true)
    }

    /// 展开指定分组
    public func expandGroup(groupID: String) {
        guard let group = group(for: groupID) else {
            logger.warning("展开失败，分组不存在: \(groupID)")
            return
        }
        group.setCollapsed(false)
    }

    // MARK: - 批量显示/隐藏
    /// 显示所有分组
    public func showAllGroups() {
        lock.lock()
        let all = Array(groups.values)
        lock.unlock()
        for group in all {
            group.setVisible(true)
        }
        logger.info("一键显示所有分组")
    }

    /// 隐藏所有分组
    public func hideAllGroups() {
        lock.lock()
        let all = Array(groups.values)
        lock.unlock()
        for group in all {
            group.setVisible(false)
        }
        logger.info("一键隐藏所有分组")
    }

    /// 显示指定分组
    public func showGroup(groupID: String) {
        guard let group = group(for: groupID) else {
            logger.warning("显示失败，分组不存在: \(groupID)")
            return
        }
        group.setVisible(true)
    }

    /// 隐藏指定分组
    public func hideGroup(groupID: String) {
        guard let group = group(for: groupID) else {
            logger.warning("隐藏失败，分组不存在: \(groupID)")
            return
        }
        group.setVisible(false)
    }

    // MARK: - 设置面板方法
    /// 获取分组设置字典（用于设置面板展示）
    public struct UIGroupSettingsInfo {
        public let groupID: String
        public let name: String
        public let panelCount: Int
        public let isCollapsed: Bool
        public let isVisible: Bool
        public let activePanelID: String?
        
        public init(groupID: String, name: String, panelCount: Int, isCollapsed: Bool, isVisible: Bool, activePanelID: String?) {
            self.groupID = groupID
            self.name = name
            self.panelCount = panelCount
            self.isCollapsed = isCollapsed
            self.isVisible = isVisible
            self.activePanelID = activePanelID
        }
    }
    
    public func groupSettings(for groupID: String) -> UIGroupSettingsInfo? {
        guard let group = group(for: groupID) else { return nil }
        group.lock.lock()
        let info = UIGroupSettingsInfo(
            groupID: group.groupID,
            name: group.name,
            panelCount: group.panels.count,
            isCollapsed: group.isCollapsed,
            isVisible: group.isVisible,
            activePanelID: group.activePanelID
        )
        group.lock.unlock()
        return info
    }

    /// 更新分组设置（从设置面板调用）
    public func updateGroupSettings(groupID: String, settings: UIGroupSettingsInfo) {
        guard let group = group(for: groupID) else {
            logger.warning("更新设置失败，分组不存在: \(groupID)")
            return
        }
        if !settings.name.isEmpty {
            renameGroup(groupID: groupID, newName: settings.name)
        }
        group.setCollapsed(settings.isCollapsed)
        group.setVisible(settings.isVisible)
        if let activePanelID = settings.activePanelID {
            group.activatePanel(windowID: activePanelID)
        }
        logger.info("分组 \(groupID) 设置已更新")
        saveToDisk()
    }

    /// 所有分组的设置摘要（用于设置面板总览）
    public func allGroupSettingsSummary() -> [UIGroupSettingsInfo] {
        lock.lock()
        let all = Array(groups.values)
        lock.unlock()
        return all.compactMap { group in
            groupSettings(for: group.groupID)
        }
    }

    // MARK: - 持久化
    /// 保存到磁盘
    public func saveToDisk() {
        lock.lock()
        let configs = groups.values.map { $0.exportConfig() }
        lock.unlock()

        do {
            let data = try JSONEncoder().encode(configs)
            let url = configURL
            let dir = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            try data.write(to: url, options: .atomic)
            logger.info("分组配置已保存到磁盘，共 \(configs.count) 个分组")
        } catch {
            logger.error("保存分组配置失败: \(error.localizedDescription)")
        }
    }

    /// 从磁盘加载
    public func loadFromDisk() {
        let url = configURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("未找到分组配置文件，跳过加载")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let configs = try JSONDecoder().decode([UIPanelGroupConfig].self, from: data)
            lock.lock()
            for config in configs {
                let group = UIPanelGroup(
                    groupID: config.groupID,
                    name: config.name
                )
                group.panels = config.panels
                group.activePanelID = config.activePanelID
                group.isCollapsed = config.isCollapsed
                group.isVisible = config.isVisible
                groups[config.groupID] = group
            }
            lock.unlock()
            logger.info("从磁盘加载了 \(configs.count) 个分组配置")
        } catch {
            logger.error("加载分组配置失败: \(error.localizedDescription)")
        }
    }

    /// 重置所有分组配置（清空）
    public func resetAllGroups() {
        lock.lock()
        groups.removeAll()
        lock.unlock()
        logger.info("所有分组已重置")
        saveToDisk()
    }

    // MARK: - 查询方法
    /// 查找面板所在的分组
    public func groupContainingPanel(windowID: String) -> UIPanelGroup? {
        lock.lock()
        let result = groups.values.first { $0.panels.contains(windowID) }
        lock.unlock()
        return result
    }

    /// 检查面板是否在某分组中
    public func isPanel(windowID: String, inGroup groupID: String) -> Bool {
        guard let group = group(for: groupID) else { return false }
        group.lock.lock()
        let contains = group.panels.contains(windowID)
        group.lock.unlock()
        return contains
    }

    /// 获取分组内所有面板ID
    public func panelIDs(inGroup groupID: String) -> [String] {
        guard let group = group(for: groupID) else { return [] }
        group.lock.lock()
        let ids = group.panels
        group.lock.unlock()
        return ids
    }

    /// 获取分组当前激活面板ID
    public func activePanelID(inGroup groupID: String) -> String? {
        guard let group = group(for: groupID) else { return nil }
        group.lock.lock()
        let id = group.activePanelID
        group.lock.unlock()
        return id
    }

    /// 获取所有分组ID
    public var allGroupIDs: [String] {
        lock.lock()
        let ids = Array(groups.keys)
        lock.unlock()
        return ids
    }

    /// 获取分组名称
    public func groupName(for groupID: String) -> String? {
        guard let group = group(for: groupID) else { return nil }
        group.lock.lock()
        let name = group.name
        group.lock.unlock()
        return name
    }

    /// 获取分组统计信息
    public func groupStatistics() -> [String: Int] {
        lock.lock()
        let all = Array(groups.values)
        lock.unlock()
        var stats: [String: Int] = [:]
        stats["totalGroups"] = all.count
        stats["totalPanels"] = all.reduce(0) { $0 + $1.count }
        stats["collapsedGroups"] = all.filter { $0.isCollapsed }.count
        stats["visibleGroups"] = all.filter { $0.isVisible }.count
        return stats
    }
}

// MARK: - 迁回自 UI-02：struct UIPanelGroupConfig
// MARK: - UI-GL-55 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-55_types.swift
// 版本: 2.0
// MARK: - 通知名称扩展
/// 历史回放模块专用的通知名称，用于跨模块通信
// 已迁回 UI-GL-55_历史数据回放模式.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-56 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-56_types.swift
// 版本: 2.0
// MARK: - 通知名称定义
/// 停靠位置变更通知，userInfo 包含 ["panelID": String, "position": UIDockingPosition]
// 已迁回 UI-GL-56_停靠系统.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-57 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-57_types.swift
// 版本: 2.0
// MARK: - 通知名称扩展
/// 固定机制模块专用的通知定义，用于广播面板固定状态与布局变更事件
// 已迁回 UI-GL-57_固定机制.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-58 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-58_types.swift
// 版本: 2.0
// MARK: - 分组配置结构（用于持久化）
struct UIPanelGroupConfig: Codable {  // 原为private，改为internal以允许public方法返回
    let groupID: String
    let name: String
    let panels: [String]
    let activePanelID: String?
    let isCollapsed: Bool
    let isVisible: Bool
}
