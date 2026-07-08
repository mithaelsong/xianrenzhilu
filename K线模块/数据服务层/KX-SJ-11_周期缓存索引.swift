//
//  KX-SJ-11_周期缓存索引.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：维护币对和周期对应的缓存索引
//  禁止事项：禁止 UI 绘制、禁止 NSCache、禁止磁盘/网络/数据库访问
//

import Foundation


// MARK: - 周期缓存索引

public enum KXSJ11Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-11",
        fileName: "KX-SJ-11_周期缓存索引.swift",
        layer: .cache,
        relativePath: "缓存层/KX-SJ-11_周期缓存索引.swift",
        duty: "维护币对和周期对应的缓存索引"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "周期缓存索引", passed: true, message: "已实现纯内存索引：注册、更新、移除、查询、覆盖合并、缺口识别与过期清理")
    }

    public static func placeholder() {
        // 本文件已由骨架升级为可用纯索引逻辑。
        // 只维护 KLCacheKey、KLTimeRange、KLCacheEntryDescriptor 的内存索引关系。
    }
}

public struct KXSJ11CacheIndexEntry: Codable, Equatable, Sendable {
    public let key: KLCacheKey
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let timeRange: KLTimeRange
    public let metadata: KLCacheEntryDescriptor
    public let updatedAt: Date

    public init(key: KLCacheKey, symbol: KXSymbol, timeframe: KXTimeframe, timeRange: KLTimeRange, metadata: KLCacheEntryDescriptor, updatedAt: Date = Date()) {
        self.key = key
        self.symbol = symbol
        self.timeframe = timeframe
        self.timeRange = timeRange
        self.metadata = metadata
        self.updatedAt = updatedAt
    }

    public var isExpired: Bool {
        guard let expiresAt = metadata.expiresAt else { return false }
        return expiresAt <= Date()
    }

    public func isExpired(at now: Date) -> Bool {
        guard let expiresAt = metadata.expiresAt else { return false }
        return expiresAt <= now
    }

    public func intersects(_ range: KLTimeRange) -> Bool {
        timeRange.startTime <= range.endTime && range.startTime <= timeRange.endTime
    }

    public func contains(_ date: Date) -> Bool {
        timeRange.startTime <= date && date <= timeRange.endTime
    }
}

public struct KXSJ11CoverageReport: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let requestedRange: KLTimeRange
    public let coveredRanges: [KLTimeRange]
    public let gaps: [KLGapRange]
    public let matchingEntries: [KXSJ11CacheIndexEntry]

    public init(symbol: KXSymbol, timeframe: KXTimeframe, requestedRange: KLTimeRange, coveredRanges: [KLTimeRange], gaps: [KLGapRange], matchingEntries: [KXSJ11CacheIndexEntry]) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.requestedRange = requestedRange
        self.coveredRanges = coveredRanges
        self.gaps = gaps
        self.matchingEntries = matchingEntries
    }

    public var isFullyCovered: Bool { gaps.isEmpty }
}

public struct KXSJ11TimeframeCacheIndex: Codable, Equatable, Sendable {
    private struct PairKey: Codable, Hashable, Sendable {
        let symbol: KXSymbol
        let timeframe: KXTimeframe
    }

    private var entriesByKey: [KLCacheKey: KXSJ11CacheIndexEntry]
    private var keysByPair: [PairKey: Set<KLCacheKey>]

    public init(entries: [KXSJ11CacheIndexEntry] = []) {
        self.entriesByKey = [:]
        self.keysByPair = [:]
        for entry in entries {
            insert(entry)
        }
    }

    public var count: Int { entriesByKey.count }
    public var isEmpty: Bool { entriesByKey.isEmpty }
    public var allEntries: [KXSJ11CacheIndexEntry] { sorted(entriesByKey.values) }

