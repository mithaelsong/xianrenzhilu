// 功能21: 公共资源访问
// 对应: 模块可以访问 Resources/ 下的图片、字体等
// 优先级: P1

import Foundation
import AppKit
import CoreText
import os


// MARK: - KJResourceManager
/// 公共资源管理器 (功能21)
///
/// 特性:
/// - 单例模式，全局统一资源访问入口
/// - 线程安全（os_unfair_lock 保护所有缓存与注册表操作）
/// - 支持从公共 Resources/ 目录和模块私有 bundle 读取
/// - 内置缓存机制，提升重复访问性能
/// - 支持图片、字符串、数据、字体、颜色等资源类型
/// - 统一资源存在性查询
public final class KJResourceManager : @unchecked Sendable {
    public static let shared = KJResourceManager()

    /// 资源缓存：复合键 -> 资源实例
    private var resourceCache: [String: Any] = [:]
    /// 已注册字体文件路径集合
    private var registeredFontPaths: Set<String> = []
    /// 线程安全锁
    private var lock = os_unfair_lock()
    private let logger = KJModuleLogger.shared

    private init() {}

    // MARK: - 缓存键
    private func cacheKey(named name: String, bundle: Bundle?) -> String {
        let bundleID = bundle?.bundleIdentifier ?? "main"
        return "\(bundleID)_\(name)"
    }

    // MARK: - 获取资源 URL
    /// 获取指定资源的文件 URL
    /// - Parameters:
    ///   - name: 资源名称（不含扩展名）
    ///   - type: 资源扩展名，nil 表示无扩展名
    ///   - bundle: 目标 bundle，nil 表示主 bundle / 公共 Resources 目录
    /// - Returns: 资源 URL，如果不存在返回 nil
    public func url(forResource name: String, ofType type: String?, bundle: Bundle? = nil) -> URL? {
        let targetBundle = bundle ?? Bundle.main

        // 1. 直接从 bundle 根目录查找
        if let url = targetBundle.url(forResource: name, withExtension: type) {
            return url
        }

        // 2. 从 Resources 子目录查找
        if let url = targetBundle.url(forResource: name, withExtension: type, subdirectory: "Resources") {
            return url
        }

        // 3. 从常见分类子目录查找（仅限主 bundle）
        if targetBundle == Bundle.main {
            let searchPaths = [
                "Resources/Images",
                "Resources/Fonts",
                "Resources/Data",
                "Resources/Colors",
                "Resources/Strings",
            ]
            for subdir in searchPaths {
                if let url = targetBundle.url(forResource: name, withExtension: type, subdirectory: subdir) {
                    return url
                }
            }
        }

        return nil
    }

    // MARK: - 检查资源是否存在
    /// 检查指定名称的资源是否存在（自动尝试常见扩展名）
    /// - Parameters:
    ///   - name: 资源名称
    ///   - bundle: 目标 bundle，nil 表示主 bundle
    /// - Returns: 资源是否存在
    public func resourceExists(named name: String, bundle: Bundle? = nil) -> Bool {
        let targetBundle = bundle ?? Bundle.main
        let extensions: [String?] = [nil, "png", "jpg", "jpeg", "tiff", "gif",
                                       "json", "plist", "xml", "data", "bin",
                                       "ttf", "otf", "ttc", "strings"]

        for ext in extensions {
            if url(forResource: name, ofType: ext, bundle: targetBundle) != nil {
                return true
            }
        }

        // 额外检查 Asset Catalog 中的图片/颜色（仅限主 bundle）
        if targetBundle == Bundle.main {
            if NSImage(named: name) != nil { return true }
            if #available(macOS 10.13, *) {
                if NSColor(named: NSColor.Name(name)) != nil { return true }
            }
        }

