//
//  KX-SJ-02_交易对目录访问.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：交易对目录表读写接口骨架
//  禁止事项：禁止 OKX 请求、禁止 UI 适配
//

import Foundation


// MARK: - 交易对目录表记录 DTO

public struct KLTradingPairDirectoryRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: KXSymbol
    public let symbol: KXSymbol
    public let baseCurrency: String
    public let quoteCurrency: String
    public let exchangeID: KLExchangeID
    public let instrumentID: KLInstrumentID
    public let marketTypeRawValue: String
    public let statusRawValue: String
    public let pricePrecision: Int
    public let quantityPrecision: Int
    public let minOrderSize: KXDecimal?
    public let displayName: String
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        symbol: KXSymbol,
        baseCurrency: String,
        quoteCurrency: String,
        exchangeID: KLExchangeID,
        instrumentID: KLInstrumentID,
        marketTypeRawValue: String,
        statusRawValue: String,
        pricePrecision: Int,
        quantityPrecision: Int,
        minOrderSize: KXDecimal? = nil,
        displayName: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = symbol
        self.symbol = symbol
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.exchangeID = exchangeID
        self.instrumentID = instrumentID
        self.marketTypeRawValue = marketTypeRawValue
        self.statusRawValue = statusRawValue
        self.pricePrecision = pricePrecision
        self.quantityPrecision = quantityPrecision
        self.minOrderSize = minOrderSize
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 查询条件、写入请求、变更结果

public struct KLTradingPairDirectoryQueryCondition: Codable, Equatable, Sendable {
    public let symbols: [KXSymbol]?
    public let exchangeID: KLExchangeID?
    public let instrumentID: KLInstrumentID?
    public let baseCurrency: String?
    public let quoteCurrency: String?
    public let marketType: KLMarketType?
    public let status: KLTradingPairStatus?
    public let keyword: String?

    public init(
        symbols: [KXSymbol]? = nil,
        exchangeID: KLExchangeID? = nil,
        instrumentID: KLInstrumentID? = nil,
        baseCurrency: String? = nil,
        quoteCurrency: String? = nil,
        marketType: KLMarketType? = nil,
        status: KLTradingPairStatus? = nil,
        keyword: String? = nil
    ) {
        self.symbols = symbols
        self.exchangeID = exchangeID
        self.instrumentID = instrumentID
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.marketType = marketType
        self.status = status
        self.keyword = keyword
    }
}

public struct KLTradingPairDirectoryListRequest: Codable, Equatable, Sendable {
    public let condition: KLTradingPairDirectoryQueryCondition
    public let limit: Int?
    public let offset: Int?
    public let order: KLQuerySortOrder

    public init(
        condition: KLTradingPairDirectoryQueryCondition = KLTradingPairDirectoryQueryCondition(),
        limit: Int? = nil,
        offset: Int? = nil,
        order: KLQuerySortOrder = .ascending
    ) {
        self.condition = condition
        self.limit = limit
        self.offset = offset
        self.order = order
    }
}

public struct KLTradingPairDirectoryUpsertRequest: Codable, Equatable, Sendable {
    public let records: [KLTradingPairDirectoryRecord]
    public let requestedAt: Date?
    public let source: String?

    public init(records: [KLTradingPairDirectoryRecord], requestedAt: Date? = nil, source: String? = nil) {
        self.records = records
        self.requestedAt = requestedAt
        self.source = source
    }
}

public struct KLTradingPairDirectoryDeleteRequest: Codable, Equatable, Sendable {
    public let symbols: [KXSymbol]
    public let requestedAt: Date?
    public let reason: String?

    public init(symbols: [KXSymbol], requestedAt: Date? = nil, reason: String? = nil) {
        self.symbols = symbols
        self.requestedAt = requestedAt
        self.reason = reason
    }
}

public enum KLTradingPairDirectoryMutationKind: String, Codable, Sendable, CaseIterable {
    case upsert
    case delete
}

public struct KLTradingPairDirectoryMutationResult: Codable, Equatable, Sendable {
    public let kind: KLTradingPairDirectoryMutationKind
    public let requestedCount: Int
    public let affectedSymbols: [KXSymbol]
    public let skippedSymbols: [KXSymbol]
    public let message: String

    public init(
        kind: KLTradingPairDirectoryMutationKind,
        requestedCount: Int,
        affectedSymbols: [KXSymbol],
        skippedSymbols: [KXSymbol] = [],
        message: String
    ) {
        self.kind = kind
        self.requestedCount = requestedCount
        self.affectedSymbols = affectedSymbols
        self.skippedSymbols = skippedSymbols
        self.message = message
    }
}

// MARK: - 表描述与 SQL 描述字符串（仅描述，不执行）

