//
//  KX-FN-04_数据标准化.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：把外部 K线数据转换为统一 OHLCV 数据模型
//  禁止事项：禁止真实网络请求、禁止数据库写入
//

import Foundation


// MARK: - K线数据标准化

public enum KXFN04Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-04",
        fileName: "KX-FN-04_数据标准化.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-04_数据标准化.swift",
        duty: "把外部 K线数据转换为统一 OHLCV 数据模型"
    )

    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("K线数据标准化骨架校验通过")
        return KXHealthCheckItem(name: "K线数据标准化", passed: true, message: "已实现数组/字典 OHLCV 到 KLCandlePoint 的标准化转换")
    }

    public static func placeholder() {
        // 本文件已实现 K线数据标准化能力；保留占位入口以兼容骨架协议验收。
    }
}

// MARK: - 标准化公开模型

public extension KXFN04Skeleton {
    /// 外部数组 K线字段布局。
    enum ArrayLayout: Sendable, Equatable {
        /// OKX 常见格式：[ts, open, high, low, close, volume, volumeCurrency, quoteVolume, confirm]
        case okx
        /// 通用 OHLCV 格式：[timestamp, open, high, low, close, volume]
        case genericOHLCV
        /// 自定义索引。缺失字段传 nil。
        case custom(
            timestamp: Int,
            open: Int,
            high: Int,
            low: Int,
            close: Int,
            volume: Int,
            quoteVolume: Int?,
            tradeCount: Int?,
            isClosed: Int?
        )
    }

    /// raw payload 保留策略。
    enum RawPayloadPolicy: Sendable, Equatable {
        /// 不保留 raw，只在 source 写入来源标识。
        case none
        /// 将可读 raw 摘要拼接到 KLCandlePoint.source，超过 maxCharacters 会截断。
        case sourceSummary(maxCharacters: Int = 512)
    }

    /// 单行标准化失败描述。用于批量转换时定位具体失败行，不抛异常、不强解包。
    struct NormalizationFailure: Sendable, Equatable {
        public let index: Int
        public let reason: String
        public let rawSummary: String?

        public init(index: Int, reason: String, rawSummary: String? = nil) {
            self.index = index
            self.reason = reason
            self.rawSummary = rawSummary
        }
    }

    /// 批量标准化结果：成功 candle 与失败明细分离，调用方可决定是否接受部分成功。
    struct BatchResult: Sendable, Equatable {
        public let candles: [KLCandlePoint]
        public let failures: [NormalizationFailure]

        public init(candles: [KLCandlePoint], failures: [NormalizationFailure]) {
            self.candles = candles
            self.failures = failures
        }

        public var isFullySuccessful: Bool { failures.isEmpty }
    }

    /// 标准化错误：全部带中文失败描述，避免崩溃式强解包。
    enum NormalizationError: Error, Sendable, Equatable, CustomStringConvertible {
        case missingField(String)
        case invalidField(name: String, value: String)
        case invalidTimestamp(String)
        case invalidOHLC(open: Decimal, high: Decimal, low: Decimal, close: Decimal)
        case arrayIndexOutOfRange(field: String, index: Int, count: Int)

        public var description: String {
            switch self {
            case .missingField(let name):
                return "缺少必要字段：\(name)"
            case .invalidField(let name, let value):
                return "字段 \(name) 的值无效：\(value)"
            case .invalidTimestamp(let value):
                return "时间戳无效或无法识别秒/毫秒：\(value)"
            case .invalidOHLC(let open, let high, let low, let close):
                return "OHLC 价格关系无效：open=\(open), high=\(high), low=\(low), close=\(close)"
            case .arrayIndexOutOfRange(let field, let index, let count):
                return "数组字段 \(field) 索引越界：index=\(index), count=\(count)"
            }
        }
    }
}

// MARK: - 标准化入口

