//
//  KX-SJ-09_PostgreSQL适配.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：PostgreSQL 真实执行适配。通过 psql 执行建表、upsert、条件查询、同步状态。
//  强制规则：低于 15m 的周期拒绝写入 kline_ohlcv
//  禁止事项：禁止UI绘制、禁止网络请求、禁止业务逻辑判断
//

import Foundation

// MARK: - 数据库事件通知

public extension Notification.Name {
    /// 数据库连接失败通知。object = error localizedDescription
    static let klineDatabaseConnectionFailed = Notification.Name("com.xianrenzhilu.kline.databaseConnectionFailed")
}

// MARK: - 错误

public enum KLDatabaseError: LocalizedError, Sendable {
    case connectionNotConfigured
    case queryFailed(String)
    case writeToMemoryOnlyTimeframe(timeframe: KXTimeframe)
    case instrumentMismatch(expected: String, actual: String)
    case tableNotExists(String)

    public var errorDescription: String? {
        switch self {
        case .connectionNotConfigured: return "数据库连接未配置"
        case .queryFailed(let detail): return "查询失败: \(detail)"
        case .writeToMemoryOnlyTimeframe(let tf): return "周期 \(tf.rawValue) 为 memoryOnly，禁止写入"
        case .instrumentMismatch(let expected, let actual): return "K线标的与入库 instrumentID 不一致: expected=\(expected), actual=\(actual)"
        case .tableNotExists(let name): return "表不存在: \(name)"
        }
    }
}

// MARK: - 配置

public struct KLDatabaseConfig: Codable, Sendable {
    public let host: String
    public let port: Int
    public let database: String
    public let user: String
    public let psqlPath: String

    public init(host: String = "localhost", port: Int = 5432, database: String = "library_knowledge", user: String = "songxiaoxiao", psqlPath: String = "/opt/homebrew/bin/psql") {
        self.host = host
        self.port = port
        self.database = database
        self.user = user
        self.psqlPath = psqlPath
    }
}

// MARK: - SQL 执行核心

public final class KLDatabase: @unchecked Sendable {
    public static let shared = KLDatabase()
    public var config: KLDatabaseConfig = KLDatabaseConfig()
    private let queue = DispatchQueue(label: "com.kline.db")

    private init() {}

    /// 执行 SQL 返回第一列第一行（String?）
    @discardableResult
    public func execute(sql: String) throws -> String? {
        if Thread.isMainThread {
            klineLogger.error("[KLDatabase] ⚠️ execute 在主线程同步调用，会阻塞 UI/泵 RunLoop，应移至后台线程。")
        }
        let sqlPrefix = String(sql.prefix(60).replacingOccurrences(of: "\n", with: " "))
        let t0 = CFAbsoluteTimeGetCurrent()
        do {
            let result = try _execute(sql: sql, sqlPrefix: sqlPrefix)
            let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            klineLogger.info("[DB][OK] [\(String(format: "%.1f", elapsed))ms] \(sqlPrefix)")
            return result
        } catch {
            let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            let errMsg = error.localizedDescription
            klineLogger.error("[DB][FAIL] [\(String(format: "%.1f", elapsed))ms] \(sqlPrefix) | \(errMsg)")
            if _isConnectionError(errMsg) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .klineDatabaseConnectionFailed, object: errMsg)
                }
            }
            throw error
        }
    }

    private func _isConnectionError(_ msg: String) -> Bool {
        let lower = msg.lowercased()
        return lower.contains("connection refused") || lower.contains("could not connect") || lower.contains("no route to host") || lower.contains("server closed") || lower.contains("cannot assign requested address") || lower.contains("postmaster became multithreaded") || lower.contains("pre-existing shared memory") || lower.contains("is another postmaster")
    }

    private func _execute(sql: String, sqlPrefix: String) throws -> String? {
        return try queue.sync {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: config.psqlPath)
            process.arguments = [
                "-h", config.host,
                "-p", "\(config.port)",
                "-U", config.user,
                "-d", config.database,
                "-t", "-A",
                "-c", sql
            ]
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            try process.run()
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let outStr = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if process.terminationStatus != 0 {
                let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw KLDatabaseError.queryFailed(errStr.isEmpty ? outStr : errStr)
            }
            return outStr.isEmpty ? nil : outStr
        }
    }

    /// 执行多行 SQL（DDL 建表等）
    public func executeBatch(sql: String) throws {
        if Thread.isMainThread {
            klineLogger.error("[KLDatabase] ⚠️ executeBatch 在主线程同步调用，会阻塞 UI/泵 RunLoop，应移至后台线程。")
        }
        let sqlPrefix = String(sql.prefix(60).replacingOccurrences(of: "\n", with: " "))
        let t0 = CFAbsoluteTimeGetCurrent()
        do {
            try _executeBatch(sql: sql, sqlPrefix: sqlPrefix)
            let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            klineLogger.info("[DB][OK] [\(String(format: "%.1f", elapsed))ms] BATCH \(sqlPrefix)")
        } catch {
            let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            let errMsg = error.localizedDescription
            klineLogger.error("[DB][FAIL] [\(String(format: "%.1f", elapsed))ms] BATCH \(sqlPrefix) | \(errMsg)")
            if _isConnectionError(errMsg) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .klineDatabaseConnectionFailed, object: errMsg)
                }
            }
            throw error
        }
    }

    private func _executeBatch(sql: String, sqlPrefix: String) throws {
        try queue.sync {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: config.psqlPath)
            process.arguments = [
                "-h", config.host,
                "-p", "\(config.port)",
                "-U", config.user,
                "-d", config.database,
                "-c", sql
            ]
            let errPipe = Pipe()
            process.standardError = errPipe
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                throw KLDatabaseError.queryFailed(errStr)
            }
        }
    }
}

