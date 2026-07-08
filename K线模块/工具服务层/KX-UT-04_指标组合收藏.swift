//
//  KX-UT-04_指标组合收藏.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：指标组合收藏纯服务逻辑
//  禁止事项：禁止指标公式实现、禁止数据库访问、禁止网络请求、禁止 UI 绘制
//

import Foundation


// MARK: - 指标组合收藏服务结果

public nonisolated enum KXUT04IndicatorCombinationValidationIssue: Equatable, Sendable {
    case emptyCombinationID
    case emptyName
    case invalidName(reason: String)
    case emptyIndicatorIDs
    case duplicatedIndicatorID(String)
    case invalidIndicatorID(String)
    case duplicatedCombinationID(String)
    case combinationNotFound(String)
    case invalidSortWeight(combinationID: String, weight: Int, reason: String)
    case duplicatedSortWeight(Int)
    case unknownSortWeightID(String)
}

public struct KXUT04IndicatorCombinationValidationResult: Equatable, Sendable {
    public let isValid: Bool
    public let issues: [KXUT04IndicatorCombinationValidationIssue]

    public init(issues: [KXUT04IndicatorCombinationValidationIssue] = []) {
        self.issues = issues
        self.isValid = issues.isEmpty
    }

    public static let valid = KXUT04IndicatorCombinationValidationResult()
}

public struct KXUT04IndicatorCombinationOperationResult: Equatable, Sendable {
    public let combinations: [KLIndicatorCombination]
    public let succeeded: Bool
    public let changed: Bool
    public let affectedID: String?
    public let validation: KXUT04IndicatorCombinationValidationResult
    public let message: String

    public init(
        combinations: [KLIndicatorCombination],
        succeeded: Bool,
        changed: Bool,
        affectedID: String? = nil,
        validation: KXUT04IndicatorCombinationValidationResult = .valid,
        message: String
    ) {
        self.combinations = combinations
        self.succeeded = succeeded
        self.changed = changed
        self.affectedID = affectedID
        self.validation = validation
        self.message = message
    }
}

public struct KXUT04IndicatorCombinationSortWeight: Equatable, Sendable {
    public let combinationID: String
    public let weight: Int

    public init(combinationID: String, weight: Int) {
        self.combinationID = combinationID
        self.weight = weight
    }
}

public enum KXUT04IndicatorCombinationFilterScope: Sendable {
    case all
    case id
    case name
    case indicatorID
}

public enum KXUT04IndicatorCombinationSortRule: Sendable {
    case original
    case idAscending
    case idDescending
    case nameAscending
    case nameDescending
    case indicatorCountAscending
    case indicatorCountDescending
    case weightAscending
    case weightDescending
}

// MARK: - 指标组合收藏纯服务逻辑

public enum KXUT04IndicatorCombinationFavoriteService {
    private static let maximumNameLength = 40
    private static let maximumIndicatorIDLength = 64

    public static func create(
        in combinations: [KLIndicatorCombination],
        combination: KLIndicatorCombination
    ) -> KXUT04IndicatorCombinationOperationResult {
        let normalized = normalize(combination)
        var issues = validate(normalized).issues

        if combinations.contains(where: { $0.id == normalized.id }) {
            issues.append(.duplicatedCombinationID(normalized.id))
        }

        let validation = KXUT04IndicatorCombinationValidationResult(issues: issues)
        guard validation.isValid else {
            return KXUT04IndicatorCombinationOperationResult(
                combinations: combinations,
                succeeded: false,
                changed: false,
                affectedID: normalized.id,
                validation: validation,
                message: "指标组合创建失败：校验未通过"
            )
        }

        return KXUT04IndicatorCombinationOperationResult(
            combinations: combinations + [normalized],
            succeeded: true,
            changed: true,
            affectedID: normalized.id,
            message: "指标组合已创建"
        )
    }

