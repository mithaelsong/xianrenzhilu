//
//  KX-IN-08_Aroon.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Aroon（阿隆指标）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct AroonCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-08" }
    public var name: String { "Aroon" }
    public var englishName: String { "Aroon Indicator" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 25.0,
            "strongThreshold": 70.0,
            "weakThreshold": 50.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultAroon) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    // 辅助计算：找到最高价格索引
    private func findHighestIndex(in slice: [KLCandlePoint]) -> Int {
        guard !slice.isEmpty else { return 0 }
        var maxIndex = 0
        var maxValue = Double(truncating: slice[0].high as NSDecimalNumber)
        
        for i in 1..<slice.count {
            let current = Double(truncating: slice[i].high as NSDecimalNumber)
            if current > maxValue {
                maxValue = current
                maxIndex = i
            }
        }
        
        // 返回距离当前的距离（从最后算起）
        return slice.count - 1 - maxIndex
    }
    
    // 辅助计算：找到最低价格索引
    private func findLowestIndex(in slice: [KLCandlePoint]) -> Int {
        guard !slice.isEmpty else { return 0 }
        var minIndex = 0
        var minValue = Double(truncating: slice[0].low as NSDecimalNumber)
        
        for i in 1..<slice.count {
            let current = Double(truncating: slice[i].low as NSDecimalNumber)
            if current < minValue {
                minValue = current
                minIndex = i
            }
        }
        
        // 返回距离当前的距离（从最后算起）
        return slice.count - 1 - minIndex
    }
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 25)
        let strongThreshold = parameters.values["strongThreshold"] ?? 70.0
        let weakThreshold = parameters.values["weakThreshold"] ?? 50.0
        
        var aroonUpValues: [Double?] = Array(repeating: nil, count: candles.count)
        var aroonDownValues: [Double?] = Array(repeating: nil, count: candles.count)
        var oscillatorValues: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period else {
            return KXIndicatorResult(values: oscillatorValues, signals: signals)
        }
        
        for i in (period - 1)..<candles.count {
            let slice = Array(candles[(i - period + 1)...i])
            
            // 找到最高点和最低点的位置（距离当前的距离）
            let highestIndex = findHighestIndex(in: slice)
            let lowestIndex = findLowestIndex(in: slice)
            
            // Aroon Up = (period - days_since_high) / period * 100
            let aroonUp = (Double(period) - Double(highestIndex)) / Double(period) * 100
            
            // Aroon Down = (period - days_since_low) / period * 100
            let aroonDown = (Double(period) - Double(lowestIndex)) / Double(period) * 100
            
            // Aroon Oscillator = Aroon Up - Aroon Down
            let aroonOsc = aroonUp - aroonDown
            
            aroonUpValues[i] = aroonUp
            aroonDownValues[i] = aroonDown
            oscillatorValues[i] = aroonOsc
            
            // 生成信号
            if i >= 1 && i >= (period - 1) + 1 {
                guard let prevAroonUp = aroonUpValues[i-1], let prevAroonDown = aroonDownValues[i-1] else {
                    continue
                }
                
                // Aroon Up 上穿 Aroon Down，买入
                if prevAroonUp <= prevAroonDown && aroonUp > aroonDown {
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
                
                // Aroon Down 上穿 Aroon Up，卖出
                if prevAroonDown <= prevAroonUp && aroonDown > aroonUp {
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
                
                // Aroon Up > 强阈值，强上升趋势
                if aroonUp > strongThreshold {
                    signals.append(KXSignal(
                        index: i,
                        type: .strongBuy,
                        price: candles[i].close
                    ))
                }
                
                // Aroon Down > 强阈值，强下降趋势
                if aroonDown > strongThreshold {
                    signals.append(KXSignal(
                        index: i,
                        type: .strongSell,
                        price: candles[i].close
                    ))
                }
                
                // 双方都 < 弱阈值，盘整
                if aroonUp < weakThreshold && aroonDown < weakThreshold {
                    // 中性信号，不操作，这里可以不添加，或者保留记录
                }
            }
        }
        
        // 输出 Oscillator 作为主值
        return KXIndicatorResult(values: oscillatorValues, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultAroon: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 25,
                "strongThreshold": 70.0,
                "weakThreshold": 50.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN08Aroon: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-08", fileName: "KX-IN-08_Aroon.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-08_Aroon.swift", duty: "Aroon"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "Aroon", passed: true, message: "Aroon指标实现完成")
    }
}