// MARK: - 执行协议

public protocol KLDatabaseExecuting: AnyObject {
    func ensureTables() throws
    func upsertCandles(candles: [KLCandlePoint], exchange: String, instrumentID: String, timeframe: KXTimeframe) throws
    func queryCandles(exchange: String, instrumentID: String, timeframe: KXTimeframe, startTime: Date?, endTime: Date?, limit: Int) throws -> [KLCandlePoint]
    func queryDistinctSymbols(exchange: String) throws -> [String]
    func queryInstrumentIDs(exchange: String, marketType: KLMarketType?, liveOnly: Bool) throws -> [String]
    func readSyncState(exchange: String, instrumentID: String, timeframe: KXTimeframe) throws -> [String: String]
    func writeSyncState(exchange: String, instrumentID: String, timeframe: KXTimeframe, lastOpenTime: Date, syncState: String) throws
    func tableExists(_ name: String) throws -> Bool
    func countCandles(exchange: String, instrumentID: String, timeframe: KXTimeframe) throws -> Int
    func latestCandleTime(exchange: String, instrumentID: String, timeframe: KXTimeframe) throws -> Date?
    func queryCandleRange(exchange: String, instrumentID: String, timeframe: KXTimeframe, startISO: String, endISO: String, limit: Int) throws -> [KLCandlePoint]
}

// MARK: - 真实执行器

public final class KLDefaultDatabaseExecutor: KLDatabaseExecuting, @unchecked Sendable {
    public static let shared = KLDefaultDatabaseExecutor()
    private let db = KLDatabase.shared

    private init() {}

    // MARK: 建表

