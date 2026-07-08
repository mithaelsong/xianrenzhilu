// 功能7B: 视图容器协议
// 对应: 所有模块视图必须实现 UIContainerViewProtocol，支持大小自适应、主题切换
// 优先级: P0
// 版本: 2.0

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "07B_视图容器协议")

#if DEBUG
// import XCTest (disabled for executable target)
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIContainerView

private struct UIContainerResizeEdges: OptionSet {
    let rawValue: Int

    static let left = UIContainerResizeEdges(rawValue: 1 << 0)
    static let right = UIContainerResizeEdges(rawValue: 1 << 1)
    static let top = UIContainerResizeEdges(rawValue: 1 << 2)
    static let bottom = UIContainerResizeEdges(rawValue: 1 << 3)

    var isCorner: Bool {
        let horizontal = contains(.left) || contains(.right)
        let vertical = contains(.top) || contains(.bottom)
        return horizontal && vertical
    }
}

private final class UIContainerChromeOverlayView: NSView {
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

open class UIContainerView: NSView, UIContainerViewProtocol {
    
    public let viewIdentifier: String
    public let displayName: String
    public let moduleName: String
    
    /// 毛玻璃效果视图
    public private(set) var glassView: NSVisualEffectView?
    
    /// 内容视图，所有子视图添加到这个视图上
    public let contentView: NSView

    /// 最上层视觉覆盖层：只画边框/界限，不参与鼠标事件。
    private let chromeOverlayView: NSView
    
    private nonisolated(unsafe) var isDarkModeObserver: NSKeyValueObservation?

    public var resizeHitThickness: CGFloat = 8
    private let containerCornerRadius: CGFloat = 14
    private let containerBorderWidth: CGFloat = 1.2
    private var activeResizeEdges: UIContainerResizeEdges?
    private var isMovingContainer = false
    private var resizeStartFrame: NSRect = .zero
    private var resizeStartMouseInSuperview: NSPoint = .zero
    private var moveStartFrame: NSRect = .zero
    private var moveStartMouseInSuperview: NSPoint = .zero
    private var resizeTrackingArea: NSTrackingArea?
    private let moveHitTopInset: CGFloat = 8
    private let moveHitHeight: CGFloat = 22
    
    public required init(viewIdentifier: String, displayName: String, moduleName: String, frame: NSRect = .zero) {
        self.viewIdentifier = viewIdentifier
        self.displayName = displayName
        self.moduleName = moduleName
        self.contentView = NSView(frame: .zero)
        self.chromeOverlayView = UIContainerChromeOverlayView(frame: .zero)
        
        super.init(frame: frame)
        
        setupLiquidGlassBackground()
        setupContentView()
        viewDidInitialize()
    }
    
    public required init?(coder: NSCoder) {
        self.viewIdentifier = ""
        self.displayName = ""
        self.moduleName = ""
        self.contentView = NSView()
        self.chromeOverlayView = UIContainerChromeOverlayView(frame: .zero)
        super.init(coder: coder)
        setupLiquidGlassBackground()
        setupContentView()
        viewDidInitialize()
    }
    
    deinit {
        isDarkModeObserver?.invalidate()
    }

    open override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    public func persistLayoutState() {
        guard superview != nil else { return }
        UISerializationManager.shared.saveContainerFrame(identifier: viewIdentifier, frame: frame)
    }

    open override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let resizeTrackingArea {
            removeTrackingArea(resizeTrackingArea)
        }
        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
        resizeTrackingArea = tracking
    }

