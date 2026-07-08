//
//  KX-FN-23_UI图表数据接口.swift
//  仙人指路测试项目｜K线模块
//
//  版本：2.0
//  职责：向 UI 提供蜡烛、成交量、标记、叠加层、状态数据
//  禁止事项：禁止 UI 直接查库、禁止 UI 绘制
//

import Foundation


// MARK: - UI图表数据接口骨架

public struct KXFN223Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KL-IF-04",
        fileName: "KL-IF-04_UI图表数据接口.swift",
        layer: .interface,
        relativePath: "接口层/KL-IF-04_UI图表数据接口.swift",
        duty: "向 UI 提供蜡烛、成交量、标记、叠加层、状态数据"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "UI图表数据接口", passed: true, message: "已实现纯 DTO/快照/接口适配，向 UI 提供蜡烛、成交量、标记、叠加层、状态与质量摘要")
    }

    public static func placeholder() {
        // 本文件已补充 UI 图表数据 DTO、快照生成和接口适配。
        // 不包含 SwiftUI/View、不绘制 UI、不请求网络、不读写数据库、不做真实缓存。
        // 仅基于 KL-02 公共类型 KLCandlePoint、KLVisibleWindow、KLMarkerDescriptor 等生成可渲染数据快照。
    }
}

// MARK: - UI图表状态 DTO

public enum KXFN223ChartLoadingState: String, Codable, Sendable, CaseIterable {
    case idle
    case loading
    case refreshing
    case loaded
    case empty
    case failed
}

public struct KXFN223ChartErrorSnapshot: Codable, Equatable, Sendable {
    public let code: String
    public let message: String
    public let isRecoverable: Bool
    public let occurredAt: Date

    public init(code: String, message: String, isRecoverable: Bool = true, occurredAt: Date = Date()) {
        self.code = code
        self.message = message
        self.isRecoverable = isRecoverable
        self.occurredAt = occurredAt
    }
}

public struct KXFN223ChartEmptyStateSnapshot: Codable, Equatable, Sendable {
    public let isEmpty: Bool
    public let title: String
    public let message: String?

    public init(isEmpty: Bool, title: String = "暂无 K线数据", message: String? = nil) {
        self.isEmpty = isEmpty
        self.title = title
        self.message = message
    }
}

public struct KXFN223ChartStatusSnapshot: Codable, Equatable, Sendable {
    public let loadingState: KXFN223ChartLoadingState
    public let emptyState: KXFN223ChartEmptyStateSnapshot
    public let error: KXFN223ChartErrorSnapshot?
    public let generatedAt: Date

    public init(
        loadingState: KXFN223ChartLoadingState,
        emptyState: KXFN223ChartEmptyStateSnapshot,
        error: KXFN223ChartErrorSnapshot? = nil,
        generatedAt: Date = Date()
    ) {
        self.loadingState = loadingState
        self.emptyState = emptyState
        self.error = error
        self.generatedAt = generatedAt
    }
}

// MARK: - 蜡烛与成交量 DTO

public enum KXFN223CandleDirection: String, Codable, Sendable, CaseIterable {
    case rise
    case fall
    case flat
}

public struct KXFN223CandleBarSnapshot: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let sourceCandleID: KLCandleID?
    public let index: Int
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let openTime: Date
    public let closeTime: Date?
    public let open: KXDecimal
    public let high: KXDecimal
    public let low: KXDecimal
    public let close: KXDecimal
    public let direction: KXFN223CandleDirection
    public let isClosed: Bool
    public let bodyTopY: Double?
    public let bodyBottomY: Double?
    public let highY: Double?
    public let lowY: Double?
    public let centerX: Double?
    public let width: Double
    public let source: String?

    public init(
        id: String,
        sourceCandleID: KLCandleID?,
        index: Int,
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        openTime: Date,
        closeTime: Date?,
        open: KXDecimal,
        high: KXDecimal,
        low: KXDecimal,
        close: KXDecimal,
        direction: KXFN223CandleDirection,
        isClosed: Bool,
        bodyTopY: Double?,
        bodyBottomY: Double?,
        highY: Double?,
        lowY: Double?,
        centerX: Double?,
        width: Double,
        source: String?
    ) {
        self.id = id
        self.sourceCandleID = sourceCandleID
        self.index = index
        self.symbol = symbol
        self.timeframe = timeframe
        self.openTime = openTime
        self.closeTime = closeTime
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.direction = direction
        self.isClosed = isClosed
        self.bodyTopY = bodyTopY
        self.bodyBottomY = bodyBottomY
        self.highY = highY
        self.lowY = lowY
        self.centerX = centerX
        self.width = width
        self.source = source
    }
}

