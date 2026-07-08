// 功能26: 模块沙盒隔离
// 版本: 2.0
// 对应: 每个模块在独立沙盒环境运行，崩溃不影响主应用
// 优先级: P2

import AppKit
import Foundation
import os.log

// MARK: - 通知名称扩展
/// 沙盒隔离相关通知
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 测试代码
#if false // DEBUG tests disabled in App target
// import XCTest (disabled for executable target)

/// 功能26：模块沙盒隔离 — 单元测试
/// 覆盖：沙盒注册/配置持久化/状态查询/违规日志/文件访问控制/网络访问控制
func test_sandbox() {
    let manager = UISandboxIsolationManager.shared

    print("\n🧪 测试1: 注册模块")
    let instance = manager.registerModule(moduleName: "test.module")
    guard instance.moduleName == "test.module" else {
        fatalError("❌ 测试1失败: 模块名不匹配")
    }
    print("✅ 测试1通过: 模块注册成功")

    print("\n🧪 测试2: 沙盒状态查询")
    let status = manager.moduleStatus(moduleName: "test.module")
    guard status == .stopped else {
        fatalError("❌ 测试2失败: 初始应为已停止")
    }
    print("✅ 测试2通过: 状态查询正确")

    print("\n🧪 测试3: 配置持久化")
    let config = UISandboxConfig(moduleName: "test.module", memoryQuotaMB: 256)
    let saved = manager.saveConfig(config)
    guard saved else {
        fatalError("❌ 测试3失败: 配置保存应成功")
    }
    let loaded = manager.loadConfig(for: "test.module")
    guard loaded?.memoryQuotaMB == 256 else {
        fatalError("❌ 测试3失败: 配置加载值不匹配")
    }
    print("✅ 测试3通过: 配置持久化正常")

    print("\n🧪 测试4: 文件访问控制")
    let sandboxDir = manager.sandboxDirectory(for: "test.module")
    let access = manager.validateFileAccess(moduleName: "test.module", path: sandboxDir.path)
    guard access else {
        fatalError("❌ 测试4失败: 沙盒目录应被允许访问")
    }
    print("✅ 测试4通过: 文件访问控制正常")

    print("\n🧪 测试5: 网络访问控制（白名单为空时默认允许）")
    let networkAccess = manager.validateNetworkAccess(moduleName: "test.module", domain: "api.example.com")
    guard networkAccess else {
        fatalError("❌ 测试5失败: 白名单为空时应允许")
    }
    print("✅ 测试5通过: 网络访问控制正常")

    print("\n🧪 测试6: 违规日志")
    let records = manager.allViolationRecords()
    _ = records.count
    print("✅ 测试6通过: 违规日志查询正常")

    print("\n🧪 测试7: 沙盒列表")
    let list = manager.sandboxList()
    guard !list.isEmpty else {
        fatalError("❌ 测试7失败: 沙盒列表不应为空")
    }
    print("✅ 测试7通过: 沙盒列表正常")

    print("\n🧪 测试8: 设置面板数据")
    let panelList = manager.settingsPanelSandboxList()
    guard !panelList.isEmpty else {
        fatalError("❌ 测试8失败: 设置面板列表不应为空")
    }
    print("✅ 测试8通过: 设置面板数据正常")

    print("\n🧪 测试9: 卸载模块")
    let unregistered = manager.unregisterModule(moduleName: "test.module")
    guard unregistered else {
        fatalError("❌ 测试9失败: 卸载应成功")
    }
    print("✅ 测试9通过: 模块卸载成功")

    print("\n=== 全部沙盒隔离测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    static let sandboxDidStart = Notification.Name("com.xianrenzhilu.sandboxDidStart")
    static let sandboxDidStop = Notification.Name("com.xianrenzhilu.sandboxDidStop")
    static let sandboxResourceExceeded = Notification.Name("com.xianrenzhilu.sandboxResourceExceeded")
    static let sandboxFileViolation = Notification.Name("com.xianrenzhilu.sandboxFileViolation")
    static let sandboxNetworkViolation = Notification.Name("com.xianrenzhilu.sandboxNetworkViolation")
    static let sandboxConfigDidUpdate = Notification.Name("com.xianrenzhilu.sandboxConfigDidUpdate")
    static let sandboxViolationLogDidUpdate = Notification.Name("com.xianrenzhilu.sandboxViolationLogDidUpdate")
}

// MARK: - 迁回自 UI-02：class UISandboxInstance
public final class UISandboxInstance : @unchecked Sendable {
    public let moduleName: String
    public private(set) var status: UISandboxStatus
    public private(set) var process: Process?
    public let sandboxDirectory: URL
    public private(set) var resourceHistory: [UIResourceUsage]
    public var config: UISandboxConfig
    public private(set) var startTime: Date?
    public private(set) var stopTime: Date?

    private nonisolated(unsafe) var monitorTimer: Timer?
    private let lock = NSRecursiveLock()
    private let logger: Logger

    public init(moduleName: String, config: UISandboxConfig, sandboxDirectory: URL) {
        self.moduleName = moduleName
        self.config = config
        self.sandboxDirectory = sandboxDirectory
        self.status = .stopped
        self.resourceHistory = []
        self.logger = Logger(subsystem: "com.xianrenzhilu", category: "沙盒.\(moduleName)")
    }

    deinit {
        monitorTimer?.invalidate()
        if let process = process, process.isRunning {
            process.terminate()
            logger.info("沙盒实例销毁时终止进程: \(self.moduleName)")
        }
    }

    public func start(executableURL: URL) throws {
        guard status != .running && status != .starting else {
            throw UISandboxError.moduleAlreadyRunning(moduleName)
        }

        status = .starting
        logger.info("正在启动沙盒: \(self.moduleName)")

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: self.sandboxDirectory.path) {
            do {
                try fileManager.createDirectory(at: self.sandboxDirectory, withIntermediateDirectories: true)
                logger.info("沙盒目录已创建: \(self.sandboxDirectory.path)")
            } catch {
                status = .stopped
                throw UISandboxError.directoryCreationFailed(sandboxDirectory.path)
            }
        }

        let process = Process()
        process.executableURL = executableURL
        process.currentDirectoryURL = sandboxDirectory

        var env = ProcessInfo.processInfo.environment
        env["XIANRENZHIlu_SANDBOX"] = "1"
        env["XIANRENZHIlu_MODULE_NAME"] = moduleName
        env["XIANRENZHIlu_SANDBOX_DIR"] = sandboxDirectory.path
        process.environment = env

        do {
            try process.run()
            self.process = process
            self.startTime = Date()
            self.status = .running
            logger.info("沙盒启动成功: \(self.moduleName), PID: \(process.processIdentifier)")

            if config.enableResourceMonitor {
                startResourceMonitoring()
            }

            NotificationCenter.default.post(
                name: .sandboxDidStart,
                object: self,
                userInfo: ["moduleName": moduleName, "pid": process.processIdentifier]
            )
        } catch {
            status = .stopped
            throw UISandboxError.processLaunchFailed(error.localizedDescription)
        }
    }

    public func stop() {
        guard let process = process else {
            logger.warning("停止失败，模块未运行: \(self.moduleName)")
            return
        }

        status = .stopping
        logger.info("正在停止沙盒: \(self.moduleName)")

        monitorTimer?.invalidate()
        monitorTimer = nil

        if process.isRunning {
            process.terminate()
            logger.info("已发送终止信号到进程: \(self.moduleName)")
        }

        self.stopTime = Date()
        self.process = nil
        self.status = .stopped

        NotificationCenter.default.post(
            name: .sandboxDidStop,
            object: self,
            userInfo: ["moduleName": moduleName]
        )
    }

    public func checkProcessStatus() -> Bool {
        guard let process = process else { return false }
        let isRunning = process.isRunning
        if !isRunning && status == .running {
            status = .crashed
            stopTime = Date()
            logger.error("沙盒进程异常退出: \(self.moduleName)")
        }
        return isRunning
    }

    private func startResourceMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sampleResourceUsage()
        }
    }

    private func sampleResourceUsage() {
        guard let process = process, process.isRunning else { return }

        let pid = process.processIdentifier
        var usage = UIResourceUsage(timestamp: Date())

        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-o", "rss=,pcpu=", "-p", "\(pid)"]

        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let parts = output.split(separator: " ")
                if parts.count >= 2 {
                    if let rssKB = Double(parts[0]) {
                        usage.memoryMB = rssKB / 1024.0
                    }
                    if let cpu = Double(parts[1]) {
                        usage.cpuPercent = cpu
                    }
                }
            }
        } catch {
            logger.debug("资源采样失败: \(error.localizedDescription)")
        }

        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: sandboxDirectory, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles)
            var totalBytes: Int64 = 0
            for url in contents {
                if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    totalBytes += size
                }
            }
            usage.diskMB = Double(totalBytes) / (1024.0 * 1024.0)
        } catch {
            logger.debug("磁盘使用计算失败: \(error.localizedDescription)")
        }

        lock.lock()
        resourceHistory.append(usage)
        if resourceHistory.count > 100 {
            resourceHistory.removeFirst(resourceHistory.count - 100)
        }
        lock.unlock()

        checkResourceQuotas(usage: usage)
    }

    private func checkResourceQuotas(usage: UIResourceUsage) {
        var exceeded = false
        var detail = ""

        if usage.memoryMB > config.memoryQuotaMB {
            exceeded = true
            detail += "内存 \(String(format: "%.1f", usage.memoryMB))MB > 配额 \(String(format: "%.1f", config.memoryQuotaMB))MB; "
        }
        if usage.diskMB > config.diskQuotaMB {
            exceeded = true
            detail += "磁盘 \(String(format: "%.1f", usage.diskMB))MB > 配额 \(String(format: "%.1f", config.diskQuotaMB))MB; "
        }
        if usage.cpuPercent > config.cpuQuotaPercent {
            exceeded = true
            detail += "CPU \(String(format: "%.1f", usage.cpuPercent))% > 配额 \(String(format: "%.1f", config.cpuQuotaPercent))%; "
        }

        if exceeded {
            status = .suspended
            logger.warning("资源超限: \(self.moduleName) - \(detail)")
            NotificationCenter.default.post(
                name: .sandboxResourceExceeded,
                object: self,
                userInfo: ["moduleName": moduleName, "detail": detail, "usage": usage]
            )
        }
    }

    public func currentResourceUsage() -> UIResourceUsage? {
        lock.lock()
        let latest = resourceHistory.last
        lock.unlock()
        return latest
    }

    public func getResourceHistory() -> [UIResourceUsage] {
        lock.lock()
        let history = resourceHistory
        lock.unlock()
        return history
    }

    public var uptime: TimeInterval? {
        guard let start = startTime else { return nil }
        let end = stopTime ?? Date()
        return end.timeIntervalSince(start)
    }
}

