// MARK: - 功能59: 颜色盲模式
// 对应需求: 提供红-绿色盲、蓝-黄色盲、全色盲等视觉适配方案
// 优先级: P3
// 核心职责: 管理色盲类型切换、颜色替换映射、K线颜色适配、模拟模式预览
// 使用方式: UIColorBlindManager.shared.方法名
// 注意事项: 所有颜色调整均为非破坏性，原始色值保留在配置中

import Foundation
import AppKit
import os.log

// MARK: - 统一日志器
private let logger = Logger(subsystem: "com.xianrenzhilu.app", category: "ColorBlindMode")

// MARK: - 辅助工具函数
// isRedGreenColor / isBlueYellowColor 已迁移到 UI-02_公共类型定义.swift。

// MARK: - 使用示例（注释）
/*
 // 切换色盲模式
 UIColorBlindManager.shared.setMode(.protanopia)
 UIColorBlindManager.shared.setEnabled(true)

 // 添加自定义颜色替换
 UIColorBlindManager.shared.addColorReplacement(
     original: "#FF0000",
     replacement: "#0066FF",
     label: "红涨→蓝"
 )

 // 获取适配后的K线颜色
 let scheme = UIColorBlindManager.shared.getKLineColors()
 let (upColor, downColor, upBorder, downBorder) = UIColorBlindManager.shared.getKLineNSColors()

 // 颜色调整
 let adjusted = UIColorBlindManager.shared.adjustColor(NSColor.red)

 // 模拟模式预览
 UIColorBlindManager.shared.startSimulation(type: .deuteranopia)
 // ... 预览界面 ...
 UIColorBlindManager.shared.stopSimulation()

 // 监听通知
 NotificationCenter.default.addObserver(
     forName: UIColorBlindManager.modeDidChangeNotification,
     object: nil,
     queue: .main
 ) { notification in
     if let old = notification.userInfo?["oldType"] as? UIColorBlindType,
        let new = notification.userInfo?["newType"] as? UIColorBlindType {
         print("色盲模式从 \(old.displayName) 切换到 \(new.displayName)")
     }
 }
 */


// MARK: - 测试代码
#if DEBUG

