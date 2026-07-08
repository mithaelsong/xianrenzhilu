//
//  KX-SJ-12_可视窗口缓存.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：缓存当前可视窗口及邻近窗口数据
//  禁止事项：禁止全量历史加载、禁止 NSCache、禁止磁盘/网络/数据库访问
//

import Foundation


// MARK: - 可视窗口缓存位置

public enum KXSJ12VisibleWindowPosition: String, Codable, Sendable, CaseIterable {
    case current
    case leftNeighbor
    case rightNeighbor
    case custom
}

// MARK: - 可视窗口缓存键

public struct KXSJ12VisibleWindowCacheKey: Codable, Hashable, Sendable, CustomStringConvertible {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let startIndex: Int
    public let endIndex: Int
    public let startTime: Date?
    public let endTime: Date?
    public let position: KXSJ12VisibleWindowPosition

    public init(symbol: KXSymbol, timeframe: KXTimeframe, startIndex: Int, endIndex: Int, startTime: Date? = nil, endTime: Date? = nil, position: KXSJ12VisibleWindowPosition = .custom) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.startTime = startTime
        self.endTime = endTime
        self.position = position
    }

    public init(window: KLVisibleWindow, position: KXSJ12VisibleWindowPosition = .custom) {
        self.init(
            symbol: window.symbol,
            timeframe: window.timeframe,
            startIndex: window.indexRange.startIndex,
            endIndex: window.indexRange.endIndex,
            startTime: window.timeRange?.startTime,
            endTime: window.timeRange?.endTime,
            position: position
        )
    }

    public var description: String {
        let timePart: String
        if let startTime, let endTime {
            timePart = "\(startTime.timeIntervalSince1970)-\(endTime.timeIntervalSince1970)"
        } else {
            timePart = "no-time"
        }
        return "visibleWindow:\(symbol):\(timeframe.rawValue):\(startIndex)-\(endIndex):\(position.rawValue):\(timePart)"
    }

    public var cacheKey: KLCacheKey {
        KLCacheKey(
            namespace: .visibleWindow,
            symbol: symbol,
            timeframe: timeframe,
            startTime: startTime,
            endTime: endTime,
            variant: "\(startIndex)-\(endIndex)-\(position.rawValue)"
        )
    }

    public func matches(symbol: KXSymbol, timeframe: KXTimeframe, window: KLVisibleWindow) -> Bool {
        self.symbol == symbol
        && self.timeframe == timeframe
        && startIndex == window.indexRange.startIndex
        && endIndex == window.indexRange.endIndex
        && startTime == window.timeRange?.startTime
        && endTime == window.timeRange?.endTime
    }
}

// MARK: - 可视窗口缓存条目

public struct KXSJ12VisibleWindowCacheEntry: Codable, Equatable, Sendable {
    public let key: KXSJ12VisibleWindowCacheKey
    public let window: KLVisibleWindow
    public let candles: [KLCandlePoint]
    public let createdAt: Date
    public let expiresAt: Date?
    public let quality: KLDataQuality
    public let descriptor: KLCacheEntryDescriptor
    public private(set) var lastAccessedAt: Date?
    public private(set) var hitCount: Int

    public init(window: KLVisibleWindow, candles: [KLCandlePoint], position: KXSJ12VisibleWindowPosition = .custom, createdAt: Date = Date(), ttlSeconds: Double? = nil, quality: KLDataQuality = .unknown) {
        let key = KXSJ12VisibleWindowCacheKey(window: window, position: position)
        let expiresAt = ttlSeconds.map { createdAt.addingTimeInterval($0) }
        self.key = key
        self.window = window
        self.candles = KXSJ12VisibleWindowCacheEntry.normalizedCandles(candles, for: window)
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.quality = quality
        self.lastAccessedAt = nil
        self.hitCount = 0
        self.descriptor = KLCacheEntryDescriptor(
            key: key.cacheKey,
            createdAt: createdAt,
            expiresAt: expiresAt,
            itemCount: self.candles.count,
            byteSize: KXSJ12VisibleWindowCacheEntry.estimatedByteSize(candleCount: self.candles.count),
            quality: quality
        )
    }

    public var isEmpty: Bool { candles.isEmpty }

    public func isExpired(at now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return now >= expiresAt
    }

    public func overlaps(window other: KLVisibleWindow) -> Bool {
        guard key.symbol == other.symbol, key.timeframe == other.timeframe else { return false }
        let left = max(window.indexRange.startIndex, other.indexRange.startIndex)
        let right = min(window.indexRange.endIndex, other.indexRange.endIndex)
        return left <= right
    }

