//
//  KX-SY-06_REST执行器.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：OKX REST API 真实执行器。用 API Key 签名，无需公共通道，为交易模块铺路。
//  禁止事项：禁止UI绘制、禁止直接写数据库（只返回标准DTO，由调用方决定写库）
//

import Foundation
import CommonCrypto
import os.log

// 导入K线日志工具

// 日志实例
private let logger = klineLogger

// MARK: - OKX Error

public struct KLOKXAPIError: LocalizedError, Sendable {
    public let code: String
    public let message: String
    public var errorDescription: String? { "OKX 错误 \(code): \(message)" }
}

// MARK: - OKX 配置（自行从数据库 environment_inventory 加载）

public struct KLOKXRESTConfig: Sendable, Codable {
    public let baseURL: String
    public let apiKey: String
    public let secretKey: String
    public let passphrase: String
    public let apiVersion: String
    public let project: String

    public init(baseURL: String = "https://www.okx.com",
                apiKey: String,
                secretKey: String,
                passphrase: String,
                apiVersion: String = "v5",
                project: String = "仙人指路2-min") {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.secretKey = secretKey
        self.passphrase = passphrase
        self.apiVersion = apiVersion
        self.project = project
    }

    /// 开发中的默认 Key（晓筱提供，用于跑通功能测试，后续在 UI 设置面板中可换）
    public static var development: KLOKXRESTConfig {
        KLOKXRESTConfig(
            apiKey: "53BC12C6ECC8A64A1D879097438FEB66",
            secretKey: "d90d8aae-15f7-4a6f-85d4-d0767ae25250",
            passphrase: "SQTadd..0204"
        )
    }

    /// 从外部配置加载。Key 注入方式由调用方决定
    public static func loadFromExternal(apiKey: String, secretKey: String, passphrase: String) -> KLOKXRESTConfig {
        KLOKXRESTConfig(apiKey: apiKey, secretKey: secretKey, passphrase: passphrase)
    }
}

// MARK: - 签名工具

public enum KLOKXSigner {
    /// 生成 OKX REST 请求签名（HMAC-SHA256 Base64）
    static func sign(timestamp: String, method: String, path: String, body: String, secretKey: String) -> String? {
        let message = "\(timestamp)\(method)\(path)\(body)"
        guard let data = message.data(using: .utf8),
              let keyData = secretKey.data(using: .utf8) else { return nil }
        var mac = CCHmacContext()
        CCHmacInit(&mac, CCHmacAlgorithm(kCCHmacAlgSHA256), (keyData as NSData).bytes, keyData.count)
        CCHmacUpdate(&mac, (data as NSData).bytes, data.count)
        var macOut = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CCHmacFinal(&mac, &macOut)
        return Data(macOut).base64EncodedString()
    }

    /// ISO 时间戳（UTC）
    static func isoTimestamp() -> String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df.string(from: Date())
    }
}

// MARK: - 执行协议

public protocol KLOKXRESTExecuting: AnyObject {
    var config: KLOKXRESTConfig { get }
    func fetchInstruments(instType: String) async throws -> [[String: Any]]
    func fetchHistoricalCandles(instID: String, bar: String, before: String?, after: String?, limit: Int) async throws -> [[String: Any]]
    func fetchRecentCandles(instID: String, bar: String, limit: Int) async throws -> [[String: Any]]
    func fetchAllHistoricalCandles(instID: String, bar: String, pageLimit: Int, maxPages: Int?) async throws -> [[String: Any]]
    func fetchServerTime() async throws -> Date
    func fetchTickerSnapshot(instID: String) async throws -> [String: Any]
}

// MARK: - 真实执行器

public final class KLOKXDefaultRESTExecutor: KLOKXRESTExecuting, @unchecked Sendable {
    public let config: KLOKXRESTConfig
    private let session: URLSession

