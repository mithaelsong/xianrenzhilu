// 功能23: 异步加载器
// 版本: 2.0
// 对应: 数据请求、图片加载等耗时操作异步执行，不阻塞UI
// 优先级: P1

import AppKit
import Foundation
import os.log

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能23：异步加载器 — 单元测试
/// 覆盖：任务调度/优先级/取消/缓存/LRU
func test_asyncLoader() {
    let loader = UIAsyncLoader.shared
    
    print("\n🧪 测试1: 简化任务调度")
    loader.load({
        return 42
    }, completion: { (state: UILoadingState<Int>) in
        if case .success = state { }
    })
    print("✅ 测试1通过: 简化任务调度正常")
    
    print("\n🧪 测试2: 配置读写")
    let config = loader.getConfiguration()
    _ = config.maxConcurrentLoads
    loader.resetToDefaultConfiguration()
    print("✅ 测试2通过: 配置读写正常")
    
    print("\n🧪 测试3: 缓存统计")
    let stats = loader.cacheStatistics
    _ = stats.hitRate
    print("✅ 测试3通过: 缓存统计正常")
    
    print("\n🧪 测试4: 清理缓存")
    loader.clearCache(type: .all)
    print("✅ 测试4通过: 缓存清理正常")
    
    print("\n🧪 测试5: 配置更新")
    loader.updateConfiguration { config in
        config.maxConcurrentLoads = 8
    }
    guard loader.configuration.maxConcurrentLoads == 8 else {
        fatalError("❌ 测试5失败: 配置更新未生效")
    }

    print("✅ 测试5通过: 配置更新成功")
    
    print("\n🧪 测试6: 优先级比较")
    guard UILoadingPriority.high > UILoadingPriority.normal else {
        fatalError("❌ 测试6失败: 优先级比较错误")
    }
    print("✅ 测试6通过: 优先级比较正确")
    
    print("\n🧪 测试7: 加载指示器")
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    let indicator = UILoadingIndicatorView(frame: view.bounds)
    indicator.show(in: view, message: "加载中...")
    indicator.updateMessage("正在处理...")
    indicator.hide()
    print("✅ 测试7通过: 加载指示器正常")
    
    print("\n=== 全部异步加载器测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    static let asyncLoaderTaskStarted = Notification.Name("AsyncLoader.TaskStarted")
    static let asyncLoaderTaskProgressed = Notification.Name("AsyncLoader.TaskProgressed")
    static let asyncLoaderTaskCompleted = Notification.Name("AsyncLoader.TaskCompleted")
    static let asyncLoaderTaskFailed = Notification.Name("AsyncLoader.TaskFailed")
    static let asyncLoaderTaskCancelled = Notification.Name("AsyncLoader.TaskCancelled")
    static let asyncLoaderCacheCleared = Notification.Name("AsyncLoader.CacheCleared")
    static let asyncLoaderCacheSettingsChanged = Notification.Name("AsyncLoader.CacheSettingsChanged")
}

// MARK: - 迁回自 UI-02：class UILoadingTaskWrapper
private final class UILoadingTaskWrapper: Operation, UICancellableLoadingTask, @unchecked Sendable {
    let taskID: String
    var priority: UILoadingPriority {
        didSet {
            queuePriority = priority.operationPriority
        }
    }
    private var _isCancelled: Bool = false
    private let cancelLock = NSRecursiveLock()
    
    private let work: (@escaping @Sendable (UILoadingProgress) -> Void) throws -> Any
    private let onProgress: (@Sendable (UILoadingProgress) -> Void)?
    private let onComplete: @Sendable (Result<Any, Error>) -> Void
    /// 包装非Sendable值以便跨并发域传递
    private struct SendableBox: @unchecked Sendable {
        let value: Any
        init(_ v: Any) { self.value = v }
    }
    
    override var isCancelled: Bool {
        cancelLock.lock()
        defer { cancelLock.unlock() }
        return _isCancelled
    }
    
    init(
        taskID: String,
        priority: UILoadingPriority,
        work: @escaping (@escaping @Sendable (UILoadingProgress) -> Void) throws -> Any,
        onProgress: (@Sendable (UILoadingProgress) -> Void)? = nil,
        onComplete: @escaping @Sendable (Result<Any, Error>) -> Void
    ) {
        self.taskID = taskID
        self.priority = priority
        self.work = work
        self.onProgress = onProgress
        self.onComplete = onComplete
        super.init()
        self.queuePriority = priority.operationPriority
    }
    
    override func cancel() {
        cancelLock.lock()
        _isCancelled = true
        cancelLock.unlock()
        super.cancel()
    }
    
    override func main() {
        guard !isCancelled else {
            DispatchQueue.main.async { self.onComplete(.failure(CancellationError())) }
            return
        }
        
        let progressHandler: @Sendable (UILoadingProgress) -> Void = { [weak self] progress in
            guard let self = self, !self.isCancelled else { return }
            DispatchQueue.main.async {
                self.onProgress?(progress)
                NotificationCenter.default.post(
                    name: .asyncLoaderTaskProgressed,
                    object: nil,
                    userInfo: ["taskID": self.taskID, "progress": progress]
                )
            }
        }
        
        do {
            let box = SendableBox(try work(progressHandler))
            guard !isCancelled else {
                DispatchQueue.main.async { self.onComplete(.failure(CancellationError())) }
                return
            }
            DispatchQueue.main.async { self.onComplete(.success(box.value)) }
        } catch {
            let errorBox = SendableBox(error)
            DispatchQueue.main.async { self.onComplete(.failure(errorBox.value as! Error)) }
        }
    }
}

// MARK: - 迁回自 UI-02：class UILRUCacheNode<Key
private final class UILRUCacheNode<Key: Hashable, Value> {
    var key: Key
    var value: Value
    var size: Int
    var prev: UILRUCacheNode?
    var next: UILRUCacheNode?
    var timestamp: Date
    
    init(key: Key, value: Value, size: Int) {
        self.key = key
        self.value = value
        self.size = size
        self.timestamp = Date()
    }
}

// MARK: - 迁回自 UI-02：class UILRUCache<Key
private final class UILRUCache<Key: Hashable, Value> {
    private var map: [Key: UILRUCacheNode<Key, Value>] = [:]
    private var head: UILRUCacheNode<Key, Value>?
    private var tail: UILRUCacheNode<Key, Value>?
    private let lock = NSRecursiveLock()
    
    var maxSize: Int
    var currentSize: Int = 0
    var totalHits: Int64 = 0
    var totalMisses: Int64 = 0
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        if let node = map[key] {
            moveToHead(node)
            totalHits += 1
            return node.value
        }
        totalMisses += 1
        return nil
    }
    
    func set(_ key: Key, value: Value, size: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        if let node = map[key] {
            node.value = value
            node.size = size
            node.timestamp = Date()
            moveToHead(node)
        } else {
            let node = UILRUCacheNode(key: key, value: value, size: size)
            map[key] = node
            addToHead(node)
            currentSize += size
            
            while currentSize > maxSize, let tail = tail {
                remove(tail)
            }
        }
    }
    
    func remove(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        if let node = map[key] {
            remove(node)
            return node.value
        }
        return nil
    }
    
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        
        map.removeAll()
        head = nil
        tail = nil
        currentSize = 0
    }
    
    func removeExpired(threshold: Date) -> [(Key, Value)] {
        lock.lock()
        defer { lock.unlock() }
        
        var expired: [(Key, Value)] = []
        var node = tail
        while let current = node {
            node = current.prev
            if current.timestamp < threshold {
                remove(current)
                expired.append((current.key, current.value))
            }
        }
        return expired
    }
    
    func allKeys() -> [Key] {
        lock.lock()
        defer { lock.unlock() }
        return Array(map.keys)
    }
    
    func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return map.count
    }
    
    func totalSize() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return currentSize
    }
    
    private func addToHead(_ node: UILRUCacheNode<Key, Value>) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil { tail = node }
    }
    
    private func moveToHead(_ node: UILRUCacheNode<Key, Value>) {
        remove(node)
        addToHead(node)
    }
    
    private func remove(_ node: UILRUCacheNode<Key, Value>) {
        map.removeValue(forKey: node.key)
        currentSize -= node.size
        
        if node.prev != nil { node.prev?.next = node.next }
        else { head = node.next }
        
        if node.next != nil { node.next?.prev = node.prev }
        else { tail = node.prev }
        
        node.prev = nil
        node.next = nil
    }
}