public struct KXFN223VolumeBarSnapshot: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let index: Int
    public let openTime: Date
    public let volume: KXDecimal
    public let quoteVolume: KXDecimal?
    public let tradeCount: Int?
    public let direction: KXFN223CandleDirection
    public let centerX: Double?
    public let heightRatio: Double
    public let height: Double?

    public init(
        id: String,
        index: Int,
        openTime: Date,
        volume: KXDecimal,
        quoteVolume: KXDecimal? = nil,
        tradeCount: Int? = nil,
        direction: KXFN223CandleDirection,
        centerX: Double?,
        heightRatio: Double,
        height: Double? = nil
    ) {
        self.id = id
        self.index = index
        self.openTime = openTime
        self.volume = volume
        self.quoteVolume = quoteVolume
        self.tradeCount = tradeCount
        self.direction = direction
        self.centerX = centerX
        self.heightRatio = heightRatio
        self.height = height
    }
}

public struct KXFN223CandleSeriesSnapshot: Codable, Equatable, Sendable {
    public let candles: [KXFN223CandleBarSnapshot]
    public let visibleWindow: KLVisibleWindow
    public let priceRange: KLPriceRange?

    public init(candles: [KXFN223CandleBarSnapshot], visibleWindow: KLVisibleWindow, priceRange: KLPriceRange?) {
        self.candles = candles
        self.visibleWindow = visibleWindow
        self.priceRange = priceRange
    }
}

public struct KXFN223VolumeSeriesSnapshot: Codable, Equatable, Sendable {
    public let bars: [KXFN223VolumeBarSnapshot]
    public let maxVolume: KXDecimal
    public let totalVolume: KXDecimal

    public init(bars: [KXFN223VolumeBarSnapshot], maxVolume: KXDecimal, totalVolume: KXDecimal) {
        self.bars = bars
        self.maxVolume = maxVolume
        self.totalVolume = totalVolume
    }
}

// MARK: - 标记与叠加层 DTO

public struct KXFN223MarkerSnapshot: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let descriptor: KLMarkerDescriptor
    public let isVisible: Bool
    public let point: KLChartPoint?

    public init(id: String, descriptor: KLMarkerDescriptor, isVisible: Bool, point: KLChartPoint?) {
        self.id = id
        self.descriptor = descriptor
        self.isVisible = isVisible
        self.point = point
    }
}

public enum KXFN223OverlayKind: String, Codable, Sendable, CaseIterable {
    case marker
    case priceLine
    case indicatorLine
    case band
    case backgroundRegion
    case custom
}

public struct KXFN223OverlayPointSnapshot: Codable, Equatable, Sendable {
    public let coordinate: KLChartCoordinate
    public let point: KLChartPoint?
    public let label: String?

    public init(coordinate: KLChartCoordinate, point: KLChartPoint? = nil, label: String? = nil) {
        self.coordinate = coordinate
        self.point = point
        self.label = label
    }
}

public struct KXFN223OverlaySnapshot: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: KXFN223OverlayKind
    public let title: String
    public let points: [KXFN223OverlayPointSnapshot]
    public let style: KLMarkerStyleDescriptor?
    public let isVisible: Bool

    public init(
        id: String,
        kind: KXFN223OverlayKind,
        title: String,
        points: [KXFN223OverlayPointSnapshot],
        style: KLMarkerStyleDescriptor? = nil,
        isVisible: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.points = points
        self.style = style
        self.isVisible = isVisible
    }
}

// MARK: - 数据质量摘要 DTO

public struct KXFN223DataQualitySummary: Codable, Equatable, Sendable {
    public let totalInputCount: Int
    public let visibleCandleCount: Int
    public let closedCandleCount: Int
    public let openCandleCount: Int
    public let invalidOHLCCount: Int
    public let negativeVolumeCount: Int
    public let missingCloseTimeCount: Int
    public let duplicateOpenTimeCount: Int
    public let nonMonotonicTimeCount: Int
    public let firstOpenTime: Date?
    public let lastOpenTime: Date?
    public let hasDataGapRisk: Bool

