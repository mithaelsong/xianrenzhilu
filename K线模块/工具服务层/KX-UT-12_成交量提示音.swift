//
//  KX-UT-12_成交量提示音.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：成交量异常提示音事件生成骨架 → 可用生成逻辑
//  禁止事项：禁止播放声音、禁止请求网络、禁止读写数据库、禁止画 UI；只生成事件描述
//

import Foundation


// MARK: - 成交量异常输入模型

/// 成交量异常检测输入
public struct KLVolumeAnomalyInput: Codable, Equatable, Sendable {
    /// 交易对标识
    public let symbol: KXSymbol
    /// 周期
    public let timeframe: KXTimeframe
    /// 当前成交量
    public let currentVolume: KXDecimal
    /// 平均成交量（对比基准）
    public let averageVolume: KXDecimal
    /// 当前量 / 平均量 倍率（例：3.0 表示 3 倍）
    public let ratio: Double
    /// 偏离程度（标准差倍数或百分比，正 = 放量，负 = 缩量）
    public let deviation: Double
    /// 严重性等级
    public let severity: KLMarkerSeverity
    /// 事件发生时间
    public let occurredAt: Date

    public init(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        currentVolume: KXDecimal,
        averageVolume: KXDecimal,
        ratio: Double,
        deviation: Double,
        severity: KLMarkerSeverity,
        occurredAt: Date = Date()
    ) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.currentVolume = currentVolume
        self.averageVolume = averageVolume
        self.ratio = ratio
        self.deviation = deviation
        self.severity = severity
        self.occurredAt = occurredAt
    }
}

// MARK: - 成交量异常方向

/// 成交量异常方向：放量 / 缩量
public enum KLVolumeAnomalyDirection: String, Codable, Sendable, CaseIterable {
    case surge       // 放量
    case shrink      // 缩量
}

// MARK: - 成交量异常类型

/// 成交量异常细分类型
public enum KLVolumeAnomalyKind: String, Codable, Sendable, CaseIterable {
    /// 温和放量（1.5x ~ 2x）
    case mildSurge
    /// 明显放量（2x ~ 3x）
    case significantSurge
    /// 巨量放量（3x ~ 5x）
    case massiveSurge
    /// 天量放量（5x 以上）
    case extremeSurge
    /// 略微缩量（0.5x ~ 0.8x）
    case slightShrink
    /// 明显缩量（0.2x ~ 0.5x）
    case severeShrink
    /// 极度缩量（0.2x 以下）
    case extremeShrink
    /// 成交量突变（相对前一周期变化超 3 倍且方向不明）
    case abruptChange
}

// MARK: - 成交量异常事件工厂

public enum KLVolumeAnomalyEventFactory {

    // MARK: - 公开入口

    /// 根据成交量异常输入生成事件描述
    /// - Parameters:
    ///   - input: 成交量异常输入
    ///   - ruleID: 关联的规则 ID（可选）
    ///   - enabledRules: 启用的规则 ID 集合，nil 表示全部放行
    ///   - muteKinds: 禁用的异常种类集合，空集合表示全部放行
    /// - Returns: 事件描述，若被开关过滤则返回 nil
    public static func makeEvent(
        input: KLVolumeAnomalyInput,
        ruleID: String? = nil,
        enabledRules: Set<String>? = nil,
        muteKinds: Set<KLVolumeAnomalyKind> = []
    ) -> KLAlertEventDescriptor? {
        // 1. 判断异常方向
        let direction = resolveDirection(deviation: input.deviation)

        // 2. 解析异常类型
        let kind = resolveKind(direction: direction, ratio: input.ratio, deviation: input.deviation)

        // 3. 开关过滤：检查禁用种类
        guard !muteKinds.contains(kind) else { return nil }

        // 4. 开关过滤：检查规则是否启用
        if let enabledRules, let rid = ruleID {
            guard enabledRules.contains(rid) else { return nil }
        }

        // 5. 生成文案
        let title = makeTitle(symbol: input.symbol, direction: direction, kind: kind)
        let message = makeMessage(input: input, direction: direction, kind: kind)

        // 6. 去重键
        let dedupKey = makeDedupKey(symbol: input.symbol, timeframe: input.timeframe, kind: kind)

        // 7. 构造事件描述符
        return KLAlertEventDescriptor(
            id: dedupKey,
            ruleID: ruleID,
            symbol: input.symbol,
            timeframe: input.timeframe,
            kind: .volumeAnomaly,
            title: title,
            message: message,
            occurredAt: input.occurredAt,
            deliveryState: .pending,
            sound: nil
        )
    }

    /// 批量生成事件（适用场景：一个 candle 匹配多个规则时）
    public static func makeEvents(
        input: KLVolumeAnomalyInput,
        rules: [KLAlertRuleDescriptor],
        muteKinds: Set<KLVolumeAnomalyKind> = []
    ) -> [KLAlertEventDescriptor] {
        let enabledRuleIDs = Set(rules.filter(\.enabled).map(\.id))
        return rules.compactMap { rule in
            makeEvent(
                input: input,
                ruleID: rule.id,
                enabledRules: enabledRuleIDs,
                muteKinds: muteKinds
            )
        }
    }

    // MARK: - 方向解析

    /// 根据偏离值判断放量/缩量
    public static func resolveDirection(deviation: Double) -> KLVolumeAnomalyDirection {
        deviation >= 0 ? .surge : .shrink
    }

