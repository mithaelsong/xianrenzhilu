// 功能29: 模块加载日志
// 对应: 输出每个模块的加载时间、成功/失败状态
// 优先级: P0

import Foundation
import os


// MARK: - KJModuleLoadLogger

/// 模块加载日志记录器（功能29）
/// 线程安全的单例，记录每个模块的加载耗时和结果，支持导出和统计
public final class KJModuleLoadLogger: @unchecked Sendable {

    // MARK: - 单例
    public static let shared = KJModuleLoadLogger()

    // MARK: - 私有状态
    private var _records: [KJLoadRecord] = []
    private var _lock = os_unfair_lock()

    // MARK: - 初始化
    private init() {}

    // MARK: - 锁辅助方法
    @inline(__always)
    private func withLock<T>(_ block: () -> T) -> T {
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        return block()
    }

    // MARK: - 记录加载事件

    /// 记录模块加载开始
    /// - Parameter moduleName: 模块名称
    /// - Returns: 纳秒级时间戳，用于后续 logLoadEnd 计时
    public func logLoadStart(moduleName: String) -> UInt64 {
        log("[KJModuleLoadLogger] 开始加载模块: \(moduleName)")
        return DispatchTime.now().uptimeNanoseconds
    }

    /// 记录模块加载结束
    /// - Parameters:
    ///   - moduleName: 模块名称
    ///   - startTime: logLoadStart 返回的时间戳
    ///   - success: 是否加载成功
    ///   - error: 错误信息（加载失败时）
    public func logLoadEnd(moduleName: String, startTime: UInt64, success: Bool, error: String? = nil) {
        let endTime = DispatchTime.now().uptimeNanoseconds
        let duration = TimeInterval(endTime - startTime) / 1_000_000_000.0
        let endDate = Date()
        _ = Date(timeInterval: -duration, since: endDate)

        let record = KJLoadRecord(
            moduleID: moduleName,
            status: success ? "success" : "failure",
            timestamp: endDate
        )

        withLock {
            _records.append(record)
        }

        if success {
            log("[KJModuleLoadLogger] ✅ 模块 \(moduleName) 加载成功，耗时 \(String(format: "%.3f", duration))s")
        } else {
            log("[KJModuleLoadLogger] ❌ 模块 \(moduleName) 加载失败，耗时 \(String(format: "%.3f", duration))s — \(error ?? "未知错误")")
        }
    }

    // MARK: - 查询记录

    /// 获取所有加载记录
    /// - Returns: 所有加载记录数组
    public func getLoadReport() -> [KJLoadRecord] {
        return withLock { Array(_records) }
    }

    /// 按模块名查询加载记录
    /// - Parameter moduleName: 模块名称
    /// - Returns: 该模块的所有加载记录
    public func records(for moduleName: String) -> [KJLoadRecord] {
        return withLock { _records.filter { $0.moduleID == moduleName } }
    }

    // MARK: - 统计

    /// 成功加载次数
    public var successCount: Int {
        return withLock { _records.filter { $0.status == "success" }.count }
    }

    /// 失败加载次数
    public var failureCount: Int {
        return withLock { _records.filter { $0.status != "success" }.count }
    }

    // MARK: - 导出与清除

    /// 导出加载报告为文本
    /// - Returns: 格式化的报告文本
    public func exportReport() -> String {
        let records = getLoadReport()
        var lines: [String] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.locale = Locale(identifier: "zh_CN")

        lines.append("=== 模块加载报告 ===")
        lines.append("生成时间: \(dateFormatter.string(from: Date()))")
        lines.append("总记录数: \(records.count)")
        lines.append("成功次数: \(successCount)")
        lines.append("失败次数: \(failureCount)")
        lines.append("成功率: \(records.isEmpty ? "N/A" : String(format: "%.1f%%", Double(successCount) / Double(records.count) * 100))")
        lines.append("")

        for (index, record) in records.enumerated() {
            let status = record.status == "success" ? "✅ 成功" : "❌ 失败"
            lines.append("[\(index + 1)] \(record.moduleID)")
            lines.append("    状态: \(status)")
            lines.append("    开始: \(dateFormatter.string(from: record.timestamp))")
            lines.append("    结束: \(dateFormatter.string(from: record.timestamp))")
            lines.append("    耗时: \(String(format: "%.3f", 0.0))s")
            if false {
                lines.append("    错误: 无")
            }
            lines.append("")
        }

        lines.append("=== 报告结束 ===")
        return lines.joined(separator: "\n")
    }

    /// 清除所有记录
    public func clearRecords() {
        withLock {
            _records.removeAll()
        }
        log("[KJModuleLoadLogger] 所有记录已清除")
    }

    // MARK: - 私有日志
    private func log(_ message: String) {
        print(message)
    }
}


