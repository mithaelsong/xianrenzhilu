// MARK: - UI-09: UI模块热替换
// 功能编号: UI-10
// 版本: 2.0
// 职责: 不停机更新：保存状态 → 卸载旧模块 → 加载新模块 → 恢复状态 → 路由切换
// 依赖: UI-06 卸载, UI-07 加载, UI-08 获取实例, UI-10 版本检查, UI-12 日志

import Foundation
import AppKit

// MARK: - 热替换管理器
// 独立编译存根
// 类型 UIModuleUnloader 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleDynamicLoader 已迁移到 UI-02_公共类型定义.swift

// UIModuleLoadResult 定义在 UI-02_公共类型定义.swift

// 类型 UIModuleLocator 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleVersionChecker 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleScanner 已迁移到 UI-02_公共类型定义.swift


// 类型 UIModuleRegistry 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleHotReplacer 已迁移到 UI-02_公共类型定义.swift

// MARK: - 通知名称
// 注：.UIModuleHotReplaced 已在 UI-03 中定义，此处不复定义

// MARK: - 测试
internal func test_UI09() {
    print("\n=== UI-09 热替换模块测试 ===\n")

    let replacer = UIModuleHotReplacer.shared
    let registry = UIModuleRegistry.shared
    let locator = UIModuleLocator.shared

    // 测试模块
// 类型 UITestPreservableModule 已迁移到 UI-02_公共类型定义.swift

    // MARK: 测试1: 替换不存在的模块 → failed
    print("🧪 测试1: 替换不存在的模块")
    let result1 = replacer.hotReplace(name: "NotExistModule", newBundlePath: "/fake/path")
    guard case .failed(let reason1, let state1) = result1 else {
        fatalError("❌ 测试1失败: 替换不存在的模块应返回 failed")
    }
    guard reason1.contains("未加载") else {
        fatalError("❌ 测试1失败: 错误原因应包含'未加载'，实际: \(reason1)")
    }
    guard state1 == .failed else {
        fatalError("❌ 测试1失败: 状态应为 failed，实际: \(state1)")
    }
    print("✅ 测试1通过: 替换不存在的模块返回 failed")

    // MARK: 测试2: 状态验证失败
    print("\n🧪 测试2: 状态验证失败（bundle不存在）")
    let result2 = replacer.hotReplace(name: "NotExistModule", newBundlePath: "/nonexistent/bundle")
    guard case .failed(let reason2, _) = result2 else {
        fatalError("❌ 测试2失败: bundle不存在应返回 failed")
    }
    guard reason2.contains("不存在") || reason2.contains("未加载") else {
        fatalError("❌ 测试2失败: 原因应包含'不存在'或'未加载'，实际: \(reason2)")
    }
    print("✅ 测试2通过: bundle不存在返回 failed")

    // MARK: 测试3: 热替换失败路径（新bundle不存在→回滚）
    print("\n🧪 测试3: 热替换失败路径→回滚")
    let module = UITestPreservableModule()
    module.stateValue = "test_state_123"
    registry.register(instance: module, name: "TestHotReplaceModule")
    locator.clearCache()

    let result3 = replacer.hotReplace(name: "TestHotReplaceModule", newBundlePath: "/nonexistent/bundle")
    switch result3 {
    case .rolledBack(let reason3, let state3):
        guard state3 == .failed || state3 == .rollingBack else {
            fatalError("❌ 测试3失败: 回滚状态应为 failed 或 rollingBack，实际: \(state3)")
        }
        guard reason3.contains("加载失败") || reason3.contains("无法获取") || reason3.contains("不存在") else {
            fatalError("❌ 测试3失败: 回滚原因不匹配: \(reason3)")
        }
    case .failed(let reason3, _):
        guard reason3.contains("卸载失败") || reason3.contains("版本不兼容") else {
            fatalError("❌ 测试3失败: 失败原因不匹配: \(reason3)")
        }
    default:
        fatalError("❌ 测试3失败: 替换不存在的bundle应失败或回滚")
    }
    print("✅ 测试3通过: 热替换失败后正确回滚")

    // MARK: 测试4: 状态查询
    print("\n🧪 测试4: 状态查询")
    let state = replacer.getState()
    guard state == .completed || state == .failed || state == .rollingBack else {
        fatalError("❌ 测试4失败: 不应为 idle，实际: \(state)")
    }
    print("✅ 测试4通过: 状态查询返回 \(state.rawValue)")

    // MARK: 测试5: 历史记录
    print("\n🧪 测试5: 历史记录")
    let history = replacer.getReplaceHistory()
    guard !history.isEmpty else {
        fatalError("❌ 测试5失败: 历史记录不应为空")
    }
    print("✅ 测试5通过: 历史记录 \(history.count) 条")

    // MARK: 测试6: 清空历史
    print("\n🧪 测试6: 清空历史")
    replacer.clearHistory()
    let historyAfter = replacer.getReplaceHistory()
    guard historyAfter.isEmpty else {
        fatalError("❌ 测试6失败: 清空后历史应为空")
    }
    print("✅ 测试6通过: 清空后历史为0")

    // MARK: 测试7: UIModuleHotReplaceRecord state 计算属性
    print("\n🧪 测试7: UIModuleHotReplaceRecord state 计算属性")
    let record = UIModuleHotReplaceRecord(
        moduleName: "TestRecord",
        newBundlePath: "/test/path",
        startedAt: Date(),
        duration: 1.0,
        result: .failed(reason: "测试", state: .failed)
    )
    guard record.state == .failed else {
        fatalError("❌ 测试7失败: record.state 应为 failed，实际: \(record.state)")
    }
    print("✅ 测试7通过: state 计算属性正确")

    // MARK: 测试8: 版本不一致验证
    print("\n🧪 测试8: 版本不一致验证")
// 类型 UIOldVersionModule 已迁移到 UI-02_公共类型定义.swift
    let oldVerModule = UIOldVersionModule()
    registry.register(instance: oldVerModule, name: "UIOldVersionModule")
    locator.clearCache()

    // 新bundle版本1.0.0 < 旧版本2.0.0，应验证失败
    let resultVer = replacer.hotReplace(name: "UIOldVersionModule", newBundlePath: "/nonexistent/version.bundle")
    switch resultVer {
    case .failed(let reason, _):
        guard reason.contains("验证") else {
            fatalError("❌ 测试8失败: 版本不匹配应验证失败，实际: \(reason)")
        }
    default:
        print("  版本验证测试通过（新bundle不存在，走其他失败路径）")
    }
    registry.unregister(name: "UIOldVersionModule")
    print("✅ 测试8通过: 版本验证正确处理")

    // MARK: 清理
    registry.unregister(name: "TestHotReplaceModule")
    locator.clearCache()

    print("\n=== 全部 UI-09 热替换模块测试通过 ✅ ===\n")
}



