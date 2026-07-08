// MARK: - 玻璃皮肤辅助文件
// 功能编号: UI-PF-09 (辅助)
// 版本: 3.0.0
// 职责: 集中存放玻璃皮肤专用辅助类和参数常量
// 规则: 本文件只包含皮肤内部实现的专用类/参数，禁止定义公共协议/公共模型

import Foundation
import AppKit
import QuartzCore
import os

private let glassSkinHelperLogger = Logger(subsystem: "com.xianrenzhilu.ui", category: "GlassSkinHelper")

// MARK: - 所有可配置参数集中管理（不动代码只改这里）

public struct GlassSkinConstants {
    // MARK: 功能栏
    public static let toolbarHeight: CGFloat = 60      // Safari unified toolbar 参考高度
    public static let windowCornerRadius: CGFloat = 14   // 主窗口玻璃根层圆角，恢复顶部圆角质感
    public static let trafficLightTopMargin: CGFloat = 0 // fullSizeContentView 后红绿灯按功能栏顶部坐标对齐；0 比 -18 继续上移
    public static let leftPadding: CGFloat = 16
    public static let buttonSpacing: CGFloat = 20

    // MARK: 齿轮按钮
    public static let settingsButtonSize: CGFloat = 38
    public static let settingsButtonRightMargin: CGFloat = 12
    public static let gearIconSize: CGFloat = 32

    public static let buttonCircleOpacity: CGFloat = 0.48
    public static let buttonCircleHoverOpacity: CGFloat = 0.68
    public static let borderWidth: CGFloat = 1.15
    public static let borderOpacity: CGFloat = 0.72
    public static let shadowOpacity: Float = 0.18
    public static let shadowHoverOpacity: Float = 0.28
    public static let shadowRadius: CGFloat = 13
    public static let shadowHoverRadius: CGFloat = 18
    public static let shadowOffset: CGSize = CGSize(width: 0, height: -4)

    // 深色主题下的按钮参数
    public static let buttonCircleDarkOpacity: CGFloat = 0.35
    public static let buttonCircleDarkHoverOpacity: CGFloat = 0.50

    // MARK: 按钮动画
    public static let buttonHoverScale: CGFloat = 1.08
    public static let buttonHoverDuration: CGFloat = 0.18
    public static let buttonHoverExitDuration: CGFloat = 0.24
    public static let buttonPressScale: CGFloat = 0.92
    public static let buttonPressDuration: CGFloat = 0.08
    public static let buttonBounceMass: CGFloat = 0.7
    public static let buttonBounceStiffness: CGFloat = 260
    public static let buttonBounceDamping: CGFloat = 18
    public static let buttonBounceVelocity: CGFloat = 9

    // MARK: 设置面板
    public static let panelMinWidth: CGFloat = 720
    public static let panelMaxWidth: CGFloat = 980
    public static let panelWidthRatio: CGFloat = 0.82
    public static let panelCornerRadius: CGFloat = 22
    public static let panelBorderWidth: CGFloat = 1.35
    public static let panelBorderOpacity: CGFloat = 0.72
    public static let panelShadowRadius: CGFloat = 32
    public static let panelShadowOffset: CGSize = CGSize(width: -10, height: 0)
    public static let panelShadowOpacity: Float = 0.20
    public static let panelBackgroundOpacity: CGFloat = 0.20

    // MARK: 设置面板动画
    public static let panelSpringMass: CGFloat = 0.88
    public static let panelSpringStiffness: CGFloat = 150
    public static let panelSpringDamping: CGFloat = 19
    public static let panelSpringVelocity: CGFloat = 6
    public static let panelSlideInDuration: CFTimeInterval = 0.60
    public static let panelSlideOutDuration: CFTimeInterval = 0.50
    public static let panelOpacityDuration: CFTimeInterval = 0.22
    public static let panelOpacityOutDuration: CFTimeInterval = 0.24

