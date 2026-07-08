//
//  KX-UI-06_工作区数据适配.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：为工作区保存恢复提供 K线面板状态数据适配
//  禁止事项：禁止 UI 绘制、禁止网络请求、禁止数据库读写、禁止缓存实现
//

import Foundation


// MARK: - 工作区面板状态快照

public struct KXUI06PaneStateSnapshot: Codable, Equatable, Sendable {
    public let paneID: String
    public let symbol: KXSymbol?
    public let timeframe: KXTimeframe?
    public let row: Int
    public let column: Int
    public let rowSpan: Int
    public let columnSpan: Int
    public let indicatorIDs: [String]
    public let drawingData: Data?
    public let markerIDs: [String]

    public init(paneID: String, symbol: KXSymbol? = nil, timeframe: KXTimeframe? = nil, row: Int = 0, column: Int = 0, rowSpan: Int = 1, columnSpan: Int = 1, indicatorIDs: [String] = [], drawingData: Data? = nil, markerIDs: [String] = []) {
        self.paneID = paneID
        self.symbol = symbol
        self.timeframe = timeframe
        self.row = row
        self.column = column
        self.rowSpan = rowSpan
        self.columnSpan = columnSpan
        self.indicatorIDs = indicatorIDs
        self.drawingData = drawingData
        self.markerIDs = markerIDs
    }
}

// MARK: - 工作区完整快照

