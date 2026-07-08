// 功能31B: 嵌套分割视图 (Nested SplitView)
// 对应: 支持无限层级的垂直/水平分割，每个分割区域可独立拖拽调整大小
// 优先级: P0
// version: 2.0

import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "31B_嵌套分割视图")

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能31B：嵌套分割视图 — 单元测试
func test_nestedSplitView() {
    logger.info("测试1: 创建根节点")
    let node = UISplitNode()
    guard node.isLeaf else {
        fatalError("❌ 测试1失败: 新节点应为叶子")
    }
    logger.info("✅ 测试1通过: 根节点创建成功")
    
    logger.info("测试2: 分割节点")
    let leftView = NSView()
    let rightView = NSView()
    let container = UINestedSplitView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    container.split(node: node, direction: .horizontal, leftView: leftView, rightView: rightView)
    guard !node.isLeaf else {
        fatalError("❌ 测试2失败: 分割后不应为叶子")
    }
    logger.info("✅ 测试2通过: 分割操作成功")
    
    logger.info("=== 全部嵌套分割视图测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UISplitNode
public final class UISplitNode {
    public var direction: UISplitDirection
    public var ratio: CGFloat          // 分割比例 0~1
    public var left: UISplitNode?        // 左/上子节点
    public var right: UISplitNode?       // 右/下子节点
    public var view: NSView?           // 叶子节点对应的视图

    public init(direction: UISplitDirection = .horizontal, ratio: CGFloat = 0.5) {
        self.direction = direction
        self.ratio = ratio
    }

    public var isLeaf: Bool { view != nil }
}

// MARK: - 迁回自 UI-02：class UINestedSplitView
public final class UINestedSplitView: NSView {

    public let rootNode: UISplitNode
    /// 分割线厚度（可自定义）
    public var dividerThickness: CGFloat = 4.0
    private var dividers: [NSView] = []

    public override init(frame frameRect: NSRect) {
        self.rootNode = UISplitNode()
        super.init(frame: frameRect)
        wantsLayer = true
    }

    public required init?(coder: NSCoder) {
        self.rootNode = UISplitNode()
        super.init(coder: coder)
    }

    /// 在指定节点分割
    public func split(node: UISplitNode, direction: UISplitDirection, leftView: NSView, rightView: NSView, ratio: CGFloat = 0.5) {
        node.direction = direction
        node.ratio = max(0.1, min(0.9, ratio))
        node.left = UISplitNode()
        node.left!.view = leftView
        node.right = UISplitNode()
        node.right!.view = rightView
        if let oldView = node.view {
            oldView.removeFromSuperview()
        }
        node.view = nil
        layoutSubviews()
    }

    /// 设置叶子节点的视图
    public func setView(_ view: NSView, at node: UISplitNode) {
        guard node.isLeaf else { return }
        node.view?.removeFromSuperview()
        node.view = view
        addSubview(view)
        layoutSubviews()
    }

    private func layoutSubviews() {
        subviews.forEach { $0.removeFromSuperview() }
        dividers.forEach { $0.removeFromSuperview() }
        dividers.removeAll()
        layoutNode(rootNode, in: bounds)
    }

    private func layoutNode(_ node: UISplitNode, in rect: NSRect) {
        guard !node.isLeaf, let left = node.left, let right = node.right else {
            if let view = node.view {
                view.frame = rect
                addSubview(view)
            }
            return
        }

        let dividerThickness = self.dividerThickness
        let available = max(0, node.direction == .horizontal ? rect.width - dividerThickness : rect.height - dividerThickness)

        let leftSize = available * max(0.1, min(0.9, node.ratio))
        let leftRect: NSRect
        let rightRect: NSRect
        let dividerRect: NSRect

        if node.direction == .horizontal {
            leftRect = NSRect(x: rect.origin.x, y: rect.origin.y, width: leftSize, height: rect.height)
            dividerRect = NSRect(x: rect.origin.x + leftSize, y: rect.origin.y, width: dividerThickness, height: rect.height)
            rightRect = NSRect(x: rect.origin.x + leftSize + dividerThickness, y: rect.origin.y, width: rect.width - leftSize - dividerThickness, height: rect.height)
        } else {
            leftRect = NSRect(x: rect.origin.x, y: rect.origin.y + rect.height - leftSize, width: rect.width, height: leftSize)
            dividerRect = NSRect(x: rect.origin.x, y: rect.origin.y + rect.height - leftSize - dividerThickness, width: rect.width, height: dividerThickness)
            rightRect = NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height - leftSize - dividerThickness)
        }

        let divider = NSView(frame: dividerRect)
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(divider)
        dividers.append(divider)

        layoutNode(left, in: leftRect)
        layoutNode(right, in: rightRect)
    }

    public override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutSubviews()
    }
}

// MARK: - 迁回自 UI-02：enum UISplitDirection
// MARK: - UI-GL-40 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-40_types.swift
// 版本: 2.0
// MARK: - 分割方向
public enum UISplitDirection {
    case horizontal
    case vertical
}