    open override func hitTest(_ point: NSPoint) -> NSView? {
        // contentView 覆盖了整个容器，如果不在 hitTest 阶段拦截边缘，
        // 左/右/下边和四角的 mouseDown 会被内容子视图吃掉，父容器收不到缩放事件。
        // ⚠️ hitTest 传入的 point 是【superview 坐标系】，而 resizeEdges/isMoveDragArea 用 bounds（自身坐标系）判断；
        // 必须先转换到自身坐标系，否则容器 origin 偏移后边缘判断出错（部分边/角无法缩放）。
        let local = convert(point, from: superview)
        if resizeEdges(at: local) != nil {
            return self
        }
        // 顶部拖拽区允许按钮等 NSControl 优先响应。
        // 折叠面板只剩一级功能栏时，折叠/展开按钮会落在顶部拖拽区；若直接 return self，按钮无法再次展开。
        if isMoveDragArea(at: local) {
            let hit = super.hitTest(point)
            if let hit, isInteractiveControlHit(hit) {
                return hit
            }
            return self
        }
        return super.hitTest(point)
    }

    private func isInteractiveControlHit(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let node = current, node !== self {
            if node is NSControl { return true }
            current = node.superview
        }
        return false
    }

    open override func mouseMoved(with event: NSEvent) {
        updateResizeCursor(for: event)
        super.mouseMoved(with: event)
    }

