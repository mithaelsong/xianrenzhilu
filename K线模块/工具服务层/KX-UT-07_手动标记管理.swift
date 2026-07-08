//
//  KX-UT-07_手动标记管理.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：用户手动标记的新增、删除、更新服务骨架
//  禁止事项：禁止 UI 绘制、禁止数据库读写、禁止网络请求
//

import Foundation

@MainActor


// MARK: - 用户手动标记管理骨架

public enum KXUT07Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UT-07",
        fileName: "KX-UT-07_用户手动标记管理.swift",
        layer: .marker,
        relativePath: "标记层/KX-UT-07_用户手动标记管理.swift",
        duty: "用户手动标记的新增、删除、更新纯服务逻辑"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "用户手动标记管理", passed: true, message: "已实现纯服务逻辑：新增、删除、更新、查询、过滤、排序、撤销、重做")
    }

    public static func placeholder() {
        // 本文件只提供纯计算服务：输入标记数组/状态，返回新数组/操作结果。
        // 不读写数据库，不请求网络，不绘制 UI。
    }
}

// MARK: - 用户手动标记操作模型

public enum KXUT07ManualMarkerOperationKind: String, Codable, Sendable, CaseIterable {
    case add
    case remove
    case update
    case toggle
    case batchRemove
    case undo
    case reapply
    case none
}

public enum KXUT07ManualMarkerSortField: String, Codable, Sendable, CaseIterable {
    case id
    case title
    case createdAt
    case time
    case index
    case price
    case severity
}

public struct KXUT07ManualMarkerFilter: Codable, Equatable, Sendable {
    public let symbol: KXSymbol?
    public let timeframe: KXTimeframe?
    public let window: KLVisibleWindow?
    public let includeOnlyUserManualMarkers: Bool

    public init(symbol: KXSymbol? = nil, timeframe: KXTimeframe? = nil, window: KLVisibleWindow? = nil, includeOnlyUserManualMarkers: Bool = true) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.window = window
        self.includeOnlyUserManualMarkers = includeOnlyUserManualMarkers
    }
}

public struct KXUT07ManualMarkerSortRule: Codable, Equatable, Sendable {
    public let field: KXUT07ManualMarkerSortField
    public let order: KLQuerySortOrder

    public init(field: KXUT07ManualMarkerSortField = .createdAt, order: KLQuerySortOrder = .ascending) {
        self.field = field
        self.order = order
    }
}

public struct KXUT07ManualMarkerUpdate: Codable, Equatable, Sendable {
    public let id: String
    public let title: String?
    public let message: String?
    public let coordinate: KLChartCoordinate?
    public let severity: KLMarkerSeverity?
    public let style: KLMarkerStyleDescriptor?

    public init(id: String, title: String? = nil, message: String? = nil, coordinate: KLChartCoordinate? = nil, severity: KLMarkerSeverity? = nil, style: KLMarkerStyleDescriptor? = nil) {
        self.id = id
        self.title = title
        self.message = message
        self.coordinate = coordinate
        self.severity = severity
        self.style = style
    }
}

public struct KXUT07ManualMarkerOperationSnapshot: Codable, Equatable, Sendable {
    public let kind: KXUT07ManualMarkerOperationKind
    public let beforeMarkers: [KLMarkerDescriptor]
    public let afterMarkers: [KLMarkerDescriptor]
    public let summary: String
    public let operatedAt: Date

    public init(kind: KXUT07ManualMarkerOperationKind, beforeMarkers: [KLMarkerDescriptor], afterMarkers: [KLMarkerDescriptor], summary: String, operatedAt: Date = Date()) {
        self.kind = kind
        self.beforeMarkers = beforeMarkers
        self.afterMarkers = afterMarkers
        self.summary = summary
        self.operatedAt = operatedAt
    }
}