    public init(
        totalInputCount: Int,
        visibleCandleCount: Int,
        closedCandleCount: Int,
        openCandleCount: Int,
        invalidOHLCCount: Int,
        negativeVolumeCount: Int,
        missingCloseTimeCount: Int,
        duplicateOpenTimeCount: Int,
        nonMonotonicTimeCount: Int,
        firstOpenTime: Date?,
        lastOpenTime: Date?,
        hasDataGapRisk: Bool
    ) {
        self.totalInputCount = totalInputCount
        self.visibleCandleCount = visibleCandleCount
        self.closedCandleCount = closedCandleCount
        self.openCandleCount = openCandleCount
        self.invalidOHLCCount = invalidOHLCCount
        self.negativeVolumeCount = negativeVolumeCount
        self.missingCloseTimeCount = missingCloseTimeCount
        self.duplicateOpenTimeCount = duplicateOpenTimeCount
        self.nonMonotonicTimeCount = nonMonotonicTimeCount
        self.firstOpenTime = firstOpenTime
        self.lastOpenTime = lastOpenTime
        self.hasDataGapRisk = hasDataGapRisk
    }
}

// MARK: - UI图表完整快照

public struct KXFN223ChartDataSnapshot: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let visibleWindow: KLVisibleWindow
    public let candleSeries: KXFN223CandleSeriesSnapshot
    public let volumeSeries: KXFN223VolumeSeriesSnapshot
    public let markers: [KXFN223MarkerSnapshot]
    public let overlays: [KXFN223OverlaySnapshot]
    public let status: KXFN223ChartStatusSnapshot
    public let qualitySummary: KXFN223DataQualitySummary
    public let generatedAt: Date

    public init(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        visibleWindow: KLVisibleWindow,
        candleSeries: KXFN223CandleSeriesSnapshot,
        volumeSeries: KXFN223VolumeSeriesSnapshot,
        markers: [KXFN223MarkerSnapshot],
        overlays: [KXFN223OverlaySnapshot],
        status: KXFN223ChartStatusSnapshot,
        qualitySummary: KXFN223DataQualitySummary,
        generatedAt: Date = Date()
    ) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.visibleWindow = visibleWindow
        self.candleSeries = candleSeries
        self.volumeSeries = volumeSeries
        self.markers = markers
        self.overlays = overlays
        self.status = status
        self.qualitySummary = qualitySummary
        self.generatedAt = generatedAt
    }
}

// MARK: - UI图表接口适配器

public struct KXFN223ChartDataAdapter: Sendable {
    public init() {}

    /// 基于 KL-02 公共类型生成 UI 图表完整快照。
    /// - 注意：该方法只做内存内 DTO 转换与坐标快照计算，不请求网络、不读写数据库、不绘制 UI、不做真实缓存。
    public func makeSnapshot(
        candles: [KLCandlePoint],
        visibleWindow: KLVisibleWindow,
        markers: [KLMarkerDescriptor] = [],
        overlays: [KXFN223OverlaySnapshot] = [],
        loadingState: KXFN223ChartLoadingState = .loaded,
        error: KXFN223ChartErrorSnapshot? = nil,
        generatedAt: Date = Date()
    ) -> KXFN223ChartDataSnapshot {
        let visibleCandles = Self.visibleCandles(from: candles, in: visibleWindow)
        let candleBars = Self.makeCandleBars(from: visibleCandles, in: visibleWindow)
        let volumeSeries = Self.makeVolumeSeries(from: visibleCandles, in: visibleWindow)
        let markerSnapshots = Self.makeMarkerSnapshots(from: markers, in: visibleWindow)
        let autoMarkerOverlay = Self.makeMarkerOverlay(from: markerSnapshots)
        let allOverlays = autoMarkerOverlay.map { [$0] } ?? [] + overlays
        let quality = Self.makeQualitySummary(inputCandles: candles, visibleCandles: visibleCandles.map(\.candle))
        let effectiveState = Self.effectiveLoadingState(requested: loadingState, hasVisibleCandles: !candleBars.isEmpty, hasError: error != nil)
        let status = KXFN223ChartStatusSnapshot(
            loadingState: effectiveState,
            emptyState: KXFN223ChartEmptyStateSnapshot(
                isEmpty: candleBars.isEmpty,
                title: candleBars.isEmpty ? "暂无 K线数据" : "K线数据已就绪",
                message: candleBars.isEmpty ? "当前可视窗口没有可展示的蜡烛数据" : nil
            ),
            error: error,
            generatedAt: generatedAt
        )
        let candleSeries = KXFN223CandleSeriesSnapshot(
            candles: candleBars,
            visibleWindow: visibleWindow,
            priceRange: visibleWindow.priceRange
        )

        return KXFN223ChartDataSnapshot(
            symbol: visibleWindow.symbol,
            timeframe: visibleWindow.timeframe,
            visibleWindow: visibleWindow,
            candleSeries: candleSeries,
            volumeSeries: volumeSeries,
            markers: markerSnapshots,
            overlays: allOverlays,
            status: status,
            qualitySummary: quality,
            generatedAt: generatedAt
        )
    }

