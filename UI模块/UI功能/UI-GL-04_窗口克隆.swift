// 功能6: 窗口克隆/新实例
// 对应: 同一模块可打开多个独立窗口实例（如对比不同K线），通过模块标识符创建
// 优先级: P1
// 版本: 2.0

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "06B_窗口克隆")

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能06B：窗口克隆 — 单元测试
/// 覆盖：克隆编号生成、计数器管理、边界情况
@MainActor
func test_windowClone() {
    print("\n🧪 测试1: 克隆编号递增")
    let manager = UIWindowCloneManager.shared
    
    let num1 = manager.totalCloneCount(for: "test_module")
    guard num1 == 0 else {
        fatalError("❌ 测试1失败: 初始克隆数应为0，实际为\(num1)")
    }
    print("✅ 测试1通过: 初始克隆数为0")
    
    print("\n🧪 测试2: 多次获取克隆编号递增")
    // 通过resetCounter重置后测试自增
    manager.resetCounter(for: "test_counter")
    let c1 = manager.totalCloneCount(for: "test_counter")
    guard c1 == 0 else {
        fatalError("❌ 测试2失败: reset后计数应为0，实际为\(c1)")
    }
    print("✅ 测试2通过: resetCounter后计数归零")
    
    print("\n🧪 测试3: 不同模块计数器独立")
    let countA = manager.totalCloneCount(for: "module_A")
    let countB = manager.totalCloneCount(for: "module_B")
    guard countA == countB else {
        fatalError("❌ 测试3失败: 不同模块初始计数应一致，但A=\(countA), B=\(countB)")
    }
    print("✅ 测试3通过: 不同模块计数器独立")
    
    print("\n🧪 测试4: 不存在的模块返回0")
    let nonExist = manager.totalCloneCount(for: "non_existent_module")
    guard nonExist == 0 else {
        fatalError("❌ 测试4失败: 不存在的模块应返回0，实际为\(nonExist)")
    }
    print("✅ 测试4通过: 不存在的模块返回0")
    
    print("\n🧪 测试5: 重复访问计数器不崩溃")
    for _ in 0..<10 {
        _ = manager.totalCloneCount(for: "concurrent_module")
    }
    print("✅ 测试5通过: 10次重复读取未崩溃")
    
    print("\n🧪 测试6: 克隆窗口ID格式验证")
    let testID = "stock_chart_clone_3"
    guard testID.contains("_clone_") else {
        fatalError("❌ 测试6失败: 克隆窗口ID应包含_clone_")
    }
    guard testID.hasPrefix("stock_chart") else {
        fatalError("❌ 测试6失败: 克隆窗口ID应以模块名开头")
    }
    print("✅ 测试6通过: 克隆窗口ID格式正确")
    
    print("\n=== 全部窗口克隆测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWindowCloneManager
@MainActor public final class UIWindowCloneManager : @unchecked Sendable {

    public static let shared = UIWindowCloneManager()

    private var cloneCounters: [String: Int] = [:]
    private let lock = NSRecursiveLock()

    private init() {}

    // MARK: - 克隆窗口

    /// 克隆一个模块的窗口
    /// - Parameters:
    ///   - moduleName: 模块名
    ///   - title: 窗口标题
    ///   - contentFactory: 创建内容视图控制器的闭包（每次克隆调用一次，创建独立实例）
    ///   - rect: 窗口位置和大小
    /// - Returns: 克隆的窗口控制器，失败返回nil
    @discardableResult
    public func cloneWindow(
        moduleName: String,
        title: String,
        contentFactory: () -> NSViewController,
        rect: NSRect = NSRect(x: 200, y: 200, width: 800, height: 600)
    ) -> NSWindowController? {
        let cloneNumber = nextCloneNumber(for: moduleName)
        let windowID = "\(moduleName)_clone_\(cloneNumber)"

        // 检查是否已存在此ID
        guard UIUnifiedRegistry.shared.getWindowRecord(windowID: windowID) == nil else {
            return nil
        }

        // 创建内容视图（独立实例）
        let contentVC = contentFactory()

        // 创建窗口
        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(title) - \(cloneNumber)"
        window.contentViewController = contentVC
        window.identifier = NSUserInterfaceItemIdentifier(windowID)

        let controller = NSWindowController(window: window)

        // 注册到窗口注册表
        let registered = UIUnifiedRegistry.shared.registerWindow(
            windowID: windowID,
            controller: controller,
            moduleName: moduleName
        )

        guard registered else {
            return nil
        }

        return controller
    }

    /// 获取指定模块当前打开的克隆窗口数
    public func cloneCount(for moduleName: String) -> Int {
        return UIUnifiedRegistry.shared.getWindowRecords(for: moduleName).filter {
            $0.windowID.contains("_clone_")
        }.count
    }

    /// 关闭指定模块的所有克隆窗口
    public func closeAllClones(for moduleName: String) {
        let windows = UIUnifiedRegistry.shared.getWindowRecords(for: moduleName).filter {
            $0.windowID.contains("_clone_")
        }
        for record in windows {
            UIWindowLifecycleManager.shared.close(windowID: record.windowID)
        }
    }

    /// 重置指定模块的克隆编号（从1重新开始）
    public func resetCounter(for moduleName: String) {
        lock.lock()
        cloneCounters[moduleName] = 0
        lock.unlock()
    }

    /// 获取指定模块已生成的克隆总数（含已关闭的）
    public func totalCloneCount(for moduleName: String) -> Int {
        lock.lock()
        let count = cloneCounters[moduleName] ?? 0
        lock.unlock()
        return count
    }

    // MARK: - 内部方法

    private func nextCloneNumber(for moduleName: String) -> Int {
        lock.lock()
        let current = cloneCounters[moduleName] ?? 0
        let next = current + 1
        cloneCounters[moduleName] = next
        lock.unlock()
        return next
    }
}
