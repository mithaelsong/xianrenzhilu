//
//  KX-UT-02_收藏服务.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：币对收藏、取消收藏、筛选、排序服务
//  禁止事项：禁止 UI 绘制、禁止数据库访问、禁止网络请求
//

import Foundation


// MARK: - 币对收藏服务类型

public enum KXUT02FavoriteSortKey: String, Codable, Sendable, CaseIterable {
    case sortIndex
    case createdAt
    case symbol
    case displayName
    case exchangeID
    case baseCurrency
    case quoteCurrency
    case marketType
    case status
}

public struct KXUT02FavoriteFilter: Codable, Equatable, Sendable {
    public let keyword: String?
    public let exchangeID: KLExchangeID?
    public let marketType: KLMarketType?
    public let status: KLTradingPairStatus?
    public let baseCurrency: String?
    public let quoteCurrency: String?

    public init(
        keyword: String? = nil,
        exchangeID: KLExchangeID? = nil,
        marketType: KLMarketType? = nil,
        status: KLTradingPairStatus? = nil,
        baseCurrency: String? = nil,
        quoteCurrency: String? = nil
    ) {
        self.keyword = keyword
        self.exchangeID = exchangeID
        self.marketType = marketType
        self.status = status
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
    }
}

public struct KXUT02FavoriteSortDescriptor: Codable, Equatable, Sendable {
    public let key: KXUT02FavoriteSortKey
    public let order: KLQuerySortOrder

    public init(key: KXUT02FavoriteSortKey = .sortIndex, order: KLQuerySortOrder = .ascending) {
        self.key = key
        self.order = order
    }
}

public enum KXUT02FavoriteOperationKind: String, Codable, Sendable, CaseIterable {
    case added
    case removed
    case toggledOn
    case toggledOff
    case unchanged
    case reordered
}

public struct KXUT02FavoriteOperationResult: Codable, Equatable, Sendable {
    public let favorites: [KLFavoriteTradingPair]
    public let favorite: KLFavoriteTradingPair?
    public let kind: KXUT02FavoriteOperationKind
    public let changed: Bool
    public let message: String

    public init(
        favorites: [KLFavoriteTradingPair],
        favorite: KLFavoriteTradingPair?,
        kind: KXUT02FavoriteOperationKind,
        changed: Bool,
        message: String
    ) {
        self.favorites = favorites
        self.favorite = favorite
        self.kind = kind
        self.changed = changed
        self.message = message
    }
}

// MARK: - 币对收藏服务

