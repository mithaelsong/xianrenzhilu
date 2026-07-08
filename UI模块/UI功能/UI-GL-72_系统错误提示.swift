//
//  UI-GL-72_系统错误提示.swift
//  仙人指路｜UI模块
//
//  版本：1.0
//  职责：系统级错误提示窗口。统一管理应用内所有错误提示的显示。
//  规则：所有模块的错误提示都通过此组件弹出，内容不同但 UI 一致。
//  调用：UIErrorAlertManager.shared.show(...)
//

import AppKit
import Foundation

// MARK: - 错误提示严重级别

public enum UIErrorSeverity: String, Codable, Sendable {
    case warning   // 黄色，可忽略
    case error     // 红色，需要用户知道但不阻塞
    case critical  // 红色高亮，需要用户处理，可能影响功能
}

// MARK: - 错误提示配置

public struct UIErrorAlertConfig: Sendable {
    public let title: String
    public let message: String
    public let detail: String?
    public let severity: UIErrorSeverity
    public let autoDismissAfter: TimeInterval?  // nil = 用户手动关闭
    public let showHelpButton: Bool
    public let helpURL: String?
    public let sourceModule: String

    public init(
        title: String,
        message: String,
        detail: String? = nil,
        severity: UIErrorSeverity = .error,
        autoDismissAfter: TimeInterval? = nil,
        showHelpButton: Bool = false,
        helpURL: String? = nil,
        sourceModule: String = "Unknown"
    ) {
        self.title = title
        self.message = message
        self.detail = detail
        self.severity = severity
        self.autoDismissAfter = autoDismissAfter
        self.showHelpButton = showHelpButton
        self.helpURL = helpURL
        self.sourceModule = sourceModule
    }
}

// MARK: - 错误提示管理器

/// 系统级错误提示管理器。线程安全。
/// 所有错误弹窗都在主线程显示，调用方可在任意线程调用 show。
public final class UIErrorAlertManager: @unchecked Sendable {
    public static let shared = UIErrorAlertManager()

    private let queue = DispatchQueue(label: "com.xianrenzhilu.ui.errorAlert")
    private var shownAlertIDs = Set<String>()
    private var activeWindow: NSWindow?

    private init() {
        // 监听 K线模块数据库连接失败通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDatabaseError(_:)),
            name: .klineDatabaseConnectionFailed,
            object: nil
        )
    }

    /// 显示错误提示窗口
    /// - Parameters:
    ///   - config: 错误提示配置
    ///   - dedupKey: 去重键。同一键在 30 秒内不重复显示。传 nil 每次都显示。
    ///   - onDismiss: 关闭回调
    public func show(
        config: UIErrorAlertConfig,
        dedupKey: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // 去重
            if let key = dedupKey {
                let now = Date()
                let cacheKey = "\(key)|\(Int(now.timeIntervalSince1970 / 30))"
                if self.shownAlertIDs.contains(cacheKey) { return }
                self.shownAlertIDs.insert(cacheKey)
                // 清理 60 秒前的老 key
                let staleBoundary = Int(now.timeIntervalSince1970 / 30) - 2
                self.shownAlertIDs = self.shownAlertIDs.filter { $0.hasSuffix("|\(staleBoundary)") == false && $0.hasSuffix("|\(staleBoundary - 1)") == false }
            }

            // 关闭旧窗口
            self.activeWindow?.close()
            self.activeWindow = nil

            // 创建窗口
            let window = self.makeAlertWindow(config: config, onDismiss: {
                self.activeWindow = nil
                onDismiss?()
            })

            // 自动关闭
            if let auto = config.autoDismissAfter, auto > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + auto) { [weak window] in
                    window?.close()
                    self.activeWindow = nil
                }
            }

            self.activeWindow = window

            // 定位到主窗口上方
            if let mainWin = NSApp.windows.first(where: { $0.isVisible }) {
                let mainFrame = mainWin.frame
                let wFrame = window.frame
                let x = mainFrame.midX - wFrame.width / 2
                let y = mainFrame.midY - wFrame.height / 2 + 100
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }

            // 模态运行
            if let mainWin = NSApp.windows.first(where: { $0.isVisible }) {
                mainWin.beginSheet(window) { _ in }
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - 快捷方法

    /// 显示数据库连接失败提示
    public static func showDatabaseError(_ reason: String) {
        shared.show(
            config: UIErrorAlertConfig(
                title: "数据库连接失败",
                message: "无法连接到本地数据库 (PostgreSQL)。部分数据可能不可用。",
                detail: reason,
                severity: .error,
                autoDismissAfter: nil,
                sourceModule: "KX-SJ-09"
            ),
            dedupKey: "kline.db.connectionFailed"
        )
    }

    /// 显示通用失败提示
    public static func showError(title: String, message: String, detail: String? = nil) {
        shared.show(
            config: UIErrorAlertConfig(
                title: title,
                message: message,
                detail: detail,
                severity: .error,
                sourceModule: "General"
            ),
            dedupKey: nil
        )
    }
}

// MARK: - 私有窗口构建

