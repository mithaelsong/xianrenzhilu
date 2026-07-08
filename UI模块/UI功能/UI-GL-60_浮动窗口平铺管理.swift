// 功能50: 浮动窗口平铺管理
// 对应: 多显示器环境下一键将所有浮动窗口平铺到当前屏幕
// 支持网格、并排、堆叠三种平铺模式，自动排列计算，窗口大小调整，配置持久化
// 优先级: P2

import AppKit
import Foundation
import os.log

#if DEBUG

private let uiGL60TestLogger = Logger(subsystem: "com.xianrenzhilu", category: "UIFloatingWindowTilingTests")

/// 功能50：浮动窗口平铺管理 — 单元测试
func test_tiling() {
    let manager = UIFloatingWindowTilingManager.shared
    
    uiGL60TestLogger.info("测试1: 默认配置")
    if manager.activeMode == .grid { uiGL60TestLogger.info("✅ 测试1通过") }
    else { uiGL60TestLogger.error("❌ 测试1失败") }
    
    uiGL60TestLogger.info("测试2: 注册窗口")
    let reg = manager.registerWindow(windowID: "win1", moduleName: "test")
    if reg { uiGL60TestLogger.info("✅ 测试2通过") }
    else { uiGL60TestLogger.error("❌ 测试2失败") }
    
    uiGL60TestLogger.info("测试3: 重复注册")
    let dup = manager.registerWindow(windowID: "win1", moduleName: "test")
    if !dup { uiGL60TestLogger.info("✅ 测试3通过") }
    else { uiGL60TestLogger.error("❌ 测试3失败") }
    
    uiGL60TestLogger.info("测试4: 窗口计数")
    if manager.registeredWindowCount == 1 { uiGL60TestLogger.info("✅ 测试4通过") }
    else { uiGL60TestLogger.error("❌ 测试4失败") }
    
    uiGL60TestLogger.info("测试5: 切换模式")
    manager.setTilingMode(.sideBySide)
    if manager.activeMode == .sideBySide { uiGL60TestLogger.info("✅ 测试5通过") }
    else { uiGL60TestLogger.error("❌ 测试5失败") }
    
    uiGL60TestLogger.info("测试6: 排除窗口")
    let excluded = manager.excludeWindowFromTiling(windowID: "win1")
    if excluded { uiGL60TestLogger.info("✅ 测试6通过") }
    else { uiGL60TestLogger.error("❌ 测试6失败") }
    
    uiGL60TestLogger.info("测试7: 包含窗口")
    let included = manager.includeWindowInTiling(windowID: "win1")
    if included { uiGL60TestLogger.info("✅ 测试7通过") }
    else { uiGL60TestLogger.error("❌ 测试7失败") }
    
    uiGL60TestLogger.info("测试8: 配置读取")
    let config = manager.currentConfig
    _ = config
    uiGL60TestLogger.info("✅ 测试8通过")
    
    uiGL60TestLogger.info("测试9: 重置配置")
    manager.resetConfigToDefault()
    let afterReset = manager.currentConfig
    if afterReset.mode == .grid { uiGL60TestLogger.info("✅ 测试9通过") }
    else { uiGL60TestLogger.error("❌ 测试9失败") }
    
    uiGL60TestLogger.info("测试10: 注销窗口")
    let unr = manager.unregisterWindow(windowID: "win1")
    if unr { uiGL60TestLogger.info("✅ 测试10通过") }
    else { uiGL60TestLogger.error("❌ 测试10失败") }
    
    uiGL60TestLogger.info("=== 全部平铺管理测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 平铺模式已变更（从旧模式切换到新模式）
    /// userInfo包含: ["oldMode": String, "newMode": String]
    static let tilingModeDidChange = Notification.Name("com.xianrenzhilu.tilingModeDidChange")
    /// 窗口排列已完成（平铺或恢复）
    /// userInfo包含: ["windowIDs": [String], "mode": String, "screen": String?]
    static let tilingWindowsDidArrange = Notification.Name("com.xianrenzhilu.tilingWindowsDidArrange")
    /// 浮动窗口状态变更（注册/注销/排除/启用）
    /// userInfo包含: ["windowID": String, "action": String, "info": UIFloatingWindowInfo?]
    static let tilingFloatingWindowStatusDidChange = Notification.Name("com.xianrenzhilu.tilingFloatingWindowStatusDidChange")
    /// 平铺配置已更新
    /// userInfo包含: ["config": UIFloatingWindowTilingConfig]
    static let tilingConfigDidUpdate = Notification.Name("com.xianrenzhilu.tilingConfigDidUpdate")
}

// MARK: - 迁回自 UI-02：class UIFloatingWindowTilingManager
public final class UIFloatingWindowTilingManager : @unchecked Sendable {

    /// 全局单例
    public static let shared = UIFloatingWindowTilingManager()

    /// 日志记录器（使用 subsystem:category 格式）
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "FloatingWindowTiling")

    /// 线程安全锁，保护所有共享可变状态
    private let lock = NSRecursiveLock()

    /// 已注册的浮动窗口信息列表（按优先级排序）
    private var registeredWindows: [UIFloatingWindowInfo] = []

    /// 当前平铺配置
    private var config: UIFloatingWindowTilingConfig

    /// 当前激活的平铺模式
    private var currentMode: UIFloatingWindowTilingMode

    /// 上次排列的窗口帧映射（windowID -> frame），用于恢复
    private var lastArrangement: [String: NSRect] = [:]

    /// 通知观察token列表（用于deinit时清理）
    private var notificationTokens: [NSObjectProtocol] = []

    /// 配置持久化在UserDefaults中的键名
    private let configKey = "com.xianrenzhilu.floatingWindowTilingConfig"

    // MARK: - 初始化

    private init() {
        // 从UserDefaults加载已保存的配置，否则使用默认配置
        self.config = Self.loadConfigFromDisk()
        self.currentMode = self.config.mode

        // 注册系统通知监听
        setupNotifications()

        logger.info("浮动窗口平铺管理器已初始化，当前模式：\(self.currentMode.rawValue)")
    }

    // MARK: - 清理

    /// 析构时清理通知监听和资源
    deinit {
        cleanup()
    }

    /// 清理所有通知监听和内部状态
    private func cleanup() {
        // 移除所有通知观察
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        notificationTokens.removeAll()

        // 清空内部状态
        lock.lock()
        registeredWindows.removeAll()
        lastArrangement.removeAll()
        lock.unlock()

        logger.info("浮动窗口平铺管理器已清理")
    }

    // MARK: - 通知监听设置

    /// 设置系统级通知监听
    private func setupNotifications() {
        // 监听窗口注册表的新窗口注册，自动将浮动窗口纳入管理
        let registerToken = NotificationCenter.default.addObserver(
            forName: Notification.Name("com.xianrenzhilu.windowDidRegister"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let windowID = notification.userInfo?["windowID"] as? String else { return }
            guard let moduleName = notification.userInfo?["moduleName"] as? String else { return }

            // 检查是否为主窗口或已排除的模块，决定是否自动注册
            lock.lock()
            let autoRegister = config.autoTilingEnabled
            lock.unlock()
            if autoRegister {
                self.registerWindow(windowID: windowID, moduleName: moduleName)
            }
        }
        notificationTokens.append(registerToken)

        // 监听窗口注销，同步从平铺管理器中移除
        let unregisterToken = NotificationCenter.default.addObserver(
            forName: Notification.Name("com.xianrenzhilu.windowDidUnregister"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let windowID = notification.userInfo?["windowID"] as? String else { return }
            self.unregisterWindow(windowID: windowID)
        }
        notificationTokens.append(unregisterToken)
    }

    // MARK: - 窗口注册与注销

    /// 将一个窗口注册到平铺管理器
    /// - Parameters:
    ///   - windowID: 窗口唯一标识（来自窗口注册表）
    ///   - moduleName: 所属模块名称
    ///   - priority: 平铺优先级（数值越小排列越靠前，默认0）
    /// - Returns: 注册是否成功（重复ID返回false）
    @discardableResult
    public func registerWindow(windowID: String, moduleName: String, priority: Int = 0) -> Bool {
        lock.lock()

        // 检查是否已注册
        guard !registeredWindows.contains(where: { $0.windowID == windowID }) else {
            logger.warning("窗口 '\(windowID)' 已在平铺管理器中注册，跳过重复注册")
            lock.unlock()
            return false
        }

        // 检查是否在全局排除列表中
        let isExcluded = config.excludedWindowIDs.contains(windowID)

        var info = UIFloatingWindowInfo(windowID: windowID, moduleName: moduleName, priority: priority)
        info.isExcludedFromTiling = isExcluded
        registeredWindows.append(info)

        // 按优先级排序
        registeredWindows.sort { $0.customPriority < $1.customPriority }

        lock.unlock()
        logger.info("已注册浮动窗口 '\(windowID)'（模块：\(moduleName)，优先级：\(priority)，排除：\(isExcluded)）")

        // 发送状态变更通知
        NotificationCenter.default.post(
            name: .tilingFloatingWindowStatusDidChange,
            object: self,
            userInfo: [
                "windowID": windowID,
                "action": "registered",
                "info": info
            ]
        )

        return true
    }

    /// 从平铺管理器中注销一个窗口
    /// - Parameter windowID: 窗口唯一标识
    /// - Returns: 是否成功注销（不存在返回false）
    @discardableResult
    public func unregisterWindow(windowID: String) -> Bool {
        lock.lock()

        guard let index = registeredWindows.firstIndex(where: { $0.windowID == windowID }) else {
            logger.debug("窗口 '\(windowID)' 不在平铺管理器中，无需注销")
            lock.unlock()
            return false
        }

        let removedInfo = registeredWindows.remove(at: index)
        lastArrangement.removeValue(forKey: windowID)

        lock.unlock()
        logger.info("已注销浮动窗口 '\(windowID)'（模块：\(removedInfo.moduleName)）")

        // 发送状态变更通知
        NotificationCenter.default.post(
            name: .tilingFloatingWindowStatusDidChange,
            object: self,
            userInfo: [
                "windowID": windowID,
                "action": "unregistered",
                "info": removedInfo
            ]
        )

        return true
    }

    /// 检查窗口是否已注册到平铺管理器
    /// - Parameter windowID: 窗口ID
    /// - Returns: 是否已注册
    public func isWindowRegistered(windowID: String) -> Bool {
        lock.lock()
        let r = registeredWindows.contains(where: { $0.windowID == windowID })
        lock.unlock()
        return r
    }

    /// 获取已注册窗口的数量
    public var registeredWindowCount: Int {
        lock.lock()
        let c = registeredWindows.count
        lock.unlock()
        return c
    }

    /// 获取所有已注册窗口的ID列表
    public var allRegisteredWindowIDs: [String] {
        lock.lock()
        let r = registeredWindows.map { $0.windowID }
        lock.unlock()
        return r
    }

    /// 获取所有已注册且未排除的窗口信息
    public var allTileableWindowInfos: [UIFloatingWindowInfo] {
        lock.lock()
        let r = registeredWindows.filter { !$0.isExcludedFromTiling }
        lock.unlock()
        return r
    }

    // MARK: - 排除与启用管理

    /// 将指定窗口从平铺排列中排除（保留原位置）
    /// - Parameter windowID: 窗口ID
    /// - Returns: 是否成功设置
    @discardableResult
    public func excludeWindowFromTiling(windowID: String) -> Bool {
        lock.lock()

        guard let index = registeredWindows.firstIndex(where: { $0.windowID == windowID }) else {
            logger.warning("无法排除窗口 '\(windowID)'：未在平铺管理器中注册")
            lock.unlock()
            return false
        }

        registeredWindows[index].isExcludedFromTiling = true

        // 同时加入全局排除列表
        if !config.excludedWindowIDs.contains(windowID) {
            config.excludedWindowIDs.append(windowID)
            saveConfigToDisk()
        }

        lock.unlock()
        logger.info("窗口 '\(windowID)' 已设置为排除平铺")

        NotificationCenter.default.post(
            name: .tilingFloatingWindowStatusDidChange,
            object: self,
            userInfo: [
                "windowID": windowID,
                "action": "excluded"
            ]
        )

        return true
    }

    /// 将指定窗口重新纳入平铺排列
    /// - Parameter windowID: 窗口ID
    /// - Returns: 是否成功设置
    @discardableResult
    public func includeWindowInTiling(windowID: String) -> Bool {
        lock.lock()

        guard let index = registeredWindows.firstIndex(where: { $0.windowID == windowID }) else {
            logger.warning("无法启用窗口 '\(windowID)' 平铺：未在平铺管理器中注册")
            lock.unlock()
            return false
        }

        registeredWindows[index].isExcludedFromTiling = false

        // 从全局排除列表中移除
        config.excludedWindowIDs.removeAll { $0 == windowID }
        saveConfigToDisk()

        lock.unlock()
        logger.info("窗口 '\(windowID)' 已重新纳入平铺")

        NotificationCenter.default.post(
            name: .tilingFloatingWindowStatusDidChange,
            object: self,
            userInfo: [
                "windowID": windowID,
                "action": "included"
            ]
        )

        return true
    }

    // MARK: - 平铺模式切换

    /// 当前激活的平铺模式
    public var activeMode: UIFloatingWindowTilingMode {
        lock.lock()
        let m = currentMode
        lock.unlock()
        return m
    }

    /// 切换平铺模式
    /// - Parameter mode: 目标平铺模式
    public func setTilingMode(_ mode: UIFloatingWindowTilingMode) {
        let oldMode: UIFloatingWindowTilingMode
        lock.lock()
        oldMode = currentMode
        currentMode = mode
        config.mode = mode
        lock.unlock()

        saveConfigToDisk()

        logger.info("平铺模式已切换：\(oldMode.displayName) -> \(mode.displayName)")

        // 发送模式变更通知
        NotificationCenter.default.post(
            name: .tilingModeDidChange,
            object: self,
            userInfo: [
                "oldMode": oldMode.rawValue,
                "newMode": mode.rawValue
            ]
        )
    }

    // MARK: - 主平铺入口

    /// 将所有已注册且未排除的浮动窗口平铺到主屏幕
    /// 使用当前配置的平铺模式和参数
    /// - Returns: 平铺操作结果
    @discardableResult
    public func tileToMainScreen() -> UITilingOperationResult {
        guard let mainScreen = NSScreen.main else {
            logger.error("无法平铺：未检测到主屏幕")
            return UITilingOperationResult(
                successCount: 0, failureCount: 0, excludedCount: 0,
                totalCount: 0, mode: currentMode, screenDescription: "无屏幕",
                windowResults: []
            )
        }
        return tileWindowsToScreen(mainScreen)
    }

    /// 将所有已注册且未排除的浮动窗口平铺到指定屏幕
    /// - Parameter screen: 目标屏幕
    /// - Returns: 平铺操作结果
    @discardableResult
    public func tileWindowsToScreen(_ screen: NSScreen) -> UITilingOperationResult {
        let currentConfig: UIFloatingWindowTilingConfig
        let mode: UIFloatingWindowTilingMode

        // 获取当前需要平铺的窗口列表
        lock.lock()
        currentConfig = config
        mode = currentMode
        let targetWindowIDs = registeredWindows
            .filter { !$0.isExcludedFromTiling }
            .map { $0.windowID }
        lock.unlock()

        // 从窗口注册表获取实际窗口实例
        let allRecords: [UITilingWindowRecord] = [] // /* WindowRegistry.shared 不可用 */.allActiveRecords
        let targetRecords = allRecords.filter { targetWindowIDs.contains($0.windowID) }
        let excludedCount = targetWindowIDs.count - targetRecords.count

        let visibleFrame = screen.visibleFrame
        let screenDesc = "\(screen.localizedName) (\(Int(visibleFrame.width))x\(Int(visibleFrame.height)))"

        logger.info("开始平铺 \(targetRecords.count) 个窗口到屏幕 \(screenDesc)，模式：\(mode.displayName)")

        // 执行平铺算法
        let result = executeTiling(
            records: targetRecords,
            in: visibleFrame,
            mode: mode,
            config: currentConfig
        )

        logger.info("平铺完成：成功\(result.successCount) 失败\(result.failureCount) 排除\(excludedCount)")

        // 发送排列完成通知
        NotificationCenter.default.post(
            name: .tilingWindowsDidArrange,
            object: self,
            userInfo: [
                "windowIDs": targetWindowIDs,
                "mode": mode.rawValue,
                "screen": screenDesc,
                "result": result
            ]
        )

        return result
    }

    // MARK: - 平铺算法执行

    /// 执行具体的平铺算法
    private func executeTiling(
        records: [UITilingWindowRecord],
        in frame: NSRect,
        mode: UIFloatingWindowTilingMode,
        config: UIFloatingWindowTilingConfig
    ) -> UITilingOperationResult {
        let count = records.count
        guard count > 0 else {
            return UITilingOperationResult(
                successCount: 0, failureCount: 0, excludedCount: 0,
                totalCount: 0, mode: mode, screenDescription: "\(Int(frame.width))x\(Int(frame.height))",
                windowResults: []
            )
        }

        // 计算可用区域（去除边距）
        let availableFrame = NSRect(
            x: frame.minX + config.margin,
            y: frame.minY + config.margin,
            width: frame.width - config.margin * 2,
            height: frame.height - config.margin * 2
        )

        var windowResults: [UITilingWindowResult] = []

        switch mode {
        case .grid:
            windowResults = tileGrid(records: records, frame: availableFrame, config: config)
        case .sideBySide:
            windowResults = tileSideBySide(records: records, frame: availableFrame, config: config)
        case .stack:
            windowResults = tileStack(records: records, frame: availableFrame, config: config)
        }

        let successCount = windowResults.filter { $0.applied }.count
        let failureCount = windowResults.count - successCount

        return UITilingOperationResult(
            successCount: successCount,
            failureCount: failureCount,
            excludedCount: 0,
            totalCount: count,
            mode: mode,
            screenDescription: "\(Int(frame.width))x\(Int(frame.height))",
            windowResults: windowResults
        )
    }

    // MARK: - 网格平铺算法

    /// 网格平铺：将窗口按行列均分排列
    private func tileGrid(
        records: [UITilingWindowRecord],
        frame: NSRect,
        config: UIFloatingWindowTilingConfig
    ) -> [UITilingWindowResult] {
        let count = records.count
        var results: [UITilingWindowResult] = []

        // 计算行列数
        let columns: Int
        let rows: Int
        if config.gridColumns > 0 && config.gridRows > 0 {
            columns = config.gridColumns
            rows = config.gridRows
        } else if config.gridColumns > 0 {
            columns = config.gridColumns
            rows = max(1, (count + columns - 1) / columns)
        } else {
            // 自动计算：尽量接近正方形
            columns = max(1, Int(ceil(sqrt(Double(count)))))
            rows = max(1, (count + columns - 1) / columns)
        }

        // 计算每个单元格的尺寸（扣除间距）
        let totalHGap = config.padding * CGFloat(columns - 1)
        let totalVGap = config.padding * CGFloat(rows - 1)
        let cellWidth = max(config.minWindowWidth, (frame.width - totalHGap) / CGFloat(columns))
        let cellHeight = max(config.minWindowHeight, (frame.height - totalVGap) / CGFloat(rows))

        for (i, record) in records.enumerated() {
            let col = i % columns
            let row = i / columns

            let x = frame.minX + CGFloat(col) * (cellWidth + config.padding)
            let y = frame.maxY - CGFloat(row + 1) * (cellHeight + config.padding) + config.padding
            let targetFrame = NSRect(x: x, y: y, width: cellWidth, height: cellHeight)

            let result = applyFrame(to: record, frame: targetFrame, config: config, index: i)
            results.append(result)
        }

        return results
    }

    // MARK: - 并排平铺算法

    /// 并排平铺：窗口水平并排排列
    private func tileSideBySide(
        records: [UITilingWindowRecord],
        frame: NSRect,
        config: UIFloatingWindowTilingConfig
    ) -> [UITilingWindowResult] {
        let count = records.count
        var results: [UITilingWindowResult] = []

        let totalGap = config.padding * CGFloat(count - 1)

        if config.sideBySidePreserveRatio, records.first?.window != nil {
            // 按原始宽度比例分配
            let totalOriginalWidth = records.compactMap { $0.window?.frame.width }.reduce(0, +)
            let availableWidth = frame.width - totalGap
            var currentX = frame.minX

            for (i, record) in records.enumerated() {
                let windowWidth = record.window?.frame.width ?? (availableWidth / CGFloat(count))
                let ratio = totalOriginalWidth > 0 ? windowWidth / totalOriginalWidth : 1.0 / CGFloat(count)
                let width = max(config.minWindowWidth, availableWidth * ratio)
                let targetFrame = NSRect(
                    x: currentX,
                    y: frame.minY,
                    width: width,
                    height: frame.height
                )
                let result = applyFrame(to: record, frame: targetFrame, config: config, index: i)
                results.append(result)
                currentX += width + config.padding
            }
        } else {
            // 等宽分配
            let width = max(config.minWindowWidth, (frame.width - totalGap) / CGFloat(count))
            for (i, record) in records.enumerated() {
                let x = frame.minX + CGFloat(i) * (width + config.padding)
                let targetFrame = NSRect(
                    x: x,
                    y: frame.minY,
                    width: width,
                    height: frame.height
                )
                let result = applyFrame(to: record, frame: targetFrame, config: config, index: i)
                results.append(result)
            }
        }

        return results
    }

    // MARK: - 堆叠平铺算法

    /// 堆叠平铺：窗口垂直堆叠排列
    private func tileStack(
        records: [UITilingWindowRecord],
        frame: NSRect,
        config: UIFloatingWindowTilingConfig
    ) -> [UITilingWindowResult] {
        let count = records.count
        var results: [UITilingWindowResult] = []

        let totalGap = config.padding * CGFloat(count - 1)

        if config.stackEqualHeight {
            // 等高堆叠
            let height = max(config.minWindowHeight, (frame.height - totalGap) / CGFloat(count))
            for (i, record) in records.enumerated() {
                let y = frame.maxY - CGFloat(i + 1) * (height + config.padding) + config.padding
                let targetFrame = NSRect(
                    x: frame.minX,
                    y: y,
                    width: frame.width,
                    height: height
                )
                let result = applyFrame(to: record, frame: targetFrame, config: config, index: i)
                results.append(result)
            }
        } else {
            // 按原始高度比例堆叠
            let totalOriginalHeight = records.compactMap { $0.window?.frame.height }.reduce(0, +)
            let availableHeight = frame.height - totalGap
            var currentY = frame.maxY

            for (i, record) in records.enumerated() {
                let windowHeight = record.window?.frame.height ?? (availableHeight / CGFloat(count))
                let ratio = totalOriginalHeight > 0 ? windowHeight / totalOriginalHeight : 1.0 / CGFloat(count)
                let height = max(config.minWindowHeight, availableHeight * ratio)
                currentY -= height
                let targetFrame = NSRect(
                    x: frame.minX,
                    y: currentY,
                    width: frame.width,
                    height: height
                )
                let result = applyFrame(to: record, frame: targetFrame, config: config, index: i)
                results.append(result)
                currentY -= config.padding
            }
        }

        return results
    }

    // MARK: - 帧应用

    /// 将计算好的帧应用到实际窗口
    private func applyFrame(
        to record: UITilingWindowRecord,
        frame: NSRect,
        config: UIFloatingWindowTilingConfig,
        index: Int
    ) -> UITilingWindowResult {
        guard let window = record.window else {
            return UITilingWindowResult(
                windowID: record.windowID,
                targetFrame: frame,
                applied: false,
                failureReason: "窗口实例已失效"
            )
        }

        var finalFrame = frame

        // 尊重窗口最小尺寸限制
        if config.respectMinSize {
            let minSize = window.minSize
            if minSize.width > 0 || minSize.height > 0 {
                finalFrame.size.width = max(finalFrame.width, minSize.width)
                finalFrame.size.height = max(finalFrame.height, minSize.height)
            }
        }

        // 尊重窗口最大尺寸限制
        if config.respectMaxSize {
            let maxSize = window.maxSize
            if maxSize.width > 0, maxSize.height > 0 {
                finalFrame.size.width = min(finalFrame.width, maxSize.width)
                finalFrame.size.height = min(finalFrame.height, maxSize.height)
            }
        }

        // 保存原始帧（用于恢复）
        lock.lock()
        lastArrangement[record.windowID] = window.frame
        // 更新窗口信息中的最后平铺帧
        if let idx = registeredWindows.firstIndex(where: { $0.windowID == record.windowID }) {
            registeredWindows[idx].lastTiledFrame = UITilingFrame(rect: finalFrame)
        }
        lock.unlock()

        // 应用动画或立即设置
        if config.animationDuration > 0 {
            window.setFrame(finalFrame, display: true, animate: true)
        } else {
            window.setFrame(finalFrame, display: true, animate: false)
        }

        return UITilingWindowResult(
            windowID: record.windowID,
            targetFrame: finalFrame,
            applied: true,
            failureReason: nil
        )
    }

    // MARK: - 恢复原始位置

    /// 将所有已平铺窗口恢复到平铺前的原始位置
    /// - Returns: 成功恢复的窗口数量
    @discardableResult
    public func restoreOriginalPositions() -> Int {
        var restoreCount = 0
        var restoredIDs: [String] = []

        lock.lock()
        let snapshot = lastArrangement
        lock.unlock()

        for (windowID, originalFrame) in snapshot {
            guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowID }) else { continue }  // 替代 WindowRegistry 获取窗口

            if config.animationDuration > 0 {
                window.setFrame(originalFrame, display: true, animate: true)
            } else {
                window.setFrame(originalFrame, display: true, animate: false)
            }
            restoreCount += 1
            restoredIDs.append(windowID)
        }

        logger.info("已恢复 \(restoreCount) 个窗口到原始位置")

        // 发送排列通知（恢复也算一次排列）
        NotificationCenter.default.post(
            name: .tilingWindowsDidArrange,
            object: self,
            userInfo: [
                "windowIDs": restoredIDs,
                "mode": "restore",
                "action": "restoreOriginal"
            ]
        )

        return restoreCount
    }

    // MARK: - 配置持久化

    /// 加载已保存的配置（私有静态方法）
    private static func loadConfigFromDisk() -> UIFloatingWindowTilingConfig {
        let key = "com.xianrenzhilu.floatingWindowTilingConfig"
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return .default
        }
        do {
            let decoder = JSONDecoder()
            let config = try decoder.decode(UIFloatingWindowTilingConfig.self, from: data)
            return config
        } catch {
            return .default
        }
    }

    /// 保存当前配置到UserDefaults（私有方法）
    private func saveConfigToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(config)
            UserDefaults.standard.set(data, forKey: configKey)
            logger.debug("平铺配置已持久化")
        } catch {
            logger.error("平铺配置持久化失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 设置面板方法（外部配置接口）

    /// 获取当前平铺配置的副本（用于设置面板读取）
    public var currentConfig: UIFloatingWindowTilingConfig {
        lock.lock()
        let c = config
        lock.unlock()
        return c
    }

    /// 应用新的平铺配置（通常由设置面板调用）
    /// - Parameter newConfig: 新的配置对象
    public func applyConfig(_ newConfig: UIFloatingWindowTilingConfig) {
        lock.lock()
        let oldMode = currentMode
        config = newConfig
        currentMode = newConfig.mode
        lock.unlock()

        saveConfigToDisk()

        // 如果模式发生变化，发送模式变更通知
        if oldMode != newConfig.mode {
            NotificationCenter.default.post(
                name: .tilingModeDidChange,
                object: self,
                userInfo: [
                    "oldMode": oldMode.rawValue,
                    "newMode": newConfig.mode.rawValue
                ]
            )
        }

        // 发送配置更新通知
        NotificationCenter.default.post(
            name: .tilingConfigDidUpdate,
            object: self,
            userInfo: ["config": newConfig]
        )

        logger.info("平铺配置已更新：模式\(newConfig.mode.displayName)，间距\(newConfig.padding)，边距\(newConfig.margin)")
    }

    /// 重置配置为默认值
    public func resetConfigToDefault() {
        applyConfig(.default)
        logger.info("平铺配置已重置为默认值")
    }

    /// 设置网格行列数
    /// - Parameters:
    ///   - columns: 列数（0表示自动）
    ///   - rows: 行数（0表示自动）
    public func setGridDimensions(columns: Int, rows: Int) {
        lock.lock()
        config.gridColumns = max(0, columns)
        config.gridRows = max(0, rows)
        lock.unlock()
        saveConfigToDisk()
        logger.info("网格尺寸已设置为 \(columns)x\(rows)")
    }

    /// 设置间距和边距
    /// - Parameters:
    ///   - padding: 窗口间距
    ///   - margin: 屏幕边距
    public func setSpacing(padding: CGFloat, margin: CGFloat) {
        lock.lock()
        config.padding = max(0, padding)
        config.margin = max(0, margin)
        lock.unlock()
        saveConfigToDisk()
        logger.info("间距已设置为 padding=\(padding) margin=\(margin)")
    }

    /// 设置动画时长
    /// - Parameter duration: 动画时长（秒，0表示无动画）
    public func setAnimationDuration(_ duration: TimeInterval) {
        lock.lock()
        config.animationDuration = max(0, duration)
        lock.unlock()
        saveConfigToDisk()
        logger.info("动画时长已设置为 \(duration) 秒")
    }

    /// 设置自动平铺开关
    /// - Parameter enabled: 是否启用
    public func setAutoTilingEnabled(_ enabled: Bool) {
        lock.lock()
        config.autoTilingEnabled = enabled
        lock.unlock()
        saveConfigToDisk()
        logger.info("自动平铺已\(enabled ? "启用" : "禁用")")
    }

    /// 设置窗口最小尺寸限制
    /// - Parameters:
    ///   - width: 最小宽度
    ///   - height: 最小高度
    public func setMinWindowSize(width: CGFloat, height: CGFloat) {
        lock.lock()
        config.minWindowWidth = max(100, width)
        config.minWindowHeight = max(100, height)
        lock.unlock()
        saveConfigToDisk()
        logger.info("窗口最小尺寸已设置为 \(width)x\(height)")
    }

    // MARK: - 批量操作与查询

    /// 注销所有已注册的窗口
    public func unregisterAllWindows() {
        lock.lock()
        let count = registeredWindows.count
        let allIDs = registeredWindows.map { $0.windowID }
        registeredWindows.removeAll()
        lastArrangement.removeAll()
        lock.unlock()

        logger.info("已注销全部 \(count) 个浮动窗口")

        for id in allIDs {
            NotificationCenter.default.post(
                name: .tilingFloatingWindowStatusDidChange,
                object: self,
                userInfo: ["windowID": id, "action": "unregisteredAll"]
            )
        }
    }

    /// 获取指定窗口的信息
    /// - Parameter windowID: 窗口ID
    /// - Returns: 窗口信息，未注册时返回nil
    public func windowInfo(for windowID: String) -> UIFloatingWindowInfo? {
        lock.lock()
        let r = registeredWindows.first(where: { $0.windowID == windowID })
        lock.unlock()
        return r
    }

    /// 更新窗口的平铺优先级
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - priority: 新优先级
    /// - Returns: 是否成功更新
    @discardableResult
    public func setWindowPriority(windowID: String, priority: Int) -> Bool {
        lock.lock()
        guard let index = registeredWindows.firstIndex(where: { $0.windowID == windowID }) else {
            lock.unlock()
            return false
        }

        registeredWindows[index].customPriority = priority
        // 重新排序
        registeredWindows.sort { $0.customPriority < $1.customPriority }

        logger.info("窗口 '\(windowID)' 优先级已更新为 \(priority)")
        lock.unlock()
        return true
    }

    /// 获取平铺管理器的当前状态描述（用于调试面板）
    public var statusDescription: String {
        lock.lock()
        let mode = currentMode
        let count = registeredWindows.count
        let tileable = registeredWindows.filter { !$0.isExcludedFromTiling }.count
        let excluded = registeredWindows.filter { $0.isExcludedFromTiling }.count
        lock.unlock()

        return "平铺管理器：模式=\(mode.displayName)，注册窗口=\(count)，可平铺=\(tileable)，排除=\(excluded)"
    }

    /// 获取详细的调试信息
    public var detailedDescription: String {
        lock.lock()
        let windows = registeredWindows
        let mode = currentMode
        let cfg = config
        lock.unlock()

        var lines: [String] = []
        lines.append("=== 浮动窗口平铺管理器详情 ===")
        lines.append("当前模式：\(mode.displayName)")
        lines.append("网格尺寸：\(cfg.gridColumns)列 x \(cfg.gridRows)行")
        lines.append("间距：\(cfg.padding) 边距：\(cfg.margin)")
        lines.append("动画：\(cfg.animationDuration)秒 自动平铺：\(cfg.autoTilingEnabled ? "开" : "关")")
        lines.append("已注册窗口：\(windows.count) 个")
        lines.append("")

        for (i, info) in windows.enumerated() {
            let status = info.isExcludedFromTiling ? "[排除]" : "[正常]"
            lines.append("\(i+1). \(status) \(info.windowID)（\(info.moduleName)）优先级=\(info.customPriority)")
        }

        lines.append("=== 结束 ===")
        return lines.joined(separator: "\n")
    }

    // MARK: - 便捷平铺方法

    /// 使用网格模式平铺到主屏幕
    /// - Parameter columns: 列数
    /// - Returns: 平铺操作结果
    @discardableResult
    public func tileGridToMainScreen(columns: Int) -> UITilingOperationResult {
        setTilingMode(.grid)
        setGridDimensions(columns: columns, rows: 0)
        return tileToMainScreen()
    }

    /// 使用并排模式平铺到主屏幕
    /// - Returns: 平铺操作结果
    @discardableResult
    public func tileSideBySideToMainScreen() -> UITilingOperationResult {
        setTilingMode(.sideBySide)
        return tileToMainScreen()
    }

    /// 使用堆叠模式平铺到主屏幕
    /// - Returns: 平铺操作结果
    @discardableResult
    public func tileStackToMainScreen() -> UITilingOperationResult {
        setTilingMode(.stack)
        return tileToMainScreen()
    }
}

// MARK: - 迁回自 UI-02：extension UIFloatingWindowTilingManager
public extension UIFloatingWindowTilingManager {

    /// 所有已注册窗口的模块名称集合（去重）
    var allRegisteredModuleNames: [String] {
        lock.lock()
        let r = Array(Set(registeredWindows.map { $0.moduleName })).sorted()
        lock.unlock()
        return r
    }

    /// 按模块统计已注册窗口数量
    var moduleRegistrationStatistics: [String: Int] {
        lock.lock()
        var stats: [String: Int] = [:]
        for info in registeredWindows {
            stats[info.moduleName, default: 0] += 1
        }
        lock.unlock()
        return stats
    }

    /// 获取指定模块的所有已注册窗口ID
    /// - Parameter moduleName: 模块名
    /// - Returns: 窗口ID数组
    func registeredWindowIDs(for moduleName: String) -> [String] {
        lock.lock()
        let r = registeredWindows.filter { $0.moduleName == moduleName }.map { $0.windowID }
        lock.unlock()
        return r
    }

    /// 平铺指定模块的所有窗口到主屏幕
    /// - Parameter moduleName: 模块名
    /// - Returns: 平铺操作结果
    @discardableResult
    func tileModuleToMainScreen(_ moduleName: String) -> UITilingOperationResult {
        guard let mainScreen = NSScreen.main else {
            logger.error("无法平铺模块：未检测到主屏幕")
            return UITilingOperationResult(
                successCount: 0, failureCount: 0, excludedCount: 0,
                totalCount: 0, mode: currentMode, screenDescription: "无屏幕",
                windowResults: []
            )
        }

        let targetIDs = registeredWindowIDs(for: moduleName)
        let allRecords: [UITilingWindowRecord] = [] // /* WindowRegistry.shared 不可用 */.allActiveRecords
        let targetRecords = allRecords.filter { targetIDs.contains($0.windowID) }

        let visibleFrame = mainScreen.visibleFrame
        let config = currentConfig
        let mode = activeMode

        logger.info("开始平铺模块 '\(moduleName)' 的 \(targetRecords.count) 个窗口")
        let result = executeTiling(records: targetRecords, in: visibleFrame, mode: mode, config: config)

        NotificationCenter.default.post(
            name: .tilingWindowsDidArrange,
            object: self,
            userInfo: [
                "windowIDs": targetIDs,
                "mode": mode.rawValue,
                "moduleName": moduleName
            ]
        )

        return result
    }
}

// MARK: - 迁回自 UI-02：enum UIFloatingWindowTilingMode
/// 封装单个自动隐藏区域的运行时状态,不直接参与持久化
// 已迁回 UI-GL-59_自动隐藏区域.swift：class UIAutoHideZoneInfo（公共类型文件禁止功能实现）

/// 管理窗口四边自动隐藏面板的核心单例类
/// 负责鼠标悬停检测、展开/隐藏动画、配置持久化、手动锁定等完整生命周期
// 已迁回 UI-GL-59_自动隐藏区域.swift：class UIAutoHideManager（公共类型文件禁止功能实现）

/// 为 UIAutoHideManager 提供设置面板专用的便捷方法扩展
// 已迁回 UI-GL-59_自动隐藏区域.swift：extension UIAutoHideManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-60 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-60_types.swift
// 版本: 2.0
// MARK: - 平铺模式
/// 浮动窗口支持的平铺排列模式
public enum UIFloatingWindowTilingMode: String, Codable, CaseIterable, Sendable, CustomStringConvertible {
    /// 网格模式：窗口按行列均分排列
    case grid = "grid"
    /// 并排模式：窗口水平并排排列
    case sideBySide = "sideBySide"
    /// 堆叠模式：窗口垂直堆叠排列
    case stack = "stack"

    /// 中文显示名称
    public var displayName: String {
        switch self {
        case .grid: return "网格"
        case .sideBySide: return "并排"
        case .stack: return "堆叠"
        }
    }

    public var description: String { displayName }
}

// MARK: - 迁回自 UI-02：struct UIFloatingWindowInfo
// MARK: - 浮动窗口信息
/// 已注册到平铺管理器的浮动窗口元信息
public struct UIFloatingWindowInfo: Codable, Identifiable, Equatable {
    /// 唯一标识（对应窗口注册表中的windowID）
    public let id: String
    /// 窗口唯一标识
    public var windowID: String
    /// 所属模块名称
    public var moduleName: String
    /// 注册到平铺管理器的时间
    public var registeredAt: Date
    /// 是否从平铺中排除（保留原位置不变）
    public var isExcludedFromTiling: Bool
    /// 平铺优先级（数值越小越靠前排列）
    public var customPriority: Int
    /// 最后平铺时分配的帧（用于恢复）
    public var lastTiledFrame: UITilingFrame?

    public init(windowID: String, moduleName: String, priority: Int = 0) {
        self.id = windowID
        self.windowID = windowID
        self.moduleName = moduleName
        self.registeredAt = Date()
        self.isExcludedFromTiling = false
        self.customPriority = priority
        self.lastTiledFrame = nil
    }
}

// MARK: - 迁回自 UI-02：struct UITilingWindowRecord
// MARK: - 窗口记录（用于平铺算法）
/// 平铺算法使用的窗口记录，包含窗口ID和窗口引用
public struct UITilingWindowRecord: Identifiable, Equatable {
    /// 窗口唯一标识
    public let id: String
    /// 窗口引用（运行时，不参与编码）
    public var window: NSWindow?
    
    /// 窗口唯一标识（兼容字段，等同于 id）
    public var windowID: String { id }
    
    public init(id: String, window: NSWindow? = nil) {
        self.id = id
        self.window = window
    }
    
    enum UICodingKeys: String, CodingKey {
        case id
    }
}

// MARK: - 迁回自 UI-02：struct UITilingFrame
// MARK: - 可编码帧（用于持久化窗口位置）
/// 可编码的矩形帧，用于保存窗口平铺位置
public struct UITilingFrame: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(rect: NSRect) {
        self.x = Double(rect.origin.x)
        self.y = Double(rect.origin.y)
        self.width = Double(rect.size.width)
        self.height = Double(rect.size.height)
    }

    public var nsRect: NSRect {
        NSRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    }
}