    open override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        super.mouseExited(with: event)
    }

    open override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let superview else {
            super.mouseDown(with: event)
            return
        }

        if let edges = resizeEdges(at: point) {
            activeResizeEdges = edges
            resizeStartFrame = frame
            resizeStartMouseInSuperview = superview.convert(event.locationInWindow, from: nil)
            return
        }

        if isMoveDragArea(at: point) {
            isMovingContainer = true
            moveStartFrame = frame
            moveStartMouseInSuperview = superview.convert(event.locationInWindow, from: nil)
            NSCursor.closedHand.set()
            return
        }

        super.mouseDown(with: event)
    }

    open override func mouseDragged(with event: NSEvent) {
        guard let superview else {
            super.mouseDragged(with: event)
            return
        }

        let currentMouse = superview.convert(event.locationInWindow, from: nil)

        if isMovingContainer {
            let deltaX = currentMouse.x - moveStartMouseInSuperview.x
            let deltaY = currentMouse.y - moveStartMouseInSuperview.y
            var next = moveStartFrame
            next.origin.x += deltaX
            next.origin.y += deltaY
            frame = constrainedMoveFrame(next, in: superview.bounds)
            needsLayout = true
            needsDisplay = true
            return
        }

        guard let edges = activeResizeEdges else {
            super.mouseDragged(with: event)
            return
        }

        let deltaX = currentMouse.x - resizeStartMouseInSuperview.x
        let deltaY = currentMouse.y - resizeStartMouseInSuperview.y
        var next = resizeStartFrame
        let minSize = minimumSize
        let parentIsFlipped = superview.isFlipped

        // 横向：AppKit flipped/non-flipped 对 x 轴无影响。
        if edges.contains(.right) {
            next.size.width = max(minSize.width, resizeStartFrame.width + deltaX)
        }
        if edges.contains(.left) {
            let proposedWidth = max(minSize.width, resizeStartFrame.width - deltaX)
            next.origin.x = resizeStartFrame.maxX - proposedWidth
            next.size.width = proposedWidth
        }

        // 纵向必须区分父视图坐标系。
        // 非 flipped：y 往上增大；flipped：y 往下增大。
        // 正常 UI 期望是“拖哪条边，哪条边跟着鼠标走，另一条边固定”。
        if parentIsFlipped {
            // flipped 父坐标：origin.y 是视觉顶部，maxY 是视觉底部。
            if edges.contains(.top) {
                let proposedHeight = max(minSize.height, resizeStartFrame.height - deltaY)
                next.origin.y = resizeStartFrame.maxY - proposedHeight
                next.size.height = proposedHeight
            }
            if edges.contains(.bottom) {
                next.size.height = max(minSize.height, resizeStartFrame.height + deltaY)
            }
        } else {
            // 普通父坐标：origin.y 是视觉底部，maxY 是视觉顶部。
            if edges.contains(.top) {
                next.size.height = max(minSize.height, resizeStartFrame.height + deltaY)
            }
            if edges.contains(.bottom) {
                let proposedHeight = max(minSize.height, resizeStartFrame.height - deltaY)
                next.origin.y = resizeStartFrame.maxY - proposedHeight
                next.size.height = proposedHeight
            }
        }

        frame = constrainedFrame(next, resizing: edges, in: superview.bounds, parentIsFlipped: parentIsFlipped)
        needsLayout = true
        needsDisplay = true
    }

    open override func mouseUp(with event: NSEvent) {
        if activeResizeEdges != nil || isMovingContainer {
            persistLayoutState()
        }
        activeResizeEdges = nil
        isMovingContainer = false
        updateResizeCursor(for: event)
        super.mouseUp(with: event)
    }

    private func resizeEdges(at point: NSPoint) -> UIContainerResizeEdges? {
        guard bounds.insetBy(dx: -1, dy: -1).contains(point) else { return nil }
        var edges: UIContainerResizeEdges = []
        if point.x <= resizeHitThickness { edges.insert(.left) }
        if point.x >= bounds.width - resizeHitThickness { edges.insert(.right) }

        // 这里判断的是容器自身坐标系，不是父坐标系。
        // UIContainerView 默认非 flipped；如果以后子类改成 flipped，也能正确识别视觉上下边。
        if isFlipped {
            if point.y <= resizeHitThickness { edges.insert(.top) }
            if point.y >= bounds.height - resizeHitThickness { edges.insert(.bottom) }
        } else {
            if point.y <= resizeHitThickness { edges.insert(.bottom) }
            if point.y >= bounds.height - resizeHitThickness { edges.insert(.top) }
        }
        return edges.isEmpty ? nil : edges
    }

    private func isMoveDragArea(at point: NSPoint) -> Bool {
        guard bounds.contains(point), resizeEdges(at: point) == nil else { return false }
        let topMinY: CGFloat
        let topMaxY: CGFloat
        if isFlipped {
            topMinY = moveHitTopInset
            topMaxY = moveHitTopInset + moveHitHeight
        } else {
            topMinY = bounds.height - moveHitTopInset - moveHitHeight
            topMaxY = bounds.height - moveHitTopInset
        }
        return point.y >= topMinY && point.y <= topMaxY
    }

    private func updateResizeCursor(for event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if activeResizeEdges == nil, isMovingContainer || isMoveDragArea(at: point) {
            (isMovingContainer ? NSCursor.closedHand : NSCursor.openHand).set()
            return
        }

        guard let edges = activeResizeEdges ?? resizeEdges(at: point) else {
            NSCursor.arrow.set()
            return
        }

        if edges.isCorner {
            diagonalResizeCursor(for: edges).set()
        } else if edges.contains(.left) || edges.contains(.right) {
            NSCursor.resizeLeftRight.set()
        } else if edges.contains(.top) || edges.contains(.bottom) {
            NSCursor.resizeUpDown.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func diagonalResizeCursor(for edges: UIContainerResizeEdges) -> NSCursor {
        let topLeftToBottomRight =
            (edges.contains(.top) && edges.contains(.left)) ||
            (edges.contains(.bottom) && edges.contains(.right))
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 18, height: 18).fill()
        NSColor.labelColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 2.0
        path.lineCapStyle = .round
        if topLeftToBottomRight {
            path.move(to: NSPoint(x: 4, y: 14))
            path.line(to: NSPoint(x: 14, y: 4))
            path.move(to: NSPoint(x: 4, y: 14))
            path.line(to: NSPoint(x: 8, y: 14))
            path.move(to: NSPoint(x: 4, y: 14))
            path.line(to: NSPoint(x: 4, y: 10))
            path.move(to: NSPoint(x: 14, y: 4))
            path.line(to: NSPoint(x: 10, y: 4))
            path.move(to: NSPoint(x: 14, y: 4))
            path.line(to: NSPoint(x: 14, y: 8))
        } else {
            path.move(to: NSPoint(x: 4, y: 4))
            path.line(to: NSPoint(x: 14, y: 14))
            path.move(to: NSPoint(x: 4, y: 4))
            path.line(to: NSPoint(x: 8, y: 4))
            path.move(to: NSPoint(x: 4, y: 4))
            path.line(to: NSPoint(x: 4, y: 8))
            path.move(to: NSPoint(x: 14, y: 14))
            path.line(to: NSPoint(x: 10, y: 14))
            path.move(to: NSPoint(x: 14, y: 14))
            path.line(to: NSPoint(x: 14, y: 10))
        }
        path.stroke()
        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: 9, y: 9))
    }

    private func constrainedMoveFrame(_ rect: NSRect, in parentBounds: NSRect) -> NSRect {
        var result = rect
        result.size.width = min(result.width, parentBounds.width)
        result.size.height = min(result.height, parentBounds.height)
        result.origin.x = min(max(result.origin.x, parentBounds.minX), parentBounds.maxX - result.width)
        result.origin.y = min(max(result.origin.y, parentBounds.minY), parentBounds.maxY - result.height)
        return result
    }

    private func constrainedFrame(_ rect: NSRect, resizing edges: UIContainerResizeEdges, in parentBounds: NSRect, parentIsFlipped: Bool) -> NSRect {
        var result = rect
        let minSize = minimumSize
        let maxWidth = max(1, parentBounds.width)
        let maxHeight = max(1, parentBounds.height)

        // UI 模块必须完整留在 UI 内容区内：尺寸不能大于父内容区。
        result.size.width = min(max(minSize.width, result.size.width), maxWidth)
        result.size.height = min(max(minSize.height, result.size.height), maxHeight)

        // 横向按拖动边约束：拖右边时固定左边，拖左边时固定右边。
        if edges.contains(.left) {
            if result.minX < parentBounds.minX {
                result.origin.x = parentBounds.minX
                result.size.width = min(maxWidth, max(minSize.width, resizeStartFrame.maxX - parentBounds.minX))
            }
            if result.maxX > parentBounds.maxX { result.origin.x = parentBounds.maxX - result.width }
        }
        if edges.contains(.right) {
            if result.maxX > parentBounds.maxX {
                result.size.width = min(maxWidth, max(minSize.width, parentBounds.maxX - result.minX))
            }
            if result.minX < parentBounds.minX { result.origin.x = parentBounds.minX }
        }

        if parentIsFlipped {
            // flipped：视觉顶部是 minY，视觉底部是 maxY。
            if edges.contains(.top) {
                if result.minY < parentBounds.minY {
                    result.origin.y = parentBounds.minY
                    result.size.height = min(maxHeight, max(minSize.height, resizeStartFrame.maxY - parentBounds.minY))
                }
                if result.maxY > parentBounds.maxY { result.origin.y = parentBounds.maxY - result.height }
            }
            if edges.contains(.bottom) {
                if result.maxY > parentBounds.maxY {
                    result.size.height = min(maxHeight, max(minSize.height, parentBounds.maxY - result.minY))
                }
                if result.minY < parentBounds.minY { result.origin.y = parentBounds.minY }
            }
        } else {
            // 非 flipped：视觉底部是 minY，视觉顶部是 maxY。
            if edges.contains(.bottom) {
                if result.minY < parentBounds.minY {
                    result.origin.y = parentBounds.minY
                    result.size.height = min(maxHeight, max(minSize.height, resizeStartFrame.maxY - parentBounds.minY))
                }
                if result.maxY > parentBounds.maxY { result.origin.y = parentBounds.maxY - result.height }
            }
            if edges.contains(.top) {
                if result.maxY > parentBounds.maxY {
                    result.size.height = min(maxHeight, max(minSize.height, parentBounds.maxY - result.minY))
                }
                if result.minY < parentBounds.minY { result.origin.y = parentBounds.minY }
            }
        }

        // 最后兜底夹紧，避免任何浮点/最小尺寸冲突导致模块越界。
        result.origin.x = min(max(result.origin.x, parentBounds.minX), parentBounds.maxX - result.width)
        result.origin.y = min(max(result.origin.y, parentBounds.minY), parentBounds.maxY - result.height)
        return result
    }
    
    // MARK: - 毛玻璃背景（液态玻璃风格）
    
    private func setupLiquidGlassBackground() {
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.cornerRadius = containerCornerRadius
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.34
        layer?.shadowRadius = 18
        layer?.shadowOffset = NSSize(width: 0, height: -8)
        layer?.shouldRasterize = false

        // 创建毛玻璃效果视图
        let vibrancy = NSVisualEffectView(frame: bounds)
        vibrancy.wantsLayer = true
        vibrancy.material = .windowBackground  // 液态玻璃标准材质
        vibrancy.blendingMode = .behindWindow
        vibrancy.state = .followsWindowActiveState
        vibrancy.autoresizingMask = [.width, .height]
        vibrancy.layer?.cornerRadius = containerCornerRadius
        vibrancy.layer?.masksToBounds = true
        vibrancy.layer?.borderWidth = containerBorderWidth
        vibrancy.layer?.borderColor = currentContainerBorderColor().cgColor
        addSubview(vibrancy)
        glassView = vibrancy

        updateContainerChrome()
        
        // 监听主题变化（通过 effectiveAppearance 的 KVO 监听系统外观切换）
        isDarkModeObserver = self.observe(\.effectiveAppearance, options: [.new]) { [weak self] view, _ in
            self?.updateTheme()
        }
        
        // 初始适配主题
        updateTheme()
    }
    
    private func setupContentView() {
        contentView.frame = bounds
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = currentContainerFillColor().cgColor
        contentView.layer?.cornerRadius = containerCornerRadius
        contentView.layer?.masksToBounds = true
        addSubview(contentView)

        chromeOverlayView.frame = bounds
        chromeOverlayView.autoresizingMask = [.width, .height]
        chromeOverlayView.wantsLayer = true
        chromeOverlayView.layer?.backgroundColor = NSColor.clear.cgColor
        chromeOverlayView.layer?.cornerRadius = containerCornerRadius
        chromeOverlayView.layer?.masksToBounds = false
        chromeOverlayView.layer?.borderWidth = containerBorderWidth
        chromeOverlayView.layer?.borderColor = currentContainerBorderColor().cgColor
        addSubview(chromeOverlayView, positioned: .above, relativeTo: contentView)
    }

    private func currentContainerBorderColor() -> NSColor {
        let isDark = effectiveAppearance.name == .darkAqua || effectiveAppearance.name == .vibrantDark
        return isDark
            ? NSColor.white.withAlphaComponent(0.62)
            : NSColor.black.withAlphaComponent(0.38)
    }

    private func currentContainerFillColor() -> NSColor {
        let isDark = effectiveAppearance.name == .darkAqua || effectiveAppearance.name == .vibrantDark
        return isDark
            ? NSColor.black.withAlphaComponent(0.18)
            : NSColor.white.withAlphaComponent(0.24)
    }

    private func updateContainerChrome() {
        layer?.shadowPath = CGPath(roundedRect: bounds, cornerWidth: containerCornerRadius, cornerHeight: containerCornerRadius, transform: nil)
        glassView?.layer?.cornerRadius = containerCornerRadius
        glassView?.layer?.borderWidth = 0
        glassView?.layer?.borderColor = nil
        contentView.layer?.cornerRadius = containerCornerRadius
        contentView.layer?.backgroundColor = currentContainerFillColor().cgColor
        chromeOverlayView.frame = bounds
        chromeOverlayView.layer?.cornerRadius = containerCornerRadius
        chromeOverlayView.layer?.borderWidth = containerBorderWidth
        chromeOverlayView.layer?.borderColor = currentContainerBorderColor().cgColor
        chromeOverlayView.needsDisplay = true
    }
    
    private func updateTheme() {
        let isDark = effectiveAppearance.name == .darkAqua || effectiveAppearance.name == .vibrantDark
        updateContainerChrome()
        viewDidChangeTheme(isDark)
    }
    
    // MARK: - 布局
    
    open override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        glassView?.frame = bounds
        contentView.frame = bounds
        chromeOverlayView.frame = bounds
        updateContainerChrome()
        viewDidResize(to: bounds.size)
    }
    
    // MARK: - UIContainerViewProtocol
    
    open func viewDidInitialize() {
        // 子类重写
    }
    
    open func viewDidResize(to newSize: NSSize) {
        // 子类重写
    }
    
    open func viewDidChangeTheme(_ isDarkMode: Bool) {
        // 子类重写
    }
    
    open var minimumSize: NSSize {
        return NSSize(width: 200, height: 150)
    }
    
    open var preferredSize: NSSize {
        return NSSize(width: 400, height: 300)
    }
}

