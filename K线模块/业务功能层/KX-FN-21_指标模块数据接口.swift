//
//  KX-FN-21_指标模块数据接口.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：向指标模块提供标准 OHLCV 数据
//  禁止事项：禁止硬编码指标公式、禁止请求网络、禁止读写数据库、禁止 UI 绘制
//

import Foundation


// MARK: - 指标模块标准数据模型

public struct KLIndicatorOHLCVPoint: Codable, Equatable, Sendable {
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

    public init(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        openTime: Date,
        closeTime: Date? = nil,
        open: KXDecimal,
        high: KXDecimal,
        low: KXDecimal,
        close: KXDecimal,
        volume: KXDecimal,
        quoteVolume: KXDecimal? = nil,
        tradeCount: Int? = nil,
        isClosed: Bool
    ) {
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
    }
}

public struct KLIndicatorDataQualitySummary: Codable, Equatable, Sendable {
    public let quality: KLDataQuality
    public let sourceCount: Int
    public let acceptedCount: Int
    public let rejectedSymbolCount: Int
    public let rejectedTimeframeCount: Int
    public let rejectedBeforeStartCount: Int
    public let rejectedAfterEndCount: Int
    public let rejectedUnclosedCount: Int
    public let rejectedInvalidOHLCVCount: Int
    public let duplicateOpenTimeCount: Int
    public let unclosedIncludedCount: Int
    public let firstOpenTime: Date?
    public let lastOpenTime: Date?
    public let messages: [String]

    public init(
        quality: KLDataQuality,
        sourceCount: Int,
        acceptedCount: Int,
        rejectedSymbolCount: Int,
        rejectedTimeframeCount: Int,
        rejectedBeforeStartCount: Int,
        rejectedAfterEndCount: Int,
        rejectedUnclosedCount: Int,
        rejectedInvalidOHLCVCount: Int,
        duplicateOpenTimeCount: Int,
        unclosedIncludedCount: Int,
        firstOpenTime: Date?,
        lastOpenTime: Date?,
        messages: [String]
    ) {
        self.quality = quality
        self.sourceCount = sourceCount
        self.acceptedCount = acceptedCount
        self.rejectedSymbolCount = rejectedSymbolCount
        self.rejectedTimeframeCount = rejectedTimeframeCount
        self.rejectedBeforeStartCount = rejectedBeforeStartCount
        self.rejectedAfterEndCount = rejectedAfterEndCount
        self.rejectedUnclosedCount = rejectedUnclosedCount
        self.rejectedInvalidOHLCVCount = rejectedInvalidOHLCVCount
        self.duplicateOpenTimeCount = duplicateOpenTimeCount
        self.unclosedIncludedCount = unclosedIncludedCount
        self.firstOpenTime = firstOpenTime
        self.lastOpenTime = lastOpenTime
        self.messages = messages
    }
}

public struct KLIndicatorOHLCVSeries: Codable, Equatable, Sendable {
    public let query: KLKLineQuery
    public let points: [KLIndicatorOHLCVPoint]
    public let closePrices: [KXDecimal]
    public let volumes: [KXDecimal]
    public let qualitySummary: KLIndicatorDataQualitySummary
    public let generatedAt: Date

    public init(
        query: KLKLineQuery,
        points: [KLIndicatorOHLCVPoint],
        closePrices: [KXDecimal],
        volumes: [KXDecimal],
        qualitySummary: KLIndicatorDataQualitySummary,
        generatedAt: Date = Date()
    ) {
        self.query = query
        self.points = points
        self.closePrices = closePrices
        self.volumes = volumes
        self.qualitySummary = qualitySummary
        self.generatedAt = generatedAt
    }
}

public protocol KLIndicatorDataProvidingProtocol {
    func makeIndicatorOHLCVSeries(candles: [KLCandlePoint], query: KLKLineQuery) -> KLIndicatorOHLCVSeries
    func makeIndicatorClosePrices(candles: [KLCandlePoint], query: KLKLineQuery) -> [KXDecimal]
    func makeIndicatorVolumes(candles: [KLCandlePoint], query: KLKLineQuery) -> [KXDecimal]
    func makeIndicatorQualitySummary(candles: [KLCandlePoint], query: KLKLineQuery) -> KLIndicatorDataQualitySummary
}

// MARK: - 指标模块数据接口

public struct KXFN221IndicatorDataInterface: KLIndicatorDataProvidingProtocol {
    public init() {}

    public func makeIndicatorOHLCVSeries(candles: [KLCandlePoint], query: KLKLineQuery) -> KLIndicatorOHLCVSeries {
        Self.makeOHLCVSeries(candles: candles, query: query)
    }

    public func makeIndicatorClosePrices(candles: [KLCandlePoint], query: KLKLineQuery) -> [KXDecimal] {
        Self.makeClosePrices(candles: candles, query: query)
    }

