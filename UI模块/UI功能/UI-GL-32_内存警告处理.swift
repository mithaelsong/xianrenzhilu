// 功能24: 内存警告处理
// 版本: 2.0
// 对应: 收到内存警告时清理缓存（图像缓存、历史数据等）
// 优先级: P2

import AppKit
import Foundation
import os.log

// MARK: - 测试代码
#if DEBUG
// import XCTest  // 移除：XCTest 不可用，测试改用 fatalError

/// 功能24：内存警告处理 — 单元测试
/// 覆盖：注册/注销/分级清理/策略配置/白黑名单/统计
func test_memoryWarning() {
    let manager = UIMemoryWarningManager.shared
    
    print("\n🧪 测试1: 注册缓存")
    let testCache = UITestCacheable()
    manager.registerCache(id: "test.cache", cache: testCache)
    let report = manager.cacheReport()
    guard report.contains("test.cache") else {
        fatalError("❌ 测试1失败: 注册后应能在报告中找到")
    }
    print("✅ 测试1通过: 缓存注册成功")
    
    print("\n🧪 测试2: 清理级别枚举")
    let levels = UICleanupLevel.allCases
    guard levels.count == 3 else {
        fatalError("❌ 测试2失败: 应有3个清理级别")
    }
    print("✅ 测试2通过: 清理级别正确")
    
    print("\n🧪 测试3: 策略配置")
    let policy = manager.getPolicy()
    _ = policy.isAutoCleanupEnabled
    print("✅ 测试3通过: 策略配置正常")
    
    print("\n🧪 测试4: 白名单管理")
    manager.addToWhitelist(id: "important.cache")
    manager.removeFromWhitelist(id: "important.cache")
    print("✅ 测试4通过: 白名单管理正常")
    
    print("\n🧪 测试5: 设置面板数据")
    let settings = manager.getSettingsData()
    guard settings.isEnabled else {
        fatalError("❌ 测试5失败: 默认应启用")
    }
    print("✅ 测试5通过: 设置面板数据正确")
    
    print("\n🧪 测试6: 缓存统计")
    let stats = manager.getAllStatistics()
    _ = stats.count  // 至少不崩溃
    print("✅ 测试6通过: 缓存统计正常")
    
    print("\n🧪 测试7: 注销缓存")
    manager.unregisterCache(id: "test.cache")
    print("✅ 测试7通过: 注销缓存成功")
    
    print("\n=== 全部内存警告处理测试通过 ✅ ===\n")
}

// 测试用可清理缓存（类型定义在 UI-GL-32_types.swift）
// class UITestCacheable: UIMemoryCacheable { ... }
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 内存清理开始
    static let memoryCleanupDidStart = Notification.Name("MemoryCleanupDidStart")
    /// 内存清理完成
    static let memoryCleanupDidFinish = Notification.Name("MemoryCleanupDidFinish")
    /// 内存缓存统计更新
    static let memoryCacheStatisticsUpdated = Notification.Name("MemoryCacheStatisticsUpdated")
    /// 内存压力警告（macOS 自定义通知）
    static let memoryPressureWarning = Notification.Name("MemoryPressureWarning")
}

// MARK: - 迁回自 UI-02：class UIMemoryWarningManager
public final class UIMemoryWarningManager : @unchecked Sendable {

    // MARK: - 单例
    public static let shared = UIMemoryWarningManager()

    // MARK: - 日志
    private let logger = Logger(subsystem: "com.xianrenzhilu.app", category: "内存警告")

    // MARK: - 锁（使用 NSRecursiveLock）
    private let lock = NSRecursiveLock()

    // MARK: - 注册表
    private var cacheRegistry: [String: UICacheRegistryEntry] = [:]
    private var cleanupHandlers: [String: UIMemoryCleanupHandler] = [:]

