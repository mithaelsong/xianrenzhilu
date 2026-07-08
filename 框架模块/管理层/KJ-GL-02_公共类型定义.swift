// MARK: - KJ-GL-02: 框架公共类型定义
// 功能编号: KJ-GL-02
// 版本: 1.0.0
// 职责: 集中定义所有框架模块共享的纯数据类型和协议
// 注意: 只包含struct/enum/protocol，不包含class业务逻辑

import Foundation
import os
import AppKit

// MARK: - 版本号
public struct KJVersion: Sendable, Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    
    public var stringValue: String {
        "\(major).\(minor).\(patch)"
    }
    
    public var description: String { stringValue }
    
    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    // 从字符串解析版本（如 "1.2.3"）
    public init?(string: String) {
        let parts = string.split(separator: ".")
        guard parts.count >= 1,
              let major = Int(parts[0]) else { return nil }
        self.major = major
        self.minor = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        self.patch = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
    }
    
    public static func < (lhs: KJVersion, rhs: KJVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

// MARK: - 模块分类
public enum KJModuleCategory: String, Sendable {
    case framework, ui, skin, kline, indicator, tool, general
}

// MARK: - 模块元数据
public struct KJModuleMetadata: Sendable {
    public let id: String
    public let name: String
    public var moduleName: String { return name }
    public let version: KJVersion
    public let description: String
    public let author: String
    public let dependencies: [String]
    public let category: KJModuleCategory
    public let isUnloadable: Bool
    public let isSystem: Bool
    public let priority: Int
    
    public init(id: String = "", name: String, version: KJVersion, description: String, author: String, dependencies: [String] = [], category: KJModuleCategory = .general, isUnloadable: Bool = true, isSystem: Bool = false, priority: Int = 0) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.dependencies = dependencies
        self.category = category
        self.isUnloadable = isUnloadable
        self.isSystem = isSystem
        self.priority = priority
    }
    
    // 兼容旧版初始化（version为String）
    public init(id: String = "", name: String, version: String, description: String, author: String, dependencies: [String] = [], category: KJModuleCategory = .general, isUnloadable: Bool = true, isSystem: Bool = false, priority: Int = 0) {
        self.id = id
        self.name = name
        self.version = KJVersion(string: version) ?? KJVersion(major: 1, minor: 0, patch: 0)
        self.description = description
        self.author = author
        self.dependencies = dependencies
        self.category = category
        self.isUnloadable = isUnloadable
        self.isSystem = isSystem
        self.priority = priority
    }
}

// MARK: - 模块注册信息
public struct KJModuleRegistration: Sendable {
    public let name: String
    public let aliases: [String]
    public let priority: Int
    public let registeredAt: Date
    public let moduleID: String?
    
    public init(name: String, aliases: [String] = [], priority: Int = 0, moduleID: String? = nil) {
        self.name = name
        self.aliases = aliases
        self.priority = priority
        self.registeredAt = Date()
        self.moduleID = moduleID
    }
}

// MARK: - 模块协议
public protocol KJModuleProtocol: AnyObject {
    init()
    var moduleID: String { get }
    var moduleName: String { get }
    var moduleVersion: String { get }
    var moduleDescription: String { get }
    var isUnloadable: Bool { get }
    func start(context: Any?) throws
    func stop()
    func pause()
    func resume()
    func willUnload() throws
    func didUnload()
}

// MARK: - 日志输出协议
public protocol KJLogOutput: AnyObject {
    func write(_ entry: KJLogEntry)
}

// MARK: - 日志级别
public enum KJLogLevel: Int, Codable, Sendable, Comparable, CustomStringConvertible, CaseIterable {
    case debug = 0, info = 1, warning = 2, error = 3, critical = 4
    
    public var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
    
    public static func < (lhs: KJLogLevel, rhs: KJLogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public var emoji: String {
        switch self {
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "💥"
        }
    }
    
    public var label: String { description }
    public var color: String { description }
}

// MARK: - 日志条目
public struct KJLogEntry: Sendable {
    public let timestamp: Date
    public let level: KJLogLevel
    public let message: String
    public let moduleName: String
    public let source: String
    