        return false
    }

    // MARK: - 加载图片
    /// 加载图片资源
    /// - Parameters:
    ///   - name: 图片名称（不含扩展名）或 Asset Catalog 中的名称
    ///   - bundle: 目标 bundle，nil 表示主 bundle / 公共 Resources 目录
    /// - Returns: NSImage 实例，如果不存在返回 nil
    public func image(named name: String, bundle: Bundle? = nil) -> NSImage? {
        let cacheKey = self.cacheKey(named: "image_\(name)", bundle: bundle)

        os_unfair_lock_lock(&lock)
        if let cached = resourceCache[cacheKey] as? NSImage {
            os_unfair_lock_unlock(&lock)
            logger.debug("KJResourceManager", "图片缓存命中: '\(name)'")
            return cached
        }
        os_unfair_lock_unlock(&lock)

        let targetBundle = bundle ?? Bundle.main
        var image: NSImage?

        // 1. 从主 bundle Asset Catalog 加载
        if targetBundle == Bundle.main {
            image = NSImage(named: name)
        }

        // 2. 从指定 bundle 的 Asset Catalog 加载
        if image == nil, let _ = bundle {
            image = NSImage(named: NSImage.Name(name))
        }

        // 3. 从文件系统加载
        if image == nil {
            let imageExts = ["png", "jpg", "jpeg", "tiff", "gif", "bmp", "heic"]
            for ext in imageExts {
                if let url = url(forResource: name, ofType: ext, bundle: targetBundle) {
                    image = NSImage(contentsOf: url)
                    if image != nil { break }
                }
            }
            // 尝试无扩展名
            if image == nil, let url = url(forResource: name, ofType: nil, bundle: targetBundle) {
                image = NSImage(contentsOf: url)
            }
        }

        if let image = image {
            os_unfair_lock_lock(&lock)
            resourceCache[cacheKey] = image
            os_unfair_lock_unlock(&lock)
            logger.info("KJResourceManager", "已加载图片: '\(name)' 来自\(targetBundle.bundleIdentifier ?? "main")")
        } else {
            logger.warning("KJResourceManager", "图片未找到: '\(name)'")
        }

        return image
    }

    // MARK: - 加载字符串
    /// 加载本地化字符串资源
    /// - Parameters:
    ///   - name: 字符串键名
    ///   - table: 字符串表名称，nil 表示 Localizable.strings
    ///   - bundle: 目标 bundle，nil 表示主 bundle
    /// - Returns: 本地化字符串，如果键不存在返回 nil
    public func string(named name: String, table: String? = nil, bundle: Bundle? = nil) -> String? {
        let targetBundle = bundle ?? Bundle.main
        let result = targetBundle.localizedString(forKey: name, value: nil, table: table)

        // localizedString 在没有找到时会返回 key 本身
        if result == name {
            logger.warning("KJResourceManager", "字符串未找到: key='\(name)', table=\(table ?? "Localizable")")
            return nil
        }

        logger.debug("KJResourceManager", "已加载字符串: key='\(name)'")
        return result
    }

    // MARK: - 加载数据
    /// 加载二进制数据资源
    /// - Parameters:
    ///   - name: 资源名称（不含扩展名）
    ///   - bundle: 目标 bundle，nil 表示主 bundle
    /// - Returns: Data 实例，如果不存在返回 nil
    public func data(named name: String, bundle: Bundle? = nil) -> Data? {
        let cacheKey = self.cacheKey(named: "data_\(name)", bundle: bundle)

        os_unfair_lock_lock(&lock)
        if let cached = resourceCache[cacheKey] as? Data {
            os_unfair_lock_unlock(&lock)
            logger.debug("KJResourceManager", "数据缓存命中: '\(name)'")
            return cached
        }
        os_unfair_lock_unlock(&lock)

        let targetBundle = bundle ?? Bundle.main
        var data: Data?

        // 1. 尝试无扩展名
        if let url = url(forResource: name, ofType: nil, bundle: targetBundle) {
            data = try? Data(contentsOf: url)
        }

        // 2. 尝试常见扩展名
        if data == nil {
            let extensions = ["json", "plist", "xml", "data", "bin"]
            for ext in extensions {
                if let url = url(forResource: name, ofType: ext, bundle: targetBundle) {
                    data = try? Data(contentsOf: url)
                    if data != nil { break }
                }
            }
        }

        if let data = data {
            os_unfair_lock_lock(&lock)
            resourceCache[cacheKey] = data
            os_unfair_lock_unlock(&lock)
            logger.info("KJResourceManager", "已加载数据: '\(name)' (\(data.count) 字节)")
        } else {
            logger.warning("KJResourceManager", "数据未找到: '\(name)'")
        }

        return data
    }

    // MARK: - 加载字体
    /// 加载自定义字体
    /// - Parameters:
    ///   - name: 字体 PostScript 名称或字体文件名（不含扩展名）
    ///   - size: 字体大小（磅值）
    ///   - bundle: 目标 bundle，nil 表示主 bundle
    /// - Returns: NSFont 实例，如果不存在返回 nil
    public func font(named name: String, size: CGFloat, bundle: Bundle? = nil) -> NSFont? {
        let cacheKey = self.cacheKey(named: "font_\(name)_\(size)", bundle: bundle)

        os_unfair_lock_lock(&lock)
        if let cached = resourceCache[cacheKey] as? NSFont {
            os_unfair_lock_unlock(&lock)
            logger.debug("KJResourceManager", "字体缓存命中: '\(name)' @ \(size)pt")
            return cached
        }
        os_unfair_lock_unlock(&lock)

        let targetBundle = bundle ?? Bundle.main
        var font: NSFont?

        // 1. 尝试按 PostScript 名称直接加载（系统字体或已注册字体）
        font = NSFont(name: name, size: size)

        // 2. 尝试从字体文件加载并动态注册
        if font == nil {
            let fontExts = ["ttf", "otf", "ttc"]
            for ext in fontExts {
                if let url = url(forResource: name, ofType: ext, bundle: targetBundle) {
                    font = loadAndRegisterFont(from: url, size: size)
                    if font != nil { break }
                }
            }
        }

        if let font = font {
            os_unfair_lock_lock(&lock)
            resourceCache[cacheKey] = font
            os_unfair_lock_unlock(&lock)
            logger.info("KJResourceManager", "已加载字体: '\(name)' @ \(size)pt")
        } else {
            logger.warning("KJResourceManager", "字体未找到: '\(name)' @ \(size)pt")
        }

        return font
    }

    /// 从 URL 加载字体文件并注册到当前进程
    private func loadAndRegisterFont(from url: URL, size: CGFloat) -> NSFont? {
        let path = url.path

        os_unfair_lock_lock(&lock)
        let alreadyRegistered = registeredFontPaths.contains(path)
        if !alreadyRegistered {
            registeredFontPaths.insert(path)
        }
        os_unfair_lock_unlock(&lock)

        // 首次使用时注册字体
        if !alreadyRegistered {
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if !success {
                if let err = error?.takeRetainedValue() {
                    logger.error("KJResourceManager", "注册字体失败: \(path): \(err)")
                }
                // 注册失败，移除记录以便后续重试
                os_unfair_lock_lock(&lock)
                registeredFontPaths.remove(path)
                os_unfair_lock_unlock(&lock)
                return nil
            }
        }

        // 获取字体的 PostScript 名称
        guard let provider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(provider),
              let psName = cgFont.postScriptName as String? else {
            return nil
        }

        return NSFont(name: psName, size: size)
    }

    // MARK: - 加载颜色
    /// 加载颜色资源
    /// - Parameters:
    ///   - name: 颜色名称（Asset Catalog 名称或颜色定义文件名）
    ///   - bundle: 目标 bundle，nil 表示主 bundle
    /// - Returns: NSColor 实例，如果不存在返回 nil
    public func color(named name: String, bundle: Bundle? = nil) -> NSColor? {
        let cacheKey = self.cacheKey(named: "color_\(name)", bundle: bundle)

        os_unfair_lock_lock(&lock)
        if let cached = resourceCache[cacheKey] as? NSColor {
            os_unfair_lock_unlock(&lock)
            logger.debug("KJResourceManager", "颜色缓存命中: '\(name)'")
            return cached
        }
        os_unfair_lock_unlock(&lock)

        let targetBundle = bundle ?? Bundle.main
        var color: NSColor?

        // 1. 从 Asset Catalog 加载（macOS 10.13+）
        if #available(macOS 10.13, *) {
            if let bundle = bundle {
                color = NSColor(named: NSColor.Name(name), bundle: bundle)
            } else {
                color = NSColor(named: NSColor.Name(name))
            }
        }

        // 2. 从 JSON 颜色定义加载
        if color == nil {
            color = loadColorFromJSON(named: name, bundle: targetBundle)
        }

        // 3. 从 plist 颜色定义加载
        if color == nil {
            color = loadColorFromPlist(named: name, bundle: targetBundle)
        }

        if let color = color {
            os_unfair_lock_lock(&lock)
            resourceCache[cacheKey] = color
            os_unfair_lock_unlock(&lock)
            logger.info("KJResourceManager", "已加载颜色: '\(name)'")
        } else {
            logger.warning("KJResourceManager", "颜色未找到: '\(name)'")
        }

        return color
    }

    /// 从 JSON 文件加载颜色定义
    /// 支持格式: { "r": 255, "g": 128, "b": 0, "a": 1.0 }
    /// 或 { "red": 1.0, "green": 0.5, "blue": 0.0, "alpha": 1.0 }
    private func loadColorFromJSON(named name: String, bundle: Bundle) -> NSColor? {
        guard let url = url(forResource: name, ofType: "json", bundle: bundle),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let r = parseColorComponent(from: json, keys: ["r", "red"])
        let g = parseColorComponent(from: json, keys: ["g", "green"])
        let b = parseColorComponent(from: json, keys: ["b", "blue"])
        let a = parseColorComponent(from: json, keys: ["a", "alpha"]) ?? 1.0

        guard let red = r, let green = g, let blue = b else { return nil }
        return NSColor(red: red, green: green, blue: blue, alpha: a)
    }

    /// 从 plist 文件加载颜色定义
    private func loadColorFromPlist(named name: String, bundle: Bundle) -> NSColor? {
        guard let url = url(forResource: name, ofType: "plist", bundle: bundle),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }

        let r = parseColorComponent(from: dict, keys: ["r", "red"])
        let g = parseColorComponent(from: dict, keys: ["g", "green"])
        let b = parseColorComponent(from: dict, keys: ["b", "blue"])
        let a = parseColorComponent(from: dict, keys: ["a", "alpha"]) ?? 1.0

        guard let red = r, let green = g, let blue = b else { return nil }
        return NSColor(red: red, green: green, blue: blue, alpha: a)
    }

    /// 解析颜色分量，支持 0~1 浮点数或 0~255 整数
    private func parseColorComponent(from dict: [String: Any], keys: [String]) -> CGFloat? {
        for key in keys {
            if let value = dict[key] as? CGFloat {
                return value > 1.0 ? value / 255.0 : value
            }
            if let value = dict[key] as? Double {
                return CGFloat(value > 1.0 ? value / 255.0 : value)
            }
            if let value = dict[key] as? Int {
                return CGFloat(value) / 255.0
            }
        }
        return nil
    }

    // MARK: - 缓存管理
    /// 清理所有缓存的资源
    public func clearCache() {
        os_unfair_lock_lock(&lock)
        resourceCache.removeAll()
        os_unfair_lock_unlock(&lock)
        logger.info("KJResourceManager", "资源缓存已清理")
    }

    /// 获取当前缓存统计信息
    public var cacheStats: KJResourceCacheStats {
        os_unfair_lock_lock(&lock)
        let count = resourceCache.count
        os_unfair_lock_unlock(&lock)
        return KJResourceCacheStats(hitCount: count, missCount: 0, totalSize: 0)
    }
}

// MARK: - 缓存统计
/// 资源缓存统计信息

// MARK: - 资源路径常量
public extension KJResourceManager {
    /// 常用资源子目录路径常量
    enum KJResourcePaths {
        public static let images = "Resources/Images"
        public static let fonts = "Resources/Fonts"
        public static let data = "Resources/Data"
        public static let colors = "Resources/Colors"
        public static let strings = "Resources/Strings"
    }
}


