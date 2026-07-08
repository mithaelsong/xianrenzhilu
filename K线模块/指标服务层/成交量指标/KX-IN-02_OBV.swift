//
//  KX-IN-02_OBV.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：OBV（能量潮）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct OBVCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-02" }
    public var name: String { "OBV" }
    public var englishName: String { "On Balance Volume" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "signalPeriod": 12.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultOBV) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let signalPeriod = Int(parameters.values["signalPeriod"] ?? 12)
        
        var results: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        guard candles.count >= 2 else {
            return KXIndicatorResult(values: results, signals: signals)
        }
        
        var obv: Double = 0
        var obvArray: [Double] = []
        results[0] = 0 // 第一个点OBV为0
        obvArray.append(0)
        
        for i in 1..<candles.count {
            let currentClose = Double(truncating: candles[i].close as NSDecimalNumber)
            let prevClose = Double(truncating: candles[i-1].close as NSDecimalNumber)
            let volume = Double(truncating: candles[i].volume as NSDecimalNumber)
            
            if currentClose > prevClose {
                obv += volume
            } else if currentClose < prevClose {
                obv -= volume
            }
            // 相等不变
            results[i] = obv
            obvArray.append(obv)
        }
        
        // 如果设置了信号周期，计算OBV的EMA信号，金叉死叉
        if signalPeriod > 0 && obvArray.count >= signalPeriod {
            // 计算EMA
            let k = 2.0 / (Double(signalPeriod) + 1.0)
            var ema = [Double](repeating: 0, count: obvArray.count)
            ema[0] = obvArray[0]
            for i in 1..<obvArray.count {
                ema[i] = obvArray[i] * k + ema[i-1] * (1 - k)
            }
            
            // 金叉死叉信号
            for i in signalPeriod..<obvArray.count {
                if obvArray[i] > ema[i] && obvArray[i-1] <= ema[i-1] {
                    // OBV上穿EMA → 放量上涨，买入
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
                if obvArray[i] < ema[i] && obvArray[i-1] >= ema[i-1] {
                    // OBV下穿EMA → 放量下跌，卖出
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(values: results, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultOBV: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "signalPeriod": 12
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX成交量指标KXIN02OBV: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-02", fileName: "KX-IN-02_OBV.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-02_OBV.swift", duty: "OBV"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "OBV", passed: true, message: "OBV指标实现完成")
    }
}