    public static func makeCacheKey(symbol: KXSymbol, timeframe: KXTimeframe, range: KLTimeRange, variant: String? = nil) -> KLCacheKey {
        KLCacheKey(namespace: .timeframeIndex, symbol: symbol, timeframe: timeframe, startTime: range.startTime, endTime: range.endTime, variant: variant)
    }

    @discardableResult
    public mutating func register(symbol: KXSymbol, timeframe: KXTimeframe, range: KLTimeRange, metadata: KLCacheEntryDescriptor? = nil, variant: String? = nil, now: Date = Date()) -> KXSJ11CacheIndexEntry {
        let key = metadata?.key ?? Self.makeCacheKey(symbol: symbol, timeframe: timeframe, range: range, variant: variant)
        return register(key: key, symbol: symbol, timeframe: timeframe, range: range, metadata: metadata, now: now)
    }

    @discardableResult
    public mutating func register(key: KLCacheKey, range: KLTimeRange, metadata: KLCacheEntryDescriptor? = nil, now: Date = Date()) -> KXSJ11CacheIndexEntry? {
        guard let symbol = key.symbol, let timeframe = key.timeframe else { return nil }
        return register(key: key, symbol: symbol, timeframe: timeframe, range: range, metadata: metadata, now: now)
    }

    @discardableResult
    public mutating func update(key: KLCacheKey, range: KLTimeRange? = nil, metadata: KLCacheEntryDescriptor? = nil, now: Date = Date()) -> KXSJ11CacheIndexEntry? {
        guard let current = entriesByKey[key] else { return nil }
        let nextRange = range ?? current.timeRange
        let nextMetadata = metadata ?? current.metadata
        let updated = KXSJ11CacheIndexEntry(
            key: key,
            symbol: current.symbol,
            timeframe: current.timeframe,
            timeRange: normalized(nextRange),
            metadata: nextMetadata,
            updatedAt: now
        )
        insert(updated)
        return updated
    }

    @discardableResult
    public mutating func remove(key: KLCacheKey) -> KXSJ11CacheIndexEntry? {
        guard let removed = entriesByKey.removeValue(forKey: key) else { return nil }
        let pair = PairKey(symbol: removed.symbol, timeframe: removed.timeframe)
        keysByPair[pair]?.remove(key)
        if keysByPair[pair]?.isEmpty == true {
            keysByPair.removeValue(forKey: pair)
        }
        return removed
    }

    @discardableResult
    public mutating func remove(symbol: KXSymbol, timeframe: KXTimeframe? = nil) -> [KXSJ11CacheIndexEntry] {
        let keys: [KLCacheKey]
        if let timeframe {
            keys = Array(keysByPair[PairKey(symbol: symbol, timeframe: timeframe)] ?? [])
        } else {
            keys = keysByPair
                .filter { $0.key.symbol == symbol }
                .flatMap { Array($0.value) }
        }
        return keys.compactMap { remove(key: $0) }
    }

    public func find(key: KLCacheKey) -> KXSJ11CacheIndexEntry? {
        entriesByKey[key]
    }

    public func find(symbol: KXSymbol, timeframe: KXTimeframe, range: KLTimeRange? = nil, includeExpired: Bool = false, now: Date = Date()) -> [KXSJ11CacheIndexEntry] {
        let pair = PairKey(symbol: symbol, timeframe: timeframe)
        let entries = (keysByPair[pair] ?? [])
            .compactMap { entriesByKey[$0] }
            .filter { includeExpired || !$0.isExpired(at: now) }
        guard let range else { return sorted(entries) }
        return sorted(entries.filter { $0.intersects(range) })
    }

    public func entries(forSymbol symbol: KXSymbol, includeExpired: Bool = false, now: Date = Date()) -> [KXSJ11CacheIndexEntry] {
        sorted(entriesByKey.values.filter { entry in
            entry.symbol == symbol && (includeExpired || !entry.isExpired(at: now))
        })
    }

