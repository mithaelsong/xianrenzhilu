// KP-AD-05_形态结果标记桥.swift
// 职责：把识别引擎输出的 PatternMatchResult 映射为图表标记信号输入。

import Foundation

public enum KPAD05PatternResultMarkerBridge {
    public static func markerSignals(from results: [PatternMatchResult], symbol: String, timeframe: KXTimeframe, snapshot: CandlePatternIndicatorSnapshot? = nil) -> [KPAD04PatternSignalInput] {
        KPAD02PatternResultSignalBridge.signals(from: results, symbol: symbol, timeframe: timeframe, snapshot: snapshot)
    }

    public static func makeSignals(from results: [PatternMatchResult], symbol: String, timeframe: KXTimeframe, snapshot: CandlePatternIndicatorSnapshot? = nil) -> [KPAD04PatternSignalInput] {
        markerSignals(from: results, symbol: symbol, timeframe: timeframe, snapshot: snapshot)
    }

    public static func payloads(from results: [PatternMatchResult], symbol: String, timeframe: KXTimeframe, snapshot: CandlePatternIndicatorSnapshot? = nil) -> [KLCandlePatternMarkerPayload] {
        KPAD02CandlePatternPayloadBridge.payloads(from: markerSignals(from: results, symbol: symbol, timeframe: timeframe, snapshot: snapshot))
    }
    public static func markers(from results: [PatternMatchResult], symbol: String, timeframe: KXTimeframe, snapshot: CandlePatternIndicatorSnapshot? = nil, createdAt: Date = Date()) -> [KLMarkerDescriptor] {
        let signals = markerSignals(from: results, symbol: symbol, timeframe: timeframe, snapshot: snapshot)
        return KPAD04PatternMarkerConverter().convert(signals, createdAt: createdAt).markers
    }
}

public enum KPAD05PatternResultMarkerBridgeSkeleton: KPFileSkeletonProtocol {
    public static let descriptor = KPModuleRegistry.descriptor(id: "KP-AD-05") ?? KPFileDescriptor(id: "KP-AD-05", fileName: "KP-AD-05_形态结果标记桥.swift", layer: .adapter, relativePath: "接口适配层/KP-AD-05_形态结果标记桥.swift", duty: "识别结果到图表标记输入的桥接")
    public static func skeletonStatus() -> KPHealthCheckItem { KPHealthCheckItem(name: descriptor.id, passed: true, message: "识别结果可桥接为图表标记") }
}
