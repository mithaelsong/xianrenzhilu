// 功能: 窗口动画效果
// 对应: 窗口打开/关闭/最小化/恢复/淡入淡出/缩放等动画，支持自定义配置
// 优先级: P0
// 技术栈: AppKit (NSViewAnimation / NSAnimation)，纯原生框架，无 SwiftUI
// 版本: 2.0

import Foundation
import AppKit
import os

// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension NSWindow {

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能06A：窗口动画效果 — 单元测试
/// 覆盖：配置管理、动画记录、取消动画边界情况、便捷扩展
func test_windowAnimation() {
    print("\n🧪 测试1: 默认配置初始化")
    let config = UIWindowAnimationConfiguration()
    guard abs(config.duration - 0.25) < 0.01 else {
        fatalError("❌ 测试1失败: 默认duration应为0.25，实际为\(config.duration)")
    }
    guard config.isEnabled else {
        fatalError("❌ 测试1失败: 默认isEnabled应为true")
    }
    print("✅ 测试1通过: 默认配置初始化正确")
    
    print("\n🧪 测试2: 自定义配置")
    let custom = UIWindowAnimationConfiguration(duration: 0.5, curve: .springDamping, damping: 0.5, isEnabled: false)
    guard abs(custom.duration - 0.5) < 0.01 else {
        fatalError("❌ 测试2失败: 自定义duration应为0.5")
    }
    guard !custom.isEnabled else {
        fatalError("❌ 测试2失败: 自定义isEnabled应为false")
    }
    print("✅ 测试2通过: 自定义配置正确")
    
    print("\n🧪 测试3: 设置与获取类型配置")
    let manager = UIWindowAnimationManager.shared
    let fadeConfig = UIWindowAnimationConfiguration(duration: 0.3, curve: .linear)
    manager.setConfiguration(fadeConfig, for: .fadeIn)
    let retrieved = manager.configuration(for: .fadeIn)
    guard abs(retrieved.duration - 0.3) < 0.01 else {
        fatalError("❌ 测试3失败: 获取的配置duration不匹配")
    }
    print("✅ 测试3通过: 类型配置设置与获取正确")
    
    print("\n🧪 测试4: 重置所有配置")
    manager.resetAllConfigurations()
    let afterReset = manager.configuration(for: .fadeIn)
    guard abs(afterReset.duration - 0.25) < 0.01 else {
        fatalError("❌ 测试4失败: 重置后duration应恢复默认0.25")
    }
    print("✅ 测试4通过: 重置配置正确")
    
    print("\n🧪 测试5: 动画曲线枚举")
    let curves: [UIWindowAnimationCurve] = [.linear, .easeIn, .easeOut, .easeInOut, .springDamping]
    for curve in curves {
        let _ = curve.nsAnimationCurve
    }
    print("✅ 测试5通过: 所有动画曲线类型有效")
    
    print("\n🧪 测试6: 动画类型枚举")
    let types: [UIWindowAnimationType] = [.open, .close, .minimize, .restore, .fadeIn, .fadeOut, .scale, .custom]
    for type in types {
        guard !type.description.isEmpty else {
            fatalError("❌ 测试6失败: 动画类型\(type)描述为空")
        }
    }
    print("✅ 测试6通过: 所有动画类型描述有效")
    
    print("\n🧪 测试7: 动画记录生命周期")
    let record = UIWindowAnimationRecord(type: .scale, window: nil)
    guard !record.isCompleted else {
        fatalError("❌ 测试7失败: 新创建的记录不应已完成")
    }
    guard !record.isCancelled else {
        fatalError("❌ 测试7失败: 新创建的记录不应已取消")
    }
    record.markCompleted()
    guard record.isCompleted else {
        fatalError("❌ 测试7失败: markCompleted后应为已完成")
    }
    print("✅ 测试7通过: 动画记录生命周期正确\(record)")
    
    print("\n=== 全部窗口动画测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWindowAnimationRecord
public class UIWindowAnimationRecord: CustomStringConvertible , @unchecked Sendable{
    /// 唯一标识
    public let recordID: UUID
    /// 动画类型
    public let type: UIWindowAnimationType
    /// 目标窗口
    public weak var window: NSWindow?
    /// 开始时间
    public let startTime: Date
    /// 结束时间（动画完成后设置）
    public private(set) var endTime: Date?
    /// 是否已取消
    public private(set) var isCancelled: Bool = false
    /// 是否已完成
    public var isCompleted: Bool { endTime != nil }
    /// 关联的 NSViewAnimation 实例（弱引用，避免循环）
    public weak var animation: NSViewAnimation?
    
    init(type: UIWindowAnimationType, window: NSWindow?) {
        self.recordID = UUID()
        self.type = type
        self.window = window
        self.startTime = Date()
    }
    
    /// 标记动画完成
    func markCompleted() {
        endTime = Date()
    }
    
    /// 标记动画取消
    func markCancelled() {
        isCancelled = true
    }
    
    public var description: String {
        let windowInfo = window != nil ? "窗口 \(window?.title ?? "未知")" : "无窗口"
        let status = isCancelled ? "已取消" : (isCompleted ? "已完成" : "执行中")
        return "动画记录[\(recordID.uuidString.prefix(8))] 类型:\(type) \(windowInfo) 状态:\(status)"
    }
}

// MARK: - 迁回自 UI-02：class UIWindowAnimationManager
public final class UIWindowAnimationManager: NSObject , @unchecked Sendable{
    deinit {
        logger.info("UIWindowAnimationManager 已释放")
    }

    
    // MARK: 单例
    
    /// 全局共享实例
    public static let shared = UIWindowAnimationManager()
    
    // MARK: 日志
    
    /// 日志对象，用于输出调试信息
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "窗口动画管理器")
    
    // MARK: 线程安全
    
    /// 读写锁，保护动画记录表和配置等共享状态
    private let lock = NSRecursiveLock()
    
    // MARK: 动画记录
    
    /// 当前正在执行的动画记录表
    /// 键为动画记录 ID，值为动画记录对象
    private var activeRecords: [UUID: UIWindowAnimationRecord] = [:]
    
    /// 已完成的历史动画记录（保留最近 100 条用于调试）
    private var historyRecords: [UIWindowAnimationRecord] = []
    /// 历史记录最大容量
    private let maxHistoryCount = 100
    
    // MARK: 配置
    
    /// 各动画类型的默认配置表
    /// 键为动画类型，值为对应配置。未设置的类型使用全局默认配置
    private var typeConfigurations: [UIWindowAnimationType: UIWindowAnimationConfiguration] = [:]
    
    /// 全局默认配置（当类型配置未单独设置时使用）
    public var defaultConfiguration = UIWindowAnimationConfiguration() {
        didSet {
            logger.info("全局默认配置已更新: \(self.defaultConfiguration.description)")
        }
    }
    
    // MARK: 代理
    
    /// 弱引用代理集合，用于广播动画事件
    private var delegates = NSHashTable<AnyObject>.weakObjects()
    
    // MARK: 初始化
    
    /// 私有初始化，防止外部创建实例
    private override init() {
        super.init()
        logger.info("窗口动画管理器已初始化")
    }
    
    // MARK: 配置管理
    
    /// 获取指定动画类型的配置
    /// 如果该类型没有单独设置配置，则返回全局默认配置
    /// - Parameter type: 动画类型
    /// - Returns: 动画配置
    public func configuration(for type: UIWindowAnimationType) -> UIWindowAnimationConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return typeConfigurations[type] ?? defaultConfiguration
    }
    
    /// 设置指定动画类型的配置
    /// - Parameters:
    ///   - configuration: 动画配置
    ///   - type: 动画类型。nil 表示设置全局默认配置
    public func setConfiguration(_ configuration: UIWindowAnimationConfiguration, for type: UIWindowAnimationType? = nil) {
        lock.lock()
        defer { lock.unlock() }
        if let type = type {
            typeConfigurations[type] = configuration
            logger.info("已为类型 [\(type.description)] 设置配置: \(configuration.description)")
        } else {
            defaultConfiguration = configuration
            logger.info("已更新全局默认配置: \(configuration.description)")
        }
    }
    
    /// 重置所有类型配置为全局默认值
    public func resetAllConfigurations() {
        lock.lock()
        defer { lock.unlock() }
        typeConfigurations.removeAll()
        defaultConfiguration = UIWindowAnimationConfiguration()
        logger.info("已重置所有动画配置为默认值")
    }
    
    // MARK: 代理管理
    
    /// 添加动画代理
    /// - Parameter delegate: 实现 UIWindowAnimationDelegate 的对象
    public func addDelegate(_ delegate: UIWindowAnimationDelegate) {
        lock.lock()
        defer { lock.unlock() }
        delegates.add(delegate)
        logger.debug("已添加动画代理: \(String(describing: type(of: delegate)))")
    }
    
    /// 移除动画代理
    /// - Parameter delegate: 要移除的代理对象
    public func removeDelegate(_ delegate: UIWindowAnimationDelegate) {
        lock.lock()
        defer { lock.unlock() }
        delegates.remove(delegate)
        logger.debug("已移除动画代理")
    }
    
    /// 通知所有代理动画即将开始
    private func notifyWillStart(_ record: UIWindowAnimationRecord) {
        for case let delegate as UIWindowAnimationDelegate in delegates.allObjects {
            delegate.animationWillStart(record)
        }
    }
    
    /// 通知所有代理动画进度更新
    func notifyDidProgress(_ record: UIWindowAnimationRecord, progress: Double) {
        for case let delegate as UIWindowAnimationDelegate in delegates.allObjects {
            delegate.animationDidProgress(record, progress: progress)
        }
    }
    
    /// 通知所有代理动画已完成
    func notifyDidComplete(_ record: UIWindowAnimationRecord) {
        for case let delegate as UIWindowAnimationDelegate in delegates.allObjects {
            delegate.animationDidComplete(record)
        }
    }
    
    /// 通知所有代理动画已取消
    func notifyDidCancel(_ record: UIWindowAnimationRecord) {
        for case let delegate as UIWindowAnimationDelegate in delegates.allObjects {
            delegate.animationDidCancel(record)
        }
    }
    
    // MARK: 动画记录管理
    
    /// 注册动画记录
    private func registerRecord(_ record: UIWindowAnimationRecord) {
        lock.lock()
        defer { lock.unlock() }
        activeRecords[record.recordID] = record
        logger.debug("动画记录已注册: \(record.description)")
    }
    
    /// 完成动画记录，从活跃表移至历史表
    func completeRecord(_ record: UIWindowAnimationRecord) {
        lock.lock()
        defer { lock.unlock() }
        activeRecords.removeValue(forKey: record.recordID)
        record.markCompleted()
        historyRecords.append(record)
        if historyRecords.count > maxHistoryCount {
            historyRecords.removeFirst(historyRecords.count - maxHistoryCount)
        }
        logger.debug("动画记录已完成: \(record.description)")
    }
    
    /// 取消动画记录
    func cancelRecord(_ record: UIWindowAnimationRecord) {
        lock.lock()
        defer { lock.unlock() }
        record.markCancelled()
        activeRecords.removeValue(forKey: record.recordID)
        historyRecords.append(record)
        if historyRecords.count > maxHistoryCount {
            historyRecords.removeFirst(historyRecords.count - maxHistoryCount)
        }
        logger.debug("动画记录已取消: \(record.description)")
    }
    
    /// 获取当前活跃的动画记录列表
    public var activeAnimationRecords: [UIWindowAnimationRecord] {
        lock.lock()
        defer { lock.unlock() }
        return Array(activeRecords.values)
    }
    
    /// 获取历史动画记录列表
    public var historyAnimationRecords: [UIWindowAnimationRecord] {
        lock.lock()
        defer { lock.unlock() }
        return historyRecords
    }
    
    // MARK: 核心动画执行
    
    /// 执行 NSViewAnimation 动画，统一封装动画记录、代理通知、线程安全
    /// - Parameters:
    ///   - type: 动画类型
    ///   - window: 目标窗口
    ///   - viewAnimations: NSViewAnimation 所需的动画字典数组（包含 NSViewAnimationTargetKey, NSViewAnimationStartFrameKey, NSViewAnimationEndFrameKey, NSViewAnimationEffectKey 等）
    ///   - configuration: 动画配置（nil 时使用类型默认配置）
    ///   - completion: 完成回调
    /// - Returns: 动画记录对象，可用于取消或追踪
    @discardableResult
    private func executeAnimation(
        type: UIWindowAnimationType,
        window: NSWindow?,
        viewAnimations: [[NSViewAnimation.Key: Any]],
        configuration: UIWindowAnimationConfiguration? = nil,
        completion: UIWindowAnimationCompletion? = nil
    ) -> UIWindowAnimationRecord {
        
        let config = configuration ?? self.configuration(for: type)
        let record = UIWindowAnimationRecord(type: type, window: window)
        
        // 如果动画被禁用，瞬间完成
        guard config.isEnabled else {
            logger.debug("动画已禁用，瞬间执行: \(record.description)")
            // 直接应用结束状态
            for animDict in viewAnimations {
                if let targetWindow = animDict[.target] as? NSWindow,
                   let endFrame = animDict[.endFrame] as? NSValue {
                    targetWindow.setFrame(endFrame.rectValue, display: true)
                }
                if let effect = animDict[.effect] as? NSViewAnimation.EffectName {
                    if effect == .fadeIn {
                        window?.alphaValue = 1.0
                    } else if effect == .fadeOut {
                        window?.alphaValue = 0.0
                    }
                }
            }
            record.markCompleted()
            completion?(true)
            return record
        }
        
        // 注册记录
        registerRecord(record)
        
        // 创建 NSViewAnimation
        let animation = NSViewAnimation(viewAnimations: viewAnimations)
        animation.duration = config.duration
        animation.animationCurve = config.curve.nsAnimationCurve
        animation.animationBlockingMode = .nonblocking
        if config.frameRate > 0 {
            animation.frameRate = config.frameRate
        }
        
        // 设置代理（通过内部代理对象转发，避免循环引用）
        let delegateProxy = UIAnimationDelegateProxy(record: record, manager: self, completion: completion)
        animation.delegate = delegateProxy
        record.animation = animation
        
        // 保留代理对象（NSViewAnimation 的 delegate 是 weak，需要外部强引用）
        lock.lock()
        delegateProxies[record.recordID] = delegateProxy
        lock.unlock()
        
        // 通知代理
        notifyWillStart(record)
        
        // 启动动画
        logger.info("动画开始执行: \(record.description), 配置: \(config.description)")
        animation.start()
        
        return record
    }
    
    /// 存储代理对象，防止被过早释放（键为动画记录 ID）
    private var delegateProxies: [UUID: UIAnimationDelegateProxy] = [:]
    
    /// 清理代理对象
    func cleanupDelegateProxy(for recordID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        delegateProxies.removeValue(forKey: recordID)
    }
    
    // MARK: 窗口打开动画
    
    /// 执行窗口打开动画
    /// 效果：窗口从下方缩略图状态放大到目标位置并淡入
    /// - Parameters:
    ///   - window: 要打开的窗口
    ///   - targetFrame: 目标窗口位置和大小。nil 时使用窗口当前 frame
    ///   - configuration: 动画配置。nil 时使用默认配置
    ///   - completion: 完成回调
    /// - Returns: 动画记录
    @discardableResult
    public func animateOpen(
        window: NSWindow,
        targetFrame: NSRect? = nil,
        configuration: UIWindowAnimationConfiguration? = nil,
        completion: UIWindowAnimationCompletion? = nil
    ) -> UIWindowAnimationRecord {
        let finalFrame = targetFrame ?? window.frame
        
        // 计算起始 frame：中心点相同，尺寸缩小为 0.1 倍，位置偏下
        let startFrame = NSRect(
            x: finalFrame.midX - finalFrame.width * 0.05,
            y: finalFrame.minY - finalFrame.height * 0.2,
            width: finalFrame.width * 0.1,
            height: finalFrame.height * 0.1
        )
        
        // 先设置窗口为初始状态（不可见、小尺寸）
        window.setFrame(startFrame, display: false)
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        
        let animDict: [NSViewAnimation.Key: Any] = [
            .target: window,
            .startFrame: NSValue(rect: startFrame),
            .endFrame: NSValue(rect: finalFrame),
            .effect: NSViewAnimation.EffectName.fadeIn
        ]
        
        return executeAnimation(
            type: .open,
            window: window,
            viewAnimations: [animDict],
            configuration: configuration,
            completion: completion
        )
    }
    
    // MARK: 窗口关闭动画
    
    /// 执行窗口关闭动画
    /// 效果：窗口缩小并淡出，动画完成后执行关闭
    /// - Parameters:
    ///   - window: 要关闭的窗口
    ///   - configuration: 动画配置。nil 时使用默认配置
    ///   - completion: 完成回调（finished 为 true 表示动画正常结束并关闭）
    /// - Returns: 动画记录
    @discardableResult
    public func animateClose(
        window: NSWindow,
        configuration: UIWindowAnimationConfiguration? = nil,
        completion: UIWindowAnimationCompletion? = nil
    ) -> UIWindowAnimationRecord {
        let startFrame = window.frame
        
        // 目标 frame：中心点相同，尺寸缩小为 0.1 倍，位置偏下
        let endFrame = NSRect(
            x: startFrame.midX - startFrame.width * 0.05,
            y: startFrame.minY - startFrame.height * 0.2,
            width: startFrame.width * 0.1,
            height: startFrame.height * 0.1
        )
        
        let animDict: [NSViewAnimation.Key: Any] = [
            .target: window,
            .startFrame: NSValue(rect: startFrame),
            .endFrame: NSValue(rect: endFrame),
            .effect: NSViewAnimation.EffectName.fadeOut
        ]
        
        let _ = configuration ?? self.configuration(for: .close)
        
        return executeAnimation(
            type: .close,
            window: window,
            viewAnimations: [animDict],
            configuration: configuration
        ) { [weak self] finished in
            // 动画完成后关闭窗口
            if finished {
                window.close()
                self?.logger.info("窗口已关闭: \(window.title)")
            }
            completion?(finished)
        }
    }
    
    // MARK: 窗口最小化动画
    
    /// 执行窗口最小化动画
    /// 效果：窗口缩向屏幕底部（Dock 方向）并淡出，然后执行实际的最小化
    /// - Parameters:
    ///   - window: 要最小化的窗口
    ///   - configuration: 动画配置。nil 时使用默认配置
    ///   - completion: 完成回调
    /// - Returns: 动画记录
    @discardableResult
    public func animateMinimize(
        window: NSWindow,
        configuration: UIWindowAnimationConfiguration? = nil,
        completion: UIWindowAnimationCompletion? = nil
    ) -> UIWindowAnimationRecord {
        let startFrame = window.frame
        
        // 计算目标位置：屏幕底部中心，尺寸极小
        let screen = window.screen ?? NSScreen.main
        guard let screenFrame = screen?.visibleFrame, screenFrame.width > 0, screenFrame.height > 0 else {
            logger.warning("无法获取屏幕可见区域，使用窗口当前位置")
            let fallbackFrame = NSRect(
                x: startFrame.midX - startFrame.width * 0.05,
                y: startFrame.minY - startFrame.height * 0.2,
                width: startFrame.width * 0.1,
                height: startFrame.height * 0.1
            )
            let fallbackDict: [NSViewAnimation.Key: Any] = [
                .target: window,
                .startFrame: NSValue(rect: startFrame),
                .endFrame: NSValue(rect: fallbackFrame),
                .effect: NSViewAnimation.EffectName.fadeOut
            ]
            return executeAnimation(
                type: .minimize,
                window: window,
                viewAnimations: [fallbackDict],
                configuration: configuration
            ) { [weak self] finished in
                if finished {
                    window.miniaturize(nil)
                    self?.logger.info("窗口已最小化: \(window.title)")
                }
                completion?(finished)
            }
        }
        
        let endWidth = max(startFrame.width * 0.1, 20)
        let endHeight = max(startFrame.height * 0.1, 15)
        let endFrame = NSRect(
            x: screenFrame.midX - endWidth / 2,
            y: screenFrame.minY,
            width: endWidth,
            height: endHeight
        )
        
        let animDict: [NSViewAnimation.Key: Any] = [
            .target: window,
            .startFrame: NSValue(rect: startFrame),
            .endFrame: NSValue(rect: endFrame),
            .effect: NSViewAnimation.EffectName.fadeOut
        ]
        
        return executeAnimation(
            type: .minimize,
            window: window,
            viewAnimations: [animDict],
            configuration: configuration
        ) { [weak self] finished in
            if finished {
                // 执行实际的最小化到 Dock
                window.miniaturize(nil)
                self?.logger.info("窗口已最小化: \(window.title)")
            }
            completion?(finished)
        }
    }
    
    // MARK: 窗口恢复动画
    
    /// 执行窗口恢复动画（从最小化状态恢复）
    /// 效果：窗口从屏幕底部放大到目标位置并淡入
    /// - Parameters:
    ///   - window: 要恢复的窗口
    ///   - targetFrame: 恢复后的目标位置和大小。nil 时使用窗口当前 frame 或默认尺寸
    ///   - configuration: 动画配置。nil 时使用默认配置
    ///   - completion: 完成回调
    /// - Returns: 动画记录
    @discardableResult
    public func animateRestore(
        window: NSWindow,
        targetFrame: NSRect? = nil,
        configuration: UIWindowAnimationConfiguration? = nil,
        completion: UIWindowAnimationCompletion? = nil
    ) -> UIWindowAnimationRecord {
        // 先从 Dock 中恢复（如果正在最小化）
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        
        let finalFrame = targetFrame ?? window.frame
        
        // 计算起始 frame：屏幕底部中心，极小尺寸
        let startFrame: NSRect
        let screen = window.screen ?? NSScreen.main
        if let screenFrame = screen?.visibleFrame, screenFrame.width > 0, screenFrame.height > 0 {
            let sw = max(finalFrame.width * 0.1, 20)
            let sh = max(finalFrame.height * 0.1, 15)
            startFrame = NSRect(
                x: screenFrame.midX - sw / 2,
                y: screenFrame.minY,
                width: sw,
                height: sh
            )
        } else {
            logger.warning("无法获取屏幕可见区域，使用窗口当前位置作为起点")
            startFrame = finalFrame
        }
        
        // 先设置为初始状态
        window.setFrame(startFrame, display: false)
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        
        let animDict: [NSViewAnimation.Key: Any] = [
            .target: window,
            .startFrame: NSValue(rect: startFrame),
            .endFrame: NSValue(rect: finalFrame),
            .effect: NSViewAnimation.EffectName.fadeIn
        ]
        
        return executeAnimation(
            type: .restore,
            window: window,
            viewAnimations: [animDict],
            configuration: configuration,
            completion: completion
        )
    }
    
    // MARK: 淡入动画
    
    /// 执行窗口淡入动画
    /// 效果：窗口透明度从 0 渐变到 1，位置和尺寸保持不变
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - configuration: 动画配置。nil 时使用默认配置
    ///   - completion: 完成回调
    /// - Returns: 动画记录
    @discardableResult
    public func animateFadeIn(
        window: NSWindow,
        configuration: UIWindowAnimationConfiguration? = nil,
        completion: UIWindowAnimationCompletion? = nil
    ) -> UIWindowAnimationRecord {
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        
        let frame = window.frame
        let animDict: [NSViewAnimation.Key: Any] = [
            .target: window,
            .startFrame: NSValue(rect: frame),
            .endFrame: NSValue(rect: frame),
            .effect: NSViewAnimation.EffectName.fadeIn
        ]
        
        return executeAnimation(
            type: .fadeIn,
            window: window,
            viewAnimations: [animDict],
            configuration: configuration,
            completion: completion
        )
    }
    
    // MARK: 淡出动画
    
    /// 执行窗口淡出动画
    /// 效果：窗口透明度从当前值渐变到 0，位置和尺寸保持不变
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - configuration: 动画配置。nil 时使用默认配置
    ///   - completion: 完成回调
    /// - Returns: 动画记录
    @discardableResult
    public func animateFadeOut(
        window: NSWindow,
        configuration: UIWindowAnimationConfiguration? = nil,
        completion: UIWindowAnimationCompletion? = nil
    ) -> UIWindowAnimationRecord {
        let frame = window.frame
        let animDict: [NSViewAnimation.Key: Any] = [
            .target: window,
            .startFrame: NSValue(rect: frame),
            .endFrame: NSValue(rect: frame),
            .effect: NSViewAnimation.EffectName.fadeOut
        ]
        
        return executeAnimation(
            type: .fadeOut,
            window: window,
            viewAnimations: [animDict],
            configuration: configuration,
            completion: completion
        )
    }
    
    // MARK: 缩放动画
    
    /// 执行窗口缩放动画
    /// 效果：窗口尺寸和位置平滑过渡到目标 frame
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - targetFrame: 目标位置和大小
    ///   - configuration: 动画配置。nil 时使用默认配置
    ///   - completion: 完成回调
    /// - Returns: 动画记录
    @discardableResult
    public func animateScale(
        window: NSWindow,
        to targetFrame: NSRect,
        configuration: UIWindowAnimationConfiguration? = nil,
        completion: UIWindowAnimationCompletion? = nil
    ) -> UIWindowAnimationRecord {
        let startFrame = window.frame
        
        let animDict: [NSViewAnimation.Key: Any] = [
            .target: window,
            .startFrame: NSValue(rect: startFrame),
            .endFrame: NSValue(rect: targetFrame)
        ]
        
        return executeAnimation(
            type: .scale,
            window: window,
            viewAnimations: [animDict],
            configuration: configuration,
            completion: completion
        )
    }
    
    /// 执行窗口缩放动画（以中心点为基准缩放）
    /// 效果：窗口以当前中心点为基准，缩放到目标尺寸
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - targetSize: 目标尺寸
    ///   - configuration: 动画配置。nil 时使用默认配置
    ///   - completion: 完成回调
    /// - Returns: 动画记录
    @discardableResult
    public func animateScale(
        window: NSWindow,
        toSize targetSize: NSSize,
        configuration: UIWindowAnimationConfiguration? = nil,
        completion: UIWindowAnimationCompletion? = nil
    ) -> UIWindowAnimationRecord {
        let currentFrame = window.frame
        let targetFrame = NSRect(
            x: currentFrame.midX - targetSize.width / 2,
            y: currentFrame.midY - targetSize.height / 2,
            width: targetSize.width,
            height: targetSize.height
        )
        return animateScale(
            window: window,
            to: targetFrame,
            configuration: configuration,
            completion: completion
        )
    }
    
    // MARK: 自定义组合动画
    
    /// 执行自定义动画序列
    /// 允许同时动画多个窗口或一个窗口的多个属性
    /// - Parameters:
    ///   - viewAnimations: NSViewAnimation 动画字典数组
    ///   - configuration: 动画配置。nil 时使用自定义类型的默认配置
    ///   - completion: 完成回调
    /// - Returns: 动画记录
    @discardableResult
    public func animateCustom(
        viewAnimations: [[NSViewAnimation.Key: Any]],
        configuration: UIWindowAnimationConfiguration? = nil,
        completion: UIWindowAnimationCompletion? = nil
    ) -> UIWindowAnimationRecord {
        return executeAnimation(
            type: .custom,
            window: nil,
            viewAnimations: viewAnimations,
            configuration: configuration,
            completion: completion
        )
    }
    
    // MARK: 动画控制
    
    /// 取消指定动画
    /// - Parameter record: 要取消的动画记录
    public func cancelAnimation(_ record: UIWindowAnimationRecord) {
        // 先在外部停止动画，避免锁内触发系统回调
        record.animation?.stop()
        
        var cancelled = false
        lock.lock()
        if let existing = activeRecords[record.recordID] {
            existing.markCancelled()
            activeRecords.removeValue(forKey: existing.recordID)
            delegateProxies.removeValue(forKey: existing.recordID)
            cancelled = true
        }
        lock.unlock()
        
        if cancelled {
            notifyDidCancel(record)
            logger.info("动画已取消: \(record.description)")
        } else {
            logger.warning("取消失败：动画记录不在活跃列表中: \(record.recordID)")
        }
    }
    
    /// 取消窗口的所有活跃动画
    /// - Parameter window: 目标窗口
    public func cancelAnimations(for window: NSWindow) {
        lock.lock()
        let recordsToCancel = activeRecords.values.filter { $0.window === window }
        lock.unlock()
        
        for record in recordsToCancel {
            cancelAnimation(record)
        }
    }
    
    /// 取消所有活跃动画
    public func cancelAllAnimations() {
        lock.lock()
        let recordsToCancel = Array(activeRecords.values)
        lock.unlock()
        
        for record in recordsToCancel {
            cancelAnimation(record)
        }
        logger.info("已取消所有活跃动画，共 \(recordsToCancel.count) 条")
    }
    
    // MARK: 动画状态查询
    
    /// 检查窗口是否有活跃动画
    /// - Parameter window: 目标窗口
    /// - Returns: 是否有活跃动画
    public func hasActiveAnimation(for window: NSWindow) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeRecords.values.contains(where: { $0.window === window })
    }
    
    /// 获取窗口的活跃动画记录
    /// - Parameter window: 目标窗口
    /// - Returns: 活跃动画记录列表
    public func activeAnimations(for window: NSWindow) -> [UIWindowAnimationRecord] {
        lock.lock()
        defer { lock.unlock() }
        return activeRecords.values.filter { $0.window === window }
    }
    
    /// 获取当前活跃动画总数
    public var activeAnimationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeRecords.count
    }
    
    // MARK: 调试工具
    
    /// 打印当前动画状态报告（用于调试）
    public func printStatusReport() {
        lock.lock()
        let active = Array(activeRecords.values)
        let history = historyRecords
        lock.unlock()
        
        logger.info("=== 窗口动画管理器状态报告 ===")
        logger.info("活跃动画数量: \(active.count)")
        for record in active {
            logger.info("  [活跃] \(record.description)")
        }
        logger.info("历史记录数量: \(history.count)/\(self.maxHistoryCount)")
        for record in history.suffix(5) {
            logger.info("  [历史] \(record.description)")
        }
        logger.info("================================")
    }
}

