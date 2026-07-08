// 功能7: 窗口玻璃效果
// 对应: 全局管理窗口玻璃效果，支持NSMaterial全部材质类型、混合模式、着色、强度、圆角
// 优先级: P1
// 版本: 2.0
// 类型定义已迁移至 UI-GL-05_types.swift

import Foundation
import os.log
import AppKit
import os

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "07A_窗口玻璃效果")


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIGlassEffectRecord
public class UIGlassEffectRecord : @unchecked Sendable {
    /// 窗口唯一标识
    public let windowID: String
    /// 窗口弱引用（防止循环引用）
    public weak var window: NSWindow?
    /// 视觉特效视图实例
    public var visualEffectView: NSVisualEffectView?
    /// 着色覆盖层（用于 Tinting）
    public var tintOverlayView: NSView?
    /// 当前配置
    public var configuration: UIGlassEffectConfiguration
    /// 创建时间
    public let createdAt: Date

    public init(windowID: String, window: NSWindow?, configuration: UIGlassEffectConfiguration) {
        self.windowID = windowID
        self.window = window
        self.configuration = configuration
        self.createdAt = Date()
    }
}

// MARK: - 迁回自 UI-02：class UIGlassEffectManager
public final class UIGlassEffectManager : @unchecked Sendable {
    deinit {
        logger.info("UIGlassEffectManager 已释放")
    }

    public static let shared = UIGlassEffectManager()
    /// 窗口ID -> 玻璃效果记录
    private var records: [String: UIGlassEffectRecord] = [:]
    /// 线程安全锁
    private let lock = NSRecursiveLock()

    private init() {}

    // MARK: - 核心 API：应用材质

    /// 对指定窗口应用玻璃材质效果
    /// - Parameters:
    ///   - windowID: 窗口唯一标识
    ///   - material: 材质类型
    ///   - configuration: 可选的完整配置（nil 时使用默认配置，仅覆盖材质）
    /// - Returns: 是否成功应用
    @discardableResult
    public func applyMaterial(to windowID: String, material: UIGlassMaterialType, configuration: UIGlassEffectConfiguration? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let window = UIUnifiedRegistry.shared.getWindowRecord(windowID: windowID)?.window else {
            logger.info("应用失败：窗口ID '\(windowID)' 不存在于注册表")
            return false
        }

        // 先移除旧效果（避免重复叠加）
        removeEffectUnsafe(windowID: windowID)

        var config = configuration ?? UIGlassEffectConfiguration()
        config.material = material

        let visualView = buildVisualEffectView(configuration: config)
        let record = UIGlassEffectRecord(windowID: windowID, window: window, configuration: config)
        record.visualEffectView = visualView

        // 安装到窗口内容视图最底层
        if let contentView = window.contentView {
            visualView.frame = contentView.bounds
            visualView.autoresizingMask = [.width, .height]
            if let firstSubview = contentView.subviews.first {
                contentView.addSubview(visualView, positioned: NSWindow.OrderingMode.below, relativeTo: firstSubview)
            } else {
                contentView.addSubview(visualView)
            }

            // 添加着色层（作为视觉特效视图的子视图，确保在特效之上、内容之下）
            if config.isTintingEnabled {
                addTintOverlay(to: visualView, color: config.tintColor, record: record)
            }
        }

        records[windowID] = record
        logger.info("已为窗口 '\(windowID)' 应用材质：\(material.rawValue)，混合模式：\(config.blendingMode.rawValue)，状态：\(config.state.rawValue)")
        return true
    }

    // MARK: - 核心 API：设置混合模式

    /// 设置指定窗口的混合模式
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - mode: 混合模式（窗口后方 / 窗口内部）
    /// - Returns: 是否成功设置
    @discardableResult
    public func setBlendingMode(for windowID: String, mode: UIGlassBlendingMode) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let record = records[windowID], let visualView = record.visualEffectView else {
            logger.info("设置混合模式失败：窗口ID '\(windowID)' 未应用玻璃效果")
            return false
        }

        visualView.blendingMode = mode.nsBlendingMode
        record.configuration.blendingMode = mode