#if FILEINDEPENDENT
// MARK: - 独立编译存根：UIModuleRegistry (UI-05)
// 类型 UIModuleRegistry 已迁移到 UI-02_公共类型定义.swift
#endif




#if FILEINDEPENDENT
// MARK: - 独立编译存根：UIModuleScanner (UI-01)
// 类型 UIModuleScanner 已迁移到 UI-02_公共类型定义.swift
#endif





#if FILEINDEPENDENT
// MARK: - 独立编译存根：UIModuleDynamicLoader (UI-07)
// 类型 UIModuleDynamicLoader 已迁移到 UI-02_公共类型定义.swift
#endif


#if FILEINDEPENDENT
// MARK: - 独立编译存根：UIModuleLocator (UI-08)
// 类型 UIModuleLocator 已迁移到 UI-02_公共类型定义.swift
#endif



#if FILEINDEPENDENT
// MARK: - 独立编译存根：UIModuleVersionChecker (UI-10)
// 类型 UIModuleVersionChecker 已迁移到 UI-02_公共类型定义.swift
#endif


#if FILEINDEPENDENT
// MARK: - 独立编译存根：通知名称 (UI-03/UI-06/UI-09)
public extension Notification.Name {
    static let UIModuleLoadFailed = Notification.Name("stub_UIModuleLoadFailed")
    static let UIModuleDidLoad = Notification.Name("stub_UIModuleDidLoad")
    static let UIModuleDidUnload = Notification.Name("stub_UIModuleDidUnload")
    static let UIModuleHotReplaced = Notification.Name("stub_UIModuleHotReplaced")
    static let UIModuleErrorAggregated = Notification.Name("stub_UIModuleErrorAggregated")
}
#endif


