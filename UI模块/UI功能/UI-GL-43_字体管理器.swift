// 功能34A: 字体管理器
// 对应: 管理系统字体、用户自定义字体、字体组合/主题
// 优先级: P1
// 版本: 2.0

import AppKit
import Foundation
import CoreText
import os.log

// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {


// MARK: - 测试代码
#if false // DEBUG tests disabled in App target
// import XCTest (disabled for executable target)

/// 功能34A：字体管理器 — 单元测试
func test_fontManager() {
    let manager = UIFontManager.shared
    var allPassed = true

    logger.info("测试1: 系统字体列表")
    if manager.scanSystemFonts().isEmpty {
        logger.error("❌ 测试1失败: 应有系统字体")
        allPassed = false
    } else {
        logger.info("✅ 测试1通过: 系统字体正常")
    }

    if allPassed {
        logger.info("=== 全部字体管理测试通过 ✅ ===")
    } else {
        logger.error("=== 部分字体管理测试失败 ❌ ===")
    }
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIFontManager
public final class UIFontManager : @unchecked Sendable {

    // MARK: - 单例
    public static let shared = UIFontManager()

    // MARK: - 日志器
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "字体管理器")

    // MARK: - 配置常量
    private let userFontsDirectoryName = "UserFonts"          // 用户字体存放目录名
    private let configurationFileName = "FontManagerConfig.json" // 配置文件名
    private let maxUserFontsCount = 100                         // 最大用户字体数量

    // MARK: - 线程锁（保护共享数据）
    private let lock = NSRecursiveLock()

    // MARK: - 内部状态
    /// 系统字体族列表（按字体族分组）
    private var systemFontFamilies: [UIFontFamilyInfo] = []
    /// 用户已注册的字体列表（族名 -> 文件路径）
    private nonisolated(unsafe) var registeredUserFonts: [String: String] = [:]
    /// 字体组合列表
    private nonisolated(unsafe) var fontPairs: [UIFontPair] = []
    /// 当前字体组合
    private nonisolated(unsafe) var currentFontPair: UIFontPair = .default
    /// 持久化配置
    private nonisolated(unsafe) var configuration: UIFontManagerConfiguration = .init()
    /// 系统字体扫描完成标记
    private var didScanSystemFonts = false

    // MARK: - 公开属性

    /// 当前字体组合（线程安全读取）
    public var activeFontPair: UIFontPair {
        lock.lock()
        let pair = currentFontPair
        lock.unlock()
        return pair
    }

    /// 所有字体组合（线程安全读取）
    public var allFontPairs: [UIFontPair] {
        lock.lock()
        let pairs = fontPairs
        lock.unlock()
        return pairs
    }

    /// 是否启用字体回退
    public var isFallbackEnabled: Bool {
        get {
            lock.lock()
            let enabled = configuration.enableFallback
            lock.unlock()
            return enabled
        }
        set {
            lock.lock()
            configuration.enableFallback = newValue
            lock.unlock()
            saveConfiguration()
            postSettingsChangeNotification()
            logger.info("字体回退设置已切换为: \(newValue)")
        }
    }

    // MARK: - 初始化
    private init() {
        // 初始化默认字体组合
        fontPairs = [.default]

        // 加载持久化配置
        loadConfiguration()

        // 恢复用户字体
        restoreUserFonts()

        logger.info("字体管理器初始化完成")
    }

    deinit {
        // 清理：注销所有用户字体（释放CoreText注册）
        unregisterAllUserFonts()
        logger.info("字体管理器已销毁，所有用户字体已注销")
    }

    // MARK: - 目录路径

    /// 用户字体存放目录：~/Library/Application Support/仙人指路/UserFonts/
    private var userFontsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("仙人指路/\(userFontsDirectoryName)", isDirectory: true)
    }

    /// 配置文件路径：~/Library/Application Support/仙人指路/FontManagerConfig.json
    private var configurationFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("仙人指路/\(configurationFileName)")
    }

    // MARK: - 系统字体扫描

    /// 扫描系统所有可用字体，按字体族分组
    /// 使用 CoreText 的 CTFontCopyAvailableFontFamilyNames 获取字体族列表
    /// 首次调用时会缓存结果，后续直接返回缓存
    public func scanSystemFonts() -> [UIFontFamilyInfo] {
        lock.lock()
        if didScanSystemFonts {
            let cached = systemFontFamilies
            lock.unlock()
            return cached
        }
        lock.unlock()

        logger.info("开始扫描系统字体...")

        // 使用 NSFontManager 获取所有字体族名称
        let familyNames = NSFontManager.shared.availableFontFamilies
        guard !familyNames.isEmpty else {
            logger.error("系统字体扫描失败：无法获取字体族列表")
            return []
        }

        var families: [UIFontFamilyInfo] = []

        for familyName in familyNames {
            // 获取该字体族下所有样式
            let fontDescriptors = CTFontDescriptorCreateMatchingFontDescriptors(
                CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute as String: familyName] as CFDictionary),
                nil
            )

            var styleNames: [String] = []
            var isMonospaced = false
            var displayName: String?

            if let descriptors = fontDescriptors as? [CTFontDescriptor] {
                for descriptor in descriptors {
                    if let style = CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String {
                        styleNames.append(style)
                    }
                    // 判断是否为等宽字体
                    if let traits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [String: Any],
                       let symbolicTraits = traits[kCTFontSymbolicTrait as String] as? UInt32 {
                        isMonospaced = (symbolicTraits & 0x0400) != 0
                    }
                    // 获取展示名称
                    if let dName = CTFontDescriptorCopyAttribute(descriptor, kCTFontDisplayNameAttribute) as? String {
                        displayName = dName
                    }
                }
            }

            // 去重并排序样式
            styleNames = Array(Set(styleNames)).sorted()

            let info = UIFontFamilyInfo(
                familyName: familyName,
                styleNames: styleNames,
                displayName: displayName,
                isMonospaced: isMonospaced,
                isUserRegistered: false
            )
            families.append(info)
        }

        // 按字体族名称排序
        families.sort { $0.familyName < $1.familyName }

        lock.lock()
        systemFontFamilies = families
        didScanSystemFonts = true
        lock.unlock()

        logger.info("系统字体扫描完成，共 \(families.count) 个字体族")
        return families
    }

    /// 强制重新扫描系统字体（刷新缓存）
    public func rescanSystemFonts() -> [UIFontFamilyInfo] {
        lock.lock()
        didScanSystemFonts = false
        lock.unlock()
        return scanSystemFonts()
    }

    /// 搜索系统字体（按名称模糊匹配）
    public func searchSystemFonts(query: String) -> [UIFontFamilyInfo] {
        let allFonts = scanSystemFonts()
        let lowerQuery = query.lowercased()
        return allFonts.filter { font in
            font.familyName.lowercased().contains(lowerQuery) ||
            (font.displayName?.lowercased().contains(lowerQuery) ?? false)
        }
    }

    // MARK: - 用户字体注册

    /// 从指定路径加载并注册用户自定义字体（支持 .ttf / .otf / .ttc 格式）
    /// 字体文件会被复制到应用支持目录，然后注册到 CoreText
    /// - Parameter path: 字体文件原始路径
    /// - Returns: 注册结果
    @discardableResult
    public func registerUserFont(from path: String) -> UIFontRegistrationResult {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()

        // 检查文件格式
        guard ["ttf", "otf", "ttc"].contains(ext) else {
            let msg = "不支持的字体格式: .\(ext)，仅支持 .ttf / .otf / .ttc"
            logger.error("\(msg)")
            return .failure(msg)
        }

        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: path) else {
            let msg = "字体文件不存在: \(path)"
            logger.error("\(msg)")
            return .failure(msg)
        }

        // 检查是否超过最大数量
        lock.lock()
        let currentCount = registeredUserFonts.count
        lock.unlock()

        guard currentCount < maxUserFontsCount else {
            let msg = "用户字体数量已达上限 \(maxUserFontsCount)"
            logger.error("\(msg)")
            return .failure(msg)
        }

        // 确保用户字体目录存在
        do {
            try FileManager.default.createDirectory(at: userFontsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            let msg = "创建用户字体目录失败: \(error.localizedDescription)"
            logger.error("\(msg)")
            return .failure(msg)
        }

        // 复制字体到应用支持目录
        let destURL = userFontsDirectory.appendingPathComponent(url.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
        } catch {
            let msg = "复制字体文件失败: \(error.localizedDescription)"
            logger.error("\(msg)")
            return .failure(msg)
        }

        // 注册字体到 CoreText
        var cfError: Unmanaged<CFError>?
        guard CTFontManagerRegisterFontsForURL(destURL as CFURL, .process, &cfError) else {
            if let error = cfError?.takeRetainedValue() {
                let msg = "CoreText 字体注册失败: \(error.localizedDescription)"
                logger.error("\(msg)")
                return .failure(msg)
            }
            return .failure("CoreText 字体注册未知错误")
        }

        // 获取字体族名称
        guard let familyName = extractFontFamilyName(from: destURL) else {
            // 注册成功但无法获取族名，尝试回滚
            CTFontManagerUnregisterFontsForURL(destURL as CFURL, .process, nil)
            let msg = "无法提取字体族名称"
            logger.error("\(msg)")
            return .failure(msg)
        }

        // 检查是否已注册
        lock.lock()
        if registeredUserFonts[familyName] != nil {
            lock.unlock()
            logger.info("字体 \(familyName) 已注册，跳过")
            return .alreadyRegistered
        }
        registeredUserFonts[familyName] = destURL.path
        lock.unlock()

        // 保存配置
        saveConfiguration()

        // 发送通知
        postRegisterNotification(familyName: familyName, path: destURL.path)

        logger.info("字体注册成功: \(familyName) 来自 \(path)")
        return .success
    }

    /// 注销指定用户字体
    /// - Parameter familyName: 字体族名称
    public func unregisterUserFont(familyName: String) {
        lock.lock()
        guard let path = registeredUserFonts[familyName] else {
            lock.unlock()
            logger.warning("字体 \(familyName) 未注册，无需注销")
            return
        }
        lock.unlock()

        let url = URL(fileURLWithPath: path)
        var cfError: Unmanaged<CFError>?

        // 从 CoreText 注销
        if CTFontManagerUnregisterFontsForURL(url as CFURL, .process, &cfError) {
            lock.lock()
            registeredUserFonts.removeValue(forKey: familyName)
            lock.unlock()

            // 删除文件
            try? FileManager.default.removeItem(at: url)

            saveConfiguration()
            postUnregisterNotification(familyName: familyName)
            logger.info("字体注销成功: \(familyName)")
        } else {
            if let error = cfError?.takeRetainedValue() {
                logger.error("字体注销失败: \(familyName) - \(error.localizedDescription)")
            }
        }
    }

    /// 注销所有用户字体（deinit 时调用）
    private func unregisterAllUserFonts() {
        lock.lock()
        let allFonts = registeredUserFonts
        lock.unlock()

        for (familyName, path) in allFonts {
            let url = URL(fileURLWithPath: path)
            var cfError: Unmanaged<CFError>?
            if CTFontManagerUnregisterFontsForURL(url as CFURL, .process, &cfError) {
                try? FileManager.default.removeItem(at: url)
                logger.info("已注销字体: \(familyName)")
            }
        }

        lock.lock()
        registeredUserFonts.removeAll()
        lock.unlock()
    }

    /// 提取字体文件中的字体族名称
    private func extractFontFamilyName(from url: URL) -> String? {
        guard let fontDescriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else {
            return nil
        }
        guard let firstDescriptor = fontDescriptors.first else { return nil }
        return CTFontDescriptorCopyAttribute(firstDescriptor, kCTFontFamilyNameAttribute) as? String
    }

    /// 获取所有已注册的用户字体列表
    public func registeredUserFontFamilies() -> [UIFontFamilyInfo] {
                var familyStyleMap: [(familyName: String, styleNames: [String])] = []
        lock.lock()
        for (familyName, _) in registeredUserFonts {
            familyStyleMap.append((familyName, []))
        }
        lock.unlock()

        let fonts: [UIFontFamilyInfo] = familyStyleMap.map { (familyName, _) in
            let filePath = registeredUserFonts[familyName] ?? ""
            guard !filePath.isEmpty else {
                return UIFontFamilyInfo(familyName: familyName, styleNames: [], displayName: nil, isMonospaced: false, isUserRegistered: true)
            }
            let url = URL(fileURLWithPath: filePath)
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] ?? []
            let styles = descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontStyleNameAttribute) as? String }
            return UIFontFamilyInfo(
                familyName: familyName,
                styleNames: Array(Set(styles)).sorted(),
                displayName: nil,
                isMonospaced: false,
                isUserRegistered: true
            )
        }.sorted { $0.familyName < $1.familyName }
        return fonts
    }

    // MARK: - 字体组合管理

    /// 添加字体组合
    public func addFontPair(_ pair: UIFontPair) {
        lock.lock()
        fontPairs.append(pair)
        lock.unlock()
        saveConfiguration()
        postSettingsChangeNotification()
        logger.info("添加字体组合: \(pair.name)")
    }

    /// 删除字体组合（不能删除默认组合）
    public func removeFontPair(id: UUID) {
        lock.lock()
        if let index = fontPairs.firstIndex(where: { $0.id == id }), fontPairs[index].name != "系统默认" {
            let removed = fontPairs.remove(at: index)
            lock.unlock()
            saveConfiguration()
            postSettingsChangeNotification()
            logger.info("删除字体组合: \(removed.name)")
        } else {
            lock.unlock()
            logger.warning("无法删除默认字体组合或找不到指定组合")
        }
    }

    /// 更新字体组合
    public func updateFontPair(_ pair: UIFontPair) {
        lock.lock()
        if let index = fontPairs.firstIndex(where: { $0.id == pair.id }) {
            fontPairs[index] = pair
            lock.unlock()
            saveConfiguration()
            postSettingsChangeNotification()
            logger.info("更新字体组合: \(pair.name)")
        } else {
            lock.unlock()
            logger.warning("找不到要更新的字体组合: \(pair.name)")
        }
    }

    /// 激活指定字体组合
    public func activateFontPair(id: UUID) {
        lock.lock()
        guard let pair = fontPairs.first(where: { $0.id == id }) else {
            lock.unlock()
            logger.warning("找不到要激活的字体组合: \(id)")
            return
        }
        currentFontPair = pair
        configuration.currentPairID = id
        lock.unlock()
        saveConfiguration()
        postSettingsChangeNotification()
        logger.info("激活字体组合: \(pair.name)")
    }

    // MARK: - 字体获取（带回退）

    /// 获取指定字体族和样式的字体，如果不可用则按回退栈自动回退
    /// - Parameters:
    ///   - familyName: 目标字体族名称
    ///   - style: 字体样式（如"Regular"）
    ///   - size: 字号
    /// - Returns: 可用字体实例
    public func font(familyName: String, style: String, size: CGFloat) -> NSFont {
        // 首先尝试直接创建字体
        if let font = NSFont(name: "\(familyName)-\(style)", size: size) {
            return font
        }

        // 尝试使用 CoreText 创建
        let fontDescriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute as String: familyName,
            kCTFontStyleNameAttribute as String: style
        ] as CFDictionary)
        let ctFont = CTFontCreateWithFontDescriptor(fontDescriptor, size, nil)
        let directFont = ctFont as NSFont

        // 回退逻辑
        lock.lock()
        let fallbackEnabled = configuration.enableFallback
        let fallbackStack = configuration.fallbackStack
        lock.unlock()

        if fallbackEnabled {
            for fallbackFamily in fallbackStack {
                if let fallbackFont = NSFont(name: "\(fallbackFamily)-\(style)", size: size) {
                    logger.warning("字体回退: \(familyName) -> \(fallbackFamily)")
                    return fallbackFont
                }
                if let fallbackFont = NSFont(name: fallbackFamily, size: size) {
                    logger.warning("字体回退: \(familyName) -> \(fallbackFamily)")
                    return fallbackFont
                }
            }
        }
        logger.error("CoreText字体直接创建成功: \(familyName), 无需回退")
        return directFont
    }

    /// 获取标题字体（使用当前字体组合）
    public func titleFont(size: CGFloat? = nil) -> NSFont {
        let pair = activeFontPair
        let fontSize = size ?? pair.titleFontSize
        return font(familyName: pair.titleFontFamily, style: pair.titleFontStyle, size: fontSize)
    }

    /// 获取正文字体（使用当前字体组合）
    public func bodyFont(size: CGFloat? = nil) -> NSFont {
        let pair = activeFontPair
        let fontSize = size ?? pair.bodyFontSize
        return font(familyName: pair.bodyFontFamily, style: pair.bodyFontStyle, size: fontSize)
    }

    /// 检查字体是否可用
    public func isFontAvailable(familyName: String) -> Bool {
        // 检查系统字体
        let systemFonts = scanSystemFonts()
        if systemFonts.contains(where: { $0.familyName == familyName }) {
            return true
        }
        // 检查用户字体
        lock.lock()
        let hasUserFont = registeredUserFonts[familyName] != nil
        lock.unlock()
        return hasUserFont
    }

    // MARK: - 字体预览生成

    /// 生成指定字体族的预览片段列表（不同字号、字重组合）
    /// - Parameters:
    ///   - familyName: 字体族名称
    ///   - sampleText: 预览文本（nil则使用配置中的默认文本）
    /// - Returns: 预览片段数组
    public func generatePreviews(familyName: String, sampleText: String? = nil) -> [UIFontPreviewSnippet] {
        let text = sampleText ?? configuration.previewSampleText
        var snippets: [UIFontPreviewSnippet] = []

        // 获取该字体族的所有样式
        let allFonts = scanSystemFonts()
        let userFonts = registeredUserFontFamilies()
        let allFamilies = allFonts + userFonts

        guard let familyInfo = allFamilies.first(where: { $0.familyName == familyName }) else {
            logger.warning("无法生成预览：字体族 \(familyName) 不存在")
            return snippets
        }

        // 使用配置中的预览字号列表
        let sizes = configuration.previewSizes

        for size in sizes {
            // 尝试 Regular 样式
            if let regularFont = NSFont(name: familyName, size: size) {
                let snippet = UIFontPreviewSnippet(
                    fontSize: size,
                    weightDescription: "Regular",
                    font: regularFont,
                    lineSpacing: size * 0.5,
                    sampleText: "\(familyName) \(Int(size))pt\n\(text)",
                    familyName: familyName
                )
                snippets.append(snippet)
            }

            // 尝试 Bold 样式
            if familyInfo.styleNames.contains("Bold") || familyInfo.styleNames.contains("Bold") {
                if let boldFont = NSFont(name: "\(familyName)-Bold", size: size) ?? NSFont(name: familyName, size: size) {
                    let snippet = UIFontPreviewSnippet(
                        fontSize: size,
                        weightDescription: "Bold",
                        font: boldFont,
                        lineSpacing: size * 0.5,
                        sampleText: "\(familyName) Bold \(Int(size))pt\n\(text)",
                        familyName: familyName
                    )
                    snippets.append(snippet)
                }
            }
        }

        return snippets
    }

    /// 生成当前字体组合的预览片段
    public func generateCurrentPairPreviews() -> (titlePreviews: [UIFontPreviewSnippet], bodyPreviews: [UIFontPreviewSnippet]) {
        let pair = activeFontPair
        let titlePreviews = generatePreviews(familyName: pair.titleFontFamily, sampleText: configuration.previewSampleText)
            .filter { $0.weightDescription == pair.titleFontStyle || $0.weightDescription == "Regular" }
        let bodyPreviews = generatePreviews(familyName: pair.bodyFontFamily, sampleText: configuration.previewSampleText)
            .filter { $0.weightDescription == pair.bodyFontStyle || $0.weightDescription == "Regular" }
        return (titlePreviews, bodyPreviews)
    }

    /// 更新预览样本文本
    public func setPreviewSampleText(_ text: String) {
        lock.lock()
        configuration.previewSampleText = text
        lock.unlock()
        saveConfiguration()
        postSettingsChangeNotification()
    }

    // MARK: - 持久化配置

    /// 保存配置到 JSON 文件
    private func saveConfiguration() {
        lock.lock()
        var config = configuration
        config.userFontPaths = Array(registeredUserFonts.values)
        lock.unlock()

        do {
            let data = try JSONEncoder().encode(config)
            let dir = configurationFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: configurationFileURL)
            logger.debug("字体配置已保存")
        } catch {
            logger.error("保存字体配置失败: \(error.localizedDescription)")
        }
    }

    /// 从 JSON 文件加载配置
    private func loadConfiguration() {
        guard FileManager.default.fileExists(atPath: configurationFileURL.path) else {
            logger.info("字体配置文件不存在，使用默认配置")
            return
        }

        do {
            let data = try Data(contentsOf: configurationFileURL)
            let config = try JSONDecoder().decode(UIFontManagerConfiguration.self, from: data)

            lock.lock()
            configuration = config
            // 恢复当前字体组合
            if let pairID = config.currentPairID,
               let pair = fontPairs.first(where: { $0.id == pairID }) {
                currentFontPair = pair
            }
            lock.unlock()

            logger.info("字体配置已加载，用户字体 \(config.userFontPaths.count) 个")
        } catch {
            logger.error("加载字体配置失败: \(error.localizedDescription)")
        }
    }

    /// 恢复用户字体（启动时从配置中恢复）
    private func restoreUserFonts() {
        lock.lock()
        let paths = configuration.userFontPaths
        lock.unlock()

        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else {
                logger.warning("用户字体文件丢失: \(path)")
                continue
            }

            var cfError: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &cfError) {
                if let familyName = extractFontFamilyName(from: url) {
                    lock.lock()
                    registeredUserFonts[familyName] = path
                    lock.unlock()
                    logger.info("恢复用户字体: \(familyName)")
                }
            } else {
                if let error = cfError?.takeRetainedValue() {
                    logger.error("恢复字体失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 重置所有配置到默认值
    public func resetToDefaults() {
        lock.lock()
        // 注销所有用户字体
        let userFonts = registeredUserFonts
        lock.unlock()

        for (familyName, _) in userFonts {
            unregisterUserFont(familyName: familyName)
        }

        lock.lock()
        fontPairs = [.default]
        currentFontPair = .default
        configuration = UIFontManagerConfiguration()
        lock.unlock()

        saveConfiguration()
        postSettingsChangeNotification()
        logger.info("字体配置已重置为默认值")
    }

    // MARK: - 通知发送

    /// 发送字体注册通知
    private func postRegisterNotification(familyName: String, path: String) {
        NotificationCenter.default.post(
            name: .FontManagerDidRegisterFont,
            object: self,
            userInfo: ["familyName": familyName, "path": path]
        )
    }

    /// 发送字体注销通知
    private func postUnregisterNotification(familyName: String) {
        NotificationCenter.default.post(
            name: .FontManagerDidUnregisterFont,
            object: self,
            userInfo: ["familyName": familyName]
        )
    }

    /// 发送字体设置变更通知
    private func postSettingsChangeNotification() {
        lock.lock()
        let pair = currentFontPair
        lock.unlock()

        NotificationCenter.default.post(
            name: .FontManagerSettingsDidChange,
            object: self,
            userInfo: ["currentPair": pair.name, "pairID": pair.id.uuidString]
        )
    }

    // MARK: - 设置面板方法

    /// 获取字体管理器统计信息（供设置面板展示）
    public func statistics() -> (systemFontCount: Int, userFontCount: Int, pairCount: Int, currentPair: String) {
        let systemCount = scanSystemFonts().count
        lock.lock()
        let userCount = registeredUserFonts.count
        let pairCount = fontPairs.count
        let pairName = currentFontPair.name
        lock.unlock()
        return (systemFontCount: systemCount, userFontCount: userCount, pairCount: pairCount, currentPair: pairName)
    }

    /// 获取设置面板用的配置摘要
    public func configurationSummary() -> UIFontConfigurationSummaryData? {
        lock.lock()
        let config = configuration
        let pair = currentFontPair
        lock.unlock()

        return UIFontConfigurationSummaryData(
            currentPair: pair.name,
            currentPairID: pair.id.uuidString,
            userFontCount: config.userFontPaths.count,
            fallbackEnabled: config.enableFallback,
            fallbackStack: config.fallbackStack,
            previewSampleText: config.previewSampleText
        )
    }

    /// 导入字体设置配置文件
    public func importConfiguration(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(UIFontManagerConfiguration.self, from: data)

            lock.lock()
            configuration = config
            lock.unlock()

            saveConfiguration()
            postSettingsChangeNotification()
            logger.info("字体配置已导入: \(url.path)")
            return true
        } catch {
            logger.error("导入字体配置失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 导出字体设置配置文件
    public func exportConfiguration(to url: URL) -> Bool {
        do {
            let data = try JSONEncoder().encode(configuration)
            try data.write(to: url)
            logger.info("字体配置已导出: \(url.path)")
            return true
        } catch {
            logger.error("导出字体配置失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 设置字体回退栈
    public func setFallbackStack(_ stack: [String]) {
        lock.lock()
        configuration.fallbackStack = stack
        lock.unlock()
        saveConfiguration()
        postSettingsChangeNotification()
        logger.info("字体回退栈已更新: \(stack.joined(separator: ", "))")
    }

    /// 获取字体回退栈
    public func fallbackStack() -> [String] {
        lock.lock()
        let stack = configuration.fallbackStack
        lock.unlock()
        return stack
    }
}

// MARK: - 迁回自 UI-02：class UIFontSelectorViewController
public final class UIFontSelectorViewController: NSViewController , @unchecked Sendable{

    // MARK: - UI 组件
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var searchField: NSSearchField!
    private var infoLabel: NSTextField!
    private var previewTextField: NSTextField!

    // MARK: - 数据
    private var allFamilies: [UIFontFamilyInfo] = []
    private var filteredFamilies: [UIFontFamilyInfo] = []
    private var selectedFamily: UIFontFamilyInfo?

    // MARK: - 回调
    public var onFontSelected: ((UIFontFamilyInfo) -> Void)?

    // MARK: - 生命周期
    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 500))
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadFonts()

        // 监听字体注册/注销通知，自动刷新列表
        NotificationCenter.default.addObserver(self, selector: #selector(fontsChanged), name: .FontManagerDidRegisterFont, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fontsChanged), name: .FontManagerDidUnregisterFont, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI 搭建
    private func setupUI() {
        // 搜索框
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "搜索字体..."
        searchField.target = self
        searchField.action = #selector(searchChanged)
        view.addSubview(searchField)

        // 表格视图
        tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.delegate = self
        tableView.dataSource = self

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "字体族"
        nameColumn.width = 200
        tableView.addTableColumn(nameColumn)

        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "类型"
        typeColumn.width = 80
        tableView.addTableColumn(typeColumn)

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        view.addSubview(scrollView)

        // 信息标签
        infoLabel = NSTextField(labelWithString: "选择字体族")
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        view.addSubview(infoLabel)

        // 预览文本
        previewTextField = NSTextField(labelWithString: "Aa 仙人指路 123")
        previewTextField.translatesAutoresizingMaskIntoConstraints = false
        previewTextField.font = NSFont.systemFont(ofSize: 24)
        previewTextField.alignment = .center
        view.addSubview(previewTextField)

        // 布局约束
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            scrollView.heightAnchor.constraint(equalToConstant: 320),

            previewTextField.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12),
            previewTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            previewTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            previewTextField.heightAnchor.constraint(equalToConstant: 60),

            infoLabel.topAnchor.constraint(equalTo: previewTextField.bottomAnchor, constant: 8),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            infoLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -12)
        ])
    }

    // MARK: - 数据加载
    private func loadFonts() {
        let systemFonts = UIFontManager.shared.scanSystemFonts()
        let userFonts = UIFontManager.shared.registeredUserFontFamilies()
        allFamilies = systemFonts + userFonts
        filteredFamilies = allFamilies
        tableView.reloadData()
        infoLabel.stringValue = "共 \(allFamilies.count) 个字体族（系统 \(systemFonts.count) + 用户 \(userFonts.count)）"
    }

    @objc private func fontsChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.loadFonts()
        }
    }

    @objc private func searchChanged() {
        let query = searchField.stringValue.lowercased()
        if query.isEmpty {
            filteredFamilies = allFamilies
        } else {
            filteredFamilies = allFamilies.filter {
                $0.familyName.lowercased().contains(query) ||
                ($0.displayName?.lowercased().contains(query) ?? false)
            }
        }
        tableView.reloadData()
    }
}

