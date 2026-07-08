// KP-EV-02_形态提醒事件.swift
// 职责：由形态标记生成提醒事件描述；不直接播放声音、不直接推送。

import Foundation

public enum KPEV02PatternSignalGenerator: KPFileSkeletonProtocol {
    public struct EventDTO: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let message: String
        public let priority: EventPriority
        public let createdAt: Date
        public let soundEventID: String?
        public let dedupeKey: String
        public let muted: Bool
        public let failed: Bool
        public init(id: String, title: String, message: String, priority: EventPriority, createdAt: Date = Date(), soundEventID: String? = nil, dedupeKey: String? = nil, muted: Bool = false, failed: Bool = false) {
            self.id = id; self.title = title; self.message = message; self.priority = priority; self.createdAt = createdAt; self.soundEventID = soundEventID; self.dedupeKey = dedupeKey ?? id; self.muted = muted; self.failed = failed
        }
    }
    public enum EventPriority: String, Codable, Sendable, CaseIterable { case low, normal, high, critical }
    public struct EventSwitches: Codable, Equatable, Sendable {
        public let enabled: Bool
        public let minimumSeverity: KLMarkerSeverity
        public let muted: Bool
        public let frequencyLimitSeconds: TimeInterval
        public init(enabled: Bool = true, minimumSeverity: KLMarkerSeverity = .medium, muted: Bool = false, frequencyLimitSeconds: TimeInterval = 60) { self.enabled = enabled; self.minimumSeverity = minimumSeverity; self.muted = muted; self.frequencyLimitSeconds = frequencyLimitSeconds }
    }

    public static let descriptor = KPModuleRegistry.descriptor(id: "KP-EV-02") ?? KPFileDescriptor(id: "KP-EV-02", fileName: "KP-EV-02_形态提醒事件.swift", layer: .event, relativePath: "事件层/KP-EV-02_形态提醒事件.swift", duty: "形态识别提醒事件生成")
    public static func skeletonStatus() -> KPHealthCheckItem { KPHealthCheckItem(name: descriptor.id, passed: true, message: "形态提醒事件生成器可用") }
    public static func makeEvent(from marker: KLMarkerDescriptor, switches: EventSwitches = EventSwitches()) -> EventDTO? { guard switches.enabled, rank(marker.severity) >= rank(switches.minimumSeverity) else { return nil }; return EventDTO(id: "KP-EV:\(marker.id)", title: marker.title, message: marker.message ?? "K线形态识别提醒", priority: priority(from: marker.severity), createdAt: marker.createdAt, soundEventID: "KP-SOUND:\(marker.id)", dedupeKey: "KP-EV:\(marker.symbol):\(marker.timeframe.rawValue):\((marker.coordinate.time ?? marker.createdAt).timeIntervalSince1970)", muted: switches.muted, failed: false) }
    public static func makeEvents(from markers: [KLMarkerDescriptor], switches: EventSwitches = EventSwitches()) -> [EventDTO] { markers.compactMap { makeEvent(from: $0, switches: switches) } }
    private static func rank(_ severity: KLMarkerSeverity) -> Int { switch severity { case .info: return 0; case .low: return 1; case .medium: return 2; case .high: return 3; case .critical: return 4 } }
    private static func priority(from severity: KLMarkerSeverity) -> EventPriority { switch severity { case .critical: return .critical; case .high: return .high; case .medium: return .normal; case .low, .info: return .low } }
}
