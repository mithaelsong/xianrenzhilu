//
//  KX-SJ-03_OHLCV表访问.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：标准 K线 OHLCV 表读写接口骨架
//  禁止事项：禁止聚合算法、禁止 UI 绘制、禁止执行 SQL、禁止连接数据库、禁止导入数据库驱动
//

import Foundation


// MARK: - OHLCV 表基础描述

public enum KXSJ03OHLCVTable: String, Codable, Sendable, CaseIterable {
    case candlesOHLCV = "kl_candles_ohlcv"

    public var tableName: String { rawValue }

    public var primaryKeyColumns: [String] {
        ["symbol", "timeframe", "open_time"]
    }

    public var columns: [String] {
        [
            "symbol",
            "timeframe",
            "open_time",
            "close_time",
            "open",
            "high",
            "low",
            "close",
            "volume",
            "quote_volume",
            "trade_count",
            "is_closed",
            "source",
            "created_at",
            "updated_at"
        ]
    }

    public var createTableSQLDescription: String {
        """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            symbol TEXT NOT NULL,
            timeframe TEXT NOT NULL,
            open_time TIMESTAMP NOT NULL,
            close_time TIMESTAMP,
            open NUMERIC NOT NULL,
            high NUMERIC NOT NULL,
            low NUMERIC NOT NULL,
            close NUMERIC NOT NULL,
            volume NUMERIC NOT NULL,
            quote_volume NUMERIC,
            trade_count INTEGER,
            is_closed BOOLEAN NOT NULL,
            source TEXT,
            created_at TIMESTAMP NOT NULL,
            updated_at TIMESTAMP NOT NULL,
            PRIMARY KEY (symbol, timeframe, open_time)
        );
        """
    }
}

public enum KXSJ03OHLCVColumn: String, Codable, Sendable, CaseIterable {
    case symbol = "symbol"
    case timeframe = "timeframe"
    case openTime = "open_time"
    case closeTime = "close_time"
    case open = "open"
    case high = "high"
    case low = "low"
    case close = "close"
    case volume = "volume"
    case quoteVolume = "quote_volume"
    case tradeCount = "trade_count"
    case isClosed = "is_closed"
    case source = "source"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
}

// MARK: - 主键与记录 DTO

public struct KXSJ03OHLCVPrimaryKey: Codable, Hashable, Sendable, CustomStringConvertible {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let openTime: Date

    public init(symbol: KXSymbol, timeframe: KXTimeframe, openTime: Date) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.openTime = openTime
    }

    public var description: String {
        "\(symbol)|\(timeframe.rawValue)|\(openTime.timeIntervalSince1970)"
    }

    public var candleID: KLCandleID {
        description
    }
}

public struct KXSJ03OHLCVRecord: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let openTime: Date
    public let closeTime: Date?
    public let open: KXDecimal
    public let high: KXDecimal
    public let low: KXDecimal
    public let close: KXDecimal
    public let volume: KXDecimal
    public let quoteVolume: KXDecimal?
    public let tradeCount: Int?
    public let isClosed: Bool
    public let source: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(symbol: KXSymbol, timeframe: KXTimeframe, openTime: Date, closeTime: Date? = nil, open: KXDecimal, high: KXDecimal, low: KXDecimal, close: KXDecimal, volume: KXDecimal, quoteVolume: KXDecimal? = nil, tradeCount: Int? = nil, isClosed: Bool, source: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.openTime = openTime
        self.closeTime = closeTime
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.quoteVolume = quoteVolume
        self.tradeCount = tradeCount
        self.isClosed = isClosed
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var primaryKey: KXSJ03OHLCVPrimaryKey {
        KXSJ03OHLCVPrimaryKey(symbol: symbol, timeframe: timeframe, openTime: openTime)
    }

    public var columnValueDescriptions: [String: String] {
        [
            KXSJ03OHLCVColumn.symbol.rawValue: symbol,
            KXSJ03OHLCVColumn.timeframe.rawValue: timeframe.rawValue,
            KXSJ03OHLCVColumn.openTime.rawValue: KXSJ03SQLValueFormatter.date(openTime),
            KXSJ03OHLCVColumn.closeTime.rawValue: KXSJ03SQLValueFormatter.optionalDate(closeTime),
            KXSJ03OHLCVColumn.open.rawValue: KXSJ03SQLValueFormatter.decimal(open),
            KXSJ03OHLCVColumn.high.rawValue: KXSJ03SQLValueFormatter.decimal(high),
            KXSJ03OHLCVColumn.low.rawValue: KXSJ03SQLValueFormatter.decimal(low),
            KXSJ03OHLCVColumn.close.rawValue: KXSJ03SQLValueFormatter.decimal(close),
            KXSJ03OHLCVColumn.volume.rawValue: KXSJ03SQLValueFormatter.decimal(volume),
            KXSJ03OHLCVColumn.quoteVolume.rawValue: KXSJ03SQLValueFormatter.optionalDecimal(quoteVolume),
            KXSJ03OHLCVColumn.tradeCount.rawValue: KXSJ03SQLValueFormatter.optionalInt(tradeCount),
            KXSJ03OHLCVColumn.isClosed.rawValue: KXSJ03SQLValueFormatter.bool(isClosed),
            KXSJ03OHLCVColumn.source.rawValue: KXSJ03SQLValueFormatter.optionalString(source),
            KXSJ03OHLCVColumn.createdAt.rawValue: KXSJ03SQLValueFormatter.date(createdAt),
            KXSJ03OHLCVColumn.updatedAt.rawValue: KXSJ03SQLValueFormatter.date(updatedAt)
        ]
    }
}

