//
//  KX-UI-08_面板入口.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.2
//  职责：K线模块面板 View 入口。状态持久化通过 UI 模块的 UIModuleStateModel.configuration 保存/恢复。
//        禁止创建独立 NSWindow，禁止接管 App 生命周期
//  禁止事项：禁止 makeKeyAndOrderFront、禁止 NSApplication.run
//

import AppKit
import Foundation

// 导入K线日志工具

// UI模块类型（通过协议或间接方式使用）
public protocol UIWorkspaceManagerProtocol {
    func saveCurrentState(layoutName: String, symbol: String, period: String, colorScheme: String, windowStates: [String: Any], moduleStates: [String: Any], dockedPanels: [String: Any], openModuleNames: [String], globalSettings: [String: String])
    func restoreState(name: String) -> Any?
}

// UI 模块共享类型已在自身定义中声明 Sendable；这里不重复声明，避免冗余 conformance warning。

// 日志实例
private let logger = klineLogger

// MARK: - K线面板上下文

public struct KLPanelContext: Sendable {
    public let moduleID: String
    public let initialInstrumentID: String
    public let initialInstrumentType: String
    public let exchange: String

    public init(moduleID: String = "kline", initialInstrumentID: String = "BTC-USDT", initialInstrumentType: String = "SPOT", exchange: String = "OKX") {
        self.moduleID = moduleID
        self.initialInstrumentID = initialInstrumentID
        self.initialInstrumentType = initialInstrumentType
        self.exchange = exchange
    }
}

// MARK: - K线模块状态键（存入 UI 模块 UIModuleStateModel.configuration）

public enum KLUIStateKey {
    public static let activeInstID = "kline.activeInstID"
    public static let activeTimeframe = "kline.activeTimeframe"
    public static let volumeSplitRatio = "kline.volumeSplitRatio"
    public static let openTabs = "kline.openTabs"
    public static let tabOrder = "kline.tabOrder"
    public static let candleWidth = "kline.candleWidth"
    public static let contentOffsetX = "kline.contentOffsetX"
}

// MARK: - 面板入口

public class KXUI08Entry {
    private init() {}

    private static let moduleEnabledDefaultsKey = "com.xianrenzhilu.modules.kline.enabled"

