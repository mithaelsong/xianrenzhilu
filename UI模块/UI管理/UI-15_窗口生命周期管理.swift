// 功能2: 窗口生命周期管理
// 对应: 创建、显示、隐藏、关闭、销毁，支持关闭前确认回调
// 优先级: P0

import Foundation
import AppKit
import os

// 使用UI-02的WindowInfo和UIWindowRecord
// 本文件不再定义这些类型

// MARK: - 窗口生命周期代理协议
/// 窗口生命周期事件的回调协议
/// 所有方法均为可选，窗口生命周期管理器会在适当时机自动调用
// 类型 UIWindowLifecycleDelegate 已迁移到 UI-02_公共类型定义.swift

// MARK: - 窗口生命周期管理器
/// 管理窗口的完整生命周期：创建 → 显示 → 隐藏 → 关闭 → 销毁
/// 支持关闭前确认回调，自动对接窗口注册表记录
/// 线程安全：所有公开方法使用 NSRecursiveLock 保护共享状态
/// 生命周期事件序列：
///   创建时：   windowDidCreate
///   显示时：   windowDidShow
///   隐藏时：   windowDidHide
///   关闭前：   windowShouldClose（可阻止）
///   关闭时：   windowDidClose → windowDidDestroy
///   最小化：   windowDidMiniaturize
///   恢复：     windowDidDeminiaturize
///   获得焦点： windowDidBecomeKey
///   失去焦点： windowDidResignKey
///   尺寸变化： windowDidResize
///   位置变化： windowDidMove
// 类型 UIWindowLifecycleManager 已迁移到 UI-02_公共类型定义.swift

// MARK: - NSWindowDelegate 实现
extension UIWindowLifecycleManager: NSWindowDelegate {
    
    /// 窗口即将关闭时由系统调用
    /// 依次检查确认回调和代理确认方法，任一阻止则关闭取消
    /// - Parameter sender: 即将关闭的窗口
    /// - Returns: 返回 true 允许关闭，返回 false 阻止关闭
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 获取窗口ID
        guard let windowID = sender.identifier?.rawValue else {
            return true
        }
        
        // 加锁读取确认回调，锁外执行回调
        lock.lock()
        let confirm = confirmCallbacks[windowID]
        lock.unlock()
        
        // 执行确认回调（如有）
        if let confirm = confirm, !confirm(sender) {
            logger.info("[窗口生命周期] 系统关闭请求被确认回调阻止：窗口 '\(windowID)'")
            return false
        }
        
        // 加锁读取代理，锁外执行回调
        lock.lock()
        let currentDelegate = delegate
        lock.unlock()
        
        // 执行代理确认方法（如有）
        if let currentDelegate = currentDelegate,
           let shouldClose = currentDelegate.windowShouldClose?(sender) {
            if !shouldClose {
                logger.info("[窗口生命周期] 系统关闭请求被代理阻止：窗口 '\(windowID)'")
            }
            return shouldClose
        }
        
