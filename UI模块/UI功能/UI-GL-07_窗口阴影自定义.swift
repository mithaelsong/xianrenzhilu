import AppKit
import os

// MARK: - NSWindow 便捷扩展
/// 为 NSWindow 提供便捷扩展，可直接调用阴影管理方法
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension NSWindow {

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能08A：窗口阴影自定义 — 单元测试
/// 覆盖：预设配置完整性、配置属性读写、边界情况
func test_windowShadow() {
    print("\n🧪 测试1: 预设样式完整性")
    let manager = UIWindowShadowManager.shared
    for style in UIShadowStyle.allCases {
        guard let config = manager.presetConfig(for: style) else {
            fatalError("❌ 测试1失败: 预设样式\(style) 配置为nil")
        }
        guard config.radius >= 0 else {
            fatalError("❌ 测试1失败: 预设样式\(style) radius 应为非负数，实际为\(config.radius)")
        }
        guard config.opacity >= 0 && config.opacity <= 1 else {
            fatalError("❌ 测试1失败: 预设样式\(style) opacity 应在0~1之间")
        }
    }
    print("✅ 测试1通过: 全部\(UIShadowStyle.allCases.count)种预设样式配置完整")

    print("\n🧪 测试2: 阴影配置默认值")
    let normalConfig = manager.presetConfig(for: .normal)!
    guard normalConfig.radius == 12 else {
        fatalError("❌ 测试2失败: normal预设radius应为12，实际为\(normalConfig.radius)")
    }
    guard abs(normalConfig.opacity - 0.25) < 0.01 else {
        fatalError("❌ 测试2失败: normal预设opacity应为0.25，实际为\(normalConfig.opacity)")
    }
    print("✅ 测试2通过: normal预设配置默认值正确")

    print("\n🧪 测试3: 管理者初次无受管窗口")
    let managed = manager.managedWindows()
    guard managed.isEmpty else {
        fatalError("❌ 测试3失败: 初次初始化应无受管窗口")
    }
    print("✅ 测试3通过: 初始受管窗口数为0")

    print("\n🧪 测试4: 不存在的窗口配置返回nil")
    let nonExistWindow = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
    let config = manager.currentConfig(for: nonExistWindow)
    guard config == nil else {
        fatalError("❌ 测试4失败: 未设置阴影的窗口配置应为nil")
    }
    print("✅ 测试4通过: 未设置阴影的窗口返回nil")

    print("\n🧪 测试5: 并发读取不崩溃")
    let group = DispatchGroup()
    for _ in 0..<10 {
        DispatchQueue.global().async(group: group) {
            _ = manager.presetConfig(for: .normal)
            _ = manager.managedWindows()
        }
    }
    _ = group.wait(timeout: .now() + 5.0)
    print("✅ 测试5通过: 10次并发读取未崩溃")

    print("\n🧪 测试6: UIShadowStyle描述")
    for style in UIShadowStyle.allCases {
        guard !style.description.isEmpty else {
            fatalError("❌ 测试6失败: UIShadowStyle\(style) 描述为空")
        }
        guard !style.rawValue.isEmpty else {
            fatalError("❌ 测试6失败: UIShadowStyle\(style) rawValue为空")
        }
    }
    print("✅ 测试6通过: 全部样式描述/原始值有效")

    print("\n=== 全部窗口阴影测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWindowShadowManager
public final class UIWindowShadowManager : @unchecked Sendable {
    deinit {
        logger.info("UIWindowShadowManager 已释放")
    }

    
    // MARK: 单例
    /// 全局唯一实例
    public static let shared = UIWindowShadowManager()
    
    // MARK: 私有初始化
    private init() {
        logger.info("☕ UIWindowShadowManager 单例初始化完成")
    }
    
    // MARK: 线程锁
    /// 线程锁：保证多线程环境下数据安全
    private let lock = NSRecursiveLock()
    
    // MARK: 日志记录器
    /// 结构化日志记录器，用于调试和审计
    private let logger = Logger(
        subsystem: "com.xianrenzhilu.ui.shadow",
        category: "UIWindowShadowManager"
    )
    
    // MARK: 窗口配置缓存
    /// 窗口到阴影配置的映射表
    /// 键为窗口引用，值为当前阴影配置
    private var windowConfigs: [NSWindow: UIShadowConfig] = [:]
    
    // MARK: 预设阴影配置表
    /// 五种预设样式的默认配置
    /// 所有参数经过视觉调优，可直接使用
    private let presets: [UIShadowStyle: UIShadowConfig] = [
        .normal: UIShadowConfig(
            offset: CGSize(width: 0, height: -4),
            radius: 12,
            opacity: 0.25,
            color: NSColor.black
        ),
        .soft: UIShadowConfig(
            offset: CGSize(width: 0, height: -6),
            radius: 24,
            opacity: 0.15,
            color: NSColor.black
        ),
        .strong: UIShadowConfig(
            offset: CGSize(width: 0, height: -8),
            radius: 20,
            opacity: 0.45,
            color: NSColor.black
        ),
        .dark: UIShadowConfig(
            offset: CGSize(width: 0, height: -6),
            radius: 18,
            opacity: 0.65,
            color: NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        ),
        .glow: UIShadowConfig(
            offset: CGSize(width: 0, height: 0),
            radius: 30,
            opacity: 0.5,
            color: NSColor.systemBlue
        )
    ]
    
    // MARK: - 核心方法：应用预设阴影
    /// 为指定窗口应用预设阴影样式
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - style: 预设样式（normal/soft/strong/dark/glow）
    public func applyShadow(to window: NSWindow, style: UIShadowStyle) {
        lock.lock()
        defer { lock.unlock() }
        
        logger.info("🎨 正在为窗口 \(window.title) 应用「\(style)」阴影样式")
        
        guard let config = presets[style] else {
            logger.error("❌ 未找到「\(style)」对应的预设配置")
            return
        }
        
        // 缓存配置
        windowConfigs[window] = config
        
        // 关闭系统默认阴影，避免双重阴影叠加
        window.hasShadow = false
        
        // 确保窗口内容视图已启用图层
        guard let contentView = window.contentView else {
            logger.warning("⚠️ 窗口 \(window.title) 无 contentView，跳过阴影应用")
            return
        }
        
        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = false  // 允许阴影渲染到视图边界外
        
        // 创建并配置 NSShadow 对象
        let shadow = NSShadow()
        shadow.shadowOffset = config.offset
        shadow.shadowBlurRadius = config.radius
        shadow.shadowColor = config.color.withAlphaComponent(config.opacity)
        
        // 将阴影绑定到内容视图
        contentView.shadow = shadow
        
        // 触发重绘以确保阴影立即生效
        contentView.needsDisplay = true
        contentView.displayIfNeeded()
        
        logger.info("✅ 已为窗口「\(window.title)」应用「\(style)」阴影样式")
    }
    
    // MARK: - 设置阴影颜色
    /// 设置指定窗口的阴影颜色
    /// - Parameters:
    ///   - color: 新颜色
    ///   - window: 目标窗口
    public func setShadowColor(_ color: NSColor, for window: NSWindow) {
        lock.lock()
        defer { lock.unlock() }
        
        logger.info("🖌️ 设置窗口「\(window.title)」阴影颜色为 \(color)")
        
        // 获取现有配置，若无则使用 normal 预设作为基准
        var config = windowConfigs[window] ?? presets[.normal]!
        config.color = color
        windowConfigs[window] = config
        
        // 重新应用更新后的配置
        reapplyShadow(to: window, config: config)
        
        logger.info("✅ 已更新窗口「\(window.title)」阴影颜色")
    }
    
    // MARK: - 设置阴影偏移
    /// 设置指定窗口的阴影偏移量
    /// - Parameters:
    ///   - offset: 新偏移量（正值向右/下，负值向左/上）
    ///   - window: 目标窗口
    public func setShadowOffset(_ offset: CGSize, for window: NSWindow) {
        lock.lock()
        defer { lock.unlock() }
        
        logger.info("📐 设置窗口「\(window.title)」阴影偏移为 (\(offset.width), \(offset.height))")
        
        var config = windowConfigs[window] ?? presets[.normal]!
        config.offset = offset
        windowConfigs[window] = config
        
        reapplyShadow(to: window, config: config)
        
        logger.info("✅ 已更新窗口「\(window.title)」阴影偏移")
    }
    
    // MARK: - 设置阴影半径
    /// 设置指定窗口的阴影模糊半径
    /// - Parameters:
    ///   - radius: 新半径（值越大阴影越柔和，范围建议 0~50）
    ///   - window: 目标窗口
    public func setShadowRadius(_ radius: CGFloat, for window: NSWindow) {
        lock.lock()
        defer { lock.unlock() }
        
        logger.info("🔘 设置窗口「\(window.title)」阴影半径为 \(radius)")
        
        var config = windowConfigs[window] ?? presets[.normal]!
        config.radius = max(0, radius)  // 防止负值
        windowConfigs[window] = config
        
        reapplyShadow(to: window, config: config)
        
        logger.info("✅ 已更新窗口「\(window.title)」阴影半径")
    }
    
    // MARK: - 设置阴影透明度
    /// 设置指定窗口的阴影不透明度
    /// - Parameters:
    ///   - opacity: 新透明度（0~1，0为完全透明，1为完全不透明）
    ///   - window: 目标窗口
    public func setShadowOpacity(_ opacity: CGFloat, for window: NSWindow) {
        lock.lock()
        defer { lock.unlock() }
        
        let clampedOpacity = max(0.0, min(1.0, opacity))
        logger.info("🔅 设置窗口「\(window.title)」阴影透明度为 \(clampedOpacity)")
        
        var config = windowConfigs[window] ?? presets[.normal]!
        config.opacity = clampedOpacity
        windowConfigs[window] = config
        
        reapplyShadow(to: window, config: config)
        
        logger.info("✅ 已更新窗口「\(window.title)」阴影透明度")
    }
    
    // MARK: - 重置为系统默认
    /// 将窗口阴影恢复为 macOS 系统默认样式
    /// 移除所有自定义阴影配置
    /// - Parameter window: 目标窗口
    public func resetToDefault(for window: NSWindow) {
        lock.lock()
        defer { lock.unlock() }
        
        logger.info("↩️ 正在重置窗口「\(window.title)」阴影为系统默认")
        
        // 移除缓存的配置
        windowConfigs.removeValue(forKey: window)
        
        // 恢复系统默认阴影开关
        window.hasShadow = true
        
        // 移除自定义 NSShadow
        if let contentView = window.contentView {
            contentView.shadow = nil
            contentView.needsDisplay = true
            contentView.displayIfNeeded()
        }
        
        logger.info("✅ 窗口「\(window.title)」阴影已恢复为系统默认")
    }
    
    // MARK: - 获取当前配置
    /// 获取指定窗口当前的阴影配置（只读）
    /// - Parameter window: 目标窗口
    /// - Returns: 当前阴影配置，若未设置则返回 nil
    public func currentConfig(for window: NSWindow) -> UIShadowConfig? {
        lock.lock()
        defer { lock.unlock() }
        
        return windowConfigs[window]
    }
    
    // MARK: - 获取预设配置
    /// 获取指定预设样式的默认配置（只读）
    /// - Parameter style: 预设样式
    /// - Returns: 对应的默认配置
    public func presetConfig(for style: UIShadowStyle) -> UIShadowConfig? {
        lock.lock()
        defer { lock.unlock() }
        
        return presets[style]
    }
    
    // MARK: - 列出所有受管窗口
    /// 返回当前所有已应用自定义阴影的窗口列表
    /// - Returns: 窗口数组（按标题排序）
    public func managedWindows() -> [NSWindow] {
        lock.lock()
        defer { lock.unlock() }
        
        return windowConfigs.keys.sorted { $0.title < $1.title }
    }
    
    // MARK: - 私有辅助方法：重新应用阴影
    /// 使用给定的配置重新为窗口应用阴影
    /// 此方法必须在 lock 保护下调用
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - config: 阴影配置
    private func reapplyShadow(to window: NSWindow, config: UIShadowConfig) {
        // 确保系统阴影已关闭
        window.hasShadow = false
        
        guard let contentView = window.contentView else {
            logger.warning("⚠️ 窗口 \(window.title) 无 contentView，重新应用失败")
            return
        }
        
        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = false
        
        let shadow = NSShadow()
        shadow.shadowOffset = config.offset
        shadow.shadowBlurRadius = config.radius
        shadow.shadowColor = config.color.withAlphaComponent(config.opacity)
        
        contentView.shadow = shadow
        contentView.needsDisplay = true
        contentView.displayIfNeeded()
    }
}

// MARK: - 迁回自 UI-02：enum UIShadowStyle
// MARK: - 基础容器视图
/// 实现了 UIContainerViewProtocol 的基础 NSView
/// 提供毛玻璃背景和主题自适应
// 已迁回 UI-GL-06_视图容器协议.swift：class UIContainerView（公共类型文件禁止功能实现）

// MARK: - 容器工厂
/// 创建和管理容器视图实例
/// 线程安全：使用 NSRecursiveLock 保护 registeredTypes 字典
// 已迁回 UI-GL-06_视图容器协议.swift：class UIContainerFactory（公共类型文件禁止功能实现）


// MARK: - UI-GL-07 合并类型
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-07_types.swift
// 版本: 2.0
// 跳过重复类型: 无

// MARK: - 阴影预设样式枚举
/// 窗口阴影预设样式
/// 提供五种常用的阴影效果，涵盖日常使用和特殊场景
public enum UIShadowStyle: String, CaseIterable, CustomStringConvertible {
    case normal  = "标准"
    case soft    = "柔和"
    case strong  = "强烈"
    case dark    = "深色"
    case glow    = "发光"
    
    public var description: String { rawValue }
}

// MARK: - 迁回自 UI-02：struct UIShadowConfig
// MARK: - 阴影配置数据模型
/// 阴影配置结构体
/// 存储单个窗口阴影的所有参数
public struct UIShadowConfig {
    /// 阴影偏移量：控制阴影相对窗口的位置
    var offset: CGSize
    /// 阴影模糊半径：控制阴影边缘的柔和程度
    var radius: CGFloat
    /// 阴影不透明度：0~1，控制阴影深浅
    var opacity: CGFloat
    /// 阴影颜色：支持任意NSColor
    var color: NSColor
}
