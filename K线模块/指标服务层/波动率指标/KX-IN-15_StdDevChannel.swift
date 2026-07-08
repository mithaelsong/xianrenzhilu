//
//  KX-IN-15_StdDevChannel.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Standard Deviation Channel 标准差通道计算实现
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct StdDeviationChannelCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-15" }
    public var name: String { "标准差通道" }
    public var englishName: String { "Standard Deviation Channel" }
    public var category: KXIndicatorCategory { .volatility }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 20.0,
            "multiplier": 2.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultStdDevChannel) {
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
    
    // 计算标准差
    private func calculateStdDev(values: [Double], mean: Double, from: Int, to: Int) -> Double {
        var sumSq: Double = 0
        for i in from...to {
            let diff = values[i] - mean
            sumSq += diff * diff
        }
        let count = Double(to - from + 1)
        return sqrt(sumSq / count)
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
        
        // 提取收盘价
        let closes: [Double] = candles.map { Double(truncating: $0.close as NSDecimalNumber) }
        
        // 计算均线和标准差
        let sma = calculateSMA(values: closes, period: period)
        
        let start = period - 1
        for i in start..<closes.count {
            let stdDev = calculateStdDev(values: closes, mean: sma[i - start], from: i - period + 1, to: i)
            
            let middle = sma[i - start]
            let upper = middle + multiplier * stdDev
            let lower = middle - multiplier * stdDev
            
            middleValues[i] = middle
            upperValues[i] = upper
            lowerValues[i] = lower
            
            // 信号生成：价格触碰上下轨
            let close = closes[i]
            if i > start {
                let prevClose = closes[i-1]
                
                // 突破上轨 → 买入
                if prevClose <= upper && close > upper {
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
                
                // 跌破下轨 → 卖出
                if prevClose >= lower && close < lower {
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(values: middleValues, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultStdDevChannel: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 20,
                "multiplier": 2.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN15StdDevChannel: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-15", fileName: "KX-IN-15_StdDevChannel.swift", layer: .indicator,
        relativePath: "指标服务层/波动率指标/KX-IN-15_StdDevChannel.swift", duty: "StdDevChannel"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "StdDevChannel", passed: true, message: "StdDevChannel指标实现完成")
    }
}
