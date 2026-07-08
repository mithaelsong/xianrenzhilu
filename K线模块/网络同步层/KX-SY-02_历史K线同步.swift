//
//  KX-SY-02_历史K线同步.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：OKX 历史 K线同步任务纯逻辑：计划、请求描述、响应解析、摘要
//  禁止事项：禁止真实请求 OKX、禁止真实写库、禁止文件写入
//

import Foundation


// MARK: - OKX历史K线同步纯逻辑类型

public enum KXSY02PaginationDirection: String, Codable, Sendable, CaseIterable {
    case older
    case newer

    public var displayName: String {
        switch self {
        case .older:
            return "向更早历史分页"
        case .newer:
            return "向更新历史分页"
        }
    }
}

public struct KXSY02HistorySyncTask: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let startTime: Date?
    public let endTime: Date?
    public let limit: Int
    public let before: String?
    public let after: String?
    public let direction: KXSY02PaginationDirection
    public let createdAt: Date

    public init(
        id: String,
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        startTime: Date? = nil,
        endTime: Date? = nil,
        limit: Int = KXSY02Skeleton.defaultLimit,
        before: String? = nil,
        after: String? = nil,
        direction: KXSY02PaginationDirection = .older,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.symbol = symbol
        self.timeframe = timeframe
        self.startTime = startTime
        self.endTime = endTime
        self.limit = limit
        self.before = before
        self.after = after
        self.direction = direction
        self.createdAt = createdAt
    }
}

public struct KXSY02QueryParameter: Codable, Equatable, Sendable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public struct KXSY02OKXHistoryCandlesRequest: Codable, Equatable, Sendable {
    public let method: String
    public let host: String
    public let path: String
    public let queryParameters: [KXSY02QueryParameter]
    public let note: String

    public init(
        method: String = "GET",
        host: String = "https://www.okx.com",
        path: String = "/api/v5/market/history-candles",
        queryParameters: [KXSY02QueryParameter],
        note: String = "仅为请求描述，不执行网络请求"
    ) {
        self.method = method
        self.host = host
        self.path = path
        self.queryParameters = queryParameters
        self.note = note
    }

    public var queryDictionary: [String: String] {
        var result: [String: String] = [:]
        for item in queryParameters {
            result[item.name] = item.value
        }
        return result
    }

    public var debugURLString: String {
        let query = queryParameters
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "&")
        if query.isEmpty {
            return host + path
        }
        return host + path + "?" + query
    }
}

public struct KXSY02HistoryPagePlan: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let pageIndex: Int
    public let direction: KXSY02PaginationDirection
    public let request: KXSY02OKXHistoryCandlesRequest
    public let plannedStartTime: Date?
    public let plannedEndTime: Date?
    public let plannedBefore: String?
    public let plannedAfter: String?
    public let expectedLimit: Int

    public init(
        id: String,
        pageIndex: Int,
        direction: KXSY02PaginationDirection,
        request: KXSY02OKXHistoryCandlesRequest,
        plannedStartTime: Date?,
        plannedEndTime: Date?,
        plannedBefore: String?,
        plannedAfter: String?,
        expectedLimit: Int
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.direction = direction
        self.request = request
        self.plannedStartTime = plannedStartTime
        self.plannedEndTime = plannedEndTime
        self.plannedBefore = plannedBefore
        self.plannedAfter = plannedAfter
        self.expectedLimit = expectedLimit
    }
}

public struct KXSY02HistorySyncPlan: Codable, Equatable, Sendable {
    public let task: KXSY02HistorySyncTask
    public let pages: [KXSY02HistoryPagePlan]
    public let estimatedCandleCount: Int?
    public let estimatedRequestCount: Int
    public let generatedAt: Date
    public let summary: String

    public init(
        task: KXSY02HistorySyncTask,
        pages: [KXSY02HistoryPagePlan],
        estimatedCandleCount: Int?,
        generatedAt: Date = Date(),
        summary: String
    ) {
        self.task = task
        self.pages = pages
        self.estimatedCandleCount = estimatedCandleCount
        self.estimatedRequestCount = pages.count
        self.generatedAt = generatedAt
        self.summary = summary
    }
}

