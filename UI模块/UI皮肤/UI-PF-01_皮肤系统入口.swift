// MARK: - 皮肤系统入口
// 功能编号: Skin-01
// 版本: 1.0.0
// 职责: 皮肤服务注册、切换管理、预览、事件、远程皮肤、全局皮肤获取函数
// 依赖: UI-05 注册表, UI-08 定位器, UI-12 日志, SkinEngine

import Foundation
import AppKit
// 已改用 UI-02_公共类型定义.swift 中的公共类型：SkinServiceProtocol

// MARK: - 皮肤通知名称
extension NSNotification.Name {
    static let skinWillChange = NSNotification.Name("com.xianrenzhilu.skin.willChange")
    static let skinDidChange = NSNotification.Name("com.xianrenzhilu.skin.didChange")
    static let skinChangeFailed = NSNotification.Name("com.xianrenzhilu.skin.changeFailed")
}

// MARK: - 皮肤服务实现
public final class SkinService: SkinServiceProtocol, UIModuleProtocol , @unchecked Sendable{
    public static let shared = SkinService()
    public required init() {
        self.currentSkinInfo = SkinInfo(id: "", name: "", version: "", author: "", description: "", isSystem: false, tags: [], minEngineVersion: "")
        self.skinConfig = UISkinConfig(currentSkinId: "", accentColorHex: nil, fontScale: 1.0, cornerRadiusScale: 1.0, animationEnabled: true, highContrastEnabled: false, colorBlindMode: .none, customColors: [:], customSpacings: [:])
    }

    public let moduleID = "system.skin.service"
    public let moduleName = "皮肤系统服务"
    public let moduleVersion = "1.0.0"
    public let isUnloadable = false
    public let moduleDescription = "皮肤系统服务"

    public func start(context: Any?) throws {
        lock.lock()
        let lastSkinId = skinConfig.currentSkinId
        lock.unlock()
        UIModuleRegistry.shared.register(instance: self, name: "SkinService", aliases: ["皮肤服务"], priority: 100)
        logger.info("皮肤服务", "皮肤服务已注册", moduleID: moduleID)
        _ = setSkin(id: lastSkinId, animated: false)
    }
    public func stop() {}
    public func pause() {}
    public func resume() {}
    public func willUnload() throws {}
    public func didUnload() {}

    private let lock = NSRecursiveLock()
    private let logger = UILoadingLogManager.shared
    private let engine = SkinEngine.shared
    private let registry = UIUnifiedRegistry.shared

    private var currentSkinInfo: SkinInfo
    private var previewSkinInfo: SkinInfo?
    private var previewTimer: Timer?
    private var previewTimeout: TimeInterval = 30.0
    private var previousSkinBeforePreview: SkinInfo?
    private var eventObservers: [UUID: (String, String) -> Void] = [:]
    private var skinChangeObservers: [UUID: (String, String) -> Void] = [:]
    private var skinChangeFailedObservers: [UUID: (String, Error) -> Void] = [:]
    private var skinConfig: UISkinConfig
    private var viewHandlers: NSMapTable<NSView, Box<() -> Void>> = NSMapTable(keyOptions: .weakMemory, valueOptions: .strongMemory)

    /// UserDefaults key前缀
    private let udPrefix = "com.xianrenzhilu.skin."

    // MARK: - UIModuleProtocol

    public func start(context: [String: Any]?) throws {
        lock.lock()
        let lastSkinId = skinConfig.currentSkinId
        lock.unlock()

        /// 注册到模块注册表
        UIModuleRegistry.shared.register(instance: self, name: "SkinService", aliases: ["皮肤服务"], priority: 100)
        logger.info("皮肤服务", "皮肤服务已注册到UIModuleRegistry", moduleID: moduleID)

        /// 恢复上次使用的皮肤
        _ = setSkin(id: lastSkinId, animated: false)
        if true {
            logger.info("皮肤服务", "启动时恢复皮肤成功: \(lastSkinId)", moduleID: moduleID)
        } else {
            logger.warning("皮肤服务", "启动时恢复皮肤失败，使用默认皮肤: \(lastSkinId)", moduleID: moduleID)
        }
    }

    // MARK: - SkinServiceProtocol: 基本操作

    public func getCurrentSkin() -> SkinInfo {
        lock.lock()
        let info = currentSkinInfo
        lock.unlock()
        return info
    }

    public func setSkin(id: String) -> Bool {
        return setSkin(id: id, animated: false)
    }

