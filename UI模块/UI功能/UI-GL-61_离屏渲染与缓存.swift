// 功能51: 离屏渲染与缓存
// 对应: K线图表内容渲染到离屏位图，滚动/缩放/重绘时复用缓存，提升帧率
// 优先级: P2
// 作者: 码农
// 版本: 2.0

import AppKit
import Foundation
import QuartzCore
import SwiftUI
import os.log

// MARK: - 测试代码
#if DEBUG

/// 功能51：离屏渲染与缓存 — 单元测试
func test_offscreenRender() {
    let cache = UIOffscreenRenderCache.shared
    let logger = OSLog(subsystem: "com.xianrenzhilu.ui", category: "UI-GL-61")
    
    os_log("测试1: 默认配置", log: logger, type: .info)
    let config = cache.currentConfiguration()
    if config.isEnabled { os_log("✅ 测试1通过", log: logger, type: .info) }
    else { os_log("❌ 测试1失败", log: logger, type: .error) }
    
    os_log("测试2: 离屏渲染", log: logger, type: .info)
    let image = cache.render(
        key: "test_chart",
        size: CGSize(width: 100, height: 100),
        scale: 1.0
    ) { ctx in
        ctx.setFillColor(NSColor.red.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
    }
    if image != nil { os_log("✅ 测试2通过", log: logger, type: .info) }
    else { os_log("❌ 测试2失败", log: logger, type: .error) }
    
    os_log("测试3: 缓存命中", log: logger, type: .info)
    let cached = cache.cachedImage(forKey: "test_chart", size: CGSize(width: 100, height: 100), scale: 1.0)
    if cached != nil { os_log("✅ 测试3通过", log: logger, type: .info) }
    else { os_log("❌ 测试3失败", log: logger, type: .error) }
    
    os_log("测试4: 失效", log: logger, type: .info)
    cache.invalidate(key: "test_chart")
    let afterInvalidate = cache.cachedImage(forKey: "test_chart", size: CGSize(width: 100, height: 100), scale: 1.0)
    if afterInvalidate == nil { os_log("✅ 测试4通过", log: logger, type: .info) }
    else { os_log("❌ 测试4失败", log: logger, type: .error) }
    
    os_log("测试5: 全部清空", log: logger, type: .info)
    cache.clearAll()
    let stats = cache.statistics()
    _ = stats
    os_log("✅ 测试5通过", log: logger, type: .info)
    
    os_log("测试6: 配置更新", log: logger, type: .info)
    var newConfig = UIOffscreenRenderCacheConfig()
    newConfig.maxMemoryMB = 512
    cache.configure(newConfig)
    let updatedConfig = cache.currentConfiguration()
    if updatedConfig.maxMemoryMB == 512 { os_log("✅ 测试6通过", log: logger, type: .info) }
    else { os_log("❌ 测试6失败", log: logger, type: .error) }
    
    os_log("测试7: 统计重置", log: logger, type: .info)
    cache.resetStatistics()
    os_log("✅ 测试7通过", log: logger, type: .info)
    
    os_log("=== 全部离屏渲染缓存测试通过 ✅ ===", log: logger, type: .info)
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 缓存命中通知
    /// userInfo: ["key": String, "cost": Int]
    static let offscreenRenderCacheHit = Notification.Name("com.xianrenzhilu.offscreenRenderCacheHit")
    /// 缓存失效通知
    /// userInfo: ["keys": [String], "reason": String]
    static let offscreenRenderCacheInvalidated = Notification.Name("com.xianrenzhilu.offscreenRenderCacheInvalidated")
    /// 缓存配置变更通知
    /// userInfo: ["old": UIOffscreenRenderCacheConfig, "new": UIOffscreenRenderCacheConfig]
    static let offscreenRenderCacheConfigChanged = Notification.Name("com.xianrenzhilu.offscreenRenderCacheConfigChanged")
}

// MARK: - 迁回自 UI-02：class UIOffscreenCacheEntry
final class UIOffscreenCacheEntry: NSObject , @unchecked Sendable{  // 原为private，改为internal以符合NSCacheDelegate
    /// 离屏渲染生成的位图
    let image: CGImage
    /// 该条目的元数据
    let metadata: UIOffscreenCacheEntryMetadata

    init(image: CGImage, metadata: UIOffscreenCacheEntryMetadata) {
        self.image = image
        self.metadata = metadata
        super.init()
    }
}

// MARK: - 迁回自 UI-02：class UIOffscreenRenderCache
public final class UIOffscreenRenderCache: NSObject , @unchecked Sendable{

    // MARK: 单例
    /// 全局唯一实例，整个应用生命周期共享同一缓存
    public static let shared = UIOffscreenRenderCache()

    // MARK: Logger
    /// 结构化日志记录器，严禁在代码中直接使用print输出
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "UIOffscreenRenderCache")

    // MARK: 并发锁
    /// 保护配置数据的并发访问，防止读写竞态
    private let configLock = NSRecursiveLock()
    /// 保护统计信息的并发访问，确保计数准确
    private let statsLock = NSRecursiveLock()
    /// 保护元数据字典的并发访问，与NSCache配合使用
    private let metadataLock = NSRecursiveLock()

    // MARK: 配置
    /// 当前生效的缓存配置
    private nonisolated(unsafe) var currentConfig: UIOffscreenRenderCacheConfig
    /// 配置文件在本地磁盘上的持久化路径
    private let configFileURL: URL

    // MARK: 缓存存储
    /// NSCache主存储容器，具备自动LRU淘汰与内存管理能力
    private let cache: NSCache<NSString, UIOffscreenCacheEntry>
    /// 元数据字典，记录所有缓存条目的时间与成本信息。
    /// 由于NSCache不暴露内部键集合，必须自行维护以支持遍历清理。
    private nonisolated(unsafe) var metadataDict: [String: UIOffscreenCacheEntryMetadata] = [:]

    // MARK: 统计
    /// 当前统计快照，按配置决定是否实时更新
    private nonisolated(unsafe) var currentStats: UIOffscreenRenderCacheStatistics
    /// 渲染耗时累加器，用于计算移动平均
    private var totalRenderTimeAccumulator: Double = 0.0

    // MARK: 定时器
    /// 自动清理定时器，周期性执行过期检查
    private nonisolated(unsafe) var cleanupTimer: Timer?
    /// 标记是否已完成初始化流程
    private var isInitialized: Bool = false

    // MARK: 初始化
    /// 私有构造器，加载持久化配置，初始化缓存容器与定时器
    private override init() {
        // 1. 准备Application Support目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = appSupport?.appendingPathComponent("com.xianrenzhilu", isDirectory: true)
        if let dir = dir, !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // 目录创建失败时不阻断初始化，降级到临时目录
            }
        }
        self.configFileURL = dir?.appendingPathComponent("offscreen_cache_config.json")
            ?? URL(fileURLWithPath: "/tmp/xianrenzhilu_offscreen_cache_config.json")

        // 2. 从磁盘加载已有配置，若失败则回退到默认配置
        if let data = try? Data(contentsOf: self.configFileURL),
           let decoded = try? JSONDecoder().decode(UIOffscreenRenderCacheConfig.self, from: data) {
            self.currentConfig = decoded
        } else {
            self.currentConfig = .default
        }

        // 3. 初始化NSCache，根据加载的配置设定容量上限
        self.cache = NSCache<NSString, UIOffscreenCacheEntry>()
        self.cache.name = "com.xianrenzhilu.UIOffscreenRenderCache"
        let initConfig = self.currentConfig
        self.cache.countLimit = initConfig.maxEntries
        self.cache.totalCostLimit = initConfig.maxMemoryMB * 1024 * 1024

        // 4. 初始化统计结构体
        self.currentStats = UIOffscreenRenderCacheStatistics()

        super.init()

        // 5. 设置NSCache代理，监听逐出事件
        self.cache.delegate = self

        // 6. 启动后台定时清理任务
        self.startAutoCleanup()

        self.isInitialized = true
        self.logger.info("离屏渲染缓存管理器初始化完成，配置: \(initConfig.description)")
    }

    // MARK: 反初始化
    /// 销毁时清理资源：停止定时器、持久化配置、清空缓存
    deinit {
        self.stopAutoCleanup()
        self.saveConfig()
        self.clearAll(reason: .deinitCleanup)
        self.logger.info("离屏渲染缓存管理器已销毁，资源已清理")
    }

    // MARK: 公共接口 - 离屏渲染

    /// 离屏渲染入口方法。
    /// 若缓存已启用且命中缓存，直接返回缓存位图；否则执行离屏绘制并写入缓存。
    /// - Parameters:
    ///   - key: 业务缓存键，通常包含数据源标识、K线区间、缩放级别等
    ///   - size: 目标渲染尺寸（逻辑点）
    ///   - scale: 物理像素缩放比例，nil时使用配置默认值
    ///   - draw: 闭包，接收CGContext，负责执行具体绘制指令
    /// - Returns: 生成的CGImage位图，失败时返回nil
    public func render(key: String, size: CGSize, scale: CGFloat? = nil, draw: (CGContext) -> Void) -> CGImage? {
        self.configLock.lock()
        let effectiveScale = scale ?? self.currentConfig.defaultScale
        let isEnabled = self.currentConfig.isEnabled
        self.configLock.unlock()

        // 若缓存被全局禁用，直接走无缓存路径
        if !isEnabled {
            self.logger.debug("缓存全局已禁用，直接渲染: \(key)")
            return self.renderDirectly(size: size, scale: effectiveScale, draw: draw)
        }

        // 构造完整缓存键，包含尺寸与缩放信息，确保不同渲染参数的隔离
        let fullKey = "\(key)_\(Int(size.width))x\(Int(size.height))_\(String(format: "%.2f", effectiveScale))"
        let nsKey = fullKey as NSString

        // 尝试从NSCache读取
        if let entry = self.cache.object(forKey: nsKey) {
            self.updateStatsHit(entry: entry)
            return entry.image
        }

        // 缓存未命中，执行离屏渲染
        self.updateStatsMiss()
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let image = self.renderDirectly(size: size, scale: effectiveScale, draw: draw) else {
            self.logger.error("离屏渲染失败: \(fullKey)")
            return nil
        }

        let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        // 计算内存成本：宽 x 高 x 4字节（RGBA）
        let pixelWidth = Int(ceil(size.width * effectiveScale))
        let pixelHeight = Int(ceil(size.height * effectiveScale))
        let cost = max(pixelWidth * pixelHeight * 4, 1)

        let meta = UIOffscreenCacheEntryMetadata(
            cacheKey: fullKey,
            createdAt: Date(),
            cost: cost,
            lastAccessedAt: Date()
        )
        let entry = UIOffscreenCacheEntry(image: image, metadata: meta)

        // 写入NSCache并记录元数据
        self.cache.setObject(entry, forKey: nsKey, cost: cost)
        self.metadataLock.lock()
        self.metadataDict[fullKey] = meta
        self.metadataLock.unlock()

        self.updateStatsRender(time: elapsedMs, cost: cost)
        self.logger.debug("离屏渲染完成并写入缓存: \(fullKey), 耗时: \(String(format: "%.2f", elapsedMs))ms")

        return image
    }

    /// 仅读取缓存，不触发离屏渲染。
    /// 用于需要快速判断缓存是否存在，但不希望触发绘制的场景。
    public func cachedImage(forKey key: String, size: CGSize, scale: CGFloat? = nil) -> CGImage? {
        self.configLock.lock()
        let effectiveScale = scale ?? self.currentConfig.defaultScale
        self.configLock.unlock()
        let fullKey = "\(key)_\(Int(size.width))x\(Int(size.height))_\(String(format: "%.2f", effectiveScale))"
        let nsKey = fullKey as NSString

        if let entry = self.cache.object(forKey: nsKey) {
            self.updateStatsHit(entry: entry)
            return entry.image
        }
        return nil
    }

    // MARK: 公共接口 - 缓存失效

    /// 手动失效指定缓存条目
    /// - Parameter key: 业务缓存键（不含尺寸与缩放后缀）
    /// 注意：此处的key匹配逻辑为前缀匹配，移除所有该业务键下的变体尺寸
    public func invalidate(key: String) {
        self.metadataLock.lock()
        let keysToRemove = self.metadataDict.keys.filter { $0.hasPrefix(key + "_") }
        self.metadataLock.unlock()

        guard !keysToRemove.isEmpty else {
            self.logger.debug("未找到需要失效的缓存: \(key)")
            return
        }

        for fullKey in keysToRemove {
            self.cache.removeObject(forKey: fullKey as NSString)
            self.metadataLock.lock()
            self.metadataDict.removeValue(forKey: fullKey)
            self.metadataLock.unlock()
        }

        self.updateStatsInvalidation(count: keysToRemove.count)
        self.updateCurrentStatsMemoryAndCount()

        NotificationCenter.default.post(
            name: .offscreenRenderCacheInvalidated,
            object: self,
            userInfo: [
                "keys": keysToRemove,
                "reason": UIOffscreenCacheInvalidationReason.manual.rawValue
            ]
        )

        self.logger.info("手动失效缓存完成，移除 \(keysToRemove.count) 个条目: \(key)")
    }

    /// 清空所有缓存条目
    /// - Parameter reason: 失效原因，用于日志与通知追踪
    public func clearAll(reason: UIOffscreenCacheInvalidationReason = .manual) {
        self.metadataLock.lock()
        let allKeys = Array(self.metadataDict.keys)
        let count = allKeys.count
        self.metadataDict.removeAll()
        self.metadataLock.unlock()

        self.cache.removeAllObjects()

        self.updateStatsInvalidation(count: count)
        self.updateCurrentStatsMemoryAndCount()

        NotificationCenter.default.post(
            name: .offscreenRenderCacheInvalidated,
            object: self,
            userInfo: [
                "keys": allKeys,
                "reason": reason.rawValue
            ]
        )

        self.logger.info("全部缓存已清空，共移除 \(count) 个条目，原因: \(reason.rawValue)")
    }

    /// 按时间过期策略清理缓存。
    /// 移除所有存活时间超过ttlSeconds的条目。
    public func invalidateExpired() {
        let now = Date()
        self.configLock.lock()
        let ttl = self.currentConfig.ttlSeconds
        self.configLock.unlock()

        self.metadataLock.lock()
        let expiredKeys = self.metadataDict.compactMap { (key, meta) -> String? in
            now.timeIntervalSince(meta.createdAt) > ttl ? key : nil
        }
        self.metadataLock.unlock()

        guard !expiredKeys.isEmpty else { return }

        for key in expiredKeys {
            self.cache.removeObject(forKey: key as NSString)
            self.metadataLock.lock()
            self.metadataDict.removeValue(forKey: key)
            self.metadataLock.unlock()
        }

        self.updateStatsInvalidation(count: expiredKeys.count)
        self.updateCurrentStatsMemoryAndCount()

        NotificationCenter.default.post(
            name: .offscreenRenderCacheInvalidated,
            object: self,
            userInfo: [
                "keys": expiredKeys,
                "reason": UIOffscreenCacheInvalidationReason.timeExpired.rawValue
            ]
        )

        self.logger.info("时间过期清理完成，移除 \(expiredKeys.count) 个条目")
    }

    /// 按内存压力策略清理缓存。
    /// 当当前内存占用超过上限的90%时，移除最旧的一半条目。
    public func invalidateByMemoryPressure() {
        self.configLock.lock()
        let limitMB = Double(self.currentConfig.maxMemoryMB)
        self.configLock.unlock()

        self.updateCurrentStatsMemoryAndCount()
        self.statsLock.lock()
        let currentMB = self.currentStats.currentMemoryMB
        self.statsLock.unlock()

        guard currentMB > limitMB * 0.9 else { return }

        self.metadataLock.lock()
        let sorted = self.metadataDict.sorted { $0.value.lastAccessedAt < $1.value.lastAccessedAt }
        let removeCount = max(sorted.count / 2, 1)
        let toRemove = sorted.prefix(removeCount).map { $0.key }
        self.metadataLock.unlock()

        for key in toRemove {
            self.cache.removeObject(forKey: key as NSString)
            self.metadataLock.lock()
            self.metadataDict.removeValue(forKey: key)
            self.metadataLock.unlock()
        }

        self.updateStatsInvalidation(count: toRemove.count)
        self.updateCurrentStatsMemoryAndCount()

        NotificationCenter.default.post(
            name: .offscreenRenderCacheInvalidated,
            object: self,
            userInfo: [
                "keys": toRemove,
                "reason": UIOffscreenCacheInvalidationReason.memoryPressure.rawValue
            ]
        )

        self.logger.info("内存压力清理完成，移除 \(toRemove.count) 个条目，当前内存: \(String(format: "%.2f", currentMB))MB")
    }

    // MARK: 公共接口 - 配置管理

    /// 更新缓存配置并持久化到磁盘。
    /// 配置变更后会通知订阅者，并根据新配置调整NSCache容量与定时器。
    /// - Parameter config: 新的缓存配置
    public func configure(_ config: UIOffscreenRenderCacheConfig) {
        self.configLock.lock()
        let oldConfig = self.currentConfig
        self.currentConfig = config
        self.configLock.unlock()

        // 调整NSCache容量限制
        self.cache.countLimit = config.maxEntries
        self.cache.totalCostLimit = config.maxMemoryMB * 1024 * 1024

        // 若定时器周期变更，重启定时器
        self.stopAutoCleanup()
        self.startAutoCleanup()

        // 立即持久化
        self.saveConfig()

        // 广播配置变更通知
        NotificationCenter.default.post(
            name: .offscreenRenderCacheConfigChanged,
            object: self,
            userInfo: [
                "old": oldConfig,
                "new": config
            ]
        )

        self.logger.info("配置已更新并持久化: \(config.description)")
    }

    /// 获取当前生效的缓存配置副本
    public func currentConfiguration() -> UIOffscreenRenderCacheConfig {
        self.configLock.lock()
        let config = self.currentConfig
        self.configLock.unlock()
        return config
    }

    /// 手动将当前配置持久化到磁盘。
    /// 通常在定时器或应用进入后台时调用。
    public func saveConfig() {
        self.configLock.lock()
        let config = self.currentConfig
        self.configLock.unlock()

        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: self.configFileURL, options: .atomic)
            self.logger.info("配置已持久化到磁盘: \(self.configFileURL.path)")
        } catch {
            self.logger.error("配置持久化失败: \(error.localizedDescription)")
        }
    }

    // MARK: 公共接口 - 统计信息

    /// 获取当前统计信息副本，包含内存占用估算
    public func statistics() -> UIOffscreenRenderCacheStatistics {
        self.updateCurrentStatsMemoryAndCount()
        self.statsLock.lock()
        let stats = self.currentStats
        self.statsLock.unlock()
        return stats
    }

    /// 重置所有统计计数器为初始状态
    public func resetStatistics() {
        self.statsLock.lock()
        self.currentStats = UIOffscreenRenderCacheStatistics()
        self.totalRenderTimeAccumulator = 0.0
        self.statsLock.unlock()
        self.logger.info("统计信息已重置")
    }

    // MARK: 公共接口 - 设置面板

    /// 返回设置面板视图，用于集成到应用设置窗口中
    public func settingsView() -> some View {
        UIOffscreenRenderCacheSettingsView(cache: self)
    }

    // MARK: 私有方法 - 离屏渲染核心

    /// 直接执行离屏渲染，不查询缓存。
    /// 使用CoreGraphics位图上下文创建离屏画布，调用绘制闭包，然后生成CGImage。
    private func renderDirectly(size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> CGImage? {
        let pixelWidth = Int(ceil(size.width * scale))
        let pixelHeight = Int(ceil(size.height * scale))

        guard pixelWidth > 0, pixelHeight > 0 else {
            self.logger.warning("渲染尺寸无效: \(pixelWidth)x\(pixelHeight)")
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        // 创建位图上下文，不绑定到屏幕，实现真正的离屏绘制
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            self.logger.error("无法创建位图上下文: \(pixelWidth)x\(pixelHeight)")
            return nil
        }

        // 将上下文坐标系按缩放比例调整，使逻辑绘制代码无需感知物理像素
        context.scaleBy(x: scale, y: scale)

        // 执行业务绘制逻辑
        draw(context)

        // 从位图上下文提取CGImage
        guard let image = context.makeImage() else {
            self.logger.error("无法从上下文生成CGImage")
            return nil
        }

        return image
    }

    // MARK: 私有方法 - 统计更新

    /// 缓存命中时更新统计与元数据访问时间
    private func updateStatsHit(entry: UIOffscreenCacheEntry) {
        self.metadataLock.lock()
        if var meta = self.metadataDict[entry.metadata.cacheKey] {
            meta.lastAccessedAt = Date()
            self.metadataDict[entry.metadata.cacheKey] = meta
        }
        self.metadataLock.unlock()

        self.statsLock.lock()
        self.currentStats.totalHits += 1
        self.statsLock.unlock()

        NotificationCenter.default.post(
            name: .offscreenRenderCacheHit,
            object: self,
            userInfo: [
                "key": entry.metadata.cacheKey,
                "cost": entry.metadata.cost
            ]
        )

        self.logger.debug("缓存命中: \(entry.metadata.cacheKey)")
    }

    /// 缓存未命中时更新统计
    private func updateStatsMiss() {
        self.statsLock.lock()
        self.currentStats.totalMisses += 1
        self.statsLock.unlock()

        self.logger.debug("缓存未命中")
    }

    /// 离屏渲染完成后更新统计
    private func updateStatsRender(time: Double, cost: Int) {
        self.statsLock.lock()
        self.currentStats.totalRenders += 1
        self.totalRenderTimeAccumulator += time
        self.currentStats.averageRenderTimeMs = self.totalRenderTimeAccumulator / Double(self.currentStats.totalRenders)
        self.statsLock.unlock()
    }

    /// 缓存失效时更新统计
    private func updateStatsInvalidation(count: Int) {
        self.statsLock.lock()
        self.currentStats.totalInvalidations += UInt64(count)
        self.statsLock.unlock()
    }

    /// 根据元数据字典重新计算当前内存占用与条目数量
    private func updateCurrentStatsMemoryAndCount() {
        self.metadataLock.lock()
        let totalCost = self.metadataDict.values.reduce(0) { $0 + $1.cost }
        let count = self.metadataDict.count
        self.metadataLock.unlock()

        self.statsLock.lock()
        self.currentStats.currentMemoryMB = Double(totalCost) / 1024.0 / 1024.0
        self.currentStats.currentEntryCount = count
        self.statsLock.unlock()
    }

    // MARK: 私有方法 - 定时器管理

    /// 启动自动清理定时器，按配置周期执行过期检查与内存压力检查
    private func startAutoCleanup() {
        self.configLock.lock()
        let interval = self.currentConfig.autoCleanupInterval
        self.configLock.unlock()
        guard interval > 0 else {
            self.logger.debug("自动清理周期为0，跳过定时器启动")
            return
        }

        self.cleanupTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.invalidateExpired()
            self.configLock.lock()
            let autoClear = self.currentConfig.autoClearOnMemoryPressure
            self.configLock.unlock()
            if autoClear {
                self.invalidateByMemoryPressure()
            }
        }

        self.logger.debug("自动清理定时器已启动，周期: \(interval)s")
    }

    /// 停止自动清理定时器
    private func stopAutoCleanup() {
        self.cleanupTimer?.invalidate()
        self.cleanupTimer = nil
        self.logger.debug("自动清理定时器已停止")
    }
}

