// KJ-GL-12_模块热替换.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os
import AppKit

// MARK: - KJModuleHotSwapper
public final class KJModuleHotSwapper {
    private let registry: KJModuleRegistry
    private let loader: KJModuleLoader
    private let unloader: KJModuleUnloader
    private let eventBus: NotificationCenter
    private let logger = Logger(subsystem: "com.xianrenzhilu.module.hotswap", category: "HotSwapper")
    private let scanner = KJModuleScanner.shared

    /// Currently swapping modules set (prevents concurrent swaps on same module)
    private var swappingModules: Set<String> = []
    private var swapLock = os_unfair_lock()

    public init(registry: KJModuleRegistry, loader: KJModuleLoader,
                unloader: KJModuleUnloader, eventBus: NotificationCenter) {
        self.registry = registry
        self.loader = loader
        self.unloader = unloader
        self.eventBus = eventBus
    }

    // MARK: - Hot Swap Entry Point

    /// Hot swap a specific module
    /// - Parameters:
    ///   - moduleName: Module name to replace
    ///   - newPath: Path to new module directory (with ModuleMetadata.json and bundle)
    /// - Returns: Hot swap result
    public func hotSwap(moduleName: String, with newPath: URL) -> KJHotSwapResult {
        logger.log(level: .info, "🔄 Hot swapping module: \(moduleName) -> \(newPath.path)")

        // 1. Check if already swapping this module
        os_unfair_lock_lock(&swapLock)
        if swappingModules.contains(moduleName) {
            os_unfair_lock_unlock(&swapLock)
            logger.log(level: .info, "模块\(moduleName)正在热替换中，拒绝重复请求")
            return .failure(moduleName: moduleName, reason: .moduleNotLoaded(name: moduleName))
        }
        swappingModules.insert(moduleName)
        os_unfair_lock_unlock(&swapLock)

        defer {
            os_unfair_lock_lock(&swapLock)
            swappingModules.remove(moduleName)
            os_unfair_lock_unlock(&swapLock)
        }

        // 2. Check if old module is loaded
        guard registry.isLoaded(name: moduleName) else {
            logger.log(level: .error, "模块\(moduleName)未加载，无法进行热替换")
            return .failure(moduleName: moduleName, reason: .moduleNotLoaded(name: moduleName))
        }

        // 3. Get old module info
        guard let oldModule = registry.getModule(name: moduleName) else {
            logger.log(level: .error, "模块\(moduleName)实例获取失败")
            return .failure(moduleName: moduleName, reason: .moduleNotLoaded(name: moduleName))
        }

        let oldMetadata = registry.getMetadata(name: moduleName)
        let oldVersion = oldMetadata?.version.stringValue ?? "unknown"
        logger.log(level: .info, "旧模块\(moduleName)版本: \(oldVersion)")

        // 4. Emit will-hot-swap event
        eventBus.post(name: .kjModuleWillHotSwap, object: nil, userInfo: [
            "moduleName": moduleName,
            "oldVersion": oldVersion,
            "newPath": newPath.path
        ])

        // 5. Execute hot swap flow
        let result = performHotSwap(
            moduleName: moduleName,
            oldModule: oldModule,
            oldMetadata: oldMetadata,
            oldVersion: oldVersion,
            newPath: newPath
        )

        // 6. Emit hot swap completion event
        switch result {
        case .success(let name, let from, let to):
            eventBus.post(name: .kjModuleDidHotSwap, object: nil, userInfo: [
                "moduleName": name,
                "fromVersion": from,
                "toVersion": to
            ])
        case .failure(let name, let reason):
            eventBus.post(name: .kjModuleHotSwapFailed, object: nil, userInfo: [
                "moduleName": name,
                "reason": reason.description,
                "rolledBack": false
            ])
        case .rolledBack(let name, let reason):
            eventBus.post(name: .kjModuleHotSwapFailed, object: nil, userInfo: [
                "moduleName": name,
                "reason": reason.description,
                "rolledBack": true
            ])
        }

        return result
    }

