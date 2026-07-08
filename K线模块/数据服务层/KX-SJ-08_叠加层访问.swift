//
//  KX-SJ-08_叠加层访问.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：图表叠加层表读写接口骨架
//  禁止事项：禁止指标计算、禁止 UI 绘制、禁止执行 SQL、禁止连接数据库
//

import Foundation


// MARK: - 叠加层表访问骨架

public enum KXSJ08Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-08",
        fileName: "KX-SJ-08_叠加层表访问.swift",
        layer: .data,
        relativePath: "数据层/KX-SJ-08_叠加层表访问.swift",
        duty: "图表叠加层表访问请求与记录映射 DTO"
    )

    public static let table = KLTableDescriptor(
        name: "kl_chart_overlays",
        primaryKeys: ["overlay_id"],
        duty: "保存图表叠加层记录：指标线、标记层、画线工具、形态区域、价格区间等"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "叠加层表访问", passed: true, message: "已升级为纯记录映射与访问请求描述，不执行数据库访问")
    }

    public static func placeholder() {
        // 本文件只定义叠加层表 DTO、查询/写入/删除请求、结果摘要与 KL-02 类型映射策略。
        // 禁止执行 SQL、连接数据库、导入数据库驱动或访问文件系统。
    }
}

// MARK: - 叠加层类型与状态

public enum KXSJ08OverlayType: String, Codable, Sendable, CaseIterable {
    case indicatorLine
    case markerLayer
    case drawingTool
    case patternRegion
    case priceRange
    case note
    case custom
}

public enum KXSJ08OverlayVisibility: String, Codable, Sendable, CaseIterable {
    case visible
    case hidden
    case archived
}

public enum KXSJ08OverlayAnchorKind: String, Codable, Sendable, CaseIterable {
    case chartCoordinate
    case timeRange
    case priceRange
    case visibleWindow
    case layoutPane
    case marker
    case externalReference
}

public enum KXSJ08DrawingToolKind: String, Codable, Sendable, CaseIterable {
    case trendLine
    case horizontalLine
    case verticalLine
    case ray
    case rectangle
    case channel
    case fibonacci
    case text
    case arrow
    case custom
}

public enum KXSJ08PatternRegionKind: String, Codable, Sendable, CaseIterable {
    case support
    case resistance
    case consolidation
    case breakout
    case reversal
    case supplyDemand
    case custom
}

// MARK: - 纯值对象

public struct KXSJ08OverlayStyleDTO: Codable, Equatable, Sendable {
    public let colorHex: String?
    public let fillColorHex: String?
    public let lineWidth: Double?
    public let opacity: Double
    public let dashPattern: [Double]
    public let iconName: String?
    public let label: String?

    public init(colorHex: String? = nil, fillColorHex: String? = nil, lineWidth: Double? = nil, opacity: Double = 1, dashPattern: [Double] = [], iconName: String? = nil, label: String? = nil) {
        self.colorHex = colorHex
        self.fillColorHex = fillColorHex
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.dashPattern = dashPattern
        self.iconName = iconName
        self.label = label
    }

    public func toKL02MarkerStyle(fallbackColorHex: String = "#FFFFFF") -> KLMarkerStyleDescriptor {
        KLMarkerStyleDescriptor(
            colorHex: colorHex ?? fallbackColorHex,
            iconName: iconName,
            lineWidth: lineWidth,
            opacity: opacity
        )
    }

    public static func fromKL02MarkerStyle(_ style: KLMarkerStyleDescriptor, label: String? = nil, fillColorHex: String? = nil, dashPattern: [Double] = []) -> KXSJ08OverlayStyleDTO {
        KXSJ08OverlayStyleDTO(
            colorHex: style.colorHex,
            fillColorHex: fillColorHex,
            lineWidth: style.lineWidth,
            opacity: style.opacity,
            dashPattern: dashPattern,
            iconName: style.iconName,
            label: label
        )
    }
}