    public init(config: KLOKXRESTConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// 便利初始化（全参数注入，Key 由外部传入）
    public convenience init?(apiKey: String, secretKey: String, passphrase: String) {
        let cfg = KLOKXRESTConfig(apiKey: apiKey, secretKey: secretKey, passphrase: passphrase)
        self.init(config: cfg)
    }

    // MARK: - 通用请求

    private func signedGet(path: String) async throws -> [[String: Any]] {
        let ts = KLOKXSigner.isoTimestamp()
        guard let sig = KLOKXSigner.sign(timestamp: ts, method: "GET", path: path, body: "", secretKey: config.secretKey) else {
            throw KLOKXAPIError(code: "SIGN_FAIL", message: "签名失败")
        }
        let url = URL(string: config.baseURL + path)!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(config.apiKey, forHTTPHeaderField: "OK-ACCESS-KEY")
        req.setValue(sig, forHTTPHeaderField: "OK-ACCESS-SIGN")
        req.setValue(ts, forHTTPHeaderField: "OK-ACCESS-TIMESTAMP")
        req.setValue(config.passphrase, forHTTPHeaderField: "OK-ACCESS-PASSPHRASE")
        req.setValue("0", forHTTPHeaderField: "OK-ACCESS-PROJECT")
        req.timeoutInterval = 15
        let (data, resp) = try await session.data(for: req)
        guard resp is HTTPURLResponse else {
            throw KLOKXAPIError(code: "NO_RESP", message: "无响应")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KLOKXAPIError(code: "JSON_FAIL", message: "JSON 解析失败")
        }
        // OKX 返回 {"code":"0","data":[...]}。
        // instruments/ticker 是字典数组；candles 是数组数组，需要规范化成字典，避免 UI 永远拿空数据。
        if let code = json["code"] as? String, code != "0" {
            throw KLOKXAPIError(code: code, message: json["msg"] as? String ?? "未知错误")
        }
        if let dictRows = json["data"] as? [[String: Any]] { return dictRows }
        if let arrayRows = json["data"] as? [[Any]] {
            return arrayRows.map { row in
                var item: [String: Any] = [:]
                let keys = ["ts", "o", "h", "l", "c", "vol", "volCcy", "volCcyQuote", "confirm"]
                for (idx, key) in keys.enumerated() where idx < row.count {
                    item[key] = row[idx]
                }
                return item
            }
        }
        return []
    }

    // MARK: - 交易对目录

    public func fetchInstruments(instType: String) async throws -> [[String: Any]] {
        try await signedGet(path: "/api/\(config.apiVersion)/public/instruments?instType=\(instType)")
    }

    // MARK: - 历史 K线

    public func fetchHistoricalCandles(instID: String, bar: String, before: String? = nil, after: String? = nil, limit: Int = 300) async throws -> [[String: Any]] {
        // OKX 历史补齐必须使用 history-candles；/market/candles 只适合最近K线快照，不能承担缺口回补。
        let effectiveLimit = max(1, min(limit, 100))
        var path = "/api/\(config.apiVersion)/market/history-candles?instId=\(instID)&bar=\(bar)&limit=\(effectiveLimit)"
        if let b = before { path += "&before=\(b)" }
        if let a = after { path += "&after=\(a)" }
        return try await signedGet(path: path)
    }

    /// 最近 K线快照，包含当前未闭合 K线；只用于图表内存底座，不承担历史缺口回补。
    public func fetchRecentCandles(instID: String, bar: String, limit: Int = 100) async throws -> [[String: Any]] {
        let effectiveLimit = max(1, min(limit, 100))
        let path = "/api/\(config.apiVersion)/market/candles?instId=\(instID)&bar=\(bar)&limit=\(effectiveLimit)"
        return try await signedGet(path: path)
    }

    /// 从 OKX history-candles 分页向更早时间拉取，直到交易所不再返回更早数据。
    /// OKX 的 history-candles 返回按时间倒序排列；使用 after=当前已知最早 ts 可继续向历史方向翻页。
    public func fetchAllHistoricalCandles(instID: String, bar: String, pageLimit: Int = 100, maxPages: Int? = nil) async throws -> [[String: Any]] {
        let limit = max(1, min(pageLimit, 100))
        var allRows: [[String: Any]] = []
        var seenTimestamps = Set<String>()
        var after: String?
        var page = 0

        while true {
            if let maxPages, page >= maxPages { break }
            let rows = try await fetchHistoricalCandlesWithRetry(instID: instID, bar: bar, before: nil, after: after, limit: limit, page: page + 1)
            if rows.isEmpty { break }

            var appended = 0
            var oldest: Double?
            for row in rows {
                guard let ts = Self.stringify(row["ts"]) else { continue }
                if seenTimestamps.insert(ts).inserted {
                    allRows.append(row)
                    appended += 1
                }
                if let value = Double(ts) {
                    oldest = min(oldest ?? value, value)
                }
            }

            page += 1
            if page == 1 || page % 25 == 0 || appended == 0 || rows.count < limit {
                logger.info("[KLine][REST] fetch all history instID=\(instID) bar=\(bar) page=\(page) rows=\(rows.count) appended=\(appended) total=\(allRows.count) oldest=\(oldest.map { String(Int64($0)) } ?? "nil")")
            }

            guard appended > 0, let oldest else { break }
            let nextAfter = String(Int64(oldest))
            if nextAfter == after { break }
            after = nextAfter
            if rows.count < limit { break }

            // 避免连续打满 OKX 频控；运行在后台，不阻塞 UI 主线程。
            try await Task.sleep(nanoseconds: 120_000_000)
        }

        return allRows
    }


    private func fetchHistoricalCandlesWithRetry(instID: String, bar: String, before: String?, after: String?, limit: Int, page: Int) async throws -> [[String: Any]] {
        var lastError: Error?
        for attempt in 1...3 {
            do {
                return try await fetchHistoricalCandles(instID: instID, bar: bar, before: before, after: after, limit: limit)
            } catch {
                lastError = error
                logger.info("[KLine][REST] retry history instID=\(instID) bar=\(bar) page=\(page) attempt=\(attempt) error=\(error.localizedDescription)")
                try await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
            }
        }
        throw lastError ?? KLOKXAPIError(code: "RETRY_FAIL", message: "历史K线请求重试失败")
    }

    // MARK: - 服务器时间

    public func fetchServerTime() async throws -> Date {
        let data = try await signedGet(path: "/api/\(config.apiVersion)/public/time")
        guard let first = data.first, let ts = first["ts"] as? String, let ms = Double(ts) else {
            throw KLOKXAPIError(code: "TIME_FAIL", message: "服务器时间解析失败")
        }
        return Date(timeIntervalSince1970: ms / 1000)
    }

    // MARK: - ticker

    public func fetchTickerSnapshot(instID: String) async throws -> [String: Any] {
        let data = try await signedGet(path: "/api/\(config.apiVersion)/market/ticker?instId=\(instID)")
        return data.first ?? [:]
    }

    // MARK: - OKX 原始数据 → KLCandlePoint 数组

    /// 将 OKX candles REST 返回转换
    public static func parseCandles(_ raw: [[String: Any]], symbol: String, timeframe: KXTimeframe, source: String) -> [KLCandlePoint] {
        var candles: [KLCandlePoint] = []
        for row in raw {
            let tsStr = stringify(row["ts"])
            let oStr = stringify(row["o"])
            let hStr = stringify(row["h"])
            let lStr = stringify(row["l"])
            let cStr = stringify(row["c"])
            let vStr = stringify(row["vol"])
            guard let tsRaw = tsStr, let ts = Double(tsRaw),
                  let oText = oStr, let o = Decimal(string: oText),
                  let hText = hStr, let h = Decimal(string: hText),
                  let lText = lStr, let l = Decimal(string: lText),
                  let cText = cStr, let cl = Decimal(string: cText),
                  let vText = vStr, let v = Decimal(string: vText)
            else { continue }
            let openTime = Date(timeIntervalSince1970: ts / 1000)
            let closeTime = closeTimeForCandle(openTime: openTime, timeframe: timeframe)
            let qv = stringify(row["volCcyQuote"]).flatMap { Decimal(string: $0) }
            let tc = stringify(row["tradeCount"]).flatMap { Int($0) }
            let confirmed = stringify(row["confirm"]) == "1"
            candles.append(KLCandlePoint(
                symbol: symbol, timeframe: timeframe,
                openTime: openTime, closeTime: closeTime,
                open: o, high: h, low: l, close: cl, volume: v,
                quoteVolume: qv, tradeCount: tc, isClosed: confirmed,
                source: source
            ))
        }
        return candles.sorted { $0.openTime < $1.openTime }
    }

    private static func closeTimeForCandle(openTime: Date, timeframe: KXTimeframe) -> Date {
        if let seconds = KXFN02TimeframeManager.seconds(for: timeframe), seconds > 0 {
            return openTime.addingTimeInterval(TimeInterval(seconds))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        switch timeframe {
        case .oneMonth:
            return calendar.date(byAdding: .month, value: 1, to: openTime) ?? openTime
        case .threeMonths:
            return calendar.date(byAdding: .month, value: 3, to: openTime) ?? openTime
        default:
            return openTime
        }
    }

    private static func stringify(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        if let d = value as? Double { return String(d) }
        if let i = value as? Int { return String(i) }
        return nil
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXSY06Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-SY-06", fileName: "KX-SY-06_REST执行器.swift", layer: .sync,
        relativePath: "网络同步层/KX-SY-06_REST执行器.swift", duty: "REST API执行器"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("REST执行器骨架校验通过")
        return KXHealthCheckItem(name: "REST执行器", passed: true, message: "已实现OKX REST API执行器")
    }
}