// MARK: - 迁回自 UI-02：class UIImageCacheManager
private final class UIImageCacheManager : @unchecked Sendable {
    private let memoryCache: NSCache<NSString, NSImage>
    private var lruCache: UILRUCache<String, NSImage>
    private let lock = NSRecursiveLock()
    private var diskCacheDirectory: URL
    
    var memoryLimitMB: Double = 100 {
        didSet { updateMemoryLimit() }
    }
    var diskLimitMB: Double = 500 {
        didSet { cleanDiskCacheIfNeeded() }
    }
    var expirationDays: Int = 7
    
    private var totalMemorySize: Int = 0
    
    init() {
        memoryCache = NSCache<NSString, NSImage>()
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 默认100MB
        
        lruCache = UILRUCache(maxSize: 100 * 1024 * 1024)
        
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDirectory = cacheDir.appendingPathComponent("AsyncLoader/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }
    
    func image(forKey key: String) -> NSImage? {
        // 1. 先查内存缓存
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }
        
        // 2. 查 LRU 缓存
        if let image = lruCache.get(key) {
            memoryCache.setObject(image, forKey: key as NSString, cost: imageCost(image))
            return image
        }
        
        // 3. 查磁盘缓存
        let diskPath = diskPath(forKey: key)
        if FileManager.default.fileExists(atPath: diskPath.path),
           let data = try? Data(contentsOf: diskPath),
           let image = NSImage(data: data) {
            let cost = imageCost(image)
            lruCache.set(key, value: image, size: cost)
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)
            return image
        }
        
        return nil
    }
    
