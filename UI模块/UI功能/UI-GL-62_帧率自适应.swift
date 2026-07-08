// 功能52: 帧率自适应管理器
// 说明: 根据当前操作状态和CPU负载自适应调整渲染帧率，防止界面卡顿，优化能耗
// 对应: 静止时降低刷新率，交互时恢复到最高帧率
// 优先级: P2

import AppKit
import Foundation
import QuartzCore
import os.log

// 类型定义已迁移至 /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-62_types.swift（版本 2.0）

// MARK: - 测试代码
#if DEBUG

/// 功能52：帧率自适应 — 单元测试
func test_frameRate() {
    let manager = UIAdaptiveFrameRateManager.shared
    let logger = OSLog(subsystem: "com.xianrenzhilu.ui", category: "UI-GL-62")
    
    os_log("测试1: 默认配置", log: logger, type: .info)
    if manager.config.performanceLevel == .balanced { os_log("✅ 测试1通过", log: logger, type: .info) }
    else { os_log("❌ 测试1失败: %{public}@", log: logger, type: .error, manager.config.performanceLevel.rawValue) }
    
    os_log("测试2: 帧率查询", log: logger, type: .info)
    let fps = manager.currentFrameRate
    if fps > 0 { os_log("✅ 测试2通过: %{public}ffps", log: logger, type: .info, fps) }
    else { os_log("❌ 测试2失败", log: logger, type: .error) }
    
    os_log("测试3: 设置性能等级", log: logger, type: .info)
    manager.setPerformanceLevel(.performance)
    if manager.currentPerformanceLevel == .performance { os_log("✅ 测试3通过", log: logger, type: .info) }
    else { os_log("❌ 测试3失败", log: logger, type: .error) }
    
    os_log("测试4: 设置渲染策略", log: logger, type: .info)
    manager.setRenderStrategy(.fixed)
    if manager.currentRenderStrategy == .fixed { os_log("✅ 测试4通过", log: logger, type: .info) }
    else { os_log("❌ 测试4失败", log: logger, type: .error) }
    
    os_log("测试5: 交互开始/结束", log: logger, type: .info)
    manager.beginInteraction()
    manager.endInteraction()
    os_log("✅ 测试5通过", log: logger, type: .info)
    
    os_log("测试6: 配置更新", log: logger, type: .info)
    let newConfig = UIAdaptiveFrameRateConfig(performanceLevel: .extreme, renderStrategy: .adaptive)
    manager.updateConfig(newConfig)
    let updated = manager.config
    if updated.performanceLevel == .extreme { os_log("✅ 测试6通过", log: logger, type: .info) }
    else { os_log("❌ 测试6失败", log: logger, type: .error) }
    
    os_log("测试7: 重置", log: logger, type: .info)
    manager.resetToDefaults()
    let reset = manager.config
    if reset.performanceLevel == .balanced { os_log("✅ 测试7通过", log: logger, type: .info) }
    else { os_log("❌ 测试7失败", log: logger, type: .error) }
    
    os_log("测试8: CPU负载读取", log: logger, type: .info)
    let load = manager.currentCPULoad
    _ = load
    os_log("✅ 测试8通过", log: logger, type: .info)
    
    os_log("=== 全部帧率自适应测试通过 ✅ ===", log: logger, type: .info)
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 帧率发生变更时发送的通知，object为新的帧率值（Double）
    static let adaptiveFrameRateChanged = Notification.Name("AdaptiveFrameRateChanged")
    /// 性能等级发生变更时发送的通知，object为新的UIPerformanceLevel（String）
    static let adaptivePerformanceLevelChanged = Notification.Name("AdaptivePerformanceLevelChanged")
    /// 渲染策略发生变更时发送的通知，object为新的渲染策略（String）
    static let adaptiveRenderStrategyChanged = Notification.Name("AdaptiveRenderStrategyChanged")
}

// MARK: - 迁回自 UI-02：class UIAdaptiveFrameRateManager
public final class UIAdaptiveFrameRateManager : @unchecked Sendable {
    
    // MARK: - 单例实例
    /// 全局共享的帧率自适应管理器实例
    public static let shared = UIAdaptiveFrameRateManager()
    
    // MARK: - 日志记录器
    /// 使用OSLog的Logger，替代print，支持子系统和分类过滤
    private static let logger = Logger(
        subsystem: "com.xianrenzhilu.UI",
        category: "AdaptiveFrameRate"
    )
    
    // MARK: - 同步锁
    /// 使用NSRecursiveLock保护共享数据
    private let lock = NSRecursiveLock()
    
    // MARK: - 定时器与监控
    /// 性能检测定时器，用于周期性执行CPU负载采样和帧率调整
    private nonisolated(unsafe) var samplingTimer: Timer?
    /// 帧率刷新定时器，用于控制实际渲染频率
    private nonisolated(unsafe) var frameTimer: Timer?
    /// 交互超时检测器，交互结束后延迟一段时间才降级帧率
    private nonisolated(unsafe) var interactionTimeout: Timer?
    /// 交互状态标志，表示当前是否处于用户交互中（如拖拽、滚动、动画等）
    private var isInInteraction: Bool = false
    /// 连续CPU高负载计数，达到降级阈值时触发降级
    private var consecutiveHighCPUCount: Int = 0
    /// 连续CPU低负载计数，达到升级阈值时触发升级
    private var consecutiveLowCPUCount: Int = 0
    
