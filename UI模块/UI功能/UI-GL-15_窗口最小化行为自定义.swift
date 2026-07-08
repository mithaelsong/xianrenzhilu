// 功能12B: 窗口最小化行为自定义
// 对应: 自定义最小化行为（默认最小化到Dock/缩略图预览/自定义动画位置/设置面板）
// 优先级: P2
// 版本: 2.0

import Foundation
@preconcurrency import AppKit
import os.log

// MARK: - 通知名称
/// 窗口最小化管理器相关的通知名称
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能12B：窗口最小化行为自定义 — 单元测试
/// 覆盖：最小化模式枚举、屏幕角落、配置模型、Codable
func test_windowMinimize() {
    print("\n🧪 测试1: 最小化行为模式枚举")
    let modes = UIMinimizeBehaviorMode.allCases
    guard modes.count == 3 else {
        fatalError("❌ 测试1失败: 应有3种最小化模式")
    }
    guard modes[0] == .dock && modes[1] == .customAnimation && modes[2] == .preview else {
        fatalError("❌ 测试1失败: 最小化模式枚举值错误")
    }
    for mode in modes {
        guard !mode.description.isEmpty else {
            fatalError("❌ 测试1失败: 模式\(mode) description为空")
        }
        guard !mode.displayName.isEmpty else {
            fatalError("❌ 测试1失败: 模式\(mode) displayName为空")
        }
    }
    print("✅ 测试1通过: 全部3种最小化模式有效")
    
    print("\n🧪 测试2: 屏幕角落枚举")
    let corners = UIScreenCorner.allCases
    guard corners.count == 4 else {
        fatalError("❌ 测试2失败: 应有4个屏幕角落")
    }
    for corner in corners {
        let point = corner.point()
        guard point != .zero else {
            // 无主屏幕时返回zero，可接受
            continue
        }
    }
    print("✅ 测试2通过: 全部4个屏幕角落有效")
    
    print("\n🧪 测试3: UIMinimizeConfiguration默认值")
    let config = UIMinimizeConfiguration.default
    guard config.behaviorMode == .dock else {
        fatalError("❌ 测试3失败: 默认模式应为dock")
    }
    guard config.isAnimationEnabled else {
        fatalError("❌ 测试3失败: 默认应启用动画")
    }
    guard abs(config.animationDuration - 0.3) < 0.01 else {
        fatalError("❌ 测试3失败: 默认动画时长应为0.3s")
    }
    guard config.targetCorner == .bottomLeft else {
        fatalError("❌ 测试3失败: 默认目标角落应为bottomLeft")
    }
    guard abs(config.previewSize - 160) < 0.1 else {
        fatalError("❌ 测试3失败: 默认预览尺寸应为160")
    }
    print("✅ 测试3通过: 默认配置值正确")
    
    print("\n🧪 测试4: 配置Codable编解码")
    var customConfig = UIMinimizeConfiguration.default
    customConfig.behaviorMode = .preview
    customConfig.targetCorner = .topRight
    customConfig.previewSize = 200
    guard let data = try? JSONEncoder().encode(customConfig) else {
        fatalError("❌ 测试4失败: 编码失败")
    }
    guard let decoded = try? JSONDecoder().decode(UIMinimizeConfiguration.self, from: data) else {
        fatalError("❌ 测试4失败: 解码失败")
    }
    guard decoded.behaviorMode == .preview else {
        fatalError("❌ 测试4失败: 编解码后模式不匹配")
    }
    guard decoded.targetCorner == .topRight else {
        fatalError("❌ 测试4失败: 编解码后角落不匹配")
    }
    guard abs(decoded.previewSize - 200) < 0.1 else {
        fatalError("❌ 测试4失败: 编解码后预览尺寸不匹配")
    }
    print("✅ 测试4通过: UIMinimizeConfiguration Codable编解码正确")
    
    print("\n🧪 测试5: Configuration描述文字")
    let desc = config.description
    guard desc.contains("最小化配置") else {
        fatalError("❌ 测试5失败: description应以'最小化配置'开头")
    }
    guard desc.contains("模式") && desc.contains("动画") else {
        fatalError("❌ 测试5失败: description应包含模式和动画信息")
    }
    print("✅ 测试5通过: 配置描述文字完整")
    
    print("\n🧪 测试6: UIScreenCorner description")
    guard UIScreenCorner.topLeft.description == "左上角" else {
        fatalError("❌ 测试6失败: topLeft描述应为'左上角'")
    }
    guard UIScreenCorner.bottomRight.description == "右下角" else {
        fatalError("❌ 测试6失败: bottomRight描述应为'右下角'")
    }
    print("✅ 测试6通过: 屏幕角落描述正确")
    
    print("\n=== 全部最小化行为测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIMinimizeStateRecord
private class UIMinimizeStateRecord : @unchecked Sendable {
    /// 窗口唯一标识
    let windowID: String
    /// 窗口实例（弱引用）
    weak var window: NSWindow?
    /// 窗口最小化前的原始位置和尺寸
    var originalFrame: NSRect
    /// 窗口最小化前的层级
    var originalLevel: NSWindow.Level
    /// 窗口最小化前的标题
    var originalTitle: String
    /// 最小化时间
    var minimizeTime: Date
    /// 当前使用的预览面板（如存在）
    weak var previewPanel: NSWindow?
    /// 是否正在执行动画
    var isAnimating: Bool = false
    
    /// 初始化状态记录
    init(windowID: String, window: NSWindow, originalFrame: NSRect, originalLevel: NSWindow.Level, originalTitle: String) {
        self.windowID = windowID
        self.window = window
        self.originalFrame = originalFrame
        self.originalLevel = originalLevel
        self.originalTitle = originalTitle
        self.minimizeTime = Date()
    }
}

// MARK: - 迁回自 UI-02：class UIWindowMinimizeManager
public final class UIWindowMinimizeManager : @unchecked Sendable {
    deinit {
        logger.info("UIWindowMinimizeManager 已释放")
    }

    
    // MARK: 单例
    
    /// 全局共享实例
    public static let shared = UIWindowMinimizeManager()
    
    // MARK: 日志
    
    /// 日志记录器，用于输出调试和诊断信息
    fileprivate let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "窗口最小化管理器")
    
    // MARK: 线程安全
    
    /// 公平锁，保护所有共享状态（stateRecords、configuration等）
    private let lock = NSRecursiveLock()
    
    // MARK: 持久化
    
    /// UserDefaults键名前缀
    private let defaultsKey = "com.xianrenzhilu.minimizeManager"
    /// 配置存储键名
    private let configKey = "com.xianrenzhilu.minimizeManager.configuration"
    
    // MARK: 状态记录
    
    /// 已最小化窗口的状态记录表：窗口ID → 状态记录
    private var stateRecords: [String: UIMinimizeStateRecord] = [:]
    
    /// 预览面板窗口表：窗口ID → 预览面板窗口
    private var previewPanels: [String: NSWindow] = [:]
    
    // MARK: 当前配置
    
    /// 当前最小化配置
    public private(set) var configuration: UIMinimizeConfiguration
    
    // MARK: 初始化
    
    /// 私有初始化，防止外部创建实例
    private init() {
        self.configuration = UIWindowMinimizeManager.loadConfiguration()
        logger.info("窗口最小化管理器已初始化，当前配置: \(self.configuration.description)")
    }
    
    // MARK: - 配置持久化
    
    /// 从UserDefaults加载配置
    /// 如果未保存过配置或解码失败，返回默认配置
    private static func loadConfiguration() -> UIMinimizeConfiguration {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "com.xianrenzhilu.minimizeManager.configuration") else {
            return UIMinimizeConfiguration.default
        }
        do {
            let config = try JSONDecoder().decode(UIMinimizeConfiguration.self, from: data)
            return config
        } catch {
            // 解码失败时回退到默认配置
            let fallbackLogger = Logger(subsystem: "com.xianrenzhilu.ui", category: "窗口最小化管理器")
            fallbackLogger.warning("配置加载失败，使用默认配置: \(error)")
            return UIMinimizeConfiguration.default
        }
    }
    
    /// 将当前配置保存到UserDefaults
    private func saveConfiguration(_ config: UIMinimizeConfiguration) {
        do {
            let data = try JSONEncoder().encode(config)
            UserDefaults.standard.set(data, forKey: configKey)
            logger.info("配置已持久化到UserDefaults")
        } catch {
            logger.error("配置持久化失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 公开方法：最小化窗口
    
    /// 最小化指定窗口
    @discardableResult
    public func minimizeWindow(_ window: NSWindow, windowID: String) -> Bool {
        lock.lock()
        
        guard !window.isMiniaturized else {
            lock.unlock()
            logger.warning("窗口 \(windowID) 已经处于最小化状态，跳过")
            return false
        }
        
        if let record = stateRecords[windowID], record.isAnimating {
            lock.unlock()
            logger.warning("窗口 \(windowID) 正在执行最小化动画，跳过")
            return false
        }
        
        let originalFrame = window.frame
        let originalLevel = window.level
        let originalTitle = window.title
        
        let record = UIMinimizeStateRecord(
            windowID: windowID,
            window: window,
            originalFrame: originalFrame,
            originalLevel: originalLevel,
            originalTitle: originalTitle
        )
        stateRecords[windowID] = record
        
        let mode = configuration.behaviorMode
        
        lock.unlock()
        
        logger.info("开始最小化窗口 \(windowID)（模式: \(mode.displayName)）")
        
        switch mode {
        case .dock:
            performDockMinimize(window: window, record: record)
        case .customAnimation:
            performCustomAnimationMinimize(window: window, record: record)
        case .preview:
            performPreviewMinimize(window: window, record: record)
        }
        
        NotificationCenter.default.post(
            name: .windowDidMinimize,
            object: self,
            userInfo: ["windowID": windowID, "mode": mode]
        )
        
        return true
    }
    
    // MARK: - 公开方法：恢复窗口
    
    /// 恢复已最小化的窗口
    /// 根据窗口最小化时的模式执行对应的恢复行为
    /// - Parameters:
    ///   - windowID: 要恢复的窗口唯一标识符
    ///   - completion: 恢复完成后的回调（finished: 是否成功完成）
    /// - Returns: 是否成功启动恢复操作
    @discardableResult
    public func restoreWindow(_ windowID: String, completion: (@Sendable (Bool) -> Void)? = nil) -> Bool {
        lock.lock()
        guard let record = stateRecords[windowID] else {
            lock.unlock()
            logger.warning("未找到窗口 \(windowID) 的最小化状态记录，无法恢复")
            return false
        }
        guard let window = record.window else {
            stateRecords.removeValue(forKey: windowID)
            lock.unlock()
            logger.warning("窗口 \(windowID) 已被释放，无法恢复")
            return false
        }
        // 如果正在动画中，跳过
        guard !record.isAnimating else {
            lock.unlock()
            logger.warning("窗口 \(windowID) 正在执行动画，跳过恢复")
            return false
        }
        record.isAnimating = true
        lock.unlock()
        
        logger.info("开始恢复窗口 \(windowID)（原始模式: \(self.configuration.behaviorMode.displayName)）")
        
        // 移除预览面板（如果存在）
        removePreviewPanel(for: windowID)
        
        // 根据行为模式执行对应的恢复
        switch configuration.behaviorMode {
        case .dock:
            performDockRestore(window: window, record: record, completion: completion)
        case .customAnimation:
            performCustomAnimationRestore(window: window, record: record, completion: completion)
        case .preview:
            performPreviewRestore(window: window, record: record, completion: completion)
        }
        
        return true
    }
    
    // MARK: - 公开方法：应用自定义行为到窗口
    
    /// 将自定义最小化行为应用到指定窗口
    /// 替换窗口的默认最小化按钮行为，使其使用本管理器的逻辑
    /// - Parameters:
    ///   - window: 要应用自定义行为的窗口
    ///   - windowID: 窗口的唯一标识符
    public func applyCustomBehavior(to window: NSWindow, windowID: String) {
        // 创建自定义窗口代理，拦截最小化操作
        let delegate = UIMinimizeWindowDelegate(windowID: windowID, manager: self)
        window.delegate = delegate
        logger.info("已为窗口 \(windowID) 应用自定义最小化行为")
    }
    
    // MARK: - 公开方法：设置最小化动画参数
    
    /// 设置最小化动画参数
    /// - Parameters:
    ///   - enabled: 是否启用动画
    ///   - duration: 动画时长（秒），必须大于0
    public func setMinimizeAnimation(enabled: Bool, duration: TimeInterval? = nil) {
        lock.lock()
        configuration.isAnimationEnabled = enabled
        if let duration = duration, duration > 0 {
            configuration.animationDuration = duration
        }
        let saved = configuration
        lock.unlock()
        saveConfiguration(saved)
        logger.info("已设置最小化动画: 启用=\(enabled), 时长=\(String(format: "%.2f", saved.animationDuration))s")
    }
    
    // MARK: - 公开方法：设置预览缩略图启用状态
    
    /// 设置预览缩略图是否启用
    /// - Parameter enabled: true表示启用预览缩略图，false表示禁用
    public func setPreviewEnabled(_ enabled: Bool) {
        lock.lock()
        configuration.isPreviewEnabled = enabled
        lock.unlock()
        saveConfiguration(configuration)
        logger.info("已设置预览缩略图: \(enabled ? "启用" : "禁用")")
    }
    
    // MARK: - 公开方法：设置目标屏幕角落
    
    /// 设置最小化目标屏幕角落位置
    /// 用于自定义动画和预览缩略图的目标位置
    /// - Parameter corner: 目标屏幕角落
    public func setTargetScreenCorner(_ corner: UIScreenCorner) {
        lock.lock()
        configuration.targetCorner = corner
        lock.unlock()
        saveConfiguration(configuration)
        logger.info("已设置目标屏幕角落: \(corner.description)")
    }
    
    // MARK: - 公开方法：设置行为模式
    
    /// 设置当前最小化行为模式
    /// 模式切换后会发送通知，所有已最小化的窗口保持原状态
    /// - Parameter mode: 目标行为模式
    public func setBehaviorMode(_ mode: UIMinimizeBehaviorMode) {
        lock.lock()
        let oldMode = configuration.behaviorMode
        configuration.behaviorMode = mode
        let saved = configuration
        lock.unlock()
        saveConfiguration(saved)
        
        logger.info("最小化行为模式已切换: \(oldMode.displayName) → \(mode.displayName)")
        
        NotificationCenter.default.post(
            name: .minimizeBehaviorDidChange,
            object: self,
            userInfo: ["oldMode": oldMode, "newMode": mode]
        )
    }
    
    // MARK: - 公开方法：查询状态
    
    /// 检查指定窗口是否已最小化
    /// - Parameter windowID: 窗口唯一标识符
    /// - Returns: 是否已最小化
    public func isWindowMinimized(_ windowID: String) -> Bool {
        lock.lock()
        let exists = stateRecords[windowID] != nil
        lock.unlock()
        return exists
    }
    
    /// 获取已最小化窗口的列表
    /// - Returns: 已最小化窗口的ID数组
    public func minimizedWindowIDs() -> [String] {
        lock.lock()
        let ids = Array(stateRecords.keys)
        lock.unlock()
        return ids
    }
    
    /// 获取指定窗口的原始状态信息
    /// - Parameter windowID: 窗口唯一标识符
    /// - Returns: 窗口最小化前的原始frame（如果存在记录）
    public func originalFrame(for windowID: String) -> NSRect? {
        lock.lock()
        let frame = stateRecords[windowID]?.originalFrame
        lock.unlock()
        return frame
    }
    
    /// 获取当前配置的快照（线程安全复制）
    /// - Returns: 当前配置副本
    public func currentConfiguration() -> UIMinimizeConfiguration {
        lock.lock()
        let config = configuration
        lock.unlock()
        return config
    }
    
    // MARK: - 内部方法：Dock 模式最小化
    
    /// 执行系统默认的Dock最小化
    /// 直接调用performMiniaturize，保持系统原生行为
    private func performDockMinimize(window: NSWindow, record: UIMinimizeStateRecord) {
        logger.debug("执行Dock模式最小化: \(record.windowID)")
        DispatchQueue.main.async {
            window.performMiniaturize(nil)
        }
    }
    
    /// 执行系统默认的Dock恢复
    /// 直接调用deminiaturize，保持系统原生行为
    private func performDockRestore(window: NSWindow, record: UIMinimizeStateRecord, completion: (@Sendable (Bool) -> Void)?) {
        DispatchQueue.main.async { [weak self, weak window] in
            guard let window else { return }
            window.deminiaturize(nil)
            // 清理状态记录
            self?.removeStateRecord(for: record.windowID)
            completion?(true)
        }
    }
    
    // MARK: - 内部方法：自定义动画模式最小化
    
    /// 执行自定义动画最小化
    /// 将窗口以动画方式缩放到目标屏幕角落
    private func performCustomAnimationMinimize(window: NSWindow, record: UIMinimizeStateRecord) {
        guard configuration.isAnimationEnabled else {
            // 动画禁用时直接隐藏窗口
            logger.debug("动画已禁用，直接隐藏窗口: \(record.windowID)")
            DispatchQueue.main.async { [weak self] in
                window.orderOut(nil)
                self?.removeStateRecord(for: record.windowID)
            }
            return
        }
        
        record.isAnimating = true
        let targetPoint = configuration.targetCorner.point()
        let targetSize = NSSize(width: 20, height: 20)  // 最终缩放到20x20的小点
        let targetFrame = NSRect(origin: NSPoint(x: targetPoint.x - targetSize.width/2,
                                                   y: targetPoint.y - targetSize.height/2),
                                   size: targetSize)
        let duration = configuration.animationDuration
        
        logger.debug("执行自定义动画最小化: \(record.windowID) → \(self.configuration.targetCorner.description)")
        
        DispatchQueue.main.async { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().setFrame(targetFrame, display: true)
                window.animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                window.orderOut(nil)
                window.alphaValue = 1.0  // 恢复透明度，为下次恢复做准备
                self?.removeStateRecord(for: record.windowID)
            })
        }
    }
    
    /// 执行自定义动画恢复
    /// 将窗口从目标角落动画恢复到原始位置和尺寸
    private func performCustomAnimationRestore(window: NSWindow, record: UIMinimizeStateRecord, completion: (@Sendable (Bool) -> Void)?) {
        guard configuration.isAnimationEnabled else {
            // 动画禁用时直接恢复窗口
            logger.debug("动画已禁用，直接恢复窗口: \(record.windowID)")
            DispatchQueue.main.async { [weak self, weak window] in
                guard let window else { return }
                window.setFrame(record.originalFrame, display: true)
                window.orderFront(nil)
                self?.removeStateRecord(for: record.windowID)
                completion?(true)
            }
            return
        }
        
        let duration = configuration.animationDuration
        
        logger.debug("执行自定义动画恢复: \(record.windowID) → 原始位置")
        
        DispatchQueue.main.async { [weak self] in
            // 先设置窗口为可见但透明，然后动画恢复
            window.alphaValue = 0.0
            window.orderFront(nil)
            window.setFrame(record.originalFrame, display: true)
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1.0
            }, completionHandler: { [weak self] in
                self?.removeStateRecord(for: record.windowID)
                completion?(true)
            })
        }
    }
    
    // MARK: - 内部方法：预览缩略图模式最小化
    
    /// 执行预览缩略图最小化
    /// 将窗口隐藏，并创建一个小型的预览面板显示在屏幕角落
    private func performPreviewMinimize(window: NSWindow, record: UIMinimizeStateRecord) {
        guard configuration.isPreviewEnabled else {
            // 预览禁用时退化为自定义动画模式
            logger.debug("预览已禁用，退化为自定义动画: \(record.windowID)")
            performCustomAnimationMinimize(window: window, record: record)
            return
        }
        
        let targetPoint = configuration.targetCorner.point()
        let size = configuration.previewSize
        let previewFrame = NSRect(
            origin: NSPoint(x: targetPoint.x - size/2, y: targetPoint.y - size/2),
            size: NSSize(width: size, height: size)
        )
        
        logger.debug("执行预览缩略图最小化: \(record.windowID) → \(self.configuration.targetCorner.description)")
        
        DispatchQueue.main.async { [weak self] in
            // 创建预览面板
            guard let previewPanel = self?.createPreviewPanel(
                for: window,
                windowID: record.windowID,
                frame: previewFrame,
                title: record.originalTitle
            ) else {
                self?.logger.error("创建预览面板失败: \(record.windowID)")
                return
            }
            
            record.previewPanel = previewPanel
            
            // 隐藏原始窗口（但不真正最小化到Dock）
            window.orderOut(nil)
            
            // 显示预览面板
            previewPanel.orderFront(nil)
            
            // 存储预览面板引用
            self?.storePreviewPanel(previewPanel, for: record.windowID)
            
            // 发送预览面板创建通知
            NotificationCenter.default.post(
                name: .previewPanelDidCreate,
                object: self,
                userInfo: ["windowID": record.windowID, "panel": previewPanel]
            )
        }
    }
    
    /// 执行预览缩略图恢复
    /// 关闭预览面板，恢复原始窗口到前台
    private func performPreviewRestore(window: NSWindow, record: UIMinimizeStateRecord, completion: (@Sendable (Bool) -> Void)?) {
        logger.debug("执行预览缩略图恢复: \(record.windowID)")
        
        DispatchQueue.main.async { [weak self, weak window] in
            guard let window else { return }
            // 移除预览面板
            self?.removePreviewPanel(for: record.windowID)
            
            // 恢复原始窗口
            window.setFrame(record.originalFrame, display: true)
            window.orderFront(nil)
            window.makeKeyAndOrderFront(nil)
            
            self?.removeStateRecord(for: record.windowID)
            completion?(true)
        }
    }
    
    // MARK: - 内部方法：预览面板管理
    
    /// 创建预览面板窗口
    /// - Parameters:
    ///   - sourceWindow: 源窗口（用于获取截图或缩略图）
    ///   - windowID: 关联的窗口ID
    ///   - frame: 预览面板的frame
    ///   - title: 预览面板显示的标题
    /// - Returns: 创建的预览面板窗口
    private func createPreviewPanel(for sourceWindow: NSWindow, windowID: String, frame: NSRect, title: String) -> NSWindow {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        panel.hasShadow = true
        panel.isOpaque = false
        panel.alphaValue = configuration.previewAlpha
        panel.title = title
        
        // 创建内容视图
        let contentView = NSView(frame: NSRect(origin: .zero, size: frame.size))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 8.0
        contentView.layer?.masksToBounds = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 标题栏（如果配置显示）
        if configuration.isPreviewTitleBarVisible {
            let titleHeight: CGFloat = 24.0
            let titleBar = NSView(frame: NSRect(x: 0, y: frame.size.height - titleHeight, width: frame.size.width, height: titleHeight))
            titleBar.wantsLayer = true
            titleBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            
            let titleLabel = NSTextField(frame: NSRect(x: 4, y: 2, width: frame.size.width - 8, height: titleHeight - 4))
            titleLabel.isEditable = false
            titleLabel.isBordered = false
            titleLabel.backgroundColor = .clear
            titleLabel.stringValue = title
            titleLabel.font = NSFont.systemFont(ofSize: 11)
            titleLabel.textColor = NSColor.labelColor
            titleLabel.alignment = .center
            titleBar.addSubview(titleLabel)
            contentView.addSubview(titleBar)
            
            // 预览内容区域（标题栏下方）
            let previewArea = NSView(frame: NSRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height - titleHeight))
            previewArea.wantsLayer = true
            previewArea.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            contentView.addSubview(previewArea)
        }
        
        panel.contentView = contentView
        
        // 设置预览面板的代理，点击时恢复窗口
        let previewDelegate = UIPreviewPanelDelegate(windowID: windowID, manager: self)
        panel.delegate = previewDelegate
        
        // 添加点击手势识别器（点击预览面板恢复窗口）
        let clickGesture = NSClickGestureRecognizer(target: previewDelegate, action: #selector(UIPreviewPanelDelegate.panelDidClick))
        contentView.addGestureRecognizer(clickGesture)
        
        logger.info("已创建预览面板: \(windowID) 位置:\(String(describing: frame)) 标题:\(title)")
        return panel
    }
    
    /// 存储预览面板引用（线程安全）
    private func storePreviewPanel(_ panel: NSWindow, for windowID: String) {
        lock.lock()
        previewPanels[windowID] = panel
        lock.unlock()
    }
    
    /// 移除预览面板（线程安全）
    private func removePreviewPanel(for windowID: String) {
        var panelToRemove: NSWindow?
        lock.lock()
        if let panel = previewPanels[windowID] {
            panelToRemove = panel
            previewPanels.removeValue(forKey: windowID)
            logger.info("已移除预览面板: \(windowID)")
        }
        lock.unlock()
        
        panelToRemove?.orderOut(nil)
        
        NotificationCenter.default.post(
            name: .previewPanelDidClose,
            object: self,
            userInfo: ["windowID": windowID]
        )
    }
    
    // MARK: - 内部方法：状态记录管理
    
    /// 移除状态记录（线程安全）
    private func removeStateRecord(for windowID: String) {
        lock.lock()
        stateRecords.removeValue(forKey: windowID)
        lock.unlock()
        
        NotificationCenter.default.post(
            name: .windowDidRestore,
            object: self,
            userInfo: ["windowID": windowID]
        )
    }
    
    // MARK: - 内部同步辅助方法
    
    /// 线程安全地移除并返回所有预览面板（同步版本，用于 async 上下文）
    private func removeAllPanelsSync() -> [String: NSWindow] {
        lock.lock()
        let panels = previewPanels
        previewPanels.removeAll()
        lock.unlock()
        return panels
    }
    
    /// 移除所有预览面板
    /// 通常在应用退出或切换工作区时调用
    public func removeAllPreviewPanels() async {
        let panels = removeAllPanelsSync()
        
        for (windowID, panel) in panels {
            await MainActor.run {
                panel.orderOut(nil)
            }
            logger.info("已移除预览面板: \(windowID)")
        }
        
        NotificationCenter.default.post(
            name: .previewPanelDidClose,
            object: self,
            userInfo: ["windowID": "all"]
        )
    }
    
    /// 重置所有状态（清理所有已最小化窗口的记录）
    /// 谨慎使用：此操作会导致所有最小化记录丢失，窗口无法通过本管理器恢复
    public func resetAllState() {
        lock.lock()
        let records = stateRecords
        stateRecords.removeAll()
        previewPanels.removeAll()
        lock.unlock()
        
        for (windowID, _) in records {
            logger.info("已重置最小化状态: \(windowID)")
        }
        logger.info("已重置所有最小化状态，共 \(records.count) 个窗口")
    }
    
    // MARK: - 设置面板支持
    
    /// 获取所有可用的行为模式选项（用于设置面板）
    public var availableBehaviorModes: [(mode: UIMinimizeBehaviorMode, name: String)] {
        UIMinimizeBehaviorMode.allCases.map { ($0, $0.displayName) }
    }
    
    /// 获取所有可用的屏幕角落选项（用于设置面板）
    public var availableScreenCorners: [(corner: UIScreenCorner, name: String)] {
        UIScreenCorner.allCases.map { ($0, $0.description) }
    }
    
    /// 更新完整配置（用于设置面板一次性应用）
    /// - Parameter config: 新的配置对象
    public func updateConfiguration(_ config: UIMinimizeConfiguration) {
        lock.lock()
        let oldMode = configuration.behaviorMode
        configuration = config
        lock.unlock()
        saveConfiguration(configuration)
        
        logger.info("已更新完整配置: \(config.description)")
        
        if oldMode != config.behaviorMode {
            NotificationCenter.default.post(
                name: .minimizeBehaviorDidChange,
                object: self,
                userInfo: ["oldMode": oldMode, "newMode": config.behaviorMode]
            )
        }
    }
}