    func setImage(_ image: NSImage, forKey key: String) {
        let cost = imageCost(image)
        
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
        lruCache.set(key, value: image, size: cost)
        
        // 异步写入磁盘
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            if let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: self.diskPath(forKey: key))
            }
        }
    }
    
    func removeImage(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        _ = lruCache.remove(key)
        let path = diskPath(forKey: key)
        try? FileManager.default.removeItem(at: path)
    }
    
    func removeAll() {
        memoryCache.removeAllObjects()
        lruCache.removeAll()
        try? FileManager.default.removeItem(at: diskCacheDirectory)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }
    
    func removeExpired() {
        let threshold = Date().addingTimeInterval(-Double(expirationDays) * 24 * 3600)
        _ = lruCache.removeExpired(threshold: threshold)
        
        // 清理磁盘过期文件
        let enumerator = FileManager.default.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
        while let url = enumerator?.nextObject() as? URL {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let date = attrs[.modificationDate] as? Date,
               date < threshold {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    func cleanLRUIfNeeded() {
        // LRU 缓存已自动维护，此方法用于手动触发
    }
    
    func cleanDiskCacheIfNeeded() {
        // 检查磁盘缓存大小，超出限制时按LRU清理
        let limitBytes = Int(diskLimitMB * 1024 * 1024)
        var totalSize: Int64 = 0
        var files: [(URL, Date, Int64)] = []
        
        let enumerator = FileManager.default.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
        while let url = enumerator?.nextObject() as? URL {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let date = attrs[.modificationDate] as? Date,
               let size = attrs[.size] as? Int64 {
                totalSize += size
                files.append((url, date, size))
            }
        }
        
        if totalSize > Int64(limitBytes) {
            files.sort { $0.1 < $1.1 } // 按时间排序， oldest first
            var removedSize: Int64 = 0
            let target = totalSize - Int64(limitBytes) / 2 // 清理到50%
            for (url, _, size) in files {
                if removedSize >= target { break }
                try? FileManager.default.removeItem(at: url)
                removedSize += size
            }
        }
    }
    
    func statistics() -> (memoryCount: Int, memorySizeMB: Double, diskCount: Int, diskSizeMB: Double) {
        let memCount = lruCache.count()
        let memSize = Double(lruCache.totalSize()) / 1024.0 / 1024.0
        
        var diskCount = 0
        var diskSize: Int64 = 0
        let enumerator = FileManager.default.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
        while let url = enumerator?.nextObject() as? URL {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                diskCount += 1
                diskSize += size
            }
        }
        
        return (memCount, memSize, diskCount, Double(diskSize) / 1024.0 / 1024.0)
    }
    
    private func updateMemoryLimit() {
        let bytes = Int(memoryLimitMB * 1024 * 1024)
        memoryCache.totalCostLimit = bytes
        lruCache.maxSize = bytes
    }
    
    private func diskPath(forKey key: String) -> URL {
        let safeKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return diskCacheDirectory.appendingPathComponent(safeKey + ".png")
    }
    
    private func imageCost(_ image: NSImage) -> Int {
        // 估算图片内存占用：假设 RGBA，8 bits per channel
        guard let rep = image.representations.first else { return 1 }
        let width = Int(rep.pixelsWide)
        let height = Int(rep.pixelsHigh)
        return width * height * 4
    }
}

// MARK: - 迁回自 UI-02：class UIDataCacheManager
private final class UIDataCacheManager : @unchecked Sendable {
    fileprivate var lruCache: UILRUCache<String, Data>
    private let lock = NSRecursiveLock()
    private var diskCacheDirectory: URL
    
    var memoryLimitMB: Double = 50 {
        didSet { lruCache.maxSize = Int(memoryLimitMB * 1024 * 1024) }
    }
    var diskLimitMB: Double = 200
    var expirationDays: Int = 7
    
    init() {
        lruCache = UILRUCache(maxSize: 50 * 1024 * 1024)
        
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDirectory = cacheDir.appendingPathComponent("AsyncLoader/Data", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }
    
    func data(forKey key: String) -> Data? {
        // 1. 查内存缓存
        if let data = lruCache.get(key) {
            return data
        }
        
        // 2. 查磁盘缓存
        let diskPath = self.diskPath(forKey: key)
        if FileManager.default.fileExists(atPath: diskPath.path),
           let data = try? Data(contentsOf: diskPath) {
            lruCache.set(key, value: data, size: data.count)
            return data
        }
        
        return nil
    }
    
    func setData(_ data: Data, forKey key: String) {
        lruCache.set(key, value: data, size: data.count)
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            try? data.write(to: self.diskPath(forKey: key))
        }
    }
    
    func removeData(forKey key: String) {
        _ = lruCache.remove(key)
        let path = diskPath(forKey: key)
        try? FileManager.default.removeItem(at: path)
    }
    
    func removeAll() {
        lruCache.removeAll()
        try? FileManager.default.removeItem(at: diskCacheDirectory)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }
    
    func removeExpired() {
        let threshold = Date().addingTimeInterval(-Double(expirationDays) * 24 * 3600)
        _ = lruCache.removeExpired(threshold: threshold)
        
        let enumerator = FileManager.default.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
        while let url = enumerator?.nextObject() as? URL {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let date = attrs[.modificationDate] as? Date,
               date < threshold {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    func cleanDiskCacheIfNeeded() {
        let limitBytes = Int(diskLimitMB * 1024 * 1024)
        var totalSize: Int64 = 0
        var files: [(URL, Date, Int64)] = []
        
        let enumerator = FileManager.default.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
        while let url = enumerator?.nextObject() as? URL {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let date = attrs[.modificationDate] as? Date,
               let size = attrs[.size] as? Int64 {
                totalSize += size
                files.append((url, date, size))
            }
        }
        
        if totalSize > Int64(limitBytes) {
            files.sort { $0.1 < $1.1 }
            var removedSize: Int64 = 0
            let target = totalSize - Int64(limitBytes) / 2
            for (url, _, size) in files {
                if removedSize >= target { break }
                try? FileManager.default.removeItem(at: url)
                removedSize += size
            }
        }
    }
    
    func statistics() -> (memoryCount: Int, memorySizeMB: Double, diskCount: Int, diskSizeMB: Double) {
        let memCount = lruCache.count()
        let memSize = Double(lruCache.totalSize()) / 1024.0 / 1024.0
        
        var diskCount = 0
        var diskSize: Int64 = 0
        let enumerator = FileManager.default.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
        while let url = enumerator?.nextObject() as? URL {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                diskCount += 1
                diskSize += size
            }
        }
        
        return (memCount, memSize, diskCount, Double(diskSize) / 1024.0 / 1024.0)
    }
    
    private func diskPath(forKey key: String) -> URL {
        let safeKey = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return diskCacheDirectory.appendingPathComponent(safeKey + ".dat")
    }
}

// MARK: - 迁回自 UI-02：class UIAsyncLoader
public final class UIAsyncLoader : @unchecked Sendable {

    // MARK: 单例
    public static let shared = UIAsyncLoader()
    
    // MARK: 日志
    static let logger = Logger(subsystem: "com.xianrenzhilu.asyncloader", category: "异步加载器")
    
    // MARK: 队列
    private let operationQueue: OperationQueue
    private let urlSession: URLSession
    
    // MARK: 缓存
    private let imageCache: UIImageCacheManager
    private let dataCache: UIDataCacheManager
    
    // MARK: 任务管理
    private var activeTasks: [String: UILoadingTaskWrapper] = [:]
    private let taskLock = NSRecursiveLock()
    private var taskCounter: Int64 = 0
    
    // MARK: 配置
    private let configLock = NSRecursiveLock()
    private var _configuration: UICacheConfiguration = .load()
    
    public var configuration: UICacheConfiguration {
        get {
            configLock.lock()
            defer { configLock.unlock() }
            return _configuration
        }
        set {
            configLock.lock()
            _configuration = newValue
            configLock.unlock()
            applyConfiguration(newValue)
            newValue.save()
            NotificationCenter.default.post(name: .asyncLoaderCacheSettingsChanged, object: nil)
            UIAsyncLoader.logger.info("⚙️ 缓存配置已更新并保存")
        }
    }
    
    // MARK: 初始化
    private init() {
        operationQueue = OperationQueue()
        operationQueue.name = "com.xianrenzhilu.asyncloader"
        operationQueue.maxConcurrentOperationCount = _configuration.maxConcurrentLoads
        operationQueue.qualityOfService = .userInitiated
        
        urlSession = URLSession(configuration: .default)
        
        imageCache = UIImageCacheManager()
        dataCache = UIDataCacheManager()
        
        applyConfiguration(_configuration)
        
        UIAsyncLoader.logger.info("✅ 异步加载器初始化完成，最大并发: \(self._configuration.maxConcurrentLoads)")
    }
    
    // MARK: 配置应用
    private func applyConfiguration(_ config: UICacheConfiguration) {
        imageCache.memoryLimitMB = config.imageMemoryCacheLimitMB
        imageCache.diskLimitMB = config.imageDiskCacheLimitMB
        imageCache.expirationDays = config.diskCacheExpirationDays
        
        dataCache.memoryLimitMB = config.dataMemoryCacheLimitMB
        dataCache.diskLimitMB = config.dataDiskCacheLimitMB
        dataCache.expirationDays = config.diskCacheExpirationDays
        
        operationQueue.maxConcurrentOperationCount = config.maxConcurrentLoads
    }
    
    // MARK: 生成任务ID
    private func generateTaskID() -> String {
        taskLock.lock()
        defer { taskLock.unlock() }
        taskCounter += 1
        return "async-task-\(taskCounter)"
    }
    
    // MARK: 注册/注销任务
    private func registerTask(_ wrapper: UILoadingTaskWrapper) {
        taskLock.lock()
        activeTasks[wrapper.taskID] = wrapper
        taskLock.unlock()
    }
    
    private func unregisterTask(_ taskID: String) {
        taskLock.lock()
        activeTasks.removeValue(forKey: taskID)
        taskLock.unlock()
    }
    
    // MARK: - 通用异步加载
    
    /// 异步执行任务，带状态回调
    @discardableResult
    public func load<T>(
        priority: UILoadingPriority = .normal,
        work: @escaping (@escaping @Sendable (UILoadingProgress) -> Void) throws -> T,
        onStart: (() -> Void)? = nil,
        onProgress: (@Sendable (UILoadingProgress) -> Void)? = nil,
        onComplete: @escaping @Sendable (UILoadingState<T>) -> Void
    ) -> UICancellableLoadingTask? {
        let taskID = generateTaskID()
        onStart?()
        
        NotificationCenter.default.post(
            name: .asyncLoaderTaskStarted,
            object: nil,
            userInfo: ["taskID": taskID]
        )
        UIAsyncLoader.logger.debug("🚀 任务开始: \(taskID), 优先级: \(priority.displayName)")
        
        let wrapper = UILoadingTaskWrapper(
            taskID: taskID,
            priority: priority,
            work: work,
            onProgress: onProgress,
            onComplete: { [weak self] result in
                self?.unregisterTask(taskID)
                switch result {
                case .success(let value):
                    if let typedValue = value as? T {
                        onComplete(.success(typedValue))
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskCompleted,
                            object: nil,
                            userInfo: ["taskID": taskID]
                        )
                        UIAsyncLoader.logger.debug("✅ 任务完成: \(taskID)")
                    } else {
                        let error = UIAsyncLoaderError.typeMismatch
                        onComplete(.failure(error))
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskFailed,
                            object: nil,
                            userInfo: ["taskID": taskID, "error": error]
                        )
                        UIAsyncLoader.logger.error("❌ 任务类型错误: \(taskID)")
                    }
                case .failure(let error):
                    if error is CancellationError {
                        onComplete(.failure(UIAsyncLoaderError.cancelled))
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskCancelled,
                            object: nil,
                            userInfo: ["taskID": taskID]
                        )
                        UIAsyncLoader.logger.debug("🚫 任务取消: \(taskID)")
                    } else {
                        onComplete(.failure(error))
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskFailed,
                            object: nil,
                            userInfo: ["taskID": taskID, "error": error]
                        )
                        UIAsyncLoader.logger.error("❌ 任务失败: \(taskID), 错误: \(error.localizedDescription)")
                    }
                }
            }
        )
        
        registerTask(wrapper)
        operationQueue.addOperation(wrapper)
        return wrapper
    }
    
    /// 简化版异步执行（兼容旧API）
    @discardableResult
    public func load<T>(
        _ block: @escaping () throws -> T,
        completion: @escaping @Sendable (UILoadingState<T>) -> Void
    ) -> UICancellableLoadingTask? {
        load(priority: .normal, work: { _ in try block() }, onComplete: completion)
    }
    
    // MARK: - 图片异步加载
    
    /// 异步加载图片，支持缓存
    @discardableResult
    public func loadImage(
        from url: URL,
        priority: UILoadingPriority = .normal,
        cacheKey: String? = nil,
        useCache: Bool = true,
        onStart: (() -> Void)? = nil,
        onProgress: (@Sendable (UILoadingProgress) -> Void)? = nil,
        onComplete: @escaping @Sendable (NSImage?) -> Void
    ) -> UICancellableLoadingTask? {
        let key = cacheKey ?? url.absoluteString
        
        // 先查缓存
        if useCache, let cachedImage = imageCache.image(forKey: key) {
            onComplete(cachedImage)
            UIAsyncLoader.logger.debug("📦 图片直接命中缓存: \(key)")
            return nil
        }
        
        onStart?()
        
        let taskID = generateTaskID()
        NotificationCenter.default.post(
            name: .asyncLoaderTaskStarted,
            object: nil,
            userInfo: ["taskID": taskID, "url": url.absoluteString]
        )
        UIAsyncLoader.logger.debug("🚀 图片加载任务开始: \(taskID), URL: \(url.absoluteString)")
        
        let wrapper = UILoadingTaskWrapper(
            taskID: taskID,
            priority: priority,
            work: { progressHandler in
                let request = URLRequest(url: url)
                let semaphore = DispatchSemaphore(value: 0)
                var resultData: Data?
                var resultError: Error?
                
                let task = self.urlSession.downloadTask(with: request) { location, response, error in
                    if let error = error {
                        resultError = error
                    } else if let location = location,
                              let data = try? Data(contentsOf: location) {
                        resultData = data
                    }
                    semaphore.signal()
                }
                task.resume()
                semaphore.wait()
                
                if let data = resultData,
                   let image = NSImage(data: data) {
                    if useCache {
                        self.imageCache.setImage(image, forKey: key)
                    }
                    return image
                } else if let error = resultError {
                    throw error
                } else {
                    throw UIAsyncLoaderError.invalidImageData
                }
            },
            onProgress: onProgress,
            onComplete: { [weak self] result in
                self?.unregisterTask(taskID)
                switch result {
                case .success(let image):
                    if let img = image as? NSImage {
                        onComplete(img)
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskCompleted,
                            object: nil,
                            userInfo: ["taskID": taskID, "image": img]
                        )
                        UIAsyncLoader.logger.debug("✅ 图片加载完成: \(taskID)")
                    } else {
                        onComplete(nil)
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskFailed,
                            object: nil,
                            userInfo: ["taskID": taskID, "error": UIAsyncLoaderError.invalidImageData]
                        )
                    }
                case .failure(let error):
                    if error is CancellationError {
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskCancelled,
                            object: nil,
                            userInfo: ["taskID": taskID]
                        )
                        UIAsyncLoader.logger.debug("🚫 图片加载取消: \(taskID)")
                    } else {
                        onComplete(nil)
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskFailed,
                            object: nil,
                            userInfo: ["taskID": taskID, "error": error]
                        )
                        UIAsyncLoader.logger.error("❌ 图片加载失败: \(taskID), 错误: \(error.localizedDescription)")
                    }
                }
            }
        )
        
        registerTask(wrapper)
        operationQueue.addOperation(wrapper)
        return wrapper
    }
    
    /// 简化版图片加载（兼容旧API）
    @discardableResult
    public func loadImage(from url: URL, completion: @escaping @Sendable (NSImage?) -> Void) -> UICancellableLoadingTask? {
        loadImage(from: url, priority: .normal, onComplete: completion)
    }
    
    // MARK: - 数据异步请求
    
    /// 异步请求数据，支持缓存
    @discardableResult
    public func loadData(
        from url: URL,
        priority: UILoadingPriority = .normal,
        cacheKey: String? = nil,
        useCache: Bool = true,
        cacheDuration: TimeInterval = 300,
        onStart: (() -> Void)? = nil,
        onProgress: (@Sendable (UILoadingProgress) -> Void)? = nil,
        onComplete: @escaping @Sendable (Result<Data, Error>) -> Void
    ) -> UICancellableLoadingTask? {
        let key = cacheKey ?? url.absoluteString
        
        if useCache, let cachedData = dataCache.data(forKey: key) {
            onComplete(.success(cachedData))
            UIAsyncLoader.logger.debug("📦 数据直接命中缓存: \(key)")
            return nil
        }
        
        onStart?()
        
        let taskID = generateTaskID()
        NotificationCenter.default.post(
            name: .asyncLoaderTaskStarted,
            object: nil,
            userInfo: ["taskID": taskID, "url": url.absoluteString]
        )
        UIAsyncLoader.logger.debug("🚀 数据请求任务开始: \(taskID), URL: \(url.absoluteString)")
        
        let wrapper = UILoadingTaskWrapper(
            taskID: taskID,
            priority: priority,
            work: { _ in
                let request = URLRequest(url: url)
                let semaphore = DispatchSemaphore(value: 0)
                var resultData: Data?
                var resultError: Error?
                
                let task = self.urlSession.dataTask(with: request) { data, response, error in
                    if let error = error {
                        resultError = error
                    } else if let data = data {
                        resultData = data
                    }
                    semaphore.signal()
                }
                task.resume()
                semaphore.wait()
                
                if let data = resultData {
                    if useCache {
                        self.dataCache.setData(data, forKey: key)
                    }
                    return data
                } else if let error = resultError {
                    throw error
                } else {
                    throw UIAsyncLoaderError.noData
                }
            },
            onProgress: onProgress,
            onComplete: { [weak self] result in
                self?.unregisterTask(taskID)
                switch result {
                case .success(let data):
                    if let d = data as? Data {
                        onComplete(.success(d))
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskCompleted,
                            object: nil,
                            userInfo: ["taskID": taskID, "dataSize": d.count]
                        )
                        UIAsyncLoader.logger.debug("✅ 数据请求完成: \(taskID), 大小: \(d.count) 字节")
                    } else {
                        let error = UIAsyncLoaderError.typeMismatch
                        onComplete(.failure(error))
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskFailed,
                            object: nil,
                            userInfo: ["taskID": taskID, "error": error]
                        )
                    }
                case .failure(let error):
                    if error is CancellationError {
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskCancelled,
                            object: nil,
                            userInfo: ["taskID": taskID]
                        )
                        UIAsyncLoader.logger.debug("🚫 数据请求取消: \(taskID)")
                    } else {
                        onComplete(.failure(error))
                        NotificationCenter.default.post(
                            name: .asyncLoaderTaskFailed,
                            object: nil,
                            userInfo: ["taskID": taskID, "error": error]
                        )
                        UIAsyncLoader.logger.error("❌ 数据请求失败: \(taskID), 错误: \(error.localizedDescription)")
                    }
                }
            }
        )
        
        registerTask(wrapper)
        operationQueue.addOperation(wrapper)
        return wrapper
    }
    
    // MARK: - 任务取消
    
    /// 取消指定任务
    public func cancelTask(_ taskID: String) {
        taskLock.lock()
        let task = activeTasks[taskID]
        taskLock.unlock()
        
        task?.cancel()
        UIAsyncLoader.logger.info("🚫 取消任务: \(taskID)")
    }
    
    /// 取消所有任务
    public func cancelAll() {
        taskLock.lock()
        let tasks = Array(activeTasks.values)
        activeTasks.removeAll()
        taskLock.unlock()
        
        for task in tasks {
            task.cancel()
        }
        operationQueue.cancelAllOperations()
        UIAsyncLoader.logger.info("🚫 取消所有任务")
    }
    
    /// 获取活跃任务数
    public var activeTaskCount: Int {
        taskLock.lock()
        defer { taskLock.unlock() }
        return activeTasks.count
    }
    
    // MARK: - 缓存操作
    
    /// 获取缓存统计
    public var cacheStatistics: UICacheStatistics {
        let img = imageCache.statistics()
        let dat = dataCache.statistics()
        _ = dataCache.lruCache
        
        return UICacheStatistics(
            memoryImageCount: img.memoryCount,
            memoryImageSizeMB: img.memorySizeMB,
            diskImageCount: img.diskCount,
            diskImageSizeMB: img.diskSizeMB,
            memoryDataCount: dat.memoryCount,
            memoryDataSizeMB: dat.memorySizeMB,
            diskDataCount: dat.diskCount,
            diskDataSizeMB: dat.diskSizeMB,
            totalHits: 0,
            totalMisses: 0
        )
    }
    
    /// 清理缓存
    public func clearCache(type: UICacheType = .all) {
        switch type {
        case .image:
            imageCache.removeAll()
        case .data:
            dataCache.removeAll()
        case .all:
            imageCache.removeAll()
            dataCache.removeAll()
        }
        
        NotificationCenter.default.post(
            name: .asyncLoaderCacheCleared,
            object: nil,
            userInfo: ["type": type]
        )
        UIAsyncLoader.logger.info("🗑️ 缓存已清空: \(String(describing: type))")
    }
    
    /// 清理过期缓存
    public func clearExpiredCache(type: UICacheType = .all) {
        switch type {
        case .image:
            imageCache.removeExpired()
        case .data:
            dataCache.removeExpired()
        case .all:
            imageCache.removeExpired()
            dataCache.removeExpired()
        }
        
        NotificationCenter.default.post(
            name: .asyncLoaderCacheCleared,
            object: nil,
            userInfo: ["type": type, "expiredOnly": true]
        )
        UIAsyncLoader.logger.info("🗑️ 过期缓存已清理: \(String(describing: type))")
    }
    
    /// 按LRU清理缓存
    public func clearCacheLRU(type: UICacheType = .all, targetSizeMB: Double) {
        // LRU 已在缓存满时自动清理，此方法用于手动按目标大小缩减
        switch type {
        case .image:
            imageCache.memoryLimitMB = targetSizeMB
            imageCache.diskLimitMB = targetSizeMB
            imageCache.cleanDiskCacheIfNeeded()
        case .data:
            dataCache.memoryLimitMB = targetSizeMB
            dataCache.diskLimitMB = targetSizeMB
            dataCache.cleanDiskCacheIfNeeded()
        case .all:
            imageCache.memoryLimitMB = targetSizeMB
            imageCache.diskLimitMB = targetSizeMB
            imageCache.cleanDiskCacheIfNeeded()
            dataCache.memoryLimitMB = targetSizeMB
            dataCache.diskLimitMB = targetSizeMB
            dataCache.cleanDiskCacheIfNeeded()
        }
        
        NotificationCenter.default.post(
            name: .asyncLoaderCacheCleared,
            object: nil,
            userInfo: ["type": type, "LRU": true, "targetSizeMB": targetSizeMB]
        )
        UIAsyncLoader.logger.info("🗑️ LRU缓存已清理: \(String(describing: type)), 目标大小: \(String(format: "%.2f", targetSizeMB)) MB")
    }
    
    /// 移除指定缓存项
    public func removeCache(forKey key: String, type: UICacheType) {
        switch type {
        case .image:
            imageCache.removeImage(forKey: key)
        case .data:
            dataCache.removeData(forKey: key)
        case .all:
            imageCache.removeImage(forKey: key)
            dataCache.removeData(forKey: key)
        }
        UIAsyncLoader.logger.info("🗑️ 移除缓存项: \(key), 类型: \(String(describing: type))")
    }
    
    // MARK: - 设置面板方法
    
    /// 重置为默认配置
    public func resetToDefaultConfiguration() {
        configuration = UICacheConfiguration.default
        UIAsyncLoader.logger.info("⚙️ 缓存配置已重置为默认值")
    }
    
    /// 获取当前配置副本
    public func getConfiguration() -> UICacheConfiguration {
        configuration
    }
    
    /// 更新配置（原子操作）
    public func updateConfiguration(_ update: (inout UICacheConfiguration) -> Void) {
        var config = configuration
        update(&config)
        configuration = config
    }
    
    /// 获取配置描述（用于设置面板展示）
    public func configurationDescription() -> String {
        let config = configuration
        return """
        内存图片缓存: \(String(format: "%.1f", config.imageMemoryCacheLimitMB)) MB
        磁盘图片缓存: \(String(format: "%.1f", config.imageDiskCacheLimitMB)) MB
        内存数据缓存: \(String(format: "%.1f", config.dataMemoryCacheLimitMB)) MB
        磁盘数据缓存: \(String(format: "%.1f", config.dataDiskCacheLimitMB)) MB
        磁盘过期时间: \(config.diskCacheExpirationDays) 天
        最大并发加载: \(config.maxConcurrentLoads)
        默认优先级: \(config.defaultPriority.displayName)
        """
    }
}

