// MARK: - UI-13: UI模块列表UI
// 功能编号: UI-14
// 版本: 2.0
// 职责: 开发者工具：在UI中查看和管理模块，支持操作按钮、状态列、刷新，仅DEBUG模式显示
// 依赖: UI-05 注册表, UI-06 卸载器, UI-08 获取实例, UI-12 日志, UI-04 错误处理

import Foundation
import AppKit

// MARK: - 模块列表UI管理器
// 独立编译存根
// 类型 UIModuleRegistry 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleLocator 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleUnloader 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleErrorHandler 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleListUI 已迁移到 UI-02_公共类型定义.swift

// MARK: - NSTableViewDataSource
extension UIModuleListUI: NSTableViewDataSource {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        lock.lock()
        let count = moduleList.count
        lock.unlock()
        return count
    }
}

// MARK: - NSTableViewDelegate
extension UIModuleListUI: NSTableViewDelegate {
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var moduleID = ""
        var moduleName = ""
        lock.lock()
        if row < moduleList.count {
            moduleID = moduleList[row].moduleID
            moduleName = moduleList[row].name
        }
        lock.unlock()
        guard !moduleID.isEmpty else { return nil }

        if tableColumn?.identifier.rawValue == "actions" {
            let cellId = NSUserInterfaceItemIdentifier("actionCell")
            let cell: NSTableCellView
            if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView {
                cell = reused
                // 清理旧按钮
                cell.subviews.forEach { $0.removeFromSuperview() }
            } else {
                cell = NSTableCellView()
                cell.identifier = cellId
            }

            let uninstallButton = NSButton(frame: NSRect(x: 4, y: 6, width: 60, height: 28))
            uninstallButton.title = "卸载"
            uninstallButton.bezelStyle = .rounded
            uninstallButton.target = self
            uninstallButton.action = #selector(onUninstallButtonClicked(_:))
            uninstallButton.tag = row

            let detailButton = NSButton(frame: NSRect(x: 72, y: 6, width: 80, height: 28))
            detailButton.title = "查看详情"
            detailButton.bezelStyle = .rounded
            detailButton.target = self
            detailButton.action = #selector(onDetailButtonClicked(_:))
            detailButton.tag = row

            let status = getModuleStatus(moduleID: moduleID)
            if status == .unloading {
                uninstallButton.isEnabled = false
                uninstallButton.title = "卸载中..."
            }

            cell.addSubview(uninstallButton)
            cell.addSubview(detailButton)
            return cell
        }

        let cellId: NSUserInterfaceItemIdentifier
        var labelText = ""
        switch tableColumn?.identifier.rawValue {
        case "name":
            cellId = NSUserInterfaceItemIdentifier("nameCell")
            labelText = moduleName
        case "id":
            cellId = NSUserInterfaceItemIdentifier("idCell")
            labelText = moduleID
        case "status":
            cellId = NSUserInterfaceItemIdentifier("statusCell")
            labelText = getModuleStatus(moduleID: moduleID).rawValue
        default:
            return nil
        }

        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = cellId
            let label = NSTextField(labelWithString: "")
            label.frame = NSRect(x: 4, y: 10, width: tableColumn?.width ?? 100, height: 20)
            label.font = NSFont.systemFont(ofSize: 12)
            label.tag = 1001
            cell.addSubview(label)
        }

        if let label = cell.viewWithTag(1001) as? NSTextField {
            label.stringValue = labelText
            if tableColumn?.identifier.rawValue == "status" {
                let status = getModuleStatus(moduleID: moduleID)
                switch status {
                case .normal:
                    label.textColor = NSColor.labelColor
                case .unloading:
                    label.textColor = NSColor.systemOrange
                case .failed:
                    label.textColor = NSColor.systemRed
                }
            }
        }

        return cell
    }

    @objc private func onUninstallButtonClicked(_ sender: NSButton) {
        let row = sender.tag
        var moduleID = ""
        var moduleName = ""
        lock.lock()
        if row < moduleList.count {
            moduleID = moduleList[row].moduleID
            moduleName = moduleList[row].name
        }
        lock.unlock()
        guard !moduleID.isEmpty else { return }
        uninstallModule(moduleID: moduleID, moduleName: moduleName)
    }

    @objc private func onDetailButtonClicked(_ sender: NSButton) {
        let row = sender.tag
        var moduleID = ""
        var moduleName = ""
        lock.lock()
        if row < moduleList.count {
            moduleID = moduleList[row].moduleID
            moduleName = moduleList[row].name
        }
        lock.unlock()
        guard !moduleID.isEmpty else { return }
        showModuleDetails(moduleID: moduleID, moduleName: moduleName)
    }
}

// MARK: - NSWindowDelegate
// 用户点击红色关闭按钮时清除引用，防止调用已关闭窗口
// 若不处理，下次 showDebugWindow() 会对已关闭窗口调用 makeKeyAndOrderFront
// 导致显示异常
// 注：NSWindow 对 delegate 是弱引用，不产生循环引用
extension UIModuleListUI: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        debugWindow = nil
        tableView = nil
    }
}