    public static func update(
        in combinations: [KLIndicatorCombination],
        combination: KLIndicatorCombination
    ) -> KXUT04IndicatorCombinationOperationResult {
        let normalized = normalize(combination)
        var issues = validate(normalized).issues

        guard let index = combinations.firstIndex(where: { $0.id == normalized.id }) else {
            issues.append(.combinationNotFound(normalized.id))
            let validation = KXUT04IndicatorCombinationValidationResult(issues: issues)
            return KXUT04IndicatorCombinationOperationResult(
                combinations: combinations,
                succeeded: false,
                changed: false,
                affectedID: normalized.id,
                validation: validation,
                message: "指标组合更新失败：未找到目标组合"
            )
        }

        let validation = KXUT04IndicatorCombinationValidationResult(issues: issues)
        guard validation.isValid else {
            return KXUT04IndicatorCombinationOperationResult(
                combinations: combinations,
                succeeded: false,
                changed: false,
                affectedID: normalized.id,
                validation: validation,
                message: "指标组合更新失败：校验未通过"
            )
        }

        var next = combinations
        next[index] = normalized
        return KXUT04IndicatorCombinationOperationResult(
            combinations: next,
            succeeded: true,
            changed: next != combinations,
            affectedID: normalized.id,
            message: "指标组合已更新"
        )
    }

    public static func remove(
        from combinations: [KLIndicatorCombination],
        id: String
    ) -> KXUT04IndicatorCombinationOperationResult {
        let targetID = trimmed(id)
        guard !targetID.isEmpty else {
            let validation = KXUT04IndicatorCombinationValidationResult(issues: [.emptyCombinationID])
            return KXUT04IndicatorCombinationOperationResult(
                combinations: combinations,
                succeeded: false,
                changed: false,
                affectedID: nil,
                validation: validation,
                message: "指标组合移除失败：组合 ID 为空"
            )
        }

        let next = combinations.filter { $0.id != targetID }
        let changed = next.count != combinations.count
        return KXUT04IndicatorCombinationOperationResult(
            combinations: next,
            succeeded: changed,
            changed: changed,
            affectedID: targetID,
            validation: changed ? .valid : KXUT04IndicatorCombinationValidationResult(issues: [.combinationNotFound(targetID)]),
            message: changed ? "指标组合已移除" : "指标组合移除失败：未找到目标组合"
        )
    }

    public static func contains(
        _ combinations: [KLIndicatorCombination],
        id: String
    ) -> Bool {
        let targetID = trimmed(id)
        guard !targetID.isEmpty else { return false }
        return combinations.contains { $0.id == targetID }
    }

    public static func contains(
        _ combinations: [KLIndicatorCombination],
        combination: KLIndicatorCombination
    ) -> Bool {
        contains(combinations, id: combination.id)
    }

    public static func list(
        _ combinations: [KLIndicatorCombination]
    ) -> [KLIndicatorCombination] {
        combinations
    }

    public static func filter(
        _ combinations: [KLIndicatorCombination],
        keyword: String,
        scope: KXUT04IndicatorCombinationFilterScope = .all
    ) -> [KLIndicatorCombination] {
        let token = trimmed(keyword).lowercased()
        guard !token.isEmpty else { return combinations }

        return combinations.filter { combination in
            let idMatched = combination.id.lowercased().contains(token)
            let nameMatched = combination.name.lowercased().contains(token)
            let indicatorMatched = combination.indicatorIDs.contains { $0.lowercased().contains(token) }

            switch scope {
            case .all:
                return idMatched || nameMatched || indicatorMatched
            case .id:
                return idMatched
            case .name:
                return nameMatched
            case .indicatorID:
                return indicatorMatched
            }
        }
    }

