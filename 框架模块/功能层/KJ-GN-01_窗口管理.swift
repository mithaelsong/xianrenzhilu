// 功能16: 窗口管理
// 对应: 主窗口、设置窗口、关于窗口的创建与显示
// 优先级: P1

import Foundation
import os

// MARK: - 窗口记录
/// 内部窗口数据记录
private struct KJWindowRecord {
    let name: String
    var state: KJWindowState
    var frame: KJWindowFrame?
    var zIndex: Int
}

// MARK: - 窗口管理器
/// 窗口管理器 (功能16)
/// 纯数据层窗口管理器，不依赖 AppKit/NSWindow
/// 使用字符串名称标识窗口，管理窗口状态和帧信息
/// 使用 os_unfair_lock 保证线程安全和高性能
public final class KJWindowManager : @unchecked Sendable {
    public static let shared = KJWindowManager()
    
    /// 线程安全的窗口存储包装
    private final class KJWindowStorage: @unchecked Sendable {
        var windows: [String: KJWindowRecord] = [:]
        var nextZIndex: Int = 1
        var lock = os_unfair_lock()
    }
    
    private let storage = KJWindowStorage()
    private let logger = KJModuleLogger.shared
    
    /// 公共构造函数，支持创建独立实例（测试/多实例场景）
    public init() {}
    
    // MARK: - 打开/关闭窗口
    
    /// 打开或激活指定名称的窗口
    /// - Parameter name: 窗口名称
    /// - Returns: 是否成功（名称非空即成功，已存在则激活）
    @discardableResult
    public func open(windowNamed name: String) -> Bool {
        guard !name.isEmpty else {
            logger.warning("KJWindowManager", "打开窗口失败: 名称为空")
            return false
        }
        
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        
        if let existing = storage.windows[name] {
            if existing.state == .closed {
                storage.windows[name] = KJWindowRecord(
                    name: name,
                    state: .normal,
                    frame: existing.frame,
                    zIndex: storage.nextZIndex
                )
                storage.nextZIndex += 1
                logger.info("KJWindowManager", "窗口'\(name)'已从关闭状态重新打开")
            } else {
                // 已打开，提升 zIndex（相当于激活）
                storage.windows[name]?.zIndex = storage.nextZIndex
                storage.nextZIndex += 1
                logger.info("KJWindowManager", "窗口'\(name)'已打开(状态: \(existing.state.rawValue))，前置")
            }
            return true
        }
        
        storage.windows[name] = KJWindowRecord(
            name: name,
            state: .normal,
            frame: nil,
            zIndex: storage.nextZIndex
        )
        storage.nextZIndex += 1
        logger.info("KJWindowManager", "窗口'\(name)'已打开")
        return true
    }
    
    /// 关闭指定名称的窗口
    /// - Parameter name: 窗口名称
    /// - Returns: 是否成功（窗口必须存在）
    @discardableResult
    public func close(windowNamed name: String) -> Bool {
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        
        guard storage.windows[name] != nil else {
            logger.warning("KJWindowManager", "关闭窗口失败: '\(name)'未找到")
            return false
        }
        
        storage.windows[name]?.state = .closed
        logger.info("KJWindowManager", "窗口'\(name)'已关闭")
        return true
    }
    
    /// 检查窗口是否处于打开状态（非 closed）
    /// - Parameter name: 窗口名称
    /// - Returns: 是否已打开
    public func isWindowOpen(_ name: String) -> Bool {
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        
        guard let record = storage.windows[name] else {
            return false
        }
        return record.state != .closed
    }
    
    // MARK: - 窗口帧管理
    
    /// 设置窗口位置和大小
    /// - Parameters:
    ///   - name: 窗口名称
    ///   - x: 左上角 X 坐标
    ///   - y: 左上角 Y 坐标
    ///   - width: 窗口宽度（必须 > 0）
    ///   - height: 窗口高度（必须 > 0）
    /// - Returns: 是否成功（窗口必须存在且宽高合法）
    @discardableResult
    public func setWindowFrame(_ name: String, x: Double, y: Double, width: Double, height: Double) -> Bool {
        guard width > 0, height > 0 else {
            logger.warning("KJWindowManager", "设置窗口框架失败: 无效尺寸(width=\(width), height=\(height))")
            return false
        }
        
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        
        guard storage.windows[name] != nil else {
            logger.warning("KJWindowManager", "设置窗口框架失败: '\(name)'未找到")
            return false
        }
        
        storage.windows[name]?.frame = KJWindowFrame(x: x, y: y, width: width, height: height)
        logger.info("KJWindowManager", "窗口'\(name)'帧已设置为\(KJWindowFrame(x: x, y: y, width: width, height: height))")
        return true
    }
    
