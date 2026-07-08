// KP-EN-01_形态识别引擎.swift
// 职责：执行单根、双根、多根K线形态识别；不读写数据库、不绘制UI。
// 版本：2.0 — 系统性重构识别规则，按经典定义精细化匹配逻辑。

import Foundation

public struct CandlePatternRecognitionContext: Sendable, Equatable {
    public let trend: String?
    public let supportLevels: [Decimal]
    public let resistanceLevels: [Decimal]
    public let volumeSignal: CandlePatternVolumeSignal?
    public let atr: Decimal?
    public let ma20: Decimal?
    public let ma50: Decimal?
    public let adx: Decimal?
    public let rsi: Decimal?

    public init(
        trend: String? = nil,
        supportLevels: [Decimal] = [],
        resistanceLevels: [Decimal] = [],
        volumeSignal: CandlePatternVolumeSignal? = nil,
        atr: Decimal? = nil,
        ma20: Decimal? = nil,
        ma50: Decimal? = nil,
        adx: Decimal? = nil,
        rsi: Decimal? = nil
    ) {
        self.trend = trend?.lowercased()
        self.supportLevels = supportLevels
        self.resistanceLevels = resistanceLevels
        self.volumeSignal = volumeSignal
        self.atr = atr
        self.ma20 = ma20
        self.ma50 = ma50
        self.adx = adx
        self.rsi = rsi
    }
}

public struct PatternMatchResult: Sendable, Equatable, CustomStringConvertible, Identifiable {
    public let id: String
    public let pattern: CandlePatternDefinition
    public let confidence: Double
    public let isExactMatch: Bool
    public let candleIndices: [Int]
    public let anchorTime: Date?
    public let anchorPrice: Decimal?

    public init(pattern: CandlePatternDefinition, confidence: Double, isExactMatch: Bool, candleIndices: [Int], anchorTime: Date? = nil, anchorPrice: Decimal? = nil) {
        self.id = "\(pattern.id):\(candleIndices.map(String.init).joined(separator: "-")):\(Int((anchorTime ?? Date(timeIntervalSince1970: 0)).timeIntervalSince1970))"
        self.pattern = pattern; self.confidence = min(max(confidence, 0), 1); self.isExactMatch = isExactMatch; self.candleIndices = candleIndices; self.anchorTime = anchorTime; self.anchorPrice = anchorPrice
    }

    public var description: String { "\(pattern.name) confidence=\(String(format: "%.2f", confidence)) indices=\(candleIndices)" }
}

public final class CandlePatternRecognizer {
    public static let shared = CandlePatternRecognizer()
    private let library: CandlePatternLibrary
    public init(library: CandlePatternLibrary = .shared) { self.library = library }

    public func recognizeSingle(candle: Candle, trend: String? = nil) -> [PatternMatchResult] { recognizeSingle(candle: candle, context: CandlePatternRecognitionContext(trend: trend)) }
    public func recognizeSingle(candle: Candle, context: CandlePatternRecognitionContext) -> [PatternMatchResult] { recognizeSingle(candle: candle, context: context, allowedPatternIDs: nil) }
    public func recognizeSingle(candle: Candle, context: CandlePatternRecognitionContext, allowedPatternIDs: Set<String>?) -> [PatternMatchResult] {
        patterns(category: .single, allowedPatternIDs: allowedPatternIDs).compactMap { match(pattern: $0, candles: [candle], context: context, baseIndex: 0) }
    }
    public func recognizeDual(previous: Candle, current: Candle) -> [PatternMatchResult] { recognizeDual(previous: previous, current: current, context: CandlePatternRecognitionContext()) }
    public func recognizeDual(previous: Candle, current: Candle, context: CandlePatternRecognitionContext) -> [PatternMatchResult] { recognizeDual(previous: previous, current: current, context: context, allowedPatternIDs: nil) }
    public func recognizeDual(previous: Candle, current: Candle, context: CandlePatternRecognitionContext, allowedPatternIDs: Set<String>?) -> [PatternMatchResult] {
        patterns(category: .dual, allowedPatternIDs: allowedPatternIDs).compactMap { match(pattern: $0, candles: [previous, current], context: context, baseIndex: 0) }
    }
    public func recognizeMulti(candles: [Candle]) -> [PatternMatchResult] { recognizeMulti(candles: candles, context: CandlePatternRecognitionContext()) }
    public func recognizeMulti(candles: [Candle], context: CandlePatternRecognitionContext) -> [PatternMatchResult] { recognizeMulti(candles: candles, context: context, allowedPatternIDs: nil) }
    public func recognizeMulti(candles: [Candle], context: CandlePatternRecognitionContext, allowedPatternIDs: Set<String>?) -> [PatternMatchResult] {
        patterns(category: .multi, allowedPatternIDs: allowedPatternIDs).compactMap { pattern in
            guard candles.count >= pattern.rules.requiredCandles else { return nil }
            let slice = Array(candles.suffix(pattern.rules.requiredCandles))
            return match(pattern: pattern, candles: slice, context: context, baseIndex: candles.count - slice.count)
        }
    }
    public func recognizeAll(candles: [Candle]) -> [PatternMatchResult] { recognizeAll(candles: candles, context: CandlePatternRecognitionContext()) }
    public func recognizeAll(candles: [Candle], context: CandlePatternRecognitionContext) -> [PatternMatchResult] { recognizeAll(candles: candles, context: context, allowedPatternIDs: nil) }
    public func recognizeAll(candles: [Candle], context: CandlePatternRecognitionContext, allowedPatternIDs: Set<String>?) -> [PatternMatchResult] {
        let candles = candles.filter { $0.isClosed }
        guard !candles.isEmpty else { return [] }
        guard allowedPatternIDs?.isEmpty != true else { return [] }
        var output: [PatternMatchResult] = []
        if let last = candles.last { output += recognizeSingle(candle: last, context: context, allowedPatternIDs: allowedPatternIDs).map { shifted($0, by: candles.count - 1, candle: last) } }
        if candles.count >= 2 { let pair = Array(candles.suffix(2)); output += patterns(category: .dual, allowedPatternIDs: allowedPatternIDs).compactMap { match(pattern: $0, candles: pair, context: context, baseIndex: candles.count - 2) } }
        output += recognizeMulti(candles: candles, context: context, allowedPatternIDs: allowedPatternIDs)
        return deduplicated(output).sorted { $0.confidence == $1.confidence ? $0.pattern.name < $1.pattern.name : $0.confidence > $1.confidence }
    }

