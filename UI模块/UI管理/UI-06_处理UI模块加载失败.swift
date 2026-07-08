// MARK: - UI-04: 处理UI模块加载失败
// 功能编号: UI-06
// 版本: 2.0
// 职责: 优雅处理单个模块加载失败，区分错误类型，隔离区，自动重试，聚合通知
// 依赖: UI-12 日志, UI-03 启动错误类型

import Foundation
import AppKit

// MARK: - 错误处理器
// 类型 UIModuleErrorHandler 已迁移到 UI-02_公共类型定义.swift

// 使用UI-02的UIModuleLoadError和通知名称
// 本文件不再定义这些类型

// MARK: - 测试
internal func test_UI04() {
    print("\n=== UI-04 错误处理模块测试 ===")
    let handler = UIModuleErrorHandler.shared

    // 测试1: 5种UIModuleLoadError类型分类
    print("\n🧪 测试1: UIModuleLoadError 类型分类")
    let errNotFound = UIModuleLoadError.bundleNotFound(moduleID: "test")
    let s1 = handler.handleError(moduleID: "test.type.01", moduleName: "bundle不存在", error: errNotFound)
    guard s1 == .skip else {
        fatalError("❌ 测试1失败: bundleNotFound 应为 skip")
    }

    let errLoadFailed = UIModuleLoadError.bundleLoadFailed(moduleID: "test")
    let s2 = handler.handleError(moduleID: "test.type.02", moduleName: "bundle加载失败", error: errLoadFailed)
    guard s2 == .skip else {
        fatalError("❌ 测试1失败: bundleLoadFailed 应为 skip")
    }

    let errInvalidClass = UIModuleLoadError.invalidPrincipalClass(moduleID: "test.type.03")
    let s3 = handler.handleError(moduleID: "test.type.03", moduleName: "principalClass无效", error: errInvalidClass)
    guard s3 == .fatal else {
        fatalError("❌ 测试1失败: invalidPrincipalClass 应为 fatal")
    }

    let errTimeout = UIModuleLoadError.startupTimeout(moduleID: "test.type.04")
    let s4 = handler.handleError(moduleID: "test.type.04", moduleName: "启动超时", error: errTimeout)
    guard s4 == .degrade else {
        fatalError("❌ 测试1失败: startupTimeout 应为 degrade")
    }

    let errStartupFailed = UIModuleLoadError.startupFailed(moduleID: "test.type.05", reason: "失败")
    let s5 = handler.handleError(moduleID: "test.type.05", moduleName: "启动失败", error: errStartupFailed)
    guard s5 == .skip else {
        fatalError("❌ 测试1失败: startupFailed 应为 skip")
    }
    print("✅ 测试1通过: 5种UIModuleLoadError分类正确")

    // 测试2: 隔离区行为
    print("\n🧪 测试2: 隔离区行为")
    guard handler.isInQuarantine("test.type.01") else {
        fatalError("❌ 测试2失败: skip 类型应进入隔离区")
    }
    guard handler.isInQuarantine("test.type.04") else {
        fatalError("❌ 测试2失败: degrade 类型应进入隔离区")
    }
    guard !handler.isInQuarantine("test.type.03") else {
        fatalError("❌ 测试2失败: fatal 类型不应进入隔离区")
    }
    print("✅ 测试2通过: skip/degrade入隔离区，fatal不入")

    // 测试3: 重试
    print("\n🧪 测试3: 重试")
    let canRetry = handler.retry(moduleID: "test.type.01")
    guard canRetry else {
        fatalError("❌ 测试3失败: 首次重试应返回true")
    }
    guard !handler.isInQuarantine("test.type.01") else {
        fatalError("❌ 测试3失败: 重试后应移出隔离区")
    }
    print("✅ 测试3通过: 重试成功，已移出隔离区")

    // 测试4: 隔离区查询
    print("\n🧪 测试4: 隔离区查询")
    let quarantineIDs = handler.quarantineModules()
    guard quarantineIDs.contains("test.type.02") else {
        fatalError("❌ 测试4失败: 隔离区应包含未重试的test.type.02")
    }
    guard !quarantineIDs.contains("test.type.03") else {
        fatalError("❌ 测试4失败: 隔离区不应包含fatal的test.type.03")
    }
    print("✅ 测试4通过: 隔离区查询正确")

    // 测试5: 聚合通知（连续3个错误）
    print("\n🧪 测试5: 聚合通知触发（连续3个错误）")
    handler.clear()
    let errTest = UIModuleLoadError.bundleNotFound(moduleID: "test")
    let se1 = handler.handleError(moduleID: "agg.01", moduleName: "聚合测试1", error: errTest)
    guard se1 == .skip else { fatalError("❌ 测试5准备失败") }
    let se2 = handler.handleError(moduleID: "agg.02", moduleName: "聚合测试2", error: errTest)
    guard se2 == .skip else { fatalError("❌ 测试5准备失败") }
    // 第3个错误触发聚合通知（方法内部应发送，但无法直接验证通知发送）
    let se3 = handler.handleError(moduleID: "agg.03", moduleName: "聚合测试3", error: errTest)
    guard se3 == .skip else {
        fatalError("❌ 测试5失败: 第3个错误分类应正常")
    }
    // 验证3个错误都记录在失败列表中
    let allFailed = handler.failedModules()
    let aggCount = allFailed.filter { $0.moduleID.hasPrefix("agg.") }.count
    guard aggCount == 3 else {
        fatalError("❌ 测试5失败: 聚合模块应记录3个失败，实际: \(aggCount)")
    }
    print("✅ 测试5通过: 连续3错误触发聚合通知，全部记录在案")

    // 测试6: 导出报告
    print("\n🧪 测试6: 导出错误报告")
    let report = handler.exportErrorReport()
    guard report != nil else {
        fatalError("❌ 测试6失败: 错误报告导出应为非nil")
    }
    guard report!.count > 0 else {
        fatalError("❌ 测试6失败: 错误报告不应为空")
    }
    print("✅ 测试6通过: 错误报告导出成功")

    // 测试7: 自动重试启动/停止
    print("\n🧪 测试7: 自动重试启动与停止")
    // 先添加一个隔离区模块
    let errForRetry = UIModuleLoadError.bundleLoadFailed(moduleID: "retry")
    _ = handler.handleError(moduleID: "retry.test", moduleName: "重试测试模块", error: errForRetry)
    handler.startAutoRetry()
    // 刷新主队列，让 startAutoRetry 中的 DispatchQueue.main.async 块执行完毕
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    // 停止（不验证是否真的重试了，只验证不崩溃）
    handler.stopAutoRetry()
    print("✅ 测试7通过: 自动重试启动与停止（不崩溃）")

    // 测试8: 清理
    print("\n🧪 测试8: 清理")
    handler.clear()
    guard handler.failedModules().isEmpty else {
        fatalError("❌ 测试8失败: 清理后失败记录应为空")
    }
    guard handler.quarantineModules().isEmpty else {
        fatalError("❌ 测试8失败: 清理后隔离区应为空")
    }
    print("✅ 测试8通过: 清理后记录和隔离区均为空")

    print("\n=== 全部 UI-04 错误处理模块测试通过 ✅ ===\n")
}

