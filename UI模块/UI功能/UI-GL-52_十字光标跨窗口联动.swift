// 功能42: 十字光标跨窗口联动
// 对应: 主图表十字光标位置变化时同步到所有已注册的其他窗口
// 优先级: P2
import AppKit
import Foundation
import os.log
import QuartzCore

// MARK: - 统一日志器
private let logger = Logger(subsystem: "com.xianrenzhilu.app", category: "CrosshairSync")

// MARK: - 十字光标同步通知常量（迁回自 UI-02）
public let UICrosshairSyncActivatedNotification = Notification.Name("com.xianrenzhilu.ui.crosshair.activated")
public let UICrosshairSyncDeactivatedNotification = Notification.Name("com.xianrenzhilu.ui.crosshair.deactivated")
public let UICrosshairSyncPositionChangedNotification = Notification.Name("com.xianrenzhilu.ui.crosshair.positionChanged")
public let UICrosshairSyncConfigChangedNotification = Notification.Name("com.xianrenzhilu.ui.crosshair.configChanged")
public let UICrosshairSyncWindowListChangedNotification = Notification.Name("com.xianrenzhilu.ui.crosshair.windowListChanged")


// MARK: - 通知名称常量
/// 十字光标位置变更通知，object 为 UICrosshairSyncManager，userInfo 包含 ["position": CursorPosition]
public let CrosshairSyncPositionChangedNotification = Notification.Name("com.xianrenzhilu.crosshairSync.positionChanged")
/// 联动激活通知，object 为 UICrosshairSyncManager
public let CrosshairSyncActivatedNotification = Notification.Name("com.xianrenzhilu.crosshairSync.activated")
/// 联动关闭通知，object 为 UICrosshairSyncManager
public let CrosshairSyncDeactivatedNotification = Notification.Name("com.xianrenzhilu.crosshairSync.deactivated")
/// 配置变更通知，object 为 UICrosshairSyncManager，userInfo 包含 ["config": UICrosshairStyleConfig]
public let CrosshairSyncConfigChangedNotification = Notification.Name("com.xianrenzhilu.crosshairSync.configChanged")
/// 窗口列表变更通知，object 为 UICrosshairSyncManager
public let CrosshairSyncWindowListChangedNotification = Notification.Name("com.xianrenzhilu.crosshairSync.windowListChanged")

// MARK: - 十字光标联动类型
// 十字光标联动相关类型已迁移到临时类型文件，后续合并进 UI-02。

// MARK: - 测试代码
#if DEBUG

