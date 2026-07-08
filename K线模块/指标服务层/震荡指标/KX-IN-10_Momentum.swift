//
//  KX-IN-10_Momentum.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Momentum（动量指标）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct MomentumCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-10" }
    public var name: String { "Momentum" }
    public var englishName: String { "Momentum" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 10.0,
            "overbought": 100.0,
            "oversold": -100.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultMomentum) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 10)
        
        var results: [Double?] = Array(repeating: nil, count: candles.count)
        guard candles.count >= period else {
            return KXIndicatorResult(values: results, signals: [])
        }
        
        var signals: [KXSignal] = []
        let overboughtThreshold = parameters.values["overbought"] ?? 100
        let oversoldThreshold = parameters.values["oversold"] ?? -100
        
        for i in period..<candles.count {
            let currentClose = Double(truncating: candles[i].close as NSDecimalNumber)
            let prevClose = Double(truncating: candles[i - period].close as NSDecimalNumber)
            
            guard prevClose != 0 else {
                results[i] = 0
                continue
            }
            
            // 动量公式：M = 当前收盘价 - N周期前收盘价 × 100
            // 另一种算法：M = (当前 / N前) - 1 × 100，这里用第一种
            let momentum = (currentClose - prevClose) * 100
            results[i] = momentum
            
            // 信号生成
            if momentum > overboughtThreshold && results[i-1]! <= overboughtThreshold {
                signals.append(KXSignal(
                    index: i,
                    type: .sell,
                    price: candles[i].close
                ))
            }
            
            if momentum < oversoldThreshold && results[i-1]! >= oversoldThreshold {
                signals.append(KXSignal(
                    index: i,
                    type: .buy,
                    price: candles[i].close
                ))
            }
        }
        
        return KXIndicatorResult(values: results, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultMomentum: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 10,
                "overbought": 100,
                "oversold": -100
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN10Momentum: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-10", fileName: "KX-IN-10_Momentum.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-10_Momentum.swift", duty: "Momentum"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "Momentum", passed: true, message: "Momentum指标实现完成")
    }
}
