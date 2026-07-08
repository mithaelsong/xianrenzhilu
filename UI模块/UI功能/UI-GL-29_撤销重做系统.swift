// 功能21: 撤销/重做系统
// 对应: 支持跨窗口的全局Undo/Redo
// 优先级: P2
// 版本: 2.0

import AppKit
import Foundation
import os.log

// MARK: - 通知名称
/// 撤销重做系统通知
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {
// UIUndoRedoManager 已迁移到临时类型文件，后续合并进 UI-02。




// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能21：撤销/重做系统 — 单元测试
/// 覆盖：记录/撤销/重做/清空/步数限制
func test_undoRedo() {
    let manager = UIUndoRedoManager.shared
    
    print("\n🧪 测试1: 记录操作")
    var value = 0
    let action1 = UIUndoAction(actionName: "递增", moduleName: "测试模块",
                               undo: { value -= 1 }, redo: { value += 1 })
    manager.record(action: action1)
    guard manager.undoCount == 1 else {
        fatalError("❌ 测试1失败: 撤销历史应为1")
    }
    print("✅ 测试1通过: 操作记录成功")
    
    print("\n🧪 测试2: 撤销")
    manager.record(action: UIUndoAction(actionName: "再递增", moduleName: "测试模块",
                                       undo: { value -= 1 }, redo: { value += 1 }))
    value = 2  // 模拟两次递增
    guard manager.undo() else {
        fatalError("❌ 测试2失败: 撤销应成功")
    }
    guard value == 1 else {
        fatalError("❌ 测试2失败: 撤销后值应为1")
    }
    print("✅ 测试2通过: 撤销正确")
    
    print("\n🧪 测试3: 重做")
    guard manager.redo() else {
        fatalError("❌ 测试3失败: 重做应成功")
    }
    guard value == 2 else {
        fatalError("❌ 测试3失败: 重做后值应为2")
    }
    print("✅ 测试3通过: 重做正确")
    
    print("\n🧪 测试4: canUndo/canRedo")
    guard manager.canUndo, manager.canRedo else {
        fatalError("❌ 测试4失败: 应有撤销和重做")
    }
    print("✅ 测试4通过: 状态检测正确")
    
    print("\n🧪 测试5: 清空")
    manager.clear()
    guard manager.undoCount == 0, manager.redoCount == 0 else {
        fatalError("❌ 测试5失败: 清空后历史应为0")
    }
    print("✅ 测试5通过: 清空正确")
    
    print("\n🧪 测试6: 操作名称查询")
    manager.record(action: UIUndoAction(actionName: "测试操作", moduleName: "测试模块",
                                       undo: {}, redo: {}))
    guard manager.nextUndoActionName == "测试操作" else {
        fatalError("❌ 测试6失败: 操作名称不正确")
    }
    print("✅ 测试6通过: 操作名称查询正确")
    
    print("\n🧪 测试7: 历史快照")
    let snapshot = manager.historySnapshot()
    guard snapshot.undoHistory.count >= 1 else {
        fatalError("❌ 测试7失败: 快照应有操作")
    }
    print("✅ 测试7通过: 历史快照正确")
    
    print("\n=== 全部撤销重做测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIUndoRedoManager
public final class UIUndoRedoManager : @unchecked Sendable {


    // MARK: - 单例
    /// 全局唯一实例
    public static let shared = UIUndoRedoManager()

    // MARK: - Logger
    /// 系统日志，子系统+分类中文标识
    private let logger = Logger(subsystem: "com.xianrenzhilu.undo", category: "撤销重做")

    // MARK: - 属性

    /// 最大撤销步数，默认 50，防止内存暴涨
    /// 修改时会自动裁剪超出限制的历史记录
    public var maxUndoSteps: Int = 50 {
        didSet {
            lock.lock()
            if undoStack.count > maxUndoSteps {
                let removeCount = undoStack.count - maxUndoSteps
                undoStack.removeFirst(removeCount)
                logger.info("[设置] 最大撤销步数变更为 \(self.maxUndoSteps)，裁剪 \(removeCount) 条历史")
            } else {
                logger.info("[设置] 最大撤销步数变更为 \(self.maxUndoSteps)")
            }
            lock.unlock()
            postHistoryChanged()
        }
    }

    /// 是否启用撤销系统，全局开关
    /// 禁用后不会记录新操作，也无法执行撤销/重做
    public var isEnabled: Bool = true {
        didSet {
            logger.info("[设置] 撤销系统已\(self.isEnabled ? "启用" : "禁用")")
        }
    }

    /// 当前是否可以撤销
    public var canUndo: Bool {
        lock.lock()
        let result = isEnabled && !undoStack.isEmpty
        lock.unlock()
        return result
    }

    /// 当前是否可以重做
    public var canRedo: Bool {
        lock.lock()
        let result = isEnabled && !redoStack.isEmpty
        lock.unlock()
        return result
    }

    /// 撤销历史数量
    public var undoCount: Int {
        lock.lock()
        let result = undoStack.count
        lock.unlock()
        return result
    }

    /// 重做历史数量
    public var redoCount: Int {
        lock.lock()
        let result = redoStack.count
        lock.unlock()
        return result
    }

    /// 下一个可撤销的操作名称（栈顶）
    public var nextUndoActionName: String? {
        lock.lock()
        let result = undoStack.last?.actionName
        lock.unlock()
        return result
    }

    /// 下一个可重做的操作名称（栈顶）
    public var nextRedoActionName: String? {
        lock.lock()
        let result = redoStack.last?.actionName
        lock.unlock()
        return result
    }

    /// 撤销历史操作名称列表（从旧到新）
    public var undoHistoryNames: [String] {
        lock.lock()
        let result = undoStack.map { $0.actionName }
        lock.unlock()
        return result
    }

    /// 重做历史操作名称列表（从旧到新）
    public var redoHistoryNames: [String] {
        lock.lock()
        let result = redoStack.map { $0.actionName }
        lock.unlock()
        return result
    }

    // MARK: - 私有属性
    private var undoStack: [UIUndoAction] = []
    private var redoStack: [UIUndoAction] = []
    private let lock = NSRecursiveLock()
    private var registeredWindows: [String] = []

    // MARK: - 初始化
    private init() {
        logger.info("[初始化] 撤销重做管理器已创建，默认最大撤销步数: 50")
    }

    // MARK: - 核心操作

    /// 记录操作（命令模式入口）
    /// 新操作会清空重做栈
    /// 如果 redoHandler 为 nil，将 undoHandler 作为 redo（视为自逆操作）
    public func record(action: UIUndoAction) {
        guard isEnabled else {
            logger.debug("[记录] 撤销系统已禁用，忽略操作: \(action.actionName)")
            return
        }

        // 规范化：确保 redoHandler 存在
        let normalizedAction: UIUndoAction
        if action.redoHandler == nil {
            normalizedAction = UIUndoAction(
                actionName: action.actionName,
                moduleName: action.moduleName,
                undo: action.undoHandler,
                redo: action.undoHandler
            )
            logger.debug("[记录] 操作无重做逻辑，使用自逆模式: \(action.actionName)")
        } else {
            normalizedAction = action
        }

        lock.lock()
        undoStack.append(normalizedAction)
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
            logger.debug("[记录] 撤销历史超出限制 \(self.maxUndoSteps)，移除最早记录")
        }
        redoStack.removeAll() // 新操作清空重做栈
        lock.unlock()

        logger.info("[记录] 已记录操作: \(action.actionName) [模块: \(action.moduleName)]")
        postHistoryChanged()
    }

    /// 执行撤销
    /// 将操作从 undoStack 移至 redoStack，并执行撤销闭包
    /// - Returns: 是否成功执行
    @discardableResult
    public func undo() -> Bool {
        guard isEnabled else {
            logger.info("[撤销] 撤销系统已禁用")
            return false
        }

        lock.lock()
        guard let action = undoStack.popLast() else {
            lock.unlock()
            logger.info("[撤销] 无操作可撤销")
            return false
        }

        // 交换 undo/redo 放入 redoStack
        // 交换后：undoHandler = 原 redo（用于重做），redoHandler = 原 undo（用于撤销）
        let swappedAction = UIUndoAction(
            actionName: action.actionName,
            moduleName: action.moduleName,
            undo: action.redoHandler ?? action.undoHandler,
            redo: action.undoHandler
        )
        redoStack.append(swappedAction)
        lock.unlock()

        action.undoHandler()
        logger.info("[撤销] 已撤销: \(action.actionName) [模块: \(action.moduleName)]")

        NotificationCenter.default.post(
            name: .undoRedoManagerDidUndo,
            object: self,
            userInfo: ["actionName": action.actionName, "moduleName": action.moduleName]
        )
        postHistoryChanged()
        return true
    }

    /// 执行重做
    /// 将操作从 redoStack 移回 undoStack，并执行重做闭包
    /// - Returns: 是否成功执行
    @discardableResult
    public func redo() -> Bool {
        guard isEnabled else {
            logger.info("[重做] 撤销系统已禁用")
            return false
        }

        lock.lock()
        guard let action = redoStack.popLast() else {
            lock.unlock()
            logger.info("[重做] 无操作可重做")
            return false
        }

        // redoStack 中的 action 是交换过的：undoHandler = 原 redo，redoHandler = 原 undo
        // 放回 undoStack 需要再交换回来
        let swappedBack = UIUndoAction(
            actionName: action.actionName,
            moduleName: action.moduleName,
            undo: action.redoHandler ?? action.undoHandler,
            redo: action.undoHandler
        )
        undoStack.append(swappedBack)
        lock.unlock()

        // 执行 redo（即交换后的 undoHandler）
        action.undoHandler()
        logger.info("[重做] 已重做: \(action.actionName) [模块: \(action.moduleName)]")

        NotificationCenter.default.post(
            name: .undoRedoManagerDidRedo,
            object: self,
            userInfo: ["actionName": action.actionName, "moduleName": action.moduleName]
        )
        postHistoryChanged()
        return true
    }

    /// 清空所有历史记录
    /// 同时清空 undoStack 和 redoStack
    public func clear() {
        lock.lock()
        let undoCount = undoStack.count
        let redoCount = redoStack.count
        undoStack.removeAll()
        redoStack.removeAll()
        lock.unlock()

        logger.info("[清空] 历史记录已清空（撤销: \(undoCount) 条, 重做: \(redoCount) 条）")

        NotificationCenter.default.post(name: .undoRedoManagerDidClear, object: self)
        postHistoryChanged()
    }

    // MARK: - 设置面板方法

    /// 设置最大撤销步数
    /// - Parameter steps: 最大步数，必须大于 0
    public func setMaxUndoSteps(_ steps: Int) {
        guard steps > 0 else {
            logger.error("[设置] 最大撤销步数必须大于 0，当前值: \(steps)")
            return
        }
        maxUndoSteps = steps
    }

    /// 获取当前最大撤销步数
    public func getMaxUndoSteps() -> Int {
        return maxUndoSteps
    }

    /// 启用撤销系统
    public func enable() {
        isEnabled = true
    }

    /// 禁用撤销系统
    /// 禁用后不会记录新操作，也无法执行撤销/重做
    public func disable() {
        isEnabled = false
    }

    /// 获取当前是否启用
    public func isUndoEnabled() -> Bool {
        return isEnabled
    }

    /// 切换启用状态
    /// - Returns: 切换后的状态
    @discardableResult
    public func toggleEnabled() -> Bool {
        isEnabled.toggle()
        return isEnabled
    }

    // MARK: - 跨窗口支持

    /// 注册窗口到全局撤销系统
    /// 全局撤销系统不绑定特定窗口，所有窗口共享同一套撤销栈
    /// - Parameter window: 要注册的窗口
    public func registerWindow(_ window: NSWindow?) {
        guard let w = window, let id = w.identifier?.rawValue else { return }
        lock.lock()
        // 全局撤销系统共享同一栈，记录窗口引用以备反向查询
        registeredWindows.append(id)
        lock.unlock()
        logger.info("[窗口] 注册窗口到全局撤销系统: \(w.title)")
    }

    /// 注销窗口
    /// - Parameter window: 要注销的窗口
    public func unregisterWindow(_ window: NSWindow?) {
        guard let w = window, let id = w.identifier?.rawValue else { return }
        lock.lock()
        registeredWindows.removeAll { $0 == id }
        lock.unlock()
        logger.info("[窗口] 注销窗口: \(w.title)")
    }

    // MARK: - NSUndoManager 桥接

    /// 与 NSUndoManager 桥接
    /// 将系统撤销菜单委托到全局管理器
    /// 注意：NSUndoManager 与窗口强绑定，本桥接用于兼容系统菜单
    /// - Parameter undoManager: 窗口的 UndoManager
    public func bridgeToUndoManager(_ undoManager: UndoManager) {
        undoManager.removeAllActions()
        undoManager.registerUndo(withTarget: self) { [weak self] _ in
            self?.undo()
        }
        logger.info("[桥接] 已桥接到 NSUndoManager")
    }

    /// 移除 NSUndoManager 桥接
    /// - Parameter undoManager: 窗口的 UndoManager
    public func unbridgeFromUndoManager(_ undoManager: UndoManager) {
        undoManager.removeAllActions()
        logger.info("[桥接] 已移除 NSUndoManager 桥接")
    }

    // MARK: - 持久化（可选）

    /// 获取历史记录快照（可序列化）
    /// 不包含闭包，仅包含元数据
    /// 用于调试或持久化历史摘要
    public func historySnapshot() -> UIUndoHistorySnapshot {
        lock.lock()
        let undoMeta = undoStack.map { UIUndoActionMetadata(actionName: $0.actionName, moduleName: $0.moduleName) }
        let redoMeta = redoStack.map { UIUndoActionMetadata(actionName: $0.actionName, moduleName: $0.moduleName) }
        lock.unlock()

        return UIUndoHistorySnapshot(
            undoHistory: undoMeta,
            redoHistory: redoMeta,
            maxUndoSteps: maxUndoSteps
        )
    }

    /// 导出历史记录为 JSON 数据
    /// - Returns: JSON 数据，失败返回 nil
    public func exportHistoryAsJSON() -> Data? {
        let snapshot = historySnapshot()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(snapshot)
            logger.info("[导出] 历史记录导出成功，共 \(snapshot.undoHistory.count + snapshot.redoHistory.count) 条")
            return data
        } catch {
            logger.error("[导出] 历史记录导出失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 私有方法

    /// 发送历史变更通知
    private func postHistoryChanged() {
        NotificationCenter.default.post(name: .undoRedoManagerHistoryChanged, object: self)
    }

    deinit {
        logger.info("UIUndoRedoManager 已释放")
    }
}

// MARK: - 迁回自 UI-02：struct UIUndoAction
// MARK: - UI-GL-29 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-29_types.swift
// 版本: 2.0
// MARK: - 撤销操作记录（命令模式）
/// 单次操作记录，实现命令模式
/// 每个操作包含撤销和重做闭包
/// 注：闭包不可序列化，持久化使用 UIUndoActionMetadata
public struct UIUndoAction {
    /// 操作名称（用于显示）
    public let actionName: String
    /// 所属模块名称
    public let moduleName: String
    /// 撤销操作闭包
    public let undoHandler: () -> Void
    /// 重做操作闭包（可选，为 nil 时视为自逆操作）
    public let redoHandler: (() -> Void)?

    /// 创建操作记录
    /// - Parameters:
    ///   - actionName: 操作名称
    ///   - moduleName: 所属模块
    ///   - undo: 撤销闭包
    ///   - redo: 重做闭包（可选）
    public init(actionName: String, moduleName: String, undo: @escaping () -> Void, redo: (() -> Void)? = nil) {
        self.actionName = actionName
        self.moduleName = moduleName
        self.undoHandler = undo
        self.redoHandler = redo
    }
}

// MARK: - 迁回自 UI-02：struct UIUndoActionMetadata
// MARK: - 迁移自 UI-GL-28：UIWorkspaceManager
// MARK: - 工作区管理器
/// 管理工作区布局的保存、恢复、快照、自动保存和设置面板
// 已迁回 UI-GL-28_状态持久化.swift：class UIWorkspaceManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-29 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-29_types.swift
// 版本: 2.0
// MARK: - 可持久化的操作元数据
/// 操作记录的可序列化元数据（不包含闭包）
/// 用于持久化历史记录摘要或调试
public struct UIUndoActionMetadata: Codable {
    /// 操作名称
    public let actionName: String
    /// 所属模块
    public let moduleName: String
    /// 记录时间
    public let timestamp: Date

    public init(actionName: String, moduleName: String, timestamp: Date = Date()) {
        self.actionName = actionName
        self.moduleName = moduleName
        self.timestamp = timestamp
    }
}

// MARK: - 迁回自 UI-02：struct UIUndoHistorySnapshot
// MARK: - 历史记录快照
/// 撤销历史记录的快照，支持 Codable 持久化
/// 不包含闭包，仅保存元数据
public struct UIUndoHistorySnapshot: Codable {
    /// 撤销历史元数据
    public let undoHistory: [UIUndoActionMetadata]
    /// 重做历史元数据
    public let redoHistory: [UIUndoActionMetadata]
    /// 最大撤销步数设置
    public let maxUndoSteps: Int
    /// 快照时间
    public let timestamp: Date

    public init(undoHistory: [UIUndoActionMetadata], redoHistory: [UIUndoActionMetadata], maxUndoSteps: Int, timestamp: Date = Date()) {
        self.undoHistory = undoHistory
        self.redoHistory = redoHistory
        self.maxUndoSteps = maxUndoSteps
        self.timestamp = timestamp
    }
}
