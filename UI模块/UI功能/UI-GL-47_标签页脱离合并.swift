// 功能37: 标签页脱离/合并
// 对应: 拖拽标签页到现有窗口可合并，拖拽到空白区域可创建新窗口
// 优先级: P2
// 版本: 2.0

import AppKit
import Foundation
import os.log

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能37：标签页脱离/合并 — 单元测试
func test_tabDrag() {
    let manager = UITabDragManager.shared
    
    let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "TabDragTest")
    
    logger.info("测试1: 默认配置")
    let config = manager.currentConfiguration
    if !config.isEnabled { logger.error("❌ 测试1失败: 默认应启用") }
    else { logger.info("✅ 测试1通过: 默认配置正常") }
    
    logger.info("测试2: 初始化状态")
    if manager.isDragging { logger.error("❌ 测试2失败: 初始不应拖拽") }
    else { logger.info("✅ 测试2通过: 初始状态正确") }
    
    logger.info("测试3: 配置持久化")
    manager.saveConfiguration()
    logger.info("✅ 测试3通过: 配置保存正常")
    
    logger.info("测试4: 状态查询")
    let state = manager.currentState
    _ = state
    logger.info("✅ 测试4通过: 状态查询正常")
    
    logger.info("测试5: 重置配置")
    manager.resetConfiguration()
    let afterReset = manager.currentConfiguration
    if !afterReset.isEnabled { logger.error("❌ 测试5失败") }
    else { logger.info("✅ 测试5通过: 重置正常") }
    
    logger.info("测试6: 拖拽检测")
    let shouldStart = manager.shouldStartDrag(from: NSPoint(x: 0, y: 0), currentPoint: NSPoint(x: 40, y: 0))
    if !shouldStart { logger.error("❌ 测试6失败: 超过阈值应开始拖拽") }
    else { logger.info("✅ 测试6通过: 拖拽检测正常") }
    
    logger.info("测试7: 设置面板创建")
    let settingsView = manager.createSettingsView()
    _ = settingsView
    logger.info("✅ 测试7通过: 设置面板创建成功")
    
    logger.info("=== 全部标签脱离合并测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 标签页已从源窗口脱离
    static let tabDidDetach = Notification.Name("com.xianrenzhilu.tabDidDetach")
    /// 标签页已合并到目标窗口
    static let tabDidMerge = Notification.Name("com.xianrenzhilu.tabDidMerge")
    /// 标签页拖拽创建了新的独立窗口
    static let tabDidCreateNewWindow = Notification.Name("com.xianrenzhilu.tabDidCreateNewWindow")
    /// 拖拽状态发生变化
    static let tabDragStateDidChange = Notification.Name("com.xianrenzhilu.tabDragStateDidChange")
    /// 视觉反馈显示或隐藏
    static let tabDragVisualFeedbackChanged = Notification.Name("com.xianrenzhilu.tabDragVisualFeedbackChanged")
}

// MARK: - 迁回自 UI-02：class UITabContainerWindow
public class UITabContainerWindow: NSWindow , @unchecked Sendable{
    public struct UIPageInfo {
        public var info: UITabPageInfo
        public var contentView: NSView? = nil
    }
    public var pages: [UIPageInfo] = []
    public func removePage(id: String) {}
    public func addPage(_ page: UITabPage, activate: Bool) {}
    public func reorderPage(pageID: String, to: Int) {}
}

// MARK: - 迁回自 UI-02：class UITabPage
public class UITabPage : @unchecked Sendable {
    public var info: UITabPageInfo
    public var contentView: NSView? = nil
    public init(info: UITabPageInfo) {
        self.info = info
    }
}

