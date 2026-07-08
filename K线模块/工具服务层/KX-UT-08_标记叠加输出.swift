//
//  KX-UT-08_标记叠加输出.swift
//  仙人指路测试项目｜K线模块
//
//  版本：2.0
//  职责：向图表输出可叠加标记数据
//  禁止事项：禁止 UI 绘制
//

import Foundation

@MainActor


// MARK: - 标记叠加输出

public struct KXUT08Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UT-08",
        fileName: "KX-UT-08_标记叠加输出.swift",
        layer: .marker,
        relativePath: "标记层/KX-UT-08_标记叠加输出.swift",
        duty: "向图表输出可叠加标记数据"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "标记叠加输出", passed: true, message: "已实现标记过滤、可见性计算、分组排序与叠加层快照输出")
    }

    public static func placeholder() {
        // 本文件已补充纯数据输出转换逻辑。
        // 不绘制 UI、不请求网络、不读写数据库；仅把 KLMarkerDescriptor 数组转换为图表可消费的叠加层快照。
    }
}

// MARK: - 加载状态与请求配置

public enum KXUT08OverlayLoadingState: String, Codable, Sendable, CaseIterable {
    case idle
    case loading
    case refreshing
    case loaded
    case empty
    case failed
}

public enum KXUT08MarkerSortOrder: String, Codable, Sendable, CaseIterable {
    case chartNatural
    case createdAscending
    case createdDescending
    case severityDescending
    case severityAscending
}

public struct KXUT08LayerRule: Codable, Equatable, Sendable {
    public let source: KLMarkerSource?
    public let severity: KLMarkerSeverity?
    public let kind: KLMarkerKind?
    public let zIndex: Int
    public let isVisible: Bool
    public let title: String?

    public init(
        source: KLMarkerSource? = nil,
        severity: KLMarkerSeverity? = nil,
        kind: KLMarkerKind? = nil,
        zIndex: Int,
        isVisible: Bool = true,
        title: String? = nil
    ) {
        self.source = source
        self.severity = severity
        self.kind = kind
        self.zIndex = zIndex
        self.isVisible = isVisible
        self.title = title
    }

    public func matches(_ marker: KLMarkerDescriptor) -> Bool {
        if let source, marker.source != source { return false }
        if let severity, marker.severity != severity { return false }
        if let kind, marker.kind != kind { return false }
        return true
    }
}

public struct KXUT08OverlayRequest: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let visibleWindow: KLVisibleWindow
    public let loadingState: KXUT08OverlayLoadingState
    public let errorMessage: String?
    public let globalVisible: Bool
    public let includeInvisibleMarkers: Bool
    public let markerSortOrder: KXUT08MarkerSortOrder
    public let enabledSources: Set<KLMarkerSource>?
    public let hiddenSources: Set<KLMarkerSource>
    public let enabledSeverities: Set<KLMarkerSeverity>?
    public let hiddenSeverities: Set<KLMarkerSeverity>
    public let enabledKinds: Set<KLMarkerKind>?
    public let hiddenKinds: Set<KLMarkerKind>
    public let visibleMarkerIDs: Set<String>?
    public let hiddenMarkerIDs: Set<String>
    public let layerRules: [KXUT08LayerRule]

    public init(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        visibleWindow: KLVisibleWindow,
        loadingState: KXUT08OverlayLoadingState = .loaded,
        errorMessage: String? = nil,
        globalVisible: Bool = true,
        includeInvisibleMarkers: Bool = false,
        markerSortOrder: KXUT08MarkerSortOrder = .chartNatural,
        enabledSources: Set<KLMarkerSource>? = nil,
        hiddenSources: Set<KLMarkerSource> = [],
        enabledSeverities: Set<KLMarkerSeverity>? = nil,
        hiddenSeverities: Set<KLMarkerSeverity> = [],
        enabledKinds: Set<KLMarkerKind>? = nil,
        hiddenKinds: Set<KLMarkerKind> = [],
        visibleMarkerIDs: Set<String>? = nil,
        hiddenMarkerIDs: Set<String> = [],
        layerRules: [KXUT08LayerRule] = KXUT08OverlayRequest.defaultLayerRules
    ) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.visibleWindow = visibleWindow
        self.loadingState = loadingState
        self.errorMessage = errorMessage
        self.globalVisible = globalVisible
        self.includeInvisibleMarkers = includeInvisibleMarkers
        self.markerSortOrder = markerSortOrder
        self.enabledSources = enabledSources
        self.hiddenSources = hiddenSources
        self.enabledSeverities = enabledSeverities
        self.hiddenSeverities = hiddenSeverities
        self.enabledKinds = enabledKinds
        self.hiddenKinds = hiddenKinds
        self.visibleMarkerIDs = visibleMarkerIDs
        self.hiddenMarkerIDs = hiddenMarkerIDs
        self.layerRules = layerRules
    }

    public static let defaultLayerRules: [KXUT08LayerRule] = [
        KXUT08LayerRule(source: .importSource, zIndex: 10, title: "导入标记"),
        KXUT08LayerRule(source: .system, zIndex: 20, title: "系统标记"),
        KXUT08LayerRule(source: .patternRecognition, zIndex: 30, title: "形态识别标记"),
        KXUT08LayerRule(source: .user, zIndex: 40, title: "用户标记"),
        KXUT08LayerRule(severity: .critical, zIndex: 90, title: "严重标记"),
        KXUT08LayerRule(severity: .high, zIndex: 80, title: "高优先级标记")
    ]
}

