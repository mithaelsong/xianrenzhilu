//
//  KX-FN-01_交易对管理.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：读取交易对目录、过滤交易对、给 UI 和收藏服务提供交易对清单
//  禁止事项：禁止直接请求 OKX、禁止 UI 绘制、禁止直接写注册表
//

import Foundation


// MARK: - 交易对目录管理骨架

public enum KXFN01Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-01",
        fileName: "KX-FN-01_交易对管理.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-01_交易对管理.swift",
        duty: "读取交易对目录、过滤交易对、给 UI 和收藏服务提供交易对清单"
    )

    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("交易对目录管理骨架校验通过")
        return KXHealthCheckItem(name: "交易对目录管理", passed: true, message: "已实现传入式交易对目录读取、筛选、搜索、排序与存在性校验；不请求 OKX、不读写数据库")
    }

    public static func placeholder() {
        // 本文件已实现：读取调用方传入的交易对目录、过滤交易对、给 UI 和收藏服务提供交易对清单。
        // 数据边界：只消费初始化传入数组或协议 listTradingPairs() 输入；不直接请求 OKX，不读写数据库。
    }
}

// MARK: - 交易对目录管理公开模型

public struct KXFN01TradingPairQuery: Codable, Equatable, Sendable {
    public let searchText: String?
    public let baseCurrencies: Set<String>
    public let quoteCurrencies: Set<String>
    public let statuses: Set<KLTradingPairStatus>
    public let marketTypes: Set<KLMarketType>
    public let exchangeIDs: Set<KLExchangeID>
    public let includeNonTradable: Bool
    public let sortDescriptors: [KXFN01TradingPairSortDescriptor]
    public let limit: Int?

    public init(
        searchText: String? = nil,
        baseCurrencies: Set<String> = [],
        quoteCurrencies: Set<String> = [],
        statuses: Set<KLTradingPairStatus> = [],
        marketTypes: Set<KLMarketType> = [],
        exchangeIDs: Set<KLExchangeID> = [],
        includeNonTradable: Bool = false,
        sortDescriptors: [KXFN01TradingPairSortDescriptor] = [.quoteCurrency(), .baseCurrency(), .status()],
        limit: Int? = nil
    ) {
        self.searchText = searchText
        self.baseCurrencies = baseCurrencies
        self.quoteCurrencies = quoteCurrencies
        self.statuses = statuses
        self.marketTypes = marketTypes
        self.exchangeIDs = exchangeIDs
        self.includeNonTradable = includeNonTradable
        self.sortDescriptors = sortDescriptors
        self.limit = limit
    }
}

public struct KXFN01TradingPairSortDescriptor: Codable, Equatable, Sendable {
    public enum Field: String, Codable, Sendable, CaseIterable {
        case quoteCurrency
        case baseCurrency
        case status
        case marketType
        case symbol
        case instrumentID
        case displayName
        case exchangeID
    }

    public enum Direction: String, Codable, Sendable, CaseIterable {
        case ascending
        case descending
    }

    public let field: Field
    public let direction: Direction

    public init(field: Field, direction: Direction = .ascending) {
        self.field = field
        self.direction = direction
    }

    public static func quoteCurrency(_ direction: Direction = .ascending) -> Self {
        Self(field: .quoteCurrency, direction: direction)
    }

    public static func baseCurrency(_ direction: Direction = .ascending) -> Self {
        Self(field: .baseCurrency, direction: direction)
    }

    public static func status(_ direction: Direction = .ascending) -> Self {
        Self(field: .status, direction: direction)
    }

    public static func marketType(_ direction: Direction = .ascending) -> Self {
        Self(field: .marketType, direction: direction)
    }

    public static func symbol(_ direction: Direction = .ascending) -> Self {
        Self(field: .symbol, direction: direction)
    }

    public static func instrumentID(_ direction: Direction = .ascending) -> Self {
        Self(field: .instrumentID, direction: direction)
    }
}

