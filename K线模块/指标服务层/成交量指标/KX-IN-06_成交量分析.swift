//
//  KX-IN-06_成交量分析.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Volume Analysis (成交量分析) 计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - 成交量分析计算器

public struct VolumeAnalysisCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-06" }
    public var name: String { "成交量分析" }
    public var englishName: String { "Volume Analysis" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 20.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultVolumeAnalysis) {
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
        
        // 计算上涨/下跌成交量平均值
        var upVolumeSum: Double = 0
        var downVolumeSum: Double = 0
        var upCount: Int = 0
        var downCount: Int = 0
        
        for i in 0..<candles.count {
            if i > 0 {
                let prevClose = Double(truncating: NSDecimalNumber(decimal: candles[i-1].close))
                let currentClose = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
                let volume = Double(truncating: NSDecimalNumber(decimal: candles[i].volume))
                
                if currentClose > prevClose {
                    // 上涨
                    upVolumeSum += volume
                    upCount += 1
                } else {
                    // 下跌
                    downVolumeSum += volume
                    downCount += 1
                }
            }
            
            // 滑动窗口
            if i >= period {
                let avgUpVolume = upCount > 0 ? upVolumeSum / Double(upCount) : 0
                let avgDownVolume = downCount > 0 ? downVolumeSum / Double(downCount) : 0
                
                // 计算成交量比率
                let ratio: Double
                if avgDownVolume == 0 {
                    ratio = 10 // 如果没有下跌量，设为偏高
                } else {
                    ratio = avgUpVolume / avgDownVolume
                }
                
                values[i] = ratio
                
                // 信号生成
                if i > 0 {
                    let prevRatio = values[i-1] ?? 1
                    
                    // 放量上涨 → 买入信号
                    if ratio > 2 && prevRatio <= 2 {
                        signals.append(KXSignal(
                            index: i,
                            type: .buy,
                            price: candles[i].close
                        ))
                    }
                    
                    // 放量下跌 → 卖出信号
                    if ratio < 0.5 && prevRatio >= 0.5 {
                        signals.append(KXSignal(
                            index: i,
                            type: .sell,
                            price: candles[i].close
                        ))
                    }
                }
                
                // 滑动窗口移除最老的数据
                let removeIdx = i - period + 1
                if removeIdx > 0 {
                    let prevRemoveClose = Double(truncating: NSDecimalNumber(decimal: candles[removeIdx - 1].close))
                    let currentRemoveClose = Double(truncating: NSDecimalNumber(decimal: candles[removeIdx].close))
                    let removeVolume = Double(truncating: NSDecimalNumber(decimal: candles[removeIdx].volume))
                    
                    if currentRemoveClose > prevRemoveClose {
                        upVolumeSum -= removeVolume
                        upCount -= 1
                    } else {
                        downVolumeSum -= removeVolume
                        downCount -= 1
                    }
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
    static var defaultVolumeAnalysis: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 20
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX成交量指标KXIN06成交量分析: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-06", fileName: "KX-IN-06_成交量分析.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-06_成交量分析.swift", duty: "成交量分析"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "成交量分析", passed: true, message: "成交量分析指标实现完成")
    }
}
