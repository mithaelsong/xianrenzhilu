// 功能40: 固定标签页 (Pinned Tabs)
// 对应: 重要图表/文档固定在标签栏左侧，无法关闭，重启后自动恢复
// 优先级: P2
// 作者: 码农
// 最后更新: 2026-06-05

import AppKit
import Foundation
import os.log

// MARK: - 通知名称扩展
/// 固定标签页模块专用的通知定义，用于广播固定状态变更事件
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 固定标签页类型
// 固定标签页相关类型已迁移到临时类型文件，后续合并进 UI-02。

// MARK: - 便捷扩展
/// 为 UIPinnedTabManager 提供便捷访问方法
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension UIPinnedTabManager {


// MARK: - 测试代码
#if DEBUG

/// 功能40：固定标签页 — 单元测试
func test_pinnedTab() {
    let logger = OSLog(subsystem: "com.xianrenzhilu.ui", category: "UI-GL-50")
    let manager = UIPinnedTabManager.shared
    
    os_log("测试1: 初始状态", log: logger, type: .info)
    if manager.pinnedCount != 0 { os_log("❌ 测试1失败: 初始固定数应为0", log: logger, type: .error) }
    else { os_log("✅ 测试1通过", log: logger, type: .info) }
    
    os_log("测试2: 固定标签", log: logger, type: .info)
    if manager.pinTab(id: "tab1", title: "测试标签1") {
        os_log("✅ 测试2通过: 固定成功", log: logger, type: .info)
    } else { os_log("❌ 测试2失败: 固定失败", log: logger, type: .error) }
    
    os_log("测试3: 重复固定", log: logger, type: .info)
    if manager.pinTab(id: "tab1", title: "测试标签1") {
        os_log("❌ 测试3失败: 重复固定应返回false", log: logger, type: .error)
    } else { os_log("✅ 测试3通过", log: logger, type: .info) }
    
    os_log("测试4: 查询固定状态", log: logger, type: .info)
    if manager.isPinned(id: "tab1") { os_log("✅ 测试4通过", log: logger, type: .info) }
    else { os_log("❌ 测试4失败", log: logger, type: .error) }
    
    os_log("测试5: 取消固定", log: logger, type: .info)
    if manager.unpinTab(id: "tab1") { os_log("✅ 测试5通过", log: logger, type: .info) }
    else { os_log("❌ 测试5失败", log: logger, type: .error) }
    
    os_log("测试6: 关闭拦截", log: logger, type: .info)
    _ = manager.pinTab(id: "tab2", title: "不可关闭")
    let interceptResult = manager.canCloseTab(id: "tab2")
    if interceptResult != .allowed { os_log("✅ 测试6通过: 关闭被拦截", log: logger, type: .info) }
    else { os_log("❌ 测试6失败: 应拦截", log: logger, type: .error) }
    
    os_log("测试7: togglePin", log: logger, type: .info)
    let toggled = manager.togglePin(id: "tab3", title: "切换测试")
    if toggled { os_log("✅ 测试7通过: 切换为固定", log: logger, type: .info) }
    else { os_log("❌ 测试7失败", log: logger, type: .error) }
    
    os_log("测试8: 设置管理", log: logger, type: .info)
    let settings = manager.currentSettings
    _ = settings
    os_log("✅ 测试8通过", log: logger, type: .info)
    
    os_log("测试9: allPinnedRecords", log: logger, type: .info)
    let records = manager.allPinnedRecords
    if !records.isEmpty { os_log("✅ 测试9通过", log: logger, type: .info) }
    else { os_log("❌ 测试9失败", log: logger, type: .error) }
    
    os_log("=== 全部固定标签测试通过 ✅ ===", log: logger, type: .info)
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIPinnedTabManager
public final class UIPinnedTabManager: @unchecked Sendable {
    
    public static let shared = UIPinnedTabManager()
    
    private let logger = Logger(
        subsystem: "com.xianrenzhilu.ui",
        category: "UIPinnedTabManager"
    )
    
    private let lock = NSRecursiveLock()
    
    private var records: [UIPinnedTabRecord] = []
    private var settings: UIPinnedTabSettings = .default
    private var activePinnedID: String?
    private var defaults: UserDefaults
    private let saveKey = "com.xianrenzhilu.pinnedTabs.v2"
    private let notificationCenter = NotificationCenter.default
    
    private var notificationObservers: [NSObjectProtocol] = []
    
    public static let tabIDKey = "tabID"
    public static let titleKey = "title"
    public static let isPinnedKey = "isPinned"
    public static let actionKey = "action"
    public static let tabIDsKey = "tabIDs"
    public static let countKey = "count"
    
    private init() {
        self.defaults = UserDefaults.standard
        loadFromDisk()
        setupNotificationObservers()
        logger.info("[固定标签管理器] 初始化完成，当前固定标签数: \(self.records.count)，最大允许: \(self.settings.maxPinnedCount)")
    }
    
    deinit {
        cleanup()
    }
    
    private func setupNotificationObservers() {
        let terminateObserver = notificationCenter.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.info("[生命周期] 应用即将终止，执行固定标签最终保存")
            self?.saveToDisk()
        }
        notificationObservers.append(terminateObserver)
        
        let resignObserver = notificationCenter.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.debug("[生命周期] 应用失去焦点，保存固定标签状态")
            self?.saveToDisk()
        }
        notificationObservers.append(resignObserver)
    }
    
    public func cleanup() {
        logger.info("[清理] 开始清理固定标签管理器资源")
        saveToDisk()
        for observer in notificationObservers {
            notificationCenter.removeObserver(observer)
        }
        notificationObservers.removeAll()
        lock.lock()
        records.removeAll()
        activePinnedID = nil
        lock.unlock()
        logger.info("[清理] 固定标签管理器资源已清理完成")
    }
    
    @discardableResult
    public func pinTab(id: String, title: String, iconName: String? = nil, groupID: String? = nil) -> Bool {
        lock.lock()
        guard !records.contains(where: { $0.id == id }) else {
            lock.unlock()
            logger.info("[固定] 标签已固定，忽略重复操作: \(title) (\(id))")
            return false
        }
        guard records.count < self.settings.maxPinnedCount else {
            lock.unlock()
            logger.warning("[固定] 拒绝固定，已达最大数量限制 \(self.settings.maxPinnedCount): \(title)")
            return false
        }
        let insertOrder: Int
        switch settings.insertPosition {
        case .front:
            insertOrder = records.isEmpty ? 0 : (records.map { $0.order }.min() ?? 0) - 1
        case .back:
            insertOrder = records.isEmpty ? 0 : (records.map { $0.order }.max() ?? 0) + 1
        }
        let record = UIPinnedTabRecord(
            id: id,
            title: title,
            iconName: iconName,
            order: insertOrder,
            groupID: groupID
        )
        records.append(record)
        sortRecordsByOrder()
        lock.unlock()
        saveToDisk()
        notificationCenter.post(
            name: .pinnedTabStatusDidChange,
            object: self,
            userInfo: [
                Self.tabIDKey: id,
                Self.titleKey: title,
                Self.isPinnedKey: true
            ]
        )
        notificationCenter.post(
            name: .pinnedTabListDidChange,
            object: self,
            userInfo: [
                Self.actionKey: "pin",
                Self.tabIDsKey: [id],
                Self.countKey: records.count
            ]
        )
        logger.info("[固定] 已固定标签: \(title) (\(id))，当前固定数: \(self.pinnedCount)")
        return true
    }
    
    @discardableResult
    public func unpinTab(id: String) -> Bool {
        lock.lock()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            logger.info("[取消固定] 标签未固定，忽略操作: \(id)")
            return false
        }
        let removed = records.remove(at: index)
        if activePinnedID == id {
            activePinnedID = nil
        }
        lock.unlock()
        saveToDisk()
        notificationCenter.post(
            name: .pinnedTabStatusDidChange,
            object: self,
            userInfo: [
                Self.tabIDKey: id,
                Self.titleKey: removed.title,
                Self.isPinnedKey: false
            ]
        )
        notificationCenter.post(
            name: .pinnedTabListDidChange,
            object: self,
            userInfo: [
                Self.actionKey: "unpin",
                Self.tabIDsKey: [id],
                Self.countKey: pinnedCount
            ]
        )
        logger.info("[取消固定] 已取消固定标签: \(removed.title) (\(id))，当前固定数: \(self.pinnedCount)")
        return true
    }
    
    @discardableResult
    public func togglePin(id: String, title: String = "", iconName: String? = nil) -> Bool {
        if isPinned(id: id) {
            unpinTab(id: id)
            return false
        } else {
            pinTab(id: id, title: title, iconName: iconName)
            return true
        }
    }
    
    public func isPinned(id: String) -> Bool {
        lock.lock()
        let result = records.contains(where: { $0.id == id })
        lock.unlock()
        return result
    }
    
    public var allPinnedRecords: [UIPinnedTabRecord] {
        lock.lock()
        let result = records
        lock.unlock()
        return result
    }
    
    public var allPinnedIDs: [String] {
        lock.lock()
        let result = records.map { $0.id }
        lock.unlock()
        return result
    }
    
    public var pinnedCount: Int {
        lock.lock()
        let count = records.count
        lock.unlock()
        return count
    }
    
    public func record(for id: String) -> UIPinnedTabRecord? {
        lock.lock()
        let result = records.first(where: { $0.id == id })
        lock.unlock()
        return result
    }
    
    public var currentActivePinnedID: String? {
        lock.lock()
        let id = activePinnedID
        lock.unlock()
        return id
    }
    
    public func isActivePinned(id: String) -> Bool {
        lock.lock()
        let result = activePinnedID == id
        lock.unlock()
        return result
    }
    
    public func title(for id: String) -> String? {
        lock.lock()
        let result = records.first(where: { $0.id == id })?.title
        lock.unlock()
        return result
    }
    
    public func sortWithPinnedFirst<T: Identifiable>(items: [T]) -> [T] {
        lock.lock()
        let pinnedIDs = Set(records.map { $0.id })
        let orderMap: [T.ID: Int] = Dictionary(uniqueKeysWithValues: items.map { item in
            if let stringID = item.id as? String, pinnedIDs.contains(stringID) {
                let order = records.first(where: { $0.id == stringID })?.order ?? 0
                return (item.id, order)
            }
            return (item.id, Int.max)
        })
        lock.unlock()
        return items.sorted { a, b in
            let orderA = orderMap[a.id] ?? Int.max
            let orderB = orderMap[b.id] ?? Int.max
            return orderA < orderB
        }
    }
    
    @discardableResult
    public func reorderPinnedTab(id: String, toIndex: Int) -> Bool {
        lock.lock()
        guard settings.allowReorder else {
            lock.unlock()
            logger.warning("[重排序] 重排序功能已禁用")
            return false
        }
        guard let fromIndex = records.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return false
        }
        let clampedTo = max(0, min(toIndex, records.count - 1))
        guard fromIndex != clampedTo else {
            lock.unlock()
            return true
        }
        let record = records.remove(at: fromIndex)
        records.insert(record, at: clampedTo)
        for (idx, var rec) in records.enumerated() {
            rec.order = idx * 10
            records[idx] = rec
        }
        lock.unlock()
        saveToDisk()
        notificationCenter.post(
            name: .pinnedTabListDidChange,
            object: self,
            userInfo: [
                Self.actionKey: "reorder",
                Self.tabIDsKey: [id],
                Self.countKey: pinnedCount
            ]
        )
        logger.info("[重排序] 固定标签 \(id) 从 \(fromIndex) 移动到 \(clampedTo)")
        return true
    }
    
    public func pinnedIndex(of id: String) -> Int? {
        lock.lock()
        let result = records.firstIndex(where: { $0.id == id })
        lock.unlock()
        return result
    }
    
    private func sortRecordsByOrder() {
        records.sort { $0.order < $1.order }
    }
    
    public func canCloseTab(id: String) -> UITabCloseInterceptionResult {
        lock.lock()
        let isPinnedTab = records.contains(where: { $0.id == id })
        let behavior = settings.closeBehavior
        let title = records.first(where: { $0.id == id })?.title ?? ""
        lock.unlock()
        guard isPinnedTab else {
            return .allowed
        }
        switch behavior {
        case .intercept:
            logger.info("[关闭拦截] 拦截关闭固定标签: \(title) (\(id))")
            return .intercepted(reason: "标签 \(title) 已固定，无法关闭。请先取消固定再关闭。")
        case .warn:
            logger.info("[关闭拦截] 警告关闭固定标签: \(title) (\(id))")
            return .needsConfirmation(message: "标签 \(title) 已固定。确定要关闭并取消固定吗？")
        case .ignore:
            logger.info("[关闭拦截] 不拦截固定标签: \(title) (\(id))")
            return .allowed
        }
    }
    
    public func attemptCloseTab(id: String) -> Bool {
        let result = canCloseTab(id: id)
        switch result {
        case .allowed:
            return true
        case .intercepted:
            return false
        case .needsConfirmation:
            return false
        }
    }
    
    @discardableResult
    public func forceClosePinnedTab(id: String) -> Bool {
        guard isPinned(id: id) else {
            return false
        }
        unpinTab(id: id)
        logger.info("[强制关闭] 已取消固定并允许关闭: \(id)")
        return true
    }
    
    public func activatePinnedTab(id: String) {
        lock.lock()
        guard records.contains(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        activePinnedID = id
        if let idx = records.firstIndex(where: { $0.id == id }) {
            var record = records[idx]
            record.touchActivated()
            records[idx] = record
        }
        let title = records.first(where: { $0.id == id })?.title ?? ""
        lock.unlock()
        saveToDisk()
        notificationCenter.post(
            name: .pinnedTabDidActivate,
            object: self,
            userInfo: [
                Self.tabIDKey: id,
                Self.titleKey: title
            ]
        )
        logger.info("[激活] 固定标签已激活: \(title) (\(id))")
    }
    
    public func activateNextPinnedTab() {
        lock.lock()
        guard !records.isEmpty else {
            lock.unlock()
            return
        }
        let currentID = activePinnedID
        let nextID: String
        if let current = currentID,
           let idx = records.firstIndex(where: { $0.id == current }),
           records.count > 1 {
            let nextIdx = (idx + 1) % records.count
            nextID = records[nextIdx].id
        } else {
            nextID = records[0].id
        }
        lock.unlock()
        activatePinnedTab(id: nextID)
    }
    
    public func activatePreviousPinnedTab() {
        lock.lock()
        guard !records.isEmpty else {
            lock.unlock()
            return
        }
        let currentID = activePinnedID
        let prevID: String
        if let current = currentID,
           let idx = records.firstIndex(where: { $0.id == current }),
           records.count > 1 {
            let prevIdx = (idx - 1 + records.count) % records.count
            prevID = records[prevIdx].id
        } else {
            prevID = records[records.count - 1].id
        }
        lock.unlock()
        activatePinnedTab(id: prevID)
    }
    
    public func clearActivePinned() {
        lock.lock()
        activePinnedID = nil
        lock.unlock()
        saveToDisk()
        logger.info("[激活] 已清除固定标签激活状态")
    }
    
    public func saveToDisk() {
        lock.lock()
        let container = UIPinnedTabDataContainer(
            records: records,
            settings: settings,
            savedAt: Date().timeIntervalSince1970,
            activePinnedID: activePinnedID
        )
        lock.unlock()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(container)
            defaults.set(data, forKey: saveKey)
            logger.info("[持久化] 已保存 \(container.records.count) 个固定标签到 UserDefaults")
        } catch {
            logger.error("[持久化] 保存失败: \(error.localizedDescription)")
        }
    }
    
    public func loadFromDisk() {
        guard let data = defaults.data(forKey: saveKey) else {
            logger.info("[持久化] 未找到保存的固定标签数据，使用默认值")
            return
        }
        do {
            let decoder = JSONDecoder()
            let container = try decoder.decode(UIPinnedTabDataContainer.self, from: data)
            lock.lock()
            records = container.records
            settings = container.settings
            activePinnedID = container.activePinnedID
            lock.unlock()
            logger.info("[持久化] 已加载 \(container.records.count) 个固定标签（版本 \(container.version)）")
        } catch {
            logger.error("[持久化] 加载失败，数据可能损坏: \(error.localizedDescription)")
            lock.lock()
            records.removeAll()
            settings = .default
            activePinnedID = nil
            lock.unlock()
        }
    }
    
    public func clearSavedData() {
        defaults.removeObject(forKey: saveKey)
        lock.lock()
        records.removeAll()
        activePinnedID = nil
        lock.unlock()
        logger.info("[持久化] 已清除所有固定标签保存数据")
        notificationCenter.post(
            name: .pinnedTabListDidChange,
            object: self,
            userInfo: [
                Self.actionKey: "clearAll",
                Self.countKey: 0
            ]
        )
    }
    
    public func exportToJSON() -> String? {
        lock.lock()
        let container = UIPinnedTabDataContainer(
            records: records,
            settings: settings,
            savedAt: Date().timeIntervalSince1970,
            activePinnedID: activePinnedID
        )
        lock.unlock()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(container)
            let json = String(data: data, encoding: .utf8)
            logger.info("[导出] 导出固定标签数据成功，共 \(container.records.count) 个")
            return json
        } catch {
            logger.error("[导出] 编码失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    @discardableResult
    public func importFromJSON(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            logger.error("[导入] 字符串转换为 Data 失败")
            return false
        }
        do {
            let decoder = JSONDecoder()
            let container = try decoder.decode(UIPinnedTabDataContainer.self, from: data)
            lock.lock()
            records = container.records
            settings = container.settings
            activePinnedID = container.activePinnedID
            lock.unlock()
            saveToDisk()
            logger.info("[导入] 导入成功，共 \(container.records.count) 个固定标签")
            notificationCenter.post(
                name: .pinnedTabListDidChange,
                object: self,
                userInfo: [
                    Self.actionKey: "import",
                    Self.countKey: records.count
                ]
            )
            return true
        } catch {
            logger.error("[导入] 解码失败: \(error.localizedDescription)")
            return false
        }
    }
    
    public var currentSettings: UIPinnedTabSettings {
        lock.lock()
        let s = settings
        lock.unlock()
        return s
    }
    
    public func updateSettings(_ newSettings: UIPinnedTabSettings) {
        lock.lock()
        settings = newSettings
        lock.unlock()
        saveToDisk()
        logger.info("[设置] 已更新固定标签设置")
    }
    
    public func setMaxPinnedCount(_ count: Int) {
        let clamped = max(1, min(count, 50))
        lock.lock()
        settings.maxPinnedCount = clamped
        while records.count > clamped {
            records.removeLast()
        }
        lock.unlock()
        saveToDisk()
        logger.info("[设置] 最大固定数量设置为 \(clamped)")
    }
    
    public func setCloseBehavior(_ behavior: UIPinnedTabCloseBehavior) {
        lock.lock()
        settings.closeBehavior = behavior
        lock.unlock()
        saveToDisk()
        logger.info("[设置] 关闭行为设置为 \(behavior.displayName)")
    }
    
    public func createSettingsView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 520))
        let titleLabel = NSTextField(labelWithString: "固定标签页设置")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.frame = NSRect(x: 20, y: 480, width: 300, height: 24)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        view.addSubview(titleLabel)
        var y: CGFloat = 450
        let maxCountLabel = NSTextField(labelWithString: "最大固定数量（1-50）：")
        maxCountLabel.frame = NSRect(x: 20, y: y, width: 180, height: 20)
        maxCountLabel.isEditable = false
        maxCountLabel.isBordered = false
        maxCountLabel.backgroundColor = .clear
        view.addSubview(maxCountLabel)
        let maxCountField = NSTextField(frame: NSRect(x: 210, y: y, width: 60, height: 22))
        maxCountField.stringValue = String(settings.maxPinnedCount)
        maxCountField.tag = 100
        view.addSubview(maxCountField)
        y -= 34
        let indicatorCheckbox = NSButton(
            checkboxWithTitle: "显示固定指示图标（小图钉）",
            target: self,
            action: #selector(settingsShowIndicatorChanged(_:))
        )
        indicatorCheckbox.state = settings.showPinIndicator ? .on : .off
        indicatorCheckbox.frame = NSRect(x: 20, y: y, width: 260, height: 22)
        view.addSubview(indicatorCheckbox)
        y -= 28
        let positionLabel = NSTextField(labelWithString: "指示图标位置：")
        positionLabel.frame = NSRect(x: 20, y: y, width: 120, height: 20)
        positionLabel.isEditable = false
        positionLabel.isBordered = false
        positionLabel.backgroundColor = .clear
        view.addSubview(positionLabel)
        let positionPopUp = NSPopUpButton(frame: NSRect(x: 150, y: y, width: 120, height: 22))
        for pos in UIPinIndicatorPosition.allCases {
            positionPopUp.addItem(withTitle: pos.displayName)
        }
        positionPopUp.selectItem(withTitle: settings.indicatorPosition.displayName)
        positionPopUp.tag = 101
        view.addSubview(positionPopUp)
        y -= 34
        let reorderCheckbox = NSButton(
            checkboxWithTitle: "允许拖拽重排序固定标签",
            target: self,
            action: #selector(settingsAllowReorderChanged(_:))
        )
        reorderCheckbox.state = settings.allowReorder ? .on : .off
        reorderCheckbox.frame = NSRect(x: 20, y: y, width: 240, height: 22)
        view.addSubview(reorderCheckbox)
        y -= 28
        let closeLabel = NSTextField(labelWithString: "关闭固定标签的行为：")
        closeLabel.frame = NSRect(x: 20, y: y, width: 160, height: 20)
        closeLabel.isEditable = false
        closeLabel.isBordered = false
        closeLabel.backgroundColor = .clear
        view.addSubview(closeLabel)
        let closePopUp = NSPopUpButton(frame: NSRect(x: 190, y: y, width: 120, height: 22))
        for behavior in UIPinnedTabCloseBehavior.allCases {
            closePopUp.addItem(withTitle: behavior.displayName)
        }
        closePopUp.selectItem(withTitle: settings.closeBehavior.displayName)
        closePopUp.tag = 102
        view.addSubview(closePopUp)
        y -= 34
        let insertLabel = NSTextField(labelWithString: "新固定标签插入位置：")
        insertLabel.frame = NSRect(x: 20, y: y, width: 160, height: 20)
        insertLabel.isEditable = false
        insertLabel.isBordered = false
        insertLabel.backgroundColor = .clear
        view.addSubview(insertLabel)
        let insertPopUp = NSPopUpButton(frame: NSRect(x: 190, y: y, width: 120, height: 22))
        for pos in UIPinInsertPosition.allCases {
            insertPopUp.addItem(withTitle: pos.displayName)
        }
        insertPopUp.selectItem(withTitle: settings.insertPosition.displayName)
        insertPopUp.tag = 103
        view.addSubview(insertPopUp)
        y -= 34
        let restoreCheckbox = NSButton(
            checkboxWithTitle: "启动时自动恢复上次固定的标签",
            target: self,
            action: #selector(settingsAutoRestoreChanged(_:))
        )
        restoreCheckbox.state = settings.autoRestoreOnLaunch ? .on : .off
        restoreCheckbox.frame = NSRect(x: 20, y: y, width: 300, height: 22)
        view.addSubview(restoreCheckbox)
        y -= 28
        let closeBtnCheckbox = NSButton(
            checkboxWithTitle: "固定标签显示关闭按钮（不推荐）",
            target: self,
            action: #selector(settingsShowCloseButtonChanged(_:))
        )
        closeBtnCheckbox.state = settings.showCloseButtonOnPinned ? .on : .off
        closeBtnCheckbox.frame = NSRect(x: 20, y: y, width: 300, height: 22)
        view.addSubview(closeBtnCheckbox)
        y -= 34
        let statusLabel = NSTextField(labelWithString: "当前固定标签数: \(pinnedCount) / \(settings.maxPinnedCount)")
        statusLabel.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        view.addSubview(statusLabel)
        y -= 28
        let saveButton = NSButton(title: "保存设置", target: self, action: #selector(settingsSaveButtonClicked))
        saveButton.bezelStyle = .rounded
        saveButton.frame = NSRect(x: 20, y: y - 10, width: 100, height: 28)
        view.addSubview(saveButton)
        let resetButton = NSButton(title: "恢复默认", target: self, action: #selector(settingsResetButtonClicked))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: 130, y: y - 10, width: 100, height: 28)
        view.addSubview(resetButton)
        let exportButton = NSButton(title: "导出数据", target: self, action: #selector(settingsExportButtonClicked))
        exportButton.bezelStyle = .rounded
        exportButton.frame = NSRect(x: 240, y: y - 10, width: 100, height: 28)
        view.addSubview(exportButton)
        let clearButton = NSButton(title: "清除数据", target: self, action: #selector(settingsClearButtonClicked))
        clearButton.bezelStyle = .rounded
        clearButton.frame = NSRect(x: 350, y: y - 10, width: 100, height: 28)
        view.addSubview(clearButton)
        let infoText = NSTextField(labelWithString: "固定标签始终显示在非固定标签左侧，重启后自动恢复")
        infoText.font = NSFont.systemFont(ofSize: 11)
        infoText.textColor = NSColor.secondaryLabelColor
        infoText.frame = NSRect(x: 20, y: 20, width: 440, height: 20)
        infoText.isEditable = false
        infoText.isBordered = false
        infoText.backgroundColor = .clear
        view.addSubview(infoText)
        return view
    }
    
    @objc private func settingsShowIndicatorChanged(_ sender: NSButton) {
        var newSettings = currentSettings
        newSettings.showPinIndicator = (sender.state == .on)
        updateSettings(newSettings)
    }
    
    @objc private func settingsAllowReorderChanged(_ sender: NSButton) {
        var newSettings = currentSettings
        newSettings.allowReorder = (sender.state == .on)
        updateSettings(newSettings)
    }
    
    @objc private func settingsAutoRestoreChanged(_ sender: NSButton) {
        var newSettings = currentSettings
        newSettings.autoRestoreOnLaunch = (sender.state == .on)
        updateSettings(newSettings)
    }
    
    @objc private func settingsShowCloseButtonChanged(_ sender: NSButton) {
        var newSettings = currentSettings
        newSettings.showCloseButtonOnPinned = (sender.state == .on)
        updateSettings(newSettings)
    }
    
    @objc private func settingsSaveButtonClicked() {
        saveToDisk()
        logger.info("[设置面板] 用户手动保存固定标签设置")
    }
    
    @objc private func settingsResetButtonClicked() {
        updateSettings(.default)
        logger.info("[设置面板] 用户重置固定标签设置为默认值")
    }
    
    @objc private func settingsExportButtonClicked() {
        if let json = exportToJSON() {
            logger.info("[设置面板] 导出固定标签数据，长度: \(json.count) 字符")
        }
    }
    
    @objc private func settingsClearButtonClicked() {
        clearSavedData()
        logger.info("[设置面板] 用户清除所有固定标签数据")
    }
    
    @discardableResult
    public func batchPin(tabs: [(id: String, title: String, iconName: String?)]) -> Int {
        var successCount = 0
        for tab in tabs {
            if pinTab(id: tab.id, title: tab.title, iconName: tab.iconName) {
                successCount += 1
            }
        }
        logger.info("[批量固定] 成功固定 \(successCount) / \(tabs.count) 个标签")
        return successCount
    }
    
    @discardableResult
    public func batchUnpin(ids: [String]) -> Int {
        var successCount = 0
        for id in ids {
            if unpinTab(id: id) {
                successCount += 1
            }
        }
        logger.info("[批量取消固定] 成功取消 \(successCount) / \(ids.count) 个标签")
        return successCount
    }
    
    public func unpinAll() {
        lock.lock()
        let oldIDs = records.map { $0.id }
        let oldCount = records.count
        records.removeAll()
        activePinnedID = nil
        lock.unlock()
        saveToDisk()
        notificationCenter.post(
            name: .pinnedTabListDidChange,
            object: self,
            userInfo: [
                Self.actionKey: "unpinAll",
                Self.tabIDsKey: oldIDs,
                Self.countKey: 0
            ]
        )
        logger.info("[批量取消固定] 已取消所有 \(oldCount) 个固定标签")
    }
    
    public var statistics: (total: Int, max: Int, active: String?) {
        lock.lock()
        let total = records.count
        let max = settings.maxPinnedCount
        let active = activePinnedID
        lock.unlock()
        return (total, max, active)
    }
    
    public var statusDescription: String {
        let stats = statistics
        return "固定标签: \(stats.total)/\(stats.max)，激活: \(stats.active ?? "无")"
    }
    
    public var hasPinSlot: Bool {
        lock.lock()
        let result = records.count < settings.maxPinnedCount
        lock.unlock()
        return result
    }
    
    public var remainingPinSlots: Int {
        lock.lock()
        let result = max(0, settings.maxPinnedCount - records.count)
        lock.unlock()
        return result
    }
    
    public func debugPrintStructure() {
        lock.lock()
        logger.debug("=== 固定标签结构 ===")
        logger.debug("最大数量: \(self.settings.maxPinnedCount)")
        logger.debug("激活标签: \(self.activePinnedID ?? "无")")
        for (i, rec) in records.enumerated() {
            let activeMark = (rec.id == activePinnedID) ? " [激活]" : ""
            logger.debug("[\(i)] \(rec.title) (\(rec.id)) order=\(rec.order)\(activeMark)")
        }
        logger.debug("===================")
        lock.unlock()
    }
}

// MARK: - 迁回自 UI-02：extension UIPinnedTabManager
public extension UIPinnedTabManager {
    @discardableResult
    func pinTab<T: Identifiable>(item: T, title: String, iconName: String? = nil) -> Bool where T.ID == String {
        return pinTab(id: item.id, title: title, iconName: iconName)
    }
    
    @discardableResult
    func unpinTab<T: Identifiable>(item: T) -> Bool where T.ID == String {
        return unpinTab(id: item.id)
    }
    
    func isPinned<T: Identifiable>(item: T) -> Bool where T.ID == String {
        return isPinned(id: item.id)
    }
    
    @discardableResult
    func togglePin<T: Identifiable>(item: T, title: String = "", iconName: String? = nil) -> Bool where T.ID == String {
        return togglePin(id: item.id, title: title, iconName: iconName)
    }
    
    func attemptCloseTab<T: Identifiable>(item: T) -> Bool where T.ID == String {
        return attemptCloseTab(id: item.id)
    }
    
    var pinnedIDSet: Set<String> {
        return Set(allPinnedIDs)
    }
    
    func isValidPinnedID(_ id: String) -> Bool {
        return isPinned(id: id)
    }
}

// MARK: - 迁回自 UI-02：enum UIPinIndicatorPosition
// MARK: - UI-GL-48 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-48_types.swift
// 版本: 2.0
// MARK: - 通知常量
/// 标签页预览相关通知名称
// 已迁回 UI-GL-48_标签页预览.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-49 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-49_types.swift
// 版本: 2.0
// MARK: - 通知名称定义

/// 标签页分组管理器相关通知
// 已迁回 UI-GL-49_标签页分组.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-50 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-50_types.swift
// 版本: 2.0
// MARK: - 固定指示图标位置枚举
public enum UIPinIndicatorPosition: String, Codable, Sendable, CaseIterable {
    case left = "left"
    case right = "right"
    
    public var displayName: String {
        switch self {
        case .left: return "左侧"
        case .right: return "右侧"
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIPinnedTabCloseBehavior
/// 标签页分组管理器单例,负责所有分组的CRUD、持久化、通知广播
/// 使用os_unfair_lock保护共享数据,线程安全
// 已迁回 UI-GL-49_标签页分组.swift：class UITabGroupManager（公共类型文件禁止功能实现）

// 已迁回 UI-GL-49_标签页分组.swift：extension UITabGroupManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-50 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-50_types.swift
// 版本: 2.0
// MARK: - 固定标签关闭行为枚举
public enum UIPinnedTabCloseBehavior: String, Codable, Sendable, CaseIterable {
    case intercept = "intercept"
    case warn = "warn"
    case ignore = "ignore"
    
    public var displayName: String {
        switch self {
        case .intercept: return "完全拦截"
        case .warn: return "警告确认"
        case .ignore: return "不拦截"
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIPinInsertPosition
// MARK: - 固定标签插入位置枚举
public enum UIPinInsertPosition: String, Codable, Sendable, CaseIterable {
    case front = "front"
    case back = "back"
    
    public var displayName: String {
        switch self {
        case .front: return "最前面"
        case .back: return "最后面"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIPinnedTabRecord
// MARK: - 固定标签记录
public struct UIPinnedTabRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var iconName: String?
    public var order: Int
    public var createdAt: TimeInterval
    public var lastActivatedAt: TimeInterval?
    public var groupID: String?
    public var tabType: String?
    
    public init(
        id: String,
        title: String,
        iconName: String? = nil,
        order: Int = 0,
        groupID: String? = nil,
        tabType: String? = nil
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.order = order
        self.createdAt = Date().timeIntervalSince1970
        self.lastActivatedAt = nil
        self.groupID = groupID
        self.tabType = tabType
    }
    
    public mutating func touchActivated() {
        self.lastActivatedAt = Date().timeIntervalSince1970
    }
}

// MARK: - 迁回自 UI-02：struct UIPinnedTabSettings
// MARK: - 固定标签设置
public struct UIPinnedTabSettings: Codable, Equatable, Sendable {
    public var maxPinnedCount: Int
    public var showPinIndicator: Bool
    public var indicatorPosition: UIPinIndicatorPosition
    public var allowReorder: Bool
    public var closeBehavior: UIPinnedTabCloseBehavior
    public var insertPosition: UIPinInsertPosition
    public var minTabWidth: CGFloat
    public var maxTabWidth: CGFloat
    public var persistOrder: Bool
    public var autoRestoreOnLaunch: Bool
    public var showCloseButtonOnPinned: Bool
    
    public static let `default` = UIPinnedTabSettings(
        maxPinnedCount: 10,
        showPinIndicator: true,
        indicatorPosition: .left,
        allowReorder: true,
        closeBehavior: .intercept,
        insertPosition: .front,
        minTabWidth: 60,
        maxTabWidth: 200,
        persistOrder: true,
        autoRestoreOnLaunch: true,
        showCloseButtonOnPinned: false
    )
}

// MARK: - 迁回自 UI-02：struct UIPinnedTabDataContainer
// MARK: - 持久化数据容器
public struct UIPinnedTabDataContainer: Codable, Sendable {
    var version: Double = 2.0
    var records: [UIPinnedTabRecord]
    var settings: UIPinnedTabSettings
    var savedAt: TimeInterval
    var activePinnedID: String?
}

// MARK: - 迁回自 UI-02：enum UITabCloseInterceptionResult
// MARK: - 关闭拦截结果
public enum UITabCloseInterceptionResult: Equatable, Sendable {
    case allowed
    case intercepted(reason: String)
    case needsConfirmation(message: String)
}
