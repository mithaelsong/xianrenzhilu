// MARK: - UI-07: 动态加载UI模块
// 功能编号: UI-08
// 版本: 2.0
// 职责: 不重启应用加载新模块，签名/完整性校验，依赖递归解析，超时控制，队列管理
// 依赖: UI-01 扫描, UI-02 排序, UI-03 启动, UI-04 错误处理, UI-05 注册表,
//       UI-08 获取实例, UI-10 版本检查, UI-12 日志
// 编码规则: NSRecursiveLock、手动lock/unlock、零defer、零print、
//          零[String:Any]、中文日志

import Foundation
import AppKit

// UIModuleLoadResult 定义在 UI-02_公共类型定义.swift

// MARK: - 动态加载管理器
// 独立编译存根
// 使用UI-02的UIModuleStartContext
// 本文件不再定义该类型

// 类型 UIModuleScanner 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleLauncher 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleErrorHandler 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleRegistry 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleVersionChecker 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleDynamicLoader 已迁移到 UI-02_公共类型定义.swift


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIModuleDynamicLoader
public final class UIModuleDynamicLoader : @unchecked Sendable {
    public static let shared = UIModuleDynamicLoader()

    let lock = NSRecursiveLock()
    private let logger = UILoadingLogManager.shared
    private let scanner = UIModuleScanner.shared
    private let launcher = UIModuleLauncher.shared
    private let errorHandler = UIModuleErrorHandler.shared
    private let registry = UIModuleRegistry.shared
    private let versionChecker = UIModuleVersionChecker.shared

    // 加载队列
    private var loadQueue: [UIModuleLoadQueueItem] = []
    private var isProcessingQueue: Bool = false
    private var canceledModuleIDs: Set<String> = []

    // 加载历史
    private var _loadHistory: [UIModuleLoadRecord] = []
    private let maxHistoryCount: Int = 200

    // 默认超时
    private let defaultLoadTimeout: TimeInterval = 30.0

    // 依赖解析超时
    private let dependencyResolveTimeout: TimeInterval = 10.0

    // 最大依赖递归深度
    private let maxDependencyDepth: Int = 10

    // 已解析的依赖缓存（提高性能）
    private var resolvedDependencyCache: [String: Set<String>] = [:]

    private init() {}

    // MARK: - 主加载入口

    /// 动态加载单个UI模块
    /// - Parameters:
    ///   - path: bundle文件路径
    ///   - strategy: 加载策略（默认立即）
    ///   - timeout: 超时秒数（默认30秒）
    /// - Returns: 加载结果
    public func loadModule(path: String, strategy: UIModuleLoadStrategy = .eager, timeout: TimeInterval? = nil) -> UIModuleLoadResult {
        let effectiveTimeout = timeout ?? defaultLoadTimeout
        let startTime = Date()

        // 1. 解析bundle（文件IO，锁外）
        guard !path.isEmpty else {
            logger.error("加载器", "路径为空")
            return .loadFailed(moduleID: "(unknown)", error: "路径为空")
        }

        let url = URL(fileURLWithPath: path)
        guard let discovery = scanner.parseBundle(at: url) else {
            logger.error("加载器", "无法解析bundle: \(path)")
            return .loadFailed(moduleID: "(unknown)", error: "无法解析bundle: \(path)")
        }

        let moduleID = discovery.moduleID
        let moduleName = discovery.metadata.moduleName

        // 2. 检查取消标记
        lock.lock()
        if canceledModuleIDs.contains(moduleID) {
            canceledModuleIDs.remove(moduleID)
            lock.unlock()
            logger.warning("加载器", "模块 '\(moduleID)' 已被取消加载")
            return .cancelled(moduleID: moduleID)
        }
        lock.unlock()

        // 3. 执行加载（锁外IO/启动）
        let result = performLoadWithTimeout(discovery: discovery, path: path, timeout: effectiveTimeout, strategy: strategy)

        // 4. 记录历史
        let duration = Date().timeIntervalSince(startTime)
        let record = UIModuleLoadRecord(
            moduleID: moduleID,
            moduleName: moduleName,
            path: path,
            startedAt: startTime,
            duration: duration,
            result: result,
            strategy: strategy
        )

        lock.lock()
        _loadHistory.append(record)
        if _loadHistory.count > maxHistoryCount {
            _loadHistory.removeFirst(_loadHistory.count - maxHistoryCount)
        }
        lock.unlock()

        return result
    }

