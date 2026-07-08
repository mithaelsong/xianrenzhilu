//
//  KX-SJ-07_标记事件访问.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：标记事件表读写接口骨架
//  禁止事项：禁止标记叠加渲染、禁止 SQL 执行、禁止数据库连接、禁止文件系统访问
//

import Foundation


// MARK: - 标记事件表访问骨架

public enum KXSJ07Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-07",
        fileName: "KX-SJ-07_标记事件表访问.swift",
        layer: .data,
        relativePath: "数据层/KX-SJ-07_标记事件表访问.swift",
        duty: "标记事件表记录 DTO、纯映射和访问请求描述"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "标记事件表访问", passed: true, message: "已升级为纯记录映射和访问请求描述；不执行 SQL、不连接数据库")
    }

    public static func placeholder() {
        // 本文件仅描述标记事件表记录、查询条件、写入/删除请求与映射关系。
        // 具体数据库驱动、SQL 拼装、事务执行、文件访问均由后续数据访问实现层承担。
    }
}

// MARK: - 标记事件表定义

public enum KXSJ07MarkerEventTable {
    public static let descriptor = KLTableDescriptor(
        name: "kl_marker_events",
        primaryKeys: ["id"],
        duty: "保存 K线图标记事件记录，用于标记描述符与持久化表记录之间的纯映射"
    )

    public enum Column: String, Codable, Sendable, CaseIterable {
        case id
        case symbol
        case timeframe
        case kind
        case source
        case severity
        case title
        case message
        case coordinateTime = "coordinate_time"
        case coordinateIndex = "coordinate_index"
        case coordinatePrice = "coordinate_price"
        case coordinateX = "coordinate_x"
        case coordinateY = "coordinate_y"
        case styleColorHex = "style_color_hex"
        case styleIconName = "style_icon_name"
        case styleLineWidth = "style_line_width"
        case styleOpacity = "style_opacity"
        case payload
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 标记事件表记录 DTO

public struct KXSJ07MarkerEventRecordDTO: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let symbol: KXSymbol
    public let timeframeRawValue: String
    public let kindRawValue: String
    public let sourceRawValue: String
    public let severityRawValue: String
    public let title: String
    public let message: String?
    public let coordinateTime: Date?
    public let coordinateIndex: Int?
    public let coordinatePriceText: String?
    public let coordinateX: Double?
    public let coordinateY: Double?
    public let styleColorHex: String?
    public let styleIconName: String?
    public let styleLineWidth: Double?
    public let styleOpacity: Double?
    public let payload: [String: String]
    public let createdAt: Date
    public let updatedAt: Date?

    public init(
        id: String,
        symbol: KXSymbol,
        timeframeRawValue: String,
        kindRawValue: String,
        sourceRawValue: String,
        severityRawValue: String,
        title: String,
        message: String? = nil,
        coordinateTime: Date? = nil,
        coordinateIndex: Int? = nil,
        coordinatePriceText: String? = nil,
        coordinateX: Double? = nil,
        coordinateY: Double? = nil,
        styleColorHex: String? = nil,
        styleIconName: String? = nil,
        styleLineWidth: Double? = nil,
        styleOpacity: Double? = nil,
        payload: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.timeframeRawValue = timeframeRawValue
        self.kindRawValue = kindRawValue
        self.sourceRawValue = sourceRawValue
        self.severityRawValue = severityRawValue
        self.title = title
        self.message = message
        self.coordinateTime = coordinateTime
        self.coordinateIndex = coordinateIndex
        self.coordinatePriceText = coordinatePriceText
        self.coordinateX = coordinateX
        self.coordinateY = coordinateY
        self.styleColorHex = styleColorHex
        self.styleIconName = styleIconName
        self.styleLineWidth = styleLineWidth
        self.styleOpacity = styleOpacity
        self.payload = payload
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 查询条件与访问请求描述

public enum KXSJ07MarkerEventQueryOrder: String, Codable, Sendable, CaseIterable {
    case coordinateTimeAscending
    case coordinateTimeDescending
    case createdAtAscending
    case createdAtDescending
    case severityAscending
    case severityDescending
}

public struct KXSJ07MarkerEventQueryCondition: Codable, Equatable, Sendable {
    public let symbol: KXSymbol?
    public let timeframe: KXTimeframe?
    public let kind: KLMarkerKind?
    public let source: KLMarkerSource?
    public let severity: KLMarkerSeverity?
    public let startTime: Date?
    public let endTime: Date?
    public let order: KXSJ07MarkerEventQueryOrder
    public let limit: Int?
    public let offset: Int?

    public init(
        symbol: KXSymbol? = nil,
        timeframe: KXTimeframe? = nil,
        kind: KLMarkerKind? = nil,
        source: KLMarkerSource? = nil,
        severity: KLMarkerSeverity? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        order: KXSJ07MarkerEventQueryOrder = .coordinateTimeAscending,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.kind = kind
        self.source = source
        self.severity = severity
        self.startTime = startTime
        self.endTime = endTime
        self.order = order
        self.limit = limit
        self.offset = offset
    }
}

public struct KXSJ07MarkerEventUpsertRequest: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let records: [KXSJ07MarkerEventRecordDTO]
    public let conflictKeys: [String]
    public let requestedAt: Date

    public init(
        records: [KXSJ07MarkerEventRecordDTO],
        conflictKeys: [String] = ["id"],
        requestedAt: Date = Date()
    ) {
        self.id = records.map(\.id).joined(separator: ",")
        self.records = records
        self.conflictKeys = conflictKeys
        self.requestedAt = requestedAt
    }

    public init(
        record: KXSJ07MarkerEventRecordDTO,
        conflictKeys: [String] = ["id"],
        requestedAt: Date = Date()
    ) {
        self.init(records: [record], conflictKeys: conflictKeys, requestedAt: requestedAt)
    }
}

public enum KXSJ07MarkerEventDeleteTarget: Codable, Equatable, Sendable {
    case id(String)
    case ids([String])
    case condition(KXSJ07MarkerEventQueryCondition)
}

public struct KXSJ07MarkerEventDeleteRequest: Codable, Equatable, Sendable {
    public let target: KXSJ07MarkerEventDeleteTarget
    public let requestedAt: Date

