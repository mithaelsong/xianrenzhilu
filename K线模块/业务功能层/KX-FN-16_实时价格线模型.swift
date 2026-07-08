//
//  KX-FN-16_实时价格线模型.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：实时价格线状态模型
//  禁止事项：禁止UI绘制、数据库读写、网络请求
//

import Foundation


// MARK: - 价格方向

public enum KLPriceDirection: String, Codable, Sendable {
    case up
    case down
    case flat
    case unknown
}

// MARK: - 实时价格线状态

public struct KLRealtimePriceLineState: Codable, Sendable, Equatable {
    public var lastPrice: Decimal
    public var previousPrice: Decimal
    public var direction: KLPriceDirection
    /// 颜色 token（由外部解析，禁止写死NSColor）
    public var colorToken: String
    /// 格式化后的价格标签
    public var label: String
    /// 最后更新时间
    public var updatedAt: Date

    public init(lastPrice: Decimal = 0, previousPrice: Decimal = 0, direction: KLPriceDirection = .unknown, colorToken: String = "chart.priceLine.flat", label: String = "--", updatedAt: Date = Date()) {
        self.lastPrice = lastPrice
        self.previousPrice = previousPrice
        self.direction = direction
        self.colorToken = colorToken
        self.label = label
        self.updatedAt = updatedAt
    }
}

// MARK: - 实时价格线状态更新

public extension KLRealtimePriceLineState {
    /// 更新价格并重新计算方向和颜色token
    static func updated(from state: KLRealtimePriceLineState, newPrice: Decimal, formatter: ((Decimal) -> String)? = nil) throws -> KLRealtimePriceLineState {
        var updated = state
        // direction
        if newPrice > state.lastPrice {
            updated.direction = .up
            updated.colorToken = "chart.priceLine.up"
        } else if newPrice < state.lastPrice {
            updated.direction = .down
            updated.colorToken = "chart.priceLine.down"
        } else {
            updated.direction = .flat
            updated.colorToken = "chart.priceLine.flat"
        }
        updated.previousPrice = state.lastPrice
        updated.lastPrice = newPrice
        // label
        if let f = formatter {
            updated.label = f(newPrice)
        } else {
            updated.label = NSDecimalNumber(decimal: newPrice).stringValue
        }
        updated.updatedAt = Date()
        return updated
    }

    /// 创建初始状态
    static func initial(price: Decimal, formatter: ((Decimal) -> String)? = nil) -> KLRealtimePriceLineState {
        let label: String
        if let f = formatter {
            label = f(price)
        } else {
            label = NSDecimalNumber(decimal: price).stringValue
        }
        return KLRealtimePriceLineState(
            lastPrice: price,
            previousPrice: price,
            direction: .flat,
            colorToken: "chart.priceLine.flat",
            label: label
        )
    }

    /// 检查是否应更新（价格不同）
    static func shouldUpdate(state: KLRealtimePriceLineState, newPrice: Decimal) -> Bool {
        state.lastPrice != newPrice
    }

    /// 是否上涨
    var isUp: Bool { direction == .up }

    /// 是否下跌
    var isDown: Bool { direction == .down }

    /// 是否持平
    var isFlat: Bool { direction == .flat }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN16Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-16", fileName: "KX-FN-16_实时价格线模型.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-16_实时价格线模型.swift", duty: "实时价格线的模型和逻辑"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("实时价格线模型骨架校验通过")
        return KXHealthCheckItem(name: "实时价格线模型", passed: true, message: "已实现实时价格线模型和逻辑")
    }
}
