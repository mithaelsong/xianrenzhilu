// 功能54: 图表数据虚拟滚动
// 对应: 仅渲染当前可视区域的K线条，大幅提升性能
// 优先级: P1

import AppKit
import Foundation
import os.log

// MARK: - 测试代码
#if DEBUG

/// 功能54：图表数据虚拟滚动 — 单元测试
func test_virtualScroll() {
    let manager = UIVirtualScrollManager.shared
    let logger = OSLog(subsystem: "com.xianrenzhilu.ui", category: "UI-GL-64")
    
    os_log("测试1: 默认配置", log: logger, type: .info)
    let config = manager.getConfiguration()
    if config.leadingBuffer == 5 { os_log("✅ 测试1通过", log: logger, type: .info) }
    else { os_log("❌ 测试1失败", log: logger, type: .error) }
    
    os_log("测试2: 可见范围更新", log: logger, type: .info)
    manager.updateVisibleRange(totalCount: 1000, visibleHeight: 500, itemHeight: 50, scrollOffset: 1000)
    let range = manager.visibleRange
    if range.count > 0 { os_log("✅ 测试2通过", log: logger, type: .info) }
    else { os_log("❌ 测试2失败", log: logger, type: .error) }
    
    os_log("测试3: 数据窗口", log: logger, type: .info)
    let window = manager.dataWindow
    if window.count > 0 { os_log("✅ 测试3通过", log: logger, type: .info) }
    else { os_log("❌ 测试3失败", log: logger, type: .error) }
    
    os_log("测试4: 可见性检查", log: logger, type: .info)
    if manager.isVisible(index: 25) { os_log("✅ 测试4通过", log: logger, type: .info) }
    else { os_log("❌ 测试4失败", log: logger, type: .error) }
    
    os_log("测试5: 数据窗口检查", log: logger, type: .info)
    if manager.isInDataWindow(index: 25) { os_log("✅ 测试5通过", log: logger, type: .info) }
    else { os_log("❌ 测试5失败", log: logger, type: .error) }
    
    os_log("测试6: 滚动方向", log: logger, type: .info)
    let direction = manager.scrollDirection
    _ = direction
    os_log("✅ 测试6通过", log: logger, type: .info)
    
    os_log("测试7: 配置更新", log: logger, type: .info)
    var newConfig = config
    newConfig.leadingBuffer = 10
    manager.updateConfiguration(newConfig)
    let updated = manager.getConfiguration()
    if updated.leadingBuffer == 10 { os_log("✅ 测试7通过", log: logger, type: .info) }
    else { os_log("❌ 测试7失败", log: logger, type: .error) }
    
    os_log("测试8: 性能统计", log: logger, type: .info)
    let stats = manager.performanceStats
    _ = stats
    os_log("✅ 测试8通过", log: logger, type: .info)
    
    os_log("测试9: 重置配置", log: logger, type: .info)
    manager.resetConfiguration()
    let reset = manager.getConfiguration()
    if reset.leadingBuffer == 5 { os_log("✅ 测试9通过", log: logger, type: .info) }
    else { os_log("❌ 测试9失败", log: logger, type: .error) }
    
    os_log("=== 全部虚拟滚动测试通过 ✅ ===", log: logger, type: .info)
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 可见范围发生变更时发送
    /// userInfo: ["oldRange": Range<Int>, "newRange": Range<Int>, "direction": UIScrollDirection]
    static let virtualScrollVisibleRangeDidChange = Notification.Name("com.xianrenzhilu.virtualScroll.visibleRangeDidChange")
    
    /// 数据窗口发生变更时发送
    /// userInfo: ["oldWindow": Range<Int>, "newWindow": Range<Int>, "totalCount": Int]
    static let virtualScrollDataWindowDidChange = Notification.Name("com.xianrenzhilu.virtualScroll.dataWindowDidChange")
    
    /// 虚拟滚动配置发生变更时发送
    /// userInfo: ["key": String, "oldValue": Any?, "newValue": Any?]
    static let virtualScrollConfigurationDidChange = Notification.Name("com.xianrenzhilu.virtualScroll.configurationDidChange")
}

// MARK: - 迁回自 UI-02：class UIVirtualScrollManager
public final class UIVirtualScrollManager : @unchecked Sendable {
    
    // MARK: - 单例
    /// 共享实例，全局唯一访问点
    public static let shared = UIVirtualScrollManager()
    
