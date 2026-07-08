//
//  KX-UI-01_应用状态适配.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：适配 UI 应用状态中的币对、周期、颜色、开关
//  禁止事项：禁止画 UI 界面、禁止网络请求、禁止数据库读写、禁止修改 UI 模块
//

import Foundation


// MARK: - UI 应用状态 DTO 集合

/// UI 侧最终选取的币对
public struct KLUISelectedSymbol: Codable, Equatable, Sendable {
    /// 当前选中的 KXSymbol（如 "BTC-USDT"）
    public let symbol: KXSymbol
    /// 交易所 ID
    public let exchangeID: KLExchangeID
    /// 对 UI 的展示名（如 "BTC/USDT"）
    public let displayName: String

    public init(symbol: KXSymbol, exchangeID: KLExchangeID, displayName: String) {
        self.symbol = symbol
        self.exchangeID = exchangeID
        self.displayName = displayName
    }
}

/// UI 侧当前激活的周期
public struct KLUISelectedTimeframe: Codable, Equatable, Sendable {
    /// KXTimeframe 枚举值
    public let timeframe: KXTimeframe
    /// 对 UI 的展示文字（如 "1分"、"4小时"）
    public let displayName: String
    /// 周期秒数，UI 可用于计算时间轴刻度间距
    public let seconds: Int

    public init(timeframe: KXTimeframe, displayName: String, seconds: Int) {
        self.timeframe = timeframe
        self.displayName = displayName
        self.seconds = seconds
    }
}

/// 颜色主题配置 DTO
public struct KLUIColorTheme: Codable, Equatable, Sendable {
    /// 是否深色模式
    public let isDark: Bool
    /// 主题标识符（扩展用，如 "default" / "vintage"）
    public let themeID: String
    /// 主色调十六进制
    public let primaryColorHex: String
    /// 背景色十六进制
    public let backgroundColorHex: String
    /// 上涨色十六进制
    public let upColorHex: String
    /// 下跌色十六进制
    public let downColorHex: String
    /// 文字色十六进制
    public let textColorHex: String
    /// 网格线色十六进制
    public let gridLineColorHex: String

    public init(
        isDark: Bool = false,
        themeID: String = "default",
        primaryColorHex: String = "#2196F3",
        backgroundColorHex: String = "#FFFFFF",
        upColorHex: String = "#26A69A",
        downColorHex: String = "#EF5350",
        textColorHex: String = "#333333",
        gridLineColorHex: String = "#E0E0E0"
    ) {
        self.isDark = isDark
        self.themeID = themeID
        self.primaryColorHex = primaryColorHex
        self.backgroundColorHex = backgroundColorHex
        self.upColorHex = upColorHex
        self.downColorHex = downColorHex
        self.textColorHex = textColorHex
        self.gridLineColorHex = gridLineColorHex
    }
}

/// K线图显示开关 DTO
public struct KLUIKLineVisibility: Codable, Equatable, Sendable {
    /// 是否显示蜡烛线
    public let showCandles: Bool
    /// 是否显示成交量
    public let showVolume: Bool
    /// 是否显示均线
    public let showMA: Bool
    /// 是否显示网格
    public let showGrid: Bool
    /// 是否显示标记叠加层
    public let showMarkers: Bool

    public init(showCandles: Bool = true, showVolume: Bool = true, showMA: Bool = true, showGrid: Bool = true, showMarkers: Bool = true) {
        self.showCandles = showCandles
        self.showVolume = showVolume
        self.showGrid = showGrid
        self.showMA = showMA
        self.showMarkers = showMarkers
    }
}

/// K线图缩放/间距设置 DTO
public struct KLUIKLineDisplaySettings: Codable, Equatable, Sendable {
    /// 每根蜡烛宽度(pts)
    public let candleWidth: Double
    /// 蜡烛之间间距(pts)
    public let candleSpacing: Double
    /// 成交量高度比例（相对总高度的 0~1）
    public let volumeHeightRatio: Double

    public init(candleWidth: Double = 8, candleSpacing: Double = 2, volumeHeightRatio: Double = 0.2) {
        self.candleWidth = candleWidth
        self.candleSpacing = candleSpacing
        self.volumeHeightRatio = volumeHeightRatio
    }
}

