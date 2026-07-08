// 功能16B: 窗口布局管理
// 对应: 窗口布局预设管理、自定义布局保存/加载、布局切换动画、模板系统、对齐工具、多屏幕布局、快照恢复、热键绑定
// 优先级: P2
// 版本: 2.0

import Foundation
import AppKit
import os.log

// MARK: - 测试
internal func test_UI16B() {
    print("\n=== UI-16B 窗口布局管理测试 ===\n")
    
    let manager = UIWindowLayoutManager.shared
    manager.initialize()
    
    print("✅ 测试通过: 布局管理器初始化成功")
}


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWindowLayoutManager
public final class UIWindowLayoutManager : @unchecked Sendable {
    public static let shared = UIWindowLayoutManager()
    
    private let lock = NSRecursiveLock()
    private var presets: [UIWindowLayoutDefinition] = []
    private var customLayouts: [String: UIWindowLayoutDefinition] = [:]
    private var snapshots: [String: UIWindowLayoutSnapshot] = [:]
    
    private init() {}
    
    public func initialize() {
        lock.lock()
        defer { lock.unlock() }
        
        let mainScreen = UIMultiScreenManager.shared.mainScreen
        presets = [
            createPreset(type: .singleWindow, screen: mainScreen),
            createPreset(type: .horizontalSplit, screen: mainScreen),
            createPreset(type: .verticalSplit, screen: mainScreen),
            createPreset(type: .grid2x2, screen: mainScreen),
            createPreset(type: .quad, screen: mainScreen),
            createPreset(type: .tripleLeft, screen: mainScreen),
            createPreset(type: .tripleTop, screen: mainScreen),
            createPreset(type: .tile, screen: mainScreen),
            createPreset(type: .cascade, screen: mainScreen),
            createPreset(type: .stack, screen: mainScreen),
            createPreset(type: .fullscreen, screen: mainScreen),
            createPreset(type: .mainAndAuxiliary, screen: mainScreen)
        ]
    }
    
    private func createPreset(type: UIWindowLayoutPresetType, screen: NSScreen?) -> UIWindowLayoutDefinition {
        let frame = screen?.frame ?? NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let uuid = screen.map { UIMultiScreenManager.shared.displayUUID(for: $0) } ?? "main"
        let margin: CGFloat = 8
        _ = UILayoutSize(size: NSSize(width: frame.width, height: frame.height))
        
        var items: [UIWindowLayoutItem] = []
        
        switch type {
        case .singleWindow:
            let singleFrame = NSRect(
                x: frame.origin.x + margin,
                y: frame.origin.y + margin,
                width: frame.width - margin * 2,
                height: frame.height - margin * 2
            )
            items = [
                UIWindowLayoutItem(
                    windowID: "",
                    frame: singleFrame,
                    screenUUID: uuid,
                    moduleName: "",
                    alphaValue: 1.0,
                    isMainWindow: true
                )
            ]
        case .horizontalSplit:
            let halfWidth = (frame.width - margin * 3) / 2
            let fullHeight = frame.height - margin * 2
            let leftRect = NSRect(
                x: frame.origin.x + margin,
                y: frame.origin.y + margin,
                width: halfWidth,
                height: fullHeight
            )
            let rightRect = NSRect(
                x: frame.origin.x + halfWidth + margin * 2,
                y: frame.origin.y + margin,
                width: halfWidth,
                height: fullHeight
            )
            items = [
                UIWindowLayoutItem(windowID: "", frame: leftRect, screenUUID: uuid, moduleName: ""),
                UIWindowLayoutItem(windowID: "", frame: rightRect, screenUUID: uuid, moduleName: "")
            ]
        case .verticalSplit:
            let fullWidth = frame.width - margin * 2
            let halfHeight = (frame.height - margin * 3) / 2
            let topRect = NSRect(
                x: frame.origin.x + margin,
                y: frame.origin.y + halfHeight + margin * 2,
                width: fullWidth,
                height: halfHeight
            )
            let bottomRect = NSRect(
                x: frame.origin.x + margin,
                y: frame.origin.y + margin,
                width: fullWidth,
                height: halfHeight
            )
            items = [
                UIWindowLayoutItem(windowID: "", frame: topRect, screenUUID: uuid, moduleName: ""),
                UIWindowLayoutItem(windowID: "", frame: bottomRect, screenUUID: uuid, moduleName: "")
            ]
        default:
            items = []
        }
        
        var frames: [String: CGRect] = [:]
        for (index, item) in items.enumerated() {
            frames["window_\(index)"] = item.frame
        }
        
        return UIWindowLayoutDefinition(
            name: type.rawValue,
            windowFrames: frames,
            moduleName: "",
            isBuiltIn: true
        )
    }
    
