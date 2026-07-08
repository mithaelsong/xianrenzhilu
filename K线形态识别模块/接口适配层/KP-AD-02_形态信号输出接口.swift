// KP-AD-02_形态信号输出接口.swift
// 职责：把形态识别结果转换为 K线模块可消费的标准标记信号。

import Foundation

public enum KPAD02PatternDirection: String, Codable, Sendable, CaseIterable { case bullish, bearish, neutral, continuation, reversal, unknown }
public enum KPAD02SignalConfidenceBand: String, Codable, Sendable, CaseIterable {
    case veryLow, low, medium, high, veryHigh
    public static func map(confidence: Double) -> KPAD02SignalConfidenceBand { let v = KPAD02ValueNormalizer.clamp01(confidence); if v >= 0.88 { return .veryHigh }; if v >= 0.72 { return .high }; if v >= 0.55 { return .medium }; if v >= 0.35 { return .low }; return .veryLow }
}

public struct KPAD02PatternSignalInput: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let symbol: String
    public let timeframe: KXTimeframe
    public let patternID: String
    public let patternName: String
    public let direction: KPAD02PatternDirection
    public let confidence: Double
    public let strength: Double?
    public let candleTimes: [Date]
    public let anchorTime: Date
    public let anchorPrice: Decimal?
    public let message: String?
    public let shouldTriggerSound: Bool
    public let soundEventID: String?

    public init(id: String? = nil, symbol: String, timeframe: KXTimeframe, patternID: String, patternName: String, direction: KPAD02PatternDirection = .unknown, confidence: Double, strength: Double? = nil, candleTimes: [Date] = [], anchorTime: Date, anchorPrice: Decimal? = nil, message: String? = nil, shouldTriggerSound: Bool = false, soundEventID: String? = nil) {
        self.id = id; self.symbol = symbol; self.timeframe = timeframe; self.patternID = patternID; self.patternName = patternName; self.direction = direction; self.confidence = KPAD02ValueNormalizer.clamp01(confidence); self.strength = strength.map(KPAD02ValueNormalizer.clamp01); self.candleTimes = candleTimes; self.anchorTime = anchorTime; self.anchorPrice = anchorPrice; self.message = message; self.shouldTriggerSound = shouldTriggerSound; self.soundEventID = soundEventID
    }
}

public struct KPAD02PatternSignalDedupKey: Codable, Hashable, Sendable, CustomStringConvertible {
    public let symbol: String
    public let timeframeRawValue: String
    public let patternID: String
    public let anchorTime: Date
    public init(signal: KPAD02PatternSignalInput) { self.symbol = signal.symbol; self.timeframeRawValue = signal.timeframe.rawValue; self.patternID = signal.patternID; self.anchorTime = signal.anchorTime }
    public var description: String { "\(symbol):\(timeframeRawValue):\(patternID):\(Int(anchorTime.timeIntervalSince1970))" }
}

public struct KPAD02PatternSignalConversionResult: Codable, Equatable, Sendable {
    public let acceptedSignals: [KPAD02PatternSignalInput]
    public let markers: [KLMarkerDescriptor]
    public let rejectedCount: Int
    public let duplicateCount: Int
    public init(acceptedSignals: [KPAD02PatternSignalInput], markers: [KLMarkerDescriptor], rejectedCount: Int, duplicateCount: Int) { self.acceptedSignals = acceptedSignals; self.markers = markers; self.rejectedCount = rejectedCount; self.duplicateCount = duplicateCount }
}

