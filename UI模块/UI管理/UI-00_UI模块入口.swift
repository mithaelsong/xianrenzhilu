// MARK: - UI-00: UI模块管理入口
// 功能编号: UI-00
// 版本: 2.0
// 职责: 统一管理UI模块生命周期（扫描→排序→启动→卸载→回滚），并对接70个UI功能统一注册入口
// 依赖: UI-01统一注册表、UI-02公共类型，以及UI-GL-01～70功能文件
// 使用:
//   let entry = UIModuleEntry.shared
//   try entry.start()
//   entry.stop(immediate: true)   // 紧急停止
//   entry.stop(immediate: false)  // 优雅停止（默认）
//   entry.rescanAndLoad()          // 不停机重新扫描+加载新模块
//   entry.healthReport()           // 查看健康状态

import Foundation
import AppKit

// MARK: - 全局快捷函数
// 注: 全局函数已定义在 UI-08 中 (getUIModule / isUIModuleLoaded)，此处不复定义

// MARK: - 入口管理器
// MARK: - 入口薄封装
// UIModuleEntry 类型定义已迁移到 UI-02_公共类型定义.swift。
// 本文件只保留入口调用函数，不再定义任何 class/struct/enum/protocol。

public let uiModuleEntry = UIModuleEntry.shared

@discardableResult
public func registerUIFunctionFeaturesAtEntry() -> Int {
    return registerAllUIFunctionFeatures()
}

public func registeredUIFunctionIDsAtEntry() -> [String] {
    return registeredUIFunctionFeatureIDs()
}

@MainActor
public func startUIModuleSystem(context: [String: Any]? = nil) throws {
    try UIModuleEntry.shared.start(context: context)
    let registeredCount = registerUIFunctionFeaturesAtEntry()
    guard registeredCount >= 70 else {
        throw NSError(domain: "UI-00", code: 7001, userInfo: [NSLocalizedDescriptionKey: "UI功能注册不完整：当前注册 \(registeredCount)/70"])
    }
}

public func stopUIModuleSystem(immediate: Bool = false) {
    UIModuleEntry.shared.stop(immediate: immediate)
}

public func rescanAndLoadUIModules() {
    UIModuleEntry.shared.rescanAndLoad()
    _ = registerUIFunctionFeaturesAtEntry()
}

public func uiModuleHealthReport() -> String {
    let baseReport = UIModuleEntry.shared.healthReport()
    let registeredIDs = registeredUIFunctionIDsAtEntry()
    return baseReport + "\nUI功能注册：\(registeredIDs.count)/70"
}