    // MARK: 边缘手势
    public static let edgeGestureWidth: CGFloat = 34
    public static let edgeGestureTriggerThreshold: CGFloat = 34
    public static let edgeGestureCooldown: CFTimeInterval = 0.55

    // MARK: 卡片
    public static let cardWidth: CGFloat = 426
    public static let cardHeight: CGFloat = 240
    public static let cardCornerRadius: CGFloat = 18
    public static let cardShadowOpacity: Float = 0.20
    public static let cardShadowRadius: CGFloat = 20
    public static let cardShadowOffset: CGSize = CGSize(width: 0, height: -9)
    public static let cardBackgroundOpacity: CGFloat = 0.18
    public static let cardBorderWidth: CGFloat = 1.1

    // MARK: 卡片堆叠布局
    public static let cardStackOffset: CGFloat = 72
    public static let cardStackRotation: CGFloat = 1.8
    public static let cardStackBottomMargin: CGFloat = 26
    public static let cardScatterDx: CGFloat = 18
    public static let cardScatterDy: CGFloat = 10
    public static let cardScatterScale: CGFloat = 0.985

    // MARK: 卡片鼠标跟随
    public static let cardHoverMaxDx: CGFloat = 12
    public static let cardHoverMaxDy: CGFloat = 8
    public static let cardHoverScaleIncrease: CGFloat = 0.065
    public static let themeCardExpandedScaleIncrease: CGFloat = 0.24
    public static let themeExpandedCardHorizontalMargin: CGFloat = 34
    public static let themeExpandedCardVerticalMargin: CGFloat = 42
    public static let themeExpandedCardMaxHeightRatio: CGFloat = 0.68
    public static let themeMenuContentInsetX: CGFloat = 44
    public static let themeMenuContentInsetY: CGFloat = 38
    public static let themeMenuTitleTop: CGFloat = 32
    public static let themeMenuTitleLeft: CGFloat = 44
    public static let themeMenuTitleFontSize: CGFloat = 24
    public static let themeMenuSubtitleFontSize: CGFloat = 13
    public static let themeMenuSubtitleTopGap: CGFloat = 6
    public static let themeOptionButtonWidth: CGFloat = 190
    public static let themeOptionButtonHeight: CGFloat = 74
    public static let themeOptionButtonCornerRadius: CGFloat = 37
    public static let themeOptionHorizontalGap: CGFloat = 26
    public static let themeOptionVerticalGap: CGFloat = 24
    public static let themeOptionTopFromSubtitle: CGFloat = 46
    public static let themeOptionNormalBorderWidth: CGFloat = 1.1
    public static let themeOptionSelectedBorderWidth: CGFloat = 2.2
    public static let themeOptionSelectedGlowOpacity: CGFloat = 0.35
    public static let themeOptionNormalBorderAlpha: CGFloat = 0.42
    public static let themeOptionSelectedColor: NSColor = .systemGreen
    public static let themeOptionTitleFontSize: CGFloat = 17
    public static let cardHoverElevation: CGFloat = 12
    public static let cardHoverShadowOpacity: Float = 0.30
    public static let cardHoverShadowRadius: CGFloat = 28
    public static let cardHoverM34: CGFloat = -1.0 / 700
    public static let cardHoverFollowDuration: CFTimeInterval = 0.10
    public static let cardInitialCurveApplyDelay: CFTimeInterval = 0.08

    // MARK: 卡片动画
    public static let cardSpringMass: CGFloat = 0.72
    public static let cardSpringStiffness: CGFloat = 210
    public static let cardSpringDamping: CGFloat = 21
    public static let cardSpringVelocity: CGFloat = 5
    public static let cardTransitionDuration: CFTimeInterval = 0.18
    public static let cardEntryDelay: CFTimeInterval = 0.045
    public static let cardEntryStartOffset: CGFloat = 0

    // MARK: 卡片音效
    public static let cardHoverSoundName: String = "Funk"
    public static let cardHoverSoundType: String = "aiff"

