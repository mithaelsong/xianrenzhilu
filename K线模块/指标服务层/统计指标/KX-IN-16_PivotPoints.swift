//
//  KX-IN-16_PivotPoints.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Pivot Points (枢纽点) 支撑阻力计算实现
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct PivotPointsCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-16" }
    public var name: String { "枢纽点" }
    public var englishName: String { "Pivot Points" }
    public var category: KXIndicatorCategory { .statistics }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "method": 0.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultPivotPoints) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let method = parameters.values["method"] ?? 0 // 0=standard, 1=fibonacci
        
        var pivot: [Double?] = Array(repeating: nil, count: candles.count)
        var r1: [Double?] = Array(repeating: nil, count: candles.count)
        var r2: [Double?] = Array(repeating: nil, count: candles.count)
        var r3: [Double?] = Array(repeating: nil, count: candles.count)
        var s1: [Double?] = Array(repeating: nil, count: candles.count)
        var s2: [Double?] = Array(repeating: nil, count: candles.count)
        var s3: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= 1 else {
            return KXIndicatorResult(values: pivot, signals: signals)
        }
        
        // Pivot Points基于前一根周期计算当前支撑阻力
        for i in 1..<candles.count {
            let prevHigh = Double(truncating: candles[i-1].high as NSDecimalNumber)
            let prevLow = Double(truncating: candles[i-1].low as NSDecimalNumber)
            let prevClose = Double(truncating: candles[i-1].close as NSDecimalNumber)
            
            let pp = (prevHigh + prevLow + prevClose) / 3.0
            pivot[i] = pp
            
            if Int(method) == 0 {
                // Standard pivot points
                r1[i] = 2 * pp - prevLow
                s1[i] = 2 * pp - prevHigh
                r2[i] = pp + (prevHigh - prevLow)
                s2[i] = pp - (prevHigh - prevLow)
                r3[i] = r1[i]! + (prevHigh - prevLow)
                s3[i] = s1[i]! - (prevHigh - prevLow)
            } else {
                // Fibonacci pivot points
                r1[i] = pp + 0.382 * (prevHigh - prevLow)
                s1[i] = pp - 0.382 * (prevHigh - prevLow)
                r2[i] = pp + 0.618 * (prevHigh - prevLow)
                s2[i] = pp - 0.618 * (prevHigh - prevLow)
                r3[i] = pp + 1.0 * (prevHigh - prevLow)
                s3[i] = pp - 1.0 * (prevHigh - prevLow)
            }
            
            // 生成信号：价格接触支撑阻力
            let currentClose = Double(truncating: candles[i].close as NSDecimalNumber)
            if let s1Level = s1[i] {
                if abs(currentClose - s1Level) / s1Level < 0.005 {
                    // 价格接触第一支撑，买入信号
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
            }
            if let r1Level = r1[i] {
                if abs(currentClose - r1Level) / r1Level < 0.005 {
                    // 价格接触第一阻力，卖出信号
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        // Pivot主值返回pivot
        return KXIndicatorResult(values: pivot, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultPivotPoints: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "method": 0 // 0=standard
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN16PivotPoints: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-16", fileName: "KX-IN-16_PivotPoints.swift", layer: .indicator,
        relativePath: "指标服务层/统计指标/KX-IN-16_PivotPoints.swift", duty: "PivotPoints"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "PivotPoints", passed: true, message: "PivotPoints指标实现完成")
    }
}