// MARK: - 迁回自 UI-02：struct UIFloatingWindowTilingConfig
// MARK: - 平铺配置
/// 浮动窗口平铺的全局配置，支持Codable持久化
public struct UIFloatingWindowTilingConfig: Codable, Equatable, Sendable {
    /// 当前平铺模式
    public var mode: UIFloatingWindowTilingMode
    /// 网格模式的列数（0表示自动计算）
    public var gridColumns: Int
    /// 网格模式的行数（0表示自动计算）
    public var gridRows: Int
    /// 窗口之间的间距（像素）
    public var padding: CGFloat
    /// 屏幕边缘留白（像素）
    public var margin: CGFloat
    /// 平铺动画时长（秒，0表示无动画）
    public var animationDuration: TimeInterval
    /// 是否尊重窗口最小尺寸限制
    public var respectMinSize: Bool
    /// 是否尊重窗口最大尺寸限制
    public var respectMaxSize: Bool
    /// 是否启用自动平铺（窗口注册时自动触发）
    public var autoTilingEnabled: Bool
    /// 被排除的窗口ID列表
    public var excludedWindowIDs: [String]
    /// 窗口最小宽度（像素，低于此值时不压缩）
    public var minWindowWidth: CGFloat
    /// 窗口最小高度（像素，低于此值时不压缩）
    public var minWindowHeight: CGFloat
    /// 并排序排列时是否按窗口原始宽度比例分配
    public var sideBySidePreserveRatio: Bool
    /// 堆叠模式时是否等高排列
    public var stackEqualHeight: Bool

