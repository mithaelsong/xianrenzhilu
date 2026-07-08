//
//  KX-IN-16_ChaikinVolatility.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Chaikin Volatility（蔡金波动率）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct ChaikinVolatilityCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-16" }
    public var name: String { "蔡金波动率" }
    public var englishName: String { "Chaikin Volatility" }
    public var category: KXIndicatorCategory { .volatility }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 10.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultChaikinVolatility) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    // EMA计算
    private func calculateEMA(values: [Double], period: Int) -> [Double] {
        guard !values.isEmpty else { return [] }
        let k = 2.0 / (Double(period) + 1.0)
        var ema = [Double](repeating: 0, count: values.count)
        ema[0] = values[0]
        for i in 1..<values.count {
            ema[i] = values[i] * k + ema[i-1] * (1 - k)
        }
        return ema
    }
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 10)
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period * 2 else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 计算高低价差
        var ranges: [Double] = []
        for candle in candles {
            let high = Double(truncating: candle.high as NSDecimalNumber)
            let low = Double(truncating: candle.low as NSDecimalNumber)
            ranges.append(high - low)
        }
        
        // 计算EMA
        let emaRanges = calculateEMA(values: ranges, period: period)
        
        // 计算波动率 = 100 * log( EMA(今天) / EMA(period天前) )
        for i in (period * 2 - 1)..<candles.count {
            let currentEma = emaRanges[i]
            let prevEma = emaRanges[i - period]
            
            if prevEma > 0 {
                let volatility = 100 * log(currentEma / prevEma)
                values[i] = volatility
                
                // 信号生成
                if i >= 1 {
                    let prevVol = values[i-1] ?? 0
                    
                    // 波动率快速上升 → 趋势变化可能来临
                    if volatility > prevVol * 1.5 && volatility > 0 {
                        // 当前波动率大幅提升，提示趋势变化
                        if volatility > 20 {
                            // 大幅波动，可能是行情启动
                            if currentEma > prevEma {
                                signals.append(KXSignal(
                                    index: i,
                                    type: .strongBuy,
                                    price: candles[i].close
                                ))
                            } else {
                                signals.append(KXSignal(
                                    index: i,
                                    type: .strongSell,
                                    price: candles[i].close
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        return KXIndicatorResult(values: values, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultChaikinVolatility: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 10
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN16ChaikinVolatility: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-16", fileName: "KX-IN-16_ChaikinVolatility.swift", layer: .indicator,
        relativePath: "指标服务层/波动率指标/KX-IN-16_ChaikinVolatility.swift", duty: "ChaikinVolatility"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "ChaikinVolatility", passed: true, message: "ChaikinVolatility指标实现完成")
    }
}
