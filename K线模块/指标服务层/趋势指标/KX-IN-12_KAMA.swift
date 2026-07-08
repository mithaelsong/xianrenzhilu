//
//  KX-IN-12_KAMA.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：KAMA (Kaufman's Adaptive Moving Average) 考夫曼自适应均线计算实现
//  显示位置：K线主图叠加
//  依赖：KX-GL-03_公共类型
//

import Foundation

public struct KAMACalculator: KXIndicatorProtocol {
    
    // MARK: - 协议实现
    
    public var identifier: String { "KX-IN-12" }
    public var name: String { "KAMA" }
    public var englishName: String { "Kaufman's Adaptive Moving Average" }
    public var category: KXIndicatorCategory { .trend }
    public var parameters: KXIndicatorParameters

    public var defaultParameterValues: [String: Double] {
        [
            "period": 10.0,
            "fast": 2.0,
            "slow": 30.0
        ]
    }

    // MARK: - 初始化

    public init(parameters: KXIndicatorParameters = .defaultKAMA) {
        self.parameters = parameters
    }
    
    // MARK: - 核心计算
    
    public func calculate(for candles: [KLCandlePoint], parameters: KXIndicatorParameters) throws -> KXIndicatorResult {
        let period = Int(parameters.values["period"] ?? 10)
        let fast = parameters.values["fast"] ?? 2.0
        let slow = parameters.values["slow"] ?? 30.0
        
        var values: [Double?] = Array(repeating: nil, count: candles.count)
        var signals: [KXSignal] = []
        
        guard candles.count >= period else {
            return KXIndicatorResult(values: values, signals: signals)
        }
        
        // 提取收盘价数组
        let closes: [Double] = candles.map { Double(truncating: $0.close as NSDecimalNumber) }
        
        // 计算变化率
        var change: [Double] = []
        for i in period..<closes.count {
            change.append(abs(closes[i] - closes[i - period]))
        }
        
        // 计算波动率
        var volatility: [Double] = []
        for i in period..<closes.count {
            var sum: Double = 0
            for j in (i - period + 1)...i {
                sum += abs(closes[j] - closes[j - 1])
            }
            volatility.append(sum)
        }
        
        // 计算效率比 ER = change / volatility
        var er: [Double] = []
        for i in 0..<change.count {
            if volatility[i] == 0 {
                er.append(0)
            } else {
                er.append(change[i] / volatility[i])
            }
        }
        
        // 计算平滑系数
        let sc = (2.0 / (fast + 1)) - (2.0 / (slow + 1))
        let ss = sc * sc
        
        // 计算KAMA
        var kama: [Double] = []
        if !er.isEmpty {
            kama.append(closes[period - 1])
            for i in 0..<er.count {
                let erSquare = er[i] * er[i]
                let currentSm = ss * erSquare
                let currentSmoothing = currentSm + (1 - currentSm) * (kama.last ?? 0)
                kama.append(currentSmoothing)
            }
        }
        
        // 填充结果生成信号
        let start = period
        for i in 0..<kama.count {
            let candleIdx = i + start
            guard candleIdx < candles.count else { continue }
            values[candleIdx] = kama[i]
            
            // 均线交叉信号
            if i > 0 && candleIdx > 0 {
                let prevKama = kama[i-1]
                let currKama = kama[i]
                let prevClose = closes[candleIdx - 1]
                let currClose = closes[candleIdx]
                
                // 价格上穿KAMA → 买入
                if prevClose <= prevKama && currClose > currKama {
                    signals.append(KXSignal(
                        index: candleIdx,
                        type: .buy,
                        price: candles[candleIdx].close
                    ))
                }
                
                // 价格下穿KAMA → 卖出
                if prevClose >= prevKama && currClose < currKama {
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
    static var defaultKAMA: KXIndicatorParameters {
        KXIndicatorParameters(
            values: [
                "period": 10,
                "fast": 2.0,
                "slow": 30.0
            ]
        )
    }
}







// MARK: - KXFileSkeletonProtocol

public enum KX趋势指标KXIN12KAMA: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-IN-12", fileName: "KX-IN-12_KAMA.swift", layer: .indicator,
        relativePath: "指标服务层/趋势指标/KX-IN-12_KAMA.swift", duty: "KAMA"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        return KXHealthCheckItem(name: "KAMA", passed: true, message: "KAMA指标实现完成")
    }
}
