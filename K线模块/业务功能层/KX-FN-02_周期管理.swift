//
//  KX-FN-02_周期管理.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：维护周期枚举、周期排序、周期显示名、周期秒数转换
//  禁止事项：禁止数据库写入、禁止 UI 绘制
//

import Foundation


// MARK: - 周期体系管理骨架

public enum KXFN02Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-02",
        fileName: "KX-FN-02_周期管理.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-02_周期管理.swift",
        duty: "维护周期枚举、周期排序、周期显示名、周期秒数转换"
    )

    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("周期体系管理骨架校验通过")
        return KXHealthCheckItem(name: "周期体系管理", passed: true, message: "已实现周期合法性校验、排序、显示名、秒数转换与字符串解析")
    }

    public static func placeholder() {
        // 本文件提供纯内存周期目录能力，不请求 OKX、不读写数据库、不绘制 UI、不实现缓存。
    }
}

// MARK: - 周期体系目录

public struct KXFN02TimeframeCatalog: KXTimeframeCatalogProtocol, Sendable {
    public init() {}

    public func listTimeframes() -> [KXTimeframeDescriptor] {
        KXFN02TimeframeManager.supportedDescriptors
    }

    public func descriptor(for timeframe: KXTimeframe) -> KXTimeframeDescriptor? {
        KXFN02TimeframeManager.descriptor(for: timeframe)
    }
}

// MARK: - 周期体系管理

public enum KXFN02TimeframeManager {
    public static let supportedTimeframes: [KXTimeframe] = [
        .oneSecond,
        .oneMinute,
        .threeMinutes,
        .fiveMinutes,
        .fifteenMinutes,
        .thirtyMinutes,
        .oneHour,
        .twoHours,
        .fourHours,
        .sixHours,
        .twelveHours,
        .oneDay,
        .twoDays,
        .threeDays,
        .oneWeek,
        .oneMonth,
        .threeMonths
    ]

    public static let supportedDescriptors: [KXTimeframeDescriptor] = [
        KXTimeframeDescriptor(timeframe: .oneSecond, unit: .second, amount: 1, seconds: 1, displayName: "1秒", exchangeValue: "1s"),
        KXTimeframeDescriptor(timeframe: .oneMinute, unit: .minute, amount: 1, seconds: 60, displayName: "1分钟", exchangeValue: "1m"),
        KXTimeframeDescriptor(timeframe: .threeMinutes, unit: .minute, amount: 3, seconds: 180, displayName: "3分钟", exchangeValue: "3m"),
        KXTimeframeDescriptor(timeframe: .fiveMinutes, unit: .minute, amount: 5, seconds: 300, displayName: "5分钟", exchangeValue: "5m"),
        KXTimeframeDescriptor(timeframe: .fifteenMinutes, unit: .minute, amount: 15, seconds: 900, displayName: "15分钟", exchangeValue: "15m"),
        KXTimeframeDescriptor(timeframe: .thirtyMinutes, unit: .minute, amount: 30, seconds: 1_800, displayName: "30分钟", exchangeValue: "30m"),
        KXTimeframeDescriptor(timeframe: .oneHour, unit: .hour, amount: 1, seconds: 3_600, displayName: "1小时", exchangeValue: "1h"),
        KXTimeframeDescriptor(timeframe: .twoHours, unit: .hour, amount: 2, seconds: 7_200, displayName: "2小时", exchangeValue: "2h"),
        KXTimeframeDescriptor(timeframe: .fourHours, unit: .hour, amount: 4, seconds: 14_400, displayName: "4小时", exchangeValue: "4h"),
        KXTimeframeDescriptor(timeframe: .sixHours, unit: .hour, amount: 6, seconds: 21_600, displayName: "6小时", exchangeValue: "6h"),
        KXTimeframeDescriptor(timeframe: .twelveHours, unit: .hour, amount: 12, seconds: 43_200, displayName: "12小时", exchangeValue: "12h"),
        KXTimeframeDescriptor(timeframe: .oneDay, unit: .day, amount: 1, seconds: 86_400, displayName: "1天", exchangeValue: "1d"),
        KXTimeframeDescriptor(timeframe: .twoDays, unit: .day, amount: 2, seconds: 172_800, displayName: "2天", exchangeValue: "2d"),
        KXTimeframeDescriptor(timeframe: .threeDays, unit: .day, amount: 3, seconds: 259_200, displayName: "3天", exchangeValue: "3d"),
        KXTimeframeDescriptor(timeframe: .oneWeek, unit: .week, amount: 1, seconds: 604_800, displayName: "1周", exchangeValue: "1w"),
        KXTimeframeDescriptor(timeframe: .oneMonth, unit: .month, amount: 1, seconds: 0, displayName: "1月", exchangeValue: "1M", isRealtimeSupported: false),
        KXTimeframeDescriptor(timeframe: .threeMonths, unit: .month, amount: 3, seconds: 0, displayName: "3月", exchangeValue: "3M", isRealtimeSupported: false)
    ]

    public static func isValid(_ timeframe: KXTimeframe) -> Bool {
        descriptor(for: timeframe) != nil
    }

    public static func validate(_ timeframe: KXTimeframe) throws {
        guard isValid(timeframe) else {
            throw KLModuleError.invalidTimeframe(value: timeframe.rawValue)
        }
    }

    public static func sorted(_ timeframes: [KXTimeframe]) -> [KXTimeframe] {
        timeframes.sorted { lhs, rhs in
            let lhsSeconds = seconds(for: lhs) ?? Int.max
            let rhsSeconds = seconds(for: rhs) ?? Int.max
            if lhsSeconds != rhsSeconds { return lhsSeconds < rhsSeconds }
            return lhs.rawValue < rhs.rawValue
        }
    }

    public static func descriptor(for timeframe: KXTimeframe) -> KXTimeframeDescriptor? {
        supportedDescriptors.first { $0.timeframe == timeframe }
    }

    public static func displayName(for timeframe: KXTimeframe) -> String? {
        descriptor(for: timeframe)?.displayName
    }

    public static func seconds(for timeframe: KXTimeframe) -> Int? {
        descriptor(for: timeframe)?.seconds
    }

    public static func timeframe(forSeconds seconds: Int) -> KXTimeframe? {
        guard seconds > 0 else { return nil }
        return supportedDescriptors.first { $0.seconds == seconds }?.timeframe
    }

    public static func parse(_ string: String) -> KXTimeframe? {
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else { return nil }

        if let exactMatch = supportedDescriptors.first(where: { $0.timeframe.rawValue == value || $0.displayName == value || $0.exchangeValue == value }) {
            return exactMatch.timeframe
        }

        let normalized = normalizeInput(value)
        return supportedDescriptors.first { $0.timeframe.rawValue == normalized || $0.exchangeValue == normalized }?.timeframe
    }

    public static func parseOrThrow(_ string: String) throws -> KXTimeframe {
        guard let timeframe = parse(string) else {
            throw KLModuleError.invalidTimeframe(value: string)
        }
        return timeframe
    }

    private static func normalizeInput(_ value: String) -> String {
        guard let unit = value.last else { return value }
        let amount = String(value.dropLast())

        switch unit {
        case "S":
            return amount + "s"
        case "H":
            return amount + "h"
        case "D":
            return amount + "d"
        case "W":
            return amount + "w"
        case "M":
            return amount + "M"
        default:
            return value
        }
    }
}
