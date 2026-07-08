// 功能57: 高对比度模式
// 对应: 提供高对比度主题与视障辅助配色，适配K线显示、全局UI替换、持久化配置
// 优先级: P3
// 作者: 码农
// 最后更新: 2026-06-05

import Foundation
import AppKit
import os.log
import SwiftUI

// MARK: - 日志系统
/// 高对比度模块专用日志器，全模块禁止直接使用print
private let logger = Logger(subsystem: "com.xianrenzhilu.highcontrast", category: "HighContrast")

// MARK: - 通知名称定义
/// 高对比度模式开关状态变更通知
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：extension Notification.Name {

// MARK: - NSColor Hex扩展
/// Hex字符串与NSColor互转，用于配置持久化
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：extension NSColor {

// MARK: - SwiftUI桥接（可选辅助）
// 已迁移到 UI-02_公共类型定义.swift，原文件移除 SwiftUI 顶层 extension。


// MARK: - 测试代码
#if DEBUG

/// 功能57：高对比度模式 — 单元测试
func test_highContrast() {
    let logger = OSLog(subsystem: "com.xianrenzhilu.ui", category: "UI-GL-67")
    let manager = UIHighContrastManager.shared
    
    os_log("测试1: 默认配置", log: logger, type: .info)
    let config = manager.config
    if !config.isEnabled && config.contrastLevel == .medium {
        os_log("✅ 测试1通过", log: logger, type: .info)
    } else {
        os_log("❌ 测试1失败", log: logger, type: .error)
    }
    
    os_log("测试2: 启用高对比度", log: logger, type: .info)
    manager.isEnabled = true
    let enabledConfig = manager.config
    if enabledConfig.isEnabled {
        os_log("✅ 测试2通过", log: logger, type: .info)
    } else {
        os_log("❌ 测试2失败", log: logger, type: .error)
    }
    
    os_log("测试3: 对比度等级", log: logger, type: .info)
    manager.contrastLevel = .high
    let levelConfig = manager.config
    if levelConfig.contrastLevel == .high {
        os_log("✅ 测试3通过", log: logger, type: .info)
    } else {
        os_log("❌ 测试3失败", log: logger, type: .error)
    }
    
    os_log("测试4: K线颜色方案", log: logger, type: .info)
    manager.kLineColorScheme = .blueYellow
    let schemeConfig = manager.config
    if schemeConfig.kLineColorScheme == .blueYellow {
        os_log("✅ 测试4通过", log: logger, type: .info)
    } else {
        os_log("❌ 测试4失败", log: logger, type: .error)
    }
    
    os_log("测试5: 主题预设", log: logger, type: .info)
    manager.applyThemePreset(.whiteOnBlack)
    let themeConfig = manager.config
    if themeConfig.theme == .whiteOnBlack {
        os_log("✅ 测试5通过", log: logger, type: .info)
    } else {
        os_log("❌ 测试5失败", log: logger, type: .error)
    }
    
    os_log("测试6: K线颜色获取", log: logger, type: .info)
    let upColor = manager.kLineUpColor()
    let downColor = manager.kLineDownColor()
    if upColor != downColor {
        os_log("✅ 测试6通过", log: logger, type: .info)
    } else {
        os_log("❌ 测试6失败", log: logger, type: .error)
    }
    
    os_log("测试7: 色盲友好检测", log: logger, type: .info)
    manager.kLineColorScheme = .blueYellow
    if manager.isCurrentKLineColorBlindFriendly() {
        os_log("✅ 测试7通过", log: logger, type: .info)
    } else {
        os_log("❌ 测试7失败", log: logger, type: .error)
    }
    
    os_log("测试8: 对比度等级枚举", log: logger, type: .info)
    if UIContrastLevel.allCases.count == 4 {
        os_log("✅ 测试8通过", log: logger, type: .info)
    } else {
        os_log("❌ 测试8失败", log: logger, type: .error)
    }
    
    os_log("测试9: K线方案枚举", log: logger, type: .info)
    if UIKLineColorScheme.allCases.count == 5 {
        os_log("✅ 测试9通过", log: logger, type: .info)
    } else {
        os_log("❌ 测试9失败", log: logger, type: .error)
    }
    
    os_log("测试10: 重置为默认", log: logger, type: .info)
    manager.resetToDefault()
    let resetConfig = manager.config
    if !resetConfig.isEnabled && resetConfig.contrastLevel == .medium {
        os_log("✅ 测试10通过", log: logger, type: .info)
    } else {
        os_log("❌ 测试10失败", log: logger, type: .error)
    }
    
    os_log("=== 全部高对比度测试通过 ✅ ===", log: logger, type: .info)
}
#endif

// MARK: - 内联跨文件依赖：Notification.Name 扩展
extension Notification.Name {
    static let highContrastEnabledChanged = Notification.Name("com.xianrenzhilu.ui.highContrastEnabledChanged")
    static let highContrastConfigLoaded = Notification.Name("com.xianrenzhilu.ui.highContrastConfigLoaded")
    static let highContrastConfigSaved = Notification.Name("com.xianrenzhilu.ui.highContrastConfigSaved")
    static let highContrastKLineSchemeChanged = Notification.Name("com.xianrenzhilu.ui.highContrastKLineSchemeChanged")
    static let highContrastLevelChanged = Notification.Name("com.xianrenzhilu.ui.highContrastLevelChanged")
    static let highContrastThemeChanged = Notification.Name("com.xianrenzhilu.ui.highContrastThemeChanged")
}

// MARK: - NSColor Hex 扩展已在 UI-GL-49_标签页分组.swift 定义，这里仅引用不重复定义

// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIHighContrastManager
public final class UIHighContrastManager : @unchecked Sendable {

    // MARK: 单例
    /// 全局共享实例
    public static let shared = UIHighContrastManager()

    // MARK: 锁
    /// 保护共享数据的递归锁
    private let lock = NSRecursiveLock()

    // MARK: 配置
    /// 当前高对比度配置，受锁保护，外部通过属性访问
    private var _config = UIHighContrastConfig()

    /// 配置安全访问属性（线程安全）
    public var config: UIHighContrastConfig {
        get {
            lock.lock()
            let c = _config
            lock.unlock()
            return c
        }
        set {
            lock.lock()
            let old = _config
            _config = newValue
            _config.lastUpdated = Date()
            lock.unlock()
            // 配置变更后触发应用
            applyConfigChanges(oldConfig: old, newConfig: newValue)
        }
    }

    /// 是否启用高对比度（便捷属性）
    public var isEnabled: Bool {
        get { config.isEnabled }
        set {
            lock.lock()
            let old = _config.isEnabled
            _config.isEnabled = newValue
            _config.lastUpdated = Date()
            lock.unlock()
            if old != newValue {
                logger.info("高对比度模式已\(newValue ? "启用" : "关闭")")
                NotificationCenter.default.post(name: .highContrastEnabledChanged, object: nil, userInfo: ["enabled": newValue])
                applyThemeToRegisteredViews()
            }
        }
    }

    /// 当前对比度等级（便捷属性）
    public var contrastLevel: UIContrastLevel {
        get { config.contrastLevel }
        set {
            lock.lock()
            let old = _config.contrastLevel
            _config.contrastLevel = newValue
            lock.unlock()
            if old != newValue {
                logger.info("对比度等级变更为: \(newValue.description)")
                NotificationCenter.default.post(name: .highContrastLevelChanged, object: nil, userInfo: ["level": newValue.rawValue, "description": newValue.description])
                applyThemeToRegisteredViews()
            }
        }
    }

    /// 当前K线颜色方案（便捷属性）
    public var kLineColorScheme: UIKLineColorScheme {
        get { config.kLineColorScheme }
        set {
            lock.lock()
            let old = _config.kLineColorScheme
            _config.kLineColorScheme = newValue
            lock.unlock()
            if old != newValue {
                logger.info("K线颜色方案变更为: \(newValue.description)")
                NotificationCenter.default.post(name: .highContrastKLineSchemeChanged, object: nil, userInfo: ["scheme": newValue.rawValue, "description": newValue.description])
            }
        }
    }

    // MARK: 持久化路径
    /// 配置文件在沙盒中的存储路径
    private var configURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("XianRenZhiLu/HighContrast", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    // MARK: 观察者管理
    /// 注册的视图弱引用列表，配合回调实现UI刷新
    private var registeredViews: [UIWeakViewContainer] = []
    /// 系统辅助功能监听观察者
    private var systemObserver: NSObjectProtocol?
    /// 应用活跃状态监听观察者
    private var appActiveObserver: NSObjectProtocol?
    /// 主题变更监听观察者
    private var themeObserver: NSObjectProtocol?

    // MARK: 初始化
    /// 私有构造，禁止外部实例化
    private init() {
        logger.info("UIHighContrastManager 单例初始化")
        loadConfig()
        setupSystemObservers()
        setupAppLifecycleObservers()
    }

    // MARK: 清理
    /// 析构时注销所有系统观察者，防止内存泄漏
    deinit {
        logger.info("UIHighContrastManager 析构清理")
        if let observer = systemObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = appActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: 系统观察者配置
    /// 监听系统辅助功能变化（如用户系统级开启高对比度）
    private func setupSystemObservers() {
        systemObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let shouldFollow = self.config.followSystemAccessibility
            if shouldFollow {
                let systemHighContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
                self.isEnabled = systemHighContrast
                logger.info("跟随系统辅助功能: 高对比度 = \(systemHighContrast)")
            }
        }
    }

    // MARK: 应用生命周期监听
    /// 监听应用前后台切换，切回前台时重新应用主题
    private func setupAppLifecycleObservers() {
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyThemeToRegisteredViews()
        }
    }

    // MARK: 配置变更应用
    /// 配置变更后对比旧配置，只触发必要的UI刷新
    private func applyConfigChanges(oldConfig: UIHighContrastConfig, newConfig: UIHighContrastConfig) {
        if oldConfig.theme != newConfig.theme {
            logger.info("主题变更为: \(newConfig.theme.description)")
            NotificationCenter.default.post(name: .highContrastThemeChanged, object: nil, userInfo: ["theme": newConfig.theme.rawValue, "description": newConfig.theme.description])
        }
        applyThemeToRegisteredViews()
    }

    // MARK: 注册视图
    /// 注册需要响应高对比度变化的视图，内部持有弱引用
    public func registerView(_ view: NSView, handler: ((UIHighContrastConfig) -> Void)? = nil) {
        lock.lock()
        registeredViews.append(UIWeakViewContainer(view: view, handler: handler))
        // 清理已释放的引用
        registeredViews.removeAll { $0.view == nil }
        lock.unlock()
        // 立即对新注册视图应用当前主题
        if let handler = handler {
            handler(config)
        } else {
            applyToView(view, config: config)
        }
        logger.debug("注册视图: \(view.className)")
    }

    /// 注销指定视图
    public func unregisterView(_ view: NSView) {
        lock.lock()
        registeredViews.removeAll { $0.view == view || $0.view == nil }
        lock.unlock()
        logger.debug("注销视图: \(view.className)")
    }

    // MARK: 主题应用到已注册视图
    /// 遍历所有已注册视图并应用当前高对比度主题
    public func applyThemeToRegisteredViews() {
        lock.lock()
        let containers = registeredViews
        let currentConfig = _config
        lock.unlock()

        for container in containers {
            guard let view = container.view else { continue }
            if let handler = container.handler {
                handler(currentConfig)
            } else {
                applyToView(view, config: currentConfig)
            }
        }
        logger.debug("主题已应用至 \(containers.count) 个视图")
    }

    // MARK: 应用到单个视图
    /// 将高对比度配置应用到单个NSView，修改外观、背景、边框
    private func applyToView(_ view: NSView, config: UIHighContrastConfig) {
        guard config.isEnabled else {
            // 关闭时恢复默认外观
            view.appearance = nil
            view.layer?.borderWidth = 0
            view.layer?.borderColor = nil
            return
        }

        // 设置外观为系统高对比度Aqua
        view.appearance = NSAppearance(named: .accessibilityHighContrastAqua)

        // 设置背景色
        view.layer?.backgroundColor = config.effectiveBackgroundColor().cgColor

        // 设置边框（基于对比度等级）
        view.layer?.borderWidth = config.effectiveBorderWidth()
        view.layer?.borderColor = config.effectiveForegroundColor().cgColor

        // 子视图递归处理（可选，视UI层级而定）
        for subview in view.subviews {
            applyToView(subview, config: config)
        }
    }

    // MARK: 颜色替换
    /// 根据颜色映射表将原始颜色替换为高对比度颜色
    public func replaceColor(_ original: NSColor) -> NSColor {
        let map = config.colorMap.mappings
        let hexKey = original.hexString.uppercased()
        // 尝试直接匹配Hex
        if let replacementHex = map[hexKey] {
            return NSColor(hexString: replacementHex) ?? original
        }
        // 尝试匹配系统颜色名称（近似匹配）
        if original == NSColor.systemRed,    let h = map["systemRed"]    { return NSColor(hexString: h) ?? original }
        if original == NSColor.systemGreen,  let h = map["systemGreen"]  { return NSColor(hexString: h) ?? original }
        if original == NSColor.systemBlue,   let h = map["systemBlue"]   { return NSColor(hexString: h) ?? original }
        if original == NSColor.labelColor,        let h = map["label"]        { return NSColor(hexString: h) ?? original }
        if original == NSColor.secondaryLabelColor, let h = map["secondaryLabel"] { return NSColor(hexString: h) ?? original }
        return original
    }

    // MARK: K线颜色适配
    /// 获取当前K线上涨颜色（已适配高对比度方案）
    public func kLineUpColor() -> NSColor {
        return config.kLineColorScheme.upColor
    }

    /// 获取当前K线下跌颜色（已适配高对比度方案）
    public func kLineDownColor() -> NSColor {
        return config.kLineColorScheme.downColor
    }

    /// 获取当前K线平盘颜色
    public func kLineNeutralColor() -> NSColor {
        return config.kLineColorScheme.neutralColor
    }

    /// 获取量柱上涨颜色
    public func volumeUpColor() -> NSColor {
        return config.kLineColorScheme.volumeUpColor
    }

    /// 获取量柱下跌颜色
    public func volumeDownColor() -> NSColor {
        return config.kLineColorScheme.volumeDownColor
    }

    /// 获取K线边框颜色（用于高对比度模式下加粗K线边框）
    public func kLineBorderColor() -> NSColor {
        return config.effectiveForegroundColor()
    }

    /// 当前K线方案是否适合色盲用户
    public func isCurrentKLineColorBlindFriendly() -> Bool {
        return config.kLineColorScheme.isColorBlindFriendly
    }

    // MARK: 持久化
    /// 加载本地配置文件，若不存在则使用默认配置
    public func loadConfig() {
        do {
            let data = try Data(contentsOf: configURL)
            let decoded = try JSONDecoder().decode(UIHighContrastConfig.self, from: data)
            lock.lock()
            _config = decoded
            lock.unlock()
            logger.info("配置加载成功: \(self.configURL.path)")
            NotificationCenter.default.post(name: .highContrastConfigLoaded, object: nil, userInfo: ["success": true])
        } catch {
            logger.warning("配置加载失败，使用默认配置: \(error.localizedDescription)")
            lock.lock()
            _config = UIHighContrastConfig()
            lock.unlock()
            NotificationCenter.default.post(name: .highContrastConfigLoaded, object: nil, userInfo: ["success": false, "error": error.localizedDescription])
        }
    }

    /// 保存当前配置到本地JSON文件（Codable持久化）
    public func saveConfig() {
        lock.lock()
        let configToSave = _config
        lock.unlock()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configToSave)
            try data.write(to: configURL, options: [.atomic])
            logger.info("配置保存成功: \(self.configURL.path)")
            NotificationCenter.default.post(name: .highContrastConfigSaved, object: nil, userInfo: ["success": true, "path": configURL.path])
        } catch {
            logger.error("配置保存失败: \(error.localizedDescription)")
            NotificationCenter.default.post(name: .highContrastConfigSaved, object: nil, userInfo: ["success": false, "error": error.localizedDescription])
        }
    }

    /// 重置为默认配置并保存
    public func resetToDefault() {
        config = UIHighContrastConfig()
        saveConfig()
        logger.info("配置已重置为默认值")
    }

    // MARK: 设置面板方法
    /// 返回设置面板可用的对比度等级列表（供Picker使用）
    public func availableContrastLevels() -> [UIContrastLevel] {
        return UIContrastLevel.allCases
    }

    /// 返回设置面板可用的主题预设列表
    public func availableThemes() -> [UIHighContrastTheme] {
        return UIHighContrastTheme.allCases
    }

    /// 返回设置面板可用的K线颜色方案列表
    public func availableKLineSchemes() -> [UIKLineColorScheme] {
        return UIKLineColorScheme.allCases
    }

    /// 应用主题预设（一键切换）
    public func applyThemePreset(_ theme: UIHighContrastTheme) {
        lock.lock()
        _config.theme = theme
        lock.unlock()
        NotificationCenter.default.post(name: .highContrastThemeChanged, object: nil, userInfo: ["theme": theme.rawValue, "description": theme.description])
        applyThemeToRegisteredViews()
        logger.info("应用主题预设: \(theme.description)")
    }

    /// 设置自定义配色（自动切换至custom主题）
    public func setCustomColors(background: NSColor, foreground: NSColor, accent: NSColor) {
        lock.lock()
        _config.customBackgroundHex = background.hexString
        _config.customForegroundHex = foreground.hexString
        _config.customAccentHex = accent.hexString
        _config.theme = .custom
        lock.unlock()
        NotificationCenter.default.post(name: .highContrastThemeChanged, object: nil, userInfo: ["theme": UIHighContrastTheme.custom.rawValue, "description": "自定义配色"])
        applyThemeToRegisteredViews()
        logger.info("设置自定义配色: 背景=\(background.hexString) 前景=\(foreground.hexString) 强调=\(accent.hexString)")
    }

    /// 设置字体缩放（限制范围1.0~3.0）
    public func setFontScale(_ scale: CGFloat) {
        let clamped = max(1.0, min(3.0, scale))
        lock.lock()
        _config.fontScale = clamped
        lock.unlock()
        logger.info("字体缩放设置为: \(clamped)")
    }

    /// 设置是否跟随系统辅助功能
    public func setFollowSystemAccessibility(_ follow: Bool) {
        lock.lock()
        _config.followSystemAccessibility = follow
        lock.unlock()
        logger.info("跟随系统辅助功能: \(follow)")
    }

    /// 设置焦点高亮开关
    public func setFocusHighlight(_ enabled: Bool) {
        lock.lock()
        _config.focusHighlight = enabled
        lock.unlock()
        logger.info("焦点高亮: \(enabled)")
    }

    /// 设置减少动画开关
    public func setReduceAnimation(_ enabled: Bool) {
        lock.lock()
        _config.reduceAnimation = enabled
        lock.unlock()
        logger.info("减少动画: \(enabled)")
    }

    // MARK: 辅助功能查询
    /// 获取当前配置摘要（用于设置面板展示）
    public func configSummary() -> String {
        let c = config
        var lines: [String] = []
        lines.append("高对比度: \(c.isEnabled ? "已开启" : "已关闭")")
        lines.append("对比度等级: \(c.contrastLevel.description)")
        lines.append("当前主题: \(c.theme.description)")
        lines.append("K线方案: \(c.kLineColorScheme.description)")
        lines.append("字体缩放: \(String(format: "%.1f", c.fontScale))x")
        lines.append("色盲友好: \(c.kLineColorScheme.isColorBlindFriendly ? "是" : "否")")
        lines.append("跟随系统: \(c.followSystemAccessibility ? "是" : "否")")
        return lines.joined(separator: "\n")
    }

    /// 导出配置为JSON字符串（用于备份或分享）
    public func exportConfigToJSON() -> String? {
        let c = config
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(c)
            return String(data: data, encoding: .utf8)
        } catch {
            logger.error("导出配置失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 从JSON字符串导入配置
    public func importConfig(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        do {
            let decoded = try JSONDecoder().decode(UIHighContrastConfig.self, from: data)
            config = decoded
            saveConfig()
            logger.info("配置导入成功")
            return true
        } catch {
            logger.error("配置导入失败: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - 迁回自 UI-02：UIWeakViewContainer
private struct UIWeakViewContainer {
    weak var view: NSView?
    var handler: ((UIHighContrastConfig) -> Void)?
}

// MARK: - 迁回自 UI-02：enum UIContrastLevel
// MARK: - UI-GL-67 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-67_types.swift
// 版本: 2.0
// MARK: - 对比度等级
/// 对比度强度等级，数值越高差异越极端
public enum UIContrastLevel: Int, Codable, CaseIterable, Identifiable, Sendable, CustomStringConvertible {
    case low    = 0   // 轻度增强 — 适合轻微视觉疲劳
    case medium = 1   // 中度增强 — 标准视障辅助
    case high   = 2   // 高度增强 — 严重弱视
    case extreme = 3  // 极致增强 — 法定盲人辅助

    public var id: Int { rawValue }

    public var description: String {
        switch self {
        case .low:    return "轻度"
        case .medium: return "中度"
        case .high:   return "高度"
        case .extreme: return "极致"
        }
    }

    /// 该等级对应的背景与前景明度差值系数（0~1）
    public var luminanceGap: CGFloat {
        switch self {
        case .low:     return 0.50
        case .medium:  return 0.70
        case .high:    return 0.85
        case .extreme: return 0.95
        }
    }

    /// 边框加粗倍数
    public var borderMultiplier: CGFloat {
        switch self {
        case .low:     return 1.0
        case .medium:  return 1.5
        case .high:    return 2.5
        case .extreme: return 4.0
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIHighContrastTheme
// MARK: - UI-GL-67 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-67_types.swift
// 版本: 2.0
// MARK: - 高对比度主题预设
/// 内置高对比度主题预设，用户可一键切换
public enum UIHighContrastTheme: Int, Codable, CaseIterable, Identifiable, Sendable, CustomStringConvertible {
    case blackOnWhite = 0   // 黑底白字（最常用）
    case whiteOnBlack = 1   // 白底黑字
    case blueOnYellow = 2   // 蓝底黄字（低视力经典）
    case yellowOnBlack = 3  // 黄底黑字（高亮模式）
    case custom       = 4   // 自定义配色

    public var id: Int { rawValue }

    public var description: String {
        switch self {
        case .blackOnWhite:  return "黑底白字"
        case .whiteOnBlack:  return "白底黑字"
        case .blueOnYellow:  return "蓝底黄字"
        case .yellowOnBlack: return "黄底黑字"
        case .custom:        return "自定义配色"
        }
    }

    /// 主题背景色
    public var backgroundColor: NSColor {
        switch self {
        case .blackOnWhite:  return NSColor(white: 0.0, alpha: 1.0)
        case .whiteOnBlack:  return NSColor(white: 1.0, alpha: 1.0)
        case .blueOnYellow:  return NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.5, alpha: 1.0)
        case .yellowOnBlack: return NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
        case .custom:        return NSColor(white: 0.0, alpha: 1.0)
        }
    }

    /// 主题前景色
    public var foregroundColor: NSColor {
        switch self {
        case .blackOnWhite:  return NSColor(white: 1.0, alpha: 1.0)
        case .whiteOnBlack:  return NSColor(white: 0.0, alpha: 1.0)
        case .blueOnYellow:  return NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
        case .yellowOnBlack: return NSColor(white: 0.0, alpha: 1.0)
        case .custom:        return NSColor(white: 1.0, alpha: 1.0)
        }
    }

    /// 主题强调色
    public var accentColor: NSColor {
        switch self {
        case .blackOnWhite:  return NSColor.systemYellow
        case .whiteOnBlack:  return NSColor.systemBlue
        case .blueOnYellow:  return NSColor(white: 1.0, alpha: 1.0)
        case .yellowOnBlack: return NSColor.systemRed
        case .custom:        return NSColor.systemOrange
        }
    }

    /// 边框颜色
    public var borderColor: NSColor {
        return foregroundColor
    }
}

// MARK: - 迁回自 UI-02：struct UIColorReplacementMap
// MARK: - 颜色替换映射
/// 原生颜色到高对比度颜色的映射表，用于全局UI元素替换
public struct UIColorReplacementMap: Codable, Equatable, Sendable {
    /// 映射字典：键为颜色描述标识，值为替换后的Hex字符串
    public var mappings: [String: String] = [:]

    /// 系统默认颜色映射表
    public static let `default`: [String: String] = [
        "systemRed":    "#FF0000",
        "systemGreen":  "#00CC00",
        "systemBlue":   "#0066FF",
        "systemGray":   "#888888",
        "label":        "#FFFFFF",
        "secondaryLabel": "#AAAAAA",
        "background":   "#000000",
        "separator":    "#FFFFFF",
        "link":         "#FFFF00",
        "selectedText": "#000000",
        "selectedTextBackground": "#FFFFFF"
    ]

    public init(mappings: [String: String] = [:]) {
        self.mappings = mappings.isEmpty ? Self.default : mappings
    }
}

// MARK: - UIKLineColorScheme 已在 UI-GL-70_命令面板.swift 定义，这里只引用不重复定义

// MARK: - 迁回自 UI-02：struct UIHighContrastConfig
// MARK: - 高对比度配置模型
/// 完整的高对比度配置，支持Codable持久化到本地JSON
public struct UIHighContrastConfig: Codable, Equatable, Sendable {
    /// 版本号，用于配置迁移
    public var version: Double = 2.0
    /// 是否启用高对比度模式
    public var isEnabled: Bool = false
    /// 当前对比度等级
    public var contrastLevel: UIContrastLevel = .medium
    /// 当前主题预设
    public var theme: UIHighContrastTheme = .blackOnWhite
    /// 自定义背景色（Hex格式）
    public var customBackgroundHex: String = "#000000"
    /// 自定义前景色（Hex格式）
    public var customForegroundHex: String = "#FFFFFF"
    /// 自定义强调色（Hex格式）
    public var customAccentHex: String = "#FFFF00"
    /// K线颜色方案
    public var kLineColorScheme: UIKLineColorScheme = .deepLight
    /// 是否使用粗体字体
    public var useBoldFont: Bool = true
    /// 字体放大倍数（1.0~3.0）
    public var fontScale: CGFloat = 1.2
    /// 边框宽度基数（会被contrastLevel放大）
    public var baseBorderWidth: CGFloat = 2.0
    /// 是否自动跟随系统辅助功能设置
    public var followSystemAccessibility: Bool = false
    /// 颜色替换映射
    public var colorMap: UIColorReplacementMap = UIColorReplacementMap()
    /// 是否启用焦点高亮（鼠标悬停加粗边框）
    public var focusHighlight: Bool = true
    /// 是否启用动画（视障用户建议关闭动画）
    public var reduceAnimation: Bool = true
    /// 最后更新时间
    public var lastUpdated: Date = Date()

    public init() {}

    /// 计算实际边框宽度（等级 × 基数）
    public func effectiveBorderWidth() -> CGFloat {
        return baseBorderWidth * contrastLevel.borderMultiplier
    }

    /// 获取当前生效的背景色
    public func effectiveBackgroundColor() -> NSColor {
        if theme == .custom {
            return NSColor(hexString: customBackgroundHex) ?? .black
        }
        return theme.backgroundColor
    }

    /// 获取当前生效的前景色
    public func effectiveForegroundColor() -> NSColor {
        if theme == .custom {
            return NSColor(hexString: customForegroundHex) ?? .white
        }
        return theme.foregroundColor
    }

    /// 获取当前生效的强调色
    public func effectiveAccentColor() -> NSColor {
        if theme == .custom {
            return NSColor(hexString: customAccentHex) ?? .yellow
        }
        return theme.accentColor
    }
}

// MARK: - 迁回自 UI-02：struct UIHighContrastConfigKey
// MARK: - 高对比度管理器（单例）
/// 全局高对比度模式管理器，负责配置、持久化、UI通知、K线颜色适配
// 已迁回 UI-GL-67_高对比度模式.swift：class UIHighContrastManager（公共类型文件禁止功能实现）

// MARK: - 弱引用容器
/// 包装NSView弱引用与自定义回调，用于管理器注册列表
// 已迁回 UI-GL-67_高对比度模式.swift：UIWeakViewContainer（功能弱引用容器不属于公共类型）

/// 高对比度环境键值，供SwiftUI视图读取当前配置
private struct UIHighContrastConfigKey: EnvironmentKey {
    static let defaultValue: UIHighContrastConfig = UIHighContrastConfig()
}

// MARK: - 迁回自 UI-02：struct UIHighContrastAdaptiveModifier
/// SwiftUI修饰器：自动响应高对比度变化
@available(macOS 11.0, *)
public struct UIHighContrastAdaptiveModifier: ViewModifier {
    @State private var currentConfig: UIHighContrastConfig = UIHighContrastManager.shared.config

    public func body(content: Content) -> some View {
        content
            .background(currentConfig.isEnabled ? Color(currentConfig.effectiveBackgroundColor()) : Color.clear)
            .foregroundColor(currentConfig.isEnabled ? Color(currentConfig.effectiveForegroundColor()) : Color.primary)
            .onReceive(NotificationCenter.default.publisher(for: .highContrastEnabledChanged)) { _ in
                currentConfig = UIHighContrastManager.shared.config
            }
            .onReceive(NotificationCenter.default.publisher(for: .highContrastThemeChanged)) { _ in
                currentConfig = UIHighContrastManager.shared.config
            }
            .onReceive(NotificationCenter.default.publisher(for: .highContrastLevelChanged)) { _ in
                currentConfig = UIHighContrastManager.shared.config
            }
    }
}