    public init(timestamp: Date = Date(), level: KJLogLevel, message: String, moduleName: String, source: String = "Framework") {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.moduleName = moduleName
        self.source = source
    }
}

// MARK: - 事件类型
public struct KJEventType<T>: Sendable {
    public let rawValue: String
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - 模块扫描结果
public struct KJScannedModule: Sendable {
    public let moduleID: String
    public let bundleURL: URL
    public let metadata: KJModuleMetadata
    public var isValid: Bool { return true }
    public var validationError: String? { return nil }
    
    public init(moduleID: String, bundleURL: URL, metadata: KJModuleMetadata) {
        self.moduleID = moduleID
        self.bundleURL = bundleURL
        self.metadata = metadata
    }
}

// MARK: - 模块加载结果
public enum KJModuleLoadResult: Sendable {
    case success(String)
    case failure(String, Error)
    case alreadyLoaded(String)
}

// MARK: - 模块启动结果
public enum KJModuleStartResult: Sendable {
    case success(String)
    case failure(String, Error)
}

// MARK: - 模块卸载结果
public enum KJModuleUnloadResult: Sendable {
    case success(String)
    case failure(String, Error)
    case notFound(String)
    
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

// MARK: - 窗口状态
public enum KJWindowState: String, Codable, Sendable, CaseIterable {
    case normal, minimized, maximized, fullscreen, closed
}

// MARK: - 窗口框架
public struct KJWindowFrame: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// MARK: - 配置值
public enum KJConfigValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([KJConfigValue])
    case dictionary([String: KJConfigValue])
    
    public var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
    
    public var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }
    
    public var doubleValue: Double? {
        if case .double(let v) = self { return v }
        return nil
    }
    
    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }
}

// MARK: - 模块配置
public struct KJModuleConfig: Codable, Sendable {
    public let moduleID: String
    public let values: [String: KJConfigValue]
    
    public init(moduleID: String, values: [String: KJConfigValue] = [:]) {
        self.moduleID = moduleID
        self.values = values
    }
}

// MARK: - 服务描述符
public struct KJServiceDescriptor: Sendable {
    public let name: String
    public let version: String
    public let description: String
    
    public init(name: String, version: String, description: String) {
        self.name = name
        self.version = version
        self.description = description
    }
}

// MARK: - 资源缓存统计
public struct KJResourceCacheStats: Sendable {
    public let hitCount: Int
    public let missCount: Int
    public let totalSize: Int
    
    public init(hitCount: Int, missCount: Int, totalSize: Int) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.totalSize = totalSize
    }
}

// MARK: - 崩溃记录
public struct KJCrashRecord: Sendable {
    public let moduleID: String
    public let error: String
    public let timestamp: Date
    
    public init(moduleID: String, error: String, timestamp: Date = Date()) {
        self.moduleID = moduleID
        self.error = error
        self.timestamp = timestamp
    }
}

// MARK: - 签名状态
public enum KJSignatureStatus: Sendable {
    case valid, invalid, expired, notFound
}

// MARK: - 版本状态
public enum KJVersionStatus: Sendable {
    case compatible, incompatible, outdated, newer, unknown
}

// MARK: - 重载记录
public struct KJReloadRecord: Sendable {
    public let moduleID: String
    public let oldVersion: String
    public let newVersion: String
    public let timestamp: Date
    
    public init(moduleID: String, oldVersion: String, newVersion: String, timestamp: Date = Date()) {
        self.moduleID = moduleID
        self.oldVersion = oldVersion
        self.newVersion = newVersion
        self.timestamp = timestamp
    }
}

// MARK: - 加载记录
public struct KJLoadRecord: Codable, Sendable {
    public let moduleID: String
    public let status: String
    public let timestamp: Date
    
    public init(moduleID: String, status: String, timestamp: Date = Date()) {
        self.moduleID = moduleID
        self.status = status
        self.timestamp = timestamp
    }
}
// MARK: - 框架管理层文件注册描述
public struct KJManagementLayerFileRegistration: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let fileName: String
    public let priority: String
    public let role: String
    public let version: String

    public init(id: String, title: String, fileName: String, priority: String, role: String, version: String = "2.0") {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.priority = priority
        self.role = role
        self.version = version
    }
}

// MARK: - Registry Stats
/// Module registry statistics
public struct KJModuleRegistryStats: Sendable {
    public let totalModules: Int
    public let moduleNames: [String]
    
    public init(totalModules: Int, moduleNames: [String]) {
        self.totalModules = totalModules
        self.moduleNames = moduleNames
    }
}
// MARK: - 框架功能层公共支撑类型
public enum KJViewSlot: String, Codable, Sendable, CaseIterable, Hashable {
    case top
    case bottom
    case left
    case right
    case center
}