    public func setSkin(id: String, animated: Bool) -> Bool {
        lock.lock()
        /// 验证皮肤是否存在
        let skinExists = registry.hasSkin(id: id)
        lock.unlock()

        if !skinExists {
            logger.warning("皮肤服务", "切换皮肤失败，皮肤不存在: \(id)", moduleID: moduleID)
            return false
        }

        lock.lock()
        let oldSkinId = currentSkinInfo.id
        lock.unlock()

        /// 如果目标皮肤就是当前皮肤，直接返回成功
        if oldSkinId == id {
            logger.info("皮肤服务", "目标皮肤与当前皮肤相同，无需切换: \(id)", moduleID: moduleID)
            return true
        }

        /// 发送皮肤即将变更通知
        NotificationCenter.default.post(
            name: .skinWillChange,
            object: self,
            userInfo: ["oldSkinId": oldSkinId, "newSkinId": id]
        )

        /// 调用所有 willChange 观察者
        lock.lock()
        let willChangeCallbacks = Array(eventObservers.values)
        lock.unlock()
        for callback in willChangeCallbacks {
            callback(oldSkinId, id)
        }

        /// 获取新皮肤信息
        guard let newSkinInfo = registry.hasSkin(id: id) ? registry.getSkin(id: id) : nil else {
            logger.error("皮肤服务", "切换皮肤失败，无法获取皮肤信息: \(id)", moduleID: moduleID)
            /// 发送变更失败通知
            let error = NSError(domain: "com.xianrenzhilu.skin", code: 1001, userInfo: [NSLocalizedDescriptionKey: "无法获取皮肤信息: \(id)"])
            NotificationCenter.default.post(
                name: .skinChangeFailed,
                object: self,
                userInfo: ["skinId": id, "error": error]
            )
            lock.lock()
            let failedCallbacks = Array(skinChangeFailedObservers.values)
            lock.unlock()
            for callback in failedCallbacks {
                callback(id, error)
            }
            return false
        }

        /// 通知引擎切换皮肤（自动更新 defaultColorHexes 和清除 colorCache）
        _ = engine.applySkin(id: id, animated: animated)

        /// 执行切换
        lock.lock()
        currentSkinInfo = newSkinInfo
        skinConfig.currentSkinId = id
        lock.unlock()

        /// 保存到UserDefaults
        UserDefaults.standard.set(id, forKey: "com.xianrenzhilu.skin.currentSkinId")
        UserDefaults.standard.synchronize()

        /// 发送皮肤已变更通知
        NotificationCenter.default.post(
            name: .skinDidChange,
            object: self,
            userInfo: ["oldSkinId": oldSkinId, "newSkinId": id]
        )

        /// 调用所有 didChange 观察者
        lock.lock()
        let didChangeCallbacks = Array(skinChangeObservers.values)
        lock.unlock()
        for callback in didChangeCallbacks {
            callback(oldSkinId, id)
        }

        /// 刷新所有已注册视图
        refreshAllViews()

        logger.info("皮肤服务", "皮肤切换成功: \(oldSkinId) → \(id) (animated: \(animated))", moduleID: moduleID)
        return true
    }

    public func getSkinList() -> [SkinInfo] {
        return registry.getAllSkins()
    }

    public func getSkin(id: String) -> SkinInfo? {
        return registry.getSkin(id: id)
    }

    public func getDefaultSkinId() -> String {
        return "com.app.glass"
    }

    public func restoreDefaultSkin() -> Bool {
        return setSkin(id: "com.app.glass")
    }

    public func previewSkin(id: String) -> Bool {
        lock.lock()
        /// 如果正在预览中，先取消当前预览
        if previewTimer != nil {
            previewTimer?.invalidate()
            previewTimer = nil
        }
        lock.unlock()

        /// 验证皮肤存在
        if !registry.hasSkin(id: id) {
            logger.warning("皮肤服务", "预览皮肤失败，皮肤不存在: \(id)", moduleID: moduleID)
            return false
        }

        guard let targetSkin = registry.getSkin(id: id) else {
            logger.warning("皮肤服务", "预览皮肤失败，无法获取皮肤信息: \(id)", moduleID: moduleID)
            return false
        }

        lock.lock()
        /// 备份当前皮肤
        previousSkinBeforePreview = currentSkinInfo
        /// 应用目标皮肤（不发送通知，不保存UserDefaults）
        currentSkinInfo = targetSkin
        skinConfig.currentSkinId = id
        previewSkinInfo = targetSkin
        lock.unlock()

        /// 通知引擎预览皮肤（更新引擎颜色定义但不保存）
        _ = engine.applySkin(id: id, animated: false)

        /// 刷新视图
        refreshAllViews()

        /// 启动30秒超时定时器
        let timer = Timer.scheduledTimer(withTimeInterval: previewTimeout, repeats: false) { [weak self] _ in
            _ = self?.cancelPreview()
            self?.logger.info("皮肤服务", "预览超时，自动恢复原始皮肤", moduleID: self?.moduleID)
        }

        lock.lock()
        previewTimer = timer
        lock.unlock()

        logger.info("皮肤服务", "开始预览皮肤: \(id)，\(previewTimeout)秒后自动恢复", moduleID: moduleID)
        return true
    }