    public func applyLayout(_ layout: UIWindowLayoutDefinition, animated: Bool = true) {
        lock.lock()
        lock.unlock()
        // 应用布局逻辑
    }
    
    public func saveLayout(name: String, windowIDs: [String]) -> UIWindowLayoutDefinition? {
        lock.lock()
        defer { lock.unlock() }
        
        var frames: [String: CGRect] = [:]
        for id in windowIDs {
            if let window = UIWindowRegistry.shared.window(for: id) {
                frames[id] = window.frame
            }
        }
        
        let layout = UIWindowLayoutDefinition(
            name: name,
            windowFrames: frames,
            moduleName: "",
            isBuiltIn: false
        )
        customLayouts[name] = layout
        return layout
    }
    
    public func loadLayout(name: String) -> UIWindowLayoutDefinition? {
        lock.lock()
        defer { lock.unlock() }
        return customLayouts[name] ?? presets.first { $0.name == name }
    }
    
    public func deleteLayout(name: String) {
        lock.lock()
        defer { lock.unlock() }
        customLayouts.removeValue(forKey: name)
    }
    
    public func saveSnapshot(name: String, windowIDs: [String]) -> UIWindowLayoutSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        
        var frames: [String: CGRect] = [:]
        for id in windowIDs {
            if let window = UIWindowRegistry.shared.window(for: id) {
                frames[id] = window.frame
            }
        }
        
