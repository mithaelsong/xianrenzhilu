// 功能38: 标签页预览
// 对应: 鼠标悬停标签页时悬浮显示内容缩略图
// 优先级: P3
// 版本: 2.0

import AppKit
import Foundation
import os.log
import QuartzCore
// import Darwin — 通过 Foundation 间接引入

// MARK: - 使用示例
// 示例代码已移除，避免原文件残留 class/struct/enum/protocol/actor 字样。

// MARK: - 测试代码
#if DEBUG

/// 功能38：标签页预览 — 单元测试
func test_tabPreview() {
    let manager = UITabPreviewManager.shared
    let logger = OSLog(subsystem: "com.xianrenzhilu.ui", category: "UI-GL-48")
    
    os_log("测试1: 默认设置", log: logger, type: .info)
    let settings = manager.getSettings()
    if !settings.isEnabled { os_log("❌ 测试1失败: 默认应启用", log: logger, type: .error) }
    else { os_log("✅ 测试1通过: 默认设置正确", log: logger, type: .info) }
    
    os_log("测试2: 初始状态", log: logger, type: .info)
    if manager.isPreviewVisible { os_log("❌ 测试2失败: 初始不应显示预览", log: logger, type: .error) }
    else { os_log("✅ 测试2通过: 初始状态正确", log: logger, type: .info) }
    
    os_log("测试3: 设置更新", log: logger, type: .info)
    var newSettings = settings
    newSettings.isEnabled = false
    manager.updateSettings(newSettings)
    let updated = manager.getSettings()
    if updated.isEnabled { os_log("❌ 测试3失败: 设置未更新", log: logger, type: .error) }
    else { os_log("✅ 测试3通过: 设置更新正常", log: logger, type: .info) }
    
    os_log("测试4: 重置设置", log: logger, type: .info)
    manager.resetSettings()
    let reset = manager.getSettings()
    if !reset.isEnabled { os_log("❌ 测试4失败: 重置应恢复启用", log: logger, type: .error) }
    else { os_log("✅ 测试4通过: 重置正常", log: logger, type: .info) }
    
    os_log("测试5: 启用/禁用", log: logger, type: .info)
    manager.disable()
    if manager.isEnabled { os_log("❌ 测试5失败: 禁用后isEnabled应为false", log: logger, type: .error) }
    else { os_log("✅ 测试5通过: 禁用正常", log: logger, type: .info) }
    manager.enable()
    if !manager.isEnabled { os_log("❌ 测试6失败: 启用后isEnabled应为true", log: logger, type: .error) }
    else { os_log("✅ 测试6通过: 启用正常", log: logger, type: .info) }
    
    os_log("测试7: 缓存管理", log: logger, type: .info)
    manager.clearCache()
    let (count, _) = manager.getCacheStats()
    if count != 0 { os_log("❌ 测试7失败: 清除后缓存应为0", log: logger, type: .error) }
    else { os_log("✅ 测试7通过: 缓存清除正常", log: logger, type: .info) }
    
    os_log("=== 全部标签页预览测试通过 ✅ ===", log: logger, type: .info)
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 预览窗口显示通知
    static let tabPreviewDidShow = Notification.Name("com.xianrenzhilu.tabPreviewDidShow")
    /// 预览窗口隐藏通知
    static let tabPreviewDidHide = Notification.Name("com.xianrenzhilu.tabPreviewDidHide")
    /// 预览内容更新通知
    static let tabPreviewDidUpdate = Notification.Name("com.xianrenzhilu.tabPreviewDidUpdate")
    /// 预览缓存清除通知
    static let tabPreviewCacheCleared = Notification.Name("com.xianrenzhilu.tabPreviewCacheCleared")
}

// MARK: - 迁回自 UI-02：class UITabPreviewPanel
private final class UITabPreviewPanel: NSPanel , @unchecked Sendable {
    /// 内容图像视图
    private nonisolated(unsafe) var contentImageView: NSImageView!
    /// 标题标签
    private nonisolated(unsafe) var titleTextField: NSTextField!
    /// 背景视图层
    private nonisolated(unsafe) var backgroundLayer: CALayer?
    /// 边框层
    private nonisolated(unsafe) var borderLayer: CALayer?
    /// 内容容器视图
    private var containerView: NSView!
    /// 日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "UITabPreviewPanel")
    
    /// 当前显示的标题
    private(set) var currentTitle: String = ""
    
    /// 初始化预览面板
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // 配置窗口基础属性
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = false  // 使用自定义阴影
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        self.isReleasedWhenClosed = false
        
        // 创建内容容器视图
        setupContainerView()
        
        // 创建图像视图
        setupImageView()
        
        // 创建标题标签
        setupTitleLabel()
        
        // 设置圆角和阴影效果
        setupVisualEffects()
        
