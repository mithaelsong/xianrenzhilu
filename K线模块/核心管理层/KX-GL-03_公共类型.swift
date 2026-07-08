//
//  KX-GL-03_公共类型.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：公共类型、公共协议、错误类型、数据模型、描述符、协议签名、初始化器
//  禁止事项：禁止 class、actor、extension、顶层功能函数、顶层 let/var、业务实现
//

import Foundation

// MARK: - 指标模块公共类型

public enum KXIndicatorCategory: String, Codable, Sendable, CaseIterable {
    case trend = "趋势指标"
    case oscillator = "震荡指标"
    case volume = "成交量指标"
    case volatility = "波动率指标"
    case onChain = "链上指标"
    case statistics = "统计指标"
    case custom = "自定义指标"

    public static let displayOrder: [KXIndicatorCategory] = [
        .trend,
        .oscillator,
        .volume,
        .volatility,
        .onChain,
        .statistics,
        .custom
    ]
}

public struct KXIndicatorParameters: Codable, Equatable, Sendable {
    public var values: [String: Double]

    public init(values: [String: Double] = [:]) {
        self.values = values
    }
}

public struct KXIndicatorResult: Codable, Equatable, Sendable {
    /// 单线兼容输出：一个指标实例只有一条输出序列时使用。
    public let values: [Double?]
    /// 多输出兼容：一个指标实例产生多条序列（如 KDJ 的 K/D/J、MACD 的 DIF/DEA/柱状）。
    /// key 为输出名，value 为对应索引的数值数组，长度应与输入 candles 一致。
    public let namedValues: [String: [Double?]]?
    public let signals: [KXSignal]

    public init(values: [Double?] = [], namedValues: [String: [Double?]]? = nil, signals: [KXSignal] = []) {
        self.values = values
        self.namedValues = namedValues
        self.signals = signals
    }
}

public enum KXSignalType: String, Codable, Sendable, CaseIterable {
    case buy
    case sell
    case strongBuy
    case strongSell
    case none
}

public struct KXSignal: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let index: Int
    public let type: KXSignalType
    public let price: KXDecimal
    public let time: KXTimestamp?

    public init(id: String = UUID().uuidString, index: Int, type: KXSignalType, price: KXDecimal, time: KXTimestamp? = nil) {
        self.id = id
        self.index = index
        self.type = type
        self.price = price
        self.time = time
    }

    private enum CodingKeys: String, CodingKey {
        case id, index, type, price, time
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.index = try container.decode(Int.self, forKey: .index)
        self.type = try container.decode(KXSignalType.self, forKey: .type)
        self.price = try container.decode(KXDecimal.self, forKey: .price)
        self.time = try container.decodeIfPresent(KXTimestamp.self, forKey: .time)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(index, forKey: .index)
        try container.encode(type, forKey: .type)
        try container.encode(price, forKey: .price)
        try container.encodeIfPresent(time, forKey: .time)
    }
}

public protocol KXIndicatorProtocol: Sendable {
    func calculate(for candles: [KXCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult
    /// 老指标默认参数表，供 UI/适配器构造可调 parameterSchema。
    var defaultParameterValues: [String: Double] { get }
    /// 指标参数（专业指标实例管理器需要访问）
    var parameters: KXIndicatorParameters { get }
}

extension KXIndicatorProtocol {
    public static var defaultParameters: KXIndicatorParameters {
        KXIndicatorParameters()
    }

    public var defaultParameterValues: [String: Double] {
        [:]
    }

    public var parameters: KXIndicatorParameters {
        KXIndicatorParameters(values: defaultParameterValues)
    }
}

// MARK: - 版本

public struct KXVersion: Codable, Equatable, Sendable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int

    public init(major: Int = 2, minor: Int = 0) {
        self.major = major
        self.minor = minor
    }

    public init(string: String) {
        let parts = string.split(separator: ".")
        major = parts.count > 0 ? Int(parts[0]) ?? 2 : 2
        minor = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
    }

    public var description: String { "\(major).\(minor)" }

    public static func < (lhs: KXVersion, rhs: KXVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        return lhs.minor < rhs.minor
    }

    public static let current = KXVersion(major: 2, minor: 0)
}

// MARK: - 基础标识

public typealias KXSymbol = String
public typealias KXExchangeID = String
public typealias KXInstrumentID = String
public typealias KXCandleID = String
public typealias KXDecimal = Decimal
public typealias KXTimestamp = Date

public enum KXModuleLayer: String, Codable, Sendable, CaseIterable {
    case management = "管理层"
    case function = "功能层"
    case interface = "接口层"
    case data = "数据层"
    case cache = "缓存层"
    case sync = "同步层"
    case ui = "UI组件层"
    case favorite = "收藏层"
    case marker = "标记层"
    case indicator = "指标层"
    case alert = "提示音事件层"
    case uiAdapter = "UI数据适配层"
    case utility = "工具层"
}

// MARK: - 指标模块公共类型

public struct KXTechnicalIndicator: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let category: KXIndicatorCategory
    public let description: String
    public let formula: String

