// 功能12A: 主题/皮肤系统
// 对应: 支持亮色/暗色/跟随系统，可自定义主题（浅灰、深色、高对比度）
// 优先级: P1

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "12A_主题皮肤系统")

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能12A：主题皮肤系统 — 单元测试
/// 覆盖：主题模式枚举、主题配置Codable、管理器初始状态
func test_themeManager() {
    print("\n🧪 测试1: 主题模式枚举完整")
    let modes = UIThemeMode.allCases
    guard modes.count == 4 else {
        fatalError("❌ 测试1失败: 应有4种主题模式")
    }
    guard modes.contains(.system) && modes.contains(.light) && modes.contains(.dark) && modes.contains(.highContrast) else {
        fatalError("❌ 测试1失败: 缺少主题模式")
    }
    print("✅ 测试1通过: 全部4种主题模式可用")
    
    print("\n🧪 测试2: 主题配置Codable")
    let config = UIThemeConfiguration(name: "测试主题", mode: .dark)
    guard let data = try? JSONEncoder().encode(config) else {
        fatalError("❌ 测试2失败: 编码失败")
    }
    guard let decoded = try? JSONDecoder().decode(UIThemeConfiguration.self, from: data) else {
        fatalError("❌ 测试2失败: 解码失败")
    }
    guard decoded.name == "测试主题" else {
        fatalError("❌ 测试2失败: name不匹配")
    }
    guard decoded.mode == .dark else {
        fatalError("❌ 测试2失败: mode不匹配")
    }
    print("✅ 测试2通过: UIThemeConfiguration Codable编解码正确")
    
    print("\n🧪 测试3: 主题配置默认值")
    let defaultConfig = UIThemeConfiguration(name: "默认", mode: .system)
    guard defaultConfig.name == "默认" else {
        fatalError("❌ 测试3失败: 默认名称不匹配")
    }
    guard defaultConfig.glassEffectMaterial == "windowBackground" else {
        fatalError("❌ 测试3失败: 默认毛玻璃材质应为windowBackground")
    }
    print("✅ 测试3通过: 主题配置默认值正确")
    
    print("\n🧪 测试4: UIThemeMode外观映射")
    let lightAppearance = UIThemeMode.light.appearance
    guard lightAppearance?.name == .aqua else {
        fatalError("❌ 测试4失败: light模式appearance应为aqua")
    }
    let darkAppearance = UIThemeMode.dark.appearance
    guard darkAppearance?.name == .darkAqua else {
        fatalError("❌ 测试4失败: dark模式appearance应为darkAqua")
    }
    guard UIThemeMode.system.appearance == nil else {
        fatalError("❌ 测试4失败: system模式appearance应为nil")
    }
    print("✅ 测试4通过: 主题模式外观映射正确")
    
    print("\n🧪 测试5: 管理器初始状态")
    let manager = UIThemeManager.shared
    guard manager.currentMode == .system else {
        fatalError("❌ 测试5失败: 初始主题模式应为.system")
    }
    print("✅ 测试5通过: 管理器初始状态正确")
    
    print("\n=== 全部主题测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIThemeManager
public final class UIThemeManager : @unchecked Sendable {
    
    public static let shared = UIThemeManager()
    
    /// 线程安全锁
    private let lock = NSRecursiveLock()
    
    // MARK: - 属性
    
    /// 当前主题模式
    public private(set) var currentMode: UIThemeMode = .system
    
    /// 当前主题配置
    public private(set) var currentTheme: UIThemeConfiguration
    
    /// 是否在暗色模式下
    public var isDarkMode: Bool {
        lock.lock()
        let result: Bool
        switch currentMode {
        case .dark:
            result = true
        case .light:
            result = false
        case .system:
            result = effectiveAppearanceIsDark()
        case .highContrast:
            result = effectiveAppearanceIsDark()
        }
        lock.unlock()
        return result
    }
    
    /// 主题变化通知
    public static let themeDidChangeNotification = Notification.Name("com.xianrenzhilu.themeDidChange")
    
    // MARK: - 私有
    
    private var observers: [NSObjectProtocol] = []
    
    private init() {
        self.currentTheme = UIThemeConfiguration(name: "默认", mode: .system)
        
        // 监听系统主题变化
        let observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.currentMode == .system else { return }
            self.notifyThemeChange()
        }
        lock.lock()
        observers.append(observer)
        lock.unlock()
    }
    
    deinit {
        lock.lock()
        let obs = observers
        lock.unlock()
        obs.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    // MARK: - 公开方法
    
    /// 切换主题模式
    public func setTheme(_ mode: UIThemeMode) {
        lock.lock()
        currentMode = mode
        applyUIAppearance()
        lock.unlock()
        notifyThemeChange()
        logger.info("已切换到: \(mode.rawValue)")
    }
    
    /// 应用自定义主题配置
    public func applyCustomTheme(_ config: UIThemeConfiguration) {
        lock.lock()
        currentTheme = config
        currentMode = config.mode
        applyUIAppearance()
        lock.unlock()
        notifyThemeChange()
        logger.info("已应用自定义主题: \(config.name)")
    }
    
    /// 注册主题感知视图
    /// - Parameter view: 需要响应主题变化的视图
    public func registerThemeAware(_ view: NSView) {
        lock.lock()
        let appearance = currentMode.appearance
        lock.unlock()
        view.appearance = appearance
    }
    
    // MARK: - 内部方法
    
    /// 在锁内调用：设置全局appearance（调用者已持锁）
    private func applyUIAppearance() {
        if let appearance = currentMode.appearance {
            NSApp.appearance = appearance
        } else {
            NSApp.appearance = nil  // 跟随系统
        }
    }
    
    /// 在锁外调用：发送主题变更通知
    private func notifyThemeChange() {
        NotificationCenter.default.post(
            name: UIThemeManager.themeDidChangeNotification,
            object: nil,
            userInfo: ["isDarkMode": isDarkMode]
        )
    }
    
    private func effectiveAppearanceIsDark() -> Bool {
        let appearance = NSApp.effectiveAppearance
        let name = appearance.name
        return name == .darkAqua || name == .vibrantDark || name == .accessibilityHighContrastDarkAqua
    }
}

// MARK: - 迁回自 UI-02：struct UIThemeConfiguration
// MARK: - 窗口透明度记录
/// 单个窗口的透明度状态记录
// 已迁回 UI-GL-13_透明度控制.swift：class UIWindowOpacityRecord（公共类型文件禁止功能实现）

// MARK: - 透明度动画器
/// 透明度专用动画器，继承 NSAnimation 实现平滑过渡
// 已迁回 UI-GL-13_透明度控制.swift：class UIOpacityAnimation（公共类型文件禁止功能实现）

// MARK: - 窗口透明度管理器
/// 全局单例：统一管理窗口透明度与不透光属性
/// 功能：
///   - 透明度实时调整（0.0 ~ 1.0）
///   - 不透光属性控制（isOpaque）
///   - 动画过渡（淡入/淡出/渐变）
///   - 快捷键绑定（支持 Ctrl+滚轮等自定义组合）
///   - 闪动提醒（视觉提示）
///   - 线程安全（NSRecursiveLock）
/// 与 WindowRegistry 集成，通过窗口ID管理透明度
// 已迁回 UI-GL-13_透明度控制.swift：class UIWindowOpacityManager（公共类型文件禁止功能实现）

// MARK: - 动画委托
/// 透明度动画完成委托
// 已迁回 UI-GL-13_透明度控制.swift：class UIOpacityAnimationDelegate（公共类型文件禁止功能实现）


// MARK: - UI-GL-14 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-14_types.swift
// 版本: 2.0
// MARK: - 主题配置
/// 完整的主题配置
public struct UIThemeConfiguration: Codable {
    /// 主题名称
    public var name: String
    /// 主题模式
    public var mode: UIThemeMode
    /// 背景色（16进制）
    public var backgroundColor: String
    /// 前景色（16进制）
    public var foregroundColor: String
    /// 强调色（16进制）
    public var accentColor: String
    /// 面板背景色
    public var panelBackgroundColor: String
    /// 毛玻璃材质类型
    public var glassEffectMaterial: String
    
    public init(name: String, mode: UIThemeMode) {
        self.name = name
        self.mode = mode
        self.backgroundColor = ""
        self.foregroundColor = ""
        self.accentColor = ""
        self.panelBackgroundColor = ""
        self.glassEffectMaterial = "windowBackground"
    }
}
