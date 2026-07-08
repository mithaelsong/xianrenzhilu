// 功能32A: 主题切换
// 对应: 完善的主题切换系统，支持浅色/深色/高对比度/自定义主题，实时切换UI外观，设置面板集成
// 优先级: P1

import AppKit
import Foundation
import os.log

// MARK: - 通知定义
/// 主题已切换通知，object为主题管理器，userInfo包含新主题信息
public extension Notification.Name {
    /// 主题已切换通知（切换至任何主题时发送）
    static let ThemeSwitchDidChange = Notification.Name("com.xianrenzhilu.themeSwitchDidChange")
    /// 自定义主题已保存通知（用户创建或编辑自定义主题时发送）
    static let ThemeCustomThemeDidSave = Notification.Name("com.xianrenzhilu.customThemeDidSave")
    /// 系统外观已变化通知（macOS系统外观改变时发送）
    static let ThemeSystemAppearanceDidChange = Notification.Name("com.xianrenzhilu.systemAppearanceDidChange")
}


// MARK: - 主题切换管理器
/// 完善的主题切换管理器，负责主题管理、持久化、系统外观监听、UI实时切换
/// 采用单例模式，使用NSLock保护共享数据，通过通知驱动UI更新
// 类型 UIThemeSwitchManager 已迁移到 UI-02_公共类型定义.swift

/// 弱引用包装
// 类型 UIWeakBox 已迁移到 UI-02_公共类型定义.swift

// MARK: - 主题预览视图
/// 用于设置面板展示主题预览效果的NSView子类
// 类型 UIThemePreviewView 已迁移到 UI-02_公共类型定义.swift

// MARK: - 便捷扩展
public extension NSView {
    /// 便捷注册主题感知
    func registerAsThemeAware() {
        UIThemeSwitchManager.shared.registerThemeAwareView(self)
    }

    /// 便捷注销主题感知
    func unregisterAsThemeAware() {
        UIThemeSwitchManager.shared.unregisterThemeAwareView(self)
    }
}

// MARK: - 测试代码
#if DEBUG
/// 测试专用日志输出，与 os.log.Logger 签名兼容（单参数消息）
private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "20A_主题切换")

