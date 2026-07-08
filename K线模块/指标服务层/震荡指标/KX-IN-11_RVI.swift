//
//  KX-IN-11_RVI.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：RVI（相对波动率指数）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct RVICalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-11" }
    public var name: String { "RVI" }
    public var englishName: String { "Relative Volatility Index" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 14.0,
            "overbought": 70.0,
            "oversold": 30.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultRVI) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 14)
        let overboughtThreshold = parameters.values["overbought"] ?? 70
        let oversoldThreshold = parameters.values["oversold"] ?? 30
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period + 1 else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 计算每一段的标准差
        var stdDevs: [Double] = []
        for i in 1..<candles.count {
            let start = max(0, i - period + 1)
            let slice = Array(candles[start...i])
            let closes: [Double] = slice.map { Double(truncating: $0.close as NSDecimalNumber) }
            let mean = closes.reduce(0.0, +) / Double(closes.count)
            let variance = closes.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(closes.count)
            let stdDev = sqrt(variance)
            stdDevs.append(stdDev)
        }
        
        // 分开上涨日和下跌日的标准差
        var upStdDev: [Double] = []
        var downStdDev: [Double] = []
        
        for i in 1..<stdDevs.count {
            let currentClose = Double(truncating: candles[i].close as NSDecimalNumber)
            let prevClose = Double(truncating: candles[i-1].close as NSDecimalNumber)
            
            if currentClose > prevClose {
                upStdDev.append(stdDevs[i-1])
                downStdDev.append(0)
            } else {
                upStdDev.append(0)
                downStdDev.append(stdDevs[i-1])
            }
        }
        
        // 使用Wilder's smoothing计算平均
        guard upStdDev.count >= period else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        var avgUp = upStdDev[0..<period].reduce(0.0, +) / Double(period)
        var avgDown = downStdDev[0..<period].reduce(0.0, +) / Double(period)
        
        for i in period..<upStdDev.count {
            avgUp = (avgUp * Double(period - 1) + upStdDev[i]) / Double(period)
            avgDown = (avgDown * Double(period - 1) + downStdDev[i]) / Double(period)
            
            // RVI = 100 - 100 / (1 + RVS), RVS = StdDev(gains) / StdDev(losses)
            let rvs = avgDown > 0 ? avgUp / avgDown : 0
            let rvi = 100 - (100 / (1 + rvs))
            
            let idx = i + 2  // 对齐原始数据
            if idx < candles.count {
                values[idx] = rvi
                
                // 生成信号
                if i >= 1 {
                    let prevIdx = idx - 1
                    guard let prevRvi = values[prevIdx] else { continue }
                    
                    // 上穿中线，买入
                    if prevRvi < 50 && rvi >= 50 {
                        signals.append(KXSignal(
                            index: idx,
                            type: .buy,
                            price: candles[idx].close
                        ))
                    }
                    // 下穿中线，卖出
                    if prevRvi > 50 && rvi <= 50 {
                        signals.append(KXSignal(
                            index: idx,
                            type: .sell,
                            price: candles[idx].close
                        ))
                    }
                    
                    // 超买信号
                    if rvi >= overboughtThreshold {
                        signals.append(KXSignal(
                            index: idx,
                            type: .strongSell,
                            price: candles[idx].close
                        ))
                    }
                    // 超卖信号
                    if rvi <= oversoldThreshold {
                        signals.append(KXSignal(
                            index: idx,
                            type: .strongBuy,
                            price: candles[idx].close
                        ))
                    }
                }
            }
        }
        
        // RVI作为主值返回
        return KXIndicatorResult(values: values, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultRVI: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 14,
                "overbought": 70.0,
                "oversold": 30.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN11RVI: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-11", fileName: "KX-IN-11_RVI.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-11_RVI.swift", duty: "RVI"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "RVI", passed: true, message: "RVI指标实现完成")
    }
}