public struct KLTradingPairDirectoryColumnDescription: Codable, Equatable, Sendable {
    public let name: String
    public let storageType: String
    public let isPrimaryKey: Bool
    public let isRequired: Bool
    public let note: String

    public init(name: String, storageType: String, isPrimaryKey: Bool = false, isRequired: Bool = true, note: String = "") {
        self.name = name
        self.storageType = storageType
        self.isPrimaryKey = isPrimaryKey
        self.isRequired = isRequired
        self.note = note
    }
}

public struct KLTradingPairDirectoryTableDescription: Codable, Equatable, Sendable {
    public let tableName: String
    public let primaryKey: String
    public let columns: [KLTradingPairDirectoryColumnDescription]
    public let createTableSQL: String
    public let upsertSQL: String
    public let deleteSQL: String
    public let listSQL: String
    public let filterSQLTemplate: String

    public init(
        tableName: String,
        primaryKey: String,
        columns: [KLTradingPairDirectoryColumnDescription],
        createTableSQL: String,
        upsertSQL: String,
        deleteSQL: String,
        listSQL: String,
        filterSQLTemplate: String
    ) {
        self.tableName = tableName
        self.primaryKey = primaryKey
        self.columns = columns
        self.createTableSQL = createTableSQL
        self.upsertSQL = upsertSQL
        self.deleteSQL = deleteSQL
        self.listSQL = listSQL
        self.filterSQLTemplate = filterSQLTemplate
    }
}

public enum KLTradingPairDirectoryTableCatalog {
    public static let description = KLTradingPairDirectoryTableDescription(
        tableName: "kl_trading_pair_directory",
        primaryKey: "symbol",
        columns: [
            KLTradingPairDirectoryColumnDescription(name: "symbol", storageType: "TEXT", isPrimaryKey: true, note: "模块内交易对唯一键"),
            KLTradingPairDirectoryColumnDescription(name: "base_currency", storageType: "TEXT", note: "基础币种"),
            KLTradingPairDirectoryColumnDescription(name: "quote_currency", storageType: "TEXT", note: "计价币种"),
            KLTradingPairDirectoryColumnDescription(name: "exchange_id", storageType: "TEXT", note: "交易所标识"),
            KLTradingPairDirectoryColumnDescription(name: "instrument_id", storageType: "TEXT", note: "交易所原始合约/产品 ID"),
            KLTradingPairDirectoryColumnDescription(name: "market_type", storageType: "TEXT", note: "KLMarketType.rawValue"),
            KLTradingPairDirectoryColumnDescription(name: "status", storageType: "TEXT", note: "KLTradingPairStatus.rawValue"),
            KLTradingPairDirectoryColumnDescription(name: "price_precision", storageType: "INTEGER", note: "价格精度"),
            KLTradingPairDirectoryColumnDescription(name: "quantity_precision", storageType: "INTEGER", note: "数量精度"),
            KLTradingPairDirectoryColumnDescription(name: "min_order_size", storageType: "DECIMAL", isRequired: false, note: "最小下单量"),
            KLTradingPairDirectoryColumnDescription(name: "display_name", storageType: "TEXT", note: "展示名称"),
            KLTradingPairDirectoryColumnDescription(name: "created_at", storageType: "TIMESTAMP", isRequired: false, note: "创建时间"),
            KLTradingPairDirectoryColumnDescription(name: "updated_at", storageType: "TIMESTAMP", isRequired: false, note: "更新时间")
        ],
        createTableSQL: """
        CREATE TABLE IF NOT EXISTS kl_trading_pair_directory (
            symbol TEXT PRIMARY KEY,
            base_currency TEXT NOT NULL,
            quote_currency TEXT NOT NULL,
            exchange_id TEXT NOT NULL,
            instrument_id TEXT NOT NULL,
            market_type TEXT NOT NULL,
            status TEXT NOT NULL,
            price_precision INTEGER NOT NULL,
            quantity_precision INTEGER NOT NULL,
            min_order_size DECIMAL,
            display_name TEXT NOT NULL,
            created_at TIMESTAMP,
            updated_at TIMESTAMP
        );
        """,
        upsertSQL: """
        INSERT INTO kl_trading_pair_directory (
            symbol, base_currency, quote_currency, exchange_id, instrument_id,
            market_type, status, price_precision, quantity_precision,
            min_order_size, display_name, created_at, updated_at
        ) VALUES (
            :symbol, :base_currency, :quote_currency, :exchange_id, :instrument_id,
            :market_type, :status, :price_precision, :quantity_precision,
            :min_order_size, :display_name, :created_at, :updated_at
        ) ON CONFLICT(symbol) DO UPDATE SET
            base_currency = excluded.base_currency,
            quote_currency = excluded.quote_currency,
            exchange_id = excluded.exchange_id,
            instrument_id = excluded.instrument_id,
            market_type = excluded.market_type,
            status = excluded.status,
            price_precision = excluded.price_precision,
            quantity_precision = excluded.quantity_precision,
            min_order_size = excluded.min_order_size,
            display_name = excluded.display_name,
            updated_at = excluded.updated_at;
        """,
        deleteSQL: "DELETE FROM kl_trading_pair_directory WHERE symbol IN (:symbols);",
        listSQL: "SELECT * FROM kl_trading_pair_directory ORDER BY symbol ASC LIMIT :limit OFFSET :offset;",
        filterSQLTemplate: """
        SELECT * FROM kl_trading_pair_directory
        WHERE (:exchange_id IS NULL OR exchange_id = :exchange_id)
          AND (:instrument_id IS NULL OR instrument_id = :instrument_id)
          AND (:base_currency IS NULL OR base_currency = :base_currency)
          AND (:quote_currency IS NULL OR quote_currency = :quote_currency)
          AND (:market_type IS NULL OR market_type = :market_type)
          AND (:status IS NULL OR status = :status)
          AND (:keyword IS NULL OR symbol LIKE :keyword OR display_name LIKE :keyword)
        ORDER BY symbol :order
        LIMIT :limit OFFSET :offset;
        """
    )
}