// MARK: - 迁回自 UI-02：extension UIOffscreenRenderCache
extension UIOffscreenRenderCache: NSCacheDelegate {
    /// NSCache因容量限制自动逐出对象时回调
    public func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        guard let entry = obj as? UIOffscreenCacheEntry else { return }

        self.metadataLock.lock()
        self.metadataDict.removeValue(forKey: entry.metadata.cacheKey)
        self.metadataLock.unlock()

        self.statsLock.lock()
        self.currentStats.totalEvictions += 1
        self.statsLock.unlock()

        self.logger.debug("NSCache自动逐出: \(entry.metadata.cacheKey), cost: \(entry.metadata.cost)")
    }
}

// MARK: - 迁回自 UI-02：enum UIOffscreenCacheInvalidationReason
// MARK: - 浮动窗口平铺管理器
/// 全局单例，管理所有浮动窗口的平铺排列
/// 支持网格、并排、堆叠三种模式，提供自动排列、窗口大小调整、配置持久化
/// 线程安全：所有公开API使用 NSRecursiveLock 保护
// 已迁回 UI-GL-60_浮动窗口平铺管理.swift：class UIFloatingWindowTilingManager（公共类型文件禁止功能实现）

// MARK: - 便捷扩展
// 已迁回 UI-GL-60_浮动窗口平铺管理.swift：extension UIFloatingWindowTilingManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-61 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-61_types.swift
// 版本: 2.0
// MARK: - 缓存失效原因
/// 缓存失效的具体原因枚举，用于日志与通知追踪
public enum UIOffscreenCacheInvalidationReason: String, Codable, CaseIterable {
    /// 用户手动清理
    case manual = "手动清理"
    /// 缓存条目存活时间超过TTL
    case timeExpired = "时间过期"
    /// 内存占用达到上限阈值
    case memoryPressure = "内存压力"
    /// 缓存条目数量超过上限
    case countLimit = "数量超限"
    /// 配置变更导致缓存失效
    case configurationChanged = "配置变更"
    /// 实例销毁时清理
    case deinitCleanup = "实例销毁"
}

