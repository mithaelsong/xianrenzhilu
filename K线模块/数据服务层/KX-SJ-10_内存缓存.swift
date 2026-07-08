//
//  KX-SJ-10_内存缓存.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：管理 K线内存缓存的键、读写、失效骨架
//  禁止事项：禁止真实数据库访问、禁止网络请求
//

import Foundation


// MARK: - K线内存缓存结果

public enum KXSJ10CacheMissReason: String, Codable, Equatable, Sendable {
    case notFound
    case expired
}

public enum KXSJ10CacheLookupResult: Equatable, Sendable {
    case hit(series: KLCandleSeries, descriptor: KLCacheEntryDescriptor)
    case miss(key: KLCacheKey, reason: KXSJ10CacheMissReason)

    public var series: KLCandleSeries? {
        switch self {
        case .hit(let series, _): return series
        case .miss: return nil
        }
    }

    public var isHit: Bool {
        switch self {
        case .hit: return true
        case .miss: return false
        }
    }
}

// MARK: - K线内存缓存条目

public struct KXSJ10MemoryCacheEntry: Codable, Equatable, Sendable {
    public let key: KLCacheKey
    public let series: KLCandleSeries
    public let createdAt: Date
    public let expiresAt: Date?
    public let estimatedByteSize: Int
    public var lastAccessedAt: Date
    public var accessCount: Int

    public init(key: KLCacheKey, series: KLCandleSeries, createdAt: Date = Date(), expiresAt: Date? = nil, estimatedByteSize: Int? = nil, lastAccessedAt: Date? = nil, accessCount: Int = 0) {
        self.key = key
        self.series = series
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.estimatedByteSize = estimatedByteSize ?? Self.estimateByteSize(for: series)
        self.lastAccessedAt = lastAccessedAt ?? createdAt
        self.accessCount = accessCount
    }

    public var itemCount: Int { series.candles.count }

    public var descriptor: KLCacheEntryDescriptor {
        KLCacheEntryDescriptor(
            key: key,
            createdAt: createdAt,
            expiresAt: expiresAt,
            itemCount: itemCount,
            byteSize: estimatedByteSize,
            quality: series.quality
        )
    }

    public func isExpired(at now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= now
    }

    public static func estimateByteSize(for series: KLCandleSeries) -> Int {
        let fixedSeriesOverhead = 256
        let candleApproximation = 176
        let idAndSourceApproximation = series.candles.reduce(0) { partial, candle in
            partial + (candle.id?.utf8.count ?? 0) + candle.symbol.utf8.count + (candle.source?.utf8.count ?? 0)
        }
        return fixedSeriesOverhead + series.candles.count * candleApproximation + idAndSourceApproximation
    }
}

// MARK: - K线内存缓存统计

public struct KXSJ10CacheCapacityStatistics: Codable, Equatable, Sendable {
    public let entryCount: Int
    public let candleCount: Int
    public let estimatedByteSize: Int
    public let expiredEntryCount: Int
    public let maxEntryCount: Int
    public let remainingEntryCapacity: Int
    public let maxByteSize: Int?
    public let remainingByteCapacity: Int?
    public let symbolEntryCounts: [KXSymbol: Int]
    public let timeframeEntryCounts: [KXTimeframe: Int]

    public init(entryCount: Int, candleCount: Int, estimatedByteSize: Int, expiredEntryCount: Int, maxEntryCount: Int, remainingEntryCapacity: Int, maxByteSize: Int?, remainingByteCapacity: Int?, symbolEntryCounts: [KXSymbol: Int], timeframeEntryCounts: [KXTimeframe: Int]) {
        self.entryCount = entryCount
        self.candleCount = candleCount
        self.estimatedByteSize = estimatedByteSize
        self.expiredEntryCount = expiredEntryCount
        self.maxEntryCount = maxEntryCount
        self.remainingEntryCapacity = remainingEntryCapacity
        self.maxByteSize = maxByteSize
        self.remainingByteCapacity = remainingByteCapacity
        self.symbolEntryCounts = symbolEntryCounts
        self.timeframeEntryCounts = timeframeEntryCounts
    }
}

public struct KXSJ10CacheHitMissSummary: Codable, Equatable, Sendable {
    public let hitCount: Int
    public let missCount: Int
    public let expiredMissCount: Int
    public let totalLookupCount: Int
    public let hitRate: Double
    public let missRate: Double

    public init(hitCount: Int, missCount: Int, expiredMissCount: Int) {
        self.hitCount = hitCount
        self.missCount = missCount
        self.expiredMissCount = expiredMissCount
        self.totalLookupCount = hitCount + missCount
        if totalLookupCount == 0 {
            self.hitRate = 0
            self.missRate = 0
        } else {
            self.hitRate = Double(hitCount) / Double(totalLookupCount)
            self.missRate = Double(missCount) / Double(totalLookupCount)
        }
    }
}