// MARK: - 叠加层输出 DTO

public struct KXUT08LayerKey: Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let zIndex: Int
    public let source: KLMarkerSource
    public let severity: KLMarkerSeverity

    public init(zIndex: Int, source: KLMarkerSource, severity: KLMarkerSeverity) {
        self.zIndex = zIndex
        self.source = source
        self.severity = severity
    }

    public var description: String {
        "z\(zIndex)-\(source.rawValue)-\(severity.rawValue)"
    }

    public static func < (lhs: KXUT08LayerKey, rhs: KXUT08LayerKey) -> Bool {
        if lhs.zIndex != rhs.zIndex { return lhs.zIndex < rhs.zIndex }
        if lhs.source.rawValue != rhs.source.rawValue { return lhs.source.rawValue < rhs.source.rawValue }
        return KXUT08SeverityRank.rank(lhs.severity) < KXUT08SeverityRank.rank(rhs.severity)
    }
}

public struct KXUT08OverlayMarkerItem: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let descriptor: KLMarkerDescriptor
    public let point: KLChartPoint?
    public let zIndex: Int
    public let source: KLMarkerSource
    public let severity: KLMarkerSeverity
    public let isInWindow: Bool
    public let isVisibleBySwitch: Bool
    public let isLayerVisible: Bool
    public let isVisible: Bool
    public let visibilityReason: String?

    public init(
        id: String,
        descriptor: KLMarkerDescriptor,
        point: KLChartPoint?,
        zIndex: Int,
        source: KLMarkerSource,
        severity: KLMarkerSeverity,
        isInWindow: Bool,
        isVisibleBySwitch: Bool,
        isLayerVisible: Bool,
        isVisible: Bool,
        visibilityReason: String? = nil
    ) {
        self.id = id
        self.descriptor = descriptor
        self.point = point
        self.zIndex = zIndex
        self.source = source
        self.severity = severity
        self.isInWindow = isInWindow
        self.isVisibleBySwitch = isVisibleBySwitch
        self.isLayerVisible = isLayerVisible
        self.isVisible = isVisible
        self.visibilityReason = visibilityReason
    }
}

public struct KXUT08OverlayLayer: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let key: KXUT08LayerKey
    public let title: String
    public let zIndex: Int
    public let source: KLMarkerSource
    public let severity: KLMarkerSeverity
    public let isVisible: Bool
    public let markerCount: Int
    public let visibleMarkerCount: Int
    public let markers: [KXUT08OverlayMarkerItem]

    public init(
        id: String,
        key: KXUT08LayerKey,
        title: String,
        zIndex: Int,
        source: KLMarkerSource,
        severity: KLMarkerSeverity,
        isVisible: Bool,
        markerCount: Int,
        visibleMarkerCount: Int,
        markers: [KXUT08OverlayMarkerItem]
    ) {
        self.id = id
        self.key = key
        self.title = title
        self.zIndex = zIndex
        self.source = source
        self.severity = severity
        self.isVisible = isVisible
        self.markerCount = markerCount
        self.visibleMarkerCount = visibleMarkerCount
        self.markers = markers
    }
}

public struct KXUT08OverlayStatus: Codable, Equatable, Sendable {
    public let loadingState: KXUT08OverlayLoadingState
    public let errorMessage: String?
    public let totalInputCount: Int
    public let symbolTimeframeMatchedCount: Int
    public let inWindowCount: Int
    public let switchVisibleCount: Int
    public let layerVisibleCount: Int
    public let outputVisibleCount: Int
    public let layerCount: Int
    public let isEmpty: Bool
    public let generatedAt: Date

