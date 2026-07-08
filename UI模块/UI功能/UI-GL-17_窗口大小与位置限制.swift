// 功能13B: 窗口大小与位置限制
// 对应: 最小/最大窗口尺寸限制、比例锁定、位置限制,防止窗口越界或过小/过大
// 优先级: P2

import Foundation
import AppKit
import os.log

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能13B：窗口大小与位置限制 — 单元测试
/// 覆盖：配置模型、Codable编解码、限制拦截逻辑
func test_windowSizeRestriction() {
    print("\n🧪 测试1: 默认配置")
    let config = UIWindowSizeRestrictionConfig()
    guard config.minSize == nil && config.maxSize == nil else {
        fatalError("❌ 测试1失败: 默认配置不应有min/max限制")
    }
    guard config.positionRestrictionEnabled else {
        fatalError("❌ 测试1失败: 默认应启用位置限制")
    }
    print("✅ 测试1通过: 默认配置正确")
    
    print("\n🧪 测试2: none空配置")
    let none = UIWindowSizeRestrictionConfig.none
    guard none.description == "无限制" else {
        fatalError("❌ 测试2失败: none.description应为'无限制'")
    }
    guard !none.positionRestrictionEnabled else {
        fatalError("❌ 测试2失败: none.positionRestrictionEnabled应为false")
    }
    print("✅ 测试2通过: none空配置正确")
    
    print("\n🧪 测试3: 自定义配置")
    let custom = UIWindowSizeRestrictionConfig(
        minSize: NSSize(width: 400, height: 300),
        maxSize: NSSize(width: 1920, height: 1080),
        aspectRatio: 16.0/9.0,
        positionRestrictionEnabled: true
    )
    guard let min = custom.minSize, min.width == 400, min.height == 300 else {
        fatalError("❌ 测试3失败: minSize不匹配")
    }
    guard let max = custom.maxSize, max.width == 1920, max.height == 1080 else {
        fatalError("❌ 测试3失败: maxSize不匹配")
    }
    guard let ratio = custom.aspectRatio, abs(ratio - 16.0/9.0) < 0.01 else {
        fatalError("❌ 测试3失败: aspectRatio不匹配")
    }
    print("✅ 测试3通过: 自定义配置正确")
    
    print("\n🧪 测试4: Codable编解码")
    guard let data = try? JSONEncoder().encode(custom) else {
        fatalError("❌ 测试4失败: 编码失败")
    }
    guard let decoded = try? JSONDecoder().decode(UIWindowSizeRestrictionConfig.self, from: data) else {
        fatalError("❌ 测试4失败: 解码失败")
    }
    guard decoded == custom else {
        fatalError("❌ 测试4失败: 编解码后数据不一致")
    }
    print("✅ 测试4通过: Codable编解码双向正确")
    
    print("\n🧪 测试5: 配置描述文字")
    let desc = custom.description
    guard desc.contains("最小") && desc.contains("最大") && desc.contains("宽高比") else {
        fatalError("❌ 测试5失败: description缺少关键信息")
    }
    print("✅ 测试5通过: 配置描述文字完整")
    
    print("\n🧪 测试6: NSSize使用Codable")
    let configWithSize = UIWindowSizeRestrictionConfig(minSize: NSSize(width: 800, height: 600))
    guard let data2 = try? JSONEncoder().encode(configWithSize) else {
        fatalError("❌ 测试6失败: 含NSSize的编码失败")
    }
    guard let decoded2 = try? JSONDecoder().decode(UIWindowSizeRestrictionConfig.self, from: data2) else {
        fatalError("❌ 测试6失败: 含NSSize的解码失败")
    }
    guard let min2 = decoded2.minSize, abs(min2.width - 800) < 1, abs(min2.height - 600) < 1 else {
        fatalError("❌ 测试6失败: NSSize编解码后数据不一致")
    }
    print("✅ 测试6通过: NSSize编解码正确")
    
    print("\n🧪 测试7: 拦截逻辑-最小尺寸限制")
    let manager = UIWindowSizeRestrictionManager.shared
    // 创建一个临时窗口用于测试拦截
    let testWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: true)
    testWindow.identifier = NSUserInterfaceItemIdentifier("test_resize_001")
    
    manager.setMinSize(NSSize(width: 500, height: 400), for: "test_resize_001")
    let result = manager.interceptWindowWillResize(testWindow, to: NSSize(width: 100, height: 100), windowID: "test_resize_001")
    guard result.width >= 500 && result.height >= 400 else {
        fatalError("❌ 测试7失败: 拦截后尺寸应≥最小尺寸,实际\(result.width)x\(result.height)")
    }
    print("✅ 测试7通过: 最小尺寸限制有效")
    
    print("\n🧪 测试8: 无配置时返回原尺寸")
    let noLimit = manager.interceptWindowWillResize(testWindow, to: NSSize(width: 200, height: 150), windowID: "no_config_window")
    guard abs(noLimit.width - 200) < 1, abs(noLimit.height - 150) < 1 else {
        fatalError("❌ 测试8失败: 无配置时应返回原尺寸")
    }
    print("✅ 测试8通过: 无配置时返回原尺寸")
    
    print("\n=== 全部窗口大小限制测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWindowSizeRestrictionDelegate
public final class UIWindowSizeRestrictionDelegate: NSObject, NSWindowDelegate , @unchecked Sendable{

    /// 弱引用回管理器,用于查询当前窗口的限制配置
    weak var manager: UIWindowSizeRestrictionManager?

    /// 关联的窗口标识符
    var windowID: String?

    /// 窗口即将改变大小时的拦截
    /// - Parameters:
    ///   - sender: 触发 resize 的窗口
    ///   - frameSize: 用户请求的新尺寸
    /// - Returns: 经限制处理后的最终尺寸
    public func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard let manager = manager, let windowID = windowID else {
            return frameSize
        }
        return manager.interceptWindowWillResize(sender, to: frameSize, windowID: windowID)
    }

    /// 窗口移动完成后的回调,执行位置限制校正
    public func windowDidMove(_ notification: Notification) {
        guard let manager = manager, let windowID = windowID,
              let window = notification.object as? NSWindow else {
            return
        }
        manager.clampWindowPosition(window, windowID: windowID)
    }

    /// 窗口缩放完成后的回调,执行位置限制校正
    public func windowDidEndLiveResize(_ notification: Notification) {
        guard let manager = manager, let windowID = windowID,
              let window = notification.object as? NSWindow else {
            return
        }
        manager.clampWindowPosition(window, windowID: windowID)
    }
}

