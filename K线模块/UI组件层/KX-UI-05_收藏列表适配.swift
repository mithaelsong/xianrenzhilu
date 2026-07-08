//
//  KX-UI-05_收藏列表适配.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：为 UI 收藏列表提供筛选、排序、分组数据适配
//  禁止事项：禁止修改 UI 模块、禁止请求网络、禁止读写数据库、禁止 UI 绘制
//

import Foundation


// MARK: - 收藏列表数据适配骨架

public enum KXUI05Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-05",
        fileName: "KX-UI-05_收藏列表数据适配.swift",
        layer: .uiAdapter,
        relativePath: "UI数据适配层/KX-UI-05_收藏列表数据适配.swift",
        duty: "为 UI 收藏列表提供筛选、排序、分组数据适配"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "收藏列表数据适配", passed: true, message: "已实现：筛选、排序、分组、搜索、空状态适配")
    }

    public static func placeholder() {
        // 本文件只提供 UI 数据适配：将收藏层模型转为 UI 可消费的条目数据。
        // 不画 UI、不请求网络、不读写数据库。
    }
}

// MARK: - 收藏列表 UI 条目

/// UI 可消费的收藏列表条目。每个条目对应一个收藏项（币对/周期组合/指标组合），
/// 携带展示内容、分组键、排序值以及空状态标记。
public struct KXUI05FavoriteListItem: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let type: KLFavoriteItemType
    public let title: String
    public let subtitle: String?
    public let detail: String?
    public let badges: [String]
    public let groupKey: String
    public let sortIndex: Int
    public let createdAt: Date
    public let updatedAt: Date?
    public let symbol: KXSymbol?
    public let exchangeID: KLExchangeID?
    public let marketType: KLMarketType?
    public let note: String?
    public let tags: [String]
    public let timeframeCount: Int
    public let indicatorCount: Int
    public let isPlaceholder: Bool

    public init(
        id: String,
        type: KLFavoriteItemType,
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        badges: [String] = [],
        groupKey: String = "",
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        symbol: KXSymbol? = nil,
        exchangeID: KLExchangeID? = nil,
        marketType: KLMarketType? = nil,
        note: String? = nil,
        tags: [String] = [],
        timeframeCount: Int = 0,
        indicatorCount: Int = 0,
        isPlaceholder: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.badges = badges
        self.groupKey = groupKey
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.symbol = symbol
        self.exchangeID = exchangeID
        self.marketType = marketType
        self.note = note
        self.tags = tags
        self.timeframeCount = timeframeCount
        self.indicatorCount = indicatorCount
        self.isPlaceholder = isPlaceholder
    }

    /// 空状态占位条目。
    public static func placeholder(type: KLFavoriteItemType = .tradingPair) -> KXUI05FavoriteListItem {
        KXUI05FavoriteListItem(
            id: "__placeholder__",
            type: type,
            title: "暂无收藏",
            subtitle: "去交易对目录添加收藏",
            isPlaceholder: true
        )
    }
}

// MARK: - 收藏列表适配器过滤条件

public struct KXUI05FavoriteFilter: Codable, Equatable, Sendable {
    public let keyword: String?
    public let types: [KLFavoriteItemType]?
    public let exchangeID: KLExchangeID?
    public let marketType: KLMarketType?
    public let baseCurrency: String?
    public let quoteCurrency: String?
    public let minTimeframeCount: Int?
    public let minIndicatorCount: Int?
    public let hasNote: Bool?
    public let isPlaceholderExcluded: Bool

    public init(
        keyword: String? = nil,
        types: [KLFavoriteItemType]? = nil,
        exchangeID: KLExchangeID? = nil,
        marketType: KLMarketType? = nil,
        baseCurrency: String? = nil,
        quoteCurrency: String? = nil,
        minTimeframeCount: Int? = nil,
        minIndicatorCount: Int? = nil,
        hasNote: Bool? = nil,
        isPlaceholderExcluded: Bool = true
    ) {
        self.keyword = keyword
        self.types = types
        self.exchangeID = exchangeID
        self.marketType = marketType
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.minTimeframeCount = minTimeframeCount
        self.minIndicatorCount = minIndicatorCount
        self.hasNote = hasNote
        self.isPlaceholderExcluded = isPlaceholderExcluded
    }

