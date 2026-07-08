//
//  KX-IN-08_PO.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：PO (Price Oscillator) 价格震荡指标计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct PriceOscillatorCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-08" }
    public var name: String { "PO" }
    public var englishName: String { "Price Oscillator" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "fastPeriod": 12.0,
            "slowPeriod": 26.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultPriceOscillator) {
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
        let fastPeriod = Int(parameters.values["fastPeriod"] ?? 12)
        let slowPeriod = Int(parameters.values["slowPeriod"] ?? 26)
        
        var poValues: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= slowPeriod else {
            return KXIndicatorResult(values: poValues, signals: signals)
        }
        
        // 提取收盘价
        let closes: [Double] = candles.map { Double(truncating: $0.close as NSDecimalNumber) }
        
        // 计算快慢EMA
        let fastEMA = calculateEMA(values: closes, period: fastPeriod)
        let slowEMA = calculateEMA(values: closes, period: slowPeriod)
        
        // 计算 PO = 快速EMA - 慢速EMA
        let start = slowPeriod - 1
        for i in start..<closes.count {
            let po = fastEMA[i] - slowEMA[i]
            poValues[i] = po
            
            // 信号生成：穿越零线
            if i > start {
                let prevPo = poValues[i-1] ?? 0
                
                // 上穿零线买入
                if prevPo <= 0 && po > 0 {
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
                
                // 下穿零线卖出
                if prevPo >= 0 && po < 0 {
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
                
                // 极端值信号
                if po > 0.05 {
                    signals.append(KXSignal(
                        index: i,
                        type: .strongBuy,
                        price: candles[i].close
                    ))
                }
                if po < -0.05 {
                    signals.append(KXSignal(
                        index: i,
                        type: .strongSell,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(values: poValues, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultPriceOscillator: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "fastPeriod": 12,
                "slowPeriod": 26
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN08PO: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-08", fileName: "KX-IN-08_PO.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-08_PO.swift", duty: "PO"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "PO", passed: true, message: "PO指标实现完成")
    }
}