public struct KXSJ08LayoutReferenceDTO: Codable, Equatable, Sendable {
    public let workspaceID: String?
    public let layoutTemplateID: String?
    public let paneID: String?
    public let pane: KLLayoutPaneDescriptor?
    public let visibleWindow: KLVisibleWindow?

    public init(workspaceID: String? = nil, layoutTemplateID: String? = nil, paneID: String? = nil, pane: KLLayoutPaneDescriptor? = nil, visibleWindow: KLVisibleWindow? = nil) {
        self.workspaceID = workspaceID
        self.layoutTemplateID = layoutTemplateID
        self.paneID = paneID ?? pane?.id
        self.pane = pane
        self.visibleWindow = visibleWindow
    }

    public static func referencing(workspace: KLWorkspaceDescriptor, pane: KLLayoutPaneDescriptor? = nil) -> KXSJ08LayoutReferenceDTO {
        KXSJ08LayoutReferenceDTO(
            workspaceID: workspace.id,
            layoutTemplateID: nil,
            paneID: pane?.id,
            pane: pane,
            visibleWindow: workspace.visibleWindow
        )
    }

    public static func referencing(template: KLLayoutTemplateDescriptor, paneID: String? = nil, visibleWindow: KLVisibleWindow? = nil) -> KXSJ08LayoutReferenceDTO {
        let matchedPane = paneID.flatMap { target in template.paneDescriptors.first { $0.id == target } }
        return KXSJ08LayoutReferenceDTO(
            workspaceID: nil,
            layoutTemplateID: template.id,
            paneID: paneID ?? matchedPane?.id,
            pane: matchedPane,
            visibleWindow: visibleWindow
        )
    }
}

public struct KXSJ08OverlayAnchorDTO: Codable, Equatable, Sendable {
    public let kind: KXSJ08OverlayAnchorKind
    public let coordinate: KLChartCoordinate?
    public let coordinates: [KLChartCoordinate]
    public let timeRange: KLTimeRange?
    public let priceRange: KLPriceRange?
    public let visibleWindow: KLVisibleWindow?
    public let layoutReference: KXSJ08LayoutReferenceDTO?
    public let markerID: String?
    public let externalReferenceID: String?

    public init(kind: KXSJ08OverlayAnchorKind, coordinate: KLChartCoordinate? = nil, coordinates: [KLChartCoordinate] = [], timeRange: KLTimeRange? = nil, priceRange: KLPriceRange? = nil, visibleWindow: KLVisibleWindow? = nil, layoutReference: KXSJ08LayoutReferenceDTO? = nil, markerID: String? = nil, externalReferenceID: String? = nil) {
        self.kind = kind
        self.coordinate = coordinate
        self.coordinates = coordinates
        self.timeRange = timeRange
        self.priceRange = priceRange
        self.visibleWindow = visibleWindow
        self.layoutReference = layoutReference
        self.markerID = markerID
        self.externalReferenceID = externalReferenceID
    }

    public static func chartCoordinate(_ coordinate: KLChartCoordinate, extraCoordinates: [KLChartCoordinate] = []) -> KXSJ08OverlayAnchorDTO {
        KXSJ08OverlayAnchorDTO(kind: .chartCoordinate, coordinate: coordinate, coordinates: [coordinate] + extraCoordinates)
    }

    public static func window(_ visibleWindow: KLVisibleWindow) -> KXSJ08OverlayAnchorDTO {
        KXSJ08OverlayAnchorDTO(kind: .visibleWindow, visibleWindow: visibleWindow)
    }

    public static func priceRange(_ priceRange: KLPriceRange, timeRange: KLTimeRange? = nil) -> KXSJ08OverlayAnchorDTO {
        KXSJ08OverlayAnchorDTO(kind: .priceRange, timeRange: timeRange, priceRange: priceRange)
    }

    public static func layoutPane(_ reference: KXSJ08LayoutReferenceDTO) -> KXSJ08OverlayAnchorDTO {
        KXSJ08OverlayAnchorDTO(kind: .layoutPane, visibleWindow: reference.visibleWindow, layoutReference: reference)
    }

