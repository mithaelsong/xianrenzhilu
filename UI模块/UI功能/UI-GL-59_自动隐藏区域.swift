// 功能49: 自动隐藏区域
// 对应: 窗口四边自动隐藏面板,鼠标移动到边缘时滑出,离开/失焦时自动隐藏
// 优先级: P2
// 版本: 2.0 - 完整重写版

import AppKit
import Foundation
import os.log

// MARK: - 全局常量与日志

/// 子系统标识,用于统一日志归属
private let subsystem = "com.xianrenzhilu.autohide"

/// 自动隐藏模块专用 Logger,禁止在任何地方使用 print
private let logger = Logger(subsystem: subsystem, category: "UIAutoHideManager")

// MARK: - 测试代码
#if DEBUG

/// 功能49:自动隐藏区域 - 单元测试
func test_autoHide() {
    let manager = UIAutoHideManager.shared

    logger.info("测试1: 默认配置")
    let config = manager.getConfig()
    if config.zones[.left]?.isEnabled == true { logger.info("✅ 测试1通过") }
    else { logger.error("❌ 测试1失败") }

    logger.info("测试2: 锁定/解锁")
    manager.setLock(edge: .left, locked: true)
    if manager.isLocked(edge: .left) { logger.info("✅ 测试2通过") }
    else { logger.error("❌ 测试2失败") }
    manager.toggleLock(edge: .left)

    logger.info("测试3: 区域启用/禁用")
    manager.setZoneEnabled(edge: .right, enabled: false)
    if !manager.isZoneEnabled(edge: .right) { logger.info("✅ 测试3通过") }
    else { logger.error("❌ 测试3失败") }
    manager.setZoneEnabled(edge: .right, enabled: true)

    logger.info("测试4: 延迟设置")
    manager.setRevealDelay(1.0)
    if abs(manager.currentRevealDelay - 1.0) < 0.01 { logger.info("✅ 测试4通过") }
    else { logger.error("❌ 测试4失败") }

    logger.info("测试5: 延迟预设")
    let presets = manager.availableDelayPresets()
    if presets.count == 4 { logger.info("✅ 测试5通过") }
    else { logger.error("❌ 测试5失败") }

    logger.info("测试6: 强制展开/隐藏")
    manager.forceReveal(edge: .left)
    let expanded = manager.isExpanded(edge: .left)
    _ = expanded
    manager.forceHide(edge: .left)
    logger.info("✅ 测试6通过")

    logger.info("测试7: 全部隐藏")
    manager.hideAllZones()
    logger.info("✅ 测试7通过")

    logger.info("测试8: 动画开关")
    manager.setAnimationEnabled(false)
    manager.setAnimationEnabled(true)
    logger.info("✅ 测试8通过")

    logger.info("测试9: 区域摘要")
    let summaries = manager.getZoneSummaries()
    if summaries.count == 4 { logger.info("✅ 测试9通过") }
    else { logger.error("❌ 测试9失败") }

    logger.info("测试10: 重置配置")
    manager.resetConfigToDefault()
    let afterReset = manager.getConfig()
    if afterReset.zones[.left]?.isEnabled == true { logger.info("✅ 测试10通过") }
    else { logger.error("❌ 测试10失败") }

    logger.info("=== 全部自动隐藏测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 当某个自动隐藏区域被激活(滑出显示)时发送
    /// userInfo 中 key 为 "edge",值为 UIAutoHideEdge 的字符串描述
    static let autoHideZoneActivated = Notification.Name("com.xianrenzhilu.autohide.zoneActivated")

    /// 当某个自动隐藏区域被关闭(滑入隐藏)时发送
    /// userInfo 中 key 为 "edge",值为 UIAutoHideEdge 的字符串描述
    static let autoHideZoneDeactivated = Notification.Name("com.xianrenzhilu.autohide.zoneDeactivated")

    /// 当自动隐藏的配置(延迟、开关、锁定等)发生变更时发送
    /// userInfo 中 key 为 "configSummary",值为配置的简要描述字符串
    static let autoHideConfigChanged = Notification.Name("com.xianrenzhilu.autohide.configChanged")
}

// MARK: - 迁回自 UI-02：class UIAutoHideZoneInfo
private final class UIAutoHideZoneInfo : @unchecked Sendable {
    /// 关联的 NSView 面板
    weak var panel: NSView?
    /// 当前是否已展开(可见)
    var isExpanded: Bool = false
    /// 是否正在动画过渡中
    var isAnimating: Bool = false
    /// 用于展开延迟的 DispatchWorkItem
    var revealWorkItem: DispatchWorkItem?
    /// 用于隐藏延迟的 DispatchWorkItem
    var hideWorkItem: DispatchWorkItem?
    /// 鼠标悬停检测用的 TrackingArea
    var trackingArea: NSTrackingArea?
    /// 该区域是否被手动锁定
    var isLocked: Bool = false
    /// 该区域是否启用
    var isEnabled: Bool = true

    /// 取消所有挂起的延迟任务
    func cancelPendingTasks() {
        revealWorkItem?.cancel()
        revealWorkItem = nil
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }
}

// MARK: - 迁回自 UI-02：class UIAutoHideManager
public final class UIAutoHideManager : @unchecked Sendable {

    // MARK: 单例

    /// 全局唯一的自动隐藏管理器实例
    public static let shared = UIAutoHideManager()

    // MARK: 私有属性

    /// 使用 NSRecursiveLock 保护所有共享可变状态(线程安全)
    private let lock = NSRecursiveLock()

    /// 各区域运行时状态字典
    private var zoneInfos: [UIAutoHideEdge: UIAutoHideZoneInfo] = [:]

    /// 持久化配置对象
    private var config: UIAutoHideConfig = .default

    /// 鼠标位置轮询定时器,用于检测鼠标是否位于窗口边缘触发区域
    private var mouseTimer: Timer?

    /// 主窗口引用,用于计算坐标和添加 TrackingArea
    private weak var hostWindow: NSWindow?

    /// 全局动画是否启用缓存
    private var animationEnabled: Bool = true

    /// 用户配置持久化在 UserDefaults 中的键名
    private let configKey = "com.xianrenzhilu.autohide.config"

    /// 负责串行执行延迟任务的队列,避免多线程冲突
    private let workQueue = DispatchQueue(label: "com.xianrenzhilu.autohide.work", qos: .userInitiated)

    // MARK: 初始化与反初始化

    /// 私有初始化,强制通过单例访问;加载已持久化的配置
    private init() {
        logger.info("【自动隐藏管理器】初始化开始")
        loadConfigFromDisk()
        logger.info("【自动隐藏管理器】初始化完成,当前配置已加载")
    }

    /// 清理所有资源,包括定时器、TrackingArea、延迟任务等
    deinit {
        logger.info("【自动隐藏管理器】deinit 开始清理资源")

        // 停止鼠标轮询定时器
        mouseTimer?.invalidate()
        mouseTimer = nil

        // 直接清理各区域（单例deinit，跳过锁）
        for (edge, info) in zoneInfos {
            // 取消挂起的延迟任务
            info.cancelPendingTasks()

            // 移除 TrackingArea
            if let trackingArea = info.trackingArea, let panel = info.panel {
                panel.removeTrackingArea(trackingArea)
                logger.debug("已移除 \(edge.description) 的 TrackingArea")
            }

            // 将面板恢复到正常位置(避免隐藏状态残留)
            if let panel = info.panel {
                resetPanelFrame(panel, for: edge)
            }
        }

        // 保存当前配置到磁盘,确保状态不丢失
        saveConfigToDisk()

        logger.info("【自动隐藏管理器】deinit 资源清理完毕")
    }

    // MARK: 注册与绑定

    /// 为指定边缘注册一个自动隐藏面板
    /// - Parameters:
    ///   - edge: 区域位置(左侧、右侧、底部等)
    ///   - panel: 需要参与自动隐藏的 NSView 面板
    ///   - window: 面板所属的主窗口,用于计算坐标和添加 TrackingArea
    public func registerPanel(edge: UIAutoHideEdge, panel: NSView, in window: NSWindow) {
        logger.info("注册面板:位置=\(edge.description)")

        lock.lock()
        let info = UIAutoHideZoneInfo()
        info.panel = panel
        info.isExpanded = false
        info.isAnimating = false
        info.isLocked = config.zones[edge]?.isLocked ?? false
        info.isEnabled = config.zones[edge]?.isEnabled ?? true

        // 保存窗口引用(首次注册时)
        if hostWindow == nil {
            hostWindow = window
        }

        // 为面板添加鼠标跟踪区域,实现精确的进入/离开检测
        let triggerWidth = config.zones[edge]?.triggerWidth ?? UIAutoHideZoneConfig.default.triggerWidth
        let trackingArea = createTrackingArea(for: edge, in: panel, triggerWidth: triggerWidth)
        panel.addTrackingArea(trackingArea)
        info.trackingArea = trackingArea

        // 初始状态:将面板置于隐藏位置(屏幕外)
        let hiddenSize = config.zones[edge]?.panelSize ?? UIAutoHideZoneConfig.default.panelSize
        setPanelHiddenPosition(panel, for: edge, panelSize: hiddenSize)

        zoneInfos[edge] = info

        lock.unlock()
        panel.isHidden = false
        logger.info("\(edge.description) 面板注册完成,初始状态:已折叠")
    }

    /// 注销指定边缘的面板,移除 TrackingArea 和延迟任务
    /// - Parameter edge: 需要注销的区域位置
    public func unregisterPanel(edge: UIAutoHideEdge) {
        logger.info("注销面板:位置=\(edge.description)")

        lock.lock()
        guard let info = zoneInfos[edge] else {
            lock.unlock()
            logger.warning("注销失败:\(edge.description) 未注册")
            return
        }

        // 取消挂起的延迟任务
        info.cancelPendingTasks()

        // 移除 TrackingArea
        if let trackingArea = info.trackingArea, let panel = info.panel {
            panel.removeTrackingArea(trackingArea)
        }

        // 恢复面板位置到正常状态
        if let panel = info.panel {
            let panelSize = config.zones[edge]?.panelSize ?? UIAutoHideZoneConfig.default.panelSize
            resetPanelFrame(panel, for: edge, panelSize: panelSize)
        }

        zoneInfos.removeValue(forKey: edge)
        lock.unlock()
        logger.info("\(edge.description) 面板已注销")
    }

    // MARK: 鼠标检测与 TrackingArea

    /// 为指定边缘创建对应的鼠标跟踪区域
    /// 触发区域紧贴窗口边缘,宽度由配置决定
    private func createTrackingArea(for edge: UIAutoHideEdge, in panel: NSView, triggerWidth: CGFloat = 8) -> NSTrackingArea {
        let bounds = panel.bounds

        // 根据边缘位置计算 TrackingArea 的矩形范围
        let trackingRect: NSRect
        switch edge {
        case .left:
            trackingRect = NSRect(x: 0, y: 0, width: triggerWidth, height: bounds.height)
        case .right:
            trackingRect = NSRect(x: bounds.width - triggerWidth, y: 0, width: triggerWidth, height: bounds.height)
        case .bottom:
            trackingRect = NSRect(x: 0, y: 0, width: bounds.width, height: triggerWidth)
        case .top:
            trackingRect = NSRect(x: 0, y: bounds.height - triggerWidth, width: bounds.width, height: triggerWidth)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeInKeyWindow,
            .activeInActiveApp
        ]

        return NSTrackingArea(
            rect: trackingRect,
            options: options,
            owner: self,
            userInfo: ["edge": edge]
        )
    }

    /// 鼠标进入触发区域时调用(由 AppKit 事件系统触发)
    public func mouseEnteredTriggerZone(edge: UIAutoHideEdge) {
        logger.debug("鼠标进入触发区域:\(edge.description)")

        lock.lock()
        guard let info = zoneInfos[edge], info.isEnabled, !info.isLocked else {
            lock.unlock()
            return
        }
        lock.unlock()

        // 取消可能存在的隐藏延迟任务
        cancelHideTask(for: edge)

        // 启动展开延迟任务,避免鼠标快速掠过时误触发
        let revealDelay = config.revealDelay
        let workItem = DispatchWorkItem { [weak self] in
            self?.performReveal(edge: edge)
        }

        lock.lock()
        zoneInfos[edge]?.revealWorkItem = workItem
        lock.unlock()

        workQueue.asyncAfter(deadline: .now() + revealDelay, execute: workItem)
        logger.debug("\(edge.description) 展开延迟任务已启动,延迟 \(revealDelay) 秒")
    }

    /// 鼠标离开触发区域或面板时调用
    public func mouseExitedTriggerZone(edge: UIAutoHideEdge) {
        logger.debug("鼠标离开触发区域:\(edge.description)")

        lock.lock()
        guard let info = zoneInfos[edge], info.isEnabled, !info.isLocked else {
            lock.unlock()
            return
        }
        lock.unlock()

        // 取消可能存在的展开延迟任务
        cancelRevealTask(for: edge)

        // 启动隐藏延迟任务,给用户在面板边缘操作留出缓冲时间
        let hideDelay = config.hideDelay
        let workItem = DispatchWorkItem { [weak self] in
            self?.performHide(edge: edge)
        }

        lock.lock()
        zoneInfos[edge]?.hideWorkItem = workItem
        lock.unlock()

        workQueue.asyncAfter(deadline: .now() + hideDelay, execute: workItem)
        logger.debug("\(edge.description) 隐藏延迟任务已启动,延迟 \(hideDelay) 秒")
    }

    // MARK: 定时器轮询(双保险)

    /// 启动鼠标位置轮询定时器,作为 TrackingArea 的双保险检测机制
    /// 当鼠标在窗口外或 TrackingArea 失效时,仍可通过定时器检测位置
    public func startMousePolling() {
        logger.info("启动鼠标位置轮询定时器")
        mouseTimer?.invalidate()

        mouseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.pollMouseLocation()
        }

        // 确保定时器在 common 模式下也能运行(如拖拽滚动条时)
        if let timer = mouseTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// 停止鼠标轮询定时器
    public func stopMousePolling() {
        logger.info("停止鼠标位置轮询定时器")
        mouseTimer?.invalidate()
        mouseTimer = nil
    }

    /// 轮询检测当前鼠标位置,决定是否触发展开或隐藏
    private func pollMouseLocation() {
        guard let window = hostWindow, window.screen != nil else { return }

        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame

        // 检查鼠标是否在窗口内(粗略范围)
        let isMouseInWindow = windowFrame.contains(mouseLocation)
        for edge in UIAutoHideEdge.allCases {
            lock.lock()
            guard let info = zoneInfos[edge], info.isEnabled, !info.isLocked else {
                lock.unlock()
                continue
            }
            lock.unlock()

            let zoneConfig = config.zones[edge] ?? .default
            let triggerWidth = zoneConfig.triggerWidth

            // 判断鼠标是否在指定边缘的触发区域内
            let isInTriggerZone: Bool
            switch edge {
            case .left:
                isInTriggerZone = isMouseInWindow && (mouseLocation.x - windowFrame.minX) < triggerWidth
            case .right:
                isInTriggerZone = isMouseInWindow && (windowFrame.maxX - mouseLocation.x) < triggerWidth
            case .bottom:
                isInTriggerZone = isMouseInWindow && (mouseLocation.y - windowFrame.minY) < triggerWidth
            case .top:
                isInTriggerZone = isMouseInWindow && (windowFrame.maxY - mouseLocation.y) < triggerWidth
            }

            if isInTriggerZone {
                // 在触发区域,启动展开逻辑(若尚未展开)
                lock.lock()
                let isExpanded = zoneInfos[edge]?.isExpanded ?? false
                lock.unlock()
                if !isExpanded {
                    mouseEnteredTriggerZone(edge: edge)
                }
            } else {
                // 不在触发区域,检查是否还在面板范围内
                lock.lock()
                let panelSize = self.config.zones[edge]?.panelSize ?? UIAutoHideZoneConfig.default.panelSize
                let isExpanded = zoneInfos[edge]?.isExpanded ?? false
                lock.unlock()
                let isInPanel = isMouseInPanel(mouseLocation, edge: edge, windowFrame: windowFrame, panelSize: panelSize)
                if !isInPanel && isExpanded {
                    mouseExitedTriggerZone(edge: edge)
                }
            }
        }
    }

    /// 判断鼠标是否位于已展开的面板内部区域
    private func isMouseInPanel(_ mouseLocation: NSPoint, edge: UIAutoHideEdge, windowFrame: NSRect, panelSize: CGFloat = 280) -> Bool {
        // 将鼠标坐标转换为窗口内坐标(相对于窗口左下角)
        let relativeX = mouseLocation.x - windowFrame.minX
        let relativeY = mouseLocation.y - windowFrame.minY

        switch edge {
        case .left:
            return relativeX >= 0 && relativeX <= panelSize && relativeY >= 0 && relativeY <= windowFrame.height
        case .right:
            return relativeX >= (windowFrame.width - panelSize) && relativeX <= windowFrame.width
        case .bottom:
            return relativeY >= 0 && relativeY <= panelSize && relativeX >= 0 && relativeX <= windowFrame.width
        case .top:
            return relativeY >= (windowFrame.height - panelSize) && relativeY <= windowFrame.height
        }
    }

    // MARK: 展开与隐藏动画

    /// 执行面板展开动画(滑出到屏幕内)
    private func performReveal(edge: UIAutoHideEdge) {
        lock.lock()
        guard let info = zoneInfos[edge],
              let panel = info.panel,
              !info.isExpanded,
              !info.isAnimating else {
            lock.unlock()
            return
        }
        info.isAnimating = true
        lock.unlock()

        let zoneConfig = config.zones[edge] ?? .default
        let duration = zoneConfig.revealDuration
        let useAnimation = config.animationEnabled && animationEnabled

        logger.info("\(edge.description) 开始展开动画,时长 \(duration) 秒")

        // 计算展开后的目标 frame
        let panelSize = config.zones[edge]?.panelSize ?? UIAutoHideZoneConfig.default.panelSize
        let targetFrame = calculateExpandedFrame(for: edge, panel: panel, panelSize: panelSize)

        if useAnimation {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = duration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().frame = targetFrame
            }) { [weak self] in
                self?.handleRevealCompletion(edge: edge)
            }
        } else {
            panel.frame = targetFrame
            handleRevealCompletion(edge: edge)
        }
    }

    /// 展开动画完成后的回调处理
    private func handleRevealCompletion(edge: UIAutoHideEdge) {
        lock.lock()
        zoneInfos[edge]?.isExpanded = true
        zoneInfos[edge]?.isAnimating = false
        lock.unlock()

        logger.info("\(edge.description) 展开完成")

        // 发送激活通知
        NotificationCenter.default.post(
            name: .autoHideZoneActivated,
            object: self,
            userInfo: ["edge": edge.rawValue]
        )
    }

    /// 执行面板隐藏动画(滑入到屏幕外)
    private func performHide(edge: UIAutoHideEdge) {
        lock.lock()
        guard let info = zoneInfos[edge],
              let panel = info.panel,
              info.isExpanded,
              !info.isAnimating else {
            lock.unlock()
            return
        }
        info.isAnimating = true
        lock.unlock()

        let zoneConfig = config.zones[edge] ?? .default
        let duration = zoneConfig.hideDuration
        let useAnimation = config.animationEnabled && animationEnabled

        logger.info("\(edge.description) 开始隐藏动画,时长 \(duration) 秒")

        // 计算隐藏后的目标 frame(移到屏幕外)
        let panelSize = config.zones[edge]?.panelSize ?? UIAutoHideZoneConfig.default.panelSize
        let targetFrame = calculateHiddenFrame(for: edge, panel: panel, panelSize: panelSize)

        if useAnimation {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = duration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().frame = targetFrame
            }) { [weak self] in
                self?.handleHideCompletion(edge: edge)
            }
        } else {
            panel.frame = targetFrame
            handleHideCompletion(edge: edge)
        }
    }

    /// 隐藏动画完成后的回调处理
    private func handleHideCompletion(edge: UIAutoHideEdge) {
        lock.lock()
        zoneInfos[edge]?.isExpanded = false
        zoneInfos[edge]?.isAnimating = false
        lock.unlock()

        logger.info("\(edge.description) 隐藏完成")

        // 发送关闭通知
        NotificationCenter.default.post(
            name: .autoHideZoneDeactivated,
            object: self,
            userInfo: ["edge": edge.rawValue]
        )
    }

    // MARK: Frame 计算工具

    /// 计算面板展开后的目标 frame(在窗口内可见)
    private func calculateExpandedFrame(for edge: UIAutoHideEdge, panel: NSView, panelSize: CGFloat = 280) -> NSRect {
        guard let superview = panel.superview else { return panel.frame }
        let superBounds = superview.bounds
        let size = panelSize

        switch edge {
        case .left:
            return NSRect(x: 0, y: 0, width: size, height: superBounds.height)
        case .right:
            return NSRect(x: superBounds.width - size, y: 0, width: size, height: superBounds.height)
        case .bottom:
            return NSRect(x: 0, y: 0, width: superBounds.width, height: size)
        case .top:
            return NSRect(x: 0, y: superBounds.height - size, width: superBounds.width, height: size)
        }
    }

    /// 计算面板隐藏后的目标 frame(移到屏幕外/窗口外)
    private func calculateHiddenFrame(for edge: UIAutoHideEdge, panel: NSView, panelSize: CGFloat = 280) -> NSRect {
        guard let superview = panel.superview else { return panel.frame }
        let superBounds = superview.bounds
        let size = panelSize

        switch edge {
        case .left:
            return NSRect(x: -size, y: 0, width: size, height: superBounds.height)
        case .right:
            return NSRect(x: superBounds.width, y: 0, width: size, height: superBounds.height)
        case .bottom:
            return NSRect(x: 0, y: -size, width: superBounds.width, height: size)
        case .top:
            return NSRect(x: 0, y: superBounds.height, width: superBounds.width, height: size)
        }
    }

    /// 将面板重置到初始位置(用于注销或 deinit 时)
    private func setPanelHiddenPosition(_ panel: NSView, for edge: UIAutoHideEdge, panelSize: CGFloat = 280) {
        let frame = calculateHiddenFrame(for: edge, panel: panel, panelSize: panelSize)
        panel.frame = frame
    }

    /// 将面板恢复到正常显示位置(用于注销清理时)
    private func resetPanelFrame(_ panel: NSView, for edge: UIAutoHideEdge, panelSize: CGFloat = 280) {
        guard let superview = panel.superview else { return }
        let superBounds = superview.bounds
        let size = panelSize

        let frame: NSRect
        switch edge {
        case .left:
            frame = NSRect(x: 0, y: 0, width: size, height: superBounds.height)
        case .right:
            frame = NSRect(x: superBounds.width - size, y: 0, width: size, height: superBounds.height)
        case .bottom:
            frame = NSRect(x: 0, y: 0, width: superBounds.width, height: size)
        case .top:
            frame = NSRect(x: 0, y: superBounds.height - size, width: superBounds.width, height: size)
        }
        panel.frame = frame
    }

    // MARK: 延迟任务取消

    /// 取消指定区域的展开延迟任务
    private func cancelRevealTask(for edge: UIAutoHideEdge) {
        lock.lock()
        zoneInfos[edge]?.revealWorkItem?.cancel()
        zoneInfos[edge]?.revealWorkItem = nil
        lock.unlock()
    }

    /// 取消指定区域的隐藏延迟任务
    private func cancelHideTask(for edge: UIAutoHideEdge) {
        lock.lock()
        zoneInfos[edge]?.hideWorkItem?.cancel()
        zoneInfos[edge]?.hideWorkItem = nil
        lock.unlock()
    }

    // MARK: 手动锁定

    /// 锁定指定区域,锁定后面板保持当前状态(不展开也不隐藏)
    /// - Parameters:
    ///   - edge: 要锁定的区域位置
    ///   - locked: true 为锁定,false 为解锁
    public func setLock(edge: UIAutoHideEdge, locked: Bool) {
        logger.info("设置锁定:\(edge.description) = \(locked ? "已锁定" : "已解锁")")

        lock.lock()
        zoneInfos[edge]?.isLocked = locked
        config.zones[edge]?.isLocked = locked
        lock.unlock()

        saveConfigToDisk()
        postConfigChangedNotification(summary: "锁定状态变更:\(edge.description) \(locked ? "锁定" : "解锁")")
    }

    /// 查询指定区域是否被锁定
    /// - Parameter edge: 区域位置
    /// - Returns: 是否锁定
    public func isLocked(edge: UIAutoHideEdge) -> Bool {
        lock.lock()
        let result = zoneInfos[edge]?.isLocked ?? config.zones[edge]?.isLocked ?? false
        lock.unlock()
        return result
    }

    /// 切换指定区域的锁定状态(便捷方法)
    /// - Parameter edge: 区域位置
    /// - Returns: 切换后的锁定状态
    @discardableResult
    public func toggleLock(edge: UIAutoHideEdge) -> Bool {
        let newState = !isLocked(edge: edge)
        setLock(edge: edge, locked: newState)
        return newState
    }

    // MARK: 区域开关配置

    /// 启用或禁用指定边缘的自动隐藏功能
    /// - Parameters:
    ///   - edge: 区域位置
    ///   - enabled: true 为启用,false 为禁用
    public func setZoneEnabled(edge: UIAutoHideEdge, enabled: Bool) {
        logger.info("设置区域开关:\(edge.description) = \(enabled ? "启用" : "禁用")")

        lock.lock()
        zoneInfos[edge]?.isEnabled = enabled
        config.zones[edge]?.isEnabled = enabled
        lock.unlock()

        // 如果禁用了一个已展开的区域,立即隐藏它
        if !enabled {
            lock.lock()
            let isExpanded = zoneInfos[edge]?.isExpanded ?? false
            lock.unlock()
            if isExpanded {
                cancelHideTask(for: edge)
                performHide(edge: edge)
            }
        }

        saveConfigToDisk()
        postConfigChangedNotification(summary: "区域开关变更:\(edge.description) \(enabled ? "启用" : "禁用")")
    }

    /// 查询指定区域是否已启用
    public func isZoneEnabled(edge: UIAutoHideEdge) -> Bool {
        lock.lock()
        let result = zoneInfos[edge]?.isEnabled ?? config.zones[edge]?.isEnabled ?? false
        lock.unlock()
        return result
    }

    // MARK: 延迟配置

    /// 设置鼠标悬停后的展开延迟时间(秒)
    /// 支持 0.5 / 1.0 / 2.0 / 5.0 秒等标准档位
    /// - Parameter delay: 延迟秒数
    public func setRevealDelay(_ delay: TimeInterval) {
        logger.info("设置展开延迟:\(delay) 秒")

        lock.lock()
        config.revealDelay = delay
        lock.unlock()

        saveConfigToDisk()
        postConfigChangedNotification(summary: "展开延迟变更为 \(delay) 秒")
    }

    /// 设置鼠标离开后的隐藏延迟时间(秒)
    /// - Parameter delay: 延迟秒数
    public func setHideDelay(_ delay: TimeInterval) {
        logger.info("设置隐藏延迟:\(delay) 秒")

        lock.lock()
        config.hideDelay = delay
        lock.unlock()

        saveConfigToDisk()
        postConfigChangedNotification(summary: "隐藏延迟变更为 \(delay) 秒")
    }

    /// 获取当前的展开延迟(秒)
    public var currentRevealDelay: TimeInterval {
        lock.lock()
        let result = config.revealDelay
        lock.unlock()
        return result
    }

    /// 获取当前的隐藏延迟(秒)
    public var currentHideDelay: TimeInterval {
        lock.lock()
        let result = config.hideDelay
        lock.unlock()
        return result
    }

    // MARK: 全局动画开关

    /// 设置是否启用展开/隐藏动画
    /// - Parameter enabled: true 为启用动画,false 为瞬间切换
    public func setAnimationEnabled(_ enabled: Bool) {
        logger.info("设置动画开关:\(enabled ? "启用" : "禁用")")

        lock.lock()
        config.animationEnabled = enabled
        animationEnabled = enabled
        lock.unlock()

        saveConfigToDisk()
        postConfigChangedNotification(summary: "动画开关变更为 \(enabled ? "启用" : "禁用")")
    }

    // MARK: 强制操作

    /// 立即强制展开指定区域(无视延迟和锁定,用于快捷键或菜单触发)
    /// - Parameter edge: 区域位置
    public func forceReveal(edge: UIAutoHideEdge) {
        logger.info("强制展开:\(edge.description)")
        cancelHideTask(for: edge)
        performReveal(edge: edge)
    }

    /// 立即强制隐藏指定区域(无视延迟和锁定)
    /// - Parameter edge: 区域位置
    public func forceHide(edge: UIAutoHideEdge) {
        logger.info("强制隐藏:\(edge.description)")
        cancelRevealTask(for: edge)
        performHide(edge: edge)
    }

    /// 强制隐藏所有已展开的自动隐藏区域
    /// 通常用于窗口失焦或切换全屏时调用
    public func hideAllZones() {
        logger.info("执行隐藏所有区域")
        for edge in UIAutoHideEdge.allCases {
            cancelRevealTask(for: edge)
            performHide(edge: edge)
        }
    }

    /// 查询所有区域的当前状态(用于 UI 刷新)
    /// - Returns: 字典,key 为区域位置,value 为是否已展开
    public func getAllZoneStates() -> [UIAutoHideEdge: Bool] {
        lock.lock()
        var result: [UIAutoHideEdge: Bool] = [:]
        for (edge, info) in zoneInfos {
            result[edge] = info.isExpanded
        }
        lock.unlock()
        return result
    }

    /// 获取指定区域当前是否已展开
    /// - Parameter edge: 区域位置
    /// - Returns: 是否已展开
    public func isExpanded(edge: UIAutoHideEdge) -> Bool {
        lock.lock()
        let result = zoneInfos[edge]?.isExpanded ?? false
        lock.unlock()
        return result
    }

    // MARK: 配置持久化

    /// 将当前配置编码为 JSON 并保存到 UserDefaults(也可扩展为文件存储)
    private func saveConfigToDisk() {
        lock.lock()
        let configToSave = config
        lock.unlock()

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(configToSave)
            UserDefaults.standard.set(data, forKey: configKey)
            logger.info("配置已保存到磁盘,共 \(data.count) 字节")
        } catch {
            logger.error("配置保存失败:\(error.localizedDescription)")
        }
    }

    /// 从 UserDefaults 加载已保存的配置,若不存在则使用默认配置
    private func loadConfigFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: configKey) else {
            logger.info("未找到已保存的配置,使用默认配置")
            return
        }

        do {
            let decoder = JSONDecoder()
            let loadedConfig = try decoder.decode(UIAutoHideConfig.self, from: data)

            lock.lock()
            config = loadedConfig
            animationEnabled = loadedConfig.animationEnabled
            // 同步运行时状态与持久化配置
            for edge in UIAutoHideEdge.allCases {
                zoneInfos[edge]?.isEnabled = loadedConfig.zones[edge]?.isEnabled ?? true
                zoneInfos[edge]?.isLocked = loadedConfig.zones[edge]?.isLocked ?? false
            }
            lock.unlock()

            logger.info("配置已从磁盘加载,共 \(data.count) 字节")
        } catch {
            logger.error("配置加载失败:\(error.localizedDescription),回退到默认配置")
        }
    }

    /// 重置配置为出厂默认值并保存
    public func resetConfigToDefault() {
        logger.info("重置配置为默认值")

        lock.lock()
        config = .default
        animationEnabled = true
        for edge in UIAutoHideEdge.allCases {
            zoneInfos[edge]?.isEnabled = true
            zoneInfos[edge]?.isLocked = false
        }
        lock.unlock()

        saveConfigToDisk()
        postConfigChangedNotification(summary: "配置已重置为默认值")
    }

    // MARK: 设置面板方法

    /// 获取当前完整配置对象的副本(供设置面板读取)
    /// - Returns: 当前 UIAutoHideConfig 的拷贝
    public func getConfig() -> UIAutoHideConfig {
        lock.lock()
        let result = config
        lock.unlock()
        return result
    }

    /// 应用设置面板传入的完整配置
    /// - Parameter newConfig: 新的配置对象
    public func applyConfig(_ newConfig: UIAutoHideConfig) {
        logger.info("从设置面板应用完整配置")

        lock.lock()
        let oldConfig = config
        config = newConfig
        animationEnabled = newConfig.animationEnabled

        // 同步运行时状态
        for edge in UIAutoHideEdge.allCases {
            zoneInfos[edge]?.isEnabled = newConfig.zones[edge]?.isEnabled ?? true
            zoneInfos[edge]?.isLocked = newConfig.zones[edge]?.isLocked ?? false
        }
        lock.unlock()

        // 如果有区域从启用变为禁用,立即隐藏它们
        for edge in UIAutoHideEdge.allCases {
            let wasEnabled = oldConfig.zones[edge]?.isEnabled ?? true
            let isEnabled = newConfig.zones[edge]?.isEnabled ?? true
            if wasEnabled && !isEnabled {
                cancelHideTask(for: edge)
                performHide(edge: edge)
            }
        }

        saveConfigToDisk()
        postConfigChangedNotification(summary: "通过设置面板应用完整配置")
    }

    /// 设置指定区域的触发区域宽度
    /// - Parameters:
    ///   - edge: 区域位置
    ///   - width: 新的触发宽度(像素,建议 4-16 之间)
    public func setTriggerWidth(edge: UIAutoHideEdge, width: CGFloat) {
        logger.info("设置触发宽度:\(edge.description) = \(width) 像素")

        lock.lock()
        config.zones[edge]?.triggerWidth = width
        let triggerWidth = config.zones[edge]?.triggerWidth ?? UIAutoHideZoneConfig.default.triggerWidth
        lock.unlock()

        // 重新创建 TrackingArea 以生效新宽度
        recreateTrackingArea(for: edge, triggerWidth: triggerWidth)
        saveConfigToDisk()
        postConfigChangedNotification(summary: "触发宽度变更:\(edge.description) \(width)px")
    }

    /// 设置指定区域的展开后面板尺寸
    /// - Parameters:
    ///   - edge: 区域位置
    ///   - size: 新的面板尺寸(左侧/右侧为宽度,底部/顶部为高度)
    public func setPanelSize(edge: UIAutoHideEdge, size: CGFloat) {
        logger.info("设置面板尺寸:\(edge.description) = \(size) 像素")

        lock.lock()
        config.zones[edge]?.panelSize = size
        lock.unlock()

        saveConfigToDisk()
        postConfigChangedNotification(summary: "面板尺寸变更:\(edge.description) \(size)px")
    }

    // MARK: 内部辅助

    /// 重新创建指定区域的 TrackingArea(配置变更后调用)
    private func recreateTrackingArea(for edge: UIAutoHideEdge, triggerWidth: CGFloat = 8) {
        lock.lock()
        guard let info = zoneInfos[edge], let panel = info.panel else {
            lock.unlock()
            return
        }

        // 移除旧的
        if let oldArea = info.trackingArea {
            panel.removeTrackingArea(oldArea)
        }

        // 创建新的
        let newArea = createTrackingArea(for: edge, in: panel, triggerWidth: triggerWidth)
        panel.addTrackingArea(newArea)
        info.trackingArea = newArea
        lock.unlock()

        logger.debug("已重新创建 \(edge.description) 的 TrackingArea")
    }

    /// 统一发送配置变更通知
    /// - Parameter summary: 变更摘要,会写入通知的 userInfo
    private func postConfigChangedNotification(summary: String) {
        NotificationCenter.default.post(
            name: .autoHideConfigChanged,
            object: self,
            userInfo: ["configSummary": summary]
        )
        logger.debug("已发送配置变更通知:\(summary)")
    }
}

