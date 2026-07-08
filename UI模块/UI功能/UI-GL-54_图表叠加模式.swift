// 功能44: 图表叠加模式
// 对应: 在同一区域叠加显示多个数据系列，支持不同数据源的叠加、颜色配置、透明度调节、Y轴自动缩放
// 优先级: P2

import AppKit
import Foundation
import os.log

// MARK: - 全局日志对象
/// 图表叠加模块专用日志记录器
private let logger = Logger(subsystem: "com.xianrenzhilu.overlay", category: "ChartOverlayManager")

// MARK: - 通知名称扩展
/// 图表叠加模块相关通知
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {



// MARK: - 测试代码
#if DEBUG

/// 功能44：图表叠加模式 — 单元测试
func test_overlay() {
    let manager = UIChartOverlayManager.shared
    
    logger.info("测试1: 默认状态")
    if !manager.isOverlayModeEnabled { logger.info("✅ 测试1通过: 默认未启用") }
    else { logger.error("❌ 测试1失败") }
    
    logger.info("测试2: 启用/禁用")
    manager.setOverlayModeEnabled(true)
    if manager.isOverlayModeEnabled { logger.info("✅ 测试2通过") }
    else { logger.error("❌ 测试2失败") }
    manager.setOverlayModeEnabled(false)
    
    logger.info("测试3: 添加系列")
    let series = UIOverlayDataSeries(label: "测试系列", sourceIdentifier: "test")
    let id = manager.addSeries(series)
    if !id.isEmpty { logger.info("✅ 测试3通过: id=\(id)") }
    else { logger.error("❌ 测试3失败") }
    
    logger.info("测试4: 系列查询")
    let found = manager.series(by: id)
    if found?.label == "测试系列" { logger.info("✅ 测试4通过") }
    else { logger.error("❌ 测试4失败") }
    
    logger.info("测试5: seriesCount")
    if manager.seriesCount == 1 { logger.info("✅ 测试5通过") }
    else { logger.error("❌ 测试5失败") }
    
    logger.info("测试6: 可见性")
    manager.setSeriesVisible(id: id, visible: false)
    if manager.visibleSeriesCount == 0 { logger.info("✅ 测试6通过") }
    else { logger.error("❌ 测试6失败") }
    manager.setSeriesVisible(id: id, visible: true)
    
    logger.info("测试7: 样式设置")
    manager.setSeriesColor(id: id, color: .systemRed)
    let updated = manager.series(by: id)
    if updated?.colorHex == NSColor.systemRed.hexString { logger.info("✅ 测试7通过") }
    else { logger.error("❌ 测试7失败") }
    
    logger.info("测试8: Y轴范围")
    let range = manager.yAxisRange
    _ = range
    logger.info("✅ 测试8通过")
    
    logger.info("测试9: 设置面板")
    let settings = manager.settingsConfiguration()
    _ = settings
    logger.info("✅ 测试9通过")
    
    logger.info("测试10: 导出配置")
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("overlay_test.json")
    if manager.exportConfiguration(to: tempURL) { logger.info("✅ 测试10通过") }
    else { logger.error("❌ 测试10失败") }
    
    logger.info("=== 全部图表叠加测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension NSColor
extension NSColor {
    /// 从十六进制字符串创建NSColor
    static func fromHexString(_ hex: String) -> NSColor? {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimmed.replacingOccurrences(of: "#", with: "")

        guard trimmed.count == 6 || trimmed.count == 8 else { return nil }

        var rgba: UInt64 = 0
        guard Scanner(string: trimmed).scanHexInt64(&rgba) else { return nil }

        let r, g, b, a: CGFloat
        if trimmed.count == 6 {
            r = CGFloat((rgba & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgba & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgba & 0x0000FF) / 255.0
            a = 1.0
        } else {
            r = CGFloat((rgba & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgba & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgba & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgba & 0x000000FF) / 255.0
        }

        return NSColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - hexString 计算属性已在 UI-GL-49_标签页分组.swift 定义，这里仅引用不重复定义

// MARK: - 迁回自 UI-02：class UIChartOverlayManager
public final class UIChartOverlayManager : @unchecked Sendable {

    // MARK: - 单例
    /// 全局唯一实例
    public static let shared = UIChartOverlayManager()

    // MARK: - 锁保护
    /// 保护数据系列数组的轻量级锁
    private let seriesLock = NSRecursiveLock()
    /// 保护配置状态的轻量级锁
    private let configLock = NSRecursiveLock()
    /// 保护Y轴计算结果的轻量级锁
    private let yAxisLock = NSRecursiveLock()

    // MARK: - 持久化配置
    /// UserDefaults存储键：叠加配置
    private let configSaveKey = "com.xianrenzhilu.overlayConfiguration"
    /// 文件管理器
    private let fileManager = FileManager.default
    /// 应用支持目录下的叠加数据文件夹
    private var overlayDataDirectory: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("XianRenZhiLu/Overlay", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }

    // MARK: - 内部状态
    /// 当前叠加模式是否启用
    public private(set) var isOverlayModeEnabled: Bool = false
    /// 所有数据系列（受seriesLock保护）
    private var seriesList: [UIOverlayDataSeries] = []
    /// 是否启用Y轴自动缩放
    public var autoScaleYAxis: Bool = true
    /// Y轴顶部留白比例
    public var yAxisPaddingTop: Double = 0.05
    /// Y轴底部留白比例
    public var yAxisPaddingBottom: Double = 0.05
    /// 是否显示图例
    public var showLegend: Bool = true
    /// 图例位置
    public var legendPosition: Int = 1
    /// 当前计算出的Y轴范围（受yAxisLock保护）
    private var currentYAxisRange: UIOverlayYAxisRange = UIOverlayYAxisRange()
    /// 配置版本号
    private let currentVersion: Double = 2.0

    // MARK: - 初始化与销毁
    /// 私有初始化，确保单例
    private init() {
        logger.info("图表叠加管理器初始化开始")
        loadConfigurationFromDisk()
        recalculateYAxisRange()
        logger.info("图表叠加管理器初始化完成，已加载 \(self.seriesCount) 个数据系列")
    }

    /// 销毁时清理资源并保存配置
    deinit {
        logger.info("图表叠加管理器正在销毁，执行清理工作")
        // 保存未持久化的配置
        saveConfigurationToDisk()
        // 清空内存数据（单例deinit，跳过锁）
        seriesList.removeAll()
        logger.info("图表叠加管理器销毁完成，资源已释放")
    }

    // MARK: - 叠加模式开关
    /// 启用或禁用叠加模式
    /// - Parameter enabled: 是否启用
    public func setOverlayModeEnabled(_ enabled: Bool) {
        configLock.lock()
        let oldValue = isOverlayModeEnabled
        isOverlayModeEnabled = enabled
        configLock.unlock()

        if oldValue != enabled {
            saveConfigurationToDisk()
            NotificationCenter.default.post(
                name: .chartOverlayModeChanged,
                object: self,
                userInfo: ["isEnabled": enabled]
            )
            logger.info("叠加模式状态变更: \(enabled ? "启用" : "禁用")")
        }
    }

    /// 切换叠加模式开关状态
    public func toggleOverlayMode() {
        configLock.lock()
        let enabled = isOverlayModeEnabled
        configLock.unlock()
        setOverlayModeEnabled(!enabled)
    }

    // MARK: - 数据系列查询
    /// 获取所有数据系列（线程安全副本）
    public var allSeries: [UIOverlayDataSeries] {
        seriesLock.lock()
        let result = seriesList
        seriesLock.unlock()
        return result
    }

    /// 获取所有可见的数据系列
    public var visibleSeries: [UIOverlayDataSeries] {
        seriesLock.lock()
        let result = seriesList.filter { $0.isVisible }
        seriesLock.unlock()
        return result
    }

    /// 获取参与Y轴计算的数据系列
    public var yAxisAffectingSeries: [UIOverlayDataSeries] {
        seriesLock.lock()
        let result = seriesList.filter { $0.isVisible && $0.affectsYAxis && !$0.dataPoints.isEmpty }
        seriesLock.unlock()
        return result
    }

    /// 当前数据系列总数
    public var seriesCount: Int {
        seriesLock.lock()
        let count = seriesList.count
        seriesLock.unlock()
        return count
    }

    /// 可见数据系列数量
    public var visibleSeriesCount: Int {
        seriesLock.lock()
        let count = seriesList.filter { $0.isVisible }.count
        seriesLock.unlock()
        return count
    }

    /// 根据ID获取单个数据系列
    /// - Parameter id: 系列标识符
    /// - Returns: 匹配的数据系列（不存在时返回nil）
    public func series(by id: String) -> UIOverlayDataSeries? {
        seriesLock.lock()
        let result = seriesList.first { $0.id == id }
        seriesLock.unlock()
        return result
    }

    /// 根据数据源标识筛选系列
    /// - Parameter source: 数据源标识
    public func series(from source: String) -> [UIOverlayDataSeries] {
        seriesLock.lock()
        let result = seriesList.filter { $0.sourceIdentifier == source }
        seriesLock.unlock()
        return result
    }

    /// 获取所有唯一的数据源标识列表
    public var allSourceIdentifiers: [String] {
        seriesLock.lock()
        let sources = Array(Set(seriesList.map { $0.sourceIdentifier })).sorted()
        seriesLock.unlock()
        return sources
    }

    // MARK: - 数据系列管理（添加/删除/编辑）
    /// 添加一个新的数据系列
    /// - Parameter series: 要添加的数据系列
    /// - Returns: 添加成功的系列ID
    @discardableResult
    public func addSeries(_ series: UIOverlayDataSeries) -> String {
        seriesLock.lock()
        // 检查是否已存在同ID系列
        if let existingIndex = seriesList.firstIndex(where: { $0.id == series.id }) {
            seriesList[existingIndex] = series
            seriesLock.unlock()
            logger.warning("添加系列时ID已存在，执行替换: \(series.id)")
            saveConfigurationToDisk()
            recalculateYAxisRange()
            NotificationCenter.default.post(
                name: .chartOverlaySeriesChanged,
                object: self,
                userInfo: ["action": "replaced", "seriesID": series.id]
            )
            return series.id
        }
        seriesList.append(series)
        seriesLock.unlock()

        saveConfigurationToDisk()
        recalculateYAxisRange()
        NotificationCenter.default.post(
            name: .chartOverlaySeriesChanged,
            object: self,
            userInfo: ["action": "added", "seriesID": series.id, "series": series]
        )
        logger.info("添加数据系列: \(series.id), 名称=\(series.label), 数据点=\(series.dataPoints.count)")
        return series.id
    }

    /// 批量添加多个数据系列
    /// - Parameter seriesArray: 要添加的数据系列数组
    public func addSeriesBatch(_ seriesArray: [UIOverlayDataSeries]) {
        var addedIDs: [String] = []
        seriesLock.lock()
        for series in seriesArray {
            if !seriesList.contains(where: { $0.id == series.id }) {
                seriesList.append(series)
                addedIDs.append(series.id)
            }
        }
        seriesLock.unlock()

        guard !addedIDs.isEmpty else { return }
        saveConfigurationToDisk()
        recalculateYAxisRange()
        NotificationCenter.default.post(
            name: .chartOverlaySeriesChanged,
            object: self,
            userInfo: ["action": "batchAdded", "seriesIDs": addedIDs, "count": addedIDs.count]
        )
        logger.info("批量添加数据系列，共 \(addedIDs.count) 个")
    }

    /// 删除指定数据系列
    /// - Parameter id: 要删除的系列ID
    public func removeSeries(id: String) {
        seriesLock.lock()
        guard let index = seriesList.firstIndex(where: { $0.id == id }) else {
            seriesLock.unlock()
            logger.warning("尝试删除不存在的系列: \(id)")
            return
        }
        let removed = seriesList.remove(at: index)
        seriesLock.unlock()

        saveConfigurationToDisk()
        recalculateYAxisRange()
        NotificationCenter.default.post(
            name: .chartOverlaySeriesChanged,
            object: self,
            userInfo: ["action": "removed", "seriesID": id, "removedSeries": removed]
        )
        logger.info("删除数据系列: \(id), 名称=\(removed.label)")
    }

    /// 批量删除多个数据系列
    /// - Parameter ids: 要删除的系列ID数组
    public func removeSeriesBatch(ids: [String]) {
        var removedCount = 0
        seriesLock.lock()
        for id in ids {
            if let index = seriesList.firstIndex(where: { $0.id == id }) {
                seriesList.remove(at: index)
                removedCount += 1
            }
        }
        seriesLock.unlock()

        guard removedCount > 0 else { return }
        saveConfigurationToDisk()
        recalculateYAxisRange()
        NotificationCenter.default.post(
            name: .chartOverlaySeriesChanged,
            object: self,
            userInfo: ["action": "batchRemoved", "count": removedCount]
        )
        logger.info("批量删除数据系列，共 \(removedCount) 个")
    }

    /// 清空所有数据系列
    public func clearAllSeries() {
        seriesLock.lock()
        let count = seriesList.count
        seriesList.removeAll()
        seriesLock.unlock()

        saveConfigurationToDisk()
        recalculateYAxisRange()
        NotificationCenter.default.post(
            name: .chartOverlaySeriesChanged,
            object: self,
            userInfo: ["action": "cleared", "count": count]
        )
        logger.info("清空所有数据系列，共 \(count) 个")
    }

    /// 更新数据系列的数据点
    /// - Parameters:
    ///   - id: 系列ID
    ///   - dataPoints: 新的数据点数组
    public func updateSeriesDataPoints(id: String, dataPoints: [UIOverlayDataPoint]) {
        seriesLock.lock()
        guard let index = seriesList.firstIndex(where: { $0.id == id }) else {
            seriesLock.unlock()
            logger.warning("更新数据点失败，系列不存在: \(id)")
            return
        }
        seriesList[index].dataPoints = dataPoints
        seriesList[index].updatedAt = Date().timeIntervalSince1970
        seriesLock.unlock()

        recalculateYAxisRange()
        NotificationCenter.default.post(
            name: .chartOverlaySeriesChanged,
            object: self,
            userInfo: ["action": "dataUpdated", "seriesID": id, "pointCount": dataPoints.count]
        )
        logger.debug("更新系列数据点: \(id), 共 \(dataPoints.count) 个")
    }

    /// 更新数据系列的标签名称
    /// - Parameters:
    ///   - id: 系列ID
    ///   - label: 新标签名称
    public func updateSeriesLabel(id: String, label: String) {
        seriesLock.lock()
        guard let index = seriesList.firstIndex(where: { $0.id == id }) else {
            seriesLock.unlock()
            return
        }
        seriesList[index].label = label
        seriesList[index].updatedAt = Date().timeIntervalSince1970
        seriesLock.unlock()

        saveConfigurationToDisk()
        NotificationCenter.default.post(
            name: .chartOverlaySeriesChanged,
            object: self,
            userInfo: ["action": "labelUpdated", "seriesID": id, "newLabel": label]
        )
        logger.debug("更新系列标签: \(id) -> \(label)")
    }

    // MARK: - 可见性管理
    /// 设置数据系列的可见性
    /// - Parameters:
    ///   - id: 系列ID
    ///   - visible: 是否可见
    public func setSeriesVisible(id: String, visible: Bool) {
        seriesLock.lock()
        guard let index = seriesList.firstIndex(where: { $0.id == id }) else {
            seriesLock.unlock()
            return
        }
        let oldValue = seriesList[index].isVisible
        seriesList[index].isVisible = visible
        seriesLock.unlock()

        if oldValue != visible {
            saveConfigurationToDisk()
            recalculateYAxisRange()
            NotificationCenter.default.post(
                name: .chartOverlayVisibilityChanged,
                object: self,
                userInfo: ["seriesID": id, "isVisible": visible]
            )
            logger.debug("设置系列可见性: \(id), visible=\(visible)")
        }
    }

    /// 切换数据系列的可见性
    /// - Parameter id: 系列ID
    public func toggleSeriesVisibility(id: String) {
        seriesLock.lock()
        guard let index = seriesList.firstIndex(where: { $0.id == id }) else {
            seriesLock.unlock()
            return
        }
        seriesList[index].isVisible.toggle()
        let newValue = seriesList[index].isVisible
        seriesLock.unlock()

        saveConfigurationToDisk()
        recalculateYAxisRange()
        NotificationCenter.default.post(
            name: .chartOverlayVisibilityChanged,
            object: self,
            userInfo: ["seriesID": id, "isVisible": newValue]
        )
        logger.debug("切换系列可见性: \(id), visible=\(newValue)")
    }

    /// 隐藏所有数据系列
    public func hideAllSeries() {
        var changedIDs: [String] = []
        seriesLock.lock()
        for index in seriesList.indices where seriesList[index].isVisible {
            seriesList[index].isVisible = false
            changedIDs.append(seriesList[index].id)
        }
        seriesLock.unlock()

        guard !changedIDs.isEmpty else { return }
        saveConfigurationToDisk()
        recalculateYAxisRange()
        NotificationCenter.default.post(
            name: .chartOverlayVisibilityChanged,
            object: self,
            userInfo: ["action": "hideAll", "seriesIDs": changedIDs]
        )
        logger.info("隐藏所有数据系列，共 \(changedIDs.count) 个")
    }

    /// 显示所有数据系列
    public func showAllSeries() {
        var changedIDs: [String] = []
        seriesLock.lock()
        for index in seriesList.indices where !seriesList[index].isVisible {
            seriesList[index].isVisible = true
            changedIDs.append(seriesList[index].id)
        }
        seriesLock.unlock()

        guard !changedIDs.isEmpty else { return }
        saveConfigurationToDisk()
        recalculateYAxisRange()
        NotificationCenter.default.post(
            name: .chartOverlayVisibilityChanged,
            object: self,
            userInfo: ["action": "showAll", "seriesIDs": changedIDs]
        )
        logger.info("显示所有数据系列，共 \(changedIDs.count) 个")
    }

    // MARK: - 样式管理（颜色/透明度/线宽/线型）
    /// 设置数据系列的颜色
    /// - Parameters:
    ///   - id: 系列ID
    ///   - color: NSColor颜色对象
    public func setSeriesColor(id: String, color: NSColor) {
        let hex = color.hexString
        seriesLock.lock()
        guard let index = seriesList.firstIndex(where: { $0.id == id }) else {
            seriesLock.unlock()
            return
        }
        seriesList[index].colorHex = hex
        seriesList[index].updatedAt = Date().timeIntervalSince1970
        seriesLock.unlock()

        saveConfigurationToDisk()
        NotificationCenter.default.post(
            name: .chartOverlayStyleChanged,
            object: self,
            userInfo: ["seriesID": id, "changeType": "color", "colorHex": hex]
        )
        logger.debug("设置系列颜色: \(id), hex=\(hex)")
    }

    /// 设置数据系列的透明度
    /// - Parameters:
    ///   - id: 系列ID
    ///   - alpha: 不透明度（0.0 ~ 1.0）
    public func setSeriesAlpha(id: String, alpha: Double) {
        let clampedAlpha = max(0.0, min(1.0, alpha))
        seriesLock.lock()
        guard let index = seriesList.firstIndex(where: { $0.id == id }) else {
            seriesLock.unlock()
            return
        }
        seriesList[index].alpha = clampedAlpha
        seriesList[index].updatedAt = Date().timeIntervalSince1970
        seriesLock.unlock()

        saveConfigurationToDisk()
        NotificationCenter.default.post(
            name: .chartOverlayStyleChanged,
            object: self,
            userInfo: ["seriesID": id, "changeType": "alpha", "alpha": clampedAlpha]
        )
        logger.debug("设置系列透明度: \(id), alpha=\(clampedAlpha)")
    }

    /// 设置数据系列的线条宽度
    /// - Parameters:
    ///   - id: 系列ID
    ///   - width: 线条宽度（像素，最小0.5）
    public func setSeriesLineWidth(id: String, width: CGFloat) {
        let clampedWidth = max(0.5, width)
        seriesLock.lock()
        guard let index = seriesList.firstIndex(where: { $0.id == id }) else {
            seriesLock.unlock()
            return
        }
        seriesList[index].lineWidth = clampedWidth
        seriesList[index].updatedAt = Date().timeIntervalSince1970
        seriesLock.unlock()

        saveConfigurationToDisk()
        NotificationCenter.default.post(
            name: .chartOverlayStyleChanged,
            object: self,
            userInfo: ["seriesID": id, "changeType": "lineWidth", "lineWidth": clampedWidth]
        )
        logger.debug("设置系列线宽: \(id), width=\(clampedWidth)")
    }

    /// 设置数据系列的线型样式
    /// - Parameters:
    ///   - id: 系列ID
    ///   - style: 线型样式
    public func setSeriesLineStyle(id: String, style: UIOverlayLineStyle) {
        seriesLock.lock()
        guard let index = seriesList.firstIndex(where: { $0.id == id }) else {
            seriesLock.unlock()
            return
        }
        seriesList[index].lineStyle = style
        seriesList[index].updatedAt = Date().timeIntervalSince1970
        seriesLock.unlock()

        saveConfigurationToDisk()
        NotificationCenter.default.post(
            name: .chartOverlayStyleChanged,
            object: self,
            userInfo: ["seriesID": id, "changeType": "lineStyle", "lineStyle": style.rawValue]
        )
        logger.debug("设置系列线型: \(id), style=\(style.displayName)")
    }

    /// 设置数据系列的Z轴排序权重
    /// - Parameters:
    ///   - id: 系列ID
    ///   - zIndex: 排序权重（数值越小越靠前）
    public func setSeriesZIndex(id: String, zIndex: Int) {
        seriesLock.lock()
        guard let index = seriesList.firstIndex(where: { $0.id == id }) else {
            seriesLock.unlock()
            return
        }
        seriesList[index].zIndex = zIndex
        seriesList[index].updatedAt = Date().timeIntervalSince1970
        seriesLock.unlock()

        // 按zIndex排序，确保绘制顺序正确
        sortSeriesByZIndex()
        saveConfigurationToDisk()
        NotificationCenter.default.post(
            name: .chartOverlayStyleChanged,
            object: self,
            userInfo: ["seriesID": id, "changeType": "zIndex", "zIndex": zIndex]
        )
        logger.debug("设置系列Z轴顺序: \(id), zIndex=\(zIndex)")
    }

    /// 按zIndex对数据系列排序
    private func sortSeriesByZIndex() {
        seriesLock.lock()
        seriesList.sort { $0.zIndex < $1.zIndex }
        seriesLock.unlock()
    }

    // MARK: - Y轴自动缩放
    /// 根据所有可见且参与缩放的数据系列重新计算Y轴范围
    public func recalculateYAxisRange() {
        let affectingSeries = yAxisAffectingSeries

        guard !affectingSeries.isEmpty else {
            yAxisLock.lock()
            currentYAxisRange = UIOverlayYAxisRange(min: 0, max: 100, precision: 2)
            yAxisLock.unlock()
            return
        }

        var globalMin: Double = .infinity
        var globalMax: Double = -.infinity

        for series in affectingSeries {
            if let minVal = series.minValue, let maxVal = series.maxValue {
                globalMin = min(globalMin, minVal)
                globalMax = max(globalMax, maxVal)
            }
        }

        // 计算留白
        let span = globalMax - globalMin
        let paddedMin = globalMin - span * yAxisPaddingBottom
        let paddedMax = globalMax + span * yAxisPaddingTop

        // 计算精度（根据数据范围自动推断小数位数）
        let precision = calculatePrecision(for: span)

        let newRange = UIOverlayYAxisRange(min: paddedMin, max: paddedMax, precision: precision)

        yAxisLock.lock()
        let oldRange = currentYAxisRange
        currentYAxisRange = newRange
        yAxisLock.unlock()

        if oldRange != newRange {
            NotificationCenter.default.post(
                name: .chartOverlayYAxisRangeChanged,
                object: self,
                userInfo: ["range": newRange, "oldRange": oldRange]
            )
            logger.debug("Y轴范围更新: [\(newRange.min), \(newRange.max)], precision=\(precision)")
        }
    }

    /// 获取当前Y轴范围（线程安全）
    public var yAxisRange: UIOverlayYAxisRange {
        yAxisLock.lock()
        let range = currentYAxisRange
        yAxisLock.unlock()
        return range
    }

    /// 根据数据跨度计算合适的显示精度
    private func calculatePrecision(for span: Double) -> Int {
        guard span > 0 else { return 2 }
        let magnitude = log10(span)
        if magnitude >= 4 { return 0 }
        if magnitude >= 2 { return 1 }
        if magnitude >= 0 { return 2 }
        if magnitude >= -2 { return 4 }
        return 6
    }

    // MARK: - 叠加显示辅助方法
    /// 获取所有可见系列按zIndex排序后的列表（用于绘制）
    public var sortedVisibleSeries: [UIOverlayDataSeries] {
        seriesLock.lock()
        let result = seriesList.filter { $0.isVisible }.sorted { $0.zIndex < $1.zIndex }
        seriesLock.unlock()
        return result
    }

    /// 获取指定时间范围内的数据点（用于绘制区域裁剪）
    /// - Parameters:
    ///   - id: 系列ID
    ///   - from: 起始时间戳
    ///   - to: 结束时间戳
    public func dataPointsInRange(id: String, from: TimeInterval, to: TimeInterval) -> [UIOverlayDataPoint] {
        seriesLock.lock()
        guard let series = seriesList.first(where: { $0.id == id }) else {
            seriesLock.unlock()
            return []
        }
        let points = series.dataPoints.filter { $0.timestamp >= from && $0.timestamp <= to }
        seriesLock.unlock()
        return points
    }

    /// 获取所有可见系列的时间范围交集
    public var commonTimeRange: (min: TimeInterval, max: TimeInterval)? {
        let visible = visibleSeries
        guard !visible.isEmpty else { return nil }
        var minTime: TimeInterval = .infinity
        var maxTime: TimeInterval = 0
        for series in visible {
            if let range = series.timeRange {
                minTime = min(minTime, range.min)
                maxTime = max(maxTime, range.max)
            }
        }
        guard minTime != .infinity else { return nil }
        return (min: minTime, max: maxTime)
    }

    /// 生成预设颜色（用于为新系列分配默认颜色）
    public func nextPresetColor() -> NSColor {
        let presetColors: [NSColor] = [
            .systemBlue,
            .systemRed,
            .systemGreen,
            .systemOrange,
            .systemPurple,
            .systemTeal,
            .systemYellow,
            .systemPink,
            .systemBrown,
            .systemIndigo
        ]
        let count = seriesCount
        return presetColors[count % presetColors.count]
    }

    // MARK: - 设置面板方法
    /// 返回设置面板需要的完整配置字典
    public struct UIOverlaySettingsSummary {
        public let isOverlayModeEnabled: Bool
        public let seriesCount: Int
        public let visibleSeriesCount: Int
        public let autoScaleYAxis: Bool
        public let yAxisPaddingTop: Double
        public let yAxisPaddingBottom: Double
        public let showLegend: Bool
        public let legendPosition: Int
        public let yAxisRange: UIOverlayYAxisRange
        public let allSourceIdentifiers: [String]
        
        public init(isOverlayModeEnabled: Bool, seriesCount: Int, visibleSeriesCount: Int, autoScaleYAxis: Bool, yAxisPaddingTop: Double, yAxisPaddingBottom: Double, showLegend: Bool, legendPosition: Int, yAxisRange: UIOverlayYAxisRange, allSourceIdentifiers: [String]) {
            self.isOverlayModeEnabled = isOverlayModeEnabled
            self.seriesCount = seriesCount
            self.visibleSeriesCount = visibleSeriesCount
            self.autoScaleYAxis = autoScaleYAxis
            self.yAxisPaddingTop = yAxisPaddingTop
            self.yAxisPaddingBottom = yAxisPaddingBottom
            self.showLegend = showLegend
            self.legendPosition = legendPosition
            self.yAxisRange = yAxisRange
            self.allSourceIdentifiers = allSourceIdentifiers
        }
    }
    
    public func settingsConfiguration() -> UIOverlaySettingsSummary {
        return UIOverlaySettingsSummary(
            isOverlayModeEnabled: isOverlayModeEnabled,
            seriesCount: seriesCount,
            visibleSeriesCount: visibleSeriesCount,
            autoScaleYAxis: autoScaleYAxis,
            yAxisPaddingTop: yAxisPaddingTop,
            yAxisPaddingBottom: yAxisPaddingBottom,
            showLegend: showLegend,
            legendPosition: legendPosition,
            yAxisRange: yAxisRange,
            allSourceIdentifiers: allSourceIdentifiers
        )
    }

    /// 从设置面板应用配置更新
    /// - Parameter config: 配置字典
    public func applySettings(_ config: UIOverlaySettingsSummary) {
        setOverlayModeEnabled(config.isOverlayModeEnabled)
        configLock.lock()
        autoScaleYAxis = config.autoScaleYAxis
        yAxisPaddingTop = max(0, min(0.5, config.yAxisPaddingTop))
        yAxisPaddingBottom = max(0, min(0.5, config.yAxisPaddingBottom))
        showLegend = config.showLegend
        legendPosition = max(0, min(3, config.legendPosition))
        configLock.unlock()
        saveConfigurationToDisk()
        recalculateYAxisRange()
        logger.info("应用设置面板配置完成")
    }

    /// 重置所有设置为默认值
    public func resetSettingsToDefault() {
        configLock.lock()
        isOverlayModeEnabled = false
        autoScaleYAxis = true
        yAxisPaddingTop = 0.05
        yAxisPaddingBottom = 0.05
        showLegend = true
        legendPosition = 1
        configLock.unlock()

        seriesLock.lock()
        seriesList.removeAll()
        seriesLock.unlock()

        saveConfigurationToDisk()
        recalculateYAxisRange()
        logger.info("设置已重置为默认值")
    }

    // MARK: - 持久化方法
    /// 将当前叠加配置保存到磁盘（UserDefaults + 文件双保险）
    private func saveConfigurationToDisk() {
        do {
            seriesLock.lock()
            configLock.lock()
            let config = UIOverlayConfiguration(
                isEnabled: isOverlayModeEnabled,
                seriesList: seriesList,
                autoScaleYAxis: autoScaleYAxis,
                yAxisPaddingTop: yAxisPaddingTop,
                yAxisPaddingBottom: yAxisPaddingBottom,
                showLegend: showLegend,
                legendPosition: legendPosition,
                version: currentVersion
            )
            configLock.unlock()
            seriesLock.unlock()

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)

            UserDefaults.standard.set(data, forKey: configSaveKey)

            // 同时写入文件系统作为备份
            if let dir = overlayDataDirectory {
                let fileURL = dir.appendingPathComponent("overlay_config.json")
                try data.write(to: fileURL)
            }
        } catch {
            logger.error("保存叠加配置失败: \(error.localizedDescription)")
        }
    }

    /// 从磁盘加载叠加配置
    private func loadConfigurationFromDisk() {
        // 优先从文件加载
        if let dir = overlayDataDirectory {
            let fileURL = dir.appendingPathComponent("overlay_config.json")
            if fileManager.fileExists(atPath: fileURL.path),
               let data = try? Data(contentsOf: fileURL) {
                do {
                    let decoded = try JSONDecoder().decode(UIOverlayConfiguration.self, from: data)
                    applyLoadedConfiguration(decoded)
                    logger.info("从文件加载叠加配置: \(decoded.seriesList.count) 个系列")
                    return
                } catch {
                    logger.error("配置文件解析失败，尝试UserDefaults: \(error.localizedDescription)")
                }
            }
        }

        // 回退到UserDefaults
        guard let data = UserDefaults.standard.data(forKey: configSaveKey) else { return }
        do {
            let decoded = try JSONDecoder().decode(UIOverlayConfiguration.self, from: data)
            applyLoadedConfiguration(decoded)
            logger.info("从UserDefaults加载叠加配置: \(decoded.seriesList.count) 个系列")
        } catch {
            logger.error("UserDefaults配置解析失败: \(error.localizedDescription)")
        }
    }

    /// 应用加载的配置到当前状态
    private func applyLoadedConfiguration(_ config: UIOverlayConfiguration) {
        configLock.lock()
        isOverlayModeEnabled = config.isEnabled
        autoScaleYAxis = config.autoScaleYAxis
        yAxisPaddingTop = config.yAxisPaddingTop
        yAxisPaddingBottom = config.yAxisPaddingBottom
        showLegend = config.showLegend
        legendPosition = config.legendPosition
        configLock.unlock()

        seriesLock.lock()
        seriesList = config.seriesList
        seriesLock.unlock()

        NotificationCenter.default.post(
            name: .chartOverlayConfigLoaded,
            object: self,
            userInfo: ["seriesCount": config.seriesList.count, "isEnabled": config.isEnabled]
        )
    }

    /// 导出当前配置到指定文件
    /// - Parameter url: 目标文件URL
    /// - Returns: 是否导出成功
    public func exportConfiguration(to url: URL) -> Bool {
        do {
            let config = UIOverlayConfiguration(
                isEnabled: isOverlayModeEnabled,
                seriesList: allSeries,
                autoScaleYAxis: autoScaleYAxis,
                yAxisPaddingTop: yAxisPaddingTop,
                yAxisPaddingBottom: yAxisPaddingBottom,
                showLegend: showLegend,
                legendPosition: legendPosition,
                version: currentVersion
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: url)
            logger.info("导出叠加配置成功: \(url.path)")
            return true
        } catch {
            logger.error("导出叠加配置失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 从指定文件导入配置
    /// - Parameter url: 配置文件URL
    /// - Returns: 是否导入成功
    @discardableResult
    public func importConfiguration(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(UIOverlayConfiguration.self, from: data)
            applyLoadedConfiguration(decoded)
            saveConfigurationToDisk()
            recalculateYAxisRange()
            logger.info("导入叠加配置成功: \(url.path), 共 \(decoded.seriesList.count) 个系列")
            return true
        } catch {
            logger.error("导入叠加配置失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 便捷工厂方法
    /// 从简单数组快速创建数据系列
    /// - Parameters:
    ///   - label: 系列名称
    ///   - source: 数据源标识
    ///   - values: 数值数组（时间戳自动按索引生成）
    ///   - baseTimestamp: 基础时间戳
    ///   - interval: 数据点间隔（秒）
    /// - Returns: 创建的数据系列
    public func createSeriesFromValues(
        label: String,
        source: String,
        values: [Double],
        baseTimestamp: TimeInterval = Date().timeIntervalSince1970,
        interval: TimeInterval = 60
    ) -> UIOverlayDataSeries {
        let points = values.enumerated().map { index, value in
            UIOverlayDataPoint(timestamp: baseTimestamp + TimeInterval(index) * interval, value: value)
        }
        let color = nextPresetColor()
        return UIOverlayDataSeries(
            label: label,
            sourceIdentifier: source,
            dataPoints: points,
            colorHex: color.hexString
        )
    }

    /// 创建示例数据系列（用于测试和演示）
    /// - Returns: 示例数据系列
    public func createSampleSeries() -> [UIOverlayDataSeries] {
        let now = Date().timeIntervalSince1970
        let baseTimestamp = now - 3600 * 24 // 24小时前

        // 生成第一条正弦波数据
        let series1Values = (0..<100).map { index in
            sin(Double(index) * 0.1) * 50 + 100
        }
        let series1 = createSeriesFromValues(
            label: "示例系列一",
            source: "demo",
            values: series1Values,
            baseTimestamp: baseTimestamp,
            interval: 300
        )

        // 生成第二条余弦波数据
        let series2Values = (0..<100).map { index in
            cos(Double(index) * 0.08) * 30 + 80
        }
        var series2 = createSeriesFromValues(
            label: "示例系列二",
            source: "demo",
            values: series2Values,
            baseTimestamp: baseTimestamp,
            interval: 300
        )
        series2.colorHex = NSColor.systemRed.hexString
        series2.zIndex = 1

        // 生成第三条线性趋势数据
        let series3Values = (0..<100).map { index in
            Double(index) * 0.5 + 50
        }
        var series3 = createSeriesFromValues(
            label: "示例系列三",
            source: "demo",
            values: series3Values,
            baseTimestamp: baseTimestamp,
            interval: 300
        )
        series3.colorHex = NSColor.systemGreen.hexString
        series3.zIndex = 2
        series3.lineStyle = .dashed

        return [series1, series2, series3]
    }
}

// MARK: - 迁回自 UI-02：enum UIOverlayLineStyle
// MARK: - UI-GL-54 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-54_types.swift
// 版本: 2.0
// MARK: - 线型样式枚举
/// 数据系列的绘制线型
public enum UIOverlayLineStyle: String, Codable, CaseIterable {
    /// 实线
    case solid = "solid"
    /// 虚线
    case dashed = "dashed"
    /// 点线
    case dotted = "dotted"
    /// 点划线
    case dashDot = "dashDot"

    /// 中文显示名称
    public var displayName: String {
        switch self {
        case .solid:   return "实线"
        case .dashed:  return "虚线"
        case .dotted:  return "点线"
        case .dashDot: return "点划线"
        }
    }

    /// 转换为NSLineDashPattern数组
    public var pattern: [NSNumber] {
        switch self {
        case .solid:   return []
        case .dashed:  return [6, 3]
        case .dotted:  return [2, 3]
        case .dashDot: return [6, 3, 2, 3]
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIOverlayDataPoint
// MARK: - 画线工具管理器（单例）
/// 核心管理类：负责所有画线的创建、编辑、删除、模板管理与持久化
// 已迁回 UI-GL-53_画线工具库与模板.swift：class UIDrawingToolManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-54 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-54_types.swift
// 版本: 2.0
// MARK: - 数据点结构
/// 单个数据点，包含时间戳和数值
public struct UIOverlayDataPoint: Codable, Equatable {
    /// 时间戳（Unix时间戳，秒级）
    public var timestamp: TimeInterval
    /// 数值
    public var value: Double

    public init(timestamp: TimeInterval, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

// MARK: - 迁回自 UI-02：struct UIOverlayDataSeries
// MARK: - 数据系列模型
/// 单个叠加数据系列，包含完整的数据与样式信息
public struct UIOverlayDataSeries: Codable, Identifiable, Equatable {
    /// 唯一标识符
    public var id: String
    /// 系列显示名称
    public var label: String
    /// 数据源标识（如交易所代码、指标名称等）
    public var sourceIdentifier: String
    /// 数据点数组
    public var dataPoints: [UIOverlayDataPoint]
    /// 线条颜色（RGBA十六进制字符串，如 "#FF5733FF"）
    public var colorHex: String
    /// 不透明度（0.0 ~ 1.0）
    public var alpha: Double
    /// 线条宽度（像素）
    public var lineWidth: CGFloat
    /// 线型样式
    public var lineStyle: UIOverlayLineStyle
    /// 是否可见
    public var isVisible: Bool
    /// 是否参与Y轴自动缩放计算
    public var affectsYAxis: Bool
    /// 创建时间戳
    public var createdAt: TimeInterval
    /// 最后修改时间戳
    public var updatedAt: TimeInterval
    /// 系列排序权重（数值越小越靠前绘制）
    public var zIndex: Int
    /// 是否显示数据标签
    public var showLabels: Bool
    /// 是否显示数据点标记
    public var showMarkers: Bool
    /// 标记大小
    public var markerSize: CGFloat

    /// 将十六进制颜色字符串转换为NSColor
    public var nsColor: NSColor {
        return NSColor.fromHexString(colorHex) ?? .systemBlue
    }

    /// 获取数据中的最小值
    public var minValue: Double? {
        guard !dataPoints.isEmpty else { return nil }
        return dataPoints.map { $0.value }.min()
    }

    /// 获取数据中的最大值
    public var maxValue: Double? {
        guard !dataPoints.isEmpty else { return nil }
        return dataPoints.map { $0.value }.max()
    }

    /// 获取数据时间范围
    public var timeRange: (min: TimeInterval, max: TimeInterval)? {
        guard !dataPoints.isEmpty else { return nil }
        let timestamps = dataPoints.map { $0.timestamp }
        return (min: timestamps.min() ?? 0, max: timestamps.max() ?? 0)
    }

    /// 默认初始化
    public init(
        id: String = UUID().uuidString,
        label: String,
        sourceIdentifier: String,
        dataPoints: [UIOverlayDataPoint] = [],
        colorHex: String = "#3B82F6FF",
        alpha: Double = 1.0,
        lineWidth: CGFloat = 1.5,
        lineStyle: UIOverlayLineStyle = .solid,
        isVisible: Bool = true,
        affectsYAxis: Bool = true,
        zIndex: Int = 0,
        showLabels: Bool = false,
        showMarkers: Bool = false,
        markerSize: CGFloat = 4.0
    ) {
        let now = Date().timeIntervalSince1970
        self.id = id
        self.label = label
        self.sourceIdentifier = sourceIdentifier
        self.dataPoints = dataPoints
        self.colorHex = colorHex
        self.alpha = alpha
        self.lineWidth = lineWidth
        self.lineStyle = lineStyle
        self.isVisible = isVisible
        self.affectsYAxis = affectsYAxis
        self.createdAt = now
        self.updatedAt = now
        self.zIndex = zIndex
        self.showLabels = showLabels
        self.showMarkers = showMarkers
        self.markerSize = markerSize
    }
}

// MARK: - 迁回自 UI-02：struct UIOverlayConfiguration
// MARK: - NSColor十六进制扩展
/// 为NSColor提供十六进制字符串转换能力
// 已迁回 UI-GL-54_图表叠加模式.swift：extension NSColor（公共类型文件禁止功能实现）

// MARK: - 叠加配置模型
/// 可持久化的叠加配置，用于保存/恢复叠加状态
public struct UIOverlayConfiguration: Codable, Equatable {
    /// 叠加模式是否启用
    public var isEnabled: Bool
    /// 所有数据系列配置
    public var seriesList: [UIOverlayDataSeries]
    /// 是否启用Y轴自动缩放
    public var autoScaleYAxis: Bool
    /// Y轴顶部留白比例（0.0 ~ 0.5）
    public var yAxisPaddingTop: Double
    /// Y轴底部留白比例（0.0 ~ 0.5）
    public var yAxisPaddingBottom: Double
    /// 是否显示图例
    public var showLegend: Bool
    /// 图例位置（0=左上，1=右上，2=左下，3=右下）
    public var legendPosition: Int
    /// 配置版本号（用于后续兼容升级）
    public var version: Double
    /// 最后保存时间戳
    public var lastSavedAt: TimeInterval

    public init(
        isEnabled: Bool = false,
        seriesList: [UIOverlayDataSeries] = [],
        autoScaleYAxis: Bool = true,
        yAxisPaddingTop: Double = 0.05,
        yAxisPaddingBottom: Double = 0.05,
        showLegend: Bool = true,
        legendPosition: Int = 1,
        version: Double = 2.0
    ) {
        self.isEnabled = isEnabled
        self.seriesList = seriesList
        self.autoScaleYAxis = autoScaleYAxis
        self.yAxisPaddingTop = yAxisPaddingTop
        self.yAxisPaddingBottom = yAxisPaddingBottom
        self.showLegend = showLegend
        self.legendPosition = legendPosition
        self.version = version
        self.lastSavedAt = Date().timeIntervalSince1970
    }
}

// MARK: - 迁回自 UI-02：struct UIOverlayYAxisRange
// MARK: - Y轴范围结构
/// 计算得出的Y轴显示范围
public struct UIOverlayYAxisRange: Codable, Equatable {
    /// 最小值
    public var min: Double
    /// 最大值
    public var max: Double
    /// 数据精度（小数位数）
    public var precision: Int

    /// 范围跨度
    public var span: Double { max - min }

    /// 是否有效范围
    public var isValid: Bool { span > 0 && min != .infinity && max != .infinity }

    public init(min: Double = 0, max: Double = 100, precision: Int = 2) {
        self.min = min
        self.max = max
        self.precision = precision
    }
}
