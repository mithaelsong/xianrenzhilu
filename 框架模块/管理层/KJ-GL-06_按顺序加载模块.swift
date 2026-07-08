// KJ-GL-06_按顺序加载模块.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os

// MARK: - KJModuleLoader
// MARK: - 模块加载器
public final class KJModuleLoader: @unchecked Sendable {
    public static let shared = KJModuleLoader()
    private init() {}
    
    public func load(moduleID: String) -> KJModuleLoadResult {
        return .failure(moduleID, NSError(domain: "stub", code: 0))
    }
    
    public func scanAndLoad(from path: String) {}
    public func unloadAllModules() {}
}


// MARK: - 依赖解析器
public struct KJDependencyResolver {
    public static func resolveLoadOrder(modules: [KJScannedModule]) throws -> [KJScannedModule] {
        let moduleMap = Dictionary(uniqueKeysWithValues: modules.map { ($0.metadata.name, $0) })
        var graph: [String: [String]] = [:]
        for module in modules {
            let deps = module.metadata.dependencies
            graph[module.metadata.name] = deps.compactMap { dep in
                moduleMap[dep] != nil ? dep : nil
            }
        }
        var visited = Set<String>()
        var tempMarked = Set<String>()
        var result: [KJScannedModule] = []
        func visit(_ name: String) throws {
            if tempMarked.contains(name) {
                throw KJDependencyResolverError.circularDependency(path: Array(tempMarked))
            }
            if visited.contains(name) { return }
            tempMarked.insert(name)
            for dep in graph[name] ?? [] { try visit(dep) }
            tempMarked.remove(name)
            visited.insert(name)
            if let module = moduleMap[name] { result.append(module) }
        }
        for module in modules { try visit(module.metadata.name) }
        return result
    }
}
