// KJ-GL-11_获取模块实例.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os

// MARK: - KJModuleAccessor
// MARK: - 迁移自 KJ-GL-11_获取模块实例.swift
// LogLevel, KJModuleRegistry, KJServiceRegistry, KJModuleLogger, KJModuleStarter
// are all defined in KJ-GL-02_公共类型定义.swift, so no stubs needed here.

// MARK: - KJModuleAccessor
/// Module Accessor (Function 11)
/// Provides safe module instance access as the unified entry point
/// Features:
/// - Get module instances via KJModuleRegistry
/// - Check start status via KJModuleStarter
/// - Get module services via KJServiceRegistry (recommended)
/// - Type-safe generic access methods
/// - Thread-safe (protected by os_unfair_lock)
/// - Logs access operations via KJModuleLogger
public final class KJModuleAccessor: @unchecked Sendable {
    public static let shared = KJModuleAccessor()

    private let registry: KJModuleRegistry
    private let starter: KJModuleStarter
    private let logger: KJModuleLogger

    /// Thread-safety lock
    private final class LockStorage: @unchecked Sendable {
        var lock = os_unfair_lock()
    }

    private let lockStorage = LockStorage()

    /// Private initializer using shared instance
    private init() {
        self.registry = KJModuleRegistry.shared
        self.starter = KJModuleStarter.shared
        self.logger = KJModuleLogger.shared
    }

    /// Injectable initializer (for testing or custom scenarios)
    /// - Parameters:
    ///   - registry: Module registry
    ///   - starter: Module starter
    public init(registry: KJModuleRegistry, starter: KJModuleStarter) {
        self.registry = registry
        self.starter = starter
        self.logger = KJModuleLogger.shared
    }

    // MARK: - Getting Module Instance

    /// Get module instance by name
    /// - Parameter name: Module name
    /// - Returns: Module instance, or nil if not found
    public func getModule(_ name: String) -> Any? {
        os_unfair_lock_lock(&lockStorage.lock)
        defer { os_unfair_lock_unlock(&lockStorage.lock) }

        logger.log(level: .debug, category: "KJModuleAccessor", message: "获取模块: \(name)")
        return registry.getModule(name: name)
    }

    // MARK: - Type-Safe Module Access

    /// Type-safely get module instance by name
    /// - Parameter name: Module name
    /// - Returns: Typed module instance, or nil if not found or type mismatch
    public func getModuleAs<T>(_ name: String) -> T? {
        os_unfair_lock_lock(&lockStorage.lock)
        defer { os_unfair_lock_unlock(&lockStorage.lock) }

        logger.log(level: .debug, category: "KJModuleAccessor", message: "类型安全获取模块: \(name) 为 \(String(describing: T.self))")

        guard let module = registry.getModule(name: name) else {
            logger.log(level: .warning, category: "KJModuleAccessor", message: "模块 \(name) 未加载，无法获取")
            return nil
        }

        guard let typed = module as? T else {
            logger.log(level: .error, category: "KJModuleAccessor", message: "模块 \(name) 类型不匹配: 期望 \(String(describing: T.self)), 实际 \(type(of: module))")
            return nil
        }

        return typed
    }

    // MARK: - Getting Services

    /// Get a service provided by a module
    /// Find service via KJServiceRegistry (registered in start() via registerService)
    /// - Parameters:
    ///   - module: Module name
    ///   - service: Service name
    /// - Returns: Service instance, or nil if not found or module not loaded
    public func getService(_ module: String, _ service: String) -> Any? {
        os_unfair_lock_lock(&lockStorage.lock)
        defer { os_unfair_lock_unlock(&lockStorage.lock) }

        logger.log(level: .debug, category: "KJModuleAccessor", message: "获取服务: \(module).\(service)")

        // Check if module is loaded
        guard registry.isLoaded(name: module) else {
            logger.log(level: .warning, category: "KJModuleAccessor", message: "无法获取服务 \(module).\(service): 模块未加载")
            return nil
        }

        // Get via KJServiceRegistry (Any.self for untyped access)
        let result = KJServiceRegistry.shared.resolve(Any.self)

        if result == nil {
            logger.log(level: .warning, category: "KJModuleAccessor", message: "服务 \(module).\(service) 未找到")
        } else {
            logger.log(level: .debug, category: "KJModuleAccessor", message: "已获取服务 \(module).\(service)")
        }

        return result
    }

    // MARK: - Type-Safe Service Access

    /// Type-safely get a service from a module
    /// - Parameters:
    ///   - module: Module name
    ///   - service: Service name
    /// - Returns: Typed service instance, or nil if not found/type mismatch/module not loaded
    public func getModuleService<T>(_ module: String, _ service: String) -> T? {
        os_unfair_lock_lock(&lockStorage.lock)
        defer { os_unfair_lock_unlock(&lockStorage.lock) }

        logger.log(level: .debug, category: "KJModuleAccessor", message: "类型安全获取服务: \(module).\(service) 为 \(String(describing: T.self))")

        // Check if module is loaded
        guard registry.isLoaded(name: module) else {
            logger.log(level: .warning, category: "KJModuleAccessor", message: "无法获取服务 \(module).\(service): 模块未加载")
            return nil
        }

        // Get via KJServiceRegistry type-safe
        let result: T? = KJServiceRegistry.shared.resolve(T.self)

        if result == nil {
            logger.log(level: .warning, category: "KJModuleAccessor", message: "类型安全服务 \(module).\(service) 为 \(String(describing: T.self)) 未找到")
        } else {
            logger.log(level: .debug, category: "KJModuleAccessor", message: "已获取类型安全服务 \(module).\(service)")
        }

        return result
    }

    // MARK: - Status Check

    /// Check if module is loaded in registry
    /// - Parameter name: Module name
    /// - Returns: Whether loaded
    public func isModuleLoaded(_ name: String) -> Bool {
        os_unfair_lock_lock(&lockStorage.lock)
        defer { os_unfair_lock_unlock(&lockStorage.lock) }

        let loaded = registry.isLoaded(name: name)
        logger.log(level: .debug, category: "KJModuleAccessor", message: "检查模块加载状态: \(name) = \(loaded)")
        return loaded
    }

    // MARK: - Start Status Check

    /// Check if module has started
    /// - Parameter name: Module name
    /// - Returns: Whether started
    public func isModuleStarted(_ name: String) -> Bool {
        os_unfair_lock_lock(&lockStorage.lock)
        defer { os_unfair_lock_unlock(&lockStorage.lock) }

        let started = starter.isModuleStarted(name)
        logger.log(level: .debug, category: "KJModuleAccessor", message: "检查模块启动状态: \(name) = \(started)")
        return started
    }
}

