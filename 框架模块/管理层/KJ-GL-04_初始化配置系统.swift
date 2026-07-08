// KJ-GL-04_初始化配置系统.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os

// MARK: - KJConfigSystem
// MARK: - 配置系统
public final class KJConfigSystem: @unchecked Sendable {
    public static let shared = KJConfigSystem()
    private init() {}
    
    public func initialize() {}
    
    public func getValue(_ key: String) -> KJConfigValue? {
        return nil
    }
    
    public func getModuleDependencies(_ moduleName: String) -> [String] {
        return []
    }
    
    public func setValue(_ key: String, value: KJConfigValue) {}
}

