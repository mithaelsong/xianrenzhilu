// MARK: - UI-01: 统一注册表
// 功能编号: UI-01
// 版本: 2.0
// 职责: 纯注册表，只管理ID映射和基础CRUD，不包含任何业务逻辑
// 依赖: UI-02 (公共类型)

import Foundation
import AppKit
import os
private nonisolated(unsafe) var uiWindowLevelCompatStorage: [String: UIWindowLevelType] = [:]
private let uiWindowLevelCompatLock = NSRecursiveLock()


// MARK: - UI功能注册条目
public struct UIFeatureRegistration {
    public let name: String
    public weak var instance: UIFeatureProtocol?
    public let handler: (([String: Any]?) -> Any?)?

    public init(name: String, instance: UIFeatureProtocol?, handler: (([String: Any]?) -> Any?)?) {
        self.name = name
        self.instance = instance
        self.handler = handler
    }
}

// MARK: - 统一注册表
public final class UIUnifiedRegistry: @unchecked Sendable {
    public static let shared = UIUnifiedRegistry()
    private init() {}
    
    private let lock = NSRecursiveLock()
    
    // MARK: - 模块注册表
    private var modules: [String: UIModuleProtocol] = [:]
    private var moduleMetadata: [String: UIModuleMetadata] = [:]
    private var moduleRegistrations: [String: UIModuleRegistration] = [:]
    private var moduleAliasMap: [String: String] = [:]
    
    // MARK: - 皮肤注册表
    private var skins: [String: UISkinInfo] = [:]
    private var currentSkinId: String = "com.app.glass"
    private var skinProtocols: [String: UISkinProtocol] = [:]
    private var skinIdToPath: [String: String] = [:]
    private var skinNameToId: [String: String] = [:]
    private var skinTagToIds: [String: [String]] = [:]
    private var skinInfoMap: [String: UISkinInfo] = [:]
    private var disabledSkinIds: Set<String> = []

    // MARK: - 主题注册表
    // 主题不是皮肤。皮肤负责结构/材质/交互风格；主题负责浅色、深色、高对比度和色盲辅助。
    private var themes: [String: UIThemeDefinition] = [:]
    private var currentThemeId: String = "built-in-light"
    
    // MARK: - 窗口注册表
    private var windows: [String: NSWindow] = [:]
    private var windowInfos: [String: [String: Any]] = [:]
    private var windowRecords: [String: UIWindowRecord] = [:]
    
    // MARK: - 功能注册表
    private var featureRegistrations: [String: UIFeatureRegistration] = [:]
    
    // MARK: - 配置注册表
    private var configs: [String: [String: Any]] = [:]
    
    // MARK: - 状态注册表
    private var states: [String: [String: Any]] = [:]
    
    // MARK: - 加载顺序管理
    private var loadOrders: [String: Int] = [:]
    private var dependencyGraph: [String: [String]] = [:]
    private var retainedModuleInstances: [String: AnyObject] = [:]
    
    // MARK: - 1. 模块注册表
    
    public func register(module: UIModuleProtocol, metadata: UIModuleMetadata) {
        lock.lock()
        let moduleID = module.moduleID
        modules[moduleID] = module
        moduleMetadata[moduleID] = metadata
        dependencyGraph[moduleID] = metadata.dependencies
        loadOrders[moduleID] = metadata.category.priorityValue
        lock.unlock()
        print("[UIUnifiedRegistry] Registered: \(module.moduleName) (ID: \(moduleID))")
    }
    
    public func unregister(moduleID: String) {
        lock.lock()
        modules.removeValue(forKey: moduleID)
        moduleMetadata.removeValue(forKey: moduleID)
        dependencyGraph.removeValue(forKey: moduleID)
        loadOrders.removeValue(forKey: moduleID)
        lock.unlock()
    }

    public func getModule(moduleID: String) -> UIModuleProtocol? {
        lock.lock()
        let module = modules[moduleID]
        lock.unlock()
        return module
    }

    public func isModuleRegistered(moduleID: String) -> Bool {
        lock.lock()
        let exists = modules[moduleID] != nil
        lock.unlock()
        return exists
    }
    
    public func getAllModuleIDs() -> [String] {
        lock.lock()
        let ids = Array(modules.keys)
        lock.unlock()
        return ids
    }
    
    public func getAllModuleMetadata() -> [String: UIModuleMetadata] {
        lock.lock()
        let metadata = moduleMetadata
        lock.unlock()
        return metadata
    }
    
    public func loadModule(moduleID: String) throws {
        guard let module = getModule(moduleID: moduleID) else {
            throw UIModuleLoadError.moduleNotFound(moduleID: moduleID)
        }
        try module.start(context: nil)
    }

    public func unloadModule(moduleID: String) throws {
        guard let module = getModule(moduleID: moduleID) else {
            throw UIModuleLoadError.moduleNotFound(moduleID: moduleID)
        }
        module.stop()
    }

    public func reloadModule(moduleID: String) throws {
        try unloadModule(moduleID: moduleID)
        try loadModule(moduleID: moduleID)
    }
    
    // MARK: - 2. 模块注册（详细）
    
    public func registerModule(registration: UIModuleRegistration) {
        lock.lock()
        moduleRegistrations[registration.name] = registration
        for alias in registration.aliases {
            moduleAliasMap[alias] = registration.name
        }
        lock.unlock()
    }
    
    public func unregisterModule(name: String) {
        lock.lock()
        let registration = moduleRegistrations.removeValue(forKey: name)
        if let aliases = registration?.aliases {
            for alias in aliases {
                moduleAliasMap.removeValue(forKey: alias)
            }
        }
        lock.unlock()
    }
    
    public func getModuleRegistration(name: String) -> UIModuleRegistration? {
        lock.lock()
        if let registration = moduleRegistrations[name] {
            lock.unlock()
            return registration
        }
        let targetName = moduleAliasMap[name]
        let registration = targetName != nil ? moduleRegistrations[targetName!] : nil
        lock.unlock()
        return registration
    }
    
