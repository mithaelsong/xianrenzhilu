import Foundation
import Cocoa
import os.log

// MARK: - 默认浅色皮肤

public final class DefaultLightSkin: SkinProtocol , @unchecked Sendable{
    public let skinId: String = "internal.theme.light.defaults"
    public let skinName: String = "默认浅色"
    public let skinVersion: String = "1.0.0"

    // MARK: 颜色定义

    /// 颜色定义（十六进制字符串，切换皮肤时实时解析，不会写死）
    public let colors: [String: String] = [
        "accent": "#007AFF",
        "accentHover": "#0A52D6",
        "accentPressed": "#0040A8",
        "windowBackground": "#FFFFFF",
        "textPrimary": "#000000",
        "textSecondary": "rgba(0,0,0,0.5)",
        "textTertiary": "rgba(0,0,0,0.3)",
        "separator": "rgba(0,0,0,0.1)",
        "separatorStrong": "rgba(0,0,0,0.2)",
        "border": "rgba(0,0,0,0.2)",
        "borderFocus": "#007AFF",
        "buttonBackground": "rgba(0,0,0,0.04)",
        "buttonHover": "rgba(0,0,0,0.09)",
        "buttonPressed": "rgba(0,0,0,0.18)",
        "inputBackground": "rgba(0,0,0,0.02)",
        "inputBorder": "rgba(0,0,0,0.15)",
        "inputFocusBorder": "#007AFF",
        "chartUp": "#34C759",
        "chartDown": "#FF3B30",
        "chartLine": "#007AFF",
        "chartGrid": "rgba(0,0,0,0.05)",
        "chartBackground": "#FFFFFF",
        "chartCrosshair": "rgba(0,0,0,0.3)",
        "tooltipBackground": "rgba(0,0,0,0.8)",
        "tooltipText": "#FFFFFF",
        "sidebarBackground": "rgba(0,0,0,0.04)",
        "sidebarSelected": "rgba(0,0,0,0.08)",
        "overlayBackground": "rgba(0,0,0,0.4)",
        "error": "#FF3B30",
        "warning": "#FF9500",
        "success": "#34C759",
        "info": "#007AFF"
    ]

    // MARK: 字体定义

    public let fonts: [String: NSFont] = [
        "body": NSFont.systemFont(ofSize: 13.0),
        "bodySmall": NSFont.systemFont(ofSize: 11.0),
        "bodyLarge": NSFont.systemFont(ofSize: 15.0),
        "title": NSFont.systemFont(ofSize: 17.0, weight: .medium),
        "titleLarge": NSFont.systemFont(ofSize: 20.0, weight: .medium),
        "headline": NSFont.systemFont(ofSize: 15.0, weight: .semibold),
        "caption": NSFont.systemFont(ofSize: 11.0),
        "caption2": NSFont.systemFont(ofSize: 10.0),
        "code": NSFont(name: "SF Mono", size: 11.0) ?? NSFont.monospacedSystemFont(ofSize: 11.0, weight: .regular),
        "chart": NSFont.systemFont(ofSize: 10.0),
        "chartLabel": NSFont.systemFont(ofSize: 9.0),
        "button": NSFont.systemFont(ofSize: 13.0, weight: .medium),
        "input": NSFont.systemFont(ofSize: 13.0)
    ]

    // MARK: 间距定义

    public let spacings: [String: CGFloat] = [
        "controlPadding": 8.0,
        "controlPaddingSmall": 4.0,
        "controlPaddingLarge": 12.0,
        "windowPadding": 20.0,
        "windowPaddingSmall": 12.0,
        "elementSpacing": 4.0,
        "elementSpacingSmall": 2.0,
        "elementSpacingLarge": 8.0,
        "sectionSpacing": 12.0,
        "sectionSpacingLarge": 16.0,
        "groupSpacing": 24.0,
        "groupSpacingLarge": 32.0,
        "toolbarHeight": 44.0,
        "toolbarHeightSmall": 32.0,
        "sidebarWidth": 200.0,
        "sidebarWidthCollapsed": 60.0,
        "sidebarWidthExpanded": 280.0,
        "inputHeight": 28.0,
        "buttonHeight": 32.0,
        "buttonHeightSmall": 24.0,
        "buttonHeightLarge": 40.0,
        "cardPadding": 16.0,
        "listRowHeight": 36.0,
        "listRowHeightSmall": 28.0,
        "menuItemHeight": 28.0,
        "tabHeight": 36.0,
        "tooltipPadding": 8.0
    ]

    // MARK: 圆角定义

    public let cornerRadii: [String: CGFloat] = [
        "button": 5.0,
        "buttonSmall": 3.0,
        "buttonLarge": 8.0,
        "panel": 12.0,
        "window": 10.0,
        "card": 8.0,
        "cardLarge": 12.0,
        "input": 5.0,
        "inputLarge": 8.0,
        "tooltip": 4.0,
        "badge": 10.0,
        "menu": 8.0,
        "popover": 10.0,
        "sheet": 12.0
    ]

