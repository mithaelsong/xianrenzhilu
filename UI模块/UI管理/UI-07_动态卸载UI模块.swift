// MARK: - UI-06: 动态卸载UI模块
// 功能编号: UI-07
// 版本: 2.0
// 职责: 不重启应用卸载UI模块，调用willUnload、清理资源、支持回滚、架构解耦
// 依赖: UI-05 注册表, UI-08 定位器, UI-12 日志

import Foundation
import AppKit

// 独立编译存根

// 类型 UIModuleRegistry 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleLocator 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleUnloader 已迁移到 UI-02_公共类型定义.swift

// MARK: - 测试
internal func test_UI06() {
    print("\n=== UI-06 卸载器模块测试 ===\n")
    let unloader = UIModuleUnloader.shared
    let registry = UIModuleRegistry.shared
    let locator = UIModuleLocator.shared

    // 创建测试模块类
// 类型 UITestModule 已迁移到 UI-02_公共类型定义.swift

    // 清理初始状态
    registry.unregister(name: "TestUnloaderModule")
    registry.unregister(name: "NonUnloadableModule")
    registry.unregister(name: "DependentModule")
    unloader.clearAllBackups()
    locator.clearCache()

    // MARK: 测试1: 正常卸载
    print("🧪 测试1: 正常卸载")
    let module1 = UITestModule(id: "test.unloader.01", name: "卸载测试模块1")
    registry.register(instance: module1, name: "TestUnloaderModule")
    guard locator.getModule("TestUnloaderModule") != nil else {
        fatalError("❌ 测试1准备失败: 模块未注册成功")
    }
    let result1 = unloader.unloadModule(name: "TestUnloaderModule")
    guard case .success = result1 else {
        fatalError("❌ 测试1失败: 卸载应返回success，实际: \(result1)")
    }
    guard module1.willUnloadCalled else {
        fatalError("❌ 测试1失败: willUnload 应被调用")
    }
    guard locator.getModule("TestUnloaderModule") == nil else {
        fatalError("❌ 测试1失败: 卸载后模块应不可定位")
    }
    print("✅ 测试1通过: 正常卸载成功")
    
    // MARK: 测试2: 回滚
    print("\n🧪 测试2: 回滚")
    let rollbackResult = unloader.rollback(moduleID: "test.unloader.01")
    guard rollbackResult else {
        fatalError("❌ 测试2失败: 回滚应返回true")
    }
    guard locator.getModule("TestUnloaderModule") != nil else {
        fatalError("❌ 测试2失败: 回滚后模块应恢复")
    }
    print("✅ 测试2通过: 回滚成功")
    
    // MARK: 测试3: 重复回滚失败
    print("\n🧪 测试3: 重复回滚失败")
    let secondRollback = unloader.rollback(moduleID: "test.unloader.01")
    guard !secondRollback else {
        fatalError("❌ 测试3失败: 重复回滚应返回false")
    }
    print("✅ 测试3通过: 重复回滚失败")
    
    // MARK: 测试4: 卸载不可卸载模块
    print("\n🧪 测试4: 卸载不可卸载模块")
    let nonUnloadable = UITestModule(id: "test.unloader.02", name: "不可卸载模块", unloadable: false)
    registry.register(instance: nonUnloadable, name: "NonUnloadableModule")
    let result4 = unloader.unloadModule(name: "NonUnloadableModule")
    guard case .failed(let reason4) = result4, reason4 == "模块不可卸载" else {
        fatalError("❌ 测试4失败: 不可卸载模块应返回 failed(模块不可卸载)")
    }
    print("✅ 测试4通过: 不可卸载模块返回失败")
    
    // MARK: 测试5: 卸载未加载模块
    print("\n🧪 测试5: 卸载未加载模块")
    let result5 = unloader.unloadModule(name: "NotLoadedModule")
    guard case .failed(let reason5) = result5, reason5 == "模块未加载" else {
        fatalError("❌ 测试5失败: 未加载模块应返回 failed(模块未加载)")
    }
    print("✅ 测试5通过: 未加载模块返回失败")

    // MARK: 测试5b: 卸载空名称
    print("\n🧪 测试5b: 卸载空名称")
    let result5b = unloader.unloadModule(name: "")
    guard case .moduleNotFound = result5b else {
        fatalError("❌ 测试5b失败: 空名称应返回 .moduleNotFound，实际: \(result5b)")
    }
    print("✅ 测试5b通过: 空名称返回 .moduleNotFound")
    
    // MARK: 测试6: 备份计数
    print("\n🧪 测试6: 备份计数")
    let module6 = UITestModule(id: "test.unloader.06", name: "备份测试")
    registry.register(instance: module6, name: "BackupTestModule")
    _ = unloader.unloadModule(name: "BackupTestModule")
    guard unloader.backupCount() >= 1 else {
        fatalError("❌ 测试6失败: 卸载后应有备份")
    }
    unloader.clearAllBackups()
    guard unloader.backupCount() == 0 else {
        fatalError("❌ 测试6失败: 清空后备份应=0")
    }
    print("✅ 测试6通过: 备份计数")
    
    // MARK: 测试7: 无依赖时正常卸载（依赖检查功能因架构解耦暂未启用）
    print("\n🧪 测试7: 无依赖时正常卸载（依赖检查暂未启用）")
    registry.unregister(name: "TestUnloaderModule_A")
    registry.unregister(name: "TestUnloaderModule_B")
    locator.clearCache()
    
    let moduleA = UITestModule(id: "test.unloader.A", name: "模块A")
    let moduleB = UITestModule(id: "test.unloader.B", name: "模块B")
    registry.register(instance: moduleA, name: "TestUnloaderModule_A")
    registry.register(instance: moduleB, name: "TestUnloaderModule_B")
    
    let resultDep = unloader.unloadModule(name: "TestUnloaderModule_A")
    guard case .success = resultDep else {
        fatalError("❌ 测试7失败: 不存在依赖时卸载应成功")
    }
    locator.clearCache()
    _ = unloader.rollback(moduleID: "test.unloader.A")
    registry.unregister(name: "TestUnloaderModule_B")
    locator.clearCache()
    print("✅ 测试7通过: 无依赖时正常卸载")
    
    // MARK: 测试8: 并发卸载
    print("\n🧪 测试8: 并发卸载")
    let group = DispatchGroup()
    let concQueue = DispatchQueue(label: "test.unloader.concurrent", attributes: .concurrent)
    
    // 先注册10个模块
    var concModules: [UITestModule] = []
    for i in 0..<10 {
        let mod = UITestModule(id: "concurrent.unloader.\(i)", name: "并发卸载模块\(i)")
        registry.register(instance: mod, name: "ConcurrentModule\(i)")
        concModules.append(mod)
    }
    locator.clearCache()
    
    // 并发卸载
    for i in 0..<10 {
        group.enter()
        concQueue.async {
            _ = unloader.unloadModule(name: "ConcurrentModule\(i)")
            group.leave()
        }
    }
    group.wait()
    
    // 验证全部卸载完成
    for i in 0..<10 {
        guard locator.getModule("ConcurrentModule\(i)") == nil else {
            fatalError("❌ 测试8失败: 并发卸载后模块ConcurrentModule\(i)仍存在")
        }
    }
    unloader.clearAllBackups()
    print("✅ 测试8通过: 10个模块并发卸载（无崩溃、无残留）")

    // MARK: 测试9: 批量卸载空数组
    print("\n🧪 测试9: 批量卸载空数组")
    let result9 = unloader.batchUnload(names: [])
    guard result9.success == 0 && result9.failed == 0 && result9.details.isEmpty else {
        fatalError("❌ 测试9失败: 空数组应返回 (0, 0, [])，实际: \(result9)")
    }
    print("✅ 测试9通过: 空数组批量卸载返回正确")
    
    // MARK: 清理
    registry.unregister(name: "TestUnloaderModule")
    registry.unregister(name: "NonUnloadableModule")
    registry.unregister(name: "TestUnloaderModule_A")
    registry.unregister(name: "TestUnloaderModule_B")
    registry.unregister(name: "BackupTestModule")
    unloader.clearAllBackups()
    locator.clearCache()

    print("\n=== 全部 UI-06 卸载器模块测试通过 ✅ ===")
}


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UITestModule
    class UITestModule: UIModuleProtocol , @unchecked Sendable{
        required init() { moduleID = ""; moduleName = ""; isUnloadable = true }
        let moduleID: String
        let moduleName: String
        let moduleVersion = "2.0"
        let moduleDescription = "Test module"
        let isUnloadable: Bool
        var willUnloadCalled = false
        init(id: String, name: String, unloadable: Bool = true) {
            moduleID = id; moduleName = name; isUnloadable = unloadable
        }
        func start(context: Any?) throws {}
        func stop() {}
        func pause() {}
        func resume() {}
        func willUnload() { willUnloadCalled = true }
        func didUnload() {}
    }

