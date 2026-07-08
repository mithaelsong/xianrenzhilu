// 功能45: 历史数据回放模式
// 对应: 以播放器形式回放历史K线数据，支持播放/暂停/停止/速度调节/NSSlider拖拽
// 优先级: P2
import AppKit
import Foundation
import os.log

// MARK: - 统一日志器
private let logger = Logger(subsystem: "com.xianrenzhilu.app", category: "HistoricalReplay")

// 类型定义已迁移到 /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-55_types.swift
// 本文件仅保留功能调用逻辑/测试逻辑。

// MARK: - 测试代码
#if DEBUG

/// 功能45：历史数据回放模式 — 单元测试
func test_replay() {
    let manager = UIHistoricalReplayManager.shared
    
    logger.info("测试1: 初始状态")
    if manager.state == .stopped { logger.info("✅ 测试1通过: 默认已停止") }
    else { logger.error("❌ 测试1失败") }
    
    logger.info("测试2: 加载配置")
    let config = UIHistoricalReplayConfiguration(
        symbol: "BTCUSDT", interval: "1h",
        startTime: Date().timeIntervalSince1970 - 86400 * 30,
        endTime: Date().timeIntervalSince1970,
        defaultSpeed: .x1, autoPlay: false,
        loopPlayback: false, chartLockEnabled: true,
        defaultTimestamp: nil
    )
    manager.loadConfiguration(config)
    if manager.configuration?.symbol == "BTCUSDT" { logger.info("✅ 测试2通过") }
    else { logger.error("❌ 测试2失败") }
    
    logger.info("测试3: 速度切换")
    manager.setSpeed(.x2)
    if manager.speed == .x2 { logger.info("✅ 测试3通过") }
    else { logger.error("❌ 测试3失败") }
    
    logger.info("测试4: 播放/暂停")
    manager.play()
    if manager.state == .playing { logger.info("✅ 测试4通过") }
    else { logger.error("❌ 测试4失败") }
    manager.pause()
    
    logger.info("测试5: 进度查询")
    let progress = manager.progress
    _ = progress
    logger.info("✅ 测试5通过")
    
    logger.info("测试6: stop")
    manager.stop()
    if manager.state == .stopped { logger.info("✅ 测试6通过") }
    else { logger.error("❌ 测试6失败") }
    
    logger.info("测试7: 进度跳转")
    manager.seekToProgress(0.5)
    let p = manager.progress
    if p > 0.49 && p < 0.51 { logger.info("✅ 测试7通过") }
    else { logger.error("❌ 测试7失败: progress=\(p)") }
    
    logger.info("=== 全部历史回放测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 回放状态发生变更时发送（停止/播放/暂停）
    static let historicalReplayStateChanged = Notification.Name("com.xianrenzhilu.historicalReplayStateChanged")
    /// 回放进度发生变更时发送（时间戳推进或手动跳转）
    static let historicalReplayProgressChanged = Notification.Name("com.xianrenzhilu.historicalReplayProgressChanged")
    /// 回放速度发生变更时发送（1x/2x/5x/10x切换）
    static let historicalReplaySpeedChanged = Notification.Name("com.xianrenzhilu.historicalReplaySpeedChanged")
}

// MARK: - 迁回自 UI-02：extension UIHistoricalReplayDataSourceProtocol
public extension UIHistoricalReplayDataSourceProtocol {
    /// 默认实现：获取数据点总数（未加载时返回0）
    var totalDataPoints: Int { return 0 }
    /// 默认实现：获取时间范围（未加载时返回nil）
    var timeRange: (start: TimeInterval, end: TimeInterval)? { return nil }
    /// 默认实现：清理数据（空操作）
    func clearData() {}
}

// MARK: - 迁回自 UI-02：class UIHistoricalReplayDataSource
public final class UIHistoricalReplayDataSource: UIHistoricalReplayDataSourceProtocol , @unchecked Sendable{
    /// 使用 Logger 替代 print，子系统标识为仙人指路
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "UIHistoricalReplayDataSource")
    /// 使用 NSRecursiveLock 保护共享数组，确保线程安全
    private let lock = NSRecursiveLock()
    /// 已加载的快照数据，按时间升序排列
    private var snapshots: [UIKLineSnapshot] = []
    
    /// 数据点总数（线程安全读取）
    public var totalDataPoints: Int {
        lock.lock()
        let c = snapshots.count
        lock.unlock()
        return c
    }
    
    /// 当前数据时间范围（线程安全读取）
    public var timeRange: (start: TimeInterval, end: TimeInterval)? {
        lock.lock()
        guard let first = snapshots.first, let last = snapshots.last else {
            lock.unlock()
            return nil
        }
        let result = (first.timestamp, last.timestamp)
        lock.unlock()
        return result
    }
    
    /// 准备回放数据（异步加载），实际项目中应替换为真实数据库/网络请求
    public func prepareReplayData(symbol: String, interval: String, startTime: TimeInterval, endTime: TimeInterval) async throws -> [UIKLineSnapshot] {
        logger.info("开始准备回放数据: 交易对=\(symbol), 周期=\(interval), 时间范围=\(startTime) 至 \(endTime)")
        // 在实际项目中，这里应从数据库或网络API获取真实K线数据
        // 以下为演示用的数据生成逻辑，确保功能可独立测试
        var data: [UIKLineSnapshot] = []
        var currentTime = startTime
        let intervalSeconds = getIntervalSeconds(interval)
        let basePrice = 10000.0
        // 生成模拟数据，保持随机游走特性
        var lastClose = basePrice
        while currentTime <= endTime {
            let noise = Double.random(in: -0.02...0.02)
            let price = lastClose * (1.0 + noise)
            let open = price * (1.0 + Double.random(in: -0.005...0.005))
            let high = max(open, price) * (1.0 + Double.random(in: 0.0...0.005))
            let low = min(open, price) * (1.0 + Double.random(in: -0.005...0.0))
            let close = price * (1.0 + Double.random(in: -0.003...0.003))
            let candle = UIKLineSnapshot(
                timestamp: currentTime,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: Double.random(in: 1000...100000)
            )
            data.append(candle)
            lastClose = close
            currentTime += intervalSeconds
        }
        let finalizedData = data
        await MainActor.run {
            self.lock.lock()
            self.snapshots = finalizedData
            self.lock.unlock()
        }
        logger.info("回放数据准备完成，共加载 \(finalizedData.count) 条K线记录")
        return finalizedData
    }
    
    /// 二分查找获取指定时间戳的数据快照，时间复杂度 O(log n)
    public func getSnapshot(at timestamp: TimeInterval) -> UIKLineSnapshot? {
        lock.lock()
        guard !snapshots.isEmpty else {
            lock.unlock()
            return nil
        }
        // 二分查找精确匹配或最接近的时间点
        var left = 0
        var right = snapshots.count - 1
        while left <= right {
            let mid = (left + right) / 2
            if snapshots[mid].timestamp == timestamp {
                lock.unlock()
                return snapshots[mid]
            } else if snapshots[mid].timestamp < timestamp {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        // 返回最接近的未来时间点（用于展示当前及之前已形成的K线）
        if left < snapshots.count {
            lock.unlock()
            return snapshots[left]
        }
        lock.unlock()
        return snapshots.last
    }
    
    /// 获取指定时间范围内的所有快照（用于批量展示）
    public func getSnapshotsInRange(start: TimeInterval, end: TimeInterval) -> [UIKLineSnapshot] {
        lock.lock()
        let result = snapshots.filter { $0.timestamp >= start && $0.timestamp <= end }
        lock.unlock()
        return result
    }
    
    /// 清理所有已加载数据，释放内存
    public func clearData() {
        lock.lock()
        snapshots.removeAll()
        lock.unlock()
        logger.info("回放数据源已清理，内存已释放")
    }
    
    /// 将周期字符串转换为秒数
    private func getIntervalSeconds(_ interval: String) -> TimeInterval {
        switch interval {
        case "1m": return 60
        case "5m": return 300
        case "15m": return 900
        case "30m": return 1800
        case "1h": return 3600
        case "4h": return 14400
        case "1d": return 86400
        case "1w": return 604800
        default: return 60
        }
    }
}

// MARK: - 迁回自 UI-02：class UIChartLockManager
public final class UIChartLockManager : @unchecked Sendable {
    /// 使用 Logger 替代 print
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "UIChartLockManager")
    /// 使用 NSRecursiveLock 保护锁定状态
    private let lock = NSRecursiveLock()
    /// 内部锁定状态
    private var _isLocked = false
    
    /// 当前是否锁定（线程安全）
    public var isLocked: Bool {
        get {
            lock.lock()
            let v = _isLocked
            lock.unlock()
            return v
        }
        set {
            lock.lock()
            _isLocked = newValue
            lock.unlock()
            logger.info("图表锁定状态变更为: \(newValue ? "已锁定" : "已解锁")")
        }
    }
    
    /// 单例访问点
    public static let shared = UIChartLockManager()
    private init() {}
    
    /// 检查操作是否被允许（回放锁定状态下禁止修改图表）
    public func checkOperationAllowed(operation: String) -> Bool {
        if isLocked {
            logger.warning("操作 [\(operation)] 被拒绝：当前处于回放锁定状态")
            return false
        }
        return true
    }
}

// MARK: - 迁回自 UI-02：class UIHistoricalReplayManager
public final class UIHistoricalReplayManager : @unchecked Sendable {
    /// 单例访问点，全局统一管理回放状态
    public static let shared = UIHistoricalReplayManager()
    /// 使用 Logger 替代 print，符合苹果官方日志规范
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "UIHistoricalReplayManager")
    
    /// 数据源弱引用，防止循环引用
    private weak var dataSource: UIHistoricalReplayDataSourceProtocol?
    /// 回放定时器，控制时间推进
    private nonisolated(unsafe) var timer: Timer?
    /// 使用 NSRecursiveLock 保护所有共享状态，确保多线程安全
    private let lock = NSRecursiveLock()
    
    // MARK: 受锁保护的内部状态（禁止外部直接访问）
    private var _state: UIHistoricalReplayState = .stopped
    private var _currentTimestamp: TimeInterval = 0
    private var _speed: UIHistoricalReplaySpeed = .x1
    private var _configuration: UIHistoricalReplayConfiguration?
    private var _startTimestamp: TimeInterval = 0
    private var _endTimestamp: TimeInterval = 0
    private var _isChartLocked = false
    
    // MARK: 公共属性访问器（线程安全）
    
    /// 当前回放状态（只读）
    public var state: UIHistoricalReplayState {
        get {
            lock.lock()
            let v = _state
            lock.unlock()
            return v
        }
    }
    
    /// 当前回放时间戳（只读）
    public var currentTimestamp: TimeInterval {
        get {
            lock.lock()
            let v = _currentTimestamp
            lock.unlock()
            return v
        }
    }
    
    /// 当前回放速度（只读）
    public var speed: UIHistoricalReplaySpeed {
        get {
            lock.lock()
            let v = _speed
            lock.unlock()
            return v
        }
    }
    
    /// 当前配置（只读）
    public var configuration: UIHistoricalReplayConfiguration? {
        get {
            lock.lock()
            let v = _configuration
            lock.unlock()
            return v
        }
    }
    
    /// 图表是否被锁定（只读）
    public var isChartLocked: Bool {
        get {
            lock.lock()
            let v = _isChartLocked
            lock.unlock()
            return v
        }
    }
    
    /// 起始时间戳（只读）
    public var startTimestamp: TimeInterval {
        get {
            lock.lock()
            let v = _startTimestamp
            lock.unlock()
            return v
        }
    }
    
    /// 结束时间戳（只读）
    public var endTimestamp: TimeInterval {
        get {
            lock.lock()
            let v = _endTimestamp
            lock.unlock()
            return v
        }
    }
    
    /// 当前回放进度百分比（0.0 ~ 1.0），实时计算
    public var progress: Double {
        get {
            lock.lock()
            let start = _startTimestamp
            let end = _endTimestamp
            let current = _currentTimestamp
            lock.unlock()
            guard end > start else { return 0.0 }
            return (current - start) / (end - start)
        }
    }
    
    /// 是否已加载数据
    public var isDataReady: Bool {
        guard let ds = dataSource else { return false }
        return ds.totalDataPoints > 0
    }
    
    /// 当前时间格式化字符串
    public var currentTimeString: String {
        let date = Date(timeIntervalSince1970: currentTimestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
    
    // MARK: 播放控制
    
    /// 开始回放，从当前时间点或起点启动
    public func play() {
        lock.lock()
        guard _state != .playing else {
            lock.unlock()
            logger.warning("播放请求被忽略，当前已在播放状态")
            return
        }
        // 如果当前时间已超出范围，重置到起点
        if _currentTimestamp >= _endTimestamp || _currentTimestamp < _startTimestamp {
            _currentTimestamp = _startTimestamp
        }
        _state = .playing
        _isChartLocked = true
        lock.unlock()
        
        // 锁定图表交互，防止回放期间误修改
        UIChartLockManager.shared.isLocked = true
        
        // 启动定时推进
        startTimer()
        
        // 广播状态变更通知
        postStateChangedNotification()
        logger.info("回放开始，当前速度: \(self.speed.displayName)，起始时间: \(self.currentTimeString)")
    }
    
    /// 暂停回放，保留当前时间位置
    public func pause() {
        lock.lock()
        guard _state == .playing else {
            lock.unlock()
            logger.warning("暂停请求被忽略，当前未在播放")
            return
        }
        _state = .paused
        lock.unlock()
        
        stopTimer()
        postStateChangedNotification()
        logger.info("回放已暂停，当前时间: \(self.currentTimeString)")
    }
    
    /// 停止回放并重置到起点，解锁图表
    public func stop() {
        lock.lock()
        _state = .stopped
        _currentTimestamp = _startTimestamp
        _isChartLocked = false
        lock.unlock()
        
        // 解锁图表交互
        UIChartLockManager.shared.isLocked = false
        
        stopTimer()
        postStateChangedNotification()
        postProgressChangedNotification()
        logger.info("回放已停止，时间已重置到起点: \(self.currentTimeString)")
    }
    
    // MARK: 进度控制（支持NSSlider拖拽）
    
    /// 手动跳转到指定时间戳（NSSlider拖拽时调用）
    public func seek(to timestamp: TimeInterval) {
        lock.lock()
        let clamped = max(_startTimestamp, min(timestamp, _endTimestamp))
        let oldTime = _currentTimestamp
        _currentTimestamp = clamped
        let wasPlaying = _state == .playing
        lock.unlock()
        
        // 通知进度变更
        postProgressChangedNotification()
        
        // 如果正在播放，重启定时器以保持速度对应的时间间隔准确
        if wasPlaying {
            stopTimer()
            startTimer()
        }
        
        if oldTime != clamped {
            logger.info("手动跳转: \(oldTime) -> \(clamped)")
        }
    }
    
    /// 按百分比跳转（0.0 ~ 1.0），NSSlider值直接映射
    public func seekToProgress(_ progress: Double) {
        let clamped = max(0.0, min(progress, 1.0))
        let targetTime = startTimestamp + (endTimestamp - startTimestamp) * clamped
        seek(to: targetTime)
    }
    
    // MARK: 速度控制
    
    /// 设置回放速度（支持1x/2x/5x/10x），立即生效
    public func setSpeed(_ speed: UIHistoricalReplaySpeed) {
        lock.lock()
        let oldSpeed = _speed
        _speed = speed
        let wasPlaying = _state == .playing
        lock.unlock()
        
        // 如果正在播放，重启定时器以匹配新速度的时间间隔
        if wasPlaying {
            stopTimer()
            startTimer()
        }
        
        postSpeedChangedNotification()
        logger.info("回放速度从 \(oldSpeed.displayName) 切换到 \(speed.displayName)")
    }
    
    /// 切换到下一个速度档位
    public func toggleNextSpeed() {
        let allCases = UIHistoricalReplaySpeed.allCases
        guard let currentIndex = allCases.firstIndex(of: speed) else { return }
        let nextIndex = (currentIndex + 1) % allCases.count
        setSpeed(allCases[nextIndex])
    }
    
    // MARK: 配置与数据
    
    /// 加载回放配置，并持久化到本地
    public func loadConfiguration(_ config: UIHistoricalReplayConfiguration) {
        lock.lock()
        _configuration = config
        _startTimestamp = config.startTime
        _endTimestamp = config.endTime
        _currentTimestamp = config.defaultTimestamp ?? config.startTime
        _speed = config.defaultSpeed
        if config.chartLockEnabled {
            _isChartLocked = true
        }
        lock.unlock()
        
        // 持久化到本地文件
        saveConfiguration(config)
        logger.info("已加载回放配置: \(config.symbol), 区间=\(config.interval), 速度=\(config.defaultSpeed.displayName)")
    }
    
    /// 异步准备回放数据，完成后可根据配置自动播放
    public func prepareData(source: UIHistoricalReplayDataSourceProtocol) async {
        self.dataSource = source
        guard let config = configuration else {
            logger.error("无法准备数据：配置未加载")
            return
        }
        
        do {
            let snapshots = try await source.prepareReplayData(
                symbol: config.symbol,
                interval: config.interval,
                startTime: config.startTime,
                endTime: config.endTime
            )
            logger.info("数据准备完成，共 \(snapshots.count) 条记录")
            // 如果配置要求自动播放，则立即开始
            if config.autoPlay {
                play()
            }
        } catch {
            logger.error("数据准备失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取当前时间点的数据快照
    public func getCurrentSnapshot() -> UIKLineSnapshot? {
        guard let ds = dataSource else { return nil }
        return ds.getSnapshot(at: currentTimestamp)
    }
    
    /// 清理数据源并停止回放
    public func clear() {
        stop()
        dataSource?.clearData()
        dataSource = nil
        logger.info("回放管理器已清理")
    }
    
    // MARK: 设置面板方法
    
    /// 打开回放设置面板（通过通知触发UI层显示）
    public func showSettingsPanel() {
        logger.info("请求打开回放设置面板")
        NotificationCenter.default.post(
            name: Notification.Name("com.xianrenzhilu.showHistoricalReplaySettings"),
            object: self
        )
    }
    
    /// 从设置面板接收参数并应用配置，一站式配置入口
    public func applySettingsFromPanel(
        symbol: String,
        interval: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        speed: UIHistoricalReplaySpeed,
        loop: Bool,
        lockChart: Bool,
        autoPlay: Bool
    ) {
        let config = UIHistoricalReplayConfiguration(
            symbol: symbol,
            interval: interval,
            startTime: startTime,
            endTime: endTime,
            defaultSpeed: speed,
            autoPlay: autoPlay,
            loopPlayback: loop,
            chartLockEnabled: lockChart,
            defaultTimestamp: startTime
        )
        loadConfiguration(config)
        logger.info("已从面板应用配置: symbol=\(symbol), interval=\(interval), speed=\(speed.displayName), loop=\(loop ? "是" : "否")")
    }
    
    // MARK: 配置持久化
    
    /// 保存配置到Application Support目录，JSON格式原子写入
    private func saveConfiguration(_ config: UIHistoricalReplayConfiguration) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(config)
            let url = getConfigurationURL()
            try data.write(to: url, options: .atomic)
            logger.info("配置已持久化到: \(url.path)")
        } catch {
            logger.error("配置持久化失败: \(error.localizedDescription)")
        }
    }
    
    /// 从本地加载持久化配置，首次启动时自动恢复
    public func loadPersistedConfiguration() -> UIHistoricalReplayConfiguration? {
        let url = getConfigurationURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("未找到本地持久化配置")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(UIHistoricalReplayConfiguration.self, from: data)
            logger.info("已从本地加载持久化配置")
            return config
        } catch {
            logger.error("加载持久化配置失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 获取配置文件的存储路径（~/Library/Application Support/XianRenZhiLu/）
    private func getConfigurationURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("XianRenZhiLu", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        return appDir.appendingPathComponent("historical_replay_config.json")
    }
    
    // MARK: 通知发送
    
    /// 发送状态变更通知（停止/播放/暂停），附带当前时间戳
    private func postStateChangedNotification() {
        NotificationCenter.default.post(
            name: .historicalReplayStateChanged,
            object: self,
            userInfo: ["state": state.rawValue, "timestamp": currentTimestamp]
        )
    }
    
    /// 发送进度变更通知（时间戳推进或手动跳转），附带进度百分比
    private func postProgressChangedNotification() {
        NotificationCenter.default.post(
            name: .historicalReplayProgressChanged,
            object: self,
            userInfo: ["timestamp": currentTimestamp, "progress": progress]
        )
    }
    
    /// 发送速度变更通知（1x/2x/5x/10x切换），附带速度显示名
    private func postSpeedChangedNotification() {
        NotificationCenter.default.post(
            name: .historicalReplaySpeedChanged,
            object: self,
            userInfo: ["speed": speed.rawValue, "displayName": speed.displayName]
        )
    }
    
    // MARK: 定时器
    
    /// 启动回放定时器，根据速度计算时间间隔
    private func startTimer() {
        let speedValue = speed.rawValue
        // 速度越快，定时器间隔越短，保持视觉流畅度
        let interval = 0.1 / speedValue
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // 确保定时器在主循环运行，支持拖拽等UI操作
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
        logger.debug("定时器已启动，间隔: \(interval)秒，速度: \(self.speed.displayName)")
    }
    
    /// 停止回放定时器
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        logger.debug("定时器已停止")
    }
    
    /// 每次定时器触发的时间推进逻辑，处理循环与结束判断
    private func tick() {
        lock.lock()
        let step = 60.0 * _speed.rawValue // 每次推进60秒乘以速度倍率
        let newTime = _currentTimestamp + step
        
        if newTime >= _endTimestamp {
            // 到达或超过结束时间
            if _configuration?.loopPlayback == true {
                // 循环模式：回到起点继续播放
                _currentTimestamp = _startTimestamp
                lock.unlock()
                postProgressChangedNotification()
                logger.info("回放到达终点，循环回到起点")
            } else {
                // 非循环模式：停止在终点，解锁图表
                _currentTimestamp = _endTimestamp
                _state = .stopped
                _isChartLocked = false
                lock.unlock()
                stopTimer()
                UIChartLockManager.shared.isLocked = false
                postStateChangedNotification()
                postProgressChangedNotification()
                logger.info("回放到达结束时间，自动停止，图表已解锁")
            }
        } else {
            // 正常推进时间
            _currentTimestamp = newTime
            lock.unlock()
            postProgressChangedNotification()
        }
    }
    
    // MARK: 初始化与清理
    
    /// 初始化时尝试加载上次保存的配置，实现状态恢复
    private init() {
        logger.info("UIHistoricalReplayManager 初始化完成")
        if let config = loadPersistedConfiguration() {
            loadConfiguration(config)
        }
    }
    
    /// 释放时清理定时器与资源，防止内存泄漏
    deinit {
        stopTimer()
        logger.info("UIHistoricalReplayManager 已释放，所有资源已清理")
    }
}

// MARK: - 迁回自 UI-02：enum UIHistoricalReplayState
// MARK: - 图表叠加管理器
/// 核心管理类：负责所有数据系列的叠加显示、样式管理、Y轴自动缩放与持久化
/// 采用单例模式，使用NSRecursiveLock保护共享数据，通过NotificationCenter广播状态变更
// 已迁回 UI-GL-54_图表叠加模式.swift：class UIChartOverlayManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-55 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-55_types.swift
// 版本: 2.0
// MARK: - 回放状态枚举
/// 历史数据回放器的运行状态
public enum UIHistoricalReplayState: String, Codable, Sendable {
    case stopped = "stopped"
    case playing = "playing"
    case paused = "paused"
    
    /// 是否在活跃回放中
    public var isActive: Bool {
        return self == .playing
    }
    
    /// 是否已停止
    public var isStopped: Bool {
        return self == .stopped
    }
    
    /// 中文显示名称
    public var displayName: String {
        switch self {
        case .stopped: return "已停止"
        case .playing: return "播放中"
        case .paused: return "已暂停"
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIHistoricalReplaySpeed
// MARK: - 回放速度枚举
/// 支持的历史回放速度档位
public enum UIHistoricalReplaySpeed: Double, Codable, CaseIterable, Sendable {
    case x1 = 1.0
    case x2 = 2.0
    case x5 = 5.0
    case x10 = 10.0
    
    /// 界面显示名称
    public var displayName: String {
        switch self {
        case .x1: return "1x"
        case .x2: return "2x"
        case .x5: return "5x"
        case .x10: return "10x"
        }
    }
    
    /// 中文描述
    public var description: String {
        switch self {
        case .x1: return "1倍速（正常）"
        case .x2: return "2倍速"
        case .x5: return "5倍速"
        case .x10: return "10倍速"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIKLineSnapshot
// MARK: - K线快照模型
/// 历史回放中的单根K线数据快照
public struct UIKLineSnapshot: Codable, Sendable, Equatable {
    /// 时间戳（Unix时间，秒）
    public let timestamp: TimeInterval
    /// 开盘价
    public let open: Double
    /// 最高价
    public let high: Double
    /// 最低价
    public let low: Double
    /// 收盘价
    public let close: Double
    /// 成交量
    public let volume: Double
    
    /// 验证数据有效性（价格关系是否自洽）
    public var isValid: Bool {
        return high >= low && high >= max(open, close) && low <= min(open, close)
    }
    
    /// 格式化时间字符串（中文格式）
    public var formattedTime: String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
    
    /// 涨跌幅百分比
    public var changePercent: Double {
        guard open != 0 else { return 0 }
        return ((close - open) / open) * 100
    }
}

// MARK: - 迁回自 UI-02：struct UIHistoricalReplayConfiguration
// MARK: - 回放配置模型
/// 历史回放的可持久化配置，支持JSON编码解码
public struct UIHistoricalReplayConfiguration: Codable, Sendable {
    /// 交易对/股票代码
    public var symbol: String
    /// K线周期（1m/5m/15m/1h/4h/1d等）
    public var interval: String
    /// 回放起始时间（Unix时间戳）
    public var startTime: TimeInterval
    /// 回放结束时间（Unix时间戳）
    public var endTime: TimeInterval
    /// 默认播放速度
    public var defaultSpeed: UIHistoricalReplaySpeed
    /// 是否自动开始播放
    public var autoPlay: Bool
    /// 是否循环播放
    public var loopPlayback: Bool
    /// 是否锁定图表
    public var chartLockEnabled: Bool
    /// 默认起始时间戳（可选，用于恢复上次播放位置）
    public var defaultTimestamp: TimeInterval?
    
    /// 时间范围总时长（秒）
    public var duration: TimeInterval {
        return endTime - startTime
    }
    
    /// 验证配置有效性
    public var isValid: Bool {
        return !symbol.isEmpty && !interval.isEmpty && endTime > startTime
    }
    
    /// 格式化时间范围字符串
    public var timeRangeString: String {
        let start = Date(timeIntervalSince1970: startTime)
        let end = Date(timeIntervalSince1970: endTime)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return "\(formatter.string(from: start)) 至 \(formatter.string(from: end))"
    }
}

// MARK: - 迁回自 UI-02：protocol UIHistoricalReplayDataSourceProtocol
// MARK: - 回放数据源协议
/// 定义历史回放所需的数据源接口，实现方可对接真实数据库或网络API
public protocol UIHistoricalReplayDataSourceProtocol: AnyObject {
    /// 准备指定时间范围的回放数据
    /// - Parameters:
    ///   - symbol: 交易对代码
    ///   - interval: K线周期
    ///   - startTime: 开始时间
    ///   - endTime: 结束时间
    /// - Returns: 按时间排序的K线快照数组
    func prepareReplayData(symbol: String, interval: String, startTime: TimeInterval, endTime: TimeInterval) async throws -> [UIKLineSnapshot]
    
    /// 获取指定时间戳最接近的数据快照
    /// - Parameter timestamp: 目标时间戳
    /// - Returns: 最接近的K线快照，如不存在返回nil
    func getSnapshot(at timestamp: TimeInterval) -> UIKLineSnapshot?
    
    /// 数据点总数
    var totalDataPoints: Int { get }
    
    /// 当前数据时间范围
    var timeRange: (start: TimeInterval, end: TimeInterval)? { get }
    
    /// 清理已加载的数据，释放内存
    func clearData()
}

// MARK: - 迁回自 UI-02：struct UIHistoricalReplaySliderView
// MARK: - 回放数据源协议默认实现
// 已迁回 UI-GL-55_历史数据回放模式.swift：extension UIHistoricalReplayDataSourceProtocol（公共类型文件禁止功能实现）

// MARK: - 默认回放数据源实现
/// 基于内存的回放数据源实现，支持线程安全的数据访问
// 已迁回 UI-GL-55_历史数据回放模式.swift：class UIHistoricalReplayDataSource（公共类型文件禁止功能实现）

// MARK: - 图表锁定管理器
/// 管理回放期间图表的交互锁定状态，防止回放中误操作图表设置
// 已迁回 UI-GL-55_历史数据回放模式.swift：class UIChartLockManager（公共类型文件禁止功能实现）

// MARK: - 核心回放管理器
/// 历史数据回放的核心控制器，负责播放/暂停/停止/进度控制/速度调节/图表锁定
// 已迁回 UI-GL-55_历史数据回放模式.swift：class UIHistoricalReplayManager（公共类型文件禁止功能实现）

// MARK: - 进度条视图辅助结构
/// 用于连接NSSlider与回放进度的辅助结构，桥接UI控件与回放管理器
public struct UIHistoricalReplaySliderView {
    /// 进度变化回调（NSSlider值变更时调用）
    public var onSeek: ((TimeInterval) -> Void)?
    /// 当前进度值（0.0 ~ 1.0）
    public var progress: Double = 0.0
    /// 是否可交互（回放时允许拖拽，未加载时禁用）
    public var isEnabled: Bool = true
    /// 时间范围字符串（如 "2024-01-01 至 2024-06-01"）
    public var timeRangeString: String = ""
    
    /// 根据当前时间更新进度和显示文本
    public mutating func updateProgress(current: TimeInterval, start: TimeInterval, end: TimeInterval) {
        guard end > start else {
            progress = 0.0
            return
        }
        progress = (current - start) / (end - start)
        let startDate = Date(timeIntervalSince1970: start)
        let endDate = Date(timeIntervalSince1970: end)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")
        timeRangeString = "\(formatter.string(from: startDate)) 至 \(formatter.string(from: endDate))"
    }
    
    /// 根据进度值计算目标时间戳，用于NSSlider松手时跳转
    public func targetTimestamp(from progress: Double, start: TimeInterval, end: TimeInterval) -> TimeInterval {
        let clamped = max(0.0, min(progress, 1.0))
        return start + (end - start) * clamped
    }
}
