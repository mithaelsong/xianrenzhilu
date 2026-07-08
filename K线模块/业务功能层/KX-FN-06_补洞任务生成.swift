//
//  KX-FN-06_补洞任务生成.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：把缺口区间转换为补洞任务描述
//  禁止事项：禁止直接请求 OKX、禁止真实数据库写入
//

import Foundation


// MARK: - K线补洞任务生成模型

/// KX-FN-06 本文件内的补洞任务计划描述。
///
/// 说明：KL-02 中已有 `KLBackfillTaskDescriptor`，但缺少"去重键"字段。
/// 为满足本文件职责且不修改公共类型文件，这里在单文件内补充带去重键的计划模型；
/// 该模型只描述计划，不执行网络请求、不写数据库、不做缓存。
public struct KXFN06BackfillTaskPlan: Codable, Equatable, Sendable {
    public let id: String
    public let gap: KLGapRange
    public let priority: KLBackfillPriority
    public let createdAt: Date
    public let retryCount: Int
    public let deduplicationKey: String

    public init(
        id: String,
        gap: KLGapRange,
        priority: KLBackfillPriority,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        deduplicationKey: String
    ) {
        self.id = id
        self.gap = gap
        self.priority = priority
        self.createdAt = createdAt
        self.retryCount = max(0, retryCount)
        self.deduplicationKey = deduplicationKey
    }

    /// 转换为 KL-02 已有的公共任务描述，供只需要公共类型的调用方使用。
    public var descriptor: KLBackfillTaskDescriptor {
        KLBackfillTaskDescriptor(
            id: id,
            gap: gap,
            priority: priority,
            createdAt: createdAt,
            retryCount: retryCount
        )
    }
}

/// KX-FN-06 的批量生成结果，显式暴露输入数量、去重数量、被限制截断数量，便于验收与审计。
public struct KXFN06BackfillBatchPlan: Codable, Equatable, Sendable {
    public let tasks: [KXFN06BackfillTaskPlan]
    public let inputGapCount: Int
    public let duplicateGapCount: Int
    public let droppedByLimitCount: Int
    public let maxTaskCount: Int?
    public let generatedAt: Date

    public init(
        tasks: [KXFN06BackfillTaskPlan],
        inputGapCount: Int,
        duplicateGapCount: Int,
        droppedByLimitCount: Int,
        maxTaskCount: Int?,
        generatedAt: Date = Date()
    ) {
        self.tasks = tasks
        self.inputGapCount = inputGapCount
        self.duplicateGapCount = max(0, duplicateGapCount)
        self.droppedByLimitCount = max(0, droppedByLimitCount)
        self.maxTaskCount = maxTaskCount
        self.generatedAt = generatedAt
    }

    public var descriptors: [KLBackfillTaskDescriptor] {
        tasks.map { $0.descriptor }
    }
}

// MARK: - K线补洞任务生成骨架与实现

