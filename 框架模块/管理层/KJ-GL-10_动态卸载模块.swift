// KJ-GL-10_动态卸载模块.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os

// MARK: - KJModuleUnloader
// MARK: - 模块卸载器
public final class KJModuleUnloader: @unchecked Sendable {
    public static let shared = KJModuleUnloader()
    private init() {}
    
    public func unload(moduleID: String) -> KJModuleUnloadResult {
        return .notFound(moduleID)
    }
    
    public func forceUnload(moduleID: String) -> KJModuleUnloadResult {
        return unload(moduleID: moduleID)
    }
}


// MARK: - Predefined Events (Extension)
public extension Notification.Name {
    /// 模块即将卸载（卸载流程开始）
    static let moduleWillUnload = Notification.Name("com.xianrenzhilu.module.willUnload")
    /// 模块已卸载（卸载流程结束）
    static let moduleDidUnload = Notification.Name("com.xianrenzhilu.module.didUnload")
}
