//
//  KX-FN-37_指标交易信号生成器.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：提供通用指标交易信号规则（穿越、突破、金叉死叉、背离），不依赖具体指标
//  禁止事项：禁止 UI 绘制、禁止直接操作 K线视图、禁止维护业务状态
//

import Foundation

public enum KXSignalDirection: Sendable {
    case up
    case down
}

public enum KXIndicatorSignalGenerator {

    // MARK: - 序列对齐

    /// 把按时间排列的指标点，对齐到 K 线序列的对应索引上，方便按索引做穿越/背离判断。
    public static func alignIndicatorValues(
        _ values: [KLIndicatorPoint],
        to candles: [KLCandlePoint]
    ) -> [Decimal?] {
        guard !candles.isEmpty else { return [] }
        var result: [Decimal?] = Array(repeating: nil, count: candles.count)
        var valueIndex = 0
        for (candleIndex, candle) in candles.enumerated() {
            while valueIndex < values.count && values[valueIndex].time < candle.openTime {
                valueIndex += 1
            }
            if valueIndex < values.count && values[valueIndex].time == candle.openTime {
                result[candleIndex] = values[valueIndex].value
            }
        }
        return result
    }

    // MARK: - 价格穿越指标线

    /// 价格（默认收盘价）穿越指标线时产生信号。
    /// direction = .up：前一根收盘价 <= 指标值，当前收盘价 > 指标值。
    /// direction = .down：前一根收盘价 >= 指标值，当前收盘价 < 指标值。
    public static func priceCrossSignals(
        candles: [KLCandlePoint],
        indicatorValues: [Decimal?],
        direction: KXSignalDirection,
        signalType: KXSignalType,
        useClose: Bool = true
    ) -> [KXSignal] {
        guard candles.count == indicatorValues.count, candles.count >= 2 else { return [] }
        var signals: [KXSignal] = []
        for i in 1..<candles.count {
            guard let prevValue = indicatorValues[i - 1], let currValue = indicatorValues[i] else { continue }
            let prevPrice = price(for: candles[i - 1], useClose: useClose)
            let currPrice = price(for: candles[i], useClose: useClose)

            let triggered: Bool
            switch direction {
            case .up:
                triggered = prevPrice <= prevValue && currPrice > currValue
            case .down:
                triggered = prevPrice >= prevValue && currPrice < currValue
            }

            if triggered {
                signals.append(KXSignal(
                    index: i,
                    type: signalType,
                    price: currPrice,
                    time: candles[i].openTime
                ))
            }
        }
        return signals
    }

    // MARK: - 价格突破阈值

    /// 价格突破固定阈值，方向 .up：上穿阈值；.down：下穿阈值。
    public static func priceBreakSignals(
        candles: [KLCandlePoint],
        threshold: Decimal,
        direction: KXSignalDirection,
        signalType: KXSignalType,
        useClose: Bool = true
    ) -> [KXSignal] {
        guard candles.count >= 2 else { return [] }
        var signals: [KXSignal] = []
        for i in 1..<candles.count {
            let prevPrice = price(for: candles[i - 1], useClose: useClose)
            let currPrice = price(for: candles[i], useClose: useClose)
            let triggered: Bool
            switch direction {
            case .up:
                triggered = prevPrice <= threshold && currPrice > threshold
            case .down:
                triggered = prevPrice >= threshold && currPrice < threshold
            }
            if triggered {
                signals.append(KXSignal(index: i, type: signalType, price: currPrice, time: candles[i].openTime))
            }
        }
        return signals
    }

    // MARK: - 指标线突破阈值

    /// 指标序列突破固定阈值，例如 RSI 上穿 30 或下穿 70。
    /// 信号 price 使用当前指标值，以便在副图（sub pane）正确渲染。
    public static func indicatorBreakSignals(
        candles: [KLCandlePoint],
        indicatorValues: [Decimal?],
        threshold: Decimal,
        direction: KXSignalDirection,
        signalType: KXSignalType
    ) -> [KXSignal] {
        guard candles.count == indicatorValues.count, candles.count >= 2 else { return [] }
        var signals: [KXSignal] = []
        for i in 1..<candles.count {
            guard let prevValue = indicatorValues[i - 1], let currValue = indicatorValues[i] else { continue }
            let triggered: Bool
            switch direction {
            case .up:
                triggered = prevValue <= threshold && currValue > threshold
            case .down:
                triggered = prevValue >= threshold && currValue < threshold
            }
            if triggered {
                signals.append(KXSignal(index: i, type: signalType, price: currValue, time: candles[i].openTime))
            }
        }
        return signals
    }

    // MARK: - 双线金叉死叉