    /// 仅生成蜡烛序列 DTO，便于 UI 局部刷新蜡烛层。
    public func makeCandleSeries(candles: [KLCandlePoint], visibleWindow: KLVisibleWindow) -> KXFN223CandleSeriesSnapshot {
        let visibleCandles = Self.visibleCandles(from: candles, in: visibleWindow)
        return KXFN223CandleSeriesSnapshot(
            candles: Self.makeCandleBars(from: visibleCandles, in: visibleWindow),
            visibleWindow: visibleWindow,
            priceRange: visibleWindow.priceRange
        )
    }

    /// 仅生成成交量序列 DTO，便于 UI 局部刷新成交量层。
    public func makeVolumeSeries(candles: [KLCandlePoint], visibleWindow: KLVisibleWindow) -> KXFN223VolumeSeriesSnapshot {
        Self.makeVolumeSeries(from: Self.visibleCandles(from: candles, in: visibleWindow), in: visibleWindow)
    }

    /// 仅生成标记 DTO，便于 UI 局部刷新标记层。
    public func makeMarkerSnapshots(markers: [KLMarkerDescriptor], visibleWindow: KLVisibleWindow) -> [KXFN223MarkerSnapshot] {
        Self.makeMarkerSnapshots(from: markers, in: visibleWindow)
    }
}

// MARK: - 内部纯计算辅助

private struct KXFN223IndexedCandle: Sendable {
    let index: Int
    let candle: KLCandlePoint
}

private extension KXFN223ChartDataAdapter {
    static func visibleCandles(from candles: [KLCandlePoint], in window: KLVisibleWindow) -> [KXFN223IndexedCandle] {
        candles.enumerated().compactMap { offset, candle in
            guard candle.symbol == window.symbol, candle.timeframe == window.timeframe else { return nil }
            guard offset >= window.indexRange.startIndex, offset <= window.indexRange.endIndex else { return nil }
            if let timeRange = window.timeRange {
                guard candle.openTime >= timeRange.startTime, candle.openTime <= timeRange.endTime else { return nil }
            }
            return KXFN223IndexedCandle(index: offset, candle: candle)
        }
    }

    static func makeCandleBars(from indexedCandles: [KXFN223IndexedCandle], in window: KLVisibleWindow) -> [KXFN223CandleBarSnapshot] {
        indexedCandles.map { item in
            let candle = item.candle
            let openY = y(forPrice: candle.open, in: window)
            let closeY = y(forPrice: candle.close, in: window)
            let highY = y(forPrice: candle.high, in: window)
            let lowY = y(forPrice: candle.low, in: window)
            let bodyTopY: Double?
            let bodyBottomY: Double?

            if let openY, let closeY {
                bodyTopY = min(openY, closeY)
                bodyBottomY = max(openY, closeY)
            } else {
                bodyTopY = nil
                bodyBottomY = nil
            }

            return KXFN223CandleBarSnapshot(
                id: candle.id ?? "\(candle.symbol)-\(candle.timeframe.rawValue)-\(item.index)-\(Int(candle.openTime.timeIntervalSince1970))",
                sourceCandleID: candle.id,
                index: item.index,
                symbol: candle.symbol,
                timeframe: candle.timeframe,
                openTime: candle.openTime,
                closeTime: candle.closeTime,
                open: candle.open,
                high: candle.high,
                low: candle.low,
                close: candle.close,
                direction: direction(open: candle.open, close: candle.close),
                isClosed: candle.isClosed,
                bodyTopY: bodyTopY,
                bodyBottomY: bodyBottomY,
                highY: highY,
                lowY: lowY,
                centerX: x(forIndex: item.index, in: window),
                width: max(0, window.candleWidth),
                source: candle.source
            )
        }
    }