    /// 不过滤任何条目的默认条件。
    public static let none = KXUI05FavoriteFilter()

    /// 仅按关键字搜索，不过滤其他维度。
    public static func keyword(_ keyword: String) -> KXUI05FavoriteFilter {
        KXUI05FavoriteFilter(keyword: keyword)
    }

    /// 仅按收藏类型过滤。
    public static func types(_ types: [KLFavoriteItemType]) -> KXUI05FavoriteFilter {
        KXUI05FavoriteFilter(types: types)
    }
}

// MARK: - 收藏列表排序规则

public enum KXUI05SortRule: String, Codable, Sendable, CaseIterable {
    case sortIndexAscending = "sortIndexAsc"
    case sortIndexDescending = "sortIndexDesc"
    case createdAtAscending = "createdAtAsc"
    case createdAtDescending = "createdAtDesc"
    case titleAscending = "titleAsc"
    case titleDescending = "titleDesc"
    case symbolAscending = "symbolAsc"
    case symbolDescending = "symbolDesc"
    case timeframeCountAscending = "timeframeCountAsc"
    case timeframeCountDescending = "timeframeCountDesc"
    case indicatorCountAscending = "indicatorCountAsc"
    case indicatorCountDescending = "indicatorCountDesc"
    case exchangeIDAscending = "exchangeIDAsc"
    case exchangeIDDescending = "exchangeIDDesc"
    case marketTypeAscending = "marketTypeAsc"
    case marketTypeDescending = "marketTypeDesc"

    public var displayName: String {
        switch self {
        case .sortIndexAscending: return "排序权重 ↑"
        case .sortIndexDescending: return "排序权重 ↓"
        case .createdAtAscending: return "添加时间 ↑"
        case .createdAtDescending: return "添加时间 ↓"
        case .titleAscending: return "名称 ↑"
        case .titleDescending: return "名称 ↓"
        case .symbolAscending: return "币对 ↑"
        case .symbolDescending: return "币对 ↓"
        case .timeframeCountAscending: return "周期数量 ↑"
        case .timeframeCountDescending: return "周期数量 ↓"
        case .indicatorCountAscending: return "指标数量 ↑"
        case .indicatorCountDescending: return "指标数量 ↓"
        case .exchangeIDAscending: return "交易所 ↑"
        case .exchangeIDDescending: return "交易所 ↓"
        case .marketTypeAscending: return "市场类型 ↑"
        case .marketTypeDescending: return "市场类型 ↓"
        }
    }
}

// MARK: - 收藏列表分组规则

public enum KXUI05GroupRule: String, Codable, Sendable, CaseIterable {
    case none
    case type
    case exchangeID
    case marketType
    case quoteCurrency
    case createdDay

    public var displayName: String {
        switch self {
        case .none: return "不分组"
        case .type: return "按收藏类型"
        case .exchangeID: return "按交易所"
        case .marketType: return "按市场类型"
        case .quoteCurrency: return "按计价币"
        case .createdDay: return "按添加日期"
        }
    }
}

// MARK: - 收藏列表分组条目

public struct KXUI05FavoritesGroup: Codable, Equatable, Sendable {
    public let title: String
    public let items: [KXUI05FavoriteListItem]
    public let itemCount: Int

    public init(title: String, items: [KXUI05FavoriteListItem]) {
        self.title = title
        self.items = items
        self.itemCount = items.count
    }
}

// MARK: - 收藏列表适配器状态

public struct KXUI05FavoritesListState: Codable, Equatable, Sendable {
    public let groups: [KXUI05FavoritesGroup]
    public let totalCount: Int
    public let allCount: Int
    public let hasItems: Bool
    public let isEmpty: Bool
    public let filter: KXUI05FavoriteFilter
    public let sortRule: KXUI05SortRule
    public let groupRule: KXUI05GroupRule
    public let generatedAt: Date

    public init(
        groups: [KXUI05FavoritesGroup] = [],
        totalCount: Int = 0,
        allCount: Int = 0,
        filter: KXUI05FavoriteFilter = .none,
        sortRule: KXUI05SortRule = .sortIndexAscending,
        groupRule: KXUI05GroupRule = .type,
        generatedAt: Date = Date()
    ) {
        self.groups = groups
        self.totalCount = totalCount
        self.allCount = allCount
        self.hasItems = totalCount > 0
        self.isEmpty = totalCount == 0
        self.filter = filter
        self.sortRule = sortRule
        self.groupRule = groupRule
        self.generatedAt = generatedAt
    }
}