// MARK: - 迁回自 UI-02：extension UIFontSelectorViewController
extension UIFontSelectorViewController: NSTableViewDataSource, NSTableViewDelegate {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredFamilies.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let family = filteredFamilies[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""

        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 12)

        switch identifier {
        case "name":
            textField.stringValue = family.displayName ?? family.familyName
        case "type":
            textField.stringValue = family.isUserRegistered ? "用户" : "系统"
            textField.textColor = family.isUserRegistered ? .systemOrange : .secondaryLabelColor
        default:
            textField.stringValue = ""
        }

        cell.textField = textField
        cell.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredFamilies.count else { return }
        selectedFamily = filteredFamilies[row]

        // 更新预览
        if let family = selectedFamily {
            let font = UIFontManager.shared.font(familyName: family.familyName, style: "Regular", size: 24)
            previewTextField.font = font
            previewTextField.stringValue = "\(family.familyName) Aa 仙人指路 123"
            infoLabel.stringValue = "\(family.familyName) — \(family.styleNames.count) 个样式"
            onFontSelected?(family)
        }
    }

    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 28
    }
}

// MARK: - 迁回自 UI-02：enum UIFontRegistrationResult
// MARK: - UI-GL-43 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-43_types.swift
// 版本: 2.0
// MARK: - 字体注册结果
/// 字体注册操作的返回结果
public enum UIFontRegistrationResult {
    /// 注册成功
    case success
    /// 注册失败，附带错误信息
    case failure(String)
    /// 字体已存在，无需重复注册
    case alreadyRegistered
}

