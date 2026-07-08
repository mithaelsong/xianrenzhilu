//
//  KX-SJ-06_收藏表访问.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：K线收藏表读写接口骨架
//  禁止事项：禁止 UI 收藏列表绘制、禁止 SQL 执行、禁止数据库连接、禁止文件系统访问
//

import Foundation


// MARK: - 收藏表访问骨架

public enum KXSJ06Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-06",
        fileName: "KX-SJ-06_收藏表访问.swift",
        layer: .data,
        relativePath: "数据层/KX-SJ-06_收藏表访问.swift",
        duty: "K线收藏表访问请求描述、记录 DTO 与纯映射"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "收藏表访问", passed: true, message: "已升级为纯记录映射和访问请求描述；不执行 SQL、不连接数据库")
    }

    public static func placeholder() {
        // 本文件仅描述收藏表记录、查询条件、写入/删除请求与映射关系。
        // 具体数据库驱动、SQL 拼装、事务执行、文件访问均由后续数据访问实现层承担。
    }
}

// MARK: - 收藏表定义

public enum KXSJ06FavoriteTable {
    public static let descriptor = KLTableDescriptor(
        name: "kl_favorites",
        primaryKeys: ["id"],
        duty: "保存 K线交易对收藏、周期组合收藏、指标组合收藏的统一记录"
    )

    public enum Column: String, Codable, Sendable, CaseIterable {
        case id
        case type
        case symbol
        case name
        case sortIndex = "sort_index"
        case note
        case payload
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 收藏类型、记录 DTO 与请求摘要

public enum KXSJ06FavoriteType: String, Codable, Sendable, CaseIterable {
    case tradingPair = "trading_pair"
    case timeframeCombination = "timeframe_combination"
    case indicatorCombination = "indicator_combination"
}

public struct KXSJ06FavoriteRecordDTO: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let type: KXSJ06FavoriteType
    public let symbol: KXSymbol?
    public let name: String?
    public let sortIndex: Int
    public let note: String?
    public let payload: [String: String]
    public let createdAt: Date
    public let updatedAt: Date?

    public init(
        id: String,
        type: KXSJ06FavoriteType,
        symbol: KXSymbol? = nil,
        name: String? = nil,
        sortIndex: Int = 0,
        note: String? = nil,
        payload: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.symbol = symbol
        self.name = name
        self.sortIndex = sortIndex
        self.note = note
        self.payload = payload
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum KXSJ06FavoriteSortIndexCondition: Codable, Equatable, Sendable {
    case equal(Int)
    case greaterThanOrEqual(Int)
    case lessThanOrEqual(Int)
    case between(closedRangeStart: Int, closedRangeEnd: Int)
}

public enum KXSJ06FavoriteQueryOrder: String, Codable, Sendable, CaseIterable {
    case sortIndexAscending
    case sortIndexDescending
    case createdAtAscending
    case createdAtDescending
    case nameAscending
    case nameDescending
}

public struct KXSJ06FavoriteQueryCondition: Codable, Equatable, Sendable {
    public let symbol: KXSymbol?
    public let type: KXSJ06FavoriteType?
    public let name: String?
    public let sortIndex: KXSJ06FavoriteSortIndexCondition?
    public let order: KXSJ06FavoriteQueryOrder
    public let limit: Int?
    public let offset: Int?

    public init(
        symbol: KXSymbol? = nil,
        type: KXSJ06FavoriteType? = nil,
        name: String? = nil,
        sortIndex: KXSJ06FavoriteSortIndexCondition? = nil,
        order: KXSJ06FavoriteQueryOrder = .sortIndexAscending,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.symbol = symbol
        self.type = type
        self.name = name
        self.sortIndex = sortIndex
        self.order = order
        self.limit = limit
        self.offset = offset
    }
}

public struct KXSJ06FavoriteUpsertRequest: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let record: KXSJ06FavoriteRecordDTO
    public let conflictKeys: [String]
    public let requestedAt: Date

    public init(
        record: KXSJ06FavoriteRecordDTO,
        conflictKeys: [String] = ["id"],
        requestedAt: Date = Date()
    ) {
        self.id = record.id
        self.record = record
        self.conflictKeys = conflictKeys
        self.requestedAt = requestedAt
    }
}

public enum KXSJ06FavoriteDeleteTarget: Codable, Equatable, Sendable {
    case id(String)
    case condition(KXSJ06FavoriteQueryCondition)
}

public struct KXSJ06FavoriteDeleteRequest: Codable, Equatable, Sendable {
    public let target: KXSJ06FavoriteDeleteTarget
    public let requestedAt: Date

