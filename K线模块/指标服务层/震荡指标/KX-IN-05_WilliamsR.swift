//
//  KX-IN-05_WilliamsR.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Williams %R (威廉指标)计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct WilliamsRCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-05" }
    public var name: String { "Williams %R" }
    public var englishName: String { "Williams Percent Range" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 14.0,
            "overbought": -20.0,
            "oversold": -80.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultWilliamsR) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 14)
        let overbought = parameters.values["overbought"] ?? -20.0
        let oversold = parameters.values["oversold"] ?? -80.0
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        for i in (period - 1)..<candles.count {
            // 找到周期内最高最低价
            var highest = -Double.greatestFiniteMagnitude
            var lowest = Double.greatestFiniteMagnitude
            
            for j in (i - period + 1)...i {
                let high = Double(truncating: candles[j].high as NSDecimalNumber)
                let low = Double(truncating: candles[j].low as NSDecimalNumber)
                if high > highest { highest = high }
                if low < lowest { lowest = low }
            }
            
            let close = Double(truncating: candles[i].close as NSDecimalNumber)
            // Williams %R = ( highest - close ) / ( highest - lowest ) * -100
            guard highest != lowest else {
                values[i] = -50
                continue
            }
            let wr = (highest - close) / (highest - lowest) * (-100)
            values[i] = wr
            
            // 信号生成
            if i >= 1 {
                guard let prevWr = values[i-1] else { continue }
                
                // 从超卖区域回升 → 买入
                if prevWr <= oversold && wr > oversold {
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
                
                // 从超买区域回落 → 卖出
                if prevWr >= overbought && wr < overbought {
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
                
                // 极端区域提示
                if wr <= oversold {
                    signals.append(KXSignal(
                        index: i,
                        type: .strongBuy,
                        price: candles[i].close
                    ))
                }
                if wr >= overbought {
                    signals.append(KXSignal(
                        index: i,
                        type: .strongSell,
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
    static var defaultWilliamsR: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 14,
                "overbought": -20.0,
                "oversold": -80.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN05WilliamsR: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-05", fileName: "KX-IN-05_WilliamsR.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-05_WilliamsR.swift", duty: "WilliamsR"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "WilliamsR", passed: true, message: "WilliamsR指标实现完成")
    }
}
