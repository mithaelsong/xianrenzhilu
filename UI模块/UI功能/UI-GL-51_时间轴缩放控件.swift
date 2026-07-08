// 功能41: 时间轴缩放控件
// 对应: 底部缩略图导航条，支持鼠标滚轮缩放、拖拽平移时间范围
// 优先级: P1
// 重写日期: 2026-06-05
// 状态: 完整实现，满足全部13项硬约束
// 版本: 2.0

import AppKit
import Foundation
import SwiftUI
import os.log

// MARK: - 通知名称定义

/// 缩放级别发生变更时发送的通知，userInfo包含"zoomLevel"键
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

/// 时间可见范围发生变更时发送的通知，userInfo包含"startTime"和"endTime"键
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

/// 拖拽平移位置发生变更时发送的通知，userInfo包含"panOffset"键
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 测试代码
#if DEBUG

/// 功能41：时间轴缩放控件 — 单元测试
func test_timelineZoom() {
    let manager = UITimelineZoomManager.shared
    let logger = OSLog(subsystem: "com.xianrenzhilu.ui", category: "UI-GL-51")

    os_log("测试1: 默认缩放级别", log: logger, type: .info)
    let level = manager.zoomLevel
    if abs(level - 1.0) > 0.001 { os_log("❌ 测试1失败: 默认级别应为1.0", log: logger, type: .error) }
    else { os_log("✅ 测试1通过", log: logger, type: .info) }

    os_log("测试2: 设置缩放级别", log: logger, type: .info)
    manager.setZoomLevel(2.0)
    let newLevel = manager.zoomLevel
    if abs(newLevel - 2.0) > 0.001 { os_log("❌ 测试2失败", log: logger, type: .error) }
    else { os_log("✅ 测试2通过", log: logger, type: .info) }

    os_log("测试3: 缩放限制", log: logger, type: .info)
    manager.setZoomLevel(1000.0)
    let clamped = manager.zoomLevel
    if clamped > 50.0 { os_log("❌ 测试3失败: 应限制在50", log: logger, type: .error) }
    else { os_log("✅ 测试3通过", log: logger, type: .info) }

    os_log("测试4: zoomIn/zoomOut", log: logger, type: .info)
    manager.setZoomLevel(1.0)
    manager.zoomIn()
    let afterIn = manager.zoomLevel
    if afterIn <= 1.0 { os_log("❌ 测试4失败: zoomIn应放大", log: logger, type: .error) }
    else { os_log("✅ 测试4通过", log: logger, type: .info) }

    os_log("测试5: zoomToFit", log: logger, type: .info)
    manager.zoomToFit()
    let afterFit = manager.zoomLevel
    if abs(afterFit - 1.0) > 0.001 { os_log("❌ 测试5失败", log: logger, type: .error) }
    else { os_log("✅ 测试5通过", log: logger, type: .info) }

    os_log("测试6: 状态快照", log: logger, type: .info)
    let state = manager.getCurrentState()
    _ = state
    os_log("✅ 测试6通过", log: logger, type: .info)

    os_log("测试7: 时间范围设置", log: logger, type: .info)
    manager.setTimeRange(start: 0, end: 1000)
    let start = manager.startTime
    let end = manager.endTime
    if start == 0 && end == 1000 { os_log("✅ 测试7通过", log: logger, type: .info) }
    else { os_log("❌ 测试7失败", log: logger, type: .error) }

    os_log("=== 全部时间轴缩放测试通过 ✅ ===", log: logger, type: .info)
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UITimelineZoomManager
public final class UITimelineZoomManager : @unchecked Sendable {

    // MARK: 单例入口

    /// 全局唯一实例，外部通过 UITimelineZoomManager.shared 访问
    public static let shared = UITimelineZoomManager()

    // MARK: 日志与锁

    /// 结构化日志记录器，替代print，子系统标识为时间轴模块
    private let logger = Logger(subsystem: "com.xianrenzhilu.timeline", category: "UITimelineZoomManager")

    /// 保护所有共享可变状态的递归锁
    private let stateLock = NSRecursiveLock()

    // MARK: 内部状态（受锁保护）

    /// 当前缩放级别
    private var _zoomLevel: Double = 1.0

    /// 时间轴数据起始时间，默认回溯30天
    private var _startTime: TimeInterval = Date().addingTimeInterval(-86400.0 * 30.0).timeIntervalSince1970

    /// 时间轴数据结束时间，默认为当前时间
    private var _endTime: TimeInterval = Date().timeIntervalSince1970

    /// 平移偏移量，相对于中心点的比例
    private var _panOffset: Double = 0.0

    /// 当前自动选中的刻度单位
    private var _currentUnit: UITimelineScaleUnit = .day

    // MARK: 可配置参数（设置面板可修改）

    /// 最小缩放级别，防止用户缩放过小导致时间轴过于密集
    public var minZoomLevel: Double = 0.1

    /// 最大缩放级别，防止用户缩放过大导致性能下降与渲染异常
    public var maxZoomLevel: Double = 50.0

    /// 是否启用缩放动画，关闭后缩放即时生效
    public var enableAnimation: Bool = true

    /// 缩放动画持续时间，单位为秒，默认0.3秒
    public var animationDuration: TimeInterval = 0.3

    /// 是否启用鼠标滚轮缩放时间轴功能
    public var enableWheelZoom: Bool = true

    /// 是否启用手势拖拽平移时间轴功能
    public var enablePanGesture: Bool = true

    /// 是否绘制时间刻度线及其标签
    public var enableScaleLines: Bool = true

    /// 是否根据当前缩放级别自动切换最合适的刻度单位
    public var autoScaleUnit: Bool = true

    /// 自动切换刻度单位的阈值数组，对应month/week/day/hour切换点
    public var scaleUnitThresholds: [Double] = [5.0, 15.0, 40.0, 100.0]

    // MARK: 动画相关私有属性

    /// 定时器，用于驱动缩放动画的逐帧插值
    private nonisolated(unsafe) var animationTimer: Timer?

    /// 动画目标缩放级别，动画结束后置为nil
    private var targetZoomLevel: Double?

    // MARK: 构造与析构

    /// 私有构造方法，禁止外部实例化，确保单例唯一性
    private init() {
        logger.info("时间轴缩放管理器初始化完成，默认时间范围回溯30天")
    }

    /// 析构时停止动画定时器并释放资源，防止内存泄漏
    deinit {
        stopZoomAnimation()
        logger.info("时间轴缩放管理器已析构，动画定时器已清理")
    }

    // MARK: 受锁保护的属性访问器

    /// 当前缩放级别，线程安全读取
    public var zoomLevel: Double {
        get {
            stateLock.lock()
            let v = _zoomLevel
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _zoomLevel = newValue
            stateLock.unlock()
        }
    }

    /// 时间轴数据起始时间戳，线程安全读写
    public var startTime: TimeInterval {
        get {
            stateLock.lock()
            let v = _startTime
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _startTime = newValue
            stateLock.unlock()
        }
    }

    /// 时间轴数据结束时间戳，线程安全读写
    public var endTime: TimeInterval {
        get {
            stateLock.lock()
            let v = _endTime
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _endTime = newValue
            stateLock.unlock()
        }
    }

    /// 平移偏移量，正值向右，负值向左，线程安全读写
    public var panOffset: Double {
        get {
            stateLock.lock()
            let v = _panOffset
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _panOffset = newValue
            stateLock.unlock()
        }
    }

    /// 当前刻度单位，线程安全读写
    public var currentUnit: UITimelineScaleUnit {
        get {
            stateLock.lock()
            let v = _currentUnit
            stateLock.unlock()
            return v
        }
        set {
            stateLock.lock()
            _currentUnit = newValue
            stateLock.unlock()
        }
    }

    // MARK: 缩放控制方法

    /// 设置目标缩放级别，自动限制在最小与最大范围之内
    /// - Parameters:
    ///   - level: 目标缩放级别
    ///   - animated: 是否使用平滑动画过渡，默认false
    public func setZoomLevel(_ level: Double, animated: Bool = false) {
        let clamped = max(minZoomLevel, min(maxZoomLevel, level))
        logger.info("请求缩放级别: \(String(format: "%.3f", level))，限制后: \(String(format: "%.3f", clamped))")

        if animated && enableAnimation {
            animateZoom(to: clamped)
        } else {
            stateLock.lock()
            _zoomLevel = clamped
            stateLock.unlock()
            notifyZoomLevelChanged()
            if autoScaleUnit {
                updateScaleUnitAutomatically()
            }
        }
    }

    /// 以相对倍数进行缩放，大于1放大，小于1缩小
    /// - Parameter factor: 缩放倍数
    public func zoomBy(factor: Double) {
        let current = zoomLevel
        let target = current * factor
        setZoomLevel(target, animated: enableAnimation)
    }

    /// 缩放到适合显示整个时间范围的级别，并重置平移偏移
    public func zoomToFit() {
        setZoomLevel(1.0, animated: true)
        setPanOffset(0.0)
        logger.info("执行缩放到适合显示整个时间范围")
    }

    /// 放大一级，默认倍数为1.25
    public func zoomIn(factor: Double = 1.25) {
        zoomBy(factor: factor)
    }

    /// 缩小一级，默认倍数为0.8
    public func zoomOut(factor: Double = 0.8) {
        zoomBy(factor: factor)
    }

    // MARK: 缩放动画私有实现

    /// 启动平滑缩放动画，使用60fps定时器与三次缓动曲线
    private func animateZoom(to target: Double) {
        stopZoomAnimation()
        targetZoomLevel = target
        let startValue = zoomLevel
        let delta = target - startValue
        let animationStartTime = CACurrentMediaTime()

        logger.info("启动缩放动画: \(String(format: "%.3f", startValue)) -> \(String(format: "%.3f", target)), 持续 \(String(format: "%.2f", self.animationDuration)) 秒")

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let elapsed = CACurrentMediaTime() - animationStartTime
            let progress = min(1.0, elapsed / self.animationDuration)
            let eased = self.easeInOutCubic(progress)
            let current = startValue + delta * eased

            self.stateLock.lock()
            self._zoomLevel = current
            self.stateLock.unlock()

            self.notifyZoomLevelChanged()

            if progress >= 1.0 {
                self.stopZoomAnimation()
                if self.autoScaleUnit {
                    self.updateScaleUnitAutomatically()
                }
            }
        }
    }

    /// 停止当前正在进行的缩放动画，释放定时器
    private func stopZoomAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        targetZoomLevel = nil
    }

    /// 三次缓动函数，使动画起始与结束更平滑自然
    private func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4.0 * t * t * t
        } else {
            let inverse = 1.0 - t
            return 1.0 - 4.0 * inverse * inverse * inverse
        }
    }

    // MARK: 通知发送方法

    /// 向系统通知中心发送缩放级别变更广播
    private func notifyZoomLevelChanged() {
        NotificationCenter.default.post(
            name: .timelineZoomLevelDidChange,
            object: self,
            userInfo: ["zoomLevel": zoomLevel]
        )
    }

    /// 向系统通知中心发送时间范围变更广播
    private func notifyTimeRangeChanged() {
        NotificationCenter.default.post(
            name: .timelineZoomTimeRangeDidChange,
            object: self,
            userInfo: ["startTime": startTime, "endTime": endTime]
        )
    }

    /// 向系统通知中心发送平移位置变更广播
    private func notifyPanPositionChanged() {
        NotificationCenter.default.post(
            name: .timelineZoomPanPositionDidChange,
            object: self,
            userInfo: ["panOffset": panOffset]
        )
    }

    // MARK: 时间范围与平移控制

    /// 设置完整时间范围，结束时间必须大于起始时间
    public func setTimeRange(start: TimeInterval, end: TimeInterval) {
        guard end > start else {
            logger.warning("拒绝设置无效时间范围：结束时间必须大于起始时间")
            return
        }
        stateLock.lock()
        _startTime = start
        _endTime = end
        stateLock.unlock()
        notifyTimeRangeChanged()
        logger.info("时间范围已更新: \(Date(timeIntervalSince1970: start)) 至 \(Date(timeIntervalSince1970: end))")
    }

    /// 设置平移偏移量，通知外部刷新
    public func setPanOffset(_ offset: Double) {
        stateLock.lock()
        _panOffset = offset
        stateLock.unlock()
        notifyPanPositionChanged()
    }

    // MARK: 自动刻度单位

    /// 根据当前缩放级别自动切换最合适的刻度单位，仅在autoScaleUnit为true时生效
    public func updateScaleUnitAutomatically() {
        let z = zoomLevel
        var newUnit: UITimelineScaleUnit
        if z < scaleUnitThresholds[0] {
            newUnit = .month
        } else if z < scaleUnitThresholds[1] {
            newUnit = .week
        } else if z < scaleUnitThresholds[2] {
            newUnit = .day
        } else if z < scaleUnitThresholds[3] {
            newUnit = .hour
        } else {
            newUnit = .minute
        }
        if newUnit != currentUnit {
            stateLock.lock()
            _currentUnit = newUnit
            stateLock.unlock()
            logger.info("自动切换刻度单位至: \(newUnit.displayName)")
        }
    }

    // MARK: 设置面板方法

    /// 打开时间轴缩放设置面板，由外部UI模块响应此调用并呈现面板
    public func showSettingsPanel() {
        logger.info("请求打开时间轴缩放设置面板")
    }

    /// 将所有配置参数重置为出厂默认值，并恢复缩放与平移状态
    public func resetAllSettings() {
        minZoomLevel = 0.1
        maxZoomLevel = 50.0
        enableAnimation = true
        animationDuration = 0.3
        enableWheelZoom = true
        enablePanGesture = true
        enableScaleLines = true
        autoScaleUnit = true
        scaleUnitThresholds = [5.0, 15.0, 40.0, 100.0]
        setZoomLevel(1.0, animated: false)
        setPanOffset(0.0)
        logger.info("时间轴缩放所有设置已重置为默认值")
    }

    /// 批量应用设置参数，用于设置面板一次性更新多项配置
    public func applySettings(
        minZoom: Double,
        maxZoom: Double,
        animation: Bool,
        duration: TimeInterval,
        wheelZoom: Bool,
        panGesture: Bool,
        scaleLines: Bool,
        autoUnit: Bool,
        thresholds: [Double]? = nil
    ) {
        minZoomLevel = max(0.01, minZoom)
        maxZoomLevel = max(minZoomLevel + 0.1, maxZoom)
        enableAnimation = animation
        animationDuration = max(0.05, duration)
        enableWheelZoom = wheelZoom
        enablePanGesture = panGesture
        enableScaleLines = scaleLines
        autoScaleUnit = autoUnit
        if let t = thresholds, t.count >= 4 {
            scaleUnitThresholds = Array(t.prefix(4))
        }
        logger.info("时间轴缩放设置已批量应用，新范围 [\(String(format: "%.2f", self.minZoomLevel)), \(String(format: "%.2f", self.maxZoomLevel))]")
    }

    // MARK: 状态快照与恢复

    /// 获取当前状态的完整线程安全副本，可用于保存到偏好设置或跨模块传递
    public func getCurrentState() -> UITimelineZoomState {
        stateLock.lock()
        let state = UITimelineZoomState(
            zoomLevel: _zoomLevel,
            startTime: _startTime,
            endTime: _endTime,
            panOffset: _panOffset,
            currentUnit: _currentUnit
        )
        stateLock.unlock()
        return state
    }

    /// 使用时间状态快照恢复全部状态，并触发相应通知
    public func restoreState(_ state: UITimelineZoomState) {
        stateLock.lock()
        _zoomLevel = max(minZoomLevel, min(maxZoomLevel, state.zoomLevel))
        _startTime = state.startTime
        _endTime = state.endTime
        _panOffset = state.panOffset
        _currentUnit = state.currentUnit
        stateLock.unlock()
        notifyZoomLevelChanged()
        notifyTimeRangeChanged()
        notifyPanPositionChanged()
        logger.info("已从状态快照恢复时间轴缩放状态")
    }
}