    static func makeVolumeSeries(from indexedCandles: [KXFN223IndexedCandle], in window: KLVisibleWindow) -> KXFN223VolumeSeriesSnapshot {
        let volumes = indexedCandles.map { $0.candle.volume }
        let maxVolume = volumes.max() ?? 0
        let totalVolume = volumes.reduce(KXDecimal(0), +)
        let maxVolumeDouble = max(0, double(from: maxVolume))
        let volumeViewportHeight = max(0, window.viewportHeight * 0.22)

        let bars = indexedCandles.map { item in
            let candle = item.candle
            let rawVolume = max(0, double(from: candle.volume))
            let ratio = maxVolumeDouble > 0 ? min(rawVolume / maxVolumeDouble, 1) : 0
            let height = volumeViewportHeight > 0 ? ratio * volumeViewportHeight : nil

            return KXFN223VolumeBarSnapshot(
                id: "volume-\(candle.id ?? "\(item.index)-\(Int(candle.openTime.timeIntervalSince1970))")",
                index: item.index,
                openTime: candle.openTime,
                volume: candle.volume,
                quoteVolume: candle.quoteVolume,
                tradeCount: candle.tradeCount,
                direction: direction(open: candle.open, close: candle.close),
                centerX: x(forIndex: item.index, in: window),
                heightRatio: ratio,
                height: height
            )
        }

        return KXFN223VolumeSeriesSnapshot(bars: bars, maxVolume: maxVolume, totalVolume: totalVolume)
    }

    static func makeMarkerSnapshots(from markers: [KLMarkerDescriptor], in window: KLVisibleWindow) -> [KXFN223MarkerSnapshot] {
        markers
            .filter { $0.symbol == window.symbol && $0.timeframe == window.timeframe }
            .map { marker in
                let point = point(for: marker.coordinate, in: window)
                let visible = isCoordinateVisible(marker.coordinate, point: point, in: window)
                return KXFN223MarkerSnapshot(id: marker.id, descriptor: marker, isVisible: visible, point: point)
            }
    }

    static func makeMarkerOverlay(from markerSnapshots: [KXFN223MarkerSnapshot]) -> KXFN223OverlaySnapshot? {
        let visibleMarkers = markerSnapshots.filter(\.isVisible)
        guard !visibleMarkers.isEmpty else { return nil }

        return KXFN223OverlaySnapshot(
            id: "marker-overlay",
            kind: .marker,
            title: "标记层",
            points: visibleMarkers.map { marker in
                KXFN223OverlayPointSnapshot(
                    coordinate: marker.descriptor.coordinate,
                    point: marker.point,
                    label: marker.descriptor.title
                )
            },
            style: nil,
            isVisible: true
        )
    }

    static func makeQualitySummary(inputCandles: [KLCandlePoint], visibleCandles: [KLCandlePoint]) -> KXFN223DataQualitySummary {
        var invalidOHLCCount = 0
        var negativeVolumeCount = 0
        var missingCloseTimeCount = 0
        var duplicateOpenTimeCount = 0
        var nonMonotonicTimeCount = 0
        var seenOpenTimes = Set<Date>()
        var previousOpenTime: Date?

        for candle in inputCandles {
            let prices = [candle.open, candle.high, candle.low, candle.close]
            if prices.contains(where: { !decimalIsFinite($0) }) || candle.high < candle.low || candle.open > candle.high || candle.open < candle.low || candle.close > candle.high || candle.close < candle.low {
                invalidOHLCCount += 1
            }
            if candle.volume < 0 {
                negativeVolumeCount += 1
            }
            if candle.isClosed && candle.closeTime == nil {
                missingCloseTimeCount += 1
            }
            if seenOpenTimes.contains(candle.openTime) {
                duplicateOpenTimeCount += 1
            } else {
                seenOpenTimes.insert(candle.openTime)
            }
            if let previousOpenTime, candle.openTime < previousOpenTime {
                nonMonotonicTimeCount += 1
            }
            previousOpenTime = candle.openTime
        }

        return KXFN223DataQualitySummary(
            totalInputCount: inputCandles.count,
            visibleCandleCount: visibleCandles.count,
            closedCandleCount: visibleCandles.filter(\.isClosed).count,
            openCandleCount: visibleCandles.filter { !$0.isClosed }.count,
            invalidOHLCCount: invalidOHLCCount,
            negativeVolumeCount: negativeVolumeCount,
            missingCloseTimeCount: missingCloseTimeCount,
            duplicateOpenTimeCount: duplicateOpenTimeCount,
            nonMonotonicTimeCount: nonMonotonicTimeCount,
            firstOpenTime: visibleCandles.first?.openTime,
            lastOpenTime: visibleCandles.last?.openTime,
            hasDataGapRisk: duplicateOpenTimeCount > 0 || nonMonotonicTimeCount > 0
        )
    }

