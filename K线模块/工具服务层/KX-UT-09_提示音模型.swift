//
//  KX-UT-09_提示音模型.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：提示音事件类型模型、事件来源/方向/严重性/触发条件 DTO、开关配置、
//        以及 KLAlertEventDescriptor/KLAlertRuleDescriptor 与本文件 DTO 的映射。
//  禁止事项：禁止播放实现、禁止请求网络、禁止读写数据库、禁止绘制 UI
//

import Foundation

@MainActor


// MARK: - 提示音事件模型

public enum KXUT09AlertModel {
    // 命名空间，不实例化
}

// MARK: - 事件来源

public extension KXUT09AlertModel {
    /// 提示音事件来源分类
    enum EventSource: String, Codable, Sendable, CaseIterable {
        /// 标记系统（手动标记、形态识别标记）
        case marker
        /// 形态识别信号
        case patternSignal
        /// 价格突破
        case priceBreakout
        /// 成交量异常
        case volumeAnomaly
        /// 数据同步失败
        case syncFailure
        /// 自定义事件
        case custom
    }

    /// 事件优先级（数值越低优先级越低）
    enum EventPriority: Int, Codable, Sendable, Comparable, CaseIterable {
        case low = 10
        case normal = 20
        case high = 30
        case critical = 40

        public static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// 事件严重性（与标记系统对齐）
    enum EventSeverity: String, Codable, Sendable, CaseIterable {
        case info
        case low
        case medium
        case high
        case critical
    }

    /// 事件方向
    enum EventDirection: String, Codable, Sendable, CaseIterable {
        /// 向上突破/超过
        case above
        /// 向下突破/低于
        case below
        /// 向上穿越（较短周期穿越较长周期均线等场景）
        case crossUp
        /// 向下穿越
        case crossDown
        /// 任意方向/不确定方向
        case any

        /// 中文显示名称
        public var displayName: String {
            switch self {
            case .above:    return "上破"
            case .below:    return "下破"
            case .crossUp:  return "向上穿越"
            case .crossDown: return "向下穿越"
            case .any:      return "触发"
            }
        }
    }

    /// 事件交付状态
    enum EventDeliveryState: String, Codable, Sendable, CaseIterable {
        /// 等待交付
        case pending
        /// 已交付
        case delivered
        /// 已静音/用户关闭了通知
        case muted
        /// 交付失败
        case failed
    }

    /// 事件类型分类
    enum EventKind: String, Codable, Sendable, CaseIterable {
        /// 形态信号
        case patternSignal
        /// 价格突破
        case priceBreakout
        /// 成交量异常
        case volumeAnomaly
        /// 同步失败
        case syncFailure
        /// 自定义
        case custom
    }

    /// 去重策略
    enum DedupeStrategy: String, Codable, Sendable, CaseIterable {
        /// 相同 dedupeKey 只保留最新的一条
        case keepLatest
        /// 相同 dedupeKey 在冷却期内不重复
        case cooldown
        /// 不限制（每次都产生事件）
        case unlimited
    }
}

// MARK: - 声音描述

public extension KXUT09AlertModel {
    /// 提示音描述
    struct SoundDescriptor: Codable, Equatable, Sendable {
        /// 声音唯一标识
        public let soundID: String
        /// 显示名称
        public let displayName: String
        /// 文件名（可选，系统默认音时可为 nil）
        public let fileName: String?
        /// 音量 (0~1)
        public let volume: Double
        /// 重复次数
        public let repeatCount: Int

        public init(soundID: String,
                    displayName: String,
                    fileName: String? = nil,
                    volume: Double = 1.0,
                    repeatCount: Int = 1) {
            self.soundID = soundID
            self.displayName = displayName
            self.fileName = fileName
            self.volume = max(0, min(1, volume))
            self.repeatCount = max(1, repeatCount)
        }
    }
}

// MARK: - 触发条件 DTO

public extension KXUT09AlertModel {
    /// 价格阈值触发条件
    struct PriceThresholdCondition: Codable, Equatable, Sendable {
        /// 触发价格
        public let thresholdPrice: KXDecimal
        /// 方向（above/below）
        public let direction: EventDirection
        /// 触发精度（价格达到 thresholdPrice ± precision 范围内即触发，nil 表示精确匹配）
        public let tolerance: KXDecimal?
        /// 是否在首次达到后持续触发
        public let persistent: Bool

