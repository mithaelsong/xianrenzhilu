// 功能70: 视图点击置顶
// 对应: 同一窗口内的视图点击置顶，解决模块重叠问题
// 优先级: P0
//
//  使用系统原生API实现的极简版本，不需要重复造轮子
//

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "70_视图点击置顶")

// MARK: - NSView 扩展 - 点击置顶
public extension NSView {
    /// 为视图添加点击置顶功能（使用系统原生API）
    /// 点击视图时自动将其置于父视图的最上层
    func addClickToFront() {
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClickForBringToFront(_:)))
        clickGesture.buttonMask = 0x1 // 只响应左键点击
        addGestureRecognizer(clickGesture)

        // 添加边缘检测
        // setupModuleEdgeHandling() → already defined in UI-GL-40_嵌套分割视图.swift

        logger.info("已为视图 \(self.identifier?.rawValue ?? "无标识") 添加点击置顶和边缘管理功能")
    }

    /// 移除视图的点击置顶功能
    func removeClickToFront() {
        for gesture in gestureRecognizers {
            if let clickGesture = gesture as? NSClickGestureRecognizer,
               clickGesture.action == #selector(handleClickForBringToFront(_:)) {
                removeGestureRecognizer(clickGesture)
            }
        }

        logger.info("已移除视图 \(self.identifier?.rawValue ?? "无标识") 的点击置顶功能")
    }

    @objc private func handleClickForBringToFront(_ sender: NSClickGestureRecognizer) {
        guard sender.state == .ended,
              let targetView = sender.view else {
            return
        }

        // 核心实现：移除后重新添加，自动置于最上层。
        // 修复：必须先缓存 superview；removeFromSuperview 后 targetView.superview 会变 nil，
        // 原写法 targetView.superview?.addSubview 是对 nil 调用，导致视图被永久移出父视图树（消失）。
        guard let superview = targetView.superview else { return }
        targetView.removeFromSuperview()
        superview.addSubview(targetView)

        if let identifier = targetView.identifier?.rawValue {
            logger.info("点击视图 \(identifier)，已将其置于最上层")
        } else {
            logger.info("点击未标识视图，已将其置于最上层")
        }
    }
}

// MARK: - 便捷扩展方法
/// 针对容器视图的便捷扩展
extension NSStackView {
    /// 为所有排列的子视图添加点击置顶功能
    func addClickToFrontAll() {
        for view in arrangedSubviews {
            view.addClickToFront()
        }
    }

    /// 移除所有排列的子视图的点击置顶功能
    func removeClickToFrontAll() {
        for view in arrangedSubviews {
            view.removeClickToFront()
        }
    }
}

// MARK: - 测试
#if DEBUG
func test_UIViewClickToFront() {
    print("\n=== UI-70 视图点击置顶测试 ===\n")

    // 创建测试窗口
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.center()
    window.title = "点击置顶测试"

    // 创建两个重叠的视图
    let view1 = NSView(frame: CGRect(x: 50, y: 50, width: 300, height: 200))
    view1.wantsLayer = true
    view1.layer?.backgroundColor = NSColor.red.cgColor
    view1.identifier = NSUserInterfaceItemIdentifier("view1")
    window.contentView?.addSubview(view1)

    let view2 = NSView(frame: CGRect(x: 100, y: 100, width: 300, height: 200))
    view2.wantsLayer = true
    view2.layer?.backgroundColor = NSColor.blue.cgColor
    view2.identifier = NSUserInterfaceItemIdentifier("view2")
    window.contentView?.addSubview(view2)

    // 为视图添加点击置顶功能
    view1.addClickToFront()
    view2.addClickToFront()

    print("✅ 测试创建成功: 两个重叠视图，红色在下层，蓝色在上层")
    print("点击任意视图应该能将其置于最上层")
    print("注意：蓝色视图初始在最上层，点击红色视图会将红色置于最上层")

    // 显示窗口
    window.makeKeyAndOrderFront(nil)

    print("\n=== 测试完成 ===")
}
#endif