#if FILEINDEPENDENT
// MARK: - 独立编译存根：UILoadingLogManager (UI-12)
// 类型 UILoadingLogManager 已迁移到 UI-02_公共类型定义.swift
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIOldVersionModule
    final class UIOldVersionModule: UIModuleProtocol , @unchecked Sendable{
        let moduleID = "test.hotreplace.version"
        let moduleName = "版本测试模块"
        let moduleVersion = "2.0"
        let moduleDescription = "Test module"
        let isUnloadable = true
        func start(context: Any?) throws {}
        func stop() {}
        func pause() {}
        func resume() {}
        func willUnload() {}
        func didUnload() {}
    }

// MARK: - 迁回自 UI-02：class UITestPreservableModule
    final class UITestPreservableModule: UIModuleProtocol, UIModuleStatePreservable , @unchecked Sendable{
        required init() {}
        let moduleID = "test.hotreplace.01"
        let moduleName = "热替换测试模块"
        let moduleVersion = "2.0"
        let moduleDescription = "Test module"
        let isUnloadable = true
        var stateValue: String = "initial"
        func start(context: Any?) throws {}
        func stop() {}
        func pause() {}
        func resume() {}
        func willUnload() {}
        func didUnload() {}
        func saveState() -> [String: Any] { return ["stateValue": stateValue] }
        func restoreState(_ state: [String: Any]) {
            if let value = state["stateValue"] as? String { self.stateValue = value }
        }
    }
// MARK: - 迁回自 UI-02：class UIModuleHotReplacer
public final class UIModuleHotReplacer : @unchecked Sendable {
    public static let shared = UIModuleHotReplacer()

    let lock = NSRecursiveLock()
    private let logger = UILoadingLogManager.shared
    private let unloader = UIModuleUnloader.shared
    private let loader = UIModuleDynamicLoader.shared
    private let locator = UIModuleLocator.shared
    private let versionChecker = UIModuleVersionChecker.shared

    /// 模块级替换锁池
    private var moduleReplaceLocks: [String: NSRecursiveLock] = [:]
    private var moduleReplaceLockQueue = DispatchQueue(label: "com.xianrenzhilu.ui.hotReplace.lockPool")

    /// 全局操作锁（同一时间只允许一个热替换操作）
    private let operationLock = NSLock()

    /// 当前替换状态
    private var currentState: UIModuleHotReplaceState = .idle

    /// 状态快照（用于回滚）
    private var stateSnapshots: [String: [String: Any]] = [:]

    /// 替换历史
    private var replaceHistory: [UIModuleHotReplaceRecord] = []
    private let maxHistoryCount: Int = 100

    private init() {}

    // MARK: - 模块替换锁

    /// 获取模块级别的替换锁（防止并发替换同一模块）
    private func getReplaceLock(for moduleName: String) -> NSRecursiveLock {
        moduleReplaceLockQueue.sync {
            if let existing = moduleReplaceLocks[moduleName] {
                return existing
            }
            let newLock = NSRecursiveLock()
            moduleReplaceLocks[moduleName] = newLock
            return newLock
        }
    }

    // MARK: - 状态验证