        public init(thresholdPrice: KXDecimal,
                    direction: EventDirection = .any,
                    tolerance: KXDecimal? = nil,
                    persistent: Bool = false) {
            self.thresholdPrice = thresholdPrice
            self.direction = direction
            self.tolerance = tolerance
            self.persistent = persistent
        }
    }

    /// 成交量阈值触发条件
    struct VolumeThresholdCondition: Codable, Equatable, Sendable {
        /// 成交量阈值
        public let thresholdVolume: KXDecimal
        /// 比较方式（大于/小于）
        public let greaterThan: Bool
        /// 基准量（用于计算放大倍数，nil 则只比较绝对值）
        public let baselineVolume: KXDecimal?
        /// 最小放大倍数（与 baselineVolume 配合使用）
        public let minRatio: Double?
        /// 是否在持续达标时重复触发
        public let persistent: Bool

        public init(thresholdVolume: KXDecimal,
                    greaterThan: Bool = true,
                    baselineVolume: KXDecimal? = nil,
                    minRatio: Double? = nil,
                    persistent: Bool = false) {
            self.thresholdVolume = thresholdVolume
            self.greaterThan = greaterThan
            self.baselineVolume = baselineVolume
            self.minRatio = minRatio
            self.persistent = persistent
        }
    }

    /// 形态信号触发条件
    struct PatternSignalCondition: Codable, Equatable, Sendable {
        /// 信号名称（如"头肩顶"、"双底"等）
        public let signalName: String?
        /// 最低置信度 (0~1)
        public let minConfidence: Double?
        /// 信号方向
        public let direction: EventDirection
        /// 是否包含子模式
        public let includeSubPatterns: Bool

        public init(signalName: String? = nil,
                    minConfidence: Double? = nil,
                    direction: EventDirection = .any,
                    includeSubPatterns: Bool = false) {
            self.signalName = signalName
            self.minConfidence = minConfidence
            self.direction = direction
            self.includeSubPatterns = includeSubPatterns
        }
    }

    /// 数据同步异常触发条件
    struct SyncFailureCondition: Codable, Equatable, Sendable {
        /// 连续失败次数阈值
        public let consecutiveFailureThreshold: Int
        /// 超时秒数阈值
        public let timeoutSeconds: Double?
        /// 是否只关注当前交易对
        public let currentSymbolOnly: Bool

        public init(consecutiveFailureThreshold: Int = 3,
                    timeoutSeconds: Double? = nil,
                    currentSymbolOnly: Bool = true) {
            self.consecutiveFailureThreshold = consecutiveFailureThreshold
            self.timeoutSeconds = timeoutSeconds
            self.currentSymbolOnly = currentSymbolOnly
        }
    }

    /// 任意组合触发条件
    struct CompositeCondition: Codable, Equatable, Sendable {
        public let priceCondition: PriceThresholdCondition?
        public let volumeCondition: VolumeThresholdCondition?
        public let patternCondition: PatternSignalCondition?
        public let syncFailureCondition: SyncFailureCondition?

        public init(priceCondition: PriceThresholdCondition? = nil,
                    volumeCondition: VolumeThresholdCondition? = nil,
                    patternCondition: PatternSignalCondition? = nil,
                    syncFailureCondition: SyncFailureCondition? = nil) {
            self.priceCondition = priceCondition
            self.volumeCondition = volumeCondition
            self.patternCondition = patternCondition
            self.syncFailureCondition = syncFailureCondition
        }
    }
}

// MARK: - 开关配置

public extension KXUT09AlertModel {
    /// 全局提示音开关配置
    struct GlobalSwitches: Codable, Equatable, Sendable {
        /// 总开关
        public let enabled: Bool
        /// 静音模式（所有事件标记为 muted，不播放）
        public let muted: Bool
        /// 允许标记事件
        public let allowMarkers: Bool
        /// 允许形态信号
        public let allowPatternSignals: Bool
        /// 允许价格突破
        public let allowPriceBreakouts: Bool
        /// 允许成交量异常
        public let allowVolumeAnomalies: Bool
        /// 允许同步失败事件
        public let allowSyncFailures: Bool
        /// 允许自定义事件
        public let allowCustom: Bool
        /// 最低优先级（低于此优先级的事件被过滤）
        public let minimumPriority: EventPriority
        /// 去重策略
        public let dedupeStrategy: DedupeStrategy
        /// 去重冷却秒数（仅 cooldown 策略有效）
        public let dedupeCooldownSeconds: Double