public struct KXFN01TradingPairListResult: Codable, Equatable, Sendable {
    public let pairs: [KLTradingPairDescriptor]
    public let inputCount: Int
    public let matchedCountBeforeLimit: Int
    public let returnedCount: Int
    public let generatedAt: Date

    public init(
        pairs: [KLTradingPairDescriptor],
        inputCount: Int,
        matchedCountBeforeLimit: Int,
        generatedAt: Date = Date()
    ) {
        self.pairs = pairs
        self.inputCount = inputCount
        self.matchedCountBeforeLimit = matchedCountBeforeLimit
        self.returnedCount = pairs.count
        self.generatedAt = generatedAt
    }
}

// MARK: - 交易对目录管理器

public struct KXFN01TradingPairDirectoryManager: KLTradingPairDirectoryProtocol, Sendable {
    public let pairs: [KLTradingPairDescriptor]

    public init(pairs: [KLTradingPairDescriptor]) {
        self.pairs = pairs
    }

    public init(source: any KLTradingPairDirectoryProtocol) async throws {
        self.pairs = try await source.listTradingPairs()
    }

    public func listTradingPairs() async throws -> [KLTradingPairDescriptor] {
        listTradablePairs()
    }

    public func tradingPair(symbol: KXSymbol) async throws -> KLTradingPairDescriptor? {
        descriptor(for: symbol)
    }

    public func listTradablePairs(
        sortedBy sortDescriptors: [KXFN01TradingPairSortDescriptor] = [.quoteCurrency(), .baseCurrency(), .status()]
    ) -> [KLTradingPairDescriptor] {
        listPairs(
            matching: KXFN01TradingPairQuery(
                includeNonTradable: false,
                sortDescriptors: sortDescriptors
            )
        ).pairs
    }

    public func listPairs(matching query: KXFN01TradingPairQuery = KXFN01TradingPairQuery()) -> KXFN01TradingPairListResult {
        let filtered = pairs.filter { pair in
            matchesTradableRule(pair, includeNonTradable: query.includeNonTradable) &&
            matchesSet(pair.baseCurrency, allowedValues: query.baseCurrencies) &&
            matchesSet(pair.quoteCurrency, allowedValues: query.quoteCurrencies) &&
            matchesStatus(pair.status, allowedValues: query.statuses) &&
            matchesMarketType(pair.marketType, allowedValues: query.marketTypes) &&
            matchesSet(pair.exchangeID, allowedValues: query.exchangeIDs) &&
            matchesSearchText(query.searchText, pair: pair)
        }

        let sorted = sort(filtered, by: query.sortDescriptors)
        let normalizedLimit = query.limit.map { max(0, $0) }
        let limited = normalizedLimit.map { Array(sorted.prefix($0)) } ?? sorted

        return KXFN01TradingPairListResult(
            pairs: limited,
            inputCount: pairs.count,
            matchedCountBeforeLimit: sorted.count
        )
    }

    public func search(
        _ text: String,
        includeNonTradable: Bool = false,
        limit: Int? = nil
    ) -> [KLTradingPairDescriptor] {
        listPairs(
            matching: KXFN01TradingPairQuery(
                searchText: text,
                includeNonTradable: includeNonTradable,
                sortDescriptors: [.quoteCurrency(), .baseCurrency(), .status(), .symbol()],
                limit: limit
            )
        ).pairs
    }

    public func descriptor(for symbolOrInstrumentID: String) -> KLTradingPairDescriptor? {
        let normalizedKey = normalizeForExactMatch(symbolOrInstrumentID)
        guard !normalizedKey.isEmpty else { return nil }

        return sort(pairs, by: [.quoteCurrency(), .baseCurrency(), .status(), .symbol()]).first { pair in
            normalizeForExactMatch(pair.symbol) == normalizedKey ||
            normalizeForExactMatch(pair.instrumentID) == normalizedKey
        }
    }

    public func contains(symbolOrInstrumentID: String, tradableOnly: Bool = true) -> Bool {
        guard let pair = descriptor(for: symbolOrInstrumentID) else { return false }
        return !tradableOnly || pair.status == .online
    }