    public static func marker(_ marker: KLMarkerDescriptor) -> KXSJ08OverlayAnchorDTO {
        KXSJ08OverlayAnchorDTO(kind: .marker, coordinate: marker.coordinate, coordinates: [marker.coordinate], markerID: marker.id)
    }
}

public struct KXSJ08IndicatorLineDTO: Codable, Equatable, Sendable {
    public let indicatorID: String
    public let seriesKey: String
    public let displayName: String
    public let valuesReference: String?
    public let parameters: [String: String]

    public init(indicatorID: String, seriesKey: String, displayName: String, valuesReference: String? = nil, parameters: [String: String] = [:]) {
        self.indicatorID = indicatorID
        self.seriesKey = seriesKey
        self.displayName = displayName
        self.valuesReference = valuesReference
        self.parameters = parameters
    }
}

public struct KXSJ08DrawingToolDTO: Codable, Equatable, Sendable {
    public let kind: KXSJ08DrawingToolKind
    public let points: [KLChartCoordinate]
    public let text: String?
    public let locked: Bool

    public init(kind: KXSJ08DrawingToolKind, points: [KLChartCoordinate], text: String? = nil, locked: Bool = false) {
        self.kind = kind
        self.points = points
        self.text = text
        self.locked = locked
    }
}

public struct KXSJ08PatternRegionDTO: Codable, Equatable, Sendable {
    public let kind: KXSJ08PatternRegionKind
    public let timeRange: KLTimeRange?
    public let priceRange: KLPriceRange?
    public let boundaryPoints: [KLChartCoordinate]
    public let confidence: Double?
    public let sourceMarkerID: String?

    public init(kind: KXSJ08PatternRegionKind, timeRange: KLTimeRange? = nil, priceRange: KLPriceRange? = nil, boundaryPoints: [KLChartCoordinate] = [], confidence: Double? = nil, sourceMarkerID: String? = nil) {
        self.kind = kind
        self.timeRange = timeRange
        self.priceRange = priceRange
        self.boundaryPoints = boundaryPoints
        self.confidence = confidence
        self.sourceMarkerID = sourceMarkerID
    }
}

public struct KXSJ08PriceRangeOverlayDTO: Codable, Equatable, Sendable {
    public let range: KLPriceRange
    public let timeRange: KLTimeRange?
    public let title: String?
    public let alertReferenceID: String?

    public init(range: KLPriceRange, timeRange: KLTimeRange? = nil, title: String? = nil, alertReferenceID: String? = nil) {
        self.range = range
        self.timeRange = timeRange
        self.title = title
        self.alertReferenceID = alertReferenceID
    }
}

public enum KXSJ08OverlayPayloadDTO: Codable, Equatable, Sendable {
    case indicatorLine(KXSJ08IndicatorLineDTO)
    case marker(KLMarkerDescriptor)
    case drawingTool(KXSJ08DrawingToolDTO)
    case patternRegion(KXSJ08PatternRegionDTO)
    case priceRange(KXSJ08PriceRangeOverlayDTO)
    case note(String)
    case custom(kind: String, encodedBody: String)
}

// MARK: - 表记录 DTO

