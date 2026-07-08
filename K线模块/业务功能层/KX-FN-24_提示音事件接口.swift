//
//  KX-FN-24_提示音事件接口.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：把形态、价格突破、成交量异常转换为提示音事件描述
//  禁止事项：禁止播放实现、禁止阻塞 UI
//

import Foundation


// MARK: - 提示音事件接口

public enum KXFN224Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KL-IF-05",
        fileName: "KL-IF-05_提示音事件接口.swift",
        layer: .interface,
        relativePath: "接口层/KL-IF-05_提示音事件接口.swift",
        duty: "把形态、价格突破、成交量异常转换为提示音事件描述"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "提示音事件接口", passed: true, message: "已实现纯事件描述转换：形态、价格突破、成交量异常 -> KLAlertEventDescriptor/DTO")
    }

    public static func placeholder() {
        // 本文件只生成提示音事件描述；不播放声音、不请求网络、不读写数据库、不绘制 UI。
    }
}

// MARK: - 事件 DTO 与输入模型

public extension KXFN224Skeleton {
    enum EventSource: String, Codable, Sendable, CaseIterable {
        case marker
        case patternSignal
        case priceBreakout
        case volumeAnomaly
    }

    enum EventPriority: Int, Codable, Sendable, Comparable, CaseIterable {
        case low = 10
        case normal = 20
        case high = 30
        case critical = 40

        public static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    struct EventSwitches: Codable, Equatable, Sendable {
        public let enabled: Bool
        public let muted: Bool
        public let allowMarkers: Bool
        public let allowPatternSignals: Bool
        public let allowPriceBreakouts: Bool
        public let allowVolumeAnomalies: Bool
        public let minimumPriority: EventPriority

        public init(
            enabled: Bool = true,
            muted: Bool = false,
            allowMarkers: Bool = true,
            allowPatternSignals: Bool = true,
            allowPriceBreakouts: Bool = true,
            allowVolumeAnomalies: Bool = true,
            minimumPriority: EventPriority = .low
        ) {
            self.enabled = enabled
            self.muted = muted
            self.allowMarkers = allowMarkers
            self.allowPatternSignals = allowPatternSignals
            self.allowPriceBreakouts = allowPriceBreakouts
            self.allowVolumeAnomalies = allowVolumeAnomalies
            self.minimumPriority = minimumPriority
        }
    }

    struct EventDTO: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let dedupeKey: String
        public let source: EventSource
        public let priority: EventPriority
        public let enabled: Bool
        public let muted: Bool
        public let descriptor: KLAlertEventDescriptor

        public init(
            id: String,
            dedupeKey: String,
            source: EventSource,
            priority: EventPriority,
            enabled: Bool,
            muted: Bool,
            descriptor: KLAlertEventDescriptor
        ) {
            self.id = id
            self.dedupeKey = dedupeKey
            self.source = source
            self.priority = priority
            self.enabled = enabled
            self.muted = muted
            self.descriptor = descriptor
        }
    }

    struct PatternSignalInput: Codable, Equatable, Sendable {
        public let symbol: KXSymbol
        public let timeframe: KXTimeframe?
        public let signalName: String
        public let direction: KLAlertDirection
        public let severity: KLMarkerSeverity
        public let confidence: Double?
        public let price: KXDecimal?
        public let occurredAt: Date
        public let ruleID: String?
        public let enabled: Bool
        public let muted: Bool
        public let sound: KLSoundDescriptor?
        public let note: String?

        public init(
            symbol: KXSymbol,
            timeframe: KXTimeframe? = nil,
            signalName: String,
            direction: KLAlertDirection = .any,
            severity: KLMarkerSeverity = .medium,
            confidence: Double? = nil,
            price: KXDecimal? = nil,
            occurredAt: Date = Date(),
            ruleID: String? = nil,
            enabled: Bool = true,
            muted: Bool = false,
            sound: KLSoundDescriptor? = nil,
            note: String? = nil
        ) {
            self.symbol = symbol
            self.timeframe = timeframe
            self.signalName = signalName
            self.direction = direction
            self.severity = severity
            self.confidence = confidence
            self.price = price
            self.occurredAt = occurredAt
            self.ruleID = ruleID
            self.enabled = enabled
            self.muted = muted
            self.sound = sound
            self.note = note
        }
    }