    public func getAllModuleRegistrations() -> [UIModuleRegistration] {
        lock.lock()
        let registrations = Array(moduleRegistrations.values)
        lock.unlock()
        return registrations
    }
    
    // MARK: - 3. 皮肤注册表
    
    public func registerSkin(_ info: UISkinInfo, protocol skin: UISkinProtocol) {
        lock.lock()
        skins[info.id] = info
        skinProtocols[info.id] = skin
        lock.unlock()
        print("[UIUnifiedRegistry] Skin registered: \(info.id)")
    }
    
    public func registerSkin(id: String, path: String, info: UISkinInfo) {
        lock.lock()
        skinIdToPath[id] = path
        skinNameToId[info.name] = id
        skinInfoMap[id] = info
        for tag in info.tags {
            if skinTagToIds[tag] == nil {
                skinTagToIds[tag] = []
            }
            skinTagToIds[tag]?.append(id)
        }
        lock.unlock()
        print("[UIUnifiedRegistry] Registered skin: \(id)")
    }
    
    public func unregisterSkin(id: String) {
        lock.lock()
        skins.removeValue(forKey: id)
        skinProtocols.removeValue(forKey: id)
        skinIdToPath.removeValue(forKey: id)
        skinInfoMap.removeValue(forKey: id)
        if let name = skinInfoMap[id]?.name {
            skinNameToId.removeValue(forKey: name)
        }
        for (tag, var ids) in skinTagToIds {
            ids.removeAll { $0 == id }
            skinTagToIds[tag] = ids
        }
        lock.unlock()
    }
    
    public func applySkin(id: String) -> Bool {
        lock.lock()
        let exists = skins[id] != nil
        lock.unlock()
        guard exists else { return false }
        lock.lock()
        currentSkinId = id
        lock.unlock()
        for (_, window) in windows {
            skinProtocols[id]?.apply(to: window)
        }
        return true
    }
    
    public func getCurrentSkin() -> UISkinInfo? {
        lock.lock()
        let skin = skins[currentSkinId]
        lock.unlock()
        return skin
    }
    
    public func getSkin(id: String) -> UISkinInfo? {
        lock.lock()
        let info = skinInfoMap[id] ?? skins[id]
        lock.unlock()
        return info
    }
    public func getSkinProtocol(id: String) -> UISkinProtocol? {
        lock.lock()
        let skin = skinProtocols[id]
        lock.unlock()
        return skin
    }

    
    public func getSkinByName(name: String) -> UISkinInfo? {
        lock.lock()
        let id = skinNameToId[name]
        let info = id != nil ? skinInfoMap[id!] : nil
        lock.unlock()
        return info
    }
    
    public func getSkinsByTag(tag: String) -> [UISkinInfo] {
        lock.lock()
        let ids = skinTagToIds[tag] ?? []
        let infos = ids.compactMap { skinInfoMap[$0] }
        lock.unlock()
        return infos
    }
    
    public func getAllSkins() -> [UISkinInfo] {
        lock.lock()
        let infos = Array(skinInfoMap.values)
        lock.unlock()
        return infos
    }
    
    public func hasSkin(id: String) -> Bool {
        lock.lock()
        let exists = skinInfoMap[id] != nil || skins[id] != nil
        lock.unlock()
        return exists
    }

    public func isSkinDisabled(id: String) -> Bool {
        lock.lock()
        let disabled = disabledSkinIds.contains(id)
        lock.unlock()
        return disabled
    }
    
    public func setSkinDisabled(id: String, disabled: Bool) {
        lock.lock()
        if disabled {
            disabledSkinIds.insert(id)
        } else {
            disabledSkinIds.remove(id)
        }
        lock.unlock()
    }
    
    public func getSkinCount() -> Int {
        lock.lock()
        let count = skinInfoMap.count
        lock.unlock()
        return count
    }

    // MARK: - 3A. 主题注册表

    public func registerTheme(_ theme: UIThemeDefinition) {
        lock.lock()
        themes[theme.id] = theme
        lock.unlock()
        print("[UIUnifiedRegistry] Theme registered: \(theme.id)")
    }

    public func unregisterTheme(id: String) {
        lock.lock()
        let isBuiltIn = themes[id]?.isBuiltIn ?? false
        if !isBuiltIn {
            themes.removeValue(forKey: id)
            if currentThemeId == id { currentThemeId = "built-in-light" }
        }
        lock.unlock()
    }

    public func hasTheme(id: String) -> Bool {
        lock.lock()
        let exists = themes[id] != nil
        lock.unlock()
        return exists
    }

    public func getTheme(id: String) -> UIThemeDefinition? {
        lock.lock()
        let theme = themes[id]
        lock.unlock()
        return theme
    }

    public func getAllThemes() -> [UIThemeDefinition] {
        lock.lock()
        let result = Array(themes.values).sorted { $0.createdAt < $1.createdAt }
        lock.unlock()
        return result
    }

    public func getCurrentTheme() -> UIThemeDefinition? {
        lock.lock()
        let theme = themes[currentThemeId]
        lock.unlock()
        return theme
    }

    @discardableResult
    public func setCurrentTheme(id: String) -> Bool {
        lock.lock()
        guard themes[id] != nil else {
            lock.unlock()
            return false
        }
        currentThemeId = id
        lock.unlock()
        UserDefaults.standard.set(id, forKey: "com.xianrenzhilu.theme.currentThemeId")
        return true
    }

    @discardableResult
    public func applyTheme(id: String) -> Bool {
        guard setCurrentTheme(id: id) else { return false }
        UIThemeSwitchManager.shared.switchToTheme(id: id)
        return true
    }
    
    // MARK: - 4. 窗口注册表
    
    public func registerWindow(id: String, window: NSWindow, info: [String: Any]) {
        lock.lock()
        windows[id] = window
        windowInfos[id] = info
        lock.unlock()
    }
    
    public func registerWindow(record: UIWindowRecord) {
        lock.lock()
        windowRecords[record.windowID] = record
        lock.unlock()
        NotificationCenter.default.post(name: .windowDidRegister, object: record)
    }
    