// MARK: - 迁回自 UI-02：class UIContainerFactory
public final class UIContainerFactory : @unchecked Sendable {

    public static let shared = UIContainerFactory()

    private var registeredTypes: [String: UIContainerView.Type] = [:]
    private let lock = NSRecursiveLock()

    private init() {

    }

    /// 注册容器类型
    /// - Parameters:
    ///   - containerType: 容器视图的类类型
    ///   - identifier: 唯一标识符
    public func register(containerType: UIContainerView.Type, for identifier: String) {
        lock.lock()
        registeredTypes[identifier] = containerType
        lock.unlock()
        logger.info("已注册容器类型 '\(identifier)'")
    }
    
    /// 创建容器视图
    /// - Parameters:
    ///   - identifier: 已注册的容器标识符
    ///   - displayName: 显示名称
    ///   - moduleName: 所属模块
    ///   - frame: 初始位置和大小
    /// - Returns: 容器视图实例（未注册的标识符返回默认 UIContainerView）
    public func createContainer(identifier: String, displayName: String, moduleName: String, frame: NSRect) -> UIContainerView {
        lock.lock()
        let type = registeredTypes[identifier]
        lock.unlock()
        
        let restoredFrame = UISerializationManager.shared.restoredContainerFrame(identifier: identifier, fallback: frame)
        if let type = type {
            return type.init(viewIdentifier: identifier, displayName: displayName, moduleName: moduleName, frame: restoredFrame)
        }
        return UIContainerView(viewIdentifier: identifier, displayName: displayName, moduleName: moduleName, frame: restoredFrame)
    }
}