// MARK: - 收藏列表数据适配器

public enum KXUI05FavoritesListAdapter: Sendable {

    // MARK: 主入口适配

    /// 从收藏层 KLFavoriteCollectionSnapshot 生成 UI 可消费的列表状态。
    ///
    /// - Parameters:
    ///   - snapshot: 收藏层模型的集合快照。
    ///   - filter: 过滤条件。
    ///   - sortRule: 排序规则。
    ///   - groupRule: 分组规则。
    /// - Returns: 收藏列表 UI 状态，包含分组、条目数量和空状态。
    public static func adapt(
        snapshot: KLFavoriteCollectionSnapshot,
        filter: KXUI05FavoriteFilter = .none,
        sortRule: KXUI05SortRule = .sortIndexAscending,
        groupRule: KXUI05GroupRule = .type
    ) -> KXUI05FavoritesListState {
        let allItems = collectItems(from: snapshot)
        let filtered = filterItems(allItems, by: filter)
        let sorted = sortItems(filtered, by: sortRule)
        let groups = groupItems(sorted, by: groupRule)

        return KXUI05FavoritesListState(
            groups: groups,
            totalCount: sorted.count,
            allCount: allItems.count,
            filter: filter,
            sortRule: sortRule,
            groupRule: groupRule,
            generatedAt: Date()
        )
    }

    // MARK: 收集

    /// 从 KLFavoriteCollectionSnapshot 收集所有条目为 UI 列表项。
    public static func collectItems(from snapshot: KLFavoriteCollectionSnapshot) -> [KXUI05FavoriteListItem] {
        snapshot.items.map { item in
            let summary = item.displaySummary(groupedBy: mapGroupField(from: .type))
            return KXUI05FavoriteListItem(
                id: item.id,
                type: item.type,
                title: summary.title,
                subtitle: summary.subtitle,
                detail: summary.detail,
                badges: summary.badges,
                groupKey: summary.groupKey,
                sortIndex: item.sortIndex,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt,
                symbol: item.symbol,
                exchangeID: item.exchangeID,
                marketType: item.marketType,
                note: item.note,
                tags: item.tags,
                timeframeCount: item.timeframes.count,
                indicatorCount: item.indicatorIDs.count
            )
        }
    }

    /// 从 KLFavoriteTradingPair 数组生成 UI 条目列表。
    public static func collectItems(from pairFavorites: [KLFavoriteTradingPair]) -> [KXUI05FavoriteListItem] {
        pairFavorites.map { favorite in
            let pair = favorite.pair
            return KXUI05FavoriteListItem(
                id: favorite.id,
                type: .tradingPair,
                title: pair.displayName,
                subtitle: [pair.exchangeID, pair.marketType.rawValue, pair.status.rawValue].joined(separator: " · "),
                detail: favorite.note,
                badges: [KLFavoriteItemType.tradingPair.displayName, pair.baseCurrency, pair.quoteCurrency, pair.exchangeID],
                groupKey: mapTradingPairGroupKey(pair, for: .type),
                sortIndex: favorite.sortIndex,
                createdAt: favorite.createdAt,
                symbol: pair.symbol,
                exchangeID: pair.exchangeID,
                marketType: pair.marketType,
                note: favorite.note
            )
        }
    }

    /// 从 KXTimeframeCombination 数组生成 UI 条目列表。
    public static func collectItems(from combinations: [KXTimeframeCombination]) -> [KXUI05FavoriteListItem] {
        combinations.enumerated().map { index, combo in
            KXUI05FavoriteListItem(
                id: combo.id,
                type: .timeframeCombination,
                title: combo.name,
                subtitle: combo.timeframes.map { $0.rawValue }.joined(separator: " / "),
                badges: [KLFavoriteItemType.timeframeCombination.displayName, "\(combo.timeframes.count)"],
                groupKey: KLFavoriteItemType.timeframeCombination.displayName,
                sortIndex: index,
                timeframeCount: combo.timeframes.count
            )
        }
    }

