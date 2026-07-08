//
//  KX-FN-27_跨模块K线数据查询接口.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：指标模块、形态识别模块、回撤模块、预测模块、交易模块
//        通过本接口读取标准 OHLCV K线数据
//        禁止直接查库、直接访问内存缓存、直接请求 OKX
//  禁止事项：禁止UI绘制、禁止数据库写入、禁止网络请求
//

import Foundation


// MARK: - 数据查询请求

public struct KLExternalCandleRequest: Codable, Sendable {
    public let requesterModuleID: String
    public let exchange: String
    public let instrumentID: String
    public let instrumentType: String
    public let timeframe: KXTimeframe
    public let startTime: Date?
    public let endTime: Date?
    public let limit: Int?
    public let includeUnclosed: Bool

    public init(requesterModuleID: String, exchange: String = "OKX", instrumentID: String, instrumentType: String = "SPOT", timeframe: KXTimeframe, startTime: Date? = nil, endTime: Date? = nil, limit: Int? = nil, includeUnclosed: Bool = true) {
        self.requesterModuleID = requesterModuleID
        self.exchange = exchange
        self.instrumentID = instrumentID
        self.instrumentType = instrumentType
        self.timeframe = timeframe
        self.startTime = startTime
        self.endTime = endTime
        self.limit = limit
        self.includeUnclosed = includeUnclosed
    }
}

// MARK: - 数据查询响应

public struct KLExternalCandleResponse: Codable, Sendable {
    public let request: KLExternalCandleRequest
    public let candles: [KLCandlePoint]
    public let quality: KLDataQuality
    public let generatedAt: Date
    public let dataSourceSummary: String

    public init(request: KLExternalCandleRequest, candles: [KLCandlePoint], quality: KLDataQuality = .unknown, generatedAt: Date = Date(), dataSourceSummary: String = "") {
        self.request = request
        self.candles = candles
        self.quality = quality
        self.generatedAt = generatedAt
        self.dataSourceSummary = dataSourceSummary
    }
}

// MARK: - 数据查询协议

public protocol KLExternalCandleQuerying: AnyObject {
    /// 查询K线数据
    func queryCandles(request: KLExternalCandleRequest) throws -> KLExternalCandleResponse
    /// 查询当前最新一根K线
    func latestCandle(exchange: String, instrumentID: String, timeframe: KXTimeframe) -> KLCandlePoint?
    /// 查询某个时间范围内的K线数量
    func countInRange(exchange: String, instrumentID: String, timeframe: KXTimeframe, startTime: Date, endTime: Date) -> Int
    /// 查询某币对/周期是否已有数据
    func hasData(exchange: String, instrumentID: String, timeframe: KXTimeframe) -> Bool
}

// MARK: - 默认数据查询服务

public final class KLDefaultExternalCandleQueryService: KLExternalCandleQuerying, @unchecked Sendable {
    public static let shared = KLDefaultExternalCandleQueryService()

    private init() {}

    /// 外部模块查询K线的入口
    /// 实际获取数据时，内部应从：内存缓存 → 数据库 → OKX（按优先级）
    /// 当前为骨架，会调用未来的 KLDataServiceProtocol
    public func queryCandles(request: KLExternalCandleRequest) throws -> KLExternalCandleResponse {
        // 后续对接数据管道
        KLExternalCandleResponse(request: request, candles: [], quality: .unknown, dataSourceSummary: "骨架模式-未对接真实数据源")
    }

    public func latestCandle(exchange: String, instrumentID: String, timeframe: KXTimeframe) -> KLCandlePoint? {
        nil
    }

    public func countInRange(exchange: String, instrumentID: String, timeframe: KXTimeframe, startTime: Date, endTime: Date) -> Int {
        0
    }

    public func hasData(exchange: String, instrumentID: String, timeframe: KXTimeframe) -> Bool {
        false
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN27Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-27", fileName: "KX-FN-27_跨模块K线数据查询接口.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-27_跨模块K线数据查询接口.swift", duty: "跨模块K线数据查询接口定义"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("跨模块K线数据查询接口骨架校验通过")
        return KXHealthCheckItem(name: "跨模块K线数据查询接口", passed: true, message: "已实现跨模块K线数据查询接口定义")
    }
}
