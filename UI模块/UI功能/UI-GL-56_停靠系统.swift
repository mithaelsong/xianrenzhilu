// 功能46: 停靠系统 (Docking System)
// 对应: 浮动面板拖拽到窗口边缘时嵌入主窗口，支持拖拽分离
// 优先级: P1

import AppKit
import Foundation
import os.log

// MARK: - 测试代码
#if DEBUG

/// 功能46：停靠系统 — 单元测试
func test_docking() {
    let manager = UIDockingManager.shared
    let logger = OSLog(subsystem: "com.xianrenzhilu.ui", category: "UI-GL-56")
    
    os_log("测试1: 默认配置", log: logger, type: .info)
    if manager.dockingThreshold == 40 { os_log("✅ 测试1通过", log: logger, type: .info) }
    else { os_log("❌ 测试1失败", log: logger, type: .error) }
    
    os_log("测试2: 面板注册", log: logger, type: .info)
    let panel = UIDockablePanel(panelID: "test1", title: "测试面板", contentView: NSView())
    manager.registerPanel(panel)
    let retrieved = manager.getPanel("test1")
    if retrieved?.panelTitle == "测试面板" { os_log("✅ 测试2通过", log: logger, type: .info) }
    else { os_log("❌ 测试2失败", log: logger, type: .error) }
    
    os_log("测试3: 停靠位置", log: logger, type: .info)
    manager.setPanelPosition("test1", position: .left)
    let panelAfter = manager.getPanel("test1")
    if panelAfter?.currentPosition == .left { os_log("✅ 测试3通过", log: logger, type: .info) }
    else { os_log("❌ 测试3失败", log: logger, type: .error) }
    
    os_log("测试4: 所有面板", log: logger, type: .info)
    let all = manager.allPanels()
    if all.count >= 1 { os_log("✅ 测试4通过", log: logger, type: .info) }
    else { os_log("❌ 测试4失败", log: logger, type: .error) }
    
    os_log("测试5: 按位置查询", log: logger, type: .info)
    let leftPanels = manager.panels(at: .left)
    if leftPanels.count >= 1 { os_log("✅ 测试5通过", log: logger, type: .info) }
    else { os_log("❌ 测试5失败", log: logger, type: .error) }
    
    os_log("测试6: 展开/折叠", log: logger, type: .info)
    manager.collapsePanel("test1")
    if panelAfter?.isExpanded == false { os_log("✅ 测试6通过", log: logger, type: .info) }
    else { os_log("❌ 测试6失败", log: logger, type: .error) }
    manager.expandPanel("test1")
    
    os_log("测试7: 停靠统计", log: logger, type: .info)
    let stats = manager.dockingStatistics()
    _ = stats
    os_log("✅ 测试7通过", log: logger, type: .info)
    
    os_log("测试8: 排序", log: logger, type: .info)
    manager.setPanelOrder("test1", orderIndex: 1)
    os_log("✅ 测试8通过", log: logger, type: .info)
    
    os_log("测试9: 注销", log: logger, type: .info)
    manager.unregisterPanel("test1")
    let afterUnregister = manager.getPanel("test1")
    if afterUnregister == nil { os_log("✅ 测试9通过", log: logger, type: .info) }
    else { os_log("❌ 测试9失败", log: logger, type: .error) }
    
    os_log("=== 全部停靠系统测试通过 ✅ ===", log: logger, type: .info)
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
extension Notification.Name {
    static let dockingPositionDidChange = Notification.Name("dockingPositionDidChange")
    static let dockablePanelDidExpand = Notification.Name("dockablePanelDidExpand")
    static let dockablePanelDidCollapse = Notification.Name("dockablePanelDidCollapse")
}

// MARK: - 迁回自 UI-02：extension UIDockablePanelProtocol
public extension UIDockablePanelProtocol {
    func willDock(to position: UIDockingPosition) {}
    func didDock(to position: UIDockingPosition) {}
    func willUndock() {}
    func didUndock() {}
}

// MARK: - 迁回自 UI-02：class UIDockingZoneIndicatorView
public class UIDockingZoneIndicatorView: NSView , @unchecked Sendable{
    private var targetZone: UIDockingZone = .none
    private var highlightColor: NSColor = NSColor.systemBlue.withAlphaComponent(0.3)
    private var borderColor: NSColor = NSColor.systemBlue.withAlphaComponent(0.8)
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAppearance()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }
    
    /// 设置视图外观
    private func setupAppearance() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 6.0
        layer?.borderWidth = 2.0
        layer?.borderColor = borderColor.cgColor
    }
    
    /// 设置当前高亮的目标区域
    public func setTargetZone(_ zone: UIDockingZone) {
        targetZone = zone
        needsDisplay = true
    }
    
    /// 绘制高亮区域
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard targetZone != .none else { return }
        
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        highlightColor.setFill()
        path.fill()
        
        borderColor.setStroke()
        path.lineWidth = 2.0
        path.stroke()
        
        // 绘制区域名称文字
        let text = targetZone.displayName as NSString
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: textAttributes)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: textAttributes)
    }
}

// MARK: - 迁回自 UI-02：class UIDockingIndicatorWindowController
public class UIDockingIndicatorWindowController : @unchecked Sendable {
    private var indicatorWindow: NSWindow?
    private var indicatorView: UIDockingZoneIndicatorView?
    private let logger = Logger(subsystem: "com.xianrenzhilu.docking", category: "IndicatorWindow")
    
    /// 在指定区域显示停靠指示器
    public func showIndicator(in frame: NSRect, for zone: UIDockingZone, on screen: NSScreen) {
        hideIndicator()
        
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = .floating
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        
        let indicatorView = UIDockingZoneIndicatorView(frame: NSRect(origin: .zero, size: frame.size))
        indicatorView.setTargetZone(zone)
        window.contentView = indicatorView
        
        window.orderFront(nil)
        
        self.indicatorWindow = window
        self.indicatorView = indicatorView
        
        logger.debug("显示停靠指示器: \(zone.displayName), 位置: \(String(describing: frame.origin))")
    }
    