/// 加载状态 DTO
public enum KLUILoadingState: String, Codable, Sendable, CaseIterable {
    case idle        /// 空闲（无加载请求）
    case loading     /// 加载中
    case refreshing  /// 刷新中
    case completed   /// 加载完成
    case failed      /// 加载失败
}

/// 错误状态 DTO
public struct KLUIErrorState: Codable, Equatable, Sendable {
    /// 是否有错误
    public let hasError: Bool
    /// 错误标题
    public let title: String
    /// 错误详细描述
    public let message: String
    /// 是否可以重试
    public let retryable: Bool

    public init(hasError: Bool = false, title: String = "", message: String = "", retryable: Bool = true) {
        self.hasError = hasError
        self.title = title
        self.message = message
        self.retryable = retryable
    }

    /// 无错误状态
    public static let none = KLUIErrorState()
}

// MARK: - K线应用整体状态 DTO

/// UI 侧 K线应用状态的完整快照
/// 由 UI 适配层维护，纯 DTO，不含业务逻辑
public struct KLUIAppState: Codable, Equatable, Sendable {
    /// 当前选中的币对
    public var selectedSymbol: KLUISelectedSymbol
    /// 当前激活的周期
    public var selectedTimeframe: KLUISelectedTimeframe
    /// 颜色主题
    public var colorTheme: KLUIColorTheme
    /// 显示开关
    public var visibility: KLUIKLineVisibility
    /// 显示设置（缩放/间距等）
    public var displaySettings: KLUIKLineDisplaySettings
    /// 加载状态
    public var loadingState: KLUILoadingState
    /// 错误状态
    public var errorState: KLUIErrorState

    public init(
        selectedSymbol: KLUISelectedSymbol,
        selectedTimeframe: KLUISelectedTimeframe,
        colorTheme: KLUIColorTheme = KLUIColorTheme(),
        visibility: KLUIKLineVisibility = KLUIKLineVisibility(),
        displaySettings: KLUIKLineDisplaySettings = KLUIKLineDisplaySettings(),
        loadingState: KLUILoadingState = .idle,
        errorState: KLUIErrorState = .none
    ) {
        self.selectedSymbol = selectedSymbol
        self.selectedTimeframe = selectedTimeframe
        self.colorTheme = colorTheme
        self.visibility = visibility
        self.displaySettings = displaySettings
        self.loadingState = loadingState
        self.errorState = errorState
    }
}

// MARK: - 双路映射：KXSymbol ↔ String / KXTimeframe ↔ UI 描述

/// KXSymbol 与 UI 显示名的映射记录
public struct KXSymbolMapping: Codable, Equatable, Sendable {
    /// K 线模块内部符号
    public let symbol: KXSymbol
    /// UI 侧展示（如 "BTC/USDT"）
    public let uiDisplayName: String
    /// 交易所 ID
    public let exchangeID: KLExchangeID

    public init(symbol: KXSymbol, uiDisplayName: String, exchangeID: KLExchangeID = "OKX") {
        self.symbol = symbol
        self.uiDisplayName = uiDisplayName
        self.exchangeID = exchangeID
    }
}

/// KXTimeframe 与 UI 周期描述的映射记录
public struct KXTimeframeMapping: Codable, Equatable, Sendable {
    /// K 线模块内部周期枚举
    public let timeframe: KXTimeframe
    /// UI 侧展示文字（如 "1分"、"4小时"）
    public let uiDisplayName: String
    /// 周期秒数
    public let seconds: Int

    public init(timeframe: KXTimeframe, uiDisplayName: String, seconds: Int) {
        self.timeframe = timeframe
        self.uiDisplayName = uiDisplayName
        self.seconds = seconds
    }
}

// MARK: - 双路映射表与转换工具

/// KXSymbol / KXTimeframe 与 UI 端字符串的双路映射表
/// 方便 UI 适配层在需要时做纯转换（不依赖 KX-FN-01 / KX-FN-02 功能实现）
public enum KLUIDualMappingTable {
    // MARK: 币对映射表