// MARK: - 测试
@MainActor
internal func test_UI00() {
    print("\n=== UI-00 入口模块测试 ===\n")

    let entry = UIModuleEntry.shared

    // MARK: 测试0: 70个UI功能统一注册
    print("🧪 测试0: 70个UI功能统一注册")
    let registeredFeatureCount = registerUIFunctionFeaturesAtEntry()
    let registeredIDs = registeredUIFunctionIDsAtEntry()
    guard registeredIDs.count == 70 else {
        fatalError("❌ 测试0失败: UI功能注册ID应为70个，实际 \(registeredIDs.count)")
    }
    guard Set(registeredIDs).count == 70 else {
        fatalError("❌ 测试0失败: UI功能注册ID存在重复")
    }
    guard registeredFeatureCount >= 70 else {
        fatalError("❌ 测试0失败: 统一注册表功能数量不足70，实际 \(registeredFeatureCount)")
    }
    print("✅ 测试0通过: 70个UI功能已统一注册")

    // MARK: 测试1: 启动（空目录）
    print("🧪 测试1: 启动（空目录）")
    do {
        try entry.start(context: ["testMode": true])
    } catch {
        fatalError("❌ 测试1失败: 启动应成功 \(error)")
    }
    guard entry.isStarted else {
        fatalError("❌ 测试1失败: 启动后 isStarted 应为 true")
    }
    print("✅ 测试1通过: 启动成功")

    // MARK: 测试2: 重复启动安全
    print("\n🧪 测试2: 重复启动安全")
    try? entry.start(context: ["testMode": true])
    print("✅ 测试2通过: 重复启动安全")

    // MARK: 测试3: 健康报告
    print("\n🧪 测试3: 健康报告")
    let report = entry.healthReport()
    guard !report.isEmpty else {
        fatalError("❌ 测试3失败: 健康报告不应为空")
    }
    guard report.contains("健康状态") else {
        fatalError("❌ 测试3失败: 健康报告应包含'健康状态'")
    }
    print("✅ 测试3通过: 健康报告正常")

    // MARK: 测试4: 优雅停止
    print("\n🧪 测试4: 优雅停止")
    entry.stop(immediate: false)
    guard !entry.isStarted else {
        fatalError("❌ 测试4失败: 停止后 isStarted 应为 false")
    }
    print("✅ 测试4通过: 优雅停止成功")

    // MARK: 测试5: 重新启动
    print("\n🧪 测试5: 重新启动")
    do {
        try entry.start(context: ["testMode": true])
        guard entry.isStarted else {
            fatalError("❌ 测试5失败: 重新启动后 isStarted 应为 true")
        }
    } catch {
        fatalError("❌ 测试5失败: 重新启动应成功: \(error)")
    }
    print("✅ 测试5通过: 重新启动成功")

    // MARK: 测试6: rescanAndLoad
    print("\n🧪 测试6: rescanAndLoad（不崩溃）")
    entry.rescanAndLoad()
    print("✅ 测试6通过: rescanAndLoad 不崩溃")

    // MARK: 测试7: 立即停止
    print("\n🧪 测试7: 立即停止")
    entry.stop(immediate: true)
    guard !entry.isStarted else {
        fatalError("❌ 测试7失败: 停止后 isStarted 应为 false")
    }
    print("✅ 测试7通过: 立即停止成功")

    // MARK: 测试8: 停止已停止的入口
    print("\n🧪 测试8: 停止已停止的入口（不崩溃）")
    entry.stop()
    entry.stop(immediate: true)
    print("✅ 测试8通过: 重复停止不崩溃")

    // MARK: 测试9: 全局便捷函数
    print("\n🧪 测试9: 全局便捷函数")
    let mod = UIUnifiedRegistry.shared.getModule(moduleID: "NotExist")
    guard mod == nil else {
        fatalError("❌ 测试9失败: 不存在的模块应返回 nil")
    }
    let loaded = UIUnifiedRegistry.shared.isModuleRegistered(moduleID: "NotExist")
    guard !loaded else {
        fatalError("❌ 测试9失败: 不存在的模块 isModuleRegistered 应返回 false")
    }
    print("✅ 测试9通过: 全局便捷函数正确")

    // MARK: 测试10: 错误类型
    print("\n🧪 测试10: 错误类型")
    let cycleErr = NSError(domain: "UIModuleEntry", code: 1, userInfo: [NSLocalizedDescriptionKey: "循环依赖: A → B → A"])
    guard cycleErr.localizedDescription.contains("循环依赖") else {
        fatalError("❌ 测试10失败: 错误描述应包含'循环依赖'")
    }
    let depErr = NSError(domain: "UIModuleEntry", code: 2, userInfo: [NSLocalizedDescriptionKey: "模块 A 缺少依赖 B"])
    guard depErr.localizedDescription.contains("缺少依赖") else {
        fatalError("❌ 测试10失败: 错误描述应包含'缺少依赖'")
    }
    print("✅ 测试10通过: 错误类型描述正确")

    // 最终清理
    entry.stop(immediate: true)

    // MARK: 测试11: context 传递
    print("\n🧪 测试11: context 传递")
    do {
        try entry.start(context: ["config": ["key": "value"], "launchParameters": ["param": "test"]])
        guard entry.isStarted else {
            fatalError("❌ 测试11失败: 启动应成功")
        }
        var ctx = UIModuleStartContext()
        ctx.config = ["key": "value"]
        ctx.launchParameters = ["param": "test"]
        try entry.start(context: ctx)
    } catch {
        fatalError("❌ 测试11失败: context 启动应成功: \(error)")
    }
    entry.stop(immediate: false)
    print("✅ 测试11通过: context 传递正确")

    // MARK: 测试12: 启动后立即立即停止
    print("\n🧪 测试12: 启动后立即立即停止")
    do {
        try entry.start(context: nil)
        entry.stop(immediate: true)
    } catch {
        fatalError("❌ 测试12失败: 启动后立即停止应成功: \(error)")
    }
    print("✅ 测试12通过: 启动后立即停止成功")

    print("\n=== 全部 UI-00 入口模块测试通过 ✅ ===\n")
}


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension UIFeatureProtocol
public extension UIFeatureProtocol {
    func featureDidRegister() {}
    func featureWillUnregister() {}
}

// MARK: - 迁回自 UI-02：class UIModuleEntry
public final class UIModuleEntry: NSObject, @preconcurrency UIModuleProtocol, UIFeatureProtocol , @unchecked Sendable{
    public static let shared = UIModuleEntry()

    public let moduleID = "system.entry"
    public let moduleName = "UI模块管理入口"
    public let moduleVersion = "2.0"
    public let isUnloadable = false

    public let moduleDescription = "UI模块管理系统统一入口"
    public let featureVersion = "2.0"
    