    public func contains(index: Int) -> Bool {
        window.indexRange.startIndex <= index && index <= window.indexRange.endIndex
    }

    public func candles(in requestedWindow: KLVisibleWindow) -> [KLCandlePoint] {
        guard overlaps(window: requestedWindow) else { return [] }
        if let requestedTimeRange = requestedWindow.timeRange {
            return candles.filter { candle in
                candle.openTime >= requestedTimeRange.startTime && candle.openTime <= requestedTimeRange.endTime
            }
        }
        return candles
    }

    public mutating func recordHit(at now: Date = Date()) {
        lastAccessedAt = now
        hitCount += 1
    }

    private static func normalizedCandles(_ candles: [KLCandlePoint], for window: KLVisibleWindow) -> [KLCandlePoint] {
        candles
            .filter { candle in
                guard candle.symbol == window.symbol, candle.timeframe == window.timeframe else { return false }
                if let timeRange = window.timeRange {
                    return candle.openTime >= timeRange.startTime && candle.openTime <= timeRange.endTime
                }
                return true
            }
            .sorted { $0.openTime < $1.openTime }
    }

    private static func estimatedByteSize(candleCount: Int) -> Int {
        candleCount * 160
    }
}

// MARK: - 读取结果与命中摘要

public struct KXSJ12VisibleWindowCacheReadResult: Codable, Equatable, Sendable {
    public let key: KXSJ12VisibleWindowCacheKey
    public let entry: KXSJ12VisibleWindowCacheEntry?
    public let hit: Bool
    public let expired: Bool
    public let message: String

    public init(key: KXSJ12VisibleWindowCacheKey, entry: KXSJ12VisibleWindowCacheEntry?, hit: Bool, expired: Bool, message: String) {
        self.key = key
        self.entry = entry
        self.hit = hit
        self.expired = expired
        self.message = message
    }
}

public struct KXSJ12VisibleWindowCacheHitSummary: Codable, Equatable, Sendable {
    public let totalEntries: Int
    public let validEntries: Int
    public let expiredEntries: Int
    public let totalCandles: Int
    public let totalHits: Int
    public let currentWindowHits: Int
    public let leftNeighborHits: Int
    public let rightNeighborHits: Int
    public let latestAccessedAt: Date?

    public init(totalEntries: Int, validEntries: Int, expiredEntries: Int, totalCandles: Int, totalHits: Int, currentWindowHits: Int, leftNeighborHits: Int, rightNeighborHits: Int, latestAccessedAt: Date?) {
        self.totalEntries = totalEntries
        self.validEntries = validEntries
        self.expiredEntries = expiredEntries
        self.totalCandles = totalCandles
        self.totalHits = totalHits
        self.currentWindowHits = currentWindowHits
        self.leftNeighborHits = leftNeighborHits
        self.rightNeighborHits = rightNeighborHits
        self.latestAccessedAt = latestAccessedAt
    }
}

// MARK: - 纯内存可视窗口缓存

public struct KXSJ12VisibleWindowMemoryCache: Sendable {
    public private(set) var entries: [KXSJ12VisibleWindowCacheKey: KXSJ12VisibleWindowCacheEntry]
    public private(set) var currentWindowKeyByScope: [String: KXSJ12VisibleWindowCacheKey]
    public let policy: KLCachePolicyDescriptor

    public init(policy: KLCachePolicyDescriptor = KLCachePolicyDescriptor(maxItemCount: 24, maxByteSize: nil, ttlSeconds: 120, evictWhenMemoryWarning: true)) {
        self.entries = [:]
        self.currentWindowKeyByScope = [:]
        self.policy = policy
    }

    public var isEmpty: Bool { entries.isEmpty }
    public var count: Int { entries.count }

    public mutating func storeCurrent(window: KLVisibleWindow, candles: [KLCandlePoint], now: Date = Date(), ttlSeconds: Double? = nil, quality: KLDataQuality = .unknown) {
        store(window: window, candles: candles, position: .current, now: now, ttlSeconds: ttlSeconds, quality: quality)
        currentWindowKeyByScope[scopeKey(symbol: window.symbol, timeframe: window.timeframe)] = KXSJ12VisibleWindowCacheKey(window: window, position: .current)
    }

    public mutating func storeLeftNeighbor(window: KLVisibleWindow, candles: [KLCandlePoint], now: Date = Date(), ttlSeconds: Double? = nil, quality: KLDataQuality = .unknown) {
        store(window: window, candles: candles, position: .leftNeighbor, now: now, ttlSeconds: ttlSeconds, quality: quality)
    }