public struct KJSlotEntry {
    public let moduleName: String
    public let view: NSView
    public let priority: Int

    public init(moduleName: String, view: NSView, priority: Int) {
        self.moduleName = moduleName
        self.view = view
        self.priority = priority
    }
}

public struct KJMenuItemDefinition {
    public let identifier: String
    public let title: String
    public let action: Selector?
    public let target: AnyObject?
    public let keyEquivalent: String

    public init(identifier: String, title: String, action: Selector? = nil, target: AnyObject? = nil, keyEquivalent: String = "") {
        self.identifier = identifier
        self.title = title
        self.action = action
        self.target = target
        self.keyEquivalent = keyEquivalent
    }
}

public struct KJToolbarItemDefinition {
    public let identifier: String
    public let label: String
    public let paletteLabel: String
    public let tooltip: String
    public let icon: NSImage?
    public let action: (() -> Void)?

    public init(identifier: String, label: String, paletteLabel: String? = nil, tooltip: String = "", icon: NSImage? = nil, action: (() -> Void)? = nil) {
        self.identifier = identifier
        self.label = label
        self.paletteLabel = paletteLabel ?? label
        self.tooltip = tooltip
        self.icon = icon
        self.action = action
    }
}

public struct KJModuleWindow {
    public let identifier: String
    public var title: String
    public var window: NSWindow?
    public var frame: NSRect
    public var isVisible: Bool

    public init(identifier: String, title: String, window: NSWindow? = nil, frame: NSRect = .zero, isVisible: Bool = true) {
        self.identifier = identifier
        self.title = title
        self.window = window
        self.frame = frame
        self.isVisible = isVisible
    }
}

public struct KJSecurityScopedAccessResult {
    public let startAccessing: Bool
    public let stopHandler: () -> Void

    public init(startAccessing: Bool, stopHandler: @escaping () -> Void) {
        self.startAccessing = startAccessing
        self.stopHandler = stopHandler
    }
}

public struct KJFileAccessCheckResult {
    public let canRead: Bool
    public let canWrite: Bool
    public let exists: Bool
    public let isDirectory: Bool
    public let error: String?

    public init(canRead: Bool, canWrite: Bool, exists: Bool, isDirectory: Bool, error: String?) {
        self.canRead = canRead
        self.canWrite = canWrite
        self.exists = exists
        self.isDirectory = isDirectory
        self.error = error
    }
}

public enum KJPermissionType: String, Codable, Sendable, CaseIterable {
    case network
    case fileRead
    case fileWrite
    case userSelectedFile
}

public enum KJSandboxPathType: String, Codable, Sendable, CaseIterable {
    case documents
    case applicationSupport
    case caches
    case temp
}

public struct KJSandboxPermissions: Codable, Sendable, Equatable {
    public var networkAccess: Bool
    public var fileRead: Bool
    public var fileWrite: Bool
    public var userSelectedFileAccess: Bool

    public static let `default` = KJSandboxPermissions(networkAccess: true, fileRead: true, fileWrite: true, userSelectedFileAccess: true)

    public init(networkAccess: Bool, fileRead: Bool, fileWrite: Bool, userSelectedFileAccess: Bool) {
        self.networkAccess = networkAccess
        self.fileRead = fileRead
        self.fileWrite = fileWrite
        self.userSelectedFileAccess = userSelectedFileAccess
    }
}

public typealias KJModuleVersion = KJVersion

public protocol KJModuleHotReloaderDelegate: AnyObject {
    func compileModule(moduleName: String, sourceDirectory: URL) -> Bool
    func performHotReload(moduleName: String) -> Bool
}


public enum KJCrashError: Error, CustomStringConvertible {
    case moduleDisabled(moduleName: String)
    case moduleCrashed(moduleName: String, underlyingError: String)

    public var description: String {
        switch self {
        case .moduleDisabled(let moduleName): return "模块已禁用: \(moduleName)"
        case .moduleCrashed(let moduleName, let underlyingError): return "模块崩溃: \(moduleName), \(underlyingError)"
        }
    }
}

// 框架管理层16文件统一注册清单已迁回 KJ-GL-01_模块注册表.swift。