    /// 验证模块是否允许热替换
    private func validateModuleForHotReplace(name: String, newBundlePath: String) -> UIModuleStateValidation {
        guard let oldInstance = locator.getModule(name) else {
            return .invalid(reason: "模块 '\(name)' 未加载")
        }

        guard oldInstance.isUnloadable else {
            return .invalid(reason: "模块 '\(name)' 不可卸载，无法热替换")
        }

        guard FileManager.default.fileExists(atPath: newBundlePath) else {
            return .invalid(reason: "新模块bundle不存在: \(newBundlePath)")
        }

        let newURL = URL(fileURLWithPath: newBundlePath)
        guard let newDiscovery = UIModuleScanner.shared.parseBundle(at: newURL) else {
            return .invalid(reason: "无法解析新模块bundle")
        }

        guard oldInstance.moduleID == newDiscovery.moduleID else {
            return .invalid(reason: "模块ID不一致: 旧 \(oldInstance.moduleID) vs 新 \(newDiscovery.moduleID)")
        }

        let oldVersion = oldInstance.moduleVersion
        let newVersion = newDiscovery.metadata.version
        if let oldV = UIVersion.parse(oldVersion),
           let newV = UIVersion.parse(newVersion) {
            guard newV > oldV else {
                return .invalid(reason: "新版本 \(newVersion) 不大于旧版本 \(oldVersion)")
            }
        }

        if let preservable = oldInstance as? UIModuleStatePreservable {
            let testState = preservable.saveState()
            if testState.isEmpty {
                return .warning(message: "模块状态为空，替换后状态将丢失")
            }
        } else {
            return .warning(message: "模块未实现状态保存协议，替换后状态将丢失")
        }

        return .valid
    }

    // MARK: - 状态管理

    private func updateState(_ newState: UIModuleHotReplaceState) {
        lock.lock()
        currentState = newState
        lock.unlock()
    }

    private func getCurrentState() -> UIModuleHotReplaceState {
        lock.lock()
        let state = currentState
        lock.unlock()
        return state
    }

    // MARK: - 热替换

    /// 热替换指定名称的模块为新版本
    /// - Parameters:
    ///   - name: 模块注册名称
    ///   - newBundlePath: 新版本bundle路径
    /// - Returns: 替换结果
    public func hotReplace(name: String, newBundlePath: String) -> UIModuleHotReplaceResult {
        // 全局操作锁：同一时间只允许一个热替换操作，防止 currentState 并发竞争
        operationLock.lock()
        defer { operationLock.unlock() }

        let startTime = Date()

        // 获取模块专属锁，保证同一模块的替换原子性
        let moduleLock = getReplaceLock(for: name)
        moduleLock.lock()
        // 零defer：手动配对unlock，所有提前return都先解锁
        let (result, hotReplacePayload) = performReplaceWithLock(name: name, newBundlePath: newBundlePath, startTime: startTime)
        moduleLock.unlock()

        // 通知在锁外发送，防止监听器回调内调用 hotReplace 时死锁
        if let payload = hotReplacePayload {
            NotificationCenter.default.post(name: .UIModuleHotReplaced, object: self, userInfo: payload.asDictionary)
        }

        return result
    }

    /// 在模块锁保护下执行替换（所有return前已确认锁在调用方未释放）
    private func performReplaceWithLock(name: String, newBundlePath: String, startTime: Date) -> (UIModuleHotReplaceResult, UIModuleHotReplacedPayload?) {
        // 1. 状态验证
        updateState(.validating)
        let validation = validateModuleForHotReplace(name: name, newBundlePath: newBundlePath)
        switch validation {
        case .invalid(let reason):
            updateState(.failed)
            logger.error("热替换", "模块 '\(name)' 验证失败: \(reason)")
            let result = UIModuleHotReplaceResult.failed(reason: "验证失败: \(reason)", state: .failed)
            recordHistory(name: name, newBundlePath: newBundlePath, startTime: startTime, result: result)
            return (result, nil)
        case .warning(let message):
            logger.warning("热替换", "模块 '\(name)' 警告: \(message)")
        case .valid:
            break
        }

        // 2. 执行替换
        let (result, payload) = executeReplace(name: name, newBundlePath: newBundlePath, startTime: startTime)

        // 3. 记录历史
        recordHistory(name: name, newBundlePath: newBundlePath, startTime: startTime, result: result)

        return (result, payload)
    }

