//
//  KX-UT-01_收藏模型.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：币对、周期组合、指标组合收藏数据模型
//  禁止事项：禁止服务实现、禁止数据库访问
//

import Foundation


// MARK: - 收藏模型文件声明

public enum KXUT01FavoriteSkeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UT-01",
        fileName: "KX-UT-01_币对收藏模型.swift",
        layer: .favorite,
        relativePath: "收藏层/KX-UT-01_币对收藏模型.swift",
        duty: "币对、周期组合、指标组合收藏数据模型"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "币对收藏模型", passed: true, message: "收藏模型、摘要、校验与纯转换已就绪")
    }

    public static func placeholder() {
        // 本文件只保留模型与纯转换能力；不读写数据库、不绘制 UI、不请求网络。
    }
}

// MARK: - 收藏类型、排序与分组

public enum KLFavoriteItemType: String, Codable, Sendable, CaseIterable {
    case tradingPair
    case timeframeCombination
    case indicatorCombination

    public var displayName: String {
        switch self {
        case .tradingPair:
            return "币对"
        case .timeframeCombination:
            return "周期组合"
        case .indicatorCombination:
            return "指标组合"
        }
    }
}

public enum KLFavoriteSortField: String, Codable, Sendable, CaseIterable {
    case type
    case title
    case symbol
    case exchangeID
    case marketType
    case sortIndex
    case createdAt
    case updatedAt
}

public enum KLFavoriteGroupField: String, Codable, Sendable, CaseIterable {
    case none
    case type
    case exchangeID
    case marketType
    case quoteCurrency
    case timeframeCount
    case indicatorCount
    case createdDay
}

public enum KLFavoriteSortDirection: String, Codable, Sendable, CaseIterable {
    case ascending
    case descending
}

public struct KLFavoriteSortDescriptor: Codable, Equatable, Sendable {
    public let field: KLFavoriteSortField
    public let direction: KLFavoriteSortDirection

    public init(field: KLFavoriteSortField = .sortIndex, direction: KLFavoriteSortDirection = .ascending) {
        self.field = field
        self.direction = direction
    }
}

// MARK: - 展示摘要与校验结果

public struct KLFavoriteDisplaySummary: Codable, Equatable, Sendable {
    public let id: String
    public let type: KLFavoriteItemType
    public let title: String
    public let subtitle: String?
    public let detail: String?
    public let badges: [String]
    public let groupKey: String
    public let sortIndex: Int

    public init(id: String, type: KLFavoriteItemType, title: String, subtitle: String? = nil, detail: String? = nil, badges: [String] = [], groupKey: String = "", sortIndex: Int = 0) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.badges = badges
        self.groupKey = groupKey
        self.sortIndex = sortIndex
    }
}

public enum KLFavoriteValidationSeverity: String, Codable, Sendable, CaseIterable {
    case warning
    case error
}

public enum KLFavoriteValidationCode: String, Codable, Sendable, CaseIterable {
    case emptyID
    case emptyTitle
    case missingTradingPair
    case missingTimeframes
    case missingIndicators
    case typePayloadMismatch
    case negativeSortIndex
}

public struct KLFavoriteValidationIssue: Codable, Equatable, Sendable {
    public let code: KLFavoriteValidationCode
    public let severity: KLFavoriteValidationSeverity
    public let message: String

    public init(code: KLFavoriteValidationCode, severity: KLFavoriteValidationSeverity, message: String) {
        self.code = code
        self.severity = severity
        self.message = message
    }
}

public struct KLFavoriteValidationResult: Codable, Equatable, Sendable {
    public let issues: [KLFavoriteValidationIssue]

    public init(issues: [KLFavoriteValidationIssue] = []) {
        self.issues = issues
    }

    public var isValid: Bool {
        !issues.contains { $0.severity == .error }
    }

    public var errors: [KLFavoriteValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [KLFavoriteValidationIssue] {
        issues.filter { $0.severity == .warning }
    }
}

// MARK: - 收藏条目模型

public struct KLFavoriteItemModel: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let type: KLFavoriteItemType
    public let title: String
    public let note: String?
    public let tags: [String]
    public let sortIndex: Int
    public let createdAt: Date
    public let updatedAt: Date?
    public let tradingPair: KLTradingPairDescriptor?
    public let timeframes: [KXTimeframe]
    public let indicatorIDs: [String]

    public init(
        id: String,
        type: KLFavoriteItemType,
        title: String,
        note: String? = nil,
        tags: [String] = [],
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        tradingPair: KLTradingPairDescriptor? = nil,
        timeframes: [KXTimeframe] = [],
        indicatorIDs: [String] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.note = note
        self.tags = tags
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tradingPair = tradingPair
        self.timeframes = timeframes
        self.indicatorIDs = indicatorIDs
    }

    public var symbol: KXSymbol? {
        tradingPair?.symbol
    }

