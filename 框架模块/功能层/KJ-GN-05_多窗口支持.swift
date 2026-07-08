// 功能20: 多窗口支持
// 对应: 模块可拥有独立窗口（如 KLine、新闻浮窗等），由管理器统一跟踪
// 优先级: P2

import Foundation
import AppKit

// MARK: - 模块窗口管理器

/// 多窗口管理单例
/// 管理模块窗口的注册、注销、查询
/// 不负责实际的 NSWindow 创建和渲染，只记录窗口状态
public final class KJModuleWindowManager: @unchecked Sendable {
    
    // MARK: - 单例
    public static let shared = KJModuleWindowManager()
    
    // MARK: - 私有状态
    private var windows: [String: KJModuleWindow] = [:]
    private var moduleWindows: [String: [String]] = [:]
    private var lock = os_unfair_lock()
    private let logger = KJModuleLogger.shared
    
    private init() {}
    
    // MARK: - 注册 / 注销
    
    /// 注册窗口
    /// - Parameters:
    ///   - window: 模块窗口信息
    ///   - moduleName: 模块名称
    /// - Returns: 是否注册成功
    @discardableResult
    public func registerWindow(_ window: KJModuleWindow, for moduleName: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        guard !window.identifier.isEmpty, !moduleName.isEmpty else {
            logger.warning("KJModuleWindowManager", "注册失败: 标识符或模块名不能为空")
            return false
        }
        
        guard windows[window.identifier] == nil else {
            logger.warning("KJModuleWindowManager", "注册失败: 窗口 '\(window.identifier)' 已存在")
            return false
        }
        
        windows[window.identifier] = window
        moduleWindows[moduleName, default: []].append(window.identifier)
        
        logger.info("KJModuleWindowManager", "窗口 '\(window.title)' 已注册到模块 \(moduleName)")
        return true
    }
    
    /// 注销指定标识符的窗口
    /// - Parameter identifier: 窗口标识符
    /// - Returns: 是否注销成功
    @discardableResult
    public func unregisterWindow(identifier: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        guard windows[identifier] != nil else {
            logger.warning("KJModuleWindowManager", "注销失败: 窗口 '\(identifier)' 不存在")
            return false
        }
        
        windows.removeValue(forKey: identifier)
        
        // 从所有模块的列表中移除
        for (module, var items) in moduleWindows {
            items.removeAll { $0 == identifier }
            moduleWindows[module] = items
        }
        
        logger.info("KJModuleWindowManager", "窗口 '\(identifier)' 已注销")
        return true
    }
    
    /// 注销指定模块的所有窗口
    /// - Parameter moduleName: 模块名称
    /// - Returns: 注销的窗口数量
    @discardableResult
    public func unregisterAllWindows(for moduleName: String) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        guard let items = moduleWindows[moduleName] else {
            return 0
        }
        
        for identifier in items {
            windows.removeValue(forKey: identifier)
        }
        
        moduleWindows.removeValue(forKey: moduleName)
        
        logger.info("KJModuleWindowManager", "模块 \(moduleName) 的 \(items.count) 个窗口已注销")
        return items.count
    }
    
    // MARK: - 查询
    
    /// 获取所有窗口标识符
    public var allWindowIdentifiers: [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return Array(windows.keys)
    }
    
    /// 获取指定模块的窗口标识符
    /// - Parameter moduleName: 模块名称
    /// - Returns: 窗口标识符列表
    public func windowIdentifiers(for moduleName: String) -> [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return moduleWindows[moduleName] ?? []
    }
    
    /// 获取窗口信息
    /// - Parameter identifier: 窗口标识符
    /// - Returns: 窗口信息
    public func window(for identifier: String) -> KJModuleWindow? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return windows[identifier]
    }
    
    /// 检查窗口是否存在
    /// - Parameter identifier: 窗口标识符
    /// - Returns: 是否存在
    public func hasWindow(_ identifier: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return windows[identifier] != nil
    }
    
    /// 获取指定模块的所有窗口
    /// - Parameter moduleName: 模块名称
    /// - Returns: 窗口信息列表
    public func windows(for moduleName: String) -> [KJModuleWindow] {
        os_unfair_lock_lock(&lock)
        let identifiers = moduleWindows[moduleName] ?? []
        let result = identifiers.compactMap { windows[$0] }
        os_unfair_lock_unlock(&lock)
        return result
    }
    
    // MARK: - 状态更新
    
    /// 更新窗口可见性
    /// - Parameters:
    ///   - identifier: 窗口标识符
    ///   - isVisible: 是否可见
    /// - Returns: 是否更新成功
    @discardableResult
    public func setVisibility(_ identifier: String, isVisible: Bool) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        guard var window = windows[identifier] else {
            return false
        }
        
        window.isVisible = isVisible
        windows[identifier] = window
        return true
    }
    
    /// 更新窗口位置
    /// - Parameters:
    ///   - identifier: 窗口标识符
    ///   - frame: 新位置
    /// - Returns: 是否更新成功
    @discardableResult
    public func setFrame(_ identifier: String, frame: NSRect) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        guard var window = windows[identifier] else {
            return false
        }
        
        window.frame = frame
        windows[identifier] = window
        return true
    }
}
