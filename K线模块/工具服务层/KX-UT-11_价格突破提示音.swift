//
//  KX-UT-11_价格突破提示音.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：价格突破提示音事件生成逻辑
//  禁止事项：禁止播放实现、禁止网络请求、禁止数据库访问、禁止UI
//

import Foundation


// MARK: - 价格突破方向

public enum KLBreakoutDirection: String, Codable, Sendable, CaseIterable {
    /// 向上突破（价格上穿阻力位）
    case upward
    /// 向下突破（价格下穿支撑位）
    case downward
}

// MARK: - 价格突破类型

public enum KLBreakoutType: String, Codable, Sendable, CaseIterable {
    /// 区间突破（价格突破一段时间内的横盘区间）
    case rangeBreakout
    /// 趋势线突破（价格突破趋势线）
    case trendlineBreakout
    /// 关键价位突破（前高/前低/整数关口等）
    case keyLevelBreakout
    /// 均线突破（价格上穿/下穿某均线）
    case maBreakout
    /// 布林带突破（价格触及或突破布林带上/下轨）
    case bollingerBreakout
    /// 斐波那契突破（突破斐波那契关键位）
    case fibonacciBreakout
}

// MARK: - 价格突破严重级别

public enum KLBreakoutSeverity: String, Codable, Sendable, CaseIterable {
    /// 一般（正常突破，常规关注）
    case normal
    /// 重要（高量能配合/关键位置/大周期）
    case important
    /// 紧急（极端行情、假突破反转、重大事件驱动）
    case urgent

    /// 对应的 KLMarkerSeverity 名称，用于统一展示
    public var markerSeverityString: String {
        switch self {
        case .normal:   return "info"
        case .important: return "warning"
        case .urgent:   return "critical"
        }
    }
}

// MARK: - 价格突破输入

public struct KLBreakoutInput: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let direction: KLBreakoutDirection
    public let triggerPrice: KXDecimal
    public let currentPrice: KXDecimal
    public let breakoutType: KLBreakoutType
    /// 距离触发价的百分比（正数）
    public let deviationPercent: Double
    /// 量能倍率（当前量是均量的倍数，nil 表示未知）
    public let volumeMultiplier: Double?
    /// 具体触发时间
    public let occurredAt: Date

    public init(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        direction: KLBreakoutDirection,
        triggerPrice: KXDecimal,
        currentPrice: KXDecimal,
        breakoutType: KLBreakoutType,
        deviationPercent: Double,
        volumeMultiplier: Double? = nil,
        occurredAt: Date = Date()
    ) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.direction = direction
        self.triggerPrice = triggerPrice
        self.currentPrice = currentPrice
        self.breakoutType = breakoutType
        self.deviationPercent = deviationPercent
        self.volumeMultiplier = volumeMultiplier
        self.occurredAt = occurredAt
    }
}

// MARK: - 价格突破提示音事件生成器

public enum KLBreakoutAlertGenerator {

    // MARK: 严重性判断

    /// 根据突破输入判断严重级别
    public static func severity(for input: KLBreakoutInput) -> KLBreakoutSeverity {
        // 大周期突破 -> 重要
        let isMajorTimeframe: Bool = {
            switch input.timeframe {
            case .fourHours, .sixHours, .twelveHours, .oneDay, .oneWeek, .oneMonth:
                return true
            default:
                return false
            }
        }()

        // 偏差超过 3% 或大周期突破 -> 重要
        if isMajorTimeframe || input.deviationPercent >= 3.0 {
            return .important
        }

        // 偏差超过 5% 或量能超过 5 倍 -> 紧急
        if input.deviationPercent >= 5.0 || (input.volumeMultiplier ?? 0) >= 5.0 {
            return .urgent
        }

        return .normal
    }

    // MARK: 标题与文案生成

    /// 根据突破输入生成提示标题
    public static func title(for input: KLBreakoutInput) -> String {
        let directionText: String
        switch input.direction {
        case .upward:
            directionText = "向上突破"
        case .downward:
            directionText = "向下突破"
        }

        let typeText = typeDisplayName(input.breakoutType)
        return "\(input.symbol) \(directionText)｜\(typeText)"
    }

    /// 根据突破输入生成详情文案
    public static func message(for input: KLBreakoutInput) -> String {
        let directionText: String
        switch input.direction {
        case .upward:
            directionText = "向上突破"
        case .downward:
            directionText = "向下突破"
        }

        let typeText = typeDisplayName(input.breakoutType)
        var parts: [String] = [
            "\(input.symbol) \(directionText)「\(typeText)」",
            "触发价: \(input.triggerPrice) | 现价: \(input.currentPrice)"
        ]

        if input.deviationPercent > 0 {
            parts.append("偏离: \(String(format: "%.2f", input.deviationPercent))%")
        }
        if let vm = input.volumeMultiplier, vm >= 1.5 {
            parts.append("量比: \(String(format: "%.1f", vm))x")
        }
        parts.append("周期: \(input.timeframe.rawValue)")

        return parts.joined(separator: "\n")
    }

