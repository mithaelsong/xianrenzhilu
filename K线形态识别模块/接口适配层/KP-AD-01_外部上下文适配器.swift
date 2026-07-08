// KP-AD-01_外部上下文适配器.swift
// 职责：把外部K线模块数据适配为本模块 Candle 和识别上下文。

import Foundation

public struct CandlePatternIndicatorSnapshot: Sendable, Equatable {
    public let trend: String?
    public let supportLevels: [Decimal]
    public let resistanceLevels: [Decimal]
    public let volumeSignal: CandlePatternVolumeSignal?
    public let atr: Decimal?
    public let indicatorValues: [String: Double]
    public let usedIndicatorIDs: [String]
    public let missingIndicatorIDs: [String]

    public init(
        trend: String? = nil,
        supportLevels: [Decimal] = [],
        resistanceLevels: [Decimal] = [],
        volumeSignal: CandlePatternVolumeSignal? = nil,
        atr: Decimal? = nil,
        indicatorValues: [String: Double] = [:],
        usedIndicatorIDs: [String] = [],
        missingIndicatorIDs: [String] = []
    ) {
        self.trend = trend
        self.supportLevels = supportLevels
        self.resistanceLevels = resistanceLevels
        self.volumeSignal = volumeSignal
        self.atr = atr
        self.indicatorValues = indicatorValues
        self.usedIndicatorIDs = usedIndicatorIDs
        self.missingIndicatorIDs = missingIndicatorIDs
    }

    public var recognitionContext: CandlePatternRecognitionContext {
        CandlePatternRecognitionContext(
            trend: trend,
            supportLevels: supportLevels,
            resistanceLevels: resistanceLevels,
            volumeSignal: volumeSignal,
            atr: atr,
            ma20: ma20,
            adx: adx
        )
    }
}

public enum CandlePatternIndicatorBridge {
    public static func candles(from points: [KLCandlePoint]) -> [Candle] {
        points.map { point in
            Candle(id: point.id ?? "\(point.symbol):\(point.timeframe.rawValue):\(Int(point.openTime.timeIntervalSince1970))", symbol: point.symbol, timeframe: point.timeframe.rawValue, openTime: point.openTime, closeTime: point.closeTime, open: point.open, high: point.high, low: point.low, close: point.close, volume: point.volume, isClosed: point.isClosed)
        }
    }

    public static func makeSnapshot(candles: [KLCandlePoint], query: KLKLineQuery) -> CandlePatternIndicatorSnapshot {
        let filtered = candles
            .filter { $0.symbol == query.symbol && $0.timeframe == query.timeframe }
            .filter { query.includeUnclosed || $0.isClosed }
            .filter { point in query.startTime.map { point.openTime >= $0 } ?? true }
            .filter { point in query.endTime.map { point.openTime <= $0 } ?? true }
        let sorted = query.order == .ascending ? filtered.sorted { $0.openTime < $1.openTime } : filtered.sorted { $0.openTime > $1.openTime }
        let limited = query.limit.map { Array(sorted.prefix($0)) } ?? sorted
        return makeSnapshot(candles: limited)
    }

    public static func makeSnapshot(candles: [KLCandlePoint]) -> CandlePatternIndicatorSnapshot {
        makeSnapshot(candles: candles, requiredIndicatorIDs: ["KX-IN-01-MA", "KX-IN-06-成交量分析", "KX-IN-15-ATR", "KX-IN-29-支撑阻力"])
    }