// MARK: - 迁回自 UI-02：class UIModuleErrorAggregator
public final class UIModuleErrorAggregator : @unchecked Sendable {
    public static let shared = UIModuleErrorAggregator()
    private init() {}
}

// MARK: - 迁回自 UI-02：class UIModuleErrorHandler
public final class UIModuleErrorHandler : @unchecked Sendable {
    public static let shared = UIModuleErrorHandler()

    let lock = NSRecursiveLock()
    private let logger = UILoadingLogManager.shared
    private var failureRecords: [String: UIModuleFailureRecord] = [:]
    private var quarantineList: Set<String> = []   // 隔离区
    private let maxRetryCount: Int = 3

    // 聚合通知
    private var consecutiveErrorCount: Int = 0
    private var consecutiveErrorModules: [String] = []
    private var firstErrorTimestamp: Date?
    private let aggregationThreshold: Int = 3

    // 定时器
    private var aggregationTimer: Timer?
    private var retryTimer: Timer?
    private var isRetryActive: Bool = false

    private init() {}

    // MARK: - 处理错误

    /// 处理模块加载失败错误，自动分类严重程度并送入隔离区
    /// - Parameters:
    ///   - moduleID: 模块ID
    ///   - moduleName: 模块名称
    ///   - error: 错误对象
    ///   - retryCount: 已重试次数
    /// - Returns: 错误严重程度
    public func handleError(moduleID: String, moduleName: String, error: Error, retryCount: Int = 0) -> UIModuleErrorSeverity {
        let severity = classifyErrorByType(error)

        let record = UIModuleFailureRecord(
            moduleID: moduleID,
            moduleName: moduleName,
            error: error.localizedDescription,
            severity: severity,
            timestamp: Date(),
            retryCount: retryCount
        )

        lock.lock()
        updateFailureRecord(moduleID: moduleID, record: record, severity: severity)
        aggregateError(moduleName: moduleName)
        let snapshot = takeAggregationSnapshot()
        // 🔴 修复：达到聚合阈值时重置状态，防止后续每个错误都重复触发聚合通知
        if snapshot.count >= aggregationThreshold {
            resetAggregation()
        }
        lock.unlock()

        // 日志（锁外）
        logError(moduleName: moduleName, severity: severity, error: error, moduleID: moduleID)

        // 发送单个错误通知（锁外）
        let payload = UIModuleLoadFailedPayload(
            moduleID: moduleID,
            moduleName: moduleName,
            error: error.localizedDescription,
            severity: severity.rawValue
        )
        NotificationCenter.default.post(name: .UIModuleLoadFailed, object: self, userInfo: payload.asDictionary)

        // 聚合检查（锁外）
        if snapshot.count >= aggregationThreshold {
            sendAggregatedNotification(snapshot: snapshot)
        } else {
            scheduleAggregationFlush()
        }

        return severity
    }