// MARK: - 迁回自 UI-02：class UIModuleUnloader
public final class UIModuleUnloader : @unchecked Sendable {
    public static let shared = UIModuleUnloader()

    private let lock = NSLock()
    private let logger = UILoadingLogManager.shared
    private let registry = UIModuleRegistry.shared
    private let locator = UIModuleLocator.shared

    /// 卸载中的模块备份（用于回滚）
    private var unloadBackups: [String: (instance: UIModuleProtocol, name: String)] = [:]

    /// 批量卸载进行标志
    private var batchInProgress: Bool = false

    private init() {}

    // MARK: - 依赖检查（与UI-01解耦）

    /// 检查是否有其他模块依赖目标模块。
    /// 注意：依赖信息存储在 UIModuleDiscoveryResult.metadata.dependencies 中，
    /// 由 UI-01 扫描器提供，UI-06 不持有该数据。在架构上，依赖关系应由外部管理器管理。
    /// 因此当前实现始终返回空数组（相当于跳过了依赖检查）。
    /// 如需真实依赖检查，需要引入依赖关系图管理器。
    private func hasDependents(moduleID: String) -> [String] {
        // 依赖关系由外部管理器维护，UI-06 不持有依赖数据
        return []
    }

    /// 判断模块是否被其他模块依赖。
    /// 与 hasDependents 同理，UI-06 不持有依赖数据，始终返回 false。
    private func isReferencedByOtherModules(moduleID: String) -> Bool {
        // 依赖关系由外部管理器维护，UI-06 不持有依赖数据
        return false
    }

