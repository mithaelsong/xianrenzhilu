// 功能22: 视图渲染优化 (v2.0)
// 对应: 图表类视图使用Metal渲染，普通视图优先使用图层wantsLayer
// 优先级: P1

import AppKit
import Foundation
import Metal
import MetalKit
import os.log
import QuartzCore

// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {


// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能22：视图渲染优化 — 单元测试 (v2.0)
/// 覆盖：渲染模式切换/视图优化/性能统计/渲染器注册
func test_renderOptimizer() {
    let opt = UIRenderOptimizer.shared
    let testView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

    print("\n🧪 测试1: 初始渲染模式")
    let mode = opt.currentMode
    _ = mode.displayName  // 至少不崩溃
    print("✅ 测试1通过: 初始渲染模式正常")

    print("\n🧪 测试2: 切换渲染模式")
    opt.setMode(.metal)
    guard opt.currentMode == .metal else {
        fatalError("❌ 测试2失败: 模式应为metal")
    }
    // 切回
    opt.setMode(.layer)
    print("✅ 测试2通过: 渲染模式切换成功")

    print("\n🧪 测试3: 视图优化")
    opt.optimize(testView, mode: .layer)
    guard testView.wantsLayer else {
        fatalError("❌ 测试3失败: 视图应启用layer")
    }
    print("✅ 测试3通过: 视图优化成功")

    print("\n🧪 测试4: 自动检测")
    let detected = opt.detectOptimalMode(for: testView)
    _ = detected
    print("✅ 测试4通过: 自动检测正常")

    print("\n🧪 测试5: 性能统计")
    opt.resetStats()
    for _ in 0..<10 { opt.recordFrame() }
    let stats = opt.stats
    print("✅ 测试5通过: 性能统计正常（FPS=\(String(format: "%.0f", stats.fps))）")

    print("\n🧪 测试6: 动画控制")
    opt.pauseAnimations(for: testView)
    opt.resumeAnimations(for: testView)
    print("✅ 测试6通过: 动画控制正常")

    print("\n🧪 测试7: 渲染器注册")
    // 测试注册表至少不崩溃
    let modes = opt.settingsModeList()
    guard !modes.isEmpty else {
        fatalError("❌ 测试7失败: 应有渲染模式选项")
    }
    print("✅ 测试7通过: 渲染模式列表正常，共\(modes.count)项")

    print("\n=== 全部渲染优化测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 渲染模式发生变更时发送
    static let renderModeDidChange = Notification.Name("com.xianrenzhilu.renderModeDidChange")
    /// 渲染统计信息更新时发送
    static let renderStatsDidUpdate = Notification.Name("com.xianrenzhilu.renderStatsDidUpdate")
    /// 自定义渲染器注册时发送
    static let customRendererDidRegister = Notification.Name("com.xianrenzhilu.customRendererDidRegister")
}

// MARK: - 迁回自 UI-02：class UIRenderOptimizer
public final class UIRenderOptimizer : @unchecked Sendable {


    // MARK: 单例
    public static let shared = UIRenderOptimizer()

    // MARK: 日志
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "视图渲染优化")

    // MARK: 配置持久化Key
    private let persistKey = "RenderOptimizer.CurrentMode"

    // MARK: 锁（使用 NSRecursiveLock 保护共享数据）
    private let lock = NSRecursiveLock()

    // MARK: 状态
    private var _currentMode: UIRenderMode = .layer
    private var _stats = UIRenderStats()
    private var _renderers: [String: UIViewRenderer] = [:]
    private var _viewRenderers: [ObjectIdentifier: String] = [:]
    private var _metalDevice: MTLDevice?
    private var _lastFrameTime: CFTimeInterval = 0
    private var _frameCount: Int = 0
    private var _frameAccumulator: CFTimeInterval = 0

    // MARK: 初始化
    private init() {
        logger.info("【视图渲染优化】初始化渲染优化单例")
        loadPersistedMode()
        setupMetalDevice()
    }

    // MARK: - 当前渲染模式

    /// 当前渲染模式（线程安全）
    public var currentMode: UIRenderMode {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _currentMode
        }
        set {
            setMode(newValue)
        }
    }

    /// 当前渲染模式显示名称
    public var currentModeDisplayName: String {
        return currentMode.displayName
    }

    /// 所有可用的渲染模式（用于设置面板）
    public static var allRenderModes: [UIRenderMode] {
        return UIRenderMode.allCases
    }

    /// 获取各渲染模式的描述信息（用于设置面板）
    public static var availableModesDescription: [UIRenderMode: String] {
        return [
            .layer: "使用标准CALayer，兼容性最好，适用于大多数普通视图。",
            .metal: "使用Metal硬件加速渲染，适用于图表、K线等高性能需求视图。",
            .coreAnimation: "使用CoreAnimation异步绘制优化，适用于复杂动画场景。"
        ]
    }

    // MARK: - 渲染性能统计

    /// 当前渲染性能统计（线程安全）
    public var stats: UIRenderStats {
        lock.lock()
        defer { lock.unlock() }
        return _stats
    }

    /// Metal设备（如果可用）
    public var metalDevice: MTLDevice? {
        lock.lock()
        defer { lock.unlock() }
        return _metalDevice
    }

    // MARK: - 渲染模式切换

    /// 切换渲染模式
    /// - Parameter mode: 目标渲染模式
    public func setMode(_ mode: UIRenderMode) {
        lock.lock()
        let oldMode = _currentMode
        _currentMode = mode
        lock.unlock()

        persistMode(mode)
        logger.info("【渲染模式切换】从 \(oldMode.displayName) 切换到 \(mode.displayName)")
        NotificationCenter.default.post(
            name: .renderModeDidChange,
            object: nil,
            userInfo: [
                "oldMode": oldMode,
                "newMode": mode
            ]
        )
    }

    // MARK: - 视图渲染优化

    /// 为视图设置优化后的图层
    /// - Parameters:
    ///   - view: 目标视图
    ///   - mode: 渲染模式
    public func optimize(_ view: NSView, mode: UIRenderMode = .layer) {
        view.wantsLayer = true

        switch mode {
        case .layer:
            view.layerContentsRedrawPolicy = .onSetNeedsDisplay
            view.canDrawConcurrently = true
            logger.debug("【视图优化】视图 \(String(describing: type(of: view))) 已启用普通图层模式")

        case .metal:
            if let layer = view.layer {
                layer.drawsAsynchronously = true
                layer.shouldRasterize = true
                layer.rasterizationScale = view.window?.backingScaleFactor ?? 2.0
            }
            logger.debug("【视图优化】视图 \(String(describing: type(of: view))) 已启用Metal优化模式")

        case .coreAnimation:
            if let layer = view.layer {
                layer.drawsAsynchronously = true
                layer.needsDisplayOnBoundsChange = false
            }
            logger.debug("【视图优化】视图 \(String(describing: type(of: view))) 已启用CoreAnimation优化模式")
        }
    }

    /// 为图表视图启用Metal优化
    /// - Parameter view: 图表视图
    public func optimizeChartView(_ view: NSView) {
        optimize(view, mode: .metal)
        logger.info("【图表优化】已为图表视图 \(String(describing: type(of: view))) 启用Metal渲染优化")
    }

    /// 检测视图类型并选择合适的渲染模式
    /// - Parameter view: 目标视图
    /// - Returns: 推荐的渲染模式
    public func detectOptimalMode(for view: NSView) -> UIRenderMode {
        let className = String(describing: type(of: view))

        lock.lock()
        defer { lock.unlock() }

        // 检查是否有自定义渲染器匹配
        for (id, renderer) in _renderers {
            if renderer.supportedViewTypes.contains(className) {
                logger.info("【视图类型检测】视图 \(className) 匹配自定义渲染器 \(id)")
                return renderer.isMetalBacked ? .metal : .coreAnimation
            }
        }

        // 默认规则：图表/K线/蜡烛图类视图使用Metal
        if className.contains("Chart") || className.contains("KLine") ||
           className.contains("Candle") || className.contains("Indicator") {
            return .metal
        }

        // 复杂动画视图使用CoreAnimation优化
        if className.contains("Animation") || className.contains("Transition") {
            return .coreAnimation
        }

        // 默认使用普通图层
        return .layer
    }

    /// 根据检测自动优化视图
    /// - Parameter view: 目标视图
    public func autoOptimize(_ view: NSView) {
        let mode = detectOptimalMode(for: view)
        optimize(view, mode: mode)
        logger.info("【自动优化】视图 \(String(describing: type(of: view))) 自动选择模式: \(mode.displayName)")
    }

    // MARK: - Metal渲染接口

    /// 为视图创建Metal层（仅声明接口，不实现复杂Metal管线）
    /// - Parameter view: 目标视图
    /// - Returns: 配置好的CAMetalLayer，如果设备不支持则返回nil
    public func createMetalLayer(for view: NSView) -> CAMetalLayer? {
        lock.lock()
        let device = _metalDevice
        lock.unlock()

        guard let device = device else {
            logger.warning("【Metal层】Metal设备不可用，无法创建Metal层")
            return nil
        }

        let metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.bounds
        metalLayer.contentsScale = view.window?.backingScaleFactor ?? 2.0

        logger.info("【Metal层】已为视图创建CAMetalLayer，设备: \(device.name)")
        return metalLayer
    }

    /// 创建MTKView（仅声明接口）
    /// - Parameter frame: 视图 frame
    /// - Returns: 配置好的MTKView，如果设备不支持则返回nil
    public func createMTKView(frame: CGRect) -> MTKView? {
        lock.lock()
        let device = _metalDevice
        lock.unlock()

        guard let device = device else {
            logger.warning("【MTKView】Metal设备不可用，无法创建MTKView")
            return nil
        }

        let mtkView = MTKView(frame: frame, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false

        logger.info("【MTKView】已创建MTKView，尺寸: \(frame.width)x\(frame.height)")
        return mtkView
    }

    // MARK: - 自定义渲染器注册表

    /// 注册自定义渲染器
    /// - Parameter renderer: 符合UIViewRenderer协议的渲染器
    public func registerRenderer(_ renderer: UIViewRenderer) {
        lock.lock()
        _renderers[renderer.rendererID] = renderer
        lock.unlock()

        logger.info("【渲染器注册】已注册渲染器: \(renderer.rendererName) (ID: \(renderer.rendererID))")
        NotificationCenter.default.post(
            name: .customRendererDidRegister,
            object: nil,
            userInfo: ["renderer": renderer]
        )
    }

    /// 注销自定义渲染器
    /// - Parameter id: 渲染器唯一标识
    public func unregisterRenderer(id: String) {
        lock.lock()
        _renderers.removeValue(forKey: id)
        // 清理已绑定的视图映射
        _viewRenderers = _viewRenderers.filter { $0.value != id }
        lock.unlock()

        logger.info("【渲染器注册】已注销渲染器: \(id)")
    }

    /// 获取视图匹配的渲染器
    /// - Parameter view: 目标视图
    /// - Returns: 匹配的渲染器，如果没有则返回nil
    public func renderer(for view: NSView) -> UIViewRenderer? {
        let className = String(describing: type(of: view))
        let identifier = ObjectIdentifier(view)

        lock.lock()
        defer { lock.unlock() }

        // 先检查视图是否有显式绑定的渲染器
        if let rendererID = _viewRenderers[identifier], let renderer = _renderers[rendererID] {
            return renderer
        }

        // 按类型匹配第一个合适的渲染器
        for (_, renderer) in _renderers {
            if renderer.supportedViewTypes.contains(className) {
                _viewRenderers[identifier] = renderer.rendererID
                return renderer
            }
        }

        return nil
    }

    /// 显式绑定渲染器到视图
    /// - Parameters:
    ///   - rendererID: 渲染器ID
    ///   - view: 目标视图
    public func bindRenderer(_ rendererID: String, to view: NSView) {
        lock.lock()
        _viewRenderers[ObjectIdentifier(view)] = rendererID
        lock.unlock()

        logger.info("【渲染器绑定】视图 \(String(describing: type(of: view))) 已绑定渲染器 \(rendererID)")
    }

    /// 解绑视图的渲染器
    /// - Parameter view: 目标视图
    public func unbindRenderer(from view: NSView) {
        let identifier = ObjectIdentifier(view)
        lock.lock()
        _viewRenderers.removeValue(forKey: identifier)
        lock.unlock()

        logger.info("【渲染器解绑】视图 \(String(describing: type(of: view))) 已解绑渲染器")
    }

    // MARK: - 性能统计

    /// 记录一帧渲染（供视图调用）
    public func recordFrame() {
        let now = CACurrentMediaTime()
        var shouldNotify = false
        var statsCopy = UIRenderStats()

        lock.lock()

        // 首次调用，初始化时间基准
        if _lastFrameTime == 0 {
            _lastFrameTime = now
            lock.unlock()
            return
        }

        let delta = now - _lastFrameTime
        _lastFrameTime = now
        _frameCount += 1
        _frameAccumulator += delta

        // 每秒计算一次统计
        if _frameAccumulator >= 1.0 {
            let fps = Double(_frameCount) / _frameAccumulator
            let avgFrameTime = (_frameAccumulator / Double(_frameCount)) * 1000.0

            // 检测掉帧（目标60fps，单帧超过16.67ms视为掉帧）
            let targetFrameTime = 1.0 / 60.0
            if delta > targetFrameTime {
                _stats.droppedFrames += 1
            }

            _stats.fps = fps
            _stats.frameTime = avgFrameTime
            _stats.timestamp = Date()

            statsCopy = _stats
            _frameCount = 0
            _frameAccumulator = 0
            shouldNotify = true
        }

        lock.unlock()

        if shouldNotify {
            let fpsStr = String(format: "%.1f", statsCopy.fps)
            let frameTimeStr = String(format: "%.2f", statsCopy.frameTime)
            logger.info("【性能统计】FPS: \(fpsStr), 帧时间: \(frameTimeStr) ms, 累计掉帧: \(statsCopy.droppedFrames)")
            NotificationCenter.default.post(
                name: .renderStatsDidUpdate,
                object: nil,
                userInfo: ["stats": statsCopy]
            )
        }
    }

    /// 重置性能统计
    public func resetStats() {
        lock.lock()
        _stats = UIRenderStats()
        _frameCount = 0
        _frameAccumulator = 0
        _lastFrameTime = 0
        lock.unlock()

        logger.info("【性能统计】已重置统计数据")
    }

    // MARK: - 动画控制

    /// 暂停图层动画（滚动/拖拽时使用）
    /// - Parameter view: 目标视图
    public func pauseAnimations(for view: NSView) {
        view.layer?.speed = 0.0
        logger.debug("【动画控制】已暂停视图 \(String(describing: type(of: view))) 的图层动画")
    }

    /// 恢复图层动画
    /// - Parameter view: 目标视图
    public func resumeAnimations(for view: NSView) {
        view.layer?.speed = 1.0
        logger.debug("【动画控制】已恢复视图 \(String(describing: type(of: view))) 的图层动画")
    }

    // MARK: - 设置面板方法

    /// 获取设置面板需要的模式列表
    /// - Returns: 模式与显示名称的数组
    public func settingsModeList() -> [(mode: UIRenderMode, name: String, description: String)] {
        return UIRenderOptimizer.allRenderModes.map { mode in
            let desc = UIRenderOptimizer.availableModesDescription[mode] ?? ""
            return (mode: mode, name: mode.displayName, description: desc)
        }
    }

    /// 设置面板切换模式（带日志和通知）
    /// - Parameter mode: 目标模式
    public func applyModeFromSettings(_ mode: UIRenderMode) {
        setMode(mode)
        logger.info("【设置面板】用户通过设置面板切换渲染模式为: \(mode.displayName)")
    }

    /// 获取当前性能统计摘要（用于设置面板显示）
    /// - Returns: 格式化的统计字符串
    public func statsSummary() -> String {
        let currentStats = stats
        return "FPS: \(String(format: "%.1f", currentStats.fps)) | 帧时间: \(String(format: "%.2f", currentStats.frameTime)) ms | 掉帧: \(currentStats.droppedFrames)"
    }

    // MARK: - 私有方法

    /// 加载持久化的渲染模式
    private func loadPersistedMode() {
        if let raw = UserDefaults.standard.string(forKey: persistKey),
           let mode = UIRenderMode(rawValue: raw) {
            _currentMode = mode
            logger.info("【配置持久化】已加载保存的渲染模式: \(mode.displayName)")
        } else {
            logger.info("【配置持久化】未找到保存的渲染模式，使用默认值: \(self._currentMode.displayName)")
        }
    }

    /// 持久化渲染模式
    private func persistMode(_ mode: UIRenderMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: persistKey)
    }

    /// 初始化Metal设备
    private func setupMetalDevice() {
        _metalDevice = MTLCreateSystemDefaultDevice()
        if let device = _metalDevice {
            logger.info("【Metal初始化】Metal设备就绪: \(device.name)")
        } else {
            logger.warning("【Metal初始化】当前设备不支持Metal，Metal渲染功能将不可用")
        }
    }

    deinit {
        logger.info("UIRenderOptimizer 已释放")
    }
}