// MARK: - 迁回自 UI-02：struct UIFontFamilyInfo
// MARK: - 序列化管理器
/// 将UI状态序列化/反序列化,支持跨设备同步
// 已迁回 UI-GL-42_布局序列化与恢复.swift：class UISerializationManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-43 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-43_types.swift
// 版本: 2.0
// MARK: - 字体族信息
/// 描述一个字体族的基本信息，用于系统字体扫描结果展示
public struct UIFontFamilyInfo: Codable, Identifiable {
    public var id = UUID()
    /// 字体族名称（如"PingFang SC"）
    public var familyName: String
    /// 该字体族下的所有样式名称（如"Regular","Bold"）
    public var styleNames: [String]
    /// 字体族展示名称（本地化后的友好名称）
    public var displayName: String?
    /// 是否为等宽字体
    public var isMonospaced: Bool
    /// 是否为用户自定义字体
    public var isUserRegistered: Bool

    public init(familyName: String, styleNames: [String], displayName: String? = nil, isMonospaced: Bool = false, isUserRegistered: Bool = false) {
        self.familyName = familyName
        self.styleNames = styleNames
        self.displayName = displayName
        self.isMonospaced = isMonospaced
        self.isUserRegistered = isUserRegistered
    }
}

// MARK: - 迁回自 UI-02：struct UIFontPair
// MARK: - 字体组合
/// 定义一组字体配对（标题字体 + 正文字体），用于统一UI风格
public struct UIFontPair: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    /// 组合名称（如"商务风格"）
    public var name: String
    /// 标题字体族名称
    public var titleFontFamily: String
    /// 标题字体样式（如"Bold"）
    public var titleFontStyle: String
    /// 标题字体基础字号
    public var titleFontSize: CGFloat
    /// 正文字体族名称
    public var bodyFontFamily: String
    /// 正文字体样式（如"Regular"）
    public var bodyFontStyle: String
    /// 正文字体基础字号
    public var bodyFontSize: CGFloat
    /// 行距倍数（相对于字号）
    public var lineSpacingMultiplier: CGFloat

    public init(name: String, titleFontFamily: String, titleFontStyle: String, titleFontSize: CGFloat, bodyFontFamily: String, bodyFontStyle: String, bodyFontSize: CGFloat, lineSpacingMultiplier: CGFloat = 1.5) {
        self.name = name
        self.titleFontFamily = titleFontFamily
        self.titleFontStyle = titleFontStyle
        self.titleFontSize = titleFontSize
        self.bodyFontFamily = bodyFontFamily
        self.bodyFontStyle = bodyFontStyle
        self.bodyFontSize = bodyFontSize
        self.lineSpacingMultiplier = lineSpacingMultiplier
    }

    /// 默认字体组合（系统字体）
    public static let `default` = UIFontPair(
        name: "系统默认",
        titleFontFamily: "PingFang SC",
        titleFontStyle: "Semibold",
        titleFontSize: 16,
        bodyFontFamily: "PingFang SC",
        bodyFontStyle: "Regular",
        bodyFontSize: 13,
        lineSpacingMultiplier: 1.5
    )
}