    public init(id: String, name: String, category: KXIndicatorCategory, description: String, formula: String) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.formula = formula
    }
}

public struct KXFileDescriptor: Codable, Equatable, Sendable {
    public let id: String
    public let fileName: String
    public let layer: KXModuleLayer
    public let relativePath: String
    public let version: KXVersion
    public let duty: String
    public let required: Bool

    public init(id: String, fileName: String, layer: KXModuleLayer, relativePath: String, version: KXVersion = .current, duty: String, required: Bool = true) {
        self.id = id
        self.fileName = fileName
        self.layer = layer
        self.relativePath = relativePath
        self.version = version
        self.duty = duty
        self.required = required
    }
}

// MARK: - 周期与交易对

public enum KXTimeframe: String, Codable, Sendable, CaseIterable {
    case oneSecond = "1s"
    case oneMinute = "1m"
    case threeMinutes = "3m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case oneHour = "1h"
    case twoHours = "2h"
    case fourHours = "4h"
    case sixHours = "6h"
    case twelveHours = "12h"
    case oneDay = "1d"
    case twoDays = "2d"
    case threeDays = "3d"
    case oneWeek = "1w"
    case oneMonth = "1M"
    case threeMonths = "3M"
}

public enum KXTimeframeUnit: String, Codable, Sendable, CaseIterable {
    case second
    case minute
    case hour
    case day
    case week
    case month
}

public struct KXTimeframeDescriptor: Codable, Equatable, Sendable {
    public let timeframe: KXTimeframe
    public let unit: KXTimeframeUnit
    public let amount: Int
    public let seconds: Int
    public let displayName: String
    public let exchangeValue: String
    public let isRealtimeSupported: Bool

    public init(timeframe: KXTimeframe, unit: KXTimeframeUnit, amount: Int, seconds: Int, displayName: String, exchangeValue: String, isRealtimeSupported: Bool = true) {
        self.timeframe = timeframe
        self.unit = unit
        self.amount = amount
        self.seconds = seconds
        self.displayName = displayName
        self.exchangeValue = exchangeValue
        self.isRealtimeSupported = isRealtimeSupported
    }
}

public enum KXMarketType: String, Codable, Sendable, CaseIterable {
    case spot
    case margin
    case futures
    case swap
    case option
}

public enum KXTradingPairStatus: String, Codable, Sendable, CaseIterable {
    case online
    case suspended
    case delisted
    case unknown
}

public struct KXTradingPairDescriptor: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let baseCurrency: String
    public let quoteCurrency: String
    public let exchangeID: KXExchangeID
    public let instrumentID: KXInstrumentID
    public let marketType: KXMarketType
    public let status: KXTradingPairStatus
    public let pricePrecision: Int
    public let quantityPrecision: Int
    public let minOrderSize: KXDecimal?
    public let displayName: String

    public init(symbol: KXSymbol, baseCurrency: String, quoteCurrency: String, exchangeID: KXExchangeID, instrumentID: KXInstrumentID, marketType: KXMarketType, status: KXTradingPairStatus = .unknown, pricePrecision: Int = 0, quantityPrecision: Int = 0, minOrderSize: KXDecimal? = nil, displayName: String) {
        self.symbol = symbol
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.exchangeID = exchangeID
        self.instrumentID = instrumentID
        self.marketType = marketType
        self.status = status
        self.pricePrecision = pricePrecision
        self.quantityPrecision = quantityPrecision
        self.minOrderSize = minOrderSize
        self.displayName = displayName
    }
}

// MARK: - K线点、成交与查询

public struct KXCandlePoint: Codable, Equatable, Sendable {
    public let id: KXCandleID?
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let openTime: Date
    public let closeTime: Date?
    public let open: KXDecimal
    public let high: KXDecimal
    public let low: KXDecimal
    public let close: KXDecimal
    public let volume: KXDecimal
    public let quoteVolume: KXDecimal?
    public let tradeCount: Int?
    public let isClosed: Bool
    public let source: String?

    public init(id: KXCandleID? = nil, symbol: KXSymbol, timeframe: KXTimeframe, openTime: Date, closeTime: Date? = nil, open: KXDecimal, high: KXDecimal, low: KXDecimal, close: KXDecimal, volume: KXDecimal, quoteVolume: KXDecimal? = nil, tradeCount: Int? = nil, isClosed: Bool, source: String? = nil) {
        self.id = id
        self.symbol = symbol
        self.timeframe = timeframe
        self.openTime = openTime
        self.closeTime = closeTime
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.quoteVolume = quoteVolume
        self.tradeCount = tradeCount
        self.isClosed = isClosed
        self.source = source
    }
}

