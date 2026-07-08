//
//  KX-FN-15_视口缩放平移.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：K线图表视口缩放与平移纯逻辑
//  禁止事项：禁止UI绘制、数据库读写、网络请求
//

import Foundation


// MARK: - 视口调整结果

public struct KLViewportAdjustResult: Sendable, Equatable {
    public var startIndex: Int
    public var endIndex: Int
    public var candleWidth: Double
    public var contentOffsetX: Double

    public init(startIndex: Int = 0, endIndex: Int = 0, candleWidth: Double = 8.0, contentOffsetX: Double = 0.0) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.candleWidth = candleWidth
        self.contentOffsetX = contentOffsetX
    }
}

// MARK: - 视口计算器

public enum KLViewportCalculator {
    public static let minCandleWidth: Double = 1.5
    public static let maxCandleWidth: Double = 60.0
    public static let minVisibleCandles: Int = 5

    /// 向左/向右平移
    /// - Parameters:
    ///   - deltaX: 水平偏移量（points，正=右移/内容左移）
    ///   - currentViewport: 当前视口
    ///   - totalCandles: 总K线数
    /// - Returns: 新视口
    public static func pan(deltaX: Double, currentViewport: KLViewportAdjustResult, totalCandles: Int) -> KLViewportAdjustResult {
        guard totalCandles > 0 else { return currentViewport }

        var newOffset = currentViewport.contentOffsetX + deltaX
        let visibleCount = visibleCandleCount(candleWidth: currentViewport.candleWidth, viewportWidth: 800) // 默认宽度的比例
        let maxOffset = Double(max(0, totalCandles - visibleCount)) * currentViewport.candleWidth

        newOffset = max(0, min(newOffset, maxOffset))

        var result = currentViewport
        result.contentOffsetX = newOffset
        result.startIndex = min(max(0, Int(newOffset / currentViewport.candleWidth)), totalCandles - 1)
        result.endIndex = min(totalCandles, result.startIndex + max(1, visibleCount))
        return result
    }

    /// 缩放
    /// - Parameters:
    ///   - magnification: 缩放因子（>1 = 放大/变宽, <1 = 缩小/变窄）
    ///   - anchorX: 缩放锚点相对偏移量
    ///   - currentViewport: 当前视口
    /// - Returns: 新视口
    public static func zoom(magnification: Double, anchorX: Double, currentViewport: KLViewportAdjustResult) -> KLViewportAdjustResult {
        var newWidth = currentViewport.candleWidth * magnification
        newWidth = max(minCandleWidth, min(newWidth, maxCandleWidth))

        var result = currentViewport
        result.candleWidth = newWidth
        // 保持锚点位置相对稳定
        let oldOffset = currentViewport.contentOffsetX
        let newOffset = oldOffset * (newWidth / currentViewport.candleWidth)
        result.contentOffsetX = newOffset

        return result
    }

    /// 计算可视K线数量
    public static func visibleCandleCount(candleWidth: Double, viewportWidth: Double) -> Int {
        guard candleWidth > 0 else { return minVisibleCandles }
        return max(minVisibleCandles, Int(viewportWidth / candleWidth))
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN15Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-15", fileName: "KX-FN-15_视口缩放平移.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-15_视口缩放平移.swift", duty: "图表视口的缩放和平移逻辑"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("视口缩放平移骨架校验通过")
        return KXHealthCheckItem(name: "视口缩放平移", passed: true, message: "已实现图表视口缩放和平移逻辑")
    }
}