    // MARK: - 配置数据
    /// 当前帧率配置，受lock保护，使用Codable支持持久化
    private nonisolated(unsafe) var _config: UIAdaptiveFrameRateConfig
    
    /// 当前配置的安全访问器（线程安全）
    public var config: UIAdaptiveFrameRateConfig {
        lock.lock()
        let c = _config
        lock.unlock()
        return c
    }
    
    // MARK: - 状态数据
    /// 当前实际帧率（每秒渲染次数），受lock保护
    private var _currentFrameRate: Double
    
    /// 当前实际帧率的安全访问器（线程安全）
    public var currentFrameRate: Double {
        lock.lock()
        let v = _currentFrameRate
        lock.unlock()
        return v
    }
    
    /// 当前性能等级，受lock保护
    private var _currentPerformanceLevel: UIPerformanceLevel
    
    /// 当前性能等级的安全访问器（线程安全）
    public var currentPerformanceLevel: UIPerformanceLevel {
        lock.lock()
        let v = _currentPerformanceLevel
        lock.unlock()
        return v
    }
    
    /// 当前渲染策略，受lock保护
    private var _currentRenderStrategy: UIRenderStrategy
    
    /// 当前渲染策略的安全访问器（线程安全）
    public var currentRenderStrategy: UIRenderStrategy {
        lock.lock()
        let v = _currentRenderStrategy
        lock.unlock()
        return v
    }
    
    /// 最近一次CPU负载采样值（0.0 ~ 1.0），受lock保护
    private var _currentCPULoad: Double
    
    /// 最近一次CPU负载采样值的安全访问器（线程安全）
    public var currentCPULoad: Double {
        lock.lock()
        let v = _currentCPULoad
        lock.unlock()
        return v
    }
    
    /// CPU负载历史采样记录（保留最近100条），受lock保护
    private var _cpuLoadHistory: [UICPULoadSample]
    
    /// CPU负载历史采样记录的安全访问器（线程安全，返回副本）
    public var cpuLoadHistory: [UICPULoadSample] {
        lock.lock()
        let v = Array(_cpuLoadHistory)
        lock.unlock()
        return v
    }
    
    /// 是否正在运行（已启动定时器），受lock保护
    private var _isRunning: Bool
    
    /// 是否处于交互中，受lock保护
    private var _isInInteraction: Bool = false
    
    /// 是否正在运行的安全访问器（线程安全）
    public var isRunning: Bool {
        lock.lock()
        let v = _isRunning
        lock.unlock()
        return v
    }
    
