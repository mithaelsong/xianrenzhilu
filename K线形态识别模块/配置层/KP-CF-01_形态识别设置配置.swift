// KP-CF-01_形态识别设置配置.swift
// 职责：向 UI 设置面板提供形态识别开关、周期、展示名称和示意图类型配置。

import Foundation

public struct KPPatternSettingOption: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let category: String
    public let illustrationKind: String
    public let defaultEnabled: Bool
    public let selectedTimeframes: Set<String>
    public init(id: String, name: String, category: String, illustrationKind: String, defaultEnabled: Bool, selectedTimeframes: Set<String>) { self.id = id; self.name = name; self.category = category; self.illustrationKind = illustrationKind; self.defaultEnabled = defaultEnabled; self.selectedTimeframes = selectedTimeframes }
}

public enum KPPatternSettingsCatalog {
    /// 设置面板写入的是 KXTimeframe.rawValue；必须和 K线面板周期值一致。
    /// 旧版曾使用“1月/3月”中文值，K线面板实际 rawValue 为“1M/3M”，会导致月线/季线按钮看起来选中了但不生效。
    public static let timeframes = ["5m", "15m", "1h", "4h", "1d", "1w", "1M", "3M"]
    public static func builtinOptions() -> [KPPatternSettingOption] {
        let enabled: Set<String> = []
        let illustrations: [String: String] = ["hanging-man": "hangingMan", "long-legged-doji": "longLeggedDoji", "gravestone-doji": "gravestone", "dragonfly-doji": "dragonfly", "spinning-top": "spinning", "long-lower-shadow": "lowerShadow", "long-upper-shadow": "upperShadow", "bullish-engulfing": "engulfingBull", "bearish-engulfing": "engulfingBear", "piercing-line": "piercing", "dark-cloud-cover": "darkCloud", "bullish-harami": "haramiBull", "bearish-harami": "haramiBear", "harami-cross": "haramiCross", "tweezer-top": "tweezerTop", "tweezer-bottom": "tweezerBottom", "bullish-separating": "separatingBull", "bearish-separating": "separatingBear", "morning-star": "morningStar", "evening-star": "eveningStar", "abandoned-baby": "abandonedBaby", "three-black-crows": "threeBear", "three-white-soldiers": "threeBull", "rising-three-methods": "risingThree", "falling-three-methods": "fallingThree"]
        var options = CandlePatternLibrary.shared.allPatterns.map { p in KPPatternSettingOption(id: p.id, name: p.name, category: p.category.rawValue, illustrationKind: illustrations[p.id] ?? p.id, defaultEnabled: enabled.contains(p.id), selectedTimeframes: defaultTimeframes(for: p)) }
        options.append(KPPatternSettingOption(id: "custom", name: "自定义形态", category: "自定义", illustrationKind: "custom", defaultEnabled: true, selectedTimeframes: ["1h"]))
        return options
    }
    private static func defaultTimeframes(for pattern: CandlePatternDefinition) -> Set<String> { switch pattern.category { case .single: return ["15m", "1h"]; case .dual: return ["1h", "4h"]; case .multi: return ["4h", "1d"] } }

    public static func timeframeMeaning(_ timeframe: String) -> String {
        switch timeframe {
        case "5m": return "超短线，通常反映未来数根K线内的分钟级波动。"
        case "15m": return "短线，通常反映约一两个小时内的强弱变化。"
        case "1h": return "日内级别，通常反映半天到一天内的节奏变化。"
        case "4h": return "波段级别，通常反映数天内一段行情的涨跌力度。"
        case "1d": return "日线级别，通常反映数日到数周的趋势/反转信号。"
        case "1w": return "周线级别，通常反映中长期趋势结构。"
        case "1M": return "月线级别，通常反映长期大周期方向。"
        case "3M": return "季线级别，通常反映超长期结构，只用于大周期确认。"
        default: return "当前K线周期内的形态信号。"
        }
    }

    public static func requiredIndicatorIDs(for patternID: String) -> Set<String> {
        switch patternID {
        case "gap", "abandoned-baby", "morning-star", "evening-star", "rising-three-methods", "falling-three-methods":
            return ["KX-IN-01-MA", "KX-IN-15-ATR", "KX-IN-06-成交量分析"]
        case "hammer", "hanging-man", "dragonfly-doji", "gravestone-doji", "long-lower-shadow", "long-upper-shadow", "tweezer-top", "tweezer-bottom":
            return ["KX-IN-01-MA", "KX-IN-29-支撑阻力", "KX-IN-06-成交量分析"]
        case "bullish-engulfing", "bearish-engulfing", "piercing-line", "dark-cloud-cover", "bullish-harami", "bearish-harami", "harami-cross":
            return ["KX-IN-01-MA", "KX-IN-03-ADX", "KX-IN-06-成交量分析"]
        case "three-black-crows", "three-white-soldiers", "bullish-separating", "bearish-separating", "marubozu":
            return ["KX-IN-01-MA", "KX-IN-03-ADX", "KX-IN-15-ATR"]
        default:
            return ["KX-IN-01-MA", "KX-IN-06-成交量分析"]
        }
    }

