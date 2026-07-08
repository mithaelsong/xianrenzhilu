// 功能23: 本地化支持 (KJLocalizationManager)
// 对应: 支持多语言（Localizable.strings）
// 优先级: P2
// 平台: macOS / Foundation + AppKit

import Foundation
import AppKit
import os

// MARK: - 语言变更通知定义
public extension Notification.Name {
    /// 语言发生变更时发送的通知，userInfo 包含 ["language": String]
    static let localizationLanguageChanged = Notification.Name(
        "com.xianrenzhilu.localization.languageChanged"
    )
}

// MARK: - 本地化错误（使用公共类型 KJModuleError）

// MARK: - KJLocalizationManager
/// 本地化管理器单例
/// 管理应用多语言本地化，支持动态语言切换、格式化字符串、线程安全
public final class KJLocalizationManager : @unchecked Sendable {

    // MARK: - 单例
    public static let shared = KJLocalizationManager()

    // MARK: - 线程安全锁
    /// 使用 os_unfair_lock 保证轻量级线程安全
    private var unfairLock = os_unfair_lock()

    // MARK: - 内部状态
    /// 当前语言标识符，如 "zh-Hans", "en", "ja"
    private var _currentLanguage: String

    /// 已注册的模块 Bundle，key 为模块标识
    private var bundles: [String: Bundle] = [:]

    /// 已加载的语言 Bundle 缓存，key 为 "bundlePath_language"
    private var languageBundles: [String: Bundle] = [:]

    /// 支持的语言列表
    private let _availableLanguages: [String]

    // MARK: - 初始化
    private init() {

        // 默认支持的语言
        self._availableLanguages = ["zh-Hans", "zh-Hant", "en", "ja", "ko", "fr", "de", "es", "ru"]

        // 从 UserDefaults 读取已保存的语言偏好
        if let saved = UserDefaults.standard.string(forKey: KJLocalizationKey.savedLanguage),
           _availableLanguages.contains(saved) {
            self._currentLanguage = saved
        } else {
            // 匹配系统首选语言
            self._currentLanguage = KJLocalizationManager.matchSystemLanguage(
                preferred: Locale.preferredLanguages,
                available: _availableLanguages
            )
        }
    }

    // MARK: - 语言列表
    /// 获取当前支持的所有语言标识符列表
    public var availableLanguages: [String] {
        lock()
        defer { unlock() }
        return _availableLanguages
    }

    // MARK: - 当前语言
    /// 获取当前语言标识符
    public var currentLanguage: String {
        lock()
        defer { unlock() }
        return _currentLanguage
    }

    // MARK: - 设置语言
    /// 切换当前语言
    /// - Parameter identifier: 目标语言标识符，如 "zh-Hans", "en"
    /// - Returns: 切换是否成功
    @discardableResult
    public func setLanguage(_ identifier: String) -> Bool {
        lock()

        // 检查是否已经是当前语言
        guard _currentLanguage != identifier else {
            unlock()
            return true
        }

        // 检查语言是否在支持列表中
        guard _availableLanguages.contains(identifier) else {
            unlock()
            return false
        }

        // 执行切换
        _currentLanguage = identifier

        // 持久化到 UserDefaults
        UserDefaults.standard.set(identifier, forKey: KJLocalizationKey.savedLanguage)
        UserDefaults.standard.synchronize()

        unlock()

        // 发送全局通知（在锁外发送，避免死锁）
        NotificationCenter.default.post(
            name: .localizationLanguageChanged,
            object: self,
            userInfo: [KJLocalizationKey.notificationLanguage: identifier]
        )

        return true
    }

    // MARK: - 获取本地化字符串
    /// 获取本地化字符串，支持格式化参数
    /// - Parameters:
    ///   - key: 本地化键名
    ///   - table: 本地化表名（如 "Localizable", "Main"），nil 时默认 "Localizable"
    ///   - bundle: 自定义 Bundle，nil 时使用主 Bundle
    ///   - arguments: 格式化参数，用于 %@ / %d 等占位符
    /// - Returns: 本地化后的字符串；若未找到则返回 key 本身
    public func localizedString(
        key: String,
        table: String? = nil,
        bundle: Bundle? = nil,
        arguments: [CVarArg] = []
    ) -> String {
        let resolvedBundle: Bundle

        if let customBundle = bundle {
            resolvedBundle = resolveLanguageBundle(from: customBundle)
        } else {
            resolvedBundle = resolveLanguageBundle(from: Bundle.main)
        }

        let resolvedTable = table ?? "Localizable"

        let rawString = resolvedBundle.localizedString(
            forKey: key,
            value: key,
            table: resolvedTable
        )

        if arguments.isEmpty {
            return rawString
        } else {
            return String(format: rawString, arguments: arguments)
        }
    }

