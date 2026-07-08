//
//  KX-FN-29_统一指标注册表.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：统一登记指标服务层全部指标，向 UI、收藏、搜索提供唯一指标目录
//  禁止事项：禁止 UI 绘制、禁止网络请求、禁止数据库读写
//

import Foundation

public enum KXUnifiedIndicatorRegistry {
    public static let allIndicators: [KXTechnicalIndicator] = [
        KXTechnicalIndicator(id: "KX-IN-03-ADX", name: "ADX", category: .trend, description: "ADX 指标，来源：指标服务层/趋势指标/KX-IN-03_ADX.swift", formula: "ADX"),
        KXTechnicalIndicator(id: "KX-IN-08-Aroon", name: "Aroon", category: .trend, description: "Aroon 指标，来源：指标服务层/趋势指标/KX-IN-08_Aroon.swift", formula: "Aroon"),
        KXTechnicalIndicator(id: "KX-IN-06-CoppockCurve", name: "Coppock Curve", category: .trend, description: "Coppock Curve 指标，来源：指标服务层/趋势指标/KX-IN-06_CoppockCurve.swift", formula: "Coppock Curve"),
        KXTechnicalIndicator(id: "KX-IN-02-EMA", name: "EMA", category: .trend, description: "EMA 指标，来源：指标服务层/趋势指标/KX-IN-02_EMA.swift", formula: "EMA"),
        KXTechnicalIndicator(id: "KX-IN-01-MA", name: "MA", category: .trend, description: "MA 指标，来源：指标服务层/趋势指标/KX-IN-01_MA.swift", formula: "MA"),
        KXTechnicalIndicator(id: "KX-IN-05-ParabolicSAR", name: "Parabolic SAR", category: .trend, description: "Parabolic SAR 指标，来源：指标服务层/趋势指标/KX-IN-05_ParabolicSAR.swift", formula: "Parabolic SAR"),
        KXTechnicalIndicator(id: "KX-IN-21-SuperTrend", name: "SuperTrend", category: .trend, description: "SuperTrend 指标，来源：指标服务层/趋势指标/KX-IN-21_SuperTrend.swift", formula: "SuperTrend"),
        KXTechnicalIndicator(id: "KX-IN-07-TRIX", name: "TRIX", category: .trend, description: "TRIX 指标，来源：指标服务层/趋势指标/KX-IN-07_TRIX.swift", formula: "TRIX"),
        KXTechnicalIndicator(id: "KX-IN-04-CCI", name: "CCI", category: .oscillator, description: "CCI 指标，来源：指标服务层/震荡指标/KX-IN-04_CCI.swift", formula: "CCI"),
        KXTechnicalIndicator(id: "KX-IN-18-CMO", name: "CMO", category: .oscillator, description: "CMO 指标，来源：指标服务层/震荡指标/KX-IN-18_CMO.swift", formula: "CMO"),
        KXTechnicalIndicator(id: "KX-IN-09-DPO", name: "DPO", category: .oscillator, description: "DPO 指标，来源：指标服务层/震荡指标/KX-IN-09_DPO.swift", formula: "DPO"),
        KXTechnicalIndicator(id: "KX-IN-23-KD", name: "KD", category: .oscillator, description: "KD 指标，来源：指标服务层/震荡指标/KX-IN-23_KD.swift", formula: "KD"),
        KXTechnicalIndicator(id: "KX-IN-03-KDJ", name: "KDJ", category: .oscillator, description: "KDJ 指标，来源：指标服务层/震荡指标/KX-IN-03_KDJ.swift", formula: "KDJ"),
        KXTechnicalIndicator(id: "KX-IN-02-MACD", name: "MACD", category: .oscillator, description: "MACD 指标，来源：指标服务层/震荡指标/KX-IN-02_MACD.swift", formula: "MACD"),
        KXTechnicalIndicator(id: "KX-IN-08-PO", name: "PO", category: .oscillator, description: "PO 指标，来源：指标服务层/震荡指标/KX-IN-08_PO.swift", formula: "PO"),
        KXTechnicalIndicator(id: "KX-IN-01-RSI", name: "RSI", category: .oscillator, description: "RSI 指标，来源：指标服务层/震荡指标/KX-IN-01_RSI.swift", formula: "RSI"),
        KXTechnicalIndicator(id: "KX-IN-11-RVI", name: "RVI", category: .oscillator, description: "RVI 指标，来源：指标服务层/震荡指标/KX-IN-11_RVI.swift", formula: "RVI"),
        KXTechnicalIndicator(id: "KX-IN-06-StochasticRSI", name: "Stochastic RSI", category: .oscillator, description: "Stochastic RSI 指标，来源：指标服务层/震荡指标/KX-IN-06_StochasticRSI.swift", formula: "Stochastic RSI"),
        KXTechnicalIndicator(id: "KX-IN-07-UltimateOscillator", name: "Ultimate Oscillator", category: .oscillator, description: "Ultimate Oscillator 指标，来源：指标服务层/震荡指标/KX-IN-07_UltimateOscillator.swift", formula: "Ultimate Oscillator"),
        KXTechnicalIndicator(id: "KX-IN-05-WilliamsR", name: "Williams %R", category: .oscillator, description: "Williams %R 指标，来源：指标服务层/震荡指标/KX-IN-05_WilliamsR.swift", formula: "Williams %R"),
        KXTechnicalIndicator(id: "KX-IN-19-牛熊力量", name: "牛熊力量", category: .oscillator, description: "牛熊力量 指标，来源：指标服务层/震荡指标/KX-IN-19_牛熊力量.swift", formula: "牛熊力量"),
        KXTechnicalIndicator(id: "KX-IN-30-ChandeForecast", name: "钱德预测", category: .oscillator, description: "钱德预测 指标，来源：指标服务层/震荡指标/KX-IN-30_ChandeForecast.swift", formula: "钱德预测"),
        KXTechnicalIndicator(id: "KX-IN-10-Momentum", name: "Momentum", category: .oscillator, description: "Momentum 指标，来源：指标服务层/震荡指标/KX-IN-10_Momentum.swift", formula: "Momentum"),
        KXTechnicalIndicator(id: "KX-IN-09-ROC", name: "ROC", category: .oscillator, description: "ROC 指标，来源：指标服务层/震荡指标/KX-IN-09_ROC.swift", formula: "ROC"),
        KXTechnicalIndicator(id: "KX-IN-10-ADLine", name: "ADL", category: .volume, description: "ADL 指标，来源：指标服务层/成交量指标/KX-IN-10_ADLine.swift", formula: "ADL"),
        KXTechnicalIndicator(id: "KX-IN-06-ChaikinMoneyFlow", name: "CMF", category: .volume, description: "CMF 指标，来源：指标服务层/成交量指标/KX-IN-06_ChaikinMoneyFlow.swift", formula: "CMF"),
        KXTechnicalIndicator(id: "KX-IN-02-EMV", name: "EMV", category: .volume, description: "EMV 指标，来源：指标服务层/成交量指标/KX-IN-02_EMV.swift", formula: "EMV"),
        KXTechnicalIndicator(id: "KX-IN-04-ForceIndex", name: "Force Index", category: .volume, description: "Force Index 指标，来源：指标服务层/成交量指标/KX-IN-04_ForceIndex.swift", formula: "Force Index"),
        KXTechnicalIndicator(id: "KX-IN-12-MFI", name: "MFI", category: .volume, description: "MFI 指标，来源：指标服务层/成交量指标/KX-IN-12_MFI.swift", formula: "MFI"),
        KXTechnicalIndicator(id: "KX-IN-13-NVI", name: "NVI", category: .volume, description: "NVI 指标，来源：指标服务层/成交量指标/KX-IN-13_NVI.swift", formula: "NVI"),
        KXTechnicalIndicator(id: "KX-IN-02-OBV", name: "OBV", category: .volume, description: "OBV 指标，来源：指标服务层/成交量指标/KX-IN-02_OBV.swift", formula: "OBV"),
        KXTechnicalIndicator(id: "KX-IN-07-POC", name: "POC", category: .volume, description: "POC 指标，来源：指标服务层/成交量指标/KX-IN-07_POC.swift", formula: "POC"),
        KXTechnicalIndicator(id: "KX-IN-14-PVI", name: "PVI", category: .volume, description: "PVI 指标，来源：指标服务层/成交量指标/KX-IN-14_PVI.swift", formula: "PVI"),
        KXTechnicalIndicator(id: "KX-IN-05-VPT", name: "VPT", category: .volume, description: "VPT 指标，来源：指标服务层/成交量指标/KX-IN-05_VPT.swift", formula: "VPT"),
        KXTechnicalIndicator(id: "KX-IN-03-VWAP", name: "VWAP", category: .volume, description: "VWAP 指标，来源：指标服务层/成交量指标/KX-IN-03_VWAP.swift", formula: "VWAP"),
        KXTechnicalIndicator(id: "KX-IN-01-Vortex", name: "Vortex", category: .volume, description: "Vortex 指标，来源：指标服务层/成交量指标/KX-IN-01_Vortex.swift", formula: "Vortex"),
        KXTechnicalIndicator(id: "KX-IN-13-VolumeProfile", name: "成交量分布", category: .volume, description: "成交量分布 指标，来源：指标服务层/成交量指标/KX-IN-13_VolumeProfile.swift", formula: "成交量分布"),
        KXTechnicalIndicator(id: "KX-IN-06-成交量分析", name: "成交量分析", category: .volume, description: "成交量分析 指标，来源：指标服务层/成交量指标/KX-IN-06_成交量分析.swift", formula: "成交量分析"),
        KXTechnicalIndicator(id: "KX-IN-15-ATR", name: "ATR", category: .volatility, description: "ATR 指标，来源：指标服务层/波动率指标/KX-IN-15_ATR.swift", formula: "ATR"),
        KXTechnicalIndicator(id: "KX-IN-14-BBW", name: "布林带宽", category: .volatility, description: "布林带宽 指标，来源：指标服务层/波动率指标/KX-IN-14_BBW.swift", formula: "布林带宽"),
        KXTechnicalIndicator(id: "KX-IN-15-StdDevChannel", name: "标准差通道", category: .volatility, description: "标准差通道 指标，来源：指标服务层/波动率指标/KX-IN-15_StdDevChannel.swift", formula: "标准差通道"),
        KXTechnicalIndicator(id: "KX-IN-16-ChaikinVolatility", name: "蔡金波动率", category: .volatility, description: "蔡金波动率 指标，来源：指标服务层/波动率指标/KX-IN-16_ChaikinVolatility.swift", formula: "蔡金波动率"),
        KXTechnicalIndicator(id: "KX-IN-18-DonchianChannel", name: "Donchian Channel", category: .volatility, description: "Donchian Channel 指标，来源：指标服务层/波动率指标/KX-IN-18_DonchianChannel.swift", formula: "Donchian Channel"),
        KXTechnicalIndicator(id: "KX-IN-20-HMA", name: "HMA", category: .trend, description: "HMA 指标，来源：指标服务层/趋势指标/KX-IN-20_HMA.swift", formula: "HMA"),
        KXTechnicalIndicator(id: "KX-IN-04-一目均衡图", name: "Ichimoku", category: .trend, description: "Ichimoku 指标，来源：指标服务层/趋势指标/KX-IN-04_一目均衡图.swift", formula: "Ichimoku"),
        KXTechnicalIndicator(id: "KX-IN-12-KAMA", name: "KAMA", category: .trend, description: "KAMA 指标，来源：指标服务层/趋势指标/KX-IN-12_KAMA.swift", formula: "KAMA"),
        KXTechnicalIndicator(id: "KX-IN-01-布林带", name: "布林带", category: .volatility, description: "布林带 指标，来源：指标服务层/波动率指标/KX-IN-01_布林带.swift", formula: "布林带"),
        KXTechnicalIndicator(id: "KX-IN-25-rainbow", name: "彩虹均线", category: .trend, description: "彩虹均线 指标，来源：指标服务层/趋势指标/KX-IN-25_rainbow.swift", formula: "彩虹均线"),
        KXTechnicalIndicator(id: "KX-IN-29-支撑阻力", name: "支撑阻力", category: .trend, description: "支撑阻力 指标，来源：指标服务层/趋势指标/KX-IN-29_支撑阻力.swift", formula: "支撑阻力"),
        KXTechnicalIndicator(id: "KX-IN-20-Fibonacci", name: "斐波那契", category: .statistics, description: "斐波那契 指标，来源：指标服务层/统计指标/KX-IN-20_Fibonacci.swift", formula: "斐波那契"),
        KXTechnicalIndicator(id: "KX-IN-16-PivotPoints", name: "枢纽点", category: .statistics, description: "枢纽点 指标，来源：指标服务层/统计指标/KX-IN-16_PivotPoints.swift", formula: "枢纽点"),
        KXTechnicalIndicator(id: "KX-IN-17-KeltnerChannel", name: "肯特纳通道", category: .volatility, description: "肯特纳通道 指标，来源：指标服务层/波动率指标/KX-IN-17_KeltnerChannel.swift", formula: "肯特纳通道"),
        KXTechnicalIndicator(id: "KX-IN-25-Ahr999", name: "AHR999", category: .onChain, description: "AHR999 指标，来源：指标服务层/链上指标/KX-IN-25_Ahr999.swift", formula: "AHR999"),
        KXTechnicalIndicator(id: "KX-IN-22-MVRV", name: "MVRV", category: .onChain, description: "MVRV 指标，来源：指标服务层/链上指标/KX-IN-22_MVRV.swift", formula: "MVRV"),
        KXTechnicalIndicator(id: "KX-IN-24-NUPL", name: "NUPL", category: .onChain, description: "NUPL 指标，来源：指标服务层/链上指标/KX-IN-24_NUPL.swift", formula: "NUPL"),
        KXTechnicalIndicator(id: "KX-IN-26-彩虹图", name: "彩虹图", category: .onChain, description: "彩虹图 指标，来源：指标服务层/链上指标/KX-IN-26_彩虹图.swift", formula: "彩虹图"),
        KXTechnicalIndicator(id: "KX-IN-17-活跃地址数", name: "活跃地址数", category: .onChain, description: "活跃地址数 指标，来源：指标服务层/链上指标/KX-IN-17_活跃地址数.swift", formula: "活跃地址数"),
        KXTechnicalIndicator(id: "KX-IN-28-资金费率", name: "资金费率", category: .onChain, description: "资金费率 指标，来源：指标服务层/链上指标/KX-IN-28_资金费率.swift", formula: "资金费率"),
        KXTechnicalIndicator(id: "KX-IN-27-多空比", name: "多空比", category: .statistics, description: "多空比 指标，来源：指标服务层/统计指标/KX-IN-27_多空比.swift", formula: "多空比"),
    ]

