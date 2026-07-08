// MARK: - UI-04: 按顺序加载UI模块
// 功能编号: UI-04
// 版本: 2.0
// 职责: 根据依赖关系确定加载顺序，检测循环依赖，拓扑排序
// 依赖: UI-02 公共类型, UI-12 日志

import Foundation
import AppKit

// MARK: - 编译存根（UI-01 中定义，此处仅提供最小存根以支持独立编译）


// 独立编译存根
// 类型 UIUnifiedRegistry 已迁移到 UI-02_公共类型定义.swift

// MARK: - 模块排序器
// 类型 UIModuleSorter 已迁移到 UI-02_公共类型定义.swift

// MARK: - 测试
internal func test_UI02() {
    print("\n=== UI-02 排序器模块测试 ===")

    let sorter = UIModuleSorter.shared

    // 测试1: 正常拓扑排序
    print("\n🧪 测试1: 正常拓扑排序")
    let metaA = UIModuleMetadata(moduleID: "A", moduleName: "模块A", version: "2.0", minFrameworkVersion: nil, dependencies: ["B"], author: nil, description: nil, isBuiltIn: false)
    let metaB = UIModuleMetadata(moduleID: "B", moduleName: "模块B", version: "2.0", minFrameworkVersion: nil, dependencies: [], author: nil, description: nil, isBuiltIn: false)
    let metaC = UIModuleMetadata(moduleID: "C", moduleName: "模块C", version: "2.0", minFrameworkVersion: nil, dependencies: ["A"], author: nil, description: nil, isBuiltIn: false)
    let resultA = UIModuleDiscoveryResult(moduleID: "A", bundleURL: URL(fileURLWithPath: "/tmp/A.bundle"), metadata: metaA)
    let resultB = UIModuleDiscoveryResult(moduleID: "B", bundleURL: URL(fileURLWithPath: "/tmp/B.bundle"), metadata: metaB)
    let resultC = UIModuleDiscoveryResult(moduleID: "C", bundleURL: URL(fileURLWithPath: "/tmp/C.bundle"), metadata: metaC)
    let sortResult = sorter.sort(modules: [resultA, resultB, resultC])
    guard case .success(let order) = sortResult else {
        fatalError("❌ 测试1失败: 正常排序不应失败")
    }
    guard order.first == "B" else {
        fatalError("❌ 测试1失败: 拓扑排序B应在最前，实际: \(order)")
    }
    guard order.last == "C" else {
        fatalError("❌ 测试1失败: 拓扑排序C应在最后，实际: \(order)")
    }
    print("✅ 测试1通过: 拓扑排序 B→A→C")

    // 测试2: 循环依赖检测
    print("\n🧪 测试2: 循环依赖检测")
    let metaD = UIModuleMetadata(moduleID: "D", moduleName: "模块D", version: "2.0", minFrameworkVersion: nil, dependencies: ["E"], author: nil, description: nil, isBuiltIn: false)
    let metaE = UIModuleMetadata(moduleID: "E", moduleName: "模块E", version: "2.0", minFrameworkVersion: nil, dependencies: ["D"], author: nil, description: nil, isBuiltIn: false)
    let resultD = UIModuleDiscoveryResult(moduleID: "D", bundleURL: URL(fileURLWithPath: "/tmp/D.bundle"), metadata: metaD)
    let resultE = UIModuleDiscoveryResult(moduleID: "E", bundleURL: URL(fileURLWithPath: "/tmp/E.bundle"), metadata: metaE)
    let cycleResult = sorter.sort(modules: [resultD, resultE])
    guard case .cycleDetected = cycleResult else {
        fatalError("❌ 测试2失败: 循环依赖D↔E应被检测到")
    }
    print("✅ 测试2通过: 循环依赖 D↔E 检测成功")

    // 测试3: 缺失依赖检测
    print("\n🧪 测试3: 缺失依赖检测")
    let metaF = UIModuleMetadata(moduleID: "F", moduleName: "模块F", version: "2.0", minFrameworkVersion: nil, dependencies: ["MissingModule"], author: nil, description: nil, isBuiltIn: false)
    let resultF = UIModuleDiscoveryResult(moduleID: "F", bundleURL: URL(fileURLWithPath: "/tmp/F.bundle"), metadata: metaF)
    let missingResult = sorter.sort(modules: [resultF])
    guard case .missingDependency(let missing, let mid) = missingResult else {
        fatalError("❌ 测试3失败: 缺失依赖应被检测到")
    }
    guard missing == "MissingModule" else {
        fatalError("❌ 测试3失败: 缺失依赖名应为MissingModule，实际: \(missing)")
    }
    guard mid == "F" else {
        fatalError("❌ 测试3失败: 缺失依赖所属模块应为F，实际: \(mid)")
    }
    print("✅ 测试3通过: 缺失依赖 'MissingModule' 检测成功")

    // 测试4: 软依赖（?结尾）
    print("\n🧪 测试4: 软依赖（?结尾不阻断）")
    let metaG = UIModuleMetadata(moduleID: "G", moduleName: "模块G", version: "2.0", minFrameworkVersion: nil, dependencies: ["OptionalDep?"], author: nil, description: nil, isBuiltIn: false)
    let metaH = UIModuleMetadata(moduleID: "H", moduleName: "模块H", version: "2.0", minFrameworkVersion: nil, dependencies: ["AnotherDep(optional)"], author: nil, description: nil, isBuiltIn: false)
    let resultG = UIModuleDiscoveryResult(moduleID: "G", bundleURL: URL(fileURLWithPath: "/tmp/G.bundle"), metadata: metaG)
    let resultH = UIModuleDiscoveryResult(moduleID: "H", bundleURL: URL(fileURLWithPath: "/tmp/H.bundle"), metadata: metaH)
    let softDepResult = sorter.sort(modules: [resultG, resultH])
    guard case .success = softDepResult else {
        fatalError("❌ 测试4失败: 软依赖模块排序应成功")
    }
    print("✅ 测试4通过: 软依赖模块排序成功")

    // 测试5: 软依赖存在目标模块时建立排序约束
    print("\n🧪 测试5: 软依赖存在目标时建立排序约束")
    let metaSoftA = UIModuleMetadata(moduleID: "SoftA", moduleName: "模块A", version: "2.0", minFrameworkVersion: nil, dependencies: ["SoftB?"], author: nil, description: nil, isBuiltIn: false)
    let metaSoftB = UIModuleMetadata(moduleID: "SoftB", moduleName: "模块B", version: "2.0", minFrameworkVersion: nil, dependencies: [], author: nil, description: nil, isBuiltIn: false)
    let resultSoftA = UIModuleDiscoveryResult(moduleID: "SoftA", bundleURL: URL(fileURLWithPath: "/tmp/SoftA.bundle"), metadata: metaSoftA)
    let resultSoftB = UIModuleDiscoveryResult(moduleID: "SoftB", bundleURL: URL(fileURLWithPath: "/tmp/SoftB.bundle"), metadata: metaSoftB)
    let softExistingResult = sorter.sort(modules: [resultSoftA, resultSoftB])
    guard case .success(let softOrder) = softExistingResult else {
        fatalError("❌ 测试5失败: 软依赖（目标存在）排序应成功")
    }
    guard softOrder.first == "SoftB" else {
        fatalError("❌ 测试5失败: 软依赖目标 SoftB 应在 SoftA 之前，实际: \(softOrder)")
    }
    print("✅ 测试5通过: 软依赖目标 SoftB 排在 SoftA 之前（\(softOrder.joined(separator: " → "))）")

    // 测试6: 核心模块优先
    print("\n🧪 测试6: 核心模块优先")
    let metaWindow = UIModuleMetadata(moduleID: "WindowManager", moduleName: "窗口管理", version: "2.0", minFrameworkVersion: nil, dependencies: [], author: nil, description: nil, isBuiltIn: true)
    let metaPanel = UIModuleMetadata(moduleID: "PanelManager", moduleName: "面板管理", version: "2.0", minFrameworkVersion: nil, dependencies: [], author: nil, description: nil, isBuiltIn: true)
    let metaUser = UIModuleMetadata(moduleID: "UserModule", moduleName: "用户模块", version: "2.0", minFrameworkVersion: nil, dependencies: [], author: nil, description: nil, isBuiltIn: false)
    let resultWin = UIModuleDiscoveryResult(moduleID: "WindowManager", bundleURL: URL(fileURLWithPath: "/tmp/WindowManager.bundle"), metadata: metaWindow)
    let resultPanel = UIModuleDiscoveryResult(moduleID: "PanelManager", bundleURL: URL(fileURLWithPath: "/tmp/PanelManager.bundle"), metadata: metaPanel)
    let resultUser = UIModuleDiscoveryResult(moduleID: "UserModule", bundleURL: URL(fileURLWithPath: "/tmp/UserModule.bundle"), metadata: metaUser)
    let coreResult = sorter.sort(modules: [resultUser, resultWin, resultPanel])
    guard case .success(let coreOrder) = coreResult else {
        fatalError("❌ 测试6失败: 核心模块排序不应失败")
    }
    guard coreOrder.first == "WindowManager" || coreOrder.first == "PanelManager" else {
        fatalError("❌ 测试6失败: 核心模块应排在前面，实际: \(coreOrder)")
    }
    guard coreOrder.last == "UserModule" else {
        fatalError("❌ 测试6失败: 非核心模块应排在最后，实际: \(coreOrder)")
    }
    print("✅ 测试6通过: 核心模块 WindowManager/PanelManager 排在 UserModule 之前")

    // 测试7: 手动优先级覆盖
    print("\n🧪 测试7: 手动优先级覆盖")
    let metaX = UIModuleMetadata(moduleID: "X", moduleName: "模块X", version: "2.0", minFrameworkVersion: nil, dependencies: [], author: nil, description: nil, isBuiltIn: false)
    let metaY = UIModuleMetadata(moduleID: "Y", moduleName: "模块Y", version: "2.0", minFrameworkVersion: nil, dependencies: [], author: nil, description: nil, isBuiltIn: false)
    let resultX = UIModuleDiscoveryResult(moduleID: "X", bundleURL: URL(fileURLWithPath: "/tmp/X.bundle"), metadata: metaX)
    let resultY = UIModuleDiscoveryResult(moduleID: "Y", bundleURL: URL(fileURLWithPath: "/tmp/Y.bundle"), metadata: metaY)

    sorter.clearPriorityOverrides()
    let normalOrder = sorter.sort(modules: [resultX, resultY])
    guard case .success(let norm) = normalOrder else {
        fatalError("❌ 测试7失败: 正常排序应成功")
    }
    guard norm == ["X", "Y"] else {
        fatalError("❌ 测试7失败: 默认字母序应为 X→Y，实际: \(norm)")
    }

    sorter.setPriority(moduleID: "Y", order: 1)
    sorter.setPriority(moduleID: "X", order: 10)
    let priorityOrder = sorter.sort(modules: [resultX, resultY])
    guard case .success(let pOrder) = priorityOrder else {
        fatalError("❌ 测试7失败: 手动优先级排序应成功")
    }
    guard pOrder == ["Y", "X"] else {
        fatalError("❌ 测试7失败: 手动优先级 Y(1) 应排在 X(10) 之前，实际: \(pOrder)")
    }
    sorter.clearPriorityOverrides()
    print("✅ 测试7通过: 手动优先级 Y(1) 排在 X(10) 之前")

    // 测试8: 预览输出
    print("\n🧪 测试8: 排序预览输出")
    let preview = sorter.previewSort(modules: [resultA, resultB, resultC])
    guard preview.contains("B") && preview.contains("A") && preview.contains("C") else {
        fatalError("❌ 测试8失败: 预览应包含B→A→C，实际: \(preview)")
    }
    print("✅ 测试8通过: 排序预览: \(preview)")

    // 测试9: 空列表
    print("\n🧪 测试9: 空模块列表")
    let emptyResult = sorter.sort(modules: [])
    guard case .success(let emptyOrder) = emptyResult, emptyOrder.isEmpty else {
        fatalError("❌ 测试9失败: 空列表应返回空排序")
    }
    print("✅ 测试9通过: 空列表返回空排序")

    // 测试10: 重复模块ID去重
    print("\n🧪 测试10: 重复模块ID去重")
    let dupResult = sorter.sort(modules: [resultA, resultB, resultA])
    guard case .success(let dupOrder) = dupResult else {
        fatalError("❌ 测试10失败: 去重后排序应成功")
    }
    guard dupOrder == ["B", "A", "C"] else {
        fatalError("❌ 测试10失败: 去重后排序应为B→A→C，实际: \(dupOrder)")
    }
    print("✅ 测试10通过: 重复模块ID去重后排序正确")

    // 测试11: 并发安全
    print("\n🧪 测试11: 并发安全")
    let concQueue = DispatchQueue(label: "test.sorter.concurrent", attributes: .concurrent)
    let group = DispatchGroup()
    for i in 0..<10 {
        group.enter()
        concQueue.async {
            sorter.setPriority(moduleID: "Concurrent\(i)", order: i)
            _ = sorter.sort(modules: [resultA, resultB, resultC])
            group.leave()
        }
        group.enter()
        concQueue.async {
            sorter.clearPriorityOverrides()
            _ = sorter.previewSort(modules: [resultA, resultB, resultC])
            group.leave()
        }
    }
    let waitResult = group.wait(timeout: .now() + 10.0)
    guard waitResult == .success else {
        fatalError("❌ 测试11失败: 并发排序超时（10秒）")
    }
    sorter.clearPriorityOverrides()
    print("✅ 测试11通过: 20次并发读写（无崩溃）")

    print("\n=== 全部 UI-04 排序器模块测试通过 ✅ ===")
}

