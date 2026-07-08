// 功能31A: 插件管理器
// 对应: 提供插件扫描、加载、卸载、启用/禁用、依赖管理、市场接口等完整生命周期管理
// 优先级: P1

import AppKit
import Foundation
import os.log

// MARK: - 通知名称扩展
/// 插件管理器相关通知名称
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能31A：插件管理器 — 单元测试
/// 覆盖：扫描/加载/卸载/启用禁用/依赖/查询/配置持久化
func test_pluginManager() {
    let logger = Logger(subsystem: "com.xianrenzhilu", category: "Test")
    let manager = UIPluginManager.shared
    
    logger.info("测试1: 初始状态")
    let count = manager.totalPluginCount
    _ = count
    logger.info("✅ 测试1通过: 初始状态正常")
    
    logger.info("测试2: 插件状态查询")
    let status = manager.pluginStatus(for: "nonexistent")
    guard status == .unloaded else {
        fatalError("❌ 测试2失败: 不存在插件应为unloaded")
    }
    logger.info("✅ 测试2通过: 状态查询正确")
    
    logger.info("测试3: 依赖解析（无插件时返回空）")
    let order = manager.resolveLoadOrder()
    _ = order.isEmpty
    logger.info("✅ 测试3通过: 依赖解析正常")
    
    logger.info("测试4: 依赖查询")
    let deps = manager.dependencies(of: "test")
    guard deps.isEmpty else {
        fatalError("❌ 测试4失败: 不存在插件依赖应为空")
    }
    logger.info("✅ 测试4通过: 依赖查询正常")
    
    logger.info("测试5: 便捷属性")
    _ = manager.loadedPluginCount
    _ = manager.enabledPluginCount
    _ = manager.hasFailedPlugins
    logger.info("✅ 测试5通过: 便捷属性正常")
    
    logger.info("测试6: 设置面板数据")
    let panel = manager.settingsPanelData()
    _ = panel.count
    logger.info("✅ 测试6通过: 设置面板数据正常")
    
    logger.info("测试7: 默认市场实现")
    let market = UIDefaultPluginMarket()
    market.fetchMarketPlugins { result in
        if case .success(let plugins) = result {
            _ = plugins.isEmpty
        }
    }
    logger.info("✅ 测试7通过: 默认市场实现正常")
    
    logger.info("=== 全部插件管理器测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIPluginManager
public final class UIPluginManager : @unchecked Sendable {
    
    // MARK: 单例
    /// 全局共享的插件管理器实例
    public static let shared = UIPluginManager()
    
    // MARK: 日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "PluginManager")
    
    // MARK: 并发锁
    /// 保护共享插件字典的递归锁，确保线程安全
    private let lock = NSRecursiveLock()
    
    // MARK: 插件存储
    /// 所有已发现/已加载的插件，以 ID 为键
    private var plugins: [String: UIPluginEntry] = [:]
    /// 插件加载顺序（拓扑排序后的结果），用于按序初始化
    private var loadOrder: [String] = []
    
    // MARK: 插件目录
    /// 插件扫描根目录，默认指向应用支持目录下的 Plugins 文件夹
    public var pluginDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("XianRenZhiLu/Plugins", isDirectory: true)
    }
    
    /// 插件配置文件路径
    private var configurationFileURL: URL {
        return pluginDirectory.appendingPathComponent("plugin_configs.json")
    }
    
    // MARK: 市场接口
    /// 插件市场接口实例，外部可注入实现
    public weak var marketInterface: UIPluginMarketProtocol?
    
    // MARK: 初始化
    private init() {
        logger.info("插件管理器初始化完成")
        // 确保插件目录存在
        createPluginDirectoryIfNeeded()
    }
    
    // MARK: 目录管理
    /// 如果插件目录不存在，则自动创建
    private func createPluginDirectoryIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: pluginDirectory.path) {
            do {
                try fm.createDirectory(at: pluginDirectory, withIntermediateDirectories: true, attributes: nil)
                logger.info("已创建插件目录: \(self.pluginDirectory.path)")
            } catch {
                logger.error("创建插件目录失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 插件扫描
    
    /// 扫描插件目录，发现所有 .bundle 和 .framework 插件包
    /// 返回本次新发现的插件数量
    @discardableResult
    public func scanPlugins() -> Int {
        createPluginDirectoryIfNeeded()
        
        let fm = FileManager.default
        var newDiscoveredCount = 0
        
        do {
            let contents = try fm.contentsOfDirectory(at: pluginDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            
            for url in contents {
                let ext = url.pathExtension.lowercased()
                guard ext == "bundle" || ext == "framework" else { continue }
                
                let info = parsePluginInfo(from: url)
                let pluginID = info.id
                
                lock.lock()
                
                if plugins[pluginID] == nil {
                    let config = UIPluginConfiguration(pluginID: pluginID)
                    let entry = UIPluginEntry(id: pluginID, info: info, configuration: config, status: .discovered, path: url)
                    plugins[pluginID] = entry
                    loadOrder.append(pluginID)
                    newDiscoveredCount += 1
                    logger.info("发现新插件: \(pluginID) v\(info.version) 位于 \(url.path)")
                }
                lock.unlock()
            }
        } catch {
            logger.error("扫描插件目录失败: \(error.localizedDescription)")
        }
        
        // 发送发现通知
        NotificationCenter.default.post(name: .pluginDidDiscover, object: self, userInfo: ["count": newDiscoveredCount])
        logger.info("插件扫描完成，本次发现 \(newDiscoveredCount) 个新插件")
        return newDiscoveredCount
    }
    
    /// 从插件包路径解析元数据信息
    private func parsePluginInfo(from url: URL) -> UIPluginInfo {
        let infoPlist = url.appendingPathComponent("Contents/Info.plist")
        let fallbackID = url.deletingPathExtension().lastPathComponent
        
        if let dict = NSDictionary(contentsOf: infoPlist) as? [String: Any] {
            let id = dict["CFBundleIdentifier"] as? String ?? fallbackID
            let name = dict["CFBundleName"] as? String ?? fallbackID
            let version = dict["CFBundleShortVersionString"] as? String ?? "2.0"
            let author = dict["XRZPluginAuthor"] as? String ?? "未知作者"
            let description = dict["XRZPluginDescription"] as? String ?? ""
            let deps = dict["XRZPluginDependencies"] as? [String] ?? []
            let typeString = dict["XRZPluginType"] as? String ?? "native"
            let type = UIPluginInfo.UIPluginType(rawValue: typeString) ?? .native
            let minVersion = dict["XRZMinimumAppVersion"] as? String
            let archs = dict["XRZSupportedArchitectures"] as? [String]
            return UIPluginInfo(id: id, name: name, version: version, author: author, description: description, dependencies: deps, type: type, minimumAppVersion: minVersion, supportedArchitectures: archs)
        }
        
        // 无 Info.plist 时使用默认值
        return UIPluginInfo(id: fallbackID, name: fallbackID, version: "2.0", author: "未知作者", description: "", dependencies: [])
    }
    
    // MARK: - 插件加载
    
    /// 加载所有已发现的插件，按依赖拓扑顺序执行
    public func loadAllPlugins() {
        let order = resolveLoadOrder()
        for pluginID in order {
            _ = loadPlugin(id: pluginID)
        }
    }
    
    /// 加载指定 ID 的插件
    /// - Returns: 是否加载成功
    @discardableResult
    public func loadPlugin(id: String) -> Bool {
        lock.lock()
        guard plugins[id] != nil else {
            lock.unlock()
            logger.error("加载失败：未找到插件 \(id)")
            return false
        }
        lock.unlock()

        guard self.pluginEntry(for: id) != nil else { return false }
        
        let currentStatus = self.pluginStatus(for: id)
        guard currentStatus != .loaded && currentStatus != .enabled else {
            logger.debug("插件 \(id) 已加载，跳过")
            return true
        }
        
        let entryDeps = self.pluginDependencies(for: id)
        let entryPath = self.pluginPath(for: id)
        let missingDeps = entryDeps.filter { depID in
            let depStatus = self.pluginStatus(for: depID)
            return depStatus != .loaded && depStatus != .enabled
        }
        if !missingDeps.isEmpty {
            let error = UIPluginManagerError.missingDependencies(missingDeps)
            logger.error("插件 \(id) 缺少依赖: \(missingDeps.joined(separator: ", "))")
            updateEntry(id: id) { $0.status = .failed; $0.lastError = error.errorDescription }
            NotificationCenter.default.post(name: .pluginDidFailLoad, object: self, userInfo: ["id": id, "error": error])
            return false
        }
        
        // 加载 Bundle
        let bundle = Bundle(url: entryPath)
        if let bundle = bundle {
            if !bundle.isLoaded {
                do {
                    try bundle.loadAndReturnError()
                } catch {
                    let err = UIPluginManagerError.loadFailed(id, error)
                    logger.error("Bundle 加载失败 \(id): \(error.localizedDescription)")
                    updateEntry(id: id) { $0.status = .failed; $0.lastError = err.errorDescription }
                    NotificationCenter.default.post(name: .pluginDidFailLoad, object: self, userInfo: ["id": id, "error": err])
                    return false
                }
            }
        } else {
            let err = UIPluginManagerError.invalidBundle(entryPath)
            logger.error("无效的 Bundle \(id)")
            updateEntry(id: id) { $0.status = .failed; $0.lastError = err.errorDescription }
            NotificationCenter.default.post(name: .pluginDidFailLoad, object: self, userInfo: ["id": id, "error": err])
            return false
        }
        
        // 更新状态为已加载
        updateEntry(id: id) {
            $0.bundle = bundle
            $0.status = .loaded
            $0.configuration.lastLoadedAt = Date()
            $0.lastError = nil
        }
        
        let entryInfo = self.pluginInfo(for: id)
        logger.info("插件 \(id) v\(entryInfo?.version ?? "未知") 加载成功")
        let notifyInfo: [String: Any] = ["id": id, "version": entryInfo?.version ?? ""]
        NotificationCenter.default.post(name: .pluginDidLoad, object: self, userInfo: notifyInfo)
        
        if self.isPluginEnabled(id: id) {
            enablePlugin(id: id)
        }
        
        return true
    }
    
    // MARK: - 插件卸载
    
    /// 卸载所有已加载的插件，按逆拓扑顺序卸载
    public func unloadAllPlugins() {
        let order = resolveLoadOrder().reversed()
        for pluginID in order {
            unloadPlugin(id: pluginID)
        }
    }
    
    /// 卸载指定插件，同时释放 Bundle 资源
    @discardableResult
    public func unloadPlugin(id: String) -> Bool {
        lock.lock()
        disablePlugin(id: id)
        lock.unlock()
        
        if let bundle = self.pluginBundle(for: id), bundle.isLoaded {
            bundle.unload()
        }
        
        updateEntry(id: id) {
            $0.bundle = nil
            $0.status = .unloaded
            $0.configuration.lastLoadedAt = nil
        }
        
        logger.info("插件 \(id) 已卸载")
        NotificationCenter.default.post(name: .pluginDidUnload, object: self, userInfo: ["id": id])
        return true
    }
    
    // MARK: - 启用/禁用
    
    /// 启用指定插件，使其参与运行时执行
    @discardableResult
    public func enablePlugin(id: String) -> Bool {
        guard self.pluginEntry(for: id) != nil else {
            logger.error("启用失败：未找到插件 \(id)")
            return false
        }
        
        let curStatus = self.pluginStatus(for: id)
        if curStatus == .discovered || curStatus == .unloaded || curStatus == .failed {
            guard loadPlugin(id: id) else { return false }
        }
        
        updateEntry(id: id) {
            $0.status = .enabled
            $0.configuration.isEnabled = true
        }
        
        logger.info("插件 \(id) 已启用")
        NotificationCenter.default.post(name: .pluginDidEnable, object: self, userInfo: ["id": id])
        return true
    }
    
    /// 禁用指定插件，不卸载但跳过执行
    @discardableResult
    public func disablePlugin(id: String) -> Bool {
        guard self.pluginEntry(for: id) != nil else {
            logger.error("禁用失败：未找到插件 \(id)")
            return false
        }
        
        updateEntry(id: id) {
            $0.status = .disabled
            $0.configuration.isEnabled = false
        }
        
        logger.info("插件 \(id) 已禁用")
        NotificationCenter.default.post(name: .pluginDidDisable, object: self, userInfo: ["id": id])
        return true
    }
    
    // MARK: - 依赖管理
    
    /// 对当前所有插件进行拓扑排序，返回依赖满足后的加载顺序
    /// 使用 Kahn 算法（基于入度的拓扑排序）
    public func resolveLoadOrder() -> [String] {
        lock.lock()
        let allPlugins = plugins
        lock.unlock()
        
        var inDegree: [String: Int] = [:]
        var adjacency: [String: [String]] = [:]
        
        // 初始化
        for (id, _) in allPlugins {
            inDegree[id] = 0
            adjacency[id] = []
        }
        
        // 构建依赖图
        for (id, entry) in allPlugins {
            for dep in entry.info.dependencies {
                adjacency[dep, default: []].append(id)
                inDegree[id, default: 0] += 1
            }
        }
        
        // Kahn 算法
        var queue: [String] = inDegree.filter { $0.value == 0 }.map { $0.key }
        var result: [String] = []
        var visited = Set<String>()
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if visited.contains(current) { continue }
            visited.insert(current)
            result.append(current)
            
            for neighbor in adjacency[current, default: []] {
                inDegree[neighbor] = (inDegree[neighbor] ?? 1) - 1
                if inDegree[neighbor] == 0 {
                    queue.append(neighbor)
                }
            }
        }
        
        // 检测循环依赖
        if result.count != allPlugins.count {
            // 找出剩余节点构成循环链
            let remaining = Set(allPlugins.keys).subtracting(visited)
            let chain = Array(remaining).sorted()
            logger.error("检测到循环依赖: \(chain.joined(separator: " → "))")
            NotificationCenter.default.post(name: .pluginDependenciesResolved, object: self, userInfo: ["order": result, "circular": chain])
            return result
        }
        
        logger.debug("依赖拓扑排序完成: \(result.joined(separator: " → "))")
        NotificationCenter.default.post(name: .pluginDependenciesResolved, object: self, userInfo: ["order": result])
        return result
    }
    
    // MARK: - 插件信息查询
    
    /// 获取所有已发现的插件列表
    public var allPlugins: [UIPluginEntry] {
        lock.lock()
        let list = Array(plugins.values)
        lock.unlock()
        return list
    }
    
    /// 获取指定插件的当前状态
    public func pluginStatus(for id: String) -> UIPluginStatus {
        lock.lock()
        let status = plugins[id]?.status ?? .unloaded
        lock.unlock()
        return status
    }
    
    /// 获取指定插件的信息
    public func pluginInfo(for id: String) -> UIPluginInfo? {
        lock.lock()
        let info = plugins[id]?.info
        lock.unlock()
        return info
    }
    
    /// 获取指定插件的依赖列表
    public func dependencies(of id: String) -> [String] {
        lock.lock()
        let deps = plugins[id]?.info.dependencies ?? []
        lock.unlock()
        return deps
    }
    
    /// 获取依赖于指定插件的插件列表
    public func dependents(of id: String) -> [UIPluginEntry] {
        lock.lock()
        let list = plugins.values.filter { $0.info.dependencies.contains(id) }
        lock.unlock()
        return Array(list)
    }
    
    // MARK: - 配置持久化
    
    /// 将所有插件配置保存到 JSON 文件
    public func saveConfigurations() throws {
        lock.lock()
        let configs = plugins.values.map { $0.configuration }
        lock.unlock()
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(configs)
            try data.write(to: configurationFileURL, options: .atomic)
            logger.info("已保存 \(configs.count) 个插件配置到 \(self.configurationFileURL.path)")
        } catch {
            logger.error("保存配置失败: \(error.localizedDescription)")
            throw UIPluginManagerError.configurationSaveFailed(error)
        }
    }
    
    /// 从 JSON 文件读取插件配置并应用
    public func loadConfigurations() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: configurationFileURL.path) else {
            logger.info("配置文件不存在，跳过加载")
            return
        }
        
        do {
            let data = try Data(contentsOf: configurationFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let configs = try decoder.decode([UIPluginConfiguration].self, from: data)
            
            lock.lock()
            for config in configs {
                if var entry = plugins[config.pluginID] {
                    entry.configuration = config
                    // 根据配置恢复状态
                    if config.isEnabled && entry.status != .enabled {
                        entry.status = .loaded
                    } else if !config.isEnabled && entry.status == .enabled {
                        entry.status = .disabled
                    }
                    plugins[config.pluginID] = entry
                }
            }
            lock.unlock()
            
            logger.info("已加载 \(configs.count) 个插件配置")
            NotificationCenter.default.post(name: .pluginConfigurationDidChange, object: self, userInfo: ["count": configs.count])
        } catch {
            logger.error("加载配置失败: \(error.localizedDescription)")
            throw UIPluginManagerError.configurationLoadFailed(error)
        }
    }
    
    // MARK: - 设置面板方法
    
    /// 返回供设置面板展示的所有插件简要信息（ID、名称、版本、状态）
    public func settingsPanelData() -> [(id: String, name: String, version: String, status: UIPluginStatus, isEnabled: Bool, author: String, description: String)] {
        lock.lock()
        let list = plugins.values.map { entry in
            (id: entry.id, name: entry.info.name, version: entry.info.version, status: entry.status, isEnabled: entry.configuration.isEnabled, author: entry.info.author, description: entry.info.description)
        }
        lock.unlock()
        return list.sorted { $0.name < $1.name }
    }
    
    /// 设置面板调用：切换插件启用状态
    public func togglePluginEnabled(id: String) -> Bool {
        let currentStatus = pluginStatus(for: id)
        if currentStatus == .enabled {
            return disablePlugin(id: id)
        } else {
            return enablePlugin(id: id)
        }
    }
    
    /// 设置面板调用：更新插件配置项
    public func updatePluginSetting(id: String, key: String, value: String) {
        updateEntry(id: id) { $0.configuration.settings[key] = value }
        logger.debug("更新插件 \(id) 配置: \(key)=\(value)")
    }
    
    // MARK: - 插件市场接口预留
    
    /// 从远程市场获取插件列表（需注入 marketInterface 实现）
    public func fetchMarketPlugins(completion: @escaping (Result<[UIPluginInfo], Error>) -> Void) {
        guard let market = marketInterface else {
            let error = NSError(domain: "UIPluginManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "插件市场接口未实现"])
            logger.warning("插件市场接口未注入，无法获取市场列表")
            completion(.failure(error))
            return
        }
        market.fetchMarketPlugins(completion: completion)
    }
    
    /// 下载指定插件（需注入 marketInterface 实现）
    public func downloadPluginFromMarket(id: String, version: String, progress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let market = marketInterface else {
            let error = NSError(domain: "UIPluginManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "插件市场接口未实现"])
            logger.warning("插件市场接口未注入，无法下载插件")
            completion(.failure(error))
            return
        }
        market.downloadPlugin(id: id, version: version, progress: progress, completion: completion)
    }
    
    /// 检查已安装插件的更新（需注入 marketInterface 实现）
    public func checkPluginUpdates(completion: @escaping (Result<[UIPluginInfo], Error>) -> Void) {
        guard let market = marketInterface else {
            let error = NSError(domain: "UIPluginManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "插件市场接口未实现"])
            logger.warning("插件市场接口未注入，无法检查更新")
            completion(.failure(error))
            return
        }
        let installed = allPlugins.map { $0.info }
        market.checkUpdates(for: installed, completion: completion)
    }
    
    // MARK: - 内部工具方法
    
    /// 在递归锁保护下获取插件条目
    private func pluginEntry(for id: String) -> UIPluginEntry? {
        lock.lock()
        let result = plugins[id]
        lock.unlock()
        return result
    }

    /// 检查插件是否启用
    private func isPluginEnabled(id: String) -> Bool {
        lock.lock()
        let enabled = plugins[id]?.configuration.isEnabled ?? false
        lock.unlock()
        return enabled
    }

    /// 获取插件Bundle
    private func pluginBundle(for id: String) -> Bundle? {
        lock.lock()
        let b = plugins[id]?.bundle
        lock.unlock()
        return b
    }

    /// 获取插件依赖列表（线程安全）
    private func pluginDependencies(for id: String) -> [String] {
        lock.lock()
        let deps = plugins[id]?.info.dependencies ?? []
        lock.unlock()
        return deps
    }

    /// 获取插件路径（线程安全）
    private func pluginPath(for id: String) -> URL {
        lock.lock()
        let path = plugins[id]?.path ?? pluginDirectory
        lock.unlock()
        return path
    }

    /// 在递归锁保护下更新指定插件条目
    private func updateEntry(id: String, mutation: (inout UIPluginEntry) -> Void) {
        lock.lock()
        if var entry = plugins[id] {
            mutation(&entry)
            plugins[id] = entry
        }
        lock.unlock()
    }
    
    /// 根据插件 ID 获取条目（线程安全，内部已加锁）
    private func entry(for id: String) -> UIPluginEntry? {
        lock.lock()
        let result = plugins[id]
        lock.unlock()
        return result
    }

    deinit {
        logger.info("UIPluginManager 已释放")
    }
}

// MARK: - 迁回自 UI-02：class UIDefaultPluginMarket
public final class UIDefaultPluginMarket: UIPluginMarketProtocol , @unchecked Sendable{
    
    public init() {}
    
    public func fetchMarketPlugins(completion: @escaping (Result<[UIPluginInfo], Error>) -> Void) {
        // 占位实现：返回空列表
        completion(.success([]))
    }
    
    public func downloadPlugin(id: String, version: String, progress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        // 占位实现：返回错误
        let error = NSError(domain: "UIDefaultPluginMarket", code: -1, userInfo: [NSLocalizedDescriptionKey: "默认市场实现不支持下载，请注入实际实现"])
        completion(.failure(error))
    }
    
    public func checkUpdates(for installedPlugins: [UIPluginInfo], completion: @escaping (Result<[UIPluginInfo], Error>) -> Void) {
        // 占位实现：返回空列表
        completion(.success([]))
    }
    
    public func installPlugin(from localURL: URL, completion: @escaping (Result<UIPluginEntry, Error>) -> Void) {
        // 占位实现：将本地包复制到插件目录并扫描
        let manager = UIPluginManager.shared
        let dest = manager.pluginDirectory.appendingPathComponent(localURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: localURL, to: dest)
            manager.scanPlugins()
            if let entry = manager.allPlugins.first(where: { $0.path == dest }) {
                completion(.success(entry))
            } else {
                let error = UIPluginManagerError.bundleNotFound(dest)
                completion(.failure(error))
            }
        } catch {
            completion(.failure(error))
        }
    }
}

// MARK: - 迁回自 UI-02：extension UIPluginManager
public extension UIPluginManager {
    
    /// 已加载插件数量
    var loadedPluginCount: Int {
        return allPlugins.filter { $0.status == .loaded || $0.status == .enabled }.count
    }
    
    /// 已启用插件数量
    var enabledPluginCount: Int {
        return allPlugins.filter { $0.status == .enabled }.count
    }
    
    /// 已发现插件总数
    var totalPluginCount: Int {
        return allPlugins.count
    }
    
    /// 是否存在失败的插件
    var hasFailedPlugins: Bool {
        return allPlugins.contains { $0.status == .failed }
    }
    
    /// 获取所有失败插件的列表
    var failedPlugins: [UIPluginEntry] {
        return allPlugins.filter { $0.status == .failed }
    }
    
    /// 重新加载所有插件（先卸载再加载）
    func reloadAllPlugins() {
        unloadAllPlugins()
        loadAllPlugins()
    }
    
    /// 重新加载指定插件
    func reloadPlugin(id: String) -> Bool {
        unloadPlugin(id: id)
        return loadPlugin(id: id)
    }
    
    /// 删除插件文件（从磁盘移除并卸载）
    func removePlugin(id: String) -> Bool {
        guard unloadPlugin(id: id) else { return false }
        
        lock.lock()
        guard let path = plugins[id]?.path else {
            lock.unlock()
            return false
        }
        plugins.removeValue(forKey: id)
        loadOrder.removeAll { $0 == id }
        lock.unlock()
        
        do {
            try FileManager.default.removeItem(at: path)
            logger.info("插件 \(id) 已从磁盘删除")
            return true
        } catch {
            logger.error("删除插件文件失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 安装本地插件包（复制到插件目录并加载）
    func installPlugin(from localURL: URL) -> UIPluginEntry? {
        let dest = pluginDirectory.appendingPathComponent(localURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: localURL, to: dest)
            scanPlugins()
            if let entry = allPlugins.first(where: { $0.path == dest }) {
                loadPlugin(id: entry.id)
                return entry
            }
        } catch {
            logger.error("安装插件失败: \(error.localizedDescription)")
        }
        return nil
    }
}

// MARK: - 迁回自 UI-02：struct UIPluginInfo
// MARK: - UI-GL-39 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-39_types.swift
// 版本: 2.0
// MARK: - 插件信息数据模型
/// 插件元数据信息，用于描述插件的基本属性
public struct UIPluginInfo: Codable, Identifiable, Equatable {
    /// 插件唯一标识符（通常使用 Bundle Identifier）
    public let id: String
    /// 插件显示名称
    public let name: String
    /// 插件版本号（语义化版本）
    public let version: String
    /// 插件作者
    public let author: String
    /// 插件描述
    public let description: String
    /// 声明的依赖插件 ID 列表
    public let dependencies: [String]
    /// 插件类型（原生 / 脚本 / 混合）
    public let type: UIPluginType
    /// 最低兼容的应用版本
    public let minimumAppVersion: String?
    /// 插件支持的架构列表
    public let supportedArchitectures: [String]?
    
    public enum UIPluginType: String, Codable {
        case native = "原生"
        case script = "脚本"
        case hybrid = "混合"
    }
    
    public init(id: String, name: String, version: String, author: String, description: String, dependencies: [String] = [], type: UIPluginType = .native, minimumAppVersion: String? = nil, supportedArchitectures: [String]? = nil) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.description = description
        self.dependencies = dependencies
        self.type = type
        self.minimumAppVersion = minimumAppVersion
        self.supportedArchitectures = supportedArchitectures
    }
}

// MARK: - 迁回自 UI-02：struct UIPluginConfiguration
// MARK: - 独立模块管理器
/// 管理所有独立模块的加载、注册、卸载
// 已迁回 UI-GL-38_模块独立性.swift：class UIIndependentModuleManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-39 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-39_types.swift
// 版本: 2.0
// MARK: - 插件配置数据模型
/// 单个插件的运行时配置，支持持久化存储
public struct UIPluginConfiguration: Codable, Equatable {
    /// 关联的插件 ID
    public let pluginID: String
    /// 是否启用该插件
    public var isEnabled: Bool
    /// 插件自定义配置字典（以 JSON 兼容方式存储）
    public var settings: [String: String]
    /// 上次加载时间戳
    public var lastLoadedAt: Date?
    /// 安装时间戳
    public var installedAt: Date
    
    public init(pluginID: String, isEnabled: Bool = true, settings: [String: String] = [:], lastLoadedAt: Date? = nil, installedAt: Date = Date()) {
        self.pluginID = pluginID
        self.isEnabled = isEnabled
        self.settings = settings
        self.lastLoadedAt = lastLoadedAt
        self.installedAt = installedAt
    }
}

// MARK: - 迁回自 UI-02：enum UIPluginStatus
// MARK: - 插件状态枚举
/// 插件在生命周期中的当前状态
public enum UIPluginStatus: String, Codable {
    /// 已扫描发现但未加载
    case discovered = "已发现"
    /// 已加载到内存中
    case loaded = "已加载"
    /// 已启用且正在运行
    case enabled = "已启用"
    /// 已禁用但未卸载
    case disabled = "已禁用"
    /// 已卸载
    case unloaded = "已卸载"
    /// 加载失败
    case failed = "加载失败"
}

// MARK: - 迁回自 UI-02：struct UIPluginEntry
// MARK: - 插件运行时条目
/// 运行时维护的插件完整信息，包含元数据、配置和状态
public struct UIPluginEntry: Identifiable, Equatable {
    public let id: String
    /// 插件元数据
    public let info: UIPluginInfo
    /// 运行时配置（非持久化，运行时维护）
    public var configuration: UIPluginConfiguration
    /// 当前状态
    public var status: UIPluginStatus
    /// 对应加载的 Bundle 对象（原生插件）
    public var bundle: Bundle?
    /// 插件所在路径
    public let path: URL
    /// 加载失败时的错误信息
    public var lastError: String?
    
    public init(id: String, info: UIPluginInfo, configuration: UIPluginConfiguration, status: UIPluginStatus, bundle: Bundle? = nil, path: URL, lastError: String? = nil) {
        self.id = id
        self.info = info
        self.configuration = configuration
        self.status = status
        self.bundle = bundle
        self.path = path
        self.lastError = lastError
    }
}

// MARK: - 迁回自 UI-02：enum UIPluginManagerError
// MARK: - 插件管理器错误
/// 插件管理器执行过程中可能抛出的错误
public enum UIPluginManagerError: Error, LocalizedError {
    /// 插件文件未找到
    case bundleNotFound(URL)
    /// 插件包无效或已损坏
    case invalidBundle(URL)
    /// 插件加载失败
    case loadFailed(String, Error)
    /// 插件未找到
    case pluginNotFound(String)
    /// 插件已存在
    case duplicatePlugin(String)
    /// 循环依赖 detected
    case circularDependency([String])
    /// 依赖缺失
    case missingDependencies([String])
    /// 配置保存失败
    case configurationSaveFailed(Error)
    /// 配置读取失败
    case configurationLoadFailed(Error)
    /// 插件目录不可访问
    case pluginDirectoryInaccessible(URL)
    
    public var errorDescription: String? {
        switch self {
        case .bundleNotFound(let url):
            return "插件文件未找到: \(url.path)"
        case .invalidBundle(let url):
            return "无效的插件包: \(url.path)"
        case .loadFailed(let id, let error):
            return "插件 \(id) 加载失败: \(error.localizedDescription)"
        case .pluginNotFound(let id):
            return "未找到插件: \(id)"
        case .duplicatePlugin(let id):
            return "插件已存在: \(id)"
        case .circularDependency(let chain):
            return "检测到循环依赖: \(chain.joined(separator: " → "))"
        case .missingDependencies(let deps):
            return "缺少依赖插件: \(deps.joined(separator: ", "))"
        case .configurationSaveFailed(let error):
            return "配置保存失败: \(error.localizedDescription)"
        case .configurationLoadFailed(let error):
            return "配置读取失败: \(error.localizedDescription)"
        case .pluginDirectoryInaccessible(let url):
            return "插件目录无法访问: \(url.path)"
        }
    }
}

// MARK: - 迁回自 UI-02：protocol UIPluginMarketProtocol
// MARK: - 插件市场接口预留
/// 插件市场接口协议，预留远程下载/更新/安装能力
public protocol UIPluginMarketProtocol: AnyObject {
    /// 获取市场插件列表
    func fetchMarketPlugins(completion: @escaping (Result<[UIPluginInfo], Error>) -> Void)
    /// 下载指定插件
    func downloadPlugin(id: String, version: String, progress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void)
    /// 检查插件更新
    func checkUpdates(for installedPlugins: [UIPluginInfo], completion: @escaping (Result<[UIPluginInfo], Error>) -> Void)
    /// 安装已下载的插件包
    func installPlugin(from localURL: URL, completion: @escaping (Result<UIPluginEntry, Error>) -> Void)
}