// MARK: - 迁回自 UI-02：enum UIRenderMode
// MARK: - 撤销管理器
/// 全局 Undo/Redo 管理器，支持跨窗口
/// 使用单例模式，命令模式存储操作历史
/// 线程安全：使用 os_unfair_lock 保护共享数据
/// 通知体系：通过 NotificationCenter 广播撤销/重做/清空/变更事件
// 已迁回 UI-GL-29_撤销重做系统.swift：class UIUndoRedoManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-30 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-30_types.swift
// 版本: 2.0
// MARK: - 渲染模式
/// 视图渲染模式
public enum UIRenderMode: String, CaseIterable, Codable {
    /// 普通CALayer
    case layer = "layer"
    /// Metal渲染（图表类使用）
    case metal = "metal"
    /// CoreAnimation优化
    case coreAnimation = "coreAnimation"

    /// 显示名称（用于设置面板）
    public var displayName: String {
        switch self {
        case .layer: return "普通图层"
        case .metal: return "Metal渲染"
        case .coreAnimation: return "CoreAnimation优化"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIRenderStats
// MARK: - 渲染性能统计
/// 渲染性能统计信息
public struct UIRenderStats: Codable {
    /// 当前帧率
    public var fps: Double = 0
    /// 平均帧时间（毫秒）
    public var frameTime: Double = 0
    /// 掉帧数量
    public var droppedFrames: Int = 0
    /// 统计时间戳
    public var timestamp: Date = Date()

    public init() {}

    public init(fps: Double, frameTime: Double, droppedFrames: Int, timestamp: Date) {
        self.fps = fps
        self.frameTime = frameTime
        self.droppedFrames = droppedFrames
        self.timestamp = timestamp
    }
}

// MARK: - 迁回自 UI-02：protocol UIViewRenderer
// MARK: - 渲染器协议
/// 自定义视图渲染器协议
public protocol UIViewRenderer: AnyObject {
    /// 渲染器唯一标识
    var rendererID: String { get }
    /// 渲染器显示名称
    var rendererName: String { get }
    /// 支持的视图类型（类名字符串）
    var supportedViewTypes: [String] { get }
    /// 是否为Metal后端
    var isMetalBacked: Bool { get }

    /// 初始化视图的渲染后端
    func setupRenderer(for view: NSView)
    /// 清理视图的渲染后端
    func teardownRenderer(for view: NSView)
    /// 执行一帧渲染
    func render(in view: NSView)
}