// MARK: - 测试
internal func test_UI13() {
    print("\n=== UI-13 模块列表UI测试 ===\n")

    let listUI = UIModuleListUI.shared
    let registry = UIModuleRegistry.shared

    // MARK: 测试1: 刷新列表（空表）
    print("🧪 测试1: 刷新列表（空表）")
    listUI.refreshModuleList()
    // 不崩溃即通过
    print("✅ 测试1通过: 空列表刷新不崩溃")

    // MARK: 测试2: 刷新列表（有模块）
    print("\n🧪 测试2: 刷新列表（有模块）")
// 类型 UITestListModule 已迁移到 UI-02_公共类型定义.swift
    let testMod = UITestListModule(id: "test.listui.01", name: "列表测试模块")
    registry.register(instance: testMod, name: "TestListUIModule")
    listUI.refreshModuleList()
    registry.unregister(name: "TestListUIModule")
    print("✅ 测试2通过: 有模块刷新不崩溃")

    // MARK: 测试3: 状态获取
    print("\n🧪 测试3: 状态获取")
    // 不存在的模块默认正常
    let status = listUI.getModuleStatus(moduleID: "test.nonexist")
    guard status == .normal else {
        fatalError("❌ 测试3失败: 未注册模块默认应为 normal，实际: \(status)")
    }
    print("✅ 测试3通过: 不存在的模块返回 normal")

    // MARK: 测试4: 窗口创建与关闭
    print("\n🧪 测试4: 窗口创建与关闭（不阻塞）")
    // show和close在主线程同步执行，但测试可能不在主线程，跳过UI操作
    listUI.closeDebugWindow()
    print("✅ 测试4通过: 关闭窗口不崩溃")

    // MARK: 测试5: 重新加载所有模块
    print("\n🧪 测试5: 重新加载所有模块")
    listUI.reloadAllModules()
    print("✅ 测试5通过: reloadAllModules 不崩溃")

    print("\n=== 全部 UI-13 模块列表UI测试通过 ✅ ===\n")
}

#if FILEINDEPENDENT
// MARK: - 独立编译存根：UI-13 外部依赖
// 类型 UIModuleRegistry 已迁移到 UI-02_公共类型定义.swift
// 类型 UIModuleLocator 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleUnloader 已迁移到 UI-02_公共类型定义.swift

// 类型 UIModuleErrorHandler 已迁移到 UI-02_公共类型定义.swift

// 类型 UILoadingLogManager 已迁移到 UI-02_公共类型定义.swift
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UITestListModule
    class UITestListModule: UIModuleProtocol , @unchecked Sendable{
        required init() { moduleID = ""; moduleName = ""; moduleDescription = "" }
        let moduleID: String
        let moduleName: String
        let moduleVersion = "2.0"
        let moduleDescription: String
        let isUnloadable = true
        init(id: String, name: String, desc: String = "") { moduleID = id; moduleName = name; moduleDescription = desc }
        func start(context: Any?) throws {}
        func stop() {}
        func pause() {}
        func resume() {}
        func willUnload() {}
        func didUnload() {}
    }

// MARK: - 迁回自 UI-02：class UIModuleListUI
public final class UIModuleListUI: NSObject , @unchecked Sendable{
    public static let shared = UIModuleListUI()

    let lock = NSRecursiveLock()
    let logger = UILoadingLogManager.shared
    let registry = UIModuleRegistry.shared
    let locator = UIModuleLocator.shared
    let unloader = UIModuleUnloader.shared
    let errorHandler = UIModuleErrorHandler.shared

    var debugWindow: NSWindow?
    var tableView: NSTableView?
    var moduleList: [(moduleID: String, name: String, instance: UIModuleProtocol)] = []
    var unloadingModules: Set<String> = []

    private override init() {}

    // MARK: - 显示调试窗口

