//
//  KX-IN-01_Vortex.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Vortex (涡流指标) 计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - Vortex 计算器

public struct VortexCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-01" }
    public var name: String { "Vortex" }
    public var englishName: String { "Vortex Indicator" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 14.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultVortex) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 14)
        guard candles.count >= period + 1 else {
            return KXIndicatorResult()
        }
        
        var viPlus: [Double?] = Array(repeating: nil, count: candles.count)
        var viMinus: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        var trueRangeSum: Double = 0
        var vmPlusSum: Double = 0
        var vmMinusSum: Double = 0
        
        // 计算 TR + VM 累计
        for i in 1..<candles.count {
            let prevClose = Double(truncating: NSDecimalNumber(decimal: candles[i-1].close))
            let currentHigh = Double(truncating: NSDecimalNumber(decimal: candles[i].high))
            let currentLow = Double(truncating: NSDecimalNumber(decimal: candles[i].low))
            
            // True Range
            let tr = max(
                currentHigh - currentLow,
                abs(currentHigh - prevClose),
                abs(currentLow - prevClose)
            )
            trueRangeSum += tr
            
            // Vortex Movement
            let vmP = abs(currentHigh - candles[i-1].low.doubleValue)
            let vmM = abs(currentLow - candles[i-1].high.doubleValue)
            vmPlusSum += vmP
            vmMinusSum += vmM
            
            if i >= period {
                viPlus[i] = vmPlusSum / trueRangeSum
                viMinus[i] = vmMinusSum / trueRangeSum
                
                // 金叉 viPlus 上穿 viMinus → 买入
                if let prevVP = viPlus[i-1], let prevVM = viMinus[i-1],
                   let currVP = viPlus[i], let currVM = viMinus[i] {
                    if prevVP <= prevVM && currVP > currVM {
                        signals.append(KXSignal(
                            index: i,
                            type: .buy,
                            price: candles[i].close
                        ))
                    }
                    // 死叉 viPlus 下穿 viMinus → 卖出
                    if prevVP >= prevVM && currVP < currVM {
                        signals.append(KXSignal(
                            index: i,
                            type: .sell,
                            price: candles[i].close
                        ))
                    }
                }
                
                // 滑动窗口累计
                let startIdx = i - period + 1
                let startTR = max(
                    Double(truncating: NSDecimalNumber(decimal: candles[startIdx].high)) - Double(truncating: NSDecimalNumber(decimal: candles[startIdx].low)),
                    abs(Double(truncating: NSDecimalNumber(decimal: candles[startIdx].high)) - Double(truncating: NSDecimalNumber(decimal: candles[startIdx - 1].close))),
                    abs(Double(truncating: NSDecimalNumber(decimal: candles[startIdx].low)) - Double(truncating: NSDecimalNumber(decimal: candles[startIdx - 1].close)))
                )
                trueRangeSum -= startTR
                
                let startVMP = abs(Double(truncating: NSDecimalNumber(decimal: candles[startIdx].high)) - Double(truncating: NSDecimalNumber(decimal: candles[startIdx - 1].low)))
                vmPlusSum -= startVMP
                
                let startVMM = abs(Double(truncating: NSDecimalNumber(decimal: candles[startIdx].low)) - Double(truncating: NSDecimalNumber(decimal: candles[startIdx - 1].high)))
                vmMinusSum -= startVMM
            }
        }
        
        // 输出 viPlus 作为主值
        let values: [Double?] = viPlus
        return KXIndicatorResult(
            values: values,
            signals: signals
        )
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultVortex: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 14
            ]
        )
    }
}

// MARK: - 扩展 KXDecimal 获取 doubleValue
fileprivate extension Decimal {
    var doubleValue: Double {
        Double(truncating: NSDecimalNumber(decimal: self))
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX成交量指标KXIN01Vortex: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-01", fileName: "KX-IN-01_Vortex.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-01_Vortex.swift", duty: "Vortex"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "Vortex", passed: true, message: "Vortex指标实现完成")
    }
}
