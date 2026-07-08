//
//  KX-UI-02_虚拟滚动适配.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：为 UI 虚拟滚动提供可视窗口数据适配
//  禁止事项：禁止画 UI、禁止请求网络、禁止读写数据库、禁止实现虚拟滚动管理器
//

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - 虚拟滚动条目

/// 虚拟滚动中的单一条目，映射为一根 K 线。
public struct KXUI02VirtualScrollItem: Codable, Equatable, Sendable {
    /// 条目在虚拟列表中的绝对位置（不随缓冲区偏移变化）
    public let index: Int
    /// 该条目对应的 K 线数据
    public let candle: KLCandlePoint
    /// 条目在滚动视图中距离 contentOffset 的 x 偏移（像素）
    public let originX: Double
    /// 条目宽度（像素），恒定等于 candleWidth
    public let width: Double
    /// 该条目是否完全可见
    public let isFullyVisible: Bool
    /// 该条目是否部分可见（首尾边缘）
    public let isPartiallyVisible: Bool

    public init(index: Int, candle: KLCandlePoint, originX: Double, width: Double, isFullyVisible: Bool, isPartiallyVisible: Bool) {
        self.index = index
        self.candle = candle
        self.originX = originX
        self.width = width
        self.isFullyVisible = isFullyVisible
        self.isPartiallyVisible = isPartiallyVisible
    }
}

// MARK: - 可见范围

/// 虚拟滚动当前位置下的可见范围摘要。
public struct KXUI02VisibleRange: Codable, Equatable, Sendable {
    /// 第一个可见 K 线在完整序列中的索引
    public let firstVisibleIndex: Int
    /// 最后一个可见 K 线在完整序列中的索引
    public let lastVisibleIndex: Int
    /// 从完整序列中截取的可见部分
    public let visibleIndices: [Int]
    /// 可见窗口缓冲区起始索引（含缓冲）
    public let bufferStartIndex: Int
    /// 可见窗口缓冲区结束索引（含缓冲）
    public let bufferEndIndex: Int
    /// 滑动方向
    public let scrollDirection: KXUI02ScrollDirection

    public init(firstVisibleIndex: Int, lastVisibleIndex: Int, visibleIndices: [Int], bufferStartIndex: Int, bufferEndIndex: Int, scrollDirection: KXUI02ScrollDirection) {
        self.firstVisibleIndex = firstVisibleIndex
        self.lastVisibleIndex = lastVisibleIndex
        self.visibleIndices = visibleIndices
        self.bufferStartIndex = bufferStartIndex
        self.bufferEndIndex = bufferEndIndex
        self.scrollDirection = scrollDirection
    }
}

// MARK: - 滑动方向

public enum KXUI02ScrollDirection: String, Codable, Sendable, CaseIterable {
    /// 左滑（看更早的 K 线）
    case backward
    /// 右滑（看更新的 K 线）
    case forward
    /// 无滑动（静止）
    case stationary
}

// MARK: - 条目计算器

/// 基于 KLVisibleWindow 提供 item-size 计算、首尾可见索引计算、滑动方向估算。
public struct KXUI02ItemCalculator: Sendable {
    /// 每根 K 线的像素宽度
    public let candleWidth: Double
    /// 视口总像素宽度
    public let viewportWidth: Double
    /// 当前 contentOffset.x（像素）
    public let contentOffsetX: Double
    /// 缓冲系数（额外加载的条目倍数，默认 0.5 即前后各加载半个视口）
    public let bufferFactor: Double

    public init(candleWidth: Double, viewportWidth: Double, contentOffsetX: Double = 0, bufferFactor: Double = 0.5) {
        self.candleWidth = candleWidth
        self.viewportWidth = viewportWidth
        self.contentOffsetX = contentOffsetX
        self.bufferFactor = max(0, bufferFactor)
    }

    // MARK: - Item-Size 计算

    /// 单条目宽度（即 candleWidth）
    @inlinable
    public var itemSize: Double { candleWidth }

    /// 总内容宽度 = 条目数 × 条目宽度
    public func totalContentWidth(itemCount: Int) -> Double {
        Double(itemCount) * candleWidth
    }

    /// 当前可见条目数（至少为 1）
    public var visibleItemCount: Int {
        max(1, Int(ceil(viewportWidth / candleWidth)))
    }

