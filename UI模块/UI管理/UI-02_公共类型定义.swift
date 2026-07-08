// MARK: - UI-02: 公共类型定义
// 功能编号: UI-02
// 版本: 2.0
// 职责: 集中定义 UI 模块共享的公共类型、协议签名、数据模型和初始化器
// 规则: 禁止 class、actor、extension、顶层功能函数、顶层 let/var；功能实现必须在对应功能文件中

import Foundation
import AppKit
import os
import CoreText
import JavaScriptCore
import Metal
import MetalKit
import QuartzCore
import SwiftUI
import os.log


// MARK: - UI模块分类
public enum UIModuleCategory: String, Codable, Sendable {
    case framework
    case ui
    case skin
    case kline
    case indicator
    case tool
    case general
}

// MARK: - UI模块扫描元数据
public struct UIModuleMetadata: Codable, Sendable {
    public let moduleID: String
    public let moduleName: String
    public let version: String
    public let minFrameworkVersion: String?
    public let dependencies: [String]
    public let author: String?
    public let description: String?
    public let isBuiltIn: Bool
    public let category: UIModuleCategory
    
    public init(moduleID: String, moduleName: String, version: String, minFrameworkVersion: String?, dependencies: [String], author: String?, description: String?, isBuiltIn: Bool, category: UIModuleCategory = .general) {
        self.moduleID = moduleID
        self.moduleName = moduleName
        self.version = version
        self.minFrameworkVersion = minFrameworkVersion
        self.dependencies = dependencies
        self.author = author
        self.description = description
        self.isBuiltIn = isBuiltIn
        self.category = category
    }
}

// MARK: - UI模块注册信息
public struct UIModuleRegistration: Sendable {
    public let name: String
    public let aliases: [String]
    public let metadata: UIModuleMetadata?
    public let isEnabled: Bool
    
    public init(name: String, aliases: [String] = [], metadata: UIModuleMetadata? = nil, isEnabled: Bool = true) {
        self.name = name
        self.aliases = aliases
        self.metadata = metadata
        self.isEnabled = isEnabled
    }
}

// MARK: - UI版本状态
public enum UIVersionStatus: String, Sendable {
    case compatible, incompatible, outdated, newer, unknown
}

// MARK: - UI版本号
public struct UIVersion: Codable, Equatable, Comparable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var stringValue: String { patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)" }

    public static func == (lhs: UIVersion, rhs: UIVersion) -> Bool {
        lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }

    public static func < (lhs: UIVersion, rhs: UIVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    public static func parse(_ string: String) -> UIVersion? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ".")
        guard parts.count == 2 || parts.count == 3,
              let mj = Int(parts[0]),
              let mn = Int(parts[1]) else {
            return nil
        }
        let pt = parts.count == 3 ? (Int(parts[2]) ?? 0) : 0
        return UIVersion(major: mj, minor: mn, patch: pt)
    }

    public init?(string: String) {
        guard let v = UIVersion.parse(string) else { return nil }
        self = v
    }
}

// MARK: - UI版本范围
public struct UIVersionRange: Codable, Equatable, Sendable {
    public let minVersion: UIVersion
    public let maxVersion: UIVersion

    public init(minVersion: UIVersion, maxVersion: UIVersion) {
        self.minVersion = minVersion
        self.maxVersion = maxVersion
    }

    public func contains(_ version: UIVersion) -> Bool {
        version >= minVersion && version <= maxVersion
    }
}

// MARK: - UI版本兼容性
public enum UIVersionCompatibility: Sendable, Equatable {
    case compatible
    case incompatible(reason: String)
    case requiresUpdate(current: UIVersion, required: UIVersion)
    case deprecated(current: UIVersion, latest: UIVersion)
}

// MARK: - UI模块加载结果
public enum UIModuleLoadResult: Sendable, Equatable {
    case success(moduleID: String)
    case alreadyLoaded(moduleID: String)
    case loadFailed(moduleID: String, error: String)
    case timedOut(moduleID: String, timeout: TimeInterval)
    case cancelled(moduleID: String)
    case failure(Error)
    case notFound
    case incompatible(moduleID: String, reason: String)
    case missingDependency(moduleID: String, dependency: String)

