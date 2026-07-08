// 功能29: 布局模板系统
// 对应: 用户可保存/加载完整的布局方案，一键切换不同场景（K线分析、量化回测、盘口监控等）
// 优先级: P2

import AppKit
import Foundation
import os.log

// MARK: - 通知名称
/// 布局模板相关通知
extension Notification.Name {
    /// 模板已保存
    static let layoutTemplateSaved = Notification.Name("com.xianrenzhilu.layoutTemplateSaved")
    /// 模板已加载
    static let layoutTemplateLoaded = Notification.Name("com.xianrenzhilu.layoutTemplateLoaded")
    /// 模板已删除
    static let layoutTemplateDeleted = Notification.Name("com.xianrenzhilu.layoutTemplateDeleted")
    /// 模板已重命名
    static let layoutTemplateRenamed = Notification.Name("com.xianrenzhilu.layoutTemplateRenamed")
    /// 模板已导出
    static let layoutTemplateExported = Notification.Name("com.xianrenzhilu.layoutTemplateExported")
    /// 模板已导入
    static let layoutTemplateImported = Notification.Name("com.xianrenzhilu.layoutTemplateImported")
    /// 内置模板已初始化
    static let layoutTemplateBuiltInInitialized = Notification.Name("com.xianrenzhilu.layoutTemplateBuiltInInitialized")
}

// MARK: - 布局模板管理器
/// 管理布局模板的保存、加载、导入导出、预览与设置面板
/// 单例模式，线程安全（NSRecursiveLock），持久化到磁盘
// 类型 UILayoutTemplateManager 已迁移到 UI-02_公共类型定义.swift

// MARK: - 模板列表视图控制器
/// 使用 NSTableView 展示模板列表，纯 AppKit 实现，用于设置面板
// 类型 UILayoutTemplateListViewController 已迁移到 UI-02_公共类型定义.swift

// MARK: - NSTableViewDataSource
extension UILayoutTemplateListViewController {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return templates.count
    }
}

// MARK: - NSTableViewDelegate
extension UILayoutTemplateListViewController {
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        let template = templates[row]

        let cellIdentifier = NSUserInterfaceItemIdentifier(column.identifier.rawValue + "Cell")
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView

        if cellView == nil {
            cellView = NSTableCellView(frame: NSRect.zero)
            cellView?.identifier = cellIdentifier

            let textField = NSTextField(frame: NSRect(x: 4, y: 2, width: column.width - 8, height: 18))
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.font = NSFont.systemFont(ofSize: 12)
            textField.lineBreakMode = .byTruncatingTail
            cellView?.textField = textField
            cellView?.addSubview(textField)
        }

        switch column.identifier.rawValue {
        case "name":
            cellView?.textField?.stringValue = template.name
            cellView?.textField?.textColor = .labelColor
        case "description":
            cellView?.textField?.stringValue = template.desc
            cellView?.textField?.textColor = .secondaryLabelColor
        case "tags":
            cellView?.textField?.stringValue = template.tags.joined(separator: ", ")
            cellView?.textField?.textColor = .secondaryLabelColor
        case "type":
            cellView?.textField?.stringValue = template.isBuiltIn ? "内置" : "自定义"
            cellView?.textField?.textColor = template.isBuiltIn ? .systemBlue : .labelColor
        default:
            cellView?.textField?.stringValue = ""
        }

        return cellView
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 && row < templates.count else { return }
        onTemplateSelected?(templates[row])
    }
}

// MARK: - 模板预览视图
/// 展示模板布局示意图的自定义 NSView，用于设置面板中的缩略图展示
// 类型 UILayoutTemplatePreviewView 已迁移到 UI-02_公共类型定义.swift