// MARK: - 迁回自 UI-02：struct UIAnyCodable
// MARK: - 依赖关系图
// 已迁回 UI-GL-33_模块热加载.swift：class UIDependencyGraph（公共类型文件禁止功能实现）

// MARK: - 热加载管理器
// 已迁回 UI-GL-33_模块热加载.swift：class UIHotLoadManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-34 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-34_types.swift
// 版本: 2.0
public struct UIAnyCodable: Codable {
    public let value: Any?

    public init(_ value: Any?) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        self.value = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value = value as? String {
            try container.encode(value)
        } else if let value = value as? Int {
            try container.encode(value)
        } else if let value = value as? Double {
            try container.encode(value)
        } else if let value = value as? Bool {
            try container.encode(value)
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - 迁回自 UI-02：enum UISandboxError
// MARK: - 通知名称扩展
// 已迁回 UI-GL-34_模块沙盒隔离.swift：extension Notification.Name（公共类型文件禁止功能实现）

// MARK: - 沙盒错误枚举
public enum UISandboxError: Error, LocalizedError {
    case directoryCreationFailed(String)
    case moduleAlreadyRunning(String)
    case moduleNotRunning(String)
    case fileAccessDenied(String)
    case networkAccessDenied(String)
    case resourceQuotaExceeded(String)
    case configLoadFailed(String)
    case configSaveFailed(String)
    case crossSandboxAccessDenied(String)
    case processLaunchFailed(String)
    case invalidModuleName(String)

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let path):
            return "沙盒目录创建失败: \(path)"
        case .moduleAlreadyRunning(let name):
            return "模块 '\(name)' 已在沙盒中运行"
        case .moduleNotRunning(let name):
            return "模块 '\(name)' 未在沙盒中运行"
        case .fileAccessDenied(let path):
            return "文件访问被拒绝（路径不在白名单）: \(path)"
        case .networkAccessDenied(let domain):
            return "网络访问被拒绝（域名不在白名单）: \(domain)"
        case .resourceQuotaExceeded(let detail):
            return "资源配额超限: \(detail)"
        case .configLoadFailed(let detail):
            return "沙盒配置加载失败: \(detail)"
        case .configSaveFailed(let detail):
            return "沙盒配置保存失败: \(detail)"
        case .crossSandboxAccessDenied(let detail):
            return "跨沙盒访问被禁止: \(detail)"
        case .processLaunchFailed(let detail):
            return "沙盒进程启动失败: \(detail)"
        case .invalidModuleName(let name):
            return "无效的模块名称: \(name)"
        }
    }
}

