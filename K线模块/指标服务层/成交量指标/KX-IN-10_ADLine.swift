//
//  KX-IN-10_ADLine.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：ADL（Accumulation/Distribution Line，累积派发线）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct AccumulationDistributionLineCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-10" }
    public var name: String { "ADL" }
    public var englishName: String { "Accumulation/Distribution Line" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [:]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultADLine) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        var adlValues: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= 2 else {
            return KXIndicatorResult(values: adlValues, signals: signals)
        }
        
        var currentADL: Double = 0
        
        for i in 0..<candles.count {
            let high = Double(truncating: candles[i].high as NSDecimalNumber)
            let low = Double(truncating: candles[i].low as NSDecimalNumber)
            let close = Double(truncating: candles[i].close as NSDecimalNumber)
            let volume = Double(truncating: candles[i].volume as NSDecimalNumber)
            
            // 计算资金流量乘数 = ((close - low) - (high - close)) / (high - low)
            let multiplier: Double
            if high != low {
                multiplier = ((close - low) - (high - close)) / (high - low)
            } else {
                multiplier = 0
            }
            
            // 资金流量 = 乘数 × 成交量
            let moneyFlow = multiplier * volume
            currentADL += moneyFlow
            adlValues[i] = currentADL
            
            // 信号生成：ADL与价格背离
            if i >= 1 {
                guard let prevADL = adlValues[i-1] else { continue }
                let prevClose = Double(truncating: candles[i-1].close as NSDecimalNumber)
                
                // 价格新高，但ADL没有新高 → 顶背离，卖出
                if close > prevClose && currentADL <= prevADL {
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
                
                // 价格新低，但ADL没有新低 → 底背离，买入
                if close < prevClose && currentADL >= prevADL {
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(values: adlValues, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultADLine: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [:]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN10ADLine: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-10", fileName: "KX-IN-10_ADLine.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-10_ADLine.swift", duty: "ADLine"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "ADLine", passed: true, message: "ADLine指标实现完成")
    }
}