    /// 隐藏停靠指示器
    public func hideIndicator() {
        guard let window = indicatorWindow else { return }
        window.orderOut(nil)
        indicatorWindow = nil
        indicatorView = nil
        logger.debug("隐藏停靠指示器")
    }
    
    /// 检查指示器是否正在显示
    public var isShowing: Bool {
        return indicatorWindow != nil
    }
    
    deinit {
        hideIndicator()
        logger.debug("UIDockingIndicatorWindowController 已释放")
    }
}

// MARK: - 迁回自 UI-02：class UIDockablePanel
public class UIDockablePanel: NSObject, UIDockablePanelProtocol, NSDraggingDestination , @unchecked Sendable{
    public let panelID: String
    public let panelTitle: String
    public let contentView: NSView
    public var preferredSize: NSSize
    
    public var currentPosition: UIDockingPosition = .floating
    public var isExpanded: Bool = true
    public var lastFloatingFrame: NSRect = .zero
    public var orderIndex: Int = 0
    
    private weak var containerWindow: NSWindow?
    private weak var hostView: NSView?
    private var dragSession: NSDraggingSession?
    
    private let logger = Logger(subsystem: "com.xianrenzhilu.docking", category: "UIDockablePanel")
    
    public init(panelID: String, title: String, contentView: NSView, preferredSize: NSSize = NSSize(width: 250, height: 400)) {
        self.panelID = panelID
        self.panelTitle = title
        self.contentView = contentView
        self.preferredSize = preferredSize
        super.init()
        logger.debug("创建面板: \(panelID) - \(title)")
    }
    
    /// 面板即将停靠
    public func willDock(to position: UIDockingPosition) {
        logger.debug("面板 \(self.panelID) 即将停靠到 \(position.displayName)")
        if position == .floating {
            // 恢复浮动时，需要记录之前的位置
        }
    }
    
    /// 面板已停靠
    public func didDock(to position: UIDockingPosition) {
        currentPosition = position
        logger.info("面板 \(self.panelID) 已停靠到 \(position.displayName)")
        
        // 发送停靠位置变更通知
        NotificationCenter.default.post(
            name: .dockingPositionDidChange,
            object: self,
            userInfo: ["panelID": panelID, "position": position]
        )
    }
    
    /// 面板即将分离
    public func willUndock() {
        logger.debug("面板 \(self.panelID) 即将分离")
    }
    
    /// 面板已分离
    public func didUndock() {
        currentPosition = .floating
        logger.info("面板 \(self.panelID) 已恢复浮动")
        
        NotificationCenter.default.post(
            name: .dockingPositionDidChange,
            object: self,
            userInfo: ["panelID": panelID, "position": UIDockingPosition.floating]
        )
    }
    
    /// 展开面板
    public func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        logger.info("面板 \(self.panelID) 已展开")
        
        NotificationCenter.default.post(
            name: .dockablePanelDidExpand,
            object: self,
            userInfo: ["panelID": panelID]
        )
    }
    
    /// 折叠面板
    public func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        logger.info("面板 \(self.panelID) 已折叠")
        
        NotificationCenter.default.post(
            name: .dockablePanelDidCollapse,
            object: self,
            userInfo: ["panelID": panelID]
        )
    }
    
    /// 切换展开/折叠状态
    public func toggleExpandCollapse() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }
    
    /// 设置容器窗口
    public func setContainerWindow(_ window: NSWindow?) {
        containerWindow = window
    }
    
    /// 获取容器窗口
    public var getContainerWindow: NSWindow? {
        return containerWindow
    }
    
    // MARK: - NSDraggingDestination 协议实现
    
    public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        logger.debug("拖拽进入面板 \(self.panelID)")
        return .move
    }
    
    public func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .move
    }
    
    public func draggingExited(_ sender: NSDraggingInfo?) {
        logger.debug("拖拽离开面板 \(self.panelID)")
    }
    
    public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        logger.info("在面板 \(self.panelID) 上执行拖拽操作")
        return true
    }
    
    /// 生成拖拽图像
    public func createDraggingImage() -> NSImage {
        let image = NSImage(size: preferredSize)
        image.lockFocus()
        contentView.layer?.render(in: NSGraphicsContext.current!.cgContext)
        image.unlockFocus()
        return image
    }
    
    deinit {
        logger.debug("UIDockablePanel \(self.panelID) 已释放")
    }
}

// MARK: - 面板折叠规则
/// 折叠锚点。描述面板折叠/展开时哪一条视觉边保持不动。
public enum UIDockingCollapseAnchor: String, Codable, Sendable {
    case top
    case bottom
    case left
    case right
}

/// 固定区域参与动画的策略。
public enum UIDockingFixedRegionAnimationMode: String, Codable, Sendable {
    /// 固定区域完全不参与位移、缩放、透明度动画。
    case fixed
    /// 固定区域只随外层容器裁剪，不做额外动画。
    case clippedOnly
    /// 固定区域允许跟随外层容器一起动画。
    case followContainer
}

/// 内容区折叠/展开的视觉方向。
public enum UIDockingBodyRevealDirection: String, Codable, Sendable {
    /// 折叠时从底部向上收；展开时从上往下露出。
    case bottomToTopCollapseTopToBottomExpand
    /// 折叠时从顶部向下收；展开时从下往上露出。
    case topToBottomCollapseBottomToTopExpand
    /// 从左向右/右向左。
    case horizontal
    /// 只裁剪，不指定方向。
    case clipOnly
}

/// 内容区动画参与方式。
public enum UIDockingBodyAnimationMode: String, Codable, Sendable {
    /// 由 UI 模块裁剪内容区高度/宽度。
    case clip
    /// 裁剪 + 淡入淡出。
    case clipAndFade
    /// 内容区先隐藏，外层容器动画结束后再显示。
    case hideDuringContainerAnimation
    /// 跟随外层容器一起缩放。
    case followContainer
}

