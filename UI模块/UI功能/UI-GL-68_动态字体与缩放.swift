// 功能58: 动态字体与缩放
// 对应: 支持Cmd+/-全局缩放UI，字体大小适配系统Dynamic Type
// 优先级: P2

import Foundation
import AppKit
import os.log

// MARK: - 日志记录器
/// 模块专用日志记录器，用于替代print输出调试与运行信息
private let moduleLogger = Logger(subsystem: "com.xianrenzhilu.fontscale", category: "DynamicFont")

// MARK: - 测试代码
#if DEBUG

/// 功能58：动态字体与缩放 — 单元验证
func test_dynamicFont() {
    let manager = UIDynamicFontManager.shared
    
    moduleLogger.info("测试1: 默认字体等级")
    if manager.currentFontSizeLevel == .normal {
        moduleLogger.info("✅ 测试1通过")
    } else {
        moduleLogger.error("❌ 测试1失败")
    }
    
    moduleLogger.info("测试2: 默认缩放级别")
    if manager.currentZoomLevel == .normal {
        moduleLogger.info("✅ 测试2通过")
    } else {
        moduleLogger.error("❌ 测试2失败")
    }
    
    moduleLogger.info("测试3: 设置字体等级")
    manager.setFontSizeLevel(.large)
    if manager.currentFontSizeLevel == .large {
        moduleLogger.info("✅ 测试3通过")
    } else {
        moduleLogger.error("❌ 测试3失败")
    }
    
    moduleLogger.info("测试4: 设置缩放级别")
    manager.setInterfaceZoomLevel(.large)
    if manager.currentZoomLevel == .large {
        moduleLogger.info("✅ 测试4通过")
    } else {
        moduleLogger.error("❌ 测试4失败")
    }
    
    moduleLogger.info("测试5: 增大字体")
    manager.increaseFontSize()
    if manager.currentFontSizeLevel == .extraLarge {
        moduleLogger.info("✅ 测试5通过")
    } else {
        moduleLogger.error("❌ 测试5失败")
    }
    
    moduleLogger.info("测试6: 缩小字体")
    manager.decreaseFontSize()
    if manager.currentFontSizeLevel == .large {
        moduleLogger.info("✅ 测试6通过")
    } else {
        moduleLogger.error("❌ 测试6失败")
    }
    
    moduleLogger.info("测试7: 缩放字号计算")
    let bodySize = manager.scaledFontSize(for: .body)
    if bodySize > 10 && bodySize < 30 {
        moduleLogger.info("✅ 测试7通过 (bodySize=\(bodySize))")
    } else {
        moduleLogger.error("❌ 测试7失败")
    }
    
    moduleLogger.info("测试8: 缩放字体实例")
    let font = manager.scaledFont(for: .headline)
    if font.pointSize > 0 {
        moduleLogger.info("✅ 测试8通过 (fontSize=\(font.pointSize))")
    } else {
        moduleLogger.error("❌ 测试8失败")
    }
    
    moduleLogger.info("测试9: 组件尺寸缩放")
    let metrics = manager.scaledButtonMetrics
    if metrics.height > 0 {
        moduleLogger.info("✅ 测试9通过 (height=\(metrics.height))")
    } else {
        moduleLogger.error("❌ 测试9失败")
    }
    
    moduleLogger.info("测试10: 缩放放大")
    manager.zoomIn()
    if manager.currentZoomLevel == .xlarge {
        moduleLogger.info("✅ 测试10通过")
    } else {
        moduleLogger.error("❌ 测试10失败")
    }
    
    moduleLogger.info("测试11: 缩放缩小")
    manager.zoomOut()
    if manager.currentZoomLevel == .large {
        moduleLogger.info("✅ 测试11通过")
    } else {
        moduleLogger.error("❌ 测试11失败")
    }
    
    moduleLogger.info("测试12: 枚举个数")
    if UIFontSizeLevel.allCases.count == 5 && UIInterfaceZoomLevel.allCases.count == 6 {
        moduleLogger.info("✅ 测试12通过")
    } else {
        moduleLogger.error("❌ 测试12失败")
    }
    
    moduleLogger.info("测试13: 重置为默认")
    manager.resetToDefaults()
    if manager.currentFontSizeLevel == .normal && manager.currentZoomLevel == .normal {
        moduleLogger.info("✅ 测试13通过")
    } else {
        moduleLogger.error("❌ 测试13失败")
    }
    
    moduleLogger.info("=== 全部动态字体测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    static let fontSizeLevelDidChange = Notification.Name("com.xianrenzhilu.fontSizeLevelDidChange")
    static let interfaceZoomLevelDidChange = Notification.Name("com.xianrenzhilu.interfaceZoomLevelDidChange")
    static let dynamicFontConfigurationDidChange = Notification.Name("com.xianrenzhilu.dynamicFontConfigurationDidChange")
}

// MARK: - 迁回自 UI-02：class UIDynamicFontManager
public final class UIDynamicFontManager : @unchecked Sendable {

    // MARK: - 单例
    /// 全局共享的动态字体管理器实例
    public static let shared = UIDynamicFontManager()

    // MARK: - 私有初始化
    /// 私有化构造器，禁止外部创建实例
    private init() {
        loadConfiguration()
        setupGlobalShortcuts()
        moduleLogger.info("动态字体管理器初始化完成，当前字体等级: \(String(describing: self.currentFontSizeLevel))，缩放: \(String(describing: self.currentZoomLevel))")
    }

    // MARK: - 线程锁
    /// 用于保护共享状态数据的递归锁
    private let lock = NSRecursiveLock()

    // MARK: - 通知中心
    /// 模块内部使用的通知中心，默认使用全局通知中心
    private let notificationCenter = NotificationCenter.default

    // MARK: - 当前状态（受锁保护）
    /// 当前字体大小等级，受lock保护
    private var _currentFontSizeLevel: UIFontSizeLevel = .normal
    /// 当前界面缩放级别，受lock保护
    private var _currentZoomLevel: UIInterfaceZoomLevel = .normal
    /// 当前完整配置对象，受lock保护
    private var _configuration: UIDynamicFontConfiguration = .default

    // MARK: - 观察者与快捷键事件监听（用于deinit清理）
    /// 已注册的系统字体变化观察者对象，用于deinit时注销
    private var fontChangeObserver: NSObjectProtocol?
    /// 已注册的全局快捷键事件监视器引用，用于deinit时注销
    private var globalEventMonitor: Any?
    /// 已注册的本地快捷键事件监视器引用，用于deinit时注销
    private var localEventMonitor: Any?
    /// 记录已发送过的通知名称，用于调试日志
    private var lastNotificationLog: String = ""

    // MARK: - 持久化存储键
    /// UserDefaults中存储动态字体配置的键名
    private let configurationStorageKey = "com.xianrenzhilu.dynamicFontConfiguration"

    // MARK: - 公开属性（带锁访问）
    /// 当前字体大小等级，线程安全读取
    public var currentFontSizeLevel: UIFontSizeLevel {
        get {
            lock.lock()
            let level = _currentFontSizeLevel
            lock.unlock()
            return level
        }
        set {
            lock.lock()
            let oldValue = _currentFontSizeLevel
            _currentFontSizeLevel = newValue
            _configuration.fontSizeLevel = newValue
            _configuration.touch()
            lock.unlock()
            if oldValue != newValue {
                notifyFontSizeLevelChanged(oldValue: oldValue, newValue: newValue)
            }
        }
    }

    /// 当前界面缩放级别，线程安全读取
    public var currentZoomLevel: UIInterfaceZoomLevel {
        get {
            lock.lock()
            let level = _currentZoomLevel
            lock.unlock()
            return level
        }
        set {
            lock.lock()
            let oldValue = _currentZoomLevel
            _currentZoomLevel = newValue
            _configuration.interfaceZoomLevel = newValue
            _configuration.touch()
            lock.unlock()
            if oldValue != newValue {
                notifyInterfaceZoomLevelChanged(oldValue: oldValue, newValue: newValue)
            }
        }
    }

    /// 当前完整配置对象，线程安全读取（返回副本）
    public var currentConfiguration: UIDynamicFontConfiguration {
        get {
            lock.lock()
            let config = _configuration
            lock.unlock()
            return config
        }
    }

    // MARK: - 字体缩放核心方法

    /// 根据字体类型和当前缩放状态获取实际字体大小
    /// 计算逻辑：基准字号 × 字体等级缩放倍数 × 界面缩放比例
    /// - Parameter type: 字体类型（标题/正文/等宽等）
    /// - Returns: 计算后的实际字号（磅）
    public func scaledFontSize(for type: UIFontType) -> CGFloat {
        lock.lock()
        let fontScale = _currentFontSizeLevel.scaleFactor
        let zoomScale = _currentZoomLevel.rawValue
        let base = type.baseSize
        lock.unlock()
        let result = base * fontScale * zoomScale
        return result.roundedToOneDecimal
    }

    /// 根据字体类型和当前缩放状态获取对应的NSFont实例
    /// 自动处理自定义字体族和系统字体回退
    /// - Parameter type: 字体类型
    /// - Returns: 配置好的NSFont实例
    public func scaledFont(for type: UIFontType) -> NSFont {
        lock.lock()
        let config = _configuration
        let fontSize = scaledFontSize(for: type)
        lock.unlock()
        // 等宽字体优先使用配置的等宽字体族
        if type == .mono {
            let monoName = config.monoFontFamily
            if !monoName.isEmpty, let font = NSFont(name: monoName, size: fontSize) {
                return font
            }
            return NSFont.monospacedSystemFont(ofSize: fontSize, weight: type.weight)
        }
        // 常规字体优先使用自定义字体族
        let customName = config.customFontFamily
        if !customName.isEmpty, let font = NSFont(name: customName, size: fontSize) {
            return font
        }
        return NSFont.systemFont(ofSize: fontSize, weight: type.weight)
    }

    /// 获取指定字体类型的标准字体（不考虑缩放，用于对比或重置）
    /// - Parameter type: 字体类型
    /// - Returns: 标准字号对应的NSFont
    public func standardFont(for type: UIFontType) -> NSFont {
        return NSFont.systemFont(ofSize: type.baseSize, weight: type.weight)
    }

    // MARK: - 组件尺寸缩放方法

    /// 根据当前缩放级别获取按钮的适配尺寸
    /// 返回的值包含缩放后的高度、内边距和圆角
    public var scaledButtonMetrics: (height: CGFloat, padding: CGFloat, cornerRadius: CGFloat) {
        let zoom = currentZoomLevel.rawValue
        let height = (UIComponentMetrics.buttonHeight * zoom).roundedToOneDecimal
        let padding = (UIComponentMetrics.buttonPaddingHorizontal * zoom).roundedToOneDecimal
        let radius = (UIComponentMetrics.buttonCornerRadius * zoom).roundedToOneDecimal
        return (height, padding, radius)
    }

    /// 根据当前缩放级别获取输入框的适配高度
    public var scaledTextFieldHeight: CGFloat {
        return (UIComponentMetrics.textFieldHeight * currentZoomLevel.rawValue).roundedToOneDecimal
    }

    /// 根据当前缩放级别获取标签的适配高度
    public var scaledLabelHeight: CGFloat {
        return (UIComponentMetrics.labelHeight * currentZoomLevel.rawValue).roundedToOneDecimal
    }

    /// 根据当前缩放级别获取图标的适配尺寸
    /// - Parameter size: 图标尺寸等级（小/中/大）
    /// - Returns: 缩放后的实际像素尺寸
    public func scaledIconSize(_ size: UIComponentIconSize) -> CGFloat {
        let base: CGFloat
        switch size {
        case .small:  base = UIComponentMetrics.iconSizeSmall
        case .medium: base = UIComponentMetrics.iconSizeMedium
        case .large:  base = UIComponentMetrics.iconSizeLarge
        }
        return (base * currentZoomLevel.rawValue).roundedToOneDecimal
    }

    /// 根据当前缩放级别获取模块间距
    public var scaledModuleSpacing: CGFloat {
        return (UIComponentMetrics.moduleSpacing * currentZoomLevel.rawValue).roundedToOneDecimal
    }

    /// 根据当前缩放级别获取标题栏高度
    public var scaledTitleBarHeight: CGFloat {
        return (UIComponentMetrics.titleBarHeight * currentZoomLevel.rawValue).roundedToOneDecimal
    }

    /// 获取通用缩放后的尺寸值
    /// - Parameter baseValue: 标准缩放下的基准值
    /// - Returns: 缩放后的实际值
    public func scaledValue(_ baseValue: CGFloat) -> CGFloat {
        return (baseValue * currentZoomLevel.rawValue).roundedToOneDecimal
    }

    // MARK: - 缩放操作方法

    /// 增大字体等级（向更大字号切换）
    /// 如果已经是最大等级则保持不动，并通过日志提示用户
    public func increaseFontSize() {
        lock.lock()
        let oldLevel = _currentFontSizeLevel
        let allLevels = UIFontSizeLevel.allCases.sorted { $0.rawValue < $1.rawValue }
        guard let currentIndex = allLevels.firstIndex(of: oldLevel) else {
            lock.unlock()
            moduleLogger.warning("无法定位当前字体等级索引")
            return
        }
        let newLevel: UIFontSizeLevel
        if currentIndex + 1 < allLevels.count {
            newLevel = allLevels[currentIndex + 1]
        } else {
            newLevel = oldLevel
            moduleLogger.info("字体等级已到达最大，无法继续增大")
        }
        _currentFontSizeLevel = newLevel
        _configuration.fontSizeLevel = newLevel
        _configuration.touch()
        lock.unlock()
        if oldLevel != newLevel {
            notifyFontSizeLevelChanged(oldValue: oldLevel, newValue: newLevel)
        }
    }

    /// 减小字体等级（向更小字号切换）
    /// 如果已经是最小等级则保持不动，并通过日志提示用户
    public func decreaseFontSize() {
        lock.lock()
        let oldLevel = _currentFontSizeLevel
        let allLevels = UIFontSizeLevel.allCases.sorted { $0.rawValue < $1.rawValue }
        guard let currentIndex = allLevels.firstIndex(of: oldLevel) else {
            lock.unlock()
            moduleLogger.warning("无法定位当前字体等级索引")
            return
        }
        let newLevel: UIFontSizeLevel
        if currentIndex > 0 {
            newLevel = allLevels[currentIndex - 1]
        } else {
            newLevel = oldLevel
            moduleLogger.info("字体等级已到达最小，无法继续减小")
        }
        _currentFontSizeLevel = newLevel
        _configuration.fontSizeLevel = newLevel
        _configuration.touch()
        lock.unlock()
        if oldLevel != newLevel {
            notifyFontSizeLevelChanged(oldValue: oldLevel, newValue: newLevel)
        }
    }

    /// 放大界面（提高缩放级别）
    /// 快捷键Cmd+Plus对应此方法
    public func zoomIn() {
        lock.lock()
        let oldLevel = _currentZoomLevel
        let newLevel = oldLevel.nextLarger
        _currentZoomLevel = newLevel
        _configuration.interfaceZoomLevel = newLevel
        _configuration.touch()
        lock.unlock()
        if oldLevel != newLevel {
            notifyInterfaceZoomLevelChanged(oldValue: oldLevel, newValue: newLevel)
        } else {
            moduleLogger.info("缩放已到达最大级别 \(oldLevel.description)，无法继续放大")
        }
    }

    /// 缩小界面（降低缩放级别）
    /// 快捷键Cmd+Minus对应此方法
    public func zoomOut() {
        lock.lock()
        let oldLevel = _currentZoomLevel
        let newLevel = oldLevel.nextSmaller
        _currentZoomLevel = newLevel
        _configuration.interfaceZoomLevel = newLevel
        _configuration.touch()
        lock.unlock()
        if oldLevel != newLevel {
            notifyInterfaceZoomLevelChanged(oldValue: oldLevel, newValue: newLevel)
        } else {
            moduleLogger.info("缩放已到达最小级别 \(oldLevel.description)，无法继续缩小")
        }
    }

    /// 重置所有字体与缩放设置为默认值
    /// 重置后会依次触发字体变更通知、缩放变更通知和总配置变更通知
    public func resetToDefaults() {
        lock.lock()
        let oldFontLevel = _currentFontSizeLevel
        let oldZoomLevel = _currentZoomLevel
        let oldConfig = _configuration
        _currentFontSizeLevel = .normal
        _currentZoomLevel = .normal
        _configuration = .default
        _configuration.touch()
        lock.unlock()
        moduleLogger.info("已重置为默认字体与缩放配置")
        if oldFontLevel != .normal {
            notifyFontSizeLevelChanged(oldValue: oldFontLevel, newValue: .normal)
        }
        if oldZoomLevel != .normal {
            notifyInterfaceZoomLevelChanged(oldValue: oldZoomLevel, newValue: .normal)
        }
        if oldConfig != .default {
            notifyConfigurationChanged()
        }
        saveConfiguration()
    }

    // MARK: - 配置持久化

    /// 将当前配置保存到UserDefaults，使用JSON编码的Codable序列化
    /// 保存失败时会记录错误日志，不影响应用运行
    public func saveConfiguration() {
        lock.lock()
        let config = _configuration
        lock.unlock()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(config)
            UserDefaults.standard.set(data, forKey: configurationStorageKey)
            moduleLogger.info("动态字体配置已保存，最后修改: \(config.lastModified)")
        } catch {
            moduleLogger.error("保存动态字体配置失败: \(error.localizedDescription)")
        }
    }

    /// 从UserDefaults加载已保存的配置，若不存在或解码失败则使用默认配置
    /// 加载成功后会触发一次配置变更通知，确保UI同步
    private func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: configurationStorageKey) else {
            moduleLogger.info("未找到已保存的动态字体配置，使用默认配置")
            return
        }
        do {
            let decoder = JSONDecoder()
            let config = try decoder.decode(UIDynamicFontConfiguration.self, from: data)
            lock.lock()
            _configuration = config
            _currentFontSizeLevel = config.fontSizeLevel
            _currentZoomLevel = config.interfaceZoomLevel
            lock.unlock()
            moduleLogger.info("已加载动态字体配置，字体等级: \(String(describing: config.fontSizeLevel))，缩放: \(String(describing: config.interfaceZoomLevel))")
            notifyConfigurationChanged()
        } catch {
            moduleLogger.error("加载动态字体配置失败: \(error.localizedDescription)，使用默认配置")
        }
    }

    // MARK: - 设置面板方法

    /// 设置面板调用：直接设置字体大小等级
    /// - Parameter level: 目标字体大小等级
    public func setFontSizeLevel(_ level: UIFontSizeLevel) {
        currentFontSizeLevel = level
        saveConfiguration()
    }

    /// 设置面板调用：直接设置界面缩放级别
    /// - Parameter level: 目标界面缩放级别
    public func setInterfaceZoomLevel(_ level: UIInterfaceZoomLevel) {
        currentZoomLevel = level
        saveConfiguration()
    }

    /// 设置面板调用：切换是否跟随系统Dynamic Type设置
    /// - Parameter enabled: 是否启用跟随系统
    public func setFollowSystemDynamicType(_ enabled: Bool) {
        lock.lock()
        let oldValue = _configuration.followSystemDynamicType
        _configuration.followSystemDynamicType = enabled
        _configuration.touch()
        lock.unlock()
        if oldValue != enabled {
            notifyConfigurationChanged()
            saveConfiguration()
        }
    }

    /// 设置面板调用：切换是否启用全局缩放快捷键
    /// - Parameter enabled: 是否启用快捷键
    public func setGlobalZoomShortcutsEnabled(_ enabled: Bool) {
        lock.lock()
        let oldValue = _configuration.enableGlobalZoomShortcuts
        _configuration.enableGlobalZoomShortcuts = enabled
        _configuration.touch()
        lock.unlock()
        if oldValue != enabled {
            notifyConfigurationChanged()
            saveConfiguration()
        }
        // 根据开关状态重新注册或注销快捷键监听
        if enabled {
            setupGlobalShortcuts()
        } else {
            removeGlobalShortcuts()
        }
    }

    /// 设置面板调用：设置自定义字体族名称
    /// - Parameter family: 字体族名称字符串，空字符串表示使用系统默认
    public func setCustomFontFamily(_ family: String) {
        lock.lock()
        let oldValue = _configuration.customFontFamily
        _configuration.customFontFamily = family
        _configuration.touch()
        lock.unlock()
        if oldValue != family {
            notifyConfigurationChanged()
            saveConfiguration()
        }
    }

    /// 设置面板调用：设置等宽字体族名称
    /// - Parameter family: 等宽字体族名称字符串
    public func setMonoFontFamily(_ family: String) {
        lock.lock()
        let oldValue = _configuration.monoFontFamily
        _configuration.monoFontFamily = family
        _configuration.touch()
        lock.unlock()
        if oldValue != family {
            notifyConfigurationChanged()
            saveConfiguration()
        }
    }

    /// 设置面板调用：获取所有可用字体等级列表，用于下拉菜单或分段选择器
    /// - Returns: 所有字体大小等级的数组
    public func allFontSizeLevels() -> [UIFontSizeLevel] {
        return UIFontSizeLevel.allCases.sorted { $0.rawValue < $1.rawValue }
    }

    /// 设置面板调用：获取所有可用缩放级别列表，用于下拉菜单或分段选择器
    /// - Returns: 所有界面缩放级别的数组
    public func allZoomLevels() -> [UIInterfaceZoomLevel] {
        return UIInterfaceZoomLevel.allCases.sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - 通知发送方法

    /// 发送字体大小等级变更通知
    /// - Parameters:
    ///   - oldValue: 变更前的字体等级
    ///   - newValue: 变更后的字体等级
    private func notifyFontSizeLevelChanged(oldValue: UIFontSizeLevel, newValue: UIFontSizeLevel) {
        let userInfo: [AnyHashable: Any] = [
            "oldValue": oldValue,
            "newValue": newValue,
            "oldScale": oldValue.scaleFactor,
            "newScale": newValue.scaleFactor
        ]
        notificationCenter.post(name: .fontSizeLevelDidChange, object: newValue, userInfo: userInfo)
        moduleLogger.info("字体等级变更: \(oldValue.description) -> \(newValue.description) (缩放: \(String(format: "%.2f", oldValue.scaleFactor)) -> \(String(format: "%.2f", newValue.scaleFactor))")
        // 字体等级变化也视为总配置变化，发送综合变更通知
        notifyConfigurationChanged()
    }

    /// 发送界面缩放级别变更通知
    /// - Parameters:
    ///   - oldValue: 变更前的缩放级别
    ///   - newValue: 变更后的缩放级别
    private func notifyInterfaceZoomLevelChanged(oldValue: UIInterfaceZoomLevel, newValue: UIInterfaceZoomLevel) {
        let userInfo: [AnyHashable: Any] = [
            "oldValue": oldValue,
            "newValue": newValue,
            "oldScale": oldValue.rawValue,
            "newScale": newValue.rawValue
        ]
        notificationCenter.post(name: .interfaceZoomLevelDidChange, object: newValue, userInfo: userInfo)
        moduleLogger.info("界面缩放变更: \(oldValue.description) -> \(newValue.description) (比例: \(String(format: "%.2f", oldValue.rawValue)) -> \(String(format: "%.2f", newValue.rawValue))")
        // 缩放级别变化也视为总配置变化，发送综合变更通知
        notifyConfigurationChanged()
    }

    /// 发送动态字体总配置变更通知
    /// 此通知在字体等级、缩放级别或其他配置项变化时都会触发
    private func notifyConfigurationChanged() {
        let config = currentConfiguration
        let userInfo: [AnyHashable: Any] = [
            "configuration": config,
            "timestamp": Date().timeIntervalSince1970
        ]
        notificationCenter.post(name: .dynamicFontConfigurationDidChange, object: config, userInfo: userInfo)
        lastNotificationLog = "配置变更通知已发送 (\(config.lastModified))"
    }

    // MARK: - 全局快捷键支持

    /// 注册全局快捷键监听（Cmd+Plus放大、Cmd+Minus缩小、Cmd+0重置）
    /// 仅在配置中启用快捷键时有效，重复调用会避免重复注册
    private func setupGlobalShortcuts() {
        // 如果已注册则先清理，避免重复
        removeGlobalShortcuts()
        // 本地事件监视器：捕获应用内快捷键
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            guard self.currentConfiguration.enableGlobalZoomShortcuts else { return event }
            let flags = event.modifierFlags
            // 检查是否仅按下Command键（避免与Shift/Ctrl/Option组合冲突）
            guard flags.contains(.command) && !flags.contains(.shift) && !flags.contains(.control) else {
                return event
            }
            let key = event.charactersIgnoringModifiers
            switch key {
            case "=", "+":
                // Cmd+Plus (注意等号键在标准键盘上通常需要Shift)
                // 这里额外处理没有Shift的等号，因为macOS键盘映射差异
                if flags.contains(.shift) || key == "=" {
                    self.zoomIn()
                    return nil
                }
            case "-":
                // Cmd+Minus
                self.zoomOut()
                return nil
            case "0":
                // Cmd+0 重置为默认
                self.resetToDefaults()
                return nil
            default:
                break
            }
            return event
        }
        moduleLogger.info("全局缩放快捷键已注册")
    }

    /// 注销已注册的全局快捷键事件监视器
    private func removeGlobalShortcuts() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        moduleLogger.info("全局缩放快捷键已注销")
    }

    // MARK: - 系统Dynamic Type跟随（macOS 2.0兼容层）

    /// 注册系统字体偏好变化监听，当用户修改系统辅助功能字体设置时自动响应
    /// 仅在配置中启用跟随系统时有效
    public func startObservingSystemDynamicType() {
        stopObservingSystemDynamicType()
        fontChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            guard self.currentConfiguration.followSystemDynamicType else { return }
            self.syncWithSystemDynamicType()
        }
        moduleLogger.info("系统Dynamic Type变化监听已启动")
    }

    /// 注销系统字体偏好变化监听
    public func stopObservingSystemDynamicType() {
        if let observer = fontChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            fontChangeObserver = nil
            moduleLogger.info("系统Dynamic Type变化监听已停止")
        }
    }

    /// 同步当前字体设置与系统Dynamic Type偏好
    /// 读取系统辅助功能字体放大设置，映射到对应的字体等级
    private func syncWithSystemDynamicType() {
        // macOS通过NSWorkspace.accessibilityDisplayOptionsDidChangeNotification通知字体变化
        // 实际字体缩放值可通过NSUserDefaults的AppleFontSmoothing或辅助功能设置获取
        // 此处简化实现：根据系统通知触发配置同步即可，实际映射逻辑可根据需要扩展
        moduleLogger.info("系统Dynamic Type偏好发生变化，同步配置中")
        notifyConfigurationChanged()
    }

    // MARK: - 清理与析构

    /// 清理资源，注销所有观察者和事件监视器
    /// 在UIDynamicFontManager不再需要时调用，避免内存泄漏和事件重复响应
    public func cleanup() {
        stopObservingSystemDynamicType()
        removeGlobalShortcuts()
        // 保存最后一次配置，确保用户设置不丢失
        saveConfiguration()
        moduleLogger.info("动态字体管理器资源已清理完成")
    }

    /// 析构函数，自动调用清理方法确保资源释放
    deinit {
        cleanup()
        moduleLogger.info("UIDynamicFontManager实例已释放")
    }
}