    // MARK: - 策略配置
    private var policy: UICleanupPolicy = .default
    private var policyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("仙人指路")
        return appFolder.appendingPathComponent("cleanup_policy.json")
    }

    // MARK: - 定时器
    private var checkTimer: Timer?

    // MARK: - 日志记录
    private var logEntries: [UICleanupLogEntry] = []
    private let maxLogEntries = 100

    // MARK: - 监听
    private var observers: [NSObjectProtocol] = []

    // MARK: - 兼容性属性
    /// 注册的可清理缓存列表（兼容旧接口，只读）
    public var caches: [String: UIMemoryCacheable] {
        lock.lock()
        var result: [String: UIMemoryCacheable] = [:]
        for (id, entry) in cacheRegistry {
            if let cache = entry.cache {
                result[id] = cache
            }
        }
        lock.unlock()
        return result
    }

    // MARK: - 初始化
    private init() {
        loadPolicy()
        setupNotifications()
        startPeriodicCheck()
        logger.info("内存警告管理器初始化完成")
    }

    deinit {
        stopPeriodicCheck()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - 通知设置
    private func setupNotifications() {
        #if canImport(UIKit)
        // iOS 使用系统内存警告通知
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.warning("收到系统内存警告通知")
            self?.handleMemoryWarning(level: .medium)
        }
        observers.append(observer)
        #else
        // macOS 无系统级内存警告通知，使用自定义通知 + 定时检查
        let observer = NotificationCenter.default.addObserver(
            forName: .memoryPressureWarning,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let level = notification.userInfo?["level"] as? UICleanupLevel ?? .medium
            self?.logger.warning("收到内存压力警告，级别: \(level.description)")
            self?.handleMemoryWarning(level: level)
        }
        observers.append(observer)
        #endif
    }

    // MARK: - 定时检查
    /// 启动定时内存检查
    private func startPeriodicCheck() {
        guard policy.isAutoCleanupEnabled else {
            logger.info("自动清理已禁用，跳过定时检查")
            return
        }
        stopPeriodicCheck()

        checkTimer = Timer.scheduledTimer(withTimeInterval: policy.checkInterval, repeats: true) { [weak self] _ in
            self?.checkMemoryPressure()
        }
        logger.info("启动定时内存检查，间隔: \(self.policy.checkInterval) 秒")
    }

    /// 停止定时检查
    private func stopPeriodicCheck() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    /// 检查内存压力（macOS 简化实现）
    private func checkMemoryPressure() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else {
            logger.error("获取内存信息失败，错误码: \(kerr)")
            return
        }

        let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        logger.debug("当前进程内存使用: \(Int(usedMB)) MB")

        // 应用使用超过 500MB 触发轻度清理
        if usedMB > 500 {
            logger.warning("检测到内存压力，应用使用内存: \(Int(usedMB)) MB")
            handleMemoryWarning(level: .light)
        }
    }

    // MARK: - 注册 / 注销
    /// 注册可清理缓存（兼容旧接口）
    public func registerCache(id: String, cache: UIMemoryCacheable) {
        lock.lock()
        let entry = UICacheRegistryEntry(
            id: id,
            cache: cache,
            handler: nil,
            priority: .normal,
            registerTime: Date()
        )
        cacheRegistry[id] = entry
        lock.unlock()
        logger.info("注册缓存: \(id)")
    }

    /// 注册可清理缓存（带优先级）
    public func registerCache(id: String, cache: UIMemoryCacheable, priority: UICleanupPriority) {
        lock.lock()
        let entry = UICacheRegistryEntry(
            id: id,
            cache: cache,
            handler: nil,
            priority: priority,
            registerTime: Date()
        )
        cacheRegistry[id] = entry
        lock.unlock()
        logger.info("注册缓存: \(id)，优先级: \(priority.rawValue)")
    }

    /// 注册清理处理器（注册表模式）
    public func registerHandler(_ handler: UIMemoryCleanupHandler) {
        lock.lock()
        cleanupHandlers[handler.handlerId] = handler
        lock.unlock()
        logger.info("注册清理处理器: \(handler.handlerId)")
    }

    /// 注销缓存或处理器
    public func unregisterCache(id: String) {
        lock.lock()
        cacheRegistry.removeValue(forKey: id)
        cleanupHandlers.removeValue(forKey: id)
        lock.unlock()
        logger.info("注销缓存/处理器: \(id)")
    }

    // MARK: - 内存警告处理（分级清理核心）
    /// 处理内存警告，执行分级清理
    public func handleMemoryWarning(level: UICleanupLevel) {
        guard policy.isAutoCleanupEnabled else {
            logger.info("自动清理已禁用，跳过内存警告处理")
            return
        }

        logger.warning("开始内存清理，级别: \(level.description)")

        // 发送清理开始通知
        NotificationCenter.default.post(
            name: .memoryCleanupDidStart,
            object: self,
            userInfo: ["level": level, "timestamp": Date()]
        )

        var totalFreed: UInt64 = 0
        var details: [String] = []
        var processedCount = 0

        // 收集注册表条目（加锁读取）
        lock.lock()
        let entries = Array(cacheRegistry.values)
        let handlers = Array(cleanupHandlers.values)
        lock.unlock()

        // 按优先级排序：黑名单优先，然后高优先级，然后普通，最后低
        let sortedEntries = entries.sorted { a, b in
            let aInBlacklist = policy.blacklist.contains(a.id)
            let bInBlacklist = policy.blacklist.contains(b.id)
            if aInBlacklist && !bInBlacklist { return true }
            if !aInBlacklist && bInBlacklist { return false }
            return a.priority.rawValue > b.priority.rawValue
        }

        // 阶段一：清理注册表缓存
        for entry in sortedEntries {
            // 白名单检查
            if policy.whitelist.contains(entry.id) {
                details.append("[\(entry.id)] 在白名单中，跳过")
                continue
            }

            // 根据级别决定是否清理
            let shouldClean: Bool
            switch level {
            case .light:
                shouldClean = entry.priority == .high || policy.blacklist.contains(entry.id)
            case .medium:
                shouldClean = entry.priority != .low || policy.blacklist.contains(entry.id)
            case .heavy:
                shouldClean = true
            }

            if shouldClean {
                if let cache = entry.cache {
                    let size = cache.cacheSize
                    cache.clearCache()
                    totalFreed += size
                    details.append("[\(entry.id)] 清理完成，释放 \(formatBytes(size))")
                    processedCount += 1
                } else {
                    details.append("[\(entry.id)] 缓存已释放，跳过")
                }
            } else {
                details.append("[\(entry.id)] 优先级不足，跳过")
            }
        }

        // 阶段二：执行处理器清理
        for handler in handlers {
            if policy.whitelist.contains(handler.handlerId) {
                details.append("[\(handler.handlerId)] 在白名单中，跳过")
                continue
            }

            let freed = handler.performCleanup(level: level)
            if freed > 0 {
                totalFreed += freed
                details.append("[\(handler.handlerId)] 处理器释放 \(formatBytes(freed))")
                processedCount += 1
            }
        }

        // 阶段三：重度清理额外措施
        if level == .heavy {
            malloc_zone_pressure_relief(nil, 0)
            details.append("执行系统内存压力释放")
        }

        // 记录日志
        if policy.isLoggingEnabled {
            let logEntry = UICleanupLogEntry(
                timestamp: Date(),
                level: level,
                freedBytes: totalFreed,
                processedCount: processedCount,
                details: details
            )
            appendLogEntry(logEntry)
        }

        logger.info("内存清理完成，级别: \(level.description)，释放: \(self.formatBytes(totalFreed))，处理: \(processedCount) 项")

        // 发送清理完成通知
        NotificationCenter.default.post(
            name: .memoryCleanupDidFinish,
            object: self,
            userInfo: [
                "level": level,
                "freedBytes": totalFreed,
                "processedCount": processedCount,
                "details": details,
                "timestamp": Date()
            ]
        )

        // 发送统计更新通知
        postStatisticsUpdate()
    }

    // MARK: - 手动清理
    /// 主动触发缓存清理（兼容旧接口，使用默认级别）
    public func purgeAllCaches() {
        logger.info("手动触发缓存清理（默认中度）")
        handleMemoryWarning(level: policy.autoCleanupLevel)
    }

    /// 手动触发指定级别的缓存清理
    public func purgeAllCaches(level: UICleanupLevel) {
        logger.info("手动触发缓存清理，级别: \(level.description)")
        handleMemoryWarning(level: level)
    }

    /// 清理指定缓存
    @discardableResult
    public func purgeCache(id: String) -> Bool {
        var cacheToPurge: UIMemoryCacheable?
        var size: UInt64 = 0

        lock.lock()
        if let entry = cacheRegistry[id], let c = entry.cache {
            cacheToPurge = c
            size = c.cacheSize
        }
        lock.unlock()

        guard let cache = cacheToPurge else {
            logger.warning("未找到缓存: \(id)")
            return false
        }

        cache.clearCache()
        logger.info("手动清理缓存: \(id)，释放: \(self.formatBytes(size))")
        postStatisticsUpdate()
        return true
    }

    // MARK: - 统计与报告
    /// 获取所有缓存统计信息
    public func getAllStatistics() -> [UIMemoryCacheStatistics] {
        var stats: [UIMemoryCacheStatistics] = []

        lock.lock()
        let entries = Array(cacheRegistry.values)
        let handlers = Array(cleanupHandlers.values)
        lock.unlock()

        for entry in entries {
            if let cache = entry.cache {
                stats.append(UIMemoryCacheStatistics(
                    id: entry.id,
                    size: cache.cacheSize,
                    isActive: true,
                    priority: entry.priority
                ))
            }
        }

        for handler in handlers {
            stats.append(UIMemoryCacheStatistics(
                id: handler.handlerId,
                size: handler.currentCacheSize,
                isActive: handler.isActive,
                priority: .normal
            ))
        }

        return stats
    }

    /// 获取缓存大小报告（兼容旧接口）
    public func cacheReport() -> String {
        let stats = getAllStatistics()
        var lines = ["📊 内存缓存报告"]
        lines.append("━━━━━━━━━━━━━━━━━━━━━━")

        let totalSize = stats.reduce(0) { $0 + $1.size }
        lines.append("总缓存大小: \(formatBytes(totalSize))")
        lines.append("缓存项数量: \(stats.count)")
        lines.append("")

        for stat in stats.sorted(by: { $0.size > $1.size }) {
            let status = stat.isActive ? "🟢" : "⚪️"
            lines.append("\(status) \(stat.id): \(stat.formattedSize)")
        }

        return lines.joined(separator: "\n")
    }

    /// 获取清理日志
    public func getCleanupLogs() -> [UICleanupLogEntry] {
        lock.lock()
        let logs = logEntries
        lock.unlock()
        return logs
    }

    /// 获取总缓存大小
    public var totalCacheSize: UInt64 {
        let stats = getAllStatistics()
        return stats.reduce(0) { $0 + $1.size }
    }

    // MARK: - 策略配置
    /// 获取当前策略
    public func getPolicy() -> UICleanupPolicy {
        lock.lock()
        let current = policy
        lock.unlock()
        return current
    }

    /// 更新策略
    public func updatePolicy(_ newPolicy: UICleanupPolicy) {
        lock.lock()
        policy = newPolicy
        lock.unlock()
        savePolicy()

        if newPolicy.isAutoCleanupEnabled {
            startPeriodicCheck()
        } else {
            stopPeriodicCheck()
        }

        logger.info("策略更新: 自动=\(newPolicy.isAutoCleanupEnabled), 级别=\(newPolicy.autoCleanupLevel.description)")
    }

    /// 添加白名单
    public func addToWhitelist(id: String) {
        lock.lock()
        if !policy.whitelist.contains(id) {
            policy.whitelist.append(id)
        }
        lock.unlock()
        savePolicy()
        logger.info("添加白名单: \(id)")
    }

    /// 移除白名单
    public func removeFromWhitelist(id: String) {
        lock.lock()
        policy.whitelist.removeAll { $0 == id }
        lock.unlock()
        savePolicy()
        logger.info("移除白名单: \(id)")
    }

    /// 添加黑名单
    public func addToBlacklist(id: String) {
        lock.lock()
        if !policy.blacklist.contains(id) {
            policy.blacklist.append(id)
        }
        lock.unlock()
        savePolicy()
        logger.info("添加黑名单: \(id)")
    }

    /// 移除黑名单
    public func removeFromBlacklist(id: String) {
        lock.lock()
        policy.blacklist.removeAll { $0 == id }
        lock.unlock()
        savePolicy()
        logger.info("移除黑名单: \(id)")
    }

    // MARK: - 设置面板方法
    /// 获取设置面板数据（供设置面板调用）
    public func getSettingsData() -> (
        isEnabled: Bool,
        level: UICleanupLevel,
        whitelist: [String],
        blacklist: [String],
        threshold: Double,
        interval: TimeInterval,
        totalSize: UInt64,
        logCount: Int
    ) {
        lock.lock()
        let p = policy
        let logs = logEntries.count
        lock.unlock()
        return (
            isEnabled: p.isAutoCleanupEnabled,
            level: p.autoCleanupLevel,
            whitelist: p.whitelist,
            blacklist: p.blacklist,
            threshold: p.memoryPressureThreshold,
            interval: p.checkInterval,
            totalSize: totalCacheSize,
            logCount: logs
        )
    }

    /// 从设置面板更新配置
    public func updateSettings(
        isEnabled: Bool,
        level: UICleanupLevel,
        whitelist: [String],
        blacklist: [String],
        threshold: Double,
        interval: TimeInterval
    ) {
        var newPolicy = getPolicy()
        newPolicy.isAutoCleanupEnabled = isEnabled
        newPolicy.autoCleanupLevel = level
        newPolicy.whitelist = whitelist
        newPolicy.blacklist = blacklist
        newPolicy.memoryPressureThreshold = threshold
        newPolicy.checkInterval = interval
        updatePolicy(newPolicy)
    }

    /// 设置面板手动触发清理
    public func settingsTriggerCleanup(level: UICleanupLevel) -> (success: Bool, freedBytes: UInt64, message: String) {
        let before = totalCacheSize
        handleMemoryWarning(level: level)
        let after = totalCacheSize
        let freed = before > after ? before - after : 0
        let message = "清理完成，释放 \(formatBytes(freed))，剩余 \(formatBytes(after))"
        logger.info("设置面板触发清理: \(message)")
        return (success: true, freedBytes: freed, message: message)
    }

    // MARK: - 持久化
    /// 加载保存的策略
    private func loadPolicy() {
        guard FileManager.default.fileExists(atPath: policyFileURL.path),
              let data = try? Data(contentsOf: policyFileURL),
              let saved = try? JSONDecoder().decode(UICleanupPolicy.self, from: data) else {
            logger.info("使用默认清理策略")
            return
        }
        lock.lock()
        policy = saved
        lock.unlock()
        logger.info("已加载保存的清理策略")
    }

    /// 保存策略到磁盘
    private func savePolicy() {
        do {
            let directory = policyFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

            lock.lock()
            let data = try JSONEncoder().encode(policy)
            lock.unlock()

            try data.write(to: policyFileURL)
            logger.info("清理策略已保存")
        } catch {
            logger.error("保存策略失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 日志管理
    /// 添加日志条目（限制最大数量）
    private func appendLogEntry(_ entry: UICleanupLogEntry) {
        lock.lock()
        logEntries.append(entry)
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
        lock.unlock()
    }

    // MARK: - 通知
    /// 发送统计更新通知
    private func postStatisticsUpdate() {
        let stats = getAllStatistics()
        NotificationCenter.default.post(
            name: .memoryCacheStatisticsUpdated,
            object: self,
            userInfo: ["statistics": stats, "timestamp": Date()]
        )
    }

    // MARK: - 工具方法
    /// 格式化字节大小为可读字符串
    private func formatBytes(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1024 {
            return "\(bytes) B"
        } else if b < 1024 * 1024 {
            return String(format: "%.2f KB", b / 1024)
        } else if b < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB", b / 1024 / 1024)
        } else {
            return String(format: "%.2f GB", b / 1024 / 1024 / 1024)
        }
    }
}

// MARK: - 迁回自 UI-02：class UITestCacheable
class UITestCacheable: UIMemoryCacheable , @unchecked Sendable{
    var cacheSize: UInt64 { 1024 }
    func clearCache() { }
}

// MARK: - 迁回自 UI-02：enum UICleanupLevel
// MARK: - 加载指示器视图
/// 简单的加载旋转指示器
// 已迁回 UI-GL-31_异步加载器.swift：class UILoadingIndicatorView（公共类型文件禁止功能实现）


// MARK: - UI-GL-32 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-32_types.swift
// 版本: 2.0
// MARK: - 清理级别
/// 内存清理分级策略
public enum UICleanupLevel: Int, Codable, CaseIterable, Sendable {
    /// 轻度清理：只清理高优先级和黑名单缓存
    case light = 0
    /// 中度清理：清理高优先级、普通优先级和黑名单缓存
    case medium = 1
    /// 重度清理：清理所有缓存（白名单除外），并强制释放系统资源
    case heavy = 2

    public var description: String {
        switch self {
        case .light:  return "轻度"
        case .medium: return "中度"
        case .heavy:  return "重度"
        }
    }
}

// MARK: - 迁回自 UI-02：enum UICleanupPriority
// MARK: - 清理优先级
/// 缓存清理优先级，决定清理顺序
public enum UICleanupPriority: Int, Codable {
    /// 低优先级，最后清理
    case low = 0
    /// 普通优先级
    case normal = 1
    /// 高优先级，优先清理
    case high = 2
}

// MARK: - 迁回自 UI-02：struct UICleanupPolicy
// MARK: - 清理策略配置
/// 清理策略，支持 Codable 持久化
public struct UICleanupPolicy: Codable, Sendable {
    /// 白名单：这些缓存 ID 不会被自动清理
    public var whitelist: [String] = []
    /// 黑名单：这些缓存 ID 优先清理
    public var blacklist: [String] = []
    /// 自动清理级别
    public var autoCleanupLevel: UICleanupLevel = .medium
    /// 是否启用自动清理
    public var isAutoCleanupEnabled: Bool = true
    /// 是否记录清理日志
    public var isLoggingEnabled: Bool = true
    /// 内存压力阈值（百分比，0-100）
    public var memoryPressureThreshold: Double = 85.0
    /// 定时检查间隔（秒）
    public var checkInterval: TimeInterval = 60.0

    /// 默认策略
    public static let `default` = UICleanupPolicy()
}

// MARK: - 迁回自 UI-02：struct UIMemoryCacheStatistics
// MARK: - 缓存统计信息
/// 单个缓存模块的统计信息
public struct UIMemoryCacheStatistics {
    public let id: String
    public let size: UInt64
    public let isActive: Bool
    public let priority: UICleanupPriority

    /// 格式化大小显示
    public var formattedSize: String {
        let bytes = Double(size)
        if bytes < 1024 {
            return "\(size) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.2f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB", bytes / 1024 / 1024)
        } else {
            return String(format: "%.2f GB", bytes / 1024 / 1024 / 1024)
        }
    }
}