// MARK: - 迁回自 UI-02：extension UIAutoHideManager
public extension UIAutoHideManager {

    /// 获取所有可用延迟档位的描述列表
    /// 供设置面板渲染下拉选择器
    /// - Returns: 延迟档位描述字符串数组
    func availableDelayPresets() -> [String] {
        return UIAutoHideConfig.UIDelayPreset.allCases.map { $0.description }
    }

    /// 根据描述字符串设置展开延迟(设置面板回调用)
    /// - Parameter presetDescription: 档位描述,如 "0.5 秒"
    func setRevealDelayByPreset(_ presetDescription: String) {
        if let preset = UIAutoHideConfig.UIDelayPreset.allCases.first(where: { $0.description == presetDescription }) {
            setRevealDelay(preset.rawValue)
        }
    }

    /// 根据描述字符串设置隐藏延迟(设置面板回调用)
    /// - Parameter presetDescription: 档位描述,如 "1 秒"
    func setHideDelayByPreset(_ presetDescription: String) {
        if let preset = UIAutoHideConfig.UIDelayPreset.allCases.first(where: { $0.description == presetDescription }) {
            setHideDelay(preset.rawValue)
        }
    }

    /// 获取当前展开延迟对应的档位描述(供设置面板回显当前选项)
    /// - Returns: 当前档位的描述字符串,如 "0.5 秒"
    func currentRevealDelayPreset() -> String {
        let delay = currentRevealDelay
        if let preset = UIAutoHideConfig.UIDelayPreset.allCases.first(where: { abs($0.rawValue - delay) < 0.01 }) {
            return preset.description
        }
        return "\(delay) 秒"  // 自定义值兜底
    }