    public static func requiredIndicatorIDs(for patternIDs: Set<String>) -> Set<String> {
        patternIDs.reduce(into: Set<String>()) { partial, patternID in
            partial.formUnion(requiredIndicatorIDs(for: patternID))
        }
    }

    public static func indicatorDisplayName(_ indicatorID: String) -> String {
        switch indicatorID {
        case "KX-IN-01-MA": return "MA趋势"
        case "KX-IN-03-ADX": return "ADX趋势强度"
        case "KX-IN-06-成交量分析": return "成交量确认"
        case "KX-IN-15-ATR": return "ATR波动率"
        case "KX-IN-29-支撑阻力": return "支撑阻力"
        default: return indicatorID
        }
    }

    public static func requiredIndicatorText(for patternID: String) -> String {
        requiredIndicatorIDs(for: patternID).map(indicatorDisplayName(_:)).sorted().joined(separator: "、")
    }

    public static func helpText(for option: KPPatternSettingOption) -> String {
        let definition = CandlePatternLibrary.shared.pattern(id: option.id)
        let description = definition?.description ?? "自定义形态：按用户定义规则识别。"
        let direction: String
        switch definition?.direction {
        case .bullish?: direction = "偏看涨"
        case .bearish?: direction = "偏看跌"
        case .reversal?: direction = "反转信号"
        case .continuation?: direction = "趋势延续"
        case .neutral?: direction = "中性/分歧"
        default: direction = "未知方向"
        }
        let timeframeText = timeframes.map { "\($0)：\(timeframeMeaning($0))" }.joined(separator: "\n")
        let indicators = requiredIndicatorText(for: option.id)
        return "\(option.name)｜\(direction)\n\(description)\n\n依赖指标：\(indicators)。即使这些指标没有在K线面板手动打开，形态识别开启时也会按规则临时计算，不强制显示指标线。\n\n周期意义：\n\(timeframeText)"
    }

}


public struct KPPatternSettingState: Codable, Equatable, Sendable {
    public let id: String
    public var enabled: Bool
    public var selectedTimeframes: Set<String>
    public init(id: String, enabled: Bool, selectedTimeframes: Set<String>) { self.id = id; self.enabled = enabled; self.selectedTimeframes = selectedTimeframes }
}

public enum KPPatternSettingsStore {
    private static let storageKey = "com.xianrenzhilu.kp.pattern.settings.states"
    public static func loadStates() -> [String: KPPatternSettingState] {
        guard let data = UserDefaults.standard.data(forKey: storageKey), let states = try? JSONDecoder().decode([String: KPPatternSettingState].self, from: data) else { return defaultStates() }
        var merged = defaultStates()
        for (id, state) in states {
            merged[id] = normalized(state)
        }
        return merged
    }
    public static func clearSavedStates() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.synchronize()
    }
    public static func saveStates(_ states: [String: KPPatternSettingState]) {
        let normalizedStates = Dictionary(uniqueKeysWithValues: states.map { ($0.key, normalized($0.value)) })
        guard let data = try? JSONEncoder().encode(normalizedStates) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    public static func defaultStates() -> [String: KPPatternSettingState] {
        Dictionary(uniqueKeysWithValues: KPPatternSettingsCatalog.builtinOptions().map { ($0.id, KPPatternSettingState(id: $0.id, enabled: $0.defaultEnabled, selectedTimeframes: $0.selectedTimeframes)) })
    }

    private static func normalized(_ state: KPPatternSettingState) -> KPPatternSettingState {
        KPPatternSettingState(id: state.id, enabled: state.enabled, selectedTimeframes: Set(state.selectedTimeframes.map(normalizedTimeframe(_:))))
    }

    private static func normalizedTimeframe(_ value: String) -> String {
        switch value {
        case "1月": return "1M"
        case "3月": return "3M"
        default: return value
        }
    }
}

public extension Notification.Name {
    static let KPPatternSettingsDidChange = Notification.Name("KPPatternSettingsDidChange")
}