    /// 带缓冲的可见条目数
    public var bufferedItemCount: Int {
        max(1, Int(ceil(viewportWidth * (1 + 2 * bufferFactor) / candleWidth)))
    }

    // MARK: - 可见索引计算

    /// 根据 contentOffsetX 计算第一个可见条目的索引。
    /// 按 floor 取整：只要偏移量覆盖了该条目的一部分，就算可见。
    public var firstVisibleIndex: Int {
        max(0, Int(floor(contentOffsetX / candleWidth)))
    }

    /// 根据 contentOffsetX 和视口宽度计算最后一个可见条目的索引（含）。
    public var lastVisibleIndex: Int {
        max(0, Int(ceil((contentOffsetX + viewportWidth) / candleWidth)) - 1)
    }

    /// 最左端第一条数据的索引（偏移 0 处），始终为 0。
    public var firstIndex: Int { 0 }

    /// 可见范围内的所有索引（含首尾）。
    public var visibleIndices: [Int] {
        let first = firstVisibleIndex
        let last = lastVisibleIndex
        guard first <= last else { return [] }
        return Array(first...last)
    }

    /// 带缓冲的起始索引（左扩 bufferFactor 个视口宽度 / candleWidth）。
    public var bufferStartIndex: Int {
        max(0, firstVisibleIndex - Int(ceil(viewportWidth * bufferFactor / candleWidth)))
    }

    /// 带缓冲的结束索引（右扩 bufferFactor 个视口宽度 / candleWidth）。
    public var bufferEndIndex: Int {
        lastVisibleIndex + Int(ceil(viewportWidth * bufferFactor / candleWidth))
    }

    /// 根据完整数据总量约束的缓冲起止索引。
    public func clampedBufferStartIndex(totalCount: Int) -> Int {
        min(max(0, bufferStartIndex), max(0, totalCount - 1))
    }

    public func clampedBufferEndIndex(totalCount: Int) -> Int {
        min(bufferEndIndex, max(0, totalCount - 1))
    }

    /// 可见窗口条目数（至少为 1）
    public func clampedVisibleItemCount(totalCount: Int) -> Int {
        let first = min(firstVisibleIndex, max(0, totalCount - 1))
        let last = min(lastVisibleIndex, max(0, totalCount - 1))
        return max(1, last - first + 1)
    }

    // MARK: - 滑动方向估算

    /// 根据新旧 contentOffsetX 估算滑动方向。
    /// - Parameters:
    ///   - previousOffsetX: 上一次的 contentOffset.x
    ///   - threshold: 变化阈值（像素），小于此值视为静止
    /// - Returns: 滑动方向
    public func estimateScrollDirection(previousOffsetX: Double, threshold: Double = 1) -> KXUI02ScrollDirection {
        let delta = contentOffsetX - previousOffsetX
        if abs(delta) < threshold {
            return .stationary
        }
        return delta > 0 ? .forward : .backward
    }

    // MARK: - 根据 index 获取 x 偏移

    /// 计算指定索引的条目在 contentOffset 中的 originX。
    @inlinable
    public func originX(for index: Int) -> Double {
        Double(index) * candleWidth
    }

    /// 计算中心 x 偏移（用于判断哪个条目在正中）。
    @inlinable
    public func centerXInViewport(for index: Int) -> Double {
        originX(for: index) + candleWidth * 0.5 - contentOffsetX
    }

    // MARK: - 可见性判断

    /// 指定条目是否完全可见（左右边缘均在视口内）。
    public func isFullyVisible(index: Int) -> Bool {
        let origin = originX(for: index)
        let adjustedOrigin = origin - contentOffsetX
        return adjustedOrigin >= 0 && adjustedOrigin + candleWidth <= viewportWidth
    }

    /// 指定条目是否部分可见（首尾边缘条目）。
    public func isPartiallyVisible(index: Int) -> Bool {
        !isFullyVisible(index: index) && (index == firstVisibleIndex || index == lastVisibleIndex)
    }

    // MARK: - 效率摘要

    /// 当前计算器配置下的效率摘要。
    public var efficiencySummary: KXUI02EfficiencySummary {
        let visible = visibleItemCount
        let buffered = bufferedItemCount
        let overheadRatio = buffered > 0 ? Double(buffered - visible) / Double(buffered) : 0
        return KXUI02EfficiencySummary(
            candleWidth: candleWidth,
            viewportWidth: viewportWidth,
            bufferFactor: bufferFactor,
            visibleItemCount: visible,
            bufferedItemCount: buffered,
            overheadRatio: overheadRatio,
            firstVisibleIndex: firstVisibleIndex,
            lastVisibleIndex: lastVisibleIndex
        )
    }

