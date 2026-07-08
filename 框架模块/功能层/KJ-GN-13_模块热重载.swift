import Foundation
import os


// MARK: - 模块热重载器

/// 模块热重载管理器（功能28）
/// 开发模式下监视模块文件变化，自动或手动触发重载
public final class KJModuleHotReloader: @unchecked Sendable {
    
    // MARK: - 单例
    
    public static let shared = KJModuleHotReloader()
    
    // MARK: - 属性
    
    /// 是否开启自动重载（文件变化时自动触发）
    public var autoReload: Bool = true
    
    /// 开发模式开关（非开发模式时所有操作返回 false）
    public var isDevelopmentMode: Bool = true
    
    /// 代理对象，提供实际加载/卸载能力
    public weak var delegate: KJModuleHotReloaderDelegate?
    
    /// 当前正在监视的模块名列表
    public var watchedModules: [String] {
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        return Array(_watchedModules.keys)
    }
    
    /// 热重载历史记录
    public var reloadHistory: [KJReloadRecord] {
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        return _history
    }
    
    // MARK: - 私有状态
    
    private var _watchedModules: [String: URL] = [:]
    private var _sources: [String: DispatchSourceFileSystemObject] = [:]
    private var _history: [KJReloadRecord] = []
    private var _lock: os_unfair_lock = .init()
    
    // MARK: - 初始化
    
    private init() {}
    
    // MARK: - 监视控制
    
    /// 开始监视指定模块的目录变化
    /// - Parameters:
    ///   - moduleName: 模块名称
    ///   - directoryURL: 模块所在目录
    /// - Returns: 是否成功开始监视
    @discardableResult
    public func startWatching(moduleName: String, directoryURL: URL) -> Bool {
        guard isDevelopmentMode else {
            log("热重载仅在开发模式可用")
            return false
        }
        
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        
        guard _sources[moduleName] == nil else {
            log("模块 \(moduleName) 已在监视中")
            return false
        }
        
        let path = directoryURL.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            log("无法打开目录进行监视: \(path)")
            return false
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.autoReload {
                _ = self.hotReload(moduleName: moduleName)
            } else {
                self.log("检测到 \(moduleName) 文件变化，自动重载已关闭")
            }
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        source.resume()
        _sources[moduleName] = source
        _watchedModules[moduleName] = directoryURL
        log("开始监视模块 \(moduleName): \(path)")
        return true
    }
    
    /// 停止监视指定模块
    /// - Parameter moduleName: 模块名称
    /// - Returns: 是否成功停止
    @discardableResult
    public func stopWatching(moduleName: String) -> Bool {
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        
        guard let source = _sources.removeValue(forKey: moduleName) else {
            log("模块 \(moduleName) 未在监视中")
            return false
        }
        
        source.cancel()
        _watchedModules.removeValue(forKey: moduleName)
        log("停止监视模块 \(moduleName)")
        return true
    }
    
    /// 停止所有监视
    public func stopAllWatching() {
        os_unfair_lock_lock(&_lock)
        let modules = Array(_watchedModules.keys)
        os_unfair_lock_unlock(&_lock)
        
        for module in modules {
            stopWatching(moduleName: module)
        }
    }
    
    // MARK: - 热重载
    
    /// 手动热重载指定模块
    /// - Parameter moduleName: 模块名称
    /// - Returns: 重载是否成功
    @discardableResult
    public func hotReload(moduleName: String) -> Bool {
        guard isDevelopmentMode else {
            log("热重载仅在开发模式可用")
            record(moduleName: moduleName, success: false, error: "非开发模式")
            return false
        }
        
        os_unfair_lock_lock(&_lock)
        let hasWatched = _watchedModules[moduleName] != nil
        os_unfair_lock_unlock(&_lock)
        
        guard hasWatched || delegate != nil else {
            log("模块 \(moduleName) 未在监视中且未设置代理")
            record(moduleName: moduleName, success: false, error: "模块未在监视中")
            return false
        }
        
        log("正在热重载模块 \(moduleName)...")
        
        var success = false
        var errorMsg: String? = nil
        
        if let delegate = delegate {
            if let sourceDir = _watchedModules[moduleName] {
                _ = delegate.compileModule(moduleName: moduleName, sourceDirectory: sourceDir)
            }
            success = delegate.performHotReload(moduleName: moduleName)
            if !success {
                errorMsg = "代理重载失败"
            }
        } else {
            success = performDefaultReload(moduleName: moduleName)
            if !success {
                errorMsg = "默认重载流程失败"
            }
        }
        
        record(moduleName: moduleName, success: success, error: errorMsg)
        log("模块 \(moduleName) 热重载\(success ? "成功" : "失败")")
        return success
    }
    
    // MARK: - 历史管理
    
    /// 清空热重载历史
    public func clearHistory() {
        os_unfair_lock_lock(&_lock)
        _history.removeAll()
        os_unfair_lock_unlock(&_lock)
    }
    
    // MARK: - 私有方法
    
    private func record(moduleName: String, success: Bool, error: String? = nil) {
        let record = KJReloadRecord(
            moduleID: moduleName,
            oldVersion: error ?? "",
            newVersion: success ? "成功" : "失败",
            timestamp: Date()
        )
        os_unfair_lock_lock(&_lock)
        _history.append(record)
        os_unfair_lock_unlock(&_lock)
    }
    
    /// 默认重载流程（兼容项目已有架构）
    private func performDefaultReload(moduleName: String) -> Bool {
        // 默认重载流程：由delegate提供实际能力
        return false
    }
    
    private func log(_ message: String) {
        print("[KJModuleHotReloader] \(message)")
    }
}
