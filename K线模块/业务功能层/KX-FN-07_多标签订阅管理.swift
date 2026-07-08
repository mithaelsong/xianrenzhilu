//
//  KX-FN-07_多标签订阅管理.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：维护每个标签的币对、周期、订阅状态、缓存状态
//  禁止事项：禁止 UI 标签绘制、禁止直接网络请求
//

import Foundation


// MARK: - 多标签订阅状态管理模型

/// KX-FN-07 文件内标签标识。
///
/// 说明：KL-02 当前没有专用 TabID 类型；为遵守"不改 KL-02"的要求，本文件内定义轻量别名。
public typealias KXFN07TabID = String

/// 标签订阅状态。
///
/// 本状态只描述"应如何订阅"，不会真实启动/关闭 WebSocket。
public enum KXFN07SubscriptionState: String, Codable, Equatable, Sendable, CaseIterable {
    /// 已打开且应保持实时订阅。
    case active
    /// 标签被切到后台，但为了"切换标签不断流"仍应保持订阅。
    case keptAlive
    /// 标签已关闭或释放，不应继续订阅。
    case released
}

/// 标签缓存状态。
///
/// 只记录缓存可用性摘要，不读写数据库、不访问真实缓存存储。
public enum KXFN07CacheState: String, Codable, Equatable, Sendable, CaseIterable {
    /// 尚未确认缓存状态。
    case unknown
    /// 没有可用缓存。
    case empty
    /// 有部分缓存，可作为预热/补洞依据。
    case partial
    /// 缓存可用。
    case ready
    /// 缓存过期，需要调用方自行安排刷新。
    case stale
}

/// 订阅计划动作。
///
/// 调用方可根据这些动作决定是否向网络层发起真实操作；本文件只生成计划。
public enum KXFN07SubscriptionPlanAction: String, Codable, Equatable, Sendable, CaseIterable {
    /// 需要新增订阅。
    case subscribe
    /// 订阅继续保持，不做网络变更。
    case keep
    /// 需要释放订阅。
    case unsubscribe
}

/// 单个标签状态。
public struct KXFN07TabSubscriptionState: Codable, Equatable, Sendable, Identifiable {
    public let id: KXFN07TabID
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let subscriptionState: KXFN07SubscriptionState
    public let cacheState: KXFN07CacheState
    public let isPinned: Bool
    public let lastActiveAt: Date
    public let openedAt: Date

    public init(
        id: KXFN07TabID,
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        subscriptionState: KXFN07SubscriptionState = .active,
        cacheState: KXFN07CacheState = .unknown,
        isPinned: Bool = false,
        lastActiveAt: Date = Date(),
        openedAt: Date = Date()
    ) {
        self.id = id
        self.symbol = symbol
        self.timeframe = timeframe
        self.subscriptionState = subscriptionState
        self.cacheState = cacheState
        self.isPinned = isPinned
        self.lastActiveAt = lastActiveAt
        self.openedAt = openedAt
    }

    public var subscriptionDescriptor: KLSubscriptionDescriptor {
        KLSubscriptionDescriptor(
            id: KXFN07Skeleton.subscriptionID(symbol: symbol, timeframe: timeframe),
            symbol: symbol,
            timeframe: timeframe,
            exchangeID: KXFN07Skeleton.defaultExchangeID,
            createdAt: openedAt
        )
    }

    public var cacheKey: KLCacheKey {
        KLCacheKey(namespace: .candles, symbol: symbol, timeframe: timeframe, variant: "tab:\(id)")
    }
}

/// 单条订阅计划。
public struct KXFN07SubscriptionPlanItem: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let action: KXFN07SubscriptionPlanAction
    public let tabID: KXFN07TabID
    public let descriptor: KLSubscriptionDescriptor
    public let reason: String
    public let plannedAt: Date

    public init(
        id: String,
        action: KXFN07SubscriptionPlanAction,
        tabID: KXFN07TabID,
        descriptor: KLSubscriptionDescriptor,
        reason: String,
        plannedAt: Date = Date()
    ) {
        self.id = id
        self.action = action
        self.tabID = tabID
        self.descriptor = descriptor
        self.reason = reason
        self.plannedAt = plannedAt
    }
}