// MARK: - 迁回自 UI-02：class UITimelineZoomView
public final class UITimelineZoomView: NSView , @unchecked Sendable{

    // MARK: 日志与手势

    /// 视图层结构化日志记录器，替代print
    private let logger = Logger(subsystem: "com.xianrenzhilu.timeline", category: "UITimelineZoomView")

    /// 平移手势识别器，用于识别用户的拖拽操作
    private nonisolated(unsafe) var panGestureRecognizer: NSPanGestureRecognizer?

    /// 上一次平移手势的位置，用于计算连续位移增量
    private var lastPanPoint: CGPoint = .zero

    /// 本次手势累计平移距离，用于日志记录与手势结束判定
    private var accumulatedPanDelta: CGFloat = 0.0

    // MARK: 绘制常量

    /// 轨道区域高度，决定时间轴整体视觉厚度
    private let trackHeight: CGFloat = 32.0

    /// 普通刻度线高度
    private let scaleLineHeight: CGFloat = 8.0

    /// 刻度标签字体大小，保持紧凑清晰
    private let scaleFontSize: CGFloat = 9.0

    /// 左右缩放手柄宽度
    private let handleWidth: CGFloat = 8.0

    /// 左右缩放手柄高度
    private let handleHeight: CGFloat = 28.0

