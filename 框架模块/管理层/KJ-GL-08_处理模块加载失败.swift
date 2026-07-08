// KJ-GL-08_处理模块加载失败.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os

// MARK: - KJModuleFailureHandler
// MARK: - 迁移自 KJ-GL-08_处理模块加载失败.swift
// MARK: - 模块失败处理器
/// 模块失败处理器（功能7）
/// 处理5种模块加载失败，包含恢复策略和指数退避重试
/// 所有操作使用 os_unfair_lock 保证线程安全
public final class KJModuleFailureHandler {
    private let logger = KJModuleLogger.shared
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0
    
    private var retryRecords: [String: KJRetryRecord] = [:]
    private var lock = os_unfair_lock()
    
    // MARK: - 处理失败
    /// 为每种失败类型执行对应的处理策略
    /// - Parameter failure: 具体的失败类型
    /// - Returns: 该失败的解决决策
    public func handle(_ failure: KJModuleFailureType) -> KJModuleFailureResolution {
        switch failure {
        case .dependencyMissing(let module, let dependency):
            // 记录日志并标记重试
            logger.info("KJModuleFailureHandler", "模块 [\(module)] 依赖缺失: \(dependency)，标记重试")
            return scheduleRetry(module: module)
            
        case .circularDependency(let path):
            // 中止：拒绝加载，报告错误
            let pathStr = path.joined(separator: " -> ")
            logger.error("KJModuleFailureHandler", "检测到循环依赖: \(pathStr)，中止加载")
            return .abort
            
        case .versionIncompatible(let module, let required, let actual):
            // 降级：记录日志并尝试降级
            logger.warning("KJModuleFailureHandler", "模块 [\(module)] 版本不兼容: 需要 \(required)，实际 \(actual)，尝试降级")
            return .downgrade
            
        case .configurationError(let module, let reason):
            // 使用默认配置：记录日志并继续
            logger.warning("KJModuleFailureHandler", "模块 [\(module)] 配置错误: \(reason)，使用默认配置")
            return .useDefaultConfig
            
        case .loadTimeout(let module, let duration):
            // 重试：记录日志，最多重试3次，然后放弃
            logger.error("KJModuleFailureHandler", "模块 [\(module)] 加载超时: \(String(format: "%.2f", duration))s，重试")
            return scheduleRetry(module: module)
        }
    }
    
    // MARK: - 重试管理
    /// 计算并记录重试计划（指数退避）
    /// - Parameter module: 模块名称
    /// - Returns: 重试决策（重试/放弃）
    private func scheduleRetry(module: String) -> KJModuleFailureResolution {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        var record = retryRecords[module] ?? KJRetryRecord()
        record.count += 1
        
        if record.count > maxRetries {
            logger.error("KJModuleFailureHandler", "模块 \(module) 超过最大重试次数 (\(maxRetries))，放弃")
            retryRecords.removeValue(forKey: module)
            return .giveUp
        }
        
        // 指数退避：延迟 = 基础延迟 * 2^(尝试次数-1)
        let delay = baseDelay * pow(2.0, Double(record.count - 1))
        record.nextRetryAt = Date().addingTimeInterval(delay)
        retryRecords[module] = record
        
        logger.info("KJModuleFailureHandler", "模块 \(module) 将在 \(String(format: "%.2f", delay))s 后重试 (第\(record.count)/\(maxRetries)次)")
        return .retry(delay: delay)
    }
    
    /// 检查模块是否仍可重试
    /// - Parameter module: 模块名称
    /// - Returns: 是否未超过最大重试次数
    public func canRetry(module: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard let record = retryRecords[module] else { return true }
        return record.count < maxRetries
    }
    
    /// 获取模块的当前重试次数
    /// - Parameter module: 模块名称
    /// - Returns: 重试次数，未记录则为0
    public func retryCount(for module: String) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return retryRecords[module]?.count ?? 0
    }
    
    /// 获取模块的下次重试时间
    /// - Parameter module: 模块名称
    /// - Returns: 下次重试时间，无计划则为nil
    public func nextRetryTime(for module: String) -> Date? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return retryRecords[module]?.nextRetryAt
    }
    
    /// 重置模块的重试记录（加载成功后调用）
    /// - Parameter module: 模块名称
    public func reset(module: String) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        retryRecords.removeValue(forKey: module)
        logger.info("KJModuleFailureHandler", "模块 \(module) 重试记录已重置")
    }
    
    /// 重置所有重试记录
    public func resetAll() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        retryRecords.removeAll()
        logger.info("KJModuleFailureHandler", "全部模块重试记录已重置")
    }
    
    // MARK: - 查询状态
    /// 获取所有待重试的模块
    public var pendingRetryModules: [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return Array(retryRecords.keys)
    }
    
    /// 获取待重试模块的数量
    public var pendingRetryCount: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return retryRecords.count
    }
}

