//
//  KX-IN-06_StochasticRSI.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Stochastic RSI（随机相对强弱指数）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct StochasticRSICalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-06" }
    public var name: String { "Stochastic RSI" }
    public var englishName: String { "Stochastic RSI" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "rsiPeriod": 14.0,
            "stochPeriod": 14.0,
            "kPeriod": 3.0,
            "dPeriod": 3.0,
            "overbought": 80.0,
            "oversold": 20.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultStochasticRSI) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let rsiPeriod = Int(parameters.values["rsiPeriod"] ?? 14)
        let stochPeriod = Int(parameters.values["stochPeriod"] ?? 14)
        let kPeriod = Int(parameters.values["kPeriod"] ?? 3)
        let dPeriod = Int(parameters.values["dPeriod"] ?? 3)
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= rsiPeriod + stochPeriod + kPeriod else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 第一步：计算RSI
        let rsiResults = calculateRSI(data: candles, period: rsiPeriod)
        
        // 第二步：计算Stochastic RSI
        var stochRSI: [Double] = []
        for i in (stochPeriod - 1)..<rsiResults.count {
            let slice = Array(rsiResults[(i - stochPeriod + 1)...i])
            let lowestRSI = slice.min() ?? 0
            let highestRSI = slice.max() ?? 100
            
            let currentRSI = rsiResults[i]
            var value: Double = 0
            if highestRSI != lowestRSI {
                value = (currentRSI - lowestRSI) / (highestRSI - lowestRSI)
            }
            stochRSI.append(value)
        }
        
        // 第三步：计算K线（Stoch RSI的SMA）
        let kLine = calculateSMA(values: stochRSI, period: kPeriod)
        
        // 第四步：计算D线（K线的SMA）
        let dLine = calculateSMA(values: kLine, period: dPeriod)
        
        // 组装结果values
        let startIndex = rsiPeriod + stochPeriod + kPeriod - 2
        for i in 0..<min(kLine.count, dLine.count) {
            let idx = startIndex + i
            if idx < candles.count {
                let k = kLine[i]
                values[idx] = k * 100  // 转换为0-100范围
            }
        }
        
        // 生成信号
        if kLine.count >= 2 && dLine.count >= 2 {
            for i in 1..<min(kLine.count, dLine.count) {
                let idx = startIndex + i
                guard idx < candles.count else { continue }
                
                let prevK = kLine[i-1] * 100
                let prevD = dLine[i-1] * 100
                let currK = kLine[i] * 100
                let currD = dLine[i] * 100
                
                // K上穿D → 金叉买入
                if prevK <= prevD && currK > currD && currK < 20 {
                    signals.append(KXSignal(
                        index: idx,
                        type: .buy,
                        price: candles[idx].close
                    ))
                }
                
                // K下穿D → 死叉卖出
                if prevK >= prevD && currK < currD && currK > 80 {
                    signals.append(KXSignal(
                        index: idx,
                        type: .sell,
                        price: candles[idx].close
                    ))
                }
                
                // 超卖区域
                if currK < 20 {
                    // 超卖区域提示，直接按买入信号处理
                    signals.append(KXSignal(
                        index: idx,
                        type: .buy,
                        price: candles[idx].close
                    ))
                }
                
                // 超买区域
                if currK > 80 {
                    // 超买区域提示，直接按卖出信号处理
                    signals.append(KXSignal(
                        index: idx,
                        type: .sell,
                        price: candles[idx].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(
            values: values,
            signals: signals
        )
    }
    
    // MARK: - 辅助计算
    
    private func calculateRSI(data: [KLCandlePoint], period: Int) -> [Double] {
        var rsi: [Double] = []
        
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<data.count {
            let change = Double(truncating: data[i].close as NSDecimalNumber) - Double(truncating: data[i-1].close as NSDecimalNumber)
            if change > 0 {
                gains.append(change)
                losses.append(0)
            } else {
                gains.append(0)
                losses.append(abs(change))
            }
        }
        
        guard gains.count >= period else { return rsi }
        
        var avgGain = gains[0..<period].reduce(0.0, +) / Double(period)
        var avgLoss = losses[0..<period].reduce(0.0, +) / Double(period)
        
        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
            
            let rs = avgLoss > 0 ? avgGain / avgLoss : 0
            let value = 100 - (100 / (1 + rs))
            rsi.append(value)
        }
        
        return rsi
    }
    
    private func calculateSMA(values: [Double], period: Int) -> [Double] {
        guard values.count >= period else { return [] }
        
        var sma: [Double] = []
        for i in (period - 1)..<values.count {
            let slice = Array(values[(i - period + 1)...i])
            let value = slice.reduce(0.0, +) / Double(period)
            sma.append(value)
        }
        
        return sma
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultStochasticRSI: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "rsiPeriod": 14,
                "stochPeriod": 14,
                "kPeriod": 3,
                "dPeriod": 3,
                "overbought": 80,
                "oversold": 20
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN06StochasticRSI: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-06", fileName: "KX-IN-06_StochasticRSI.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-06_StochasticRSI.swift", duty: "StochasticRSI"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "StochasticRSI", passed: true, message: "StochasticRSI指标实现完成")
    }
}