    public func unregisterWindow(windowID: String) {
        lock.lock()
        let record = windowRecords[windowID]
        windowRecords.removeValue(forKey: windowID)
        windows.removeValue(forKey: windowID)
        windowInfos.removeValue(forKey: windowID)
        lock.unlock()
        if let record = record {
            NotificationCenter.default.post(name: .windowWillClose, object: record)
            NotificationCenter.default.post(name: .windowDidUnregister, object: record)
        }
    }
    
    public func getWindow(id: String) -> NSWindow? {
        lock.lock()
        let window = windows[id]
        lock.unlock()
        return window
    }
    
    public func getWindowInfo(id: String) -> [String: Any]? {
        lock.lock()
        let info = windowInfos[id]
        lock.unlock()
        return info
    }
    
    public func getUIWindowRecord(windowID: String) -> UIWindowRecord? {
        lock.lock()
        let record = windowRecords[windowID]
        lock.unlock()
        return record
    }
    
    public func getAllActiveUIWindowRecords() -> [UIWindowRecord] {
        lock.lock()
        let records = Array(windowRecords.values).filter { !$0.isClosed }
        lock.unlock()
        return records
    }
    
    public func getUIWindowRecords(for moduleName: String) -> [UIWindowRecord] {
        lock.lock()
        let records = Array(windowRecords.values).filter { $0.moduleName == moduleName && !$0.isClosed }
        lock.unlock()
        return records
    }
    
    public func getAllWindows() -> [(id: String, window: NSWindow, info: [String: Any])] {
        lock.lock()
        let all = windows.compactMap { (id, window) -> (String, NSWindow, [String: Any])? in
            guard let info = windowInfos[id] else { return nil }
            return (id, window, info)
        }
        lock.unlock()
        return all
    }
    
    public func closeWindow(id: String) -> Bool {
        lock.lock()
        guard let window = windows[id] else {
            lock.unlock()
            return false
        }
        windows.removeValue(forKey: id)
        windowInfos.removeValue(forKey: id)
        lock.unlock()
        window.close()
        return true
    }
    
    public func getWindowCount() -> Int {
        lock.lock()
        let count = windowRecords.count
        lock.unlock()
        return count
    }
    
    public func getActiveWindowCount() -> Int {
        lock.lock()
        let count = windowRecords.values.filter { !$0.isClosed }.count
        lock.unlock()
        return count
    }
    
    // MARK: - 5. 功能注册表
    
    public func registerFeature(feature: UIFeatureProtocol) {
        lock.lock()
        let name = feature.featureName
        if let old = featureRegistrations[name]?.instance as? UIFeatureProtocol {
            old.featureWillUnregister()
        }
        featureRegistrations[name] = UIFeatureRegistration(name: name, instance: feature, handler: nil)
        lock.unlock()
        feature.featureDidRegister()
    }
    
    public func registerFeature(name: String, handler: @escaping ([String: Any]?) -> Any?) {
        lock.lock()
        featureRegistrations[name] = UIFeatureRegistration(name: name, instance: nil, handler: handler)
        lock.unlock()
    }
    
    public func getFeature(name: String) -> AnyObject? {
        lock.lock()
        let instance = featureRegistrations[name]?.instance
        lock.unlock()
        return instance
    }
    
    public func callFeature(name: String, args: [String: Any]?) -> Any? {
        lock.lock()
        let handler = featureRegistrations[name]?.handler
        lock.unlock()
        return handler?(args)
    }
    
    public func unregisterFeature(name: String) {
        lock.lock()
        if let old = featureRegistrations[name]?.instance as? UIFeatureProtocol {
            old.featureWillUnregister()
        }
        featureRegistrations.removeValue(forKey: name)
        lock.unlock()
    }
    
    public func getAllFeatureNames() -> [String] {
        lock.lock()
        let names = Array(featureRegistrations.keys)
        lock.unlock()
        return names
    }
    
    public func getFeatureCount() -> Int {
        lock.lock()
        let count = featureRegistrations.count
        lock.unlock()
        return count
    }
    
    // MARK: - 6. 配置注册表
    
    public func setConfig(moduleName: String, key: String, value: Any) {
        lock.lock()
        if configs[moduleName] == nil {
            configs[moduleName] = [:]
        }
        configs[moduleName]?[key] = value
        lock.unlock()
    }
    
    public func getConfig(moduleName: String, key: String) -> Any? {
        lock.lock()
        let value = configs[moduleName]?[key]
        lock.unlock()
        return value
    }
    
    public func getAllConfigs(moduleName: String) -> [String: Any] {
        lock.lock()
        let all = configs[moduleName] ?? [:]
        lock.unlock()
        return all
    }
    
    public func removeConfig(moduleName: String, key: String) {
        lock.lock()
        configs[moduleName]?.removeValue(forKey: key)
        lock.unlock()
    }
    
    public func removeAllConfigs(moduleName: String) {
        lock.lock()
        configs.removeValue(forKey: moduleName)
        lock.unlock()
    }
    
    // MARK: - 7. 状态注册表
    
    public func setState(moduleName: String, key: String, value: Any) {
        lock.lock()
        if states[moduleName] == nil {
            states[moduleName] = [:]
        }
        states[moduleName]?[key] = value
        lock.unlock()
    }
    
    public func getState(moduleName: String, key: String) -> Any? {
        lock.lock()
        let value = states[moduleName]?[key]
        lock.unlock()
        return value
    }
    
    public func getAllStates(moduleName: String) -> [String: Any] {
        lock.lock()
        let all = states[moduleName] ?? [:]
        lock.unlock()
        return all
    }
    
    public func clearState(moduleName: String) {
        lock.lock()
        states.removeValue(forKey: moduleName)
        lock.unlock()
    }
    
    public func clearAllStates() {
        lock.lock()
        states.removeAll()
        lock.unlock()
    }
    
    // MARK: - 8. 加载顺序管理
    