public struct KXSJ08OverlayRecordDTO: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let overlayType: KXSJ08OverlayType
    public let title: String
    public let visibility: KXSJ08OverlayVisibility
    public let zIndex: Int
    public let anchor: KXSJ08OverlayAnchorDTO
    public let payload: KXSJ08OverlayPayloadDTO
    public let style: KXSJ08OverlayStyleDTO?
    public let layoutReference: KXSJ08LayoutReferenceDTO?
    public let tags: [String]
    public let metadata: [String: String]
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: String, symbol: KXSymbol, timeframe: KXTimeframe, overlayType: KXSJ08OverlayType, title: String, visibility: KXSJ08OverlayVisibility = .visible, zIndex: Int = 0, anchor: KXSJ08OverlayAnchorDTO, payload: KXSJ08OverlayPayloadDTO, style: KXSJ08OverlayStyleDTO? = nil, layoutReference: KXSJ08LayoutReferenceDTO? = nil, tags: [String] = [], metadata: [String: String] = [:], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.symbol = symbol
        self.timeframe = timeframe
        self.overlayType = overlayType
        self.title = title
        self.visibility = visibility
        self.zIndex = zIndex
        self.anchor = anchor
        self.payload = payload
        self.style = style
        self.layoutReference = layoutReference
        self.tags = tags
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func fromMarker(_ marker: KLMarkerDescriptor, zIndex: Int = 0, layoutReference: KXSJ08LayoutReferenceDTO? = nil, metadata: [String: String] = [:]) -> KXSJ08OverlayRecordDTO {
        KXSJ08OverlayRecordDTO(
            id: marker.id,
            symbol: marker.symbol,
            timeframe: marker.timeframe,
            overlayType: .markerLayer,
            title: marker.title,
            zIndex: zIndex,
            anchor: .marker(marker),
            payload: .marker(marker),
            style: marker.style.map { .fromKL02MarkerStyle($0) },
            layoutReference: layoutReference,
            tags: [marker.kind.rawValue, marker.source.rawValue, marker.severity.rawValue],
            metadata: metadata,
            createdAt: marker.createdAt,
            updatedAt: Date()
        )
    }

    public func markerDescriptor(fallbackKind: KLMarkerKind = .manual, fallbackSource: KLMarkerSource = .user, fallbackSeverity: KLMarkerSeverity = .info) -> KLMarkerDescriptor? {
        if case let .marker(marker) = payload {
            return marker
        }

        guard overlayType == .markerLayer, let coordinate = anchor.coordinate else { return nil }
        return KLMarkerDescriptor(
            id: id,
            symbol: symbol,
            timeframe: timeframe,
            kind: fallbackKind,
            source: fallbackSource,
            severity: fallbackSeverity,
            title: title,
            message: metadata["message"],
            coordinate: coordinate,
            style: style?.toKL02MarkerStyle(),
            createdAt: createdAt
        )
    }

    public func visibleWindowSnapshot() -> KLVisibleWindow? {
        anchor.visibleWindow ?? layoutReference?.visibleWindow
    }
}

// MARK: - 查询条件与访问请求描述

public struct KXSJ08OverlayQueryCondition: Codable, Equatable, Sendable {
    public let symbol: KXSymbol?
    public let timeframe: KXTimeframe?
    public let overlayTypes: [KXSJ08OverlayType]
    public let visibility: KXSJ08OverlayVisibility?
    public let layoutPaneID: String?
    public let workspaceID: String?
    public let timeRange: KLTimeRange?
    public let priceRange: KLPriceRange?
    public let tags: [String]
    public let limit: Int?
    public let order: KLQuerySortOrder

    public init(symbol: KXSymbol? = nil, timeframe: KXTimeframe? = nil, overlayTypes: [KXSJ08OverlayType] = [], visibility: KXSJ08OverlayVisibility? = .visible, layoutPaneID: String? = nil, workspaceID: String? = nil, timeRange: KLTimeRange? = nil, priceRange: KLPriceRange? = nil, tags: [String] = [], limit: Int? = nil, order: KLQuerySortOrder = .ascending) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.overlayTypes = overlayTypes
        self.visibility = visibility
        self.layoutPaneID = layoutPaneID
        self.workspaceID = workspaceID
        self.timeRange = timeRange
        self.priceRange = priceRange
        self.tags = tags
        self.limit = limit
        self.order = order
    }

    public static func forVisibleWindow(_ window: KLVisibleWindow, overlayTypes: [KXSJ08OverlayType] = [], limit: Int? = nil) -> KXSJ08OverlayQueryCondition {
        KXSJ08OverlayQueryCondition(
            symbol: window.symbol,
            timeframe: window.timeframe,
            overlayTypes: overlayTypes,
            visibility: .visible,
            timeRange: window.timeRange,
            priceRange: window.priceRange,
            limit: limit
        )
    }
}

public struct KXSJ08OverlayUpsertRequest: Codable, Equatable, Sendable {
    public let record: KXSJ08OverlayRecordDTO
    public let expectedExistingUpdatedAt: Date?
    public let reason: String?