    public func pause() {}
    public func resume() {}
    
    // MARK: - UIFeatureProtocol
    public let featureName = "UI模块入口"
    public let featureDescription = "UI模块管理系统统一入口"

    private let lock = NSRecursiveLock()
    private let logger: UILoadingLogManager

    // 依赖的所有子模块
    private let scanner: UIModuleScanner
    private let sorter: UIModuleSorter
    private let launcher: UIModuleLauncher
    private let errorHandler: UIModuleErrorHandler
    private let unloader: UIModuleUnloader
    private let registry: UIModuleRegistry
    private let locator: UIModuleLocator
    private let loader: UIModuleDynamicLoader
    private let hotReplacer: UIModuleHotReplacer
    private let versionChecker: UIModuleVersionChecker
    private let errorAggregator: UIModuleErrorAggregator
    private let rollbackManager: UIModuleRollbackManager
    private let functionRegistry: UIFunctionRegistry
    private let unifiedRegistry: UIUnifiedRegistry
    private let moduleListUI: UIModuleListUI
    private let windowLevelManager: UIWindowLevelManager
    private let globalEventBus: UIGlobalEventBus
    private let appStateManager: UIAppStateManager
    private let layoutTemplateManager: UILayoutTemplateManager
    // themeSwitchManager 主题切换功能后续接入
    private let workspaceSchemeManager: UIWorkspaceSchemeManager
    private let hotReloader: UIModuleHotReloader?

    private var _isStarted: Bool = false
    private var _startTime: Date?
    private var healthCheckTimer: Timer?
    private var mainWindow: NSWindow?  // 强引用保持窗口存活
    private let glassSkin = GlassSkin()  // 玻璃皮肤实例，负责工具栏设置面板等完整 UI 皮肤能力
    private var _lastHealthCheck: Date?
    private var _healthIssues: [String] = []
    private var _isHealthy: Bool = false
    private var applicationTerminationObserver: NSObjectProtocol?

    /// 创建UIModuleEntry实例
    /// - Parameters:
    ///   - scanner: 模块扫描器
    ///   - sorter: 模块排序器
    ///   - launcher: 模块启动器
    ///   - errorHandler: 错误处理器
    ///   - unloader: 模块卸载器
    ///   - registry: 模块注册表
    ///   - locator: 模块定位器
    ///   - loader: 动态加载器
    ///   - hotReplacer: 热替换器
    ///   - versionChecker: 版本检查器
    ///   - errorAggregator: 错误聚合器
    ///   - rollbackManager: 回滚管理器
    ///   - functionRegistry: 功能注册表
    ///   - unifiedRegistry: 统一注册表
    ///   - moduleListUI: 模块列表UI
    ///   - windowLevelManager: 窗口层级管理器
    ///   - globalEventBus: 全局事件总线
    ///   - appStateManager: 应用状态管理器
    ///   - layoutTemplateManager: 布局模板管理器
    ///   - workspaceSchemeManager: 工作区方案管理器
    ///   - hotReloader: 热重载器（仅DEBUG）
    public init(
        scanner: UIModuleScanner = .shared,
        sorter: UIModuleSorter = .shared,
        launcher: UIModuleLauncher = .shared,
        errorHandler: UIModuleErrorHandler = .shared,
        unloader: UIModuleUnloader = .shared,
        registry: UIModuleRegistry = .shared,
        locator: UIModuleLocator = .shared,
        loader: UIModuleDynamicLoader = .shared,
        hotReplacer: UIModuleHotReplacer = .shared,
        versionChecker: UIModuleVersionChecker = .shared,
        errorAggregator: UIModuleErrorAggregator = .shared,
        rollbackManager: UIModuleRollbackManager = .shared,
        functionRegistry: UIFunctionRegistry = .shared,
        unifiedRegistry: UIUnifiedRegistry = .shared,
        moduleListUI: UIModuleListUI = .shared,
        windowLevelManager: UIWindowLevelManager = .shared,
        globalEventBus: UIGlobalEventBus = .shared,
        appStateManager: UIAppStateManager = .shared,
        layoutTemplateManager: UILayoutTemplateManager = .shared,
        workspaceSchemeManager: UIWorkspaceSchemeManager = .shared,
        hotReloader: UIModuleHotReloader? = nil,
        logger: UILoadingLogManager = .shared
    ) {
        // 处理DEBUG条件编译的热重载器
        #if DEBUG
        self.hotReloader = hotReloader ?? .shared
        #else
        self.hotReloader = nil
        #endif
        self.scanner = scanner
        self.sorter = sorter
        self.launcher = launcher
        self.errorHandler = errorHandler
        self.unloader = unloader
        self.registry = registry
        self.locator = locator
        self.loader = loader
        self.hotReplacer = hotReplacer
        self.versionChecker = versionChecker
        self.errorAggregator = errorAggregator
        self.rollbackManager = rollbackManager
        self.functionRegistry = functionRegistry
        self.unifiedRegistry = unifiedRegistry
        self.moduleListUI = moduleListUI
        self.windowLevelManager = windowLevelManager
        self.globalEventBus = globalEventBus
        self.appStateManager = appStateManager
        self.layoutTemplateManager = layoutTemplateManager
        self.workspaceSchemeManager = workspaceSchemeManager
        self.logger = logger
        super.init()
    }

