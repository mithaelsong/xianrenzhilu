//
//  KX-SY-05_断线恢复.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：断线恢复、续传检查、恢复计划骨架
//  禁止事项：禁止真实网络连接
//

import Foundation


// MARK: - 断线恢复与续传骨架

public enum KXSY05Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SY-05",
        fileName: "KX-SY-05_断线恢复与续传.swift",
        layer: .sync,
        relativePath: "同步层/KX-SY-05_断线恢复与续传.swift",
        duty: "断线恢复、续传检查、恢复计划骨架"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "断线恢复与续传", passed: true, message: "已升级为纯计划生成逻辑：只产出恢复计划与续传请求描述，不执行网络、WebSocket、数据库或文件操作")
    }

    public static func placeholder() {
        // 本文件已实现纯计划生成能力；保留占位入口以满足骨架协议约定。
        // 禁止在此处加入真实请求、WebSocket、数据库连接或文件写入逻辑。
    }
}

// MARK: - 计划输入模型

public extension KXSY05Skeleton {
    enum SubscriptionState: String, Codable, Sendable, CaseIterable {
        case active
        case inactive
        case disconnected
        case unknown
    }

    struct RecoveryTarget: Codable, Equatable, Sendable {
        public let status: KLSyncStatusDescriptor
        public let gaps: [KLGapRange]
        public let subscription: KLSubscriptionDescriptor?
        public let subscriptionState: SubscriptionState
        public let retryCount: Int
        public let maxRetryCount: Int
        public let resumeFromOverride: Date?

        public init(
            status: KLSyncStatusDescriptor,
            gaps: [KLGapRange] = [],
            subscription: KLSubscriptionDescriptor? = nil,
            subscriptionState: SubscriptionState = .unknown,
            retryCount: Int = 0,
            maxRetryCount: Int = 3,
            resumeFromOverride: Date? = nil
        ) {
            self.status = status
            self.gaps = gaps
            self.subscription = subscription
            self.subscriptionState = subscriptionState
            self.retryCount = max(0, retryCount)
            self.maxRetryCount = max(0, maxRetryCount)
            self.resumeFromOverride = resumeFromOverride
        }
    }

    struct RecoveryOptions: Codable, Equatable, Sendable {
        public let defaultLookbackSeconds: TimeInterval
        public let staleToleranceSeconds: TimeInterval
        public let historicalRequestLimit: Int
        public let includeSkipItems: Bool
        public let resubscribeWhenSubscriptionMissing: Bool

        public init(
            defaultLookbackSeconds: TimeInterval = 86_400,
            staleToleranceSeconds: TimeInterval = 0,
            historicalRequestLimit: Int = 300,
            includeSkipItems: Bool = true,
            resubscribeWhenSubscriptionMissing: Bool = true
        ) {
            self.defaultLookbackSeconds = max(0, defaultLookbackSeconds)
            self.staleToleranceSeconds = max(0, staleToleranceSeconds)
            self.historicalRequestLimit = max(1, historicalRequestLimit)
            self.includeSkipItems = includeSkipItems
            self.resubscribeWhenSubscriptionMissing = resubscribeWhenSubscriptionMissing
        }
    }
}

// MARK: - 计划输出模型

public extension KXSY05Skeleton {
    enum RecoveryActionKind: String, Codable, Sendable, CaseIterable {
        case historicalBackfill
        case realtimeResubscribe
        case skipCompleted
        case failedRetry
    }

    enum ResumeRequestKind: String, Codable, Sendable, CaseIterable {
        case historicalCandles
        case realtimeSubscription
        case retryEnvelope
        case skip
    }

    struct ResumeRequestDescription: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let kind: ResumeRequestKind
        public let symbol: KXSymbol
        public let timeframe: KXTimeframe
        public let exchangeID: KLExchangeID?
        public let subscriptionID: String?
        public let startTime: Date?
        public let endTime: Date?
        public let limit: Int?
        public let retryCount: Int
        public let reason: String