    // MARK: 边框宽度定义

    public let borderWidths: [String: CGFloat] = [
        "thin": 0.5,
        "normal": 1.0,
        "thick": 2.0,
        "focus": 2.0,
        "separator": 0.5,
        "hairline": 0.25
    ]

    public init() {}

    // MARK: 辅助查询方法

    public func color(_ key: String) -> NSColor? {
        guard let hex = colors[key] else { return nil }
        return SkinEngine.shared.parseColor(hex: hex)
    }

    public func font(_ key: String) -> NSFont? {
        return fonts[key]
    }

    public func spacing(_ key: String) -> CGFloat {
        return spacings[key] ?? 0.0
    }

    public func cornerRadius(_ key: String) -> CGFloat {
        return cornerRadii[key] ?? 0.0
    }

    public func borderWidth(_ key: String) -> CGFloat {
        return borderWidths[key] ?? 0.0
    }

    // MARK: 应用皮肤

    public func apply(to window: NSWindow) {
        window.backgroundColor = SkinEngine.shared.parseColor(hex: colors["windowBackground"] ?? "#FFFFFF") ?? NSColor.white
        // 递归应用到所有子视图
        if let contentView = window.contentView {
            applyRecursively(to: contentView, skin: self)
        }
    }

    public func apply(to view: NSView) {
        // 设置基础样式，具体视图样式由 applyRecursively 按类型区分
        if view.layer == nil {
            view.wantsLayer = true
        }
        view.layer?.backgroundColor = SkinEngine.shared.parseColor(hex: colors["windowBackground"] ?? "#FFFFFF")?.cgColor
    }

    /// 递归遍历视图层级，根据视图类型应用不同样式
    private func applyRecursively(to view: NSView, skin: DefaultLightSkin) {
        // 玻璃皮肤是 UI 基座，普通浅色皮肤递归应用时不能覆盖玻璃材质/工具栏/内容容器。
        if view.identifier?.rawValue.hasPrefix("glass.") == true {
            return
        }

        if view.layer == nil {
            view.wantsLayer = true
        }

        // 从十六进制字符串实时解析颜色，不写死 NSColor
        func skinColor(_ key: String) -> CGColor? {
            guard let hex = skin.colors[key] else { return nil }
            guard let color = SkinEngine.shared.parseColor(hex: hex) else { return nil }
            return color.cgColor
        }

        if view is NSButton {
            view.layer?.backgroundColor = skinColor("buttonBackground")
            view.layer?.cornerRadius = skin.cornerRadii["button"] ?? 5.0
            view.layer?.borderWidth = skin.borderWidths["thin"] ?? 0.5
            view.layer?.borderColor = skinColor("border")
        } else if view is NSTextField {
            view.layer?.backgroundColor = skinColor("inputBackground")
            view.layer?.cornerRadius = skin.cornerRadii["input"] ?? 5.0
            view.layer?.borderWidth = skin.borderWidths["normal"] ?? 1.0
            view.layer?.borderColor = skinColor("inputBorder")
        } else if view is NSScrollView || view is NSTableView {
            view.layer?.backgroundColor = skinColor("chartBackground")
        } else {
            view.layer?.backgroundColor = skinColor("windowBackground")
        }

        for subview in view.subviews {
            applyRecursively(to: subview, skin: skin)
        }
    }

    public func isSupported() -> Bool {
        return true
    }
}

// MARK: - 皮肤引擎

public final class SkinEngine : @unchecked Sendable {

    // MARK: 单例

    public static let shared = SkinEngine()

    // MARK: 锁

    private let lock = NSRecursiveLock()

    // MARK: 日志

    private let logger = Logger(subsystem: "com.xianrenzhilu.skin", category: "SkinEngine")

    // MARK: 当前皮肤

    private var currentSkin: SkinProtocol
    private var currentSkinId: String = "com.app.glass"

    // MARK: 颜色缓存（实时解析结果缓存，切换皮肤时自动清空）

    private var colorCache: [String: NSColor] = [:]

    // MARK: LRU 缓存

    private var skinCache: [String: SkinProtocol] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheSize = 5

    // MARK: 默认皮肤数据

    /// 默认颜色定义（十六进制字符串），切换皮肤时更新此字典，color(_:) 实时解析
    private var defaultColorHexes: [String: String] = [:]
    private var defaultFonts: [String: NSFont] = [:]
    private var defaultSpacings: [String: CGFloat] = [:]
    private var defaultCornerRadii: [String: CGFloat] = [:]
    private var defaultBorderWidths: [String: CGFloat] = [:]

