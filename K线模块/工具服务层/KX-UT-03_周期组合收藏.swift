//
//  KX-UT-03_周期组合收藏.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：周期组合收藏服务
//  禁止事项：禁止 UI 绘制、禁止数据库读写、禁止网络请求
//

import Foundation


// MARK: - 周期组合收藏服务骨架

public struct KXUT03Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UT-03",
        fileName: "KX-UT-03_周期组合收藏服务.swift",
        layer: .favorite,
        relativePath: "收藏层/KX-UT-03_周期组合收藏服务.swift",
        duty: "周期组合收藏服务"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "周期组合收藏服务", passed: true, message: "已实现纯内存周期组合收藏增删改查、校验、筛选、排序、重排与默认组合")
    }

    public static func placeholder() {
        // 本文件仅提供纯服务逻辑：不读写数据库、不请求网络、不绘制 UI。
    }
}

// MARK: - 周期组合收藏操作结果

public struct KXUT03TimeframeCombinationOperationResult: Equatable, Sendable {
    public let combinations: [KXTimeframeCombination]
    public let affectedCombination: KXTimeframeCombination?
    public let changed: Bool
    public let message: String

    public init(
        combinations: [KXTimeframeCombination],
        affectedCombination: KXTimeframeCombination?,
        changed: Bool,
        message: String
    ) {
        self.combinations = combinations
        self.affectedCombination = affectedCombination
        self.changed = changed
        self.message = message
    }
}

public enum KXUT03TimeframeCombinationSortKey: Sendable, CaseIterable {
    case id
    case name
    case timeframeCount
    case firstTimeframeSeconds
}

public enum KXUT03SortDirection: Sendable, CaseIterable {
    case ascending
    case descending
}

// MARK: - 周期组合收藏服务

public struct KXUT03TimeframeCombinationService: Sendable {
    public init() {}

    /// 新建周期组合：校验周期非空、合法，按周期秒数去重排序；返回追加后的新数组。
    public func create(
        in combinations: [KXTimeframeCombination],
        id: String? = nil,
        name: String,
        timeframes: [KXTimeframe]
    ) throws -> KXUT03TimeframeCombinationOperationResult {
        let normalizedExisting = try normalizeCombinations(combinations)
        let normalizedID = try normalizeID(id ?? makeStableID(name: name, timeframes: timeframes))

        guard normalizedExisting.contains(where: { $0.id == normalizedID }) == false else {
            throw KLModuleError.invalidQuery(reason: "周期组合 ID 已存在：\(normalizedID)")
        }

        let combination = try makeCombination(id: normalizedID, name: name, timeframes: timeframes)
        return KXUT03TimeframeCombinationOperationResult(
            combinations: normalizedExisting + [combination],
            affectedCombination: combination,
            changed: true,
            message: "周期组合已创建"
        )
    }

    /// 更新周期组合：按 ID 找到已有组合；未传入的字段沿用旧值；返回替换后的新数组。
    public func update(
        in combinations: [KXTimeframeCombination],
        id: String,
        name: String? = nil,
        timeframes: [KXTimeframe]? = nil
    ) throws -> KXUT03TimeframeCombinationOperationResult {
        let normalizedExisting = try normalizeCombinations(combinations)
        let normalizedID = try normalizeID(id)

        guard let index = normalizedExisting.firstIndex(where: { $0.id == normalizedID }) else {
            throw KLModuleError.invalidQuery(reason: "周期组合不存在：\(normalizedID)")
        }

        let oldCombination = normalizedExisting[index]
        let updatedCombination = try makeCombination(
            id: normalizedID,
            name: name ?? oldCombination.name,
            timeframes: timeframes ?? oldCombination.timeframes
        )

        var newCombinations = normalizedExisting
        newCombinations[index] = updatedCombination

        return KXUT03TimeframeCombinationOperationResult(
            combinations: newCombinations,
            affectedCombination: updatedCombination,
            changed: updatedCombination != oldCombination,
            message: updatedCombination == oldCombination ? "周期组合无变化" : "周期组合已更新"
        )
    }

