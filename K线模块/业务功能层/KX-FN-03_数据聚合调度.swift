//
//  KX-FN-03_数据聚合调度.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：协调成交明细或低周期 K线聚合为目标周期的纯逻辑调度
//  禁止事项：禁止直接画 UI、禁止直接播放提示音、禁止入库、禁止请求网络
//

import Foundation


// MARK: - K线数据聚合调度骨架

public enum KXFN03Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-03",
        fileName: "KX-FN-03_数据聚合调度.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-03_数据聚合调度.swift",
        duty: "协调成交明细或低周期 K线聚合为目标周期的纯逻辑调度"
    )

    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("K线数据聚合调度骨架校验通过")
        return KXHealthCheckItem(name: "K线数据聚合调度", passed: true, message: "已实现成交明细与低周期 K线到目标周期的纯内存聚合")
    }

    public static func placeholder() {
        // 本文件已实现：协调成交明细或低周期 K线聚合为目标周期的纯逻辑。
        // 不请求网络、不读写数据库、不绘制 UI、不播放提示音。
    }
}

// MARK: - 成交明细兼容命名

/// 兼容任务中使用的 KLTickTrade 命名；公共类型定义中当前成交明细模型名为 KLTradeTick。
public typealias KLTickTrade = KLTradeTick

// MARK: - 聚合模式与错误

public enum KXFN03AggregationMode: Sendable {
    /// 历史闭合数据：只输出完整且已闭合的目标周期 K线。
    case historicalClosed
    /// 实时数据：允许输出当前未完整/未闭合的目标周期 K线，并将 isClosed 标记为 false。
    case realtime
}

public enum KXFN03AggregationError: Error, Equatable, Sendable, CustomStringConvertible {
    case unsupportedTimeframe(KXTimeframe)
    case sourceTimeframeMustBeSmaller(source: KXTimeframe, target: KXTimeframe)
    case nonDivisibleTimeframe(source: KXTimeframe, target: KXTimeframe, sourceSeconds: Int, targetSeconds: Int)
    case mixedSymbols(expected: KXSymbol, actual: KXSymbol)
    case candleTimeframeMismatch(expected: KXTimeframe, actual: KXTimeframe)

    public var description: String {
        switch self {
        case .unsupportedTimeframe(let timeframe):
            return "不支持固定秒数换算的周期：\(timeframe.rawValue)"
        case .sourceTimeframeMustBeSmaller(let source, let target):
            return "源周期必须小于目标周期：source=\(source.rawValue), target=\(target.rawValue)"
        case .nonDivisibleTimeframe(let source, let target, let sourceSeconds, let targetSeconds):
            return "源周期不能整除目标周期：source=\(source.rawValue)(\(sourceSeconds)s), target=\(target.rawValue)(\(targetSeconds)s)"
        case .mixedSymbols(let expected, let actual):
            return "输入数据包含不同币对：expected=\(expected), actual=\(actual)"
        case .candleTimeframeMismatch(let expected, let actual):
            return "输入 K线周期不一致：expected=\(expected.rawValue), actual=\(actual.rawValue)"
        }
    }
}

// MARK: - K线数据聚合调度

public struct KXFN03KLineAggregationScheduler: Sendable {
    public init() {}

    /// 将低周期 K线聚合为目标周期 K线。
    ///
    /// - Parameters:
    ///   - candles: 已标准化的低周期 K线。允许乱序输入，内部会按 openTime 排序。
    ///   - sourceTimeframe: 源 K线周期，例如 1m。
    ///   - targetTimeframe: 目标 K线周期，例如 5m。
    ///   - mode: 历史闭合模式只输出完整闭合桶；实时模式允许输出未闭合桶。
    /// - Returns: 聚合后的目标周期 K线；不能整除或周期不合法时返回明确错误。
    public func aggregateCandles(
        _ candles: [KLCandlePoint],
        sourceTimeframe: KXTimeframe,
        targetTimeframe: KXTimeframe,
        mode: KXFN03AggregationMode = .realtime
    ) -> Result<[KLCandlePoint], KXFN03AggregationError> {
        switch validateTimeframes(source: sourceTimeframe, target: targetTimeframe) {
        case .failure(let error):
            return .failure(error)
        case .success(let seconds):
            return aggregateValidatedCandles(
                candles,
                sourceTimeframe: sourceTimeframe,
                targetTimeframe: targetTimeframe,
                sourceSeconds: seconds.source,
                targetSeconds: seconds.target,
                mode: mode
            )
        }
    }

