//
//  KX-IN-04_CCI.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：CCI（商品通道指数）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct CCICalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-04" }
    public var name: String { "CCI" }
    public var englishName: String { "Commodity Channel Index" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 20.0,
            "overbought": 100.0,
            "oversold": -100.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultCCI) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 20)
        let overbought = parameters.values["overbought"] ?? 100.0
        let oversold = parameters.values["oversold"] ?? -100.0
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        for i in (period - 1)..<candles.count {
            // 计算周期内的典型价格 (TP = (high + low + close) / 3)
            var sumTp: Double = 0
            for j in (i - period + 1)...i {
                let high = Double(truncating: candles[j].high as NSDecimalNumber)
                let low = Double(truncating: candles[j].low as NSDecimalNumber)
                let close = Double(truncating: candles[j].close as NSDecimalNumber)
                sumTp += (high + low + close) / 3.0
            }
            let meanTp = sumTp / Double(period)
            
            // 计算平均偏差 MD
            var meanDeviation: Double = 0
            for j in (i - period + 1)...i {
                let high = Double(truncating: candles[j].high as NSDecimalNumber)
                let low = Double(truncating: candles[j].low as NSDecimalNumber)
                let close = Double(truncating: candles[j].close as NSDecimalNumber)
                let tp = (high + low + close) / 3.0
                meanDeviation += abs(tp - meanTp)
            }
            meanDeviation = meanDeviation / Double(period)
            
            // 计算CCI
            let currentHigh = Double(truncating: candles[i].high as NSDecimalNumber)
            let currentLow = Double(truncating: candles[i].low as NSDecimalNumber)
            let currentClose = Double(truncating: candles[i].close as NSDecimalNumber)
            let currentTp = (currentHigh + currentLow + currentClose) / 3.0
            let cci: Double
            if meanDeviation == 0 {
                cci = 0
            } else {
                cci = (currentTp - meanTp) / (0.015 * meanDeviation)
            }
            values[i] = cci
            
            // 信号生成
            if i >= 1 {
                guard let prevCCI = values[i-1] else { continue }
                
                // 从超卖区域回升 → 买入
                if prevCCI <= oversold && cci > oversold {
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
                
                // 从超买区域回落 → 卖出
                if prevCCI >= overbought && cci < overbought {
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
                
                // 极端信号
                if cci >= overbought {
                    signals.append(KXSignal(
                        index: i,
                        type: .strongSell,
                        price: candles[i].close
                    ))
                }
                if cci <= oversold {
                    signals.append(KXSignal(
                        index: i,
                        type: .strongBuy,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(values: values, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultCCI: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 20,
                "overbought": 100.0,
                "oversold": -100.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN04CCI: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-04", fileName: "KX-IN-04_CCI.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-04_CCI.swift", duty: "CCI"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "CCI", passed: true, message: "CCI指标实现完成")
    }
}
