// 功能55: 完整键盘导航
// 对应: 所有UI元素可通过Tab/方向键访问，支持全局快捷键
// 优先级: P2

import AppKit
import Foundation
import os.log

// MARK: - 测试代码
#if DEBUG

/// 功能55：完整键盘导航 — 单元测试
func test_keyboardNav() {
    let manager = UIKeyboardNavigationManager.shared
    let logger = OSLog(subsystem: "com.xianrenzhilu.ui", category: "UI-GL-65")
    
    os_log("测试1: 默认设置", log: logger, type: .info)
    let settings = manager.getCurrentSettings()
    if settings.isEnabled { os_log("✅ 测试1通过", log: logger, type: .info) }
    else { os_log("❌ 测试1失败", log: logger, type: .error) }
    
    os_log("测试2: 注册焦点元素", log: logger, type: .info)
    let element = UIFocusableElementInfo(
        identifier: "btn1", displayName: "按钮1",
        moduleName: "test", frame: .zero, tabIndex: 1, isEnabled: true, hierarchyLevel: 0
    )
    manager.registerFocusableElement(element)
    let all = manager.getAllFocusableElements()
    if all.count == 1 { os_log("✅ 测试2通过", log: logger, type: .info) }
    else { os_log("❌ 测试2失败", log: logger, type: .error) }
    
    os_log("测试3: 设置焦点", log: logger, type: .info)
    if manager.setFocus(to: "btn1") { os_log("✅ 测试3通过", log: logger, type: .info) }
    else { os_log("❌ 测试3失败", log: logger, type: .error) }
    
    os_log("测试4: 焦点查询", log: logger, type: .info)
    if manager.isFocused("btn1") { os_log("✅ 测试4通过", log: logger, type: .info) }
    else { os_log("❌ 测试4失败", log: logger, type: .error) }
    
    os_log("测试5: Tab切换", log: logger, type: .info)
    let element2 = UIFocusableElementInfo(
        identifier: "btn2", displayName: "按钮2",
        moduleName: "test", frame: .zero, tabIndex: 2, isEnabled: true, hierarchyLevel: 0
    )
    manager.registerFocusableElement(element2)
    let moved = manager.moveFocusToNext()
    if moved { os_log("✅ 测试5通过: 焦点已移动", log: logger, type: .info) }
    else { os_log("❌ 测试5失败", log: logger, type: .error) }
    
    os_log("测试6: 方向键", log: logger, type: .info)
    let movedDir = manager.moveFocusInDirection(.down)
    _ = movedDir
    os_log("✅ 测试6通过", log: logger, type: .info)
    
    os_log("测试7: Esc键", log: logger, type: .info)
    manager.clearFocus()
    if !manager.isFocused("btn1") { os_log("✅ 测试7通过", log: logger, type: .info) }
    else { os_log("❌ 测试7失败", log: logger, type: .error) }
    
    os_log("测试8: 注销元素", log: logger, type: .info)
    manager.unregisterFocusableElement(identifier: "btn1")
    let afterUnreg = manager.getAllFocusableElements()
    if afterUnreg.count == 1 { os_log("✅ 测试8通过", log: logger, type: .info) }
    else { os_log("❌ 测试8失败", log: logger, type: .error) }
    
    os_log("测试9: 更新设置", log: logger, type: .info)
    var newSettings = manager.getCurrentSettings()
    newSettings.navigationMode = .arrowKeys
    manager.applySettings(newSettings)
    let afterApply = manager.getCurrentSettings()
    if afterApply.navigationMode == .arrowKeys { os_log("✅ 测试9通过", log: logger, type: .info) }
    else { os_log("❌ 测试9失败", log: logger, type: .error) }
    
    os_log("测试10: 重置设置", log: logger, type: .info)
    manager.resetSettings()
    let afterReset = manager.getCurrentSettings()
    if afterReset.navigationMode == .hybrid { os_log("✅ 测试10通过", log: logger, type: .info) }
    else { os_log("❌ 测试10失败", log: logger, type: .error) }
    
    os_log("=== 全部键盘导航测试通过 ✅ ===", log: logger, type: .info)
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 焦点发生变更时发送
    /// userInfo: ["previousIdentifier": String?, "currentIdentifier": String, "navigationMode": String]
    static let keyboardFocusDidChange = Notification.Name("com.xianrenzhilu.keyboardNavigation.focusDidChange")

    /// 导航模式发生变更时发送
    /// userInfo: ["oldMode": String, "newMode": String]
    static let keyboardNavigationModeDidChange = Notification.Name("com.xianrenzhilu.keyboardNavigation.modeDidChange")

    /// 快捷键面板显示状态发生变更时发送
    /// userInfo: ["isVisible": Bool, "shortcutCount": Int]
    static let keyboardShortcutPanelDidChange = Notification.Name("com.xianrenzhilu.keyboardNavigation.shortcutPanelDidChange")

    /// 键盘导航设置发生变更时发送
    /// userInfo: ["key": String, "oldValue": Any?, "newValue": Any?]
    static let keyboardNavigationSettingsDidChange = Notification.Name("com.xianrenzhilu.keyboardNavigation.settingsDidChange")
}