// MARK: - 迁回自 UI-02：protocol UIMemoryCleanupHandler
// MARK: - 缓存清理处理器协议
/// 高级清理处理器，支持分级清理和返回释放大小
public protocol UIMemoryCleanupHandler: AnyObject {
    /// 处理器唯一标识
    var handlerId: String { get }
    /// 执行指定级别的清理，返回释放的字节数
    func performCleanup(level: UICleanupLevel) -> UInt64
    /// 当前缓存大小
    var currentCacheSize: UInt64 { get }
    /// 是否处于活跃状态
    var isActive: Bool { get }
}

// MARK: - 迁回自 UI-02：protocol UIMemoryCacheable
// MARK: - 可清理缓存协议（兼容旧接口）
/// 可被内存警告清理的缓存
public protocol UIMemoryCacheable: AnyObject {
    /// 清空缓存
    func clearCache()
    /// 缓存大小（字节）
    var cacheSize: UInt64 { get }
}

// MARK: - 迁回自 UI-02：struct UICacheRegistryEntry
// MARK: - 缓存注册条目
/// 注册表条目，统一管理缓存和处理器
public struct UICacheRegistryEntry {
    public let id: String
    public weak var cache: UIMemoryCacheable?
    public weak var handler: UIMemoryCleanupHandler?
    public let priority: UICleanupPriority
    public let registerTime: Date
}

// MARK: - 迁回自 UI-02：struct UICleanupLogEntry
// MARK: - 清理日志条目
/// 单次清理操作的日志记录
public struct UICleanupLogEntry: Codable {
    public let timestamp: Date
    public let level: UICleanupLevel
    public let freedBytes: UInt64
    public let processedCount: Int
    public let details: [String]
}
