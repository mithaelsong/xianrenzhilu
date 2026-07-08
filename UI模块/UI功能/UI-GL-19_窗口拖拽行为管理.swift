// 功能14B: 窗口拖拽行为管理
// 对应: 自定义窗口拖拽行为，包括拖拽时半透明、禁用拖拽、拖拽吸附、拖拽对齐线等高级交互
// 优先级: P2
// 版本: 2.0

import Foundation
import AppKit
import os.log

// MARK: - 通知名称
/// 窗口拖拽行为相关通知
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 窗口拖拽管理器
// UIWindowDragManager 已迁移到临时类型文件，后续合并进 UI-02。

// MARK: - 辅助扩展

/// NSRect 辅助扩展
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：private extension NSRect {


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIAlignmentLineView
public final class UIAlignmentLineView: NSView {
    /// 当前需要显示的对齐线集合
    /// 每条线用 (起点, 终点) 表示
    private var lines: [(start: NSPoint, end: NSPoint)] = []
    /// 线条颜色
    private var lineColor: NSColor = NSColor.systemBlue.withAlphaComponent(0.8)
    /// 线条宽度
    private var lineWidth: CGFloat = 1.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    /// 设置对齐线并触发重绘
    /// - Parameters:
    ///   - lines: 对齐线数组，每条线为 (起点, 终点)
    ///   - color: 线条颜色
    ///   - width: 线条宽度
    func setLines(
        _ lines: [(start: NSPoint, end: NSPoint)],
        color: NSColor = NSColor.systemBlue.withAlphaComponent(0.8),
        width: CGFloat = 1.0
    ) {
        self.lines = lines
        self.lineColor = color
        self.lineWidth = width
        self.needsDisplay = true
    }

    /// 清除所有对齐线
    func clearLines() {
        self.lines = []
        self.needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !lines.isEmpty else { return }

        lineColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = lineWidth

        for line in lines {
            path.move(to: line.start)
            path.line(to: line.end)
        }
        path.stroke()
    }

    public override var isFlipped: Bool { return false }
}

// MARK: - 迁回自 UI-02：enum UISnapEdgeType
// MARK: - 标签页视图
/// 单个标签页视图，支持悬停、关闭按钮、选中状态
// 已迁回 UI-GL-16_工具栏管理器.swift：class UIToolbarTabView（公共类型文件禁止功能实现）

// MARK: - 标签条容器
/// 管理多个标签页的水平容器，支持滚动
// 已迁回 UI-GL-16_工具栏管理器.swift：class UIToolbarTabStrip（公共类型文件禁止功能实现）

// MARK: - String 扩展（计算文本宽度）
// 已迁回 UI-GL-16_工具栏管理器.swift：extension String（公共类型文件禁止功能实现）

// MARK: - 工具栏按钮容器
/// 通用工具栏按钮容器，解决 NSToolbarItem.view 的 x 坐标被布局系统忽略的问题
/// 支持：位置偏移、悬停放大、背景色变化
// 已迁回 UI-GL-16_工具栏管理器.swift：class UIToolbarButtonContainer（公共类型文件禁止功能实现）

// MARK: - 工具栏代理
// 已迁回 UI-GL-16_工具栏管理器.swift：class UIToolbarManagerDelegate（公共类型文件禁止功能实现）


// MARK: - UI-GL-17 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-17_types.swift
// 版本: 2.0
// MARK: - 窗口限制代理
/// 窗口限制代理,实现 NSWindowDelegate 以拦截 resize 和 move 事件
///
/// 通过 windowWillResize 拦截尺寸变化,实时应用最小/最大尺寸和宽高比限制。
/// 通过 windowDidMove 拦截位置变化,确保窗口不超出屏幕边界。
/// 该代理弱引用管理器,避免循环引用。
// 已迁回 UI-GL-17_窗口大小与位置限制.swift：class UIWindowSizeRestrictionDelegate（公共类型文件禁止功能实现）

// MARK: - 窗口大小与位置限制管理器
/// 窗口大小与位置限制管理器（单例）
///
/// 管理所有窗口的尺寸限制、比例锁定和位置限制。
/// 通过 NSWindowDelegate 代理拦截 resize 和 move 事件,实时应用限制。
/// 所有可变状态受 NSRecursiveLock 保护,保证线程安全。
/// 支持配置的保存/恢复（基于 JSON 序列化）。
// 已迁回 UI-GL-17_窗口大小与位置限制.swift：class UIWindowSizeRestrictionManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-18 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-18_types.swift
// 版本: 2.0
// MARK: - 工具栏定制管理器
/// 管理工具栏的自定义配置：拖拽重排、导入/导出布局
// 已迁回 UI-GL-18_工具栏可定制.swift：class UIToolbarCustomizationManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-19 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-19_types.swift
// 版本: 2.0
// MARK: - 吸附边缘类型
/// 描述窗口吸附的目标边缘类型
public enum UISnapEdgeType: String, Codable, Sendable, CustomStringConvertible {
    /// 屏幕左边缘
    case screenLeft
    /// 屏幕右边缘
    case screenRight
    /// 屏幕上边缘
    case screenTop
    /// 屏幕下边缘
    case screenBottom
    /// 屏幕水平中心线
    case screenHorizontalCenter
    /// 屏幕垂直中心线
    case screenVerticalCenter
    /// 其他窗口左边缘
    case windowLeft
    /// 其他窗口右边缘
    case windowRight
    /// 其他窗口上边缘
    case windowTop
    /// 其他窗口下边缘
    case windowBottom
    /// 其他窗口水平中心线
    case windowHorizontalCenter
    /// 其他窗口垂直中心线
    case windowVerticalCenter

    public var description: String {
        switch self {
        case .screenLeft: return "屏幕左边缘"
        case .screenRight: return "屏幕右边缘"
        case .screenTop: return "屏幕上边缘"
        case .screenBottom: return "屏幕下边缘"
        case .screenHorizontalCenter: return "屏幕水平中心"
        case .screenVerticalCenter: return "屏幕垂直中心"
        case .windowLeft: return "窗口左边缘"
        case .windowRight: return "窗口右边缘"
        case .windowTop: return "窗口上边缘"
        case .windowBottom: return "窗口下边缘"
        case .windowHorizontalCenter: return "窗口水平中心"
        case .windowVerticalCenter: return "窗口垂直中心"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UISnapResult
// MARK: - 吸附结果
/// 窗口吸附计算结果
public struct UISnapResult: Sendable, CustomStringConvertible {
    /// 是否已吸附
    public let didSnap: Bool
    /// 吸附到的边缘类型
    public let edgeType: UISnapEdgeType?
    /// 吸附后的目标位置（窗口左上角）
    public let snappedOrigin: NSPoint?
    /// 吸附距离
    public let snapDistance: CGFloat?
    /// 吸附到的目标框架（用于对齐线绘制）
    public let targetFrame: NSRect?

    public init(
        didSnap: Bool,
        edgeType: UISnapEdgeType? = nil,
        snappedOrigin: NSPoint? = nil,
        snapDistance: CGFloat? = nil,
        targetFrame: NSRect? = nil
    ) {
        self.didSnap = didSnap
        self.edgeType = edgeType
        self.snappedOrigin = snappedOrigin
        self.snapDistance = snapDistance
        self.targetFrame = targetFrame
    }

    /// 未吸附的空结果
    public static let noSnap = UISnapResult(didSnap: false)

    public var description: String {
        if didSnap, let edge = edgeType, let dist = snapDistance {
            return "已吸附到\(edge)，距离:\(dist)"
        }
        return "未吸附"
    }
}

// MARK: - 迁回自 UI-02：struct UIExcludedArea
// MARK: - 对齐线视图
/// 绘制拖拽对齐线的覆盖视图
/// 使用 CALayer 绘制高对比度线条，在吸附时临时显示
// 已迁回 UI-GL-19_窗口拖拽行为管理.swift：class UIAlignmentLineView（公共类型文件禁止功能实现）

// MARK: - 排除区域
/// 排除区域编码表示
public struct UIExcludedArea: Codable, Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    /// 区域描述（可选，用于日志）
    public var label: String?

    public var rect: NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }

    public init(rect: NSRect, label: String? = nil) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
        self.label = label
    }

    /// 描述字符串，用于日志输出
    public var descriptionString: String {
        if let desc = label, !desc.isEmpty {
            return "\(desc) [\(x), \(y), \(width)x\(height)]"
        }
        return "[\(x), \(y), \(width)x\(height)]"
    }
}

// MARK: - 迁回自 UI-02：struct UIWindowDragConfiguration
// MARK: - 窗口拖拽配置
/// 单个窗口的拖拽行为配置
/// 可持久化，支持 Codable 序列化
public struct UIWindowDragConfiguration: Codable, Equatable {
    /// 窗口唯一标识
    public var windowID: String
    /// 拖拽时窗口透明度（0.0 ~ 1.0）
    public var dragOpacity: CGFloat
    /// 是否启用拖拽
    public var dragEnabled: Bool
    /// 是否启用吸附
    public var snapEnabled: Bool
    /// 是否显示对齐线
    public var alignmentLinesEnabled: Bool
    /// 吸附阈值（像素距离），默认 10 点
    public var snapThreshold: CGFloat
    /// 排除区域列表（屏幕坐标系中的矩形区域）
    public var excludedAreas: [UIExcludedArea]

    public init(
        windowID: String,
        dragOpacity: CGFloat = 0.75,
        dragEnabled: Bool = true,
        snapEnabled: Bool = true,
        alignmentLinesEnabled: Bool = true,
        snapThreshold: CGFloat = 10.0,
        excludedAreas: [UIExcludedArea] = []
    ) {
        self.windowID = windowID
        self.dragOpacity = dragOpacity
        self.dragEnabled = dragEnabled
        self.snapEnabled = snapEnabled
        self.alignmentLinesEnabled = alignmentLinesEnabled
        self.snapThreshold = snapThreshold
        self.excludedAreas = excludedAreas
    }

    /// 默认配置
    public static func `default`(for windowID: String) -> UIWindowDragConfiguration {
        UIWindowDragConfiguration(windowID: windowID)
    }
}

// MARK: - 迁回自 UI-02：struct UIDragSession
// MARK: - 拖拽状态
/// 单个窗口的实时拖拽状态
public struct UIDragSession {
    /// 窗口唯一标识
    let windowID: String
    /// 拖拽起始时鼠标位置（屏幕坐标）
    let startMouseLocation: NSPoint
    /// 拖拽起始时窗口位置（屏幕坐标）
    let startWindowOrigin: NSPoint
    /// 拖拽起始时窗口大小
    let startWindowSize: NSSize
    /// 拖拽开始时间
    let startTime: Date
    /// 窗口原始透明度（用于恢复）
    let originalOpacity: CGFloat
    /// 是否已吸附（本次拖拽中）
    var hasSnapped: Bool = false
    /// 当前吸附结果
    var currentSnap: UISnapResult = .noSnap

    init(
        windowID: String,
        startMouseLocation: NSPoint,
        startWindowOrigin: NSPoint,
        startWindowSize: NSSize,
        originalOpacity: CGFloat
    ) {
        self.windowID = windowID
        self.startMouseLocation = startMouseLocation
        self.startWindowOrigin = startWindowOrigin
        self.startWindowSize = startWindowSize
        self.startTime = Date()
        self.originalOpacity = originalOpacity
    }
}
