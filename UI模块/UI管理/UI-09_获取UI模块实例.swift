// MARK: - UI-08: 获取UI模块实例
// 功能编号: UI-09
// 版本: 2.0
// 职责: 提供统一的模块获取接口，支持同步/异步、按名/按协议、别名、缓存、代理
// 依赖: UI-05 注册表, UI-12 日志

import Foundation

// MARK: - 模块查找结果
// 类型 UIModuleLookupResult 已迁移到 UI-02_公共类型定义.swift

// MARK: - 模块获取管理器
// 独立编译存根
// 类型 UIModuleRegistry 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleLocator 已迁移到 UI-02_公共类型定义.swift

// MARK: - 弱引用包装
// 类型 UIWeakRef 已迁移到 UI-02_公共类型定义.swift

// MARK: - 全局便捷函数

/// 快捷获取UI模块实例
/// - Parameter name: 模块名称或别名
/// - Returns: 模块实例
public func getUIModule(_ name: String) -> UIModuleProtocol? {
    UIModuleLocator.shared.getModule(name)
}

/// 快捷判断UI模块是否已加载
/// - Parameter name: 模块名称或别名
/// - Returns: 是否已加载
public func isUIModuleLoaded(_ name: String) -> Bool {
    UIModuleLocator.shared.isModuleReachable(name)
}

// MARK: - 按协议查找测试专用协议
// 类型 UI08TestModuleProtocol 已迁移到 UI-02_公共类型定义.swift