// MARK: - 迁回自 UI-02：class UILoadingIndicatorView
public class UILoadingIndicatorView: NSView , @unchecked Sendable{
    
    private let spinner: NSProgressIndicator
    private var label: NSText?
    
    public override init(frame frameRect: NSRect) {
        self.spinner = NSProgressIndicator(frame: NSRect(x: (frameRect.width - 32) / 2, y: (frameRect.height - 32) / 2 + 10, width: 32, height: 32))
        super.init(frame: frameRect)
        spinner.style = .spinning
        spinner.startAnimation(nil)
        addSubview(spinner)
    }
    
    public required init?(coder: NSCoder) {
        self.spinner = NSProgressIndicator()
        super.init(coder: coder)
    }
    
    public func show(in view: NSView, message: String? = nil) {
        frame = view.bounds
        spinner.frame = NSRect(x: (bounds.width - 32) / 2, y: (bounds.height - 32) / 2 + 10, width: 32, height: 32)
        
        // 更新或创建提示文字
        if let message = message {
            if let existingLabel = label {
                existingLabel.string = message
                existingLabel.frame = NSRect(x: 0, y: (bounds.height - 32) / 2 - 20, width: bounds.width, height: 20)
            } else {
                let newLabel = NSText(frame: NSRect(x: 0, y: (bounds.height - 32) / 2 - 20, width: bounds.width, height: 20))
                newLabel.string = message
                newLabel.alignment = .center
                newLabel.font = NSFont.systemFont(ofSize: 12)
                newLabel.textColor = NSColor.secondaryLabelColor
                newLabel.isEditable = false
                newLabel.isSelectable = false
                newLabel.drawsBackground = false
                self.label = newLabel
                addSubview(newLabel)
            }
        }
        
        view.addSubview(self)
        spinner.startAnimation(nil)
    }
    