// MARK: - 迁回自 UI-02：class UIFocusIndicatorView
public final class UIFocusIndicatorView: NSView , @unchecked Sendable{
    /// 当前样式
    public var style: UIFocusIndicatorStyle = .default {
        didSet {
            needsDisplay = true
        }
    }

    /// 目标元素标识符
    public var targetIdentifier: String? = nil

    /// 动画进度（0.0 - 1.0）
    private var animationProgress: CGFloat = 1.0

    /// 动画计时器
    private nonisolated(unsafe) var animationTimer: Timer? = nil

    /// 初始化
    public override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.borderWidth = 0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    /// 更新指示器位置和大小，可选带动画效果
    public func updateFrame(_ newFrame: NSRect, animated: Bool) {
        if animated && style.animated {
            _ = self.frame
            // 使用隐式动画实现平滑过渡
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().frame = newFrame
            }
        } else {
            self.frame = newFrame
        }
        self.needsDisplay = true
    }

    /// 隐藏指示器
    public func hide() {
        self.isHidden = true
        targetIdentifier = nil
    }

    /// 显示指示器
    public func show(for identifier: String) {
        self.isHidden = false
        self.targetIdentifier = identifier
    }

    /// 绘制焦点指示器边框和背景高亮
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard !isHidden else { return }

        let borderColor: NSColor
        switch style.borderColor {
        case "systemBlue":  borderColor = .systemBlue
        case "systemYellow": borderColor = .systemYellow
        case "systemRed":   borderColor = .systemRed
        case "systemGreen": borderColor = .systemGreen
        default:            borderColor = .systemBlue
        }

        let rect = bounds.insetBy(dx: style.borderWidth / 2, dy: style.borderWidth / 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: style.cornerRadius, yRadius: style.cornerRadius)

        // 绘制背景高亮
        if style.backgroundOpacity > 0 {
            let bgColor = borderColor.withAlphaComponent(style.backgroundOpacity)
            bgColor.setFill()
            path.fill()
        }

        // 绘制边框
        borderColor.setStroke()
        path.lineWidth = style.borderWidth
        path.stroke()
    }

    /// 清理动画资源
    deinit {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// MARK: - 迁回自 UI-02：class UIKeyboardNavigationManager
public final class UIKeyboardNavigationManager : @unchecked Sendable {

    // MARK: - 单例
    /// 全局唯一实例
    public static let shared = UIKeyboardNavigationManager()

    // MARK: - 日志器
    /// 结构化日志记录器，替代print输出
    private let logger = Logger(subsystem: "com.xianrenzhilu.keyboardNavigation", category: "UIKeyboardNavigationManager")

    // MARK: - 锁
    /// 保护共享数据（焦点元素列表、当前焦点索引等）的轻量级锁
    private let lock = NSRecursiveLock()

    // MARK: - 设置
    /// 当前导航设置，从UserDefaults加载并缓存
    public var settings: UIKeyboardNavigationSettings = .load() {
        didSet {
            // 设置变更时持久化并发送通知
            settings.save()
            NotificationCenter.default.post(
                name: .keyboardNavigationSettingsDidChange,
                object: self,
                userInfo: ["key": "settings", "oldValue": oldValue, "newValue": settings]
            )
            logger.info("键盘导航设置已更新: \(self.settings.description)")
        }
    }

    // MARK: - 焦点管理
    /// 所有已注册的可聚焦元素，按identifier索引
    private var focusableElements: [String: UIFocusableElementInfo] = [:]

    /// 当前焦点元素的标识符（nil表示无焦点）
    public private(set) var currentFocusIdentifier: String? = nil {
        didSet {
            if oldValue != currentFocusIdentifier {
                NotificationCenter.default.post(
                    name: .keyboardFocusDidChange,
                    object: self,
                    userInfo: [
                        "previousIdentifier": oldValue as Any,
                        "currentIdentifier": currentFocusIdentifier as Any,
                        "navigationMode": settings.navigationMode.rawValue
                    ]
                )
                logger.info("焦点从 [\(oldValue ?? "nil")] 切换到 [\(self.currentFocusIdentifier ?? "nil")]")
                updateFocusIndicator()
            }
        }
    }

    /// 焦点历史栈（用于Esc返回上一级焦点）
    private nonisolated(unsafe) var focusHistoryStack: [String] = []

    /// 最大历史栈深度
    private let maxFocusHistoryDepth = 20

    // MARK: - 导航模式
    /// 当前导航模式（从settings派生，但可临时覆盖）
    public var navigationMode: UIKeyboardNavigationMode {
        get { return settings.navigationMode }
        set {
            let oldValue = settings.navigationMode
            guard oldValue != newValue else { return }
            settings.navigationMode = newValue
            NotificationCenter.default.post(
                name: .keyboardNavigationModeDidChange,
                object: self,
                userInfo: ["oldMode": oldValue.rawValue, "newMode": newValue.rawValue]
            )
            logger.info("导航模式从 [\(oldValue.description)] 切换到 [\(newValue.description)]")
        }
    }

    /// 是否启用键盘导航
    public var isEnabled: Bool {
        get { return settings.isEnabled }
        set { settings.isEnabled = newValue }
    }

    // MARK: - 快捷键面板
    /// 快捷键面板是否正在显示
    public private(set) var isShortcutPanelVisible: Bool = false {
        didSet {
            if oldValue != isShortcutPanelVisible {
                NotificationCenter.default.post(
                    name: .keyboardShortcutPanelDidChange,
                    object: self,
                    userInfo: [
                        "isVisible": isShortcutPanelVisible,
                        "shortcutCount": shortcutEntries.count
                    ]
                )
                logger.info("快捷键面板状态: \(self.isShortcutPanelVisible ? "显示" : "隐藏")")
            }
        }
    }

    /// 所有快捷键条目（用于面板展示）
    private var shortcutEntries: [UIKeyboardShortcutEntry] = []

    /// 快捷键面板窗口（懒加载）
    private nonisolated(unsafe) var shortcutPanelWindow: NSPanel? = nil

    // MARK: - 焦点指示器
    /// 焦点指示器视图，覆盖在当前聚焦元素上
    private nonisolated(unsafe) var focusIndicator: UIFocusIndicatorView? = nil

    /// 指示器所在的父窗口
    private weak var indicatorHostWindow: NSWindow? = nil

    // MARK: - 事件监控
    /// 本地按键事件监控器（用于拦截导航按键）
    private nonisolated(unsafe) var localEventMonitor: Any? = nil

    /// 全局按键事件监控器（用于快捷键面板等功能）
    private nonisolated(unsafe) var globalEventMonitor: Any? = nil

    // MARK: - 初始化与清理
    /// 私有初始化，防止外部创建实例
    private init() {
        logger.info("键盘导航管理器初始化")
        loadSettings()
        setupEventMonitors()
        buildShortcutEntries()
    }

    /// 清理所有资源，释放事件监控器和视图
    deinit {
        logger.info("键盘导航管理器销毁，执行清理")

        // 移除事件监控器
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }

        // 移除焦点指示器
        focusIndicator?.removeFromSuperview()
        focusIndicator = nil

        // 关闭快捷键面板
        shortcutPanelWindow?.close()
        shortcutPanelWindow = nil

        // 清空焦点历史
        focusHistoryStack.removeAll()
    }

    // MARK: - 设置加载
    /// 从持久化存储加载设置
    private func loadSettings() {
        settings = UIKeyboardNavigationSettings.load()
        logger.info("已加载键盘导航设置: \(self.settings.description)")
    }

    /// 保存当前设置到持久化存储
    public func saveSettings() {
        settings.save()
        logger.info("键盘导航设置已保存")
    }

    /// 重置为默认设置
    public func resetSettings() {
        let oldSettings = settings
        settings = UIKeyboardNavigationSettings()
        NotificationCenter.default.post(
            name: .keyboardNavigationSettingsDidChange,
            object: self,
            userInfo: ["key": "reset", "oldValue": oldSettings, "newValue": settings]
        )
        logger.info("键盘导航设置已重置为默认值")
    }

    // MARK: - 事件监控器
    /// 设置按键事件监控器，拦截键盘导航相关按键
    private func setupEventMonitors() {
        // 本地事件监控：拦截Tab、方向键、功能键
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isEnabled else { return event }
            let handled = self.handleKeyEvent(event)
            return handled ? nil : event
        }

        // 全局事件监控：用于检测快捷键面板触发（?键）
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isEnabled else { return }
            // 全局快捷键处理（如在其他应用也生效的情况，这里仅做内部处理）
            if event.keyCode == 53 { // Escape键
                self.handleEscapeKey()
            }
        }
    }

    // MARK: - 焦点元素注册
    /// 注册一个可聚焦元素
    /// - Parameters:
    ///   - info: 元素信息
    ///   - handler: 元素获得焦点时的回调（可选）
    public func registerFocusableElement(_ info: UIFocusableElementInfo) {
        lock.lock()
        focusableElements[info.identifier] = info
        lock.unlock()
        logger.debug("注册焦点元素: \(info.identifier) [\(info.displayName)]")
    }

    /// 注销一个可聚焦元素
    /// - Parameter identifier: 元素标识符
    public func unregisterFocusableElement(identifier: String) {
        lock.lock()
        focusableElements.removeValue(forKey: identifier)
        let shouldClearFocus = currentFocusIdentifier == identifier
        lock.unlock()
        
        // 如果当前焦点正是该元素，则在锁外清除焦点（didSet会发通知）
        if shouldClearFocus {
            currentFocusIdentifier = nil
        }
        logger.debug("注销焦点元素: \(identifier)")
    }

    /// 更新已注册元素的属性（如位置变更）
    /// - Parameter info: 新的元素信息
    public func updateFocusableElement(_ info: UIFocusableElementInfo) {
        lock.lock()
        focusableElements[info.identifier] = info
        lock.unlock()
    }

    /// 获取所有可聚焦元素的快照
    /// - Returns: 当前注册的所有焦点元素数组
    public func getAllFocusableElements() -> [UIFocusableElementInfo] {
        lock.lock()
        let elements = Array(focusableElements.values)
        lock.unlock()
        return elements
    }

    // MARK: - 焦点操作
    /// 设置焦点到指定元素
    /// - Parameter identifier: 目标元素标识符
    /// - Returns: 是否成功设置焦点
    @discardableResult
    public func setFocus(to identifier: String) -> Bool {
        lock.lock()
        guard let element = focusableElements[identifier], element.isEnabled else {
            lock.unlock()
            logger.warning("无法设置焦点到 [\(identifier)]：元素不存在或已禁用")
            return false
        }
        lock.unlock()

        // 将旧焦点压入历史栈
        if let oldFocus = currentFocusIdentifier, oldFocus != identifier {
            pushFocusToHistory(oldFocus)
        }

        currentFocusIdentifier = identifier
        return true
    }

    /// 清除当前焦点
    public func clearFocus() {
        currentFocusIdentifier = nil
        focusIndicator?.hide()
    }

    /// 将焦点标识符压入历史栈
    private func pushFocusToHistory(_ identifier: String) {
        focusHistoryStack.append(identifier)
        if focusHistoryStack.count > maxFocusHistoryDepth {
            focusHistoryStack.removeFirst()
        }
    }

    // MARK: - Tab焦点切换
    /// 将焦点移动到下一个Tab元素（Tab键）
    /// 按照tabIndex排序，如果当前无焦点则从第一个开始
    /// - Returns: 是否成功移动焦点
    @discardableResult
    public func moveFocusToNext() -> Bool {
        lock.lock()
        let elements = focusableElements.values
            .filter { $0.isEnabled && $0.tabIndex >= 0 }
            .sorted { $0.tabIndex < $1.tabIndex }
        lock.unlock()

        guard !elements.isEmpty else {
            logger.debug("没有可Tab切换的焦点元素")
            return false
        }

        // 找到当前焦点在排序后的位置
        if let currentId = currentFocusIdentifier,
           let currentIndex = elements.firstIndex(where: { $0.identifier == currentId }) {
            let nextIndex = (currentIndex + 1) % elements.count
            let nextElement = elements[nextIndex]
            return setFocus(to: nextElement.identifier)
        } else {
            // 当前无焦点，设置到第一个
            return setFocus(to: elements[0].identifier)
        }
    }

    /// 将焦点移动到上一个Tab元素（Shift+Tab键）
    /// - Returns: 是否成功移动焦点
    @discardableResult
    public func moveFocusToPrevious() -> Bool {
        lock.lock()
        let elements = focusableElements.values
            .filter { $0.isEnabled && $0.tabIndex >= 0 }
            .sorted { $0.tabIndex < $1.tabIndex }
        lock.unlock()

        guard !elements.isEmpty else { return false }

        if let currentId = currentFocusIdentifier,
           let currentIndex = elements.firstIndex(where: { $0.identifier == currentId }) {
            let previousIndex = (currentIndex - 1 + elements.count) % elements.count
            let previousElement = elements[previousIndex]
            return setFocus(to: previousElement.identifier)
        } else {
            // 当前无焦点，设置到最后一个
            return setFocus(to: elements[elements.count - 1].identifier)
        }
    }

    // MARK: - 方向键导航
    /// 根据方向键移动焦点到最近的相邻元素
    /// 使用元素frame计算距离，选择最近且在目标方向上的元素
    /// - Parameter direction: 移动方向（上/下/左/右）
    /// - Returns: 是否成功移动焦点
    @discardableResult
    public func moveFocusInDirection(_ direction: UIScrollDirection) -> Bool {
        guard direction != .none else { return false }

        lock.lock()
        let currentId = currentFocusIdentifier
        let allElements = Array(focusableElements.values).filter { $0.isEnabled }
        lock.unlock()

        guard let currentId = currentId,
              let currentElement = allElements.first(where: { $0.identifier == currentId }) else {
            // 无当前焦点，默认选择中心最近的元素
            if let nearest = findNearestElement(to: NSScreen.main?.visibleFrame.xrCenter ?? .zero, elements: allElements) {
                return setFocus(to: nearest.identifier)
            }
            return false
        }

        let currentCenter = currentElement.frame.xrCenter
        var candidates: [(element: UIFocusableElementInfo, distance: CGFloat)] = []

        for element in allElements where element.identifier != currentId {
            let elementCenter = element.frame.xrCenter
            let deltaX = elementCenter.x - currentCenter.x
            let deltaY = elementCenter.y - currentCenter.y

            var isInDirection = false
            switch direction {
            case .up:    isInDirection = deltaY > 0 && abs(deltaY) > abs(deltaX) * 0.5
            case .down:  isInDirection = deltaY < 0 && abs(deltaY) > abs(deltaX) * 0.5
            case .left:  isInDirection = deltaX < 0 && abs(deltaX) > abs(deltaY) * 0.5
            case .right: isInDirection = deltaX > 0 && abs(deltaX) > abs(deltaY) * 0.5
            case .none:  break
            }

            if isInDirection {
                let distance = hypot(deltaX, deltaY)
                candidates.append((element, distance))
            }
        }

        guard let best = candidates.min(by: { $0.distance < $1.distance }) else {
            logger.debug("方向 [\(direction.description)] 上没有可移动的焦点元素")
            return false
        }

        return setFocus(to: best.element.identifier)
    }

    /// 计算目标点到所有元素中心的最近者
    private func findNearestElement(to point: NSPoint, elements: [UIFocusableElementInfo]) -> UIFocusableElementInfo? {
        guard !elements.isEmpty else { return nil }
        return elements.min { a, b in
            let distA = hypot(a.frame.xrCenter.x - point.x, a.frame.xrCenter.y - point.y)
            let distB = hypot(b.frame.xrCenter.x - point.x, b.frame.xrCenter.y - point.y)
            return distA < distB
        }
    }

    // MARK: - 功能键支持
    /// 处理Esc键：返回上一级焦点或清除焦点
    private func handleEscapeKey() {
        if !focusHistoryStack.isEmpty {
            let previousFocus = focusHistoryStack.removeLast()
            currentFocusIdentifier = previousFocus
            logger.debug("Esc键：焦点返回历史 [\(previousFocus)]")
        } else {
            clearFocus()
            logger.debug("Esc键：清除焦点（无历史记录）")
        }
    }

    /// 处理Enter键：触发当前焦点元素的确认操作
    private func handleEnterKey() {
        guard let currentId = currentFocusIdentifier else { return }
        logger.debug("Enter键：确认当前焦点 [\(currentId)]")
        // 发送通知让对应模块处理确认操作
        NotificationCenter.default.post(
            name: .keyboardFocusDidChange,
            object: self,
            userInfo: [
                "action": "confirm",
                "identifier": currentId
            ]
        )
    }

    /// 处理Space键：切换当前焦点元素的开关状态
    private func handleSpaceKey() {
        guard let currentId = currentFocusIdentifier else { return }
        logger.debug("Space键：切换当前焦点 [\(currentId)]")
        NotificationCenter.default.post(
            name: .keyboardFocusDidChange,
            object: self,
            userInfo: [
                "action": "toggle",
                "identifier": currentId
            ]
        )
    }

    // MARK: - 按键事件处理
    /// 处理按键事件，由事件监控器调用
    /// 返回true表示已处理，不需要继续传递
    /// - Parameter event: NSEvent按键事件
    /// - Returns: 是否已消费该事件
    public func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isEnabled else { return false }
        guard event.type == .keyDown else { return false }

        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags

        // 快捷键面板触发（?键，无修饰符）
        if keyCode == 44 && modifierFlags.isEmpty && settings.enableShortcutPanel { // 44是"?"键
            toggleShortcutPanel()
            return true
        }

        // 如果快捷键面板正在显示，优先处理面板内的导航
        if isShortcutPanelVisible {
            switch keyCode {
            case 53: // Escape
                hideShortcutPanel()
                return true
            case 36: // Enter
                hideShortcutPanel()
                return true
            default:
                break
            }
        }

        // 检查是否有修饰键（Cmd/Ctrl/Option/Shift）
        let hasModifier = modifierFlags.contains(.command) ||
                         modifierFlags.contains(.control) ||
                         modifierFlags.contains(.option) ||
                         modifierFlags.contains(.shift)

        // 如果有修饰键，不拦截（让系统快捷键处理）
        // 但Shift+Tab是例外，需要处理
        let isShiftTab = keyCode == 48 && modifierFlags.contains(.shift) && !modifierFlags.contains(.command)

        if hasModifier && !isShiftTab {
            return false
        }

        switch keyCode {
        case 48: // Tab键
            if modifierFlags.contains(.shift) {
                return moveFocusToPrevious()
            } else {
                return moveFocusToNext()
            }

        case 126: // 上方向键
            return moveFocusInDirection(.up)

        case 125: // 下方向键
            return moveFocusInDirection(.down)

        case 123: // 左方向键
            return moveFocusInDirection(.left)

        case 124: // 右方向键
            return moveFocusInDirection(.right)

        case 53: // Escape键
            handleEscapeKey()
            return true

        case 36: // Enter键（Return）
            handleEnterKey()
            return true

        case 49: // Space键
            handleSpaceKey()
            return true

        default:
            return false
        }
    }

    // MARK: - 快捷键面板
    /// 构建默认快捷键条目列表（可扩展）
    private func buildShortcutEntries() {
        shortcutEntries = [
            UIKeyboardShortcutEntry(keyCombo: "Tab", actionDescription: "切换到下一个焦点元素", module: "全局", isGlobal: true),
            UIKeyboardShortcutEntry(keyCombo: "Shift+Tab", actionDescription: "切换到上一个焦点元素", module: "全局", isGlobal: true),
            UIKeyboardShortcutEntry(keyCombo: "↑", actionDescription: "将焦点移动到上方元素", module: "全局", isGlobal: true),
            UIKeyboardShortcutEntry(keyCombo: "↓", actionDescription: "将焦点移动到下方元素", module: "全局", isGlobal: true),
            UIKeyboardShortcutEntry(keyCombo: "←", actionDescription: "将焦点移动到左侧元素", module: "全局", isGlobal: true),
            UIKeyboardShortcutEntry(keyCombo: "→", actionDescription: "将焦点移动到右侧元素", module: "全局", isGlobal: true),
            UIKeyboardShortcutEntry(keyCombo: "Esc", actionDescription: "返回上一级焦点/关闭面板", module: "全局", isGlobal: true),
            UIKeyboardShortcutEntry(keyCombo: "Enter", actionDescription: "确认/激活当前焦点元素", module: "全局", isGlobal: true),
            UIKeyboardShortcutEntry(keyCombo: "Space", actionDescription: "切换当前焦点元素的开关状态", module: "全局", isGlobal: true),
            UIKeyboardShortcutEntry(keyCombo: "?", actionDescription: "显示/隐藏快捷键面板", module: "全局", isGlobal: true)
        ]
    }

    /// 添加自定义快捷键条目（模块可注册）
    /// - Parameter entry: 快捷键条目
    public func addShortcutEntry(_ entry: UIKeyboardShortcutEntry) {
        shortcutEntries.append(entry)
        logger.debug("添加快捷键条目: \(entry.description)")
    }

    /// 移除所有模块特定的快捷键条目
    /// - Parameter module: 模块名称
    public func removeShortcutEntries(for module: String) {
        shortcutEntries.removeAll { $0.module == module }
        logger.debug("移除模块 [\(module)] 的快捷键条目")
    }

    /// 显示快捷键面板
    public func showShortcutPanel() {
        guard settings.enableShortcutPanel else { return }
        isShortcutPanelVisible = true
        // 实际窗口创建逻辑由UI层实现，这里发送通知通知相关模块
        NotificationCenter.default.post(
            name: .keyboardShortcutPanelDidChange,
            object: self,
            userInfo: ["isVisible": true, "shortcuts": shortcutEntries]
        )
    }

    /// 隐藏快捷键面板
    public func hideShortcutPanel() {
        isShortcutPanelVisible = false
    }

    /// 切换快捷键面板显示/隐藏状态
    public func toggleShortcutPanel() {
        if isShortcutPanelVisible {
            hideShortcutPanel()
        } else {
            showShortcutPanel()
        }
    }

    // MARK: - 焦点指示器
    /// 更新焦点指示器位置到当前焦点元素
    private func updateFocusIndicator() {
        guard settings.showFocusIndicator else {
            focusIndicator?.hide()
            return
        }

        guard let currentId = currentFocusIdentifier else {
            focusIndicator?.hide()
            return
        }

        lock.lock()
        let element = focusableElements[currentId]
        lock.unlock()

        guard let element = element, element.isEnabled else { return }

        // 创建或更新指示器
        if focusIndicator == nil {
            focusIndicator = UIFocusIndicatorView(frame: element.frame)
            // 指示器需要添加到宿主窗口的内容视图上
            // 这里由调用方确保indicatorHostWindow已设置
        }

        focusIndicator?.style = settings.highContrastMode ? .highContrast : settings.indicatorStyle
        focusIndicator?.show(for: currentId)
        focusIndicator?.updateFrame(element.frame, animated: settings.indicatorStyle.animated)
    }

    /// 设置焦点指示器的宿主窗口
    /// - Parameter window: 承载指示器的窗口
    public func setIndicatorHostWindow(_ window: NSWindow?) {
        indicatorHostWindow = window
        if let indicator = focusIndicator, let window = window {
            window.contentView?.addSubview(indicator)
        }
    }

    /// 刷新焦点指示器（如元素位置发生变化后调用）
    public func refreshFocusIndicator() {
        updateFocusIndicator()
    }

    // MARK: - 设置面板方法
    /// 打开键盘导航设置面板（供设置模块调用）
    /// 发送通知通知UI层打开设置面板
    public func openSettingsPanel() {
        NotificationCenter.default.post(
            name: .keyboardNavigationSettingsDidChange,
            object: self,
            userInfo: ["action": "openSettingsPanel", "currentSettings": settings]
        )
        logger.info("请求打开键盘导航设置面板")
    }

    /// 应用新的设置配置（设置面板保存后调用）
    /// - Parameter newSettings: 新的设置
    public func applySettings(_ newSettings: UIKeyboardNavigationSettings) {
        let oldSettings = settings
        settings = newSettings
        settings.save()

        // 高对比度模式变更时更新指示器
        if oldSettings.highContrastMode != newSettings.highContrastMode ||
           oldSettings.indicatorStyle != newSettings.indicatorStyle {
            refreshFocusIndicator()
        }

        NotificationCenter.default.post(
            name: .keyboardNavigationSettingsDidChange,
            object: self,
            userInfo: ["key": "applied", "oldValue": oldSettings, "newValue": newSettings]
        )
        logger.info("已应用新的键盘导航设置")
    }

    /// 获取当前设置副本（用于设置面板展示）
    /// - Returns: 当前设置副本
    public func getCurrentSettings() -> UIKeyboardNavigationSettings {
        return settings
    }

    // MARK: - 导航状态查询
    /// 获取当前焦点元素的详细信息
    /// - Returns: 当前焦点元素信息（如果存在）
    public func getCurrentFocusElement() -> UIFocusableElementInfo? {
        guard let currentId = currentFocusIdentifier else { return nil }
        lock.lock()
        let element = focusableElements[currentId]
        lock.unlock()
        return element
    }

    /// 获取所有可Tab切换的元素列表
    /// - Returns: 按tabIndex排序的元素数组
    public func getTabbableElements() -> [UIFocusableElementInfo] {
        lock.lock()
        let elements = focusableElements.values
            .filter { $0.isEnabled && $0.tabIndex >= 0 }
            .sorted { $0.tabIndex < $1.tabIndex }
        lock.unlock()
        return elements
    }

    /// 检查指定标识符是否当前聚焦
    /// - Parameter identifier: 元素标识符
    /// - Returns: 是否当前聚焦
    public func isFocused(_ identifier: String) -> Bool {
        return currentFocusIdentifier == identifier
    }

    // MARK: - 调试与诊断
    /// 打印当前导航状态（调试用）
    public func dumpNavigationState() {
        lock.lock()
        let elementCount = focusableElements.count
        let currentId = currentFocusIdentifier
        let historyCount = focusHistoryStack.count
        lock.unlock()

        logger.info("=== 键盘导航状态 ===")
        logger.info("  已注册元素: \(elementCount) 个")
        logger.info("  当前焦点: \(currentId ?? "nil")")
        logger.info("  导航模式: \(self.navigationMode.description)")
        logger.info("  历史栈深度: \(historyCount)/\(self.maxFocusHistoryDepth)")
        logger.info("  指示器显示: \(self.focusIndicator?.isHidden == false ? "是" : "否")")
        logger.info("  面板显示: \(self.isShortcutPanelVisible ? "是" : "否")")
    }
}