    public static func makeSnapshot(candles: [KLCandlePoint], requiredIndicatorIDs: Set<String>) -> CandlePatternIndicatorSnapshot {
        let priceTrend = inferredTrend(from: candles)
        let recent = candles.suffix(30)
        var support = recent.map { $0.low }.min().map { [$0] } ?? []
        var resistance = recent.map { $0.high }.max().map { [$0] } ?? []
        var values: [String: Double] = [:]
        var used: [String] = []
        var missing: [String] = []

        var indicatorResults: [String: KXIndicatorResult] = [:]
        for id in requiredIndicatorIDs.sorted() {
            guard let calculator = KXUnifiedIndicatorRegistry.calculator(for: id) else {
                missing.append(id)
                continue
            }
            do {
                if id == "KX-IN-01-MA" {
                    var hasAnyMA = false
                    for period in [5, 10, 20, 60] {
                        let result = try calculator.calculate(for: candles, parameters: KXIndicatorParameters(values: ["period": Double(period)]))
                        indicatorResults["\(id).\(period)"] = result
                        if let latest = result.values.reversed().compactMap({ $0 }).first {
                            values["\(id).\(period)"] = latest
                            if period == 20 { values[id] = latest }
                            hasAnyMA = true
                        }
                    }
                    if hasAnyMA { used.append(id) } else { missing.append(id) }
                } else {
                    let result = try calculator.calculate(for: candles, parameters: defaultParameters(for: id))
                    indicatorResults[id] = result
                    if let latest = result.values.reversed().compactMap({ $0 }).first {
                        values[id] = latest
                    }
                    used.append(id)
                }
            } catch {
                missing.append(id)
            }
        }

        if requiredIndicatorIDs.contains("KX-IN-29-支撑阻力"), !candles.isEmpty, let srResult = indicatorResults["KX-IN-29-支撑阻力"], let lastClose = candles.last?.close {
            // 支撑阻力指标的历史 swing high/low 多点进入识别上下文：低于/等于当前收盘价视为支撑，高于当前收盘价视为阻力。
            let lastCloseDouble = NSDecimalNumber(decimal: lastClose).doubleValue
            var indicatorSupports: [Decimal] = []
            var indicatorResistances: [Decimal] = []
            for level in srResult.values.compactMap({ $0 }).suffix(20) {
                let levelDecimal = Decimal(level)
                if level <= lastCloseDouble { indicatorSupports.append(levelDecimal) } else { indicatorResistances.append(levelDecimal) }
            }
            support = Array(Set(support + indicatorSupports)).sorted()
            resistance = Array(Set(resistance + indicatorResistances)).sorted()
        }

        let atrValue: Decimal?
        if let atr = values["KX-IN-15-ATR"] {
            atrValue = Decimal(atr)
        } else {
            atrValue = inferredATR(from: candles)
        }

        let adxValue = values["KX-IN-03-ADX"].map { Decimal($0) }
        let trend = trendFromIndicator(indicatorValues: values, adx: adxValue, candles: candles) ?? priceTrend
        let volumeSignal = values["KX-IN-06-成交量分析"].map(volumeSignalFromIndicatorRatio(_:)) ?? inferredVolumeSignal(from: candles)

        return CandlePatternIndicatorSnapshot(
            trend: trend,
            supportLevels: support,
            resistanceLevels: resistance,
            volumeSignal: volumeSignal,
            atr: atrValue,
            indicatorValues: values,
            usedIndicatorIDs: used,
            missingIndicatorIDs: missing
        )
    }

    public static func recognize(candles points: [KLCandlePoint], snapshot: CandlePatternIndicatorSnapshot? = nil) -> [PatternMatchResult] {
        recognize(candles: points, snapshot: snapshot, allowedPatternIDs: nil)
    }

    public static func recognize(candles points: [KLCandlePoint], snapshot: CandlePatternIndicatorSnapshot? = nil, allowedPatternIDs: Set<String>?) -> [PatternMatchResult] {
        guard allowedPatternIDs?.isEmpty != true else { return [] }
        let context = snapshot?.recognitionContext ?? makeSnapshot(candles: points).recognitionContext
        return CandlePatternRecognizer.shared.recognizeAll(candles: candles(from: points), context: context, allowedPatternIDs: allowedPatternIDs)
    }

    private static func inferredTrend(from candles: [KLCandlePoint]) -> String? {
        let closes = candles.suffix(12).map { NSDecimalNumber(decimal: $0.close).doubleValue }
        guard let first = closes.first, let last = closes.last, closes.count >= 4 else { return nil }
        let change = (last - first) / max(abs(first), 0.00000001)
        if change > 0.015 { return "up" }
        if change < -0.015 { return "down" }
        return "sideways"
    }

