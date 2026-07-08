// KJ-GL-07_调用模块的start.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os

// MARK: - KJModuleStarter
// MARK: - 模块启动器
public final class KJModuleStarter: @unchecked Sendable {
    public static let shared = KJModuleStarter()
    private init() {}
    
    public func start(moduleID: String, context: Any?) -> KJModuleStartResult {
        return .failure(moduleID, NSError(domain: "stub", code: 0))
    }
    
    public func isModuleStarted(_ moduleID: String) -> Bool {
        return false
    }
}

