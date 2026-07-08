// 模块04: 多屏幕支持
// 版本: 2.0
// 功能: 管理窗口在多屏幕间的行为，自动适配分辨率/DPI变化，记录每个屏幕的窗口位置
// 优先级: P1
// 作者: 码农
// 更新: 2026-06-10

import Foundation
import AppKit
import os.log

// MARK: - 屏幕变更通知
/// 多屏幕相关通知名称
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：internal extension NSScreen {

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能04：多屏幕支持 — 单元测试
/// 覆盖：正常查询、边界情况、屏幕变更处理、并发访问
func test_multiScreen() {
    print("\n🧪 测试1: 获取屏幕信息")
    let manager = UIMultiScreenManager.shared
    let screenCount = manager.screenCount
    guard screenCount > 0 else {
        fatalError("❌ 测试1失败: 无可用屏幕")
    }
    print("✅ 测试1通过: 可用屏幕数=\(screenCount)")
    
    print("\n🧪 测试2: 屏幕信息结构完整性")
    let info = manager.screenInfo(for: NSScreen.screens[0])
    guard !info.displayID.isEmpty else {
        fatalError("❌ 测试2失败: screen displayID 为空")
    }
    guard info.frame.width > 0 && info.frame.height > 0 else {
        fatalError("❌ 测试2失败: screen frame 无效")
    }
    guard info.scaleFactor >= 1.0 else {
        fatalError("❌ 测试2失败: 缩放因子异常\(info.scaleFactor)")
    }
    print("✅ 测试2通过: 屏幕信息完整")
    
    print("\n🧪 测试3: 窗口位置记录与恢复")
    let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.identifier = NSUserInterfaceItemIdentifier("test_window_multi_001")
    
    guard let firstScreen = NSScreen.screens.first else {
        fatalError("❌ 测试3失败: 无可用屏幕")
    }
    let uuid = manager.displayUUID(for: firstScreen)
    manager.recordPosition(of: window, on: firstScreen)
    
    guard let restored = manager.lastPosition(for: "test_window_multi_001", on: firstScreen) else {
        fatalError("❌ 测试3失败: 记录位置后无法恢复")
    }
    guard abs(restored.x - 100) < 1 && abs(restored.y - 100) < 1 else {
        fatalError("❌ 测试3失败: 恢复位置不匹配，期望(100,100)，实际(\(restored.x),\(restored.y))")
    }
    let lastUUID = manager.lastScreenUUID(for: "test_window_multi_001")
    guard lastUUID == uuid else {
        fatalError("❌ 测试3失败: 屏幕UUID不匹配")
    }
    print("✅ 测试3通过: 窗口位置记录与恢复正确")
    
    print("\n🧪 测试4: 清除位置记录")
    manager.clearPosition(for: "test_window_multi_001", on: firstScreen)
    let afterClear = manager.lastPosition(for: "test_window_multi_001", on: firstScreen)
    guard afterClear == nil else {
        fatalError("❌ 测试4失败: 清除后位置应返回nil")
    }
    print("✅ 测试4通过: 清除位置记录成功")
    
    print("\n🧪 测试5: 空identifier窗口不崩溃")
    let noIDWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
    manager.recordPosition(of: noIDWindow, on: firstScreen)
    print("✅ 测试5通过: 无identifier窗口不崩溃")
    
    print("\n🧪 测试6: 居中窗口在范围内")
    let centerWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                                styleMask: [.titled], backing: .buffered, defer: false)
    manager.center(window: centerWindow, on: firstScreen)
    let visible = firstScreen.visibleFrame
    let centerFrame = centerWindow.frame
    let cx = centerFrame.midX
    guard cx >= visible.origin.x && cx <= visible.maxX else {
        fatalError("❌ 测试6失败: 居中窗口x=\(cx)超出屏幕范围")
    }
    print("✅ 测试6通过: 居中窗口在屏幕范围内")
    
    print("\n🧪 测试7: 并发读写不崩溃")
    let group = DispatchGroup()
    for _ in 0..<20 {
        DispatchQueue.global().async(group: group) {
            manager.recordPosition(of: window, on: firstScreen)
            _ = manager.lastPosition(for: "test_window_multi_001", on: firstScreen)
        }
    }
    _ = group.wait(timeout: .now() + 5.0)
    print("✅ 测试7通过: 20次并发读写未崩溃")
    
    print("\n=== 全部多屏幕测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 窗口移动到新屏幕
    static let windowDidMoveToScreen = Notification.Name("UIMultiScreenManager.windowDidMoveToScreen")
    /// 屏幕配置发生变更（连接/断开/分辨率变化）
    static let screenConfigurationChanged = Notification.Name("UIMultiScreenManager.screenConfigurationChanged")
    /// 窗口位置已记录
    static let windowPositionRecorded = Notification.Name("UIMultiScreenManager.windowPositionRecorded")
    /// 窗口已在新屏幕居中
    static let windowCenteredOnScreen = Notification.Name("UIMultiScreenManager.windowCenteredOnScreen")
}

// MARK: - 迁回自 UI-02：class UIMultiScreenManager
public final class UIMultiScreenManager : @unchecked Sendable {
    
    // MARK: 单例
    public static let shared = UIMultiScreenManager()
    
    // MARK: 日志
    private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "04_多屏幕支持")
    
    // MARK: 线程安全锁
    private let lock = NSRecursiveLock()
    
    // MARK: 状态数据
    /// 每个屏幕上的窗口位置记录：displayUUID -> [windowID: 位置]
    private var screenWindowPositions: [String: [String: NSPoint]] = [:]
    /// 每个屏幕上的窗口尺寸记录：displayUUID -> [windowID: 尺寸]
    private var screenWindowSizes: [String: [String: NSSize]] = [:]
    /// 每个窗口最后一次所在屏幕的UUID：windowID -> displayUUID
    private var windowLastScreenMap: [String: String] = [:]
    /// 窗口是否跟随鼠标所在屏幕（设置项）
    private var followMouseScreen: Bool = false
    
    // MARK: 初始化
    private init() {
        logger.info("多屏幕管理器初始化完成")
        setupScreenChangeNotifications()
    }
    
    deinit {
        removeScreenChangeNotifications()
    }
    
    // MARK: - 屏幕变更通知监听
    
    /// 注册系统屏幕变更通知
    private func setupScreenChangeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenConfigurationChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        logger.info("已注册屏幕参数变更监听")
    }
    
    /// 移除通知监听
    private func removeScreenChangeNotifications() {
        NotificationCenter.default.removeObserver(self)
        logger.info("已移除屏幕参数变更监听")
    }
    
    /// 屏幕配置变更回调（新增/断开/分辨率变化）
    @objc private func handleScreenConfigurationChanged(_ notification: Notification) {
        var disconnected: [String] = []
        var currentScreenInfos: [UIScreenInfo] = []
        var screenCount = 0
        
        lock.lock()
        let screens = NSScreen.screens
        screenCount = screens.count
        logger.info("屏幕配置发生变更，当前可用屏幕数量：\(screenCount)")
        
        // 清理已断开屏幕的历史记录
        let currentUUIDs = Set(screens.map { displayUUID(for: $0) })
        let storedUUIDs = Set(screenWindowPositions.keys)
        disconnected = Array(storedUUIDs.subtracting(currentUUIDs))
        currentScreenInfos = screens.map { screenInfo(for: $0) }
        for uuid in disconnected {
            screenWindowPositions.removeValue(forKey: uuid)
            screenWindowSizes.removeValue(forKey: uuid)
            logger.info("已清理断开屏幕 '\(uuid)' 的历史记录")
        }
        lock.unlock()
        
        // 解锁后发送通知
        NotificationCenter.default.post(
            name: .screenConfigurationChanged,
            object: self,
            userInfo: [
                "screenCount": screenCount,
                "disconnectedUUIDs": disconnected,
                "currentScreens": currentScreenInfos
            ]
        )
    }
    
    // MARK: - 屏幕查询
    
    /// 获取所有可用屏幕数组
    public var allScreens: [NSScreen] {
        return NSScreen.screens
    }
    
    /// 获取可用屏幕数量
    public var screenCount: Int {
        return NSScreen.screens.count
    }
    
    /// 当前主屏幕（菜单栏所在屏幕）
    public var mainScreen: NSScreen? {
        return NSScreen.main
    }
    
    /// 获取鼠标指针当前所在的屏幕
    public var screenWithMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return screen(at: mouseLocation)
    }
    
    /// 根据坐标点查询所在屏幕
    /// - Parameter point: 虚拟桌面坐标系中的点
    /// - Returns: 包含该点的屏幕，无则返回主屏幕
    public func screen(at point: NSPoint) -> NSScreen? {
        for screen in allScreens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return mainScreen
    }
    
    /// 根据矩形区域查询包含它的最佳屏幕
    /// - Parameter rect: 目标矩形
    /// - Returns: 与该矩形交集面积最大的屏幕
    public func screen(containing rect: NSRect) -> NSScreen? {
        var bestScreen: NSScreen?
        var maxArea: CGFloat = 0
        for screen in allScreens {
            let intersection = screen.frame.intersection(rect)
            let area = intersection.width * intersection.height
            if area > maxArea {
                maxArea = area
                bestScreen = screen
            }
        }
        return bestScreen ?? mainScreen
    }
    
    /// 获取窗口当前所在的屏幕
    /// - Parameter window: 目标窗口
    /// - Returns: 窗口中心点所在的屏幕
    public func screen(for window: NSWindow) -> NSScreen? {
        guard let screen = window.screen else {
            // 备用方案：通过窗口中心点计算
            let centerPoint = NSPoint(
                x: window.frame.midX,
                y: window.frame.midY
            )
            return screen(at: centerPoint)
        }
        return screen
    }
    
    /// 获取指定屏幕的显示ID（唯一标识符）
    /// - Parameter screen: NSScreen 对象
    /// - Returns: screen_{CGDirectDisplayID} 格式的字符串
    public func displayUUID(for screen: NSScreen) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let num = screen.deviceDescription[key] as? NSNumber else {
            logger.error("无法获取屏幕的 displayID，使用 fallback")
            return "screen_unknown_\(screen.hash)"
        }
        return "screen_\(num.uint32Value)"
    }
    
    /// 获取屏幕的视网膜缩放因子（DPI比例）
    /// - Parameter screen: 目标屏幕
    /// - Returns: 1.0 表示普通屏幕，2.0/3.0 表示 Retina 屏幕
    public func scaleFactor(for screen: NSScreen) -> CGFloat {
        return screen.backingScaleFactor
    }
    
    /// 获取两个屏幕之间的缩放比例差
    /// - Parameters:
    ///   - fromScreen: 源屏幕
    ///   - toScreen: 目标屏幕
    /// - Returns: 目标/源缩放比例，用于尺寸换算
    public func scaleRatio(from fromScreen: NSScreen, to toScreen: NSScreen) -> CGFloat {
        let sourceScale = scaleFactor(for: fromScreen)
        let targetScale = scaleFactor(for: toScreen)
        guard sourceScale > 0 else { return 1.0 }
        return targetScale / sourceScale
    }
    
    /// 获取面积最大的屏幕（通常为主显示器）
    public var screenWithLargestArea: NSScreen? {
        var bestScreen: NSScreen?
        var maxArea: CGFloat = 0
        for screen in allScreens {
            let area = screen.frame.width * screen.frame.height
            if area > maxArea {
                maxArea = area
                bestScreen = screen
            }
        }
        return bestScreen
    }
    
    // MARK: - 屏幕信息
    
    /// 获取指定屏幕的完整信息结构
    /// - Parameter screen: NSScreen 对象
    /// - Returns: UIScreenInfo 结构体
    public func screenInfo(for screen: NSScreen) -> UIScreenInfo {
        let colorSpace = screen.colorSpace?.localizedName ?? "未知"
        return UIScreenInfo(
            displayID: displayUUID(for: screen),
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            scaleFactor: screen.backingScaleFactor,
            isMainScreen: (screen == mainScreen),
            localizedName: screen.localizedName,
            colorSpaceName: colorSpace
        )
    }
    
    /// 获取所有屏幕的信息文本（用于开发者面板或日志）
    /// - Returns: 格式化的多行字符串
    public func screenInfoText() -> String {
        let screens = allScreens
        var lines: [String] = []
        lines.append("╔══════════════════════════════════════════════════╗")
        lines.append("║              多屏幕配置信息                       ║")
        lines.append("╚══════════════════════════════════════════════════╝")
        lines.append("当前可用屏幕总数：\(screens.count)")
        lines.append("──────────────────────────────────────────────────")
        
        for (index, screen) in screens.enumerated() {
            let info = screenInfo(for: screen)
            let mainTag = info.isMainScreen ? " ⭐主屏" : ""
            lines.append("【屏幕 \(index + 1)\(mainTag)】")
            lines.append("  名称：\(info.localizedName)")
            lines.append("  ID：\(info.displayID)")
            lines.append("  完整帧：x=\(Int(info.frame.origin.x)), y=\(Int(info.frame.origin.y)), w=\(Int(info.frame.width)), h=\(Int(info.frame.height))")
            lines.append("  可用帧：x=\(Int(info.visibleFrame.origin.x)), y=\(Int(info.visibleFrame.origin.y)), w=\(Int(info.visibleFrame.width)), h=\(Int(info.visibleFrame.height))")
            lines.append("  缩放因子：\(info.scaleFactor)x（物理像素 \(Int(info.pixelWidth))×\(Int(info.pixelHeight))）")
            lines.append("  色域：\(info.colorSpaceName)")
            lines.append("")
        }
        
        // 附加窗口位置记录摘要
        lines.append("──────────────────────────────────────────────────")
        lines.append("窗口位置记录摘要：")
        lock.lock()
        let recordCount = screenWindowPositions.values.reduce(0) { $0 + $1.count }
        lock.unlock()
        lines.append("  已记录窗口位置：\(recordCount) 条")
        lines.append("  已记录窗口尺寸：\(screenWindowSizes.values.reduce(0) { $0 + $1.count }) 条")
        
        return lines.joined(separator: "\n")
    }
    
    /// 获取所有屏幕信息的数组
    public func allScreenInfos() -> [UIScreenInfo] {
        return allScreens.map { screenInfo(for: $0) }
    }
    
    // MARK: - 窗口位置记录
    
    /// 记录窗口在当前屏幕上的位置与尺寸
    /// 线程安全
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - screen: 所在屏幕（可选，自动检测）
    public func recordPosition(of window: NSWindow, on screen: NSScreen? = nil) {
        let targetScreen = screen ?? self.screen(for: window)
        guard let screen = targetScreen else {
            logger.error("无法确定窗口所在屏幕，跳过记录")
            return
        }
        
        guard let windowID = window.identifier?.rawValue else {
            logger.error("窗口无 identifier，跳过记录")
            return
        }
        
        let uuid = displayUUID(for: screen)
        let origin = window.frame.origin
        let size = window.frame.size
        
        lock.lock()
        if screenWindowPositions[uuid] == nil {
            screenWindowPositions[uuid] = [:]
        }
        if screenWindowSizes[uuid] == nil {
            screenWindowSizes[uuid] = [:]
        }
        screenWindowPositions[uuid]?[windowID] = origin
        screenWindowSizes[uuid]?[windowID] = size
        windowLastScreenMap[windowID] = uuid
        lock.unlock()
        
        logger.info("记录窗口 '\(windowID)' 在屏幕 '\(uuid)' 的位置：(\(origin.x), \(origin.y))，尺寸：\(size.width)×\(size.height)")
        
        NotificationCenter.default.post(
            name: .windowPositionRecorded,
            object: self,
            userInfo: [
                "windowID": windowID,
                "screenUUID": uuid,
                "position": origin,
                "size": size
            ]
        )
    }
    
    /// 获取窗口在指定屏幕上的最后记录位置
    /// 线程安全
    /// - Parameters:
    ///   - windowID: 窗口标识符
    ///   - screen: 目标屏幕
    /// - Returns: 记录的位置，无记录返回 nil
    public func lastPosition(for windowID: String, on screen: NSScreen) -> NSPoint? {
        let uuid = displayUUID(for: screen)
        lock.lock()
        let position = screenWindowPositions[uuid]?[windowID]
        lock.unlock()
        return position
    }
    
    /// 获取窗口在指定屏幕上的最后记录尺寸
    /// - Parameters:
    ///   - windowID: 窗口标识符
    ///   - screen: 目标屏幕
    /// - Returns: 记录的尺寸，无记录返回 nil
    public func lastSize(for windowID: String, on screen: NSScreen) -> NSSize? {
        let uuid = displayUUID(for: screen)
        lock.lock()
        let size = screenWindowSizes[uuid]?[windowID]
        lock.unlock()
        return size
    }
    
    /// 获取窗口最后一次所在的屏幕UUID
    /// - Parameter windowID: 窗口标识符
    /// - Returns: 屏幕 UUID 字符串，无记录返回 nil
    public func lastScreenUUID(for windowID: String) -> String? {
        lock.lock()
        let uuid = windowLastScreenMap[windowID]
        lock.unlock()
        return uuid
    }
    
    /// 清除指定窗口在指定屏幕上的位置记录
    /// - Parameters:
    ///   - windowID: 窗口标识符
    ///   - screen: 目标屏幕（nil 表示所有屏幕）
    public func clearPosition(for windowID: String, on screen: NSScreen? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        if let screen = screen {
            let uuid = displayUUID(for: screen)
            screenWindowPositions[uuid]?.removeValue(forKey: windowID)
            screenWindowSizes[uuid]?.removeValue(forKey: windowID)
            logger.info("已清除窗口「\(windowID)」在屏幕「\(uuid)」的记录")
        } else {
            for uuid in screenWindowPositions.keys {
                screenWindowPositions[uuid]?.removeValue(forKey: windowID)
            }
            for uuid in screenWindowSizes.keys {
                screenWindowSizes[uuid]?.removeValue(forKey: windowID)
            }
            windowLastScreenMap.removeValue(forKey: windowID)
            logger.info("已清除窗口「\(windowID)」在所有屏幕的记录")
        }
    }
    
    /// 清除所有窗口的位置记录
    public func clearAllPositions() {
        lock.lock()
        screenWindowPositions.removeAll()
        screenWindowSizes.removeAll()
        windowLastScreenMap.removeAll()
        lock.unlock()
        logger.info("已清除所有窗口的位置记录")
    }
    
    // MARK: - 窗口位置适配（核心方法）
    
    /// 窗口移动到另一个屏幕时，智能适配位置
    /// 逻辑：优先恢复该屏幕上的历史位置 → 按比例映射 → 居中
    /// 线程安全
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - oldScreen: 原屏幕（可选，用于比例映射）
    ///   - newScreen: 目标屏幕
    public func adaptPosition(for window: NSWindow, from oldScreen: NSScreen? = nil, to newScreen: NSScreen) {
        guard let windowID = window.identifier?.rawValue else {
            logger.error("窗口无 identifier，无法适配位置")
            return
        }
        
        let newUUID = displayUUID(for: newScreen)
            logger.info("适配窗口「\(windowID)」到屏幕「\(newUUID)」")
        
        // 策略1：如果目标屏幕有历史位置，直接恢复
        if let lastPos = lastPosition(for: windowID, on: newScreen) {
            var frame = window.frame
            frame.origin = lastPos
            
            // 如果有历史尺寸，一并恢复
            if let lastSize = lastSize(for: windowID, on: newScreen) {
                frame.size = lastSize
            }
            
            // 确保窗口不会完全超出屏幕可视区域
            frame = constrainFrame(frame, to: newScreen)
            
            window.setFrame(frame, display: true, animate: true)
            logger.info("恢复历史位置：(\(frame.origin.x), \(frame.origin.y))，尺寸：\(frame.size.width)×\(frame.size.height)")
            
            recordPosition(of: window, on: newScreen)
            notifyWindowMoved(window: window, toScreen: newScreen)
            return
        }
        
        // 策略2：从旧屏幕按比例映射
        if let oldScreen = oldScreen ?? detectPreviousScreen(for: windowID) {
            let mappedFrame = mapFrame(windowFrame: window.frame, from: oldScreen, to: newScreen)
            let constrained = constrainFrame(mappedFrame, to: newScreen)
            window.setFrame(constrained, display: true, animate: true)
            logger.info("按比例映射位置：(\(constrained.origin.x), \(constrained.origin.y))，尺寸：\(constrained.size.width)×\(constrained.size.height)")
            
            recordPosition(of: window, on: newScreen)
            notifyWindowMoved(window: window, toScreen: newScreen)
            return
        }
        
        // 策略3：fallback，居中显示
            logger.info("无历史位置、无旧屏幕信息，执行居中 fallback")
        center(window: window, on: newScreen)
        recordPosition(of: window, on: newScreen)
        notifyWindowMoved(window: window, toScreen: newScreen)
    }
    
    /// 一站式窗口位置管理：检测窗口当前屏幕、对比上一次记录、自动适配
    /// 应在窗口移动完成时调用（如 NSWindow.didMoveNotification 回调中）
    /// - Parameter window: 目标窗口
    public func managePosition(of window: NSWindow) {
        guard let currentScreen = screen(for: window) else {
            logger.error("无法获取窗口当前屏幕，跳过位置管理")
            return
        }
        
        guard let windowID = window.identifier?.rawValue else {
            logger.error("窗口无 identifier，跳过位置管理")
            return
        }
        
        let currentUUID = displayUUID(for: currentScreen)
        
        lock.lock()
        let lastUUID = windowLastScreenMap[windowID]
        lock.unlock()
        
        if let lastUUID = lastUUID, lastUUID != currentUUID {
            // 屏幕发生变更，需要适配
            logger.info("窗口「\(windowID)」从屏幕「\(lastUUID)」移动到「\(currentUUID)」")
            
            if let oldScreen = screenByUUID(lastUUID) {
                adaptPosition(for: window, from: oldScreen, to: currentScreen)
            } else {
                adaptPosition(for: window, to: currentScreen)
            }
        } else {
            // 同一屏幕内，仅记录位置
            recordPosition(of: window, on: currentScreen)
        }
    }
    
    // MARK: - 内部位置映射工具
    
    /// 将窗口帧从一个屏幕按比例映射到另一个屏幕
    /// 考虑屏幕坐标系差异和缩放因子
    private func mapFrame(windowFrame: NSRect, from oldScreen: NSScreen, to newScreen: NSScreen) -> NSRect {
        let _ = oldScreen.frame
        let _ = newScreen.frame
        let oldVisible = oldScreen.visibleFrame
        let newVisible = newScreen.visibleFrame
        
        var newWindowFrame = windowFrame
        
        // 按比例映射位置（相对于可用区域的相对位置）
        let relX = (windowFrame.origin.x - oldVisible.origin.x) / oldVisible.width
        let relY = (windowFrame.origin.y - oldVisible.origin.y) / oldVisible.height
        
        newWindowFrame.origin.x = newVisible.origin.x + relX * newVisible.width
        newWindowFrame.origin.y = newVisible.origin.y + relY * newVisible.height
        
        // 按比例映射尺寸（相对于可用区域的相对尺寸）
        let _ = windowFrame.width / oldVisible.width
        let _ = windowFrame.height / oldVisible.height
        
        // 根据屏幕缩放因子微调尺寸（Retina ↔ 非 Retina 转换）
        let scaleRatio = self.scaleRatio(from: oldScreen, to: newScreen)
        let adjustedW = windowFrame.width * scaleRatio
        let adjustedH = windowFrame.height * scaleRatio
        
        // 取相对比例和缩放比例的最合理值（防止窗口过大/过小）
        newWindowFrame.size.width = min(
            max(adjustedW, 300),  // 最小宽度 300
            newVisible.width * 0.9  // 不超过屏幕 90%
        )
        newWindowFrame.size.height = min(
            max(adjustedH, 200),  // 最小高度 200
            newVisible.height * 0.9
        )
        
        // 如果窗口在旧屏幕是最大化状态，在新屏幕也最大化
        let wasMaximized = abs(windowFrame.width - oldVisible.width) < 10 && abs(windowFrame.height - oldVisible.height) < 10
        if wasMaximized {
            newWindowFrame = newVisible
        }
        
        return newWindowFrame
    }
    
    /// 根据窗口历史记录推测它之前所在的屏幕
    private func detectPreviousScreen(for windowID: String) -> NSScreen? {
        lock.lock()
        let lastUUID = windowLastScreenMap[windowID]
        lock.unlock()
        
        guard let uuid = lastUUID else { return nil }
        return screenByUUID(uuid)
    }
    
    /// 根据 UUID 查找对应的 NSScreen
    private func screenByUUID(_ uuid: String) -> NSScreen? {
        for screen in allScreens {
            if displayUUID(for: screen) == uuid {
                return screen
            }
        }
        return nil
    }
    
    /// 将窗口帧约束在屏幕可视区域内，确保至少 50% 可见
    private func constrainFrame(_ frame: NSRect, to screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        var constrained = frame
        
        // 确保窗口不会完全离开屏幕右侧
        let minVisibleX = visible.origin.x - frame.width * 0.5
        let maxVisibleX = visible.maxX - frame.width * 0.5
        constrained.origin.x = max(minVisibleX, min(frame.origin.x, maxVisibleX))
        
        // 确保窗口不会完全离开屏幕顶部/底部
        let minVisibleY = visible.origin.y - frame.height * 0.3
        let maxVisibleY = visible.maxY - frame.height * 0.3
        constrained.origin.y = max(minVisibleY, min(frame.origin.y, maxVisibleY))
        
        // 确保窗口不会太大
        constrained.size.width = min(constrained.size.width, visible.width * 0.95)
        constrained.size.height = min(constrained.size.height, visible.height * 0.95)
        
        return constrained
    }
    
    // MARK: - 窗口居中
    
    /// 在指定屏幕上将窗口居中（考虑可用区域，避开菜单栏/程序坞）
    /// 线程安全
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - screen: 目标屏幕
    public func center(window: NSWindow, on screen: NSScreen) {
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
        let y = screenFrame.origin.y + (screenFrame.height - windowFrame.height) / 2
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
        
        logger.info("窗口居中于屏幕「\(self.displayUUID(for: screen))」：(\(x), \(y))")
        
        NotificationCenter.default.post(
            name: .windowCenteredOnScreen,
            object: self,
            userInfo: [
                "window": window,
                "screen": screen,
                "position": NSPoint(x: x, y: y)
            ]
        )
    }
    
    /// 在主屏幕上居中窗口
    /// - Parameter window: 目标窗口
    public func centerOnMainScreen(window: NSWindow) {
        if let screen = mainScreen {
            center(window: window, on: screen)
        } else {
            logger.error("无主屏幕，无法居中")
        }
    }
    
    /// 在鼠标指针所在屏幕上居中窗口
    /// - Parameter window: 目标窗口
    public func centerOnScreenWithMouse(window: NSWindow) {
        if let screen = screenWithMouse {
            center(window: window, on: screen)
        } else {
            centerOnMainScreen(window: window)
        }
    }
    
    // MARK: - 尺寸适配
    
    /// 根据屏幕缩放因子自动调整窗口尺寸（Retina ↔ 非Retina 转换）
    /// 线程安全
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - oldScreen: 原屏幕
    ///   - newScreen: 新屏幕
    public func adaptSize(for window: NSWindow, from oldScreen: NSScreen, to newScreen: NSScreen) {
        let ratio = scaleRatio(from: oldScreen, to: newScreen)
        guard abs(ratio - 1.0) > 0.01 else {
            logger.info("缩放因子相同(\(ratio))，无需调整尺寸")
            return
        }
        
        var frame = window.frame
        frame.size.width = max(frame.size.width * ratio, 400)
        frame.size.height = max(frame.size.height * ratio, 300)
        
        // 约束到新屏幕
        frame = constrainFrame(frame, to: newScreen)
        window.setFrame(frame, display: true, animate: true)
        
            logger.info("尺寸适配：\(ratio)× → \(frame.size.width)×\(frame.size.height)")
    }
    
    // MARK: - 私有通知
    
    /// 广播窗口已移动到新屏幕
    private func notifyWindowMoved(window: NSWindow, toScreen: NSScreen) {
        NotificationCenter.default.post(
            name: .windowDidMoveToScreen,
            object: self,
            userInfo: [
                "window": window,
                "screen": toScreen,
                "screenUUID": displayUUID(for: toScreen),
                "screenInfo": screenInfo(for: toScreen)
            ]
        )
    }
    
    // MARK: - 设置项
    
    /// 设置是否开启「跟随鼠标所在屏幕」模式
    /// 开启后，新窗口默认在鼠标所在屏幕打开
    public var shouldFollowMouseScreen: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return followMouseScreen
        }
        set {
            lock.lock()
            followMouseScreen = newValue
            lock.unlock()
            logger.info("跟随鼠标屏幕模式：\(newValue)")
        }
    }
    
    /// 获取新窗口的推荐打开屏幕（根据设置决定）
    public var preferredScreenForNewWindow: NSScreen? {
        if shouldFollowMouseScreen {
            return screenWithMouse ?? mainScreen
        }
        return mainScreen
    }
    
    // MARK: - 调试与诊断
    
    /// 打印当前所有状态到日志（调试用）
    public func dumpState() {
        lock.lock()
        defer { lock.unlock() }
        
        logger.info("━━━━━━━━━━ 状态转储 ━━━━━━━━━━")
        logger.info("屏幕数量：\(NSScreen.screens.count)")
        logger.info("位置记录：\(self.screenWindowPositions.count) 个屏幕")
        for (uuid, positions) in screenWindowPositions {
            logger.info("├─ 屏幕 \(uuid)：\(positions.count) 个窗口")
            for (wid, pos) in positions {
                logger.info("│   ├─ \(wid)：(\(pos.x), \(pos.y))")
            }
        }
        logger.info("尺寸记录：\(self.screenWindowSizes.count) 个屏幕")
        logger.info("窗口屏幕映射：\(self.windowLastScreenMap.count) 个窗口")
        for (wid, uuid) in windowLastScreenMap {
            logger.info("├─ \(wid) → \(uuid)")
        }
        logger.info("━━━━━━━━━━ 转储结束 ━━━━━━━━━━")
    }
}