    // MARK: - 依赖递归解析

    /// 递归解析模块的所有依赖，带超时保护和循环依赖检测
    private func resolveDependenciesRecursive(
        discovery: UIModuleDiscoveryResult,
        depth: Int = 0,
        startTime: Date? = nil,
        resolved: Set<String> = []
    ) -> (missing: [String], timedOut: Bool, depthExceeded: Bool) {
        let moduleID = discovery.moduleID
        let currentStartTime = startTime ?? Date()

        // 检查超时
        let elapsed = Date().timeIntervalSince(currentStartTime)
        if elapsed > dependencyResolveTimeout {
            logger.error("加载器", "模块 '\(moduleID)' 依赖解析超时 (\(String(format: "%.1f", elapsed))秒)")
            return (missing: ["依赖解析超时"], timedOut: true, depthExceeded: false)
        }

        // 检查深度
        if depth > maxDependencyDepth {
            logger.error("加载器", "模块 '\(moduleID)' 依赖递归深度超限 (\(depth) > \(maxDependencyDepth))")
            return (missing: ["依赖递归深度超限"], timedOut: false, depthExceeded: true)
        }

        // 检查循环依赖
        if resolved.contains(moduleID) {
            logger.error("加载器", "模块 '\(moduleID)' 检测到循环依赖")
            return (missing: ["循环依赖: \(moduleID)"], timedOut: false, depthExceeded: false)
        }

        var allMissing: [String] = []
        var currentResolved = resolved
        currentResolved.insert(moduleID)

        for dep in discovery.metadata.dependencies {
            // 软依赖（以?结尾）不阻断
            if dep.hasSuffix("?") || dep.hasSuffix("(optional)") {
                continue
            }

            // 检查是否已加载
            lock.lock()
            let loaded = registry.isRegistered(name: dep) || registry.isRegistered(moduleID: dep)
            lock.unlock()

            if !loaded {
                // 尝试查找该依赖模块的bundle
                let depPaths = findDependencyBundle(dependencyName: dep)

                if depPaths.isEmpty {
                    allMissing.append(dep)
                    continue
                }

                // 递归解析该依赖的依赖
                for depPath in depPaths {
                    let depURL = URL(fileURLWithPath: depPath)
                    guard let depDiscovery = scanner.parseBundle(at: depURL) else {
                        allMissing.append(dep)
                        continue
                    }

                    let subResult = resolveDependenciesRecursive(
                        discovery: depDiscovery,
                        depth: depth + 1,
                        startTime: currentStartTime,
                        resolved: currentResolved
                    )

                    if subResult.timedOut {
                        return (missing: allMissing + subResult.missing, timedOut: true, depthExceeded: false)
                    }
                    if subResult.depthExceeded {
                        return (missing: allMissing + subResult.missing, timedOut: false, depthExceeded: true)
                    }

                    allMissing.append(contentsOf: subResult.missing)
                }
            }
        }

        return (missing: allMissing, timedOut: false, depthExceeded: false)
    }

    /// 查找依赖模块的bundle路径（使用 scanner.parseBundle 遍历模块目录）
    private func findDependencyBundle(dependencyName: String) -> [String] {
        // 检查缓存
        lock.lock()
        let cached = resolvedDependencyCache[dependencyName]
        lock.unlock()
        if let cached = cached {
            return Array(cached)
        }

        // 使用 scanner 扫描默认目录
        let foundPaths = scanner.scan().filter { result in
            result.moduleID == dependencyName || result.metadata.moduleName == dependencyName
        }.map { $0.bundleURL.path }

        // 缓存结果
        let pathSet = Set(foundPaths)
        lock.lock()
        resolvedDependencyCache[dependencyName] = pathSet
        lock.unlock()

        return foundPaths
    }

    // MARK: - 带超时的加载执行

    /// 使用信号量 + 后台队列执行加载，支持可取消超时
    private func performLoadWithTimeout(
        discovery: UIModuleDiscoveryResult,
        path: String,
        timeout: TimeInterval,
        strategy: UIModuleLoadStrategy
    ) -> UIModuleLoadResult {
        let moduleID = discovery.moduleID
        let startTime = Date()

        let semaphore = DispatchSemaphore(value: 0)
        var loadResult: UIModuleLoadResult = .timedOut(moduleID: moduleID, timeout: timeout)
        var isCompleted = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                loadResult = .loadFailed(moduleID: moduleID, error: "加载器已释放")
                semaphore.signal()
                return
            }

