//
//  KX-UT-05_标记模型.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：标记类型、来源、位置、置信度、文本等模型骨架
//  禁止事项：禁止服务实现
//

import Foundation

@MainActor


// MARK: - K线标记模型骨架

public enum KXUT05Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UT-05",
        fileName: "KX-UT-05_K线标记模型.swift",
        layer: .marker,
        relativePath: "标记层/KX-UT-05_K线标记模型.swift",
        duty: "标记类型、来源、位置、置信度、文本等模型骨架"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "K线标记模型", passed: true, message: "已实现可用标记模型、DTO、置信度分档、样式匹配与 KLMarkerDescriptor 纯转换")
    }

    public static func placeholder() {
        // 本文件只提供标记模型与纯转换能力。
        // 不读写数据库、不绘制 UI、不请求网络、不实现标记服务。
    }
}

// MARK: - 标记枚举模型

public enum KXUT05MarkerKind: String, Codable, Sendable, CaseIterable {
    case pattern
    case manual
    case priceLevel
    case trendLine
    case note
    case signal
    case volumeAnomaly
    case syncGap

    public var publicKind: KLMarkerKind {
        switch self {
        case .pattern: return .pattern
        case .manual: return .manual
        case .priceLevel: return .priceLevel
        case .trendLine: return .trendLine
        case .note: return .note
        case .signal, .volumeAnomaly, .syncGap: return .signal
        }
    }

    public init(publicKind: KLMarkerKind) {
        switch publicKind {
        case .pattern: self = .pattern
        case .manual: self = .manual
        case .priceLevel: self = .priceLevel
        case .trendLine: self = .trendLine
        case .note: self = .note
        case .signal: self = .signal
        }
    }
}

public enum KXUT05MarkerSource: String, Codable, Sendable, CaseIterable {
    case system
    case patternRecognition
    case user
    case importSource
    case indicator
    case alert
    case unknown

    public var publicSource: KLMarkerSource {
        switch self {
        case .system, .indicator, .alert, .unknown: return .system
        case .patternRecognition: return .patternRecognition
        case .user: return .user
        case .importSource: return .importSource
        }
    }

    public init(publicSource: KLMarkerSource) {
        switch publicSource {
        case .system: self = .system
        case .patternRecognition: self = .patternRecognition
        case .user: self = .user
        case .importSource: self = .importSource
        }
    }
}

public enum KXUT05MarkerSeverity: String, Codable, Sendable, CaseIterable, Comparable {
    case info
    case low
    case medium
    case high
    case critical