    private static func inferredVolumeSignal(from candles: [KLCandlePoint]) -> CandlePatternVolumeSignal {
        let vols = candles.suffix(20).map { NSDecimalNumber(decimal: $0.volume).doubleValue }
        guard let last = vols.last, vols.count >= 5 else { return .unknown }
        let avg = vols.dropLast().reduce(0, +) / Double(max(vols.count - 1, 1))
        guard avg > 0 else { return .unknown }
        return volumeSignalFromIndicatorRatio(last / avg)
    }

    private static func volumeSignalFromIndicatorRatio(_ ratio: Double) -> CandlePatternVolumeSignal {
        // 形态确认只需要量能分层：>=1.5x 均量为放量，>=2.0x 为显著放量。
        if ratio >= 2.0 { return .spike }
        if ratio >= 1.5 { return .high }
        if ratio <= 0.5 { return .low }
        return .normal
    }

    private static func trendFromIndicator(indicatorValues: [String: Double], adx: Decimal?, candles: [KLCandlePoint]) -> String? {
        guard let lastClose = candles.last?.close else { return nil }
        let close = NSDecimalNumber(decimal: lastClose).doubleValue
        let ma20 = indicatorValues["KX-IN-01-MA.20"] ?? indicatorValues["KX-IN-01-MA"]
        let ma60 = indicatorValues["KX-IN-01-MA.60"]
        guard let base = ma20, base > 0 else { return nil }
        if let adx, NSDecimalNumber(decimal: adx).doubleValue < 15 { return "sideways" }
        if let ma60 {
            if close > base && base > ma60 { return "up" }
            if close < base && base < ma60 { return "down" }
        }
        let diff = (close - base) / base
        if diff > 0.002 { return "up" }
        if diff < -0.002 { return "down" }
        return "sideways"
    }

    private static func inferredATR(from candles: [KLCandlePoint]) -> Decimal? {
        guard candles.count >= 2 else { return nil }
        let recent = candles.suffix(15)
        var ranges: [Double] = []
        for idx in recent.indices.dropFirst() {
            let current = recent[idx]
            let previous = recent[recent.index(before: idx)]
            let high = NSDecimalNumber(decimal: current.high).doubleValue
            let low = NSDecimalNumber(decimal: current.low).doubleValue
            let prevClose = NSDecimalNumber(decimal: previous.close).doubleValue
            ranges.append(max(high - low, abs(high - prevClose), abs(low - prevClose)))
        }
        guard !ranges.isEmpty else { return nil }
        return Decimal(ranges.reduce(0, +) / Double(ranges.count))
    }

    private static func defaultParameters(for indicatorID: String) -> KXIndicatorParameters {
        var params = KXIndicatorParameters()
        switch indicatorID {
        case "KX-IN-01-MA": params.values["period"] = 20
        case "KX-IN-03-ADX": params.values["period"] = 14
        case "KX-IN-15-ATR": params.values["period"] = 14
        default: break
        }
        return params
    }
}

public enum KPAD01ExternalContextAdapterSkeleton: KPFileSkeletonProtocol {
    public static let descriptor = KPModuleRegistry.descriptor(id: "KP-AD-01") ?? KPFileDescriptor(id: "KP-AD-01", fileName: "KP-AD-01_外部上下文适配器.swift", layer: .adapter, relativePath: "接口适配层/KP-AD-01_外部上下文适配器.swift", duty: "K线模块Candle输入适配和指标上下文桥接")
    public static func skeletonStatus() -> KPHealthCheckItem { KPHealthCheckItem(name: descriptor.id, passed: true, message: "K线数据通过接口转换为独立模块Candle") }
}


public extension CandlePatternIndicatorBridge {
    static func makePatternCandles(from points: [KLCandlePoint]) -> [Candle] { candles(from: points) }
}

public extension CandlePatternIndicatorSnapshot {
    var ma20: Decimal? { indicatorValues["KX-IN-01-MA"].map { Decimal($0) } }
    var adx: Decimal? { indicatorValues["KX-IN-03-ADX"].map { Decimal($0) } }
    var nearestSupport: Decimal? { supportLevels.last }
    var nearestResistance: Decimal? { resistanceLevels.last }
}
