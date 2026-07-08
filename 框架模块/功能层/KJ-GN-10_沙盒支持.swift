// 功能25: 沙盒支持（可选）
// 对应: 如果上架 Mac App Store，需要支持沙盒
// 优先级: P3 (交易软件通常不上架，但预留)
//
// 核心能力:
// 1. 检测当前是否在沙盒环境
// 2. 获取沙盒容器目录（Documents/Caches/Tmp等）
// 3. 安全访问安全区文件（Security-Scoped Resource）
// 4. 沙盒文件读写保护检查
// 5. 线程安全（os_unfair_lock）
// 6. 完整测试覆盖

import Foundation
import AppKit
import Darwin
import os.log

// MARK: - 日志记录器（轻量封装）


// MARK: - KJSandboxManager 单例
/// 沙盒管理器：负责检测沙盒环境、管理沙盒目录、安全区资源访问
public final class KJSandboxManager : @unchecked Sendable {
    
    // MARK: - 单例
    public static let shared = KJSandboxManager()
    
    // MARK: - 线程安全锁
    private var lock = os_unfair_lock()
    
    // MARK: - 日志记录器
    private static let logger = KJModuleLogger.shared
    
    // MARK: - 缓存属性
    private var _cachedIsSandboxed: Bool?
    private var _cachedContainerDirectory: URL?
    private var _cachedDocumentsDirectory: URL?
    private var _cachedCacheDirectory: URL?
    private var _cachedTemporaryDirectory: URL?
    
    // MARK: - 权限配置
    public var permissions: KJSandboxPermissions = .default {
        didSet {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            KJSandboxManager.logger.info("KJSandboxManager", "权限配置已更新")
        }
    }
    
    // MARK: - 初始化

    private init() {}
    
    // MARK: - 沙盒环境检测
    
    /// 检测当前应用是否在沙盒环境中运行
    public var isSandboxed: Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        // 使用缓存结果
        if let cached = _cachedIsSandboxed {
            return cached
        }
        