    public func filterByBaseCurrency(_ baseCurrency: String, includeNonTradable: Bool = false) -> [KLTradingPairDescriptor] {
        listPairs(
            matching: KXFN01TradingPairQuery(
                baseCurrencies: [baseCurrency],
                includeNonTradable: includeNonTradable,
                sortDescriptors: [.quoteCurrency(), .baseCurrency(), .status(), .symbol()]
            )
        ).pairs
    }

    public func filterByQuoteCurrency(_ quoteCurrency: String, includeNonTradable: Bool = false) -> [KLTradingPairDescriptor] {
        listPairs(
            matching: KXFN01TradingPairQuery(
                quoteCurrencies: [quoteCurrency],
                includeNonTradable: includeNonTradable,
                sortDescriptors: [.quoteCurrency(), .baseCurrency(), .status(), .symbol()]
            )
        ).pairs
    }

    public func filterByStatus(_ status: KLTradingPairStatus) -> [KLTradingPairDescriptor] {
        listPairs(
            matching: KXFN01TradingPairQuery(
                statuses: [status],
                includeNonTradable: true,
                sortDescriptors: [.status(), .quoteCurrency(), .baseCurrency(), .symbol()]
            )
        ).pairs
    }

    public func filterByMarketType(_ marketType: KLMarketType, includeNonTradable: Bool = false) -> [KLTradingPairDescriptor] {
        listPairs(
            matching: KXFN01TradingPairQuery(
                marketTypes: [marketType],
                includeNonTradable: includeNonTradable,
                sortDescriptors: [.marketType(), .quoteCurrency(), .baseCurrency(), .status(), .symbol()]
            )
        ).pairs
    }

    public func availableBaseCurrencies(includeNonTradable: Bool = false) -> [String] {
        sortedUniqueCurrencies(pairs.filter { matchesTradableRule($0, includeNonTradable: includeNonTradable) }.map(\.baseCurrency))
    }

    public func availableQuoteCurrencies(includeNonTradable: Bool = false) -> [String] {
        sortedUniqueCurrencies(pairs.filter { matchesTradableRule($0, includeNonTradable: includeNonTradable) }.map(\.quoteCurrency))
    }

    public func availableMarketTypes(includeNonTradable: Bool = false) -> [KLMarketType] {
        let values = Set(pairs.filter { matchesTradableRule($0, includeNonTradable: includeNonTradable) }.map(\.marketType))
        return KLMarketType.allCases.filter { values.contains($0) }
    }

    public func availableStatuses(includeNonTradable: Bool = true) -> [KLTradingPairStatus] {
        let values = Set(pairs.filter { matchesTradableRule($0, includeNonTradable: includeNonTradable) }.map(\.status))
        return KLTradingPairStatus.allCases.filter { values.contains($0) }
    }

    private func matchesTradableRule(_ pair: KLTradingPairDescriptor, includeNonTradable: Bool) -> Bool {
        includeNonTradable || pair.status == .online
    }

    private func matchesSet(_ value: String, allowedValues: Set<String>) -> Bool {
        allowedValues.isEmpty || allowedValues.map(normalizeForExactMatch).contains(normalizeForExactMatch(value))
    }

    private func matchesStatus(_ status: KLTradingPairStatus, allowedValues: Set<KLTradingPairStatus>) -> Bool {
        allowedValues.isEmpty || allowedValues.contains(status)
    }

    private func matchesMarketType(_ marketType: KLMarketType, allowedValues: Set<KLMarketType>) -> Bool {
        allowedValues.isEmpty || allowedValues.contains(marketType)
    }

    private func matchesSearchText(_ text: String?, pair: KLTradingPairDescriptor) -> Bool {
        let tokens = searchTokens(from: text)
        guard !tokens.isEmpty else { return true }

        let searchableValues = [
            pair.symbol,
            pair.instrumentID,
            pair.baseCurrency,
            pair.quoteCurrency,
            pair.displayName,
            pair.exchangeID,
            pair.marketType.rawValue,
            pair.status.rawValue
        ]
        let normalizedValues = searchableValues.map(normalizeForSearch)

        return tokens.allSatisfy { token in
            normalizedValues.contains { value in value.contains(token) }
        }
    }

