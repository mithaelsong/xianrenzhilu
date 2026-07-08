// MARK: - 皮肤专用子注册器
// 功能编号: UI-PF-00
// 职责: 作为皮肤领域门面，注册内置皮肤并把当前皮肤应用到主窗口。
// 架构铁律: 本文件不是独立权威注册表；最终必须写入 UIUnifiedRegistry。
// 公共类型来源: 只使用 UI-02_公共类型定义.swift 中的 UISkinInfo / UISkinProtocol 等公共类型。

import Foundation
import AppKit
import os

private let uiSkinBridgeLogger = Logger(subsystem: "com.xianrenzhilu.ui", category: "SkinRuntimeBridge")

@MainActor
public final class UISkinRuntimeBridge: NSObject {
    public static let shared = UISkinRuntimeBridge()

    private var registered = false
    private var skins: [String: UISkinProtocol] = [:]
    private weak var mainWindow: NSWindow?
    private weak var mainRootView: NSView?
    private var glassCanvas: NSScrollView?

    private override init() {
        super.init()
    }

    public func registerAllSkins() {
        uiSkinBridgeLogger.info("开始注册所有内置皮肤")
        guard !registered else { return }
        registered = true

        // 皮肤 Skin 只注册真正的 UI 基座/外观体系；浅色、深色、高对比度、色盲是 Theme，不再注册为皮肤。
        register(GlassSkin(), id: "com.app.glass", name: "玻璃皮肤", description: "Liquid Glass 玻璃外观", isDefault: true, tags: ["glass", "default", "skin"])
        _ = UIThemeSwitchManager.shared
    }

    private func register(_ skin: UISkinProtocol, id: String, name: String, description: String, isDefault: Bool = false, tags: [String] = []) {
        skins[id] = skin
        let info = UISkinInfo(
            id: id,
            name: name,
            version: skin.skinVersion,
            author: "仙人指路",
            description: description,
            isDefault: isDefault,
            isSystem: true,
            tags: tags,
            minEngineVersion: "2.0"
        )
        UIUnifiedRegistry.shared.registerSkin(info, protocol: skin)
        uiSkinBridgeLogger.info("注册皮肤 id=\(id, privacy: .public) name=\(name, privacy: .public) default=\(isDefault, privacy: .public)")
    }

    public func bindMainWindow(_ window: NSWindow, rootView: NSView) {
        uiSkinBridgeLogger.info("绑定主窗口 root=\(rootView.bounds.width, privacy: .public)x\(rootView.bounds.height, privacy: .public)")
        registerAllSkins()
        mainWindow = window
        mainRootView = rootView
        UIUnifiedRegistry.shared.registerWindow(id: "main", window: window, info: [
            "title": window.title,
            "module": "framework",
            "role": "main"
        ])

        // 玻璃皮肤是当前 UI 基座；浅色/深色/高对比度/色盲作为主题保存，不能把基础皮肤切走。
        UserDefaults.standard.set("com.app.glass", forKey: "com.xianrenzhilu.skin.currentSkinId")
        let savedTheme = UserDefaults.standard.string(forKey: "com.xianrenzhilu.theme.currentThemeId")
            ?? UserDefaults.standard.string(forKey: "com.xianrenzhilu.glass.visualSkinId")
            ?? "built-in-light"
        let themeId = Self.normalizeThemeId(savedTheme)
        UserDefaults.standard.set(themeId, forKey: "com.xianrenzhilu.theme.currentThemeId")
        UserDefaults.standard.set(themeId, forKey: "com.xianrenzhilu.glass.visualThemeId")
        applySkin(id: "com.app.glass")
    }

    @discardableResult
    public func applySkin(id: String) -> Bool {
        uiSkinBridgeLogger.info("请求应用皮肤 id=\(id, privacy: .public)")
        registerAllSkins()
        let resolvedWindow = mainWindow ?? NSApp.keyWindow ?? NSApp.mainWindow
        let resolvedRoot = mainRootView ?? resolvedWindow?.contentView
        guard let window = resolvedWindow, let rootView = resolvedRoot, let skin = skins[id] else {
            uiSkinBridgeLogger.error("应用皮肤失败：缺少 window/root/skin id=\(id, privacy: .public) hasWindow=\(resolvedWindow != nil, privacy: .public) hasRoot=\(resolvedRoot != nil, privacy: .public) hasSkin=\(self.skins[id] != nil, privacy: .public)")
            return false
        }

        guard id == "com.app.glass" else {
            uiSkinBridgeLogger.error("拒绝把主题当皮肤应用 id=\(id, privacy: .public)。请使用 applyTheme/applyVisualTheme。")
            return false
        }

        // 玻璃皮肤不再使用独立画布，内容容器在 GlassSkin.apply(to:) 中自动创建
        skin.apply(to: window)
        skin.apply(to: rootView)
        _ = UIUnifiedRegistry.shared.applySkin(id: id)
        UserDefaults.standard.set(id, forKey: "com.xianrenzhilu.skin.currentSkinId")
        uiSkinBridgeLogger.info("应用皮肤成功 id=\(id, privacy: .public)")
        return true
    }

    public func availableSkinIds() -> [String] {
        registerAllSkins()
        return ["com.app.glass"]
    }

    public func availableThemeIds() -> [String] {
        _ = UIThemeSwitchManager.shared
        return UIUnifiedRegistry.shared.getAllThemes().map { $0.id }
    }

    @discardableResult
    public func applyVisualTheme(id: String) -> Bool {
        let themeId = Self.normalizeThemeId(id)
        UserDefaults.standard.set("com.app.glass", forKey: "com.xianrenzhilu.skin.currentSkinId")
        UserDefaults.standard.set(themeId, forKey: "com.xianrenzhilu.theme.currentThemeId")
        UserDefaults.standard.set(themeId, forKey: "com.xianrenzhilu.glass.visualThemeId")
        UserDefaults.standard.set(themeId, forKey: "com.xianrenzhilu.glass.visualSkinId") // 兼容旧键
        return UIUnifiedRegistry.shared.applyTheme(id: themeId)
    }

    public static func normalizeThemeId(_ id: String) -> String {
        switch id {
        case "com.app.light", "built-in-light": return "built-in-light"
        case "com.app.dark", "built-in-dark": return "built-in-dark"
        case "com.app.highContrast", "com.app.high-contrast", "built-in-high-contrast", "built-in-highcontrast": return "built-in-highcontrast"
        case "com.app.protanopia", "built-in-protanopia": return "built-in-protanopia"
        case "com.app.deuteranopia", "built-in-deuteranopia": return "built-in-deuteranopia"
        case "system": return "system"
        default: return id
        }
    }

    @objc public func selectSkinFromButton(_ sender: NSButton) {
        guard let skinId = sender.identifier?.rawValue else { return }
        _ = applySkin(id: skinId)
    }
}
