//
//  KX-IN-12_MFI.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：MFI（资金流量指数）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - MFI 计算器

public struct MFICalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-12" }
    public var name: String { "MFI" }
    public var englishName: String { "Money Flow Index" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 14.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultMFI) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 14)
        guard candles.count >= period + 1 else {
            return KXIndicatorResult()
        }
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        // 计算典型价格和资金流量
        var rawMoneyFlow: [Double] = []
        var typicalPrices: [Double] = []
        
        for i in 0..<candles.count {
            let high = Double(truncating: NSDecimalNumber(decimal: candles[i].high))
            let low = Double(truncating: NSDecimalNumber(decimal: candles[i].low))
            let close = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
            
            let tp = (high + low + close) / 3.0
            typicalPrices.append(tp)
            rawMoneyFlow.append(tp * Double(truncating: NSDecimalNumber(decimal: candles[i].volume)))
        }
        
        for i in period..<typicalPrices.count {
            var positiveFlow: Double = 0
            var negativeFlow: Double = 0
            
            for j in (i - period + 1)...i {
                if typicalPrices[j] > typicalPrices[j-1] {
                    positiveFlow += rawMoneyFlow[j]
                } else if typicalPrices[j] < typicalPrices[j-1] {
                    negativeFlow += rawMoneyFlow[j]
                }
            }
            
            let mfi: Double
            if negativeFlow == 0 {
                mfi = 100
            } else {
                let moneyRatio = positiveFlow / negativeFlow
                mfi = 100 * (moneyRatio / (1 + moneyRatio))
            }
            
            values[i] = mfi
            
            // 超买超卖信号
            if mfi > 80 {
                signals.append(KXSignal(
                    index: i,
                    type: .strongSell,
                    price: candles[i].close
                ))
            }
            if mfi < 20 {
                signals.append(KXSignal(
                    index: i,
                    type: .strongBuy,
                    price: candles[i].close
                ))
            }
            
            // 背离信号简化处理
            if i > period {
                let prevMfi = values[i-1] ?? 50
                if mfi > 80 && prevMfi <= 80 {
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
                if mfi < 20 && prevMfi >= 20 {
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
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
    static var defaultMFI: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 14
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN12MFI: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-12", fileName: "KX-IN-12_MFI.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-12_MFI.swift", duty: "MFI"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "MFI", passed: true, message: "MFI指标实现完成")
    }
}