    struct PriceBreakoutInput: Codable, Equatable, Sendable {
        public let symbol: KXSymbol
        public let timeframe: KXTimeframe?
        public let direction: KLAlertDirection
        public let currentPrice: KXDecimal
        public let triggerPrice: KXDecimal
        public let previousPrice: KXDecimal?
        public let occurredAt: Date
        public let ruleID: String?
        public let enabled: Bool
        public let muted: Bool
        public let sound: KLSoundDescriptor?
        public let note: String?

        public init(
            symbol: KXSymbol,
            timeframe: KXTimeframe? = nil,
            direction: KLAlertDirection,
            currentPrice: KXDecimal,
            triggerPrice: KXDecimal,
            previousPrice: KXDecimal? = nil,
            occurredAt: Date = Date(),
            ruleID: String? = nil,
            enabled: Bool = true,
            muted: Bool = false,
            sound: KLSoundDescriptor? = nil,
            note: String? = nil
        ) {
            self.symbol = symbol
            self.timeframe = timeframe
            self.direction = direction
            self.currentPrice = currentPrice
            self.triggerPrice = triggerPrice
            self.previousPrice = previousPrice
            self.occurredAt = occurredAt
            self.ruleID = ruleID
            self.enabled = enabled
            self.muted = muted
            self.sound = sound
            self.note = note
        }
    }

    struct VolumeAnomalyInput: Codable, Equatable, Sendable {
        public let symbol: KXSymbol
        public let timeframe: KXTimeframe?
        public let currentVolume: KXDecimal
        public let baselineVolume: KXDecimal?
        public let ratio: Double?
        public let severity: KLMarkerSeverity
        public let occurredAt: Date
        public let ruleID: String?
        public let enabled: Bool
        public let muted: Bool
        public let sound: KLSoundDescriptor?
        public let note: String?

        public init(
            symbol: KXSymbol,
            timeframe: KXTimeframe? = nil,
            currentVolume: KXDecimal,
            baselineVolume: KXDecimal? = nil,
            ratio: Double? = nil,
            severity: KLMarkerSeverity = .medium,
            occurredAt: Date = Date(),
            ruleID: String? = nil,
            enabled: Bool = true,
            muted: Bool = false,
            sound: KLSoundDescriptor? = nil,
            note: String? = nil
        ) {
            self.symbol = symbol
            self.timeframe = timeframe
            self.currentVolume = currentVolume
            self.baselineVolume = baselineVolume
            self.ratio = ratio
            self.severity = severity
            self.occurredAt = occurredAt
            self.ruleID = ruleID
            self.enabled = enabled
            self.muted = muted
            self.sound = sound
            self.note = note
        }
    }
}

// MARK: - 纯转换接口

public extension KXFN224Skeleton {
    static func makeEvent(from marker: KLMarkerDescriptor, switches: EventSwitches = EventSwitches()) -> EventDTO? {
        let source: EventSource = marker.kind == .pattern || marker.kind == .signal ? .patternSignal : .marker
        let priority = priority(from: marker.severity)
        let sourceAllowed = source == .patternSignal ? switches.allowPatternSignals : switches.allowMarkers
        guard switches.enabled, sourceAllowed, priority >= switches.minimumPriority else { return nil }

        let muted = switches.muted
        let eventID = stableID(parts: ["marker", marker.id, marker.symbol, marker.timeframe.rawValue])
        let dedupeKey = stableID(parts: ["marker", marker.id, marker.symbol, marker.timeframe.rawValue])
        let title = marker.title.isEmpty ? "K线标记提醒" : marker.title
        let message = marker.message ?? "\(marker.symbol) \(marker.timeframe.rawValue) 出现\(title)"
        let descriptor = KLAlertEventDescriptor(
            id: eventID,
            ruleID: nil,
            symbol: marker.symbol,
            timeframe: marker.timeframe,
            kind: source == .patternSignal ? .patternSignal : .custom,
            title: title,
            message: message,
            occurredAt: marker.createdAt,
            deliveryState: muted ? .muted : .pending,
            sound: nil
        )
        return EventDTO(id: eventID, dedupeKey: dedupeKey, source: source, priority: priority, enabled: true, muted: muted, descriptor: descriptor)
    }