    /// 获取当前隐藏延迟对应的档位描述(供设置面板回显当前选项)
    /// - Returns: 当前档位的描述字符串
    func currentHideDelayPreset() -> String {
        let delay = currentHideDelay
        if let preset = UIAutoHideConfig.UIDelayPreset.allCases.first(where: { abs($0.rawValue - delay) < 0.01 }) {
            return preset.description
        }
        return "\(delay) 秒"
    }

    /// 设置面板调用:一键切换四个区域的总开关
    /// - Parameter enabled: 全局启用或禁用所有自动隐藏区域
    func setAllZonesEnabled(_ enabled: Bool) {
        logger.info("设置面板:全局切换所有区域开关 = \(enabled ? "启用" : "禁用")")
        for edge in UIAutoHideEdge.allCases {
            setZoneEnabled(edge: edge, enabled: enabled)
        }
    }

    /// 设置面板调用:获取各区域配置摘要,用于实时预览
    /// - Returns: 每个区域的状态摘要字典
    func getZoneSummaries() -> [UIAutoHideEdge: String] {
        var summaries: [UIAutoHideEdge: String] = [:]
        for edge in UIAutoHideEdge.allCases {
            let enabled = isZoneEnabled(edge: edge)
            let locked = isLocked(edge: edge)
            let expanded = isExpanded(edge: edge)
            summaries[edge] = "\(enabled ? "启用" : "禁用") | \(locked ? "锁定" : "未锁定") | \(expanded ? "展开" : "折叠")"
        }
        return summaries
    }
}