        logger.info("窗口 '\(windowID)' 混合模式已更新为：\(mode.rawValue)")
        return true
    }

    // MARK: - 核心 API：设置效果状态

    /// 设置指定窗口的效果状态
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - state: 效果状态（跟随活跃 / 始终活跃 / 始终非活跃）
    /// - Returns: 是否成功设置
    @discardableResult
    public func setState(for windowID: String, state: UIGlassState) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let record = records[windowID], let visualView = record.visualEffectView else {
            logger.info("设置状态失败：窗口ID '\(windowID)' 未应用玻璃效果")
            return false
        }

        visualView.state = state.nsState
        record.configuration.state = state

        logger.info("窗口 '\(windowID)' 效果状态已更新为：\(state.rawValue)")
        return true
    }

    // MARK: - 核心 API：设置圆角

    /// 设置指定窗口玻璃效果的圆角半径
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - radius: 圆角半径（像素）
    /// - Returns: 是否成功设置
    @discardableResult
    public func setCornerRadius(for windowID: String, radius: CGFloat) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let record = records[windowID], let visualView = record.visualEffectView else {
            logger.info("设置圆角失败：窗口ID '\(windowID)' 未应用玻璃效果")
            return false
        }

        visualView.wantsLayer = true
        visualView.layer?.cornerRadius = radius
        visualView.layer?.masksToBounds = true
        record.configuration.cornerRadius = radius

        // 着色层也需要同步圆角
        if let tintView = record.tintOverlayView {
            tintView.layer?.cornerRadius = radius
            tintView.layer?.masksToBounds = true
        }

        logger.info("窗口 '\(windowID)' 圆角半径已设为：\(radius)pt")
        return true
    }

    // MARK: - 核心 API：移除效果

    /// 移除指定窗口的玻璃效果
    /// - Parameter windowID: 窗口ID
    /// - Returns: 是否成功移除
    @discardableResult
    public func removeEffect(for windowID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return removeEffectUnsafe(windowID: windowID)
    }

    // MARK: - 自定义：切换材质类型

    /// 更改已应用效果的窗口材质类型
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - material: 新的材质类型
    /// - Returns: 是否成功设置
    @discardableResult
    public func setMaterial(for windowID: String, material: UIGlassMaterialType) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let record = records[windowID], let visualView = record.visualEffectView else {
            logger.info("切换材质失败：窗口ID '\(windowID)' 未应用玻璃效果")
            return false
        }

        visualView.material = material.nsMaterial
        record.configuration.material = material

        logger.info("窗口 '\(windowID)' 材质已切换为：\(material.rawValue)")
        return true
    }

    // MARK: - 自定义：着色（Tinting）

    /// 设置或更新窗口玻璃效果的着色（Tinting）
    /// 通过覆盖层实现，不干扰 NSVisualEffectView 本身的材质渲染
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - enabled: 是否启用着色
    ///   - color: 着色颜色（nil 时沿用当前配置或默认透明白）
    /// - Returns: 是否成功设置
    @discardableResult
    public func setTinting(for windowID: String, enabled: Bool, color: NSColor? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let record = records[windowID], let visualView = record.visualEffectView else {
            logger.info("设置着色失败：窗口ID '\(windowID)' 未应用玻璃效果")
            return false
        }

        if enabled {
            let tintColor = color ?? record.configuration.tintColor
            // 如果已有着色层，先移除旧层
            record.tintOverlayView?.removeFromSuperview()
            addTintOverlay(to: visualView, color: tintColor, record: record)
            record.configuration.isTintingEnabled = true
            record.configuration.tintColor = tintColor
            logger.info("窗口 '\(windowID)' 着色已启用，颜色：\(tintColor)")
        } else {
            record.tintOverlayView?.removeFromSuperview()
            record.tintOverlayView = nil
            record.configuration.isTintingEnabled = false
            logger.info("窗口 '\(windowID)' 着色已禁用")
        }

        return true
    }

    // MARK: - 自定义：材料强度

    /// 设置窗口玻璃效果的材料强度
    /// 通过调整 NSVisualEffectView 的 alphaValue 实现，值越小越透明
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - strength: 强度值（0.0 ~ 1.0）
    /// - Returns: 是否成功设置
    @discardableResult
    public func setMaterialStrength(for windowID: String, strength: CGFloat) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let record = records[windowID], let visualView = record.visualEffectView else {
            logger.info("设置强度失败：窗口ID '\(windowID)' 未应用玻璃效果")
            return false
        }

        let clampedStrength = min(1.0, max(0.0, strength))
        visualView.alphaValue = clampedStrength
        record.configuration.materialStrength = clampedStrength

        logger.info("窗口 '\(windowID)' 材料强度已设为：\(clampedStrength)")
        return true
    }

    // MARK: - 自定义：强调效果

    /// 设置窗口是否启用强调效果（更突出的材质渲染）
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - emphasized: 是否强调
    /// - Returns: 是否成功设置
    @discardableResult
    public func setEmphasized(for windowID: String, emphasized: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let record = records[windowID], let visualView = record.visualEffectView else {
            logger.info("设置强调效果失败：窗口ID '\(windowID)' 未应用玻璃效果")
            return false
        }

        visualView.isEmphasized = emphasized
        record.configuration.isEmphasized = emphasized

        logger.info("窗口 '\(windowID)' 强调效果已设为：\(emphasized ? "启用" : "禁用")")
        return true
    }

    // MARK: - 完整配置应用

    /// 对指定窗口应用完整的玻璃效果配置（覆盖所有参数）
    /// 会自动移除旧效果并重新应用
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - configuration: 完整配置
    /// - Returns: 是否成功应用
    @discardableResult
    public func applyConfiguration(to windowID: String, configuration: UIGlassEffectConfiguration) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let window = UIUnifiedRegistry.shared.getWindowRecord(windowID: windowID)?.window else {
            logger.info("应用配置失败：窗口ID '\(windowID)' 不存在于注册表")
            return false
        }

        // 移除旧效果
        removeEffectUnsafe(windowID: windowID)

        let visualView = buildVisualEffectView(configuration: configuration)
        let record = UIGlassEffectRecord(windowID: windowID, window: window, configuration: configuration)
        record.visualEffectView = visualView

        if let contentView = window.contentView {
            visualView.frame = contentView.bounds
            visualView.autoresizingMask = [.width, .height]
            if let firstSubview = contentView.subviews.first {
                contentView.addSubview(visualView, positioned: NSWindow.OrderingMode.below, relativeTo: firstSubview)
            } else {
                contentView.addSubview(visualView)
            }

            if configuration.isTintingEnabled {
                addTintOverlay(to: visualView, color: configuration.tintColor, record: record)
            }
        }

        records[windowID] = record
        logger.info("已为窗口 '\(windowID)' 应用完整配置（材质：\(configuration.material.rawValue)，强度：\(configuration.materialStrength)）")
        return true
    }

    // MARK: - 查询

    /// 获取窗口当前的玻璃效果配置
    /// - Parameter windowID: 窗口ID
    /// - Returns: 配置副本，无效果时返回 nil
    public func configuration(for windowID: String) -> UIGlassEffectConfiguration? {
        lock.lock()
        defer { lock.unlock() }
        return records[windowID]?.configuration
    }

    /// 判断窗口是否已应用玻璃效果
    /// - Parameter windowID: 窗口ID
    /// - Returns: 是否已应用
    public func hasEffect(for windowID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return records[windowID] != nil
    }

    /// 获取所有已应用玻璃效果的窗口ID列表
    public var allEffectWindowIDs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(records.keys)
    }

    /// 获取已应用玻璃效果的活跃记录数量
    public var effectCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return records.count
    }

    // MARK: - 批量操作

    /// 对所有未应用玻璃效果的活跃窗口应用默认材质（窗口背景）
    public func applyDefaultToAllActive() {
        let activeRecords = UIUnifiedRegistry.shared.allWindowRecords
        var appliedCount = 0

        for record in activeRecords {
            let windowID = record.windowID
            if !hasEffect(for: windowID) {
                if applyMaterial(to: windowID, material: .windowBackground) {
                    appliedCount += 1
                }
            }
        }

        logger.info("批量应用完成：已为 \(appliedCount) 个活跃窗口添加默认玻璃效果")
    }

    /// 移除所有窗口的玻璃效果
    public func removeAllEffects() {
        lock.lock()
        let windowIDs = Array(records.keys)
        lock.unlock()

        for windowID in windowIDs {
            _ = removeEffect(for: windowID)
        }
        logger.info("已移除所有窗口的玻璃效果（共 \(windowIDs.count) 个）")
    }

    // MARK: - 状态描述

    /// 获取管理器状态描述（用于调试）
    public var statusDescription: String {
        lock.lock()
        defer { lock.unlock() }

        var lines: [String] = []
        lines.append("=== 玻璃效果管理器状态 ===")
        lines.append("活跃效果数：\(records.count)")
        for (id, record) in records {
            let cfg = record.configuration
            lines.append("[\(id)] 材质：\(cfg.material.rawValue)，混合：\(cfg.blendingMode.rawValue)，强度：\(cfg.materialStrength)，圆角：\(cfg.cornerRadius)，着色：\(cfg.isTintingEnabled ? "开" : "关")")
        }
        lines.append("=== 结束 ===")
        return lines.joined(separator: "\n")
    }

    // MARK: - 私有方法

    /// 构建视觉特效视图
    private func buildVisualEffectView(configuration: UIGlassEffectConfiguration) -> NSVisualEffectView {
        let visualView = NSVisualEffectView()
        visualView.material = configuration.material.nsMaterial
        visualView.blendingMode = configuration.blendingMode.nsBlendingMode
        visualView.state = configuration.state.nsState
        visualView.isEmphasized = configuration.isEmphasized
        visualView.alphaValue = configuration.materialStrength
        return visualView
    }

    /// 添加着色覆盖层到视觉特效视图
    private func addTintOverlay(to visualView: NSVisualEffectView, color: NSColor, record: UIGlassEffectRecord) {
        let tintView = NSView()
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = color.cgColor
        tintView.autoresizingMask = [.width, .height]
        tintView.frame = visualView.bounds

        // 同步圆角
        if record.configuration.cornerRadius > 0 {
            tintView.layer?.cornerRadius = record.configuration.cornerRadius
            tintView.layer?.masksToBounds = true
        }

        visualView.addSubview(tintView)
        record.tintOverlayView = tintView
    }

    /// 内部移除效果（不加锁，调用方必须已持有锁）
    @discardableResult
    private func removeEffectUnsafe(windowID: String) -> Bool {
        guard let record = records[windowID] else {
            return false
        }

        record.visualEffectView?.removeFromSuperview()
        record.tintOverlayView = nil
        records.removeValue(forKey: windowID)
        logger.info("已移除窗口 '\(windowID)' 的玻璃效果")
        return true
    }
}

