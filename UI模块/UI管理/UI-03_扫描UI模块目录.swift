// MARK: - UI-01: 扫描UI模块目录
// 功能编号: UI-03
// 版本: 2.0
// 职责: 扫描指定目录，发现所有UI模块bundle，解析元数据，验证完整性
// 依赖: UI-02 公共类型, UI-12 日志

import Foundation

// 使用UI-02的ModuleMetadata、ModuleCategory等类型
// 本文件不再定义这些类型

// MARK: - Plist 内部结构（类型安全解码）
// 类型 UIModulePlistInfo 已迁移到 UI-02_公共类型定义.swift

// MARK: - 扫描管理器
// 类型 UIModuleScanner 已迁移到 UI-02_公共类型定义.swift


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIModuleScanner
public final class UIModuleScanner : @unchecked Sendable {
    public static let shared = UIModuleScanner()

    private let lock = NSLock()
    private let logger = UILoadingLogManager.shared
    private var blacklist: Set<String> = []
    private var scannedModules: [String: UIModuleDiscoveryResult] = [:]
    private nonisolated(unsafe) var fileSystemSource: DispatchSourceFileSystemObject?

    // Plist缓存：bundle路径 → 解析结果（避免重复I/O）
    private var plistCache: [String: UIModulePlistInfo] = [:]

    // bundle修改时间快照（用于增量扫描时比对）
    private var bundleModDates: [String: Date] = [:]

    // 索引持久化路径（懒加载，只创建一次目录）
    private lazy var indexSaveURL: URL = {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("com.xianrenzhilu.ui/index", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ui-module-index.json")
    }()

    // 默认的UI模块存放目录
    public var defaultModuleDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("仙人指路/UIModules", isDirectory: true)
    }

    private init() {
        // 启动时尝试从文件恢复索引
        restoreIndexFromDisk()
    }

    // MARK: - 增量扫描（使用modDate比对）
    /// 增量扫描：只扫描新增或修改时间变化的bundle
    @discardableResult
    public func incrementalScan(directory: URL? = nil) -> [UIModuleDiscoveryResult] {
        let dir = directory ?? defaultModuleDirectory
        logger.info("扫描器", "开始增量扫描UI模块目录: \(dir.path)")

        guard checkDirectoryExists(dir) else { return [] }

        guard let currentBundles = enumerateBundles(at: dir) else {
            logger.warning("扫描器", "无法枚举目录内容")
            return []
        }

        // 一次加锁完成快照比对和状态更新
        lock.lock()
        let oldDates = bundleModDates
        var changedPaths: [URL] = []
        var newDates: [String: Date] = [:]
        // 当前有效bundle路径集合，用于清理已删除bundle的孤儿索引
        var currentBundlePaths: Set<String> = []

        for (url, modDate) in currentBundles {
            let path = url.path
            newDates[path] = modDate
            currentBundlePaths.insert(path)

            if let lastMod = oldDates[path] {
                if modDate != lastMod {
                    // 修改时间变了 → 清除旧缓存和索引
                    plistCache.removeValue(forKey: path)
                    if let key = scannedModules.first(where: { $0.value.bundleURL.path == path })?.key {
                        scannedModules.removeValue(forKey: key)
                    }
                    changedPaths.append(url)
                }
            } else {
                // 全新bundle
                changedPaths.append(url)
            }
        }

        // 清理已删除bundle的孤儿索引（存在于 scannedModules 但不在当前磁盘上）
        let orphanKeys = scannedModules.keys.filter { key in
            guard let result = scannedModules[key] else { return false }
            return !currentBundlePaths.contains(result.bundleURL.path)
        }
        for key in orphanKeys {
            scannedModules.removeValue(forKey: key)
        }

        bundleModDates = newDates
        lock.unlock()

        // 锁外逐个解析（I/O操作）
        var newResults: [UIModuleDiscoveryResult] = []
        for url in changedPaths {
            if let result = parseBundle(at: url) {
                lock.lock()
                scannedModules[result.moduleID] = result
                lock.unlock()
                logModuleDiscovered(result)
                newResults.append(result)
            }
        }

        if !newResults.isEmpty {
            saveIndexToDisk()
            let payload = UIModuleScanPayload(results: newResults, count: newResults.count, directoryPath: dir.path)
            NotificationCenter.default.post(name: .uiModuleScanCompleted, object: payload)
            logger.info("扫描器", "增量扫描完成，发现 \(newResults.count) 个新/变更模块")
        } else {
            logger.info("扫描器", "增量扫描完成，无变化")
        }

        return newResults
    }