    public func makeIndicatorVolumes(candles: [KLCandlePoint], query: KLKLineQuery) -> [KXDecimal] {
        Self.makeVolumes(candles: candles, query: query)
    }

    public func makeIndicatorQualitySummary(candles: [KLCandlePoint], query: KLKLineQuery) -> KLIndicatorDataQualitySummary {
        Self.makeOHLCVSeries(candles: candles, query: query).qualitySummary
    }

    public static func makeOHLCVSeries(candles: [KLCandlePoint], query: KLKLineQuery) -> KLIndicatorOHLCVSeries {
        let filteredResult = filterAndSort(candles: candles, query: query)
        let points = filteredResult.points.map { candle in
            KLIndicatorOHLCVPoint(
                symbol: candle.symbol,
                timeframe: candle.timeframe,
                openTime: candle.openTime,
                closeTime: candle.closeTime,
                open: candle.open,
                high: candle.high,
                low: candle.low,
                close: candle.close,
                volume: candle.volume,
                quoteVolume: candle.quoteVolume,
                tradeCount: candle.tradeCount,
                isClosed: candle.isClosed
            )
        }
        let closePrices = points.map { $0.close }
        let volumes = points.map { $0.volume }
        let qualitySummary = makeQualitySummary(candles: candles, acceptedPoints: points, counters: filteredResult.counters)

        return KLIndicatorOHLCVSeries(
            query: query,
            points: points,
            closePrices: closePrices,
            volumes: volumes,
            qualitySummary: qualitySummary
        )
    }

    public static func makeOHLCVSeries(series: KLCandleSeries) -> KLIndicatorOHLCVSeries {
        makeOHLCVSeries(candles: series.candles, query: series.query)
    }

    public static func makeClosePrices(candles: [KLCandlePoint], query: KLKLineQuery) -> [KXDecimal] {
        makeOHLCVSeries(candles: candles, query: query).closePrices
    }

    public static func makeVolumes(candles: [KLCandlePoint], query: KLKLineQuery) -> [KXDecimal] {
        makeOHLCVSeries(candles: candles, query: query).volumes
    }

    public static func makeQualitySummary(candles: [KLCandlePoint], query: KLKLineQuery) -> KLIndicatorDataQualitySummary {
        makeOHLCVSeries(candles: candles, query: query).qualitySummary
    }

    private static func filterAndSort(candles: [KLCandlePoint], query: KLKLineQuery) -> (points: [KLCandlePoint], counters: KXFN221FilterCounters) {
        var counters = KXFN221FilterCounters()
        var accepted: [KLCandlePoint] = []

        for candle in candles {
            if candle.symbol != query.symbol {
                counters.rejectedSymbolCount += 1
                continue
            }
            if candle.timeframe != query.timeframe {
                counters.rejectedTimeframeCount += 1
                continue
            }
            if let startTime = query.startTime, candle.openTime < startTime {
                counters.rejectedBeforeStartCount += 1
                continue
            }
            if let endTime = query.endTime, candle.openTime > endTime {
                counters.rejectedAfterEndCount += 1
                continue
            }
            if !query.includeUnclosed && !candle.isClosed {
                counters.rejectedUnclosedCount += 1
                continue
            }
            if !isValidOHLCV(candle) {
                counters.rejectedInvalidOHLCVCount += 1
                continue
            }
            accepted.append(candle)
        }

        accepted.sort { lhs, rhs in
            switch query.order {
            case .ascending:
                return lhs.openTime < rhs.openTime
            case .descending:
                return lhs.openTime > rhs.openTime
            }
        }

        counters.duplicateOpenTimeCount = countDuplicateOpenTimes(in: accepted)

        if let limit = query.limit, limit >= 0, accepted.count > limit {
            accepted = Array(accepted.prefix(limit))
        }

        counters.unclosedIncludedCount = accepted.filter { !$0.isClosed }.count
        return (accepted, counters)
    }

    private static func isValidOHLCV(_ candle: KLCandlePoint) -> Bool {
        if candle.high < candle.low { return false }
        if candle.open < candle.low || candle.open > candle.high { return false }
        if candle.close < candle.low || candle.close > candle.high { return false }
        if candle.volume < Decimal(0) { return false }
        if let quoteVolume = candle.quoteVolume, quoteVolume < Decimal(0) { return false }
        if let tradeCount = candle.tradeCount, tradeCount < 0 { return false }
        if let closeTime = candle.closeTime, closeTime < candle.openTime { return false }
        return true
    }

    private static func countDuplicateOpenTimes(in candles: [KLCandlePoint]) -> Int {
        var seen = Set<Date>()
        var duplicateCount = 0
        for candle in candles {
            if seen.contains(candle.openTime) {
                duplicateCount += 1
            } else {
                seen.insert(candle.openTime)
            }
        }
        return duplicateCount
    }

