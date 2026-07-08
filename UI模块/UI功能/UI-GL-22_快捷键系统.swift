// 功能16A: 快捷键系统
// 对应: 模块可注册全局/局部快捷键，支持冲突检测；用户可自定义修改
// 版本: 2.0
// 优先级: P1

import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "16A_快捷键系统")

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能16A：快捷键系统 — 单元测试
/// 覆盖：注册/冲突检测/查询/自定义/重置/持久化
@MainActor
func test_keyBinding() {
    print("\n🧪 测试1: 注册快捷键")
    let manager = UIKeyBindingManager.shared
    let binding1 = UIKeyBinding(identifier: "test.open", moduleName: "测试模块",
                               keyEquivalent: "o", modifierFlags: .command,
                               actionDescription: "打开测试")
    let result1 = manager.register(binding1)
    guard case .success = result1 else {
        fatalError("❌ 测试1失败: 注册应成功")
    }
    print("✅ 测试1通过: 注册成功")
    
    print("\n🧪 测试2: 冲突检测")
    let binding2 = UIKeyBinding(identifier: "test.save", moduleName: "测试模块",
                               keyEquivalent: "o", modifierFlags: .command,
                               actionDescription: "保存测试")
    let result2 = manager.register(binding2)
    guard case .conflict(existingIdentifier: _, description: _) = result2 else {
        fatalError("❌ 测试2失败: 冲突应被检测到")
    }
    print("✅ 测试2通过: 冲突检测正确")
    
    print("\n🧪 测试3: 按模块查询")
    let bindings = manager.bindings(for: "测试模块")
    guard bindings.count >= 1 else {
        fatalError("❌ 测试3失败: 应有至少1个快捷键")
    }
    print("✅ 测试3通过: 模块查询返回\(bindings.count)项")
    
    print("\n🧪 测试4: 注销快捷键")
    manager.unregister(identifier: "test.save")
    let afterUnregister = manager.bindings(for: "测试模块")
    guard afterUnregister.count == 1 else {
        fatalError("❌ 测试4失败: 注销后应为1项")
    }
    print("✅ 测试4通过: 注销正确")
    
    print("\n🧪 测试5: 自定义快捷键")
    let customResult = manager.customize(identifier: "test.open", keyEquivalent: "e",
                                          modifierFlags: [.command, .shift])
    guard case .success = customResult else {
        fatalError("❌ 测试5失败: 自定义应成功")
    }
    print("✅ 测试5通过: 自定义成功")
    
    print("\n🧪 测试6: 显示字符串")
    let str = manager.keyString(binding1)
    guard !str.isEmpty else {
        fatalError("❌ 测试6失败: 显示字符串不应为空")
    }
    print("✅ 测试6通过: 显示字符串=\(str)")
    
    print("\n🧪 测试7: 未找到标识符")
    let notFoundResult = manager.customize(identifier: "nonexistent", keyEquivalent: "x",
                                            modifierFlags: .command)
    guard case .notFound = notFoundResult else {
        fatalError("❌ 测试7失败: 不存在标识符应返回notFound")
    }
    print("✅ 测试7通过: 不存在的标识符返回notFound")
    
    print("\n=== 全部快捷键系统测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIKeyBindingManager
public final class UIKeyBindingManager : @unchecked Sendable {
    
    public static let shared = UIKeyBindingManager()
    
    /// 所有已注册的快捷键
    private var bindings: [String: UIKeyBinding] = [:]
    
    private let lock = NSRecursiveLock()
    private let saveKey = "com.xianrenzhilu.keyBindings"
    private let defaults: UserDefaults
    
    private init() {
        self.defaults = UserDefaults.standard
        loadCustomBindings()
    }
    
    /// 获取所有已注册的快捷键（只读副本）
    public func allBindings() -> [String: UIKeyBinding] {
        lock.lock()
        let result = bindings
        lock.unlock()
        return result
    }
    
    // MARK: - 注册快捷键
    
    /// 注册快捷键
    /// - Parameter binding: 快捷键定义
    /// - Returns: 注册结果（成功/冲突）
    @discardableResult
    public func register(_ binding: UIKeyBinding) -> UIKeyBindingResult {
        lock.lock()
        
        // 冲突检测
        for (_, existing) in bindings where existing.identifier != binding.identifier {
            if existing.keyEquivalent == binding.keyEquivalent &&
                existing.modifierFlags == binding.modifierFlags {
                lock.unlock()
                return .conflict(existingIdentifier: existing.identifier,
                                 description: existing.actionDescription)
            }
        }
        
        bindings[binding.identifier] = binding
        lock.unlock()
        logger.info("已注册: \(binding.actionDescription) (\(self.keyString(binding)))")
        return .success
    }
    
    /// 注销快捷键
    public func unregister(identifier: String) {
        lock.lock()
        bindings.removeValue(forKey: identifier)
        lock.unlock()
        logger.info("已注销: \(identifier)")
    }
    
    // MARK: - 用户自定义
    
    /// 用户修改快捷键
    public func customize(identifier: String, keyEquivalent: String, modifierFlags: NSEvent.ModifierFlags) -> UIKeyBindingResult {
        lock.lock()
        guard var binding = bindings[identifier] else {
            lock.unlock()
            return .notFound
        }
        
        // 冲突检测
        for (_, existing) in bindings where existing.identifier != identifier {
            if existing.keyEquivalent == keyEquivalent && existing.modifierFlags == modifierFlags.rawValue {
                lock.unlock()
                return .conflict(existingIdentifier: existing.identifier,
                                 description: existing.actionDescription)
            }
        }
        
        binding.keyEquivalent = keyEquivalent
        binding.modifierFlags = modifierFlags.rawValue
        bindings[identifier] = binding
        lock.unlock()
        
        saveCustomBindings()
        logger.info("已自定义: \(binding.actionDescription) -> \(self.keyString(binding))")
        return .success
    }
    
    /// 重置所有快捷键为默认
    public func resetAll() {
        lock.lock()
        for id in bindings.keys {
            bindings[id]?.isEnabled = true
        }
        lock.unlock()
        defaults.removeObject(forKey: saveKey)
        logger.info("已重置为默认")
    }
    
    // MARK: - 查询
    
    /// 获取模块的所有快捷键
    public func bindings(for moduleName: String) -> [UIKeyBinding] {
        lock.lock()
        let result = bindings.values.filter { $0.moduleName == moduleName && $0.isEnabled }
        lock.unlock()
        return Array(result)
    }
    
    /// 获取快捷键的显示字符串
    public func keyString(_ binding: UIKeyBinding) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: binding.modifierFlags)
        var parts: [String] = []
        if flags.contains(.command)  { parts.append("⌘") }
        if flags.contains(.shift)    { parts.append("⇧") }
        if flags.contains(.option)   { parts.append("⌥") }
        if flags.contains(.control)  { parts.append("⌃") }
        parts.append(binding.keyEquivalent.uppercased())
        return parts.joined()
    }
    
    // MARK: - 持久化
    
    private func saveCustomBindings() {
        lock.lock()
        let data = try? JSONEncoder().encode(bindings)
        lock.unlock()
        if let data = data {
            defaults.set(data, forKey: saveKey)
        } else {
            logger.error("快捷键持久化编码失败")
        }
    }
    
    private func loadCustomBindings() {
        guard let data = defaults.data(forKey: saveKey) else {
            return
        }
        guard let loaded = try? JSONDecoder().decode([String: UIKeyBinding].self, from: data) else {
            logger.error("快捷键持久化数据解码失败")
            return
        }
        lock.lock()
        for (id, binding) in loaded {
            if bindings[id] != nil {
                bindings[id] = binding
            }
        }
        lock.unlock()
    }
}
