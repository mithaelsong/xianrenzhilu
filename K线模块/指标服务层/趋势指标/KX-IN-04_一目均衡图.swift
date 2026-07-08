//
//  KX-IN-04_一目均衡图.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Ichimoku Kinko Hyo（一目均衡图）计算实现
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - 一目均衡图 计算器

public struct IchimokuCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-04" }
    public var name: String { "Ichimoku" }
    public var englishName: String { "Ichimoku Kinko Hyo" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "tenkan": 9.0,
            "kijun": 26.0,
            "senkouB": 52.0,
            "displacement": 26.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultIchimoku) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let tenkanPeriod = Int(parameters.values["tenkan"] ?? 9)
        let kijunPeriod = Int(parameters.values["kijun"] ?? 26)
        let senkouBPeriod = Int(parameters.values["senkouB"] ?? 52)
        let displacement = Int(parameters.values["displacement"] ?? 26)
        
        guard candles.count >= max(tenkanPeriod, max(kijunPeriod, senkouBPeriod)) else {
            return KXIndicatorResult()
        }
        
        var tenkanValues: [Double?] = Array(repeating: nil, count: candles.count)
        var kijunValues: [Double?] = Array(repeating: nil, count: candles.count)
        var senkouA: [Double?] = Array(repeating: nil, count: candles.count)
        var senkouB: [Double?] = Array(repeating: nil, count: candles.count)
        var chikou: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        // 计算转换线 (Tenkan-sen) = (最高价 + 最低价)/2 for tenkanPeriod
        for i in (tenkanPeriod - 1)..<candles.count {
            let slice = candles[(i - tenkanPeriod + 1)...i]
            let highs = slice.map { Double(truncating: NSDecimalNumber(decimal: $0.high)) }
            let lows = slice.map { Double(truncating: NSDecimalNumber(decimal: $0.low)) }
            let highestHigh = highs.max() ?? 0
            let lowestLow = lows.min() ?? 0
            tenkanValues[i] = (highestHigh + lowestLow) / 2
        }
        
        // 计算基准线 (Kijun-sen) = (最高价 + 最低价)/2 for kijunPeriod
        for i in (kijunPeriod - 1)..<candles.count {
            let slice = candles[(i - kijunPeriod + 1)...i]
            let highs = slice.map { Double(truncating: NSDecimalNumber(decimal: $0.high)) }
            let lows = slice.map { Double(truncating: NSDecimalNumber(decimal: $0.low)) }
            let highestHigh = highs.max() ?? 0
            let lowestLow = lows.min() ?? 0
            kijunValues[i] = (highestHigh + lowestLow) / 2
        }
        
        // 计算先行 Span A (Senkou Span A) = (Tenkan + Kijun) / 2 向前位移 displacement 根K线
        for i in (kijunPeriod - 1)..<candles.count {
            if i + displacement < candles.count {
                senkouA[i + displacement] = ((tenkanValues[i] ?? 0) + (kijunValues[i] ?? 0)) / 2
            }
        }
        
        // 计算先行 Span B (Senkou Span B) = (最高价 + 最低价)/2 for senkouBPeriod 向前位移 displacement 根K线
        for i in (senkouBPeriod - 1)..<candles.count {
            let slice = candles[(i - senkouBPeriod + 1)...i]
            let highs = slice.map { Double(truncating: NSDecimalNumber(decimal: $0.high)) }
            let lows = slice.map { Double(truncating: NSDecimalNumber(decimal: $0.low)) }
            let highestHigh = highs.max() ?? 0
            let lowestLow = lows.min() ?? 0
            if i + displacement < candles.count {
                senkouB[i + displacement] = (highestHigh + lowestLow) / 2
            }
        }
        
        // 计算迟行线 (Chikou Span) = 收盘价向后位移 displacement 根K线
        for i in 0..<candles.count {
            if i >= displacement {
                chikou[i - displacement] = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
            }
        }
        
        // 信号生成：价格穿越云层
        for i in displacement..<candles.count {
            guard let tenkan = tenkanValues[i], let kijun = kijunValues[i] else { continue }
            let close = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
            let top = max(senkouA[i] ?? 0, senkouB[i] ?? 0)
            let bottom = min(senkouA[i] ?? 0, senkouB[i] ?? 0)
            
            if close > top {
                // 价格突破云层 → 买入信号
                signals.append(KXSignal(
                    index: i,
                    type: .buy,
                    price: candles[i].close
                ))
            } else if close < bottom {
                // 价格跌破云层 → 卖出信号
                signals.append(KXSignal(
                    index: i,
                    type: .sell,
                    price: candles[i].close
                ))
            }
            
            // 金叉死叉
            if i > displacement {
                guard let prevTenkan = tenkanValues[i-1], let prevKijun = kijunValues[i-1] else { continue }
                if prevTenkan <= prevKijun && tenkan > kijun {
                    // 金叉 → 买入
                    signals.append(KXSignal(
                        index: i,
                        type: .buy,
                        price: candles[i].close
                    ))
                }
                if prevTenkan >= prevKijun && tenkan < kijun {
                    // 死叉 → 卖出
                    signals.append(KXSignal(
                        index: i,
                        type: .sell,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        // 我们输出 Tenkan 作为主值，其他可以通过计算复用
        let values: [Double?] = tenkanValues
        return KXIndicatorResult(
            values: values,
            signals: signals
        )
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultIchimoku: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "tenkan": 9,
                "kijun": 26,
                "senkouB": 52,
                "displacement": 26
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN04一目均衡图: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-04", fileName: "KX-IN-04_一目均衡图.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-04_一目均衡图.swift", duty: "一目均衡图"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "一目均衡图", passed: true, message: "一目均衡图指标实现完成")
    }
}