    public init(target: KXSJ07MarkerEventDeleteTarget, requestedAt: Date = Date()) {
        self.target = target
        self.requestedAt = requestedAt
    }
}

public enum KXSJ07MarkerEventAccessRequest: Codable, Equatable, Sendable {
    case query(KXSJ07MarkerEventQueryCondition)
    case upsert(KXSJ07MarkerEventUpsertRequest)
    case delete(KXSJ07MarkerEventDeleteRequest)
}

public struct KXSJ07MarkerEventResultSummary: Codable, Equatable, Sendable {
    public let request: KXSJ07MarkerEventAccessRequest?
    public let matchedCount: Int
    public let insertedCount: Int
    public let updatedCount: Int
    public let deletedCount: Int
    public let skippedCount: Int
    public let returnedCount: Int
    public let generatedAt: Date
    public let message: String?

    public init(
        request: KXSJ07MarkerEventAccessRequest? = nil,
        matchedCount: Int = 0,
        insertedCount: Int = 0,
        updatedCount: Int = 0,
        deletedCount: Int = 0,
        skippedCount: Int = 0,
        returnedCount: Int = 0,
        generatedAt: Date = Date(),
        message: String? = nil
    ) {
        self.request = request
        self.matchedCount = matchedCount
        self.insertedCount = insertedCount
        self.updatedCount = updatedCount
        self.deletedCount = deletedCount
        self.skippedCount = skippedCount
        self.returnedCount = returnedCount
        self.generatedAt = generatedAt
        self.message = message
    }
}

// MARK: - KLMarkerDescriptor 与表记录纯映射

public enum KXSJ07MarkerEventRecordMapper {
    public static func record(
        from descriptor: KLMarkerDescriptor,
        payload: [String: String] = [:],
        updatedAt: Date? = nil
    ) -> KXSJ07MarkerEventRecordDTO {
        KXSJ07MarkerEventRecordDTO(
            id: descriptor.id,
            symbol: descriptor.symbol,
            timeframeRawValue: descriptor.timeframe.rawValue,
            kindRawValue: descriptor.kind.rawValue,
            sourceRawValue: descriptor.source.rawValue,
            severityRawValue: descriptor.severity.rawValue,
            title: descriptor.title,
            message: descriptor.message,
            coordinateTime: descriptor.coordinate.time,
            coordinateIndex: descriptor.coordinate.index,
            coordinatePriceText: decimalText(from: descriptor.coordinate.price),
            coordinateX: descriptor.coordinate.point?.x,
            coordinateY: descriptor.coordinate.point?.y,
            styleColorHex: descriptor.style?.colorHex,
            styleIconName: descriptor.style?.iconName,
            styleLineWidth: descriptor.style?.lineWidth,
            styleOpacity: descriptor.style?.opacity,
            payload: payload,
            createdAt: descriptor.createdAt,
            updatedAt: updatedAt
        )
    }