    private func sort(_ input: [KLTradingPairDescriptor], by sortDescriptors: [KXFN01TradingPairSortDescriptor]) -> [KLTradingPairDescriptor] {
        let descriptors = sortDescriptors.isEmpty ? [.quoteCurrency(), .baseCurrency(), .status(), .symbol()] : sortDescriptors

        return input.sorted { lhs, rhs in
            for descriptor in descriptors {
                let comparison = compare(lhs, rhs, field: descriptor.field)
                guard comparison != .orderedSame else { continue }
                return descriptor.direction == .ascending ? comparison == .orderedAscending : comparison == .orderedDescending
            }

            return stableTieBreak(lhs, rhs)
        }
    }

    private func compare(_ lhs: KLTradingPairDescriptor, _ rhs: KLTradingPairDescriptor, field: KXFN01TradingPairSortDescriptor.Field) -> ComparisonResult {
        switch field {
        case .quoteCurrency:
            return compareText(lhs.quoteCurrency, rhs.quoteCurrency)
        case .baseCurrency:
            return compareText(lhs.baseCurrency, rhs.baseCurrency)
        case .status:
            return compareRank(statusRank(lhs.status), statusRank(rhs.status))
        case .marketType:
            return compareRank(marketTypeRank(lhs.marketType), marketTypeRank(rhs.marketType))
        case .symbol:
            return compareText(lhs.symbol, rhs.symbol)
        case .instrumentID:
            return compareText(lhs.instrumentID, rhs.instrumentID)
        case .displayName:
            return compareText(lhs.displayName, rhs.displayName)
        case .exchangeID:
            return compareText(lhs.exchangeID, rhs.exchangeID)
        }
    }

    private func stableTieBreak(_ lhs: KLTradingPairDescriptor, _ rhs: KLTradingPairDescriptor) -> Bool {
        let fields: [(String, String)] = [
            (lhs.quoteCurrency, rhs.quoteCurrency),
            (lhs.baseCurrency, rhs.baseCurrency),
            (lhs.status.rawValue, rhs.status.rawValue),
            (lhs.marketType.rawValue, rhs.marketType.rawValue),
            (lhs.symbol, rhs.symbol),
            (lhs.instrumentID, rhs.instrumentID),
            (lhs.exchangeID, rhs.exchangeID)
        ]

        for field in fields {
            let comparison = compareText(field.0, field.1)
            if comparison != .orderedSame { return comparison == .orderedAscending }
        }
        return false
    }

    private func compareText(_ lhs: String, _ rhs: String) -> ComparisonResult {
        normalizeForSearch(lhs).compare(normalizeForSearch(rhs))
    }

    private func compareRank(_ lhs: Int, _ rhs: Int) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    private func statusRank(_ status: KLTradingPairStatus) -> Int {
        switch status {
        case .online: return 0
        case .suspended: return 1
        case .unknown: return 2
        case .delisted: return 3
        }
    }

    private func marketTypeRank(_ marketType: KLMarketType) -> Int {
        switch marketType {
        case .spot: return 0
        case .margin: return 1
        case .swap: return 2
        case .futures: return 3
        case .option: return 4
        }
    }

    private func sortedUniqueCurrencies(_ currencies: [String]) -> [String] {
        Array(Set(currencies.map(normalizeForExactMatch).filter { !$0.isEmpty })).sorted()
    }

    private func searchTokens(from text: String?) -> [String] {
        guard let text else { return [] }
        return text
            .split { character in
                character.isWhitespace || character == "," || character == ";" || character == "|"
            }
            .map(String.init)
            .map(normalizeForSearch)
            .filter { !$0.isEmpty }
    }

    private func normalizeForExactMatch(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func normalizeForSearch(_ value: String) -> String {
        normalizeForExactMatch(value)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}