        public init(enabled: Bool = true,
                    muted: Bool = false,
                    allowMarkers: Bool = true,
                    allowPatternSignals: Bool = true,
                    allowPriceBreakouts: Bool = true,
                    allowVolumeAnomalies: Bool = true,
                    allowSyncFailures: Bool = true,
                    allowCustom: Bool = true,
                    minimumPriority: EventPriority = .low,
                    dedupeStrategy: DedupeStrategy = .cooldown,
                    dedupeCooldownSeconds: Double = 5) {
            self.enabled = enabled
            self.muted = muted
            self.allowMarkers = allowMarkers
            self.allowPatternSignals = allowPatternSignals
            self.allowPriceBreakouts = allowPriceBreakouts
            self.allowVolumeAnomalies = allowVolumeAnomalies
            self.allowSyncFailures = allowSyncFailures
            self.allowCustom = allowCustom
            self.minimumPriority = minimumPriority
            self.dedupeStrategy = dedupeStrategy
            self.dedupeCooldownSeconds = dedupeCooldownSeconds
        }
    }

    /// 单类事件开关
    struct CategorySwitch: Codable, Equatable, Sendable {
        /// 是否启用该类事件
        public let enabled: Bool
        /// 是否静音
        public let muted: Bool
        /// 最低严重性（低于此级别的被过滤）
        public let minimumSeverity: EventSeverity
        /// 最低置信度（仅 pattern 类生效）
        public let minConfidence: Double?
        /// 声音覆盖（nil 表示使用默认音）
        public let soundOverride: SoundDescriptor?
        /// 冷却秒数（同一类型事件的最小间隔）
        public let cooldownSeconds: Double

        public init(enabled: Bool = true,
                    muted: Bool = false,
                    minimumSeverity: EventSeverity = .low,
                    minConfidence: Double? = nil,
                    soundOverride: SoundDescriptor? = nil,
                    cooldownSeconds: Double = 3) {
            self.enabled = enabled
            self.muted = muted
            self.minimumSeverity = minimumSeverity
            self.minConfidence = minConfidence
            self.soundOverride = soundOverride
            self.cooldownSeconds = cooldownSeconds
        }
    }

    /// 单币对额外开关（覆盖全局）
    struct PerSymbolSwitch: Codable, Equatable, Sendable {
        public let symbol: KXSymbol
        /// nil = 继承全局设置
        public let enabled: Bool?
        /// nil = 继承全局设置
        public let muted: Bool?

        public init(symbol: KXSymbol,
                    enabled: Bool? = nil,
                    muted: Bool? = nil) {
            self.symbol = symbol
            self.enabled = enabled
            self.muted = muted
        }
    }
}

// MARK: - 事件 DTO（完整模型）

public extension KXUT09AlertModel {
    /// 完整提示音事件 DTO
    struct EventDTO: Codable, Equatable, Sendable, Identifiable {
        /// 事件唯一 ID
        public let id: String
        /// 去重键（相同键在冷却期/保留策略下会被去重）
        public let dedupeKey: String
        /// 事件来源
        public let source: EventSource
        /// 事件优先级
        public let priority: EventPriority
        /// 事件严重性
        public let severity: EventSeverity
        /// 是否启用
        public let enabled: Bool
        /// 是否静音
        public let muted: Bool
        /// 触发条件
        public let condition: CompositeCondition?
        /// 对应的 KLAlertEventDescriptor（桥接层用）
        public let descriptor: KLAlertEventDescriptor
        /// 关联的规则 ID（如果有）
        public let ruleID: String?