    /// 将成交明细聚合为目标周期 K线。
    ///
    /// 成交明细没有独立源周期，因此只要求目标周期可换算为固定秒数。
    /// quoteVolume 使用 price * size 逐笔累加；tradeCount 为成交笔数。
    /// historicalClosed 模式下，只输出 closeTime <= referenceTime 的桶；realtime 模式下允许输出当前未闭合桶。
    public func aggregateTrades(
        _ trades: [KLTickTrade],
        targetTimeframe: KXTimeframe,
        mode: KXFN03AggregationMode = .realtime,
        referenceTime: Date = Date()
    ) -> Result<[KLCandlePoint], KXFN03AggregationError> {
        guard let targetSeconds = seconds(for: targetTimeframe) else {
            return .failure(.unsupportedTimeframe(targetTimeframe))
        }

        guard trades.isEmpty == false else {
            return .success([])
        }

        let sortedTrades = trades.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
            return lhs.tradeID < rhs.tradeID
        }

        guard let firstSymbol = sortedTrades.first?.symbol else {
            return .success([])
        }

        for trade in sortedTrades where trade.symbol != firstSymbol {
            return .failure(.mixedSymbols(expected: firstSymbol, actual: trade.symbol))
        }

        let grouped = Dictionary(grouping: sortedTrades) { trade in
            bucketOpenTime(for: trade.timestamp, targetSeconds: targetSeconds)
        }

        let candles = grouped.keys.sorted().compactMap { bucketOpenTime -> KLCandlePoint? in
            guard let bucketTrades = grouped[bucketOpenTime], bucketTrades.isEmpty == false else { return nil }

            let bucketCloseTime = bucketOpenTime.addingTimeInterval(TimeInterval(targetSeconds))
            let isBucketClosed = referenceTime >= bucketCloseTime

            if mode == .historicalClosed, isBucketClosed == false {
                return nil
            }

            let open = bucketTrades[0].price
            let close = bucketTrades[bucketTrades.count - 1].price
            let high = bucketTrades.map(\.price).max() ?? open
            let low = bucketTrades.map(\.price).min() ?? open
            let volume = bucketTrades.reduce(KXDecimal(0)) { $0 + $1.size }
            let quoteVolume = bucketTrades.reduce(KXDecimal(0)) { $0 + ($1.price * $1.size) }
            let isClosed = mode == .historicalClosed ? true : isBucketClosed

            return KLCandlePoint(
                symbol: firstSymbol,
                timeframe: targetTimeframe,
                openTime: bucketOpenTime,
                closeTime: isClosed ? bucketCloseTime : nil,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                quoteVolume: quoteVolume,
                tradeCount: bucketTrades.count,
                isClosed: isClosed,
                source: "KX-FN-03:trades"
            )
        }

