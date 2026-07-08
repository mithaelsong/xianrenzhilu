//
//  KX-IN-09_ROC.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：ROC（变动率指标）计算实现
//  显示位置：K线副图
//  依赖：KX-GL-03_公共类型定义
//

import Foundation


// MARK: - ROC 计算器

public struct ROCCalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-09" }
    public var name: String { "ROC" }
    public var englishName: String { "Rate of Change" }
    public var category: KXIndicatorCategory { .oscillator }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 12.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultROC) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 12)
        guard candles.count > period else {
            return KXIndicatorResult()
        }
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        for i in period..<candles.count {
            let currentClose = Double(truncating: NSDecimalNumber(decimal: candles[i].close))
            let prevClose = Double(truncating: NSDecimalNumber(decimal: candles[i - period].close))
            
            if prevClose == 0 {
                continue
            }
            
            let roc = ((currentClose - prevClose) / prevClose) * 100
            values[i] = roc
            
            // 穿越零轴信号
            let prevROC = values[i - 1] ?? 0
            if prevROC <= 0 && roc > 0 {
                signals.append(KXSignal(
                    index: i,
                    type: .buy,
                    price: candles[i].close
                ))
            }
            if prevROC >= 0 && roc < 0 {
                signals.append(KXSignal(
                    index: i,
                    type: .sell,
                    price: candles[i].close
                ))
            }
            
            // 超买超卖
            if roc > 10 {
                signals.append(KXSignal(
                    index: i,
                    type: .strongSell,
                    price: candles[i].close
                ))
            }
            if roc < -10 {
                signals.append(KXSignal(
                    index: i,
                    type: .strongBuy,
                    price: candles[i].close
                ))
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
    static var defaultROC: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 12
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN09ROC: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-09", fileName: "KX-IN-09_ROC.swift", layer: .indicator,
        relativePath: "指标服务层/震荡指标/KX-IN-09_ROC.swift", duty: "ROC"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "ROC", passed: true, message: "ROC指标实现完成")
    }
}