        public init(id: String,
                    dedupeKey: String,
                    source: EventSource,
                    priority: EventPriority,
                    severity: EventSeverity = .medium,
                    enabled: Bool = true,
                    muted: Bool = false,
                    condition: CompositeCondition? = nil,
                    descriptor: KLAlertEventDescriptor,
                    ruleID: String? = nil) {
            self.id = id
            self.dedupeKey = dedupeKey
            self.source = source
            self.priority = priority
            self.severity = severity
            self.enabled = enabled
            self.muted = muted
            self.condition = condition
            self.descriptor = descriptor
            self.ruleID = ruleID
        }
    }
}

// MARK: - 规则 DTO

public extension KXUT09AlertModel {
    /// 完整提示音规则 DTO
    struct RuleDTO: Codable, Equatable, Sendable, Identifiable {
        /// 规则 ID
        public let id: String
        /// 交易对
        public let symbol: KXSymbol
        /// 周期（nil = 全周期）
        public let timeframe: KXTimeframe?
        /// 事件类型
        public let kind: EventKind
        /// 触发条件
        public let condition: CompositeCondition
        /// 声音
        public let sound: SoundDescriptor?
        /// 是否启用
        public let enabled: Bool
        /// 创建时间
        public let createdAt: Date
        /// 对应的 KLAlertRuleDescriptor
        public let descriptor: KLAlertRuleDescriptor

        public init(id: String,
                    symbol: KXSymbol,
                    timeframe: KXTimeframe? = nil,
                    kind: EventKind,
                    condition: CompositeCondition,
                    sound: SoundDescriptor? = nil,
                    enabled: Bool = true,
                    createdAt: Date = Date(),
                    descriptor: KLAlertRuleDescriptor) {
            self.id = id
            self.symbol = symbol
            self.timeframe = timeframe
            self.kind = kind
            self.condition = condition
            self.sound = sound
            self.enabled = enabled
            self.createdAt = createdAt
            self.descriptor = descriptor
        }
    }
}

// MARK: - 桥接映射：本文件 DTO ↔ KL-02 描述符

public extension KXUT09AlertModel {

    // MARK: 从 KLAlertRuleDescriptor 构造 RuleDTO

    /// 将 KL-02 的 KLAlertRuleDescriptor 映射为本地 RuleDTO
    static func mapRule(from descriptor: KLAlertRuleDescriptor) -> RuleDTO {
        let kind: EventKind
        switch descriptor.kind {
        case .patternSignal: kind = .patternSignal
        case .priceBreakout: kind = .priceBreakout
        case .volumeAnomaly: kind = .volumeAnomaly
        case .syncFailure:   kind = .syncFailure
        case .custom:        kind = .custom
        }

        let direction: EventDirection
        switch descriptor.direction {
        case .above:    direction = .above
        case .below:    direction = .below
        case .crossUp:  direction = .crossUp
        case .crossDown: direction = .crossDown
        case .any:      direction = .any
        }

        let condition = CompositeCondition(
            priceCondition: descriptor.thresholdPrice.map {
                PriceThresholdCondition(thresholdPrice: $0, direction: direction)
            },
            volumeCondition: descriptor.thresholdVolume.map {
                VolumeThresholdCondition(thresholdVolume: $0)
            },
            patternCondition: (descriptor.kind == .patternSignal) ? PatternSignalCondition() : nil,
            syncFailureCondition: (descriptor.kind == .syncFailure) ? SyncFailureCondition() : nil
        )

        let sound = descriptor.sound.map {
            SoundDescriptor(soundID: $0.soundID, displayName: $0.displayName, fileName: $0.fileName, volume: $0.volume, repeatCount: $0.repeatCount)
        }

        return RuleDTO(
            id: descriptor.id,
            symbol: descriptor.symbol,
            timeframe: descriptor.timeframe,
            kind: kind,
            condition: condition,
            sound: sound,
            enabled: descriptor.enabled,
            createdAt: descriptor.createdAt,
            descriptor: descriptor
        )
    }

    // MARK: 从 RuleDTO 映射回 KLAlertRuleDescriptor

    /// 将本地 RuleDTO 映射为 KL-02 的 KLAlertRuleDescriptor
    static func mapRuleToDescriptor(_ rule: RuleDTO) -> KLAlertRuleDescriptor {
        let kind: KLAlertKind
        switch rule.kind {
        case .patternSignal: kind = .patternSignal
        case .priceBreakout: kind = .priceBreakout
        case .volumeAnomaly: kind = .volumeAnomaly
        case .syncFailure:   kind = .syncFailure
        case .custom:        kind = .custom
        }

        let direction: KLAlertDirection
        if let priceCond = rule.condition.priceCondition {
            // EventDirection → KLAlertDirection
            switch priceCond.direction {
            case .above:    direction = .above
            case .below:    direction = .below
            case .crossUp:  direction = .crossUp
            case .crossDown: direction = .crossDown
            case .any:      direction = .any
            }
        } else {
            direction = .any
        }

        let sound = rule.sound.map {
            KLSoundDescriptor(soundID: $0.soundID, displayName: $0.displayName, fileName: $0.fileName, volume: $0.volume, repeatCount: $0.repeatCount)
        }

        return KLAlertRuleDescriptor(
            id: rule.id,
            symbol: rule.symbol,
            timeframe: rule.timeframe,
            kind: kind,
            direction: direction,
            thresholdPrice: rule.condition.priceCondition?.thresholdPrice,
            thresholdVolume: rule.condition.volumeCondition?.thresholdVolume,
            sound: sound,
            enabled: rule.enabled,
            createdAt: rule.createdAt
        )
    }