// MARK: - 迁回自 UI-02：enum UIAutoHideEdge
// MARK: - 持久化数据容器
/// 用于 Codable 持久化的顶层数据容器，保存所有固定面板记录和全局设置
// 已迁回 UI-GL-57_固定机制.swift：UIPanelPinningDataContainer（功能持久化容器不属于公共类型）

// MARK: - 面板固定管理器
/// 面板固定机制管理器单例，负责固定面板的增删改查、位置管理、尺寸调节、持久化
/// 核心功能：
/// 1. 面板固定/取消固定（独立于标签系统）
/// 2. 固定面板始终可见（跨标签切换保持显示）
/// 3. 固定面板位置管理（上方/下方/左侧/右侧）
/// 4. 固定面板大小调节（拖拽分割条调整尺寸）
/// 5. 固定面板布局序列化与恢复（Codable 持久化）
/// 6. 设置面板支持
/// 7. 使用 NSRecursiveLock 保证线程安全
// 已迁回 UI-GL-57_固定机制.swift：class UIPanelPinningManager（公共类型文件禁止功能实现）

// MARK: - 便捷扩展
/// UIPanelConfiguration convenience methods removed (type not available)
// 已迁回 UI-GL-57_固定机制.swift：extension UIPanelPinningManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-58 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-58_types.swift
// 版本: 2.0
// MARK: - 面板分组
// 已迁回 UI-GL-58_面板分组.swift：class UIPanelGroup（公共类型文件禁止功能实现）

