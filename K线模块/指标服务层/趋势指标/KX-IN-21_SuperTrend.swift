//
//  KX-IN-21_SuperTrend.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：SuperTrend（超级趋势）计算实现
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct SuperTrendCalculator: KXIndicatorProtocol {
    
    public var identifier: String { "KX-IN-21" }
    public var name: String { "SuperTrend" }
    public var englishName: String { "SuperTrend" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 10.0,
            "multiplier": 3.0
        ]
    }

    public init(parameters: KXIndicatorParameters = .defaultSuperTrend) {
        self.parameters = parameters
    }
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let atrPeriod = Int(parameters.values["period"] ?? 10)
        let multiplier = parameters.values["multiplier"] ?? 3.0
        
        guard candles.count >= atrPeriod else {
            // 返回全空结果
            return KXIndicatorResult(values: Array(repeating: nil, count: candles.count))
        }
        
        var results: [Double?] = Array(repeating: nil, count: candles.count)
        var atrValues: [Double] = []
        var upperBand: Double = 0
        var lowerBand: Double = 0
        var trend: Double = 1  // 1 = up, -1 = down
        
        // 计算TR（真实波动范围）
        for i in 1..<candles.count {
            let high = Double(truncating: candles[i].high as NSDecimalNumber)
            let low = Double(truncating: candles[i].low as NSDecimalNumber)
            let prevClose = Double(truncating: candles[i-1].close as NSDecimalNumber)
            
            let tr1 = high - low
            let tr2 = abs(high - prevClose)
            let tr3 = abs(low - prevClose)
            atrValues.append(max(tr1, tr2, tr3))
        }
        
        // 初始ATR
        var atr = atrValues[0..<atrPeriod].reduce(0.0, +) / Double(atrPeriod)
        
        for i in atrPeriod..<candles.count {
            atr = (atr * Double(atrPeriod - 1) + atrValues[i-1]) / Double(atrPeriod)
            
            let high = Double(truncating: candles[i].high as NSDecimalNumber)
            let low = Double(truncating: candles[i].low as NSDecimalNumber)
            let close = Double(truncating: candles[i].close as NSDecimalNumber)
            let prevClose = Double(truncating: candles[i-1].close as NSDecimalNumber)
            
            let mid = (high + low) / 2
            let newUpper = mid + multiplier * atr
            let newLower = mid - multiplier * atr
            
            if i == atrPeriod {
                upperBand = newUpper
                lowerBand = newLower
                results[i] = lowerBand
            } else {
                upperBand = prevClose > upperBand ? min(newUpper, upperBand) : newUpper
                lowerBand = prevClose < lowerBand ? max(newLower, lowerBand) : newLower
                
                if close > upperBand {
                    trend = 1
                    results[i] = lowerBand
                } else if close < lowerBand {
                    trend = -1
                    results[i] = upperBand
                } else {
                    results[i] = trend == 1 ? lowerBand : upperBand
                }
            }
        }
        
        return KXIndicatorResult(values: results, signals: [])
    }
}

public extension KXIndicatorParameters {
    static var defaultSuperTrend: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 10,
                "multiplier": 3.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN21SuperTrend: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-21", fileName: "KX-IN-21_SuperTrend.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-21_SuperTrend.swift", duty: "SuperTrend"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "SuperTrend", passed: true, message: "SuperTrend指标实现完成")
    }
}