    /// 生成新的 ItemCalculator 并更新 contentOffsetX。
    public func withContentOffsetX(_ newOffsetX: Double) -> KXUI02ItemCalculator {
        KXUI02ItemCalculator(
            candleWidth: candleWidth,
            viewportWidth: viewportWidth,
            contentOffsetX: newOffsetX,
            bufferFactor: bufferFactor
        )
    }

    /// 生成新的 ItemCalculator 并更新 viewportWidth。
    public func withViewportWidth(_ newViewportWidth: Double) -> KXUI02ItemCalculator {
        KXUI02ItemCalculator(
            candleWidth: candleWidth,
            viewportWidth: newViewportWidth,
            contentOffsetX: contentOffsetX,
            bufferFactor: bufferFactor
        )
    }
}

// MARK: - 效率摘要

/// 虚拟滚动当前状态的效率摘要。
public struct KXUI02EfficiencySummary: Codable, Equatable, Sendable {
    /// 每根 K 线的像素宽度
    public let candleWidth: Double
    /// 视口宽度
    public let viewportWidth: Double
    /// 缓冲系数
    public let bufferFactor: Double
    /// 实际可见条目数
    public let visibleItemCount: Int
    /// 带缓冲的条目数
    public let bufferedItemCount: Int
    /// 缓冲开销占比（越小越高效）
    public let overheadRatio: Double
    /// 第一个可见条目索引
    public let firstVisibleIndex: Int
    /// 最后一个可见条目索引
    public let lastVisibleIndex: Int

    public init(candleWidth: Double, viewportWidth: Double, bufferFactor: Double, visibleItemCount: Int, bufferedItemCount: Int, overheadRatio: Double, firstVisibleIndex: Int, lastVisibleIndex: Int) {
        self.candleWidth = candleWidth
        self.viewportWidth = viewportWidth
        self.bufferFactor = bufferFactor
        self.visibleItemCount = visibleItemCount
        self.bufferedItemCount = bufferedItemCount
        self.overheadRatio = overheadRatio
        self.firstVisibleIndex = firstVisibleIndex
        self.lastVisibleIndex = lastVisibleIndex
    }
}

// MARK: - 条目生成器

/// 根据 KLVisibleWindow 和 KLCandlePoint 数组生成虚拟滚动条目序列。
public struct KXUI02ItemGenerator: Sendable {
    public let candles: [KLCandlePoint]
    public let window: KLVisibleWindow
    public let calculator: KXUI02ItemCalculator

    public init(candles: [KLCandlePoint], window: KLVisibleWindow, calculator: KXUI02ItemCalculator) {
        self.candles = candles
        self.window = window
        self.calculator = calculator
    }

    // MARK: - 条目生成

    /// 生成当前可见窗口内所有虚拟滚动条目（含缓冲）。
    public var visibleItems: [KXUI02VirtualScrollItem] {
        let startIndex = window.indexRange.startIndex
        let endIndex = window.indexRange.endIndex
        guard startIndex <= endIndex, !candles.isEmpty else { return [] }

        let bufferStart = calculator.bufferStartIndex
        let bufferEnd = calculator.bufferEndIndex

        return candles.compactMap { candle -> KXUI02VirtualScrollItem? in
            // 计算条目的相对索引
            let rawIndex: Int
            if let candleIndex = candles.firstIndex(where: { $0.openTime >= candle.openTime && $0.symbol == candle.symbol && $0.timeframe == candle.timeframe }) {
                rawIndex = startIndex + candleIndex
            } else {
                rawIndex = startIndex + (candles.firstIndex(of: candle) ?? 0)
            }

            // 跳转超出缓冲范围的条目
            guard rawIndex >= bufferStart && rawIndex <= bufferEnd else { return nil }

            let originX = calculator.originX(for: rawIndex)
            let isFullyVisible = calculator.isFullyVisible(index: rawIndex)
            let isPartiallyVisible = calculator.isPartiallyVisible(index: rawIndex)

            return KXUI02VirtualScrollItem(
                index: rawIndex,
                candle: candle,
                originX: originX,
                width: calculator.candleWidth,
                isFullyVisible: isFullyVisible,
                isPartiallyVisible: isPartiallyVisible
            )
        }
    }

