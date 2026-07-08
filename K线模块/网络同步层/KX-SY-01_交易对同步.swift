//
//  KX-SY-01_交易对同步.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：OKX 交易对同步任务纯逻辑（计划、请求描述、DTO、解析映射、状态摘要）
//  禁止事项：本文件禁止真实请求 OKX、禁止连接数据库、禁止写文件
//

import Foundation


// MARK: - OKX交易对同步骨架

public enum KXSY01Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SY-01",
        fileName: "KX-SY-01_OKX交易对同步.swift",
        layer: .sync,
        relativePath: "同步层/KX-SY-01_OKX交易对同步.swift",
        duty: "OKX 交易对同步任务纯逻辑"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "OKX交易对同步", passed: true, message: "已提供同步计划、请求描述、DTO、解析映射与状态摘要纯逻辑")
    }

    public static func placeholder() {
        // 兼容骨架入口：真实同步由外部执行器调度，本文件只提供无副作用纯逻辑。
    }
}

// MARK: - 同步配置与请求描述

public struct KXSY01OKXTradingPairSyncConfiguration: Codable, Equatable, Sendable {
    public let exchangeID: KLExchangeID
    public let baseURL: String
    public let path: String
    public let instrumentTypes: [KXSY01OKXInstrumentType]
    public let includeSuspended: Bool
    public let retryPolicy: KLRetryPolicyDescriptor
    public let rateLimit: KLRateLimitDescriptor

    public init(
        exchangeID: KLExchangeID = "okx",
        baseURL: String = "https://www.okx.com",
        path: String = "/api/v5/public/instruments",
        instrumentTypes: [KXSY01OKXInstrumentType] = [.spot, .swap, .futures],
        includeSuspended: Bool = true,
        retryPolicy: KLRetryPolicyDescriptor = KLRetryPolicyDescriptor(maxRetries: 3, baseDelaySeconds: 1, maxDelaySeconds: 20, jitterEnabled: true),
        rateLimit: KLRateLimitDescriptor = KLRateLimitDescriptor(maxRequests: 20, intervalSeconds: 2, scope: "okx.public.instruments")
    ) {
        self.exchangeID = exchangeID
        self.baseURL = baseURL
        self.path = path
        self.instrumentTypes = instrumentTypes
        self.includeSuspended = includeSuspended
        self.retryPolicy = retryPolicy
        self.rateLimit = rateLimit
    }
}

public struct KXSY01OKXInstrumentRequestDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let method: String
    public let baseURL: String
    public let path: String
    public let queryItems: [String: String]
    public let marketType: KXSY01OKXInstrumentType

    public init(
        id: String,
        method: String = "GET",
        baseURL: String,
        path: String,
        queryItems: [String: String],
        marketType: KXSY01OKXInstrumentType
    ) {
        self.id = id
        self.method = method
        self.baseURL = baseURL
        self.path = path
        self.queryItems = queryItems
        self.marketType = marketType
    }

    public var cacheKey: KLCacheKey {
        KLCacheKey(namespace: .tradingPairs, variant: "okx:instruments:\(marketType.rawValue)")
    }
}

public struct KXSY01OKXTradingPairSyncPlan: Codable, Equatable, Sendable {
    public let configuration: KXSY01OKXTradingPairSyncConfiguration
    public let requests: [KXSY01OKXInstrumentRequestDescriptor]
    public let plannedAt: Date
    public let lastIncrementalUpdatedAt: Date?

    public init(
        configuration: KXSY01OKXTradingPairSyncConfiguration,
        requests: [KXSY01OKXInstrumentRequestDescriptor],
        plannedAt: Date = Date(),
        lastIncrementalUpdatedAt: Date? = nil
    ) {
        self.configuration = configuration
        self.requests = requests
        self.plannedAt = plannedAt
        self.lastIncrementalUpdatedAt = lastIncrementalUpdatedAt
    }
}

// MARK: - OKX DTO

public enum KXSY01OKXInstrumentType: String, Codable, Sendable, CaseIterable {
    case spot = "SPOT"
    case margin = "MARGIN"
    case swap = "SWAP"
    case futures = "FUTURES"
    case option = "OPTION"
    case unknown = "UNKNOWN"