    /// 便捷初始化方法，使用默认依赖
    public convenience override init() {
        #if DEBUG
        self.init(
            scanner: .shared,
            sorter: .shared,
            launcher: .shared,
            errorHandler: .shared,
            unloader: .shared,
            registry: .shared,
            locator: .shared,
            loader: .shared,
            hotReplacer: .shared,
            versionChecker: .shared,
            errorAggregator: .shared,
            rollbackManager: .shared,
            functionRegistry: .shared,
            unifiedRegistry: .shared,
            moduleListUI: .shared,
            windowLevelManager: .shared,
            globalEventBus: .shared,
            appStateManager: .shared,
            layoutTemplateManager: .shared,
            workspaceSchemeManager: .shared,
            hotReloader: .shared,
            logger: .shared
        )
        #else
        self.init(
            scanner: .shared,
            sorter: .shared,
            launcher: .shared,
            errorHandler: .shared,
            unloader: .shared,
            registry: .shared,
            locator: .shared,
            loader: .shared,
            hotReplacer: .shared,
            versionChecker: .shared,
            errorAggregator: .shared,
            rollbackManager: .shared,
            functionRegistry: .shared,
            unifiedRegistry: .shared,
            moduleListUI: .shared,
            windowLevelManager: .shared,
            globalEventBus: .shared,
            appStateManager: .shared,
            layoutTemplateManager: .shared,
            workspaceSchemeManager: .shared,
            hotReloader: nil,
            logger: .shared
        )
        #endif
    }

    deinit {
        removeApplicationTerminationObserver()
    }

    // MARK: - 启动

    /// 启动UI模块管理系统
    /// - Parameter context: 启动上下文（可选）
    /// - Throws: 启动过程中的错误
    @MainActor
    public func start(context: Any?) throws {
        try start(context: context as? [String: Any])
    }

    @MainActor
    public func start(context: [String: Any]?) throws {
        lock.lock()
        guard !_isStarted else {
            lock.unlock()
            logger.warning("入口", "UI模块系统已启动，跳过重复启动")
            return
        }
        _isStarted = true
        _startTime = Date()
        lock.unlock()

        logger.info("入口", "===== UI模块系统 v\(moduleVersion) 启动 =====")

        // 阶段1: 注册管理模块清单
        logger.info("入口", "阶段 1/8: 注册管理模块清单")
        registerAllUIModules()

        // 阶段2: 设置框架版本
        logger.info("入口", "阶段 2/8: 设置框架版本")
        versionChecker.setFrameworkVersion("2.0")

        // 阶段3: 初始化管理服务
        logger.info("入口", "阶段 3/8: 初始化管理服务")
        initializeManagementServices()

        // 阶段4: 扫描模块目录
        logger.info("入口", "阶段 4/8: 扫描模块目录")
        let discoveredModules = scanner.scan()
        logger.info("入口", "发现 \(discoveredModules.count) 个模块")

        // 创建主窗口（如果需要）
        // 注意：主窗口是应用基础 UI，不能依赖外部 UIModules bundle 是否存在。
        // 之前这段逻辑放在 discoveredModules.isEmpty 之后；当外部模块目录为空时会提前 return，
        // 导致 Dock 图标已出现但没有任何 NSWindow 被创建/显示。
        createMainWindowIfNeeded(context: context)

        if discoveredModules.isEmpty {
            logger.info("入口", "无UI模块需要加载，系统就绪")
            startHealthCheck()
            startHotReloadIfDebug()
            logger.info("入口", "===== UI模块系统启动完成（无模块）=====")
            return
        }

        // 阶段3: 排序
        logger.info("入口", "阶段 5/8: 依赖排序")
        let sortResult = sorter.sort(modules: discoveredModules)
        switch sortResult {
        case .success(let order):
            logger.info("入口", "加载顺序: \(order)")
        case .cycleDetected(let cycle):
            logger.error("入口", "检测到循环依赖，终止加载: \(cycle.joined(separator: " -> "))")
            lock.lock()
            _isStarted = false
            _startTime = nil
            lock.unlock()
            throw NSError(domain: "UIModuleEntry", code: 1, userInfo: [NSLocalizedDescriptionKey: "循环依赖: \(cycle.joined(separator: " -> "))"])
        case .missingDependency(let mid, let dep):
            logger.error("入口", "模块 '\(mid)' 缺少依赖 '\(dep)'")
            lock.lock()
            _isStarted = false
            _startTime = nil
            lock.unlock()
            throw NSError(domain: "UIModuleEntry", code: 2, userInfo: [NSLocalizedDescriptionKey: "模块 \(mid) 缺少依赖 \(dep)"])
        }

        // 阶段4: 启动模块
        logger.info("入口", "阶段 6/8: 启动模块")
        var launchContext = UIModuleStartContext()
        // 将调用方传入的 context 传递给启动器
        if let ctx = context {
            if let config = ctx["config"] as? [String: Any] {
                launchContext.config = config
            }
            if let params = ctx["launchParameters"] as? [String: String] {
                launchContext.launchParameters = params
            }
        }
        let launchResult = launcher.launchAll(modules: discoveredModules, context: launchContext)

        if launchResult.failureCount > 0 {
            logger.warning("入口", "\(launchResult.successCount) 个成功, \(launchResult.failureCount) 个失败")
            errorHandler.startAutoRetry()
        } else {
            logger.info("入口", "全部 \(launchResult.successCount) 个模块启动成功")
        }

        // 阶段5: 启动目录监听（热插拔）
        logger.info("入口", "阶段 7/8: 启动目录监听")
        scanner.startWatching()

        // 阶段6: 注册 UI 系统自身功能
        logger.info("入口", "阶段 8/8: 注册 UI 管理服务")
        registerManagementServices()

        // 后台服务
        logger.info("入口", "启动后台服务")
        startHealthCheck()
        startHotReloadIfDebug()

        // 注册停机通知
        applicationTerminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applicationWillTerminate()
        }