    /// 删除周期组合：按 ID 删除；不存在时返回校验后的原数组与 changed=false。
    public func remove(
        from combinations: [KXTimeframeCombination],
        id: String
    ) throws -> KXUT03TimeframeCombinationOperationResult {
        let normalizedExisting = try normalizeCombinations(combinations)
        let normalizedID = try normalizeID(id)

        guard let index = normalizedExisting.firstIndex(where: { $0.id == normalizedID }) else {
            return KXUT03TimeframeCombinationOperationResult(
                combinations: normalizedExisting,
                affectedCombination: nil,
                changed: false,
                message: "周期组合不存在，无需删除"
            )
        }

        var newCombinations = normalizedExisting
        let removed = newCombinations.remove(at: index)

        return KXUT03TimeframeCombinationOperationResult(
            combinations: newCombinations,
            affectedCombination: removed,
            changed: true,
            message: "周期组合已删除"
        )
    }

    /// 判断数组中是否包含指定 ID 的周期组合。
    public func contains(_ combinations: [KXTimeframeCombination], id: String) -> Bool {
        guard let normalizedID = try? normalizeID(id) else { return false }
        return combinations.contains { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedID }
    }

    /// 判断数组中是否包含指定周期集合的组合；输入周期会先去重、排序并校验合法性。
    public func contains(_ combinations: [KXTimeframeCombination], timeframes: [KXTimeframe]) throws -> Bool {
        let normalizedTimeframes = try normalizeTimeframes(timeframes)
        return try normalizeCombinations(combinations).contains { $0.timeframes == normalizedTimeframes }
    }

    /// 列出周期组合：只做纯内存校验和规范化，不改变调用方原数组。
    public func list(_ combinations: [KXTimeframeCombination]) throws -> [KXTimeframeCombination] {
        try normalizeCombinations(combinations)
    }

    /// 筛选周期组合：支持按关键字匹配 ID、名称、周期 rawValue，并可要求包含指定周期。
    public func filter(
        _ combinations: [KXTimeframeCombination],
        keyword: String? = nil,
        requiredTimeframes: [KXTimeframe] = []
    ) throws -> [KXTimeframeCombination] {
        let normalizedExisting = try normalizeCombinations(combinations)
        let trimmedKeyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRequiredTimeframes = try normalizeOptionalTimeframes(requiredTimeframes)

        return normalizedExisting.filter { combination in
            let matchesKeyword: Bool
            if let trimmedKeyword, trimmedKeyword.isEmpty == false {
                matchesKeyword = combination.id.localizedCaseInsensitiveContains(trimmedKeyword)
                    || combination.name.localizedCaseInsensitiveContains(trimmedKeyword)
                    || combination.timeframes.contains { $0.rawValue.localizedCaseInsensitiveContains(trimmedKeyword) }
            } else {
                matchesKeyword = true
            }

            let matchesRequiredTimeframes = normalizedRequiredTimeframes.allSatisfy { timeframe in
                combination.timeframes.contains(timeframe)
            }

            return matchesKeyword && matchesRequiredTimeframes
        }
    }

    /// 排序周期组合：纯内存排序，不修改调用方原数组。
    public func sort(
        _ combinations: [KXTimeframeCombination],
        by key: KXUT03TimeframeCombinationSortKey = .name,
        direction: KXUT03SortDirection = .ascending
    ) throws -> [KXTimeframeCombination] {
        let normalizedExisting = try normalizeCombinations(combinations)

        let sortedCombinations = normalizedExisting.sorted { lhs, rhs in
            let ascendingResult: Bool
            switch key {
            case .id:
                ascendingResult = lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
            case .name:
                let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
                if nameOrder != .orderedSame {
                    ascendingResult = nameOrder == .orderedAscending
                } else {
                    ascendingResult = lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
                }
            case .timeframeCount:
                if lhs.timeframes.count != rhs.timeframes.count {
                    ascendingResult = lhs.timeframes.count < rhs.timeframes.count
                } else {
                    ascendingResult = lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
                }
            case .firstTimeframeSeconds:
                let lhsSeconds = secondsForFirstTimeframe(lhs)
                let rhsSeconds = secondsForFirstTimeframe(rhs)
                if lhsSeconds != rhsSeconds {
                    ascendingResult = lhsSeconds < rhsSeconds
                } else {
                    ascendingResult = lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
                }
            }

            return direction == .ascending ? ascendingResult : !ascendingResult
        }

        return sortedCombinations
    }