public struct KXUT07ManualMarkerState: Codable, Equatable, Sendable {
    public let markers: [KLMarkerDescriptor]
    public let undoStack: [KXUT07ManualMarkerOperationSnapshot]
    public let reapplyStack: [KXUT07ManualMarkerOperationSnapshot]
    public let lastOperationSummary: String?

    public init(markers: [KLMarkerDescriptor], undoStack: [KXUT07ManualMarkerOperationSnapshot] = [], reapplyStack: [KXUT07ManualMarkerOperationSnapshot] = [], lastOperationSummary: String? = nil) {
        self.markers = markers
        self.undoStack = undoStack
        self.reapplyStack = reapplyStack
        self.lastOperationSummary = lastOperationSummary
    }
}

public struct KXUT07ManualMarkerOperationResult: Codable, Equatable, Sendable {
    public let markers: [KLMarkerDescriptor]
    public let state: KXUT07ManualMarkerState
    public let changed: Bool
    public let affectedIDs: [String]
    public let summary: String

    public init(markers: [KLMarkerDescriptor], state: KXUT07ManualMarkerState, changed: Bool, affectedIDs: [String], summary: String) {
        self.markers = markers
        self.state = state
        self.changed = changed
        self.affectedIDs = affectedIDs
        self.summary = summary
    }
}

// MARK: - 用户手动标记纯服务

public enum KXUT07ManualMarkerManager {
    public static func makeState(markers: [KLMarkerDescriptor]) -> KXUT07ManualMarkerState {
        KXUT07ManualMarkerState(markers: markers)
    }

    public static func add(_ marker: KLMarkerDescriptor, to markers: [KLMarkerDescriptor]) -> KXUT07ManualMarkerOperationResult {
        add(marker, to: makeState(markers: markers))
    }

    public static func add(_ marker: KLMarkerDescriptor, to state: KXUT07ManualMarkerState) -> KXUT07ManualMarkerOperationResult {
        guard isUserManualMarker(marker) else {
            return unchangedResult(state: state, kind: .add, affectedIDs: [marker.id], summary: "新增失败：仅允许新增用户手动标记 \(marker.id)")
        }
        guard !contains(id: marker.id, in: state.markers, includeOnlyUserManualMarkers: false) else {
            return unchangedResult(state: state, kind: .add, affectedIDs: [marker.id], summary: "新增跳过：标记已存在 \(marker.id)")
        }
        return changedResult(state: state, afterMarkers: state.markers + [marker], kind: .add, affectedIDs: [marker.id], summary: "新增用户手动标记 1 个：\(marker.id)")
    }

    public static func remove(id: String, from markers: [KLMarkerDescriptor]) -> KXUT07ManualMarkerOperationResult {
        remove(id: id, from: makeState(markers: markers))
    }

    public static func remove(id: String, from state: KXUT07ManualMarkerState) -> KXUT07ManualMarkerOperationResult {
        batchRemove(ids: [id], from: state, operationKind: .remove)
    }

    public static func batchRemove(ids: [String], from markers: [KLMarkerDescriptor]) -> KXUT07ManualMarkerOperationResult {
        batchRemove(ids: ids, from: makeState(markers: markers))
    }

    public static func batchRemove(ids: [String], from state: KXUT07ManualMarkerState) -> KXUT07ManualMarkerOperationResult {
        batchRemove(ids: ids, from: state, operationKind: .batchRemove)
    }

    public static func update(_ markerUpdate: KXUT07ManualMarkerUpdate, in markers: [KLMarkerDescriptor]) -> KXUT07ManualMarkerOperationResult {
        update(markerUpdate, in: makeState(markers: markers))
    }

