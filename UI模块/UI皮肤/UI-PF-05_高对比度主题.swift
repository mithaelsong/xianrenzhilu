// MARK: - 高对比度主题兼容适配器
// 功能编号: Skin-05
// 版本: 1.0.0
// 职责: 历史文件：高对比度是无障碍主题，不是独立皮肤；当前不注册为 Skin。

import Foundation
import AppKit
// 架构说明：主题不是皮肤；本文件不再参与 UISkinRuntimeBridge 皮肤注册。
import OSLog
// 已改用 UI-02_公共类型定义.swift 中的公共类型：SkinEngine

// MARK: - 高对比度主题实现

public final class HighContrastSkin: SkinProtocol {
    public let skinId = "com.app.high-contrast"
    public let skinName = "高对比度"
    public let skinVersion = "1.0.0"

    public init() {}

    /// 颜色定义字典，键为语义名称，值为十六进制字符串
    private let colors: [String: String] = [
        "windowBackground": "#000000",
        "textPrimary": "#FFFF00",
        "textSecondary": "#FFFFFF",
        "separator": "#FFFFFF",
        "accent": "#00FFFF",
    ]

    /// 字体定义字典，键为语义名称，值为字体配置元组
    private let fonts: [String: (name: String, size: CGFloat, weight: NSFont.Weight)] = [
        "body": ("SF Pro Text", 15, .bold),
        "title": ("SF Pro Display", 19, .bold),
        "code": ("SF Mono", 13, .regular),
        "small": ("SF Pro Text", 13, .regular),
        "button": ("SF Pro Text", 15, .bold),
    ]

    /// 间距定义字典，键为语义名称，值为间距数值
    private let spacings: [String: CGFloat] = [
        "controlPadding": 12.0,
        "windowPadding": 24.0,
        "elementSpacing": 8.0,
        "sectionSpacing": 16.0,
        "groupSpacing": 28.0,
    ]

    /// 圆角定义字典，键为语义名称，值为圆角数值
    private let cornerRadii: [String: CGFloat] = [
        "button": 8.0,
        "panel": 16.0,
        "window": 12.0,
        "card": 10.0,
        "input": 8.0,
    ]

    /// 获取指定语义的颜色（委托 SkinEngine 实时解析）
    private func color(for key: String) -> NSColor? {
        guard let colorString = colors[key] else {
            return nil
        }
        guard let color = SkinEngine.shared.parseColor(hex: colorString) else {
            os_log("⚠️ Skin-05 高对比度: 颜色解析失败 key=%@ hex=%@", type: .error, key, colorString)
            return nil
        }
        return color
    }

    /// 获取指定语义的字体（使用系统字体 + 字重，避免字体名找不到导致 weight 丢失）
    public func font(for key: String) -> NSFont? {
        guard let config = fonts[key] else {
            return nil
        }
        return NSFont.systemFont(ofSize: config.size, weight: config.weight)
    }

    /// 获取指定语义的间距
    public func spacing(for key: String) -> CGFloat {
        return spacings[key] ?? 0.0
    }

    /// 获取指定语义的圆角
    public func cornerRadius(for key: String) -> CGFloat {
        return cornerRadii[key] ?? 0.0
    }

    /// 应用到窗口：设置窗口背景色
    public func apply(to window: NSWindow) {
        guard let bgColor = color(for: "windowBackground") else {
            os_log("⚠️ Skin-05 高对比度: apply(to:) 窗口背景色解析失败", type: .error)
            return
        }
        window.backgroundColor = bgColor
    }

    /// 应用到视图：设置视图 layer 背景色
    public func apply(to view: NSView) {
        guard let bgColor = color(for: "windowBackground") else {
            os_log("⚠️ Skin-05 高对比度: apply(to:) 视图背景色解析失败", type: .error)
            return
        }
        view.wantsLayer = true
        view.layer?.backgroundColor = bgColor.cgColor
    }

    /// 是否支持当前系统
    public func isSupported() -> Bool {
        return true
    }
}

// MARK: - 测试

internal func test_Skin05() {
    print("\n=== Skin-05 高对比度主题测试开始 ===\n")
    let skin = HighContrastSkin()

    // 测试 1: 验证皮肤ID
    print("🧪 测试1: 验证皮肤ID")
    guard skin.skinId == "com.app.high-contrast" else {
        fatalError("❌ 测试1失败: 皮肤ID应为 com.app.high-contrast，实际 \(skin.skinId)")
    }

    // 测试 2: 验证皮肤名称
    print("🧪 测试2: 验证皮肤名称")
    guard skin.skinName == "高对比度" else {
        fatalError("❌ 测试2失败: 皮肤名称应为 高对比度，实际 \(skin.skinName)")
    }

    // 测试 3: 验证皮肤版本
    print("🧪 测试3: 验证皮肤版本")
    guard skin.skinVersion == "1.0.0" else {
        fatalError("❌ 测试3失败: 皮肤版本应为 1.0.0，实际 \(skin.skinVersion)")
    }

    // 测试 4: 验证支持状态
    print("🧪 测试4: 验证 isSupported")
    guard skin.isSupported() else {
        fatalError("❌ 测试4失败: isSupported 应为 true")
    }

    // 测试 5: 验证字体定义
    print("🧪 测试5: 验证字体定义")
    let bodyFont = skin.font(for: "body")
    guard bodyFont != nil else {
        fatalError("❌ 测试5失败: body 字体应返回系统字体")
    }
    guard bodyFont?.fontDescriptor.symbolicTraits.contains(NSFontDescriptor.SymbolicTraits.bold) == true else {
        fatalError("❌ 测试5失败: body 字体应为加粗")
    }

    // 测试 6: 验证间距定义
    print("🧪 测试6: 验证间距定义")
    guard skin.spacing(for: "controlPadding") == 12.0 else {
        fatalError("❌ 测试6失败: controlPadding 应为 12.0")
    }

    // 测试 7: 验证圆角定义
    print("🧪 测试7: 验证圆角定义")
    guard skin.cornerRadius(for: "button") == 8.0 else {
        fatalError("❌ 测试7失败: button 圆角应为 8.0")
    }

    print("✅ Skin-05 全部测试通过")
}
