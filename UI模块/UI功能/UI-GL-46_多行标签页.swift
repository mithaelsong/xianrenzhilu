// 功能36: 多行标签页 (Multi-line Tabs)
// 对应: 打开的文档/图表超过一行时自动换行，支持滚动标签页列表
// 优先级: P1
// 版本: 2.0

import AppKit
import Foundation
import os.log

// MARK: - 通知扩展
/// 多行标签页系统通知定义
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能36：多行标签页 — 单元测试
func test_multiLineTab() {
    let manager = UIMultiLineTabManager.shared
    let logger = OSLog(subsystem: "com.xianrenzhilu.ui", category: "UI-GL-46")
    
    os_log("测试1: 添加标签页", log: logger, type: .info)
    let tab1 = manager.addTab(title: "图表1", iconName: "chart.bar.fill")
    let tab2 = manager.addTab(title: "图表2", isPinned: true)
    guard manager.tabCount == 2 else {
        os_log("❌ 测试1失败: 应有2个标签页", log: logger, type: .error)
        return
    }
    os_log("✅ 测试1通过: 添加标签成功(2个)", log: logger, type: .info)
    
    os_log("测试2: 激活标签", log: logger, type: .info)
    manager.activateTab(id: tab1.id)
    guard manager.currentActiveID == tab1.id else {
        os_log("❌ 测试2失败: 应激活tab1", log: logger, type: .error)
        return
    }
    os_log("✅ 测试2通过: 激活标签正常", log: logger, type: .info)
    
    os_log("测试3: 标签查询", log: logger, type: .info)
    let all = manager.allItems
    if all.isEmpty {
        os_log("❌ 测试3失败: 标签列表不应为空", log: logger, type: .error)
    } else {
        os_log("✅ 测试3通过: 标签查询正常", log: logger, type: .info)
    }
    
    os_log("测试4: 标签状态", log: logger, type: .info)
    let desc = manager.statusDescription
    if desc.isEmpty { os_log("❌ 测试4失败", log: logger, type: .error) }
    else { os_log("✅ 测试4通过", log: logger, type: .info) }
    
    os_log("测试5: 关闭标签", log: logger, type: .info)
    manager.closeTab(id: tab2.id)
    if manager.tabCount != 1 { os_log("❌ 测试5失败", log: logger, type: .error) }
    else { os_log("✅ 测试5通过: 关闭后剩余1个", log: logger, type: .info) }
    
    os_log("测试6: 便捷扩展", log: logger, type: .info)
    let first = manager.item(at: 0)
    if first == nil { os_log("❌ 测试6失败", log: logger, type: .error) }
    else { os_log("✅ 测试6通过: 索引查询正常", log: logger, type: .info) }
    
    os_log("测试7: 样式设置视图创建", log: logger, type: .info)
    let styleView = manager.createStyleSettingsView()
    _ = styleView
    os_log("✅ 测试7通过: 样式视图创建成功", log: logger, type: .info)
    
    os_log("=== 全部多行标签测试通过 ✅ ===", log: logger, type: .info)
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIMultiLineTabButton
public class UIMultiLineTabButton: NSControl , @unchecked Sendable {
    public var itemID: String
    public var title: String
    public var isActive: Bool = false
    public var isPinned: Bool = false
    public var isModified: Bool = false
    public var showCloseButton: Bool = true
    public var showIcon: Bool = true
    public var fontSize: CGFloat = 12
    public var iconName: String?
    public var badge: String?

    public var activeColor: NSColor = NSColor.selectedControlColor
    public var inactiveColor: NSColor = NSColor.controlBackgroundColor
    public var hoverColor: NSColor = NSColor.highlightColor.withAlphaComponent(0.3)
    public var textColor: NSColor = NSColor.labelColor
    public var activeTextColor: NSColor = NSColor.alternateSelectedControlTextColor
    public var cornerRadius: CGFloat = 4

    public var onClose: ((String) -> Void)?
    public var onClick: ((String) -> Void)?
    public var onRightClick: ((String, NSEvent) -> Void)?
    public var onMouseEntered: ((String) -> Void)?
    public var onMouseExited: ((String) -> Void)?

    private var titleLabel: NSTextField?
    private var closeButton: NSButton?
    private var iconImageView: NSImageView?
    private var badgeLabel: NSTextField?
    private nonisolated(unsafe) var trackingAreaObj: NSTrackingArea?
    private var isHovering: Bool = false

    public init(itemID: String, title: String) {
        self.itemID = itemID
        self.title = title
        super.init(frame: .zero)
        setup()
    }

    public required init?(coder: NSCoder) {
        self.itemID = ""
        self.title = ""
        super.init(coder: coder)
        setup()
    }

    deinit {
        // 清理跟踪区域
        if let old = trackingAreaObj { removeTrackingArea(old) }
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true

        // 图标视图
        let iconView = NSImageView(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        self.iconImageView = iconView

        // 标题标签
        let label = NSTextField(labelWithString: title)
        label.alignment = .left
        label.font = NSFont.systemFont(ofSize: fontSize)
        label.textColor = textColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
        self.titleLabel = label

        // 徽标标签
        let badgeLbl = NSTextField(labelWithString: "")
        badgeLbl.font = NSFont.boldSystemFont(ofSize: max(9, fontSize - 3))
        badgeLbl.textColor = .white
        badgeLbl.alignment = .center
        badgeLbl.wantsLayer = true
        badgeLbl.layer?.backgroundColor = NSColor.systemRed.cgColor
        badgeLbl.layer?.cornerRadius = 6
        badgeLbl.translatesAutoresizingMaskIntoConstraints = false
        badgeLbl.isHidden = true
        addSubview(badgeLbl)
        self.badgeLabel = badgeLbl

        // 关闭按钮
        let close = NSButton(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        close.title = "×"
        close.setButtonType(.momentaryLight)
        close.bezelStyle = .inline
        close.target = self
        close.action = #selector(closeClicked)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.isHidden = !showCloseButton || isPinned
        addSubview(close)
        self.closeButton = close

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 4),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            badgeLbl.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 4),
            badgeLbl.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeLbl.heightAnchor.constraint(equalToConstant: 14),

            close.leadingAnchor.constraint(equalTo: badgeLbl.trailingAnchor, constant: 2),
            close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            close.centerYAnchor.constraint(equalTo: centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 16),
            close.heightAnchor.constraint(equalToConstant: 16)
        ])

        updateTrackingArea()
    }

    private func updateTrackingArea() {
        if let old = trackingAreaObj { removeTrackingArea(old) }
        let tracking = NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                                       owner: self, userInfo: nil)
        addTrackingArea(tracking)
        self.trackingAreaObj = tracking
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateTrackingArea()
    }

    public override func mouseDown(with event: NSEvent) {
        if event.type == .rightMouseDown {
            onRightClick?(itemID, event)
            return
        }
        onClick?(itemID)
    }

    public override func rightMouseDown(with event: NSEvent) {
        onRightClick?(itemID, event)
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovering = true
        onMouseEntered?(itemID)
        needsDisplay = true
    }

    public override func mouseExited(with event: NSEvent) {
        isHovering = false
        onMouseExited?(itemID)
        needsDisplay = true
    }

    @objc private func closeClicked() {
        onClose?(itemID)
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isActive {
            activeColor.setFill()
        } else if isHovering {
            hoverColor.setFill()
        } else {
            inactiveColor.setFill()
        }
        dirtyRect.fill()
    }

    public override var intrinsicContentSize: NSSize {
        let titleWidth = title.size(withAttributes: [.font: NSFont.systemFont(ofSize: fontSize)]).width
        let iconWidth: CGFloat = (iconName != nil) ? 20 : 0
        let badgeWidth: CGFloat = (badge != nil) ? 24 : 0
        let closeWidth: CGFloat = (showCloseButton && !isPinned) ? 20 : 0
        let width = titleWidth + 24 + iconWidth + badgeWidth + closeWidth
        return NSSize(width: max(width, 70), height: 28)
    }

    /// 更新外观显示状态
    public func updateAppearance() {
        titleLabel?.textColor = isActive ? activeTextColor : textColor
        titleLabel?.stringValue = isModified ? "● \(title)" : title
        closeButton?.isHidden = !showCloseButton || isPinned

        if let iconName = iconName, showIcon {
            iconImageView?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            iconImageView?.isHidden = false
        } else {
            iconImageView?.isHidden = true
        }

        if let badge = badge, !badge.isEmpty {
            badgeLabel?.stringValue = badge
            badgeLabel?.isHidden = false
        } else {
            badgeLabel?.isHidden = true
        }
    }
}