    /// 重排周期组合：按 ID 将一个组合移动到目标下标；返回重排后的新数组。
    public func reorder(
        _ combinations: [KXTimeframeCombination],
        movingID id: String,
        toIndex targetIndex: Int
    ) throws -> KXUT03TimeframeCombinationOperationResult {
        var normalizedExisting = try normalizeCombinations(combinations)
        let normalizedID = try normalizeID(id)

        guard targetIndex >= 0 && targetIndex < normalizedExisting.count else {
            throw KLModuleError.invalidQuery(reason: "目标下标越界：\(targetIndex)")
        }

        guard let sourceIndex = normalizedExisting.firstIndex(where: { $0.id == normalizedID }) else {
            throw KLModuleError.invalidQuery(reason: "周期组合不存在：\(normalizedID)")
        }

        let movingCombination = normalizedExisting.remove(at: sourceIndex)
        normalizedExisting.insert(movingCombination, at: targetIndex)

        return KXUT03TimeframeCombinationOperationResult(
            combinations: normalizedExisting,
            affectedCombination: movingCombination,
            changed: sourceIndex != targetIndex,
            message: sourceIndex == targetIndex ? "周期组合顺序无变化" : "周期组合已重排"
        )
    }

    /// 默认周期组合：稳定 ID + 常用周期，周期会按 KX-FN-02 周期能力排序。
    public func defaultCombination() -> KXTimeframeCombination {
        let defaultTimeframes: [KXTimeframe] = [
            .oneMinute,
            .fiveMinutes,
            .fifteenMinutes,
            .oneHour,
            .fourHours,
            .oneDay
        ]

        return KXTimeframeCombination(
            id: "default-common-timeframes",
            name: "常用周期",
            timeframes: KXUT03TimeframeHelper.sorted(defaultTimeframes)
        )
    }
}

// MARK: - 私有校验与规范化

// MARK: - 收藏层本地周期辅助（避免跨层依赖 KX-FN-02）

private enum KXUT03TimeframeHelper {
    static let supportedDescriptors: [KXTimeframeDescriptor] = [
        KXTimeframeDescriptor(timeframe: .oneSecond, unit: .second, amount: 1, seconds: 1, displayName: "1秒", exchangeValue: "1s"),
        KXTimeframeDescriptor(timeframe: .oneMinute, unit: .minute, amount: 1, seconds: 60, displayName: "1分钟", exchangeValue: "1m"),
        KXTimeframeDescriptor(timeframe: .threeMinutes, unit: .minute, amount: 3, seconds: 180, displayName: "3分钟", exchangeValue: "3m"),
        KXTimeframeDescriptor(timeframe: .fiveMinutes, unit: .minute, amount: 5, seconds: 300, displayName: "5分钟", exchangeValue: "5m"),
        KXTimeframeDescriptor(timeframe: .fifteenMinutes, unit: .minute, amount: 15, seconds: 900, displayName: "15分钟", exchangeValue: "15m"),
        KXTimeframeDescriptor(timeframe: .thirtyMinutes, unit: .minute, amount: 30, seconds: 1_800, displayName: "30分钟", exchangeValue: "30m"),
        KXTimeframeDescriptor(timeframe: .oneHour, unit: .hour, amount: 1, seconds: 3_600, displayName: "1小时", exchangeValue: "1h"),
        KXTimeframeDescriptor(timeframe: .twoHours, unit: .hour, amount: 2, seconds: 7_200, displayName: "2小时", exchangeValue: "2h"),
        KXTimeframeDescriptor(timeframe: .fourHours, unit: .hour, amount: 4, seconds: 14_400, displayName: "4小时", exchangeValue: "4h"),
        KXTimeframeDescriptor(timeframe: .sixHours, unit: .hour, amount: 6, seconds: 21_600, displayName: "6小时", exchangeValue: "6h"),
        KXTimeframeDescriptor(timeframe: .twelveHours, unit: .hour, amount: 12, seconds: 43_200, displayName: "12小时", exchangeValue: "12h"),
        KXTimeframeDescriptor(timeframe: .oneDay, unit: .day, amount: 1, seconds: 86_400, displayName: "1天", exchangeValue: "1d"),
        KXTimeframeDescriptor(timeframe: .twoDays, unit: .day, amount: 2, seconds: 172_800, displayName: "2天", exchangeValue: "2d"),
        KXTimeframeDescriptor(timeframe: .threeDays, unit: .day, amount: 3, seconds: 259_200, displayName: "3天", exchangeValue: "3d"),
        KXTimeframeDescriptor(timeframe: .oneWeek, unit: .week, amount: 1, seconds: 604_800, displayName: "1周", exchangeValue: "1w"),
        KXTimeframeDescriptor(timeframe: .oneMonth, unit: .month, amount: 1, seconds: 2_592_000, displayName: "1月", exchangeValue: "1M"),
        KXTimeframeDescriptor(timeframe: .threeMonths, unit: .month, amount: 3, seconds: 7_776_000, displayName: "3月", exchangeValue: "3M")
    ]