    // MARK: 面板标题
    public static let panelTitleFontSize: CGFloat = 24
    public static let panelSubtitleFontSize: CGFloat = 12
    public static let panelTitleLeftMargin: CGFloat = 28
    public static let panelSubtitleLeftMargin: CGFloat = 29
    public static let panelScrollViewLeftMargin: CGFloat = 18
    public static let panelScrollViewTopMargin: CGFloat = 112
    public static let panelScrollViewBottomMargin: CGFloat = 36

    // MARK: 卡片内布局
    public static let cardSymbolSize: CGFloat = 30
    public static let cardSymbolLeftMargin: CGFloat = 18
    public static let cardTitleFontSize: CGFloat = 17
    public static let cardSubtitleFontSize: CGFloat = 12
    public static let cardTitleLeftMargin: CGFloat = 60
    public static let cardSubtitleBottomMargin: CGFloat = 20
    public static let cardSubtitleMaxWidth: CGFloat = 40

    // MARK: 窗口
    public static let windowMinWidth: CGFloat = 800
    public static let windowMinHeight: CGFloat = 600
    public static let windowSkinDefaultId = "com.app.glass"

    // MARK: 分割线
    public static let separatorHeight: CGFloat = 1.25
    public static let separatorOpacity: CGFloat = 0.52
    public static let separatorWhite: CGFloat = 0.62

    // MARK: 玻璃高光
    public static let sheenHeight: CGFloat = 18
    public static let sheenOpacity1: CGFloat = 0.62
    public static let sheenOpacity2: CGFloat = 0.18
    public static let sheenOpacity3: CGFloat = 0.02
    public static let darkToolbarWhite: CGFloat = 0.1176  // macOS DarkAqua windowBackgroundColor ≈ #1E1E1E
    public static let darkToolbarBlackAlpha: CGFloat = 1.0
    public static let darkToolbarSheenOpacity1: CGFloat = 0.14
    public static let darkToolbarSheenOpacity2: CGFloat = 0.045
    public static let darkToolbarSheenOpacity3: CGFloat = 0.0
    public static let darkContentWhite: CGFloat = 0.1569  // macOS DarkAqua underPageBackgroundColor ≈ #282828
    public static let darkContentAlpha: CGFloat = 1.0
    public static let darkContentGlassHighlightOpacity: CGFloat = 0.09
    public static let darkContentGlassVignetteOpacity: CGFloat = 0.12

    private init() {}
}

// MARK: - 主题工具

public struct GlassThemeHelper {
    /// 当前玻璃皮肤内部主题。主题不是皮肤；玻璃皮肤始终是 com.app.glass。
    public static func currentThemeId() -> String {
        let stored = UserDefaults.standard.string(forKey: "com.xianrenzhilu.glass.visualThemeId")
            ?? UserDefaults.standard.string(forKey: "com.xianrenzhilu.theme.currentThemeId")
            ?? UserDefaults.standard.string(forKey: "com.xianrenzhilu.glass.visualSkinId")
            ?? "built-in-light"
        return normalizeThemeId(stored)
    }

    /// 兼容旧调用名。旧 visualSkinId 语义已废弃，实际返回主题 ID。
    public static func currentSkinId() -> String { currentThemeId() }

    public static func normalizeThemeId(_ id: String) -> String {
        switch id {
        case "com.app.light", "built-in-light": return "built-in-light"
        case "com.app.dark", "built-in-dark": return "built-in-dark"
        case "com.app.highContrast", "com.app.high-contrast", "built-in-high-contrast", "built-in-highcontrast": return "built-in-highcontrast"
        case "com.app.protanopia", "built-in-protanopia": return "built-in-protanopia"
        case "com.app.deuteranopia", "built-in-deuteranopia": return "built-in-deuteranopia"
        default: return id
        }
    }