    public init(
        loadingState: KXUT08OverlayLoadingState,
        errorMessage: String?,
        totalInputCount: Int,
        symbolTimeframeMatchedCount: Int,
        inWindowCount: Int,
        switchVisibleCount: Int,
        layerVisibleCount: Int,
        outputVisibleCount: Int,
        layerCount: Int,
        isEmpty: Bool,
        generatedAt: Date
    ) {
        self.loadingState = loadingState
        self.errorMessage = errorMessage
        self.totalInputCount = totalInputCount
        self.symbolTimeframeMatchedCount = symbolTimeframeMatchedCount
        self.inWindowCount = inWindowCount
        self.switchVisibleCount = switchVisibleCount
        self.layerVisibleCount = layerVisibleCount
        self.outputVisibleCount = outputVisibleCount
        self.layerCount = layerCount
        self.isEmpty = isEmpty
        self.generatedAt = generatedAt
    }
}

public struct KXUT08MarkerOverlaySnapshot: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let visibleWindow: KLVisibleWindow
    public let layers: [KXUT08OverlayLayer]
    public let flattenedMarkers: [KXUT08OverlayMarkerItem]
    public let status: KXUT08OverlayStatus
    public let generatedAt: Date

    public init(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        visibleWindow: KLVisibleWindow,
        layers: [KXUT08OverlayLayer],
        flattenedMarkers: [KXUT08OverlayMarkerItem],
        status: KXUT08OverlayStatus,
        generatedAt: Date
    ) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.visibleWindow = visibleWindow
        self.layers = layers
        self.flattenedMarkers = flattenedMarkers
        self.status = status
        self.generatedAt = generatedAt
    }
}

// MARK: - 输出适配器

public struct KXUT08MarkerOverlayOutputAdapter: Sendable {
    public init() {}

    /// 将 KLMarkerDescriptor 数组转换为图表可消费的叠加层快照。
    /// - 约束：纯内存数据转换；不绘制 UI、不请求网络、不读写数据库。
    public func makeOverlaySnapshot(
        markers: [KLMarkerDescriptor],
        request: KXUT08OverlayRequest,
        generatedAt: Date = Date()
    ) -> KXUT08MarkerOverlaySnapshot {
        Self.makeOverlaySnapshot(markers: markers, request: request, generatedAt: generatedAt)
    }

    /// 便捷入口：按可视窗口的 symbol/timeframe 生成默认叠加层快照。
    public func makeOverlaySnapshot(
        markers: [KLMarkerDescriptor],
        visibleWindow: KLVisibleWindow,
        loadingState: KXUT08OverlayLoadingState = .loaded,
        generatedAt: Date = Date()
    ) -> KXUT08MarkerOverlaySnapshot {
        let request = KXUT08OverlayRequest(
            symbol: visibleWindow.symbol,
            timeframe: visibleWindow.timeframe,
            visibleWindow: visibleWindow,
            loadingState: loadingState
        )
        return Self.makeOverlaySnapshot(markers: markers, request: request, generatedAt: generatedAt)
    }
}

// MARK: - 内部纯计算辅助