public struct KXSY02RejectedCandleRow: Error, Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let rowIndex: Int
    public let rawValues: [String]
    public let reason: String

    public init(id: String, rowIndex: Int, rawValues: [String], reason: String) {
        self.id = id
        self.rowIndex = rowIndex
        self.rawValues = rawValues
        self.reason = reason
    }
}

public struct KXSY02ParseResult: Codable, Equatable, Sendable {
    public let candles: [KLCandlePoint]
    public let rejectedRows: [KXSY02RejectedCandleRow]
    public let sourceRowCount: Int
    public let parsedAt: Date

    public init(candles: [KLCandlePoint], rejectedRows: [KXSY02RejectedCandleRow], sourceRowCount: Int, parsedAt: Date = Date()) {
        self.candles = candles
        self.rejectedRows = rejectedRows
        self.sourceRowCount = sourceRowCount
        self.parsedAt = parsedAt
    }

    public var acceptedRowCount: Int { candles.count }
    public var rejectedRowCount: Int { rejectedRows.count }
    public var isFullyAccepted: Bool { rejectedRows.isEmpty }
}

public struct KXSY02CompletionSummary: Codable, Equatable, Sendable {
    public let taskID: String
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let direction: KXSY02PaginationDirection
    public let plannedRequestCount: Int
    public let parsedCandleCount: Int
    public let rejectedRowCount: Int
    public let firstOpenTime: Date?
    public let lastOpenTime: Date?
    public let completedAt: Date
    public let message: String

    public init(
        taskID: String,
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        direction: KXSY02PaginationDirection,
        plannedRequestCount: Int,
        parsedCandleCount: Int,
        rejectedRowCount: Int,
        firstOpenTime: Date?,
        lastOpenTime: Date?,
        completedAt: Date = Date(),
        message: String
    ) {
        self.taskID = taskID
        self.symbol = symbol
        self.timeframe = timeframe
        self.direction = direction
        self.plannedRequestCount = plannedRequestCount
        self.parsedCandleCount = parsedCandleCount
        self.rejectedRowCount = rejectedRowCount
        self.firstOpenTime = firstOpenTime
        self.lastOpenTime = lastOpenTime
        self.completedAt = completedAt
        self.message = message
    }
}

public struct KXSY02FailureSummary: Error, Codable, Equatable, Sendable {
    public let taskID: String?
    public let symbol: KXSymbol?
    public let timeframe: KXTimeframe?
    public let failedPageIndex: Int?
    public let failedRequest: KXSY02OKXHistoryCandlesRequest?
    public let reason: String
    public let failedAt: Date

    public init(
        taskID: String?,
        symbol: KXSymbol?,
        timeframe: KXTimeframe?,
        failedPageIndex: Int? = nil,
        failedRequest: KXSY02OKXHistoryCandlesRequest? = nil,
        reason: String,
        failedAt: Date = Date()
    ) {
        self.taskID = taskID
        self.symbol = symbol
        self.timeframe = timeframe
        self.failedPageIndex = failedPageIndex
        self.failedRequest = failedRequest
        self.reason = reason
        self.failedAt = failedAt
    }
}

// MARK: - OKX历史K线同步骨架 / 纯逻辑入口

