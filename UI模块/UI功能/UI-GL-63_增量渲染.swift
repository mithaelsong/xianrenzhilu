// 功能53: 增量渲染
// 对应: K线数据更新时只渲染新增或变化的部分，避免全量重绘，大幅提升性能
// 优先级: P2

import AppKit
import Foundation
import os.log
private let rendererLogger = Logger(subsystem: "com.xianrenzhilu.ui", category: "ui-gl-63")

// 类型定义已迁移至 /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-63_types.swift


// MARK: - 测试代码
#if false // DEBUG tests disabled in App target

/// 功能53：增量渲染 — 单元测试
func test_incrementalRender() {
    let renderer = UIIncrementalRenderer.shared
    
    logger.info("测试1: 默认配置")
    let config = renderer.getConfiguration()
    if config.enableIncrementalRender { logger.info("✅ 测试1通过") }
    else { logger.error("❌ 测试1失败") }
    
    logger.info("测试2: 提交脏区域")
    renderer.submitDirtyRect(NSRect(x: 0, y: 0, width: 100, height: 100), source: "test")
    let rects = renderer.getMergedDirtyRects()
    if rects.count >= 1 { logger.info("✅ 测试2通过: \(rects.count)个区域") }
    else { logger.error("❌ 测试2失败") }
    
    logger.info("测试3: 批量提交")
    renderer.submitDirtyRects([
        NSRect(x: 10, y: 10, width: 50, height: 50),
        NSRect(x: 200, y: 200, width: 100, height: 100)
    ], source: "test_batch")
    let merged = renderer.getMergedDirtyRects()
    _ = merged
    logger.info("✅ 测试3通过")
    
    logger.info("测试4: 增量渲染")
    renderer.triggerIncrementalRender()
    logger.info("✅ 测试4通过")
    
    logger.info("测试5: 全量重绘")
    renderer.triggerFullRedraw()
    logger.info("✅ 测试5通过")
    
    logger.info("测试6: 配置更新")
    var newConfig = config
    newConfig.enableIncrementalRender = false
    renderer.updateConfiguration(newConfig)
    let updated = renderer.getConfiguration()
    if !updated.enableIncrementalRender { logger.info("✅ 测试6通过") }
    else { logger.error("❌ 测试6失败") }
    
    logger.info("测试7: 恢复默认")
    renderer.resetConfigurationToDefaults()
    let reset = renderer.getConfiguration()
    if reset.enableIncrementalRender { logger.info("✅ 测试7通过") }
    else { logger.error("❌ 测试7失败") }
    
    logger.info("测试8: 统计信息")
    let stats = renderer.getStatistics()
    _ = stats
    logger.info("✅ 测试8通过")
    
    logger.info("=== 全部增量渲染测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 脏区域提交通知：有新的脏区域被提交到渲染器
    /// userInfo包含: ["rects": [NSRect], "source": String, "count": Int]
    static let incrementalRendererDirtyRectsSubmitted = Notification.Name("UIIncrementalRendererDirtyRectsSubmitted")
    
    /// 渲染开始通知：增量渲染任务开始执行
    /// userInfo包含: ["rects": [NSRect], "queueSize": Int, "timestamp": Date]
    static let incrementalRendererRenderStarted = Notification.Name("UIIncrementalRendererRenderStarted")
    
    /// 渲染完成通知：增量渲染任务执行完毕
    /// userInfo包含: ["rects": [NSRect], "durationMs": Double, "isFullRedraw": Bool]
    static let incrementalRendererRenderCompleted = Notification.Name("UIIncrementalRendererRenderCompleted")
    
    /// 设置变更通知：用户通过设置面板修改了渲染配置
    /// userInfo包含: ["oldConfig": UIIncrementalRenderConfiguration, "newConfig": UIIncrementalRenderConfiguration]
    static let incrementalRendererSettingsChanged = Notification.Name("UIIncrementalRendererSettingsChanged")
}

// MARK: - 迁回自 UI-02：class UIIncrementalRenderer
public final class UIIncrementalRenderer : @unchecked Sendable {
    
    // MARK: 单例
    /// 全局唯一实例，整个App生命周期内共享状态与队列
    public static let shared = UIIncrementalRenderer()
    
    // MARK: 私有属性
    /// OSLog日志器，替代print，支持分级日志与系统日志收集
    private let logger: Logger
    
    /// 递归锁，用于保护所有共享可变状态
    /// NSRecursiveLock 支持递归调用场景
    private let lock = NSRecursiveLock()
    
    /// 当前累积的脏区域列表，受lock保护
    private var dirtyRectEntries: [UIDirtyRectEntry]
    
    /// 等待执行的渲染队列，受lock保护
    private var renderQueue: [UIRenderQueueEntry]
    
    /// 当前渲染配置，受lock保护
    private var configuration: UIIncrementalRenderConfiguration
    
    /// 是否正在执行渲染中，用于防止重复渲染，受lock保护
    private var isRendering: Bool
    
    /// 聚合定时器：延迟一小段时间后将脏区域合并并触发渲染
    private var coalesceTimer: Timer?
    
    /// 统计信息，受lock保护
    private var statistics: UIRenderStatistics
    
    /// 最后一次渲染完成时间，受lock保护
    private var lastRenderTime: Date?
    
    /// 唯一标识符，用于区分多个实例（虽然当前是单例）
    private let instanceId: UUID
    
    /// 渲染队列专用串行调度队列，保证线程安全
    private let renderDispatchQueue: DispatchQueue
    
    /// 观察者令牌：监听应用进入前台/后台通知，用于暂停/恢复渲染
    private var appStateObservers: [NSObjectProtocol]
    
    // MARK: 初始化
    /// 私有构造器，强制通过单例访问
    private init() {
        // 锁初始化在声明时已完成（NSRecursiveLock）
        self.dirtyRectEntries = []
        self.renderQueue = []
        self.configuration = UIIncrementalRenderConfiguration.loadFromDefaults()
        self.isRendering = false
        self.statistics = UIRenderStatistics()
        self.lastRenderTime = nil
        self.instanceId = UUID()
        self.logger = Logger(subsystem: "com.xianrenzhilu.incremental", category: "UIIncrementalRenderer-\(self.instanceId.uuidString.prefix(8))")
        self.renderDispatchQueue = DispatchQueue(label: "com.xianrenzhilu.incremental.render", qos: .userInteractive)
        self.appStateObservers = []
        
        rendererLogger.info("【增量渲染器】初始化完成，实例ID: \(self.instanceId.uuidString)")
        
        // 注册应用状态监听，进入后台时清理队列，回到前台时重置状态
        self.registerAppStateObservers()
    }
    
    // MARK: deinit 清理
    /// 清理所有资源：定时器、观察者、队列、脏区域，防止内存泄漏与后台残留任务
    deinit {
        // 停止聚合定时器
        coalesceTimer?.invalidate()
        coalesceTimer = nil
        
        // 移除应用状态观察者
        for observer in appStateObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        appStateObservers.removeAll()
        
        // 加锁清理共享数据
        lock.lock()
        dirtyRectEntries.removeAll()
        renderQueue.removeAll()
        isRendering = false
        lock.unlock()
        
        logger.info("【增量渲染器】实例已销毁，资源全部清理")
    }
    
    // MARK: 应用状态监听
    /// 注册应用前后台切换通知，用于智能管理渲染队列
    private func registerAppStateObservers() {
        // 进入后台：取消所有待渲染任务，节省CPU
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cancelAllPendingRenders()
            self?.logger.info("【增量渲染器】应用进入后台，已取消所有待渲染任务")
        }
        
        // 进入前台：重置状态，准备接收新渲染任务
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetRenderState()
            self?.logger.info("【增量渲染器】应用进入前台，渲染状态已重置")
        }
        
        appStateObservers.append(backgroundObserver)
        appStateObservers.append(foregroundObserver)
    }
    
    // MARK: 脏区域管理 — 提交单个脏区域
    /// 提交一个脏区域到渲染器，等待聚合后统一渲染
    /// - Parameters:
    ///   - rect: 需要重绘的矩形区域（视图坐标系）
    ///   - source: 来源标识，例如"KLineView"、"VolumeCanvas"，用于调试追踪
    ///   - priority: 优先级，0最低10最高，高优先级任务不会被丢弃
    public func submitDirtyRect(_ rect: NSRect, source: String, priority: Int = 5) {
        // 忽略空区域或无效区域
        guard !rect.isEmpty, rect.width > 0, rect.height > 0 else {
            logger.debug("【脏区域】提交被忽略，区域为空或无效: \(String(describing: rect)), 来源: \(source)")
            return
        }
        
        lock.lock()
        
        // 如果增量渲染被禁用，直接标记为需要全量重绘，不缓存脏区域
        if !configuration.enableIncrementalRender {
            lock.unlock()
            triggerFullRedraw()
            logger.info("【脏区域】增量渲染已禁用，触发全量重绘，来源: \(source)")
            return
        }
        
        // 检查脏区域数量是否超限，超限则触发合并
        if dirtyRectEntries.count >= configuration.maxDirtyRects {
            let rectsBeforeMerge = dirtyRectEntries.count
            let merged = performRectMerge(entries: dirtyRectEntries)
            dirtyRectEntries = merged
            let rectsAfterMerge = dirtyRectEntries.count
            let saved = rectsBeforeMerge - rectsAfterMerge
            statistics.rectsSavedByMerge += saved
            logger.info("【脏区域】缓存超限，自动合并: \(rectsBeforeMerge) → \(rectsAfterMerge) 个区域，节省 \(saved) 个")
        }
        
        // 创建脏区域条目并加入缓存
        let entry = UIDirtyRectEntry(
            rect: rect,
            priority: max(0, min(10, priority)),
            timestamp: Date(),
            source: source,
            id: UUID()
        )
        dirtyRectEntries.append(entry)
        statistics.totalDirtyRectsSubmitted += 1
        
        let currentCount = dirtyRectEntries.count
        lock.unlock()
        
        logger.info("【脏区域】提交成功: \(String(describing: rect)) | 来源: \(source) | 优先级: \(priority) | 当前缓存: \(currentCount) 个")
        
        // 发送脏区域提交通知，通知外部模块有新区域需要重绘
        NotificationCenter.default.post(
            name: .incrementalRendererDirtyRectsSubmitted,
            object: self,
            userInfo: [
                "rects": [rect],
                "source": source,
                "count": currentCount,
                "priority": priority
            ]
        )
        
        // 启动聚合定时器，延迟触发渲染，以合并短时间内的大量提交
        scheduleCoalesceRender()
    }
    
    // MARK: 脏区域管理 — 批量提交
    /// 批量提交多个脏区域，减少锁竞争，适合K线数据批量更新场景
    /// - Parameters:
    ///   - rects: 需要重绘的矩形区域数组
    ///   - source: 来源标识
    public func submitDirtyRects(_ rects: [NSRect], source: String) {
        // 过滤无效区域
        let validRects = rects.filter { !$0.isEmpty && $0.width > 0 && $0.height > 0 }
        guard !validRects.isEmpty else {
            logger.debug("【脏区域】批量提交被忽略，所有区域无效，来源: \(source)")
            return
        }
        
        lock.lock()
        
        if !configuration.enableIncrementalRender {
            lock.unlock()
            triggerFullRedraw()
            logger.info("【脏区域】批量提交时增量渲染已禁用，触发全量重绘，来源: \(source)")
            return
        }
        
        // 如果单次提交数量超过全量阈值，直接触发全量重绘
        if validRects.count >= configuration.fullRedrawThreshold {
            lock.unlock()
            triggerFullRedraw()
            logger.info("【脏区域】批量提交数量(\(validRects.count))超过全量阈值(\(self.configuration.fullRedrawThreshold))，触发全量重绘")
            return
        }
        
        let now = Date()
        for rect in validRects {
            let entry = UIDirtyRectEntry(
                rect: rect,
                priority: 5,
                timestamp: now,
                source: source,
                id: UUID()
            )
            dirtyRectEntries.append(entry)
        }
        statistics.totalDirtyRectsSubmitted += validRects.count
        let currentCount = dirtyRectEntries.count
        lock.unlock()
        
        logger.info("【脏区域】批量提交成功: \(validRects.count) 个区域 | 来源: \(source) | 当前缓存: \(currentCount) 个")
        
        NotificationCenter.default.post(
            name: .incrementalRendererDirtyRectsSubmitted,
            object: self,
            userInfo: [
                "rects": validRects,
                "source": source,
                "count": currentCount,
                "priority": 5
            ]
        )
        
        scheduleCoalesceRender()
    }
    
    // MARK: 区域合并算法 — 核心合并
    /// 对脏区域条目执行合并：先合并重叠区域，再合并相邻区域
    /// - Parameter entries: 待合并的脏区域条目
    /// - Returns: 合并后的脏区域条目列表（条目数量减少，但覆盖范围不变或扩大）
    private func performRectMerge(entries: [UIDirtyRectEntry]) -> [UIDirtyRectEntry] {
        lock.lock()
        let mergeEnabled = configuration.enableRectMerge
        let mergeThreshold = configuration.mergeThreshold
        lock.unlock()
        guard mergeEnabled, entries.count > 1 else {
            return entries
        }
        
        // 第一步：提取所有rect并进行重叠合并
        var rects = entries.map { $0.rect }
        rects = mergeOverlappingRects(rects)
        
        // 第二步：对相邻区域进行合并（使用配置中的阈值）
        rects = mergeAdjacentRects(rects, threshold: mergeThreshold)
        
        // 第三步：将合并后的rect重新封装为条目（使用最高优先级和最早时间）
        var mergedEntries: [UIDirtyRectEntry] = []
        for rect in rects {
            // 找到原始条目中与此rect相交的所有条目，提取最高优先级和最早时间
            let intersectingEntries = entries.filter { $0.rect.intersects(rect) }
            let maxPriority = intersectingEntries.map { $0.priority }.max() ?? 5
            let earliestTime = intersectingEntries.map { $0.timestamp }.min() ?? Date()
            let sources = intersectingEntries.map { $0.source }.joined(separator: ",")
            
            mergedEntries.append(UIDirtyRectEntry(
                rect: rect,
                priority: maxPriority,
                timestamp: earliestTime,
                source: sources,
                id: UUID()
            ))
        }
        
        return mergedEntries
    }
    
    // MARK: 区域合并算法 — 重叠区域合并
    /// 合并所有互相重叠或包含的矩形，直到没有重叠为止
    /// 使用贪心算法：遍历所有矩形对，合并重叠的，循环直到不再减少
    /// - Parameter rects: 原始矩形数组
    /// - Returns: 合并重叠后的矩形数组
    private func mergeOverlappingRects(_ rects: [NSRect]) -> [NSRect] {
        guard rects.count > 1 else { return rects }
        
        var result = rects
        var didMerge = true
        
        while didMerge && result.count > 1 {
            didMerge = false
            var newResult: [NSRect] = []
            var merged: [Bool] = Array(repeating: false, count: result.count)
            
            for i in 0..<result.count {
                if merged[i] { continue }
                var current = result[i]
                
                for j in (i + 1)..<result.count {
                    if merged[j] { continue }
                    let other = result[j]
                    
                    // 如果两个矩形重叠或包含，合并为最小包围矩形
                    if current.intersects(other) || current.contains(other) || other.contains(current) {
                        current = current.union(other)
                        merged[j] = true
                        didMerge = true
                    }
                }
                
                newResult.append(current)
            }
            
            result = newResult
        }
        
        return result
    }
    
    // MARK: 区域合并算法 — 相邻区域合并
    /// 合并间距小于阈值的不重叠矩形，减少渲染调用次数
    /// - Parameters:
    ///   - rects: 已合并重叠后的矩形数组
    ///   - threshold: 相邻判定阈值（像素），小于此间距则合并
    /// - Returns: 合并相邻后的矩形数组
    private func mergeAdjacentRects(_ rects: [NSRect], threshold: CGFloat) -> [NSRect] {
        guard rects.count > 1 else { return rects }
        guard threshold > 0 else { return rects }
        
        var result = rects
        var didMerge = true
        
        while didMerge && result.count > 1 {
            didMerge = false
            var newResult: [NSRect] = []
            var merged: [Bool] = Array(repeating: false, count: result.count)
            
            for i in 0..<result.count {
                if merged[i] { continue }
                var current = result[i]
                
                for j in (i + 1)..<result.count {
                    if merged[j] { continue }
                    let other = result[j]
                    
                    // 判断两矩形是否在阈值内相邻
                    if rectsAreAdjacentOrNear(current, other, threshold: threshold) {
                        current = current.union(other)
                        merged[j] = true
                        didMerge = true
                    }
                }
                
                newResult.append(current)
            }
            
            result = newResult
        }
        
        return result
    }
    
    // MARK: 区域合并算法 — 相邻判定辅助函数
    /// 判断两个矩形是否在阈值范围内相邻或接近（包括水平和垂直方向）
    /// - Parameters:
    ///   - a: 第一个矩形
    ///   - b: 第二个矩形
    ///   - threshold: 判定阈值（像素）
    /// - Returns: true表示在阈值范围内相邻，应合并
    private func rectsAreAdjacentOrNear(_ a: NSRect, _ b: NSRect, threshold: CGFloat) -> Bool {
        // 水平方向：检查x轴间距和y轴重叠度
        let horizontalGap = max(0, max(a.minX - b.maxX, b.minX - a.maxX))
        let verticalOverlap = max(0, min(a.maxY, b.maxY) - max(a.minY, b.minY))
        
        // 垂直方向：检查y轴间距和x轴重叠度
        let verticalGap = max(0, max(a.minY - b.maxY, b.minY - a.maxY))
        let horizontalOverlap = max(0, min(a.maxX, b.maxX) - max(a.minX, b.minX))
        
        // 水平相邻（左右相邻，y轴有重叠）且水平间距小于阈值
        if horizontalGap > 0 && horizontalGap <= threshold && verticalOverlap > 0 {
            return true
        }
        
        // 垂直相邻（上下相邻，x轴有重叠）且垂直间距小于阈值
        if verticalGap > 0 && verticalGap <= threshold && horizontalOverlap > 0 {
            return true
        }
        
        // 如果两矩形本身就重叠（已被前一个函数处理，但防御性保留）
        if a.intersects(b) || a.contains(b) || b.contains(a) {
            return true
        }
        
        return false
    }
    
    // MARK: 获取合并后的脏区域
    /// 获取当前所有脏区域经过合并后的矩形列表，供渲染模块直接调用
    /// - Returns: 合并后的NSRect数组，如果增量渲染被禁用则返回空数组
    public func getMergedDirtyRects() -> [NSRect] {
        lock.lock()
        let entries = dirtyRectEntries
        let enableMerge = configuration.enableRectMerge
        lock.unlock()
        
        guard !entries.isEmpty else { return [] }
        
        let rects = entries.map { $0.rect }
        
        if enableMerge {
            var merged = mergeOverlappingRects(rects)
            merged = mergeAdjacentRects(merged, threshold: configuration.mergeThreshold)
            return merged
        } else {
            return rects
        }
    }
    
    // MARK: 渲染队列管理 — 调度聚合渲染
    /// 启动聚合定时器，在指定时间后将脏区域合并并加入渲染队列
    /// 短时间内多次调用会重置定时器，以达到聚合效果
    private func scheduleCoalesceRender() {
        // 在主线程操作定时器，避免线程安全问题
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 取消已有定时器
            self.coalesceTimer?.invalidate()
            
            // 获取当前配置的聚合间隔
            var interval: TimeInterval = 0.016
            self.lock.lock()
            interval = self.configuration.renderCoalesceInterval
            self.lock.unlock()
            
            // 创建新定时器，到期后将脏区域合并并加入队列
            self.coalesceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.enqueueDirtyRectsForRender()
            }
        }
    }
    
    // MARK: 渲染队列管理 — 将脏区域加入队列
    /// 将当前缓存的脏区域合并后加入渲染队列，等待实际渲染
    /// 如果队列已满，会按优先级丢弃低优先级任务
    private func enqueueDirtyRectsForRender() {
        lock.lock()
        
        let entries = dirtyRectEntries
        let config = configuration
        let isCurrentlyRendering = isRendering
        
        // 清空脏区域缓存（已经取出）
        dirtyRectEntries.removeAll()
        
        lock.unlock()
        
        guard !entries.isEmpty else { return }
        
        // 合并脏区域
        var mergedRects: [NSRect]
        if config.enableRectMerge {
            let mergedEntries = performRectMerge(entries: entries)
            mergedRects = mergedEntries.map { $0.rect }
        } else {
            mergedRects = entries.map { $0.rect }
        }
        
        // 判断是否触发全量重绘：如果合并后区域数量仍然很多，或者覆盖范围太大
        let isFullRedraw = mergedRects.count >= config.fullRedrawThreshold || isLargeCoverage(mergedRects)
        if isFullRedraw {
            mergedRects = [NSRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)]
        }
        
        // 创建渲染队列条目
        let maxPriority = entries.map { $0.priority }.max() ?? 5
        let queueEntry = UIRenderQueueEntry(
            id: UUID(),
            dirtyRects: mergedRects,
            timestamp: Date(),
            isProcessing: false,
            isFullRedraw: isFullRedraw,
            priority: maxPriority
        )
        
        lock.lock()
        
        // 如果已经在渲染中，将任务加入队列
        // 如果队列已满，丢弃低优先级任务
        if renderQueue.count >= config.maxRenderQueueSize {
            // 找到优先级最低且未在处理的条目进行替换
            if let lowestIndex = renderQueue.enumerated().filter({ !$0.element.isProcessing }).min(by: { $0.element.priority < $1.element.priority })?.offset {
                if renderQueue[lowestIndex].priority < queueEntry.priority {
                    let dropped = renderQueue.remove(at: lowestIndex)
                    logger.info("【渲染队列】队列已满，丢弃低优先级任务: \(dropped.id) 优先级:\(dropped.priority)，加入新任务: \(queueEntry.id) 优先级:\(queueEntry.priority)")
                } else {
                    logger.info("【渲染队列】队列已满，新任务优先级不足，丢弃新任务: \(queueEntry.id)")
                    lock.unlock()
                    return
                }
            } else {
                // 所有任务都在处理中，丢弃新任务
                logger.info("【渲染队列】队列已满且所有任务处理中，丢弃新任务: \(queueEntry.id)")
                lock.unlock()
                return
            }
        }
        
        renderQueue.append(queueEntry)
        let currentQueueSize = renderQueue.count
        if currentQueueSize > statistics.peakQueueSize {
            statistics.peakQueueSize = currentQueueSize
        }
        lock.unlock()
        
        logger.info("【渲染队列】任务已加入队列: \(queueEntry.id) | 区域数:\(mergedRects.count) | 全量重绘:\(isFullRedraw) | 队列长度:\(currentQueueSize)")
        
        // 如果当前没有在渲染，立即触发处理
        if !isCurrentlyRendering {
            processRenderQueue()
        }
    }
    
    // MARK: 渲染队列管理 — 处理队列
    /// 串行处理渲染队列中的任务，保证顺序执行，防止重复渲染
    private func processRenderQueue() {
        renderDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 尝试获取队列中的第一个待处理任务
            var entry: UIRenderQueueEntry?
            
            self.lock.lock()
            if let index = self.renderQueue.firstIndex(where: { !$0.isProcessing }) {
                self.renderQueue[index].isProcessing = true
                entry = self.renderQueue[index]
                self.isRendering = true
            }
            self.lock.unlock()
            
            guard let currentEntry = entry else {
                // 没有待处理任务，标记渲染结束
                self.lock.lock()
                self.isRendering = false
                self.lock.unlock()
                return
            }
            
            // 执行实际渲染
            self.performRender(entry: currentEntry)
            
            // 渲染完成后从队列移除
            self.lock.lock()
            self.renderQueue.removeAll { $0.id == currentEntry.id }
            let remainingCount = self.renderQueue.count
            self.lock.unlock()
            
            self.logger.info("【渲染队列】任务完成并从队列移除: \(currentEntry.id) | 剩余任务:\(remainingCount)")
            
            // 如果队列还有任务，继续处理下一个
            if remainingCount > 0 {
                self.processRenderQueue()
            } else {
                self.lock.lock()
                self.isRendering = false
                self.lock.unlock()
            }
        }
    }
    
    // MARK: 增量重绘触发 — 执行渲染
    /// 执行实际的增量渲染操作，记录耗时并发送通知
    /// - Parameter entry: 渲染队列条目，包含脏区域和渲染参数
    private func performRender(entry: UIRenderQueueEntry) {
        let startTime = Date()
        let rects = entry.dirtyRects
        let isFullRedraw = entry.isFullRedraw
        
        logger.info("【渲染开始】任务ID: \(entry.id) | 区域数:\(rects.count) | 全量重绘:\(isFullRedraw)")
        
        // 发送渲染开始通知，供外部模块（如KLineView）监听并执行实际绘制
        lock.lock()
        let queueSize = renderQueue.count
        lock.unlock()
        NotificationCenter.default.post(
            name: .incrementalRendererRenderStarted,
            object: self,
            userInfo: [
                "rects": rects,
                "queueSize": queueSize,
                "timestamp": startTime,
                "taskId": entry.id,
                "isFullRedraw": isFullRedraw
            ]
        )
        
        // 实际渲染逻辑：通知监听者执行绘制，这里不直接操作视图
        // 监听者（如KLineCanvas）收到通知后，会调用setNeedsDisplay(inRect:)或draw(_:)
        // 此处模拟渲染耗时（实际由监听者处理）
        // 对于全量重绘，模拟耗时更长
        let simulatedDuration = isFullRedraw ? 0.008 : 0.002
        Thread.sleep(forTimeInterval: simulatedDuration)
        
        let endTime = Date()
        let durationMs = endTime.timeIntervalSince(startTime) * 1000.0
        
        // 更新统计信息
        lock.lock()
        statistics.totalRenderCount += 1
        if isFullRedraw {
            statistics.fullRedrawCount += 1
        } else {
            statistics.incrementalRenderCount += 1
        }
        statistics.totalMergedRectsRendered += rects.count
        statistics.lastRenderDurationMs = durationMs
        // 更新平均耗时：滑动平均
        let total = Double(statistics.totalRenderCount)
        statistics.averageRenderDurationMs = (statistics.averageRenderDurationMs * (total - 1) + durationMs) / total
        lastRenderTime = endTime
        lock.unlock()
        
        logger.info("【渲染完成】任务ID: \(entry.id) | 耗时: \(String(format: "%.3f", durationMs))ms | 区域数:\(rects.count)")
        
        // 发送渲染完成通知，供性能监控和调试面板使用
        NotificationCenter.default.post(
            name: .incrementalRendererRenderCompleted,
            object: self,
            userInfo: [
                "rects": rects,
                "durationMs": durationMs,
                "isFullRedraw": isFullRedraw,
                "taskId": entry.id,
                "timestamp": endTime
            ]
        )
    }
    
    // MARK: 增量重绘触发 — 手动触发
    /// 外部模块手动触发增量渲染，立即将当前脏区域加入队列并处理
    /// 适用于用户交互（如缩放、拖拽）后需要立即刷新场景
    public func triggerIncrementalRender() {
        logger.info("【手动触发】增量渲染被外部调用触发")
        
        // 取消聚合定时器，立即处理
        DispatchQueue.main.async { [weak self] in
            self?.coalesceTimer?.invalidate()
            self?.coalesceTimer = nil
        }
        
        enqueueDirtyRectsForRender()
    }
    
    // MARK: 增量重绘触发 — 全量重绘
    /// 强制触发全量重绘，忽略所有脏区域缓存，直接渲染整个视图
    /// 适用于配置切换、主题变更、数据大量更新等场景
    public func triggerFullRedraw() {
        logger.info("【全量重绘】强制触发全量重绘")
        
        // 取消聚合定时器
        DispatchQueue.main.async { [weak self] in
            self?.coalesceTimer?.invalidate()
            self?.coalesceTimer = nil
        }
        
        lock.lock()
        dirtyRectEntries.removeAll()
        
        // 创建一个覆盖全屏的渲染任务
        let fullRect = NSRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let queueEntry = UIRenderQueueEntry(
            id: UUID(),
            dirtyRects: [fullRect],
            timestamp: Date(),
            isProcessing: false,
            isFullRedraw: true,
            priority: 10
        )
        renderQueue.append(queueEntry)
        let currentQueueSize = renderQueue.count
        if currentQueueSize > statistics.peakQueueSize {
            statistics.peakQueueSize = currentQueueSize
        }
        let isCurrentlyRendering = isRendering
        lock.unlock()
        
        logger.info("【全量重绘】全量任务已加入队列: \(queueEntry.id) | 队列长度:\(currentQueueSize)")
        
        if !isCurrentlyRendering {
            processRenderQueue()
        }
    }
    
    // MARK: 渲染队列管理 — 取消所有待渲染
    /// 取消所有未开始处理的渲染任务，保留正在处理的任务
    /// 适用于应用进入后台、视图不可见、需要紧急清理等场景
    public func cancelAllPendingRenders() {
        lock.lock()
        let beforeCount = renderQueue.count
        // 只保留正在处理的任务
        renderQueue.removeAll { !$0.isProcessing }
        let afterCount = renderQueue.count
        lock.unlock()
        
        // 取消聚合定时器，防止后续脏区域触发渲染
        DispatchQueue.main.async { [weak self] in
            self?.coalesceTimer?.invalidate()
            self?.coalesceTimer = nil
        }
        
        logger.info("【取消渲染】已取消 \(beforeCount - afterCount) 个待处理任务，保留 \(afterCount) 个处理中任务")
    }
    
    // MARK: 脏区域管理 — 清空所有脏区域
    /// 清空所有已缓存但尚未渲染的脏区域，不取消队列中的渲染任务
    /// 适用于数据重置、视图即将销毁但不需要立即渲染的场景
    public func clearAllDirtyRects() {
        lock.lock()
        let count = dirtyRectEntries.count
        dirtyRectEntries.removeAll()
        lock.unlock()
        
        logger.info("【清空脏区域】已清空 \(count) 个缓存的脏区域")
    }
    
    // MARK: 辅助方法 — 覆盖范围判定
    /// 判断一组矩形覆盖的总面积是否过大，过大则建议全量重绘
    /// - Parameter rects: 矩形数组
    /// - Returns: true表示覆盖面积过大，应使用全量重绘
    private func isLargeCoverage(_ rects: [NSRect]) -> Bool {
        guard rects.count > 1 else { return false }
        
        // 计算所有矩形的并集面积
        var unionRect = rects[0]
        for rect in rects.dropFirst() {
            unionRect = unionRect.union(rect)
        }
        
        // 计算各个矩形面积之和
        var totalArea: CGFloat = 0
        for rect in rects {
            totalArea += rect.width * rect.height
        }
        
        // 如果各个矩形面积之和远大于并集面积，说明重叠严重，增量渲染收益不大
        // 或者如果并集面积本身很大，也建议全量重绘
        let unionArea = unionRect.width * unionRect.height
        
        // 阈值：如果覆盖面积超过某个大值（模拟屏幕面积），建议全量重绘
        let screenArea: CGFloat = 4096 * 4096  // 假设4K屏幕面积
        if unionArea > screenArea * 0.5 {
            return true
        }
        
        // 如果矩形数量很多且重叠严重（面积和 > 并集面积 * 2），增量收益低
        if totalArea > unionArea * 2.0 && rects.count > 10 {
            return true
        }
        
        return false
    }
    
    // MARK: 设置面板方法 — 获取配置
    /// 供设置面板读取当前渲染配置
    /// - Returns: 当前增量渲染配置副本
    public func getConfiguration() -> UIIncrementalRenderConfiguration {
        lock.lock()
        let config = configuration
        lock.unlock()
        return config
    }
    
    // MARK: 设置面板方法 — 更新配置
    /// 供设置面板实时修改渲染配置，修改后立即生效
    /// - Parameter config: 新的配置，将覆盖旧配置并持久化到UserDefaults
    public func updateConfiguration(_ config: UIIncrementalRenderConfiguration) {
        lock.lock()
        let oldConfig = configuration
        configuration = config
        lock.unlock()
        
        // 持久化到UserDefaults
        config.saveToDefaults()
        
        logger.info("【设置变更】配置已更新: 增量渲染 \(config.enableIncrementalRender ? "启用" : "禁用") | 合并 \(config.enableRectMerge ? "启用" : "禁用") | 最大脏区域:\(config.maxDirtyRects) | 聚合间隔:\(String(format: "%.3f", config.renderCoalesceInterval))s")
        
        // 发送设置变更通知
        NotificationCenter.default.post(
            name: .incrementalRendererSettingsChanged,
            object: self,
            userInfo: [
                "oldConfig": oldConfig,
                "newConfig": config
            ]
        )
        
        // 如果禁用了增量渲染，立即触发一次全量重绘
        if !config.enableIncrementalRender && oldConfig.enableIncrementalRender {
            triggerFullRedraw()
        }
    }
    
    // MARK: 设置面板方法 — 恢复默认配置
    /// 供设置面板一键恢复默认配置
    public func resetConfigurationToDefaults() {
        let defaultConfig = UIIncrementalRenderConfiguration.default
        updateConfiguration(defaultConfig)
        logger.info("【设置恢复】已恢复默认配置")
    }
    
    // MARK: 设置面板方法 — 开关增量渲染
    /// 快速切换增量渲染的启用/禁用状态，不改变其他配置
    /// - Parameter enabled: true启用增量渲染，false禁用并回退全量重绘
    public func setIncrementalRenderEnabled(_ enabled: Bool) {
        lock.lock()
        var config = configuration
        lock.unlock()
        
        guard config.enableIncrementalRender != enabled else { return }
        config.enableIncrementalRender = enabled
        updateConfiguration(config)
        
        logger.info("【快速开关】增量渲染已\(enabled ? "启用" : "禁用")")
    }
    
    // MARK: 设置面板方法 — 开关区域合并
    /// 快速切换区域合并的启用/禁用状态
    /// - Parameter enabled: true启用区域合并，false禁用
    public func setRectMergeEnabled(_ enabled: Bool) {
        lock.lock()
        var config = configuration
        lock.unlock()
        
        guard config.enableRectMerge != enabled else { return }
        config.enableRectMerge = enabled
        updateConfiguration(config)
        
        logger.info("【快速开关】区域合并已\(enabled ? "启用" : "禁用")")
    }
    
    // MARK: 统计信息 — 获取统计
    /// 获取当前渲染统计信息副本，供调试面板或性能监控使用
    /// - Returns: 渲染统计信息副本
    public func getStatistics() -> UIRenderStatistics {
        lock.lock()
        let stats = statistics
        lock.unlock()
        return stats
    }
    
    // MARK: 统计信息 — 重置统计
    /// 重置所有渲染统计数据，通常用于性能测试或用户手动清零
    public func resetStatistics() {
        lock.lock()
        statistics.reset()
        lock.unlock()
        logger.info("【统计】渲染统计数据已重置")
    }
    
    // MARK: 全局重置
    /// 彻底重置渲染器状态：清空脏区域、取消队列、重置统计、恢复默认配置
    /// 适用于严重错误恢复或用户手动重置场景
    public func reset() {
        cancelAllPendingRenders()
        clearAllDirtyRects()
        resetStatistics()
        resetConfigurationToDefaults()
        
        lock.lock()
        isRendering = false
        lastRenderTime = nil
        lock.unlock()
        
        logger.info("【全局重置】增量渲染器已完全重置")
    }
    
    // MARK: 全局重置 — 仅渲染状态
    /// 仅重置渲染状态（不清空配置和统计），用于视图重建后恢复渲染
    public func resetRenderState() {
        lock.lock()
        isRendering = false
        lastRenderTime = nil
        lock.unlock()
        
        // 取消定时器和队列，准备接收新任务
        DispatchQueue.main.async { [weak self] in
            self?.coalesceTimer?.invalidate()
            self?.coalesceTimer = nil
        }
        cancelAllPendingRenders()
        
        logger.info("【状态重置】渲染状态已重置，准备接收新任务")
    }
    
    // MARK: 调试信息 — 获取当前状态摘要
    /// 获取渲染器当前状态的文本描述，用于日志和调试面板
    /// - Returns: 状态摘要字符串
    public func getStatusSummary() -> String {
        lock.lock()
        let dirtyCount = dirtyRectEntries.count
        let queueCount = renderQueue.count
        let rendering = isRendering
        let config = configuration
        let stats = statistics
        lock.unlock()
        
        return """
        【增量渲染器状态摘要】
        脏区域缓存: \(dirtyCount) 个
        渲染队列: \(queueCount) 个
        是否渲染中: \(rendering ? "是" : "否")
        增量渲染: \(config.enableIncrementalRender ? "启用" : "禁用")
        区域合并: \(config.enableRectMerge ? "启用" : "禁用")
        累计渲染: \(stats.totalRenderCount) 次 (增量\(stats.incrementalRenderCount), 全量\(stats.fullRedrawCount))
        平均耗时: \(String(format: "%.3f", stats.averageRenderDurationMs)) ms
        队列峰值: \(stats.peakQueueSize) 个
        合并节省: \(stats.rectsSavedByMerge) 个区域
        """
    }
}