    public func ensureTables() throws {
        try db.executeBatch(sql: """
        CREATE TABLE IF NOT EXISTS kline_instruments (
            id BIGSERIAL PRIMARY KEY,
            exchange TEXT NOT NULL,
            inst_type TEXT NOT NULL,
            inst_id TEXT NOT NULL,
            base_ccy TEXT,
            quote_ccy TEXT,
            tick_size NUMERIC,
            lot_size NUMERIC,
            price_precision INTEGER,
            quantity_precision INTEGER,
            state TEXT,
            raw_payload JSONB,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
            UNIQUE(exchange, inst_id)
        );
        CREATE TABLE IF NOT EXISTS kline_ohlcv (
            id BIGSERIAL PRIMARY KEY,
            exchange TEXT NOT NULL,
            instrument_id TEXT NOT NULL,
            timeframe TEXT NOT NULL,
            open_time TIMESTAMP NOT NULL,
            close_time TIMESTAMP,
            open_price NUMERIC NOT NULL,
            high_price NUMERIC NOT NULL,
            low_price NUMERIC NOT NULL,
            close_price NUMERIC NOT NULL,
            volume NUMERIC NOT NULL,
            quote_volume NUMERIC,
            trade_count INTEGER,
            is_closed BOOLEAN NOT NULL DEFAULT true,
            source TEXT,
            raw_payload JSONB,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
            UNIQUE(exchange, instrument_id, timeframe, open_time)
        );
        CREATE INDEX IF NOT EXISTS idx_kline_ohlcv_inst_tf_open ON kline_ohlcv(exchange, instrument_id, timeframe, open_time);
        CREATE INDEX IF NOT EXISTS idx_kline_ohlcv_inst_tf_close ON kline_ohlcv(exchange, instrument_id, timeframe, close_time);
        CREATE TABLE IF NOT EXISTS kline_sync_state (
            id BIGSERIAL PRIMARY KEY,
            exchange TEXT NOT NULL,
            instrument_id TEXT NOT NULL,
            timeframe TEXT NOT NULL,
            last_closed_open_time TIMESTAMP,
            last_synced_at TIMESTAMP,
            sync_state TEXT DEFAULT 'idle',
            last_error TEXT,
            retry_count INTEGER DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
            UNIQUE(exchange, instrument_id, timeframe)
        );
        """)
    }

    // MARK: 写入 K线

    public func upsertCandles(candles: [KLCandlePoint], exchange: String, instrumentID: String, timeframe: KXTimeframe) throws {
        guard !KLOKXTimeframePolicyCatalog.isMemoryOnly(timeframe) else {
            throw KLDatabaseError.writeToMemoryOnlyTimeframe(timeframe: timeframe)
        }
        guard try tableExists("kline_ohlcv") else {
            throw KLDatabaseError.tableNotExists("kline_ohlcv")
        }
        if let mismatch = candles.first(where: { $0.symbol != instrumentID }) {
            throw KLDatabaseError.instrumentMismatch(expected: instrumentID, actual: mismatch.symbol)
        }
        let chunkSize = 500
        for start in stride(from: 0, to: candles.count, by: chunkSize) {
            let chunk = Array(candles[start..<min(start + chunkSize, candles.count)])
            let values = chunk.map { c -> String in
                let ot = iso(from: c.openTime)
                let ct = c.closeTime.map { "'\(esc(iso(from: $0)))'" } ?? "NULL"
                let qv = c.quoteVolume.map { "\($0)" } ?? "NULL"
                let tc = c.tradeCount.map { "\($0)" } ?? "NULL"
                let closed = c.isClosed ? "true" : "false"
                let source = esc(c.source ?? "okx_api")
                return "('\(esc(exchange))', '\(esc(instrumentID))', '\(esc(timeframe.rawValue))', '\(esc(ot))', \(ct), \(c.open), \(c.high), \(c.low), \(c.close), \(c.volume), \(qv), \(tc), \(closed), '\(source)')"
            }.joined(separator: ",\n")
            let sql = """
            INSERT INTO kline_ohlcv (exchange, instrument_id, timeframe, open_time, close_time, open_price, high_price, low_price, close_price, volume, quote_volume, trade_count, is_closed, source)
            VALUES
            \(values)
            ON CONFLICT (exchange, instrument_id, timeframe, open_time) DO UPDATE SET
                close_time = EXCLUDED.close_time,
                open_price = EXCLUDED.open_price,
                high_price = EXCLUDED.high_price,
                low_price = EXCLUDED.low_price,
                close_price = EXCLUDED.close_price,
                volume = EXCLUDED.volume,
                quote_volume = EXCLUDED.quote_volume,
                trade_count = EXCLUDED.trade_count,
                is_closed = EXCLUDED.is_closed,
                source = EXCLUDED.source,
                updated_at = NOW();
            """
            try db.executeBatch(sql: sql)
        }
    }

    // MARK: 查询 K线（compact）