    public mutating func storeRightNeighbor(window: KLVisibleWindow, candles: [KLCandlePoint], now: Date = Date(), ttlSeconds: Double? = nil, quality: KLDataQuality = .unknown) {
        store(window: window, candles: candles, position: .rightNeighbor, now: now, ttlSeconds: ttlSeconds, quality: quality)
    }

    public mutating func store(window: KLVisibleWindow, candles: [KLCandlePoint], position: KXSJ12VisibleWindowPosition = .custom, now: Date = Date(), ttlSeconds: Double? = nil, quality: KLDataQuality = .unknown) {
        let effectiveTTL = ttlSeconds ?? policy.ttlSeconds
        let entry = KXSJ12VisibleWindowCacheEntry(window: window, candles: candles, position: position, createdAt: now, ttlSeconds: effectiveTTL, quality: quality)
        entries[entry.key] = entry
        evictExpired(now: now)
        evictOverflowIfNeeded()
    }

    public mutating func storeNeighbors(leftWindow: KLVisibleWindow?, leftCandles: [KLCandlePoint] = [], rightWindow: KLVisibleWindow?, rightCandles: [KLCandlePoint] = [], now: Date = Date(), ttlSeconds: Double? = nil, quality: KLDataQuality = .unknown) {
        if let leftWindow {
            storeLeftNeighbor(window: leftWindow, candles: leftCandles, now: now, ttlSeconds: ttlSeconds, quality: quality)
        }
        if let rightWindow {
            storeRightNeighbor(window: rightWindow, candles: rightCandles, now: now, ttlSeconds: ttlSeconds, quality: quality)
        }
    }

    public mutating func value(symbol: KXSymbol, timeframe: KXTimeframe, window: KLVisibleWindow, position: KXSJ12VisibleWindowPosition = .custom, now: Date = Date()) -> KXSJ12VisibleWindowCacheReadResult {
        let key = KXSJ12VisibleWindowCacheKey(window: window, position: position)
        guard key.matches(symbol: symbol, timeframe: timeframe, window: window) else {
            return KXSJ12VisibleWindowCacheReadResult(key: key, entry: nil, hit: false, expired: false, message: "查询参数与窗口不一致")
        }
        return value(for: key, now: now)
    }

    public mutating func currentWindow(symbol: KXSymbol, timeframe: KXTimeframe, now: Date = Date()) -> KXSJ12VisibleWindowCacheReadResult? {
        guard let key = currentWindowKeyByScope[scopeKey(symbol: symbol, timeframe: timeframe)] else { return nil }
        return value(for: key, now: now)
    }

    public func peek(symbol: KXSymbol, timeframe: KXTimeframe, window: KLVisibleWindow, position: KXSJ12VisibleWindowPosition = .custom, now: Date = Date()) -> KXSJ12VisibleWindowCacheEntry? {
        let key = KXSJ12VisibleWindowCacheKey(window: window, position: position)
        guard let entry = entries[key], !entry.isExpired(at: now) else { return nil }
        return entry
    }

    public func entries(symbol: KXSymbol, timeframe: KXTimeframe, now: Date = Date(), includeExpired: Bool = false) -> [KXSJ12VisibleWindowCacheEntry] {
        entries.values
            .filter { entry in
                entry.key.symbol == symbol
                && entry.key.timeframe == timeframe
                && (includeExpired || !entry.isExpired(at: now))
            }
            .sorted { lhs, rhs in
                if lhs.key.startIndex == rhs.key.startIndex { return lhs.key.endIndex < rhs.key.endIndex }
                return lhs.key.startIndex < rhs.key.startIndex
            }
    }

    public mutating func invalidate(symbol: KXSymbol? = nil, timeframe: KXTimeframe? = nil, window: KLVisibleWindow? = nil, position: KXSJ12VisibleWindowPosition? = nil) {
        let keysToRemove = entries.keys.filter { key in
            if let symbol, key.symbol != symbol { return false }
            if let timeframe, key.timeframe != timeframe { return false }
            if let position, key.position != position { return false }
            if let window, !key.matches(symbol: window.symbol, timeframe: window.timeframe, window: window) { return false }
            return true
        }
        for key in keysToRemove {
            entries.removeValue(forKey: key)
            removeCurrentPointerIfNeeded(removedKey: key)
        }
    }

    public mutating func evictExpired(now: Date = Date()) {
        let keysToRemove = entries.filter { $0.value.isExpired(at: now) }.map { $0.key }
        for key in keysToRemove {
            entries.removeValue(forKey: key)
            removeCurrentPointerIfNeeded(removedKey: key)
        }
    }