/// 动画曲线类型。
public enum UIDockingAnimationCurve: Sendable {
    case easeInOut
    case easeOut
    case easeIn
    case linear
    /// 弹簧参数：阻尼越小越弹，stiffness 越大越快，initialVelocity 越大初速度越强。
    case spring(mass: CGFloat, stiffness: CGFloat, damping: CGFloat, initialVelocity: CGFloat)

    fileprivate var timingFunction: CAMediaTimingFunction? {
        switch self {
        case .easeInOut: return CAMediaTimingFunction(name: .easeInEaseOut)
        case .easeOut: return CAMediaTimingFunction(name: .easeOut)
        case .easeIn: return CAMediaTimingFunction(name: .easeIn)
        case .linear: return CAMediaTimingFunction(name: .linear)
        case .spring: return nil
        }
    }
}

/// 单个方向的动画配置。
public struct UIDockingTransitionAnimation: Sendable {
    public var duration: TimeInterval
    public var curve: UIDockingAnimationCurve
    public var bodyFade: Bool
    public var bodyFadeDelay: TimeInterval

    public init(
        duration: TimeInterval = 0.25,
        curve: UIDockingAnimationCurve = .easeInOut,
        bodyFade: Bool = false,
        bodyFadeDelay: TimeInterval = 0
    ) {
        self.duration = duration
        self.curve = curve
        self.bodyFade = bodyFade
        self.bodyFadeDelay = bodyFadeDelay
    }

    public static func easeInOut(duration: TimeInterval = 0.25) -> UIDockingTransitionAnimation {
        UIDockingTransitionAnimation(duration: duration, curve: .easeInOut)
    }

    public static func appleSpring(
        duration: TimeInterval = 0.34,
        mass: CGFloat = 0.70,
        stiffness: CGFloat = 360,
        damping: CGFloat = 30,
        initialVelocity: CGFloat = 0.65,
        bodyFade: Bool = true,
        bodyFadeDelay: TimeInterval = 0.04
    ) -> UIDockingTransitionAnimation {
        UIDockingTransitionAnimation(
            duration: duration,
            curve: .spring(mass: mass, stiffness: stiffness, damping: damping, initialVelocity: initialVelocity),
            bodyFade: bodyFade,
            bodyFadeDelay: bodyFadeDelay
        )
    }
}

/// 固定头部/侧边区域配置。
public struct UIDockingFixedRegionRule: Sendable {
    public var anchor: UIDockingCollapseAnchor
    public var size: CGFloat
    public var participatesInAnimation: UIDockingFixedRegionAnimationMode
    public var keepControlsInteractive: Bool
    public var clipsToBounds: Bool

    public init(
        anchor: UIDockingCollapseAnchor = .top,
        size: CGFloat,
        participatesInAnimation: UIDockingFixedRegionAnimationMode = .fixed,
        keepControlsInteractive: Bool = true,
        clipsToBounds: Bool = true
    ) {
        self.anchor = anchor
        self.size = size
        self.participatesInAnimation = participatesInAnimation
        self.keepControlsInteractive = keepControlsInteractive
        self.clipsToBounds = clipsToBounds
    }
}

/// 可折叠内容区规则。
public struct UIDockingBodyRegionRule: Sendable {
    public var startsAfterFixedRegion: Bool
    public var revealDirection: UIDockingBodyRevealDirection
    public var animationMode: UIDockingBodyAnimationMode
    public var clipsToBounds: Bool
    public var collapseAlpha: CGFloat
    public var expandedAlpha: CGFloat

    public init(
        startsAfterFixedRegion: Bool = true,
        revealDirection: UIDockingBodyRevealDirection = .bottomToTopCollapseTopToBottomExpand,
        animationMode: UIDockingBodyAnimationMode = .clipAndFade,
        clipsToBounds: Bool = true,
        collapseAlpha: CGFloat = 0,
        expandedAlpha: CGFloat = 1
    ) {
        self.startsAfterFixedRegion = startsAfterFixedRegion
        self.revealDirection = revealDirection
        self.animationMode = animationMode
        self.clipsToBounds = clipsToBounds
        self.collapseAlpha = collapseAlpha
        self.expandedAlpha = expandedAlpha
    }
}

/// 业务模块提交给 UI 停靠系统的折叠/展开执行规则。
/// 业务模块只描述“折成什么样”，具体状态切换、外层 frame 动画、内容区裁剪节奏和通知由 UI 模块执行。
public struct UIDockingCollapseRule: Sendable {
    /// 折叠后外层容器高度/宽度。纵向折叠时是高度。
    public var collapsedSize: CGFloat
    /// 兼容旧调用：折叠后高度。
    public var collapsedHeight: CGFloat { collapsedSize }
    /// 外层容器折叠/展开时哪条视觉边不动。
    public var anchor: UIDockingCollapseAnchor
    /// 固定区域（例如 K线一级功能栏）规则。
    public var fixedRegion: UIDockingFixedRegionRule?
    /// 可折叠内容区（例如二级栏 + 图表 + 成交量）规则。
    public var bodyRegion: UIDockingBodyRegionRule
    /// 折叠动画。
    public var collapseAnimation: UIDockingTransitionAnimation
    /// 展开动画。
    public var expandAnimation: UIDockingTransitionAnimation
    /// 是否持久化折叠状态下的外层 frame。通常 false，避免把 44 高误当展开高度。
    public var persistCollapsedFrame: Bool
    /// 状态切换前通知业务模块准备内部视图，例如隐藏/显示 body。
    public var beforeTransition: (@Sendable (Bool) -> Void)?
    /// 状态切换后通知业务模块同步箭头、业务状态等。
    public var afterTransition: (@Sendable (Bool) -> Void)?

