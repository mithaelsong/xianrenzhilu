// KP-DF-01_形态类型定义.swift
// 职责：29个内置K线形态的定义、分类、方向、规则元数据。

import Foundation

public enum CandlePatternCategory: String, Codable, Sendable, CaseIterable { case single = "单根", dual = "双根", multi = "三根+" }
public enum PatternDirection: String, Codable, Sendable, CaseIterable { case bullish, bearish, neutral, reversal, continuation, unknown }
public enum PatternConfidence: String, Codable, Sendable, CaseIterable { case low, medium, high }
public enum CandlePatternTrendPosition: String, Codable, Sendable, CaseIterable { case any, afterDowntrend, afterUptrend, continuationUp, continuationDown }

public struct CandlePatternRule: Codable, Equatable, Sendable {
    public let requiredCandles: Int
    public let trendPosition: CandlePatternTrendPosition
    public let minConfidence: Double
    public let notes: [String]

    public init(requiredCandles: Int, trendPosition: CandlePatternTrendPosition = .any, minConfidence: Double = 0.55, notes: [String] = []) {
        self.requiredCandles = requiredCandles
        self.trendPosition = trendPosition
        self.minConfidence = min(max(minConfidence, 0), 1)
        self.notes = notes
    }
}

public struct CandlePatternDefinition: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let category: CandlePatternCategory
    public let direction: PatternDirection
    public let confidence: PatternConfidence
    public let description: String
    public let rules: CandlePatternRule
    public let aliases: [String]

    public init(id: String, name: String, category: CandlePatternCategory, direction: PatternDirection, confidence: PatternConfidence = .medium, description: String, rules: CandlePatternRule, aliases: [String] = []) {
        self.id = id
        self.name = name
        self.category = category
        self.direction = direction
        self.confidence = confidence
        self.description = description
        self.rules = rules
        self.aliases = aliases
    }
}

public struct CandlePatternLibrary: Sendable {
    public static let shared = CandlePatternLibrary()
    public let allPatterns: [CandlePatternDefinition]

    public init(patterns: [CandlePatternDefinition] = CandlePatternLibrary.makeBuiltinPatterns()) { self.allPatterns = patterns }
    public func pattern(id: String) -> CandlePatternDefinition? { allPatterns.first { $0.id == id || $0.aliases.contains(id) } }
    public func patterns(category: CandlePatternCategory) -> [CandlePatternDefinition] { allPatterns.filter { $0.category == category } }
    public func patterns(direction: PatternDirection) -> [CandlePatternDefinition] { allPatterns.filter { $0.direction == direction } }

    private static func p(_ id: String, _ name: String, _ category: CandlePatternCategory, _ direction: PatternDirection, _ description: String, candles: Int, trend: CandlePatternTrendPosition = .any, min: Double = 0.55, confidence: PatternConfidence = .medium) -> CandlePatternDefinition {
        CandlePatternDefinition(id: id, name: name, category: category, direction: direction, confidence: confidence, description: description, rules: CandlePatternRule(requiredCandles: candles, trendPosition: trend, minConfidence: min))
    }

