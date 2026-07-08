// 功能17A: 全局事件总线
// 对应: 模块间通信（跨窗口），例如"品种切换"事件通知所有窗口
// 优先级: P0
//
// 注意: 这是 UIGlobalEventBus 的主要定义文件。
//       UI功能/25_模块间通信协议.swift 中的同名类型为精简 stub，
//       仅用于该文件的独立 swiftc -typecheck 编译。

import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "17A_全局事件总线")

// MARK: - 订阅令牌
/// 用于取消订阅的不透明令牌
/// 由 on() 方法自动创建，不可外部构造
// 类型 UIEventSubscriptionToken 已迁移到 UI-02_公共类型定义.swift

// MARK: - 标准事件消息
/// 模块间通信的标准消息格式
// 类型 UIMessage 已迁移到 UI-02_公共类型定义.swift

// 使用UI-02的ModuleNotification和NotificationType
// 本文件不再定义这些类型

// MARK: - 全局事件总线
/// 模块间通信（跨窗口），发送 UIMessage 格式的消息。
///
/// 支持订阅/取消订阅特定 action 的事件，以及清除所有订阅。
/// 线程安全：所有公共方法使用 NSRecursiveLock 保护。
// 类型 UIGlobalEventBus 已迁移到 UI-02_公共类型定义.swift

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能17A：全局事件总线 — 单元测试
/// 覆盖：订阅/发送/Token取消/按动作取消/清除
func test_eventBus() {
    print("\n🧪 测试1: 订阅并接收消息")
    let bus = UIGlobalEventBus.shared
    var received: [String] = []
    let token1 = bus.on("test.event") { msg in
        received.append(msg.action)
    }
    bus.send(UIMessage(sender: "测试", action: "test.event"))
    guard received.count == 1 else {
        fatalError("❌ 测试1失败: 应收到1条消息，实际收到 \(received.count)")
    }
    print("✅ 测试1通过: 消息发送/接收正确")

    print("\n🧪 测试2: 多订阅者独立接收")
    var received2: [String] = []
    bus.on("test.event") { msg in
        received2.append(msg.action)
    }
    bus.send(UIMessage(sender: "测试", action: "test.event"))
    guard received.count == 2, received2.count == 1 else {
        fatalError("❌ 测试2失败: 两个订阅者都应收到，received=\(received.count), received2=\(received2.count)")
    }
    print("✅ 测试2通过: 多订阅者正确")

    print("\n🧪 测试3: 按Token精确取消")
    bus.off(token: token1)
    bus.send(UIMessage(sender: "测试", action: "test.event"))
    guard received.count == 2 else {
        fatalError("❌ 测试3失败: 取消后不应再增加，当前 count=\(received.count)")
    }
    print("✅ 测试3通过: Token取消正确")

    print("\n🧪 测试4: 按动作取消所有")
    bus.offAll(for: "test.event")
    bus.send(UIMessage(sender: "测试", action: "test.event"))
    guard received.count == 2, received2.count == 1 else {
        fatalError("❌ 测试4失败: 取消所有后不应再收到")
    }
    print("✅ 测试4通过: 按动作取消正确")

    print("\n🧪 测试5: 清除所有")
    let token3 = bus.on("another.event") { _ in }
    // 清除前应有活跃订阅
    guard bus.subscriptionCount > 0 else {
        fatalError("❌ 测试5失败: 清除前应有订阅")
    }
    bus.clear()
    guard bus.subscriptionCount == 0 else {
        fatalError("❌ 测试5失败: 清除后订阅数应为 0，实际为 \(bus.subscriptionCount)")
    }
    // 清除后新订阅应正常工作
    var clearedCount = 0
    let checkToken = bus.on("check") { _ in clearedCount += 1 }
    bus.send(UIMessage(sender: "测试", action: "check"))
    guard clearedCount == 1 else {
        fatalError("❌ 测试5失败: 清除后新订阅应正常接收")
    }
    // 旧令牌应已失效
    bus.off(token: token3)
    // 清理
    bus.off(token: checkToken)
    bus.clear()
    print("✅ 测试5通过: 清除后新订阅正常，旧订阅已失效")

    print("\n🧪 测试6: 订阅计数")
    let t1 = bus.on("e1") { _ in }
    let t2 = bus.on("e2") { _ in }
    bus.on("e1") { _ in }
    guard bus.subscriptionCount == 3 else {
        fatalError("❌ 测试6失败: 订阅数应为 3，实际为 \(bus.subscriptionCount)")
    }
    bus.off(token: t1)
    guard bus.subscriptionCount == 2 else {
        fatalError("❌ 测试6失败: 取消后订阅数应为 2，实际为 \(bus.subscriptionCount)")
    }
    bus.offAll(for: "e1")
    guard bus.subscriptionCount == 1 else {
        fatalError("❌ 测试6失败: 按动作取消后订阅数应为 1，实际为 \(bus.subscriptionCount)")
    }
    bus.off(token: t2)
    guard bus.subscriptionCount == 0 else {
        fatalError("❌ 测试6失败: 全部取消后订阅数应为 0")
    }
    print("✅ 测试6通过: 订阅计数正确")

    print("\n🧪 测试7: 发送消息给无订阅者（不崩溃）")
    bus.send(UIMessage(sender: "测试", action: "nonexistent"))
    print("✅ 测试7通过: 无订阅者时正常")

    print("\n🧪 测试8: 定向发送（按目标模块过滤）")
    var moduleAResult: [String] = []
    var moduleBResult: [String] = []
    let tokenA = bus.on("定向消息", fromModule: "ModuleA") { msg in
        moduleAResult.append(msg.sender)
    }
    let tokenB = bus.on("定向消息", fromModule: "ModuleB") { msg in
        moduleBResult.append(msg.sender)
    }
    // 不指定模块的广播订阅，也应能收到定向消息
    var anyModuleResult: [String] = []
    let tokenAny = bus.on("定向消息") { msg in
        anyModuleResult.append(msg.sender)
    }
    // 发送定向到 ModuleA 的消息
    bus.send(UIMessage(sender: "品种管理", target: "ModuleA", action: "定向消息"))
    guard moduleAResult.count == 1 else {
        fatalError("❌ 测试8失败: ModuleA 应收到 1 条，实际 \(moduleAResult.count)")
    }
    guard moduleBResult.isEmpty else {
        fatalError("❌ 测试8失败: ModuleB 不应收到，实际 \(moduleBResult.count)")
    }
    guard anyModuleResult.isEmpty else {
        fatalError("❌ 测试8失败: 不指定模块的订阅不应收到定向消息，实际 \(anyModuleResult.count)")
    }
    // 清理
    bus.off(token: tokenA)
    bus.off(token: tokenB)
    bus.off(token: tokenAny)
    print("✅ 测试8通过: 定向发送按目标模块正确过滤")

    print("\n🧪 测试9: 广播消息时所有订阅者均收到（与定向互斥）")
    var broadcastA: [String] = []
    var broadcastAny: [String] = []
    let bTokenA = bus.on("广播消息", fromModule: "ModuleA") { msg in
        broadcastA.append(msg.sender)
    }
    let bTokenAny = bus.on("广播消息") { msg in
        broadcastAny.append(msg.sender)
    }
    bus.send(UIMessage(sender: "测试", action: "广播消息"))
    guard broadcastA.count == 1 else {
        fatalError("❌ 测试9失败: 指定模块的订阅应收到广播，实际 \(broadcastA.count)")
    }
    guard broadcastAny.count == 1 else {
        fatalError("❌ 测试9失败: 不指定模块的订阅应收到广播，实际 \(broadcastAny.count)")
    }
    bus.off(token: bTokenA)
    bus.off(token: bTokenAny)
    print("✅ 测试9通过: 广播时所有订阅者正确接收")

    print("\n=== 全部事件总线测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIGlobalEventBus
public final class UIGlobalEventBus : @unchecked Sendable {
    public static let shared = UIGlobalEventBus()

    private typealias Handler = (UIMessage) -> Void
    private struct UISubscription {
        let token: UIEventSubscriptionToken
        let action: String
        /// 注册时所属模块（nil 表示任意模块均可接收此动作的消息）
        let targetModule: String?
        let handler: Handler
    }

    private var subscriptions: [UISubscription] = []
    let lock = NSRecursiveLock()

    private init() {
        logger.info("全局事件总线已初始化")
    }

    // MARK: - 订阅

    /// 订阅指定动作的事件
    /// - Parameters:
    ///   - action: 要订阅的动作名称
    ///   - module: 订阅者所属模块名（nil 表示接收所有模块发送的此动作消息）
    ///   - handler: 收到消息时的回调（在主调线程调用，锁外）
    /// - Returns: 订阅令牌，用于取消订阅
    @discardableResult
    public func on(_ action: String, fromModule module: String? = nil, handler: @escaping (UIMessage) -> Void) -> UIEventSubscriptionToken {
        let token = UIEventSubscriptionToken()
        let subscription = UISubscription(token: token, action: action, targetModule: module, handler: handler)

        lock.lock()
        subscriptions.append(subscription)
        let count = subscriptions.count
        lock.unlock()

        logger.debug("订阅事件 '\(action)'，当前订阅数: \(count)")
        return token
    }

    // MARK: - 取消订阅

    /// 按令牌精确取消一条订阅
    /// - Parameter token: 订阅时返回的令牌
    public func off(token: UIEventSubscriptionToken) {
        lock.lock()
        let before = subscriptions.count
        subscriptions.removeAll { $0.token == token }
        let after = subscriptions.count
        lock.unlock()

        if before != after {
            logger.debug("已取消订阅（令牌方式），当前订阅数: \(after)")
        }
    }

    /// 取消指定动作的所有订阅
    /// - Parameter action: 动作名称
    public func offAll(for action: String) {
        lock.lock()
        let before = subscriptions.count
        subscriptions.removeAll { $0.action == action }
        let after = subscriptions.count
        lock.unlock()

        let removed = before - after
        if removed > 0 {
            logger.debug("已取消动作 '\(action)' 的 \(removed) 个订阅，当前订阅数: \(after)")
        }
    }

    // MARK: - 发送

    /// 发送消息，通知所有匹配的订阅者
    /// - Parameter message: 要发送的消息
    ///
    /// 如果 message.target 不为 nil，则仅通知订阅时指定了目标模块且匹配的 handler；
    /// 否则广播给所有匹配 action 的 handler。
    /// 回调在锁外执行，避免死锁。
    public func send(_ message: UIMessage) {
        var matchingHandlers: [Handler] = []

        lock.lock()
        for sub in subscriptions where sub.action == message.action {
            if let targetModuleName = message.target {
                // 定向发送：订阅时指定的目标模块必须匹配
                if sub.targetModule == targetModuleName {
                    matchingHandlers.append(sub.handler)
                }
            } else {
                // 广播：通知所有匹配 action 的订阅者
                matchingHandlers.append(sub.handler)
            }
        }
        lock.unlock()

        // 锁外执行回调，避免死锁
        for handler in matchingHandlers {
            handler(message)
        }

        if matchingHandlers.isEmpty {
            logger.debug("事件 '\(message.action)' 无订阅者")
        }
    }

    // MARK: - 清除

    /// 清除所有订阅
    public func clear() {
        lock.lock()
        subscriptions.removeAll()
        lock.unlock()

        logger.info("已清除所有订阅")
    }

    // MARK: - 查询

    /// 当前活跃订阅数
    public var subscriptionCount: Int {
        lock.lock()
        let count = subscriptions.count
        lock.unlock()
        return count
    }
}

// MARK: - 迁回自 UI-02：struct UIEventSubscriptionToken
// MARK: - 迁移自 UI-17_全局事件总线.swift：UIEventSubscriptionToken
public struct UIEventSubscriptionToken: Hashable, Sendable {
    private let id: UUID
    internal init() {
        self.id = UUID()
    }
}

// MARK: - 迁回自 UI-02：struct UIMessage
// MARK: - 迁移自 UI-17_全局事件总线.swift：UIGlobalEventBus
// 已迁回 UI-17_全局事件总线.swift：class UIGlobalEventBus（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-17_全局事件总线.swift：UIMessage
public struct UIMessage: Codable {
    /// 发送者模块名
    public let sender: String
    /// 目标模块（nil表示广播）
    public let target: String?
    /// 动作名称
    public let action: String
    /// 参数字典
    public let payload: [String: String]

    public init(sender: String, target: String? = nil, action: String, payload: [String: String] = [:]) {
        self.sender = sender
        self.target = target
        self.action = action
        self.payload = payload
    }
}

// MARK: - UI模块热替换通知名
public extension Notification.Name {
    static let UIModuleHotReplaced = Notification.Name("com.xianrenzhilu.registry.UIModuleHotReplaced")
}
// MARK: - UI模块运行通知名补齐
public extension Notification.Name {
    static let UIModuleDidLoad = Notification.Name("com.xianrenzhilu.registry.UIModuleDidLoad")
    static let UIModuleDidUnload = Notification.Name("com.xianrenzhilu.registry.UIModuleDidUnload")
    static let UIModuleDidRollback = Notification.Name("com.xianrenzhilu.registry.UIModuleDidRollback")
    static let UIModuleLoadFailed = Notification.Name("com.xianrenzhilu.registry.UIModuleLoadFailed")
    static let UIModuleErrorAggregated = Notification.Name("com.xianrenzhilu.registry.UIModuleErrorAggregated")
}
// MARK: - UI窗口注册通知名
public extension Notification.Name {
    static let windowDidRegister = Notification.Name("com.xianrenzhilu.registry.windowDidRegister")
    static let windowWillClose = Notification.Name("com.xianrenzhilu.registry.windowWillClose")
    static let windowDidUnregister = Notification.Name("com.xianrenzhilu.registry.windowDidUnregister")
}
// MARK: - UI模块扫描通知名
public extension Notification.Name {
    static let uiModuleScanCompleted = Notification.Name("com.xianrenzhilu.registry.uiModuleScanCompleted")
    static let uiModuleBlacklistChanged = Notification.Name("com.xianrenzhilu.registry.uiModuleBlacklistChanged")
}