// MARK: - 测试
internal func test_UI08() {
    print("\n=== UI-08 定位器模块测试 ===\n")

    let locator = UIModuleLocator.shared
    let registry = UIModuleRegistry.shared

    // 清理初始状态
    registry.unregister(name: "TestLocatorModule")
    registry.unregister(name: "AnotherLocatorModule")
    locator.clearCache()

    // 测试模块类
// 类型 UITestModule 已迁移到 UI-02_公共类型定义.swift

    let module = UITestModule(id: "test.locator.01", name: "定位器测试模块")
    let another = UITestModule(id: "test.locator.02", name: "定位器另一模块")
    registry.register(instance: module, name: "TestLocatorModule")
    registry.register(instance: another, name: "AnotherLocatorModule")

    // MARK: 测试1: 同步获取
    print("🧪 测试1: 同步获取")
    let found = locator.getModule("TestLocatorModule")
    guard found != nil else {
        fatalError("❌ 测试1失败: getModule 应返回非nil")
    }
    guard found?.moduleID == "test.locator.01" else {
        fatalError("❌ 测试1失败: moduleID应为 test.locator.01，实际: \(found?.moduleID ?? "nil")")
    }
    print("✅ 测试1通过: 同步获取返回正确模块")

    // MARK: 测试2: 缓存命中
    print("\n🧪 测试2: 缓存命中")
    let cached = locator.getModule("TestLocatorModule")
    guard cached != nil else {
        fatalError("❌ 测试2失败: 缓存获取应返回非nil")
    }
    guard cached?.moduleID == "test.locator.01" else {
        fatalError("❌ 测试2失败: 缓存命中ID应为 test.locator.01")
    }
    print("✅ 测试2通过: 缓存命中返回正确模块")

    // MARK: 测试3: 代理设置与获取
    print("\n🧪 测试3: 代理设置与获取")
    locator.setProxy(moduleName: "ProxyA", proxyModuleName: "TestLocatorModule")
    let proxied = locator.getModule("ProxyA")
    guard proxied != nil else {
        fatalError("❌ 测试3失败: 代理应返回非nil")
    }
    guard proxied?.moduleID == "test.locator.01" else {
        fatalError("❌ 测试3失败: 代理模块ID应为 test.locator.01")
    }
    print("✅ 测试3通过: 代理返回正确模块")

    // MARK: 测试4: 代理移除
    print("\n🧪 测试4: 代理移除")
    locator.removeProxy(moduleName: "ProxyA")
    let removedProxy = locator.getModule("ProxyA")
    guard removedProxy == nil else {
        fatalError("❌ 测试4失败: 代理移除后应返回nil")
    }
    print("✅ 测试4通过: 代理移除后返回nil")

    // MARK: 测试5: 可达性检查
    print("\n🧪 测试5: 可达性检查")
    guard locator.isModuleReachable("TestLocatorModule") else {
        fatalError("❌ 测试5失败: 已注册模块应可达")
    }
    guard !locator.isModuleReachable("NotExist") else {
        fatalError("❌ 测试5失败: 不存在的模块应不可达")
    }
    print("✅ 测试5通过: 可达性检查正确")

    // MARK: 测试6: 全局便捷函数
    print("\n🧪 测试6: 全局便捷函数")
    guard getUIModule("TestLocatorModule") != nil else {
        fatalError("❌ 测试6失败: getUIModule 应返回非nil")
    }
    guard isUIModuleLoaded("TestLocatorModule") else {
        fatalError("❌ 测试6失败: isUIModuleLoaded 应返回true")
    }
    print("✅ 测试6通过: 全局便捷函数正确")

    // MARK: 测试7: 缓存清理后仍可从注册表获取
    print("\n🧪 测试7: 缓存清理后仍可获取")
    locator.clearCache()
    let afterClear = locator.getModule("TestLocatorModule")
    guard afterClear != nil else {
        fatalError("❌ 测试7失败: 缓存清理后仍应能从注册表获取")
    }
    print("✅ 测试7通过: 缓存清理后重新加载")

    // MARK: 测试8: 按协议获取
    print("\n🧪 测试8: 按协议获取")
    let byProtocol = locator.getModule(byProtocol: UI08TestModuleProtocol.self)
    guard byProtocol != nil else {
        fatalError("❌ 测试8失败: 按 UI08TestModuleProtocol 协议应找到模块")
    }
    guard byProtocol?.moduleID == "test.locator.01" else {
        fatalError("❌ 测试8失败: 按协议获取模块ID应为 test.locator.01")
    }
    print("✅ 测试8通过: 按 UI08TestModuleProtocol 协议找到模块")

    // MARK: 测试9: 按不存在的协议获取
    print("\n🧪 测试9: 按不存在的协议获取")
    let byProtocolNotFound = locator.getModule(byProtocol: NSCopying.self)
    guard byProtocolNotFound == nil else {
        fatalError("❌ 测试9失败: 按NSCopying协议应返回nil")
    }
    print("✅ 测试9通过: 不存在的协议返回nil")

    // MARK: 测试10: 不存在模块查找
    print("\n🧪 测试10: 不存在模块查找")
    let notFound = locator.getModule("NonExistentModule")
    guard notFound == nil else {
        fatalError("❌ 测试10失败: 不存在的模块应返回nil")
    }
    print("✅ 测试10通过: 不存在模块返回nil")

    // MARK: 测试11: 异步获取（存在模块）
    print("\n🧪 测试11: 异步获取（模块已存在）")
    var asyncResult: UIModuleProtocol?
    let asyncGroup = DispatchGroup()
    asyncGroup.enter()
    locator.getModuleAsync("TestLocatorModule", timeout: 1.0) { result in
        asyncResult = result
        asyncGroup.leave()
    }
    let asyncWait = asyncGroup.wait(timeout: .now() + 2.0)
    guard asyncWait == .success else {
        fatalError("❌ 测试11失败: 异步获取超时")
    }
    guard asyncResult != nil else {
        fatalError("❌ 测试11失败: 异步获取返回nil")
    }
    guard asyncResult?.moduleID == "test.locator.01" else {
        fatalError("❌ 测试11失败: 异步获取模块ID应为 test.locator.01")
    }
    print("✅ 测试11通过: 异步获取正确")

    // MARK: 测试12: 异步获取超时
    print("\n🧪 测试12: 异步获取超时")
    var timeoutResult: UIModuleProtocol?
    let timeoutGroup = DispatchGroup()
    timeoutGroup.enter()
    locator.getModuleAsync("NonExistentModule", timeout: 0.2) { result in
        timeoutResult = result
        timeoutGroup.leave()
    }
    let timeoutWait = timeoutGroup.wait(timeout: .now() + 3.0)
    guard timeoutWait == .success else {
        fatalError("❌ 测试12失败: 异步超时回调未执行")
    }
    guard timeoutResult == nil else {
        fatalError("❌ 测试12失败: 异步超时应返回nil")
    }
    print("✅ 测试12通过: 异步获取超时返回nil")

    // MARK: 测试13: 等待模块（存在）
    print("\n🧪 测试13: 等待模块（存在）")
    let waitResult = locator.waitForModule(name: "TestLocatorModule", timeout: 1.0)
    guard case .found(let foundModule) = waitResult else {
        fatalError("❌ 测试13失败: 等待模块应返回found")
    }
    guard foundModule.moduleID == "test.locator.01" else {
        fatalError("❌ 测试13失败: 等待模块ID应为 test.locator.01")
    }
    print("✅ 测试13通过: 等待模块返回found")

    // MARK: 测试14: 等待模块超时
    print("\n🧪 测试14: 等待模块超时")
    let waitTimeoutResult = locator.waitForModule(name: "NonExistentModule", timeout: 0.1)
    guard case .timeout = waitTimeoutResult else {
        fatalError("❌ 测试14失败: 等待不存在模块应返回timeout")
    }
    print("✅ 测试14通过: 等待不存在模块返回timeout")

    // MARK: 测试15: 并发查找
    print("\n🧪 测试15: 并发查找")
    let concGroup = DispatchGroup()
    let concQueue = DispatchQueue(label: "test.locator.concurrent", attributes: .concurrent)
    var concFailed = false
    for i in 0..<20 {
        concGroup.enter()
        concQueue.async {
            let name = i % 2 == 0 ? "TestLocatorModule" : "AnotherLocatorModule"
            let result = locator.getModule(name)
            if result == nil {
                concFailed = true
            }
            concGroup.leave()
        }
    }
    let concWait = concGroup.wait(timeout: .now() + 5.0)
    guard concWait == .success else {
        fatalError("❌ 测试15失败: 并发查找超时")
    }
    guard !concFailed else {
        fatalError("❌ 测试15失败: 并发查找中出现nil（竞态问题）")
    }
    print("✅ 测试15通过: 20次并发查找无竞态问题")

    // MARK: 清理
    locator.clearCache()
    registry.unregister(name: "TestLocatorModule")
    registry.unregister(name: "AnotherLocatorModule")

    print("\n=== 全部 UI-08 定位器模块测试通过 ✅ ===\n")
}

