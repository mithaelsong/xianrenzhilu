// KJ-GL-14_服务调用.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os

// MARK: - KJServiceRegistry
// MARK: - 服务注册表
public final class KJServiceRegistry: @unchecked Sendable {
    public static let shared = KJServiceRegistry()
    private init() {}
    
    public func register(service: KJServiceDescriptor, instance: AnyObject) {}
    public func getService(name: String) -> AnyObject? { return nil }
    public func resolve<T>(_ type: T.Type) -> T? { return nil }
    public func resolve<T>(moduleName: String, serviceName: String, type: T.Type, minimumVersion: String? = nil) -> T? { return nil }
    public func resolve<T>(serviceName: String, type: T.Type, minimumVersion: String? = nil) -> T? { return nil }
    
    public func register<T>(_ instance: T, serviceName: String, moduleName: String, version: String, protocolType: T.Type) {}
}

// MARK: - KJServiceInvoker
// MARK: - 迁移自 KJ-GL-14_服务调用.swift
// MARK: - 服务调用器
/// 服务调用器 (功能14)
/// 提供便捷的闭包风格服务调用，封装 ServiceRegistry 的查找逻辑
/// 支持指定模块调用和任意模块调用两种模式
public final class KJServiceInvoker: @unchecked Sendable {
    public static let shared = KJServiceInvoker()
    
    private let registry = KJServiceRegistry.shared
    private let logger = KJModuleLogger.shared
    
    /// 内部初始化（用于测试创建独立实例）
    internal init() {}
    
    // MARK: - 调用指定模块的服务
    /// 调用指定模块的指定服务，通过闭包执行方法
    /// 类型由闭包参数推断，编译期保证类型安全
    /// - Parameters:
    ///   - moduleName: 模块名称
    ///   - serviceName: 服务名称
    ///   - method: 接收服务实例并返回结果的闭包
    /// - Returns: 闭包返回的结果，如果服务未找到返回 nil
    public func invoke<T, R>(
        moduleName: String,
        serviceName: String,
        method: (T) -> R
    ) -> R? {
        guard let service: T = registry.resolve(moduleName: moduleName, serviceName: serviceName, type: T.self) else {
            logger.warning("KJServiceInvoker", "调用失败: 无法解析 \(moduleName).\(serviceName) 为 \(String(describing: T.self))")
            return nil
        }
        return method(service)
    }
    
    // MARK: - 调用任意提供该服务的模块
    /// 按服务名查找任意提供该服务的模块，通过闭包执行方法
    /// 支持最低版本要求，返回第一个匹配版本的服务实例
    /// - Parameters:
    ///   - serviceName: 服务名称
    ///   - method: 接收服务实例并返回结果的闭包
    ///   - minimumVersion: 最低版本要求（可选）
    /// - Returns: 闭包返回的结果，如果服务未找到返回 nil
    public func invokeAny<T, R>(
        serviceName: String,
        method: (T) -> R,
        minimumVersion: String? = nil
    ) -> R? {
        guard let service: T = registry.resolve(serviceName: serviceName, type: T.self, minimumVersion: minimumVersion) else {
            logger.warning("KJServiceInvoker", "任意调用失败: 无法解析服务 '\(serviceName)' (最低版本: \(minimumVersion ?? "无"))")
            return nil
        }
        return method(service)
    }
    
    // MARK: - 异步调用
    /// 异步调用指定模块的服务，在全局队列执行后回调到主队列
    /// - Parameters:
    ///   - moduleName: 模块名称
    ///   - serviceName: 服务名称
    ///   - method: 接收服务实例并返回结果的闭包
    ///   - completion: 完成回调（主队列）
    public func invokeAsync<T, R>(
        moduleName: String,
        serviceName: String,
        method: @escaping (T) -> R,
        completion: @escaping (R?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.invoke(moduleName: moduleName, serviceName: serviceName, method: method)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}


// MARK: - KJXRZModule 服务注册扩展
/// 为 KJXRZModule 提供便捷的注册服务方法
/// 模块在 start() 中可通过 self.registerService(...) 暴露服务
public extension KJXRZModule {
    /// 便捷方法：从模块注册服务到 ServiceRegistry
    /// - Parameters:
    ///   - instance: 服务实例
    ///   - serviceName: 服务名称
    ///   - moduleName: 提供服务的模块名称
    ///   - version: 服务版本号
    ///   - protocolType: 服务协议类型
    func registerService<T>(
        _ instance: T,
        serviceName: String,
        moduleName: String,
        version: String,
        protocolType: T.Type
    ) {
        KJServiceRegistry.shared.register(
            instance,
            serviceName: serviceName,
            moduleName: moduleName,
            version: version,
            protocolType: protocolType
        )
    }
}
