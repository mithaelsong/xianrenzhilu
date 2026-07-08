// 功能47: 固定机制 (Panel Pinning)
// 对应: 面板点击图钉后固定，固定面板独立于标签系统，始终可见，不随标签页切换
// 优先级: P2
// 作者: 码农
// 最后更新: 2026-06-05

import AppKit
import Foundation
import os.log

// MARK: - 统一日志器
/// 本子模块专用的结构化日志器，subsystem 使用应用主 bundle 标识
private let logger = Logger(subsystem: "com.xianrenzhilu.app", category: "PanelPinning")

// MARK: - 调用测试
#if DEBUG

/// 功能47：固定机制 — 调用验证
func test_pinning() {
    let manager = UIPanelPinningManager.shared
    
    logger.info("测试1: 初始状态")
    if manager.pinnedCount == 0 { logger.info("✅ 测试1通过: 初始无固定面板") }
    else { logger.error("❌ 测试1失败") }
    
    logger.info("测试2: 固定面板")
    let pinned = manager.pinPanel(id: "test1", title: "测试面板", moduleName: "test")
    if pinned { logger.info("✅ 测试2通过") }
    else { logger.error("❌ 测试2失败") }
    
    logger.info("测试3: 重复固定")
    let dup = manager.pinPanel(id: "test1", title: "测试面板", moduleName: "test")
    if !dup { logger.info("✅ 测试3通过: 重复固定被拒绝") }
    else { logger.error("❌ 测试3失败") }
    
    logger.info("测试4: isPinned")
    if manager.isPinned(id: "test1") { logger.info("✅ 测试4通过") }
    else { logger.error("❌ 测试4失败") }
    
    logger.info("测试5: 取消固定")
    if manager.unpinPanel(id: "test1") { logger.info("✅ 测试5通过") }
    else { logger.error("❌ 测试5失败") }
    
    logger.info("测试6: allPinnedRecords")
    _ = manager.pinPanel(id: "test2", title: "面板2", moduleName: "test")
    let records = manager.allPinnedRecords
    if records.count == 1 { logger.info("✅ 测试6通过") }
    else { logger.error("❌ 测试6失败") }
    
    logger.info("测试7: togglePin")
    let toggled = manager.togglePin(id: "test3", title: "切换测试", moduleName: "test")
    if toggled { logger.info("✅ 测试7通过: 已固定") }
    else { logger.error("❌ 测试7失败") }
    
    logger.info("测试8: 位置管理")
    manager.movePanel(id: "test2", to: .left)
    let record = manager.record(for: "test2")
    if record?.position == .left { logger.info("✅ 测试8通过") }
    else { logger.error("❌ 测试8失败") }
    
    logger.info("测试9: 尺寸调整")
    let newSize = manager.resizePanel(id: "test2", to: 100)
    if newSize == UIPinnedPanelPosition.left.minSize { logger.info("✅ 测试9通过: 裁切到最小值") }
    else { logger.error("❌ 测试9失败") }
    
    logger.info("测试10: unpinAll")
    manager.unpinAll()
    if manager.pinnedCount == 0 { logger.info("✅ 测试10通过") }
    else { logger.error("❌ 测试10失败") }
    
    logger.info("=== 全部固定机制测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 单个面板的固定状态发生变更（固定或取消固定）
    /// userInfo 包含 ["panelID": String, "isPinned": Bool, "title": String, "position": String]
    static let panelPinStatusDidChange = Notification.Name("com.xianrenzhilu.panelPinStatusDidChange")
    /// 固定面板列表发生变更（添加/移除/批量操作）
    /// userInfo 包含 ["action": String, "panelIDs": [String], "count": Int]
    static let pinnedPanelListDidChange = Notification.Name("com.xianrenzhilu.pinnedPanelListDidChange")
    /// 固定面板布局发生变更（位置切换/尺寸调整/分割条拖拽）
    /// userInfo 包含 ["panelID": String?, "position": String?, "width": CGFloat?, "height": CGFloat?]
    static let pinnedPanelLayoutDidChange = Notification.Name("com.xianrenzhilu.pinnedPanelLayoutDidChange")
}

// MARK: - 迁回自 UI-02：class UIPanelPinningManager
public final class UIPanelPinningManager: @unchecked Sendable {
    
    // MARK: 单例
    /// 全局共享的面板固定管理器实例
    public static let shared = UIPanelPinningManager()
    
    // MARK: 日志器
    /// 结构化日志器，subsystem 使用仙人指路统一标识
    private let logger = Logger(
        subsystem: "com.xianrenzhilu.ui",
        category: "UIPanelPinningManager"
    )
    
    // MARK: 同步锁
    /// 保护所有共享可变状态的快速互斥锁
    /// 保护所有共享可变状态的递归锁
    private let lock = NSRecursiveLock()
    
    // MARK: 数据存储
    /// 所有固定面板记录（受 lock 保护）
    private nonisolated(unsafe) var records: [UIPinnedPanelRecord] = []
    /// 全局设置（受 lock 保护）
    private nonisolated(unsafe) var settings: UIPanelPinningSettings = .default
    /// 当前激活的固定面板 ID（受 lock 保护）
    private nonisolated(unsafe) var activePanelID: String?
    /// UserDefaults 实例（受 lock 保护）
    private var defaults: UserDefaults
    /// 持久化存储键
    private let saveKey = "com.xianrenzhilu.pinnedPanels.v2.0"
    /// 通知中心实例
    private let notificationCenter = NotificationCenter.default
    
    // MARK: 通知观察器
    /// 内部持有的通知观察器列表，用于 deinit 时清理
    private nonisolated(unsafe) var notificationObservers: [NSObjectProtocol] = []
    
    // MARK: 通知键名常量
    /// 通知 userInfo 中传递面板 ID 的键名
    public static let panelIDKey = "panelID"
    /// 通知 userInfo 中传递面板标题的键名
    public static let titleKey = "title"
    /// 通知 userInfo 中传递固定状态的键名
    public static let isPinnedKey = "isPinned"
    /// 通知 userInfo 中传递操作类型的键名
    public static let actionKey = "action"
    /// 通知 userInfo 中传递面板 ID 列表的键名
    public static let panelIDsKey = "panelIDs"
    /// 通知 userInfo 中传递数量的键名
    public static let countKey = "count"
    /// 通知 userInfo 中传递位置的键名
    public static let positionKey = "position"
    /// 通知 userInfo 中传递尺寸的键名
    public static let sizeKey = "size"
    /// 通知 userInfo 中传递宽度的键名
    public static let widthKey = "width"
    /// 通知 userInfo 中传递高度的键名
    public static let heightKey = "height"
    
    // MARK: 初始化
    /// 私有初始化，确保单例模式
    /// 自动从磁盘加载持久化数据和设置
    private init() {
        self.defaults = UserDefaults.standard
        loadFromDisk()
        setupNotificationObservers()
        logger.info("[面板固定管理器] 初始化完成，当前固定面板数: \(self.records.count)，最大允许: \(self.settings.maxPinnedCount)")
    }
    
    // MARK: 析构
    /// 析构函数，释放资源前保存数据并移除通知观察器
    deinit {
        logger.info("[清理] 面板固定管理器正在销毁，跳过锁直接清理")
        saveToDisk()
        for observer in notificationObservers {
            notificationCenter.removeObserver(observer)
        }
        notificationObservers.removeAll()
        records.removeAll()
        activePanelID = nil
        logger.info("[清理] 面板固定管理器已释放")
    }
    
    // MARK: 通知观察器设置
    /// 设置内部通知观察器，监听应用生命周期事件以触发自动保存/恢复
    private func setupNotificationObservers() {
        // 监听应用即将终止，执行最终保存
        let terminateObserver = notificationCenter.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.info("[生命周期] 应用即将终止，执行固定面板最终保存")
            self?.saveToDisk()
        }
        notificationObservers.append(terminateObserver)
        
        // 监听应用失去焦点，触发保存
        let resignObserver = notificationCenter.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.debug("[生命周期] 应用失去焦点，保存固定面板状态")
            self?.saveToDisk()
        }
        notificationObservers.append(resignObserver)
    }
    
    // MARK: 清理
    /// 清理所有资源：移除通知观察器、保存数据、释放引用
    /// 由 deinit 调用，也可手动调用进行重置
    public func cleanup() {
        logger.info("[清理] 开始清理面板固定管理器资源")
        
        // 保存当前状态
        saveToDisk()
        
        // 移除所有通知观察器
        for observer in notificationObservers {
            notificationCenter.removeObserver(observer)
        }
        notificationObservers.removeAll()
        
        // 清空内部数据（仅在重置时有效，因为 deinit 后对象已销毁）
        lock.lock()
        records.removeAll()
        activePanelID = nil
        lock.unlock()
        
        logger.info("[清理] 面板固定管理器资源已清理完成")
    }
    
    // MARK: - 面板固定/取消固定
    
    /// 固定指定面板
    /// 面板固定后独立于标签系统，始终可见，不随标签页切换而隐藏
    /// 如果面板已固定则忽略，如果已达最大固定数量则拒绝
    /// - Parameters:
    ///   - id: 面板唯一标识符
    ///   - title: 面板标题（用于显示和持久化记录）
    ///   - moduleName: 所属模块名称
    ///   - panelType: 面板类型标识（可选）
    ///   - position: 期望固定位置（未指定时使用默认位置）
    ///   - size: 初始尺寸（未指定时使用位置默认值）
    /// - Returns: 是否成功固定
    @discardableResult
    public func pinPanel(
        id: String,
        title: String,
        moduleName: String,
        panelType: String? = nil,
        position: UIPinnedPanelPosition? = nil,
        size: CGFloat? = nil
    ) -> Bool {
        lock.lock()
        
        // 检查是否已固定
        guard !records.contains(where: { $0.id == id }) else {
            lock.unlock()
            logger.info("[固定] 面板已固定，忽略重复操作: \(title) (\(id))")
            return false
        }
        
        // 检查是否超过最大固定数量
        guard records.count < settings.maxPinnedCount else {
            lock.unlock()
            logger.warning("[固定] 拒绝固定，已达最大数量限制 \(self.settings.maxPinnedCount): \(title)")
            return false
        }
        
        // 确定位置和尺寸
        let targetPosition = position ?? settings.defaultPosition
        var targetSize = size ?? targetPosition.defaultSize
        targetSize = max(targetPosition.minSize, min(targetSize, targetPosition.maxSize))
        
        // 计算同一位置的排序序号
        let samePositionCount = records.filter { $0.position == targetPosition }.count
        
        var record = UIPinnedPanelRecord(
            id: id,
            title: title,
            panelType: panelType,
            moduleName: moduleName,
            position: targetPosition,
            size: targetSize,
            order: samePositionCount
        )
        record.touchAdjusted()
        records.append(record)
        lock.unlock()
        
        // 保存并通知
        saveToDisk()
        notificationCenter.post(
            name: .panelPinStatusDidChange,
            object: self,
            userInfo: [
                Self.panelIDKey: id,
                Self.titleKey: title,
                Self.isPinnedKey: true,
                Self.positionKey: targetPosition.rawValue
            ]
        )
        notificationCenter.post(
            name: .pinnedPanelListDidChange,
            object: self,
            userInfo: [
                Self.actionKey: "pin",
                Self.panelIDsKey: [id],
                Self.countKey: records.count
            ]
        )
        notificationCenter.post(
            name: .pinnedPanelLayoutDidChange,
            object: self,
            userInfo: [
                Self.panelIDKey: id,
                Self.positionKey: targetPosition.rawValue,
                Self.sizeKey: targetSize
            ]
        )
        logger.info("[固定] 已固定面板: \(title) (\(id)) 位置=\(targetPosition.displayName) 尺寸=\(targetSize)")
        return true
    }
    
    /// 取消固定指定面板
    /// 取消固定后面板恢复为普通浮动面板，随标签系统管理
    /// - Parameter id: 面板唯一标识符
    /// - Returns: 是否成功取消固定
    @discardableResult
    public func unpinPanel(id: String) -> Bool {
        lock.lock()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            logger.info("[取消固定] 面板未固定，忽略操作: \(id)")
            return false
        }
        let removed = records.remove(at: index)
        if activePanelID == id {
            activePanelID = nil
        }
        // 重新整理同位置剩余面板的排序
        reorderSamePositionPanels(position: removed.position)
        lock.unlock()
        
        // 保存并通知
        saveToDisk()
        notificationCenter.post(
            name: .panelPinStatusDidChange,
            object: self,
            userInfo: [
                Self.panelIDKey: id,
                Self.titleKey: removed.title,
                Self.isPinnedKey: false,
                Self.positionKey: removed.position.rawValue
            ]
        )
        notificationCenter.post(
            name: .pinnedPanelListDidChange,
            object: self,
            userInfo: [
                Self.actionKey: "unpin",
                Self.panelIDsKey: [id],
                Self.countKey: records.count
            ]
        )
        logger.info("[取消固定] 已取消固定面板: \(removed.title) (\(id))，当前固定数: \(self.records.count)")
        return true
    }
    
    /// 切换面板的固定状态（固定 -> 取消固定，未固定 -> 固定）
    /// - Parameters:
    ///   - id: 面板唯一标识符
    ///   - title: 面板标题（仅在固定时需要）
    ///   - moduleName: 所属模块名称
    /// - Returns: 切换后的固定状态（true=已固定，false=未固定）
    @discardableResult
    public func togglePin(id: String, title: String = "", moduleName: String = "") -> Bool {
        if isPinned(id: id) {
            unpinPanel(id: id)
            return false
        } else {
            pinPanel(id: id, title: title, moduleName: moduleName)
            return true
        }
    }
    
    // MARK: - 查询
    
    /// 判断指定面板是否已固定
    /// - Parameter id: 面板唯一标识符
    /// - Returns: 是否已固定
    public func isPinned(id: String) -> Bool {
        lock.lock()
        let result = records.contains(where: { $0.id == id })
        lock.unlock()
        return result
    }
    
    /// 获取所有固定面板的记录副本
    public var allPinnedRecords: [UIPinnedPanelRecord] {
        lock.lock()
        let result = records
        lock.unlock()
        return result
    }
    
    /// 获取所有固定面板的 ID 列表
    public var allPinnedIDs: [String] {
        lock.lock()
        let result = records.map { $0.id }
        lock.unlock()
        return result
    }
    
    /// 获取固定面板数量
    public var pinnedCount: Int {
        lock.lock()
        let count = records.count
        lock.unlock()
        return count
    }
    
    /// 获取指定固定面板的记录
    /// - Parameter id: 面板唯一标识符
    /// - Returns: 固定记录副本，未固定则返回 nil
    public func record(for id: String) -> UIPinnedPanelRecord? {
        lock.lock()
        let result = records.first(where: { $0.id == id })
        lock.unlock()
        return result
    }
    
    /// 获取当前激活的固定面板 ID
    public var currentActivePanelID: String? {
        lock.lock()
        let id = activePanelID
        lock.unlock()
        return id
    }
    
    /// 获取指定位置的所有固定面板
    /// - Parameter position: 目标位置
    /// - Returns: 该位置的固定面板记录数组（按 order 排序）
    public func panels(at position: UIPinnedPanelPosition) -> [UIPinnedPanelRecord] {
        lock.lock()
        let result = records
            .filter { $0.position == position }
            .sorted { $0.order < $1.order }
        lock.unlock()
        return result
    }
    
    /// 获取固定面板的显示标题
    /// - Parameter id: 面板唯一标识符
    /// - Returns: 标题字符串，未固定返回 nil
    public func title(for id: String) -> String? {
        lock.lock()
        let result = records.first(where: { $0.id == id })?.title
        lock.unlock()
        return result
    }
    
    // MARK: - 位置管理
    
    /// 更改固定面板的位置（如从左侧移到右侧）
    /// 位置变更后自动调整尺寸到目标位置的默认值
    /// - Parameters:
    ///   - id: 面板唯一标识符
    ///   - newPosition: 新位置
    /// - Returns: 是否移动成功
    @discardableResult
    public func movePanel(id: String, to newPosition: UIPinnedPanelPosition) -> Bool {
        lock.lock()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return false
        }
        let oldPosition = records[index].position
        guard oldPosition != newPosition else {
            lock.unlock()
            return true
        }
        records[index].position = newPosition
        // 尺寸限制到新位置的有效范围
        records[index].clampSize()
        records[index].touchAdjusted()
        // 重新分配同位置的 order
        reorderSamePositionPanels(position: oldPosition)
        reorderSamePositionPanels(position: newPosition)
        let newSize = records[index].size
        let title = records[index].title
        lock.unlock()
        
        saveToDisk()
        notificationCenter.post(
            name: .pinnedPanelLayoutDidChange,
            object: self,
            userInfo: [
                Self.panelIDKey: id,
                Self.positionKey: newPosition.rawValue,
                Self.sizeKey: newSize,
                Self.titleKey: title
            ]
        )
        logger.info("[位置] 面板 \(title) (\(id)) 从 \(oldPosition.displayName) 移动到 \(newPosition.displayName)")
        return true
    }
    
    /// 获取指定位置已占用的总尺寸（所有固定面板尺寸之和）
    /// 用于布局计算时判断窗口中心内容区域的大小
    /// - Parameter position: 目标位置
    /// - Returns: 已占用总尺寸（像素）
    public func occupiedSize(at position: UIPinnedPanelPosition) -> CGFloat {
        lock.lock()
        let total = records
            .filter { $0.position == position && $0.isVisible }
            .reduce(0) { $0 + $1.size }
        lock.unlock()
        return total
    }
    
    /// 获取所有四个方向的已占用尺寸映射
    /// 用于布局系统重建窗口分割布局
    /// - Returns: 位置到占用尺寸的映射字典
    public var allOccupiedSizes: [UIPinnedPanelPosition: CGFloat] {
        lock.lock()
        var result: [UIPinnedPanelPosition: CGFloat] = [:]
        for position in UIPinnedPanelPosition.allCases {
            result[position] = records
                .filter { $0.position == position && $0.isVisible }
                .reduce(0) { $0 + $1.size }
        }
        lock.unlock()
        return result
    }
    
    /// 内部方法：重新整理指定位置的所有面板排序
    /// 按 order 排序后重新分配连续序号，确保无空缺
    /// - Parameter position: 目标位置
    private func reorderSamePositionPanels(position: UIPinnedPanelPosition) {
        let indices = records.indices.filter { records[$0].position == position }
            .sorted { records[$0].order < records[$1].order }
        for (newOrder, originalIndex) in indices.enumerated() {
            records[originalIndex].order = newOrder
        }
    }
    
    // MARK: - 大小调节（拖拽分割条）
    
    /// 调整固定面板的尺寸（通过拖拽分割条触发）
    /// 尺寸会自动限制在位置允许的最小和最大值之间
    /// - Parameters:
    ///   - id: 面板唯一标识符
    ///   - newSize: 新尺寸（水平方向为高度，垂直方向为宽度）
    /// - Returns: 是否调整成功（实际应用后的尺寸）
    @discardableResult
    public func resizePanel(id: String, to newSize: CGFloat) -> CGFloat {
        lock.lock()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return 0
        }
        let position = records[index].position
        let clampedSize = max(position.minSize, min(newSize, position.maxSize))
        records[index].size = clampedSize
        records[index].touchAdjusted()
        let title = records[index].title
        lock.unlock()
        
        saveToDisk()
        notificationCenter.post(
            name: .pinnedPanelLayoutDidChange,
            object: self,
            userInfo: [
                Self.panelIDKey: id,
                Self.sizeKey: clampedSize,
                Self.positionKey: position.rawValue,
                Self.titleKey: title
            ]
        )
        logger.info("[尺寸] 面板 \(title) (\(id)) 尺寸调整为 \(clampedSize)（限制范围 \(position.minSize)~\(position.maxSize)）")
        return clampedSize
    }
    
    /// 获取分割条的几何信息（用于渲染可拖拽的分割条）
    /// 返回指定位置相邻固定面板之间的分割条位置数组
    /// - Parameter position: 目标位置
    /// - Returns: 分割条位置数组（每个元素为相对于窗口边缘的偏移量）
    public func splitterPositions(at position: UIPinnedPanelPosition) -> [CGFloat] {
        lock.lock()
        let visiblePanels = records
            .filter { $0.position == position && $0.isVisible }
            .sorted { $0.order < $1.order }
        var positions: [CGFloat] = []
        var currentOffset: CGFloat = 0
        for panel in visiblePanels {
            currentOffset += panel.size
            positions.append(currentOffset)
        }
        // 移除最后一个（窗口边缘不需要分割条）
        if !positions.isEmpty {
            positions.removeLast()
        }
        lock.unlock()
        return positions
    }
    
    /// 获取指定位置的分割条宽度（从全局设置读取）
    public var splitterWidth: CGFloat {
        lock.lock()
        let width = settings.splitterWidth
        lock.unlock()
        return width
    }
    
    // MARK: - 可见性管理
    
    /// 设置固定面板的可见性（隐藏但不取消固定）
    /// 用于临时折叠侧边栏等场景
    /// - Parameters:
    ///   - id: 面板唯一标识符
    ///   - visible: 是否可见
    /// - Returns: 是否设置成功
    @discardableResult
    public func setPanelVisibility(id: String, visible: Bool) -> Bool {
        lock.lock()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return false
        }
        records[index].isVisible = visible
        let position = records[index].position
        let title = records[index].title
        lock.unlock()
        
        notificationCenter.post(
            name: .pinnedPanelLayoutDidChange,
            object: self,
            userInfo: [
                Self.panelIDKey: id,
                Self.positionKey: position.rawValue,
                Self.titleKey: title
            ]
        )
        logger.info("[可见性] 面板 \(title) (\(id)) 可见性设置为 \(visible)")
        return true
    }
    
    /// 切换固定面板的可见性
    /// - Parameter id: 面板唯一标识符
    /// - Returns: 切换后的可见状态
    @discardableResult
    public func togglePanelVisibility(id: String) -> Bool {
        lock.lock()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return false
        }
        let newVisible = !records[index].isVisible
        lock.unlock()
        setPanelVisibility(id: id, visible: newVisible)
        return newVisible
    }
    
    // MARK: - 持久化
    
    /// 保存当前固定面板数据和设置到 UserDefaults
    /// 使用 Codable 序列化为 JSON 数据存储
    public func saveToDisk() {
        lock.lock()
        let container = UIPanelPinningDataContainer(
            records: records,
            settings: settings,
            savedAt: Date().timeIntervalSince1970,
            occupiedSizes: allOccupiedSizes.mapKeys { $0.rawValue }
        )
        lock.unlock()
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(container)
            defaults.set(data, forKey: saveKey)
            logger.info("[持久化] 已保存 \(container.records.count) 个固定面板到 UserDefaults")
        } catch {
            logger.error("[持久化] 保存失败: \(error.localizedDescription)")
        }
    }
    
    /// 从 UserDefaults 加载固定面板数据和设置
    /// 如果数据不存在或损坏，则使用空列表和默认设置
    public func loadFromDisk() {
        guard let data = defaults.data(forKey: saveKey) else {
            logger.info("[持久化] 未找到保存的固定面板数据，使用默认值")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let container = try decoder.decode(UIPanelPinningDataContainer.self, from: data)
            lock.lock()
            records = container.records
            settings = container.settings
            lock.unlock()
            logger.info("[持久化] 已加载 \(container.records.count) 个固定面板（版本 \(container.version)）")
        } catch {
            logger.error("[持久化] 加载失败，数据可能损坏: \(error.localizedDescription)")
            // 数据损坏时回退到空状态
            lock.lock()
            records.removeAll()
            settings = .default
            lock.unlock()
        }
    }
    
    /// 清除保存的固定面板数据（危险操作，设置面板确认后调用）
    public func clearSavedData() {
        defaults.removeObject(forKey: saveKey)
        lock.lock()
        let oldIDs = records.map { $0.id }
        _ = records.count
        records.removeAll()
        activePanelID = nil
        lock.unlock()
        logger.info("[持久化] 已清除所有固定面板保存数据")
        notificationCenter.post(
            name: .pinnedPanelListDidChange,
            object: self,
            userInfo: [
                Self.actionKey: "clearAll",
                Self.panelIDsKey: oldIDs,
                Self.countKey: 0
            ]
        )
    }
    
    /// 导出固定面板数据为 JSON 字符串（用于备份）
    /// - Returns: JSON 字符串，失败返回 nil
    public func exportToJSON() -> String? {
        lock.lock()
        let container = UIPanelPinningDataContainer(
            records: records,
            settings: settings,
            savedAt: Date().timeIntervalSince1970,
            occupiedSizes: allOccupiedSizes.mapKeys { $0.rawValue }
        )
        lock.unlock()
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(container)
            let json = String(data: data, encoding: .utf8)
            logger.info("[导出] 导出固定面板数据成功，共 \(container.records.count) 个")
            return json
        } catch {
            logger.error("[导出] 编码失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 从 JSON 字符串导入固定面板数据（覆盖现有数据）
    /// - Parameter jsonString: JSON 字符串
    /// - Returns: 是否导入成功
    @discardableResult
    public func importFromJSON(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            logger.error("[导入] 字符串转换为 Data 失败")
            return false
        }
        
        do {
            let decoder = JSONDecoder()
            let container = try decoder.decode(UIPanelPinningDataContainer.self, from: data)
            lock.lock()
            records = container.records
            settings = container.settings
            lock.unlock()
            saveToDisk()
            logger.info("[导入] 导入成功，共 \(container.records.count) 个固定面板")
            notificationCenter.post(
                name: .pinnedPanelListDidChange,
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
    
    // MARK: - 设置管理
    
    /// 获取当前设置的副本
    public var currentSettings: UIPanelPinningSettings {
        lock.lock()
        let s = settings
        lock.unlock()
        return s
    }
    
    /// 更新全局设置
    /// - Parameter newSettings: 新的设置值
    public func updateSettings(_ newSettings: UIPanelPinningSettings) {
        lock.lock()
        settings = newSettings
        // 如果当前数量超过新限制，移除多余的（从末尾移除，保留先固定的）
        while records.count > settings.maxPinnedCount {
            records.removeLast()
        }
        lock.unlock()
        saveToDisk()
        logger.info("[设置] 已更新固定面板设置")
    }
    
    /// 设置最大固定面板数量
    /// - Parameter count: 最大数量（范围 1-20）
    public func setMaxPinnedCount(_ count: Int) {
        let clamped = max(1, min(count, 20))
        lock.lock()
        settings.maxPinnedCount = clamped
        while records.count > clamped {
            records.removeLast()
        }
        lock.unlock()
        saveToDisk()
        logger.info("[设置] 最大固定数量设置为 \(clamped)")
    }
    
    /// 设置默认固定位置
    /// - Parameter position: 默认位置
    public func setDefaultPosition(_ position: UIPinnedPanelPosition) {
        lock.lock()
        settings.defaultPosition = position
        lock.unlock()
        saveToDisk()
        logger.info("[设置] 默认固定位置设置为 \(position.displayName)")
    }
    
    // MARK: - 设置面板
    
    /// 创建设置面板视图，包含固定面板机制的所有配置控件
    /// 返回的 NSView 可直接嵌入到设置窗口中
    /// - Returns: 设置面板视图
    public func createSettingsView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 560))
        
        // 标题标签
        let titleLabel = NSTextField(labelWithString: "固定面板设置")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.frame = NSRect(x: 20, y: 520, width: 300, height: 24)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        view.addSubview(titleLabel)
        
        var y: CGFloat = 490
        
        // 最大固定数量
        let maxCountLabel = NSTextField(labelWithString: "最大固定数量（1-20）：")
        maxCountLabel.frame = NSRect(x: 20, y: y, width: 180, height: 20)
        maxCountLabel.isEditable = false
        maxCountLabel.isBordered = false
        maxCountLabel.backgroundColor = .clear
        view.addSubview(maxCountLabel)
        
        let maxCountField = NSTextField(frame: NSRect(x: 210, y: y, width: 60, height: 22))
        maxCountField.stringValue = String(settings.maxPinnedCount)
        maxCountField.tag = 200
        view.addSubview(maxCountField)
        y -= 34
        
        // 默认固定位置
        let defaultPosLabel = NSTextField(labelWithString: "默认固定位置：")
        defaultPosLabel.frame = NSRect(x: 20, y: y, width: 120, height: 20)
        defaultPosLabel.isEditable = false
        defaultPosLabel.isBordered = false
        defaultPosLabel.backgroundColor = .clear
        view.addSubview(defaultPosLabel)
        
        let defaultPosPopUp = NSPopUpButton(frame: NSRect(x: 150, y: y, width: 120, height: 22))
        for pos in UIPinnedPanelPosition.allCases {
            defaultPosPopUp.addItem(withTitle: pos.displayName)
        }
        defaultPosPopUp.selectItem(withTitle: settings.defaultPosition.displayName)
        defaultPosPopUp.tag = 201
        view.addSubview(defaultPosPopUp)
        y -= 34
        
        // 显示固定指示图标
        let indicatorCheckbox = NSButton(
            checkboxWithTitle: "显示固定指示图标（小图钉）",
            target: self,
            action: #selector(settingsShowIndicatorChanged(_:))
        )
        indicatorCheckbox.state = settings.showPinIndicator ? .on : .off
        indicatorCheckbox.frame = NSRect(x: 20, y: y, width: 260, height: 22)
        view.addSubview(indicatorCheckbox)
        y -= 28
        
        // 允许拖拽分割条调整尺寸
        let resizeCheckbox = NSButton(
            checkboxWithTitle: "允许拖拽分割条调整固定面板尺寸",
            target: self,
            action: #selector(settingsAllowResizeChanged(_:))
        )
        resizeCheckbox.state = settings.allowResizeBySplitter ? .on : .off
        resizeCheckbox.frame = NSRect(x: 20, y: y, width: 300, height: 22)
        view.addSubview(resizeCheckbox)
        y -= 28
        
        // 分割条宽度
        let splitterLabel = NSTextField(labelWithString: "分割条宽度（2-12像素）：")
        splitterLabel.frame = NSRect(x: 20, y: y, width: 180, height: 20)
        splitterLabel.isEditable = false
        splitterLabel.isBordered = false
        splitterLabel.backgroundColor = .clear
        view.addSubview(splitterLabel)
        
        let splitterField = NSTextField(frame: NSRect(x: 210, y: y, width: 60, height: 22))
        splitterField.stringValue = String(Int(settings.splitterWidth))
        splitterField.tag = 202
        view.addSubview(splitterField)
        y -= 34
        
        // 允许拖拽切换位置
        let dragPosCheckbox = NSButton(
            checkboxWithTitle: "允许拖拽固定面板切换位置",
            target: self,
            action: #selector(settingsAllowDragChanged(_:))
        )
        dragPosCheckbox.state = settings.allowDragToChangePosition ? .on : .off
        dragPosCheckbox.frame = NSRect(x: 20, y: y, width: 260, height: 22)
        view.addSubview(dragPosCheckbox)
        y -= 28
        
        // 固定面板保持最上层
        let topCheckbox = NSButton(
            checkboxWithTitle: "固定面板始终保持在最上层",
            target: self,
            action: #selector(settingsAlwaysOnTopChanged(_:))
        )
        topCheckbox.state = settings.pinnedPanelsAlwaysOnTop ? .on : .off
        topCheckbox.frame = NSRect(x: 20, y: y, width: 260, height: 22)
        view.addSubview(topCheckbox)
        y -= 28
        
        // 持久化布局
        let persistCheckbox = NSButton(
            checkboxWithTitle: "持久化固定面板的位置和尺寸",
            target: self,
            action: #selector(settingsPersistChanged(_:))
        )
        persistCheckbox.state = settings.persistLayout ? .on : .off
        persistCheckbox.frame = NSRect(x: 20, y: y, width: 300, height: 22)
        view.addSubview(persistCheckbox)
        y -= 28
        
        // 启动自动恢复
        let restoreCheckbox = NSButton(
            checkboxWithTitle: "启动时自动恢复上次固定的面板",
            target: self,
            action: #selector(settingsAutoRestoreChanged(_:))
        )
        restoreCheckbox.state = settings.autoRestoreOnLaunch ? .on : .off
        restoreCheckbox.frame = NSRect(x: 20, y: y, width: 300, height: 22)
        view.addSubview(restoreCheckbox)
        y -= 28
        
        // 最小化时取消固定
        let minimizeCheckbox = NSButton(
            checkboxWithTitle: "最小化时自动取消固定（不推荐）",
            target: self,
            action: #selector(settingsUnpinOnMinimizeChanged(_:))
        )
        minimizeCheckbox.state = settings.unpinOnMinimize ? .on : .off
        minimizeCheckbox.frame = NSRect(x: 20, y: y, width: 300, height: 22)
        view.addSubview(minimizeCheckbox)
        y -= 34
        
        // 当前状态信息
        let statusLabel = NSTextField(labelWithString: "当前固定面板数: \(pinnedCount) / \(settings.maxPinnedCount)")
        statusLabel.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        view.addSubview(statusLabel)
        y -= 28
        
        // 各位置分布信息
        for pos in UIPinnedPanelPosition.allCases {
            let count = panels(at: pos).count
            let posLabel = NSTextField(labelWithString: "  \(pos.displayName): \(count) 个")
            posLabel.frame = NSRect(x: 20, y: y, width: 200, height: 18)
            posLabel.font = NSFont.systemFont(ofSize: 11)
            posLabel.textColor = NSColor.secondaryLabelColor
            posLabel.isEditable = false
            posLabel.isBordered = false
            posLabel.backgroundColor = .clear
            view.addSubview(posLabel)
            y -= 20
        }
        y -= 14
        
        // 保存按钮
        let saveButton = NSButton(title: "保存设置", target: self, action: #selector(settingsSaveButtonClicked))
        saveButton.bezelStyle = .rounded
        saveButton.frame = NSRect(x: 20, y: y - 10, width: 100, height: 28)
        view.addSubview(saveButton)
        
        // 重置按钮
        let resetButton = NSButton(title: "恢复默认", target: self, action: #selector(settingsResetButtonClicked))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: 130, y: y - 10, width: 100, height: 28)
        view.addSubview(resetButton)
        
        // 导出按钮
        let exportButton = NSButton(title: "导出数据", target: self, action: #selector(settingsExportButtonClicked))
        exportButton.bezelStyle = .rounded
        exportButton.frame = NSRect(x: 240, y: y - 10, width: 100, height: 28)
        view.addSubview(exportButton)
        
        // 清除按钮
        let clearButton = NSButton(title: "清除数据", target: self, action: #selector(settingsClearButtonClicked))
        clearButton.bezelStyle = .rounded
        clearButton.frame = NSRect(x: 350, y: y - 10, width: 100, height: 28)
        view.addSubview(clearButton)
        
        // 底部说明
        let infoText = NSTextField(labelWithString: "固定面板独立于标签系统，始终可见，可通过拖拽分割条调整尺寸")
        infoText.font = NSFont.systemFont(ofSize: 11)
        infoText.textColor = NSColor.secondaryLabelColor
        infoText.frame = NSRect(x: 20, y: 20, width: 440, height: 20)
        infoText.isEditable = false
        infoText.isBordered = false
        infoText.backgroundColor = .clear
        view.addSubview(infoText)
        
        return view
    }
    
    // MARK: 设置面板事件处理
    
    @objc private func settingsShowIndicatorChanged(_ sender: NSButton) {
        var newSettings = currentSettings
        newSettings.showPinIndicator = (sender.state == .on)
        updateSettings(newSettings)
    }
    
    @objc private func settingsAllowResizeChanged(_ sender: NSButton) {
        var newSettings = currentSettings
        newSettings.allowResizeBySplitter = (sender.state == .on)
        updateSettings(newSettings)
    }
    
    @objc private func settingsAllowDragChanged(_ sender: NSButton) {
        var newSettings = currentSettings
        newSettings.allowDragToChangePosition = (sender.state == .on)
        updateSettings(newSettings)
    }
    
    @objc private func settingsAlwaysOnTopChanged(_ sender: NSButton) {
        var newSettings = currentSettings
        newSettings.pinnedPanelsAlwaysOnTop = (sender.state == .on)
        updateSettings(newSettings)
    }
    
    @objc private func settingsPersistChanged(_ sender: NSButton) {
        var newSettings = currentSettings
        newSettings.persistLayout = (sender.state == .on)
        updateSettings(newSettings)
    }
    
    @objc private func settingsAutoRestoreChanged(_ sender: NSButton) {
        var newSettings = currentSettings
        newSettings.autoRestoreOnLaunch = (sender.state == .on)
        updateSettings(newSettings)
    }
    
    @objc private func settingsUnpinOnMinimizeChanged(_ sender: NSButton) {
        var newSettings = currentSettings
        newSettings.unpinOnMinimize = (sender.state == .on)
        updateSettings(newSettings)
    }
    
    @objc private func settingsSaveButtonClicked() {
        saveToDisk()
        logger.info("[设置面板] 用户手动保存固定面板设置")
    }
    
    @objc private func settingsResetButtonClicked() {
        updateSettings(.default)
        logger.info("[设置面板] 用户重置固定面板设置为默认值")
    }
    
    @objc private func settingsExportButtonClicked() {
        if let json = exportToJSON() {
            logger.info("[设置面板] 导出固定面板数据，长度: \(json.count) 字符")
        }
    }
    
    @objc private func settingsClearButtonClicked() {
        clearSavedData()
        logger.info("[设置面板] 用户清除所有固定面板数据")
    }
    
    // MARK: - 批量操作
    
    /// 批量固定多个面板
    /// - Parameter panels: 面板元组数组 [(id, title, moduleName, panelType?)]
    /// - Returns: 成功固定的数量
    @discardableResult
    public func batchPin(panels: [(id: String, title: String, moduleName: String, panelType: String?)]) -> Int {
        var successCount = 0
        for panel in panels {
            if pinPanel(id: panel.id, title: panel.title, moduleName: panel.moduleName, panelType: panel.panelType) {
                successCount += 1
            }
        }
        logger.info("[批量固定] 成功固定 \(successCount) / \(panels.count) 个面板")
        return successCount
    }
    
    /// 批量取消固定多个面板
    /// - Parameter ids: 面板 ID 数组
    /// - Returns: 成功取消固定的数量
    @discardableResult
    public func batchUnpin(ids: [String]) -> Int {
        var successCount = 0
        for id in ids {
            if unpinPanel(id: id) {
                successCount += 1
            }
        }
        logger.info("[批量取消固定] 成功取消 \(successCount) / \(ids.count) 个面板")
        return successCount
    }
    
    /// 取消固定所有面板
    public func unpinAll() {
        lock.lock()
        let oldIDs = records.map { $0.id }
        let oldCount = records.count
        records.removeAll()
        activePanelID = nil
        lock.unlock()
        
        saveToDisk()
        notificationCenter.post(
            name: .pinnedPanelListDidChange,
            object: self,
            userInfo: [
                Self.actionKey: "unpinAll",
                Self.panelIDsKey: oldIDs,
                Self.countKey: 0
            ]
        )
        logger.info("[批量取消固定] 已取消所有 \(oldCount) 个固定面板")
    }
    
    // MARK: - 统计与状态
    
    /// 获取固定面板统计信息
    public var statistics: (total: Int, max: Int, active: String?) {
        lock.lock()
        let total = records.count
        let max = settings.maxPinnedCount
        let active = activePanelID
        lock.unlock()
        return (total, max, active)
    }
    
    /// 获取状态描述文本（供调试面板或状态栏显示）
    public var statusDescription: String {
        let stats = statistics
        let leftCount = panels(at: .left).count
        let rightCount = panels(at: .right).count
        let topCount = panels(at: .top).count
        let bottomCount = panels(at: .bottom).count
        return "固定面板: \(stats.total)/\(stats.max) (上\(topCount) 下\(bottomCount) 左\(leftCount) 右\(rightCount))"
    }
    
    /// 检查是否还有固定名额
    public var hasPinSlot: Bool {
        lock.lock()
        let result = records.count < settings.maxPinnedCount
        lock.unlock()
        return result
    }
    
    /// 获取剩余可固定数量
    public var remainingPinSlots: Int {
        lock.lock()
        let result = max(0, settings.maxPinnedCount - records.count)
        lock.unlock()
        return result
    }
    
    // MARK: - 调试辅助
    
    /// 打印当前固定面板结构的调试信息（仅供开发调试用）
    public func debugPrintStructure() {
        lock.lock()
        logger.debug("=== 固定面板结构 ===")
        logger.debug("最大数量: \(self.settings.maxPinnedCount)")
        logger.debug("激活面板: \(self.activePanelID ?? "无")")
        for pos in UIPinnedPanelPosition.allCases {
            let posPanels = records.filter { $0.position == pos }.sorted { $0.order < $1.order }
            if !posPanels.isEmpty {
                logger.debug("[\(pos.displayName)] \(posPanels.count) 个面板:")
                for (i, rec) in posPanels.enumerated() {
                    let visibleMark = rec.isVisible ? "" : " [隐藏]"
                    let activeMark = (rec.id == activePanelID) ? " [激活]" : ""
                    logger.debug("  [\(i)] \(rec.title) (\(rec.id)) 尺寸=\(rec.size) 顺序=\(rec.order)\(visibleMark)\(activeMark)")
                }
            }
        }
        logger.debug("===================")
        lock.unlock()
    }
}

// MARK: - 迁回自 UI-02：extension UIPanelPinningManager
public extension UIPanelPinningManager { }

// MARK: - 迁回自 UI-02：UIPanelPinningDataContainer
private struct UIPanelPinningDataContainer: Codable, Sendable {
    /// 数据格式版本号（用于未来迁移兼容）
    var version: String = "2.0"
    /// 所有固定面板记录
    var records: [UIPinnedPanelRecord]
    /// 全局设置
    var settings: UIPanelPinningSettings
    /// 最后保存时间戳
    var savedAt: TimeInterval
    /// 当前窗口布局中各位置的已占用尺寸（用于恢复时重建布局）
    var occupiedSizes: [String: CGFloat]?
}

// MARK: - 迁回自 UI-02：enum UIPinnedPanelPosition
// MARK: - 可停靠面板默认实现
// 已迁回 UI-GL-56_停靠系统.swift：extension UIDockablePanelProtocol（公共类型文件禁止功能实现）

// MARK: - 停靠区域视觉指示器
/// 当拖拽面板靠近窗口边缘时，显示高亮区域提示用户可以停靠
// 已迁回 UI-GL-56_停靠系统.swift：class UIDockingZoneIndicatorView（公共类型文件禁止功能实现）

// MARK: - 停靠指示器窗口
/// 管理停靠区域高亮窗口的显示与隐藏
// 已迁回 UI-GL-56_停靠系统.swift：class UIDockingIndicatorWindowController（公共类型文件禁止功能实现）

// MARK: - 可停靠面板实现
/// 具体的可停靠面板类，封装面板内容和停靠行为
// 已迁回 UI-GL-56_停靠系统.swift：class UIDockablePanel（公共类型文件禁止功能实现）

// MARK: - 停靠系统管理器（单例）
/// 管理所有面板的注册、停靠、拖拽、持久化等操作
// 已迁回 UI-GL-56_停靠系统.swift：class UIDockingManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-57 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-57_types.swift
// 版本: 2.0
// MARK: - 固定面板位置枚举
/// 固定面板在主窗口中的位置，分布在窗口四周
public enum UIPinnedPanelPosition: String, Codable, Sendable, CaseIterable {
    /// 窗口上方（顶部固定面板）
    case top = "top"
    /// 窗口下方（底部固定面板）
    case bottom = "bottom"
    /// 窗口左侧（左侧边栏）
    case left = "left"
    /// 窗口右侧（右侧边栏）
    case right = "right"
    
    /// 本地化显示名称
    public var displayName: String {
        switch self {
        case .top:    return "上方"
        case .bottom: return "下方"
        case .left:   return "左侧"
        case .right:  return "右侧"
        }
    }
    
    /// 是否为水平方向（影响尺寸调节方向）
    public var isHorizontal: Bool {
        switch self {
        case .top, .bottom: return true
        case .left, .right:  return false
        }
    }
    
    /// 默认尺寸（宽度或高度，取决于方向）
    public var defaultSize: CGFloat {
        switch self {
        case .top, .bottom: return 200
        case .left, .right:  return 280
        }
    }
    
    /// 最小允许尺寸（像素）
    public var minSize: CGFloat {
        switch self {
        case .top, .bottom: return 80
        case .left, .right:  return 120
        }
    }
    
    /// 最大允许尺寸（像素）
    public var maxSize: CGFloat {
        switch self {
        case .top, .bottom: return 600
        case .left, .right:  return 800
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIPinnedPanelRecord
// MARK: - 固定面板记录
/// 单个固定面板的持久化记录模型，包含面板标识、位置、尺寸等完整信息
/// 支持 Codable 序列化，存储到 UserDefaults 或文件，重启后自动恢复
public struct UIPinnedPanelRecord: Codable, Identifiable, Equatable, Sendable {
    /// 面板唯一标识符（与 UIPanelConfiguration.identifier 对应）
    public let id: String
    /// 面板显示标题
    public var title: String
    /// 面板类型标识符（用于恢复时重建正确类型）
    public var panelType: String?
    /// 所属模块名称（用于查找和路由）
    public var moduleName: String
    /// 固定位置（上方/下方/左侧/右侧）
    public var position: UIPinnedPanelPosition
    /// 面板尺寸（水平方向为高度，垂直方向为宽度）
    public var size: CGFloat
    /// 是否可见（即使固定也可临时隐藏）
    public var isVisible: Bool
    /// 创建时间戳
    public var createdAt: TimeInterval
    /// 最后调整时间戳（尺寸或位置变更时更新）
    public var lastAdjustedAt: TimeInterval?
    /// 排序序号（同一位置多个面板时的层叠顺序）
    public var order: Int
    
    /// 创建新固定面板记录
    public init(
        id: String,
        title: String,
        panelType: String? = nil,
        moduleName: String,
        position: UIPinnedPanelPosition = .right,
        size: CGFloat? = nil,
        isVisible: Bool = true,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.panelType = panelType
        self.moduleName = moduleName
        self.position = position
        self.size = size ?? position.defaultSize
        self.isVisible = isVisible
        self.createdAt = Date().timeIntervalSince1970
        self.lastAdjustedAt = nil
        self.order = order
    }
    
    /// 更新最后调整时间戳
    public mutating func touchAdjusted() {
        self.lastAdjustedAt = Date().timeIntervalSince1970
    }
    
    /// 将尺寸限制在有效范围内
    public mutating func clampSize() {
        self.size = max(position.minSize, min(self.size, position.maxSize))
    }
}

// MARK: - 迁回自 UI-02：struct UIPanelPinningSettings
// MARK: - 固定面板设置
/// 固定面板机制的全局行为设置，用户可在设置面板中调整
public struct UIPanelPinningSettings: Codable, Equatable, Sendable {
    /// 最大允许固定的面板数量（防止固定过多导致工作区拥挤）
    public var maxPinnedCount: Int
    /// 是否显示固定指示图标（小图钉）在面板标题栏
    public var showPinIndicator: Bool
    /// 是否允许通过拖拽分割条调整固定面板尺寸
    public var allowResizeBySplitter: Bool
    /// 分割条宽度（像素）
    public var splitterWidth: CGFloat
    /// 是否允许拖拽固定面板切换位置（如从左侧拖到右侧）
    public var allowDragToChangePosition: Bool
    /// 固定面板是否始终保持在最上层（覆盖普通浮动面板）
    public var pinnedPanelsAlwaysOnTop: Bool
    /// 是否持久化固定面板的位置和尺寸
    public var persistLayout: Bool
    /// 是否在启动时自动恢复上次固定的面板
    public var autoRestoreOnLaunch: Bool
    /// 固定面板最小化时是否自动取消固定（ false 则保持固定但隐藏）
    public var unpinOnMinimize: Bool
    /// 默认固定位置（新面板固定时默认使用的位置）
    public var defaultPosition: UIPinnedPanelPosition
    
    /// 默认设置值
    public static let `default` = UIPanelPinningSettings(
        maxPinnedCount: 8,
        showPinIndicator: true,
        allowResizeBySplitter: true,
        splitterWidth: 6,
        allowDragToChangePosition: true,
        pinnedPanelsAlwaysOnTop: false,
        persistLayout: true,
        autoRestoreOnLaunch: true,
        unpinOnMinimize: false,
        defaultPosition: .right
    )
}

// MARK: - 从 UI-02 正确迁回：var PinToTopOriginalLevelKey
private nonisolated(unsafe) var PinToTopOriginalLevelKey: UInt8 = 0