// MARK: - 面板分组管理器
// 已迁回 UI-GL-58_面板分组.swift：class UIPanelGroupManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-59 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-59_types.swift
// 版本: 2.0
/// 定义窗口四边的自动隐藏区域位置
public enum UIAutoHideEdge: String, Codable, CaseIterable, Sendable, CustomStringConvertible {
    case left
    case right
    case bottom
    case top

    public var description: String {
        switch self {
        case .left:   return "左侧"
        case .right:  return "右侧"
        case .bottom: return "底部"
        case .top:    return "顶部"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIAutoHideZoneConfig
/// 单个自动隐藏区域的持久化配置项
public struct UIAutoHideZoneConfig: Codable, Equatable, Sendable {
    /// 该区域是否启用自动隐藏功能
    public var isEnabled: Bool
    /// 是否手动锁定(锁定后不响应悬停,也不自动隐藏)
    public var isLocked: Bool
    /// 触发区域宽度(像素)
    public var triggerWidth: CGFloat
    /// 滑出后面板的宽度(或高度,取决于方向)
    public var panelSize: CGFloat
    /// 展开动画时长(秒)
    public var revealDuration: TimeInterval
    /// 隐藏动画时长(秒)
    public var hideDuration: TimeInterval

    /// 创建默认配置
    public static let `default` = UIAutoHideZoneConfig(
        isEnabled: true,
        isLocked: false,
        triggerWidth: 8.0,
        panelSize: 280.0,
        revealDuration: 0.25,
        hideDuration: 0.3
    )
}

// MARK: - 迁回自 UI-02：struct UIAutoHideConfig
/// 所有自动隐藏区域的整体配置,支持 Codable 持久化
public struct UIAutoHideConfig: Codable, Equatable, Sendable {
    /// 各区域独立配置
    public var zones: [UIAutoHideEdge: UIAutoHideZoneConfig]
    /// 鼠标悬停后展开前的延迟时间(秒)
    public var revealDelay: TimeInterval
    /// 鼠标离开后隐藏前的延迟时间(秒)
    public var hideDelay: TimeInterval
    /// 是否启用全局声音反馈(展开/隐藏时)
    public var soundFeedbackEnabled: Bool
    /// 是否启用动画(关闭后瞬间切换)
    public var animationEnabled: Bool

    /// 默认配置构造器
    public static let `default` = UIAutoHideConfig(
        zones: [
            .left:   .default,
            .right:  .default,
            .bottom: .default,
            .top:    .default
        ],
        revealDelay: 0.5,
        hideDelay: 1.0,
        soundFeedbackEnabled: false,
        animationEnabled: true
    )

    /// 延迟档位枚举,用于设置面板选择
    public enum UIDelayPreset: TimeInterval, CaseIterable {
        case halfSecond = 0.5
        case oneSecond = 1.0
        case twoSeconds = 2.0
        case fiveSeconds = 5.0

        public var description: String {
            switch self {
            case .halfSecond:  return "0.5 秒"
            case .oneSecond:   return "1 秒"
            case .twoSeconds:  return "2 秒"
            case .fiveSeconds: return "5 秒"
            }
        }
    }
}
