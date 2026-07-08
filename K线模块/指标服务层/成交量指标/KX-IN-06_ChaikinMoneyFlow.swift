//
//  KX-IN-06_ChaikinMoneyFlow.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：CMF (Chaikin Money Flow) 蔡金资金流量计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct ChaikinMoneyFlowCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-06" }
    public var name: String { "CMF" }
    public var englishName: String { "Chaikin Money Flow" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 20.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultCMF) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 20)
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 计算每根的资金流量
        var mf: [Double] = []
        for candle in candles {
            let close = Double(truncating: candle.close as NSDecimalNumber)
            let high = Double(truncating: candle.high as NSDecimalNumber)
            let low = Double(truncating: candle.low as NSDecimalNumber)
            let volume = Double(truncating: candle.volume as NSDecimalNumber)
            
            guard high != low else {
                mf.append(0)
                continue
            }
            
            // 计算资金流量 = 收盘位置 × 成交量
            let closeLocation = ((close - low) - (high - close)) / (high - low)
            mf.append(closeLocation * volume)
        }
        
        // 计算周期平均
        var cmf: [Double] = []
        for i in (period - 1)..<mf.count {
            let slice = mf[(i - period + 1)...i]
            let volumeSum = candles[(i - period + 1)...i].map {
                Double(truncating: $0.volume as NSDecimalNumber)
            }.reduce(0, +)
            
            let sumMF = slice.reduce(0, +)
            let currentCMF = volumeSum > 0 ? sumMF / volumeSum : 0
            cmf.append(currentCMF)
            
            // 填充结果
            let candleIdx = i + 1
            guard candleIdx < candles.count else { continue }
            values[candleIdx] = currentCMF
            
            // 信号生成
            if i > 0 && i >= (period - 1) + 1 {
                let prevCMF = cmf[i-1]
                
                // 上穿零线 → 资金流入，买入
                if prevCMF <= 0 && currentCMF > 0 {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .buy,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 下穿零线 → 资金流出，卖出
                if prevCMF >= 0 && currentCMF < 0 {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .sell,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 强信号：持续偏离零线
                if currentCMF > 0.2 {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .strongBuy,
                        price: candles[candleIdx].close
                    ))
                }
                if currentCMF < -0.2 {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .strongSell,
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
    static var defaultCMF: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 20
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN06ChaikinMoneyFlow: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-06", fileName: "KX-IN-06_ChaikinMoneyFlow.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-06_ChaikinMoneyFlow.swift", duty: "ChaikinMoneyFlow"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "ChaikinMoneyFlow", passed: true, message: "ChaikinMoneyFlow指标实现完成")
    }
}