    // MARK: - 按偏移量返回可见范围

    /// 根据给定的时间点计算其所在索引，并返回对应的可见范围。
    /// - Parameter candle: K 线数据点
    /// - Returns: 如果该 candle 在可见范围内，返回其索引；否则 nil
    public func index(of candle: KLCandlePoint) -> Int? {
        guard let candleIndex = candles.firstIndex(where: { $0.openTime >= candle.openTime && $0.symbol == candle.symbol && $0.timeframe == candle.timeframe }) else {
            return nil
        }
        let rawIndex = window.indexRange.startIndex + candleIndex
        guard rawIndex >= window.indexRange.startIndex && rawIndex <= window.indexRange.endIndex else {
            return nil
        }
        return rawIndex
    }

    /// 根据全局索引，返回对应的 candle（如果在缓存范围内）。
    public func candle(at index: Int) -> KLCandlePoint? {
        let localIndex = index - window.indexRange.startIndex
        guard localIndex >= 0, localIndex < candles.count else { return nil }
        return candles[localIndex]
    }

    /// 可见范围（含缓冲）。
    public var visibleRange: KXUI02VisibleRange {
        let totalCount = candles.count
        let startIndex = window.indexRange.startIndex
        let endIndex = window.indexRange.endIndex
        let bufferStart = calculator.clampedBufferStartIndex(totalCount: totalCount + startIndex)
        let bufferEnd = calculator.clampedBufferEndIndex(totalCount: totalCount + startIndex)

        let firstVisible = calculator.firstVisibleIndex
        let lastVisible = calculator.lastVisibleIndex
        let clampedFirst = min(firstVisible, endIndex)
        let clampedLast = min(lastVisible, endIndex)

        let visible: [Int]
        if clampedFirst <= clampedLast {
            visible = Array(clampedFirst...clampedLast)
        } else {
            visible = []
        }

        return KXUI02VisibleRange(
            firstVisibleIndex: max(startIndex, clampedFirst),
            lastVisibleIndex: max(startIndex, clampedLast),
            visibleIndices: visible.map { $0 },
            bufferStartIndex: max(startIndex, bufferStart),
            bufferEndIndex: min(endIndex, bufferEnd),
            scrollDirection: .stationary
        )
    }

    // MARK: - 快速元组摘要

    /// 生成一份轻量的虚拟滚动状态摘要。
    public var summary: KXUI02ScrollSummary {
        let totalCount = candles.count
        let range = visibleRange
        return KXUI02ScrollSummary(
            totalCandles: totalCount,
            firstIndex: window.indexRange.startIndex,
            lastIndex: window.indexRange.endIndex,
            firstVisibleIndex: range.firstVisibleIndex,
            lastVisibleIndex: range.lastVisibleIndex,
            bufferStartIndex: range.bufferStartIndex,
            bufferEndIndex: range.bufferEndIndex,
            scrollDirection: range.scrollDirection,
            efficiency: calculator.efficiencySummary
        )
    }

    /// 从 KLVisibleWindow 创建 ItemGenerator（便利工厂）。
    public static func from(window: KLVisibleWindow, candles: [KLCandlePoint], bufferFactor: Double = 0.5) -> KXUI02ItemGenerator {
        let calculator = KXUI02ItemCalculator(
            candleWidth: window.candleWidth,
            viewportWidth: window.viewportWidth,
            contentOffsetX: window.contentOffsetX,
            bufferFactor: bufferFactor
        )
        return KXUI02ItemGenerator(candles: candles, window: window, calculator: calculator)
    }
}

// MARK: - 滚动摘要

/// 虚拟滚动的轻量摘要，适用于效率监控和调试。
public struct KXUI02ScrollSummary: Codable, Equatable, Sendable {
    /// 窗口内总 K 线数
    public let totalCandles: Int
    /// 完整窗口的起始索引
    public let firstIndex: Int
    /// 完整窗口的结束索引
    public let lastIndex: Int
    /// 第一个可见条目索引
    public let firstVisibleIndex: Int
    /// 最后一个可见条目索引
    public let lastVisibleIndex: Int
    /// 缓冲起始索引
    public let bufferStartIndex: Int
    /// 缓冲结束索引
    public let bufferEndIndex: Int
    /// 滑动方向
    public let scrollDirection: KXUI02ScrollDirection
    /// 效率摘要
    public let efficiency: KXUI02EfficiencySummary