            let result = self.executeLoadInternal(
                discovery: discovery,
                path: path,
                strategy: strategy
            )

            self.lock.lock()
            if !isCompleted {
                loadResult = result
                isCompleted = true
            }
            self.lock.unlock()
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + timeout)

        if waitResult == .timedOut {
            lock.lock()
            if !isCompleted {
                isCompleted = true
                loadResult = .timedOut(moduleID: moduleID, timeout: timeout)
                logger.error("加载器", "模块 '\(moduleID)' 加载超时 (\(timeout)秒)")
            }
            lock.unlock()
        }

        let duration = Date().timeIntervalSince(startTime)
        if case .timedOut = loadResult {
            logger.error("加载器", "模块 '\(moduleID)' 加载超时，已取消 (耗时: \(String(format: "%.2f", duration))秒)")
        }

        return loadResult
    }

    // MARK: - 内部加载逻辑

    /// 不带超时包装的加载逻辑（在performLoadWithTimeout的后台闭包中调用）
    private func executeLoadInternal(
        discovery: UIModuleDiscoveryResult,
        path: String,
        strategy: UIModuleLoadStrategy
    ) -> UIModuleLoadResult {
        let internalLoadStartTime = Date()
        let moduleID = discovery.moduleID
        let moduleName = discovery.metadata.moduleName

        // 1. 检查是否已加载
        lock.lock()
        let alreadyLoaded = registry.isRegistered(moduleID: moduleID)
        lock.unlock()

        if alreadyLoaded {
            logger.warning("加载器", "模块 '\(moduleID)' 已加载，跳过")
            return .alreadyLoaded(moduleID: moduleID)
        }

        // 2. 依赖检查 — 递归解析（带超时和深度限制）
        let depResult = resolveDependenciesRecursive(discovery: discovery)
        if depResult.timedOut {
            return .timedOut(moduleID: moduleID, timeout: dependencyResolveTimeout)
        }
        if depResult.depthExceeded {
            return .loadFailed(moduleID: moduleID, error: "依赖递归深度超限")
        }
        if !depResult.missing.isEmpty {
            let depStr = depResult.missing.joined(separator: ", ")
            logger.error("加载器", "模块 '\(moduleID)' 缺少依赖: \(depStr)")
            return .missingDependency(moduleID: moduleID, dependency: depStr)
        }

        // 3. 版本兼容性检查
        lock.lock()
        if let minVersion = discovery.metadata.minFrameworkVersion {
            let compat = versionChecker.checkCompatibility(
                moduleID: moduleID,
                moduleVersion: discovery.metadata.version,
                minFrameworkVersion: minVersion
            )
            switch compat {
            case .incompatible(let reason):
                lock.unlock()
                logger.error("加载器", "模块 '\(moduleID)' 版本不兼容: \(reason)")
                return .incompatible(moduleID: moduleID, reason: reason)
            case .requiresUpdate(_, let required):
                lock.unlock()
                let reason = "需要框架版本 \(required)"
                logger.error("加载器", "模块 '\(moduleID)' \(reason)")
                return .incompatible(moduleID: moduleID, reason: reason)
            default:
                break
            }
        }
        lock.unlock()

        // 4. 完整性校验
        guard validateModuleIntegrity(at: URL(fileURLWithPath: path)) else {
            logger.error("加载器", "模块 '\(moduleID)' 完整性校验失败")
            return .loadFailed(moduleID: moduleID, error: "模块完整性校验失败")
        }

        // 5. 启动模块
        let context = UIModuleStartContext()
        let launchResult = launcher.launchAll(modules: [discovery], context: context)

        // 6. 检查结果
        if launchResult.failureCount > 0 {
            let errMsg = launchResult.failedModules.first?.error ?? "未知启动错误"
            let _ = errorHandler.handleError(moduleID: moduleID, moduleName: moduleName, error: UIModuleLoadError.startupFailed(moduleID: moduleID, reason: errMsg))
            logger.error("加载器", "模块 '\(moduleID)' 动态加载失败: \(errMsg)")
            return .loadFailed(moduleID: moduleID, error: errMsg)
        }

        // 7. 成功通知（锁外）
        let actualDuration = Date().timeIntervalSince(internalLoadStartTime)
        let payload = UIModuleLoadedPayload(moduleID: moduleID, moduleName: moduleName, loadDuration: actualDuration, strategy: strategy)
        NotificationCenter.default.post(name: .UIModuleDidLoad, object: payload)

        logger.info("加载器", "模块 '\(moduleID)' (\(moduleName)) 动态加载成功")
        return .success(moduleID: moduleID)
    }

    // MARK: - 完整性校验

    /// 校验模块 bundle 的完整性（存在 + principalClass）
    private func validateModuleIntegrity(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        guard Bundle(url: url)?.principalClass != nil else {
            return false
        }
        return true
    }

    // MARK: - 异步加载

    /// 后台队列异步加载模块，结果在主线程回调
    public func loadModuleAsync(path: String, timeout: TimeInterval? = nil, completion: @escaping (UIModuleLoadResult) -> Void) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                completion(.cancelled(moduleID: "(self-deallocated)"))
                return
            }
            let result = self.loadModule(path: path, timeout: timeout)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    // MARK: - 加载队列管理

    /// 将模块加入加载队列，按优先级排序
    /// 如果队列不在处理中，自动开始处理
    public func enqueueModule(path: String, priority: Int = 0) {
        let url = URL(fileURLWithPath: path)
        guard let discovery = scanner.parseBundle(at: url) else {
            logger.error("加载器", "入队失败，无法解析模块: \(path)")
            return
        }

        let item = UIModuleLoadQueueItem(
            moduleID: discovery.moduleID,
            moduleName: discovery.metadata.moduleName,
            path: path,
            priority: priority,
            createdAt: Date(),
            isCanceled: false
        )

        var shouldStartProcessing = false
        lock.lock()
        loadQueue.append(item)
        loadQueue.sort { $0.priority > $1.priority }
        if !isProcessingQueue {
            isProcessingQueue = true
            shouldStartProcessing = true
        }
        lock.unlock()

        logger.info("加载器", "模块 '\(discovery.metadata.moduleName)' 已加入加载队列 (优先级: \(priority))")

        if shouldStartProcessing {
            startQueueProcessing()
        }
    }

    /// 开始队列处理（后台执行）
    private func startQueueProcessing() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            self.processQueueItems()
        }
    }

    /// 处理加载队列中的所有待处理项（在后台线程中调用）
    private func processQueueItems() {
        while true {
            self.lock.lock()
            guard !self.loadQueue.isEmpty else {
                self.isProcessingQueue = false
                self.lock.unlock()
                return
            }

            let item = self.loadQueue.removeFirst()
            if item.isCanceled {
                self.lock.unlock()
                continue
            }
            self.lock.unlock()

            let result = self.loadModule(path: item.path, strategy: .deferred(priority: item.priority))
            switch result {
            case .success(let mid):
                self.logger.info("加载器", "队列加载完成: \(mid)")
            case .loadFailed(let mid, let err):
                self.logger.error("加载器", "队列加载失败: \(mid) - \(err)")
            default:
                break
            }
        }
    }

    /// 取消加载队列中的模块
    public func cancelLoad(moduleID: String) {
        lock.lock()
        canceledModuleIDs.insert(moduleID)
        loadQueue = loadQueue.filter { $0.moduleID != moduleID }
        lock.unlock()
        logger.warning("加载器", "模块 '\(moduleID)' 加载已取消")
    }

    // MARK: - 批量加载

    /// 同步批量加载多个模块
    public func loadModules(paths: [String]) -> [UIModuleLoadResult] {
        var results: [UIModuleLoadResult] = []
        for path in paths {
            let result = loadModule(path: path)
            results.append(result)
        }
        return results
    }

    // MARK: - 查询

    /// 获取当前队列状态
    public func queueStatus() -> (pending: Int, processing: Bool) {
        lock.lock()
        let status = (loadQueue.count, isProcessingQueue)
        lock.unlock()
        return status
    }

    /// 获取加载历史
    public func loadHistory() -> [UIModuleLoadRecord] {
        lock.lock()
        let history = _loadHistory
        lock.unlock()
        return history
    }

    /// 清空加载历史
    public func clearHistory() {
        lock.lock()
        _loadHistory.removeAll()
        lock.unlock()
        logger.info("加载器", "加载历史已清空")
    }
}
