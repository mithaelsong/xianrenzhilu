// 功能8B: 面板类型系统
// 对应: 支持工具面板、参数面板、输出面板、图表面板等不同类型，预设不同尺寸和行为
// 优先级: P0

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "08B_面板类型系统")

// 面板类型定义在 UI-02_公共类型定义.swift 中
// WindowLevelType、UIPanelType、UIPanelConfiguration 均引用 UI-02 公共类型

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能08B：面板类型系统 — 单元测试
/// 覆盖：面板类型预设值、配置创建、默认配置、枚举完整性
func test_panelType() {
    print("\n🧪 测试1: 面板类型枚举完整性")
    let allTypes = UIPanelType.allCases
    guard allTypes.count == 6 else {
        fatalError("❌ 测试1失败: 应有6种面板类型，实际\(allTypes.count)")
    }
    for type in allTypes {
        guard type.defaultWidth > 0 else {
            fatalError("❌ 测试1失败: 面板类型\(type) defaultWidth 应大于0")
        }
        guard type.defaultHeight > 0 else {
            fatalError("❌ 测试1失败: 面板类型\(type) defaultHeight 应大于0")
        }
        guard !type.rawValue.isEmpty else {
            fatalError("❌ 测试1失败: 面板类型\(type) rawValue 为空")
        }
    }
    print("✅ 测试1通过: 全部\(allTypes.count)种面板类型配置齐全")
    
    print("\n🧪 测试2: 面板类型默认尺寸")
    guard UIPanelType.chart.defaultWidth == 600 else {
        fatalError("❌ 测试2失败: chart默认宽度应为600")
    }
    guard UIPanelType.tool.defaultWidth == 280 else {
        fatalError("❌ 测试2失败: tool默认宽度应为280")
    }
    guard UIPanelType.debug.defaultWidth == 500 else {
        fatalError("❌ 测试2失败: debug默认宽度应为500")
    }
    print("✅ 测试2通过: 面板默认尺寸正确")
    
    print("\n🧪 测试3: UIPanelConfiguration创建")
    let config = UIPanelConfiguration(type: .tool, identifier: "tool_001", title: "指标列表", moduleName: "indicators")
    guard config.identifier == "tool_001" else {
        fatalError("❌ 测试3失败: identifier不匹配")
    }
    guard config.moduleName == "indicators" else {
        fatalError("❌ 测试3失败: moduleName不匹配")
    }
    guard config.width == UIPanelType.tool.defaultWidth else {
        fatalError("❌ 测试3失败: width应等于默认宽度\(UIPanelType.tool.defaultWidth)")
    }
    print("✅ 测试3通过: 面板配置创建正确")
    
    print("\n🧪 测试4: 自定尺寸面板配置")
    let customConfig = UIPanelConfiguration(type: .chart, identifier: "chart_001", title: "BTC/USDT", moduleName: "trading", width: 800, height: 600)
    guard customConfig.width == 800 && customConfig.height == 600 else {
        fatalError("❌ 测试4失败: 自定义尺寸不匹配")
    }
    print("✅ 测试4通过: 自定尺寸面板配置正确")
    
    print("\n🧪 测试5: isResizable全部为true")
    for type in allTypes {
        guard type.isResizable else {
            fatalError("❌ 测试5失败: 面板类型\(type) isResizable 应为true")
        }
    }
    print("✅ 测试5通过: 全部面板可调整尺寸")
    
    print("\n🧪 测试6: 默认配置工厂方法")
    let manager = UIPanelManager.shared
    let defaultConfig = manager.defaultConfiguration(for: .info, identifier: "info_default", title: "信息", moduleName: "default")
    guard defaultConfig.type == .info else {
        fatalError("❌ 测试6失败: 默认配置类型应为info")
    }
    print("✅ 测试6通过: 默认配置工厂方法正确")
    
    print("\n=== 全部面板类型测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIPanelManager
public final class UIPanelManager : @unchecked Sendable {
    
    public static let shared = UIPanelManager()
    
    private let lock = NSRecursiveLock()
    
    private init() {
        logger.info("面板管理器已初始化")
    }
    
    @discardableResult
    public func createPanel(config: UIPanelConfiguration, contentView: NSView) -> NSWindowController? {
        let rect = NSRect(x: 200, y: 200, width: config.width, height: config.height)
        
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        let panel = NSPanel(
            contentRect: rect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        panel.title = config.title
        panel.identifier = NSUserInterfaceItemIdentifier(config.identifier)
        panel.isFloatingPanel = config.isFloating
        panel.styleMask.insert(.closable)
        if !config.isClosable {
            panel.styleMask.remove(.closable)
        }
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        
        let visualEffect = NSVisualEffectView(frame: rect)
        visualEffect.material = .windowBackground
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .followsWindowActiveState
        visualEffect.autoresizingMask = [.width, .height]
        
        let container = NSView(frame: rect)
        container.wantsLayer = true
        container.addSubview(visualEffect)
        
        contentView.frame = container.bounds
        contentView.autoresizingMask = [.width, .height]
        container.addSubview(contentView)
        
        panel.contentView = container
        panel.setFrameAutosaveName(NSWindow.FrameAutosaveName(config.identifier))
        
        let controller = NSWindowController(window: panel)
        
        lock.lock()
        let record = UIWindowRecord(windowID: config.identifier, window: panel, windowController: controller, moduleName: config.moduleName, creationTime: Date(), isClosed: false, frame: panel.frame, zIndex: 0)
        UIWindowRegistry.shared.register(record)
        lock.unlock()
        
        logger.info("已创建面板: \(config.identifier)（类型：\(config.type.rawValue)，模块：\(config.moduleName)）")
        return controller
    }
    
    public func defaultConfiguration(for type: UIPanelType, identifier: String, title: String, moduleName: String) -> UIPanelConfiguration {
        return UIPanelConfiguration(type: type, identifier: identifier, title: title, moduleName: moduleName)
    }
}
