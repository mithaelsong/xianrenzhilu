// 功能33A: 布局管理器
// 对应: 视图布局管理器，水平/垂直/网格/层叠/对齐布局容器，响应式布局，布局快照恢复
// 优先级: P1
// 版本: 2.0

import AppKit
import Foundation
import os.log

// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 测试代码
#if false // DEBUG tests disabled in App target

/// 功能33A：布局管理器 — 单元测试
/// 覆盖：容器注册/视图绑定/布局执行/快照/持久化
func test_layoutManager() {
    let manager = UILayoutManager.shared
    var allPassed = true

    logger.info("测试1: 注册容器")
    var container = UILayoutContainer(type: .horizontal, name: "测试容器")
    container.spacing = 8
    let registered = manager.registerContainer(container)
    if !registered {
        logger.error("❌ 测试1失败: 注册应成功")
        allPassed = false
    } else {
        logger.info("✅ 测试1通过: 容器注册成功")
    }

    logger.info("测试2: 查询容器")
    let fetched = manager.container(by: container.id)
    if fetched?.name != "测试容器" {
        logger.error("❌ 测试2失败: 容器查询不匹配")
        allPassed = false
    } else {
        logger.info("✅ 测试2通过: 容器查询正常")
    }

    logger.info("测试3: 容器摘要列表")
    let summary = manager.containerSummaryList()
    if summary.isEmpty {
        logger.error("❌ 测试3失败: 摘要列表不应为空")
        allPassed = false
    } else {
        logger.info("✅ 测试3通过: 容器摘要正常")
    }

    logger.info("测试4: 快照管理")
    let snap = manager.saveSnapshot(name: "测试快照")
    if snap.id.isEmpty {
        logger.error("❌ 测试4失败: 快照保存失败")
        allPassed = false
    } else {
        let allSnaps = manager.allSnapshots
        if allSnaps.isEmpty {
            logger.error("❌ 测试4失败: 快照列表不应为空")
            allPassed = false
        } else {
            logger.info("✅ 测试4通过: 快照管理正常")
        }
    }

    logger.info("测试5: 删除快照")
    let deleted = manager.deleteSnapshot(id: snap.id)
    if !deleted {
        logger.error("❌ 测试5失败: 快照删除失败")
        allPassed = false
    } else {
        logger.info("✅ 测试5通过: 快照删除成功")
    }

    logger.info("测试6: 约束工厂")
    let v1 = NSView()
    let v2 = NSView()
    let fillConstraints = UILayoutManager.makeFillConstraints(subview: v1, parentView: v2, insets: .all(10))
    if fillConstraints.count != 4 {
        logger.error("❌ 测试6失败: 应有4个约束")
        allPassed = false
    } else {
        logger.info("✅ 测试6通过: 约束工厂正常")
    }

    logger.info("测试7: 容器类型过滤")
    let horizontals = manager.containers(of: .horizontal)
    if horizontals.count < 1 {
        logger.error("❌ 测试7失败: 应有水平容器")
        allPassed = false
    } else {
        logger.info("✅ 测试7通过: 容器过滤正常")
    }

    logger.info("测试8: 更新容器")
    let updated = manager.updateContainer(id: container.id) { c in
        c.name = "已更新"
    }
    if !updated || manager.container(by: container.id)?.name != "已更新" {
        logger.error("❌ 测试8失败: 容器更新失败")
        allPassed = false
    } else {
        logger.info("✅ 测试8通过: 容器更新成功")
    }

    if allPassed {
        logger.info("=== 全部布局管理器测试通过 ✅ ===")
    } else {
        logger.error("=== 部分布局管理器测试失败 ❌ ===")
    }
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UILayoutManager
public final class UILayoutManager : @unchecked Sendable {
    public static let shared = UILayoutManager()

    private let lock = NSRecursiveLock()
    private var containers: [String: UILayoutContainer] = [:]
    private var snapshots: [UILayoutSnapshot] = []
    private var layoutViews: NSMapTable<NSString, NSView> = NSMapTable.strongToWeakObjects()
    private var currentConstraints: [NSLayoutConstraint] = []
    private var isAnimating: Bool = false
    private var resizeTimer: Timer?
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "布局管理器")

    private let udKeySnapshots = "com.xianrenzhilu.layoutSnapshots"
    private let udKeyContainers = "com.xianrenzhilu.layoutContainers"

    public var allContainers: [UILayoutContainer] {
        lock.lock()
        let list = Array(containers.values).sorted { $0.id < $1.id }
        lock.unlock()
        return list
    }

    public var allSnapshots: [UILayoutSnapshot] {
        lock.lock()
        let list = snapshots.sorted { $0.createdAt > $1.createdAt }
        lock.unlock()
        return list
    }

    public var currentlyAnimating: Bool {
        lock.lock()
        let animating = isAnimating
        lock.unlock()
        return animating
    }

    public var activeContainerCount: Int {
        lock.lock()
        let count = containers.count
        lock.unlock()
        return count
    }

    private init() {
        logger.info("布局管理器已初始化")
        loadPersistentData()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidResize),
            name: NSWindow.didResizeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        resizeTimer?.invalidate()
        removeAllConstraints()
        logger.info("布局管理器已释放")
    }

    @discardableResult
    public func registerContainer(_ container: UILayoutContainer) -> Bool {
        lock.lock()
        containers[container.id] = container
        lock.unlock()
        saveContainers()
        logger.info("已注册布局容器: \(container.name) (\(container.type.rawValue))")
        return true
    }

    @discardableResult
    public func unregisterContainer(id: String) -> Bool {
        lock.lock()
        guard containers.removeValue(forKey: id) != nil else {
            lock.unlock()
            logger.warning("移除容器失败: 未找到 \(id)")
            return false
        }
        lock.unlock()
        saveContainers()
        logger.info("已移除布局容器: \(id)")
        return true
    }

    public func container(by id: String) -> UILayoutContainer? {
        lock.lock()
        let container = containers[id]
        lock.unlock()
        return container
    }

    @discardableResult
    public func updateContainer(id: String, updater: (inout UILayoutContainer) -> Void) -> Bool {
        lock.lock()
        guard var container = containers[id] else {
            lock.unlock()
            return false
        }
        updater(&container)
        containers[id] = container
        lock.unlock()
        saveContainers()
        logger.info("已更新布局容器: \(id)")
        return true
    }

    public func containers(of type: UILayoutContainerType) -> [UILayoutContainer] {
        lock.lock()
        let list = containers.values.filter { $0.type == type }
        lock.unlock()
        return Array(list)
    }

    public func bindView(_ view: NSView, to containerID: String) {
        layoutViews.setObject(view, forKey: containerID as NSString)
    }

    public func unbindView(for containerID: String) {
        layoutViews.removeObject(forKey: containerID as NSString)
    }

    public func view(for containerID: String) -> NSView? {
        layoutViews.object(forKey: containerID as NSString)
    }

    public func performLayout(for containerID: String) {
        lock.lock()
        guard let container = containers[containerID] else {
            lock.unlock()
            logger.warning("布局执行失败: 未找到容器 \(containerID)")
            return
        }
        lock.unlock()

        guard let view = self.view(for: containerID) else {
            logger.warning("布局执行失败: 未绑定视图到容器 \(containerID)")
            return
        }

        applyLayout(container: container, to: view, animated: container.animationDuration > 0)
    }

    public func performAllLayouts() {
        let all = allContainers
        for container in all {
            performLayout(for: container.id)
        }
    }

    private func applyLayout(container: UILayoutContainer, to parentView: NSView, animated: Bool) {
        removeConstraints(for: parentView)

        guard let subview = parentView.subviews.first else {
            logger.warning("容器 \(container.name) 无子视图")
            return
        }

        var newConstraints: [NSLayoutConstraint] = []

        subview.translatesAutoresizingMaskIntoConstraints = false

        switch container.type {
        case .horizontal:
            newConstraints = buildHorizontalConstraints(container: container, parentView: parentView, subview: subview)
        case .vertical:
            newConstraints = buildVerticalConstraints(container: container, parentView: parentView, subview: subview)
        case .grid:
            newConstraints = buildGridConstraints(container: container, parentView: parentView, subview: subview)
        case .overlay:
            newConstraints = buildOverlayConstraints(container: container, parentView: parentView, subview: subview)
        case .alignment:
            newConstraints = buildAlignmentConstraints(container: container, parentView: parentView, subview: subview)
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = container.animationDuration
                context.timingFunction = container.animationCurve.mediaTimingFunction
                NSLayoutConstraint.activate(newConstraints)
                parentView.layoutSubtreeIfNeeded()
            }
        } else {
            NSLayoutConstraint.activate(newConstraints)
        }

        lock.lock()
        currentConstraints.append(contentsOf: newConstraints)
        lock.unlock()
    }

    private func buildHorizontalConstraints(container: UILayoutContainer, parentView: NSView, subview: NSView) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        let p = container.padding

        constraints.append(subview.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: p.left))
        constraints.append(subview.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -p.right))
        constraints.append(subview.topAnchor.constraint(equalTo: parentView.topAnchor, constant: p.top))
        constraints.append(subview.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -p.bottom))

        switch container.alignment {
        case .start:
            constraints.append(subview.topAnchor.constraint(equalTo: parentView.topAnchor, constant: p.top))
        case .center:
            constraints.append(subview.centerYAnchor.constraint(equalTo: parentView.centerYAnchor))
        case .end:
            constraints.append(subview.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -p.bottom))
        case .fill:
            constraints.append(subview.topAnchor.constraint(equalTo: parentView.topAnchor, constant: p.top))
            constraints.append(subview.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -p.bottom))
        }

        return constraints
    }

    private func buildVerticalConstraints(container: UILayoutContainer, parentView: NSView, subview: NSView) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        let p = container.padding

        constraints.append(subview.topAnchor.constraint(equalTo: parentView.topAnchor, constant: p.top))
        constraints.append(subview.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -p.bottom))
        constraints.append(subview.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: p.left))
        constraints.append(subview.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -p.right))

        switch container.alignment {
        case .start:
            constraints.append(subview.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: p.left))
        case .center:
            constraints.append(subview.centerXAnchor.constraint(equalTo: parentView.centerXAnchor))
        case .end:
            constraints.append(subview.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -p.right))
        case .fill:
            constraints.append(subview.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: p.left))
            constraints.append(subview.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -p.right))
        }

        return constraints
    }

    private func buildGridConstraints(container: UILayoutContainer, parentView: NSView, subview: NSView) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        let p = container.padding

        constraints.append(subview.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: p.left))
        constraints.append(subview.topAnchor.constraint(equalTo: parentView.topAnchor, constant: p.top))
        constraints.append(subview.trailingAnchor.constraint(lessThanOrEqualTo: parentView.trailingAnchor, constant: -p.right))
        constraints.append(subview.bottomAnchor.constraint(lessThanOrEqualTo: parentView.bottomAnchor, constant: -p.bottom))

        return constraints
    }

    private func buildOverlayConstraints(container: UILayoutContainer, parentView: NSView, subview: NSView) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        let p = container.padding

        constraints.append(subview.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: p.left))
        constraints.append(subview.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -p.right))
        constraints.append(subview.topAnchor.constraint(equalTo: parentView.topAnchor, constant: p.top))
        constraints.append(subview.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -p.bottom))

        return constraints
    }

    private func buildAlignmentConstraints(container: UILayoutContainer, parentView: NSView, subview: NSView) -> [NSLayoutConstraint] {
        return buildHorizontalConstraints(container: container, parentView: parentView, subview: subview)
    }

    private func removeConstraints(for view: NSView) {
        let toRemove: [NSLayoutConstraint]
        lock.lock()
        toRemove = currentConstraints.filter { $0.firstItem as? NSView == view || $0.secondItem as? NSView == view }
        currentConstraints.removeAll { toRemove.contains($0) }
        lock.unlock()
        NSLayoutConstraint.deactivate(toRemove)
    }

    private func removeAllConstraints() {
        lock.lock()
        let all = currentConstraints
        currentConstraints.removeAll()
        lock.unlock()
        NSLayoutConstraint.deactivate(all)
    }

    @objc private func handleWindowDidResize(_ notification: Notification) {
        resizeTimer?.invalidate()
        resizeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.performResponsiveLayout()
            NotificationCenter.default.post(name: .layoutWindowDidResize, object: self)
        }
    }

    private func performResponsiveLayout() {
        let all = allContainers
        for container in all where container.isResponsive {
            performLayout(for: container.id)
        }
    }

    @discardableResult
    public func saveSnapshot(name: String, description: String = "", isAuto: Bool = false) -> UILayoutSnapshot {
        let containers = allContainers
        let snapshot = UILayoutSnapshot(
            name: name,
            containers: containers,
            description: description,
            isAutoSnapshot: isAuto
        )

        lock.lock()
        snapshots.append(snapshot)
        if snapshots.count > 20 {
            snapshots.sort { $0.createdAt > $1.createdAt }
            snapshots = Array(snapshots.prefix(20))
        }
        lock.unlock()

        saveSnapshots()

        NotificationCenter.default.post(name: .layoutSnapshotDidSave, object: self, userInfo: [
            "snapshotID": snapshot.id,
            "snapshotName": snapshot.name,
            "containerCount": containers.count
        ])
        logger.info("布局快照已保存: \(name) (\(containers.count) 个容器)")
        return snapshot
    }

    public func autoSaveSnapshot() {
        _ = saveSnapshot(name: "自动快照 \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))", isAuto: true)
    }

    @discardableResult
    public func restoreSnapshot(id snapshotID: String) -> Bool {
        lock.lock()
        guard let snapshot = snapshots.first(where: { $0.id == snapshotID }) else {
            lock.unlock()
            return false
        }
        let containersToRestore = snapshot.containers
        lock.unlock()

        for container in containersToRestore {
            registerContainer(container)
        }

        performAllLayouts()

        NotificationCenter.default.post(name: .layoutSnapshotDidRestore, object: self, userInfo: [
            "snapshotID": snapshot.id,
            "snapshotName": snapshot.name,
            "containerCount": containersToRestore.count
        ])
        logger.info("布局快照已恢复: \(snapshot.name)")
        return true
    }

    @discardableResult
    public func deleteSnapshot(id: String) -> Bool {
        lock.lock()
        guard let index = snapshots.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return false
        }
        snapshots.remove(at: index)
        lock.unlock()
        saveSnapshots()
        logger.info("布局快照已删除: \(id)")
        return true
    }

    private func saveContainers() {
        let list = allContainers
        do {
            let data = try JSONEncoder().encode(list)
            UserDefaults.standard.set(data, forKey: udKeyContainers)
        } catch {
            logger.error("保存容器配置失败: \(error.localizedDescription)")
        }
    }

    private func saveSnapshots() {
        let list = allSnapshots
        do {
            let data = try JSONEncoder().encode(list)
            UserDefaults.standard.set(data, forKey: udKeySnapshots)
        } catch {
            logger.error("保存快照失败: \(error.localizedDescription)")
        }
    }

    private func loadPersistentData() {
        if let data = UserDefaults.standard.data(forKey: udKeyContainers) {
            do {
                let list = try JSONDecoder().decode([UILayoutContainer].self, from: data)
                lock.lock()
                for container in list {
                    containers[container.id] = container
                }
                lock.unlock()
                logger.info("已加载 \(list.count) 个布局容器")
            } catch {
                logger.error("加载容器配置失败: \(error.localizedDescription)")
            }
        } else {
            logger.debug("无持久化容器数据，使用默认空列表")
        }

        if let data = UserDefaults.standard.data(forKey: udKeySnapshots) {
            do {
                let list = try JSONDecoder().decode([UILayoutSnapshot].self, from: data)
                lock.lock()
                snapshots = list
                lock.unlock()
                logger.info("已加载 \(list.count) 个布局快照")
            } catch {
                logger.error("加载快照失败: \(error.localizedDescription)")
            }
        } else {
            logger.debug("无持久化快照数据，使用默认空列表")
        }
    }

    public func clearPersistentData() {
        UserDefaults.standard.removeObject(forKey: udKeyContainers)
        UserDefaults.standard.removeObject(forKey: udKeySnapshots)
        lock.lock()
        containers.removeAll()
        snapshots.removeAll()
        lock.unlock()
        removeAllConstraints()
        logger.warning("布局持久化数据已全部清除")
    }

    public static func makeFillConstraints(subview: NSView, parentView: NSView, insets: UILayoutEdgeInsets = .zero) -> [NSLayoutConstraint] {
        subview.translatesAutoresizingMaskIntoConstraints = false
        return [
            subview.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: insets.left),
            subview.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -insets.right),
            subview.topAnchor.constraint(equalTo: parentView.topAnchor, constant: insets.top),
            subview.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -insets.bottom)
        ]
    }

    public static func makeCenterConstraints(subview: NSView, parentView: NSView, offset: CGPoint = .zero) -> [NSLayoutConstraint] {
        subview.translatesAutoresizingMaskIntoConstraints = false
        return [
            subview.centerXAnchor.constraint(equalTo: parentView.centerXAnchor, constant: offset.x),
            subview.centerYAnchor.constraint(equalTo: parentView.centerYAnchor, constant: offset.y)
        ]
    }

    public static func makeEqualSizeConstraints(view1: NSView, view2: NSView, multiplier: CGFloat = 1.0) -> [NSLayoutConstraint] {
        view1.translatesAutoresizingMaskIntoConstraints = false
        return [
            view1.widthAnchor.constraint(equalTo: view2.widthAnchor, multiplier: multiplier),
            view1.heightAnchor.constraint(equalTo: view2.heightAnchor, multiplier: multiplier)
        ]
    }

    public static func makeSpacingConstraint(view1: NSView, view2: NSView, spacing: CGFloat, axis: NSLayoutConstraint.Orientation = .horizontal) -> NSLayoutConstraint {
        view1.translatesAutoresizingMaskIntoConstraints = false
        if axis == .horizontal {
            return view1.trailingAnchor.constraint(equalTo: view2.leadingAnchor, constant: -spacing)
        } else {
            return view1.bottomAnchor.constraint(equalTo: view2.topAnchor, constant: -spacing)
        }
    }

    public func containerSummaryList() -> [(id: String, name: String, type: String, itemCount: Int)] {
        lock.lock()
        let list = containers.values.map { container in
            (id: container.id, name: container.name, type: container.type.rawValue, itemCount: container.items.count)
        }
        lock.unlock()
        return Array(list).sorted { $0.id < $1.id }
    }

    public func snapshotSummaryList() -> [(id: String, name: String, containerCount: Int, isAuto: Bool, createdAt: TimeInterval)] {
        lock.lock()
        let list = snapshots.map { snap in
            (id: snap.id, name: snap.name, containerCount: snap.containers.count, isAuto: snap.isAutoSnapshot, createdAt: snap.createdAt)
        }
        lock.unlock()
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    public enum UIContainerSettingValue {
        case string(String)
        case float(CGFloat)
        case bool(Bool)
        case timeInterval(TimeInterval)
        case int(Int)
    }

    public func updateContainerSetting(containerID: String, key: String, value: UIContainerSettingValue) {
        updateContainer(id: containerID) { container in
            switch key {
            case "name":
                if case .string(let v) = value { container.name = v }
            case "spacing":
                if case .float(let v) = value { container.spacing = v }
            case "alignment":
                if case .string(let v) = value, let align = UILayoutAlignment(rawValue: v) { container.alignment = align }
            case "distribution":
                if case .string(let v) = value, let dist = UILayoutDistribution(rawValue: v) { container.distribution = dist }
            case "isResponsive":
                if case .bool(let v) = value { container.isResponsive = v }
            case "animationDuration":
                if case .timeInterval(let v) = value { container.animationDuration = v }
            case "gridColumns":
                if case .int(let v) = value { container.gridColumns = v }
            default:
                break
            }
        }
    }

    public func resetToDefault() {
        clearPersistentData()
        performAllLayouts()
        logger.info("布局已重置为默认状态")
    }

    public func exportSnapshotToJSON(id: String) -> String? {
        lock.lock()
        let snapshot = snapshots.first { $0.id == id }
        lock.unlock()

        guard let snap = snapshot else { return nil }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snap)
            return String(data: data, encoding: .utf8)
        } catch {
            logger.error("导出快照JSON失败: \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    public func importSnapshotFromJSON(_ jsonString: String) -> UILayoutSnapshot? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            let decoder = JSONDecoder()
            var snapshot = try decoder.decode(UILayoutSnapshot.self, from: data)
            snapshot.id = UUID().uuidString
            snapshot.name = snapshot.name + " (导入)"
            snapshot.createdAt = Date().timeIntervalSince1970
            _ = saveSnapshot(name: snapshot.name, description: snapshot.description, isAuto: false)
            logger.info("快照导入成功: \(snapshot.name)")
            return snapshot
        } catch {
            logger.error("导入快照JSON失败: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - 迁回自 UI-02：enum UILayoutDirection
// MARK: - UI-GL-41 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-41_types.swift
// 版本: 2.0
// MARK: - 布局方向
public enum UILayoutDirection: String, Codable, CaseIterable {
    case horizontal
    case vertical
}

// MARK: - 迁回自 UI-02：enum UILayoutAlignment
// MARK: - 插件管理器
/// 管理所有插件的完整生命周期：扫描、加载、卸载、启用/禁用、依赖解析、配置持久化
// 已迁回 UI-GL-39_插件管理器.swift：class UIPluginManager（公共类型文件禁止功能实现）

// MARK: - 插件市场默认实现占位
/// 插件市场接口的默认空实现，用于占位和测试
// 已迁回 UI-GL-39_插件管理器.swift：class UIDefaultPluginMarket（公共类型文件禁止功能实现）

// MARK: - 插件管理器扩展（便捷方法）
// 已迁回 UI-GL-39_插件管理器.swift：extension UIPluginManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-40 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-40_types.swift
// 版本: 2.0
// MARK: - 分割节点
/// 递归分割视图的节点
// 已迁回 UI-GL-40_嵌套分割视图.swift：class UISplitNode（公共类型文件禁止功能实现）

// MARK: - 嵌套分割视图
/// 支持无限层级的分割视图
// 已迁回 UI-GL-40_嵌套分割视图.swift：class UINestedSplitView（公共类型文件禁止功能实现）


// MARK: - UI-GL-41 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-41_types.swift
// 版本: 2.0
// MARK: - 布局对齐方式
public enum UILayoutAlignment: String, Codable, CaseIterable {
    case start
    case center
    case end
    case fill
}

// MARK: - 迁回自 UI-02：enum UILayoutDistribution
// MARK: - 布局分布模式
public enum UILayoutDistribution: String, Codable, CaseIterable {
    case equalSpacing
    case equalCenters
    case fill
    case fillProportionally
}

// MARK: - 迁回自 UI-02：enum UILayoutContainerType
// MARK: - 布局容器类型
public enum UILayoutContainerType: String, Codable, CaseIterable {
    case horizontal
    case vertical
    case grid
    case overlay
    case alignment
}

// MARK: - 迁回自 UI-02：struct UILayoutEdgeInsets
// MARK: - 布局边距
public struct UILayoutEdgeInsets: Codable, Equatable, Sendable {
    public var top: CGFloat
    public var left: CGFloat
    public var bottom: CGFloat
    public var right: CGFloat

    public static let zero = UILayoutEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    public static func all(_ value: CGFloat) -> UILayoutEdgeInsets {
        UILayoutEdgeInsets(top: value, left: value, bottom: value, right: value)
    }

    public static func symmetric(horizontal h: CGFloat = 0, vertical v: CGFloat = 0) -> UILayoutEdgeInsets {
        UILayoutEdgeInsets(top: v, left: h, bottom: v, right: h)
    }

    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutItemConfig
// MARK: - 布局项配置
public struct UILayoutItemConfig: Codable, Equatable {
    public var identifier: String
    public var width: CGFloat?
    public var height: CGFloat?
    public var minWidth: CGFloat?
    public var maxWidth: CGFloat?
    public var minHeight: CGFloat?
    public var maxHeight: CGFloat?
    public var compressionResistancePriority: Float
    public var huggingPriority: Float
    public var margin: UILayoutEdgeInsets
    public var isVisible: Bool
    public var weight: CGFloat
    public var zIndex: Int

    public init(identifier: String, width: CGFloat? = nil, height: CGFloat? = nil, margin: UILayoutEdgeInsets = .zero, isVisible: Bool = true, weight: CGFloat = 1.0, zIndex: Int = 0) {
        self.identifier = identifier
        self.width = width
        self.height = height
        self.minWidth = nil
        self.maxWidth = nil
        self.minHeight = nil
        self.maxHeight = nil
        self.compressionResistancePriority = 750
        self.huggingPriority = 250
        self.margin = margin
        self.isVisible = isVisible
        self.weight = weight
        self.zIndex = zIndex
    }
}

// MARK: - 迁回自 UI-02：enum UILayoutAnimationCurve
// MARK: - 布局动画曲线
public enum UILayoutAnimationCurve: String, Codable, CaseIterable {
    case linear
    case easeInEaseOut
    case easeInOut
    case easeIn
    case easeOut
    case spring

    public var mediaTimingFunction: CAMediaTimingFunction {
        switch self {
        case .linear: return CAMediaTimingFunction(name: .linear)
        case .easeInEaseOut: return CAMediaTimingFunction(name: .easeInEaseOut)
        case .easeInOut: return CAMediaTimingFunction(name: .default)
        case .easeIn: return CAMediaTimingFunction(name: .easeIn)
        case .easeOut: return CAMediaTimingFunction(name: .easeOut)
        case .spring: return CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
        }
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutContainer
// MARK: - 布局容器模型
public struct UILayoutContainer: Codable, Equatable, Identifiable {
    public var id: String
    public var type: UILayoutContainerType
    public var name: String
    public var direction: UILayoutDirection
    public var alignment: UILayoutAlignment
    public var distribution: UILayoutDistribution
    public var spacing: CGFloat
    public var padding: UILayoutEdgeInsets
    public var items: [UILayoutItemConfig]
    public var gridColumns: Int
    public var gridRowHeight: CGFloat?
    public var isResponsive: Bool
    public var minContainerWidth: CGFloat
    public var minContainerHeight: CGFloat
    public var animationDuration: TimeInterval
    public var animationCurve: UILayoutAnimationCurve

    public init(id: String = UUID().uuidString, type: UILayoutContainerType, name: String = "", direction: UILayoutDirection = .horizontal, alignment: UILayoutAlignment = .center, distribution: UILayoutDistribution = .equalSpacing, spacing: CGFloat = 8, padding: UILayoutEdgeInsets = .all(12)) {
        self.id = id
        self.type = type
        self.name = name
        self.direction = direction
        self.alignment = alignment
        self.distribution = distribution
        self.spacing = spacing
        self.padding = padding
        self.items = []
        self.gridColumns = 2
        self.gridRowHeight = nil
        self.isResponsive = true
        self.minContainerWidth = 100
        self.minContainerHeight = 50
        self.animationDuration = 0.25
        self.animationCurve = .easeInOut
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutSnapshot
// MARK: - 布局快照
public struct UILayoutSnapshot: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var createdAt: TimeInterval
    public var containers: [UILayoutContainer]
    public var description: String
    public var isAutoSnapshot: Bool

    public init(id: String = UUID().uuidString, name: String, containers: [UILayoutContainer], description: String = "", isAutoSnapshot: Bool = false) {
        self.id = id
        self.name = name
        self.createdAt = Date().timeIntervalSince1970
        self.containers = containers
        self.description = description
        self.isAutoSnapshot = isAutoSnapshot
    }
}
