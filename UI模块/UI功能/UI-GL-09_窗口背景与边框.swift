// 功能09: 窗口背景与边框
// 对应: 窗口背景样式管理（纯色/渐变/图片），边框与圆角，自定义标题栏外观
// 优先级: P1
// 版本: 2.0

import Foundation
@preconcurrency import AppKit
import os

// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：extension NSColor {

// MARK: - parseHexColor 解析十六进制颜色
public func parseHexColor(_ hex: String) -> NSColor? {
    var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("#") { value.removeFirst() }
    guard value.count == 6, let intValue = Int(value, radix: 16) else { return nil }
    let r = CGFloat((intValue >> 16) & 0xff) / 255.0
    let g = CGFloat((intValue >> 8) & 0xff) / 255.0
    let b = CGFloat(intValue & 0xff) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
}

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能09A：窗口背景与边框 — 单元测试
/// 覆盖：渐变方向、标题栏外观、背景配置模型、NSColor hex扩展
func test_windowBackground() {
    print("\n🧪 测试1: 渐变方向枚举")
    let directions = UIGradientDirection.allCases
    guard directions.count == 4 else {
        fatalError("❌ 测试1失败: 应有4种渐变方向")
    }
    for dir in directions {
        let start = dir.startPoint
        let end = dir.endPoint
        guard start != end else {
            fatalError("❌ 测试1失败: 渐变方向\(dir) 的startPoint和endPoint应不同")
        }
    }
    print("✅ 测试1通过: 全部\(directions.count)种渐变方向配置正确")
    
    print("\n🧪 测试2: 标题栏外观枚举")
    let appearances = UITitleBarAppearance.allCases
    guard appearances.count == 4 else {
        fatalError("❌ 测试2失败: 应有4种标题栏外观")
    }
    for app in appearances {
        guard !app.rawValue.isEmpty else {
            fatalError("❌ 测试2失败: 标题栏外观 rawValue 为空")
        }
    }
    print("✅ 测试2通过: 全部\(appearances.count)种标题栏外观正确")
    
    print("\n🧪 测试3: 背景配置默认值")
    let config = UIWindowBackgroundConfiguration()
    guard config.backgroundType == .system else {
        fatalError("❌ 测试3失败: 默认背景类型应为system")
    }
    guard config.borderWidth == 0 else {
        fatalError("❌ 测试3失败: 默认边框宽度应为0")
    }
    guard config.cornerRadius == 0 else {
        fatalError("❌ 测试3失败: 默认圆角半径应为0")
    }
    print("✅ 测试3通过: 背景配置默认值正确")
    
    print("\n🧪 测试4: 背景配置Codable")
    var customConfig = UIWindowBackgroundConfiguration()
    customConfig.backgroundType = .gradient
    customConfig.borderWidth = 2.0
    customConfig.cornerRadius = 8.0
    guard let data = try? JSONEncoder().encode(customConfig) else {
        fatalError("❌ 测试4失败: 编码失败")
    }
    guard let decoded = try? JSONDecoder().decode(UIWindowBackgroundConfiguration.self, from: data) else {
        fatalError("❌ 测试4失败: 解码失败")
    }
    guard decoded.backgroundType == .gradient else {
        fatalError("❌ 测试4失败: 编解码后backgroundType不匹配")
    }
    guard abs(decoded.borderWidth - 2.0) < 0.01 else {
        fatalError("❌ 测试4失败: 编解码后borderWidth不匹配")
    }
    print("✅ 测试4通过: 背景配置Codable编解码正确")
    
    print("\n🧪 测试5: NSColor Hex转换")
    let color = NSColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0)
    let hex = color.hexString
    guard let restored = parseHexColor(hex) else {
        fatalError("❌ 测试5失败: fromHexString解析失败")
    }
    let hex2 = restored.hexString
    guard hex == hex2 else {
        fatalError("❌ 测试5失败: Hex双向转换不一致：\(hex) → \(hex2)")
    }
    print("✅ 测试5通过: NSColor Hex转换双向正确：\(hex)")
    
    print("\n🧪 测试6: NSColor Hex无效输入")
    let invalid = parseHexColor("XYZ")
    guard invalid == nil else {
        fatalError("❌ 测试6失败: 无效hex应返回nil")
    }
    print("✅ 测试6通过: 无效hex返回nil")
    
    print("\n🧪 测试7: 管理者初始状态")
    let manager = UIWindowBackgroundManager.shared
    let allConfigs = manager.allConfigurations()
    guard allConfigs.isEmpty else {
        fatalError("❌ 测试7失败: 初始应无配置")
    }
    print("✅ 测试7通过: 初始配置为空")
    
    print("\n=== 全部窗口背景测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWindowBackgroundManager
public final class UIWindowBackgroundManager : @unchecked Sendable {
    deinit {
        logger.info("UIWindowBackgroundManager 已释放")
    }
    
    public static let shared = UIWindowBackgroundManager()
    
    // MARK: - 属性
    
    /// 每个窗口的配置缓存：窗口ID -> 配置
    private var configurations: [String: UIWindowBackgroundConfiguration] = [:]
    
    /// 渐变图层缓存：窗口ID -> 渐变图层（用于移除旧图层）
    private var gradientLayers: [String: CAGradientLayer] = [:]
    
    /// 图片图层缓存：窗口ID -> 图片图层
    private var imageLayers: [String: CALayer] = [:]
    
    /// 线程安全锁
    private let lock = NSRecursiveLock()
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.xianrenzhilu", category: "UIWindowBackgroundManager")
    
    private init() {
        logger.info("[窗口背景管理器] 初始化完成")
    }
    
    // MARK: - 配置获取与保存
    
    /// 获取指定窗口的当前配置
    /// - Parameter windowID: 窗口唯一标识
    /// - Returns: 窗口背景配置，如不存在则返回默认配置
    public func configuration(for windowID: String) -> UIWindowBackgroundConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return configurations[windowID] ?? UIWindowBackgroundConfiguration()
    }
    
    /// 保存窗口配置
    /// - Parameters:
    ///   - config: 要保存的配置
    ///   - windowID: 窗口唯一标识
    private func saveConfiguration(_ config: UIWindowBackgroundConfiguration, for windowID: String) {
        lock.lock()
        configurations[windowID] = config
        lock.unlock()
    }
    
    /// 获取窗口实例（从窗口注册表）
    /// - Parameter windowID: 窗口唯一标识
    /// - Returns: NSWindow 实例
    private func window(for windowID: String) -> NSWindow? {
        return UIUnifiedRegistry.shared.getWindowRecord(windowID: windowID)?.window
    }
    
    // MARK: - 纯色背景
    
    /// 设置窗口纯色背景
    /// - Parameters:
    ///   - color: 背景颜色
    ///   - windowID: 目标窗口ID
    /// 效果：移除旧背景图层，直接设置窗口背景色，支持透明色
    public func setBackgroundColor(_ color: NSColor, for windowID: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let window = self.window(for: windowID) else {
            logger.warning("[窗口背景] 设置纯色背景失败：找不到窗口 \(windowID)")
            return
        }
        
        // 移除旧背景图层
        removeBackgroundLayers(for: windowID, window: window)
        
        // 设置窗口背景色
        window.backgroundColor = color
        
        // 更新配置
        var config = configurations[windowID] ?? UIWindowBackgroundConfiguration()
        config.backgroundType = .solidColor
        config.solidColorHex = color.hexString
        configurations[windowID] = config
        
        logger.info("[窗口背景] 已设置纯色背景：窗口\(windowID) 颜色\(color.hexString)")
        
        // 发送通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .windowBackgroundDidChange,
                object: nil,
                userInfo: ["windowID": windowID, "type": "solidColor"]
            )
        }
    }
    
    // MARK: - 渐变背景
    
    /// 设置窗口渐变背景
    /// - Parameters:
    ///   - colors: 渐变颜色数组（至少2个）
    ///   - direction: 渐变方向，默认从上到下
    ///   - windowID: 目标窗口ID
    /// 效果：在窗口内容视图底层插入CAGradientLayer，支持多色渐变
    public func setGradientBackground(
        colors: [NSColor],
        direction: UIGradientDirection = .topToBottom,
        for windowID: String
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let window = self.window(for: windowID) else {
            logger.warning("[窗口背景] 设置渐变背景失败：找不到窗口 \(windowID)")
            return
        }
        
        guard colors.count >= 2 else {
            logger.warning("[窗口背景] 设置渐变背景失败：至少需要2个颜色")
            return
        }
        
        // 移除旧背景图层
        removeBackgroundLayers(for: windowID, window: window)
        
        // 确保内容视图有图层
        guard let contentView = window.contentView else {
            logger.warning("[窗口背景] 设置渐变背景失败：窗口无内容视图")
            return
        }
        
        contentView.wantsLayer = true
        
        // 创建渐变图层
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = contentView.bounds
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = direction.startPoint
        gradientLayer.endPoint = direction.endPoint
        gradientLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        // 插入到内容视图图层的最底层
        if contentView.layer?.sublayers != nil {
            contentView.layer?.insertSublayer(gradientLayer, at: 0)
        } else {
            contentView.layer?.addSublayer(gradientLayer)
        }
        
        gradientLayers[windowID] = gradientLayer
        
        // 将窗口背景设为透明，以便显示渐变图层
        window.backgroundColor = .clear
        
        // 更新配置
        var config = configurations[windowID] ?? UIWindowBackgroundConfiguration()
        config.backgroundType = .gradient
        config.gradientStartColorHex = colors.first?.hexString
        config.gradientEndColorHex = colors.last?.hexString
        config.gradientDirection = direction.rawValue
        configurations[windowID] = config
        
        logger.info("[窗口背景] 已设置渐变背景：窗口\(windowID) 方向\(direction.rawValue)")
        
        // 发送通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .windowBackgroundDidChange,
                object: nil,
                userInfo: ["windowID": windowID, "type": "gradient"]
            )
        }
    }
    
    // MARK: - 图片背景
    
    /// 设置窗口图片背景
    /// - Parameters:
    ///   - image: 背景图片
    ///   - contentMode: 图片填充模式，默认缩放填充
    ///   - windowID: 目标窗口ID
    /// 效果：在窗口内容视图底层插入图片图层，支持缩放、平铺、拉伸等模式
    public func setBackgroundImage(
        _ image: NSImage,
        contentMode: CALayerContentsGravity = .resizeAspectFill,
        for windowID: String
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let window = self.window(for: windowID) else {
            logger.warning("[窗口背景] 设置图片背景失败：找不到窗口 \(windowID)")
            return
        }
        
        // 移除旧背景图层
        removeBackgroundLayers(for: windowID, window: window)
        
        // 确保内容视图有图层
        guard let contentView = window.contentView else {
            logger.warning("[窗口背景] 设置图片背景失败：窗口无内容视图")
            return
        }
        
        contentView.wantsLayer = true
        
        // 创建图片图层
        let imageLayer = CALayer()
        imageLayer.frame = contentView.bounds
        imageLayer.contents = image.cgImage
        imageLayer.contentsGravity = contentMode
        imageLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        // 插入到内容视图图层的最底层
        if contentView.layer?.sublayers != nil {
            contentView.layer?.insertSublayer(imageLayer, at: 0)
        } else {
            contentView.layer?.addSublayer(imageLayer)
        }
        
        imageLayers[windowID] = imageLayer
        
        // 将窗口背景设为透明
        window.backgroundColor = .clear
        
        // 更新配置
        var config = configurations[windowID] ?? UIWindowBackgroundConfiguration()
        config.backgroundType = .image
        // 尝试保存图片路径（如果图片有名称）
        if let imageName = image.name(), !imageName.isEmpty {
            config.imagePath = imageName
        }
        configurations[windowID] = config
        
        logger.info("[窗口背景] 已设置图片背景：窗口\(windowID) 图片尺寸\(image.size.width)×\(image.size.height)")
        
        // 发送通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .windowBackgroundDidChange,
                object: nil,
                userInfo: ["windowID": windowID, "type": "image"]
            )
        }
    }
    
    /// 通过文件路径设置窗口图片背景
    /// - Parameters:
    ///   - path: 图片文件绝对路径
    ///   - contentMode: 图片填充模式
    ///   - windowID: 目标窗口ID
    /// 效果：从磁盘加载图片并设置为背景，失败时记录错误日志
    public func setBackgroundImage(
        fromPath path: String,
        contentMode: CALayerContentsGravity = .resizeAspectFill,
        for windowID: String
    ) {
        guard let image = NSImage(contentsOfFile: path) else {
            logger.error("[窗口背景] 加载图片失败：\(path)")
            return
        }
        
        // 将图片加载和配置更新放在同一把锁内完成，避免递归加锁
        lock.lock()
        
        guard let window = self.window(for: windowID) else {
            lock.unlock()
            logger.warning("[窗口背景] 设置图片背景失败：找不到窗口 \(windowID)")
            return
        }
        
        removeBackgroundLayers(for: windowID, window: window)
        
        guard let contentView = window.contentView else {
            lock.unlock()
            logger.warning("[窗口背景] 设置图片背景失败：窗口无内容视图")
            return
        }
        
        contentView.wantsLayer = true
        
        let imageLayer = CALayer()
        imageLayer.frame = contentView.bounds
        imageLayer.contents = image.cgImage
        imageLayer.contentsGravity = contentMode
        imageLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        
        if contentView.layer?.sublayers != nil {
            contentView.layer?.insertSublayer(imageLayer, at: 0)
        } else {
            contentView.layer?.addSublayer(imageLayer)
        }
        
        imageLayers[windowID] = imageLayer
        window.backgroundColor = .clear
        
        var config = configurations[windowID] ?? UIWindowBackgroundConfiguration()
        config.backgroundType = .image
        config.imagePath = path
        configurations[windowID] = config
        
        lock.unlock()
        
        logger.info("[窗口背景] 已从路径加载图片：\(path)，窗口：\(windowID)")
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .windowBackgroundDidChange,
                object: nil,
                userInfo: ["windowID": windowID, "type": "image"]
            )
        }
    }
    
    // MARK: - 边框设置
    
    /// 设置窗口边框颜色
    /// - Parameters:
    ///   - color: 边框颜色
    ///   - windowID: 目标窗口ID
    /// 效果：通过内容视图的CALayer边框实现，与系统边框独立
    public func setBorderColor(_ color: NSColor, for windowID: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let window = self.window(for: windowID) else {
            logger.warning("[窗口边框] 设置边框颜色失败：找不到窗口 \(windowID)")
            return
        }
        
        guard let contentView = window.contentView else { return }
        
        contentView.wantsLayer = true
        contentView.layer?.borderColor = color.cgColor
        
        // 如果当前无边框宽度，默认设为1
        if contentView.layer?.borderWidth == 0 {
            contentView.layer?.borderWidth = 1.0
        }
        
        // 更新配置
        var config = configurations[windowID] ?? UIWindowBackgroundConfiguration()
        config.borderColorHex = color.hexString
        configurations[windowID] = config
        
        logger.info("[窗口边框] 已设置边框颜色：窗口\(windowID) 颜色\(color.hexString)")
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .windowBorderDidChange,
                object: nil,
                userInfo: ["windowID": windowID, "property": "borderColor"]
            )
        }
    }
    
    /// 设置窗口边框宽度
    /// - Parameters:
    ///   - width: 边框宽度（像素）
    ///   - windowID: 目标窗口ID
    /// 效果：设置内容视图CALayer的边框宽度，0表示无边框
    public func setBorderWidth(_ width: CGFloat, for windowID: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let window = self.window(for: windowID) else {
            logger.warning("[窗口边框] 设置边框宽度失败：找不到窗口 \(windowID)")
            return
        }
        
        guard let contentView = window.contentView else { return }
        
        contentView.wantsLayer = true
        contentView.layer?.borderWidth = width
        
        // 如果设置了边框宽度但没有颜色，默认使用系统边框色
        if width > 0 && contentView.layer?.borderColor == nil {
            contentView.layer?.borderColor = NSColor.separatorColor.cgColor
        }
        
        // 更新配置
        var config = configurations[windowID] ?? UIWindowBackgroundConfiguration()
        config.borderWidth = width
        configurations[windowID] = config
        
        logger.info("[窗口边框] 已设置边框宽度：窗口\(windowID) 宽度\(width)")
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .windowBorderDidChange,
                object: nil,
                userInfo: ["windowID": windowID, "property": "borderWidth"]
            )
        }
    }
    
    // MARK: - 圆角设置
    
    /// 设置窗口圆角半径
    /// - Parameters:
    ///   - radius: 圆角半径（像素），0表示直角
    ///   - windowID: 目标窗口ID
    /// 效果：同时设置窗口内容视图和背景图层的圆角，实现整体圆角效果
    /// 注意：圆角仅影响窗口内容区域，标题栏圆角由系统控制
    public func setCornerRadius(_ radius: CGFloat, for windowID: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let window = self.window(for: windowID) else {
            logger.warning("[窗口圆角] 设置圆角失败：找不到窗口 \(windowID)")
            return
        }
        
        guard let contentView = window.contentView else { return }
        
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = radius
        
        // 同时设置背景图层的圆角（如果存在）
        if let gradientLayer = gradientLayers[windowID] {
            gradientLayer.cornerRadius = radius
        }
        if let imageLayer = imageLayers[windowID] {
            imageLayer.cornerRadius = radius
        }
        
        // 设置内容视图裁剪，确保子视图也遵循圆角
        contentView.layer?.masksToBounds = true
        
        // 更新配置
        var config = configurations[windowID] ?? UIWindowBackgroundConfiguration()
        config.cornerRadius = radius
        configurations[windowID] = config
        
        logger.info("[窗口圆角] 已设置圆角半径：窗口\(windowID) 半径\(radius)")
    }
    
    // MARK: - 标题栏外观
    
    /// 设置窗口标题栏外观
    /// - Parameters:
    ///   - appearance: 标题栏外观模式
    ///   - customColor: 自定义标题栏颜色（仅在.customColor模式下有效）
    ///   - windowID: 目标窗口ID
    /// 效果：修改窗口styleMask、标题栏透明度、背景色等属性
    /// 注意：隐藏标题栏后窗口仍可通过拖拽边缘调整大小，关闭/最小化按钮仍可点击
    public func setTitleBarAppearance(
        _ appearance: UITitleBarAppearance,
        customColor: NSColor? = nil,
        for windowID: String
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let window = self.window(for: windowID) else {
            logger.warning("[标题栏] 设置外观失败：找不到窗口 \(windowID)")
            return
        }
        
        // 设置标题栏透明度
        window.titlebarAppearsTransparent = appearance.isTitlebarTransparent
        
        // 设置标题栏是否隐藏标题文字
        window.titleVisibility = appearance.isTitleHidden ? .hidden : .visible
        
        // 设置标题栏背景色（仅自定义颜色模式）
        if appearance == .customColor, let color = customColor {
            window.backgroundColor = color
            
            // 更新配置
            var config = configurations[windowID] ?? UIWindowBackgroundConfiguration()
            config.titleBarColorHex = color.hexString
            configurations[windowID] = config
        }
        
        // 更新配置
        var config = configurations[windowID] ?? UIWindowBackgroundConfiguration()
        config.titleBarAppearance = appearance.rawValue
        configurations[windowID] = config
        
        logger.info("[标题栏] 已设置外观：窗口\(windowID) 模式\(appearance.rawValue)")
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .windowTitleBarDidChange,
                object: nil,
                userInfo: ["windowID": windowID, "appearance": appearance.rawValue]
            )
        }
    }
    
    // MARK: - 重置为系统默认
    
    /// 将窗口重置为系统默认外观
    /// - Parameter windowID: 目标窗口ID
    /// 效果：移除所有自定义背景图层、边框、圆角，恢复系统默认背景色和标题栏
    public func resetToSystemDefault(for windowID: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let window = self.window(for: windowID) else {
            logger.warning("[窗口重置] 重置失败：找不到窗口 \(windowID)")
            return
        }
        
        // 移除所有自定义背景图层
        removeBackgroundLayers(for: windowID, window: window)
        
        // 重置窗口背景色为系统默认
        window.backgroundColor = .windowBackgroundColor
        
        // 重置内容视图边框和圆角
        if let contentView = window.contentView, let layer = contentView.layer {
            layer.borderWidth = 0
            layer.borderColor = nil
            layer.cornerRadius = 0
            layer.masksToBounds = false
        }
        
        // 重置标题栏为系统默认
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        
        // 移除配置缓存
        configurations.removeValue(forKey: windowID)
        
        logger.info("[窗口重置] 已重置为系统默认：窗口\(windowID)")
        
        // 发送通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .windowBackgroundDidChange,
                object: nil,
                userInfo: ["windowID": windowID, "type": "systemDefault"]
            )
            NotificationCenter.default.post(
                name: .windowBorderDidChange,
                object: nil,
                userInfo: ["windowID": windowID, "property": "reset"]
            )
            NotificationCenter.default.post(
                name: .windowTitleBarDidChange,
                object: nil,
                userInfo: ["windowID": windowID, "appearance": "default"]
            )
        }
    }
    
    // MARK: - 批量操作
    
    /// 将指定配置应用到窗口（用于恢复保存的配置）
    /// - Parameters:
    ///   - config: 窗口背景配置
    ///   - windowID: 目标窗口ID
    public func applyConfiguration(_ config: UIWindowBackgroundConfiguration, for windowID: String) {
        // 根据配置类型应用背景
        switch config.backgroundType {
        case .solidColor:
            if let hex = config.solidColorHex, let color = parseHexColor(hex) {
                setBackgroundColor(color, for: windowID)
            }
        case .gradient:
            if let startHex = config.gradientStartColorHex,
               let endHex = config.gradientEndColorHex,
               let startColor = parseHexColor(startHex),
               let endColor = parseHexColor(endHex) {
                let direction = UIGradientDirection.allCases.first {
                    $0.rawValue == config.gradientDirection
                } ?? .topToBottom
                setGradientBackground(colors: [startColor, endColor], direction: direction, for: windowID)
            }
        case .image:
            if let path = config.imagePath {
                setBackgroundImage(fromPath: path, for: windowID)
            }
        case .system:
            break // 保持系统默认
        }
        
        // 应用边框
        if let borderHex = config.borderColorHex, let borderColor = parseHexColor(borderHex) {
            setBorderColor(borderColor, for: windowID)
        }
        setBorderWidth(config.borderWidth, for: windowID)
        
        // 应用圆角
        setCornerRadius(config.cornerRadius, for: windowID)
        
        // 应用标题栏外观
        if let appearance = UITitleBarAppearance.allCases.first(where: { $0.rawValue == config.titleBarAppearance }) {
            let customColor: NSColor? = config.titleBarColorHex.flatMap { parseHexColor($0) }
            setTitleBarAppearance(appearance, customColor: customColor, for: windowID)
        }
        
        logger.info("[窗口背景] 已应用完整配置：窗口\(windowID)")
    }
    
    // MARK: - 内部方法
    
    /// 移除窗口的所有自定义背景图层
    /// - Parameters:
    ///   - windowID: 窗口ID
    ///   - window: 窗口实例
    private func removeBackgroundLayers(for windowID: String, window: NSWindow) {
        // 移除渐变图层
        if let gradientLayer = gradientLayers[windowID] {
            gradientLayer.removeFromSuperlayer()
            gradientLayers.removeValue(forKey: windowID)
        }
        
        // 移除图片图层
        if let imageLayer = imageLayers[windowID] {
            imageLayer.removeFromSuperlayer()
            imageLayers.removeValue(forKey: windowID)
        }
        
        // 清理内容视图的layer内容（避免残留）
        if let contentView = window.contentView {
            contentView.layer?.contents = nil
        }
    }
    
    /// 清理已关闭窗口的缓存
    /// - Parameter windowID: 已关闭的窗口ID
    public func cleanup(for windowID: String) {
        lock.lock()
        configurations.removeValue(forKey: windowID)
        gradientLayers.removeValue(forKey: windowID)
        imageLayers.removeValue(forKey: windowID)
        lock.unlock()
        logger.info("[窗口背景] 已清理窗口缓存：\(windowID)")
    }
    
    /// 获取所有已注册窗口的配置列表
    /// - Returns: 窗口ID到配置的映射
    public func allConfigurations() -> [String: UIWindowBackgroundConfiguration] {
        lock.lock()
        let copy = configurations
        lock.unlock()
        return copy
    }
}

