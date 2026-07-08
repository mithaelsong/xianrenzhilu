//
//  KX-IN-03_VWAP.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：VWAP (Volume Weighted Average Price) 成交量加权平均价计算实现
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - VWAP 计算器

public struct VWAPCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-03" }
    public var name: String { "VWAP" }
    public var englishName: String { "Volume Weighted Average Price" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [:]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultVWAP) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        var cumulativePriceVolume: Double = 0
        var cumulativeVolume: Double = 0
        
        for i in 0..<candles.count {
            let close = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
            let volume = Double(truncating: NSDecimalNumber(decimal: candles[i].volume))
            let typicalPrice = (
                Double(truncating: NSDecimalNumber(decimal: candles[i].high)) +
                Double(truncating: NSDecimalNumber(decimal: candles[i].low)) +
                close
            ) / 3.0
            
            cumulativePriceVolume += typicalPrice * volume
            cumulativeVolume += volume
            
            if cumulativeVolume > 0 {
                values[i] = cumulativePriceVolume / cumulativeVolume
            } else {
                values[i] = close
            }
            
            // 价格穿越VWAP信号
            if i > 0 {
                let prevClose = Double(truncating: NSDecimalNumber(decimal: candles[i-1].close))
                let prevVWAP = values[i-1] ?? prevClose
                let currentVWAP = values[i] ?? close
                
                if prevClose <= prevVWAP && close > currentVWAP {
                    // 价格上穿VWAP → 买入
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
                if prevClose >= prevVWAP && close < currentVWAP {
                    // 价格下穿VWAP → 卖出
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(
            values: values,
            signals: signals
        )
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultVWAP: KXIndicatorParameters {
        KXIndicatorParameters()
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX成交量指标KXIN03VWAP: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-03", fileName: "KX-IN-03_VWAP.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-03_VWAP.swift", duty: "VWAP"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "VWAP", passed: true, message: "VWAP指标实现完成")
    }
}
