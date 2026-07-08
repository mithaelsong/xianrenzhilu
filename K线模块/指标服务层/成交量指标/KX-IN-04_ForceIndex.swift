//
//  KX-IN-04_ForceIndex.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Force Index (力量指数) 计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - Force Index 计算器

public struct ForceIndexCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-04" }
    public var name: String { "Force Index" }
    public var englishName: String { "Force Index" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 13.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultForceIndex) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 13)
        
        guard candles.count >= period + 1 else {
            return KXIndicatorResult()
        }
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        // 计算原始力量指数
        var rawForce: [Double] = []
        for i in 1..<candles.count {
            let prevClose = Double(truncating: NSDecimalNumber(decimal: candles[i-1].close))
            let currentClose = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
            let volume = Double(truncating: NSDecimalNumber(decimal: candles[i].volume))
            
            let force = (currentClose - prevClose) * volume
            rawForce.append(force)
            if i == 1 {
                values[0] = 0
            }
            values[i] = force
        }
        
        // 计算EMA平滑力量指数
        var emaForce: Double = 0
        let multiplier = 2.0 / (Double(period) + 1.0)
        
        // 初始化用SMA
        var sum: Double = 0
        for i in 1...period {
            sum += rawForce[i - 1]
        }
        emaForce = sum / Double(period)
        values[period] = emaForce
        
        // 继续计算EMA
        for i in (period + 1)..<candles.count {
            let currentForce = values[i] ?? 0
            emaForce = currentForce * multiplier + emaForce * (1 - multiplier)
            values[i] = emaForce
            
            // 信号：力量指数穿越零轴
            if let prevEma = values[i-1] {
                if prevEma <= 0 && emaForce > 0 {
                    // 上穿零轴 → 买入
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
                if prevEma >= 0 && emaForce < 0 {
                    // 下穿零轴 → 卖出
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
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
    static var defaultForceIndex: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 13
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX成交量指标KXIN04ForceIndex: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-04", fileName: "KX-IN-04_ForceIndex.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-04_ForceIndex.swift", duty: "ForceIndex"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "ForceIndex", passed: true, message: "ForceIndex指标实现完成")
    }
}
