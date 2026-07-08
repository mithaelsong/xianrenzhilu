//
//  UI-GL-71_图表索引视口计算器.swift
//  仙人指路2-min｜UI模块
//
//  版本：2.0
//  职责：面向索引式图表（K线、蜡烛图、柱状图、深度图、订单簿等）的通用视口计算工具。
//  核心原则：
//    1. 纯计算，不碰手势、不碰刷新、不碰特定模块逻辑。
//    2. 功能模块自己捕获手势，调用本计算器，自己决定刷新方式。
//    3. 不绑定任何模块，各图表模块按需调用。
//  公共类型：UIChartViewport / UIChartViewportConfiguration / UIChartViewportPerformanceStats / UIChartViewportSnapshot
//           已迁到 UI-02_公共类型定义.swift，本文件不再定义。
//  日志：使用 UILogger.makeUILogger(category:)（UI-02 统一日志）。
//  优先级：P1
//

import AppKit
import Foundation
import os.log

// MARK: - 主计算器

/// 图表索引视口计算器
/// 纯计算工具，不处理手势、不处理刷新、不绑定任何模块。
public final class UIChartIndexViewportCalculator: @unchecked Sendable {
    
    // MARK: 单例（可选，模块也可以自己创建实例）
    public static let shared = UIChartIndexViewportCalculator()
    
    // MARK: 日志（使用UI-02统一日志）
    private let logger = UILogger.makeUILogger(category: "UI-GL-71")
    
    // MARK: 内部状态
    // ⚠️ 2026-06-23：统一为 NSRecursiveLock（与UI模块其他70个文件一致）。
    // 原 NSLock 不可重入，持锁回调（onViewportChanged）中若访问 viewport getter 会死锁（BUG-3/BUG-5）。
    private let lock = NSRecursiveLock()
    // ⚠️ 2026-06-23：平移亚蜡烛余数累积器。pan 按整根步进，小幅滑动（deltaX<candleWidth）
    // 被取整为0会导致完全不动（BUG-1）。累积未消费位移，凑足1根才步进，保留余数。
    private var _panAccumulator: Double = 0
    private var _viewport = UIChartViewport()
    private var _config = UIChartViewportConfiguration()
    private var _debounceTimer: Timer?
    private var _inertiaTimer: Timer?
    private var _currentVelocity: Double = 0
    private var _animationTimer: Timer?
    private var _targetCandleWidth: Double?
    private var _snapshots: [UIChartViewportSnapshot] = []
    private var _performanceStats = UIChartViewportPerformanceStats()
    private var _bookmarks: [Int: UIChartViewportSnapshot] = [:]
    private var _selectedIndex: Int?
    
    // MARK: 回调
    /// 视口变化时实时回调（每次pan/zoom都会触发）
    public var onViewportChanged: ((UIChartViewport) -> Void)?
    /// 停止滑动后防抖回调（debounceInterval后触发）
    public var onPanEnded: (() -> Void)?
    /// 分页加载触发回调（左边界或右边界）
    public var onPaginationTriggered: ((String, Int) -> Void)?
    /// 惯性滑动停止回调
    public var onInertiaEnded: (() -> Void)?
    /// 视口动画完成回调
    public var onAnimationCompleted: (() -> Void)?
    
    // MARK: 公开属性
    public var viewport: UIChartViewport {
        get { lock.lock(); defer { lock.unlock() }; return _viewport }
        set { lock.lock(); defer { lock.unlock() }; _viewport = newValue }
    }
    
    public var configuration: UIChartViewportConfiguration {
        get { lock.lock(); defer { lock.unlock() }; return _config }
        set { lock.lock(); _config = newValue; lock.unlock() }
    }
    
    public var performanceStats: UIChartViewportPerformanceStats {
        get { lock.lock(); defer { lock.unlock() }; return _performanceStats }
    }
    
    public var snapshots: [UIChartViewportSnapshot] {
        get { lock.lock(); defer { lock.unlock() }; return _snapshots }
    }
    
    public var selectedIndex: Int? {
        get { lock.lock(); defer { lock.unlock() }; return _selectedIndex }
        set { lock.lock(); _selectedIndex = newValue; lock.unlock() }
    }
    