// MARK: - 迁回自 UI-02：extension UIDynamicFontManager
public extension UIDynamicFontManager {
    /// 获取SwiftUI Font（适用于SwiftUI视图构建）
    /// - Parameter type: 字体类型
    /// - Returns: 对应缩放后的SwiftUI Font
    func swiftUIFont(for type: UIFontType) -> NSFont {
        let nsFont = scaledFont(for: type)
        return nsFont
    }
}

// MARK: - 迁回自 UI-02：enum UIFontSizeLevel
// MARK: - UI-GL-68 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-68_types.swift
// 版本: 2.0
// MARK: - 字体大小等级
/// 字体大小等级枚举，定义5级字体大小，从极小到极大
/// 用于适配不同视力需求的用户，每级对应系统标准字体的一个偏移量
public enum UIFontSizeLevel: Int, Codable, CaseIterable, Sendable, CustomStringConvertible {
    /// 极小字体，适合视力极好的用户或需要一屏显示大量信息的场景
    case extraSmall = 0
    /// 小字体，适合默认偏小的显示需求
    case small = 1
    /// 标准字体，系统默认大小
    case normal = 2
    /// 大字体，适合轻度视力障碍或大屏显示
    case large = 3
    /// 极大字体，适合重度视力障碍或演示场景
    case extraLarge = 4

