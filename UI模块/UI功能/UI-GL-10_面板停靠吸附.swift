// 功能9: 面板停靠/吸附
// 对应: 面板拖拽到窗口边缘时自动吸附，支持多个面板并排或堆叠
// 优先级: P1

import Foundation
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "09B_面板停靠吸附")

import AppKit

// 类型定义已迁移至 UI-GL-10_types.swift（版本 2.0）

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能09B：面板停靠吸附 — 单元测试
/// 覆盖：停靠位置枚举、吸附检测、停靠/取消停靠、清除
func test_panelDock() {
    print("\n🧪 测试1: UIDockPosition枚举完整性")
    let positions: [UIDockPosition] = [.left, .right, .top, .bottom, .center]
    guard positions.count == 5 else {
        fatalError("❌ 测试1失败: 应有5种停靠位置")
    }
    for pos in positions {
        guard !pos.rawValue.isEmpty else {
            fatalError("❌ 测试1失败: UIDockPosition rawValue 为空")
        }
    }
    print("✅ 测试1通过: 全部5种停靠位置有效")
    
    print("\n🧪 测试2: UIDockRegion结构")
    let region = UIDockRegion(position: .left, bounds: .zero, panelIDs: [])
    guard region.isEmpty else {
        fatalError("❌ 测试2失败: 空panelIDs时isEmpty应为true")
    }
    let nonEmptyRegion = UIDockRegion(position: .right, bounds: .zero, panelIDs: ["panel1"])
    guard !nonEmptyRegion.isEmpty else {
        fatalError("❌ 测试2失败: 有panelID时isEmpty应为false")
    }
    print("✅ 测试2通过: UIDockRegion isEmpty正确")
    
    print("\n🧪 测试3: 吸附检测-边缘检测")
    let manager = UIPanelDockManager.shared
    manager.isSnapEnabled = true
    manager.snapThreshold = 30
    
    let mainFrame = NSRect(x: 0, y: 0, width: 1000, height: 800)
    let nearLeft = NSRect(x: 5, y: 0, width: 300, height: 200)
    let snapped = manager.detectSnap(windowFrame: nearLeft, mainWindowFrame: mainFrame)
    guard snapped == .left else {
        fatalError("❌ 测试3失败: 距离边缘5px应吸附到left")
    }
    
    let nearRight = NSRect(x: 975, y: 0, width: 300, height: 200)
    let snappedR = manager.detectSnap(windowFrame: nearRight, mainWindowFrame: mainFrame)
    guard snappedR == .right else {
        fatalError("❌ 测试3失败: 距离右边缘25px应吸附到right")
    }
    print("✅ 测试3通过: 边缘吸附检测正确")
    
    print("\n🧪 测试4: 吸附检测-距离超过阈值不吸附")
    let farWindow = NSRect(x: 100, y: 0, width: 300, height: 200)
    let noSnap = manager.detectSnap(windowFrame: farWindow, mainWindowFrame: mainFrame)
    guard noSnap == nil else {
        fatalError("❌ 测试4失败: 距离边缘100px不应吸附")
    }
    print("✅ 测试4通过: 超出阈值不吸附")
    
    print("\n🧪 测试5: 吸附开关")
    manager.isSnapEnabled = false
    let nearLeft2 = NSRect(x: 5, y: 0, width: 300, height: 200)
    let disabledSnap = manager.detectSnap(windowFrame: nearLeft2, mainWindowFrame: mainFrame)
    guard disabledSnap == nil else {
        fatalError("❌ 测试5失败: isSnapEnabled=false时不应吸附")
    }
    manager.isSnapEnabled = true
    print("✅ 测试5通过: 吸附开关有效")
    
    print("\n🧪 测试6: 清除全部停靠")
    let dockFrame = manager.dock(windowID: "test_panel_001", to: .left, mainWindowFrame: mainFrame)
    guard dockFrame != .zero else {
        fatalError("❌ 测试6失败: 停靠失败，返回.zero")
    }
    manager.clearAll()
    let info = manager.dockedPanelInfo
    guard info.isEmpty else {
        fatalError("❌ 测试6失败: 清除后dockedPanelInfo应为空")
    }
    print("✅ 测试6通过: 清除全部后状态为空")
    
    print("\n=== 全部面板停靠吸附测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIPanelDockManager
public final class UIPanelDockManager : @unchecked Sendable {
    
    public static let shared = UIPanelDockManager()
    
    /// 吸附阈值（距离窗口边缘多少像素时触发吸附）
    public var snapThreshold: CGFloat = 30.0
    
    /// 是否启用吸附
    public var isSnapEnabled: Bool = true
    
    private var dockedPanels: [UIDockPosition: [String]] = [:]
    private var dragStartPositions: [String: NSPoint] = [:]
    private let lock = NSRecursiveLock()
    
    private init() {}
    
    // MARK: - 停靠操作
    
    /// 将面板停靠到指定位置
    /// - Parameters:
    ///   - windowID: 面板窗口ID
    ///   - position: 停靠位置
    ///   - mainWindowFrame: 主窗口的帧
    /// - Returns: 停靠后的窗口位置
    public func dock(windowID: String, to position: UIDockPosition, mainWindowFrame: NSRect) -> NSRect {
        guard let window = UIUnifiedRegistry.shared.getWindowRecord(windowID: windowID)?.window else {
            return .zero
        }
        
        let panelFrame = window.frame
        var newFrame = panelFrame
        
        lock.lock()
        var panels = dockedPanels[position] ?? []
        if !panels.contains(windowID) {
            panels.append(windowID)
            dockedPanels[position] = panels
        }
        lock.unlock()
        
        switch position {
        case .left:
            newFrame.origin.x = mainWindowFrame.origin.x
            newFrame.origin.y = mainWindowFrame.origin.y
            newFrame.size.height = mainWindowFrame.height
            newFrame.size.width = min(panelFrame.width, mainWindowFrame.width * 0.4)
            
        case .right:
            newFrame.origin.x = mainWindowFrame.maxX - panelFrame.width
            newFrame.origin.y = mainWindowFrame.origin.y
            newFrame.size.height = mainWindowFrame.height
            
        case .top:
            newFrame.origin.x = mainWindowFrame.origin.x
            newFrame.origin.y = mainWindowFrame.maxY - panelFrame.height
            newFrame.size.width = mainWindowFrame.width
            
        case .bottom:
            newFrame.origin.x = mainWindowFrame.origin.x
            newFrame.origin.y = mainWindowFrame.origin.y
            newFrame.size.width = mainWindowFrame.width
            
        case .center:
            break // 保持浮动，不吸附
        }
        
        return newFrame
    }
    
    /// 取消面板停靠，恢复浮动状态
    public func undock(windowID: String) {
        lock.lock()
        // 遍历所有停靠位置，移除指定面板
        for position in dockedPanels.keys {
            dockedPanels[position]?.removeAll { $0 == windowID }
            // 如果该位置没有面板了，移除空键
            if let panels = dockedPanels[position], panels.isEmpty {
                dockedPanels.removeValue(forKey: position)
            }
        }
        lock.unlock()
    }
    
    /// 检测窗口是否应吸附到主窗口边缘
    /// - Parameters:
    ///   - windowFrame: 窗口当前的帧
    ///   - mainWindowFrame: 主窗口的帧
    /// - Returns: 如果吸附返回吸附位置，否则nil
    public func detectSnap(windowFrame: NSRect, mainWindowFrame: NSRect) -> UIDockPosition? {
        guard isSnapEnabled else { return nil }
        
        let threshold = snapThreshold
        
        // 检测左边缘
        if abs(windowFrame.origin.x - mainWindowFrame.origin.x) < threshold {
            return .left
        }
        
        // 检测右边缘
        if abs(windowFrame.maxX - mainWindowFrame.maxX) < threshold {
            return .right
        }
        
        // 检测顶部
        if abs(windowFrame.maxY - mainWindowFrame.maxY) < threshold {
            return .top
        }
        
        // 检测底部
        if abs(windowFrame.origin.y - mainWindowFrame.origin.y) < threshold {
            return .bottom
        }
        
        return nil
    }
    
    // MARK: - 布局管理
    
    /// 获取所有已停靠面板的位置信息（用于布局序列化）
    public var dockedPanelInfo: [String: String] {
        lock.lock()
        var info: [String: String] = [:]
        for (position, panels) in dockedPanels {
            for panelID in panels {
                info[panelID] = position.rawValue
            }
        }
        lock.unlock()
        return info
    }
    
    /// 清理所有停靠状态
    public func clearAll() {
        lock.lock()
        dockedPanels.removeAll()
        lock.unlock()
    }
}