// MARK: - KLTradingPairDescriptor <-> 表记录纯映射

public enum KLTradingPairDirectoryMapper {
    public static func makeRecord(
        from descriptor: KLTradingPairDescriptor,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) -> KLTradingPairDirectoryRecord {
        KLTradingPairDirectoryRecord(
            symbol: descriptor.symbol,
            baseCurrency: descriptor.baseCurrency,
            quoteCurrency: descriptor.quoteCurrency,
            exchangeID: descriptor.exchangeID,
            instrumentID: descriptor.instrumentID,
            marketTypeRawValue: descriptor.marketType.rawValue,
            statusRawValue: descriptor.status.rawValue,
            pricePrecision: descriptor.pricePrecision,
            quantityPrecision: descriptor.quantityPrecision,
            minOrderSize: descriptor.minOrderSize,
            displayName: descriptor.displayName,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public static func makeDescriptor(from record: KLTradingPairDirectoryRecord) -> KLTradingPairDescriptor {
        KLTradingPairDescriptor(
            symbol: record.symbol,
            baseCurrency: record.baseCurrency,
            quoteCurrency: record.quoteCurrency,
            exchangeID: record.exchangeID,
            instrumentID: record.instrumentID,
            marketType: KLMarketType(rawValue: record.marketTypeRawValue) ?? .spot,
            status: KLTradingPairStatus(rawValue: record.statusRawValue) ?? .unknown,
            pricePrecision: record.pricePrecision,
            quantityPrecision: record.quantityPrecision,
            minOrderSize: record.minOrderSize,
            displayName: record.displayName
        )
    }

    public static func makeRecords(from descriptors: [KLTradingPairDescriptor]) -> [KLTradingPairDirectoryRecord] {
        descriptors.map { makeRecord(from: $0) }
    }

    public static func makeDescriptors(from records: [KLTradingPairDirectoryRecord]) -> [KLTradingPairDescriptor] {
        records.map { makeDescriptor(from: $0) }
    }
}

// MARK: - 访问协议与内存计划（只描述动作，不连接数据库）

public protocol KLTradingPairDirectoryTableAccessProtocol {
    func upsertTradingPairs(_ request: KLTradingPairDirectoryUpsertRequest) async throws -> KLTradingPairDirectoryMutationResult
    func deleteTradingPairs(_ request: KLTradingPairDirectoryDeleteRequest) async throws -> KLTradingPairDirectoryMutationResult
    func listTradingPairs(_ request: KLTradingPairDirectoryListRequest) async throws -> [KLTradingPairDirectoryRecord]
    func filterTradingPairs(_ condition: KLTradingPairDirectoryQueryCondition) async throws -> [KLTradingPairDirectoryRecord]
}

public enum KLTradingPairDirectoryOperation: String, Codable, Sendable, CaseIterable {
    case upsert
    case delete
    case list
    case filter
}

public struct KLTradingPairDirectoryAccessPlan: Codable, Equatable, Sendable {
    public let operation: KLTradingPairDirectoryOperation
    public let tableName: String
    public let sqlDescription: String
    public let affectedSymbols: [KXSymbol]
    public let condition: KLTradingPairDirectoryQueryCondition?
    public let note: String

    public init(
        operation: KLTradingPairDirectoryOperation,
        tableName: String = KLTradingPairDirectoryTableCatalog.description.tableName,
        sqlDescription: String,
        affectedSymbols: [KXSymbol] = [],
        condition: KLTradingPairDirectoryQueryCondition? = nil,
        note: String
    ) {
        self.operation = operation
        self.tableName = tableName
        self.sqlDescription = sqlDescription
        self.affectedSymbols = affectedSymbols
        self.condition = condition
        self.note = note
    }
}

public enum KLTradingPairDirectoryPlanBuilder {
    public static func makeUpsertPlan(_ request: KLTradingPairDirectoryUpsertRequest) -> KLTradingPairDirectoryAccessPlan {
        KLTradingPairDirectoryAccessPlan(
            operation: .upsert,
            sqlDescription: KLTradingPairDirectoryTableCatalog.description.upsertSQL,
            affectedSymbols: request.records.map(\.symbol),
            note: "仅生成交易对目录 upsert 计划，不执行数据库写入。"
        )
    }

    public static func makeDeletePlan(_ request: KLTradingPairDirectoryDeleteRequest) -> KLTradingPairDirectoryAccessPlan {
        KLTradingPairDirectoryAccessPlan(
            operation: .delete,
            sqlDescription: KLTradingPairDirectoryTableCatalog.description.deleteSQL,
            affectedSymbols: request.symbols,
            note: "仅生成交易对目录 delete 计划，不执行数据库删除。"
        )
    }

    public static func makeListPlan(_ request: KLTradingPairDirectoryListRequest) -> KLTradingPairDirectoryAccessPlan {
        KLTradingPairDirectoryAccessPlan(
            operation: .list,
            sqlDescription: KLTradingPairDirectoryTableCatalog.description.listSQL,
            condition: request.condition,
            note: "仅生成交易对目录 list 计划，不执行数据库读取。"
        )
    }

    public static func makeFilterPlan(_ condition: KLTradingPairDirectoryQueryCondition) -> KLTradingPairDirectoryAccessPlan {
        KLTradingPairDirectoryAccessPlan(
            operation: .filter,
            sqlDescription: KLTradingPairDirectoryTableCatalog.description.filterSQLTemplate,
            condition: condition,
            note: "仅生成交易对目录 filter 计划，不执行数据库读取。"
        )
    }
}

// MARK: - 纯内存过滤辅助

public enum KLTradingPairDirectoryRecordFilter {
    public static func matches(_ record: KLTradingPairDirectoryRecord, condition: KLTradingPairDirectoryQueryCondition) -> Bool {
        if let symbols = condition.symbols, !symbols.isEmpty, !symbols.contains(record.symbol) { return false }
        if let exchangeID = condition.exchangeID, record.exchangeID != exchangeID { return false }
        if let instrumentID = condition.instrumentID, record.instrumentID != instrumentID { return false }
        if let baseCurrency = condition.baseCurrency, record.baseCurrency != baseCurrency { return false }
        if let quoteCurrency = condition.quoteCurrency, record.quoteCurrency != quoteCurrency { return false }
        if let marketType = condition.marketType, record.marketTypeRawValue != marketType.rawValue { return false }
        if let status = condition.status, record.statusRawValue != status.rawValue { return false }
        if let keyword = condition.keyword, !keyword.isEmpty {
            let matched = record.symbol.localizedCaseInsensitiveContains(keyword)
                || record.displayName.localizedCaseInsensitiveContains(keyword)
                || record.instrumentID.localizedCaseInsensitiveContains(keyword)
            if !matched { return false }
        }
        return true
    }

    public static func filter(_ records: [KLTradingPairDirectoryRecord], condition: KLTradingPairDirectoryQueryCondition) -> [KLTradingPairDirectoryRecord] {
        records.filter { matches($0, condition: condition) }
    }

    public static func applyListRequest(_ records: [KLTradingPairDirectoryRecord], request: KLTradingPairDirectoryListRequest) -> [KLTradingPairDirectoryRecord] {
        let filtered = filter(records, condition: request.condition).sorted { lhs, rhs in
            switch request.order {
            case .ascending:
                return lhs.symbol < rhs.symbol
            case .descending:
                return lhs.symbol > rhs.symbol
            }
        }
        let start = max(0, request.offset ?? 0)
        guard start < filtered.count else { return [] }
        let end: Int
        if let limit = request.limit {
            end = min(filtered.count, start + max(0, limit))
        } else {
            end = filtered.count
        }
        return Array(filtered[start..<end])
    }
}

// MARK: - 交易对目录表访问骨架

public enum KXSJ02Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-02",
        fileName: "KX-SJ-02_交易对目录表访问.swift",
        layer: .data,
        relativePath: "数据层/KX-SJ-02_交易对目录表访问.swift",
        duty: "交易对目录表读写接口骨架"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "交易对目录表访问", passed: true, message: "已提供 DTO、查询/写入请求、映射、访问协议、SQL 描述与纯内存过滤计划")
    }

    public static func placeholder() {
        // 本文件只定义交易对目录表访问接口、请求/结果 DTO、纯映射与 SQL 描述。
        // 不建立数据库连接，不导入数据库驱动，不读写真实数据库。
    }
}