// MARK: - 迁回自 UI-02：enum UIGradientDirection
// MARK: - UI功能公共类型批量补充合并（修正顶层解析器）
// 版本: 2.0


// MARK: - UI-GL-08 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-08_types.swift
// 版本: 2.0
// MARK: - 面板管理器
// 已迁回 UI-GL-08_面板类型系统.swift：class UIPanelManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-09 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-09_types.swift
// 版本: 2.0
// MARK: - 渐变方向
/// 渐变背景的方向枚举
public enum UIGradientDirection: String, CaseIterable {
    case topToBottom      = "从上到下"
    case leftToRight      = "从左到右"
    case topLeftToBottomRight = "从左上到右下"
    case topRightToBottomLeft = "从右上到左下"
    
    /// 转换为CAGradientLayer的坐标
    public var startPoint: CGPoint {
        switch self {
        case .topToBottom:           return CGPoint(x: 0.5, y: 1.0)
        case .leftToRight:           return CGPoint(x: 0.0, y: 0.5)
        case .topLeftToBottomRight:  return CGPoint(x: 0.0, y: 1.0)
        case .topRightToBottomLeft:  return CGPoint(x: 1.0, y: 1.0)
        }
    }
    
    public var endPoint: CGPoint {
        switch self {
        case .topToBottom:           return CGPoint(x: 0.5, y: 0.0)
        case .leftToRight:           return CGPoint(x: 1.0, y: 0.5)
        case .topLeftToBottomRight:  return CGPoint(x: 1.0, y: 0.0)
        case .topRightToBottomLeft:  return CGPoint(x: 0.0, y: 0.0)
        }
    }
}