#if FILEINDEPENDENT
// MARK: - 独立编译存根：UIModuleRegistry (UI-05)
// 类型 UIModuleRegistry 已迁移到 UI-02_公共类型定义.swift
#endif


#if FILEINDEPENDENT
// MARK: - 独立编译存根：UILoadingLogManager (UI-12)
// 类型 UILoadingLogManager 已迁移到 UI-02_公共类型定义.swift
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIModuleLocator
public final class UIModuleLocator : @unchecked Sendable {
    public static let shared = UIModuleLocator()

    let lock = NSRecursiveLock()
    private let registry = UIModuleRegistry.shared
    private let logger = UILoadingLogManager.shared
    private var lookupCache: [String: UIWeakRef] = [:]
    private var proxies: [String: String] = [:]

    private init() {}

    // MARK: - 同步获取（按名称）

    /// 按名称查找已加载的模块实例
    /// - Parameter name: 模块名称或别名
    /// - Returns: 模块实例，未找到返回nil
    public func getModule(_ name: String) -> UIModuleProtocol? {
        guard !name.isEmpty else {
            logger.warning("定位器", "模块名称为空，跳过查找")
            return nil
        }
        let (instance, proxySource) = _lockedFindModule(name)
        // 锁外输出日志，避免在锁内调用外部方法
        if let proxySource {
            logger.info("定位器", "模块 '\(name)' 由代理 '\(proxySource)' 提供服务")
        } else if instance == nil {
            logger.warning("定位器", "模块 '\(name)' 未找到")
        }
        return instance
    }

    /// 锁内查找逻辑（线程安全），将日志输出与锁保护的数据访问分离
    private func _lockedFindModule(_ name: String) -> (UIModuleProtocol?, proxySource: String?) {
        lock.lock()
        defer { lock.unlock() }

        // 1. 查缓存
        if let cached = lookupCache[name], let instance = cached.value as? UIModuleProtocol {
            return (instance, nil)
        }

        // 2. 查注册表
        if let instance = registry.get(name: name) {
            lookupCache[name] = UIWeakRef(value: instance)
            return (instance, nil)
        }

        // 3. 查代理
        if let proxyTarget = proxies[name], let proxyInstance = registry.get(name: proxyTarget) {
            return (proxyInstance, proxyTarget)
        }

        return (nil, nil)
    }

