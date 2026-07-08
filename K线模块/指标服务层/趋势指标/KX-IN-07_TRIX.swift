//
//  KX-IN-07_TRIX.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：TRIX（三重指数平滑）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct TRIXCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-07" }
    public var name: String { "TRIX" }
    public var englishName: String { "Triple Exponential Average" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 15.0,
            "signalPeriod": 9.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultTRIX) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    private func calculateEMA(values: [Double], period: Int) -> [Double] {
        guard !values.isEmpty else { return [] }
        var ema = [Double](repeating: 0, count: values.count)
        let k = 2.0 / (Double(period) + 1.0)
        ema[0] = values[0]
        for i in 1..<values.count {
            ema[i] = values[i] * k + ema[i-1] * (1 - k)
        }
        return ema
    }
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 15)
        let signalPeriod = Int(parameters.values["signalPeriod"] ?? 9)
        
        let totalLength = period * 3 + signalPeriod
        var results: [Double?] = Array(repeating: nil, count: candles.count)
        var signalResults: [Double?] = Array(repeating: nil, count: candles.count)
        guard candles.count >= totalLength else {
            return KXIndicatorResult(values: results, signals: [])
        }
        
        // 第一步：提取收盘价数组
        let closes: [Double] = candles.map { Double(truncating: $0.close as NSDecimalNumber) }
        
        // 第二步：三重EMA计算
        let ema1 = calculateEMA(values: closes, period: period)
        let ema2 = calculateEMA(values: ema1, period: period)
        let ema3 = calculateEMA(values: ema2, period: period)
        
        // 第三步：计算TRIX = (EMA3_today - EMA3_yesterday) / EMA3_yesterday * 100
        var trixValues: [Double] = []
        let trixStartIndex = 3 * (period - 1) + 1
        
        for i in trixStartIndex..<ema3.count {
            let value = ((ema3[i] - ema3[i-1]) / ema3[i-1]) * 100
            trixValues.append(value)
            results[i] = value
        }
        
        // 第四步：计算信号线（TRIX的EMA）
        let signalEma = calculateEMA(values: trixValues, period: signalPeriod)
        
        // 填充结果并生成信号
        var signals: [KXSignal] = []
        
        for i in 0..<signalEma.count {
            let finalIndex = trixStartIndex + i
            guard finalIndex < candles.count else { break }
            signalResults[finalIndex] = signalEma[i]
            
            // 金叉死叉信号
            if i >= 1 {
                let prevTrix = trixValues[i-1]
                let prevSignal = signalEma[i-1]
                let currTrix = trixValues[i]
                let currSignal = signalEma[i]
                
                // TRIX上穿信号线 → 金叉买入
                if prevTrix < prevSignal && currTrix >= currSignal {
                    signals.append(KXSignal(
                        index: finalIndex,
                        type: .buy,
                        price: candles[finalIndex].close
                    ))
                }
                
                // TRIX下穿信号线 → 死叉卖出
                if prevTrix > prevSignal && currTrix <= currSignal {
                    signals.append(KXSignal(
                        index: finalIndex,
                        type: .sell,
                        price: candles[finalIndex].close
                    ))
                }
            }
        }
        
        // TRIX结果放第一位
        return KXIndicatorResult(values: results, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultTRIX: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 15,
                "signalPeriod": 9
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN07TRIX: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-07", fileName: "KX-IN-07_TRIX.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-07_TRIX.swift", duty: "TRIX"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "TRIX", passed: true, message: "TRIX指标实现完成")
    }
}
