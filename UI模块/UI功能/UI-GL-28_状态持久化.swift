// 功能20: 状态持久化
// 对应: 保存/恢复工作区布局：窗口位置、打开哪些模块、当前品种、颜色方案
// 优先级: P1

import AppKit
import Foundation
import os.log

// MARK: - 通知名称
/// 状态持久化相关通知
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：extension Notification.Name {

// MARK: - 工作区状态持久化管理器
// UIWorkspaceManager 已迁移到临时类型文件，后续合并进 UI-02。

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能20：状态持久化 — 单元测试
/// 覆盖：保存/恢复/快照/自动保存/导出导入
func test_persistence() {
    let manager = UIWorkspaceManager.shared
    
    print("\n🧪 测试1: 保存工作区")
    manager.saveCurrentState(
        layoutName: "测试工作区",
        symbol: "BTC/USDT",
        period: "1h",
        colorScheme: "默认",
        windowStates: [:],
        moduleStates: [:],
        dockedPanels: [:],
        openModuleNames: ["图表", "交易"],
        globalSettings: ["theme": "dark"]
    )
    let names = manager.savedWorkspaceNames
    guard names.contains("测试工作区") else {
        fatalError("❌ 测试1失败: 保存后应能找到工作区")
    }
    print("✅ 测试1通过: 工作区保存成功")
    
    print("\n🧪 测试2: 恢复工作区")
    let layout = manager.restoreState(name: "测试工作区")
    guard layout?.symbol == "BTC/USDT" else {
        fatalError("❌ 测试2失败: 恢复后品种应正确")
    }
    print("✅ 测试2通过: 工作区恢复成功")
    
    print("\n🧪 测试3: 创建快照")
    let snapCreated = manager.createSnapshot(name: "测试快照", description: "用于测试")
    guard snapCreated else {
        fatalError("❌ 测试3失败: 快照创建失败")
    }
    print("✅ 测试3通过: 快照创建成功")
    
    print("\n🧪 测试4: 列举快照")
    let snapshots = manager.listSnapshots()
    guard snapshots.contains(where: { $0.name == "测试快照" }) else {
        fatalError("❌ 测试4失败: 应能找到创建的快照")
    }
    print("✅ 测试4通过: 快照列举成功")
    
    print("\n🧪 测试5: 重命名快照")
    let renamed = manager.renameSnapshot(oldName: "测试快照", newName: "重命名快照")
    guard renamed else {
        fatalError("❌ 测试5失败: 重命名失败")
    }
    print("✅ 测试5通过: 快照重命名成功")
    
    print("\n🧪 测试6: 删除快照")
    let deleted = manager.deleteSnapshot(name: "重命名快照")
    guard deleted else {
        fatalError("❌ 测试6失败: 删除快照失败")
    }
    print("✅ 测试6通过: 快照删除成功")
    
    print("\n🧪 测试7: 自动保存开关")
    manager.startAutoSave(interval: 600)
    guard manager.isAutoSaveActive else {
        fatalError("❌ 测试7失败: 自动保存应已启动")
    }
    manager.stopAutoSave()
    guard !manager.isAutoSaveActive else {
        fatalError("❌ 测试7失败: 自动保存应已停止")
    }
    print("✅ 测试7通过: 自动保存开关正常")
    
    print("\n🧪 测试8: 设置面板数据")
    let data = manager.settingsPanelData()
    guard data.workspaceCount >= 1 else {
        fatalError("❌ 测试8失败: 应有至少1个工作区")
    }
    print("✅ 测试8通过: 设置面板数据正确")
    
    print("\n🧪 测试9: 删除工作区")
    let worksDeleted = manager.deleteWorkspace(name: "测试工作区")
    guard worksDeleted else {
        fatalError("❌ 测试9失败: 删除工作区失败")
    }
    print("✅ 测试9通过: 工作区删除成功")
    
    print("\n=== 全部状态持久化测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWorkspaceManager
public final class UIWorkspaceManager : @unchecked Sendable {

    public static let shared = UIWorkspaceManager()

    // MARK: 日志
    private let logger = Logger(
        subsystem: "com.xianrenzhilu",
        category: "状态持久化"
    )

    // MARK: 锁
    private let lock = NSRecursiveLock()

    // MARK: 存储
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let saveKey = "com.xianrenzhilu.workspaceLayout"
    private let snapshotDirectoryName = "WorkspaceSnapshots"

    // MARK: 自动保存
    private nonisolated(unsafe) var autoSaveTimer: Timer?
    private nonisolated(unsafe) var debounceTimer: Timer?
    private var autoSaveInterval: TimeInterval = 300.0  // 默认 5 分钟
    private var isAutoSaveEnabled: Bool = true
    private var debounceInterval: TimeInterval = 2.0    // 默认 2 秒

    // MARK: 当前状态缓存
    private var currentLayout: UIWorkspaceLayout?
    private var lastSavedDate: Date?

    // MARK: 初始化
    private init() {
        self.defaults = UserDefaults.standard
        self.fileManager = FileManager.default
        self.ensureSnapshotDirectoryExists()
        self.registerTerminationObserver()
        self.logger.info("工作区管理器初始化完成")
    }

    deinit {
        stopAutoSave()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 锁辅助方法
    /// 在锁保护下执行操作
    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    // MARK: - 目录管理
    /// 确保快照目录存在
    private func ensureSnapshotDirectoryExists() {
        let url = snapshotDirectoryURL()
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                logger.info("快照目录创建成功: \(url.path)")
            } catch {
                logger.error("快照目录创建失败: \(error.localizedDescription)")
            }
        }
    }

    /// 快照目录 URL
    private func snapshotDirectoryURL() -> URL {
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("XianRenZhiLu")
            .appendingPathComponent(snapshotDirectoryName)
    }

    /// 快照文件 URL
    private func snapshotFileURL(name: String) -> URL {
        return snapshotDirectoryURL().appendingPathComponent("\(name).json")
    }

    // MARK: - 保存当前工作区
    /// 保存当前工作区状态（从外部传入数据，不依赖外部类）
    public func saveCurrentState(
        layoutName: String,
        symbol: String,
        period: String,
        colorScheme: String,
        windowStates: [String: UIPersistentWindowStateModel],
        moduleStates: [String: UIModuleStateModel],
        dockedPanels: [String: UIDockedPanelStateModel],
        openModuleNames: [String],
        globalSettings: [String: String]
    ) {
        var layout = UIWorkspaceLayout(layoutName: layoutName)
        layout.timestamp = Date()
        layout.symbol = symbol
        layout.period = period
        layout.colorScheme = colorScheme
        layout.windowStates = windowStates
        layout.moduleStates = moduleStates
        layout.dockedPanels = dockedPanels
        layout.openModuleNames = openModuleNames
        layout.globalSettings = globalSettings

        do {
            let data = try JSONEncoder().encode(layout)
            let key = "\(saveKey).\(layoutName)"

            withLock {
                defaults.set(data, forKey: key)
                currentLayout = layout
                lastSavedDate = Date()
            }

            logger.info("工作区已保存: \(layoutName)")
            NotificationCenter.default.post(
                name: .workspaceSaved,
                object: self,
                userInfo: ["layoutName": layoutName, "timestamp": layout.timestamp]
            )
        } catch {
            logger.error("工作区保存失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 恢复工作区
    /// 加载工作区布局
    public func restoreState(name: String) -> UIWorkspaceLayout? {
        let key = "\(saveKey).\(name)"
        let data: Data? = withLock {
            return defaults.data(forKey: key)
        }

        guard let data = data else {
            logger.warning("未找到工作区: \(name)")
            return nil
        }

        do {
            let layout = try JSONDecoder().decode(UIWorkspaceLayout.self, from: data)
            withLock {
                currentLayout = layout
            }
            logger.info("工作区已恢复: \(name)")
            NotificationCenter.default.post(
                name: .workspaceRestored,
                object: self,
                userInfo: ["layoutName": name, "layout": layout]
            )
            return layout
        } catch {
            logger.error("工作区恢复失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 列举已保存工作区
    /// 获取所有已保存的工作区名称
    public var savedWorkspaceNames: [String] {
        let allKeys: [String] = withLock {
            return Array(defaults.dictionaryRepresentation().keys)
        }
        let names = allKeys
            .filter { $0.hasPrefix(saveKey + ".") }
            .map { String($0.dropFirst(saveKey.count + 1)) }
        return names.sorted()
    }

    // MARK: - 删除工作区
    /// 删除指定工作区
    public func deleteWorkspace(name: String) -> Bool {
        let key = "\(saveKey).\(name)"
        let exists: Bool = withLock {
            return defaults.object(forKey: key) != nil
        }

        guard exists else {
            logger.warning("删除失败，工作区不存在: \(name)")
            return false
        }

        withLock {
            defaults.removeObject(forKey: key)
            if currentLayout?.layoutName == name {
                currentLayout = nil
            }
        }
        logger.info("工作区已删除: \(name)")
        return true
    }

    // MARK: - 快照管理
    /// 创建快照（复制当前布局到快照目录）
    public func createSnapshot(name: String, description: String? = nil) -> Bool {
        guard !name.isEmpty else {
            logger.error("快照名称不能为空")
            return false
        }

        let fileURL = snapshotFileURL(name: name)
        let layout: UIWorkspaceLayout? = withLock { currentLayout }

        guard var targetLayout = layout else {
            logger.error("创建快照失败：没有当前工作区状态")
            return false
        }

        targetLayout.layoutName = name
        targetLayout.timestamp = Date()

        do {
            let data = try JSONEncoder().encode(targetLayout)
            try data.write(to: fileURL, options: [.atomic])

            let snapshotInfo = UISnapshotInfo(name: name, createdAt: Date(), description: description)
            let infoData = try JSONEncoder().encode(snapshotInfo)
            let infoURL = snapshotDirectoryURL().appendingPathComponent("\(name).info.json")
            try infoData.write(to: infoURL, options: [.atomic])

            logger.info("快照已创建: \(name)")
            NotificationCenter.default.post(
                name: .snapshotCreated,
                object: self,
                userInfo: ["name": name, "description": description ?? ""]
            )
            return true
        } catch {
            logger.error("快照创建失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 列举所有快照
    public func listSnapshots() -> [UISnapshotInfo] {
        let snapshotDir = snapshotDirectoryURL()
        let files: [String]
        do {
            files = try fileManager.contentsOfDirectory(atPath: snapshotDir.path)
        } catch {
            logger.error("读取快照目录失败: \(error.localizedDescription)")
            return []
        }

        var snapshots: [UISnapshotInfo] = []
        for file in files where file.hasSuffix(".info.json") {
            let name = String(file.dropLast(".info.json".count))
            let infoURL = snapshotDir.appendingPathComponent(file)
            do {
                let data = try Data(contentsOf: infoURL)
                let info = try JSONDecoder().decode(UISnapshotInfo.self, from: data)
                snapshots.append(info)
            } catch {
                logger.warning("读取快照信息失败: \(name), 错误: \(error.localizedDescription)")
            }
        }
        return snapshots.sorted { $0.createdAt > $1.createdAt }
    }

    /// 删除快照
    public func deleteSnapshot(name: String) -> Bool {
        let fileURL = snapshotFileURL(name: name)
        let infoURL = snapshotDirectoryURL().appendingPathComponent("\(name).info.json")

        let exists = fileManager.fileExists(atPath: fileURL.path)

        guard exists else {
            logger.warning("删除快照失败，不存在: \(name)")
            return false
        }

        do {
            try fileManager.removeItem(at: fileURL)
            if fileManager.fileExists(atPath: infoURL.path) {
                try fileManager.removeItem(at: infoURL)
            }
            logger.info("快照已删除: \(name)")
            NotificationCenter.default.post(
                name: .snapshotDeleted,
                object: self,
                userInfo: ["name": name]
            )
            return true
        } catch {
            logger.error("快照删除失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 重命名快照
    public func renameSnapshot(oldName: String, newName: String) -> Bool {
        guard !newName.isEmpty else {
            logger.error("新名称不能为空")
            return false
        }

        let oldFileURL = snapshotFileURL(name: oldName)
        let oldInfoURL = snapshotDirectoryURL().appendingPathComponent("\(oldName).info.json")
        let newFileURL = snapshotFileURL(name: newName)
        let newInfoURL = snapshotDirectoryURL().appendingPathComponent("\(newName).info.json")

        let exists = fileManager.fileExists(atPath: oldFileURL.path)

        guard exists else {
            logger.warning("重命名快照失败，源快照不存在: \(oldName)")
            return false
        }

        do {
            try fileManager.moveItem(at: oldFileURL, to: newFileURL)
            if fileManager.fileExists(atPath: oldInfoURL.path) {
                try fileManager.moveItem(at: oldInfoURL, to: newInfoURL)
            }

            // 更新 info 文件中的名称
            if fileManager.fileExists(atPath: newInfoURL.path) {
                do {
                    let data = try Data(contentsOf: newInfoURL)
                    var info = try JSONDecoder().decode(UISnapshotInfo.self, from: data)
                    info.name = newName
                    let updatedData = try JSONEncoder().encode(info)
                    try updatedData.write(to: newInfoURL, options: [.atomic])
                } catch {
                    logger.warning("更新快照信息失败: \(error.localizedDescription)")
                }
            }

            logger.info("快照已重命名: \(oldName) -> \(newName)")
            NotificationCenter.default.post(
                name: .snapshotRenamed,
                object: self,
                userInfo: ["oldName": oldName, "newName": newName]
            )
            return true
        } catch {
            logger.error("快照重命名失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 从快照恢复工作区
    public func restoreFromSnapshot(name: String) -> UIWorkspaceLayout? {
        let fileURL = snapshotFileURL(name: name)
        let exists = fileManager.fileExists(atPath: fileURL.path)

        guard exists else {
            logger.warning("恢复快照失败，不存在: \(name)")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let layout = try JSONDecoder().decode(UIWorkspaceLayout.self, from: data)
            withLock {
                currentLayout = layout
            }
            logger.info("已从快照恢复: \(name)")
            NotificationCenter.default.post(
                name: .workspaceRestored,
                object: self,
                userInfo: ["layoutName": name, "source": "snapshot", "layout": layout]
            )
            return layout
        } catch {
            logger.error("恢复快照失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 导出/导入 JSON
    /// 导出工作区布局到 JSON 文件
    public func exportToJSON(name: String, to url: URL) -> Bool {
        let key = "\(saveKey).\(name)"
        let data: Data? = withLock {
            return defaults.data(forKey: key)
        }

        guard let data = data else {
            logger.warning("导出失败，未找到工作区: \(name)")
            return false
        }

        do {
            try data.write(to: url, options: [.atomic])
            logger.info("工作区已导出到: \(url.path)")
            return true
        } catch {
            logger.error("导出失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 从 JSON 文件导入工作区布局
    public func importFromJSON(from url: URL) -> UIWorkspaceLayout? {
        do {
            let data = try Data(contentsOf: url)
            let layout = try JSONDecoder().decode(UIWorkspaceLayout.self, from: data)
            let key = "\(saveKey).\(layout.layoutName)"

            withLock {
                defaults.set(data, forKey: key)
                currentLayout = layout
                lastSavedDate = Date()
            }

            logger.info("工作区已导入: \(layout.layoutName)")
            return layout
        } catch {
            logger.error("导入失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 自动保存
    /// 启动自动保存定时器
    public func startAutoSave(interval: TimeInterval = 300.0) {
        stopAutoSave()

        withLock {
            autoSaveInterval = interval
            isAutoSaveEnabled = true
        }

        autoSaveTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            self.performAutoSave()
        }

        logger.info("自动保存已启动，间隔: \(interval) 秒")
    }

    /// 停止自动保存
    public func stopAutoSave() {
        withLock {
            autoSaveTimer?.invalidate()
            autoSaveTimer = nil
            isAutoSaveEnabled = false
        }
        logger.info("自动保存已停止")
    }

    /// 执行自动保存（需要外部提供当前状态数据）
    public func performAutoSave(
        layoutName: String = "自动保存",
        symbol: String = "BTC/USDT",
        period: String = "1h",
        colorScheme: String = "默认",
        windowStates: [String: UIPersistentWindowStateModel] = [:],
        moduleStates: [String: UIModuleStateModel] = [:],
        dockedPanels: [String: UIDockedPanelStateModel] = [:],
        openModuleNames: [String] = [],
        globalSettings: [String: String] = [:]
    ) {
        saveCurrentState(
            layoutName: layoutName,
            symbol: symbol,
            period: period,
            colorScheme: colorScheme,
            windowStates: windowStates,
            moduleStates: moduleStates,
            dockedPanels: dockedPanels,
            openModuleNames: openModuleNames,
            globalSettings: globalSettings
        )

        NotificationCenter.default.post(
            name: .autoSaveTriggered,
            object: self,
            userInfo: ["layoutName": layoutName, "timestamp": Date()]
        )
        logger.info("自动保存已执行")
    }

    // MARK: - 延迟保存（Debounce）
    /// 触发延迟保存（防抖，防止频繁写入）
    public func debouncedSave(
        layoutName: String,
        symbol: String,
        period: String,
        colorScheme: String,
        windowStates: [String: UIPersistentWindowStateModel],
        moduleStates: [String: UIModuleStateModel],
        dockedPanels: [String: UIDockedPanelStateModel],
        openModuleNames: [String],
        globalSettings: [String: String]
    ) {
        // 取消之前的 debounce 定时器
        withLock {
            debounceTimer?.invalidate()
        }

        // 创建新的 debounce 定时器
        let timer = Timer.scheduledTimer(
            withTimeInterval: debounceInterval,
            repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }
            self.saveCurrentState(
                layoutName: layoutName,
                symbol: symbol,
                period: period,
                colorScheme: colorScheme,
                windowStates: windowStates,
                moduleStates: moduleStates,
                dockedPanels: dockedPanels,
                openModuleNames: openModuleNames,
                globalSettings: globalSettings
            )
        }

        withLock {
            debounceTimer = timer
        }

        logger.debug("延迟保存已触发，将在 \(self.debounceInterval) 秒后执行")
    }

    /// 取消待执行的延迟保存
    public func cancelDebouncedSave() {
        withLock {
            debounceTimer?.invalidate()
            debounceTimer = nil
        }
        logger.debug("延迟保存已取消")
    }

    // MARK: - 应用退出前保存
    /// 注册应用终止通知观察者
    private func registerTerminationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    /// 应用退出前自动保存
    @objc private func applicationWillTerminate() {
        logger.info("应用即将退出，执行最终保存")
        // 如果有当前布局，尝试保存
        let layout: UIWorkspaceLayout? = withLock {
            return currentLayout
        }
        if let layout = layout {
            saveCurrentState(
                layoutName: layout.layoutName,
                symbol: layout.symbol,
                period: layout.period,
                colorScheme: layout.colorScheme,
                windowStates: layout.windowStates,
                moduleStates: layout.moduleStates,
                dockedPanels: layout.dockedPanels,
                openModuleNames: layout.openModuleNames,
                globalSettings: layout.globalSettings
            )
        }
    }

    // MARK: - 设置面板数据
    /// 返回设置面板所需的数据字典
    public func settingsPanelData() -> UIPersistenceSettingsData {
        let snapshots = listSnapshots()
        let snapshotNames = snapshots.map { $0.name }
        let workspaceNames = savedWorkspaceNames

        let layoutName: String? = withLock { currentLayout?.layoutName }
        let lastSaved: Date? = withLock { lastSavedDate }
        let autoSaveEnabled: Bool = withLock { isAutoSaveEnabled }
        let autoSaveIntervalValue: TimeInterval = withLock { autoSaveInterval }

        return UIPersistenceSettingsData(
            autoSaveEnabled: autoSaveEnabled,
            autoSaveInterval: autoSaveIntervalValue,
            debounceInterval: debounceInterval,
            snapshots: snapshotNames,
            workspaces: workspaceNames,
            version: "2.0",
            snapshotCount: snapshots.count,
            workspaceCount: workspaceNames.count,
            currentLayout: layoutName,
            lastSaved: lastSaved
        )
    }

    // MARK: - 配置读写
    /// 设置自动保存间隔
    public func setAutoSaveInterval(_ interval: TimeInterval) {
        withLock {
            autoSaveInterval = interval
        }
        if isAutoSaveEnabled {
            startAutoSave(interval: interval)
        }
        logger.info("自动保存间隔已设置为: \(interval) 秒")
    }

    /// 获取自动保存间隔
    public var currentAutoSaveInterval: TimeInterval {
        return withLock {
            return autoSaveInterval
        }
    }

    /// 设置是否启用自动保存
    public func setAutoSaveEnabled(_ enabled: Bool) {
        withLock {
            isAutoSaveEnabled = enabled
        }
        if enabled {
            let interval = withLock { autoSaveInterval }
            startAutoSave(interval: interval)
        } else {
            stopAutoSave()
        }
        logger.info("自动保存已\(enabled ? "启用" : "禁用")")
    }

    /// 获取当前是否启用自动保存
    public var isAutoSaveActive: Bool {
        return withLock {
            return isAutoSaveEnabled && autoSaveTimer != nil
        }
    }

    /// 设置防抖间隔
    public func setDebounceInterval(_ interval: TimeInterval) {
        withLock {
            debounceInterval = interval
        }
        logger.info("防抖间隔已设置为: \(interval) 秒")
    }

    /// 获取当前防抖间隔
    public var currentDebounceInterval: TimeInterval {
        return withLock {
            return debounceInterval
        }
    }

    // MARK: - 当前状态访问
    /// 获取当前缓存的布局
    public var cachedLayout: UIWorkspaceLayout? {
        return withLock {
            return currentLayout
        }
    }

    /// 获取最后保存时间
    public var lastSavedTimestamp: Date? {
        return withLock {
            return lastSavedDate
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIPersistentWindowStateModel
// MARK: - UI-GL-28 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-28_types.swift
// 版本: 2.0
// MARK: - 数据结构

/// 窗口状态模型（完全自包含，不依赖外部类）
public struct UIPersistentWindowStateModel: Codable, Equatable {
    public var windowID: String
    public var frame: CGRect
    public var isVisible: Bool
    public var isMainWindow: Bool
    public var screenIdentifier: String?
    public var isFullScreen: Bool
    public var isMiniaturized: Bool

    public init(
        windowID: String,
        frame: CGRect,
        isVisible: Bool,
        isMainWindow: Bool,
        screenIdentifier: String?,
        isFullScreen: Bool = false,
        isMiniaturized: Bool = false
    ) {
        self.windowID = windowID
        self.frame = frame
        self.isVisible = isVisible
        self.isMainWindow = isMainWindow
        self.screenIdentifier = screenIdentifier
        self.isFullScreen = isFullScreen
        self.isMiniaturized = isMiniaturized
    }
}

// MARK: - 迁回自 UI-02：struct UIModuleStateModel
// MARK: - 窗口分组管理器
/// 窗口分组管理器
/// 功能：
///   - 窗口分组（将多个窗口关联为一个组）
///   - 组操作（统一移动/缩放/最小化/关闭）
///   - 组排列布局（平铺、层叠、堆栈等）
///   - 组锁（锁定组关系，防止意外解散）
///   - 组标签/命名（名称和标签颜色）
///   - 组悬浮模式（整个组置顶）
///   - 组透明度联动（统一调整）
///   - 组保存/加载（UserDefaults持久化）
///   - 组热键（快捷键一键激活）
///   - 组通知（操作时发出通知）
/// 线程安全：所有公开API使用 NSRecursiveLock 保护
// 已迁回 UI-GL-27_窗口分组管理.swift：class UIWindowGroupManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-28 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-28_types.swift
// 版本: 2.0
/// 模块状态模型
public struct UIModuleStateModel: Codable, Equatable {
    public var moduleName: String
    public var windowID: String?
    public var position: CGPoint?
    public var size: CGSize?
    public var isVisible: Bool
    public var configuration: [String: String]
    public var zIndex: Int

    public init(
        moduleName: String,
        windowID: String?,
        position: CGPoint?,
        size: CGSize?,
        isVisible: Bool,
        configuration: [String: String],
        zIndex: Int = 0
    ) {
        self.moduleName = moduleName
        self.windowID = windowID
        self.position = position
        self.size = size
        self.isVisible = isVisible
        self.configuration = configuration
        self.zIndex = zIndex
    }
}

// MARK: - 迁回自 UI-02：struct UIDockedPanelStateModel
/// 停靠面板状态
public struct UIDockedPanelStateModel: Codable, Equatable {
    public var panelID: String
    public var position: String
    public var width: CGFloat?
    public var height: CGFloat?
    public var isCollapsed: Bool
    public var isVisible: Bool

    public init(
        panelID: String,
        position: String,
        width: CGFloat?,
        height: CGFloat?,
        isCollapsed: Bool,
        isVisible: Bool = true
    ) {
        self.panelID = panelID
        self.position = position
        self.width = width
        self.height = height
        self.isCollapsed = isCollapsed
        self.isVisible = isVisible
    }
}

// MARK: - 迁回自 UI-02：struct UISnapshotInfo
/// 快照元数据
public struct UISnapshotInfo: Codable, Identifiable, Equatable {
    public var id: String { name }
    public var name: String
    public var createdAt: Date
    public var description: String?

    public init(name: String, createdAt: Date, description: String?) {
        self.name = name
        self.createdAt = createdAt
        self.description = description
    }
}

// MARK: - 迁回自 UI-02：struct UIWorkspaceLayoutStruct
/// 完整工作区布局
public struct UIWorkspaceLayoutStruct: Codable, Equatable {
    public var version: String
    public var timestamp: Date
    public var layoutName: String
    public var symbol: String
    public var period: String
    public var colorScheme: String
    public var windowStates: [String: UIPersistentWindowStateModel]
    public var moduleStates: [String: UIModuleStateModel]
    public var dockedPanels: [String: UIDockedPanelStateModel]
    public var openModuleNames: [String]
    public var globalSettings: [String: String]

    public init(layoutName: String) {
        self.version = "2.0"
        self.timestamp = Date()
        self.layoutName = layoutName
        self.symbol = "BTC/USDT"
        self.period = "1h"
        self.colorScheme = "默认"
        self.windowStates = [:]
        self.moduleStates = [:]
        self.dockedPanels = [:]
        self.openModuleNames = []
        self.globalSettings = [:]
    }
}

// MARK: - 迁回自 UI-02：struct UIPersistenceSettingsData
// MARK: - 设置面板数据结构
/// 状态持久化设置面板数据
public struct UIPersistenceSettingsData {
    public let autoSaveEnabled: Bool
    public let autoSaveInterval: TimeInterval
    public let debounceInterval: TimeInterval
    public let snapshots: [String]
    public let workspaces: [String]
    public let version: String
    public let snapshotCount: Int
    public let workspaceCount: Int
    public let currentLayout: String?
    public let lastSaved: Date?
}