    /// 从 KLIndicatorCombination 数组生成 UI 条目列表。
    public static func collectItems(from combinations: [KLIndicatorCombination]) -> [KXUI05FavoriteListItem] {
        combinations.enumerated().map { index, combo in
            KXUI05FavoriteListItem(
                id: combo.id,
                type: .indicatorCombination,
                title: combo.name,
                subtitle: combo.indicatorIDs.joined(separator: " / "),
                badges: [KLFavoriteItemType.indicatorCombination.displayName, "\(combo.indicatorIDs.count)"],
                groupKey: KLFavoriteItemType.indicatorCombination.displayName,
                sortIndex: index,
                indicatorCount: combo.indicatorIDs.count
            )
        }
    }

    // MARK: 过滤

    /// 按过滤条件筛选条目。所有字段均为 AND 关系。
    public static func filterItems(
        _ items: [KXUI05FavoriteListItem],
        by filter: KXUI05FavoriteFilter
    ) -> [KXUI05FavoriteListItem] {
        items.filter { item in
            if filter.isPlaceholderExcluded, item.isPlaceholder { return false }
            if let types = filter.types, !types.contains(item.type) { return false }
            if let keyword = filter.keyword, !matchesKeyword(item, keyword: keyword) { return false }
            if let exchangeID = filter.exchangeID, !exchangeMatches(item, exchangeID: exchangeID) { return false }
            if let marketType = filter.marketType, item.marketType != marketType { return false }
            if let base = filter.baseCurrency, let symbol = item.symbol,
               !symbol.uppercased().hasPrefix(base.uppercased()) { return false }
            if let quote = filter.quoteCurrency,
               !item.title.uppercased().hasSuffix(quote.uppercased()),
               !item.badges.contains(where: { $0.uppercased() == quote.uppercased() }) { return false }
            if let min = filter.minTimeframeCount, item.timeframeCount < min { return false }
            if let min = filter.minIndicatorCount, item.indicatorCount < min { return false }
            if let hasNote = filter.hasNote {
                if hasNote, item.note == nil { return false }
                if !hasNote, item.note != nil { return false }
            }
            return true
        }
    }

    // MARK: 排序

    /// 按排序规则对条目排序。相等时以 sortIndex、创建时间、ID 稳定兜底。
    public static func sortItems(
        _ items: [KXUI05FavoriteListItem],
        by rule: KXUI05SortRule
    ) -> [KXUI05FavoriteListItem] {
        items.sorted { lhs, rhs in
            let ascendingResult: Bool
            switch rule {
            case .sortIndexAscending:
                ascendingResult = compareSortIndex(lhs, rhs, ascending: true)
            case .sortIndexDescending:
                ascendingResult = compareSortIndex(lhs, rhs, ascending: false)
            case .createdAtAscending:
                ascendingResult = compareCreatedAt(lhs, rhs, ascending: true)
            case .createdAtDescending:
                ascendingResult = compareCreatedAt(lhs, rhs, ascending: false)
            case .titleAscending:
                ascendingResult = compareString(lhs.title, rhs.title, ascending: true, fallbackLeft: lhs.id, fallbackRight: rhs.id)
            case .titleDescending:
                ascendingResult = compareString(lhs.title, rhs.title, ascending: false, fallbackLeft: lhs.id, fallbackRight: rhs.id)
            case .symbolAscending:
                ascendingResult = compareSymbol(lhs, rhs, ascending: true)
            case .symbolDescending:
                ascendingResult = compareSymbol(lhs, rhs, ascending: false)
            case .timeframeCountAscending:
                ascendingResult = compareInt(lhs.timeframeCount, rhs.timeframeCount, ascending: true, fallbackLeft: lhs.id, fallbackRight: rhs.id)
            case .timeframeCountDescending:
                ascendingResult = compareInt(lhs.timeframeCount, rhs.timeframeCount, ascending: false, fallbackLeft: lhs.id, fallbackRight: rhs.id)
            case .indicatorCountAscending:
                ascendingResult = compareInt(lhs.indicatorCount, rhs.indicatorCount, ascending: true, fallbackLeft: lhs.id, fallbackRight: rhs.id)
            case .indicatorCountDescending:
                ascendingResult = compareInt(lhs.indicatorCount, rhs.indicatorCount, ascending: false, fallbackLeft: lhs.id, fallbackRight: rhs.id)
            case .exchangeIDAscending:
                ascendingResult = compareExchangeID(lhs, rhs, ascending: true)
            case .exchangeIDDescending:
                ascendingResult = compareExchangeID(lhs, rhs, ascending: false)
            case .marketTypeAscending:
                ascendingResult = compareMarketType(lhs, rhs, ascending: true)
            case .marketTypeDescending:
                ascendingResult = compareMarketType(lhs, rhs, ascending: false)
            }
            return ascendingResult
        }
    }