    public var rank: Int {
        switch self {
        case .info: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }

    public var publicSeverity: KLMarkerSeverity {
        switch self {
        case .info: return .info
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .critical: return .critical
        }
    }

    public init(publicSeverity: KLMarkerSeverity) {
        switch publicSeverity {
        case .info: self = .info
        case .low: self = .low
        case .medium: self = .medium
        case .high: self = .high
        case .critical: self = .critical
        }
    }

    public static func < (lhs: KXUT05MarkerSeverity, rhs: KXUT05MarkerSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum KXUT05MarkerConversionSource: String, Codable, Sendable, CaseIterable {
    case klMarkerDescriptor
    case markerDTO
    case patternSignal
    case manualInput
    case importedPayload
    case unknown
}

// MARK: - 位置与坐标描述

public enum KXUT05MarkerAnchor: String, Codable, Sendable, CaseIterable {
    case candleCenter
    case candleHigh
    case candleLow
    case priceLine
    case chartPoint
    case floating
}

public struct KXUT05PointDTO: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(point: KLChartPoint) {
        self.init(x: point.x, y: point.y)
    }

    public var chartPoint: KLChartPoint {
        KLChartPoint(x: x, y: y)
    }
}

public struct KXUT05MarkerPositionDTO: Codable, Equatable, Sendable {
    public let time: Date?
    public let candleIndex: Int?
    public let candleID: KLCandleID?
    public let price: KXDecimal?
    public let point: KXUT05PointDTO?
    public let anchor: KXUT05MarkerAnchor
    public let offsetX: Double
    public let offsetY: Double

    public init(
        time: Date? = nil,
        candleIndex: Int? = nil,
        candleID: KLCandleID? = nil,
        price: KXDecimal? = nil,
        point: KXUT05PointDTO? = nil,
        anchor: KXUT05MarkerAnchor = .candleCenter,
        offsetX: Double = 0,
        offsetY: Double = 0
    ) {
        self.time = time
        self.candleIndex = candleIndex
        self.candleID = candleID
        self.price = price
        self.point = point
        self.anchor = anchor
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    public init(coordinate: KLChartCoordinate, anchor: KXUT05MarkerAnchor = .candleCenter) {
        self.init(
            time: coordinate.time,
            candleIndex: coordinate.index,
            price: coordinate.price,
            point: coordinate.point.map(KXUT05PointDTO.init(point:)),
            anchor: anchor
        )
    }

    public var chartCoordinate: KLChartCoordinate {
        KLChartCoordinate(time: time, index: candleIndex, price: price, point: point?.chartPoint)
    }

    public var hasRenderableCoordinate: Bool {
        time != nil || candleIndex != nil || price != nil || point != nil
    }
}

// MARK: - 置信度、文本、图标与样式

public enum KXUT05ConfidenceBand: String, Codable, Sendable, CaseIterable, Comparable {
    case unknown
    case veryLow
    case low
    case medium
    case high
    case veryHigh

    public var rank: Int {
        switch self {
        case .unknown: return 0
        case .veryLow: return 1
        case .low: return 2
        case .medium: return 3
        case .high: return 4
        case .veryHigh: return 5
        }
    }

    public var displayName: String {
        switch self {
        case .unknown: return "未知"
        case .veryLow: return "很低"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .veryHigh: return "很高"
        }
    }

    public static func band(for confidence: Double?) -> KXUT05ConfidenceBand {
        guard let confidence else { return .unknown }
        let value = KXUT05ValueNormalizer.clamp01(confidence)
        switch value {
        case ..<0.2: return .veryLow
        case ..<0.4: return .low
        case ..<0.65: return .medium
        case ..<0.85: return .high
        default: return .veryHigh
        }
    }

    public static func < (lhs: KXUT05ConfidenceBand, rhs: KXUT05ConfidenceBand) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct KXUT05ConfidenceDTO: Codable, Equatable, Sendable {
    public let value: Double?
    public let band: KXUT05ConfidenceBand
    public let evidenceCount: Int?
    public let note: String?

    public init(value: Double? = nil, band: KXUT05ConfidenceBand? = nil, evidenceCount: Int? = nil, note: String? = nil) {
        self.value = value.map(KXUT05ValueNormalizer.clamp01)
        self.band = band ?? KXUT05ConfidenceBand.band(for: value)
        self.evidenceCount = evidenceCount
        self.note = note
    }
}

public struct KXUT05MarkerTextDTO: Codable, Equatable, Sendable {
    public let title: String
    public let message: String?
    public let badge: String?
    public let accessibilityLabel: String?

    public init(title: String, message: String? = nil, badge: String? = nil, accessibilityLabel: String? = nil) {
        self.title = title
        self.message = message
        self.badge = badge
        self.accessibilityLabel = accessibilityLabel
    }
}

public enum KXUT05IconPlacement: String, Codable, Sendable, CaseIterable {
    case leading
    case trailing
    case above
    case below
    case center
}

public struct KXUT05MarkerIconDTO: Codable, Equatable, Sendable {
    public let name: String?
    public let emoji: String?
    public let placement: KXUT05IconPlacement
    public let size: Double?

    public init(name: String? = nil, emoji: String? = nil, placement: KXUT05IconPlacement = .leading, size: Double? = nil) {
        self.name = name
        self.emoji = emoji
        self.placement = placement
        self.size = size
    }
}

public enum KXUT05TextEmphasis: String, Codable, Sendable, CaseIterable {
    case normal
    case muted
    case strong
    case warning
}

public struct KXUT05MarkerStyleDTO: Codable, Equatable, Sendable {
    public let colorHex: String
    public let backgroundColorHex: String?
    public let borderColorHex: String?
    public let iconName: String?
    public let lineWidth: Double?
    public let opacity: Double
    public let textEmphasis: KXUT05TextEmphasis

    public init(
        colorHex: String,
        backgroundColorHex: String? = nil,
        borderColorHex: String? = nil,
        iconName: String? = nil,
        lineWidth: Double? = nil,
        opacity: Double = 1,
        textEmphasis: KXUT05TextEmphasis = .normal
    ) {
        self.colorHex = colorHex
        self.backgroundColorHex = backgroundColorHex
        self.borderColorHex = borderColorHex
        self.iconName = iconName
        self.lineWidth = lineWidth
        self.opacity = KXUT05ValueNormalizer.clamp01(opacity)
        self.textEmphasis = textEmphasis
    }

    public init(publicStyle: KLMarkerStyleDescriptor) {
        self.init(
            colorHex: publicStyle.colorHex,
            iconName: publicStyle.iconName,
            lineWidth: publicStyle.lineWidth,
            opacity: publicStyle.opacity
        )
    }

    public var publicStyle: KLMarkerStyleDescriptor {
        KLMarkerStyleDescriptor(colorHex: colorHex, iconName: iconName, lineWidth: lineWidth, opacity: opacity)
    }
}

// MARK: - 标记 DTO 与 KLMarkerDescriptor 映射

public struct KXUT05MarkerDTO: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let kind: KXUT05MarkerKind
    public let source: KXUT05MarkerSource
    public let severity: KXUT05MarkerSeverity
    public let position: KXUT05MarkerPositionDTO
    public let confidence: KXUT05ConfidenceDTO
    public let text: KXUT05MarkerTextDTO
    public let icon: KXUT05MarkerIconDTO?
    public let style: KXUT05MarkerStyleDTO?
    public let conversionSource: KXUT05MarkerConversionSource
    public let metadata: [String: String]
    public let createdAt: Date
    public let updatedAt: Date?

    public init(
        id: String,
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        kind: KXUT05MarkerKind,
        source: KXUT05MarkerSource,
        severity: KXUT05MarkerSeverity = .info,
        position: KXUT05MarkerPositionDTO,
        confidence: KXUT05ConfidenceDTO = KXUT05ConfidenceDTO(),
        text: KXUT05MarkerTextDTO,
        icon: KXUT05MarkerIconDTO? = nil,
        style: KXUT05MarkerStyleDTO? = nil,
        conversionSource: KXUT05MarkerConversionSource = .markerDTO,
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.timeframe = timeframe
        self.kind = kind
        self.source = source
        self.severity = severity
        self.position = position
        self.confidence = confidence
        self.text = text
        self.icon = icon
        self.style = style
        self.conversionSource = conversionSource
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(descriptor: KLMarkerDescriptor, confidence: KXUT05ConfidenceDTO = KXUT05ConfidenceDTO()) {
        let styleDTO = descriptor.style.map(KXUT05MarkerStyleDTO.init(publicStyle:))
        self.init(
            id: descriptor.id,
            symbol: descriptor.symbol,
            timeframe: descriptor.timeframe,
            kind: KXUT05MarkerKind(publicKind: descriptor.kind),
            source: KXUT05MarkerSource(publicSource: descriptor.source),
            severity: KXUT05MarkerSeverity(publicSeverity: descriptor.severity),
            position: KXUT05MarkerPositionDTO(coordinate: descriptor.coordinate),
            confidence: confidence,
            text: KXUT05MarkerTextDTO(title: descriptor.title, message: descriptor.message),
            icon: styleDTO?.iconName.map { KXUT05MarkerIconDTO(name: $0) },
            style: styleDTO,
            conversionSource: .klMarkerDescriptor,
            createdAt: descriptor.createdAt
        )
    }

    public func descriptor(styleCatalog: KXUT05MarkerStyleCatalog = .standard) -> KLMarkerDescriptor {
        let resolvedStyle = style ?? styleCatalog.style(for: self)
        return KLMarkerDescriptor(
            id: id,
            symbol: symbol,
            timeframe: timeframe,
            kind: kind.publicKind,
            source: source.publicSource,
            severity: severity.publicSeverity,
            title: text.title,
            message: text.message,
            coordinate: position.chartCoordinate,
            style: resolvedStyle.publicStyle,
            createdAt: createdAt
        )
    }

    public var isRenderable: Bool {
        !text.title.isEmpty && position.hasRenderableCoordinate
    }
}

public enum KXUT05MarkerDescriptorMapper {
    public static func dto(from descriptor: KLMarkerDescriptor, confidence: KXUT05ConfidenceDTO = KXUT05ConfidenceDTO()) -> KXUT05MarkerDTO {
        KXUT05MarkerDTO(descriptor: descriptor, confidence: confidence)
    }

    public static func descriptor(from dto: KXUT05MarkerDTO, styleCatalog: KXUT05MarkerStyleCatalog = .standard) -> KLMarkerDescriptor {
        dto.descriptor(styleCatalog: styleCatalog)
    }

    public static func descriptors(from dtos: [KXUT05MarkerDTO], styleCatalog: KXUT05MarkerStyleCatalog = .standard) -> [KLMarkerDescriptor] {
        dtos.map { $0.descriptor(styleCatalog: styleCatalog) }
    }

    public static func dtos(from descriptors: [KLMarkerDescriptor]) -> [KXUT05MarkerDTO] {
        descriptors.map { KXUT05MarkerDTO(descriptor: $0) }
    }
}

// MARK: - 样式匹配

public struct KXUT05MarkerStyleRule: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: KXUT05MarkerKind?
    public let source: KXUT05MarkerSource?
    public let severity: KXUT05MarkerSeverity?
    public let minimumConfidenceBand: KXUT05ConfidenceBand?
    public let style: KXUT05MarkerStyleDTO
    public let priority: Int

    public init(
        id: String,
        kind: KXUT05MarkerKind? = nil,
        source: KXUT05MarkerSource? = nil,
        severity: KXUT05MarkerSeverity? = nil,
        minimumConfidenceBand: KXUT05ConfidenceBand? = nil,
        style: KXUT05MarkerStyleDTO,
        priority: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.source = source
        self.severity = severity
        self.minimumConfidenceBand = minimumConfidenceBand
        self.style = style
        self.priority = priority
    }

    public func matchScore(for marker: KXUT05MarkerDTO) -> Int? {
        var score = priority
        if let kind {
            guard kind == marker.kind else { return nil }
            score += 100
        }
        if let source {
            guard source == marker.source else { return nil }
            score += 40
        }
        if let severity {
            guard severity == marker.severity else { return nil }
            score += 60 + severity.rank
        }
        if let minimumConfidenceBand {
            guard marker.confidence.band >= minimumConfidenceBand else { return nil }
            score += 20 + marker.confidence.band.rank
        }
        return score
    }
}

public struct KXUT05MarkerStyleCatalog: Codable, Equatable, Sendable {
    public let rules: [KXUT05MarkerStyleRule]
    public let fallbackStyle: KXUT05MarkerStyleDTO

    public init(rules: [KXUT05MarkerStyleRule] = [], fallbackStyle: KXUT05MarkerStyleDTO = KXUT05MarkerStyleCatalog.defaultFallbackStyle) {
        self.rules = rules
        self.fallbackStyle = fallbackStyle
    }

    public func style(for marker: KXUT05MarkerDTO) -> KXUT05MarkerStyleDTO {
        bestRule(for: marker)?.style ?? fallbackStyle
    }

    public func bestRule(for marker: KXUT05MarkerDTO) -> KXUT05MarkerStyleRule? {
        rules.compactMap { rule -> (rule: KXUT05MarkerStyleRule, score: Int)? in
            guard let score = rule.matchScore(for: marker) else { return nil }
            return (rule, score)
        }
        .max { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            return lhs.rule.id < rhs.rule.id
        }?
        .rule
    }

    public static let defaultFallbackStyle = KXUT05MarkerStyleDTO(
        colorHex: "#8E8E93",
        iconName: "circle",
        lineWidth: 1,
        opacity: 0.9,
        textEmphasis: .normal
    )

    public static let standard = KXUT05MarkerStyleCatalog(rules: [
        KXUT05MarkerStyleRule(
            id: "pattern-high-confidence",
            kind: .pattern,
            source: .patternRecognition,
            minimumConfidenceBand: .high,
            style: KXUT05MarkerStyleDTO(colorHex: "#34C759", iconName: "chart.line.uptrend.xyaxis", lineWidth: 2, opacity: 1, textEmphasis: .strong),
            priority: 50
        ),
        KXUT05MarkerStyleRule(
            id: "manual-note",
            kind: .manual,
            source: .user,
            style: KXUT05MarkerStyleDTO(colorHex: "#0A84FF", iconName: "pencil.circle", lineWidth: 1.5, opacity: 1, textEmphasis: .normal),
            priority: 40
        ),
        KXUT05MarkerStyleRule(
            id: "price-level",
            kind: .priceLevel,
            style: KXUT05MarkerStyleDTO(colorHex: "#FF9F0A", iconName: "line.horizontal.3", lineWidth: 1.5, opacity: 0.95, textEmphasis: .warning),
            priority: 30
        ),
        KXUT05MarkerStyleRule(
            id: "critical",
            severity: .critical,
            style: KXUT05MarkerStyleDTO(colorHex: "#FF3B30", iconName: "exclamationmark.triangle.fill", lineWidth: 2.5, opacity: 1, textEmphasis: .warning),
            priority: 90
        ),
        KXUT05MarkerStyleRule(
            id: "high",
            severity: .high,
            style: KXUT05MarkerStyleDTO(colorHex: "#FF453A", iconName: "exclamationmark.circle", lineWidth: 2, opacity: 1, textEmphasis: .strong),
            priority: 60
        ),
        KXUT05MarkerStyleRule(
            id: "medium",
            severity: .medium,
            style: KXUT05MarkerStyleDTO(colorHex: "#FFD60A", iconName: "bell", lineWidth: 1.5, opacity: 0.95, textEmphasis: .normal),
            priority: 20
        ),
        KXUT05MarkerStyleRule(
            id: "low",
            severity: .low,
            style: KXUT05MarkerStyleDTO(colorHex: "#64D2FF", iconName: "info.circle", lineWidth: 1, opacity: 0.85, textEmphasis: .muted),
            priority: 10
        )
    ])
}

// MARK: - 工具

public enum KXUT05ValueNormalizer {
    public static func clamp01(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        return min(1, max(0, value))
    }
}
