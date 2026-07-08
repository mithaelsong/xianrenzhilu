// 对应: 将模块抛出的异常/崩溃限制在自身范围内，不影响主进程
// 优先级: P1

import Foundation
import os

// MARK: - 崩溃隔离器
public final class KJCrashIsolator : @unchecked Sendable {
    
    public static let shared = KJCrashIsolator()
    
    public var thresholdCrashCount: Int = 3
    
    private var _crashRecords: [KJCrashRecord] = []
    private var _disabledModules: Set<String> = []
    private var _crashCounts: [String: Int] = [:]
    private var lock = os_unfair_lock()
    
    private init() {}
    
    public var crashRecords: [KJCrashRecord] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _crashRecords
    }
    
    public var disabledModules: [String] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return Array(_disabledModules)
    }
    
    @discardableResult
    public func execute<T>(moduleName: String, closure: () throws -> T) -> Result<T, KJCrashError> {
        os_unfair_lock_lock(&lock)
        let isDisabled = _disabledModules.contains(moduleName)
        os_unfair_lock_unlock(&lock)
        
        if isDisabled {
            return .failure(.moduleDisabled(moduleName: moduleName))
        }
        
        do {
            let result = try closure()
            return .success(result)
        } catch {
            let record = KJCrashRecord(
                moduleID: moduleName,
                error: String(describing: error),
                timestamp: Date()
            )
            
            os_unfair_lock_lock(&lock)
            _crashRecords.append(record)
            _crashCounts[moduleName, default: 0] += 1
            let currentCount = _crashCounts[moduleName] ?? 0
            if currentCount >= thresholdCrashCount {
                _disabledModules.insert(moduleName)
            }
            os_unfair_lock_unlock(&lock)
            
            return .failure(.moduleCrashed(moduleName: moduleName, underlyingError: String(describing: error)))
        }
    }
    
    public func crashCount(for moduleName: String) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _crashCounts[moduleName] ?? 0
    }
    
    @discardableResult
    public func autoDisableModule(moduleName: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        let wasDisabled = _disabledModules.insert(moduleName).inserted
        return wasDisabled
    }
    
    @discardableResult
    public func enableModule(moduleName: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        let wasEnabled = _disabledModules.remove(moduleName) != nil
        if wasEnabled {
            _crashCounts[moduleName] = 0
        }
        return wasEnabled
    }
    
    public func resetCrashRecords() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        _crashRecords.removeAll()
        _crashCounts.removeAll()
        _disabledModules.removeAll()
    }
    
    public func crashRecords(for moduleName: String) -> [KJCrashRecord] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _crashRecords.filter { $0.moduleID == moduleName }
    }
    
    public func isModuleDisabled(_ moduleName: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _disabledModules.contains(moduleName)
    }
}