public struct KXUI06WorkspaceSnapshot: Codable, Equatable, Sendable {
    public let workspaceID: String
    public let name: String
    public let panes: [KXUI06PaneStateSnapshot]
    public let openTabSymbols: [KXSymbol]
    public let activeSymbol: KXSymbol?
    public let activeTimeframe: KXTimeframe?
    public let selectedIndicatorComboID: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(workspaceID: String, name: String, panes: [KXUI06PaneStateSnapshot] = [], openTabSymbols: [KXSymbol] = [], activeSymbol: KXSymbol? = nil, activeTimeframe: KXTimeframe? = nil, selectedIndicatorComboID: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.workspaceID = workspaceID
        self.name = name
        self.panes = panes
        self.openTabSymbols = openTabSymbols
        self.activeSymbol = activeSymbol
        self.activeTimeframe = activeTimeframe
        self.selectedIndicatorComboID = selectedIndicatorComboID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 工作区状态差异描述

public struct KXUI06WorkspaceDiff: Codable, Equatable, Sendable {
    public let nameChanged: Bool
    public let paneCountChanged: Bool
    public let activeSymbolChanged: Bool
    public let activeTimeframeChanged: Bool
    public let addedPaneIDs: [String]
    public let removedPaneIDs: [String]
    public let changedPaneIDs: [String]
    public let description: String

    public init(nameChanged: Bool = false, paneCountChanged: Bool = false, activeSymbolChanged: Bool = false, activeTimeframeChanged: Bool = false, addedPaneIDs: [String] = [], removedPaneIDs: [String] = [], changedPaneIDs: [String] = [], description: String = "") {
        self.nameChanged = nameChanged
        self.paneCountChanged = paneCountChanged
        self.activeSymbolChanged = activeSymbolChanged
        self.activeTimeframeChanged = activeTimeframeChanged
        self.addedPaneIDs = addedPaneIDs
        self.removedPaneIDs = removedPaneIDs
        self.changedPaneIDs = changedPaneIDs
        self.description = description
    }
}

// MARK: - 工作区数据适配器

public enum KXUI06WorkspaceDataAdapter {
    /// 从 KLLayoutTemplateDescriptor + 活动状态生成快照
    public static func makeSnapshot(template: KLLayoutTemplateDescriptor, openTabs: [KXSymbol] = [], activeSymbol: KXSymbol? = nil, activeTimeframe: KXTimeframe? = nil, activeIndicatorComboID: String? = nil) -> KXUI06WorkspaceSnapshot {
        let panes = template.paneDescriptors.map { pane in
            KXUI06PaneStateSnapshot(paneID: pane.id, symbol: pane.symbol, timeframe: pane.timeframe, row: pane.row, column: pane.column, rowSpan: pane.rowSpan, columnSpan: pane.columnSpan)
        }
        return KXUI06WorkspaceSnapshot(workspaceID: template.id, name: template.name, panes: panes, openTabSymbols: openTabs, activeSymbol: activeSymbol, activeTimeframe: activeTimeframe, selectedIndicatorComboID: activeIndicatorComboID)
    }

    /// 从快照构建 KLLayoutTemplateDescriptor
    public static func makeTemplateDescriptor(from snapshot: KXUI06WorkspaceSnapshot) -> KLLayoutTemplateDescriptor {
        let paneDescs = snapshot.panes.map { pane -> KLLayoutPaneDescriptor in
            KLLayoutPaneDescriptor(id: pane.paneID, symbol: pane.symbol, timeframe: pane.timeframe, row: pane.row, column: pane.column, rowSpan: pane.rowSpan, columnSpan: pane.columnSpan)
        }
        return KLLayoutTemplateDescriptor(id: snapshot.workspaceID, name: snapshot.name, columnCount: max(snapshot.panes.map(\.column).max() ?? 0, 1), rowCount: max(snapshot.panes.map(\.row).max() ?? 0, 1), paneDescriptors: paneDescs)
    }

    /// 比较两个快照，返回差异
    public static func diff(from old: KXUI06WorkspaceSnapshot, to new: KXUI06WorkspaceSnapshot) -> KXUI06WorkspaceDiff {
        let oldIDs = Set(old.panes.map(\.paneID))
        let newIDs = Set(new.panes.map(\.paneID))
        let added = newIDs.subtracting(oldIDs).sorted()
        let removed = oldIDs.subtracting(newIDs).sorted()
        let common = oldIDs.intersection(newIDs)
        let changed = common.filter { id in
            let oldPane = old.panes.first { $0.paneID == id }
            let newPane = new.panes.first { $0.paneID == id }
            return oldPane != newPane
        }.sorted()
        return KXUI06WorkspaceDiff(nameChanged: old.name != new.name, paneCountChanged: old.panes.count != new.panes.count, activeSymbolChanged: old.activeSymbol != new.activeSymbol, activeTimeframeChanged: old.activeTimeframe != new.activeTimeframe, addedPaneIDs: added, removedPaneIDs: removed, changedPaneIDs: changed, description: "工作区 \(new.name)：新增\(added.count)面板、移除\(removed.count)面板、变更\(changed.count)面板")
    }

    /// 更新快照指定字段
    public static func updateSnapshot(_ snapshot: KXUI06WorkspaceSnapshot, name: String? = nil, panes: [KXUI06PaneStateSnapshot]? = nil, activeSymbol: KXSymbol? = nil, activeTimeframe: KXTimeframe? = nil, selectedIndicatorComboID: String? = nil) -> KXUI06WorkspaceSnapshot {
        KXUI06WorkspaceSnapshot(workspaceID: snapshot.workspaceID, name: name ?? snapshot.name, panes: panes ?? snapshot.panes, openTabSymbols: snapshot.openTabSymbols, activeSymbol: activeSymbol ?? snapshot.activeSymbol, activeTimeframe: activeTimeframe ?? snapshot.activeTimeframe, selectedIndicatorComboID: selectedIndicatorComboID ?? snapshot.selectedIndicatorComboID, createdAt: snapshot.createdAt, updatedAt: Date())
    }

    /// 序列化快照为 JSON Data
    public static func serialize(_ snapshot: KXUI06WorkspaceSnapshot) -> Data? { try? JSONEncoder().encode(snapshot) }

    /// 从 JSON Data 反序列化快照
    public static func deserialize(from data: Data) -> KXUI06WorkspaceSnapshot? { try? JSONDecoder().decode(KXUI06WorkspaceSnapshot.self, from: data) }
}

// MARK: - KXFileSkeletonProtocol

public enum KXKXUI06Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-06", fileName: "KX-UI-06_工作区数据适配.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-06_工作区数据适配.swift", duty: "工作区数据适配"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("工作区数据适配骨架校验通过")
        return KXHealthCheckItem(name: "工作区数据适配", passed: true, message: "工作区数据适配")
    }
}
