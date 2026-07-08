// KJ-GL-01_模块注册表.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os

// MARK: - KJModuleRegistry
// MARK: - 模块注册表
/// 模块注册表（单例）
/// 所有模块通过此注册表发现和互相调用
public final class KJModuleRegistry : @unchecked Sendable {
    public static let shared = KJModuleRegistry()
    private init() {}
    
    private var modules: [String: AnyObject] = [:]
    private var metadata: [String: KJModuleMetadata] = [:]
    private var managementLayerFileRegistrations: [String: KJManagementLayerFileRegistration] = [:]
    private var functionLayerFileRegistrations: [String: KJManagementLayerFileRegistration] = [:]
    private var lock = os_unfair_lock()
    
    public var allModuleNames: [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return Array(modules.keys)
    }
    
    public func register(module: AnyObject, name: String, metadata: KJModuleMetadata? = nil) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        modules[name] = module
        if let meta = metadata {
            self.metadata[name] = meta
        }
    }
    
    public func unregister(name: String) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        modules.removeValue(forKey: name)
        metadata.removeValue(forKey: name)
    }
    
    public func isLoaded(name: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return modules[name] != nil
    }
    
    public func getModule(name: String) -> AnyObject? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return modules[name]
    }
    
    public func getMetadata(name: String) -> KJModuleMetadata? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return metadata[name]
    }
    
    public func getModulesConformingTo<T>(protocolType: T.Type) -> [String: AnyObject] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        var result: [String: AnyObject] = [:]
        for (name, module) in modules {
            if module is T {
                result[name] = module
            }
        }
        return result
    }
    
    public var stats: KJModuleRegistryStats {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return KJModuleRegistryStats(totalModules: modules.count, moduleNames: Array(modules.keys))
    }

    public func registerManagementLayerFile(_ registration: KJManagementLayerFileRegistration) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        managementLayerFileRegistrations[registration.id] = registration
    }

    @discardableResult
    public func registerManagementLayerFiles(_ registrations: [KJManagementLayerFileRegistration]) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        for registration in registrations {
            managementLayerFileRegistrations[registration.id] = registration
        }
        return managementLayerFileRegistrations.count
    }

    public func getManagementLayerFileRegistration(id: String) -> KJManagementLayerFileRegistration? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return managementLayerFileRegistrations[id]
    }

    public var allManagementLayerFileRegistrations: [KJManagementLayerFileRegistration] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return managementLayerFileRegistrations.values.sorted { $0.id < $1.id }
    }

    public var managementLayerFileRegistrationCount: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return managementLayerFileRegistrations.count
    }

    public func registerFunctionLayerFile(_ registration: KJManagementLayerFileRegistration) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        functionLayerFileRegistrations[registration.id] = registration
    }

    @discardableResult
    public func registerFunctionLayerFiles(_ registrations: [KJManagementLayerFileRegistration]) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        for registration in registrations {
            functionLayerFileRegistrations[registration.id] = registration
        }
        return functionLayerFileRegistrations.count
    }

    public func getFunctionLayerFileRegistration(id: String) -> KJManagementLayerFileRegistration? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return functionLayerFileRegistrations[id]
    }

    public var allFunctionLayerFileRegistrations: [KJManagementLayerFileRegistration] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return functionLayerFileRegistrations.values.sorted { $0.id < $1.id }
    }

    public var functionLayerFileRegistrationCount: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return functionLayerFileRegistrations.count
    }
}


