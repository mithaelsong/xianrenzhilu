// 功能11: 窗口透明与不透明度控制
// 对应: 全局统一管理窗口透明度与不透光属性，支持实时调整、动画过渡、快捷键绑定、闪动提醒
// 优先级: P1
// 版本: 2.0

import Foundation
import AppKit
import os.log

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能11：窗口透明与不透明度控制 — 单元测试
/// 覆盖：数据模型、配置、快捷键、动画配置
func test_windowOpacity() {
    print("\n🧪 测试1: 透明度CLAMP范围")
    let record = UIWindowOpacityRecord(windowID: "test_001", alpha: 0.5)
    record.update(alpha: 1.5)
    guard record.alpha == 1.0 else {
        fatalError("❌ 测试1失败: 1.5应被clamp为1.0")
    }
    record.update(alpha: -0.5)
    guard record.alpha == 0.0 else {
        fatalError("❌ 测试1失败: -0.5应被clamp为0.0")
    }
    print("✅ 测试1通过: 透明度CLAMP范围0.0~1.0")
    
    print("\n🧪 测试2: UIWindowOpacityRecord状态")
    let record2 = UIWindowOpacityRecord(windowID: "test_002", alpha: 0.8, isOpaque: false)
    guard !record2.isMarkedOpaque else {
        fatalError("❌ 测试2失败: isMarkedOpaque应为false")
    }
    record2.update(alpha: 1.0)
    guard record2.isMarkedOpaque else {
        fatalError("❌ 测试2失败: 透明度为1.0后isMarkedOpaque应为true")
    }
    print("✅ 测试2通过: UIWindowOpacityRecord状态变更正确")
    
    print("\n🧪 测试3: UIOpacityAnimationConfig默认值")
    let defaultConfig = UIOpacityAnimationConfig.default
    guard abs(defaultConfig.duration - 0.25) < 0.01 else {
        fatalError("❌ 测试3失败: 默认duration应为0.25")
    }
    let fastConfig = UIOpacityAnimationConfig.fast
    guard abs(fastConfig.duration - 0.15) < 0.01 else {
        fatalError("❌ 测试3失败: fast duration应为0.15")
    }
    print("✅ 测试3通过: 动画配置预设值正确")
    
    print("\n🧪 测试4: UIOpacityKeyConfig创建与Codable")
    let keyConfig = UIOpacityKeyConfig(
        identifier: "opacity.increase",
        description: "增加透明度",
        keyEquivalent: "=",
        modifierFlags: .control,
        step: 0.05
    )
    guard let data = try? JSONEncoder().encode(keyConfig) else {
        fatalError("❌ 测试4失败: 编码失败")
    }
    guard let decoded = try? JSONDecoder().decode(UIOpacityKeyConfig.self, from: data) else {
        fatalError("❌ 测试4失败: 解码失败")
    }
    guard decoded == keyConfig else {
        fatalError("❌ 测试4失败: 编解码后不一致")
    }
    print("✅ 测试4通过: UIOpacityKeyConfig Codable编解码正确")
    
    print("\n🧪 测试5: 管理器初始状态")
    let manager = UIWindowOpacityManager.shared
    guard abs(manager.globalAlpha - 1.0) < 0.01 else {
        fatalError("❌ 测试5失败: 全局透明度初始应为1.0")
    }
    print("✅ 测试5通过: 管理器初始状态正确")
    
    print("\n=== 全部窗口透明度测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 窗口透明度已变更
    static let windowOpacityDidChange = Notification.Name("com.xianrenzhilu.windowOpacityDidChange")
    /// 窗口不透明属性已变更
    static let windowOpaqueDidChange = Notification.Name("com.xianrenzhilu.windowOpaqueDidChange")
    /// 窗口透明度动画已完成
    static let windowOpacityAnimationDidComplete = Notification.Name("com.xianrenzhilu.windowOpacityAnimationDidComplete")
    /// 闪动提醒已开始
    static let windowFlashDidStart = Notification.Name("com.xianrenzhilu.windowFlashDidStart")
    /// 闪动提醒已结束
    static let windowFlashDidEnd = Notification.Name("com.xianrenzhilu.windowFlashDidEnd")
}

// MARK: - 迁回自 UI-02：class UIWindowOpacityRecord
public class UIWindowOpacityRecord : @unchecked Sendable {
    /// 窗口唯一标识
    public let windowID: String
    /// 当前透明度值（0.0 ~ 1.0）
    public private(set) var alpha: CGFloat
    /// 动画前透明度值（用于恢复）
    public private(set) var alphaBeforeAnimation: CGFloat = 1.0
    /// 是否标记为不透明
    public var isMarkedOpaque: Bool
    /// 是否排除在全局管理之外
    public var isExcluded: Bool = false
    /// 创建时间
    public let creationTime: Date
    
    public init(windowID: String, alpha: CGFloat = 1.0, isOpaque: Bool = true) {
        self.windowID = windowID
        self.alpha = alpha
        self.isMarkedOpaque = isOpaque
        self.creationTime = Date()
    }
    
    /// 更新透明度值
    func update(alpha: CGFloat) {
        self.alpha = min(1.0, max(0.0, alpha))
        self.isMarkedOpaque = (self.alpha >= 1.0)
    }
    
    /// 标记动画前状态
    func markBeforeAnimation() {
        alphaBeforeAnimation = alpha
    }
}

// MARK: - 迁回自 UI-02：class UIOpacityAnimation
private class UIOpacityAnimation: NSAnimation , @unchecked Sendable{
    /// 目标窗口
    weak var targetWindow: NSWindow?
    /// 起始透明度
    var startAlpha: CGFloat = 1.0
    /// 目标透明度
    var endAlpha: CGFloat = 1.0
    /// 是否同时变更 isOpaque
    var changesOpaque: Bool = true
    
    override var currentProgress: NSAnimation.Progress {
        get {
            return super.currentProgress
        }
        set {
            super.currentProgress = newValue
            guard let window = targetWindow else { return }
            let progress = CGFloat(newValue)
            let newAlpha = startAlpha + (endAlpha - startAlpha) * progress
            window.alphaValue = newAlpha
            if changesOpaque {
                window.isOpaque = (newAlpha >= 1.0)
            }
        }
    }
    
    override func stop() {
        super.stop()
        // 确保最终值精确
        if let window = targetWindow {
            window.alphaValue = endAlpha
            if changesOpaque {
                window.isOpaque = (endAlpha >= 1.0)
            }
        }
    }
}

// MARK: - 迁回自 UI-02：class UIWindowOpacityManager
public final class UIWindowOpacityManager : @unchecked Sendable {
    
    public static let shared = UIWindowOpacityManager()
    
    /// 日志记录器
    let logger = Logger(subsystem: "com.xianrenzhilu.opacity", category: "UIWindowOpacityManager")
    
    /// 线程安全锁
    let lock = NSRecursiveLock()
    
    /// 窗口透明度记录字典：窗口ID -> 记录
    var records: [String: UIWindowOpacityRecord] = [:]
    
    /// 当前全局透明度值（0.0 ~ 1.0）
    public private(set) var globalAlpha: CGFloat = 1.0
    
    /// 是否启用全局透明度管理
    public var isEnabled: Bool = true {
        didSet {
            logger.info("[透明度] 全局管理已\(self.isEnabled ? "启用" : "禁用")")
            if isEnabled {
                applyGlobalAlphaToAll()
            } else {
                restoreAllWindowsToOpaque()
            }
        }
    }
    
    /// 透明度变化回调（窗口ID, 新透明度）
    public var onAlphaChanged: ((String, CGFloat) -> Void)?
    
    /// 动画完成回调（窗口ID, 最终透明度）
    public var onAnimationCompleted: ((String, CGFloat) -> Void)?
    
    /// 当前活跃动画表（窗口ID -> 动画器）
    fileprivate var activeAnimations: [String: UIOpacityAnimation] = [:]
    
    /// 动画委托强引用（防止被立即释放）
    fileprivate var animationDelegates: [String: UIOpacityAnimationDelegate] = [:]
    
    /// 默认动画配置
    public var defaultAnimationConfig: UIOpacityAnimationConfig = .default
    
    /// 快捷键配置列表
    private var keyConfigs: [String: UIOpacityKeyConfig] = [:]
    
    /// 闪动提醒相关状态
    private var flashTimers: [String: Timer] = [:]
    private var flashOriginalAlphas: [String: CGFloat] = [:]
    
    // MARK: - 生命周期
    
    private init() {
        setupDefaultKeyBindings()
        logger.info("[透明度] UIWindowOpacityManager 单例初始化完成")
    }
    
    deinit {
        // 清理所有动画
        for (_, animation) in activeAnimations {
            animation.stop()
        }
        activeAnimations.removeAll()
        animationDelegates.removeAll()
        
        // 清理所有闪动定时器
        for (_, timer) in flashTimers {
            timer.invalidate()
        }
        flashTimers.removeAll()
    }
    
    // MARK: - 窗口管理
    
    /// 将窗口注册到透明度管理
    /// - Parameters:
    ///   - windowID: 窗口唯一标识
    ///   - initialAlpha: 初始透明度（默认1.0）
    ///   - isOpaque: 初始是否不透明（默认true）
    public func registerWindow(windowID: String, initialAlpha: CGFloat = 1.0, isOpaque: Bool = true) {
        lock.lock()
        let record = UIWindowOpacityRecord(windowID: windowID, alpha: initialAlpha, isOpaque: isOpaque)
        records[windowID] = record
        
        // 解锁前在锁内完成apply，避免解锁后被其他线程修改状态
        let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowID })
        if isEnabled, let w = window, !record.isExcluded {
            let effectiveAlpha = min(record.alpha, globalAlpha)
            w.alphaValue = effectiveAlpha
            w.isOpaque = record.isMarkedOpaque && (effectiveAlpha >= 1.0)
        }
        lock.unlock()
        
        logger.info("[透明度] 已注册窗口 '\(windowID)'，初始透明度 \(initialAlpha)，不透明 \(isOpaque)")
    }
    
    /// 将窗口从透明度管理注销
    /// - Parameter windowID: 窗口ID
    public func unregisterWindow(windowID: String) {
        lock.lock()
        
        // 停止正在进行的动画
        if let animation = activeAnimations[windowID] {
            animation.stop()
            activeAnimations.removeValue(forKey: windowID)
            animationDelegates.removeValue(forKey: windowID)
        }
        
        // 停止闪动定时器
        if let timer = flashTimers[windowID] {
            timer.invalidate()
            flashTimers.removeValue(forKey: windowID)
        }
        
        records.removeValue(forKey: windowID)
        lock.unlock()
        
        // 恢复窗口为完全不透明
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowID }) {
            window.alphaValue = 1.0
            window.isOpaque = true
        }
        
        logger.info("[透明度] 已注销窗口 '\(windowID)'，恢复默认状态")
    }
    
    /// 排除指定窗口（不参与全局透明度管理）
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - excluded: 是否排除
    public func excludeWindow(windowID: String, excluded: Bool) {
        lock.lock()
        records[windowID]?.isExcluded = excluded
        lock.unlock()
        
        if excluded {
            logger.info("[透明度] 窗口 '\(windowID)' 已排除全局管理")
        } else {
            applyToWindow(windowID: windowID)
            logger.info("[透明度] 窗口 '\(windowID)' 已恢复全局管理")
        }
    }
    
    /// 检查窗口是否被排除
    public func isWindowExcluded(windowID: String) -> Bool {
        lock.lock()
        let excluded = records[windowID]?.isExcluded ?? false
        lock.unlock()
        return excluded
    }
    
    // MARK: - 透明度设置
    
    /// 设置单个窗口的透明度
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - alpha: 透明度值（0.0 ~ 1.0）
    public func setWindowAlpha(windowID: String, alpha: CGFloat) {
        let clampedAlpha = min(1.0, max(0.0, alpha))
        
        lock.lock()
        records[windowID]?.update(alpha: clampedAlpha)
        lock.unlock()
        
        applyToWindow(windowID: windowID)
        onAlphaChanged?(windowID, clampedAlpha)
        
        logger.info("[透明度] 窗口 '\(windowID)' 透明度已设为 \(clampedAlpha)")
    }
    
    /// 设置全局透明度（应用于所有非排除窗口）
    /// - Parameter alpha: 透明度值（0.0 ~ 1.0）
    public func setOpacity(_ alpha: CGFloat) {
        let clampedAlpha = min(1.0, max(0.0, alpha))
        globalAlpha = clampedAlpha
        
        logger.info("[透明度] 全局透明度已设为 \(clampedAlpha)")
        
        applyGlobalAlphaToAll()
        
        // 发送全局通知
        NotificationCenter.default.post(
            name: .windowOpacityDidChange,
            object: self,
            userInfo: ["alpha": clampedAlpha]
        )
    }
    
    /// 增加或减少全局透明度
    /// - Parameter delta: 变化量（正值增加，负值减少）
    public func adjustOpacity(delta: CGFloat) {
        let newAlpha = min(1.0, max(0.0, globalAlpha + delta))
        setOpacity(newAlpha)
    }
    
    /// 获取窗口当前透明度
    /// - Parameter windowID: 窗口ID
    /// - Returns: 透明度值（未注册返回1.0）
    public func getWindowAlpha(windowID: String) -> CGFloat {
        lock.lock()
        let alpha = records[windowID]?.alpha ?? 1.0
        lock.unlock()
        return alpha
    }
    
    // MARK: - 不透光属性控制
    
    /// 设置窗口是否为不透光
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - opaque: 是否不透光
    public func setOpaque(windowID: String, opaque: Bool) {
        lock.lock()
        records[windowID]?.isMarkedOpaque = opaque
        if opaque {
            records[windowID]?.update(alpha: 1.0)
        }
        lock.unlock()
        
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowID }) {
            window.isOpaque = opaque
            if opaque {
                window.alphaValue = 1.0
            }
        }
        
        logger.info("[透明度] 窗口 '\(windowID)' 不透光属性已设为 \(opaque)")
        
        NotificationCenter.default.post(
            name: .windowOpaqueDidChange,
            object: self,
            userInfo: ["windowID": windowID, "isOpaque": opaque]
        )
    }
    
    /// 查询窗口是否为不透光
    /// - Parameter windowID: 窗口ID
    /// - Returns: 是否不透光（未注册返回true）
    public func isOpaque(windowID: String) -> Bool {
        lock.lock()
        let opaque = records[windowID]?.isMarkedOpaque ?? true
        lock.unlock()
        return opaque
    }
    
    /// 将窗口设为完全透明（isOpaque = false, alpha = 0.0）
    /// - Parameter windowID: 窗口ID
    public func isTransparent(windowID: String) {
        setWindowAlpha(windowID: windowID, alpha: 0.0)
        setOpaque(windowID: windowID, opaque: false)
        logger.info("[透明度] 窗口 '\(windowID)' 已设为完全透明")
    }
    
    /// 将窗口恢复为完全不透明（isOpaque = true, alpha = 1.0）
    /// - Parameter windowID: 窗口ID
    public func restoreOpaque(windowID: String) {
        setWindowAlpha(windowID: windowID, alpha: 1.0)
        setOpaque(windowID: windowID, opaque: true)
        logger.info("[透明度] 窗口 '\(windowID)' 已恢复为完全不透明")
    }
    
    // MARK: - 动画过渡
    
    /// 动画过渡到指定透明度
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - targetAlpha: 目标透明度
    ///   - config: 动画配置（默认使用 defaultAnimationConfig）
    ///   - completion: 动画完成回调
    public func fadeTo(windowID: String, targetAlpha: CGFloat, config: UIOpacityAnimationConfig? = nil, completion: (() -> Void)? = nil) {
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowID }) else {
            logger.warning("[透明度] fadeTo 失败：窗口 '\(windowID)' 不存在")
            return
        }
        
        let clampedTarget = min(1.0, max(0.0, targetAlpha))
        let animationConfig = config ?? defaultAnimationConfig
        
        // 停止已有动画
        lock.lock()
        if let existingAnimation = activeAnimations[windowID] {
            existingAnimation.stop()
            activeAnimations.removeValue(forKey: windowID)
        }
        records[windowID]?.markBeforeAnimation()
        let startAlpha = records[windowID]?.alpha ?? window.alphaValue
        lock.unlock()
        
        // 创建动画
        let animation = UIOpacityAnimation(duration: animationConfig.duration, animationCurve: animationConfig.curve)
        animation.targetWindow = window
        animation.startAlpha = startAlpha
        animation.endAlpha = clampedTarget
        animation.changesOpaque = true
        animation.animationBlockingMode = animationConfig.allowsUserInteraction ? .nonblocking : .blocking
        
        let delegate = UIOpacityAnimationDelegate(windowID: windowID, manager: self, completion: completion)
        animation.delegate = delegate
        
        lock.lock()
        activeAnimations[windowID] = animation
        animationDelegates[windowID] = delegate
        lock.unlock()
        
        animation.start()
        
        logger.info("[透明度] 窗口 '\(windowID)' 开始动画：从 \(startAlpha) 到 \(clampedTarget)，耗时 \(animationConfig.duration)秒")
    }
    
    /// 窗口淡入（从当前透明度到1.0）
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - config: 动画配置
    ///   - completion: 完成回调
    public func fadeIn(windowID: String, config: UIOpacityAnimationConfig? = nil, completion: (() -> Void)? = nil) {
        fadeTo(windowID: windowID, targetAlpha: 1.0, config: config, completion: completion)
        logger.info("[透明度] 窗口 '\(windowID)' 执行淡入")
    }
    
    /// 窗口淡出（从当前透明度到0.0）
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - config: 动画配置
    ///   - completion: 完成回调
    public func fadeOut(windowID: String, config: UIOpacityAnimationConfig? = nil, completion: (() -> Void)? = nil) {
        fadeTo(windowID: windowID, targetAlpha: 0.0, config: config, completion: completion)
        logger.info("[透明度] 窗口 '\(windowID)' 执行淡出")
    }
    
    /// 通用动画过渡方法（从任意透明度到目标透明度）
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - fromAlpha: 起始透明度（nil表示当前值）
    ///   - toAlpha: 目标透明度
    ///   - duration: 动画持续时间（秒）
    ///   - curve: 动画曲线
    ///   - completion: 完成回调
    public func animateTransition(windowID: String, fromAlpha: CGFloat? = nil, toAlpha: CGFloat, duration: TimeInterval = 0.25, curve: NSAnimation.Curve = .easeInOut, completion: (() -> Void)? = nil) {
        let config = UIOpacityAnimationConfig(duration: duration, curve: curve, allowsUserInteraction: true)
        
        if let startAlpha = fromAlpha {
            // 先设置起始值
            setWindowAlpha(windowID: windowID, alpha: startAlpha)
        }
        
        fadeTo(windowID: windowID, targetAlpha: toAlpha, config: config, completion: completion)
    }
    
    /// 停止指定窗口的动画
    /// - Parameter windowID: 窗口ID
    public func stopAnimation(windowID: String) {
        lock.lock()
        if let animation = activeAnimations[windowID] {
            animation.stop()
            activeAnimations.removeValue(forKey: windowID)
            animationDelegates.removeValue(forKey: windowID)
        }
        lock.unlock()
        
        logger.info("[透明度] 窗口 '\(windowID)' 动画已停止")
    }
    
    /// 检查窗口是否正在动画中
    /// - Parameter windowID: 窗口ID
    /// - Returns: 是否正在动画
    public func isAnimating(windowID: String) -> Bool {
        lock.lock()
        let animating = activeAnimations[windowID] != nil
        lock.unlock()
        return animating
    }
    
    // MARK: - 闪动提醒（Flash）
    
    /// 闪动提醒：窗口透明度快速交替变化，用于视觉提示
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - count: 闪动次数（默认3次）
    ///   - flashAlpha: 闪动时的透明度（默认0.5）
    ///   - duration: 单次闪动持续时间（秒，默认0.2）
    ///   - completion: 完成回调
    public func flash(windowID: String, count: Int = 3, flashAlpha: CGFloat = 0.5, duration: TimeInterval = 0.2, completion: (() -> Void)? = nil) {
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowID }) else {
            logger.warning("[透明度] flash 失败：窗口 '\(windowID)' 不存在")
            return
        }
        
        // 保存原始透明度
        let originalAlpha = window.alphaValue
        
        lock.lock()
        flashOriginalAlphas[windowID] = originalAlpha
        
        // 停止已有闪动
        if let timer = flashTimers[windowID] {
            timer.invalidate()
        }
        lock.unlock()
        
        var currentCount = 0
        var isFlashing = false
        
        NotificationCenter.default.post(
            name: .windowFlashDidStart,
            object: self,
            userInfo: ["windowID": windowID, "count": count]
        )
        
        logger.info("[透明度] 窗口 '\(windowID)' 开始闪动提醒（\(count)次）")
        
        // 创建定时器实现闪动效果
        let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if currentCount >= count * 2 {
                // 闪动结束，恢复原始透明度
                timer.invalidate()
                
                self.lock.lock()
                self.flashTimers.removeValue(forKey: windowID)
                let restoreAlpha = self.flashOriginalAlphas[windowID] ?? 1.0
                self.flashOriginalAlphas.removeValue(forKey: windowID)
                self.lock.unlock()
                
                window.alphaValue = restoreAlpha
                window.isOpaque = (restoreAlpha >= 1.0)
                
                self.logger.info("[透明度] 窗口 '\(windowID)' 闪动提醒结束")
                
                NotificationCenter.default.post(
                    name: .windowFlashDidEnd,
                    object: self,
                    userInfo: ["windowID": windowID]
                )
                
                completion?()
                return
            }
            
            if isFlashing {
                window.alphaValue = originalAlpha
                window.isOpaque = (originalAlpha >= 1.0)
            } else {
                window.alphaValue = flashAlpha
                window.isOpaque = false
            }
            
            isFlashing = !isFlashing
            currentCount += 1
        }
        
        lock.lock()
        flashTimers[windowID] = timer
        lock.unlock()
        
        // 立即触发第一次变化
        timer.fire()
    }
    
    /// 停止指定窗口的闪动提醒
    /// - Parameter windowID: 窗口ID
    public func stopFlash(windowID: String) {
        lock.lock()
        
        if let timer = flashTimers[windowID] {
            timer.invalidate()
            flashTimers.removeValue(forKey: windowID)
        }
        
        let restoreAlpha = flashOriginalAlphas[windowID] ?? 1.0
        flashOriginalAlphas.removeValue(forKey: windowID)
        
        lock.unlock()
        
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowID }) {
            window.alphaValue = restoreAlpha
            window.isOpaque = (restoreAlpha >= 1.0)
        }
        
        logger.info("[透明度] 窗口 '\(windowID)' 闪动提醒已停止")
    }
    
    /// 检查窗口是否正在闪动
    /// - Parameter windowID: 窗口ID
    /// - Returns: 是否正在闪动
    public func isFlashing(windowID: String) -> Bool {
        lock.lock()
        let flashing = flashTimers[windowID] != nil
        lock.unlock()
        return flashing
    }
    
    // MARK: - 快捷键绑定
    
    /// 设置默认快捷键绑定
    private func setupDefaultKeyBindings() {
        // 增加透明度：Ctrl + =
        let increaseConfig = UIOpacityKeyConfig(
            identifier: "opacity.increase",
            description: "增加窗口透明度",
            keyEquivalent: "=",
            modifierFlags: .control,
            step: 0.05,
            isEnabled: true
        )
        
        // 降低透明度：Ctrl + -
        let decreaseConfig = UIOpacityKeyConfig(
            identifier: "opacity.decrease",
            description: "降低窗口透明度",
            keyEquivalent: "-",
            modifierFlags: .control,
            step: -0.05,
            isEnabled: true
        )
        
        // 恢复完全不透明：Ctrl + 0
        let resetConfig = UIOpacityKeyConfig(
            identifier: "opacity.reset",
            description: "恢复窗口完全不透明",
            keyEquivalent: "0",
            modifierFlags: .control,
            step: 0.0,
            isEnabled: true
        )
        
        // 切换全局透明度开关：Ctrl + Shift + O
        let toggleConfig = UIOpacityKeyConfig(
            identifier: "opacity.toggle",
            description: "切换全局透明度管理",
            keyEquivalent: "o",
            modifierFlags: [.control, .shift],
            step: 0.0,
            isEnabled: true
        )
        
        registerKeyConfig(increaseConfig)
        registerKeyConfig(decreaseConfig)
        registerKeyConfig(resetConfig)
        registerKeyConfig(toggleConfig)
    }
    
    /// 注册快捷键配置
    /// - Parameter config: 快捷键配置
    public func registerKeyConfig(_ config: UIOpacityKeyConfig) {
        lock.lock()
        keyConfigs[config.identifier] = config
        lock.unlock()
        
        logger.info("[透明度] 已注册快捷键: \(config.displayString) -> \(config.description)")
    }
    
    /// 注销快捷键配置
    /// - Parameter identifier: 快捷键标识符
    public func unregisterKeyConfig(identifier: String) {
        lock.lock()
        keyConfigs.removeValue(forKey: identifier)
        lock.unlock()
        
        logger.info("[透明度] 已注销快捷键: \(identifier)")
    }
    
    /// 自定义快捷键配置
    /// - Parameters:
    ///   - identifier: 快捷键标识符
    ///   - keyEquivalent: 新按键字符
    ///   - modifierFlags: 新修饰键
    /// - Returns: 是否成功更新
    @discardableResult
    public func customizeKeyConfig(identifier: String, keyEquivalent: String, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        lock.lock()
        guard var config = keyConfigs[identifier] else {
            lock.unlock()
            logger.warning("[透明度] 自定义快捷键失败：标识符 '\(identifier)' 不存在")
            return false
        }
        
        config.keyEquivalent = keyEquivalent
        config.modifierFlags = modifierFlags.rawValue
        keyConfigs[identifier] = config
        lock.unlock()
        
        logger.info("[透明度] 快捷键 '\(identifier)' 已自定义为 \(config.displayString)")
        return true
    }
    
    /// 获取所有快捷键配置
    /// - Returns: 快捷键配置数组
    public func allKeyConfigs() -> [UIOpacityKeyConfig] {
        lock.lock()
        let configs = Array(keyConfigs.values)
        lock.unlock()
        return configs
    }
    
    /// 根据标识符获取快捷键配置
    /// - Parameter identifier: 快捷键标识符
    /// - Returns: 快捷键配置，不存在返回nil
    public func keyConfig(for identifier: String) -> UIOpacityKeyConfig? {
        lock.lock()
        let config = keyConfigs[identifier]
        lock.unlock()
        return config
    }
    
    /// 处理快捷键事件（由外部快捷键系统调用）
    /// - Parameters:
    ///   - identifier: 快捷键标识符
    ///   - windowID: 当前焦点窗口ID（可选）
    /// - Returns: 是否已处理
    @discardableResult
    public func handleKeyEvent(identifier: String, windowID: String? = nil) -> Bool {
        guard let config = keyConfig(for: identifier), config.isEnabled else {
            return false
        }
        
        switch identifier {
        case "opacity.increase":
            adjustOpacity(delta: config.step)
            return true
        case "opacity.decrease":
            adjustOpacity(delta: config.step)
            return true
        case "opacity.reset":
            setOpacity(1.0)
            if let wid = windowID {
                restoreOpaque(windowID: wid)
            }
            return true
        case "opacity.toggle":
            isEnabled = !isEnabled
            return true
        default:
            // 自定义快捷键处理步长调整
            if config.step != 0.0 {
                adjustOpacity(delta: config.step)
                return true
            }
            return false
        }
    }
    
    /// 处理滚轮事件（Ctrl+滚轮调整透明度）
    /// - Parameter event: NSEvent 滚轮事件
    /// - Returns: 是否已处理
    @discardableResult
    public func handleScrollEvent(_ event: NSEvent) -> Bool {
        // 检查是否按住了 Ctrl 键（或用户自定义的修饰键）
        let requiredModifiers: NSEvent.ModifierFlags = .control
        guard event.modifierFlags.contains(requiredModifiers) else {
            return false
        }
        
        let delta = event.deltaY
        guard delta != 0 else { return false }
        
        // 滚轮向上（deltaY > 0）增加透明度，向下降低透明度
        let step: CGFloat = 0.03
        let adjustment = delta > 0 ? step : -step
        
        adjustOpacity(delta: adjustment)
        
        logger.info("[透明度] Ctrl+滚轮调整透明度：\(adjustment > 0 ? "增加" : "降低") \(abs(adjustment))")
        
        return true
    }
    
    // MARK: - 批量操作
    
    /// 应用全局透明度到所有非排除窗口
    private func applyGlobalAlphaToAll() {
        guard isEnabled else { return }
        
        lock.lock()
        let windowIDs = records.compactMap { (id, record) -> String? in
            return record.isExcluded ? nil : id
        }
        lock.unlock()
        
        for windowID in windowIDs {
            applyToWindow(windowID: windowID)
        }
    }
    
    /// 恢复所有窗口为完全不透明
    private func restoreAllWindowsToOpaque() {
        lock.lock()
        let windowIDs = Array(records.keys)
        lock.unlock()
        
        for windowID in windowIDs {
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowID }) {
                window.alphaValue = 1.0
                window.isOpaque = true
            }
        }
        
        logger.info("[透明度] 已恢复所有 \(windowIDs.count) 个窗口为完全不透明（全局管理已禁用）")
    }
    
    /// 将透明度设置应用到指定窗口
    private func applyToWindow(windowID: String) {
        guard isEnabled else { return }
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowID }) else { return }
        
        lock.lock()
        guard let record = records[windowID], !record.isExcluded else {
            lock.unlock()
            return
        }
        let alpha = record.alpha
        let opaque = record.isMarkedOpaque
        lock.unlock()
        
        // 使用全局透明度与窗口透明度中的较小值（更透明）
        let effectiveAlpha = min(alpha, globalAlpha)
        
        window.alphaValue = effectiveAlpha
        window.isOpaque = opaque && (effectiveAlpha >= 1.0)
    }
    
    /// 设置所有窗口的透明度（全局批量设置）
    /// - Parameter alpha: 目标透明度
    public func setAllWindowsAlpha(_ alpha: CGFloat) {
        lock.lock()
        let windowIDs = records.compactMap { (id, record) -> String? in
            return record.isExcluded ? nil : id
        }
        lock.unlock()
        
        for windowID in windowIDs {
            setWindowAlpha(windowID: windowID, alpha: alpha)
        }
        
        logger.info("[透明度] 已批量设置 \(windowIDs.count) 个窗口透明度为 \(alpha)")
    }
    
    /// 淡入所有窗口
    /// - Parameter config: 动画配置
    public func fadeInAll(config: UIOpacityAnimationConfig? = nil) {
        lock.lock()
        let windowIDs = records.compactMap { (id, record) -> String? in
            return record.isExcluded ? nil : id
        }
        lock.unlock()
        
        for windowID in windowIDs {
            fadeIn(windowID: windowID, config: config)
        }
    }
    
    /// 淡出所有窗口
    /// - Parameter config: 动画配置
    public func fadeOutAll(config: UIOpacityAnimationConfig? = nil) {
        lock.lock()
        let windowIDs = records.compactMap { (id, record) -> String? in
            return record.isExcluded ? nil : id
        }
        lock.unlock()
        
        for windowID in windowIDs {
            fadeOut(windowID: windowID, config: config)
        }
    }
    
    // MARK: - 查询与统计
    
    /// 获取所有已注册窗口的透明度信息
    /// - Returns: 窗口ID -> 透明度 字典
    public var allWindowAlphas: [String: CGFloat] {
        lock.lock()
        let result = records.reduce(into: [String: CGFloat]()) { dict, pair in
            dict[pair.key] = pair.value.alpha
        }
        lock.unlock()
        return result
    }
    
    /// 获取受管理的窗口数量
    public var managedWindowCount: Int {
        lock.lock()
        let count = records.count
        lock.unlock()
        return count
    }
    
    /// 获取状态描述（用于调试面板）
    public var statusDescription: String {
        lock.lock()
        let total = records.count
        let excluded = records.values.filter { $0.isExcluded }.count
        let animating = activeAnimations.count
        let flashing = flashTimers.count
        lock.unlock()
        
        return "管理窗口：\(total)（排除：\(excluded)），全局透明度：\(globalAlpha)，动画中：\(animating)，闪动中：\(flashing)，管理状态：\(isEnabled ? "启用" : "禁用")"
    }
    
    /// 获取详细状态（用于调试日志）
    public var detailedDescription: String {
        lock.lock()
        var lines: [String] = []
        lines.append("=== 窗口透明度管理器详情 ===")
        lines.append("全局透明度：\(globalAlpha)")
        lines.append("管理状态：\(isEnabled ? "启用" : "禁用")")
        lines.append("管理窗口数：\(records.count)")
        lines.append("动画中窗口：\(activeAnimations.count)")
        lines.append("闪动中窗口：\(flashTimers.count)")
        lines.append("")
        
        for (id, record) in records.sorted(by: { $0.value.creationTime < $1.value.creationTime }) {
            let status = record.isExcluded ? "[排除]" : ""
            lines.append("[\(id)] 透明度：\(record.alpha)，不透光：\(record.isMarkedOpaque) \(status)")
        }
        
        lines.append("")
        lines.append("=== 快捷键绑定 ===")
        for config in keyConfigs.values.sorted(by: { $0.identifier < $1.identifier }) {
            lines.append("[\(config.identifier)] \(config.displayString) -> \(config.description)（\(config.isEnabled ? "启用" : "禁用")）")
        }
        
        lines.append("=== 结束 ===")
        lock.unlock()
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - 清理与重置
    
    /// 重置所有窗口为默认状态（不透明，透明度1.0）
    public func resetAll() {
        lock.lock()
        let windowIDs = Array(records.keys)
        lock.unlock()
        
        for windowID in windowIDs {
            restoreOpaque(windowID: windowID)
        }
        
        globalAlpha = 1.0
        isEnabled = true
        
        // 停止所有动画和闪动
        for (_, animation) in activeAnimations {
            animation.stop()
        }
        activeAnimations.removeAll()
        
        for (_, timer) in flashTimers {
            timer.invalidate()
        }
        flashTimers.removeAll()
        
        logger.info("[透明度] 已重置所有窗口为默认状态")
    }
    
    /// 清理已注销窗口的记录（保留内存）
    /// 注意：unregisterWindow 会自动清理，此方法用于额外维护
    public func purgeRecords() {
        lock.lock()
        let count = records.count
        lock.unlock()
        
        logger.info("[透明度] 记录表状态：\(count) 条记录")
    }
}