    public func loadModulesInOrder() -> [String] {
        lock.lock()
        let allModules = Array(modules.keys)
        let graph = dependencyGraph
        let orders = loadOrders
        lock.unlock()
        
        var visited = Set<String>()
        var result = [String]()
        var tempMark = Set<String>()
        
        func visit(_ name: String) {
            guard !visited.contains(name) else { return }
            guard !tempMark.contains(name) else { return }
            tempMark.insert(name)
            let deps = graph[name] ?? []
            for dep in deps {
                if allModules.contains(dep) {
                    visit(dep)
                }
            }
            tempMark.remove(name)
            visited.insert(name)
            result.append(name)
        }
        
        let sortedByPriority = allModules.sorted { (a, b) -> Bool in
            let pa = orders[a] ?? Int.max
            let pb = orders[b] ?? Int.max
            return pa < pb
        }
        
        for name in sortedByPriority {
            if !visited.contains(name) {
                visit(name)
            }
        }
        
        return result
    }
    
    public func getLoadOrder(moduleName: String) -> Int? {
        lock.lock()
        let order = loadOrders[moduleName]
        lock.unlock()
        return order
    }
    
    public func setLoadOrder(moduleName: String, order: Int) {
        lock.lock()
        loadOrders[moduleName] = order
        lock.unlock()
    }
    
    // MARK: - 9. 模块版本管理
    
    public func checkModuleVersion(moduleID: String) -> UIVersionStatus {
        lock.lock()
        let versionString = moduleMetadata[moduleID]?.version
        lock.unlock()
        guard let versionString else { return .unknown }
        let moduleVersion = UIVersion.parse(versionString) ?? UIVersion(major: 2, minor: 0, patch: 0)
        let systemVersion = UIVersion(major: 2, minor: 0, patch: 0)
        if moduleVersion == systemVersion {
            return .compatible
        } else if moduleVersion < systemVersion {
            return .outdated
        } else {
            return .newer
        }
    }
    
    public func getModuleVersion(moduleID: String) -> UIVersion? {
        lock.lock()
        let versionString = moduleMetadata[moduleID]?.version
        lock.unlock()
        guard let versionString else { return nil }
        return UIVersion.parse(versionString) ?? UIVersion(major: 2, minor: 0, patch: 0)
    }
    
    // MARK: - 10. 模块依赖管理
    
    public func checkDependencies(moduleID: String) -> [String] {
        guard let metadata = moduleMetadata[moduleID] else { return [] }
        return metadata.dependencies.filter { !isModuleRegistered(moduleID: $0) }
    }
    
    public func resolveDependencies(for moduleName: String) -> [String] {
        lock.lock()
        let graph = dependencyGraph
        lock.unlock()
        
        var resolved = [String]()
        var visited = Set<String>()
        var tempMark = Set<String>()
        
        func visit(_ name: String) {
            guard !visited.contains(name) else { return }
            guard !tempMark.contains(name) else { return }
            tempMark.insert(name)
            let deps = graph[name] ?? []
            for dep in deps {
                visit(dep)
            }
            tempMark.remove(name)
            visited.insert(name)
            if name != moduleName {
                resolved.append(name)
            }
        }
        
        visit(moduleName)
        return resolved
    }
    
    public func getAllDependencies() -> [String: [String]] {
        lock.lock()
        let all = dependencyGraph
        lock.unlock()
        return all
    }
    
    public func getReverseDependencies(moduleName: String) -> [String] {
        lock.lock()
        let reverse = dependencyGraph.filter { $0.value.contains(moduleName) }.map { $0.key }
        lock.unlock()
        return reverse
    }
    
    public func areAllDependenciesResolved(moduleID: String) -> Bool {
        return checkDependencies(moduleID: moduleID).isEmpty
    }
    
    // MARK: - 11. 清理
    
    public func clear() {
        lock.lock()
        modules.removeAll()
        moduleMetadata.removeAll()
        moduleRegistrations.removeAll()
        moduleAliasMap.removeAll()
        skins.removeAll()
        skinProtocols.removeAll()
        skinIdToPath.removeAll()
        skinNameToId.removeAll()
        skinTagToIds.removeAll()
        skinInfoMap.removeAll()
        disabledSkinIds.removeAll()
        themes.removeAll()
        currentThemeId = "built-in-light"
        windows.removeAll()
        windowInfos.removeAll()
        windowRecords.removeAll()
        featureRegistrations.removeAll()
        configs.removeAll()
        states.removeAll()
        loadOrders.removeAll()
        dependencyGraph.removeAll()
        lock.unlock()
    }
    
    // MARK: - 12. 健康检查
    
    public func healthCheck() -> [String: Any] {
        lock.lock()
        let moduleCount = modules.count
        let windowCount = windowRecords.count
        let skinCount = skinInfoMap.count
        let featureCount = featureRegistrations.count
        lock.unlock()
        
        return [
            "modules": moduleCount,
            "windows": windowCount,
            "skins": skinCount,
            "features": featureCount,
            "timestamp": Date()
        ]
    }
    
    public func isHealthy() -> Bool {
        lock.lock()
        let healthy = modules.count > 0 || windowRecords.count > 0
        lock.unlock()
        return healthy
    }

    // MARK: - 13. UI功能公共兼容接口
    public var allWindowRecords: [UIWindowRecord] {
        lock.lock()
        let records = Array(windowRecords.values)
        lock.unlock()
        return records
    }

    public func getWindowRecord(windowID: String) -> UIWindowRecord? {
        return getUIWindowRecord(windowID: windowID)
    }

    public func getWindowRecords() -> [UIWindowRecord] {
        lock.lock()
        let records = Array(windowRecords.values)
        lock.unlock()
        return records
    }

    public func getWindowRecords(for moduleName: String) -> [UIWindowRecord] {
        return getUIWindowRecords(for: moduleName)
    }

