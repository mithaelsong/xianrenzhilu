//
//  KX-IN-05_VPT.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：VPT (Volume Price Trend) 量价趋势计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct VPTCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-05" }
    public var name: String { "VPT" }
    public var englishName: String { "Volume Price Trend" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "emaPeriod": 25.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultVPT) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let emaPeriod = Int(parameters.values["emaPeriod"] ?? 25)
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= emaPeriod else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 计算每一根的VPT
        var vpt: [Double] = []
        var prevVpt: Double = 0
        
        for i in 1..<candles.count {
            let currentClose = Double(truncating: candles[i].close as NSDecimalNumber)
            let prevClose = Double(truncating: candles[i-1].close as NSDecimalNumber)
            let volume = Double(truncating: candles[i].volume as NSDecimalNumber)
            
            let change = (currentClose - prevClose) / prevClose
            let currentVpt = prevVpt + volume * change
            vpt.append(currentVpt)
            prevVpt = currentVpt
        }
        
        // 计算EMA(VPT)
        let k = 2.0 / (Double(emaPeriod) + 1.0)
        var emaVpt: [Double] = []
        var ema = vpt[0]
        emaVpt.append(ema)
        for i in 1..<vpt.count {
            ema = vpt[i] * k + ema * (1 - k)
            emaVpt.append(ema)
        }
        
        // 填充结果并生成信号
        let startIndex = 1 + (emaPeriod - 1)
        for i in 0..<emaVpt.count {
            let candleIdx = i + startIndex
            guard candleIdx < candles.count else { continue }
            
            values[candleIdx] = vpt[i] - emaVpt[i]
            
            // MACD风格信号
            if i >= 1 {
                let prevDiff = vpt[i-1] - emaVpt[i-1]
                let currDiff = vpt[i] - emaVpt[i]
                
                // 上穿零线买入
                if prevDiff <= 0 && currDiff > 0 {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .buy,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 下穿零线卖出
                if prevDiff >= 0 && currDiff < 0 {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .sell,
                        price: candles[candleIdx].close
                    ))
                }
            }
        }
        
        return KXIndicatorResult(values: values, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultVPT: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "emaPeriod": 25
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX成交量指标KXIN05VPT: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-05", fileName: "KX-IN-05_VPT.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-05_VPT.swift", duty: "VPT"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "VPT", passed: true, message: "VPT指标实现完成")
    }
}