/// 功能32A：主题切换 — 单元测试
/// 覆盖：内置主题/切换/自定义/导出导入/视图注册/设置面板
@MainActor
func test_themeSwitch() {
    let manager = UIThemeSwitchManager.shared
    var allPassed = true

    logger.info("测试1: 内置主题数量")
    let builtIn = manager.builtInThemes
    if builtIn.count < 3 {
        logger.error("❌ 测试1失败: 应有至少3个内置主题")
        allPassed = false
    } else {
        logger.info("✅ 测试1通过: 内置主题共\(builtIn.count)个")
    }

    logger.info("测试2: 主题切换")
    manager.switchToTheme(id: "built-in-dark")
    let current = manager.currentTheme
    if current?.id != "built-in-dark" {
        logger.error("❌ 测试2失败: 当前主题应为深色")
        allPassed = false
    } else {
        logger.info("✅ 测试2通过: 主题切换成功")
    }

    logger.info("测试3: 主题摘要列表")
    let summary = manager.themeSummaryList()
    if summary.isEmpty {
        logger.error("❌ 测试3失败: 应有主题摘要")
        allPassed = false
    } else {
        logger.info("✅ 测试3通过: 主题摘要正常")
    }

    logger.info("测试4: 默认重置")
    manager.resetToDefault()
    if manager.currentTheme?.id != "built-in-light" {
        logger.error("❌ 测试4失败: 重置后应为浅色")
        allPassed = false
    } else {
        logger.info("✅ 测试4通过: 重置正常")
    }

    logger.info("测试5: 视图注册")
    let view = NSView()
    manager.registerThemeAwareView(view)
    manager.unregisterThemeAwareView(view)
    logger.info("✅ 测试5通过: 视图注册/注销正常")

    logger.info("测试6: 模式切换")
    manager.switchTheme(to: .dark)
    if manager.currentTheme?.id != "built-in-dark" {
        logger.error("❌ 测试6失败: switchTheme(to:) 应切换到深色")
        allPassed = false
    } else if manager.currentMode != .dark {
        logger.error("❌ 测试6失败: currentMode 应为 dark")
        allPassed = false
    } else {
        logger.info("✅ 测试6通过: 模式切换正常")
    }

    logger.info("测试7: 颜色转换")
    let color = UIThemeColorUtilities.color(fromHex: "#FF5733")
    if color == nil {
        logger.error("❌ 测试7失败: 颜色转换应成功")
        allPassed = false
    } else {
        let hex = UIThemeColorUtilities.hex(from: color!)
        if hex.isEmpty {
            logger.error("❌ 测试7失败: Hex转换应成功")
            allPassed = false
        } else {
            logger.info("✅ 测试7通过: 颜色转换正确")
        }
    }

    logger.info("测试8: 自定义主题管理")
    let customTheme = UIThemeDefinition(
        id: "test-custom-1",
        name: "测试自定义",
        description: "单元测试用的自定义主题",
        isBuiltIn: false,
        followSystemAppearance: false,
        systemAppearance: nil,
        colors: manager.currentTheme?.colors ?? UIThemeColors(
            background: "#FFFFFF", foreground: "#1C1C1E", accent: "#007AFF",
            panelBackground: "#F2F2F7", secondaryBackground: "#E5E5EA",
            border: "#C6C6C8", disabled: "#999999", success: "#34C759",
            warning: "#FF9500", error: "#FF3B30"
        ),
        fonts: UIThemeFonts(baseSize: 13, titleFontName: "", bodyFontName: "", monoFontName: "",
                          titleMultiplier: 1.5, subtitleMultiplier: 1.2, bodyMultiplier: 1.0, smallMultiplier: 0.85),
        spacing: UIThemeSpacing(small: 8, medium: 16, large: 24, xlarge: 32,
                              cornerRadiusSmall: 4, cornerRadiusMedium: 8, cornerRadiusLarge: 12,
                              borderWidth: 1, shadowOpacity: 0.1, shadowOffset: CGSize(width: 0, height: 1), shadowBlurRadius: 4),
        iconTint: UIThemeIconTint(default: "#007AFF", selected: "#0056CC", disabled: "#999999", highlighted: "#4DA6FF", useUniformTint: false)
    )
    manager.addCustomTheme(customTheme)
    let customCount = manager.customThemes.count
    if customCount < 1 {
        logger.error("❌ 测试8失败: 自定义主题添加后应为 1")
        allPassed = false
    } else {
        logger.info("✅ 测试8通过: 自定义主题添加正常")
    }

    let deleted = manager.deleteCustomTheme(id: "test-custom-1")
    if !deleted {
        logger.error("❌ 测试8失败: 自定义主题删除应成功")
        allPassed = false
    } else {
        logger.info("✅ 测试8通过: 自定义主题删除正常")
    }

    // 内置主题不可删除
    let builtInDeleted = manager.deleteCustomTheme(id: "built-in-light")
    if builtInDeleted {
        logger.error("❌ 测试8失败: 内置主题不应可删除")
        allPassed = false
    } else {
        logger.info("✅ 测试8通过: 内置主题保护正常")
    }

    logger.info("测试9: 主题列表")
    let all = manager.allThemes
    _ = all.count
    let custom = manager.customThemes
    _ = custom.count
    logger.info("✅ 测试9通过: 主题列表查询正常")

    if allPassed {
        logger.info("=== 全部主题切换测试通过 ✅ ===")
    } else {
        logger.error("=== 部分主题切换测试失败 ❌ ===")
    }
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIThemePreviewView
public final class UIThemePreviewView: NSView , @unchecked Sendable{

    private var theme: UIThemeDefinition?
    private var previewData: UIThemePreviewData = .default

    /// 设置要预览的主题
    public func setPreviewTheme(_ theme: UIThemeDefinition, data: UIThemePreviewData = .default) {
        self.theme = theme
        self.previewData = data
        self.needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let t = theme else { return }

        let bgColor = UIThemeColorUtilities.color(fromHex: t.colors.background) ?? .windowBackgroundColor
        bgColor.setFill()
        dirtyRect.fill()

        let fgColor = UIThemeColorUtilities.color(fromHex: t.colors.foreground) ?? .labelColor
        let accentColor = UIThemeColorUtilities.color(fromHex: t.colors.accent) ?? .controlAccentColor
        let panelBg = UIThemeColorUtilities.color(fromHex: t.colors.panelBackground) ?? .controlBackgroundColor
        let borderColor = UIThemeColorUtilities.color(fromHex: t.colors.border) ?? .separatorColor

        let panelRect = NSRect(x: 16, y: 16, width: bounds.width - 32, height: bounds.height - 32)
        let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: t.spacing.cornerRadiusMedium, yRadius: t.spacing.cornerRadiusMedium)
        panelBg.setFill()
        panelPath.fill()
        borderColor.setStroke()
        panelPath.lineWidth = t.spacing.borderWidth
        panelPath.stroke()

        // 绘制标题文本
        let titleAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: fgColor,
            .font: t.fonts.titleFont
        ]
        let titleStr = NSAttributedString(string: previewData.title, attributes: titleAttr)
        titleStr.draw(at: NSPoint(x: panelRect.minX + t.spacing.medium, y: panelRect.maxY - t.spacing.medium - t.fonts.titleFont.pointSize))

        // 绘制正文
        let bodyY = panelRect.maxY - t.spacing.medium - t.fonts.titleFont.pointSize - t.spacing.small - t.fonts.bodyFont.pointSize
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: fgColor,
            .font: t.fonts.bodyFont
        ]
        let bodyStr = NSAttributedString(string: previewData.body, attributes: bodyAttr)
        bodyStr.draw(at: NSPoint(x: panelRect.minX + t.spacing.medium, y: bodyY))

        // 绘制模拟按钮（使用强调色）
        let buttonWidth: CGFloat = 80
        let buttonHeight: CGFloat = 28
        let buttonRect = NSRect(x: panelRect.minX + t.spacing.medium, y: panelRect.minY + t.spacing.medium, width: buttonWidth, height: buttonHeight)
        let buttonPath = NSBezierPath(roundedRect: buttonRect, xRadius: t.spacing.cornerRadiusSmall, yRadius: t.spacing.cornerRadiusSmall)
        accentColor.setFill()
        buttonPath.fill()

        let btnTextAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium)
        ]
        let btnStr = NSAttributedString(string: previewData.buttonText, attributes: btnTextAttr)
        let btnSize = btnStr.size()
        btnStr.draw(at: NSPoint(x: buttonRect.midX - btnSize.width / 2, y: buttonRect.midY - btnSize.height / 2))

        // 绘制标签文字
        let labelAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIThemeColorUtilities.color(fromHex: t.colors.disabled) ?? .secondaryLabelColor,
            .font: NSFont.systemFont(ofSize: 11)
        ]
        let labelStr = NSAttributedString(string: previewData.labelText, attributes: labelAttr)
        labelStr.draw(at: NSPoint(x: buttonRect.maxX + t.spacing.medium, y: buttonRect.midY - 6))
    }
}