    @discardableResult
    public func registerWindow(windowID: String, controller: NSWindowController, moduleName: String) -> Bool {
        guard let window = controller.window else { return false }
        let record = UIWindowRecord(windowID: windowID, window: window, windowController: controller, moduleName: moduleName, creationTime: Date(), isClosed: false, frame: window.frame, zIndex: 0)
        registerWindow(record: record)
        return true
    }

    public func register(instance: AnyObject, name: String, aliases: [String], priority: Int) {
        lock.lock()
        retainedModuleInstances[name] = instance
        for alias in aliases { moduleAliasMap[alias] = name }
        loadOrders[name] = priority
        lock.unlock()
    }

    public func retain(moduleID: String, instance: AnyObject) {
        lock.lock()
        retainedModuleInstances[moduleID] = instance
        lock.unlock()
    }
}

// MARK: - ModuleCategory 优先级扩展
extension UIModuleCategory {
    var priorityValue: Int {
        switch self {
        case .framework: return 0
        case .ui: return 10
        case .skin: return 20
        case .kline: return 30
        case .indicator: return 40
        case .tool: return 50
        case .general: return 100
        }
    }
}

// MARK: - 全局便捷函数

public func registerModule(_ module: UIModuleProtocol, metadata: UIModuleMetadata) {
    UIUnifiedRegistry.shared.register(module: module, metadata: metadata)
}

public func loadModule(_ moduleID: String) throws {
    try UIUnifiedRegistry.shared.loadModule(moduleID: moduleID)
}

public func unloadModule(_ moduleID: String) throws {
    try UIUnifiedRegistry.shared.unloadModule(moduleID: moduleID)
}

public func registerSkin(_ info: UISkinInfo, protocol skin: UISkinProtocol) {
    UIUnifiedRegistry.shared.registerSkin(info, protocol: skin)
}

public func applySkin(id: String) throws {
    _ = UIUnifiedRegistry.shared.applySkin(id: id)
}

public func getCurrentSkin() -> UISkinInfo? {
    return UIUnifiedRegistry.shared.getCurrentSkin()
}

public func getAllSkins() -> [UISkinInfo] {
    return UIUnifiedRegistry.shared.getAllSkins()
}

public func registerTheme(_ theme: UIThemeDefinition) {
    UIUnifiedRegistry.shared.registerTheme(theme)
}

public func applyTheme(id: String) -> Bool {
    return UIUnifiedRegistry.shared.applyTheme(id: id)
}

public func getCurrentTheme() -> UIThemeDefinition? {
    return UIUnifiedRegistry.shared.getCurrentTheme()
}

public func getAllThemes() -> [UIThemeDefinition] {
    return UIUnifiedRegistry.shared.getAllThemes()
}

public func registerWindow(id: String, window: NSWindow, info: [String: Any]) {
    UIUnifiedRegistry.shared.registerWindow(id: id, window: window, info: info)
}

public func getWindow(id: String) -> NSWindow? {
    return UIUnifiedRegistry.shared.getWindow(id: id)
}

public func closeWindow(id: String) -> Bool {
    return UIUnifiedRegistry.shared.closeWindow(id: id)
}

public func setModuleConfig(moduleName: String, key: String, value: Any) {
    UIUnifiedRegistry.shared.setConfig(moduleName: moduleName, key: key, value: value)
}

public func getModuleConfig(moduleName: String, key: String) -> Any? {
    return UIUnifiedRegistry.shared.getConfig(moduleName: moduleName, key: key)
}

public func removeModuleConfig(moduleName: String, key: String) {
    UIUnifiedRegistry.shared.removeConfig(moduleName: moduleName, key: key)
}

public func setModuleState(moduleName: String, key: String, value: Any) {
    UIUnifiedRegistry.shared.setState(moduleName: moduleName, key: key, value: value)
}

public func getModuleState(moduleName: String, key: String) -> Any? {
    return UIUnifiedRegistry.shared.getState(moduleName: moduleName, key: key)
}

public func clearModuleState(moduleName: String) {
    UIUnifiedRegistry.shared.clearState(moduleName: moduleName)
}

public func loadModulesInOrder() -> [String] {
    return UIUnifiedRegistry.shared.loadModulesInOrder()
}

public func checkModuleVersion(moduleID: String) -> UIVersionStatus {
    return UIUnifiedRegistry.shared.checkModuleVersion(moduleID: moduleID)
}

public func getModuleVersion(moduleID: String) -> UIVersion? {
    return UIUnifiedRegistry.shared.getModuleVersion(moduleID: moduleID)
}

public func checkDependencies(moduleID: String) -> [String] {
    return UIUnifiedRegistry.shared.checkDependencies(moduleID: moduleID)
}

public func resolveDependencies(for moduleName: String) -> [String] {
    return UIUnifiedRegistry.shared.resolveDependencies(for: moduleName)
}

// MARK: - 通知名称扩展（已在UI-02定义，此处不再重复）
// public extension Notification.Name {
//     static let windowDidRegister = Notification.Name("com.xianrenzhilu.registry.windowDidRegister")
//     static let windowWillClose = Notification.Name("com.xianrenzhilu.registry.windowWillClose")
//     static let windowDidUnregister = Notification.Name("com.xianrenzhilu.registry.windowDidUnregister")
// }

// MARK: - UI功能70项统一注册
// 第三阶段：70个 UI-GL 功能统一注册到 UI-01_统一注册表.swift
// 版本: 2.0

public struct UIFunctionFeatureDescriptor: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let fileName: String
    public let priority: String
    public let testFunctionName: String?
}