// MARK: - 迁回自 UI-02：class UIAnimationDelegateProxy
private class UIAnimationDelegateProxy: NSObject, NSAnimationDelegate , @unchecked Sendable{
    
    /// 关联的动画记录
    private let record: UIWindowAnimationRecord
    
    /// 弱引用管理器（避免循环）
    private weak var manager: UIWindowAnimationManager?
    
    /// 完成回调
    private let completion: UIWindowAnimationCompletion?
    
    /// 初始化
    init(record: UIWindowAnimationRecord, manager: UIWindowAnimationManager, completion: UIWindowAnimationCompletion?) {
        self.record = record
        self.manager = manager
        self.completion = completion
        super.init()
    }
    
    // MARK: NSAnimationDelegate
    
    /// 动画开始
    func animationDidStart(_ animation: NSAnimation) {
        // 记录已在执行前注册，此处无需额外操作
    }
    
    /// 动画停止（完成或取消都会触发）
    func animationDidStop(_ animation: NSAnimation) {
        guard let manager = manager else { return }
        
        // 动画正常结束（没有被停止）
        if animation.currentProgress >= 1.0 {
            manager.completeRecord(record)
            manager.notifyDidComplete(record)
            completion?(true)
        } else {
            // 动画被提前停止（取消）
            manager.cancelRecord(record)
            manager.notifyDidCancel(record)
            completion?(false)
        }
        
        // 清理代理对象
        manager.cleanupDelegateProxy(for: record.recordID)
    }
    
