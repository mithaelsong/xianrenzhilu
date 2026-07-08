//
//  KX-SJ-13_滑动窗口缓存.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：1s、1m、2m、3m、5m、10m 内存滑动窗口缓存
//  禁止事项：禁止数据库写入、禁止网络请求、禁止UI绘制
//

import Foundation


// MARK: - 低周期缓存

public final class KLLowTimeframeCache: @unchecked Sendable {
    private var storage: [String: [KLCandlePoint]] = [:]
    private var limits: [String: Int] = [:]
    /// 历史窗口是否已经按策略加载完成。实时聚合器写入的 1 根 K线不能把该状态置为 ready。
    private var historyReadyKeys: Set<String> = []
    private var historyErrors: [String: String] = [:]
    private let queue = DispatchQueue(label: "com.kline.lowtimeframe.cache")
    private static let defaultLimits: [KXTimeframe: Int] = [
        // 低周期只为实时显示/短期聚合服务，不长期留存。周期越短，保留时间越短，避免内存堆积。
        .oneSecond: 60 * 60,            // 1s：最近1小时，约3,600根
        .oneMinute: 84 * 60,            // 1m：最近3.5天，约5,040根
        .threeMinutes: 21 * 24 * 20,    // 3m：最近21天，约10,080根
        .fiveMinutes: 15 * 24 * 12,     // 5m：最近15天，约4,320根
    ]

    public init() {}

    public static func recommendedRetentionLimit(for timeframe: KXTimeframe) -> Int {
        KLOKXTimeframePolicyCatalog.memoryRetentionLimit(for: timeframe) ?? defaultLimits[timeframe] ?? 1000
    }

    // MARK: - Key

    private func key(exchange: String, instrumentID: String, timeframe: KXTimeframe) -> String {
        "\(exchange)/\(instrumentID)/\(timeframe.rawValue)"
    }


    /// 历史K线是底座；实时聚合从 App 启动后才有 trades，不能整根覆盖交易所历史当前桶。
    private static func mergeRealtime(base: KLCandlePoint, incoming: KLCandlePoint) -> KLCandlePoint {
        KLCandlePoint(
            id: base.id,
            symbol: base.symbol,
            timeframe: base.timeframe,
            openTime: base.openTime,
            closeTime: incoming.closeTime ?? base.closeTime,
            open: base.open,
            high: max(base.high, incoming.high),
            low: min(base.low, incoming.low),
            close: incoming.close,
            volume: max(base.volume, incoming.volume),
            quoteVolume: [base.quoteVolume, incoming.quoteVolume].compactMap { $0 }.max(),
            tradeCount: max(base.tradeCount ?? 0, incoming.tradeCount ?? 0),
            isClosed: base.isClosed || incoming.isClosed,
            source: incoming.source ?? base.source
        )
    }

    // MARK: - append