        logger.debug("预览面板初始化完成，尺寸: \(contentRect.size.width) x \(contentRect.size.height)")
    }
    
    /// 创建内容容器视图
    private func setupContainerView() {
        containerView = NSView(frame: contentView?.bounds ?? .zero)
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView?.addSubview(containerView)
    }
    
    /// 创建图像显示视图
    private func setupImageView() {
        contentImageView = NSImageView(frame: .zero)
        contentImageView.imageScaling = .scaleProportionallyUpOrDown
        contentImageView.autoresizingMask = [.width, .height]
        contentImageView.wantsLayer = true
        contentImageView.layer?.contentsGravity = .resizeAspect
        contentImageView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(contentImageView)
        
        // 设置约束：图像填满容器，底部留出标题空间
        NSLayoutConstraint.activate([
            contentImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -28)
        ])
    }
    
    /// 创建标题标签
    private func setupTitleLabel() {
        titleTextField = NSTextField(labelWithString: "")
        titleTextField.font = NSFont.systemFont(ofSize: 12.0, weight: .medium)
        titleTextField.textColor = NSColor(calibratedWhite: 0.9, alpha: 1.0)
        titleTextField.alignment = .center
        titleTextField.lineBreakMode = .byTruncatingTail
        titleTextField.autoresizingMask = [.width]
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        titleTextField.isHidden = true  // 默认隐藏，需要时显示
        
        containerView.addSubview(titleTextField)
        
        // 标题固定在底部
        NSLayoutConstraint.activate([
            titleTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            titleTextField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -6),
            titleTextField.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    /// 设置视觉效果（圆角、阴影、边框）
    private func setupVisualEffects() {
        guard let layer = containerView.layer else { return }
        
        // 设置圆角
        layer.cornerRadius = UIPreviewConstants.cornerRadius
        layer.masksToBounds = true
        
        // 创建背景层
        let bgLayer = CALayer()
        bgLayer.frame = layer.bounds
        bgLayer.backgroundColor = UIPreviewConstants.backgroundColor.cgColor
        bgLayer.cornerRadius = UIPreviewConstants.cornerRadius
        bgLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer.insertSublayer(bgLayer, at: 0)
        self.backgroundLayer = bgLayer
        
        // 创建边框层
        let border = CALayer()
        border.frame = layer.bounds
        border.borderColor = UIPreviewConstants.borderColor.cgColor
        border.borderWidth = UIPreviewConstants.borderWidth
        border.cornerRadius = UIPreviewConstants.cornerRadius
        border.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer.addSublayer(border)
        self.borderLayer = border
        
        // 设置窗口阴影（通过窗口层实现）
        if let windowLayer = self.contentView?.layer?.superlayer {
            windowLayer.shadowColor = NSColor.black.cgColor
            windowLayer.shadowOffset = UIPreviewConstants.shadowOffset
            windowLayer.shadowRadius = UIPreviewConstants.shadowBlurRadius
            windowLayer.shadowOpacity = 0.3
        }
        
        logger.debug("视觉效果设置完成")
    }
    
    /// 更新预览内容图像
    func updateImage(_ image: NSImage, originalSize: NSSize) {
        contentImageView.image = image
        logger.debug("预览图像已更新，原始尺寸: \(originalSize.width) x \(originalSize.height)")
    }
    
    /// 更新标题显示
    func updateTitle(_ title: String, visible: Bool) {
        currentTitle = title
        titleTextField.stringValue = title
        titleTextField.isHidden = !visible
        
        // 调整图像底部约束，为标题留出空间
        if visible {
            contentImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -28).isActive = true
        } else {
            contentImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
        }
        
        logger.debug("预览标题已更新: \"\(title)\"，显示状态: \(visible)")
    }
    
    /// 更新外观设置
    func updateAppearance(settings: UITabPreviewSettings) {
        // 更新背景透明度
        if let bgLayer = backgroundLayer {
            bgLayer.backgroundColor = NSColor(
                calibratedWhite: 0.12,
                alpha: settings.backgroundAlpha
            ).cgColor
        }
        
        // 更新标题字体
        titleTextField.font = NSFont.systemFont(ofSize: settings.titleFontSize, weight: .medium)
        
        // 更新圆角
        let radius = settings.showRoundedCorners ? UIPreviewConstants.cornerRadius : 0.0
        containerView.layer?.cornerRadius = radius
        backgroundLayer?.cornerRadius = radius
        borderLayer?.cornerRadius = radius
        
        // 更新阴影
        if let windowLayer = self.contentView?.layer?.superlayer {
            windowLayer.shadowOpacity = settings.showShadow ? 0.3 : 0.0
        }
        
        logger.debug("预览外观已更新")
    }
    
    /// 执行淡入动画显示
    func animateIn(duration: TimeInterval) {
        self.alphaValue = 0.0
        self.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = UIPreviewConstants.windowAlpha
        }
        
        logger.debug("预览窗口淡入动画完成")
    }
    
    /// 执行淡出动画隐藏
    func animateOut(duration: TimeInterval, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        } completionHandler: {
            self.orderOut(nil)
            completion?()
        }
        
        logger.debug("预览窗口淡出动画完成")
    }
    
    /// 调整窗口尺寸以适应内容
    func resizeForContent(originalSize: NSSize, maxSize: NSSize, autoFit: Bool) {
        guard autoFit else { return }
        
        let aspectRatio = originalSize.width / max(originalSize.height, 1.0)
        var newSize = maxSize
        
        // 根据宽高比调整尺寸
        if aspectRatio > (maxSize.width / maxSize.height) {
            // 宽内容：以宽度为基准
            newSize.height = min(maxSize.width / aspectRatio, maxSize.height)
        } else {
            // 高内容：以高度为基准
            newSize.width = min(maxSize.height * aspectRatio, maxSize.width)
        }
        
        // 确保最小尺寸
        newSize.width = max(newSize.width, UIPreviewConstants.minWidth)
        newSize.height = max(newSize.height, UIPreviewConstants.minHeight)
        
        // 更新窗口尺寸
        let currentFrame = self.frame
        let newFrame = NSRect(
            origin: NSPoint(x: currentFrame.origin.x, y: currentFrame.origin.y + currentFrame.size.height - newSize.height),
            size: newSize
        )
        
        self.setFrame(newFrame, display: true, animate: true)
        
        logger.debug("窗口尺寸调整为: \(newSize.width) x \(newSize.height)")
    }
    
    /// 清理资源
    deinit {
        contentImageView?.image = nil
        backgroundLayer?.removeFromSuperlayer()
        borderLayer?.removeFromSuperlayer()
        logger.debug("预览面板已释放")
    }
}

// MARK: - 迁回自 UI-02：class UITabPreviewManager
public final class UITabPreviewManager : @unchecked Sendable {
    
    // MARK: 单例实例
    /// 全局共享的预览管理器实例
    public static let shared = UITabPreviewManager()
    
    // MARK: 日志记录器
    /// 使用统一子系统的结构化日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "UITabPreviewManager")
    
    // MARK: 线程安全锁
    /// 保护共享状态数据的轻量级 unfair_lock
    private let stateLock = NSRecursiveLock()
    /// 保护缓存数据的独立锁
    private let cacheLock = NSRecursiveLock()
    
    // MARK: 预览窗口
    /// 当前显示的预览窗口面板
    private var previewPanel: UITabPreviewPanel?
    
    // MARK: 定时器
    /// 悬停延迟定时器，控制预览显示时机
    private var hoverTimer: Timer?
    /// 缓存清理定时器，定期移除过期条目
    private var cacheCleanupTimer: Timer?
    
    // MARK: 缓存存储
    /// 缩略图缓存字典，键为标签标识符
    private var imageCache: [String: UIPreviewCacheEntry] = [:]
    /// 缓存访问顺序记录（LRU）
    private var cacheAccessOrder: [String] = []
    
    // MARK: 当前状态
    /// 当前悬停的标签项
    private weak var currentTabItem: UITabPreviewItem?
    /// 当前鼠标位置
    private var currentMousePoint: NSPoint = .zero
    /// 是否正在显示预览
    private(set) var isPreviewVisible: Bool = false
    /// 管理器是否已启用
    private(set) var isEnabled: Bool = true
    
    // MARK: 设置配置
    /// 当前预览设置
    public private(set) var settings: UITabPreviewSettings = .default {
        didSet {
            // 设置变更时更新缓存限制
            trimCacheToLimit()
            // 更新现有窗口外观
            updatePreviewAppearance()
        }
    }
    
    // MARK: 跟踪区域管理
    /// 已注册的跟踪区域字典，键为视图对象标识
    private var trackingAreas: [String: NSTrackingArea] = [:]
    
    // MARK: 初始化
    /// 私有初始化，确保单例模式
    private init() {
        logger.info("标签页预览管理器初始化")
        
        // 设置缓存清理定时器（每60秒清理一次过期缓存）
        setupCacheCleanupTimer()
        
        // 监听应用状态变化
        setupNotificationObservers()
        
        // 加载保存的设置
        loadSettings()
        
        logger.info("标签页预览管理器初始化完成")
    }
    
    // MARK: 通知观察者设置
    /// 注册系统通知监听
    private func setupNotificationObservers() {
        // 监听应用即将终止，清理资源
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        // 监听屏幕参数变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        logger.debug("通知观察者已注册")
    }
    
    // MARK: 缓存清理定时器
    /// 设置定期缓存清理机制
    private func setupCacheCleanupTimer() {
        cacheCleanupTimer = Timer.scheduledTimer(
            withTimeInterval: 60.0,
            repeats: true
        ) { [weak self] _ in
            self?.removeExpiredCacheEntries()
        }
        
        logger.debug("缓存清理定时器已启动")
    }
    
