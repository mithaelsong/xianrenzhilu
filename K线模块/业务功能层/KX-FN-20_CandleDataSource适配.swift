//
//  KX-FN-20_CandleDataSource适配.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：适配 K线形态识别模块需要的 Candle 数据源
//  禁止事项：禁止形态识别算法、禁止 UI 绘制
//

import Foundation


// MARK: - CandleDataSource适配骨架

public enum KXFN20Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-20",
        fileName: "KX-FN-20_CandleDataSource适配.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-20_CandleDataSource适配.swift",
        duty: "适配 K线形态识别模块需要的 Candle 数据源"
    )

    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("CandleDataSource适配骨架校验通过")
        return KXHealthCheckItem(name: "CandleDataSource适配", passed: true, message: "已实现基于 KXKLineQuery 的 Candle 数据源适配")
    }

    public static func placeholder() {
        // 本文件已实现 CandleDataSource 适配纯逻辑；保留占位入口以兼容骨架协议验收。
    }
}

// MARK: - 形态识别可消费 Candle 模型

/// KL-IF-01 输出给形态识别模块消费的轻量蜡烛模型。
///
/// 只做字段投影与顺序整理，不包含任何形态判断、信号计算、网络请求、数据库访问或 UI 绘制。
public struct KXFN20PatternCandle: Codable, Equatable, Sendable, Identifiable {
    public let id: String
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
    public let sourceCandleID: KLCandleID?
    public let source: String?

    public init(
        id: String,
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        openTime: Date,
        closeTime: Date? = nil,
        open: KXDecimal,
        high: KXDecimal,
        low: KXDecimal,
        close: KXDecimal,
        volume: KXDecimal,
        quoteVolume: KXDecimal? = nil,
        tradeCount: Int? = nil,
        isClosed: Bool,
        sourceCandleID: KLCandleID? = nil,
        source: String? = nil
    ) {
        self.id = id
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
        self.sourceCandleID = sourceCandleID
        self.source = source
    }
}

/// 形态识别模块可直接遍历的蜡烛序列。
public struct KXFN20PatternCandleSequence: Codable, Equatable, Sendable {
    public let query: KLKLineQuery
    public let candles: [KXFN20PatternCandle]
    public let generatedAt: Date
    public let sourceCount: Int
    public let droppedCount: Int
    public let quality: KLDataQuality

    public init(
        query: KLKLineQuery,
        candles: [KXFN20PatternCandle],
        generatedAt: Date = Date(),
        sourceCount: Int,
        droppedCount: Int,
        quality: KLDataQuality = .unknown
    ) {
        self.query = query
        self.candles = candles
        self.generatedAt = generatedAt
        self.sourceCount = sourceCount
        self.droppedCount = droppedCount
        self.quality = quality
    }

    public var isEmpty: Bool { candles.isEmpty }
    public var count: Int { candles.count }
}

// MARK: - 查询与适配配置

/// limit 的裁剪策略。
///
/// - latestInTimeThenRequestedOrder：先取时间最新的 N 根，再按 query.order 输出；适合形态识别"最近 N 根 K线"。
/// - prefixInRequestedOrder：按 query.order 排序后取前 N 根；适合调用方已经明确希望按当前排序取前缀。
/// - oldestInTimeThenRequestedOrder：先取时间最早的 N 根，再按 query.order 输出。
public enum KXFN20LimitPolicy: Codable, Equatable, Sendable {
    case latestInTimeThenRequestedOrder
    case prefixInRequestedOrder
    case oldestInTimeThenRequestedOrder
}

/// 适配错误。仅描述输入或查询问题，不包装外部网络/数据库行为。
public enum KXFN20CandleDataSourceError: Error, Codable, Equatable, Sendable, CustomStringConvertible {
    case invalidSymbol(String)
    case invalidTimeRange(start: Date, end: Date)
    case invalidLimit(Int)

    public var description: String {
        switch self {
        case .invalidSymbol(let symbol):
            return "交易对为空或无效：\(symbol)"
        case .invalidTimeRange(let start, let end):
            return "时间范围无效：startTime(\(start)) 晚于 endTime(\(end))"
        case .invalidLimit(let limit):
            return "limit 必须大于 0：\(limit)"
        }
    }
}

// MARK: - 适配纯逻辑入口

public extension KXFN20Skeleton {
    /// 构造兼容旧 CandleDataSource.fetchCandles(symbol:interval:limit:) 语义的查询。
    /// 默认升序输出，limit 表示最近 N 根，未闭合 K线默认过滤掉，便于形态识别消费稳定数据。
    static func makePatternQuery(
        symbol: KXSymbol,
        interval timeframe: KXTimeframe,
        limit: Int? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        order: KLQuerySortOrder = .ascending,
        includeUnclosed: Bool = false
    ) -> KLKLineQuery {
        KLKLineQuery(
            symbol: symbol,
            timeframe: timeframe,
            startTime: startTime,
            endTime: endTime,
            limit: limit,
            order: order,
            includeUnclosed: includeUnclosed
        )
    }