    public static func makeBuiltinPatterns() -> [CandlePatternDefinition] {
        [
            p("hammer", "锤子线", .single, .bullish, "下跌后小实体长下影，潜在看涨反转。", candles: 1, trend: .afterDowntrend, min: 0.62, confidence: .high),
            p("hanging-man", "吊颈线", .single, .bearish, "上涨后小实体长下影，潜在看跌反转。", candles: 1, trend: .afterUptrend, min: 0.62, confidence: .high),
            p("doji", "十字星", .single, .neutral, "开收盘接近，表示多空分歧。", candles: 1, min: 0.58),
            p("long-legged-doji", "长腿十字星", .single, .neutral, "十字实体且上下影线都较长。", candles: 1, min: 0.60),
            p("gravestone-doji", "墓碑十字星", .single, .bearish, "长上影十字，冲高回落。", candles: 1, trend: .afterUptrend, min: 0.60),
            p("dragonfly-doji", "蜻蜓十字星", .single, .bullish, "长下影十字，探底回升。", candles: 1, trend: .afterDowntrend, min: 0.60),
            p("marubozu", "光头光脚", .single, .continuation, "实体占比极高，趋势动能强。", candles: 1, min: 0.65),
            p("spinning-top", "纺锤线", .single, .neutral, "小实体且上下影线明显。", candles: 1, min: 0.55),
            p("long-lower-shadow", "长下影线", .single, .bullish, "下影线显示下方承接。", candles: 1, min: 0.55),
            p("long-upper-shadow", "长上影线", .single, .bearish, "上影线显示上方抛压。", candles: 1, min: 0.55),
            p("bullish-engulfing", "看涨吞没", .dual, .bullish, "阳线实体吞没前一根阴线实体。", candles: 2, trend: .afterDowntrend, min: 0.68, confidence: .high),
            p("bearish-engulfing", "看跌吞没", .dual, .bearish, "阴线实体吞没前一根阳线实体。", candles: 2, trend: .afterUptrend, min: 0.68, confidence: .high),
            p("piercing-line", "刺透形态", .dual, .bullish, "低开阳线收回前阴线实体一半以上。", candles: 2, trend: .afterDowntrend, min: 0.62),
            p("dark-cloud-cover", "乌云盖顶", .dual, .bearish, "高开阴线跌入前阳线实体一半以下。", candles: 2, trend: .afterUptrend, min: 0.62),
            p("bullish-harami", "看涨孕线", .dual, .bullish, "前阴后阳小实体被前实体包含。", candles: 2, trend: .afterDowntrend, min: 0.58),
            p("bearish-harami", "看跌孕线", .dual, .bearish, "前阳后阴小实体被前实体包含。", candles: 2, trend: .afterUptrend, min: 0.58),
            p("harami-cross", "十字孕线", .dual, .reversal, "后一根为十字星且位于前实体内部。", candles: 2, min: 0.58),
            p("tweezer-top", "镊子顶", .dual, .bearish, "两根K线高点接近，顶部受阻。", candles: 2, trend: .afterUptrend, min: 0.56),
            p("tweezer-bottom", "镊子底", .dual, .bullish, "两根K线低点接近，底部承接。", candles: 2, trend: .afterDowntrend, min: 0.56),
            p("gap", "跳空缺口", .dual, .continuation, "当前K线与前一根K线价格区间不重叠。", candles: 2, min: 0.60),
            p("bullish-separating", "看涨分手线", .dual, .bullish, "前阴后阳，开盘价接近但方向相反。", candles: 2, min: 0.56),
            p("bearish-separating", "看跌分手线", .dual, .bearish, "前阳后阴，开盘价接近但方向相反。", candles: 2, min: 0.56),
            p("morning-star", "晨星", .multi, .bullish, "大阴、小实体、大阳组合，潜在底部反转。", candles: 3, trend: .afterDowntrend, min: 0.68, confidence: .high),
            p("evening-star", "黄昏星", .multi, .bearish, "大阳、小实体、大阴组合，潜在顶部反转。", candles: 3, trend: .afterUptrend, min: 0.68, confidence: .high),
            p("abandoned-baby", "弃婴形态", .multi, .reversal, "中间十字星与两侧存在缺口，强反转信号。", candles: 3, min: 0.70, confidence: .high),
            p("three-black-crows", "三只乌鸦", .multi, .bearish, "连续三根较强阴线，收盘逐步走低。", candles: 3, trend: .afterUptrend, min: 0.68, confidence: .high),
            p("three-white-soldiers", "三白兵", .multi, .bullish, "连续三根较强阳线，收盘逐步走高。", candles: 3, trend: .afterDowntrend, min: 0.68, confidence: .high),
            p("rising-three-methods", "上升三法", .multi, .continuation, "上升趋势中的强阳、回调整理、再强阳。", candles: 5, trend: .continuationUp, min: 0.64),
            p("falling-three-methods", "下降三法", .multi, .continuation, "下降趋势中的强阴、反弹整理、再强阴。", candles: 5, trend: .continuationDown, min: 0.64)
        ]
    }
}


// MARK: - 兼容包装：保留迁移前公开扩展参数容器
public struct AnyCodable: Codable, Sendable {
    public let value: String
    public init(_ value: Any) { self.value = String(describing: value) }
    public init(from decoder: Decoder) throws { self.value = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(value) }
}

public extension CandlePatternRule {
    var bodyRatioMin: Double? { nil }
    var bodyRatioMax: Double? { nil }
    var lowerShadowRatioMin: Double? { nil }
    var lowerShadowRatioMax: Double? { nil }
    var upperShadowRatioMin: Double? { nil }
    var upperShadowRatioMax: Double? { nil }
    var color: String? { nil }
    var rawRules: [String: AnyCodable]? { nil }
}

public extension CandlePatternDefinition {
    var nameCN: String { name }
    var nameEN: String { id }
    var signalLogic: String { description }
}