public struct KXTradeTick: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let tradeID: String
    public let price: KXDecimal
    public let size: KXDecimal
    public let side: KXTradeSide
    public let timestamp: Date

    public init(symbol: KXSymbol, tradeID: String, price: KXDecimal, size: KXDecimal, side: KXTradeSide, timestamp: Date) {
        self.symbol = symbol
        self.tradeID = tradeID
        self.price = price
        self.size = size
        self.side = side
        self.timestamp = timestamp
    }
}

public enum KXTradeSide: String, Codable, Sendable, CaseIterable {
    case buy
    case sell
    case unknown
}

public enum KXQuerySortOrder: String, Codable, Sendable, CaseIterable {
    case ascending
    case descending
}

public struct KXKLineQuery: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let startTime: Date?
    public let endTime: Date?
    public let limit: Int?
    public let order: KXQuerySortOrder
    public let includeUnclosed: Bool

    public init(symbol: KXSymbol, timeframe: KXTimeframe, startTime: Date? = nil, endTime: Date? = nil, limit: Int? = nil, order: KXQuerySortOrder = .ascending, includeUnclosed: Bool = true) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.startTime = startTime
        self.endTime = endTime
        self.limit = limit
        self.order = order
        self.includeUnclosed = includeUnclosed
    }
}

public struct KXCandleSeries: Codable, Equatable, Sendable {
    public let query: KXKLineQuery
    public let candles: [KXCandlePoint]
    public let generatedAt: Date
    public let quality: KXDataQuality

    public init(query: KXKLineQuery, candles: [KXCandlePoint], generatedAt: Date = Date(), quality: KXDataQuality = .unknown) {
        self.query = query
        self.candles = candles
        self.generatedAt = generatedAt
        self.quality = quality
    }
}

public enum KXDataQuality: String, Codable, Sendable, CaseIterable {
    case complete
    case partial
    case stale
    case invalid
    case unknown
}

// MARK: - 缺口、补洞与同步

public struct KXGapRange: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let startTime: Date
    public let endTime: Date
    public let expectedCount: Int
    public let actualCount: Int
    public let reason: String?

    public init(symbol: KXSymbol, timeframe: KXTimeframe, startTime: Date, endTime: Date, expectedCount: Int, actualCount: Int, reason: String? = nil) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.startTime = startTime
        self.endTime = endTime
        self.expectedCount = expectedCount
        self.actualCount = actualCount
        self.reason = reason
    }
}

public enum KXBackfillPriority: String, Codable, Sendable, CaseIterable {
    case low
    case normal
    case high
    case urgent
}

public struct KXBackfillTaskDescriptor: Codable, Equatable, Sendable {
    public let id: String
    public let gap: KXGapRange
    public let priority: KXBackfillPriority
    public let createdAt: Date
    public let retryCount: Int

    public init(id: String, gap: KXGapRange, priority: KXBackfillPriority = .normal, createdAt: Date = Date(), retryCount: Int = 0) {
        self.id = id
        self.gap = gap
        self.priority = priority
        self.createdAt = createdAt
        self.retryCount = retryCount
    }
}

public enum KXSyncState: String, Codable, Sendable, CaseIterable {
    case idle
    case syncing
    case paused
    case failed
    case completed
}

public struct KXSyncStatusDescriptor: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let state: KXSyncState
    public let lastSyncedAt: Date?
    public let lastError: String?
    public let progress: Double?

    public init(symbol: KXSymbol, timeframe: KXTimeframe, state: KXSyncState, lastSyncedAt: Date? = nil, lastError: String? = nil, progress: Double? = nil) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.state = state
        self.lastSyncedAt = lastSyncedAt
        self.lastError = lastError
        self.progress = progress
    }
}

public struct KXRetryPolicyDescriptor: Codable, Equatable, Sendable {
    public let maxRetries: Int
    public let baseDelaySeconds: Double
    public let maxDelaySeconds: Double
    public let jitterEnabled: Bool

    public init(maxRetries: Int = 3, baseDelaySeconds: Double = 1, maxDelaySeconds: Double = 30, jitterEnabled: Bool = true) {
        self.maxRetries = maxRetries
        self.baseDelaySeconds = baseDelaySeconds
        self.maxDelaySeconds = maxDelaySeconds
        self.jitterEnabled = jitterEnabled
    }
}

public struct KXRateLimitDescriptor: Codable, Equatable, Sendable {
    public let maxRequests: Int
    public let intervalSeconds: Double
    public let scope: String

    public init(maxRequests: Int, intervalSeconds: Double, scope: String) {
        self.maxRequests = maxRequests
        self.intervalSeconds = intervalSeconds
        self.scope = scope
    }
}

// MARK: - 缓存键与缓存描述