        createMainWindowIfNeeded(context: context)

        let duration = Date().timeIntervalSince(_startTime ?? Date())

        logger.info("入口", "===== UI模块系统 v\(moduleVersion) 启动完成（耗时: \(String(format: "%.2f", duration))秒）=====")

        // 导出日志到文件
        logger.exportToFile(path: "/Users/songxiaoxiao/Desktop/ui_log.txt")
        print("[UI-00] 日志已导出到桌面 ui_log.txt")
    }

    // MARK: - 主窗口创建

    /// 按启动上下文创建主窗口。可重复调用，内部会防重。
    @MainActor
    private func createMainWindowIfNeeded(context: [String: Any]?) {
        print("[UI-00] 检查是否需要创建主窗口...")
        guard let needsMainWindow = context?["needsMainWindow"] as? Bool, needsMainWindow else {
            print("[UI-00] 不需要创建主窗口，context: \(String(describing: context))")
            return
        }

        if self.mainWindow != nil || NSApp.windows.contains(where: { $0.identifier?.rawValue == "main-window" }) {
            print("[UI-00] 主窗口已存在，跳过重复创建")
            return
        }

        // 必须同步创建第一窗口，不能再 DispatchQueue.main.async 延后。
        // 否则 AppKit 可能在启动阶段判断“无窗口”并自动终止进程。
        print("[UI-00] 需要创建主窗口，立即调用 createMainWindowWithGlassSkin()")
        self.createMainWindowWithGlassSkin()
    }

    /// 创建使用玻璃皮肤的主窗口
    @MainActor
    private func createMainWindowWithGlassSkin() {
        print("[UI-00] 开始创建玻璃皮肤主窗口...")

        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "仙人指路"
        window.identifier = NSUserInterfaceItemIdentifier("main-window")
        print("[UI-00] 窗口已创建，标题: \(window.title)")

        // 注册窗口到窗口注册表
        UIWindowRegistry.shared.register(window: window, id: "main-window")
        print("[UI-00] 窗口已注册到 UIWindowRegistry")

        // 应用完整玻璃皮肤：窗口样式 + 工具栏 + 设置按钮
        glassSkin.apply(to: window)
        print("[UI-00] 完整玻璃皮肤已应用")

        // 渲染远程完整玻璃皮肤根视图：材质背景 + 顶部功能栏 + 内容容器 + 边缘手势。
        // 新版 GlassSkin 不再暴露旧的 createCanvas(in:)；内容区由 apply(to: NSView) 内部创建 glass.content.view。
        if let contentView = window.contentView {
            glassSkin.apply(to: contentView)
            if let glassContentView = contentView.subviews.first(where: { $0.identifier?.rawValue == "glass.content.view" }) {
                glassContentView.identifier = NSUserInterfaceItemIdentifier("glass.content.view")
                print("[UI-00] 远程完整玻璃皮肤内容容器已创建: \(glassContentView.frame)")
            } else {
                print("[UI-00] 警告：远程玻璃皮肤未创建 glass.content.view")
            }
        }

        // 应用真正的玻璃效果
        let result = UIGlassEffectManager.shared.applyMaterial(to: "main-window", material: .windowBackground)
        print("[UI-00] 玻璃效果应用结果: \(result)")

        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("[UI-00] 窗口已显示并激活")

        // 强引用保持窗口存活
        self.mainWindow = window
        print("[UI-00] 窗口已保存到 mainWindow 属性")

        print("[UI-00] 玻璃皮肤主窗口创建成功")
    }

    /// 应用玻璃皮肤样式
    @MainActor
    private func applyGlassSkinStyle(to window: NSWindow) {
        window.backgroundColor = NSColor.windowBackgroundColor
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
    }

    /// 创建无限画布
    @MainActor
    private func createCanvas(in view: NSView) -> NSScrollView {
        let scrollView = NSScrollView(frame: view.bounds)
        scrollView.identifier = NSUserInterfaceItemIdentifier("glass.content.view")
        scrollView.wantsLayer = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.windowBackgroundColor
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .noBorder

        let canvasSize = NSSize(width: max(view.bounds.width * 3, 3000),
                                height: max(view.bounds.height * 3, 3000))
        let documentView = NSView(frame: NSRect(origin: .zero, size: canvasSize))
        documentView.identifier = NSUserInterfaceItemIdentifier("glass.content.document.view")
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        scrollView.documentView = documentView

        return scrollView
    }

    /// 配置工具栏
    @MainActor
    private func configureToolbar(for window: NSWindow) {
        let toolbar = NSToolbar(identifier: "glassskin.toolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.sizeMode = .regular
        if #available(macOS 15, *) {
            // macOS 15+ 中 showsBaselineSeparator 已被移除
        } else {
            toolbar.showsBaselineSeparator = false
        }
        window.toolbar = toolbar
        window.toolbar?.isVisible = true
    }

    /// 带上下文的便捷启动方法
    /// - Parameter context: 启动上下文
    /// - Throws: 启动过程中的错误
    @MainActor
    public func start(context: UIModuleStartContext) throws {
        try start(context: ["config": context.config, "launchParameters": context.launchParameters])
    }

    // MARK: - UI管理服务接入

    private func initializeManagementServices() {
        let _ = rollbackManager
        let _ = errorAggregator
        let _ = hotReplacer
        let _ = moduleListUI
        let _ = windowLevelManager
        let _ = globalEventBus
        // 使用系统当前外观，主题功能后续接入
        let currentAppearance = NSApp.effectiveAppearance
        let isDark = currentAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        appStateManager.updateColorScheme(isDark ? "dark" : "light")
        let _ = layoutTemplateManager.allTemplates
        let _ = workspaceSchemeManager.allSchemes
        logger.info("入口", "UI管理服务初始化完成")
    }

    private func registerManagementServices() {
        functionRegistry.register(feature: self)
        functionRegistry.register(name: "模块注册表", instance: registry)
        functionRegistry.register(name: "统一注册表", instance: unifiedRegistry)
        functionRegistry.register(name: "模块卸载器", instance: unloader)
        functionRegistry.register(name: "模块热替换器", instance: hotReplacer)
        functionRegistry.register(name: "模块错误处理器", instance: errorHandler)
        functionRegistry.register(name: "模块错误聚合器", instance: errorAggregator)
        functionRegistry.register(name: "模块回滚管理器", instance: rollbackManager)
        functionRegistry.register(name: "模块列表界面", instance: moduleListUI)
        functionRegistry.register(name: "窗口注册表", instance: UIWindowRegistry.shared)
        functionRegistry.register(name: "窗口层级管理器", instance: windowLevelManager)
        functionRegistry.register(name: "全局事件总线", instance: globalEventBus)
        functionRegistry.register(name: "应用状态管理器", instance: appStateManager)
        functionRegistry.register(name: "布局模板管理器", instance: layoutTemplateManager)
        // 主题切换管理器后续接入，暂不注册
        functionRegistry.register(name: "工作区管理器", instance: workspaceSchemeManager)
        functionRegistry.register(name: "功能注册表", instance: functionRegistry)
    }

    @MainActor public func makeWindowLifecycleManager(record: UIWindowRecord) -> UIWindowLifecycleManager {
        UIWindowLifecycleManager(record: record)
    }

    public func showModuleListDebugWindow() {
        moduleListUI.showDebugWindow()
    }

    public func closeModuleListDebugWindow() {
        moduleListUI.closeDebugWindow()
    }

    public func switchTheme(id: String) {
        // 已移至 SkinEngine
        logger.warning("switchTheme 已废弃，请使用 SkinEngine.shared.applySkin(id: id, animated: true)")
    }

    @discardableResult
    public func switchWorkspaceScheme(named name: String) -> Bool {
        workspaceSchemeManager.switchToScheme(named: name)
    }

    // MARK: - 主题切换兼容方法
    public func switchToTheme(id: String) {
        logger.warning("入口", "主题切换功能暂未接入，id: \(id)")
    }

    // MARK: - 停止

    /// 停止UI模块管理系统
    /// - Parameter immediate: true=立即停止，false=优雅停止（默认）
    public func stop(immediate: Bool = false) {
        lock.lock()
        guard _isStarted else {
            lock.unlock()
            logger.warning("入口", "UI系统未运行，跳过停止")
            return
        }
        _isStarted = false
        lock.unlock()

        logger.info("入口", "===== UI模块系统停止 \(immediate ? "（立即）" : "（优雅）") =====")

        // 停止后台服务
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        scanner.stopWatching()
        errorHandler.stopAutoRetry()
        unloader.clearAllBackups()
        moduleListUI.closeDebugWindow()
        #if DEBUG
        hotReloader?.stopWatching()
        #endif

        // 移除应用终止通知观察者
        removeApplicationTerminationObserver()

        if !immediate {
            // 优雅停止：使用注册表快照，避免 willUnload 回调中修改注册表影响遍历
            logger.info("入口", "阶段 1/3: 通知所有模块即将停止...")
            let allModules = registry.allRegisteredModules()
            // 先全部通知 willUnload，不操作注册表
            for (_, _, instance) in allModules {
                if instance.moduleID != moduleID {
                    do {
                        try instance.willUnload()
                    } catch {
                        logger.warning("入口", "模块 \(instance.moduleID) willUnload 失败: \(error)")
                    }
                }
            }

            // 倒序卸载（后加载的先停），使用单独的卸载列表
            logger.info("入口", "阶段 2/3: 正在卸载模块...")
            for (_, name, instance) in allModules.reversed() {
                if instance.moduleID != moduleID && instance.isUnloadable {
                    instance.stop()
                    registry.unregister(name: name)
                }
            }
            locator.clearCache()

            // 清理监听
            logger.info("入口", "阶段 3/3: 清理资源...")
            functionRegistry.unregisterAll()
        }

        logger.info("入口", "===== UI模块系统已停止 =====")
    }

    // MARK: - 重新扫描

    /// 不停机重新扫描模块目录，自动加载新发现的模块
    public func rescanAndLoad() {
        guard _isStarted else {
            logger.warning("入口", "系统未启动，跳过重新扫描")
            return
        }
        logger.info("入口", "开始重新扫描模块目录...")
        let discoveredModules = scanner.scan()
        guard !discoveredModules.isEmpty else {
            logger.info("入口", "未发现新模块")
            return
        }

        var loadedCount = 0
        var failedCount = 0

        for discovery in discoveredModules {
            lock.lock()
            let isAlreadyLoaded = registry.isRegistered(moduleID: discovery.moduleID)
            lock.unlock()

            if isAlreadyLoaded {
                logger.info("入口", "模块 '\(discovery.metadata.moduleName)' 已加载，跳过")
                continue
            }

            let result = loader.loadModule(path: discovery.bundleURL.path)
            switch result {
            case .success(let mid):
                loadedCount += 1
                logger.info("入口", "新模块 '\(discovery.metadata.moduleName)' (ID: \(mid)) 加载成功")
            case .alreadyLoaded(let mid):
                logger.info("入口", "新模块 '\(discovery.metadata.moduleName)' (ID: \(mid)) 已加载")
                loadedCount += 1
            case .incompatible(let mid, let reason):
                failedCount += 1
                logger.error("入口", "新模块 '\(discovery.metadata.moduleName)' (ID: \(mid)) 版本不兼容: \(reason)")
            case .missingDependency(let mid, let dep):
                failedCount += 1
                logger.error("入口", "新模块 '\(discovery.metadata.moduleName)' (ID: \(mid)) 缺少依赖: \(dep)")
            case .loadFailed(let mid, let err):
                failedCount += 1
                logger.error("入口", "新模块 '\(discovery.metadata.moduleName)' (ID: \(mid)) 加载失败: \(err)")
            case .timedOut(let mid, let timeout):
                failedCount += 1
                logger.error("入口", "新模块 '\(discovery.metadata.moduleName)' (ID: \(mid)) 加载超时 (\(timeout)秒)")
            case .cancelled(let mid):
                logger.info("入口", "新模块 '\(discovery.metadata.moduleName)' (ID: \(mid)) 加载被取消")
            case .failure:
                failedCount += 1
                logger.error("入口", "新模块 '\(discovery.metadata.moduleName)' 加载失败: 未知错误")
            case .notFound:
                failedCount += 1
                logger.error("入口", "新模块 '\(discovery.metadata.moduleName)' 未找到")
            }
        }

        if loadedCount > 0 {
            logger.info("入口", "重新扫描完成：\(loadedCount) 个加载成功, \(failedCount) 个失败")
        } else if failedCount > 0 {
            logger.info("入口", "重新扫描完成：\(failedCount) 个失败")
        } else {
            logger.info("入口", "重新扫描完成，无新模块")
        }
    }

    // MARK: - 健康检查

    private func startHealthCheck() {
        // Timer 必须在主线程创建，锁外操作确保无竞态
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.healthCheckTimer?.invalidate()
            self.healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                self?.performHealthCheck()
            }
        }
        _isHealthy = true
        logger.info("入口", "健康检查已启动（每30秒）")
    }

    private func performHealthCheck() {
        var issues: [String] = []

        lock.lock()
        let started = _isStarted
        lock.unlock()

        if !started {
            issues.append("系统未启动")
        }

        let moduleCount = registry.registeredCount()
        if moduleCount == 0 && started {
            issues.append("无已注册模块")
        }

        if let st = _startTime {
            let elapsed = Date().timeIntervalSince(st)
            if elapsed > 300 && moduleCount == 0 {
                issues.append("启动超过5分钟仍无模块注册")
            }
        }

        lock.lock()
        _healthIssues = issues
        _lastHealthCheck = Date()
        _isHealthy = issues.isEmpty
        lock.unlock()

        issues.forEach { logger.warning("入口", "健康检查: \($0)") }
    }

    // MARK: - 热重载

    private func startHotReloadIfDebug() {
        #if DEBUG
        let moduleDir = scanner.defaultModuleDirectory
        hotReloader?.startWatching(directory: moduleDir)
        logger.info("入口", "开发热重载已启动")
        #endif
    }

    // MARK: - 查询

    /// 获取当前健康报告
    /// - Returns: 健康报告
    public func healthReport() -> String {
        lock.lock()
        let isHealthy = _isHealthy
        let isStarted = _isStarted
        let moduleCount = registry.registeredCount()
        let _ = _lastHealthCheck
        let _ = _healthIssues
        let uptime = _startTime.map { Date().timeIntervalSince($0) } ?? 0
        lock.unlock()
        return "健康状态: \(isHealthy), 已启动: \(isStarted), 模块数: \(moduleCount), 布局模板数: \(layoutTemplateManager.allTemplates.count), 工作区数: \(workspaceSchemeManager.allSchemes.count), 运行时间: \(uptime)秒"
    }

    /// 当前是否已启动
    public var isStarted: Bool {
        lock.lock()
        let s = _isStarted
        lock.unlock()
        return s
    }

    // MARK: - UIModuleProtocol 接口


    public func stop() {
        stop(immediate: false)
    }

    public func willUnload() throws {
        stop(immediate: true)
    }

    public func didUnload() {}
    