// MARK: - 迁回自 UI-02：extension UIIncrementalRenderer
public extension UIIncrementalRenderer {
    /// 旧版计算更新矩形接口，保留向后兼容，内部转发到新的脏区域机制
    /// 注意：新代码应直接使用 submitDirtyRect / submitDirtyRects
    @available(*, deprecated, message: "请使用 submitDirtyRect 或 submitDirtyRects 替代")
    func calculateUpdateRect(currentCount: Int, previousCount: Int? = nil) -> UIIncrementalUpdateRegion {
        let diff = currentCount - (previousCount ?? 0)
        if diff > 10 || diff < 0 {
            triggerFullRedraw()
            return UIIncrementalUpdateRegion(rect: NSRect.zero, isFullRedraw: true)
        }
        let rect = NSRect(x: 0, y: 0, width: CGFloat(diff) * 8, height: 500)
        submitDirtyRect(rect, source: "LegacyAPI", priority: 5)
        return UIIncrementalUpdateRegion(rect: rect, isFullRedraw: false)
    }
    
    /// 旧版重置接口，保留向后兼容
    @available(*, deprecated, message: "请使用 reset() 或 resetRenderState() 替代")
    func resetRenderCount() {
        resetRenderState()
    }
}

// MARK: - 迁回自 UI-02：UIRenderQueueEntry
private struct UIRenderQueueEntry: Equatable {
    /// 任务唯一标识
    let id: UUID
    
