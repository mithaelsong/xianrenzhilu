// MARK: - UI-05: 调用UI模块的start
// 功能编号: UI-05
// 版本: 2.0
// 职责: 按排序顺序动态加载bundle、实例化、调用start()、异常捕获、超时保护、重试机制
// 依赖: UI-02 排序器, UI-06 注册表, UI-12 日志

import Foundation
import AppKit

// 独立编译存根
// 类型 UIUnifiedRegistry 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleSorter 已迁移到 UI-02_公共类型定义.swift



// 使用UI-02的UIModuleStartContext
// 本文件不再定义该类型

// MARK: - 模块启动器
// 类型 UIModuleLauncher 已迁移到 UI-02_公共类型定义.swift

// MARK: - 测试
internal func test_UI03() {
    print("\n=== UI-03 启动器模块测试 ===")
    let launcher = UIModuleLauncher.shared
    let testContext = UIModuleStartContext()

    // 测试1: 空列表启动
    print("\n🧪 测试1: 空列表启动")
    let emptyResult = launcher.launchAll(modules: [], context: testContext)
    guard emptyResult.successCount == 0 else {
        fatalError("❌ 测试1失败: 空列表成功数应为0")
    }
    guard emptyResult.failureCount == 0 else {
        fatalError("❌ 测试1失败: 空列表失败数应为0")
    }
    guard emptyResult.successfulModules.isEmpty else {
        fatalError("❌ 测试1失败: 空列表成功模块应为空")
    }
    guard emptyResult.failedModules.isEmpty else {
        fatalError("❌ 测试1失败: 空列表失败模块应为空")
    }
    guard emptyResult.totalDuration >= 0 else {
        fatalError("❌ 测试1失败: 耗时应非负")
    }
    guard emptyResult.totalDuration < 5.0 else {
        fatalError("❌ 测试1失败: 空列表启动应快速，实际: \(emptyResult.totalDuration)秒")
    }
    print("✅ 测试1通过: 空列表启动返回0成功0失败0耗时")

    // 测试2: 循环依赖检测
    print("\n🧪 测试2: 循环依赖检测")
    let metaD = UIModuleMetadata(moduleID: "D", moduleName: "模块D", version: "2.0", minFrameworkVersion: nil, dependencies: ["E"], author: nil, description: nil, isBuiltIn: false)
    let metaE = UIModuleMetadata(moduleID: "E", moduleName: "模块E", version: "2.0", minFrameworkVersion: nil, dependencies: ["D"], author: nil, description: nil, isBuiltIn: false)
    let resultD = UIModuleDiscoveryResult(moduleID: "D", bundleURL: URL(fileURLWithPath: "/tmp/D.bundle"), metadata: metaD)
    let resultE = UIModuleDiscoveryResult(moduleID: "E", bundleURL: URL(fileURLWithPath: "/tmp/E.bundle"), metadata: metaE)
    let cycleResult = launcher.launchAll(modules: [resultD, resultE], context: testContext)
    guard cycleResult.successCount == 0 else {
        fatalError("❌ 测试2失败: 循环依赖应全部失败")
    }
    guard cycleResult.failureCount == 2 else {
        fatalError("❌ 测试2失败: 循环依赖应2个都失败，实际: \(cycleResult.failureCount)")
    }
    print("✅ 测试2通过: 循环依赖检测，2个全部失败")

    // 测试3: 缺失依赖检测
    print("\n🧪 测试3: 缺失依赖检测")
    let metaF = UIModuleMetadata(moduleID: "F", moduleName: "模块F", version: "2.0", minFrameworkVersion: nil, dependencies: ["MissingModule"], author: nil, description: nil, isBuiltIn: false)
    let resultF = UIModuleDiscoveryResult(moduleID: "F", bundleURL: URL(fileURLWithPath: "/tmp/F.bundle"), metadata: metaF)
    let missingResult = launcher.launchAll(modules: [resultF], context: testContext)
    guard missingResult.successCount == 0 else {
        fatalError("❌ 测试3失败: 缺失依赖应全部失败")
    }
    guard missingResult.failureCount == 1 else {
        fatalError("❌ 测试3失败: 缺失依赖应1个失败，实际: \(missingResult.failureCount)")
    }
    guard missingResult.failedModules.first?.moduleID == "F" else {
        fatalError("❌ 测试3失败: 失败模块应为F")
    }
    guard (missingResult.failedModules.first?.error ?? "").contains("MissingModule") else {
        fatalError("❌ 测试3失败: 失败原因应包含MissingModule")
    }
    print("✅ 测试3通过: 缺失依赖检测成功")

    // 测试4: UIModuleLoadError 类型覆盖
    print("\n🧪 测试4: UIModuleLoadError 类型覆盖")
    let errBundleNotFound = UIModuleLoadError.bundleNotFound(moduleID: "test")
    guard errBundleNotFound.localizedDescription.contains("未找到") else {
        fatalError("❌ 测试4失败: bundleNotFound描述应包含'未找到'")
    }
    let errTimeout = UIModuleLoadError.startupTimeout(moduleID: "X")
    guard errTimeout.localizedDescription.contains("超时") else {
        fatalError("❌ 测试4失败: startupTimeout描述应包含'超时'")
    }
    print("✅ 测试4通过: 5种错误类型描述均正确")

    // 测试5: 启动历史记录
    print("\n🧪 测试5: 启动历史记录")
    _ = launcher.launchAll(modules: [resultF], context: testContext)  // 第2次失败
    let history = launcher.getLaunchHistory()
    guard history.count >= 2 else {
        fatalError("❌ 测试5失败: 历史记录应>=2，实际: \(history.count)")
    }
    guard history.last?.failedModules.first?.moduleID == "F" else {
        fatalError("❌ 测试5失败: 最后一条历史应为F启动失败")
    }
    print("✅ 测试5通过: 历史记录 \(history.count) 条，内容正确")

    // 测试6: 启动结果结构体
    print("\n🧪 测试6: 启动结果结构体")
    let result = UIModuleStartResult(successCount: 3, failureCount: 1, successfulModules: ["A", "B", "C"], failedModules: [("D", "错误")], totalDuration: 1.5)
    guard result.successCount == 3 else {
        fatalError("❌ 测试6失败: successCount应为3")
    }
    guard result.failureCount == 1 else {
        fatalError("❌ 测试6失败: failureCount应为1")
    }
    guard result.successfulModules == ["A", "B", "C"] else {
        fatalError("❌ 测试6失败: successfulModules应为[A,B,C]")
    }
    guard result.failedModules.count == 1, result.failedModules[0].moduleID == "D" else {
        fatalError("❌ 测试6失败: failedModules应为[D]")
    }
    guard result.totalDuration == 1.5 else {
        fatalError("❌ 测试6失败: totalDuration应为1.5")
    }
    print("✅ 测试6通过: 启动结果结构体构造正确")

    // 测试7: Payload 序列化
    print("\n🧪 测试7: Payload 序列化")
    let failedPayload = UIModuleStartFailedPayload(moduleID: "X", error: "测试错误", severity: 2)
    let dict = failedPayload.asDictionary
    guard dict["moduleID"] as? String == "X" else {
        fatalError("❌ 测试7失败: failedPayload moduleID应为X")
    }
    guard dict["severity"] as? Int == 2 else {
        fatalError("❌ 测试7失败: failedPayload severity应为2")
    }
    let successPayload = UIModuleStartSuccessPayload(moduleID: "Y")
    let succDict = successPayload.asDictionary
    guard succDict["moduleID"] as? String == "Y" else {
        fatalError("❌ 测试7失败: successPayload moduleID应为Y")
    }
    print("✅ 测试7通过: Payload 序列化正确")

    print("\n=== 全部 UI-03 启动器模块测试通过 ✅ ===\n")
}


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIModuleLauncher
public final class UIModuleLauncher : @unchecked Sendable {
    public static let shared = UIModuleLauncher()