    /// 缓冲效率（实际可见占比），[0,1] 区间，越大越高效
    public var bufferEfficiency: Double {
        guard bufferEndIndex >= bufferStartIndex else { return 1 }
        let total = Double(bufferEndIndex - bufferStartIndex + 1)
        let visible = Double(lastVisibleIndex - firstVisibleIndex + 1)
        guard total > 0 else { return 1 }
        return min(1, visible / total)
    }

    public init(totalCandles: Int, firstIndex: Int, lastIndex: Int, firstVisibleIndex: Int, lastVisibleIndex: Int, bufferStartIndex: Int, bufferEndIndex: Int, scrollDirection: KXUI02ScrollDirection, efficiency: KXUI02EfficiencySummary) {
        self.totalCandles = totalCandles
        self.firstIndex = firstIndex
        self.lastIndex = lastIndex
        self.firstVisibleIndex = firstVisibleIndex
        self.lastVisibleIndex = lastVisibleIndex
        self.bufferStartIndex = bufferStartIndex
        self.bufferEndIndex = bufferEndIndex
        self.scrollDirection = scrollDirection
        self.efficiency = efficiency
    }
}

// MARK: - 虚拟滚动窗口同步器

/// 监听窗口变化、更新 contentOffsetX、重新计算可见范围的同步器。
public struct KXUI02WindowSynchronizer: Sendable {
    public var calculator: KXUI02ItemCalculator

    public init(calculator: KXUI02ItemCalculator) {
        self.calculator = calculator
    }

    // MARK: - 窗口同步

    /// 将窗口中的偏移量同步到计算器，重新生成 ItemCalculator。
    /// - Parameter window: 当前可见窗口
    /// - Returns: 同步后的 visible range
    public func sync(from window: KLVisibleWindow, totalCount: Int) -> KXUI02VisibleRange {
        let syncedCalc = calculator.withContentOffsetX(window.contentOffsetX)
        return KXUI02ItemCalculator.computeVisibleRange(
            calculator: syncedCalc,
            totalCount: totalCount,
            globalStartIndex: window.indexRange.startIndex,
            globalEndIndex: window.indexRange.endIndex
        )
    }

    /// 根据时间戳查找对应条目在虚拟列表中的索引。
    /// - Parameter openTime: K 线的开盘时间
    /// - Returns: 对应的全局索引（如果存在）
    public func virtualIndex(openTime: Date, in candles: [KLCandlePoint], globalStartIndex: Int) -> Int? {
        guard let localIndex = candles.firstIndex(where: { $0.openTime >= openTime }) else { return nil }
        return globalStartIndex + localIndex
    }

    /// 快速判断是否需要更新。
    public func needsUpdate(oldOffsetX: Double, newOffsetX: Double, threshold: Double = 1) -> Bool {
        abs(newOffsetX - oldOffsetX) >= threshold
    }

    /// 创建新的同步器并更新偏移量。
    public func withContentOffsetX(_ newOffsetX: Double) -> KXUI02WindowSynchronizer {
        KXUI02WindowSynchronizer(calculator: calculator.withContentOffsetX(newOffsetX))
    }

    public func withViewportWidth(_ newViewportWidth: Double) -> KXUI02WindowSynchronizer {
        KXUI02WindowSynchronizer(calculator: calculator.withViewportWidth(newViewportWidth))
    }
}

// MARK: - 虚拟滚动数据适配入口

public enum KXUI02VisibleWindowScrollAdapter: Sendable {
    /// 从 KLVisibleWindow 初始化 ItemGenerator。
    public static func makeGenerator(window: KLVisibleWindow, candles: [KLCandlePoint], bufferFactor: Double = 0.5) -> KXUI02ItemGenerator {
        KXUI02ItemGenerator.from(window: window, candles: candles, bufferFactor: bufferFactor)
    }

    /// 初始化 ItemCalculator。
    public static func makeCalculator(candleWidth: Double, viewportWidth: Double, contentOffsetX: Double = 0, bufferFactor: Double = 0.5) -> KXUI02ItemCalculator {
        KXUI02ItemCalculator(candleWidth: candleWidth, viewportWidth: viewportWidth, contentOffsetX: contentOffsetX, bufferFactor: bufferFactor)
    }

