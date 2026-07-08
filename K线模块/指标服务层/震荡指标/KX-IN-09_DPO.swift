//
//  KX-IN-09_DPO.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：DPO（Detrended Price Oscillator，去趋势价格振荡器）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct DPOCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-09" }
    public var name: String { "DPO" }
    public var englishName: String { "Detrended Price Oscillator" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 20.0,
            "overbought": 0.5,
            "oversold": -0.5
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultDPO) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    // SMA计算
    private func calculateSMA(values: [Double], period: Int) -> [Double] {
        guard values.count >= period else { return [] }
        var sma: [Double] = []
        for i in (period - 1)..<values.count {
            let slice = values[(i - period + 1)...i]
            let avg = slice.reduce(0.0, +) / Double(period)
            sma.append(avg)
        }
        return sma
    }
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 20)
        let overboughtThreshold = parameters.values["overbought"] ?? 0.5
        let oversoldThreshold = parameters.values["oversold"] ?? -0.5
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period + (period / 2) else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 提取收盘价数组
        let closes: [Double] = candles.map { Double(truncating: $0.close as NSDecimalNumber) }
        // 计算SMA
        let sma = calculateSMA(values: closes, period: period)
        
        // 计算DPO = 收盘价 - SMA(N/2)周期前
        let shift = (period / 2) + 1
        for i in 0..<sma.count {
            let priceIndex = i + shift + (period - 1)
            guard priceIndex < candles.count else { continue }
            
            let dpo = closes[priceIndex] - sma[i]
            values[priceIndex] = dpo
            
            // 信号生成
            if priceIndex >= 1 && i >= 1 {
                let prevDpo = values[priceIndex - 1] ?? 0
                
                // 上穿零轴 → 买入
                if prevDpo <= 0 && dpo > 0 {
                    signals.append(KXSignal(
                        index: priceIndex,
                        type: .buy,
                        price: candles[priceIndex].close
                    ))
                }
                
                // 下穿零轴 → 卖出
                if prevDpo >= 0 && dpo < 0 {
                    signals.append(KXSignal(
                        index: priceIndex,
                        type: .sell,
                        price: candles[priceIndex].close
                    ))
                }
                
                // 超买超卖信号
                if dpo > overboughtThreshold {
                    signals.append(KXSignal(
                        index: priceIndex,
                        type: .strongSell,
                        price: candles[priceIndex].close
                    ))
                }
                if dpo < oversoldThreshold {
                    signals.append(KXSignal(
                        index: priceIndex,
                        type: .strongBuy,
                        price: candles[priceIndex].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(values: values, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultDPO: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 20,
                "overbought": 0.5,
                "oversold": -0.5
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN09DPO: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-09", fileName: "KX-IN-09_DPO.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-09_DPO.swift", duty: "DPO"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "DPO", passed: true, message: "DPO指标实现完成")
    }
}