public extension KXFN04Skeleton {
    /// 标准化数组形式 K线数据为 KL-02 中定义的 KLCandlePoint。
    static func normalizeArray(
        _ row: [Any],
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        source: String? = nil,
        layout: ArrayLayout = .okx,
        rawPayloadPolicy: RawPayloadPolicy = .sourceSummary()
    ) -> Result<KLCandlePoint, NormalizationError> {
        let indexes = indexes(for: layout)

        return buildCandle(
            symbol: symbol,
            timeframe: timeframe,
            timestampValue: value(in: row, field: "timestamp", index: indexes.timestamp),
            openValue: value(in: row, field: "open", index: indexes.open),
            highValue: value(in: row, field: "high", index: indexes.high),
            lowValue: value(in: row, field: "low", index: indexes.low),
            closeValue: value(in: row, field: "close", index: indexes.close),
            volumeValue: value(in: row, field: "volume", index: indexes.volume),
            quoteVolumeValue: optionalValue(in: row, index: indexes.quoteVolume),
            tradeCountValue: optionalValue(in: row, index: indexes.tradeCount),
            isClosedValue: optionalValue(in: row, index: indexes.isClosed),
            source: mergedSource(source: source, raw: row, policy: rawPayloadPolicy)
        )
    }

    /// 标准化字典形式 K线数据为 KL-02 中定义的 KLCandlePoint。
    /// 支持常见别名：timestamp/ts/time/openTime, open/o, high/h, low/l, close/c, volume/vol 等。
    static func normalizeDictionary(
        _ dictionary: [String: Any],
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        source: String? = nil,
        rawPayloadPolicy: RawPayloadPolicy = .sourceSummary()
    ) -> Result<KLCandlePoint, NormalizationError> {
        buildCandle(
            symbol: symbol,
            timeframe: timeframe,
            timestampValue: requiredValue(in: dictionary, field: "timestamp", keys: ["timestamp", "ts", "time", "openTime", "open_time", "t"]),
            openValue: requiredValue(in: dictionary, field: "open", keys: ["open", "o"]),
            highValue: requiredValue(in: dictionary, field: "high", keys: ["high", "h"]),
            lowValue: requiredValue(in: dictionary, field: "low", keys: ["low", "l"]),
            closeValue: requiredValue(in: dictionary, field: "close", keys: ["close", "c"]),
            volumeValue: requiredValue(in: dictionary, field: "volume", keys: ["volume", "vol", "baseVolume", "base_volume", "v"]),
            quoteVolumeValue: optionalValue(in: dictionary, keys: ["quoteVolume", "quote_volume", "volCcyQuote", "turnover", "amount"]),
            tradeCountValue: optionalValue(in: dictionary, keys: ["tradeCount", "trade_count", "count", "trades"]),
            isClosedValue: optionalValue(in: dictionary, keys: ["isClosed", "is_closed", "closed", "confirm", "final"]),
            source: mergedSource(source: source, raw: dictionary, policy: rawPayloadPolicy)
        )
    }

    /// 批量标准化数组行。不会因单行失败中断，失败原因写入 failures。
    static func normalizeArrays(
        _ rows: [[Any]],
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        source: String? = nil,
        layout: ArrayLayout = .okx,
        rawPayloadPolicy: RawPayloadPolicy = .sourceSummary()
    ) -> BatchResult {
        var candles: [KLCandlePoint] = []
        var failures: [NormalizationFailure] = []

        for (index, row) in rows.enumerated() {
            switch normalizeArray(row, symbol: symbol, timeframe: timeframe, source: source, layout: layout, rawPayloadPolicy: rawPayloadPolicy) {
            case .success(let candle):
                candles.append(candle)
            case .failure(let error):
                failures.append(NormalizationFailure(index: index, reason: error.description, rawSummary: rawSummary(row, maxCharacters: 256)))
            }
        }

        return BatchResult(candles: candles, failures: failures)
    }

    /// 批量标准化字典行。不会因单行失败中断，失败原因写入 failures。
    static func normalizeDictionaries(
        _ rows: [[String: Any]],
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        source: String? = nil,
        rawPayloadPolicy: RawPayloadPolicy = .sourceSummary()
    ) -> BatchResult {
        var candles: [KLCandlePoint] = []
        var failures: [NormalizationFailure] = []

        for (index, row) in rows.enumerated() {
            switch normalizeDictionary(row, symbol: symbol, timeframe: timeframe, source: source, rawPayloadPolicy: rawPayloadPolicy) {
            case .success(let candle):
                candles.append(candle)
            case .failure(let error):
                failures.append(NormalizationFailure(index: index, reason: error.description, rawSummary: rawSummary(row, maxCharacters: 256)))
            }
        }

        return BatchResult(candles: candles, failures: failures)
    }
}