    private static func makeQualitySummary(
        candles: [KLCandlePoint],
        acceptedPoints: [KLIndicatorOHLCVPoint],
        counters: KXFN221FilterCounters
    ) -> KLIndicatorDataQualitySummary {
        var messages: [String] = []
        let rejectedCount = counters.rejectedSymbolCount
            + counters.rejectedTimeframeCount
            + counters.rejectedBeforeStartCount
            + counters.rejectedAfterEndCount
            + counters.rejectedUnclosedCount
            + counters.rejectedInvalidOHLCVCount

        if candles.isEmpty {
            messages.append("源 K线为空")
        }
        if acceptedPoints.isEmpty {
            messages.append("过滤后无可供指标模块消费的 OHLCV 数据")
        }
        if counters.rejectedSymbolCount > 0 {
            messages.append("已过滤非目标交易对 K线：\(counters.rejectedSymbolCount) 条")
        }
        if counters.rejectedTimeframeCount > 0 {
            messages.append("已过滤非目标周期 K线：\(counters.rejectedTimeframeCount) 条")
        }
        if counters.rejectedBeforeStartCount > 0 || counters.rejectedAfterEndCount > 0 {
            messages.append("已按时间范围过滤 K线：\(counters.rejectedBeforeStartCount + counters.rejectedAfterEndCount) 条")
        }
        if counters.rejectedUnclosedCount > 0 {
            messages.append("已排除未闭合 K线：\(counters.rejectedUnclosedCount) 条")
        }
        if counters.rejectedInvalidOHLCVCount > 0 {
            messages.append("已排除 OHLCV 不合法 K线：\(counters.rejectedInvalidOHLCVCount) 条")
        }
        if counters.duplicateOpenTimeCount > 0 {
            messages.append("检测到重复 openTime：\(counters.duplicateOpenTimeCount) 条")
        }
        if counters.unclosedIncludedCount > 0 {
            messages.append("结果包含未闭合 K线：\(counters.unclosedIncludedCount) 条")
        }

        let quality: KLDataQuality
        if acceptedPoints.isEmpty {
            quality = candles.isEmpty ? .unknown : .invalid
        } else if counters.rejectedInvalidOHLCVCount > 0 {
            quality = .partial
        } else if rejectedCount > 0 || counters.duplicateOpenTimeCount > 0 || counters.unclosedIncludedCount > 0 {
            quality = .partial
        } else {
            quality = .complete
        }

        return KLIndicatorDataQualitySummary(
            quality: quality,
            sourceCount: candles.count,
            acceptedCount: acceptedPoints.count,
            rejectedSymbolCount: counters.rejectedSymbolCount,
            rejectedTimeframeCount: counters.rejectedTimeframeCount,
            rejectedBeforeStartCount: counters.rejectedBeforeStartCount,
            rejectedAfterEndCount: counters.rejectedAfterEndCount,
            rejectedUnclosedCount: counters.rejectedUnclosedCount,
            rejectedInvalidOHLCVCount: counters.rejectedInvalidOHLCVCount,
            duplicateOpenTimeCount: counters.duplicateOpenTimeCount,
            unclosedIncludedCount: counters.unclosedIncludedCount,
            firstOpenTime: acceptedPoints.first?.openTime,
            lastOpenTime: acceptedPoints.last?.openTime,
            messages: messages
        )
    }
}

private struct KXFN221FilterCounters {
    var rejectedSymbolCount = 0
    var rejectedTimeframeCount = 0
    var rejectedBeforeStartCount = 0
    var rejectedAfterEndCount = 0
    var rejectedUnclosedCount = 0
    var rejectedInvalidOHLCVCount = 0
    var duplicateOpenTimeCount = 0
    var unclosedIncludedCount = 0
}

// MARK: - 指标模块数据接口骨架

public struct KXFN221Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KL-IF-02",
        fileName: "KL-IF-02_指标模块数据接口.swift",
        layer: .interface,
        relativePath: "接口层/KL-IF-02_指标模块数据接口.swift",
        duty: "向指标模块提供标准 OHLCV 数据"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "指标模块数据接口", passed: true, message: "已提供 OHLCV、收盘价、成交量序列与数据质量摘要适配能力")
    }

    public static func placeholder() {
        // 本文件仅实现指标模块数据接口适配：不实现指标算法、不联网、不查库、不绘制 UI。
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN21Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-21", fileName: "KX-FN-21_指标模块数据接口.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-21_指标模块数据接口.swift", duty: "向指标模块提供标准OHLCV数据"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("指标模块数据接口骨架校验通过")
        return KXHealthCheckItem(name: "指标模块数据接口", passed: true, message: "已实现指标模块数据接口定义")
    }
}