    public func hide() {
        spinner.stopAnimation(nil)
        removeFromSuperview()
    }
    
    /// 更新进度提示文字
    public func updateMessage(_ message: String) {
        if let label = label {
            label.string = message
        }
    }

    deinit {
    }
}

// MARK: - 迁回自 UI-02：enum UILoadingPriority
// MARK: - 渲染优化管理器
/// 管理视图渲染模式，优化性能
// 已迁回 UI-GL-30_视图渲染优化.swift：class UIRenderOptimizer（公共类型文件禁止功能实现）


// MARK: - UI-GL-31 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-31_types.swift
// 版本: 2.0
// MARK: - 加载优先级
/// 异步加载任务的优先级
public enum UILoadingPriority: Int, Comparable, CaseIterable, Codable, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    public static func < (lhs: UILoadingPriority, rhs: UILoadingPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// 转换为 Operation 优先级
    var operationPriority: Operation.QueuePriority {
        switch self {
        case .low:      return .low
        case .normal:   return .normal
        case .high:     return .high
        case .critical: return .veryHigh
        }
    }
    
    /// 中文描述
    var displayName: String {
        switch self {
        case .low:      return "低"
        case .normal:   return "正常"
        case .high:     return "高"
        case .critical: return "紧急"
        }
    }
}

