//
//  KX-IN-19_牛熊力量.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：牛熊力量（Bull Bear Power）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct BullBearPowerCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-19" }
    public var name: String { "牛熊力量" }
    public var englishName: String { "Bull Bear Power" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "emaPeriod": 13.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultBullBearPower) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    // 计算EMA
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
        let emaPeriod = Int(parameters.values["emaPeriod"] ?? 13)
        
        var bullPower: [Double?] = Array(repeating: nil, count: candles.count)
        var bearPower: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= emaPeriod else {
            return KXIndicatorResult(values: bullPower, signals: signals)
        }
        
        // 计算EMA
        var closes: [Double] = []
        var highs: [Double] = []
        var lows: [Double] = []
        for candle in candles {
            closes.append(Double(truncating: candle.close as NSDecimalNumber))
            highs.append(Double(truncating: candle.high as NSDecimalNumber))
            lows.append(Double(truncating: candle.low as NSDecimalNumber))
        }
        let emaCloses = calculateEMA(values: closes, period: emaPeriod)
        
        // 计算牛熊力量
        for i in (emaPeriod - 1)..<candles.count {
            let bull = highs[i] - emaCloses[i]
            let bear = lows[i] - emaCloses[i]
            bullPower[i] = bull
            bearPower[i] = bear
            
            // 信号生成
            if i >= 1 {
                let prevBull = bullPower[i-1] ?? 0
                let currBull = bull
                let prevBear = bearPower[i-1] ?? 0
                let currBear = bear
                
                // 牛线上穿零线 → 买入
                if prevBull <= 0 && currBull > 0 {
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
                
                // 熊线下穿零线 → 卖出
                if prevBear >= 0 && currBear < 0 {
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
                
                // 牛力放大且为正 → 强买
                if currBull > 0 && abs(currBull) > abs(prevBull) {
                    signals.append(KXSignal(
                        index: i,
                        type: .strongBuy,
                        price: candles[i].close
                    ))
                }
                
                // 熊力放大且为负 → 强卖
                if currBear < 0 && abs(currBear) > abs(prevBear) {
                    signals.append(KXSignal(
                        index: i,
                        type: .strongSell,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        // 主值返回牛力
        return KXIndicatorResult(values: bullPower, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultBullBearPower: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "emaPeriod": 13
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN19牛熊力量: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-19", fileName: "KX-IN-19_牛熊力量.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-19_牛熊力量.swift", duty: "牛熊力量"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "牛熊力量", passed: true, message: "牛熊力量指标实现完成")
    }
}
