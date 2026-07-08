// 功能30A: 脚本引擎
// 对应: 运行时脚本执行，支持AppleScript和JavaScript，提供扩展能力
// 优先级: P2

import AppKit
import Foundation
import JavaScriptCore
import os.log

// 类型定义已迁移至 UI-GL-37_types.swift

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能30A：脚本引擎 — 单元测试
/// 覆盖：脚本注册/权限/执行/配置/历史
func test_scriptEngine() {
    let engine = UIScriptEngine.shared
    
    print("\n🧪 测试1: 配置默认值")
    let config = engine.currentConfig
    guard config.appleScriptEnabled else {
        fatalError("❌ 测试1失败: AppleScript默认应启用")
    }
    print("✅ 测试1通过: 配置默认值正常")
    
    print("\n🧪 测试2: 注册脚本")
    let info = UIScriptInfo(name: "测试脚本", type: .javaScript, sourceCode: "1+1")
    let registered = engine.registerScript(info)
    guard registered else {
        fatalError("❌ 测试2失败: 注册应成功")
    }
    print("✅ 测试2通过: 脚本注册成功")
    
    print("\n🧪 测试3: 查询脚本")
    let found = engine.scriptByID(info.id)
    guard found?.name == "测试脚本" else {
        fatalError("❌ 测试3失败: 查询应找到脚本")
    }
    print("✅ 测试3通过: 脚本查询正确")
    
    print("\n🧪 测试4: 白名单")
    engine.setScriptWhitelisted(id: info.id, whitelisted: true)
    print("✅ 测试4通过: 白名单设置正常")
    
    print("\n🧪 测试5: 设置面板数据")
    let scripts = engine.allScriptsForSettings()
    guard !scripts.isEmpty else {
        fatalError("❌ 测试5失败: 设置面板应有脚本")
    }
    let history = engine.executionHistoryForSettings()
    _ = history.count
    let cfgs = engine.configForSettings()
    guard !cfgs.isEmpty else {
        fatalError("❌ 测试5失败: 配置项不应为空")
    }
    print("✅ 测试5通过: 设置面板数据正常")
    
    print("\n🧪 测试6: 所有脚本列表")
    let all = engine.allScripts
    guard !all.isEmpty else {
        fatalError("❌ 测试6失败: 脚本列表不应为空")
    }
    print("✅ 测试6通过: 脚本列表正常")
    
    print("\n=== 全部脚本引擎测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 脚本执行开始通知
    static let scriptExecutionDidStart = Notification.Name("com.xianrenzhilu.scriptExecutionDidStart")
    /// 脚本执行完成通知
    static let scriptExecutionDidComplete = Notification.Name("com.xianrenzhilu.scriptExecutionDidComplete")
    /// 脚本执行失败通知
    static let scriptExecutionDidFail = Notification.Name("com.xianrenzhilu.scriptExecutionDidFail")
    /// 脚本注册成功通知
    static let scriptDidRegister = Notification.Name("com.xianrenzhilu.scriptDidRegister")
}

// MARK: - 迁回自 UI-02：class UIScriptPermissionManager
public final class UIScriptPermissionManager : @unchecked Sendable {
    /// 共享日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu.script", category: "ScriptPermission")
    /// 互斥锁保护白名单数据
    private let lock = NSRecursiveLock()
    /// 白名单脚本ID集合
    private var whitelistedIDs: Set<String> = []
    /// 白名单脚本来源标识集合（如文件路径、签名等）
    private var trustedSources: Set<String> = []
    
    /// 初始化权限管理器
    public init() {
        logger.info("脚本权限管理器已初始化")
    }
    
    /// 将脚本ID加入白名单
    public func addToWhitelist(scriptID: String) {
        lock.lock()
        whitelistedIDs.insert(scriptID)
        lock.unlock()
        logger.info("脚本已加入白名单: \(scriptID)")
    }
    
    /// 从白名单移除脚本ID
    public func removeFromWhitelist(scriptID: String) {
        lock.lock()
        whitelistedIDs.remove(scriptID)
        lock.unlock()
        logger.info("脚本已从白名单移除: \(scriptID)")
    }
    
    /// 检查脚本ID是否在白名单中
    public func isWhitelisted(scriptID: String) -> Bool {
        lock.lock()
        let result = whitelistedIDs.contains(scriptID)
        lock.unlock()
        return result
    }
    
    /// 添加受信任来源
    public func addTrustedSource(_ source: String) {
        lock.lock()
        trustedSources.insert(source)
        lock.unlock()
    }
    
    /// 检查来源是否受信任
    public func isTrustedSource(_ source: String) -> Bool {
        lock.lock()
        let result = trustedSources.contains(source)
        lock.unlock()
        return result
    }
    
    /// 获取当前白名单数量
    public var whitelistCount: Int {
        lock.lock()
        let count = whitelistedIDs.count
        lock.unlock()
        return count
    }
    
    /// 清空白名单
    public func clearWhitelist() {
        lock.lock()
        whitelistedIDs.removeAll()
        trustedSources.removeAll()
        lock.unlock()
        logger.warning("白名单已清空")
    }
    
    /// 验证脚本执行权限（白名单模式）
    public func validateExecution(scriptID: String, whitelistModeEnabled: Bool) throws {
        if whitelistModeEnabled && !isWhitelisted(scriptID: scriptID) {
            logger.error("权限拒绝: 脚本 \(scriptID) 不在白名单中")
            throw UIScriptEngineError.permissionDenied(scriptID)
        }
    }
}

// MARK: - 迁回自 UI-02：class UIScriptEngine
public final class UIScriptEngine : @unchecked Sendable {
    /// 单例实例
    public static let shared = UIScriptEngine()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu.script", category: "ScriptEngine")
    
    /// 互斥锁保护所有共享数据
    private let lock = NSRecursiveLock()
    
    /// 脚本管理器：管理所有已注册脚本
    private var scriptManager = UIScriptManager()
    
    /// 权限管理器：控制白名单和权限
    private let permissionManager = UIScriptPermissionManager()
    
    /// 当前配置
    private var config: UIScriptEngineConfig = .default
    
    /// 执行历史记录
    private var executionHistory: [UIScriptExecutionRecord] = []
    
    /// JavaScript 执行上下文（懒加载）
    private lazy var jsContext: JSContext = {
        let context = JSContext()
        context?.exceptionHandler = { [weak self] _, exception in
            let msg = exception?.toString() ?? "未知JS错误"
            self?.logger.error("JavaScript异常: \(msg)")
        }
        return context ?? JSContext()
    }()
    
    /// 私有的初始化方法（单例模式）
    private init() {
        logger.info("脚本引擎已初始化")
        loadConfig()
    }
    
    /// 对象销毁时清理资源
    deinit {
        // 清理JS上下文
        jsContext.exceptionHandler = nil
        logger.info("脚本引擎已释放")
    }
    
    // MARK: - 配置管理
    
    /// 加载持久化配置
    private func loadConfig() {
        let url = configFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("未找到持久化配置，使用默认配置")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(UIScriptEngineConfig.self, from: data)
            lock.lock()
            config = decoded
            lock.unlock()
            logger.info("脚本引擎配置已加载")
        } catch {
            logger.error("加载配置失败: \(error.localizedDescription)")
        }
    }
    
    /// 保存配置到磁盘
    public func saveConfig() throws {
        lock.lock()
        let currentConfig = config
        lock.unlock()
        
        do {
            let data = try JSONEncoder().encode(currentConfig)
            try data.write(to: configFileURL)
            logger.info("脚本引擎配置已保存")
        } catch {
            logger.error("保存配置失败: \(error.localizedDescription)")
            throw UIScriptEngineError.persistenceFailed(error)
        }
    }
    
    /// 获取当前配置副本
    public var currentConfig: UIScriptEngineConfig {
        lock.lock()
        let cfg = config
        lock.unlock()
        return cfg
    }
    
    /// 更新配置
    public func updateConfig(_ newConfig: UIScriptEngineConfig) {
        lock.lock()
        config = newConfig
        lock.unlock()
        try? saveConfig()
        logger.info("脚本引擎配置已更新")
    }
    
    /// 配置文件存储路径
    private var configFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("XianRenZhiLu/ScriptEngine", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }
    
    // MARK: - 脚本注册与管理
    
    /// 注册一个脚本（如果ID已存在则更新）
    @discardableResult
    public func registerScript(_ info: UIScriptInfo) -> Bool {
        do {
            try scriptManager.saveScript(info)
            NotificationCenter.default.post(
                name: .scriptDidRegister,
                object: self,
                userInfo: ["scriptID": info.id, "scriptName": info.name]
            )
            logger.info("脚本已注册: \(info.name) (\(info.id))")
            return true
        } catch {
            logger.error("注册脚本失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 取消注册（删除）脚本
    public func unregisterScript(id: String) -> Bool {
        do {
            try scriptManager.deleteScript(id: id)
            logger.info("脚本已删除: \(id)")
            return true
        } catch {
            logger.error("删除脚本失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 获取所有已注册脚本
    public var allScripts: [UIScriptInfo] {
        return scriptManager.allScripts()
    }
    
    /// 根据ID查找脚本
    public func scriptByID(_ id: String) -> UIScriptInfo? {
        return scriptManager.scriptByID(id)
    }
    
    /// 根据标签筛选脚本
    public func scriptsByTag(_ tag: String) -> [UIScriptInfo] {
        return scriptManager.allScripts().filter { $0.tags.contains(tag) }
    }
    
    /// 设置脚本白名单状态
    public func setScriptWhitelisted(id: String, whitelisted: Bool) {
        if var script = scriptManager.scriptByID(id) {
            script.isWhitelisted = whitelisted
            if whitelisted {
                permissionManager.addToWhitelist(scriptID: id)
            } else {
                permissionManager.removeFromWhitelist(scriptID: id)
            }
            try? scriptManager.saveScript(script)
            logger.info("脚本 \(id) 白名单状态已设为 \(whitelisted)")
        }
    }
    
    // MARK: - 脚本执行
    
    /// 执行指定ID的脚本
    public func executeScript(id: String) async -> Result<UIScriptResult, UIScriptEngineError> {
        guard let info = scriptManager.scriptByID(id) else {
            return .failure(.scriptNotFound(id))
        }
        return await executeScript(info)
    }
    
    /// 直接执行脚本内容（不经过注册）
    public func executeScript(_ info: UIScriptInfo) async -> Result<UIScriptResult, UIScriptEngineError> {
        let startTime = Date()
        
        // 发送执行开始通知
        NotificationCenter.default.post(
            name: .scriptExecutionDidStart,
            object: self,
            userInfo: ["scriptID": info.id, "scriptName": info.name, "scriptType": info.type.rawValue]
        )
        logger.info("开始执行脚本: \(info.name) (\(info.type.displayName))")
        
        do {
            // 权限检查
            let currentConfig = self.currentConfig
            try permissionManager.validateExecution(
                scriptID: info.id,
                whitelistModeEnabled: currentConfig.whitelistModeEnabled
            )
            
            // 检查脚本类型是否启用
            switch info.type {
            case .appleScript:
                guard currentConfig.appleScriptEnabled else {
                    throw UIScriptEngineError.unsupportedScriptType("AppleScript已禁用")
                }
            case .javaScript:
                guard currentConfig.javaScriptEnabled else {
                    throw UIScriptEngineError.unsupportedScriptType("JavaScript已禁用")
                }
            }
            
            // 检查脚本内容
            guard !info.sourceCode.isEmpty else {
                throw UIScriptEngineError.invalidScriptContent
            }
            
            // 执行脚本
            let result: UIScriptResult
            switch info.type {
            case .appleScript:
                result = try executeAppleScript(info.sourceCode)
            case .javaScript:
                result = try executeJavaScript(info.sourceCode)
            }
            
            // 更新脚本统计信息
            if var script = scriptManager.scriptByID(info.id) {
                script.recordExecution()
                try? scriptManager.saveScript(script)
            }
            
            // 记录执行历史
            let duration = Date().timeIntervalSince(startTime) * 1000
            let summary = result.stringValue.prefix(200).description
            let record = UIScriptExecutionRecord(
                scriptID: info.id,
                scriptName: info.name,
                executedAt: startTime,
                durationMs: duration,
                isSuccess: true,
                resultSummary: summary
            )
            addExecutionRecord(record)
            
            // 发送执行完成通知
            NotificationCenter.default.post(
                name: .scriptExecutionDidComplete,
                object: self,
                userInfo: [
                    "scriptID": info.id,
                    "scriptName": info.name,
                    "result": result,
                    "durationMs": duration
                ]
            )
            logger.info("脚本执行成功: \(info.name) (耗时 \(String(format: "%.2f", duration))ms)")
            
            return .success(result)
            
        } catch let error as UIScriptEngineError {
            let duration = Date().timeIntervalSince(startTime) * 1000
            let record = UIScriptExecutionRecord(
                scriptID: info.id,
                scriptName: info.name,
                executedAt: startTime,
                durationMs: duration,
                isSuccess: false,
                resultSummary: error.localizedDescription
            )
            addExecutionRecord(record)
            
            NotificationCenter.default.post(
                name: .scriptExecutionDidFail,
                object: self,
                userInfo: [
                    "scriptID": info.id,
                    "scriptName": info.name,
                    "error": error.localizedDescription
                ]
            )
            logger.error("脚本执行失败: \(info.name) - \(error.localizedDescription)")
            return .failure(error)
        } catch {
            let scriptError = UIScriptEngineError.javaScriptExecutionFailed(error.localizedDescription)
            NotificationCenter.default.post(
                name: .scriptExecutionDidFail,
                object: self,
                userInfo: [
                    "scriptID": info.id,
                    "scriptName": info.name,
                    "error": scriptError.localizedDescription
                ]
            )
            logger.error("脚本执行失败: \(info.name) - \(error.localizedDescription)")
            return .failure(scriptError)
        }
    }
    
    // MARK: - AppleScript 执行
    
    /// 执行 AppleScript 源码
    private func executeAppleScript(_ source: String) throws -> UIScriptResult {
        guard let appleScript = NSAppleScript(source: source) else {
            throw UIScriptEngineError.appleScriptCompileFailed("无法创建AppleScript对象")
        }
        
        var compileError: NSDictionary?
        appleScript.compileAndReturnError(&compileError)
        if let error = compileError {
            let msg = error.description
            throw UIScriptEngineError.appleScriptCompileFailed(msg)
        }
        
        var executionError: NSDictionary?
        let result = appleScript.executeAndReturnError(&executionError)
        
        if let error = executionError {
            let msg = error.description
            throw UIScriptEngineError.appleScriptExecutionFailed(msg)
        }
        
        if result == NSAppleEventDescriptor.null() {
            return .empty
        }
        return .text(result.stringValue ?? "")
    }
    
    // MARK: - JavaScript 执行
    
    /// 执行 JavaScript 源码
    private func executeJavaScript(_ source: String) throws -> UIScriptResult {
        let result = jsContext.evaluateScript(source)
        
        if let exception = jsContext.exception {
            let msg = exception.toString() ?? "JavaScript执行异常"
            throw UIScriptEngineError.javaScriptExecutionFailed(msg)
        }
        
        guard let jsValue = result else {
            return .empty
        }
        
        // 将 JSValue 转换为 Swift 类型
        if jsValue.isUndefined || jsValue.isNull {
            return .empty
        } else if jsValue.isString {
            return .text(jsValue.toString())
        } else if jsValue.isNumber {
            return .text(jsValue.toString())
        } else if jsValue.isObject {
            // 尝试转换为JSON对象
            if let dict = jsValue.toDictionary() as? [String: Any] {
                return .json(dict)
            } else if let array = jsValue.toArray() {
                return .json(["result": array])
            } else {
                return .text(jsValue.toString())
            }
        } else if jsValue.isBoolean {
            return .text(jsValue.toBool() ? "true" : "false")
        } else {
            return .text(jsValue.toString())
        }
    }
    
    // MARK: - 执行历史管理
    
    /// 添加执行记录（线程安全）
    private func addExecutionRecord(_ record: UIScriptExecutionRecord) {
        lock.lock()
        executionHistory.append(record)
        // 限制历史记录数量
        let maxCount = config.maxHistoryCount
        if executionHistory.count > maxCount {
            executionHistory.removeFirst(executionHistory.count - maxCount)
        }
        lock.unlock()
    }
    
    /// 获取所有执行历史（副本）
    public var history: [UIScriptExecutionRecord] {
        lock.lock()
        let records = executionHistory
        lock.unlock()
        return records
    }
    
    /// 清空执行历史
    public func clearHistory() {
        lock.lock()
        executionHistory.removeAll()
        lock.unlock()
        logger.info("执行历史已清空")
    }
    
    // MARK: - 预设脚本
    
    /// 注册预设脚本（调试和常用工具脚本）
    public func registerPresetScripts() {
        // 预设1: 获取当前应用版本（AppleScript）
        let versionScript = UIScriptInfo(
            name: "获取应用版本",
            description: "通过AppleScript获取当前应用的版本号",
            type: .appleScript,
            sourceCode: """
            tell application "System Events"
                set appName to name of first application process whose frontmost is true
            end tell
            tell application appName
                set appVersion to version
            end tell
            return appVersion
            """,
            isEnabled: true,
            isWhitelisted: true,
            tags: ["预设", "系统信息"]
        )
        
        // 预设2: 获取当前时间（JavaScript）
        let timeScript = UIScriptInfo(
            name: "获取当前时间",
            description: "通过JavaScript获取当前日期时间字符串",
            type: .javaScript,
            sourceCode: """
            var now = new Date();
            var result = {
                "date": now.toLocaleDateString(),
                "time": now.toLocaleTimeString(),
                "timestamp": now.getTime(),
                "iso": now.toISOString()
            };
            result;
            """,
            isEnabled: true,
            isWhitelisted: true,
            tags: ["预设", "时间"]
        )
        
        // 预设3: 系统内存信息（AppleScript）
        let memoryScript = UIScriptInfo(
            name: "系统内存信息",
            description: "获取系统内存使用情况",
            type: .appleScript,
            sourceCode: """
            tell application "System Events"
                set memStats to system info
            end tell
            return "系统内存信息已获取"
            """,
            isEnabled: true,
            isWhitelisted: true,
            tags: ["预设", "系统信息"]
        )
        
        // 预设4: JSON数据格式化（JavaScript）
        let jsonFormatScript = UIScriptInfo(
            name: "JSON格式化工具",
            description: "将输入数据格式化为标准JSON字符串",
            type: .javaScript,
            sourceCode: """
            var data = {
                "app": "仙人指路",
                "version": "2.0",
                "features": ["K线", "指标", "脚本引擎"],
                "status": "running"
            };
            JSON.stringify(data, null, 2);
            """,
            isEnabled: true,
            isWhitelisted: true,
            tags: ["预设", "工具"]
        )
        
        // 预设5: 计算器（JavaScript）
        let calculatorScript = UIScriptInfo(
            name: "简易计算器",
            description: "执行简单的数学表达式计算",
            type: .javaScript,
            sourceCode: """
            var a = 10;
            var b = 20;
            var sum = a + b;
            var product = a * b;
            var result = {
                "a": a,
                "b": b,
                "sum": sum,
                "product": product,
                "average": (a + b) / 2
            };
            result;
            """,
            isEnabled: true,
            isWhitelisted: true,
            tags: ["预设", "数学"]
        )
        
        // 批量注册预设脚本
        let presets = [versionScript, timeScript, memoryScript, jsonFormatScript, calculatorScript]
        for preset in presets {
            _ = registerScript(preset)
        }
        logger.info("已注册 \(presets.count) 个预设脚本")
    }
    
    // MARK: - 设置面板支持
    
    /// 获取设置面板需要的配置项
    public func settingsData() -> (config: UIScriptEngineConfig, scriptCount: Int, whitelistCount: Int, historyCount: Int) {
        let cfg = currentConfig
        return (config: cfg, scriptCount: allScripts.count, whitelistCount: permissionManager.whitelistCount, historyCount: history.count)
    }
    
    /// 从设置面板更新单个配置项
    public func updateSetting(key: String, value: Any) {
        var cfg = currentConfig
        switch key {
        case "appleScriptEnabled":
            if let v = value as? Bool { cfg.appleScriptEnabled = v }
        case "javaScriptEnabled":
            if let v = value as? Bool { cfg.javaScriptEnabled = v }
        case "defaultTimeout":
            if let v = value as? TimeInterval { cfg.defaultTimeout = v }
        case "whitelistModeEnabled":
            if let v = value as? Bool { cfg.whitelistModeEnabled = v }
        case "maxScriptCount":
            if let v = value as? Int { cfg.maxScriptCount = v }
        case "autoSaveHistory":
            if let v = value as? Bool { cfg.autoSaveHistory = v }
        case "maxHistoryCount":
            if let v = value as? Int { cfg.maxHistoryCount = v }
        case "showExecutionConfirmation":
            if let v = value as? Bool { cfg.showExecutionConfirmation = v }
        case "allowNetworkAccess":
            if let v = value as? Bool { cfg.allowNetworkAccess = v }
        case "allowFileSystemAccess":
            if let v = value as? Bool { cfg.allowFileSystemAccess = v }
        default:
            logger.warning("未知的设置项: \(key)")
            return
        }
        updateConfig(cfg)
    }
    
    /// 重置所有配置为默认值
    public func resetToDefaultConfig() {
        updateConfig(.default)
        logger.info("脚本引擎配置已重置为默认值")
    }
    
    /// 导出所有脚本到指定目录（JSON格式）
    public func exportScripts(to directory: URL) throws {
        let scripts = allScripts
        let exportData = try JSONEncoder().encode(scripts)
        let exportURL = directory.appendingPathComponent("scripts_export_\(Int(Date().timeIntervalSince1970)).json")
        try exportData.write(to: exportURL)
        logger.info("已导出 \(scripts.count) 个脚本到 \(exportURL.path)")
    }
    
    /// 从JSON文件导入脚本
    public func importScripts(from url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let scripts = try JSONDecoder().decode([UIScriptInfo].self, from: data)
        var count = 0
        for script in scripts {
            if registerScript(script) {
                count += 1
            }
        }
        logger.info("已从 \(url.path) 导入 \(count) 个脚本")
        return count
    }
    
    /// 执行历史导出（JSON格式）
    public func exportHistory(to url: URL) throws {
        lock.lock()
        let records = executionHistory
        lock.unlock()
        let data = try JSONEncoder().encode(records)
        try data.write(to: url)
        logger.info("已导出 \(records.count) 条执行历史")
    }
    
    // MARK: - 设置面板方法
    
    /// 脚本列表项（供设置面板展示）
    public struct UIScriptListItem {
        public let id: String
        public let name: String
        public let type: String
        public let description: String
        public let isEnabled: Bool
        public let isWhitelisted: Bool
        public let executionCount: Int
        public let createdAt: Date
        public let updatedAt: Date
        public let tags: [String]
    }
    
    /// 执行历史项（供设置面板展示）
    public struct UIHistoryItem {
        public let id: String
        public let scriptID: String
        public let scriptName: String
        public let executedAt: Date
        public let durationMs: Double
        public let isSuccess: Bool
        public let resultSummary: String
    }
    
    /// 配置项（供设置面板展示）
    public struct UIScriptConfigItem: Identifiable {
        public var id: String { key }
        public let key: String
        public let label: String
        public let value: Any
        public let type: String
    }
    
    /// 获取所有已注册脚本列表（用于设置面板展示）
    public func allScriptsForSettings() -> [UIScriptListItem] {
        return allScripts.map { info in
            UIScriptListItem(
                id: info.id, name: info.name, type: info.type.rawValue,
                description: info.description,
                isEnabled: info.isEnabled, isWhitelisted: info.isWhitelisted,
                executionCount: info.executionCount,
                createdAt: info.createdAt, updatedAt: info.updatedAt,
                tags: info.tags
            )
        }
    }
    
    /// 获取脚本执行历史列表（用于设置面板展示）
    public func executionHistoryForSettings() -> [UIHistoryItem] {
        return history.map { record in
            UIHistoryItem(
                id: record.id, scriptID: record.scriptID,
                scriptName: record.scriptName,
                executedAt: record.executedAt,
                durationMs: record.durationMs,
                isSuccess: record.isSuccess,
                resultSummary: record.resultSummary
            )
        }
    }
    
    /// 获取引擎配置数据（用于设置面板展示）
    public func configForSettings() -> [UIScriptConfigItem] {
        let cfg = currentConfig
        return [
            UIScriptConfigItem(key: "appleScriptEnabled", label: "AppleScript", value: cfg.appleScriptEnabled, type: "bool"),
            UIScriptConfigItem(key: "javaScriptEnabled", label: "JavaScript", value: cfg.javaScriptEnabled, type: "bool"),
            UIScriptConfigItem(key: "defaultTimeout", label: "超时(秒)", value: cfg.defaultTimeout, type: "timeInterval"),
            UIScriptConfigItem(key: "whitelistModeEnabled", label: "白名单模式", value: cfg.whitelistModeEnabled, type: "bool"),
            UIScriptConfigItem(key: "maxScriptCount", label: "最大脚本数", value: cfg.maxScriptCount, type: "int"),
            UIScriptConfigItem(key: "autoSaveHistory", label: "自动保存历史", value: cfg.autoSaveHistory, type: "bool"),
            UIScriptConfigItem(key: "maxHistoryCount", label: "历史记录数", value: cfg.maxHistoryCount, type: "int"),
            UIScriptConfigItem(key: "allowNetworkAccess", label: "网络访问", value: cfg.allowNetworkAccess, type: "bool"),
            UIScriptConfigItem(key: "allowFileSystemAccess", label: "文件系统访问", value: cfg.allowFileSystemAccess, type: "bool")
        ]
    }
}

// MARK: - 迁回自 UI-02：class UIScriptManager
public final class UIScriptManager : @unchecked Sendable {
    /// 日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu.script", category: "ScriptManager")
    /// 互斥锁保护脚本存储
    private let lock = NSRecursiveLock()
    /// 内存中的脚本缓存
    private var scripts: [String: UIScriptInfo] = [:]
    /// 存储目录URL
    private let storageDirectory: URL
    
    /// 初始化并加载已有脚本
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("XianRenZhiLu/Scripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageDirectory = dir
        loadAllScripts()
        logger.info("脚本管理器已初始化，加载了 \(self.scripts.count) 个脚本")
    }
    
    /// 清理时释放资源
    deinit {
        logger.info("脚本管理器已释放")
    }
    
    /// 获取所有脚本数组
    public func allScripts() -> [UIScriptInfo] {
        lock.lock()
        let list = Array(scripts.values)
        lock.unlock()
        return list.sorted { $0.createdAt < $1.createdAt }
    }
    
    /// 根据ID查找脚本
    public func scriptByID(_ id: String) -> UIScriptInfo? {
        lock.lock()
        let result = scripts[id]
        lock.unlock()
        return result
    }
    
    /// 保存脚本到磁盘（新增或更新）
    public func saveScript(_ info: UIScriptInfo) throws {
        lock.lock()
        scripts[info.id] = info
        lock.unlock()
        
        // 持久化到文件
        let fileURL = storageDirectory.appendingPathComponent("\(info.id).json")
        do {
            let data = try JSONEncoder().encode(info)
            try data.write(to: fileURL)
            logger.info("脚本已保存到磁盘: \(info.name)")
        } catch {
            logger.error("保存脚本到磁盘失败: \(error.localizedDescription)")
            throw UIScriptEngineError.persistenceFailed(error)
        }
    }
    
    /// 删除脚本
    public func deleteScript(id: String) throws {
        lock.lock()
        scripts.removeValue(forKey: id)
        lock.unlock()
        
        let fileURL = storageDirectory.appendingPathComponent("\(id).json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        logger.info("脚本已删除: \(id)")
    }
    
    /// 加载所有已持久化的脚本
    private func loadAllScripts() {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil,
            options: []
        ) else {
            return
        }
        
        var loadedCount = 0
        for url in fileURLs where url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                let script = try JSONDecoder().decode(UIScriptInfo.self, from: data)
                scripts[script.id] = script
                loadedCount += 1
            } catch {
                logger.error("加载脚本文件失败 \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        logger.info("从磁盘加载了 \(loadedCount) 个脚本")
    }
    
    /// 清理所有脚本（危险操作）
    public func clearAllScripts() throws {
        lock.lock()
        let ids = Array(scripts.keys)
        scripts.removeAll()
        lock.unlock()
        
        for id in ids {
            let fileURL = storageDirectory.appendingPathComponent("\(id).json")
            try? FileManager.default.removeItem(at: fileURL)
        }
        logger.warning("所有脚本已清空（共 \(ids.count) 个）")
    }
}

// MARK: - 迁回自 UI-02：enum UIScriptEngineError
// 已迁回 UI-GL-36_开发者工具面板.swift：class UIDeveloperToolsManager（公共类型文件禁止功能实现）

// MARK: - NSWindowDelegate
// 已迁回 UI-GL-36_开发者工具面板.swift：extension UIDeveloperToolsManager（公共类型文件禁止功能实现）

// MARK: - 键盘快捷键处理
// 已迁回 UI-GL-36_开发者工具面板.swift：extension UIDeveloperToolsManager（公共类型文件禁止功能实现）

// 已迁回 UI-GL-36_开发者工具面板.swift：class UIDeveloperToolsShortcutHandler（公共类型文件禁止功能实现）

// 已迁回 UI-GL-36_开发者工具面板.swift：class UIDevToolsSplitViewController（公共类型文件禁止功能实现）

// 已迁回 UI-GL-36_开发者工具面板.swift：class UIDevToolsSidebarViewController（公共类型文件禁止功能实现）

// 已迁回 UI-GL-36_开发者工具面板.swift：class UIDevToolsContentViewController（公共类型文件禁止功能实现）


// MARK: - UI-GL-37 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-37_types.swift
// 版本: 2.0
// MARK: - 错误枚举
/// 脚本引擎执行过程中可能发生的错误类型
public enum UIScriptEngineError: Error, LocalizedError {
    /// 脚本类型不支持
    case unsupportedScriptType(String)
    /// 脚本内容为空或无效
    case invalidScriptContent
    /// AppleScript 编译失败
    case appleScriptCompileFailed(String)
    /// AppleScript 执行失败
    case appleScriptExecutionFailed(String)
    /// JavaScript 执行失败
    case javaScriptExecutionFailed(String)
    /// 脚本权限被拒绝（不在白名单中）
    case permissionDenied(String)
    /// 脚本文件不存在
    case scriptFileNotFound(URL)
    /// 脚本持久化失败
    case persistenceFailed(Error)
    /// 脚本ID重复
    case duplicateScriptID(String)
    /// 脚本未找到
    case scriptNotFound(String)
    /// JSON 解析失败
    case jsonParseFailed(Error)
    /// 白名单配置错误
    case whitelistConfigError(String)
    
    /// 中文错误描述
    public var errorDescription: String? {
        switch self {
        case .unsupportedScriptType(let type):
            return "不支持的脚本类型: \(type)"
        case .invalidScriptContent:
            return "脚本内容无效或为空"
        case .appleScriptCompileFailed(let msg):
            return "AppleScript 编译失败: \(msg)"
        case .appleScriptExecutionFailed(let msg):
            return "AppleScript 执行失败: \(msg)"
        case .javaScriptExecutionFailed(let msg):
            return "JavaScript 执行失败: \(msg)"
        case .permissionDenied(let id):
            return "脚本权限被拒绝: \(id)"
        case .scriptFileNotFound(let url):
            return "脚本文件不存在: \(url.path)"
        case .persistenceFailed(let err):
            return "脚本持久化失败: \(err.localizedDescription)"
        case .duplicateScriptID(let id):
            return "脚本ID重复: \(id)"
        case .scriptNotFound(let id):
            return "未找到脚本: \(id)"
        case .jsonParseFailed(let err):
            return "JSON解析失败: \(err.localizedDescription)"
        case .whitelistConfigError(let msg):
            return "白名单配置错误: \(msg)"
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIScriptType
// MARK: - 脚本类型
/// 支持的脚本语言类型
public enum UIScriptType: String, Codable, CaseIterable, Identifiable {
    /// AppleScript 脚本（macOS原生脚本）
    case appleScript = "AppleScript"
    /// JavaScript 脚本（通过JSCore执行）
    case javaScript = "JavaScript"
    
    public var id: String { rawValue }
    
    /// 文件扩展名
    public var fileExtension: String {
        switch self {
        case .appleScript: return "scpt"
        case .javaScript: return "js"
        }
    }
    
    /// 显示名称
    public var displayName: String {
        switch self {
        case .appleScript: return "AppleScript"
        case .javaScript: return "JavaScript"
        }
    }
    
    /// 语法高亮标识符
    public var syntaxHighlightID: String {
        switch self {
        case .appleScript: return "applescript"
        case .javaScript: return "javascript"
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIScriptResult
// MARK: - 脚本结果
/// 脚本执行结果，支持多种格式
public enum UIScriptResult {
    /// 纯文本结果
    case text(String)
    /// JSON 对象结果
    case json([String: Any])
    /// 二进制数据结果
    case data(Data)
    /// 空结果
    case empty
    
    /// 转换为字符串表示
    public var stringValue: String {
        switch self {
        case .text(let str):
            return str
        case .json(let dict):
            do {
                let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
                return String(data: data, encoding: .utf8) ?? "{}"
            } catch {
                return "{}"
            }
        case .data(let d):
            return "<Data: \(d.count) bytes>"
        case .empty:
            return "<空结果>"
        }
    }
    
    /// 判断结果是否为空
    public var isEmpty: Bool {
        switch self {
        case .text(let str): return str.isEmpty
        case .json(let dict): return dict.isEmpty
        case .data(let d): return d.isEmpty
        case .empty: return true
        }
    }
    
    /// 尝试获取JSON字典（非JSON类型返回nil）
    public var jsonValue: [String: Any]? {
        switch self {
        case .json(let dict): return dict
        default: return nil
        }
    }
    
    /// 获取数据形式的结果
    public var dataValue: Data? {
        switch self {
        case .data(let d): return d
        case .text(let str): return str.data(using: .utf8)
        case .json(let dict):
            return try? JSONSerialization.data(withJSONObject: dict)
        case .empty: return nil
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIScriptInfo
// MARK: - 脚本信息
/// 已注册脚本的信息结构，用于持久化和管理
public struct UIScriptInfo: Identifiable, Codable, Equatable {
    /// 唯一标识符
    public let id: String
    /// 脚本名称
    public var name: String
    /// 脚本描述
    public var description: String
    /// 脚本类型
    public var type: UIScriptType
    /// 脚本内容（源码）
    public var sourceCode: String
    /// 创建时间
    public var createdAt: Date
    /// 最后修改时间
    public var updatedAt: Date
    /// 是否启用
    public var isEnabled: Bool
    /// 是否在白名单中（允许执行）
    public var isWhitelisted: Bool
    /// 执行次数统计
    public var executionCount: Int
    /// 最后执行时间
    public var lastExecutedAt: Date?
    /// 标签分类
    public var tags: [String]
    
    /// 创建脚本信息
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        type: UIScriptType,
        sourceCode: String,
        isEnabled: Bool = true,
        isWhitelisted: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.sourceCode = sourceCode
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isEnabled = isEnabled
        self.isWhitelisted = isWhitelisted
        self.executionCount = 0
        self.lastExecutedAt = nil
        self.tags = tags
    }
    
    /// 更新修改时间
    public mutating func touch() {
        self.updatedAt = Date()
    }
    
    /// 记录一次执行
    public mutating func recordExecution() {
        self.executionCount += 1
        self.lastExecutedAt = Date()
    }
}

// MARK: - 迁回自 UI-02：struct UIScriptEngineConfig
// MARK: - 脚本引擎配置
/// 脚本引擎的全局配置，支持Codable持久化
public struct UIScriptEngineConfig: Codable, Equatable, Sendable {
    /// 是否启用AppleScript执行
    public var appleScriptEnabled: Bool
    /// 是否启用JavaScript执行
    public var javaScriptEnabled: Bool
    /// 默认执行超时（秒）
    public var defaultTimeout: TimeInterval
    /// 是否启用白名单模式（true时只允许白名单脚本执行）
    public var whitelistModeEnabled: Bool
    /// 最大脚本数量限制
    public var maxScriptCount: Int
    /// 是否自动保存执行历史
    public var autoSaveHistory: Bool
    /// 历史记录最大条数
    public var maxHistoryCount: Int
    /// 执行前是否弹出确认对话框
    public var showExecutionConfirmation: Bool
    /// 是否允许脚本访问网络
    public var allowNetworkAccess: Bool
    /// 是否允许脚本访问文件系统
    public var allowFileSystemAccess: Bool
    
    /// 默认配置
    public static let `default` = UIScriptEngineConfig(
        appleScriptEnabled: true,
        javaScriptEnabled: true,
        defaultTimeout: 30.0,
        whitelistModeEnabled: true,
        maxScriptCount: 100,
        autoSaveHistory: true,
        maxHistoryCount: 50,
        showExecutionConfirmation: false,
        allowNetworkAccess: false,
        allowFileSystemAccess: false
    )
    
    public init(
        appleScriptEnabled: Bool = true,
        javaScriptEnabled: Bool = true,
        defaultTimeout: TimeInterval = 30.0,
        whitelistModeEnabled: Bool = true,
        maxScriptCount: Int = 100,
        autoSaveHistory: Bool = true,
        maxHistoryCount: Int = 50,
        showExecutionConfirmation: Bool = false,
        allowNetworkAccess: Bool = false,
        allowFileSystemAccess: Bool = false
    ) {
        self.appleScriptEnabled = appleScriptEnabled
        self.javaScriptEnabled = javaScriptEnabled
        self.defaultTimeout = defaultTimeout
        self.whitelistModeEnabled = whitelistModeEnabled
        self.maxScriptCount = maxScriptCount
        self.autoSaveHistory = autoSaveHistory
        self.maxHistoryCount = maxHistoryCount
        self.showExecutionConfirmation = showExecutionConfirmation
        self.allowNetworkAccess = allowNetworkAccess
        self.allowFileSystemAccess = allowFileSystemAccess
    }
}

// MARK: - 迁回自 UI-02：struct UIScriptExecutionRecord
// MARK: - 脚本执行历史记录
/// 单次脚本执行的记录
public struct UIScriptExecutionRecord: Identifiable, Codable, Equatable {
    /// 记录ID
    public let id: String
    /// 脚本ID
    public let scriptID: String
    /// 脚本名称
    public let scriptName: String
    /// 执行时间
    public let executedAt: Date
    /// 执行时长（毫秒）
    public let durationMs: Double
    /// 是否成功
    public let isSuccess: Bool
    /// 结果摘要（成功时为结果前200字符，失败时为错误信息）
    public let resultSummary: String
    
    public init(
        id: String = UUID().uuidString,
        scriptID: String,
        scriptName: String,
        executedAt: Date,
        durationMs: Double,
        isSuccess: Bool,
        resultSummary: String
    ) {
        self.id = id
        self.scriptID = scriptID
        self.scriptName = scriptName
        self.executedAt = executedAt
        self.durationMs = durationMs
        self.isSuccess = isSuccess
        self.resultSummary = resultSummary
    }
}

// MARK: - 迁回自 UI-02：struct UIScriptResultFormatter
// MARK: - 脚本权限管理器
/// 管理脚本执行权限，提供白名单控制
// 已迁回 UI-GL-37_脚本引擎.swift：class UIScriptPermissionManager（公共类型文件禁止功能实现）

// MARK: - 脚本引擎
/// 运行时脚本执行引擎，支持AppleScript和JavaScript
// 已迁回 UI-GL-37_脚本引擎.swift：class UIScriptEngine（公共类型文件禁止功能实现）

// MARK: - 脚本管理器
/// 负责脚本的持久化存储、加载和删除
// 已迁回 UI-GL-37_脚本引擎.swift：class UIScriptManager（公共类型文件禁止功能实现）

// MARK: - 结果格式化工具
/// 脚本结果的格式化输出工具
public struct UIScriptResultFormatter {
    /// 将结果格式化为纯文本
    public static func plainText(from result: UIScriptResult) -> String {
        return result.stringValue
    }
    
    /// 将结果格式化为JSON字符串
    public static func jsonString(from result: UIScriptResult) -> String {
        switch result {
        case .json(let dict):
            do {
                let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
                return String(data: data, encoding: .utf8) ?? "{}"
            } catch {
                return "{\"error\": \"JSON序列化失败\"}"
            }
        case .text(let str):
            return "{\"result\": \"\(str)\"}"
        case .data(let d):
            let base64 = d.base64EncodedString()
            return "{\"data\": \"\(base64)\"}"
        case .empty:
            return "{\"result\": null}"
        }
    }
    
    /// 将结果转换为HTML格式（用于富文本显示）
    public static func html(from result: UIScriptResult) -> String {
        let content: String
        switch result {
        case .text(let str):
            content = str.htmlEscaped
        case .json(let dict):
            content = UIScriptResultFormatter.jsonString(from: .json(dict)).htmlEscaped
        case .data(let d):
            content = "<Data: \(d.count) bytes>"
        case .empty:
            content = "<空结果>"
        }
        return "<pre>\(content)</pre>"
    }
}