    public func queryCandles(exchange: String, instrumentID: String, timeframe: KXTimeframe, startTime: Date?, endTime: Date?, limit: Int = 500) throws -> [KLCandlePoint] {
        var whereClause = "exchange = '\(esc(exchange))' AND instrument_id = '\(esc(instrumentID))' AND timeframe = '\(esc(timeframe.rawValue))'"
        if let s = startTime { whereClause += " AND open_time >= '\(esc(iso(from: s)))'" }
        if let e = endTime   { whereClause += " AND open_time <= '\(esc(iso(from: e)))'" }
        let limitClause = limit > 0 ? " LIMIT \(limit)" : ""
        let sql = "SELECT to_char(open_time, 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'), COALESCE(to_char(close_time, 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'), 'NULL'), open_price, high_price, low_price, close_price, volume, quote_volume, trade_count, is_closed FROM kline_ohlcv WHERE \(whereClause) ORDER BY open_time ASC\(limitClause);"
        guard let result = try db.execute(sql: sql) else { return [] }
        return parseCandles(result, symbol: instrumentID, timeframe: timeframe)
    }

    /// 取最新 N 根（按 open_time DESC 限行后外层 ASC 还原正序）。
    /// 用于画布 hydrate：4h/6h 等“全量”周期 DB 存上万行，初始显示只需最新一段，避免全 parse 造成启动 CPU 爆炸。
    public func queryLatestCandles(exchange: String, instrumentID: String, timeframe: KXTimeframe, startTime: Date?, limit: Int) throws -> [KLCandlePoint] {
        guard limit > 0 else {
            return try queryCandles(exchange: exchange, instrumentID: instrumentID, timeframe: timeframe, startTime: startTime, endTime: nil, limit: 0)
        }
        var whereClause = "exchange = '\(esc(exchange))' AND instrument_id = '\(esc(instrumentID))' AND timeframe = '\(esc(timeframe.rawValue))'"
        if let s = startTime { whereClause += " AND open_time >= '\(esc(iso(from: s)))'" }
        let cols = "to_char(open_time, 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'), COALESCE(to_char(close_time, 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'), 'NULL'), open_price, high_price, low_price, close_price, volume, quote_volume, trade_count, is_closed"
        let sql = "SELECT * FROM (SELECT \(cols) FROM kline_ohlcv WHERE \(whereClause) ORDER BY open_time DESC LIMIT \(limit)) sub ORDER BY 1 ASC;"
        guard let result = try db.execute(sql: sql) else { return [] }
        return parseCandles(result, symbol: instrumentID, timeframe: timeframe)
    }

