//
//  KX-IN-03_ADX.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：ADX（平均趋向指数）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct ADXCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-03" }
    public var name: String { "ADX" }
    public var englishName: String { "Average Directional Index" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 14.0,
            "trendThreshold": 25.0,
            "strongTrendThreshold": 40.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultADX) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    // 平滑计算（Wilder's smoothing）
    private func smooth(values: [Double], period: Int) -> [Double] {
        guard values.count >= period else { return [] }
        
        var smoothed: [Double] = []
        
        // 第一个值 = 前period个的简单平均
        let firstSum = values[0..<period].reduce(0.0, +)
        var smoothedValue = firstSum / Double(period)
        smoothed.append(smoothedValue)
        
        // 后续值 = 前一日平滑值 * (period-1)/period + 今日值 / period
        for i in period..<values.count {
            smoothedValue = smoothedValue * (Double(period) - 1.0) / Double(period) + values[i] / Double(period)
            smoothed.append(smoothedValue)
        }
        
        return smoothed
    }
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 14)
        let trendThreshold = parameters.values["trendThreshold"] ?? 25.0
        let strongTrendThreshold = parameters.values["strongTrendThreshold"] ?? 40.0
        
        var adxResults: [Double?] = Array(repeating: nil, count: candles.count)
        var diPlusResults: [Double?] = Array(repeating: nil, count: candles.count)
        var diMinusResults: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period * 2 else {
            return KXIndicatorResult(values: adxResults, signals: signals)
        }
        
        // 计算 +DM, -DM, TR
        var plusDM: [Double] = []
        var minusDM: [Double] = []
        var tr: [Double] = []
        
        for i in 1..<candles.count {
            let high = Double(truncating: candles[i].high as NSDecimalNumber)
            let low = Double(truncating: candles[i].low as NSDecimalNumber)
            let prevHigh = Double(truncating: candles[i-1].high as NSDecimalNumber)
            let prevLow = Double(truncating: candles[i-1].low as NSDecimalNumber)
            let prevClose = Double(truncating: candles[i-1].close as NSDecimalNumber)
            
            let highDiff = high - prevHigh
            let lowDiff = prevLow - low
            
            // +DM
            if highDiff > lowDiff && highDiff > 0 {
                plusDM.append(highDiff)
            } else {
                plusDM.append(0)
            }
            
            // -DM
            if lowDiff > highDiff && lowDiff > 0 {
                minusDM.append(lowDiff)
            } else {
                minusDM.append(0)
            }
            
            // TR
            let tr1 = high - low
            let tr2 = abs(high - prevClose)
            let tr3 = abs(low - prevClose)
            tr.append(max(tr1, tr2, tr3))
        }
        
        // 平滑 TR, +DM, -DM
        let atr = smooth(values: tr, period: period)
        let plusDI = smooth(values: plusDM, period: period)
        let minusDI = smooth(values: minusDM, period: period)
        
        // 计算 DI+ 和 DI-
        var diPlus: [Double] = []
        var diMinus: [Double] = []
        for i in 0..<min(atr.count, plusDI.count, minusDI.count) {
            guard atr[i] > 0 else {
                diPlus.append(0)
                diMinus.append(0)
                continue
            }
            let dip = (plusDI[i] / atr[i]) * 100
            let dim = (minusDI[i] / atr[i]) * 100
            diPlus.append(dip)
            diMinus.append(dim)
        }
        
        // 计算 DX 和 ADX
        var dx: [Double] = []
        for i in 0..<diPlus.count {
            let diff = abs(diPlus[i] - diMinus[i])
            let sum = diPlus[i] + diMinus[i]
            if sum > 0 {
                dx.append((diff / sum) * 100)
            } else {
                dx.append(0)
            }
        }
        let adx = smooth(values: dx, period: period)
        
        // 填充结果并生成信号
        let startIdx = period + period
        for i in 0..<adx.count {
            let candleIdx = i + startIdx
            guard candleIdx < candles.count else { break }
            
            adxResults[candleIdx] = adx[i]
            diPlusResults[candleIdx] = diPlus[i]
            diMinusResults[candleIdx] = diMinus[i]
            
            // 生成信号（从第二个点开始）
            if i >= 1 {
                let prevAdx = adx[i-1]
                let prevDiPlus = diPlus[i-1]
                let prevDiMinus = diMinus[i-1]
                
                let currentAdx = adx[i]
                let currentDiPlus = diPlus[i]
                let currentDiMinus = diMinus[i]
                
                let hasTrend = currentAdx > trendThreshold
                let prevHasTrend = prevAdx > trendThreshold
                let price = candles[candleIdx].close
                
                // 趋势开始
                if !prevHasTrend && hasTrend {
                    if currentDiPlus > currentDiMinus {
                        signals.append(KXSignal(
                            index: candleIdx,
                            type: .buy,
                            price: price
                        ))
                    } else {
                        signals.append(KXSignal(
                            index: candleIdx,
                            type: .sell,
                            price: price
                        ))
                    }
                }
                
                // 强趋势
                if currentAdx > strongTrendThreshold {
                    let signalType: KXSignalType = currentDiPlus > currentDiMinus ? .strongBuy : .strongSell
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: signalType,
                        price: price
                    ))
                }
                
                // DI交叉
                if prevDiPlus <= prevDiMinus && currentDiPlus > currentDiMinus {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .buy,
                        price: price
                    ))
                } else if prevDiPlus >= prevDiMinus && currentDiPlus < currentDiMinus {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .sell,
                        price: price
                    ))
                }
            }
        }
        
        // ADX结果放第一位
        return KXIndicatorResult(values: adxResults, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultADX: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 14,
                "trendThreshold": 25.0,
                "strongTrendThreshold": 40.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN03ADX: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-03", fileName: "KX-IN-03_ADX.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-03_ADX.swift", duty: "ADX"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "ADX", passed: true, message: "ADX指标实现完成")
    }
}