/// 标签状态变更结果。
public struct KXFN07TabMutationResult: Codable, Equatable, Sendable {
    public let tabs: [KXFN07TabSubscriptionState]
    public let activeTabID: KXFN07TabID?
    public let plans: [KXFN07SubscriptionPlanItem]
    public let warnings: [String]
    public let generatedAt: Date

    public init(
        tabs: [KXFN07TabSubscriptionState],
        activeTabID: KXFN07TabID?,
        plans: [KXFN07SubscriptionPlanItem],
        warnings: [String] = [],
        generatedAt: Date = Date()
    ) {
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.plans = plans
        self.warnings = warnings
        self.generatedAt = generatedAt
    }
}

/// 可恢复状态摘要。
public struct KXFN07RestorableStateSummary: Codable, Equatable, Sendable {
    public let activeTabID: KXFN07TabID?
    public let tabCount: Int
    public let pinnedTabCount: Int
    public let subscribedTabCount: Int
    public let releasedTabCount: Int
    public let tabs: [KXFN07TabSubscriptionState]
    public let subscriptions: [KLSubscriptionDescriptor]
    public let cacheKeys: [KLCacheKey]
    public let generatedAt: Date

    public init(
        activeTabID: KXFN07TabID?,
        tabs: [KXFN07TabSubscriptionState],
        generatedAt: Date = Date()
    ) {
        self.activeTabID = activeTabID
        self.tabCount = tabs.count
        self.pinnedTabCount = tabs.filter { $0.isPinned }.count
        self.subscribedTabCount = tabs.filter { $0.subscriptionState != .released }.count
        self.releasedTabCount = tabs.filter { $0.subscriptionState == .released }.count
        self.tabs = tabs
        self.subscriptions = tabs
            .filter { $0.subscriptionState != .released }
            .map { $0.subscriptionDescriptor }
        self.cacheKeys = tabs.map { $0.cacheKey }
        self.generatedAt = generatedAt
    }
}

// MARK: - 多标签订阅状态管理实现

