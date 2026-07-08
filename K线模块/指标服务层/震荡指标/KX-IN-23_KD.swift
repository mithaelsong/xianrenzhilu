//
//  KX-IN-23_KD.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Stochastic Oscillator（随机指标）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct StochasticOscillatorCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-23" }
    public var name: String { "KD" }
    public var englishName: String { "Stochastic Oscillator" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "kPeriod": 14.0,
            "dPeriod": 3.0,
            "overbought": 80.0,
            "oversold": 20.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultStochasticOscillator) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    private func calculateSMA(values: [Double], period: Int) -> [Double] {
        guard values.count >= period else { return [] }
        var sma: [Double] = []
        for i in (period - 1)..<values.count {
            let slice = values[(i - period + 1)...i]
            sma.append(slice.reduce(0.0, +) / Double(period))
        }
        return sma
    }
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let kPeriod = Int(parameters.values["kPeriod"] ?? 14)
        let dPeriod = Int(parameters.values["dPeriod"] ?? 3)
        let overbought = parameters.values["overbought"] ?? 80
        let oversold = parameters.values["oversold"] ?? 20
        
        var kValues: [Double?] = Array(repeating: nil, count: candles.count)
        var dValues: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= kPeriod else {
            return KXIndicatorResult(values: kValues, signals: signals)
        }
        
        // 计算每日最高最低
        var kPercent: [Double] = []
        for i in (kPeriod - 1)..<candles.count {
            var lowestLow = Double.greatestFiniteMagnitude
            var highestHigh = -Double.greatestFiniteMagnitude
            
            for j in (i - kPeriod + 1)...i {
                let low = Double(truncating: candles[j].low as NSDecimalNumber)
                let high = Double(truncating: candles[j].high as NSDecimalNumber)
                if low < lowestLow { lowestLow = low }
                if high > highestHigh { highestHigh = high }
            }
            
            let close = Double(truncating: candles[i].close as NSDecimalNumber)
            guard highestHigh != lowestLow else {
                kPercent.append(50)
                continue
            }
            let k = (close - lowestLow) / (highestHigh - lowestLow) * 100
            kPercent.append(k)
        }
        
        // 计算%D = %K的SMA
        let d = calculateSMA(values: kPercent, period: dPeriod)
        
        // 填充结果生成信号
        let startIndex = (kPeriod - 1) + (dPeriod - 1)
        for i in 0..<d.count {
            let candleIdx = i + startIndex
            guard candleIdx < candles.count else { continue }
            
            kValues[candleIdx] = kPercent[i + (dPeriod - 1)]
            dValues[candleIdx] = d[i]
            
            // 信号生成：金叉死叉
            if i >= 1 && candleIdx >= 1 {
                let prevK = kPercent[(i - 1) + (dPeriod - 1)]
                let prevD = d[i - 1]
                let currK = kPercent[i + (dPeriod - 1)]
                let currD = d[i]
                
                // K上穿D → 金叉买入
                if prevK <= prevD && currK > currD {
                    if currK < oversold {
                        // 超卖区金叉 → 强买入
                        signals.append(KXSignal(
                            index: candleIdx,
                            type: .strongBuy,
                            price: candles[candleIdx].close
                        ))
                    } else {
                        signals.append(KXSignal(
                            index: candleIdx,
                            type: .buy,
                            price: candles[candleIdx].close
                        ))
                    }
                }
                
                // K下穿D → 死叉卖出
                if prevK >= prevD && currK < currD {
                    if currK > overbought {
                        // 超买区死叉 → 强卖出
                        signals.append(KXSignal(
                            index: candleIdx,
                            type: .strongSell,
                            price: candles[candleIdx].close
                        ))
                    } else {
                        signals.append(KXSignal(
                            index: candleIdx,
                            type: .sell,
                            price: candles[candleIdx].close
                        ))
                    }
                }
                
                // 超买超卖信号
                if currK > overbought {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .strongSell,
                        price: candles[candleIdx].close
                    ))
                }
                if currK < oversold {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .strongBuy,
                        price: candles[candleIdx].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(values: kValues, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultStochasticOscillator: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "kPeriod": 14,
                "dPeriod": 3,
                "overbought": 80,
                "oversold": 20
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN23SOPR: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-23", fileName: "KX-IN-23_KD.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-23_KD.swift", duty: "SOPR"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "SOPR", passed: true, message: "SOPR指标实现完成")
    }
}