    /// 内置常见币对映射（UI 展示名基于 / 分隔）
    public static let symbolMappings: [KXSymbolMapping] = [
        KXSymbolMapping(symbol: "BTC-USDT",   uiDisplayName: "BTC/USDT"),
        KXSymbolMapping(symbol: "ETH-USDT",   uiDisplayName: "ETH/USDT"),
        KXSymbolMapping(symbol: "SOL-USDT",   uiDisplayName: "SOL/USDT"),
        KXSymbolMapping(symbol: "DOGE-USDT",  uiDisplayName: "DOGE/USDT"),
        KXSymbolMapping(symbol: "XRP-USDT",   uiDisplayName: "XRP/USDT"),
        KXSymbolMapping(symbol: "ADA-USDT",   uiDisplayName: "ADA/USDT"),
        KXSymbolMapping(symbol: "AVAX-USDT",  uiDisplayName: "AVAX/USDT"),
        KXSymbolMapping(symbol: "DOT-USDT",   uiDisplayName: "DOT/USDT"),
        KXSymbolMapping(symbol: "LINK-USDT",  uiDisplayName: "LINK/USDT"),
        KXSymbolMapping(symbol: "MATIC-USDT", uiDisplayName: "MATIC/USDT"),
    ]

    /// 从 KXSymbol 查找 UI 展示名
    public static func uiName(for symbol: KXSymbol) -> String {
        symbolMappings.first { $0.symbol == symbol }?.uiDisplayName ?? symbol.replacingOccurrences(of: "-", with: "/")
    }

    /// 从 UI 展示名反向查找 KXSymbol（严格匹配）
    public static func symbol(for uiDisplayName: String) -> KXSymbol? {
        symbolMappings.first { $0.uiDisplayName == uiDisplayName }?.symbol
    }

    // MARK: 周期映射表

    /// 内置完整周期映射
    public static let timeframeMappings: [KXTimeframeMapping] = [
        KXTimeframeMapping(timeframe: .oneSecond,      uiDisplayName: "1秒",  seconds: 1),
        KXTimeframeMapping(timeframe: .oneMinute,      uiDisplayName: "1分",  seconds: 60),
        KXTimeframeMapping(timeframe: .threeMinutes,   uiDisplayName: "3分",  seconds: 180),
        KXTimeframeMapping(timeframe: .fiveMinutes,    uiDisplayName: "5分",  seconds: 300),
        KXTimeframeMapping(timeframe: .fifteenMinutes, uiDisplayName: "15分", seconds: 900),
        KXTimeframeMapping(timeframe: .thirtyMinutes,  uiDisplayName: "30分", seconds: 1800),
        KXTimeframeMapping(timeframe: .oneHour,        uiDisplayName: "1小时", seconds: 3600),
        KXTimeframeMapping(timeframe: .twoHours,       uiDisplayName: "2小时", seconds: 7200),
        KXTimeframeMapping(timeframe: .fourHours,      uiDisplayName: "4小时", seconds: 14400),
        KXTimeframeMapping(timeframe: .sixHours,       uiDisplayName: "6小时", seconds: 21600),
        KXTimeframeMapping(timeframe: .twelveHours,    uiDisplayName: "12小时", seconds: 43200),
        KXTimeframeMapping(timeframe: .oneDay,         uiDisplayName: "日线", seconds: 86400),
        KXTimeframeMapping(timeframe: .twoDays,        uiDisplayName: "2日", seconds: 172800),
        KXTimeframeMapping(timeframe: .threeDays,      uiDisplayName: "3日", seconds: 259200),
        KXTimeframeMapping(timeframe: .oneWeek,        uiDisplayName: "周线", seconds: 604800),
        KXTimeframeMapping(timeframe: .oneMonth,       uiDisplayName: "月线", seconds: 2592000),
        KXTimeframeMapping(timeframe: .threeMonths,    uiDisplayName: "季线", seconds: 7776000),
    ]

    /// 从 KXTimeframe 查找 UI 展示名
    public static func uiName(for timeframe: KXTimeframe) -> String {
        timeframeMappings.first { $0.timeframe == timeframe }?.uiDisplayName ?? timeframe.rawValue
    }

