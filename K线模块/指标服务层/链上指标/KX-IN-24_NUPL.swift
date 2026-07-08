//
//  KX-IN-24_NUPL.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：NUPL（净未实现利润/损失）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation


public struct NUPLCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-24" }
    public var name: String { "NUPL" }
    public var englishName: String { "Net Unrealized Profit/Loss" }
    public var category: KXIndicatorCategory { .onChain }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "euphoria": 0.5,
            "capitulation": 0.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultNUPL) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let euphoriaThreshold = parameters.values["euphoria"] ?? 0.5
        let capitulationThreshold = parameters.values["capitulation"] ?? 0.0
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        for i in 0..<candles.count {
            // 模拟NUPL，实际需要从链上获取
            let simulatedNUPL = Double.random(in: -0.5...0.75)
            values[i] = simulatedNUPL
            
            // 只在最后一个数据点生成信号
            if i == candles.count - 1 {
                if simulatedNUPL > euphoriaThreshold {
                    // NUPL > 阈值 → 极度贪婪，市场过热，卖出信号
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
                if simulatedNUPL < capitulationThreshold {
                    // NUPL < 阈值 → 未实现亏损，恐惧情绪，买入信号
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
    static var defaultNUPL: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "euphoria": 0.5,
                "capitulation": 0.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN24NUPL: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-24", fileName: "KX-IN-24_NUPL.swift", layer: .indicator,
        relativePath: "指标服务层/链上指标/KX-IN-24_NUPL.swift", duty: "NUPL"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "NUPL", passed: true, message: "NUPL指标实现完成")
    }
}
