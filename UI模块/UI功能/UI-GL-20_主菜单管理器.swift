// 功能15A: 主菜单管理器
// 对应: 管理应用主菜单栏，支持模块动态添加菜单项
// 优先级: P0

import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "15A_主菜单管理器")


// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能15A：主菜单管理器 — 单元测试
/// 覆盖：菜单项定义、注册/注销模块菜单、查询
func test_mainMenu() {
    print("\n🧪 测试1: MenuItemDefinition创建")
    let item = UIMenuItemDefinition(title: "测试", action: nil, keyEquivalent: "t", toolTip: "测试项")
    guard item.title == "测试" else {
        fatalError("❌ 测试1失败: title不匹配")
    }
    guard item.keyEquivalent == "t" else {
        fatalError("❌ 测试1失败: keyEquivalent不匹配")
    }
    guard item.toolTip == "测试项" else {
        fatalError("❌ 测试1失败: toolTip不匹配")
    }
    print("✅ 测试1通过: 菜单项定义创建正确")
    
    print("\n🧪 测试2: 分割线菜单项")
    let sep = UIMenuItemDefinition(title: "-", isSeparator: true)
    guard sep.isSeparator else {
        fatalError("❌ 测试2失败: isSeparator应为true")
    }
    print("✅ 测试2通过: 分割线菜单项正确")
    
    print("\n🧪 测试3: 子菜单定义")
    let subItems = [
        UIMenuItemDefinition(title: "子项1", keyEquivalent: "1"),
        UIMenuItemDefinition(title: "子项2", keyEquivalent: "2")
    ]
    let parent = UIMenuItemDefinition(title: "父菜单", submenu: subItems)
    guard parent.submenu?.count == 2 else {
        fatalError("❌ 测试3失败: 子菜单项数量应为2")
    }
    guard parent.submenu?[0].title == "子项1" else {
        fatalError("❌ 测试3失败: 子菜单项title不匹配")
    }
    print("✅ 测试3通过: 子菜单定义正确")
    
    print("\n🧪 测试4: 注册与注销菜单")
    let manager = UIMainMenuManager.shared
    let defs = [UIMenuItemDefinition(title: "打开面板", keyEquivalent: "p")]
    manager.registerModuleMenu(moduleName: "test_module", definitions: defs)
    
    var retrieved = manager.definitions(for: "test_module")
    guard retrieved.count == 1 else {
        fatalError("❌ 测试4失败: 注册后定义数应为1")
    }
    guard retrieved[0].title == "打开面板" else {
        fatalError("❌ 测试4失败: 注册后定义title不匹配")
    }
    
    manager.unregisterModuleMenu(moduleName: "test_module")
    retrieved = manager.definitions(for: "test_module")
    guard retrieved.isEmpty else {
        fatalError("❌ 测试4失败: 注销后定义应为空")
    }
    print("✅ 测试4通过: 注册与注销模块菜单正确")
    
    print("\n🧪 测试5: 未注册模块返回空")
    let empty = manager.definitions(for: "non_existent_module")
    guard empty.isEmpty else {
        fatalError("❌ 测试5失败: 未注册模块应返回空")
    }
    print("✅ 测试5通过: 未注册模块返回空")
    
    print("\n🧪 测试6: 构建主菜单")
    let mainMenu = manager.buildMainMenu()
    guard mainMenu.items.count == 6 else {
        fatalError("❌ 测试6失败: 主菜单应有6个子菜单，实际为\(mainMenu.items.count)")
    }
    let titles = mainMenu.items.map { $0.title }
    guard titles == ["仙人指路", "文件", "编辑", "视图", "窗口", "帮助"] else {
        fatalError("❌ 测试6失败: 主菜单标题不匹配: \(titles)")
    }
    print("✅ 测试6通过: 主菜单构建正确，6个子菜单")
    
    print("\n=== 全部主菜单管理器测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIMainMenuManager
public final class UIMainMenuManager : @unchecked Sendable {
    
    public static let shared = UIMainMenuManager()
    
    private var moduleMenus: [String: [UIMenuItemDefinition]] = [:]
    private let lock = NSRecursiveLock()
    
    private init() {}
    
    // MARK: - 构建主菜单
    
    /// 构建应用程序主菜单栏
    /// 包含6个内置菜单(应用/文件/编辑/视图/窗口/帮助)加上所有已注册模块的菜单
    /// - Returns: 完整的主菜单
    public func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu(title: "主菜单")
        
        // 应用菜单
        let appMenu = createAppMenu()
        let appMenuItem = NSMenuItem(title: "仙人指路", action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // 文件菜单
        let fileMenu = createFileMenu()
        let fileMenuItem = NSMenuItem(title: "文件", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)
        
        // 编辑菜单
        let editMenu = createEditMenu()
        let editMenuItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        // 视图菜单
        let viewMenu = createViewMenu()
        let viewMenuItem = NSMenuItem(title: "视图", action: nil, keyEquivalent: "")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)
        
        // 窗口菜单
        let windowMenu = createWindowMenu()
        let windowMenuItem = NSMenuItem(title: "窗口", action: nil, keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        
        // 帮助菜单
        let helpMenu = createHelpMenu()
        let helpMenuItem = NSMenuItem(title: "帮助", action: nil, keyEquivalent: "")
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        
        // 已注册模块的菜单（插入到视图菜单和窗口菜单之间）
        lock.lock()
        let moduleNames = Array(moduleMenus.keys).sorted()
        let moduleDict = moduleMenus
        lock.unlock()
        
        for name in moduleNames {
            if let defs = moduleDict[name], !defs.isEmpty {
                let moduleMenu = NSMenu(title: name)
                for def in defs {
                    let item: NSMenuItem
                    if def.isSeparator {
                        item = NSMenuItem.separator()
                    } else if let subDefs = def.submenu, !subDefs.isEmpty {
                        let subMenu = NSMenu(title: def.title)
                        for subDef in subDefs {
                            let subItem = NSMenuItem(title: subDef.title, action: subDef.action, keyEquivalent: subDef.keyEquivalent)
                            subItem.toolTip = subDef.toolTip
                            subMenu.addItem(subItem)
                        }
                        item = NSMenuItem(title: def.title, action: nil, keyEquivalent: "")
                        item.submenu = subMenu
                    } else {
                        item = NSMenuItem(title: def.title, action: def.action, keyEquivalent: def.keyEquivalent)
                        item.toolTip = def.toolTip
                    }
                    moduleMenu.addItem(item)
                }
                let moduleMenuItem = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                moduleMenuItem.submenu = moduleMenu
                mainMenu.addItem(moduleMenuItem)
            }
        }
        
        logger.info("已构建主菜单（\(moduleNames.count) 个模块菜单）")
        return mainMenu
    }
    
    // MARK: - 模块菜单注册
    
    /// 注册模块菜单
    /// 如果模块已注册过菜单会覆盖旧定义
    public func registerModuleMenu(moduleName: String, definitions: [UIMenuItemDefinition]) {
        lock.lock()
        let isUpdate = moduleMenus[moduleName] != nil
        moduleMenus[moduleName] = definitions
        lock.unlock()
        logger.info("模块 '\(moduleName)' 已\(isUpdate ? "更新" : "注册")菜单，共 \(definitions.count) 项")
    }
    
    /// 注销模块菜单
    public func unregisterModuleMenu(moduleName: String) {
        lock.lock()
        moduleMenus.removeValue(forKey: moduleName)
        lock.unlock()
        logger.info("模块 '\(moduleName)' 已注销菜单")
    }
    
    /// 获取模块的菜单项定义
    public func definitions(for moduleName: String) -> [UIMenuItemDefinition] {
        lock.lock()
        let defs = moduleMenus[moduleName] ?? []
        lock.unlock()
        return defs
    }
    
    // MARK: - 创建内置菜单
    
    private func createAppMenu() -> NSMenu {
        let menu = NSMenu(title: "仙人指路")
        menu.addItem(withTitle: "关于仙人指路", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "设置...", action: nil, keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出仙人指路", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }
    
    private func createFileMenu() -> NSMenu {
        let menu = NSMenu(title: "文件")
        menu.addItem(withTitle: "新建窗口", action: nil, keyEquivalent: "n")
        menu.addItem(withTitle: "打开...", action: nil, keyEquivalent: "o")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "保存布局", action: nil, keyEquivalent: "s")
        menu.addItem(withTitle: "另存布局...", action: nil, keyEquivalent: "S")
        return menu
    }
    
    private func createEditMenu() -> NSMenu {
        let menu = NSMenu(title: "编辑")
        menu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        return menu
    }
    
    private func createViewMenu() -> NSMenu {
        let menu = NSMenu(title: "视图")
        menu.addItem(withTitle: "切换主题", action: nil, keyEquivalent: "t")
        menu.addItem(withTitle: "显示/隐藏工具栏", action: nil, keyEquivalent: "T")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "进入/退出全屏", action: nil, keyEquivalent: "f")
        return menu
    }
    
    private func createWindowMenu() -> NSMenu {
        let menu = NSMenu(title: "窗口")
        menu.addItem(withTitle: "最小化", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "缩放", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "全部前置", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        return menu
    }
    
    private func createHelpMenu() -> NSMenu {
        let menu = NSMenu(title: "帮助")
        menu.addItem(withTitle: "仙人指路帮助", action: nil, keyEquivalent: "?")
        return menu
    }
}