    public init(record: KXSJ08OverlayRecordDTO, expectedExistingUpdatedAt: Date? = nil, reason: String? = nil) {
        self.record = record
        self.expectedExistingUpdatedAt = expectedExistingUpdatedAt
        self.reason = reason
    }
}

public struct KXSJ08OverlayDeleteRequest: Codable, Equatable, Sendable {
    public let overlayID: String
    public let hardDelete: Bool
    public let expectedExistingUpdatedAt: Date?
    public let reason: String?

    public init(overlayID: String, hardDelete: Bool = false, expectedExistingUpdatedAt: Date? = nil, reason: String? = nil) {
        self.overlayID = overlayID
        self.hardDelete = hardDelete
        self.expectedExistingUpdatedAt = expectedExistingUpdatedAt
        self.reason = reason
    }
}

public struct KXSJ08OverlayBatchUpsertRequest: Codable, Equatable, Sendable {
    public let records: [KXSJ08OverlayRecordDTO]
    public let reason: String?

    public init(records: [KXSJ08OverlayRecordDTO], reason: String? = nil) {
        self.records = records
        self.reason = reason
    }
}

public struct KXSJ08OverlayAccessPlan: Codable, Equatable, Sendable {
    public let table: KLTableDescriptor
    public let query: KXSJ08OverlayQueryCondition?
    public let upserts: [KXSJ08OverlayUpsertRequest]
    public let deletes: [KXSJ08OverlayDeleteRequest]
    public let readonly: Bool

    public init(table: KLTableDescriptor = KXSJ08Skeleton.table, query: KXSJ08OverlayQueryCondition? = nil, upserts: [KXSJ08OverlayUpsertRequest] = [], deletes: [KXSJ08OverlayDeleteRequest] = [], readonly: Bool = true) {
        self.table = table
        self.query = query
        self.upserts = upserts
        self.deletes = deletes
        self.readonly = readonly
    }
}

// MARK: - 结果摘要

public struct KXSJ08OverlayResultSummary: Codable, Equatable, Sendable {
    public let matchedCount: Int
    public let insertedCount: Int
    public let updatedCount: Int
    public let deletedCount: Int
    public let archivedCount: Int
    public let skippedCount: Int
    public let affectedIDs: [String]
    public let warnings: [String]
    public let generatedAt: Date

    public init(matchedCount: Int = 0, insertedCount: Int = 0, updatedCount: Int = 0, deletedCount: Int = 0, archivedCount: Int = 0, skippedCount: Int = 0, affectedIDs: [String] = [], warnings: [String] = [], generatedAt: Date = Date()) {
        self.matchedCount = matchedCount
        self.insertedCount = insertedCount
        self.updatedCount = updatedCount
        self.deletedCount = deletedCount
        self.archivedCount = archivedCount
        self.skippedCount = skippedCount
        self.affectedIDs = affectedIDs
        self.warnings = warnings
        self.generatedAt = generatedAt
    }
}

public struct KXSJ08OverlayQueryResultDTO: Codable, Equatable, Sendable {
    public let condition: KXSJ08OverlayQueryCondition
    public let records: [KXSJ08OverlayRecordDTO]
    public let summary: KXSJ08OverlayResultSummary

    public init(condition: KXSJ08OverlayQueryCondition, records: [KXSJ08OverlayRecordDTO], summary: KXSJ08OverlayResultSummary? = nil) {
        self.condition = condition
        self.records = records
        self.summary = summary ?? KXSJ08OverlayResultSummary(matchedCount: records.count, affectedIDs: records.map { $0.id })
    }

    public func markerOverlayDescriptor(window fallbackWindow: KLVisibleWindow? = nil) -> KLMarkerOverlayDescriptor? {
        let markers = records.compactMap { $0.markerDescriptor() }
        guard !markers.isEmpty else { return nil }
        guard let window = fallbackWindow ?? records.compactMap({ $0.visibleWindowSnapshot() }).first else { return nil }
        return KLMarkerOverlayDescriptor(visibleWindow: window, markers: markers)
    }
}