    /// 快线穿越慢线：.up 为金叉，.down 为死叉。
    /// 信号 price 使用当前慢线值，以便与指标线同 pane 渲染。
    public static func dualCrossSignals(
        candles: [KLCandlePoint],
        fastValues: [Decimal?],
        slowValues: [Decimal?],
        direction: KXSignalDirection,
        signalType: KXSignalType
    ) -> [KXSignal] {
        guard candles.count == fastValues.count,
              candles.count == slowValues.count,
              candles.count >= 2 else { return [] }
        var signals: [KXSignal] = []
        for i in 1..<candles.count {
            guard let prevFast = fastValues[i - 1], let currFast = fastValues[i],
                  let prevSlow = slowValues[i - 1], let currSlow = slowValues[i] else { continue }
            let triggered: Bool
            switch direction {
            case .up:
                triggered = prevFast <= prevSlow && currFast > currSlow
            case .down:
                triggered = prevFast >= prevSlow && currFast < currSlow
            }
            if triggered {
                signals.append(KXSignal(
                    index: i,
                    type: signalType,
                    price: currSlow,
                    time: candles[i].openTime
                ))
            }
        }
        return signals
    }

    // MARK: - 背离

    /// 顶背离/底背离检测（简化版）：在指定窗口内找价格与指标的局部极值。
    /// direction = .down 检测顶背离（价格新高、指标未新高），通常视为 sell 信号。
    /// direction = .up 检测底背离（价格新低、指标未新低），通常视为 buy 信号。
    public static func divergenceSignals(
        candles: [KLCandlePoint],
        indicatorValues: [Decimal?],
        direction: KXSignalDirection,
        signalType: KXSignalType,
        window: Int = 5,
        useClose: Bool = true
    ) -> [KXSignal] {
        guard candles.count == indicatorValues.count, candles.count >= window * 2 + 2 else { return [] }
        var signals: [KXSignal] = []

        func isLocalHigh(at index: Int, values: [Decimal?]) -> Bool {
            guard let current = values[index] else { return false }
            let half = window / 2
            let start = max(0, index - half)
            let end = min(values.count - 1, index + half)
            for j in start...end where j != index {
                guard let v = values[j] else { return false }
                if v >= current { return false }
            }
            return true
        }

        func isLocalLow(at index: Int, values: [Decimal?]) -> Bool {
            guard let current = values[index] else { return false }
            let half = window / 2
            let start = max(0, index - half)
            let end = min(values.count - 1, index + half)
            for j in start...end where j != index {
                guard let v = values[j] else { return false }
                if v <= current { return false }
            }
            return true
        }

        var priceExtrema: [Int] = []
        var indicatorExtrema: [Int] = []
        let prices: [Decimal?] = candles.map { price(for: $0, useClose: useClose) }

        for i in window..<(candles.count - window) {
            switch direction {
            case .down:
                if isLocalHigh(at: i, values: prices), isLocalHigh(at: i, values: indicatorValues) {
                    priceExtrema.append(i)
                    indicatorExtrema.append(i)
                }
            case .up:
                if isLocalLow(at: i, values: prices), isLocalLow(at: i, values: indicatorValues) {
                    priceExtrema.append(i)
                    indicatorExtrema.append(i)
                }
            }
        }

        guard priceExtrema.count >= 2 else { return [] }
        for i in 1..<priceExtrema.count {
            let prevPriceIndex = priceExtrema[i - 1]
            let currPriceIndex = priceExtrema[i]
            let prevIndicatorIndex = indicatorExtrema[i - 1]
            let currIndicatorIndex = indicatorExtrema[i]

            guard let prevPrice = prices[prevPriceIndex],
                  let currPrice = prices[currPriceIndex],
                  let prevIndicator = indicatorValues[prevIndicatorIndex],
                  let currIndicator = indicatorValues[currIndicatorIndex] else { continue }

            let diverged: Bool
            switch direction {
            case .down:
                // 价格创新高，指标没有创新高 -> 顶背离
                diverged = currPrice > prevPrice && currIndicator <= prevIndicator
            case .up:
                // 价格创新低，指标没有创新低 -> 底背离
                diverged = currPrice < prevPrice && currIndicator >= prevIndicator
            }
            if diverged {
                signals.append(KXSignal(
                    index: currPriceIndex,
                    type: signalType,
                    price: currPrice
                ))
            }
        }
        return signals
    }

    // MARK: - 聚合

    /// 对多个信号源按索引去重并合并，保留最早出现的信号类型。
    public static func merge(_ signalGroups: [KXSignal]...) -> [KXSignal] {
        var seen: Set<Int> = []
        var result: [KXSignal] = []
        for group in signalGroups {
            for signal in group {
                if seen.insert(signal.index).inserted {
                    result.append(signal)
                }
            }
        }
        return result.sorted { $0.index < $1.index }
    }

    // MARK: - Helpers

    private static func price(for candle: KLCandlePoint, useClose: Bool) -> Decimal {
        useClose ? candle.close : candle.open
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN37Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-37", fileName: "KX-FN-37_指标交易信号生成器.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-37_指标交易信号生成器.swift", duty: "通用指标交易信号规则（穿越、突破、金叉死叉、背离）"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("指标交易信号生成器骨架校验通过")
        return KXHealthCheckItem(name: "指标交易信号生成器", passed: true, message: "已实现通用指标交易信号生成器")
    }
}
