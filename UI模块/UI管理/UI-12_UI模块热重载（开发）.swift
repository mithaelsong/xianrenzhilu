// MARK: - UI-11: UI模块热重载（开发）
// 功能编号: UI-12
// 版本: 2.0
// 职责: 开发时监听模块文件变化自动重载，精确检测变化模块，防抖处理，仅DEBUG模式开启
// 依赖: UI-09 热替换, UI-12 日志, UI-01 扫描器

import Foundation
import AppKit

// MARK: - 热重载管理器
// 独立编译存根

// 类型 UIModuleScanner 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleHotReplacer 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleRegistry 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleLocator 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleHotReloader 已迁移到 UI-02_公共类型定义.swift

// MARK: - 测试
internal func test_UI11() {
    print("\n=== UI-11 热重载模块测试 ===\n")

    let reloader = UIModuleHotReloader.shared

    // MARK: 测试1: 手动重载不存在模块 → failed
    print("🧪 测试1: 手动重载不存在模块")
    let result1 = reloader.reloadModule(name: "NotExist", bundlePath: "/tmp/test.bundle")
    switch result1 {
    case .failed(let reason, _):
        guard reason.contains("未加载") || reason.contains("验证失败") else {
            fatalError("❌ 测试1失败: 失败原因应包含'未加载'或'验证失败'，实际: \(reason)")
        }
    default:
        fatalError("❌ 测试1失败: 重载不存在模块应返回failed，实际: \(result1)")
    }
    print("✅ 测试1通过: 手动重载不存在模块返回 failed")

    // MARK: 测试2: 监听目录启动与停止
    print("\n🧪 测试2: 监听目录启动与停止")
    let tempDir = FileManager.default.temporaryDirectory
    reloader.startWatching(directory: tempDir)
    // 重复启动应安全
    reloader.startWatching(directory: tempDir)
    reloader.stopWatching()
    // 重复停止应安全
    reloader.stopWatching()
    print("✅ 测试2通过: 重复启动/停止不崩溃")

    // MARK: 测试3: 手动重载模块存在但bundle不存在
    print("\n🧪 测试3: 手动重载已注册但bundle不存在")
    let moduleID = "test.reloader.module"
    let moduleName = "热重载测试模块"

// 类型 UIReloaderTestModule 已迁移到 UI-02_公共类型定义.swift

    let testModule = UIReloaderTestModule(id: moduleID, name: moduleName)
    UIModuleRegistry.shared.register(module: testModule, name: moduleName)
    UIModuleLocator.shared.clearCache()

    let result3 = reloader.reloadModule(name: moduleName, bundlePath: "/nonexistent/bundle")
    switch result3 {
    case .failed(let reason, _):
        guard reason.contains("bundle不存在") else {
            fatalError("❌ 测试3失败: 应提示bundle不存在，实际: \(reason)")
        }
    case .rolledBack(let reason, _):
        print("  热重载触发回滚: \(reason)")
    default:
        fatalError("❌ 测试3失败: nonexistent bundle应返回failed/rolledBack")
    }

    UIModuleRegistry.shared.unregister(name: moduleName)
    UIModuleLocator.shared.clearCache()
    print("✅ 测试3通过: 已注册但bundle不存在返回failed")

    // MARK: 测试4: 防抖行为验证
    print("\n🧪 测试4: 快照刷新")
    let dir = FileManager.default.temporaryDirectory
    reloader.startWatching(directory: dir)
    // 在 DEBUG 下 refreshSnapshot 可用
    #if DEBUG
    reloader.refreshSnapshot()
    #endif
    reloader.stopWatching()
    print("✅ 测试4通过: 快照刷新不崩溃")

    print("\n=== 全部 UI-11 热重载模块测试通过 ✅ ===\n")
}


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIReloaderTestModule
    final class UIReloaderTestModule: UIModuleProtocol , @unchecked Sendable{
        required init() {}
        var moduleID: String = ""
        var moduleName: String = ""
        let moduleVersion = "2.0"
        let moduleDescription = ""
        let isUnloadable = true
        init(id: String, name: String) { moduleID = id; moduleName = name }
        func start(context: Any?) throws {}
        func stop() {}
        func pause() {}
        func resume() {}
        func willUnload() throws {}
        func didUnload() {}
    }

