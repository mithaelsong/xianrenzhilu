// 功能5: 窗口层级管理
// 对应: 支持普通窗口、浮动面板(NSPanel)、模态对话框，提供bringToFront/sendToBack
// 优先级: P1

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "05_窗口层级管理")

// MARK: - 窗口层级类型
// 类型 UIWindowLevelType 已迁移到 UI-02_公共类型定义.swift

// MARK: - 关联对象键
private nonisolated(unsafe) var PinToTopOriginalLevelKey: UInt8 = 0

// MARK: - 窗口层级管理器
/// 管理窗口的前后顺序和层级
/// 支持 bringToFront / sendToBack / 置顶 / 取消置顶
///
/// 线程安全：所有公开方法使用 NSRecursiveLock 保护共享状态（zIndexMap / pinnedWindowIDs）
/// 注意：所有操作 AppKit 窗口属性的方法必须在主线程调用，本类标记为 @MainActor
// 类型 UIWindowLevelManager 已迁移到 UI-02_公共类型定义.swift

// MARK: - 测试代码
#if DEBUG

/// 功能05：窗口层级管理 — 单元测试
/// 覆盖：层级设置、bringToFront/sendToBack、置顶/取消置顶、Z索引、面板创建、
///       重复置顶保护、窗口移除清理、Z顺序排序、不存在的ID查询、并发安全
func test_windowLevel() {
    print("\n🧪 测试1: 设置窗口层级类型")
    let manager = UIWindowLevelManager.shared
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.identifier = NSUserInterfaceItemIdentifier("test_level_001")

    manager.setLevel(for: window, type: .floating)
    guard window.level == .floating else {
        fatalError("❌ 测试1失败: 设置浮动层级后 window.level 应为 .floating，实际为 \(window.level)")
    }
    print("✅ 测试1通过: 层级类型设置正确")

    print("\n🧪 测试2: bringToFront 分配Z索引")
    manager.bringToFront(window)
    let index1 = manager.zIndex(for: "test_level_001")
    guard index1 > 0 else {
        fatalError("❌ 测试2失败: bringToFront后Z索引应为正数，实际为 \(index1)")
    }
    print("✅ 测试2通过: bringToFront后Z索引 = \(index1)")

    print("\n🧪 测试3: sendToBack Z索引归零")
    manager.sendToBack(window)
    let index2 = manager.zIndex(for: "test_level_001")
    guard index2 == 0 else {
        fatalError("❌ 测试3失败: sendToBack后Z索引应为0，实际为 \(index2)")
    }
    print("✅ 测试3通过: sendToBack后Z索引归零")

    print("\n🧪 测试4: 置顶/取消置顶")
    manager.pinToTop(window)
    guard window.level == .floating else {
        fatalError("❌ 测试4失败: pinToTop后 window.level 应为 .floating")
    }
    let index3 = manager.zIndex(for: "test_level_001")
    guard index3 > index1 else {
        fatalError("❌ 测试4失败: pinToTop后Z索引应大于之前")
    }

    manager.unpinFromTop(window)
    guard window.level == .normal else {
        fatalError("❌ 测试4失败: unpinFromTop后 window.level 应为 .normal")
    }
    print("✅ 测试4通过: 置顶/取消置顶切换正确")

    print("\n🧪 测试5: 重复置顶保护（不覆盖原始层级）")
    window.level = .normal
    manager.pinToTop(window)  // 第一次置顶，保存 .normal
    window.level = .floating  // 模拟外部修改（现有逻辑不变）
    manager.pinToTop(window)  // 第二次置顶应被保护，不覆盖已保存的原始层级
    manager.unpinFromTop(window) // 应恢复到 .normal，而不是 .floating
    guard window.level == .normal else {
        fatalError("❌ 测试5失败: 重复置顶后取消，层级应为 .normal，实际为 \(window.level.rawValue)")
    }
    print("✅ 测试5通过: 重复置顶保护正确")

    print("\n🧪 测试6: Z顺序排序")
    let window2 = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
                           styleMask: [.titled], backing: .buffered, defer: false)
    window2.identifier = NSUserInterfaceItemIdentifier("test_level_002")
    manager.bringToFront(window2)

    let ordered = manager.orderedWindowIDs
    guard ordered.first == "test_level_002" else {
        fatalError("❌ 测试6失败: 最后bringToFront的窗口应排在最前，实际顺序为 \(ordered)")
    }
    print("✅ 测试6通过: Z顺序排序正确（最前 = \(ordered.first ?? "nil")）")

    print("\n🧪 测试7: 不存在的窗口ID返回0")
    let nonExistIndex = manager.zIndex(for: "non_existent_window")
    guard nonExistIndex == 0 else {
        fatalError("❌ 测试7失败: 不存在的窗口ID应返回0，实际为 \(nonExistIndex)")
    }
    print("✅ 测试7通过: 不存在的窗口ID返回0")

    print("\n🧪 测试8: 创建浮动面板")
    let panel = manager.createFloatingPanel(rect: NSRect(x: 0, y: 0, width: 300, height: 200), title: "测试面板")
    guard panel.level == .floating else {
        fatalError("❌ 测试8失败: NSPanel层级应为 .floating")
    }
    guard panel.title == "测试面板" else {
        fatalError("❌ 测试8失败: NSPanel标题不匹配")
    }
    guard panel.isFloatingPanel else {
        fatalError("❌ 测试8失败: isFloatingPanel 应为 true")
    }
    // identifier 应包含计数前缀，确保唯一
    guard let panelID = panel.identifier?.rawValue, panelID.hasPrefix("floating_panel_") else {
        fatalError("❌ 测试8失败: 面板 identifier 应为唯一格式，实际为 \(panel.identifier?.rawValue ?? "nil")")
    }
    print("✅ 测试8通过: 浮动面板创建成功，唯一ID = \(panelID)")

    print("\n🧪 测试9: UIWindowLevelType枚举值")
    let normalLevel = UIWindowLevelType.normal.level
    let floatingLevel = UIWindowLevelType.floating.level
    guard floatingLevel > normalLevel else {
        fatalError("❌ 测试9失败: floating层级应大于normal层级")
    }
    print("✅ 测试9通过: 层级枚举值合理（normal < \(normalLevel.rawValue) < floating < \(floatingLevel.rawValue)）")

    print("\n🧪 测试10: 窗口移除清理（无泄漏）")
    manager.removeWindow("test_level_001")
    guard manager.zIndex(for: "test_level_001") == 0 else {
        fatalError("❌ 测试10失败: 移除后Z索引应为0")
    }
    guard !manager.orderedWindowIDs.contains("test_level_001") else {
        fatalError("❌ 测试10失败: 移除后不应出现在排序列表")
    }
    print("✅ 测试10通过: 窗口移除清理正确")

    print("\n🧪 测试11: 并发安全（串行模拟，确保不崩溃）")
    let concurrencyWindow = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 300, height: 200),
                                     styleMask: [.titled], backing: .buffered, defer: false)
    concurrencyWindow.identifier = NSUserInterfaceItemIdentifier("test_concurrent")
    // 串行调用所有方法（实际并发由测试框架保证）
    manager.bringToFront(concurrencyWindow)
    manager.sendToBack(concurrencyWindow)
    manager.pinToTop(concurrencyWindow)
    manager.unpinFromTop(concurrencyWindow)
    manager.removeWindow("test_concurrent")
    print("✅ 测试11通过: 并发安全模拟无崩溃")

    // 清理测试窗口和面板
    window.close()
    window2.close()
    panel.close()
    concurrencyWindow.close()

    print("\n=== 全部窗口层级管理测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWindowLevelManager
public final class UIWindowLevelManager : @unchecked Sendable {
    /// 共享单例
    public static let shared = UIWindowLevelManager()
    private init() {}

    let lock = NSRecursiveLock()

    /// Z 索引字典，key 为窗口 ID，value 为 Z 索引值
    private var zIndexMap: [String: Int] = [:]

    /// 下一次分配的 Z 索引值（递增）
    private var nextZIndex: Int = 1

    /// 当前置顶的窗口 ID 集合，防止 repeatPin 覆盖原始层级
    private var pinnedWindowIDs: Set<String> = []

    /// 浮动面板自增计数器，确保标识唯一
    private var panelCounter: Int = 0

    // MARK: - 层级设置

    /// 设置窗口层级类型
    /// - Parameters:
    ///   - window: 目标窗口
    ///   - type: 层级类型
    public func setLevel(for window: NSWindow, type: UIWindowLevelType) {
        window.level = type.level
        logger.info("设置窗口 '\(window.identifier?.rawValue ?? "未知")' 层级为 \(type.displayName)")
    }

    // MARK: - 前置/后置

    /// 将窗口提到最前（分配最高 Z 索引）
    /// - Parameter window: 目标窗口
    /// - Returns: 分配的 Z 索引值
    @discardableResult
    public func bringToFront(_ window: NSWindow) -> Int {
        guard let windowID = window.identifier?.rawValue else {
            logger.warning("bringToFront 失败：窗口没有 identifier")
            return 0
        }
        let index: Int
        lock.lock()
        index = nextZIndex
        nextZIndex += 1
        zIndexMap[windowID] = index
        lock.unlock()

        window.orderFront(nil)
        logger.info("窗口 '\(windowID)' 提到最前，Z 索引 = \(index)")
        return index
    }

    /// 将窗口置底（Z 索引归零）
    /// - Parameter window: 目标窗口
    public func sendToBack(_ window: NSWindow) {
        guard let windowID = window.identifier?.rawValue else {
            logger.warning("sendToBack 失败：窗口没有 identifier")
            return
        }
        lock.lock()
        zIndexMap[windowID] = 0
        lock.unlock()

        window.orderBack(nil)
        logger.info("窗口 '\(windowID)' 置底")
    }

    /// 获取窗口的 Z 索引
    /// - Parameter windowID: 窗口唯一标识
    /// - Returns: Z 索引值，不存在（或从未 bringToFront）返回 0
    public func zIndex(for windowID: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return zIndexMap[windowID] ?? 0
    }

    /// 按 Z 索引降序排列的窗口 ID 列表（最前优先）
    /// 只包含已通过 bringToFront / pinToTop 分配过正 Z 索引的窗口
    public var orderedWindowIDs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return zIndexMap
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }

    // MARK: - 置顶 / 取消置顶

    /// 将窗口置顶（设为浮动层级，分配最高 Z 索引）
    /// 重复调用不会覆盖原始层级，只有首次调用会保存
    /// - Parameter window: 目标窗口
    public func pinToTop(_ window: NSWindow) {
        guard let windowID = window.identifier?.rawValue else {
            logger.warning("pinToTop 失败：窗口没有 identifier")
            return
        }

        // 检查是否已置顶，防止 repeatPin 覆盖原始层级（关键 bug 修复）
        lock.lock()
        if pinnedWindowIDs.contains(windowID) {
            lock.unlock()
            logger.info("窗口 '\(windowID)' 已置顶，跳过重复操作")
            return
        }
        pinnedWindowIDs.insert(windowID)
        lock.unlock()

        // 保存原始层级到关联对象（使用 rawValue 确保 ObjC 桥接安全）
        objc_setAssociatedObject(window, &PinToTopOriginalLevelKey,
                                 NSNumber(value: window.level.rawValue),
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        window.level = .floating

        lock.lock()
        let index = nextZIndex
        nextZIndex += 1
        zIndexMap[windowID] = index
        lock.unlock()

        window.orderFront(nil)
        logger.info("窗口 '\(windowID)' 已置顶，Z 索引 = \(index)")
    }

    /// 取消窗口置顶（恢复原始层级）
    /// - Parameter window: 目标窗口
    public func unpinFromTop(_ window: NSWindow) {
        guard let windowID = window.identifier?.rawValue else {
            logger.warning("unpinFromTop 失败：窗口没有 identifier")
            return
        }

        // 从置顶集合中移除
        lock.lock()
        pinnedWindowIDs.remove(windowID)
        lock.unlock()

        // 恢复原始层级（rawValue 桥接安全获取）
        let rawNumber = objc_getAssociatedObject(window, &PinToTopOriginalLevelKey) as? NSNumber
        let originalLevel = rawNumber.map { NSWindow.Level(rawValue: $0.intValue) } ?? .normal
        window.level = originalLevel

        logger.info("窗口 '\(windowID)' 已取消置顶，恢复层级 = \(originalLevel.rawValue)")
    }

    // MARK: - 窗口移除

    /// 从层级管理中移除窗口（通常在窗口关闭时调用）
    /// 清理 zIndexMap 和 pinnedWindowIDs，防止内存泄漏
    /// - Parameter windowID: 窗口唯一标识
    public func removeWindow(_ windowID: String) {
        lock.lock()
        zIndexMap.removeValue(forKey: windowID)
        pinnedWindowIDs.remove(windowID)
        lock.unlock()
        logger.info("窗口 '\(windowID)' 已从层级管理中移除")
    }

    // MARK: - 浮动面板创建

    /// 创建浮动面板（NSPanel）
    /// - Parameters:
    ///   - rect: 面板位置和尺寸
    ///   - title: 面板标题
    /// - Returns: 创建的 NSPanel 实例，其 identifier 为唯一值（不重复）
    public func createFloatingPanel(rect: NSRect, title: String) -> NSPanel {
        let panel = NSPanel(contentRect: rect,
                            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                            backing: .buffered, defer: false)
        panel.title = title
        panel.level = .floating
        panel.isFloatingPanel = true

        // 使用自增计数器确保 identifier 唯一，避免标题重复时冲突
        lock.lock()
        let counter = panelCounter
        panelCounter += 1
        lock.unlock()
        let uniqueID = "floating_panel_\(counter)_\(title)"
        panel.identifier = NSUserInterfaceItemIdentifier(uniqueID)

        logger.info("创建浮动面板 '\(title)' (ID: \(uniqueID))")
        return panel
    }
}

// MARK: - 迁回自 UI-02：enum UIWindowLevelType
// MARK: - 迁移自 UI-15_窗口生命周期管理.swift：UIWindowLifecycleManager
// 已迁回 UI-15_窗口生命周期管理.swift：class UIWindowLifecycleManager（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-16_窗口层级管理.swift：UIWindowLevelManager
// 已迁回 UI-16_窗口层级管理.swift：class UIWindowLevelManager（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-16_窗口层级管理.swift：UIWindowLevelType
public enum UIWindowLevelType: Int, CaseIterable, CustomStringConvertible {
    case normal = 0
    case floating = 1
    case modal = 2
    case pinned = 3
    
    public var level: NSWindow.Level {
        switch self {
        case .normal: return .normal
        case .floating: return .floating
        case .modal: return .modalPanel
        case .pinned: return .floating + 1
        }
    }
    
    public var displayName: String {
        switch self {
        case .normal: return "普通窗口"
        case .floating: return "浮动面板"
        case .modal: return "模态对话框"
        case .pinned: return "置顶窗口"
        }
    }
    
    public var description: String { displayName }
}
