//
//  KX-IN-18_CMO.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：CMO (Chande Momentum Oscillator) 钱德动量摆动指标计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct CMOCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-18" }
    public var name: String { "CMO" }
    public var englishName: String { "Chande Momentum Oscillator" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 14.0,
            "overbought": 50.0,
            "oversold": -50.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultCMO) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 14)
        let overbought = parameters.values["overbought"] ?? 50.0
        let oversold = parameters.values["oversold"] ?? -50.0
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 分别计算上涨sum和下跌sum
        var upSum: [Double] = []
        var downSum: [Double] = []
        
        for i in 1..<candles.count {
            let prevClose = Double(truncating: candles[i-1].close as NSDecimalNumber)
            let currClose = Double(truncating: candles[i].close as NSDecimalNumber)
            let change = currClose - prevClose
            if change > 0 {
                upSum.append(change)
                downSum.append(0)
            } else {
                upSum.append(0)
                downSum.append(-change)
            }
        }
        
        // 计算平滑sum
        var upSMA: [Double] = []
        var downSMA: [Double] = []
        for i in (period - 1)..<upSum.count {
            let upSlice = upSum[(i - period + 1)...i]
            let downSlice = downSum[(i - period + 1)...i]
            let upAvg = upSlice.reduce(0, +) / Double(period)
            let downAvg = downSlice.reduce(0, +) / Double(period)
            upSMA.append(upAvg)
            downSMA.append(downAvg)
        }
        
        // 计算CMO = 100 * (upSum - downSum) / (upSum + downSum)
        let start = period + (period - 1)
        for i in 0..<upSMA.count {
            let candleIdx = i + start
            guard candleIdx < candles.count else { continue }
            
            let cmo = 100 * (upSMA[i] - downSMA[i]) / (upSMA[i] + downSMA[i])
            values[candleIdx] = cmo
            
            // 信号生成
            if i > 0 {
                guard let prevCMO = values[candleIdx - 1] else { continue }
                
                // 从超卖区域回升 → 买入
                if prevCMO <= oversold && cmo > oversold {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .buy,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 从超买区域回落 → 卖出
                if prevCMO >= overbought && cmo < overbought {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .sell,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 极端区域信号
                if cmo >= overbought {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .strongSell,
                        price: candles[candleIdx].close
                    ))
                }
                if cmo <= oversold {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .strongBuy,
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
    static var defaultCMO: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 14,
                "overbought": 50.0,
                "oversold": -50.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN18CMO: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-18", fileName: "KX-IN-18_CMO.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-18_CMO.swift", duty: "CMO"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "CMO", passed: true, message: "CMO指标实现完成")
    }
}