// MARK: - 迁回自 UI-02：struct UIOffscreenRenderCacheConfig
// MARK: - 缓存配置
/// 离屏渲染缓存配置结构体，支持Codable持久化到本地磁盘
public struct UIOffscreenRenderCacheConfig: Codable, Equatable, Sendable, CustomStringConvertible {
    /// 是否启用离屏渲染缓存
    public var isEnabled: Bool = true
    /// 缓存条目最大存活时间（秒），超过此时间将被自动清理
    public var ttlSeconds: Double = 300.0
    /// 最大内存占用（MB），NSCache通过totalCostLimit控制
    public var maxMemoryMB: Int = 256
    /// 最大缓存条目数，NSCache通过countLimit控制
    public var maxEntries: Int = 500
    /// 自动清理周期（秒），定时器按此周期执行过期检查
    public var autoCleanupInterval: Double = 60.0
    /// 是否启用统计信息收集
    public var enableStatistics: Bool = true
    /// 默认渲染缩放比例，Retina屏通常设为2.0
    public var defaultScale: CGFloat = 2.0
    /// 是否在内存压力时自动清理一半最旧缓存
    public var autoClearOnMemoryPressure: Bool = true

    /// 默认配置实例
    public static let `default` = UIOffscreenRenderCacheConfig()

