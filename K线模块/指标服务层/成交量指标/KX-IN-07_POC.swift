//
//  KX-IN-07_POC.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：POC (Point of Control) 成交量价位分布计算实现
//  显示位置：K线主图侧边/水平
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct POCCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-07" }
    public var name: String { "POC" }
    public var englishName: String { "Point of Control" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "numBins": 20.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultPOC) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let numBins = Int(parameters.values["numBins"] ?? 20)
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= 20 else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 找出价格范围
        var minPrice = Double.greatestFiniteMagnitude
        var maxPrice = -Double.greatestFiniteMagnitude
        var totalVolume: Double = 0
        
        for candle in candles {
            let close = Double(truncating: candle.close as NSDecimalNumber)
            let volume = Double(truncating: candle.volume as NSDecimalNumber)
            if close < minPrice { minPrice = close }
            if close > maxPrice { maxPrice = close }
            totalVolume += volume
        }
        
        // 分箱统计成交量
        guard maxPrice > minPrice else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        let binSize = (maxPrice - minPrice) / Double(numBins)
        var volumeBins: [Double] = Array(repeating: 0, count: numBins)
        
        for candle in candles {
            let close = Double(truncating: candle.close as NSDecimalNumber)
            let volume = Double(truncating: candle.volume as NSDecimalNumber)
            let bin = Int(floor((close - minPrice) / binSize))
            if bin >= 0 && bin < numBins {
                volumeBins[bin] += volume
            }
        }
        
        // 找到最大成交量价位 = POC
        if let maxBin = volumeBins.enumerated().max(by: { $0.element < $1.element })?.offset {
            let pocPrice = minPrice + (Double(maxBin) + 0.5) * binSize
            // POC值放在最后一根K线
            values[candles.count - 1] = pocPrice
            
            // 生成信号：提醒关注POC价位，作为重要支撑阻力
            signals.append(KXSignal(
                index: candles.count - 1,
                type: .none,
                price: candles[candles.count - 1].close
            ))
        }
        
        return KXIndicatorResult(values: values, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultPOC: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "numBins": 20
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX成交量指标KXIN07POC: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-07", fileName: "KX-IN-07_POC.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-07_POC.swift", duty: "POC"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "POC", passed: true, message: "POC指标实现完成")
    }
}