public struct KXSJ10CacheSnapshot: Codable, Equatable, Sendable {
    public let capacity: KXSJ10CacheCapacityStatistics
    public let hitMiss: KXSJ10CacheHitMissSummary
    public let descriptors: [KLCacheEntryDescriptor]

    public init(capacity: KXSJ10CacheCapacityStatistics, hitMiss: KXSJ10CacheHitMissSummary, descriptors: [KLCacheEntryDescriptor]) {
        self.capacity = capacity
        self.hitMiss = hitMiss
        self.descriptors = descriptors
    }
}

// MARK: - K线纯内存缓存

public struct KXSJ10MemoryCandleCache: Equatable, Sendable {
    public private(set) var policy: KLCachePolicyDescriptor
    public private(set) var entries: [KLCacheKey: KXSJ10MemoryCacheEntry]
    public private(set) var hitCount: Int
    public private(set) var missCount: Int
    public private(set) var expiredMissCount: Int

    public init(policy: KLCachePolicyDescriptor = KLCachePolicyDescriptor(maxItemCount: 512, maxByteSize: nil, ttlSeconds: 300, evictWhenMemoryWarning: true), entries: [KLCacheKey: KXSJ10MemoryCacheEntry] = [:], hitCount: Int = 0, missCount: Int = 0, expiredMissCount: Int = 0) {
        self.policy = policy
        self.entries = entries
        self.hitCount = hitCount
        self.missCount = missCount
        self.expiredMissCount = expiredMissCount
    }

    public var count: Int { entries.count }
    public var isEmpty: Bool { entries.isEmpty }

    public func contains(_ key: KLCacheKey, at now: Date = Date()) -> Bool {
        guard let entry = entries[key] else { return false }
        return !entry.isExpired(at: now)
    }

    public func descriptor(for key: KLCacheKey, at now: Date = Date()) -> KLCacheEntryDescriptor? {
        guard let entry = entries[key], !entry.isExpired(at: now) else { return nil }
        return entry.descriptor
    }

    public func value(for key: KLCacheKey, at now: Date = Date()) -> KLCandleSeries? {
        guard let entry = entries[key], !entry.isExpired(at: now) else { return nil }
        return entry.series
    }

    public mutating func put(_ series: KLCandleSeries, for key: KLCacheKey, policy overridePolicy: KLCachePolicyDescriptor? = nil, now: Date = Date()) {
        let effectivePolicy = overridePolicy ?? policy
        let ttl = effectivePolicy.ttlSeconds ?? self.policy.ttlSeconds
        let expiresAt = ttl.map { now.addingTimeInterval($0) }
        entries[key] = KXSJ10MemoryCacheEntry(
            key: key,
            series: series,
            createdAt: now,
            expiresAt: expiresAt,
            lastAccessedAt: now
        )
        enforceCapacity(policy: effectivePolicy, now: now)
    }

    @discardableResult
    public mutating func get(_ key: KLCacheKey, now: Date = Date()) -> KXSJ10CacheLookupResult {
        guard var entry = entries[key] else {
            missCount += 1
            return .miss(key: key, reason: .notFound)
        }

        if entry.isExpired(at: now) {
            entries.removeValue(forKey: key)
            missCount += 1
            expiredMissCount += 1
            return .miss(key: key, reason: .expired)
        }

        entry.lastAccessedAt = now
        entry.accessCount += 1
        entries[key] = entry
        hitCount += 1
        return .hit(series: entry.series, descriptor: entry.descriptor)
    }

    @discardableResult
    public mutating func remove(_ key: KLCacheKey) -> KLCandleSeries? {
        entries.removeValue(forKey: key)?.series
    }

    @discardableResult
    public mutating func clear() -> Int {
        let removedCount = entries.count
        entries.removeAll(keepingCapacity: false)
        return removedCount
    }

    @discardableResult
    public mutating func removeExpired(now: Date = Date()) -> Int {
        let expiredKeys = entries.keys.filter { key in
            entries[key]?.isExpired(at: now) ?? false
        }
        for key in expiredKeys {
            entries.removeValue(forKey: key)
        }
        return expiredKeys.count
    }

    @discardableResult
    public mutating func invalidate(symbol: KXSymbol? = nil, timeframe: KXTimeframe? = nil) -> Int {
        let keysToRemove = entries.keys.filter { key in
            let symbolMatches = symbol.map { key.symbol == $0 } ?? true
            let timeframeMatches = timeframe.map { key.timeframe == $0 } ?? true
            return symbolMatches && timeframeMatches
        }
        for key in keysToRemove {
            entries.removeValue(forKey: key)
        }
        return keysToRemove.count
    }

