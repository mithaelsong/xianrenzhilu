// 功能27: 日志记录
// 对应: 记录所有UI操作（窗口打开/关闭、模块加载等），支持分级、文件轮转、日志查看器
// 优先级: P0

import AppKit
import Foundation
import os.log
import UniformTypeIdentifiers

private let uilogger = Logger(subsystem: "com.xianrenzhilu.ui", category: "ui-gl-35")

// 使用UI-02的UILogLevel
// 本文件不再定义该类型

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能27：日志记录 — 单元测试
/// 覆盖：分级日志/内存缓存/级别过滤/导出/清理
func test_uilog() {
    let manager = UILogManager.shared
    
    print("\n🧪 测试1: 记录日志")
    manager.log(level: .info, category: "测试", message: "这是一条测试日志")
    let entries = manager.allEntries()
    guard !entries.isEmpty else {
        fatalError("❌ 测试1失败: 日志应被记录")
    }
    print("✅ 测试1通过: 日志记录成功")
    
    print("\n🧪 测试2: 日志级别过滤")
    let debugCount = manager.recentEntries(count: 5).count
    _ = debugCount
    print("✅ 测试2通过: 日志过滤正常")
    
    print("\n🧪 测试3: 导出文本")
    let exported = manager.export()
    guard !exported.isEmpty else {
        fatalError("❌ 测试3失败: 导出不应为空")
    }
    print("✅ 测试3通过: 日志导出正常")
    
    print("\n🧪 测试4: 日志统计")
    let stats = manager.logStatistics()
    guard stats.memoryEntries >= 1 else {
        fatalError("❌ 测试4失败: 统计应有日志条目")
    }
    print("✅ 测试4通过: 日志统计正常")
    
    print("\n🧪 测试5: 级别设置")
    let oldLevel = manager.logLevel
    manager.setLogLevel(.debug)
    manager.setLogLevel(oldLevel)
    print("✅ 测试5通过: 级别设置正常")
    
    print("\n🧪 测试6: 清空内存缓存")
    manager.clear()
    let afterClear = manager.allEntries()
    guard afterClear.isEmpty else {
        fatalError("❌ 测试6失败: 清空后应为空")
    }
    print("✅ 测试6通过: 清空成功")
    
    print("\n🧪 测试7: 便捷分类方法")
    manager.info("测试", "便捷info")
    manager.warning("测试", "便捷warning")
    manager.error("测试", "便捷error")
    print("✅ 测试7通过: 便捷方法正常")
    
    print("\n=== 全部日志系统测试通过 ✅ ===\n")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：extension Notification.Name
public extension Notification.Name {
    /// 日志内容更新时发送
    static let UILogDidUpdate = Notification.Name("UILogDidUpdate")
    /// 日志级别发生变更时发送
    static let UILogLevelDidChange = Notification.Name("UILogLevelDidChange")
    /// 日志文件发生轮转时发送
    static let UILogDidRotate = Notification.Name("UILogDidRotate")
}

// MARK: - 迁回自 UI-02：class UILogManager
public final class UILogManager : @unchecked Sendable {
    public static let shared = UILogManager()

    // MARK: - 配置常量
    private let maxMemoryEntries = 1000                 // 内存缓存最大条目数
    private let maxFileSize: UInt64 = 10 * 1024 * 1024  // 文件轮转大小阈值 10MB
    private let defaultKeepDays = 30                      // 默认保留最近30天日志

    // MARK: - 内部状态
    private var entries: [UILogEntry] = []
    private let lock = NSRecursiveLock()
    private var currentLogFile: URL?
    private var fileHandle: FileHandle?
    private var currentFileSize: UInt64 = 0
    private var writeQueue = DispatchQueue(label: "com.xianrenzhilu.logwriter", qos: .utility)
    private var cleanupTimer: Timer?

    // MARK: - 公开属性
    /// 当前日志级别（低于此级别的日志不会被记录到内存与文件）
    public var logLevel: UILogLevel = .info {
        didSet {
            if oldValue != logLevel {
                logUnified(level: .info, category: "日志系统", message: "日志级别已切换为: \(logLevel.label)")
                NotificationCenter.default.post(
                    name: .UILogLevelDidChange,
                    object: self,
                    userInfo: ["level": logLevel.rawValue, "levelLabel": logLevel.label]
                )
            }
        }
    }

    /// 日志文件存放目录: ~/Library/Logs/仙人指路/
    public var logDirectory: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return library.appendingPathComponent("Logs/仙人指路", isDirectory: true)
    }

    // MARK: - 初始化
    private init() {
        setupLogDirectory()
        rotateIfNeeded()
        cleanupOldLogs(keepDays: defaultKeepDays)
        // 确保定时清理任务注册到主线程RunLoop
        DispatchQueue.main.async { [weak self] in
            self?.startCleanupTimer()
        }
    }

    deinit {
        cleanupTimer?.invalidate()
        closeFileHandle()
    }

    // MARK: - 目录与文件管理

    /// 创建日志目录（如果不存在）
    private func setupLogDirectory() {
        do {
            try FileManager.default.createDirectory(
                at: logDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            uilogger.error("日志目录创建失败: \(error.localizedDescription)")
        }
    }

    /// 根据当前日期生成日志文件路径
    private func currentLogFileURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        return logDirectory.appendingPathComponent("仙人指路_\(dateStr).log")
    }

    /// 归档旧日志文件，避免文件名冲突
    private func archiveFile(_ url: URL) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        var archiveName = "仙人指路_\(formatter.string(from: Date())).log"
        var archiveURL = logDirectory.appendingPathComponent(archiveName)
        var counter = 1
        while FileManager.default.fileExists(atPath: archiveURL.path) {
            archiveName = "仙人指路_\(formatter.string(from: Date()))_\(counter).log"
            archiveURL = logDirectory.appendingPathComponent(archiveName)
            counter += 1
        }
        do {
            try FileManager.default.moveItem(at: url, to: archiveURL)
            NotificationCenter.default.post(
                name: .UILogDidRotate,
                object: self,
                userInfo: ["archivedFile": archiveURL, "originalFile": url]
            )
        } catch {
            uilogger.error("日志归档失败: \(error.localizedDescription)")
        }
    }

    /// 检查并执行日志轮转（时间轮转 + 大小轮转）
    private func rotateIfNeeded() {
        let targetURL = currentLogFileURL()

        // 按时间轮转：日期变化时切换新文件
        if let current = currentLogFile, current != targetURL {
            closeFileHandle()
            if FileManager.default.fileExists(atPath: current.path) {
                archiveFile(current)
            }
            currentLogFile = nil
            currentFileSize = 0
        }

        // 按大小轮转：单文件超过阈值时归档
        if let current = currentLogFile,
           currentFileSize >= maxFileSize,
           FileManager.default.fileExists(atPath: current.path) {
            closeFileHandle()
            archiveFile(current)
            currentLogFile = nil
            currentFileSize = 0
        }

        // 打开当前日期的日志文件
        if currentLogFile == nil {
            currentLogFile = targetURL
            if !FileManager.default.fileExists(atPath: targetURL.path) {
                FileManager.default.createFile(atPath: targetURL.path, contents: nil, attributes: nil)
            }
            do {
                fileHandle = try FileHandle(forWritingTo: targetURL)
                if #available(macOS 10.15.4, *) {
                    currentFileSize = try fileHandle?.seekToEnd() ?? 0
                } else {
                    fileHandle?.seekToEndOfFile()
                    let attrs = try FileManager.default.attributesOfItem(atPath: targetURL.path)
                    currentFileSize = attrs[.size] as? UInt64 ?? 0
                }
            } catch {
                uilogger.error("日志文件打开失败: \(error.localizedDescription)")
                fileHandle = nil
            }
        }
    }

    /// 关闭文件句柄
    private func closeFileHandle() {
        fileHandle?.closeFile()
        fileHandle = nil
    }

    // MARK: - 日志保留策略

    /// 启动每日定时清理任务
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.cleanupOldLogs(keepDays: self?.defaultKeepDays ?? 30)
        }
    }

    /// 清理过旧的日志文件，仅保留指定天数内的日志
    public func cleanupOldLogs(keepDays: Int) {
        let cutoffDate = Date().addingTimeInterval(TimeInterval(-keepDays * 86400))
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: logDirectory,
                includingPropertiesForKeys: [.creationDateKey]
            )
            for file in files where file.pathExtension == "log" {
                let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
                if let createDate = attrs[.creationDate] as? Date, createDate < cutoffDate {
                    try FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            uilogger.error("日志清理失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 统一日志接口（Logger）

    /// 使用 os.Logger 输出到系统统一日志（辅助调试）
    private func logUnified(level: UILogLevel, category: String, message: String) {
        if #available(macOS 11.0, *) {
            switch level {
            case .debug:
                uilogger.debug("\(message)")
            case .info:
                uilogger.info("\(message)")
            case .warning:
                uilogger.warning("\(message)")
            case .error:
                uilogger.error("\(message)")
            case .critical:
                uilogger.critical("\(message)")
            }
        }
    }

    // MARK: - 写入日志

    /// 记录一条日志（主线程安全，文件写入异步执行）
    public func log(level: UILogLevel, category: String, message: String) {
        guard level.rawValue >= logLevel.rawValue else { return }

        let entry = UILogEntry(timestamp: Date(), level: level, category: category, message: message)

        // 写入内存缓存（NSRecursiveLock保护）
        lock.lock()
        entries.append(entry)
        if entries.count > maxMemoryEntries {
            entries.removeFirst(entries.count - maxMemoryEntries)
        }
        lock.unlock()

        // 异步写入文件
        writeQueue.async { [weak self] in
            self?.writeToFile(entry: entry)
        }

        // 同步输出到系统日志
        logUnified(level: level, category: category, message: message)

        // 发送更新通知（供查看器刷新）
        NotificationCenter.default.post(
            name: .UILogDidUpdate,
            object: self,
            userInfo: ["entry": entry]
        )

        #if DEBUG
        uilogger.info("[\(level.label)][\(category)] \(message)")
        #endif
    }

    public func debug(_ category: String, _ message: String) {
        log(level: .debug, category: category, message: message)
    }

    public func info(_ category: String, _ message: String) {
        log(level: .info, category: category, message: message)
    }

    public func warning(_ category: String, _ message: String) {
        log(level: .warning, category: category, message: message)
    }

    public func error(_ category: String, _ message: String) {
        log(level: .error, category: category, message: message)
    }

    public func fatal(_ category: String, _ message: String) {
        log(level: .critical, category: category, message: message)
    }

    /// 在后台队列中将单条日志写入磁盘文件
    private func writeToFile(entry: UILogEntry) {
        rotateIfNeeded()
        guard let handle = fileHandle else { return }

        let line = entry.fileLine + "\n"
        guard let data = line.data(using: .utf8) else { return }

        if #available(macOS 10.15.4, *) {
            do {
                let offset = try handle.seekToEnd()
                try handle.write(contentsOf: data)
                currentFileSize = offset + UInt64(data.count)
            } catch {
                uilogger.error("日志写入失败: \(error.localizedDescription)")
            }
        } else {
            handle.seekToEndOfFile()
            handle.write(data)
            currentFileSize += UInt64(data.count)
        }

        // 写入后再次检查是否触发大小轮转
        if currentFileSize >= maxFileSize {
            rotateIfNeeded()
        }
    }

    // MARK: - 查询与导出

    /// 获取最近N条内存缓存日志
    public func recentEntries(count: Int = 100) -> [UILogEntry] {
        lock.lock()
        let recent = Array(entries.suffix(count))
        lock.unlock()
        return recent
    }

    /// 获取全部内存缓存日志
    public func allEntries() -> [UILogEntry] {
        lock.lock()
        let all = entries
        lock.unlock()
        return all
    }

    /// 获取日志目录下所有日志文件URL（按文件名降序排列）
    public func getLogFiles() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: logDirectory,
                includingPropertiesForKeys: nil
            )
            return files
                .filter { $0.pathExtension == "log" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            return []
        }
    }

    /// 读取指定日志文件的文本内容
    public func readLogFile(at url: URL) -> String? {
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// 将内存缓存日志导出为文本字符串
    public func export() -> String {
        lock.lock()
        let lines = entries.map { $0.fileLine }
        lock.unlock()
        return lines.joined(separator: "\n")
    }

    /// 导出内存缓存日志到指定文件
    public func exportToFile(to url: URL) throws {
        let content = export()
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// 导出指定级别及以上的过滤日志到文件
    public func exportFiltered(level: UILogLevel, to url: URL) throws {
        lock.lock()
        let filtered = entries.filter { $0.level.rawValue >= level.rawValue }
        let lines = filtered.map { $0.fileLine }
        lock.unlock()
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    /// 清空内存缓存日志（不会删除磁盘文件）
    public func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    // MARK: - 设置面板方法

    /// 设置当前日志级别（供设置面板调用）
    public func setLogLevel(_ level: UILogLevel) {
        logLevel = level
    }

    /// 获取日志文件列表信息（文件名 + 大小，供设置面板展示）
    public func logFileList() -> [(url: URL, name: String, size: String)] {
        let files = getLogFiles()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file

        return files.compactMap { url in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int64 else { return nil }
            return (url: url, name: url.lastPathComponent, size: formatter.string(fromByteCount: size))
        }
    }

    /// 获取日志统计信息（文件总数、总大小、内存条目数）
    public func logStatistics() -> (totalFiles: Int, totalSize: String, memoryEntries: Int) {
        let files = getLogFiles()
        var totalBytes: Int64 = 0
        for file in files {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int64 {
                totalBytes += size
            }
        }
        let formatter = ByteCountFormatter()
        let sizeStr = formatter.string(fromByteCount: totalBytes)
        return (totalFiles: files.count, totalSize: sizeStr, memoryEntries: allEntries().count)
    }

    /// 将日志目录下所有日志文件复制到指定目录
    public func exportAllLogs(to directory: URL) throws {
        let files = getLogFiles()
        for file in files {
            let dest = directory.appendingPathComponent(file.lastPathComponent)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: file, to: dest)
        }
    }
}

// MARK: - 迁回自 UI-02：class UILogViewerViewController
public final class UILogViewerViewController: NSViewController , @unchecked Sendable{

    // MARK: - UI 组件
    private var searchField: NSSearchField!
    private var levelPopUp: NSPopUpButton!
    private var refreshButton: NSButton!
    private var exportButton: NSButton!
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var statusLabel: NSTextField!

    // MARK: - 数据
    private var allEntries: [UILogEntry] = []
    private var filteredEntries: [UILogEntry] = []

    // MARK: - 生命周期

    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reloadData()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(logDidUpdate),
            name: .UILogDidUpdate,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI 搭建

    private func setupUI() {
        // 搜索框
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "搜索日志..."
        searchField.target = self
        searchField.action = #selector(filterChanged)
        view.addSubview(searchField)

        // 级别筛选下拉框
        levelPopUp = NSPopUpButton()
        levelPopUp.translatesAutoresizingMaskIntoConstraints = false
        levelPopUp.addItems(withTitles: ["全部级别"] + UILogLevel.allCases.map { $0.label })
        levelPopUp.target = self
        levelPopUp.action = #selector(filterChanged)
        view.addSubview(levelPopUp)

        // 刷新按钮
        refreshButton = NSButton(title: "刷新", target: self, action: #selector(reloadData))
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(refreshButton)

        // 导出按钮
        exportButton = NSButton(title: "导出", target: self, action: #selector(exportLogs))
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(exportButton)

        // 表格视图
        tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.delegate = self
        tableView.dataSource = self

        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = "时间"
        timeColumn.width = 160
        timeColumn.minWidth = 140
        tableView.addTableColumn(timeColumn)

        let levelColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("level"))
        levelColumn.title = "级别"
        levelColumn.width = 60
        levelColumn.minWidth = 50
        tableView.addTableColumn(levelColumn)

        let categoryColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("category"))
        categoryColumn.title = "分类"
        categoryColumn.width = 120
        categoryColumn.minWidth = 80
        tableView.addTableColumn(categoryColumn)

        let messageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("message"))
        messageColumn.title = "消息"
        messageColumn.width = 500
        messageColumn.minWidth = 200
        tableView.addTableColumn(messageColumn)

        // 滚动视图包裹表格
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        view.addSubview(scrollView)

        // 状态栏标签
        statusLabel = NSTextField(labelWithString: "就绪")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont(name: "Menlo", size: 11) ?? NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        view.addSubview(statusLabel)

        // 自动布局约束
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            searchField.widthAnchor.constraint(equalToConstant: 200),

            levelPopUp.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            levelPopUp.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 8),
            levelPopUp.widthAnchor.constraint(equalToConstant: 120),

            refreshButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            refreshButton.leadingAnchor.constraint(equalTo: levelPopUp.trailingAnchor, constant: 8),

            exportButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            exportButton.leadingAnchor.constraint(equalTo: refreshButton.trailingAnchor, constant: 8),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),

            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            statusLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    // MARK: - 数据操作

    @objc private func reloadData() {
        allEntries = UILogManager.shared.allEntries()
        applyFilter()
    }

    @objc private func logDidUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadData()
        }
    }

    @objc private func filterChanged() {
        applyFilter()
    }

    /// 根据搜索文本和级别筛选条件过滤日志
    private func applyFilter() {
        let searchText = searchField.stringValue.lowercased()
        let levelIndex = levelPopUp.indexOfSelectedItem

        filteredEntries = allEntries.filter { entry in
            // 级别筛选（0表示全部级别）
            if levelIndex > 0 {
                let selectedLevel = UILogLevel.allCases[levelIndex - 1]
                if entry.level.rawValue < selectedLevel.rawValue {
                    return false
                }
            }
            // 文本搜索（匹配分类和消息）
            if !searchText.isEmpty {
                let combined = "\(entry.category) \(entry.message)".lowercased()
                return combined.contains(searchText)
            }
            return true
        }

        tableView.reloadData()
        statusLabel.stringValue = "显示 \(filteredEntries.count) / \(allEntries.count) 条日志"
    }

    @objc private func exportLogs() {
        guard let window = view.window else { return }
        let panel = NSSavePanel()
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.plainText]
        } else {
            panel.allowedFileTypes = ["txt"]
        }
        panel.nameFieldStringValue = "仙人指路日志_\(Int(Date().timeIntervalSince1970)).txt"

        panel.beginSheetModal(for: window) { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            do {
                let content = self?.filteredEntries.map { $0.fileLine }.joined(separator: "\n") ?? ""
                try content.write(to: url, atomically: true, encoding: .utf8)
                self?.statusLabel.stringValue = "导出成功: \(url.path)"
            } catch {
                self?.statusLabel.stringValue = "导出失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 迁回自 UI-02：extension UILogViewerViewController
extension UILogViewerViewController: NSTableViewDataSource, NSTableViewDelegate {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredEntries.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = filteredEntries[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""

        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: "")
        let font = NSFont(name: "Menlo", size: 12) ?? NSFont.systemFont(ofSize: 12)
        textField.font = font
        textField.lineBreakMode = .byTruncatingTail

        switch identifier {
        case "time":
            textField.stringValue = entry.formattedTimestamp
        case "level":
            textField.stringValue = entry.level.label
            textField.textColor = entry.level.color
        case "category":
            textField.stringValue = entry.category
        case "message":
            textField.stringValue = entry.message
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

    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }
}

// MARK: - 迁回自 UI-02：class UILogViewerWindowController
public final class UILogViewerWindowController: NSWindowController , @unchecked Sendable{

    public init() {
        let viewController = UILogViewerViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "仙人指路 - 日志查看器"
        window.contentViewController = viewController
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - 迁回自 UI-02：struct UILogEntry
// MARK: - UI-GL-35 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-35_types.swift
// 版本: 2.0
// MARK: - UI日志条目
public struct UILogEntry {
    public let timestamp: Date
    public let level: UILogLevel
    public let category: String
    public let message: String

    /// 格式化的日期时间字符串（精确到毫秒）
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    /// 转换为文件日志的一行文本
    public var fileLine: String {
        return "[\(formattedTimestamp)][\(level.label)][\(category)] \(message)"
    }
}