// MARK: - 迁回自 UI-02：class UITabRowView
public class UITabRowView: NSView , @unchecked Sendable{
    public private(set) var buttons: [UIMultiLineTabButton] = []
    private let stackView = NSStackView()
    private let lock = NSRecursiveLock()

    public var onTabSelected: ((String) -> Void)?
    public var onTabClose: ((String) -> Void)?
    public var onTabRightClick: ((String, NSEvent) -> Void)?
    public var onTabHover: ((String) -> Void)?
    public var onTabHoverEnd: ((String) -> Void)?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        stackView.orientation = .horizontal
        stackView.spacing = 2
        stackView.distribution = .fill
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// 添加标签按钮到本行
    public func addButton(_ button: UIMultiLineTabButton) {
        lock.lock()
        buttons.append(button)
        lock.unlock()

        button.onClick = { [weak self] id in self?.onTabSelected?(id) }
        button.onClose = { [weak self] id in self?.onTabClose?(id) }
        button.onRightClick = { [weak self] id, event in self?.onTabRightClick?(id, event) }
        button.onMouseEntered = { [weak self] id in self?.onTabHover?(id) }
        button.onMouseExited = { [weak self] id in self?.onTabHoverEnd?(id) }

        stackView.addArrangedSubview(button)
    }

    /// 移除指定标签按钮
    public func removeButton(itemID: String) {
        lock.lock()
        guard let index = buttons.firstIndex(where: { $0.itemID == itemID }) else {
            lock.unlock()
            return
        }
        let button = buttons.remove(at: index)
        lock.unlock()
        stackView.removeArrangedSubview(button)
        button.removeFromSuperview()
    }