// MARK: - 查询、写入、删除请求描述

public struct KXSJ03OHLCVQueryCondition: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let startTime: Date?
    public let endTime: Date?
    public let limit: Int?
    public let order: KLQuerySortOrder
    public let includeUnclosed: Bool

    public init(symbol: KXSymbol, timeframe: KXTimeframe, startTime: Date? = nil, endTime: Date? = nil, limit: Int? = nil, order: KLQuerySortOrder = .ascending, includeUnclosed: Bool = true) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.startTime = startTime
        self.endTime = endTime
        self.limit = limit
        self.order = order
        self.includeUnclosed = includeUnclosed
    }

    public init(query: KLKLineQuery) {
        self.init(
            symbol: query.symbol,
            timeframe: query.timeframe,
            startTime: query.startTime,
            endTime: query.endTime,
            limit: query.limit,
            order: query.order,
            includeUnclosed: query.includeUnclosed
        )
    }

    public var normalizedLimit: Int? {
        guard let limit else { return nil }
        return max(0, limit)
    }

    public var orderSQLKeyword: String {
        switch order {
        case .ascending:
            return "ASC"
        case .descending:
            return "DESC"
        }
    }

    public func sqlDescription(table: KXSJ03OHLCVTable = .candlesOHLCV) -> KXSJ03SQLDescription {
        KXSJ03SQLDescription.select(table: table, condition: self)
    }
}

public enum KXSJ03OHLCVUpsertConflictPolicy: String, Codable, Sendable, CaseIterable {
    case updateExisting
    case ignoreExisting
}

public struct KXSJ03OHLCVBatchUpsertRequest: Codable, Equatable, Sendable {
    public let records: [KXSJ03OHLCVRecord]
    public let conflictPolicy: KXSJ03OHLCVUpsertConflictPolicy
    public let requestedAt: Date
    public let requestID: String?

    public init(records: [KXSJ03OHLCVRecord], conflictPolicy: KXSJ03OHLCVUpsertConflictPolicy = .updateExisting, requestedAt: Date = Date(), requestID: String? = nil) {
        self.records = records
        self.conflictPolicy = conflictPolicy
        self.requestedAt = requestedAt
        self.requestID = requestID
    }

    public var recordCount: Int { records.count }

    public var primaryKeys: [KXSJ03OHLCVPrimaryKey] {
        records.map { $0.primaryKey }
    }

    public func sqlDescription(table: KXSJ03OHLCVTable = .candlesOHLCV) -> KXSJ03SQLDescription {
        KXSJ03SQLDescription.upsert(table: table, request: self)
    }
}

public struct KXSJ03OHLCVDeleteRangeRequest: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let startTime: Date?
    public let endTime: Date?
    public let includeStart: Bool
    public let includeEnd: Bool
    public let requestedAt: Date
    public let requestID: String?

    public init(symbol: KXSymbol, timeframe: KXTimeframe, startTime: Date? = nil, endTime: Date? = nil, includeStart: Bool = true, includeEnd: Bool = true, requestedAt: Date = Date(), requestID: String? = nil) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.startTime = startTime
        self.endTime = endTime
        self.includeStart = includeStart
        self.includeEnd = includeEnd
        self.requestedAt = requestedAt
        self.requestID = requestID
    }

    public func sqlDescription(table: KXSJ03OHLCVTable = .candlesOHLCV) -> KXSJ03SQLDescription {
        KXSJ03SQLDescription.delete(table: table, request: self)
    }
}

// MARK: - 读写结果摘要

public enum KXSJ03OHLCVAccessOperation: String, Codable, Sendable, CaseIterable {
    case query
    case batchUpsert
    case deleteRange
    case describeSQL
}

public struct KXSJ03OHLCVAccessSummary: Codable, Equatable, Sendable {
    public let operation: KXSJ03OHLCVAccessOperation
    public let requestedCount: Int
    public let returnedCount: Int
    public let affectedCount: Int
    public let skippedCount: Int
    public let errorMessages: [String]
    public let startedAt: Date
    public let finishedAt: Date