// MARK: - 迁回自 UI-02：struct UIFontManagerConfiguration
// MARK: - 字体设置配置
/// 可持久化的字体管理器配置
public struct UIFontManagerConfiguration: Codable {
    /// 当前选中的字体组合ID
    public var currentPairID: UUID?
    /// 用户自定义字体文件路径列表
    public var userFontPaths: [String]
    /// 字体回退栈（按优先级排列）
    public var fallbackStack: [String]
    /// 是否启用字体回退
    public var enableFallback: Bool
    /// 字体预览样本文本
    public var previewSampleText: String
    /// 预览字号列表
    public var previewSizes: [CGFloat]

    public init() {
        self.currentPairID = nil
        self.userFontPaths = []
        self.fallbackStack = ["PingFang SC", "Helvetica Neue", "Arial", "Menlo"]
        self.enableFallback = true
        self.previewSampleText = "仙人指路 字体预览\nThe quick brown fox jumps over the lazy dog.\n1234567890"
        self.previewSizes = [10, 12, 14, 16, 18, 24]
    }
}

// MARK: - 迁回自 UI-02：struct UIFontPreviewSnippet
// MARK: - 字体预览片段
/// 单个字体预览片段，包含字号、字重、行距等渲染信息
public struct UIFontPreviewSnippet: Identifiable {
    public var id = UUID()
    /// 字号
    public var fontSize: CGFloat
    /// 字重描述
    public var weightDescription: String
    /// 实际字体
    public var font: NSFont
    /// 行距
    public var lineSpacing: CGFloat
    /// 预览文本
    public var sampleText: String
    /// 字体族名称
    public var familyName: String

    public var attributedString: NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.labelColor
        ]
        return NSAttributedString(string: sampleText, attributes: attributes)
    }
}

// MARK: - 迁回自 UI-02：struct UIFontConfigurationSummaryData
// MARK: - 字体管理器配置摘要
/// 设置面板配置摘要数据（类型安全版本）
public struct UIFontConfigurationSummaryData: Codable {
    public let currentPair: String
    public let currentPairID: String
    public let userFontCount: Int
    public let fallbackEnabled: Bool
    public let fallbackStack: [String]
    public let previewSampleText: String
}
