// KP-AD-04_图表标记输出接口.swift
// 职责：形态信号到K线图表标记的转换和管理。

import Foundation

public typealias KPAD04PatternDirection = KPAD02PatternDirection
public typealias KPAD04ConfidenceBand = KPAD02SignalConfidenceBand
public typealias KPAD04PatternSignalInput = KPAD02PatternSignalInput
public typealias KPAD04PatternSignalDedupKey = KPAD02PatternSignalDedupKey
public typealias KPAD04ConversionResult = KPAD02PatternSignalConversionResult

public enum KPAD04MarkerSortOrder: String, Codable, Sendable, CaseIterable { case timeAscending, timeDescending, confidenceDescending }

public struct KPAD04ConversionPolicy: Codable, Equatable, Sendable {
    public let minimumConfidence: Double
    public let includeVeryLowConfidence: Bool
    public let sortOrder: KPAD04MarkerSortOrder
    public init(minimumConfidence: Double = 0.55, includeVeryLowConfidence: Bool = false, sortOrder: KPAD04MarkerSortOrder = .timeAscending) { self.minimumConfidence = KPAD02ValueNormalizer.clamp01(minimumConfidence); self.includeVeryLowConfidence = includeVeryLowConfidence; self.sortOrder = sortOrder }
}

public struct KPAD04PatternMarkerConverter: Sendable {
    public let policy: KPAD04ConversionPolicy
    private let converter: KPAD02PatternSignalConverter
    public init(policy: KPAD04ConversionPolicy = KPAD04ConversionPolicy()) { self.policy = policy; self.converter = KPAD02PatternSignalConverter(minimumConfidence: policy.minimumConfidence, includeVeryLowConfidence: policy.includeVeryLowConfidence) }
    public func convert(_ signal: KPAD04PatternSignalInput, createdAt: Date = Date()) -> KLMarkerDescriptor? { converter.convert(signal, createdAt: createdAt) }
    public func convert(_ signals: [KPAD04PatternSignalInput], createdAt: Date = Date()) -> KPAD04ConversionResult {
        let result = converter.convert(sortSignals(signals), createdAt: createdAt)
        return result
    }
    public func dedupKey(for signal: KPAD04PatternSignalInput) -> KPAD04PatternSignalDedupKey { KPAD04PatternSignalDedupKey(signal: signal) }
    private func sortSignals(_ signals: [KPAD04PatternSignalInput]) -> [KPAD04PatternSignalInput] {
        switch policy.sortOrder {
        case .timeAscending: return signals.sorted { $0.anchorTime < $1.anchorTime }
        case .timeDescending: return signals.sorted { $0.anchorTime > $1.anchorTime }
        case .confidenceDescending: return signals.sorted { $0.confidence > $1.confidence }
        }
    }
}

public struct KPAD04ManualMarkerDraft: Codable, Equatable, Sendable {
    public let id: String?
    public let symbol: String
    public let timeframe: KXTimeframe
    public let title: String
    public let message: String?
    public let time: Date
    public let price: Decimal?
    public let severity: KLMarkerSeverity
    public init(id: String? = nil, symbol: String, timeframe: KXTimeframe, title: String, message: String? = nil, time: Date, price: Decimal? = nil, severity: KLMarkerSeverity = .info) { self.id = id; self.symbol = symbol; self.timeframe = timeframe; self.title = title; self.message = message; self.time = time; self.price = price; self.severity = severity }
}

public enum KPAD04MarkerManagementError: Error, Codable, Equatable, Sendable { case markerNotFound(id: String), invalidMarker(reason: String) }

public struct KPAD04PatternMarkerManager: Sendable {
    public private(set) var automaticMarkers: [KLMarkerDescriptor]
    public private(set) var manualMarkers: [String: KLMarkerDescriptor]
    public let converter: KPAD04PatternMarkerConverter

