// 功能10B: 面板自动隐藏
// 对应: 面板不使用时自动收缩为标签，鼠标悬停或点击时展开（类似Xcode工具区）
// 优先级: P1
// 版本: 2.0

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "10B_面板自动隐藏")

// 类型定义已迁移至 UI-GL-12_types.swift
// UIAutoHideState → UIAutoHideState (已以UI开头)
// AutoHidePanelView → UIAutoHidePanelView (已加UI前缀)


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIAutoHidePanelView
open class UIAutoHidePanelView: NSView {
    
    // MARK: - 属性
    
    /// 当前状态
    public private(set) var autoHideState: UIAutoHideState = .expanded
    
    /// 展开时的宽度
    public var expandedWidth: CGFloat = 300
    
    /// 收缩时的宽度（标签宽度）
    public var collapsedWidth: CGFloat = 36
    
    /// 展开动画时长
    public var expandDuration: TimeInterval = 0.25
    
    /// 收缩动画时长
    public var collapseDuration: TimeInterval = 0.2
    
    /// 鼠标悬停到展开的延迟
    public var expandDelay: TimeInterval = 0.15
    
    /// 鼠标离开到收缩的延迟
    public var collapseDelay: TimeInterval = 0.5
    
    /// 是否固定为展开状态（点击图钉按钮后）
    public var isPinned: Bool = false {
        didSet {
            if isPinned {
                expand()
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 标签栏（收缩时显示的窄条）
    public private(set) var tabBar: NSView!
    
    /// 标签按钮
    public private(set) var tabButton: NSButton!
    
    /// 图钉按钮
    public private(set) var pinButton: NSButton!
    
    /// 内容区域
    public private(set) var contentArea: NSView!
    
    /// 毛玻璃背景
    private var visualEffectView: NSVisualEffectView!
    
    // MARK: - 私有状态
    
    private var expandWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    private var trackingArea: NSTrackingArea?
    private var widthConstraint: NSLayoutConstraint?
    
    // MARK: - 初始化
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        
        // 毛玻璃背景
        visualEffectView = NSVisualEffectView(frame: bounds)
        visualEffectView.material = .windowBackground
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .followsWindowActiveState
        visualEffectView.autoresizingMask = [.width, .height]
        addSubview(visualEffectView)
        
        // 标签栏
        tabBar = NSView(frame: NSRect(x: 0, y: 0, width: collapsedWidth, height: bounds.height))
        tabBar.wantsLayer = true
        tabBar.autoresizingMask = [.height]
        addSubview(tabBar)
        
        // 标签按钮
        tabButton = NSButton(frame: NSRect(x: 4, y: bounds.midY - 18, width: 28, height: 36))
        tabButton.bezelStyle = .shadowlessSquare
        tabButton.title = ""
        tabButton.isBordered = false
        tabBar.addSubview(tabButton)
        
        // 图钉按钮
        pinButton = NSButton(frame: NSRect(x: 4, y: 8, width: 28, height: 24))
        pinButton.bezelStyle = .shadowlessSquare
        pinButton.title = "📌"
        pinButton.isBordered = false
        pinButton.setButtonType(.toggle)
        pinButton.action = #selector(togglePin)
        pinButton.target = self
        tabBar.addSubview(pinButton)
        
        // 内容区域初始可见
        contentArea = NSView(frame: NSRect(x: collapsedWidth, y: 0, width: bounds.width - collapsedWidth, height: bounds.height))
        contentArea.wantsLayer = true
        contentArea.autoresizingMask = [.width, .height]
        contentArea.isHidden = false
        addSubview(contentArea)
    }
    
    // MARK: - 鼠标追踪
    
    open override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let oldArea = trackingArea {
            removeTrackingArea(oldArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    open override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        // 取消延迟收缩
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        
        // 如果不是图钉固定状态，延迟展开
        if !isPinned && autoHideState == .collapsed {
            let workItem = DispatchWorkItem { [weak self] in
                self?.expand()
            }
            expandWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + expandDelay, execute: workItem)
        }
    }
    
    open override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        // 取消延迟展开
        expandWorkItem?.cancel()
        expandWorkItem = nil
        
        // 如果不是图钉固定状态，延迟收缩
        if !isPinned && autoHideState == .expanded {
            let workItem = DispatchWorkItem { [weak self] in
                self?.collapse()
            }
            collapseWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + collapseDelay, execute: workItem)
        }
    }
    
    // MARK: - 展开/收缩
    
    /// 展开面板
    public func expand() {
        guard autoHideState != .expanded else { return }
        autoHideState = .expanding
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = expandDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            var frame = self.frame
            frame.size.width = expandedWidth
            self.animator().frame = frame
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            self.autoHideState = .expanded
            self.contentArea.isHidden = false
        }
    }
    
    /// 收缩面板
    public func collapse() {
        guard autoHideState != .collapsed && !isPinned else { return }
        autoHideState = .collapsing
        
        contentArea.isHidden = true
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = collapseDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            var frame = self.frame
            frame.size.width = collapsedWidth
            self.animator().frame = frame
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            self.autoHideState = .collapsed
        }
    }
    
    // MARK: - 动作
    
    @objc private func togglePin() {
        isPinned.toggle()
    }
}

// MARK: - 迁回自 UI-02：enum UIAutoHideState
// MARK: - UI-GL-12 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-12_types.swift
// 版本: 2.0
// MARK: - 自动隐藏状态
/// 面板自动隐藏的当前状态
public enum UIAutoHideState {
    /// 完全展开
    case expanded
    /// 收缩为标签
    case collapsed
    /// 正在展开动画中
    case expanding
    /// 正在收缩动画中
    case collapsing
}