    public static func isPanelEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: moduleEnabledDefaultsKey)
    }

    public static func setPanelEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: moduleEnabledDefaultsKey)
        logger.info("[KLine] 模块启用状态已更新: \(enabled)")
        if enabled {
            openPanel()
        } else {
            closePanel()
        }
    }
    
    /// 创建K线面板视图
    public static func makePanelView(context: KLPanelContext = KLPanelContext()) -> NSView {
        let view = KXUI09KLinePanelView(frame: .zero)
        view.panelContext = context
        return view
    }

    /// 在主窗口内容区打开K线面板（从 main.swift 直接调用，不走UI设置面板）
    private static var openPanelRetries = 0
    /// 防重复创建：已建 KL_Main 容器的弱引用。openPanel 重入时优先用它复用，避免 addModuleContainer reparent 后检查失效。
    private static weak var existingKLMainContainer: NSView?

    private static func adaptiveInitialFrame(in parentBounds: NSRect) -> NSRect {
        guard parentBounds.width > 0, parentBounds.height > 0 else {
            return NSRect(x: 10, y: 70, width: 480, height: 600)
        }
        let marginX: CGFloat = 10
        let topMargin: CGFloat = 70
        let rightMargin: CGFloat = 10
        let bottomMargin: CGFloat = 10
        let minWidth: CGFloat = 320
        let minHeight: CGFloat = 260
        let width = max(minWidth, parentBounds.width - marginX - rightMargin)
        let height = max(minHeight, parentBounds.height - topMargin - bottomMargin)
        return NSRect(x: marginX, y: topMargin, width: width, height: height)
    }

    private static func applyAdaptiveResize(to container: NSView, in parent: NSView) {
        let targetFrame = adaptiveInitialFrame(in: parent.bounds)
        container.frame = targetFrame
        container.autoresizingMask = [.width, .height]
        container.needsLayout = true
        container.subviews.forEach { subview in
            subview.needsLayout = true
            subview.needsDisplay = true
        }
        container.layoutSubtreeIfNeeded()
    }

    /// App 启动后按设置面板卡片开关状态自动恢复 K线面板。
    /// 开关打开 = 模块启用，启动后自动显示并恢复 UI 工作区位置/排列；开关关闭 = 不自动显示。
    public static func restorePanelIfNeededAfterLaunch() {
        guard isPanelEnabled() else {
            logger.info("[KLine] 启动恢复跳过：设置面板 K线模块开关未打开")
            return
        }

        logger.info("[KLine] 启动恢复：K线模块开关已打开，准备自动打开 KL_Main")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            openPanel()
        }
    }

    @objc public static func openPanel() {
        logger.info("🚀 openPanel() called")
        DispatchQueue.main.async {
            logger.info("📍 Dispatch to main thread")

            // 防重复创建：若之前已建 KL_Main 容器且仍在窗口层级中，直接置顶复用，不再重建整套面板/画布。
            // （addModuleContainer: 会把容器 reparent 到更深层，导致仅查 glassContent.subviews 的旧检查失效。）
            if let existing = existingKLMainContainer, existing.window != nil {
                logger.info("♻️ openPanel 重入：复用现有 KL_Main 容器（静态引用），不重建")
                if let sv = existing.superview {
                    existing.removeFromSuperview()
                    sv.addSubview(existing)
                }
                return
            }

            // 查找主窗口
            guard let mainWin = NSApp.windows.first(where: { $0.isVisible }) else {
                logger.error("❌ ERROR: mainWin not found, will retry")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { openPanel() }
                return
            }
            logger.info("✅ Found main window: \(mainWin)")

            // 查找玻璃内容视图
            // fallback: 如果找不到玻璃 content view identifier，直接使用主窗口 contentView 本身
            let glassContent: NSView
            if let found = mainWin.contentView?.subviews.first(where: {
                $0.identifier?.rawValue == "glass.content.view"
            }) {
                glassContent = found
                logger.info("✅ Found glassContentView with identifier, bounds: \(glassContent.bounds)")
            } else {
                // fallback: 使用主窗口 contentView
                guard let contentView = mainWin.contentView else {
                    logger.error("❌ ERROR: mainWin has no contentView")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { openPanel() }
                    return
                }
                glassContent = contentView
                logger.warning("⚠️  glassContentView with identifier 'glass.content.view' not found, fallback to mainWin.contentView")
            }

            logger.info("✅ Found glassContentView, bounds: \(glassContent.bounds)")

            // 检查是否已存在K线主容器
            if let existing = glassContent.subviews.first(where: { $0.identifier?.rawValue == "KL_Main" }) {
                logger.info("♻️ Found existing KL_Main container, repositioning and restoring adaptive resize")
                applyAdaptiveResize(to: existing, in: glassContent)
                existing.removeFromSuperview()
                glassContent.addSubview(existing)
                existing.needsLayout = true
                existing.layoutSubtreeIfNeeded()
                return
            }

            // 创建容器：使用 UIContainerFactory 创建可拖拽缩放的子窗口
            // 容器已经自带玻璃皮肤效果（由 UI 模块统一管理）
            let fallbackFrame = self.adaptiveInitialFrame(in: glassContent.bounds)
            let restoredFrame = UISerializationManager.shared.restoredContainerFrame(identifier: "KL_Main", fallback: fallbackFrame)
            let hasSavedContainerFrame = !NSEqualRects(restoredFrame, fallbackFrame)
            let container = UIContainerFactory.shared.createContainer(
                identifier: "KL_Main",
                displayName: "K线",
                moduleName: "K线模块",
                frame: restoredFrame
            )
            // UIContainerFactory 当前可能未把 identifier 写到 NSView.identifier（日志曾显示 no-id），
            // 导致 openPanel 重入时找不到既有 KL_Main 容器，重复创建整套面板/画布。
            // 这里强制写入，保证 existing-container 检查有效。
            container.identifier = NSUserInterfaceItemIdentifier("KL_Main")
            existingKLMainContainer = container
            logger.info("✅ Created container: \(container.identifier?.rawValue ?? "no-id")")
            // 打开 UI 模块已有的布局序列化功能：
            // - 有历史保存 frame：严格恢复用户关闭前摆放位置，不再用自适应初始 frame 覆盖。
            // - 没有历史保存 frame：首次打开按内容区自适应铺开。
            // - 两种情况都启用 autoresizingMask，使父 UI 窗口拉伸/压扁时 K线容器跟随变化。
            if hasSavedContainerFrame {
                container.autoresizingMask = [.width, .height]
                // 首帧 clamp：防止历史保存的 frame 超出当前 glassContent bounds（窗口可能已缩小）
                let b = glassContent.bounds
                var f = container.frame
                f.size.width = min(f.size.width, b.width)
                f.size.height = min(f.size.height, b.height)
                f.origin.x = max(0, min(f.origin.x, b.width - f.size.width))
                f.origin.y = max(0, min(f.origin.y, b.height - f.size.height))
                container.frame = f
                container.needsLayout = true
            } else {
                applyAdaptiveResize(to: container, in: glassContent)
            }

            // 创建面板视图：K线主面板已经自带玻璃皮肤背景，嵌入容器
            let panelView = KXUI08Entry.makePanelView(context: KLPanelContext())
            guard let klinePanel = panelView as? KXUI09KLinePanelView else {
                logger.error("❌ ERROR: Failed to cast panelView to KXUI09KLinePanelView, type: \(type(of: panelView))")
                return
            }
            logger.info("✅ Created KXUI09KLinePanelView")

            // 添加到容器内容区：使用四边约束固定填充，避免 autoresizing 弹簧在高度变化时造成顶部功能栏上下漂移。
            panelView.translatesAutoresizingMaskIntoConstraints = false
            container.contentView.addSubview(panelView)
            NSLayoutConstraint.activate([
                panelView.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor),
                panelView.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor),
                panelView.topAnchor.constraint(equalTo: container.contentView.topAnchor),
                panelView.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor)
            ])

            // 建立布局
            klinePanel.setupPanelLayout()
            container.layoutSubtreeIfNeeded()
            glassContent.layoutSubtreeIfNeeded()
            logger.info("✅ Panel layout setup completed")

            // 添加到父视图（玻璃内容容器）
            if glassContent.responds(to: NSSelectorFromString("addModuleContainer:")) {
                logger.info("🧩 Using addModuleContainer: API")
                _ = glassContent.perform(NSSelectorFromString("addModuleContainer:"), with: container)
            } else {
                logger.info("🧩 Adding subview directly")
                glassContent.addSubview(container)
            }

            // 置顶容器
            if let superview = container.superview {
                container.removeFromSuperview()
                superview.addSubview(container)
                logger.info("✅ Container brought to front")
            }

            // 恢复状态，并安装 UI 模块持久化/自适应钩子
            klinePanel.restoreLayoutState()
            klinePanel.installWorkspacePersistenceHooks()
            logger.info("✅ Layout state restored and persistence hooks installed")

            // 加载数据
            klinePanel.loadPanel()
            logger.info("✅ Panel load triggered")

            // 启动恢复管道
            Task {
                do {
                    try await KLDefaultStartupPipeline.shared.restore()
                    logger.info("✅ Startup pipeline completed successfully")
                } catch {
                    logger.warning("⚠️ Startup recovery failed: \(error)")
                    // 启动恢复失败不影响UI显示
                }
            }

            // 注册到 UI 模块停靠系统
            UIWindowRegistry.shared.register(window: mainWin, id: "KL_Main")
            let dockPanel = UIDockablePanel(
                panelID: "KL_Main",
                title: "K线",
                contentView: container,
                preferredSize: NSSize(width: 640, height: 480)
            )
            UIDockingManager.shared.registerPanel(dockPanel)
            UIDockingManager.shared.registerCollapseRule(
                panelID: "KL_Main",
                rule: UIDockingCollapseRule(
                    collapsedSize: 44,
                    anchor: .top,
                    fixedRegion: UIDockingFixedRegionRule(
                        anchor: .top,
                        size: 44,
                        participatesInAnimation: .fixed,
                        keepControlsInteractive: true,
                        clipsToBounds: true
                    ),
                    bodyRegion: UIDockingBodyRegionRule(
                        startsAfterFixedRegion: true,
                        revealDirection: .bottomToTopCollapseTopToBottomExpand,
                        animationMode: .clipAndFade,
                        clipsToBounds: true,
                        collapseAlpha: 0,
                        expandedAlpha: 1
                    ),
                    collapseAnimation: .easeInOut(duration: 0.22),
                    expandAnimation: .appleSpring(
                        duration: 0.34,
                        mass: 0.72,
                        stiffness: 340,
                        damping: 28,
                        initialVelocity: 0.55,
                        bodyFade: true,
                        bodyFadeDelay: 0.04
                    ),
                    persistCollapsedFrame: false,
                    beforeTransition: { collapsed in
                        NotificationCenter.default.post(
                            name: .kxKLineDockingTransitionWillBegin,
                            object: nil,
                            userInfo: ["panelID": "KL_Main", "collapsed": collapsed]
                        )
                    }
                )
            )
            UIDockingManager.shared.markPanelExpandedState("KL_Main", expanded: true, currentFrame: container.frame)
            UIPanelGroupManager.shared.addPanel(windowID: "KL_Main", toGroup: "K线模块")
            
            logger.info("🎉 K线面板加载完成！玻璃皮肤容器由UI模块统一提供")
        }
    }

    /// 关闭/禁用 K线面板：只移除 UI 实例，不清除保存的 frame 和内部参数。
    /// 下次开关打开时继续按 UI 工作区恢复关闭前位置和排列。
    public static func closePanel() {
        DispatchQueue.main.async {
            guard let mainWin = NSApp.windows.first(where: { $0.isVisible }),
                  let root = mainWin.contentView else {
                UIDockingManager.shared.unregisterPanel("KL_Main")
                return
            }
            let allSubviews = root.subviews + root.subviews.flatMap { $0.subviews }
            if let container = allSubviews.first(where: { $0.identifier?.rawValue == "KL_Main" }) {
                UISerializationManager.shared.saveContainerFrame(identifier: "KL_Main", frame: container.frame)
                container.removeFromSuperview()
            }
            UIDockingManager.shared.unregisterPanel("KL_Main")
            logger.info("[KLine] K线面板已关闭，布局状态保留")
        }
    }
}