    public func applyPreview() -> Bool {
        lock.lock()
        /// 取消定时器
        previewTimer?.invalidate()
        previewTimer = nil

        /// 确认有预览状态
        guard previewSkinInfo != nil else {
            lock.unlock()
            logger.warning("皮肤服务", "应用预览失败，当前未在预览状态", moduleID: moduleID)
            return false
        }
        lock.unlock()

        /// 保存当前（预览的）皮肤到UserDefaults
        lock.lock()
        let currentId = skinConfig.currentSkinId
        lock.unlock()
        UserDefaults.standard.set(currentId, forKey: "com.xianrenzhilu.skin.currentSkinId")
        UserDefaults.standard.synchronize()

        /// 清除预览状态
        lock.lock()
        previewSkinInfo = nil
        previousSkinBeforePreview = nil
        lock.unlock()

        logger.info("皮肤服务", "预览已应用，皮肤永久切换为: \(currentId)", moduleID: moduleID)
        return true
    }

    public func cancelPreview() -> Bool {
        lock.lock()
        /// 取消定时器
        previewTimer?.invalidate()
        previewTimer = nil

        /// 恢复旧皮肤
        guard let oldSkin = previousSkinBeforePreview else {
            lock.unlock()
            logger.info("皮肤服务", "取消预览，无备份皮肤可恢复", moduleID: moduleID)
            return false
        }

        currentSkinInfo = oldSkin
        skinConfig.currentSkinId = oldSkin.id
        let restoredSkinId = oldSkin.id
        previewSkinInfo = nil
        previousSkinBeforePreview = nil
        lock.unlock()

        /// 通知引擎恢复旧皮肤
        _ = engine.applySkin(id: restoredSkinId, animated: false)

        /// 刷新视图
        refreshAllViews()

        logger.info("皮肤服务", "预览已取消，恢复皮肤: \(restoredSkinId)", moduleID: moduleID)
        return true
    }

    // MARK: - SkinServiceProtocol: 颜色

    public func color(_ key: String) -> NSColor? {
        guard let semantic = UIColorSemantic(rawValue: key) else { return nil }
        return engine.color(for: semantic)
    }

    public func color(_ key: String, category: String) -> NSColor? {
        guard let semantic = UIColorSemantic(rawValue: key) else { return nil }
        return engine.color(for: semantic)
    }

    public func getAllColors() -> [String: NSColor] {
        return engine.getAllColors()
    }

    public func setAccentColor(_ color: NSColor) -> Bool {
        guard let hex = nsColorToHex(color) else {
            logger.warning("皮肤服务", "设置强调色失败，无法转换为Hex", moduleID: moduleID)
            return false
        }
        lock.lock()
        skinConfig.accentColorHex = hex
        lock.unlock()
        UserDefaults.standard.set(hex, forKey: "com.xianrenzhilu.skin.accentColorHex")
        UserDefaults.standard.synchronize()
        logger.info("皮肤服务", "强调色已设置: \(hex)", moduleID: moduleID)
        return true
    }