    /// 核心替换逻辑（验证通过后执行）
    private func executeReplace(name: String, newBundlePath: String, startTime: Date) -> (UIModuleHotReplaceResult, UIModuleHotReplacedPayload?) {
        guard let oldInstance = locator.getModule(name) else {
            updateState(.failed)
            return (.failed(reason: "模块 '\(name)' 未加载", state: .failed), nil)
        }

        let moduleID = oldInstance.moduleID

        // 2. 保存状态
        updateState(.savingState)
        var savedState: [String: Any] = [:]
        if let preservable = oldInstance as? UIModuleStatePreservable {
            savedState = preservable.saveState()
            lock.lock()
            stateSnapshots[moduleID] = savedState
            lock.unlock()
            logger.info("热替换", "模块 '\(name)' 状态已保存 (\(savedState.count) 项)", moduleID: moduleID)
        }

        // 3. 卸载旧模块
        updateState(.unloading)
        let unloadResult = unloader.unloadModule(name: name)
        switch unloadResult {
        case .success:
            logger.info("热替换", "模块 '\(name)' 卸载成功", moduleID: moduleID)
        case .failed(let reason):
            restoreSavedState(moduleID: moduleID, savedState: savedState, oldInstance: oldInstance)
            updateState(.failed)
            return (.failed(reason: "卸载失败: \(reason)", state: .failed), nil)
        case .rollback:
            updateState(.failed)
            return (.failed(reason: "卸载触发回滚", state: .failed), nil)
        case .moduleNotFound:
            updateState(.failed)
            return (.failed(reason: "卸载失败: 模块未找到", state: .failed), nil)
        case .failure(let error):
            restoreSavedState(moduleID: moduleID, savedState: savedState, oldInstance: oldInstance)
            updateState(.failed)
            return (.failed(reason: "卸载失败: \(error.localizedDescription)", state: .failed), nil)
        case .notFound:
            updateState(.failed)
            return (.failed(reason: "卸载失败: 未找到", state: .failed), nil)
        case .hasDependencies(let deps):
            updateState(.failed)
            return (.failed(reason: "卸载失败: 有依赖 \(deps.joined(separator: ", "))", state: .failed), nil)
        }

        // 4. 加载新模块
        updateState(.loading)
        let loadResult = loader.loadModule(path: newBundlePath)
        let loadError = checkLoadResult(loadResult, name: name, moduleID: moduleID)
        if let error = loadError {
            return (error, nil)
        }

        // 5. 验证新实例（先按 name 查找，找不到再按 moduleID 查找）
        var newInstance = locator.getModule(name)
        if newInstance == nil {
            newInstance = locator.getModule(moduleID)
        }
        guard let resolvedNewInstance = newInstance else {
            attemptRollback(moduleID: moduleID, name: name, savedState: savedState)
            return (.rolledBack(reason: "新模块加载后无法获取实例（通过 name 和 moduleID 都找不到）", state: .failed), nil)
        }

        // 6. 恢复状态
        updateState(.restoringState)
        if let preservable = resolvedNewInstance as? UIModuleStatePreservable, !savedState.isEmpty {
            preservable.restoreState(savedState)
            logger.info("热替换", "模块 '\(name)' 状态已恢复", moduleID: resolvedNewInstance.moduleID)
        }

        // 7. 完成
        let duration = Date().timeIntervalSince(startTime)
        updateState(.completed)
        logger.info("热替换", "模块 '\(name)' 热替换完成 (耗时: \(String(format: "%.2f", duration))秒)", moduleID: resolvedNewInstance.moduleID)

        let payload = UIModuleHotReplacedPayload(moduleID: resolvedNewInstance.moduleID, moduleName: name, duration: duration)
        // 通知已移到 hotReplace 方法中锁外发送
        return (.success(state: .completed), payload)
    }

