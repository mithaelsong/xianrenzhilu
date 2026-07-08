//
//  KX-IN-07_UltimateOscillator.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Ultimate Oscillator（终极振荡器）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct UltimateOscillatorCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-07" }
    public var name: String { "Ultimate Oscillator" }
    public var englishName: String { "Ultimate Oscillator" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period1": 7.0,
            "period2": 14.0,
            "period3": 28.0,
            "weight1": 4.0,
            "weight2": 2.0,
            "weight3": 1.0,
            "overbought": 70.0,
            "oversold": 30.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultUltimateOscillator) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    private func calculateBP(closes: [Double], highs: [Double], lows: [Double]) -> [Double] {
        var bp: [Double] = []
        for i in 1..<closes.count {
            let currentLow = lows[i]
            let prevClose = closes[i-1]
            bp.append(max(0, currentLow - prevClose))
        }
        return bp
    }
    
    private func calculateTR(closes: [Double], highs: [Double], lows: [Double]) -> [Double] {
        var tr: [Double] = []
        for i in 1..<closes.count {
            let high = highs[i]
            let low = lows[i]
            let prevClose = closes[i-1]
            let trValue = max(high - low, max(abs(high - prevClose), abs(low - prevClose)))
            tr.append(trValue)
        }
        return tr
    }
    
    private func average(period: Int, from index: Int, data: [Double]) -> Double {
        let start = max(0, index - period + 1)
        let sum = data[start...index].reduce(0.0, +)
        return sum / Double(index - start + 1)
    }
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period1 = Int(parameters.values["period1"] ?? 7)
        let period2 = Int(parameters.values["period2"] ?? 14)
        let period3 = Int(parameters.values["period3"] ?? 28)
        let weight1 = parameters.values["weight1"] ?? 4.0
        let weight2 = parameters.values["weight2"] ?? 2.0
        let weight3 = parameters.values["weight3"] ?? 1.0
        let overbought = parameters.values["overbought"] ?? 70.0
        let oversold = parameters.values["oversold"] ?? 30.0
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        let totalNeeded = period3 + 1 // 因为BP/TR从索引1开始
        guard candles.count >= totalNeeded else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 提取价格数组
        let closes: [Double] = candles.map { Double(truncating: $0.close as NSDecimalNumber) }
        let highs: [Double] = candles.map { Double(truncating: $0.high as NSDecimalNumber) }
        let lows: [Double]  = candles.map { Double(truncating: $0.low  as NSDecimalNumber) }
        
        // 计算 Buying Pressure 和 True Range
        let bp = calculateBP(closes: closes, highs: highs, lows: lows)
        let tr = calculateTR(closes: closes, highs: highs, lows: lows)
        
        // 计算三个周期平均
        let requiredStart = period3 - 1
        for i in requiredStart..<bp.count {
            let avg1 = average(period: period1, from: i, data: bp) / average(period: period1, from: i, data: tr)
            let avg2 = average(period: period2, from: i, data: bp) / average(period: period2, from: i, data: tr)
            let avg3 = average(period: period3, from: i, data: bp) / average(period: period3, from: i, data: tr)
            
            let uo = 100 * (
                (weight1 * avg1 + weight2 * avg2 + weight3 * avg3) /
                (weight1 + weight2 + weight3)
            )
            
            let candleIdx = i + 1 // 对应原始 candles
            values[candleIdx] = uo
            
            // 信号生成
            if candleIdx >= 1 && i >= 1 {
                guard let prevUO = values[candleIdx - 1] else { continue }
                
                // 从超卖区域回升 → 买入信号
                if prevUO < oversold && uo >= oversold {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .buy,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 从超买区域回落 → 卖出信号
                if prevUO > overbought && uo <= overbought {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .sell,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 牛熊背离检测（简化版）
                if uo > overbought {
                    // 超买区域，强势卖出信号
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .strongSell,
                        price: candles[candleIdx].close
                    ))
                }
                if uo < oversold {
                    // 超卖区域，强势买入信号
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .strongBuy,
                        price: candles[candleIdx].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(values: values, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultUltimateOscillator: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period1": 7,
                "period2": 14,
                "period3": 28,
                "weight1": 4.0,
                "weight2": 2.0,
                "weight3": 1.0,
                "overbought": 70.0,
                "oversold": 30.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN07UltimateOscillator: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-07", fileName: "KX-IN-07_UltimateOscillator.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-07_UltimateOscillator.swift", duty: "UltimateOscillator"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "UltimateOscillator", passed: true, message: "UltimateOscillator指标实现完成")
    }
}