public enum KXCacheNamespace: String, Codable, Sendable, CaseIterable {
    case candles
    case timeframeIndex
    case visibleWindow
    case tradingPairs
    case markers
    case alerts
    case favorites
}

public struct KXCacheKey: Codable, Hashable, Sendable, CustomStringConvertible {
    public let namespace: KXCacheNamespace
    public let symbol: KXSymbol?
    public let timeframe: KXTimeframe?
    public let startTime: Date?
    public let endTime: Date?
    public let variant: String?

    public init(namespace: KXCacheNamespace, symbol: KXSymbol? = nil, timeframe: KXTimeframe? = nil, startTime: Date? = nil, endTime: Date? = nil, variant: String? = nil) {
        self.namespace = namespace
        self.symbol = symbol
        self.timeframe = timeframe
        self.startTime = startTime
        self.endTime = endTime
        self.variant = variant
    }

    public var description: String {
        [namespace.rawValue, symbol, timeframe?.rawValue, variant].compactMap { $0 }.joined(separator: ":")
    }
}

public struct KXCacheEntryDescriptor: Codable, Equatable, Sendable {
    public let key: KXCacheKey
    public let createdAt: Date
    public let expiresAt: Date?
    public let itemCount: Int
    public let byteSize: Int?
    public let quality: KXDataQuality

    public init(key: KXCacheKey, createdAt: Date = Date(), expiresAt: Date? = nil, itemCount: Int = 0, byteSize: Int? = nil, quality: KXDataQuality = .unknown) {
        self.key = key
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.itemCount = itemCount
        self.byteSize = byteSize
        self.quality = quality
    }
}

public struct KXCachePolicyDescriptor: Codable, Equatable, Sendable {
    public let maxItemCount: Int
    public let maxByteSize: Int?
    public let ttlSeconds: Double?
    public let evictWhenMemoryWarning: Bool

    public init(maxItemCount: Int, maxByteSize: Int? = nil, ttlSeconds: Double? = nil, evictWhenMemoryWarning: Bool = true) {
        self.maxItemCount = maxItemCount
        self.maxByteSize = maxByteSize
        self.ttlSeconds = ttlSeconds
        self.evictWhenMemoryWarning = evictWhenMemoryWarning
    }
}

// MARK: - 可视窗口与坐标模型

public struct KXIndexRange: Codable, Equatable, Sendable {
    public let startIndex: Int
    public let endIndex: Int

    public init(startIndex: Int, endIndex: Int) {
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

public struct KXPriceRange: Codable, Equatable, Sendable {
    public let minPrice: KXDecimal
    public let maxPrice: KXDecimal

    public init(minPrice: KXDecimal, maxPrice: KXDecimal) {
        self.minPrice = minPrice
        self.maxPrice = maxPrice
    }
}

public struct KXTimeRange: Codable, Equatable, Sendable {
    public let startTime: Date
    public let endTime: Date

    public init(startTime: Date, endTime: Date) {
        self.startTime = startTime
        self.endTime = endTime
    }
}

public struct KXVisibleWindow: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let indexRange: KXIndexRange
    public let timeRange: KXTimeRange?
    public let priceRange: KXPriceRange?
    public let candleWidth: Double
    public let contentOffsetX: Double
    public let viewportWidth: Double
    public let viewportHeight: Double

    public init(symbol: KXSymbol, timeframe: KXTimeframe, indexRange: KXIndexRange, timeRange: KXTimeRange? = nil, priceRange: KXPriceRange? = nil, candleWidth: Double, contentOffsetX: Double = 0, viewportWidth: Double, viewportHeight: Double) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.indexRange = indexRange
        self.timeRange = timeRange
        self.priceRange = priceRange
        self.candleWidth = candleWidth
        self.contentOffsetX = contentOffsetX
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
    }
}

public struct KXChartPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct KXChartCoordinate: Codable, Equatable, Sendable {
    public let time: Date?
    public let index: Int?
    public let price: KXDecimal?
    public let point: KXChartPoint?

    public init(time: Date? = nil, index: Int? = nil, price: KXDecimal? = nil, point: KXChartPoint? = nil) {
        self.time = time
        self.index = index
        self.price = price
        self.point = point
    }
}

public struct KXCrosshairSnapshot: Codable, Equatable, Sendable {
    public let coordinate: KXChartCoordinate
    public let candle: KXCandlePoint?
    public let visibleWindow: KXVisibleWindow

    public init(coordinate: KXChartCoordinate, candle: KXCandlePoint? = nil, visibleWindow: KXVisibleWindow) {
        self.coordinate = coordinate
        self.candle = candle
        self.visibleWindow = visibleWindow
    }
}

// MARK: - 标记基础模型

public enum KXMarkerKind: String, Codable, Sendable, CaseIterable {
    case pattern
    case manual
    case priceLevel
    case trendLine
    case note
    case signal
}

