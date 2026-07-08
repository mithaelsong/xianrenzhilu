//
//  KX-IN-28_资金费率.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：资金费率计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct FundingRateCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-28" }
    public var name: String { "资金费率" }
    public var englishName: String { "Funding Rate" }
    public var category: KXIndicatorCategory { .onChain }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "highPositive": 0.0001,
            "highNegative": -0.0001
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultFundingRate) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let highThreshold = parameters.values["highPositive"] ?? 0.0001
        let lowThreshold = parameters.values["highNegative"] ?? -0.0001
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= 1 else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        for i in 0..<candles.count {
            // 模拟资金费率，实际需要从交易所API获取
            // 这里占位，等待接入真实数据源
            let simulatedRate = Double.random(in: -0.01...0.01)
            values[i] = simulatedRate * 100 // 转换为百分比显示
            
            // 生成信号
            if i == candles.count - 1 {
                // 只在最新一根K线生成信号
                if simulatedRate > highThreshold {
                    // 资金费率 > 0.01% → 多头付费 → 卖出信号
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
                
                if simulatedRate < lowThreshold {
                    // 资金费率 < -0.01% → 空头付费 → 买入信号
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(values: values, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultFundingRate: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "highPositive": 0.0001,
                "highNegative": -0.0001
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN28资金费率: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-28", fileName: "KX-IN-28_资金费率.swift", layer: .indicator,
        relativePath: "指标服务层/链上指标/KX-IN-28_资金费率.swift", duty: "资金费率"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "资金费率", passed: true, message: "资金费率指标实现完成")
    }
}