// MARK: - 迁回自 UI-02：class UIWindowSizeRestrictionManager
public final class UIWindowSizeRestrictionManager : @unchecked Sendable {
    deinit {
        logger.info("UIWindowSizeRestrictionManager 已释放")
    }


    /// 全局单例
    public static let shared = UIWindowSizeRestrictionManager()

    /// 日志对象
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "窗口大小限制")

    /// 窗口ID到限制配置的映射
    private var configs: [String: UIWindowSizeRestrictionConfig] = [:]

    /// 窗口ID到代理对象的映射,用于拦截窗口事件
    private var delegates: [String: UIWindowSizeRestrictionDelegate] = [:]

    /// 线程安全锁,保护 configs 和 delegates 字典
    private let lock = NSRecursiveLock()

    /// 私有初始化,防止外部构造
    private init() {
        logger.info("【窗口大小限制】管理器初始化完成")
    }

    // MARK: - 设置方法

    /// 设置窗口的最小尺寸
    /// - Parameters:
    ///   - size: 最小尺寸（nil 表示取消限制）
    ///   - windowID: 窗口唯一标识符
    /// - Note: 如果当前窗口已存在配置,仅更新最小尺寸字段,保留其他限制。
    public func setMinSize(_ size: NSSize?, for windowID: String) {
        lock.lock()
        defer { lock.unlock() }

        var config = configs[windowID] ?? UIWindowSizeRestrictionConfig.none
        config.minSize = size
        configs[windowID] = config

        if let size = size {
            logger.info("【窗口大小限制】设置最小尺寸：\(windowID)，\(size.width)x\(size.height)")
        } else {
            logger.info("【窗口大小限制】取消最小尺寸限制：\(windowID)")
        }
    }

    /// 设置窗口的最大尺寸
    /// - Parameters:
    ///   - size: 最大尺寸（nil 表示取消限制）
    ///   - windowID: 窗口唯一标识符
    /// - Note: 如果当前窗口已存在配置,仅更新最大尺寸字段,保留其他限制。
    public func setMaxSize(_ size: NSSize?, for windowID: String) {
        lock.lock()
        defer { lock.unlock() }

        var config = configs[windowID] ?? UIWindowSizeRestrictionConfig.none
        config.maxSize = size
        configs[windowID] = config

        if let size = size {
            logger.info("【窗口大小限制】设置最大尺寸：\(windowID)，\(size.width)x\(size.height)")
        } else {
            logger.info("【窗口大小限制】取消最大尺寸限制：\(windowID)")
        }
    }

    /// 设置窗口的宽高比锁定
    /// - Parameters:
    ///   - ratio: 宽高比（width / height）,nil 表示取消锁定
    ///   - windowID: 窗口唯一标识符
    /// - Note: 如果当前窗口已存在配置,仅更新宽高比字段,保留其他限制。
    public func setAspectRatio(_ ratio: CGFloat?, for windowID: String) {
        lock.lock()
        defer { lock.unlock() }

        var config = configs[windowID] ?? UIWindowSizeRestrictionConfig.none
        config.aspectRatio = ratio
        configs[windowID] = config

        if let ratio = ratio {
            logger.info("【窗口大小限制】设置宽高比：\(windowID) \(ratio)")
        } else {
            logger.info("【窗口大小限制】取消宽高比锁定：\(windowID)")
        }
    }

    /// 设置窗口的位置限制开关
    /// - Parameters:
    ///   - enabled: 是否启用位置限制
    ///   - windowID: 窗口唯一标识符
    /// - Note: 启用后,窗口移动或缩放后若超出屏幕边界,将自动校正到可见区域内。
    public func setPositionRestriction(_ enabled: Bool, for windowID: String) {
        lock.lock()
        defer { lock.unlock() }

        var config = configs[windowID] ?? UIWindowSizeRestrictionConfig.none
        config.positionRestrictionEnabled = enabled
        configs[windowID] = config

        logger.info("【窗口大小限制】设置位置限制：\(windowID) \(enabled ? "启用" : "禁用")")
    }

    /// 批量设置窗口的所有限制配置
    /// - Parameters:
    ///   - config: 完整的限制配置对象
    ///   - windowID: 窗口唯一标识符
    /// - Note: 此操作会覆盖该窗口的所有现有限制。
    public func setRestrictions(_ config: UIWindowSizeRestrictionConfig, for windowID: String) {
        lock.lock()
        defer { lock.unlock() }

        configs[windowID] = config
        logger.info("【窗口大小限制】批量设置限制：\(windowID) \(config.description)")
    }

    /// 重置窗口的所有限制（恢复为无限制状态）
    /// - Parameter windowID: 窗口唯一标识符
    /// - Note: 此操作会清空该窗口的配置记录,但不会自动移除已附加的代理。
    ///   如需移除代理,请调用 resetRestrictions 后手动设置 window.delegate = nil。
    public func resetRestrictions(for windowID: String) {
        lock.lock()
        defer { lock.unlock() }

        configs.removeValue(forKey: windowID)
        logger.info("【窗口大小限制】重置所有限制：\(windowID)")
    }

    // MARK: - 应用方法

    /// 将所有限制配置应用到指定窗口
    /// - Parameters:
    ///   - window: 目标 NSWindow 实例
    ///   - windowID: 窗口唯一标识符
    /// - Important: 此方法必须在主线程调用,所有 NSWindow 操作均为 UI 操作。
    /// - Note: 方法会设置窗口的 contentMinSize、contentMaxSize、contentAspectRatio,
    ///   并创建/附加 UIWindowSizeRestrictionDelegate 代理以拦截 resize 和 move 事件。
    public func applyAll(to window: NSWindow, windowID: String) {
        assert(Thread.isMainThread, "【窗口大小限制】applyAll 必须在主线程调用")

        lock.lock()
        let config = configs[windowID] ?? UIWindowSizeRestrictionConfig.none
        lock.unlock()

        // 应用最小/最大尺寸限制
        window.contentMinSize = config.minSize ?? NSSize(width: 0, height: 0)
        window.contentMaxSize = config.maxSize ?? NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // 应用宽高比锁定（NSWindow 原生支持）
        if let ratio = config.aspectRatio, ratio > 0 {
            let baseHeight: CGFloat = 100.0
            window.contentAspectRatio = NSSize(width: baseHeight * ratio, height: baseHeight)
        } else {
            window.contentAspectRatio = NSSize(width: 0, height: 0)
        }

        // 创建或复用代理对象
        let delegate: UIWindowSizeRestrictionDelegate
        lock.lock()
        if let existing = delegates[windowID] {
            delegate = existing
        } else {
            delegate = UIWindowSizeRestrictionDelegate()
            delegate.manager = self
            delegate.windowID = windowID
            delegates[windowID] = delegate
        }
        lock.unlock()

        // 附加代理到窗口（仅在窗口当前无 delegate 时设置）
        if window.delegate == nil {
            window.delegate = delegate
        } else if window.delegate !== delegate {
            logger.warning("【窗口大小限制】窗口已有其他代理，无法附加限制代理：\(windowID)")
        }

        // 立即执行位置限制校正
        if config.positionRestrictionEnabled {
            clampWindowPosition(window, windowID: windowID)
        }

        logger.info("【窗口大小限制】已应用到窗口：\(windowID) \(config.description)")
    }

    // MARK: - 拦截方法

    /// 拦截窗口即将改变大小的事件,应用限制规则
    /// - Parameters:
    ///   - window: 触发事件的窗口
    ///   - newSize: 用户请求的新尺寸
    ///   - windowID: 窗口唯一标识符
    /// - Returns: 经限制处理后的最终尺寸
    /// - Note: 此方法由 UIWindowSizeRestrictionDelegate 在 windowWillResize 中调用。
    ///   逻辑包括：最小/最大尺寸限制、宽高比强制校正。
    public func interceptWindowWillResize(_ window: NSWindow, to newSize: NSSize, windowID: String) -> NSSize {
        lock.lock()
        let config = configs[windowID] ?? UIWindowSizeRestrictionConfig.none
        lock.unlock()

        var result = newSize

        // 1. 应用最小尺寸限制
        if let minSize = config.minSize {
            result.width = max(result.width, minSize.width)
            result.height = max(result.height, minSize.height)
        }

        // 2. 应用最大尺寸限制
        if let maxSize = config.maxSize {
            result.width = min(result.width, maxSize.width)
            result.height = min(result.height, maxSize.height)
        }

        // 3. 强制宽高比（如果启用且设置了比例）
        if config.enforceAspectRatioOnResize, let ratio = config.aspectRatio, ratio > 0 {
            let currentSize = window.frame.size
            _ = currentSize.width / max(currentSize.height, 1.0)
            let newRatio = result.width / max(result.height, 1.0)

            if newRatio > ratio {
                // 新尺寸太宽,按高度调整宽度
                result.width = result.height * ratio
            } else if newRatio < ratio {
                // 新尺寸太高,按宽度调整高度
                result.height = result.width / ratio
            }
        }

        return result
    }

    // MARK: - 位置限制

    /// 校正窗口位置,确保不超出屏幕边界
    /// - Parameters:
    ///   - window: 需要校正的窗口
    ///   - windowID: 窗口唯一标识符
    /// - Important: 此方法必须在主线程调用。
    /// - Note: 若窗口跨多个屏幕,以窗口当前所在屏幕（window.screen）的可见区域为边界。
    ///   窗口将被限制在屏幕可见区域内（考虑菜单栏和 Dock 占用）。
    public func clampWindowPosition(_ window: NSWindow, windowID: String) {
        assert(Thread.isMainThread, "【窗口大小限制】clampWindowPosition 必须在主线程调用")

        lock.lock()
        let config = configs[windowID] ?? UIWindowSizeRestrictionConfig.none
        lock.unlock()

        guard config.positionRestrictionEnabled else { return }
        guard let screen = window.screen else { return }

        let screenFrame = screen.visibleFrame
        var frame = window.frame
        var adjusted = false

        // 左边界：窗口左边不能超出屏幕左边
        if frame.origin.x < screenFrame.origin.x {
            frame.origin.x = screenFrame.origin.x
            adjusted = true
        }

        // 下边界：窗口底边不能超出屏幕底边（macOS 坐标系原点在左下角）
        if frame.origin.y < screenFrame.origin.y {
            frame.origin.y = screenFrame.origin.y
            adjusted = true
        }

        // 右边界：窗口右边不能超出屏幕右边
        let maxX = frame.origin.x + frame.size.width
        let screenMaxX = screenFrame.origin.x + screenFrame.size.width
        if maxX > screenMaxX {
            frame.origin.x = screenMaxX - frame.size.width
            adjusted = true
        }

        // 上边界：窗口顶边不能超出屏幕顶边
        let maxY = frame.origin.y + frame.size.height
        let screenMaxY = screenFrame.origin.y + screenFrame.size.height
        if maxY > screenMaxY {
            frame.origin.y = screenMaxY - frame.size.height
            adjusted = true
        }

        // 确保窗口宽度和高度不超出屏幕范围（极端情况下）
        if frame.size.width > screenFrame.size.width {
            frame.size.width = screenFrame.size.width
            frame.origin.x = screenFrame.origin.x
            adjusted = true
        }
        if frame.size.height > screenFrame.size.height {
            frame.size.height = screenFrame.size.height
            frame.origin.y = screenFrame.origin.y
            adjusted = true
        }

        if adjusted {
            window.setFrame(frame, display: true, animate: false)
            logger.info("【窗口大小限制】位置已校正：\(windowID) 新位置(\(frame.origin.x), \(frame.origin.y))")
        }
    }

    // MARK: - 保存与恢复

    /// 保存指定窗口的限制配置到 Data
    /// - Parameter windowID: 窗口唯一标识符
    /// - Returns: 序列化后的 Data,如果不存在配置则返回 nil
    /// - Note: 使用 JSONEncoder 进行序列化,便于写入 UserDefaults 或文件。
    public func saveConfig(for windowID: String) -> Data? {
        lock.lock()
        let config = configs[windowID]
        lock.unlock()

        guard let config = config else {
            logger.debug("【窗口大小限制】无配置可保存：\(windowID)")
            return nil
        }

        do {
            let data = try JSONEncoder().encode(config)
            logger.info("【窗口大小限制】配置已保存：\(windowID) \(data.count) 字节")
            return data
        } catch {
            logger.error("【窗口大小限制】配置保存失败：\(windowID) 错误：\(error.localizedDescription)")
            return nil
        }
    }

    /// 从 Data 恢复窗口的限制配置
    /// - Parameters:
    ///   - data: 序列化后的配置数据
    ///   - windowID: 窗口唯一标识符
    /// - Throws: 当解码失败时抛出 DecodingError
    /// - Note: 恢复后配置会立即存入内存,但尚未应用到窗口。请手动调用 applyAll 生效。
    public func restoreConfig(_ data: Data, for windowID: String) throws {
        let config = try JSONDecoder().decode(UIWindowSizeRestrictionConfig.self, from: data)

        lock.lock()
        configs[windowID] = config
        lock.unlock()

        logger.info("【窗口大小限制】配置已恢复：\(windowID) \(config.description)")
    }

    // MARK: - 查询方法

    /// 获取指定窗口的当前限制配置
    /// - Parameter windowID: 窗口唯一标识符
    /// - Returns: 限制配置,如果不存在则返回 nil
    public func config(for windowID: String) -> UIWindowSizeRestrictionConfig? {
        lock.lock()
        defer { lock.unlock() }
        return configs[windowID]
    }

    /// 检查指定窗口是否已设置限制配置
    /// - Parameter windowID: 窗口唯一标识符
    /// - Returns: 是否存在配置记录
    public func hasConfig(for windowID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return configs[windowID] != nil
    }

    /// 获取所有已设置限制配置的窗口ID列表
    /// - Returns: 窗口ID字符串数组
    public func allWindowIDs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(configs.keys)
    }

    // MARK: - 代理清理

    /// 移除指定窗口的代理对象引用
    /// - Parameter windowID: 窗口唯一标识符
    /// - Note: 当窗口关闭时,应调用此方法清理代理缓存,避免内存泄漏。
    public func removeDelegate(for windowID: String) {
        lock.lock()
        delegates.removeValue(forKey: windowID)
        lock.unlock()
        logger.info("【窗口大小限制】代理已移除：\(windowID)")
    }

    /// 清理所有已释放窗口的代理引用
    /// - Note: 遍历所有代理,若关联窗口已释放则移除记录。
    ///   可定期调用（如窗口关闭时）以保持内存干净。
    public func pruneDelegates() {
        lock.lock()
        var removedCount = 0
        // 遍历keys快照，避免遍历时修改字典
        for id in delegates.keys {
            guard let delegate = delegates[id] else { continue }
            // 如果代理的 manager 或 windowID 已清空,视为无效
            if delegate.manager == nil || delegate.windowID == nil {
                delegates.removeValue(forKey: id)
                removedCount += 1
            }
        }
        lock.unlock()

        if removedCount > 0 {
            logger.info("【窗口大小限制】已清理 \(removedCount) 个无效代理")
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIWindowSizeRestrictionConfig
// MARK: - UI-GL-17 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-17_types.swift
// 版本: 2.0
// MARK: - 窗口限制配置数据模型
/// 可持久化的窗口大小与位置限制配置
///
/// 记录最小/最大尺寸、宽高比锁定、位置限制等参数。
/// 支持 Codable 序列化,用于保存/恢复用户配置。
public struct UIWindowSizeRestrictionConfig: Codable, Equatable, Sendable, CustomStringConvertible {

    /// 最小窗口尺寸（内容区域）
    public var minSize: NSSize?

    /// 最大窗口尺寸（内容区域）
    public var maxSize: NSSize?

    /// 宽高比（width / height）,如 16:9 对应 1.777...
    /// 当此值非 nil 时,窗口 resize 将保持该比例
    public var aspectRatio: CGFloat?

    /// 是否启用位置限制（防止窗口超出屏幕边界）
    public var positionRestrictionEnabled: Bool

    /// 是否在 resize 时强制保持宽高比（通过 windowWillResize 拦截）
    /// 当为 false 时,仅通过 NSWindow.contentAspectRatio 保持比例
    public var enforceAspectRatioOnResize: Bool

    /// 自定义编码键,处理 NSSize 的可编码性
    enum UICodingKeys: String, CodingKey {
        case minSizeWidth, minSizeHeight
        case maxSizeWidth, maxSizeHeight
        case aspectRatio
        case positionRestrictionEnabled
        case enforceAspectRatioOnResize
    }

    public init(
        minSize: NSSize? = nil,
        maxSize: NSSize? = nil,
        aspectRatio: CGFloat? = nil,
        positionRestrictionEnabled: Bool = true,
        enforceAspectRatioOnResize: Bool = true
    ) {
        self.minSize = minSize
        self.maxSize = maxSize
        self.aspectRatio = aspectRatio
        self.positionRestrictionEnabled = positionRestrictionEnabled
        self.enforceAspectRatioOnResize = enforceAspectRatioOnResize
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: UICodingKeys.self)

        if let w = try container.decodeIfPresent(Double.self, forKey: .minSizeWidth),
           let h = try container.decodeIfPresent(Double.self, forKey: .minSizeHeight) {
            self.minSize = NSSize(width: w, height: h)
        } else {
            self.minSize = nil
        }

        if let w = try container.decodeIfPresent(Double.self, forKey: .maxSizeWidth),
           let h = try container.decodeIfPresent(Double.self, forKey: .maxSizeHeight) {
            self.maxSize = NSSize(width: w, height: h)
        } else {
            self.maxSize = nil
        }

        self.aspectRatio = try container.decodeIfPresent(CGFloat.self, forKey: .aspectRatio)
        self.positionRestrictionEnabled = try container.decode(Bool.self, forKey: .positionRestrictionEnabled)
        self.enforceAspectRatioOnResize = try container.decodeIfPresent(Bool.self, forKey: .enforceAspectRatioOnResize) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: UICodingKeys.self)

        try container.encodeIfPresent(minSize?.width, forKey: .minSizeWidth)
        try container.encodeIfPresent(minSize?.height, forKey: .minSizeHeight)
        try container.encodeIfPresent(maxSize?.width, forKey: .maxSizeWidth)
        try container.encodeIfPresent(maxSize?.height, forKey: .maxSizeHeight)
        try container.encodeIfPresent(aspectRatio, forKey: .aspectRatio)
        try container.encode(positionRestrictionEnabled, forKey: .positionRestrictionEnabled)
        try container.encode(enforceAspectRatioOnResize, forKey: .enforceAspectRatioOnResize)
    }

    public var description: String {
        var parts: [String] = []
        if let min = minSize {
            parts.append("最小\(min.width)x\(min.height)")
        }
        if let max = maxSize {
            parts.append("最大\(max.width)x\(max.height)")
        }
        if let ratio = aspectRatio {
            parts.append("宽高比\(String(format: "%.3f", ratio))")
        }
        if positionRestrictionEnabled {
            parts.append("位置限制")
        }
        if enforceAspectRatioOnResize {
            parts.append("强制比例")
        }
        return parts.isEmpty ? "无限制" : parts.joined(separator: ", ")
    }

    /// 空配置（无任何限制）
    public static let none = UIWindowSizeRestrictionConfig(
        minSize: nil,
        maxSize: nil,
        aspectRatio: nil,
        positionRestrictionEnabled: false,
        enforceAspectRatioOnResize: false
    )
}