public enum KXMarkerSource: String, Codable, Sendable, CaseIterable {
    case system
    case patternRecognition
    case user
    case importSource
}

public enum KXMarkerSeverity: String, Codable, Sendable, CaseIterable {
    case info
    case low
    case medium
    case high
    case critical
}

public struct KXMarkerStyleDescriptor: Codable, Equatable, Sendable {
    public let colorHex: String
    public let iconName: String?
    public let lineWidth: Double?
    public let opacity: Double

    public init(colorHex: String, iconName: String? = nil, lineWidth: Double? = nil, opacity: Double = 1) {
        self.colorHex = colorHex
        self.iconName = iconName
        self.lineWidth = lineWidth
        self.opacity = opacity
    }
}

public struct KXMarkerDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let kind: KXMarkerKind
    public let source: KXMarkerSource
    public let severity: KXMarkerSeverity
    public let title: String
    public let message: String?
    public let coordinate: KXChartCoordinate
    public let style: KXMarkerStyleDescriptor?
    public let createdAt: Date

    public init(id: String, symbol: KXSymbol, timeframe: KXTimeframe, kind: KXMarkerKind, source: KXMarkerSource, severity: KXMarkerSeverity = .info, title: String, message: String? = nil, coordinate: KXChartCoordinate, style: KXMarkerStyleDescriptor? = nil, createdAt: Date = Date()) {
        self.id = id
        self.symbol = symbol
        self.timeframe = timeframe
        self.kind = kind
        self.source = source
        self.severity = severity
        self.title = title
        self.message = message
        self.coordinate = coordinate
        self.style = style
        self.createdAt = createdAt
    }
}

public struct KXMarkerOverlayDescriptor: Codable, Equatable, Sendable {
    public let visibleWindow: KXVisibleWindow
    public let markers: [KXMarkerDescriptor]
    public let generatedAt: Date

    public init(visibleWindow: KXVisibleWindow, markers: [KXMarkerDescriptor], generatedAt: Date = Date()) {
        self.visibleWindow = visibleWindow
        self.markers = markers
        self.generatedAt = generatedAt
    }
}

// MARK: - 提示音事件基础模型

public enum KXAlertKind: String, Codable, Sendable, CaseIterable {
    case patternSignal
    case priceBreakout
    case volumeAnomaly
    case syncFailure
    case custom
}

public enum KXAlertDirection: String, Codable, Sendable, CaseIterable {
    case above
    case below
    case crossUp
    case crossDown
    case any
}

public enum KXAlertDeliveryState: String, Codable, Sendable, CaseIterable {
    case pending
    case delivered
    case muted
    case failed
}

public struct KXSoundDescriptor: Codable, Equatable, Sendable {
    public let soundID: String
    public let displayName: String
    public let fileName: String?
    public let volume: Double
    public let repeatCount: Int

    public init(soundID: String, displayName: String, fileName: String? = nil, volume: Double = 1, repeatCount: Int = 1) {
        self.soundID = soundID
        self.displayName = displayName
        self.fileName = fileName
        self.volume = volume
        self.repeatCount = repeatCount
    }
}

public struct KXAlertRuleDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe?
    public let kind: KXAlertKind
    public let direction: KXAlertDirection
    public let thresholdPrice: KXDecimal?
    public let thresholdVolume: KXDecimal?
    public let sound: KXSoundDescriptor?
    public let enabled: Bool
    public let createdAt: Date

    public init(id: String, symbol: KXSymbol, timeframe: KXTimeframe? = nil, kind: KXAlertKind, direction: KXAlertDirection = .any, thresholdPrice: KXDecimal? = nil, thresholdVolume: KXDecimal? = nil, sound: KXSoundDescriptor? = nil, enabled: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.symbol = symbol
        self.timeframe = timeframe
        self.kind = kind
        self.direction = direction
        self.thresholdPrice = thresholdPrice
        self.thresholdVolume = thresholdVolume
        self.sound = sound
        self.enabled = enabled
        self.createdAt = createdAt
    }
}

public struct KXAlertEventDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let ruleID: String?
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe?
    public let kind: KXAlertKind
    public let title: String
    public let message: String
    public let occurredAt: Date
    public let deliveryState: KXAlertDeliveryState
    public let sound: KXSoundDescriptor?

    public init(id: String, ruleID: String? = nil, symbol: KXSymbol, timeframe: KXTimeframe? = nil, kind: KXAlertKind, title: String, message: String, occurredAt: Date = Date(), deliveryState: KXAlertDeliveryState = .pending, sound: KXSoundDescriptor? = nil) {
        self.id = id
        self.ruleID = ruleID
        self.symbol = symbol
        self.timeframe = timeframe
        self.kind = kind
        self.title = title
        self.message = message
        self.occurredAt = occurredAt
        self.deliveryState = deliveryState
        self.sound = sound
    }
}