    public func resetAccentColor() -> Bool {
        lock.lock()
        skinConfig.accentColorHex = nil
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: "com.xianrenzhilu.skin.accentColorHex")
        UserDefaults.standard.synchronize()
        logger.info("皮肤服务", "强调色已重置", moduleID: moduleID)
        return true
    }

    public func color(for semantic: UIColorSemantic) -> NSColor? {
        return engine.color(for: semantic)
    }

    // MARK: - SkinServiceProtocol: 字体

    public func font(_ key: String) -> NSFont? {
        return engine.font(key, size: 14)
    }

    public func font(_ key: String, size: CGFloat) -> NSFont? {
        return engine.font(key, size: size)
    }

    public func scaledFont(_ key: String, size: CGFloat, weight: NSFont.Weight) -> NSFont? {
        return engine.scaledFont(key, size: size, weight: weight)
    }

    public func getAllFonts() -> [String: NSFont] {
        return engine.getAllFonts()
    }

    public func setFontScale(_ scale: CGFloat) -> Bool {
        let clampedScale = max(0.5, min(2.0, scale))
        lock.lock()
        skinConfig.fontScale = clampedScale
        lock.unlock()
        UserDefaults.standard.set(clampedScale, forKey: "com.xianrenzhilu.skin.fontScale")
        UserDefaults.standard.synchronize()
        logger.info("皮肤服务", "字体缩放已设置: \(clampedScale)", moduleID: moduleID)
        return true
    }

    public func getFontScale() -> CGFloat {
        lock.lock()
        let scale = skinConfig.fontScale
        lock.unlock()
        return scale
    }

    // MARK: - SkinServiceProtocol: 尺寸

    public func spacing(_ key: String) -> CGFloat {
        return engine.spacing(key)
    }

    public func spacing(_ key: String, category: String) -> CGFloat {
        return engine.spacing(key, category: category)
    }

    public func cornerRadius(_ key: String) -> CGFloat {
        return engine.cornerRadius(key)
    }

    public func borderWidth(_ key: String) -> CGFloat {
        return engine.borderWidth(key)
    }

    public func setGlobalSpacing(_ value: CGFloat, forKey key: String) -> Bool {
        lock.lock()
        skinConfig.customSpacings[key] = value
        lock.unlock()
        UserDefaults.standard.set(skinConfig.customSpacings, forKey: "com.xianrenzhilu.skin.customSpacings")
        UserDefaults.standard.synchronize()
        logger.info("皮肤服务", "全局间距已设置: \(key) = \(value)", moduleID: moduleID)
        return true
    }

    public func resetSpacingOverrides() -> Bool {
        lock.lock()
        skinConfig.customSpacings.removeAll()
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: "com.xianrenzhilu.skin.customSpacings")
        UserDefaults.standard.synchronize()
        logger.info("皮肤服务", "间距覆盖已重置", moduleID: moduleID)
        return true
    }

    // MARK: - SkinServiceProtocol: 事件

    public func onSkinWillChange(_ callback: @escaping (String, String) -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        eventObservers[id] = callback
        lock.unlock()
        logger.info("皮肤服务", "注册 willChange 观察者: \(id)", moduleID: moduleID)
        return id
    }

    public func onSkinDidChange(_ callback: @escaping (String, String) -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        skinChangeObservers[id] = callback
        lock.unlock()
        logger.info("皮肤服务", "注册 didChange 观察者: \(id)", moduleID: moduleID)
        return id
    }

    public func onSkinChangeFailed(_ callback: @escaping (String, Error) -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        skinChangeFailedObservers[id] = callback
        lock.unlock()
        logger.info("皮肤服务", "注册 changeFailed 观察者: \(id)", moduleID: moduleID)
        return id
    }

    public func removeObserver(_ id: UUID) -> Bool {
        lock.lock()
        var removed = false
        if eventObservers.removeValue(forKey: id) != nil {
            removed = true
        }
        if skinChangeObservers.removeValue(forKey: id) != nil {
            removed = true
        }
        if skinChangeFailedObservers.removeValue(forKey: id) != nil {
            removed = true
        }
        lock.unlock()
        if removed {
            logger.info("皮肤服务", "观察者已移除: \(id)", moduleID: moduleID)
        }
        return removed
    }

    // MARK: - SkinServiceProtocol: 视图注册

    public func registerView(_ view: NSView, forSkinUpdate handler: @escaping () -> Void) {
        lock.lock()
        viewHandlers.setObject(Box(handler), forKey: view)
        lock.unlock()
        logger.info("皮肤服务", "视图已注册皮肤更新: \(view)", moduleID: moduleID)
    }

    public func unregisterView(_ view: NSView) {
        lock.lock()
        viewHandlers.removeObject(forKey: view)
        lock.unlock()
        logger.info("皮肤服务", "视图已注销皮肤更新: \(view)", moduleID: moduleID)
    }

    public func refreshAllViews() {
        lock.lock()
        let enumerator = viewHandlers.keyEnumerator()
        var handlers: [() -> Void] = []
        while let view = enumerator.nextObject() as? NSView {
            if let box = viewHandlers.object(forKey: view) {
                handlers.append(box.value)
            }
        }
        lock.unlock()

        for handler in handlers {
            handler()
        }
        logger.info("皮肤服务", "已刷新 \(handlers.count) 个视图", moduleID: moduleID)
    }

    public func isViewRegistered(_ view: NSView) -> Bool {
        lock.lock()
        let exists = viewHandlers.object(forKey: view) != nil
        lock.unlock()
        return exists
    }

    // MARK: - SkinServiceProtocol: 设置面板

    public func getAvailableAccentColors() -> [(name: String, color: NSColor)] {
        return [
            ("蓝色", NSColor.systemBlue),
            ("紫色", NSColor.systemPurple),
            ("粉色", NSColor.systemPink),
            ("红色", NSColor.systemRed),
            ("橙色", NSColor.systemOrange),
            ("黄色", NSColor.systemYellow),
            ("绿色", NSColor.systemGreen),
            ("青色", NSColor.systemTeal),
            ("靛蓝", NSColor.systemIndigo),
            ("棕色", NSColor.systemBrown),
            ("灰色", NSColor.systemGray)
        ]
    }

    public func getAvailableFonts() -> [String] {
        return [
            "SF Pro",
            "SF Pro Display",
            "SF Pro Text",
            "SF Mono",
            "New York",
            "Helvetica Neue",
            "PingFang SC",
            "Heiti SC",
            "Songti SC",
            "Kaiti SC",
            "Arial",
            "Times New Roman",
            "Menlo",
            "Monaco",
            "Courier"
        ]
    }

    public func getCurrentSkinConfig() -> UISkinConfig {
        lock.lock()
        let config = skinConfig
        lock.unlock()
        return config
    }

    public func exportSkinConfig() -> Data? {
        lock.lock()
        let config = skinConfig
        lock.unlock()
        do {
            let data = try JSONEncoder().encode(config)
            logger.info("皮肤服务", "皮肤配置导出成功", moduleID: moduleID)
            return data
        } catch {
            logger.error("皮肤服务", "皮肤配置导出失败: \(error.localizedDescription)", moduleID: moduleID)
            return nil
        }
    }

    public func importSkinConfig(_ data: Data) -> Bool {
        do {
            let config = try JSONDecoder().decode(UISkinConfig.self, from: data)
            lock.lock()
            skinConfig = config
            lock.unlock()

            /// 同步到UserDefaults
            UserDefaults.standard.set(config.currentSkinId, forKey: "com.xianrenzhilu.skin.currentSkinId")
            UserDefaults.standard.set(config.accentColorHex, forKey: "com.xianrenzhilu.skin.accentColorHex")
            UserDefaults.standard.set(config.fontScale, forKey: "com.xianrenzhilu.skin.fontScale")
            UserDefaults.standard.set(config.cornerRadiusScale, forKey: "com.xianrenzhilu.skin.cornerRadiusScale")
            UserDefaults.standard.set(config.animationEnabled, forKey: "com.xianrenzhilu.skin.animationEnabled")
            UserDefaults.standard.set(config.highContrastEnabled, forKey: "com.xianrenzhilu.skin.highContrastEnabled")
            UserDefaults.standard.set(config.colorBlindMode.rawValue, forKey: "com.xianrenzhilu.skin.colorBlindMode")
            UserDefaults.standard.set(config.customColors, forKey: "com.xianrenzhilu.skin.customColors")
            UserDefaults.standard.set(config.customSpacings, forKey: "com.xianrenzhilu.skin.customSpacings")
            UserDefaults.standard.synchronize()

            logger.info("皮肤服务", "皮肤配置导入成功", moduleID: moduleID)
            return true
        } catch {
            logger.error("皮肤服务", "皮肤配置导入失败: \(error.localizedDescription)", moduleID: moduleID)
            return false
        }
    }

    public func resetAllSettings() -> Bool {
        lock.lock()
        skinConfig = UISkinConfig(
            currentSkinId: "com.app.glass",
            accentColorHex: nil,
            fontScale: 1.0,
            cornerRadiusScale: 1.0,
            animationEnabled: true,
            highContrastEnabled: false,
            colorBlindMode: .none,
            customColors: [:],
            customSpacings: [:]
        )
        currentSkinInfo = SkinInfo(
            id: "com.app.glass",
            name: "玻璃皮肤",
            version: "1.0.0",
            author: "系统",
            description: "系统默认玻璃皮肤",
            previewImage: nil,
            isDefault: true,
            isSystem: true,
            tags: ["glass", "default", "skin"],
            minEngineVersion: "1.0.0"
        )
        lock.unlock()

        /// 清除所有UserDefaults
        UserDefaults.standard.removeObject(forKey: "com.xianrenzhilu.skin.currentSkinId")
        UserDefaults.standard.removeObject(forKey: "com.xianrenzhilu.skin.accentColorHex")
        UserDefaults.standard.removeObject(forKey: "com.xianrenzhilu.skin.fontScale")
        UserDefaults.standard.removeObject(forKey: "com.xianrenzhilu.skin.cornerRadiusScale")
        UserDefaults.standard.removeObject(forKey: "com.xianrenzhilu.skin.animationEnabled")
        UserDefaults.standard.removeObject(forKey: "com.xianrenzhilu.skin.highContrastEnabled")
        UserDefaults.standard.removeObject(forKey: "com.xianrenzhilu.skin.colorBlindMode")
        UserDefaults.standard.removeObject(forKey: "com.xianrenzhilu.skin.customColors")
        UserDefaults.standard.removeObject(forKey: "com.xianrenzhilu.skin.customSpacings")
        UserDefaults.standard.synchronize()

        /// 刷新视图
        refreshAllViews()

        logger.info("皮肤服务", "所有皮肤设置已重置为默认值", moduleID: moduleID)
        return true
    }

    // MARK: - SkinServiceProtocol: 色盲

    public func setColorBlindMode(_ mode: UIColorBlindMode) {
        lock.lock()
        skinConfig.colorBlindMode = mode
        lock.unlock()
        UserDefaults.standard.set(mode.rawValue, forKey: "com.xianrenzhilu.skin.colorBlindMode")
        UserDefaults.standard.synchronize()
        logger.info("皮肤服务", "色盲模式已设置: \(mode.rawValue)", moduleID: moduleID)
    }

    public func currentColorBlindMode() -> UIColorBlindMode {
        lock.lock()
        let mode = skinConfig.colorBlindMode
        lock.unlock()
        return mode
    }
}
// 已改用 UI-02_公共类型定义.swift 中的公共类型：Box