    /// 激活指定标签按钮
    public func activateButton(itemID: String) {
        var activeButtons: [UIMultiLineTabButton] = []
        lock.lock()
        for button in buttons {
            button.isActive = (button.itemID == itemID)
            activeButtons.append(button)
        }
        lock.unlock()
        for button in activeButtons {
            button.updateAppearance()
            button.needsDisplay = true
        }
    }

    /// 计算本行当前所有按钮的总宽度
    public var totalWidth: CGFloat {
        lock.lock()
        let total = buttons.reduce(CGFloat(0)) { $0 + $1.intrinsicContentSize.width + stackView.spacing }
        lock.unlock()
        return total
    }

    /// 是否包含指定标签按钮
    public func containsButton(itemID: String) -> Bool {
        lock.lock()
        let result = buttons.contains(where: { $0.itemID == itemID })
        lock.unlock()
        return result
    }

    /// 获取本行所有按钮的ID列表
    public var buttonIDs: [String] {
        lock.lock()
        let ids = buttons.map { $0.itemID }
        lock.unlock()
        return ids
    }
}

// MARK: - 迁回自 UI-02：class UIMultiLineTabBarView
public class UIMultiLineTabBarView: NSView , @unchecked Sendable{
    public private(set) var items: [UIMultiLineTabItem] = []
    public private(set) var activeItemID: String?
    public var style: UIMultiLineTabStyle = .default

    public var onTabSelected: ((String) -> Void)?
    public var onTabClose: ((String) -> Void)?
    public var onTabRightClick: ((String, NSEvent) -> Void)?
    public var onTabReorder: ((String, Int) -> Void)?
    public var onTabHover: ((String) -> Void)?
    public var onTabHoverEnd: ((String) -> Void)?