    static func effectiveLoadingState(requested: KXFN223ChartLoadingState, hasVisibleCandles: Bool, hasError: Bool) -> KXFN223ChartLoadingState {
        if hasError { return .failed }
        if !hasVisibleCandles, requested == .loaded { return .empty }
        return requested
    }

    static func direction(open: KXDecimal, close: KXDecimal) -> KXFN223CandleDirection {
        if close > open { return .rise }
        if close < open { return .fall }
        return .flat
    }

    static func x(forIndex index: Int, in window: KLVisibleWindow) -> Double? {
        guard window.indexRange.startIndex <= window.indexRange.endIndex else { return nil }
        guard window.candleWidth.isFinite, window.candleWidth > 0 else { return nil }
        guard window.contentOffsetX.isFinite else { return nil }
        return (Double(index - window.indexRange.startIndex) + 0.5) * window.candleWidth - window.contentOffsetX
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

        let y = (maxPrice - priceValue) / range * window.viewportHeight
        return y.isFinite ? y : nil
    }

    static func point(for coordinate: KLChartCoordinate, in window: KLVisibleWindow) -> KLChartPoint? {
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

    static func isCoordinateVisible(_ coordinate: KLChartCoordinate, point: KLChartPoint?, in window: KLVisibleWindow) -> Bool {
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
            return point.x.isFinite && point.y.isFinite
        }
        return coordinate.index != nil || coordinate.time != nil || coordinate.price != nil
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

        let count = max(window.indexRange.endIndex - window.indexRange.startIndex, 0)
        let ratio = (value - start) / (end - start)
        return window.indexRange.startIndex + Int((ratio * Double(count)).rounded())
    }

    static func decimalIsFinite(_ decimal: KXDecimal) -> Bool {
        double(from: decimal).isFinite
    }

    static func double(from decimal: KXDecimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN23Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-23", fileName: "KX-FN-23_UI图表数据接口.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-23_UI图表数据接口.swift", duty: "向UI提供蜡烛、成交量、标记、叠加层、状态数据"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("UI图表数据接口骨架校验通过")
        return KXHealthCheckItem(name: "UI图表数据接口", passed: true, message: "已实现UI图表数据接口定义")
    }
}

// MARK: - 外部标准标记接入 UI 图表数据快照

public extension KXFN223ChartDataAdapter {
    /// 把外部模块已提交的标准标记合并进 UI 图表数据快照。
    /// 约束：K线模块不主动运行形态识别算法，只消费标准 KLMarkerDescriptor。
    func makeSnapshotWithExternalMarkers(
        candles: [KLCandlePoint],
        visibleWindow: KLVisibleWindow,
        markers: [KLMarkerDescriptor] = [],
        overlays: [KXFN223OverlaySnapshot] = [],
        loadingState: KXFN223ChartLoadingState = .loaded,
        error: KXFN223ChartErrorSnapshot? = nil,
        generatedAt: Date = Date()
    ) -> KXFN223ChartDataSnapshot {
        makeSnapshot(
            candles: candles,
            visibleWindow: visibleWindow,
            markers: markers,
            overlays: overlays,
            loadingState: loadingState,
            error: error,
            generatedAt: generatedAt
        )
    }
}