    public init(automaticMarkers: [KLMarkerDescriptor] = [], manualMarkers: [String: KLMarkerDescriptor] = [:], policy: KPAD04ConversionPolicy = KPAD04ConversionPolicy()) { self.automaticMarkers = automaticMarkers; self.manualMarkers = manualMarkers; self.converter = KPAD04PatternMarkerConverter(policy: policy) }
    public mutating func updateAutomaticMarkers(from signals: [KPAD04PatternSignalInput], generatedAt: Date = Date()) -> KPAD04ConversionResult { let result = converter.convert(signals, createdAt: generatedAt); automaticMarkers = result.markers; return result }
    public func convertedAutomaticMarkers(from signals: [KPAD04PatternSignalInput], generatedAt: Date = Date()) -> KPAD04ConversionResult { converter.convert(signals, createdAt: generatedAt) }
    public var allMarkers: [KLMarkerDescriptor] { automaticMarkers + manualMarkers.values.sorted { $0.createdAt < $1.createdAt } }
    public mutating func addManualMarker(_ draft: KPAD04ManualMarkerDraft) throws -> KLMarkerDescriptor { let marker = try makeManualMarker(from: draft); manualMarkers[marker.id] = marker; return marker }
    public mutating func removeManualMarker(id: String) throws { guard manualMarkers.removeValue(forKey: id) != nil else { throw KPAD04MarkerManagementError.markerNotFound(id: id) } }
    private func makeManualMarker(from draft: KPAD04ManualMarkerDraft) throws -> KLMarkerDescriptor { let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines); guard !draft.symbol.isEmpty else { throw KPAD04MarkerManagementError.invalidMarker(reason: "交易对不能为空") }; guard !title.isEmpty else { throw KPAD04MarkerManagementError.invalidMarker(reason: "标题不能为空") }; return KLMarkerDescriptor(id: draft.id ?? "KP-MANUAL:\(draft.symbol):\(draft.timeframe.rawValue):\(Int(draft.time.timeIntervalSince1970))", symbol: draft.symbol, timeframe: draft.timeframe, kind: .manual, source: .user, severity: draft.severity, title: title, message: draft.message, coordinate: KLChartCoordinate(time: draft.time, index: nil, price: draft.price, point: nil), style: nil) }
}

public enum KPAD04SeverityMapper { public static func map(confidence: Double, strength: Double? = nil) -> KLMarkerSeverity { KPAD02SeverityMapper.map(confidence: confidence, strength: strength) }; public static func rank(_ severity: KLMarkerSeverity) -> Int { switch severity { case .info: return 0; case .low: return 1; case .medium: return 2; case .high: return 3; case .critical: return 4 } } }
public enum KPAD04ValueNormalizer { public static func clamp01(_ value: Double) -> Double { KPAD02ValueNormalizer.clamp01(value) } }
public enum KPAD04StyleMapper { public static func colorHex(direction: KPAD04PatternDirection, severity: KLMarkerSeverity) -> String { KPAD02StyleMapper.colorHex(direction: direction, severity: severity) }; public static func iconName(direction: KPAD04PatternDirection) -> String? { KPAD02StyleMapper.iconName(direction: direction) }; public static func lineWidth(severity: KLMarkerSeverity) -> Double { KPAD02StyleMapper.lineWidth(severity: severity) } }
public enum KPAD04DisplayText { public static func direction(_ direction: KPAD04PatternDirection) -> String { KPAD02DirectionTextMapper.displayName(direction) }; public static func confidenceBand(_ band: KPAD04ConfidenceBand) -> String { KPAD02ConfidenceTextMapper.displayName(band) } }
public enum KPAD04PercentFormatter { public static func percentText(_ value: Double) -> String { KPAD02PercentFormatter.percentText(value) } }
public enum KPAD04TextSanitizer { public static func identifier(_ text: String) -> String { text.replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: ":", with: "-") } }
public enum KPAD04MarkerTextParser {
    public static func confidence(from message: String?) -> Double? {
        guard let message else { return nil }
        let pattern = #"([0-9]+(?:\.[0-9]+)?)%"#
        guard let range = message.range(of: pattern, options: .regularExpression) else { return nil }
        let numberText = message[range].replacingOccurrences(of: "%", with: "")
        guard let value = Double(numberText) else { return nil }
        return KPAD04ValueNormalizer.clamp01(value / 100.0)
    }
}

public enum KPAD04Skeleton: KPFileSkeletonProtocol {
    public static let descriptor = KPModuleRegistry.descriptor(id: "KP-AD-04") ?? KPFileDescriptor(id: "KP-AD-04", fileName: "KP-AD-04_图表标记输出接口.swift", layer: .adapter, relativePath: "接口适配层/KP-AD-04_图表标记输出接口.swift", duty: "图表标记输出接口与标记管理")
    public static func skeletonStatus() -> KPHealthCheckItem {
        KPHealthCheckItem(name: descriptor.id, passed: true, message: "图表标记输出接口已提供转换器、手动标记与自动标记管理")
    }
}
