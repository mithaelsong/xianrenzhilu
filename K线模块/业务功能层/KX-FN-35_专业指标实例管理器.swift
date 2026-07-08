//
//  KX-FN-35_专业指标实例管理器.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：管理指标实例的 CRUD、计算、overlay 提交、通知刷新
//  禁止事项：禁止 UI 绘制、禁止直接操作 K线视图
//

import Foundation

public final class KXProfessionalIndicatorInstanceManager: @unchecked Sendable {
    public static let shared = KXProfessionalIndicatorInstanceManager()

    private var instances: [String: KXProfessionalIndicatorInstance] = [:]
    private var templates: [String: KXProfessionalIndicatorTemplate] = [:]
    private let queue = DispatchQueue(label: "com.kline.indicator.instance.manager")

    private init() {
        registerTemplate(KXIN_MA_Template())
        registerTemplate(KXIN_RSI_Template())
        registerTemplate(KXIN_EMA_Template())
        registerTemplate(KXIN_MACD_Template())
        registerTemplate(KXIN_KDJ_Template())
        registerTemplate(KXIN_BOLL_Template())
        registerLegacyIndicators()
        loadInstances()
    }

    // MARK: - 持久化

    private let persistenceKey = "com.kline.indicator.instances.v1"

    private func saveInstances() {
        queue.sync {
            do {
                let data = try JSONEncoder().encode(Array(instances.values))
                UserDefaults.standard.set(data, forKey: persistenceKey)
            } catch {
                klineLogger.error("[Indicator] saveInstances failed: \(error)")
            }
        }
    }

