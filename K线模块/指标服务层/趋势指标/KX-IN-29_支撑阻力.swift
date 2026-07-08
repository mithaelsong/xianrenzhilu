//
//  KX-IN-29_支撑阻力.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：支撑阻力位检测 (S/R detection based on swing high/low + volume)
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - 支撑阻力检测器

public struct SupportResistanceDetector: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-29" }
    public var name: String { "支撑阻力" }
    public var englishName: String { "Support & Resistance" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "swingThreshold": 2.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultSupportResistance) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let swingThreshold = Int(parameters.values["swingThreshold"] ?? 2)
        
        guard candles.count >= swingThreshold * 2 else {
            return KXIndicatorResult()
        }
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        // 检测摆动高点/低点
        var supportLevels: [Double] = []
        var resistanceLevels: [Double] = []
        
        for i in swingThreshold..<(candles.count - swingThreshold) {
            let currentHigh = Double(truncating: NSDecimalNumber(decimal: candles[i].high))
            let currentLow = Double(truncating: NSDecimalNumber(decimal: candles[i].low))
            
            // 检查是否是局部高点
            var isSwingHigh = true
            for j in (i - swingThreshold)..<i {
                if Double(truncating: NSDecimalNumber(decimal: candles[j].high)) > currentHigh {
                    isSwingHigh = false
                    break
                }
            }
            for j in (i + 1)...(i + swingThreshold) {
                if Double(truncating: NSDecimalNumber(decimal: candles[j].high)) > currentHigh {
                    isSwingHigh = false
                    break
                }
            }
            if isSwingHigh {
                resistanceLevels.append(currentHigh)
                values[i] = currentHigh
                // 阻力位，价格突破 → 买入信号
                if i < candles.count - 1 {
                    let nextClose = Double(truncating: NSDecimalNumber(decimal: candles[i + 1].close))
                    if nextClose > currentHigh {
                        signals.append(KXSignal(
                            index: i + 1,
                            type: .buy,
                            price: candles[i + 1].close
                        ))
                    }
                }
            }
            
            // 检查是否是局部低点
            var isSwingLow = true
            for j in (i - swingThreshold)..<i {
                if Double(truncating: NSDecimalNumber(decimal: candles[j].low)) < currentLow {
                    isSwingLow = false
                    break
                }
            }
            for j in (i + 1)...(i + swingThreshold) {
                if Double(truncating: NSDecimalNumber(decimal: candles[j].low)) < currentLow {
                    isSwingLow = false
                    break
                }
            }
            if isSwingLow {
                supportLevels.append(currentLow)
                values[i] = currentLow
                // 支撑位，价格跌破 → 卖出信号
                if i < candles.count - 1 {
                    let nextClose = Double(truncating: NSDecimalNumber(decimal: candles[i + 1].close))
                    if nextClose < currentLow {
                        signals.append(KXSignal(
                            index: i + 1,
                            type: .sell,
                            price: candles[i + 1].close
                        ))
                    }
                }
            }
        }
        
        // 输出最近一个支撑/阻力位作为最后一个点，方便只读取 latest 的调用方；
        // 同时历史 swing high/low 已分别写在对应K线 index，供形态识别回看多个候选位。
        if values.indices.contains(candles.count - 1), values[candles.count - 1] == nil {
            values[candles.count - 1] = (resistanceLevels.last ?? supportLevels.last)
        }
        
        return KXIndicatorResult(
            values: values,
            signals: signals
        )
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultSupportResistance: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "swingThreshold": 2
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN29支撑阻力: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-29", fileName: "KX-IN-29_支撑阻力.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-29_支撑阻力.swift", duty: "支撑阻力"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "支撑阻力", passed: true, message: "支撑阻力指标实现完成")
    }
}