    public static func update(_ markerUpdate: KXUT07ManualMarkerUpdate, in state: KXUT07ManualMarkerState) -> KXUT07ManualMarkerOperationResult {
        guard let targetIndex = state.markers.firstIndex(where: { $0.id == markerUpdate.id && isUserManualMarker($0) }) else {
            return unchangedResult(state: state, kind: .update, affectedIDs: [markerUpdate.id], summary: "更新失败：未找到用户手动标记 \(markerUpdate.id)")
        }

        let oldMarker = state.markers[targetIndex]
        let newMarker = KLMarkerDescriptor(
            id: oldMarker.id,
            symbol: oldMarker.symbol,
            timeframe: oldMarker.timeframe,
            kind: .manual,
            source: .user,
            severity: markerUpdate.severity ?? oldMarker.severity,
            title: markerUpdate.title ?? oldMarker.title,
            message: markerUpdate.message ?? oldMarker.message,
            coordinate: markerUpdate.coordinate ?? oldMarker.coordinate,
            style: markerUpdate.style ?? oldMarker.style,
            createdAt: oldMarker.createdAt
        )

        guard newMarker != oldMarker else {
            return unchangedResult(state: state, kind: .update, affectedIDs: [markerUpdate.id], summary: "更新跳过：内容无变化 \(markerUpdate.id)")
        }

        var nextMarkers = state.markers
        nextMarkers[targetIndex] = newMarker
        return changedResult(state: state, afterMarkers: nextMarkers, kind: .update, affectedIDs: [markerUpdate.id], summary: "更新用户手动标记 1 个：\(markerUpdate.id)")
    }

    public static func toggle(_ marker: KLMarkerDescriptor, in markers: [KLMarkerDescriptor]) -> KXUT07ManualMarkerOperationResult {
        toggle(marker, in: makeState(markers: markers))
    }

    public static func toggle(_ marker: KLMarkerDescriptor, in state: KXUT07ManualMarkerState) -> KXUT07ManualMarkerOperationResult {
        if contains(id: marker.id, in: state.markers, includeOnlyUserManualMarkers: true) {
            return batchRemove(ids: [marker.id], from: state, operationKind: .toggle)
        }

        guard isUserManualMarker(marker) else {
            return unchangedResult(state: state, kind: .toggle, affectedIDs: [marker.id], summary: "切换失败：仅允许切换用户手动标记 \(marker.id)")
        }
        return changedResult(state: state, afterMarkers: state.markers + [marker], kind: .toggle, affectedIDs: [marker.id], summary: "切换为已添加：\(marker.id)")
    }

    public static func contains(id: String, in markers: [KLMarkerDescriptor], includeOnlyUserManualMarkers: Bool = true) -> Bool {
        markers.contains { marker in
            marker.id == id && (!includeOnlyUserManualMarkers || isUserManualMarker(marker))
        }
    }

    public static func list(_ markers: [KLMarkerDescriptor], filter: KXUT07ManualMarkerFilter = KXUT07ManualMarkerFilter(), sortRule: KXUT07ManualMarkerSortRule? = nil) -> [KLMarkerDescriptor] {
        let filteredMarkers = self.filter(markers, by: filter)
        guard let sortRule else { return filteredMarkers }
        return sort(filteredMarkers, by: sortRule)
    }

    public static func filter(_ markers: [KLMarkerDescriptor], by filter: KXUT07ManualMarkerFilter) -> [KLMarkerDescriptor] {
        markers.filter { marker in
            if filter.includeOnlyUserManualMarkers && !isUserManualMarker(marker) { return false }
            if let symbol = filter.symbol, marker.symbol != symbol { return false }
            if let timeframe = filter.timeframe, marker.timeframe != timeframe { return false }
            if let window = filter.window, !isMarker(marker, inside: window) { return false }
            return true
        }
    }

    public static func sort(_ markers: [KLMarkerDescriptor], by rule: KXUT07ManualMarkerSortRule = KXUT07ManualMarkerSortRule()) -> [KLMarkerDescriptor] {
        markers.sorted { lhs, rhs in
            let ascending = isOrdered(lhs, before: rhs, field: rule.field)
            return rule.order == .ascending ? ascending : !ascending
        }
    }