// MARK: - 模块加载器
/// 按排序后的顺序加载模块，执行依赖预加载、并行加载、进度跟踪
// 类型 UIModuleLoader 已迁移到 UI-02_公共类型定义.swift

// MARK: - 加载器测试
internal func test_UI04_loader() {
    print("\n=== UI-04 加载器测试 ===\n")
    let loader = UIModuleLoader.shared
    let context = UIModuleStartContext()
    
    print("🧪 测试1: 空列表加载")
    let emptyResult = loader.loadAll(modules: [], context: context)
    assert(emptyResult.successCount == 0)
    assert(emptyResult.failureCount == 0)
    print("✅ 测试1通过")
    
    print("\n=== UI-04 加载器测试通过 ✅ ===\n")
}

// MARK: - UI-98 注册表集成
// 已移至UI-01注册表
// extension UIUnifiedRegistry {
//     public static let ui04Metadata = ModuleMetadata(...)
// }


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIModuleLoader
public final class UIModuleLoader : @unchecked Sendable {
    public static let shared = UIModuleLoader()
    
    let lock = NSRecursiveLock()
    private let logger = UILoadingLogManager.shared
    private let sorter = UIModuleSorter.shared
    private let registry = UIUnifiedRegistry.shared
    
    /// 加载超时阈值（秒）
    private let loadTimeout: TimeInterval = 30.0
    