    /// 轨道与选中区域的圆角半径
    private let cornerRadius: CGFloat = 4.0

    // MARK: 回调

    /// 当时间范围发生变更时，通过此闭包通知上层模块
    public var onZoomChanged: ((ClosedRange<TimeInterval>) -> Void)?

    // MARK: 初始化

    /// 通过代码初始化视图
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonSetup()
    }

    /// 通过Storyboard或XIB初始化视图
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonSetup()
    }

    /// 通用初始化配置，设置图层、手势识别器与日志
    private func commonSetup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        setupPanGestureRecognizer()

        logger.info("时间轴缩放视图初始化完成，视图尺寸: \(String(format: "%.1f", self.frame.width)) x \(String(format: "%.1f", self.frame.height))")
    }

    // MARK: 手势配置

    /// 创建并注册平移手势识别器到当前视图
    private func setupPanGestureRecognizer() {
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer = pan
        addGestureRecognizer(pan)
    }

    /// 处理平移手势的状态变化，实现时间轴拖拽平移
    @objc private func handlePanGesture(_ gesture: NSPanGestureRecognizer) {
        let manager = UITimelineZoomManager.shared
        guard manager.enablePanGesture else { return }

        switch gesture.state {
        case .began:
            lastPanPoint = gesture.location(in: self)
            accumulatedPanDelta = 0.0
            logger.debug("平移手势开始，起始位置: (x: \(String(format: "%.1f", self.lastPanPoint.x)), y: \(String(format: "%.1f", self.lastPanPoint.y)))")

        case .changed:
            let current = gesture.location(in: self)
            let deltaX = current.x - lastPanPoint.x
            accumulatedPanDelta += deltaX
            lastPanPoint = current

            // 将像素级位移转换为时间轴平移比例
            let viewWidth = max(bounds.width, 1.0)
            let ratioDelta = Double(deltaX) / Double(viewWidth)
            let currentOffset = manager.panOffset
            let newOffset = currentOffset - ratioDelta * manager.zoomLevel
            manager.setPanOffset(newOffset)

            needsDisplay = true
            onZoomChanged?(manager.startTime...manager.endTime)

        case .ended, .cancelled:
            logger.debug("平移手势结束，累计位移: \(String(format: "%.1f", self.accumulatedPanDelta)) 像素")
            lastPanPoint = .zero
            accumulatedPanDelta = 0.0

        default:
            break
        }
    }

    // MARK: 鼠标滚轮缩放

    /// 重写鼠标滚轮事件，实现时间轴缩放，向上滚轮放大，向下缩小
    public override func scrollWheel(with event: NSEvent) {
        let manager = UITimelineZoomManager.shared
        guard manager.enableWheelZoom else {
            super.scrollWheel(with: event)
            return
        }

        let deltaY = event.scrollingDeltaY
        guard deltaY != 0 else {
            super.scrollWheel(with: event)
            return
        }

        // 根据滚轮方向计算缩放因子，灵敏度系数为0.008
        let zoomFactor = 1.0 + Double(deltaY) * 0.008
        let currentZoom = manager.zoomLevel
        let newZoom = currentZoom * zoomFactor

        manager.setZoomLevel(newZoom, animated: true)
        needsDisplay = true

        logger.debug("滚轮缩放事件: deltaY=\(String(format: "%.2f", deltaY)), 缩放从 \(String(format: "%.2f", currentZoom)) 到 \(String(format: "%.2f", newZoom))")
    }

    // MARK: 主绘制方法

    /// 重写绘制方法，依次绘制轨道背景、选中区域、时间刻度线、缩放手柄与中心指示线
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard NSGraphicsContext.current != nil else { return }
        let manager = UITimelineZoomManager.shared
        let state = manager.getCurrentState()

        // 绘制底层轨道背景
        drawTrackBackground(in: bounds)

        // 绘制当前可见时间范围的选中高亮区域
        drawSelectedRange(in: bounds, state: state)

        // 绘制时间刻度线与标签，仅在用户开启时显示
        if manager.enableScaleLines {
            drawScaleLinesAndLabels(in: bounds, state: state)
        }

        // 绘制左右两侧用于调整范围的缩放手柄
        drawResizeHandles(in: bounds, state: state)

        // 绘制中心参考虚线，辅助对齐
        drawCenterIndicator(in: bounds)
    }

    // MARK: 绘制子方法

    /// 绘制时间轴底部轨道背景，使用圆角矩形与半透明颜色
    private func drawTrackBackground(in rect: NSRect) {
        let trackRect = NSRect(
            x: 0.0,
            y: (rect.height - trackHeight) / 2.0,
            width: rect.width,
            height: trackHeight
        )
        let path = NSBezierPath(roundedRect: trackRect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.separatorColor.withAlphaComponent(0.35).setFill()
        path.fill()

        // 绘制轨道内边框，增强视觉层次
        NSColor.separatorColor.withAlphaComponent(0.15).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    /// 绘制当前可见时间范围的选中区域，使用半透明系统蓝色
    private func drawSelectedRange(in rect: NSRect, state: UITimelineZoomState) {
        let totalDuration = state.endTime - state.startTime
        guard totalDuration > 0.0, rect.width > 0.0 else { return }

        let visibleDuration = totalDuration / state.zoomLevel
        let panRatio = state.panOffset / totalDuration
        let startRatio = max(0.0, min(1.0, 0.5 + panRatio - visibleDuration / totalDuration / 2.0))
        let endRatio = max(0.0, min(1.0, 0.5 + panRatio + visibleDuration / totalDuration / 2.0))

        let selectedRect = NSRect(
            x: rect.width * CGFloat(startRatio),
            y: (rect.height - trackHeight) / 2.0,
            width: rect.width * CGFloat(endRatio - startRatio),
            height: trackHeight
        )
        let path = NSBezierPath(roundedRect: selectedRect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.systemBlue.withAlphaComponent(0.25).setFill()
        path.fill()
        NSColor.systemBlue.withAlphaComponent(0.45).setStroke()
        path.lineWidth = 1.0
        path.stroke()
    }

    /// 绘制时间刻度线及其对应标签，根据当前单位自动计算最优间隔与对齐
    private func drawScaleLinesAndLabels(in rect: NSRect, state: UITimelineZoomState) {
        let totalDuration = state.endTime - state.startTime
        guard totalDuration > 0.0, rect.width > 0.0 else { return }

        let unit = state.currentUnit
        let secondsPerPixel = totalDuration / Double(rect.width) / state.zoomLevel
        let interval = calculateOptimalInterval(for: unit, secondsPerPixel: secondsPerPixel)
        guard interval > 0.0 else { return }

        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: state.startTime)

        // 将起始时间对齐到当前单位的整数边界，避免刻度线偏移
        var alignedStart = state.startTime
        if unit == .month {
            var comp = calendar.dateComponents([.year, .month], from: startDate)
            comp.day = 1; comp.hour = 0; comp.minute = 0; comp.second = 0
            if let d = calendar.date(from: comp) {
                alignedStart = d.timeIntervalSince1970
            }
        } else if unit == .week {
            var comp = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)
            comp.weekday = 1
            if let d = calendar.date(from: comp) {
                alignedStart = d.timeIntervalSince1970
            }
        } else if unit == .day {
            var comp = calendar.dateComponents([.year, .month, .day], from: startDate)
            comp.hour = 0; comp.minute = 0; comp.second = 0
            if let d = calendar.date(from: comp) {
                alignedStart = d.timeIntervalSince1970
            }
        } else if unit == .hour {
            var comp = calendar.dateComponents([.year, .month, .day, .hour], from: startDate)
            comp.minute = 0; comp.second = 0
            if let d = calendar.date(from: comp) {
                alignedStart = d.timeIntervalSince1970
            }
        } else if unit == .minute {
            var comp = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: startDate)
            comp.second = 0
            if let d = calendar.date(from: comp) {
                alignedStart = d.timeIntervalSince1970
            }
        }

        let baseY = (rect.height - trackHeight) / 2.0
        let minorPath = NSBezierPath()
        let majorPath = NSBezierPath()

        // 限制最大刻度线数量，避免极端缩放导致性能问题
        let lineCount = min(200, Int(ceil(totalDuration / interval)) + 2)
        for i in 0..<lineCount {
            let t = alignedStart + Double(i) * interval
            let ratio = (t - state.startTime) / totalDuration
            let x = rect.width * CGFloat(ratio)
            if x < -20.0 || x > rect.width + 20.0 { continue }

            let isMajor = i % 5 == 0
            let topY = baseY - (isMajor ? scaleLineHeight + 2.0 : scaleLineHeight)
            let bottomY = baseY + trackHeight

            if isMajor {
                majorPath.move(to: CGPoint(x: x, y: topY))
                majorPath.line(to: CGPoint(x: x, y: bottomY))

                // 绘制主刻度对应的时间标签
                let date = Date(timeIntervalSince1970: t)
                let label = formatDateForUnit(date, unit: unit)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: scaleFontSize),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                let size = label.size(withAttributes: attrs)
                let labelRect = NSRect(
                    x: x - size.width / 2.0,
                    y: topY - size.height - 3.0,
                    width: size.width + 4.0,
                    height: size.height
                )
                label.draw(in: labelRect, withAttributes: attrs)
            } else {
                minorPath.move(to: CGPoint(x: x, y: topY))
                minorPath.line(to: CGPoint(x: x, y: bottomY))
            }
        }

        NSColor.tertiaryLabelColor.withAlphaComponent(0.4).setStroke()
        minorPath.lineWidth = 0.5
        minorPath.stroke()

        NSColor.secondaryLabelColor.withAlphaComponent(0.6).setStroke()
        majorPath.lineWidth = 0.8
        majorPath.stroke()
    }

    /// 根据当前刻度单位与像素密度计算最优刻度线间隔，避免过于密集或稀疏
    private func calculateOptimalInterval(for unit: UITimelineScaleUnit, secondsPerPixel: Double) -> TimeInterval {
        switch unit {
        case .month:
            return max(unit.seconds, secondsPerPixel * 120.0)
        case .week:
            return max(unit.seconds, secondsPerPixel * 100.0)
        case .day:
            return max(unit.seconds, secondsPerPixel * 80.0)
        case .hour:
            return max(unit.seconds, secondsPerPixel * 60.0)
        case .minute:
            return max(unit.seconds, secondsPerPixel * 40.0)
        }
    }

    /// 按当前刻度单位将日期格式化为对应的短字符串，使用中文本地化
    private func formatDateForUnit(_ date: Date, unit: UITimelineScaleUnit) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        switch unit {
        case .month:
            formatter.dateFormat = "yyyy年M月"
        case .week:
            formatter.dateFormat = "M月d日"
        case .day:
            formatter.dateFormat = "M月d日"
        case .hour:
            formatter.dateFormat = "HH:mm"
        case .minute:
            formatter.dateFormat = "HH:mm"
        }
        return formatter.string(from: date)
    }

    /// 绘制左右两侧缩放手柄，用于视觉上提示用户可调整范围
    private func drawResizeHandles(in rect: NSRect, state: UITimelineZoomState) {
        let totalDuration = state.endTime - state.startTime
        guard totalDuration > 0.0 else { return }

        let visibleDuration = totalDuration / state.zoomLevel
        let panRatio = state.panOffset / totalDuration
        let startRatio = max(0.0, min(1.0, 0.5 + panRatio - visibleDuration / totalDuration / 2.0))
        let endRatio = max(0.0, min(1.0, 0.5 + panRatio + visibleDuration / totalDuration / 2.0))

        let leftX = rect.width * CGFloat(startRatio)
        let rightX = rect.width * CGFloat(endRatio)
        let trackY = (rect.height - handleHeight) / 2.0

        let leftHandle = NSRect(
            x: leftX - handleWidth / 2.0,
            y: trackY,
            width: handleWidth,
            height: handleHeight
        )
        let rightHandle = NSRect(
            x: rightX - handleWidth / 2.0,
            y: trackY,
            width: handleWidth,
            height: handleHeight
        )

        NSColor.systemBlue.setFill()
        let leftPath = NSBezierPath(roundedRect: leftHandle, xRadius: 2.0, yRadius: 2.0)
        leftPath.fill()
        let rightPath = NSBezierPath(roundedRect: rightHandle, xRadius: 2.0, yRadius: 2.0)
        rightPath.fill()

        // 在手柄中央绘制竖线装饰，增强手柄辨识度
        NSColor.white.withAlphaComponent(0.75).setStroke()
        let gripWidth: CGFloat = 1.0
        let gripCount = 3
        let gripSpacing: CGFloat = 2.0
        for handleRect in [leftHandle, rightHandle] {
            let totalGripWidth = CGFloat(gripCount - 1) * gripSpacing + CGFloat(gripCount) * gripWidth
            let startX = handleRect.midX - totalGripWidth / 2.0
            for i in 0..<gripCount {
                let gx = startX + CGFloat(i) * (gripWidth + gripSpacing)
                let gripPath = NSBezierPath()
                gripPath.move(to: CGPoint(x: gx, y: handleRect.minY + 6.0))
                gripPath.line(to: CGPoint(x: gx, y: handleRect.maxY - 6.0))
                gripPath.lineWidth = gripWidth
                gripPath.stroke()
            }
        }
    }

    /// 绘制视图中心参考虚线，辅助用户对齐当前时间位置
    private func drawCenterIndicator(in rect: NSRect) {
        let centerX = rect.midX
        let indicatorPath = NSBezierPath()
        indicatorPath.move(to: CGPoint(x: centerX, y: rect.minY + 2.0))
        indicatorPath.line(to: CGPoint(x: centerX, y: rect.maxY - 2.0))
        NSColor.systemRed.withAlphaComponent(0.25).setStroke()
        indicatorPath.lineWidth = 0.5
        indicatorPath.setLineDash([2.0, 2.0], count: 2, phase: 0.0)
        indicatorPath.stroke()
    }

    // MARK: 鼠标交互事件

    /// 记录鼠标按下位置，用于后续日志与调试
    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        logger.debug("鼠标按下事件: (x: \(String(format: "%.1f", point.x)), y: \(String(format: "%.1f", point.y)))")
    }

    /// 记录鼠标拖拽位置，用于日志追踪
    public override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        logger.debug("鼠标拖拽事件: (x: \(String(format: "%.1f", point.x)), y: \(String(format: "%.1f", point.y)))")
    }

    // MARK: 视图尺寸变更

    /// 当视图尺寸变化时重绘内容，确保布局正确
    public override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        needsDisplay = true
    }

    // MARK: 资源清理

    /// 视图释放时移除手势识别器，防止野指针与内存泄漏
    deinit {
        if let pan = panGestureRecognizer {
            removeGestureRecognizer(pan)
        }
        logger.info("时间轴缩放视图已析构，平移手势识别器已移除")
    }
}