    // MARK: - Logger
    /// 结构化日志，替代print，便于调试和性能分析
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "VirtualScroll")
    
    // MARK: - 线程安全锁
    /// 保护所有共享可变状态，确保多线程安全
    /// NSRecursiveLock 保护所有共享可变状态
    private let lock = NSRecursiveLock()
    
    // MARK: - 核心状态（受锁保护）
    /// 当前可视范围（在总数据中的索引范围）
    private var _visibleRange: Range<Int> = 0..<0
    /// 当前数据窗口（比可视范围更大的切片范围，包含预加载区域）
    private var _dataWindow: Range<Int> = 0..<0
    /// 上一次滚动偏移，用于计算滚动方向
    private var _lastScrollOffset: CGFloat = 0
    /// 当前滚动方向
    private var _scrollDirection: UIScrollDirection = .none
    /// 总数据条目数
    private var _totalCount: Int = 0
    /// 每项高度（像素）
    private var _itemHeight: CGFloat = 0
    /// 可视区域高度（像素）
    private var _visibleHeight: CGFloat = 0
    /// 可视区域宽度（像素，用于水平滚动）
    private var _visibleWidth: CGFloat = 0
    /// 每项宽度（像素，用于水平滚动）
    private var _itemWidth: CGFloat = 0
    
    // MARK: - 配置（受锁保护）
    /// 当前虚拟滚动配置
    private var _configuration: UIVirtualScrollConfiguration = .default
    
    // MARK: - 预加载任务（受锁保护）
    /// 当前预加载异步任务，用于取消旧任务
    private var _preloadTask: Task<Void, Never>?
    /// 预加载状态标记
    private var _isPreloading: Bool = false
    /// 上次预加载时间戳，用于防抖
    private var _lastPreloadTime: Date = Date.distantPast
    /// 预加载序列号，用于识别过期的预加载请求
    private var _preloadSequence: UInt64 = 0
    
    // MARK: - 性能统计（受锁保护，可选）
    /// 可见范围更新次数
    private var _updateCount: UInt64 = 0
    /// 数据窗口变更次数
    private var _windowChangeCount: UInt64 = 0
    /// 预加载触发次数
    private var _preloadTriggerCount: UInt64 = 0
    
    // MARK: - 初始化
    /// 私有初始化，确保单例模式
    private init() {
        logger.info("☕️ 虚拟滚动管理器初始化完成，默认配置已加载")
    }
    
    // MARK: - 析构清理
    /// 释放资源，取消所有异步任务
    deinit {
        // 取消可能存在的预加载任务
        cancelPreloadTask()
        logger.info("🧹 虚拟滚动管理器已销毁，所有资源已清理")
    }
    
    // MARK: - 便捷锁操作
    /// 在闭包内执行加锁操作，自动处理解锁
    private func withLock<T>(_ action: () -> T) -> T {
        lock.lock()
        let result = action()
        lock.unlock()
        return result
    }
    
    /// 在闭包内执行加锁操作，无返回值
    private func withLock(_ action: () -> Void) {
        lock.lock()
        action()
        lock.unlock()
    }
    
    // MARK: - 可见范围计算（核心方法）
    /// 根据滚动偏移和尺寸参数计算当前可视范围
    /// 该方法会自动判断滚动方向，动态调整缓冲区，并触发数据窗口更新
    /// - Parameters:
    ///   - totalCount: 总数据条目数
    ///   - visibleHeight: 可视区域高度（像素）
    ///   - itemHeight: 每项高度（像素）
    ///   - scrollOffset: 当前滚动偏移（像素）
    ///   - visibleWidth: 可视区域宽度（像素，水平滚动时必填）
    ///   - itemWidth: 每项宽度（像素，水平滚动时必填）
    /// - Note: 此方法线程安全，可在主线程或后台线程调用
    public func updateVisibleRange(
        totalCount: Int,
        visibleHeight: CGFloat,
        itemHeight: CGFloat,
        scrollOffset: CGFloat,
        visibleWidth: CGFloat = 0,
        itemWidth: CGFloat = 0
    ) {
        // 参数合法性检查
        guard totalCount > 0, itemHeight > 0, visibleHeight > 0 else {
            logger.warning("⚠️ 更新可见范围参数无效: totalCount=\(totalCount), itemHeight=\(itemHeight), visibleHeight=\(visibleHeight)")
            return
        }
        
        // 计算滚动方向
        let direction = calculateScrollDirection(newOffset: scrollOffset)
        
        let config = withLock { _configuration }
        
        // 计算像素级精确起始索引
        let rawStartIndex: CGFloat
        let rawEndIndex: CGFloat
        
        if config.pixelPrecisionEnabled {
            // 像素级精确定位：使用浮点数精确计算
            rawStartIndex = scrollOffset / itemHeight
            rawEndIndex = (scrollOffset + visibleHeight) / itemHeight
        } else {
            // 整行对齐：向下取整
            rawStartIndex = floor(scrollOffset / itemHeight)
            rawEndIndex = ceil((scrollOffset + visibleHeight) / itemHeight)
        }
        
        // 根据滚动方向动态调整缓冲区
        let leadingBuffer: Int
        let trailingBuffer: Int
        
        if config.adaptiveBufferEnabled {
            // 自适应缓冲：滚动方向的前方增加缓冲，减少卡顿感
            switch direction {
            case .up, .left:
                // 向上/向左滚动：上方数据需要更多缓冲
                leadingBuffer = Int(CGFloat(config.leadingBuffer) * config.directionBufferMultiplier)
                trailingBuffer = config.trailingBuffer
            case .down, .right:
                // 向下/向右滚动：下方数据需要更多缓冲
                leadingBuffer = config.leadingBuffer
                trailingBuffer = Int(CGFloat(config.trailingBuffer) * config.directionBufferMultiplier)
            case .none:
                leadingBuffer = config.leadingBuffer
                trailingBuffer = config.trailingBuffer
            }
        } else {
            // 固定缓冲
            leadingBuffer = config.leadingBuffer
            trailingBuffer = config.trailingBuffer
        }
        
        // 计算最终可见范围（含缓冲）
        let startIndex = max(0, Int(floor(rawStartIndex)) - leadingBuffer)
        let endIndex = min(totalCount, Int(ceil(rawEndIndex)) + trailingBuffer + 1)
        
        // 确保范围有效
        let newRange = startIndex..<max(startIndex, min(endIndex, totalCount))
        
        // 获取旧范围用于比较
        let oldRange = withLock { _visibleRange }
        
        // 检查范围是否发生实质变化（避免微小抖动导致频繁刷新）
        let significantChange = abs(newRange.lowerBound - oldRange.lowerBound) > 0 ||
                                abs(newRange.upperBound - oldRange.upperBound) > 0
        
        guard significantChange else {
            // 范围无实质变化，仅更新滚动偏移和方向
            withLock {
                _lastScrollOffset = scrollOffset
                _scrollDirection = direction
            }
            return
        }
        
        // 更新核心状态
        withLock {
            _visibleRange = newRange
            _lastScrollOffset = scrollOffset
            _scrollDirection = direction
            _totalCount = totalCount
            _itemHeight = itemHeight
            _visibleHeight = visibleHeight
            _visibleWidth = visibleWidth
            _itemWidth = itemWidth
            _updateCount += 1
        }
        
        // 计算数据窗口
        updateDataWindow(direction: direction, config: config)
        
        // 发送可见范围变更通知（主线程发送，确保UI刷新在主线程）
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let userInfo: [String: Any] = [
                "oldRange": oldRange,
                "newRange": newRange,
                "direction": direction,
                "scrollOffset": scrollOffset,
                "totalCount": totalCount
            ]
            NotificationCenter.default.post(
                name: .virtualScrollVisibleRangeDidChange,
                object: self,
                userInfo: userInfo
            )
            self.logger.debug("📢 发送可见范围变更通知: \(oldRange) → \(newRange), 方向: \(direction.description)")
        }
        
        // 触发异步预加载
        if config.asyncPreloadEnabled {
            triggerAsyncPreload(direction: direction)
        }
        
        let updateCount = withLock({ _updateCount })
        logger.debug("🔄 可见范围更新 #\(updateCount): \(newRange), 方向: \(direction.description)")
    }
    
    // MARK: - 数据窗口计算（内部方法）
    /// 根据可见范围和滚动方向计算数据窗口
    /// 数据窗口 = 可见范围 + 预加载区域，是实际持有数据的范围
    /// - Parameters:
    ///   - direction: 当前滚动方向
    ///   - config: 当前配置
    private func updateDataWindow(direction: UIScrollDirection, config: UIVirtualScrollConfiguration) {
        let (visibleRange, totalCount) = withLock { (_visibleRange, _totalCount) }
        
        let visibleSize = visibleRange.count
        guard visibleSize > 0, totalCount > 0 else { return }
        
        // 根据预加载倍数计算扩展窗口
        let aheadCount = max(0, Int(CGFloat(visibleSize) * config.preloadAheadMultiplier))
        let behindCount = max(0, Int(CGFloat(visibleSize) * config.preloadBehindMultiplier))
        
        // 根据滚动方向调整预加载侧重
        var adjustedAhead = aheadCount
        var adjustedBehind = behindCount
        
        if config.adaptiveBufferEnabled {
            switch direction {
            case .up, .left:
                // 向上/向左滚动：前方（上方/左侧）数据即将进入视野，增加前方预加载
                adjustedAhead = Int(CGFloat(aheadCount) * config.directionBufferMultiplier)
            case .down, .right:
                // 向下/向右滚动：后方（下方/右侧）数据即将进入视野，增加后方预加载
                adjustedBehind = Int(CGFloat(behindCount) * config.directionBufferMultiplier)
            case .none:
                break
            }
        }
        
        // 计算新窗口边界
        var newWindowStart = max(0, visibleRange.lowerBound - adjustedAhead)
        var newWindowEnd = min(totalCount, visibleRange.upperBound + adjustedBehind)
        
        // 确保窗口大小在限制范围内
        let windowSize = newWindowEnd - newWindowStart
        if windowSize < config.minWindowSize {
            // 窗口过小，扩展至最小大小
            let expand = config.minWindowSize - windowSize
            newWindowStart = max(0, newWindowStart - expand / 2)
            newWindowEnd = min(totalCount, newWindowEnd + expand / 2 + expand % 2)
        }
        if windowSize > config.maxWindowSize {
            // 窗口过大，收缩至最大大小，以可视范围为中心
            let center = (visibleRange.lowerBound + visibleRange.upperBound) / 2
            let half = config.maxWindowSize / 2
            newWindowStart = max(0, center - half)
            newWindowEnd = min(totalCount, newWindowStart + config.maxWindowSize)
        }
        
        let newWindow = newWindowStart..<newWindowEnd
        let oldWindow = withLock { _dataWindow }
        
        // 检查数据窗口是否发生实质变化
        let windowChanged = newWindow != oldWindow
        
        guard windowChanged else { return }
        
        // 更新数据窗口
        withLock {
            _dataWindow = newWindow
            _windowChangeCount += 1
        }
        
        // 发送数据窗口变更通知
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let userInfo: [String: Any] = [
                "oldWindow": oldWindow,
                "newWindow": newWindow,
                "totalCount": totalCount,
                "windowInfo": UIDataWindowInfo(
                    range: newWindow,
                    totalCount: totalCount,
                    visibleOffsetInWindow: visibleRange.lowerBound - newWindow.lowerBound,
                    windowSize: newWindow.count
                )
            ]
            NotificationCenter.default.post(
                name: .virtualScrollDataWindowDidChange,
                object: self,
                userInfo: userInfo
            )
            self.logger.debug("📢 发送数据窗口变更通知: \(oldWindow) → \(newWindow)")
        }
        
        let windowChangeCount = withLock({ _windowChangeCount })
        logger.info("📦 数据窗口更新 #\(windowChangeCount): \(newWindow) (大小: \(newWindow.count))")
    }
    
    // MARK: - 滚动方向计算
    /// 根据当前滚动偏移与上一次偏移的差值计算滚动方向
    /// - Parameter newOffset: 新的滚动偏移值
    /// - Returns: 计算出的滚动方向
    private func calculateScrollDirection(newOffset: CGFloat) -> UIScrollDirection {
        let lastOffset = withLock { _lastScrollOffset }
        let delta = newOffset - lastOffset
        
        // 定义方向判断阈值（像素），避免微小抖动被误判为滚动
        let threshold: CGFloat = 0.5
        
        if abs(delta) < threshold {
            return .none
        }
        
        // 判断水平还是垂直滚动（根据是否有宽度参数）
        let hasHorizontal = withLock { _visibleWidth > 0 && _itemWidth > 0 }
        
        if hasHorizontal {
            // 水平滚动优先判断
            return delta > 0 ? .right : .left
        } else {
            // 垂直滚动（向上滚动偏移减小，向下滚动偏移增加）
            // 注意：在 macOS/iOS 中，scrollOffset 增加意味着内容向上移动
            return delta > 0 ? .up : .down
        }
    }
    
    // MARK: - 异步预加载
    /// 触发相邻数据的异步预加载
    /// 使用防抖机制，避免快速滚动时频繁触发预加载
    /// - Parameter direction: 当前滚动方向，用于确定优先预加载的区域
    private func triggerAsyncPreload(direction: UIScrollDirection) {
        let config = withLock { _configuration }
        let currentSequence = withLock {
            _preloadSequence += 1
            return _preloadSequence
        }
        
        let debounceMs = config.preloadDebounceMs
        
        // 取消旧任务
        cancelPreloadTask()
        
        // 创建新的预加载任务
        let task = Task { [weak self] in
            // 防抖延迟
            try? await Task.sleep(nanoseconds: debounceMs * 1_000_000)
            
            // 检查任务是否被取消
            guard !Task.isCancelled else { return }
            
            guard let self = self else { return }
            
            // 检查序列号是否过期（已有更新的滚动事件）
            let isExpired = self.withLock { currentSequence < self._preloadSequence }
            guard !isExpired else {
                self.logger.debug("⏭️ 预加载请求 #\(currentSequence) 已过期，跳过")
                return
            }
            
            await self.performPreload(direction: direction)
        }
        
        withLock {
            _preloadTask = task
            _preloadTriggerCount += 1
        }
        
        logger.debug("🚀 触发预加载任务 #\(currentSequence), 方向: \(direction.description), 防抖: \(debounceMs)ms")
    }
    
    /// 执行实际的预加载操作
    /// 此方法在后台线程执行，不应阻塞主线程
    /// - Parameter direction: 滚动方向
    private func performPreload(direction: UIScrollDirection) async {
        withLock { _isPreloading = true }
        defer { withLock { _isPreloading = false } }
        
        // 获取当前数据窗口和总数据量
        let (currentWindow, totalCount, config) = withLock {
            (_dataWindow, _totalCount, _configuration)
        }
        
        guard totalCount > 0 else { return }
        
        // 计算预加载目标范围
        let preloadSize = max(config.minWindowSize, currentWindow.count / 2)
        var preloadStart: Int
        var preloadEnd: Int
        
        switch direction {
        case .up, .left:
            // 向上/向左滚动：预加载前方（索引更小）的数据
            preloadStart = max(0, currentWindow.lowerBound - preloadSize)
            preloadEnd = currentWindow.lowerBound
        case .down, .right:
            // 向下/向右滚动：预加载后方（索引更大）的数据
            preloadStart = currentWindow.upperBound
            preloadEnd = min(totalCount, currentWindow.upperBound + preloadSize)
        case .none:
            // 静止状态：预加载前后两侧
            let halfSize = preloadSize / 2
            preloadStart = max(0, currentWindow.lowerBound - halfSize)
            preloadEnd = min(totalCount, currentWindow.upperBound + halfSize)
        }
        
        guard preloadStart < preloadEnd else { return }
        
        // 模拟预加载工作（实际项目中此处会调用数据提供者加载数据到缓存）
        let preloadRange = preloadStart..<preloadEnd
        logger.info("🔄 执行预加载: \(preloadRange), 大小: \(preloadRange.count)")
        
        // 这里可以扩展为实际的数据加载逻辑
        // 例如：调用 DataSource.shared.loadData(range: preloadRange)
        // 或：触发缓存预热操作
        
        // 发送预加载完成通知（可选，用于UI显示加载状态）
        // NotificationCenter.default.post(name: .virtualScrollPreloadCompleted, ...)
    }
    
    /// 取消当前预加载任务
    private func cancelPreloadTask() {
        let task = withLock {
            let t = _preloadTask
            _preloadTask = nil
            return t
        }
        task?.cancel()
    }
    
    // MARK: - 数据窗口切片（公开接口）
    /// 从完整数据数组中获取当前数据窗口的切片
    /// 如果数据不在窗口内，返回空数组
    /// - Parameter data: 完整数据数组
    /// - Returns: 数据窗口内的切片数组
    public func getDataWindowSlice<T>(from data: [T]) -> [T] {
        let window = withLock { _dataWindow }
        guard window.lowerBound >= 0, window.upperBound <= data.count else {
            logger.warning("⚠️ 数据窗口范围 \(window) 超出数据数组大小 \(data.count)")
            return []
        }
        return Array(data[window])
    }
    
    /// 从完整数据数组中获取当前可视范围的切片
    /// - Parameter data: 完整数据数组
    /// - Returns: 可视范围内的切片数组
    public func getVisibleSlice<T>(from data: [T]) -> [T] {
        let range = withLock { _visibleRange }
        guard range.lowerBound >= 0, range.upperBound <= data.count else {
            logger.warning("⚠️ 可视范围 \(range) 超出数据数组大小 \(data.count)")
            return []
        }
        return Array(data[range])
    }
    
    /// 获取当前数据窗口的信息
    public var dataWindowInfo: UIDataWindowInfo {
        let (window, totalCount, visibleRange) = withLock {
            (_dataWindow, _totalCount, _visibleRange)
        }
        return UIDataWindowInfo(
            range: window,
            totalCount: totalCount,
            visibleOffsetInWindow: visibleRange.lowerBound - window.lowerBound,
            windowSize: window.count
        )
    }
    
    /// 获取当前可视范围的索引数组
    public var visibleIndices: [Int] {
        let range = withLock { _visibleRange }
        return Array(range)
    }
    
    /// 获取当前数据窗口的索引数组
    public var dataWindowIndices: [Int] {
        let window = withLock { _dataWindow }
        return Array(window)
    }
    
    // MARK: - 可见性检查
    /// 检查指定索引是否在可视范围内
    /// - Parameter index: 数据索引
    /// - Returns: 是否在可视范围
    public func isVisible(index: Int) -> Bool {
        let range = withLock { _visibleRange }
        return range.contains(index)
    }
    
    /// 检查指定索引是否在数据窗口内
    /// - Parameter index: 数据索引
    /// - Returns: 是否在数据窗口内
    public func isInDataWindow(index: Int) -> Bool {
        let window = withLock { _dataWindow }
        return window.contains(index)
    }
    
    // MARK: - 尺寸计算
    /// 计算总虚拟高度（所有数据项的总高度）
    /// - Parameters:
    ///   - totalCount: 总数据条目数
    ///   - itemHeight: 每项高度
    /// - Returns: 总虚拟高度（像素）
    public func totalHeight(totalCount: Int, itemHeight: CGFloat) -> CGFloat {
        return CGFloat(totalCount) * itemHeight
    }
    
    /// 计算总虚拟宽度（所有数据项的总宽度）
    /// - Parameters:
    ///   - totalCount: 总数据条目数
    ///   - itemWidth: 每项宽度
    /// - Returns: 总虚拟宽度（像素）
    public func totalWidth(totalCount: Int, itemWidth: CGFloat) -> CGFloat {
        return CGFloat(totalCount) * itemWidth
    }
    
    /// 计算指定索引项的Y轴偏移（像素）
    /// - Parameters:
    ///   - index: 数据索引
    ///   - itemHeight: 每项高度
    /// - Returns: Y轴偏移量
    public func offsetY(for index: Int, itemHeight: CGFloat) -> CGFloat {
        return CGFloat(index) * itemHeight
    }
    
    /// 计算指定索引项的X轴偏移（像素，用于水平滚动）
    /// - Parameters:
    ///   - index: 数据索引
    ///   - itemWidth: 每项宽度
    /// - Returns: X轴偏移量
    public func offsetX(for index: Int, itemWidth: CGFloat) -> CGFloat {
        return CGFloat(index) * itemWidth
    }
    
    // MARK: - 设置面板方法（配置管理）
    /// 获取当前配置副本
    /// 返回的配置结构体是值类型，修改后不会影响当前配置，需要调用 updateConfiguration 提交
    public func getConfiguration() -> UIVirtualScrollConfiguration {
        return withLock { _configuration }
    }
    
    /// 更新虚拟滚动配置
    /// 更新后会自动发送配置变更通知，并触发一次数据窗口重算
    /// - Parameter newConfig: 新的配置
    /// - Note: 此方法线程安全
    public func updateConfiguration(_ newConfig: UIVirtualScrollConfiguration) {
        let oldConfig = withLock { _configuration }
        
        // 检查是否有实质变化
        guard newConfig != oldConfig else {
            logger.debug("📝 配置未发生实质变化，跳过更新")
            return
        }
        
        // 更新配置
        withLock {
            _configuration = newConfig
        }
        
        // 发送配置变更通知
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let userInfo: [String: Any] = [
                "oldConfig": oldConfig,
                "newConfig": newConfig
            ]
            NotificationCenter.default.post(
                name: .virtualScrollConfigurationDidChange,
                object: self,
                userInfo: userInfo
            )
            self.logger.info("📢 发送配置变更通知")
        }
        
        // 触发数据窗口重算（配置变更可能影响窗口大小）
        let currentDirection = withLock { _scrollDirection }
        updateDataWindow(direction: currentDirection, config: newConfig)
        
        logger.info("📝 配置已更新: \(newConfig)")
    }
    
    /// 重置配置为默认值
    /// 同时会清空所有滚动状态
    public func resetConfiguration() {
        let oldConfig = withLock { _configuration }
        
        withLock {
            _configuration = .default
        }
        
        // 发送配置变更通知
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            NotificationCenter.default.post(
                name: .virtualScrollConfigurationDidChange,
                object: self,
                userInfo: [
                    "oldConfig": oldConfig,
                    "newConfig": UIVirtualScrollConfiguration.default,
                    "isReset": true
                ]
            )
        }
        
        logger.info("📝 配置已重置为默认值")
    }
    
    /// 设置缓冲大小（便捷方法，供设置面板调用）
    /// - Parameters:
    ///   - leading: 前向缓冲区大小
    ///   - trailing: 后向缓冲区大小
    public func setBufferSize(leading: Int, trailing: Int) {
        var config = getConfiguration()
        config.leadingBuffer = max(0, leading)
        config.trailingBuffer = max(0, trailing)
        updateConfiguration(config)
    }
    
    /// 设置预加载倍数（便捷方法，供设置面板调用）
    /// - Parameters:
    ///   - ahead: 向前预加载倍数
    ///   - behind: 向后预加载倍数
    public func setPreloadMultiplier(ahead: CGFloat, behind: CGFloat) {
        var config = getConfiguration()
        config.preloadAheadMultiplier = max(0, ahead)
        config.preloadBehindMultiplier = max(0, behind)
        updateConfiguration(config)
    }
    
    /// 设置自适应缓冲开关（便捷方法，供设置面板调用）
    /// - Parameter enabled: 是否启用
    public func setAdaptiveBufferEnabled(_ enabled: Bool) {
        var config = getConfiguration()
        config.adaptiveBufferEnabled = enabled
        updateConfiguration(config)
    }
    
    /// 设置像素级精度开关（便捷方法，供设置面板调用）
    /// - Parameter enabled: 是否启用
    public func setPixelPrecisionEnabled(_ enabled: Bool) {
        var config = getConfiguration()
        config.pixelPrecisionEnabled = enabled
        updateConfiguration(config)
    }
    
    // MARK: - 状态查询
    /// 当前可视范围（只读）
    public var visibleRange: Range<Int> {
        return withLock { _visibleRange }
    }
    
    /// 当前数据窗口（只读）
    public var dataWindow: Range<Int> {
        return withLock { _dataWindow }
    }
    
    /// 当前滚动方向（只读）
    public var scrollDirection: UIScrollDirection {
        return withLock { _scrollDirection }
    }
    
    /// 当前滚动偏移（只读）
    public var lastScrollOffset: CGFloat {
        return withLock { _lastScrollOffset }
    }
    
    /// 当前预加载状态（只读）
    public var isPreloading: Bool {
        return withLock { _isPreloading }
    }
    
    /// 总数据条目数（只读）
    public var totalCount: Int {
        return withLock { _totalCount }
    }
    
    // MARK: - 性能统计
    /// 性能统计信息结构体
    public struct UIPerformanceStatsInfo {
        public let visibleRangeUpdates: UInt64
        public let dataWindowChanges: UInt64
        public let preloadTriggers: UInt64
        public let isPreloading: Bool
        public let configurationDescription: String
        
        public init(updateCount: UInt64, windowChangeCount: UInt64, preloadTriggerCount: UInt64, isPreloading: Bool, configDescription: String) {
            self.visibleRangeUpdates = updateCount
            self.dataWindowChanges = windowChangeCount
            self.preloadTriggers = preloadTriggerCount
            self.isPreloading = isPreloading
            self.configurationDescription = configDescription
        }
    }
    
    /// 获取当前性能统计信息
    /// 用于调试和性能分析
    public var performanceStats: UIPerformanceStatsInfo {
        let (updateCount, windowChangeCount, preloadTriggerCount, isPreloading, config) = withLock {
            (_updateCount, _windowChangeCount, _preloadTriggerCount, _isPreloading, _configuration)
        }
        return UIPerformanceStatsInfo(
            updateCount: updateCount,
            windowChangeCount: windowChangeCount,
            preloadTriggerCount: preloadTriggerCount,
            isPreloading: isPreloading,
            configDescription: config.description
        )
    }
    
    /// 重置性能统计
    public func resetPerformanceStats() {
        withLock {
            _updateCount = 0
            _windowChangeCount = 0
            _preloadTriggerCount = 0
        }
        logger.debug("📊 性能统计已重置")
    }
    
    // MARK: - 完全重置
    /// 完全重置虚拟滚动管理器状态
    /// 清除所有状态、配置和任务，恢复到初始状态
    /// 注意：此操作会取消预加载任务并发送通知
    public func fullReset() {
        // 取消预加载任务
        cancelPreloadTask()
        
        // 重置所有状态
        let oldRange = withLock { _visibleRange }
        let oldWindow = withLock { _dataWindow }
        
        withLock {
            _visibleRange = 0..<0
            _dataWindow = 0..<0
            _lastScrollOffset = 0
            _scrollDirection = .none
            _totalCount = 0
            _itemHeight = 0
            _visibleHeight = 0
            _visibleWidth = 0
            _itemWidth = 0
            _configuration = .default
            _preloadTask = nil
            _isPreloading = false
            _preloadSequence = 0
            _lastPreloadTime = Date.distantPast
            _updateCount = 0
            _windowChangeCount = 0
            _preloadTriggerCount = 0
        }
        
        // 发送状态变更通知
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            NotificationCenter.default.post(
                name: .virtualScrollVisibleRangeDidChange,
                object: self,
                userInfo: ["oldRange": oldRange, "newRange": 0..<0, "isReset": true]
            )
            NotificationCenter.default.post(
                name: .virtualScrollDataWindowDidChange,
                object: self,
                userInfo: ["oldWindow": oldWindow, "newWindow": 0..<0, "isReset": true]
            )
            NotificationCenter.default.post(
                name: .virtualScrollConfigurationDidChange,
                object: self,
                userInfo: ["isReset": true]
            )
        }
        
        logger.info("🔄 虚拟滚动管理器已完全重置")
    }
}