    public init(okxValue: String?) {
        let normalized = (okxValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self = KXSY01OKXInstrumentType(rawValue: normalized) ?? .unknown
    }

    public var marketType: KLMarketType {
        switch self {
        case .spot: return .spot
        case .margin: return .margin
        case .swap: return .swap
        case .futures: return .futures
        case .option: return .option
        case .unknown: return .spot
        }
    }
}

public enum KXSY01OKXInstrumentState: String, Codable, Sendable, CaseIterable {
    case live
    case suspend
    case preopen
    case test
    case expired
    case unknown

    public init(okxValue: String?) {
        let normalized = (okxValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self = KXSY01OKXInstrumentState(rawValue: normalized) ?? .unknown
    }

    public var tradingPairStatus: KLTradingPairStatus {
        switch self {
        case .live: return .online
        case .suspend: return .suspended
        case .expired: return .delisted
        case .preopen, .test, .unknown: return .unknown
        }
    }
}

public struct KXSY01OKXInstrumentsResponseDTO: Codable, Equatable, Sendable {
    public let code: String
    public let message: String
    public let data: [KXSY01OKXInstrumentDTO]

    private enum CodingKeys: String, CodingKey {
        case code
        case message = "msg"
        case data
    }

    public init(code: String, message: String, data: [KXSY01OKXInstrumentDTO]) {
        self.code = code
        self.message = message
        self.data = data
    }

    public init(dictionary: [String: Any]) {
        self.code = dictionary["code"] as? String ?? ""
        self.message = dictionary["msg"] as? String ?? dictionary["message"] as? String ?? ""
        let rawItems = dictionary["data"] as? [[String: Any]] ?? []
        self.data = rawItems.map { KXSY01OKXInstrumentDTO(dictionary: $0) }
    }

    public var isSuccess: Bool {
        code == "0"
    }
}

public struct KXSY01OKXInstrumentDTO: Codable, Equatable, Sendable, Identifiable {
    public let instrumentType: String
    public let instrumentID: String
    public let underlying: String?
    public let baseCurrency: String?
    public let quoteCurrency: String?
    public let settlementCurrency: String?
    public let contractValue: String?
    public let contractMultiplier: String?
    public let contractValueCurrency: String?
    public let optionType: String?
    public let strikePrice: String?
    public let listTime: String?
    public let expiryTime: String?
    public let leverage: String?
    public let tickSize: String?
    public let lotSize: String?
    public let minSize: String?
    public let state: String?
    public let rawFields: [String: String]

    public var id: String { instrumentID }

    private enum CodingKeys: String, CodingKey {
        case instrumentType = "instType"
        case instrumentID = "instId"
        case underlying = "uly"
        case baseCurrency = "baseCcy"
        case quoteCurrency = "quoteCcy"
        case settlementCurrency = "settleCcy"
        case contractValue = "ctVal"
        case contractMultiplier = "ctMult"
        case contractValueCurrency = "ctValCcy"
        case optionType = "optType"
        case strikePrice = "stk"
        case listTime
        case expiryTime = "expTime"
        case leverage = "lever"
        case tickSize = "tickSz"
        case lotSize = "lotSz"
        case minSize = "minSz"
        case state
        case rawFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            instrumentType: try container.decodeIfPresent(String.self, forKey: .instrumentType) ?? "",
            instrumentID: try container.decodeIfPresent(String.self, forKey: .instrumentID) ?? "",
            underlying: try container.decodeIfPresent(String.self, forKey: .underlying),
            baseCurrency: try container.decodeIfPresent(String.self, forKey: .baseCurrency),
            quoteCurrency: try container.decodeIfPresent(String.self, forKey: .quoteCurrency),
            settlementCurrency: try container.decodeIfPresent(String.self, forKey: .settlementCurrency),
            contractValue: try container.decodeIfPresent(String.self, forKey: .contractValue),
            contractMultiplier: try container.decodeIfPresent(String.self, forKey: .contractMultiplier),
            contractValueCurrency: try container.decodeIfPresent(String.self, forKey: .contractValueCurrency),
            optionType: try container.decodeIfPresent(String.self, forKey: .optionType),
            strikePrice: try container.decodeIfPresent(String.self, forKey: .strikePrice),
            listTime: try container.decodeIfPresent(String.self, forKey: .listTime),
            expiryTime: try container.decodeIfPresent(String.self, forKey: .expiryTime),
            leverage: try container.decodeIfPresent(String.self, forKey: .leverage),
            tickSize: try container.decodeIfPresent(String.self, forKey: .tickSize),
            lotSize: try container.decodeIfPresent(String.self, forKey: .lotSize),
            minSize: try container.decodeIfPresent(String.self, forKey: .minSize),
            state: try container.decodeIfPresent(String.self, forKey: .state),
            rawFields: try container.decodeIfPresent([String: String].self, forKey: .rawFields) ?? [:]
        )
    }