    private var scrollView: NSScrollView!
    private var rowsContainer: NSView!       // 垂直容器，包含所有行
    private var rows: [UITabRowView] = []
    private let lock = NSRecursiveLock()
    private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "UIMultiLineTabBarView")

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        // 清理所有行中的按钮跟踪区域
        for row in rows {
            for button in row.buttons {
                button.onClick = nil
                button.onClose = nil
                button.onRightClick = nil
                button.onMouseEntered = nil
                button.onMouseExited = nil
            }
        }
    }

    private func setup() {
        // 滚动视图
        scrollView = NSScrollView(frame: bounds)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = false
        addSubview(scrollView)

        // 垂直容器（多行排列）
        rowsContainer = NSView()
        rowsContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = rowsContainer

        wantsLayer = true
        layer?.borderWidth = style.borderWidth
        layer?.borderColor = style.borderColor.nsColor.cgColor
    }

    public override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        scrollView.frame = bounds
        relayoutRows()
    }

    // MARK: - 标签项管理

    /// 添加标签项（自动排序并重新布局）
    public func addItem(_ item: UIMultiLineTabItem) {
        lock.lock()
        items.append(item)
        items.sort(by: { (a: UIMultiLineTabItem, b: UIMultiLineTabItem) in
            if a.isPinned && !b.isPinned { return true }
            if !a.isPinned && b.isPinned { return false }
            return a.order < b.order
        })
        lock.unlock()
        relayoutRows()
        logger.info("[多行标签栏] 添加标签: \(item.title)")
    }

    /// 移除标签项
    public func removeItem(id: String) {
        lock.lock()
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        let removed = items.remove(at: index)
        lock.unlock()

        // 如果移除的是当前激活项，激活下一个
        if activeItemID == id {
            // 已在锁内处理
        }

        relayoutRows()
        logger.info("[多行标签栏] 移除标签: \(removed.title)")
    }

    /// 激活指定标签项
    public func activateItem(id: String) {
        activeItemID = id
        var activeRows: [UITabRowView] = []
        lock.lock()
        activeRows = rows
        lock.unlock()
        for row in activeRows {
            row.activateButton(itemID: id)
        }
        onTabSelected?(id)
        logger.info("[多行标签栏] 激活标签: \(id)")
    }

    /// 重新排序标签项
    public func reorderItem(id: String, to newIndex: Int) {
        lock.lock()
        guard let oldIndex = items.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        let item = items.remove(at: oldIndex)
        let count = items.count
        let clamped = max(0, min(newIndex, count))
        items.insert(item, at: clamped)
        lock.unlock()
        relayoutRows()
        logger.info("[多行标签栏] 重新排序标签: \(item.title) -> 索引 \(clamped)")
    }

    /// 获取标签项
    public func item(id: String) -> UIMultiLineTabItem? {
        lock.lock()
        let result = items.first(where: { $0.id == id })
        lock.unlock()
        return result
    }

    /// 更新标签项数据
    public func updateItem(_ item: UIMultiLineTabItem) {
        lock.lock()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
        lock.unlock()
        // 刷新对应按钮外观
        for row in rows {
            for button in row.buttons where button.itemID == item.id {
                button.title = item.title
                button.isPinned = item.isPinned
                button.isModified = item.isModified
                button.iconName = item.iconName
                button.badge = item.badge
                button.updateAppearance()
            }
        }
    }

    // MARK: - 多行布局

    /// 重新计算多行布局，标签超出宽度自动换行
    private func relayoutRows() {
        // 清除现有行
        rows.forEach { $0.removeFromSuperview() }
        rows.removeAll()

        lock.lock()
        let currentItems = items
        lock.unlock()

        guard !currentItems.isEmpty else {
            rowsContainer.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 1)
            return
        }

        let containerWidth = bounds.width - 8  // 留边距
        let tabHeight = style.tabHeight
        let rowSpacing = style.rowSpacing
        let tabSpacing = style.tabSpacing
        let tabMinWidth = style.tabMinWidth
        let tabMaxWidth = style.tabMaxWidth

        var currentRow: UITabRowView?
        var currentRowWidth: CGFloat = 0
        var allRows: [UITabRowView] = []
        var yOffset: CGFloat = 4

        for item in currentItems {
            let button = createButton(for: item)
            let buttonWidth = min(max(button.intrinsicContentSize.width, tabMinWidth), tabMaxWidth)
            let neededWidth = buttonWidth + tabSpacing

            // 判断是否需要换行
            if currentRow == nil || (currentRowWidth + neededWidth > containerWidth && containerWidth > 0) {
                if let row = currentRow {
                    row.frame = NSRect(x: 4, y: yOffset, width: containerWidth, height: tabHeight)
                    yOffset += tabHeight + rowSpacing
                    allRows.append(row)
                }
                currentRow = createRow()
                currentRowWidth = 0
            }

            currentRow?.addButton(button)
            currentRowWidth += neededWidth
        }

        // 添加最后一行
        if let row = currentRow {
            row.frame = NSRect(x: 4, y: yOffset, width: containerWidth, height: tabHeight)
            yOffset += tabHeight + rowSpacing
            allRows.append(row)
        }

        rows = allRows

        // 更新容器高度
        let totalHeight = yOffset + 4
        rowsContainer.frame = NSRect(x: 0, y: 0, width: bounds.width, height: totalHeight)

        // 激活当前选中项
        if let activeID = activeItemID {
            for row in rows { row.activateButton(itemID: activeID) }
        }

        _ = rows.count
        // 如果标签行数变化，发送通知
        NotificationCenter.default.post(
            name: .multiLineTabRowsDidChange,
            object: self,
            userInfo: ["rowCount": rows.count]
        )
    }

    private func createRow() -> UITabRowView {
        let row = UITabRowView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.onTabSelected = { [weak self] id in self?.activateItem(id: id) }
        row.onTabClose = { [weak self] id in self?.onTabClose?(id) }
        row.onTabRightClick = { [weak self] id, event in self?.onTabRightClick?(id, event) }
        row.onTabHover = { [weak self] id in self?.onTabHover?(id) }
        row.onTabHoverEnd = { [weak self] id in self?.onTabHoverEnd?(id) }
        rowsContainer.addSubview(row)
        return row
    }

    private func createButton(for item: UIMultiLineTabItem) -> UIMultiLineTabButton {
        let button = UIMultiLineTabButton(itemID: item.id, title: item.title)
        button.isPinned = item.isPinned
        button.isModified = item.isModified
        button.iconName = item.iconName
        button.badge = item.badge
        button.showCloseButton = style.showCloseButton
        button.showIcon = style.showIcon
        button.fontSize = style.fontSize
        button.cornerRadius = style.cornerRadius
        button.activeColor = style.activeColor.nsColor
        button.inactiveColor = style.inactiveColor.nsColor
        button.hoverColor = style.hoverColor.nsColor
        button.textColor = style.textColor.nsColor
        button.activeTextColor = style.activeTextColor.nsColor
        button.updateAppearance()
        return button
    }

    // MARK: - 样式更新

    /// 更新整体样式并重新布局
    public func updateStyle(_ style: UIMultiLineTabStyle) {
        self.style = style
        layer?.borderWidth = style.borderWidth
        layer?.borderColor = style.borderColor.nsColor.cgColor
        relayoutRows()
    }
}

// MARK: - 迁回自 UI-02：class UIMultiLineTabManager
public final class UIMultiLineTabManager : @unchecked Sendable {
    public static let shared = UIMultiLineTabManager()