    public static func undo(_ state: KXUT07ManualMarkerState) -> KXUT07ManualMarkerOperationResult {
        guard let snapshot = state.undoStack.last else {
            return unchangedResult(state: state, kind: .undo, affectedIDs: [], summary: "撤销失败：没有可撤销操作")
        }

        let nextUndoStack = Array(state.undoStack.dropLast())
        let nextReapplyStack = state.reapplyStack + [snapshot]
        let summary = "撤销：\(snapshot.summary)"
        let nextState = KXUT07ManualMarkerState(markers: snapshot.beforeMarkers, undoStack: nextUndoStack, reapplyStack: nextReapplyStack, lastOperationSummary: summary)
        return KXUT07ManualMarkerOperationResult(markers: nextState.markers, state: nextState, changed: true, affectedIDs: changedIDs(between: snapshot.afterMarkers, and: snapshot.beforeMarkers), summary: summary)
    }

    public static func reapply(_ state: KXUT07ManualMarkerState) -> KXUT07ManualMarkerOperationResult {
        guard let snapshot = state.reapplyStack.last else {
            return unchangedResult(state: state, kind: .reapply, affectedIDs: [], summary: "重做失败：没有可重做操作")
        }

        let nextReapplyStack = Array(state.reapplyStack.dropLast())
        let nextUndoStack = state.undoStack + [snapshot]
        let summary = "重做：\(snapshot.summary)"
        let nextState = KXUT07ManualMarkerState(markers: snapshot.afterMarkers, undoStack: nextUndoStack, reapplyStack: nextReapplyStack, lastOperationSummary: summary)
        return KXUT07ManualMarkerOperationResult(markers: nextState.markers, state: nextState, changed: true, affectedIDs: changedIDs(between: snapshot.beforeMarkers, and: snapshot.afterMarkers), summary: summary)
    }

    public static func lastOperationSummary(in state: KXUT07ManualMarkerState) -> String? {
        state.lastOperationSummary
    }

    public static func isUserManualMarker(_ marker: KLMarkerDescriptor) -> Bool {
        marker.kind == .manual && marker.source == .user
    }

    private static func batchRemove(ids: [String], from state: KXUT07ManualMarkerState, operationKind: KXUT07ManualMarkerOperationKind) -> KXUT07ManualMarkerOperationResult {
        let uniqueIDs = Array(Set(ids))
        guard !uniqueIDs.isEmpty else {
            return unchangedResult(state: state, kind: operationKind, affectedIDs: [], summary: "删除跳过：未提供标记 ID")
        }

        let idSet = Set(uniqueIDs)
        let removableIDs = Set(state.markers.filter { idSet.contains($0.id) && isUserManualMarker($0) }.map(\.id))
        guard !removableIDs.isEmpty else {
            return unchangedResult(state: state, kind: operationKind, affectedIDs: uniqueIDs, summary: "删除失败：未找到可删除的用户手动标记")
        }

        let nextMarkers = state.markers.filter { !removableIDs.contains($0.id) }
        let summary: String
        if operationKind == .toggle, let id = removableIDs.sorted().first {
            summary = "切换为已删除：\(id)"
        } else {
            summary = "删除用户手动标记 \(removableIDs.count) 个"
        }
        return changedResult(state: state, afterMarkers: nextMarkers, kind: operationKind, affectedIDs: removableIDs.sorted(), summary: summary)
    }

    private static func changedResult(state: KXUT07ManualMarkerState, afterMarkers: [KLMarkerDescriptor], kind: KXUT07ManualMarkerOperationKind, affectedIDs: [String], summary: String) -> KXUT07ManualMarkerOperationResult {
        let snapshot = KXUT07ManualMarkerOperationSnapshot(kind: kind, beforeMarkers: state.markers, afterMarkers: afterMarkers, summary: summary)
        let nextState = KXUT07ManualMarkerState(markers: afterMarkers, undoStack: state.undoStack + [snapshot], reapplyStack: [], lastOperationSummary: summary)
        return KXUT07ManualMarkerOperationResult(markers: afterMarkers, state: nextState, changed: true, affectedIDs: affectedIDs, summary: summary)
    }