public let uiFunctionFeatureDescriptors: [UIFunctionFeatureDescriptor] = [
    UIFunctionFeatureDescriptor(id: "UI-GL-01", title: "窗口位置与状态持久化", fileName: "UI-GL-01_窗口位置与状态持久化.swift", priority: "P0", testFunctionName: "test_windowPersistence"),
    UIFunctionFeatureDescriptor(id: "UI-GL-02", title: "多屏幕支持", fileName: "UI-GL-02_多屏幕支持.swift", priority: "P1", testFunctionName: "test_multiScreen"),
    UIFunctionFeatureDescriptor(id: "UI-GL-03", title: "窗口动画效果", fileName: "UI-GL-03_窗口动画效果.swift", priority: "P0", testFunctionName: "test_windowAnimation"),
    UIFunctionFeatureDescriptor(id: "UI-GL-04", title: "窗口克隆", fileName: "UI-GL-04_窗口克隆.swift", priority: "P1", testFunctionName: "test_windowClone"),
    UIFunctionFeatureDescriptor(id: "UI-GL-05", title: "窗口玻璃效果", fileName: "UI-GL-05_窗口玻璃效果.swift", priority: "P1", testFunctionName: nil),
    UIFunctionFeatureDescriptor(id: "UI-GL-06", title: "视图容器协议", fileName: "UI-GL-06_视图容器协议.swift", priority: "P0", testFunctionName: "test_containerView"),
    UIFunctionFeatureDescriptor(id: "UI-GL-07", title: "窗口阴影自定义", fileName: "UI-GL-07_窗口阴影自定义.swift", priority: "P3", testFunctionName: "test_windowShadow"),
    UIFunctionFeatureDescriptor(id: "UI-GL-08", title: "面板类型系统", fileName: "UI-GL-08_面板类型系统.swift", priority: "P0", testFunctionName: "test_panelType"),
    UIFunctionFeatureDescriptor(id: "UI-GL-09", title: "窗口背景与边框", fileName: "UI-GL-09_窗口背景与边框.swift", priority: "P1", testFunctionName: "test_windowBackground"),
    UIFunctionFeatureDescriptor(id: "UI-GL-10", title: "面板停靠吸附", fileName: "UI-GL-10_面板停靠吸附.swift", priority: "P1", testFunctionName: "test_panelDock"),
    UIFunctionFeatureDescriptor(id: "UI-GL-11", title: "窗口工具栏", fileName: "UI-GL-11_窗口工具栏.swift", priority: "P0", testFunctionName: "test_windowToolbar"),
    UIFunctionFeatureDescriptor(id: "UI-GL-12", title: "面板自动隐藏", fileName: "UI-GL-12_面板自动隐藏.swift", priority: "P1", testFunctionName: nil),
    UIFunctionFeatureDescriptor(id: "UI-GL-13", title: "透明度控制", fileName: "UI-GL-13_透明度控制.swift", priority: "P1", testFunctionName: "test_windowOpacity"),
    UIFunctionFeatureDescriptor(id: "UI-GL-14", title: "主题皮肤系统", fileName: "UI-GL-14_主题皮肤系统.swift", priority: "P1", testFunctionName: "test_themeManager"),
    UIFunctionFeatureDescriptor(id: "UI-GL-15", title: "窗口最小化行为自定义", fileName: "UI-GL-15_窗口最小化行为自定义.swift", priority: "P2", testFunctionName: "test_windowMinimize"),
    UIFunctionFeatureDescriptor(id: "UI-GL-16", title: "工具栏管理器", fileName: "UI-GL-16_工具栏管理器.swift", priority: "P0", testFunctionName: "test_toolbarManager"),
    UIFunctionFeatureDescriptor(id: "UI-GL-17", title: "窗口大小与位置限制", fileName: "UI-GL-17_窗口大小与位置限制.swift", priority: "P2", testFunctionName: "test_windowSizeRestriction"),
    UIFunctionFeatureDescriptor(id: "UI-GL-18", title: "工具栏可定制", fileName: "UI-GL-18_工具栏可定制.swift", priority: "P2", testFunctionName: "test_toolbarCustomization"),
    UIFunctionFeatureDescriptor(id: "UI-GL-19", title: "窗口拖拽行为管理", fileName: "UI-GL-19_窗口拖拽行为管理.swift", priority: "P2", testFunctionName: nil),
    UIFunctionFeatureDescriptor(id: "UI-GL-20", title: "主菜单管理器", fileName: "UI-GL-20_主菜单管理器.swift", priority: "P0", testFunctionName: "test_mainMenu"),
    UIFunctionFeatureDescriptor(id: "UI-GL-21", title: "窗口全屏管理", fileName: "UI-GL-21_窗口全屏管理.swift", priority: "P0", testFunctionName: "test_windowFullscreen"),
    UIFunctionFeatureDescriptor(id: "UI-GL-22", title: "快捷键系统", fileName: "UI-GL-22_快捷键系统.swift", priority: "P1", testFunctionName: "test_keyBinding"),
    UIFunctionFeatureDescriptor(id: "UI-GL-23", title: "窗口布局管理", fileName: "UI-GL-23_窗口布局管理.swift", priority: "P2", testFunctionName: "test_UI16B"),
    UIFunctionFeatureDescriptor(id: "UI-GL-24", title: "窗口标签化（Tab管理）", fileName: "UI-GL-24_窗口标签化（Tab管理）.swift", priority: "P1", testFunctionName: "test_UI12"),
    UIFunctionFeatureDescriptor(id: "UI-GL-25", title: "模块间通信协议", fileName: "UI-GL-25_模块间通信协议.swift", priority: "P0", testFunctionName: "test_communication"),
    UIFunctionFeatureDescriptor(id: "UI-GL-26", title: "窗口悬浮与置顶", fileName: "UI-GL-26_窗口悬浮与置顶.swift", priority: "P0", testFunctionName: "test_UI11A"),
    UIFunctionFeatureDescriptor(id: "UI-GL-27", title: "窗口分组管理", fileName: "UI-GL-27_窗口分组管理.swift", priority: "P2", testFunctionName: "test_windowGroup"),
    UIFunctionFeatureDescriptor(id: "UI-GL-28", title: "状态持久化", fileName: "UI-GL-28_状态持久化.swift", priority: "P1", testFunctionName: "test_persistence"),
    UIFunctionFeatureDescriptor(id: "UI-GL-29", title: "撤销重做系统", fileName: "UI-GL-29_撤销重做系统.swift", priority: "P2", testFunctionName: "test_undoRedo"),
    UIFunctionFeatureDescriptor(id: "UI-GL-30", title: "视图渲染优化", fileName: "UI-GL-30_视图渲染优化.swift", priority: "P1", testFunctionName: "test_renderOptimizer"),
    UIFunctionFeatureDescriptor(id: "UI-GL-31", title: "异步加载器", fileName: "UI-GL-31_异步加载器.swift", priority: "P1", testFunctionName: "test_asyncLoader"),
    UIFunctionFeatureDescriptor(id: "UI-GL-32", title: "内存警告处理", fileName: "UI-GL-32_内存警告处理.swift", priority: "P2", testFunctionName: "test_memoryWarning"),
    UIFunctionFeatureDescriptor(id: "UI-GL-33", title: "模块热加载", fileName: "UI-GL-33_模块热加载.swift", priority: "P2", testFunctionName: "test_hotLoad"),
    UIFunctionFeatureDescriptor(id: "UI-GL-34", title: "模块沙盒隔离", fileName: "UI-GL-34_模块沙盒隔离.swift", priority: "P2", testFunctionName: "test_sandbox"),
    UIFunctionFeatureDescriptor(id: "UI-GL-35", title: "日志记录", fileName: "UI-GL-35_日志记录.swift", priority: "P0", testFunctionName: "test_uilog"),
    UIFunctionFeatureDescriptor(id: "UI-GL-36", title: "开发者工具面板", fileName: "UI-GL-36_开发者工具面板.swift", priority: "P3", testFunctionName: "test_devTools"),
    UIFunctionFeatureDescriptor(id: "UI-GL-37", title: "脚本引擎", fileName: "UI-GL-37_脚本引擎.swift", priority: "P2", testFunctionName: "test_scriptEngine"),
    UIFunctionFeatureDescriptor(id: "UI-GL-38", title: "模块独立性", fileName: "UI-GL-38_模块独立性.swift", priority: "P0", testFunctionName: "test_moduleIndependence"),
    UIFunctionFeatureDescriptor(id: "UI-GL-39", title: "插件管理器", fileName: "UI-GL-39_插件管理器.swift", priority: "P1", testFunctionName: "test_pluginManager"),
    UIFunctionFeatureDescriptor(id: "UI-GL-40", title: "嵌套分割视图", fileName: "UI-GL-40_嵌套分割视图.swift", priority: "P0", testFunctionName: "test_nestedSplitView"),
    UIFunctionFeatureDescriptor(id: "UI-GL-41", title: "布局管理器", fileName: "UI-GL-41_布局管理器.swift", priority: "P1", testFunctionName: "test_layoutManager"),
    UIFunctionFeatureDescriptor(id: "UI-GL-42", title: "布局序列化与恢复", fileName: "UI-GL-42_布局序列化与恢复.swift", priority: "P1", testFunctionName: "test_uiSerialization"),
    UIFunctionFeatureDescriptor(id: "UI-GL-43", title: "字体管理器", fileName: "UI-GL-43_字体管理器.swift", priority: "P1", testFunctionName: "test_fontManager"),
    UIFunctionFeatureDescriptor(id: "UI-GL-44", title: "视图组", fileName: "UI-GL-44_视图组.swift", priority: "P2", testFunctionName: "test_viewGroup"),
    UIFunctionFeatureDescriptor(id: "UI-GL-45", title: "布局模板市场", fileName: "UI-GL-45_布局模板市场.swift", priority: "P3", testFunctionName: "test_layoutMarket"),
    UIFunctionFeatureDescriptor(id: "UI-GL-46", title: "多行标签页", fileName: "UI-GL-46_多行标签页.swift", priority: "P1", testFunctionName: "test_multiLineTab"),
    UIFunctionFeatureDescriptor(id: "UI-GL-47", title: "标签页脱离合并", fileName: "UI-GL-47_标签页脱离合并.swift", priority: "P2", testFunctionName: "test_tabDrag"),
    UIFunctionFeatureDescriptor(id: "UI-GL-48", title: "标签页预览", fileName: "UI-GL-48_标签页预览.swift", priority: "P3", testFunctionName: "test_tabPreview"),
    UIFunctionFeatureDescriptor(id: "UI-GL-49", title: "标签页分组", fileName: "UI-GL-49_标签页分组.swift", priority: "P2", testFunctionName: "test_tabGroup"),
    UIFunctionFeatureDescriptor(id: "UI-GL-50", title: "固定标签页", fileName: "UI-GL-50_固定标签页.swift", priority: "P2", testFunctionName: "test_pinnedTab"),
    UIFunctionFeatureDescriptor(id: "UI-GL-51", title: "时间轴缩放控件", fileName: "UI-GL-51_时间轴缩放控件.swift", priority: "P1", testFunctionName: "test_timelineZoom"),
    UIFunctionFeatureDescriptor(id: "UI-GL-52", title: "十字光标跨窗口联动", fileName: "UI-GL-52_十字光标跨窗口联动.swift", priority: "P2", testFunctionName: "test_crosshair"),
    UIFunctionFeatureDescriptor(id: "UI-GL-53", title: "画线工具库与模板", fileName: "UI-GL-53_画线工具库与模板.swift", priority: "P2", testFunctionName: "test_drawing"),
    UIFunctionFeatureDescriptor(id: "UI-GL-54", title: "图表叠加模式", fileName: "UI-GL-54_图表叠加模式.swift", priority: "P2", testFunctionName: "test_overlay"),
    UIFunctionFeatureDescriptor(id: "UI-GL-55", title: "历史数据回放模式", fileName: "UI-GL-55_历史数据回放模式.swift", priority: "P2", testFunctionName: "test_replay"),
    UIFunctionFeatureDescriptor(id: "UI-GL-56", title: "停靠系统", fileName: "UI-GL-56_停靠系统.swift", priority: "P1", testFunctionName: "test_docking"),
    UIFunctionFeatureDescriptor(id: "UI-GL-57", title: "固定机制", fileName: "UI-GL-57_固定机制.swift", priority: "P2", testFunctionName: "test_pinning"),
    UIFunctionFeatureDescriptor(id: "UI-GL-58", title: "面板分组", fileName: "UI-GL-58_面板分组.swift", priority: "P2", testFunctionName: "test_panelGroup"),
    UIFunctionFeatureDescriptor(id: "UI-GL-59", title: "自动隐藏区域", fileName: "UI-GL-59_自动隐藏区域.swift", priority: "P2", testFunctionName: "test_autoHide"),
    UIFunctionFeatureDescriptor(id: "UI-GL-60", title: "浮动窗口平铺管理", fileName: "UI-GL-60_浮动窗口平铺管理.swift", priority: "P2", testFunctionName: "test_tiling"),
    UIFunctionFeatureDescriptor(id: "UI-GL-61", title: "离屏渲染与缓存", fileName: "UI-GL-61_离屏渲染与缓存.swift", priority: "P2", testFunctionName: "test_offscreenRender"),
    UIFunctionFeatureDescriptor(id: "UI-GL-62", title: "帧率自适应", fileName: "UI-GL-62_帧率自适应.swift", priority: "P2", testFunctionName: "test_frameRate"),
    UIFunctionFeatureDescriptor(id: "UI-GL-63", title: "增量渲染", fileName: "UI-GL-63_增量渲染.swift", priority: "P2", testFunctionName: "test_incrementalRender"),
    UIFunctionFeatureDescriptor(id: "UI-GL-64", title: "图表数据虚拟滚动", fileName: "UI-GL-64_图表数据虚拟滚动.swift", priority: "P1", testFunctionName: "test_virtualScroll"),
    UIFunctionFeatureDescriptor(id: "UI-GL-65", title: "完整键盘导航", fileName: "UI-GL-65_完整键盘导航.swift", priority: "P2", testFunctionName: "test_keyboardNav"),
    UIFunctionFeatureDescriptor(id: "UI-GL-66", title: "VoiceOver支持", fileName: "UI-GL-66_VoiceOver支持.swift", priority: "P3", testFunctionName: "test_voiceOver"),
    UIFunctionFeatureDescriptor(id: "UI-GL-67", title: "高对比度模式", fileName: "UI-GL-67_高对比度模式.swift", priority: "P3", testFunctionName: "test_highContrast"),
    UIFunctionFeatureDescriptor(id: "UI-GL-68", title: "动态字体与缩放", fileName: "UI-GL-68_动态字体与缩放.swift", priority: "P2", testFunctionName: "test_dynamicFont"),
    UIFunctionFeatureDescriptor(id: "UI-GL-69", title: "颜色盲模式", fileName: "UI-GL-69_颜色盲模式.swift", priority: "P3", testFunctionName: "test_colorBlind"),
    UIFunctionFeatureDescriptor(id: "UI-GL-70", title: "命令面板", fileName: "UI-GL-70_命令面板.swift", priority: "P1", testFunctionName: "test_commandPalette"),
]