// MARK: - 迁回自 UI-02：extension NSScreen
internal extension NSScreen {
    /// 获取屏幕唯一标识（兼容旧版代码）
    var displayUUID: String {
        return UIMultiScreenManager.shared.displayUUID(for: self)
    }
    
    /// 当前屏幕缩放因子
    var scaleFactor: CGFloat {
        return backingScaleFactor
    }
    
    /// 物理像素尺寸
    var pixelSize: NSSize {
        return NSSize(
            width: frame.width * backingScaleFactor,
            height: frame.height * backingScaleFactor
        )
    }
}

// MARK: - 迁回自 UI-02：struct UIScreenInfo
// MARK: - 窗口状态持久化管理器
/// 窗口位置与状态持久化管理器（单例）
///
/// 负责自动保存和恢复窗口的位置、大小、最大化状态。
/// 使用 UserDefaults 作为持久化存储，结合串行派发队列和锁保证线程安全。
/// 所有耗时操作（编码/写入）均在后台队列执行，UI 操作在主线程完成。
// 已迁回 UI-01_统一注册表.swift：class UIWindowPersistenceManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-02 合并类型
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-02_types.swift
// 版本: 2.0

// 版本: 2.0
// 提取时间: 2026-06-10


// MARK: - 屏幕信息结构
/// 单个屏幕的完整信息
public struct UIScreenInfo {
    /// 屏幕唯一标识（CGDirectDisplayID）
    public let displayID: String
    /// 屏幕在虚拟桌面坐标系中的完整帧（含菜单栏/程序坞）
    public let frame: NSRect
    /// 屏幕可用区域（不含菜单栏/程序坞）
    public let visibleFrame: NSRect
    /// 视网膜缩放因子（1.0/2.0/3.0）
    public let scaleFactor: CGFloat
    /// 是否为当前主屏幕
    public let isMainScreen: Bool
    /// 屏幕名称（如 "Color LCD"）
    public let localizedName: String
    /// 色域描述
    public let colorSpaceName: String
    /// 屏幕宽度（物理像素）
    public var pixelWidth: CGFloat { frame.width * scaleFactor }
    /// 屏幕高度（物理像素）
    public var pixelHeight: CGFloat { frame.height * scaleFactor }
    /// 可用区域宽度
    public var visibleWidth: CGFloat { visibleFrame.width }
    /// 可用区域高度
    public var visibleHeight: CGFloat { visibleFrame.height }
    
    public var description: String {
        return "屏幕「\(localizedName)」(\(displayID))：\(Int(frame.width))×\(Int(frame.height))，缩放@\(scaleFactor)x，可用区域\(Int(visibleFrame.width))×\(Int(visibleFrame.height))\(isMainScreen ? "，主屏幕" : "")"
    }
}