    public static func == (lhs: UIModuleLoadResult, rhs: UIModuleLoadResult) -> Bool {
        switch (lhs, rhs) {
        case (.success(let a), .success(let b)): return a == b
        case (.alreadyLoaded(let a), .alreadyLoaded(let b)): return a == b
        case (.loadFailed(let a1, let a2), .loadFailed(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.timedOut(let a1, let a2), .timedOut(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.cancelled(let a), .cancelled(let b)): return a == b
        case (.incompatible(let a1, let a2), .incompatible(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.missingDependency(let a1, let a2), .missingDependency(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.failure, .failure): return true
        case (.notFound, .notFound): return true
        default: return false
        }
    }
}

// MARK: - 窗口记录
public struct UIWindowRecord: Sendable {
    public let windowID: String
    public let window: NSWindow
    public let windowController: NSWindowController?
    public let moduleName: String
    public let creationTime: Date
    public var isClosed: Bool
    public var frame: NSRect?
    public var zIndex: Int
    
    public mutating func markClosed() { isClosed = true }
    public mutating func touch() { }
    
    public init(windowID: String, window: NSWindow, windowController: NSWindowController?, moduleName: String, creationTime: Date, isClosed: Bool, frame: NSRect?, zIndex: Int) {
        self.windowID = windowID
        self.window = window
        self.windowController = windowController
        self.moduleName = moduleName
        self.creationTime = creationTime
        self.isClosed = isClosed
        self.frame = frame
        self.zIndex = zIndex
    }
}

// MARK: - 窗口信息
public struct UIWindowInfo: Sendable {
    public let id: String
    public let title: String
    public let moduleName: String
    public let createdAt: Date
    public var isVisible: Bool
    
    public init(id: String, title: String, moduleName: String, createdAt: Date = Date(), isVisible: Bool = true) {
        self.id = id
        self.title = title
        self.moduleName = moduleName
        self.createdAt = createdAt
        self.isVisible = isVisible
    }
}

// MARK: - 皮肤信息
public struct UISkinInfo: Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let author: String
    public let description: String
    public let previewImage: Data?
    public let isDefault: Bool
    public let isSystem: Bool
    public let tags: [String]
    public let minEngineVersion: String
    
    public init(id: String, name: String, version: String, author: String, description: String, previewImage: Data? = nil, isDefault: Bool = false, isSystem: Bool = false, tags: [String] = [], minEngineVersion: String = "2.0") {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.description = description
        self.previewImage = previewImage
        self.isDefault = isDefault
        self.isSystem = isSystem
        self.tags = tags
        self.minEngineVersion = minEngineVersion
    }
}

// MARK: - 皮肤协议
public protocol UISkinProtocol: AnyObject {
    init()
    var skinId: String { get }
    var skinName: String { get }
    var skinVersion: String { get }
    func apply(to window: NSWindow)
    func apply(to view: NSView)
    func isSupported() -> Bool
}

// MARK: - 功能协议
public protocol UIFeatureProtocol: AnyObject {
    var featureName: String { get }
    var featureVersion: String { get }
    var featureDescription: String { get }
}

// MARK: - 日志级别
public enum UILogLevel: Int, Codable, Sendable, Comparable, CustomStringConvertible, CaseIterable {
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
    
    public var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
    
    public var color: NSColor {
        switch self {
        case .debug: return .secondaryLabelColor
        case .info: return .labelColor
        case .warning: return .systemOrange
        case .error: return .systemRed
        case .critical: return .systemPurple
        }
    }
    
    public static func < (lhs: UILogLevel, rhs: UILogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 启动上下文
public struct UIModuleStartContext: @unchecked Sendable {
    public var config: [String: Any] = [:]
    public var launchParameters: [String: String] = [:]
    public init() {}
}

// MARK: - 批量加载结果
public struct UIModuleLoadBatchResult: Sendable {
    public let successCount: Int
    public let failureCount: Int
    public let failedModules: [(moduleID: String, error: String)]
    public let totalDuration: TimeInterval
    
    public init(successCount: Int, failureCount: Int, failedModules: [(moduleID: String, error: String)], totalDuration: TimeInterval) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.failedModules = failedModules
        self.totalDuration = totalDuration
    }
}

// MARK: - 模块日志条目
public struct UIModuleLogEntry: Sendable {
    public let timestamp: Date
    public let level: UILogLevel
    public let message: String
    public let moduleName: String
    public let source: String
    
    public init(timestamp: Date = Date(), level: UILogLevel, message: String, moduleName: String, source: String = "UIUnifiedRegistry") {
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.moduleName = moduleName
        self.source = source
    }
}

// MARK: - 通知类型
public enum UINotificationType: String, Sendable {
    case info, success, warning, error
}

// MARK: - 模块通知
public struct UIModuleNotification: Sendable {
    public let moduleName: String
    public let type: UINotificationType
    public let message: String
    public let data: [String: String]
    public let timestamp: Date
    
    public init(moduleName: String, type: UINotificationType, message: String, data: [String: String] = [:], timestamp: Date = Date()) {
        self.moduleName = moduleName
        self.type = type
        self.message = message
        self.data = data
        self.timestamp = timestamp
    }
}

// MARK: - 热插拔记录
public struct UIHotSwapRecord: Sendable {
    public let oldModuleName: String
    public let newModuleName: String
    public let success: Bool
    public let reason: String
    public let timestamp: Date
    
    public init(oldModuleName: String, newModuleName: String, success: Bool, reason: String, timestamp: Date = Date()) {
        self.oldModuleName = oldModuleName
        self.newModuleName = newModuleName
        self.success = success
        self.reason = reason
        self.timestamp = timestamp
    }
}

// MARK: - 模块扫描结果（所有UI文件共享）
public struct UIModuleDiscoveryResult: Sendable {
    public let moduleID: String
    public let bundleURL: URL
    public let metadata: UIModuleMetadata
    
    public init(moduleID: String, bundleURL: URL, metadata: UIModuleMetadata) {
        self.moduleID = moduleID
        self.bundleURL = bundleURL
        self.metadata = metadata
    }
}

// MARK: - 模块协议
public protocol UIModuleProtocol: AnyObject {
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

// MARK: - 扫描结果负载
public struct UIModuleScanPayload: Sendable {
    public let results: [UIModuleDiscoveryResult]
    public let count: Int
    public let directoryPath: String
    
    public init(results: [UIModuleDiscoveryResult], count: Int, directoryPath: String) {
        self.results = results
        self.count = count
        self.directoryPath = directoryPath
    }
}

public struct UIModuleBlacklistPayload: Sendable {
    public let moduleID: String
    public let isBlacklisted: Bool
    
    public init(moduleID: String, isBlacklisted: Bool) {
        self.moduleID = moduleID
        self.isBlacklisted = isBlacklisted
    }
}

// MARK: - 模块加载错误（所有UI文件共享）
public enum UIModuleLoadError: Error, Sendable {
    case startupTimeout(moduleID: String)
    case bundleNotFound(moduleID: String)
    case moduleNotFound(moduleID: String)
    case bundleLoadFailed(moduleID: String)
    case classNotFound(moduleID: String)
    case instantiationFailed(moduleID: String, reason: String)
    case startFailed(moduleID: String, reason: String)
    case dependencyMissing(moduleID: String, dependency: String)
    case invalidPrincipalClass(moduleID: String)
    case startupFailed(moduleID: String, reason: String)
    case loadFailed(moduleID: String, reason: String)
    
    public var localizedDescription: String {
        switch self {
        case .startupTimeout(let id): return "模块 \(id) 启动超时"
        case .bundleNotFound(let id): return "模块 \(id) bundle未找到"
        case .moduleNotFound(let id): return "模块 \(id) 在注册表中未找到"
        case .bundleLoadFailed(let id): return "模块 \(id) bundle加载失败"
        case .classNotFound(let id): return "模块 \(id) 类未找到"
        case .instantiationFailed(let id, let reason): return "模块 \(id) 实例化失败: \(reason)"
        case .startFailed(let id, let reason): return "模块 \(id) 启动失败: \(reason)"
        case .dependencyMissing(let id, let dep): return "模块 \(id) 依赖缺失: \(dep)"
        case .invalidPrincipalClass(let id): return "模块 \(id) 主类无效"
        case .startupFailed(let id, let reason): return "模块 \(id) 启动失败: \(reason)"
        case .loadFailed(let id, let reason): return "模块 \(id) 加载失败: \(reason)"
        }
    }
}

// MARK: - 通用包装类
/// 通用值包装类，用于在集合类型中存储值类型或引用类型
public final class Box<T> {
    public let value: T
    public init(_ value: T) { self.value = value }
}

// MARK: - UI管理公共补充类型
public struct UIModuleStartResult: Sendable {
    public let successCount: Int
    public let failureCount: Int
    public let successfulModules: [String]
    public let failedModules: [(moduleID: String, error: String)]
    public let totalDuration: TimeInterval
    public init(successCount: Int, failureCount: Int, successfulModules: [String], failedModules: [(String, String)], totalDuration: TimeInterval) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.successfulModules = successfulModules
        self.failedModules = failedModules.map { (moduleID: $0.0, error: $0.1) }
        self.totalDuration = totalDuration
    }
}

public struct UIModuleStartFailedPayload: Sendable {
    public let moduleID: String
    public let error: String
    public let severity: Int
    public var asDictionary: [String: Any] { ["moduleID": moduleID, "error": error, "severity": severity] }
    public init(moduleID: String, error: String, severity: Int) { self.moduleID = moduleID; self.error = error; self.severity = severity }
}

public struct UIModuleStartSuccessPayload: Sendable {
    public let moduleID: String
    public var asDictionary: [String: Any] { ["moduleID": moduleID] }
    public init(moduleID: String) { self.moduleID = moduleID }
}

public enum UIModuleErrorSeverity: Int, Codable, Sendable {
    case skip = 1
    case degrade = 2
    case fatal = 3
}

public struct UIModuleFailureRecord: Codable, Sendable {
    public let moduleID: String
    public let moduleName: String
    public let error: String
    public let severity: UIModuleErrorSeverity
    public let timestamp: Date
    public var retryCount: Int
    public init(moduleID: String, moduleName: String, error: String, severity: UIModuleErrorSeverity, timestamp: Date, retryCount: Int) {
        self.moduleID = moduleID; self.moduleName = moduleName; self.error = error; self.severity = severity; self.timestamp = timestamp; self.retryCount = retryCount
    }
}

public struct UIModuleLoadFailedPayload: Sendable {
    public let moduleID: String
    public let moduleName: String
    public let error: String
    public let severity: Int
    public var asDictionary: [String: Any] { ["moduleID": moduleID, "moduleName": moduleName, "error": error, "severity": severity] }
    public init(moduleID: String, moduleName: String, error: String, severity: Int) { self.moduleID = moduleID; self.moduleName = moduleName; self.error = error; self.severity = severity }
}

public struct UIModuleErrorAggregatedPayload: Sendable {
    public let errorCount: Int
    public let modules: [String]
    public let firstTimestamp: Date
    public let lastTimestamp: Date
    public let summary: String
    public var asDictionary: [String: Any] { ["errorCount": errorCount, "modules": modules, "firstTimestamp": firstTimestamp, "lastTimestamp": lastTimestamp, "summary": summary] }
    public init(errorCount: Int, modules: [String], firstTimestamp: Date, lastTimestamp: Date, summary: String) { self.errorCount = errorCount; self.modules = modules; self.firstTimestamp = firstTimestamp; self.lastTimestamp = lastTimestamp; self.summary = summary }
}

public enum UIModuleUnloadResult: Sendable {
    case success
    case failed(reason: String)
    case rollback
    case moduleNotFound
    case failure(Error)
    case notFound
    case hasDependencies([String])
}

public struct UIModuleUnloadPayload: Sendable {
    public let moduleID: String
    public let moduleName: String
    public let timestamp: Date
    public init(moduleID: String, moduleName: String, timestamp: Date) { self.moduleID = moduleID; self.moduleName = moduleName; self.timestamp = timestamp }
}

public struct UIModuleRollbackPayload: Sendable {
    public let moduleID: String
    public let moduleName: String
    public let timestamp: Date
    public init(moduleID: String, moduleName: String, timestamp: Date) { self.moduleID = moduleID; self.moduleName = moduleName; self.timestamp = timestamp }
}

public enum UIModuleLoadStrategy: Sendable {
    case eager
    case lazy
    case deferred(priority: Int)
}

public struct UIModuleLoadRecord: Sendable {
    public let moduleID: String
    public let moduleName: String
    public let path: String
    public let startedAt: Date
    public let duration: TimeInterval
    public let result: UIModuleLoadResult
    public let strategy: UIModuleLoadStrategy
    public init(moduleID: String, moduleName: String, path: String, startedAt: Date, duration: TimeInterval, result: UIModuleLoadResult, strategy: UIModuleLoadStrategy) {
        self.moduleID = moduleID; self.moduleName = moduleName; self.path = path; self.startedAt = startedAt; self.duration = duration; self.result = result; self.strategy = strategy
    }
}

public struct UIModuleLoadQueueItem: Sendable {
    public let moduleID: String
    public let moduleName: String
    public let path: String
    public let priority: Int
    public let createdAt: Date
    public var isCanceled: Bool
    public init(moduleID: String, moduleName: String, path: String, priority: Int, createdAt: Date, isCanceled: Bool) {
        self.moduleID = moduleID; self.moduleName = moduleName; self.path = path; self.priority = priority; self.createdAt = createdAt; self.isCanceled = isCanceled
    }
}

public struct UIModuleLoadedPayload: Sendable {
    public let moduleID: String
    public let moduleName: String
    public let loadDuration: TimeInterval
    public let strategy: UIModuleLoadStrategy
    public init(moduleID: String, moduleName: String, loadDuration: TimeInterval, strategy: UIModuleLoadStrategy) { self.moduleID = moduleID; self.moduleName = moduleName; self.loadDuration = loadDuration; self.strategy = strategy }
}

public enum UIModuleHotReplaceState: String, Sendable {
    case idle
    case validating
    case savingState
    case unloading
    case loading
    case restoringState
    case rollingBack
    case completed
    case failed
}

public enum UIModuleStateValidation: Sendable {
    case valid
    case warning(message: String)
    case invalid(reason: String)
}

public protocol UIModuleStatePreservable: AnyObject {
    func saveState() -> [String: Any]
    func restoreState(_ state: [String: Any])
}

public enum UIModuleHotReplaceResult: Sendable {
    case success(state: UIModuleHotReplaceState)
    case failed(reason: String, state: UIModuleHotReplaceState)
    case rolledBack(reason: String, state: UIModuleHotReplaceState)
}

public struct UIModuleHotReplacedPayload: Sendable {
    public let moduleID: String
    public let moduleName: String
    public let duration: TimeInterval
    public var asDictionary: [String: Any] { ["moduleID": moduleID, "moduleName": moduleName, "duration": duration] }
    public init(moduleID: String, moduleName: String, duration: TimeInterval) { self.moduleID = moduleID; self.moduleName = moduleName; self.duration = duration }
}

public struct UIModuleHotReplaceRecord: Sendable {
    public let moduleName: String
    public let newBundlePath: String
    public let startedAt: Date
    public let duration: TimeInterval
    public let result: UIModuleHotReplaceResult
    public var state: UIModuleHotReplaceState {
        switch result {
        case .success(let state): return state
        case .failed(_, let state): return state
        case .rolledBack(_, let state): return state
        }
    }
    public init(moduleName: String, newBundlePath: String, startedAt: Date, duration: TimeInterval, result: UIModuleHotReplaceResult) { self.moduleName = moduleName; self.newBundlePath = newBundlePath; self.startedAt = startedAt; self.duration = duration; self.result = result }
}

public enum UIModuleListStatus: String, Sendable {
    case normal
    case unloading
    case failed
}

public struct UIWorkspaceLayout: Codable, @unchecked Sendable {
    public var version: String
    public var timestamp: Date
    public var layoutName: String
    public var symbol: String
    public var period: String
    public var colorScheme: String
    public var windowStates: [String: UIPersistentWindowStateModel]
    public var moduleStates: [String: UIModuleStateModel]
    public var dockedPanels: [String: UIDockedPanelStateModel]
    public var openModuleNames: [String]
    public var globalSettings: [String: String]

    public init(layoutName: String = "default", openModuleNames: [String] = []) {
        self.version = "2.0"
        self.timestamp = Date()
        self.layoutName = layoutName
        self.symbol = "BTC/USDT"
        self.period = "1D"
        self.colorScheme = "default"
        self.windowStates = [:]
        self.moduleStates = [:]
        self.dockedPanels = [:]
        self.openModuleNames = openModuleNames
        self.globalSettings = [:]
    }
}

public struct UILayoutTemplate: Codable, Sendable {
    public var name: String
    public var description: String
    public var tags: [String]
    public var isBuiltIn: Bool
    public var layout: UIWorkspaceLayout
    public var createdAt: Date
    public var updatedAt: Date
    public var desc: String { description }
    public init(name: String, description: String, tags: [String] = [], isBuiltIn: Bool = false, layout: UIWorkspaceLayout = UIWorkspaceLayout(), createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.name = name; self.description = description; self.tags = tags; self.isBuiltIn = isBuiltIn; self.layout = layout; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public struct UIThemeColors: Codable, Sendable {
    public var background, foreground, accent, panelBackground, secondaryBackground, border, disabled, success, warning, error: String
    public init(background: String, foreground: String, accent: String, panelBackground: String, secondaryBackground: String, border: String, disabled: String, success: String, warning: String, error: String) {
        self.background = background; self.foreground = foreground; self.accent = accent; self.panelBackground = panelBackground; self.secondaryBackground = secondaryBackground; self.border = border; self.disabled = disabled; self.success = success; self.warning = warning; self.error = error
    }
}

public struct UIThemeFonts: Codable, Sendable {
    public var baseSize: CGFloat
    public var titleFontName, bodyFontName, monoFontName: String
    public var titleMultiplier, subtitleMultiplier, bodyMultiplier, smallMultiplier: CGFloat
    public var titleFont: NSFont { NSFont.systemFont(ofSize: baseSize * titleMultiplier, weight: .semibold) }
    public var bodyFont: NSFont { NSFont.systemFont(ofSize: baseSize * bodyMultiplier) }
    public init(baseSize: CGFloat, titleFontName: String, bodyFontName: String, monoFontName: String, titleMultiplier: CGFloat, subtitleMultiplier: CGFloat, bodyMultiplier: CGFloat, smallMultiplier: CGFloat) {
        self.baseSize = baseSize; self.titleFontName = titleFontName; self.bodyFontName = bodyFontName; self.monoFontName = monoFontName; self.titleMultiplier = titleMultiplier; self.subtitleMultiplier = subtitleMultiplier; self.bodyMultiplier = bodyMultiplier; self.smallMultiplier = smallMultiplier
    }
}

public struct UIThemeSpacing: Codable, Sendable {
    public var small, medium, large, xlarge: CGFloat
    public var cornerRadiusSmall, cornerRadiusMedium, cornerRadiusLarge: CGFloat
    public var borderWidth: CGFloat
    public var shadowOpacity: CGFloat
    public var shadowOffset: CGSize
    public var shadowBlurRadius: CGFloat
    public init(small: CGFloat, medium: CGFloat, large: CGFloat, xlarge: CGFloat, cornerRadiusSmall: CGFloat, cornerRadiusMedium: CGFloat, cornerRadiusLarge: CGFloat, borderWidth: CGFloat, shadowOpacity: CGFloat, shadowOffset: CGSize, shadowBlurRadius: CGFloat) {
        self.small = small; self.medium = medium; self.large = large; self.xlarge = xlarge; self.cornerRadiusSmall = cornerRadiusSmall; self.cornerRadiusMedium = cornerRadiusMedium; self.cornerRadiusLarge = cornerRadiusLarge; self.borderWidth = borderWidth; self.shadowOpacity = shadowOpacity; self.shadowOffset = shadowOffset; self.shadowBlurRadius = shadowBlurRadius
    }
}

public struct UIThemeIconTint: Codable, Sendable {
    public var `default`, selected, disabled, highlighted: String
    public var useUniformTint: Bool
    public init(default: String, selected: String, disabled: String, highlighted: String, useUniformTint: Bool) { self.default = `default`; self.selected = selected; self.disabled = disabled; self.highlighted = highlighted; self.useUniformTint = useUniformTint }
}

public struct UIThemeDefinition: Codable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var isBuiltIn: Bool
    public var followSystemAppearance: Bool
    public var systemAppearance: String?
    public var colors: UIThemeColors
    public var fonts: UIThemeFonts
    public var spacing: UIThemeSpacing
    public var iconTint: UIThemeIconTint
    public var createdAt: Date
    public init(id: String, name: String, description: String, isBuiltIn: Bool, followSystemAppearance: Bool, systemAppearance: String?, colors: UIThemeColors, fonts: UIThemeFonts, spacing: UIThemeSpacing, iconTint: UIThemeIconTint, createdAt: Date = Date()) {
        self.id = id; self.name = name; self.description = description; self.isBuiltIn = isBuiltIn; self.followSystemAppearance = followSystemAppearance; self.systemAppearance = systemAppearance; self.colors = colors; self.fonts = fonts; self.spacing = spacing; self.iconTint = iconTint; self.createdAt = createdAt
    }
}

public enum UIThemeMode: String, Codable, Sendable, CaseIterable {
    case light
    case dark
    case system
    case highContrast

    public var appearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark, .highContrast: return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }
}

public struct UIThemePreviewData: Codable, Sendable {
    public var title: String
    public var body: String
    public var buttonText: String
    public var labelText: String
    public static let `default` = UIThemePreviewData(title: "主题预览", body: "这是主题正文预览", buttonText: "按钮", labelText: "辅助文字")
    public init(title: String, body: String, buttonText: String, labelText: String) { self.title = title; self.body = body; self.buttonText = buttonText; self.labelText = labelText }
}

public enum UIThemeColorUtilities {
    public static func color(fromHex hex: String) -> NSColor? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let intValue = Int(value, radix: 16) else { return nil }
        let r = CGFloat((intValue >> 16) & 0xff) / 255.0
        let g = CGFloat((intValue >> 8) & 0xff) / 255.0
        let b = CGFloat(intValue & 0xff) / 255.0
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
    }

    public static func hex(from color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return "" }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - 日志工具
public enum UILogger {
    public static func makeLogger(subsystem: String, category: String) -> os.Logger {
        return os.Logger(subsystem: subsystem, category: category)
    }

    public static func makeUILogger(category: String) -> os.Logger {
        return os.Logger(subsystem: "com.xianrenzhilu.ui", category: category)
    }
}


public struct UIWorkspaceScheme: Codable, Sendable {
    public var name: String
    public var description: String
    public var layout: UIWorkspaceLayout
    public var isBuiltIn: Bool
    public init(name: String, description: String, layout: UIWorkspaceLayout, isBuiltIn: Bool = false) { self.name = name; self.description = description; self.layout = layout; self.isBuiltIn = isBuiltIn }
}

// MARK: - 图表索引视口（迁自 UI-GL-71，2026-06-22）

/// 索引式图表的视口状态
public struct UIChartViewport: Equatable, Sendable {
    public var startIndex: Int
    public var endIndex: Int
    public var candleWidth: Double
    public var contentOffsetX: Double
    public var visibleCount: Int
    public var totalCount: Int
    
    public init(
        startIndex: Int = 0,
        endIndex: Int = 0,
        candleWidth: Double = 8.0,
        contentOffsetX: Double = 0.0,
        visibleCount: Int = 0,
        totalCount: Int = 0
    ) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.candleWidth = candleWidth
        self.contentOffsetX = contentOffsetX
        self.visibleCount = visibleCount
        self.totalCount = totalCount
    }
    
    public var isAtTail: Bool { endIndex >= max(0, totalCount - 2) || endIndex == 0 }
    public var isAtHead: Bool { startIndex <= 0 }
    public var count: Int { max(0, endIndex - startIndex) }
}

/// 视口计算器配置
public struct UIChartViewportConfiguration: Equatable, Sendable {
    public var leftMarginCandles: Int = 20
    public var allowRightBlank: Bool = true
    public var minCandleWidth: Double = 1.5
    public var maxCandleWidth: Double = 60.0
    public var minVisibleCandles: Int = 5
    public var debounceInterval: TimeInterval = 0.15
    public var followTail: Bool = true
    public var enableInertia: Bool = true
    public var inertiaDeceleration: Double = 0.90
    public var inertiaMinVelocity: Double = 0.5
    public var enableZoomAnimation: Bool = true
    public var zoomAnimationDuration: TimeInterval = 0.15
    public var enableBounce: Bool = false
    public var bounceDistance: Double = 20.0
    public var bounceDuration: TimeInterval = 0.3
    public var preloadBuffer: Int = 3
    public var enableDensityAdaptation: Bool = true
    public var enableSmoothScroll: Bool = true
    public var smoothScrollSteps: Int = 5
    public var enableViewportLock: Bool = false
    public var enableEmptyPlaceholder: Bool = true
    public var enableHighlight: Bool = true
    public var enableViewportAnimation: Bool = true
    public var viewportAnimationDuration: TimeInterval = 0.2
    public var enableEdgeLoadingIndicator: Bool = true
    public var zoomAnchorMode: Double? = 0.5
    public var snapToIntegerIndex: Bool = true
    public var paginationTriggerThreshold: Int = 10
    public var enablePagination: Bool = true
    public var enableZoomStepping: Bool = false
    public var zoomSteps: [Double] = [1.0, 2.0, 4.0, 8.0, 16.0]
    public var enableZoomMemory: Bool = false
    public var enableDirectionLock: Bool = false
    public var enablePerformanceStats: Bool = false
    public var enableScrollBar: Bool = false
    public var enableRuler: Bool = false
    public var enableGridSnap: Bool = false
    public var enableScaleAdaptation: Bool = false
    public var enableFocusFollow: Bool = false
    public var enableViewportComparison: Bool = false
    public var enableBookmark: Bool = false
    public var enableThumbnailNavigation: Bool = false
    public var enableDoubleTapReset: Bool = false
    public var enablePinchZoom: Bool = false
    public var enableBoxSelection: Bool = false
    public var enableZoomToSelection: Bool = false
    public var enableDataClipping: Bool = false
    public var enableCrossZoom: Bool = false
    public var enableLongPressPrecision: Bool = true
    public var longPressDuration: TimeInterval = 0.5
    
    public init() {}
}

/// 性能统计数据
public struct UIChartViewportPerformanceStats: Sendable {
    public var totalPanEvents: Int = 0
    public var totalZoomEvents: Int = 0
    public var averagePanLatency: Double = 0
    public var averageZoomLatency: Double = 0
    public var droppedFrames: Int = 0
    public var lastUpdateTime: Date?
}

/// 视口快照
public struct UIChartViewportSnapshot: Codable, Sendable {
    public let startIndex: Int
    public let endIndex: Int
    public let candleWidth: Double
    public let contentOffsetX: Double
    public let timestamp: Date
    public let label: String?
    
    public init(viewport: UIChartViewport, label: String? = nil) {
        self.startIndex = viewport.startIndex
        self.endIndex = viewport.endIndex
        self.candleWidth = viewport.candleWidth
        self.contentOffsetX = viewport.contentOffsetX
        self.timestamp = Date()
        self.label = label
    }
}

/// 图表索引视口计算器通知名称
public extension Notification.Name {
    static let chartViewportDidChange = Notification.Name("com.xianrenzhilu.ui.chartViewportDidChange")
    static let chartPaginationTriggered = Notification.Name("com.xianrenzhilu.ui.chartPaginationTriggered")
    static let chartViewportAnimationCompleted = Notification.Name("com.xianrenzhilu.ui.chartViewportAnimationCompleted")
    static let chartInertiaDidEnd = Notification.Name("com.xianrenzhilu.ui.chartInertiaDidEnd")
}