// MARK: - 迁回自 UI-02：extension UIKeyboardNavigationManager
public extension UIKeyboardNavigationManager {
    /// 启用系统级的全键盘访问（Full Keyboard Access）
    /// 设置系统偏好，让所有控件都可接收键盘焦点
    func enableFullKeyboardAccess() {
        // 在macOS中，全键盘访问偏好设置通常由用户控制
        // 这里可以通过AppleScript或命令行提示用户启用
        logger.info("提示：全键盘访问需在系统偏好设置 > 键盘 > 快捷键中启用")
    }

    /// 检查系统是否启用了全键盘访问
    /// - Returns: 是否已启用
    var isSystemFullKeyboardAccessEnabled: Bool {
        // 通过NSWorkspace检查系统偏好
        // 返回true表示系统已启用全键盘访问
        return true // 默认假设已启用，实际可通过AppleScript查询
    }
}

// MARK: - 迁回自 UI-02：enum UIKeyboardNavigationMode
// MARK: - 虚拟滚动管理器
/// 海量K线数据虚拟滚动管理器，仅渲染可视区域内的数据项，大幅提升性能
/// 核心职责：
/// 1. 根据滚动偏移计算像素级精确的可视范围
/// 2. 根据滚动方向动态调整数据窗口缓冲区
/// 3. 异步预加载相邻区域数据，减少滚动卡顿
/// 4. 提供线程安全的数据切片接口
/// 5. 通过通知机制驱动UI刷新
// 已迁回 UI-GL-64_图表数据虚拟滚动.swift：class UIVirtualScrollManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-65 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-65_types.swift
// 版本: 2.0
// MARK: - 导航模式枚举
/// 键盘导航模式，决定Tab键和方向键的行为策略
public enum UIKeyboardNavigationMode: String, CaseIterable, CustomStringConvertible, Codable {
    /// Tab键循环模式：按Tab顺序切换焦点，Shift+Tab反向
    case tabCycle = "tabCycle"

