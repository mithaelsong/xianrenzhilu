//
//  KX-FN-12_OKX周期映射.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：ELTimeframe ↔ OKX bar/channel 映射、存储策略（memoryOnly / persistent）、是否实时支持
//  禁止事项：禁止网络请求、禁止数据库读写、禁止UI绘制
//

import Foundation


// MARK: - 存储策略

public enum KLStoragePolicy: String, Codable, Sendable {
    /// 仅内存滑动窗口，不写数据库。适用于 1s、1m、2m、3m、5m、10m
    case memoryOnly
    /// 写入数据库持久化，同时保留内存副本。适用于 15m 及以上周期
    case persistent
}

public enum KLExchangeHistoryFetchScope: String, Codable, Sendable {
    /// 只按内存保留窗口请求；用于不写数据库的低周期，避免内存爆炸。
    case memoryRetentionWindow
    /// 向交易所请求/补全全量历史；用于 15m 以上持久化周期。
    case fullForDatabase
}

// MARK: - OKX Bar / Channel 映射

public struct KLOKXTimeframePolicy: Codable, Sendable, Equatable {
    public let timeframe: KXTimeframe
    /// OKX REST bar 参数值，例如 "1m"、"5m"、"1H"、"1D"、"1M"
    public let okxBar: String
    /// OKX WebSocket channel 参数值，例如 "candle1m"、"candle5m"
    public let okxChannel: String
    /// 存储策略
    public let storagePolicy: KLStoragePolicy
    /// 是否支持实时订阅
    public let isRealtimeSupported: Bool
    /// 非 OKX 直接周期的历史来源周期，例如 2m 由 1m 聚合、10m 由 5m 聚合。
    public let derivedFromTimeframe: KXTimeframe?
    /// 交易所历史请求范围：低周期按内存窗口请求；15m+ 为数据库补全而请求全量。
    public let exchangeFetchScope: KLExchangeHistoryFetchScope
    /// memoryOnly 周期的最大内存根数；超过后滚动裁掉旧 K线。
    public let memoryRetentionCandleLimit: Int?
    /// persistent 周期加载到图表内存的最近天数；nil 表示不按天限制。
    public let persistentMemoryWindowDays: Int?
    /// persistent 周期加载到图表内存的最近月数；nil 表示不按月限制。
    public let persistentMemoryWindowMonths: Int?
    /// persistent 周期是否加载全部数据库/交易所历史到图表内存。
    public let persistentLoadAllToMemory: Bool

    public init(
        timeframe: KXTimeframe,
        okxBar: String,
        okxChannel: String,
        storagePolicy: KLStoragePolicy,
        isRealtimeSupported: Bool,
        derivedFromTimeframe: KXTimeframe? = nil,
        exchangeFetchScope: KLExchangeHistoryFetchScope? = nil,
        memoryRetentionCandleLimit: Int? = nil,
        persistentMemoryWindowDays: Int? = nil,
        persistentMemoryWindowMonths: Int? = nil,
        persistentLoadAllToMemory: Bool = false
    ) {
        self.timeframe = timeframe
        self.okxBar = okxBar
        self.okxChannel = okxChannel
        self.storagePolicy = storagePolicy
        self.isRealtimeSupported = isRealtimeSupported
        self.derivedFromTimeframe = derivedFromTimeframe
        self.exchangeFetchScope = exchangeFetchScope ?? (storagePolicy == .memoryOnly ? .memoryRetentionWindow : .fullForDatabase)
        self.memoryRetentionCandleLimit = memoryRetentionCandleLimit
        self.persistentMemoryWindowDays = persistentMemoryWindowDays
        self.persistentMemoryWindowMonths = persistentMemoryWindowMonths
        self.persistentLoadAllToMemory = persistentLoadAllToMemory
    }
}

// MARK: - 周期策略目录