    // MARK: - 同步获取（按协议）

    /// 按协议查找第一个实现该协议的模块实例
    /// - Parameter proto: 协议对象
    /// - Returns: 第一个匹配的模块实例，未找到返回nil
    public func getModule(byProtocol proto: Protocol) -> UIModuleProtocol? {
        lock.lock()
        defer { lock.unlock() }
        let allModules = registry.allRegisteredModules()
        for (_, _, instance) in allModules {
            if (instance as AnyObject).conforms(to: proto) {
                return instance
            }
        }
        return nil
    }

    // MARK: - 异步获取

    /// 异步获取模块，指定时间内轮询等待
    /// - Parameters:
    ///   - name: 模块名称或别名
    ///   - timeout: 超时秒数
    ///   - completion: 回调（主线程）
    public func getModuleAsync(_ name: String, timeout: TimeInterval, completion: @escaping (UIModuleProtocol?) -> Void) {
        guard !name.isEmpty else {
            logger.warning("定位器", "异步获取：模块名称为空")
            DispatchQueue.main.async { completion(nil) }
            return
        }
        if let instance = getModule(name) {
            DispatchQueue.main.async {
                completion(instance)
            }
            return
        }

        let workItem = DispatchWorkItem {
            let startTime = Date()
            while Date().timeIntervalSince(startTime) < timeout {
                if let instance = self.getModule(name) {
                    DispatchQueue.main.async {
                        completion(instance)
                    }
                    return
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            DispatchQueue.main.async {
                completion(nil)
            }
            self.logger.warning("定位器", "异步获取模块 '\(name)' 超时 (\(timeout)秒)")
        }

        DispatchQueue.global(qos: .default).async(execute: workItem)
    }

    // MARK: - 等待模块加载（阻塞式）

    /// 阻塞等待模块加载，直到超时或找到模块
    /// - Parameters:
    ///   - name: 模块名称或别名
    ///   - timeout: 超时秒数
    /// - Returns: 查找结果
    /// - Warning: 此方法会阻塞调用线程，请勿在主线程调用
    public func waitForModule(name: String, timeout: TimeInterval) -> UIModuleLookupResult {
        guard !name.isEmpty else {
            logger.warning("定位器", "等待模块：模块名称为空")
            return .notFound(reason: "模块名称为空")
        }
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if let instance = getModule(name) {
                return .found(instance)
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        logger.warning("定位器", "等待模块 '\(name)' 超时 (\(timeout)秒)")
        return .timeout
    }

    // MARK: - 模块代理

    /// 设置模块代理：当名称A对应模块不存在时，返回名称B的模块实例
    /// - Parameters:
    ///   - moduleName: 被代理的模块名
    ///   - proxyModuleName: 实际提供服务的模块名
    public func setProxy(moduleName: String, proxyModuleName: String) {
        guard !moduleName.isEmpty, !proxyModuleName.isEmpty else {
            logger.warning("定位器", "设置代理失败：模块名称或代理名称为空")
            return
        }
        lock.lock()
        proxies[moduleName] = proxyModuleName
        lock.unlock()
        logger.info("定位器", "模块 '\(moduleName)' 代理设置为 '\(proxyModuleName)'")
    }

    /// 移除模块代理
    /// - Parameter moduleName: 被代理的模块名
    public func removeProxy(moduleName: String) {
        lock.lock()
        proxies.removeValue(forKey: moduleName)
        lock.unlock()
        logger.info("定位器", "模块 '\(moduleName)' 代理已移除")
    }

    // MARK: - 缓存管理

    /// 清空查找缓存
    public func clearCache() {
        lock.lock()
        lookupCache.removeAll()
        lock.unlock()
        logger.info("定位器", "查找缓存已清空")
    }

    // MARK: - 可达性检查

    /// 判断模块是否可获取（已加载且有效）
    /// - Parameter name: 模块名称或别名
    /// - Returns: 是否可获取
    public func isModuleReachable(_ name: String) -> Bool {
        getModule(name) != nil
    }
}

// MARK: - 迁回自 UI-02：class UIModuleRegistry
public final class UIModuleRegistry : @unchecked Sendable {
    public static let shared = UIModuleRegistry()
    private init() {}
    public func register(instance: UIModuleProtocol, name: String, aliases: [String] = [], priority: Int = 0) {}
    public func unregister(name: String) {}
    public func unregister(moduleID: String) -> Bool { false }
    public func isRegistered(name: String) -> Bool { false }
    public func isRegistered(moduleID: String) -> Bool { false }
    public func allRegisteredModules() -> [(moduleID: String, name: String, instance: UIModuleProtocol)] { [] }
    public func registeredCount() -> Int { 0 }
    public func get(name: String) -> UIModuleProtocol? { nil }
    public func get(moduleID: String) -> UIModuleProtocol? { nil }
    public func find(proto: Protocol) -> [UIModuleProtocol] { [] }
    public func retain(moduleID: String, instance: UIModuleProtocol) {}
    public func release(moduleID: String) {}
}

// MARK: - 迁回自 UI-02：class UIWeakRef
internal class UIWeakRef : @unchecked Sendable {
    weak var value: AnyObject?
    init(value: AnyObject) { self.value = value }
}

// MARK: - 迁回自 UI-02：enum UIModuleLookupResult
// MARK: - 迁移自 UI-03_扫描UI模块目录.swift：UIModuleScanner
// 已迁回 UI-03_扫描UI模块目录.swift：class UIModuleScanner（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-04_按顺序加载UI模块.swift：UIModuleLoader
// 已迁回 UI-04_按顺序加载UI模块.swift：class UIModuleLoader（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-04_按顺序加载UI模块.swift：UIModuleSorter
// 已迁回 UI-04_按顺序加载UI模块.swift：class UIModuleSorter（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-05_调用UI模块的start.swift：UIModuleLauncher
// 已迁回 UI-05_调用UI模块的start.swift：class UIModuleLauncher（公共类型文件禁止功能实现）


// MARK: - UIUnifiedRegistry 兼容扩展
// UIUnifiedRegistry 兼容方法已迁移到 UI-01_统一注册表.swift。

// MARK: - 迁移自 UI-06_处理UI模块加载失败.swift：UIModuleErrorHandler
// 已迁回 UI-06_处理UI模块加载失败.swift：class UIModuleErrorHandler（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-07_动态卸载UI模块.swift：UITestModule
// 已迁回 UI-07_动态卸载UI模块.swift：class UITestModule（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-07_动态卸载UI模块.swift：UIModuleUnloader
// 已迁回 UI-07_动态卸载UI模块.swift：class UIModuleUnloader（公共类型文件禁止功能实现）



// 已迁回 UI-07_动态卸载UI模块.swift：extension UIModuleRegistry（公共类型文件禁止功能实现）

// MARK: - 迁移自 UI-08_动态加载UI模块.swift：UIModuleDynamicLoader
// 已迁回 UI-08_动态加载UI模块.swift：class UIModuleDynamicLoader（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-09_获取UI模块实例.swift：UIModuleLocator
// 已迁回 UI-09_获取UI模块实例.swift：class UIModuleLocator（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-09_获取UI模块实例.swift：UIModuleLookupResult
public enum UIModuleLookupResult {
    case found(UIModuleProtocol)
    case notFound(reason: String)
    case timeout
}

// MARK: - 迁回自 UI-02：protocol UI08TestModuleProtocol
// MARK: - 迁移自 UI-09_获取UI模块实例.swift：UIModuleRegistry
// 已迁回 UI-09_获取UI模块实例.swift：class UIModuleRegistry（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-09_获取UI模块实例.swift：UIWeakRef
// 已迁回 UI-09_获取UI模块实例.swift：class UIWeakRef（公共类型文件禁止功能实现）


// MARK: - 迁移自 UI-09_获取UI模块实例.swift：UI08TestModuleProtocol
@objc public protocol UI08TestModuleProtocol: AnyObject {
    @objc optional func testMethod()
}