    private func patterns(category: CandlePatternCategory, allowedPatternIDs: Set<String>?) -> [CandlePatternDefinition] {
        let candidates = library.patterns(category: category)
        guard let allowedPatternIDs else { return candidates }
        guard !allowedPatternIDs.isEmpty else { return [] }
        return candidates.filter { allowedPatternIDs.contains($0.id) }
    }

    private func shifted(_ result: PatternMatchResult, by offset: Int, candle: Candle) -> PatternMatchResult { PatternMatchResult(pattern: result.pattern, confidence: result.confidence, isExactMatch: result.isExactMatch, candleIndices: result.candleIndices.map { $0 + offset }, anchorTime: candle.openTime, anchorPrice: candle.close) }

    // MARK: - 主匹配分发

    private func match(pattern: CandlePatternDefinition, candles: [Candle], context: CandlePatternRecognitionContext, baseIndex: Int) -> PatternMatchResult? {
        guard candles.count == pattern.rules.requiredCandles else { return nil }
        let score: Double
        switch pattern.id {
        case "hammer": score = scoreHammer(candles[0], bullish: true, context: context)
        case "hanging-man": score = scoreHammer(candles[0], bullish: false, context: context)
        case "doji": score = scoreDoji(candles[0], context: context)
        case "long-legged-doji": score = scoreLongLeggedDoji(candles[0], context: context)
        case "gravestone-doji": score = scoreGravestone(candles[0], context: context)
        case "dragonfly-doji": score = scoreDragonfly(candles[0], context: context)
        case "marubozu": score = scoreMarubozu(candles[0], context: context)
        case "spinning-top": score = scoreSpinningTop(candles[0], context: context)
        case "long-lower-shadow": score = scoreLongShadow(candles[0], lower: true, context: context)
        case "long-upper-shadow": score = scoreLongShadow(candles[0], lower: false, context: context)
        case "bullish-engulfing": score = scoreEngulfing(candles[0], candles[1], bullish: true, context: context)
        case "bearish-engulfing": score = scoreEngulfing(candles[0], candles[1], bullish: false, context: context)
        case "piercing-line": score = scorePiercing(candles[0], candles[1], context: context)
        case "dark-cloud-cover": score = scoreDarkCloud(candles[0], candles[1], context: context)
        case "bullish-harami": score = scoreHarami(candles[0], candles[1], bullish: true, context: context)
        case "bearish-harami": score = scoreHarami(candles[0], candles[1], bullish: false, context: context)
        case "harami-cross": score = scoreHaramiCross(candles[0], candles[1], context: context)
        case "tweezer-top": score = scoreTweezer(candles[0], candles[1], top: true, context: context)
        case "tweezer-bottom": score = scoreTweezer(candles[0], candles[1], top: false, context: context)
        case "gap": score = scoreGap(candles[0], candles[1], context: context)
        case "bullish-separating": score = scoreSeparating(candles[0], candles[1], bullish: true, context: context)
        case "bearish-separating": score = scoreSeparating(candles[0], candles[1], bullish: false, context: context)
        case "morning-star": score = scoreStar(candles[0], candles[1], candles[2], bullish: true, context: context)
        case "evening-star": score = scoreStar(candles[0], candles[1], candles[2], bullish: false, context: context)
        case "abandoned-baby": score = scoreAbandonedBaby(candles[0], candles[1], candles[2], context: context)
        case "three-black-crows": score = scoreThreeLine(candles, bullish: false, context: context)
        case "three-white-soldiers": score = scoreThreeLine(candles, bullish: true, context: context)
        case "rising-three-methods": score = scoreThreeMethods(candles, bullish: true, context: context)
        case "falling-three-methods": score = scoreThreeMethods(candles, bullish: false, context: context)
        default: score = 0
        }
        let boosted = confirmationBoost(score, pattern: pattern, candles: candles, context: context)
        guard boosted >= pattern.rules.minConfidence else { return nil }
        let anchor = candles.last
        return PatternMatchResult(pattern: pattern, confidence: boosted, isExactMatch: boosted >= 0.82, candleIndices: Array(baseIndex..<(baseIndex + candles.count)), anchorTime: anchor?.openTime, anchorPrice: anchor?.close)
    }

    // MARK: - 增强Metrics系统