public enum KXFN07Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let defaultExchangeID: KLExchangeID = "OKX"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-07",
        fileName: "KX-FN-07_多标签订阅状态管理.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-07_多标签订阅状态管理.swift",
        duty: "维护每个标签的币对、周期、订阅状态、缓存状态"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "多标签订阅状态管理", passed: true, message: "已实现打开标签、切换不断流、关闭释放、固定保护、缓存状态与可恢复摘要的纯状态计划")
    }

    public static func placeholder() {
        // 本文件已填充具体实现：只维护标签状态并生成订阅计划。
        // 禁止行为保持不变：不真实启动 WebSocket、不请求 OKX、不写数据库、不绘制 UI。
    }

    /// 打开或复用标签。
    ///
    /// - Parameters:
    ///   - tabs: 当前标签状态列表。
    ///   - activeTabID: 当前活跃标签。
    ///   - id: 新标签 ID；如与现有标签重复，则复用并更新该标签交易对/周期。
    ///   - symbol: 交易对。
    ///   - timeframe: 周期。
    ///   - cacheState: 初始缓存状态。
    ///   - isPinned: 是否固定。
    ///   - now: 变更时间。
    /// - Returns: 新状态与订阅计划。原活跃标签会变为 keptAlive，以保证切换标签不断流。
    public static func openTab(
        tabs: [KXFN07TabSubscriptionState],
        activeTabID: KXFN07TabID?,
        id: KXFN07TabID,
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        cacheState: KXFN07CacheState = .unknown,
        isPinned: Bool = false,
        now: Date = Date()
    ) -> KXFN07TabMutationResult {
        var normalizedTabs = tabs
        var warnings: [String] = []
        let targetID = normalizedTabID(id: id, symbol: symbol, timeframe: timeframe)

        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("标签 ID 为空，已按交易对和周期生成稳定 ID：\(targetID)")
        }

        var didReuse = false
        normalizedTabs = normalizedTabs.map { tab in
            if tab.id == targetID {
                didReuse = true
                return KXFN07TabSubscriptionState(
                    id: tab.id,
                    symbol: symbol,
                    timeframe: timeframe,
                    subscriptionState: .active,
                    cacheState: cacheState,
                    isPinned: isPinned || tab.isPinned,
                    lastActiveAt: now,
                    openedAt: tab.openedAt
                )
            }

            return keepAliveIfNeeded(tab, now: now)
        }

        if !didReuse {
            let newTab = KXFN07TabSubscriptionState(
                id: targetID,
                symbol: symbol,
                timeframe: timeframe,
                subscriptionState: .active,
                cacheState: cacheState,
                isPinned: isPinned,
                lastActiveAt: now,
                openedAt: now
            )
            normalizedTabs.append(newTab)
        }

        let currentTab = normalizedTabs.first { $0.id == targetID }
        let action: KXFN07SubscriptionPlanAction = didReuse ? .keep : .subscribe
        let reason = didReuse ? "复用已有标签，保持订阅并更新为活跃" : "打开新标签，需要建立订阅计划"
        let plans = currentTab.map { [planItem(action: action, tab: $0, reason: reason, plannedAt: now)] } ?? []

        return KXFN07TabMutationResult(
            tabs: sortTabs(normalizedTabs),
            activeTabID: targetID,
            plans: plans,
            warnings: warnings,
            generatedAt: now
        )
    }

    /// 切换活跃标签。
    ///
    /// 旧活跃标签不会释放订阅，而是转为 keptAlive；目标标签转为 active。
    public static func switchTab(
        tabs: [KXFN07TabSubscriptionState],
        activeTabID: KXFN07TabID?,
        to targetTabID: KXFN07TabID,
        now: Date = Date()
    ) -> KXFN07TabMutationResult {
        guard tabs.contains(where: { $0.id == targetTabID }) else {
            return KXFN07TabMutationResult(
                tabs: sortTabs(tabs),
                activeTabID: activeTabID,
                plans: [],
                warnings: ["目标标签不存在，未执行切换：\(targetTabID)"],
                generatedAt: now
            )
        }

        let updatedTabs = tabs.map { tab -> KXFN07TabSubscriptionState in
            if tab.id == targetTabID {
                return replacing(tab: tab, subscriptionState: .active, lastActiveAt: now)
            }
            return keepAliveIfNeeded(tab, now: now)
        }

        let plans = updatedTabs
            .filter { $0.id == targetTabID || $0.id == activeTabID }
            .map { planItem(action: .keep, tab: $0, reason: "切换标签不断流，订阅保持", plannedAt: now) }

        return KXFN07TabMutationResult(
            tabs: sortTabs(updatedTabs),
            activeTabID: targetTabID,
            plans: plans,
            generatedAt: now
        )
    }

    /// 关闭标签。
    ///
    /// 固定标签默认受保护，不会关闭；传入 `forceClosePinned: true` 才会释放固定标签订阅。
    public static func closeTab(
        tabs: [KXFN07TabSubscriptionState],
        activeTabID: KXFN07TabID?,
        closingTabID: KXFN07TabID,
        forceClosePinned: Bool = false,
        now: Date = Date()
    ) -> KXFN07TabMutationResult {
        guard let closingTab = tabs.first(where: { $0.id == closingTabID }) else {
            return KXFN07TabMutationResult(
                tabs: sortTabs(tabs),
                activeTabID: activeTabID,
                plans: [],
                warnings: ["目标标签不存在，未执行关闭：\(closingTabID)"],
                generatedAt: now
            )
        }

        if closingTab.isPinned && !forceClosePinned {
            return KXFN07TabMutationResult(
                tabs: sortTabs(tabs),
                activeTabID: activeTabID,
                plans: [planItem(action: .keep, tab: closingTab, reason: "固定标签受保护，关闭请求被忽略", plannedAt: now)],
                warnings: ["固定标签受保护，未关闭：\(closingTabID)"],
                generatedAt: now
            )
        }

        let remainingTabs = tabs.filter { $0.id != closingTabID }
        let nextActiveTabID: KXFN07TabID?
        if activeTabID == closingTabID {
            nextActiveTabID = chooseNextActiveTab(from: remainingTabs)
        } else {
            nextActiveTabID = activeTabID
        }

        let updatedRemainingTabs = remainingTabs.map { tab -> KXFN07TabSubscriptionState in
            if tab.id == nextActiveTabID {
                return replacing(tab: tab, subscriptionState: .active, lastActiveAt: now)
            }
            return keepAliveIfNeeded(tab, now: now)
        }

        var plans = [
            planItem(
                action: .unsubscribe,
                tab: replacing(tab: closingTab, subscriptionState: .released, lastActiveAt: now),
                reason: "关闭标签，释放该标签订阅计划",
                plannedAt: now
            )
        ]

        if let nextActive = updatedRemainingTabs.first(where: { $0.id == nextActiveTabID }) {
            plans.append(planItem(action: .keep, tab: nextActive, reason: "关闭当前标签后恢复下一个活跃标签订阅", plannedAt: now))
        }

        let result = KXFN07TabMutationResult(
            tabs: sortTabs(updatedRemainingTabs),
            activeTabID: nextActiveTabID,
            plans: plans,
            generatedAt: now
        )

        // 释放关闭标签的内存缓存
        DispatchQueue.global(qos: .utility).async {
            KLDefaultStartupPipeline.shared.cleanupSymbol(symbol: closingTab.symbol)
        }

        return result
    }

    /// 设置或取消固定标签。
    public static func setPinned(
        tabs: [KXFN07TabSubscriptionState],
        activeTabID: KXFN07TabID?,
        tabID: KXFN07TabID,
        isPinned: Bool,
        now: Date = Date()
    ) -> KXFN07TabMutationResult {
        guard tabs.contains(where: { $0.id == tabID }) else {
            return KXFN07TabMutationResult(
                tabs: sortTabs(tabs),
                activeTabID: activeTabID,
                plans: [],
                warnings: ["目标标签不存在，未修改固定状态：\(tabID)"],
                generatedAt: now
            )
        }

        let updatedTabs = tabs.map { tab -> KXFN07TabSubscriptionState in
            guard tab.id == tabID else { return tab }
            return KXFN07TabSubscriptionState(
                id: tab.id,
                symbol: tab.symbol,
                timeframe: tab.timeframe,
                subscriptionState: tab.subscriptionState,
                cacheState: tab.cacheState,
                isPinned: isPinned,
                lastActiveAt: now,
                openedAt: tab.openedAt
            )
        }

        let changedTab = updatedTabs.first { $0.id == tabID }
        return KXFN07TabMutationResult(
            tabs: sortTabs(updatedTabs),
            activeTabID: activeTabID,
            plans: changedTab.map { [planItem(action: .keep, tab: $0, reason: isPinned ? "标签已固定，订阅保持" : "标签已取消固定，订阅保持", plannedAt: now)] } ?? [],
            generatedAt: now
        )
    }

    /// 更新指定标签的缓存状态。
    public static func updateCacheState(
        tabs: [KXFN07TabSubscriptionState],
        activeTabID: KXFN07TabID?,
        tabID: KXFN07TabID,
        cacheState: KXFN07CacheState,
        now: Date = Date()
    ) -> KXFN07TabMutationResult {
        guard tabs.contains(where: { $0.id == tabID }) else {
            return KXFN07TabMutationResult(
                tabs: sortTabs(tabs),
                activeTabID: activeTabID,
                plans: [],
                warnings: ["目标标签不存在，未更新缓存状态：\(tabID)"],
                generatedAt: now
            )
        }

        let updatedTabs = tabs.map { tab -> KXFN07TabSubscriptionState in
            guard tab.id == tabID else { return tab }
            return KXFN07TabSubscriptionState(
                id: tab.id,
                symbol: tab.symbol,
                timeframe: tab.timeframe,
                subscriptionState: tab.subscriptionState,
                cacheState: cacheState,
                isPinned: tab.isPinned,
                lastActiveAt: now,
                openedAt: tab.openedAt
            )
        }

        return KXFN07TabMutationResult(
            tabs: sortTabs(updatedTabs),
            activeTabID: activeTabID,
            plans: [],
            generatedAt: now
        )
    }

    /// 根据当前状态生成完整订阅计划。
    public static func makeSubscriptionPlan(
        tabs: [KXFN07TabSubscriptionState],
        activeTabID: KXFN07TabID?,
        now: Date = Date()
    ) -> [KXFN07SubscriptionPlanItem] {
        sortTabs(tabs).map { tab in
            let action: KXFN07SubscriptionPlanAction = tab.subscriptionState == .released ? .unsubscribe : .keep
            let reason: String
            if tab.subscriptionState == .released {
                reason = "标签已释放，应取消订阅"
            } else if tab.id == activeTabID {
                reason = "活跃标签，订阅保持"
            } else {
                reason = "后台标签不断流，订阅保持"
            }
            return planItem(action: action, tab: tab, reason: reason, plannedAt: now)
        }
    }

    /// 生成恢复状态摘要。
    public static func makeRestorableStateSummary(
        tabs: [KXFN07TabSubscriptionState],
        activeTabID: KXFN07TabID?,
        now: Date = Date()
    ) -> KXFN07RestorableStateSummary {
        let sorted = sortTabs(tabs)
        let validActiveID = sorted.contains(where: { $0.id == activeTabID }) ? activeTabID : chooseNextActiveTab(from: sorted)
        return KXFN07RestorableStateSummary(activeTabID: validActiveID, tabs: sorted, generatedAt: now)
    }

    /// 生成稳定订阅 ID，同一交易对/周期复用同一订阅标识，便于调用方合并连接。
    public static func subscriptionID(symbol: KXSymbol, timeframe: KXTimeframe) -> String {
        "sub:\(normalizedSymbol(symbol)):\(timeframe.rawValue)"
    }

    // MARK: - 内部纯函数

    private static func normalizedTabID(id: KXFN07TabID, symbol: KXSymbol, timeframe: KXTimeframe) -> KXFN07TabID {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedID.isEmpty { return trimmedID }
        return "tab:\(normalizedSymbol(symbol)):\(timeframe.rawValue)"
    }

    private static func normalizedSymbol(_ symbol: KXSymbol) -> KXSymbol {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func replacing(
        tab: KXFN07TabSubscriptionState,
        subscriptionState: KXFN07SubscriptionState,
        lastActiveAt: Date
    ) -> KXFN07TabSubscriptionState {
        KXFN07TabSubscriptionState(
            id: tab.id,
            symbol: tab.symbol,
            timeframe: tab.timeframe,
            subscriptionState: subscriptionState,
            cacheState: tab.cacheState,
            isPinned: tab.isPinned,
            lastActiveAt: lastActiveAt,
            openedAt: tab.openedAt
        )
    }

    private static func keepAliveIfNeeded(_ tab: KXFN07TabSubscriptionState, now: Date) -> KXFN07TabSubscriptionState {
        guard tab.subscriptionState != .released else { return tab }
        return replacing(tab: tab, subscriptionState: .keptAlive, lastActiveAt: tab.lastActiveAt)
    }

    private static func chooseNextActiveTab(from tabs: [KXFN07TabSubscriptionState]) -> KXFN07TabID? {
        sortTabs(tabs)
            .filter { $0.subscriptionState != .released }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                if lhs.lastActiveAt != rhs.lastActiveAt { return lhs.lastActiveAt > rhs.lastActiveAt }
                return lhs.id < rhs.id
            }
            .first?.id
    }

    private static func sortTabs(_ tabs: [KXFN07TabSubscriptionState]) -> [KXFN07TabSubscriptionState] {
        tabs.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            if lhs.openedAt != rhs.openedAt { return lhs.openedAt < rhs.openedAt }
            return lhs.id < rhs.id
        }
    }

    private static func planItem(
        action: KXFN07SubscriptionPlanAction,
        tab: KXFN07TabSubscriptionState,
        reason: String,
        plannedAt: Date
    ) -> KXFN07SubscriptionPlanItem {
        let descriptor = tab.subscriptionDescriptor
        return KXFN07SubscriptionPlanItem(
            id: "\(action.rawValue):\(tab.id):\(descriptor.id)",
            action: action,
            tabID: tab.id,
            descriptor: descriptor,
            reason: reason,
            plannedAt: plannedAt
        )
    }
}