    public init(operation: KXSJ03OHLCVAccessOperation, requestedCount: Int = 0, returnedCount: Int = 0, affectedCount: Int = 0, skippedCount: Int = 0, errorMessages: [String] = [], startedAt: Date = Date(), finishedAt: Date = Date()) {
        self.operation = operation
        self.requestedCount = requestedCount
        self.returnedCount = returnedCount
        self.affectedCount = affectedCount
        self.skippedCount = skippedCount
        self.errorMessages = errorMessages
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    public var succeeded: Bool {
        errorMessages.isEmpty
    }

    public var durationSeconds: TimeInterval {
        finishedAt.timeIntervalSince(startedAt)
    }
}

// MARK: - KLCandlePoint <-> OHLCV Record 纯映射

public enum KXSJ03OHLCVRecordMapper {
    public static func record(from candle: KLCandlePoint, createdAt: Date = Date(), updatedAt: Date = Date()) -> KXSJ03OHLCVRecord {
        KXSJ03OHLCVRecord(
            symbol: candle.symbol,
            timeframe: candle.timeframe,
            openTime: candle.openTime,
            closeTime: candle.closeTime,
            open: candle.open,
            high: candle.high,
            low: candle.low,
            close: candle.close,
            volume: candle.volume,
            quoteVolume: candle.quoteVolume,
            tradeCount: candle.tradeCount,
            isClosed: candle.isClosed,
            source: candle.source,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public static func records(from candles: [KLCandlePoint], createdAt: Date = Date(), updatedAt: Date = Date()) -> [KXSJ03OHLCVRecord] {
        candles.map { record(from: $0, createdAt: createdAt, updatedAt: updatedAt) }
    }

    public static func candlePoint(from record: KXSJ03OHLCVRecord) -> KLCandlePoint {
        KLCandlePoint(
            id: record.primaryKey.candleID,
            symbol: record.symbol,
            timeframe: record.timeframe,
            openTime: record.openTime,
            closeTime: record.closeTime,
            open: record.open,
            high: record.high,
            low: record.low,
            close: record.close,
            volume: record.volume,
            quoteVolume: record.quoteVolume,
            tradeCount: record.tradeCount,
            isClosed: record.isClosed,
            source: record.source
        )
    }

    public static func candlePoints(from records: [KXSJ03OHLCVRecord]) -> [KLCandlePoint] {
        records.map { candlePoint(from: $0) }
    }

    public static func queryCondition(from query: KLKLineQuery) -> KXSJ03OHLCVQueryCondition {
        KXSJ03OHLCVQueryCondition(query: query)
    }
}

// MARK: - SQL 描述字符串（只描述，不执行）

public struct KXSJ03SQLParameter: Codable, Equatable, Sendable {
    public let name: String
    public let valueDescription: String

    public init(name: String, valueDescription: String) {
        self.name = name
        self.valueDescription = valueDescription
    }
}

public struct KXSJ03SQLDescription: Codable, Equatable, Sendable {
    public let statement: String
    public let parameters: [KXSJ03SQLParameter]
    public let note: String

    public init(statement: String, parameters: [KXSJ03SQLParameter] = [], note: String = "仅为 SQL 描述字符串，不执行、不连接数据库") {
        self.statement = statement
        self.parameters = parameters
        self.note = note
    }

    public static func select(table: KXSJ03OHLCVTable, condition: KXSJ03OHLCVQueryCondition) -> KXSJ03SQLDescription {
        var whereParts: [String] = ["symbol = :symbol", "timeframe = :timeframe"]
        var parameters: [KXSJ03SQLParameter] = [
            KXSJ03SQLParameter(name: "symbol", valueDescription: condition.symbol),
            KXSJ03SQLParameter(name: "timeframe", valueDescription: condition.timeframe.rawValue)
        ]

        if let startTime = condition.startTime {
            whereParts.append("open_time >= :start_time")
            parameters.append(KXSJ03SQLParameter(name: "start_time", valueDescription: KXSJ03SQLValueFormatter.date(startTime)))
        }

        if let endTime = condition.endTime {
            whereParts.append("open_time <= :end_time")
            parameters.append(KXSJ03SQLParameter(name: "end_time", valueDescription: KXSJ03SQLValueFormatter.date(endTime)))
        }

        if !condition.includeUnclosed {
            whereParts.append("is_closed = TRUE")
        }

        let limitPart: String
        if let limit = condition.normalizedLimit, limit > 0 {
            limitPart = "\nLIMIT :limit"
            parameters.append(KXSJ03SQLParameter(name: "limit", valueDescription: "\(limit)"))
        } else {
            limitPart = ""
        }

        let statement = """
        SELECT \(table.columns.joined(separator: ", "))
        FROM \(table.tableName)
        WHERE \(whereParts.joined(separator: " AND "))
        ORDER BY open_time \(condition.orderSQLKeyword)\(limitPart);
        """

        return KXSJ03SQLDescription(statement: statement, parameters: parameters)
    }

    public static func upsert(table: KXSJ03OHLCVTable, request: KXSJ03OHLCVBatchUpsertRequest) -> KXSJ03SQLDescription {
        let columns = table.columns
        let placeholders = columns.map { ":\($0)" }.joined(separator: ", ")
        let conflictColumns = table.primaryKeyColumns.joined(separator: ", ")
        let updateColumns = columns.filter { !table.primaryKeyColumns.contains($0) }
        let conflictAction: String

        switch request.conflictPolicy {
        case .updateExisting:
            let assignments = updateColumns.map { "\($0) = excluded.\($0)" }.joined(separator: ", ")
            conflictAction = "DO UPDATE SET \(assignments)"
        case .ignoreExisting:
            conflictAction = "DO NOTHING"
        }

        let statement = """
        INSERT INTO \(table.tableName) (\(columns.joined(separator: ", ")))
        VALUES (\(placeholders))
        ON CONFLICT (\(conflictColumns)) \(conflictAction);
        """

        let parameters = [
            KXSJ03SQLParameter(name: "record_count", valueDescription: "\(request.recordCount)"),
            KXSJ03SQLParameter(name: "conflict_policy", valueDescription: request.conflictPolicy.rawValue),
            KXSJ03SQLParameter(name: "requested_at", valueDescription: KXSJ03SQLValueFormatter.date(request.requestedAt))
        ]

        return KXSJ03SQLDescription(statement: statement, parameters: parameters, note: "批量 upsert SQL 模板描述；records 仅作为 DTO，不在本文件执行")
    }

    public static func delete(table: KXSJ03OHLCVTable, request: KXSJ03OHLCVDeleteRangeRequest) -> KXSJ03SQLDescription {
        var whereParts: [String] = ["symbol = :symbol", "timeframe = :timeframe"]
        var parameters: [KXSJ03SQLParameter] = [
            KXSJ03SQLParameter(name: "symbol", valueDescription: request.symbol),
            KXSJ03SQLParameter(name: "timeframe", valueDescription: request.timeframe.rawValue)
        ]

        if let startTime = request.startTime {
            whereParts.append("open_time \(request.includeStart ? ">=" : ">") :start_time")
            parameters.append(KXSJ03SQLParameter(name: "start_time", valueDescription: KXSJ03SQLValueFormatter.date(startTime)))
        }

        if let endTime = request.endTime {
            whereParts.append("open_time \(request.includeEnd ? "<=" : "<") :end_time")
            parameters.append(KXSJ03SQLParameter(name: "end_time", valueDescription: KXSJ03SQLValueFormatter.date(endTime)))
        }

        let statement = """
        DELETE FROM \(table.tableName)
        WHERE \(whereParts.joined(separator: " AND "));
        """

        return KXSJ03SQLDescription(statement: statement, parameters: parameters)
    }
}

public enum KXSJ03SQLValueFormatter {
    public static func string(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "''"))'"
    }