public enum KXUT02Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UT-02",
        fileName: "KX-UT-02_币对收藏服务.swift",
        layer: .favorite,
        relativePath: "收藏层/KX-UT-02_币对收藏服务.swift",
        duty: "币对收藏、取消收藏、筛选、排序服务"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "币对收藏服务", passed: true, message: "已升级为纯服务逻辑：支持 add/remove/toggle/contains/list/filter/sort/reorder")
    }

    /// 添加收藏。若同一交易对已存在，则返回原数组且 changed=false。
    public static func add(
        favorites: [KLFavoriteTradingPair],
        pair: KLTradingPairDescriptor,
        note: String? = nil,
        at index: Int? = nil,
        createdAt: Date = Date()
    ) -> KXUT02FavoriteOperationResult {
        if let existing = favorite(in: favorites, matching: pair) {
            return KXUT02FavoriteOperationResult(
                favorites: normalizeSortIndexes(favorites),
                favorite: existing,
                kind: .unchanged,
                changed: false,
                message: "交易对已在收藏中"
            )
        }

        var next = normalizeSortIndexes(favorites)
        let insertionIndex = clampedInsertionIndex(index ?? next.count, count: next.count)
        let favorite = KLFavoriteTradingPair(
            id: favoriteID(for: pair),
            pair: pair,
            note: note,
            sortIndex: insertionIndex,
            createdAt: createdAt
        )
        next.insert(favorite, at: insertionIndex)
        next = normalizeSortIndexes(next)

        return KXUT02FavoriteOperationResult(
            favorites: next,
            favorite: next.first(where: { $0.id == favorite.id }),
            kind: .added,
            changed: true,
            message: "交易对已加入收藏"
        )
    }

    /// 按交易对取消收藏。若不存在，则返回原数组且 changed=false。
    public static func remove(
        favorites: [KLFavoriteTradingPair],
        pair: KLTradingPairDescriptor
    ) -> KXUT02FavoriteOperationResult {
        remove(favorites: favorites, favoriteID: favoriteID(for: pair))
    }

    /// 按收藏 ID 取消收藏。若不存在，则返回原数组且 changed=false。
    public static func remove(
        favorites: [KLFavoriteTradingPair],
        favoriteID: String
    ) -> KXUT02FavoriteOperationResult {
        let normalized = normalizeSortIndexes(favorites)
        guard let removed = normalized.first(where: { $0.id == favoriteID }) else {
            return KXUT02FavoriteOperationResult(
                favorites: normalized,
                favorite: nil,
                kind: .unchanged,
                changed: false,
                message: "未找到需要取消的收藏"
            )
        }

        let next = normalizeSortIndexes(normalized.filter { $0.id != favoriteID })
        return KXUT02FavoriteOperationResult(
            favorites: next,
            favorite: removed,
            kind: .removed,
            changed: true,
            message: "交易对已取消收藏"
        )
    }

    /// 切换收藏状态：已收藏则取消，未收藏则添加。
    public static func toggle(
        favorites: [KLFavoriteTradingPair],
        pair: KLTradingPairDescriptor,
        note: String? = nil,
        at index: Int? = nil,
        createdAt: Date = Date()
    ) -> KXUT02FavoriteOperationResult {
        if contains(favorites: favorites, pair: pair) {
            let result = remove(favorites: favorites, pair: pair)
            return KXUT02FavoriteOperationResult(
                favorites: result.favorites,
                favorite: result.favorite,
                kind: .toggledOff,
                changed: result.changed,
                message: "交易对已从收藏中移除"
            )
        }

        let result = add(favorites: favorites, pair: pair, note: note, at: index, createdAt: createdAt)
        return KXUT02FavoriteOperationResult(
            favorites: result.favorites,
            favorite: result.favorite,
            kind: .toggledOn,
            changed: result.changed,
            message: "交易对已加入收藏"
        )
    }

    /// 判断交易对是否已收藏。
    public static func contains(
        favorites: [KLFavoriteTradingPair],
        pair: KLTradingPairDescriptor
    ) -> Bool {
        favorite(in: favorites, matching: pair) != nil
    }

    /// 返回按 sortIndex 归一化后的收藏列表。
    public static func list(favorites: [KLFavoriteTradingPair]) -> [KLFavoriteTradingPair] {
        normalizeSortIndexes(favorites)
    }

    /// 按条件筛选收藏列表。所有非空条件均为 AND 关系。
    public static func filter(
        favorites: [KLFavoriteTradingPair],
        by filter: KXUT02FavoriteFilter
    ) -> [KLFavoriteTradingPair] {
        normalizeSortIndexes(favorites).filter { favorite in
            matchesKeyword(favorite, keyword: filter.keyword)
            && matchesOptional(favorite.pair.exchangeID, filter.exchangeID)
            && matchesOptional(favorite.pair.marketType, filter.marketType)
            && matchesOptional(favorite.pair.status, filter.status)
            && matchesOptionalFolded(favorite.pair.baseCurrency, filter.baseCurrency)
            && matchesOptionalFolded(favorite.pair.quoteCurrency, filter.quoteCurrency)
        }
    }

    /// 按单个排序描述符排序收藏列表。
    public static func sort(
        favorites: [KLFavoriteTradingPair],
        by descriptor: KXUT02FavoriteSortDescriptor = KXUT02FavoriteSortDescriptor()
    ) -> [KLFavoriteTradingPair] {
        sort(favorites: favorites, by: [descriptor])
    }

    /// 按多个排序描述符排序收藏列表；描述符相等时以 sortIndex、symbol、id 稳定兜底。
    public static func sort(
        favorites: [KLFavoriteTradingPair],
        by descriptors: [KXUT02FavoriteSortDescriptor]
    ) -> [KLFavoriteTradingPair] {
        let normalized = normalizeSortIndexes(favorites)
        let effectiveDescriptors = descriptors.isEmpty ? [KXUT02FavoriteSortDescriptor()] : descriptors

        return normalized.sorted { lhs, rhs in
            for descriptor in effectiveDescriptors {
                let comparison = compare(lhs, rhs, key: descriptor.key)
                if comparison < 0 { return descriptor.order == .ascending }
                if comparison > 0 { return descriptor.order == .descending }
            }

            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            let symbolComparison = compareFolded(lhs.pair.symbol, rhs.pair.symbol)
            if symbolComparison != 0 { return symbolComparison < 0 }
            return lhs.id < rhs.id
        }
    }

    /// 将指定收藏移动到目标位置，并重新生成连续 sortIndex。
    public static func reorder(
        favorites: [KLFavoriteTradingPair],
        movingFavoriteID: String,
        to targetIndex: Int
    ) -> KXUT02FavoriteOperationResult {
        var next = normalizeSortIndexes(favorites)
        guard let sourceIndex = next.firstIndex(where: { $0.id == movingFavoriteID }) else {
            return KXUT02FavoriteOperationResult(
                favorites: next,
                favorite: nil,
                kind: .unchanged,
                changed: false,
                message: "未找到需要移动的收藏"
            )
        }

        let item = next.remove(at: sourceIndex)
        let insertionIndex = clampedInsertionIndex(targetIndex, count: next.count)
        next.insert(item, at: insertionIndex)
        next = normalizeSortIndexes(next)

        return KXUT02FavoriteOperationResult(
            favorites: next,
            favorite: next.first(where: { $0.id == movingFavoriteID }),
            kind: .reordered,
            changed: sourceIndex != insertionIndex,
            message: sourceIndex == insertionIndex ? "收藏顺序未变化" : "收藏顺序已更新"
        )
    }

    /// 按目标 ID 顺序重排。未出现在 orderedFavoriteIDs 中的收藏保留并追加到末尾。
    public static func reorder(
        favorites: [KLFavoriteTradingPair],
        orderedFavoriteIDs: [String]
    ) -> KXUT02FavoriteOperationResult {
        let normalized = normalizeSortIndexes(favorites)
        var remaining = normalized
        var reordered: [KLFavoriteTradingPair] = []

        for id in orderedFavoriteIDs {
            if let index = remaining.firstIndex(where: { $0.id == id }) {
                reordered.append(remaining.remove(at: index))
            }
        }
        reordered.append(contentsOf: remaining)
        let next = normalizeSortIndexes(reordered)
        let changed = normalized.map(\ .id) != next.map(\ .id)

        return KXUT02FavoriteOperationResult(
            favorites: next,
            favorite: nil,
            kind: changed ? .reordered : .unchanged,
            changed: changed,
            message: changed ? "收藏顺序已更新" : "收藏顺序未变化"
        )
    }

    public static func placeholder() {
        // 已实现纯服务逻辑；保留占位入口以兼容骨架检查。
    }

    // MARK: - 私有纯函数

    private static func favoriteID(for pair: KLTradingPairDescriptor) -> String {
        [pair.exchangeID, pair.marketType.rawValue, pair.instrumentID, pair.symbol]
            .map { normalizedText($0) }
            .joined(separator: "|")
    }

    private static func favorite(in favorites: [KLFavoriteTradingPair], matching pair: KLTradingPairDescriptor) -> KLFavoriteTradingPair? {
        let id = favoriteID(for: pair)
        return favorites.first { favorite in
            favorite.id == id || sameTradingPair(favorite.pair, pair)
        }
    }

    private static func sameTradingPair(_ lhs: KLTradingPairDescriptor, _ rhs: KLTradingPairDescriptor) -> Bool {
        normalizedText(lhs.exchangeID) == normalizedText(rhs.exchangeID)
        && normalizedText(lhs.instrumentID) == normalizedText(rhs.instrumentID)
        && normalizedText(lhs.symbol) == normalizedText(rhs.symbol)
        && lhs.marketType == rhs.marketType
    }

    private static func normalizeSortIndexes(_ favorites: [KLFavoriteTradingPair]) -> [KLFavoriteTradingPair] {
        favorites
            .sorted {
                if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id < $1.id
            }
            .enumerated()
            .map { index, favorite in
                KLFavoriteTradingPair(
                    id: favorite.id,
                    pair: favorite.pair,
                    note: favorite.note,
                    sortIndex: index,
                    createdAt: favorite.createdAt
                )
            }
    }

    private static func clampedInsertionIndex(_ index: Int, count: Int) -> Int {
        max(0, min(index, count))
    }

    private static func matchesKeyword(_ favorite: KLFavoriteTradingPair, keyword: String?) -> Bool {
        guard let keyword, normalizedText(keyword).isEmpty == false else { return true }
        let target = [
            favorite.pair.symbol,
            favorite.pair.baseCurrency,
            favorite.pair.quoteCurrency,
            favorite.pair.exchangeID,
            favorite.pair.instrumentID,
            favorite.pair.displayName,
            favorite.note ?? ""
        ].map { normalizedText($0) }.joined(separator: " ")
        return target.contains(normalizedText(keyword))
    }

    private static func matchesOptional<T: Equatable>(_ value: T, _ expected: T?) -> Bool {
        guard let expected else { return true }
        return value == expected
    }

    private static func matchesOptionalFolded(_ value: String, _ expected: String?) -> Bool {
        guard let expected, normalizedText(expected).isEmpty == false else { return true }
        return normalizedText(value) == normalizedText(expected)
    }

    private static func compare(_ lhs: KLFavoriteTradingPair, _ rhs: KLFavoriteTradingPair, key: KXUT02FavoriteSortKey) -> Int {
        switch key {
        case .sortIndex:
            return compareInt(lhs.sortIndex, rhs.sortIndex)
        case .createdAt:
            return compareDate(lhs.createdAt, rhs.createdAt)
        case .symbol:
            return compareFolded(lhs.pair.symbol, rhs.pair.symbol)
        case .displayName:
            return compareFolded(lhs.pair.displayName, rhs.pair.displayName)
        case .exchangeID:
            return compareFolded(lhs.pair.exchangeID, rhs.pair.exchangeID)
        case .baseCurrency:
            return compareFolded(lhs.pair.baseCurrency, rhs.pair.baseCurrency)
        case .quoteCurrency:
            return compareFolded(lhs.pair.quoteCurrency, rhs.pair.quoteCurrency)
        case .marketType:
            return compareFolded(lhs.pair.marketType.rawValue, rhs.pair.marketType.rawValue)
        case .status:
            return compareFolded(lhs.pair.status.rawValue, rhs.pair.status.rawValue)
        }
    }

    private static func compareInt(_ lhs: Int, _ rhs: Int) -> Int {
        if lhs < rhs { return -1 }
        if lhs > rhs { return 1 }
        return 0
    }

    private static func compareDate(_ lhs: Date, _ rhs: Date) -> Int {
        if lhs < rhs { return -1 }
        if lhs > rhs { return 1 }
        return 0
    }

    private static func compareFolded(_ lhs: String, _ rhs: String) -> Int {
        let left = normalizedText(lhs)
        let right = normalizedText(rhs)
        if left < right { return -1 }
        if left > right { return 1 }
        return 0
    }

    private static func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