    public init(
        instrumentType: String,
        instrumentID: String,
        underlying: String? = nil,
        baseCurrency: String? = nil,
        quoteCurrency: String? = nil,
        settlementCurrency: String? = nil,
        contractValue: String? = nil,
        contractMultiplier: String? = nil,
        contractValueCurrency: String? = nil,
        optionType: String? = nil,
        strikePrice: String? = nil,
        listTime: String? = nil,
        expiryTime: String? = nil,
        leverage: String? = nil,
        tickSize: String? = nil,
        lotSize: String? = nil,
        minSize: String? = nil,
        state: String? = nil,
        rawFields: [String: String] = [:]
    ) {
        self.instrumentType = instrumentType
        self.instrumentID = instrumentID
        self.underlying = underlying
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.settlementCurrency = settlementCurrency
        self.contractValue = contractValue
        self.contractMultiplier = contractMultiplier
        self.contractValueCurrency = contractValueCurrency
        self.optionType = optionType
        self.strikePrice = strikePrice
        self.listTime = listTime
        self.expiryTime = expiryTime
        self.leverage = leverage
        self.tickSize = tickSize
        self.lotSize = lotSize
        self.minSize = minSize
        self.state = state
        self.rawFields = rawFields
    }

    public init(dictionary: [String: Any]) {
        let strings = dictionary.reduce(into: [String: String]()) { result, entry in
            if let value = entry.value as? String {
                result[entry.key] = value
            } else if let number = entry.value as? NSNumber {
                result[entry.key] = number.stringValue
            }
        }

        self.init(
            instrumentType: strings["instType"] ?? "",
            instrumentID: strings["instId"] ?? "",
            underlying: strings["uly"],
            baseCurrency: strings["baseCcy"],
            quoteCurrency: strings["quoteCcy"],
            settlementCurrency: strings["settleCcy"],
            contractValue: strings["ctVal"],
            contractMultiplier: strings["ctMult"],
            contractValueCurrency: strings["ctValCcy"],
            optionType: strings["optType"],
            strikePrice: strings["stk"],
            listTime: strings["listTime"],
            expiryTime: strings["expTime"],
            leverage: strings["lever"],
            tickSize: strings["tickSz"],
            lotSize: strings["lotSz"],
            minSize: strings["minSz"],
            state: strings["state"],
            rawFields: strings
        )
    }
}

// MARK: - 解析结果与状态摘要

public struct KXSY01OKXTradingPairParseIssue: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let instrumentID: String?
    public let field: String
    public let message: String

    public init(id: String, instrumentID: String?, field: String, message: String) {
        self.id = id
        self.instrumentID = instrumentID
        self.field = field
        self.message = message
    }
}

public struct KXSY01OKXTradingPairParseResult: Codable, Equatable, Sendable {
    public let pairs: [KLTradingPairDescriptor]
    public let issues: [KXSY01OKXTradingPairParseIssue]
    public let parsedAt: Date
    public let incrementalUpdatedAt: Date?

    public init(
        pairs: [KLTradingPairDescriptor],
        issues: [KXSY01OKXTradingPairParseIssue],
        parsedAt: Date = Date(),
        incrementalUpdatedAt: Date? = nil
    ) {
        self.pairs = pairs
        self.issues = issues
        self.parsedAt = parsedAt
        self.incrementalUpdatedAt = incrementalUpdatedAt
    }
}