// MARK: - 收藏、工作区与布局

public struct KXFavoriteTradingPair: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let pair: KXTradingPairDescriptor
    public let note: String?
    public let sortIndex: Int
    public let createdAt: Date

    public init(id: String, pair: KXTradingPairDescriptor, note: String? = nil, sortIndex: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.pair = pair
        self.note = note
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}

public struct KXTimeframeCombination: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let timeframes: [KXTimeframe]

    public init(id: String, name: String, timeframes: [KXTimeframe]) {
        self.id = id
        self.name = name
        self.timeframes = timeframes
    }
}

public struct KXIndicatorCombination: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let indicatorIDs: [String]

    public init(id: String, name: String, indicatorIDs: [String]) {
        self.id = id
        self.name = name
        self.indicatorIDs = indicatorIDs
    }
}

public struct KXWorkspaceDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let symbol: KXSymbol
    public let selectedTimeframe: KXTimeframe
    public let visibleWindow: KXVisibleWindow?
    public let indicatorCombinationID: String?

    public init(id: String, name: String, symbol: KXSymbol, selectedTimeframe: KXTimeframe, visibleWindow: KXVisibleWindow? = nil, indicatorCombinationID: String? = nil) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.selectedTimeframe = selectedTimeframe
        self.visibleWindow = visibleWindow
        self.indicatorCombinationID = indicatorCombinationID
    }
}

public struct KXLayoutTemplateDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let columnCount: Int
    public let rowCount: Int
    public let paneDescriptors: [KXLayoutPaneDescriptor]

    public init(id: String, name: String, columnCount: Int, rowCount: Int, paneDescriptors: [KXLayoutPaneDescriptor]) {
        self.id = id
        self.name = name
        self.columnCount = columnCount
        self.rowCount = rowCount
        self.paneDescriptors = paneDescriptors
    }
}

public struct KXLayoutPaneDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let symbol: KXSymbol?
    public let timeframe: KXTimeframe?
    public let row: Int
    public let column: Int
    public let rowSpan: Int
    public let columnSpan: Int

    public init(id: String, symbol: KXSymbol? = nil, timeframe: KXTimeframe? = nil, row: Int, column: Int, rowSpan: Int = 1, columnSpan: Int = 1) {
        self.id = id
        self.symbol = symbol
        self.timeframe = timeframe
        self.row = row
        self.column = column
        self.rowSpan = rowSpan
        self.columnSpan = columnSpan
    }
}

// MARK: - 数据库与接口描述

public struct KXDatabaseConnectionDescriptor: Codable, Equatable, Sendable {
    public let identifier: String
    public let databaseName: String
    public let schemaName: String
    public let readonly: Bool

    public init(identifier: String, databaseName: String, schemaName: String, readonly: Bool = false) {
        self.identifier = identifier
        self.databaseName = databaseName
        self.schemaName = schemaName
        self.readonly = readonly
    }
}

public struct KXTableDescriptor: Codable, Equatable, Sendable {
    public let name: String
    public let primaryKeys: [String]
    public let version: KXVersion
    public let duty: String

    public init(name: String, primaryKeys: [String], version: KXVersion = .current, duty: String) {
        self.name = name
        self.primaryKeys = primaryKeys
        self.version = version
        self.duty = duty
    }
}

public struct KXSubscriptionDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let exchangeID: KXExchangeID
    public let createdAt: Date

    public init(id: String, symbol: KXSymbol, timeframe: KXTimeframe, exchangeID: KXExchangeID, createdAt: Date = Date()) {
        self.id = id
        self.symbol = symbol
        self.timeframe = timeframe
        self.exchangeID = exchangeID
        self.createdAt = createdAt
    }
}

// MARK: - 日志工具
// 注意：完整的日志工具实现请参见 KX-UT-01_日志工具.swift

// MARK: - 健康报告与错误类型

public struct KXHealthCheckItem: Codable, Equatable, Sendable {
    public let name: String
    public let passed: Bool
    public let message: String
    public let severity: KXMarkerSeverity

    public init(name: String, passed: Bool, message: String, severity: KXMarkerSeverity = .info) {
        self.name = name
        self.passed = passed
        self.message = message
        self.severity = severity
    }
}

public struct KXHealthReport: Codable, Equatable, Sendable {
    public let moduleName: String
    public let version: KXVersion
    public let generatedAt: Date
    public let items: [KXHealthCheckItem]

    public var allPassed: Bool { items.allSatisfy { $0.passed } }

    public init(moduleName: String = "K线模块", version: KXVersion = .current, generatedAt: Date = Date(), items: [KXHealthCheckItem]) {
        self.moduleName = moduleName
        self.version = version
        self.generatedAt = generatedAt
        self.items = items
    }
}