    /// 动画进度更新（每帧调用）
    func animationDidAdvance(_ animation: NSAnimation) {
        guard let manager = manager else { return }
        let progress = Double(animation.currentProgress)
        manager.notifyDidProgress(record, progress: progress)
    }
    
    /// 动画是否应该在某个进度值达到时触发事件（返回 true 允许触发）
    func animation(_ animation: NSAnimation, shouldStartAnimationFor view: NSView?, withObjectValue object: Any?, forKey event: String?) -> Bool {
        return true
    }
}

// MARK: - 迁回自 UI-02：enum UIWindowAnimationCurve
// MARK: - 屏幕变更通知
/// 多屏幕相关通知名称
// 已迁回 UI-GL-02_多屏幕支持.swift：extension Notification.Name（公共类型文件禁止功能实现）

// MARK: - 多屏幕管理器
/// 单例管理器，负责窗口在多屏幕间的自动适配、位置记忆、DPI缩放处理
/// 线程安全：所有可变状态通过 NSLock 保护
// 已迁回 UI-GL-02_多屏幕支持.swift：class UIMultiScreenManager（公共类型文件禁止功能实现）

// MARK: - NSScreen 便捷扩展（包内可见）
// 已迁回 UI-GL-02_多屏幕支持.swift：extension NSScreen（公共类型文件禁止功能实现）


