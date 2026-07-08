//
//  KX-IN-05_ParabolicSAR.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Parabolic SAR (Stop and Reverse) 计算实现
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - Parabolic SAR 计算器

public struct ParabolicSARCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-05" }
    public var name: String { "Parabolic SAR" }
    public var englishName: String { "Parabolic SAR" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "acceleration": 0.02,
            "accelerationMax": 0.2,
            "accelerationIncrement": 0.02
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultParabolicSAR) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let acceleration = parameters.values["acceleration"] ?? 0.02
        let accelerationMax = parameters.values["accelerationMax"] ?? 0.2
        let accelerationIncrement = parameters.values["accelerationIncrement"] ?? 0.02
        
        guard candles.count >= 2 else {
            return KXIndicatorResult()
        }
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        // 初始化 SAR
        var currentSAR: Double = 0
        var currentEP: Double = 0
        var currentAcceleration: Double = acceleration
        var isBullish: Bool = true
        
        // 初始化第一根K线
        let firstHigh = Double(truncating: NSDecimalNumber(decimal: candles[0].high))
        let firstLow = Double(truncating: NSDecimalNumber(decimal: candles[0].low))
        let secondHigh = Double(truncating: NSDecimalNumber(decimal: candles[1].high))
        let secondLow = Double(truncating: NSDecimalNumber(decimal: candles[1].low))
        
        if secondHigh > firstHigh {
            isBullish = true
            currentEP = max(firstHigh, secondHigh)
            currentSAR = min(firstLow, secondLow)
        } else {
            isBullish = false
            currentEP = min(firstLow, secondLow)
            currentSAR = max(firstHigh, secondHigh)
        }
        
        values[0] = currentSAR
        
        for i in 1..<candles.count {
            let currentHigh = Double(truncating: NSDecimalNumber(decimal: candles[i].high))
            let currentLow = Double(truncating: NSDecimalNumber(decimal: candles[i].low))
            
            // 检查反转
            var reversed = false
            if isBullish && currentLow < currentSAR {
                // 趋势反转，从多转空
                isBullish = false
                currentEP = currentLow
                currentSAR = currentEP
                currentAcceleration = acceleration
                reversed = true
                // 反转 → 卖出信号
                signals.append(KXSignal(
                    index: i,
                    type: .sell,
                    price: candles[i].close
                ))
            } else if !isBullish && currentHigh > currentSAR {
                // 趋势反转，从空转多
                isBullish = true
                currentEP = currentHigh
                currentSAR = currentEP
                currentAcceleration = acceleration
                reversed = true
                // 反转 → 买入信号
                signals.append(KXSignal(
                    index: i,
                    type: .buy,
                    price: candles[i].close
                ))
            }
            
            if !reversed {
                // 更新极端价格
                if isBullish && currentHigh > currentEP {
                    currentEP = currentHigh
                    currentAcceleration = min(currentAcceleration + accelerationIncrement, accelerationMax)
                } else if !isBullish && currentLow < currentEP {
                    currentEP = currentLow
                    currentAcceleration = min(currentAcceleration + accelerationIncrement, accelerationMax)
                }
                
                // 更新 SAR
                if isBullish {
                    currentSAR = currentSAR + currentAcceleration * (currentEP - currentSAR)
                    // SAR 不能超过最近两根K线的最低点
                    if i >= 1 {
                        let prevLow = Double(truncating: NSDecimalNumber(decimal: candles[i - 1].low))
                        currentSAR = min(currentSAR, prevLow)
                        currentSAR = min(currentSAR, currentLow)
                    }
                } else {
                    currentSAR = currentSAR - currentAcceleration * (currentSAR - currentEP)
                    // SAR 不能超过最近两根K线的最高点
                    if i >= 1 {
                        let prevHigh = Double(truncating: NSDecimalNumber(decimal: candles[i - 1].high))
                        currentSAR = max(currentSAR, prevHigh)
                        currentSAR = max(currentSAR, currentHigh)
                    }
                }
            }
            
            values[i] = currentSAR
        }
        
        // 输出 SAR 值
        return KXIndicatorResult(
            values: values,
            signals: signals
        )
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultParabolicSAR: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "acceleration": 0.02,
                "accelerationMax": 0.2,
                "accelerationIncrement": 0.02
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN05ParabolicSAR: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-05", fileName: "KX-IN-05_ParabolicSAR.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-05_ParabolicSAR.swift", duty: "ParabolicSAR"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "ParabolicSAR", passed: true, message: "ParabolicSAR指标实现完成")
    }
}