    public static func sort(
        _ combinations: [KLIndicatorCombination],
        by rule: KXUT04IndicatorCombinationSortRule = .nameAscending,
        weights: [KXUT04IndicatorCombinationSortWeight] = []
    ) -> KXUT04IndicatorCombinationOperationResult {
        let validation = validateSortWeights(weights, against: combinations)
        guard validation.isValid else {
            return KXUT04IndicatorCombinationOperationResult(
                combinations: combinations,
                succeeded: false,
                changed: false,
                validation: validation,
                message: "指标组合排序失败：排序权重校验未通过"
            )
        }

        let weightMap = Dictionary(uniqueKeysWithValues: weights.map { ($0.combinationID, $0.weight) })
        let originalIndexMap = Dictionary(uniqueKeysWithValues: combinations.enumerated().map { ($0.element.id, $0.offset) })
        let next: [KLIndicatorCombination]

        switch rule {
        case .original:
            next = combinations
        case .idAscending:
            next = combinations.sorted { compare($0.id, $1.id, ascending: true) }
        case .idDescending:
            next = combinations.sorted { compare($0.id, $1.id, ascending: false) }
        case .nameAscending:
            next = combinations.sorted { compare($0.name, $1.name, ascending: true, fallbackLeft: $0.id, fallbackRight: $1.id) }
        case .nameDescending:
            next = combinations.sorted { compare($0.name, $1.name, ascending: false, fallbackLeft: $0.id, fallbackRight: $1.id) }
        case .indicatorCountAscending:
            next = combinations.sorted {
                if $0.indicatorIDs.count != $1.indicatorIDs.count { return $0.indicatorIDs.count < $1.indicatorIDs.count }
                return compare($0.name, $1.name, ascending: true, fallbackLeft: $0.id, fallbackRight: $1.id)
            }
        case .indicatorCountDescending:
            next = combinations.sorted {
                if $0.indicatorIDs.count != $1.indicatorIDs.count { return $0.indicatorIDs.count > $1.indicatorIDs.count }
                return compare($0.name, $1.name, ascending: true, fallbackLeft: $0.id, fallbackRight: $1.id)
            }
        case .weightAscending:
            next = combinations.sorted {
                let leftWeight = weightMap[$0.id] ?? Int.max
                let rightWeight = weightMap[$1.id] ?? Int.max
                if leftWeight != rightWeight { return leftWeight < rightWeight }
                return (originalIndexMap[$0.id] ?? Int.max) < (originalIndexMap[$1.id] ?? Int.max)
            }
        case .weightDescending:
            next = combinations.sorted {
                let leftWeight = weightMap[$0.id] ?? Int.min
                let rightWeight = weightMap[$1.id] ?? Int.min
                if leftWeight != rightWeight { return leftWeight > rightWeight }
                return (originalIndexMap[$0.id] ?? Int.max) < (originalIndexMap[$1.id] ?? Int.max)
            }
        }

        return KXUT04IndicatorCombinationOperationResult(
            combinations: next,
            succeeded: true,
            changed: next != combinations,
            message: "指标组合已排序"
        )
    }

    public static func reorder(
        _ combinations: [KLIndicatorCombination],
        orderedIDs: [String]
    ) -> KXUT04IndicatorCombinationOperationResult {
        let weights = orderedIDs.enumerated().map { index, id in
            KXUT04IndicatorCombinationSortWeight(combinationID: trimmed(id), weight: index)
        }
        return reorder(combinations, weights: weights)
    }

    public static func reorder(
        _ combinations: [KLIndicatorCombination],
        weights: [KXUT04IndicatorCombinationSortWeight]
    ) -> KXUT04IndicatorCombinationOperationResult {
        sort(combinations, by: .weightAscending, weights: weights)
    }

    public static func defaultCombination() -> KLIndicatorCombination {
        KLIndicatorCombination(
            id: "default-indicator-combination",
            name: "默认指标组合",
            indicatorIDs: ["MA", "EMA", "MACD", "KDJ", "RSI", "BOLL", "VOL"]
        )
    }