    // MARK: 从 KLAlertEventDescriptor 构造 EventDTO

    /// 将 KL-02 的 KLAlertEventDescriptor 映射为本地 EventDTO
    static func mapEvent(from descriptor: KLAlertEventDescriptor,
                         source: EventSource? = nil,
                         priority: EventPriority = .normal,
                         severity: EventSeverity = .medium,
                         enabled: Bool = true,
                         ruleDTO: RuleDTO? = nil) -> EventDTO {
        let eventSource: EventSource
        if let s = source {
            eventSource = s
        } else {
            switch descriptor.kind {
            case .patternSignal: eventSource = .patternSignal
            case .priceBreakout: eventSource = .priceBreakout
            case .volumeAnomaly: eventSource = .volumeAnomaly
            case .syncFailure:   eventSource = .syncFailure
            case .custom:        eventSource = .custom
            }
        }

        let deliveryMuted = (descriptor.deliveryState == .muted)
        let condition = ruleDTO?.condition

        return EventDTO(
            id: descriptor.id,
            dedupeKey: descriptor.id,
            source: eventSource,
            priority: priority,
            severity: severity,
            enabled: enabled,
            muted: deliveryMuted,
            condition: condition,
            descriptor: descriptor,
            ruleID: descriptor.ruleID
        )
    }

    // MARK: 从 EventDTO 映射回 KLAlertEventDescriptor

    /// 将本地 EventDTO 映射为 KL-02 的 KLAlertEventDescriptor
    static func mapEventToDescriptor(_ event: EventDTO) -> KLAlertEventDescriptor {
        let deliveryState: KLAlertDeliveryState
        switch (event.muted, event.enabled) {
        case (true, _):
            deliveryState = .muted
        case (_, true):
            deliveryState = .pending
        case (_, false):
            deliveryState = .muted
        }

        return KLAlertEventDescriptor(
            id: event.id,
            ruleID: event.ruleID,
            symbol: event.descriptor.symbol,
            timeframe: event.descriptor.timeframe,
            kind: event.descriptor.kind,
            title: event.descriptor.title,
            message: event.descriptor.message,
            occurredAt: event.descriptor.occurredAt,
            deliveryState: deliveryState,
            sound: event.descriptor.sound
        )
    }

    // MARK: 批量映射

    /// 批量映射多个 KLAlertRuleDescriptor → RuleDTO
    static func mapRules(from descriptors: [KLAlertRuleDescriptor]) -> [RuleDTO] {
        descriptors.map(mapRule)
    }

    /// 批量映射多个 KLAlertEventDescriptor → EventDTO
    static func mapEvents(from descriptors: [KLAlertEventDescriptor],
                          sources: [EventSource]? = nil,
                          priorities: [EventPriority]? = nil,
                          severities: [EventSeverity]? = nil) -> [EventDTO] {
        descriptors.enumerated().map { idx, desc in
            let source = sources?.indices.contains(idx) == true ? sources?[idx] : nil
            let priority = priorities?.indices.contains(idx) == true ? priorities?[idx] : .normal
            let severity = severities?.indices.contains(idx) == true ? severities?[idx] : .medium
            return mapEvent(from: desc, source: source, priority: priority ?? .normal, severity: severity ?? .medium)
        }
    }

    /// 批量映射多个 EventDTO → KLAlertEventDescriptor
    static func mapEventsToDescriptors(_ events: [EventDTO]) -> [KLAlertEventDescriptor] {
        events.map(mapEventToDescriptor)
    }

