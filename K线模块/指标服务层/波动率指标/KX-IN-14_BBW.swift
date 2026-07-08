//
//  KX-IN-14_BBW.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：BBW (Bollinger Band Width) 布林带宽计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct BBWCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-14" }
    public var name: String { "布林带宽" }
    public var englishName: String { "Bollinger Band Width" }
    public var category: KXIndicatorCategory { .volatility }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 20.0,
            "multiplier": 2.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultBBW) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    // SMA计算
    private func calculateSMA(values: [Double], period: Int) -> [Double] {
        guard values.count >= period else { return [] }
        var sma: [Double] = []
        for i in (period - 1)..<values.count {
            let slice = values[(i - period + 1)...i]
            let avg = slice.reduce(0.0, +) / Double(period)
            sma.append(avg)
        }
        return sma
    }
    
    // 计算标准差
    private func calculateStandardDeviation(values: [Double], mean: Double, from: Int, to: Int) -> Double {
        var sumSq: Double = 0
        for i in from...to {
            let diff = values[i] - mean
            sumSq += diff * diff
        }
        let count = Double(to - from + 1)
        return sqrt(sumSq / count)
    }
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 20)
        let multiplier = parameters.values["multiplier"] ?? 2.0
        
        var widthValues: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period else {
            return KXIndicatorResult(values: widthValues, signals: signals)
        }
        
        // 提取收盘价数组
        let closes: [Double] = candles.map { Double(truncating: $0.close as NSDecimalNumber) }
        
        // 计算SMA
        let sma = calculateSMA(values: closes, period: period)
        
        // 计算布林带宽度 = (upper - lower) / middle * 100%
        let start = period - 1
        for i in start..<closes.count {
            let currentSma = sma[i - start]
            let sd = calculateStandardDeviation(values: closes, mean: currentSma, from: i - period + 1, to: i)
            
            let upper = currentSma + multiplier * sd
            let lower = currentSma - multiplier * sd
            let width = (upper - lower) / currentSma * 100
            
            widthValues[i] = width
            
            // 信号生成：带宽极值提示
            if i >= 1 {
                guard let prevWidth = widthValues[i-1] else { continue }
                let currentWidth = width
                
                // 极度收窄 → 可能行情即将爆发
                if currentWidth < 2 && prevWidth >= 2 {
                    signals.append(KXSignal(
                        index: i,
                        type: .none,
                        price: candles[i].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(values: widthValues, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultBBW: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 20,
                "multiplier": 2.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN14BBW: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-14", fileName: "KX-IN-14_BBW.swift", layer: .indicator,
        relativePath: "指标服务层/波动率指标/KX-IN-14_BBW.swift", duty: "BBW"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "BBW", passed: true, message: "BBW指标实现完成")
    }
}