public struct KPAD02PatternSignalConverter: Sendable {
    public let minimumConfidence: Double
    public let includeVeryLowConfidence: Bool
    public init(minimumConfidence: Double = 0.55, includeVeryLowConfidence: Bool = false) { self.minimumConfidence = KPAD02ValueNormalizer.clamp01(minimumConfidence); self.includeVeryLowConfidence = includeVeryLowConfidence }
    public func convert(_ signal: KPAD02PatternSignalInput, createdAt: Date = Date()) -> KLMarkerDescriptor? {
        guard shouldAccept(signal) else { return nil }
        let severity = KPAD02SeverityMapper.map(confidence: signal.confidence, strength: signal.strength)
        let style = KLMarkerStyleDescriptor(colorHex: KPAD02StyleMapper.colorHex(direction: signal.direction, severity: severity), iconName: KPAD02StyleMapper.iconName(direction: signal.direction), lineWidth: KPAD02StyleMapper.lineWidth(severity: severity), opacity: max(0.35, signal.confidence))
        return KLMarkerDescriptor(id: signal.id ?? "KP:\(KPAD02PatternSignalDedupKey(signal: signal).description)", symbol: signal.symbol, timeframe: signal.timeframe, kind: .pattern, source: .patternRecognition, severity: severity, title: "\(signal.timeframe.rawValue) \(signal.patternName)｜\(KPAD02DirectionTextMapper.displayName(signal.direction))", message: signal.message ?? "置信度：\(KPAD02PercentFormatter.percentText(signal.confidence))", coordinate: KLChartCoordinate(time: signal.anchorTime, index: nil, price: signal.anchorPrice, point: nil), style: style, createdAt: createdAt)
    }
    public func convert(_ signals: [KPAD02PatternSignalInput], deduplicate: Bool = true, createdAt: Date = Date()) -> KPAD02PatternSignalConversionResult {
        let filtered = signals.filter(shouldAccept)
        let selected = deduplicate ? deduplicateKeepingHighestConfidence(filtered) : (filtered, 0)
        return KPAD02PatternSignalConversionResult(acceptedSignals: selected.0, markers: selected.0.compactMap { convert($0, createdAt: createdAt) }, rejectedCount: signals.count - filtered.count, duplicateCount: selected.1)
    }
    private func shouldAccept(_ signal: KPAD02PatternSignalInput) -> Bool { signal.confidence >= minimumConfidence && (includeVeryLowConfidence || KPAD02SignalConfidenceBand.map(confidence: signal.confidence) != .veryLow) }
    private func deduplicateKeepingHighestConfidence(_ signals: [KPAD02PatternSignalInput]) -> ([KPAD02PatternSignalInput], Int) { var best: [KPAD02PatternSignalDedupKey: KPAD02PatternSignalInput] = [:]; var order: [KPAD02PatternSignalDedupKey] = []; var dup = 0; for s in signals { let k = KPAD02PatternSignalDedupKey(signal: s); if let old = best[k] { dup += 1; if s.confidence > old.confidence { best[k] = s } } else { best[k] = s; order.append(k) } }; return (order.compactMap { best[$0] }, dup) }
}

public enum KPAD02SeverityMapper { public static func severity(confidence: Double, strength: Double? = nil) -> KLMarkerSeverity { map(confidence: confidence, strength: strength) }; public static func map(confidence: Double, strength: Double? = nil) -> KLMarkerSeverity { let v = max(KPAD02ValueNormalizer.clamp01(confidence), strength.map(KPAD02ValueNormalizer.clamp01) ?? 0); if v >= 0.88 { return .critical }; if v >= 0.72 { return .high }; if v >= 0.55 { return .medium }; if v >= 0.35 { return .low }; return .info } }
public enum KPAD02ValueNormalizer { public static func clamp01(_ value: Double) -> Double { min(max(value, 0), 1) } }
public enum KPAD02StyleMapper { public static func colorHex(direction: KPAD02PatternDirection, severity: KLMarkerSeverity) -> String { switch direction { case .bullish: return "#22C55E"; case .bearish: return "#EF4444"; case .continuation: return "#38BDF8"; case .reversal: return "#F59E0B"; case .neutral, .unknown: return severity == .critical ? "#F97316" : "#A3A3A3" } }; public static func iconName(direction: KPAD02PatternDirection) -> String? { switch direction { case .bullish: return "arrow.up.circle.fill"; case .bearish: return "arrow.down.circle.fill"; case .continuation: return "arrow.right.circle.fill"; case .reversal: return "arrow.triangle.2.circlepath.circle.fill"; default: return "circle.fill" } }; public static func lineWidth(severity: KLMarkerSeverity) -> Double { severity == .critical || severity == .high ? 2.0 : 1.0 } }
public enum KPAD02DirectionTextMapper { public static func displayName(_ direction: KPAD02PatternDirection) -> String { switch direction { case .bullish: return "看涨"; case .bearish: return "看跌"; case .continuation: return "延续"; case .reversal: return "反转"; case .neutral: return "中性"; case .unknown: return "未知" } } }
public enum KPAD02ConfidenceTextMapper { public static func displayName(_ band: KPAD02SignalConfidenceBand) -> String { switch band { case .veryHigh: return "极高"; case .high: return "高"; case .medium: return "中"; case .low: return "低"; case .veryLow: return "极低" } } }
public enum KPAD02PercentFormatter { public static func percentText(_ value: Double) -> String { String(format: "%.1f%%", KPAD02ValueNormalizer.clamp01(value) * 100) } }