    /// 该任务需要渲染的脏区域列表（已合并）
    let dirtyRects: [NSRect]
    
    /// 任务创建时间
    let timestamp: Date
    
    /// 是否正在处理中
    var isProcessing: Bool = false
    
    /// 是否触发全量重绘
    let isFullRedraw: Bool
    
    /// 任务优先级（继承自脏区域的最高优先级）
    let priority: Int
}

// MARK: - 迁回自 UI-02：UIDirtyRectEntry
private struct UIDirtyRectEntry: Equatable {
    /// 需要重绘的矩形区域
    let rect: NSRect
    
    /// 优先级，数值越高越优先处理（0-10）
    let priority: Int
    
    /// 提交时间戳
    let timestamp: Date
    
    /// 来源标识，用于追踪是哪个模块提交的脏区域
    let source: String
    
    /// 唯一标识
    let id: UUID
    
    static func == (lhs: UIDirtyRectEntry, rhs: UIDirtyRectEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 迁回自 UI-02：struct UIIncrementalUpdateRegion
// MARK: - UI-GL-59 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-59_types.swift
// 版本: 2.0
// MARK: - 通知定义

/// 自动隐藏相关通知的扩展集合
// 已迁回 UI-GL-59_自动隐藏区域.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-60 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-60_types.swift
// 版本: 2.0
// MARK: - 通知名称
/// 浮动窗口平铺管理相关通知
// 已迁回 UI-GL-60_浮动窗口平铺管理.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-61 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-61_types.swift
// 版本: 2.0
// MARK: - 通知常量
/// 离屏渲染缓存相关通知名称
// 已迁回 UI-GL-61_离屏渲染与缓存.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-62 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-62_types.swift
// 版本: 2.0
// 迁移版本: 2.0
// MARK: - 通知名称常量
/// 帧率自适应模块相关的通知名称集合
// 已迁回 UI-GL-62_帧率自适应.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-63 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-63_types.swift
// 版本: 2.0
// UI-GL-63 增量渲染类型迁移文件
// Version: 2.0

// 兼容旧代码的增量更新区域定义
public struct UIIncrementalUpdateRegion {
    public let rect: NSRect
    public let isFullRedraw: Bool
}

// MARK: - 迁回自 UI-02：struct UIIncrementalRenderConfiguration
// MARK: - 帧率自适应管理器
/// 帧率自适应管理器 - 单例模式
/// 负责根据当前交互状态、CPU负载和配置策略，动态调整应用渲染帧率
// 已迁回 UI-GL-62_帧率自适应.swift：class UIAdaptiveFrameRateManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-63 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-63_types.swift
// 版本: 2.0
// MARK: - 通知名称扩展
/// 增量渲染模块发出的全局通知，供UI模块、性能监控模块订阅
// 已迁回 UI-GL-63_增量渲染.swift：extension Notification.Name（公共类型文件禁止功能实现）

// MARK: - 渲染配置结构体
/// 增量渲染器的可调参数，支持通过设置面板实时修改
public struct UIIncrementalRenderConfiguration: Codable, Equatable, Sendable {
    /// 最大脏区域缓存数量，超过则触发合并
    public var maxDirtyRects: Int = 50
    
    /// 区域合并阈值（像素），相邻区域间距小于此值时合并
    public var mergeThreshold: CGFloat = 4.0
    
    /// 是否启用增量渲染，关闭后回退到全量重绘
    public var enableIncrementalRender: Bool = true
    
    /// 渲染队列最大长度，超过则丢弃低优先级任务
    public var maxRenderQueueSize: Int = 10
    
    /// 渲染聚合间隔（秒），在此间隔内提交的脏区域会被合并后统一渲染
    public var renderCoalesceInterval: TimeInterval = 0.016  // 约1帧（60Hz）
    
    /// 是否启用区域合并优化
    public var enableRectMerge: Bool = true
    
    /// 全量重绘阈值：单次脏区域数量超过此值时直接全量重绘
    public var fullRedrawThreshold: Int = 20
    
    /// 是否启用渲染统计（用于调试面板）
    public var enableStatistics: Bool = true
    
    /// 默认配置
    public static let `default` = UIIncrementalRenderConfiguration()
    
    /// 从UserDefaults加载配置，不存在则返回默认值
    public static func loadFromDefaults() -> UIIncrementalRenderConfiguration {
        if let data = UserDefaults.standard.data(forKey: "UIIncrementalRendererConfiguration"),
           let config = try? JSONDecoder().decode(UIIncrementalRenderConfiguration.self, from: data) {
            return config
        }
        return .default
    }
    
    /// 保存到UserDefaults
    public func saveToDefaults() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "UIIncrementalRendererConfiguration")
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIRenderStatistics
// MARK: - 渲染统计信息
/// 记录增量渲染的性能数据，用于调优和监控
public struct UIRenderStatistics: Codable {
    /// 累计渲染次数
    public var totalRenderCount: Int = 0
    
    /// 累计增量渲染次数（非全量）
    public var incrementalRenderCount: Int = 0
    
    /// 累计全量重绘次数
    public var fullRedrawCount: Int = 0
    
    /// 累计提交的脏区域数量
    public var totalDirtyRectsSubmitted: Int = 0
    
    /// 合并后实际渲染的区域数量
    public var totalMergedRectsRendered: Int = 0
    
    /// 平均渲染耗时（毫秒）
    public var averageRenderDurationMs: Double = 0.0
    
    /// 最后一次渲染耗时（毫秒）
    public var lastRenderDurationMs: Double = 0.0
    
    /// 渲染队列峰值长度
    public var peakQueueSize: Int = 0
    
    /// 合并算法节省的区域数量（原始数量 - 合并后数量）
    public var rectsSavedByMerge: Int = 0
    
    /// 自启动以来的运行时间
    public var sessionStartTime: Date = Date()
    
    /// 重置所有统计数据
    public mutating func reset() {
        totalRenderCount = 0
        incrementalRenderCount = 0
        fullRedrawCount = 0
        totalDirtyRectsSubmitted = 0
        totalMergedRectsRendered = 0
        averageRenderDurationMs = 0.0
        lastRenderDurationMs = 0.0
        peakQueueSize = 0
        rectsSavedByMerge = 0
        sessionStartTime = Date()
    }
}