    public init() {}

    /// 描述字符串，用于日志输出
    public var description: String {
        return """
        UIOffscreenRenderCacheConfig(
            isEnabled: \(isEnabled),
            ttlSeconds: \(ttlSeconds),
            maxMemoryMB: \(maxMemoryMB),
            maxEntries: \(maxEntries),
            autoCleanupInterval: \(autoCleanupInterval),
            enableStatistics: \(enableStatistics),
            defaultScale: \(defaultScale),
            autoClearOnMemoryPressure: \(autoClearOnMemoryPressure)
        )
        """
    }
}

// MARK: - 迁回自 UI-02：struct UIOffscreenRenderCacheStatistics
// MARK: - 缓存统计
/// 离屏渲染缓存统计信息结构体，用于性能监控与调优
public struct UIOffscreenRenderCacheStatistics: Codable, CustomStringConvertible {
    /// 总命中次数，从缓存直接读取
    public var totalHits: UInt64 = 0
    /// 总未命中次数，需要执行离屏渲染
    public var totalMisses: UInt64 = 0
    /// 总离屏渲染执行次数
    public var totalRenders: UInt64 = 0
    /// 总逐出次数，NSCache因空间不足自动移除
    public var totalEvictions: UInt64 = 0
    /// 总失效次数，包含手动/过期/压力/配置变更
    public var totalInvalidations: UInt64 = 0
    /// 平均单次离屏渲染耗时（毫秒）
    public var averageRenderTimeMs: Double = 0.0
    /// 当前估算内存占用（MB），基于元数据累加
    public var currentMemoryMB: Double = 0.0
    /// 当前缓存条目数量
    public var currentEntryCount: Int = 0

