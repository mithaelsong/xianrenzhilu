// MARK: - 绿色盲主题兼容适配器
// 功能编号: Skin-07
// 版本: 1.0.0
// 职责: 历史文件：绿色盲是无障碍主题，不是独立皮肤；当前不注册为 Skin。

import Foundation
import AppKit
// 架构说明：主题不是皮肤；本文件不再参与 UISkinRuntimeBridge 皮肤注册。
import OSLog
// 已改用 UI-02_公共类型定义.swift 中的公共类型：SkinEngine

// MARK: - 绿色盲主题实现

public final class DeuteranopiaSkin: SkinProtocol {
    public let skinId = "com.app.deuteranopia"
    public let skinName = "绿色盲模式"
    public let skinVersion = "1.0.0"

    public init() {}

    /// 颜色定义字典，键为语义名称，值为十六进制或 rgba 字符串
    /// 绿色盲模式：绿色→蓝紫色重映射
    private let colors: [String: String] = [
        "windowBackground": "#FFFFFF",
        "textPrimary": "#000000",
        "textSecondary": "rgba(0,0,0,0.5)",
        "accent": "#007AFF",
        "chartUp": "#FF3B30",
        "chartDown": "#8A2BE2",
    ]

    /// 获取指定语义的颜色（委托 SkinEngine 实时解析）
    private func color(for key: String) -> NSColor? {
        guard let colorString = colors[key] else { return nil }
        guard let color = SkinEngine.shared.parseColor(hex: colorString) else {
            os_log("⚠️ Skin-07 绿色盲: 颜色解析失败 key=%@ hex=%@", type: .error, key, colorString)
            return nil
        }
        return color
    }

    /// 应用皮肤到窗口
    public func apply(to window: NSWindow) {
        guard let bgColor = color(for: "windowBackground") else {
            os_log("⚠️ Skin-07 绿色盲: apply(to:) 窗口背景色解析失败", type: .error)
            return
        }
        window.backgroundColor = bgColor
    }

    /// 应用皮肤到视图
    public func apply(to view: NSView) {
        guard let bgColor = color(for: "windowBackground") else {
            os_log("⚠️ Skin-07 绿色盲: apply(to:) 视图背景色解析失败", type: .error)
            return
        }
        view.wantsLayer = true
        view.layer?.backgroundColor = bgColor.cgColor
    }

    /// 是否支持该皮肤
    public func isSupported() -> Bool {
        return true
    }
}

// MARK: - 测试

internal func test_Skin07() {
    print("\n=== Skin-07 绿色盲主题测试开始 ===\n")

    let skin = DeuteranopiaSkin()

    // 测试 1: 验证皮肤ID
    print("🧪 测试1: 验证皮肤ID")
    guard skin.skinId == "com.app.deuteranopia" else {
        fatalError("❌ 测试1失败: 皮肤ID应为 com.app.deuteranopia，实际 \(skin.skinId)")
    }

    // 测试 2: 验证皮肤名称
    print("🧪 测试2: 验证皮肤名称")
    guard skin.skinName == "绿色盲模式" else {
        fatalError("❌ 测试2失败: 皮肤名称应为 绿色盲模式，实际 \(skin.skinName)")
    }

    // 测试 3: 验证皮肤版本
    print("🧪 测试3: 验证皮肤版本")
    guard skin.skinVersion == "1.0.0" else {
        fatalError("❌ 测试3失败: 皮肤版本应为 1.0.0，实际 \(skin.skinVersion)")
    }

    // 测试 4: 验证是否支持
    print("🧪 测试4: 验证 isSupported")
    guard skin.isSupported() == true else {
        fatalError("❌ 测试4失败: isSupported 应该返回 true")
    }

    // 测试 5: 验证颜色解析（委托 SkinEngine）
    print("🧪 测试5: 验证颜色解析")
    guard SkinEngine.shared.parseColor(hex: "#FF3B30") != nil else {
        fatalError("❌ 测试5失败: #FF3B30 应解析成功")
    }
    guard SkinEngine.shared.parseColor(hex: "#8A2BE2") != nil else {
        fatalError("❌ 测试5失败: #8A2BE2 应解析成功")
    }

    print("✅ Skin-07 全部测试通过")
}