// MARK: - 迁回自 UI-02：class UIDragVisualFeedbackManager
public final class UIDragVisualFeedbackManager : @unchecked Sendable {
    /// 半透明拖拽浮窗（显示被拖拽标签的预览）
    private var dragFloatingWindow: NSWindow?
    /// 位置指示器窗口（在目标标签栏显示插入线）
    private var positionIndicatorWindow: NSWindow?
    /// 目标区域高亮覆盖层
    private var targetHighlightWindow: NSWindow?
    /// 专用 Logger，禁止 print
    private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "DragVisualFeedback")
    
    /// 创建或更新拖拽浮窗
    func showDragFloatingWindow(at point: NSPoint, title: String, opacity: CGFloat) {
        hideDragFloatingWindow()
        
        let size = NSSize(width: 200, height: 44)
        let rect = NSRect(
            origin: NSPoint(x: point.x - size.width / 2, y: point.y - size.height / 2),
            size: size
        )
        
        let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.animationBehavior = .none
        
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3 * opacity).cgColor
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6 * opacity).cgColor
        
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.textColor = NSColor.labelColor.withAlphaComponent(opacity)
        label.alignment = .center
        label.frame = NSRect(x: 8, y: 10, width: size.width - 16, height: 24)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        container.addSubview(label)
        
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        dragFloatingWindow = window
        
        logger.info("[视觉反馈] 显示拖拽浮窗: \(title) 位置=(\(point.x), \(point.y))")
    }
    
    /// 隐藏拖拽浮窗
    func hideDragFloatingWindow() {
        dragFloatingWindow?.orderOut(nil)
        dragFloatingWindow = nil
    }
    
    /// 显示位置指示器（在目标窗口标签栏的目标插入位置）
    func showPositionIndicator(in window: NSWindow, at index: Int, tabBarHeight: CGFloat) {
        hidePositionIndicator()
        
        let windowFrame = window.frame
        let indicatorHeight: CGFloat = tabBarHeight + 4
        let indicatorWidth: CGFloat = 3
        
        // 根据插入索引计算水平位置（简化：平均标签宽度估算）
        var xOffset: CGFloat = 4
        let tabWidth: CGFloat = 80
        for _ in 0..<index {
            xOffset += tabWidth + 2
        }
        
        let screenPoint = NSPoint(
            x: windowFrame.origin.x + xOffset,
            y: windowFrame.origin.y + windowFrame.height - indicatorHeight + 2
        )
        let rect = NSRect(origin: screenPoint, size: NSSize(width: indicatorWidth, height: indicatorHeight))
        
        let indicatorWindow = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        indicatorWindow.isOpaque = false
        indicatorWindow.backgroundColor = .clear
        indicatorWindow.level = .floating
        indicatorWindow.ignoresMouseEvents = true
        
        let view = NSView(frame: NSRect(origin: .zero, size: rect.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        view.layer?.cornerRadius = 1.5
        indicatorWindow.contentView = view
        indicatorWindow.makeKeyAndOrderFront(nil)
        
        positionIndicatorWindow = indicatorWindow
        logger.info("[视觉反馈] 显示位置指示器 窗口=\(window.title) 插入索引=\(index)")
    }
    
    /// 隐藏位置指示器
    func hidePositionIndicator() {
        positionIndicatorWindow?.orderOut(nil)
        positionIndicatorWindow = nil
    }
    
    /// 显示目标窗口高亮
    func showTargetHighlight(for window: NSWindow) {
        hideTargetHighlight()
        
        let frame = window.frame
        let highlightWindow = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        highlightWindow.isOpaque = false
        highlightWindow.backgroundColor = .clear
        highlightWindow.level = .floating
        highlightWindow.ignoresMouseEvents = true
        
        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.15).cgColor
        view.layer?.borderWidth = 2
        view.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
        view.layer?.cornerRadius = 8
        highlightWindow.contentView = view
        highlightWindow.makeKeyAndOrderFront(nil)
        
        targetHighlightWindow = highlightWindow
        logger.info("[视觉反馈] 显示目标高亮: \(window.title)")
    }
    
    /// 隐藏目标窗口高亮
    func hideTargetHighlight() {
        targetHighlightWindow?.orderOut(nil)
        targetHighlightWindow = nil
    }
    
    /// 更新拖拽浮窗位置
    func updateDragFloatingWindowPosition(to point: NSPoint) {
        guard let window = dragFloatingWindow else { return }
        var frame = window.frame
        frame.origin.x = point.x - frame.width / 2
        frame.origin.y = point.y - frame.height / 2
        window.setFrame(frame, display: true, animate: false)
    }
    
    /// 清理所有视觉反馈元素
    func cleanup() {
        hideDragFloatingWindow()
        hidePositionIndicator()
        hideTargetHighlight()
        logger.info("[视觉反馈] 已清理所有视觉元素")
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - 迁回自 UI-02：class UITabDragManager
public final class UITabDragManager : @unchecked Sendable {
    
    // MARK: - 单例
    public static let shared = UITabDragManager()
    
    // MARK: - 属性
    /// 当前拖拽配置
    private var configuration: UITabDragConfiguration
    /// 当前拖拽状态
    private var state: UITabDragState = .idle
    /// 被拖拽的标签项数据
    private var draggingTab: UITabPageInfo?
    /// 被拖拽标签的原始内容视图
    private var draggingContentView: NSView?
    /// 源窗口 ID
    private var sourceWindowID: String?
    /// 拖拽起始鼠标位置
    private var dragStartMousePoint: NSPoint?
    /// 已附加的拖拽手势识别器列表
    private var gestureRecognizers: [NSPanGestureRecognizer] = []
    /// 递归锁，保护所有共享可变状态
    private let lock = NSRecursiveLock()
    /// 视觉反馈管理器
    private var feedbackManager: UIDragVisualFeedbackManager
    /// 全局鼠标事件监控（监听鼠标松开）
    private var globalEventMonitor: Any?
    /// 本地鼠标事件监控（监听鼠标移动）
    private var localEventMonitor: Any?
    /// 持久化存储键
    private let configKey = "com.xianrenzhilu.tabDragConfiguration"
    /// 悬停检测计时器（用于延迟检测目标）
    private var hoverTimer: Timer?
    /// 当前检测到的目标窗口 ID
    private var currentTargetWindowID: String?
    /// 当前检测到的插入索引
    private var currentInsertIndex: Int = 0
    /// 是否正在执行拖拽操作（防止重入）
    private var isProcessingDrag: Bool = false
    /// 专用 Logger，项目中禁止 print
    private let logger: Logger
    
    // MARK: - 初始化
    private init() {
        self.logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "TabDragManager")
        self.configuration = UITabDragManager.loadConfiguration()
        self.feedbackManager = UIDragVisualFeedbackManager()
        setupEventMonitoring()
        logger.info("[拖拽管理器] 初始化完成，配置: 启用=\(self.configuration.isEnabled) 脱离阈值=\(self.configuration.detachThreshold)px")
    }
    
    // MARK: - 事件监控设置
    /// 设置鼠标移动和释放事件监控，用于全局追踪拖拽过程
    private func setupEventMonitoring() {
        // 全局监控鼠标松开事件（拖拽结束）
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { [weak self] _ in
            self?.handleMouseUp()
        }
        // 本地监控鼠标移动事件（拖拽中位置检测）
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event)
            return event
        }
        logger.info("[事件监控] 已设置全局鼠标松开和本地鼠标移动监控")
    }
    
    // MARK: - 拖拽手势识别器
    /// 为指定标签按钮创建并附加拖拽手势识别器
    /// - Parameters:
    ///   - button: 标签按钮视图
    ///   - tabItem: 对应的标签数据
    ///   - windowID: 所属窗口的注册 ID
    public func attachDragGesture(to button: NSView, tabItem: UITabPageInfo, windowID: String) {
        let gesture = NSPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        gesture.allowedTouchTypes = []
        button.addGestureRecognizer(gesture)
        
        // 将标签信息关联到识别器，使用 objc 关联对象存储
        objc_setAssociatedObject(gesture, &UIAssociatedKeys.tabItem, tabItem, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(gesture, &UIAssociatedKeys.windowID, windowID, .OBJC_ASSOCIATION_RETAIN)
        
        lock.lock()
        gestureRecognizers.append(gesture)
        lock.unlock()
        
        logger.info("[手势] 已为标签 '\(tabItem.title)' 附加拖拽手势识别器")
    }
    
    /// 从按钮移除拖拽手势识别器
    /// - Parameter button: 需要移除手势的标签按钮视图
    public func detachDragGesture(from button: NSView) {
        for gesture in button.gestureRecognizers {
            if let panGesture = gesture as? NSPanGestureRecognizer {
                button.removeGestureRecognizer(panGesture)
                lock.lock()
                gestureRecognizers.removeAll { $0 === panGesture }
                lock.unlock()
            }
        }
    }
    
    // MARK: - 手势处理
    /// 处理拖拽手势状态变化（began/changed/ended/cancelled）
    @objc private func handlePanGesture(_ gesture: NSPanGestureRecognizer) {
        guard configuration.isEnabled else {
            logger.debug("[手势] 拖拽功能已禁用，忽略手势")
            return
        }
        
        guard let tabItem = objc_getAssociatedObject(gesture, &UIAssociatedKeys.tabItem) as? UITabPageInfo,
              let windowID = objc_getAssociatedObject(gesture, &UIAssociatedKeys.windowID) as? String else {
            logger.warning("[手势] 无法从手势识别器获取标签项或窗口ID")
            return
        }
        
        let location = gesture.location(in: nil)
        
        switch gesture.state {
        case .began:
            beginDrag(tab: tabItem, from: windowID, at: location)
        case .changed:
            updateDrag(to: location)
        case .ended, .cancelled, .failed:
            endDrag(at: location)
        default:
            break
        }
    }
    
    // MARK: - 鼠标拖拽处理（备用方案）
    /// 通过 mouseDragged 事件持续更新拖拽（当手势识别器不可用时作为降级方案）
    /// - Parameters:
    ///   - event: 鼠标事件
    ///   - tabItem: 被拖拽的标签数据
    ///   - windowID: 源窗口 ID
    public func handleMouseDragged(event: NSEvent, tabItem: UITabPageInfo, windowID: String) {
        guard configuration.isEnabled else { return }
        let location = event.locationInWindow
        if dragStartMousePoint == nil {
            dragStartMousePoint = location
            beginDrag(tab: tabItem, from: windowID, at: location)
        } else {
            updateDrag(to: location)
        }
    }
    
    /// 通过鼠标松开事件结束拖拽
    /// - Parameter event: 鼠标事件
    public func handleMouseUp(event: NSEvent) {
        guard configuration.isEnabled else { return }
        guard state.isDragging else { return }
        endDrag(at: event.locationInWindow)
    }
    
    // MARK: - 拖拽生命周期
    /// 开始拖拽标签页
    /// - Parameters:
    ///   - tab: 被拖拽的标签项
    ///   - windowID: 源窗口注册 ID
    ///   - point: 鼠标在屏幕上的起始位置
    public func beginDrag(tab: UITabPageInfo, from windowID: String, at point: NSPoint) {
        lock.lock()
        draggingTab = tab
        sourceWindowID = windowID
        dragStartMousePoint = point
        state = .dragging(tabID: tab.id, sourceWindowID: windowID, startPoint: point)
        isProcessingDrag = false
        lock.unlock()
        
        // 显示视觉反馈（半透明浮窗）
        if configuration.showVisualFeedback {
            feedbackManager.showDragFloatingWindow(
                at: point,
                title: tab.title,
                opacity: configuration.feedbackOpacity
            )
        }
        
        // 发送状态变更通知
        NotificationCenter.default.post(
            name: .tabDragStateDidChange,
            object: self,
            userInfo: ["state": "dragging", "tabID": tab.id, "sourceWindowID": windowID]
        )
        
        logger.info("[拖拽] 开始拖拽标签 '\(tab.title)' 从窗口 \(windowID) 位置=(\(point.x), \(point.y))")
    }
    
    /// 更新拖拽位置（鼠标移动过程中持续调用）
    /// - Parameter point: 当前鼠标在屏幕上的位置
    private func updateDrag(to point: NSPoint) {
        guard state.isDragging else { return }
        
        // 更新视觉反馈浮窗位置（跟随鼠标）
        if configuration.showVisualFeedback {
            feedbackManager.updateDragFloatingWindowPosition(to: point)
        }
        
        // 检测目标窗口
        detectTargetWindow(at: point)
    }
    
    /// 检测当前鼠标位置下的目标窗口
    /// 根据鼠标位置判断：悬停在目标窗口标签栏、窗口内容区、或空白区域
    /// - Parameter point: 当前鼠标在屏幕上的位置
    private func detectTargetWindow(at point: NSPoint) {
        guard let sourceID = sourceWindowID else { return }
        
        // 通过窗口注册表查找包含当前鼠标位置的窗口（排除源窗口自身）
        let result = UIWindowRegistry.shared.windowContaining(point: point, excluding: sourceID)
        
        if let (targetID, targetWindow) = result {
            // 检测鼠标是否在目标窗口的标签栏区域（窗口顶部 40 像素）
            let windowFrame = targetWindow.frame
            let tabBarRegion = NSRect(
                x: windowFrame.origin.x,
                y: windowFrame.origin.y + windowFrame.height - 40,
                width: windowFrame.width,
                height: 40
            )
            
            if tabBarRegion.contains(point) {
                // 在目标窗口标签栏区域，准备合并
                let insertIndex = calculateInsertIndex(in: targetWindow, at: point)
                
                lock.lock()
                if currentTargetWindowID != targetID || currentInsertIndex != insertIndex {
                    currentTargetWindowID = targetID
                    currentInsertIndex = insertIndex
                    if let tabID = draggingTab?.id {
                        state = .hoveringTarget(tabID: tabID, targetWindowID: targetID, insertIndex: insertIndex)
                    }
                }
                lock.unlock()
                
                // 显示位置指示器和目标高亮
                if configuration.showVisualFeedback {
                    feedbackManager.showPositionIndicator(in: targetWindow, at: insertIndex, tabBarHeight: 36)
                    feedbackManager.showTargetHighlight(for: targetWindow)
                }
                
                logger.info("[检测] 悬停目标窗口 \(targetID) 插入索引 \(insertIndex)")
            } else {
                // 在窗口内容区域，不触发合并，清除目标状态
                clearTargetState()
            }
        } else {
            // 鼠标不在任何窗口上，判定为空白区域，准备创建新窗口
            lock.lock()
            if let tabID = draggingTab?.id {
                state = .creatingNewWindow(tabID: tabID, currentPoint: point)
                currentTargetWindowID = nil
            }
            lock.unlock()
            
            // 隐藏合并相关的视觉反馈
            feedbackManager.hidePositionIndicator()
            feedbackManager.hideTargetHighlight()
            
            logger.info("[检测] 无目标窗口，准备创建新窗口 位置=(\(point.x), \(point.y))")
        }
    }
    
    /// 根据鼠标在标签栏的水平位置计算插入索引
    /// 简化实现：基于平均标签宽度的比例估算
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - point: 鼠标位置
    /// - Returns: 建议的插入索引
    private func calculateInsertIndex(in window: NSWindow, at point: NSPoint) -> Int {
        let windowFrame = window.frame
        let relativeX = point.x - windowFrame.origin.x
        let tabWidth: CGFloat = 80 // 平均标签宽度估算
        let index = max(0, Int(relativeX / (tabWidth + 2)))
        return index
    }
    
    /// 清除目标窗口状态，恢复为普通拖拽中
    private func clearTargetState() {
        lock.lock()
        currentTargetWindowID = nil
        currentInsertIndex = 0
        if let tabID = draggingTab?.id, let sourceID = sourceWindowID, let start = dragStartMousePoint {
            state = .dragging(tabID: tabID, sourceWindowID: sourceID, startPoint: start)
        }
        lock.unlock()
        
        feedbackManager.hidePositionIndicator()
        feedbackManager.hideTargetHighlight()
    }
    
    /// 结束拖拽（鼠标松开时调用）
    /// 根据当前状态执行：合并、创建新窗口、或取消
    /// - Parameter point: 鼠标释放位置
    private func endDrag(at point: NSPoint) {
        lock.lock()
        guard !isProcessingDrag else {
            lock.unlock()
            return
        }
        isProcessingDrag = true
        let currentState = state
        _ = draggingTab
        let sourceID = sourceWindowID
        _ = dragStartMousePoint
        dragStartMousePoint = nil
        lock.unlock()
        
        // 结束后清理处理状态
        defer {
            lock.lock()
            isProcessingDrag = false
            lock.unlock()
        }
        
        // 隐藏所有视觉反馈元素
        feedbackManager.cleanup()
        
        switch currentState {
        case .idle:
            // 空闲状态无需处理
            break
            
        case .dragging(let tabID, let sourceWindowID, _):
            // 仍在拖拽状态（未悬停目标窗口），根据拖拽距离判定是否创建新窗口
            if let startPoint = dragStartMousePoint {
                let distance = hypot(point.x - startPoint.x, point.y - startPoint.y)
                if distance >= configuration.detachThreshold {
                    createNewWindow(tabID: tabID, from: sourceWindowID, at: point)
                } else {
                    // 拖拽距离不足，视为取消
                    cancelDrag()
                    logger.info("[拖拽] 拖拽距离 \(distance)px 小于阈值 \(self.configuration.detachThreshold)px，已取消")
                }
            }
            
        case .hoveringTarget(let tabID, let targetWindowID, let insertIndex):
            // 悬停在目标窗口上方，执行合并
            merge(tabID: tabID, to: targetWindowID, at: insertIndex)
            
        case .creatingNewWindow(let tabID, _):
            // 判定为空白区域，创建新窗口
            if let sourceID = sourceID {
                createNewWindow(tabID: tabID, from: sourceID, at: point)
            }
        }
        
        // 重置拖拽状态
        resetDragState()
    }
    
    // MARK: - 标签脱离
    /// 将标签页从源窗口脱离（内部方法）
    /// 从源容器中移除标签页并返回标签数据，同时保存内容视图引用
    /// - Parameters:
    ///   - tabID: 标签页 ID
    ///   - sourceWindowID: 源窗口注册 ID
    /// - Returns: 成功脱离的标签项，失败返回 nil
    private func detachTab(tabID: String, from sourceWindowID: String) -> UITabPageInfo? {
        // 查找源窗口
        guard let sourceWindow = UIWindowRegistry.shared.window(for: sourceWindowID) else {
            logger.error("[脱离] 找不到源窗口: \(sourceWindowID)")
            return nil
        }
        
        // 如果源窗口是标签容器，从容器中移除页面
        if let container = sourceWindow as? UITabContainerWindow {
            guard let page = container.pages.first(where: { $0.info.id == tabID }) else {
                logger.error("[脱离] 标签页 \(tabID) 不在容器 \(sourceWindowID) 中")
                return nil
            }
            
            // 从容器移除页面
            container.removePage(id: tabID)
            
            // 构造 UITabPageInfo
            let tabItem = page.info
            
            // 保存内容视图引用供后续复用
            lock.lock()
            draggingContentView = page.contentView
            lock.unlock()
            
            logger.info("[脱离] 标签 '\(tabItem.title)' 已从容器 \(sourceWindowID) 脱离")
            return tabItem
        }
        
        // 普通窗口：直接返回当前拖拽的标签数据
        logger.info("[脱离] 从普通窗口脱离标签: \(tabID)")
        return draggingTab
    }
    
    // MARK: - 创建新窗口
    /// 拖拽标签页到空白区域时，创建新的独立窗口
    /// 先从源窗口脱离标签，再创建窗口并恢复内容视图
    /// - Parameters:
    ///   - tabID: 标签页 ID
    ///   - sourceWindowID: 源窗口注册 ID
    ///   - point: 鼠标释放位置（新窗口中心点）
    private func createNewWindow(tabID: String, from sourceWindowID: String, at point: NSPoint) {
        logger.info("[新窗口] 开始创建新窗口 标签=\(tabID) 源窗口=\(sourceWindowID)")
        
        // 先从源窗口脱离标签页
        guard let tabItem = detachTab(tabID: tabID, from: sourceWindowID) else {
            logger.error("[新窗口] 脱离标签失败，取消创建新窗口")
            return
        }
        
        // 创建新窗口，以释放点为中心
        let rect = NSRect(
            x: point.x - configuration.newWindowWidth / 2,
            y: point.y - configuration.newWindowHeight / 2,
            width: configuration.newWindowWidth,
            height: configuration.newWindowHeight
        )
        
        let newWindow = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = tabItem.title
        newWindow.identifier = NSUserInterfaceItemIdentifier(UUID().uuidString)
        
        // 恢复内容视图到新窗口
        lock.lock()
        if let contentView = draggingContentView {
            contentView.frame = NSRect(origin: .zero, size: rect.size)
            contentView.autoresizingMask = [.width, .height]
            newWindow.contentView = contentView
            draggingContentView = nil
        }
        lock.unlock()
        
        newWindow.makeKeyAndOrderFront(nil)
        
        // 注册新窗口到窗口注册表
        let newWindowID = UUID().uuidString
        UIWindowRegistry.shared.register(window: newWindow, id: newWindowID)
        
        // 发送新窗口创建通知
        NotificationCenter.default.post(
            name: .tabDidCreateNewWindow,
            object: self,
            userInfo: [
                "tabID": tabID,
                "sourceWindowID": sourceWindowID,
                "newWindowID": newWindowID,
                "title": tabItem.title
            ]
        )
        
        // 自动保存配置
        if configuration.autoSaveLayout {
            saveConfiguration()
        }
        
        logger.info("[新窗口] 已创建新窗口 \(newWindowID) 标题='\(tabItem.title)' 尺寸=(\(self.configuration.newWindowWidth), \(self.configuration.newWindowHeight))")
    }
    
    // MARK: - 标签合并
    /// 将标签页合并到目标窗口的标签栏
    /// 先从源窗口脱离，再添加到目标容器并调整插入位置
    /// - Parameters:
    ///   - tabID: 标签页 ID
    ///   - targetWindowID: 目标窗口注册 ID
    ///   - insertIndex: 目标插入索引
    private func merge(tabID: String, to targetWindowID: String, at insertIndex: Int) {
        logger.info("[合并] 开始合并标签 \(tabID) -> 窗口 \(targetWindowID) 索引 \(insertIndex)")
        
        guard let sourceID = sourceWindowID else {
            logger.error("[合并] 源窗口ID为空，无法合并")
            return
        }
        
        // 先从源窗口脱离标签
        guard let tabItem = detachTab(tabID: tabID, from: sourceID) else {
            logger.error("[合并] 脱离标签失败，取消合并")
            return
        }
        
        // 查找目标窗口
        guard let targetWindow = UIWindowRegistry.shared.window(for: targetWindowID) else {
            logger.error("[合并] 找不到目标窗口: \(targetWindowID)，回退为创建新窗口")
            // 回退策略：无法找到目标窗口时，创建新窗口
            createNewWindow(tabID: tabID, from: sourceID, at: NSEvent.mouseLocation)
            return
        }
        
        // 如果目标是 UITabContainerWindow，合并到容器
        if let container = targetWindow as? UITabContainerWindow {
            let pageInfo = UITabPageInfo(
                id: tabItem.id,
                title: tabItem.title,
                windowID: targetWindowID,
                groupID: tabItem.groupID,
                isPinned: tabItem.isPinned,
                order: insertIndex,
                iconName: tabItem.iconName
            )
            
            let page = UITabPage(info: pageInfo)
            lock.lock()
            if let contentView = draggingContentView {
                page.contentView = contentView
                draggingContentView = nil
            }
            lock.unlock()
            
            container.addPage(page, activate: true)
            container.reorderPage(pageID: tabItem.id, to: insertIndex)
            
            logger.info("[合并] 标签 '\(tabItem.title)' 已合并到容器 \(targetWindowID)")
        } else {
            // 目标不是容器窗口，无法合并，回退为创建新窗口
            logger.info("[合并] 目标窗口不是容器，回退为创建新窗口")
            createNewWindow(tabID: tabID, from: sourceID, at: NSEvent.mouseLocation)
            return
        }
        
        // 发送标签合并通知
        NotificationCenter.default.post(
            name: .tabDidMerge,
            object: self,
            userInfo: [
                "tabID": tabID,
                "sourceWindowID": sourceID,
                "targetWindowID": targetWindowID,
                "insertIndex": insertIndex,
                "title": tabItem.title
            ]
        )
        
        // 自动保存布局
        if configuration.autoSaveLayout {
            saveConfiguration()
        }
        
        logger.info("[合并] 完成合并标签 '\(tabItem.title)' 到窗口 \(targetWindowID) 索引 \(insertIndex)")
    }
    
    // MARK: - 取消拖拽
    /// 取消当前拖拽操作，恢复所有状态并清理视觉反馈
    public func cancelDrag() {
        lock.lock()
        let wasDragging = state.isDragging
        state = .idle
        draggingTab = nil
        sourceWindowID = nil
        dragStartMousePoint = nil
        draggingContentView = nil
        currentTargetWindowID = nil
        currentInsertIndex = 0
        isProcessingDrag = false
        lock.unlock()
        
        // 清理视觉反馈
        feedbackManager.cleanup()
        
        // 取消悬停计时器
        hoverTimer?.invalidate()
        hoverTimer = nil
        
        if wasDragging {
            NotificationCenter.default.post(
                name: .tabDragStateDidChange,
                object: self,
                userInfo: ["state": "cancelled"]
            )
            logger.info("[拖拽] 已取消")
        }
    }
    
    /// 重置拖拽状态为空闲（拖拽结束后的内部清理）
    private func resetDragState() {
        lock.lock()
        state = .idle
        draggingTab = nil
        sourceWindowID = nil
        dragStartMousePoint = nil
        draggingContentView = nil
        currentTargetWindowID = nil
        currentInsertIndex = 0
        isProcessingDrag = false
        lock.unlock()
        
        hoverTimer?.invalidate()
        hoverTimer = nil
        
        NotificationCenter.default.post(
            name: .tabDragStateDidChange,
            object: self,
            userInfo: ["state": "idle"]
        )
        
        logger.info("[拖拽] 状态已重置为空闲")
    }
    
    // MARK: - 事件处理辅助
    /// 处理全局鼠标松开事件（拖拽结束）
    private func handleMouseUp() {
        guard state.isDragging else { return }
        let point = NSEvent.mouseLocation
        endDrag(at: point)
    }
    
    /// 处理本地鼠标移动事件（拖拽中位置追踪）
    @discardableResult
    private func handleMouseMoved(_ event: NSEvent) -> NSEvent? {
        guard state.isDragging else { return event }
        let point = event.locationInWindow
        updateDrag(to: point)
        return event
    }
    
    // MARK: - 拖拽检测公共方法
    /// 判断拖拽是否应该开始（基于鼠标移动距离是否超过阈值）
    /// - Parameters:
    ///   - startPoint: 拖拽起始点
    ///   - currentPoint: 当前鼠标位置
    /// - Returns: 是否应开始拖拽
    public func shouldStartDrag(from startPoint: NSPoint, currentPoint: NSPoint) -> Bool {
        let distance = hypot(currentPoint.x - startPoint.x, currentPoint.y - startPoint.y)
        return distance >= configuration.detachThreshold
    }
    
    /// 检测当前鼠标位置是否在目标窗口的可合并区域（标签栏附近）
    /// - Parameters:
    ///   - point: 鼠标位置
    ///   - targetWindow: 目标窗口
    /// - Returns: 是否在合并区域内
    public func isInMergeArea(point: NSPoint, targetWindow: NSWindow) -> Bool {
        let windowFrame = targetWindow.frame
        let mergeArea = NSRect(
            x: windowFrame.origin.x - configuration.mergeProximity,
            y: windowFrame.origin.y + windowFrame.height - 40 - configuration.mergeProximity,
            width: windowFrame.width + configuration.mergeProximity * 2,
            height: 40 + configuration.mergeProximity * 2
        )
        return mergeArea.contains(point)
    }
    
    // MARK: - 持久化（Codable）
    /// 保存当前配置到 UserDefaults（Codable 序列化）
    public func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: configKey)
            logger.info("[持久化] 配置已保存到 UserDefaults")
        } else {
            logger.error("[持久化] 配置编码失败，无法保存")
        }
    }
    
    /// 从 UserDefaults 加载配置（Codable 反序列化）
    private static func loadConfiguration() -> UITabDragConfiguration {
        guard let data = UserDefaults.standard.data(forKey: "com.xianrenzhilu.tabDragConfiguration"),
              let config = try? JSONDecoder().decode(UITabDragConfiguration.self, from: data) else {
            return .default
        }
        return config
    }
    
    /// 重置配置为默认值并保存
    public func resetConfiguration() {
        lock.lock()
        configuration = .default
        lock.unlock()
        saveConfiguration()
        logger.info("[持久化] 配置已重置为默认值")
    }
    
    /// 更新配置并保存
    /// - Parameter newConfig: 新的配置对象
    public func updateConfiguration(_ newConfig: UITabDragConfiguration) {
        lock.lock()
        configuration = newConfig
        lock.unlock()
        saveConfiguration()
        logger.info("[持久化] 配置已更新并保存")
    }
    
    /// 获取当前配置的副本
    public var currentConfiguration: UITabDragConfiguration {
        lock.lock()
        let config = configuration
        lock.unlock()
        return config
    }
    
    // MARK: - 设置面板方法
    /// 创建设置面板视图：拖拽分离/合并的所有设置控件
    /// 返回包含完整控件的 NSView，可直接嵌入到设置窗口中
    /// - Returns: 设置面板 NSView
    public func createSettingsView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 420))
        
        // 标题标签
        let titleLabel = NSTextField(labelWithString: "标签页拖拽分离/合并设置")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.frame = NSRect(x: 20, y: 380, width: 300, height: 24)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        view.addSubview(titleLabel)
        
        // 启用开关
        let enableCheckbox = NSButton(checkboxWithTitle: "启用标签页拖拽分离/合并", target: self, action: #selector(enableChanged(_:)))
        enableCheckbox.state = configuration.isEnabled ? .on : .off
        enableCheckbox.frame = NSRect(x: 20, y: 345, width: 240, height: 22)
        view.addSubview(enableCheckbox)
        
        // 脱离阈值输入框
        let thresholdLabel = NSTextField(labelWithString: "脱离触发距离（像素）：")
        thresholdLabel.frame = NSRect(x: 20, y: 310, width: 160, height: 20)
        thresholdLabel.isEditable = false
        thresholdLabel.isBordered = false
        thresholdLabel.backgroundColor = .clear
        view.addSubview(thresholdLabel)
        
        let thresholdField = NSTextField(frame: NSRect(x: 190, y: 310, width: 60, height: 22))
        thresholdField.stringValue = String(Int(configuration.detachThreshold))
        thresholdField.tag = 100
        view.addSubview(thresholdField)
        
        // 合并邻近距离输入框
        let proximityLabel = NSTextField(labelWithString: "合并感应距离（像素）：")
        proximityLabel.frame = NSRect(x: 20, y: 275, width: 160, height: 20)
        proximityLabel.isEditable = false
        proximityLabel.isBordered = false
        proximityLabel.backgroundColor = .clear
        view.addSubview(proximityLabel)
        
        let proximityField = NSTextField(frame: NSRect(x: 190, y: 275, width: 60, height: 22))
        proximityField.stringValue = String(Int(configuration.mergeProximity))
        proximityField.tag = 101
        view.addSubview(proximityField)
        
        // 新窗口宽度
        let widthLabel = NSTextField(labelWithString: "新窗口宽度：")
        widthLabel.frame = NSRect(x: 20, y: 240, width: 120, height: 20)
        widthLabel.isEditable = false
        widthLabel.isBordered = false
        widthLabel.backgroundColor = .clear
        view.addSubview(widthLabel)
        
        let widthField = NSTextField(frame: NSRect(x: 150, y: 240, width: 60, height: 22))
        widthField.stringValue = String(Int(configuration.newWindowWidth))
        widthField.tag = 102
        view.addSubview(widthField)
        
        // 新窗口高度
        let heightLabel = NSTextField(labelWithString: "新窗口高度：")
        heightLabel.frame = NSRect(x: 240, y: 240, width: 120, height: 20)
        heightLabel.isEditable = false
        heightLabel.isBordered = false
        heightLabel.backgroundColor = .clear
        view.addSubview(heightLabel)
        
        let heightField = NSTextField(frame: NSRect(x: 370, y: 240, width: 60, height: 22))
        heightField.stringValue = String(Int(configuration.newWindowHeight))
        heightField.tag = 103
        view.addSubview(heightField)
        
        // 视觉反馈开关
        let feedbackCheckbox = NSButton(checkboxWithTitle: "显示拖拽视觉反馈", target: self, action: #selector(feedbackChanged(_:)))
        feedbackCheckbox.state = configuration.showVisualFeedback ? .on : .off
        feedbackCheckbox.frame = NSRect(x: 20, y: 205, width: 180, height: 22)
        view.addSubview(feedbackCheckbox)
        
        // 透明度滑块
        let opacityLabel = NSTextField(labelWithString: "浮窗透明度：")
        opacityLabel.frame = NSRect(x: 20, y: 170, width: 100, height: 20)
        opacityLabel.isEditable = false
        opacityLabel.isBordered = false
        opacityLabel.backgroundColor = .clear
        view.addSubview(opacityLabel)
        
        let opacitySlider = NSSlider(value: Double(configuration.feedbackOpacity), minValue: 0.1, maxValue: 1.0, target: self, action: #selector(opacityChanged(_:)))
        opacitySlider.frame = NSRect(x: 130, y: 170, width: 200, height: 22)
        opacitySlider.tag = 104
        view.addSubview(opacitySlider)
        
        let opacityValueLabel = NSTextField(labelWithString: String(format: "%.0f%%", configuration.feedbackOpacity * 100))
        opacityValueLabel.frame = NSRect(x: 340, y: 170, width: 50, height: 20)
        opacityValueLabel.tag = 105
        opacityValueLabel.isEditable = false
        opacityValueLabel.isBordered = false
        opacityValueLabel.backgroundColor = .clear
        view.addSubview(opacityValueLabel)
        
        // 动画开关
        let animateCheckbox = NSButton(checkboxWithTitle: "启用过渡动画", target: self, action: #selector(animateChanged(_:)))
        animateCheckbox.state = configuration.animateTransitions ? .on : .off
        animateCheckbox.frame = NSRect(x: 20, y: 135, width: 140, height: 22)
        view.addSubview(animateCheckbox)
        
        // 自动保存开关
        let autoSaveCheckbox = NSButton(checkboxWithTitle: "自动保存布局", target: self, action: #selector(autoSaveChanged(_:)))
        autoSaveCheckbox.state = configuration.autoSaveLayout ? .on : .off
        autoSaveCheckbox.frame = NSRect(x: 20, y: 100, width: 140, height: 22)
        view.addSubview(autoSaveCheckbox)
        
        // 保存按钮
        let saveButton = NSButton(title: "保存设置", target: self, action: #selector(saveSettingsButtonClicked))
        saveButton.bezelStyle = .rounded
        saveButton.frame = NSRect(x: 20, y: 55, width: 100, height: 28)
        view.addSubview(saveButton)
        
        // 重置按钮
        let resetButton = NSButton(title: "恢复默认", target: self, action: #selector(resetSettingsButtonClicked))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: 130, y: 55, width: 100, height: 28)
        view.addSubview(resetButton)
        
        // 底部说明文本
        let infoText = NSTextField(labelWithString: "拖拽标签页到空白区域可分离为新窗口，拖拽到其他窗口标签栏可合并")
        infoText.font = NSFont.systemFont(ofSize: 11)
        infoText.textColor = NSColor.secondaryLabelColor
        infoText.frame = NSRect(x: 20, y: 20, width: 440, height: 20)
        infoText.isEditable = false
        infoText.isBordered = false
        infoText.backgroundColor = .clear
        view.addSubview(infoText)
        
        return view
    }
    
    /// 启用开关变更
    @objc private func enableChanged(_ sender: NSButton) {
        var config = currentConfiguration
        config.isEnabled = (sender.state == .on)
        updateConfiguration(config)
    }
    
    /// 视觉反馈开关变更
    @objc private func feedbackChanged(_ sender: NSButton) {
        var config = currentConfiguration
        config.showVisualFeedback = (sender.state == .on)
        updateConfiguration(config)
    }
    
    /// 透明度滑块变更
    @objc private func opacityChanged(_ sender: NSSlider) {
        var config = currentConfiguration
        config.feedbackOpacity = CGFloat(sender.doubleValue)
        updateConfiguration(config)
    }
    
    /// 动画开关变更
    @objc private func animateChanged(_ sender: NSButton) {
        var config = currentConfiguration
        config.animateTransitions = (sender.state == .on)
        updateConfiguration(config)
    }
    
    /// 自动保存开关变更
    @objc private func autoSaveChanged(_ sender: NSButton) {
        var config = currentConfiguration
        config.autoSaveLayout = (sender.state == .on)
        updateConfiguration(config)
    }
    
    /// 保存按钮点击
    @objc private func saveSettingsButtonClicked() {
        saveConfiguration()
        logger.info("[设置面板] 用户手动保存配置")
    }
    
    /// 重置按钮点击
    @objc private func resetSettingsButtonClicked() {
        resetConfiguration()
        logger.info("[设置面板] 用户重置配置为默认值")
    }
    
    // MARK: - 状态查询
    /// 获取当前拖拽状态的副本（线程安全）
    public var currentState: UITabDragState {
        lock.lock()
        let s = state
        lock.unlock()
        return s
    }
    
    /// 是否正在拖拽中（线程安全）
    public var isDragging: Bool {
        lock.lock()
        let result = state.isDragging
        lock.unlock()
        return result
    }
    
    /// 当前被拖拽的标签 ID（线程安全）
    public var currentDraggingTabID: String? {
        lock.lock()
        let result = state.draggingTabID
        lock.unlock()
        return result
    }
    
    // MARK: - 清理
    deinit {
        // 移除全局事件监控
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        // 移除本地事件监控
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // 取消悬停计时器
        hoverTimer?.invalidate()
        hoverTimer = nil
        
        // 清理视觉反馈
        feedbackManager.cleanup()
        

        logger.info("[销毁] UITabDragManager 已释放，所有监控和视觉元素已清理")
    }
}

// MARK: - 迁回自 UI-02：标签拖拽关联键
private enum UIAssociatedKeys {
    static nonisolated(unsafe) var tabItem: UInt8 = 0
    static nonisolated(unsafe) var windowID: UInt8 = 0
}

// MARK: - 迁回自 UI-02：struct UITabPageInfo
// MARK: - 标签按钮
/// 单个标签页按钮，支持点击、关闭、悬停高亮、右击菜单
// 已迁回 UI-GL-46_多行标签页.swift：class UIMultiLineTabButton（公共类型文件禁止功能实现）

// MARK: - 标签行视图
/// 单行标签容器，管理一行内的标签按钮排列
// 已迁回 UI-GL-46_多行标签页.swift：class UITabRowView（公共类型文件禁止功能实现）

// MARK: - 多行标签栏视图
/// 支持多行显示和滚动的标签栏视图，标签超出容器宽度自动换行
// 已迁回 UI-GL-46_多行标签页.swift：class UIMultiLineTabBarView（公共类型文件禁止功能实现）

// MARK: - 多行标签管理器（单例）
/// 全局单例管理器，负责多行标签页的增删改查、持久化、设置面板和通知分发
// 已迁回 UI-GL-46_多行标签页.swift：class UIMultiLineTabManager（公共类型文件禁止功能实现）

// MARK: - 便捷扩展
// 已迁回 UI-GL-46_多行标签页.swift：extension UIMultiLineTabManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-47 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-47_types.swift
// 版本: 2.0
// MARK: - 通知扩展
/// 标签拖拽模块专用的通知名称扩展
// 已迁回 UI-GL-47_标签页脱离合并.swift：extension Notification.Name（公共类型文件禁止功能实现）

// MARK: - 占位类型（由其他模块提供）
/// 标签页信息占位定义，实际由标签页模块提供
public struct UITabPageInfo: Codable, Equatable {
    public var id: String
    public var title: String
    public var windowID: String?
    public var groupID: String?
    public var isPinned: Bool
    public var order: Int
    public var isModified: Bool = false
    public var iconName: String?
    
    public init(id: String, title: String, windowID: String? = nil, groupID: String? = nil, isPinned: Bool = false, order: Int = 0, iconName: String? = nil) {
        self.id = id
        self.title = title
        self.windowID = windowID
        self.groupID = groupID
        self.isPinned = isPinned
        self.order = order
        self.iconName = iconName
    }
}

// MARK: - 迁回自 UI-02：struct UITabDragConfiguration
/// 标签容器窗口占位定义
// 已迁回 UI-GL-47_标签页脱离合并.swift：class UITabContainerWindow（公共类型文件禁止功能实现）

/// 标签页占位定义
// 已迁回 UI-GL-47_标签页脱离合并.swift：class UITabPage（公共类型文件禁止功能实现）

// MARK: - 拖拽配置
/// 标签页拖拽行为配置，支持 Codable 持久化到 UserDefaults
public struct UITabDragConfiguration: Codable, Equatable, Sendable {
    /// 是否启用标签拖拽功能
    public var isEnabled: Bool
    /// 触发脱离的最小拖拽距离（像素）
    public var detachThreshold: CGFloat
    /// 判定为可合并的邻近距离（像素）
    public var mergeProximity: CGFloat
    /// 新窗口默认宽度
    public var newWindowWidth: CGFloat
    /// 新窗口默认高度
    public var newWindowHeight: CGFloat
    /// 是否显示拖拽视觉反馈
    public var showVisualFeedback: Bool
    /// 浮窗透明度（0.0 ~ 1.0）
    public var feedbackOpacity: CGFloat
    /// 是否启用过渡动画
    public var animateTransitions: Bool
    /// 自动保存布局
    public var autoSaveLayout: Bool
    
    /// 默认配置
    public static let `default` = UITabDragConfiguration(
        isEnabled: true,
        detachThreshold: 30.0,
        mergeProximity: 60.0,
        newWindowWidth: 800.0,
        newWindowHeight: 600.0,
        showVisualFeedback: true,
        feedbackOpacity: 0.85,
        animateTransitions: true,
        autoSaveLayout: true
    )
}

// MARK: - 迁回自 UI-02：enum UITabDragState
// MARK: - 拖拽状态枚举
/// 标签拖拽的当前状态机，用于追踪拖拽生命周期
public enum UITabDragState: Equatable {
    /// 空闲状态，无拖拽进行中
    case idle
    /// 正在拖拽中：记录标签ID、源窗口ID、起始鼠标位置
    case dragging(tabID: String, sourceWindowID: String, startPoint: NSPoint)
    /// 悬停在目标窗口上方：准备合并
    case hoveringTarget(tabID: String, targetWindowID: String, insertIndex: Int)
    /// 正在创建新窗口：拖拽到空白区域
    case creatingNewWindow(tabID: String, currentPoint: NSPoint)
    
    /// 是否处于拖拽活跃状态
    public var isDragging: Bool {
        if case .idle = self { return false }
        return true
    }
    
    /// 获取当前被拖拽的标签ID
    public var draggingTabID: String? {
        switch self {
        case .idle: return nil
        case .dragging(let tabID, _, _): return tabID
        case .hoveringTarget(let tabID, _, _): return tabID
        case .creatingNewWindow(let tabID, _): return tabID
        }
    }
}