    public var exchangeID: KLExchangeID? {
        tradingPair?.exchangeID
    }

    public var marketType: KLMarketType? {
        tradingPair?.marketType
    }

    public var quoteCurrency: String? {
        tradingPair?.quoteCurrency
    }

    public func displaySummary(groupedBy groupField: KLFavoriteGroupField = .type) -> KLFavoriteDisplaySummary {
        KLFavoriteDisplaySummary(
            id: id,
            type: type,
            title: normalizedTitle,
            subtitle: subtitle,
            detail: detail,
            badges: badges,
            groupKey: groupKey(for: groupField),
            sortIndex: sortIndex
        )
    }

    public func groupKey(for field: KLFavoriteGroupField) -> String {
        switch field {
        case .none:
            return ""
        case .type:
            return type.displayName
        case .exchangeID:
            return tradingPair?.exchangeID ?? "未指定交易所"
        case .marketType:
            return tradingPair?.marketType.rawValue ?? "未指定市场"
        case .quoteCurrency:
            return tradingPair?.quoteCurrency ?? "未指定计价币"
        case .timeframeCount:
            return "\(timeframes.count) 个周期"
        case .indicatorCount:
            return "\(indicatorIDs.count) 个指标"
        case .createdDay:
            return String(Int(createdAt.timeIntervalSince1970 / 86_400))
        }
    }

    public func sortValue(for field: KLFavoriteSortField) -> String {
        switch field {
        case .type:
            return type.rawValue
        case .title:
            return normalizedTitle
        case .symbol:
            return tradingPair?.symbol ?? ""
        case .exchangeID:
            return tradingPair?.exchangeID ?? ""
        case .marketType:
            return tradingPair?.marketType.rawValue ?? ""
        case .sortIndex:
            return String(format: "%020d", sortIndex)
        case .createdAt:
            return String(format: "%020.6f", createdAt.timeIntervalSince1970)
        case .updatedAt:
            return String(format: "%020.6f", (updatedAt ?? createdAt).timeIntervalSince1970)
        }
    }

    public func validate() -> KLFavoriteValidationResult {
        var issues: [KLFavoriteValidationIssue] = []
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(KLFavoriteValidationIssue(code: .emptyID, severity: .error, message: "收藏 ID 不能为空"))
        }
        if normalizedTitle.isEmpty {
            issues.append(KLFavoriteValidationIssue(code: .emptyTitle, severity: .error, message: "收藏标题不能为空"))
        }
        if sortIndex < 0 {
            issues.append(KLFavoriteValidationIssue(code: .negativeSortIndex, severity: .warning, message: "排序值小于 0，可能影响列表展示顺序"))
        }