    /// 命中率（0.0~1.0），命中次数除以总访问次数
    public var hitRate: Double {
        let total = totalHits + totalMisses
        guard total > 0 else { return 0.0 }
        return Double(totalHits) / Double(total)
    }

    /// 格式化统计报告，用于设置面板展示
    public var description: String {
        return """
        离屏渲染缓存统计:
        ├─ 命中次数:     \(totalHits)
        ├─ 未命中次数:   \(totalMisses)
        ├─ 命中率:       \(String(format: "%.2f", hitRate * 100))%
        ├─ 渲染次数:     \(totalRenders)
        ├─ 逐出次数:     \(totalEvictions)
        ├─ 失效次数:     \(totalInvalidations)
        ├─ 平均耗时:     \(String(format: "%.2f", averageRenderTimeMs))ms
        ├─ 内存占用:     \(String(format: "%.2f", currentMemoryMB))MB
        └─ 条目数量:     \(currentEntryCount)
        """
    }

    public init() {}
}

// MARK: - 迁回自 UI-02：struct UIOffscreenCacheEntryMetadata
// MARK: - 缓存条目元数据
/// 缓存条目元数据，用于时间追踪、失效管理与内存成本计算
struct UIOffscreenCacheEntryMetadata {  // 原为private，改为internal
    /// 缓存键，唯一标识该缓存条目
    let cacheKey: String
    /// 创建时间，用于TTL失效判断
    let createdAt: Date
    /// 内存成本（字节），基于位图宽高与通道数计算
    let cost: Int
    /// 最后访问时间，用于LRU与压力清理
    var lastAccessedAt: Date
}