    static func makeEvent(from input: PatternSignalInput, switches: EventSwitches = EventSwitches()) -> EventDTO? {
        let priority = priority(from: input.severity)
        guard switches.enabled, switches.allowPatternSignals, input.enabled, priority >= switches.minimumPriority else { return nil }

        let muted = switches.muted || input.muted
        let dedupeKey = stableID(parts: ["pattern", input.symbol, timeframeText(input.timeframe), input.signalName, directionText(input.direction)])
        let eventID = stableID(parts: [dedupeKey, timestampKey(input.occurredAt)])
        let title = "形态信号：\(input.signalName)"
        let message = patternMessage(input)
        let descriptor = KLAlertEventDescriptor(
            id: eventID,
            ruleID: input.ruleID,
            symbol: input.symbol,
            timeframe: input.timeframe,
            kind: .patternSignal,
            title: title,
            message: message,
            occurredAt: input.occurredAt,
            deliveryState: muted ? .muted : .pending,
            sound: muted ? nil : input.sound
        )
        return EventDTO(id: eventID, dedupeKey: dedupeKey, source: .patternSignal, priority: priority, enabled: true, muted: muted, descriptor: descriptor)
    }

    static func makeEvent(from input: PriceBreakoutInput, switches: EventSwitches = EventSwitches()) -> EventDTO? {
        let priority = priceBreakoutPriority(input)
        guard switches.enabled, switches.allowPriceBreakouts, input.enabled, priority >= switches.minimumPriority else { return nil }

        let muted = switches.muted || input.muted
        let dedupeKey = stableID(parts: ["price", input.symbol, timeframeText(input.timeframe), directionText(input.direction), decimalText(input.triggerPrice)])
        let eventID = stableID(parts: [dedupeKey, timestampKey(input.occurredAt)])
        let title = "价格突破：\(directionTitle(input.direction))"
        let message = priceBreakoutMessage(input)
        let descriptor = KLAlertEventDescriptor(
            id: eventID,
            ruleID: input.ruleID,
            symbol: input.symbol,
            timeframe: input.timeframe,
            kind: .priceBreakout,
            title: title,
            message: message,
            occurredAt: input.occurredAt,
            deliveryState: muted ? .muted : .pending,
            sound: muted ? nil : input.sound
        )
        return EventDTO(id: eventID, dedupeKey: dedupeKey, source: .priceBreakout, priority: priority, enabled: true, muted: muted, descriptor: descriptor)
    }

    static func makeEvent(from input: VolumeAnomalyInput, switches: EventSwitches = EventSwitches()) -> EventDTO? {
        let priority = volumePriority(input)
        guard switches.enabled, switches.allowVolumeAnomalies, input.enabled, priority >= switches.minimumPriority else { return nil }

        let muted = switches.muted || input.muted
        let dedupeKey = stableID(parts: ["volume", input.symbol, timeframeText(input.timeframe), severityText(input.severity)])
        let eventID = stableID(parts: [dedupeKey, timestampKey(input.occurredAt)])
        let title = "成交量异常"
        let message = volumeAnomalyMessage(input)
        let descriptor = KLAlertEventDescriptor(
            id: eventID,
            ruleID: input.ruleID,
            symbol: input.symbol,
            timeframe: input.timeframe,
            kind: .volumeAnomaly,
            title: title,
            message: message,
            occurredAt: input.occurredAt,
            deliveryState: muted ? .muted : .pending,
            sound: muted ? nil : input.sound
        )
        return EventDTO(id: eventID, dedupeKey: dedupeKey, source: .volumeAnomaly, priority: priority, enabled: true, muted: muted, descriptor: descriptor)
    }

    static func makeEvents(
        markers: [KLMarkerDescriptor] = [],
        patternSignals: [PatternSignalInput] = [],
        priceBreakouts: [PriceBreakoutInput] = [],
        volumeAnomalies: [VolumeAnomalyInput] = [],
        switches: EventSwitches = EventSwitches()
    ) -> [EventDTO] {
        let markerEvents = markers.compactMap { makeEvent(from: $0, switches: switches) }
        let patternEvents = patternSignals.compactMap { makeEvent(from: $0, switches: switches) }
        let priceEvents = priceBreakouts.compactMap { makeEvent(from: $0, switches: switches) }
        let volumeEvents = volumeAnomalies.compactMap { makeEvent(from: $0, switches: switches) }
        return deduplicated(markerEvents + patternEvents + priceEvents + volumeEvents)
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.descriptor.occurredAt < rhs.descriptor.occurredAt
            }
    }

    static func makeAlertDescriptors(
        markers: [KLMarkerDescriptor] = [],
        patternSignals: [PatternSignalInput] = [],
        priceBreakouts: [PriceBreakoutInput] = [],
        volumeAnomalies: [VolumeAnomalyInput] = [],
        switches: EventSwitches = EventSwitches()
    ) -> [KLAlertEventDescriptor] {
        makeEvents(
            markers: markers,
            patternSignals: patternSignals,
            priceBreakouts: priceBreakouts,
            volumeAnomalies: volumeAnomalies,
            switches: switches
        ).map(\.descriptor)
    }
}