        public init(
            id: String,
            kind: ResumeRequestKind,
            symbol: KXSymbol,
            timeframe: KXTimeframe,
            exchangeID: KLExchangeID? = nil,
            subscriptionID: String? = nil,
            startTime: Date? = nil,
            endTime: Date? = nil,
            limit: Int? = nil,
            retryCount: Int = 0,
            reason: String
        ) {
            self.id = id
            self.kind = kind
            self.symbol = symbol
            self.timeframe = timeframe
            self.exchangeID = exchangeID
            self.subscriptionID = subscriptionID
            self.startTime = startTime
            self.endTime = endTime
            self.limit = limit
            self.retryCount = max(0, retryCount)
            self.reason = reason
        }
    }

    struct RecoveryPlanItem: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let action: RecoveryActionKind
        public let priority: KLBackfillPriority
        public let request: ResumeRequestDescription
        public let sourceState: KLSyncState
        public let subscriptionState: SubscriptionState
        public let reason: String
        public let sortRank: Int

        public init(
            id: String,
            action: RecoveryActionKind,
            priority: KLBackfillPriority,
            request: ResumeRequestDescription,
            sourceState: KLSyncState,
            subscriptionState: SubscriptionState,
            reason: String,
            sortRank: Int
        ) {
            self.id = id
            self.action = action
            self.priority = priority
            self.request = request
            self.sourceState = sourceState
            self.subscriptionState = subscriptionState
            self.reason = reason
            self.sortRank = sortRank
        }
    }

    struct RecoveryPlanSummary: Codable, Equatable, Sendable {
        public let totalItems: Int
        public let historicalBackfillCount: Int
        public let realtimeResubscribeCount: Int
        public let skipCompletedCount: Int
        public let failedRetryCount: Int

        public init(items: [RecoveryPlanItem]) {
            self.totalItems = items.count
            self.historicalBackfillCount = items.filter { $0.action == .historicalBackfill }.count
            self.realtimeResubscribeCount = items.filter { $0.action == .realtimeResubscribe }.count
            self.skipCompletedCount = items.filter { $0.action == .skipCompleted }.count
            self.failedRetryCount = items.filter { $0.action == .failedRetry }.count
        }
    }

    struct RecoveryPlan: Codable, Equatable, Sendable {
        public let generatedAt: Date
        public let items: [RecoveryPlanItem]
        public let summary: RecoveryPlanSummary

        public init(generatedAt: Date = Date(), items: [RecoveryPlanItem]) {
            self.generatedAt = generatedAt
            self.items = items
            self.summary = RecoveryPlanSummary(items: items)
        }

        public var resumeRequests: [ResumeRequestDescription] {
            items.map { $0.request }
        }
    }
}

// MARK: - 纯计划生成逻辑

public extension KXSY05Skeleton {
    static func makeRecoveryPlan(
        targets: [RecoveryTarget],
        options: RecoveryOptions = RecoveryOptions(),
        now: Date = Date()
    ) -> RecoveryPlan {
        let items = targets.flatMap { target in
            makePlanItems(for: target, options: options, now: now)
        }
        .sorted { lhs, rhs in
            if lhs.sortRank != rhs.sortRank { return lhs.sortRank < rhs.sortRank }
            if priorityWeight(lhs.priority) != priorityWeight(rhs.priority) {
                return priorityWeight(lhs.priority) > priorityWeight(rhs.priority)
            }
            if lhs.request.symbol != rhs.request.symbol { return lhs.request.symbol < rhs.request.symbol }
            if lhs.request.timeframe.rawValue != rhs.request.timeframe.rawValue { return lhs.request.timeframe.rawValue < rhs.request.timeframe.rawValue }
            return lhs.id < rhs.id
        }

        return RecoveryPlan(generatedAt: now, items: items)
    }

    static func makeResumeRequests(
        targets: [RecoveryTarget],
        options: RecoveryOptions = RecoveryOptions(),
        now: Date = Date()
    ) -> [ResumeRequestDescription] {
        makeRecoveryPlan(targets: targets, options: options, now: now).resumeRequests
    }

    static func makeBackfillTaskDescriptions(
        from plan: RecoveryPlan,
        createdAt: Date? = nil
    ) -> [KLBackfillTaskDescriptor] {
        plan.items.compactMap { item in
            guard item.action == .historicalBackfill,
                  let startTime = item.request.startTime,
                  let endTime = item.request.endTime else {
                return nil
            }

            let gap = KLGapRange(
                symbol: item.request.symbol,
                timeframe: item.request.timeframe,
                startTime: startTime,
                endTime: endTime,
                expectedCount: item.request.limit ?? 1,
                actualCount: 0,
                reason: item.reason
            )

            return KLBackfillTaskDescriptor(
                id: item.id,
                gap: gap,
                priority: item.priority,
                createdAt: createdAt ?? plan.generatedAt,
                retryCount: item.request.retryCount
            )
        }
    }
}

// MARK: - 私有推导规则