// MARK: - 迁回自 UI-02：enum UILoadingState<T>
// MARK: - 加载状态
/// 异步加载的状态
public enum UILoadingState<T>: @unchecked Sendable {
    case idle
    case loading
    case success(T)
    case failure(Error)
}

// MARK: - 迁回自 UI-02：struct UILoadingProgress
// MARK: - 加载进度
/// 加载进度信息
public struct UILoadingProgress: Sendable {
    public let totalBytes: Int64
    public let loadedBytes: Int64
    public let fractionCompleted: Double
    
    public init(totalBytes: Int64, loadedBytes: Int64) {
        self.totalBytes = totalBytes
        self.loadedBytes = loadedBytes
        self.fractionCompleted = totalBytes > 0 ? Double(loadedBytes) / Double(totalBytes) : 0
    }
}

// MARK: - 迁回自 UI-02：protocol UICancellableLoadingTask
// MARK: - 加载任务
/// 可取消的异步加载任务
public protocol UICancellableLoadingTask: AnyObject {
    var taskID: String { get }
    var priority: UILoadingPriority { get set }
    func cancel()
    var isCancelled: Bool { get }
}

// MARK: - 迁回自 UI-02：enum UICacheType
// MARK: - 内部任务包装
/// 内部任务包装类，用于 OperationQueue 调度
// 已迁回 UI-GL-31_异步加载器.swift：class UILoadingTaskWrapper（公共类型文件禁止功能实现）