    public static func isDarkAppearance() -> Bool {
        let themeId = currentThemeId()
        if themeId == "built-in-dark" { return true }
        if themeId == "built-in-light" || themeId == "built-in-highcontrast" || themeId == "built-in-protanopia" || themeId == "built-in-deuteranopia" { return false }
        guard let appearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) else {
            return false
        }
        return appearance == .darkAqua
    }

    /// 主题驱动玻璃材质外观。浅色主题必须强制 Aqua，不能继续跟随系统深色材质。
    public static func nsAppearance() -> NSAppearance? {
        switch currentThemeId() {
        case "built-in-dark":
            return NSAppearance(named: .darkAqua)
        case "built-in-light", "built-in-highcontrast", "built-in-protanopia", "built-in-deuteranopia":
            return NSAppearance(named: .aqua)
        default:
            return nil
        }
    }

    /// 深色主题下，按钮玻璃圈的颜色
    public static func settingsButtonBackgroundColor() -> CGColor {
        if isDarkAppearance() {
            return NSColor(calibratedWhite: 0.34, alpha: 0.72).cgColor
        }
        return NSColor.white.withAlphaComponent(GlassSkinConstants.buttonCircleOpacity).cgColor
    }

    /// 深色主题下，按钮玻璃圈悬停颜色
    public static func settingsButtonHoverBackgroundColor() -> CGColor {
        if isDarkAppearance() {
            return NSColor(calibratedWhite: 0.46, alpha: 0.82).cgColor
        }
        return NSColor.white.withAlphaComponent(GlassSkinConstants.buttonCircleHoverOpacity).cgColor
    }

    /// 功能栏背景（深色主题用近黑，浅色用半透明白）
    /// ⚠️ 2026-06-22：深色值调深，与 K线模块主功能栏(KLUITheme.toolbarBackground)一致。
    public static func toolbarBackgroundColor() -> CGColor {
        if isDarkAppearance() {
            // 与 K线主功能栏同色：RGB(0.018, 0.020, 0.026)
            return NSColor(calibratedRed: 0.018, green: 0.020, blue: 0.026,
                           alpha: GlassSkinConstants.darkToolbarBlackAlpha).cgColor
        }
        return NSColor(calibratedWhite: 0.98, alpha: 0.72).cgColor
    }

    /// 主内容区背景：深色模式为灰黑色，浅色保持透明玻璃。
    public static func contentBackgroundColor() -> CGColor {
        if isDarkAppearance() {
            return NSColor(calibratedWhite: GlassSkinConstants.darkContentWhite,
                           alpha: GlassSkinConstants.darkContentAlpha).cgColor
        }
        return NSColor(calibratedWhite: 0.98, alpha: 0.34).cgColor
    }

    /// 卡片背景（深色中灰，浅色半透明白）
    public static func cardBackgroundColor() -> CGColor {
        switch currentThemeId() {
        case "built-in-dark":
            return NSColor(calibratedWhite: 0.22, alpha: GlassSkinConstants.cardBackgroundOpacity).cgColor
        case "built-in-highcontrast":
            return NSColor(calibratedWhite: 0.96, alpha: 0.92).cgColor
        case "built-in-protanopia":
            return NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.45, alpha: 0.34).cgColor
        case "built-in-deuteranopia":
            return NSColor(calibratedRed: 0.58, green: 0.48, blue: 1.0, alpha: 0.30).cgColor
        default:
            return NSColor(calibratedWhite: 1.0, alpha: 0.62).cgColor
        }
    }

    /// 设置面板背景（深色中灰，浅色半透明白）
    public static func panelBackgroundColor() -> CGColor {
        switch currentThemeId() {
        case "built-in-dark":
            return NSColor(calibratedWhite: 0.18, alpha: GlassSkinConstants.panelBackgroundOpacity).cgColor
        case "built-in-highcontrast":
            return NSColor(calibratedWhite: 0.94, alpha: 0.88).cgColor
        case "built-in-protanopia":
            return NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.62, alpha: 0.30).cgColor
        case "built-in-deuteranopia":
            return NSColor(calibratedRed: 0.62, green: 0.55, blue: 1.0, alpha: 0.26).cgColor
        default:
            return NSColor(calibratedWhite: 1.0, alpha: 0.70).cgColor
        }
    }

    /// 分割线颜色
    public static func separatorColor() -> CGColor {
        if isDarkAppearance() {
            return NSColor(calibratedWhite: 0.40, alpha: GlassSkinConstants.separatorOpacity).cgColor
        }
        return NSColor(calibratedWhite: GlassSkinConstants.separatorWhite, alpha: GlassSkinConstants.separatorOpacity).cgColor
    }

    /// 面板边框颜色
    public static func panelBorderColor() -> CGColor {
        if isDarkAppearance() {
            return NSColor(calibratedWhite: 0.55, alpha: GlassSkinConstants.panelBorderOpacity).cgColor
        }
        return NSColor(calibratedWhite: 0.72, alpha: GlassSkinConstants.panelBorderOpacity).cgColor
    }

    /// 卡片边框颜色
    public static func cardBorderColor() -> CGColor {
        if isDarkAppearance() {
            return NSColor(calibratedWhite: 0.60, alpha: 0.50).cgColor
        }
        return NSColor.white.withAlphaComponent(0.86).cgColor
    }
}