    // MARK: - 黑名单管理

    public func addToBlacklist(_ moduleID: String) {
        lock.lock()
        let wasAdded = blacklist.insert(moduleID).inserted
        lock.unlock()

        if wasAdded {
            logger.info("扫描器", "模块 '\(moduleID)' 已加入黑名单")
            let payload = UIModuleBlacklistPayload(moduleID: moduleID, isBlacklisted: true)
            NotificationCenter.default.post(name: .uiModuleBlacklistChanged, object: payload)
        }
    }

    public func removeFromBlacklist(_ moduleID: String) {
        lock.lock()
        let wasRemoved = blacklist.remove(moduleID) != nil
        lock.unlock()

        if wasRemoved {
            logger.info("扫描器", "模块 '\(moduleID)' 已移出黑名单")
            let payload = UIModuleBlacklistPayload(moduleID: moduleID, isBlacklisted: false)
            NotificationCenter.default.post(name: .uiModuleBlacklistChanged, object: payload)
        }
    }

    public func isBlacklisted(_ moduleID: String) -> Bool {
        lock.lock()
        let result = blacklist.contains(moduleID)
        lock.unlock()
        return result
    }

    // MARK: - 扫描目录

    public func scan(directory: URL? = nil) -> [UIModuleDiscoveryResult] {
        let dir = directory ?? defaultModuleDirectory
        logger.info("扫描器", "开始扫描UI模块目录: \(dir.path)")

        guard checkDirectoryExists(dir) else {
            return []
        }

        return executeScan(at: dir)
    }

    /// 递归扫描：支持子目录嵌套bundle（最大深度10层，防止符号链接死循环）
    public func scanRecursive(directory: URL? = nil) -> [UIModuleDiscoveryResult] {
        let dir = directory ?? defaultModuleDirectory
        logger.info("扫描器", "开始递归扫描UI模块目录: \(dir.path)")

        guard checkDirectoryExists(dir) else { return [] }

        var allResults: [UIModuleDiscoveryResult] = []
        collectBundlesRecursive(at: dir, results: &allResults)
        return allResults
    }

    // 递归收集bundle（最大深度10层，防止符号链接死循环）
    private func collectBundlesRecursive(at dir: URL, results: inout [UIModuleDiscoveryResult], depth: Int = 0) {
        guard depth < 10 else {
            logger.warning("扫描器", "递归扫描达到最大深度限制(10)，跳过更深目录: \(dir.path)")
            return
        }

        let levelResults = executeScan(at: dir)
        results.append(contentsOf: levelResults)

        guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }

        for url in contents {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if url.pathExtension != "bundle" {
                    collectBundlesRecursive(at: url, results: &results, depth: depth + 1)
                }
            }
        }
    }

    // 检查目录是否存在
    private func checkDirectoryExists(_ dir: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: dir.path) else {
            logger.warning("扫描器", "模块目录不存在: \(dir.path)")
            return false
        }
        return true
    }

    // 执行扫描全流程
    private func executeScan(at dir: URL) -> [UIModuleDiscoveryResult] {
        let results = performScan(at: dir)
        buildIndex(from: results)
        saveIndexToDisk()
        postScanCompleted(results: results, directory: dir)
        logger.info("扫描器", "扫描完成，发现 \(results.count) 个有效模块")
        return results
    }

    // 遍历目录执行扫描
    private func performScan(at dir: URL) -> [UIModuleDiscoveryResult] {
        var results: [UIModuleDiscoveryResult] = []
        var seenIDs: Set<String> = []

        do {
            let contents = try listDirectoryContents(dir)
            for url in contents {
                if let result = processBundleURL(url, seenIDs: &seenIDs) {
                    results.append(result)
                }
            }
        } catch {
            logger.error("扫描器", "扫描模块目录失败: \(error.localizedDescription)")
        }

        return results
    }

    // 枚举所有bundle（带修改时间）
    private func enumerateBundles(at dir: URL) -> [(URL, Date)]? {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return nil
        }

        var bundles: [(URL, Date)] = []
        for url in contents {
            guard url.pathExtension == "bundle" else { continue }
            guard !url.lastPathComponent.hasPrefix(".") else { continue }
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            bundles.append((url, modDate))
        }
        return bundles
    }

    // 列出目录内容
    private func listDirectoryContents(_ dir: URL) throws -> [URL] {
        return try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    }

    // 处理单个 Bundle URL
    private func processBundleURL(_ url: URL, seenIDs: inout Set<String>) -> UIModuleDiscoveryResult? {
        guard shouldProcessBundle(url: url) else { return nil }

        guard !isURLBlacklisted(url) else {
            logger.info("扫描器", "跳过黑名单模块: \(url.lastPathComponent)")
            return nil
        }

        guard let result = parseBundle(at: url) else { return nil }

        guard !isDuplicate(result: result, seenIDs: &seenIDs) else {
            logger.warning("扫描器", "检测到重复模块ID: \(result.moduleID)，路径: \(url.path)")
            return nil
        }

        logModuleDiscovered(result)
        return result
    }

    // 判断是否需要处理该 URL
    private func shouldProcessBundle(url: URL) -> Bool {
        guard url.pathExtension == "bundle" else { return false }
        let filename = url.lastPathComponent
        guard !filename.hasPrefix(".") else { return false }
        return true
    }

    // 检查 URL 是否在黑名单中
    private func isURLBlacklisted(_ url: URL) -> Bool {
        let filename = url.lastPathComponent
        lock.lock()
        let isBlacklisted = blacklist.contains { filename.contains($0) }
        lock.unlock()
        return isBlacklisted
    }

    // 检查是否重复
    private func isDuplicate(result: UIModuleDiscoveryResult, seenIDs: inout Set<String>) -> Bool {
        if seenIDs.contains(result.moduleID) {
            return true
        }
        seenIDs.insert(result.moduleID)
        return false
    }

    // 记录发现模块
    private func logModuleDiscovered(_ result: UIModuleDiscoveryResult) {
        logger.info("扫描器", "发现模块: \(result.metadata.moduleName) (ID: \(result.moduleID), 版本: \(result.metadata.version))")
    }

    // 建立索引
    private func buildIndex(from results: [UIModuleDiscoveryResult]) {
        lock.lock()
        for result in results {
            scannedModules[result.moduleID] = result
        }
        lock.unlock()
    }

    // 发送扫描完成通知
    private func postScanCompleted(results: [UIModuleDiscoveryResult], directory: URL) {
        let payload = UIModuleScanPayload(
            results: results,
            count: results.count,
            directoryPath: directory.path
        )
        NotificationCenter.default.post(name: .uiModuleScanCompleted, object: payload)
    }

    // MARK: - 解析单个bundle（带Plist缓存）

    /// 解析指定路径的UI模块bundle，读取Info.plist，验证结构完整性。
    ///
    /// 此方法只解析并返回结果，不会将结果注册到内部扫描索引。
    /// 如需更新索引，请使用 `scan()`、`incrementalScan()` 或 `scanRecursive()`。
    /// - Parameter url: bundle目录的URL
    /// - Returns: 解析成功返回 `UIModuleDiscoveryResult`，失败返回 `nil`
    public func parseBundle(at url: URL) -> UIModuleDiscoveryResult? {
        let bundlePath = url.path

        // 先查Plist缓存（锁外快速判断，实际读取时再加锁判断）
        lock.lock()
        let cachedInfo = plistCache[bundlePath]
        lock.unlock()

        if let info = cachedInfo {
            // 缓存中的info已在首次解析时通过validateModuleID，无需重复检查
            return buildDiscoveryResult(info: info, url: url)
        }

        // 缓存未命中，走完整解析
        guard let plistURL = findPlistURL(at: url) else {
            logMissingPlist(for: url)
            return nil
        }

        guard let info = readAndDecodePlist(at: plistURL) else {
            return nil
        }

        guard validateModuleID(info) else {
            logInvalidModuleID(for: url)
            return nil
        }

        guard validateBundleStructure(at: url) else {
            logInvalidStructure(for: url)
            return nil
        }

        // 写入缓存
        lock.lock()
        plistCache[bundlePath] = info
        lock.unlock()

        return buildDiscoveryResult(info: info, url: url)
    }

    /// 清除指定bundle的Plist缓存
    public func invalidateCache(bundlePath: String) {
        lock.lock()
        plistCache.removeValue(forKey: bundlePath)
        // 也从索引移除
        let toRemove = scannedModules.first { $0.value.bundleURL.path == bundlePath }?.key
        if let key = toRemove {
            scannedModules.removeValue(forKey: key)
        }
        lock.unlock()
        logger.info("扫描器", "已清除bundle缓存: \(bundlePath)")
    }

    /// 清空全部缓存
    public func clearAllCache() {
        lock.lock()
        plistCache.removeAll()
        scannedModules.removeAll()
        bundleModDates.removeAll()
        lock.unlock()
        logger.info("扫描器", "全部缓存已清空")
    }

    // 查找 plist 文件
    private func findPlistURL(at url: URL) -> URL? {
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        let altInfoPlistURL = url.appendingPathComponent("Info.plist")

        if FileManager.default.fileExists(atPath: infoPlistURL.path) {
            return infoPlistURL
        }
        if FileManager.default.fileExists(atPath: altInfoPlistURL.path) {
            return altInfoPlistURL
        }
        return nil
    }

    // 记录缺少 plist
    private func logMissingPlist(for url: URL) {
        logger.warning("扫描器", "Bundle 缺少 Info.plist: \(url.lastPathComponent)")
    }

    // 读取并解码 plist
    private func readAndDecodePlist(at plistURL: URL) -> UIModulePlistInfo? {
        // 获取 bundle 名称：plist 在 Contents/Info.plist 时需上两级，直接 Info.plist 时上一级
        let parentDir = plistURL.deletingLastPathComponent()
        let bundleName: String
        if parentDir.lastPathComponent == "Contents" {
            bundleName = parentDir.deletingLastPathComponent().lastPathComponent
        } else {
            bundleName = parentDir.lastPathComponent
        }
        guard let plistData = readPlistData(at: plistURL) else {
            logger.warning("扫描器", "无法读取 Info.plist: \(bundleName)")
            return nil
        }
        guard let info = decodePlistData(plistData) else {
            logger.warning("扫描器", "Info.plist 格式无效: \(bundleName)")
            return nil
        }
        return info
    }

    // 读取 plist 数据
    private func readPlistData(at url: URL) -> Data? {
        return try? Data(contentsOf: url)
    }

    // 解码 plist 数据
    private func decodePlistData(_ data: Data) -> UIModulePlistInfo? {
        let decoder = PropertyListDecoder()
        return try? decoder.decode(UIModulePlistInfo.self, from: data)
    }

    // 验证模块ID
    private func validateModuleID(_ info: UIModulePlistInfo) -> Bool {
        return !info.UIModuleID.isEmpty
    }

    // 记录无效模块ID
    private func logInvalidModuleID(for url: URL) {
        logger.warning("扫描器", "Info.plist 缺少有效的 UIModuleID: \(url.lastPathComponent)")
    }

    // 验证bundle结构（检查是否为有效的bundle目录，不要求 executable/principalClass）
    private func validateBundleStructure(at url: URL) -> Bool {
        return Bundle(url: url) != nil
    }

    // 记录结构无效
    private func logInvalidStructure(for url: URL) {
        logger.warning("扫描器", "Bundle 结构不完整: \(url.lastPathComponent)")
    }

    // 构建发现结果
    private func buildDiscoveryResult(info: UIModulePlistInfo, url: URL) -> UIModuleDiscoveryResult {
        let metadata = UIModuleMetadata(
            moduleID: info.UIModuleID,
            moduleName: info.UIModuleName ?? info.UIModuleID,
            version: info.UIModuleVersion ?? "2.0",
            minFrameworkVersion: info.UIModuleMinFrameworkVersion,
            dependencies: info.UIModuleDependencies ?? [],
            author: info.UIModuleAuthor,
            description: info.UIModuleDescription,
            isBuiltIn: info.UIModuleIsBuiltIn ?? false
        )
        return UIModuleDiscoveryResult(moduleID: info.UIModuleID, bundleURL: url, metadata: metadata)
    }

    // MARK: - 索引持久化

    /// 保存索引到磁盘
    private func saveIndexToDisk() {
        lock.lock()
        let snapshot = scannedModules
        lock.unlock()

        let indexData: [[String: String]] = snapshot.compactMap { (_, result) in
            guard let jsonData = try? JSONEncoder().encode(result.metadata),
                  let jsonStr = String(data: jsonData, encoding: .utf8) else {
                return nil
            }
            return [
                "moduleID": result.moduleID,
                "bundlePath": result.bundleURL.path,
                "metadataJSON": jsonStr
            ]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: indexData, options: .prettyPrinted) else {
            return
        }

        try? data.write(to: indexSaveURL)
    }

    /// 从磁盘恢复索引
    private func restoreIndexFromDisk() {
        guard let data = try? Data(contentsOf: indexSaveURL) else { return }
        guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return }

        var restored: [String: UIModuleDiscoveryResult] = [:]
        for entry in entries {
            guard let moduleID = entry["moduleID"],
                  let bundlePath = entry["bundlePath"],
                  let jsonStr = entry["metadataJSON"],
                  let jsonData = jsonStr.data(using: .utf8),
                  let metadata = try? JSONDecoder().decode(UIModuleMetadata.self, from: jsonData) else {
                continue
            }
            let result = UIModuleDiscoveryResult(
                moduleID: moduleID,
                bundleURL: URL(fileURLWithPath: bundlePath),
                metadata: metadata
            )
            restored[moduleID] = result
        }

        lock.lock()
        scannedModules = restored
        lock.unlock()

        logger.info("扫描器", "已从磁盘恢复 \(restored.count) 条索引记录")
    }

    // MARK: - 查询

    public func scannedModule(moduleID: String) -> UIModuleDiscoveryResult? {
        lock.lock()
        let result = scannedModules[moduleID]
        lock.unlock()
        return result
    }

    public func allScannedModules() -> [UIModuleDiscoveryResult] {
        lock.lock()
        let results = Array(scannedModules.values)
        lock.unlock()
        return results
    }

    // MARK: - 目录监听（用于热插拔）

    public func startWatching(directory: URL? = nil) {
        let dir = directory ?? defaultModuleDirectory

        stopCurrentWatching()

        guard checkDirectoryExists(dir) else {
            return
        }

        startFileSystemWatch(at: dir)
        logger.info("扫描器", "已启动目录监听: \(dir.path)")
    }

    // 停止当前监听（公开方法，外部可主动停止）
    public func stopWatching() { stopCurrentWatching() }
    public func stopCurrentWatching() {
        lock.lock()
        let source = fileSystemSource
        fileSystemSource = nil
        lock.unlock()

        // 锁外取消，避免cancel handler重新拿锁时的竞态
        source?.cancel()
    }

    // 启动文件系统监听
    private func startFileSystemWatch(at dir: URL) {
        let fd = openDirectoryForWatching(dir)
        guard fd >= 0 else { return }

        let source = createDispatchSource(fd: fd, directory: dir)
        storeDispatchSource(source)
        source.resume()
    }

    // 打开目录用于监听
    private func openDirectoryForWatching(_ dir: URL) -> Int32 {
        let fd = open(dir.path, O_EVTONLY)
        if fd < 0 {
            logger.warning("扫描器", "无法打开目录进行监听: \(dir.path)")
        }
        return fd
    }

    // 创建文件系统监听源
    private func createDispatchSource(fd: Int32, directory: URL) -> DispatchSourceFileSystemObject {
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.logger.info("扫描器", "检测到目录变化，触发增量扫描")
            self.incrementalScan(directory: directory)
        }

        source.setCancelHandler {
            close(fd)
        }

        return source
    }

    // 保存监听源
    private func storeDispatchSource(_ source: DispatchSourceFileSystemObject) {
        lock.lock()
        fileSystemSource = source
        lock.unlock()
    }

    deinit {
        stopCurrentWatching()
    }
}

// MARK: - 迁回自 UI-02：struct UIModulePlistInfo
// MARK: - UI管理文件迁移类型（UI-03 ~ UI-21）

// MARK: - 迁移自 UI-03_扫描UI模块目录.swift：UIModulePlistInfo
internal struct UIModulePlistInfo: Codable {
    let UIModuleID: String
    let UIModuleName: String?
    let UIModuleVersion: String?
    let UIModuleMinFrameworkVersion: String?
    let UIModuleDependencies: [String]?
    let UIModuleAuthor: String?
    let UIModuleDescription: String?
    let UIModuleIsBuiltIn: Bool?
}