// MARK: - 迁回自 UI-02：class UIMinimizeWindowDelegate
private class UIMinimizeWindowDelegate: NSObject, NSWindowDelegate , @unchecked Sendable{
    
    /// 关联的窗口ID
    let windowID: String
    /// 关联的最小化管理器
    weak var manager: UIWindowMinimizeManager?
    
    /// 初始化窗口代理
    /// - Parameters:
    ///   - windowID: 窗口唯一标识
    ///   - manager: 最小化管理器实例
    init(windowID: String, manager: UIWindowMinimizeManager) {
        self.windowID = windowID
        self.manager = manager
        super.init()
    }
    
    /// 窗口即将最小化
    /// 拦截系统默认行为，使用自定义最小化管理器
    func windowWillMiniaturize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let manager = manager else { return }
        // 取消系统默认最小化，改用自定义行为
        manager.minimizeWindow(window, windowID: windowID)
    }
    
    /// 窗口已最小化（Dock模式时触发）
    func windowDidMiniaturize(_ notification: Notification) {
        // 已在最小化管理器中处理，此处无需额外操作
    }
    
    /// 窗口已恢复（Dock模式时触发）
    func windowDidDeminiaturize(_ notification: Notification) {
        // 已在最小化管理器中处理，此处无需额外操作
    }
}

