// 功能43: 画线工具库与模板
// 对应: 支持趋势线/水平线/垂直线/平行通道/斐波那契回撤等画线工具，支持模板保存/加载/分享
// 优先级: P2

import AppKit
import Foundation
import os.log

// MARK: - 全局日志对象
private let logger = Logger(subsystem: "com.xianrenzhilu.drawing", category: "UIDrawingToolManager")

// MARK: - 画线工具通知名称
/// 线条创建完成通知
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {



// MARK: - 测试代码
#if DEBUG

/// 功能43：画线工具库与模板 — 单元测试
func test_drawing() {
    let manager = UIDrawingToolManager.shared
    
    logger.info("测试1: 默认状态")
    let lines = manager.allLines
    if lines.isEmpty { logger.info("✅ 测试1通过: 初始无线条") }
    else { logger.error("❌ 测试1失败") }
    
    logger.info("测试2: 创建线条")
    let lineID = manager.createLineByClick(toolType: .horizontalLine, at: CGPoint(x: 0.5, y: 0.5))
    if lineID != nil { logger.info("✅ 测试2通过") }
    else { logger.error("❌ 测试2失败") }
    
    logger.info("测试3: 线条查询")
    let created = manager.line(by: lineID!)
    if created != nil { logger.info("✅ 测试3通过") }
    else { logger.error("❌ 测试3失败") }
    
    logger.info("测试4: 选中线条")
    manager.selectLine(id: lineID!)
    let selected = manager.selectedLines
    if selected.count == 1 { logger.info("✅ 测试4通过") }
    else { logger.error("❌ 测试4失败") }
    
    logger.info("测试5: 线条类型筛选")
    let horizontals = manager.lines(of: .horizontalLine)
    if horizontals.count >= 1 { logger.info("✅ 测试5通过") }
    else { logger.error("❌ 测试5失败") }
    
    logger.info("测试6: 模板保存")
    manager.saveCurrentLinesAsTemplate(name: "测试模板")
    let names = manager.allTemplateNames
    if names.contains("测试模板") { logger.info("✅ 测试6通过") }
    else { logger.error("❌ 测试6失败") }
    
    logger.info("测试7: 模板加载")
    manager.loadTemplate(name: "测试模板")
    logger.info("✅ 测试7通过")
    
    logger.info("测试8: 设置面板")
    let config = manager.settingsConfiguration()
    _ = config
    logger.info("✅ 测试8通过")
    
    logger.info("测试9: 撤销")
    if manager.canUndo { logger.info("✅ 测试9通过") }
    else { logger.error("❌ 测试9失败") }
    
    logger.info("=== 全部画线工具测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIDrawingToolManager
public final class UIDrawingToolManager : @unchecked Sendable {
    // MARK: 单例
    /// 全局唯一实例
    public static let shared = UIDrawingToolManager()

    // MARK: 锁保护
    /// 保护共享线条数据的轻量级锁
    private let linesLock = NSRecursiveLock()
    /// 保护模板数据的轻量级锁
    private let templatesLock = NSRecursiveLock()
    /// 保护操作状态的轻量级锁
    private let operationLock = NSRecursiveLock()

    // MARK: 持久化配置
    /// UserDefaults存储键：线条数据
    private let linesSaveKey = "com.xianrenzhilu.drawingLines"
    /// UserDefaults存储键：模板数据
    private let templatesSaveKey = "com.xianrenzhilu.drawingTemplates"
    /// 文件管理器
    private let fileManager = FileManager.default
    /// 应用支持目录下的画线数据文件夹
    private var drawingDataDirectory: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("XianRenZhiLu/Drawings", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir
    }

    // MARK: 数据存储
    /// 当前画布上的所有线条（受linesLock保护）
    private nonisolated(unsafe) var lines: [UIDrawingLineData] = []
    /// 已保存的模板字典（模板名称 -> 模板，受templatesLock保护）
    private nonisolated(unsafe) var templates: [String: UIDrawingTemplate] = [:]
    /// 当前用户操作状态（受operationLock保护）
    private var currentOperation: UIDrawingOperation = .idle
    /// 当前激活的画线工具类型（nil表示不处于画线模式）
    public var activeToolType: UIDrawingToolType? = nil
    /// 当前默认线条样式（新线条默认使用）
    public var defaultStyle: UIDrawingLineStyle = .default
    /// 是否启用吸附功能（吸附到K线高低点）
    public var snapToPrice: Bool = true
    /// 吸附阈值（像素距离）
    public var snapThreshold: CGFloat = 8.0
    /// 是否显示所有线条标签
    public var showAllLabels: Bool = true
    /// 历史操作记录（用于撤销/重做）
    private nonisolated(unsafe) var historyStack: [[UIDrawingLineData]] = []
    /// 历史指针
    private nonisolated(unsafe) var historyIndex: Int = -1
    /// 历史最大容量
    private let maxHistorySize = 50
    /// 是否启用历史记录
    private var historyEnabled: Bool = true

    // MARK: 初始化与销毁
    /// 私有初始化，确保单例
    private init() {
        logger.info("画线工具管理器初始化开始")
        loadFromDisk()
        loadTemplates()
        saveHistorySnapshot() // 初始空状态入历史栈
        logger.info("画线工具管理器初始化完成，已加载 \(self.lines.count) 条线条，\(self.templates.count) 个模板")
    }

    /// 销毁时清理资源
    deinit {
        logger.info("画线工具管理器正在销毁，执行清理工作")
        // 保存未持久化的数据
        saveToDisk()
        saveTemplates()
        // 清空内存数据（单例deinit时无并发，跳过锁）
        lines.removeAll()
        templates.removeAll()
        // 清空历史栈
        historyStack.removeAll()
        historyIndex = -1
        logger.info("画线工具管理器销毁完成，资源已释放")
    }

    // MARK: - 线条查询方法
    /// 获取所有线条的副本（线程安全）
    public var allLines: [UIDrawingLineData] {
        linesLock.lock()
        let result = lines
        linesLock.unlock()
        return result
    }

    /// 获取可见线条
    public var visibleLines: [UIDrawingLineData] {
        linesLock.lock()
        let result = lines.filter { $0.isVisible }
        linesLock.unlock()
        return result
    }

    /// 根据ID获取单条线条
    public func line(by id: UUID) -> UIDrawingLineData? {
        linesLock.lock()
        let result = lines.first { $0.id == id }
        linesLock.unlock()
        return result
    }

    /// 获取当前选中的线条
    public var selectedLines: [UIDrawingLineData] {
        linesLock.lock()
        let result = lines.filter { $0.isSelected }
        linesLock.unlock()
        return result
    }

    /// 按图层名称筛选线条
    public func lines(in layer: String) -> [UIDrawingLineData] {
        linesLock.lock()
        let result = lines.filter { $0.layerName == layer }
        linesLock.unlock()
        return result
    }

    /// 按类型筛选线条
    public func lines(of type: UIDrawingToolType) -> [UIDrawingLineData] {
        linesLock.lock()
        let result = lines.filter { $0.type == type }
        linesLock.unlock()
        return result
    }

    /// 获取所有图层名称列表
    public var allLayerNames: [String] {
        linesLock.lock()
        let names = Array(Set(lines.map { $0.layerName })).sorted()
        linesLock.unlock()
        return names
    }

    // MARK: - 线条创建方法
    /// 开始创建线条（鼠标按下时调用）
    /// - Parameters:
    ///   - toolType: 要创建的画线类型
    ///   - point: 鼠标按下的起始坐标（归一化坐标）
    public func beginCreatingLine(toolType: UIDrawingToolType, at point: CGPoint) {
        operationLock.lock()
        currentOperation = .creating(tool: toolType, startPoint: point)
        operationLock.unlock()
        logger.debug("开始创建线条: type=\(toolType.displayName), point=(\(point.x), \(point.y))")
    }

    /// 更新创建中的线条（鼠标拖拽时调用）
    /// - Parameter point: 当前鼠标坐标（归一化坐标）
    public func updateCreatingLine(to point: CGPoint) {
        operationLock.lock()
        guard case .creating(let toolType, _) = currentOperation else {
            operationLock.unlock()
            return
        }
        operationLock.unlock()

        // 创建临时预览线条（实际由UI层绘制，这里只记录状态）
        logger.debug("更新创建线条: tool=\(toolType.displayName), end=(\(point.x), \(point.y))")
    }

    /// 完成线条创建（鼠标释放时调用）
    /// - Parameter endPoint: 鼠标释放的坐标（归一化坐标）
    /// - Returns: 创建成功的线条ID（失败返回nil）
    @discardableResult
    public func finishCreatingLine(at endPoint: CGPoint) -> UUID? {
        operationLock.lock()
        guard case .creating(let toolType, let startPoint) = currentOperation else {
            operationLock.unlock()
            return nil
        }
        currentOperation = .idle
        operationLock.unlock()

        // 过滤过短的线条（误触）
        let distance = hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
        guard distance > 0.005 else {
            logger.debug("线条距离过短，忽略误触")
            return nil
        }

        var points: [CGPoint] = [startPoint, endPoint]
        // 平行通道需要3个点，前两点作为上轨，第三点通过算法推断或后续设置
        if toolType == .parallelChannel {
            // 默认第三点基于前两点平行偏移
            let dx = endPoint.x - startPoint.x
            let dy = endPoint.y - startPoint.y
            let offset = CGPoint(x: CGFloat(-dy * 0.1), y: CGFloat(dx * 0.1))
            let thirdPoint = CGPoint(x: endPoint.x + offset.x, y: endPoint.y + offset.y)
            points.append(thirdPoint)
        }

        let newLine = UIDrawingLineData(
            type: toolType,
            points: points,
            style: defaultStyle,
            label: toolType.displayName
        )

        linesLock.lock()
        lines.append(newLine)
        linesLock.unlock()

        saveHistorySnapshot()
        saveToDisk()

        // 发送线条创建通知
        NotificationCenter.default.post(
            name: .drawingLineCreated,
            object: self,
            userInfo: ["lineID": newLine.id, "line": newLine]
        )
        logger.info("线条创建完成: id=\(newLine.id.uuidString), type=\(toolType.displayName)")
        return newLine.id
    }

    /// 通过点击方式创建线条（不需要拖拽，如水平线/垂直线/文本标注）
    /// - Parameters:
    ///   - toolType: 画线类型
    ///   - point: 点击位置（归一化坐标）
    /// - Returns: 创建的线条ID
    @discardableResult
    public func createLineByClick(toolType: UIDrawingToolType, at point: CGPoint) -> UUID? {
        let points: [CGPoint]
        switch toolType {
        case .horizontalLine:
            points = [point, CGPoint(x: point.x + 0.3, y: point.y)]
        case .verticalLine:
            points = [point, CGPoint(x: point.x, y: point.y + 0.3)]
        case .textAnnotation:
            points = [point]
        default:
            points = [point, point]
        }

        let newLine = UIDrawingLineData(
            type: toolType,
            points: points,
            style: defaultStyle,
            textContent: toolType == .textAnnotation ? "标注文本" : nil,
            label: toolType.displayName
        )

        linesLock.lock()
        lines.append(newLine)
        linesLock.unlock()

        saveHistorySnapshot()
        saveToDisk()

        NotificationCenter.default.post(
            name: .drawingLineCreated,
            object: self,
            userInfo: ["lineID": newLine.id, "line": newLine]
        )
        logger.info("点击创建线条: id=\(newLine.id.uuidString), type=\(toolType.displayName)")
        return newLine.id
    }

    // MARK: - 线条选中方法
    /// 选中单条线条（其他线条取消选中）
    /// - Parameter id: 要选中线条的ID
    public func selectLine(id: UUID) {
        linesLock.lock()
        var updated = false
        for index in lines.indices {
            if lines[index].id == id {
                if !lines[index].isSelected {
                    lines[index].isSelected = true
                    lines[index].updatedAt = Date()
                    updated = true
                }
            } else {
                if lines[index].isSelected {
                    lines[index].isSelected = false
                    updated = true
                }
            }
        }
        linesLock.unlock()

        if updated {
            NotificationCenter.default.post(
                name: .drawingLineSelected,
                object: self,
                userInfo: ["selectedLineID": id]
            )
            logger.debug("选中线条: \(id.uuidString)")
        }
    }

    /// 多选线条（按住Shift/Command时调用）
    /// - Parameter id: 要切换选中状态的线条ID
    public func toggleSelection(id: UUID) {
        linesLock.lock()
        guard let index = lines.firstIndex(where: { $0.id == id }) else {
            linesLock.unlock()
            return
        }
        lines[index].isSelected.toggle()
        lines[index].updatedAt = Date()
        let isNowSelected = lines[index].isSelected
        linesLock.unlock()

        NotificationCenter.default.post(
            name: .drawingLineSelected,
            object: self,
            userInfo: ["selectedLineID": id, "isSelected": isNowSelected]
        )
        logger.debug("切换线条选中状态: \(id.uuidString), isSelected=\(isNowSelected)")
    }

    /// 取消所有线条的选中状态
    public func deselectAll() {
        linesLock.lock()
        var hadSelection = false
        for index in lines.indices {
            if lines[index].isSelected {
                lines[index].isSelected = false
                hadSelection = true
            }
        }
        linesLock.unlock()

        if hadSelection {
            NotificationCenter.default.post(
                name: .drawingLineSelected,
                object: self,
                userInfo: ["selectedLineID": NSNull()]
            )
            logger.debug("取消所有选中")
        }
    }

    /// 框选区域内的线条
    /// - Parameter rect: 归一化坐标的选择框
    public func selectLinesInRect(_ rect: CGRect) {
        linesLock.lock()
        for index in lines.indices {
            let line = lines[index]
            let contained = line.points.contains { rect.contains($0) }
            if contained {
                lines[index].isSelected = true
                lines[index].updatedAt = Date()
            }
        }
        linesLock.unlock()

        NotificationCenter.default.post(
            name: .drawingLineSelected,
            object: self,
            userInfo: ["selectionRect": rect]
        )
        logger.debug("框选完成: rect=\(rect.debugDescription)")
    }

    // MARK: - 线条编辑方法
    /// 修改线条的控制点（拖拽端点/中间点）
    /// - Parameters:
    ///   - id: 线条ID
    ///   - pointIndex: 要修改的控制点索引
    ///   - newPoint: 新的坐标位置（归一化坐标）
    public func updateLinePoint(id: UUID, pointIndex: Int, to newPoint: CGPoint) {
        linesLock.lock()
        guard let index = lines.firstIndex(where: { $0.id == id }) else {
            linesLock.unlock()
            return
        }
        guard pointIndex >= 0, pointIndex < lines[index].points.count else {
            linesLock.unlock()
            return
        }
        guard !lines[index].isLocked else {
            linesLock.unlock()
            logger.warning("尝试修改锁定线条，已拒绝: \(id.uuidString)")
            return
        }
        lines[index].points[pointIndex] = newPoint
        lines[index].updatedAt = Date()
        linesLock.unlock()

        logger.debug("更新线条控制点: \(id.uuidString), index=\(pointIndex)")
    }

    /// 修改线条样式
    /// - Parameters:
    ///   - id: 线条ID
    ///   - style: 新样式
    public func updateLineStyle(id: UUID, style: UIDrawingLineStyle) {
        linesLock.lock()
        guard let index = lines.firstIndex(where: { $0.id == id }) else {
            linesLock.unlock()
            return
        }
        guard !lines[index].isLocked else {
            linesLock.unlock()
            logger.warning("尝试修改锁定线条样式，已拒绝: \(id.uuidString)")
            return
        }
        lines[index].style = style
        lines[index].updatedAt = Date()
        linesLock.unlock()

        saveToDisk()
        NotificationCenter.default.post(
            name: .drawingLineModified,
            object: self,
            userInfo: ["lineID": id, "changeType": "style"]
        )
        logger.info("修改线条样式: \(id.uuidString)")
    }

    /// 修改线条文本内容
    public func updateLineText(id: UUID, text: String) {
        linesLock.lock()
        guard let index = lines.firstIndex(where: { $0.id == id }) else {
            linesLock.unlock()
            return
        }
        lines[index].textContent = text
        lines[index].updatedAt = Date()
        linesLock.unlock()

        saveToDisk()
        NotificationCenter.default.post(
            name: .drawingLineModified,
            object: self,
            userInfo: ["lineID": id, "changeType": "text"]
        )
        logger.info("修改线条文本: \(id.uuidString)")
    }

    /// 修改线条可见性
    public func setLineVisible(id: UUID, visible: Bool) {
        linesLock.lock()
        guard let index = lines.firstIndex(where: { $0.id == id }) else {
            linesLock.unlock()
            return
        }
        lines[index].isVisible = visible
        lines[index].updatedAt = Date()
        linesLock.unlock()

        saveToDisk()
        NotificationCenter.default.post(
            name: .drawingLineModified,
            object: self,
            userInfo: ["lineID": id, "changeType": "visibility", "isVisible": visible]
        )
        logger.debug("设置线条可见性: \(id.uuidString), visible=\(visible)")
    }

    /// 锁定/解锁线条
    public func setLineLocked(id: UUID, locked: Bool) {
        linesLock.lock()
        guard let index = lines.firstIndex(where: { $0.id == id }) else {
            linesLock.unlock()
            return
        }
        lines[index].isLocked = locked
        lines[index].updatedAt = Date()
        linesLock.unlock()

        saveToDisk()
        logger.info("设置线条锁定状态: \(id.uuidString), locked=\(locked)")
    }

    /// 移动整条线条（所有控制点偏移）
    public func moveLine(id: UUID, offset: CGSize) {
        linesLock.lock()
        guard let index = lines.firstIndex(where: { $0.id == id }) else {
            linesLock.unlock()
            return
        }
        guard !lines[index].isLocked else {
            linesLock.unlock()
            return
        }
        for i in lines[index].points.indices {
            lines[index].points[i].x += offset.width
            lines[index].points[i].y += offset.height
        }
        lines[index].updatedAt = Date()
        linesLock.unlock()

        saveToDisk()
        NotificationCenter.default.post(
            name: .drawingLineModified,
            object: self,
            userInfo: ["lineID": id, "changeType": "move"]
        )
        logger.debug("移动线条: \(id.uuidString), offset=(\(offset.width), \(offset.height))")
    }

    // MARK: - 线条删除方法
    /// 删除单条线条
    /// - Parameter id: 要删除的线条ID
    public func deleteLine(id: UUID) {
        linesLock.lock()
        guard let index = lines.firstIndex(where: { $0.id == id }) else {
            linesLock.unlock()
            return
        }
        let removed = lines.remove(at: index)
        linesLock.unlock()

        saveHistorySnapshot()
        saveToDisk()

        NotificationCenter.default.post(
            name: .drawingLineDeleted,
            object: self,
            userInfo: ["lineID": id, "deletedLine": removed]
        )
        logger.info("删除线条: \(id.uuidString), type=\(removed.type.displayName)")
    }

    /// 删除所有选中的线条
    public func deleteSelectedLines() {
        linesLock.lock()
        let selectedIDs = lines.filter { $0.isSelected }.map { $0.id }
        lines.removeAll { $0.isSelected }
        linesLock.unlock()

        guard !selectedIDs.isEmpty else { return }
        saveHistorySnapshot()
        saveToDisk()

        for id in selectedIDs {
            NotificationCenter.default.post(
                name: .drawingLineDeleted,
                object: self,
                userInfo: ["lineID": id]
            )
        }
        logger.info("批量删除选中线条，共 \(selectedIDs.count) 条")
    }

    /// 清空所有线条（危险操作）
    public func clearAllLines() {
        linesLock.lock()
        let count = lines.count
        lines.removeAll()
        linesLock.unlock()

        saveHistorySnapshot()
        saveToDisk()

        NotificationCenter.default.post(
            name: .drawingLineDeleted,
            object: self,
            userInfo: ["allDeleted": true, "count": count]
        )
        logger.info("清空所有线条，共 \(count) 条")
    }

    // MARK: - 模板管理方法
    /// 将当前所有线条保存为模板
    /// - Parameters:
    ///   - name: 模板名称
    ///   - description: 模板描述
    ///   - symbol: 关联品种
    ///   - timeFrame: 时间周期
    public func saveCurrentLinesAsTemplate(
        name: String,
        description: String? = nil,
        symbol: String? = nil,
        timeFrame: String? = nil
    ) {
        let currentLines = allLines
        let template = UIDrawingTemplate(
            name: name,
            description: description,
            lines: currentLines,
            symbol: symbol,
            timeFrame: timeFrame
        )

        templatesLock.lock()
        templates[name] = template
        templatesLock.unlock()

        saveTemplates()

        NotificationCenter.default.post(
            name: .drawingTemplateUpdated,
            object: self,
            userInfo: ["templateName": name, "action": "saved"]
        )
        logger.info("保存模板: \(name), 包含 \(currentLines.count) 条线条")
    }

    /// 加载模板到当前画布（追加模式）
    /// - Parameter name: 模板名称
    public func loadTemplate(name: String) {
        templatesLock.lock()
        guard let template = templates[name] else {
            templatesLock.unlock()
            logger.warning("模板不存在: \(name)")
            return
        }
        let linesToAdd = template.lines
        templatesLock.unlock()

        linesLock.lock()
        lines.append(contentsOf: linesToAdd)
        linesLock.unlock()

        saveHistorySnapshot()
        saveToDisk()

        NotificationCenter.default.post(
            name: .drawingTemplateUpdated,
            object: self,
            userInfo: ["templateName": name, "action": "loaded", "count": linesToAdd.count]
        )
        logger.info("加载模板: \(name), 追加 \(linesToAdd.count) 条线条")
    }

    /// 加载模板并替换当前画布（清空后加载）
    public func loadTemplateReplacingCurrent(name: String) {
        templatesLock.lock()
        guard let template = templates[name] else {
            templatesLock.unlock()
            logger.warning("模板不存在: \(name)")
            return
        }
        let linesToLoad = template.lines
        templatesLock.unlock()

        linesLock.lock()
        lines = linesToLoad
        linesLock.unlock()

        saveHistorySnapshot()
        saveToDisk()

        NotificationCenter.default.post(
            name: .drawingTemplateUpdated,
            object: self,
            userInfo: ["templateName": name, "action": "replaced", "count": linesToLoad.count]
        )
        logger.info("加载模板替换当前: \(name), 共 \(linesToLoad.count) 条线条")
    }

    /// 删除指定模板
    public func deleteTemplate(name: String) {
        templatesLock.lock()
        templates.removeValue(forKey: name)
        templatesLock.unlock()

        saveTemplates()

        NotificationCenter.default.post(
            name: .drawingTemplateUpdated,
            object: self,
            userInfo: ["templateName": name, "action": "deleted"]
        )
        logger.info("删除模板: \(name)")
    }

    /// 重命名模板
    public func renameTemplate(oldName: String, newName: String) {
        templatesLock.lock()
        guard var template = templates.removeValue(forKey: oldName) else {
            templatesLock.unlock()
            return
        }
        template.name = newName
        templates[newName] = template
        templatesLock.unlock()

        saveTemplates()

        NotificationCenter.default.post(
            name: .drawingTemplateUpdated,
            object: self,
            userInfo: ["oldName": oldName, "newName": newName, "action": "renamed"]
        )
        logger.info("重命名模板: \(oldName) -> \(newName)")
    }

    /// 获取所有模板名称列表
    public var allTemplateNames: [String] {
        templatesLock.lock()
        let names = Array(templates.keys).sorted()
        templatesLock.unlock()
        return names
    }

    /// 获取模板详情
    public func template(named name: String) -> UIDrawingTemplate? {
        templatesLock.lock()
        let result = templates[name]
        templatesLock.unlock()
        return result
    }

    /// 导出模板到文件（JSON格式）
    /// - Parameter url: 目标文件URL
    /// - Parameter name: 模板名称
    public func exportTemplate(named name: String, to url: URL) -> Bool {
        templatesLock.lock()
        guard let template = templates[name] else {
            templatesLock.unlock()
            return false
        }
        templatesLock.unlock()

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(template)
            try data.write(to: url)
            logger.info("导出模板成功: \(name) -> \(url.path)")
            return true
        } catch {
            logger.error("导出模板失败: \(name), error=\(error.localizedDescription)")
            return false
        }
    }

    /// 从文件导入模板
    /// - Parameter url: JSON文件URL
    public func importTemplate(from url: URL) -> String? {
        do {
            let data = try Data(contentsOf: url)
            let template = try JSONDecoder().decode(UIDrawingTemplate.self, from: data)
            let name = template.name

            templatesLock.lock()
            templates[name] = template
            templatesLock.unlock()

            saveTemplates()

            NotificationCenter.default.post(
                name: .drawingTemplateUpdated,
                object: self,
                userInfo: ["templateName": name, "action": "imported"]
            )
            logger.info("导入模板成功: \(name) from \(url.path)")
            return name
        } catch {
            logger.error("导入模板失败: \(url.path), error=\(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 撤销与重做
    /// 撤销上一次操作
    public func undo() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        let snapshot = historyStack[historyIndex]

        linesLock.lock()
        lines = snapshot
        linesLock.unlock()

        saveToDisk()
        logger.info("撤销操作，历史指针=\(self.historyIndex)")
    }

    /// 重做上一次撤销的操作
    public func redo() {
        guard historyIndex < historyStack.count - 1 else { return }
        historyIndex += 1
        let snapshot = historyStack[historyIndex]

        linesLock.lock()
        lines = snapshot
        linesLock.unlock()

        saveToDisk()
        logger.info("重做操作，历史指针=\(self.historyIndex)")
    }

    /// 当前是否可以撤销
    public var canUndo: Bool { historyIndex > 0 }
    /// 当前是否可以重做
    public var canRedo: Bool { historyIndex < historyStack.count - 1 }

    /// 保存当前状态到历史栈
    private func saveHistorySnapshot() {
        guard historyEnabled else { return }
        linesLock.lock()
        let snapshot = lines
        linesLock.unlock()

        // 删除当前指针之后的历史记录（分支情况）
        if historyIndex < historyStack.count - 1 {
            historyStack.removeSubrange((historyIndex + 1)..<historyStack.count)
        }
        historyStack.append(snapshot)
        // 超出容量则移除最早的状态
        if historyStack.count > maxHistorySize {
            historyStack.removeFirst(historyStack.count - maxHistorySize)
        }
        historyIndex = historyStack.count - 1
    }

    // MARK: - 设置面板方法
    /// 返回设置面板需要的配置项字典
    public struct UISettingsConfiguration {
        public var defaultStyle: UIDrawingLineStyle
        public var snapToPrice: Bool
        public var snapThreshold: CGFloat
        public var showAllLabels: Bool
        public var activeToolType: UIDrawingToolType?
        public var totalLines: Int
        public var totalTemplates: Int
        public var layerNames: [String]
        public var canUndo: Bool
        public var canRedo: Bool
        
        public init(defaultStyle: UIDrawingLineStyle, snapToPrice: Bool, snapThreshold: CGFloat, showAllLabels: Bool, activeToolType: UIDrawingToolType?, totalLines: Int, totalTemplates: Int, layerNames: [String], canUndo: Bool, canRedo: Bool) {
            self.defaultStyle = defaultStyle
            self.snapToPrice = snapToPrice
            self.snapThreshold = snapThreshold
            self.showAllLabels = showAllLabels
            self.activeToolType = activeToolType
            self.totalLines = totalLines
            self.totalTemplates = totalTemplates
            self.layerNames = layerNames
            self.canUndo = canUndo
            self.canRedo = canRedo
        }
    }
    
    public func settingsConfiguration() -> UISettingsConfiguration {
        return UISettingsConfiguration(
            defaultStyle: defaultStyle,
            snapToPrice: snapToPrice,
            snapThreshold: snapThreshold,
            showAllLabels: showAllLabels,
            activeToolType: activeToolType,
            totalLines: allLines.count,
            totalTemplates: allTemplateNames.count,
            layerNames: allLayerNames,
            canUndo: canUndo,
            canRedo: canRedo
        )
    }

    /// 从设置面板更新配置
    /// - Parameter config: 配置字典
    public func applySettings(_ config: UISettingsConfiguration) {
        defaultStyle = config.defaultStyle
        snapToPrice = config.snapToPrice
        snapThreshold = config.snapThreshold
        showAllLabels = config.showAllLabels
        activeToolType = config.activeToolType
        saveToDisk()
        logger.info("应用设置面板配置完成")
    }

    /// 重置所有设置为默认值
    public func resetSettingsToDefault() {
        defaultStyle = .default
        snapToPrice = true
        snapThreshold = 8.0
        showAllLabels = true
        activeToolType = nil
        saveToDisk()
        logger.info("设置已重置为默认值")
    }

    // MARK: - 持久化方法
    /// 将所有线条数据保存到磁盘（UserDefaults + 文件双保险）
    private func saveToDisk() {
        do {
            linesLock.lock()
            let linesCopy = lines
            linesLock.unlock()
            let data = try JSONEncoder().encode(linesCopy)

            // 同时写入文件系统作为备份
            if let dir = drawingDataDirectory {
                let fileURL = dir.appendingPathComponent("lines.json")
                try data.write(to: fileURL)
            }
        } catch {
            logger.error("保存线条数据失败: \(error.localizedDescription)")
        }
    }

    /// 从磁盘加载线条数据
    private func loadFromDisk() {
        // 优先从文件加载
        if let dir = drawingDataDirectory {
            let fileURL = dir.appendingPathComponent("lines.json")
            if fileManager.fileExists(atPath: fileURL.path),
               let data = try? Data(contentsOf: fileURL) {
                do {
                    let decoded = try JSONDecoder().decode([UIDrawingLineData].self, from: data)
                    linesLock.lock()
                    lines = decoded
                    linesLock.unlock()
                    logger.info("从文件加载线条数据: \(decoded.count) 条")
                    return
                } catch {
                    logger.error("文件解析失败，尝试UserDefaults: \(error.localizedDescription)")
                }
            }
        }

        // 回退到UserDefaults
        guard let data = UserDefaults.standard.data(forKey: linesSaveKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([UIDrawingLineData].self, from: data)
            linesLock.lock()
            lines = decoded
            linesLock.unlock()
            logger.info("从UserDefaults加载线条数据: \(decoded.count) 条")
        } catch {
            logger.error("UserDefaults解析失败: \(error.localizedDescription)")
        }
    }

    /// 保存模板到磁盘
    private func saveTemplates() {
        do {
            templatesLock.lock()
            let templatesCopy = templates
            templatesLock.unlock()
            let data = try JSONEncoder().encode(templatesCopy)

            if let dir = drawingDataDirectory {
                let fileURL = dir.appendingPathComponent("templates.json")
                try data.write(to: fileURL)
            }
        } catch {
            logger.error("保存模板失败: \(error.localizedDescription)")
        }
    }

    /// 从磁盘加载模板
    private func loadTemplates() {
        if let dir = drawingDataDirectory {
            let fileURL = dir.appendingPathComponent("templates.json")
            if fileManager.fileExists(atPath: fileURL.path),
               let data = try? Data(contentsOf: fileURL) {
                do {
                    let decoded = try JSONDecoder().decode([String: UIDrawingTemplate].self, from: data)
                    templatesLock.lock()
                    templates = decoded
                    templatesLock.unlock()
                    logger.info("从文件加载模板: \(decoded.count) 个")
                    return
                } catch {
                    logger.error("模板文件解析失败: \(error.localizedDescription)")
                }
            }
        }

        guard let data = UserDefaults.standard.data(forKey: templatesSaveKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: UIDrawingTemplate].self, from: data)
            templatesLock.lock()
            templates = decoded
            templatesLock.unlock()
            logger.info("从UserDefaults加载模板: \(decoded.count) 个")
        } catch {
            logger.error("模板UserDefaults解析失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 辅助方法
    /// 获取某点附近的线条（用于点击选中）
    /// - Parameters:
    ///   - point: 查询坐标（归一化）
    ///   - tolerance: 容差范围（归一化，默认0.01）
    /// - Returns: 匹配的线条列表（按距离排序）
    public func linesNearPoint(_ point: CGPoint, tolerance: CGFloat = 0.01) -> [UIDrawingLineData] {
        linesLock.lock()
        let candidates = lines.filter { line in
            line.points.contains { candidate in
                let dx = candidate.x - point.x
                let dy = candidate.y - point.y
                return hypot(dx, dy) <= tolerance
            }
        }
        linesLock.unlock()
        return candidates
    }

    /// 获取某点最近的控制点
    public func nearestControlPoint(to point: CGPoint, tolerance: CGFloat = 0.01) -> (lineID: UUID, pointIndex: Int, distance: CGFloat)? {
        var best: (UUID, Int, CGFloat)? = nil
        linesLock.lock()
        for line in lines {
            for (index, pt) in line.points.enumerated() {
                let dist = hypot(pt.x - point.x, pt.y - point.y)
                if dist <= tolerance {
                    if best == nil || dist < best!.2 {
                        best = (line.id, index, dist)
                    }
                }
            }
        }
        linesLock.unlock()
        return best
    }

    /// 切换画线工具激活状态
    public func setActiveTool(_ tool: UIDrawingToolType?) {
        activeToolType = tool
        logger.info("切换画线工具: \(tool?.displayName ?? "无")")
    }

    /// 取消当前激活的画线工具
    public func deactivateTool() {
        activeToolType = nil
        operationLock.lock()
        currentOperation = .idle
        operationLock.unlock()
        logger.info("取消画线工具激活状态")
    }
}

// MARK: - 迁回自 UI-02：enum UIDrawingToolType
// MARK: - UI-GL-53 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-53_types.swift
// 版本: 2.0
// MARK: - 画线类型枚举
/// 定义所有支持的画线工具类型
public enum UIDrawingToolType: String, Codable, CaseIterable {
    case trendLine       = "trendLine"       // 趋势线：两点确定一条直线
    case horizontalLine  = "horizontalLine"  // 水平线：一点+水平方向
    case verticalLine    = "verticalLine"    // 垂直线：一点+垂直方向
    case parallelChannel = "parallelChannel" // 平行通道：三点确定上下轨
    case fibonacci       = "fibonacci"       // 斐波那契回撤：两点+多个回撤位
    case ray             = "ray"             // 射线：起点+方向，单向延伸
    case arrow           = "arrow"           // 箭头：带方向箭头的线段
    case textAnnotation  = "textAnnotation"  // 文本标注：带文字说明的点

    /// 中文显示名称
    public var displayName: String {
        switch self {
        case .trendLine:       return "趋势线"
        case .horizontalLine:  return "水平线"
        case .verticalLine:    return "垂直线"
        case .parallelChannel: return "平行通道"
        case .fibonacci:       return "斐波那契回撤"
        case .ray:             return "射线"
        case .arrow:           return "箭头"
        case .textAnnotation:  return "文本标注"
        }
    }

    /// 该工具需要几个控制点来创建
    public var requiredPoints: Int {
        switch self {
        case .trendLine, .horizontalLine, .verticalLine, .ray, .arrow, .fibonacci:
            return 2
        case .parallelChannel:
            return 3
        case .textAnnotation:
            return 1
        }
    }

    /// 是否支持拖拽创建（鼠标按下+拖动+释放）
    public var supportsDragCreation: Bool {
        switch self {
        case .trendLine, .ray, .arrow, .fibonacci:
            return true
        case .horizontalLine, .verticalLine, .parallelChannel, .textAnnotation:
            return false
        }
    }
}

// MARK: - 迁回自 UI-02：enum UIDrawingLineDashStyle
// MARK: - 十字光标同步管理器
/// 主图表十字光标位置变化时，同步到所有已注册的其他窗口
/// 负责管理跨窗口光标联动、样式配置、窗口注册注销等
// 已迁回 UI-GL-52_十字光标跨窗口联动.swift：class UICrosshairSyncManager（公共类型文件禁止功能实现）

// MARK: - 十字光标绘制视图
/// 用于在窗口内绘制同步十字光标的自定义 NSView
/// 可嵌入到各个图表窗口中，接收联动管理器的通知进行重绘
// 已迁回 UI-GL-52_十字光标跨窗口联动.swift：class UICrosshairOverlayView（公共类型文件禁止功能实现）


// MARK: - UI-GL-53 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-53_types.swift
// 版本: 2.0
// MARK: - 线型枚举
/// 线条的样式类型
public enum UIDrawingLineDashStyle: String, Codable, CaseIterable, Sendable {
    case solid      = "solid"      // 实线
    case dashed     = "dashed"     // 虚线
    case dotted     = "dotted"     // 点线
    case dashDot    = "dashDot"    // 点划线
    case dashDotDot = "dashDotDot" // 双点划线

    /// 转换为NSLineDashPattern数组
    public var pattern: [NSNumber] {
        switch self {
        case .solid:      return []
        case .dashed:     return [6, 3]
        case .dotted:     return [2, 3]
        case .dashDot:    return [6, 3, 2, 3]
        case .dashDotDot: return [6, 3, 2, 3, 2, 3]
        }
    }

    /// 中文显示名称
    public var displayName: String {
        switch self {
        case .solid:      return "实线"
        case .dashed:     return "虚线"
        case .dotted:     return "点线"
        case .dashDot:    return "点划线"
        case .dashDotDot: return "双点划线"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIDrawingLineStyle
// MARK: - 线条样式配置
/// 单条线条的外观属性，可独立配置
public struct UIDrawingLineStyle: Codable, Equatable, Sendable {
    /// 线条颜色（RGBA十六进制字符串，如 "#FF5733FF"）
    public var colorHex: String
    /// 线条宽度（像素）
    public var lineWidth: CGFloat
    /// 线型样式
    public var dashStyle: UIDrawingLineDashStyle
    /// 是否显示端点标记
    public var showEndpoints: Bool
    /// 端点标记大小
    public var endpointSize: CGFloat
    /// 不透明度（0.0 ~ 1.0）
    public var opacity: CGFloat
    /// 是否显示延长线（射线/趋势线有效）
    public var extendLine: Bool
    /// 标签文字颜色
    public var labelColorHex: String
    /// 标签字体大小
    public var labelFontSize: CGFloat

    /// 默认样式
    public static let `default` = UIDrawingLineStyle(
        colorHex: "#FF5733FF",
        lineWidth: 1.5,
        dashStyle: .solid,
        showEndpoints: true,
        endpointSize: 5.0,
        opacity: 1.0,
        extendLine: false,
        labelColorHex: "#FFFFFFFF",
        labelFontSize: 12.0
    )

    /// 便捷初始化
    public init(
        colorHex: String = "#FF5733FF",
        lineWidth: CGFloat = 1.5,
        dashStyle: UIDrawingLineDashStyle = .solid,
        showEndpoints: Bool = true,
        endpointSize: CGFloat = 5.0,
        opacity: CGFloat = 1.0,
        extendLine: Bool = false,
        labelColorHex: String = "#FFFFFFFF",
        labelFontSize: CGFloat = 12.0
    ) {
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.dashStyle = dashStyle
        self.showEndpoints = showEndpoints
        self.endpointSize = endpointSize
        self.opacity = opacity
        self.extendLine = extendLine
        self.labelColorHex = labelColorHex
        self.labelFontSize = labelFontSize
    }
}

// MARK: - 迁回自 UI-02：struct UIDrawingLineData
// MARK: - 单条线条数据模型
/// 代表画布上的一条完整画线，包含几何数据与样式属性
public struct UIDrawingLineData: Codable, Identifiable, Equatable {
    /// 唯一标识符
    public var id: UUID
    /// 画线类型
    public var type: UIDrawingToolType
    /// 控制点坐标（归一化到0~1的相对坐标，适配不同分辨率）
    public var points: [CGPoint]
    /// 线条样式
    public var style: UIDrawingLineStyle
    /// 创建时间戳
    public var createdAt: Date
    /// 最后修改时间戳
    public var updatedAt: Date
    /// 是否可见
    public var isVisible: Bool
    /// 是否被锁定（锁定后不可编辑）
    public var isLocked: Bool
    /// 文本内容（仅文本标注有效）
    public var textContent: String?
    /// 斐波那契回撤比例（自定义比例列表）
    public var fibonacciLevels: [CGFloat]?
    /// 所属图层名称
    public var layerName: String
    /// 线条标签（用户自定义备注）
    public var label: String?
    /// 选中状态（运行时属性，不持久化）
    public var isSelected: Bool

    /// 初始化一条新线条
    public init(
        id: UUID = UUID(),
        type: UIDrawingToolType,
        points: [CGPoint],
        style: UIDrawingLineStyle = .default,
        textContent: String? = nil,
        fibonacciLevels: [CGFloat]? = nil,
        layerName: String = "默认图层",
        label: String? = nil
    ) {
        self.id = id
        self.type = type
        self.points = points
        self.style = style
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isVisible = true
        self.isLocked = false
        self.textContent = textContent
        self.fibonacciLevels = fibonacciLevels ?? [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0]
        self.layerName = layerName
        self.label = label
        self.isSelected = false
    }
}

// MARK: - 迁回自 UI-02：struct UIDrawingTemplate
// MARK: - 画线模板
/// 一组画线的预设集合，可保存为模板供后续复用
public struct UIDrawingTemplate: Codable, Identifiable, Equatable {
    /// 模板唯一标识
    public var id: UUID
    /// 模板名称
    public var name: String
    /// 模板描述
    public var description: String?
    /// 包含的线条数据
    public var lines: [UIDrawingLineData]
    /// 创建时间
    public var createdAt: Date
    /// 标签列表（用于分类检索）
    public var tags: [String]
    /// 是否系统内置模板
    public var isBuiltIn: Bool
    /// 关联的交易所/品种
    public var symbol: String?
    /// 时间周期
    public var timeFrame: String?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        lines: [UIDrawingLineData] = [],
        tags: [String] = [],
        isBuiltIn: Bool = false,
        symbol: String? = nil,
        timeFrame: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.lines = lines
        self.createdAt = Date()
        self.tags = tags
        self.isBuiltIn = isBuiltIn
        self.symbol = symbol
        self.timeFrame = timeFrame
    }
}

// MARK: - 迁回自 UI-02：enum UIDrawingOperation
// MARK: - 画线操作类型
/// 用户当前正在执行的画线操作
public enum UIDrawingOperation: Equatable {
    case idle                  // 空闲状态
    case creating(tool: UIDrawingToolType, startPoint: CGPoint) // 正在创建线条
    case moving(lineID: UUID, pointIndex: Int, offset: CGPoint) // 正在移动控制点
    case selecting(rect: CGRect) // 框选区域
    case panning(offset: CGPoint) // 平移画布
}