    /// 从 KXTimeframe 查找秒数
    public static func seconds(for timeframe: KXTimeframe) -> Int {
        timeframeMappings.first { $0.timeframe == timeframe }?.seconds ?? 60
    }

    /// 从 UI 展示名反向查找 KXTimeframe
    public static func timeframe(for uiDisplayName: String) -> KXTimeframe? {
        timeframeMappings.first { $0.uiDisplayName == uiDisplayName }?.timeframe
    }

    // MARK: 生成 KLUISelectedXxx 工厂方法

    /// 从 KXSymbol 生成 UI 选中的币对 DTO
    public static func makeSelectedSymbol(_ symbol: KXSymbol, exchangeID: KLExchangeID = "OKX") -> KLUISelectedSymbol {
        KLUISelectedSymbol(
            symbol: symbol,
            exchangeID: exchangeID,
            displayName: uiName(for: symbol)
        )
    }

    /// 从 KXTimeframe 生成 UI 选中的周期 DTO
    public static func makeSelectedTimeframe(_ timeframe: KXTimeframe) -> KLUISelectedTimeframe {
        KLUISelectedTimeframe(
            timeframe: timeframe,
            displayName: uiName(for: timeframe),
            seconds: seconds(for: timeframe)
        )
    }
}

// MARK: - KXSymbol / KXTimeframe 到 KLUIAppState 的初始状态生成

/// KLUIAppState 初始状态工厂
/// 在不依赖 KX-FN-01 / KX-FN-02 功能实现的情况下，由 UI 适配层生成初始状态
public enum KLUIAppStateFactory {
    /// 生成默认的 K 线应用初始状态
    /// - Parameters:
    ///   - symbol: 默认币对（可选，默认 "BTC-USDT"）
    ///   - timeframe: 默认周期（可选，默认 .oneHour）
    ///   - isDark: 是否默认深色模式
    /// - Returns: KLUIAppState 初始状态
    public static func makeDefault(
        symbol: KXSymbol = "BTC-USDT",
        timeframe: KXTimeframe = .oneHour,
        isDark: Bool = false
    ) -> KLUIAppState {
        KLUIAppState(
            selectedSymbol: KLUIDualMappingTable.makeSelectedSymbol(symbol),
            selectedTimeframe: KLUIDualMappingTable.makeSelectedTimeframe(timeframe),
            colorTheme: KLUIColorTheme(isDark: isDark),
            visibility: KLUIKLineVisibility(),
            displaySettings: KLUIKLineDisplaySettings(),
            loadingState: .idle,
            errorState: .none
        )
    }

    /// 从已有的 KXSymbol 和 KXTimeframe 值生成新的状态（仅切换币对和周期，其余保持默认）
    public static func makeState(
        symbol: KXSymbol,
        exchangeID: KLExchangeID = "OKX",
        timeframe: KXTimeframe,
        isDark: Bool = false
    ) -> KLUIAppState {
        KLUIAppState(
            selectedSymbol: KLUIDualMappingTable.makeSelectedSymbol(symbol, exchangeID: exchangeID),
            selectedTimeframe: KLUIDualMappingTable.makeSelectedTimeframe(timeframe),
            colorTheme: KLUIColorTheme(isDark: isDark),
            visibility: KLUIKLineVisibility(),
            displaySettings: KLUIKLineDisplaySettings(),
            loadingState: .idle,
            errorState: .none
        )
    }
}

// MARK: - KX-UI-01 骨架实现（兼容统一注册表）

public enum KXUI01Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-01",
        fileName: "KX-UI-01_K线应用状态适配.swift",
        layer: .uiAdapter,
        relativePath: "UI数据适配层/KX-UI-01_K线应用状态适配.swift",
        duty: "适配 UI 应用状态中的币对、周期、颜色、开关"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "K线应用状态适配", passed: true, message: "已实现：UI 应用状态 DTO、KXTimeframe/KXSymbol 双路映射表、初始状态工厂")
    }

    public static func placeholder() {
        // 本文件已实现：DTP、双路映射表、初始状态工厂，无需后续填充
    }
}