    // MARK: - 异常类型解析

    /// 根据方向和倍率解析异常细分类型
    public static func resolveKind(
        direction: KLVolumeAnomalyDirection,
        ratio: Double,
        deviation: Double
    ) -> KLVolumeAnomalyKind {
        switch direction {
        case .surge:
            if ratio >= 5.0 { return .extremeSurge }
            if ratio >= 3.0 { return .massiveSurge }
            if ratio >= 2.0 { return .significantSurge }
            if ratio >= 1.5 { return .mildSurge }
            // ratio >= 1.0 不触发（不到放量阈值）
            // ratio < 1.0 但 deviation >= 0 → 异常为涨，量没涨 → abrupt
            return .abruptChange
        case .shrink:
            if ratio <= 0.2 { return .extremeShrink }
            if ratio <= 0.5 { return .severeShrink }
            if ratio <= 0.8 { return .slightShrink }
            // ratio > 0.8 但 deviation < 0 → 轻微缩量但不到阈值
            // 或者 ratio 反而 >= 1 → 异常方向与倍率矛盾 → abrupt
            if ratio >= 1.0 { return .abruptChange }
            return .slightShrink
        }
    }

    // MARK: - 去重键

    /// 生成去重键（symbol + timeframe + 异常类型）
    /// 同一交易对同一周期的同一类型异常只保留最新一条
    public static func makeDedupKey(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        kind: KLVolumeAnomalyKind
    ) -> String {
        "vol_anomaly_\(symbol)_\(timeframe.rawValue)_\(kind.rawValue)"
    }

    // MARK: - 严重性映射

    /// 将成交量异常严重性映射为 MarkerSeverity
    public static func mapSeverity(kind: KLVolumeAnomalyKind) -> KLMarkerSeverity {
        switch kind {
        case .extremeSurge, .extremeShrink:
            return .critical
        case .massiveSurge, .severeShrink, .abruptChange:
            return .high
        case .significantSurge:
            return .medium
        case .mildSurge, .slightShrink:
            return .low
        }
    }

    // MARK: - 文案生成

    /// 生成事件标题
    public static func makeTitle(
        symbol: KXSymbol,
        direction: KLVolumeAnomalyDirection,
        kind: KLVolumeAnomalyKind
    ) -> String {
        let dirLabel: String = {
            switch direction {
            case .surge:  return "放量"
            case .shrink: return "缩量"
            }
        }()
        let kindLabel: String = {
            switch kind {
            case .mildSurge:        return "温和"
            case .significantSurge: return "明显"
            case .massiveSurge:     return "巨量"
            case .extremeSurge:     return "天量"
            case .slightShrink:    return "略微"
            case .severeShrink:    return "明显"
            case .extremeShrink:   return "极度"
            case .abruptChange:    return "突变"
            }
        }()
        return "\(symbol) \(kindLabel)\(dirLabel)"
    }

    /// 生成事件详情
    public static func makeMessage(
        input: KLVolumeAnomalyInput,
        direction: KLVolumeAnomalyDirection,
        kind: KLVolumeAnomalyKind
    ) -> String {
        let dirLabel: String = {
            switch direction {
            case .surge:  return "放量"
            case .shrink: return "缩量"
            }
        }()
        let directionSign = input.deviation >= 0 ? "↑" : "↓"

        return [
            "\(input.symbol) \(input.timeframe.rawValue)",
            "当前量: \(fmt(input.currentVolume))",
            "平均量: \(fmt(input.averageVolume))",
            "倍率: \(String(format: "%.2f", input.ratio))x",
            "偏离: \(String(format: "%.2f", abs(input.deviation)))σ \(directionSign)",
            "类型: \(dirLabel)",
            "严重性: \(input.severity.rawValue)"
        ].joined(separator: " | ")
    }

    // MARK: - 辅助

    private static func fmt(_ value: KXDecimal) -> String {
        // 简化数字格式化：取整或保留两位小数
        let d = (value as NSDecimalNumber).doubleValue
        if d >= 1_000_000_000 {
            return String(format: "%.2fB", d / 1_000_000_000)
        } else if d >= 1_000_000 {
            return String(format: "%.2fM", d / 1_000_000)
        } else if d >= 1_000 {
            return String(format: "%.2fK", d / 1_000)
        } else {
            return String(format: "%.2f", d)
        }
    }
}

// MARK: - 骨架兼容

public enum KXUT12Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UT-12",
        fileName: "KX-UT-12_成交量异常提示音.swift",
        layer: .alert,
        relativePath: "提示音事件层/KX-UT-12_成交量异常提示音.swift",
        duty: "成交量异常提示音事件生成骨架"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(
            name: "成交量异常提示音",
            passed: true,
            message: "已升级：KLVolumeAnomalyEventFactory 可用，支持方向解析/类型识别/开关过滤/去重/文案自动生成"
        )
    }

    public static func placeholder() {
        // 已填充：KLVolumeAnomalyInput / KLVolumeAnomalyDirection / KLVolumeAnomalyKind
        //            / KLVolumeAnomalyEventFactory
        // 未实现：candle→rule 的完整规则匹配引擎（下阶段补充）
        // 禁止：播放声音、网络请求、数据库读写、UI 绘制
    }
}