    // MARK: 初始化
    public init(viewport: UIChartViewport = UIChartViewport(), configuration: UIChartViewportConfiguration = UIChartViewportConfiguration()) {
        self._viewport = viewport
        self._config = configuration
    }
    
    // ⚠️ 2026-06-23 修复：对象销毁时清理所有 Timer，避免实例释放后 Timer 仍在跑导致状态不一致。
    deinit {
        _debounceTimer?.invalidate()
        _inertiaTimer?.invalidate()
        _animationTimer?.invalidate()
    }
    
    // MARK: 1. 平移计算
    
    /// 平移视口
    /// - Parameters:
    ///   - deltaX: 水平位移（像素，正=右移/内容左移）
    ///   - viewWidth: 视图宽度（像素）
    /// - Returns: 新视口
    public func pan(deltaX: Double, viewWidth: Double) -> UIChartViewport {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 0.5 { logger.info("[PERF][UI-GL-71] pan ms=\(dt) deltaX=\(deltaX)") }
        }
        lock.lock()
        let startTime = Date()
        
        var viewport = _viewport
        guard viewport.totalCount > 0, viewWidth > 0 else { lock.unlock(); return viewport }
        
        let candleWidth = max(_config.minCandleWidth, viewport.candleWidth)
        // ⚠️ 2026-06-23 BUG-1修复：累积位移，不再直接取整。小幅滑动（deltaX<candleWidth）
        // 累积到足1根才步进，余数保留给下次，鼠标拖动/触控板小位移不再被丢弃。
        _panAccumulator += -deltaX
        let deltaCandles = Int((_panAccumulator / candleWidth).rounded(.towardZero))
        _panAccumulator -= Double(deltaCandles) * candleWidth
        // 余数还没攒够1根：startIndex 不变，直接返回（余数已保留），避免无效刷新。
        if deltaCandles == 0 { lock.unlock(); return viewport }
        
        let newStart = viewport.startIndex + deltaCandles
        let clampedStart = clampStartIndex(newStart, totalCount: viewport.totalCount, viewWidth: viewWidth, candleWidth: candleWidth)
        viewport.startIndex = clampedStart
        viewport.visibleCount = calculateVisibleCount(viewWidth: viewWidth, candleWidth: candleWidth)
        viewport.endIndex = min(viewport.totalCount, viewport.startIndex + viewport.visibleCount)
        viewport.contentOffsetX = Double(viewport.startIndex) * candleWidth
        viewport.candleWidth = candleWidth
        
        let oldViewport = _viewport
        _viewport = viewport
        recordPerformance(startTime: startTime, type: .pan)
        lock.unlock()
        
        // ⚠️ 2026-06-23 BUG-3修复：回调/通知/防抖全部移到锁外执行，避免持锁回调死锁。
        checkPaginationTrigger(viewport: viewport)
        onViewportChanged?(viewport)
        startDebounceTimer()
        postViewportChangeNotification(old: oldViewport, new: viewport)
        