    // MARK: - 卸载模块

    /// 按名称卸载单个UI模块
    /// - Parameter name: 模块注册名或别名
    /// - Returns: 卸载结果（成功/失败/回滚）
    public func unloadModule(name: String) -> UIModuleUnloadResult {
        guard !name.isEmpty else {
            logger.warning("卸载器", "卸载失败：模块名为空")
            return .moduleNotFound
        }

        // 1. 获取实例
        guard let instance = locator.getModule(name) else {
            logger.warning("卸载器", "卸载失败：模块 '\(name)' 未加载")
            return .failed(reason: "模块未加载")
        }

        let moduleID = instance.moduleID

        // 2. 检查是否可卸载
        guard instance.isUnloadable else {
            logger.warning("卸载器", "模块 '\(name)' (ID: \(moduleID)) 不可卸载")
            return .failed(reason: "模块不可卸载")
        }

        // 3. 检查依赖
        let dependents = isReferencedByOtherModules(moduleID: moduleID)
        if dependents {
            logger.warning("卸载器", "模块 '\(name)' 被其他模块依赖，无法卸载")
            return .failed(reason: "被其他模块依赖")
        }

        // 4. 备份实例（锁内保护共享数据）
        lock.lock()
        unloadBackups[moduleID] = (instance: instance, name: name)
        lock.unlock()

        // 5. 调用 willUnload 回调
        try? instance.willUnload()

        // 6. 从注册表移除
        registry.unregister(name: name)

        // 7. 清理定位器缓存
        locator.clearCache()

        // 8. 清理通知监听
        NotificationCenter.default.removeObserver(instance)

        // 9. 发送卸载通知（锁外）
        let event = UIModuleUnloadPayload(moduleID: moduleID, moduleName: name, timestamp: Date())
        NotificationCenter.default.post(name: .UIModuleDidUnload, object: event)

        logger.info("卸载器", "模块 '\(name)' (ID: \(moduleID)) 卸载成功")
        return .success
    }

    // MARK: - 回滚

    /// 回滚已卸载的模块
    /// - Parameter moduleID: 模块ID
    /// - Returns: 是否成功
    @discardableResult
    public func rollback(moduleID: String) -> Bool {
        return performRollback(moduleID: moduleID)
    }