public struct KXSY01OKXTradingPairSyncSummary: Codable, Equatable, Sendable {
    public let exchangeID: KLExchangeID
    public let requestedMarketTypes: [KXSY01OKXInstrumentType]
    public let requestCount: Int
    public let responseCount: Int
    public let parsedPairCount: Int
    public let onlineCount: Int
    public let suspendedCount: Int
    public let delistedCount: Int
    public let unknownStatusCount: Int
    public let issueCount: Int
    public let errorSummary: String?
    public let lastIncrementalUpdatedAt: Date?
    public let generatedAt: Date

    public init(
        exchangeID: KLExchangeID,
        requestedMarketTypes: [KXSY01OKXInstrumentType],
        requestCount: Int,
        responseCount: Int,
        parsedPairCount: Int,
        onlineCount: Int,
        suspendedCount: Int,
        delistedCount: Int,
        unknownStatusCount: Int,
        issueCount: Int,
        errorSummary: String?,
        lastIncrementalUpdatedAt: Date?,
        generatedAt: Date = Date()
    ) {
        self.exchangeID = exchangeID
        self.requestedMarketTypes = requestedMarketTypes
        self.requestCount = requestCount
        self.responseCount = responseCount
        self.parsedPairCount = parsedPairCount
        self.onlineCount = onlineCount
        self.suspendedCount = suspendedCount
        self.delistedCount = delistedCount
        self.unknownStatusCount = unknownStatusCount
        self.issueCount = issueCount
        self.errorSummary = errorSummary
        self.lastIncrementalUpdatedAt = lastIncrementalUpdatedAt
        self.generatedAt = generatedAt
    }

    public var syncState: KLSyncState {
        if parsedPairCount > 0 && issueCount == 0 { return .completed }
        if parsedPairCount > 0 { return .completed }
        if issueCount > 0 { return .failed }
        return .idle
    }
}

public struct KXSY01OKXTradingPairSyncSnapshot: Codable, Equatable, Sendable {
    public let plan: KXSY01OKXTradingPairSyncPlan
    public let responses: [KXSY01OKXInstrumentsResponseDTO]
    public let parseResult: KXSY01OKXTradingPairParseResult
    public let summary: KXSY01OKXTradingPairSyncSummary

    public init(
        plan: KXSY01OKXTradingPairSyncPlan,
        responses: [KXSY01OKXInstrumentsResponseDTO],
        parseResult: KXSY01OKXTradingPairParseResult,
        summary: KXSY01OKXTradingPairSyncSummary
    ) {
        self.plan = plan
        self.responses = responses
        self.parseResult = parseResult
        self.summary = summary
    }
}

// MARK: - 纯逻辑入口

public enum KXSY01OKXTradingPairSyncLogic {
    public static func makePlan(
        configuration: KXSY01OKXTradingPairSyncConfiguration = KXSY01OKXTradingPairSyncConfiguration(),
        lastIncrementalUpdatedAt: Date? = nil,
        plannedAt: Date = Date()
    ) -> KXSY01OKXTradingPairSyncPlan {
        let requests = configuration.instrumentTypes.map { type in
            KXSY01OKXInstrumentRequestDescriptor(
                id: "okx-instruments-\(type.rawValue.lowercased())",
                baseURL: configuration.baseURL,
                path: configuration.path,
                queryItems: ["instType": type.rawValue],
                marketType: type
            )
        }
        return KXSY01OKXTradingPairSyncPlan(
            configuration: configuration,
            requests: requests,
            plannedAt: plannedAt,
            lastIncrementalUpdatedAt: lastIncrementalUpdatedAt
        )
    }

