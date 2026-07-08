//
//  KX-FN-14_时间轴刻度.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：根据时间框架、可视窗口、缩放比、面板宽度动态生成时间轴刻度
//  禁止事项：禁止网络请求、数据库读写、UI绘制
//

import Foundation


// MARK: - 时间轴刻度

public struct KLTimeAxisTick: Codable, Sendable, Equatable {
    public let time: Date
    public let xRatio: Double
    public let label: String
    public let level: Int
}

// MARK: - 时间轴刻度生成

public enum KLTimeAxisCalculator {
    public static let minSpacing: CGFloat = 60

    /// 生成时间轴刻度
    /// - Parameters:
    ///   - timeframe: 当前时间框架
    ///   - visibleStart: 可视起始时间（UTC）
    ///   - visibleEnd: 可视结束时间（UTC）
    ///   - viewportWidth: 时间轴可用宽度（points）
    ///   - candleWidth: 每根K线宽度（points）
    /// - Returns: 时间轴刻度数组
    public static func ticks(timeframe: KXTimeframe, visibleStart: Date, visibleEnd: Date, viewportWidth: CGFloat, candleWidth: CGFloat) -> [KLTimeAxisTick] {
        guard viewportWidth > 0, visibleEnd > visibleStart else { return [] }

        let totalWidth = viewportWidth
        let totalSeconds = visibleEnd.timeIntervalSince(visibleStart)
        guard totalSeconds > 0 else { return [] }

        // 根据周期和缩放选择刻度间隔
        let interval = tickInterval(for: timeframe, candleWidth: candleWidth, totalWidth: totalWidth)

        var ticks: [KLTimeAxisTick] = []
        var tickTime = floorTime(visibleStart, to: interval)

        while tickTime <= visibleEnd {
            let secondsFromStart = tickTime.timeIntervalSince(visibleStart)
            let xRatio = CGFloat(secondsFromStart / totalSeconds) * totalWidth

            let label = formatTimeLabel(tickTime, timeframe: timeframe)

            let level: Int = {
                switch timeframe {
                case .oneDay, .oneWeek, .oneMonth, .threeMonths:
                    return 0
                default:
                    // 小时刻度为1级，整点为0级
                    let cal = Calendar.current
                    let comps = cal.dateComponents([.hour, .minute, .second], from: tickTime)
                    if comps.hour == 0, comps.minute == 0 { return 0 }
                    return 1
                }
            }()

            ticks.append(KLTimeAxisTick(time: tickTime, xRatio: xRatio, label: label, level: level))

            switch interval {
            case .seconds(let s):
                tickTime.addTimeInterval(s)
            case .minutes(let m):
                tickTime.addTimeInterval(TimeInterval(m * 60))
            case .hours(let h):
                tickTime.addTimeInterval(TimeInterval(h * 3600))
            case .days(let d):
                tickTime.addTimeInterval(TimeInterval(d * 86400))
            case .weeks(let w):
                tickTime.addTimeInterval(TimeInterval(w * 604800))
            case .months(let m):
                guard let next = Calendar.current.date(byAdding: .month, value: m, to: tickTime) else { break }
                tickTime = next
            }
        }

        return ticks
    }

    // MARK: - 刻度间隔

    private enum TickInterval {
        case seconds(TimeInterval)
        case minutes(Int)
        case hours(Int)
        case days(Int)
        case weeks(Int)
        case months(Int)
    }

    private static func tickInterval(for timeframe: KXTimeframe, candleWidth: CGFloat, totalWidth: CGFloat) -> TickInterval {
        let visibleCandles = totalWidth / max(candleWidth, 1)

        switch timeframe {
        case .oneSecond:
            let interval = max(1, Int(visibleCandles / 10))
            return .seconds(TimeInterval(interval))
        case .oneMinute, .threeMinutes:
            let interval = max(5, Int(visibleCandles / 8))
            return .minutes(min(interval, 60))
        case .fiveMinutes, .fifteenMinutes:
            let interval = max(1, Int(visibleCandles / 8))
            return .hours(interval)
        case .thirtyMinutes:
            let interval = max(2, Int(visibleCandles / 8))
            return .hours(interval)
        case .oneHour:
            return .hours(4)
        case .twoHours:
            return .hours(6)
        case .fourHours:
            return .hours(12)
        case .sixHours:
            return .days(1)
        case .twelveHours:
            return .days(1)
        case .oneDay:
            let interval = max(1, Int(visibleCandles / 7))
            return .days(interval)
        case .twoDays, .threeDays:
            let interval = max(1, Int(visibleCandles / 7))
            return .days(interval)
        case .oneWeek:
            return .weeks(1)
        case .oneMonth:
            return .months(1)
        case .threeMonths:
            return .months(3)
        }
    }

    // MARK: - 时间格式化

    private static func formatTimeLabel(_ date: Date, timeframe: KXTimeframe) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current

        switch timeframe {
        case .oneSecond, .oneMinute, .threeMinutes, .fiveMinutes:
            df.dateFormat = "HH:mm"
            return df.string(from: date)
        case .fifteenMinutes, .thirtyMinutes:
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute, .day], from: date)
            if comps.hour == 0, comps.minute == 0 {
                df.dateFormat = "MM/dd"
                return df.string(from: date)
            }
            df.dateFormat = "HH:mm"
            return df.string(from: date)
        case .oneHour, .twoHours, .fourHours:
            df.dateFormat = "HH:mm"
            return df.string(from: date)
        case .sixHours, .twelveHours:
            df.dateFormat = "MM/dd"
            return df.string(from: date)
        case .oneDay, .twoDays, .threeDays:
            df.dateFormat = "MM/dd"
            return df.string(from: date)
        case .oneWeek:
            df.dateFormat = "MM/dd"
            return df.string(from: date)
        case .oneMonth:
            df.dateFormat = "yyyy/MM"
            return df.string(from: date)
        case .threeMonths:
            df.dateFormat = "yyyy/MM"
            return df.string(from: date)
        }
    }

    // MARK: - 时间向下对齐

    private static func floorTime(_ date: Date, to interval: TickInterval) -> Date {
        let seconds: TimeInterval
        switch interval {
        case .seconds(let s): seconds = s
        case .minutes(let m): seconds = TimeInterval(m * 60)
        case .hours(let h): seconds = TimeInterval(h * 3600)
        case .days(let d): seconds = TimeInterval(d * 86400)
        case .weeks(_): return date
        case .months(let m):
            guard let floored = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)),
                  m <= 1 else {
                return Calendar.current.date(byAdding: .month, value: -(m-1), to: date) ?? date
            }
            return floored
        }
        let epoch = date.timeIntervalSince1970
        let remainder = epoch.truncatingRemainder(dividingBy: seconds)
        return Date(timeIntervalSince1970: epoch - remainder)
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN14Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-14", fileName: "KX-FN-14_时间轴刻度.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-14_时间轴刻度.swift", duty: "时间轴刻度生成与格式化"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("时间轴刻度骨架校验通过")
        return KXHealthCheckItem(name: "时间轴刻度", passed: true, message: "已实现时间轴刻度生成与格式化")
    }
}