    // MARK: - Core Hot Swap Flow

    private func performHotSwap(
        moduleName: String,
        oldModule: Any,
        oldMetadata: KJModuleMetadata?,
        oldVersion: String,
        newPath: URL
    ) -> KJHotSwapResult {

        // ========== Phase 1: Save Old Module State ==========
        logger.log(level: .info, "📦 Phase 1: Save old module \(moduleName) state")
        let stateSnapshot = captureState(module: oldModule, name: moduleName, metadata: oldMetadata)

        // Check if old module is running (via KJModuleProtocol conformance and started state)
        let wasStarted = isModuleStarted(moduleName)

        // Create backup for rollback
        let backup = KJModuleBackup(
            instance: oldModule,
            metadata: oldMetadata,
            stateSnapshot: stateSnapshot,
            wasStarted: wasStarted
        )

        // ========== Phase 2: Scan New Module ==========
        logger.log(level: .info, "🔍 Phase 2: Scan new module path: \(newPath.path)")

        guard FileManager.default.fileExists(atPath: newPath.path) else {
            logger.log(level: .error, "新模块路径不存在: \(newPath.path)")
            return .failure(moduleName: moduleName,
                           reason: .newModuleNotFound(path: newPath.path))
        }

        let scanned: [KJScannedModule] = scanner.scan(directory: newPath.path)
        guard let newScannedModule = scanned.first(where: { $0.metadata.name == moduleName && $0.isValid }) else {
            let reason = scanned.first(where: { $0.metadata.name == moduleName })?.validationError
                ?? "No valid module named \(moduleName)"
            logger.log(level: .error, "新模块无效: \(reason)")
            return .failure(moduleName: moduleName,
                           reason: .newModuleInvalid(name: moduleName, reason: reason))
        }

        let newVersion = newScannedModule.metadata.version
        logger.log(level: .info, "新模块\(moduleName)版本: \(newVersion)")

        // ========== Phase 3: Unload Old Module ==========
        logger.log(level: .info, "🗑️ Phase 3: Unload old module \(moduleName)")
        do {
            try stopModuleIfNeeded(name: moduleName)
        } catch {
            logger.log(level: .error, "停止旧模块\(moduleName)失败: \(error)")
            return .failure(moduleName: moduleName,
                           reason: .unloadFailed(name: moduleName, error: error))
        }

        let unloaded = unloader.forceUnload(moduleID: moduleName)
        guard unloaded.isSuccess else {
            logger.log(level: .error, "卸载旧模块\(moduleName)失败")
            // Attempt rollback
            return attemptRollback(moduleName: moduleName, backup: backup,
                                   originalReason: .unloadFailed(name: moduleName, error: NSError(domain: "HotSwap", code: 1)))
        }

        logger.log(level: .info, "旧模块\(moduleName)已卸载")

        // ========== Phase 4: Load New Module ==========
        logger.log(level: .info, "📥 Phase 4: Load new module \(moduleName)")
        let loadResult = loader.load(moduleID: newScannedModule.moduleID)

        guard case .success = loadResult else {
            let failureReason: KJHotSwapFailureReason
            if case .failure(_, let error) = loadResult {
                failureReason = .loadFailed(name: moduleName, error: KJModuleError.loadFailed)
                logger.log(level: .error, "加载新模块\(moduleName)失败: \(error)")
            } else {
                failureReason = .loadFailed(name: moduleName, error: KJModuleError.loadFailed)
                logger.log(level: .error, "加载新模块\(moduleName)失败: 未知错误")
            }
            // Rollback to old module
            return attemptRollback(moduleName: moduleName, backup: backup, originalReason: failureReason)
        }

        logger.log(level: .info, "新模块\(moduleName)加载成功")

        // ========== Phase 5: Start New Module ==========
        logger.log(level: .info, "🚀 Phase 5: Start new module \(moduleName)")
        do {
            try startModuleIfNeeded(name: moduleName)
        } catch {
            logger.log(level: .error, "启动新模块\(moduleName)失败: \(error)")
            // Unload new module, rollback to old module
            _ = unloader.forceUnload(moduleID: moduleName)
            return attemptRollback(moduleName: moduleName, backup: backup,
                                   originalReason: .startFailed(name: moduleName, error: error))
        }

        logger.log(level: .info, "新模块\(moduleName)启动成功")

        // ========== Phase 6: Restore State ==========
        logger.log(level: .info, "♻️ Phase 6: Restore module \(moduleName) state")
        guard let newModule = registry.getModule(name: moduleName) else {
            logger.log(level: .error, "获取新模块\(moduleName)实例失败，无法恢复状态")
            _ = unloader.forceUnload(moduleID: moduleName)
            return attemptRollback(moduleName: moduleName, backup: backup,
                                   originalReason: .stateRestoreFailed(name: moduleName, error: NSError(domain: "HotSwap", code: 2)))
        }

        do {
            try restoreState(module: newModule, snapshot: stateSnapshot)
            logger.log(level: .info, "模块\(moduleName)状态已恢复")
        } catch {
            logger.log(level: .info, "恢复模块\(moduleName)状态失败: \(error)，模块正常运行")
            // State restore failure does not block hot swap success, log warning only
        }

        // ========== Hot Swap Succeeded ==========
        logger.log(level: .info, "✅ Hot swap succeeded: \(moduleName) \(oldVersion) -> \(newVersion)")
        return .success(moduleName: moduleName, fromVersion: oldVersion, toVersion: newVersion.stringValue)
    }