        return .success(candles)
    }

    /// 便捷静态入口：低周期 K线聚合。
    public static func aggregateCandles(
        _ candles: [KLCandlePoint],
        sourceTimeframe: KXTimeframe,
        targetTimeframe: KXTimeframe,
        mode: KXFN03AggregationMode = .realtime
    ) -> Result<[KLCandlePoint], KXFN03AggregationError> {
        KXFN03KLineAggregationScheduler().aggregateCandles(
            candles,
            sourceTimeframe: sourceTimeframe,
            targetTimeframe: targetTimeframe,
            mode: mode
        )
    }

    /// 便捷静态入口：成交明细聚合。
    public static func aggregateTrades(
        _ trades: [KLTickTrade],
        targetTimeframe: KXTimeframe,
        mode: KXFN03AggregationMode = .realtime,
        referenceTime: Date = Date()
    ) -> Result<[KLCandlePoint], KXFN03AggregationError> {
        KXFN03KLineAggregationScheduler().aggregateTrades(
            trades,
            targetTimeframe: targetTimeframe,
            mode: mode,
            referenceTime: referenceTime
        )
    }

    // MARK: - Private

    private func aggregateValidatedCandles(
        _ candles: [KLCandlePoint],
        sourceTimeframe: KXTimeframe,
        targetTimeframe: KXTimeframe,
        sourceSeconds: Int,
        targetSeconds: Int,
        mode: KXFN03AggregationMode
    ) -> Result<[KLCandlePoint], KXFN03AggregationError> {
        guard candles.isEmpty == false else {
            return .success([])
        }

        let sortedCandles = candles.sorted { lhs, rhs in
            lhs.openTime < rhs.openTime
        }

        guard let firstSymbol = sortedCandles.first?.symbol else {
            return .success([])
        }

        for candle in sortedCandles {
            if candle.symbol != firstSymbol {
                return .failure(.mixedSymbols(expected: firstSymbol, actual: candle.symbol))
            }
            if candle.timeframe != sourceTimeframe {
                return .failure(.candleTimeframeMismatch(expected: sourceTimeframe, actual: candle.timeframe))
            }
        }

        let expectedComponentCount = targetSeconds / sourceSeconds
        let grouped = Dictionary(grouping: sortedCandles) { candle in
            bucketOpenTime(for: candle.openTime, targetSeconds: targetSeconds)
        }

        let candles = grouped.keys.sorted().compactMap { bucketOpenTime -> KLCandlePoint? in
            guard let bucketCandles = grouped[bucketOpenTime], bucketCandles.isEmpty == false else { return nil }

            let sortedBucketCandles = bucketCandles.sorted { lhs, rhs in lhs.openTime < rhs.openTime }
            let hasEnoughComponents = sortedBucketCandles.count >= expectedComponentCount
            let allComponentsClosed = sortedBucketCandles.allSatisfy(\.isClosed)
            let bucketCloseTime = bucketOpenTime.addingTimeInterval(TimeInterval(targetSeconds))
            let bucketElapsed = Date() >= bucketCloseTime
            // 历史闭合聚合仍要求源周期完整，避免用缺页历史拼出假闭合K线。
            // 实时 trades 聚合不能要求每秒都有成交；目标时间桶已经结束且已有源K线均闭合，即可闭合。
            let isFullyClosed: Bool = {
                switch mode {
                case .historicalClosed:
                    return hasEnoughComponents && allComponentsClosed
                case .realtime:
                    return bucketElapsed && allComponentsClosed
                }
            }()

            if mode == .historicalClosed, isFullyClosed == false {
                return nil
            }

            guard let first = sortedBucketCandles.first, let last = sortedBucketCandles.last else {
                return nil
            }

            let high = sortedBucketCandles.map(\.high).max() ?? first.high
            let low = sortedBucketCandles.map(\.low).min() ?? first.low
            let volume = sortedBucketCandles.reduce(KXDecimal(0)) { $0 + $1.volume }
            let quoteVolume = sumOptionalDecimals(sortedBucketCandles.map(\.quoteVolume))
            let tradeCount = sumOptionalInts(sortedBucketCandles.map(\.tradeCount))
            let isClosed = mode == .historicalClosed ? true : isFullyClosed
            let closeTime = isClosed ? bucketCloseTime : nil

            return KLCandlePoint(
                symbol: firstSymbol,
                timeframe: targetTimeframe,
                openTime: bucketOpenTime,
                closeTime: closeTime,
                open: first.open,
                high: high,
                low: low,
                close: last.close,
                volume: volume,
                quoteVolume: quoteVolume,
                tradeCount: tradeCount,
                isClosed: isClosed,
                source: "KX-FN-03:candles:\(sourceTimeframe.rawValue)->\(targetTimeframe.rawValue)"
            )
        }

        return .success(candles)
    }

    private func validateTimeframes(
        source: KXTimeframe,
        target: KXTimeframe
    ) -> Result<(source: Int, target: Int), KXFN03AggregationError> {
        guard let sourceSeconds = seconds(for: source) else {
            return .failure(.unsupportedTimeframe(source))
        }
        guard let targetSeconds = seconds(for: target) else {
            return .failure(.unsupportedTimeframe(target))
        }
        guard sourceSeconds < targetSeconds else {
            return .failure(.sourceTimeframeMustBeSmaller(source: source, target: target))
        }
        guard targetSeconds % sourceSeconds == 0 else {
            return .failure(.nonDivisibleTimeframe(
                source: source,
                target: target,
                sourceSeconds: sourceSeconds,
                targetSeconds: targetSeconds
            ))
        }
        return .success((sourceSeconds, targetSeconds))
    }

    private func seconds(for timeframe: KXTimeframe) -> Int? {
        KXFN02TimeframeManager.seconds(for: timeframe)
    }

    private func bucketOpenTime(for date: Date, targetSeconds: Int) -> Date {
        let interval = date.timeIntervalSince1970
        let bucket = floor(interval / TimeInterval(targetSeconds)) * TimeInterval(targetSeconds)
        return Date(timeIntervalSince1970: bucket)
    }

    private func sumOptionalDecimals(_ values: [KXDecimal?]) -> KXDecimal? {
        let existingValues = values.compactMap { $0 }
        guard existingValues.isEmpty == false else { return nil }
        return existingValues.reduce(KXDecimal(0), +)
    }

    private func sumOptionalInts(_ values: [Int?]) -> Int? {
        let existingValues = values.compactMap { $0 }
        guard existingValues.isEmpty == false else { return nil }
        return existingValues.reduce(0, +)
    }
}
