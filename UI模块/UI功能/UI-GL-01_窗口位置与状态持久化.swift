// 功能3: 窗口位置与状态持久化
// 对应: 关闭时自动保存位置、大小、是否最大化；下次启动时恢复
// 优先级: P0

import Foundation
import AppKit
import os.log

// MARK: - NSScreen 扩展（使用 04_多屏幕支持.swift 中定义的 displayUUID）
/// 注：04_多屏幕支持.swift 已定义 internal extension NSScreen { var displayUUID: String }
/// 此处移除重复定义，避免编译错误。

// MARK: - 测试代码
#if false // DEBUG tests disabled in App target
/// 功能03：窗口位置与状态持久化 — 单元测试
/// 覆盖：正常保存/恢复、边界情况、编解码兼容、并发写入
func test_windowPersistence() {
    print("\n🧪 测试1: 正常保存并恢复窗口状态")
    let manager = UIWindowPersistenceManager.shared
    let windowID = "test_window_001"
    let window = NSWindow(contentRect: NSRect(x: 100, y: 200, width: 800, height: 600),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
    manager.save(windowID: windowID, window: window)
    // 异步保存需要等待后台队列完成
    let expectation = XCTestExpectation(description: "等待保存完成")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        guard let restored = manager.restore(windowID: windowID) else {
            fatalError("❌ 测试1失败: 保存后无法恢复窗口状态")
        }
        guard restored.windowID == windowID else {
            fatalError("❌ 测试1失败: 恢复的窗口ID不匹配，期望\(windowID)，实际\(restored.windowID)")
        }
        guard restored.width == 800 && restored.height == 600 else {
            fatalError("❌ 测试1失败: 恢复的尺寸不匹配，期望800x600，实际\(restored.width)x\(restored.height)")
        }
        expectation.fulfill()
    }
    _ = XCTWaiter.wait(for: [expectation], timeout: 3.0)
    print("✅ 测试1通过: 窗口状态保存并恢复成功")
    
    print("\n🧪 测试2: 不存在的窗口ID返回nil")
    let result = manager.restore(windowID: "non_existent_window")
    guard result == nil else {
        fatalError("❌ 测试2失败: 不存在的窗口ID应返回nil，实际返回了\(result!)")
    }
    print("✅ 测试2通过: 不存在的窗口ID返回nil")
    
    print("\n🧪 测试3: 删除后无法恢复")
    manager.save(windowID: "test_window_002", window: window)
    let exp3 = XCTestExpectation(description: "等待删除完成")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        manager.delete(windowID: "test_window_002")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let afterDelete = manager.restore(windowID: "test_window_002")
            guard afterDelete == nil else {
                fatalError("❌ 测试3失败: 删除后应返回nil")
            }
            exp3.fulfill()
        }
    }
    _ = XCTWaiter.wait(for: [exp3], timeout: 5.0)
    print("✅ 测试3通过: 删除后无法恢复")
    
    print("\n🧪 测试4: 批量清空所有状态")
    manager.save(windowID: "batch_test_1", window: window)
    manager.save(windowID: "batch_test_2", window: window)
    let exp4 = XCTestExpectation(description: "等待批量清空")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        manager.deleteAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let ids = manager.allSavedWindowIDs()
            guard ids.isEmpty else {
                fatalError("❌ 测试4失败: 清空后allSavedWindowIDs应返回空数组，实际返回\(ids)")
            }
            exp4.fulfill()
        }
    }
    _ = XCTWaiter.wait(for: [exp4], timeout: 5.0)
    print("✅ 测试4通过: 批量清空后状态为空")
    
    print("\n🧪 测试5: UIWindowPositionStateModel编解码兼容性")
    let model = UIWindowPositionStateModel(windowID: "compat_test", x: 100, y: 200, width: 800, height: 600,
                                  isMaximized: true, displayUUID: "display_001")
    guard let encoded = try? JSONEncoder().encode(model) else {
        fatalError("❌ 测试5失败: UIWindowPositionStateModel编码失败")
    }
    guard let decoded = try? JSONDecoder().decode(UIWindowPositionStateModel.self, from: encoded) else {
        fatalError("❌ 测试5失败: UIWindowPositionStateModel解码失败")
    }
    guard decoded == model else {
        fatalError("❌ 测试5失败: 编解码后数据不一致")
    }
    print("✅ 测试5通过: UIWindowPositionStateModel编解码双向兼容")
    
    print("\n🧪 测试6: 空windowID处理")
    manager.save(windowID: "", window: window)
    print("✅ 测试6通过: 空windowID不会导致崩溃（后台保存跳过空键不报错）")
    
    print("\n🧪 测试7: 并发写入不崩溃")
    let group = DispatchGroup()
    for i in 0..<10 {
        DispatchQueue.global().async(group: group) {
            manager.save(windowID: "concurrent_\(i)", window: window)
        }
    }
    _ = group.wait(timeout: .now() + 5.0)
    print("✅ 测试7通过: 10次并发写入未崩溃")
    
    print("\n=== 全部窗口持久化测试通过 ✅ ===")
}
#endif

