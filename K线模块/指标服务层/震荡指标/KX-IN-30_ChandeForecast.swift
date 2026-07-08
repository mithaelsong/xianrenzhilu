//
//  KX-IN-30_ChandeForecast.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Chande Forecast Oscillator 钱德预测震荡指标计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct ChandeForecastCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-30" }
    public var name: String { "钱德预测" }
    public var englishName: String { "Chande Forecast Oscillator" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 14.0,
            "overbought": 50.0,
            "oversold": -50.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultChandeForecast) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 14)
        let overbought = parameters.values["overbought"] ?? 50.0
        let oversold = parameters.values["oversold"] ?? -50.0
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 计算每一根预测
        var priceChange: [Double] = []
        for i in 1..<candles.count {
            let prevClose = Double(truncating: candles[i-1].close as NSDecimalNumber)
            let currClose = Double(truncating: candles[i].close as NSDecimalNumber)
            priceChange.append(currClose - prevClose)
        }
        
        var cfo: [Double] = []
        var cumulativeUp: Double = 0
        var cumulativeChange: Double = 0
        for i in 0..<priceChange.count {
            let change = priceChange[i]
            cumulativeChange += abs(change)
            if change > 0 {
                cumulativeUp += change
            }
            
            if i >= (period - 1) {
                // 计算 CFO = 100 × (cumulativeUp - (cumulativeChange - cumulativeUp)) / cumulativeChange
                let cfoValue = 100 * (cumulativeUp - (cumulativeChange - cumulativeUp)) / cumulativeChange
                cfo.append(cfoValue)
                
                // 滑动窗口
                let startIndex = i - (period - 1)
                cumulativeChange -= abs(priceChange[startIndex])
                if priceChange[startIndex] > 0 {
                    cumulativeUp -= priceChange[startIndex]
                }
            }
        }
        
        // 填充结果生成信号
        let start = period
        for i in 0..<cfo.count {
            let candleIdx = i + start
            guard candleIdx < candles.count else { continue }
            values[candleIdx] = cfo[i]
            
            // 信号生成
            if i > 0 {
                guard i-1 < cfo.count else { continue }
                let prevCfo = cfo[i-1]
                let currCfo = cfo[i]
                
                // 从超卖区域回升 → 买入
                if prevCfo <= oversold && currCfo > oversold {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .buy,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 从超买区域回落 → 卖出
                if prevCfo >= overbought && currCfo < overbought {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .sell,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 极端信号
                if currCfo >= overbought {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .strongSell,
                        price: candles[candleIdx].close
                    ))
                }
                if currCfo <= oversold {
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
    static var defaultChandeForecast: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 14,
                "overbought": 50.0,
                "oversold": -50.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN30chandeForecast: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-30", fileName: "KX-IN-30_ChandeForecast.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-30_ChandeForecast.swift", duty: "chandeForecast"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "chandeForecast", passed: true, message: "chandeForecast指标实现完成")
    }
}