    /// 按 KLKLineQuery 对候选 KLCandlePoint 做接口层适配。
    ///
    /// 处理顺序：校验 query → symbol/timeframe 过滤 → 时间范围过滤 → 未闭合过滤 → limit 裁剪 → query.order 排序。
    static func adaptCandles(
        _ sourceCandles: [KLCandlePoint],
        query: KLKLineQuery,
        limitPolicy: KXFN20LimitPolicy = .latestInTimeThenRequestedOrder
    ) throws -> [KLCandlePoint] {
        try validate(query: query)

        let ranged = sourceCandles.filter { candle in
            guard candle.symbol == query.symbol, candle.timeframe == query.timeframe else { return false }
            guard query.includeUnclosed || candle.isClosed else { return false }
            if let startTime = query.startTime, candle.openTime < startTime { return false }
            if let endTime = query.endTime, candle.openTime > endTime { return false }
            return true
        }

        let limited = applyLimit(to: ranged, query: query, policy: limitPolicy)
        return sort(limited, order: query.order)
    }

    /// 输出 KL-02 标准 KLCandleSeries，供仍消费模块内公共类型的调用方使用。
    static func makeCandleSeries(
        from sourceCandles: [KLCandlePoint],
        query: KLKLineQuery,
        limitPolicy: KXFN20LimitPolicy = .latestInTimeThenRequestedOrder,
        generatedAt: Date = Date()
    ) throws -> KLCandleSeries {
        let candles = try adaptCandles(sourceCandles, query: query, limitPolicy: limitPolicy)
        return KLCandleSeries(
            query: query,
            candles: candles,
            generatedAt: generatedAt,
            quality: inferQuality(sourceCount: sourceCandles.count, outputCount: candles.count, query: query)
        )
    }

    /// 输出形态识别模块可消费的轻量蜡烛序列。
    static func makePatternCandleSequence(
        from sourceCandles: [KLCandlePoint],
        query: KLKLineQuery,
        limitPolicy: KXFN20LimitPolicy = .latestInTimeThenRequestedOrder,
        generatedAt: Date = Date()
    ) throws -> KXFN20PatternCandleSequence {
        let adapted = try adaptCandles(sourceCandles, query: query, limitPolicy: limitPolicy)
        let patternCandles = adapted.map(makePatternCandle)

        return KXFN20PatternCandleSequence(
            query: query,
            candles: patternCandles,
            generatedAt: generatedAt,
            sourceCount: sourceCandles.count,
            droppedCount: max(0, sourceCandles.count - adapted.count),
            quality: inferQuality(sourceCount: sourceCandles.count, outputCount: adapted.count, query: query)
        )
    }

    /// 兼容旧接口命名：按 symbol、interval、limit 从给定候选 K线中返回蜡烛序列。
    /// 返回顺序默认从旧到新，不含未闭合 K线，不访问任何外部数据源。
    static func fetchCandles(
        symbol: KXSymbol,
        interval timeframe: KXTimeframe,
        limit: Int,
        from sourceCandles: [KLCandlePoint],
        includeUnclosed: Bool = false
    ) throws -> [KXFN20PatternCandle] {
        let query = makePatternQuery(
            symbol: symbol,
            interval: timeframe,
            limit: limit,
            order: .ascending,
            includeUnclosed: includeUnclosed
        )
        return try makePatternCandleSequence(from: sourceCandles, query: query).candles
    }

    /// 单根 KLCandlePoint 到形态识别轻量 Candle 的字段投影。
    static func makePatternCandle(from candle: KLCandlePoint) -> KXFN20PatternCandle {
        KXFN20PatternCandle(
            id: candle.id ?? stableCandleID(for: candle),
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
            sourceCandleID: candle.id,
            source: candle.source
        )
    }
}

// MARK: - Candle 数据源适配器

/// 通过注入加载闭包，把任意上游 K线来源适配成 KL-02 的 KLCandleDataSourceProtocol。
///
/// 本类型不关心闭包背后的来源；自身只负责二次过滤、排序、限量和格式转换。
public struct KXFN20CandleDataSourceAdapter: KLCandleDataSourceProtocol, Sendable {
    public typealias Loader = @Sendable (KLKLineQuery) async throws -> [KLCandlePoint]

    private let loader: Loader
    private let limitPolicy: KXFN20LimitPolicy

    public init(
        limitPolicy: KXFN20LimitPolicy = .latestInTimeThenRequestedOrder,
        loader: @escaping Loader
    ) {
        self.limitPolicy = limitPolicy
        self.loader = loader
    }

