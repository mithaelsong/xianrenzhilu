// KJ-GL-03_初始化日志系统.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import AppKit
import os

// MARK: - KJModuleLogger
// MARK: - 模块日志器
public final class KJModuleLogger: @unchecked Sendable {
    public static let shared = KJModuleLogger()
    private init() {}
    
    private let lock = NSRecursiveLock()
    private var entries: [KJLogEntry] = []
    private var currentLevel: KJLogLevel = .info
    private let maxEntries: Int = 10000
    
    public func log(level: KJLogLevel, category: String, message: String, moduleID: String? = nil) {
        guard level.rawValue >= currentLevel.rawValue else { return }
        let entry = KJLogEntry(timestamp: Date(), level: level, message: message, moduleName: moduleID ?? "", source: category)
        lock.lock()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()
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
    
    public func allEntries() -> [KJLogEntry] {
        lock.lock()
        let copy = entries
        lock.unlock()
        return copy
    }
    
    public func setLogLevel(_ level: KJLogLevel) {
        lock.lock()
        currentLevel = level
        lock.unlock()
    }
}

// MARK: - KJLogSystem
// MARK: - 日志系统
public final class KJLogSystem: @unchecked Sendable {
    public static let shared = KJLogSystem()
    private init() {}
    
    public func initialize() {}
    public func flush() {}
    public var logDirectory: String { return "/tmp/logs" }
}

// MARK: - KJConsoleLogOutput
// MARK: - 迁移自 KJ-GL-03_初始化日志系统.swift
// MARK: - LogLevel
/// 日志级别，支持5个级别：debug < info < warning < error < fatal

// MARK: - LogEntry
/// 日志条目数据结构

// MARK: - KJConsoleLogOutput
/// 控制台日志输出（带格式化）
public final class KJConsoleLogOutput: KJLogOutput , @unchecked Sendable{
    private let dateFormatter: DateFormatter
    
    public init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    public func write(_ entry: KJLogEntry) {
        let time = dateFormatter.string(from: entry.timestamp)
        print("[\(time)] \(entry.level.emoji) [\(entry.level)] [\(entry.source)] \(entry.message)")
    }
    
    public func flush() {}
}

// MARK: - KJFileLogOutput
// MARK: - 迁移自 KJ-GL-03_初始化日志系统.swift
// MARK: - KJFileLogOutput
/// 文件日志输出（按天轮转，7天自动清理）
/// 全部使用 os_unfair_lock，与 LogSystem 保持一致
public final class KJFileLogOutput: KJLogOutput , @unchecked Sendable{
    private let logDirectory: URL
    private let maxAgeDays = 7
    private var currentFile: URL?
    private var fileHandle: FileHandle?
    private var unfairLock = os_unfair_lock()
    private let dateFormatter: DateFormatter
    private let fileNameFormatter: DateFormatter
    private var lastCleanupDate: Date? = nil
    
    public init(directory: URL) {
        self.logDirectory = directory
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.fileNameFormatter = DateFormatter()
        self.fileNameFormatter.dateFormat = "yyyy-MM-dd"
        
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    deinit {
        // fileHandle.closeFile() 是幂等的，不拿锁避免阻塞
        if let handle = fileHandle {
            handle.closeFile()
        }
    }
    
    public func write(_ entry: KJLogEntry) {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        rotateIfNeededLocked()
        
        let time = dateFormatter.string(from: entry.timestamp)
        let line = "[\(time)] \(entry.level.emoji) [\(entry.level)] [\(entry.source)] \(entry.message)\n"
        
        if let data = line.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }
    
    public func flush() {
        os_unfair_lock_lock(&unfairLock)
        defer { os_unfair_lock_unlock(&unfairLock) }
        fileHandle?.synchronizeFile()
    }
    
    /// 仅在持有锁时调用
    private func rotateIfNeededLocked() {
        let today = Calendar.current.startOfDay(for: Date())
        let expectedFile = logDirectory.appendingPathComponent("log_\(fileNameFormatter.string(from: today)).txt")
        
        if currentFile != expectedFile {
            fileHandle?.closeFile()
            currentFile = expectedFile
            
            if !FileManager.default.fileExists(atPath: expectedFile.path) {
                FileManager.default.createFile(atPath: expectedFile.path, contents: nil)
            }
            
            fileHandle = FileHandle(forWritingAtPath: expectedFile.path)
            fileHandle?.seekToEndOfFile()
        }
        
        if lastCleanupDate != today {
            lastCleanupDate = today
            cleanupOldLogsLocked()
        }
    }
    
    /// 仅在持有锁时调用
    private func cleanupOldLogsLocked() {
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxAgeDays, to: Date()) else { return }
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        
        for file in files {
            let fileName = file.lastPathComponent
            if fileName.hasPrefix("log_"), fileName.hasSuffix(".txt"),
               let dateStr = fileName.dropFirst(4).dropLast(4).split(separator: ".").first,
               let fileDate = fileNameFormatter.date(from: String(dateStr)) {
                if fileDate < cutoffDate {
                    try? FileManager.default.removeItem(at: file)
                    continue
                }
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let creationDate = attrs[.creationDate] as? Date,
               creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

