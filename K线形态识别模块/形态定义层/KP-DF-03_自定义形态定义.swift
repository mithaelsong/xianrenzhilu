// KP-DF-03_自定义形态定义.swift
// 职责：用户自定义形态规则和计算器。

import Foundation

public struct CustomCandlePatternRule: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let minBodyRatio: Double?
    public let maxBodyRatio: Double?
    public let minUpperShadowRatio: Double?
    public let minLowerShadowRatio: Double?
    public let direction: PatternDirection

    public init(id: String, name: String, minBodyRatio: Double? = nil, maxBodyRatio: Double? = nil, minUpperShadowRatio: Double? = nil, minLowerShadowRatio: Double? = nil, direction: PatternDirection = .unknown) {
        self.id = id; self.name = name; self.minBodyRatio = minBodyRatio; self.maxBodyRatio = maxBodyRatio; self.minUpperShadowRatio = minUpperShadowRatio; self.minLowerShadowRatio = minLowerShadowRatio; self.direction = direction
    }
}

public struct CustomPatternMatch: Sendable, Identifiable, Equatable {
    public let id: String
    public let rule: CustomCandlePatternRule
    public let candleIndex: Int
    public let confidence: Double

    public init(id: String = UUID().uuidString, rule: CustomCandlePatternRule, candleIndex: Int, confidence: Double) {
        self.id = id; self.rule = rule; self.candleIndex = candleIndex; self.confidence = min(max(confidence, 0), 1)
    }
}

public struct CustomPatternCalculator: Sendable {
    public let rules: [CustomCandlePatternRule]
    public init(rules: [CustomCandlePatternRule] = Self.defaultRules) { self.rules = rules }

    public func calculate(candles: [Candle]) -> [CustomPatternMatch] {
        var output: [CustomPatternMatch] = []
        for (index, candle) in candles.enumerated() {
            for rule in rules where matches(candle, rule: rule) {
                output.append(CustomPatternMatch(rule: rule, candleIndex: index, confidence: confidence(candle, rule: rule)))
            }
        }
        return output.sorted { $0.confidence > $1.confidence }
    }

    private func matches(_ candle: Candle, rule: CustomCandlePatternRule) -> Bool {
        let metric = metrics(candle)
        if let min = rule.minBodyRatio, metric.bodyRatio < min { return false }
        if let max = rule.maxBodyRatio, metric.bodyRatio > max { return false }
        if let min = rule.minUpperShadowRatio, metric.upperRatio < min { return false }
        if let min = rule.minLowerShadowRatio, metric.lowerRatio < min { return false }
        switch rule.direction { case .bullish: return metric.close > metric.open; case .bearish: return metric.close < metric.open; default: return true }
    }

    private func confidence(_ candle: Candle, rule: CustomCandlePatternRule) -> Double {
        let metric = metrics(candle)
        var score = 0.55
        if let minBody = rule.minBodyRatio { score += Swift.min(0.15, Swift.max(0, metric.bodyRatio - minBody)) }
        if let maxBody = rule.maxBodyRatio { score += Swift.min(0.15, Swift.max(0, maxBody - metric.bodyRatio)) }
        if let minUpper = rule.minUpperShadowRatio { score += Swift.min(0.1, Swift.max(0, metric.upperRatio - minUpper) * 0.2) }
        if let minLower = rule.minLowerShadowRatio { score += Swift.min(0.1, Swift.max(0, metric.lowerRatio - minLower) * 0.2) }
        return Swift.min(score, 0.95)
    }

    private func metrics(_ candle: Candle) -> (open: Double, close: Double, bodyRatio: Double, upperRatio: Double, lowerRatio: Double) {
        let open = NSDecimalNumber(decimal: candle.open).doubleValue
        let close = NSDecimalNumber(decimal: candle.close).doubleValue
        let high = NSDecimalNumber(decimal: candle.high).doubleValue
        let low = NSDecimalNumber(decimal: candle.low).doubleValue
        let range = max(high - low, 0.00000001)
        let body = abs(close - open)
        return (open, close, body / range, max(0, high - max(open, close)) / range, max(0, min(open, close) - low) / range)
    }

    public static let defaultRules: [CustomCandlePatternRule] = [
        CustomCandlePatternRule(id: "custom-long-lower-shadow", name: "自定义长下影", maxBodyRatio: 0.35, minLowerShadowRatio: 0.55, direction: .bullish),
        CustomCandlePatternRule(id: "custom-long-upper-shadow", name: "自定义长上影", maxBodyRatio: 0.35, minUpperShadowRatio: 0.55, direction: .bearish)
    ]
}

public enum KPDF03CustomPatternSkeleton: KPFileSkeletonProtocol {
    public static let descriptor = KPModuleRegistry.descriptor(id: "KP-DF-03") ?? KPFileDescriptor(id: "KP-DF-03", fileName: "KP-DF-03_自定义形态定义.swift", layer: .definition, relativePath: "形态定义层/KP-DF-03_自定义形态定义.swift", duty: "用户自定义形态规则和计算器")
    public static func skeletonStatus() -> KPHealthCheckItem { KPHealthCheckItem(name: descriptor.id, passed: true, message: "自定义形态规则计算器可用") }
}


public extension CustomCandlePatternRule {
    var identifier: String { id }
    var ruleID: String { id }
    var displayName: String { name }
    var ruleName: String { name }
    var minimumBodyRatio: Double? { minBodyRatio }
    var maximumBodyRatio: Double? { maxBodyRatio }
    var minimumUpperShadowRatio: Double? { minUpperShadowRatio }
    var minimumLowerShadowRatio: Double? { minLowerShadowRatio }
    var version: String { "3.0" }
}