// MARK: - UI-GL-03 合并类型
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-03_types.swift
// 版本: 2.0

// MARK: - 动画曲线类型

/// 窗口动画的缓动曲线类型
/// 定义动画过程中值变化的速度规律
public enum UIWindowAnimationCurve: Int, CaseIterable, Sendable, CustomStringConvertible {
    /// 线性变化，匀速运动
    case linear = 0
    /// 缓入，由慢到快
    case easeIn
    /// 缓出，由快到慢
    case easeOut
    /// 缓入缓出，两端平滑
    case easeInOut
    /// 阻尼弹性效果，带轻微回弹
    case springDamping
    
    public var description: String {
        switch self {
        case .linear:        return "线性"
        case .easeIn:        return "缓入"
        case .easeOut:       return "缓出"
        case .easeInOut:     return "缓入缓出"
        case .springDamping: return "弹性阻尼"
        }
    }
    
    /// 转换为 NSAnimation 的动画曲线
    /// 注意：NSAnimation 原生仅支持有限的曲线，额外曲线通过自定义插值实现
    var nsAnimationCurve: NSAnimation.Curve {
        switch self {
        case .linear:    return .linear
        case .easeIn:    return .easeIn
        case .easeOut:   return .easeOut
        case .easeInOut: return .easeInOut
        case .springDamping:
            // 弹性阻尼使用 easeInOut 作为基础，在动画代理中叠加回弹效果
            return .easeInOut
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIWindowAnimationConfiguration
// MARK: - 动画配置

/// 窗口动画配置项
/// 每条动画可独立设置时长、曲线、阻尼等参数
public struct UIWindowAnimationConfiguration: Sendable, CustomStringConvertible {
    
    // MARK: 默认配置
    
    /// 全局默认动画时长（秒）
    public static let defaultDuration: TimeInterval = 0.25
    /// 全局默认动画曲线
    public static let defaultCurve: UIWindowAnimationCurve = .easeInOut
    /// 全局默认阻尼系数（0.0~1.0，越大回弹越弱）
    public static let defaultDamping: CGFloat = 0.75
    /// 全局默认是否使用动画
    public static let defaultEnabled: Bool = true
    
    // MARK: 配置属性
    
    /// 动画时长（秒），值必须大于 0
    public var duration: TimeInterval
    /// 动画曲线
    public var curve: UIWindowAnimationCurve
    /// 阻尼系数（仅对 springDamping 曲线有效），范围 0.0~1.0
    public var damping: CGFloat
    /// 动画帧率（每秒更新次数），0 表示使用系统默认
    public var frameRate: Float
    /// 是否启用动画。false 时所有变化瞬间完成
    public var isEnabled: Bool
    
    // MARK: 初始化
    
    /// 创建动画配置
    /// - Parameters:
    ///   - duration: 动画时长（秒），默认 0.25
    ///   - curve: 动画曲线，默认 easeInOut
    ///   - damping: 阻尼系数，默认 0.75
    ///   - frameRate: 帧率，默认 0（系统默认）
    ///   - isEnabled: 是否启用动画，默认 true
    public init(
        duration: TimeInterval = defaultDuration,
        curve: UIWindowAnimationCurve = defaultCurve,
        damping: CGFloat = defaultDamping,
        frameRate: Float = 0,
        isEnabled: Bool = defaultEnabled
    ) {
        self.duration = max(duration, 0.01)
        self.curve = curve
        self.damping = max(0.0, min(1.0, damping))
        self.frameRate = max(0, frameRate)
        self.isEnabled = isEnabled
    }
    
    /// 描述字符串，用于日志输出
    public var description: String {
        "动画配置[时长:\(String(format: "%.3f", duration))s, 曲线:\(curve), 阻尼:\(String(format: "%.2f", damping)), 帧率:\(frameRate == 0 ? "系统默认" : String(format: "%.0f", frameRate)), 启用:\(isEnabled ? "是" : "否")]"
    }
}

// MARK: - 迁回自 UI-02：enum UIWindowAnimationType
// MARK: - 动画类型

/// 窗口动画的类型标识
public enum UIWindowAnimationType: String, CustomStringConvertible {
    /// 窗口打开动画（从屏幕外或缩略图放大到目标位置）
    case open       = "打开"
    /// 窗口关闭动画（缩小并淡出）
    case close      = "关闭"
    /// 窗口最小化动画（缩向 Dock 或屏幕底部）
    case minimize   = "最小化"
    /// 窗口恢复动画（从 Dock 或屏幕底部展开）
    case restore    = "恢复"
    /// 淡入动画（仅改变透明度）
    case fadeIn     = "淡入"
    /// 淡出动画（仅改变透明度）
    case fadeOut    = "淡出"
    /// 缩放动画（改变窗口大小）
    case scale      = "缩放"
    /// 自定义组合动画
    case custom     = "自定义"
    
    public var description: String { rawValue }
}

// MARK: - 迁回自 UI-02：typealias UIWindowAnimationCompletion
// MARK: - 动画执行记录

/// 单次动画执行的记录信息，用于追踪和回调
// 已迁回 UI-GL-03_窗口动画效果.swift：class UIWindowAnimationRecord（公共类型文件禁止功能实现）

// MARK: - 动画代理协议

/// 窗口动画的自定义代理协议
/// 在标准 NSAnimationDelegate 基础上增加业务层面的回调
public typealias UIWindowAnimationCompletion = (_ finished: Bool) -> Void

// MARK: - 迁回自 UI-02：protocol UIWindowAnimationDelegate
public protocol UIWindowAnimationDelegate: AnyObject {
    /// 动画即将开始
    func animationWillStart(_ record: UIWindowAnimationRecord)
    /// 动画进度更新（0.0 ~ 1.0）
    func animationDidProgress(_ record: UIWindowAnimationRecord, progress: Double)
    /// 动画已完成（正常结束）
    func animationDidComplete(_ record: UIWindowAnimationRecord)
    /// 动画已取消（被中断）
    func animationDidCancel(_ record: UIWindowAnimationRecord)
}