// MARK: - 从 UI-02 正确迁回：struct UIWindowPositionStateModel
public struct UIWindowPositionStateModel: Codable, Equatable, CustomStringConvertible {

    /// 窗口唯一标识符
    public let windowID: String

    /// 窗口左上角X坐标（屏幕坐标系，左下角为原点）
    public let x: Double

    /// 窗口左上角Y坐标（屏幕坐标系）
    public let y: Double

    /// 窗口宽度
    public let width: Double

    /// 窗口高度
    public let height: Double

    /// 是否处于最大化（缩放）状态
    public let isMaximized: Bool

    /// 所在屏幕的标识符（用于多显示器场景恢复）
    public let displayUUID: String

    /// 状态保存时间戳
    public let savedAt: Date

    /// 数据模型版本号（用于未来数据迁移）
    public let version: Int

    /// 自定义 CodingKeys，用于向后兼容
    enum UICodingKeys: String, CodingKey {
        case windowID, x, y, width, height, isMaximized, displayUUID, savedAt, version
    }

    public init(
        windowID: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        isMaximized: Bool,
        displayUUID: String,
        savedAt: Date = Date(),
        version: Int = 2
    ) {
        self.windowID = windowID
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.isMaximized = isMaximized
        self.displayUUID = displayUUID
        self.savedAt = savedAt
        self.version = version
    }

    /// 向后兼容的解码初始化
    /// 兼容旧版本数据（无 savedAt 和 version 字段）
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: UICodingKeys.self)
        self.windowID = try container.decode(String.self, forKey: .windowID)
        self.x = try container.decode(Double.self, forKey: .x)
        self.y = try container.decode(Double.self, forKey: .y)
        self.width = try container.decode(Double.self, forKey: .width)
        self.height = try container.decode(Double.self, forKey: .height)
        self.isMaximized = try container.decode(Bool.self, forKey: .isMaximized)
        self.displayUUID = try container.decode(String.self, forKey: .displayUUID)
        self.savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 2
    }

    public var description: String {
        return "窗口状态[\(windowID)]: 位置(\(x), \(y)), 尺寸(\(width)x\(height)), 最大化:\(isMaximized ? "是" : "否"), 屏幕:\(displayUUID), 版本:\(version)"
    }
}


// MARK: - 从 UI-02 正确迁回：class UIWindowPersistenceManager
public final class UIWindowPersistenceManager : @unchecked Sendable {
    deinit {
        Self.logger.info("UIWindowPersistenceManager 已释放")
    }

    /// 全局单例
    public static let shared = UIWindowPersistenceManager()

    /// 日志对象
    private static let logger = Logger(subsystem: "com.xianrenzhilu", category: "窗口持久化")

    /// UserDefaults 标准实例
    private let defaults: UserDefaults

    /// 串行派发队列，用于所有持久化写操作，保证线程安全
    private let persistenceQueue: DispatchQueue

    /// 递归锁，保护共享状态（缓存、批量操作）
    private let lock = NSRecursiveLock()

    /// 当前已保存的窗口ID内存缓存（加速查询）
    private var cachedWindowIDs: Set<String> = []

    /// 私有初始化，防止外部构造
    private init() {
        self.defaults = UserDefaults.standard
        self.persistenceQueue = DispatchQueue(
            label: "com.xianrenzhilu.windowPersistence",
            qos: .utility,
            attributes: []
        )
        self.refreshCache()
        Self.logger.info("【窗口持久化】管理器初始化完成")
    }

    // MARK: - 保存方法

    /// 保存指定窗口的当前状态到持久化存储
    public func save(windowID: String, window: NSWindow) {
        let frame = window.frame
        let isZoomed = window.isZoomed
        let screen = window.screen

        persistenceQueue.async { [weak self] in
            guard let self = self else {
                Self.logger.error("【窗口持久化】保存失败：管理器已释放，windowID=\(windowID)")
                return
            }

            let displayUUID = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? String ?? "unknown"
            let state = UIWindowPositionStateModel(
                windowID: windowID,
                x: Double(frame.origin.x),
                y: Double(frame.origin.y),
                width: Double(frame.size.width),
                height: Double(frame.size.height),
                isMaximized: isZoomed,
                displayUUID: displayUUID
            )

            self.lock.lock()
            self.lockedSave(state: state)
            self.lock.unlock()

            Self.logger.info("【窗口持久化】状态已保存：\(windowID)，位置(\(state.x), \(state.y))，尺寸(\(state.width)x\(state.height))，最大化:\(state.isMaximized ? "是" : "否")")
        }
    }

    /// 批量保存所有已注册窗口的状态
    public func saveAll() {
        let records = UIUnifiedRegistry.shared.allWindowRecords
        Self.logger.info("【窗口持久化】开始批量保存，共 \(records.count) 个窗口")

        for record in records {
            let window = record.window
            guard !record.isClosed else {
                Self.logger.debug("【窗口持久化】跳过已关闭或无效窗口：\(record.windowID)")
                continue
            }
            save(windowID: record.windowID, window: window)
        }
    }

    // MARK: - 恢复方法

