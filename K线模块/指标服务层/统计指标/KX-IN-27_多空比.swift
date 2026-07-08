//
//  KX-IN-27_多空比.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：多空比 (Bull/Bear Ratio) 计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - 多空比计算器

public struct BullBearRatioCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-27" }
    public var name: String { "多空比" }
    public var englishName: String { "Bull Bear Ratio" }
    public var category: KXIndicatorCategory { .statistics }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 20.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultBullBear) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 20)
        
        guard candles.count >= period else {
            return KXIndicatorResult()
        }
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        // 统计上涨下跌数量
        var upCount: Int = 0
        var downCount: Int = 0
        
        // 初始化
        for i in 0..<(period - 1) {
            if i == 0 { continue }
            let prevClose = Double(truncating: NSDecimalNumber(decimal: candles[i-1].close))
            let currentClose = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
            if currentClose > prevClose {
                upCount += 1
            } else {
                downCount += 1
            }
        }
        
        // 滑动窗口计算
        for i in (period - 1)..<candles.count {
            let prevClose = Double(truncating: NSDecimalNumber(decimal: candles[i - period].close))
            let currentPrevClose = Double(truncating: NSDecimalNumber(decimal: candles[i-1].close))
            let currentClose = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
            
            // 更新窗口：移除最老的，加入最新的
            if i > (period - 1) {
                if prevClose > Double(truncating: NSDecimalNumber(decimal: candles[i - period - 1].close)) {
                    upCount -= 1
                } else {
                    downCount -= 1
                }
            }
            
            if currentClose > currentPrevClose {
                upCount += 1
            } else {
                downCount += 1
            }
            
            // 计算多空比
            let ratio: Double
            if downCount == 0 {
                ratio = 10.0 // 绝对多头，设为10
            } else {
                ratio = Double(upCount) / Double(downCount)
            }
            
            values[i] = ratio
            
            // 信号生成
            if i > (period - 1) {
                let prevRatio = values[i-1] ?? 1.0
                
                // 多空比突破 1.5 → 多头信号
                if prevRatio <= 1.5 && ratio > 1.5 {
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
                
                // 多空比跌破 0.7 → 空头信号
                if prevRatio >= 0.7 && ratio < 0.7 {
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
    static var defaultBullBear: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 20
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN27多空比: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-27", fileName: "KX-IN-27_多空比.swift", layer: .indicator,
        relativePath: "指标服务层/统计指标/KX-IN-27_多空比.swift", duty: "多空比"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "多空比", passed: true, message: "多空比指标实现完成")
    }
}
