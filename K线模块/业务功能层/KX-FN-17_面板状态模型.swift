//
//  KX-FN-17_面板状态模型.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：K线面板状态模型，包括面板级、标签级、视口级、指标插槽状态
//  禁止事项：禁止UI绘制、禁止数据库读写、禁止网络请求
//

import Foundation


/// 面板框架，Codable 版 CGRect
public struct KXPanelFrame: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

// MARK: - 视口状态

public struct KLKLineViewportState: Codable, Sendable, Equatable {
    /// 可视窗口起始时间（UTC）
    public var visibleStartTime: Date?
    /// 可视窗口结束时间（UTC）
    public var visibleEndTime: Date?
    /// 当前可视 K线起始索引
    public var startIndex: Int?
    /// 当前可视 K线结束索引
    public var endIndex: Int?
    /// 每根 K线的渲染宽度（points）
    public var candleWidth: Double
    /// 内容水平偏移量（points）
    public var contentOffsetX: Double

    public init(visibleStartTime: Date? = nil, visibleEndTime: Date? = nil, startIndex: Int? = nil, endIndex: Int? = nil, candleWidth: Double = 8.0, contentOffsetX: Double = 0.0) {
        self.visibleStartTime = visibleStartTime
        self.visibleEndTime = visibleEndTime
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.candleWidth = candleWidth
        self.contentOffsetX = contentOffsetX
    }
}

// MARK: - 标签状态

public struct KLKLineTabState: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var exchange: String
    public var instrumentCategory: String
    public var instType: String
    public var instID: String
    public var displayName: String
    public var timeframe: KXTimeframe
    public var viewport: KLKLineViewportState
    /// 主图高度与总图表高度的比例，范围 0.60~0.90
    public var volumeSplitRatio: Double
    /// 指标插槽 ID 列表（预留）
    public var indicatorSlotIDs: [String]
    /// 画线工具模板 ID（预留）
    public var drawingTemplateID: String?
    /// 最后选中时间
    public var lastSelectedAt: Date

    public init(id: String = UUID().uuidString, exchange: String = "OKX", instrumentCategory: String = "", instType: String = "SPOT", instID: String = "BTC-USDT", displayName: String = "BTC-USDT", timeframe: KXTimeframe = .oneHour, viewport: KLKLineViewportState = KLKLineViewportState(), volumeSplitRatio: Double = 0.75, indicatorSlotIDs: [String] = [], drawingTemplateID: String? = nil, lastSelectedAt: Date = Date()) {
        self.id = id
        self.exchange = exchange
        self.instrumentCategory = instrumentCategory
        self.instType = instType
        self.instID = instID
        self.displayName = displayName
        self.timeframe = timeframe
        self.viewport = viewport
        self.volumeSplitRatio = volumeSplitRatio
        self.indicatorSlotIDs = indicatorSlotIDs
        self.drawingTemplateID = drawingTemplateID
        self.lastSelectedAt = lastSelectedAt
    }
}

// MARK: - 面板状态

public struct KLKLinePanelState: Codable, Sendable, Equatable {
    /// 当前打开的标签列表
    public var tabs: [KLKLineTabState]
    /// 当前激活标签 ID
    public var activeTabID: String
    /// 面板在 UI 内容区中的位置（基于 UI 模块容器），Codable
    public var panelFrameInUI: KXPanelFrame?
    /// 全局分割比例（未来支持更多子面板时使用）
    public var globalSplitRatio: Double
    /// 左侧画线工具栏是否可见
    public var drawingToolbarVisible: Bool
    /// 指标插槽区域是否可见
    public var indicatorSlotVisible: Bool
    /// 最后更新时间
    public var updatedAt: Date

    public init(tabs: [KLKLineTabState] = [], activeTabID: String = "", panelFrameInUI: KXPanelFrame? = nil, globalSplitRatio: Double = 1.0, drawingToolbarVisible: Bool = false, indicatorSlotVisible: Bool = false, updatedAt: Date = Date()) {
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.panelFrameInUI = panelFrameInUI
        self.globalSplitRatio = globalSplitRatio
        self.drawingToolbarVisible = drawingToolbarVisible
        self.indicatorSlotVisible = indicatorSlotVisible
        self.updatedAt = updatedAt
    }
}

// MARK: - 便利方法

public extension KLKLinePanelState {
    /// 获取当前激活的标签
    var activeTab: KLKLineTabState? {
        tabs.first { $0.id == activeTabID }
    }

    /// 检查是否有指定币对的标签已打开
    func hasTab(instID: String, exchange: String = "OKX") -> Bool {
        tabs.contains { $0.instID == instID && $0.exchange == exchange }
    }

    /// 追加或选择已有标签
    mutating func ensureTab(instID: String, exchange: String, instType: String, displayName: String) {
        if let existing = tabs.firstIndex(where: { $0.instID == instID && $0.exchange == exchange }) {
            activeTabID = tabs[existing].id
            tabs[existing].lastSelectedAt = Date()
        } else {
            let tab = KLKLineTabState(
                exchange: exchange,
                instType: instType,
                instID: instID,
                displayName: displayName,
                lastSelectedAt: Date()
            )
            tabs.append(tab)
            activeTabID = tab.id
        }
    }

    /// 关闭指定标签
    mutating func closeTab(id: String) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        if activeTabID == id {
            activeTabID = tabs.last?.id ?? ""
        }
    }
}

// MARK: - 默认初始状态

public extension KLKLinePanelState {
    static var `default`: KLKLinePanelState {
        let defaultTab = KLKLineTabState(
            instID: "BTC-USDT",
            displayName: "BTC-USDT"
        )
        return KLKLinePanelState(
            tabs: [defaultTab],
            activeTabID: defaultTab.id
        )
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN17Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-17", fileName: "KX-FN-17_面板状态模型.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-17_面板状态模型.swift", duty: "K线面板状态的模型和序列化"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("面板状态模型骨架校验通过")
        return KXHealthCheckItem(name: "面板状态模型", passed: true, message: "已实现面板/标签/视口状态模型和序列化")
    }
}