/// 功能59：颜色盲模式 — 单元测试
func test_colorBlind() {
    let manager = UIColorBlindManager.shared
    
    logger.info("测试1: 默认配置")
    if manager.currentType == .none && !manager.isEnabled {
        logger.info("✅ 测试1通过")
    } else {
        logger.error("❌ 测试1失败")
    }
    
    logger.info("测试2: 设置色盲类型")
    manager.setMode(.protanopia)
    if manager.currentType == .protanopia {
        logger.info("✅ 测试2通过")
    } else {
        logger.error("❌ 测试2失败")
    }
    
    logger.info("测试3: 启用色盲模式")
    manager.setEnabled(true)
    if manager.isEnabled {
        logger.info("✅ 测试3通过")
    } else {
        logger.error("❌ 测试3失败")
    }
    
    logger.info("测试4: 色盲类型枚举")
    if UIColorBlindType.allCases.count == 5 {
        logger.info("✅ 测试4通过")
    } else {
        logger.error("❌ 测试4失败")
    }
    
    logger.info("测试5: 颜色调整")
    let red = NSColor.red
    let adjusted = manager.adjustColor(red)
    if adjusted != red {
        logger.info("✅ 测试5通过")
    } else {
        logger.error("❌ 测试5失败")
    }
    
    logger.info("测试6: 添加颜色替换")
    manager.addColorReplacement(original: "#FF0000", replacement: "#0066FF", label: "红→蓝")
    if manager.colorReplacements.count == 1 {
        logger.info("✅ 测试6通过")
    } else {
        logger.error("❌ 测试6失败")
    }
    
    logger.info("测试7: K线颜色")
    let scheme = manager.getKLineColors()
    logger.info("✅ 测试7通过：upColor = \(scheme.upColor), downColor = \(scheme.downColor)")
    
    logger.info("测试8: K线NSColors")
    let (up, down, _, _) = manager.getKLineNSColors()
    if up != down {
        logger.info("✅ 测试8通过")
    } else {
        logger.error("❌ 测试8失败")
    }
    
    logger.info("测试9: 模拟模式")
    manager.startSimulation(type: .deuteranopia)
    if manager.isSimulated && manager.currentType == .deuteranopia {
        logger.info("✅ 测试9通过")
    } else {
        logger.error("❌ 测试9失败")
    }
    
    logger.info("测试10: 停止模拟")
    manager.stopSimulation()
    if !manager.isSimulated && manager.currentType == .none {
        logger.info("✅ 测试10通过")
    } else {
        logger.error("❌ 测试10失败")
    }
    
    logger.info("测试11: 重置配置")
    manager.resetToDefault()
    if manager.currentType == .none && !manager.isEnabled {
        logger.info("✅ 测试11通过")
    } else {
        logger.error("❌ 测试11失败")
    }
    
    logger.info("测试12: 可用类型")
    let types = manager.availableColorBlindTypes()
    if types.count == 5 {
        logger.info("✅ 测试12通过")
    } else {
        logger.error("❌ 测试12失败")
    }
    
    logger.info("测试13: 辅助工具函数")
    let isRedGreen = isRedGreenColor(NSColor.red)
    if isRedGreen {
        logger.info("✅ 测试13通过")
    } else {
        logger.error("❌ 测试13失败")
    }
    
    logger.info("=== 全部色盲模式测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIColorBlindManager
public final class UIColorBlindManager: @unchecked Sendable {

    // MARK: - 单例
    public static let shared = UIColorBlindManager()

    // MARK: - 日志器
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "UIColorBlindManager")

    // MARK: - 线程锁
    private let lock = NSRecursiveLock()

    // MARK: - 通知定义
    /// 色盲模式类型变更通知
    public static let modeDidChangeNotification = Notification.Name("com.xianrenzhilu.colorBlindModeChanged")
    /// 颜色替换方案变更通知
    public static let colorReplacementDidChangeNotification = Notification.Name("com.xianrenzhilu.colorBlindReplacementChanged")
    /// 色盲全局配置变更通知
    public static let configDidChangeNotification = Notification.Name("com.xianrenzhilu.colorBlindConfigChanged")

    // MARK: - 持久化键
    private let configKey = "com.xianrenzhilu.colorBlindConfig"

    // MARK: - 私有状态
    /// 当前色盲模式配置，受锁保护
    private var _config: UIColorBlindConfig
    /// 当前是否处于模拟模式，受锁保护
    private var _isSimulated: Bool
    /// 自定义颜色替换映射表，受锁保护（原始色Hex -> 替换条目）
    private nonisolated(unsafe) var _replacementMap: [String: UIColorReplacementEntry]
    /// 观察者令牌列表，用于deinit清理
    private nonisolated(unsafe) var observerTokens: [NSObjectProtocol]
    /// 是否已初始化完成
    private nonisolated(unsafe) var isInitialized: Bool

    // MARK: - 初始化
    private init() {
        self._config = UIColorBlindConfig.default
        self._isSimulated = false
        self._replacementMap = [:]
        self.observerTokens = []
        self.isInitialized = false

        logger.info("色盲管理器初始化中...")

        // 加载持久化配置
        loadPersistedConfig()

        // 注册应用通知监听
        registerNotificationObservers()

        self.isInitialized = true
        logger.info("色盲管理器初始化完成，当前类型: \(String(describing: self._config.type.displayName))")
    }

    // MARK: - 反初始化
    deinit {
        // 移除所有通知观察者
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
        observerTokens.removeAll()

        // 清理替换映射
        _replacementMap.removeAll()

        logger.info("色盲管理器已清理")
    }

    // MARK: - 通知监听注册
    /// 注册系统级通知监听，用于触发配置保存
    private func registerNotificationObservers() {
        let token = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveConfig()
        }
        observerTokens.append(token)
    }

    // MARK: - 配置持久化
    /// 从UserDefaults加载持久化配置
    private func loadPersistedConfig() {
        guard let data = UserDefaults.standard.data(forKey: configKey) else {
            logger.info("未找到持久化配置，使用默认配置")
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode(UIColorBlindConfig.self, from: data)
            _config = loaded
            rebuildReplacementMap()
            logger.info("成功加载持久化配置")
        } catch {
            logger.error("加载持久化配置失败: \(error.localizedDescription)")
        }
    }

    /// 将当前配置持久化到UserDefaults
    public func saveConfig() {
        lock.lock()
        do {
            var configToSave = _config
            configToSave.lastModified = Date()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(configToSave)
            UserDefaults.standard.set(data, forKey: configKey)
            logger.info("配置已持久化")
        } catch {
            logger.error("持久化配置失败: \(error.localizedDescription)")
        }
        lock.unlock()
    }

    // MARK: - 设置面板方法
    /// 设置色盲模式类型
    /// 参数 type: 目标色盲类型
    /// 触发 modeDidChangeNotification 通知
    public func setMode(_ type: UIColorBlindType) {
        lock.lock()
        let oldType = _config.type
        guard oldType != type else {
            lock.unlock()
            return
        }
        _config.type = type
        _config.lastModified = Date()

        // 自动更新K线颜色方案
        if _config.isKLineAdaptive {
            _config.kLineScheme = UIKLineColorScheme.defaultForType(type)
        }

        let configCopy = _config
        lock.unlock()

        // 保存到持久化
        saveConfig()

        // 广播通知
        let userInfo = UIModeChangeUserInfo(
            oldType: oldType,
            newType: type,
            config: configCopy
        )
        NotificationCenter.default.post(
            name: Self.modeDidChangeNotification,
            object: self,
            userInfo: userInfo.asDictionary
        )
        logger.info("色盲模式切换: \(oldType.displayName) → \(type.displayName)")
    }

    /// 获取当前色盲类型
    public var currentType: UIColorBlindType {
        lock.lock()
        let type = _config.type
        lock.unlock()
        return type
    }

    /// 获取色盲模式总开关状态
    public var isEnabled: Bool {
        lock.lock()
        let enabled = _config.isEnabled
        lock.unlock()
        return enabled
    }

    /// 设置色盲模式总开关
    public func setEnabled(_ enabled: Bool) {
        lock.lock()
        guard _config.isEnabled != enabled else {
            lock.unlock()
            return
        }
        _config.isEnabled = enabled
        _config.lastModified = Date()
        let configCopy = _config
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.configDidChangeNotification,
            object: self,
            userInfo: UIConfigChangeUserInfo(config: configCopy).asDictionary
        )
        logger.info("色盲模式开关: \(enabled ? "开启" : "关闭")")
    }

    /// 设置K线颜色自适应开关
    public func setKLineAdaptive(_ adaptive: Bool) {
        lock.lock()
        _config.isKLineAdaptive = adaptive
        if adaptive {
            _config.kLineScheme = UIKLineColorScheme.defaultForType(_config.type)
        }
        _config.lastModified = Date()
        let configCopy = _config
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.configDidChangeNotification,
            object: self,
            userInfo: UIConfigChangeUserInfo(config: configCopy).asDictionary
        )
        logger.info("K线自适应: \(adaptive ? "开启" : "关闭")")
    }

    /// 设置全局颜色替换开关
    public func setGlobalReplacement(_ enabled: Bool) {
        lock.lock()
        _config.isGlobalReplacement = enabled
        _config.lastModified = Date()
        let configCopy = _config
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.configDidChangeNotification,
            object: self,
            userInfo: UIConfigChangeUserInfo(config: configCopy).asDictionary
        )
        logger.info("全局颜色替换: \(enabled ? "开启" : "关闭")")
    }

    /// 获取当前完整配置副本
    public var currentConfig: UIColorBlindConfig {
        lock.lock()
        let config = _config
        lock.unlock()
        return config
    }

    /// 重置配置为默认状态
    public func resetToDefault() {
        lock.lock()
        _config = UIColorBlindConfig.default
        rebuildReplacementMap()
        let configCopy = _config
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.configDidChangeNotification,
            object: self,
            userInfo: UIConfigChangeUserInfo(config: configCopy).asDictionary
        )
        logger.info("配置已重置为默认")
    }

    // MARK: - 模拟模式
    /// 模拟模式：让正常视觉用户预览色盲效果
    /// 开启后所有颜色调整均生效，但色盲模式开关本身不开启
    public func setSimulated(_ simulated: Bool) {
        lock.lock()
        guard _isSimulated != simulated else {
            lock.unlock()
            return
        }
        _isSimulated = simulated
        _config.isSimulated = simulated
        _config.lastModified = Date()
        let configCopy = _config
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.configDidChangeNotification,
            object: self,
            userInfo: UIConfigChangeUserInfo(config: configCopy, isSimulated: simulated).asDictionary
        )
        logger.info("模拟模式: \(simulated ? "开启" : "关闭")")
    }

    /// 当前是否处于模拟模式
    public var isSimulated: Bool {
        lock.lock()
        let sim = _isSimulated
        lock.unlock()
        return sim
    }

    /// 开始模拟指定色盲类型的效果
    /// 参数 type: 要模拟的色盲类型
    public func startSimulation(type: UIColorBlindType = .protanopia) {
        setMode(type)
        setSimulated(true)
        logger.info("开始模拟: \(type.displayName)")
    }

    /// 停止模拟，恢复原始状态
    public func stopSimulation() {
        setSimulated(false)
        setMode(.none)
        logger.info("模拟已停止")
    }

    // MARK: - 颜色替换映射
    /// 添加颜色替换规则
    /// 参数 original: 原始色十六进制字符串
    /// 参数 replacement: 替换色十六进制字符串
    /// 参数 label: 规则描述标签
    public func addColorReplacement(original: String, replacement: String, label: String = "") {
        let entry = UIColorReplacementEntry(originalHex: original, replacementHex: replacement, label: label)
        lock.lock()
        _config.colorReplacements.append(entry)
        _replacementMap[original] = entry
        _config.lastModified = Date()
        let replacementsCopy = _config.colorReplacements
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.colorReplacementDidChangeNotification,
            object: self,
            userInfo: UIReplacementChangeUserInfo(replacements: replacementsCopy).asDictionary
        )
        logger.info("添加颜色替换: \(original) → \(replacement)")
    }

    /// 移除指定颜色替换规则
    /// 参数 originalHex: 原始色十六进制字符串
    public func removeColorReplacement(originalHex: String) {
        lock.lock()
        _config.colorReplacements.removeAll { $0.originalHex == originalHex }
        _replacementMap.removeValue(forKey: originalHex)
        _config.lastModified = Date()
        let replacementsCopy = _config.colorReplacements
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.colorReplacementDidChangeNotification,
            object: self,
            userInfo: UIReplacementChangeUserInfo(replacements: replacementsCopy).asDictionary
        )
        logger.info("移除颜色替换: \(originalHex)")
    }

    /// 更新指定颜色替换规则
    /// 参数 originalHex: 原始色十六进制字符串
    /// 参数 newReplacement: 新的替换色十六进制字符串
    public func updateColorReplacement(originalHex: String, newReplacement: String) {
        lock.lock()
        if let index = _config.colorReplacements.firstIndex(where: { $0.originalHex == originalHex }) {
            _config.colorReplacements[index].replacementHex = newReplacement
            _replacementMap[originalHex] = _config.colorReplacements[index]
            _config.lastModified = Date()
        }
        let replacementsCopy = _config.colorReplacements
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.colorReplacementDidChangeNotification,
            object: self,
            userInfo: UIReplacementChangeUserInfo(replacements: replacementsCopy).asDictionary
        )
        logger.info("更新颜色替换: \(originalHex) → \(newReplacement)")
    }

    /// 获取所有颜色替换规则
    public var colorReplacements: [UIColorReplacementEntry] {
        lock.lock()
        let replacements = _config.colorReplacements
        lock.unlock()
        return replacements
    }

    /// 清空所有自定义颜色替换规则
    public func clearColorReplacements() {
        lock.lock()
        _config.colorReplacements.removeAll()
        _replacementMap.removeAll()
        _config.lastModified = Date()
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.colorReplacementDidChangeNotification,
            object: self,
            userInfo: UIReplacementChangeUserInfo(replacements: []).asDictionary
        )
        logger.info("已清空所有颜色替换规则")
    }

    /// 重置颜色替换为色盲类型默认方案
    /// 根据当前色盲类型预填充常用颜色替换
    public func resetColorReplacementsToDefault() {
        lock.lock()
        let type = _config.type
        _config.colorReplacements = UIColorBlindManager.defaultReplacements(for: type)
        rebuildReplacementMap()
        _config.lastModified = Date()
        let replacementsCopy = _config.colorReplacements
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.colorReplacementDidChangeNotification,
            object: self,
            userInfo: UIReplacementChangeUserInfo(replacements: replacementsCopy).asDictionary
        )
        logger.info("已重置为默认颜色替换方案")
    }

    /// 根据色盲类型获取默认颜色替换方案
    private static func defaultReplacements(for type: UIColorBlindType) -> [UIColorReplacementEntry] {
        switch type {
        case .none:
            return []
        case .protanopia, .deuteranopia:
            return [
                UIColorReplacementEntry(originalHex: "#FF0000", replacementHex: "#0066FF", label: "涨 → 蓝"),
                UIColorReplacementEntry(originalHex: "#00FF00", replacementHex: "#FF8800", label: "跌 → 橙"),
                UIColorReplacementEntry(originalHex: "#CC0000", replacementHex: "#0044CC", label: "涨边框 → 深蓝"),
                UIColorReplacementEntry(originalHex: "#00CC00", replacementHex: "#CC6600", label: "跌边框 → 深橙"),
            ]
        case .tritanopia:
            return [
                UIColorReplacementEntry(originalHex: "#0000FF", replacementHex: "#FF00FF", label: "蓝 → 洋红"),
                UIColorReplacementEntry(originalHex: "#FFFF00", replacementHex: "#00FF00", label: "黄 → 绿"),
            ]
        case .achromatopsia:
            return [
                UIColorReplacementEntry(originalHex: "#FF0000", replacementHex: "#FFFFFF", label: "红 → 白"),
                UIColorReplacementEntry(originalHex: "#00FF00", replacementHex: "#000000", label: "绿 → 黑"),
            ]
        }
    }

    /// 重建内部替换映射字典
    private func rebuildReplacementMap() {
        _replacementMap.removeAll()
        for entry in _config.colorReplacements {
            _replacementMap[entry.originalHex] = entry
        }
    }

    // MARK: - K线颜色适配
    /// 获取当前色盲类型的K线颜色方案
    /// 返回适配后的上涨/下跌颜色组合
    public func getKLineColors() -> UIKLineColorScheme {
        lock.lock()
        let scheme = _config.kLineScheme
        lock.unlock()
        return scheme
    }

    /// 设置自定义K线颜色方案
    /// 参数 scheme: K线颜色方案
    public func setKLineColors(_ scheme: UIKLineColorScheme) {
        lock.lock()
        _config.kLineScheme = scheme
        _config.lastModified = Date()
        let configCopy = _config
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.configDidChangeNotification,
            object: self,
            userInfo: UIConfigChangeUserInfo(config: configCopy).asDictionary
        )
        logger.info("K线颜色方案已更新")
    }

    /// 将K线颜色方案转换为NSColor元组
    /// 返回 (上涨颜色, 下跌颜色, 上涨边框, 下跌边框)
    public func getKLineNSColors() -> (NSColor, NSColor, NSColor, NSColor) {
        lock.lock()
        let scheme = _config.kLineScheme
        lock.unlock()

        return (scheme.upColor, scheme.downColor, scheme.upBorderColor, scheme.downBorderColor)
    }

    /// 恢复K线颜色为当前色盲类型的默认方案
    public func resetKLineColorsToDefault() {
        lock.lock()
        let type = _config.type
        _config.kLineScheme = UIKLineColorScheme.defaultForType(type)
        _config.lastModified = Date()
        let configCopy = _config
        lock.unlock()

        saveConfig()
        NotificationCenter.default.post(
            name: Self.configDidChangeNotification,
            object: self,
            userInfo: UIConfigChangeUserInfo(config: configCopy).asDictionary
        )
        logger.info("K线颜色已恢复为默认")
    }

    // MARK: - 颜色调整
    /// 调整指定颜色，应用色盲转换和自定义替换
    /// 优先级: 自定义替换 > 色盲类型转换
    /// 参数 color: 原始颜色
    /// 返回: 适配后的颜色
    public func adjustColor(_ color: NSColor) -> NSColor {
        // 检查是否启用色盲模式或模拟模式
        lock.lock()
        let shouldAdjust = _config.isEnabled || _isSimulated
        let type = _config.type
        let isGlobalReplacement = _config.isGlobalReplacement
        let replacementMap = _replacementMap
        lock.unlock()

        guard shouldAdjust, type != .none else {
            return color
        }

        // 先尝试自定义替换映射
        if isGlobalReplacement {
            let hex = color.hexString
            if let entry = replacementMap[hex], let repColor = entry.replacementColor {
                return repColor
            }
        }

        // 应用色盲类型转换
        return type.adjust(color: color)
    }

    /// 批量调整颜色数组
    /// 参数 colors: 原始颜色数组
    /// 返回: 适配后的颜色数组
    public func adjustColors(_ colors: [NSColor]) -> [NSColor] {
        colors.map { adjustColor($0) }
    }

    /// 调整K线专用颜色（涨/跌）
    /// 返回适配后的上涨色和下跌色
    public func adjustKLineColors(up: NSColor, down: NSColor) -> (NSColor, NSColor) {
        let adjustedUp = adjustColor(up)
        let adjustedDown = adjustColor(down)
        return (adjustedUp, adjustedDown)
    }

    /// 获取指定颜色的推荐替换色（用于UI提示）
    /// 参数 color: 原始颜色
    /// 返回: 推荐替换色
    public func getRecommendedReplacement(for color: NSColor) -> NSColor? {
        lock.lock()
        let type = _config.type
        lock.unlock()

        let hex = color.hexString

        // 根据色盲类型给出推荐
        switch type {
        case .none:
            return nil
        case .protanopia, .deuteranopia:
            if hex == "#FF0000" { return NSColor(hexString: "#0066FF") }
            if hex == "#00FF00" { return NSColor(hexString: "#FF8800") }
        case .tritanopia:
            if hex == "#0000FF" { return NSColor(hexString: "#FF00FF") }
            if hex == "#FFFF00" { return NSColor(hexString: "#00FF00") }
        case .achromatopsia:
            let gray = color.hexString
            return NSColor(hexString: gray)
        }
        return nil
    }

    // MARK: - 设置面板支持
    /// 获取所有可用色盲类型的显示信息
    /// 返回: [(类型, 中文名称, 分类)]
    public func availableColorBlindTypes() -> [(type: UIColorBlindType, name: String, category: String)] {
        UIColorBlindType.allCases.map { ($0, $0.displayName, $0.categoryName) }
    }

    /// 获取当前色盲类型的详细描述
    /// 返回: 描述文本
    public func currentTypeDescription() -> String {
        let type = currentType
        switch type {
        case .none:
            return "标准色彩模式，使用原生红绿配色方案"
        case .protanopia:
            return "红色盲适配：红绿通道信息重组，红蜡烛→蓝色，绿蜡烛→橙色"
        case .deuteranopia:
            return "绿色盲适配：绿通道信息重组，红蜡烛→蓝色，绿蜡烛→橙色"
        case .tritanopia:
            return "蓝色盲适配：蓝黄通道信息重组，增强边框对比度"
        case .achromatopsia:
            return "全色盲适配：仅使用明暗对比，涨→白色实心，跌→黑色空心"
        }
    }

    /// 获取当前色盲类型的统计信息
    /// 返回: 各通道权重的描述文本
    public func currentTypeStatistics() -> String {
        let type = currentType
        switch type {
        case .none:
            return "R:100% G:100% B:100%"
        case .protanopia:
            return "L通道缺失: 红→绿蓝混合"
        case .deuteranopia:
            return "M通道缺失: 绿→红蓝混合"
        case .tritanopia:
            return "S通道缺失: 蓝→红黄混合"
        case .achromatopsia:
            return "全通道缺失: 仅亮度信息"
        }
    }

    /// 获取当前生效的颜色替换规则数量
    public var activeReplacementCount: Int {
        lock.lock()
        let count = _config.colorReplacements.count
        lock.unlock()
        return count
    }

    /// 判断指定颜色是否被替换规则覆盖
    /// 参数 color: 目标颜色
    /// 返回: 是否被覆盖
    public func isColorReplaced(_ color: NSColor) -> Bool {
        lock.lock()
        let replaced = _replacementMap[color.hexString] != nil
        lock.unlock()
        return replaced
    }

    /// 获取指定颜色的替换条目
    /// 参数 color: 目标颜色
    /// 返回: 替换条目（如无则返回nil）
    public func replacementEntry(for color: NSColor) -> UIColorReplacementEntry? {
        lock.lock()
        let entry = _replacementMap[color.hexString]
        lock.unlock()
        return entry
    }

    /// 检查当前配置是否为默认状态
    public var isDefaultConfig: Bool {
        let current = currentConfig
        return current == UIColorBlindConfig.default
    }

    /// 导出配置为JSON字符串
    /// 返回: JSON字符串
    public func exportConfig() -> String? {
        let config = currentConfig
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            return String(data: data, encoding: .utf8)
        } catch {
            logger.error("导出配置失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 从JSON字符串导入配置
    /// 参数 jsonString: JSON字符串
    /// 返回: 是否成功
    @discardableResult
    public func importConfig(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let newConfig = try decoder.decode(UIColorBlindConfig.self, from: data)

            lock.lock()
            _config = newConfig
            rebuildReplacementMap()
            let configCopy = _config
            lock.unlock()

            saveConfig()
            NotificationCenter.default.post(
                name: Self.configDidChangeNotification,
                object: self,
                userInfo: UIConfigChangeUserInfo(config: configCopy).asDictionary
            )
            logger.info("配置导入成功")
            return true
        } catch {
            logger.error("配置导入失败: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIColorBlindType
// MARK: - UI-GL-68 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-68_types.swift
// 版本: 2.0
// MARK: - 通知名称定义
/// 字体大小等级发生变更时发出的通知，object携带新的UIFontSizeLevel
// 已迁回 UI-GL-68_动态字体与缩放.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-69 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-69_types.swift
// 版本: 2.0
// MARK: - 色盲类型枚举
/// 支持的色盲类型定义
/// 红绿色盲细分为红色盲（Protanopia）和绿色盲（Deuteranopia），临床上两种均为红绿色觉异常
public enum UIColorBlindType: String, CaseIterable, Codable, Identifiable, Sendable {
    case none = "none"
    case protanopia = "protanopia"
    case deuteranopia = "deuteranopia"
    case tritanopia = "tritanopia"
    case achromatopsia = "achromatopsia"

    public var id: String { rawValue }

    /// 中文显示名称
    public var displayName: String {
        switch self {
        case .none:
            return "关闭"
        case .protanopia:
            return "红色盲（红-绿色弱）"
        case .deuteranopia:
            return "绿色盲（红-绿色弱）"
        case .tritanopia:
            return "蓝色盲（蓝-黄色弱）"
        case .achromatopsia:
            return "全色盲（单色视觉）"
        }
    }

    /// 分类描述，用于设置面板分组
    public var categoryName: String {
        switch self {
        case .none:
            return "标准视觉"
        case .protanopia, .deuteranopia:
            return "红绿色盲"
        case .tritanopia:
            return "蓝黄色盲"
        case .achromatopsia:
            return "全色盲"
        }
    }

    /// 是否属于色盲类型（非关闭状态）
    public var isColorBlind: Bool {
        self != .none
    }

    /// 基于W3C建议的色盲模拟颜色转换矩阵
    /// 使用简化的LMS（长/中/短视锥细胞）空间转换实现
    public func adjust(color: NSColor) -> NSColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        switch self {
        case .none:
            return color
        case .protanopia:
            // 红色盲：L视锥细胞缺失，红色通道信息丢失
            // 将红色信息映射到绿色和蓝色通道
            let newR = r * 0.567 + g * 0.433
            let newG = r * 0.558 + g * 0.442
            let newB = r * 0.242 + g * 0.758 + b * 0.0
            return NSColor(red: min(newR, 1.0), green: min(newG, 1.0), blue: min(newB, 1.0), alpha: a)
        case .deuteranopia:
            // 绿色盲：M视锥细胞缺失，绿色通道信息丢失
            let newR = r * 0.625 + g * 0.375
            let newG = r * 0.7 + g * 0.3
            let newB = r * 0.167 + g * 0.833 + b * 0.0
            return NSColor(red: min(newR, 1.0), green: min(newG, 1.0), blue: min(newB, 1.0), alpha: a)
        case .tritanopia:
            // 蓝色盲：S视锥细胞缺失，蓝色通道信息丢失
            let newR = r + g * 0.0 + b * 0.05
            let newG = g + b * 0.05
            let newB = r * 0.05 + g * 0.95 + b * 0.0
            return NSColor(red: min(newR, 1.0), green: min(newG, 1.0), blue: min(newB, 1.0), alpha: a)
        case .achromatopsia:
            // 全色盲：所有视锥细胞缺失，仅保留亮度信息
            let gray = r * 0.299 + g * 0.587 + b * 0.114
            return NSColor(red: gray, green: gray, blue: gray, alpha: a)
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIColorReplacementEntry
// MARK: - SwiftUI桥接扩展（可选）
/// 为SwiftUI视图提供便捷的字体和尺寸获取方法
// 已迁回 UI-GL-68_动态字体与缩放.swift：extension UIDynamicFontManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-69 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-69_types.swift
// 版本: 2.0
// MARK: - 颜色替换条目
/// 单条颜色替换规则，支持原始色值到目标色值的精确映射
/// 用于自定义色盲用户的个性化颜色偏好
public struct UIColorReplacementEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var originalHex: String
    public var replacementHex: String
    public var label: String

    public init(id: UUID = UUID(), originalHex: String, replacementHex: String, label: String = "") {
        self.id = id
        self.originalHex = originalHex
        self.replacementHex = replacementHex
        self.label = label
    }

    /// 将十六进制字符串转换为NSColor
    public var originalColor: NSColor? {
        NSColor(hexString: originalHex)
    }

    /// 将替换十六进制字符串转换为NSColor
    public var replacementColor: NSColor? {
        NSColor(hexString: replacementHex)
    }
}

// MARK: - 迁回自 UI-02：struct UIColorBlindConfig
// MARK: - 色盲模式全局配置
/// 色盲模式的完整配置结构，支持Codable持久化
public struct UIColorBlindConfig: Codable, Equatable, Sendable {
    /// 当前色盲类型
    public var type: UIColorBlindType
    /// 色盲模式总开关
    public var isEnabled: Bool
    /// 是否处于模拟模式（正常视觉用户预览色盲效果）
    public var isSimulated: Bool
    /// 自定义颜色替换映射列表
    public var colorReplacements: [UIColorReplacementEntry]
    /// K线颜色方案
    public var kLineScheme: UIKLineColorScheme
    /// 是否启用K线颜色自适应
    public var isKLineAdaptive: Bool
    /// 是否启用全局颜色替换
    public var isGlobalReplacement: Bool
    /// 最后修改时间
    public var lastModified: Date

    /// 默认配置构造器
    public static var `default`: UIColorBlindConfig {
        UIColorBlindConfig(
            type: .none,
            isEnabled: false,
            isSimulated: false,
            colorReplacements: [],
            kLineScheme: UIKLineColorScheme.defaultForType(.none),
            isKLineAdaptive: true,
            isGlobalReplacement: true,
            lastModified: Date()
        )
    }
}

// MARK: - 迁回自 UI-02：struct UIModeChangeUserInfo
// MARK: - 通知数据结构（类型安全替代 [String: Any]）
/// 模式变更通知信息
public struct UIModeChangeUserInfo: Sendable {
    public var oldType: UIColorBlindType
    public var newType: UIColorBlindType
    public var config: UIColorBlindConfig
    
    public var asDictionary: [String: Any] {
        ["oldType": oldType, "newType": newType, "config": config]
    }
}

// MARK: - 迁回自 UI-02：struct UIReplacementChangeUserInfo
/// 颜色替换变更通知信息
public struct UIReplacementChangeUserInfo: Sendable {
    public var replacements: [UIColorReplacementEntry]
    
    public var asDictionary: [String: Any] {
        ["replacements": replacements]
    }
}

// MARK: - 迁回自 UI-02：struct UIConfigChangeUserInfo
/// 配置变更通知信息
public struct UIConfigChangeUserInfo: Sendable {
    public var config: UIColorBlindConfig
    public var isSimulated: Bool?
    
    public var asDictionary: [String: Any] {
        var dict: [String: Any] = ["config": config]
        if let isSimulated = isSimulated {
            dict["isSimulated"] = isSimulated
        }
        return dict
    }
}