    // MARK: 分组

    /// 按分组规则将条目分组。各组内部保持原有排序。
    public static func groupItems(
        _ items: [KXUI05FavoriteListItem],
        by rule: KXUI05GroupRule
    ) -> [KXUI05FavoritesGroup] {
        if rule == .none {
            return [KXUI05FavoritesGroup(title: "全部", items: items)]
        }

        let groupField = mapGroupField(from: rule)
        let grouped = Dictionary(grouping: items) { item -> String in
            itemGroupKey(for: item, field: groupField)
        }

        return grouped.keys.sorted().compactMap { key in
            guard let groupItems = grouped[key], !groupItems.isEmpty else { return nil }
            return KXUI05FavoritesGroup(title: key, items: groupItems)
        }
    }

    // MARK: 搜索

    /// 按关键字搜索。等价于 filter 传 keyword。便捷入口。
    public static func search(
        snapshot: KLFavoriteCollectionSnapshot,
        keyword: String,
        sortRule: KXUI05SortRule = .sortIndexAscending,
        groupRule: KXUI05GroupRule = .type
    ) -> KXUI05FavoritesListState {
        adapt(
            snapshot: snapshot,
            filter: .keyword(keyword),
            sortRule: sortRule,
            groupRule: groupRule
        )
    }

    // MARK: 空状态

    /// 返回空列表状态。
    public static func emptyState(
        filter: KXUI05FavoriteFilter = .none,
        sortRule: KXUI05SortRule = .sortIndexAscending,
        groupRule: KXUI05GroupRule = .type
    ) -> KXUI05FavoritesListState {
        let placeholderGroup = KXUI05FavoritesGroup(
            title: "全部",
            items: [KXUI05FavoriteListItem.placeholder()]
        )
        return KXUI05FavoritesListState(
            groups: [placeholderGroup],
            totalCount: 0,
            allCount: 0,
            filter: filter,
            sortRule: sortRule,
            groupRule: groupRule,
            generatedAt: Date()
        )
    }

    /// 检查快照是否为空。
    public static func isEmptySnapshot(_ snapshot: KLFavoriteCollectionSnapshot) -> Bool {
        snapshot.items.isEmpty
    }
}

// MARK: - 内部纯函数

private extension KXUI05FavoritesListAdapter {
    static func matchesKeyword(_ item: KXUI05FavoriteListItem, keyword: String) -> Bool {
        let token = trimmedLower(keyword)
        guard !token.isEmpty else { return true }
        let searchable = [
            item.title,
            item.subtitle ?? "",
            item.detail ?? "",
            item.symbol ?? "",
            item.exchangeID ?? "",
            item.note ?? ""
        ] + item.badges + item.tags
        return searchable.map { trimmedLower($0) }.joined(separator: " ").contains(token)
    }

    static func exchangeMatches(_ item: KXUI05FavoriteListItem, exchangeID: KLExchangeID) -> Bool {
        trimmedLower(item.exchangeID ?? "") == trimmedLower(exchangeID)
    }

    static func compareSortIndex(_ lhs: KXUI05FavoriteListItem, _ rhs: KXUI05FavoriteListItem, ascending: Bool) -> Bool {
        if lhs.sortIndex != rhs.sortIndex { return ascending ? lhs.sortIndex < rhs.sortIndex : lhs.sortIndex > rhs.sortIndex }
        if lhs.createdAt != rhs.createdAt { return ascending ? lhs.createdAt < rhs.createdAt : lhs.createdAt > rhs.createdAt }
        return lhs.id < rhs.id
    }