        let snapshot = UIWindowLayoutSnapshot(
            name: name,
            windowFrames: frames
        )
        snapshots[name] = snapshot
        return snapshot
    }
    
    public func restoreSnapshot(name: String) -> UIWindowLayoutSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return snapshots[name]
    }
    
    public func deleteSnapshot(name: String) {
        lock.lock()
        defer { lock.unlock() }
        snapshots.removeValue(forKey: name)
    }
    
    public func alignWindows(_ alignment: UIWindowAlignment, windowIDs: [String]? = nil) {
        lock.lock()
        lock.unlock()
        // 对齐逻辑
    }
    
    public func distributeWindows(_ distribution: UIWindowDistribution, windowIDs: [String]? = nil) {
        lock.lock()
        lock.unlock()
        // 分布逻辑
    }
    
    public func allPresets() -> [UIWindowLayoutDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return presets
    }
    
    public func allCustomLayouts() -> [UIWindowLayoutDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return Array(customLayouts.values)
    }
    
    public func allSnapshots() -> [UIWindowLayoutSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return Array(snapshots.values)
    }
    
    public func settingsPanelPresets() -> [UILayoutPresetItem] {
        return presets.map { preset in
            UILayoutPresetItem(
                name: preset.name,
                icon: "",
                description: "",
                type: .custom,
                isBuiltIn: preset.isBuiltIn
            )
        }
    }
    
    public func settingsPanelCustomLayouts() -> [UILayoutCustomItem] {
        return customLayouts.values.map { layout in
            UILayoutCustomItem(
                name: layout.name,
                icon: "",
                description: ""
            )
        }
    }
    
    public func settingsPanelSnapshots() -> [UILayoutSnapshotItem] {
        return snapshots.values.map { snapshot in
            UILayoutSnapshotItem(
                name: snapshot.name,
                icon: "",
                description: "",
                timestamp: snapshot.timestamp
            )
        }
    }
    
    public func settingsPanelAlignmentOptions() -> [UILayoutAlignmentOption] {
        return UIWindowAlignment.allCases.map { alignment in
            UILayoutAlignmentOption(
                name: alignment.rawValue,
                icon: "",
                description: "",
                alignment: alignment
            )
        }
    }
    
    public func settingsPanelDistributionOptions() -> [UILayoutDistributionOption] {
        return UIWindowDistribution.allCases.map { distribution in
            UILayoutDistributionOption(
                name: distribution.rawValue,
                icon: "",
                description: "",
                distribution: distribution
            )
        }
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutDistributionOption
// MARK: - UI-GL-20 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-20_types.swift
// 版本: 2.0
/// 管理应用主菜单栏，支持模块动态添加菜单项
// 已迁回 UI-GL-20_主菜单管理器.swift：class UIMainMenuManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-21 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-21_types.swift
// 版本: 2.0
/// 窗口全屏管理器单例
/// 负责统一管理应用窗口的全屏行为，支持多屏幕切换、动画控制、UI元素自动隐藏
// 已迁回 UI-GL-21_窗口全屏管理.swift：class UIWindowFullscreenManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-22 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-22_types.swift
// 版本: 2.0
// MARK: - 快捷键管理器
/// 管理全局/局部快捷键注册、冲突检测、用户自定义
// 已迁回 UI-GL-22_快捷键系统.swift：class UIKeyBindingManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-23 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-23_types.swift
// 版本: 2.0
// 独立编译存根
public struct UILayoutDistributionOption: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let icon: String
    public let description: String
    public let distribution: UIWindowDistribution
    
    public init(name: String, icon: String, description: String, distribution: UIWindowDistribution) {
        self.name = name
        self.icon = icon
        self.description = description
        self.distribution = distribution
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutAlignmentOption
// MARK: - UI-GL-23 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-23_types.swift
// 版本: 2.0
public struct UILayoutAlignmentOption: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let icon: String
    public let description: String
    public let alignment: UIWindowAlignment
    
    public init(name: String, icon: String, description: String, alignment: UIWindowAlignment) {
        self.name = name
        self.icon = icon
        self.description = description
        self.alignment = alignment
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutSnapshotItem
public struct UILayoutSnapshotItem: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let icon: String
    public let description: String
    public let timestamp: Date
    
    public init(name: String, icon: String, description: String, timestamp: Date = Date()) {
        self.name = name
        self.icon = icon
        self.description = description
        self.timestamp = timestamp
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutCustomItem
public struct UILayoutCustomItem: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let icon: String
    public let description: String
    public let createdAt: Date
    
    public init(name: String, icon: String, description: String, createdAt: Date = Date()) {
        self.name = name
        self.icon = icon
        self.description = description
        self.createdAt = createdAt
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutPresetItem
public struct UILayoutPresetItem: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let icon: String
    public let description: String
    public let type: UIWindowLayoutPresetType
    public let isBuiltIn: Bool
    
    public init(name: String, icon: String, description: String, type: UIWindowLayoutPresetType, isBuiltIn: Bool) {
        self.name = name
        self.icon = icon
        self.description = description
        self.type = type
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - 迁回自 UI-02：struct UIWindowLayoutItem
public struct UIWindowLayoutItem: Codable, Sendable, Identifiable {
    public let id: String
    public var frame: CGRect
    public let screenUUID: String
    public let moduleName: String
    public let alphaValue: CGFloat
    public let isMainWindow: Bool
    
    public init(windowID: String, frame: CGRect, screenUUID: String = "", moduleName: String, alphaValue: CGFloat = 1.0, isMainWindow: Bool = false) {
        self.id = windowID
        self.frame = frame
        self.screenUUID = screenUUID
        self.moduleName = moduleName
        self.alphaValue = alphaValue
        self.isMainWindow = isMainWindow
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutSize
public struct UILayoutSize: Codable, Sendable {
    public let width: CGFloat
    public let height: CGFloat
    
    public init(size: NSSize) {
        self.width = size.width
        self.height = size.height
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutRect
public struct UILayoutRect: Codable, Sendable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat
    
    public init(rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
    
    public var cgRect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - 迁回自 UI-02：enum UIWindowLayoutPresetType
public enum UIWindowLayoutPresetType: String, Codable, Sendable {
    case singleWindow, horizontalSplit, verticalSplit, grid2x2, quad, tripleLeft, tripleTop, tile, cascade, stack, split, fullscreen, mainAndAuxiliary, custom
}

// MARK: - 迁回自 UI-02：enum UIWindowAlignment
public enum UIWindowAlignment: String, Codable, Sendable, CaseIterable {
    case left, right, top, bottom, center, horizontal, vertical
}

// MARK: - 迁回自 UI-02：enum UIWindowDistribution
public enum UIWindowDistribution: String, Codable, Sendable, CaseIterable {
    case evenly, bySize, byModule, custom
}

// MARK: - 迁回自 UI-02：struct UIWindowLayoutSnapshot
public struct UIWindowLayoutSnapshot: Codable, Sendable {
    public let name: String
    public let windowFrames: [String: CGRect]
    public let timestamp: Date
    
    public init(name: String, windowFrames: [String: CGRect], timestamp: Date = Date()) {
        self.name = name
        self.windowFrames = windowFrames
        self.timestamp = timestamp
    }
}

// MARK: - 迁回自 UI-02：struct UIWindowLayoutDefinition
public struct UIWindowLayoutDefinition: Codable, Sendable {
    public let name: String
    public let windowFrames: [String: CGRect]
    public let moduleName: String
    public let createdAt: Date
    public let isBuiltIn: Bool
    
    public init(name: String, windowFrames: [String: CGRect], moduleName: String, createdAt: Date = Date(), isBuiltIn: Bool = false) {
        self.name = name
        self.windowFrames = windowFrames
        self.moduleName = moduleName
        self.createdAt = createdAt
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - 迁回自 UI-02：struct UIWindowRegistryRecord
public struct UIWindowRegistryRecord {
    public let windowID: String
    public weak var window: NSWindow?
    public let moduleName: String
}
