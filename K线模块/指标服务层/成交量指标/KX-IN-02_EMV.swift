//
//  KX-IN-02_EMV.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：EMV (Ease of Movement) 轻松移动指标计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct EaseOfMovementCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-02" }
    public var name: String { "EMV" }
    public var englishName: String { "Ease of Movement" }
    public var category: KXIndicatorCategory { .volume }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 14.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultEMV) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
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
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 14)
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period + 1 else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 计算每一根的emv
        var emv: [Double] = []
        for i in 1..<candles.count {
            let prevMid = (Double(truncating: candles[i-1].high as NSDecimalNumber) + Double(truncating: candles[i-1].low as NSDecimalNumber)) / 2.0
            let currMid = (Double(truncating: candles[i].high as NSDecimalNumber) + Double(truncating: candles[i].low as NSDecimalNumber)) / 2.0
            let volume = Double(truncating: candles[i].volume as NSDecimalNumber)
            let range = Double(truncating: candles[i].high as NSDecimalNumber) - Double(truncating: candles[i].low as NSDecimalNumber)
            
            if volume == 0 || range == 0 {
                emv.append(0)
                continue
            }
            
            let move = (currMid - prevMid) * range / volume
            emv.append(move * 1000) // 放大方便显示
        }
        
        // 计算sma(emv)
        let emvSma = calculateSMA(values: emv, period: period)
        
        // 填充结果生成信号
        let start = period
        for i in 0..<emvSma.count {
            let candleIdx = i + start
            guard candleIdx < candles.count else { continue }
            values[candleIdx] = emvSma[i]
            
            // 穿越零线信号
            if i > 0 && candleIdx > 0 {
                let prevEmv = emvSma[i-1]
                let currEmv = emvSma[i]
                
                // 上穿零线 → 放量上涨，买入
                if prevEmv <= 0 && currEmv > 0 {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .buy,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 下穿零线 → 放量下跌，卖出
                if prevEmv >= 0 && currEmv < 0 {
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
    static var defaultEMV: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 14
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX震荡指标KXIN02EMV: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-02", fileName: "KX-IN-02_EMV.swift", layer: .indicator,
        relativePath: "指标服务层/成交量指标/KX-IN-02_EMV.swift", duty: "EMV"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "EMV", passed: true, message: "EMV指标实现完成")
    }
}