    /// K线度量：包含经典技术分析所需的全部维度
    private struct Metrics {
        let range: Double       // 总范围 (high - low)
        let body: Double        // 实体大小 |close - open|
        let bodyRatio: Double   // 实体占比 body/range
        let upperShadow: Double // 上影线
        let upperRatio: Double  // 上影线占比
        let lowerShadow: Double // 下影线
        let lowerRatio: Double  // 下影线占比
        let bullish: Bool       // 阳线
        let bearish: Bool       // 阴线
        let doji: Bool          // 实体极小 (<3%)
        let bodyPosition: Double // 实体中心在K线范围的位置 (0=底部, 0.5=中间, 1=顶部)
        let bodyTopPosition: Double // 实体上沿位置 (0=底部, 1=顶部)
        let bodyBottomPosition: Double // 实体下沿位置
        let isSignificant: Bool // K线是否有意义的大小

        init(candle: Candle, atr: Decimal? = nil) {
            let o = Metrics.d(candle.open)
            let cl = Metrics.d(candle.close)
            let h = Metrics.d(candle.high)
            let l = Metrics.d(candle.low)
            let r = max(h - l, 0.00000001)
            let b = abs(cl - o)
            let upper = max(0, h - max(o, cl))
            let lower = max(0, min(o, cl) - l)

            self.range = r
            self.body = b
            self.bodyRatio = b / r
            self.upperShadow = upper
            self.upperRatio = upper / r
            self.lowerShadow = lower
            self.lowerRatio = lower / r
            self.bullish = cl > o
            self.bearish = cl < o
            self.doji = b / r < 0.03

            let bodyCenter = (max(o, cl) + min(o, cl)) / 2
            self.bodyPosition = (bodyCenter - l) / r
            self.bodyTopPosition = (max(o, cl) - l) / r
            self.bodyBottomPosition = (min(o, cl) - l) / r

            // K线质量：至少要有一定大小
            let atrValue = atr.map { Metrics.d($0) } ?? 0
            self.isSignificant = r >= max(atrValue * 0.15, abs(o) * 0.001)
        }

        static func d(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
    }