public enum KPAD02PatternResultSignalBridge {
    public static func makeSignals(from results: [PatternMatchResult], symbol: String, timeframe: KXTimeframe, snapshot: CandlePatternIndicatorSnapshot? = nil) -> [KPAD02PatternSignalInput] {
        signals(from: results, symbol: symbol, timeframe: timeframe, snapshot: snapshot)
    }

    public static func signals(from results: [PatternMatchResult], symbol: String, timeframe: KXTimeframe, snapshot: CandlePatternIndicatorSnapshot? = nil) -> [KPAD02PatternSignalInput] {
        results.compactMap { result in signal(from: result, symbol: symbol, timeframe: timeframe, snapshot: snapshot) }
    }
    public static func signal(from result: PatternMatchResult, symbol: String, timeframe: KXTimeframe, snapshot: CandlePatternIndicatorSnapshot?) -> KPAD02PatternSignalInput? {
        guard let anchorTime = result.anchorTime else { return nil }
        let indicatorNote: String
        if let snapshot {
            let used = snapshot.usedIndicatorIDs.map(KPPatternSettingsCatalog.indicatorDisplayName(_:)).sorted().joined(separator: "、")
            let missing = snapshot.missingIndicatorIDs.map(KPPatternSettingsCatalog.indicatorDisplayName(_:)).sorted().joined(separator: "、")
            indicatorNote = "依赖指标：\(used.isEmpty ? "已使用内置K线统计" : used)\(missing.isEmpty ? "" : "；缺失/计算失败：\(missing)")"
        } else {
            indicatorNote = "依赖指标：\(KPPatternSettingsCatalog.requiredIndicatorText(for: result.pattern.id))"
        }
        let message = "\(result.pattern.description)\n周期意义：\(timeframe.rawValue) - \(KPPatternSettingsCatalog.timeframeMeaning(timeframe.rawValue))\n\(indicatorNote)"
        return KPAD02PatternSignalInput(symbol: symbol, timeframe: timeframe, patternID: result.pattern.id, patternName: result.pattern.name, direction: direction(from: result.pattern.direction), confidence: result.confidence, strength: result.confidence, candleTimes: [anchorTime], anchorTime: anchorTime, anchorPrice: result.anchorPrice, message: message, shouldTriggerSound: result.confidence >= 0.72, soundEventID: "KP-SOUND:\(result.pattern.id)")
    }
    private static func direction(from direction: PatternDirection) -> KPAD02PatternDirection { switch direction { case .bullish: return .bullish; case .bearish: return .bearish; case .continuation: return .continuation; case .reversal: return .reversal; case .neutral: return .neutral; case .unknown: return .unknown } }
}

public enum KPAD02CandlePatternPayloadBridge {
    public static func payload(from signal: KPAD02PatternSignalInput) -> KLCandlePatternMarkerPayload {
        KLCandlePatternMarkerPayload(
            patternID: signal.patternID,
            patternName: signal.patternName,
            direction: KPAD02DirectionTextMapper.displayName(signal.direction),
            confidence: signal.confidence,
            candleTimes: signal.candleTimes.isEmpty ? [signal.anchorTime] : signal.candleTimes,
            anchorTime: signal.anchorTime,
            anchorPrice: signal.anchorPrice,
            description: signal.message,
            shouldTriggerSound: signal.shouldTriggerSound,
            soundEventID: signal.soundEventID
        )
    }

    public static func payloads(from signals: [KPAD02PatternSignalInput]) -> [KLCandlePatternMarkerPayload] {
        signals.map(payload(from:))
    }
}

public enum KPAD02Skeleton: KPFileSkeletonProtocol {
    public static let descriptor = KPModuleRegistry.descriptor(id: "KP-AD-02") ?? KPFileDescriptor(id: "KP-AD-02", fileName: "KP-AD-02_形态信号输出接口.swift", layer: .adapter, relativePath: "接口适配层/KP-AD-02_形态信号输出接口.swift", duty: "形态识别结果到标准标记信号的转换")
    public static func skeletonStatus() -> KPHealthCheckItem { KPHealthCheckItem(name: descriptor.id, passed: true, message: "形态结果可转换为KLMarkerDescriptor") }
}
