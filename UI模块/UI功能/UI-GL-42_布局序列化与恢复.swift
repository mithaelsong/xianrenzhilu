// 功能33B: 布局序列化与恢复
// 对应: 将整个UI状态序列化为JSON,支持跨设备同步
// 优先级: P1

import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "33B_布局序列化与恢复")

// 类型定义已迁移至 UI-GL-42_types.swift
// UILayoutWindowStateModel, UIThemeSwitchManager, UITheme, UIAppStateManager, UIStateSnapshot, UISerializationManager

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能33B:布局序列化与恢复 - 单元测试
func test_uiSerialization() {
    let manager = UISerializationManager.shared
    var allPassed = true

    logger.info("测试1: 快照默认值")
    let snap = manager.captureSnapshot()
    if snap.version != "2.0" {
        logger.error("❌ 测试1失败: 版本号不正确")
        allPassed = false
    } else {
        logger.info("✅ 测试1通过: 默认快照正常")
    }

    logger.info("测试2: 保存并加载")
    manager.saveSnapshot(snap)
    let loaded = manager.loadSnapshot()
    if loaded == nil {
        logger.error("❌ 测试2失败: 加载应为非nil")
        allPassed = false
    } else {
        logger.info("✅ 测试2通过: 保存/加载正常")
    }

    if allPassed {
        logger.info("=== 全部序列化测试通过 ✅ ===")
    } else {
        logger.error("=== 部分序列化测试失败 ❌ ===")
    }
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UISerializationManager
public final class UISerializationManager : @unchecked Sendable {

    public static let shared = UISerializationManager()

    private let defaults: UserDefaults
    private let saveKey = "com.xianrenzhilu.uiState"

    private init() {
        self.defaults = UserDefaults.standard
    }

    deinit {
        // 静默释放，不依赖外部 logger
    }

    /// 快照当前UI状态
    public func captureSnapshot() -> UIStateSnapshot {
        var snapshot = UIStateSnapshot()
        snapshot.symbol = UIAppStateManager.shared.currentState.symbol
        snapshot.period = UIAppStateManager.shared.currentState.period
        // 主题模式已移除，使用系统当前外观
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        snapshot.themeMode = isDark ? "dark" : "light"
        return snapshot
    }

    /// 保存到UserDefaults
    public func saveSnapshot(_ snapshot: UIStateSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: saveKey)
    }

    /// 从UserDefaults加载
    public func loadSnapshot() -> UIStateSnapshot? {
        guard let data = defaults.data(forKey: saveKey) else {
            return nil
        }
        guard let snapshot = try? JSONDecoder().decode(UIStateSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    // MARK: - 业务模块容器 frame 保存/恢复
    // UIContainerView 是 UI 模块的通用子窗口容器；这里把它接入已有 UIStateSnapshot.windowStates。
    // 业务模块只需要提供稳定 identifier，不需要自己实现位置持久化。
    public func saveContainerFrame(identifier: String, frame: NSRect) {
        guard !identifier.isEmpty,
              frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.width.isFinite, frame.height.isFinite,
              frame.width > 0, frame.height > 0 else { return }

        var snapshot = loadSnapshot() ?? UIStateSnapshot()
        snapshot.timestamp = Date()
        snapshot.windowStates[identifier] = UILayoutWindowStateModel(
            frame: NSStringFromRect(frame),
            isVisible: true,
            isFullscreen: false
        )
        saveSnapshot(snapshot)
    }

    public func restoredContainerFrame(identifier: String, fallback: NSRect) -> NSRect {
        guard !identifier.isEmpty,
              let raw = loadSnapshot()?.windowStates[identifier]?.frame,
              !raw.isEmpty else { return fallback }
        let rect = NSRectFromString(raw)
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite,
              rect.width > 40, rect.height > 40 else { return fallback }
        return rect
    }

    public func saveMainWindowFrame(_ frame: NSRect) {
        saveContainerFrame(identifier: "UI_MainWindow", frame: frame)
    }

    public func restoredMainWindowFrame(fallback: NSRect) -> NSRect {
        restoredContainerFrame(identifier: "UI_MainWindow", fallback: fallback)
    }

    public func saveSplitRatio(identifier: String, dividerIndex: Int, ratio: CGFloat) {
        guard !identifier.isEmpty, ratio.isFinite else { return }
        var snapshot = loadSnapshot() ?? UIStateSnapshot()
        snapshot.timestamp = Date()
        snapshot.splitViewRatios["\(identifier)#\(dividerIndex)"] = min(max(ratio, 0.02), 0.98)
        saveSnapshot(snapshot)
    }

    public func restoredSplitRatio(identifier: String, dividerIndex: Int) -> CGFloat? {
        guard !identifier.isEmpty else { return nil }
        return loadSnapshot()?.splitViewRatios["\(identifier)#\(dividerIndex)"]
    }

    /// 导出到文件
    public func exportToFile(_ snapshot: UIStateSnapshot) -> URL? {
        guard let tempDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = tempDir.appendingPathComponent("ui_state_\(Int(Date().timeIntervalSince1970)).json")
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return nil
        }
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    /// 从文件导入
    public func importFromFile(url: URL) -> UIStateSnapshot? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        guard let snapshot = try? JSONDecoder().decode(UIStateSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutWindowStateModel
// MARK: - UI-GL-42 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-42_types.swift
// 版本: 2.0
// MARK: - 占位类型
/// 窗口状态模型占位定义，实际由窗口模块提供
public struct UILayoutWindowStateModel: Codable, Equatable {
    public var frame: String = ""
    public var isVisible: Bool = true
    public var isFullscreen: Bool = false
}

// MARK: - 迁回自 UI-02：struct UITheme
// MARK: - 布局管理器
// 已迁回 UI-GL-41_布局管理器.swift：class UILayoutManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-42 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-42_types.swift
// 版本: 2.0
public struct UITheme: Codable {
    public let name: String
    public let identifier: String
}

// MARK: - 迁回自 UI-02：struct UIStateSnapshot
// MARK: - 完整UI状态
/// 可完整序列化的UI状态
public struct UIStateSnapshot: Codable {
    public var version: String
    public var timestamp: Date
    public var themeMode: String
    public var symbol: String
    public var period: String
    public var currentWorkspace: String
    public var windowStates: [String: UILayoutWindowStateModel]
    public var splitViewRatios: [String: CGFloat]
    public var toolbarIdentifiers: [String]
    public var activeTabIDs: [String]

    public init() {
        self.version = "2.0"
        self.timestamp = Date()
        self.themeMode = "跟随系统"
        self.symbol = "BTC/USDT"
        self.period = "1h"
        self.currentWorkspace = "交易模式"
        self.windowStates = [:]
        self.splitViewRatios = [:]
        self.toolbarIdentifiers = []
        self.activeTabIDs = []
    }
}
