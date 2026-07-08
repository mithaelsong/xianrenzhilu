//
//  KX-SJ-04_成交明细访问.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：成交明细表纯记录映射和访问请求描述
//  禁止事项：禁止聚合调度实现、禁止 SQL 执行、禁止连接数据库、禁止导入数据库驱动、禁止访问文件系统
//

import Foundation


// MARK: - 成交明细表访问骨架

public enum KXSJ04Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.1"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-04",
        fileName: "KX-SJ-04_成交明细表访问.swift",
        layer: .data,
        relativePath: "数据层/KX-SJ-04_成交明细表访问.swift",
        duty: "成交明细表纯记录映射和访问请求描述"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "成交明细表访问", passed: true, message: "已提供 DTO、查询/写入/删除请求描述与纯映射逻辑，不执行数据库访问")
    }

    public static func placeholder() {
        // 本文件只描述成交明细表记录、访问请求和领域模型映射。
        // 不执行 SQL、不连接数据库、不导入数据库驱动、不访问文件系统。
        // 不实现聚合调度、网络请求、缓存策略或 UI 逻辑。
    }
}

// MARK: - 表结构描述

public enum KXSJ04TradeTickColumn: String, Codable, Sendable, CaseIterable {
    case symbol
    case tradeID = "trade_id"
    case price
    case size
    case side
    case timestamp
    case receivedAt = "received_at"
    case source
}

public enum KXSJ04ConflictPolicy: String, Codable, Sendable, CaseIterable {
    case keepExisting
    case replaceExisting
    case rejectDuplicates
}

public enum KXSJ04WriteIntent: String, Codable, Sendable, CaseIterable {
    case insert
    case upsert
    case replace
}

// MARK: - 记录 DTO

public struct KXSJ04TradeTickRecord: Codable, Equatable, Sendable, Identifiable {
    public let symbol: KXSymbol
    public let tradeID: String
    public let price: KXDecimal
    public let size: KXDecimal
    public let side: KLTradeSide
    public let timestamp: Date
    public let receivedAt: Date?
    public let source: String?

    public var id: String { "\(symbol)#\(tradeID)" }

    public init(
        symbol: KXSymbol,
        tradeID: String,
        price: KXDecimal,
        size: KXDecimal,
        side: KLTradeSide,
        timestamp: Date,
        receivedAt: Date? = nil,
        source: String? = nil
    ) {
        self.symbol = symbol
        self.tradeID = tradeID
        self.price = price
        self.size = size
        self.side = side
        self.timestamp = timestamp
        self.receivedAt = receivedAt
        self.source = source
    }
}

// MARK: - 查询、写入、删除请求描述

public struct KXSJ04TradeTickQueryCondition: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let startTime: Date?
    public let endTime: Date?
    public let side: KLTradeSide?
    public let limit: Int?
    public let order: KLQuerySortOrder

    public init(
        symbol: KXSymbol,
        startTime: Date? = nil,
        endTime: Date? = nil,
        side: KLTradeSide? = nil,
        limit: Int? = nil,
        order: KLQuerySortOrder = .ascending
    ) {
        self.symbol = symbol
        self.startTime = startTime
        self.endTime = endTime
        self.side = side
        self.limit = limit
        self.order = order
    }
}

public struct KXSJ04TradeTickBatchWriteRequest: Codable, Equatable, Sendable {
    public let records: [KXSJ04TradeTickRecord]
    public let intent: KXSJ04WriteIntent
    public let conflictPolicy: KXSJ04ConflictPolicy
    public let requestedAt: Date

    public init(
        records: [KXSJ04TradeTickRecord],
        intent: KXSJ04WriteIntent = .upsert,
        conflictPolicy: KXSJ04ConflictPolicy = .replaceExisting,
        requestedAt: Date = Date()
    ) {
        self.records = records
        self.intent = intent
        self.conflictPolicy = conflictPolicy
        self.requestedAt = requestedAt
    }
}

public struct KXSJ04TradeTickRangeDeleteRequest: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let startTime: Date?
    public let endTime: Date?
    public let side: KLTradeSide?
    public let requestedAt: Date

    public init(
        symbol: KXSymbol,
        startTime: Date? = nil,
        endTime: Date? = nil,
        side: KLTradeSide? = nil,
        requestedAt: Date = Date()
    ) {
        self.symbol = symbol
        self.startTime = startTime
        self.endTime = endTime
        self.side = side
        self.requestedAt = requestedAt
    }
}

public struct KXSJ04TradeTickResultSummary: Codable, Equatable, Sendable {
    public let matchedCount: Int
    public let insertedCount: Int
    public let updatedCount: Int
    public let deletedCount: Int
    public let skippedCount: Int
    public let failedCount: Int
    public let message: String?

    public init(
        matchedCount: Int = 0,
        insertedCount: Int = 0,
        updatedCount: Int = 0,
        deletedCount: Int = 0,
        skippedCount: Int = 0,
        failedCount: Int = 0,
        message: String? = nil
    ) {
        self.matchedCount = matchedCount
        self.insertedCount = insertedCount
        self.updatedCount = updatedCount
        self.deletedCount = deletedCount
        self.skippedCount = skippedCount
        self.failedCount = failedCount
        self.message = message
    }
}

// MARK: - 访问接口描述

public protocol KXSJ04TradeTickTableAccessProtocol {
    func describeTradeTickQuery(_ condition: KXSJ04TradeTickQueryCondition) -> KXSJ04TradeTickQueryCondition
    func describeTradeTickBatchWrite(_ request: KXSJ04TradeTickBatchWriteRequest) -> KXSJ04TradeTickBatchWriteRequest
    func describeTradeTickRangeDelete(_ request: KXSJ04TradeTickRangeDeleteRequest) -> KXSJ04TradeTickRangeDeleteRequest
}

// MARK: - 纯映射逻辑

public enum KXSJ04TradeTickMapper {
    public static func record(from tick: KLTradeTick, receivedAt: Date? = nil, source: String? = nil) -> KXSJ04TradeTickRecord {
        KXSJ04TradeTickRecord(
            symbol: tick.symbol,
            tradeID: tick.tradeID,
            price: tick.price,
            size: tick.size,
            side: tick.side,
            timestamp: tick.timestamp,
            receivedAt: receivedAt,
            source: source
        )
    }

    public static func tradeTick(from record: KXSJ04TradeTickRecord) -> KLTradeTick {
        KLTradeTick(
            symbol: record.symbol,
            tradeID: record.tradeID,
            price: record.price,
            size: record.size,
            side: record.side,
            timestamp: record.timestamp
        )
    }

    public static func records(from ticks: [KLTradeTick], receivedAt: Date? = nil, source: String? = nil) -> [KXSJ04TradeTickRecord] {
        ticks.map { record(from: $0, receivedAt: receivedAt, source: source) }
    }

    public static func tradeTicks(from records: [KXSJ04TradeTickRecord]) -> [KLTradeTick] {
        records.map { tradeTick(from: $0) }
    }

    public static func recordFromTickTrade(_ tickTrade: KLTradeTick, receivedAt: Date? = nil, source: String? = nil) -> KXSJ04TradeTickRecord {
        record(from: tickTrade, receivedAt: receivedAt, source: source)
    }

    public static func tickTrade(from record: KXSJ04TradeTickRecord) -> KLTradeTick {
        tradeTick(from: record)
    }
}