    public init(
        collapsedHeight: CGFloat,
        animationDuration: TimeInterval = 0.25,
        preserveTopEdge: Bool = true,
        beforeTransition: (@Sendable (Bool) -> Void)? = nil,
        afterTransition: (@Sendable (Bool) -> Void)? = nil
    ) {
        self.collapsedSize = collapsedHeight
        self.anchor = preserveTopEdge ? .top : .bottom
        self.fixedRegion = nil
        self.bodyRegion = UIDockingBodyRegionRule(animationMode: .hideDuringContainerAnimation)
        self.collapseAnimation = .easeInOut(duration: animationDuration)
        self.expandAnimation = .easeInOut(duration: animationDuration)
        self.persistCollapsedFrame = false
        self.beforeTransition = beforeTransition
        self.afterTransition = afterTransition
    }

    public init(
        collapsedSize: CGFloat,
        anchor: UIDockingCollapseAnchor = .top,
        fixedRegion: UIDockingFixedRegionRule? = nil,
        bodyRegion: UIDockingBodyRegionRule = UIDockingBodyRegionRule(),
        collapseAnimation: UIDockingTransitionAnimation = .easeInOut(duration: 0.22),
        expandAnimation: UIDockingTransitionAnimation = .appleSpring(),
        persistCollapsedFrame: Bool = false,
        beforeTransition: (@Sendable (Bool) -> Void)? = nil,
        afterTransition: (@Sendable (Bool) -> Void)? = nil
    ) {
        self.collapsedSize = collapsedSize
        self.anchor = anchor
        self.fixedRegion = fixedRegion
        self.bodyRegion = bodyRegion
        self.collapseAnimation = collapseAnimation
        self.expandAnimation = expandAnimation
        self.persistCollapsedFrame = persistCollapsedFrame
        self.beforeTransition = beforeTransition
        self.afterTransition = afterTransition
    }
}

// MARK: - 迁回自 UI-02：class UIDockingManager
public final class UIDockingManager : @unchecked Sendable {
    
    // MARK: 单例
    public static let shared = UIDockingManager()
    
    // MARK: 日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu.docking", category: "UIDockingManager")
    
    // MARK: 线程锁，保护共享数据
    private let lock = NSRecursiveLock()
    
    // MARK: 存储的面板字典
    private var panels: [String: UIDockablePanel] = [:]

    // MARK: 面板折叠规则表
    private var collapseRules: [String: UIDockingCollapseRule] = [:]
    private var expandedFramesBeforeCollapse: [String: NSRect] = [:]
    
    // MARK: 停靠配置信息
    private var panelInfos: [String: UIDockingPanelInfo] = [:]
    
    // MARK: 停靠区域阈值（像素）
    public var dockingThreshold: CGFloat = 40.0
    
    // MARK: 最小面板尺寸
    public var minimumPanelSize: NSSize = NSSize(width: 150, height: 100)
    
    // MARK: 停靠区域尺寸配置
    public var leftDockWidth: CGFloat = 250.0
    public var rightDockWidth: CGFloat = 250.0
    public var bottomDockHeight: CGFloat = 200.0
    
    // MARK: 指示器管理器
    private let indicatorController = UIDockingIndicatorWindowController()
    
    // MARK: 主窗口引用
    private weak var mainWindow: NSWindow?
    
    // MARK: 当前拖拽中的面板
    private var draggingPanelID: String?
    