// MARK: - 迁回自 UI-02：enum UIGlassMaterialType
// MARK: - 窗口动画管理器

/// 窗口动画管理器（单例）
/// 负责统一调度所有窗口的动画效果，包括打开、关闭、最小化、恢复、淡入淡出、缩放等
/// 特性：
/// - 基于 AppKit NSViewAnimation 实现，无 SwiftUI 依赖
/// - 动画配置可自定义（时长、曲线、阻尼、帧率）
/// - 线程安全（通过 NSLock 保护共享状态）
/// - 支持动画取消、并发控制、代理回调
// 已迁回 UI-GL-03_窗口动画效果.swift：class UIWindowAnimationManager（公共类型文件禁止功能实现）

// MARK: - 动画代理转发器

/// 内部使用的 NSAnimationDelegate 转发器
/// 将 NSViewAnimation 的代理回调转发到 UIWindowAnimationManager 的业务层
/// 注意：NSAnimation 的 delegate 是 weak，因此需要管理器强持有此代理对象直到动画结束
// 已迁回 UI-GL-03_窗口动画效果.swift：class UIAnimationDelegateProxy（公共类型文件禁止功能实现）


// MARK: - UI-GL-04 合并类型
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-04_types.swift
// 版本: 2.0
// 跳过重复类型: UIWindowLifecycleManager, UIUnifiedRegistry

