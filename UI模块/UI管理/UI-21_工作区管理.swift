// 功能32B: 工作区 (Workspace) 管理
// 对应: 支持保存/加载多个完整布局方案，一键切换
// 优先级: P1

import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "32B_工作区管理")

// MARK: - 工作区方案管理器
/// 管理多个工作区方案，支持内置方案与自定义方案的增删查改，一键切换
// 类型 UIUIWorkspaceSchemeManager 已迁移到 UI-02_公共类型定义.swift

// MARK: - 通知名称扩展
extension Notification.Name {
    /// 工作区方案已切换
    public static let workspaceSchemeChanged = Notification.Name("com.xianrenzhilu.workspaceSchemeChanged")
}

// MARK: - 测试代码
#if false // DEBUG tests disabled in App target

/// 功能32B：工作区管理 — 单元测试
func test_workspaceScheme() {
    let manager = UIUIWorkspaceSchemeManager.shared
    var allPassed = true

    logger.info("测试1: 内置工作区数量")
    if UIUIWorkspaceSchemeManager.builtInSchemes.count < 3 {
        logger.error("❌ 测试1失败: 应有至少3个内置工作区，实际 \(UIUIWorkspaceSchemeManager.builtInSchemes.count)")
        allPassed = false
    } else {
        logger.info("✅ 测试1通过: 内置工作区 \(UIUIWorkspaceSchemeManager.builtInSchemes.count) 个")
    }

    logger.info("测试2: 获取工作区方案")
    let klineScheme = manager.scheme(named: "K线分析")
    if klineScheme == nil {
        logger.error("❌ 测试2失败: 应能获取「K线分析」方案")
        allPassed = false
    } else if klineScheme!.isBuiltIn != true {
        logger.error("❌ 测试2失败: 「K线分析」应为内置方案")
        allPassed = false
    } else {
        logger.info("✅ 测试2通过: 获取方案正常")
    }

    logger.info("测试3: 添加自定义方案")
    let custom = UIWorkspaceScheme(
        name: "我的布局",
        description: "自定义测试方案",
        layout: WorkspaceLayout(layoutName: "custom"),
        isBuiltIn: false
    )
    let addOK = manager.addCustomScheme(custom)
    if !addOK {
        logger.error("❌ 测试3失败: 添加自定义方案应成功")
        allPassed = false
    } else {
        logger.info("✅ 测试3通过: 添加自定义方案成功")
    }

    logger.info("测试4: 重复添加自定义方案")
    let duplicateOK = manager.addCustomScheme(custom)
    if duplicateOK {
        logger.error("❌ 测试4失败: 重复添加应返回 false")
        allPassed = false
    } else {
        logger.info("✅ 测试4通过: 重复添加已被拒绝")
    }

    logger.info("测试5: 添加空名称方案")
    let emptyScheme = UIWorkspaceScheme(
        name: "  ",
        description: "空名称",
        layout: WorkspaceLayout(layoutName: "empty"),
        isBuiltIn: false
    )
    let emptyOK = manager.addCustomScheme(emptyScheme)
    if emptyOK {
        logger.error("❌ 测试5失败: 空名称不应允许添加")
        allPassed = false
    } else {
        logger.info("✅ 测试5通过: 空名称已被拒绝")
    }

    logger.info("测试6: 切换方案")
    let switchOK = manager.switchToScheme(named: "我的布局")
    if !switchOK {
        logger.error("❌ 测试6失败: 切换到已存在的方案应成功")
        allPassed = false
    } else if manager.activeScheme?.name != "我的布局" {
        logger.error("❌ 测试6失败: 当前激活方案应为「我的布局」")
        allPassed = false
    } else {
        logger.info("✅ 测试6通过: 切换方案成功")
    }

    logger.info("测试7: 删除自定义方案")
    let delOK = manager.deleteScheme(named: "我的布局")
    if !delOK {
        logger.error("❌ 测试7失败: 删除自定义方案应成功")
        allPassed = false
    } else {
        logger.info("✅ 测试7通过: 删除自定义方案成功")
    }

    logger.info("测试8: 删除不存在的方案")
    let delFail = manager.deleteScheme(named: "不存在的方案")
    if delFail {
        logger.error("❌ 测试8失败: 删除不存在的方案应返回 false")
        allPassed = false
    } else {
        logger.info("✅ 测试8通过: 删除不存在方案已被正确处理")
    }

    if allPassed {
        logger.info("=== 全部工作区管理测试通过 ✅ ===")
    } else {
        logger.error("=== 部分工作区管理测试失败 ❌ ===")
    }
}
#endif