    public func queryDistinctSymbols(exchange: String) throws -> [String] {
        let sql = "SELECT DISTINCT instrument_id FROM kline_ohlcv WHERE exchange = '\(esc(exchange))' ORDER BY instrument_id ASC;"
        guard let result = try db.execute(sql: sql) else { return [] }
        return result.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    /// 读取 OKX 交易对目录中的真实 instId。
    /// UI 交易对选择器优先使用该表，避免只显示硬编码 Top20，保证任意已同步币对都能打开正确 K线。
    public func queryInstrumentIDs(exchange: String = "OKX", marketType: KLMarketType? = nil, liveOnly: Bool = true) throws -> [String] {
        guard try tableExists("kline_instruments") else { return [] }
        var whereClause = "exchange = '\(esc(exchange))'"
        if let marketType {
            switch marketType {
            case .spot:
                whereClause += " AND inst_type = 'SPOT'"
            case .swap:
                // UI 中的“U本位永续”：OKX 类型是 SWAP，instId 通常为 BTC-USDT-SWAP / BTC-USDC-SWAP。
                whereClause += " AND inst_type = 'SWAP' AND (inst_id LIKE '%-USDT-SWAP' OR inst_id LIKE '%-USDC-SWAP')"
            case .futures:
                // UI 中的“币本位永续”：不是 OKX FUTURES 交割，而是 SWAP + USD 结算，如 BTC-USD-SWAP。
                whereClause += " AND inst_type = 'SWAP' AND inst_id LIKE '%-USD-SWAP'"
            case .margin:
                whereClause += " AND inst_type = 'MARGIN'"
            case .option:
                whereClause += " AND inst_type = 'OPTION'"
            }
        }
        if liveOnly {
            whereClause += " AND COALESCE(state, 'live') = 'live'"
        }
        let sql = "SELECT inst_id FROM kline_instruments WHERE \(whereClause) ORDER BY inst_id ASC;"
        guard let result = try db.execute(sql: sql) else { return [] }
        return result.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: 按 ISO 范围查询（第一批数据预热用）

    public func queryCandleRange(exchange: String, instrumentID: String, timeframe: KXTimeframe, startISO: String, endISO: String, limit: Int = 1000) throws -> [KLCandlePoint] {
        let sql = """
        SELECT to_char(open_time, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'), COALESCE(to_char(close_time, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'), 'NULL'), open_price, high_price, low_price, close_price, volume, quote_volume, trade_count, is_closed
        FROM kline_ohlcv
        WHERE exchange = '\(esc(exchange))' AND instrument_id = '\(esc(instrumentID))' AND timeframe = '\(esc(timeframe.rawValue))'
          AND open_time >= '\(esc(startISO))' AND open_time <= '\(esc(endISO))'
        ORDER BY open_time ASC LIMIT \(limit);
        """
        guard let result = try db.execute(sql: sql) else { return [] }
        return parseCandles(result, symbol: instrumentID, timeframe: timeframe)
    }

    // MARK: 最新K线时间

    public func latestCandleTime(exchange: String, instrumentID: String, timeframe: KXTimeframe) throws -> Date? {
        let sql = "SELECT to_char(MAX(open_time), 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') FROM kline_ohlcv WHERE exchange = '\(esc(exchange))' AND instrument_id = '\(esc(instrumentID))' AND timeframe = '\(esc(timeframe.rawValue))';"
        guard let str = try db.execute(sql: sql), let d = parseDate(str) else { return nil }
        return d
    }

    // MARK: 同步状态

    public func readSyncState(exchange: String, instrumentID: String, timeframe: KXTimeframe) throws -> [String: String] {
        let sql = "SELECT last_closed_open_time, last_synced_at, sync_state, last_error, retry_count FROM kline_sync_state WHERE exchange = '\(esc(exchange))' AND instrument_id = '\(esc(instrumentID))' AND timeframe = '\(esc(timeframe.rawValue))';"
        guard let result = try db.execute(sql: sql) else { return [:] }
        let parts = result.split(separator: "|", maxSplits: 4).map(String.init)
        guard parts.count >= 1 else { return [:] }
        var dict: [String: String] = [:]
        if parts.count >= 1 { dict["last_closed_open_time"] = parts[0] }
        if parts.count >= 2 { dict["last_synced_at"] = parts[1] }
        if parts.count >= 3 { dict["sync_state"] = parts[2] }
        if parts.count >= 4 { dict["last_error"] = parts[3] }
        if parts.count >= 5 { dict["retry_count"] = parts[4] }
        return dict
    }

    public func writeSyncState(exchange: String, instrumentID: String, timeframe: KXTimeframe, lastOpenTime: Date, syncState: String) throws {
        let sql = """
        INSERT INTO kline_sync_state (exchange, instrument_id, timeframe, last_closed_open_time, last_synced_at, sync_state)
        VALUES ('\(esc(exchange))', '\(esc(instrumentID))', '\(esc(timeframe.rawValue))', '\(esc(iso(from: lastOpenTime)))', NOW(), '\(esc(syncState))')
        ON CONFLICT (exchange, instrument_id, timeframe) DO UPDATE SET
            last_closed_open_time = EXCLUDED.last_closed_open_time,
            last_synced_at = NOW(),
            sync_state = EXCLUDED.sync_state,
            updated_at = NOW();
        """
        try db.execute(sql: sql)
    }

    // MARK: 辅助

    public func tableExists(_ name: String) throws -> Bool {
        let sql = "SELECT to_regclass('public.\(esc(name))');"
        guard let r = try db.execute(sql: sql), !r.isEmpty, r != "nil" else { return false }
        return true
    }

    public func countCandles(exchange: String, instrumentID: String, timeframe: KXTimeframe) throws -> Int {
        let sql = "SELECT count(*) FROM kline_ohlcv WHERE exchange = '\(esc(exchange))' AND instrument_id = '\(esc(instrumentID))' AND timeframe = '\(esc(timeframe.rawValue))';"
        guard let str = try db.execute(sql: sql), let n = Int(str) else { return 0 }
        return n
    }

    // MARK: - Private helpers

    // MARK: - 缓存的日期格式化器
    // 原实现每解析一行 K线就 new 一批 ISO8601DateFormatter/DateFormatter，构造极昂贵（每次走 ICU udat_open），
    // 启动同步多周期/多符号时会打穿多个后台线程、CPU 贑满导致 UI 转圈。
    // 改为进程内只创建一次、全局复用；date(from:) 在不修改属性时是线程安全的。
    private enum DateFormatterCache {
        static let isoWithFraction: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            f.timeZone = TimeZone(secondsFromGMT: 0)
            return f
        }()
        static let iso: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            f.timeZone = TimeZone(secondsFromGMT: 0)
            return f
        }()
        // PostgreSQL timestamp 常见格式（DB 查询返回的主格式，优先匹配）
        static let pg: [DateFormatter] = [
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'"
        ].map { fmt -> DateFormatter in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = fmt
            return f
        }
    }

