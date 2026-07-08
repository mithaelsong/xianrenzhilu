//
//  KX-IN-13_VolumeProfile.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：Volume Profile（成交量分布）计算实现
//  显示位置：K线主图侧边
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct VolumeProfileCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-13" }
    public var name: String { "成交量分布" }
    public var englishName: String { "Volume Profile" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "numBins": 10.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultVolumeProfile) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let numBins = Int(parameters.values["numBins"] ?? 10)
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= 10 else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 找出价格范围
        var minPrice = Double.greatestFiniteMagnitude
        var maxPrice = -Double.greatestFiniteMagnitude
        var totalVolume: Double = 0
        
        for candle in candles {
            let low = Double(truncating: candle.low as NSDecimalNumber)
            let high = Double(truncating: candle.high as NSDecimalNumber)
            let vol = Double(truncating: candle.volume as NSDecimalNumber)
            minPrice = min(minPrice, low)
            maxPrice = max(maxPrice, high)
            totalVolume += vol
        }
        
        // 按价格区间分箱
        let binSize = (maxPrice - minPrice) / Double(numBins)
        var bins: [Double] = Array(repeating: 0, count: numBins)
        
        for candle in candles {
            let low = Double(truncating: candle.low as NSDecimalNumber)
            let high = Double(truncating: candle.high as NSDecimalNumber)
            let vol = Double(truncating: candle.volume as NSDecimalNumber)
            
            // 计算成交量分布到区间
            let startBin = max(0, Int(floor((low - minPrice) / binSize)))
            let endBin = min(numBins - 1, Int(ceil((high - minPrice) / binSize)))
            
            // 均匀分配成交量到区间
            let binRange = (endBin - startBin + 1)
            let volPerBin = vol / Double(binRange)
            for bin in startBin...endBin {
                bins[bin] += volPerBin
            }
        }
        
        // 找到POC（Point of Control，最大成交量价格区间）
        if let maxVolumeBin = bins.enumerated().max(by: { $0.element < $1.element })?.offset {
            let pocPrice = minPrice + (Double(maxVolumeBin) + 0.5) * binSize
            // POC作为当前结果（只在最后一根有效）
            values[candles.count - 1] = pocPrice
            
            // POC通常是重要支撑阻力，生成信号
            let lastCandle = candles[candles.count - 1]
            let lastClose = Double(truncating: lastCandle.close as NSDecimalNumber)
            
            if abs(lastClose - pocPrice) < binSize * 0.5 {
                // 价格接近POC，关键支撑阻力位 → 无方向信号，使用none
                signals.append(KXSignal(
                    index: candles.count - 1,
                    type: .none,
                    price: lastCandle.close
                ))
            }
        }
        
        return KXIndicatorResult(values: values, signals: signals)
    }
}

// MARK: - 默认参数

public extension KXIndicatorParameters {
    static var defaultVolumeProfile: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "numBins": 10
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN13VolumeProfile: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-13", fileName: "KX-IN-13_VolumeProfile.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-13_VolumeProfile.swift", duty: "VolumeProfile"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "VolumeProfile", passed: true, message: "VolumeProfile指标实现完成")
    }
}
