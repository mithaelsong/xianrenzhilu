//
//  KX-UI-00_UI层入口.swift
//  仙人指路2-min｜K线模块｜UI层
//
//  版本：2.0
//  职责：K线模块 UI 层统一入口
//        注册面板到 UI 模块的窗口注册表 + 停靠系统 + 面板分组
//        关掉这三个接口即可脱离 UI 模块，只对接框架模块
//  依赖：管理层 KX-GL-01（入口，注册表，公共类型）
//        UI 模块（UIPanelManager, UIWindowRegistry, UIDockingManager, UIPanelGroupManager）
//

import AppKit
import Foundation

/// K线窗口管理器 — UI 层唯一外部入口
public enum KXWindowManager {
    public static let version = "2.0"
    public static var containerView: UIContainerView?
    private static var didStartCollectionAutomation = false

    /// 在 UI 主窗口的内容容器（GlassContentView）内显示K线面板
    public static func showKlinePanel() {
        if !didStartCollectionAutomation {
            didStartCollectionAutomation = true
            Task { try? await KLDefaultStartupPipeline.shared.restore() }
        }
        DispatchQueue.main.async {
            // 如果已创建，前置
            if let existing = containerView, existing.superview != nil { return }

            guard let mainWin = NSApp.windows.first(where: { $0.isVisible }) else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showKlinePanel() }
                return
            }
            guard let glassContent = mainWin.contentView?.subviews.first(where: {
                $0.identifier?.rawValue == "glass.content.view"
            }) else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showKlinePanel() }
                return
            }

            // 用 UIContainerView 创建可拖拽缩放的子窗口。
            // 注意：K线模块泡在 GlassContentView 上，必须随 UI 内容区自适应。
            // 初始 frame 按内容区 bounds 计算，避免写死尺寸导致主 UI 拉伸/缩小时不同步。
            let initialFrame = adaptiveInitialFrame(in: glassContent.bounds)
            let container = UIContainerFactory.shared.createContainer(
                identifier: "KL_Main",
                displayName: "K线",
                moduleName: "K线模块",
                frame: initialFrame
            )
            let panel = KXUI09KLinePanelView(frame: container.bounds)
            panel.autoresizingMask = [.width, .height]
            container.contentView.addSubview(panel)

            // 恢复保存的布局状态
            // panel.restoreLayoutState() // 持久化功能已回滚

            // 添加到内容视图：由 UI 内容区统一打开子窗口自适应规则。
            if glassContent.responds(to: NSSelectorFromString("addModuleContainer:")) {
                _ = glassContent.perform(NSSelectorFromString("addModuleContainer:"), with: container)
            } else {
                glassContent.addSubview(container)
            }
            containerView = container

            // 置顶K线面板容器
            if let superview = container.superview {
                container.removeFromSuperview()
                superview.addSubview(container)
            }

            // 注册到 UI 模块管理系统（可选，关掉即可脱离 UI 模块）
            UIWindowRegistry.shared.register(window: mainWin, id: "KL_Main")
            let dockPanel = UIDockablePanel(
                panelID: "KL_Main",
                title: "K线",
                contentView: container,
                preferredSize: NSSize(width: 640, height: 480)
            )
            UIDockingManager.shared.registerPanel(dockPanel)
            UIPanelGroupManager.shared.addPanel(windowID: "KL_Main", toGroup: "K线模块")
            
            klineLogger.info("🎉 K线面板加载完成！玻璃皮肤容器由UI模块统一提供")
        }
    }

    private static func adaptiveInitialFrame(in parentBounds: NSRect) -> NSRect {
        guard parentBounds.width > 0, parentBounds.height > 0 else {
            return NSRect(x: 10, y: 70, width: 640, height: 480)
        }

        // GlassContentView 是 flipped 坐标：x/y 表示左上起始位置。
        // 保留 UI 内容区边距，让模块像正常子窗口一样随父内容区宽高自适应。
        let marginX: CGFloat = 10
        let topMargin: CGFloat = 70
        let rightMargin: CGFloat = 10
        let bottomMargin: CGFloat = 10
        let minWidth: CGFloat = 480
        let minHeight: CGFloat = 320

        let width = max(minWidth, parentBounds.width - marginX - rightMargin)
        let height = max(minHeight, parentBounds.height - topMargin - bottomMargin)
        return NSRect(x: marginX, y: topMargin, width: width, height: height)
    }

    /// 关闭K线面板
    public static func closeKlinePanel() {
        UIDockingManager.shared.unregisterPanel("KL_Main")
        containerView?.removeFromSuperview()
        containerView = nil
    }
}