    public func fetchCandles(query: KLKLineQuery) async throws -> [KLCandlePoint] {
        let loaded = try await loader(query)
        return try KXFN20Skeleton.adaptCandles(loaded, query: query, limitPolicy: limitPolicy)
    }

    public func latestCandle(symbol: KXSymbol, timeframe: KXTimeframe) async throws -> KLCandlePoint? {
        let query = KLKLineQuery(
            symbol: symbol,
            timeframe: timeframe,
            limit: 1,
            order: .descending,
            includeUnclosed: true
        )
        return try await fetchCandles(query: query).first
    }

    public func fetchPatternCandleSequence(query: KLKLineQuery) async throws -> KXFN20PatternCandleSequence {
        let candles = try await fetchCandles(query: query)
        return try KXFN20Skeleton.makePatternCandleSequence(
            from: candles,
            query: query,
            limitPolicy: .prefixInRequestedOrder
        )
    }
}

/// 内存候选集适配器，便于单元测试、预览或上层已持有 KLCandlePoint 数组时直接转换。
public struct KXFN20InMemoryCandleDataSource: KLCandleDataSourceProtocol, Sendable {
    public let candles: [KLCandlePoint]
    public let limitPolicy: KXFN20LimitPolicy

    public init(
        candles: [KLCandlePoint],
        limitPolicy: KXFN20LimitPolicy = .latestInTimeThenRequestedOrder
    ) {
        self.candles = candles
        self.limitPolicy = limitPolicy
    }

    public func fetchCandles(query: KLKLineQuery) async throws -> [KLCandlePoint] {
        try KXFN20Skeleton.adaptCandles(candles, query: query, limitPolicy: limitPolicy)
    }

    public func latestCandle(symbol: KXSymbol, timeframe: KXTimeframe) async throws -> KLCandlePoint? {
        let query = KLKLineQuery(
            symbol: symbol,
            timeframe: timeframe,
            limit: 1,
            order: .descending,
            includeUnclosed: true
        )
        return try await fetchCandles(query: query).first
    }

    public func fetchPatternCandleSequence(query: KLKLineQuery) throws -> KXFN20PatternCandleSequence {
        try KXFN20Skeleton.makePatternCandleSequence(from: candles, query: query, limitPolicy: limitPolicy)
    }
}

// MARK: - 内部纯函数

private extension KXFN20Skeleton {
    static func validate(query: KLKLineQuery) throws {
        let trimmedSymbol = query.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSymbol.isEmpty else {
            throw KXFN20CandleDataSourceError.invalidSymbol(query.symbol)
        }

        if let startTime = query.startTime, let endTime = query.endTime, startTime > endTime {
            throw KXFN20CandleDataSourceError.invalidTimeRange(start: startTime, end: endTime)
        }

        if let limit = query.limit, limit <= 0 {
            throw KXFN20CandleDataSourceError.invalidLimit(limit)
        }
    }

    static func applyLimit(
        to candles: [KLCandlePoint],
        query: KLKLineQuery,
        policy: KXFN20LimitPolicy
    ) -> [KLCandlePoint] {
        guard let limit = query.limit else { return candles }
        let safeLimit = max(0, limit)
        guard safeLimit < candles.count else { return candles }

        switch policy {
        case .latestInTimeThenRequestedOrder:
            return Array(sort(candles, order: .descending).prefix(safeLimit))
        case .prefixInRequestedOrder:
            return Array(sort(candles, order: query.order).prefix(safeLimit))
        case .oldestInTimeThenRequestedOrder:
            return Array(sort(candles, order: .ascending).prefix(safeLimit))
        }
    }

    static func sort(_ candles: [KLCandlePoint], order: KLQuerySortOrder) -> [KLCandlePoint] {
        candles.sorted { lhs, rhs in
            if lhs.openTime == rhs.openTime {
                let lhsID = lhs.id ?? ""
                let rhsID = rhs.id ?? ""
                return order == .ascending ? lhsID < rhsID : lhsID > rhsID
            }

            switch order {
            case .ascending:
                return lhs.openTime < rhs.openTime
            case .descending:
                return lhs.openTime > rhs.openTime
            }
        }
    }

    static func inferQuality(sourceCount: Int, outputCount: Int, query: KLKLineQuery) -> KLDataQuality {
        if outputCount == 0 { return .unknown }
        if let limit = query.limit, outputCount < limit { return .partial }
        if outputCount < sourceCount { return .partial }
        return .complete
    }

    static func stableCandleID(for candle: KLCandlePoint) -> String {
        let milliseconds = Int64((candle.openTime.timeIntervalSince1970 * 1_000).rounded())
        return [candle.symbol, candle.timeframe.rawValue, String(milliseconds)].joined(separator: "|")
    }
}