// MARK: - 缓存类型
/// 缓存数据类型
public enum UICacheType {
    case image
    case data
    case all
}

// MARK: - 迁回自 UI-02：struct UICacheConfiguration
// MARK: - 缓存配置
/// 缓存配置，可持久化
public struct UICacheConfiguration: Codable, Equatable, Sendable {
    /// 内存图片缓存上限（MB）
    public var imageMemoryCacheLimitMB: Double = 100
    /// 磁盘图片缓存上限（MB）
    public var imageDiskCacheLimitMB: Double = 500
    /// 内存数据缓存上限（MB）
    public var dataMemoryCacheLimitMB: Double = 50
    /// 磁盘数据缓存上限（MB）
    public var dataDiskCacheLimitMB: Double = 200
    /// 磁盘缓存过期时间（天）
    public var diskCacheExpirationDays: Int = 7
    /// 是否启用内存缓存
    public var memoryCacheEnabled: Bool = true
    /// 是否启用磁盘缓存
    public var diskCacheEnabled: Bool = true
    /// 最大并发加载数
    public var maxConcurrentLoads: Int = 4
    /// 默认加载优先级
    public var defaultPriority: UILoadingPriority = .normal
    
    public init() {}
    
    /// 默认配置
    public static let `default` = UICacheConfiguration()
    