    private let lock = NSLock()
    private let logger = UILoadingLogManager.shared
    private let registry = UIUnifiedRegistry.shared
    private let sorter = UIModuleSorter.shared

    /// 启动超时阈值（秒）
    private let startupTimeout: TimeInterval = 30.0

    /// 最大重试次数
    private let maxRetryCount: Int = 2

    /// 启动历史
    private var launchHistory: [UIModuleStartResult] = []
    private let maxHistoryCount: Int = 20

    private init() {}

    // MARK: - 启动所有模块

    /// 启动所有发现的UI模块
    /// - Parameters:
    ///   - modules: 模块发现结果列表
    ///   - context: 启动上下文
    /// - Returns: 启动结果统计
    public func launchAll(modules: [UIModuleDiscoveryResult], context: UIModuleStartContext) -> UIModuleStartResult {
        // 1. 排序 — 锁外执行，不阻塞其他操作
        let sortResult = sorter.sort(modules: modules)
        var sortedIDs: [String]
        var preFailures: [(String, String)] = []

        switch sortResult {
        case .success(let order):
            sortedIDs = order
        case .cycleDetected(let cycle):
            logger.error("启动器", "检测到循环依赖，启动终止: \(cycle.joined(separator: " → "))")
            // 精确标注处于循环中的模块，其余模块标注为被阻塞
            let cycleSet = Set(cycle)
            preFailures = modules.map { module in
                if cycleSet.contains(module.moduleID) {
                    (module.moduleID, "循环依赖：\(cycle.joined(separator: " → "))")
                } else {
                    (module.moduleID, "排序失败：受循环依赖影响")
                }
            }
            let result = UIModuleStartResult(
                successCount: 0,
                failureCount: modules.count,
                successfulModules: [],
                failedModules: preFailures,
                totalDuration: 0
            )
            lock.lock()
            launchHistory.append(result)
            if launchHistory.count > maxHistoryCount {
                launchHistory.removeFirst(launchHistory.count - maxHistoryCount)
            }
            lock.unlock()
            postNotifications(failed: preFailures, successful: [])
            return result
        case .missingDependency(let dep, let module):
            logger.error("启动器", "模块 '\(module)' 缺少依赖 '\(dep)'")
            // 具体缺失依赖的模块标注详细错误，其余模块标注为被阻塞
            preFailures = modules.map { m in
                if m.moduleID == module {
                    (m.moduleID, "缺少依赖：\(dep)")
                } else {
                    (m.moduleID, "排序失败：受依赖缺失影响")
                }
            }
            let result = UIModuleStartResult(
                successCount: 0,
                failureCount: modules.count,
                successfulModules: [],
                failedModules: preFailures,
                totalDuration: 0
            )
            lock.lock()
            launchHistory.append(result)
            if launchHistory.count > maxHistoryCount {
                launchHistory.removeFirst(launchHistory.count - maxHistoryCount)
            }
            lock.unlock()
            postNotifications(failed: preFailures, successful: [])
            return result
        }

        logger.info("启动器", "启动顺序: \(sortedIDs.joined(separator: " → "))")

        let startTime = Date()
        var successful: [String] = []
        var failed: [(String, String)] = []

        // 构建moduleID→发现结果映射，重复moduleID保留第一个（防御性处理）
        let moduleMap: [String: UIModuleDiscoveryResult] = modules.reduce(into: [:]) { dict, module in
            if dict[module.moduleID] == nil {
                dict[module.moduleID] = module
            }
        }

        // 2. 遍历启动 — 锁外执行（包含I/O和信号量等待）
        for moduleID in sortedIDs {
            guard let discovery = moduleMap[moduleID] else { continue }

            logger.info("启动器", "正在加载模块: \(discovery.metadata.moduleName) (ID: \(moduleID))")
            let loadStart = Date()

            let loadResult = launchSingleModuleWithRetry(discovery: discovery, context: context)
            let duration = Date().timeIntervalSince(loadStart)

            switch loadResult {
            case .success:
                successful.append(moduleID)
                logger.info("启动器", "模块 '\(discovery.metadata.moduleName)' 启动成功 (耗时: \(String(format: "%.2f", duration))秒)", moduleID: moduleID)
            case .failure(let errMsg):
                failed.append((moduleID, errMsg))
                logger.error("启动器", "模块 '\(discovery.metadata.moduleName)' 启动失败: \(errMsg) (耗时: \(String(format: "%.2f", duration))秒)", moduleID: moduleID)
            }
        }

        let totalDuration = Date().timeIntervalSince(startTime)
        logger.info("启动器", "全部模块启动完成: \(successful.count) 成功, \(failed.count) 失败, 总耗时: \(String(format: "%.2f", totalDuration))秒")

        // 3. 记录历史（锁内保护共享数据）
        let result = UIModuleStartResult(
            successCount: successful.count,
            failureCount: failed.count,
            successfulModules: successful,
            failedModules: failed,
            totalDuration: totalDuration
        )

        lock.lock()
        launchHistory.append(result)
        if launchHistory.count > maxHistoryCount {
            launchHistory.removeFirst(launchHistory.count - maxHistoryCount)
        }
        lock.unlock()

        // 4. 锁外发通知
        postNotifications(failed: failed, successful: successful)

        return result
    }

