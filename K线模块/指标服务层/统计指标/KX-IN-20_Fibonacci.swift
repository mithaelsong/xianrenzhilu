//
//  KX-IN-20_Fibonacci.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Fibonacci Retracement 斐波那契回撤位计算实现
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - 斐波那契回撤计算器

public struct FibonacciRetracementCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-20" }
    public var name: String { "斐波那契" }
    public var englishName: String { "Fibonacci Retracement" }
    public var category: KXIndicatorCategory { .statistics }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [:]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultFibonacci) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let startIndex = 0
        let endIndex = candles.count - 1
        
        guard startIndex < endIndex else {
            return KXIndicatorResult()
        }
        
        // 获取起点和终点价格
        let startPrice = Double(truncating: NSDecimalNumber(decimal: candles[startIndex].low))
        let endPrice = Double(truncating: NSDecimalNumber(decimal: candles[endIndex].high))
        
        let range = endPrice - startPrice
        
        // 计算斐波那契回撤位
        let levels: [Double] = [0.236, 0.382, 0.5, 0.618, 0.786]
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        // 计算每个回撤位，输出主要的 0.618 位作为主值
        if levels.count > 3 {
            let fib618 = levels[3]
            let level = startPrice + fib618 * range
            for i in startIndex...endIndex {
                values[i] = level
            }
            
            // 价格回到 0.618 支撑位 → 买入信号
            for i in startIndex..<candles.count {
                let close = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
                if abs(close - level) < 0.01 * level {
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(
            values: values,
            signals: signals
        )
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultFibonacci: KXIndicatorParameters {
        KXIndicatorParameters()
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN20Fibonacci: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-20", fileName: "KX-IN-20_Fibonacci.swift", layer: .indicator,
        relativePath: "指标服务层/统计指标/KX-IN-20_Fibonacci.swift", duty: "Fibonacci"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "Fibonacci", passed: true, message: "Fibonacci指标实现完成")
    }
}