    // MARK: - 配置持久化路径
    /// 配置文件在用户应用支持目录中的存储路径
    private var configFilePath: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appFolder = appSupport.appendingPathComponent("XianRenZhiLu", isDirectory: true)
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("FrameRateConfig.json")
    }
    
    // MARK: - 初始化与销毁
    
    /// 私有初始化器，确保单例模式
    private init() {
        // 先尝试从持久化文件加载配置，失败则使用默认配置
        if let loaded = UIAdaptiveFrameRateManager.loadConfigFromDisk() {
            self._config = loaded
            Self.logger.info("[帧率自适应] 已从磁盘加载配置: 等级=\(loaded.performanceLevel.rawValue), 策略=\(loaded.renderStrategy.rawValue)")
        } else {
            self._config = UIAdaptiveFrameRateConfig.default
            Self.logger.info("[帧率自适应] 使用默认配置初始化")
        }
        
        // 初始化状态数据
        self._currentPerformanceLevel = self._config.performanceLevel
        self._currentRenderStrategy = self._config.renderStrategy
        self._currentFrameRate = self._config.performanceLevel.defaultFrameRate
        self._currentCPULoad = 0.0
        self._cpuLoadHistory = []
        self._isRunning = false
        
        // 注册系统通知：应用进入前台/后台时调整帧率策略
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        Self.logger.info("[帧率自适应] 管理器初始化完成，初始帧率: \(self._currentFrameRate)fps")
    }
    
    /// 析构函数，清理所有资源、定时器和通知监听
    deinit {
        // 停止所有定时器
        stop()
        
        // 移除所有通知监听
        NotificationCenter.default.removeObserver(self)
        
        // 保存当前配置到磁盘
        saveConfigToDisk()
        
        Self.logger.info("[帧率自适应] 管理器已销毁，配置已保存")
    }
    
    // MARK: - 应用状态监听
    
    /// 应用进入前台时调用，恢复帧率监控
    @objc private func handleApplicationDidBecomeActive() {
        Self.logger.info("[帧率自适应] 应用进入前台，恢复帧率监控")
        if config.autoDetectionEnabled {
            start()
        }
    }
    
    /// 应用进入后台时调用，降低帧率以节省资源
    @objc private func handleApplicationDidResignActive() {
        Self.logger.info("[帧率自适应] 应用进入后台，降低帧率至节能模式")
        // 后台运行时强制进入节能模式
        lock.lock()
        let oldLevel = _currentPerformanceLevel
        _currentPerformanceLevel = .powerSaving
        let newRate = UIPerformanceLevel.powerSaving.defaultFrameRate
        _currentFrameRate = newRate
        lock.unlock()
        
        if oldLevel != .powerSaving {
            postPerformanceLevelChangedNotification(level: .powerSaving)
        }
        postFrameRateChangedNotification(frameRate: newRate)
    }
    
    // MARK: - 启动与停止
    
    /// 启动帧率自适应系统，开始CPU负载采样和帧率调整
    public func start() {
        lock.lock()
        guard !_isRunning else {
            lock.unlock()
            Self.logger.info("[帧率自适应] 系统已在运行中，无需重复启动")
            return
        }
        _isRunning = true
        let interval = _config.samplingInterval
        lock.unlock()
        
        // 在主线程创建定时器
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 创建CPU采样定时器
            self.samplingTimer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: true
            ) { [weak self] _ in
                self?.performSampling()
            }
            // 立即执行一次采样
            self.performSampling()
            Self.logger.info("[帧率自适应] 系统已启动，采样间隔: \(interval)s")
        }
    }
    
    /// 停止帧率自适应系统，清理所有定时器
    public func stop() {
        lock.lock()
        _isRunning = false
        lock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.samplingTimer?.invalidate()
            self.samplingTimer = nil
            self.frameTimer?.invalidate()
            self.frameTimer = nil
            self.interactionTimeout?.invalidate()
            self.interactionTimeout = nil
            Self.logger.info("[帧率自适应] 系统已停止")
        }
    }
    
    // MARK: - 交互状态管理
    
    /// 标记交互开始（用户开始拖拽、滚动、点击等操作）
    /// 交互期间会提升帧率以确保流畅度
    public func beginInteraction() {
        lock.lock()
        _isInInteraction = true
        // 取消交互超时定时器
        lock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            self?.interactionTimeout?.invalidate()
            self?.interactionTimeout = nil
        }
        
        // 根据策略调整帧率
        updateFrameRateForInteraction()
        Self.logger.info("[帧率自适应] 交互开始，提升帧率")
    }
    
    /// 标记交互结束（用户停止操作）
    /// 延迟一段时间后才会降级帧率，防止频繁切换
    public func endInteraction() {
        lock.lock()
        _isInInteraction = false
        let delay: TimeInterval = 2.0 // 交互结束后2秒才降级
        lock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.interactionTimeout?.invalidate()
            self.interactionTimeout = Timer.scheduledTimer(
                withTimeInterval: delay,
                repeats: false
            ) { [weak self] _ in
                self?.handleInteractionTimeout()
            }
        }
        
        Self.logger.info("[帧率自适应] 交互结束，将在\(delay)秒后降级帧率")
    }
    
    /// 交互超时回调，实际执行帧率降级
    /// 自动应用帧率调整（内部方法）
    private func applyAutoFrameRate() {
        // 根据当前策略和性能等级自动计算并应用帧率
        lock.lock()
        let level = _currentPerformanceLevel
        let strategy = _currentRenderStrategy
        lock.unlock()
        
        switch strategy {
        case .fixed:
            break
        case .adaptive:
            _currentFrameRate = level.defaultFrameRate
        case .interactionPriority:
            _currentFrameRate = UIPerformanceLevel.extreme.defaultFrameRate
        case .powerPriority:
            _currentFrameRate = UIPerformanceLevel.powerSaving.defaultFrameRate
        }
    }
    
    private func handleInteractionTimeout() {
        lock.lock()
        guard !_isInInteraction else {
            lock.unlock()
            return // 交互重新开始，不降级
        }
        lock.unlock()
        
        applyAutoFrameRate()
        Self.logger.info("[帧率自适应] 交互超时，已降级帧率")
    }
    
    // MARK: - CPU负载监控
    
    /// 执行一次CPU负载采样
    private func performSampling() {
        let cpuLoad = readCurrentCPULoad()
        
        lock.lock()
        _currentCPULoad = cpuLoad.total
        let sample = UICPULoadSample(
            timestamp: Date(),
            load: cpuLoad.total,
            userLoad: cpuLoad.user,
            systemLoad: cpuLoad.system
        )
        _cpuLoadHistory.append(sample)
        // 只保留最近100条记录，防止内存无限增长
        if _cpuLoadHistory.count > 100 {
            _cpuLoadHistory.removeFirst(_cpuLoadHistory.count - 100)
        }
        let autoDetection = _config.autoDetectionEnabled
        _ = _currentPerformanceLevel
        let strategy = _currentRenderStrategy
        lock.unlock()
        
        // 记录采样日志
        Self.logger.debug("[帧率自适应] CPU采样: 总负载\(String(format: "%.1f", cpuLoad.total * 100))% 用户\(String(format: "%.1f", cpuLoad.user * 100))% 系统\(String(format: "%.1f", cpuLoad.system * 100))%")
        
        // 如果启用了自动检测且策略为自适应，执行性能等级自动调整
        if autoDetection && strategy == .adaptive {
            evaluatePerformanceLevel(cpuLoad: cpuLoad.total)
        }
        
        // 根据当前策略应用帧率
        applyFrameRateByStrategy()
    }
    
    /// 读取当前CPU负载信息
    /// 返回(total, user, system)三个值，范围均为0.0~1.0
    private func readCurrentCPULoad() -> (total: Double, user: Double, system: Double) {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &loadInfo) { loadInfoPtr in
            loadInfoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, ptr, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            Self.logger.error("[帧率自适应] 读取CPU负载失败，错误码: \(result)")
            return (0.0, 0.0, 0.0)
        }
        
        let totalTicks = Double(loadInfo.cpu_ticks.0 + loadInfo.cpu_ticks.1 + loadInfo.cpu_ticks.2 + loadInfo.cpu_ticks.3)
        guard totalTicks > 0 else {
            return (0.0, 0.0, 0.0)
        }
        
        let user = Double(loadInfo.cpu_ticks.0) / totalTicks
        let system = Double(loadInfo.cpu_ticks.1) / totalTicks
        let idle = Double(loadInfo.cpu_ticks.2) / totalTicks
        let total = 1.0 - idle
        
        return (total, user, system)
    }
    
    /// 评估当前性能等级，根据CPU负载决定是否升级或降级
    private func evaluatePerformanceLevel(cpuLoad: Double) {
        lock.lock()
        let currentLevel = _currentPerformanceLevel
        let downgradeThreshold = _config.downgradeThreshold
        let upgradeThreshold = _config.upgradeThreshold
        lock.unlock()
        
        let cpuThreshold = currentLevel.cpuThreshold
        
        if cpuLoad > cpuThreshold {
            // CPU负载过高，增加降级计数
            lock.lock()
            consecutiveHighCPUCount += 1
            consecutiveLowCPUCount = 0
            let highCount = consecutiveHighCPUCount
            lock.unlock()
            
            Self.logger.info("[帧率自适应] CPU负载过高: \(String(format: "%.1f", cpuLoad * 100))% > \(String(format: "%.1f", cpuThreshold * 100))%，降级计数: \(highCount)/\(downgradeThreshold)")
            
            if highCount >= downgradeThreshold {
                // 触发降级
                downgradePerformanceLevel()
            }
        } else if cpuLoad < cpuThreshold * 0.7 {
            // CPU负载较低，增加升级计数（使用阈值的70%作为升级门槛，避免频繁切换）
            lock.lock()
            consecutiveLowCPUCount += 1
            consecutiveHighCPUCount = 0
            let lowCount = consecutiveLowCPUCount
            lock.unlock()
            
            if lowCount >= upgradeThreshold {
                // 触发升级
                upgradePerformanceLevel()
            }
        } else {
            // CPU负载处于正常范围，重置计数器
            lock.lock()
            consecutiveHighCPUCount = 0
            consecutiveLowCPUCount = 0
            lock.unlock()
        }
    }
    
    /// 降级性能等级（性能→平衡→节能）
    private func downgradePerformanceLevel() {
        lock.lock()
        let oldLevel = _currentPerformanceLevel
        let newLevel: UIPerformanceLevel
        switch oldLevel {
        case .extreme:      newLevel = .performance
        case .performance:  newLevel = .balanced
        case .balanced:     newLevel = .powerSaving
        case .powerSaving:  newLevel = .powerSaving // 最低档不再降级
        }
        _currentPerformanceLevel = newLevel
        consecutiveHighCPUCount = 0
        consecutiveLowCPUCount = 0
        lock.unlock()
        
        if oldLevel != newLevel {
            Self.logger.info("[帧率自适应] 性能等级降级: \(oldLevel.rawValue) → \(newLevel.rawValue)")
            postPerformanceLevelChangedNotification(level: newLevel)
            applyFrameRateByStrategy()
        }
    }
    
    /// 升级性能等级（节能→平衡→性能→极速）
    private func upgradePerformanceLevel() {
        lock.lock()
        let oldLevel = _currentPerformanceLevel
        let newLevel: UIPerformanceLevel
        switch oldLevel {
        case .powerSaving:  newLevel = .balanced
        case .balanced:     newLevel = .performance
        case .performance:  newLevel = .extreme
        case .extreme:      newLevel = .extreme // 最高档不再升级
        }
        _currentPerformanceLevel = newLevel
        consecutiveHighCPUCount = 0
        consecutiveLowCPUCount = 0
        lock.unlock()
        
        if oldLevel != newLevel {
            Self.logger.info("[帧率自适应] 性能等级升级: \(oldLevel.rawValue) → \(newLevel.rawValue)")
            postPerformanceLevelChangedNotification(level: newLevel)
            applyFrameRateByStrategy()
        }
    }
    
    // MARK: - 帧率应用逻辑
    
    /// 根据当前策略应用对应的帧率
    private func applyFrameRateByStrategy() {
        lock.lock()
        let strategy = _currentRenderStrategy
        lock.unlock()
        
        switch strategy {
        case .fixed:
            applyFixedFrameRate()
        case .adaptive:
            applyAdaptiveFrameRate()
        case .interactionPriority:
            applyInteractionPriorityFrameRate()
        case .powerPriority:
            applyPowerPriorityFrameRate()
        }
    }
    
    /// 固定策略：使用用户设置的固定帧率
    private func applyFixedFrameRate() {
        lock.lock()
        let customRate = _config.customFrameRate
        let newRate = customRate > 0 ? customRate : _currentPerformanceLevel.defaultFrameRate
        let oldRate = _currentFrameRate
        _currentFrameRate = newRate
        lock.unlock()
        
        if abs(oldRate - newRate) > 0.1 {
            Self.logger.info("[帧率自适应] 固定帧率模式: 帧率设置为 \(String(format: "%.1f", newRate))fps")
            postFrameRateChangedNotification(frameRate: newRate)
        }
    }
    
    /// 自适应策略：综合考虑交互状态和性能等级
    private func applyAdaptiveFrameRate() {
        lock.lock()
        let inInteraction = _isInInteraction
        let level = _currentPerformanceLevel
        let oldRate = _currentFrameRate
        lock.unlock()
        
        let newRate: Double
        if inInteraction {
            // 交互中使用更高一档的帧率（但不超过极速）
            switch level {
            case .powerSaving:  newRate = UIPerformanceLevel.balanced.defaultFrameRate
            case .balanced:     newRate = UIPerformanceLevel.performance.defaultFrameRate
            case .performance:  newRate = UIPerformanceLevel.extreme.defaultFrameRate
            case .extreme:    newRate = UIPerformanceLevel.extreme.defaultFrameRate
            }
        } else {
            newRate = level.defaultFrameRate
        }
        
        lock.lock()
        _currentFrameRate = newRate
        lock.unlock()
        
        if abs(oldRate - newRate) > 0.1 {
            Self.logger.info("[帧率自适应] 自适应模式: 帧率 \(String(format: "%.1f", oldRate)) → \(String(format: "%.1f", newRate))fps (交互=\(inInteraction))")
            postFrameRateChangedNotification(frameRate: newRate)
        }
    }
    
    /// 交互优先策略：只要有交互就锁定最高帧率
    private func applyInteractionPriorityFrameRate() {
        lock.lock()
        let inInteraction = _isInInteraction
        let oldRate = _currentFrameRate
        lock.unlock()
        
        let newRate = inInteraction ? UIPerformanceLevel.extreme.defaultFrameRate : UIPerformanceLevel.balanced.defaultFrameRate
        
        lock.lock()
        _currentFrameRate = newRate
        lock.unlock()
        
        if abs(oldRate - newRate) > 0.1 {
            Self.logger.info("[帧率自适应] 交互优先模式: 帧率 \(String(format: "%.1f", oldRate)) → \(String(format: "%.1f", newRate))fps")
            postFrameRateChangedNotification(frameRate: newRate)
        }
    }
    
    /// 节能优先策略：优先考虑降低帧率
    private func applyPowerPriorityFrameRate() {
        lock.lock()
        let inInteraction = _isInInteraction
        let oldRate = _currentFrameRate
        lock.unlock()
        
        let newRate = inInteraction ? UIPerformanceLevel.balanced.defaultFrameRate : UIPerformanceLevel.powerSaving.defaultFrameRate
        
        lock.lock()
        _currentFrameRate = newRate
        lock.unlock()
        
        if abs(oldRate - newRate) > 0.1 {
            Self.logger.info("[帧率自适应] 节能优先模式: 帧率 \(String(format: "%.1f", oldRate)) → \(String(format: "%.1f", newRate))fps")
            postFrameRateChangedNotification(frameRate: newRate)
        }
    }
    
    /// 交互期间的帧率更新（单独处理，不依赖定时器）
    private func updateFrameRateForInteraction() {
        lock.lock()
        let strategy = _currentRenderStrategy
        lock.unlock()
        
        switch strategy {
        case .fixed:
            // 固定策略不受交互影响
            break
        case .adaptive, .interactionPriority:
            applyFrameRateByStrategy()
        case .powerPriority:
            applyFrameRateByStrategy()
        }
    }
    
    /// 公共接口：手动触发一次帧率重新计算
    public func refreshFrameRate() {
        applyFrameRateByStrategy()
    }
    
    // MARK: - 通知发送
    
    /// 发送帧率变更通知
    private func postFrameRateChangedNotification(frameRate: Double) {
        NotificationCenter.default.post(
            name: .adaptiveFrameRateChanged,
            object: self,
            userInfo: ["frameRate": frameRate, "timestamp": Date()]
        )
    }
    
    /// 发送性能等级变更通知
    private func postPerformanceLevelChangedNotification(level: UIPerformanceLevel) {
        NotificationCenter.default.post(
            name: .adaptivePerformanceLevelChanged,
            object: self,
            userInfo: ["performanceLevel": level.rawValue, "timestamp": Date()]
        )
    }
    
    /// 发送渲染策略变更通知
    private func postRenderStrategyChangedNotification(strategy: UIRenderStrategy) {
        NotificationCenter.default.post(
            name: .adaptiveRenderStrategyChanged,
            object: self,
            userInfo: ["renderStrategy": strategy.rawValue, "timestamp": Date()]
        )
    }
    
    // MARK: - 配置管理
    
    /// 更新完整配置
    public func updateConfig(_ newConfig: UIAdaptiveFrameRateConfig) {
        lock.lock()
        let oldStrategy = _config.renderStrategy
        _config = newConfig
        _currentPerformanceLevel = newConfig.performanceLevel
        _currentRenderStrategy = newConfig.renderStrategy
        lock.unlock()
        
        // 保存配置到磁盘
        saveConfigToDisk()
        
        // 如果策略变化，发送通知
        if oldStrategy != newConfig.renderStrategy {
            postRenderStrategyChangedNotification(strategy: newConfig.renderStrategy)
        }
        
        Self.logger.info("[帧率自适应] 配置已更新: 等级=\(newConfig.performanceLevel.rawValue), 策略=\(newConfig.renderStrategy.rawValue), 自动检测=\(newConfig.autoDetectionEnabled)")
        
        // 根据新配置重新应用帧率
        applyFrameRateByStrategy()
        
        // 如果启用了自动检测且系统未运行，自动启动
        if newConfig.autoDetectionEnabled && !isRunning {
            start()
        }
        // 如果禁用了自动检测且系统正在运行，自动停止
        if !newConfig.autoDetectionEnabled && isRunning {
            stop()
        }
    }
    
    /// 设置性能等级
    public func setPerformanceLevel(_ level: UIPerformanceLevel) {
        lock.lock()
        var newConfig = _config
        newConfig.performanceLevel = level
        _config = newConfig
        let oldLevel = _currentPerformanceLevel
        _currentPerformanceLevel = level
        lock.unlock()
        
        saveConfigToDisk()
        
        if oldLevel != level {
            postPerformanceLevelChangedNotification(level: level)
        }
        
        Self.logger.info("[帧率自适应] 手动设置性能等级: \(level.rawValue)")
        applyFrameRateByStrategy()
    }
    
    /// 设置渲染策略
    public func setRenderStrategy(_ strategy: UIRenderStrategy) {
        lock.lock()
        var newConfig = _config
        newConfig.renderStrategy = strategy
        _config = newConfig
        let oldStrategy = _currentRenderStrategy
        _currentRenderStrategy = strategy
        lock.unlock()
        
        saveConfigToDisk()
        
        if oldStrategy != strategy {
            postRenderStrategyChangedNotification(strategy: strategy)
        }
        
        Self.logger.info("[帧率自适应] 手动设置渲染策略: \(strategy.rawValue)")
        applyFrameRateByStrategy()
    }
    
    /// 设置是否启用自动检测
    public func setAutoDetectionEnabled(_ enabled: Bool) {
        lock.lock()
        var newConfig = _config
        newConfig.autoDetectionEnabled = enabled
        _config = newConfig
        lock.unlock()
        
        saveConfigToDisk()
        
        Self.logger.info("[帧率自适应] 自动检测: \(enabled ? "开启" : "关闭")")
        
        if enabled && !isRunning {
            start()
        } else if !enabled && isRunning {
            stop()
        }
    }
    
    /// 设置自定义固定帧率（仅固定策略有效）
    public func setCustomFrameRate(_ rate: Double) {
        lock.lock()
        var newConfig = _config
        newConfig.customFrameRate = max(1.0, min(240.0, rate))
        _config = newConfig
        lock.unlock()
        
        saveConfigToDisk()
        Self.logger.info("[帧率自适应] 设置自定义帧率: \(String(format: "%.1f", rate))fps")
        applyFrameRateByStrategy()
    }
    
    /// 重置配置为默认值
    public func resetToDefaults() {
        lock.lock()
        _config = UIAdaptiveFrameRateConfig.default
        _currentPerformanceLevel = .balanced
        _currentRenderStrategy = .adaptive
        consecutiveHighCPUCount = 0
        consecutiveLowCPUCount = 0
        lock.unlock()
        
        saveConfigToDisk()
        Self.logger.info("[帧率自适应] 配置已重置为默认值")
        applyFrameRateByStrategy()
    }
    
    // MARK: - 配置持久化
    
    /// 将当前配置保存到磁盘（JSON格式）
    private func saveConfigToDisk() {
        lock.lock()
        let configToSave = _config
        lock.unlock()
        
        do {
            let data = try JSONEncoder().encode(configToSave)
            try data.write(to: configFilePath, options: .atomic)
            Self.logger.info("[帧率自适应] 配置已保存到磁盘")
        } catch {
            Self.logger.error("[帧率自适应] 保存配置失败: \(error.localizedDescription)")
        }
    }
    
    /// 从磁盘加载配置（JSON格式）
    private static func loadConfigFromDisk() -> UIAdaptiveFrameRateConfig? {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let configPath = appSupport
            .appendingPathComponent("XianRenZhiLu", isDirectory: true)
            .appendingPathComponent("FrameRateConfig.json")
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: configPath)
            let config = try JSONDecoder().decode(UIAdaptiveFrameRateConfig.self, from: data)
            return config
        } catch {
            logger.error("[帧率自适应] 加载配置失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 设置面板方法（供UI调用）
    
    /// 获取所有可用的性能等级选项（供设置面板下拉选择）
    public func availablePerformanceLevels() -> [UIPerformanceLevel] {
        return UIPerformanceLevel.allCases.sorted { $0.displayPriority < $1.displayPriority }
    }
    
    /// 获取所有可用的渲染策略选项（供设置面板下拉选择）
    public func availableRenderStrategies() -> [UIRenderStrategy] {
        return UIRenderStrategy.allCases
    }
    
    /// 获取当前性能等级的显示名称（供设置面板显示）
    public func currentPerformanceLevelName() -> String {
        return currentPerformanceLevel.rawValue
    }
    
    /// 获取当前渲染策略的显示名称（供设置面板显示）
    public func currentRenderStrategyName() -> String {
        return currentRenderStrategy.rawValue
    }
    
    /// 获取当前帧率的显示字符串（供设置面板显示）
    public func currentFrameRateDisplay() -> String {
        return String(format: "%.1f fps", currentFrameRate)
    }
    
    /// 获取当前CPU负载的显示字符串（供设置面板显示）
    public func currentCPULoadDisplay() -> String {
        return String(format: "%.1f%%", currentCPULoad * 100)
    }
    
    /// 获取CPU负载历史数据的平均值（供设置面板图表展示）
    public func averageCPULoad() -> Double {
        let history = cpuLoadHistory
        guard !history.isEmpty else { return 0.0 }
        return history.reduce(0.0) { $0 + $1.load } / Double(history.count)
    }
    
    /// 获取CPU负载历史数据的最大值（供设置面板图表展示）
    public func maxCPULoad() -> Double {
        let history = cpuLoadHistory
        guard !history.isEmpty else { return 0.0 }
        return history.map { $0.load }.max() ?? 0.0
    }
    
    /// 获取CPU负载历史数据的最小值（供设置面板图表展示）
    public func minCPULoad() -> Double {
        let history = cpuLoadHistory
        guard !history.isEmpty else { return 0.0 }
        return history.map { $0.load }.min() ?? 0.0
    }
    
    /// 获取当前配置的副本（供设置面板编辑）
    public func getConfigForEditing() -> UIAdaptiveFrameRateConfig {
        return config
    }
    
    /// 切换性能等级到下一个档次（循环切换：节能→平衡→性能→极速→节能）
    public func cyclePerformanceLevel() {
        let levels = availablePerformanceLevels()
        guard let currentIndex = levels.firstIndex(of: currentPerformanceLevel) else { return }
        let nextIndex = (currentIndex + 1) % levels.count
        setPerformanceLevel(levels[nextIndex])
    }
    
    // MARK: - 调试与诊断
    
    /// 获取当前完整状态的描述（供调试使用）
    public func fullStatusDescription() -> String {
        lock.lock()
        let desc = """
        [帧率自适应状态]
        - 运行状态: \(_isRunning ? "运行中" : "已停止")
        - 交互中: \(_isInInteraction ? "是" : "否")
        - 性能等级: \(_currentPerformanceLevel.rawValue)
        - 渲染策略: \(_currentRenderStrategy.rawValue)
        - 当前帧率: \(String(format: "%.1f", _currentFrameRate)) fps
        - CPU负载: \(String(format: "%.1f", _currentCPULoad * 100))%
        - 高负载计数: \(consecutiveHighCPUCount)/\(_config.downgradeThreshold)
        - 低负载计数: \(consecutiveLowCPUCount)/\(_config.upgradeThreshold)
        - 历史采样数: \(_cpuLoadHistory.count)
        - 自动检测: \(_config.autoDetectionEnabled ? "开启" : "关闭")
        - CPU监控: \(_config.cpuMonitoringEnabled ? "开启" : "关闭")
        """
        lock.unlock()
        return desc
    }
    
    /// 打印当前状态到日志（调试用途）
    public func logCurrentStatus() {
        Self.logger.info("\(self.fullStatusDescription())")
    }
}

// MARK: - 迁回自 UI-02：enum UIPerformanceLevel
// MARK: - UI-GL-62 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-62_types.swift
// 版本: 2.0
// MARK: - 性能等级枚举
/// 系统性能等级，分为四个档次，从节能到极速
public enum UIPerformanceLevel: String, Codable, CaseIterable, Sendable, CustomStringConvertible {
    /// 节能模式：最低帧率，适合静止状态和电池供电场景
    case powerSaving = "节能"
    /// 平衡模式：中等帧率，兼顾流畅度与能耗
    case balanced = "平衡"
    /// 性能模式：高帧率，适合复杂交互场景
    case performance = "性能"
    /// 极速模式：最高帧率，适合关键动画和高频交互
    case extreme = "极速"
    
    public var description: String { rawValue }
    
    /// 该性能等级对应的默认帧率（每秒渲染次数）
    public var defaultFrameRate: Double {
        switch self {
        case .powerSaving: return 10.0
        case .balanced:     return 30.0
        case .performance:  return 60.0
        case .extreme:      return 120.0
        }
    }
    
    /// 该性能等级对应的最低帧率阈值（低于此值会降级）
    public var minFrameRate: Double {
        switch self {
        case .powerSaving: return 5.0
        case .balanced:     return 20.0
        case .performance:  return 45.0
        case .extreme:      return 90.0
        }
    }
    
    /// 该性能等级对应的CPU负载阈值（高于此值会考虑降级）
    public var cpuThreshold: Double {
        switch self {
        case .powerSaving: return 0.50
        case .balanced:     return 0.60
        case .performance:  return 0.75
        case .extreme:      return 0.90
        }
    }
    
    /// 该性能等级对应的显示优先级（用于UI展示排序）
    public var displayPriority: Int {
        switch self {
        case .powerSaving: return 0
        case .balanced:     return 1
        case .performance:  return 2
        case .extreme:      return 3
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIRenderStrategy
// MARK: - 渲染策略枚举
/// 渲染调度策略，决定如何根据当前状态选择帧率
public enum UIRenderStrategy: String, Codable, CaseIterable, Sendable, CustomStringConvertible {
    /// 固定策略：始终使用用户指定的固定帧率，不自适应调整
    case fixed = "固定帧率"
    /// 自适应策略：根据交互状态和CPU负载动态调整帧率（推荐）
    case adaptive = "自适应帧率"
    /// 交互优先策略：只要有交互就锁定最高帧率，忽略CPU负载
    case interactionPriority = "交互优先"
    /// 节能优先策略：优先考虑降低能耗，仅在必要交互时提升帧率
    case powerPriority = "节能优先"
    
    public var description: String { rawValue }
}

// MARK: - 迁回自 UI-02：struct UIAdaptiveFrameRateConfig
// MARK: - 帧率配置结构体
/// 可持久化的帧率配置数据，支持JSON编码/解码
public struct UIAdaptiveFrameRateConfig: Codable, Equatable, Sendable {
    /// 当前选定的性能等级
    public var performanceLevel: UIPerformanceLevel
    /// 当前渲染策略
    public var renderStrategy: UIRenderStrategy
    /// 是否启用自动性能检测（基于CPU负载自动调整性能等级）
    public var autoDetectionEnabled: Bool
    /// 是否启用CPU负载监控
    public var cpuMonitoringEnabled: Bool
    /// 性能等级自动检测的采样间隔（秒）
    public var samplingInterval: TimeInterval
    /// 连续多少次CPU负载过高才降级（防止抖动）
    public var downgradeThreshold: Int
    /// 连续多少次CPU负载正常才升级（防止抖动）
    public var upgradeThreshold: Int
    /// 自定义帧率覆盖值（仅固定策略有效，0表示使用默认值）
    public var customFrameRate: Double
    
    /// 默认配置构造器
    public init(
        performanceLevel: UIPerformanceLevel = .balanced,
        renderStrategy: UIRenderStrategy = .adaptive,
        autoDetectionEnabled: Bool = true,
        cpuMonitoringEnabled: Bool = true,
        samplingInterval: TimeInterval = 1.0,
        downgradeThreshold: Int = 3,
        upgradeThreshold: Int = 5,
        customFrameRate: Double = 0
    ) {
        self.performanceLevel = performanceLevel
        self.renderStrategy = renderStrategy
        self.autoDetectionEnabled = autoDetectionEnabled
        self.cpuMonitoringEnabled = cpuMonitoringEnabled
        self.samplingInterval = samplingInterval
        self.downgradeThreshold = downgradeThreshold
        self.upgradeThreshold = upgradeThreshold
        self.customFrameRate = customFrameRate
    }
    
    /// 默认配置实例
    public static let `default` = UIAdaptiveFrameRateConfig()
}

// MARK: - 迁回自 UI-02：struct UICPULoadSample
// MARK: - CPU负载采样记录
/// 单次CPU负载采样数据点
public struct UICPULoadSample: Equatable {
    /// 采样时间戳
    public let timestamp: Date
    /// CPU负载百分比（0.0 ~ 1.0）
    public let load: Double
    /// 用户态CPU时间占比
    public let userLoad: Double
    /// 系统态CPU时间占比
    public let systemLoad: Double
    
    public init(timestamp: Date, load: Double, userLoad: Double, systemLoad: Double) {
        self.timestamp = timestamp
        self.load = load
        self.userLoad = userLoad
        self.systemLoad = systemLoad
    }
}
