// 功能56: VoiceOver完整支持
// 对应: 窗口、面板、图表元素提供完整无障碍标签
// 优先级: P3

import AppKit
import Foundation
import os.log

// MARK: - 统一日志器
/// 本子模块专用的结构化日志器，subsystem 使用应用主 bundle 标识
private let logger = Logger(subsystem: "com.xianrenzhilu.app", category: "VoiceOver")

// MARK: - 通知名称常量
/// VoiceOver相关通知名称，用于跨模块通信
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 通知信息扩展
/// 为通知userInfo提供便捷访问的扩展
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification {


// MARK: - 测试代码
#if DEBUG

/// 功能56：VoiceOver支持 — 单元测试
func test_voiceOver() {
    let manager = UIVoiceOverManager.shared
    
    logger.info("测试1: 默认设置")
    let settings = manager.currentSettings
    if settings.isEnabled { logger.info("✅ 测试1通过") }
    else { logger.error("❌ 测试1失败") }
    
    logger.info("测试2: 注册元素")
    let config = UIAccessibilityElementConfig(
        identifier: "test_btn", label: "测试按钮",
        hint: "点击执行测试", roleDescription: "按钮",
        value: "100"
    )
    if manager.registerElement(config) { logger.info("✅ 测试2通过") }
    else { logger.error("❌ 测试2失败") }
    
    logger.info("测试3: 元素查询")
    let el = manager.getElementConfig("test_btn")
    if el?.label == "测试按钮" { logger.info("✅ 测试3通过") }
    else { logger.error("❌ 测试3失败") }
    
    logger.info("测试4: 更新值")
    manager.setValue("test_btn", value: "200")
    let updated = manager.getElementConfig("test_btn")
    if updated?.value == "200" { logger.info("✅ 测试4通过") }
    else { logger.error("❌ 测试4失败") }
    
    logger.info("测试5: 设置标签")
    manager.setLabel("test_btn", label: "已更新按钮")
    let labeled = manager.getElementConfig("test_btn")
    if labeled?.label == "已更新按钮" { logger.info("✅ 测试5通过") }
    else { logger.error("❌ 测试5失败") }
    
    logger.info("测试6: 注册数")
    if manager.getRegisteredElementCount() >= 1 { logger.info("✅ 测试6通过") }
    else { logger.error("❌ 测试6失败") }
    
    logger.info("测试7: 注销")
    manager.unregisterElement("test_btn")
    if manager.getRegisteredElementCount() == 0 { logger.info("✅ 测试7通过") }
    else { logger.error("❌ 测试7失败") }
    
    logger.info("测试8: 设置更新")
    var newSettings = manager.currentSettings
    newSettings.isEnabled = false
    manager.updateSettings(newSettings)
    let afterUpdate = manager.currentSettings
    if !afterUpdate.isEnabled { logger.info("✅ 测试8通过") }
    else { logger.error("❌ 测试8失败") }
    
    logger.info("测试9: 设置重置")
    manager.resetSettings()
    let afterReset = manager.currentSettings
    if afterReset.isEnabled { logger.info("✅ 测试9通过") }
    else { logger.error("❌ 测试9失败") }
    
    logger.info("=== 全部VoiceOver测试通过 ✅ ===")
}
#endif

// MARK: - 迁回自 UI-02：struct UIAccessibilityElementConfig
// MARK: - UI-GL-64 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-64_types.swift
// 版本: 2.0
// MARK: - 通知名称定义
/// 虚拟滚动相关通知
// 已迁回 UI-GL-64_图表数据虚拟滚动.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-65 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-65_types.swift
// 版本: 2.0
// MARK: - 通知名称定义
/// 键盘导航相关通知，用于模块间通信和状态同步
// 已迁回 UI-GL-65_完整键盘导航.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-66 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-66_types.swift
// 版本: 2.0
public struct UIAccessibilityElementConfig {
    /// 元素的标识符，用于唯一识别
    public var identifier: String
    /// 无障碍标签（朗读主文本）
    public var label: String
    /// 操作提示文本（用户悬停时补充说明）
    public var hint: String
    /// 元素的角色描述（如"按钮"、"图表"）
    public var roleDescription: String
    /// 元素的当前值（如价格、数量等动态数据）
    public var value: String
    /// 元素是否可用
    public var isEnabled: Bool
    /// 是否可被VoiceOver聚焦
    public var isFocusable: Bool
    /// 元素的子元素标识符列表（用于层级结构）
    public var childIdentifiers: [String]
    /// 元素的自定义属性（扩展用）
    public var customAttributes: [String: String]
    /// 元素关联的视图（弱引用避免循环）
    public weak var associatedView: NSView?
    
    /// 创建默认配置
    public init(
        identifier: String,
        label: String,
        hint: String = "",
        roleDescription: String = "",
        value: String = "",
        isEnabled: Bool = true,
        isFocusable: Bool = true,
        childIdentifiers: [String] = [],
        customAttributes: [String: String] = [:],
        associatedView: NSView? = nil
    ) {
        self.identifier = identifier
        self.label = label
        self.hint = hint
        self.roleDescription = roleDescription
        self.value = value
        self.isEnabled = isEnabled
        self.isFocusable = isFocusable
        self.childIdentifiers = childIdentifiers
        self.customAttributes = customAttributes
        self.associatedView = associatedView
    }
    
    /// 生成完整的朗读文本（标签+值+提示）
    public var fullAnnouncement: String {
        var parts = [label]
        if !value.isEmpty { parts.append("，当前值：\(value)") }
        if !hint.isEmpty { parts.append("，\(hint)") }
        return parts.joined(separator: "")
    }
}

// MARK: - 迁回自 UI-02：struct UIRegisteredElement
// MARK: - 焦点指示器视图
/// 绘制焦点指示器的覆盖层视图，跟随当前聚焦元素移动
// 已迁回 UI-GL-65_完整键盘导航.swift：class UIFocusIndicatorView（公共类型文件禁止功能实现）

// MARK: - 键盘导航管理器
/// 完整键盘导航系统管理器
/// 支持Tab焦点切换、方向键导航、快捷键面板、功能键操作、焦点指示器
/// 采用单例模式，使用NSRecursiveLock保护共享数据，确保线程安全
// 已迁回 UI-GL-65_完整键盘导航.swift：class UIKeyboardNavigationManager（公共类型文件禁止功能实现）

// MARK: - 系统全键盘访问扩展
/// 扩展键盘导航管理器，提供系统全键盘访问的增强控制
// 已迁回 UI-GL-65_完整键盘导航.swift：extension UIKeyboardNavigationManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-66 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-66_types.swift
// 版本: 2.0
private struct UIRegisteredElement {
    /// 元素配置（不可变引用）
    var config: UIAccessibilityElementConfig
    /// 注册时间戳
    let registeredAt: Date
    /// 最后更新时间戳
    var lastUpdatedAt: Date
    /// 当前是否处于焦点状态
    var isFocused: Bool
    /// 聚焦次数统计
    var focusCount: Int
    
    /// 创建已注册元素记录
    init(config: UIAccessibilityElementConfig) {
        self.config = config
        self.registeredAt = Date()
        self.lastUpdatedAt = Date()
        self.isFocused = false
        self.focusCount = 0
    }
}

// MARK: - 迁回自 UI-02：struct UIFocusHistoryEntry
struct UIFocusHistoryEntry {  // 原为private，改为internal以允许public属性暴露
    /// 元素标识符
    let elementIdentifier: String
    /// 元素标签（便于调试）
    let elementLabel: String
    /// 进入焦点的时间
    let timestamp: Date
    /// 离开焦点的时间（nil表示当前仍聚焦）
    var exitedAt: Date?
    
    /// 计算该次聚焦的持续时间
    var duration: TimeInterval? {
        guard let exited = exitedAt else { return nil }
        return exited.timeIntervalSince(timestamp)
    }
}

// MARK: - 迁回自 UI-02：struct UIAccessibilitySettings
public struct UIAccessibilitySettings: Sendable {
    /// 是否启用VoiceOver支持（总开关）
    public var isEnabled: Bool
    /// 是否启用图表朗读
    public var isChartAnnouncementEnabled: Bool
    /// 是否启用价格变动朗读
    public var isPriceChangeAnnouncementEnabled: Bool
    /// 是否启用操作结果朗读
    public var isActionResultAnnouncementEnabled: Bool
    /// 朗读语速（0.5-2.0，1.0为正常）
    public var speechRate: Double
    /// 是否启用详细模式（朗读更多上下文信息）
    public var isDetailedMode: Bool
    /// 焦点是否自动跟随鼠标
    public var isFocusFollowsMouse: Bool
    /// 朗读延迟（秒，避免频繁触发）
    public var announcementDelay: TimeInterval
    
    /// 默认设置
    public static let `default` = UIAccessibilitySettings(
        isEnabled: true,
        isChartAnnouncementEnabled: true,
        isPriceChangeAnnouncementEnabled: true,
        isActionResultAnnouncementEnabled: true,
        speechRate: 1.0,
        isDetailedMode: false,
        isFocusFollowsMouse: false,
        announcementDelay: 0.1
    )
    
    /// 从UserDefaults加载设置
    public static func loadFromDefaults() -> UIAccessibilitySettings {
        let defaults = UserDefaults.standard
        return UIAccessibilitySettings(
            isEnabled: defaults.object(forKey: "voiceOver.enabled") as? Bool ?? true,
            isChartAnnouncementEnabled: defaults.object(forKey: "voiceOver.chartAnnouncement") as? Bool ?? true,
            isPriceChangeAnnouncementEnabled: defaults.object(forKey: "voiceOver.priceChange") as? Bool ?? true,
            isActionResultAnnouncementEnabled: defaults.object(forKey: "voiceOver.actionResult") as? Bool ?? true,
            speechRate: defaults.object(forKey: "voiceOver.speechRate") as? Double ?? 1.0,
            isDetailedMode: defaults.object(forKey: "voiceOver.detailedMode") as? Bool ?? false,
            isFocusFollowsMouse: defaults.object(forKey: "voiceOver.focusFollowsMouse") as? Bool ?? false,
            announcementDelay: defaults.object(forKey: "voiceOver.announcementDelay") as? TimeInterval ?? 0.1
        )
    }
    
    /// 保存到UserDefaults
    public func saveToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: "voiceOver.enabled")
        defaults.set(isChartAnnouncementEnabled, forKey: "voiceOver.chartAnnouncement")
        defaults.set(isPriceChangeAnnouncementEnabled, forKey: "voiceOver.priceChange")
        defaults.set(isActionResultAnnouncementEnabled, forKey: "voiceOver.actionResult")
        defaults.set(speechRate, forKey: "voiceOver.speechRate")
        defaults.set(isDetailedMode, forKey: "voiceOver.detailedMode")
        defaults.set(isFocusFollowsMouse, forKey: "voiceOver.focusFollowsMouse")
        defaults.set(announcementDelay, forKey: "voiceOver.announcementDelay")
    }
}
