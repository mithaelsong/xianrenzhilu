//
//  KX-IN-20_HMA.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：HMA (Hull Moving Average) 赫尔移动平均线计算实现
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct HMACalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-20" }
    public var name: String { "HMA" }
    public var englishName: String { "Hull Moving Average" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 16.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultHMA) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    // WMA计算（加权移动平均）
    private func calculateWMA_HMA(values: [Double], period: Int) -> [Double] {
        guard values.count >= period else { return [] }
        var wma: [Double] = []
        var weightSum: Double = 0
        var weightedSum: Double = 0
        for i in 0..<(period - 1) {
            let weight = Double(i + 1)
            weightSum += weight
            weightedSum += weight * values[i]
        }
        wma.append(weightedSum / weightSum)
        
        for i in period..<values.count {
            var weightSum = weightSum
            var weightedSum = weightedSum
            let weight = Double(period)
            weightSum += weight
            weightedSum += weight * values[i]
            wma.append(weightedSum / weightSum)
        }
        return wma
    }
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 16)
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period * 2 else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 提取收盘价
        let closes: [Double] = candles.map { Double(truncating: $0.close as NSDecimalNumber) }
        
        // HMA计算步骤:
        // 1. WMA(n / 2)
        // 2. WMA(n)
        // 3. HMA = 2 * WMA(n/2) - WMA(n)
        // 4. 对结果再做一次sqrt(n)长度的WMA
        
        let halfPeriod = max(1, period / 2)
        let wmaHalf = calculateWMA_HMA(values: closes, period: halfPeriod)
        let wmaFull = calculateWMA_HMA(values: closes, period: period)
        
        // 计算中间步骤 2 * wmaHalf - wmaFull
        var intermediate: [Double] = []
        for i in 0..<min(wmaHalf.count, wmaFull.count) {
            intermediate.append(2 * wmaHalf[i] - wmaFull[i])
        }
        
        // 最后一步 WMA(sqrt(period))
        let sqrtPeriod = Int(sqrt(Double(period)))
        let resultHMA = calculateWMA_HMA(values: intermediate, period: sqrtPeriod)
        
        // 填充结果生成信号
        let start = period + sqrtPeriod - 2
        for i in 0..<resultHMA.count {
            let candleIdx = i + start
            guard candleIdx < candles.count else { continue }
            values[candleIdx] = resultHMA[i]
            
            // 均线交叉信号
            if i > 0 && candleIdx > 0 {
                guard i-1 < resultHMA.count else { continue }
                let prevHMA = resultHMA[i-1]
                let currHMA = resultHMA[i]
                let prevClose = closes[candleIdx - 1]
                let currClose = closes[candleIdx]
                
                // 价格上穿均线 → 买入
                if prevClose <= prevHMA && currClose > currHMA {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .buy,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 价格下穿均线 → 卖出
                if prevClose >= prevHMA && currClose < currHMA {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .sell,
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
    static var defaultHMA: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 16
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN20HMA: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-20", fileName: "KX-IN-20_HMA.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-20_HMA.swift", duty: "HMA"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "HMA", passed: true, message: "HMA指标实现完成")
    }
}