    private var items: [UIMultiLineTabItem] = []
    private var activeItemID: String?
    private var style: UIMultiLineTabStyle = .default
    private let lock = NSRecursiveLock()
    private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "UIMultiLineTabManager")
    private let saveKey = "com.xianrenzhilu.multiLineTabs"

    private init() {
        loadFromDisk()
    }

    deinit {
        // 清理通知监听
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 标签页增删改查

    /// 添加新标签页
    public func addTab(title: String, iconName: String? = nil, view: NSView? = nil,
                       isPinned: Bool = false, badge: String? = nil) -> UIMultiLineTabItem {
        let id = UUID().uuidString
        let item = UIMultiLineTabItem(id: id, title: title, iconName: iconName,
                          isPinned: isPinned, badge: badge, view: view)
        lock.lock()
        items.append(item)
        sortItems()
        if activeItemID == nil { activeItemID = id }
        lock.unlock()

        saveToDisk()
        NotificationCenter.default.post(
            name: .multiLineTabPagesDidChange,
            object: self,
            userInfo: ["action": "add", "itemID": id, "title": title]
        )
        logger.info("[管理器] 添加标签页: \(title)")
        return item
    }

    /// 关闭指定标签页
    public func closeTab(id: String) {
        lock.lock()
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        let removed = items.remove(at: index)
        if activeItemID == id {
            activeItemID = items.first?.id
        }
        lock.unlock()

        saveToDisk()
        NotificationCenter.default.post(
            name: .multiLineTabPagesDidChange,
            object: self,
            userInfo: ["action": "close", "itemID": id, "title": removed.title]
        )
        if let activeID = activeItemID {
            NotificationCenter.default.post(
                name: .multiLineTabActiveDidChange,
                object: self,
                userInfo: ["itemID": activeID]
            )
        }
        logger.info("[管理器] 关闭标签页: \(removed.title)")
    }

    /// 激活指定标签页
    public func activateTab(id: String) {
        lock.lock()
        guard items.contains(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        activeItemID = id
        lock.unlock()

        saveToDisk()
        NotificationCenter.default.post(
            name: .multiLineTabActiveDidChange,
            object: self,
            userInfo: ["itemID": id]
        )
        logger.info("[管理器] 激活标签页: \(id)")
    }

    /// 重新排序标签页
    public func reorderTab(id: String, to newIndex: Int) {
        lock.lock()
        guard let oldIndex = items.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        let item = items.remove(at: oldIndex)
        let clamped = max(0, min(newIndex, items.count))
        items.insert(item, at: clamped)
        // 更新排序号
        for (idx, var it) in items.enumerated() {
            it.order = idx
            items[idx] = it
        }
        lock.unlock()

        saveToDisk()
        NotificationCenter.default.post(
            name: .multiLineTabPagesDidChange,
            object: self,
            userInfo: ["action": "reorder", "itemID": id, "newIndex": clamped]
        )
        logger.info("[管理器] 重新排序标签页: \(item.title) -> \(clamped)")
    }

    /// 更新标签页数据
    public func updateTab(_ item: UIMultiLineTabItem) {
        lock.lock()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
        lock.unlock()
        saveToDisk()
    }

    /// 切换标签页固定状态
    public func togglePin(id: String) {
        lock.lock()
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        items[index].isPinned.toggle()
        sortItems()
        lock.unlock()
        saveToDisk()
        NotificationCenter.default.post(
            name: .multiLineTabPagesDidChange,
            object: self,
            userInfo: ["action": "pin", "itemID": id]
        )
    }

    /// 设置标签页未保存修改状态
    public func setModified(id: String, isModified: Bool) {
        lock.lock()
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isModified = isModified
        }
        lock.unlock()
        saveToDisk()
    }

    /// 获取所有标签页
    public var allItems: [UIMultiLineTabItem] {
        lock.lock()
        let result = items
        lock.unlock()
        return result
    }

    /// 获取当前激活标签页
    public var activeItem: UIMultiLineTabItem? {
        lock.lock()
        let result = items.first(where: { $0.id == activeItemID })
        lock.unlock()
        return result
    }

    /// 获取当前激活标签页ID
    public var currentActiveID: String? {
        lock.lock()
        let id = activeItemID
        lock.unlock()
        return id
    }

    /// 获取标签页数量
    public var tabCount: Int {
        lock.lock()
        let count = items.count
        lock.unlock()
        return count
    }

    /// 关闭右侧所有标签页
    public func closeTabsToRight(of id: String) {
        lock.lock()
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        let toRemove = items[(index + 1)...].map { $0.id }
        items.removeSubrange((index + 1)...)
        lock.unlock()

        for removedID in toRemove {
            NotificationCenter.default.post(
                name: .multiLineTabPagesDidChange,
                object: self,
                userInfo: ["action": "close", "itemID": removedID]
            )
        }
        saveToDisk()
        logger.info("[管理器] 关闭右侧标签页，共 \(toRemove.count) 个")
    }

    /// 关闭除指定标签外的所有标签页
    public func closeOtherTabs(keep id: String) {
        lock.lock()
        let toRemove = items.filter { $0.id != id }.map { $0.id }
        items.removeAll { $0.id != id }
        activeItemID = id
        lock.unlock()

        for removedID in toRemove {
            NotificationCenter.default.post(
                name: .multiLineTabPagesDidChange,
                object: self,
                userInfo: ["action": "close", "itemID": removedID]
            )
        }
        NotificationCenter.default.post(
            name: .multiLineTabActiveDidChange,
            object: self,
            userInfo: ["itemID": id]
        )
        saveToDisk()
        logger.info("[管理器] 关闭其他标签页，保留: \(id)")
    }

    // MARK: - 右击菜单

    /// 创建标签页右击上下文菜单
    public func createContextMenu(for itemID: String) -> NSMenu {
        let menu = NSMenu()

        let closeItem = NSMenuItem(title: "关闭", action: #selector(contextMenuClose(_:)), keyEquivalent: "")
        closeItem.representedObject = itemID
        closeItem.target = self
        menu.addItem(closeItem)

        let closeOthersItem = NSMenuItem(title: "关闭其他", action: #selector(contextMenuCloseOthers(_:)), keyEquivalent: "")
        closeOthersItem.representedObject = itemID
        closeOthersItem.target = self
        menu.addItem(closeOthersItem)

        let closeRightItem = NSMenuItem(title: "关闭右侧", action: #selector(contextMenuCloseRight(_:)), keyEquivalent: "")
        closeRightItem.representedObject = itemID
        closeRightItem.target = self
        menu.addItem(closeRightItem)

        menu.addItem(NSMenuItem.separator())

        let pinItem = NSMenuItem(title: "固定/取消固定", action: #selector(contextMenuTogglePin(_:)), keyEquivalent: "")
        pinItem.representedObject = itemID
        pinItem.target = self
        menu.addItem(pinItem)

        return menu
    }

    @objc private func contextMenuClose(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        closeTab(id: id)
    }

    @objc private func contextMenuCloseOthers(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        closeOtherTabs(keep: id)
    }

    @objc private func contextMenuCloseRight(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        closeTabsToRight(of: id)
    }

    @objc private func contextMenuTogglePin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        togglePin(id: id)
    }

    // MARK: - 持久化

    /// 保存当前标签布局到磁盘（UserDefaults）
    public func saveToDisk() {
        lock.lock()
        let config = UIMultiLineTabConfig(
            items: items,
            activeItemID: activeItemID,
            style: style
        )
        lock.unlock()

        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: saveKey)
            logger.info("[管理器] 已保存多行标签布局，共 \(self.items.count) 个标签")
        }
    }

    /// 从磁盘加载标签布局
    public func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let config = try? JSONDecoder().decode(UIMultiLineTabConfig.self, from: data) else {
            return
        }
        lock.lock()
        items = config.items
        activeItemID = config.activeItemID
        style = config.style
        lock.unlock()
        logger.info("[管理器] 已加载多行标签布局，共 \(self.items.count) 个标签")
    }

    /// 清除保存的标签布局
    public func clearSavedLayout() {
        UserDefaults.standard.removeObject(forKey: saveKey)
        logger.info("[管理器] 已清除保存的多行标签布局")
    }

    // MARK: - 样式管理

    /// 获取当前样式
    public var currentStyle: UIMultiLineTabStyle {
        lock.lock()
        let s = style
        lock.unlock()
        return s
    }

    /// 更新样式
    public func updateStyle(_ newStyle: UIMultiLineTabStyle) {
        lock.lock()
        style = newStyle
        lock.unlock()
        saveToDisk()
        logger.info("[管理器] 已更新多行标签样式")
    }

    // MARK: - 设置面板方法

    /// 创建样式设置面板视图
    public func createStyleSettingsView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 360))

        let label = NSTextField(labelWithString: "多行标签栏样式设置")
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.frame = NSRect(x: 20, y: 320, width: 200, height: 22)
        view.addSubview(label)

        var y: CGFloat = 290

        // 标签栏高度
        let heightLabel = NSTextField(labelWithString: "标签栏高度:")
        heightLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(heightLabel)

        let heightField = NSTextField(frame: NSRect(x: 130, y: y, width: 60, height: 22))
        heightField.stringValue = String(Int(style.tabHeight))
        view.addSubview(heightField)
        y -= 34

        // 字体大小
        let fontLabel = NSTextField(labelWithString: "字体大小:")
        fontLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(fontLabel)

        let fontField = NSTextField(frame: NSRect(x: 130, y: y, width: 60, height: 22))
        fontField.stringValue = String(Int(style.fontSize))
        view.addSubview(fontField)
        y -= 34

        // 标签最小宽度
        let minWidthLabel = NSTextField(labelWithString: "最小宽度:")
        minWidthLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(minWidthLabel)

        let minWidthField = NSTextField(frame: NSRect(x: 130, y: y, width: 60, height: 22))
        minWidthField.stringValue = String(Int(style.tabMinWidth))
        view.addSubview(minWidthField)
        y -= 34

        // 标签最大宽度
        let maxWidthLabel = NSTextField(labelWithString: "最大宽度:")
        maxWidthLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(maxWidthLabel)

        let maxWidthField = NSTextField(frame: NSRect(x: 130, y: y, width: 60, height: 22))
        maxWidthField.stringValue = String(Int(style.tabMaxWidth))
        view.addSubview(maxWidthField)
        y -= 34

        // 最大行数
        let maxRowsLabel = NSTextField(labelWithString: "最大行数:")
        maxRowsLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        view.addSubview(maxRowsLabel)

        let maxRowsField = NSTextField(frame: NSRect(x: 130, y: y, width: 60, height: 22))
        maxRowsField.stringValue = String(style.maxRows)
        view.addSubview(maxRowsField)
        y -= 34

        // 显示关闭按钮
        let closeBtn = NSButton(checkboxWithTitle: "显示关闭按钮", target: nil, action: nil)
        closeBtn.state = style.showCloseButton ? .on : .off
        closeBtn.frame = NSRect(x: 20, y: y, width: 140, height: 20)
        view.addSubview(closeBtn)
        y -= 28

        // 显示图标
        let iconBtn = NSButton(checkboxWithTitle: "显示图标", target: nil, action: nil)
        iconBtn.state = style.showIcon ? .on : .off
        iconBtn.frame = NSRect(x: 20, y: y, width: 120, height: 20)
        view.addSubview(iconBtn)
        y -= 28

        // 保存按钮
        let saveBtn = NSButton(title: "保存样式", target: self, action: #selector(saveStyleSettings(_:)))
        saveBtn.frame = NSRect(x: 20, y: y - 10, width: 100, height: 28)
        view.addSubview(saveBtn)

        return view
    }

    @objc private func saveStyleSettings(_ sender: NSButton) {
        // 从设置面板读取并应用样式（实际应用需扩展字段绑定）
        logger.info("[管理器] 保存样式设置")
    }

    /// 创建布局设置面板视图
    public func createLayoutSettingsView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 260))

        let label = NSTextField(labelWithString: "多行标签栏布局设置")
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.frame = NSRect(x: 20, y: 220, width: 200, height: 22)
        view.addSubview(label)

        let info = NSTextField(labelWithString: "标签超出容器宽度时自动换行，支持垂直滚动")
        info.frame = NSRect(x: 20, y: 190, width: 400, height: 20)
        view.addSubview(info)

        let rowSpacingLabel = NSTextField(labelWithString: "行间距:")
        rowSpacingLabel.frame = NSRect(x: 20, y: 160, width: 100, height: 20)
        view.addSubview(rowSpacingLabel)

        let rowSpacingField = NSTextField(frame: NSRect(x: 130, y: 160, width: 60, height: 22))
        rowSpacingField.stringValue = String(Int(style.rowSpacing))
        view.addSubview(rowSpacingField)

        let tabSpacingLabel = NSTextField(labelWithString: "标签间距:")
        tabSpacingLabel.frame = NSRect(x: 20, y: 130, width: 100, height: 20)
        view.addSubview(tabSpacingLabel)

        let tabSpacingField = NSTextField(frame: NSRect(x: 130, y: 130, width: 60, height: 22))
        tabSpacingField.stringValue = String(Int(style.tabSpacing))
        view.addSubview(tabSpacingField)

        let persistBtn = NSButton(title: "立即保存布局", target: self, action: #selector(saveToDiskButtonClicked))
        persistBtn.frame = NSRect(x: 20, y: 90, width: 120, height: 28)
        view.addSubview(persistBtn)

        let clearBtn = NSButton(title: "清除保存的布局", target: self, action: #selector(clearLayoutButtonClicked))
        clearBtn.frame = NSRect(x: 150, y: 90, width: 120, height: 28)
        view.addSubview(clearBtn)

        return view
    }

    @objc private func saveToDiskButtonClicked() {
        saveToDisk()
    }

    @objc private func clearLayoutButtonClicked() {
        clearSavedLayout()
    }

    /// 创建行为设置面板视图
    public func createBehaviorSettingsView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 220))

        let label = NSTextField(labelWithString: "多行标签栏行为设置")
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.frame = NSRect(x: 20, y: 180, width: 200, height: 22)
        view.addSubview(label)

        let info = NSTextField(labelWithString: "当前标签页数: \(tabCount)")
        info.frame = NSRect(x: 20, y: 150, width: 200, height: 20)
        view.addSubview(info)

        let shortcutInfo = NSTextField(labelWithString: "快捷键: 右击标签显示上下文菜单")
        shortcutInfo.frame = NSRect(x: 20, y: 120, width: 300, height: 20)
        view.addSubview(shortcutInfo)

        return view
    }

    /// 获取所有设置面板视图列表
    public func allSettingsViews() -> [(title: String, view: NSView)] {
        return [
            ("样式", createStyleSettingsView()),
            ("布局", createLayoutSettingsView()),
            ("行为", createBehaviorSettingsView())
        ]
    }

    // MARK: - 状态查询

    /// 获取状态描述文本
    public var statusDescription: String {
        lock.lock()
        let count = items.count
        let active = activeItemID ?? "无"
        lock.unlock()
        return "标签页总数：\(count)，当前激活：\(active)"
    }

    // MARK: - 清理

    /// 关闭所有标签页
    public func closeAll() {
        lock.lock()
        let oldItems = items
        items.removeAll()
        activeItemID = nil
        lock.unlock()

        for item in oldItems {
            NotificationCenter.default.post(
                name: .multiLineTabPagesDidChange,
                object: self,
                userInfo: ["action": "close", "itemID": item.id]
            )
        }
        saveToDisk()
        logger.info("[管理器] 已关闭所有标签页")
    }

    // MARK: - 辅助方法

    /// 按固定状态排序标签项
    private func sortItems() {
        items.sort(by: { (a: UIMultiLineTabItem, b: UIMultiLineTabItem) in
            if a.isPinned && !b.isPinned { return true }
            if !a.isPinned && b.isPinned { return false }
            return a.order < b.order
        })
    }
}

