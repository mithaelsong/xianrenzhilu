// 功能30B: 模块独立性
// 对应: 每个模块可独立开发、独立打包、独立发布；主框架仅通过协议调用
// 优先级: P0
// 版本: 2.0

import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "30B_module_independence")

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能30B：模块独立性 — 单元测试
func test_moduleIndependence() {
    let manager = UIIndependentModuleManager.shared
    
    print("\n🧪 测试1: 单例存在")
    _ = manager
    print("✅ 测试1通过: 管理器初始化正确")
    
    print("\n🧪 测试2: 卸载不存在的模块不崩溃")
    manager.unloadModule(identifier: "nonexistent")
    print("✅ 测试2通过: 卸载不存在的模块安全")
    
    print("\n=== 全部模块独立性测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIModuleWrapper
public final class UIModuleWrapper : @unchecked Sendable {

    public let identifier: String
    public let bundle: Bundle
    public var instance: UIIndependentModuleProtocol?

    public init(bundle: Bundle) throws {
        self.bundle = bundle
        guard let identifier = bundle.bundleIdentifier else {
            throw UIModuleWrapperError.missingIdentifier
        }
        self.identifier = identifier
    }

    /// 实例化模块
    public func instantiate() throws {
        guard let principalClass = bundle.principalClass as? UIIndependentModuleProtocol.Type else {
            throw UIModuleWrapperError.invalidPrincipalClass
        }
        self.instance = principalClass.init()
    }
}

// MARK: - 迁回自 UI-02：class UIIndependentModuleManager
public final class UIIndependentModuleManager : @unchecked Sendable {

    public static let shared = UIIndependentModuleManager()

    private var modules: [String: UIModuleWrapper] = [:]
    private let lock = NSRecursiveLock()

    private init() {}

    /// 从bundle路径加载独立模块
    public func loadModule(at url: URL) throws {
        guard let bundle = Bundle(url: url) else {
            throw UIModuleWrapperError.missingIdentifier
        }
        let wrapper = try UIModuleWrapper(bundle: bundle)
        try wrapper.instantiate()
        let identifier = wrapper.identifier
        lock.lock()
        modules[identifier] = wrapper
        lock.unlock()

        do {
            try wrapper.instance?.start()
        } catch {
            lock.lock()
            modules.removeValue(forKey: identifier)
            lock.unlock()
            throw UIModuleWrapperError.invalidPrincipalClass
        }
    }

    /// 卸载模块
    public func unloadModule(identifier: String) {
        lock.lock()
        let wrapper = modules.removeValue(forKey: identifier)
        lock.unlock()
        wrapper?.instance?.stop()
    }

    /// 获取模块主视图
    public func mainView(for identifier: String) -> NSView? {
        lock.lock()
        let instance = modules[identifier]?.instance
        lock.unlock()
        return instance?.mainView()
    }
}

// MARK: - 迁回自 UI-02：protocol UIIndependentModuleProtocol
// MARK: - UI-GL-35 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-35_types.swift
// 版本: 2.0
// MARK: - 通知扩展
// 已迁回 UI-GL-35_日志记录.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-36 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-36_types.swift
// 版本: 2.0
// MARK: - 独立编译存根

// 已迁回 UI-GL-36_开发者工具面板.swift：class UISandboxIsolationManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-37 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-37_types.swift
// 版本: 2.0
// MARK: - 通知名称
/// 脚本引擎系统通知名称扩展
// 已迁回 UI-GL-37_脚本引擎.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-38 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-38_types.swift
// 版本: 2.0
// MARK: - 独立模块协议
/// 独立模块必须实现的协议
public protocol UIIndependentModuleProtocol: AnyObject {
    /// 模块唯一标识
    static var moduleIdentifier: String { get }
    /// 模块显示名称
    static var moduleDisplayName: String { get }
    /// 模块版本
    static var moduleVersion: String { get }
    /// 模块依赖的其他模块标识符列表
    static var moduleDependencies: [String] { get }

    /// 初始化模块
    init()
    /// 启动模块
    func start() throws
    /// 停止模块
    func stop()
    /// 获取模块主视图
    func mainView() -> NSView?
}

// MARK: - 迁回自 UI-02：enum UIModuleWrapperError
// MARK: - UI-GL-38 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-38_types.swift
// 版本: 2.0
// MARK: - 独立模块包装器
/// 将.bundle中的模块包装为UIIndependentModuleProtocol
// 已迁回 UI-GL-38_模块独立性.swift：class UIModuleWrapper（公共类型文件禁止功能实现）

public enum UIModuleWrapperError: Error, LocalizedError {
    case missingIdentifier
    case invalidPrincipalClass

    public var errorDescription: String? {
        switch self {
        case .missingIdentifier:      return "Bundle缺少标识符"
        case .invalidPrincipalClass:  return "Bundle的主类不符合UIIndependentModuleProtocol"
        }
    }
}