    public init(target: KXSJ06FavoriteDeleteTarget, requestedAt: Date = Date()) {
        self.target = target
        self.requestedAt = requestedAt
    }
}

public enum KXSJ06FavoriteAccessRequest: Codable, Equatable, Sendable {
    case query(KXSJ06FavoriteQueryCondition)
    case upsert(KXSJ06FavoriteUpsertRequest)
    case delete(KXSJ06FavoriteDeleteRequest)
}

public struct KXSJ06FavoriteResultSummary: Codable, Equatable, Sendable {
    public let requestedType: KXSJ06FavoriteType?
    public let matchedCount: Int
    public let insertedCount: Int
    public let updatedCount: Int
    public let deletedCount: Int
    public let skippedCount: Int
    public let message: String?

    public init(
        requestedType: KXSJ06FavoriteType? = nil,
        matchedCount: Int = 0,
        insertedCount: Int = 0,
        updatedCount: Int = 0,
        deletedCount: Int = 0,
        skippedCount: Int = 0,
        message: String? = nil
    ) {
        self.requestedType = requestedType
        self.matchedCount = matchedCount
        self.insertedCount = insertedCount
        self.updatedCount = updatedCount
        self.deletedCount = deletedCount
        self.skippedCount = skippedCount
        self.message = message
    }
}

// MARK: - 收藏描述符

public struct KLFavoritePairDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let pair: KLTradingPairDescriptor
    public let note: String?
    public let sortIndex: Int
    public let createdAt: Date
    public let updatedAt: Date?