// MARK: - 音效管理器

public final class GlassSoundManager {
    public static let shared = GlassSoundManager()
    private var cachedSounds: [String: NSSound] = [:]
    private var lastPlayTime: TimeInterval = 0
    private let cooldown: TimeInterval = 0.04

    private init() {}

    public func playHoverTick() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPlayTime > cooldown else { return }
        lastPlayTime = now
        let soundName = GlassSkinConstants.cardHoverSoundName
        let soundType = GlassSkinConstants.cardHoverSoundType
        if let cached = cachedSounds[soundName] {
            cached.play()
            return
        }
        if let sound = NSSound(named: soundName) {
            cachedSounds[soundName] = sound
            sound.play()
        } else {
            // 尝试从系统 Sounds 目录加载
            let path = "/System/Library/Sounds/\(soundName).\(soundType)"
            if let sound = NSSound(contentsOfFile: path, byReference: false) {
                cachedSounds[soundName] = sound
                sound.play()
            }
        }
    }
}

// MARK: - 手势边缘视图

public final class GlassEdgeGestureView: NSView {
    public var onSwipeLeft: (() -> Void)?
    public var onSwipeRight: (() -> Void)?
    private var accumulatedX: CGFloat = 0
    private var lastTriggerTime: TimeInterval = 0

    override public var acceptsFirstResponder: Bool { true }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override public func swipe(with event: NSEvent) {
        if event.deltaX < 0 {
            triggerLeftSwipe()
        } else if event.deltaX > 0 {
            triggerRightSwipe()
        } else {
            super.swipe(with: event)
        }
    }

    override public func scrollWheel(with event: NSEvent) {
        let rawX = event.scrollingDeltaX
        let rawY = event.scrollingDeltaY
        guard abs(rawX) > abs(rawY), abs(rawX) > 0.4 else {
            super.scrollWheel(with: event)
            return
        }
        let fingerMotionX = event.isDirectionInvertedFromDevice ? -rawX : rawX
        accumulatedX += fingerMotionX
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTriggerTime > GlassSkinConstants.edgeGestureCooldown else { return }

        if accumulatedX < -GlassSkinConstants.edgeGestureTriggerThreshold {
            triggerLeftSwipe()
        } else if accumulatedX > GlassSkinConstants.edgeGestureTriggerThreshold {
            triggerRightSwipe()
        }
    }

    private func triggerLeftSwipe() {
        lastTriggerTime = ProcessInfo.processInfo.systemUptime
        accumulatedX = 0
        onSwipeLeft?()
    }

    private func triggerRightSwipe() {
        lastTriggerTime = ProcessInfo.processInfo.systemUptime
        accumulatedX = 0
        onSwipeRight?()
    }
}

// MARK: - 内容容器视图（固定尺寸随窗口，非无限画布）