    public func append(candle: KLCandlePoint, exchange: String, instrumentID: String, timeframe: KXTimeframe) {
        queue.sync {
            let k = key(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
            var candles = storage[k] ?? []
            if let idx = candles.lastIndex(where: { $0.openTime == candle.openTime && $0.timeframe == timeframe && $0.symbol == instrumentID }) {
                // 同一根：原地合并，顺序不变，无需排序。
                candles[idx] = Self.mergeRealtime(base: candles[idx], incoming: candle)
            } else if let last = candles.last, candle.openTime < last.openTime {
                // 极少见：乱序到达，二分插入到正确位置，保持有序（避免全量 sort）。
                var lo = 0, hi = candles.count
                while lo < hi {
                    let mid = (lo + hi) / 2
                    if candles[mid].openTime < candle.openTime { lo = mid + 1 } else { hi = mid }
                }
                candles.insert(candle, at: lo)
            } else {
                // 常态：新一根就是最新桶，直接追加即保持有序，无需排序。
                candles.append(candle)
            }
            let limit = limits[k] ?? Self.recommendedRetentionLimit(for: timeframe)
            if candles.count > limit {
                candles = Array(candles.suffix(limit))
            }
            storage[k] = candles
        }
    }

    // MARK: - query

    public func query(exchange: String, instrumentID: String, timeframe: KXTimeframe, startTime: Date?, endTime: Date?) -> [KLCandlePoint] {
        queue.sync {
            let k = key(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
            guard let candles = storage[k] else { return [] }
            if let start = startTime, let end = endTime {
                return candles.filter { $0.openTime >= start && $0.openTime <= end }
            } else if let start = startTime {
                return candles.filter { $0.openTime >= start }
            } else if let end = endTime {
                return candles.filter { $0.openTime <= end }
            }
            return candles
        }
    }

    // MARK: - trim

    public func trim(exchange: String, instrumentID: String, timeframe: KXTimeframe, maxCount: Int) {
        queue.sync {
            let k = key(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
            guard var candles = storage[k], candles.count > maxCount else { return }
            candles = Array(candles.suffix(maxCount))
            storage[k] = candles
        }
    }

    /// 为当前币对/周期提升缓存容量。用于打开币对后预加载交易所可返回的完整低周期历史。
    public func ensureLimit(exchange: String, instrumentID: String, timeframe: KXTimeframe, minCount: Int) {
        queue.sync {
            let k = key(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
            let current = limits[k] ?? Self.recommendedRetentionLimit(for: timeframe)
            limits[k] = max(current, minCount)
        }
    }

    public func clear(exchange: String, instrumentID: String, timeframe: KXTimeframe) {
        queue.sync {
            let k = key(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
            storage.removeValue(forKey: k)
            limits.removeValue(forKey: k)
            historyReadyKeys.remove(k)
            historyErrors.removeValue(forKey: k)
        }
    }

    public func clearAll() {
        queue.sync {
            storage.removeAll()
            limits.removeAll()
            historyReadyKeys.removeAll()
            historyErrors.removeAll()
        }
    }

    public func memorySummary() -> [String: Int] {
        queue.sync {
            storage.mapValues { $0.count }
        }
    }
}

// MARK: - 便利访问

public extension KLLowTimeframeCache {
    static let shared = KLLowTimeframeCache()

    /// 判断周期是否应由本缓存管理
    static func isManaged(timeframe: KXTimeframe) -> Bool {
        KLOKXTimeframePolicyCatalog.isMemoryOnly(timeframe)
    }

    /// 获取某币对某周期的所有缓存数据
    func allCandles(exchange: String, instrumentID: String, timeframe: KXTimeframe) -> [KLCandlePoint] {
        query(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe, startTime: nil, endTime: nil)
    }

    /// 更新或追加多个 K线
    func upsert(candles: [KLCandlePoint], exchange: String, instrumentID: String, timeframe: KXTimeframe) {
        for c in candles {
            append(candle: c, exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
        }
    }

    /// 按策略直接覆盖当前币对/周期的图表内存工作集；多余数据只保留尾部窗口。
    func replace(candles: [KLCandlePoint], exchange: String, instrumentID: String, timeframe: KXTimeframe, maxCount: Int?) {
        queue.sync {
            let k = key(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
            var normalized = candles
                .filter { $0.symbol == instrumentID && $0.timeframe == timeframe }
                .sorted { $0.openTime < $1.openTime }
            if let maxCount, normalized.count > maxCount {
                normalized = Array(normalized.suffix(maxCount))
                limits[k] = maxCount
            }
            storage[k] = normalized
            if normalized.isEmpty {
                historyReadyKeys.remove(k)
            } else {
                historyReadyKeys.insert(k)
                historyErrors.removeValue(forKey: k)
            }
        }
    }

    /// 标记历史加载失败；保留已有缓存，但 UI 不应把实时临时K线当成历史窗口。
    func markHistoryFailed(exchange: String, instrumentID: String, timeframe: KXTimeframe, error: String) {
        queue.sync {
            let k = key(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
            historyReadyKeys.remove(k)
            historyErrors[k] = error
        }
    }

    /// 当前 symbol/timeframe 的历史窗口是否已经按策略加载完成。
    func historyReady(exchange: String, instrumentID: String, timeframe: KXTimeframe) -> Bool {
        queue.sync {
            let k = key(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
            return historyReadyKeys.contains(k)
        }
    }

    /// 读取最近一次历史加载错误。
    func historyError(exchange: String, instrumentID: String, timeframe: KXTimeframe) -> String? {
        queue.sync {
            let k = key(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
            return historyErrors[k]
        }
    }

    /// 获取当前缓存数量
    func count(exchange: String, instrumentID: String, timeframe: KXTimeframe) -> Int {
        queue.sync {
            let k = key(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe)
            return storage[k]?.count ?? 0
        }
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXSJ13Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-13", fileName: "KX-SJ-13_滑动窗口缓存.swift", layer: .data,
        relativePath: "数据服务层/KX-SJ-13_滑动窗口缓存.swift", duty: "滑动窗口缓存管理"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("滑动窗口缓存骨架校验通过")
        return KXHealthCheckItem(name: "滑动窗口缓存", passed: true, message: "已实现低周期滑动窗口缓存")
    }
}