// MARK: - 内部实现

private extension KXFN04Skeleton {
    typealias ArrayIndexes = (
        timestamp: Int,
        open: Int,
        high: Int,
        low: Int,
        close: Int,
        volume: Int,
        quoteVolume: Int?,
        tradeCount: Int?,
        isClosed: Int?
    )

    static func indexes(for layout: ArrayLayout) -> ArrayIndexes {
        switch layout {
        case .okx:
            return (timestamp: 0, open: 1, high: 2, low: 3, close: 4, volume: 5, quoteVolume: 7, tradeCount: nil, isClosed: 8)
        case .genericOHLCV:
            return (timestamp: 0, open: 1, high: 2, low: 3, close: 4, volume: 5, quoteVolume: nil, tradeCount: nil, isClosed: nil)
        case .custom(let timestamp, let open, let high, let low, let close, let volume, let quoteVolume, let tradeCount, let isClosed):
            return (timestamp: timestamp, open: open, high: high, low: low, close: close, volume: volume, quoteVolume: quoteVolume, tradeCount: tradeCount, isClosed: isClosed)
        }
    }

    static func buildCandle(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        timestampValue: Result<Any, NormalizationError>,
        openValue: Result<Any, NormalizationError>,
        highValue: Result<Any, NormalizationError>,
        lowValue: Result<Any, NormalizationError>,
        closeValue: Result<Any, NormalizationError>,
        volumeValue: Result<Any, NormalizationError>,
        quoteVolumeValue: Any?,
        tradeCountValue: Any?,
        isClosedValue: Any?,
        source: String?
    ) -> Result<KLCandlePoint, NormalizationError> {
        switch timestampValue.flatMap(parseTimestamp) {
        case .failure(let error): return .failure(error)
        case .success(let openTime):
            return parseRequiredDecimal(openValue, name: "open").flatMap { open in
                parseRequiredDecimal(highValue, name: "high").flatMap { high in
                    parseRequiredDecimal(lowValue, name: "low").flatMap { low in
                        parseRequiredDecimal(closeValue, name: "close").flatMap { close in
                            parseRequiredDecimal(volumeValue, name: "volume").flatMap { volume in
                                guard high >= open, high >= close, high >= low, low <= open, low <= close, low <= high else {
                                    return .failure(.invalidOHLC(open: open, high: high, low: low, close: close))
                                }

                                let quoteVolume = quoteVolumeValue.flatMap { parseDecimal($0).successValue }
                                let tradeCount = tradeCountValue.flatMap(parseInt)
                                let isClosed = isClosedValue.flatMap(parseBool) ?? true
                                let closeTime = isClosed ? Date(timeInterval: TimeInterval(seconds(for: timeframe)), since: openTime) : nil

                                let candle = KLCandlePoint(
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
                                    tradeCount: tradeCount,
                                    isClosed: isClosed,
                                    source: source
                                )
                                return .success(candle)
                            }
                        }
                    }
                }
            }
        }
    }

    static func value(in row: [Any], field: String, index: Int) -> Result<Any, NormalizationError> {
        guard index >= 0, index < row.count else {
            return .failure(.arrayIndexOutOfRange(field: field, index: index, count: row.count))
        }
        return .success(row[index])
    }

    static func optionalValue(in row: [Any], index: Int?) -> Any? {
        guard let index, index >= 0, index < row.count else { return nil }
        return row[index]
    }

    static func requiredValue(in dictionary: [String: Any], field: String, keys: [String]) -> Result<Any, NormalizationError> {
        for key in keys {
            if let value = dictionary[key], !isNull(value) {
                return .success(value)
            }
        }
        return .failure(.missingField(field))
    }