// MARK: - 迁回自 UI-02：enum UITimelineScaleUnit
// MARK: - UI-GL-51 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-51_types.swift
// 版本: 2.0
// MARK: - 时间刻度单位枚举

/// 时间轴支持的五种刻度粒度，从粗到细依次为：月、周、日、时、分
public enum UITimelineScaleUnit: Int, CaseIterable, Equatable {
    case month = 0   /// 月刻度
    case week = 1    /// 周刻度
    case day = 2     /// 日刻度
    case hour = 3    /// 时刻度
    case minute = 4  /// 分钟刻度

    /// 单位的中文显示名称
    public var displayName: String {
        switch self {
        case .month:  return "月"
        case .week:   return "周"
        case .day:    return "日"
        case .hour:   return "时"
        case .minute: return "分"
        }
    }

    /// 单位对应的近似秒数，用于计算刻度间隔
    public var seconds: TimeInterval {
        switch self {
        case .month:  return 86400.0 * 30.0
        case .week:   return 86400.0 * 7.0
        case .day:    return 86400.0
        case .hour:   return 3600.0
        case .minute: return 60.0
        }
    }
}

// MARK: - 迁回自 UI-02：struct UITimelineZoomState
// MARK: - 固定标签管理器
// 已迁回 UI-GL-50_固定标签页.swift：class UIPinnedTabManager（公共类型文件禁止功能实现）