private enum KXUT08SeverityRank {
    static func rank(_ severity: KLMarkerSeverity) -> Int {
        switch severity {
        case .info: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

private extension KXUT08MarkerOverlayOutputAdapter {
    static func makeOverlaySnapshot(
        markers: [KLMarkerDescriptor],
        request: KXUT08OverlayRequest,
        generatedAt: Date
    ) -> KXUT08MarkerOverlaySnapshot {
        let symbolTimeframeMatched = markers.filter { $0.symbol == request.symbol && $0.timeframe == request.timeframe }
        let evaluatedItems = symbolTimeframeMatched.map { marker in
            makeItem(marker: marker, request: request)
        }
        let outputItems = request.includeInvisibleMarkers ? evaluatedItems : evaluatedItems.filter(\.isVisible)
        let sortedItems = sort(outputItems, order: request.markerSortOrder)
        let layers = makeLayers(from: sortedItems, request: request)
        let flattenedMarkers = layers.flatMap(\.markers)
        let effectiveState = effectiveLoadingState(
            requested: request.loadingState,
            hasVisibleMarkers: flattenedMarkers.contains(where: \.isVisible),
            hasError: request.errorMessage != nil
        )
        let status = KXUT08OverlayStatus(
            loadingState: effectiveState,
            errorMessage: request.errorMessage,
            totalInputCount: markers.count,
            symbolTimeframeMatchedCount: symbolTimeframeMatched.count,
            inWindowCount: evaluatedItems.filter(\.isInWindow).count,
            switchVisibleCount: evaluatedItems.filter(\.isVisibleBySwitch).count,
            layerVisibleCount: evaluatedItems.filter(\.isLayerVisible).count,
            outputVisibleCount: flattenedMarkers.filter(\.isVisible).count,
            layerCount: layers.count,
            isEmpty: flattenedMarkers.isEmpty,
            generatedAt: generatedAt
        )

        return KXUT08MarkerOverlaySnapshot(
            symbol: request.symbol,
            timeframe: request.timeframe,
            visibleWindow: request.visibleWindow,
            layers: layers,
            flattenedMarkers: flattenedMarkers,
            status: status,
            generatedAt: generatedAt
        )
    }

    static func makeItem(marker: KLMarkerDescriptor, request: KXUT08OverlayRequest) -> KXUT08OverlayMarkerItem {
        let window = request.visibleWindow
        let point = chartPoint(for: marker.coordinate, in: window)
        let inWindow = isCoordinateInWindow(marker.coordinate, point: point, in: window)
        let switchEvaluation = isVisibleBySwitch(marker, request: request)
        let layerRule = matchedLayerRule(for: marker, rules: request.layerRules)
        let zIndex = layerRule?.zIndex ?? defaultZIndex(for: marker)
        let layerVisible = layerRule?.isVisible ?? true
        let isVisible = request.globalVisible && inWindow && switchEvaluation.isVisible && layerVisible
        let reason: String?

        if !request.globalVisible {
            reason = "global-hidden"
        } else if !inWindow {
            reason = "outside-window"
        } else if !switchEvaluation.isVisible {
            reason = switchEvaluation.reason
        } else if !layerVisible {
            reason = "layer-hidden"
        } else {
            reason = nil
        }

        return KXUT08OverlayMarkerItem(
            id: marker.id,
            descriptor: marker,
            point: point,
            zIndex: zIndex,
            source: marker.source,
            severity: marker.severity,
            isInWindow: inWindow,
            isVisibleBySwitch: switchEvaluation.isVisible,
            isLayerVisible: layerVisible,
            isVisible: isVisible,
            visibilityReason: reason
        )
    }

    static func makeLayers(from items: [KXUT08OverlayMarkerItem], request: KXUT08OverlayRequest) -> [KXUT08OverlayLayer] {
        let grouped = Dictionary(grouping: items) { item in
            KXUT08LayerKey(zIndex: item.zIndex, source: item.source, severity: item.severity)
        }

        return grouped.keys.sorted().map { key in
            let layerItems = sort(grouped[key] ?? [], order: request.markerSortOrder)
            let visibleCount = layerItems.filter(\.isVisible).count
            return KXUT08OverlayLayer(
                id: key.description,
                key: key,
                title: layerTitle(for: key, request: request),
                zIndex: key.zIndex,
                source: key.source,
                severity: key.severity,
                isVisible: visibleCount > 0,
                markerCount: layerItems.count,
                visibleMarkerCount: visibleCount,
                markers: layerItems
            )
        }
    }

    static func isVisibleBySwitch(_ marker: KLMarkerDescriptor, request: KXUT08OverlayRequest) -> (isVisible: Bool, reason: String?) {
        if request.hiddenMarkerIDs.contains(marker.id) { return (false, "marker-id-hidden") }
        if let visibleMarkerIDs = request.visibleMarkerIDs, !visibleMarkerIDs.contains(marker.id) { return (false, "marker-id-not-enabled") }
        if request.hiddenSources.contains(marker.source) { return (false, "source-hidden") }
        if let enabledSources = request.enabledSources, !enabledSources.contains(marker.source) { return (false, "source-not-enabled") }
        if request.hiddenSeverities.contains(marker.severity) { return (false, "severity-hidden") }
        if let enabledSeverities = request.enabledSeverities, !enabledSeverities.contains(marker.severity) { return (false, "severity-not-enabled") }
        if request.hiddenKinds.contains(marker.kind) { return (false, "kind-hidden") }
        if let enabledKinds = request.enabledKinds, !enabledKinds.contains(marker.kind) { return (false, "kind-not-enabled") }
        return (true, nil)
    }

    static func matchedLayerRule(for marker: KLMarkerDescriptor, rules: [KXUT08LayerRule]) -> KXUT08LayerRule? {
        rules
            .filter { $0.matches(marker) }
            .sorted { lhs, rhs in
                let lhsSpecificity = specificity(of: lhs)
                let rhsSpecificity = specificity(of: rhs)
                if lhsSpecificity != rhsSpecificity { return lhsSpecificity > rhsSpecificity }
                return lhs.zIndex > rhs.zIndex
            }
            .first
    }

    static func specificity(of rule: KXUT08LayerRule) -> Int {
        var score = 0
        if rule.source != nil { score += 1 }
        if rule.severity != nil { score += 1 }
        if rule.kind != nil { score += 1 }
        return score
    }

    static func defaultZIndex(for marker: KLMarkerDescriptor) -> Int {
        let sourceBase: Int
        switch marker.source {
        case .importSource: sourceBase = 10
        case .system: sourceBase = 20
        case .patternRecognition: sourceBase = 30
        case .user: sourceBase = 40
        }
        return sourceBase + KXUT08SeverityRank.rank(marker.severity)
    }

    static func layerTitle(for key: KXUT08LayerKey, request: KXUT08OverlayRequest) -> String {
        if let rule = request.layerRules.first(where: { rule in
            rule.source == key.source && rule.severity == key.severity && rule.zIndex == key.zIndex && rule.title != nil
        }), let title = rule.title {
            return title
        }
        return "标记层 · \(key.source.rawValue) · \(key.severity.rawValue) · z\(key.zIndex)"
    }

    static func sort(_ items: [KXUT08OverlayMarkerItem], order: KXUT08MarkerSortOrder) -> [KXUT08OverlayMarkerItem] {
        items.sorted { lhs, rhs in
            switch order {
            case .chartNatural:
                return naturalLessThan(lhs, rhs)
            case .createdAscending:
                if lhs.descriptor.createdAt != rhs.descriptor.createdAt { return lhs.descriptor.createdAt < rhs.descriptor.createdAt }
                return naturalLessThan(lhs, rhs)
            case .createdDescending:
                if lhs.descriptor.createdAt != rhs.descriptor.createdAt { return lhs.descriptor.createdAt > rhs.descriptor.createdAt }
                return naturalLessThan(lhs, rhs)
            case .severityDescending:
                let lhsRank = KXUT08SeverityRank.rank(lhs.severity)
                let rhsRank = KXUT08SeverityRank.rank(rhs.severity)
                if lhsRank != rhsRank { return lhsRank > rhsRank }
                return naturalLessThan(lhs, rhs)
            case .severityAscending:
                let lhsRank = KXUT08SeverityRank.rank(lhs.severity)
                let rhsRank = KXUT08SeverityRank.rank(rhs.severity)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return naturalLessThan(lhs, rhs)
            }
        }
    }

    static func naturalLessThan(_ lhs: KXUT08OverlayMarkerItem, _ rhs: KXUT08OverlayMarkerItem) -> Bool {
        if lhs.zIndex != rhs.zIndex { return lhs.zIndex < rhs.zIndex }
        if let lhsIndex = lhs.descriptor.coordinate.index, let rhsIndex = rhs.descriptor.coordinate.index, lhsIndex != rhsIndex {
            return lhsIndex < rhsIndex
        }
        if let lhsTime = lhs.descriptor.coordinate.time, let rhsTime = rhs.descriptor.coordinate.time, lhsTime != rhsTime {
            return lhsTime < rhsTime
        }
        let lhsRank = KXUT08SeverityRank.rank(lhs.severity)
        let rhsRank = KXUT08SeverityRank.rank(rhs.severity)
        if lhsRank != rhsRank { return lhsRank > rhsRank }
        if lhs.source.rawValue != rhs.source.rawValue { return lhs.source.rawValue < rhs.source.rawValue }
        return lhs.id < rhs.id
    }

    static func chartPoint(for coordinate: KLChartCoordinate, in window: KLVisibleWindow) -> KLChartPoint? {
        if let point = coordinate.point { return point }

        let xValue: Double?
        if let index = coordinate.index {
            xValue = x(forIndex: index, in: window)
        } else if let time = coordinate.time, let index = estimatedIndex(for: time, in: window) {
            xValue = x(forIndex: index, in: window)
        } else {
            xValue = nil
        }

        let yValue = coordinate.price.flatMap { y(forPrice: $0, in: window) }
        if let xValue, let yValue {
            return KLChartPoint(x: xValue, y: yValue)
        }
        return nil
    }

    static func isCoordinateInWindow(_ coordinate: KLChartCoordinate, point: KLChartPoint?, in window: KLVisibleWindow) -> Bool {
        if let index = coordinate.index, (index < window.indexRange.startIndex || index > window.indexRange.endIndex) {
            return false
        }
        if let time = coordinate.time, let timeRange = window.timeRange, (time < timeRange.startTime || time > timeRange.endTime) {
            return false
        }
        if let price = coordinate.price, let priceRange = window.priceRange {
            let lower = min(priceRange.minPrice, priceRange.maxPrice)
            let upper = max(priceRange.minPrice, priceRange.maxPrice)
            if price < lower || price > upper { return false }
        }
        if let point {
            return point.x.isFinite && point.y.isFinite && point.x >= 0 && point.x <= window.viewportWidth && point.y >= 0 && point.y <= window.viewportHeight
        }
        return coordinate.index != nil || coordinate.time != nil || coordinate.price != nil
    }

    static func x(forIndex index: Int, in window: KLVisibleWindow) -> Double? {
        guard window.indexRange.startIndex <= window.indexRange.endIndex else { return nil }
        guard window.candleWidth.isFinite, window.candleWidth > 0 else { return nil }
        guard window.contentOffsetX.isFinite else { return nil }
        let xValue = (Double(index - window.indexRange.startIndex) + 0.5) * window.candleWidth - window.contentOffsetX
        return xValue.isFinite ? xValue : nil
    }

    static func y(forPrice price: KXDecimal, in window: KLVisibleWindow) -> Double? {
        guard let priceRange = window.priceRange else { return nil }
        guard window.viewportHeight.isFinite, window.viewportHeight > 0 else { return nil }

        let minPrice = double(from: min(priceRange.minPrice, priceRange.maxPrice))
        let maxPrice = double(from: max(priceRange.minPrice, priceRange.maxPrice))
        let priceValue = double(from: price)
        guard minPrice.isFinite, maxPrice.isFinite, priceValue.isFinite else { return nil }

        let range = maxPrice - minPrice
        if range == 0 { return window.viewportHeight / 2 }

        let yValue = (maxPrice - priceValue) / range * window.viewportHeight
        return yValue.isFinite ? yValue : nil
    }

    static func estimatedIndex(for time: Date, in window: KLVisibleWindow) -> Int? {
        guard let timeRange = window.timeRange else { return nil }
        guard window.indexRange.startIndex <= window.indexRange.endIndex else { return nil }

        let start = timeRange.startTime.timeIntervalSinceReferenceDate
        let end = timeRange.endTime.timeIntervalSinceReferenceDate
        let value = time.timeIntervalSinceReferenceDate
        guard start.isFinite, end.isFinite, value.isFinite, start <= end else { return nil }
        if start == end { return value == start ? window.indexRange.startIndex : nil }
        guard value >= start, value <= end else { return nil }

        let span = max(window.indexRange.endIndex - window.indexRange.startIndex, 0)
        let ratio = (value - start) / (end - start)
        return window.indexRange.startIndex + Int((ratio * Double(span)).rounded())
    }

    static func effectiveLoadingState(
        requested: KXUT08OverlayLoadingState,
        hasVisibleMarkers: Bool,
        hasError: Bool
    ) -> KXUT08OverlayLoadingState {
        if hasError { return .failed }
        if !hasVisibleMarkers, requested == .loaded { return .empty }
        return requested
    }

    static func double(from decimal: KXDecimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }
}

// MARK: - 外部标准标记直出图表叠加层

public extension KXUT08MarkerOverlayOutputAdapter {
    /// 从外部模块已生成的标准标记输出图表可消费的叠加快照。
    /// 约束：K线模块不主动运行形态识别算法，只消费标准 KLMarkerDescriptor。
    func makeExternalMarkerOverlaySnapshot(
        markers: [KLMarkerDescriptor],
        visibleWindow: KLVisibleWindow,
        generatedAt: Date = Date()
    ) -> KXUT08MarkerOverlaySnapshot {
        makeOverlaySnapshot(
            markers: markers,
            visibleWindow: visibleWindow,
            loadingState: markers.isEmpty ? .empty : .loaded,
            generatedAt: generatedAt
        )
    }
}
