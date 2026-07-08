// KJ-GL-00_主程序启动.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import AppKit
import os



// MARK: - KJXRZApplication
// MARK: - 框架管理层残留类型迁移汇总
// 版本: 2.0

// MARK: - 迁移自 KJ-GL-00_主程序启动.swift
// MARK: - 前置类型定义 (补全引用的缺失类型)

/// 模块日志系统

/// 泛型事件类型

/// 事件总线（简易版，支持类型擦除）

/// 模块注册表

/// 模块加载器

/// 日志系统

/// 配置系统

// MARK: - 应用程序主入口

/// 应用程序主入口
/// 负责初始化框架并启动主事件循环
public final class KJXRZApplication : @unchecked Sendable {
    
    // MARK: - 单例
    public static let shared = KJXRZApplication()
    
    // MARK: - 核心组件
    private let moduleLoader: KJModuleLoader
    private let moduleRegistry: KJModuleRegistry
    private let eventBus: KJEventBus
    private let logger: KJModuleLogger
    private let moduleScanner: KJModuleScanner
    private let moduleStarter: KJModuleStarter
    private let moduleUnloader: KJModuleUnloader
    private let dynamicModuleLoader: KJDynamicModuleLoader
    private let moduleFailureHandler: KJModuleFailureHandler
    private let moduleAccessor: KJModuleAccessor
    private let serviceRegistry: KJServiceRegistry
    private let serviceInvoker: KJServiceInvoker
    private let sharedDataManager: KJSharedDataManager
    private let moduleHotSwapper: KJModuleHotSwapper
    
    // MARK: - 状态
    private var isRunning = false

    // MARK: - 初始化
    private init() {
        self.logger = KJModuleLogger.shared
        self.eventBus = KJEventBus.shared
        self.moduleRegistry = KJModuleRegistry.shared
        self.moduleLoader = KJModuleLoader.shared
        self.moduleScanner = KJModuleScanner.shared
        self.moduleStarter = KJModuleStarter.shared
        self.moduleUnloader = KJModuleUnloader.shared
        self.dynamicModuleLoader = KJDynamicModuleLoader.shared
        self.moduleFailureHandler = KJModuleFailureHandler()
        self.moduleAccessor = KJModuleAccessor.shared
        self.serviceRegistry = KJServiceRegistry.shared
        self.serviceInvoker = KJServiceInvoker.shared
        self.sharedDataManager = KJSharedDataManager.shared
        self.moduleHotSwapper = KJModuleHotSwapper(
            registry: KJModuleRegistry.shared,
            loader: KJModuleLoader.shared,
            unloader: KJModuleUnloader.shared,
            eventBus: NotificationCenter.default
        )
    }
    
