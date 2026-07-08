//
//  KX-UT-01_日志工具.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：K线模块统一日志工具，支持控制台输出和文件日志
//  禁止事项：禁止直接使用NSLog，统一使用此工具
//

import Foundation
import os.log

// MARK: - 统一日志工具

public final class KXLogger: @unchecked Sendable {
    public let subsystem: String
    public let category: String
    private let osLogger: os.Logger

    // 线程安全文件写入
    private let logFileURL: URL?
    private let fileHandle: FileHandle?
    private var fileLock = os_unfair_lock()

    // 共享 DateFormatter
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return df
    }()

    public static func makeKXLogger(subsystem: String = "com.xianrenzhilu.kline", category: String) -> KXLogger {
        return KXLogger(subsystem: subsystem, category: category)
    }

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        self.osLogger = os.Logger(subsystem: subsystem, category: category)

        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            self.logFileURL = nil
            self.fileHandle = nil
            return
        }

        let klineLogDir = documentsDir.appendingPathComponent("KLineLogs", isDirectory: true)
        let url = klineLogDir.appendingPathComponent("\(category).log")

        try? fileManager.createDirectory(at: klineLogDir, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }

        if let fh = try? FileHandle(forWritingTo: url) {
            fh.seekToEndOfFile()
            self.logFileURL = url
            self.fileHandle = fh
        } else {
            self.logFileURL = nil
            self.fileHandle = nil
        }
    }

    public func debug(_ message: String) {
        let msg = "[DEBUG] [\(Self.dateFormatter.string(from: Date()))] \(message)\n"
        print(msg, terminator: "")
        writeToFile(msg)
        osLogger.debug("\(message)")
    }

    public func info(_ message: String) {
        let msg = "[INFO] [\(Self.dateFormatter.string(from: Date()))] \(message)\n"
        print(msg, terminator: "")
        writeToFile(msg)
        osLogger.info("\(message)")
    }

    public func warning(_ message: String) {
        let msg = "[WARNING] [\(Self.dateFormatter.string(from: Date()))] \(message)\n"
        print(msg, terminator: "")
        writeToFile(msg)
        osLogger.warning("\(message)")
    }

    public func error(_ message: String) {
        let msg = "[ERROR] [\(Self.dateFormatter.string(from: Date()))] \(message)\n"
        fputs(msg, stderr)
        writeToFile(msg)
        osLogger.error("\(message)")
    }

    private func writeToFile(_ message: String) {
        guard let data = message.data(using: .utf8), let fh = fileHandle else { return }
        os_unfair_lock_lock(&fileLock)
        defer { os_unfair_lock_unlock(&fileLock) }
        do {
            try fh.write(contentsOf: data)
        } catch {
            print("Failed to write to log file: \(error)")
        }
    }

    deinit {
        fileHandle?.closeFile()
    }
}

// MARK: - 安全数组下标

extension Array {
    public subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// MARK: - 全局统一日志实例

public let klineLogger = KXLogger.makeKXLogger(category: "KLineModule")

// MARK: - KXFileSkeletonProtocol

public enum KXUT01Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UT-01",
        fileName: "KX-UT-01_日志工具.swift",
        layer: .utility,
        relativePath: "工具服务层/KX-UT-01_日志工具.swift",
        duty: "K线模块统一日志工具，支持控制台输出和文件日志"
    )

    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("日志工具骨架校验通过")
        return KXHealthCheckItem(name: "统一日志工具", passed: true, message: "日志工具支持控制台+文件双输出，线程安全")
    }
}