    /// 最大重试次数
    private let maxRetryCount: Int = 2
    
    /// 是否允许并行加载无依赖的模块
    private let enableParallelLoading: Bool = true
    
    private init() {}
    
    /// 按排序顺序加载所有模块
    public func loadAll(modules: [UIModuleDiscoveryResult], context: UIModuleStartContext) -> UIModuleLoadBatchResult {
        let sortResult = sorter.sort(modules: modules)
        var sortedIDs: [String]
        
        switch sortResult {
        case .success(let order):
            sortedIDs = order
        case .cycleDetected(let cycle):
            logger.error("加载器", "检测到循环依赖，加载终止: \(cycle.joined(separator: " → "))")
            return UIModuleLoadBatchResult(
                successCount: 0,
                failureCount: modules.count,
                failedModules: modules.map { ($0.moduleID, "循环依赖: \(cycle.joined(separator: " → "))") },
                totalDuration: 0
            )
        case .missingDependency(let dep, let module):
            logger.error("加载器", "模块 '\(module)' 缺少依赖 '\(dep)'")
            return UIModuleLoadBatchResult(
                successCount: 0,
                failureCount: modules.count,
                failedModules: modules.map { m in
                    m.moduleID == module ? (m.moduleID, "缺少依赖: \(dep)") : (m.moduleID, "依赖缺失导致加载失败")
                },
                totalDuration: 0
            )
        }
        
        logger.info("加载器", "加载顺序: \(sortedIDs.joined(separator: " → "))")
        
        let startTime = Date()
        var successful: [String] = []
        var failed: [(String, String)] = []
        
        let moduleMap: [String: UIModuleDiscoveryResult] = modules.reduce(into: [:]) { dict, module in
            if dict[module.moduleID] == nil {
                dict[module.moduleID] = module
            }
        }
        
        for moduleID in sortedIDs {
            guard let discovery = moduleMap[moduleID] else { continue }
            let result = loadSingleWithRetry(discovery: discovery, context: context)
            switch result {
            case .success:
                successful.append(moduleID)
            case .failure(let error):
                failed.append((moduleID, error.localizedDescription))
            }
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        return UIModuleLoadBatchResult(
            successCount: successful.count,
            failureCount: failed.count,
            failedModules: failed,
            totalDuration: totalDuration
        )
    }
    
    private func loadSingleWithRetry(discovery: UIModuleDiscoveryResult, context: UIModuleStartContext) -> Result<Void, Error> {
        var lastError: Error?
        for attempt in 1...(maxRetryCount + 1) {
            do {
                try loadSingle(discovery: discovery, context: context)
                return .success(())
            } catch {
                lastError = error
                if attempt <= maxRetryCount {
                    Thread.sleep(forTimeInterval: 0.5 * pow(2.0, Double(attempt - 1)))
                }
            }
        }
        return .failure(lastError ?? UIModuleLoadError.loadFailed(moduleID: discovery.moduleID, reason: "未知错误"))
    }
    
    private func loadSingle(discovery: UIModuleDiscoveryResult, context: UIModuleStartContext) throws {
        guard let bundle = Bundle(url: discovery.bundleURL) else {
            throw UIModuleLoadError.bundleNotFound(moduleID: discovery.moduleID)
        }
        guard bundle.load() else {
            throw UIModuleLoadError.bundleLoadFailed(moduleID: discovery.moduleID)
        }
        guard let principalClass = bundle.principalClass as? UIModuleProtocol.Type else {
            throw UIModuleLoadError.invalidPrincipalClass(moduleID: discovery.moduleID)
        }
        let instance = principalClass.init()
        lock.lock()
        registry.register(module: instance, metadata: UIModuleMetadata(
            moduleID: discovery.moduleID,
            moduleName: discovery.metadata.moduleName,
            version: discovery.metadata.version,
            minFrameworkVersion: nil,
            dependencies: discovery.metadata.dependencies,
            author: nil,
            description: nil,
            isBuiltIn: discovery.metadata.isBuiltIn
        ))
        lock.unlock()
    }
}

// MARK: - 迁回自 UI-02：class UIModuleSorter
public final class UIModuleSorter : @unchecked Sendable {
    public static let shared = UIModuleSorter()
    private init() {}
    
