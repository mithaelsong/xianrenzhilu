//
//  KX-IN-15_ATR.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：ATR (Average True Range) 平均真实波幅计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct ATRCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-15" }
    public var name: String { "ATR" }
    public var englishName: String { "Average True Range" }
    public var category: KXIndicatorCategory { .volatility }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 14.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultATR) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    // Wilder 平滑：首个 ATR 为前 period 个 TR 的均值，之后 ATR = (前值 * (period - 1) + 当前TR) / period。
    private func calculateWilderATR(values: [Double], period: Int) -> [Double] {
        guard values.count >= period else { return [] }
        var out: [Double] = []
        var previous = values[0..<period].reduce(0.0, +) / Double(period)
        out.append(previous)
        for i in period..<values.count {
            previous = (previous * Double(period - 1) + values[i]) / Double(period)
            out.append(previous)
        }
        return out
    }
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 14)
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 计算真实波幅
        var trueRanges: [Double] = []
        for i in 1..<candles.count {
            let currentHigh = Double(truncating: candles[i].high as NSDecimalNumber)
            let currentLow = Double(truncating: candles[i].low as NSDecimalNumber)
            let prevClose = Double(truncating: candles[i-1].close as NSDecimalNumber)
            
            let trueRange = max(
                currentHigh - currentLow,
                max(
                    abs(currentHigh - prevClose),
                    abs(currentLow - prevClose)
                )
            )
            trueRanges.append(trueRange)
        }
        
        // 计算ATR = Wilder 平滑真实波幅，行业默认 period=14
        let atr = calculateWilderATR(values: trueRanges, period: period)
        
        // 填充结果生成信号
        let start = period
        for i in 0..<atr.count {
            let candleIdx = i + start
            guard candleIdx < candles.count else { continue }
            values[candleIdx] = atr[i]
            
            // 信号生成：ATR突破可能意味着趋势变化
            if i > 0 && candleIdx > 0 {
                let prevAtr = atr[i-1]
                let currAtr = atr[i]
                
                // ATR大幅突破均值 → 趋势开始
                if currAtr > prevAtr * 1.5 {
                    let close = candles[candleIdx].close
                    if currAtr > 2 * prevAtr {
                        // 大幅波动率放大，趋势启动
                        if close > candles[candleIdx-1].close {
                            signals.append(KXSignal(
                                index: candleIdx,
                                type: .strongBuy,
                                price: close
                            ))
                        } else {
                            signals.append(KXSignal(
                                index: candleIdx,
                                type: .strongSell,
                                price: close
                            ))
                        }
                    } else {
                        // 波动率放大，趋势变化
                        if close > candles[candleIdx-1].close {
                            signals.append(KXSignal(
                                index: candleIdx,
                                type: .buy,
                                price: close
                            ))
                        } else {
                            signals.append(KXSignal(
                                index: candleIdx,
                                type: .sell,
                                price: close
                            ))
                        }
                    }
                }
            }
        }
        
        return KXIndicatorResult(values: values, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultATR: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 14
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN15ATR: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-15", fileName: "KX-IN-15_ATR.swift", layer: .indicator,
        relativePath: "指标服务层/波动率指标/KX-IN-15_ATR.swift", duty: "ATR"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "ATR", passed: true, message: "ATR指标实现完成")
    }
}