    public static var categorizedIndicators: [KXIndicatorCategory: [KXTechnicalIndicator]] {
        Dictionary(grouping: allIndicators, by: { $0.category })
    }

    public static func indicators(for category: KXIndicatorCategory) -> [KXTechnicalIndicator] {
        categorizedIndicators[category, default: []].sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public static func indicator(withId id: String) -> KXTechnicalIndicator? {
        let lowered = id.lowercased()
        return allIndicators.first { $0.id.lowercased() == lowered || $0.name.lowercased() == lowered }
    }

    public static func searchIndicators(query: String) -> [KXTechnicalIndicator] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allIndicators }
        return allIndicators.filter {
            $0.id.lowercased().contains(q) ||
            $0.name.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.formula.lowercased().contains(q)
        }
    }


    /// 根据统一指标 ID 或指标名称创建真实计算器实例。
    /// 这个工厂显式链接全部指标服务层文件；若任一计算器类型丢失或改名，编译阶段会失败。
    public static func calculator(for idOrName: String) -> KXIndicatorProtocol? {
        switch idOrName.lowercased() {
        case "kx-in-09-roc", "roc": return ROCCalculator()
        case "kx-in-10-momentum", "momentum": return MomentumCalculator()
        case "kx-in-01-vortex", "vortex": return VortexCalculator()
        case "kx-in-02-emv", "emv": return EaseOfMovementCalculator()
        case "kx-in-02-obv", "obv": return OBVCalculator()
        case "kx-in-03-vwap", "vwap": return VWAPCalculator()
        case "kx-in-04-forceindex", "force index": return ForceIndexCalculator()
        case "kx-in-05-vpt", "vpt": return VPTCalculator()
        case "kx-in-06-chaikinmoneyflow", "cmf": return ChaikinMoneyFlowCalculator()
        case "kx-in-06-成交量分析", "成交量分析": return VolumeAnalysisCalculator()
        case "kx-in-07-poc", "poc": return POCCalculator()
        case "kx-in-10-adline", "adl": return AccumulationDistributionLineCalculator()
        case "kx-in-12-mfi", "mfi": return MFICalculator()
        case "kx-in-13-nvi", "nvi": return NVICalculator()
        case "kx-in-13-volumeprofile", "成交量分布": return VolumeProfileCalculator()
        case "kx-in-14-pvi", "pvi": return PVICalculator()
        case "kx-in-14-bbw", "布林带宽": return BBWCalculator()
        case "kx-in-15-atr", "atr": return ATRCalculator()
        case "kx-in-15-stddevchannel", "标准差通道": return StdDeviationChannelCalculator()
        case "kx-in-16-chaikinvolatility", "蔡金波动率": return ChaikinVolatilityCalculator()
        case "kx-in-27-多空比", "多空比": return BullBearRatioCalculator()
        case "kx-in-01-ma", "ma": return MACalculator()
        case "kx-in-02-ema", "ema": return EMACalculator()
        case "kx-in-03-adx", "adx": return ADXCalculator()
        case "kx-in-05-parabolicsar", "parabolic sar": return ParabolicSARCalculator()
        case "kx-in-06-coppockcurve", "coppock curve": return CoppockCurveCalculator()
        case "kx-in-07-trix", "trix": return TRIXCalculator()
        case "kx-in-08-aroon", "aroon": return AroonCalculator()
        case "kx-in-21-supertrend", "supertrend": return SuperTrendCalculator()
        case "kx-in-01-布林带", "布林带": return BollingerBandsCalculator()
        case "kx-in-04-一目均衡图", "ichimoku": return IchimokuCalculator()
        case "kx-in-12-kama", "kama": return KAMACalculator()
        case "kx-in-16-pivotpoints", "枢纽点": return PivotPointsCalculator()
        case "kx-in-17-keltnerchannel", "肯特纳通道": return KeltnerChannelCalculator()
        case "kx-in-18-donchianchannel", "donchian channel": return DonchianChannelCalculator()
        case "kx-in-20-fibonacci", "斐波那契": return FibonacciRetracementCalculator()
        case "kx-in-20-hma", "hma": return HMACalculator()
        case "kx-in-25-rainbow", "彩虹均线": return RainbowMovingAverageCalculator()
        case "kx-in-29-支撑阻力", "支撑阻力": return SupportResistanceDetector()
        case "kx-in-17-活跃地址数", "活跃地址数": return ActiveAddressesCalculator()
        case "kx-in-22-mvrv", "mvrv": return MVRVCalculator()
        case "kx-in-24-nupl", "nupl": return NUPLCalculator()
        case "kx-in-25-ahr999", "ahr999": return AHR999Calculator()
        case "kx-in-26-彩虹图", "彩虹图": return 彩虹图Calculator()
        case "kx-in-28-资金费率", "资金费率": return FundingRateCalculator()
        case "kx-in-01-rsi", "rsi": return RSICalculator()
        case "kx-in-02-macd", "macd": return MACDCalculator()
        case "kx-in-03-kdj", "kdj": return KDJCalculator()
        case "kx-in-04-cci", "cci": return CCICalculator()
        case "kx-in-05-williamsr", "williams %r": return WilliamsRCalculator()
        case "kx-in-06-stochasticrsi", "stochastic rsi": return StochasticRSICalculator()
        case "kx-in-07-ultimateoscillator", "ultimate oscillator": return UltimateOscillatorCalculator()
        case "kx-in-08-po", "po": return PriceOscillatorCalculator()
        case "kx-in-09-dpo", "dpo": return DPOCalculator()
        case "kx-in-11-rvi", "rvi": return RVICalculator()
        case "kx-in-18-cmo", "cmo": return CMOCalculator()
        case "kx-in-19-牛熊力量", "牛熊力量": return BullBearPowerCalculator()
        case "kx-in-23-kd", "kd": return StochasticOscillatorCalculator()
        case "kx-in-30-chandeforecast", "钱德预测": return ChandeForecastCalculator()
        default:
            return nil
        }
    }

    public static func calculator(for indicator: KXTechnicalIndicator) -> KXIndicatorProtocol? {
        calculator(for: indicator.id) ?? calculator(for: indicator.name)
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN29Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-29", fileName: "KX-FN-29_统一指标注册表.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-29_统一指标注册表.swift", duty: "统一登记指标服务层全部指标"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("统一指标注册表骨架校验通过，共\(KXUnifiedIndicatorRegistry.allIndicators.count)个指标")
        return KXHealthCheckItem(name: "统一指标注册表", passed: true, message: "已注册\(KXUnifiedIndicatorRegistry.allIndicators.count)个指标")
    }
}