    public static func optionalString(_ value: String?) -> String {
        guard let value else { return "NULL" }
        return string(value)
    }

    public static func date(_ value: Date) -> String {
        "\(value.timeIntervalSince1970)"
    }

    public static func optionalDate(_ value: Date?) -> String {
        guard let value else { return "NULL" }
        return date(value)
    }

    public static func decimal(_ value: KXDecimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    public static func optionalDecimal(_ value: KXDecimal?) -> String {
        guard let value else { return "NULL" }
        return decimal(value)
    }

    public static func optionalInt(_ value: Int?) -> String {
        guard let value else { return "NULL" }
        return "\(value)"
    }

    public static func bool(_ value: Bool) -> String {
        value ? "TRUE" : "FALSE"
    }
}

// MARK: - K线OHLCV表访问骨架

public enum KXSJ03Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-03",
        fileName: "KX-SJ-03_K线OHLCV表访问.swift",
        layer: .data,
        relativePath: "数据层/KX-SJ-03_K线OHLCV表访问.swift",
        duty: "标准 K线 OHLCV 表读写接口骨架"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "K线OHLCV表访问", passed: true, message: "已升级为纯记录映射与访问请求描述：DTO、主键、查询、批量 upsert、删除范围、结果摘要、SQL 描述均已具备")
    }

    public static func placeholder() {
        // 本文件只描述标准 K线 OHLCV 表访问边界。
        // 不执行 SQL、不连接数据库、不导入数据库驱动。
        // KLCandlePoint 与 KXSJ03OHLCVRecord 的转换由 KXSJ03OHLCVRecordMapper 纯映射完成。
    }
}