    public func entries(forTimeframe timeframe: KXTimeframe, includeExpired: Bool = false, now: Date = Date()) -> [KXSJ11CacheIndexEntry] {
        sorted(entriesByKey.values.filter { entry in
            entry.timeframe == timeframe && (includeExpired || !entry.isExpired(at: now))
        })
    }

    public func coveredRanges(symbol: KXSymbol, timeframe: KXTimeframe, in requestedRange: KLTimeRange? = nil, includeExpired: Bool = false, now: Date = Date()) -> [KLTimeRange] {
        let entries = find(symbol: symbol, timeframe: timeframe, range: requestedRange, includeExpired: includeExpired, now: now)
        let ranges = entries.map { entry -> KLTimeRange in
            guard let requestedRange else { return entry.timeRange }
            return clipped(entry.timeRange, to: requestedRange)
        }
        return merge(ranges)
    }

    public func coverageReport(symbol: KXSymbol, timeframe: KXTimeframe, requestedRange: KLTimeRange, includeExpired: Bool = false, now: Date = Date()) -> KXSJ11CoverageReport {
        let requested = normalized(requestedRange)
        let matchingEntries = find(symbol: symbol, timeframe: timeframe, range: requested, includeExpired: includeExpired, now: now)
        let covered = merge(matchingEntries.map { clipped($0.timeRange, to: requested) })
        let gaps = gapRanges(symbol: symbol, timeframe: timeframe, requestedRange: requested, coveredRanges: covered)
        return KXSJ11CoverageReport(symbol: symbol, timeframe: timeframe, requestedRange: requested, coveredRanges: covered, gaps: gaps, matchingEntries: matchingEntries)
    }

    public func gaps(symbol: KXSymbol, timeframe: KXTimeframe, requestedRange: KLTimeRange, includeExpired: Bool = false, now: Date = Date()) -> [KLGapRange] {
        coverageReport(symbol: symbol, timeframe: timeframe, requestedRange: requestedRange, includeExpired: includeExpired, now: now).gaps
    }