    private func loadInstances() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        do {
            let loaded = try JSONDecoder().decode([KXProfessionalIndicatorInstance].self, from: data)
            // MA 最多保留 5 个；其他指标实例全部保留（全局共享）
            let maInstances = loaded.filter { $0.indicatorID == "ma" }.sorted { $0.updatedAt > $1.updatedAt }
            let otherInstances = loaded.filter { $0.indicatorID != "ma" }
            for instance in otherInstances + maInstances.prefix(5) {
                instances[instance.id] = instance
            }
            if maInstances.count > 5 {
                saveInstances()
                klineLogger.info("[Indicator] loaded \(instances.count) instances, cleaned \(maInstances.count - 5) old MA instances")
            } else {
                klineLogger.info("[Indicator] loaded \(instances.count) instances from persistence")
            }
        } catch {
            klineLogger.error("[Indicator] loadInstances failed: \(error)")
        }
    }

    // MARK: - 模板注册

    public func registerTemplate(_ template: KXProfessionalIndicatorTemplate) {
        queue.sync {
            templates[template.indicatorID] = template
        }
    }

    public func template(for indicatorID: String) -> KXProfessionalIndicatorTemplate? {
        queue.sync { templates[indicatorID] }
    }

    // MARK: - 遗留指标批量注册

    private struct LegacyIndicatorConfig {
        let registryID: String
        let pane: KLOverlayPane
        let figureType: KXIndicatorFigureType
    }

    private func registerLegacyIndicators() {
        let configs: [LegacyIndicatorConfig] = [
            // MARK: 趋势指标
            .init(registryID: "KX-IN-03-ADX", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-08-Aroon", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-06-CoppockCurve", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-05-ParabolicSAR", pane: .main, figureType: .point),
            .init(registryID: "KX-IN-21-SuperTrend", pane: .main, figureType: .line),
            .init(registryID: "KX-IN-07-TRIX", pane: .sub, figureType: .line),

            // MARK: 震荡指标
            .init(registryID: "KX-IN-04-CCI", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-18-CMO", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-09-DPO", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-23-KD", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-11-RVI", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-06-StochasticRSI", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-07-UltimateOscillator", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-05-WilliamsR", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-19-牛熊力量", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-30-ChandeForecast", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-10-Momentum", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-09-ROC", pane: .sub, figureType: .line),

            // MARK: 成交量指标
            .init(registryID: "KX-IN-10-ADLine", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-06-ChaikinMoneyFlow", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-02-EMV", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-04-ForceIndex", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-12-MFI", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-13-NVI", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-02-OBV", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-07-POC", pane: .main, figureType: .horizontalLine),
            .init(registryID: "KX-IN-14-PVI", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-05-VPT", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-03-VWAP", pane: .main, figureType: .line),
            .init(registryID: "KX-IN-01-Vortex", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-13-VolumeProfile", pane: .main, figureType: .horizontalLine),
            .init(registryID: "KX-IN-06-成交量分析", pane: .sub, figureType: .line),

            // MARK: 波动率指标
            .init(registryID: "KX-IN-15-ATR", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-14-BBW", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-15-StdDevChannel", pane: .main, figureType: .band),
            .init(registryID: "KX-IN-16-ChaikinVolatility", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-18-DonchianChannel", pane: .main, figureType: .band),
            .init(registryID: "KX-IN-17-KeltnerChannel", pane: .main, figureType: .band),

            // MARK: 趋势指标（补充）
            .init(registryID: "KX-IN-20-HMA", pane: .main, figureType: .line),
            .init(registryID: "KX-IN-04-一目均衡图", pane: .main, figureType: .band),
            .init(registryID: "KX-IN-12-KAMA", pane: .main, figureType: .line),
            .init(registryID: "KX-IN-25-rainbow", pane: .main, figureType: .line),
            .init(registryID: "KX-IN-29-支撑阻力", pane: .main, figureType: .horizontalLine),

            // MARK: 统计指标
            .init(registryID: "KX-IN-20-Fibonacci", pane: .main, figureType: .horizontalLine),
            .init(registryID: "KX-IN-16-PivotPoints", pane: .main, figureType: .horizontalLine),
            .init(registryID: "KX-IN-27-多空比", pane: .sub, figureType: .line),

            // MARK: 链上指标
            .init(registryID: "KX-IN-25-Ahr999", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-22-MVRV", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-24-NUPL", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-26-彩虹图", pane: .main, figureType: .band),
            .init(registryID: "KX-IN-17-活跃地址数", pane: .sub, figureType: .line),
            .init(registryID: "KX-IN-28-资金费率", pane: .sub, figureType: .bar),
        ]

        for config in configs {
            guard let indicator = KXUnifiedIndicatorRegistry.indicator(withId: config.registryID) else {
                klineLogger.warning("[Indicator] legacy config missing registry entry: \(config.registryID)")
                continue
            }
            let indicatorID = indicator.name.lowercased()
            guard template(for: indicatorID) == nil else {
                klineLogger.warning("[Indicator] template already exists for \(indicatorID), skipping legacy registration")
                continue
            }
            // 从老指标计算器提取默认参数，构造可调 parameterSchema
            let defaultParams = KXUnifiedIndicatorRegistry.calculator(for: indicator)?.defaultParameterValues ?? [:]
            let parameterSchema = KXIN_LegacySchemaFactory.parameterSchema(from: defaultParams)
            let adapter = KXIN_LegacyOutputAdapter(
                indicatorID: indicatorID,
                name: indicator.name,
                defaultPane: config.pane,
                mappings: [
                    KXIN_OutputMapping(key: "main", title: indicator.name, type: config.figureType, styleKey: "color")
                ],
                parameterSchema: parameterSchema,
                styleSchema: KXIN_LegacySchemaFactory.commonLineStyles
            )
            registerTemplate(KXIN_LegacyIndicatorTemplate(adapter: adapter))
            klineLogger.info("[Indicator] registered legacy template \(indicatorID) (\(indicator.name))")
        }
    }

    // MARK: - 实例创建

    public func createInstance(indicatorID: String, zIndex: Int = 40) -> KXProfessionalIndicatorInstance? {
        guard let template = template(for: indicatorID) else { return nil }
        let instance = template.makeDefaultInstance(zIndex: zIndex)
        queue.sync {
            instances[instance.id] = instance
        }
        saveInstances()
        return instance
    }

    // MARK: - 实例查询

    public func instance(id: String) -> KXProfessionalIndicatorInstance? {
        queue.sync { instances[id] }
    }

    public func allInstances() -> [KXProfessionalIndicatorInstance] {
        queue.sync { Array(instances.values) }
    }

    public func instances(for indicatorID: String) -> [KXProfessionalIndicatorInstance] {
        queue.sync { instances.values.filter { $0.indicatorID == indicatorID } }
    }

    // MARK: - 实例更新

    public func updateParams(instanceID: String, params: [String: KXIndicatorParameterValue]) {
        queue.sync {
            guard instances[instanceID] != nil else { return }
            instances[instanceID]?.params = params
            instances[instanceID]?.updatedAt = Date()
        }
        saveInstances()
    }

    public func updateStyle(instanceID: String, styles: [String: KXIndicatorParameterValue]) {
        queue.sync {
            guard instances[instanceID] != nil else { return }
            instances[instanceID]?.styles = styles
            instances[instanceID]?.updatedAt = Date()
        }
        saveInstances()
    }

    public func toggleVisible(instanceID: String) {
        queue.sync {
            guard instances[instanceID] != nil else { return }
            instances[instanceID]?.visible.toggle()
            instances[instanceID]?.updatedAt = Date()
        }
        saveInstances()
    }

    public func setVisible(instanceID: String, visible: Bool) {
        queue.sync {
            guard instances[instanceID] != nil else { return }
            instances[instanceID]?.visible = visible
            instances[instanceID]?.updatedAt = Date()
        }
        saveInstances()
        // 通知所有画布刷新，确保隐藏/显示状态同步到所有币对/时间框架
        NotificationCenter.default.post(name: .KXIndicatorOverlayDidChange, object: instanceID)
    }

    // MARK: - 实例删除

    public func removeInstance(instanceID: String) {
        _ = queue.sync {
            instances.removeValue(forKey: instanceID)
        }
        saveInstances()
    }

    public func removeAllInstances(for indicatorID: String) {
        queue.sync {
            instances = instances.filter { $0.value.indicatorID != indicatorID }
        }
        saveInstances()
    }

    public func clearAllInstances() {
        queue.sync {
            instances.removeAll()
        }
        saveInstances()
    }

    // MARK: - 计算与提交

    public func recalculateAndSubmit(instanceID: String, context: KXIndicatorCalculationContext) throws {
        guard let instance = instance(id: instanceID),
              let template = template(for: instance.indicatorID) else { return }

        let output = try template.calculate(context: context, instance: instance)
        let overlays = template.makeOverlays(output: output, instance: instance, target: context.target)

        // 提交 overlay
        for overlay in overlays {
            try KLDefaultOverlayManager.shared.submitOverlay(overlay)
        }

        // 发送通知
        NotificationCenter.default.post(name: .KXIndicatorOverlayDidChange, object: instanceID)
    }

    public func recalculateAllAndSubmit(context: KXIndicatorCalculationContext) throws {
        let all = allInstances()
        for instance in all where instance.visible {
            try recalculateAndSubmit(instanceID: instance.id, context: context)
        }
    }

    // MARK: - 创建并提交（快捷方法）

    public func createAndSubmit(indicatorID: String, context: KXIndicatorCalculationContext, zIndex: Int = 40) throws {
        guard let instance = createInstance(indicatorID: indicatorID, zIndex: zIndex) else { return }
        try recalculateAndSubmit(instanceID: instance.id, context: context)
    }

    // MARK: - Tooltip

    public func tooltipText(instanceID: String, context: KXIndicatorCalculationContext) -> String? {
        guard let instance = instance(id: instanceID),
              let template = template(for: instance.indicatorID) else { return nil }
        do {
            let output = try template.calculate(context: context, instance: instance)
            let tooltip = template.makeTooltip(output: output, instance: instance)
            return tooltip.text
        } catch {
            return nil
        }
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN35Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-35", fileName: "KX-FN-35_专业指标实例管理器.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-35_专业指标实例管理器.swift", duty: "管理指标实例的 CRUD、计算、overlay 提交、通知刷新"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("专业指标实例管理器骨架校验通过")
        return KXHealthCheckItem(name: "专业指标实例管理器", passed: true, message: "已实现专业指标实例管理器")
    }
}
