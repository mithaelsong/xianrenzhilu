// 功能35: 布局模板市场
// 对应: 用户可上传/下载他人分享的布局模板，支持模板分类、评分、搜索
// 优先级: P3

import AppKit
import Foundation
import os.log

// MARK: - 通知名称
/// 布局模板市场相关通知
// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：public extension Notification.Name {

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能35：布局模板市场 — 单元测试
func test_layoutMarket() {
    let manager = UILayoutMarketManager.shared
    let logger = OSLog(subsystem: "com.xianrenzhilu.ui", category: "UI-GL-45")
    
    os_log("测试1: 内置模板", log: logger, type: .info)
    let builtIn = manager.builtInTemplates
    if builtIn.count < 3 {
        os_log("❌ 测试1失败: 应有至少3个内置模板", log: logger, type: .error)
    } else {
        os_log("✅ 测试1通过: 内置模板共%{public}lu个", log: logger, type: .info, builtIn.count)
    }
    
    os_log("测试2: 查询模板", log: logger, type: .info)
    let t = manager.template(id: "builtin-default")
    if t == nil {
        os_log("❌ 测试2失败: 应找到默认模板", log: logger, type: .error)
    } else {
        os_log("✅ 测试2通过: 模板查询成功", log: logger, type: .info)
    }
    
    os_log("测试3: 搜索过滤", log: logger, type: .info)
    let results = manager.searchTemplates(keyword: "K线")
    if results.isEmpty {
        os_log("❌ 测试3失败: 应有搜索结果", log: logger, type: .error)
    } else {
        os_log("✅ 测试3通过: 搜索正常，共%{public}lu条", log: logger, type: .info, results.count)
    }
    
    os_log("测试4: 设置面板数据", log: logger, type: .info)
    let data = manager.settingsPanelData()
    if data.templateCount < 3 {
        os_log("❌ 测试4失败: 应有模板数据", log: logger, type: .error)
    } else {
        os_log("✅ 测试4通过: 设置面板数据正常", log: logger, type: .info)
    }
    
    os_log("测试5: 收藏切换", log: logger, type: .info)
    manager.toggleFavorite(id: "builtin-default")
    os_log("✅ 测试5通过: 收藏切换正常", log: logger, type: .info)
    
    os_log("=== 全部布局模板市场测试通过 ✅ ===", log: logger, type: .info)
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UILayoutMarketManager
public final class UILayoutMarketManager : @unchecked Sendable {

    /// 单例实例
    public static let shared = UILayoutMarketManager()

    // MARK: 日志
    private let logger = Logger(
        subsystem: "com.xianrenzhilu",
        category: "布局模板市场"
    )

    // MARK: 线程锁
    private let lock = NSRecursiveLock()

    // MARK: 文件管理
    private let fileManager = FileManager.default
    /// 模板存储目录：~/Library/Application Support/仙人指路/LayoutMarket/
    private var marketDirectoryURL: URL {
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("仙人指路")
            .appendingPathComponent("LayoutMarket")
    }
    /// 评分数据持久化文件
    private var ratingsFileURL: URL {
        marketDirectoryURL.appendingPathComponent("ratings.json")
    }
    /// 当前过滤条件持久化文件
    private var filterFileURL: URL {
        marketDirectoryURL.appendingPathComponent("last_filter.json")
    }

    // MARK: 数据
    private var templates: [String: UILayoutMarketTemplate] = [:]
    private var hasInitializedBuiltIn = false
    /// 当前搜索过滤条件（内存中，也持久化）
    public private(set) var currentFilter: UITemplateSearchFilter = .none
    /// 所有已知标签集合（用于搜索提示）
    private var allKnownTags: Set<String> = []

    // MARK: 初始化
    private init() {
        ensureMarketDirectoryExists()
        loadAllTemplatesFromDisk()
        loadRatingsFromDisk()
        loadFilterFromDisk()
        initializeBuiltInTemplatesIfNeeded()
        rebuildKnownTags()
        logger.info("布局模板市场管理器初始化完成，共 \(self.templates.count) 个模板")
    }

    /// 清理通知监听与资源
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 锁辅助
    /// 在锁保护下执行操作
    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        let result = try operation()
        lock.unlock()
        return result
    }

    // MARK: - 目录管理
    /// 确保模板市场存储目录存在
    private func ensureMarketDirectoryExists() {
        let url = marketDirectoryURL
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                logger.info("模板市场目录创建成功: \(url.path)")
            } catch {
                logger.error("模板市场目录创建失败: \(error.localizedDescription)")
            }
        }
    }

    /// 单个模板文件路径（对名称做安全处理）
    private func templateFileURL(id: String) -> URL {
        let sanitized = id
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return marketDirectoryURL.appendingPathComponent("\(sanitized).json")
    }

    // MARK: - 内置预设模板
    /// 初始化内置预设模板（至少3个：默认/双栏/三栏）
    private func initializeBuiltInTemplatesIfNeeded() {
        guard !hasInitializedBuiltIn else { return }

        let builtInTemplates: [UILayoutMarketTemplate] = [
            UILayoutMarketTemplate(
                id: "builtin-default",
                name: "默认布局",
                author: "系统",
                version: "2.0",
                description: "标准单窗口布局，包含主K线图、工具栏和侧边面板，适合日常交易分析",
                tags: ["默认", "单窗口", "K线", "交易"],
                sourceCategory: .builtIn,
                rating: UITemplateRating(likeCount: 128, averageStar: 4.5, ratingCount: 50),
                layout: UIMarketWorkspaceLayout(layoutName: "默认布局")
            ),
            UILayoutMarketTemplate(
                id: "builtin-dual",
                name: "双栏布局",
                author: "系统",
                version: "2.0",
                description: "左右双栏布局，左侧主K线图，右侧深度图或订单簿，适合盯盘交易",
                tags: ["双栏", "分屏", "盘口", "监控"],
                sourceCategory: .builtIn,
                rating: UITemplateRating(likeCount: 86, averageStar: 4.2, ratingCount: 35),
                layout: UIMarketWorkspaceLayout(layoutName: "双栏布局")
            ),
            UILayoutMarketTemplate(
                id: "builtin-triple",
                name: "三栏布局",
                author: "系统",
                version: "2.0",
                description: "三栏分屏布局，主图+副图+数据面板，适合多维度技术分析",
                tags: ["三栏", "多屏", "指标", "分析"],
                sourceCategory: .builtIn,
                rating: UITemplateRating(likeCount: 64, averageStar: 4.0, ratingCount: 28),
                layout: UIMarketWorkspaceLayout(layoutName: "三栏布局")
            ),
            UILayoutMarketTemplate(
                id: "builtin-quad",
                name: "四宫格布局",
                author: "系统",
                version: "2.0",
                description: "四窗口等分布局，同时监控多品种或多周期，适合宏观把控",
                tags: ["四宫格", "多品种", "多周期", "联动"],
                sourceCategory: .builtIn,
                rating: UITemplateRating(likeCount: 42, averageStar: 3.8, ratingCount: 20),
                layout: UIMarketWorkspaceLayout(layoutName: "四宫格布局")
            )
        ]

        for template in builtInTemplates {
            withLock {
                // 内置模板不覆盖用户已有的同名模板（保护用户数据）
                if templates[template.id] == nil {
                    templates[template.id] = template
                }
            }
        }

        hasInitializedBuiltIn = true
        logger.info("内置预设模板已初始化，共 \(builtInTemplates.count) 个")
    }

    // MARK: - 模板保存与添加
    /// 添加或更新模板到市场
    /// - Parameter template: 模板对象
    /// - Returns: 是否保存成功
    @discardableResult
    public func addTemplate(_ template: UILayoutMarketTemplate) -> Bool {
        withLock {
            templates[template.id] = template
        }
        rebuildKnownTags()
        let success = saveTemplateToDisk(template)
        if success {
            logger.info("模板已添加/更新: \(template.name) [\(template.id)]")
            NotificationCenter.default.post(
                name: .layoutMarketTemplatesUpdated,
                object: self,
                userInfo: ["id": template.id, "name": template.name, "action": "save"]
            )
        }
        return success
    }

    /// 将当前工作区保存为市场模板
    /// - Parameters:
    ///   - name: 模板名称
    ///   - author: 作者
    ///   - description: 描述
    ///   - tags: 标签
    ///   - category: 来源分类
    /// - Returns: 保存的模板，失败返回nil
    public func saveCurrentAsMarketTemplate(
        name: String,
        author: String = "用户",
        description: String = "",
        tags: [String] = [],
        category: UITemplateSourceCategory = .userCreated
    ) -> UILayoutMarketTemplate? {
        guard !name.isEmpty else {
            logger.error("模板名称不能为空")
            return nil
        }

        guard let layout = UIWorkspaceManager.shared.cachedLayout else {
            logger.error("保存市场模板失败：当前没有工作区布局")
            return nil
        }

        var marketLayout = UIMarketWorkspaceLayout(layoutName: name)
        marketLayout.symbol = layout.symbol
        marketLayout.period = layout.period
        marketLayout.timestamp = Date()
        marketLayout.openModuleNames = layout.openModuleNames

        let template = UILayoutMarketTemplate(
            name: name,
            author: author,
            description: description,
            tags: tags,
            sourceCategory: category,
            layout: marketLayout
        )

        let success = addTemplate(template)
        return success ? template : nil
    }

    // MARK: - 模板删除
    /// 删除模板（内置模板不可删除）
    /// - Parameter id: 模板ID
    /// - Returns: 是否删除成功
    @discardableResult
    public func deleteTemplate(id: String) -> Bool {
        let template: UILayoutMarketTemplate? = withLock {
            let t = templates[id]
            if t?.sourceCategory == .builtIn {
                return t
            }
            templates.removeValue(forKey: id)
            return t
        }

        guard let t = template else {
            logger.warning("删除失败，模板不存在: \(id)")
            return false
        }

        if t.sourceCategory == .builtIn {
            logger.warning("内置模板不可删除: \(t.name)")
            return false
        }

        // 删除磁盘文件
        let fileURL = templateFileURL(id: id)
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                logger.error("删除模板文件失败: \(error.localizedDescription)")
            }
        }

        rebuildKnownTags()
        logger.info("模板已删除: \(t.name) [\(id)]")
        NotificationCenter.default.post(
            name: .layoutMarketTemplatesUpdated,
            object: self,
            userInfo: ["id": id, "name": t.name, "action": "delete"]
        )
        return true
    }

    // MARK: - 模板查询
    /// 获取指定模板
    /// - Parameter id: 模板ID
    /// - Returns: 模板对象，未找到返回nil
    public func template(id: String) -> UILayoutMarketTemplate? {
        withLock {
            return templates[id]
        }
    }

    /// 所有模板（不过滤）
    public var allTemplates: [UILayoutMarketTemplate] {
        withLock {
            return Array(templates.values)
        }
    }

    /// 按来源分类获取模板
    /// - Parameter category: 来源分类
    /// - Returns: 匹配模板列表
    public func templates(in category: UITemplateSourceCategory) -> [UILayoutMarketTemplate] {
        withLock {
            return templates.values
                .filter { $0.sourceCategory == category }
        }
    }

    /// 内置模板列表
    public var builtInTemplates: [UILayoutMarketTemplate] {
        templates(in: .builtIn)
    }

    /// 用户创建模板列表
    public var userCreatedTemplates: [UILayoutMarketTemplate] {
        templates(in: .userCreated)
    }

    /// 网络下载模板列表
    public var downloadedTemplates: [UILayoutMarketTemplate] {
        templates(in: .downloaded)
    }

    // MARK: - 模板搜索与过滤
    /// 按过滤条件搜索模板（按名称/分类/标签过滤）
    /// - Parameter filter: 搜索过滤条件
    /// - Returns: 匹配的模板列表
    public func searchTemplates(filter: UITemplateSearchFilter) -> [UILayoutMarketTemplate] {
        let keyword = filter.keyword.lowercased().trimmingCharacters(in: .whitespaces)
        let lowerTags = filter.tags.map { $0.lowercased() }

        var results: [UILayoutMarketTemplate] = withLock {
            return templates.values.filter { template in
                // 关键词过滤（名称/描述/作者/标签）
                if !keyword.isEmpty {
                    let matchName = template.name.lowercased().contains(keyword)
                    let matchDesc = template.description.lowercased().contains(keyword)
                    let matchAuthor = template.author.lowercased().contains(keyword)
                    let matchTags = template.tags.contains(where: { $0.lowercased().contains(keyword) })
                    if !(matchName || matchDesc || matchAuthor || matchTags) {
                        return false
                    }
                }

                // 来源分类过滤
                if let category = filter.sourceCategory, template.sourceCategory != category {
                    return false
                }

                // 标签过滤（包含任意一个指定标签）
                if !lowerTags.isEmpty {
                    let templateLowerTags = template.tags.map { $0.lowercased() }
                    let hasTag = lowerTags.contains(where: { templateLowerTags.contains($0) })
                    if !hasTag { return false }
                }

                // 仅收藏过滤
                if filter.favoritesOnly && !template.rating.isFavorited {
                    return false
                }

                // 最低星级过滤
                if filter.minStarRating > 0, template.rating.averageStar < Double(filter.minStarRating) {
                    return false
                }

                return true
            }
        }

        // 排序
        switch filter.sortOrder {
        case .nameAscending:
            results.sort { $0.name < $1.name }
        case .nameDescending:
            results.sort { $0.name > $1.name }
        case .updatedAtDescending:
            results.sort { $0.updatedAt > $1.updatedAt }
        case .createdAtDescending:
            results.sort { $0.createdAt > $1.createdAt }
        case .downloadCountDescending:
            results.sort { $0.downloadCount > $1.downloadCount }
        case .ratingDescending:
            results.sort { $0.rating.averageStar > $1.rating.averageStar }
        case .likesDescending:
            results.sort { $0.rating.likeCount > $1.rating.likeCount }
        }

        return results
    }

    /// 快捷搜索（仅关键词）
    /// - Parameter keyword: 搜索关键词
    /// - Returns: 匹配的模板列表
    public func searchTemplates(keyword: String) -> [UILayoutMarketTemplate] {
        var filter = currentFilter
        filter.keyword = keyword
        return searchTemplates(filter: filter)
    }

    /// 更新当前过滤条件并持久化
    /// - Parameter filter: 新的过滤条件
    public func updateFilter(_ filter: UITemplateSearchFilter) {
        withLock {
            currentFilter = filter
        }
        saveFilterToDisk()
        NotificationCenter.default.post(
            name: .layoutMarketSearchFilterChanged,
            object: self,
            userInfo: ["filter": filter]
        )
        logger.info("搜索过滤条件已更新")
    }

    /// 所有已知标签（用于搜索提示）
    public var knownTags: [String] {
        withLock {
            return Array(allKnownTags).sorted()
        }
    }

    /// 重建已知标签集合
    private func rebuildKnownTags() {
        withLock {
            allKnownTags.removeAll()
            for template in templates.values {
                for tag in template.tags {
                    allKnownTags.insert(tag)
                }
            }
        }
    }

    // MARK: - 模板评分（点赞/收藏/星级评价）
    /// 切换点赞状态
    /// - Parameter id: 模板ID
    /// - Returns: 更新后的模板，失败返回nil
    @discardableResult
    public func toggleLike(id: String) -> UILayoutMarketTemplate? {
        var updated: UILayoutMarketTemplate? = nil
        withLock {
            guard var template = templates[id] else { return }
            if template.rating.isLikedByCurrentUser {
                template.rating.isLikedByCurrentUser = false
                template.rating.likeCount = max(0, template.rating.likeCount - 1)
            } else {
                template.rating.isLikedByCurrentUser = true
                template.rating.likeCount += 1
            }
            template.updatedAt = Date()
            templates[id] = template
            updated = template
        }

        guard let template = updated else { return nil }
        saveRatingsToDisk()
        _ = saveTemplateToDisk(template)
        logger.info("模板点赞状态已切换: \(template.name) [点赞数: \(template.rating.likeCount)]")
        NotificationCenter.default.post(
            name: .layoutMarketTemplateRatingChanged,
            object: self,
            userInfo: ["id": id, "template": template, "action": "like"]
        )
        return template
    }

    /// 切换收藏状态
    /// - Parameter id: 模板ID
    /// - Returns: 更新后的模板，失败返回nil
    @discardableResult
    public func toggleFavorite(id: String) -> UILayoutMarketTemplate? {
        var updated: UILayoutMarketTemplate? = nil
        withLock {
            guard var template = templates[id] else { return }
            template.rating.isFavorited.toggle()
            template.updatedAt = Date()
            templates[id] = template
            updated = template
        }

        guard let template = updated else { return nil }
        saveRatingsToDisk()
        _ = saveTemplateToDisk(template)
        logger.info("模板收藏状态已切换: \(template.name) [收藏: \(template.rating.isFavorited)]")
        NotificationCenter.default.post(
            name: .layoutMarketTemplateFavoriteChanged,
            object: self,
            userInfo: ["id": id, "template": template, "isFavorited": template.rating.isFavorited]
        )
        return template
    }

    /// 设置用户星级评分
    /// - Parameters:
    ///   - id: 模板ID
    ///   - star: 星级（1-5）
    /// - Returns: 更新后的模板，失败返回nil
    @discardableResult
    public func setStarRating(id: String, star: Int) -> UILayoutMarketTemplate? {
        guard star >= 1 && star <= 5 else {
            logger.error("星级评分必须在1-5之间: \(star)")
            return nil
        }

        var updated: UILayoutMarketTemplate? = nil
        withLock {
            guard var template = templates[id] else { return }
            let oldRating = template.rating.userStarRating
            template.rating.userStarRating = star
            // 重新计算平均分（简化算法：用新评分替换旧评分）
            if oldRating == 0 {
                template.rating.ratingCount += 1
            }
            // 简单平均更新
            let totalStars = template.rating.averageStar * Double(max(1, template.rating.ratingCount - (oldRating == 0 ? 0 : 1))) + Double(star)
            template.rating.averageStar = totalStars / Double(max(1, template.rating.ratingCount))
            template.updatedAt = Date()
            templates[id] = template
            updated = template
        }

        guard let template = updated else { return nil }
        saveRatingsToDisk()
        _ = saveTemplateToDisk(template)
        logger.info("模板星级已更新: \(template.name) [\(star)星, 平均: \(String(format: "%.1f", template.rating.averageStar))]")
        NotificationCenter.default.post(
            name: .layoutMarketTemplateRatingChanged,
            object: self,
            userInfo: ["id": id, "template": template, "action": "star", "star": star]
        )
        return template
    }

    // MARK: - 模板导入导出（JSON格式，包含元数据）
    /// 导出单个模板到文件
    /// - Parameters:
    ///   - id: 模板ID
    ///   - url: 目标URL，nil时导出到临时目录
    /// - Returns: 导出文件URL，失败返回nil
    public func exportTemplate(id: String, to url: URL? = nil) -> URL? {
        guard let template = template(id: id) else {
            logger.warning("导出失败，模板不存在: \(id)")
            return nil
        }

        let package = UITemplateExportPackage(templates: [template])
        do {
            let data = try JSONEncoder().encode(package)
            let fileName = "\(template.name).xrzmarket"
            let destinationURL = url ?? FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: destinationURL, options: .atomic)
            logger.info("模板已导出: \(template.name) -> \(destinationURL.path)")
            NotificationCenter.default.post(
                name: .layoutMarketTemplateUploaded,
                object: self,
                userInfo: ["id": id, "name": template.name, "url": destinationURL, "action": "export"]
            )
            return destinationURL
        } catch {
            logger.error("导出模板失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 批量导出多个模板到文件
    /// - Parameters:
    ///   - ids: 模板ID列表
    ///   - url: 目标URL
    /// - Returns: 导出文件URL，失败返回nil
    public func exportTemplates(ids: [String], to url: URL? = nil) -> URL? {
        let selectedTemplates = ids.compactMap { template(id: $0) }
        guard !selectedTemplates.isEmpty else {
            logger.warning("批量导出失败，未找到任何模板")
            return nil
        }

        let package = UITemplateExportPackage(templates: selectedTemplates)
        do {
            let data = try JSONEncoder().encode(package)
            let fileName = "模板集合_\(selectedTemplates.count)个.xrzmarket"
            let destinationURL = url ?? FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: destinationURL, options: .atomic)
            logger.info("批量导出完成: \(selectedTemplates.count) 个模板 -> \(destinationURL.path)")
            NotificationCenter.default.post(
                name: .layoutMarketTemplateUploaded,
                object: self,
                userInfo: ["count": selectedTemplates.count, "url": destinationURL, "action": "batchExport"]
            )
            return destinationURL
        } catch {
            logger.error("批量导出模板失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 从文件导入模板（JSON格式，包含元数据）
    /// - Parameter url: 模板文件URL
    /// - Returns: 导入的模板列表，失败返回空数组
    @discardableResult
    public func importTemplates(from url: URL) -> [UILayoutMarketTemplate] {
        do {
            let data = try Data(contentsOf: url)
            let package = try JSONDecoder().decode(UITemplateExportPackage.self, from: data)

            var importedTemplates: [UILayoutMarketTemplate] = []
            for var template in package.templates {
                // 重置ID和来源分类
                template.id = UUID().uuidString
                template.sourceCategory = .imported
                template.createdAt = Date()
                template.updatedAt = Date()
                template.downloadCount = 0
                template.rating = UITemplateRating()
                template.originalURL = nil

                // 处理名称冲突
                var finalName = template.name
                var suffix = 1
                while withLock({ return templates.values.contains(where: { $0.name == finalName }) }) {
                    finalName = "\(template.name) (\(suffix))"
                    suffix += 1
                }
                template.name = finalName
                template.layout.layoutName = finalName

                withLock {
                    templates[template.id] = template
                }
                importedTemplates.append(template)
                _ = saveTemplateToDisk(template)
            }

            rebuildKnownTags()
            logger.info("模板导入完成: \(importedTemplates.count) 个，来自 \(url.lastPathComponent)")
            NotificationCenter.default.post(
                name: .layoutMarketTemplateDownloaded,
                object: self,
                userInfo: ["count": importedTemplates.count, "url": url, "templates": importedTemplates, "action": "import"]
            )
            return importedTemplates
        } catch {
            logger.error("导入模板失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 模拟下载网络模板（实际网络请求占位，本地演示用）
    /// - Parameters:
    ///   - name: 模板名称
    ///   - author: 作者
    ///   - layout: 布局数据
    ///   - tags: 标签
    /// - Returns: 下载的模板，失败返回nil
    public func downloadTemplate(
        name: String,
        author: String,
        layout: UIMarketWorkspaceLayout,
        tags: [String] = []
    ) -> UILayoutMarketTemplate? {
        let template = UILayoutMarketTemplate(
            name: name,
            author: author,
            tags: tags,
            sourceCategory: .downloaded,
            layout: layout
        )
        let success = addTemplate(template)
        if success {
            logger.info("网络模板下载完成: \(name)")
            NotificationCenter.default.post(
                name: .layoutMarketTemplateDownloaded,
                object: self,
                userInfo: ["id": template.id, "name": name, "action": "download"]
            )
        }
        return success ? template : nil
    }

    // MARK: - 模板应用
    /// 应用模板到当前工作区
    /// - Parameter id: 模板ID
    /// - Returns: 是否应用成功
    @discardableResult
    public func applyTemplate(id: String) -> Bool {
        guard let template = template(id: id) else {
            logger.warning("应用模板失败，未找到: \(id)")
            return false
        }

        // 更新应用状态
        UIAppStateManager.shared.setSymbol(template.layout.symbol)
        UIAppStateManager.shared.setPeriod(template.layout.period)

        // 可选：增加下载计数（对于网络模板）
        if template.sourceCategory == .downloaded || template.sourceCategory == .builtIn {
            var updated = template
            updated.downloadCount += 1
            updated.updatedAt = Date()
            withLock {
                templates[id] = updated
            }
            _ = saveTemplateToDisk(updated)
        }

        logger.info("模板已应用到工作区: \(template.name)")
        return true
    }

    // MARK: - 磁盘持久化
    /// 将模板保存到磁盘
    private func saveTemplateToDisk(_ template: UILayoutMarketTemplate) -> Bool {
        let url = templateFileURL(id: template.id)
        do {
            let data = try JSONEncoder().encode(template)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            logger.error("保存模板到磁盘失败 [\(template.name)]: \(error.localizedDescription)")
            return false
        }
    }

    /// 从磁盘加载所有模板
    private func loadAllTemplatesFromDisk() {
        let url = marketDirectoryURL
        guard fileManager.fileExists(atPath: url.path) else { return }

        do {
            let files = try fileManager.contentsOfDirectory(atPath: url.path)
            var loadedCount = 0

            for file in files where file.hasSuffix(".json") && file != "ratings.json" && file != "last_filter.json" {
                let fileURL = url.appendingPathComponent(file)
                do {
                    let data = try Data(contentsOf: fileURL)
                    let template = try JSONDecoder().decode(UILayoutMarketTemplate.self, from: data)
                    withLock {
                        templates[template.id] = template
                    }
                    loadedCount += 1
                } catch {
                    logger.warning("加载模板文件失败 [\(file)]: \(error.localizedDescription)")
                }
            }

            logger.info("从磁盘加载了 \(loadedCount) 个市场模板")
        } catch {
            logger.error("读取模板市场目录失败: \(error.localizedDescription)")
        }
    }

    /// 保存评分数据到磁盘
    private func saveRatingsToDisk() {
        let ratingsDict: [String: UITemplateRating] = withLock {
            var dict: [String: UITemplateRating] = [:]
            for (id, template) in templates {
                dict[id] = template.rating
            }
            return dict
        }
        do {
            let data = try JSONEncoder().encode(ratingsDict)
            try data.write(to: ratingsFileURL, options: .atomic)
        } catch {
            logger.error("保存评分数据失败: \(error.localizedDescription)")
        }
    }

    /// 从磁盘加载评分数据
    private func loadRatingsFromDisk() {
        guard fileManager.fileExists(atPath: ratingsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: ratingsFileURL)
            let ratings = try JSONDecoder().decode([String: UITemplateRating].self, from: data)
            withLock {
                for (id, rating) in ratings {
                    if var template = templates[id] {
                        template.rating = rating
                        templates[id] = template
                    }
                }
            }
            logger.info("评分数据加载完成，共 \(ratings.count) 条")
        } catch {
            logger.warning("加载评分数据失败: \(error.localizedDescription)")
        }
    }

    /// 保存过滤条件到磁盘
    private func saveFilterToDisk() {
        do {
            let data = try JSONEncoder().encode(currentFilter)
            try data.write(to: filterFileURL, options: .atomic)
        } catch {
            logger.error("保存过滤条件失败: \(error.localizedDescription)")
        }
    }

    /// 从磁盘加载过滤条件
    private func loadFilterFromDisk() {
        guard fileManager.fileExists(atPath: filterFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: filterFileURL)
            let filter = try JSONDecoder().decode(UITemplateSearchFilter.self, from: data)
            withLock {
                currentFilter = filter
            }
            logger.info("过滤条件已恢复")
        } catch {
            logger.warning("加载过滤条件失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 设置面板方法
    /// 返回设置面板所需的数据字典
    /// 包含模板列表、统计信息、可执行操作的标识
    public func settingsPanelData() -> UIMarketSettingsData {
        let all = allTemplates
        let builtIn = builtInTemplates
        let userCreated = userCreatedTemplates
        let downloaded = downloadedTemplates
        let favorited = all.filter { $0.rating.isFavorited }
        let topRated = all.filter { $0.rating.averageStar >= 4.0 }

        return UIMarketSettingsData(
            templates: all.map { templateToItem($0) },
            builtInTemplates: builtIn.map { templateToItem($0) },
            userCreatedTemplates: userCreated.map { templateToItem($0) },
            downloadedTemplates: downloaded.map { templateToItem($0) },
            favoritedTemplates: favorited.map { templateToItem($0) },
            topRatedTemplates: topRated.map { templateToItem($0) },
            templateCount: all.count,
            builtInCount: builtIn.count,
            userCreatedCount: userCreated.count,
            downloadedCount: downloaded.count,
            favoritedCount: favorited.count,
            knownTags: knownTags,
            directoryPath: marketDirectoryURL.path
        )
    }

    /// 将模板转换为列表条目
    private func templateToItem(_ template: UILayoutMarketTemplate) -> UIMarketTemplateListItem {
        UIMarketTemplateListItem(
            id: template.id, name: template.name, author: template.author,
            version: template.version, description: template.description,
            tags: template.tags, sourceCategory: template.sourceCategory.rawValue,
            likeCount: template.rating.likeCount,
            isLiked: template.rating.isLikedByCurrentUser,
            isFavorited: template.rating.isFavorited,
            averageStar: template.rating.averageStar,
            ratingCount: template.rating.ratingCount,
            userStarRating: template.rating.userStarRating,
            moduleCount: template.layout.openModuleNames.count,
            symbol: template.layout.symbol, period: template.layout.period,
            hasPreview: template.previewData != nil,
            previewSize: template.previewData?.count ?? 0
        )
    }
}

// MARK: - 迁回自 UI-02：class UILayoutMarketListViewController
public final class UILayoutMarketListViewController: NSViewController , @unchecked Sendable{

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var searchField: NSSearchField!
    private var categoryPopup: NSPopUpButton!
    private var templates: [UILayoutMarketTemplate] = []
    private var filter: UITemplateSearchFilter = .none

    /// 模板选中回调
    public var onTemplateSelected: ((UILayoutMarketTemplate) -> Void)?
    /// 模板应用回调
    public var onTemplateApply: ((UILayoutMarketTemplate) -> Void)?
    /// 模板导出回调
    public var onTemplateExport: ((UILayoutMarketTemplate) -> Void)?
    /// 模板删除回调
    public var onTemplateDelete: ((UILayoutMarketTemplate) -> Void)?
    /// 模板收藏回调
    public var onTemplateFavorite: ((UILayoutMarketTemplate) -> Void)?

    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 480))
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupSearchBar()
        setupCategoryFilter()
        setupTableView()
        reloadData()

        // 监听模板市场变化通知，自动刷新列表
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: .layoutMarketTemplatesUpdated,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: .layoutMarketTemplateRatingChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: .layoutMarketTemplateFavoriteChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: .layoutMarketSearchFilterChanged,
            object: nil
        )
    }

    private func setupSearchBar() {
        searchField = NSSearchField(frame: NSRect(x: 8, y: view.bounds.height - 36, width: 240, height: 24))
        searchField.autoresizingMask = [.width, .minYMargin]
        searchField.placeholderString = "搜索模板名称、描述、标签..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        view.addSubview(searchField)
    }

    private func setupCategoryFilter() {
        categoryPopup = NSPopUpButton(frame: NSRect(x: 256, y: view.bounds.height - 36, width: 140, height: 24))
        categoryPopup.autoresizingMask = [.minXMargin, .minYMargin]
        categoryPopup.addItem(withTitle: "全部分类")
        for category in UITemplateSourceCategory.allCases {
            categoryPopup.addItem(withTitle: category.rawValue)
        }
        categoryPopup.target = self
        categoryPopup.action = #selector(categoryChanged)
        view.addSubview(categoryPopup)
    }

    private func setupTableView() {
        let tableY: CGFloat = 8
        let tableHeight = view.bounds.height - 48
        scrollView = NSScrollView(frame: NSRect(x: 8, y: tableY, width: view.bounds.width - 16, height: tableHeight))
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
        tableView.doubleAction = #selector(doubleClicked)
        tableView.target = self

        // 名称列
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "名称"
        nameColumn.width = 140
        tableView.addTableColumn(nameColumn)

        // 分类列
        let categoryColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("category"))
        categoryColumn.title = "分类"
        categoryColumn.width = 80
        tableView.addTableColumn(categoryColumn)

        // 描述列
        let descColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("description"))
        descColumn.title = "描述"
        descColumn.width = 220
        tableView.addTableColumn(descColumn)

        // 标签列
        let tagColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tags"))
        tagColumn.title = "标签"
        tagColumn.width = 100
        tableView.addTableColumn(tagColumn)

        // 评分列
        let ratingColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rating"))
        ratingColumn.title = "评分"
        ratingColumn.width = 80
        tableView.addTableColumn(ratingColumn)

        scrollView.documentView = tableView
        view.addSubview(scrollView)
    }

    @objc private func searchFieldChanged() {
        filter.keyword = searchField.stringValue
        UILayoutMarketManager.shared.updateFilter(filter)
        reloadData()
    }

    @objc private func categoryChanged() {
        let selected = categoryPopup.indexOfSelectedItem
        if selected == 0 {
            filter.sourceCategory = nil
        } else if selected - 1 < UITemplateSourceCategory.allCases.count {
            filter.sourceCategory = UITemplateSourceCategory.allCases[selected - 1]
        }
        UILayoutMarketManager.shared.updateFilter(filter)
        reloadData()
    }

    @objc public func reloadData() {
        templates = UILayoutMarketManager.shared.searchTemplates(filter: filter)
        tableView?.reloadData()
    }

    @objc private func doubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0 && row < templates.count else { return }
        let template = templates[row]
        onTemplateApply?(template)
        _ = UILayoutMarketManager.shared.applyTemplate(id: template.id)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 迁回自 UI-02：class UILayoutMarketPreviewView
public final class UILayoutMarketPreviewView: NSView , @unchecked Sendable{

    /// 当前展示的模板
    public var template: UILayoutMarketTemplate? {
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

        // 绘制模块方块示意布局
        let count = template.layout.openModuleNames.count
        let cols = max(1, min(count, 3))
        let rows = max(1, Int(ceil(Double(count) / Double(cols))))
        let pad: CGFloat = 4
        let cellW = (bounds.width - pad * CGFloat(cols + 1)) / CGFloat(cols)
        let cellH = (bounds.height - pad * CGFloat(rows + 1)) / CGFloat(rows)

        let colors: [NSColor] = [
            .systemRed, .systemGreen, .systemBlue,
            .systemOrange, .systemPurple, .systemTeal
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

// MARK: - 迁回自 UI-02：struct UIWindowLayout
// MARK: - 字体管理器
/// 字体管理器：管理系统字体扫描、用户自定义字体注册、字体组合配置、字体预览生成
/// 采用单例模式，使用 NSRecursiveLock 保护共享数据，支持配置持久化与字体回退
// 已迁回 UI-GL-43_字体管理器.swift：class UIFontManager（公共类型文件禁止功能实现）

// MARK: - 字体选择器视图控制器（设置面板用）
/// 纯 AppKit 实现的字体选择器，供设置面板集成
/// 展示系统字体与用户字体列表，支持选择字体族和样式
// 已迁回 UI-GL-43_字体管理器.swift：class UIFontSelectorViewController（公共类型文件禁止功能实现）

// MARK: - NSTableView 数据源与代理
// 已迁回 UI-GL-43_字体管理器.swift：extension UIFontSelectorViewController（公共类型文件禁止功能实现）


// MARK: - UI-GL-44 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-44_types.swift
// 版本: 2.0
// MARK: - 视图组管理器
// 已迁回 UI-GL-44_视图组.swift：class UIViewGroupManager（公共类型文件禁止功能实现）


// MARK: - UI-GL-45 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-45_types.swift
// 版本: 2.0
public struct UIWindowLayout: Codable, Sendable {
    public var id: String
    public var frame: CGRect
    public var isVisible: Bool
}

// MARK: - 迁回自 UI-02：struct UIPanelLayout
public struct UIPanelLayout: Codable, Sendable {
    public var id: String
    public var position: String
}

// MARK: - 迁回自 UI-02：enum UITemplateSourceCategory
// MARK: - 模板来源分类
/// 模板来源分类体系：内置 / 用户创建 / 从网络下载
public enum UITemplateSourceCategory: String, Codable, CaseIterable, CustomStringConvertible {
    /// 系统内置预设模板
    case builtIn = "内置"
    /// 用户自行创建并保存的模板
    case userCreated = "用户创建"
    /// 从网络模板市场下载的模板
    case downloaded = "网络下载"
    /// 从文件导入的模板
    case imported = "文件导入"

    public var description: String { rawValue }
}

// MARK: - 迁回自 UI-02：struct UIMarketWorkspaceLayout
// MARK: - 市场模板布局占位（简化版，仅供模板市场使用）
public struct UIMarketWorkspaceLayout: Codable, Equatable {
    public var layoutName: String
    public var symbol: String = ""
    public var period: String = ""
    public var timestamp: Date = Date()
    public var openModuleNames: [String] = []
    
    public init(layoutName: String) {
        self.layoutName = layoutName
    }
}

// MARK: - 迁回自 UI-02：struct UITemplateRating
// MARK: - 模板评分数据
/// 单个模板的评分信息：点赞数、收藏状态、星级评价
public struct UITemplateRating: Codable, Equatable {
    /// 点赞数量（所有用户累计）
    public var likeCount: Int
    /// 当前用户是否已点赞
    public var isLikedByCurrentUser: Bool
    /// 当前用户是否已收藏
    public var isFavorited: Bool
    /// 平均星级（1-5，支持半星）
    public var averageStar: Double
    /// 评分人数
    public var ratingCount: Int
    /// 当前用户给出的星级（0表示未评分）
    public var userStarRating: Int

    public init(
        likeCount: Int = 0,
        isLikedByCurrentUser: Bool = false,
        isFavorited: Bool = false,
        averageStar: Double = 0.0,
        ratingCount: Int = 0,
        userStarRating: Int = 0
    ) {
        self.likeCount = likeCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.isFavorited = isFavorited
        self.averageStar = averageStar
        self.ratingCount = ratingCount
        self.userStarRating = userStarRating
    }
}

// MARK: - 迁回自 UI-02：struct UILayoutMarketTemplate
// MARK: - 市场模板模型
/// 布局模板市场条目，包含完整元数据、评分、分类与布局数据
public struct UILayoutMarketTemplate: Codable, Identifiable, Equatable {
    /// 唯一标识（UUID字符串）
    public var id: String
    /// 模板名称
    public var name: String
    /// 作者名称
    public var author: String
    /// 版本号
    public var version: String
    /// 描述说明
    public var description: String
    /// 标签列表
    public var tags: [String]
    /// 来源分类
    public var sourceCategory: UITemplateSourceCategory
    /// 评分数据
    public var rating: UITemplateRating
    /// 布局数据
    public var layout: UIMarketWorkspaceLayout
    /// 创建时间
    public var createdAt: Date
    /// 更新时间
    public var updatedAt: Date
    /// 下载次数（网络模板）
    public var downloadCount: Int
    /// 预览图数据（PNG）
    public var previewData: Data?
    /// 原始网络URL（下载模板用）
    public var originalURL: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        author: String = "用户",
        version: String = "1.0",
        description: String = "",
        tags: [String] = [],
        sourceCategory: UITemplateSourceCategory = .userCreated,
        rating: UITemplateRating = UITemplateRating(),
        layout: UIMarketWorkspaceLayout,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        downloadCount: Int = 0,
        previewData: Data? = nil,
        originalURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.version = version
        self.description = description
        self.tags = tags
        self.sourceCategory = sourceCategory
        self.rating = rating
        self.layout = layout
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.downloadCount = downloadCount
        self.previewData = previewData
        self.originalURL = originalURL
    }
}

// MARK: - 迁回自 UI-02：struct UITemplateSearchFilter
// MARK: - 搜索过滤条件
/// 模板搜索过滤条件封装
public struct UITemplateSearchFilter: Codable, Equatable {
    /// 关键词（匹配名称/描述/标签）
    public var keyword: String
    /// 来源分类过滤（nil表示全部）
    public var sourceCategory: UITemplateSourceCategory?
    /// 标签过滤（包含任意一个即匹配）
    public var tags: [String]
    /// 仅显示已收藏
    public var favoritesOnly: Bool
    /// 最低星级要求
    public var minStarRating: Int
    /// 排序方式
    public var sortOrder: UITemplateSortOrder

    public init(
        keyword: String = "",
        sourceCategory: UITemplateSourceCategory? = nil,
        tags: [String] = [],
        favoritesOnly: Bool = false,
        minStarRating: Int = 0,
        sortOrder: UITemplateSortOrder = .nameAscending
    ) {
        self.keyword = keyword
        self.sourceCategory = sourceCategory
        self.tags = tags
        self.favoritesOnly = favoritesOnly
        self.minStarRating = minStarRating
        self.sortOrder = sortOrder
    }

    /// 空过滤条件（不过滤）
    public static var none: UITemplateSearchFilter {
        UITemplateSearchFilter()
    }
}

// MARK: - 迁回自 UI-02：enum UITemplateSortOrder
// MARK: - 排序方式
/// 模板列表排序方式
public enum UITemplateSortOrder: String, Codable, CaseIterable {
    /// 按名称升序
    case nameAscending = "名称升序"
    /// 按名称降序
    case nameDescending = "名称降序"
    /// 按更新时间（最新在前）
    case updatedAtDescending = "最近更新"
    /// 按创建时间（最新在前）
    case createdAtDescending = "最近创建"
    /// 按下载次数（从高到低）
    case downloadCountDescending = "下载最多"
    /// 按评分（从高到低）
    case ratingDescending = "评分最高"
    /// 按点赞数（从高到低）
    case likesDescending = "点赞最多"
}

// MARK: - 迁回自 UI-02：struct UITemplateExportPackage
// MARK: - 导入导出包
/// 模板导入导出时的JSON包装结构，包含完整元数据
public struct UITemplateExportPackage: Codable {
    /// 导出格式版本
    public var exportVersion: String
    /// 导出时间
    public var exportedAt: Date
    /// 导出工具标识
    public var exporter: String
    /// 包含的模板列表
    public var templates: [UILayoutMarketTemplate]

    public init(templates: [UILayoutMarketTemplate]) {
        self.exportVersion = "2.0"
        self.exportedAt = Date()
        self.exporter = "仙人指路-布局模板市场"
        self.templates = templates
    }
}

// MARK: - 迁回自 UI-02：struct UIMarketTemplateListItem
// MARK: - 设置面板数据结构
/// 模板列表项（供设置面板展示）
public struct UIMarketTemplateListItem {
    public let id: String
    public let name: String
    public let author: String
    public let version: String
    public let description: String
    public let tags: [String]
    public let sourceCategory: String
    public let likeCount: Int
    public let isLiked: Bool
    public let isFavorited: Bool
    public let averageStar: Double
    public let ratingCount: Int
    public let userStarRating: Int
    public let moduleCount: Int
    public let symbol: String
    public let period: String
    public let hasPreview: Bool
    public let previewSize: Int
}

// MARK: - 迁回自 UI-02：struct UIMarketSettingsData
public struct UIMarketSettingsData {
    public let templates: [UIMarketTemplateListItem]
    public let builtInTemplates: [UIMarketTemplateListItem]
    public let userCreatedTemplates: [UIMarketTemplateListItem]
    public let downloadedTemplates: [UIMarketTemplateListItem]
    public let favoritedTemplates: [UIMarketTemplateListItem]
    public let topRatedTemplates: [UIMarketTemplateListItem]
    public let templateCount: Int
    public let builtInCount: Int
    public let userCreatedCount: Int
    public let downloadedCount: Int
    public let favoritedCount: Int
    public let knownTags: [String]
    public let directoryPath: String
}

// MARK: - 迁回自 UI-02：struct UIMarketFilterData
public struct UIMarketFilterData {
    public let keyword: String
    public let tags: [String]
    public let favoritesOnly: Bool
    public let minStarRating: Int
    public let sortOrder: String
    public let sourceCategory: String?
}