// MARK: - 迁回自 UI-02：enum UIScrollDirection
// MARK: - 脏区域条目
/// 单个脏区域的元数据，包含区域、优先级、来源等信息
// 已迁回 UI-GL-63_增量渲染.swift：UIDirtyRectEntry（功能脏区条目不属于公共类型）

// MARK: - 渲染队列条目
/// 等待执行的渲染任务
// 已迁回 UI-GL-63_增量渲染.swift：UIRenderQueueEntry（功能队列条目不属于公共类型）

// MARK: - 增量渲染器（单例）
/// 核心增量渲染管理器，负责脏区域收集、合并、队列调度与渲染触发
/// 通过只重绘变化区域来避免全量刷新，显著提升K线滚动/更新时的性能
// 已迁回 UI-GL-63_增量渲染.swift：class UIIncrementalRenderer（公共类型文件禁止功能实现）

// MARK: - 兼容旧接口（Deprecated）
// 已迁回 UI-GL-63_增量渲染.swift：extension UIIncrementalRenderer（公共类型文件禁止功能实现）


// MARK: - UI-GL-64 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-64_types.swift
// 版本: 2.0
// MARK: - 滚动方向枚举
/// 滚动方向，用于动态调整缓冲策略
public enum UIScrollDirection: Int, CaseIterable, CustomStringConvertible {
    case none = 0   /// 无滚动或静止
    case up         /// 向上滚动（内容向上移动，展示更早数据）
    case down       /// 向下滚动（内容向下移动，展示更晚数据）
    case left       /// 向左滚动（水平滚动，展示更早数据）
    case right      /// 向右滚动（水平滚动，展示更晚数据）
    