// MARK: - 迁回自 UI-02：protocol UIContainerViewProtocol
// MARK: - 玻璃效果记录
/// 单个窗口的玻璃效果记录
// 已迁回 UI-GL-05_窗口玻璃效果.swift：class UIGlassEffectRecord（公共类型文件禁止功能实现）

// MARK: - 玻璃效果管理器
/// 全局玻璃效果管理器单例
/// 管理所有窗口的 NSVisualEffectView 玻璃效果
/// 线程安全：所有公开 API 使用 NSRecursiveLock 保护
// 已迁回 UI-GL-05_窗口玻璃效果.swift：class UIGlassEffectManager（公共类型文件禁止功能实现）


// MARK: - 容器视图协议
/// 所有模块视图必须实现的协议
/// 提供统一的大小自适应、主题切换、生命周期回调
@MainActor @objc public protocol UIContainerViewProtocol {
    /// 视图的唯一标识
    var viewIdentifier: String { get }

    /// 视图的显示名称（用于面板标题）
    var displayName: String { get }

    /// 视图所属模块名
    var moduleName: String { get }

    /// 视图初始化完成时调用
    @objc optional func viewDidInitialize()

    /// 视图大小变化时调用
    @objc optional func viewDidResize(to newSize: NSSize)

    /// 主题切换时调用
    @objc optional func viewDidChangeTheme(_ isDarkMode: Bool)

    /// 视图即将显示时调用
    @objc optional func viewWillAppear()

    /// 视图即将隐藏时调用
    @objc optional func viewWillDisappear()

    /// 获取视图的最小尺寸
    @objc optional var minimumSize: NSSize { get }

    /// 获取视图的推荐尺寸
    @objc optional var preferredSize: NSSize { get }
}

// MARK: - UI-GL-06 合并类型
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-06_types.swift
// 版本: 2.0
// 跳过重复类型: 无