    /// 获取窗口帧信息
    /// - Parameter name: 窗口名称
    /// - Returns: 窗口帧元组 (x, y, width, height)，窗口不存在或无帧时返回 nil
    public func getWindowFrame(_ name: String) -> (x: Double, y: Double, width: Double, height: Double)? {
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        
        guard let frame = storage.windows[name]?.frame else {
            return nil
        }
        return (x: frame.x, y: frame.y, width: frame.width, height: frame.height)
    }
    
    // MARK: - 窗口状态操作
    
    /// 最小化窗口
    /// - Parameter name: 窗口名称
    /// - Returns: 是否成功（窗口必须存在且处于 open/fullscreen 状态）
    @discardableResult
    public func minimizeWindow(_ name: String) -> Bool {
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        
        guard let record = storage.windows[name] else {
            logger.warning("KJWindowManager", "最小化窗口失败: '\(name)'未找到")
            return false
        }
        
        guard record.state == .normal || record.state == .fullscreen else {
            logger.warning("KJWindowManager", "最小化窗口失败: '\(name)'状态为\(record.state.rawValue)，无法最小化")
            return false
        }
        
        storage.windows[name]?.state = .minimized
        logger.info("KJWindowManager", "窗口'\(name)'已最小化")
        return true
    }
    
    /// 恢复窗口（从最小化状态恢复为打开）
    /// - Parameter name: 窗口名称
    /// - Returns: 是否成功（窗口必须存在且处于 minimized 状态）
    @discardableResult
    public func restoreWindow(_ name: String) -> Bool {
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        
        guard let record = storage.windows[name] else {
            logger.warning("KJWindowManager", "恢复窗口失败: '\(name)'未找到")
            return false
        }
        
        guard record.state == .minimized else {
            logger.warning("KJWindowManager", "恢复窗口失败: '\(name)'状态为\(record.state.rawValue)，非最小化")
            return false
        }
        
        storage.windows[name]?.state = .normal
        logger.info("KJWindowManager", "窗口'\(name)'已恢复")
        return true
    }
    
    /// 将窗口前置（提升 zIndex）
    /// - Parameter name: 窗口名称
    /// - Returns: 是否成功（窗口必须存在且非 closed）
    @discardableResult
    public func bringToFront(_ name: String) -> Bool {
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        
        guard let record = storage.windows[name] else {
            logger.warning("KJWindowManager", "置顶窗口失败: '\(name)'未找到")
            return false
        }
        
        guard record.state != .closed else {
            logger.warning("KJWindowManager", "置顶窗口失败: '\(name)'已关闭")
            return false
        }
        
        storage.windows[name]?.zIndex = storage.nextZIndex
        storage.nextZIndex += 1
        logger.info("KJWindowManager", "窗口'\(name)'已前置(zIndex: \(storage.windows[name]!.zIndex))")
        return true
    }
    
    /// 列出所有已打开的窗口名称（按 zIndex 排序，最前在前）
    /// - Returns: 所有非 closed 状态的窗口名称数组
    public func listOpenWindows() -> [String] {
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        
        return storage.windows
            .filter { $0.value.state != .closed }
            .sorted { $0.value.zIndex > $1.value.zIndex }
            .map { $0.key }
    }
    
    /// 获取窗口当前状态（内部诊断用）
    /// - Parameter name: 窗口名称
    /// - Returns: 窗口状态，不存在时返回 nil
    public func getWindowState(_ name: String) -> KJWindowState? {
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        return storage.windows[name]?.state
    }
    
    /// 获取所有窗口的调试信息（内部诊断用）
    /// - Returns: 窗口名称到状态的映射
    public func dumpWindows() -> [String: KJWindowState] {
        os_unfair_lock_lock(&storage.lock)
        defer { os_unfair_lock_unlock(&storage.lock) }
        return storage.windows.mapValues { $0.state }
    }
}