    // MARK: - 启动应用
    public func start() async {
        guard !isRunning else {
            logger.warning("App", "Application already running")
            return
        }

        logger.info("App", "=== XianRenZhiLu Starting ===")

        // 1. 初始化日志系统 (KJ-GL-03)
        initializeLogging()

        // 2. 初始化配置系统 (KJ-GL-04)
        initializeConfiguration()

        // 3. 注册框架管理层16个文件到唯一统一注册表 (KJ-GL-01/KJ-GL-02)
        let managementRegistrationCount = registerAllKJManagementLayerFiles()
        guard managementRegistrationCount >= 16 else {
            logger.error("App", "框架管理层注册不完整：当前注册 \(managementRegistrationCount)/16")
            return
        }

        // 4. 校验管理层文件装配：启动入口必须能找到 KJ-GL-00～KJ-GL-15
        guard validateManagementLayerFileAssembly() else {
            logger.error("App", "框架管理层文件装配校验失败，启动中止")
            return
        }

        // 5. 注册框架功能层15个文件到唯一统一注册表 (KJ-GL-01/KJ-GN-01～15)
        let functionRegistrationCount = registerAllKJFunctionLayerFiles()
        guard functionRegistrationCount >= 15 else {
            logger.error("App", "框架功能层注册不完整：当前注册 \(functionRegistrationCount)/15")
            return
        }

        // 6. 校验功能层文件装配：启动入口必须能找到 KJ-GN-01～KJ-GN-15
        guard validateFunctionLayerFileAssembly() else {
            logger.error("App", "框架功能层文件装配校验失败，启动中止")
            return
        }

        // 7. 初始化框架运行结构能力 (KJ-GL-08～KJ-GL-15)
        initializeFrameworkRuntimeServices()

        // 8. 扫描、加载、启动模块 (KJ-GL-05/KJ-GL-06/KJ-GL-07)
        loadModules()
        startRegisteredModules()

        // 9. 启动 UI 模块（接口对接：框架→UIModuleProtocol）
        let uiBootContext: [String: Any] = ["frameworkVersion": "2.0", "needsMainWindow": true]
        print("[KJ-GL-00] 准备启动 UI 模块，context: \(uiBootContext)")
        do {
            try await MainActor.run {
                try UIModuleEntry.shared.start(context: uiBootContext)
            }
            _ = registerUIFunctionFeaturesAtEntry()
            await MainActor.run {
                startKLineModuleAtApplicationLaunch()
            }
            KXUI08Entry.restorePanelIfNeededAfterLaunch()
            print("[KJ-GL-00] UI 模块系统启动成功")
        } catch {
            print("[KJ-GL-00] UI 模块系统启动失败: \(error)")
        }

        isRunning = true
        logger.info("App", "=== Application Started ===")

        // 10. 发送启动完成事件 (KJ-GL-13)
        eventBus.emit(KJEventType<[String: Any]>("applicationDidFinishLaunching"), payload: [
            "managementRegistrationCount": managementRegistrationCount,
            "functionRegistrationCount": functionRegistrationCount,
            "registeredModuleCount": moduleRegistry.allModuleNames.count,
            "runtimeServicesReady": true
        ])
    }
    
    // MARK: - 停止应用
    public func shutdown() {
        guard isRunning else { return }

        logger.info("App", "=== Shutting Down ===")
        eventBus.emit(KJEventType<[String: Any]>("applicationWillTerminate"), payload: [:])

        // 按统一注册表记录卸载模块 (KJ-GL-10)
        for moduleName in moduleRegistry.allModuleNames {
            _ = moduleUnloader.forceUnload(moduleID: moduleName)
        }
        moduleLoader.unloadAllModules()

        // 清理运行时共享状态 (KJ-GL-15)
        _ = sharedDataManager.remove("framework.runtime.initializedAt")
        _ = sharedDataManager.remove("framework.runtime.pluginPath")

        isRunning = false
        logger.info("App", "=== Shutdown Complete ===")
    }
    
    // MARK: - 私有方法
    private func initializeLogging() {
        // KJ-GL-03：初始化日志系统
        KJLogSystem.shared.initialize()
        logger.info("App", "日志系统已初始化")
    }

    private func initializeConfiguration() {
        // KJ-GL-04：初始化配置系统
        KJConfigSystem.shared.initialize()
        logger.info("App", "配置系统已初始化")
    }

    private func validateManagementLayerFileAssembly() -> Bool {
        let registry = KJModuleRegistry.shared
        let registrations = registry.allManagementLayerFileRegistrations
        let expectedIDs = Set((0...15).map { String(format: "KJ-GL-%02d", $0) })
        let actualIDs = Set(registrations.map { $0.id })
        let missingIDs = expectedIDs.subtracting(actualIDs).sorted()
        let duplicateCheckPassed = registrations.count == actualIDs.count

        guard registrations.count == 16, missingIDs.isEmpty, duplicateCheckPassed else {
            logger.error("App", "框架管理层注册清单异常：count=\(registrations.count), missing=\(missingIDs), duplicateOK=\(duplicateCheckPassed)")
            return false
        }

        let managementDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        var missingFiles: [String] = []
        for registration in registrations {
            let fileURL = managementDirectory.appendingPathComponent(registration.fileName)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                missingFiles.append(registration.fileName)
            }
        }

        guard missingFiles.isEmpty else {
            logger.error("App", "框架管理层文件缺失：\(missingFiles.joined(separator: ", "))")
            return false
        }