        return true
    }
    
    /// 窗口即将关闭时由系统调用（通知形式）
    /// 执行清理操作：标记关闭、通知代理、移除回调
    /// - Parameter notification: 包含关闭窗口对象的通知
    public func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let windowID = window.identifier?.rawValue else {
            return
        }
        
        // 刷新最后访问时间
        windowRecord.touch()
        
        // 通知代理关闭事件
        notifyDelegate(selector: #selector(UIWindowLifecycleDelegate.windowDidClose(_:)), window: window)
        
        // 执行清理
        cleanupAfterClose(windowID: windowID)
        
        logger.info("[窗口生命周期] 系统通知：窗口 '\(windowID)' 已关闭并清理")
    }
    
    /// 窗口已成为主窗口时由系统调用
    /// - Parameter notification: 包含窗口对象的通知
    public func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let windowID = window.identifier?.rawValue else {
            return
        }
        
        windowRecord.touch()
        notifyDelegate(selector: #selector(UIWindowLifecycleDelegate.windowDidBecomeKey(_:)), window: window)
        logger.debug("[窗口生命周期] 窗口 '\(windowID)' 已成为主窗口")
    }
    
    /// 窗口已失去主窗口状态时由系统调用
    /// - Parameter notification: 包含窗口对象的通知
    public func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let windowID = window.identifier?.rawValue else {
            return
        }
        
        windowRecord.touch()
        notifyDelegate(selector: #selector(UIWindowLifecycleDelegate.windowDidResignKey(_:)), window: window)
        logger.debug("[窗口生命周期] 窗口 '\(windowID)' 已失去主窗口状态")
    }
    
    /// 窗口已最小化时由系统调用
    /// - Parameter notification: 包含窗口对象的通知
    public func windowDidMiniaturize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let windowID = window.identifier?.rawValue else {
            return
        }
        
        windowRecord.touch()
        notifyDelegate(selector: #selector(UIWindowLifecycleDelegate.windowDidMiniaturize(_:)), window: window)
        logger.info("[窗口生命周期] 窗口 '\(windowID)' 已最小化")
    }
    
    /// 窗口已从最小化恢复时由系统调用
    /// - Parameter notification: 包含窗口对象的通知
    public func windowDidDeminiaturize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let windowID = window.identifier?.rawValue else {
            return
        }
        
        windowRecord.touch()
        notifyDelegate(selector: #selector(UIWindowLifecycleDelegate.windowDidDeminiaturize(_:)), window: window)
        logger.info("[窗口生命周期] 窗口 '\(windowID)' 已从最小化恢复")
    }
    
    /// 窗口尺寸已改变时由系统调用
    /// - Parameter notification: 包含窗口对象的通知
    public func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }
        
        windowRecord.touch()
        notifyDelegate(selector: #selector(UIWindowLifecycleDelegate.windowDidResize(_:)), window: window)
    }
    
    /// 窗口位置已改变时由系统调用
    /// - Parameter notification: 包含窗口对象的通知
    public func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }
        
        windowRecord.touch()
        notifyDelegate(selector: #selector(UIWindowLifecycleDelegate.windowDidMove(_:)), window: window)
    }
}

// MARK: - Auto-generated stubs for UI-15_窗口生命周期管理.swift

/*
使用示例：

// 创建窗口记录
let record = UIWindowRecord(
    windowID: "main-editor",
    windowController: myController,
    moduleName: "editor"
)

// 创建生命周期管理器
let lifecycleManager = UIWindowLifecycleManager(record: record)
window.delegate = lifecycleManager  // 设为 NSWindow 的 delegate

// 设置代理（可选）
lifecycleManager.delegate = myDelegate

// 设置关闭确认（可选）
lifecycleManager.setConfirmCallback(for: "main-editor") { window in
    let hasUnsavedChanges = checkUnsavedChanges()
    if hasUnsavedChanges {
        showSaveDialog()  // 显示保存对话框
        return false      // 阻止关闭，等用户确认后再手动关闭
    }
    return true
}

// 移除关闭确认
lifecycleManager.removeConfirmCallback(for: "main-editor")
*/


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWindowLifecycleManager
@MainActor public final class UIWindowLifecycleManager: NSObject , @unchecked Sendable {
    public static let shared: UIWindowLifecycleManager = {
        let window = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
        let controller = NSWindowController(window: window)
        let record = UIWindowRecord(windowID: "__shared_lifecycle__", window: window, windowController: controller, moduleName: "system", creationTime: Date(), isClosed: false, frame: .zero, zIndex: 0)
        return UIWindowLifecycleManager(record: record)
    }()
    /// 关联的窗口注册表记录
    public var windowRecord: UIWindowRecord
    /// 生命周期代理，弱引用避免循环引用
    public weak var delegate: UIWindowLifecycleDelegate?
    