        switch type {
        case .tradingPair:
            if tradingPair == nil {
                issues.append(KLFavoriteValidationIssue(code: .missingTradingPair, severity: .error, message: "币对收藏缺少交易对描述"))
            }
            if !timeframes.isEmpty || !indicatorIDs.isEmpty {
                issues.append(KLFavoriteValidationIssue(code: .typePayloadMismatch, severity: .warning, message: "币对收藏不应携带周期或指标组合载荷"))
            }
        case .timeframeCombination:
            if timeframes.isEmpty {
                issues.append(KLFavoriteValidationIssue(code: .missingTimeframes, severity: .error, message: "周期组合收藏至少需要 1 个周期"))
            }
            if tradingPair != nil || !indicatorIDs.isEmpty {
                issues.append(KLFavoriteValidationIssue(code: .typePayloadMismatch, severity: .warning, message: "周期组合收藏不应携带币对或指标载荷"))
            }
        case .indicatorCombination:
            if indicatorIDs.isEmpty {
                issues.append(KLFavoriteValidationIssue(code: .missingIndicators, severity: .error, message: "指标组合收藏至少需要 1 个指标 ID"))
            }
            if tradingPair != nil || !timeframes.isEmpty {
                issues.append(KLFavoriteValidationIssue(code: .typePayloadMismatch, severity: .warning, message: "指标组合收藏不应携带币对或周期载荷"))
            }
        }
        return KLFavoriteValidationResult(issues: issues)
    }

    public static func fromTradingPairDescriptor(_ descriptor: KLTradingPairDescriptor, note: String? = nil, sortIndex: Int = 0, createdAt: Date = Date()) -> KLFavoriteItemModel {
        KLFavoriteItemModel(
            id: stableTradingPairID(for: descriptor),
            type: .tradingPair,
            title: descriptor.displayName,
            note: note,
            sortIndex: sortIndex,
            createdAt: createdAt,
            tradingPair: descriptor
        )
    }

    public static func fromFavoriteTradingPair(_ favorite: KLFavoriteTradingPair) -> KLFavoriteItemModel {
        KLFavoriteItemModel(
            id: favorite.id,
            type: .tradingPair,
            title: favorite.pair.displayName,
            note: favorite.note,
            sortIndex: favorite.sortIndex,
            createdAt: favorite.createdAt,
            tradingPair: favorite.pair
        )
    }

    public static func fromTimeframeCombination(_ combination: KXTimeframeCombination, sortIndex: Int = 0, createdAt: Date = Date()) -> KLFavoriteItemModel {
        KLFavoriteItemModel(
            id: combination.id,
            type: .timeframeCombination,
            title: combination.name,
            sortIndex: sortIndex,
            createdAt: createdAt,
            timeframes: combination.timeframes
        )
    }

    public static func fromIndicatorCombination(_ combination: KLIndicatorCombination, sortIndex: Int = 0, createdAt: Date = Date()) -> KLFavoriteItemModel {
        KLFavoriteItemModel(
            id: combination.id,
            type: .indicatorCombination,
            title: combination.name,
            sortIndex: sortIndex,
            createdAt: createdAt,
            indicatorIDs: combination.indicatorIDs
        )
    }

    public func toFavoriteTradingPair() -> KLFavoriteTradingPair? {
        guard type == .tradingPair, let tradingPair else { return nil }
        return KLFavoriteTradingPair(id: id, pair: tradingPair, note: note, sortIndex: sortIndex, createdAt: createdAt)
    }

    public func toTimeframeCombination() -> KXTimeframeCombination? {
        guard type == .timeframeCombination else { return nil }
        return KXTimeframeCombination(id: id, name: normalizedTitle, timeframes: timeframes)
    }

    public func toIndicatorCombination() -> KLIndicatorCombination? {
        guard type == .indicatorCombination else { return nil }
        return KLIndicatorCombination(id: id, name: normalizedTitle, indicatorIDs: indicatorIDs)
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var subtitle: String? {
        switch type {
        case .tradingPair:
            guard let pair = tradingPair else { return nil }
            return [pair.exchangeID, pair.marketType.rawValue, pair.status.rawValue].joined(separator: " · ")
        case .timeframeCombination:
            return timeframes.map { $0.rawValue }.joined(separator: " / ")
        case .indicatorCombination:
            return indicatorIDs.joined(separator: " / ")
        }
    }

    private var detail: String? {
        switch type {
        case .tradingPair:
            guard let pair = tradingPair else { return note }
            let precision = "价格精度 \(pair.pricePrecision)，数量精度 \(pair.quantityPrecision)"
            if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "\(precision)｜\(note)"
            }
            return precision
        case .timeframeCombination:
            return "共 \(timeframes.count) 个周期"
        case .indicatorCombination:
            return "共 \(indicatorIDs.count) 个指标"
        }
    }

    private var badges: [String] {
        switch type {
        case .tradingPair:
            guard let pair = tradingPair else { return [type.displayName] }
            return [type.displayName, pair.baseCurrency, pair.quoteCurrency, pair.exchangeID]
        case .timeframeCombination:
            return [type.displayName, "\(timeframes.count)"]
        case .indicatorCombination:
            return [type.displayName, "\(indicatorIDs.count)"]
        }
    }

    private static func stableTradingPairID(for descriptor: KLTradingPairDescriptor) -> String {
        ["pair", descriptor.exchangeID, descriptor.instrumentID, descriptor.symbol]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ":")
    }
}

// MARK: - 收藏集合快照

public struct KLFavoriteCollectionSnapshot: Codable, Equatable, Sendable {
    public let items: [KLFavoriteItemModel]
    public let sortDescriptor: KLFavoriteSortDescriptor
    public let groupField: KLFavoriteGroupField
    public let generatedAt: Date

    public init(items: [KLFavoriteItemModel], sortDescriptor: KLFavoriteSortDescriptor = KLFavoriteSortDescriptor(), groupField: KLFavoriteGroupField = .type, generatedAt: Date = Date()) {
        self.items = items
        self.sortDescriptor = sortDescriptor
        self.groupField = groupField
        self.generatedAt = generatedAt
    }

    public var summaries: [KLFavoriteDisplaySummary] {
        sortedItems.map { $0.displaySummary(groupedBy: groupField) }
    }

    public var validationResult: KLFavoriteValidationResult {
        KLFavoriteValidationResult(issues: items.flatMap { $0.validate().issues })
    }

    public var sortedItems: [KLFavoriteItemModel] {
        items.sorted { lhs, rhs in
            let lhsValue = lhs.sortValue(for: sortDescriptor.field)
            let rhsValue = rhs.sortValue(for: sortDescriptor.field)
            if lhsValue == rhsValue { return lhs.id < rhs.id }
            switch sortDescriptor.direction {
            case .ascending:
                return lhsValue < rhsValue
            case .descending:
                return lhsValue > rhsValue
            }
        }
    }

    public func groupedSummaries() -> [String: [KLFavoriteDisplaySummary]] {
        Dictionary(grouping: summaries) { $0.groupKey }
    }
}