// MARK: - 模块错误
public enum KJModuleError: Error {
    case loadFailed
    case startFailed
    case stopFailed
    case unloadFailed
    case notFound
    case invalidState
}

// MARK: - XRZModule 协议（从 KJ-GL-06 移入）
public protocol KJXRZModule {
    var moduleName: String { get }
    var moduleVersion: String { get }
    var moduleDependencies: [String] { get }
    func initialize() throws
    func start() throws
    func stop() throws
}

// MARK: - 依赖解析错误
public enum KJDependencyResolverError: Error, LocalizedError {
    case circularDependency(path: [String])

    public var errorDescription: String? {
        switch self {
        case .circularDependency(let path):
            return "检测到循环依赖: \(path.joined(separator: " -> "))"
        }
    }
}

// MARK: - 模块启动错误（从 KJ-GL-07 移入）
public enum KJModuleStartError: Error, CustomStringConvertible {
    case moduleNotFound(name: String)
    case moduleNotConformingToProtocol(name: String)
    case dependencyMissing(name: String, dependency: String)
    case dependencyCycle(cycle: [String])
    case simulatedFailure(name: String)

    public var description: String {
        switch self {
        case .moduleNotFound(let name):
            return "模块未找到: \(name)"
        case .moduleNotConformingToProtocol(let name):
            return "模块 \(name) 未遵循 XRZModule 协议"
        case .dependencyMissing(let name, let dep):
            return "模块 \(name) 缺少依赖: \(dep)"
        case .dependencyCycle(let cycle):
            return "依赖循环: \(cycle.joined(separator: " -> "))"
        case .simulatedFailure(let name):
            return "模块 \(name) 启动模拟失败"
        }
    }
}

// MARK: - 启动结果（从 KJ-GL-07 移入）
public enum KJStartAllResult {
    case success(started: [String], failed: [(String, Error)])
    case failure(reason: KJStartAllFailureReason)
}

// MARK: - 启动失败原因（从 KJ-GL-07 移入）
public enum KJStartAllFailureReason {
    case dependencyCycle(cycle: [String])
}


// MARK: - 框架模块加载失败公共类型
public enum KJModuleFailureType: Sendable, Equatable {
    case dependencyMissing(module: String, dependency: String)
    case circularDependency(path: [String])
    case versionIncompatible(module: String, required: String, actual: String)
    case configurationError(module: String, reason: String)
    case loadTimeout(module: String, duration: TimeInterval)
}

public enum KJModuleFailureResolution: Sendable, Equatable {
    case retry(delay: TimeInterval)
    case downgrade
    case useDefaultConfig
    case abort
    case giveUp
}
// MARK: - 迁移自 KJ-GL-07_调用模块的start.swift
// KJXRZModule 协议定义在 KJ-GL-01_模块注册表.swift
// ModuleMetadata 定义在 KJ-GL-02_公共类型定义.swift
// ModuleLogger 定义在 KJ-GL-02_公共类型定义.swift
// ModuleRegistry 定义在 KJ-GL-02_公共类型定义.swift
// ConfigSystem 定义在 KJ-GL-02_公共类型定义.swift

// MARK: - 拓扑排序结果
private enum KJTopologySortResult {
    case success(order: [String])
    case failure(cycle: [String])
}


// MARK: - 迁移自 KJ-GL-08_处理模块加载失败.swift
// 使用 KJ-GL-02 的公共类型：KJModuleLogger

// MARK: - 重试记录
/// 单个模块重试的状态记录
public struct KJRetryRecord {
    var count: Int = 0
    var nextRetryAt: Date?
}
// MARK: - 迁移自 KJ-GL-10_动态卸载模块.swift
// KJXRZModule 协议定义在 KJ-GL-01_模块注册表.swift
// ModuleMetadata 定义在 KJ-GL-02_公共类型定义.swift
// KJModuleLogger 定义在 KJ-GL-02_公共类型定义.swift
// KJEventBus 定义在 KJ-GL-02_公共类型定义.swift
// KJModuleRegistry 定义在 KJ-GL-02_公共类型定义.swift

// MARK: - 模块元数据
/// 描述模块基本信息的元数据结构

// MARK: - KJModuleLogger (自包含)
/// 模块专用日志记录器，基于 os.Logger 实现

// MARK: - KJEventBus (自包含)
/// 事件总线，使用 Foundation NotificationCenter 实现

// MARK: - KJModuleRegistry (自包含)
/// 模块注册表，全局单例