// MARK: - 迁回自 UI-02：class UIOpacityAnimationDelegate
private class UIOpacityAnimationDelegate: NSObject, NSAnimationDelegate , @unchecked Sendable{
    let windowID: String
    weak var manager: UIWindowOpacityManager?
    let completion: (() -> Void)?
    
    init(windowID: String, manager: UIWindowOpacityManager, completion: (() -> Void)?) {
        self.windowID = windowID
        self.manager = manager
        self.completion = completion
        super.init()
    }
    
    func animationDidEnd(_ animation: NSAnimation) {
        guard let manager = manager else { return }
        
        manager.lock.lock()
        manager.activeAnimations.removeValue(forKey: self.windowID)
        manager.animationDelegates.removeValue(forKey: self.windowID)
        manager.lock.unlock()
        
        // 更新记录中的透明度为最终值
        if let anim = animation as? UIOpacityAnimation {
            manager.records[self.windowID]?.update(alpha: anim.endAlpha)
        }
        
        manager.onAnimationCompleted?(self.windowID, manager.records[self.windowID]?.alpha ?? 1.0)
        
        NotificationCenter.default.post(
            name: .windowOpacityAnimationDidComplete,
            object: manager,
            userInfo: ["windowID": self.windowID, "alpha": manager.records[self.windowID]?.alpha ?? 1.0]
        )
        
        manager.logger.info("[透明度] 窗口 '\(self.windowID)' 动画完成")
        
        completion?()
    }
    