// MARK: - 测试代码
/// 功能29：布局模板系统 — 单元测试
func test_layoutTemplate() {
    let manager = UILayoutTemplateManager.shared

    print("\n🧪 测试1: 内置模板")
    let builtIn = manager.builtInTemplates
    guard builtIn.count >= 5 else {
        fatalError("❌ 测试1失败: 应有至少5个内置模板，实际有\(builtIn.count)个")
    }
    print("✅ 测试1通过: 内置模板共\(builtIn.count)个")

    print("\n🧪 测试2: 保存模板")
    let saved = manager.saveCurrentAsTemplate(name: "测试模板", description: "用于测试")
    guard saved else {
        fatalError("❌ 测试2失败: 保存应成功")
    }
    print("✅ 测试2通过: 模板保存成功")

    print("\n🧪 测试3: 模板查询")
    let t = manager.template(named: "测试模板")
    guard t?.name == "测试模板" else {
        fatalError("❌ 测试3失败: 查询应找到模板")
    }
    print("✅ 测试3通过: 模板查询正确")

    print("\n🧪 测试4: 按标签搜索")
    let tagged = manager.templatesWithTag("默认")
    guard !tagged.isEmpty else {
        fatalError("❌ 测试4失败: 应有「默认」标签的模板")
    }
    print("✅ 测试4通过: 标签搜索正常（找到\(tagged.count)个）")

    print("\n🧪 测试5: 重命名")
    let renamed = manager.renameTemplate(oldName: "测试模板", newName: "新名称")
    guard renamed, manager.template(named: "新名称") != nil else {
        fatalError("❌ 测试5失败: 重命名应成功")
    }
    print("✅ 测试5通过: 重命名成功")

    print("\n🧪 测试6: 设置面板数据")
    let data = manager.settingsPanelData()
    guard let templateCount = data["templateCount"] as? Int, templateCount >= 6 else {
        fatalError("❌ 测试6失败: 应有至少6个模板，实际有\(data["templateCount"] ?? 0)个")
    }
    guard let customCount = data["customCount"] as? Int, customCount >= 1 else {
        fatalError("❌ 测试6失败: 应有至少1个自定义模板")
    }
    print("✅ 测试6通过: 设置面板数据正确（共\(templateCount)个模板，其中内置\(data["builtInCount"] ?? 0)个，自定义\(customCount)个）")

    print("\n🧪 测试7: 删除自定义模板")
    let deleted = manager.deleteTemplate(name: "新名称")
    guard deleted else {
        fatalError("❌ 测试7失败: 删除应成功")
    }
    print("✅ 测试7通过: 模板删除成功")

    print("\n🧪 测试8: 导出模板（内置模板）")
    let exportData = manager.exportTemplate(name: "K线分析")
    guard let exportData = exportData, !exportData.isEmpty else {
        fatalError("❌ 测试8失败: 导出应成功返回非空数据")
    }
    print("✅ 测试8通过: 导出成功（\(exportData.count)字节）")

    print("\n🧪 测试9: 导入模板")
    let imported = manager.importTemplate(from: exportData)
    guard imported, manager.template(named: "K线分析") != nil else {
        fatalError("❌ 测试9失败: 导入应成功")
    }
    let importedTemplate = manager.template(named: "K线分析")
    guard importedTemplate?.isBuiltIn == false else {
        fatalError("❌ 测试9失败: 导入的模板应标记为自定义")
    }
    print("✅ 测试9通过: 模板导入成功（标记为自定义）")

    print("\n🧪 测试10: 空名称保存保护")
    let emptySave = manager.saveCurrentAsTemplate(name: "   ", description: "空名称测试")
    guard !emptySave else {
        fatalError("❌ 测试10失败: 空名称保存应返回false")
    }
    print("✅ 测试10通过: 空名称被正确拦截")

    print("\n🧪 测试11: 重命名空名称保护")
    let emptyRename = manager.renameTemplate(oldName: "K线分析", newName: "  ")
    guard !emptyRename else {
        fatalError("❌ 测试11失败: 空名称重命名应返回false")
    }
    print("✅ 测试11通过: 空名称重命名被正确拦截")

    // 清理：删除导入的测试模板
    manager.deleteTemplate(name: "K线分析")

    print("\n=== 全部布局模板测试通过 ✅ ===\n")
}

#if FILEINDEPENDENT
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UILayoutTemplateListViewController
public final class UILayoutTemplateListViewController: NSViewController , @unchecked Sendable{

    var tableView: NSTableView!
    var scrollView: NSScrollView!
    var templates: [UILayoutTemplate] = []