    static func compareCreatedAt(_ lhs: KXUI05FavoriteListItem, _ rhs: KXUI05FavoriteListItem, ascending: Bool) -> Bool {
        if lhs.createdAt != rhs.createdAt { return ascending ? lhs.createdAt < rhs.createdAt : lhs.createdAt > rhs.createdAt }
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return lhs.id < rhs.id
    }

    static func compareSymbol(_ lhs: KXUI05FavoriteListItem, _ rhs: KXUI05FavoriteListItem, ascending: Bool) -> Bool {
        let left = trimmedLower(lhs.symbol ?? "")
        let right = trimmedLower(rhs.symbol ?? "")
        if left != right { return ascending ? left < right : left > right }
        return compareCreatedAt(lhs, rhs, ascending: true)
    }

    static func compareExchangeID(_ lhs: KXUI05FavoriteListItem, _ rhs: KXUI05FavoriteListItem, ascending: Bool) -> Bool {
        let left = trimmedLower(lhs.exchangeID ?? "")
        let right = trimmedLower(rhs.exchangeID ?? "")
        if left != right { return ascending ? left < right : left > right }
        return compareSortIndex(lhs, rhs, ascending: true)
    }

    static func compareMarketType(_ lhs: KXUI05FavoriteListItem, _ rhs: KXUI05FavoriteListItem, ascending: Bool) -> Bool {
        let left = trimmedLower(lhs.marketType?.rawValue ?? "")
        let right = trimmedLower(rhs.marketType?.rawValue ?? "")
        if left != right { return ascending ? left < right : left > right }
        return compareSortIndex(lhs, rhs, ascending: true)
    }

    static func compareString(_ left: String, _ right: String, ascending: Bool, fallbackLeft: String, fallbackRight: String) -> Bool {
        let l = trimmedLower(left)
        let r = trimmedLower(right)
        if l != r { return ascending ? l < r : l > r }
        return fallbackLeft < fallbackRight
    }

    static func compareInt(_ left: Int, _ right: Int, ascending: Bool, fallbackLeft: String, fallbackRight: String) -> Bool {
        if left != right { return ascending ? left < right : left > right }
        return fallbackLeft < fallbackRight
    }

    static func trimmedLower(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func itemGroupKey(for item: KXUI05FavoriteListItem, field: KLFavoriteGroupField) -> String {
        switch field {
        case .type:
            return item.type.displayName
        case .exchangeID:
            return item.exchangeID ?? "未指定交易所"
        case .marketType:
            return item.marketType?.rawValue ?? "未指定市场"
        case .quoteCurrency:
            return extractQuoteCurrency(from: item) ?? "未指定计价币"
        case .timeframeCount:
            return "\(item.timeframeCount) 个周期"
        case .indicatorCount:
            return "\(item.indicatorCount) 个指标"
        case .createdDay:
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: item.createdAt)
        case .none:
            return ""
        }
    }

    static func mapGroupField(from rule: KXUI05GroupRule) -> KLFavoriteGroupField {
        switch rule {
        case .none: return .none
        case .type: return .type
        case .exchangeID: return .exchangeID
        case .marketType: return .marketType
        case .quoteCurrency: return .quoteCurrency
        case .createdDay: return .createdDay
        }
    }

    static func extractQuoteCurrency(from item: KXUI05FavoriteListItem) -> String? {
        // 尝试从标题（如 BTC/USDT）中提取计价币
        if let symbol = item.symbol {
            let parts = symbol.split(separator: "/").map(String.init)
            if parts.count == 2 { return parts[1] }
        }
        // 从 badges 中猜测：遍历 badge，排除类型名后取第一个可能是计价币的项
        for badge in item.badges {
            if badge == item.type.displayName { continue }
            if let symbol = item.symbol, symbol.uppercased().hasPrefix(badge.uppercased()) { continue }
            return badge
        }
        return nil
    }

    static func mapTradingPairGroupKey(_ pair: KLTradingPairDescriptor, for field: KLFavoriteGroupField) -> String {
        switch field {
        case .type: return KLFavoriteItemType.tradingPair.displayName
        case .exchangeID: return pair.exchangeID
        case .marketType: return pair.marketType.rawValue
        case .quoteCurrency: return pair.quoteCurrency
        case .timeframeCount: return "0 个周期"
        case .indicatorCount: return "0 个指标"
        case .createdDay:
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return dateFormatter.string(from: Date())
        case .none: return ""
        }
    }
}