    func animationDidStop(_ animation: NSAnimation) {
        guard let manager = manager else { return }
        
        manager.lock.lock()
        manager.activeAnimations.removeValue(forKey: self.windowID)
        manager.animationDelegates.removeValue(forKey: self.windowID)
        manager.lock.unlock()
        
        manager.logger.info("[透明度] 窗口 '\(self.windowID)' 动画已停止")
        
        completion?()
    }
}

// MARK: - 迁回自 UI-02：struct UIOpacityKeyConfig
// MARK: - 工具栏项包装器
/// 内部使用的工具栏项包装器，存储定义与对应的 NSToolbarItem 实例
// 已迁回 UI-GL-11_窗口工具栏.swift：class UIToolbarItemWrapper（公共类型文件禁止功能实现）

// MARK: - 工具栏实例包装器
/// 内部使用的工具栏实例包装器，管理一个窗口的工具栏及其所有项
// 已迁回 UI-GL-11_窗口工具栏.swift：class UIToolbarInstanceWrapper（公共类型文件禁止功能实现）

// MARK: - 工具栏实例代理
/// 单个工具栏实例的 NSToolbarDelegate 实现
// 已迁回 UI-GL-11_窗口工具栏.swift：class UIToolbarInstanceDelegate（公共类型文件禁止功能实现）