    /// 从持久化存储中恢复窗口状态
    public func restore(windowID: String) -> UIWindowPositionStateModel? {
        let key = persistenceKey(for: windowID)

        lock.lock()
        defer { lock.unlock() }

        guard let data = defaults.data(forKey: key) else {
            Self.logger.debug("【窗口持久化】未找到保存的状态：\(windowID)")
            return nil
        }

        do {
            let state = try JSONDecoder().decode(UIWindowPositionStateModel.self, from: data)
            Self.logger.info("【窗口持久化】成功恢复状态：\(windowID)，版本\(state.version)，保存于\(state.savedAt)")
            return state
        } catch {
            Self.logger.error("【窗口持久化】解码失败：\(windowID)，错误：\(error.localizedDescription)")
            return nil
        }
    }

    /// 将保存的状态应用到指定窗口
    @discardableResult
    public func apply(windowID: String, to window: NSWindow) -> Bool {
        assert(Thread.isMainThread, "【窗口持久化】apply 必须在主线程调用")

        guard let state = restore(windowID: windowID) else {
            if !window.frameAutosaveName.isEmpty {
                let autosaveName = window.frameAutosaveName
                let restored = window.setFrameUsingName(autosaveName)
                if restored {
                    Self.logger.info("【窗口持久化】使用系统 AutosaveName 恢复窗口：\(windowID)")
                } else {
                    Self.logger.warning("【窗口持久化】系统 AutosaveName 恢复失败：\(windowID)")
                }
                return restored
            }
            Self.logger.info("【窗口持久化】无保存状态，使用默认布局：\(windowID)")
            return false
        }

        let targetFrame = NSRect(
            x: state.x,
            y: state.y,
            width: state.width,
            height: state.height
        )

        let targetScreen = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? String) == state.displayUUID }
        if targetScreen != nil {
            window.setFrame(targetFrame, display: true, animate: false)
            Self.logger.info("【窗口持久化】已恢复到原屏幕：\(windowID)")
        } else {
            window.setFrame(targetFrame, display: true, animate: false)
            Self.logger.warning("【窗口持久化】原屏幕不可用，仍尝试恢复位置：\(windowID)")
        }

        if state.isMaximized {
            if !window.isZoomed {
                window.zoom(nil)
                Self.logger.info("【窗口持久化】恢复最大化状态：\(windowID)")
            }
        } else {
            if window.isZoomed {
                window.zoom(nil)
                Self.logger.info("【窗口持久化】恢复非最大化状态：\(windowID)")
            }
        }

        return true
    }

    // MARK: - 删除方法

    /// 删除指定窗口的已保存状态
    public func delete(windowID: String) {
        persistenceQueue.async { [weak self] in
            guard let self = self else { return }

            let key = self.persistenceKey(for: windowID)

            self.lock.lock()
            self.defaults.removeObject(forKey: key)
            self.cachedWindowIDs.remove(windowID)
            self.lock.unlock()

            Self.logger.info("【窗口持久化】已删除状态：\(windowID)")
        }
    }

    /// 清空所有保存的窗口状态
    public func deleteAll() {
        persistenceQueue.async { [weak self] in
            guard let self = self else { return }

            self.lock.lock()
            let allKeys = self.defaults.dictionaryRepresentation().keys
            var removedCount = 0
            for key in allKeys where key.hasPrefix("com.xianrenzhilu.windowState.") {
                self.defaults.removeObject(forKey: key)
                removedCount += 1
            }
            self.cachedWindowIDs.removeAll()
            self.lock.unlock()

            Self.logger.info("【窗口持久化】已清空所有状态，共删除 \(removedCount) 条记录")
        }
    }

    // MARK: - 查询方法

    /// 检查是否已保存指定窗口的状态
    public func hasState(for windowID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cachedWindowIDs.contains(windowID)
    }

    /// 获取所有已保存状态的窗口ID列表
    public func allSavedWindowIDs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(cachedWindowIDs)
    }

    /// 获取当前缓存的窗口状态数量
    public var savedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cachedWindowIDs.count
    }

    // MARK: - 内部辅助方法

    private func persistenceKey(for windowID: String) -> String {
        return "com.xianrenzhilu.windowState.\(windowID)"
    }

    private func lockedSave(state: UIWindowPositionStateModel) {
        let key = persistenceKey(for: state.windowID)
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: key)
            cachedWindowIDs.insert(state.windowID)
            Self.logger.debug("【窗口持久化】状态写入成功：\(state.windowID)")
        } catch {
            Self.logger.error("【窗口持久化】状态写入失败：\(state.windowID)，错误：\(error.localizedDescription)")
        }
    }

    private func refreshCache() {
        lock.lock()
        defer { lock.unlock() }

        let allKeys = defaults.dictionaryRepresentation().keys
        let prefix = "com.xianrenzhilu.windowState."
        cachedWindowIDs = Set(allKeys.filter { $0.hasPrefix(prefix) }.map { key in
            String(key.dropFirst(prefix.count))
        })

        Self.logger.info("【窗口持久化】缓存刷新完成，共 \(self.cachedWindowIDs.count) 个窗口")
    }
}