// MARK: - 迁回自 UI-02：enum UITitleBarAppearance
// MARK: - 标题栏外观模式
/// 标题栏外观配置枚举
public enum UITitleBarAppearance: String, CaseIterable {
    case `default`    = "系统默认"      // 系统标准标题栏
    case hidden       = "完全隐藏"      // 完全隐藏标题栏（无边框模式）
    case transparent  = "透明标题栏"    // 透明背景，保留按钮
    case customColor  = "自定义颜色"    // 自定义标题栏背景色
    
    /// 对应的NSWindow.StyleMask
    public var styleMask: NSWindow.StyleMask {
        switch self {
        case .default:
            return [.titled, .closable, .miniaturizable, .resizable]
        case .hidden:
            return [.borderless, .closable, .miniaturizable, .resizable]
        case .transparent, .customColor:
            return [.titled, .closable, .miniaturizable, .resizable]
        }
    }
    
    /// 是否隐藏标题栏（titlebarAppearsTransparent）
    public var isTitlebarTransparent: Bool {
        switch self {
        case .transparent, .customColor, .hidden: return true
        case .default: return false
        }
    }
    
    /// 是否隐藏标题文字
    public var isTitleHidden: Bool {
        switch self {
        case .hidden: return true
        default: return false
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIWindowBackgroundType
// MARK: - 背景类型
/// 窗口背景类型枚举
public enum UIWindowBackgroundType: String, Codable {
    case solidColor = "纯色背景"
    case gradient   = "渐变背景"
    case image      = "图片背景"
    case system     = "系统默认"
}

// MARK: - 迁回自 UI-02：struct UIWindowBackgroundConfiguration
// MARK: - 窗口背景配置
/// 单个窗口的背景配置（可序列化）
public struct UIWindowBackgroundConfiguration: Codable {
    /// 背景类型
    public var backgroundType: UIWindowBackgroundType
    /// 纯色背景的十六进制颜色值
    public var solidColorHex: String?
    /// 渐变的起始颜色（十六进制）
    public var gradientStartColorHex: String?
    /// 渐变的结束颜色（十六进制）
    public var gradientEndColorHex: String?
    /// 渐变方向
    public var gradientDirection: String?
    /// 图片背景的文件路径
    public var imagePath: String?
    /// 边框颜色（十六进制）
    public var borderColorHex: String?
    /// 边框宽度
    public var borderWidth: CGFloat
    /// 圆角半径
    public var cornerRadius: CGFloat
    /// 标题栏外观模式
    public var titleBarAppearance: String
    /// 标题栏自定义颜色（十六进制）
    public var titleBarColorHex: String?
    
    public init() {
        self.backgroundType = .system
        self.solidColorHex = nil
        self.gradientStartColorHex = nil
        self.gradientEndColorHex = nil
        self.gradientDirection = UIGradientDirection.topToBottom.rawValue
        self.imagePath = nil
        self.borderColorHex = nil
        self.borderWidth = 0
        self.cornerRadius = 0
        self.titleBarAppearance = UITitleBarAppearance.default.rawValue
        self.titleBarColorHex = nil
    }
}