    @discardableResult
    public mutating func removeExpired(now: Date = Date()) -> [KXSJ11CacheIndexEntry] {
        let expiredKeys = entriesByKey.values
            .filter { $0.isExpired(at: now) }
            .map { $0.key }
        return expiredKeys.compactMap { remove(key: $0) }
    }

    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        entriesByKey.removeAll(keepingCapacity: keepCapacity)
        keysByPair.removeAll(keepingCapacity: keepCapacity)
    }

    private mutating func register(key: KLCacheKey, symbol: KXSymbol, timeframe: KXTimeframe, range: KLTimeRange, metadata: KLCacheEntryDescriptor?, now: Date) -> KXSJ11CacheIndexEntry {
        let normalizedRange = normalized(range)
        let descriptor = metadata ?? KLCacheEntryDescriptor(key: key, createdAt: now, itemCount: 0, quality: .unknown)
        let entry = KXSJ11CacheIndexEntry(key: key, symbol: symbol, timeframe: timeframe, timeRange: normalizedRange, metadata: descriptor, updatedAt: now)
        insert(entry)
        return entry
    }

    private mutating func insert(_ entry: KXSJ11CacheIndexEntry) {
        if let old = entriesByKey[entry.key] {
            let oldPair = PairKey(symbol: old.symbol, timeframe: old.timeframe)
            keysByPair[oldPair]?.remove(entry.key)
            if keysByPair[oldPair]?.isEmpty == true {
                keysByPair.removeValue(forKey: oldPair)
            }
        }
        entriesByKey[entry.key] = entry
        let pair = PairKey(symbol: entry.symbol, timeframe: entry.timeframe)
        keysByPair[pair, default: []].insert(entry.key)
    }

    private func gapRanges(symbol: KXSymbol, timeframe: KXTimeframe, requestedRange: KLTimeRange, coveredRanges: [KLTimeRange]) -> [KLGapRange] {
        var cursor = requestedRange.startTime
        var gaps: [KLGapRange] = []

        for range in coveredRanges {
            if cursor < range.startTime {
                gaps.append(makeGap(symbol: symbol, timeframe: timeframe, start: cursor, end: range.startTime))
            }
            if cursor < range.endTime {
                cursor = range.endTime
            }
        }

        if cursor < requestedRange.endTime {
            gaps.append(makeGap(symbol: symbol, timeframe: timeframe, start: cursor, end: requestedRange.endTime))
        }

        return gaps
    }

    private func makeGap(symbol: KXSymbol, timeframe: KXTimeframe, start: Date, end: Date) -> KLGapRange {
        KLGapRange(
            symbol: symbol,
            timeframe: timeframe,
            startTime: start,
            endTime: end,
            expectedCount: expectedCount(from: start, to: end, timeframe: timeframe),
            actualCount: 0,
            reason: "cache index uncovered range"
        )
    }

    private func expectedCount(from start: Date, to end: Date, timeframe: KXTimeframe) -> Int {
        guard end > start else { return 0 }
        let seconds = timeframeSeconds(timeframe)
        guard seconds > 0 else { return 1 }
        return max(1, Int(ceil(end.timeIntervalSince(start) / seconds)))
    }

    private func timeframeSeconds(_ timeframe: KXTimeframe) -> TimeInterval {
        switch timeframe {
        case .oneSecond: return 1
        case .oneMinute: return 60
        case .threeMinutes: return 180
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1_800
        case .oneHour: return 3_600
        case .twoHours: return 7_200
        case .fourHours: return 14_400
        case .sixHours: return 21_600
        case .twelveHours: return 43_200
        case .oneDay: return 86_400
        case .twoDays: return 172_800
        case .threeDays: return 259_200
        case .oneWeek: return 604_800
        case .oneMonth: return 2_592_000
        case .threeMonths: return 0
        }
    }

    private func merge(_ ranges: [KLTimeRange]) -> [KLTimeRange] {
        let ordered = ranges.map { normalized($0) }.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime { return lhs.startTime < rhs.startTime }
            return lhs.endTime < rhs.endTime
        }
        guard var current = ordered.first else { return [] }
        var result: [KLTimeRange] = []

        for range in ordered.dropFirst() {
            if range.startTime <= current.endTime {
                if current.endTime < range.endTime {
                    current = KLTimeRange(startTime: current.startTime, endTime: range.endTime)
                }
            } else {
                result.append(current)
                current = range
            }
        }
        result.append(current)
        return result
    }

    private func clipped(_ range: KLTimeRange, to bounds: KLTimeRange) -> KLTimeRange {
        let source = normalized(range)
        let target = normalized(bounds)
        return KLTimeRange(startTime: max(source.startTime, target.startTime), endTime: min(source.endTime, target.endTime))
    }

    private func normalized(_ range: KLTimeRange) -> KLTimeRange {
        if range.startTime <= range.endTime { return range }
        return KLTimeRange(startTime: range.endTime, endTime: range.startTime)
    }

    private func sorted<S: Sequence>(_ entries: S) -> [KXSJ11CacheIndexEntry] where S.Element == KXSJ11CacheIndexEntry {
        entries.sorted { lhs, rhs in
            if lhs.symbol != rhs.symbol { return lhs.symbol < rhs.symbol }
            if lhs.timeframe.rawValue != rhs.timeframe.rawValue { return lhs.timeframe.rawValue < rhs.timeframe.rawValue }
            if lhs.timeRange.startTime != rhs.timeRange.startTime { return lhs.timeRange.startTime < rhs.timeRange.startTime }
            if lhs.timeRange.endTime != rhs.timeRange.endTime { return lhs.timeRange.endTime < rhs.timeRange.endTime }
            return lhs.key.description < rhs.key.description
        }
    }
}