    // MARK: 自定义覆盖

    private var accentColorOverride: NSColor? = nil
    private var fontScaleOverride: CGFloat = 1.0
    private var spacingOverrides: [String: CGFloat] = [:]
    private var colorBlindMode: UIColorBlindMode = .none

    // MARK: 视图注册

    private var registeredViews: NSMapTable<NSView, NSMutableArray>

    // MARK: 动画设置

    private var animationsEnabled: Bool = true
    private let animationDuration: TimeInterval = 0.25

    // MARK: 初始化

    private init() {
        self.currentSkin = DefaultLightSkin()
        self.registeredViews = NSMapTable.weakToStrongObjects()
        self.setupDefaultValues()
        self.logger.info("皮肤引擎初始化完成，默认皮肤: com.app.glass；DefaultLightSkin 仅作为浅色主题默认值来源")
        
        // 注册到统一注册表
        self.registerToUnifiedRegistry()
    }
    
    // MARK: 注册表注册
    
    private func registerToUnifiedRegistry() {
        // DefaultLightSkin 现在只是浅色主题默认值来源，不再注册为独立皮肤。
        // 真正的皮肤由 UISkinRuntimeBridge 注册，例如 com.app.glass；浅色/深色/高对比度/色盲进入主题注册表。
        self.logger.info("DefaultLightSkin 保留为主题默认值来源，未注册为独立皮肤")
    }

    // MARK: 设置默认值

    private func setupDefaultValues() {
        let skin = DefaultLightSkin()
        // 存十六进制字符串，不写死 NSColor，切换皮肤时实时解析
        self.defaultColorHexes = skin.colors
        self.defaultFonts = skin.fonts
        self.defaultSpacings = skin.spacings
        self.defaultCornerRadii = skin.cornerRadii
        self.defaultBorderWidths = skin.borderWidths
    }

    // MARK: 切换检查

    public func canSwitchTo(id: String) -> Bool {
        self.lock.lock()

        // 默认皮肤始终允许
        if id == "com.app.glass" {
            self.lock.unlock()
            return true
        }

        // 检查缓存中是否有
        if self.skinCache[id] != nil {
            self.lock.unlock()
            return true
        }

        self.lock.unlock()

        // 尝试加载验证
        if let skin = self.loadSkin(id: id) {
            return skin.isSupported()
        }

        return false
    }

    // MARK: 应用皮肤

    public func applySkin(id: String, animated: Bool) -> Bool {
        self.lock.lock()

        // 获取或加载皮肤
        var skin: SkinProtocol? = nil

        if id == "com.app.glass" {
            skin = self.skinCache[id] ?? DefaultLightSkin()
        } else if let cached = self.skinCache[id] {
            skin = cached
        }

        self.lock.unlock()

        if skin == nil {
            skin = self.loadSkin(id: id)
        }

        guard let targetSkin = skin else {
            self.logger.error("无法加载皮肤: \(id)")
            return false
        }

        guard targetSkin.isSupported() else {
            self.logger.error("皮肤不支持当前系统: \(id)")
            return false
        }

        self.lock.lock()
        let oldId = self.currentSkinId
        self.currentSkin = targetSkin
        self.currentSkinId = id
        let useAnimation = animated && self.animationsEnabled

        // 更新缓存
        if self.skinCache[id] == nil {
            self.skinCache[id] = targetSkin
            self.cacheOrder.append(id)

            // LRU 淘汰
            while self.cacheOrder.count > self.maxCacheSize {
                let oldest = self.cacheOrder.removeFirst()
                if oldest == "com.app.glass" {
                    // 默认皮肤不淘汰，移到队尾
                    self.cacheOrder.append(oldest)
                    continue
                }
                self.skinCache.removeValue(forKey: oldest)
                self.logger.info("LRU 淘汰皮肤缓存: \(oldest)")
            }
        } else {
            // 移到最近使用
            if let index = self.cacheOrder.firstIndex(of: id) {
                self.cacheOrder.remove(at: index)
            }
            self.cacheOrder.append(id)
        }

        self.lock.unlock()

        // 应用到所有已注册视图
        if useAnimation {
            self.applyWithAnimation(skin: targetSkin, fromId: oldId, toId: id)
        } else {
            self.applyWithoutAnimation(skin: targetSkin)
        }

        self.logger.info("皮肤应用成功: \(oldId) -> \(id)")
        return true
    }

    // MARK: 动画应用