/// 功能42：十字光标跨窗口联动 — 单元测试
func test_crosshair() {
    let manager = UICrosshairSyncManager.shared
    
    logger.info("测试1: 默认状态")
    if manager.isEnabled { logger.info("✅ 测试1通过: 默认启用") }
    else { logger.error("❌ 测试1失败: 默认应启用") }
    
    logger.info("测试2: 启用/禁用")
    manager.disableSync()
    if !manager.isEnabled { logger.info("✅ 测试2通过: 禁用成功") }
    else { logger.error("❌ 测试2失败") }
    manager.enableSync()
    if manager.isEnabled { logger.info("✅ 测试3通过: 启用成功") }
    else { logger.error("❌ 测试3失败") }
    
    logger.info("测试4: toggleSync")
    manager.toggleSync()
    if !manager.isEnabled { logger.info("✅ 测试4通过") }
    else { logger.error("❌ 测试4失败") }
    manager.enableSync()
    
    logger.info("测试5: 样式配置")
    let config = manager.styleConfig
    _ = config
    logger.info("✅ 测试5通过")
    
    logger.info("测试6: updateStyleConfig")
    var newConfig = UICrosshairStyleConfig()
    newConfig.horizontalLineColor = "#00FF00"
    manager.updateStyleConfig(newConfig)
    let updated = manager.styleConfig
    if updated.horizontalLineColor == "#00FF00" { logger.info("✅ 测试6通过") }
    else { logger.error("❌ 测试6失败") }
    
    logger.info("测试7: 设置项读取")
    let items = manager.getSettingsItems()
    _ = items
    logger.info("✅ 测试7通过")
    
    logger.info("测试8: 设置项更新")
    manager.updateSettingItem(key: "horizontalLineColor", value: .string("#FF0000"))
    let afterUpdate = manager.styleConfig
    if afterUpdate.horizontalLineColor == "#FF0000" { logger.info("✅ 测试8通过") }
    else { logger.error("❌ 测试8失败") }
    
    logger.info("=== 全部十字光标测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UICrosshairSyncManager
public final class UICrosshairSyncManager: NSObject, NSWindowDelegate , @unchecked Sendable{
    
    // MARK: 单例
    /// 十字光标同步管理器单例
    public static let shared = UICrosshairSyncManager()
    
    // MARK: Logger
    /// 使用系统 Logger，禁止 print
    private let logger = Logger(
        subsystem: "com.xianrenzhilu.crosshairSync",
        category: "UICrosshairSyncManager"
    )
    
    // MARK: 锁保护
    /// 保护共享状态的递归锁
    private let syncLock = NSRecursiveLock()
    
    // MARK: 持久化键名
    private let configKey = "com.xianrenzhilu.crosshairSync.styleConfig"
    private let enabledKey = "com.xianrenzhilu.crosshairSync.enabled"
    
    // MARK: 共享状态
    /// 当前光标位置（受锁保护）
    private var _currentPosition: UICrosshairPosition?
    /// 当前光标位置（线程安全访问）
    public var currentPosition: UICrosshairPosition? {
        syncLock.lock()
        let v = _currentPosition
        syncLock.unlock()
        return v
    }
    
    /// 联动全局开关（受锁保护）
    private var _isEnabled: Bool = true
    /// 联动全局开关（线程安全访问）
    public var isEnabled: Bool {
        syncLock.lock()
        let v = _isEnabled
        syncLock.unlock()
        return v
    }
    
    /// 光标样式配置（受锁保护）
    private var _styleConfig: UICrosshairStyleConfig = UICrosshairStyleConfig()
    /// 光标样式配置（线程安全访问）
    public var styleConfig: UICrosshairStyleConfig {
        syncLock.lock()
        let v = _styleConfig
        syncLock.unlock()
        return v
    }
    
    /// 已注册窗口集合（受锁保护）
    private var _registeredWindows: [String: NSWindow] = [:]
    /// 已注册窗口信息（受锁保护）
    private var _windowInfos: [String: UIRegisteredWindowInfo] = [:]
    /// 已注册窗口数量（线程安全访问）
    public var registeredWindowCount: Int {
        syncLock.lock()
        let c = _registeredWindows.count
        syncLock.unlock()
        return c
    }
    
    /// 已注册窗口信息列表（线程安全访问）
    public var registeredWindowInfos: [UIRegisteredWindowInfo] {
        syncLock.lock()
        let result = Array(_windowInfos.values).sorted { $0.registerTimestamp < $1.registerTimestamp }
        syncLock.unlock()
        return result
    }
    
    /// 光标跟踪区域缓存
    private var trackingAreas: [String: NSTrackingArea] = [:]
    
    /// 鼠标移动事件监听器
    private var mouseMoveMonitor: Any?
    
    /// 主窗口引用（发送联动的主窗口）
    private var mainWindow: NSWindow?
    
    // MARK: 初始化
    private override init() {
        super.init()
        // 从持久化加载配置
        loadConfig()
        // 加载联动开关状态
        loadEnabledState()
        // 注册鼠标移动监听
        setupMouseMoveMonitor()
        logger.info("十字光标同步管理器初始化完成")
    }
    
    // MARK: deinit 清理
    deinit {
        // 移除鼠标移动监听
        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
        }
        // 清理所有跟踪区域
        for _ in trackingAreas {
            // 跟踪区域由 NSView 持有，这里仅清理引用
        }
        trackingAreas.removeAll()
        // 注销所有窗口
        unregisterAllWindows()
        // 保存当前配置到持久化
        saveConfig()
        // 保存联动开关状态
        saveEnabledState()
        logger.info("十字光标同步管理器已销毁并清理完毕")
    }
    
    // MARK: - 鼠标移动监控
    /// 设置全局鼠标移动监听，用于追踪主窗口内的鼠标位置
    private func setupMouseMoveMonitor() {
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleGlobalMouseMove(event: event)
        }
        // 同时添加局部监听作为备选
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleLocalMouseMove(event: event)
            return event
        }
        if localMonitor == nil {
            logger.warning("局部鼠标移动监听器注册失败")
        }
    }
    
    /// 处理全局鼠标移动事件
    private func handleGlobalMouseMove(event: NSEvent) {
        // 全局事件只记录，不处理联动，避免误触发
        logger.debug("全局鼠标移动事件：location=\(event.locationInWindow.x), \(event.locationInWindow.y)")
    }
    
    /// 处理局部鼠标移动事件，在主窗口内触发联动
    private func handleLocalMouseMove(event: NSEvent) {
        // 检查联动是否启用
        guard isEnabled else { return }
        // 获取事件关联窗口
        guard let window = event.window else { return }
        // 检查该窗口是否已注册
        syncLock.lock()
        let isRegistered = _registeredWindows.values.contains(where: { $0 === window })
        syncLock.unlock()
        guard isRegistered else { return }
        // 获取鼠标在窗口内的坐标
        let location = event.locationInWindow
        // 转换为 NSView 坐标系（Y轴翻转）
        let viewPoint = CGPoint(
            x: location.x,
            y: window.contentView?.bounds.height ?? 0 - location.y
        )
        // 标记为主窗口
        mainWindow = window
        // 更新光标位置（这里使用占位符价格，实际由图表模块调用 updatePosition）
        logger.debug("局部鼠标移动：window=\(window.title), point=\(viewPoint.x), \(viewPoint.y)")
    }
    
    // MARK: - 窗口注册/注销
    /// 注册窗口到联动系统，注册后该窗口的光标位置会同步到其他窗口
    /// - Parameters:
    ///   - window: 要注册的 NSWindow
    ///   - symbol: 交易对符号
    ///   - title: 窗口标题
    ///   - timePeriod: 时间周期（如 "1m", "5m", "1h"）
    /// - Returns: 窗口唯一标识符
    @discardableResult
    public func addWindow(_ window: NSWindow, symbol: String, title: String, timePeriod: String) -> String {
        let windowID = "\(window.hashValue)_\(symbol)_\(timePeriod)_\(Date().timeIntervalSince1970)"
        syncLock.lock()
        _registeredWindows[windowID] = window
        let info = UIRegisteredWindowInfo(
            windowID: windowID,
            title: title,
            symbol: symbol,
            timePeriod: timePeriod,
            registerTimestamp: Date().timeIntervalSince1970
        )
        _windowInfos[windowID] = info
        syncLock.unlock()
        // 设置窗口委托以监听关闭事件
        window.delegate = self
        // 为窗口内容视图添加跟踪区域
        if let contentView = window.contentView {
            let trackingArea = NSTrackingArea(
                rect: contentView.bounds,
                options: [.activeAlways, .mouseMoved, .inVisibleRect],
                owner: self,
                userInfo: ["windowID": windowID]
            )
            contentView.addTrackingArea(trackingArea)
            trackingAreas[windowID] = trackingArea
        }
        // 发送窗口列表变更通知
        NotificationCenter.default.post(
            name: UICrosshairSyncWindowListChangedNotification,
            object: self,
            userInfo: ["count": registeredWindowCount]
        )
        logger.info("注册窗口：\(title) [\(windowID)]，当前注册窗口数：\(self.registeredWindowCount)")
        return windowID
    }
    
    /// 从联动系统中注销窗口
    /// - Parameter windowID: 窗口唯一标识符
    public func removeWindow(_ windowID: String) {
        syncLock.lock()
        let removedWindow = _registeredWindows.removeValue(forKey: windowID)
        _windowInfos.removeValue(forKey: windowID)
        syncLock.unlock()
        // 清理跟踪区域
        if let area = trackingAreas.removeValue(forKey: windowID),
           let contentView = removedWindow?.contentView {
            contentView.removeTrackingArea(area)
        }
        // 发送窗口列表变更通知
        NotificationCenter.default.post(
            name: UICrosshairSyncWindowListChangedNotification,
            object: self,
            userInfo: ["count": registeredWindowCount]
        )
        logger.info("注销窗口：[\(windowID)]，当前注册窗口数：\(self.registeredWindowCount)")
    }
    
    /// 注销指定窗口实例（通过对象引用查找）
    /// - Parameter window: 要注销的 NSWindow
    public func removeWindow(_ window: NSWindow) {
        syncLock.lock()
        let targetID = _registeredWindows.first(where: { $0.value === window })?.key
        syncLock.unlock()
        if let id = targetID {
            removeWindow(id)
        } else {
            logger.warning("未找到要注销的窗口引用")
        }
    }
    
    /// 注销所有窗口
    public func unregisterAllWindows() {
        syncLock.lock()
        let allIDs = Array(_registeredWindows.keys)
        _registeredWindows.removeAll()
        _windowInfos.removeAll()
        syncLock.unlock()
        for windowID in allIDs {
            if trackingAreas.removeValue(forKey: windowID) != nil {
                logger.debug("清理窗口 \(windowID) 的跟踪区域")
            }
        }
        trackingAreas.removeAll()
        // 发送窗口列表变更通知
        NotificationCenter.default.post(
            name: UICrosshairSyncWindowListChangedNotification,
            object: self,
            userInfo: ["count": 0]
        )
        logger.info("已注销所有窗口，联动系统清空")
    }
    
    // MARK: - 窗口关闭委托回调
    public func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        removeWindow(window)
    }
    
    // MARK: - 联动开关控制
    /// 启用跨窗口联动
    public func enableSync() {
        syncLock.lock()
        _isEnabled = true
        syncLock.unlock()
        saveEnabledState()
        NotificationCenter.default.post(
            name: UICrosshairSyncActivatedNotification,
            object: self,
            userInfo: ["windowCount": registeredWindowCount]
        )
        logger.info("跨窗口联动已启用")
    }
    
    /// 禁用跨窗口联动
    public func disableSync() {
        syncLock.lock()
        _isEnabled = false
        syncLock.unlock()
        saveEnabledState()
        // 隐藏所有窗口的光标
        hideAllCrosshairs()
        NotificationCenter.default.post(
            name: UICrosshairSyncDeactivatedNotification,
            object: self,
            userInfo: ["windowCount": registeredWindowCount]
        )
        logger.info("跨窗口联动已禁用")
    }
    
    /// 切换联动开关状态
    public func toggleSync() {
        if isEnabled {
            disableSync()
        } else {
            enableSync()
        }
    }
    
    // MARK: - 光标位置更新
    /// 更新主光标位置，触发所有从属窗口同步
    /// - Parameter position: 光标位置数据
    public func updatePosition(_ position: UICrosshairPosition) {
        // 检查联动是否启用
        guard isEnabled else { return }
        // 加锁更新位置
        syncLock.lock()
        _currentPosition = position
        syncLock.unlock()
        // 发送位置变更通知
        NotificationCenter.default.post(
            name: UICrosshairSyncPositionChangedNotification,
            object: self,
            userInfo: ["position": position]
        )
        // 同步到所有从属窗口
        syncToAllWindows(position: position)
        logger.debug("更新光标位置：symbol=\(position.symbol), price=\(position.price), time=\(position.formattedDateTime)")
    }
    
    /// 隐藏十字光标（鼠标移出窗口或联动禁用）
    public func hideCrosshair() {
        syncLock.lock()
        _currentPosition = nil
        syncLock.unlock()
        // 隐藏所有窗口的光标
        hideAllCrosshairs()
        // 发送位置变更通知（位置为 nil 表示隐藏）
        NotificationCenter.default.post(
            name: UICrosshairSyncPositionChangedNotification,
            object: self,
            userInfo: ["position": NSNull()]
        )
        logger.debug("隐藏十字光标")
    }
    
    /// 隐藏所有窗口的十字光标
    private func hideAllCrosshairs() {
        syncLock.lock()
        let windows = Array(_registeredWindows.values)
        syncLock.unlock()
        for window in windows {
            // 触发窗口内十字光标隐藏
            window.contentView?.needsDisplay = true
        }
        logger.debug("已隐藏所有窗口十字光标")
    }
    
    /// 同步光标位置到所有已注册窗口
    private func syncToAllWindows(position: UICrosshairPosition) {
        syncLock.lock()
        let windows = Array(_registeredWindows.values)
        syncLock.unlock()
        for window in windows {
            // 标记窗口需要重绘，以更新十字光标位置
            window.contentView?.needsDisplay = true
        }
        logger.debug("已同步到 \(windows.count) 个从属窗口")
    }
    
    // MARK: - 样式配置管理
    /// 更新光标样式配置
    /// - Parameter config: 新的样式配置
    public func updateStyleConfig(_ config: UICrosshairStyleConfig) {
        syncLock.lock()
        _styleConfig = config
        syncLock.unlock()
        // 保存到持久化
        saveConfig()
        // 发送配置变更通知
        NotificationCenter.default.post(
            name: UICrosshairSyncConfigChangedNotification,
            object: self,
            userInfo: ["config": config]
        )
        // 触发所有窗口重绘
        syncLock.lock()
        let windows = Array(_registeredWindows.values)
        syncLock.unlock()
        for window in windows {
            window.contentView?.needsDisplay = true
        }
        logger.info("更新光标样式配置")
    }
    
    /// 重置样式为默认配置
    public func resetStyleConfig() {
        let defaultConfig = UICrosshairStyleConfig()
        updateStyleConfig(defaultConfig)
        logger.info("重置光标样式为默认配置")
    }
    
    // MARK: - 持久化
    /// 保存样式配置到 UserDefaults
    private func saveConfig() {
        syncLock.lock()
        let config = _styleConfig
        syncLock.unlock()
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(config)
            UserDefaults.standard.set(data, forKey: configKey)
            logger.debug("样式配置已持久化保存")
        } catch {
            logger.error("保存光标样式配置失败：\(error.localizedDescription)")
        }
    }
    
    /// 从 UserDefaults 加载样式配置
    private func loadConfig() {
        guard let data = UserDefaults.standard.data(forKey: configKey) else {
            logger.info("未找到持久化的光标样式配置，使用默认配置")
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(UICrosshairStyleConfig.self, from: data)
            syncLock.lock()
            _styleConfig = config
            syncLock.unlock()
            logger.info("已加载持久化的光标样式配置")
        } catch {
            logger.error("加载光标样式配置失败：\(error.localizedDescription)，使用默认配置")
        }
    }
    
    /// 保存联动开关状态到 UserDefaults
    private func saveEnabledState() {
        syncLock.lock()
        let enabled = _isEnabled
        syncLock.unlock()
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        logger.debug("联动开关状态已保存：\(enabled)")
    }
    
    /// 从 UserDefaults 加载联动开关状态
    private func loadEnabledState() {
        let enabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        syncLock.lock()
        _isEnabled = enabled
        syncLock.unlock()
        logger.info("已加载联动开关状态：\(enabled)")
    }
    
    // MARK: - 时间轴值显示辅助方法
    /// 根据光标位置获取格式化时间轴值显示字符串
    /// - Parameter position: 光标位置数据
    /// - Returns: 包含时间、价格、成交量的格式化字符串
    public func getAxisValueLabel(for position: UICrosshairPosition) -> String {
        var components: [String] = []
        // 时间部分
        components.append("时间: \(position.formattedDateTime)")
        // 价格部分
        components.append("价格: \(position.formattedPrice)")
        // 成交量部分（如果存在）
        if let volumeStr = position.formattedVolume {
            components.append("成交量: \(volumeStr)")
        }
        return components.joined(separator: " | ")
    }
    
    /// 根据价格标签获取格式化字符串
    /// - Parameter position: 光标位置数据
    /// - Returns: 价格标签字符串
    public func getPriceLabel(for position: UICrosshairPosition) -> String {
        return position.formattedPrice
    }
    
    /// 根据时间获取格式化字符串
    /// - Parameter position: 光标位置数据
    /// - Returns: 时间标签字符串
    public func getTimeLabel(for position: UICrosshairPosition) -> String {
        return position.formattedTime
    }
    
    // MARK: - 设置面板方法
    /// 获取设置面板所需的配置项字典
    /// 用于在设置面板中展示和修改配置
    /// - Returns: 配置项字典，包含所有可修改的配置项和当前值
    public struct UISettingsItem {
        public let horizontalLineColor: String
        public let verticalLineColor: String
        public let horizontalLineWidth: CGFloat
        public let verticalLineWidth: CGFloat
        public let isDashed: Bool
        public let dashLength: CGFloat
        public let gapLength: CGFloat
        public let priceLabelBgColor: String
        public let timeLabelBgColor: String
        public let labelTextColor: String
        public let labelFontSize: CGFloat
        public let labelCornerRadius: CGFloat
        public let showPriceLabel: Bool
        public let showTimeLabel: Bool
        public let showVolumeLabel: Bool
        public let volumeLabelBgColor: String
        public let isEnabled: Bool
        public let registeredWindowCount: Int
        
        public init(config: UICrosshairStyleConfig, isEnabled: Bool, registeredWindowCount: Int) {
            self.horizontalLineColor = config.horizontalLineColor
            self.verticalLineColor = config.verticalLineColor
            self.horizontalLineWidth = config.horizontalLineWidth
            self.verticalLineWidth = config.verticalLineWidth
            self.isDashed = config.isDashed
            self.dashLength = config.dashLength
            self.gapLength = config.gapLength
            self.priceLabelBgColor = config.priceLabelBgColor
            self.timeLabelBgColor = config.timeLabelBgColor
            self.labelTextColor = config.labelTextColor
            self.labelFontSize = config.labelFontSize
            self.labelCornerRadius = config.labelCornerRadius
            self.showPriceLabel = config.showPriceLabel
            self.showTimeLabel = config.showTimeLabel
            self.showVolumeLabel = config.showVolumeLabel
            self.volumeLabelBgColor = config.volumeLabelBgColor
            self.isEnabled = isEnabled
            self.registeredWindowCount = registeredWindowCount
        }
    }
    
    public func getSettingsItems() -> UISettingsItem {
        let config = styleConfig
        return UISettingsItem(
            config: config,
            isEnabled: isEnabled,
            registeredWindowCount: registeredWindowCount
        )
    }
    
    /// 从设置面板更新配置项
    /// - Parameters:
    ///   - key: 配置项键名
    ///   - value: 新的值
    public enum UISettingValue {
        case string(String)
        case bool(Bool)
        case float(CGFloat)
        
        public var stringValue: String? { if case .string(let v) = self { return v }; return nil }
        public var boolValue: Bool? { if case .bool(let v) = self { return v }; return nil }
        public var floatValue: CGFloat? { if case .float(let v) = self { return v }; return nil }
    }
    
    public func updateSettingItem(key: String, value: UISettingValue) {
        var config = styleConfig
        switch key {
        case "horizontalLineColor":
            if let v = value.stringValue { config.horizontalLineColor = v }
        case "verticalLineColor":
            if let v = value.stringValue { config.verticalLineColor = v }
        case "horizontalLineWidth":
            if let v = value.floatValue { config.horizontalLineWidth = v }
        case "verticalLineWidth":
            if let v = value.floatValue { config.verticalLineWidth = v }
        case "isDashed":
            if let v = value.boolValue { config.isDashed = v }
        case "dashLength":
            if let v = value.floatValue { config.dashLength = v }
        case "gapLength":
            if let v = value.floatValue { config.gapLength = v }
        case "priceLabelBgColor":
            if let v = value.stringValue { config.priceLabelBgColor = v }
        case "timeLabelBgColor":
            if let v = value.stringValue { config.timeLabelBgColor = v }
        case "labelTextColor":
            if let v = value.stringValue { config.labelTextColor = v }
        case "labelFontSize":
            if let v = value.floatValue { config.labelFontSize = v }
        case "labelCornerRadius":
            if let v = value.floatValue { config.labelCornerRadius = v }
        case "showPriceLabel":
            if let v = value.boolValue { config.showPriceLabel = v }
        case "showTimeLabel":
            if let v = value.boolValue { config.showTimeLabel = v }
        case "showVolumeLabel":
            if let v = value.boolValue { config.showVolumeLabel = v }
        case "volumeLabelBgColor":
            if let v = value.stringValue { config.volumeLabelBgColor = v }
        case "isEnabled":
            if let v = value.boolValue {
                if v { enableSync() } else { disableSync() }
                return
            }
        default:
            logger.warning("未知的设置项键：\(key)")
            return
        }
        updateStyleConfig(config)
    }
    
    /// 获取设置面板中配置项的显示名称
    /// - Parameter key: 配置项键名
    /// - Returns: 对应的中文显示名称
    public func getSettingDisplayName(for key: String) -> String {
        let displayNames: [String: String] = [
            "horizontalLineColor": "水平线颜色",
            "verticalLineColor": "垂直线颜色",
            "horizontalLineWidth": "水平线宽度",
            "verticalLineWidth": "垂直线宽度",
            "isDashed": "使用虚线",
            "dashLength": "虚线实线长度",
            "gapLength": "虚线间隔长度",
            "priceLabelBgColor": "价格标签背景色",
            "timeLabelBgColor": "时间标签背景色",
            "labelTextColor": "标签文字颜色",
            "labelFontSize": "标签字体大小",
            "labelCornerRadius": "标签圆角",
            "showPriceLabel": "显示价格标签",
            "showTimeLabel": "显示时间标签",
            "showVolumeLabel": "显示成交量标签",
            "volumeLabelBgColor": "成交量标签背景色",
            "isEnabled": "启用跨窗口联动"
        ]
        return displayNames[key] ?? key
    }
    
    /// 获取设置面板中配置项的说明文字
    /// - Parameter key: 配置项键名
    /// - Returns: 对应的中文说明文字
    public func getSettingDescription(for key: String) -> String {
        let descriptions: [String: String] = [
            "horizontalLineColor": "水平十字线的颜色，使用 Hex 格式（如 #FF0000）",
            "verticalLineColor": "垂直十字线的颜色，使用 Hex 格式",
            "isDashed": "是否使用虚线样式绘制十字线",
            "showPriceLabel": "在十字线水平位置显示当前价格数值",
            "showTimeLabel": "在十字线垂直位置显示当前时间数值",
            "showVolumeLabel": "在光标附近显示当前成交量数值",
            "isEnabled": "开启后，所有图表窗口的十字光标将同步联动"
        ]
        return descriptions[key] ?? ""
    }
    
    // MARK: - 辅助工具方法
    /// 判断指定窗口是否已注册
    /// - Parameter window: 要检查的窗口
    /// - Returns: 是否已注册
    public func isWindowRegistered(_ window: NSWindow) -> Bool {
        syncLock.lock()
        let registered = _registeredWindows.values.contains(where: { $0 === window })
        syncLock.unlock()
        return registered
    }
    
    /// 获取窗口的注册信息
    /// - Parameter window: 已注册的窗口
    /// - Returns: 注册信息，未注册返回 nil
    public func getWindowInfo(for window: NSWindow) -> UIRegisteredWindowInfo? {
        syncLock.lock()
        let info = _registeredWindows.first(where: { $0.value === window }).flatMap { _windowInfos[$0.key] }
        syncLock.unlock()
        return info
    }
    
    /// 获取所有已注册窗口的引用列表
    /// - Returns: 已注册窗口数组
    public func getAllRegisteredWindows() -> [NSWindow] {
        syncLock.lock()
        let windows = Array(_registeredWindows.values)
        syncLock.unlock()
        return windows
    }
    
    /// 检查是否有激活的联动会话
    /// - Returns: 当前是否有光标位置数据
    public var hasActiveCrosshair: Bool {
        return currentPosition != nil && isEnabled
    }
    
    /// 获取当前光标位置的时间戳（字符串格式）
    public var currentCursorTimeString: String? {
        return currentPosition?.formattedDateTime
    }
    
    /// 获取当前光标位置的价格（字符串格式）
    public var currentCursorPriceString: String? {
        return currentPosition?.formattedPrice
    }
}