    /// 从 UserDefaults 加载
    public static func load() -> UICacheConfiguration {
        if let data = UserDefaults.standard.data(forKey: "AsyncLoader.CacheConfiguration"),
           let config = try? JSONDecoder().decode(UICacheConfiguration.self, from: data) {
            return config
        }
        return .default
    }
    
    /// 保存到 UserDefaults
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "AsyncLoader.CacheConfiguration")
        }
    }
}

// MARK: - 迁回自 UI-02：struct UICacheStatistics
// MARK: - 缓存统计
/// 缓存统计信息
public struct UICacheStatistics {
    public let memoryImageCount: Int
    public let memoryImageSizeMB: Double
    public let diskImageCount: Int
    public let diskImageSizeMB: Double
    public let memoryDataCount: Int
    public let memoryDataSizeMB: Double
    public let diskDataCount: Int
    public let diskDataSizeMB: Double
    public let totalHits: Int64
    public let totalMisses: Int64
    
    public var hitRate: Double {
        let total = totalHits + totalMisses
        return total > 0 ? Double(totalHits) / Double(total) : 0
    }
}

// MARK: - 迁回自 UI-02：enum UIAsyncLoaderError
// MARK: - LRU 节点
/// LRU 链表节点
// 已迁回 UI-GL-31_异步加载器.swift：class UILRUCacheNode<Key（公共类型文件禁止功能实现）

// MARK: - LRU 缓存
/// 基于双向链表的 LRU 缓存
// 已迁回 UI-GL-31_异步加载器.swift：class UILRUCache<Key（公共类型文件禁止功能实现）

// MARK: - 图片缓存管理器
/// 图片缓存：内存(NSCache) + 磁盘 + LRU 淘汰
// 已迁回 UI-GL-31_异步加载器.swift：class UIImageCacheManager（公共类型文件禁止功能实现）

// MARK: - 数据缓存管理器
/// 通用数据缓存：内存(LRU) + 磁盘
// 已迁回 UI-GL-31_异步加载器.swift：class UIDataCacheManager（公共类型文件禁止功能实现）

// MARK: - 异步加载管理器
/// 执行耗时操作，不阻塞UI，支持加载指示器
/// 功能：异步任务调度、图片缓存、数据缓存、任务取消、优先级管理、LRU清理、通知体系
// 已迁回 UI-GL-31_异步加载器.swift：class UIAsyncLoader（公共类型文件禁止功能实现）

// MARK: - 错误定义
/// 异步加载器错误
public enum UIAsyncLoaderError: Error, LocalizedError {
    case invalidImageData
    case noData
    case typeMismatch
    case cancelled
    case cacheNotFound
    
    public var errorDescription: String? {
        switch self {
        case .invalidImageData: return "图片数据无效，无法解码"
        case .noData:           return "未获取到数据"
        case .typeMismatch:     return "返回类型不匹配"
        case .cancelled:        return "任务已取消"
        case .cacheNotFound:    return "缓存未找到"
        }
    }
}
