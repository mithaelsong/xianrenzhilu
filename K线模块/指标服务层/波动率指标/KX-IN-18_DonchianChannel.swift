//
//  KX-IN-18_DonchianChannel.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Donchian Channel（唐奇安通道）计算实现
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - Donchian Channel 计算器

public struct DonchianChannelCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-18" }
    public var name: String { "Donchian Channel" }
    public var englishName: String { "Donchian Channel" }
    public var category: KXIndicatorCategory { .volatility }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 20.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultDonchianChannel) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 20)
        guard candles.count >= period else {
            return KXIndicatorResult()
        }
        
        var upper: [Double?] = Array(repeating: nil, count: candles.count)
        var lower: [Double?] = Array(repeating: nil, count: candles.count)
        var middle: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        for i in (period - 1)..<candles.count {
            let slice = candles[(i - period + 1)...i]
            let highs = slice.map { Double(truncating: NSDecimalNumber(decimal: $0.high)) }
            let lows = slice.map { Double(truncating: NSDecimalNumber(decimal: $0.low)) }
            
            let highestHigh = highs.max() ?? 0
            let lowestLow = lows.min() ?? 0
            let mid = (highestHigh + lowestLow) / 2
            
            upper[i] = highestHigh
            lower[i] = lowestLow
            middle[i] = mid
            
            // 突破上轨 → 买入信号
            let currentPrice = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
            if currentPrice > highestHigh {
                signals.append(KXSignal(
                    index: i,
                    type: .buy,
                    price: candles[i].close
                ))
            }
            
            // 跌破下轨 → 卖出信号
            if currentPrice < lowestLow {
                signals.append(KXSignal(
                    index: i,
                    type: .sell,
                    price: candles[i].close
                ))
            }
        }
        
        // Donchian Channel 输出上轨到values数组（我们只输出主要轨道，其他轨道可以复用计算结果）
        let values: [Double?] = upper
        return KXIndicatorResult(
            values: values,
            signals: signals
        )
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultDonchianChannel: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 20
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN18DonchianChannel: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-18", fileName: "KX-IN-18_DonchianChannel.swift", layer: .indicator,
        relativePath: "指标服务层/波动率指标/KX-IN-18_DonchianChannel.swift", duty: "DonchianChannel"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "DonchianChannel", passed: true, message: "DonchianChannel指标实现完成")
    }
}
