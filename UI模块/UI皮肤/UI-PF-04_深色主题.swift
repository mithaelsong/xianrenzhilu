// MARK: - 深色主题兼容适配器
// 功能编号: Skin-04
// 版本: 1.0.0
// 职责: 历史文件：深色是主题，不是独立皮肤；当前不注册为 Skin，仅保留兼容/颜色实现。

import Foundation
import AppKit
// 架构说明：主题不是皮肤；本文件不再参与 UISkinRuntimeBridge 皮肤注册。
import OSLog
// 已改用 UI-02_公共类型定义.swift 中的公共类型：SkinEngine

// MARK: - 深色主题实现

public final class DarkSkin: SkinProtocol {
    public let skinId = "com.app.dark"
    public let skinName = "深色模式"
    public let skinVersion = "1.0.0"

    public init() {}

    /// 颜色定义字典，键为语义名称，值为十六进制或 rgba 字符串
    private let colors: [String: String] = [
        "windowBackground": "#1E1E1E",
        "textPrimary": "#FFFFFF",
        "textSecondary": "rgba(255,255,255,0.7)",
        "separator": "rgba(255,255,255,0.1)",
        "accent": "#0A84FF",
    ]

    /// 获取指定语义的颜色（委托 SkinEngine 实时解析）
    private func color(for key: String) -> NSColor? {
        guard let colorString = colors[key] else {
            return nil
        }
        guard let color = SkinEngine.shared.parseColor(hex: colorString) else {
            os_log("⚠️ Skin-04 深色模式: 颜色解析失败 key=%@ hex=%@", type: .error, key, colorString)
            return nil
        }
        return color
    }

    /// 应用到窗口：设置窗口背景色
    public func apply(to window: NSWindow) {
        guard let bgColor = color(for: "windowBackground") else {
            os_log("⚠️ Skin-04 深色模式: apply(to:) 窗口背景色解析失败", type: .error)
            return
        }
        window.backgroundColor = bgColor
    }

    /// 应用到视图：设置视图 layer 背景色
    public func apply(to view: NSView) {
        guard let bgColor = color(for: "windowBackground") else {
            os_log("⚠️ Skin-04 深色模式: apply(to:) 视图背景色解析失败", type: .error)
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

internal func test_Skin04() {
    print("\n=== Skin-04 深色主题测试开始 ===\n")
    let skin = DarkSkin()

    // 测试 1: 验证皮肤ID
    print("🧪 测试1: 验证皮肤ID")
    guard skin.skinId == "com.app.dark" else {
        fatalError("❌ 测试1失败: 皮肤ID应为 com.app.dark，实际 \(skin.skinId)")
    }

    // 测试 2: 验证皮肤名称
    print("🧪 测试2: 验证皮肤名称")
    guard skin.skinName == "深色模式" else {
        fatalError("❌ 测试2失败: 皮肤名称应为 深色模式，实际 \(skin.skinName)")
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

    // 测试 5: 验证颜色解析（委托 SkinEngine）
    print("🧪 测试5: 验证颜色解析")
    guard SkinEngine.shared.parseColor(hex: "#1E1E1E") != nil else {
        fatalError("❌ 测试5失败: #1E1E1E 应解析成功")
    }
    guard SkinEngine.shared.parseColor(hex: "rgba(255,255,255,0.7)") != nil else {
        fatalError("❌ 测试5失败: rgba(255,255,255,0.7) 应解析成功")
    }

    print("✅ Skin-04 全部测试通过")
}