        _ = sharedDataManager.set(managementDirectory.path, forKey: "framework.management.directory")
        _ = sharedDataManager.set(registrations.map { $0.fileName }, forKey: "framework.management.files")
        logger.info("App", "框架管理层文件装配校验通过：16/16，目录：\(managementDirectory.path)")
        return true
    }

    private func validateFunctionLayerFileAssembly() -> Bool {
        let registry = KJModuleRegistry.shared
        let registrations = registry.allFunctionLayerFileRegistrations
        let expectedIDs = Set((1...15).map { String(format: "KJ-GN-%02d", $0) })
        let actualIDs = Set(registrations.map { $0.id })
        let missingIDs = expectedIDs.subtracting(actualIDs).sorted()
        let duplicateCheckPassed = registrations.count == actualIDs.count

        guard registrations.count == 15, missingIDs.isEmpty, duplicateCheckPassed else {
            logger.error("App", "框架功能层注册清单异常：count=\(registrations.count), missing=\(missingIDs), duplicateOK=\(duplicateCheckPassed)")
            return false
        }

        let functionDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("功能层")
        var missingFiles: [String] = []
        for registration in registrations {
            let fileURL = functionDirectory.appendingPathComponent(registration.fileName)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                missingFiles.append(registration.fileName)
            }
        }

        guard missingFiles.isEmpty else {
            logger.error("App", "框架功能层文件缺失：\(missingFiles.joined(separator: ", "))")
            return false
        }

        _ = sharedDataManager.set(functionDirectory.path, forKey: "framework.function.directory")
        _ = sharedDataManager.set(registrations.map { $0.fileName }, forKey: "framework.function.files")
        _ = sharedDataManager.set(registeredKJFunctionLayerFileIDs(), forKey: "framework.function.registeredIDs")
        logger.info("App", "框架功能层文件装配校验通过：15/15，目录：\(functionDirectory.path)")
        return true
    }

    private func startKLineModuleAtApplicationLaunch() {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let klineModulePath = projectRoot.appendingPathComponent("K线模块").path
        let klineReport = KXModuleEntry.start(basePath: klineModulePath)
        if klineReport.allPassed {
            logger.info("App", "K线模块已随软件启动加载")
        } else {
            let failed = klineReport.items.filter { !$0.passed }.map { $0.name }.joined(separator: ", ")
            logger.warning("App", "K线模块启动检查存在未通过项：\(failed)")
        }

        let patternModulePath = projectRoot.appendingPathComponent("K线形态识别模块").path
        let patternReport = KPModuleEntry.start(basePath: patternModulePath)
        let patternAllPassed = patternReport.healthItems.allSatisfy { $0.passed }
        if patternAllPassed {
            logger.info("App", "K线形态识别模块已作为独立模块随软件启动加载")
        } else {
            let failed = patternReport.healthItems.filter { !$0.passed }.map { $0.name }.joined(separator: ", ")
            logger.warning("App", "K线形态识别模块启动检查存在未通过项：\(failed)")
        }
    }

    private func initializeFrameworkRuntimeServices() {
        logger.info("App", "初始化框架运行时服务")

        // KJ-GL-08：失败处理器进入运行时链路
        moduleFailureHandler.resetAll()

        // KJ-GL-09/KJ-GL-10/KJ-GL-11/KJ-GL-12/KJ-GL-14/KJ-GL-15：运行时服务挂入统一服务注册表
        registerRuntimeService(name: "framework.dynamicLoader", instance: dynamicModuleLoader, description: "动态模块加载服务")
        registerRuntimeService(name: "framework.moduleUnloader", instance: moduleUnloader, description: "模块动态卸载服务")
        registerRuntimeService(name: "framework.moduleAccessor", instance: moduleAccessor, description: "模块实例访问服务")
        registerRuntimeService(name: "framework.hotSwapper", instance: moduleHotSwapper, description: "模块热替换服务")
        registerRuntimeService(name: "framework.serviceInvoker", instance: serviceInvoker, description: "模块服务调用服务")
        registerRuntimeService(name: "framework.sharedData", instance: sharedDataManager, description: "模块间共享数据服务")

        _ = sharedDataManager.set(Date(), forKey: "framework.runtime.initializedAt")
        _ = sharedDataManager.set(registeredKJManagementLayerFileIDs(), forKey: "framework.management.registeredIDs")
        _ = sharedDataManager.set(registeredKJFunctionLayerFileIDs(), forKey: "framework.function.registeredIDs")

        eventBus.emit(KJEventType<[String: Any]>("frameworkRuntimeDidInitialize"), payload: [
            "serviceCount": 6,
            "managementRegistrationCount": KJModuleRegistry.shared.managementLayerFileRegistrationCount,
            "functionRegistrationCount": KJModuleRegistry.shared.functionLayerFileRegistrationCount
        ])
    }

    private func registerRuntimeService(name: String, instance: AnyObject, description: String) {
        let descriptor = KJServiceDescriptor(name: name, version: "2.0", description: description)
        serviceRegistry.register(service: descriptor, instance: instance)
        logger.info("App", "运行时服务已注册：\(name)")
    }

    private func loadModules() {
        let pluginPath = Bundle.main.bundlePath + "/Contents/PlugIns"
        _ = sharedDataManager.set(pluginPath, forKey: "framework.runtime.pluginPath")
        logger.info("App", "扫描模块目录：\(pluginPath)")

        // KJ-GL-05：扫描模块目录
        let scannedModules = moduleScanner.scan(directory: pluginPath)
        eventBus.emit(KJEventType<[String: Any]>("moduleScanDidFinish"), payload: [
            "path": pluginPath,
            "count": scannedModules.count
        ])

        guard !scannedModules.isEmpty else {
            logger.warning("App", "未扫描到外部模块，继续启动框架基础能力")
            moduleLoader.scanAndLoad(from: pluginPath)
            return
        }

        // KJ-GL-06：按扫描顺序加载模块；KJ-GL-08：失败交给失败处理器
        for scannedModule in scannedModules {
            guard scannedModule.isValid else {
                _ = moduleFailureHandler.handle(.configurationError(module: scannedModule.moduleID, reason: scannedModule.validationError ?? "模块校验失败"))
                continue
            }

            let loadResult = moduleLoader.load(moduleID: scannedModule.moduleID)
            switch loadResult {
            case .success(let moduleID), .alreadyLoaded(let moduleID):
                logger.info("App", "模块已加载：\(moduleID)")
            case .failure(let moduleID, let error):
                logger.error("App", "模块加载失败：\(moduleID), \(error)")
                _ = moduleFailureHandler.handle(.configurationError(module: moduleID, reason: error.localizedDescription))
            }
        }
    }

    private func startRegisteredModules() {
        // KJ-GL-07：对统一注册表里的模块调用 start
        let moduleNames = moduleRegistry.allModuleNames
        guard !moduleNames.isEmpty else {
            logger.warning("App", "统一注册表暂无已加载模块，跳过模块启动阶段")
            return
        }

        for moduleName in moduleNames {
            let result = moduleStarter.start(moduleID: moduleName, context: [
                "registry": moduleRegistry,
                "eventBus": eventBus,
                "serviceRegistry": serviceRegistry,
                "sharedData": sharedDataManager
            ])

            switch result {
            case .success(let moduleID):
                logger.info("App", "模块已启动：\(moduleID)")
            case .failure(let moduleID, let error):
                logger.error("App", "模块启动失败：\(moduleID), \(error)")
                _ = moduleFailureHandler.handle(.configurationError(module: moduleID, reason: error.localizedDescription))
            }
        }
    }

}

// MARK: - KJXRZAppDelegate
// MARK: - 迁移自 KJ-GL-00_主程序启动.swift
// MARK: - AppDelegate (传统入口)
public final class KJXRZAppDelegate: NSObject, NSApplicationDelegate , @unchecked Sendable{
    public func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await KJXRZApplication.shared.start()
        }
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        KJXRZApplication.shared.shutdown()
    }
}