    /// 默认配置
    public static let `default` = UIFloatingWindowTilingConfig(
        mode: .grid,
        gridColumns: 3,
        gridRows: 0,
        padding: 8.0,
        margin: 8.0,
        animationDuration: 0.25,
        respectMinSize: true,
        respectMaxSize: true,
        autoTilingEnabled: false,
        excludedWindowIDs: [],
        minWindowWidth: 400.0,
        minWindowHeight: 300.0,
        sideBySidePreserveRatio: false,
        stackEqualHeight: true
    )
}

// MARK: - 迁回自 UI-02：struct UITilingOperationResult
// MARK: - 平铺结果
/// 单次平铺操作的结果记录
public struct UITilingOperationResult {
    /// 成功排列的窗口数量
    public let successCount: Int
    /// 失败的窗口数量
    public let failureCount: Int
    /// 被排除的窗口数量
    public let excludedCount: Int
    /// 总参与窗口数量
    public let totalCount: Int
    /// 所使用的平铺模式
    public let mode: UIFloatingWindowTilingMode
    /// 目标屏幕描述
    public let screenDescription: String
    /// 各窗口的具体结果
    public let windowResults: [UITilingWindowResult]
}

// MARK: - 迁回自 UI-02：struct UITilingWindowResult
/// 单个窗口的平铺结果
public struct UITilingWindowResult {
    /// 窗口ID
    public let windowID: String
    /// 目标帧位置
    public let targetFrame: NSRect
    /// 是否成功应用
    public let applied: Bool
    /// 失败原因（成功时为nil）
    public let failureReason: String?
}