public enum KXModuleError: Error, Codable, Equatable, Sendable {
    case missingFile(path: String)
    case duplicateRegistration(id: String)
    case invalidVersion(file: String, version: String)
    case boundaryViolation(path: String)
    case invalidTimeframe(value: String)
    case invalidSymbol(value: String)
    case invalidQuery(reason: String)
    case dataGap(range: KXGapRange)
    case cacheMiss(key: KXCacheKey)
    case syncFailed(reason: String)
    case databaseUnavailable(reason: String)
    case networkUnavailable(reason: String)
    case decodingFailed(reason: String)
    case notImplemented(file: String)
}

// MARK: - 公共协议签名

public protocol KXFileSkeletonProtocol {
    static var descriptor: KXFileDescriptor { get }
    static func skeletonStatus() -> KXHealthCheckItem
}

public protocol KXHealthReportingProtocol {
    func makeHealthReport() -> KXHealthReport
}

public protocol KXDataProviderProtocol {
    associatedtype Output
    func makePlaceholder() -> Output?
}

public protocol KXTradingPairDirectoryProtocol {
    func listTradingPairs() async throws -> [KXTradingPairDescriptor]
    func tradingPair(symbol: KXSymbol) async throws -> KXTradingPairDescriptor?
}

public protocol KXTimeframeCatalogProtocol {
    func listTimeframes() -> [KXTimeframeDescriptor]
    func descriptor(for timeframe: KXTimeframe) -> KXTimeframeDescriptor?
}

public protocol KXCandleDataSourceProtocol {
    func fetchCandles(query: KXKLineQuery) async throws -> [KXCandlePoint]
    func latestCandle(symbol: KXSymbol, timeframe: KXTimeframe) async throws -> KXCandlePoint?
}

public protocol KXCandleRepositoryProtocol {
    func saveCandles(_ candles: [KXCandlePoint]) async throws
    func loadCandles(query: KXKLineQuery) async throws -> [KXCandlePoint]
}

public protocol KXCacheStoreProtocol {
    associatedtype Value
    func value(for key: KXCacheKey) async throws -> Value?
    func store(_ value: Value, for key: KXCacheKey, policy: KXCachePolicyDescriptor?) async throws
    func removeValue(for key: KXCacheKey) async throws
}

public protocol KXGapDetectingProtocol {
    func detectGaps(query: KXKLineQuery, candles: [KXCandlePoint]) throws -> [KXGapRange]
}

public protocol KXBackfillTaskProvidingProtocol {
    func makeBackfillTasks(gaps: [KXGapRange], priority: KXBackfillPriority) -> [KXBackfillTaskDescriptor]
}

public protocol KXVisibleWindowSlicingProtocol {
    func slice(candles: [KXCandlePoint], window: KXVisibleWindow) -> [KXCandlePoint]
}

public protocol KXCoordinateMappingProtocol {
    func coordinate(for candle: KXCandlePoint, in window: KXVisibleWindow) -> KXChartCoordinate
    func candleIndex(at point: KXChartPoint, in window: KXVisibleWindow) -> Int?
}

public protocol KXMarkerProvidingProtocol {
    func markers(symbol: KXSymbol, timeframe: KXTimeframe, window: KXVisibleWindow?) async throws -> [KXMarkerDescriptor]
}

public protocol KXAlertEventProducingProtocol {
    func alertEvents(candle: KXCandlePoint, rules: [KXAlertRuleDescriptor]) throws -> [KXAlertEventDescriptor]
}

public protocol KXAlertEventConsumingProtocol {
    func consumeAlertEvent(_ event: KXAlertEventDescriptor) async throws
}

public protocol KXSyncStatusProvidingProtocol {
    func syncStatus(symbol: KXSymbol, timeframe: KXTimeframe) async throws -> KXSyncStatusDescriptor
}

// MARK: - KL前缀向后兼容别名

// 协议别名（KL→KX）
public typealias KLFileSkeletonProtocol = KXFileSkeletonProtocol
public typealias KLHealthReportingProtocol = KXHealthReportingProtocol
public typealias KLTradingPairDirectoryProtocol = KXTradingPairDirectoryProtocol
public typealias KLTimeframeCatalogProtocol = KXTimeframeCatalogProtocol
public typealias KLCandleDataSourceProtocol = KXCandleDataSourceProtocol
public typealias KLCandleRepositoryProtocol = KXCandleRepositoryProtocol
public typealias KLCacheStoreProtocol = KXCacheStoreProtocol
public typealias KLGapDetectingProtocol = KXGapDetectingProtocol
public typealias KLBackfillTaskProvidingProtocol = KXBackfillTaskProvidingProtocol
public typealias KLVisibleWindowSlicingProtocol = KXVisibleWindowSlicingProtocol
public typealias KLCoordinateMappingProtocol = KXCoordinateMappingProtocol
public typealias KLMarkerProvidingProtocol = KXMarkerProvidingProtocol
public typealias KLAlertEventProducingProtocol = KXAlertEventProducingProtocol
public typealias KLAlertEventConsumingProtocol = KXAlertEventConsumingProtocol
public typealias KLSyncStatusProvidingProtocol = KXSyncStatusProvidingProtocol