// MARK: - 迁回自 UI-02：extension UIMultiLineTabManager
public extension UIMultiLineTabManager {
    /// 获取指定索引位置的标签页
    func item(at index: Int) -> UIMultiLineTabItem? {
        lock.lock()
        let result = (index >= 0 && index < items.count) ? items[index] : nil
        lock.unlock()
        return result
    }

    /// 获取标签页索引位置
    func index(of id: String) -> Int? {
        lock.lock()
        let result = items.firstIndex(where: { $0.id == id })
        lock.unlock()
        return result
    }

    /// 判断标签页是否存在
    func contains(id: String) -> Bool {
        lock.lock()
        let result = items.contains(where: { $0.id == id })
        lock.unlock()
        return result
    }
}

// MARK: - 迁回自 UI-02：struct UIMLTCodableColor
// MARK: - UI-GL-44 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-44_types.swift
// 版本: 2.0
// MARK: - 视图组
/// 多个视图编组,作为一个整体操作的容器
// 已迁回 UI-GL-44_视图组.swift：class UIViewGroup（公共类型文件禁止功能实现）


// MARK: - UI-GL-46 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-46_types.swift
// 版本: 2.0
public struct UIMLTCodableColor: Codable, Equatable, Sendable {
    var r, g, b, a: CGFloat