// MARK: - 框架管理层16文件统一注册清单
// 版本: 2.0
public let kjManagementLayerFileRegistrations: [KJManagementLayerFileRegistration] = [
    KJManagementLayerFileRegistration(id: "KJ-GL-00", title: "主程序启动", fileName: "KJ-GL-00_主程序启动.swift", priority: "P0", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-01", title: "模块注册表", fileName: "KJ-GL-01_模块注册表.swift", priority: "P2", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-02", title: "公共类型定义", fileName: "KJ-GL-02_公共类型定义.swift", priority: "P2", role: "公共类型与统一注册表"),
    KJManagementLayerFileRegistration(id: "KJ-GL-03", title: "初始化日志系统", fileName: "KJ-GL-03_初始化日志系统.swift", priority: "P0", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-04", title: "初始化配置系统", fileName: "KJ-GL-04_初始化配置系统.swift", priority: "P0", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-05", title: "扫描模块目录", fileName: "KJ-GL-05_扫描模块目录.swift", priority: "P0", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-06", title: "按顺序加载模块", fileName: "KJ-GL-06_按顺序加载模块.swift", priority: "P0", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-07", title: "调用模块的start", fileName: "KJ-GL-07_调用模块的start.swift", priority: "P0", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-08", title: "处理模块加载失败", fileName: "KJ-GL-08_处理模块加载失败.swift", priority: "P1", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-09", title: "动态加载模块", fileName: "KJ-GL-09_动态加载模块.swift", priority: "P2", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-10", title: "动态卸载模块", fileName: "KJ-GL-10_动态卸载模块.swift", priority: "P2", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-11", title: "获取模块实例", fileName: "KJ-GL-11_获取模块实例.swift", priority: "P2", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-12", title: "模块热替换", fileName: "KJ-GL-12_模块热替换.swift", priority: "P2", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-13", title: "事件总线", fileName: "KJ-GL-13_事件总线.swift", priority: "P0", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-14", title: "服务调用", fileName: "KJ-GL-14_服务调用.swift", priority: "P0", role: "框架管理层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GL-15", title: "数据共享", fileName: "KJ-GL-15_数据共享.swift", priority: "P1", role: "框架管理层功能文件"),
]

@discardableResult
public func registerAllKJManagementLayerFiles() -> Int {
    return KJModuleRegistry.shared.registerManagementLayerFiles(kjManagementLayerFileRegistrations)
}

public func registeredKJManagementLayerFileIDs() -> [String] {
    return kjManagementLayerFileRegistrations.map { $0.id }
}

// MARK: - 框架功能层15文件统一注册清单
// 版本: 2.0
public let kjFunctionLayerFileRegistrations: [KJManagementLayerFileRegistration] = [
    KJManagementLayerFileRegistration(id: "KJ-GN-01", title: "窗口管理", fileName: "KJ-GN-01_窗口管理.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-02", title: "视图容器", fileName: "KJ-GN-02_视图容器.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-03", title: "菜单管理", fileName: "KJ-GN-03_菜单管理.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-04", title: "工具栏管理", fileName: "KJ-GN-04_工具栏管理.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-05", title: "多窗口支持", fileName: "KJ-GN-05_多窗口支持.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-06", title: "公共资源访问", fileName: "KJ-GN-06_公共资源访问.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-07", title: "模块私有资源", fileName: "KJ-GN-07_模块私有资源.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-08", title: "本地化支持", fileName: "KJ-GN-08_本地化支持.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-09", title: "模块签名验证", fileName: "KJ-GN-09_模块签名验证.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-10", title: "沙盒支持", fileName: "KJ-GN-10_沙盒支持.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-11", title: "崩溃隔离", fileName: "KJ-GN-11_崩溃隔离.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-12", title: "模块版本检查", fileName: "KJ-GN-12_模块版本检查.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-13", title: "模块热重载", fileName: "KJ-GN-13_模块热重载.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-14", title: "模块加载日志", fileName: "KJ-GN-14_模块加载日志.swift", priority: "P1", role: "框架功能层功能文件"),
    KJManagementLayerFileRegistration(id: "KJ-GN-15", title: "模块列表UI", fileName: "KJ-GN-15_模块列表UI.swift", priority: "P1", role: "框架功能层功能文件"),
]

@discardableResult
public func registerAllKJFunctionLayerFiles() -> Int {
    return KJModuleRegistry.shared.registerFunctionLayerFiles(kjFunctionLayerFileRegistrations)
}

public func registeredKJFunctionLayerFileIDs() -> [String] {
    return kjFunctionLayerFileRegistrations.map { $0.id }
}