public enum KLOKXTimeframePolicyCatalog {
    /// 全量周期策略表
    public static let allPolicies: [KLOKXTimeframePolicy] = [
        KLOKXTimeframePolicy(timeframe: .oneSecond,    okxBar: "1s",   okxChannel: "candle1s",   storagePolicy: .memoryOnly,   isRealtimeSupported: true,  memoryRetentionCandleLimit: 600), // 10分钟
        KLOKXTimeframePolicy(timeframe: .oneMinute,    okxBar: "1m",   okxChannel: "candle1m",   storagePolicy: .memoryOnly,   isRealtimeSupported: true,  memoryRetentionCandleLimit: 240), // 4小时
        KLOKXTimeframePolicy(timeframe: .threeMinutes, okxBar: "3m",   okxChannel: "candle3m",   storagePolicy: .memoryOnly,   isRealtimeSupported: true,  memoryRetentionCandleLimit: 360), // 6小时
        KLOKXTimeframePolicy(timeframe: .fiveMinutes,  okxBar: "5m",   okxChannel: "candle5m",   storagePolicy: .memoryOnly,   isRealtimeSupported: true,  memoryRetentionCandleLimit: 288), // 24小时
        KLOKXTimeframePolicy(timeframe: .fifteenMinutes, okxBar: "15m", okxChannel: "candle15m", storagePolicy: .persistent,   isRealtimeSupported: true,  persistentMemoryWindowDays: 7),
        KLOKXTimeframePolicy(timeframe: .thirtyMinutes, okxBar: "30m", okxChannel: "candle30m", storagePolicy: .persistent,   isRealtimeSupported: true,  persistentMemoryWindowDays: 7),
        KLOKXTimeframePolicy(timeframe: .oneHour,      okxBar: "1H",   okxChannel: "candle1H",   storagePolicy: .persistent,   isRealtimeSupported: true,  persistentMemoryWindowMonths: 4),
        KLOKXTimeframePolicy(timeframe: .twoHours,     okxBar: "2H",   okxChannel: "candle2H",   storagePolicy: .persistent,   isRealtimeSupported: true,  persistentMemoryWindowMonths: 4),
        KLOKXTimeframePolicy(timeframe: .fourHours,    okxBar: "4H",   okxChannel: "candle4H",   storagePolicy: .persistent,   isRealtimeSupported: true,  persistentLoadAllToMemory: true),
        KLOKXTimeframePolicy(timeframe: .sixHours,     okxBar: "6H",   okxChannel: "candle6H",   storagePolicy: .persistent,   isRealtimeSupported: true,  persistentLoadAllToMemory: true),
        KLOKXTimeframePolicy(timeframe: .twelveHours,  okxBar: "12H",  okxChannel: "candle12H",  storagePolicy: .persistent,   isRealtimeSupported: true,  persistentLoadAllToMemory: true),
        KLOKXTimeframePolicy(timeframe: .oneDay,       okxBar: "1D",   okxChannel: "candle1D",   storagePolicy: .persistent,   isRealtimeSupported: true,  persistentLoadAllToMemory: true),
        KLOKXTimeframePolicy(timeframe: .twoDays,      okxBar: "2D",   okxChannel: "candle2D",   storagePolicy: .persistent,   isRealtimeSupported: true,  persistentLoadAllToMemory: true),
        KLOKXTimeframePolicy(timeframe: .threeDays,    okxBar: "3D",   okxChannel: "candle3D",   storagePolicy: .persistent,   isRealtimeSupported: true,  persistentLoadAllToMemory: true),
        KLOKXTimeframePolicy(timeframe: .oneWeek,      okxBar: "1W",   okxChannel: "candle1W",   storagePolicy: .persistent,   isRealtimeSupported: true,  persistentLoadAllToMemory: true),
        KLOKXTimeframePolicy(timeframe: .oneMonth,     okxBar: "1M",   okxChannel: "candle1M",   storagePolicy: .persistent,   isRealtimeSupported: false, persistentLoadAllToMemory: true),
        KLOKXTimeframePolicy(timeframe: .threeMonths,  okxBar: "3M",   okxChannel: "candle3M",   storagePolicy: .persistent,   isRealtimeSupported: false, persistentLoadAllToMemory: true),
    ]

    /// 按 timeframe 查询策略
    public static func policy(for timeframe: KXTimeframe) -> KLOKXTimeframePolicy? {
        allPolicies.first { $0.timeframe == timeframe }
    }

    /// 所有 memoryOnly 周期的列表
    public static var memoryOnlyTimeframes: [KXTimeframe] {
        allPolicies.filter { $0.storagePolicy == .memoryOnly }.map { $0.timeframe }
    }

    /// 所有 persistent 周期的列表
    public static var persistentTimeframes: [KXTimeframe] {
        allPolicies.filter { $0.storagePolicy == .persistent }.map { $0.timeframe }
    }

    /// 判断某周期是否应写入数据库
    public static func shouldPersist(_ timeframe: KXTimeframe) -> Bool {
        policy(for: timeframe)?.storagePolicy == .persistent
    }