    /// 发送启动通知（锁外调用）
    private func postNotifications(failed: [(String, String)], successful: [String]) {
        for (moduleID, errMsg) in failed {
            let payload = UIModuleStartFailedPayload(moduleID: moduleID, error: errMsg, severity: 1)
            NotificationCenter.default.post(name: .UIModuleLoadFailed, object: self, userInfo: payload.asDictionary)
        }
        for moduleID in successful {
            let payload = UIModuleStartSuccessPayload(moduleID: moduleID)
            NotificationCenter.default.post(name: .UIModuleDidLoad, object: self, userInfo: payload.asDictionary)
        }
    }

    // MARK: - 带重试的单个模块启动

    private enum UISingleLaunchResult {
        case success
        case failure(String)
    }

    private func launchSingleModuleWithRetry(discovery: UIModuleDiscoveryResult, context: UIModuleStartContext) -> UISingleLaunchResult {
        var lastError: String = ""

        for attempt in 1...(maxRetryCount + 1) {
            do {
                try launchSingleModule(discovery: discovery, context: context)
                return .success
            } catch let error as UIModuleLoadError {
                lastError = error.localizedDescription
                if case .startupTimeout = error {
                    // 超时不重试
                    break
                }
                logger.warning("启动器", "模块 '\(discovery.metadata.moduleName)' 第\(attempt)次启动失败: \(lastError)，即将\(attempt <= maxRetryCount ? "重试" : "放弃")", moduleID: discovery.moduleID)
                if attempt <= maxRetryCount {
                    // 指数退避：0.5s, 1s, 2s...
                    let delay = 0.5 * pow(2.0, Double(attempt - 1))
                    Thread.sleep(forTimeInterval: delay)
                }
            } catch {
                lastError = error.localizedDescription
                logger.warning("启动器", "模块 '\(discovery.metadata.moduleName)' 第\(attempt)次启动失败: \(lastError)", moduleID: discovery.moduleID)
                if attempt <= maxRetryCount {
                    let delay = 0.3 * pow(2.0, Double(attempt - 1))
                    Thread.sleep(forTimeInterval: delay)
                }
            }
        }

        return .failure(lastError)
    }