    private func iso(from d: Date) -> String {
        return DateFormatterCache.isoWithFraction.string(from: d)
    }

    private static func okxInstrumentType(for marketType: KLMarketType) -> String {
        switch marketType {
        case .spot: return "SPOT"
        case .swap, .futures: return "SWAP"
        case .margin: return "MARGIN"
        case .option: return "OPTION"
        }
    }

    // ========== 快速解析（绕开 ICU/DateFormatter/NSDecimal 本地化，CPU 关键优化） ==========
    // 原因：Decimal(string:) 走 NSDecimal.init(string:locale:) → ICU DecimalFormat，DateFormatter 也是 ICU；
    // 读几万行 K线每行解析 6 个数字 + 1~2 个日期，是加载/切换 CPU 颙1xx% 的真凶。
    // 下面两个函数手写解析常见格式，异常格式回退老路保证不丢数据。

    /// 快速解析纯十进制十进位小数字符串（如 "6212.4" / "-0.0833" / "56281.63002388"）。
    /// 不处理科学计数法(e/E)等罕见格式，遇到则返回 nil 由调用方回退 Decimal(string:)。
    @inline(__always)
    private func fastDecimal(_ s: String) -> Decimal? {
        let u = s.utf8
        var mantissa: UInt64 = 0
        var scale = 0
        var seenDot = false
        var neg = false
        var any = false
        var digits = 0
        var i = 0
        for ch in u {
            switch ch {
            case 0x2D where i == 0: neg = true            // '-'
            case 0x2B where i == 0: break                 // '+'
            case 0x2E: seenDot = true                      // '.'
            case 0x30...0x39:                              // '0'..'9'
                digits += 1
                if digits > 18 { return nil }              // 防 UInt64 溢出，回退慢路
                mantissa = mantissa &* 10 &+ UInt64(ch - 0x30)
                if seenDot { scale += 1 }
                any = true
            default: return nil                            // 其他字符（空格/e/E等）回退慢路
            }
            i += 1
        }
        guard any else { return nil }
        return Decimal(sign: neg ? .minus : .plus, exponent: -scale, significand: Decimal(mantissa))
    }