// MARK: - 应用终止

    @objc private func applicationWillTerminate() {
        logger.info("入口", "应用终止，执行清理...")
        stop(immediate: true)
    }

    private func removeApplicationTerminationObserver() {
        if let observer = applicationTerminationObserver {
            NotificationCenter.default.removeObserver(observer)
            applicationTerminationObserver = nil
        }
    }
}

// MARK: - NSToolbarDelegate
extension UIModuleEntry: NSToolbarDelegate {
    private static let toolbarSettingsItem = "com.glassskin.settings"

    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, NSToolbarItem.Identifier(Self.toolbarSettingsItem)]
    }

    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, NSToolbarItem.Identifier(Self.toolbarSettingsItem)]
    }

    public func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard itemIdentifier.rawValue == Self.toolbarSettingsItem else { return nil }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "设置"
        item.paletteLabel = "设置"
        item.toolTip = "打开设置面板"

        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.title = "⚙"
        button.font = NSFont.systemFont(ofSize: 16)
        button.contentTintColor = NSColor.secondaryLabelColor
        button.target = self
        button.action = #selector(settingsButtonClicked(_:))

        item.view = button
        return item
    }

    @objc private func settingsButtonClicked(_ sender: NSButton) {
        guard let window = sender.window ?? mainWindow ?? NSApp.keyWindow else {
            logger.warning("入口", "设置按钮被点击，但未找到主窗口")
            return
        }
        logger.info("入口", "设置按钮被点击，打开玻璃皮肤设置面板")
        glassSkin.openSettingsPanel(in: window)
    }
}