    /// 锁，保护 confirmCallbacks 等共享状态
    let lock = NSRecursiveLock()
    /// 关闭确认回调字典，key 为窗口ID
    var confirmCallbacks: [String: (NSWindow) -> Bool] = [:]
    /// 窗口可见性 KVO 观察者
    nonisolated(unsafe) var visibilityObserver: NSKeyValueObservation?
    /// 日志
    let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "02_窗口生命周期")
    
    /// 创建生命周期管理器
    /// 初始化时自动触发 windowDidCreate 代理回调
    /// - Parameter record: 窗口注册表记录
    public init(record: UIWindowRecord) {
        self.windowRecord = record
        super.init()
        setupVisibilityObservation()
        notifyDelegate(selector: #selector(UIWindowLifecycleDelegate.windowDidCreate(_:)))
        logger.info("[窗口生命周期] 窗口 '\(record.windowID)' 生命周期管理器已创建")
    }
    
    nonisolated deinit {
        visibilityObserver?.invalidate()
        logger.debug("[窗口生命周期] 窗口生命周期管理器已销毁")
    }
    
    /// 窗口控制器
    public var windowController: NSWindowController { windowRecord.windowController! }
    
    // MARK: - 关闭确认回调
    
    /// 设置关闭确认回调
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - callback: 确认闭包，返回 true 允许关闭，返回 false 阻止关闭
    public func setConfirmCallback(for windowID: String, callback: @escaping (NSWindow) -> Bool) {
        lock.lock()
        confirmCallbacks[windowID] = callback
        lock.unlock()
    }
    
    /// 移除关闭确认回调
    /// - Parameter windowID: 窗口ID
    public func removeConfirmCallback(for windowID: String) {
        lock.lock()
        confirmCallbacks.removeValue(forKey: windowID)
        lock.unlock()
    }
    
    // MARK: - 代理通知
    
    /// 通知代理某个事件（线程安全，在锁外执行代理调用，避免死锁）
    /// - Parameters:
    ///   - selector: 代理方法的选择器
    ///   - window: 事件关联的窗口，默认为 windowRecord.window
    func notifyDelegate(selector: Selector, window: NSWindow? = nil) {
        // 锁定读取 delegate，防止并发写入期间读取到中间态
        let currentDelegate: UIWindowLifecycleDelegate?
        lock.lock()
        currentDelegate = delegate
        lock.unlock()
        
        guard let del = currentDelegate as? NSObject,
              del.responds(to: selector) else { return }
        let targetWindow = window ?? windowRecord.window
        del.perform(selector, with: targetWindow)
    }
    
    // MARK: - 可见性观测
    
    /// 设置窗口可见性 KVO 观察
    /// 窗口显示时触发 windowDidShow，隐藏时触发 windowDidHide
    func setupVisibilityObservation() {
        let window = windowRecord.window
        visibilityObserver = window.observe(\.isVisible, options: [.new, .old]) {
            [weak self] window, change in
            guard let self = self else { return }
            guard let newValue = change.newValue,
                  let oldValue = change.oldValue,
                  newValue != oldValue else { return }
            // KVO 回调在任意线程执行，切换到 MainActor 访问 @MainActor 隔离的属性和方法
            Task { @MainActor in
                if newValue {
                    self.notifyDelegate(selector: #selector(UIWindowLifecycleDelegate.windowDidShow(_:)), window: window)
                    self.logger.info("[窗口生命周期] 窗口 '\(self.windowRecord.windowID)' 已显示")
                } else {
                    self.notifyDelegate(selector: #selector(UIWindowLifecycleDelegate.windowDidHide(_:)), window: window)
                    self.logger.info("[窗口生命周期] 窗口 '\(self.windowRecord.windowID)' 已隐藏")
                }
            }
        }
    }
    
    // MARK: - 关闭后清理
    
    /// 关闭后清理：移除关闭确认回调，标记窗口已关闭，触发销毁事件
    /// - Parameter windowID: 窗口ID
    func cleanupAfterClose(windowID: String) {
        // 先通知代理窗口已销毁（清理前仍可查询记录）
        notifyDelegate(selector: #selector(UIWindowLifecycleDelegate.windowDidDestroy(_:)))
        
        lock.lock()
        confirmCallbacks.removeValue(forKey: windowID)
        lock.unlock()
        
        // 标记窗口记录为已关闭
        windowRecord.markClosed()
        // 停止可见性观察，避免关闭后的无用回调
        visibilityObserver?.invalidate()
        visibilityObserver = nil
        
        logger.info("[窗口生命周期] 窗口 '\(windowID)' 已销毁，所有回调已清理")
    }
}

// MARK: - 迁回自 UI-02：protocol UIWindowLifecycleDelegate
// MARK: - 迁移自 UI-10_UI模块热替换.swift：UIOldVersionModule
// 已迁回 UI-10_UI模块热替换.swift：class UIOldVersionModule（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-10_UI模块热替换.swift：UITestPreservableModule
// 已迁回 UI-10_UI模块热替换.swift：class UITestPreservableModule（公共类型文件禁止功能实现）



// 已迁回 UI-10_UI模块热替换.swift：extension UIModuleDynamicLoader（公共类型文件禁止功能实现）

// MARK: - 迁移自 UI-10_UI模块热替换.swift：UIModuleHotReplacer
// 已迁回 UI-10_UI模块热替换.swift：class UIModuleHotReplacer（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-11_UI模块版本检查.swift：UIModuleVersionChecker
// 已迁回 UI-11_UI模块版本检查.swift：class UIModuleVersionChecker（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-12_UI模块热重载（开发）.swift：UIReloaderTestModule
// 已迁回 UI-12_UI模块热重载（开发）.swift：class UIReloaderTestModule（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-12_UI模块热重载（开发）.swift：UIModuleHotReloader
// 已迁回 UI-12_UI模块热重载（开发）.swift：class UIModuleHotReloader（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-14_UI模块列表UI.swift：UITestListModule
// 已迁回 UI-14_UI模块列表UI.swift：class UITestListModule（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-14_UI模块列表UI.swift：UIModuleListUI
// 已迁回 UI-14_UI模块列表UI.swift：class UIModuleListUI（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-15_窗口生命周期管理.swift：UIWindowLifecycleDelegate
@objc public protocol UIWindowLifecycleDelegate: AnyObject {
    
    /// 窗口即将关闭，返回 false 阻止关闭
    /// - Parameter window: 即将关闭的窗口
    /// - Returns: 返回 true 允许关闭，返回 false 阻止关闭
    @objc optional func windowShouldClose(_ window: NSWindow) -> Bool
    
    /// 窗口已关闭
    /// - Parameter window: 已关闭的窗口
    @objc optional func windowDidClose(_ window: NSWindow)
    
    /// 窗口已显示
    /// - Parameter window: 已显示的窗口
    @objc optional func windowDidShow(_ window: NSWindow)
    
    /// 窗口已隐藏
    /// - Parameter window: 已隐藏的窗口
    @objc optional func windowDidHide(_ window: NSWindow)
    
    /// 窗口已创建（已注册到窗口注册表）
    /// - Parameter window: 已创建的窗口
    @objc optional func windowDidCreate(_ window: NSWindow)
    
    /// 窗口已销毁（已从注册表移除）
    /// - Parameter window: 已销毁的窗口
    @objc optional func windowDidDestroy(_ window: NSWindow)
    
    /// 窗口已最小化
    /// - Parameter window: 已最小化的窗口
    @objc optional func windowDidMiniaturize(_ window: NSWindow)
    
    /// 窗口已恢复（从最小化状态恢复）
    /// - Parameter window: 已恢复的窗口
    @objc optional func windowDidDeminiaturize(_ window: NSWindow)
    
    /// 窗口已成为主窗口
    /// - Parameter window: 已成为主窗口的窗口
    @objc optional func windowDidBecomeKey(_ window: NSWindow)
    
    /// 窗口已失去主窗口状态
    /// - Parameter window: 已失去主窗口状态的窗口
    @objc optional func windowDidResignKey(_ window: NSWindow)
    
    /// 窗口尺寸已改变
    /// - Parameter window: 尺寸已改变的窗口
    @objc optional func windowDidResize(_ window: NSWindow)
    
    /// 窗口位置已改变
    /// - Parameter window: 位置已改变的窗口
    @objc optional func windowDidMove(_ window: NSWindow)
}