@discardableResult
public func registerAllUIFunctionFeatures() -> Int {
    let registry = UIUnifiedRegistry.shared
    for descriptor in uiFunctionFeatureDescriptors {
        registry.registerFeature(name: descriptor.id) { args in
            let action = args?["action"] as? String ?? "metadata"
            switch action {
            case "metadata", "describe":
                return [
                    "id": descriptor.id,
                    "title": descriptor.title,
                    "fileName": descriptor.fileName,
                    "priority": descriptor.priority,
                    "testFunctionName": descriptor.testFunctionName as Any,
                    "version": "2.0"
                ]
            default:
                return [
                    "id": descriptor.id,
                    "status": "registered",
                    "message": "该功能已注册到 UI-01，实际入口由 UI-00 在第四阶段对接。"
                ]
            }
        }
    }
    return registry.getFeatureCount()
}

public func registeredUIFunctionFeatureIDs() -> [String] {
    return uiFunctionFeatureDescriptors.map { $0.id }
}

// MARK: - UI功能实例注册表
public final class UIFunctionRegistry : @unchecked Sendable {
    public static let shared = UIFunctionRegistry()
    private var namedInstances: [String: AnyObject] = [:]
    private let lock = NSLock()

    private init() {}

    public func register(feature: UIFeatureProtocol) {
        register(name: feature.featureName, instance: feature)
    }

