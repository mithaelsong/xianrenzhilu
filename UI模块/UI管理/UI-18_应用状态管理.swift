// 功能19A: 应用状态管理
// 对应: 全局状态变更时通知所有相关窗口
// 优先级: P1

import Foundation
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "19A_应用状态管理")

// MARK: - 应用状态
/// 全局应用状态
// 类型 UIAppState 已迁移到 UI-02_公共类型定义.swift

// MARK: - 应用状态管理器
/// 管理全局状态，变更时通知所有相关窗口
///
/// 线程安全：使用 os_unfair_lock 保护观察者列表的并发访问，
/// 通知回调在锁外执行以避免死锁和阻塞。
// 类型 UIAppStateManager 已迁移到 UI-02_公共类型定义.swift

// MARK: - 测试代码
#if DEBUG

/// 功能19A：应用状态管理 — 单元测试
/// 覆盖：状态默认值 / 更新观察者通知 / 周期更新 / 批量更新 / 观察者移除 / 空值防护
func test_appState() {
    let manager = UIAppStateManager.shared

    print("\n🧪 测试1: 初始状态默认值")
    let state = manager.currentState
    guard state.symbol == "BTC/USDT" else {
        fatalError("❌ 测试1失败: 默认品种错误")
    }
    print("✅ 测试1通过: 初始状态正确")

    print("\n🧪 测试2: 更新品种并检查通知")
    var notifiedSymbol = ""
    _ = manager.addObserver(id: "test") { newState in
        notifiedSymbol = newState.symbol
    }
    manager.updateSymbol("ETH/USDT")
    guard notifiedSymbol == "ETH/USDT" else {
        fatalError("❌ 测试2失败: 观察者未收到新品种")
    }
    print("✅ 测试2通过: 观察者收到更新")

    print("\n🧪 测试3: 更新周期")
    manager.updatePeriod("4h")
    guard manager.currentState.period == "4h" else {
        fatalError("❌ 测试3失败: 周期更新失败")
    }
    print("✅ 测试3通过: 周期更新正确")

    print("\n🧪 测试4: 批量更新")
    manager.updateState { state in
        state.symbol = "SOL/USDT"
        state.showDepthChart = false
    }
    guard manager.currentState.symbol == "SOL/USDT" else {
        fatalError("❌ 测试4失败: 批量更新未生效")
    }
    print("✅ 测试4通过: 批量更新成功")

    print("\n🧪 测试5: 移除观察者（验证不再收到通知）")
    var notifiedAfterRemoval = false
    let checkToken = manager.addObserver(id: "test-check") { _ in notifiedAfterRemoval = true }
    manager.removeObserver(id: checkToken)
    manager.updateSymbol("DOGE/USDT")
    guard !notifiedAfterRemoval else {
        fatalError("❌ 测试5失败: 移除后观察者仍收到通知")
    }
    print("✅ 测试5通过: 观察者移除成功，移除后不再收到通知")

    print("\n🧪 测试6: 移除空ID观察者（边界情况，不应当崩溃）")
    manager.removeObserver(id: "")
    print("✅ 测试6通过: 移除空ID观察者不崩溃")

    print("\n🧪 测试7: 传入空品种应被忽略")
    manager.updateSymbol("")
    guard manager.currentState.symbol == "DOGE/USDT" else {
        fatalError("❌ 测试7失败: 空品种未正确忽略")
    }
    print("✅ 测试7通过: 空品种防护生效")

    print("\n🧪 测试8: 更新颜色方案")
    manager.updateColorScheme("暗夜绿")
    guard manager.currentState.colorScheme == "暗夜绿" else {
        fatalError("❌ 测试8失败: 颜色方案更新失败")
    }
    print("✅ 测试8通过: 颜色方案更新成功")

    print("\n🧪 测试9: 传入空颜色方案应被忽略")
    manager.updateColorScheme("")
    guard manager.currentState.colorScheme == "暗夜绿" else {
        fatalError("❌ 测试9失败: 空颜色方案未正确忽略")
    }
    print("✅ 测试9通过: 空颜色方案防护生效")

    print("\n🧪 测试10: 切换深度图显示")
    manager.setShowDepthChart(false)
    guard manager.currentState.showDepthChart == false else {
        fatalError("❌ 测试10失败: 深度图显示切换失败")
    }
    print("✅ 测试10通过: 深度图显示切换成功")

    print("\n🧪 测试11: 切换交易面板显示")
    manager.setShowTradePanel(false)
    guard manager.currentState.showTradePanel == false else {
        fatalError("❌ 测试11失败: 交易面板显示切换失败")
    }
    print("✅ 测试11通过: 交易面板显示切换成功")

    print("\n=== 全部应用状态管理测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIAppStateManager
public final class UIAppStateManager : @unchecked Sendable {
    public static let shared = UIAppStateManager()
    public private(set) var currentState = UIAppState()
    private var observers: [String: (UIAppState) -> Void] = [:]
    private var lock = os_unfair_lock()
    private init() {}

    /// 更新交易品种
    /// - Parameter symbol: 新的品种名称，为空时忽略
    public func updateSymbol(_ symbol: String) {
        guard !symbol.isEmpty else {
            logger.warning("尝试设置空品种，已忽略")
            return
        }
        os_unfair_lock_lock(&lock)
        currentState.symbol = symbol
        os_unfair_lock_unlock(&lock)
        notifyObservers()
    }

    /// 更新K线周期
    /// - Parameter period: 新的周期值，为空时忽略
    public func updatePeriod(_ period: String) {
        guard !period.isEmpty else {
            logger.warning("尝试设置空周期，已忽略")
            return
        }
        os_unfair_lock_lock(&lock)
        currentState.period = period
        os_unfair_lock_unlock(&lock)
        notifyObservers()
    }

    /// 更新颜色方案
    /// - Parameter colorScheme: 新的方案名称，为空时忽略
    public func updateColorScheme(_ colorScheme: String) {
        guard !colorScheme.isEmpty else {
            logger.warning("尝试设置空颜色方案，已忽略")
            return
        }
        os_unfair_lock_lock(&lock)
        currentState.colorScheme = colorScheme
        os_unfair_lock_unlock(&lock)
        notifyObservers()
    }

    /// 设置是否显示深度图
    /// - Parameter show: 是否显示
    public func setShowDepthChart(_ show: Bool) {
        os_unfair_lock_lock(&lock)
        currentState.showDepthChart = show
        os_unfair_lock_unlock(&lock)
        notifyObservers()
    }

    /// 设置是否显示交易面板
    /// - Parameter show: 是否显示
    public func setShowTradePanel(_ show: Bool) {
        os_unfair_lock_lock(&lock)
        currentState.showTradePanel = show
        os_unfair_lock_unlock(&lock)
        notifyObservers()
    }

    /// 批量更新状态
    /// - Parameter update: 状态变更闭包，建议保持轻量快速
    /// 注意：闭包在锁内执行，请勿在闭包中调用其他加锁操作以避免死锁
    public func updateState(_ update: (inout UIAppState) -> Void) {
        os_unfair_lock_lock(&lock)
        update(&currentState)
        os_unfair_lock_unlock(&lock)
        notifyObservers()
    }

    /// 添加状态变更观察者
    /// - Parameters:
    ///   - id: 观察者唯一标识符
    ///   - block: 状态变更回调，回调执行在通知线程，请自行调度到主线程
    /// - Returns: 传入的标识符，可用于后续移除
    @discardableResult
    public func addObserver(id: String, _ block: @escaping (UIAppState) -> Void) -> String {
        os_unfair_lock_lock(&lock)
        observers[id] = block
        os_unfair_lock_unlock(&lock)
        return id
    }

    /// 移除状态变更观察者
    /// - Parameter id: 要移除的观察者标识符
    public func removeObserver(id: String) {
        guard !id.isEmpty else { return }
        os_unfair_lock_lock(&lock)
        observers.removeValue(forKey: id)
        os_unfair_lock_unlock(&lock)
    }

    /// 通知所有观察者（锁外执行回调）
    /// 锁定状态下先快照观察者列表并复制当前状态，
    /// 再释放锁，然后在锁外逐个回调，避免死锁与数据竞争。
    private func notifyObservers() {
        let snapshot: [(String, (UIAppState) -> Void)]
        let state: UIAppState
        os_unfair_lock_lock(&lock)
        snapshot = Array(observers)
        state = currentState
        os_unfair_lock_unlock(&lock)

        for (_, block) in snapshot {
            block(state)
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIAppState
// MARK: - 迁移自 UI-18_应用状态管理.swift：UIAppState
public struct UIAppState {
    /// 当前交易品种
    public var symbol: String = "BTC/USDT"
    /// K线周期
    public var period: String = "1h"
    /// 颜色方案
    public var colorScheme: String = "默认"
    /// 是否显示深度图
    public var showDepthChart: Bool = true
    /// 是否显示交易面板
    public var showTradePanel: Bool = true

    public init() {}
}