    public static func descriptor(from record: KXSJ07MarkerEventRecordDTO) -> KLMarkerDescriptor? {
        guard let timeframe = KXTimeframe(rawValue: record.timeframeRawValue),
              let kind = KLMarkerKind(rawValue: record.kindRawValue),
              let source = KLMarkerSource(rawValue: record.sourceRawValue),
              let severity = KLMarkerSeverity(rawValue: record.severityRawValue)
        else { return nil }

        let point: KLChartPoint?
        if let x = record.coordinateX, let y = record.coordinateY {
            point = KLChartPoint(x: x, y: y)
        } else {
            point = nil
        }

        let coordinate = KLChartCoordinate(
            time: record.coordinateTime,
            index: record.coordinateIndex,
            price: decimal(from: record.coordinatePriceText),
            point: point
        )

        let style: KLMarkerStyleDescriptor?
        if let colorHex = record.styleColorHex {
            style = KLMarkerStyleDescriptor(
                colorHex: colorHex,
                iconName: record.styleIconName,
                lineWidth: record.styleLineWidth,
                opacity: record.styleOpacity ?? 1
            )
        } else {
            style = nil
        }

        return KLMarkerDescriptor(
            id: record.id,
            symbol: record.symbol,
            timeframe: timeframe,
            kind: kind,
            source: source,
            severity: severity,
            title: record.title,
            message: record.message,
            coordinate: coordinate,
            style: style,
            createdAt: record.createdAt
        )
    }

    public static func records(
        from descriptors: [KLMarkerDescriptor],
        payloadsByID: [String: [String: String]] = [:]
    ) -> [KXSJ07MarkerEventRecordDTO] {
        descriptors.map { descriptor in
            record(from: descriptor, payload: payloadsByID[descriptor.id] ?? [:])
        }
    }

    public static func descriptors(from records: [KXSJ07MarkerEventRecordDTO]) -> [KLMarkerDescriptor] {
        records.compactMap { descriptor(from: $0) }
    }

    private static func decimalText(from decimal: KXDecimal?) -> String? {
        decimal.map { NSDecimalNumber(decimal: $0).stringValue }
    }

    private static func decimal(from text: String?) -> KXDecimal? {
        guard let text, !text.isEmpty else { return nil }
        return Decimal(string: text)
    }
}

// MARK: - 查询描述便捷构造

public enum KXSJ07MarkerEventQueryDescriptorFactory {
    public static func bySymbol(
        _ symbol: KXSymbol,
        timeframe: KXTimeframe? = nil,
        order: KXSJ07MarkerEventQueryOrder = .coordinateTimeAscending
    ) -> KXSJ07MarkerEventQueryCondition {
        KXSJ07MarkerEventQueryCondition(symbol: symbol, timeframe: timeframe, order: order)
    }

    public static func byKind(
        _ kind: KLMarkerKind,
        symbol: KXSymbol? = nil,
        timeframe: KXTimeframe? = nil,
        order: KXSJ07MarkerEventQueryOrder = .coordinateTimeAscending
    ) -> KXSJ07MarkerEventQueryCondition {
        KXSJ07MarkerEventQueryCondition(symbol: symbol, timeframe: timeframe, kind: kind, order: order)
    }

    public static func bySource(
        _ source: KLMarkerSource,
        symbol: KXSymbol? = nil,
        timeframe: KXTimeframe? = nil,
        order: KXSJ07MarkerEventQueryOrder = .coordinateTimeAscending
    ) -> KXSJ07MarkerEventQueryCondition {
        KXSJ07MarkerEventQueryCondition(symbol: symbol, timeframe: timeframe, source: source, order: order)
    }

    public static func bySeverity(
        _ severity: KLMarkerSeverity,
        symbol: KXSymbol? = nil,
        timeframe: KXTimeframe? = nil,
        order: KXSJ07MarkerEventQueryOrder = .severityDescending
    ) -> KXSJ07MarkerEventQueryCondition {
        KXSJ07MarkerEventQueryCondition(symbol: symbol, timeframe: timeframe, severity: severity, order: order)
    }

    public static func byTimeRange(
        startTime: Date,
        endTime: Date,
        symbol: KXSymbol? = nil,
        timeframe: KXTimeframe? = nil,
        kind: KLMarkerKind? = nil,
        source: KLMarkerSource? = nil,
        severity: KLMarkerSeverity? = nil,
        order: KXSJ07MarkerEventQueryOrder = .coordinateTimeAscending
    ) -> KXSJ07MarkerEventQueryCondition {
        KXSJ07MarkerEventQueryCondition(
            symbol: symbol,
            timeframe: timeframe,
            kind: kind,
            source: source,
            severity: severity,
            startTime: startTime,
            endTime: endTime,
            order: order
        )
    }

    public static func bySymbolTimeframeKindSourceSeverity(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        kind: KLMarkerKind? = nil,
        source: KLMarkerSource? = nil,
        severity: KLMarkerSeverity? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        order: KXSJ07MarkerEventQueryOrder = .coordinateTimeAscending
    ) -> KXSJ07MarkerEventQueryCondition {
        KXSJ07MarkerEventQueryCondition(
            symbol: symbol,
            timeframe: timeframe,
            kind: kind,
            source: source,
            severity: severity,
            startTime: startTime,
            endTime: endTime,
            order: order
        )
    }
}