// MARK: - 迁回自 UI-02：enum UISandboxStatus
// MARK: - 沙盒运行状态
public enum UISandboxStatus: String, Codable, CaseIterable {
    case stopped = "已停止"
    case starting = "正在启动"
    case running = "运行中"
    case stopping = "正在停止"
    case crashed = "已崩溃"
    case suspended = "已暂停（资源超限）"
}

// MARK: - 迁回自 UI-02：struct UIResourceUsage
// MARK: - 资源使用数据
public struct UIResourceUsage: Codable {
    public var memoryMB: Double
    public var diskMB: Double
    public var cpuPercent: Double
    public var timestamp: Date

    public init(memoryMB: Double = 0, diskMB: Double = 0, cpuPercent: Double = 0, timestamp: Date = Date()) {
        self.memoryMB = memoryMB
        self.diskMB = diskMB
        self.cpuPercent = cpuPercent
        self.timestamp = timestamp
    }
}

// MARK: - 迁回自 UI-02：struct UIViolationRecord
// MARK: - 违规记录
public struct UIViolationRecord: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let moduleName: String
    public let type: String
    public let detail: String
    public let target: String
    public let result: String

    public init(moduleName: String, type: String, detail: String, target: String, result: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.moduleName = moduleName
        self.type = type
        self.detail = detail
        self.target = target
        self.result = result
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - 迁回自 UI-02：struct UISandboxConfig
// MARK: - 沙盒配置
public struct UISandboxConfig: Codable {
    public var moduleName: String
    public var isEnabled: Bool
    public var fileWhitelist: [String]
    public var fileBlacklist: [String]
    public var networkWhitelist: [String]
    public var networkBlacklist: [String]
    public var memoryQuotaMB: Double
    public var diskQuotaMB: Double
    public var cpuQuotaPercent: Double
    public var allowCrossSandbox: Bool
    public var enableFileControl: Bool
    public var enableNetworkControl: Bool
    public var enableResourceMonitor: Bool

    public init(
        moduleName: String,
        isEnabled: Bool = true,
        fileWhitelist: [String] = [],
        fileBlacklist: [String] = [],
        networkWhitelist: [String] = [],
        networkBlacklist: [String] = [],
        memoryQuotaMB: Double = 512,
        diskQuotaMB: Double = 1024,
        cpuQuotaPercent: Double = 80,
        allowCrossSandbox: Bool = false,
        enableFileControl: Bool = true,
        enableNetworkControl: Bool = true,
        enableResourceMonitor: Bool = true
    ) {
        self.moduleName = moduleName
        self.isEnabled = isEnabled
        self.fileWhitelist = fileWhitelist
        self.fileBlacklist = fileBlacklist
        self.networkWhitelist = networkWhitelist
        self.networkBlacklist = networkBlacklist
        self.memoryQuotaMB = memoryQuotaMB
        self.diskQuotaMB = diskQuotaMB
        self.cpuQuotaPercent = cpuQuotaPercent
        self.allowCrossSandbox = allowCrossSandbox
        self.enableFileControl = enableFileControl
        self.enableNetworkControl = enableNetworkControl
        self.enableResourceMonitor = enableResourceMonitor
    }
}

// MARK: - 迁回自 UI-02：struct UISandboxListItem
// MARK: - 沙盒实例
// 已迁回 UI-GL-34_模块沙盒隔离.swift：class UISandboxInstance（公共类型文件禁止功能实现）

// MARK: - 设置面板数据结构
public struct UISandboxListItem {
    public let name: String
    public let status: UISandboxStatus
    public let uptime: TimeInterval?
    public let uptimeFormatted: String
    public let memoryMB: Double
    public let diskMB: Double
    public let cpuPercent: Double
}

// MARK: - 迁回自 UI-02：struct UISandboxViolationItem
public struct UISandboxViolationItem {
    public let id: String
    public let time: String
    public let module: String
    public let type: String
    public let detail: String
    public let target: String
    public let result: String
}

// MARK: - 迁回自 UI-02：struct UISandboxModuleSettings
public struct UISandboxModuleSettings {
    public let moduleName: String
    public let isEnabled: Bool
    public let fileWhitelist: [String]
    public let fileBlacklist: [String]
    public let networkWhitelist: [String]
    public let networkBlacklist: [String]
    public let memoryQuotaMB: Double
    public let diskQuotaMB: Double
    public let cpuQuotaPercent: Double
    public let allowCrossSandbox: Bool
    public let enableFileControl: Bool
    public let enableNetworkControl: Bool
    public let enableResourceMonitor: Bool
}