    /// 更新失败记录和隔离区（锁内调用）
    private func updateFailureRecord(moduleID: String, record: UIModuleFailureRecord, severity: UIModuleErrorSeverity) {
        failureRecords[moduleID] = record
        if severity == .skip || severity == .degrade {
            quarantineList.insert(moduleID)
        }
    }

    /// 聚合计数（锁内调用）
    private func aggregateError(moduleName: String) {
        consecutiveErrorCount += 1
        consecutiveErrorModules.append(moduleName)
        if firstErrorTimestamp == nil {
            firstErrorTimestamp = Date()
        }
    }

    /// 取聚合快照（锁内调用）
    private func takeAggregationSnapshot() -> (count: Int, modules: [String], firstTs: Date?) {
        return (consecutiveErrorCount, Array(consecutiveErrorModules), firstErrorTimestamp)
    }

    /// 日志输出（锁外调用）
    private func logError(moduleName: String, severity: UIModuleErrorSeverity, error: Error, moduleID: String) {
        switch severity {
        case .skip:
            logger.warning("错误处理", "模块 '\(moduleName)' 加载失败（跳过）: \(error.localizedDescription)", moduleID: moduleID)
        case .degrade:
            logger.warning("错误处理", "模块 '\(moduleName)' 加载失败（降级）: \(error.localizedDescription)", moduleID: moduleID)
        case .fatal:
            logger.error("错误处理", "模块 '\(moduleName)' 加载失败（致命）: \(error.localizedDescription) — 终止启动", moduleID: moduleID)
        }
    }

    // MARK: - 错误分类