    public func register(name: String, instance: AnyObject) {
        lock.lock()
        defer { lock.unlock() }
        namedInstances[name] = instance
    }

    public func unregisterAll() {
        lock.lock()
        defer { lock.unlock() }
        namedInstances.removeAll()
    }
}

// MARK: - UI窗口注册表兼容入口
public final class UIWindowRegistry : @unchecked Sendable {
    public static let shared = UIWindowRegistry()
    private init() {}

    public func record(for windowID: String) -> UIWindowRecord? {
        UIUnifiedRegistry.shared.getWindowRecord(windowID: windowID)
    }

    public func isRegistered(_ windowID: String) -> Bool {
        UIUnifiedRegistry.shared.getWindowRecord(windowID: windowID) != nil
    }

    public func windowContaining(point: NSPoint, excluding excludedID: String? = nil) -> (String, NSWindow)? {
        for record in UIUnifiedRegistry.shared.getWindowRecords() {
            guard record.windowID != excludedID else { continue }
            if record.window.frame.contains(point) {
                return (record.windowID, record.window)
            }
        }
        return nil
    }

    public func register(window: NSWindow, id: String) {
        let record = UIWindowRecord(
            windowID: id,
            window: window,
            windowController: window.windowController,
            moduleName: "unknown",
            creationTime: Date(),
            isClosed: false,
            frame: window.frame,
            zIndex: window.level.rawValue
        )
        UIUnifiedRegistry.shared.registerWindow(record: record)
        // 窗口注册后，自动应用当前皮肤
        if let currentSkin = UIUnifiedRegistry.shared.getCurrentSkin(),
           let skinProtocol = UIUnifiedRegistry.shared.getSkinProtocol(id: currentSkin.id) {
            skinProtocol.apply(to: window)
        }
    }
}