// MARK: - 窗口工具栏管理器
/// 管理多窗口工具栏实例的单例类
/// 支持动态添加/移除工具栏、增删工具项、启用/禁用项、切换显示模式与风格
// 已迁回 UI-GL-11_窗口工具栏.swift：class UIWindowToolbarManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-12 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-12_types.swift
// 版本: 2.0
// MARK: - 自动隐藏面板视图
/// 支持自动收缩/展开的面板视图
/// 不使用时收缩为窄条标签，鼠标悬停展开
// 已迁回 UI-GL-12_面板自动隐藏.swift：class UIAutoHidePanelView（公共类型文件禁止功能实现）


// MARK: - UI-GL-13 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-13_types.swift
// 版本: 2.0
// MARK: - 透明度快捷键配置
/// 透明度调节快捷键配置
public struct UIOpacityKeyConfig: Codable, Equatable {
    /// 快捷键标识符
    public let identifier: String
    /// 功能描述
    public let description: String
    /// 按键字符
    public var keyEquivalent: String
    /// 修饰键掩码（NSEvent.ModifierFlags.rawValue）
    public var modifierFlags: UInt
    /// 调节步长（正值为增加透明度，负值为降低透明度）
    public var step: CGFloat
    /// 是否启用
    public var isEnabled: Bool
    