        let result = detectSandboxEnvironment()
        _cachedIsSandboxed = result
        return result
    }
    
    /// 内部沙盒检测逻辑（多种方式综合判断）
    private func detectSandboxEnvironment() -> Bool {
        // 方法1: 检查环境变量 APP_SANDBOX_CONTAINER_ID
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil {
            return true
        }
        
        // 方法2: 检查容器目录是否存在且当前进程可访问
        if let containerDir = getContainerDirectory(),
           FileManager.default.fileExists(atPath: containerDir.path) {
            // 进一步检查路径特征：包含 "Containers" 和 bundle identifier
            let path = containerDir.path
            if path.contains("Containers/") && path.contains("Data/Application/") {
                return true
            }
        }
        
        // 方法3: 检查是否无法访问沙盒外敏感路径（如 /Users/Shared）
        // 沙盒应用通常无法访问其他用户目录
        let testPath = "/Users/Shared"
        let canAccessShared = FileManager.default.isReadableFile(atPath: testPath)
        
        // 方法4: 检查 home 目录是否被重定向到容器
        let homeDir = NSHomeDirectory()
        if homeDir.contains("Containers/") {
            return true
        }
        
        // 综合判断：如果无法访问共享目录且 home 目录不是标准路径，可能是沙盒
        if !canAccessShared && homeDir != NSHomeDirectoryForUser(NSUserName()) {
            return true
        }
        
        return false
    }
    
    // MARK: - 沙盒目录获取
    
    /// 沙盒容器目录（沙盒应用的根目录）
    /// 非沙盒环境下返回 nil
    public var containerDirectory: URL? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if let cached = _cachedContainerDirectory {
            return cached
        }
        
        let result = getContainerDirectory()
        _cachedContainerDirectory = result
        return result
    }
    
    /// 沙盒临时目录
    public var temporaryDirectory: URL? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if let cached = _cachedTemporaryDirectory {
            return cached
        }
        
        let result = getTemporaryDirectory()
        _cachedTemporaryDirectory = result
        return result
    }
    
    /// 沙盒缓存目录
    public var cacheDirectory: URL? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if let cached = _cachedCacheDirectory {
            return cached
        }
        
        let result = getCacheDirectory()
        _cachedCacheDirectory = result
        return result
    }
    
    /// 沙盒文档目录
    public var documentsDirectory: URL? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if let cached = _cachedDocumentsDirectory {
            return cached
        }
        
        let result = getDocumentsDirectory()
        _cachedDocumentsDirectory = result
        return result
    }
    
    // MARK: - 目录获取内部实现
    
    private func getContainerDirectory() -> URL? {
        // 沙盒容器目录通常是 ~/Library/Containers/<bundle-id>/
        let homeDir = NSHomeDirectory()
        
        // 如果 home 目录包含 Containers，说明是沙盒环境
        if homeDir.contains("Containers/") {
            let url = URL(fileURLWithPath: homeDir)
            // 向上追溯到容器根目录（通常是 Data 的上级目录）
            var containerURL = url
            // 从 .../Containers/<bundle-id>/Data 向上退到 .../Containers/<bundle-id>/
            if url.path.contains("/Data/") {
                containerURL = url.deletingLastPathComponent().deletingLastPathComponent()
            }
            return containerURL
        }
        
        // 尝试通过 bundle identifier 构建容器路径
        if let bundleId = Bundle.main.bundleIdentifier {
            let potentialPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/\(bundleId)")
            if FileManager.default.fileExists(atPath: potentialPath.path) {
                return potentialPath
            }
        }
        
        return nil
    }
    
    private func getTemporaryDirectory() -> URL? {
        // 沙盒临时目录
        let tempDir = FileManager.default.temporaryDirectory
        
        // 确保目录存在
        try? FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        return tempDir
    }
    
    private func getCacheDirectory() -> URL? {
        // 获取标准缓存目录
        guard let cachesURL = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        
        // 在沙盒环境下，缓存目录已经在容器内
        // 非沙盒环境下，追加应用标识子目录
        if !isSandboxed {
            let appCachesURL = cachesURL.appendingPathComponent("XianRenZhiLu", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: appCachesURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return appCachesURL
        }
        
        return cachesURL
    }
    
    private func getDocumentsDirectory() -> URL? {
        // 获取标准文档目录
        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        
        // 在沙盒环境下，文档目录已经在容器内
        // 非沙盒环境下，追加应用标识子目录
        if !isSandboxed {
            let appDocumentsURL = documentsURL.appendingPathComponent("XianRenZhiLu", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: appDocumentsURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return appDocumentsURL
        }
        
        return documentsURL
    }
    
    // MARK: - 安全区资源访问
    
    /// 安全访问安全区文件（Security-Scoped Resource）
    /// 用于访问用户通过 NSOpenPanel/NSSavePanel 选择的文件
    /// - Parameter url: 需要访问的文件 URL（通常来自文件选择面板）
    /// - Returns: 访问结果，包含是否成功和停止访问的 handler
    public func accessSecurityScopedResource(url: URL) -> KJSecurityScopedAccessResult {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        // 检查 URL 是否是安全区资源
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        
        if isSecurityScoped {
            KJSandboxManager.logger.info("KJSandboxManager", "已开始访问安全区资源: \(url.path)")
            
            return KJSecurityScopedAccessResult(
                startAccessing: true,
                stopHandler: {
                    url.stopAccessingSecurityScopedResource()
                    KJSandboxManager.logger.info("KJSandboxManager", "已停止访问安全区资源: \(url.path)")
                }
            )
        } else {
            // 如果不是安全区资源，直接返回可访问（非沙盒环境或已授权）
            return KJSecurityScopedAccessResult(
                startAccessing: true,
                stopHandler: {}
            )
        }
    }
    
    /// 使用 bookmark data 重新获取安全区资源访问权限
    /// - Parameter bookmarkData: 之前保存的 bookmark data
    /// - Returns: 解析后的 URL 和访问结果
    public func resolveBookmarkData(_ bookmarkData: Data) -> (url: URL?, result: KJSecurityScopedAccessResult?) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                KJSandboxManager.logger.warning("KJSandboxManager", "Bookmark data已过期，需要重新创建")
            }
            
            let result = accessSecurityScopedResource(url: url)
            return (url, result)
            
        } catch {
            KJSandboxManager.logger.error("KJSandboxManager", "解析bookmark data失败: \(error)")
            return (nil, nil)
        }
    }
    
    /// 创建文件的 bookmark data 用于后续安全访问
    /// - Parameter url: 需要创建 bookmark 的文件 URL
    /// - Returns: bookmark data
    public func createBookmarkData(for url: URL) -> Data? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmarkData
        } catch {
            KJSandboxManager.logger.error("KJSandboxManager", "创建bookmark data失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 文件读写保护检查
    
    /// 检查文件读取权限
    public func canReadFile(at url: URL) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        return FileManager.default.isReadableFile(atPath: url.path)
    }
    
    /// 检查文件写入权限
    public func canWriteFile(at url: URL) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        return FileManager.default.isWritableFile(atPath: url.path)
    }
    
    /// 完整文件访问检查
    public func checkFileAccess(at url: URL) -> KJFileAccessCheckResult {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        let path = url.path
        let fm = FileManager.default
        
        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: path, isDirectory: &isDir)
        let canRead = fm.isReadableFile(atPath: path)
        let canWrite = fm.isWritableFile(atPath: path)
        
        return KJFileAccessCheckResult(
            canRead: canRead,
            canWrite: canWrite,
            exists: exists,
            isDirectory: isDir.boolValue,
            error: nil
        )
    }
    
    /// 检查目录是否可创建文件（测试写入能力）
    public func canCreateFileInDirectory(at url: URL) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        let testFileName = ".sandbox_write_test_\(UUID().uuidString)"
        let testFileURL = url.appendingPathComponent(testFileName)
        
        do {
            // 尝试创建空文件
            try Data().write(to: testFileURL)
            // 清理测试文件
            try? FileManager.default.removeItem(at: testFileURL)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - 权限检查（兼容原有 API）
    
    public func checkPermission(_ type: KJPermissionType) -> Bool {
        switch type {
        case .network:
            return permissions.networkAccess
        case .fileRead:
            return permissions.fileRead
        case .fileWrite:
            return permissions.fileWrite
        case .userSelectedFile:
            return permissions.userSelectedFileAccess
        }
    }
    
    public func requestPermission(_ type: KJPermissionType, completion: @escaping (Bool) -> Void) {
        // 实际实现需要调用系统 API（如 NSOpenPanel 等）
        // 这里简化处理，直接返回当前权限状态
        completion(checkPermission(type))
    }
    
    // MARK: - 安全路径获取（兼容原有 API）
    
    public func safePath(for type: KJSandboxPathType) -> URL? {
        switch type {
        case .documents:
            return documentsDirectory
        case .applicationSupport:
            guard let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else { return nil }
            
            let appSupportURL = appSupport.appendingPathComponent("XianRenZhiLu", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return appSupportURL
            
        case .caches:
            return cacheDirectory
        case .temp:
            return temporaryDirectory
        }
    }
    
    // MARK: - 清理缓存
    
    /// 清除所有缓存的目录信息（用于环境变化时刷新）
    public func invalidateCache() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        _cachedIsSandboxed = nil
        _cachedContainerDirectory = nil
        _cachedDocumentsDirectory = nil
        _cachedCacheDirectory = nil
        _cachedTemporaryDirectory = nil
        
        KJSandboxManager.logger.info("KJSandboxManager", "缓存已清除")
    }
}

// MARK: - 兼容层：KJSandboxConfig（保留原有接口）
@available(*, deprecated, renamed: "KJSandboxManager")
public final class KJSandboxConfig : @unchecked Sendable {
    public static let shared = KJSandboxConfig()
    
    public var currentPermissions: KJSandboxPermissions {
        get { KJSandboxManager.shared.permissions }
        set { KJSandboxManager.shared.permissions = newValue }
    }
    
    private init() {}
    
    public func checkPermission(_ type: KJPermissionType) -> Bool {
        return KJSandboxManager.shared.checkPermission(type)
    }
    
    public func requestPermission(_ type: KJPermissionType, completion: @escaping (Bool) -> Void) {
        KJSandboxManager.shared.requestPermission(type, completion: completion)
    }
    
    public static func safePath(for type: KJSandboxPathType) -> URL? {
        return KJSandboxManager.shared.safePath(for: type)
    }
}