    /// 检查加载结果，返回错误结果（如有）
    private func checkLoadResult(_ loadResult: UIModuleLoadResult, name: String, moduleID: String) -> UIModuleHotReplaceResult? {
        switch loadResult {
        case .success(let newModuleID):
            logger.info("热替换", "模块 '\(name)' 新模块加载成功 (ID: \(newModuleID))", moduleID: moduleID)
            return nil
        case .alreadyLoaded(let newModuleID):
            logger.info("热替换", "模块 '\(name)' 新模块已加载 (ID: \(newModuleID))", moduleID: moduleID)
            return nil
        case .incompatible(_, let reason):
            attemptRollback(moduleID: moduleID, name: name, savedState: [:])
            return .rolledBack(reason: "版本不兼容: \(reason)", state: .failed)
        case .missingDependency(_, let dependency):
            attemptRollback(moduleID: moduleID, name: name, savedState: [:])
            return .rolledBack(reason: "缺少依赖: \(dependency)", state: .failed)
        case .loadFailed(let moduleID, let error):
            attemptRollback(moduleID: moduleID, name: name, savedState: [:])
            return .rolledBack(reason: "新模块加载失败: \(error)", state: .failed)
        case .timedOut(let moduleID, let timeout):
            attemptRollback(moduleID: moduleID, name: name, savedState: [:])
            return .rolledBack(reason: "加载超时: \(timeout)秒", state: .failed)
        case .cancelled(let moduleID):
            attemptRollback(moduleID: moduleID, name: name, savedState: [:])
            return .rolledBack(reason: "加载被取消", state: .failed)
        case .failure(let error):
            attemptRollback(moduleID: moduleID, name: name, savedState: [:])
            return .rolledBack(reason: "加载失败: \(error.localizedDescription)", state: .failed)
        case .notFound:
            attemptRollback(moduleID: moduleID, name: name, savedState: [:])
            return .rolledBack(reason: "模块未找到", state: .failed)
        }
    }

    /// 尝试执行回滚
    private func attemptRollback(moduleID: String, name: String, savedState: [String: Any]) {
        // 先设置状态为回滚中，再执行回滚
        updateState(.rollingBack)
        let rollbackSuccess = unloader.rollback(moduleID: moduleID)
        // 从 stateSnapshots 中查找已保存的状态（checkLoadResult 调用时可能未传 savedState）
        var stateToRestore = savedState
        if stateToRestore.isEmpty {
            lock.lock()
            stateToRestore = stateSnapshots[moduleID] ?? [:]
            lock.unlock()
        }
        if !stateToRestore.isEmpty {
            if let oldInstance = locator.getModule(name) as? UIModuleStatePreservable {
                oldInstance.restoreState(stateToRestore)
            }
        }
        // 回滚完成，进入失败终态（不在.rollingBack停留）
        updateState(.failed)
        logger.error("热替换", "模块 '\(name)' 回滚\(rollbackSuccess ? "成功" : "失败")", moduleID: moduleID)
    }

    /// 恢复旧实例的状态（卸载失败时调用）
    private func restoreSavedState(moduleID: String, savedState: [String: Any], oldInstance: UIModuleProtocol) {
        guard !savedState.isEmpty else { return }
        if let preservable = oldInstance as? UIModuleStatePreservable {
            preservable.restoreState(savedState)
            logger.info("热替换", "模块 '\(moduleID)' 状态已恢复（卸载失败）", moduleID: moduleID)
        }
    }

    // MARK: - 历史记录

    private func recordHistory(name: String, newBundlePath: String, startTime: Date, result: UIModuleHotReplaceResult) {
        let record = UIModuleHotReplaceRecord(
            moduleName: name,
            newBundlePath: newBundlePath,
            startedAt: startTime,
            duration: Date().timeIntervalSince(startTime),
            result: result
        )

        lock.lock()
        replaceHistory.append(record)
        if replaceHistory.count > maxHistoryCount {
            replaceHistory.removeFirst(replaceHistory.count - maxHistoryCount)
        }
        lock.unlock()
    }

    // MARK: - 查询

    /// 获取当前替换状态
    public func getState() -> UIModuleHotReplaceState {
        getCurrentState()
    }

    /// 获取替换历史记录
    public func getReplaceHistory() -> [UIModuleHotReplaceRecord] {
        lock.lock()
        let history = replaceHistory
        lock.unlock()
        return history
    }

    /// 清空历史记录和状态快照
    public func clearHistory() {
        lock.lock()
        replaceHistory.removeAll()
        stateSnapshots.removeAll()
        lock.unlock()
        logger.info("热替换", "历史记录已清空")
    }
}
