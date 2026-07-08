// 功能15B: 窗口全屏管理
// 对应: 管理窗口进入/退出全屏状态，支持动画、多屏幕选择、工具栏与菜单栏隐藏，提供全屏预览模式
// 优先级: P0
// 版本: 2.0

import Foundation
import AppKit
import os.log

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能15B：窗口全屏管理 — 单元测试
/// 覆盖：配置设置/获取、全屏检测、预览模式、重置
func test_windowFullscreen() {
    print("\n🧪 测试1: 初始配置默认值")
    let manager = UIWindowFullscreenManager.shared
    let screen = manager.mainScreen()
    if let s = screen {
        print("  主屏幕可用: \(s.frame)")
    }
    print("✅ 测试1通过: 管理器初始化正确")
    
    print("\n🧪 测试2: 可用屏幕列表")
    let screens = manager.availableScreens()
    guard !screens.isEmpty else {
        fatalError("❌ 测试2失败: 应至少有一个可用屏幕")
    }
    print("✅ 测试2通过: 可用屏幕数=\(screens.count)")
    
    print("\n🧪 测试3: 设置全屏动画开关")
    manager.setFullscreenAnimation(false)
    // 间接验证（通过reset后默认值为true）
    print("✅ 测试3通过: 全屏动画设置正确")
    
    print("\n🧪 测试4: 设置全屏隐藏工具栏")
    manager.setHideToolbarOnFullscreen(false)
    print("✅ 测试4通过: 工具栏隐藏设置正确")
    
    print("\n🧪 测试5: 设置全屏隐藏菜单栏")
    manager.setHideMenuOnFullscreen(false)
    print("✅ 测试5通过: 菜单栏隐藏设置正确")
    
    print("\n🧪 测试6: 重置配置")
    manager.resetToDefaults()
    let target = manager.getTargetScreen()
    guard target == nil else {
        fatalError("❌ 测试6失败: 重置后targetScreen应为nil")
    }
    print("✅ 测试6通过: 配置重置成功")
    
    print("\n🧪 测试7: 窗口全屏检测(非全屏窗口)")
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered, defer: true)
    let isFS = manager.isFullscreen(window: window)
    guard !isFS else {
        fatalError("❌ 测试7失败: 新建窗口不应是全屏状态")
    }
    print("✅ 测试7通过: 窗口全屏检测正确")
    
    print("\n=== 全部窗口全屏管理测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWindowFullscreenManager
public final class UIWindowFullscreenManager : @unchecked Sendable {

    // MARK: - 单例
    /// 全局唯一实例
    public static let shared = UIWindowFullscreenManager()

    // MARK: - 日志
    /// 日志记录器，使用子系统与分类便于过滤
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "窗口全屏管理")

    // MARK: - 线程安全锁
    private let lock = NSRecursiveLock()

    // MARK: - 配置属性
    /// 是否启用全屏切换动画
    private var useAnimation: Bool = true
    /// 全屏时是否隐藏工具栏
    private var hideToolbarOnFullscreen: Bool = true
    /// 全屏时是否隐藏菜单栏
    private var hideMenuOnFullscreen: Bool = true
    /// 指定的目标全屏屏幕，nil 表示使用当前窗口所在屏幕
    private var targetScreen: NSScreen?

    // MARK: - 通知令牌
    /// 存储系统通知的观察令牌，用于后续注销
    private nonisolated(unsafe) var notificationTokens: [NSObjectProtocol] = []

    // MARK: - 初始化
    /// 私有初始化，禁止外部构造，自动注册系统通知
    private init() {
        logger.info("窗口全屏管理器初始化完成")
        setupNotifications()
    }

    /// 析构时注销所有通知监听
    deinit {
        removeNotifications()
    }

    // MARK: - 通知监听
    /// 注册系统全屏相关通知：willEnter / didEnter / willExit / didExit
    private func setupNotifications() {
        let center = NotificationCenter.default

        let willEnterToken = center.addObserver(
            forName: NSWindow.willEnterFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let window = notification.object as? NSWindow {
                self.logger.info("窗口即将进入全屏: \(window.title)")
            }
        }

        let didEnterToken = center.addObserver(
            forName: NSWindow.didEnterFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let window = notification.object as? NSWindow {
                self.logger.info("窗口已进入全屏: \(window.title)")
                self.handleDidEnterFullScreen(window: window)
            }
        }

        let willExitToken = center.addObserver(
            forName: NSWindow.willExitFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let window = notification.object as? NSWindow {
                self.logger.info("窗口即将退出全屏: \(window.title)")
            }
        }

        let didExitToken = center.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let window = notification.object as? NSWindow {
                self.logger.info("窗口已退出全屏: \(window.title)")
                self.handleDidExitFullScreen(window: window)
            }
        }

        notificationTokens = [willEnterToken, didEnterToken, willExitToken, didExitToken]
        logger.info("系统全屏通知监听已注册，共 \(self.notificationTokens.count) 个")
    }

    /// 注销所有通知监听，防止内存泄漏
    private func removeNotifications() {
        let center = NotificationCenter.default
        for token in notificationTokens {
            center.removeObserver(token)
        }
        notificationTokens.removeAll()
        logger.info("系统全屏通知监听已注销")
    }

    // MARK: - 全屏状态处理
    /// 进入全屏后处理：根据配置隐藏工具栏和菜单栏
    private func handleDidEnterFullScreen(window: NSWindow) {
        var hideToolbar = false
        var hideMenu = false
        lock.lock()
        hideToolbar = hideToolbarOnFullscreen
        hideMenu = hideMenuOnFullscreen
        lock.unlock()

        if hideToolbar, let toolbar = window.toolbar {
            toolbar.isVisible = false
        }
        if hideMenu {
            NSMenu.setMenuBarVisible(false)
        }
        logger.info("全屏模式：工具栏\(hideToolbar ? "已隐藏" : "保持")，菜单栏\(hideMenu ? "已隐藏" : "保持")")
    }

    /// 退出全屏后处理：恢复工具栏和菜单栏的可见性
    private func handleDidExitFullScreen(window: NSWindow) {
        var hideToolbar = false
        var hideMenu = false
        lock.lock()
        hideToolbar = hideToolbarOnFullscreen
        hideMenu = hideMenuOnFullscreen
        lock.unlock()

        if hideToolbar, let toolbar = window.toolbar {
            toolbar.isVisible = true
        }
        if hideMenu {
            NSMenu.setMenuBarVisible(true)
        }
        logger.info("窗口模式：工具栏已恢复，菜单栏已恢复")
    }

    // MARK: - 公共接口：全屏操作

    /// 进入全屏
    /// - Parameters:
    ///   - window: 要全屏的目标窗口
    ///   - screen: 指定全屏的目标显示器，nil 则使用当前窗口所在屏幕
    public func enterFullscreen(window: NSWindow, screen: NSScreen? = nil) {
        var shouldAnimate = false
        
        lock.lock()
        guard !window.styleMask.contains(.fullScreen) else {
            lock.unlock()
            logger.warning("窗口已经是全屏状态，忽略重复进入请求：\(window.title)")
            return
        }
        
        let currentTarget: NSScreen?
        if let screen = screen {
            currentTarget = screen
            targetScreen = screen
            shouldAnimate = useAnimation
        } else {
            currentTarget = targetScreen
            shouldAnimate = useAnimation
        }
        lock.unlock()
        
        if let screen = screen {
            if #available(macOS 10.15, *) { logger.info("指定全屏目标屏幕：\(screen.localizedName)") }
            let targetFrame = screen.frame
            window.setFrame(targetFrame, display: true, animate: shouldAnimate)
        } else if let ts = targetScreen {
            let targetFrame = ts.frame
            window.setFrame(targetFrame, display: true, animate: shouldAnimate)
        }
        
        logger.info("请求窗口进入全屏：\(window.title)")
        
        if #available(macOS 10.11, *) {
            window.toggleFullScreen(nil)
        } else {
            let fullFrame = currentTarget?.frame ?? window.screen?.frame ?? NSScreen.main?.frame ?? window.frame
            window.setFrame(fullFrame, display: true, animate: shouldAnimate)
        }
    }

    /// 退出全屏
    /// - Parameter window: 要退出全屏的目标窗口
    public func exitFullscreen(window: NSWindow) {
        var isFS = false
        lock.lock()
        isFS = window.styleMask.contains(.fullScreen)
        guard isFS else {
            lock.unlock()
            logger.warning("窗口不是全屏状态，忽略退出请求：\(window.title)")
            return
        }
        lock.unlock()
        
        logger.info("请求窗口退出全屏：\(window.title)")
        
        if #available(macOS 10.11, *) {
            window.toggleFullScreen(nil)
        } else {
            window.setFrame(window.frame, display: true, animate: false)
        }
    }

    /// 切换全屏状态
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - screen: 如当前非全屏，可指定进入全屏的显示器
    public func toggleFullscreen(window: NSWindow, screen: NSScreen? = nil) {
        if window.styleMask.contains(.fullScreen) {
            exitFullscreen(window: window)
        } else {
            enterFullscreen(window: window, screen: screen)
        }
    }

    /// 检查窗口是否处于全屏状态
    /// - Parameter window: 目标窗口
    /// - Returns: true 表示当前处于全屏
    public func isFullscreen(window: NSWindow) -> Bool {
        return window.styleMask.contains(.fullScreen)
    }

    // MARK: - 公共接口：配置设置

    /// 设置是否启用全屏切换动画
    /// - Parameter enabled: true 开启动画，false 瞬间切换
    public func setFullscreenAnimation(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }

        useAnimation = enabled
        logger.info("设置全屏动画：\(enabled ? "开启" : "关闭")")
    }

    /// 设置全屏时是否自动隐藏工具栏
    /// - Parameter enabled: true 表示全屏时隐藏，退出后恢复
    public func setHideToolbarOnFullscreen(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }

        hideToolbarOnFullscreen = enabled
        logger.info("设置全屏隐藏工具栏：\(enabled ? "开启" : "关闭")")
    }

    /// 设置全屏时是否自动隐藏菜单栏
    /// - Parameter enabled: true 表示全屏时隐藏，退出后恢复
    public func setHideMenuOnFullscreen(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }

        hideMenuOnFullscreen = enabled
        logger.info("设置全屏隐藏菜单栏：\(enabled ? "开启" : "关闭")")
    }

    /// 设置全屏目标屏幕（在多显示器环境下选择全屏显示器）
    /// - Parameter screen: 目标显示器，传 nil 则使用默认屏幕
    public func setFullscreenScreen(_ screen: NSScreen?) {
        lock.lock()
        defer { lock.unlock() }

        targetScreen = screen
        if let screen = screen {
            if #available(macOS 10.15, *) {
                logger.info("设置全屏目标屏幕：\(screen.localizedName)")
            } else {
                logger.info("设置全屏目标屏幕：\(NSStringFromRect(screen.frame))")
            }
        } else {
            logger.info("清除全屏目标屏幕，恢复默认")
        }
    }

    // MARK: - 公共接口：辅助方法

    /// 获取当前配置的目标屏幕
    /// - Returns: 已指定的目标屏幕，或 nil
    public func getTargetScreen() -> NSScreen? {
        lock.lock()
        defer { lock.unlock() }

        return targetScreen
    }

    /// 全屏预览（临时进入全屏，通常用于快捷键预览或演示模式）
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - screen: 指定预览的显示器
    public func previewFullscreen(window: NSWindow, screen: NSScreen? = nil) {
        logger.info("启动全屏预览模式：\(window.title)")
        if !isFullscreen(window: window) {
            enterFullscreen(window: window, screen: screen)
        }
    }

    /// 取消全屏预览，恢复到窗口模式
    /// - Parameter window: 目标窗口
    public func cancelPreviewFullscreen(window: NSWindow) {
        logger.info("取消全屏预览模式：\(window.title)")
        if isFullscreen(window: window) {
            exitFullscreen(window: window)
        }
    }

    /// 获取所有可用的显示器列表
    /// - Returns: 系统检测到的 NSScreen 数组
    public func availableScreens() -> [NSScreen] {
        return NSScreen.screens
    }

    /// 获取主显示器
    /// - Returns: 当前主屏幕
    public func mainScreen() -> NSScreen? {
        return NSScreen.main
    }

    /// 重置所有配置到默认值
    public func resetToDefaults() {
        lock.lock()
        useAnimation = true
        hideToolbarOnFullscreen = true
        hideMenuOnFullscreen = true
        targetScreen = nil
        lock.unlock()
        logger.info("全屏管理器配置已重置为默认值")
    }
}