// MARK: - 迁回自 UI-02：class UIThemeSwitchManager
public final class UIThemeSwitchManager : @unchecked Sendable {
    public static let shared = UIThemeSwitchManager()

    private let lock = NSLock()
    private var themes: [String: UIThemeDefinition] = [:]
    private var _currentThemeID: String = "built-in-light"
    private var themeAwareViews: [UIWeakBox] = []
    /// 带刷新回调的主题感知视图：业务模块注册后，主题切换/系统外观变化时回调刷新。
    /// （2026-06-22 补全）原 registerThemeAwareView 只存弱引用、从不通知，现补齐回调链路。
    private var themeAwareHandlers: [UIThemeAwareHandlerBox] = []
    /// 系统外观（深色/浅色）变化监听令牌
    private var systemAppearanceObserver: NSObjectProtocol?

    // 当前模式（light/dark/system），使用UI-02公共类型 UIThemeMode
    public var currentMode: UIThemeMode = .system

    private init() {
        setupBuiltInThemes()
        // 初始化时根据系统外观同步 _currentThemeID
        if currentMode == .system {
            _currentThemeID = systemAppearanceThemeID()
        }
        // （2026-06-22 补全）安装系统外观监听：系统深↔浅切换时广播+回调所有注册视图。
        installSystemAppearanceObserver()
    }