// MARK: - 窗口克隆管理器
/// 支持同一模块打开多个独立窗口实例
/// 每个克隆窗口拥有独立ID和内容视图副本
// 已迁回 UI-GL-04_窗口克隆.swift：class UIWindowCloneManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-05 合并类型
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-05_types.swift
// 版本: 2.0
// 跳过重复类型: UIUnifiedRegistry

// MARK: - 材质类型枚举
/// NSVisualEffectView 所有支持的材质类型
/// 涵盖 macOS 10.14+ 全部 14 种标准材质
public enum UIGlassMaterialType: String, CaseIterable {
    case appearanceBased      = "跟随外观"
    case titlebar             = "标题栏"
    case menu                 = "菜单"
    case popover              = "弹出框"
    case sidebar              = "侧边栏"
    case headerView           = "标题视图"
    case sheet                = "工作表"
    case windowBackground     = "窗口背景"
    case hudWindow            = "HUD窗口"
    case fullScreenUI         = "全屏UI"
    case toolTip              = "工具提示"
    case contentBackground    = "内容背景"
    case underWindowBackground = "窗口底层背景"
    case underPageBackground  = "页面底层背景"

    /// 转换为 AppKit 原生材质
    public var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .appearanceBased:       return .contentBackground
        case .titlebar:              return .titlebar
        case .menu:                  return .menu
        case .popover:               return .popover
        case .sidebar:               return .sidebar
        case .headerView:            return .headerView
        case .sheet:                 return .sheet
        case .windowBackground:      return .windowBackground
        case .hudWindow:             return .hudWindow
        case .fullScreenUI:          return .fullScreenUI
        case .toolTip:               return .toolTip
        case .contentBackground:     return .contentBackground
        case .underWindowBackground: return .underWindowBackground
        case .underPageBackground:   return .underPageBackground
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIGlassBlendingMode
// MARK: - 混合模式枚举
/// 玻璃效果的混合模式
public enum UIGlassBlendingMode: String, CaseIterable {
    case behindWindow = "窗口后方"   // 与桌面背景混合，窗口需设为非不透明
    case withinWindow = "窗口内部"   // 与窗口自身内容混合