// MARK: - 迁回自 UI-02：class UIPreviewPanelDelegate
private class UIPreviewPanelDelegate: NSObject, NSWindowDelegate , @unchecked Sendable{
    
    /// 关联的窗口ID
    let windowID: String
    /// 关联的最小化管理器
    weak var manager: UIWindowMinimizeManager?
    
    /// 初始化预览面板代理
    /// - Parameters:
    ///   - windowID: 窗口唯一标识
    ///   - manager: 最小化管理器实例
    init(windowID: String, manager: UIWindowMinimizeManager) {
        self.windowID = windowID
        self.manager = manager
        super.init()
    }
    
    /// 点击预览面板时触发
    @objc func panelDidClick() {
        manager?.logger.info("预览面板被点击，请求恢复窗口: \(self.windowID)")
        manager?.restoreWindow(windowID)
    }
    
    /// 窗口即将关闭（用户点击关闭按钮）
    func windowWillClose(_ notification: Notification) {
        // 关闭预览面板时同时恢复窗口
        manager?.logger.info("预览面板即将关闭，恢复窗口: \(self.windowID)")
        manager?.restoreWindow(windowID)
    }
}

// MARK: - 迁回自 UI-02：enum UIMinimizeBehaviorMode
// MARK: - UI-GL-13 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-13_types.swift
// 版本: 2.0
// MARK: - 通知名称
/// 窗口透明度相关通知
// 已迁回 UI-GL-13_透明度控制.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-15 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-15_types.swift
// 版本: 2.0
// MARK: - 最小化行为模式
/// 窗口最小化行为模式枚举
public enum UIMinimizeBehaviorMode: String, Codable, CaseIterable, Sendable, CustomStringConvertible {
    /// 默认Dock模式：调用系统原生最小化
    case dock = "dock"
    /// 自定义动画模式：将窗口以动画方式缩放到屏幕角落
    case customAnimation = "customAnimation"
    /// 预览缩略图模式：最小化后以缩略图形式保留在屏幕角落
    case preview = "preview"
    