public enum KXSY02Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let defaultLimit = 100
    public static let maxLimit = 100
    public static let okxHistoryCandlesPath = "/api/v5/market/history-candles"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SY-02",
        fileName: "KX-SY-02_OKX历史K线同步.swift",
        layer: .sync,
        relativePath: "同步层/KX-SY-02_OKX历史K线同步.swift",
        duty: "OKX 历史 K线同步任务纯逻辑"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "OKX历史K线同步", passed: true, message: "已支持任务计划、history-candles 请求描述、分页计划、响应数组解析和摘要生成；不发真实网络请求")
    }

    public static func makeTask(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        startTime: Date? = nil,
        endTime: Date? = nil,
        limit: Int = defaultLimit,
        before: String? = nil,
        after: String? = nil,
        direction: KXSY02PaginationDirection = .older,
        createdAt: Date = Date()
    ) -> KXSY02HistorySyncTask {
        let id = makeTaskID(symbol: symbol, timeframe: timeframe, createdAt: createdAt)
        return KXSY02HistorySyncTask(
            id: id,
            symbol: symbol,
            timeframe: timeframe,
            startTime: startTime,
            endTime: endTime,
            limit: limit,
            before: before,
            after: after,
            direction: direction,
            createdAt: createdAt
        )
    }

    public static func makeRequestDescription(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        limit: Int = defaultLimit,
        before: String? = nil,
        after: String? = nil
    ) -> KXSY02OKXHistoryCandlesRequest {
        var parameters = [
            KXSY02QueryParameter(name: "instId", value: symbol),
            KXSY02QueryParameter(name: "bar", value: timeframe.rawValue),
            KXSY02QueryParameter(name: "limit", value: String(limit))
        ]
        if let before, before.isEmpty == false {
            parameters.append(KXSY02QueryParameter(name: "before", value: before))
        }
        if let after, after.isEmpty == false {
            parameters.append(KXSY02QueryParameter(name: "after", value: after))
        }
        return KXSY02OKXHistoryCandlesRequest(queryParameters: parameters)
    }

    public static func makePlan(task: KXSY02HistorySyncTask, maxPages: Int = 100) -> Result<KXSY02HistorySyncPlan, KXSY02FailureSummary> {
        if let failure = validate(task: task, maxPages: maxPages) {
            return .failure(failure)
        }

        let seconds = secondsPerCandle(timeframe: task.timeframe)
        let estimatedCount = estimateCandleCount(startTime: task.startTime, endTime: task.endTime, secondsPerCandle: seconds)
        let pageCount = estimatedCount.map { max(1, Int(ceil(Double($0) / Double(task.limit)))) } ?? 1
        let cappedPageCount = min(pageCount, maxPages)
        let pages = makePages(task: task, secondsPerCandle: seconds, pageCount: cappedPageCount)
        let summary = "生成 OKX history-candles 纯逻辑分页计划：\(pages.count) 个请求描述，方向：\(task.direction.displayName)，不执行网络请求。"
        return .success(KXSY02HistorySyncPlan(task: task, pages: pages, estimatedCandleCount: estimatedCount, summary: summary))
    }

    public static func parseHistoryCandlesResponse(
        rows: [[String]],
        symbol: KXSymbol,
        timeframe: KXTimeframe
    ) -> KXSY02ParseResult {
        var candles: [KLCandlePoint] = []
        var rejected: [KXSY02RejectedCandleRow] = []
        let seconds = secondsPerCandle(timeframe: timeframe)

        for (index, row) in rows.enumerated() {
            let parsed = parseCandleRow(row, rowIndex: index, symbol: symbol, timeframe: timeframe, secondsPerCandle: seconds)
            switch parsed {
            case .success(let candle):
                candles.append(candle)
            case .failure(let rejection):
                rejected.append(rejection)
            }
        }

        let sortedCandles = candles.sorted { $0.openTime < $1.openTime }
        return KXSY02ParseResult(candles: sortedCandles, rejectedRows: rejected, sourceRowCount: rows.count)
    }

    public static func makeCompletionSummary(plan: KXSY02HistorySyncPlan, parseResult: KXSY02ParseResult) -> KXSY02CompletionSummary {
        let first = parseResult.candles.first?.openTime
        let last = parseResult.candles.last?.openTime
        let message = "OKX 历史K线纯逻辑同步完成：计划请求 \(plan.estimatedRequestCount) 个，解析成功 \(parseResult.acceptedRowCount) 条，拒绝 \(parseResult.rejectedRowCount) 条。"
        return KXSY02CompletionSummary(
            taskID: plan.task.id,
            symbol: plan.task.symbol,
            timeframe: plan.task.timeframe,
            direction: plan.task.direction,
            plannedRequestCount: plan.estimatedRequestCount,
            parsedCandleCount: parseResult.acceptedRowCount,
            rejectedRowCount: parseResult.rejectedRowCount,
            firstOpenTime: first,
            lastOpenTime: last,
            message: message
        )
    }

    public static func makeFailureSummary(task: KXSY02HistorySyncTask?, page: KXSY02HistoryPagePlan? = nil, reason: String) -> KXSY02FailureSummary {
        KXSY02FailureSummary(
            taskID: task?.id,
            symbol: task?.symbol,
            timeframe: task?.timeframe,
            failedPageIndex: page?.pageIndex,
            failedRequest: page?.request,
            reason: reason
        )
    }

    public static func placeholder() -> KXSY02OKXHistoryCandlesRequest {
        makeRequestDescription(symbol: "BTC-USDT", timeframe: .oneMinute, limit: defaultLimit)
    }

    private static func validate(task: KXSY02HistorySyncTask, maxPages: Int) -> KXSY02FailureSummary? {
        if task.symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return makeFailureSummary(task: task, reason: "symbol 不能为空")
        }
        if task.limit < 1 || task.limit > maxLimit {
            return makeFailureSummary(task: task, reason: "limit 必须在 1...\(maxLimit) 之间，符合 OKX history-candles 单页上限")
        }
        if maxPages < 1 {
            return makeFailureSummary(task: task, reason: "maxPages 必须大于 0")
        }
        if let start = task.startTime, let end = task.endTime, start > end {
            return makeFailureSummary(task: task, reason: "startTime 不能晚于 endTime")
        }
        return nil
    }

    private static func makePages(task: KXSY02HistorySyncTask, secondsPerCandle: Int, pageCount: Int) -> [KXSY02HistoryPagePlan] {
        var pages: [KXSY02HistoryPagePlan] = []
        let pageSeconds = TimeInterval(task.limit * max(secondsPerCandle, 1))

        for pageIndex in 0..<pageCount {
            let window = pageWindow(task: task, pageIndex: pageIndex, pageSeconds: pageSeconds)
            let cursors = cursorPair(task: task, windowStart: window.start, windowEnd: window.end)
            let request = makeRequestDescription(
                symbol: task.symbol,
                timeframe: task.timeframe,
                limit: task.limit,
                before: cursors.before,
                after: cursors.after
            )
            pages.append(
                KXSY02HistoryPagePlan(
                    id: "\(task.id)-page-\(pageIndex + 1)",
                    pageIndex: pageIndex,
                    direction: task.direction,
                    request: request,
                    plannedStartTime: window.start,
                    plannedEndTime: window.end,
                    plannedBefore: cursors.before,
                    plannedAfter: cursors.after,
                    expectedLimit: task.limit
                )
            )
        }

        return pages
    }

    private static func pageWindow(task: KXSY02HistorySyncTask, pageIndex: Int, pageSeconds: TimeInterval) -> (start: Date?, end: Date?) {
        switch task.direction {
        case .newer:
            guard let start = task.startTime else {
                return (task.startTime, task.endTime)
            }
            let pageStart = start.addingTimeInterval(Double(pageIndex) * pageSeconds)
            let rawEnd = pageStart.addingTimeInterval(pageSeconds)
            let pageEnd = minDate(rawEnd, task.endTime)
            return (pageStart, pageEnd)
        case .older:
            guard let end = task.endTime else {
                return (task.startTime, task.endTime)
            }
            let pageEnd = end.addingTimeInterval(-Double(pageIndex) * pageSeconds)
            let rawStart = pageEnd.addingTimeInterval(-pageSeconds)
            let pageStart = maxDate(rawStart, task.startTime)
            return (pageStart, pageEnd)
        }
    }

    private static func cursorPair(task: KXSY02HistorySyncTask, windowStart: Date?, windowEnd: Date?) -> (before: String?, after: String?) {
        var before = task.before
        var after = task.after

        if before == nil, let windowEnd {
            before = millisecondsString(from: windowEnd)
        }
        if after == nil, let windowStart {
            after = millisecondsString(from: windowStart)
        }

        return (before, after)
    }

    private static func parseCandleRow(
        _ row: [String],
        rowIndex: Int,
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        secondsPerCandle: Int
    ) -> Result<KLCandlePoint, KXSY02RejectedCandleRow> {
        guard row.count >= 9 else {
            return .failure(rejectedRow(row, rowIndex: rowIndex, reason: "OKX K线数组字段不足，期望至少 9 个字段：[ts,o,h,l,c,vol,volCcy,volCcyQuote,confirm]"))
        }
        guard let timestamp = Int64(row[0]) else {
            return .failure(rejectedRow(row, rowIndex: rowIndex, reason: "ts 不是毫秒时间戳"))
        }
        guard let open = decimal(row[1]) else {
            return .failure(rejectedRow(row, rowIndex: rowIndex, reason: "open 不是有效 Decimal"))
        }
        guard let high = decimal(row[2]) else {
            return .failure(rejectedRow(row, rowIndex: rowIndex, reason: "high 不是有效 Decimal"))
        }
        guard let low = decimal(row[3]) else {
            return .failure(rejectedRow(row, rowIndex: rowIndex, reason: "low 不是有效 Decimal"))
        }
        guard let close = decimal(row[4]) else {
            return .failure(rejectedRow(row, rowIndex: rowIndex, reason: "close 不是有效 Decimal"))
        }
        guard let volume = decimal(row[5]) else {
            return .failure(rejectedRow(row, rowIndex: rowIndex, reason: "volume 不是有效 Decimal"))
        }

        let quoteVolume = decimal(row[7])
        let openTime = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let closeTime = openTime.addingTimeInterval(TimeInterval(max(secondsPerCandle, 1)))
        let isClosed = row[8] == "1"
        let id = "OKX|\(symbol)|\(timeframe.rawValue)|\(timestamp)"

        return .success(
            KLCandlePoint(
                id: id,
                symbol: symbol,
                timeframe: timeframe,
                openTime: openTime,
                closeTime: closeTime,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                quoteVolume: quoteVolume,
                tradeCount: nil,
                isClosed: isClosed,
                source: "OKX/history-candles"
            )
        )
    }

    private static func rejectedRow(_ row: [String], rowIndex: Int, reason: String) -> KXSY02RejectedCandleRow {
        KXSY02RejectedCandleRow(id: "rejected-row-\(rowIndex)", rowIndex: rowIndex, rawValues: row, reason: reason)
    }

    private static func estimateCandleCount(startTime: Date?, endTime: Date?, secondsPerCandle: Int) -> Int? {
        guard let startTime, let endTime else { return nil }
        let seconds = max(secondsPerCandle, 1)
        let duration = max(0, endTime.timeIntervalSince(startTime))
        return max(1, Int(ceil(duration / Double(seconds))))
    }

    private static func secondsPerCandle(timeframe: KXTimeframe) -> Int {
        switch timeframe {
        case .oneSecond:
            return 1
        case .oneMinute:
            return 60
        case .threeMinutes:
            return 180
        case .fiveMinutes:
            return 300
        case .fifteenMinutes:
            return 900
        case .thirtyMinutes:
            return 1_800
        case .oneHour:
            return 3_600
        case .twoHours:
            return 7_200
        case .fourHours:
            return 14_400
        case .sixHours:
            return 21_600
        case .twelveHours:
            return 43_200
        case .oneDay:
            return 86_400
        case .twoDays:
            return 172_800
        case .threeDays:
            return 259_200
        case .oneWeek:
            return 604_800
        case .oneMonth:
            return 2_592_000
        case .threeMonths:
            return 0
        }
    }

    private static func decimal(_ value: String) -> Decimal? {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func millisecondsString(from date: Date) -> String {
        String(Int64((date.timeIntervalSince1970 * 1000.0).rounded()))
    }

    private static func makeTaskID(symbol: KXSymbol, timeframe: KXTimeframe, createdAt: Date) -> String {
        "OKX-history-\(symbol)-\(timeframe.rawValue)-\(millisecondsString(from: createdAt))"
    }

    private static func minDate(_ lhs: Date, _ rhs: Date?) -> Date {
        guard let rhs else { return lhs }
        return lhs < rhs ? lhs : rhs
    }

    private static func maxDate(_ lhs: Date, _ rhs: Date?) -> Date {
        guard let rhs else { return lhs }
        return lhs > rhs ? lhs : rhs
    }
}