    public init(
        id: String,
        pair: KLTradingPairDescriptor,
        note: String? = nil,
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.pair = pair
        self.note = note
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct KXTimeframeCombinationDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let timeframes: [KXTimeframe]
    public let symbol: KXSymbol?
    public let sortIndex: Int
    public let createdAt: Date
    public let updatedAt: Date?

    public init(
        id: String,
        name: String,
        timeframes: [KXTimeframe],
        symbol: KXSymbol? = nil,
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.timeframes = timeframes
        self.symbol = symbol
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct KLIndicatorCombinationDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let indicatorIDs: [String]
    public let symbol: KXSymbol?
    public let sortIndex: Int
    public let createdAt: Date
    public let updatedAt: Date?

    public init(
        id: String,
        name: String,
        indicatorIDs: [String],
        symbol: KXSymbol? = nil,
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.indicatorIDs = indicatorIDs
        self.symbol = symbol
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 纯映射

public enum KXSJ06FavoriteRecordMapper {
    private static let listSeparator = ","

    public static func record(from descriptor: KLFavoritePairDescriptor) -> KXSJ06FavoriteRecordDTO {
        let pair = descriptor.pair
        return KXSJ06FavoriteRecordDTO(
            id: descriptor.id,
            type: .tradingPair,
            symbol: pair.symbol,
            name: pair.displayName,
            sortIndex: descriptor.sortIndex,
            note: descriptor.note,
            payload: [
                "baseCurrency": pair.baseCurrency,
                "quoteCurrency": pair.quoteCurrency,
                "exchangeID": pair.exchangeID,
                "instrumentID": pair.instrumentID,
                "marketType": pair.marketType.rawValue,
                "status": pair.status.rawValue,
                "pricePrecision": String(pair.pricePrecision),
                "quantityPrecision": String(pair.quantityPrecision),
                "minOrderSize": pair.minOrderSize.map { NSDecimalNumber(decimal: $0).stringValue } ?? "",
                "displayName": pair.displayName
            ],
            createdAt: descriptor.createdAt,
            updatedAt: descriptor.updatedAt
        )
    }

    public static func favoritePairDescriptor(from record: KXSJ06FavoriteRecordDTO) -> KLFavoritePairDescriptor? {
        guard record.type == .tradingPair,
              let symbol = record.symbol,
              let baseCurrency = record.payload["baseCurrency"],
              let quoteCurrency = record.payload["quoteCurrency"],
              let exchangeID = record.payload["exchangeID"],
              let instrumentID = record.payload["instrumentID"],
              let marketTypeRaw = record.payload["marketType"],
              let marketType = KLMarketType(rawValue: marketTypeRaw)
        else { return nil }

        let status = record.payload["status"].flatMap(KLTradingPairStatus.init(rawValue:)) ?? .unknown
        let pricePrecision = record.payload["pricePrecision"].flatMap(Int.init) ?? 0
        let quantityPrecision = record.payload["quantityPrecision"].flatMap(Int.init) ?? 0
        let minOrderSize = record.payload["minOrderSize"].flatMap { value -> KXDecimal? in
            guard !value.isEmpty else { return nil }
            return Decimal(string: value)
        }
        let displayName = record.payload["displayName"] ?? record.name ?? symbol
        let pair = KLTradingPairDescriptor(
            symbol: symbol,
            baseCurrency: baseCurrency,
            quoteCurrency: quoteCurrency,
            exchangeID: exchangeID,
            instrumentID: instrumentID,
            marketType: marketType,
            status: status,
            pricePrecision: pricePrecision,
            quantityPrecision: quantityPrecision,
            minOrderSize: minOrderSize,
            displayName: displayName
        )
        return KLFavoritePairDescriptor(
            id: record.id,
            pair: pair,
            note: record.note,
            sortIndex: record.sortIndex,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    public static func record(from favorite: KLFavoriteTradingPair) -> KXSJ06FavoriteRecordDTO {
        record(from: KLFavoritePairDescriptor(
            id: favorite.id,
            pair: favorite.pair,
            note: favorite.note,
            sortIndex: favorite.sortIndex,
            createdAt: favorite.createdAt
        ))
    }

    public static func favoriteTradingPair(from record: KXSJ06FavoriteRecordDTO) -> KLFavoriteTradingPair? {
        favoritePairDescriptor(from: record).map {
            KLFavoriteTradingPair(
                id: $0.id,
                pair: $0.pair,
                note: $0.note,
                sortIndex: $0.sortIndex,
                createdAt: $0.createdAt
            )
        }
    }

    public static func record(from descriptor: KXTimeframeCombinationDescriptor) -> KXSJ06FavoriteRecordDTO {
        KXSJ06FavoriteRecordDTO(
            id: descriptor.id,
            type: .timeframeCombination,
            symbol: descriptor.symbol,
            name: descriptor.name,
            sortIndex: descriptor.sortIndex,
            payload: ["timeframes": descriptor.timeframes.map(\.rawValue).joined(separator: listSeparator)],
            createdAt: descriptor.createdAt,
            updatedAt: descriptor.updatedAt
        )
    }

    public static func timeframeCombinationDescriptor(from record: KXSJ06FavoriteRecordDTO) -> KXTimeframeCombinationDescriptor? {
        guard record.type == .timeframeCombination,
              let name = record.name
        else { return nil }

        let timeframes = record.payload["timeframes", default: ""]
            .split(separator: Character(listSeparator))
            .compactMap { KXTimeframe(rawValue: String($0)) }

        return KXTimeframeCombinationDescriptor(
            id: record.id,
            name: name,
            timeframes: timeframes,
            symbol: record.symbol,
            sortIndex: record.sortIndex,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    public static func record(
        from combination: KXTimeframeCombination,
        symbol: KXSymbol? = nil,
        sortIndex: Int = 0,
        createdAt: Date = Date()
    ) -> KXSJ06FavoriteRecordDTO {
        record(from: KXTimeframeCombinationDescriptor(
            id: combination.id,
            name: combination.name,
            timeframes: combination.timeframes,
            symbol: symbol,
            sortIndex: sortIndex,
            createdAt: createdAt
        ))
    }

    public static func timeframeCombination(from record: KXSJ06FavoriteRecordDTO) -> KXTimeframeCombination? {
        timeframeCombinationDescriptor(from: record).map {
            KXTimeframeCombination(id: $0.id, name: $0.name, timeframes: $0.timeframes)
        }
    }

    public static func record(from descriptor: KLIndicatorCombinationDescriptor) -> KXSJ06FavoriteRecordDTO {
        KXSJ06FavoriteRecordDTO(
            id: descriptor.id,
            type: .indicatorCombination,
            symbol: descriptor.symbol,
            name: descriptor.name,
            sortIndex: descriptor.sortIndex,
            payload: ["indicatorIDs": descriptor.indicatorIDs.joined(separator: listSeparator)],
            createdAt: descriptor.createdAt,
            updatedAt: descriptor.updatedAt
        )
    }

    public static func indicatorCombinationDescriptor(from record: KXSJ06FavoriteRecordDTO) -> KLIndicatorCombinationDescriptor? {
        guard record.type == .indicatorCombination,
              let name = record.name
        else { return nil }

        let indicatorIDs = record.payload["indicatorIDs", default: ""]
            .split(separator: Character(listSeparator))
            .map(String.init)

        return KLIndicatorCombinationDescriptor(
            id: record.id,
            name: name,
            indicatorIDs: indicatorIDs,
            symbol: record.symbol,
            sortIndex: record.sortIndex,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    public static func record(
        from combination: KLIndicatorCombination,
        symbol: KXSymbol? = nil,
        sortIndex: Int = 0,
        createdAt: Date = Date()
    ) -> KXSJ06FavoriteRecordDTO {
        record(from: KLIndicatorCombinationDescriptor(
            id: combination.id,
            name: combination.name,
            indicatorIDs: combination.indicatorIDs,
            symbol: symbol,
            sortIndex: sortIndex,
            createdAt: createdAt
        ))
    }

    public static func indicatorCombination(from record: KXSJ06FavoriteRecordDTO) -> KLIndicatorCombination? {
        indicatorCombinationDescriptor(from: record).map {
            KLIndicatorCombination(id: $0.id, name: $0.name, indicatorIDs: $0.indicatorIDs)
        }
    }
}

// MARK: - 查询描述便捷构造

public enum KXSJ06FavoriteQueryDescriptorFactory {
    public static func bySymbol(
        _ symbol: KXSymbol,
        type: KXSJ06FavoriteType? = nil,
        order: KXSJ06FavoriteQueryOrder = .sortIndexAscending
    ) -> KXSJ06FavoriteQueryCondition {
        KXSJ06FavoriteQueryCondition(symbol: symbol, type: type, order: order)
    }

    public static func byType(
        _ type: KXSJ06FavoriteType,
        order: KXSJ06FavoriteQueryOrder = .sortIndexAscending
    ) -> KXSJ06FavoriteQueryCondition {
        KXSJ06FavoriteQueryCondition(type: type, order: order)
    }

    public static func byName(
        _ name: String,
        type: KXSJ06FavoriteType? = nil,
        order: KXSJ06FavoriteQueryOrder = .nameAscending
    ) -> KXSJ06FavoriteQueryCondition {
        KXSJ06FavoriteQueryCondition(type: type, name: name, order: order)
    }

    public static func bySortIndex(
        _ condition: KXSJ06FavoriteSortIndexCondition,
        type: KXSJ06FavoriteType? = nil,
        order: KXSJ06FavoriteQueryOrder = .sortIndexAscending
    ) -> KXSJ06FavoriteQueryCondition {
        KXSJ06FavoriteQueryCondition(type: type, sortIndex: condition, order: order)
    }
}
