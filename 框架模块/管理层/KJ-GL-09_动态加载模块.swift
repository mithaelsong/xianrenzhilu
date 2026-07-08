// KJ-GL-09_动态加载模块.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os

// MARK: - KJDynamicModuleLoader
// MARK: - 动态模块加载器
public final class KJDynamicModuleLoader: @unchecked Sendable {
    public static let shared = KJDynamicModuleLoader()
    private init() {}
    
    public func loadDynamic(moduleID: String) -> KJModuleLoadResult {
        return .failure(moduleID, NSError(domain: "stub", code: 0))
    }
}

// MARK: - KJVersionChecker
// MARK: - 迁移自 KJ-GL-09_动态加载模块.swift
// Version 定义在 KJ-GL-02_公共类型定义.swift (KJVersion)
// KJXRZModule 协议定义在 KJ-GL-01_模块注册表.swift
// ModuleMetadata 定义在 KJ-GL-02_公共类型定义.swift (KJModuleMetadata)
// ScannedModule 定义在 KJ-GL-02_公共类型定义.swift (KJScannedModule)

// MARK: - VersionChecker
public final class KJVersionChecker: @unchecked Sendable {
    public static let shared = KJVersionChecker()
    private init() {}

    public func checkModuleVersion(moduleName: String, version: KJVersion) -> KJVersionStatus {
        let systemVersion = KJVersion(major: 2, minor: 0, patch: 0)
        if version == systemVersion {
            return .compatible
        } else if version < systemVersion {
            return .outdated
        } else {
            return .newer
        }
    }
}

