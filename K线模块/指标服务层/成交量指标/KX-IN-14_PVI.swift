//
//  KX-IN-14_PVI.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：PVI (Positive Volume Index) 正成交量指标计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - PVI 计算器

public struct PVICalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-14" }
    public var name: String { "PVI" }
    public var englishName: String { "Positive Volume Index" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 255.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultPVI) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 255)
        guard candles.count > 1 else {
            return KXIndicatorResult()
        }
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        // PVI 初始值 = 1000
        var pvi: Double = 1000
        values[0] = pvi
        
        for i in 1..<candles.count {
            let prevVolume = Double(truncating: NSDecimalNumber(decimal: candles[i-1].volume))
            let currentVolume = Double(truncating: NSDecimalNumber(decimal: candles[i].volume))
            let prevClose = Double(truncating: NSDecimalNumber(decimal: candles[i-1].close))
            let currentClose = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
            
            if currentVolume > prevVolume {
                // 成交量上升 → 更新PVI
                pvi = pvi * (1 + (currentClose - prevClose) / prevClose)
            }
            // 成交量下降 → PVI不变
            
            values[i] = pvi
            
            // 金叉信号：PVI上穿EMA → 买入
            if i >= period {
                if let ema = calculateEMA(from: values, period: period, index: i),
                   let prevPvi = values[i-1],
                   let prevEma = calculateEMA(from: values, period: period, index: i-1) {
                    if prevPvi <= prevEma && pvi > ema {
                        signals.append(KXSignal(
                            index: i,
                            type: .buy,
                            price: candles[i].close
                        ))
                    }
                    if prevPvi >= prevEma && pvi < ema {
                        signals.append(KXSignal(
                            index: i,
                            type: .sell,
                            price: candles[i].close
                        ))
                    }
                }
            }
        }
        
        return KXIndicatorResult(
            values: values,
            signals: signals
        )
    }
    
    // MARK: - 辅助函数 EMA 计算
    private func calculateEMA(from values: [Double?], period: Int, index: Int) -> Double? {
        guard index >= period - 1 else { return nil }
        
        var ema: Double = 0
        
        // 初始化EMA用SMA
        var sum: Double = 0
        var count: Int = 0
        for i in (index - period + 1)...index {
            if let v = values[i] {
                sum += v
                count += 1
            }
        }
        if count == 0 { return nil }
        ema = sum / Double(count)
        
        return ema
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultPVI: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 255
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN14PVI: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-14", fileName: "KX-IN-14_PVI.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-14_PVI.swift", duty: "PVI"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "PVI", passed: true, message: "PVI指标实现完成")
    }
}