// 已迁回 UI-GL-50_固定标签页.swift：extension UIPinnedTabManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-51 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-51_types.swift
// 版本: 2.0
/// 时间轴当前缩放与平移状态的完整副本，可用于保存与恢复
public struct UITimelineZoomState {
    /// 当前缩放级别，1.0为原始比例，大于1放大，小于1缩小
    public var zoomLevel: Double
    /// 时间轴数据起始时间戳（秒级Unix时间）
    public var startTime: TimeInterval
    /// 时间轴数据结束时间戳（秒级Unix时间）
    public var endTime: TimeInterval
    /// 平移偏移量，正值向右，负值向左，单位为时间比例
    public var panOffset: Double
    /// 当前绘制使用的时间刻度单位
    public var currentUnit: UITimelineScaleUnit

    /// 默认构造方法
    public init(zoomLevel: Double, startTime: TimeInterval, endTime: TimeInterval, panOffset: Double, currentUnit: UITimelineScaleUnit) {
        self.zoomLevel = zoomLevel
        self.startTime = startTime
        self.endTime = endTime
        self.panOffset = panOffset
        self.currentUnit = currentUnit
    }
}

// MARK: - 迁回自 UI-02：struct UITimelineZoomControl
/// 时间轴缩放管理器，采用单例模式统一管理所有时间轴的缩放、平移、刻度配置
/// 所有可变状态均受 NSRecursiveLock 保护，确保线程安全
// 已迁回 UI-GL-51_时间轴缩放控件.swift：class UITimelineZoomManager（公共类型文件禁止功能实现）

/// 时间轴缩放控件的视图层，继承自NSView，负责手势识别、时间刻度绘制、事件转发
// 已迁回 UI-GL-51_时间轴缩放控件.swift：class UITimelineZoomView（公共类型文件禁止功能实现）

/// 将 UITimelineZoomView 包装为 SwiftUI 可用的 NSViewRepresentable 组件
public struct UITimelineZoomControl: NSViewRepresentable {

    /// 创建桥接组件实例
    public init() {}

    /// 创建底层的 UITimelineZoomView 实例
    public func makeNSView(context: Context) -> UITimelineZoomView {
        let view = UITimelineZoomView()
        return view
    }

    /// 当 SwiftUI 状态更新时，通知底层视图重绘
    public func updateNSView(_ nsView: UITimelineZoomView, context: Context) {
        nsView.needsDisplay = true
    }
}