    static func isValid(_ timeframe: KXTimeframe) -> Bool {
        supportedDescriptors.contains { $0.timeframe == timeframe }
    }

    static func sorted(_ timeframes: [KXTimeframe]) -> [KXTimeframe] {
        timeframes.sorted { lhs, rhs in
            let lhsSeconds = seconds(for: lhs) ?? Int.max
            let rhsSeconds = seconds(for: rhs) ?? Int.max
            if lhsSeconds != rhsSeconds { return lhsSeconds < rhsSeconds }
            return lhs.rawValue < rhs.rawValue
        }
    }

    static func seconds(for timeframe: KXTimeframe) -> Int? {
        supportedDescriptors.first { $0.timeframe == timeframe }?.seconds
    }
}

// MARK: - 私有校验与规范化

private extension KXUT03TimeframeCombinationService {
    func normalizeCombinations(_ combinations: [KXTimeframeCombination]) throws -> [KXTimeframeCombination] {
        try combinations.map { combination in
            try makeCombination(
                id: combination.id,
                name: combination.name,
                timeframes: combination.timeframes
            )
        }
    }

    func makeCombination(id: String, name: String, timeframes: [KXTimeframe]) throws -> KXTimeframeCombination {
        KXTimeframeCombination(
            id: try normalizeID(id),
            name: try normalizeName(name),
            timeframes: try normalizeTimeframes(timeframes)
        )
    }

    func normalizeID(_ id: String) throws -> String {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedID.isEmpty == false else {
            throw KLModuleError.invalidQuery(reason: "周期组合 ID 不能为空")
        }
        return normalizedID
    }

    func normalizeName(_ name: String) throws -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.isEmpty == false else {
            throw KLModuleError.invalidQuery(reason: "周期组合名称不能为空")
        }
        return normalizedName
    }

    func normalizeOptionalTimeframes(_ timeframes: [KXTimeframe]) throws -> [KXTimeframe] {
        guard timeframes.isEmpty == false else { return [] }
        return try normalizeTimeframes(timeframes)
    }

    func normalizeTimeframes(_ timeframes: [KXTimeframe]) throws -> [KXTimeframe] {
        guard timeframes.isEmpty == false else {
            throw KLModuleError.invalidQuery(reason: "周期组合不能为空")
        }

        var uniqueTimeframes: [KXTimeframe] = []
        var seenRawValues: Set<String> = []

        for timeframe in timeframes {
            guard KXUT03TimeframeHelper.isValid(timeframe) else {
                throw KLModuleError.invalidTimeframe(value: timeframe.rawValue)
            }

            guard seenRawValues.contains(timeframe.rawValue) == false else { continue }
            seenRawValues.insert(timeframe.rawValue)
            uniqueTimeframes.append(timeframe)
        }

        let sortedTimeframes = KXUT03TimeframeHelper.sorted(uniqueTimeframes)
        guard sortedTimeframes.isEmpty == false else {
            throw KLModuleError.invalidQuery(reason: "周期组合不能为空")
        }
        return sortedTimeframes
    }

    func secondsForFirstTimeframe(_ combination: KXTimeframeCombination) -> Int {
        guard let firstTimeframe = combination.timeframes.first else { return Int.max }
        return KXUT03TimeframeHelper.seconds(for: firstTimeframe) ?? Int.max
    }

    func makeStableID(name: String, timeframes: [KXTimeframe]) -> String {
        let normalizedName = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .map { character -> Character in
                if character.isLetter || character.isNumber { return character }
                return "-"
            }

        let namePart = String(normalizedName)
            .split(separator: "-")
            .joined(separator: "-")

        let timeframePart = KXUT03TimeframeHelper.sorted(timeframes)
            .map(\.rawValue)
            .joined(separator: "-")

        let stablePart = [namePart, timeframePart]
            .filter { $0.isEmpty == false }
            .joined(separator: "-")

        return stablePart.isEmpty ? "timeframe-combination-\(UUID().uuidString)" : stablePart
    }
}