    public var nsBlendingMode: NSVisualEffectView.BlendingMode {
        switch self {
        case .behindWindow: return .behindWindow
        case .withinWindow: return .withinWindow
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIGlassState
// MARK: - 效果状态枚举
/// 玻璃效果的状态控制
public enum UIGlassState: String, CaseIterable {
    case followsWindowActiveState = "跟随窗口活跃状态"
    case active                   = "始终活跃"
    case inactive                 = "始终非活跃"

    public var nsState: NSVisualEffectView.State {
        switch self {
        case .followsWindowActiveState: return .followsWindowActiveState
        case .active:                   return .active
        case .inactive:                 return .inactive
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIGlassEffectConfiguration
// MARK: - 玻璃效果配置
/// 完整的玻璃效果自定义配置
/// 支持材质、混合模式、状态、圆角、着色、材料强度、强调效果
public struct UIGlassEffectConfiguration {
    /// 材质类型（默认：窗口背景）
    public var material: UIGlassMaterialType = .windowBackground
    /// 混合模式（默认：窗口内部）
    public var blendingMode: UIGlassBlendingMode = .withinWindow
    /// 效果状态（默认：跟随窗口活跃状态）
    public var state: UIGlassState = .followsWindowActiveState
    /// 圆角半径（默认：0，无圆角）
    public var cornerRadius: CGFloat = 0.0
    /// 是否启用着色（Tinting）
    public var isTintingEnabled: Bool = false
    /// 着色颜色（默认：透明白色）
    public var tintColor: NSColor = NSColor.white.withAlphaComponent(0.1)
    /// 材料强度（0.0 ~ 1.0，1.0为默认完全不透明）
    public var materialStrength: CGFloat = 1.0
    /// 是否启用强调效果（更突出的材质渲染）
    public var isEmphasized: Bool = false

    public init() {}

    /// 预设：透明侧边栏风格
    public static var sidebar: UIGlassEffectConfiguration {
        var config = UIGlassEffectConfiguration()
        config.material = .sidebar
        config.blendingMode = .withinWindow
        config.state = .followsWindowActiveState
        return config
    }

    /// 预设：HUD 悬浮面板风格
    public static var hudPanel: UIGlassEffectConfiguration {
        var config = UIGlassEffectConfiguration()
        config.material = .hudWindow
        config.blendingMode = .withinWindow
        config.state = .active
        config.cornerRadius = 12.0
        config.isEmphasized = true
        return config
    }

    /// 预设：桌面背景穿透风格（窗口需为非不透明）
    public static var desktopBehind: UIGlassEffectConfiguration {
        var config = UIGlassEffectConfiguration()
        config.material = .windowBackground
        config.blendingMode = .behindWindow
        config.state = .followsWindowActiveState
        return config
    }
}