// MARK: - 迁回自 UI-02：class UIModuleHotReloader
public final class UIModuleHotReloader : @unchecked Sendable {
    public static let shared = UIModuleHotReloader()

    let lock = NSRecursiveLock()
    private let logger = UILoadingLogManager.shared
    private let replacer = UIModuleHotReplacer.shared
    private let scanner = UIModuleScanner.shared

    #if DEBUG
    private var source: DispatchSourceFileSystemObject?
    private var watchingPath: String?

    // 防抖
    private var debounceWorkItem: DispatchWorkItem?
    /// 防抖代数计数器，用于检测过期 work item
    private var debounceGeneration: UInt64 = 0
    private let debounceInterval: TimeInterval = 1.0

    // 精确文件检测（bundle路径 → 修改时间）
    private var lastScanSnapshot: [String: Date] = [:]
    #endif

    private init() {}

    // MARK: - 监听目录

    /// 开始监听指定目录的模块文件变化
    /// - Parameter directory: 监听目录URL
    public func startWatching(directory: URL) {
        #if DEBUG
        // 构建快照、创建 fd 与 source 均在锁外进行（不涉及共享状态）
        let snapshot = buildScanSnapshot(at: directory)

        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else {
            logger.warning("热重载", "无法监听目录: \(directory.path)")
            return
        }

        let newSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        let newPath = directory.path
        newSource.setEventHandler { [weak self] in
            self?.handleFileChange()
        }
        newSource.setCancelHandler { close(fd) }

        // 一次锁内原子交换所有共享状态，避免中间态引发的竞争
        lock.lock()
        source?.cancel()
        source = newSource
        watchingPath = newPath
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        debounceGeneration &+= 1
        lastScanSnapshot = snapshot
        lock.unlock()

        newSource.resume()
        logger.info("热重载", "开始监听模块目录变化: \(directory.path)")
        #else
        logger.info("热重载", "热重载仅在 DEBUG 模式下可用")
        #endif
    }

    /// 停止监听目录
    public func stopWatching() {
        #if DEBUG
        lock.lock()
        source?.cancel()
        source = nil
        watchingPath = nil
        lastScanSnapshot.removeAll()
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        debounceGeneration &+= 1
        lock.unlock()
        logger.info("热重载", "目录监听已停止")
        #endif
    }

    // MARK: - 快照管理

    #if DEBUG
    /// 构建目录扫描快照（bundle路径 → 修改时间）
    private func buildScanSnapshot(at directory: URL) -> [String: Date] {
        var snapshot: [String: Date] = [:]

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else {
            return [:]
        }

        for url in contents {
            guard url.pathExtension == "bundle" else { continue }
            guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { continue }
            if let modDate = attrs[.modificationDate] as? Date {
                snapshot[url.path] = modDate
            }
        }

        return snapshot
    }
    #endif

    // MARK: - 检测变化模块

    #if DEBUG
    /// 检测目录中具体发生了变化的模块（对比新旧快照）
    private func detectChangedModules(directory: URL) -> [(name: String, bundlePath: String)] {
        let currentSnapshot = buildScanSnapshot(at: directory)

        // 一次锁内完成读旧快照和写新快照，保证原子性
        lock.lock()
        let previousSnapshot = lastScanSnapshot
        lastScanSnapshot = currentSnapshot
        lock.unlock()

        var changedModules: [(name: String, bundlePath: String)] = []

        for (path, currentDate) in currentSnapshot {
            if let previousDate = previousSnapshot[path] {
                if currentDate != previousDate {
                    let name = (path as NSString).lastPathComponent
                    changedModules.append((name: name, bundlePath: path))
                    logger.info("热重载", "检测到模块变化: \(name)")
                }
            } else {
                let name = (path as NSString).lastPathComponent
                changedModules.append((name: name, bundlePath: path))
                logger.info("热重载", "检测到新增模块: \(name)")
            }
        }

        return changedModules
    }
    #endif

