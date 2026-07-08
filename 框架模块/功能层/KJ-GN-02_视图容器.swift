// 功能17: 视图容器（NSView 空槽设计）
// 对应: 提供标准空槽(center/left/right/top/bottom)，模块按优先级注册视图
// 优先级: P1

import AppKit
import os


// ModuleLogger 定义在 KJ-GL-02_公共类型定义.swift
// EventBus 定义在 KJ-GL-02_公共类型定义.swift
// KJViewSlot, KJSlotEntry 定义在 KJ-GL-02_公共类型定义.swift

// MARK: - 内部注册记录
/// 视图注册记录（内部使用）
private struct KJViewRegistration {
    let token: String
    let view: NSView
    let slot: KJViewSlot
    let moduleName: String
    let priority: Int
}

// MARK: - 视图容器
/// 视图容器管理器 (功能17)
/// 单例管理各模块在主窗口中的视图挂载
/// 每个槽位支持多模块注册，按 priority 降序排列
/// 线程安全：所有操作均受 os_unfair_lock 保护
public final class KJViewContainer : @unchecked Sendable {
    public static let shared = KJViewContainer()

    /// token -> KJViewRegistration
    private var registrations: [String: KJViewRegistration] = [:]
    /// slot -> [KJViewRegistration]（已按 priority 降序排列）
    private var slotRegistrations: [KJViewSlot: [KJViewRegistration]] = [:]
    /// moduleName -> Set<token>
    private var moduleTokens: [String: Set<String>] = [:]
    private var lock = os_unfair_lock()
    private let logger = KJModuleLogger.shared

    private init() {}

    // MARK: - 注册视图

    /// 将视图注册到指定槽位
    /// - Parameters:
    ///   - view: 要注册的 NSView
    ///   - slot: 目标槽位
    ///   - moduleName: 模块名称
    ///   - priority: 优先级（越大越靠前，同一槽位按降序排列）
    /// - Returns: 唯一 token，用于后续注销
    @discardableResult
    public func register(view: NSView, slot: KJViewSlot, moduleName: String, priority: Int = 0) -> String {
        let token = UUID().uuidString

        os_unfair_lock_lock(&lock)

        let registration = KJViewRegistration(
            token: token,
            view: view,
            slot: slot,
            moduleName: moduleName,
            priority: priority
        )
        registrations[token] = registration
        moduleTokens[moduleName, default: []].insert(token)

        var slotRegs = slotRegistrations[slot, default: []]
        slotRegs.append(registration)
        slotRegs.sort { $0.priority > $1.priority }
        slotRegistrations[slot] = slotRegs

        os_unfair_lock_unlock(&lock)

        logger.info("KJViewContainer", "已注册视图: 槽位 '\(slot)' 模块'\(moduleName)' 优先级\(priority) token \(token)")

        // EventBus.shared.emit(...) // removed for compilation

        return token
    }

    // MARK: - 注销视图

    /// 通过 token 注销单个视图
    /// - Parameter token: 注册时返回的 token
    /// - Returns: 是否成功注销
    @discardableResult
    public func unregister(token: String) -> Bool {
        os_unfair_lock_lock(&lock)
        guard let registration = registrations.removeValue(forKey: token) else {
            os_unfair_lock_unlock(&lock)
            return false
        }

        moduleTokens[registration.moduleName]?.remove(token)
        if moduleTokens[registration.moduleName]?.isEmpty == true {
            moduleTokens.removeValue(forKey: registration.moduleName)
        }

        if var slotRegs = slotRegistrations[registration.slot] {
            slotRegs.removeAll { $0.token == token }
            slotRegistrations[registration.slot] = slotRegs.isEmpty ? nil : slotRegs
        }

        os_unfair_lock_unlock(&lock)

        registration.view.removeFromSuperview()

        logger.info("KJViewContainer", "已注销视图 token \(token)")

        // EventBus.shared.emit(...) // removed for compilation

        return true
    }

    /// 注销指定模块的所有视图
    /// - Parameter moduleName: 模块名称
    /// - Returns: 实际注销的视图数量
    @discardableResult
    public func unregisterAll(moduleName: String) -> Int {
        os_unfair_lock_lock(&lock)
        let tokens = moduleTokens.removeValue(forKey: moduleName) ?? []
        var removedRegistrations: [KJViewRegistration] = []

        for token in tokens {
            if let reg = registrations.removeValue(forKey: token) {
                removedRegistrations.append(reg)
                if var slotRegs = slotRegistrations[reg.slot] {
                    slotRegs.removeAll { $0.token == token }
                    slotRegistrations[reg.slot] = slotRegs.isEmpty ? nil : slotRegs
                }
            }
        }
        os_unfair_lock_unlock(&lock)

        for reg in removedRegistrations {
            reg.view.removeFromSuperview()
        }

        logger.info("KJViewContainer", "已注销模块所有视图 '\(moduleName)' (count: \(removedRegistrations.count))")

        // EventBus.shared.emit(...) // removed for compilation

        return removedRegistrations.count
    }

    // MARK: - 查询