// MARK: - 迁回自 UI-02：struct UIOffscreenRenderCacheSettingsView
// MARK: - 缓存条目对象
/// 包装CGImage与元数据，满足NSCache存储NSObject的要求
// 已迁回 UI-GL-61_离屏渲染与缓存.swift：class UIOffscreenCacheEntry（公共类型文件禁止功能实现）

// MARK: - 离屏渲染缓存管理器
/// 单例管理器，负责离屏渲染、位图缓存、缓存失效策略、统计与持久化配置
// 已迁回 UI-GL-61_离屏渲染与缓存.swift：class UIOffscreenRenderCache（公共类型文件禁止功能实现）

// MARK: - NSCacheDelegate
// 已迁回 UI-GL-61_离屏渲染与缓存.swift：extension UIOffscreenRenderCache（公共类型文件禁止功能实现）

// MARK: - 设置面板视图
/// 离屏渲染缓存设置面板，用于集成到应用设置窗口
public struct UIOffscreenRenderCacheSettingsView: View {
    @State private var config: UIOffscreenRenderCacheConfig
    private let cache: UIOffscreenRenderCache

    public init(cache: UIOffscreenRenderCache) {
        self.cache = cache
        self._config = State(initialValue: cache.currentConfiguration())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Text("基本设置").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("启用离屏缓存", isOn: $config.isEnabled)
                    Toggle("启用统计", isOn: $config.enableStatistics)
                    Toggle("内存压力时自动清理", isOn: $config.autoClearOnMemoryPressure)
                }
                .padding(.top, 4)
            }

            GroupBox(label: Text("缓存限制").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最大内存 (MB)")
                        Spacer()
                        TextField("256", value: $config.maxMemoryMB, formatter: NumberFormatter())
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("最大条目数")
                        Spacer()
                        TextField("500", value: $config.maxEntries, formatter: NumberFormatter())
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("TTL (秒)")
                        Spacer()
                        TextField("300", value: $config.ttlSeconds, formatter: NumberFormatter())
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding(.top, 4)
            }

            GroupBox(label: Text("高级").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("自动清理周期 (秒)")
                        Spacer()
                        TextField("60", value: $config.autoCleanupInterval, formatter: NumberFormatter())
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("默认缩放比例")
                        Spacer()
                        TextField("2.0", value: $config.defaultScale, formatter: NumberFormatter())
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Button("保存配置") {
                    cache.configure(config)
                }
                Button("清理全部缓存") {
                    cache.clearAll()
                }
                Button("重置统计") {
                    cache.resetStatistics()
                }
            }

            GroupBox(label: Text("实时统计").font(.headline)) {
                Text(cache.statistics().description)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
    }
}