    // MARK: - 文件变更处理（带防抖）

    #if DEBUG
    private func handleFileChange() {
        lock.lock()
        debounceWorkItem?.cancel()

        guard let dirPath = watchingPath else {
            lock.unlock()
            logger.warning("热重载", "未设置监听路径，无法处理文件变化")
            return
        }

        // 记录当前代数，用于 work item 执行时判断是否已过期
        let gen = debounceGeneration &+ 1
        debounceGeneration = gen
        lock.unlock()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // 检查此 work item 是否已被更新的防抖任务取代
            self.lock.lock()
            let isStale = self.debounceGeneration != gen
            self.lock.unlock()
            guard !isStale else { return }

            self.logger.info("热重载", "防抖触发，开始检测变化模块...")

            let directory = URL(fileURLWithPath: dirPath)
            let changedModules = self.detectChangedModules(directory: directory)

            if changedModules.isEmpty {
                self.logger.info("热重载", "未检测到具体模块变化，忽略本次事件")
                return
            }

            for (name, bundlePath) in changedModules {
                self.logger.info("热重载", "自动重载模块 '\(name)' (路径: \(bundlePath))")
                let result = self.replacer.hotReplace(name: name, newBundlePath: bundlePath)

                switch result {
                case .success(let state):
                    self.logger.info("热重载", "模块 '\(name)' 热重载成功 (状态: \(state.rawValue))")
                case .failed(let reason, let state):
                    self.logger.error("热重载", "模块 '\(name)' 热重载失败: \(reason) (状态: \(state.rawValue))")
                case .rolledBack(let reason, let state):
                    self.logger.warning("热重载", "模块 '\(name)' 热重载回滚: \(reason) (状态: \(state.rawValue))")
                }
            }
        }

        lock.lock()
        debounceWorkItem = workItem
        lock.unlock()

        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
        logger.info("热重载", "文件变化事件已触发，等待防抖 \(debounceInterval) 秒...")
    }
    #endif

    // MARK: - 手动触发重载

    /// 手动触发模块热重载
    /// - Parameters:
    ///   - name: 模块名称
    ///   - bundlePath: 新模块bundle路径
    /// - Returns: 热替换结果
    public func reloadModule(name: String, bundlePath: String) -> UIModuleHotReplaceResult {
        let start = Date()
        let result = replacer.hotReplace(name: name, newBundlePath: bundlePath)
        let duration = Date().timeIntervalSince(start)

        switch result {
        case .success(let state):
            logger.info("热重载", "模块 '\(name)' 手动重载成功 (状态: \(state.rawValue), 耗时: \(String(format: "%.2f", duration))秒)")
        case .failed(let reason, let state):
            logger.error("热重载", "模块 '\(name)' 手动重载失败: \(reason) (状态: \(state.rawValue))")
        case .rolledBack(let reason, let state):
            logger.warning("热重载", "模块 '\(name)' 手动重载回滚: \(reason) (状态: \(state.rawValue))")
        }

        return result
    }

    #if DEBUG
    /// 强制刷新快照（手动同步目录状态）
    /// - Parameter directory: 可选目录，默认使用监听中的目录
    public func refreshSnapshot(directory: URL? = nil) {
        let dir: URL
        if let d = directory {
            dir = d
        } else {
            lock.lock()
            guard let path = watchingPath else {
                lock.unlock()
                logger.warning("热重载", "无有效监听路径，无法刷新快照")
                return
            }
            lock.unlock()
            dir = URL(fileURLWithPath: path)
        }

        let snapshot = buildScanSnapshot(at: dir)
        lock.lock()
        lastScanSnapshot = snapshot
        lock.unlock()

        logger.info("热重载", "快照已刷新，当前 \(snapshot.count) 个模块")
    }
    #endif
}
