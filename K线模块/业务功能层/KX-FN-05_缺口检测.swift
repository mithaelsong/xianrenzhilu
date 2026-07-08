//
//  KX-FN-05_缺口检测.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：检查指定币对、周期、时间范围内的 K线缺口
//  禁止事项：禁止补洞执行、禁止网络请求
//

import Foundation


// MARK: - K线缺口检测

public enum KXFN05Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-05",
        fileName: "KX-FN-05_缺口检测.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-05_缺口检测.swift",
        duty: "检查指定币对、周期、时间范围内的 K线缺口"
    )

    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("K线缺口检测骨架校验通过")
        return KXHealthCheckItem(name: "K线缺口检测", passed: true, message: "已实现本地 K线缺口检测；不执行补洞、网络请求、数据库读写或 UI 绘制")
    }

    public static func placeholder() {
        // 本文件已实现：检查指定币对、周期、时间范围内的 K线缺口。
        // 边界约定：KLGapRange.startTime 为首根缺失 K线开盘时间，endTime 为缺口右边界（左闭右开）。
    }
}

// MARK: - 缺口检测器

public struct KXFN05GapDetector: KLGapDetectingProtocol {
    public init() {}

    public static func detectGaps(query: KLKLineQuery, candles: [KLCandlePoint]) throws -> [KLGapRange] {
        try Self().detectGaps(query: query, candles: candles)
    }

    public func detectGaps(query: KLKLineQuery, candles: [KLCandlePoint]) throws -> [KLGapRange] {
        let symbol = query.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !symbol.isEmpty else {
            throw KLModuleError.invalidSymbol(value: query.symbol)
        }

        guard let rangeStart = query.startTime, let rangeEnd = query.endTime else {
            throw KLModuleError.invalidQuery(reason: "缺口检测必须提供 startTime 与 endTime")
        }

        guard rangeStart < rangeEnd else {
            throw KLModuleError.invalidQuery(reason: "startTime 必须早于 endTime")
        }

        let expectedOpenTimes = try makeExpectedOpenTimes(from: rangeStart, to: rangeEnd, timeframe: query.timeframe)
        guard !expectedOpenTimes.isEmpty else { return [] }

        let existingOpenTimes = Set(
            candles.lazy
                .filter { candle in
                    candle.symbol == symbol &&
                    candle.timeframe == query.timeframe &&
                    candle.openTime >= rangeStart &&
                    candle.openTime < rangeEnd &&
                    (query.includeUnclosed || candle.isClosed)
                }
                .map(\.openTime)
        )

        var gaps: [KLGapRange] = []
        var gapStart: Date?
        var missingCount = 0

        for openTime in expectedOpenTimes {
            if existingOpenTimes.contains(openTime) {
                if let start = gapStart {
                    gaps.append(makeGap(query: query, symbol: symbol, start: start, end: openTime, expectedCount: missingCount))
                    gapStart = nil
                    missingCount = 0
                }
            } else {
                if gapStart == nil { gapStart = openTime }
                missingCount += 1
            }
        }

        if let start = gapStart {
            gaps.append(makeGap(query: query, symbol: symbol, start: start, end: rangeEnd, expectedCount: missingCount))
        }

        return gaps
    }

    private func makeGap(query: KLKLineQuery, symbol: KXSymbol, start: Date, end: Date, expectedCount: Int) -> KLGapRange {
        KLGapRange(
            symbol: symbol,
            timeframe: query.timeframe,
            startTime: start,
            endTime: end,
            expectedCount: expectedCount,
            actualCount: 0,
            reason: "missing_candles; interval=[startTime,endTime); includeUnclosed=\(query.includeUnclosed)"
        )
    }

    private func makeExpectedOpenTimes(from start: Date, to end: Date, timeframe: KXTimeframe) throws -> [Date] {
        var result: [Date] = []
        var current = start
        let maxIterations = 1_000_000
        var iterationCount = 0

        for _ in 0..<maxIterations {
            guard current < end else { break }
            result.append(current)
            iterationCount += 1

            guard let next = nextOpenTime(after: current, timeframe: timeframe), next > current else {
                break
            }
            current = next
        }

        guard iterationCount < maxIterations else {
            throw KLModuleError.invalidQuery(reason: "缺口检测迭代超限：\(timeframe.rawValue) 区间 \(start) ~ \(end) 生成的开盘时间数量超过 100 万")
        }

        return result
    }

    private func nextOpenTime(after date: Date, timeframe: KXTimeframe) -> Date? {
        if let seconds = fixedSeconds(for: timeframe) {
            return date.addingTimeInterval(TimeInterval(seconds))
        }

        switch timeframe {
        case .oneSecond, .oneMinute, .threeMinutes, .fiveMinutes,
                .fifteenMinutes, .thirtyMinutes,
                .oneHour, .twoHours, .fourHours, .sixHours, .twelveHours,
                .oneDay, .twoDays, .threeDays, .oneWeek:
            return nil
        case .oneMonth:
            return Calendar(identifier: .gregorian).date(byAdding: .month, value: 1, to: date)
        case .threeMonths:
            return Calendar(identifier: .gregorian).date(byAdding: .month, value: 3, to: date)
        }
    }

    private func fixedSeconds(for timeframe: KXTimeframe) -> Int? {
        switch timeframe {
        case .oneSecond:
            return 1
        case .oneMinute:
            return 60
        case .threeMinutes:
            return 3 * 60
        case .fiveMinutes:
            return 5 * 60
        case .fifteenMinutes:
            return 15 * 60
        case .thirtyMinutes:
            return 30 * 60
        case .oneHour:
            return 60 * 60
        case .twoHours:
            return 2 * 60 * 60
        case .fourHours:
            return 4 * 60 * 60
        case .sixHours:
            return 6 * 60 * 60
        case .twelveHours:
            return 12 * 60 * 60
        case .oneDay:
            return 24 * 60 * 60
        case .twoDays:
            return 2 * 24 * 60 * 60
        case .threeDays:
            return 3 * 24 * 60 * 60
        case .oneWeek:
            return 7 * 24 * 60 * 60
        case .oneMonth, .threeMonths:
            return nil
        }
    }
}