    /// 打开模块管理调试窗口
    public func showDebugWindow() {
        #if DEBUG
        guard debugWindow == nil else {
            debugWindow?.makeKeyAndOrderFront(nil)
            return
        }

        refreshModuleList()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "UI模块管理"
        window.center()
        window.delegate = self

        guard let contentView = window.contentView else {
            logger.error("模块列表UI", "创建窗口失败：contentView为空")
            return
        }
        let contentBounds = contentView.bounds

        // 底部按钮区域高度
        let bottomBarHeight: CGFloat = 40.0

        // 滚动视图占据上方区域
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: bottomBarHeight, width: contentBounds.width, height: contentBounds.height - bottomBarHeight))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        let table = NSTableView(frame: scrollView.bounds)
        table.autoresizingMask = [.width, .height]
        table.rowHeight = 40

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "模块名称"
        nameCol.width = 150
        table.addTableColumn(nameCol)

        let idCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("id"))
        idCol.title = "ID"
        idCol.width = 200
        table.addTableColumn(idCol)

        let statusCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusCol.title = "状态"
        statusCol.width = 80
        table.addTableColumn(statusCol)

        let actionCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("actions"))
        actionCol.title = "操作"
        actionCol.width = 200
        table.addTableColumn(actionCol)

        table.delegate = self
        table.dataSource = self
        scrollView.documentView = table
        contentView.addSubview(scrollView)

        // 底部刷新按钮
        let refreshButton = NSButton(frame: NSRect(x: 10, y: 5, width: 80, height: 30))
        refreshButton.title = "刷新"
        refreshButton.target = self
        refreshButton.action = #selector(onRefreshClicked)
        refreshButton.autoresizingMask = [.maxXMargin]
        contentView.addSubview(refreshButton)

        self.tableView = table
        self.debugWindow = window

        window.makeKeyAndOrderFront(nil)
        logger.info("模块列表UI", "调试窗口已打开")
        #else
        logger.info("模块列表UI", "模块列表UI仅在 DEBUG 模式下可用")
        #endif
    }

    /// 关闭调试窗口
    public func closeDebugWindow() {
        debugWindow?.close()
        debugWindow = nil
        tableView = nil
    }

    // MARK: - 刷新按钮点击

    @objc private func onRefreshClicked() {
        refreshModuleList()
        logger.info("模块列表UI", "用户手动刷新模块列表")
    }

    // MARK: - 刷新数据

    /// 从注册表重新加载模块列表并刷新UI
    public func refreshModuleList() {
        lock.lock()
        moduleList = registry.allRegisteredModules()
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.tableView?.reloadData()
        }
    }

    // MARK: - 获取模块状态

    /// 获取指定模块的当前状态
    public func getModuleStatus(moduleID: String) -> UIModuleListStatus {
        lock.lock()
        let isUnloading = unloadingModules.contains(moduleID)
        lock.unlock()

        if isUnloading {
            return .unloading
        }

        if errorHandler.isInQuarantine(moduleID) {
            return .failed
        }

        return .normal
    }

    // MARK: - 卸载模块

    /// 在后台异步卸载指定模块
    func uninstallModule(moduleID: String, moduleName: String) {
        lock.lock()
        unloadingModules.insert(moduleID)
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.tableView?.reloadData()
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let result = self.unloader.unloadModule(name: moduleName)

            self.lock.lock()
            self.unloadingModules.remove(moduleID)
            self.lock.unlock()

            switch result {
            case .success:
                self.logger.info("模块列表UI", "模块 '\(moduleName)' (ID: \(moduleID)) 卸载成功")
            case .failed(let reason):
                self.logger.error("模块列表UI", "模块 '\(moduleName)' (ID: \(moduleID)) 卸载失败: \(reason)")
            case .rollback:
                self.logger.warning("模块列表UI", "模块 '\(moduleName)' (ID: \(moduleID)) 卸载触发回滚")
            case .moduleNotFound:
                self.logger.error("模块列表UI", "模块 '\(moduleName)' (ID: \(moduleID)) 未找到")
            case .failure(let error):
                self.logger.error("模块列表UI", "模块 '\(moduleName)' (ID: \(moduleID)) 卸载失败: \(error.localizedDescription)")
            case .notFound:
                self.logger.error("模块列表UI", "模块 '\(moduleName)' (ID: \(moduleID)) 未找到")
            case .hasDependencies(let deps):
                self.logger.warning("模块列表UI", "模块 '\(moduleName)' (ID: \(moduleID)) 有依赖: \(deps.joined(separator: ", "))")
            }

            self.refreshModuleList()
        }
    }

    // MARK: - 查看模块详情

    /// 弹出模块详细信息窗口
    func showModuleDetails(moduleID: String, moduleName: String) {
        let instance = locator.getModule(moduleName)
        var detailText = "模块ID: \(moduleID)\n"
        detailText += "模块名称: \(moduleName)\n"

        if let inst = instance {
            detailText += "版本: \(inst.moduleVersion)\n"
            detailText += "可卸载: \(inst.isUnloadable ? "是" : "否")\n"
        } else {
            detailText += "状态: 未获取到实例\n"
        }

        let status = getModuleStatus(moduleID: moduleID)
        detailText += "当前状态: \(status.rawValue)\n"

        if errorHandler.isInQuarantine(moduleID) {
            let records = errorHandler.failedModules().filter { $0.moduleID == moduleID }
            if let record = records.first {
                detailText += "\n错误信息: \(record.error)\n"
                detailText += "错误时间: \(record.timestamp)\n"
                detailText += "重试次数: \(record.retryCount)\n"
                detailText += "严重程度: \(record.severity.rawValue)\n"
            }
        }

        let alert = NSAlert()
        alert.messageText = "模块详情 — \(moduleName)"
        alert.informativeText = detailText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    // MARK: - 重新加载所有模块

    /// 重新加载全部模块（刷新列表）
    public func reloadAllModules() {
        logger.info("模块列表UI", "开始重新加载所有模块...")
        refreshModuleList()
    }
}