    private static func unchangedResult(state: KXUT07ManualMarkerState, kind: KXUT07ManualMarkerOperationKind, affectedIDs: [String], summary: String) -> KXUT07ManualMarkerOperationResult {
        let nextState = KXUT07ManualMarkerState(markers: state.markers, undoStack: state.undoStack, reapplyStack: state.reapplyStack, lastOperationSummary: summary)
        return KXUT07ManualMarkerOperationResult(markers: state.markers, state: nextState, changed: false, affectedIDs: affectedIDs, summary: summary)
    }

    private static func isMarker(_ marker: KLMarkerDescriptor, inside window: KLVisibleWindow) -> Bool {
        guard marker.symbol == window.symbol, marker.timeframe == window.timeframe else { return false }

        if let index = marker.coordinate.index {
            return index >= window.indexRange.startIndex && index <= window.indexRange.endIndex
        }

        if let time = marker.coordinate.time, let timeRange = window.timeRange {
            return time >= timeRange.startTime && time <= timeRange.endTime
        }

        return true
    }

    private static func isOrdered(_ lhs: KLMarkerDescriptor, before rhs: KLMarkerDescriptor, field: KXUT07ManualMarkerSortField) -> Bool {
        switch field {
        case .id:
            return stableCompare(lhs.id, rhs.id, lhsFallback: lhs.id, rhsFallback: rhs.id)
        case .title:
            return stableCompare(lhs.title, rhs.title, lhsFallback: lhs.id, rhsFallback: rhs.id)
        case .createdAt:
            return lhs.createdAt == rhs.createdAt ? lhs.id < rhs.id : lhs.createdAt < rhs.createdAt
        case .time:
            return compareOptional(lhs.coordinate.time, rhs.coordinate.time, lhsFallback: lhs.id, rhsFallback: rhs.id)
        case .index:
            return compareOptional(lhs.coordinate.index, rhs.coordinate.index, lhsFallback: lhs.id, rhsFallback: rhs.id)
        case .price:
            return compareOptional(lhs.coordinate.price, rhs.coordinate.price, lhsFallback: lhs.id, rhsFallback: rhs.id)
        case .severity:
            let lhsRank = severityRank(lhs.severity)
            let rhsRank = severityRank(rhs.severity)
            return lhsRank == rhsRank ? lhs.id < rhs.id : lhsRank < rhsRank
        }
    }

    private static func stableCompare(_ lhs: String, _ rhs: String, lhsFallback: String, rhsFallback: String) -> Bool {
        lhs == rhs ? lhsFallback < rhsFallback : lhs < rhs
    }

    private static func compareOptional<T: Comparable>(_ lhs: T?, _ rhs: T?, lhsFallback: String, rhsFallback: String) -> Bool {
        switch (lhs, rhs) {
        case let (lhsValue?, rhsValue?):
            return lhsValue == rhsValue ? lhsFallback < rhsFallback : lhsValue < rhsValue
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhsFallback < rhsFallback
        }
    }

    private static func severityRank(_ severity: KLMarkerSeverity) -> Int {
        switch severity {
        case .info: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    private static func changedIDs(between lhs: [KLMarkerDescriptor], and rhs: [KLMarkerDescriptor]) -> [String] {
        let lhsMap = Dictionary(uniqueKeysWithValues: lhs.map { ($0.id, $0) })
        let rhsMap = Dictionary(uniqueKeysWithValues: rhs.map { ($0.id, $0) })
        return Array(Set(lhsMap.keys).union(rhsMap.keys)).filter { lhsMap[$0] != rhsMap[$0] }.sorted()
    }
}