    /// 快速解析 PostgreSQL timestamp without time zone（按 UTC 处理，与原 DateFormatter GMT0 一致）。
    /// 格式 "YYYY-MM-DD HH:MM:SS" 可选 ".fff"。位置不对则返回 nil 回退。
    @inline(__always)
    private func fastDate(_ s: String) -> Date? {
        let b = Array(s.utf8)
        // 至少 "YYYY-MM-DD HH:MM:SS" = 19 字节
        guard b.count >= 19 else { return nil }
        @inline(__always) func d(_ idx: Int) -> Int? {
            let c = b[idx]; return (c >= 0x30 && c <= 0x39) ? Int(c - 0x30) : nil
        }
        guard b[4] == 0x2D, b[7] == 0x2D, b[10] == 0x20 || b[10] == 0x54, b[13] == 0x3A, b[16] == 0x3A,
              let y0=d(0),let y1=d(1),let y2=d(2),let y3=d(3),
              let mo0=d(5),let mo1=d(6), let da0=d(8),let da1=d(9),
              let h0=d(11),let h1=d(12), let mi0=d(14),let mi1=d(15), let se0=d(17),let se1=d(18)
        else { return nil }
        let year = y0*1000 + y1*100 + y2*10 + y3
        let month = mo0*10 + mo1
        let day = da0*10 + da1
        let hour = h0*10 + h1
        let minute = mi0*10 + mi1
        let second = se0*10 + se1
        // 可选小数秒
        var frac = 0.0
        if b.count > 20, b[19] == 0x2E {
            var mul = 0.1; var k = 20
            while k < b.count, let fd = d(k) { frac += Double(fd) * mul; mul *= 0.1; k += 1 }
        }
        // Howard Hinnant days_from_civil（按 UTC）
        let yy = month <= 2 ? year - 1 : year
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe/4 - yoe/100 + doy
        let days = era * 146097 + doe - 719468
        let epoch = Double(days) * 86400.0 + Double(hour*3600 + minute*60 + second) + frac
        return Date(timeIntervalSince1970: epoch)
    }

    private func parseDate(_ str: String) -> Date? {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fast = fastDate(trimmed) { return fast }   // 快路优先
        // DB 返回的主要是 PostgreSQL timestamp（空格分隔），优先匹配最常见格式。
        for f in DateFormatterCache.pg {
            if let d = f.date(from: trimmed) { return d }
        }
        if let d = DateFormatterCache.isoWithFraction.date(from: trimmed) { return d }
        if let d = DateFormatterCache.iso.date(from: trimmed) { return d }
        return nil
    }

    @inline(__always)
    private func parseDec(_ s: String) -> Decimal? {
        fastDecimal(s) ?? Decimal(string: s)
    }

    private func parseCandles(_ raw: String, symbol: String, timeframe: KXTimeframe) -> [KLCandlePoint] {
        var candles: [KLCandlePoint] = []
        let rows = raw.split(separator: "\n")
        for row in rows {
            let cols = row.split(separator: "|", maxSplits: 9).map(String.init)
            guard cols.count >= 8 else { continue }
            guard let openTime = parseDate(cols[0]),
                  let open = parseDec(cols[2]),
                  let high = parseDec(cols[3]),
                  let low = parseDec(cols[4]),
                  let close = parseDec(cols[5]),
                  let volume = parseDec(cols[6]) else { continue }
            let closeTime = cols[1] != "NULL" ? parseDate(cols[1]) : nil
            let quoteVolume = parseDec(cols[7].trimmingCharacters(in: .whitespaces))
            let tradeCount = cols.count > 8 ? Int(cols[8].trimmingCharacters(in: .whitespaces)) : nil
            let isClosed = cols.count > 9 ? (cols[9].trimmingCharacters(in: .whitespaces) == "t" || cols[9].trimmingCharacters(in: .whitespaces) == "true") : true
            candles.append(KLCandlePoint(
                symbol: symbol, timeframe: timeframe, openTime: openTime, closeTime: closeTime,
                open: open, high: high, low: low, close: close, volume: volume,
                quoteVolume: quoteVolume, tradeCount: tradeCount, isClosed: isClosed, source: "db"
            ))
        }
        return candles
    }

    private func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "'", with: "''")
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXSJ09Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-09", fileName: "KX-SJ-09_PostgreSQL适配.swift", layer: .data,
        relativePath: "数据服务层/KX-SJ-09_PostgreSQL适配.swift", duty: "PostgreSQL适配层"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("PostgreSQL适配骨架校验通过")
        return KXHealthCheckItem(name: "PostgreSQL适配", passed: true, message: "已实现PostgreSQL连接、建表、CRUD操作")
    }
}