// MARK: - 内部纯函数

private extension KXFN224Skeleton {
    static func deduplicated(_ events: [EventDTO]) -> [EventDTO] {
        var seen = Set<String>()
        var result: [EventDTO] = []
        for event in events {
            guard !seen.contains(event.dedupeKey) else { continue }
            seen.insert(event.dedupeKey)
            result.append(event)
        }
        return result
    }

    static func priority(from severity: KLMarkerSeverity) -> EventPriority {
        switch severity {
        case .info, .low:
            return .low
        case .medium:
            return .normal
        case .high:
            return .high
        case .critical:
            return .critical
        }
    }

    static func priceBreakoutPriority(_ input: PriceBreakoutInput) -> EventPriority {
        guard input.triggerPrice != 0 else { return .normal }
        let distance = abs(decimalDouble(input.currentPrice - input.triggerPrice) / decimalDouble(input.triggerPrice))
        if distance >= 0.05 { return .critical }
        if distance >= 0.02 { return .high }
        return .normal
    }

    static func volumePriority(_ input: VolumeAnomalyInput) -> EventPriority {
        if let ratio = input.ratio {
            if ratio >= 5 { return .critical }
            if ratio >= 3 { return .high }
            if ratio >= 1.5 { return .normal }
        }
        return priority(from: input.severity)
    }

    static func patternMessage(_ input: PatternSignalInput) -> String {
        var parts = ["\(input.symbol) \(timeframeText(input.timeframe)) 出现\(input.signalName)"]
        if input.direction != .any { parts.append("方向：\(directionTitle(input.direction))") }
        if let price = input.price { parts.append("价格：\(decimalText(price))") }
        if let confidence = input.confidence { parts.append("置信度：\(percentText(confidence))") }
        if let note = input.note, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: "，")
    }

    static func priceBreakoutMessage(_ input: PriceBreakoutInput) -> String {
        var parts = ["\(input.symbol) \(timeframeText(input.timeframe)) \(directionTitle(input.direction))"]
        parts.append("触发价：\(decimalText(input.triggerPrice))")
        parts.append("现价：\(decimalText(input.currentPrice))")
        if let previousPrice = input.previousPrice { parts.append("前值：\(decimalText(previousPrice))") }
        if let note = input.note, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: "，")
    }

    static func volumeAnomalyMessage(_ input: VolumeAnomalyInput) -> String {
        var parts = ["\(input.symbol) \(timeframeText(input.timeframe)) 成交量异常"]
        parts.append("当前量：\(decimalText(input.currentVolume))")
        if let baseline = input.baselineVolume { parts.append("基准量：\(decimalText(baseline))") }
        if let ratio = input.ratio { parts.append("放大倍数：\(ratioText(ratio))") }
        if let note = input.note, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: "，")
    }

    static func stableID(parts: [String]) -> String {
        let raw = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.joined(separator: "|")
        let hash = raw.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar.value)) &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    static func timestampKey(_ date: Date) -> String {
        String(Int(date.timeIntervalSince1970))
    }

    static func timeframeText(_ timeframe: KXTimeframe?) -> String {
        timeframe?.rawValue ?? "全周期"
    }

    static func directionText(_ direction: KLAlertDirection) -> String {
        direction.rawValue
    }

    static func directionTitle(_ direction: KLAlertDirection) -> String {
        switch direction {
        case .above:
            return "上破"
        case .below:
            return "下破"
        case .crossUp:
            return "向上穿越"
        case .crossDown:
            return "向下穿越"
        case .any:
            return "触发"
        }
    }

    static func severityText(_ severity: KLMarkerSeverity) -> String {
        severity.rawValue
    }

    static func decimalText(_ value: KXDecimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    static func decimalDouble(_ value: KXDecimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    static func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func ratioText(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return "\(rounded)x"
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN24Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-24", fileName: "KX-FN-24_提示音事件接口.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-24_提示音事件接口.swift", duty: "提示音事件接口定义"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("提示音事件接口骨架校验通过")
        return KXHealthCheckItem(name: "提示音事件接口", passed: true, message: "已实现提示音事件接口定义")
    }
}