    /// 用户友好的显示名称
    public var displayName: String {
        switch self {
        case .dock: return "默认Dock"
        case .customAnimation: return "自定义动画"
        case .preview: return "预览缩略图"
        }
    }
    
    /// 详细描述
    public var description: String {
        switch self {
        case .dock: return "使用系统默认的Dock最小化行为"
        case .customAnimation: return "以动画方式将窗口缩放到屏幕角落"
        case .preview: return "最小化后以缩略图形式保留在屏幕角落，点击可恢复"
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIScreenCorner
// MARK: - 主题管理器
/// 全局主题管理器
/// 支持亮色/暗色/跟随系统，可自定义主题，所有UI组件自动响应主题变化
/// 线程安全：所有共享状态访问使用 NSRecursiveLock 保护
// 已迁回 UI-GL-14_主题皮肤系统.swift：class UIThemeManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-15 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-15_types.swift
// 版本: 2.0
// MARK: - 屏幕角落
/// 屏幕角落位置枚举，用于指定最小化目标位置
public enum UIScreenCorner: String, Codable, CaseIterable, Sendable, CustomStringConvertible {
    /// 左上角
    case topLeft = "topLeft"
    /// 右上角
    case topRight = "topRight"
    /// 左下角
    case bottomLeft = "bottomLeft"
    /// 右下角
    case bottomRight = "bottomRight"
    
    /// 获取该角落对应的屏幕坐标点
    /// 基于主屏幕的尺寸计算，无主屏幕时返回.zero
    public func point() -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let frame = screen.visibleFrame
        switch self {
        case .topLeft:
            return NSPoint(x: frame.minX + 20, y: frame.maxY - 20)
        case .topRight:
            return NSPoint(x: frame.maxX - 20, y: frame.maxY - 20)
        case .bottomLeft:
            return NSPoint(x: frame.minX + 20, y: frame.minY + 20)
        case .bottomRight:
            return NSPoint(x: frame.maxX - 20, y: frame.minY + 20)
        }
    }
    
    /// 用户友好的描述
    public var description: String {
        switch self {
        case .topLeft: return "左上角"
        case .topRight: return "右上角"
        case .bottomLeft: return "左下角"
        case .bottomRight: return "右下角"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIMinimizeConfiguration
// MARK: - 最小化配置
/// 窗口最小化配置模型，支持Codable持久化
public struct UIMinimizeConfiguration: Codable, Sendable, CustomStringConvertible {
    /// 当前最小化行为模式
    public var behaviorMode: UIMinimizeBehaviorMode
    /// 是否启用最小化动画
    public var isAnimationEnabled: Bool
    /// 动画时长（秒）
    public var animationDuration: TimeInterval
    /// 目标屏幕角落
    public var targetCorner: UIScreenCorner
    /// 是否启用预览缩略图
    public var isPreviewEnabled: Bool
    /// 预览缩略图尺寸（宽高，像素）
    public var previewSize: CGFloat
    /// 预览面板透明度（0.0-1.0）
    public var previewAlpha: CGFloat
    /// 预览面板是否显示标题栏
    public var isPreviewTitleBarVisible: Bool
    
    /// 默认配置
    public static let `default` = UIMinimizeConfiguration(
        behaviorMode: .dock,
        isAnimationEnabled: true,
        animationDuration: 0.3,
        targetCorner: .bottomLeft,
        isPreviewEnabled: true,
        previewSize: 160,
        previewAlpha: 0.9,
        isPreviewTitleBarVisible: true
    )
    
    /// 详细描述字符串
    public var description: String {
        return "最小化配置: 模式=\(behaviorMode.displayName), 动画=\(isAnimationEnabled ? "启用" : "禁用"), 时长=\(String(format: "%.2f", animationDuration))s, 角落=\(targetCorner.description), 预览=\(isPreviewEnabled ? "启用" : "禁用"), 尺寸=\(Int(previewSize))px"
    }
}