    public func capacityStatistics(now: Date = Date()) -> KXSJ10CacheCapacityStatistics {
        let entryValues = Array(entries.values)
        let entryCount = entryValues.count
        let candleCount = entryValues.reduce(0) { $0 + $1.itemCount }
        let estimatedByteSize = entryValues.reduce(0) { $0 + $1.estimatedByteSize }
        let expiredEntryCount = entryValues.filter { $0.isExpired(at: now) }.count
        let maxEntryCount = max(0, policy.maxItemCount)
        let remainingEntryCapacity = max(0, maxEntryCount - entryCount)
        let remainingByteCapacity = policy.maxByteSize.map { max(0, $0 - estimatedByteSize) }
        let symbolEntryCounts = entryValues.reduce(into: [KXSymbol: Int]()) { result, entry in
            if let symbol = entry.key.symbol {
                result[symbol, default: 0] += 1
            } else {
                result[entry.series.query.symbol, default: 0] += 1
            }
        }
        let timeframeEntryCounts = entryValues.reduce(into: [KXTimeframe: Int]()) { result, entry in
            if let timeframe = entry.key.timeframe {
                result[timeframe, default: 0] += 1
            } else {
                result[entry.series.query.timeframe, default: 0] += 1
            }
        }

        return KXSJ10CacheCapacityStatistics(
            entryCount: entryCount,
            candleCount: candleCount,
            estimatedByteSize: estimatedByteSize,
            expiredEntryCount: expiredEntryCount,
            maxEntryCount: maxEntryCount,
            remainingEntryCapacity: remainingEntryCapacity,
            maxByteSize: policy.maxByteSize,
            remainingByteCapacity: remainingByteCapacity,
            symbolEntryCounts: symbolEntryCounts,
            timeframeEntryCounts: timeframeEntryCounts
        )
    }

    public func hitMissSummary() -> KXSJ10CacheHitMissSummary {
        KXSJ10CacheHitMissSummary(hitCount: hitCount, missCount: missCount, expiredMissCount: expiredMissCount)
    }

    public func snapshot(now: Date = Date()) -> KXSJ10CacheSnapshot {
        let descriptors = entries.values
            .filter { !$0.isExpired(at: now) }
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.descriptor }
        return KXSJ10CacheSnapshot(
            capacity: capacityStatistics(now: now),
            hitMiss: hitMissSummary(),
            descriptors: descriptors
        )
    }

    public mutating func resetHitMissSummary() {
        hitCount = 0
        missCount = 0
        expiredMissCount = 0
    }

    public mutating func updatePolicy(_ newPolicy: KLCachePolicyDescriptor, now: Date = Date()) {
        policy = newPolicy
        enforceCapacity(policy: newPolicy, now: now)
    }

    private mutating func enforceCapacity(policy effectivePolicy: KLCachePolicyDescriptor, now: Date) {
        _ = removeExpired(now: now)

        let maxEntryCount = max(0, effectivePolicy.maxItemCount)
        if maxEntryCount == 0 {
            entries.removeAll(keepingCapacity: false)
            return
        }

        while entries.count > maxEntryCount, let keyToEvict = leastRecentlyAccessedKey() {
            entries.removeValue(forKey: keyToEvict)
        }

        if let maxByteSize = effectivePolicy.maxByteSize {
            while totalEstimatedByteSize() > maxByteSize, let keyToEvict = leastRecentlyAccessedKey() {
                entries.removeValue(forKey: keyToEvict)
            }
        }
    }

    private func totalEstimatedByteSize() -> Int {
        entries.values.reduce(0) { $0 + $1.estimatedByteSize }
    }

    private func leastRecentlyAccessedKey() -> KLCacheKey? {
        entries.min { lhs, rhs in
            if lhs.value.lastAccessedAt != rhs.value.lastAccessedAt {
                return lhs.value.lastAccessedAt < rhs.value.lastAccessedAt
            }
            return lhs.value.createdAt < rhs.value.createdAt
        }?.key
    }
}

// MARK: - K线内存缓存骨架

public enum KXSJ10Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-10",
        fileName: "KX-SJ-10_K线内存缓存.swift",
        layer: .cache,
        relativePath: "缓存层/KX-SJ-10_K线内存缓存.swift",
        duty: "管理 K线内存缓存的键、读写、失效骨架"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "K线内存缓存", passed: true, message: "已实现纯内存 K线缓存：支持读写、移除、清空、TTL、容量统计、按币对/周期失效、命中未命中摘要")
    }

    public static func placeholder() {
        // 本文件已从占位骨架升级为纯内存缓存逻辑。
        // 不使用 NSCache，不访问磁盘，不请求网络，不连接数据库。
    }
}