    // MARK: - 启动单个模块

    private func launchSingleModule(discovery: UIModuleDiscoveryResult, context: UIModuleStartContext) throws {
        // 1. 动态加载bundle（锁外I/O）
        guard let bundle = Bundle(url: discovery.bundleURL) else {
            throw UIModuleLoadError.bundleNotFound(moduleID: discovery.moduleID)
        }

        let loaded = bundle.load()
        guard loaded else {
            throw UIModuleLoadError.bundleLoadFailed(moduleID: discovery.moduleID)
        }

        // 2. 获取principal class
        guard let principalClass = bundle.principalClass as? UIModuleProtocol.Type else {
            throw UIModuleLoadError.invalidPrincipalClass(moduleID: discovery.moduleID)
        }

        // 3. 实例化（锁外）
        let instance = principalClass.init()

        // 4. 调用start（带超时取消保护，使用 DispatchWorkItem）
        let startupContext: [String: Any] = [
            "config": context.config,
            "launchParameters": context.launchParameters
        ]

        var startError: Error? = nil
        let wasCancelled = false
        let semaphore = DispatchSemaphore(value: 0)

        let workItem = DispatchWorkItem { [weak instance] in
            guard let strongInstance = instance else {
                startError = UIModuleLoadError.startupFailed(moduleID: discovery.moduleID, reason: "模块实例已释放")
                semaphore.signal()
                return
            }
            autoreleasepool {
                do {
                    try strongInstance.start(context: startupContext)
                } catch {
                    // 已超时被截断时不处理错误
                    if !wasCancelled {
                        startError = error
                    }
                }
            }
            semaphore.signal()
        }

        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)

        let timeoutResult = semaphore.wait(timeout: .now() + startupTimeout)

        if timeoutResult == .timedOut {
            // 超时 → 取消 workItem，后台线程检测 isCancelled 后跳过错误处理
            workItem.cancel()
            throw UIModuleLoadError.startupTimeout(moduleID: discovery.moduleID)
        }

        // workItem 正常完成
        if let error = startError {
            throw error
        }

        // 5. 注册并持有强引用（锁内保护共享数据）
        lock.lock()
        registry.register(instance: instance, name: discovery.metadata.moduleName, aliases: [], priority: 0)
        registry.retain(moduleID: discovery.moduleID, instance: instance)
        lock.unlock()
    }

    // MARK: - 启动历史

    /// 获取启动历史记录列表
    /// - Returns: 最近20次启动结果
    public func getLaunchHistory() -> [UIModuleStartResult] {
        lock.lock()
        let history = launchHistory
        lock.unlock()
        return history
    }
}