    // MARK: - Bundle 管理
    /// 为指定模块注册一个 Bundle（用于模块化本地化）
    /// - Parameters:
    ///   - bundle: 模块的 Bundle
    ///   - module: 模块标识名称
    public func registerBundle(_ bundle: Bundle, for module: String) {
        lock()
        bundles[module] = bundle
        unlock()
    }

    /// 获取已注册的模块 Bundle
    public func bundle(for module: String) -> Bundle? {
        lock()
        defer { unlock() }
        return bundles[module]
    }

    /// 移除已注册的模块 Bundle
    @discardableResult
    public func unregisterBundle(for module: String) -> Bundle? {
        lock()
        defer { unlock() }
        return bundles.removeValue(forKey: module)
    }

    /// 清空所有注册的模块 Bundle
    public func unregisterAllBundles() {
        lock()
        bundles.removeAll()
        unlock()
    }

    // MARK: - 便捷方法
    /// 使用当前模块 Bundle 获取本地化字符串
    public func localizedString(
        key: String,
        table: String? = nil,
        module: String? = nil,
        arguments: [CVarArg] = []
    ) -> String {
        let resolvedBundle: Bundle?
        if let module = module {
            resolvedBundle = bundle(for: module)
        } else {
            resolvedBundle = nil
        }
        return localizedString(key: key, table: table, bundle: resolvedBundle, arguments: arguments)
    }

    // MARK: - 私有方法

    /// 根据当前语言解析目标 Bundle（带 .lproj 缓存）
    private func resolveLanguageBundle(from baseBundle: Bundle) -> Bundle {
        let current = currentLanguage
        let cacheKey = "\(baseBundle.bundlePath)_\(current)"

        lock()
        if let cached = languageBundles[cacheKey] {
            unlock()
            return cached
        }
        unlock()

        // 查找 .lproj 目录
        if let lprojPath = baseBundle.path(forResource: current, ofType: "lproj"),
           let langBundle = Bundle(path: lprojPath) {
            lock()
            languageBundles[cacheKey] = langBundle
            unlock()
            return langBundle
        }

        // 未找到则返回原 Bundle
        return baseBundle
    }

    /// 锁操作
    private func lock() {
        os_unfair_lock_lock(&unfairLock)
    }

    private func unlock() {
        os_unfair_lock_unlock(&unfairLock)
    }

    /// 将系统首选语言匹配到支持列表中最接近的语言
    private static func matchSystemLanguage(preferred: [String], available: [String]) -> String {
        for pref in preferred {
            // 完全匹配
            if available.contains(pref) {
                return pref
            }
            // 前缀匹配，如 "zh-Hans-CN" -> "zh-Hans"
            for avail in available {
                if pref.hasPrefix(avail) || avail.hasPrefix(pref) {
                    return avail
                }
            }
            // 只匹配语言代码，如 "zh-Hans" 和 "zh-Hant" 都匹配 "zh"
            let prefLang = pref.split(separator: "-").first.map(String.init) ?? pref
            for avail in available {
                let availLang = avail.split(separator: "-").first.map(String.init) ?? avail
                if prefLang == availLang {
                    return avail
                }
            }
        }
        // 兜底返回简体中文
        return "zh-Hans"
    }
}

// MARK: - UserDefaults Key 常量
private enum KJLocalizationKey {
    static let savedLanguage = "com.xianrenzhilu.localization.savedLanguage"
    static let notificationLanguage = "language"
}

// MARK: - 全局便捷函数
/// 全局便捷函数：获取本地化字符串
/// - Parameters:
///   - key: 本地化键名
///   - table: 本地化表名
///   - bundle: 自定义 Bundle
///   - arguments: 格式化参数
/// - Returns: 本地化后的字符串
public func L(
    _ key: String,
    table: String? = nil,
    bundle: Bundle? = nil,
    arguments: CVarArg...
) -> String {
    return KJLocalizationManager.shared.localizedString(
        key: key,
        table: table,
        bundle: bundle,
        arguments: arguments
    )
}

/// 全局便捷函数：通过模块名获取本地化字符串
public func L(
    _ key: String,
    table: String? = nil,
    module: String,
    arguments: CVarArg...
) -> String {
    return KJLocalizationManager.shared.localizedString(
        key: key,
        table: table,
        module: module,
        arguments: arguments
    )
}

// MARK: - 测试代码（已迁移到独立测试模块）
