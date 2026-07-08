//
//  KX-IN-17_KeltnerChannel.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Keltner Channel 肯特纳通道计算实现
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct KeltnerChannelCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-17" }
    public var name: String { "肯特纳通道" }
    public var englishName: String { "Keltner Channel" }
    public var category: KXIndicatorCategory { .volatility }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 20.0,
            "multiplier": 2.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultKeltnerChannel) {
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
        let period = Int(parameters.values["period"] ?? 20)
        let multiplier = parameters.values["multiplier"] ?? 2.0
        
        var middleValues: [Double?] = Array(repeating: nil, count: candles.count)
        var upperValues: [Double?] = Array(repeating: nil, count: candles.count)
        var lowerValues: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period else {
            return KXIndicatorResult(values: middleValues, signals: signals)
        }
        
        // 提取真实波幅
        var trueRanges: [Double] = []
        let closes: [Double] = candles.map { Double(truncating: $0.close as NSDecimalNumber) }
        
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
        
        // 计算ATR和EMA均线
        let atrEMA = calculateEMA(values: trueRanges, period: period)
        let closeEMA = calculateEMA(values: closes, period: period)
        
        // 计算通道上下轨
        let start = period - 1
        for i in start..<closes.count {
            let atr = atrEMA[i - start]
            let middle = closeEMA[i - start]
            
            let upper = middle + multiplier * atr
            let lower = middle - multiplier * atr
            
            middleValues[i] = middle
            upperValues[i] = upper
            lowerValues[i] = lower
            
            // 信号生成：价格突破通道
            let close = closes[i]
            if close > upper {
                // 向上突破上轨 → 强势上涨，买入
                signals.append(KXSignal(
                    index: i,
                    type: .strongBuy,
                    price: candles[i].close
                ))
            }
            if close < lower {
                // 向下突破下轨 → 强势下跌，卖出
                signals.append(KXSignal(
                    index: i,
                    type: .strongSell,
                    price: candles[i].close
                ))
            }
        }
        
        // 返回中轨作为主值
        return KXIndicatorResult(values: middleValues, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultKeltnerChannel: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 20,
                "multiplier": 2.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN17KeltnerChannel: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-17", fileName: "KX-IN-17_KeltnerChannel.swift", layer: .indicator,
        relativePath: "指标服务层/波动率指标/KX-IN-17_KeltnerChannel.swift", duty: "KeltnerChannel"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "KeltnerChannel", passed: true, message: "KeltnerChannel指标实现完成")
    }
}