    static func optionalValue(in dictionary: [String: Any], keys: [String]) -> Any? {
        for key in keys {
            if let value = dictionary[key], !isNull(value) {
                return value
            }
        }
        return nil
    }

    static func parseRequiredDecimal(_ value: Result<Any, NormalizationError>, name: String) -> Result<Decimal, NormalizationError> {
        switch value {
        case .failure(let error):
            return .failure(error)
        case .success(let raw):
            return parseDecimal(raw).mapError { _ in .invalidField(name: name, value: String(describing: raw)) }
        }
    }

    static func parseDecimal(_ value: Any) -> Result<Decimal, NormalizationError> {
        if let decimal = value as? Decimal {
            return .success(decimal)
        }

        if let number = value as? NSDecimalNumber, number != .notANumber {
            return .success(number.decimalValue)
        }

        if let number = value as? NSNumber {
            return .success(Decimal(string: number.stringValue) ?? Decimal(number.doubleValue))
        }

        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let decimal = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(string: trimmed) else {
                return .failure(.invalidField(name: "decimal", value: string))
            }
            return .success(decimal)
        }

        return .failure(.invalidField(name: "decimal", value: String(describing: value)))
    }

    static func parseTimestamp(_ value: Any) -> Result<Date, NormalizationError> {
        if let date = value as? Date {
            return .success(date)
        }

        let decimalResult = parseDecimal(value)
        guard case .success(let decimal) = decimalResult else {
            return .failure(.invalidTimestamp(String(describing: value)))
        }

        let number = NSDecimalNumber(decimal: decimal)
        guard number != .notANumber else {
            return .failure(.invalidTimestamp(String(describing: value)))
        }

        let rawSecondsOrMilliseconds = number.doubleValue
        guard rawSecondsOrMilliseconds.isFinite, rawSecondsOrMilliseconds > 0 else {
            return .failure(.invalidTimestamp(String(describing: value)))
        }

        let seconds: TimeInterval
        if rawSecondsOrMilliseconds >= 1_000_000_000_000 {
            seconds = rawSecondsOrMilliseconds / 1_000
        } else {
            seconds = rawSecondsOrMilliseconds
        }

        guard seconds >= 946_684_800, seconds <= 4_102_444_800 else {
            return .failure(.invalidTimestamp(String(describing: value)))
        }

        return .success(Date(timeIntervalSince1970: seconds))
    }

    static func parseInt(_ value: Any) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if case .success(let decimal) = parseDecimal(value) {
            return NSDecimalNumber(decimal: decimal).intValue
        }
        return nil
    }

    static func parseBool(_ value: Any) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.intValue != 0 }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "y", "closed", "final": return true
            case "0", "false", "no", "n", "open", "unclosed": return false
            default: return nil
            }
        }
        return nil
    }

    static func seconds(for timeframe: KXTimeframe) -> Int {
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

    static func mergedSource(source: String?, raw: Any, policy: RawPayloadPolicy) -> String? {
        switch policy {
        case .none:
            return source
        case .sourceSummary(let maxCharacters):
            let rawText = rawSummary(raw, maxCharacters: max(0, maxCharacters))
            switch (source?.isEmpty == false ? source : nil, rawText) {
            case (.some(let source), .some(let rawText)):
                return "\(source) | raw=\(rawText)"
            case (.some(let source), .none):
                return source
            case (.none, .some(let rawText)):
                return "raw=\(rawText)"
            case (.none, .none):
                return nil
            }
        }
    }

    static func rawSummary(_ raw: Any, maxCharacters: Int) -> String? {
        guard maxCharacters > 0 else { return nil }

        let text: String
        if JSONSerialization.isValidJSONObject(raw), let data = try? JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys]), let json = String(data: data, encoding: .utf8) {
            text = json
        } else {
            text = String(describing: raw)
        }

        if text.count <= maxCharacters {
            return text
        }

        return String(text.prefix(maxCharacters)) + "…"
    }

    static func isNull(_ value: Any) -> Bool {
        value is NSNull
    }
}

private extension Result {
    var successValue: Success? {
        guard case .success(let value) = self else { return nil }
        return value
    }
}
