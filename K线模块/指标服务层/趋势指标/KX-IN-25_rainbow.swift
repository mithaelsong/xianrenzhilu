//
//  KX-IN-25_rainbow.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Rainbow Moving Average 彩虹均线计算实现
//  显示位置：K线主图叠加多条均线
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct RainbowMovingAverageCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-25" }
    public var name: String { "彩虹均线" }
    public var englishName: String { "Rainbow Moving Average" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "basePeriod": 8.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultRainbow) {
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
        let basePeriod = Int(parameters.values["basePeriod"] ?? 2)
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        let closes: [Double] = candles.map { Double(truncating: $0.close as NSDecimalNumber) }
        
        // 彩虹均线由多条不同周期SMA组成，2~basePeriod步进
        var rainbow: [(period: Int, sma: [Double])] = []
        for p in 2...basePeriod {
            let sma = calculateSMA(values: closes, period: p)
            rainbow.append((period: p, sma: sma))
        }
        
        // 取最长周期均线作为主结果
        if let last = rainbow.last {
            let start = basePeriod - 1
            for i in 0..<last.sma.count {
                let candleIdx = i + start
                guard candleIdx < candles.count else { continue }
                values[candleIdx] = last.sma[i]
                
                // 均线多头排列信号
                if i > 0 && i < rainbow.count - 1 {
                    guard let prevSma = rainbow[i].sma[safe: i],
                          let currSma = rainbow[i+1].sma[safe: i] else { continue }
                    let prevClose = closes[candleIdx - 1]
                    let currClose = closes[candleIdx]
                    if prevClose < prevSma && currClose > currSma {
                            // 均线多头排列 → 买入信号
                            signals.append(KXSignal(
                                index: candleIdx,
                                type: .strongBuy,
                                price: candles[candleIdx].close
                            ))
                        }
                        if prevClose > prevSma && currClose < currSma {
                            // 均线空头排列 → 卖出信号
                            signals.append(KXSignal(
                                index: candleIdx,
                                type: .strongSell,
                                price: candles[candleIdx].close
                            ))
                        }
                }
            }
        }

        return KXIndicatorResult(values: values, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultRainbow: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "basePeriod": 8
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN25rainbow: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-25", fileName: "KX-IN-25_rainbow.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-25_rainbow.swift", duty: "rainbow"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "rainbow", passed: true, message: "rainbow指标实现完成")
    }
}