    public init(identifier: String, description: String, keyEquivalent: String,
                modifierFlags: NSEvent.ModifierFlags = .control, step: CGFloat, isEnabled: Bool = true) {
        self.identifier = identifier
        self.description = description
        self.keyEquivalent = keyEquivalent
        self.modifierFlags = modifierFlags.rawValue
        self.step = step
        self.isEnabled = isEnabled
    }
    
    /// 快捷键显示字符串（如 ⌃+）
    public var displayString: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var parts: [String] = []
        if flags.contains(.command)  { parts.append("⌘") }
        if flags.contains(.shift)    { parts.append("⇧") }
        if flags.contains(.option)   { parts.append("⌥") }
        if flags.contains(.control)  { parts.append("⌃") }
        if !keyEquivalent.isEmpty {
            parts.append(keyEquivalent.uppercased())
        }
        return parts.joined(separator: "+")
    }
}

// MARK: - 迁回自 UI-02：struct UIOpacityAnimationConfig
// MARK: - 动画配置
/// 透明度动画过渡配置
public struct UIOpacityAnimationConfig: Sendable {
    /// 动画持续时间（秒）
    public var duration: TimeInterval
    /// 动画曲线
    public var curve: NSAnimation.Curve
    /// 是否允许用户交互
    public var allowsUserInteraction: Bool
    
    public init(duration: TimeInterval = 0.25, curve: NSAnimation.Curve = .easeInOut, allowsUserInteraction: Bool = true) {
        self.duration = duration
        self.curve = curve
        self.allowsUserInteraction = allowsUserInteraction
    }
    
    /// 默认配置
    public static let `default` = UIOpacityAnimationConfig()
    
    /// 快速配置
    public static let fast = UIOpacityAnimationConfig(duration: 0.15, curve: .easeOut, allowsUserInteraction: true)
    
    /// 慢速配置（强调效果）
    public static let slow = UIOpacityAnimationConfig(duration: 0.5, curve: .easeInOut, allowsUserInteraction: false)
}