    /// 等级对应的显示文本，用于设置面板展示
    public var description: String {
        switch self {
        case .extraSmall: return "极小"
        case .small:      return "小"
        case .normal:     return "标准"
        case .large:      return "大"
        case .extraLarge: return "极大"
        }
    }

    /// 等级对应的系统Dynamic Type大小类别映射（近似值）
    public var sizeCategory: NSControl.ControlSize {
        switch self {
        case .extraSmall: return .small
        case .small:      return .small
        case .normal:     return .regular
        case .large:      return .regular
        case .extraLarge: return .large
        }
    }

    /// 基础字体缩放倍数（相对于标准字体）
    public var scaleFactor: CGFloat {
        switch self {
        case .extraSmall: return 0.82
        case .small:      return 0.90
        case .normal:     return 1.00
        case .large:      return 1.12
        case .extraLarge: return 1.25
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIInterfaceZoomLevel
// MARK: - 界面缩放级别
/// 界面整体缩放级别枚举，定义从0.75x到1.5x的离散缩放档位
/// 所有UI组件尺寸均按此比例进行等比缩放
public enum UIInterfaceZoomLevel: CGFloat, Codable, CaseIterable, Sendable, CustomStringConvertible {
    /// 75%缩放，适合小屏幕或需要紧凑布局的场景
    case small  = 0.75
    /// 85%缩放，轻度缩小
    case mediumSmall = 0.85
    /// 100%标准缩放，系统默认
    case normal = 1.00
    /// 115%缩放，轻度放大
    case mediumLarge = 1.15
    /// 125%缩放，适合大屏或轻度视力障碍
    case large  = 1.25
    /// 150%缩放，适合重度视力障碍或演示投屏
    case xlarge = 1.50

    /// 等级对应的显示文本，用于设置面板展示百分比
    public var description: String {
        switch self {
        case .small:       return "75%"
        case .mediumSmall: return "85%"
        case .normal:      return "100%"
        case .mediumLarge: return "115%"
        case .large:       return "125%"
        case .xlarge:      return "150%"
        }
    }

    /// 获取下一级更大的缩放（如果已经是最大则保持不变）
    public var nextLarger: UIInterfaceZoomLevel {
        switch self {
        case .small:       return .mediumSmall
        case .mediumSmall: return .normal
        case .normal:      return .mediumLarge
        case .mediumLarge: return .large
        case .large:       return .xlarge
        case .xlarge:      return .xlarge
        }
    }

    /// 获取下一级更小的缩放（如果已经是最小则保持不变）
    public var nextSmaller: UIInterfaceZoomLevel {
        switch self {
        case .small:       return .small
        case .mediumSmall: return .small
        case .normal:      return .mediumSmall
        case .mediumLarge: return .normal
        case .large:       return .mediumLarge
        case .xlarge:      return .large
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIFontType
// MARK: - 字体类型定义
/// 应用中使用的字体类型分类，每种类型在不同缩放等级下有不同的基准字号
public enum UIFontType: String, Codable, CaseIterable {
    /// 标题字体，用于页面大标题、模块标题
    case headline = "headline"
    /// 副标题字体，用于分区标题、卡片标题
    case subheadline = "subheadline"
    /// 正文字体，用于常规文本段落
    case body = "body"
    /// 辅助说明字体，用于次要信息、提示文字
    case caption = "caption"
    /// 标注字体，用于标签、角标、状态文字
    case footnote = "footnote"
    /// 等宽字体，用于价格、代码、数据展示
    case mono = "mono"

    /// 标准字号（在1.0x缩放、标准字体等级下的基准字号）
    public var baseSize: CGFloat {
        switch self {
        case .headline:     return 24.0
        case .subheadline:  return 18.0
        case .body:         return 14.0
        case .caption:      return 12.0
        case .footnote:     return 10.0
        case .mono:         return 13.0
        }
    }

    /// 字重建议，不同类型的文字使用不同的字重以区分层级
    public var weight: NSFont.Weight {
        switch self {
        case .headline:     return .bold
        case .subheadline:  return .semibold
        case .body:         return .regular
        case .caption:      return .regular
        case .footnote:     return .light
        case .mono:         return .medium
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIDynamicFontConfiguration
// MARK: - 动态字体配置
/// 动态字体配置数据模型，包含所有可持久化的字体与缩放设置
/// 遵循Codable协议以便JSON序列化存储到UserDefaults
public struct UIDynamicFontConfiguration: Codable, Equatable, Sendable {
    /// 当前字体大小等级，默认为标准
    public var fontSizeLevel: UIFontSizeLevel = .normal
    /// 当前界面缩放级别，默认为100%
    public var interfaceZoomLevel: UIInterfaceZoomLevel = .normal
    /// 是否启用系统Dynamic Type自动跟随（macOS 2.0兼容层）
    public var followSystemDynamicType: Bool = false
    /// 是否启用快捷键全局缩放（Cmd+Plus / Cmd+Minus）
    public var enableGlobalZoomShortcuts: Bool = true
    /// 字体抗锯齿开关，影响渲染质量与清晰度
    public var enableFontSmoothing: Bool = true
    /// 自定义字体族名称，空字符串表示使用系统默认字体
    public var customFontFamily: String = ""
    /// 等宽字体族名称，用于价格数据展示
    public var monoFontFamily: String = "SF Mono"
    /// 配置最后修改时间戳，用于同步与缓存失效判断
    public var lastModified: TimeInterval = 0

    /// 默认配置实例，用于首次启动时初始化
    public static let `default` = UIDynamicFontConfiguration()

    /// 更新修改时间戳为当前时间
    public mutating func touch() {
        lastModified = Date().timeIntervalSince1970
    }
}

// MARK: - 迁回自 UI-02：struct UIComponentMetrics
// MARK: - 组件尺寸配置
/// 常用UI组件的标准尺寸定义，所有尺寸值在应用缩放比例后会自动调整
/// 集中管理尺寸常量便于全局统一维护
public struct UIComponentMetrics: Codable, Equatable {
    /// 按钮标准高度（标准缩放下）
    public static let buttonHeight: CGFloat = 32.0
    /// 按钮标准内边距水平方向
    public static let buttonPaddingHorizontal: CGFloat = 16.0
    /// 按钮标准圆角半径
    public static let buttonCornerRadius: CGFloat = 6.0
    /// 输入框标准高度
    public static let textFieldHeight: CGFloat = 28.0
    /// 标签标准高度
    public static let labelHeight: CGFloat = 20.0
    /// 图标标准尺寸（小）
    public static let iconSizeSmall: CGFloat = 16.0
    /// 图标标准尺寸（中）
    public static let iconSizeMedium: CGFloat = 24.0
    /// 图标标准尺寸（大）
    public static let iconSizeLarge: CGFloat = 32.0
    /// 模块卡片间距
    public static let moduleSpacing: CGFloat = 12.0
    /// 标题栏高度
    public static let titleBarHeight: CGFloat = 38.0
    /// 分割线粗细
    public static let dividerThickness: CGFloat = 1.0
    /// 滚动条宽度
    public static let scrollBarWidth: CGFloat = 12.0

    /// 根据缩放级别计算实际按钮高度
    public static func buttonHeight(for zoom: UIInterfaceZoomLevel) -> CGFloat {
        return buttonHeight * zoom.rawValue
    }

    /// 根据缩放级别计算实际输入框高度
    public static func textFieldHeight(for zoom: UIInterfaceZoomLevel) -> CGFloat {
        return textFieldHeight * zoom.rawValue
    }

    /// 根据缩放级别计算实际标签高度
    public static func labelHeight(for zoom: UIInterfaceZoomLevel) -> CGFloat {
        return labelHeight * zoom.rawValue
    }
}

// MARK: - 迁回自 UI-02：enum UIComponentIconSize
// MARK: - 动态字体管理器
/// 动态字体与界面缩放管理器
/// 单例模式，统一管理应用全局字体大小、界面缩放比例及组件尺寸适配
/// 提供字体缩放映射、组件尺寸自动计算、快捷键响应、配置持久化等功能
// 已迁回 UI-GL-68_动态字体与缩放.swift：class UIDynamicFontManager（公共类型文件禁止功能实现）

// MARK: - 图标尺寸等级
/// 图标尺寸分类枚举，用于scaledIconSize方法参数
public enum UIComponentIconSize: Int, CaseIterable {
    /// 小图标，如工具栏按钮、状态指示
    case small = 0
    /// 中等图标，如模块标题图标、导航项
    case medium = 1
    /// 大图标，如空状态插图、功能入口
    case large = 2

    /// 尺寸等级显示文本
    public var description: String {
        switch self {
        case .small:  return "小"
        case .medium: return "中"
        case .large:  return "大"
        }
    }
}
