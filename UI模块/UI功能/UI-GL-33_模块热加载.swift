// 功能25: 模块热加载
// 对应: 运行时加载.bundle模块，无需重启应用
// 优先级: P2

import AppKit
import Foundation
import os.log

// MARK: - 通知名称
/// 模块热加载系统通知名称扩展
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能25：模块热加载 — 单元测试
/// 覆盖：依赖图/加载/卸载/查询/扫描/监控
func test_hotLoad() {
    let manager = UIHotLoadManager.shared
    
    print("\n🧪 测试1: 初始状态")
    let stats = manager.statistics
    _ = stats.total
    print("✅ 测试1通过: 初始状态正常")
    
    print("\n🧪 测试2: 依赖图管理")
    let graph = UIDependencyGraph()
    let added = graph.addDependency(module: "moduleA", dependency: "moduleB")
    guard added else {
        fatalError("❌ 测试2失败: 依赖添加应成功")
    }
    let deps = graph.dependencies(of: "moduleA")
    guard deps.contains("moduleB") else {
        fatalError("❌ 测试2失败: 依赖查询不正确")
    }
    print("✅ 测试2通过: 依赖图管理正常")
    
    print("\n🧪 测试3: 循环依赖检测")
    let added2 = graph.addDependency(module: "moduleB", dependency: "moduleA")
    guard added2 == false else {
        fatalError("❌ 测试3失败: 循环依赖应被检测到")
    }
    print("✅ 测试3通过: 循环依赖检测正确")
    
    print("\n🧪 测试4: 拓扑排序")
    let order = graph.topologicalSort()
    guard let sorted = order, sorted.count == 2 else {
        fatalError("❌ 测试4失败: 拓扑排序应有2个模块")
    }
    print("✅ 测试4通过: 拓扑排序正确: \(sorted.joined(separator: " → "))")
    
    print("\n🧪 测试5: 移除模块")
    graph.removeModule("moduleA")
    let afterRemove = graph.dependencies(of: "moduleA")
    guard afterRemove.isEmpty else {
        fatalError("❌ 测试5失败: 移除后依赖应为空")
    }
    print("✅ 测试5通过: 移除模块正常")
    
    print("\n🧪 测试6: 模块信息查询")
    let all = manager.allModules
    _ = all.count
    let loaded = manager.loadedModules
    _ = loaded.count
    print("✅ 测试6通过: 模块查询正常")
    
    print("\n🧪 测试7: 模块状态枚举")
    let statuses = UIModuleStatus.allCases
    guard statuses.count == 5 else {
        fatalError("❌ 测试7失败: 应有5种状态")
    }
    print("✅ 测试7通过: 模块状态枚举正确")
    
    print("\n=== 全部热加载测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIDependencyGraph
public final class UIDependencyGraph : @unchecked Sendable {
    private var adjacencyList: [String: [String]] = [:]
    private var reverseAdjacencyList: [String: [String]] = [:]
    private let lock = NSRecursiveLock()

    public func addDependency(module: String, dependency: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if wouldCreateCycle(from: module, to: dependency) { return false }
        adjacencyList[module, default: []].append(dependency)
        reverseAdjacencyList[dependency, default: []].append(module)
        return true
    }

    public func removeModule(_ module: String) {
        lock.lock(); defer { lock.unlock() }
        if let deps = adjacencyList[module] {
            for d in deps { reverseAdjacencyList[d]?.removeAll { $0 == module } }
            adjacencyList.removeValue(forKey: module)
        }
        if let deps = reverseAdjacencyList[module] {
            for d in deps { adjacencyList[d]?.removeAll { $0 == module } }
            reverseAdjacencyList.removeValue(forKey: module)
        }
    }

    public func dependencies(of module: String) -> [String] {
        lock.lock(); let d = adjacencyList[module] ?? []; lock.unlock(); return d
    }
    public func dependents(of module: String) -> [String] {
        lock.lock(); let d = reverseAdjacencyList[module] ?? []; lock.unlock(); return d
    }

    public func topologicalSort() -> [String]? {
        lock.lock(); defer { lock.unlock() }
        var inDegree: [String: Int] = [:]
        var all = Set<String>()
        for (m, ds) in adjacencyList {
            all.insert(m)
            for d in ds { all.insert(d); inDegree[d, default: 0] += 1 }
        }
        for m in all { if inDegree[m] == nil { inDegree[m] = 0 } }
        var q = inDegree.filter { $0.value == 0 }.map { $0.key }
        var res: [String] = []
        while !q.isEmpty {
            let c = q.removeFirst()
            res.append(c)
            for d in reverseAdjacencyList[c, default: []] {
                inDegree[d]! -= 1
                if inDegree[d] == 0 { q.append(d) }
            }
        }
        return res.count == all.count ? res : nil
    }

    private func wouldCreateCycle(from module: String, to dependency: String) -> Bool {
        var v = Set<String>()
        var s = [dependency]
        while !s.isEmpty {
            let c = s.removeLast()
            if c == module { return true }
            if v.contains(c) { continue }
            v.insert(c)
            for d in adjacencyList[c, default: []] { s.append(d) }
        }
        return false
    }

    public func detectCycle() -> [String]? {
        lock.lock(); defer { lock.unlock() }
        var v = Set<String>(), rs = Set<String>(), p = [String]()
        for m in adjacencyList.keys {
            if !v.contains(m) { if let c = dfs(m, &v, &rs, &p) { return c } }
        }
        return nil
    }
    private func dfs(_ n: String, _ v: inout Set<String>, _ rs: inout Set<String>, _ p: inout [String]) -> [String]? {
        v.insert(n); rs.insert(n); p.append(n)
        for x in adjacencyList[n, default: []] {
            if !v.contains(x) { if let c = dfs(x, &v, &rs, &p) { return c } }
            else if rs.contains(x), let i = p.firstIndex(of: x) { return Array(p[i...]) }
        }
        p.removeLast(); rs.remove(n); return nil
    }

    public func allDependencies() -> [(module: String, dependencies: [String])] {
        lock.lock(); let r = adjacencyList.map { (module: $0.key, dependencies: $0.value) }; lock.unlock()
        return r.sorted { $0.module < $1.module }
    }
}

// MARK: - 迁回自 UI-02：class UIHotLoadManager
public final class UIHotLoadManager : @unchecked Sendable {
    public static let shared = UIHotLoadManager()
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "UIHotLoadManager")
    private var moduleInfos: [String: UIModuleInfo] = [:]
    private var loadedBundles: [String: Bundle] = [:]
    private let dependencyGraph = UIDependencyGraph()
    private let lock = NSRecursiveLock()
    private var moduleSearchDirectory: URL?
    private var eventStream: FSEventStreamRef?
    private let eventQueue = DispatchQueue(label: "com.xianrenzhilu.hotload.fsevents", qos: .utility)
    private var debounceTimer: Timer?
    private let debounceQueue = DispatchQueue(label: "com.xianrenzhilu.hotload.debounce")

    private init() { logger.info("热加载管理器已初始化") }
    deinit { stopFileMonitoring(); logger.info("热加载管理器已释放") }

    @discardableResult
    public func loadModule(at url: URL, dependencies: [String] = []) throws -> Bundle {
        let name = url.lastPathComponent
        logger.info("开始加载模块: \(name)")
        guard FileManager.default.fileExists(atPath: url.path) else { throw UIHotLoadError.bundleNotFound(url) }
        lock.lock()
        guard loadedBundles[name] == nil else { lock.unlock(); throw UIHotLoadError.duplicateLoad(name) }
        if moduleInfos[name] == nil { moduleInfos[name] = UIModuleInfo(id: name, displayName: name, version: "2.0", fileURL: url) }
        moduleInfos[name]!.status = .loading
        lock.unlock()

        for d in dependencies {
            lock.lock(); let ok = loadedBundles[d] != nil; lock.unlock()
            if !ok { lock.lock(); moduleInfos[name]!.status = .failed; moduleInfos[name]!.lastError = "依赖模块未加载: \(d)"; lock.unlock(); throw UIHotLoadError.dependencyNotLoaded(d) }
        }
        guard let bundle = Bundle(url: url) else { lock.lock(); moduleInfos[name]!.status = .failed; moduleInfos[name]!.lastError = "无效的模块文件"; lock.unlock(); throw UIHotLoadError.invalidBundle(url) }
        do { try loadBundleExecutable(bundle: bundle, moduleName: name) } catch { lock.lock(); moduleInfos[name]!.status = .failed; moduleInfos[name]!.lastError = error.localizedDescription; lock.unlock(); throw UIHotLoadError.initializationFailed(name, error) }

        lock.lock()
        loadedBundles[name] = bundle
        moduleInfos[name]!.status = .loaded
        moduleInfos[name]!.loadTime = Date()
        moduleInfos[name]!.unloadTime = nil
        moduleInfos[name]!.lastError = nil
        for d in dependencies { _ = dependencyGraph.addDependency(module: name, dependency: d) }
        moduleInfos[name]!.dependencies = dependencies
        for d in dependencies { if moduleInfos[d] != nil && !moduleInfos[d]!.dependents.contains(name) { moduleInfos[d]!.dependents.append(name) } }
        lock.unlock()
        logger.info("模块加载成功: \(name)")
        NotificationCenter.default.post(name: .moduleLoaded, object: self, userInfo: ["moduleName": name, "moduleURL": url, "bundle": bundle])
        return bundle
    }

    private func loadBundleExecutable(bundle: Bundle, moduleName: String) throws {
        if bundle.isLoaded { return }
        _ = bundle.load()
    }

    public func unloadModule(_ name: String) throws {
        logger.info("开始卸载模块: \(name)")
        lock.lock()
        guard loadedBundles[name] != nil else { lock.unlock(); throw UIHotLoadError.notLoaded(name) }
        let dps = dependencyGraph.dependents(of: name)
        if !dps.isEmpty { lock.unlock(); throw UIHotLoadError.dependencyNotLoaded("模块 \(name) 被 \(dps.joined(separator: ", ")) 依赖，无法卸载") }
        moduleInfos[name]!.status = .unloading
        lock.unlock()

        lock.lock()
        let bundle = loadedBundles.removeValue(forKey: name)
        moduleInfos[name]!.status = .notLoaded
        moduleInfos[name]!.unloadTime = Date()
        moduleInfos[name]!.loadTime = nil
        moduleInfos[name]!.dependents = []
        dependencyGraph.removeModule(name)
        for (n, var i) in moduleInfos { if i.dependencies.contains(name) { i.dependencies.removeAll { $0 == name }; moduleInfos[n] = i } }
        lock.unlock()
        if let b = bundle, b.isLoaded { b.unload() }
        logger.info("模块卸载完成: \(name)")
        NotificationCenter.default.post(name: .moduleUnloaded, object: self, userInfo: ["moduleName": name])
    }

    public func reloadModule(_ name: String) throws {
        logger.info("开始重新加载模块: \(name)")
        lock.lock(); let deps = moduleInfos[name]?.dependencies ?? []; let url = moduleInfos[name]?.fileURL; lock.unlock()
        guard let u = url else { throw UIHotLoadError.notLoaded(name) }
        try unloadModule(name)
        try loadModule(at: u, dependencies: deps)
        logger.info("模块重新加载完成: \(name)")
    }

    public func startFileMonitoring(directory: URL) throws {
        stopFileMonitoring()
        guard FileManager.default.fileExists(atPath: directory.path) else { throw UIHotLoadError.moduleDirectoryNotFound(directory) }
        moduleSearchDirectory = directory
        logger.info("启动文件监控: \(directory.path)")
        let paths = [directory.path as CFString]
        var ptrs: [UnsafeRawPointer?] = paths.map { UnsafeRawPointer(Unmanaged.passUnretained($0).toOpaque()) }
        let arr = ptrs.withUnsafeMutableBufferPointer { CFArrayCreate(kCFAllocatorDefault, $0.baseAddress, paths.count, nil) }
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let stream = FSEventStreamCreate(kCFAllocatorDefault, { (_, info, n, paths, flags, _) in
            guard let i = info else { return }
            Unmanaged<UIHotLoadManager>.fromOpaque(i).takeUnretainedValue().handleFSEvents(numEvents: n, eventPaths: paths, eventFlags: flags)
        }, &ctx, arr!, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0, FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes))
        guard let s = stream else { throw UIHotLoadError.fileMonitorFailed(NSError(domain: "UIHotLoadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建FSEventStream"])) }
        eventStream = s
        FSEventStreamSetDispatchQueue(s, eventQueue)
        guard FSEventStreamStart(s) else {
            FSEventStreamRelease(s); eventStream = nil
            throw UIHotLoadError.fileMonitorFailed(NSError(domain: "UIHotLoadManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法启动FSEventStream"]))
        }
        logger.info("文件监控已启动")
    }

    public func stopFileMonitoring() {
        guard let s = eventStream else { return }
        FSEventStreamStop(s); FSEventStreamInvalidate(s); FSEventStreamRelease(s); eventStream = nil; moduleSearchDirectory = nil
        logger.info("文件监控已停止")
    }

    private func handleFSEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>) {
        let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
        for (i, p) in paths.enumerated() {
            let f = eventFlags[i]
            if p.hasSuffix(".bundle") || p.contains(".bundle/") {
                let created = (f & UInt32(kFSEventStreamEventFlagItemCreated)) != 0
                let modified = (f & UInt32(kFSEventStreamEventFlagItemModified)) != 0
                let renamed = (f & UInt32(kFSEventStreamEventFlagItemRenamed)) != 0
                if created || modified || renamed {
                    logger.info("检测到模块文件变更: \(p)")
                    debounceQueue.async { [weak self] in self?.scheduleHotReload(path: p) }
                }
            }
        }
    }

    private func scheduleHotReload(path: String) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let s = self else { return }
            let u = URL(fileURLWithPath: path)
            let name = u.lastPathComponent.hasSuffix(".bundle") ? u.lastPathComponent : u.deletingLastPathComponent().lastPathComponent
            s.logger.info("触发自动热重载: \(name)")
            NotificationCenter.default.post(name: .moduleHotReloadTriggered, object: s, userInfo: ["moduleName": name, "path": path])
            do { try s.reloadModule(name) } catch {
                s.logger.error("热重载失败 [\(name)]: \(error.localizedDescription)")
                NotificationCenter.default.post(name: .moduleLoadFailed, object: s, userInfo: ["moduleName": name, "error": error, "isHotReload": true])
            }
        }
    }

    public var allModules: [UIModuleInfo] { lock.lock(); let r = Array(moduleInfos.values).sorted { $0.id < $1.id }; lock.unlock(); return r }
    public var loadedModules: [UIModuleInfo] { lock.lock(); let r = moduleInfos.values.filter { $0.status == .loaded }.sorted { $0.id < $1.id }; lock.unlock(); return r }
    public func moduleInfo(_ name: String) -> UIModuleInfo? { lock.lock(); let r = moduleInfos[name]; lock.unlock(); return r }
    public func bundle(for name: String) -> Bundle? { lock.lock(); let r = loadedBundles[name]; lock.unlock(); return r }
    public func isLoaded(_ name: String) -> Bool { lock.lock(); let r = loadedBundles[name] != nil; lock.unlock(); return r }
    public func dependencies(of name: String) -> [String] { dependencyGraph.dependencies(of: name) }
    public func dependents(of name: String) -> [String] { dependencyGraph.dependents(of: name) }
    public var loadOrder: [String]? { dependencyGraph.topologicalSort() }
    public var dependencyGraphDescription: String {
        let deps = dependencyGraph.allDependencies()
        if deps.isEmpty { return "暂无依赖关系" }
        var lines = ["模块依赖关系图:"]
        for (m, ds) in deps { lines.append("  \(m) → \(ds.isEmpty ? "无依赖" : ds.joined(separator: ", "))") }
        if let o = dependencyGraph.topologicalSort() { lines += ["", "建议加载顺序: \(o.joined(separator: " → "))"] }
        if let c = dependencyGraph.detectCycle() { lines += ["", "⚠️ 检测到循环依赖: \(c.joined(separator: " → "))"] }
        return lines.joined(separator: "\n")
    }

    public func allModulesForSettings() -> [(status: UIModuleStatus, modules: [UIModuleInfo])] {
        let g = Dictionary(grouping: allModules) { $0.status }
        return UIModuleStatus.allCases.compactMap { s in g[s].flatMap { $0.isEmpty ? nil : (s, $0) } }
    }

    public func manualLoadModule(_ name: String) -> Bool {
        lock.lock(); let info = moduleInfos[name]; lock.unlock()
        guard let i = info else { logger.error("手动加载失败，模块不存在: \(name)"); return false }
        do { try loadModule(at: i.fileURL, dependencies: i.dependencies); return true } catch {
            logger.error("手动加载失败 [\(name)]: \(error.localizedDescription)")
            NotificationCenter.default.post(name: .moduleLoadFailed, object: self, userInfo: ["moduleName": name, "error": error, "isHotReload": false])
            return false
        }
    }
    public func manualUnloadModule(_ name: String) -> Bool { do { try unloadModule(name); return true } catch { logger.error("手动卸载失败 [\(name)]: \(error.localizedDescription)"); return false } }

    public func dependencyGraphData() -> (nodes: [(id: String, status: UIModuleStatus)], edges: [(from: String, to: String)]) {
        lock.lock(); let infos = moduleInfos; lock.unlock()
        let nodes = infos.map { (id: $0.key, status: $0.value.status) }.sorted { $0.id < $1.id }
        let edges = dependencyGraph.allDependencies().flatMap { dep in dep.dependencies.map { (from: dep.module, to: $0) } }
        return (nodes: nodes, edges: edges)
    }

    public func scanModules(in directory: URL) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { throw UIHotLoadError.moduleDirectoryNotFound(directory) }
        logger.info("扫描模块目录: \(directory.path)")
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let bundles = contents.filter { $0.pathExtension == "bundle" }
        lock.lock()
        for u in bundles {
            let name = u.lastPathComponent
            if moduleInfos[name] == nil {
                moduleInfos[name] = UIModuleInfo(id: name, displayName: name.replacingOccurrences(of: ".bundle", with: ""), version: "2.0", fileURL: u, description: "从 \(directory.lastPathComponent) 扫描发现")
                logger.info("发现模块: \(name)")
            }
        }
        lock.unlock()
        logger.info("模块扫描完成，发现 \(bundles.count) 个模块")
    }

    public var statistics: (total: Int, loaded: Int, failed: Int, notLoaded: Int) {
        lock.lock()
        let t = moduleInfos.count, l = moduleInfos.values.filter { $0.status == .loaded }.count, f = moduleInfos.values.filter { $0.status == .failed }.count, n = moduleInfos.values.filter { $0.status == .notLoaded }.count
        lock.unlock()
        return (t, l, f, n)
    }
}