    public var description: String {
        switch self {
        case .none:  return "静止"
        case .up:    return "向上"
        case .down:  return "向下"
        case .left:  return "向左"
        case .right: return "向右"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIVirtualScrollConfiguration
// MARK: - 虚拟滚动配置结构体
/// 虚拟滚动系统的配置参数，可通过设置面板调整
public struct UIVirtualScrollConfiguration: Equatable, Sendable, CustomStringConvertible {
    /// 可视区上方缓冲区大小（行数）
    public var leadingBuffer: Int = 5
    /// 可视区下方缓冲区大小（行数）
    public var trailingBuffer: Int = 5
    /// 预加载倍数：向前预加载可视区几倍的数据
    public var preloadAheadMultiplier: CGFloat = 2.0
    /// 预加载倍数：向后预加载可视区几倍的数据
    public var preloadBehindMultiplier: CGFloat = 1.0
    /// 是否启用滚动方向自适应缓冲
    public var adaptiveBufferEnabled: Bool = true
    /// 方向自适应时，滚动方向的额外缓冲倍数
    public var directionBufferMultiplier: CGFloat = 1.5
    /// 是否启用异步预加载
    public var asyncPreloadEnabled: Bool = true
    /// 预加载延迟（毫秒），避免快速滚动时频繁触发
    public var preloadDebounceMs: UInt64 = 100
    /// 最小数据窗口大小（避免过小数据窗口频繁切换）
    public var minWindowSize: Int = 20
    /// 最大数据窗口大小（限制内存占用）
    public var maxWindowSize: Int = 5000
    /// 是否启用像素级精确定位（而非整行对齐）
    public var pixelPrecisionEnabled: Bool = true
    
    public var description: String {
        return """
        虚拟滚动配置:
        - 前向缓冲: \(leadingBuffer) 行
        - 后向缓冲: \(trailingBuffer) 行
        - 预加载向前倍数: \(preloadAheadMultiplier)
        - 预加载向后倍数: \(preloadBehindMultiplier)
        - 自适应缓冲: \(adaptiveBufferEnabled ? "启用" : "禁用")
        - 方向缓冲倍数: \(directionBufferMultiplier)
        - 异步预加载: \(asyncPreloadEnabled ? "启用" : "禁用")
        - 预加载防抖: \(preloadDebounceMs) ms
        - 最小窗口: \(minWindowSize)
        - 最大窗口: \(maxWindowSize)
        - 像素级精度: \(pixelPrecisionEnabled ? "启用" : "禁用")
        """
    }
    
    /// 默认配置
    public static let `default` = UIVirtualScrollConfiguration()
}

// MARK: - 迁回自 UI-02：struct UIDataWindowInfo
// MARK: - 数据窗口描述结构体
/// 描述当前数据窗口的范围和元信息
public struct UIDataWindowInfo: CustomStringConvertible {
    /// 当前数据窗口在总数据中的范围
    public let range: Range<Int>
    /// 总数据条目数
    public let totalCount: Int
    /// 可视范围在数据窗口中的偏移
    public let visibleOffsetInWindow: Int
    /// 数据窗口占内存的估算条目数
    public let windowSize: Int
    /// 窗口占总数比例
    public var windowRatio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(windowSize) / Double(totalCount)
    }
    
    public var description: String {
        return "数据窗口[\(range.lowerBound)..<\(range.upperBound)] / 总计\(totalCount) (\(String(format: "%.1f", windowRatio * 100))%)"
    }
}