    /// 模板选中回调
    public var onTemplateSelected: ((UILayoutTemplate) -> Void)?
    /// 模板应用回调（双击或按钮触发）
    public var onTemplateApply: ((UILayoutTemplate) -> Void)?
    /// 模板删除回调
    public var onTemplateDelete: ((UILayoutTemplate) -> Void)?

    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        reloadData()

        // 监听模板变化通知，自动刷新列表
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: .layoutTemplateSaved,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: .layoutTemplateDeleted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: .layoutTemplateRenamed,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: .layoutTemplateImported,
            object: nil
        )
    }

    private func setupTableView() {
        scrollView = NSScrollView(frame: view.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        tableView = NSTableView()
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(doubleClicked)

        // 名称列
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "名称"
        nameColumn.width = 150
        tableView.addTableColumn(nameColumn)

        // 描述列
        let descColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("description"))
        descColumn.title = "描述"
        descColumn.width = 250
        tableView.addTableColumn(descColumn)

        // 标签列
        let tagColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tags"))
        tagColumn.title = "标签"
        tagColumn.width = 120
        tableView.addTableColumn(tagColumn)

        // 类型列
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "类型"
        typeColumn.width = 80
        tableView.addTableColumn(typeColumn)

        scrollView.documentView = tableView
        view.addSubview(scrollView)
    }

    @objc public func reloadData() {
        templates = UILayoutTemplateManager.shared.allTemplates
        tableView?.reloadData()
    }

    @objc private func doubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0 && row < templates.count else { return }
        let template = templates[row]
        onTemplateApply?(template)
        _ = UILayoutTemplateManager.shared.applyTemplate(name: template.name)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 迁回自 UI-02：class UILayoutTemplateManager
public final class UILayoutTemplateManager : @unchecked Sendable {
    public static let shared = UILayoutTemplateManager()

    private var lock = NSRecursiveLock()
    private var templates: [String: UILayoutTemplate] = [:]
    private let logger = UILoadingLogManager.shared

    private init() {
        initBuiltIn()
        loadFromDisk()
    }

    /// 内置模板
    private(set) var builtInTemplates: [UILayoutTemplate] = []

    /// 所有模板（内置 + 自定义），自定义模板覆盖同名内置模板
    public var allTemplates: [UILayoutTemplate] {
        lock.lock()
        defer { lock.unlock() }
        let customNames = Set(templates.keys)
        let filteredBuiltIn = builtInTemplates.filter { !customNames.contains($0.name) }
        return filteredBuiltIn + Array(templates.values)
    }

    // MARK: - 内置模板初始化