    /// 获取指定槽位优先级最高的视图
    /// - Parameter slot: 目标槽位
    /// - Returns: 优先级最高的视图，若未注册则返回 nil
    public func view(for slot: KJViewSlot) -> NSView? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return slotRegistrations[slot]?.first?.view
    }

    /// 获取指定槽位的所有视图（按 priority 降序）
    /// - Parameter slot: 目标槽位
    /// - Returns: 视图数组
    public func views(for slot: KJViewSlot) -> [NSView] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return slotRegistrations[slot]?.map(\.view) ?? []
    }

    /// 获取指定槽位的所有注册信息（按 priority 降序）
    /// - Parameter slot: 目标槽位
    /// - Returns: (token, view, moduleName, priority) 数组
    public func registrations(for slot: KJViewSlot) -> [(token: String, view: NSView, moduleName: String, priority: Int)] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return slotRegistrations[slot]?.map { ($0.token, $0.view, $0.moduleName, $0.priority) } ?? []
    }

    /// 获取指定槽位的所有条目（按 priority 降序）
    /// - Parameter slot: 目标槽位
    /// - Returns: KJSlotEntry 数组
    public func entries(for slot: KJViewSlot) -> [KJSlotEntry] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return slotRegistrations[slot]?.map { KJSlotEntry(moduleName: $0.moduleName, view: $0.view, priority: $0.priority) } ?? []
    }

    /// 查询指定槽位是否已注册视图
    /// - Parameter slot: 目标槽位
    /// - Returns: 是否已注册
    public func isRegistered(_ slot: KJViewSlot) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return !(slotRegistrations[slot]?.isEmpty ?? true)
    }

    /// 获取所有已注册槽位列表
    /// - Returns: 已注册槽位数组
    public func registeredSlots() -> [KJViewSlot] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return slotRegistrations.compactMap { $0.value.isEmpty ? nil : $0.key }
    }

    /// 获取指定槽位已注册的所有模块名（按 priority 降序）
    /// - Parameter slot: 目标槽位
    /// - Returns: 模块名数组
    public func modules(for slot: KJViewSlot) -> [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return slotRegistrations[slot]?.map(\.moduleName) ?? []
    }

    /// 获取指定模块已注册的所有槽位
    /// - Parameter moduleName: 模块名称
    /// - Returns: 槽位数组
    public func slots(for moduleName: String) -> [KJViewSlot] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard let tokens = moduleTokens[moduleName] else { return [] }
        var result: [KJViewSlot] = []
        for token in tokens {
            if let slot = registrations[token]?.slot, !result.contains(slot) {
                result.append(slot)
            }
        }
        return result
    }

    /// 通过 token 查询注册信息
    /// - Parameter token: 注册 token
    /// - Returns: (slot, view, moduleName, priority)
    public func registration(for token: String) -> (slot: KJViewSlot, view: NSView, moduleName: String, priority: Int)? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard let reg = registrations[token] else { return nil }
        return (reg.slot, reg.view, reg.moduleName, reg.priority)
    }

    /// 查询指定模块在指定槽位是否已注册视图
    /// - Parameters:
    ///   - moduleName: 模块名称
    ///   - slot: 目标槽位
    /// - Returns: 是否已注册
    public func isModuleRegistered(_ moduleName: String, for slot: KJViewSlot) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return slotRegistrations[slot]?.contains(where: { $0.moduleName == moduleName }) ?? false
    }

    // MARK: - 构建容器层级

    /// 为指定槽位构建容器层级
    /// 将同一槽位内所有已注册视图按 priority 降序垂直堆叠
    /// - Parameter slot: 目标槽位
    /// - Returns: 根容器 NSView，若槽位未注册任何视图则返回 nil
    public func buildContainerHierarchy(for slot: KJViewSlot) -> NSView? {
        os_unfair_lock_lock(&lock)
        let slotRegs = slotRegistrations[slot] ?? []
        os_unfair_lock_unlock(&lock)

        guard !slotRegs.isEmpty else { return nil }

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.identifier = NSUserInterfaceItemIdentifier("KJViewContainer.slot.\(slot.rawValue)")

        let views = slotRegs.map(\.view)
        for v in views {
            v.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(v)
        }

        var constraints: [NSLayoutConstraint] = []

        for (index, v) in views.enumerated() {
            constraints.append(v.leadingAnchor.constraint(equalTo: container.leadingAnchor))
            constraints.append(v.trailingAnchor.constraint(equalTo: container.trailingAnchor))

            if index == 0 {
                constraints.append(v.topAnchor.constraint(equalTo: container.topAnchor))
            } else {
                constraints.append(v.topAnchor.constraint(equalTo: views[index - 1].bottomAnchor))
            }

            if index == views.count - 1 {
                constraints.append(v.bottomAnchor.constraint(equalTo: container.bottomAnchor))
            }
        }

        NSLayoutConstraint.activate(constraints)

        logger.info("KJViewContainer", "已构建槽位'\(slot)'的容器层次，共\(views.count)个视图")

        return container
    }

    /// 为指定模块构建完整的容器层级
    /// 标准布局如下：
    /// ```
    /// +------------------------------------------+
    /// |                   top                     |
    /// +-----------+----------------------+---------+
    /// |   left    |       center         |  right  |
    /// +-----------+----------------------+---------+
    /// |                  bottom                   |
    /// +------------------------------------------+
    /// ```
    /// 若模块未注册某槽位，相邻槽位自动扩展填充其空间
    /// - Parameter moduleName: 模块名称
    /// - Returns: 根容器 NSView，若模块未注册任何视图则返回 nil
    public func buildContainerHierarchy(for moduleName: String) -> NSView? {
        os_unfair_lock_lock(&lock)
        guard let tokens = moduleTokens[moduleName], !tokens.isEmpty else {
            os_unfair_lock_unlock(&lock)
            return nil
        }
        var moduleRegs: [KJViewSlot: KJViewRegistration] = [:]
        for token in tokens {
            if let reg = registrations[token] {
                // 同一模块在同一槽位若有多个注册，取优先级最高的
                if let existing = moduleRegs[reg.slot] {
                    if reg.priority > existing.priority {
                        moduleRegs[reg.slot] = reg
                    }
                } else {
                    moduleRegs[reg.slot] = reg
                }
            }
        }
        os_unfair_lock_unlock(&lock)

        guard !moduleRegs.isEmpty else { return nil }

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.identifier = NSUserInterfaceItemIdentifier("KJViewContainer.\(moduleName)")

        let topView    = moduleRegs[.top]?.view
        let bottomView = moduleRegs[.bottom]?.view
        let leftView   = moduleRegs[.left]?.view
        let rightView  = moduleRegs[.right]?.view
        let centerView = moduleRegs[.center]?.view

        // 添加子视图
        [topView, bottomView, leftView, rightView, centerView].compactMap { $0 }.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }

        var constraints: [NSLayoutConstraint] = []

        // top
        let topAnchor: NSLayoutYAxisAnchor
        if let top = topView {
            constraints += [
                top.topAnchor.constraint(equalTo: container.topAnchor),
                top.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                top.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ]
            topAnchor = top.bottomAnchor
        } else {
            topAnchor = container.topAnchor
        }

        // bottom
        let bottomAnchor: NSLayoutYAxisAnchor
        if let bottom = bottomView {
            constraints += [
                bottom.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                bottom.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                bottom.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ]
            bottomAnchor = bottom.topAnchor
        } else {
            bottomAnchor = container.bottomAnchor
        }

        // left
        let leadingAnchor: NSLayoutXAxisAnchor
        if let left = leftView {
            constraints += [
                left.topAnchor.constraint(equalTo: topAnchor),
                left.bottomAnchor.constraint(equalTo: bottomAnchor),
                left.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            ]
            leadingAnchor = left.trailingAnchor
        } else {
            leadingAnchor = container.leadingAnchor
        }

        // right
        let trailingAnchor: NSLayoutXAxisAnchor
        if let right = rightView {
            constraints += [
                right.topAnchor.constraint(equalTo: topAnchor),
                right.bottomAnchor.constraint(equalTo: bottomAnchor),
                right.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ]
            trailingAnchor = right.leadingAnchor
        } else {
            trailingAnchor = container.trailingAnchor
        }

        // center
        if let center = centerView {
            constraints += [
                center.topAnchor.constraint(equalTo: topAnchor),
                center.bottomAnchor.constraint(equalTo: bottomAnchor),
                center.leadingAnchor.constraint(equalTo: leadingAnchor),
                center.trailingAnchor.constraint(equalTo: trailingAnchor),
            ]
        }

        NSLayoutConstraint.activate(constraints)

        logger.info("KJViewContainer", "已构建模块容器层次 '\(moduleName)' 共\(moduleRegs.count)个槽位")

        return container
    }
}

// MARK: - 模块导航控制器
/// 模块导航控制器
/// 保留与视图容器的导航集成能力
public final class KJModuleNavigationController : @unchecked Sendable {
    public static let shared = KJModuleNavigationController()

    private var currentModule: String?

    private init() {}

    /// 导航到指定模块，激活其在视图容器中的视图层级
    /// - Parameter moduleName: 目标模块名称
    public func navigate(to moduleName: String) {
        currentModule = moduleName
        _ = KJViewContainer.shared.buildContainerHierarchy(for: moduleName)
        // EventBus.shared.emit(...) // removed for compilation
    }

    /// 当前导航到的模块名
    public var currentModuleName: String? {
        return currentModule
    }

    /// 重置导航状态
    public func reset() {
        currentModule = nil
        // EventBus.shared.emit(...) // removed for compilation
    }
}

// MARK: - 通知扩展
public extension Notification.Name {
    /// 视图槽位变更通知
    static let viewSlotChanged = Notification.Name("com.xianrenzhilu.viewContainer.slotChanged")
    /// 模块导航变更通知
    static let moduleNavigationChanged = Notification.Name("com.xianrenzhilu.moduleNavigation.changed")
}