    public static func parseResponses(
        _ responses: [KXSY01OKXInstrumentsResponseDTO],
        configuration: KXSY01OKXTradingPairSyncConfiguration = KXSY01OKXTradingPairSyncConfiguration(),
        parsedAt: Date = Date()
    ) -> KXSY01OKXTradingPairParseResult {
        var pairs: [KLTradingPairDescriptor] = []
        var issues: [KXSY01OKXTradingPairParseIssue] = []
        var newestUpdateTime: Date?

        for response in responses {
            guard response.isSuccess else {
                issues.append(
                    KXSY01OKXTradingPairParseIssue(
                        id: "response-code-\(issues.count + 1)",
                        instrumentID: nil,
                        field: "code",
                        message: "OKX instruments 响应失败：code=\(response.code), msg=\(response.message)"
                    )
                )
                continue
            }

            for item in response.data {
                let mapped = mapInstrument(item, exchangeID: configuration.exchangeID)
                if let descriptor = mapped.pair {
                    if configuration.includeSuspended || descriptor.status == .online {
                        pairs.append(descriptor)
                    }
                }
                issues.append(contentsOf: mapped.issues)
                newestUpdateTime = maxDate(newestUpdateTime, mapped.incrementalUpdatedAt)
            }
        }

        return KXSY01OKXTradingPairParseResult(
            pairs: pairs,
            issues: issues,
            parsedAt: parsedAt,
            incrementalUpdatedAt: newestUpdateTime ?? (pairs.isEmpty ? nil : parsedAt)
        )
    }

    public static func mapInstrument(
        _ item: KXSY01OKXInstrumentDTO,
        exchangeID: KLExchangeID = "okx"
    ) -> (pair: KLTradingPairDescriptor?, issues: [KXSY01OKXTradingPairParseIssue], incrementalUpdatedAt: Date?) {
        var issues: [KXSY01OKXTradingPairParseIssue] = []
        let instrumentID = item.instrumentID.trimmingCharacters(in: .whitespacesAndNewlines)
        let instrumentType = KXSY01OKXInstrumentType(okxValue: item.instrumentType)
        let state = KXSY01OKXInstrumentState(okxValue: item.state)

        guard !instrumentID.isEmpty else {
            return (
                nil,
                [KXSY01OKXTradingPairParseIssue(id: "missing-instId", instrumentID: nil, field: "instId", message: "缺少 OKX instId，无法生成交易对")],
                nil
            )
        }

        let currencies = resolveCurrencies(item: item, instrumentID: instrumentID)
        if currencies.base.isEmpty {
            issues.append(KXSY01OKXTradingPairParseIssue(id: "\(instrumentID)-baseCcy", instrumentID: instrumentID, field: "baseCcy", message: "无法解析基础币种"))
        }
        if currencies.quote.isEmpty {
            issues.append(KXSY01OKXTradingPairParseIssue(id: "\(instrumentID)-quoteCcy", instrumentID: instrumentID, field: "quoteCcy", message: "无法解析计价币种"))
        }
        if instrumentType == .unknown {
            issues.append(KXSY01OKXTradingPairParseIssue(id: "\(instrumentID)-instType", instrumentID: instrumentID, field: "instType", message: "未知 OKX 市场类型：\(item.instrumentType)"))
        }

        guard !currencies.base.isEmpty, !currencies.quote.isEmpty else {
            return (nil, issues, okxMillisecondsToDate(item.listTime))
        }

        let symbol = makeSymbol(base: currencies.base, quote: currencies.quote, marketType: instrumentType, instrumentID: instrumentID)
        let descriptor = KLTradingPairDescriptor(
            symbol: symbol,
            baseCurrency: currencies.base,
            quoteCurrency: currencies.quote,
            exchangeID: exchangeID,
            instrumentID: instrumentID,
            marketType: instrumentType.marketType,
            status: state.tradingPairStatus,
            pricePrecision: decimalPrecision(item.tickSize),
            quantityPrecision: decimalPrecision(item.lotSize),
            minOrderSize: decimalValue(item.minSize),
            displayName: instrumentID
        )

        return (descriptor, issues, okxMillisecondsToDate(item.listTime))
    }