private extension KXSY05Skeleton {
    static func makePlanItems(for target: RecoveryTarget, options: RecoveryOptions, now: Date) -> [RecoveryPlanItem] {
        var items: [RecoveryPlanItem] = []
        let status = target.status
        let symbol = status.symbol
        let timeframe = status.timeframe
        let validGaps = target.gaps.filter { gap in
            gap.symbol == symbol && gap.timeframe == timeframe && gap.startTime < gap.endTime && gap.actualCount < gap.expectedCount
        }

        if status.state == .completed,
           validGaps.isEmpty,
           target.subscriptionState == .active {
            if options.includeSkipItems {
                items.append(skipItem(target: target, reason: "同步已完成且实时订阅正常，无需恢复", index: 0))
            }
            return items
        }

        if status.state == .failed {
            items.append(failedRetryItem(target: target, now: now, allowed: target.retryCount < target.maxRetryCount))
        }

        for (index, gap) in validGaps.enumerated() {
            items.append(historicalGapItem(target: target, gap: gap, index: index))
        }

        if validGaps.isEmpty,
           status.state != .completed,
           let range = inferredResumeRange(target: target, options: options, now: now) {
            items.append(historicalRangeItem(target: target, startTime: range.start, endTime: range.end, options: options))
        }

        if shouldMakeRealtimeResubscribe(target: target, options: options) {
            items.append(realtimeResubscribeItem(target: target))
        }

        if items.isEmpty, options.includeSkipItems {
            items.append(skipItem(target: target, reason: "没有发现缺口、失败重试或重订阅需求，跳过", index: 0))
        }

        return items
    }

    static func historicalGapItem(target: RecoveryTarget, gap: KLGapRange, index: Int) -> RecoveryPlanItem {
        let requestID = stableID(prefix: "history-gap", symbol: gap.symbol, timeframe: gap.timeframe, suffix: "\(Int(gap.startTime.timeIntervalSince1970))-\(Int(gap.endTime.timeIntervalSince1970))-\(index)")
        let priority = priorityForGap(gap, state: target.status.state)
        let reason = gap.reason ?? "检测到历史 K线缺口，需要补拉缺失区间"
        let request = ResumeRequestDescription(
            id: requestID,
            kind: .historicalCandles,
            symbol: gap.symbol,
            timeframe: gap.timeframe,
            exchangeID: target.subscription?.exchangeID,
            subscriptionID: target.subscription?.id,
            startTime: gap.startTime,
            endTime: gap.endTime,
            limit: max(1, gap.expectedCount - gap.actualCount),
            retryCount: target.retryCount,
            reason: reason
        )
        return RecoveryPlanItem(
            id: requestID,
            action: .historicalBackfill,
            priority: priority,
            request: request,
            sourceState: target.status.state,
            subscriptionState: target.subscriptionState,
            reason: reason,
            sortRank: actionRank(.historicalBackfill)
        )
    }

    static func historicalRangeItem(target: RecoveryTarget, startTime: Date, endTime: Date, options: RecoveryOptions) -> RecoveryPlanItem {
        let requestID = stableID(prefix: "history-resume", symbol: target.status.symbol, timeframe: target.status.timeframe, suffix: "\(Int(startTime.timeIntervalSince1970))-\(Int(endTime.timeIntervalSince1970))")
        let reason = target.status.lastSyncedAt == nil ? "缺少最后同步时间，按默认回看窗口生成历史补拉计划" : "最后同步时间已落后，生成续传补拉计划"
        let request = ResumeRequestDescription(
            id: requestID,
            kind: .historicalCandles,
            symbol: target.status.symbol,
            timeframe: target.status.timeframe,
            exchangeID: target.subscription?.exchangeID,
            subscriptionID: target.subscription?.id,
            startTime: startTime,
            endTime: endTime,
            limit: options.historicalRequestLimit,
            retryCount: target.retryCount,
            reason: reason
        )
        return RecoveryPlanItem(
            id: requestID,
            action: .historicalBackfill,
            priority: target.status.state == .failed ? .high : .normal,
            request: request,
            sourceState: target.status.state,
            subscriptionState: target.subscriptionState,
            reason: reason,
            sortRank: actionRank(.historicalBackfill)
        )
    }

