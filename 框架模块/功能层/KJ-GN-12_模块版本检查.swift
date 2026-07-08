// 功能27: 模块版本检查
// 对应: 检查模块版本是否兼容当前框架
// 优先级: P1

import Foundation
import os

// MARK: - ModuleVersionChecker
/// 模块版本检查器（单例），线程安全
public final class KJModuleVersionChecker: @unchecked Sendable {

    // MARK: - 单例
    public static let shared = KJModuleVersionChecker()

    private init() {}

    // MARK: - 线程安全
    private var lock = os_unfair_lock()

    @inline(__always)
    private func withLock<T>(_ block: () -> T) -> T {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return block()
    }

    // MARK: - 存储
    /// 当前框架版本
    private var frameworkModuleVersion: KJModuleVersion?

    /// 各模块最低要求版本 [模块名: 最低版本]
    private var minimumModuleVersions: [String: KJModuleVersion] = [:]

    /// 已注册模块版本 [模块名: 版本]
    private var moduleModuleVersions: [String: KJModuleVersion] = [:]

    // MARK: - 注册方法

    /// 注册当前框架版本
    public func registerFrameworkModuleVersion(_ version: KJModuleVersion) {
        withLock {
            frameworkModuleVersion = version
        }
    }

    /// 设置指定模块的最低兼容版本
    public func setMinimumModuleVersion(moduleName: String, version: KJModuleVersion) {
        withLock {
            minimumModuleVersions[moduleName] = version
        }
    }

    /// 注册模块版本（用于批量检查）
    public func registerModuleVersion(moduleName: String, version: KJModuleVersion) {
        withLock {
            moduleModuleVersions[moduleName] = version
        }
    }

    // MARK: - 检查方法

    /// 检查指定模块的版本状态
    /// - Parameters:
    ///   - moduleName: 模块名称    ///   - version: 模块当前版本
    /// - Returns: 版本兼容性状态
    public func checkModuleVersion(moduleName: String, version: KJModuleVersion) -> KJVersionStatus {
        return withLock {
            _checkModuleVersion(moduleName: moduleName, version: version)
        }
    }

    /// 内部检查逻辑（必须在锁内调用）
    private func _checkModuleVersion(moduleName: String, version: KJModuleVersion) -> KJVersionStatus {
        guard let fwModuleVersion = frameworkModuleVersion else {
            return .incompatible
        }

        // 检查最低版本要求
        if let minModuleVersion = minimumModuleVersions[moduleName], version < minModuleVersion {
            return .incompatible
        }

        // 主版本必须一致
        if version.major != fwModuleVersion.major {
            return .incompatible
        }

        // 详细版本比较
        if version > fwModuleVersion {
            return .newer
        } else if version < fwModuleVersion {
            return .outdated
        } else {
            return .compatible
        }
    }

    /// 批量检查所有已注册模块版本
    /// - Returns: 各模块的检查结果数组
    public func checkAllRegisteredModules() -> [(moduleName: String, status: KJVersionStatus)] {
        return withLock {
            guard frameworkModuleVersion != nil else {
                return moduleModuleVersions.map { ($0.key, .incompatible) }
            }

            return moduleModuleVersions.map { (moduleName, version) in
                let status = _checkModuleVersion(moduleName: moduleName, version: version)
                return (moduleName, status)
            }
        }
    }

    // MARK: - 查询方法

    /// 获取当前注册的框架版本
    public func currentFrameworkModuleVersion() -> KJModuleVersion? {
        return withLock { frameworkModuleVersion }
    }

    /// 获取指定模块的最低要求版本
    public func minimumModuleVersion(for moduleName: String) -> KJModuleVersion? {
        return withLock { minimumModuleVersions[moduleName] }
    }

    // MARK: - 测试辅助
    /// 重置所有状态（仅用于测试）
    public func resetForTesting() {
        withLock {
            frameworkModuleVersion = nil
            minimumModuleVersions.removeAll()
            moduleModuleVersions.removeAll()
        }
    }
}