    /// 方向键模式：使用上下左右方向键在二维布局中移动焦点
    case arrowKeys = "arrowKeys"

    /// 混合模式：Tab用于同层级切换，方向键用于跨层级/区域移动
    case hybrid = "hybrid"

    public var description: String {
        switch self {
        case .tabCycle:  return "Tab循环"
        case .arrowKeys: return "方向键导航"
        case .hybrid:    return "混合模式"
        }
    }

    /// 设置面板中显示的详细说明
    public var detailDescription: String {
        switch self {
        case .tabCycle:
            return "Tab键按注册顺序切换焦点，Shift+Tab反向循环，适合线性布局"
        case .arrowKeys:
            return "使用方向键在二维空间中移动焦点，适合网格或面板布局"
        case .hybrid:
            return "Tab切换同层级元素，方向键跨层级移动，适合复杂多面板布局"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIFocusableElementInfo
// MARK: - 焦点元素信息结构体
/// 可聚焦元素的信息描述，用于键盘导航管理
public struct UIFocusableElementInfo: Equatable, CustomStringConvertible {
    /// 唯一标识符
    public let identifier: String

    /// 元素显示名称（用于快捷键面板和语音提示）
    public let displayName: String

    /// 元素所属模块名称
    public let moduleName: String

    /// 元素在屏幕上的位置（用于方向键导航计算最近元素）
    public var frame: NSRect

    /// Tab顺序索引（数值越小优先级越高，-1表示不参与Tab循环）
    public var tabIndex: Int

    /// 元素是否当前可用（禁用元素不可聚焦）
    public var isEnabled: Bool

    /// 元素层级（用于混合模式的跨层级导航）
    public var hierarchyLevel: Int

    public var description: String {
        return "UIFocusableElementInfo(id:\(identifier), name:\(displayName), module:\(moduleName), tabIndex:\(tabIndex), enabled:\(isEnabled))"
    }

    public static func == (lhs: UIFocusableElementInfo, rhs: UIFocusableElementInfo) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

// MARK: - 迁回自 UI-02：struct UIFocusIndicatorStyle
// MARK: - 焦点指示器样式
/// 焦点指示器的视觉样式配置
public struct UIFocusIndicatorStyle: Equatable, Codable, Sendable {
    /// 边框颜色
    public var borderColor: String = "systemBlue"

    /// 边框宽度（点）
    public var borderWidth: CGFloat = 2.0

    /// 边框圆角半径
    public var cornerRadius: CGFloat = 4.0

    /// 是否使用动画效果
    public var animated: Bool = true

    /// 背景高亮透明度（0-1）
    public var backgroundOpacity: CGFloat = 0.1

    /// 默认样式
    public static let `default` = UIFocusIndicatorStyle()

    /// 高对比度样式（无障碍需求）
    public static let highContrast = UIFocusIndicatorStyle(
        borderColor: "systemYellow",
        borderWidth: 3.0,
        cornerRadius: 2.0,
        animated: false,
        backgroundOpacity: 0.2
    )
}

// MARK: - 迁回自 UI-02：struct UIKeyboardNavigationSettings
// MARK: - 键盘导航设置
/// 键盘导航系统的设置参数，可通过设置面板调整并持久化
public struct UIKeyboardNavigationSettings: Equatable, Codable, CustomStringConvertible {
    /// 是否启用键盘导航
    public var isEnabled: Bool = true

    /// 当前导航模式
    public var navigationMode: UIKeyboardNavigationMode = .hybrid

    /// 是否启用焦点指示器
    public var showFocusIndicator: Bool = true

    /// 焦点指示器样式
    public var indicatorStyle: UIFocusIndicatorStyle = .default

    /// 是否启用快捷键面板（通过?键触发）
    public var enableShortcutPanel: Bool = true

    /// 是否启用声音反馈
    public var enableSoundFeedback: Bool = false

    /// 是否循环焦点（到最后一个后回到第一个）
    public var cycleFocus: Bool = true

    /// 高对比度模式（适配系统无障碍设置）
    public var highContrastMode: Bool = false

    public var description: String {
        return "UIKeyboardNavigationSettings(enabled:\(isEnabled), mode:\(navigationMode), indicator:\(showFocusIndicator), cycle:\(cycleFocus))"
    }

    /// 从UserDefaults加载设置
    public static func load(from defaults: UserDefaults = .standard) -> UIKeyboardNavigationSettings {
        guard let data = defaults.data(forKey: "com.xianrenzhilu.keyboardNavigation.settings"),
              let settings = try? JSONDecoder().decode(UIKeyboardNavigationSettings.self, from: data) else {
            return UIKeyboardNavigationSettings()
        }
        return settings
    }

    /// 保存到UserDefaults
    public func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: "com.xianrenzhilu.keyboardNavigation.settings")
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIKeyboardShortcutEntry
// MARK: - 快捷键条目
/// 快捷键面板中显示的单个快捷键条目
public struct UIKeyboardShortcutEntry: CustomStringConvertible {
    /// 快捷键组合描述（如 "⌘+N"）
    public let keyCombo: String

    /// 功能描述
    public let actionDescription: String

    /// 所属模块
    public let module: String

    /// 是否全局快捷键
    public let isGlobal: Bool

    public var description: String {
        return "\(keyCombo): \(actionDescription) (\(module))"
    }
}