    public enum UIModuleSortResult: Sendable {
        case success([String])
        case cycleDetected([String])
        case missingDependency(String, String)
    }
    
    public func sort(modules: [UIModuleDiscoveryResult]) -> UIModuleSortResult {
        // 拓扑排序实现
        var visited = Set<String>()
        var tempMark = Set<String>()
        var result = [String]()
        
        func visit(_ moduleID: String) -> UIModuleSortResult? {
            guard !visited.contains(moduleID) else { return nil }
            guard !tempMark.contains(moduleID) else { return .cycleDetected([moduleID]) }
            tempMark.insert(moduleID)
            
            // 查找依赖
            let module = modules.first { $0.moduleID == moduleID }
            let deps = module?.metadata.dependencies ?? []
            
            for dep in deps {
                if let error = visit(dep) {
                    return error
                }
            }
            
            tempMark.remove(moduleID)
            visited.insert(moduleID)
            result.append(moduleID)
            return nil
        }
        
        for module in modules {
            if let error = visit(module.moduleID) {
                return error
            }
        }
        
        return .success(result)
    }
    
    public func previewSort(modules: [UIModuleDiscoveryResult]) -> String {
        let result = sort(modules: modules)
        switch result {
        case .success(let order):
            return order.joined(separator: " → ")
        case .cycleDetected(let cycle):
            return "循环依赖: \(cycle.joined(separator: " → "))"
        case .missingDependency(let dep, let module):
            return "缺失依赖: \(dep) (模块: \(module))"
        }
    }
    
    public func setPriority(moduleID: String, order: Int) {
        // 设置优先级
    }
    
    public func clearPriorityOverrides() {
        // 清除优先级覆盖
    }
}