    // MARK: - Rollback

    /// Rollback to old module on hot swap failure
    private func attemptRollback(
        moduleName: String,
        backup: KJModuleBackup,
        originalReason: KJHotSwapFailureReason
    ) -> KJHotSwapResult {
        logger.log(level: .info, "🔄 Starting rollback for module \(moduleName) to old version \(backup.stateSnapshot.version)")

        do {
            // Re-register old module
            registry.register(
                module: backup.instance as AnyObject,
                name: moduleName,
                metadata: backup.metadata
            )

            // Restart old module if it was running before
            if backup.wasStarted {
                logger.log(level: .info, "正在重启旧模块\(moduleName)")
                if let module = backup.instance as? KJModuleProtocol {
                    try module.start(context: nil)
                }
            }

            // Restore old module state
            try restoreState(module: backup.instance, snapshot: backup.stateSnapshot)

            logger.log(level: .info, "✅ Rollback succeeded: Module \(moduleName) restored to old version")
            return .rolledBack(moduleName: moduleName, reason: originalReason)

        } catch {
            logger.log(level: .error, "💥 Rollback failed: \(error)")
            return .failure(moduleName: moduleName,
                           reason: .rollbackFailed(name: moduleName, originalError: error))
        }
    }

    // MARK: - State Management

    /// Capture module state
    private func captureState(module: Any, name: String, metadata: KJModuleMetadata?) -> KJModuleStateSnapshot {
        var state: [String: Any] = [:]

        if let savable = module as? KJModuleStateSavable {
            state = savable.saveState()
            logger.log(level: .info, "模块\(name)状态已保存，共\(state.count)个键")
        } else {
            logger.log(level: .info, "模块\(name)未实现KJModuleStateSavable协议，状态为空")
        }

        return KJModuleStateSnapshot(
            moduleName: name,
            version: metadata?.version.stringValue ?? "unknown",
            state: state,
            metadata: metadata
        )
    }

