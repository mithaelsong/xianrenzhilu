//
//  KX-IN-06_CoppockCurve.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Coppock Curve（库珀克曲线）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct CoppockCurveCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-06" }
    public var name: String { "Coppock Curve" }
    public var englishName: String { "Coppock Curve" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "longPeriod": 14.0,
            "shortPeriod": 11.0,
            "wmaPeriod": 10.0,
            "buyThreshold": 0.0,
            "extremeHigh": 10.0,
            "extremeLow": -10.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultCoppockCurve) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let longPeriod = Int(parameters.values["longPeriod"] ?? 14)   // 长期ROC周期
        let shortPeriod = Int(parameters.values["shortPeriod"] ?? 11)  // 短期ROC周期
        let wmaPeriod = Int(parameters.values["wmaPeriod"] ?? 10)    // WMA周期
        
        var results: [Double?] = Array(repeating: nil, count: candles.count)
        guard candles.count >= longPeriod + wmaPeriod else {
            return KXIndicatorResult(values: results, signals: [])
        }
        
        // 计算两个ROC
        var longROC: [Double] = []
        var shortROC: [Double] = []
        
        for i in longPeriod..<candles.count {
            let currentClose = Double(truncating: candles[i].close as NSDecimalNumber)
            let prevClose = Double(truncating: candles[i - longPeriod].close as NSDecimalNumber)
            guard prevClose != 0 else {
                longROC.append(0)
                continue
            }
            let longRocValue = ((currentClose - prevClose) / prevClose) * 100
            longROC.append(longRocValue)
        }
        
        for i in shortPeriod..<candles.count {
            let currentClose = Double(truncating: candles[i].close as NSDecimalNumber)
            let prevClose = Double(truncating: candles[i - shortPeriod].close as NSDecimalNumber)
            guard prevClose != 0 else {
                shortROC.append(0)
                continue
            }
            let shortRocValue = ((currentClose - prevClose) / prevClose) * 100
            shortROC.append(shortRocValue)
        }
        
        // 对齐两个ROC数组
        let offset = longPeriod - shortPeriod
        var alignedShortROC: [Double] = []
        if offset > 0 {
            alignedShortROC = Array(repeating: 0.0, count: offset) + shortROC
        } else {
            alignedShortROC = shortROC
        }
        
        // 计算ROC之和
        var rocSum: [Double] = []
        let minCount = min(longROC.count, alignedShortROC.count)
        for i in 0..<minCount {
            rocSum.append(longROC[i] + alignedShortROC[i])
        }
        
        // 计算WMA（加权移动平均）
        for i in (wmaPeriod - 1)..<rocSum.count {
            let slice = Array(rocSum[(i - wmaPeriod + 1)...i])
            let wma = calculateWMA_Coppock(values: slice)
            let idx = i + longPeriod
            if idx < candles.count {
                results[idx] = wma
            }
        }
        
        // 生成信号
        var signals: [KXSignal] = []
        let buyThreshold = parameters.values["buyThreshold"] ?? 0.0
        
        // 从i=longPeriod + wmaPeriod - 1开始才有有效值
        for i in (longPeriod + wmaPeriod - 1)..<candles.count {
            guard let current = results[i], let prev = results[i-1] else {
                continue
            }
            
            // 从负转正，买入信号（主要用途）
            if prev < buyThreshold && current >= buyThreshold {
                let price = candles[i].close
                signals.append(KXSignal(
                    index: i,
                    type: .buy,
                    price: price
                ))
            }
            
            // 从正转负，卖出信号
            if prev > -buyThreshold && current <= -buyThreshold {
                let price = candles[i].close
                signals.append(KXSignal(
                    index: i,
                    type: .sell,
                    price: price
                ))
            }
        }
        
        return KXIndicatorResult(values: results, signals: signals)
    }
    
    // MARK: - 辅助计算
    
    private func calculateWMA_Coppock(values: [Double]) -> Double {
        let n = values.count
        var sum = 0.0
        var weightSum = 0.0
        
        for i in 0..<n {
            let weight = Double(i + 1)
            sum += values[i] * weight
            weightSum += weight
        }
        
        return sum / weightSum
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultCoppockCurve: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "longPeriod": 14,
                "shortPeriod": 11,
                "wmaPeriod": 10,
                "buyThreshold": 0.0,
                "extremeHigh": 10.0,
                "extremeLow": -10.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN06CoppockCurve: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-06", fileName: "KX-IN-06_CoppockCurve.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-06_CoppockCurve.swift", duty: "CoppockCurve"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "CoppockCurve", passed: true, message: "CoppockCurve指标实现完成")
    }
}