    // MARK: 去重键生成

    /// 生成去重键，相同 symbol + direction + breakoutType 的去重范围为 30 秒
    public static func dedupKey(for input: KLBreakoutInput) -> String {
        "price_breakout:\(input.symbol):\(input.timeframe.rawValue):\(input.direction.rawValue):\(input.breakoutType.rawValue):\(String(describing: input.triggerPrice))"
    }

    // MARK: 突破类型显示名

    public static func typeDisplayName(_ type: KLBreakoutType) -> String {
        switch type {
        case .rangeBreakout:      return "区间突破"
        case .trendlineBreakout:  return "趋势线突破"
        case .keyLevelBreakout:   return "关键价位突破"
        case .maBreakout:         return "均线突破"
        case .bollingerBreakout:  return "布林带突破"
        case .fibonacciBreakout:  return "斐波那契突破"
        }
    }

    // MARK: 开关过滤

    /// 检查该突破是否应当被过滤（开关关闭时忽略），由调用方传入匹配的规则
    /// - 规则为空（未设置该突破类型的规则）→ 默认通过
    /// - 规则存在且 enabled == false → 过滤
    public static func shouldFilter(input: KLBreakoutInput, rules: [KLAlertRuleDescriptor]) -> Bool {
        guard !rules.isEmpty else { return false }

        let matchedRules = rules.filter { rule in
            guard rule.kind == .priceBreakout else { return false }
            if rule.symbol != input.symbol { return false }
            // 可选的时间跨度匹配
            if let ruleTimeframe = rule.timeframe, ruleTimeframe != input.timeframe { return false }
            // 方向匹配
            switch rule.direction {
            case .any:
                return true
            case .above, .crossUp:
                return input.direction == .upward
            case .below, .crossDown:
                return input.direction == .downward
            }
        }

        // 有关联规则但全部关闭 → 过滤
        if matchedRules.isEmpty { return false }
        return matchedRules.allSatisfy { !$0.enabled }
    }

    /// 从匹配的规则中取第一个启用的 sound，否则返回 nil
    public static func sound(from rules: [KLAlertRuleDescriptor], input: KLBreakoutInput) -> KLSoundDescriptor? {
        for rule in rules {
            guard rule.kind == .priceBreakout && rule.enabled else { continue }
            if rule.symbol != input.symbol { continue }
            if let ruleTimeframe = rule.timeframe, ruleTimeframe != input.timeframe { continue }
            if let sound = rule.sound { return sound }
        }
        return nil
    }

    // MARK: 核心生成方法

    /// 根据突破输入和规则列表生成一个 KLAlertEventDescriptor
    /// - Parameters:
    ///   - input: 价格突破输入
    ///   - rules: 当前有效的规则列表（用于开关过滤 + sound 选取）
    /// - Returns: 事件描述符，若被过滤则返回 nil
    public static func generateEvent(from input: KLBreakoutInput, rules: [KLAlertRuleDescriptor] = []) -> KLAlertEventDescriptor? {
        // 1. 开关过滤
        guard !shouldFilter(input: input, rules: rules) else { return nil }

        // 2. 生成标题与文案
        let titleText = title(for: input)
        let messageText = message(for: input)

        // 3. 选择声音
        let soundDescriptor = sound(from: rules, input: input)

        // 4. 构建事件 ID（全局唯一）
        let eventID = dedupKey(for: input)

        // 5. 构建描述符
        return KLAlertEventDescriptor(
            id: eventID,
            ruleID: nil, // 调用方可自行赋值
            symbol: input.symbol,
            timeframe: input.timeframe,
            kind: .priceBreakout,
            title: titleText,
            message: messageText,
            occurredAt: input.occurredAt,
            deliveryState: .pending,
            sound: soundDescriptor
        )
    }

    /// 批量生成：为多个突破输入生成事件，自动过滤开关关闭的项
    public static func generateEvents(from inputs: [KLBreakoutInput], rules: [KLAlertRuleDescriptor] = []) -> [KLAlertEventDescriptor] {
        inputs.compactMap { generateEvent(from: $0, rules: rules) }
    }
}


// MARK: - KXFileSkeletonProtocol

public enum KXUT11Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UT-11", fileName: "KX-UT-11_价格突破提示音.swift", layer: .utility,
        relativePath: "工具服务层/KX-UT-11_价格突破提示音.swift", duty: "价格突破事件的提示音生成"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("价格突破提示音骨架校验通过")
        return KXHealthCheckItem(name: "价格突破提示音", passed: true, message: "已实现价格突破提示音规则")
    }
}