    static func realtimeResubscribeItem(target: RecoveryTarget) -> RecoveryPlanItem {
        let requestID = stableID(prefix: "realtime-resub", symbol: target.status.symbol, timeframe: target.status.timeframe, suffix: target.subscription?.id ?? "missing-subscription")
        let reason: String
        if target.subscription == nil {
            reason = "缺少实时订阅描述，需要生成重订阅请求描述"
        } else {
            reason = "实时订阅状态为 \(target.subscriptionState.rawValue)，需要重订阅"
        }
        let request = ResumeRequestDescription(
            id: requestID,
            kind: .realtimeSubscription,
            symbol: target.status.symbol,
            timeframe: target.status.timeframe,
            exchangeID: target.subscription?.exchangeID,
            subscriptionID: target.subscription?.id,
            retryCount: target.retryCount,
            reason: reason
        )
        return RecoveryPlanItem(
            id: requestID,
            action: .realtimeResubscribe,
            priority: target.subscriptionState == .disconnected ? .high : .normal,
            request: request,
            sourceState: target.status.state,
            subscriptionState: target.subscriptionState,
            reason: reason,
            sortRank: actionRank(.realtimeResubscribe)
        )
    }

    static func failedRetryItem(target: RecoveryTarget, now: Date, allowed: Bool) -> RecoveryPlanItem {
        let requestID = stableID(prefix: "failed-retry", symbol: target.status.symbol, timeframe: target.status.timeframe, suffix: "\(target.retryCount)-\(target.maxRetryCount)")
        let reason = allowed ? "同步状态失败，生成失败重试计划" : "同步状态失败，但重试次数已达到上限，仅生成人工检查描述"
        let request = ResumeRequestDescription(
            id: requestID,
            kind: .retryEnvelope,
            symbol: target.status.symbol,
            timeframe: target.status.timeframe,
            exchangeID: target.subscription?.exchangeID,
            subscriptionID: target.subscription?.id,
            startTime: target.resumeFromOverride ?? target.status.lastSyncedAt,
            endTime: now,
            retryCount: target.retryCount,
            reason: [reason, target.status.lastError].compactMap { $0 }.joined(separator: "；")
        )
        return RecoveryPlanItem(
            id: requestID,
            action: .failedRetry,
            priority: allowed ? .urgent : .low,
            request: request,
            sourceState: target.status.state,
            subscriptionState: target.subscriptionState,
            reason: request.reason,
            sortRank: actionRank(.failedRetry)
        )
    }

    static func skipItem(target: RecoveryTarget, reason: String, index: Int) -> RecoveryPlanItem {
        let requestID = stableID(prefix: "skip", symbol: target.status.symbol, timeframe: target.status.timeframe, suffix: "\(index)")
        let request = ResumeRequestDescription(
            id: requestID,
            kind: .skip,
            symbol: target.status.symbol,
            timeframe: target.status.timeframe,
            exchangeID: target.subscription?.exchangeID,
            subscriptionID: target.subscription?.id,
            retryCount: target.retryCount,
            reason: reason
        )
        return RecoveryPlanItem(
            id: requestID,
            action: .skipCompleted,
            priority: .low,
            request: request,
            sourceState: target.status.state,
            subscriptionState: target.subscriptionState,
            reason: reason,
            sortRank: actionRank(.skipCompleted)
        )
    }

    static func inferredResumeRange(target: RecoveryTarget, options: RecoveryOptions, now: Date) -> (start: Date, end: Date)? {
        let start = target.resumeFromOverride ?? target.status.lastSyncedAt ?? now.addingTimeInterval(-options.defaultLookbackSeconds)
        guard start.addingTimeInterval(options.staleToleranceSeconds) < now else { return nil }
        return (start, now)
    }

    static func shouldMakeRealtimeResubscribe(target: RecoveryTarget, options: RecoveryOptions) -> Bool {
        if target.subscription == nil { return options.resubscribeWhenSubscriptionMissing }
        return target.subscriptionState != .active
    }

    static func priorityForGap(_ gap: KLGapRange, state: KLSyncState) -> KLBackfillPriority {
        if state == .failed { return .urgent }
        let missing = max(0, gap.expectedCount - gap.actualCount)
        if missing >= 1_000 { return .urgent }
        if missing >= 100 { return .high }
        if missing > 0 { return .normal }
        return .low
    }

    static func priorityWeight(_ priority: KLBackfillPriority) -> Int {
        switch priority {
        case .urgent: return 4
        case .high: return 3
        case .normal: return 2
        case .low: return 1
        }
    }

    static func actionRank(_ action: RecoveryActionKind) -> Int {
        switch action {
        case .failedRetry: return 10
        case .historicalBackfill: return 20
        case .realtimeResubscribe: return 30
        case .skipCompleted: return 90
        }
    }

    static func stableID(prefix: String, symbol: KXSymbol, timeframe: KXTimeframe, suffix: String) -> String {
        let cleanSymbol = symbol.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: " ", with: "")
        return [prefix, cleanSymbol, timeframe.rawValue, suffix].joined(separator: "-")
    }
}