    /// 初始化 WindowSynchronizer。
    public static func makeSynchronizer(calculator: KXUI02ItemCalculator) -> KXUI02WindowSynchronizer {
        KXUI02WindowSynchronizer(calculator: calculator)
    }

    /// 根据窗口信息直接计算可见范围，不依赖 generator。
    /// - Parameters:
    ///   - window: 当前可见窗口
    ///   - totalCount: 窗口内总 K 线数
    ///   - bufferFactor: 缓冲系数
    /// - Returns: 可见范围
    public static func computeVisibleRange(window: KLVisibleWindow, totalCount: Int, bufferFactor: Double = 0.5) -> KXUI02VisibleRange {
        let calculator = makeCalculator(
            candleWidth: window.candleWidth,
            viewportWidth: window.viewportWidth,
            contentOffsetX: window.contentOffsetX,
            bufferFactor: bufferFactor
        )
        return KXUI02ItemCalculator.computeVisibleRange(
            calculator: calculator,
            totalCount: totalCount,
            globalStartIndex: window.indexRange.startIndex,
            globalEndIndex: window.indexRange.endIndex
        )
    }

    /// 估算两个 contentOffsetX 之间的滑动方向。
    public static func estimateScrollDirection(from oldOffsetX: Double, to newOffsetX: Double, threshold: Double = 1) -> KXUI02ScrollDirection {
        let delta = newOffsetX - oldOffsetX
        if abs(delta) < threshold { return .stationary }
        return delta > 0 ? .forward : .backward
    }
}

// MARK: - ItemCalculator 扩展：独立计算可见范围

extension KXUI02ItemCalculator {
    /// 独立计算可见范围（不依赖 generator）。
    public static func computeVisibleRange(
        calculator: KXUI02ItemCalculator,
        totalCount: Int,
        globalStartIndex: Int,
        globalEndIndex: Int
    ) -> KXUI02VisibleRange {
        let firstVisible = calculator.firstVisibleIndex
        let lastVisible = calculator.lastVisibleIndex
        let clampedFirst = max(globalStartIndex, firstVisible)
        let clampedLast = min(globalEndIndex, lastVisible)

        let bufferStart = calculator.bufferStartIndex
        let bufferEnd = calculator.bufferEndIndex
        let clampedBufferStart = max(globalStartIndex, bufferStart)
        let clampedBufferEnd = min(globalEndIndex, bufferEnd)

        let visible: [Int]
        if clampedFirst <= clampedLast {
            visible = Array(clampedFirst...clampedLast)
        } else {
            visible = []
        }

        return KXUI02VisibleRange(
            firstVisibleIndex: clampedFirst,
            lastVisibleIndex: clampedLast,
            visibleIndices: visible,
            bufferStartIndex: clampedBufferStart,
            bufferEndIndex: clampedBufferEnd,
            scrollDirection: .stationary
        )
    }
}

// MARK: - 骨架入口

public enum KXUI02Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-02",
        fileName: "KX-UI-02_虚拟滚动数据适配.swift",
        layer: .uiAdapter,
        relativePath: "UI数据适配层/KX-UI-02_虚拟滚动数据适配.swift",
        duty: "为 UI 虚拟滚动提供可视窗口数据适配"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(
            name: "虚拟滚动数据适配",
            passed: true,
            message: "已实现：KXUI02VirtualScrollItem / KXUI02VisibleRange / KXUI02ScrollDirection / KXUI02ItemCalculator / KXUI02ItemGenerator / KXUI02WindowSynchronizer / KXUI02VisibleWindowScrollAdapter，支持 candleWidth/viewportWidth/contentOffsetX 的 item-size 计算、可见索引计算、滑动方向估算、缓冲条目、效率摘要"
        )
    }

    /// 快速创建一个虚拟条目数组（用于框架测试/预览占位）。
    /// - Parameters:
    ///   - window: 可见窗口描述
    ///   - count: 生成的条目数量
    ///   - generator: 每个 index 的 KLCandlePoint 工厂
    /// - Returns: 虚拟条目数组
    public static func makePreviewItems(
        window: KLVisibleWindow,
        count: Int,
        generator: (Int) -> KLCandlePoint
    ) -> [KXUI02VirtualScrollItem] {
        let candles = (0..<count).map(generator)
        let itemGen = KXUI02ItemGenerator.from(window: window, candles: candles)
        return itemGen.visibleItems
    }
}