// ============================================================
// 功能10 核心代码
// ============================================================

// MARK: - Unload Result
/// 模块卸载结果枚举

// MARK: - 迁移自 KJ-GL-12_模块热替换.swift
// MARK: - 已迁移类型
// 热替换相关公共类型已迁移到 KJ-GL-02_公共类型定义.swift。

// MARK: - KJModuleHotSwapper
/// Module Hot Swapper (Function 12)
/// Hot swap modules at runtime with full rollback on failure
@available(macOS 11.0, *)

// MARK: - 框架模块热替换公共类型
public protocol KJModuleStateSavable: AnyObject {
    func saveState() -> [String: Any]
    func restoreState(_ state: [String: Any])
}

public enum KJHotSwapFailureReason: Error, CustomStringConvertible {
    case moduleNotLoaded(name: String)
    case newModuleNotFound(path: String)
    case newModuleInvalid(name: String, reason: String)
    case unloadFailed(name: String, error: Error)
    case loadFailed(name: String, error: Error)
    case startFailed(name: String, error: Error)
    case stateRestoreFailed(name: String, error: Error)
    case rollbackFailed(name: String, originalError: Error)
    case dependencyBroken(name: String, missing: [String])

    public var description: String {
        switch self {
        case .moduleNotLoaded(let name): return "模块未加载: \(name)"
        case .newModuleNotFound(let path): return "新模块路径不存在: \(path)"
        case .newModuleInvalid(let name, let reason): return "新模块无效: \(name), \(reason)"
        case .unloadFailed(let name, let error): return "卸载失败: \(name), \(error)"
        case .loadFailed(let name, let error): return "加载失败: \(name), \(error)"
        case .startFailed(let name, let error): return "启动失败: \(name), \(error)"
        case .stateRestoreFailed(let name, let error): return "状态恢复失败: \(name), \(error)"
        case .rollbackFailed(let name, let originalError): return "回滚失败: \(name), \(originalError)"
        case .dependencyBroken(let name, let missing): return "依赖破坏: \(name), \(missing.joined(separator: ","))"
        }
    }
}

public enum KJHotSwapResult {
    case success(moduleName: String, fromVersion: String, toVersion: String)
    case failure(moduleName: String, reason: KJHotSwapFailureReason)
    case rolledBack(moduleName: String, reason: KJHotSwapFailureReason)

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var isRolledBack: Bool {
        if case .rolledBack = self { return true }
        return false
    }
}

public struct KJModuleStateSnapshot {
    public let moduleName: String
    public let version: String
    public let state: [String: Any]
    public let metadata: KJModuleMetadata?

    public init(moduleName: String, version: String, state: [String: Any], metadata: KJModuleMetadata?) {
        self.moduleName = moduleName
        self.version = version
        self.state = state
        self.metadata = metadata
    }
}

public struct KJModuleBackup {
    public let instance: Any
    public let metadata: KJModuleMetadata?
    public let stateSnapshot: KJModuleStateSnapshot
    public let wasStarted: Bool

    public init(instance: Any, metadata: KJModuleMetadata?, stateSnapshot: KJModuleStateSnapshot, wasStarted: Bool) {
        self.instance = instance
        self.metadata = metadata
        self.stateSnapshot = stateSnapshot
        self.wasStarted = wasStarted
    }
}
// MARK: - 迁移自 KJ-GL-14_服务调用.swift
// KJXRZModule 协议定义在 KJ-GL-01_模块注册表.swift
// ModuleLogger 定义在 KJ-GL-02_公共类型定义.swift

// MARK: - 服务描述符
/// 服务描述符，描述一个模块提供的服务
/// 用于服务发现时返回元信息，不包含实际实例

// MARK: - 服务注册表
/// 服务注册表 (功能14)
/// 管理模块提供的服务注册和发现，是模块间通过协议调用的核心机制
/// 特性:
/// - 模块通过协议声明自己提供的服务（类型安全）
/// - 按服务名称查找所有提供该服务的模块（服务发现）
/// - 通过模块名称 + 服务名称精确获取服务实例（服务调用）
/// - 支持简单版本号匹配（minimumVersion 过滤）
/// - 线程安全（os_unfair_lock 保护）
/// - 模块卸载时自动注销该模块的所有服务

// KJXRZModule 服务注册扩展已迁回 KJ-GL-14_服务调用.swift。