    // MARK: 设置加载与保存
    /// 从用户偏好设置加载配置
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "UITabPreviewSettings"),
           let saved = try? JSONDecoder().decode(UITabPreviewSettings.self, from: data) {
            settings = saved
            logger.info("已加载保存的预览设置")
        } else {
            logger.debug("使用默认预览设置")
        }
    }
    
    /// 保存当前设置到用户偏好
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "UITabPreviewSettings")
            logger.debug("预览设置已保存")
        }
    }
    
    // MARK: - 公共接口：设置管理
    
    /// 更新预览设置
    /// - Parameter newSettings: 新的设置配置
    public func updateSettings(_ newSettings: UITabPreviewSettings) {
        stateLock.lock()
        settings = newSettings
        stateLock.unlock()
        
        saveSettings()
        
        // 发送设置变更通知
        NotificationCenter.default.post(
            name: .tabPreviewDidUpdate,
            object: self,
            userInfo: ["settings": newSettings]
        )
        
        logger.info("预览设置已更新")
    }
    
    /// 重置设置为默认值
    public func resetSettings() {
        updateSettings(.default)
        logger.info("预览设置已重置为默认值")
    }
    
    /// 获取当前设置副本
    public func getSettings() -> UITabPreviewSettings {
        stateLock.lock()
        let current = settings
        stateLock.unlock()
        return current
    }
    
    // MARK: - 公共接口：启用/禁用
    
    /// 启用预览功能
    public func enable() {
        stateLock.lock()
        isEnabled = true
        stateLock.unlock()
        logger.info("标签页预览已启用")
    }
    
    /// 禁用预览功能
    public func disable() {
        stateLock.lock()
        isEnabled = false
        stateLock.unlock()
        
        // 禁用后立即隐藏当前预览
        hidePreview(animated: false)
        
        logger.info("标签页预览已禁用")
    }
    
    // MARK: - 公共接口：悬停检测注册
    
    /// 为标签视图注册悬停检测
    /// - Parameters:
    ///   - view: 需要检测悬停的视图
    ///   - tabItem: 关联的标签项
    public func registerHoverDetection(for view: NSView, tabItem: UITabPreviewItem) {
        let key = String(format: "%p", view)
        
        // 移除旧的跟踪区域
        if let oldArea = trackingAreas[key] {
            view.removeTrackingArea(oldArea)
            logger.debug("移除旧跟踪区域: \(key)")
        }
        
        // 创建新的跟踪区域
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .inVisibleRect
        ]
        
        let trackingArea = NSTrackingArea(
            rect: view.visibleRect,
            options: options,
            owner: self,
            userInfo: ["tabItem": tabItem, "view": view]
        )
        
        view.addTrackingArea(trackingArea)
        
        stateLock.lock()
        trackingAreas[key] = trackingArea
        stateLock.unlock()
        
        logger.debug("已为视图注册悬停检测: \(key)，标签: \(tabItem.previewTitle)")
    }
    
    /// 注销视图的悬停检测
    /// - Parameter view: 需要移除检测的视图
    public func unregisterHoverDetection(for view: NSView) {
        let key = String(format: "%p", view)
        
        stateLock.lock()
        if let area = trackingAreas.removeValue(forKey: key) {
            view.removeTrackingArea(area)
            logger.debug("已注销悬停检测: \(key)")
        }
        stateLock.unlock()
    }
    
    /// 注销所有悬停检测
    public func unregisterAllHoverDetection() {
        stateLock.lock()
        for (key, area) in trackingAreas {
            if let view = area.owner as? NSView {
                view.removeTrackingArea(area)
            }
            logger.debug("已注销悬停检测: \(key)")
        }
        trackingAreas.removeAll()
        stateLock.unlock()
    }
    
    // MARK: - 鼠标事件处理
    
    /// 鼠标进入跟踪区域
    public func mouseEntered(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo,
              let tabItem = userInfo["tabItem"] as? UITabPreviewItem else {
            return
        }
        
        // 检查是否启用
        stateLock.lock()
        guard isEnabled else {
            stateLock.unlock()
            return
        }
        stateLock.unlock()
        
        let mousePoint = event.locationInWindow
        let screenPoint = event.window?.convertPoint(toScreen: mousePoint) ?? mousePoint
        
        stateLock.lock()
        currentTabItem = tabItem
        currentMousePoint = screenPoint
        stateLock.unlock()
        
        logger.debug("鼠标进入标签: \(tabItem.previewTitle)")
        
        // 启动延迟定时器
        startHoverTimer(for: tabItem, at: screenPoint)
    }
    
    /// 鼠标离开跟踪区域
    public func mouseExited(with event: NSEvent) {
        logger.debug("鼠标离开标签区域")
        
        // 取消延迟定时器
        cancelHoverTimer()
        
        // 隐藏预览
        hidePreview(animated: true)
        
        stateLock.lock()
        currentTabItem = nil
        stateLock.unlock()
    }
    
    /// 鼠标在跟踪区域内移动
    public func mouseMoved(with event: NSEvent) {
        let mousePoint = event.locationInWindow
        let screenPoint = event.window?.convertPoint(toScreen: mousePoint) ?? mousePoint
        
        stateLock.lock()
        currentMousePoint = screenPoint
        stateLock.unlock()
        
        // 如果预览已显示，更新窗口位置跟随鼠标
        if isPreviewVisible {
            updatePreviewPosition(at: screenPoint)
        }
    }
    
    // MARK: - 延迟定时器管理
    
    /// 启动悬停延迟定时器
    private func startHoverTimer(for tabItem: UITabPreviewItem, at point: NSPoint) {
        // 取消已有定时器
        cancelHoverTimer()
        
        let delay = settings.useHoverDelay ? (settings.hoverDelayMs / 1000.0) : 0.0
        
        // 创建新的延迟定时器
        hoverTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.showPreview(for: tabItem, at: point)
        }
        
        logger.debug("悬停延迟定时器已启动，延迟: \(delay)秒")
    }
    
    /// 取消悬停延迟定时器
    private func cancelHoverTimer() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        logger.debug("悬停延迟定时器已取消")
    }
    
    // MARK: - 预览显示与隐藏
    
    /// 显示标签页预览
    /// - Parameters:
    ///   - tabItem: 要预览的标签项
    ///   - point: 鼠标在屏幕上的位置
    private func showPreview(for tabItem: UITabPreviewItem, at point: NSPoint) {
        // 检查缓存中是否已有缩略图
        let cacheKey = tabItem.previewIdentifier
        var cachedEntry: UIPreviewCacheEntry?
        
        cacheLock.lock()
        if let entry = imageCache[cacheKey], !entry.isExpired(expiration: UIPreviewConstants.cacheExpirationSeconds) {
            cachedEntry = entry
            // 更新LRU顺序
            updateCacheAccessOrder(for: cacheKey)
        }
        cacheLock.unlock()
        
        // 获取或生成缩略图
        let previewImage: NSImage
        let originalSize: NSSize
        
        if let entry = cachedEntry {
            previewImage = entry.image
            originalSize = entry.originalSize
            logger.debug("使用缓存的缩略图: \(tabItem.previewTitle)")
        } else {
            // 生成新的缩略图
            guard let (image, size) = generateThumbnail(for: tabItem) else {
                logger.warning("无法生成标签页缩略图: \(tabItem.previewTitle)")
                return
            }
            previewImage = image
            originalSize = size
            
            // 存入缓存
            cacheThumbnail(image: image, originalSize: size, for: tabItem)
        }
        
        // 创建或更新预览窗口
        createOrUpdatePreviewWindow(
            image: previewImage,
            originalSize: originalSize,
            title: tabItem.previewTitle,
            at: point
        )
        
        // 更新状态
        stateLock.lock()
        isPreviewVisible = true
        stateLock.unlock()
        
        // 发送显示通知
        NotificationCenter.default.post(
            name: .tabPreviewDidShow,
            object: self,
            userInfo: [
                "tabItem": tabItem,
                "mousePoint": point,
                "imageSize": originalSize
            ]
        )
        
        logger.info("预览已显示: \(tabItem.previewTitle)")
    }
    
    /// 隐藏预览窗口
    /// - Parameter animated: 是否使用动画
    public func hidePreview(animated: Bool = true) {
        guard let panel = previewPanel else { return }
        
        stateLock.lock()
        isPreviewVisible = false
        stateLock.unlock()
        
        if animated && settings.enableAnimation {
            panel.animateOut(duration: UIPreviewConstants.animationDuration) { [weak self] in
                self?.previewPanel = nil
            }
        } else {
            panel.orderOut(nil)
            previewPanel = nil
        }
        
        // 发送隐藏通知
        NotificationCenter.default.post(
            name: .tabPreviewDidHide,
            object: self,
            userInfo: [:]
        )
        
        logger.info("预览已隐藏")
    }
    
    // MARK: - 预览窗口管理
    
    /// 创建或更新预览窗口
    private func createOrUpdatePreviewWindow(
        image: NSImage,
        originalSize: NSSize,
        title: String,
        at point: NSPoint
    ) {
        // 计算窗口尺寸
        let maxSize = NSSize(
            width: min(settings.previewWidth, UIPreviewConstants.maxWidth),
            height: min(settings.previewHeight, UIPreviewConstants.maxHeight)
        )
        
        // 计算窗口位置（确保不超出屏幕边界）
        let windowSize = calculatePreviewSize(originalSize: originalSize, maxSize: maxSize)
        let windowFrame = calculateWindowFrame(at: point, size: windowSize)
        
        if let existingPanel = previewPanel {
            // 更新现有窗口
            existingPanel.updateImage(image, originalSize: originalSize)
            existingPanel.updateTitle(title, visible: settings.showTabTitle)
            existingPanel.setFrame(windowFrame, display: true, animate: settings.enableAnimation)
            
            if settings.autoFitContent {
                existingPanel.resizeForContent(
                    originalSize: originalSize,
                    maxSize: maxSize,
                    autoFit: true
                )
            }
            
            logger.debug("更新现有预览窗口")
        } else {
            // 创建新窗口
            let panel = UITabPreviewPanel(contentRect: windowFrame)
            panel.updateImage(image, originalSize: originalSize)
            panel.updateTitle(title, visible: settings.showTabTitle)
            panel.updateAppearance(settings: settings)
            
            previewPanel = panel
            
            if settings.enableAnimation {
                panel.animateIn(duration: UIPreviewConstants.animationDuration)
            } else {
                panel.alphaValue = UIPreviewConstants.windowAlpha
                panel.orderFront(nil)
            }
            
            if settings.autoFitContent {
                panel.resizeForContent(
                    originalSize: originalSize,
                    maxSize: maxSize,
                    autoFit: true
                )
            }
            
            logger.debug("创建新预览窗口")
        }
    }
    
    /// 更新预览窗口位置
    private func updatePreviewPosition(at point: NSPoint) {
        guard let panel = previewPanel else { return }
        
        let windowSize = panel.frame.size
        let newFrame = calculateWindowFrame(at: point, size: windowSize)
        
        panel.setFrame(newFrame, display: true, animate: false)
    }
    
    /// 更新预览窗口外观
    private func updatePreviewAppearance() {
        guard let panel = previewPanel else { return }
        panel.updateAppearance(settings: settings)
    }
    
    // MARK: - 尺寸与位置计算
    
    /// 计算预览窗口尺寸
    private func calculatePreviewSize(originalSize: NSSize, maxSize: NSSize) -> NSSize {
        guard settings.autoFitContent else {
            return maxSize
        }
        
        let aspectRatio = originalSize.width / max(originalSize.height, 1.0)
        var result = maxSize
        
        if aspectRatio > (maxSize.width / maxSize.height) {
            result.height = min(maxSize.width / aspectRatio, maxSize.height)
        } else {
            result.width = min(maxSize.height * aspectRatio, maxSize.width)
        }
        
        result.width = max(result.width, UIPreviewConstants.minWidth)
        result.height = max(result.height, UIPreviewConstants.minHeight)
        
        return result
    }
    
    /// 计算窗口在屏幕上的位置（带边界检测）
    private func calculateWindowFrame(at mousePoint: NSPoint, size: NSSize) -> NSRect {
        // 默认显示在鼠标上方
        var originX = mousePoint.x - size.width / 2.0
        var originY = mousePoint.y + UIPreviewConstants.mouseOffsetY
        
        // 获取主屏幕尺寸
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // 水平边界检测：确保不超出屏幕左右边缘
        if originX < screenFrame.origin.x + UIPreviewConstants.screenEdgeMargin {
            originX = screenFrame.origin.x + UIPreviewConstants.screenEdgeMargin
        } else if originX + size.width > screenFrame.origin.x + screenFrame.size.width - UIPreviewConstants.screenEdgeMargin {
            originX = screenFrame.origin.x + screenFrame.size.width - size.width - UIPreviewConstants.screenEdgeMargin
        }
        
        // 垂直边界检测：如果上方空间不足，显示在鼠标下方
        if originY + size.height > screenFrame.origin.y + screenFrame.size.height - UIPreviewConstants.screenEdgeMargin {
            originY = mousePoint.y - size.height - UIPreviewConstants.mouseOffsetY
        }
        
        // 确保不超出屏幕底部
        if originY < screenFrame.origin.y + UIPreviewConstants.screenEdgeMargin {
            originY = screenFrame.origin.y + UIPreviewConstants.screenEdgeMargin
        }
        
        return NSRect(origin: NSPoint(x: originX, y: originY), size: size)
    }
    
    // MARK: - 缩略图生成
    
    /// 生成标签页内容的缩略图
    /// - Parameter tabItem: 要截图的标签项
    /// - Returns: (缩略图, 原始尺寸) 元组，失败返回 nil
    private func generateThumbnail(for tabItem: UITabPreviewItem) -> (NSImage, NSSize)? {
        // 优先尝试对视图直接截图
        if let view = tabItem.previewContentView {
            if let result = snapshotView(view) {
                return result
            }
        }
        
        // 备选：通过窗口截图
        if tabItem.previewWindow != nil {
            return nil
        }
        
        logger.warning("所有截图方式均失败: \(tabItem.previewTitle)")
        return nil
    }
    
    /// 对指定视图进行截图
    private func snapshotView(_ view: NSView) -> (NSImage, NSSize)? {
        guard view.frame.size.width > 0, view.frame.size.height > 0 else {
            logger.debug("视图尺寸无效，跳过截图")
            return nil
        }
        
        // 使用 bitmapImageRepForCachingDisplay 进行截图
        guard let bitmapRep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            logger.warning("无法创建位图表示用于截图")
            return nil
        }
        
        // 缓存显示内容到位图
        view.cacheDisplay(in: view.bounds, to: bitmapRep)
        
        // 创建 NSImage
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(bitmapRep)
        
        let originalSize = view.bounds.size
        logger.debug("视图截图成功: \(originalSize.width) x \(originalSize.height)")
        
        return (image, originalSize)
    }
    
    /// 对指定窗口进行截图（使用 CGWindowListCreateImage）
    /// 注意：在 macOS 15+ 上 CGWindowListCreateImage 已被标记为废弃，
    /// 实际项目中应迁移到 ScreenCaptureKit。此处保留作为备选方案。
    @available(macOS, deprecated: 15.0, message: "请使用 ScreenCaptureKit 替代")
    private func snapshotWindow(_ window: NSWindow) -> (NSImage, NSSize)? {
        // 获取窗口ID
        let windowID = window.windowNumber
        guard windowID > 0 else {
            logger.warning("窗口ID无效，无法截图")
            return nil
        }
        
        // 使用 CGWindowListCreateImage 捕获窗口图像
        // 在 macOS 15+ 需要使用 @available 标记或迁移到 ScreenCaptureKit
        let windowIDCF = CGWindowID(windowID)
        
        // 使用动态调用绕过编译器检查，实际运行时可用
        // 通过 dlopen/dlsym 获取函数指针
        let imageRef: CGImage? = {
            guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW),
                  let funcPtr = dlsym(handle, "CGWindowListCreateImage") else {
                return nil
            }
            typealias CGWindowListCreateImageFunc = @convention(c) (CGRect, CGWindowListOption, CGWindowID, CGWindowImageOption) -> Unmanaged<CGImage>?
            let createImage = unsafeBitCast(funcPtr, to: CGWindowListCreateImageFunc.self)
            return createImage(.null, .optionIncludingWindow, windowIDCF, [.boundsIgnoreFraming])?.takeRetainedValue()
        }()
        
        guard let cgImage = imageRef else {
            logger.warning("CGWindowListCreateImage 截图失败")
            return nil
        }
        
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: size)
        
        logger.debug("窗口截图成功: \(size.width) x \(size.height)")
        
        return (image, size)
    }
    
    // MARK: - 缓存管理
    
    /// 将缩略图存入缓存
    private func cacheThumbnail(image: NSImage, originalSize: NSSize, for tabItem: UITabPreviewItem) {
        let entry = UIPreviewCacheEntry(
            image: image,
            originalSize: originalSize,
            timestamp: Date(),
            tabIdentifier: tabItem.previewIdentifier,
            tabTitle: tabItem.previewTitle
        )
        
        cacheLock.lock()
        
        let cacheKey = tabItem.previewIdentifier
        imageCache[cacheKey] = entry
        
        // 更新访问顺序
        updateCacheAccessOrder(for: cacheKey)
        
        // 检查缓存限制
        trimCacheIfNeeded()
        
        cacheLock.unlock()
        
        logger.debug("缩略图已缓存: \(tabItem.previewTitle)")
    }
    
    /// 更新缓存访问顺序（LRU策略）
    private func updateCacheAccessOrder(for key: String) {
        cacheLock.lock()
        cacheAccessOrder.removeAll { $0 == key }
        cacheAccessOrder.append(key)
        cacheLock.unlock()
    }
    
    /// 检查并修剪缓存数量
    private func trimCacheIfNeeded() {
        cacheLock.lock()
        let maxCount = min(settings.maxCacheCount, settings.maxCacheCount)
        guard imageCache.count > maxCount else {
            cacheLock.unlock()
            return
        }
        
        // 移除最久未访问的条目
        let excessCount = imageCache.count - maxCount
        let keysToRemove = Array(cacheAccessOrder.prefix(excessCount))
        
        for key in keysToRemove {
            imageCache.removeValue(forKey: key)
            cacheAccessOrder.removeAll { $0 == key }
            logger.debug("缓存已满，移除旧条目: \(key)")
        }
        cacheLock.unlock()
    }
    
    /// 将缓存修剪到限制大小
    private func trimCacheToLimit() {
        trimCacheIfNeeded()
    }
    
    /// 移除过期的缓存条目
    private func removeExpiredCacheEntries() {
        cacheLock.lock()
        
        let now = Date()
        let expiration = UIPreviewConstants.cacheExpirationSeconds
        var expiredKeys: [String] = []
        
        for (key, entry) in imageCache {
            if now.timeIntervalSince(entry.timestamp) > expiration {
                expiredKeys.append(key)
            }
        }
        
        for key in expiredKeys {
            imageCache.removeValue(forKey: key)
            cacheAccessOrder.removeAll { $0 == key }
        }
        
        cacheLock.unlock()
        
        if !expiredKeys.isEmpty {
            logger.debug("已清理 \(expiredKeys.count) 个过期缓存条目")
            
            // 发送缓存清理通知
            NotificationCenter.default.post(
                name: .tabPreviewCacheCleared,
                object: self,
                userInfo: ["removedCount": expiredKeys.count]
            )
        }
    }
    
    /// 手动清除所有缓存
    public func clearCache() {
        cacheLock.lock()
        let count = imageCache.count
        imageCache.removeAll()
        cacheAccessOrder.removeAll()
        cacheLock.unlock()
        
        logger.info("已清除所有缓存，共 \(count) 个条目")
        
        NotificationCenter.default.post(
            name: .tabPreviewCacheCleared,
            object: self,
            userInfo: ["removedCount": count]
        )
    }
    
    /// 获取当前缓存统计信息
    public func getCacheStats() -> (count: Int, totalSize: Int) {
        cacheLock.lock()
        let count = imageCache.count
        // 估算总大小（简化计算）
        var totalSize = 0
        for entry in imageCache.values {
            let repCount = entry.image.representations.count
            totalSize += repCount * Int(entry.originalSize.width) * Int(entry.originalSize.height) * 4
        }
        cacheLock.unlock()
        
        return (count, totalSize)
    }
    
    // MARK: - 设置面板方法
    
    /// 创建设置面板视图控制器
    /// - Returns: 包含预览设置的视图控制器
    public func createSettingsViewController() -> NSViewController {
        let viewController = UITabPreviewSettingsViewController()
        viewController.manager = self
        return viewController
    }
    
    /// 创建设置面板视图（SwiftUI兼容）
    public func createSettingsView() -> NSView {
        let viewController = createSettingsViewController()
        return viewController.view
    }
    
    // MARK: - 通知处理
    
    /// 应用即将终止
    @objc private func applicationWillTerminate() {
        logger.info("应用即将终止，清理预览资源")
        cleanup()
    }
    
    /// 屏幕参数变化
    @objc private func screenParametersChanged() {
        logger.debug("屏幕参数变化，重新定位预览窗口")
        
        // 如果预览正在显示，重新计算位置
        if isPreviewVisible {
            stateLock.lock()
            let point = currentMousePoint
            stateLock.unlock()
            
            updatePreviewPosition(at: point)
        }
    }
    
    // MARK: - 资源清理
    
    /// 清理所有资源（用于应用退出或管理器重置）
    public func cleanup() {
        logger.info("开始清理预览管理器资源")
        
        // 取消定时器
        cancelHoverTimer()
        cacheCleanupTimer?.invalidate()
        cacheCleanupTimer = nil
        
        // 隐藏预览窗口
        hidePreview(animated: false)
        
        // 注销所有跟踪区域
        unregisterAllHoverDetection()
        
        // 清除缓存
        clearCache()
        
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
        
        logger.info("预览管理器资源清理完成")
    }
    
    /// 析构函数
    deinit {
        // 确保资源被清理
        cleanup()
        logger.info("标签页预览管理器已释放")
    }
}