public struct KXFN06Skeleton: KXFileSkeletonProtocol, KLBackfillTaskProvidingProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-06",
        fileName: "KX-FN-06_K线补洞任务生成.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-06_K线补洞任务生成.swift",
        duty: "把缺口区间转换为补洞任务描述"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "K线补洞任务生成", passed: true, message: "已实现缺口去重、任务ID、优先级、创建时间、重试次数、去重键、批量生成与数量限制")
    }

    public static func placeholder() {
        // 本文件已填充具体实现：只生成补洞任务描述/计划。
        // 禁止行为保持不变：不请求 OKX、不读写数据库、不绘制 UI、不实现缓存。
    }

    public init() {}

    /// 满足 KL-02 中 `KLBackfillTaskProvidingProtocol` 的公共协议签名。
    /// 该接口返回 KL-02 已有任务描述；如调用方需要去重键和批量统计，请使用 `makeBackfillBatchPlan`。
    public func makeBackfillTasks(gaps: [KLGapRange], priority: KLBackfillPriority) -> [KLBackfillTaskDescriptor] {
        Self.makeBackfillBatchPlan(gaps: gaps, defaultPriority: priority).descriptors
    }

    /// 批量生成补洞任务计划。
    ///
    /// - Parameters:
    ///   - gaps: 缺口区间列表。空数组会返回空任务计划。
    ///   - defaultPriority: 默认优先级；所有输入缺口默认使用该优先级。
    ///   - createdAt: 任务创建时间，默认当前时间；测试可传固定时间保证可复现。
    ///   - retryCount: 初始重试次数，负数会被归零。
    ///   - maxTaskCount: 最大任务数量限制；nil 表示不限制，小于等于 0 表示返回空任务。
    ///   - shouldDeduplicate: 是否按去重键去重；默认开启。
    ///   - shouldSortByPriority: 是否按优先级和时间排序；默认开启。
    public static func makeBackfillBatchPlan(
        gaps: [KLGapRange],
        defaultPriority: KLBackfillPriority = .normal,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        maxTaskCount: Int? = nil,
        shouldDeduplicate: Bool = true,
        shouldSortByPriority: Bool = true
    ) -> KXFN06BackfillBatchPlan {
        let prioritizedGaps = gaps.map { (gap: $0, priority: defaultPriority) }
        return makeBackfillBatchPlan(
            prioritizedGaps: prioritizedGaps,
            createdAt: createdAt,
            retryCount: retryCount,
            maxTaskCount: maxTaskCount,
            shouldDeduplicate: shouldDeduplicate,
            shouldSortByPriority: shouldSortByPriority
        )
    }

    /// 批量生成补洞任务计划，支持每个缺口携带独立优先级，用于"优先级排序"验收。
    public static func makeBackfillBatchPlan(
        prioritizedGaps: [(gap: KLGapRange, priority: KLBackfillPriority)],
        createdAt: Date = Date(),
        retryCount: Int = 0,
        maxTaskCount: Int? = nil,
        shouldDeduplicate: Bool = true,
        shouldSortByPriority: Bool = true
    ) -> KXFN06BackfillBatchPlan {
        guard !prioritizedGaps.isEmpty else {
            return KXFN06BackfillBatchPlan(
                tasks: [],
                inputGapCount: 0,
                duplicateGapCount: 0,
                droppedByLimitCount: 0,
                maxTaskCount: normalizedMaxTaskCount(maxTaskCount),
                generatedAt: createdAt
            )
        }

        let normalizedLimit = normalizedMaxTaskCount(maxTaskCount)
        if normalizedLimit == 0 {
            return KXFN06BackfillBatchPlan(
                tasks: [],
                inputGapCount: prioritizedGaps.count,
                duplicateGapCount: 0,
                droppedByLimitCount: prioritizedGaps.count,
                maxTaskCount: normalizedLimit,
                generatedAt: createdAt
            )
        }

        var seenKeys = Set<String>()
        var duplicateCount = 0
        var candidates: [KXFN06BackfillTaskPlan] = []

        for item in prioritizedGaps where isValidGap(item.gap) {
            let key = deduplicationKey(for: item.gap)
            if shouldDeduplicate {
                let inserted = seenKeys.insert(key).inserted
                if !inserted {
                    duplicateCount += 1
                    continue
                }
            }

            candidates.append(
                KXFN06BackfillTaskPlan(
                    id: taskID(forDeduplicationKey: key),
                    gap: item.gap,
                    priority: item.priority,
                    createdAt: createdAt,
                    retryCount: retryCount,
                    deduplicationKey: key
                )
            )
        }

        let sorted = shouldSortByPriority ? sortTasks(candidates) : candidates
        let limitedTasks: [KXFN06BackfillTaskPlan]
        let droppedByLimitCount: Int
        if let limit = normalizedLimit, sorted.count > limit {
            limitedTasks = Array(sorted.prefix(limit))
            droppedByLimitCount = sorted.count - limit
        } else {
            limitedTasks = sorted
            droppedByLimitCount = 0
        }

        return KXFN06BackfillBatchPlan(
            tasks: limitedTasks,
            inputGapCount: prioritizedGaps.count,
            duplicateGapCount: duplicateCount,
            droppedByLimitCount: droppedByLimitCount,
            maxTaskCount: normalizedLimit,
            generatedAt: createdAt
        )
    }

    /// 生成单个缺口的去重键。
    /// 格式稳定，不依赖 Swift 随机化 Hash：`symbol|timeframe|startMs|endMs`。
    public static func deduplicationKey(for gap: KLGapRange) -> String {
        [
            gap.symbol,
            gap.timeframe.rawValue,
            millisecondsString(gap.startTime),
            millisecondsString(gap.endTime)
        ].joined(separator: "|")
    }

    /// 根据去重键生成稳定任务 ID。
    public static func taskID(for gap: KLGapRange) -> String {
        taskID(forDeduplicationKey: deduplicationKey(for: gap))
    }

    /// 校验缺口是否适合生成补洞任务。
    /// 只做计划层过滤：时间区间必须正向，预期数量必须大于实际数量。
    public static func isValidGap(_ gap: KLGapRange) -> Bool {
        gap.startTime <= gap.endTime && gap.expectedCount > gap.actualCount
    }

    /// 缺失 K线数量，负数按 0 处理。
    public static func missingCandleCount(for gap: KLGapRange) -> Int {
        max(0, gap.expectedCount - gap.actualCount)
    }

    private static func sortTasks(_ tasks: [KXFN06BackfillTaskPlan]) -> [KXFN06BackfillTaskPlan] {
        tasks.sorted { lhs, rhs in
            let lhsRank = priorityRank(lhs.priority)
            let rhsRank = priorityRank(rhs.priority)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.gap.startTime != rhs.gap.startTime { return lhs.gap.startTime < rhs.gap.startTime }
            if lhs.gap.endTime != rhs.gap.endTime { return lhs.gap.endTime < rhs.gap.endTime }
            if lhs.gap.symbol != rhs.gap.symbol { return lhs.gap.symbol < rhs.gap.symbol }
            return lhs.gap.timeframe.rawValue < rhs.gap.timeframe.rawValue
        }
    }

    private static func priorityRank(_ priority: KLBackfillPriority) -> Int {
        switch priority {
        case .urgent: return 0
        case .high: return 1
        case .normal: return 2
        case .low: return 3
        }
    }

    private static func normalizedMaxTaskCount(_ maxTaskCount: Int?) -> Int? {
        guard let maxTaskCount else { return nil }
        return max(0, maxTaskCount)
    }

    private static func taskID(forDeduplicationKey key: String) -> String {
        "kl-backfill-\(fnv1a64Hex(key))"
    }

    private static func millisecondsString(_ date: Date) -> String {
        String(Int64((date.timeIntervalSince1970 * 1000).rounded()))
    }

    /// FNV-1a 64 位哈希：用于生成稳定、轻量、无外部依赖的任务 ID 后缀。
    private static func fnv1a64Hex(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x00000100000001B3
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(format: "%016llx", hash)
    }
}