    /// 内部回滚实现
    private func performRollback(moduleID: String) -> Bool {
        lock.lock()
        guard let backup = unloadBackups[moduleID] else {
            lock.unlock()
            logger.warning("卸载器", "回滚失败：找不到模块 '\(moduleID)' 的备份")
            return false
        }
        unloadBackups.removeValue(forKey: moduleID)
        lock.unlock()

        // 重新注册到注册表
        registry.register(instance: backup.instance, name: backup.name)

        // 清理定位器缓存
        locator.clearCache()

        // 发送回滚通知（锁外）
        let event = UIModuleRollbackPayload(moduleID: moduleID, moduleName: backup.name, timestamp: Date())
        NotificationCenter.default.post(name: .UIModuleDidRollback, object: event)

        logger.info("卸载器", "模块 '\(backup.name)' (ID: \(moduleID)) 已回滚")
        return true
    }

    // MARK: - 批量卸载

    /// 按名称列表批量卸载模块，按依赖关系排序后逐个卸载
    /// - Parameter names: 模块名称列表
    /// - Returns: (成功数, 失败数, 失败详情)
    public func batchUnload(names: [String]) -> (success: Int, failed: Int, details: [(name: String, reason: String)]) {
        guard !names.isEmpty else {
            return (0, 0, [])
        }

        lock.lock()
        guard !batchInProgress else {
            lock.unlock()
            logger.warning("卸载器", "批量卸载已在进行中")
            return (0, names.count, names.map { ($0, "批量卸载冲突") })
        }
        batchInProgress = true
        lock.unlock()

        var successCount = 0
        var failCount = 0
        var failDetails: [(name: String, reason: String)] = []

        let sortedNames = sortByDependency(names: names)

        for name in sortedNames {
            let result = unloadModule(name: name)
            switch result {
            case .success:
                successCount += 1
            case .failed(let reason):
                failCount += 1
                failDetails.append((name, reason))
            case .rollback:
                failCount += 1
                failDetails.append((name, "触发回滚"))
            case .moduleNotFound:
                failCount += 1
                failDetails.append((name, "模块不存在"))
            case .failure(let error):
                failCount += 1
                failDetails.append((name, error.localizedDescription))
            case .notFound:
                failCount += 1
                failDetails.append((name, "未找到"))
            case .hasDependencies(let deps):
                failCount += 1
                failDetails.append((name, "有依赖: \(deps.joined(separator: ", "))"))
            }
        }

        lock.lock()
        batchInProgress = false
        lock.unlock()

        logger.info("卸载器", "批量卸载完成: \(successCount) 成功, \(failCount) 失败")
        return (successCount, failCount, failDetails)
    }

    /// 按模块被依赖数排序：被依赖最少的先卸载
    /// 注意：当前依赖检查功能已禁用（见 hasDependents 注释），
    /// 所有模块的被依赖数均为 0，此排序实际上是保留原序。
    /// 待引入依赖关系图管理器后，此函数才会生效。
    private func sortByDependency(names: [String]) -> [String] {
        // 用字典缓存 countDependents 的计算结果
        var counts: [String: Int] = [:]
        for name in names {
            counts[name] = countDependents(name: name)
        }
        return names.sorted { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
    }

    /// 计算指定模块被多少个其他模块依赖
    private func countDependents(name: String) -> Int {
        guard let instance = locator.getModule(name) else { return 0 }
        return hasDependents(moduleID: instance.moduleID).count
    }

    // MARK: - 备份管理

    /// 清空所有备份（用于测试或重置）
    public func clearAllBackups() {
        lock.lock()
        unloadBackups.removeAll()
        lock.unlock()
    }

    /// 查询当前是否有备份
    /// - Returns: 备份数量
    public func backupCount() -> Int {
        lock.lock()
        let count = unloadBackups.count
        lock.unlock()
        return count
    }
}

// MARK: - 迁回自 UI-02：extension UIModuleRegistry
public extension UIModuleRegistry {
    func register(module: UIModuleProtocol, name: String) {
        register(instance: module, name: name, aliases: [], priority: 0)
    }
}

// MARK: - 从 UI-02 正确迁回：class UIModuleRollbackManager
public final class UIModuleRollbackManager : @unchecked Sendable {
    public static let shared = UIModuleRollbackManager()
    private init() {}
}