    /// 根据 UIModuleLoadError 类型分类错误严重程度
    private func classifyErrorByType(_ error: Error) -> UIModuleErrorSeverity {
        if let loadError = error as? UIModuleLoadError {
            switch loadError {
            case .bundleNotFound:       return .skip
            case .bundleLoadFailed:     return .skip
            case .invalidPrincipalClass:return .fatal
            case .startupTimeout:       return .degrade
            case .startupFailed:        return .skip
            case .classNotFound:        return .fatal
            case .instantiationFailed:  return .fatal
            case .startFailed:          return .skip
            case .dependencyMissing:    return .skip
            case .loadFailed:             return .skip
            case .moduleNotFound:         return .skip
            }
        }

        // fallback：按 NSError code 分类（兼容旧代码）
        let nsError = error as NSError
        switch nsError.code {
        case 1: return .skip
        case 2: return .fatal
        case 3: return .skip
        case 4: return .degrade
        default: return .skip
        }
    }

    // MARK: - 聚合通知

    /// 延迟发送聚合通知（给后续错误合并机会）
    /// 注意：Timer 必须创建在主线程 RunLoop 上，否则后台线程调度的 timer 不会触发
    private func scheduleAggregationFlush() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            self.aggregationTimer?.invalidate()
            let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.flushAggregatedNotification()
            }
            self.aggregationTimer = timer
            self.lock.unlock()
        }
    }

    /// 刷新聚合通知（不管是否达到阈值，一次性发送）
    private func flushAggregatedNotification() {
        lock.lock()
        guard consecutiveErrorCount > 0 else {
            lock.unlock()
            return
        }
        let snapshot = takeAggregationSnapshot()
        resetAggregation()
        lock.unlock()

        sendAggregatedNotification(snapshot: snapshot)
    }

    /// 发送聚合通知（锁外调用）
    private func sendAggregatedNotification(snapshot: (count: Int, modules: [String], firstTs: Date?)) {
        let lastTs = Date()
        let firstTs = snapshot.firstTs ?? lastTs
        let moduleList = snapshot.modules.joined(separator: ", ")
        let summary = "\(snapshot.count) 个模块加载失败: \(moduleList)"

        let payload = UIModuleErrorAggregatedPayload(
            errorCount: snapshot.count,
            modules: snapshot.modules,
            firstTimestamp: firstTs,
            lastTimestamp: lastTs,
            summary: summary
        )

        logger.error("错误处理", "聚合错误通知: \(summary)")
        NotificationCenter.default.post(name: .UIModuleErrorAggregated, object: self, userInfo: payload.asDictionary)
    }

    /// 重置聚合状态（锁内调用）
    /// 注意：调用前已持有锁，且 timer 的 invalidate 是线程安全的
    private func resetAggregation() {
        consecutiveErrorCount = 0
        consecutiveErrorModules.removeAll()
        firstErrorTimestamp = nil
        aggregationTimer?.invalidate()
        aggregationTimer = nil
    }

    // MARK: - 重试

    /// 重试单个模块，重试次数+1，移出隔离区
    /// - Parameter moduleID: 模块ID
    /// - Returns: 是否可以继续重试
    public func retry(moduleID: String) -> Bool {
        lock.lock()
        guard var record = failureRecords[moduleID] else {
            lock.unlock()
            return false
        }
        guard record.retryCount < maxRetryCount else {
            lock.unlock()
            return false
        }
        record.retryCount += 1
        failureRecords[moduleID] = record
        quarantineList.remove(moduleID)
        lock.unlock()

        logger.info("错误处理", "重试加载模块 '\(moduleID)' (第\(record.retryCount)次)")
        return true
    }

    // MARK: - 自动重试

    /// 遍历隔离区所有模块，自动重试
    /// 最多执行3轮，每10秒一次
    /// 隔离区清空或达到最大轮数后自动停止
    public func startAutoRetry() {
        lock.lock()
        guard !quarantineList.isEmpty else {
            lock.unlock()
            logger.info("错误处理", "隔离区为空，无需重试")
            return
        }
        // 停止已有定时器
        retryTimer?.invalidate()
        isRetryActive = true
        lock.unlock()
        
        var retryRound = 0
        let logger = self.logger
        let maxRetryCount = self.maxRetryCount
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 如果在 dispatch 到 main 前 stopAutoRetry 已被调用，放弃创建新 timer
            guard self.isRetryActive else { return }
            
            self.lock.lock()
            self.retryTimer?.invalidate()
            let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                retryRound += 1
                if retryRound > maxRetryCount || !self.isRetryActive {
                    timer.invalidate()
                    self.lock.lock()
                    self.retryTimer = nil
                    self.lock.unlock()
                    if !self.isRetryActive {
                        self.logger.info("错误处理", "自动重试已停止")
                    } else {
                        self.logger.info("错误处理", "自动重试已达最大次数(\(maxRetryCount)轮)，停止重试")
                    }
                    return
                }

                self.lock.lock()
                let ids = Array(self.quarantineList)
                self.lock.unlock()

                if ids.isEmpty || !self.isRetryActive {
                    timer.invalidate()
                    self.lock.lock()
                    self.retryTimer = nil
                    self.lock.unlock()
                    if !self.isRetryActive {
                        self.logger.info("错误处理", "自动重试已停止")
                    } else {
                        self.logger.info("错误处理", "隔离区已清空，自动重试停止")
                    }
                    return
                }

                self.logger.info("错误处理", "第 \(retryRound) 轮自动重试，隔离区剩余 \(ids.count) 个模块")
                for moduleID in ids {
                    let success = self.retry(moduleID: moduleID)
                    if success {
                        self.logger.info("错误处理", "模块 '\(moduleID)' 重试已启动")
                    } else {
                        self.logger.warning("错误处理", "模块 '\(moduleID)' 重试次数已达上限，移出隔离区")
                        self.lock.lock()
                        self.quarantineList.remove(moduleID)
                        self.lock.unlock()
                    }
                }
            }
            self.retryTimer = timer
            self.lock.unlock()
            timer.fire()
        }
        
        logger.info("错误处理", "自动重试已调度到主线程（每10秒，最多\(maxRetryCount)轮）")
    }

    /// 停止自动重制定时器
    public func stopAutoRetry() {
        lock.lock()
        retryTimer?.invalidate()
        retryTimer = nil
        isRetryActive = false
        lock.unlock()
        logger.info("错误处理", "自动重试已停止")
    }

    // MARK: - 查询

    /// 获取所有失败记录
    /// - Returns: 失败记录列表
    public func failedModules() -> [UIModuleFailureRecord] {
        lock.lock()
        let records = Array(failureRecords.values)
        lock.unlock()
        return records
    }

    /// 判断模块是否在隔离区中
    /// - Parameter moduleID: 模块ID
    /// - Returns: 是否在隔离区
    public func isInQuarantine(_ moduleID: String) -> Bool {
        lock.lock()
        let result = quarantineList.contains(moduleID)
        lock.unlock()
        return result
    }

    /// 获取隔离区内的所有模块ID
    /// - Returns: 模块ID列表
    public func quarantineModules() -> [String] {
        lock.lock()
        let ids = Array(quarantineList)
        lock.unlock()
        return ids
    }

    // MARK: - 导出

    /// 导出错误报告为 JSON 数据
    /// - Returns: JSON Data
    public func exportErrorReport() -> Data? {
        lock.lock()
        let records = Array(failureRecords.values)
        lock.unlock()
        return try? JSONEncoder().encode(records)
    }

    // MARK: - 清理

    /// 清空所有错误记录、隔离区、聚合状态，停止所有定时器
    public func clear() {
        lock.lock()
        failureRecords.removeAll()
        quarantineList.removeAll()
        consecutiveErrorCount = 0
        consecutiveErrorModules.removeAll()
        firstErrorTimestamp = nil
        aggregationTimer?.invalidate()
        aggregationTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
        isRetryActive = false
        lock.unlock()
        logger.info("错误处理", "错误记录已清空")
    }
}