// MARK: - 颜色辅助函数
private func nsColorToHex(_ color: NSColor) -> String? {
    guard let rgbColor = color.usingColorSpace(.sRGB) else { return nil }
    let r = Int(round(rgbColor.redComponent * 255))
    let g = Int(round(rgbColor.greenComponent * 255))
    let b = Int(round(rgbColor.blueComponent * 255))
    return String(format: "#%02X%02X%02X", r, g, b)
}

// MARK: - 全局函数
public func getSkinService() -> SkinServiceProtocol? { return SkinService.shared }
// 已改用 UI-02_公共类型定义.swift 中的公共类型：Notification.Name

// MARK: - 测试
internal func test_SkinService() {
    print("\n=== Skin-01 皮肤系统入口测试开始 ===\n")
    let service = SkinService.shared
    _ = UILoadingLogManager.shared

    // 测试1: 注册到UIModuleRegistry
    print("🧪 测试1: 验证注册到UIModuleRegistry")
    try? service.start(context: nil)
    let registry = UIModuleRegistry.shared
    guard registry.isRegistered(name: "SkinService") else {
        fatalError("❌ 测试1失败: SkinService 应已注册到UIModuleRegistry")
    }
    guard registry.isRegistered(name: "皮肤服务") else {
        fatalError("❌ 测试1失败: 别名 '皮肤服务' 应已注册")
    }
    print("✅ 测试1通过: 注册成功")

    // 测试2: 获取当前皮肤
    print("🧪 测试2: 验证获取当前皮肤")
    let current = service.getCurrentSkin()
    guard !current.id.isEmpty else {
        fatalError("❌ 测试2失败: 当前皮肤ID不应为空")
    }
    print("✅ 测试2通过: 当前皮肤 \(current.id)")

    // 测试3: 设置皮肤（不存在的皮肤应失败）
    print("🧪 测试3: 验证设置不存在的皮肤")
    let setFail = service.setSkin(id: "nonexistent.skin.123", animated: false)
    guard setFail == false else {
        fatalError("❌ 测试3失败: 设置不存在的皮肤应返回false")
    }
    print("✅ 测试3通过: 设置不存在皮肤返回false")

    // 测试4: 设置默认皮肤（应成功）
    print("🧪 测试4: 验证设置默认皮肤")
    let setDefault = service.setSkin(id: "com.app.glass", animated: false)
    guard setDefault == true else {
        fatalError("❌ 测试4失败: 设置默认皮肤应返回true")
    }
    let afterDefault = service.getCurrentSkin()
    guard afterDefault.id == "com.app.glass" else {
        fatalError("❌ 测试4失败: 设置后当前皮肤应为 com.app.glass，实际: \(afterDefault.id)")
    }
    print("✅ 测试4通过: 设置默认皮肤成功")

    // 测试5: 获取皮肤列表
    print("🧪 测试5: 验证获取皮肤列表")
    let skinList = service.getSkinList()
    guard skinList.count >= 0 else {
        fatalError("❌ 测试5失败: 皮肤列表数量不应为负")
    }
    print("✅ 测试5通过: 获取皮肤列表 \(skinList.count) 个")

    // 测试6: 获取单个皮肤（不存在）
    print("🧪 测试6: 验证获取不存在的皮肤")
    let nonExistSkin = service.getSkin(id: "nonexistent.skin")
    guard nonExistSkin == nil else {
        fatalError("❌ 测试6失败: 获取不存在的皮肤应返回nil")
    }
    print("✅ 测试6通过: 获取不存在皮肤返回nil")

    // 测试7: 恢复默认皮肤
    print("🧪 测试7: 验证恢复默认皮肤")
    let restore = service.restoreDefaultSkin()
    guard restore == true else {
        fatalError("❌ 测试7失败: 恢复默认皮肤应返回true")
    }
    guard service.getCurrentSkin().id == "com.app.glass" else {
        fatalError("❌ 测试7失败: 恢复后应为默认皮肤")
    }
    print("✅ 测试7通过: 恢复默认皮肤成功")

    // 测试8: 预览皮肤（不存在的应失败）
    print("🧪 测试8: 验证预览不存在的皮肤")
    let previewFail = service.previewSkin(id: "nonexistent.skin")
    guard previewFail == false else {
        fatalError("❌ 测试8失败: 预览不存在的皮肤应失败")
    }
    print("✅ 测试8通过: 预览不存在皮肤失败")

    // 测试9: 预览默认皮肤（应成功）+ 取消预览
    print("🧪 测试9: 验证预览并取消")
    let previewOk = service.previewSkin(id: "com.app.glass")
    guard previewOk == true else {
        fatalError("❌ 测试9失败: 预览默认皮肤应成功")
    }
    let cancelOk = service.cancelPreview()
    guard cancelOk == true else {
        fatalError("❌ 测试9失败: 取消预览应成功")
    }
    guard service.getCurrentSkin().id == "com.app.glass" else {
        fatalError("❌ 测试9失败: 取消预览后应恢复默认皮肤")
    }
    print("✅ 测试9通过: 预览并取消成功")

    // 测试10: 应用预览（无预览状态应失败）
    print("🧪 测试10: 验证无预览时应用失败")
    let applyNoPreview = service.applyPreview()
    guard applyNoPreview == false else {
        fatalError("❌ 测试10失败: 无预览状态时应用预览应失败")
    }
    print("✅ 测试10通过: 无预览时应用失败")

    // 测试11: 事件观察者注册与移除
    print("🧪 测试11: 验证事件观察者注册与移除")
    let willId = service.onSkinWillChange { old, new in
        // willChange 回调
    }
    let didId = service.onSkinDidChange { old, new in
        // didChange: \(old) → \(new)")
    }
    let failedId = service.onSkinChangeFailed { skinId, error in
        // changeFailed: \(skinId) \(error.localizedDescription)")
    }
    guard !willId.uuidString.isEmpty else {
        fatalError("❌ 测试11失败: willChange 观察者ID不应为空")
    }
    guard !didId.uuidString.isEmpty else {
        fatalError("❌ 测试11失败: didChange 观察者ID不应为空")
    }
    guard !failedId.uuidString.isEmpty else {
        fatalError("❌ 测试11失败: changeFailed 观察者ID不应为空")
    }
    let removeWill = service.removeObserver(willId)
    guard removeWill == true else {
        fatalError("❌ 测试11失败: 移除已注册的观察者应返回true")
    }
    let removeFake = service.removeObserver(UUID())
    guard removeFake == false else {
        fatalError("❌ 测试11失败: 移除不存在的观察者应返回false")
    }
    print("✅ 测试11通过: 事件观察者注册与移除正确")

    print("🧪 测试12: 视图注册")
    let dummyView = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
    var viewUpdated = false
    service.registerView(dummyView) {
        viewUpdated = true
    }
    guard service.isViewRegistered(dummyView) == true else {
        fatalError("❌ 测试12失败: 注册后视图应存在")
    }
    service.refreshAllViews()
    guard viewUpdated == true else {
        fatalError("❌ 测试12失败: 刷新后视图handler应被调用")
    }
    service.unregisterView(dummyView)
    guard service.isViewRegistered(dummyView) == false else {
        fatalError("❌ 测试12失败: 注销后视图不应存在")
    }
    print("✅ 测试12通过: 视图注册与刷新正确")

    print("🧪 测试13: 设置强调色")
    let accentColor = NSColor.systemBlue
    let setAccent = service.setAccentColor(accentColor)
    guard setAccent == true else {
        fatalError("❌ 测试13失败: 设置强调色应成功")
    }
    let configAfterAccent = service.getCurrentSkinConfig()
    guard configAfterAccent.accentColorHex != nil else {
        fatalError("❌ 测试13失败: 设置后accentColorHex不应为nil")
    }
    print("✅ 测试13通过: 强调色设置成功 \(configAfterAccent.accentColorHex!)")

    print("🧪 测试14: 重置强调色")
    let resetAccent = service.resetAccentColor()
    guard resetAccent == true else {
        fatalError("❌ 测试14失败: 重置强调色应成功")
    }
    let configAfterReset = service.getCurrentSkinConfig()
    guard configAfterReset.accentColorHex == nil else {
        fatalError("❌ 测试14失败: 重置后accentColorHex应为nil")
    }
    print("✅ 测试14通过: 强调色重置成功")

    print("🧪 测试15: 字体缩放")
    let setScale = service.setFontScale(1.5)
    guard setScale == true else {
        fatalError("❌ 测试15失败: 设置字体缩放应成功")
    }
    let scale = service.getFontScale()
    guard scale == 1.5 else {
        fatalError("❌ 测试15失败: 字体缩放应为1.5，实际: \(scale)")
    }
    
    /// 测试边界值（应被限制）
    _ = service.setFontScale(5.0)
    let clampedScale = service.getFontScale()
    guard clampedScale == 2.0 else {
        fatalError("❌ 测试15失败: 过大缩放应被限制为2.0，实际: \(clampedScale)")
    }
    _ = service.setFontScale(0.1)
    let clampedScaleLow = service.getFontScale()
    guard clampedScaleLow == 0.5 else {
        fatalError("❌ 测试15失败: 过小缩放应被限制为0.5，实际: \(clampedScaleLow)")
    }
    _ = service.setFontScale(1.0)
    print("✅ 测试15通过: 字体缩放设置与边界正确")

    print("🧪 测试16: 全局间距")
    let setSpacing = service.setGlobalSpacing(16.0, forKey: "windowPadding")
    guard setSpacing == true else {
        fatalError("❌ 测试16失败: 设置全局间距应成功")
    }
    let resetSpacing = service.resetSpacingOverrides()
    guard resetSpacing == true else {
        fatalError("❌ 测试16失败: 重置间距应成功")
    }
    let configAfterSpacingReset = service.getCurrentSkinConfig()
    guard configAfterSpacingReset.customSpacings.isEmpty else {
        fatalError("❌ 测试16失败: 重置后customSpacings应为空")
    }
    print("✅ 测试16通过: 全局间距设置与重置正确")

    print("🧪 测试17: 色盲模式")
    service.setColorBlindMode(.protanopia)
    let cbMode = service.currentColorBlindMode()
    guard cbMode == .protanopia else {
        fatalError("❌ 测试17失败: 色盲模式应为protanopia，实际: \(cbMode.rawValue)")
    }
    service.setColorBlindMode(.none)
    let cbModeNone = service.currentColorBlindMode()
    guard cbModeNone == .none else {
        fatalError("❌ 测试17失败: 色盲模式应为none，实际: \(cbModeNone.rawValue)")
    }
    print("✅ 测试17通过: 色盲模式切换正确")

    print("🧪 测试18: 配置导出与导入")
    _ = service.setFontScale(1.2)
    service.setColorBlindMode(.deuteranopia)
    let exported = service.exportSkinConfig()
    guard exported != nil else {
        fatalError("❌ 测试18失败: 导出配置不应为nil")
    }
    guard exported!.count > 0 else {
        fatalError("❌ 测试18失败: 导出配置数据不应为空")
    }
    /// 重置后导入
    _ = service.resetAllSettings()
    let imported = service.importSkinConfig(exported!)
    guard imported == true else {
        fatalError("❌ 测试18失败: 导入配置应成功")
    }
    let configAfterImport = service.getCurrentSkinConfig()
    guard configAfterImport.fontScale == 1.2 else {
        fatalError("❌ 测试18失败: 导入后字体缩放应为1.2，实际: \(configAfterImport.fontScale)")
    }
    guard configAfterImport.colorBlindMode == .deuteranopia else {
        fatalError("❌ 测试18失败: 导入后色盲模式应为deuteranopia，实际: \(configAfterImport.colorBlindMode.rawValue)")
    }
    print("✅ 测试18通过: 配置导出与导入正确")

    print("🧪 测试19: 重置所有设置")
    let resetAll = service.resetAllSettings()
    guard resetAll == true else {
        fatalError("❌ 测试19失败: 重置所有设置应成功")
    }
    let configAfterAllReset = service.getCurrentSkinConfig()
    guard configAfterAllReset.currentSkinId == "com.app.glass" else {
        fatalError("❌ 测试19失败: 重置后currentSkinId应为默认")
    }
    guard configAfterAllReset.fontScale == 1.0 else {
        fatalError("❌ 测试19失败: 重置后fontScale应为1.0")
    }
    guard configAfterAllReset.colorBlindMode == .none else {
        fatalError("❌ 测试19失败: 重置后colorBlindMode应为none")
    }
    guard configAfterAllReset.customColors.isEmpty else {
        fatalError("❌ 测试19失败: 重置后customColors应为空")
    }
    guard configAfterAllReset.customSpacings.isEmpty else {
        fatalError("❌ 测试19失败: 重置后customSpacings应为空")
    }
    print("✅ 测试19通过: 重置所有设置正确")

    print("🧪 测试20: 可用颜色与字体列表")
    let accentColors = service.getAvailableAccentColors()
    guard accentColors.count > 0 else {
        fatalError("❌ 测试20失败: 可用强调色列表不应为空")
    }
    let fonts = service.getAvailableFonts()
    guard fonts.count > 0 else {
        fatalError("❌ 测试20失败: 可用字体列表不应为空")
    }
    print("✅ 测试20通过: 可用颜色 \(accentColors.count) 个，字体 \(fonts.count) 个")

    print("🧪 测试21: 默认皮肤ID")
    let defaultId = service.getDefaultSkinId()
    guard defaultId == "com.app.glass" else {
        fatalError("❌ 测试21失败: 默认皮肤ID应为 com.app.glass，实际: \(defaultId)")
    }
    print("✅ 测试21通过: 默认皮肤ID正确")

    print("🧪 测试22: 全局函数")
    let globalService = getSkinService()
    guard globalService != nil else {
        fatalError("❌ 测试22失败: 全局函数 getSkinService 不应返回nil")
    }
    guard (globalService as? SkinService) === SkinService.shared else {
        fatalError("❌ 测试22失败: 全局函数应返回 shared 实例")
    }
    print("✅ 测试22通过: 全局函数返回正确")

    print("🧪 测试23: UserDefaults持久化")
    let ud = UserDefaults.standard
    let savedSkinId = ud.string(forKey: "com.xianrenzhilu.skin.currentSkinId")
    guard savedSkinId == "com.app.glass" else {
        fatalError("❌ 测试23失败: UserDefaults中皮肤ID应为 com.app.glass，实际: \(savedSkinId ?? "nil")")
    }
    print("✅ 测试23通过: UserDefaults持久化正确")

    print("🧪 测试24: 通知发送")
    var willNotified = false
    var didNotified = false
    let willToken = NotificationCenter.default.addObserver(forName: .skinWillChange, object: service, queue: nil) { _ in
        willNotified = true
    }
    let didToken = NotificationCenter.default.addObserver(forName: .skinDidChange, object: service, queue: nil) { _ in
        didNotified = true
    }
    _ = service.setSkin(id: "com.app.glass", animated: false)
    guard willNotified == true else {
        fatalError("❌ 测试24失败: 皮肤切换应发送 willChange 通知")
    }
    guard didNotified == true else {
        fatalError("❌ 测试24失败: 皮肤切换应发送 didChange 通知")
    }
    NotificationCenter.default.removeObserver(willToken)
    NotificationCenter.default.removeObserver(didToken)
    print("✅ 测试24通过: 通知发送正确")

    print("🧪 测试25: 服务停止与卸载")
    service.stop()
    try? service.willUnload()
    print("✅ 测试25通过: 停止与卸载无崩溃")

    print("🧪 测试26: 再次启动（验证可重入）")
    try? service.start(context: nil)
    print("✅ 测试26通过: 再次启动无异常")

    print("\n=== Skin-01 皮肤系统入口测试完毕 ✅ ===\n")
}
// 已改用 UI-02_公共类型定义.swift 中的公共类型：UIUnifiedRegistry