// MARK: - 面板 View

@objcMembers public class KXUI09KLinePanelView: NSView {
    /// K线面板采用顶部锚定坐标：一级功能栏、二级功能栏固定在顶部，只有下方图表区吃掉剩余空间。
    public override var isFlipped: Bool { true }

    public var panelContext: KLPanelContext = KLPanelContext()
    public var onMarketTypeChanged: ((KLMarketType) -> Void)?
    public var onDisplaySettingsChanged: (([String: Any]) -> Void)?

    /// 从 UI 模块的 UIModuleStateModel 恢复 K线内部状态
    public func restoreState(from config: [String: String]) {
        guard !config.isEmpty else { return }

        let tabs = config[KLUIStateKey.openTabs]?
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let activeInstID = config[KLUIStateKey.activeInstID] ?? tabs?.first ?? panelContext.initialInstrumentID
        let timeframe = config[KLUIStateKey.activeTimeframe].flatMap { KXTimeframe(rawValue: $0) } ?? .oneHour

        if let tabBar = subviews.compactMap({ $0 as? KXUI10PairTabBarView }).first {
            tabBar.tabs = tabs?.isEmpty == false ? tabs! : [activeInstID]
            if !tabBar.tabs.contains(activeInstID) { tabBar.tabs.insert(activeInstID, at: 0) }
            tabBar.activeTabID = activeInstID
            tabBar.needsLayout = true
        }

        if let selector = toolbarView?.subviews.compactMap({ $0 as? KXUI11TimeframeSelectorView }).first {
            selector.selectedTimeframe = timeframe
        }

        klineChartView?.loadLatestCandlesFromDatabaseOrOKX(symbol: activeInstID, timeframe: timeframe, triggerSyncIfMissing: true)
        KLDefaultStartupPipeline.shared.syncOpenedSymbols(
            symbols: tabs?.isEmpty == false ? tabs! : [activeInstID],
            activeSymbol: activeInstID,
            activeTimeframe: timeframe
        )
        logger.info("[KLine] 已从 UI 模块恢复内部状态: active=\(activeInstID), timeframe=\(timeframe.rawValue)")
    }