// MARK: - 独立编译存根（公共类型定义已移至 UI-02_公共类型定义.swift）


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIWorkspaceSchemeManager
public final class UIWorkspaceSchemeManager : @unchecked Sendable {
    // MARK: 单例
    public static let shared: UIWorkspaceSchemeManager = {
        let instance = UIWorkspaceSchemeManager()
        instance.loadFromDisk()
        return instance
    }()

    private init() {}

    // MARK: 内置工作区方案
    /// 系统预置的工作区方案，不可删除
    public static let builtInSchemes: [UIWorkspaceScheme] = [
        UIWorkspaceScheme(
            name: "K线分析",
            description: "默认K线分析布局，包含K线图、成交量、技术指标等模块",
            layout: UIWorkspaceLayout(layoutName: "kline"),
            isBuiltIn: true
        ),
        UIWorkspaceScheme(
            name: "量化回测",
            description: "量化回测专用布局，包含策略编辑器、回测结果、绩效分析等模块",
            layout: UIWorkspaceLayout(layoutName: "quant"),
            isBuiltIn: true
        ),
        UIWorkspaceScheme(
            name: "盘口监控",
            description: "盘口实时监控布局，包含买卖盘口、逐笔成交、深度图等模块",
            layout: UIWorkspaceLayout(layoutName: "order"),
            isBuiltIn: true
        ),
    ]

    // MARK: 自定义方案
    private var customSchemes: [UIWorkspaceScheme] = []

    /// 当前激活的工作区方案
    public private(set) var activeScheme: UIWorkspaceScheme?

    /// 所有方案（内置 + 自定义）
    public var allSchemes: [UIWorkspaceScheme] {
        return UIWorkspaceSchemeManager.builtInSchemes + customSchemes
    }

    /// 获取指定名称的方案
    public func scheme(named name: String) -> UIWorkspaceScheme? {
        return allSchemes.first(where: { $0.name == name })
    }

    // MARK: 增删改

    /// 添加自定义方案。如果名称已存在则返回 false。
    @discardableResult
    public func addCustomScheme(_ scheme: UIWorkspaceScheme) -> Bool {
        guard !scheme.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            logger.warning("添加自定义方案失败：名称为空")
            return false
        }
        guard !allSchemes.contains(where: { $0.name == scheme.name }) else {
            logger.warning("添加自定义方案失败：名称「\(scheme.name)」已存在")
            return false
        }
        var s = scheme
        s.isBuiltIn = false
        customSchemes.append(s)
        saveToDisk()
        logger.info("已添加自定义方案「\(scheme.name)」")
        return true
    }

    /// 删除自定义方案。内置方案不可删除。
    @discardableResult
    public func deleteScheme(named name: String) -> Bool {
        guard let index = customSchemes.firstIndex(where: { $0.name == name }) else {
            logger.warning("删除方案失败：未找到自定义方案「\(name)」")
            return false
        }
        customSchemes.remove(at: index)
        saveToDisk()
        logger.info("已删除自定义方案「\(name)」")
        return true
    }

    /// 更新自定义方案。如果名称不存在或为内置方案则返回 false。
    @discardableResult
    public func updateScheme(named name: String, with newScheme: UIWorkspaceScheme) -> Bool {
        guard let index = customSchemes.firstIndex(where: { $0.name == name }) else {
            logger.warning("更新方案失败：未找到自定义方案「\(name)」")
            return false
        }
        var s = newScheme
        s.isBuiltIn = false
        customSchemes[index] = s
        saveToDisk()
        logger.info("已更新自定义方案「\(name)」")
        return true
    }

    // MARK: 切换方案

    /// 切换到指定名称的方案。返回 false 表示未找到该方案。
    @discardableResult
    public func switchToScheme(named name: String) -> Bool {
        guard let scheme = scheme(named: name) else {
            logger.warning("切换方案失败：未找到方案「\(name)」")
            return false
        }
        activeScheme = scheme
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .workspaceSchemeChanged,
                object: nil,
                userInfo: ["schemeName": scheme.name]
            )
        }
        logger.info("已切换到方案「\(name)」")
        return true
    }

    // MARK: 持久化

    private static var storageURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appDir = paths[0].appendingPathComponent("仙人指路", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("workspace_schemes.json")
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(customSchemes)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            logger.error("保存自定义方案失败：\(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        let url = Self.storageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            customSchemes = try JSONDecoder().decode([UIWorkspaceScheme].self, from: data)
            logger.info("已加载 \(self.customSchemes.count) 个自定义方案")
        } catch {
            logger.error("加载自定义方案失败：\(error.localizedDescription)")
        }
    }
}
