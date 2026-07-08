// KJ-GL-05_扫描模块目录.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os

// MARK: - KJModuleScanner
// MARK: - 模块扫描器
public final class KJModuleScanner: @unchecked Sendable {
    public static let shared = KJModuleScanner()
    private init() {}
    
    public func scan(directory: String) -> [KJScannedModule] {
        return []
    }
}