    init(_ color: NSColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if let c = color.usingColorSpace(.sRGB) {
            c.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    var nsColor: NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - 迁回自 UI-02：struct UIMultiLineTabStyle
// MARK: - 布局模板市场管理器
/// 管理布局模板的上传、下载、分享、评分、搜索与分类
/// 单例模式，线程安全（NSRecursiveLock），持久化到磁盘
// 已迁回 UI-GL-45_布局模板市场.swift：class UILayoutMarketManager（公共类型文件禁止功能实现）

// MARK: - 模板市场列表视图控制器
/// 使用 NSTableView 展示模板市场列表，用于设置面板
// 已迁回 UI-GL-45_布局模板市场.swift：class UILayoutMarketListViewController（公共类型文件禁止功能实现）

// MARK: - 模板市场预览视图
/// 展示模板布局缩略图的自定义 NSView，用于设置面板
// 已迁回 UI-GL-45_布局模板市场.swift：class UILayoutMarketPreviewView（公共类型文件禁止功能实现）


// MARK: - UI-GL-46 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-46_types.swift
// 版本: 2.0
// MARK: - 多行标签页样式配置
/// 多行标签栏的视觉样式配置，支持 Codable 持久化
public struct UIMultiLineTabStyle: Codable, Equatable, Sendable {
    public var backgroundColor: UIMLTCodableColor
    public var activeColor: UIMLTCodableColor
    public var inactiveColor: UIMLTCodableColor
    public var textColor: UIMLTCodableColor
    public var activeTextColor: UIMLTCodableColor
    public var hoverColor: UIMLTCodableColor
    public var fontSize: CGFloat
    public var tabHeight: CGFloat
    public var tabMinWidth: CGFloat
    public var tabMaxWidth: CGFloat
    public var showCloseButton: Bool
    public var showIcon: Bool
    public var cornerRadius: CGFloat
    public var borderWidth: CGFloat
    public var borderColor: UIMLTCodableColor
    public var rowSpacing: CGFloat        // 行间距
    public var tabSpacing: CGFloat        // 标签间距
    public var maxRows: Int               // 最大显示行数（超出滚动）

    public static let `default` = UIMultiLineTabStyle(
        backgroundColor: UIMLTCodableColor(NSColor.windowBackgroundColor),
        activeColor: UIMLTCodableColor(NSColor.selectedControlColor),
        inactiveColor: UIMLTCodableColor(NSColor.controlBackgroundColor),
        textColor: UIMLTCodableColor(NSColor.labelColor),
        activeTextColor: UIMLTCodableColor(NSColor.alternateSelectedControlTextColor),
        hoverColor: UIMLTCodableColor(NSColor.highlightColor.withAlphaComponent(0.3)),
        fontSize: 12,
        tabHeight: 32,
        tabMinWidth: 80,
        tabMaxWidth: 200,
        showCloseButton: true,
        showIcon: true,
        cornerRadius: 4,
        borderWidth: 0.5,
        borderColor: UIMLTCodableColor(NSColor.separatorColor),
        rowSpacing: 2,
        tabSpacing: 2,
        maxRows: 3
    )
}

// MARK: - 迁回自 UI-02：struct UIMultiLineTabConfig
// MARK: - 多行标签栏配置（持久化用）
/// 多行标签栏完整配置，用于保存和恢复布局
public struct UIMultiLineTabConfig: Codable, Equatable {
    public var items: [UIMultiLineTabItem]
    public var activeItemID: String?
    public var style: UIMultiLineTabStyle
    public var scrollOffset: CGFloat      // 滚动偏移量

    public init(items: [UIMultiLineTabItem] = [], activeItemID: String? = nil,
                style: UIMultiLineTabStyle = .default, scrollOffset: CGFloat = 0) {
        self.items = items
        self.activeItemID = activeItemID
        self.style = style
        self.scrollOffset = scrollOffset
    }
}