    public mutating func removeAll() {
        entries.removeAll()
        currentWindowKeyByScope.removeAll()
    }

    public func hitSummary(now: Date = Date()) -> KXSJ12VisibleWindowCacheHitSummary {
        let values = Array(entries.values)
        let expiredEntries = values.filter { $0.isExpired(at: now) }.count
        let validEntries = values.count - expiredEntries
        let totalHits = values.reduce(0) { $0 + $1.hitCount }
        let currentHits = values.filter { $0.key.position == .current }.reduce(0) { $0 + $1.hitCount }
        let leftHits = values.filter { $0.key.position == .leftNeighbor }.reduce(0) { $0 + $1.hitCount }
        let rightHits = values.filter { $0.key.position == .rightNeighbor }.reduce(0) { $0 + $1.hitCount }
        let latestAccessedAt = values.compactMap(\.lastAccessedAt).max()
        return KXSJ12VisibleWindowCacheHitSummary(
            totalEntries: values.count,
            validEntries: validEntries,
            expiredEntries: expiredEntries,
            totalCandles: values.reduce(0) { $0 + $1.candles.count },
            totalHits: totalHits,
            currentWindowHits: currentHits,
            leftNeighborHits: leftHits,
            rightNeighborHits: rightHits,
            latestAccessedAt: latestAccessedAt
        )
    }

    private mutating func value(for key: KXSJ12VisibleWindowCacheKey, now: Date) -> KXSJ12VisibleWindowCacheReadResult {
        guard var entry = entries[key] else {
            return KXSJ12VisibleWindowCacheReadResult(key: key, entry: nil, hit: false, expired: false, message: "缓存未命中")
        }
        if entry.isExpired(at: now) {
            entries.removeValue(forKey: key)
            removeCurrentPointerIfNeeded(removedKey: key)
            return KXSJ12VisibleWindowCacheReadResult(key: key, entry: nil, hit: false, expired: true, message: "缓存已过期并失效")
        }
        entry.recordHit(at: now)
        entries[key] = entry
        return KXSJ12VisibleWindowCacheReadResult(key: key, entry: entry, hit: true, expired: false, message: "缓存命中")
    }

    private mutating func evictOverflowIfNeeded() {
        guard policy.maxItemCount > 0, entries.count > policy.maxItemCount else { return }
        let overflowCount = entries.count - policy.maxItemCount
        let removableKeys = entries.values
            .sorted { lhs, rhs in
                let lhsAccess = lhs.lastAccessedAt ?? lhs.createdAt
                let rhsAccess = rhs.lastAccessedAt ?? rhs.createdAt
                if lhsAccess == rhsAccess { return lhs.hitCount < rhs.hitCount }
                return lhsAccess < rhsAccess
            }
            .prefix(overflowCount)
            .map(\.key)
        for key in removableKeys {
            entries.removeValue(forKey: key)
            removeCurrentPointerIfNeeded(removedKey: key)
        }
    }

    private mutating func removeCurrentPointerIfNeeded(removedKey: KXSJ12VisibleWindowCacheKey) {
        let scope = scopeKey(symbol: removedKey.symbol, timeframe: removedKey.timeframe)
        if currentWindowKeyByScope[scope] == removedKey {
            currentWindowKeyByScope.removeValue(forKey: scope)
        }
    }

    private func scopeKey(symbol: KXSymbol, timeframe: KXTimeframe) -> String {
        "\(symbol)|\(timeframe.rawValue)"
    }
}

// MARK: - 可视窗口缓存实现入口

public enum KXSJ12VisibleWindowCache: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-12",
        fileName: "KX-SJ-12_可视窗口缓存.swift",
        layer: .cache,
        relativePath: "缓存层/KX-SJ-12_可视窗口缓存.swift",
        duty: "缓存当前可视窗口及邻近窗口数据"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "可视窗口缓存", passed: true, message: "已实现纯内存可视窗口缓存：当前窗口、左右邻近预热、过期失效、按窗口查询与命中摘要")
    }

    public static func makeDefaultCache(ttlSeconds: Double = 120, maxItemCount: Int = 24) -> KXSJ12VisibleWindowMemoryCache {
        KXSJ12VisibleWindowMemoryCache(
            policy: KLCachePolicyDescriptor(
                maxItemCount: maxItemCount,
                maxByteSize: nil,
                ttlSeconds: ttlSeconds,
                evictWhenMemoryWarning: true
            )
        )
    }
}

public typealias KXSJ12Skeleton = KXSJ12VisibleWindowCache