    // MARK: 持久化文件路径
    private var persistenceURL: URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport?.appendingPathComponent("XianRenZhiLu/DockingConfig.json")
    }
    
    // MARK: 通知监听集合
    private var notificationObservers: [NSObjectProtocol] = []
    
    // MARK: 初始化
    private init() {
        logger.info("停靠系统管理器初始化完成")
        setupNotificationObservers()
        loadDockingConfiguration()
    }
    
    // MARK: 设置通知监听
    private func setupNotificationObservers() {
        // 监听应用退出时保存配置
        let observer = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveDockingConfiguration()
        }
        notificationObservers.append(observer)
        logger.debug("已设置通知监听")
    }
    
    // MARK: 注册面板
    /// 注册一个可停靠面板到管理系统
    public func registerPanel(_ panel: UIDockablePanel) {
        lock.lock()
        panels[panel.panelID] = panel
        
        // 如果存在保存的配置，恢复之
        if let info = panelInfos[panel.panelID] {
            panel.currentPosition = info.position
            panel.isExpanded = info.isExpanded
            panel.preferredSize = NSSize(width: info.preferredWidth, height: info.preferredHeight)
            panel.lastFloatingFrame = info.lastFloatingFrame ?? .zero
            panel.orderIndex = info.orderIndex
        }
        lock.unlock()
        
        logger.info("注册面板成功: \(panel.panelID) - \(panel.panelTitle)")
    }

    // MARK: 注册面板折叠规则
    /// 注册业务面板的折叠规则。业务模块不直接操作外层容器 frame，只声明折叠后的期望形态。
    public func registerCollapseRule(panelID: String, rule: UIDockingCollapseRule) {
        lock.lock()
        collapseRules[panelID] = rule
        lock.unlock()
        logger.info("注册面板折叠规则: \(panelID), collapsedSize=\(rule.collapsedSize), anchor=\(rule.anchor.rawValue)")
    }
    
    // MARK: 注销面板
    /// 从管理系统中移除面板
    public func unregisterPanel(_ panelID: String) {
        lock.lock()
        guard let panel = panels.removeValue(forKey: panelID) else {
            lock.unlock()
            logger.warning("尝试注销未注册的面板: \(panelID)")
            return
        }
        
        // 保存当前状态到配置
        panelInfos[panelID] = UIDockingPanelInfo(
            id: panelID,
            position: panel.currentPosition,
            isExpanded: panel.isExpanded,
            preferredWidth: panel.preferredSize.width,
            preferredHeight: panel.preferredSize.height,
            lastFloatingFrame: panel.lastFloatingFrame,
            orderIndex: panel.orderIndex
        )
        collapseRules.removeValue(forKey: panelID)
        expandedFramesBeforeCollapse.removeValue(forKey: panelID)
        lock.unlock()
        
        logger.info("注销面板: \(panelID)")
    }
    
    // MARK: 获取面板
    /// 根据ID获取已注册的面板
    public func getPanel(_ panelID: String) -> UIDockablePanel? {
        lock.lock()
        let panel = panels[panelID]
        lock.unlock()
        return panel
    }
    
    // MARK: 获取所有面板
    /// 获取所有已注册的面板
    public func allPanels() -> [UIDockablePanel] {
        lock.lock()
        let all = Array(panels.values)
        lock.unlock()
        return all
    }
    
    // MARK: 同步面板展开状态
    /// 业务面板创建/恢复后，用当前视觉状态同步 UI 停靠系统状态，避免持久化状态与实际界面不一致。
    public func markPanelExpandedState(_ panelID: String, expanded: Bool, currentFrame: NSRect? = nil) {
        lock.lock()
        guard let panel = panels[panelID] else {
            lock.unlock()
            logger.warning("同步展开状态失败，面板未找到: \(panelID)")
            return
        }
        panel.isExpanded = expanded
        if expanded, let currentFrame {
            expandedFramesBeforeCollapse[panelID] = currentFrame
        }
        updatePanelInfo(panel)
        lock.unlock()
        logger.info("同步面板展开状态: \(panelID), expanded=\(expanded)")
    }

    // MARK: 设置面板停靠位置
    /// 将面板停靠到指定位置
    public func setPanelPosition(_ panelID: String, position: UIDockingPosition) {
        lock.lock()
        guard let panel = panels[panelID] else {
            lock.unlock()
            logger.warning("设置位置失败，面板未找到: \(panelID)")
            return
        }
        lock.unlock()
        
        let oldPosition = panel.currentPosition
        
        if oldPosition == .floating && position != .floating {
            // 从浮动转为停靠
            panel.lastFloatingFrame = panel.getContainerWindow?.frame ?? .zero
            panel.willDock(to: position)
            panel.didDock(to: position)
        } else if oldPosition != .floating && position == .floating {
            // 从停靠转为浮动
            panel.willUndock()
            panel.didUndock()
        } else {
            // 直接变更位置
            panel.didDock(to: position)
        }
        
        // 更新配置信息
        updatePanelInfo(panel)
        
        logger.info("面板 \(panelID) 位置从 \(oldPosition.displayName) 变更为 \(position.displayName)")
    }
    
    // MARK: 展开面板
    /// 展开指定面板
    public func expandPanel(_ panelID: String) {
        lock.lock()
        guard let panel = panels[panelID] else {
            lock.unlock()
            logger.warning("展开失败，面板未找到: \(panelID)")
            return
        }
        lock.unlock()
        
        performCollapseTransition(panel: panel, collapsed: false)
    }
    
    // MARK: 折叠面板
    /// 折叠指定面板
    public func collapsePanel(_ panelID: String) {
        lock.lock()
        guard let panel = panels[panelID] else {
            lock.unlock()
            logger.warning("折叠失败，面板未找到: \(panelID)")
            return
        }
        lock.unlock()
        
        performCollapseTransition(panel: panel, collapsed: true)
    }
    
    // MARK: 切换面板展开/折叠状态
    public func togglePanelExpandCollapse(_ panelID: String) {
        lock.lock()
        guard let panel = panels[panelID] else {
            lock.unlock()
            logger.warning("切换状态失败，面板未找到: \(panelID)")
            return
        }
        lock.unlock()
        
        performCollapseTransition(panel: panel, collapsed: panel.isExpanded)
    }

    // MARK: 执行规则化折叠/展开
    private func performCollapseTransition(panel: UIDockablePanel, collapsed: Bool) {
        let panelID = panel.panelID
        lock.lock()
        let rule = collapseRules[panelID]
        lock.unlock()

        guard let rule else {
            collapsed ? panel.collapse() : panel.expand()
            updatePanelInfo(panel)
            return
        }

        if collapsed == !panel.isExpanded { return }

        let execute = { [weak self, weak panel] in
            guard let self, let panel else { return }
            let hostView = panel.contentView
            if collapsed {
                self.expandedFramesBeforeCollapse[panelID] = hostView.frame
            }

            rule.beforeTransition?(collapsed)

            let source = hostView.frame
            let expandedFrame = self.expandedFramesBeforeCollapse[panelID] ?? source
            let target = self.targetFrame(for: source, expandedFrame: expandedFrame, collapsed: collapsed, rule: rule, parent: hostView.superview)
            let animation = collapsed ? rule.collapseAnimation : rule.expandAnimation

            // 区域化折叠规则：0...fixedRegion.size 是固定显示区，不折叠；fixedRegion.size 以下才是 body 折叠区。
            // 注意：这里只裁剪外层 hostView，不擅自改业务内部 subview 结构，避免把 header 裁黑。
            hostView.wantsLayer = true
            hostView.layer?.masksToBounds = true

            self.animate(view: hostView, to: target, animation: animation) { [weak self, weak panel, weak hostView] in
                guard let self, let panel else { return }
                collapsed ? panel.collapse() : panel.expand()
                self.updatePanelInfo(panel)
                if let hostView {
                    hostView.needsLayout = true
                    hostView.layoutSubtreeIfNeeded()
                    if !collapsed {
                        UISerializationManager.shared.saveContainerFrame(identifier: panelID, frame: hostView.frame)
                    } else if rule.persistCollapsedFrame {
                        UISerializationManager.shared.saveContainerFrame(identifier: panelID, frame: hostView.frame)
                    }
                }
                rule.afterTransition?(collapsed)
            }
        }

        if Thread.isMainThread {
            execute()
        } else {
            DispatchQueue.main.async(execute: execute)
        }
    }
    


    private func targetFrame(for source: NSRect, expandedFrame: NSRect, collapsed: Bool, rule: UIDockingCollapseRule, parent: NSView?) -> NSRect {
        if collapsed {
            var next = source
            let size = max(1, rule.collapsedSize)
            switch rule.anchor {
            case .top:
                if parent?.isFlipped == true {
                    next.origin.y = source.minY
                } else {
                    next.origin.y = source.maxY - size
                }
                next.size.height = size
            case .bottom:
                next.origin.y = source.minY
                next.size.height = size
            case .left:
                next.origin.x = source.minX
                next.size.width = size
            case .right:
                next.origin.x = source.maxX - size
                next.size.width = size
            }
            return next
        } else {
            var next = expandedFrame
            switch rule.anchor {
            case .top:
                if parent?.isFlipped == true {
                    next.origin.y = source.minY
                } else {
                    next.origin.y = source.maxY - expandedFrame.height
                }
            case .bottom:
                next.origin.y = source.minY
            case .left:
                next.origin.x = source.minX
            case .right:
                next.origin.x = source.maxX - expandedFrame.width
            }
            return next
        }
    }

    private func animate(view: NSView, to target: NSRect, animation: UIDockingTransitionAnimation, completion: @escaping () -> Void) {
        switch animation.curve {
        case .spring(let mass, let stiffness, let damping, let initialVelocity):
            view.wantsLayer = true
            let frameAnimation = CASpringAnimation(keyPath: "frame")
            frameAnimation.fromValue = NSValue(rect: view.frame)
            frameAnimation.toValue = NSValue(rect: target)
            frameAnimation.mass = mass
            frameAnimation.stiffness = stiffness
            frameAnimation.damping = damping
            frameAnimation.initialVelocity = initialVelocity
            frameAnimation.duration = min(max(frameAnimation.settlingDuration, animation.duration), animation.duration + 0.28)
            view.animations = ["frame": frameAnimation]
            view.animator().frame = target
            DispatchQueue.main.asyncAfter(deadline: .now() + frameAnimation.duration, execute: completion)
        default:
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = animation.duration
                context.timingFunction = animation.curve.timingFunction
                view.animator().frame = target
            }, completionHandler: completion)
        }
    }

    // MARK: 更新面板配置信息
    private func updatePanelInfo(_ panel: UIDockablePanel) {
        lock.lock()
        panelInfos[panel.panelID] = UIDockingPanelInfo(
            id: panel.panelID,
            position: panel.currentPosition,
            isExpanded: panel.isExpanded,
            preferredWidth: panel.preferredSize.width,
            preferredHeight: panel.preferredSize.height,
            lastFloatingFrame: panel.lastFloatingFrame,
            orderIndex: panel.orderIndex
        )
        lock.unlock()
    }
    
    // MARK: 设置主窗口
    /// 设置停靠系统关联的主窗口
    public func setMainWindow(_ window: NSWindow?) {
        mainWindow = window
        logger.info("主窗口已设置: \(window?.title ?? "无")")
    }
    
    // MARK: 检测拖拽位置对应的停靠区域
    /// 根据拖拽点检测应停靠的区域
    public func detectDockingZone(at point: NSPoint, in window: NSWindow) -> UIDockingZone {
        let windowFrame = window.frame
        let threshold = dockingThreshold
        
        // 转换为窗口内坐标
        let localPoint = window.contentView?.convert(point, from: nil) ?? point
        let contentBounds = window.contentView?.bounds ?? windowFrame
        
        // 检测左侧区域
        if localPoint.x < threshold && localPoint.y > 0 && localPoint.y < contentBounds.height {
            return .left
        }
        
        // 检测右侧区域
        if localPoint.x > contentBounds.width - threshold && localPoint.y > 0 && localPoint.y < contentBounds.height {
            return .right
        }
        
        // 检测底部区域
        if localPoint.y < threshold && localPoint.x > 0 && localPoint.x < contentBounds.width {
            return .bottom
        }
        
        return .none
    }
    
    // MARK: 获取停靠区域在窗口中的矩形范围
    /// 计算指定停靠区域在主窗口中的显示矩形
    public func dockZoneFrame(for zone: UIDockingZone, in window: NSWindow) -> NSRect {
        let contentView = window.contentView
        let bounds = contentView?.bounds ?? NSRect(origin: .zero, size: window.frame.size)
        
        switch zone {
        case .left:
            return NSRect(x: 0, y: 0, width: leftDockWidth, height: bounds.height)
        case .right:
            return NSRect(x: bounds.width - rightDockWidth, y: 0, width: rightDockWidth, height: bounds.height)
        case .bottom:
            return NSRect(x: 0, y: 0, width: bounds.width, height: bottomDockHeight)
        case .none:
            return .zero
        }
    }
    
    // MARK: 显示停靠区域指示器
    /// 在检测到的停靠区域显示高亮指示器
    public func showDockingIndicator(at point: NSPoint, in window: NSWindow) {
        let zone = detectDockingZone(at: point, in: window)
        
        guard zone != .none else {
            indicatorController.hideIndicator()
            return
        }
        
        let frame = dockZoneFrame(for: zone, in: window)
        let screenFrame = window.convertToScreen(frame)
        
        indicatorController.showIndicator(in: screenFrame, for: zone, on: window.screen ?? NSScreen.main!)
    }
    
    // MARK: 隐藏停靠区域指示器
    public func hideDockingIndicator() {
        indicatorController.hideIndicator()
    }
    
    // MARK: 处理拖拽面板到停靠区域
    /// 将拖拽的面板停靠到指定区域
    public func dockDraggingPanel(_ panelID: String, to zone: UIDockingZone, in window: NSWindow) -> Bool {
        guard zone != .none else { return false }
        
        let position = zone.toPosition
        setPanelPosition(panelID, position: position)
        
        // 更新面板容器
        lock.lock()
        if let panel = panels[panelID] {
            panel.setContainerWindow(window)
        }
        lock.unlock()
        
        hideDockingIndicator()
        logger.info("面板 \(panelID) 已拖拽停靠到 \(zone.displayName)")
        return true
    }
    
    // MARK: 开始拖拽面板
    /// 记录正在拖拽的面板
    public func beginDraggingPanel(_ panelID: String) {
        draggingPanelID = panelID
        logger.debug("开始拖拽面板: \(panelID)")
    }
    
    // MARK: 结束拖拽面板
    /// 清理拖拽状态
    public func endDraggingPanel() {
        if let id = draggingPanelID {
            logger.debug("结束拖拽面板: \(id)")
        }
        draggingPanelID = nil
        hideDockingIndicator()
    }
    
    // MARK: 获取当前拖拽的面板ID
    public var currentDraggingPanelID: String? {
        return draggingPanelID
    }
    
    // MARK: 保存停靠配置到文件
    /// 将所有面板停靠配置持久化到本地文件
    public func saveDockingConfiguration() {
        lock.lock()
        // 先更新所有面板的当前信息
        for (id, panel) in panels {
            panelInfos[id] = UIDockingPanelInfo(
                id: id,
                position: panel.currentPosition,
                isExpanded: panel.isExpanded,
                preferredWidth: panel.preferredSize.width,
                preferredHeight: panel.preferredSize.height,
                lastFloatingFrame: panel.lastFloatingFrame,
                orderIndex: panel.orderIndex
            )
        }
        let infosToSave = Array(panelInfos.values)
        lock.unlock()
        
        guard let url = persistenceURL else {
            logger.error("无法获取持久化文件路径")
            return
        }
        
        // 确保目录存在
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(infosToSave)
            try data.write(to: url)
            logger.info("停靠配置已保存到 \(url.path)")
        } catch {
            logger.error("保存停靠配置失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: 从文件加载停靠配置
    /// 加载之前保存的停靠配置
    public func loadDockingConfiguration() {
        guard let url = persistenceURL else {
            logger.error("无法获取持久化文件路径")
            return
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("未找到已有停靠配置文件，使用默认配置")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let infos = try decoder.decode([UIDockingPanelInfo].self, from: data)
            
            lock.lock()
            for info in infos {
                panelInfos[info.id] = info
            }
            lock.unlock()
            
            logger.info("已加载 \(infos.count) 个面板的停靠配置")
        } catch {
            logger.error("加载停靠配置失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: 重置所有停靠配置
    /// 清除所有面板配置并重新保存
    public func resetDockingConfiguration() {
        lock.lock()
        panelInfos.removeAll()
        for panel in panels.values {
            panel.currentPosition = .floating
            panel.isExpanded = true
            panel.orderIndex = 0
        }
        lock.unlock()
        
        saveDockingConfiguration()
        logger.info("已重置所有停靠配置")
    }
    
    // MARK: 打开设置面板
    /// 打开停靠系统设置面板，允许用户配置停靠参数
    public func openSettingsPanel() {
        logger.info("打开停靠系统设置面板")
        
        // 创建设置窗口
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "停靠系统设置"
        settingsWindow.center()
        
        // 创建设置视图
        let settingsView = createSettingsView()
        settingsWindow.contentView = settingsView
        
        settingsWindow.makeKeyAndOrderFront(nil)
        logger.info("停靠系统设置面板已显示")
    }
    
    // MARK: 创建设置视图
    /// 创建设置面板的内部视图内容
    private func createSettingsView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        
        // 停靠阈值设置
        let thresholdLabel = NSTextField(labelWithString: "停靠阈值: \(Int(dockingThreshold)) 像素")
        thresholdLabel.frame = NSRect(x: 20, y: 350, width: 200, height: 20)
        container.addSubview(thresholdLabel)
        
        let thresholdSlider = NSSlider(value: Double(dockingThreshold), minValue: 20, maxValue: 100, target: self, action: #selector(thresholdSliderChanged(_:)))
        thresholdSlider.frame = NSRect(x: 20, y: 320, width: 460, height: 20)
        container.addSubview(thresholdSlider)
        
        // 左侧面板宽度设置
        let leftWidthLabel = NSTextField(labelWithString: "左侧面板宽度: \(Int(leftDockWidth)) 像素")
        leftWidthLabel.frame = NSRect(x: 20, y: 280, width: 200, height: 20)
        container.addSubview(leftWidthLabel)
        
        let leftWidthSlider = NSSlider(value: Double(leftDockWidth), minValue: 150, maxValue: 400, target: self, action: #selector(leftWidthSliderChanged(_:)))
        leftWidthSlider.frame = NSRect(x: 20, y: 250, width: 460, height: 20)
        container.addSubview(leftWidthSlider)
        
        // 右侧面板宽度设置
        let rightWidthLabel = NSTextField(labelWithString: "右侧面板宽度: \(Int(rightDockWidth)) 像素")
        rightWidthLabel.frame = NSRect(x: 20, y: 210, width: 200, height: 20)
        container.addSubview(rightWidthLabel)
        
        let rightWidthSlider = NSSlider(value: Double(rightDockWidth), minValue: 150, maxValue: 400, target: self, action: #selector(rightWidthSliderChanged(_:)))
        rightWidthSlider.frame = NSRect(x: 20, y: 180, width: 460, height: 20)
        container.addSubview(rightWidthSlider)
        
        // 底部面板高度设置
        let bottomHeightLabel = NSTextField(labelWithString: "底部面板高度: \(Int(bottomDockHeight)) 像素")
        bottomHeightLabel.frame = NSRect(x: 20, y: 140, width: 200, height: 20)
        container.addSubview(bottomHeightLabel)
        
        let bottomHeightSlider = NSSlider(value: Double(bottomDockHeight), minValue: 100, maxValue: 400, target: self, action: #selector(bottomHeightSliderChanged(_:)))
        bottomHeightSlider.frame = NSRect(x: 20, y: 110, width: 460, height: 20)
        container.addSubview(bottomHeightSlider)
        
        // 保存按钮
        let saveButton = NSButton(title: "保存配置", target: self, action: #selector(saveSettingsButtonClicked(_:)))
        saveButton.frame = NSRect(x: 200, y: 50, width: 100, height: 30)
        container.addSubview(saveButton)
        
        // 重置按钮
        let resetButton = NSButton(title: "重置默认", target: self, action: #selector(resetSettingsButtonClicked(_:)))
        resetButton.frame = NSRect(x: 320, y: 50, width: 100, height: 30)
        container.addSubview(resetButton)
        
        return container
    }
    
    // MARK: 设置面板滑块回调
    @objc private func thresholdSliderChanged(_ sender: NSSlider) {
        dockingThreshold = CGFloat(sender.doubleValue)
        logger.debug("停靠阈值变更为: \(self.dockingThreshold)")
    }
    
    @objc private func leftWidthSliderChanged(_ sender: NSSlider) {
        leftDockWidth = CGFloat(sender.doubleValue)
        logger.debug("左侧面板宽度变更为: \(self.leftDockWidth)")
    }
    
    @objc private func rightWidthSliderChanged(_ sender: NSSlider) {
        rightDockWidth = CGFloat(sender.doubleValue)
        logger.debug("右侧面板宽度变更为: \(self.rightDockWidth)")
    }
    
    @objc private func bottomHeightSliderChanged(_ sender: NSSlider) {
        bottomDockHeight = CGFloat(sender.doubleValue)
        logger.debug("底部面板高度变更为: \(self.bottomDockHeight)")
    }
    
    @objc private func saveSettingsButtonClicked(_ sender: NSButton) {
        saveDockingConfiguration()
        logger.info("用户手动保存停靠配置")
    }
    
    @objc private func resetSettingsButtonClicked(_ sender: NSButton) {
        dockingThreshold = 40.0
        leftDockWidth = 250.0
        rightDockWidth = 250.0
        bottomDockHeight = 200.0
        resetDockingConfiguration()
        logger.info("用户重置停靠配置")
    }
    
    // MARK: 获取停靠面板统计信息
    /// 返回当前各停靠位置的面板数量
    public func dockingStatistics() -> [UIDockingPosition: Int] {
        lock.lock()
        var stats: [UIDockingPosition: Int] = [.left: 0, .right: 0, .bottom: 0, .floating: 0]
        for panel in panels.values {
            stats[panel.currentPosition, default: 0] += 1
        }
        lock.unlock()
        return stats
    }
    
    // MARK: 按位置获取面板列表
    /// 获取停靠在指定位置的所有面板
    public func panels(at position: UIDockingPosition) -> [UIDockablePanel] {
        lock.lock()
        let result = panels.values.filter { $0.currentPosition == position }
            .sorted { $0.orderIndex < $1.orderIndex }
        lock.unlock()
        return result
    }
    
    // MARK: 设置面板排序
    /// 设置面板在停靠区域中的显示顺序
    public func setPanelOrder(_ panelID: String, orderIndex: Int) {
        lock.lock()
        panels[panelID]?.orderIndex = orderIndex
        lock.unlock()
        
        if let panel = getPanel(panelID) {
            updatePanelInfo(panel)
        }
        logger.debug("面板 \(panelID) 排序变更为 \(orderIndex)")
    }
    
    // MARK: 释放资源
    deinit {
        // 移除所有通知监听
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        
        // 保存当前配置
        saveDockingConfiguration()
        
        // 隐藏指示器
        hideDockingIndicator()
        
        logger.info("停靠系统管理器已释放，配置已保存")
    }
}

// MARK: - 迁回自 UI-02：enum UIDockingPosition
// MARK: - UI-GL-56 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-56_types.swift
// 版本: 2.0
// MARK: - 停靠位置枚举
/// 定义面板可以停靠的四种位置
public enum UIDockingPosition: String, Codable, CaseIterable {
    case left     = "左侧"
    case right    = "右侧"
    case bottom   = "底部"
    case floating = "浮动"
    
    /// 获取位置的中文名称
    public var displayName: String {
        return self.rawValue
    }
    
    /// 获取位置对应的边缘描述
    public var edgeDescription: String {
        switch self {
        case .left:     return "窗口左边缘"
        case .right:    return "窗口右边缘"
        case .bottom:   return "窗口底部边缘"
        case .floating: return "浮动状态"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIDockingPanelInfo
// MARK: - 面板停靠信息模型
/// 用于持久化存储的停靠配置数据
public struct UIDockingPanelInfo: Codable, Identifiable {
    public let id: String
    public var position: UIDockingPosition
    public var isExpanded: Bool
    public var preferredWidth: CGFloat
    public var preferredHeight: CGFloat
    public var lastFloatingFrame: CGRect?
    public var orderIndex: Int
    
    public init(id: String,
                position: UIDockingPosition,
                isExpanded: Bool = true,
                preferredWidth: CGFloat = 250,
                preferredHeight: CGFloat = 400,
                lastFloatingFrame: CGRect? = nil,
                orderIndex: Int = 0) {
        self.id = id
        self.position = position
        self.isExpanded = isExpanded
        self.preferredWidth = preferredWidth
        self.preferredHeight = preferredHeight
        self.lastFloatingFrame = lastFloatingFrame
        self.orderIndex = orderIndex
    }
}

// MARK: - 迁回自 UI-02：enum UIDockingZone
// MARK: - 停靠区域类型
/// 定义可停靠的目标区域
public enum UIDockingZone: Equatable {
    case left
    case right
    case bottom
    case none
    
    /// 转换为停靠位置
    public var toPosition: UIDockingPosition {
        switch self {
        case .left:   return .left
        case .right:  return .right
        case .bottom: return .bottom
        case .none:   return .floating
        }
    }
    
    /// 获取区域的显示名称
    public var displayName: String {
        switch self {
        case .left:   return "左侧停靠区"
        case .right:  return "右侧停靠区"
        case .bottom: return "底部停靠区"
        case .none:   return "无"
        }
    }
}

// MARK: - 迁回自 UI-02：protocol UIDockablePanelProtocol
// MARK: - 可停靠面板协议
/// 定义可停靠面板必须实现的方法
public protocol UIDockablePanelProtocol: AnyObject {
    var panelID: String { get }
    var panelTitle: String { get }
    var contentView: NSView { get }
    var preferredSize: NSSize { get set }
    
    func willDock(to position: UIDockingPosition)
    func didDock(to position: UIDockingPosition)
    func willUndock()
    func didUndock()
}