    public static func makeSummary(
        plan: KXSY01OKXTradingPairSyncPlan,
        responses: [KXSY01OKXInstrumentsResponseDTO],
        parseResult: KXSY01OKXTradingPairParseResult,
        generatedAt: Date = Date()
    ) -> KXSY01OKXTradingPairSyncSummary {
        let pairs = parseResult.pairs
        let failedResponses = responses.filter { !$0.isSuccess }
        let responseErrors = failedResponses.map { "code=\($0.code), msg=\($0.message)" }
        let parseErrors = parseResult.issues.prefix(5).map { issue in
            [issue.instrumentID, issue.field, issue.message].compactMap { $0 }.joined(separator: " ")
        }
        let allErrors = responseErrors + parseErrors

        return KXSY01OKXTradingPairSyncSummary(
            exchangeID: plan.configuration.exchangeID,
            requestedMarketTypes: plan.configuration.instrumentTypes,
            requestCount: plan.requests.count,
            responseCount: responses.count,
            parsedPairCount: pairs.count,
            onlineCount: pairs.filter { $0.status == .online }.count,
            suspendedCount: pairs.filter { $0.status == .suspended }.count,
            delistedCount: pairs.filter { $0.status == .delisted }.count,
            unknownStatusCount: pairs.filter { $0.status == .unknown }.count,
            issueCount: parseResult.issues.count + failedResponses.count,
            errorSummary: allErrors.isEmpty ? nil : allErrors.joined(separator: "；"),
            lastIncrementalUpdatedAt: parseResult.incrementalUpdatedAt ?? plan.lastIncrementalUpdatedAt,
            generatedAt: generatedAt
        )
    }

    public static func makeSnapshot(
        responses: [KXSY01OKXInstrumentsResponseDTO],
        configuration: KXSY01OKXTradingPairSyncConfiguration = KXSY01OKXTradingPairSyncConfiguration(),
        lastIncrementalUpdatedAt: Date? = nil,
        now: Date = Date()
    ) -> KXSY01OKXTradingPairSyncSnapshot {
        let plan = makePlan(configuration: configuration, lastIncrementalUpdatedAt: lastIncrementalUpdatedAt, plannedAt: now)
        let parseResult = parseResponses(responses, configuration: configuration, parsedAt: now)
        let summary = makeSummary(plan: plan, responses: responses, parseResult: parseResult, generatedAt: now)
        return KXSY01OKXTradingPairSyncSnapshot(plan: plan, responses: responses, parseResult: parseResult, summary: summary)
    }
}

// MARK: - 私有辅助逻辑

private func resolveCurrencies(item: KXSY01OKXInstrumentDTO, instrumentID: String) -> (base: String, quote: String) {
    let explicitBase = clean(item.baseCurrency)
    let explicitQuote = clean(item.quoteCurrency)
    if !explicitBase.isEmpty && !explicitQuote.isEmpty {
        return (explicitBase, explicitQuote)
    }

    let components = instrumentID.split(separator: "-").map(String.init)
    let inferredBase = explicitBase.isEmpty ? (components.first ?? "") : explicitBase
    let inferredQuote: String
    if !explicitQuote.isEmpty {
        inferredQuote = explicitQuote
    } else if components.count > 1 {
        inferredQuote = components[1]
    } else {
        inferredQuote = clean(item.settlementCurrency)
    }
    return (inferredBase, inferredQuote)
}

private func makeSymbol(base: String, quote: String, marketType: KXSY01OKXInstrumentType, instrumentID: String) -> KXSymbol {
    switch marketType {
    case .spot, .margin:
        return "\(base)/\(quote)"
    case .swap, .futures, .option, .unknown:
        return instrumentID
    }
}

private func clean(_ value: String?) -> String {
    (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
}

private func decimalValue(_ value: String?) -> KXDecimal? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
}

private func decimalPrecision(_ value: String?) -> Int {
    guard let value else { return 0 }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let exponentRange = normalized.range(of: "e-") {
        return Int(normalized[exponentRange.upperBound...]) ?? 0
    }
    guard let dotIndex = normalized.firstIndex(of: ".") else { return 0 }
    return normalized[normalized.index(after: dotIndex)...].filter { $0 != "0" || normalized.hasSuffix("0") }.count
}

private func okxMillisecondsToDate(_ value: String?) -> Date? {
    guard let value, let milliseconds = Double(value), milliseconds > 0 else { return nil }
    return Date(timeIntervalSince1970: milliseconds / 1000)
}

private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
    switch (lhs, rhs) {
    case let (left?, right?): return max(left, right)
    case let (left?, nil): return left
    case let (nil, right?): return right
    case (nil, nil): return nil
    }
}