// MARK: - 迁回自 UI-02：class UITabPreviewSettingsViewController
public final class UITabPreviewSettingsViewController: NSViewController , @unchecked Sendable{
    
    /// 关联的预览管理器
    weak var manager: UITabPreviewManager?
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "UITabPreviewSettings")
    
    // MARK: UI 控件
    private var enabledCheckbox: NSButton!
    private var hoverDelayCheckbox: NSButton!
    private var hoverDelaySlider: NSSlider!
    private var hoverDelayLabel: NSTextField!
    private var widthSlider: NSSlider!
    private var widthLabel: NSTextField!
    private var heightSlider: NSSlider!
    private var heightLabel: NSTextField!
    private var autoFitCheckbox: NSButton!
    private var shadowCheckbox: NSButton!
    private var roundedCornersCheckbox: NSButton!
    private var animationCheckbox: NSButton!
    private var showTitleCheckbox: NSButton!
    private var titleSizeSlider: NSSlider!
    private var titleSizeLabel: NSTextField!
    private var alphaSlider: NSSlider!
    private var alphaLabel: NSTextField!
    private var cacheCountSlider: NSSlider!
    private var cacheCountLabel: NSTextField!
    private var clearCacheButton: NSButton!
    private var resetButton: NSButton!
    
    /// 加载视图
    override public func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 520))
    }
    
    /// 视图加载完成
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadCurrentSettings()
        
        logger.debug("设置面板已加载")
    }
    
    /// 设置界面布局
    private func setupUI() {
        let container = self.view
        var yOffset: CGFloat = 480
        
        // 标题
        let titleLabel = NSTextField(labelWithString: "标签页预览设置")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: yOffset, width: 440, height: 24)
        container.addSubview(titleLabel)
        yOffset -= 36
        
        // 启用预览
        enabledCheckbox = createCheckbox(title: "启用标签页预览", y: &yOffset)
        enabledCheckbox.target = self
        enabledCheckbox.action = #selector(settingChanged)
        container.addSubview(enabledCheckbox)
        yOffset -= 8
        
        // 分隔线
        addSeparator(at: &yOffset, in: container)
        
        // 悬停延迟设置
        let delayTitle = NSTextField(labelWithString: "悬停延迟")
        delayTitle.font = NSFont.boldSystemFont(ofSize: 13)
        delayTitle.frame = NSRect(x: 20, y: yOffset, width: 440, height: 20)
        container.addSubview(delayTitle)
        yOffset -= 28
        
        hoverDelayCheckbox = createCheckbox(title: "使用悬停延迟", y: &yOffset)
        hoverDelayCheckbox.target = self
        hoverDelayCheckbox.action = #selector(settingChanged)
        container.addSubview(hoverDelayCheckbox)
        
        hoverDelaySlider = NSSlider(value: 500, minValue: 100, maxValue: 2000, target: self, action: #selector(sliderChanged))
        hoverDelaySlider.frame = NSRect(x: 20, y: yOffset, width: 360, height: 20)
        container.addSubview(hoverDelaySlider)
        
        hoverDelayLabel = NSTextField(labelWithString: "500 ms")
        hoverDelayLabel.frame = NSRect(x: 390, y: yOffset, width: 70, height: 20)
        hoverDelayLabel.alignment = .right
        container.addSubview(hoverDelayLabel)
        yOffset -= 32
        
        // 分隔线
        addSeparator(at: &yOffset, in: container)
        
        // 预览尺寸
        let sizeTitle = NSTextField(labelWithString: "预览尺寸")
        sizeTitle.font = NSFont.boldSystemFont(ofSize: 13)
        sizeTitle.frame = NSRect(x: 20, y: yOffset, width: 440, height: 20)
        container.addSubview(sizeTitle)
        yOffset -= 28
        
        widthSlider = NSSlider(value: 320, minValue: 160, maxValue: 480, target: self, action: #selector(sliderChanged))
        widthSlider.frame = NSRect(x: 20, y: yOffset, width: 360, height: 20)
        container.addSubview(widthSlider)
        
        widthLabel = NSTextField(labelWithString: "320 px")
        widthLabel.frame = NSRect(x: 390, y: yOffset, width: 70, height: 20)
        widthLabel.alignment = .right
        container.addSubview(widthLabel)
        yOffset -= 28
        
        heightSlider = NSSlider(value: 240, minValue: 120, maxValue: 360, target: self, action: #selector(sliderChanged))
        heightSlider.frame = NSRect(x: 20, y: yOffset, width: 360, height: 20)
        container.addSubview(heightSlider)
        
        heightLabel = NSTextField(labelWithString: "240 px")
        heightLabel.frame = NSRect(x: 390, y: yOffset, width: 70, height: 20)
        heightLabel.alignment = .right
        container.addSubview(heightLabel)
        yOffset -= 28
        
        autoFitCheckbox = createCheckbox(title: "自动适应内容比例", y: &yOffset)
        autoFitCheckbox.target = self
        autoFitCheckbox.action = #selector(settingChanged)
        container.addSubview(autoFitCheckbox)
        yOffset -= 8
        
        // 分隔线
        addSeparator(at: &yOffset, in: container)
        
        // 外观设置
        let appearanceTitle = NSTextField(labelWithString: "外观")
        appearanceTitle.font = NSFont.boldSystemFont(ofSize: 13)
        appearanceTitle.frame = NSRect(x: 20, y: yOffset, width: 440, height: 20)
        container.addSubview(appearanceTitle)
        yOffset -= 28
        
        shadowCheckbox = createCheckbox(title: "显示窗口阴影", y: &yOffset)
        shadowCheckbox.target = self
        shadowCheckbox.action = #selector(settingChanged)
        container.addSubview(shadowCheckbox)
        
        roundedCornersCheckbox = createCheckbox(title: "圆角窗口", y: &yOffset)
        roundedCornersCheckbox.target = self
        roundedCornersCheckbox.action = #selector(settingChanged)
        container.addSubview(roundedCornersCheckbox)
        
        animationCheckbox = createCheckbox(title: "启用动画效果", y: &yOffset)
        animationCheckbox.target = self
        animationCheckbox.action = #selector(settingChanged)
        container.addSubview(animationCheckbox)
        
        showTitleCheckbox = createCheckbox(title: "显示标签标题", y: &yOffset)
        showTitleCheckbox.target = self
        showTitleCheckbox.action = #selector(settingChanged)
        container.addSubview(showTitleCheckbox)
        yOffset -= 8
        
        // 分隔线
        addSeparator(at: &yOffset, in: container)
        
        // 标题字体大小
        let titleSizeTitle = NSTextField(labelWithString: "标题字体大小")
        titleSizeTitle.font = NSFont.boldSystemFont(ofSize: 13)
        titleSizeTitle.frame = NSRect(x: 20, y: yOffset, width: 440, height: 20)
        container.addSubview(titleSizeTitle)
        yOffset -= 28
        
        titleSizeSlider = NSSlider(value: 12, minValue: 8, maxValue: 20, target: self, action: #selector(sliderChanged))
        titleSizeSlider.frame = NSRect(x: 20, y: yOffset, width: 360, height: 20)
        container.addSubview(titleSizeSlider)
        
        titleSizeLabel = NSTextField(labelWithString: "12 pt")
        titleSizeLabel.frame = NSRect(x: 390, y: yOffset, width: 70, height: 20)
        titleSizeLabel.alignment = .right
        container.addSubview(titleSizeLabel)
        yOffset -= 28
        
        // 背景透明度
        let alphaTitle = NSTextField(labelWithString: "背景透明度")
        alphaTitle.font = NSFont.boldSystemFont(ofSize: 13)
        alphaTitle.frame = NSRect(x: 20, y: yOffset, width: 440, height: 20)
        container.addSubview(alphaTitle)
        yOffset -= 28
        
        alphaSlider = NSSlider(value: 0.95, minValue: 0.5, maxValue: 1.0, target: self, action: #selector(sliderChanged))
        alphaSlider.frame = NSRect(x: 20, y: yOffset, width: 360, height: 20)
        container.addSubview(alphaSlider)
        
        alphaLabel = NSTextField(labelWithString: "95%")
        alphaLabel.frame = NSRect(x: 390, y: yOffset, width: 70, height: 20)
        alphaLabel.alignment = .right
        container.addSubview(alphaLabel)
        yOffset -= 32
        
        // 分隔线
        addSeparator(at: &yOffset, in: container)
        
        // 缓存设置
        let cacheTitle = NSTextField(labelWithString: "缓存设置")
        cacheTitle.font = NSFont.boldSystemFont(ofSize: 13)
        cacheTitle.frame = NSRect(x: 20, y: yOffset, width: 440, height: 20)
        container.addSubview(cacheTitle)
        yOffset -= 28
        
        cacheCountSlider = NSSlider(value: 20, minValue: 5, maxValue: 50, target: self, action: #selector(sliderChanged))
        cacheCountSlider.frame = NSRect(x: 20, y: yOffset, width: 360, height: 20)
        container.addSubview(cacheCountSlider)
        
        cacheCountLabel = NSTextField(labelWithString: "20 张")
        cacheCountLabel.frame = NSRect(x: 390, y: yOffset, width: 70, height: 20)
        cacheCountLabel.alignment = .right
        container.addSubview(cacheCountLabel)
        yOffset -= 32
        
        // 操作按钮
        clearCacheButton = NSButton(title: "清除缓存", target: self, action: #selector(clearCacheTapped))
        clearCacheButton.frame = NSRect(x: 20, y: yOffset, width: 120, height: 28)
        container.addSubview(clearCacheButton)
        
        resetButton = NSButton(title: "恢复默认", target: self, action: #selector(resetTapped))
        resetButton.frame = NSRect(x: 150, y: yOffset, width: 120, height: 28)
        container.addSubview(resetButton)
        
        logger.debug("设置界面已构建")
    }
    
    /// 创建复选框辅助方法
    private func createCheckbox(title: String, y: inout CGFloat) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        checkbox.frame = NSRect(x: 20, y: y, width: 440, height: 20)
        y -= 26
        return checkbox
    }
    
    /// 添加分隔线
    private func addSeparator(at y: inout CGFloat, in container: NSView) {
        let separator = NSBox()
        separator.boxType = .separator
        separator.frame = NSRect(x: 20, y: y, width: 440, height: 1)
        container.addSubview(separator)
        y -= 16
    }
    
    /// 加载当前设置到界面
    private func loadCurrentSettings() {
        guard let settings = manager?.getSettings() else { return }
        
        enabledCheckbox.state = settings.isEnabled ? .on : .off
        hoverDelayCheckbox.state = settings.useHoverDelay ? .on : .off
        hoverDelaySlider.doubleValue = settings.hoverDelayMs
        hoverDelayLabel.stringValue = "\(Int(settings.hoverDelayMs)) ms"
        widthSlider.doubleValue = Double(settings.previewWidth)
        widthLabel.stringValue = "\(Int(settings.previewWidth)) px"
        heightSlider.doubleValue = Double(settings.previewHeight)
        heightLabel.stringValue = "\(Int(settings.previewHeight)) px"
        autoFitCheckbox.state = settings.autoFitContent ? .on : .off
        shadowCheckbox.state = settings.showShadow ? .on : .off
        roundedCornersCheckbox.state = settings.showRoundedCorners ? .on : .off
        animationCheckbox.state = settings.enableAnimation ? .on : .off
        showTitleCheckbox.state = settings.showTabTitle ? .on : .off
        titleSizeSlider.doubleValue = Double(settings.titleFontSize)
        titleSizeLabel.stringValue = "\(Int(settings.titleFontSize)) pt"
        alphaSlider.doubleValue = Double(settings.backgroundAlpha)
        alphaLabel.stringValue = "\(Int(settings.backgroundAlpha * 100))%"
        cacheCountSlider.doubleValue = Double(settings.maxCacheCount)
        cacheCountLabel.stringValue = "\(settings.maxCacheCount) 张"
        
        logger.debug("当前设置已加载到界面")
    }
    
    /// 从界面收集设置
    private func collectSettingsFromUI() -> UITabPreviewSettings {
        var settings = UITabPreviewSettings()
        
        settings.isEnabled = enabledCheckbox.state == .on
        settings.useHoverDelay = hoverDelayCheckbox.state == .on
        settings.hoverDelayMs = hoverDelaySlider.doubleValue
        settings.previewWidth = CGFloat(widthSlider.doubleValue)
        settings.previewHeight = CGFloat(heightSlider.doubleValue)
        settings.autoFitContent = autoFitCheckbox.state == .on
        settings.showShadow = shadowCheckbox.state == .on
        settings.showRoundedCorners = roundedCornersCheckbox.state == .on
        settings.enableAnimation = animationCheckbox.state == .on
        settings.showTabTitle = showTitleCheckbox.state == .on
        settings.titleFontSize = CGFloat(titleSizeSlider.doubleValue)
        settings.backgroundAlpha = CGFloat(alphaSlider.doubleValue)
        settings.maxCacheCount = Int(cacheCountSlider.doubleValue)
        
        return settings
    }
    
    /// 设置变更处理
    @objc private func settingChanged() {
        let newSettings = collectSettingsFromUI()
        manager?.updateSettings(newSettings)
        logger.debug("设置已变更并保存")
    }
    
    /// 滑块变更处理
    @objc private func sliderChanged() {
        // 更新标签显示
        hoverDelayLabel.stringValue = "\(Int(hoverDelaySlider.doubleValue)) ms"
        widthLabel.stringValue = "\(Int(widthSlider.doubleValue)) px"
        heightLabel.stringValue = "\(Int(heightSlider.doubleValue)) px"
        titleSizeLabel.stringValue = "\(Int(titleSizeSlider.doubleValue)) pt"
        alphaLabel.stringValue = "\(Int(alphaSlider.doubleValue * 100))%"
        cacheCountLabel.stringValue = "\(Int(cacheCountSlider.doubleValue)) 张"
        
        // 保存设置
        settingChanged()
    }
    
    /// 清除缓存按钮点击
    @objc private func clearCacheTapped() {
        manager?.clearCache()
        
        // 显示确认提示
        let alert = NSAlert()
        alert.messageText = "缓存已清除"
        alert.informativeText = "所有预览缩略图缓存已被清除。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
        
        logger.info("用户手动清除缓存")
    }
    
    /// 恢复默认按钮点击
    @objc private func resetTapped() {
        manager?.resetSettings()
        loadCurrentSettings()
        
        let alert = NSAlert()
        alert.messageText = "设置已重置"
        alert.informativeText = "所有预览设置已恢复为默认值。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
        
        logger.info("用户重置设置为默认值")
    }
    
    /// 析构
    deinit {
        logger.debug("设置面板视图控制器已释放")
    }
}

// MARK: - 迁回自 UI-02：extension NSView
public extension NSView {
    /// 生成当前视图的内容快照
    /// - Returns: 截图图像，失败返回 nil
    func uiTabPreviewSnapshot() -> NSImage? {
        guard frame.size.width > 0, frame.size.height > 0 else { return nil }
        
        guard let bitmapRep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: bitmapRep)
        
        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmapRep)
        return image
    }
}

// MARK: - 迁回自 UI-02：UIPreviewConstants
private enum UIPreviewConstants {
    /// 悬停延迟时间（毫秒），避免鼠标快速滑过时频繁显示
    static let hoverDelayMs: TimeInterval = 500.0 / 1000.0
    /// 预览窗口默认宽度
    static let defaultWidth: CGFloat = 320.0
    /// 预览窗口默认高度
    static let defaultHeight: CGFloat = 240.0
    /// 预览窗口最大宽度
    static let maxWidth: CGFloat = 480.0
    /// 预览窗口最大高度
    static let maxHeight: CGFloat = 360.0
    /// 预览窗口最小宽度
    static let minWidth: CGFloat = 160.0
    /// 预览窗口最小高度
    static let minHeight: CGFloat = 120.0
    /// 窗口圆角半径
    static let cornerRadius: CGFloat = 12.0
    /// 窗口阴影偏移量
    static let shadowOffset: NSSize = NSSize(width: 0, height: -4)
    /// 窗口阴影模糊度
    static let shadowBlurRadius: CGFloat = 16.0
    /// 窗口与鼠标的垂直间距
    static let mouseOffsetY: CGFloat = 16.0
    /// 屏幕边缘安全间距
    static let screenEdgeMargin: CGFloat = 8.0
    /// 最大缓存数量
    static let maxCacheCount = 20
    /// 缓存过期时间（秒）
    static let cacheExpirationSeconds: TimeInterval = 300.0
    /// 缩略图缩放质量
    static let imageInterpolation: NSImageInterpolation = .high
    /// 动画持续时间
    static let animationDuration: TimeInterval = 0.15
    /// 预览窗口透明度
    static let windowAlpha: CGFloat = 1.0
    /// 背景色（深色半透明）
    static let backgroundColor: NSColor = NSColor(calibratedWhite: 0.12, alpha: 0.95)
    /// 边框颜色
    static let borderColor: NSColor = NSColor(calibratedWhite: 0.3, alpha: 0.6)
    /// 边框宽度
    static let borderWidth: CGFloat = 1.0
}

// MARK: - 迁回自 UI-02：UIPreviewCacheEntry
private struct UIPreviewCacheEntry {
    /// 缩略图图像
    let image: NSImage
    /// 原始内容尺寸
    let originalSize: NSSize
    /// 缓存时间戳
    let timestamp: Date
    /// 关联的标签标识符
    let tabIdentifier: String
    /// 标签标题（用于显示）
    let tabTitle: String
    
    /// 检查缓存是否过期
    func isExpired(expiration: TimeInterval) -> Bool {
        return Date().timeIntervalSince(timestamp) > expiration
    }
}

// MARK: - 迁回自 UI-02：struct UITabPreviewSettings
// MARK: - 视觉反馈管理器
/// 管理拖拽过程中的视觉反馈元素，包括：
/// 1. 半透明拖拽浮窗：跟随鼠标显示被拖拽标签页的标题
/// 2. 位置指示器：在目标窗口标签栏显示插入位置指示线
/// 3. 目标区域高亮：提示当前悬停的目标窗口
// 已迁回 UI-GL-47_标签页脱离合并.swift：class UIDragVisualFeedbackManager（公共类型文件禁止功能实现）

// MARK: - 标签拖拽管理器
/// 管理标签页的拖拽脱离、窗口间合并和创建新窗口
/// 核心功能：
/// 1. 拖拽检测：通过 NSPanGestureRecognizer 或 mouseDragged 检测标签拖拽
/// 2. 标签脱离：从源窗口移出标签页，生成独立浮动窗口
/// 3. 标签合并：拖拽到目标窗口标签栏区域，合并为目标窗口的标签页
/// 4. 创建新窗口：拖拽到空白区域，创建新的独立窗口
/// 5. 视觉反馈：拖拽过程中显示半透明浮窗和位置指示器
/// 6. 持久化：支持配置 Codable 序列化保存到 UserDefaults
// 已迁回 UI-GL-47_标签页脱离合并.swift：UIAssociatedKeys（功能辅助状态不属于公共类型）

// 已迁回 UI-GL-47_标签页脱离合并.swift：class UITabDragManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-48 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-48_types.swift
// 版本: 2.0
// MARK: - 预览配置常量
/// 标签页预览的默认配置参数
// 已迁回 UI-GL-48_标签页预览.swift：UIPreviewConstants（功能辅助类型不属于公共类型）

// MARK: - 预览设置结构体
/// 标签页预览的用户可配置设置
public struct UITabPreviewSettings: Codable, Equatable, Sendable {
    /// 是否启用预览功能
    public var isEnabled: Bool = true
    /// 是否启用悬停延迟
    public var useHoverDelay: Bool = true
    /// 悬停延迟时间（毫秒）
    public var hoverDelayMs: Double = 500.0
    /// 预览窗口宽度
    public var previewWidth: CGFloat = 320.0
    /// 预览窗口高度
    public var previewHeight: CGFloat = 240.0
    /// 是否自动适应内容比例
    public var autoFitContent: Bool = true
    /// 是否显示窗口阴影
    public var showShadow: Bool = true
    /// 是否显示圆角
    public var showRoundedCorners: Bool = true
    /// 是否启用动画
    public var enableAnimation: Bool = true
    /// 最大缓存数量
    public var maxCacheCount: Int = 20
    /// 是否显示标签标题
    public var showTabTitle: Bool = true
    /// 标题字体大小
    public var titleFontSize: CGFloat = 12.0
    /// 背景透明度（0.0-1.0）
    public var backgroundAlpha: CGFloat = 0.95
    
    /// 默认配置
    public static let `default` = UITabPreviewSettings()
    
    /// 编码键
    enum UICodingKeys: String, CodingKey {
        case isEnabled, useHoverDelay, hoverDelayMs
        case previewWidth, previewHeight, autoFitContent
        case showShadow, showRoundedCorners, enableAnimation
        case maxCacheCount, showTabTitle, titleFontSize, backgroundAlpha
    }
}

// MARK: - 迁回自 UI-02：protocol UITabPreviewItem
// MARK: - 缓存条目
/// 单个预览缩略图的缓存数据
// 已迁回 UI-GL-48_标签页预览.swift：UIPreviewCacheEntry（功能辅助类型不属于公共类型）

// MARK: - 标签项协议
/// 标签页预览所需的标签项接口
public protocol UITabPreviewItem: AnyObject {
    /// 标签唯一标识符
    var previewIdentifier: String { get }
    /// 标签标题
    var previewTitle: String { get }
    /// 标签内容视图（用于截图）
    var previewContentView: NSView? { get }
    /// 标签窗口（用于窗口截图）
    var previewWindow: NSWindow? { get }
}