public final class GlassContentView: NSView {
    private let glassHighlightLayer = CAGradientLayer()
    private let vignetteLayer = CAGradientLayer()

    override public var isFlipped: Bool { true }
    override public var allowsVibrancy: Bool { true }
    override public var acceptsFirstResponder: Bool { true }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
        layer?.backgroundColor = GlassThemeHelper.contentBackgroundColor()
        glassHighlightLayer.startPoint = CGPoint(x: 0, y: 1)
        glassHighlightLayer.endPoint = CGPoint(x: 1, y: 0)
        layer?.addSublayer(glassHighlightLayer)
        vignetteLayer.startPoint = CGPoint(x: 0.5, y: 1)
        vignetteLayer.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.addSublayer(vignetteLayer)
    }

    override public func layout() {
        super.layout()
        layer?.backgroundColor = GlassThemeHelper.contentBackgroundColor()
        glassHighlightLayer.frame = bounds
        vignetteLayer.frame = bounds
        if GlassThemeHelper.isDarkAppearance() {
            glassHighlightLayer.colors = [
                NSColor.white.withAlphaComponent(GlassSkinConstants.darkContentGlassHighlightOpacity).cgColor,
                NSColor.white.withAlphaComponent(0.025).cgColor,
                NSColor.clear.cgColor
            ]
            vignetteLayer.colors = [
                NSColor.black.withAlphaComponent(0.0).cgColor,
                NSColor.black.withAlphaComponent(GlassSkinConstants.darkContentGlassVignetteOpacity).cgColor
            ]
        } else {
            glassHighlightLayer.colors = [
                NSColor.white.withAlphaComponent(0.10).cgColor,
                NSColor.white.withAlphaComponent(0.02).cgColor,
                NSColor.clear.cgColor
            ]
            vignetteLayer.colors = [NSColor.clear.cgColor, NSColor.clear.cgColor]
        }
    }

    override public func magnify(with event: NSEvent) {
        super.magnify(with: event)
    }

    override public func rotate(with event: NSEvent) {
        super.rotate(with: event)
    }

    override public func smartMagnify(with event: NSEvent) {
        super.smartMagnify(with: event)
    }
}

// MARK: - 便捷动画工具

public struct GlassAnimationTools {
    /// 创建弹簧动画
    public static func springAnimation(keyPath: String, from: Any?, to: Any, mass: CGFloat, stiffness: CGFloat, damping: CGFloat, velocity: CGFloat) -> CASpringAnimation {
        let spring = CASpringAnimation(keyPath: keyPath)
        if let from { spring.fromValue = from }
        spring.toValue = to
        spring.mass = mass
        spring.stiffness = stiffness
        spring.damping = damping
        spring.initialVelocity = velocity
        spring.duration = spring.settlingDuration
        return spring
    }

    /// 创建一般动画
    public static func basicAnimation(keyPath: String, to: Any, duration: CFTimeInterval, timingFunction: CAMediaTimingFunctionName = .easeOut) -> CABasicAnimation {
        let anim = CABasicAnimation(keyPath: keyPath)
        anim.toValue = to
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: timingFunction)
        return anim
    }

    /// 应用弹簧位置动画
    public static func animateSpringPosition(layer: CALayer, from: CGPoint, to: CGPoint, mass: CGFloat, stiffness: CGFloat, damping: CGFloat, velocity: CGFloat, key: String) {
        let spring = springAnimation(keyPath: "position", from: from, to: to, mass: mass, stiffness: stiffness, damping: damping, velocity: velocity)
        layer.add(spring, forKey: key)
        layer.position = to
    }

    /// 应用不透明度动画
    public static func animateOpacity(layer: CALayer, from: CGFloat? = nil, to: CGFloat, duration: CFTimeInterval, key: String) {
        let anim = basicAnimation(keyPath: "opacity", to: to, duration: duration)
        if let from { anim.fromValue = from }
        layer.add(anim, forKey: key)
        layer.opacity = Float(to)
    }
}