    public static func validate(
        _ combination: KLIndicatorCombination
    ) -> KXUT04IndicatorCombinationValidationResult {
        var issues: [KXUT04IndicatorCombinationValidationIssue] = []
        let id = trimmed(combination.id)
        let name = trimmed(combination.name)
        let normalizedIndicatorIDs = normalizedIndicatorIDs(from: combination.indicatorIDs)

        if id.isEmpty {
            issues.append(.emptyCombinationID)
        }

        if name.isEmpty {
            issues.append(.emptyName)
        } else {
            if name.count > maximumNameLength {
                issues.append(.invalidName(reason: "名称长度不能超过 \(maximumNameLength) 个字符"))
            }
            if name.rangeOfCharacter(from: .newlines) != nil || name.rangeOfCharacter(from: .controlCharacters) != nil {
                issues.append(.invalidName(reason: "名称不能包含换行或控制字符"))
            }
        }

        if normalizedIndicatorIDs.isEmpty {
            issues.append(.emptyIndicatorIDs)
        }

        var seenIndicatorIDs = Set<String>()
        for indicatorID in combination.indicatorIDs.map(trimmed) {
            guard !indicatorID.isEmpty else {
                issues.append(.invalidIndicatorID(indicatorID))
                continue
            }
            if indicatorID.count > maximumIndicatorIDLength {
                issues.append(.invalidIndicatorID(indicatorID))
            }
            if seenIndicatorIDs.contains(indicatorID) {
                issues.append(.duplicatedIndicatorID(indicatorID))
            } else {
                seenIndicatorIDs.insert(indicatorID)
            }
        }

        return KXUT04IndicatorCombinationValidationResult(issues: issues)
    }

    public static func normalize(
        _ combination: KLIndicatorCombination
    ) -> KLIndicatorCombination {
        KLIndicatorCombination(
            id: trimmed(combination.id),
            name: trimmed(combination.name),
            indicatorIDs: normalizedIndicatorIDs(from: combination.indicatorIDs)
        )
    }

    private static func validateSortWeights(
        _ weights: [KXUT04IndicatorCombinationSortWeight],
        against combinations: [KLIndicatorCombination]
    ) -> KXUT04IndicatorCombinationValidationResult {
        var issues: [KXUT04IndicatorCombinationValidationIssue] = []
        let knownIDs = Set(combinations.map { $0.id })
        var seenIDs = Set<String>()
        var seenWeights = Set<Int>()

        for item in weights {
            let combinationID = trimmed(item.combinationID)
            if combinationID.isEmpty {
                issues.append(.emptyCombinationID)
                continue
            }
            if !knownIDs.contains(combinationID) {
                issues.append(.unknownSortWeightID(combinationID))
            }
            if seenIDs.contains(combinationID) {
                issues.append(.duplicatedCombinationID(combinationID))
            } else {
                seenIDs.insert(combinationID)
            }
            if item.weight < 0 {
                issues.append(.invalidSortWeight(combinationID: combinationID, weight: item.weight, reason: "排序权重不能为负数"))
            }
            if seenWeights.contains(item.weight) {
                issues.append(.duplicatedSortWeight(item.weight))
            } else {
                seenWeights.insert(item.weight)
            }
        }

        return KXUT04IndicatorCombinationValidationResult(issues: issues)
    }

    private static func normalizedIndicatorIDs(from indicatorIDs: [String]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()

        for rawID in indicatorIDs {
            let indicatorID = trimmed(rawID)
            guard !indicatorID.isEmpty, !seen.contains(indicatorID) else { continue }
            seen.insert(indicatorID)
            result.append(indicatorID)
        }

        return result
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func compare(
        _ left: String,
        _ right: String,
        ascending: Bool,
        fallbackLeft: String? = nil,
        fallbackRight: String? = nil
    ) -> Bool {
        let result = left.localizedStandardCompare(right)
        if result != .orderedSame {
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }

        guard let fallbackLeft, let fallbackRight else { return false }
        return fallbackLeft.localizedStandardCompare(fallbackRight) == .orderedAscending
    }
}

// MARK: - 指标组合收藏服务骨架

public enum KXUT04Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UT-04",
        fileName: "KX-UT-04_指标组合收藏服务.swift",
        layer: .favorite,
        relativePath: "收藏层/KX-UT-04_指标组合收藏服务.swift",
        duty: "指标组合收藏纯服务逻辑"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "指标组合收藏服务", passed: true, message: "已实现纯服务逻辑：创建、更新、移除、筛选、排序、重排、默认组合")
    }

    public static func placeholder() {
        // 本文件已升级为指标组合收藏纯服务逻辑。
    }
}