    private func m(_ c: Candle, atr: Decimal? = nil) -> Metrics { Metrics(candle: c, atr: atr) }
    private func d(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
    private func midpoint(_ c: Candle) -> Double { (d(c.open) + d(c.close)) / 2 }
    private func bodyHigh(_ c: Candle) -> Double { max(d(c.open), d(c.close)) }
    private func bodyLow(_ c: Candle) -> Double { min(d(c.open), d(c.close)) }
    private func near(_ a: Decimal, _ b: Decimal, tolerance: Double) -> Bool { abs(d(a) - d(b)) <= tolerance }
    private func tolerance(_ candles: [Candle]) -> Double { max(candles.map { m($0).range }.reduce(0, +) / Double(max(candles.count, 1)) * 0.08, 0.00000001) }

    // MARK: - 单根K线形态

    /// 锤子线/吊颈线 — 经典定义：
    /// 1. 实体小（<30%），在K线顶部（看涨）或底部（看跌）
    /// 2. 下影线长（≥2倍实体），上影线短（<10%）
    /// 3. 有最小实体要求（不能太小了变成十字星）
    /// 4. 位置验证：下跌趋势末端（锤子）/上涨趋势末端（吊颈）
    private func scoreHammer(_ c: Candle, bullish: Bool, context: CandlePatternRecognitionContext) -> Double {
        let x = m(c, atr: context.atr)
        guard x.isSignificant else { return 0 }
        guard x.bodyRatio >= 0.03 && x.bodyRatio <= 0.30 else { return 0 }
        guard x.lowerShadow >= x.body * 2.0 else { return 0 }
        guard x.upperRatio <= 0.10 else { return 0 }

        // 实体位置验证
        if bullish {
            guard x.bodyTopPosition >= 0.65 else { return 0 } // 实体在顶部
        } else {
            guard x.bodyBottomPosition <= 0.35 else { return 0 } // 实体在底部
        }

        // 基础分：下影线越长分越高
        var s = 0.65 + min(0.20, (x.lowerShadow / max(x.body, 0.00000001) - 2.0) * 0.05)
        // 实体越小分越高（但不能是十字星）
        s += min(0.08, (0.30 - x.bodyRatio) * 0.25)

        // 趋势位置加分
        if bullish && context.trend == "down" { s += 0.04 }
        if !bullish && context.trend == "up" { s += 0.04 }

        // RSI极端加分
        if let rsi = context.rsi {
            let r = d(rsi)
            if bullish && r < 35 { s += 0.03 }
            if !bullish && r > 65 { s += 0.03 }
        }

        return min(s, 0.94)
    }

    /// 十字星 — 严格定义：实体极小（<3%），但上下影线可长可短
    private func scoreDoji(_ c: Candle, context: CandlePatternRecognitionContext) -> Double {
        let x = m(c, atr: context.atr)
        guard x.isSignificant else { return 0 }
        guard x.bodyRatio <= 0.03 else { return 0 }

        var s = 0.72
        // 影线对称加分
        let shadowDiff = abs(x.upperRatio - x.lowerRatio)
        if shadowDiff <= 0.15 { s += 0.04 }
        // 影线较长加分（说明多空争夺激烈）
        let totalShadow = x.upperRatio + x.lowerRatio
        if totalShadow >= 0.70 { s += 0.04 }

        return min(s, 0.88)
    }

    /// 长腿十字星 — 实体极小 + 上下影线都长（各≥25%）
    private func scoreLongLeggedDoji(_ c: Candle, context: CandlePatternRecognitionContext) -> Double {
        let x = m(c, atr: context.atr)
        guard x.isSignificant else { return 0 }
        guard x.bodyRatio <= 0.05 else { return 0 }
        guard x.upperRatio >= 0.28 && x.lowerRatio >= 0.28 else { return 0 }

        var s = 0.74
        // 影线越长分越高
        s += min(0.10, (x.upperRatio + x.lowerRatio - 0.56) * 0.15)
        // 影线越对称分越高
        let symmetry = 1.0 - abs(x.upperRatio - x.lowerRatio)
        s += symmetry * 0.06

        return min(s, 0.90)
    }

    /// 墓碑十字星 — 长上影 + 极小实体 + 短下影
    private func scoreGravestone(_ c: Candle, context: CandlePatternRecognitionContext) -> Double {
        let x = m(c, atr: context.atr)
        guard x.isSignificant else { return 0 }
        guard x.bodyRatio <= 0.08 else { return 0 }
        guard x.upperRatio >= 0.55 else { return 0 }
        guard x.lowerRatio <= 0.10 else { return 0 }

        var s = 0.70
        s += min(0.12, (x.upperRatio - 0.55) * 0.20)

        // 趋势位置
        if context.trend == "up" { s += 0.04 }
        // RSI高位
        if let rsi = context.rsi, d(rsi) > 65 { s += 0.03 }

        return min(s, 0.90)
    }

    /// 蜻蜓十字星 — 长下影 + 极小实体 + 短上影
    private func scoreDragonfly(_ c: Candle, context: CandlePatternRecognitionContext) -> Double {
        let x = m(c, atr: context.atr)
        guard x.isSignificant else { return 0 }
        guard x.bodyRatio <= 0.08 else { return 0 }
        guard x.lowerRatio >= 0.55 else { return 0 }
        guard x.upperRatio <= 0.10 else { return 0 }

        var s = 0.70
        s += min(0.12, (x.lowerRatio - 0.55) * 0.20)

        // 趋势位置
        if context.trend == "down" { s += 0.04 }
        // RSI低位
        if let rsi = context.rsi, d(rsi) < 35 { s += 0.03 }

        return min(s, 0.90)
    }

    /// 光头光脚 — 实体占比极高（≥85%），影线极短
    private func scoreMarubozu(_ c: Candle, context: CandlePatternRecognitionContext) -> Double {
        let x = m(c, atr: context.atr)
        guard x.isSignificant else { return 0 }
        guard x.bodyRatio >= 0.85 else { return 0 }
        guard x.upperRatio <= 0.08 && x.lowerRatio <= 0.08 else { return 0 }

        var s = 0.78
        s += min(0.10, (x.bodyRatio - 0.85) * 0.40)

        // 大实体加分
        if x.bodyRatio >= 0.95 { s += 0.04 }

        return min(s, 0.92)
    }

    /// 纺锤线 — 小实体 + 上下影线明显（各≥15%）
    private func scoreSpinningTop(_ c: Candle, context: CandlePatternRecognitionContext) -> Double {
        let x = m(c, atr: context.atr)
        guard x.isSignificant else { return 0 }
        guard x.bodyRatio >= 0.05 && x.bodyRatio <= 0.35 else { return 0 }
        guard x.upperRatio >= 0.15 && x.lowerRatio >= 0.15 else { return 0 }

        var s = 0.58
        // 影线越对称分越高
        let symmetry = 1.0 - abs(x.upperRatio - x.lowerRatio)
        s += symmetry * 0.10
        // 实体越小但还在范围内分越高
        s += min(0.06, (0.35 - x.bodyRatio) * 0.15)

        return min(s, 0.78)
    }

    /// 长下影线 / 长上影线
    private func scoreLongShadow(_ c: Candle, lower: Bool, context: CandlePatternRecognitionContext) -> Double {
        let x = m(c, atr: context.atr)
        guard x.isSignificant else { return 0 }

        if lower {
            // 长下影：下影线长，上影线短，实体不能太大
            guard x.lowerRatio >= 0.50 else { return 0 }
            guard x.upperRatio <= 0.20 else { return 0 }
            guard x.bodyRatio <= 0.40 else { return 0 }

            var s = 0.62
            s += min(0.16, (x.lowerRatio - 0.50) * 0.25)
            // 实体位置：最好在下部
            if x.bodyPosition <= 0.55 { s += 0.04 }
            // 趋势
            if context.trend == "down" { s += 0.03 }
            // RSI
            if let rsi = context.rsi, d(rsi) < 40 { s += 0.03 }
            return min(s, 0.88)
        } else {
            // 长上影：上影线长，下影线短，实体不能太大
            guard x.upperRatio >= 0.50 else { return 0 }
            guard x.lowerRatio <= 0.20 else { return 0 }
            guard x.bodyRatio <= 0.40 else { return 0 }

            var s = 0.62
            s += min(0.16, (x.upperRatio - 0.50) * 0.25)
            // 实体位置：最好在上部
            if x.bodyPosition >= 0.45 { s += 0.04 }
            // 趋势
            if context.trend == "up" { s += 0.03 }
            // RSI
            if let rsi = context.rsi, d(rsi) > 60 { s += 0.03 }
            return min(s, 0.88)
        }
    }

    // MARK: - 双根K线形态

    /// 吞没形态 — 经典定义：
    /// 1. 第一根有实体（非十字星），第二根实体完全覆盖第一根
    /// 2. 第二根实体明显大于第一根
    /// 3. 出现在趋势末端
    private func scoreEngulfing(_ a: Candle, _ b: Candle, bullish: Bool, context: CandlePatternRecognitionContext) -> Double {
        let am = m(a, atr: context.atr), bm = m(b, atr: context.atr)
        guard am.isSignificant && bm.isSignificant else { return 0 }
        // 第一根不能是十字星
        guard am.bodyRatio >= 0.08 else { return 0 }
        // 第二根实体要明显大于第一根（至少1.2倍）
        guard bm.body >= am.body * 1.15 else { return 0 }

        if bullish {
            guard am.bearish && bm.bullish else { return 0 }
            guard bodyLow(b) <= bodyLow(a) else { return 0 }
            guard bodyHigh(b) >= bodyHigh(a) else { return 0 }
        } else {
            guard am.bullish && bm.bearish else { return 0 }
            guard bodyLow(b) <= bodyLow(a) else { return 0 }
            guard bodyHigh(b) >= bodyHigh(a) else { return 0 }
        }

        var s = 0.72
        // 第二根实体越大分越高
        let sizeRatio = bm.body / max(am.body, 0.00000001)
        s += min(0.10, (sizeRatio - 1.15) * 0.15)
        // 第二根收盘超出第一根实体越多分越高
        let extensionRatio = bullish
            ? (bodyHigh(b) - bodyHigh(a)) / max(am.body, 0.00000001)
            : (bodyLow(a) - bodyLow(b)) / max(am.body, 0.00000001)
        s += min(0.06, max(0, extensionRatio) * 0.08)

        // 趋势位置
        let trendBoost = (bullish && context.trend == "down") || (!bullish && context.trend == "up") ? 0.05 : 0.0
        s += trendBoost

        // RSI极端
        if let rsi = context.rsi {
            let r = d(rsi)
            if bullish && r < 35 { s += 0.03 }
            if !bullish && r > 65 { s += 0.03 }
        }

        return min(s, 0.96)
    }

    /// 刺透形态 — 经典定义：
    /// 1. 第一根阴线有实体
    /// 2. 第二根阳线低开，收盘价深入第一根实体内部（超过50%）
    /// 3. 第二根未完全吞没第一根（那是吞没形态，不是刺透）
    private func scorePiercing(_ a: Candle, _ b: Candle, context: CandlePatternRecognitionContext) -> Double {
        let am = m(a, atr: context.atr), bm = m(b, atr: context.atr)
        guard am.isSignificant && bm.isSignificant else { return 0 }
        guard am.bearish && bm.bullish else { return 0 }
        // 第一根要有实体
        guard am.bodyRatio >= 0.15 else { return 0 }
        // 第二根低开
        guard d(b.open) < d(a.close) else { return 0 }
        // 第二根收盘深入第一根实体超过50%
        let aMid = midpoint(a)
        guard d(b.close) > aMid else { return 0 }
        // 但未完全吞没（避免与吞没形态混淆）
        guard bodyHigh(b) < bodyHigh(a) || bodyLow(b) > bodyLow(a) else { return 0 }

        var s = 0.70
        // 深入程度
        let penetration = (d(b.close) - aMid) / am.body
        s += min(0.12, penetration * 0.12)
        // 第二根实体大小
        s += min(0.06, bm.bodyRatio * 0.08)

        // 趋势
        if context.trend == "down" { s += 0.04 }
        if let rsi = context.rsi, d(rsi) < 35 { s += 0.03 }

        return min(s, 0.92)
    }

    /// 乌云盖顶 — 刺透的看跌版本
    private func scoreDarkCloud(_ a: Candle, _ b: Candle, context: CandlePatternRecognitionContext) -> Double {
        let am = m(a, atr: context.atr), bm = m(b, atr: context.atr)
        guard am.isSignificant && bm.isSignificant else { return 0 }
        guard am.bullish && bm.bearish else { return 0 }
        guard am.bodyRatio >= 0.15 else { return 0 }
        guard d(b.open) > d(a.close) else { return 0 }
        let aMid = midpoint(a)
        guard d(b.close) < aMid else { return 0 }
        guard bodyHigh(b) < bodyHigh(a) || bodyLow(b) > bodyLow(a) else { return 0 }

        var s = 0.70
        let penetration = (aMid - d(b.close)) / am.body
        s += min(0.12, penetration * 0.12)
        s += min(0.06, bm.bodyRatio * 0.08)

        if context.trend == "up" { s += 0.04 }
        if let rsi = context.rsi, d(rsi) > 65 { s += 0.03 }

        return min(s, 0.92)
    }

    /// 孕线 — 经典定义：
    /// 1. 第一根有实体
    /// 2. 第二根实体完全在第一根实体内
    /// 3. 第二根实体明显小于第一根（<50%）
    private func scoreHarami(_ a: Candle, _ b: Candle, bullish: Bool, context: CandlePatternRecognitionContext) -> Double {
        let am = m(a, atr: context.atr), bm = m(b, atr: context.atr)
        guard am.isSignificant && bm.isSignificant else { return 0 }
        guard am.bodyRatio >= 0.15 else { return 0 }
        // 第二根实体要在第一根实体内
        guard bodyLow(b) >= bodyLow(a) && bodyHigh(b) <= bodyHigh(a) else { return 0 }
        // 第二根明显更小
        guard bm.body <= am.body * 0.55 else { return 0 }

        if bullish {
            guard am.bearish && bm.bullish else { return 0 }
        } else {
            guard am.bullish && bm.bearish else { return 0 }
        }

        var s = 0.64
        // 越小越像孕线
        s += min(0.10, (0.55 - bm.body / max(am.body, 0.00000001)) * 0.20)
        // 第一根实体越大越好
        s += min(0.06, am.bodyRatio * 0.08)

        let trendBoost = (bullish && context.trend == "down") || (!bullish && context.trend == "up") ? 0.04 : 0.0
        s += trendBoost

        return min(s, 0.88)
    }

    /// 十字孕线
    private func scoreHaramiCross(_ a: Candle, _ b: Candle, context: CandlePatternRecognitionContext) -> Double {
        let am = m(a, atr: context.atr), bm = m(b, atr: context.atr)
        guard am.isSignificant && bm.isSignificant else { return 0 }
        guard am.bodyRatio >= 0.15 else { return 0 }
        guard bodyLow(b) >= bodyLow(a) && bodyHigh(b) <= bodyHigh(a) else { return 0 }
        // 第二根必须是严格十字星
        guard bm.bodyRatio <= 0.05 else { return 0 }

        var s = 0.68
        // 第一根实体越大越好
        s += min(0.10, am.bodyRatio * 0.10)

        return min(s, 0.88)
    }

    /// 镊子顶/底 — 两根K线的高/低点接近
    private func scoreTweezer(_ a: Candle, _ b: Candle, top: Bool, context: CandlePatternRecognitionContext) -> Double {
        let am = m(a, atr: context.atr), bm = m(b, atr: context.atr)
        guard am.isSignificant && bm.isSignificant else { return 0 }
        let tol = tolerance([a, b])

        if top {
            guard near(a.high, b.high, tolerance: tol) else { return 0 }
            // 最好两根都有上影线
            guard am.upperRatio >= 0.10 || bm.upperRatio >= 0.10 else { return 0 }
            // 趋势
            var s = 0.62
            if context.trend == "up" { s += 0.04 }
            if let rsi = context.rsi, d(rsi) > 65 { s += 0.03 }
            return min(s, 0.86)
        } else {
            guard near(a.low, b.low, tolerance: tol) else { return 0 }
            guard am.lowerRatio >= 0.10 || bm.lowerRatio >= 0.10 else { return 0 }
            var s = 0.62
            if context.trend == "down" { s += 0.04 }
            if let rsi = context.rsi, d(rsi) < 35 { s += 0.03 }
            return min(s, 0.86)
        }
    }

    /// 跳空缺口
    private func scoreGap(_ a: Candle, _ b: Candle, context: CandlePatternRecognitionContext) -> Double {
        let am = m(a, atr: context.atr), bm = m(b, atr: context.atr)
        guard am.isSignificant && bm.isSignificant else { return 0 }

        let gapUp = d(b.low) > d(a.high)
        let gapDown = d(b.high) < d(a.low)
        guard gapUp || gapDown else { return 0 }

        let gapSize = gapUp ? d(b.low) - d(a.high) : d(a.low) - d(b.high)
        let avgBody = (am.body + bm.body) / 2
        let gapRatio = gapSize / max(avgBody, 0.00000001)

        var s = 0.68
        // 缺口越大分越高
        s += min(0.14, gapRatio * 0.06)
        // 方向一致加分
        if gapUp && bm.bullish { s += 0.04 }
        if gapDown && bm.bearish { s += 0.04 }

        return min(s, 0.90)
    }

    /// 分手线 — 两根开盘价接近，方向相反
    private func scoreSeparating(_ a: Candle, _ b: Candle, bullish: Bool, context: CandlePatternRecognitionContext) -> Double {
        let am = m(a, atr: context.atr), bm = m(b, atr: context.atr)
        guard am.isSignificant && bm.isSignificant else { return 0 }
        let sameOpen = abs(d(a.open) - d(b.open)) <= tolerance([a, b]) * 2
        guard sameOpen else { return 0 }

        if bullish {
            guard am.bearish && bm.bullish else { return 0 }
            guard bm.body >= am.body * 0.80 else { return 0 }
        } else {
            guard am.bullish && bm.bearish else { return 0 }
            guard bm.body >= am.body * 0.80 else { return 0 }
        }

        var s = 0.62
        // 第二根实体越大越好
        let sizeRatio = bm.body / max(am.body, 0.00000001)
        s += min(0.10, (sizeRatio - 0.80) * 0.15)

        let trendBoost = (bullish && context.trend == "down") || (!bullish && context.trend == "up") ? 0.04 : 0.0
        s += trendBoost

        return min(s, 0.88)
    }

    // MARK: - 三根K线形态

    /// 晨星/黄昏星 — 经典定义：
    /// 1. 第一根大实体，方向与趋势一致
    /// 2. 第二根小实体，与第一根有缺口（价格不重叠）
    /// 3. 第三根大实体，方向与第一根相反，收盘深入第一根实体内部
    private func scoreStar(_ a: Candle, _ b: Candle, _ c: Candle, bullish: Bool, context: CandlePatternRecognitionContext) -> Double {
        let am = m(a, atr: context.atr), bm = m(b, atr: context.atr), cm = m(c, atr: context.atr)
        guard am.isSignificant && bm.isSignificant && cm.isSignificant else { return 0 }

        // 第一根要有大实体
        guard am.bodyRatio >= 0.40 else { return 0 }
        // 第二根小实体
        guard bm.bodyRatio <= 0.30 else { return 0 }
        // 第三根要有实体
        guard cm.bodyRatio >= 0.25 else { return 0 }

        if bullish {
            guard am.bearish && cm.bullish else { return 0 }
            // 第三根收盘要深入第一根实体（超过中点）
            guard d(c.close) > midpoint(a) else { return 0 }
        } else {
            guard am.bullish && cm.bearish else { return 0 }
            guard d(c.close) < midpoint(a) else { return 0 }
        }

        var s = 0.74

        // 缺口验证（第二根与第一根不重叠）— 越强越好但不是必须
        let hasGap = bullish
            ? d(b.low) > d(a.high) || d(b.high) < d(a.low) // 任意方向缺口都算
            : d(b.low) > d(a.high) || d(b.high) < d(a.low)
        if hasGap { s += 0.04 }

        // 第二根越像十字星越好
        if bm.bodyRatio <= 0.10 { s += 0.04 }

        // 第三根实体越大、深入第一根越多分越高
        let penetration = bullish
            ? (d(c.close) - midpoint(a)) / am.body
            : (midpoint(a) - d(c.close)) / am.body
        s += min(0.08, max(0, penetration) * 0.10)

        // 趋势位置
        let trendBoost = (bullish && context.trend == "down") || (!bullish && context.trend == "up") ? 0.04 : 0.0
        s += trendBoost

        // RSI
        if let rsi = context.rsi {
            let r = d(rsi)
            if bullish && r < 35 { s += 0.03 }
            if !bullish && r > 65 { s += 0.03 }
        }

        return min(s, 0.94)
    }

    /// 弃婴形态 — 严格版晨星/黄昏星，要求中间十字星与两侧都有缺口
    private func scoreAbandonedBaby(_ a: Candle, _ b: Candle, _ c: Candle, context: CandlePatternRecognitionContext) -> Double {
        let am = m(a, atr: context.atr), bm = m(b, atr: context.atr), cm = m(c, atr: context.atr)
        guard am.isSignificant && bm.isSignificant && cm.isSignificant else { return 0 }

        // 中间必须是严格十字星
        guard bm.bodyRatio <= 0.05 else { return 0 }
        // 第一根大实体
        guard am.bodyRatio >= 0.40 else { return 0 }
        // 第三根有实体
        guard cm.bodyRatio >= 0.25 else { return 0 }

        // 两侧缺口
        let g1 = d(b.low) > d(a.high) || d(b.high) < d(a.low)
        let g2 = d(c.low) > d(b.high) || d(c.high) < d(b.low)
        guard g1 && g2 else { return 0 }

        // 方向：第一根和第三根相反
        let bullish = am.bearish && cm.bullish
        let bearish = am.bullish && cm.bearish
        guard bullish || bearish else { return 0 }

        if bullish {
            guard d(c.close) > midpoint(a) else { return 0 }
        } else {
            guard d(c.close) < midpoint(a) else { return 0 }
        }

        var s = 0.82
        // 第三根实体越大分越高
        s += min(0.08, cm.bodyRatio * 0.10)
        // 趋势
        if bullish && context.trend == "down" { s += 0.03 }
        if bearish && context.trend == "up" { s += 0.03 }

        return min(s, 0.96)
    }

    /// 三只乌鸦 / 三白兵
    private func scoreThreeLine(_ candles: [Candle], bullish: Bool, context: CandlePatternRecognitionContext) -> Double {
        guard candles.count == 3 else { return 0 }
        let ms = candles.map { m($0, atr: context.atr) }
        guard ms.allSatisfy({ $0.isSignificant }) else { return 0 }

        if bullish {
            // 三根都是阳线，实体较大，收盘价递增
            guard ms.allSatisfy({ $0.bullish && $0.bodyRatio >= 0.40 }) else { return 0 }
            guard d(candles[0].close) < d(candles[1].close) && d(candles[1].close) < d(candles[2].close) else { return 0 }
            // 最好开盘价在前一根实体内或附近（不是大跳空）
            let opensInBody = (bodyLow(candles[0])...bodyHigh(candles[0])).contains(d(candles[1].open))
                && (bodyLow(candles[1])...bodyHigh(candles[1])).contains(d(candles[2].open))
            var s = 0.76
            if opensInBody { s += 0.04 }
            // 影线短加分
            let shortShadows = ms.allSatisfy { $0.upperRatio <= 0.15 && $0.lowerRatio <= 0.15 }
            if shortShadows { s += 0.04 }
            if context.trend == "down" { s += 0.03 }
            return min(s, 0.92)
        } else {
            guard ms.allSatisfy({ $0.bearish && $0.bodyRatio >= 0.40 }) else { return 0 }
            guard d(candles[0].close) > d(candles[1].close) && d(candles[1].close) > d(candles[2].close) else { return 0 }
            let opensInBody = (bodyLow(candles[0])...bodyHigh(candles[0])).contains(d(candles[1].open))
                && (bodyLow(candles[1])...bodyHigh(candles[1])).contains(d(candles[2].open))
            var s = 0.76
            if opensInBody { s += 0.04 }
            let shortShadows = ms.allSatisfy { $0.upperRatio <= 0.15 && $0.lowerRatio <= 0.15 }
            if shortShadows { s += 0.04 }
            if context.trend == "up" { s += 0.03 }
            return min(s, 0.92)
        }
    }

    /// 上升三法 / 下降三法
    private func scoreThreeMethods(_ candles: [Candle], bullish: Bool, context: CandlePatternRecognitionContext) -> Double {
        guard candles.count == 5 else { return 0 }
        let first = candles[0], last = candles[4], middle = candles[1...3]
        let fm = m(first, atr: context.atr), lm = m(last, atr: context.atr)
        guard fm.isSignificant && lm.isSignificant else { return 0 }

        // 第一根和最后一根都是大实体，方向一致
        guard fm.bodyRatio >= 0.50 && lm.bodyRatio >= 0.50 else { return 0 }

        if bullish {
            guard fm.bullish && lm.bullish else { return 0 }
            // 最后一根收盘价要高于第一根
            guard d(last.close) > d(first.close) else { return 0 }
        } else {
            guard fm.bearish && lm.bearish else { return 0 }
            guard d(last.close) < d(first.close) else { return 0 }
        }

        // 中间三根要在第一根实体内整理
        let firstBodyLow = bodyLow(first)
        let firstBodyHigh = bodyHigh(first)
        var middleValid = true
        for mid in middle {
            let mm = m(mid, atr: context.atr)
            guard mm.isSignificant else { middleValid = false; break }
            // 中间K线实体小或方向相反
            if bullish {
                guard mm.bearish || mm.bodyRatio <= 0.35 else { middleValid = false; break }
            } else {
                guard mm.bullish || mm.bodyRatio <= 0.35 else { middleValid = false; break }
            }
            // 最好在第一根实体内
            if bodyHigh(mid) > firstBodyHigh || bodyLow(mid) < firstBodyLow {
                // 允许小幅超出，但扣分
            }
        }
        guard middleValid else { return 0 }

        var s = 0.74
        // 中间完全在第一根实体内加分
        let allInBody = middle.allSatisfy { bodyHigh($0) <= firstBodyHigh && bodyLow($0) >= firstBodyLow }
        if allInBody { s += 0.06 }
        // 中间K线数量正好3根加分
        // 最后一根实体大于第一根加分
        if lm.body >= fm.body * 1.1 { s += 0.04 }

        return min(s, 0.90)
    }

    // MARK: - 确认与过滤系统

    /// 综合确认系统：根据指标、位置、趋势动态调整置信度
    private func confirmationBoost(_ score: Double, pattern: CandlePatternDefinition, candles: [Candle], context: CandlePatternRecognitionContext) -> Double {
        guard score > 0 else { return 0 }
        guard let last = candles.last else { return 0 }
        var v = score

        // 成交量确认
        if context.volumeSignal == .spike { v += 0.05 }
        else if context.volumeSignal == .high { v += 0.03 }
        else if context.volumeSignal == .low { v -= 0.02 } // 缩量形态不可靠

        // ADX趋势强度
        if let adx = context.adx {
            let adxValue = d(adx)
            if adxValue >= 30 { v += 0.03 }      // 强趋势中形态更可靠
            else if adxValue >= 20 { v += 0.01 }
            else if adxValue < 15 { v -= 0.06 }  // 震荡区间假信号多
        }

        // 支撑/阻力位置
        if pattern.direction == .bullish && nearAny(last.low, levels: context.supportLevels, candles: candles, atr: context.atr) { v += 0.05 }
        if pattern.direction == .bearish && nearAny(last.high, levels: context.resistanceLevels, candles: candles, atr: context.atr) { v += 0.05 }

        // MA趋势一致性
        if let ma20 = context.ma20 {
            let close = d(last.close)
            let ma = d(ma20)
            if pattern.direction == .bullish && close > ma { v += 0.02 }
            if pattern.direction == .bearish && close < ma { v += 0.02 }
        }
        if let ma50 = context.ma50 {
            let close = d(last.close)
            let ma = d(ma50)
            if pattern.direction == .bullish && close > ma { v += 0.02 }
            if pattern.direction == .bearish && close < ma { v += 0.02 }
        }

        // RSI极端状态确认
        if let rsi = context.rsi {
            let r = d(rsi)
            if pattern.direction == .bullish && r < 30 { v += 0.03 }
            if pattern.direction == .bearish && r > 70 { v += 0.03 }
            // RSI在50附近（震荡）降级
            if abs(r - 50) < 10 { v -= 0.04 }
        }

        return min(max(v, 0), 0.98)
    }

    private func nearAny(_ price: Decimal, levels: [Decimal], candles: [Candle], atr: Decimal? = nil) -> Bool {
        let atrTolerance = atr.map { max(0, d($0) * 0.30) } ?? 0
        let t = max(max(tolerance(candles), abs(d(price)) * 0.003), atrTolerance)
        return levels.contains { abs(d($0) - d(price)) <= t }
    }

    private func deduplicated(_ results: [PatternMatchResult]) -> [PatternMatchResult] {
        var best: [String: PatternMatchResult] = [:]
        for item in results {
            let key = "\(item.pattern.id):\(item.candleIndices.map(String.init).joined(separator: ","))"
            if let existing = best[key], existing.confidence >= item.confidence { continue }
            best[key] = item
        }
        return Array(best.values)
    }
}