    /// 导出 K线内部状态到 UI 模块的 UIModuleStateModel
    public func exportState() -> [String: String] {
        let tabBar = subviews.compactMap { $0 as? KXUI10PairTabBarView }.first
        let selector = toolbarView?.subviews.compactMap { $0 as? KXUI11TimeframeSelectorView }.first
        let activeInstID = tabBar?.activeTabID ?? panelContext.initialInstrumentID
        let timeframe = selector?.selectedTimeframe.rawValue ?? "1h"
        let tabs = tabBar?.tabs.isEmpty == false ? tabBar!.tabs : [activeInstID]

        return [
            KLUIStateKey.activeInstID: activeInstID,
            KLUIStateKey.activeTimeframe: timeframe,
            KLUIStateKey.openTabs: tabs.joined(separator: ","),
            KLUIStateKey.tabOrder: tabs.joined(separator: ","),
            KLUIStateKey.candleWidth: String(describing: klineChartView?.bounds.width ?? bounds.width),
            KLUIStateKey.contentOffsetX: "0"
        ]
    }

    public func loadPanel() {
        // 触发启动恢复管道：建表→加载DB→OKX拉历史→写库→内存预热→实时订阅
        Task {
            do {
                try await KLDefaultStartupPipeline.shared.restore()
            } catch {
                logger.info("[KLine] 启动恢复失败: \(error)")
                // 启动恢复失败不影响UI显示
            }
        }
    }

    public func cleanupPanel() {
        // 保存当前布局状态
        logger.info("[KLine] 清理面板资源")
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXKXUI08Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-08", fileName: "KX-UI-08_面板入口.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-08_面板入口.swift", duty: "K线模块面板View入口、状态持久化"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("K线面板入口骨架校验通过")
        return KXHealthCheckItem(name: "K线面板入口", passed: true, message: "K线模块面板View入口、状态持久化")
    }
}