    private func applyWithAnimation(skin: SkinProtocol, fromId: String, toId: String) {
        // 确保在主线程执行，否则 NSAnimationContext 会崩溃
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.applyWithAnimation(skin: skin, fromId: fromId, toId: toId)
            }
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = self.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            // 渐隐效果
            for window in NSApplication.shared.windows {
                window.animator().alphaValue = 0.8
            }
        }, completionHandler: {
            self.applyWithoutAnimation(skin: skin)

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = self.animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                for window in NSApplication.shared.windows {
                    window.animator().alphaValue = 1.0
                }
            })
        })
    }

    private func applyWithoutAnimation(skin: SkinProtocol) {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.applyWithoutAnimation(skin: skin)
            }
            return
        }

        self.lock.lock()
        let viewsTable = self.registeredViews
        self.lock.unlock()

        // 应用到所有窗口
        for window in NSApplication.shared.windows {
            skin.apply(to: window)
        }

        // 触发所有已注册视图的回调
        let allViews = viewsTable.keyEnumerator().allObjects.compactMap { $0 as? NSView }
        for view in allViews {
            if let handlers = viewsTable.object(forKey: view) {
                for handler in handlers {
                    if let box = handler as? Box<() -> Void> {
                        box.value()
                    }
                }
            }
            skin.apply(to: view)
        }
    }

    // MARK: 加载皮肤 Bundle

    private func loadSkin(id: String) -> SkinProtocol? {
        // 从应用的 Resources 中查找皮肤 bundle
        guard let bundleURL = Bundle.main.url(forResource: id, withExtension: "bundle") else {
            self.logger.warning("皮肤 bundle 未找到: \(id)")
            return nil
        }

        guard let bundle = Bundle(url: bundleURL) else {
            self.logger.error("无法创建 bundle 实例: \(bundleURL.path)")
            return nil
        }

        // 加载 bundle
        if !bundle.isLoaded {
            let loaded = bundle.load()
            if !loaded {
                self.logger.error("Bundle 加载失败: \(bundleURL.path)")
                return nil
            }
        }

        // 读取 PrincipalClass
        guard let principalClassName = bundle.infoDictionary?["NSPrincipalClass"] as? String else {
            self.logger.error("Bundle 未声明 PrincipalClass: \(bundleURL.path)")
            return nil
        }

        guard let anyClass = bundle.classNamed(principalClassName) as? NSObject.Type else {
            self.logger.error("PrincipalClass 不是 NSObject 子类: \(principalClassName)")
            return nil
        }

        guard let _ = anyClass as? SkinProtocol.Type else {
            self.logger.error("PrincipalClass 不遵循 SkinProtocol: \(principalClassName)")
            return nil
        }

        let skinInstance = anyClass.init() as? SkinProtocol
        self.logger.info("皮肤 bundle 加载成功: \(id) (\(principalClassName))")
        return skinInstance
    }

    // MARK: 颜色查询

    public func color(_ key: String) -> NSColor? {
        self.lock.lock()

        // 1. 查颜色缓存
        if let cached = self.colorCache[key] {
            self.lock.unlock()
            return cached
        }

        // 2. 检查强调色覆盖（优先级最高）
        if let override = self.accentColorOverride, key == "accent" || key == "accentColor" {
            let transformed = self.applyColorBlindTransform(color: override)
            self.colorCache[key] = transformed
            self.lock.unlock()
            return transformed
        }

        // 3. 从默认颜色查找
        // 3. 从十六进制字符串实时解析
        guard let hex = self.defaultColorHexes[key] else {
            self.lock.unlock()
            return nil
        }

        guard let color = self.parseColor(hex: hex) else {
            self.lock.unlock()
            return nil
        }

        // 4. 缓存解析结果
        let transformed = self.applyColorBlindTransform(color: color)
        self.colorCache[key] = transformed
        self.lock.unlock()
        return transformed
    }

    public func color(_ key: String, category: String) -> NSColor? {
        let fullKey = "\(category).\(key)"
        return self.color(fullKey)
    }

    public func getAllColors() -> [String: NSColor] {
        self.lock.lock()
        let hexes = self.defaultColorHexes
        let accentOverride = self.accentColorOverride
        self.lock.unlock()

        // 实时解析所有十六进制颜色
        var transformed: [String: NSColor] = [:]
        for (key, hex) in hexes {
            if let color = self.parseColor(hex: hex) {
                transformed[key] = self.applyColorBlindTransform(color: color)
            }
        }
        // 强调色覆盖（NSColor 直接应用，不经过 hex 解析）
        if let accent = accentOverride {
            transformed["accent"] = self.applyColorBlindTransform(color: accent)
        }
        return transformed
    }

    public func color(for semantic: ColorSemantic) -> NSColor? {
        let key = semantic.rawValue
        return self.color(key)
    }

    // MARK: 色盲转换

    private func applyColorBlindTransform(color: NSColor) -> NSColor {
        self.lock.lock()
        let mode = self.colorBlindMode
        self.lock.unlock()

        guard mode != .none else { return color }

        guard let rgbColor = color.usingColorSpace(.sRGB) else {
            return color
        }

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        switch mode {
        case .protanopia:
            // 红色盲：红色感知减弱，加强蓝绿通道
            let newR = 0.567 * r + 0.433 * g
            let newG = 0.558 * r + 0.442 * g
            let newB = 0.242 * g + 0.758 * b
            return NSColor(red: newR, green: newG, blue: newB, alpha: a)
        case .deuteranopia:
            // 绿色盲：绿色感知减弱，加强红蓝通道
            let newR = 0.625 * r + 0.375 * g
            let newG = 0.7 * r + 0.3 * g
            let newB = 0.3 * g + 0.7 * b
            return NSColor(red: newR, green: newG, blue: newB, alpha: a)
        case .none:
            return color
        }
    }

    // MARK: 字体查询

    public func font(_ key: String) -> NSFont? {
        self.lock.lock()
        let font = self.defaultFonts[key]
        let scale = self.fontScaleOverride
        self.lock.unlock()

        if let f = font {
            return self.scaledFont(f, scale: scale)
        }
        return nil
    }

    public func font(_ key: String, size: CGFloat) -> NSFont? {
        self.lock.lock()
        let font = self.defaultFonts[key]
        let scale = self.fontScaleOverride
        self.lock.unlock()

        if let f = font {
            let scaledSize = f.pointSize * scale
            let descriptor = f.fontDescriptor.withSize(scaledSize)
            return NSFont(descriptor: descriptor, size: 0)
        }
        return nil
    }

    public func scaledFont(_ key: String, size: CGFloat, weight: NSFont.Weight) -> NSFont? {
        self.lock.lock()
        let scale = self.fontScaleOverride
        self.lock.unlock()

        let scaledSize = size * scale
        return NSFont.systemFont(ofSize: scaledSize, weight: weight)
    }

    public func getAllFonts() -> [String: NSFont] {
        self.lock.lock()
        let fonts = self.defaultFonts
        let scale = self.fontScaleOverride
        self.lock.unlock()

        var scaledFonts: [String: NSFont] = [:]
        for (key, font) in fonts {
            scaledFonts[key] = self.scaledFont(font, scale: scale)
        }
        return scaledFonts
    }

    private func scaledFont(_ font: NSFont, scale: CGFloat) -> NSFont? {
        let scaledSize = font.pointSize * scale
        let descriptor = font.fontDescriptor.withSize(scaledSize)
        return NSFont(descriptor: descriptor, size: 0)
    }

    // MARK: 间距查询

    public func spacing(_ key: String) -> CGFloat {
        self.lock.lock()
        let value = self.spacingOverrides[key] ?? self.defaultSpacings[key]
        self.lock.unlock()
        return value ?? 0.0
    }

    public func spacing(_ key: String, category: String) -> CGFloat {
        let fullKey = "\(category).\(key)"
        return self.spacing(fullKey)
    }

    // MARK: 圆角查询

    public func cornerRadius(_ key: String) -> CGFloat {
        self.lock.lock()
        let value = self.defaultCornerRadii[key]
        self.lock.unlock()
        return value ?? 0.0
    }

    // MARK: 边框宽度查询

    public func borderWidth(_ key: String) -> CGFloat {
        self.lock.lock()
        let value = self.defaultBorderWidths[key]
        self.lock.unlock()
        return value ?? 0.0
    }

    // MARK: 切换皮肤时更新默认定义

    /// 切换皮肤时调用，用新皮肤的颜色定义替换默认定义
    public func applySkinColorDefaults(_ hexes: [String: String]) {
        self.lock.lock()
        self.defaultColorHexes = hexes
        self.colorCache.removeAll()
        self.lock.unlock()
    }

    // MARK: 视图注册（使用 Box 包装闭包，避免 NSMutableArray 桥接问题）

    public func registerView(_ view: NSView, forSkinUpdate handler: @escaping () -> Void) {
        self.lock.lock()

        if let existing = self.registeredViews.object(forKey: view) {
            existing.add(Box(handler))
        } else {
            let array = NSMutableArray()
            array.add(Box(handler))
            self.registeredViews.setObject(array, forKey: view)
        }

        self.lock.unlock()
    }

    public func unregisterView(_ view: NSView) {
        self.lock.lock()
        self.registeredViews.removeObject(forKey: view)
        self.lock.unlock()
    }

    public func refreshAllViews() {
        self.lock.lock()
        let viewsTable = self.registeredViews
        let currentId = self.currentSkinId
        self.lock.unlock()

        let allViews = viewsTable.keyEnumerator().allObjects.compactMap { $0 as? NSView }

        for view in allViews {
            if let handlers = viewsTable.object(forKey: view) {
                for handler in handlers {
                    if let box = handler as? Box<() -> Void> {
                        box.value()
                    }
                }
            }
        }

        self.logger.info("刷新所有已注册视图，当前皮肤: \(currentId)")
    }

    public func isViewRegistered(_ view: NSView) -> Bool {
        self.lock.lock()
        let result = self.registeredViews.object(forKey: view) != nil
        self.lock.unlock()
        return result
    }

    // MARK: 设置覆盖

    public func setAccentColorOverride(_ color: NSColor?) {
        self.lock.lock()
        self.accentColorOverride = color
        self.lock.unlock()
        self.logger.info("设置强调色覆盖: \(color?.description ?? "nil")")
    }

    public func setFontScale(_ scale: CGFloat) {
        self.lock.lock()
        self.fontScaleOverride = max(0.5, min(3.0, scale))
        self.lock.unlock()
        self.logger.info("设置字体缩放: \(scale)")
    }

    public func setSpacingOverride(_ value: CGFloat, forKey key: String) {
        self.lock.lock()
        self.spacingOverrides[key] = value
        self.lock.unlock()
        self.logger.info("设置间距覆盖 [\(key)]: \(value)")
    }

    public func resetSpacingOverrides() {
        self.lock.lock()
        self.spacingOverrides.removeAll()
        self.lock.unlock()
        self.logger.info("重置所有间距覆盖")
    }

    public func setUIColorBlindMode(_ mode: UIColorBlindMode) {
        self.lock.lock()
        self.colorBlindMode = mode
        self.lock.unlock()
        self.logger.info("设置色盲模式: \(mode.rawValue)")
    }

    public func setAnimationsEnabled(_ enabled: Bool) {
        self.lock.lock()
        self.animationsEnabled = enabled
        self.lock.unlock()
        self.logger.info("设置动画开关: \(enabled)")
    }

    // MARK: 获取当前皮肤ID

    public func getCurrentSkinId() -> String {
        self.lock.lock()
        let id = self.currentSkinId
        self.lock.unlock()
        return id
    }

    // MARK: 十六进制颜色解析

    public func parseColor(hex: String) -> NSColor? {
        var input = hex.trimmingCharacters(in: .whitespacesAndNewlines)

        // 处理 rgba(r,g,b,a) 格式
        let lowerInput = input.lowercased()
        if lowerInput.hasPrefix("rgba(") && input.hasSuffix(")") {
            let content = input.dropFirst(5).dropLast()
            let components = content.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count == 4 else {
                self.logger.warning("rgba 格式参数数量错误: \(hex)")
                return nil
            }
            guard let r = Double(components[0]),
                  let g = Double(components[1]),
                  let b = Double(components[2]),
                  let a = Double(components[3]) else {
                self.logger.warning("rgba 格式解析失败: \(hex)")
                return nil
            }
            guard r >= 0 && r <= 255, g >= 0 && g <= 255, b >= 0 && b <= 255, a >= 0 && a <= 1 else {
                self.logger.warning("rgba 格式数值范围错误: \(hex)")
                return nil
            }
            return NSColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: CGFloat(a))
        }

        // 处理十六进制格式
        if input.hasPrefix("#") {
            input.removeFirst()
        }

        let length = input.count
        guard length == 6 || length == 8 else {
            self.logger.warning("颜色十六进制格式无效: \(hex)")
            return nil
        }

        var rgba: UInt64 = 0
        guard Scanner(string: input).scanHexInt64(&rgba) else {
            self.logger.warning("颜色十六进制解析失败: \(hex)")
            return nil
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        if length == 6 {
            red = CGFloat((rgba & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgba & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgba & 0x0000FF) / 255.0
            alpha = 1.0
        } else {
            red = CGFloat((rgba & 0xFF000000) >> 24) / 255.0
            green = CGFloat((rgba & 0x00FF0000) >> 16) / 255.0
            blue = CGFloat((rgba & 0x0000FF00) >> 8) / 255.0
            alpha = CGFloat(rgba & 0x000000FF) / 255.0
        }

        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    // MARK: 清理缓存

    public func clearCache() {
        self.lock.lock()
        let count = self.skinCache.count
        // 保留默认皮肤
        let defaultSkin = self.skinCache["com.app.glass"]
        self.skinCache.removeAll()
        if let defaultSkin = defaultSkin {
            self.skinCache["com.app.glass"] = defaultSkin
        }
        self.cacheOrder.removeAll { $0 != "com.app.glass" }
        self.lock.unlock()
        self.logger.info("清理皮肤缓存，释放 \(count - 1) 个皮肤")
    }

    // MARK: 获取缓存状态

    public func getCacheStatus() -> (count: Int, maxSize: Int, cachedIds: [String]) {
        self.lock.lock()
        let count = self.skinCache.count
        let ids = Array(self.cacheOrder)
        self.lock.unlock()
        return (count: count, maxSize: self.maxCacheSize, cachedIds: ids)
    }
}

// MARK: - 测试函数

internal func test_Skin02() {
    print("\n=== Skin-02 皮肤引擎测试开始 ===\n")
    let engine = SkinEngine.shared
    _ = Logger(subsystem: "com.xianrenzhilu.test", category: "Skin02")

    // 测试 1: 默认皮肤 ID
    print("🧪 测试1: 验证默认皮肤ID")
    guard engine.getCurrentSkinId() == "com.app.glass" else {
        fatalError("❌ 测试1失败: 默认皮肤ID应为 com.app.glass，实际 \(engine.getCurrentSkinId())")
    }

    // 测试 2: 颜色查询
    print("🧪 测试2: 验证颜色查询")
    guard engine.color("windowBackground") != nil else {
        fatalError("❌ 测试2失败: windowBackground 颜色应存在")
    }
    guard engine.color("nonexistent") == nil else {
        fatalError("❌ 测试2失败: 不存在的颜色应返回 nil")
    }

    // 测试 3: 语义化颜色
    print("🧪 测试3: 验证语义化颜色")
    let _ = engine.color(for: .accent)

    // 测试 4: 所有颜色
    print("🧪 测试4: 验证所有颜色")
    let allColors = engine.getAllColors()
    guard allColors.count > 0 else {
        fatalError("❌ 测试4失败: 颜色列表不应为空")
    }

    // 测试 5: 字体查询
    print("🧪 测试5: 验证字体查询")
    guard engine.font("body") != nil else {
        fatalError("❌ 测试5失败: body 字体应存在")
    }
    guard engine.font("nonexistent") == nil else {
        fatalError("❌ 测试5失败: 不存在的字体应返回 nil")
    }

    // 测试 6: 字体缩放
    print("🧪 测试6: 验证字体缩放")
    engine.setFontScale(1.5)
    guard engine.font("body") != nil else {
        fatalError("❌ 测试6失败: 缩放后字体应存在")
    }
    engine.setFontScale(1.0)

    // 测试 7: 所有字体
    print("🧪 测试7: 验证所有字体")
    let allFonts = engine.getAllFonts()
    guard allFonts.count > 0 else {
        fatalError("❌ 测试7失败: 字体列表不应为空")
    }

    // 测试 8: 间距查询
    print("🧪 测试8: 验证间距查询")
    guard engine.spacing("controlPadding") == 8.0 else {
        fatalError("❌ 测试8失败: controlPadding 应为 8.0")
    }
    guard engine.spacing("nonexistent") == 0.0 else {
        fatalError("❌ 测试8失败: 不存在的间距应返回 0.0")
    }

    // 测试 9: 圆角查询
    print("🧪 测试9: 验证圆角查询")
    guard engine.cornerRadius("button") == 5.0 else {
        fatalError("❌ 测试9失败: button 圆角应为 5.0")
    }

    // 测试 10: 边框宽度查询
    print("🧪 测试10: 验证边框宽度")
    guard engine.borderWidth("normal") == 1.0 else {
        fatalError("❌ 测试10失败: normal 边框应为 1.0")
    }

    // 测试 11: 十六进制解析 6 位
    print("🧪 测试11: 验证16进制解析(6位)")
    guard engine.parseColor(hex: "#FF5733") != nil else {
        fatalError("❌ 测试11失败: 6位十六进制应解析成功")
    }

    // 测试 12: 十六进制解析 8 位
    print("🧪 测试12: 验证16进制解析(8位)")
    guard engine.parseColor(hex: "#FF5733CC") != nil else {
        fatalError("❌ 测试12失败: 8位十六进制应解析成功")
    }

    // 测试 13: rgba 解析
    print("🧪 测试13: 验证rgba解析")
    guard engine.parseColor(hex: "rgba(255, 128, 64, 0.5)") != nil else {
        fatalError("❌ 测试13失败: rgba 格式应解析成功")
    }
    guard engine.parseColor(hex: "rgba(0,0,0,0)") != nil else {
        fatalError("❌ 测试13失败: rgba 紧凑格式应解析成功")
    }

    // 测试 14: 无效颜色解析
    print("🧪 测试14: 验证无效颜色解析")
    guard engine.parseColor(hex: "GGGGGG") == nil else {
        fatalError("❌ 测试14失败: 无效十六进制应返回 nil")
    }
    guard engine.parseColor(hex: "rgba(300, 0, 0, 1)") == nil else {
        fatalError("❌ 测试14失败: 无效 rgba 应返回 nil")
    }
    guard engine.parseColor(hex: "rgba(255, 255)") == nil else {
        fatalError("❌ 测试14失败: rgba 参数不足应返回 nil")
    }

    // 测试 15: 视图注册
    print("🧪 测试15: 验证视图注册")
    let testView = NSView()
    engine.registerView(testView, forSkinUpdate: {})
    guard engine.isViewRegistered(testView) == true else {
        fatalError("❌ 测试15失败: 视图应已注册")
    }
    engine.unregisterView(testView)
    guard engine.isViewRegistered(testView) == false else {
        fatalError("❌ 测试15失败: 视图应已注销")
    }

    // 测试 16: 缓存状态
    print("🧪 测试16: 验证缓存状态")
    let cacheStatus = engine.getCacheStatus()
    guard cacheStatus.maxSize == 5 else {
        fatalError("❌ 测试16失败: 缓存上限应为 5")
    }

    // 测试 17: LRU 缓存与清理
    print("🧪 测试17: 验证LRU缓存清理")
    engine.clearCache()
    let emptyStatus = engine.getCacheStatus()
    guard emptyStatus.count <= 1 else {
        fatalError("❌ 测试17失败: 清理后缓存应只保留默认皮肤")
    }

    // 应用默认皮肤，确保缓存有数据
    print("🧪 测试17续: 应用皮肤后缓存验证")
    let _ = engine.applySkin(id: "com.app.glass", animated: false)
    let afterApply = engine.getCacheStatus()
    guard afterApply.count >= 1 else {
        fatalError("❌ 测试17续失败: 应用皮肤后缓存应至少包含默认皮肤")
    }
    guard afterApply.cachedIds.contains("com.app.glass") else {
        fatalError("❌ 测试17续失败: 缓存中应包含 com.app.glass")
    }

    // 测试 18: 动画开关
    print("🧪 测试18: 验证动画开关")
    engine.setAnimationsEnabled(true)
    engine.setAnimationsEnabled(false)
    let noAnimResult = engine.applySkin(id: "com.app.glass", animated: true)
    guard noAnimResult == true else {
        fatalError("❌ 测试18失败: 关闭动画后应用皮肤仍应成功")
    }
    engine.setAnimationsEnabled(true)

    // 测试 19: 色盲模式
    print("🧪 测试19: 验证色盲模式")
    engine.setUIColorBlindMode(.protanopia)
    guard engine.color("chartUp") != nil else {
        fatalError("❌ 测试19失败: 色盲模式下颜色应存在")
    }
    engine.setUIColorBlindMode(.deuteranopia)
    guard engine.color("chartUp") != nil else {
        fatalError("❌ 测试19失败: 绿色盲模式下颜色应存在")
    }
    engine.setUIColorBlindMode(.none)
    let normalColor = engine.color("chartUp")
    guard normalColor != nil else {
        fatalError("❌ 测试19失败: 正常模式下颜色应存在")
    }

    // 测试 20: 切换检查
    print("🧪 测试20: 验证切换检查")
    guard engine.canSwitchTo(id: "com.app.glass") == true else {
        fatalError("❌ 测试20失败: 默认皮肤应允许切换")
    }
    guard engine.canSwitchTo(id: "nonexistent.skin") == false else {
        fatalError("❌ 测试20失败: 不存在的皮肤不应允许切换")
    }

    // 测试 21: 应用皮肤
    print("🧪 测试21: 验证应用皮肤")
    guard engine.applySkin(id: "com.app.glass", animated: false) == true else {
        fatalError("❌ 测试21失败: 应用默认皮肤应成功")
    }
    guard engine.applySkin(id: "nonexistent.skin", animated: false) == false else {
        fatalError("❌ 测试21失败: 应用不存在的皮肤应失败")
    }

    // 测试 22: 强调色覆盖
    print("🧪 测试22: 验证强调色覆盖")
    let testAccent = NSColor.systemPurple
    engine.setAccentColorOverride(testAccent)
    guard engine.color("accent") != nil else {
        fatalError("❌ 测试22失败: 覆盖后强调色应存在")
    }
    engine.setAccentColorOverride(nil)

    // 测试 23: 间距覆盖
    print("🧪 测试23: 验证间距覆盖")
    engine.setSpacingOverride(32.0, forKey: "testOverride")
    guard engine.spacing("testOverride") == 32.0 else {
        fatalError("❌ 测试23失败: 覆盖间距应为 32.0")
    }
    engine.resetSpacingOverrides()
    guard engine.spacing("testOverride") == 0.0 else {
        fatalError("❌ 测试23失败: 重置后间距应为 0.0")
    }

    // 测试 24: 注册表验证
    print("🧪 测试24: 验证统一注册表")
    let registry = UIUnifiedRegistry.shared
    guard registry.getSkinProtocol(id: "com.app.glass") != nil else {
        fatalError("❌ 测试24失败: 统一注册表中应存在默认皮肤协议")
    }
    guard registry.getCurrentSkin()?.id == "com.app.glass" else {
        fatalError("❌ 测试24失败: 统一注册表当前皮肤应为 com.app.glass")
    }

    print("✅ Skin-02 全部测试通过")
}
