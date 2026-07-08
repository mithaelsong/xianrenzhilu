// MARK: - UI-13: UI模块加载日志
// 功能编号: UI-13
// 版本: 2.0
// 职责: 记录UI模块加载全流程日志，支持分级、查询、导出、清理、文件持久化、轮转
// 依赖: UI-02（使用UILoadingLogManager、UILogLevel和UIModuleLogEntry）

import Foundation
import OSLog

// 使用UI-02的UILoadingLogManager，本文件不再定义


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UILoadingLogManager
public final class UILoadingLogManager: @unchecked Sendable {
    public static let shared = UILoadingLogManager()
    private init() {}
    
    let lock = NSRecursiveLock()
    private var entries: [UIModuleLogEntry] = []
    private var currentLevel: UILogLevel = .info
    private let maxEntries: Int = 10000
    
    public func log(level: UILogLevel, category: String, message: String, moduleID: String? = nil) {
        guard level.rawValue >= currentLevel.rawValue else { return }
        let entry = UIModuleLogEntry(timestamp: Date(), level: level, message: message, moduleName: moduleID ?? "", source: category)
        lock.lock()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()

        // 同时写入文件
        let logLine = "[\(Date())] [\(level)] [\(category)] \(message)\n"
        let logPath = "/Users/songxiaoxiao/Desktop/ui_log.txt"
        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? logLine.write(toFile: logPath, atomically: true, encoding: .utf8)
            }
        }
    }
    
    public func info(_ category: String, _ message: String, moduleID: String? = nil) {
        log(level: .info, category: category, message: message, moduleID: moduleID)
    }
    
    public func warning(_ category: String, _ message: String, moduleID: String? = nil) {
        log(level: .warning, category: category, message: message, moduleID: moduleID)
    }
    
    public func error(_ category: String, _ message: String, moduleID: String? = nil) {
        log(level: .error, category: category, message: message, moduleID: moduleID)
    }
    
    public func debug(_ category: String, _ message: String, moduleID: String? = nil) {
        log(level: .debug, category: category, message: message, moduleID: moduleID)
    }
    
    public func info(_ message: String) { info("UI", message) }
    public func warning(_ message: String) { warning("UI", message) }
    public func error(_ message: String) { error("UI", message) }
    public func debug(_ message: String) { debug("UI", message) }

    /// 导出所有日志到文件
    public func exportToFile(path: String) {
        let content = entries.map { "[\($0.timestamp)] [\($0.level)] [\($0.source)] \($0.message)" }.joined(separator: "\n")
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    public func allEntries() -> [UIModuleLogEntry] {
        lock.lock()
        let copy = entries
        lock.unlock()
        return copy
    }
    
    public func setLogLevel(_ level: UILogLevel) {
        lock.lock()
        currentLevel = level
        lock.unlock()
    }
}
// MARK: - 从 UI-02 正确迁回：let logger
private let logger = UILoadingLogManager.shared