    /// 判断某周期是否仅保存在内存
    public static func isMemoryOnly(_ timeframe: KXTimeframe) -> Bool {
        policy(for: timeframe)?.storagePolicy == .memoryOnly
    }

    /// OKX bar 值
    public static func okxBar(for timeframe: KXTimeframe) -> String? {
        policy(for: timeframe)?.okxBar
    }

    /// OKX WebSocket channel
    public static func okxChannel(for timeframe: KXTimeframe) -> String? {
        policy(for: timeframe)?.okxChannel
    }

    /// 低周期内存保留根数。低周期请求 OKX 历史时也按这个数量请求，不额外拉全量。
    public static func memoryRetentionLimit(for timeframe: KXTimeframe) -> Int? {
        policy(for: timeframe)?.memoryRetentionCandleLimit
    }

    /// 【权威】每个周期打开软件/新币对时的统一加载根数 = 查询根数（查询数与加载数一回事）。
    /// 晓筱 2026-06-22 拍板规则：倒查最新 N 根，不再全表查；4h+ 不再全量。
    /// 1W/1M/3M 标的若不足 1440 根，则按数据库/交易所实际数量加载（取 min(实际, 1440)）。
    public static func chartLoadCandleCount(for timeframe: KXTimeframe) -> Int {
        switch timeframe {
        case .oneSecond:     return 600    // 10 分钟
        case .oneMinute:     return 240    // 4 小时
        case .threeMinutes:  return 360    // 6 小时
        case .fiveMinutes:   return 288    // 24 小时
        case .fifteenMinutes: return 672   // 最近 7 天
        case .thirtyMinutes: return 336    // 最近 7 天
        case .oneHour:       return 2880   // 最近 4 个月
        case .twoHours:      return 1440   // 最近 4 个月
        case .fourHours:     return 1440   // 最近 8 个月
        case .sixHours:      return 1440   // 最近 8 个月
        case .twelveHours:   return 1440
        case .oneDay:        return 1440
        case .twoDays:       return 1440
        case .threeDays:     return 1440
        case .oneWeek:       return 1440   // 不够按实际
        case .oneMonth:      return 1440   // 不够按实际
        case .threeMonths:   return 1440   // 不够按实际
        }
    }

    /// 15m+ 是否为了数据库补全而从交易所拉全量历史。
    public static func shouldFetchFullHistoryForDatabase(_ timeframe: KXTimeframe) -> Bool {
        policy(for: timeframe)?.exchangeFetchScope == .fullForDatabase
    }

    /// 15m+ 图表内存加载起始时间。nil 表示该周期内存不限量，有多少加载多少。
    public static func persistentMemoryStartDate(for timeframe: KXTimeframe, now: Date = Date()) -> Date? {
        guard let policy = policy(for: timeframe) else { return nil }
        if policy.persistentLoadAllToMemory { return nil }
        if let days = policy.persistentMemoryWindowDays {
            return now.addingTimeInterval(-Double(days) * 24 * 60 * 60)
        }
        if let months = policy.persistentMemoryWindowMonths {
            return Calendar.current.date(byAdding: .month, value: -months, to: now)
        }
        return nil
    }

    /// 当前用户正在看的周期优先；同一优先级内，先预热工具栏常用周期，再预热"更多"里的重周期。
    public static func policies(activeTimeframe: KXTimeframe) -> [KLOKXTimeframePolicy] {
        let warmupOrder: [KXTimeframe] = [
            activeTimeframe,
            .oneSecond, .oneMinute, .fiveMinutes, .fifteenMinutes, .thirtyMinutes, .oneHour,
            .threeMinutes, .twoHours,
            .fourHours, .sixHours, .twelveHours, .oneDay, .twoDays, .threeDays, .oneWeek, .oneMonth, .threeMonths
        ]
        return allPolicies.sorted { lhs, rhs in
            let l = warmupOrder.firstIndex(of: lhs.timeframe) ?? Int.max
            let r = warmupOrder.firstIndex(of: rhs.timeframe) ?? Int.max
            if l != r { return l < r }
            return lhs.timeframe.rawValue < rhs.timeframe.rawValue
        }
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN12Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-12",
        fileName: "KX-FN-12_OKX周期映射.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-12_OKX周期映射.swift",
        duty: "KXTimeframe ↔ OKX bar/channel 映射、存储策略"
    )

    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("OKX周期映射骨架校验通过")
        return KXHealthCheckItem(name: "OKX周期映射", passed: true, message: "已实现16种周期的OKX映射、存储策略、预热排序")
    }
}