// 数据类型别名（KL→KX）
public typealias KLIndicatorCategory = KXIndicatorCategory
public typealias KLIndicatorParameters = KXIndicatorParameters
public typealias KLIndicatorResult = KXIndicatorResult
public typealias KLSignalType = KXSignalType
public typealias KLSignal = KXSignal
public typealias KLIndicatorProtocol = KXIndicatorProtocol

public typealias KLVersion = KXVersion

public typealias KLSymbol = KXSymbol
public typealias KLExchangeID = KXExchangeID
public typealias KLInstrumentID = KXInstrumentID
public typealias KLCandleID = KXCandleID
public typealias KLDecimal = KXDecimal
public typealias KLTimestamp = KXTimestamp

public typealias KLModuleLayer = KXModuleLayer

public typealias KLTechnicalIndicator = KXTechnicalIndicator
public typealias KLFileDescriptor = KXFileDescriptor

public typealias KLTimeframe = KXTimeframe
public typealias KLTimeframeUnit = KXTimeframeUnit
public typealias KLTimeframeDescriptor = KXTimeframeDescriptor

public typealias KLMarketType = KXMarketType
public typealias KLTradingPairStatus = KXTradingPairStatus
public typealias KLTradingPairDescriptor = KXTradingPairDescriptor

public typealias KLCandlePoint = KXCandlePoint
public typealias KLTradeTick = KXTradeTick
public typealias KLTradeSide = KXTradeSide
public typealias KLQuerySortOrder = KXQuerySortOrder
public typealias KLKLineQuery = KXKLineQuery
public typealias KLCandleSeries = KXCandleSeries
public typealias KLDataQuality = KXDataQuality

public typealias KLGapRange = KXGapRange
public typealias KLBackfillPriority = KXBackfillPriority
public typealias KLBackfillTaskDescriptor = KXBackfillTaskDescriptor
public typealias KLSyncState = KXSyncState
public typealias KLSyncStatusDescriptor = KXSyncStatusDescriptor
public typealias KLRetryPolicyDescriptor = KXRetryPolicyDescriptor
public typealias KLRateLimitDescriptor = KXRateLimitDescriptor

public typealias KLCacheNamespace = KXCacheNamespace
public typealias KLCacheKey = KXCacheKey
public typealias KLCacheEntryDescriptor = KXCacheEntryDescriptor
public typealias KLCachePolicyDescriptor = KXCachePolicyDescriptor

public typealias KLIndexRange = KXIndexRange
public typealias KLPriceRange = KXPriceRange
public typealias KLTimeRange = KXTimeRange
public typealias KLVisibleWindow = KXVisibleWindow
public typealias KLChartPoint = KXChartPoint
public typealias KLChartCoordinate = KXChartCoordinate
public typealias KLCrosshairSnapshot = KXCrosshairSnapshot

public typealias KLMarkerKind = KXMarkerKind
public typealias KLMarkerSource = KXMarkerSource
public typealias KLMarkerSeverity = KXMarkerSeverity
public typealias KLMarkerStyleDescriptor = KXMarkerStyleDescriptor
public typealias KLMarkerDescriptor = KXMarkerDescriptor
public typealias KLMarkerOverlayDescriptor = KXMarkerOverlayDescriptor

public typealias KLAlertKind = KXAlertKind
public typealias KLAlertDirection = KXAlertDirection
public typealias KLAlertDeliveryState = KXAlertDeliveryState
public typealias KLSoundDescriptor = KXSoundDescriptor
public typealias KLAlertRuleDescriptor = KXAlertRuleDescriptor
public typealias KLAlertEventDescriptor = KXAlertEventDescriptor

public typealias KLFavoriteTradingPair = KXFavoriteTradingPair
public typealias KLIndicatorCombination = KXIndicatorCombination
public typealias KLWorkspaceDescriptor = KXWorkspaceDescriptor
public typealias KLLayoutTemplateDescriptor = KXLayoutTemplateDescriptor
public typealias KLLayoutPaneDescriptor = KXLayoutPaneDescriptor

public typealias KLDatabaseConnectionDescriptor = KXDatabaseConnectionDescriptor
public typealias KLTableDescriptor = KXTableDescriptor
public typealias KLSubscriptionDescriptor = KXSubscriptionDescriptor

public typealias KLHealthCheckItem = KXHealthCheckItem
public typealias KLHealthReport = KXHealthReport
public typealias KLModuleError = KXModuleError