private extension UIErrorAlertManager {
    func makeAlertWindow(config: UIErrorAlertConfig, onDismiss: @escaping () -> Void) -> NSWindow {
        let width: CGFloat = 460
        let titlebarHeight: CGFloat = 32
        let contentHeight = contentHeightFor(config: config)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: contentHeight + titlebarHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = config.severity == .critical ? "⚠️ 严重错误" : (config.severity == .error ? "❌ 错误" : "⚠️ 提示")
        window.isReleasedWhenClosed = false
        window.level = .floating

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: contentHeight))
        contentView.wantsLayer = true

        // 背景色
        let bgColor: NSColor
        switch config.severity {
        case .critical:
            bgColor = NSColor(calibratedRed: 0.35, green: 0.08, blue: 0.08, alpha: 0.95)
        case .error:
            bgColor = NSColor(calibratedRed: 0.30, green: 0.10, blue: 0.10, alpha: 0.92)
        case .warning:
            bgColor = NSColor(calibratedRed: 0.35, green: 0.28, blue: 0.08, alpha: 0.92)
        }
        contentView.layer?.backgroundColor = bgColor.cgColor

        var yOffset: CGFloat = contentHeight - 40

        // 标题
        let titleLabel = NSTextField(labelWithString: config.title)
        titleLabel.frame = NSRect(x: 16, y: yOffset, width: width - 32, height: 24)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 15)
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)
        yOffset -= 28

        // 消息
        let messageLabel = NSTextField(wrappingLabelWithString: config.message)
        let msgHeight = messageLabel.sizeThatFits(NSSize(width: width - 32, height: 200)).height
        messageLabel.frame = NSRect(x: 16, y: yOffset - msgHeight, width: width - 32, height: msgHeight)
        messageLabel.font = NSFont.systemFont(ofSize: 13)
        messageLabel.textColor = NSColor(white: 0.85, alpha: 1)
        contentView.addSubview(messageLabel)
        yOffset = messageLabel.frame.minY - 8

        // 详细错误
        if let detail = config.detail, !detail.isEmpty {
            let detailLabel = NSTextField(wrappingLabelWithString: detail)
            let dtHeight = detailLabel.sizeThatFits(NSSize(width: width - 32, height: 300)).height
            let detailHeight = min(100, dtHeight)
            detailLabel.frame = NSRect(x: 16, y: yOffset - detailHeight, width: width - 32, height: detailHeight)
            detailLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            detailLabel.textColor = NSColor(white: 0.65, alpha: 1)
            contentView.addSubview(detailLabel)
            yOffset = detailLabel.frame.minY - 8
        }

        // 来源
        let sourceLabel = NSTextField(labelWithString: "来源模块: \(config.sourceModule)")
        sourceLabel.frame = NSRect(x: 16, y: yOffset - 18, width: width - 32, height: 16)
        sourceLabel.font = NSFont.systemFont(ofSize: 10)
        sourceLabel.textColor = NSColor(white: 0.5, alpha: 1)
        contentView.addSubview(sourceLabel)
        yOffset = sourceLabel.frame.minY - 12

        // 关闭按钮
        let closeButton = NSButton(title: "关闭", target: self, action: #selector(dismissAlert(_:)))
        closeButton.frame = NSRect(x: width - 96, y: yOffset - 4, width: 80, height: 24)
        closeButton.bezelStyle = .rounded
        closeButton.setButtonType(.momentaryPushIn)
        closeButton.tag = window.hashValue
        contentView.addSubview(closeButton)

        // 帮助按钮
        if config.showHelpButton, let helpURL = config.helpURL {
            let helpButton = NSButton(title: "帮助", target: self, action: #selector(openHelp(_:)))
            helpButton.frame = NSRect(x: width - 184, y: yOffset - 4, width: 80, height: 24)
            helpButton.bezelStyle = .rounded
            helpButton.setButtonType(.momentaryPushIn)
            helpButton.tag = 0
            objc_setAssociatedObject(helpButton, &helpURLKey, helpURL, .OBJC_ASSOCIATION_RETAIN)
            contentView.addSubview(helpButton)
        }

        window.contentView = contentView
        return window
    }

    func contentHeightFor(config: UIErrorAlertConfig) -> CGFloat {
        var h: CGFloat = 40 // title
        h += 28 // title->message gap
        let msgHeight = NSTextField(wrappingLabelWithString: config.message)
            .sizeThatFits(NSSize(width: 428, height: 200)).height
        h += msgHeight + 8
        if let detail = config.detail, !detail.isEmpty {
            h += min(100, NSTextField(wrappingLabelWithString: detail)
                .sizeThatFits(NSSize(width: 428, height: 300)).height) + 8
        }
        h += 18 + 12 // source + gap
        h += 28 + 8 // button + padding
        return max(180, min(500, h))
    }

    @objc func dismissAlert(_ sender: NSButton) {
        let window = NSApp.windows.first { $0.hashValue == sender.tag }
        window?.sheetParent?.endSheet(window!)
        window?.close()
    }

    @objc func openHelp(_ sender: NSButton) {
        if let urlStr = objc_getAssociatedObject(sender, &helpURLKey) as? String,
           let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }
}

private var helpURLKey: UInt8 = 0

// MARK: - 通知响应

private extension UIErrorAlertManager {
    @objc func handleDatabaseError(_ notification: Notification) {
        let reason = notification.object as? String
        show(
            config: UIErrorAlertConfig(
                title: "数据库连接失败",
                message: "无法连接到本地数据库 (PostgreSQL)。部分功能可能不可用。",
                detail: reason,
                severity: .error,
                autoDismissAfter: nil,
                sourceModule: "KX-SJ-09"
            ),
            dedupKey: "kline.db.connectionFailed"
        )
    }
}