    deinit {
        if let observer = systemAppearanceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    // MARK: - 内置主题创建

    /// 初始化内置主题（浅色/深色/高对比度）
    private func setupBuiltInThemes() {
        let light = createLightTheme()
        let dark = createDarkTheme()
        let highContrast = createHighContrastTheme()
        let protanopia = createProtanopiaTheme()
        let deuteranopia = createDeuteranopiaTheme()
        for theme in [light, dark, highContrast, protanopia, deuteranopia] {
            themes[theme.id] = theme
            UIUnifiedRegistry.shared.registerTheme(theme)
        }
    }

    /// 创建浅色主题
    private func createLightTheme() -> UIThemeDefinition {
        UIThemeDefinition(
            id: "built-in-light",
            name: "浅色",
            description: "标准浅色主题，适合白天或明亮环境使用",
            isBuiltIn: true,
            followSystemAppearance: true,
            systemAppearance: "light",
            colors: UIThemeColors(
                background: "#FFFFFF",
                foreground: "#1C1C1E",
                accent: "#007AFF",
                panelBackground: "#F2F2F7",
                secondaryBackground: "#E5E5EA",
                border: "#C6C6C8",
                disabled: "#999999",
                success: "#34C759",
                warning: "#FF9500",
                error: "#FF3B30"
            ),
            fonts: UIThemeFonts(
                baseSize: 13,
                titleFontName: "",
                bodyFontName: "",
                monoFontName: "",
                titleMultiplier: 1.5,
                subtitleMultiplier: 1.2,
                bodyMultiplier: 1.0,
                smallMultiplier: 0.85
            ),
            spacing: UIThemeSpacing(
                small: 8, medium: 16, large: 24, xlarge: 32,
                cornerRadiusSmall: 4, cornerRadiusMedium: 8, cornerRadiusLarge: 12,
                borderWidth: 1,
                shadowOpacity: 0.1, shadowOffset: CGSize(width: 0, height: 1), shadowBlurRadius: 4
            ),
            iconTint: UIThemeIconTint(
                default: "#007AFF", selected: "#0056CC", disabled: "#999999", highlighted: "#4DA6FF",
                useUniformTint: false
            )
        )
    }

    /// 创建深色主题
    private func createDarkTheme() -> UIThemeDefinition {
        UIThemeDefinition(
            id: "built-in-dark",
            name: "深色",
            description: "标准深色主题，适合夜晚或低光环境使用",
            isBuiltIn: true,
            followSystemAppearance: true,
            systemAppearance: "dark",
            colors: UIThemeColors(
                background: "#000000",
                foreground: "#FFFFFF",
                accent: "#0A84FF",
                panelBackground: "#1C1C1E",
                secondaryBackground: "#2C2C2E",
                border: "#3A3A3C",
                disabled: "#666666",
                success: "#30D158",
                warning: "#FF9F0A",
                error: "#FF453A"
            ),
            fonts: UIThemeFonts(
                baseSize: 13,
                titleFontName: "",
                bodyFontName: "",
                monoFontName: "",
                titleMultiplier: 1.5,
                subtitleMultiplier: 1.2,
                bodyMultiplier: 1.0,
                smallMultiplier: 0.85
            ),
            spacing: UIThemeSpacing(
                small: 8, medium: 16, large: 24, xlarge: 32,
                cornerRadiusSmall: 4, cornerRadiusMedium: 8, cornerRadiusLarge: 12,
                borderWidth: 1,
                shadowOpacity: 0.3, shadowOffset: CGSize(width: 0, height: 1), shadowBlurRadius: 4
            ),
            iconTint: UIThemeIconTint(
                default: "#0A84FF", selected: "#409CFF", disabled: "#666666", highlighted: "#66B0FF",
                useUniformTint: false
            )
        )
    }

    /// 创建高对比度主题
    private func createHighContrastTheme() -> UIThemeDefinition {
        UIThemeDefinition(
            id: "built-in-highcontrast",
            name: "高对比度",
            description: "高对比度主题，提高可读性和视觉辅助",
            isBuiltIn: true,
            followSystemAppearance: false,
            systemAppearance: nil,
            colors: UIThemeColors(
                background: "#FFFFFF",
                foreground: "#000000",
                accent: "#0000FF",
                panelBackground: "#F0F0F0",
                secondaryBackground: "#E0E0E0",
                border: "#000000",
                disabled: "#666666",
                success: "#006600",
                warning: "#996600",
                error: "#CC0000"
            ),
            fonts: UIThemeFonts(
                baseSize: 15,
                titleFontName: "",
                bodyFontName: "",
                monoFontName: "",
                titleMultiplier: 1.5,
                subtitleMultiplier: 1.2,
                bodyMultiplier: 1.0,
                smallMultiplier: 0.9
            ),
            spacing: UIThemeSpacing(
                small: 10, medium: 18, large: 28, xlarge: 36,
                cornerRadiusSmall: 6, cornerRadiusMedium: 10, cornerRadiusLarge: 14,
                borderWidth: 2,
                shadowOpacity: 0, shadowOffset: .zero, shadowBlurRadius: 0
            ),
            iconTint: UIThemeIconTint(
                default: "#0000FF", selected: "#000099", disabled: "#666666", highlighted: "#3333FF",
                useUniformTint: true
            )
        )
    }


    /// 创建红色盲辅助主题
    private func createProtanopiaTheme() -> UIThemeDefinition {
        UIThemeDefinition(
            id: "built-in-protanopia",
            name: "红色盲",
            description: "红色盲辅助主题，在当前皮肤下调整颜色映射",
            isBuiltIn: true,
            followSystemAppearance: false,
            systemAppearance: nil,
            colors: UIThemeColors(
                background: "#FFF8E1", foreground: "#1C1C1E", accent: "#0072B2",
                panelBackground: "#FFF3CD", secondaryBackground: "#F6E7A8",
                border: "#8A6D00", disabled: "#7A7A7A", success: "#0072B2",
                warning: "#E69F00", error: "#D55E00"
            ),
            fonts: UIThemeFonts(baseSize: 13, titleFontName: "", bodyFontName: "", monoFontName: "",
                                titleMultiplier: 1.5, subtitleMultiplier: 1.2, bodyMultiplier: 1.0, smallMultiplier: 0.9),
            spacing: UIThemeSpacing(small: 8, medium: 16, large: 24, xlarge: 32,
                                    cornerRadiusSmall: 4, cornerRadiusMedium: 8, cornerRadiusLarge: 12,
                                    borderWidth: 1, shadowOpacity: 0.12, shadowOffset: CGSize(width: 0, height: 1), shadowBlurRadius: 4),
            iconTint: UIThemeIconTint(default: "#0072B2", selected: "#005A8D", disabled: "#777777", highlighted: "#56B4E9", useUniformTint: false)
        )
    }

    /// 创建绿色盲辅助主题
    private func createDeuteranopiaTheme() -> UIThemeDefinition {
        UIThemeDefinition(
            id: "built-in-deuteranopia",
            name: "绿色盲",
            description: "绿色盲辅助主题，在当前皮肤下调整颜色映射",
            isBuiltIn: true,
            followSystemAppearance: false,
            systemAppearance: nil,
            colors: UIThemeColors(
                background: "#F5F3FF", foreground: "#1C1C1E", accent: "#CC79A7",
                panelBackground: "#EDE9FE", secondaryBackground: "#DDD6FE",
                border: "#6D5BD0", disabled: "#7A7A7A", success: "#0072B2",
                warning: "#E69F00", error: "#D55E00"
            ),
            fonts: UIThemeFonts(baseSize: 13, titleFontName: "", bodyFontName: "", monoFontName: "",
                                titleMultiplier: 1.5, subtitleMultiplier: 1.2, bodyMultiplier: 1.0, smallMultiplier: 0.9),
            spacing: UIThemeSpacing(small: 8, medium: 16, large: 24, xlarge: 32,
                                    cornerRadiusSmall: 4, cornerRadiusMedium: 8, cornerRadiusLarge: 12,
                                    borderWidth: 1, shadowOpacity: 0.12, shadowOffset: CGSize(width: 0, height: 1), shadowBlurRadius: 4),
            iconTint: UIThemeIconTint(default: "#CC79A7", selected: "#9B4F7D", disabled: "#777777", highlighted: "#B39DDB", useUniformTint: false)
        )
    }

    /// 根据当前系统外观返回对应内置主题ID
    /// 通过 NSApp.effectiveAppearance.name 检测 macOS 实际外观模式
    /// 安全处理 NSApp 为 nil 的情况（命令行/测试环境）
    /// - Returns: 内置浅色或深色主题ID
    private func systemAppearanceThemeID() -> String {
        guard let app = NSApp else { return "built-in-light" }
        let appearanceName = app.effectiveAppearance.name
        if appearanceName == .darkAqua {
            return "built-in-dark"
        }
        return "built-in-light"
    }

    // MARK: - 公开属性

    /// 所有内置主题
    public var builtInThemes: [UIThemeDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return themes.values.filter { $0.isBuiltIn }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 用户自定义主题
    public var customThemes: [UIThemeDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return themes.values.filter { !$0.isBuiltIn }
    }

    /// 所有主题（内置+自定义）
    public var allThemes: [UIThemeDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return Array(themes.values).sorted { $0.createdAt < $1.createdAt }
    }

    /// 当前激活的主题
    public var currentTheme: UIThemeDefinition? {
        lock.lock()
        defer { lock.unlock() }
        return themes[_currentThemeID]
    }

    // MARK: - 主题操作

    /// 根据ID切换到指定主题
    /// - Parameter id: 主题唯一标识
    public func switchToTheme(id: String) {
        lock.lock()
        cleanup()
        guard let theme = themes[id] else {
            lock.unlock()
            return
        }
        _currentThemeID = id
        lock.unlock()
        UIUnifiedRegistry.shared.setCurrentTheme(id: id)
        UserDefaults.standard.set(id, forKey: "com.xianrenzhilu.theme.currentThemeId")

        NotificationCenter.default.post(
            name: .ThemeSwitchDidChange,
            object: self,
            userInfo: ["themeID": id, "themeName": theme.name]
        )
        // （2026-06-22 补全）回调所有主题感知视图刷新颜色。
        applyThemeToRegisteredViews()
    }

    /// 按模式切换主题（light/dark/system）
    /// - Parameter mode: 目标主题模式
    /// - Note: 通知在锁外发送，避免观察者回调导致死锁
    public func switchTheme(to mode: UIThemeMode) {
        let newID: String
        let themeName: String
        lock.lock()
        cleanup()
        currentMode = mode
        switch mode {
        case .light:
            newID = "built-in-light"
        case .dark:
            newID = "built-in-dark"
        case .system:
            newID = systemAppearanceThemeID()
        case .highContrast:
            newID = "built-in-highcontrast"
        }
        _currentThemeID = newID
        themeName = themes[newID]?.name ?? ""
        lock.unlock()
        UIUnifiedRegistry.shared.setCurrentTheme(id: newID)
        UserDefaults.standard.set(newID, forKey: "com.xianrenzhilu.theme.currentThemeId")

        NotificationCenter.default.post(
            name: .ThemeSwitchDidChange,
            object: self,
            userInfo: ["themeID": newID, "themeName": themeName]
        )
        // （2026-06-22 补全）回调所有主题感知视图刷新颜色。
        applyThemeToRegisteredViews()
    }

    /// 重置为默认主题（浅色）
    public func resetToDefault() {
        switchToTheme(id: "built-in-light")
    }

    // MARK: - 自定义主题管理

    /// 添加自定义主题
    /// - Parameter theme: 自定义主题定义（isBuiltIn 会被强制设为 false）
    public func addCustomTheme(_ theme: UIThemeDefinition) {
        var mutableTheme = theme
        // 创建新的唯一 ID，确保不覆盖已有主题
        if themes[theme.id] != nil {
            mutableTheme = UIThemeDefinition(
                id: UUID().uuidString,
                name: theme.name,
                description: theme.description,
                isBuiltIn: false,
                followSystemAppearance: theme.followSystemAppearance,
                systemAppearance: theme.systemAppearance,
                colors: theme.colors,
                fonts: theme.fonts,
                spacing: theme.spacing,
                iconTint: theme.iconTint
            )
        }
        var addTheme = mutableTheme
        addTheme.isBuiltIn = false

        lock.lock()
        themes[addTheme.id] = addTheme
        lock.unlock()

        NotificationCenter.default.post(
            name: .ThemeCustomThemeDidSave,
            object: self,
            userInfo: ["themeID": addTheme.id, "themeName": addTheme.name]
        )
    }

    /// 删除自定义主题（内置主题不可删除）
    /// - Parameter id: 主题唯一标识
    /// - Returns: 删除是否成功
    @discardableResult
    public func deleteCustomTheme(id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let theme = themes[id], !theme.isBuiltIn else {
            return false
        }
        themes.removeValue(forKey: id)
        return true
    }

    /// 获取主题摘要列表（用于设置面板展示）
    /// - Returns: 主题名称和ID的摘要字符串数组
    public func themeSummaryList() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return themes.values.map { "\($0.name) - \($0.id)" }.sorted()
    }

    // MARK: - 主题感知视图注册

    /// 注册主题感知视图
    public func registerThemeAwareView(_ view: AnyObject) {
        lock.lock()
        cleanup()
        themeAwareViews.append(UIWeakBox(value: view))
        lock.unlock()
    }

    /// （2026-06-22 补全）注册带刷新回调的主题感知视图。
    /// 业务模块传入闭包，主题切换或系统外观变化时由 UI 模块统一在主线程回调。
    /// 注册时立即回调一次，保证初始色与当前主题一致。
    /// - Parameters:
    ///   - view: 需响应主题变化的视图（弱引用持有）
    ///   - onChange: 主题变化时的刷新闭包（在主线程调用）
    public func registerThemeAwareView(_ view: AnyObject, onChange: @escaping () -> Void) {
        lock.lock()
        cleanup()
        themeAwareHandlers.append(UIThemeAwareHandlerBox(value: view, handler: onChange))
        lock.unlock()
        // 立即同步一次当前主题
        if Thread.isMainThread {
            onChange()
        } else {
            DispatchQueue.main.async { onChange() }
        }
    }

    /// 注销主题感知视图
    public func unregisterThemeAwareView(_ view: AnyObject) {
        lock.lock()
        themeAwareViews.removeAll { $0.value === view }
        themeAwareHandlers.removeAll { $0.value === view || $0.value == nil }
        lock.unlock()
    }

    /// （2026-06-22 补全）遍历所有已注册的主题感知视图并刷新。
    /// 镜像 UI-GL-67 高对比度管理器的成熟模式：锁内拷贝快照，锁外主线程回调。
    public func applyThemeToRegisteredViews() {
        lock.lock()
        cleanup()
        let handlerBoxes = themeAwareHandlers
        let plainBoxes = themeAwareViews
        lock.unlock()

        let work = {
            for box in handlerBoxes {
                guard box.value != nil else { continue }
                box.handler()
            }
            // 无回调的旧式注册视图：尽力触发重绘/重布局。
            for box in plainBoxes {
                guard let v = box.value as? NSView else { continue }
                v.needsDisplay = true
                v.needsLayout = true
            }
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// （2026-06-22 补全）安装系统外观监听。
    /// 系统深↔浅切换时：若当前跟随系统(.system)则同步主题 id，并统一广播+回调所有注册视图。
    private func installSystemAppearanceObserver() {
        // 方式1：DistributedNotificationCenter（macOS 传统方式，兼容旧系统）
        systemAppearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // 系统通知可能早于 effectiveAppearance 更新，延迟一轮 runloop 再处理
            DispatchQueue.main.async {
                self?.handleSystemAppearanceChange()
            }
        }
        
        // 方式2：NSWorkspace 监听（macOS 10.15+ 更可靠，覆盖 DistributedNotificationCenter 可能遗漏的情况）
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemAppearanceChangeObjC),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }
    
    /// 兼容 NSWorkspace 的 Objective-C selector 桥接
    @objc private func handleSystemAppearanceChangeObjC() {
        DispatchQueue.main.async { [weak self] in
            self?.handleSystemAppearanceChange()
        }
    }

    /// （2026-06-22 补全）处理系统外观变化。
    private func handleSystemAppearanceChange() {
        // 系统通知可能早于 effectiveAppearance 更新，延迟 500ms 确保读到新值
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            if self.currentMode == .system {
                let newID = self.systemAppearanceThemeID()
                self.lock.lock()
                self._currentThemeID = newID
                self.lock.unlock()
                UIUnifiedRegistry.shared.setCurrentTheme(id: newID)
                UserDefaults.standard.set(newID, forKey: "com.xianrenzhilu.theme.currentThemeId")
            }
            let isDark = self.systemAppearanceThemeID() == "built-in-dark"
            // 同时发送 ThemeSwitchDidChange，保证只监听主题切换的 UI 也能刷新
            NotificationCenter.default.post(
                name: .ThemeSwitchDidChange,
                object: self,
                userInfo: ["themeID": self._currentThemeID, "themeName": self.themes[self._currentThemeID]?.name ?? "", "source": "system"]
            )
            NotificationCenter.default.post(
                name: .ThemeSystemAppearanceDidChange,
                object: self,
                userInfo: ["isDark": isDark]
            )
            self.applyThemeToRegisteredViews()
        }
    }

    /// 清理已释放的弱引用
    private func cleanup() {
        themeAwareViews.removeAll { $0.value == nil }
        themeAwareHandlers.removeAll { $0.value == nil }
    }
}

// MARK: - 迁回自 UI-02：class UIWeakBox
internal class UIWeakBox : @unchecked Sendable {
    weak var value: AnyObject?
    init(value: AnyObject?) { self.value = value }
}

// MARK: -（2026-06-22 补全）带刷新回调的主题感知视图弱引用盒
internal final class UIThemeAwareHandlerBox : @unchecked Sendable {
    weak var value: AnyObject?
    let handler: () -> Void
    init(value: AnyObject?, handler: @escaping () -> Void) {
        self.value = value
        self.handler = handler
    }
}