    /// Restore module state
    private func restoreState(module: Any, snapshot: KJModuleStateSnapshot) throws {
        guard let savable = module as? KJModuleStateSavable else {
            logger.log(level: .info, "模块\(snapshot.moduleName)未实现KJModuleStateSavable协议，跳过状态恢复")
            return
        }

        guard !snapshot.state.isEmpty else {
            logger.log(level: .info, "模块\(snapshot.moduleName)状态为空，跳过恢复")
            return
        }

        savable.restoreState(snapshot.state)
    }

    // MARK: - Helper Methods

    /// Check if module has started (via KJModuleProtocol protocol)
    private func isModuleStarted(_ name: String) -> Bool {
        guard (registry.getModule(name: name) as? KJModuleProtocol) != nil else {
            return false
        }
        // Assume module is started if registered and conforms to KJModuleProtocol
        // Use additional flags for precise check
        return true
    }

    /// Stop module if it is started
    private func stopModuleIfNeeded(name: String) throws {
        guard let module = registry.getModule(name: name) as? KJModuleProtocol else {
            return
        }
        logger.log(level: .info, "正在停止模块\(name)")
        module.stop()
    }

    /// Start module
    private func startModuleIfNeeded(name: String) throws {
        guard let module = registry.getModule(name: name) as? KJModuleProtocol else {
            throw KJHotSwapFailureReason.moduleNotLoaded(name: name)
        }
        logger.log(level: .info, "正在启动模块\(name)")
        try module.start(context: nil)
    }

    // MARK: - Batch Hot Swap (Advanced)

    /// Batch hot swap multiple modules (dependency-ordered)
    /// - Parameter swaps: [(moduleName, newPath)]
    /// - Returns: Hot swap result per module
    public func hotSwapBatch(_ swaps: [(String, URL)]) -> [KJHotSwapResult] {
        logger.log(level: .info, "🔄 Batch hot swapping \(swaps.count) modules")

        var results: [KJHotSwapResult] = []
        var failedModules: Set<String> = []

        // Sort by dependency order: replace independent modules first
        let sortedSwaps = sortByDependencies(swaps: swaps)

        for (name, path) in sortedSwaps {
            // Skip dependents if their dependency failed
            let deps = registry.getMetadata(name: name)?.dependencies ?? []
            let hasFailedDep = deps.contains(where: { failedModules.contains($0) })
            if hasFailedDep {
                logger.log(level: .info, "模块\(name)依赖替换失败，跳过")
                results.append(.failure(
                    moduleName: name,
                    reason: .dependencyBroken(name: name, missing: deps.filter { failedModules.contains($0) })
                ))
                failedModules.insert(name)
                continue
            }

            let result = hotSwap(moduleName: name, with: path)
            results.append(result)

            if !result.isSuccess {
                failedModules.insert(name)
            }
        }

        let successCount = results.filter { $0.isSuccess }.count
        logger.log(level: .info, "批量热替换完成: 成功\(successCount)/\(swaps.count)个")

        return results
    }

    /// Sort by dependencies (fewest dependencies first)
    private func sortByDependencies(swaps: [(String, URL)]) -> [(String, URL)] {
        return swaps.sorted { a, b in
            let depsA = registry.getMetadata(name: a.0)?.dependencies ?? []
            let depsB = registry.getMetadata(name: b.0)?.dependencies ?? []

            // If A depends on B, A should come after B
            if depsA.contains(b.0) { return false }
            if depsB.contains(a.0) { return true }

            // Otherwise sort by dependency count (fewest first)
            return depsA.count < depsB.count
        }
    }
}


// MARK: - Hot Swap Notification Extensions
public extension Notification.Name {
    /// Module will hot swap
    static let kjModuleWillHotSwap = Notification.Name("com.xianrenzhilu.module.willHotSwap")
    /// Module hot swap succeeded
    static let kjModuleDidHotSwap = Notification.Name("com.xianrenzhilu.module.didHotSwap")
    /// Module hot swap failed (may include rollback info)
    static let kjModuleHotSwapFailed = Notification.Name("com.xianrenzhilu.module.hotSwapFailed")
}
