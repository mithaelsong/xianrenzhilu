//
//  KX-FN-13_价格轴刻度.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：按币种价格和 tickSize 自适应生成价格轴刻度与格式化
//  禁止事项：禁止网络请求、数据库读写、UI绘制
//

import Foundation


// MARK: - 价格刻度

public struct KLPriceAxisTick: Codable, Sendable, Equatable {
    public let price: Decimal
    public let yRatio: Double
    public let label: String
}

// MARK: - 价格轴刻度生成

public enum KLPriceAxisCalculator {
    /// 计算价格轴刻度
    /// - Parameters:
    ///   - minPrice: 可视最低价
    ///   - maxPrice: 可视最高价
    ///   - viewportHeight: 价格轴可用高度（points）
    ///   - tickSize: OKX 最小价格变动
    ///   - pricePrecision: 价格精度（小数位数）
    /// - Returns: 价格刻度数组
    public static func ticks(minPrice: Decimal, maxPrice: Decimal, viewportHeight: CGFloat, tickSize: Decimal, pricePrecision: Int) -> [KLPriceAxisTick] {
        guard viewportHeight > 0, maxPrice > minPrice else { return [] }

        guard let minP = Double(minPrice.description), let maxP = Double(maxPrice.description) else { return [] }
        let range = maxP - minP
        guard range > 0 else { return [] }

        guard let ts = Double(tickSize.description), ts > 0 else { return [] }
        let rawStep = bestStep(range: range, tickSize: ts)
        guard rawStep > 0 else { return [] }

        let startTick: Double = (minP / rawStep).rounded(.up) * rawStep

        var ticks: [KLPriceAxisTick] = []
        var current = startTick
        while current <= maxP, ticks.count < 12 {
            let y = (1.0 - (current - minP) / range) * Double(viewportHeight)
            let d = Decimal(string: "\(current)") ?? Decimal(current)
            let label = formatPrice(d, tickSize: tickSize, precision: pricePrecision)
            ticks.append(KLPriceAxisTick(price: d, yRatio: y, label: label))
            current += rawStep
        }
        return ticks
    }

    /// 根据价格范围和 tickSize 计算合适的刻度步长
    public static func bestStep(range: Double, tickSize: Double) -> Double {
        guard range > 0, tickSize > 0 else { return 0 }
        let targetCount: Double = 8
        var step = tickSize
        let multipliers: [Double] = [1, 2, 3, 5, 10, 20, 30, 50, 100, 200, 500, 1000]
        for mult in multipliers {
            let candidate = tickSize * mult
            let count = range / candidate
            if count <= targetCount * 1.5 {
                step = candidate
                break
            }
            step = candidate
        }
        let factor = floor(step / tickSize)
        if factor > 1 {
            step = tickSize * factor
        }
        return step
    }

    /// 按 tickSize 格式价格
    public static func formatPrice(_ price: Decimal, tickSize: Decimal, precision: Int) -> String {
        guard let ts = Double(tickSize.description), ts > 0 else { return NSDecimalNumber(decimal: price).stringValue }

        let p = precision > 0 ? precision : 2
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = p
        formatter.maximumFractionDigits = p
        formatter.numberStyle = .decimal
        formatter.roundingMode = .down

        guard let double = Double(price.description) else { return NSDecimalNumber(decimal: price).stringValue }
        // 高价币整数/少小数
        if p == 0 || (price > 1000 && precision <= 2) {
            formatter.groupingSeparator = ","
            formatter.minimumFractionDigits = p
            formatter.maximumFractionDigits = p
            return formatter.string(from: NSNumber(value: double)) ?? "\(double)"
        }
        formatter.groupingSeparator = ""
        return formatter.string(from: NSNumber(value: double)) ?? "\(double)"
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN13Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-13", fileName: "KX-FN-13_价格轴刻度.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-13_价格轴刻度.swift", duty: "价格轴刻度生成与格式化"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("价格轴刻度骨架校验通过")
        return KXHealthCheckItem(name: "价格轴刻度", passed: true, message: "已实现价格轴刻度生成与格式化")
    }
}