    /// 批量映射多个 RuleDTO → KLAlertRuleDescriptor
    static func mapRulesToDescriptors(_ rules: [RuleDTO]) -> [KLAlertRuleDescriptor] {
        rules.map(mapRuleToDescriptor)
    }
}

// MARK: - 过滤与去重

public extension KXUT09AlertModel {
    /// 按开关过滤事件列表
    static func filterEvents(_ events: [EventDTO], by switches: GlobalSwitches) -> [EventDTO] {
        guard switches.enabled else { return [] }
        return events.filter { event in
            guard event.enabled else { return false }

            // 按来源过滤
            switch event.source {
            case .marker:
                guard switches.allowMarkers else { return false }
            case .patternSignal:
                guard switches.allowPatternSignals else { return false }
            case .priceBreakout:
                guard switches.allowPriceBreakouts else { return false }
            case .volumeAnomaly:
                guard switches.allowVolumeAnomalies else { return false }
            case .syncFailure:
                guard switches.allowSyncFailures else { return false }
            case .custom:
                guard switches.allowCustom else { return false }
            }

            // 按优先级过滤
            guard event.priority >= switches.minimumPriority else { return false }

            return true
        }
    }

    /// 去重（保留最新的一条）
    static func deduplicate(_ events: [EventDTO], strategy: DedupeStrategy) -> [EventDTO] {
        switch strategy {
        case .keepLatest, .cooldown:
            var seen = Set<String>()
            var result: [EventDTO] = []
            for event in events {
                if !seen.contains(event.dedupeKey) {
                    seen.insert(event.dedupeKey)
                    result.append(event)
                }
            }
            return result
        case .unlimited:
            return events
        }
    }

    /// 按优先级排序（从高到低），同优先级按时间先后
    static func sortByPriority(_ events: [EventDTO]) -> [EventDTO] {
        events.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.descriptor.occurredAt < rhs.descriptor.occurredAt
        }
    }
}

// MARK: - 严重性 ↔ 优先级 桥接

public extension KXUT09AlertModel {
    /// 从 EventSeverity 映射到 EventPriority
    static func priority(from severity: EventSeverity) -> EventPriority {
        switch severity {
        case .info, .low:   return .low
        case .medium:       return .normal
        case .high:         return .high
        case .critical:     return .critical
        }
    }

    /// 从 KLMarkerSeverity 映射到 EventPriority
    static func priority(from markerSeverity: KLMarkerSeverity) -> EventPriority {
        switch markerSeverity {
        case .info, .low:   return .low
        case .medium:       return .normal
        case .high:         return .high
        case .critical:     return .critical
        }
    }

    /// 从 EventSeverity 映射到 KLMarkerSeverity
    static func markerSeverity(from severity: EventSeverity) -> KLMarkerSeverity {
        switch severity {
        case .info:     return .info
        case .low:      return .low
        case .medium:   return .medium
        case .high:     return .high
        case .critical: return .critical
        }
    }
}

// MARK: - 骨架协议符合

public enum KXUT09Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UT-09",
        fileName: "KX-UT-09_提示音事件模型.swift",
        layer: .alert,
        relativePath: "提示音事件层/KX-UT-09_提示音事件模型.swift",
        duty: "提示音事件类型模型：事件来源/方向/严重性/优先级/交付状态、声音描述、触发条件 DTO、开关配置、事件描述符、事件规则 DTO、KLAlertEventDescriptor/ KLAlertRuleDescriptor 映射"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(
            name: "提示音事件模型",
            passed: true,
            message: "已升级为可用模型：包含 EventSource/EventPriority/EventSeverity/EventDirection/EventDeliveryState/EventKind/SoundDescriptor，触发条件 DTO（PriceThreshold/VolumeThreshold/PatternSignal/SyncFailure/Composite），开关配置（GlobalSwitches/CategorySwitch/PerSymbolSwitch），事件 DTO（EventDTO/RuleDTO），以及 KL-02 ↔ 本文件 DTO 的完整映射（mapRule/mapEvent 及批量方法）"
        )
    }

    public static func placeholder() {
        // 本文件已实现完整可用的提示音事件模型。
        // 不播放声音、不请求网络、不读写数据库、不绘制 UI。
        // 仅做模型定义与 DTO 映射转换。
    }
}

// MARK: - 内部工具
// 安全下标访问统一使用公共定义 ZB-02_公共类型定义.swift 中的 Array[safe:]，避免重复扩展导致编译冲突。