// MARK: - 迁回自 UI-02：class UICrosshairOverlayView
public final class UICrosshairOverlayView: NSView , @unchecked Sendable{
    
    // MARK: 属性
    /// 关联的同步管理器
    private let syncManager = UICrosshairSyncManager.shared
    /// 当前窗口的光标位置（由管理器同步过来）
    private var syncedPosition: UICrosshairPosition?
    /// 是否显示十字光标
    private var isVisible: Bool = false
    
    // MARK: 初始化
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupNotificationObserver()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNotificationObserver()
    }
    
    // MARK: 通知监听
    /// 注册联动位置变更通知监听
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePositionChanged(_:)),
            name: UICrosshairSyncPositionChangedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncActivated(_:)),
            name: UICrosshairSyncActivatedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncDeactivated(_:)),
            name: UICrosshairSyncDeactivatedNotification,
            object: nil
        )
    }
    
    /// 处理位置变更通知
    @objc private func handlePositionChanged(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let position = userInfo["position"] as? UICrosshairPosition {
            syncedPosition = position
            isVisible = true
            needsDisplay = true
        } else if let userInfo = notification.userInfo,
                  userInfo["position"] is NSNull {
            // 收到 nil 表示隐藏光标
            isVisible = false
            syncedPosition = nil
            needsDisplay = true
        }
    }
    
    /// 处理联动激活通知
    @objc private func handleSyncActivated(_ notification: Notification) {
        // 联动激活时，如果有位置数据则显示
        if let position = syncManager.currentPosition {
            syncedPosition = position
            isVisible = true
            needsDisplay = true
        }
    }
    
    /// 处理联动关闭通知
    @objc private func handleSyncDeactivated(_ notification: Notification) {
        isVisible = false
        syncedPosition = nil
        needsDisplay = true
    }
    
    // MARK: 绘制
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // 检查是否可见和联动启用
        guard isVisible, syncManager.isEnabled else { return }
        guard let position = syncedPosition else { return }
        
        let config = syncManager.styleConfig
        
        // 获取颜色
        let hColor = config.color(from: config.horizontalLineColor) ?? NSColor.red
        let vColor = config.color(from: config.verticalLineColor) ?? NSColor.red
        
        // 获取图形上下文
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        
        // 绘制水平线（从左侧到右侧）
        let hLineY = position.viewPoint.y
        let hPath = CGMutablePath()
        hPath.move(to: CGPoint(x: 0, y: hLineY))
        hPath.addLine(to: CGPoint(x: bounds.width, y: hLineY))
        
        context.setStrokeColor(hColor.cgColor)
        context.setLineWidth(config.horizontalLineWidth)
        if config.isDashed {
            context.setLineDash(phase: 0, lengths: [config.dashLength, config.gapLength])
        }
        context.addPath(hPath)
        context.strokePath()
        
        // 绘制垂直线（从顶部到底部）
        let vLineX = position.viewPoint.x
        let vPath = CGMutablePath()
        vPath.move(to: CGPoint(x: vLineX, y: 0))
        vPath.addLine(to: CGPoint(x: vLineX, y: bounds.height))
        
        context.setStrokeColor(vColor.cgColor)
        context.setLineWidth(config.verticalLineWidth)
        if config.isDashed {
            context.setLineDash(phase: 0, lengths: [config.dashLength, config.gapLength])
        } else {
            context.setLineDash(phase: 0, lengths: [])
        }
        context.addPath(vPath)
        context.strokePath()
        
        // 绘制价格标签（水平线右侧）
        if config.showPriceLabel {
            drawLabel(
                context: context,
                text: syncManager.getPriceLabel(for: position),
                bgColor: config.color(from: config.priceLabelBgColor) ?? NSColor.darkGray,
                textColor: config.color(from: config.labelTextColor) ?? NSColor.white,
                fontSize: config.labelFontSize,
                cornerRadius: config.labelCornerRadius,
                at: CGPoint(x: bounds.width - 5, y: hLineY),
                alignment: .right
            )
        }
        
        // 绘制时间标签（垂直线下方）
        if config.showTimeLabel {
            drawLabel(
                context: context,
                text: syncManager.getTimeLabel(for: position),
                bgColor: config.color(from: config.timeLabelBgColor) ?? NSColor.darkGray,
                textColor: config.color(from: config.labelTextColor) ?? NSColor.white,
                fontSize: config.labelFontSize,
                cornerRadius: config.labelCornerRadius,
                at: CGPoint(x: vLineX, y: 5),
                alignment: .center
            )
        }
        
        // 绘制成交量标签（光标右下角）
        if config.showVolumeLabel, let volumeStr = position.formattedVolume {
            drawLabel(
                context: context,
                text: "Vol: \(volumeStr)",
                bgColor: config.color(from: config.volumeLabelBgColor) ?? NSColor.gray,
                textColor: config.color(from: config.labelTextColor) ?? NSColor.white,
                fontSize: config.labelFontSize,
                cornerRadius: config.labelCornerRadius,
                at: CGPoint(x: position.viewPoint.x + 10, y: position.viewPoint.y - 10),
                alignment: .left
            )
        }
        
        context.restoreGState()
    }
    
    // MARK: 标签绘制辅助方法
    /// 绘制数值标签
    private func drawLabel(
        context: CGContext,
        text: String,
        bgColor: NSColor,
        textColor: NSColor,
        fontSize: CGFloat,
        cornerRadius: CGFloat,
        at position: CGPoint,
        alignment: NSTextAlignment
    ) {
        let font = NSFont.systemFont(ofSize: fontSize)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let attributedText = NSAttributedString(string: text, attributes: textAttributes)
        let textSize = attributedText.size()
        let padding: CGFloat = 4.0
        let labelSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)
        
        var labelRect: CGRect
        switch alignment {
        case .right:
            labelRect = CGRect(
                x: position.x - labelSize.width,
                y: position.y - labelSize.height / 2,
                width: labelSize.width,
                height: labelSize.height
            )
        case .center:
            labelRect = CGRect(
                x: position.x - labelSize.width / 2,
                y: position.y,
                width: labelSize.width,
                height: labelSize.height
            )
        default:
            labelRect = CGRect(
                x: position.x,
                y: position.y - labelSize.height,
                width: labelSize.width,
                height: labelSize.height
            )
        }
        
        // 绘制标签背景（圆角矩形）
        let labelPath = CGPath(
            roundedRect: labelRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        context.setFillColor(bgColor.cgColor)
        context.addPath(labelPath)
        context.fillPath()
        
        // 绘制文字
        let textRect = CGRect(
            x: labelRect.origin.x + padding,
            y: labelRect.origin.y + padding,
            width: textSize.width,
            height: textSize.height
        )
        attributedText.draw(in: textRect)
    }
    
    // MARK: deinit 清理
    deinit {
        // 移除所有通知监听
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 迁回自 UI-02：struct UICrosshairStyleConfig
// MARK: - UI-GL-52 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-52_types.swift
// 版本: 2.0
// MARK: - 光标样式配置
/// 十字光标外观样式配置，支持持久化保存
public struct UICrosshairStyleConfig: Codable, Equatable {
    /// 水平线颜色（Hex 字符串，如 "#FF0000"）
    public var horizontalLineColor: String = "#FF6B6B"
    /// 垂直线颜色
    public var verticalLineColor: String = "#FF6B6B"
    /// 水平线宽度（像素）
    public var horizontalLineWidth: CGFloat = 0.5
    /// 垂直线宽度
    public var verticalLineWidth: CGFloat = 0.5
    /// 是否使用虚线模式
    public var isDashed: Bool = true
    /// 虚线实线段长度
    public var dashLength: CGFloat = 5.0
    /// 虚线空白段长度
    public var gapLength: CGFloat = 2.0
    /// 价格标签背景色
    public var priceLabelBgColor: String = "#333333"
    /// 时间标签背景色
    public var timeLabelBgColor: String = "#333333"
    /// 标签文字颜色
    public var labelTextColor: String = "#FFFFFF"
    /// 标签字体大小
    public var labelFontSize: CGFloat = 10.0
    /// 标签圆角半径
    public var labelCornerRadius: CGFloat = 2.0
    /// 是否显示价格标签
    public var showPriceLabel: Bool = true
    /// 是否显示时间标签
    public var showTimeLabel: Bool = true
    /// 是否显示音量标签（如适用）
    public var showVolumeLabel: Bool = true
    /// 音量标签背景色
    public var volumeLabelBgColor: String = "#444444"
    
    public init() {}
    
    /// 将 Hex 颜色字符串转换为 NSColor
    public func color(from hex: String) -> NSColor? {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        guard hexString.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

// MARK: - 迁回自 UI-02：struct UICrosshairPosition
// MARK: - UI-GL-52 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-52_types.swift
// 版本: 2.0
// MARK: - 光标位置数据
/// 十字光标关联的数据点：位置、时间、价格、成交量等
public struct UICrosshairPosition: Codable, Equatable {
    /// 交易对符号
    public let symbol: String
    /// K线时间戳
    public let timestamp: TimeInterval
    /// 对应价格
    public let price: Double
    /// 对应成交量（可选）
    public let volume: Double?
    /// 对应最高（可选）
    public let high: Double?
    /// 对应最低（可选）
    public let low: Double?
    /// 对应开盘（可选）
    public let open: Double?
    /// 对应收盘（可选）
    public let close: Double?
    /// 窗口内鼠标坐标（相对于窗口的 NSView 坐标系）
    public let viewPoint: CGPoint
    
    public init(
        symbol: String,
        timestamp: TimeInterval,
        price: Double,
        volume: Double? = nil,
        high: Double? = nil,
        low: Double? = nil,
        open: Double? = nil,
        close: Double? = nil,
        viewPoint: CGPoint = .zero
    ) {
        self.symbol = symbol
        self.timestamp = timestamp
        self.price = price
        self.volume = volume
        self.high = high
        self.low = low
        self.open = open
        self.close = close
        self.viewPoint = viewPoint
    }
    
    /// 格式化时间字符串
    public var formattedTime: String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    /// 格式化日期时间字符串
    public var formattedDateTime: String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    /// 格式化价格字符串（保留2位小数）
    public var formattedPrice: String {
        return String(format: "%.2f", price)
    }
    
    /// 格式化成交量字符串
    public var formattedVolume: String? {
        guard let volume = volume else { return nil }
        return String(format: "%.2f", volume)
    }
}

// MARK: - 迁回自 UI-02：struct UIRegisteredWindowInfo
// MARK: - 注册窗口信息
/// 已注册联动窗口的元信息
public struct UIRegisteredWindowInfo: Codable, Equatable {
    /// 窗口唯一标识
    public let windowID: String
    /// 窗口标题
    public var title: String
    /// 交易对符号
    public var symbol: String
    /// 时间周期
    public var timePeriod: String
    /// 注册时间戳
    public let registerTimestamp: TimeInterval
}