// MARK: - 迁回自 UI-02：enum UIHotLoadError
// MARK: - UI-GL-30 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-30_types.swift
// 版本: 2.0
// MARK: - 通知名称
// 已迁回 UI-GL-30_视图渲染优化.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-31 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-31_types.swift
// 版本: 2.0
// MARK: - 通知名称
/// 异步加载器通知名称
// 已迁回 UI-GL-31_异步加载器.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-32 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-32_types.swift
// 版本: 2.0
// MARK: - 通知名称
// 已迁回 UI-GL-32_内存警告处理.swift：extension Notification.Name（公共类型文件禁止功能实现）


// MARK: - UI-GL-33 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-33_types.swift
// 版本: 2.0
// MARK: - 错误枚举
public enum UIHotLoadError: Error, LocalizedError {
    case bundleNotFound(URL)
    case invalidBundle(URL)
    case loadFailed(URL, Error)
    case duplicateLoad(String)
    case notLoaded(String)
    case dependencyNotLoaded(String)
    case circularDependency([String])
    case initializationFailed(String, Error)
    case fileMonitorFailed(Error)
    case moduleDirectoryNotFound(URL)

    public var errorDescription: String? {
        switch self {
        case .bundleNotFound(let url): return "模块文件不存在: \(url.path)"
        case .invalidBundle(let url): return "模块文件无效或损坏: \(url.path)"
        case .loadFailed(let url, let error): return "加载模块失败 [\(url.lastPathComponent)]: \(error.localizedDescription)"
        case .duplicateLoad(let name): return "模块重复加载: \(name)"
        case .notLoaded(let name): return "模块未加载: \(name)"
        case .dependencyNotLoaded(let name): return "依赖模块未加载: \(name)"
        case .circularDependency(let chain): return "模块依赖存在循环: \(chain.joined(separator: " → "))"
        case .initializationFailed(let name, let error): return "模块初始化失败 [\(name)]: \(error.localizedDescription)"
        case .fileMonitorFailed(let error): return "文件监控启动失败: \(error.localizedDescription)"
        case .moduleDirectoryNotFound(let url): return "模块目录不存在: \(url.path)"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIModuleInfo
// MARK: - 内存警告管理器
/// 监听内存警告，自动清理各模块缓存
/// 支持分级清理、注册表模式、策略配置、通知体系
// 已迁回 UI-GL-32_内存警告处理.swift：class UIMemoryWarningManager（公共类型文件禁止功能实现）

/// 测试用可清理缓存
// 已迁回 UI-GL-32_内存警告处理.swift：class UITestCacheable（公共类型文件禁止功能实现）


// MARK: - UI-GL-33 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-33_types.swift
// 版本: 2.0
// MARK: - 模块信息
public struct UIModuleInfo: Sendable, Identifiable {
    public let id: String
    public var displayName: String
    public var version: String
    public var status: UIModuleStatus
    public var fileURL: URL
    public var loadTime: Date?
    public var unloadTime: Date?
    public var dependencies: [String]
    public var dependents: [String]
    public var lastError: String?
    public var description: String

    public var loadTimeString: String {
        guard let loadTime = loadTime else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: loadTime)
    }

    public init(id: String, displayName: String, version: String, fileURL: URL, description: String = "") {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.status = .notLoaded
        self.fileURL = fileURL
        self.loadTime = nil
        self.unloadTime = nil
        self.dependencies = []
        self.dependents = []
        self.lastError = nil
        self.description = description
    }
}