        return viewport
    }
    
    // MARK: 2. 缩放计算
    
    /// 缩放视口
    public func zoom(factor: Double, viewWidth: Double, anchorX: Double? = nil) -> UIChartViewport {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            let dt = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            if dt > 0.5 { logger.info("[PERF][UI-GL-71] zoom ms=\(dt) factor=\(factor)") }
        }
        lock.lock()
        let startTime = Date()
        
        var viewport = _viewport
        guard viewport.totalCount > 0, viewWidth > 0, factor > 0 else { lock.unlock(); return viewport }
        
        let newCandleWidth = clampCandleWidth(viewport.candleWidth * factor)
        let oldCandleWidth = viewport.candleWidth
        
        let anchor = anchorX ?? _config.zoomAnchorMode.map { $0 * viewWidth } ?? viewWidth / 2
        let anchorIndex = Double(viewport.startIndex) + (anchor / oldCandleWidth)
        let newStart = anchorIndex - (anchor / newCandleWidth)
        let alignedStart = _config.snapToIntegerIndex ? Int(floor(newStart)) : Int(newStart.rounded())
        
        viewport.candleWidth = newCandleWidth
        // ⚠️ 2026-06-23：zoom 不调 clampStartIndex。candleWidth 变化后 visibleCount 变化，
        // 若同时 clamp startIndex 会导致 start 被新 maxStart 压回，画面跳跃。zoom 只约束 candleWidth，
        // startIndex 靠锚点正确计算后直接赋值（最多 clamp 到 0 和非负）。
        viewport.startIndex = clampStartIndex(max(0, alignedStart), totalCount: viewport.totalCount, viewWidth: viewWidth, candleWidth: newCandleWidth)
        viewport.visibleCount = calculateVisibleCount(viewWidth: viewWidth, candleWidth: newCandleWidth)
        viewport.endIndex = min(viewport.totalCount, viewport.startIndex + viewport.visibleCount)
        viewport.contentOffsetX = Double(viewport.startIndex) * newCandleWidth
        
        _viewport = viewport
        recordPerformance(startTime: startTime, type: .zoom)
        lock.unlock()
        
        // BUG-2修复：手势缩放不再自动跑 adaptDensity（原反向改 candleWidth 与用户意图打架）。
        // BUG-3修复：回调/防抖移到锁外执行，避免持锁回调死锁。
        onViewportChanged?(viewport)
        // ⚠️ 2026-06-23：缩放停手也需要触发 onPanEnded 重算指标（不动时做完整重刷）。
        startDebounceTimer()
        
        return viewport
    }
    
    // MARK: 3. 边界裁切
    
    public func clampToBounds(_ viewport: UIChartViewport) -> UIChartViewport {
        var result = viewport
        guard result.totalCount > 0 else { return result }
        let viewWidth = Double(result.visibleCount) * result.candleWidth
        result.startIndex = clampStartIndex(result.startIndex, totalCount: result.totalCount, viewWidth: viewWidth, candleWidth: result.candleWidth)
        result.visibleCount = calculateVisibleCount(viewWidth: viewWidth, candleWidth: result.candleWidth)
        result.endIndex = min(result.totalCount, result.startIndex + result.visibleCount)
        result.contentOffsetX = Double(result.startIndex) * result.candleWidth
        return result
    }
    
    // MARK: 4. 防抖（内部自动处理）
    
    private func startDebounceTimer() {
        _debounceTimer?.invalidate()
        _debounceTimer = Timer.scheduledTimer(withTimeInterval: _config.debounceInterval, repeats: false) { [weak self] _ in
            self?.onPanEnded?()
        }
    }
    
    // MARK: 5. followTail
    
    public func shouldFollowTail(_ viewport: UIChartViewport) -> Bool {
        guard _config.followTail else { return false }
        guard !_config.enableViewportLock else { return false }
        return viewport.isAtTail || viewport.endIndex == 0 || viewport.startIndex >= viewport.totalCount
    }
    
    // MARK: 7. 缩放限制
    
    private func clampCandleWidth(_ width: Double) -> Double {
        max(_config.minCandleWidth, min(_config.maxCandleWidth, width))
    }
    
    // MARK: 8. 动画插值（缩放动画）
    
    public func animateZoom(to targetWidth: Double, viewWidth: Double, completion: (() -> Void)? = nil) {
        guard _config.enableZoomAnimation else {
            _ = zoom(factor: targetWidth / _viewport.candleWidth, viewWidth: viewWidth)
            completion?()
            return
        }
        
        _targetCandleWidth = targetWidth
        _animationTimer?.invalidate()
        
        let startWidth = _viewport.candleWidth
        let startTime = Date()
        let duration = _config.zoomAnimationDuration
        
        _animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(1.0, elapsed / duration)
            let eased = self.easeInOut(progress)
            let currentWidth = startWidth + (targetWidth - startWidth) * eased
            let factor = currentWidth / self._viewport.candleWidth
            _ = self.zoom(factor: factor, viewWidth: viewWidth)
            
            if progress >= 1.0 {
                timer.invalidate()
                self._animationTimer = nil
                self._targetCandleWidth = nil
                self.onAnimationCompleted?()
                completion?()
                NotificationCenter.default.post(name: .chartViewportAnimationCompleted, object: self)
            }
        }
    }
    
    // MARK: 10. 分页加载触发
    
    private func checkPaginationTrigger(viewport: UIChartViewport) {
        guard _config.enablePagination else { return }
        if viewport.startIndex <= _config.paginationTriggerThreshold {
            onPaginationTriggered?("left", viewport.startIndex)
            NotificationCenter.default.post(
                name: .chartPaginationTriggered,
                object: self,
                userInfo: ["direction": "left", "currentStartIndex": viewport.startIndex]
            )
        }
    }
    
    // MARK: 11. 视口快照
    
    @discardableResult
    public func saveSnapshot(label: String? = nil) -> UIChartViewportSnapshot {
        let snapshot = UIChartViewportSnapshot(viewport: _viewport, label: label)
        _snapshots.append(snapshot)
        return snapshot
    }
    
    public func restoreSnapshot(_ snapshot: UIChartViewportSnapshot) -> UIChartViewport {
        var viewport = _viewport
        viewport.startIndex = snapshot.startIndex
        viewport.endIndex = snapshot.endIndex
        viewport.candleWidth = snapshot.candleWidth
        viewport.contentOffsetX = snapshot.contentOffsetX
        viewport.visibleCount = snapshot.endIndex - snapshot.startIndex
        _viewport = viewport
        onViewportChanged?(viewport)
        return viewport
    }
    
    public func clearSnapshots() {
        _snapshots.removeAll()
    }
    
    // MARK: 12. 事件通知
    
    private func postViewportChangeNotification(old: UIChartViewport, new: UIChartViewport) {
        NotificationCenter.default.post(
            name: .chartViewportDidChange,
            object: self,
            userInfo: ["oldViewport": old, "newViewport": new]
        )
    }
    
    // MARK: 13. 预加载缓冲
    
    public func viewportWithBuffer(viewWidth: Double) -> UIChartViewport {
        var viewport = _viewport
        let buffer = _config.preloadBuffer
        viewport.startIndex = max(0, viewport.startIndex - buffer)
        viewport.endIndex = min(viewport.totalCount, viewport.endIndex + buffer)
        return viewport
    }
    
    // MARK: 14. 自动适配
    
    public func autoAdapt(totalCount: Int, viewWidth: Double) -> UIChartViewport {
        guard totalCount > 0, viewWidth > 0 else { return _viewport }
        let idealWidth = viewWidth / Double(totalCount)
        let clampedWidth = clampCandleWidth(idealWidth)
        return zoom(factor: clampedWidth / _viewport.candleWidth, viewWidth: viewWidth)
    }
    
    // MARK: 15. 惯性滑动
    
    public func startInertia(initialVelocity: Double, viewWidth: Double) {
        guard _config.enableInertia, viewWidth > 0 else { return }
        _currentVelocity = initialVelocity
        _inertiaTimer?.invalidate()
        
        _inertiaTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let absVelocity = abs(self._currentVelocity)
            guard absVelocity > self._config.inertiaMinVelocity else {
                timer.invalidate()
                self._inertiaTimer = nil
                self._currentVelocity = 0
                self.onInertiaEnded?()
                NotificationCenter.default.post(name: .chartInertiaDidEnd, object: self)
                return
            }
            
            let deltaX = self._currentVelocity / 60.0
            _ = self.pan(deltaX: deltaX, viewWidth: viewWidth)
            self._currentVelocity *= self._config.inertiaDeceleration
        }
    }
    
    public func stopInertia() {
        _inertiaTimer?.invalidate()
        _inertiaTimer = nil
        _currentVelocity = 0
    }
    
    // MARK: 16. 边界回弹
    
    public func bounce(viewWidth: Double) -> UIChartViewport {
        guard _config.enableBounce else { return _viewport }
        var viewport = _viewport
        if viewport.startIndex < 0 {
            viewport.startIndex = 0
            viewport.endIndex = min(viewport.totalCount, viewport.visibleCount)
        } else if viewport.endIndex > viewport.totalCount {
            viewport.endIndex = viewport.totalCount
            viewport.startIndex = max(0, viewport.totalCount - viewport.visibleCount)
        }
        viewport.contentOffsetX = Double(viewport.startIndex) * viewport.candleWidth
        return viewport
    }
    
    // MARK: 17. 捏合缩放（预留接口，模块自己处理手势）
    
    public func pinchZoom(scale: Double, viewWidth: Double) -> UIChartViewport {
        return zoom(factor: scale, viewWidth: viewWidth)
    }
    
    // MARK: 18. 双击重置
    
    public func resetToFit(totalCount: Int, viewWidth: Double) -> UIChartViewport {
        return autoAdapt(totalCount: totalCount, viewWidth: viewWidth)
    }
    
    // MARK: 18b. 定位最新到屏幕中间 / 布局变化重约束（2026-06-23 新增）
    
    /// 定位视口，使最后一根（最新未闭合K线）停在屏幕中间。
    /// - Parameter viewWidth: 绘图区宽度（像素）
    /// - Returns: 定位后的视口
    public func centerOnLatest(viewWidth: Double) -> UIChartViewport {
        lock.lock()
        defer { lock.unlock() }
        var viewport = _viewport
        guard viewport.totalCount > 0, viewWidth > 0 else { return viewport }
        let visibleCount = calculateVisibleCount(viewWidth: viewWidth, candleWidth: viewport.candleWidth)
        // 最后一根 index = totalCount-1，让它位于屏幕中间：startIndex = (totalCount-1) - visibleCount/2
        let target = max(0, viewport.totalCount - 1 - visibleCount / 2)
        viewport.startIndex = clampStartIndex(target, totalCount: viewport.totalCount, viewWidth: viewWidth, candleWidth: viewport.candleWidth)
        viewport.visibleCount = visibleCount
        viewport.endIndex = min(viewport.totalCount, viewport.startIndex + visibleCount)
        viewport.contentOffsetX = Double(viewport.startIndex) * viewport.candleWidth
        _viewport = viewport
        _panAccumulator = 0  // 定位后清零余数，避免下次 pan 残留跳动
        return viewport
    }
    
    /// 视图宽度变化时，按新宽度重算 visibleCount 并重新约束 startIndex（保持当前定位意图，不跳位）。
    public func updateForViewWidth(_ viewWidth: Double) -> UIChartViewport {
        lock.lock()
        defer { lock.unlock() }
        var viewport = _viewport
        guard viewport.totalCount > 0, viewWidth > 0 else { return viewport }
        let visibleCount = calculateVisibleCount(viewWidth: viewWidth, candleWidth: viewport.candleWidth)
        viewport.startIndex = clampStartIndex(viewport.startIndex, totalCount: viewport.totalCount, viewWidth: viewWidth, candleWidth: viewport.candleWidth)
        viewport.visibleCount = visibleCount
        viewport.endIndex = min(viewport.totalCount, viewport.startIndex + visibleCount)
        viewport.contentOffsetX = Double(viewport.startIndex) * viewport.candleWidth
        _viewport = viewport
        return viewport
    }
    
    // MARK: 20. 性能统计
    
    private enum PerformanceType { case pan, zoom }
    
    private func recordPerformance(startTime: Date, type: PerformanceType) {
        guard _config.enablePerformanceStats else { return }
        let latency = Date().timeIntervalSince(startTime) * 1000
        switch type {
        case .pan:
            _performanceStats.totalPanEvents += 1
            // ⚠️ 2026-06-23 修复：累计平均（非指数移动平均），避免早期事件被无限稀释。
            let n = Double(_performanceStats.totalPanEvents)
            _performanceStats.averagePanLatency = (_performanceStats.averagePanLatency * (n - 1) + latency) / n
        case .zoom:
            _performanceStats.totalZoomEvents += 1
            let n = Double(_performanceStats.totalZoomEvents)
            _performanceStats.averageZoomLatency = (_performanceStats.averageZoomLatency * (n - 1) + latency) / n
        }
        _performanceStats.lastUpdateTime = Date()
    }
    
    public func resetPerformanceStats() {
        _performanceStats = UIChartViewportPerformanceStats()
    }
    
    // MARK: 22. 滚动吸附
    
    public func snapToInteger(viewWidth: Double) -> UIChartViewport {
        guard _config.snapToIntegerIndex else { return _viewport }
        var viewport = _viewport
        viewport.startIndex = Int(round(Double(viewport.startIndex)))
        viewport.endIndex = min(viewport.totalCount, viewport.startIndex + viewport.visibleCount)
        viewport.contentOffsetX = Double(viewport.startIndex) * viewport.candleWidth
        _viewport = viewport
        return viewport
    }
    
    // MARK: 23. 缩放步进
    
    public func stepZoom(direction: Int, viewWidth: Double) -> UIChartViewport {
        guard _config.enableZoomStepping else { return _viewport }
        let current = _viewport.candleWidth
        let steps = _config.zoomSteps.sorted()
        guard let currentIndex = steps.firstIndex(where: { $0 >= current }) else {
            return zoom(factor: steps.last! / current, viewWidth: viewWidth)
        }
        let targetIndex = min(steps.count - 1, max(0, currentIndex + direction))
        return zoom(factor: steps[targetIndex] / current, viewWidth: viewWidth)
    }
    
    // MARK: 24. 视口锁定
    
    public var isViewportLocked: Bool {
        get { _config.enableViewportLock }
        set { _config.enableViewportLock = newValue }
    }
    
    // MARK: 28. 平滑滚动
    
    public func smoothScroll(to targetStartIndex: Int, viewWidth: Double) {
        guard _config.enableSmoothScroll else {
            _ = pan(deltaX: Double(targetStartIndex - _viewport.startIndex) * _viewport.candleWidth, viewWidth: viewWidth)
            return
        }
        
        let startIndex = _viewport.startIndex
        let diff = targetStartIndex - startIndex
        let step = Double(diff) / Double(_config.smoothScrollSteps)
        var stepCount = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            stepCount += 1
            if stepCount > self._config.smoothScrollSteps {
                timer.invalidate()
                return
            }
            let currentTarget = startIndex + Int(step * Double(stepCount))
            let deltaX = Double(currentTarget - self._viewport.startIndex) * self._viewport.candleWidth
            _ = self.pan(deltaX: deltaX, viewWidth: viewWidth)
        }
    }
    
    // MARK: 29. 边缘加载指示（状态查询）
    
    public var isNearLeftEdge: Bool {
        _viewport.startIndex <= _config.paginationTriggerThreshold
    }
    
    public var isNearRightEdge: Bool {
        _viewport.endIndex >= _viewport.totalCount - _config.paginationTriggerThreshold
    }
    
    // MARK: 30. 数据密度自适应
    
    private func adaptDensity(viewport: UIChartViewport, viewWidth: Double) -> UIChartViewport {
        var result = viewport
        let density = Double(viewport.totalCount) / Double(viewport.visibleCount)
        if density > 10 {
            result.candleWidth = clampCandleWidth(result.candleWidth * 0.9)
        } else if density < 2 && result.candleWidth < _config.maxCandleWidth {
            result.candleWidth = clampCandleWidth(result.candleWidth * 1.1)
        }
        result.visibleCount = calculateVisibleCount(viewWidth: viewWidth, candleWidth: result.candleWidth)
        result.endIndex = min(result.totalCount, result.startIndex + result.visibleCount)
        return result
    }
    
    // MARK: 31. 空数据占位（状态查询）
    
    public var isEmpty: Bool {
        _viewport.totalCount == 0
    }
    
    public var emptyViewport: UIChartViewport {
        UIChartViewport(
            startIndex: 0,
            endIndex: 0,
            candleWidth: _config.minCandleWidth,
            contentOffsetX: 0,
            visibleCount: 0,
            totalCount: 0
        )
    }
    
    // MARK: 32. 选中高亮
    
    public func selectIndex(_ index: Int?) {
        _selectedIndex = index
    }
    
    public func selectedIndexScreenX() -> Double? {
        guard let index = _selectedIndex else { return nil }
        return Double(index - _viewport.startIndex) * _viewport.candleWidth + _viewport.candleWidth / 2
    }
    
    // MARK: 35. 视口动画过渡
    
    public func animateToViewport(_ target: UIChartViewport, viewWidth: Double) {
        guard _config.enableViewportAnimation else {
            _viewport = target
            onViewportChanged?(target)
            return
        }
        
        let start = _viewport
        let startTime = Date()
        let duration = _config.viewportAnimationDuration
        
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(1.0, elapsed / duration)
            let eased = self.easeInOut(progress)
            
            var current = UIChartViewport()
            current.startIndex = Int(Double(start.startIndex) + Double(target.startIndex - start.startIndex) * eased)
            current.endIndex = Int(Double(start.endIndex) + Double(target.endIndex - start.endIndex) * eased)
            current.candleWidth = start.candleWidth + (target.candleWidth - start.candleWidth) * eased
            current.contentOffsetX = Double(current.startIndex) * current.candleWidth
            current.visibleCount = current.endIndex - current.startIndex
            current.totalCount = target.totalCount
            
            self._viewport = current
            self.onViewportChanged?(current)
            
            if progress >= 1.0 {
                timer.invalidate()
                self.onAnimationCompleted?()
            }
        }
    }
    
    // MARK: 41. 滚动到索引
    
    public func scrollToIndex(_ index: Int, viewWidth: Double, animated: Bool = true) -> UIChartViewport {
        let target = max(0, min(index, _viewport.totalCount - 1))
        if animated && _config.enableSmoothScroll {
            smoothScroll(to: target, viewWidth: viewWidth)
        } else {
            _ = pan(deltaX: Double(target - _viewport.startIndex) * _viewport.candleWidth, viewWidth: viewWidth)
        }
        return _viewport
    }
    
    // MARK: 42. 滚动到尾部
    
    public func scrollToTail(viewWidth: Double, animated: Bool = true) -> UIChartViewport {
        let target = max(0, _viewport.totalCount - calculateVisibleCount(viewWidth: viewWidth, candleWidth: _viewport.candleWidth))
        return scrollToIndex(target, viewWidth: viewWidth, animated: animated)
    }
    
    // MARK: 辅助方法
    
    private func clampStartIndex(_ start: Int, totalCount: Int, viewWidth: Double, candleWidth: Double? = nil) -> Int {
        // ⚠️ 2026-06-23：原逻辑 `min(minStart, start)` 用 minStart 当上限，
        // 导致 start 被压到 totalCount-leftMargin-visibleCount 以下，无法滑到最新。
        // 正确：clamp 到 [0, maxStart]，maxStart = totalCount - visibleCount（仅限 pan，zoom 不自调 clamp）。
        guard totalCount > 0 else { return 0 }
        // ⚠️ 2026-06-23：candleWidth 显式传入（zoom 用新宽度），缺省回退 _viewport.candleWidth，
        // 避免 zoom 时用旧宽度算 visibleCount 导致 maxStart 错误。
        let cw = candleWidth ?? _viewport.candleWidth
        let visibleCount = calculateVisibleCount(viewWidth: viewWidth, candleWidth: cw)
        // ⚠️ 2026-06-23 BUG-4修复：支持右侧留白。allowRightBlank 时最新一根最多停到屏幕中间
        // （右边留 visibleCount/2 空白），使 centerOnLatest 能真正居中，pan 也能滑到最新居中。
        let rightBlank = _config.allowRightBlank ? visibleCount / 2 : 0
        let maxStart = max(0, totalCount - visibleCount + rightBlank)
        return max(0, min(start, maxStart))
    }
    
    private func calculateVisibleCount(viewWidth: Double, candleWidth: Double) -> Int {
        let width = max(candleWidth, _config.minCandleWidth)
        return max(_config.minVisibleCandles, Int(viewWidth / width))
    }
    
    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }
}

// MARK: - 工具函数

public extension UIChartIndexViewportCalculator {
    static func calculateVisibleCountStatic(viewWidth: Double, candleWidth: Double, minVisible: Int = 5) -> Int {
        guard candleWidth > 0, viewWidth > 0 else { return minVisible }
        return max(minVisible, Int(viewWidth / candleWidth))
    }
    
    static func calculateContentWidth(totalCount: Int, candleWidth: Double) -> Double {
        Double(totalCount) * candleWidth
    }
    
    static func indexToX(index: Int, startIndex: Int, candleWidth: Double) -> Double {
        Double(index - startIndex) * candleWidth
    }
    
    static func xToIndex(x: Double, startIndex: Int, candleWidth: Double) -> Int {
        guard candleWidth > 0 else { return startIndex }
        return startIndex + Int(x / candleWidth)
    }
}