    /// 初始化内置模板（5个覆盖主流场景）
    private func initBuiltIn() {
        let kline = UILayoutTemplate(
            name: "K线分析",
            description: "专注K线图表分析，支持多周期切换与指标叠加",
            tags: ["K线", "分析", "默认"],
            isBuiltIn: true,
            layout: UIWorkspaceLayout()
        )
        let quant = UILayoutTemplate(
            name: "量化回测",
            description: "量化策略回测界面，包含回测报告与绩效统计",
            tags: ["量化", "回测", "默认"],
            isBuiltIn: true,
            layout: UIWorkspaceLayout()
        )
        let order = UILayoutTemplate(
            name: "盘口监控",
            description: "实时盘口数据监控，支持深度图与逐笔成交",
            tags: ["盘口", "监控", "默认"],
            isBuiltIn: true,
            layout: UIWorkspaceLayout()
        )
        let multiMonitor = UILayoutTemplate(
            name: "多币种监视",
            description: "同时监控多个交易对的价格变动与K线走势",
            tags: ["监控", "多币种", "默认"],
            isBuiltIn: true,
            layout: UIWorkspaceLayout()
        )
        let newsFeed = UILayoutTemplate(
            name: "资讯看板",
            description: "聚合区块链资讯、项目动态与社区热度排行",
            tags: ["资讯", "看板", "默认"],
            isBuiltIn: true,
            layout: UIWorkspaceLayout()
        )
        builtInTemplates = [kline, quant, order, multiMonitor, newsFeed]

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .layoutTemplateBuiltInInitialized, object: nil)
        }
    }

    // MARK: - 持久化路径

    /// 持久化文件路径（用户应用支持目录/模板数据.json）
    private var persistenceURL: URL? {
        guard let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = supportDir.appendingPathComponent("com.xianrenzhilu", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("layoutTemplates.json")
    }

    /// 从磁盘加载自定义模板
    private func loadFromDisk() {
        guard let url = persistenceURL else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        guard let decoded = try? JSONDecoder().decode([String: UILayoutTemplate].self, from: data) else {
            logger.warning("布局模板系统", "持久化数据解析失败，跳过加载")
            return
        }
        lock.lock()
        templates = decoded.filter { !$0.value.isBuiltIn }
        lock.unlock()
    }

    /// 保存自定义模板到磁盘
    private func saveToDisk() {
        guard let url = persistenceURL else { return }
        lock.lock()
        let customTemplates = templates.filter { !$0.value.isBuiltIn }
        lock.unlock()
        guard let data = try? JSONEncoder().encode(customTemplates) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - 模板查询

    /// 获取指定名称的模板（优先查找自定义模板，再查内置模板）
    public func template(named name: String) -> UILayoutTemplate? {
        lock.lock()
        defer { lock.unlock() }
        return templates[name] ?? builtInTemplates.first { $0.name == name }
    }

    /// 搜索模板（名称或描述模糊匹配）
    public func searchTemplates(query: String) -> [UILayoutTemplate] {
        guard !query.isEmpty else { return allTemplates }
        return allTemplates.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.desc.localizedCaseInsensitiveContains(query)
        }
    }

    /// 获取包含指定标签的模板
    public func templatesWithTag(_ tag: String) -> [UILayoutTemplate] {
        guard !tag.isEmpty else { return [] }
        return allTemplates.filter { $0.tags.contains(tag) }
    }

    // MARK: - 模板增删改

    /// 保存模板（覆盖已存在的同名模板，更新时间戳）
    public func saveTemplate(_ template: UILayoutTemplate) {
        var t = template
        t.updatedAt = Date()
        lock.lock()
        templates[template.name] = t
        lock.unlock()
        saveToDisk()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .layoutTemplateSaved, object: nil)
        }
    }

    /// 保存当前布局为模板
    @discardableResult
    public func saveCurrentAsTemplate(name: String, description: String = "") -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            logger.warning("布局模板系统", "保存布局模板失败：模板名称为空")
            return false
        }
        let now = Date()
        let t = UILayoutTemplate(
            name: trimmedName,
            description: description,
            layout: UIWorkspaceLayout(),
            createdAt: now,
            updatedAt: now
        )
        lock.lock()
        templates[trimmedName] = t
        lock.unlock()
        saveToDisk()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .layoutTemplateSaved, object: nil)
        }
        return true
    }

    /// 删除自定义模板（内置模板不可删除）
    @discardableResult
    public func deleteTemplate(name: String) -> Bool {
        lock.lock()
        let removed = templates.removeValue(forKey: name) != nil
        lock.unlock()
        guard removed else {
            logger.warning("布局模板系统", "删除模板失败：未找到模板「\(name)」")
            return false
        }
        saveToDisk()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .layoutTemplateDeleted, object: nil)
        }
        return true
    }

    /// 重命名自定义模板（内置模板不可重命名，新名称不能为空也不能与现有冲突）
    @discardableResult
    public func renameTemplate(oldName: String, newName: String) -> Bool {
        let trimmedNew = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNew.isEmpty else {
            logger.warning("布局模板系统", "重命名失败：新名称不能为空")
            return false
        }
        lock.lock()
        guard var t = templates[oldName] else {
            lock.unlock()
            logger.warning("布局模板系统", "重命名失败：未找到模板「\(oldName)」")
            return false
        }
        // 检查新名称是否已被其他自定义模板占用
        if oldName != trimmedNew && templates[trimmedNew] != nil {
            lock.unlock()
            logger.warning("布局模板系统", "重命名失败：模板名称「\(trimmedNew)」已存在")
            return false
        }
        t.name = trimmedNew
        t.updatedAt = Date()
        templates[trimmedNew] = t
        templates.removeValue(forKey: oldName)
        lock.unlock()
        saveToDisk()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .layoutTemplateRenamed, object: nil)
        }
        return true
    }

    /// 应用模板（优先应用自定义模板，再尝试内置模板）
    @discardableResult
    public func applyTemplate(name: String) -> Bool {
        lock.lock()
        let found = templates[name] != nil || builtInTemplates.contains(where: { $0.name == name })
        lock.unlock()
        guard found else {
            logger.warning("布局模板系统", "应用模板失败：未找到模板「\(name)」")
            return false
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .layoutTemplateLoaded, object: nil)
        }
        return true
    }

    // MARK: - 导入导出

    /// 导出模板为JSON数据
    public func exportTemplate(name: String) -> Data? {
        guard let template = template(named: name) else {
            logger.warning("布局模板系统", "导出失败：未找到模板「\(name)」")
            return nil
        }
        guard let data = try? JSONEncoder().encode(template) else {
            logger.warning("布局模板系统", "导出失败：模板序列化错误")
            return nil
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .layoutTemplateExported, object: nil)
        }
        return data
    }

    /// 从JSON数据导入模板
    @discardableResult
    public func importTemplate(from data: Data) -> Bool {
        guard let template = try? JSONDecoder().decode(UILayoutTemplate.self, from: data) else {
            logger.warning("布局模板系统", "导入失败：数据格式错误")
            return false
        }
        guard !template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.warning("布局模板系统", "导入失败：模板名称为空")
            return false
        }
        var t = template
        t.isBuiltIn = false // 导入的模板都是自定义模板
        t.updatedAt = Date()
        lock.lock()
        templates[t.name] = t
        lock.unlock()
        saveToDisk()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .layoutTemplateImported, object: nil)
        }
        return true
    }

    // MARK: - 设置面板

    /// 设置面板数据
    public func settingsPanelData() -> [String: Any] {
        lock.lock()
        let count = templates.count
        let builtInCount = builtInTemplates.count
        lock.unlock()
        return [
            "templateCount": count + builtInCount,
            "builtInCount": builtInCount,
            "customCount": count
        ]
    }
}

// MARK: - 迁回自 UI-02：class UILayoutTemplatePreviewView
public final class UILayoutTemplatePreviewView: NSView , @unchecked Sendable{

    /// 当前展示的模板
    public var template: UILayoutTemplate? {
        didSet { needsDisplay = true }
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let template = template else {
            NSColor.controlBackgroundColor.setFill()
            dirtyRect.fill()
            return
        }

        // 背景
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()

        // 边框
        NSColor.separatorColor.setStroke()
        NSBezierPath(rect: dirtyRect.insetBy(dx: 1, dy: 1)).stroke()

        // 绘制模块方块
        let count = template.layout.openModuleNames.count
        let cols = max(1, min(count, 3))
        let rows = max(1, Int(ceil(Double(count) / Double(cols))))
        let pad: CGFloat = 4
        let cellW = (bounds.width - pad * CGFloat(cols + 1)) / CGFloat(cols)
        let cellH = (bounds.height - pad * CGFloat(rows + 1)) / CGFloat(rows)

        let colors: [NSColor] = [
            .systemRed, .systemGreen, .systemBlue,
            .systemOrange, .systemPurple
        ]

        for i in 0..<count {
            let col = i % cols
            let row = i / cols
            let x = pad + CGFloat(col) * (cellW + pad)
            let y = pad + CGFloat(row) * (cellH + pad)
            let rect = NSRect(x: x, y: y, width: cellW, height: cellH)
            colors[i % colors.count].withAlphaComponent(0.5).setFill()
            rect.fill()
        }

        // 空布局提示
        if count == 0 {
            let text = "空布局" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let size = text.size(withAttributes: attrs)
            let rect = NSRect(
                x: (bounds.width - size.width) / 2,
                y: (bounds.height - size.height) / 2,
                width: size.width,
                height: size.height
            )
            text.draw(in: rect, withAttributes: attrs)
        }
    }
}
