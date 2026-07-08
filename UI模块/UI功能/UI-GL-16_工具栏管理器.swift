// 功能13A: 工具栏管理器
// 对应: 管理主窗口工具栏，支持模块动态添加/移除按钮、间距、弹性空间
// 优先级: P0
// 版本: 2.0
// 类型定义已迁移至 UI-GL-16_types.swift

import Foundation
import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.xianrenzhilu.ui", category: "13A_工具栏管理器")

// 已迁移到 UI-02_公共类型定义.swift，原文件移除顶层 extension：extension String {

// MARK: - 测试代码
#if DEBUG
// import XCTest (disabled for executable target)

/// 功能13A：工具栏管理器 — 单元测试
/// 覆盖：按钮定义、注册/注销、标识符列表、定义查询
func test_toolbarManager() {
    print("\n🧪 测试1: UIToolbarButtonDefinition创建")
    let btn = UIToolbarButtonDefinition(
        identifier: "test_btn",
        label: "测试",
        iconName: "gearshape",
        tooltip: "测试按钮",
        isBordered: true,
        offsetX: -4,
        hoverScale: 1.1,
        hoverBackgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.8),
        normalBackgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.5)
    )
    guard btn.identifier == "test_btn" else {
        fatalError("❌ 测试1失败: identifier不匹配")
    }
    guard btn.label == "测试" else {
        fatalError("❌ 测试1失败: label不匹配")
    }
    guard btn.offsetX == -4 else {
        fatalError("❌ 测试1失败: offsetX不匹配")
    }
    guard btn.hoverScale == 1.1 else {
        fatalError("❌ 测试1失败: hoverScale不匹配")
    }
    print("✅ 测试1通过: 按钮定义创建正确，offsetX=-4, hoverScale=1.1")
    
    print("\n🧪 测试2: 注册按钮")
    let manager = UIToolbarManagerV2.shared
    manager.registerButton(btn, for: "test_module")
    guard let def = manager.definition(for: "test_btn") else {
        fatalError("❌ 测试2失败: 注册后无法找到定义")
    }
    guard def.label == "测试" else {
        fatalError("❌ 测试2失败: 定义label不匹配")
    }
    print("✅ 测试2通过: 注册按钮成功")
    
    print("\n🧪 测试3: 重复注册相同identifier")
    let btn2 = UIToolbarButtonDefinition(identifier: "test_btn", label: "覆盖测试", tooltip: nil, isBordered: false)
    manager.registerButton(btn2, for: "test_module")
    guard let updatedDef = manager.definition(for: "test_btn") else {
        fatalError("❌ 测试3失败: 注册后无法找到定义")
    }
    guard updatedDef.label == "覆盖测试" else {
        fatalError("❌ 测试3失败: 重复注册后label应更新为'覆盖测试'")
    }
    print("✅ 测试3通过: 重复注册覆盖旧按钮")
    
    print("\n🧪 测试4: 标识符列表")
    let ids = manager.allIdentifiers
    guard ids.contains("test_btn") else {
        fatalError("❌ 测试4失败: 标识符列表应包含test_btn")
    }
    guard ids.first == NSToolbarItem.Identifier.flexibleSpace.rawValue else {
        fatalError("❌ 测试4失败: 标识符列表第一个应为flexibleSpace")
    }
    print("✅ 测试4通过: 标识符列表正确")
    
    print("\n🧪 测试5: 不存在的identifier返回nil")
    let nonExist = manager.definition(for: "non_existent_btn")
    guard nonExist == nil else {
        fatalError("❌ 测试5失败: 不存在的identifier应返回nil")
    }
    print("✅ 测试5通过: 不存在的identifier返回nil")
    
    print("\n🧪 测试6: 注销模块按钮")
    manager.unregisterButtons(for: "test_module")
    let afterUnregister = manager.definition(for: "test_btn")
    guard afterUnregister == nil else {
        fatalError("❌ 测试6失败: 注销后不应找到定义")
    }
    print("✅ 测试6通过: 注销模块按钮成功")
    
    print("\n🧪 测试7: 点击回调闭包")
    var clickedIdentifier = ""
    manager.onButtonClicked = { id, _ in
        clickedIdentifier = id
    }
    manager.onButtonClicked?("click_btn", "点击测试")
    guard clickedIdentifier == "click_btn" else {
        fatalError("❌ 测试7失败: 回调未收到正确identifier")
    }
    print("✅ 测试7通过: 点击回调闭包工作正常")
    
    print("\n🧪 测试8: UIToolbarButtonContainer 偏移和悬停")
    let container = UIToolbarButtonContainer(
        frame: NSRect(x: 0, y: 0, width: 60, height: 36),
        offsetX: -4,
        hoverScale: 1.1,
        hoverBackgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.8),
        normalBackgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.5)
    )
    guard container.offsetX == -4 else {
        fatalError("❌ 测试8失败: offsetX不匹配")
    }
    guard container.hoverScale == 1.1 else {
        fatalError("❌ 测试8失败: hoverScale不匹配")
    }
    guard container.normalBackgroundColor != nil else {
        fatalError("❌ 测试8失败: normalBackgroundColor不应为nil")
    }
    print("✅ 测试8通过: UIToolbarButtonContainer 偏移和悬停配置正确")
    
    print("\n🧪 测试9: UIToolbarSizeMode 尺寸模式")
    let smallMode = UIToolbarSizeMode.small
    guard smallMode.buttonHeight == 28 else {
        fatalError("❌ 测试9失败: small模式高度应为28")
    }
    guard smallMode.buttonWidth == 44 else {
        fatalError("❌ 测试9失败: small模式宽度应为44")
    }
    guard smallMode.nsSizeMode == .small else {
        fatalError("❌ 测试9失败: small模式应映射到NSToolbarSizeMode.small")
    }
    let largeMode = UIToolbarSizeMode.large
    guard largeMode.buttonHeight == 48 else {
        fatalError("❌ 测试9失败: large模式高度应为48")
    }
    print("✅ 测试9通过: UIToolbarSizeMode 尺寸模式配置正确")
    
    print("\n🧪 测试10: UIToolbarDataItem 数据项定义")
    let item = UIToolbarDataItem(
        identifier: "BTC/USDT",
        title: "BTC/USDT",
        displayPrecision: 2,
        currentValue: 65432.50,
        changeValue: 2.35,
        isSelected: true
    )
    guard item.identifier == "BTC/USDT" else {
        fatalError("❌ 测试10失败: identifier不匹配")
    }
    guard item.formattedValue == "65432.50" else {
        fatalError("❌ 测试10失败: 格式化数值应为'65432.50'，实际是'\(item.formattedValue)'")
    }
    guard item.formattedChange == "+2.35%" else {
        fatalError("❌ 测试10失败: 格式化变化值应为'+2.35%'，实际是'\(item.formattedChange)'")
    }
    guard item.isSelected else {
        fatalError("❌ 测试10失败: isSelected应为true")
    }
    print("✅ 测试10通过: 数据项创建和格式化正确")
    
    print("\n🧪 测试11: 数据项变化值颜色")
    let upItem = UIToolbarDataItem(identifier: "ETH", title: "ETH", changeValue: 1.5)
    let downItem = UIToolbarDataItem(identifier: "SOL", title: "SOL", changeValue: -3.2)
    let flatItem = UIToolbarDataItem(identifier: "XRP", title: "XRP")
    guard upItem.changeColor == .systemGreen else {
        fatalError("❌ 测试11失败: 正向变化应显示绿色")
    }
    guard downItem.changeColor == .systemRed else {
        fatalError("❌ 测试11失败: 负向变化应显示红色")
    }
    guard flatItem.changeColor == .secondaryLabelColor else {
        fatalError("❌ 测试11失败: 无数据应显示次要标签色")
    }
    print("✅ 测试11通过: 数据项变化值颜色正确")
    
    print("\n🧪 测试12: 工具栏管理器项注册和选中")
    let item2 = UIToolbarDataItem(identifier: "ETH/USDT", title: "ETH/USDT")
    manager.registerItem(item2, for: "crypto_module")
    guard let foundItem = manager.item(for: "ETH/USDT") else {
        fatalError("❌ 测试12失败: 注册后应能找到项")
    }
    guard foundItem.identifier == "ETH/USDT" else {
        fatalError("❌ 测试12失败: 项identifier不匹配")
    }
    
    // 选中项
    var selectedIdentifier = ""
    manager.onItemSelected = { identifier in
        selectedIdentifier = identifier
    }
    manager.selectItem("ETH/USDT")
    guard selectedIdentifier == "ETH/USDT" else {
        fatalError("❌ 测试12失败: 选中回调未收到正确identifier")
    }
    guard manager.selectedItem?.identifier == "ETH/USDT" else {
        fatalError("❌ 测试12失败: selectedItem应为ETH/USDT")
    }
    print("✅ 测试12通过: 项注册和选中功能正确")
    
    print("\n🧪 测试13: 项数据更新")
    manager.updateItemData(identifier: "ETH/USDT", value: 3456.78, change: -1.25)
    guard let updatedItem = manager.item(for: "ETH/USDT") else {
        fatalError("❌ 测试13失败: 更新后应能找到项")
    }
    guard updatedItem.currentValue == 3456.78 else {
        fatalError("❌ 测试13失败: 数值更新不匹配")
    }
    guard updatedItem.changeValue == -1.25 else {
        fatalError("❌ 测试13失败: 变化值更新不匹配")
    }
    print("✅ 测试13通过: 项数据更新正确")
    
    print("\n🧪 测试14: 项注销")
    manager.unregisterItem("ETH/USDT", for: "crypto_module")
    let afterRemove = manager.item(for: "ETH/USDT")
    guard afterRemove == nil else {
        fatalError("❌ 测试14失败: 注销后应找不到项")
    }
    print("✅ 测试14通过: 项注销正确")
    
    print("\n🧪 测试14b: 边界情况 - 注销不存在的项")
    let removedNonExist = manager.unregisterItem("不存在的项", for: "test_module")
    guard removedNonExist == false else {
        fatalError("❌ 测试14b失败: 注销不存在的项应返回false")
    }
    print("✅ 测试14b通过: 注销不存在的项返回false")
    
    print("\n🧪 测试14c: 边界情况 - 更新不存在的项")
    let updatedNonExist = manager.updateItemData(identifier: "不存在的项", value: 100.0, change: 1.0)
    guard updatedNonExist == false else {
        fatalError("❌ 测试14c失败: 更新不存在的项应返回false")
    }
    print("✅ 测试14c通过: 更新不存在的项返回false")
    
    print("\n🧪 测试14d: 边界情况 - 选中不存在的项")
    let selectedNonExist = manager.selectItem("不存在的项")
    guard selectedNonExist == false else {
        fatalError("❌ 测试14d失败: 选中不存在的项应返回false")
    }
    print("✅ 测试14d通过: 选中不存在的项返回false")
    
    print("\n🧪 测试14e: 边界情况 - 重复注册覆盖")
    let item3 = UIToolbarDataItem(identifier: "重复项", title: "原始标题")
    manager.registerItem(item3, for: "test_module")
    let item3Updated = UIToolbarDataItem(identifier: "重复项", title: "更新标题")
    let registerResult = manager.registerItem(item3Updated, for: "test_module")
    guard registerResult == true else {
        fatalError("❌ 测试14e失败: 重复注册应返回true（覆盖成功）")
    }
    guard let foundUpdated = manager.item(for: "重复项") else {
        fatalError("❌ 测试14e失败: 重复注册后应能找到项")
    }
    guard foundUpdated.title == "更新标题" else {
        fatalError("❌ 测试14e失败: 重复注册应覆盖旧数据")
    }
    print("✅ 测试14e通过: 重复注册覆盖正确")
    
    print("\n🧪 测试14f: 边界情况 - 选中项被注销后selectedItem清理")
    let item4 = UIToolbarDataItem(identifier: "待注销项", title: "待注销")
    manager.registerItem(item4, for: "test_module")
    manager.selectItem("待注销项")
    guard manager.selectedItem != nil else {
        fatalError("❌ 测试14f失败: 选中后selectedItem不应为nil")
    }
    manager.unregisterItem("待注销项", for: "test_module")
    guard manager.selectedItem == nil else {
        fatalError("❌ 测试14f失败: 注销选中项后selectedItem应为nil")
    }
    print("✅ 测试14f通过: 选中项注销后selectedItem自动清理")
    let tab = UIToolbarTabItem(
        identifier: "BTC/USDT",
        title: "BTC/USDT",
        isSelected: true,
        isCloseable: true,
        badge: "2",
        metadata: ["price": "65432.50", "change": "+2.35%"]
    )
    guard tab.identifier == "BTC/USDT" else {
        fatalError("❌ 测试15失败: identifier不匹配")
    }
    guard tab.isSelected else {
        fatalError("❌ 测试15失败: isSelected应为true")
    }
    guard tab.isCloseable else {
        fatalError("❌ 测试15失败: isCloseable应为true")
    }
    guard tab.badge == "2" else {
        fatalError("❌ 测试15失败: badge应为'2'")
    }
    guard tab.metadata["price"] == "65432.50" else {
        fatalError("❌ 测试15失败: metadata价格不匹配")
    }
    print("✅ 测试15通过: UIToolbarTabItem 通用标签定义正确")
    
    print("\n🧪 测试16: UIToolbarTabView 标签视图创建")
    let tabView = UIToolbarTabView(
        frame: NSRect(x: 0, y: 0, width: 120, height: 28),
        tabItem: tab
    )
    guard tabView.tabItem.identifier == "BTC/USDT" else {
        fatalError("❌ 测试16失败: 标签视图identifier不匹配")
    }
    print("✅ 测试16通过: UIToolbarTabView 标签视图创建正确")
    
    print("\n🧪 测试17: UIToolbarTabStrip 标签条管理")
    let strip = UIToolbarTabStrip(frame: NSRect(x: 0, y: 0, width: 400, height: 32))
    
    // 添加标签（可以是币对、网页、图表等任何内容）
    let tab1 = UIToolbarTabItem(identifier: "BTC/USDT", title: "BTC")
    let tab2 = UIToolbarTabItem(identifier: "ETH/USDT", title: "ETH")
    let tab3 = UIToolbarTabItem(identifier: "chart-panel-1", title: "图表1", isCloseable: false)
    strip.addTab(tab1)
    strip.addTab(tab2)
    strip.addTab(tab3)
    guard strip.tabs.count == 3 else {
        fatalError("❌ 测试17失败: 应添加3个标签")
    }
    print("✅ 测试17通过: UIToolbarTabStrip 标签添加正确")
    
    print("\n🧪 测试18: 标签选中")
    var selectedIdentifier2 = ""
    strip.onTabSelected = { identifier in
        selectedIdentifier2 = identifier
    }
    strip.selectTab(identifier: "ETH/USDT")
    guard selectedIdentifier2 == "ETH/USDT" else {
        fatalError("❌ 测试18失败: 标签选中回调未收到正确identifier")
    }
    guard strip.tabs[1].tabItem.isSelected else {
        fatalError("❌ 测试18失败: ETH标签应被选中")
    }
    print("✅ 测试18通过: 标签选中功能正确")
    
    print("\n🧪 测试19: 标签关闭")
    var closedIdentifier = ""
    strip.onTabClosed = { identifier in
        closedIdentifier = identifier
    }
    strip.removeTab(identifier: "BTC/USDT")
    guard strip.tabs.count == 2 else {
        fatalError("❌ 测试19失败: 关闭后应剩2个标签")
    }
    guard closedIdentifier == "BTC/USDT" else {
        fatalError("❌ 测试19失败: 关闭回调未收到正确identifier")
    }
    print("✅ 测试19通过: 标签关闭功能正确")
    
    print("\n🧪 测试20: 标签更新（模拟价格更新）")
    let tab4 = UIToolbarTabItem(identifier: "SOL/USDT", title: "SOL", badge: "0")
    strip.addTab(tab4)
    strip.updateTab(identifier: "SOL/USDT", title: "SOL 155.50", badge: "+3.67%")
    guard let updatedTab = strip.tabs.first(where: { $0.tabItem.identifier == "SOL/USDT" }) else {
        fatalError("❌ 测试20失败: 应找到更新后的SOL标签")
    }
    guard updatedTab.tabItem.title == "SOL 155.50" else {
        fatalError("❌ 测试20失败: 标题应更新为'SOL 155.50'")
    }
    guard updatedTab.tabItem.badge == "+3.67%" else {
        fatalError("❌ 测试20失败: 角标应更新为'+3.67%'")
    }
    print("✅ 测试20通过: 标签更新正确")
    
    print("\n=== 全部工具栏管理器测试通过 ✅ ===")
}
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIToolbarManagerV2
public final class UIToolbarManagerV2 : @unchecked Sendable {
    deinit {
        logger.info("UIToolbarManagerV2 已释放")
    }

    public static let shared = UIToolbarManagerV2()

    private var registeredItems: [String: [UIToolbarButtonDefinition]] = [:]
    private var toolbar: NSToolbar?
    private var delegate: UIToolbarManagerDelegate?
    private let lock = NSRecursiveLock()
    public var onButtonClicked: ((String, String) -> Void)? // 点击回调闭包 (identifier, label)
    private var dataItems: [String: UIToolbarDataItem] = [:]  // 注册项标识 -> 数据定义（通用，不限于币对）
    private var selectedItemIdentifier: String? = nil                     // 当前选中的项
    public var onItemSelected: ((String) -> Void)?                        // 项选中回调（通用）

    /// 当前工具栏尺寸模式
    public var sizeMode: UIToolbarSizeMode = .regular {
        didSet {
            toolbar?.sizeMode = sizeMode.nsSizeMode
            logger.info("工具栏尺寸模式切换为: \(self.sizeMode)")
        }
    }

    private init() {}

    // MARK: - 工具栏设置

    /// 为主窗口设置液态玻璃工具栏
    /// - Parameter window: 目标窗口
    public func setupToolbar(for window: NSWindow) {
        let toolbar = NSToolbar(identifier: "main.toolbar")
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconAndLabel

        let delegate = UIToolbarManagerDelegate(manager: self)
        toolbar.delegate = delegate

        lock.lock()
        self.toolbar = toolbar
        self.delegate = delegate
        lock.unlock()

        window.toolbar = toolbar
        window.titlebarAppearsTransparent = true

        logger.info("已设置液态玻璃工具栏")
    }

    // MARK: - 工具栏高度设置

    /// 设置工具栏尺寸模式
    /// - Parameter mode: 尺寸模式
    public func setToolbarSizeMode(_ mode: UIToolbarSizeMode) {
        self.sizeMode = mode
        toolbar?.sizeMode = mode.nsSizeMode
        toolbar?.validateVisibleItems()
        logger.info("已设置工具栏尺寸模式: \(mode)")
    }

    /// 设置工具栏自定义高度（通过item尺寸控制）
    /// - Parameter height: 目标高度
    public func setToolbarHeight(_ height: CGFloat) {
        // NSToolbar自身高度由系统管理，但可通过item尺寸间接影响
        // 实际效果取决于系统实现
        logger.info("设置工具栏高度请求: \(height)，注意: NSToolbar高度由系统管理")
    }

    // MARK: - 币对管理

    /// 注册项到工具栏
    /// - Parameters:
    ///   - item: 项定义
    ///   - moduleName: 模块名称
    /// - Returns: 是否成功注册（如果已存在则覆盖并返回true）
    @discardableResult
    public func registerItem(_ item: UIToolbarDataItem, for moduleName: String) -> Bool {
        let identifier = "item.\(item.identifier)"
        lock.lock()
        let exists = dataItems[identifier] != nil
        dataItems[identifier] = item
        lock.unlock()

        if exists {
            logger.info("覆盖已存在的项: \(item.identifier)")
        } else {
            logger.info("注册新项到工具栏: \(item.identifier)")
        }

        // 创建对应的 UIToolbarButtonDefinition
        let btn = UIToolbarButtonDefinition(
            identifier: identifier,
            label: item.identifier,
            tooltip: "\(item.identifier) 当前数值: \(item.formattedValue)",
            isBordered: false,
            offsetX: 0,
            hoverScale: 1.05,
            hoverBackgroundColor: NSColor.controlBackgroundColor.withAlphaComponent(0.6),
            normalBackgroundColor: item.isSelected ? NSColor.controlBackgroundColor.withAlphaComponent(0.4) : nil
        )
        registerButton(btn, for: moduleName)
        return true
    }

    /// 注销项
    /// - Parameters:
    ///   - identifier: 项标识符
    ///   - moduleName: 模块名称
    /// - Returns: 是否成功注销（不存在返回false）
    @discardableResult
    public func unregisterItem(_ identifier: String, for moduleName: String) -> Bool {
        let fullId = "item.\(identifier)"
        lock.lock()
        let removed = dataItems.removeValue(forKey: fullId) != nil
        lock.unlock()

        if removed {
            toolbar?.validateVisibleItems()
            logger.info("注销项成功: \(identifier)")
        } else {
            logger.warning("注销项失败: \(identifier) 不存在")
        }
        return removed
    }

    /// 更新项数据
    /// - Parameters:
    ///   - identifier: 项标识符
    ///   - value: 新数值
    ///   - change: 变化值
    /// - Returns: 是否成功更新（不存在返回false）
    @discardableResult
    public func updateItemData(identifier: String, value: Double, change: Double) -> Bool {
        let fullId = "item.\(identifier)"
        lock.lock()
        guard var dataItem = dataItems[fullId] else {
            lock.unlock()
            logger.warning("更新项数据失败: \(identifier) 不存在")
            return false
        }
        dataItem.currentValue = value
        dataItem.changeValue = change
        dataItems[fullId] = dataItem
        lock.unlock()

        toolbar?.validateVisibleItems()
        logger.info("更新项数据成功: \(identifier) = \(value), 变化: \(change)%")
        return true
    }

    /// 选中项
    /// - Parameter identifier: 项标识符
    /// - Returns: 是否成功选中（不存在返回false）
    @discardableResult
    public func selectItem(_ identifier: String) -> Bool {
        let fullId = "item.\(identifier)"

        lock.lock()
        // 检查是否存在
        guard dataItems[fullId] != nil else {
            lock.unlock()
            logger.warning("选中项失败: \(identifier) 不存在")
            return false
        }

        selectedItemIdentifier = fullId
        for (id, var dataItem) in dataItems {
            dataItem.isSelected = (id == fullId)
            dataItems[id] = dataItem
        }
        lock.unlock()

        // 锁外调用回调和UI更新
        onItemSelected?(identifier)
        toolbar?.validateVisibleItems()
        logger.info("选中项成功: \(identifier)")
        return true
    }

    /// 获取当前选中的项
    public var selectedItem: UIToolbarDataItem? {
        lock.lock()
        guard let id = selectedItemIdentifier,
              let item = dataItems[id] else {
            // 如果标识符存在但项已不存在，清理标识符
            if selectedItemIdentifier != nil && dataItems[selectedItemIdentifier!] == nil {
                selectedItemIdentifier = nil
            }
            lock.unlock()
            return nil
        }
        lock.unlock()
        return item
    }

    /// 获取所有已注册的项
    public var allItems: [UIToolbarDataItem] {
        lock.lock()
        let items = Array(dataItems.values)
        lock.unlock()
        return items
    }

    // MARK: - 标签页管理

    private var tabStrip: UIToolbarTabStrip?                // 标签条实例
    public var onTabSelected: ((String) -> Void)?         // 标签选中回调

    /// 创建标签条并添加到工具栏
    /// - Parameter window: 目标窗口
    public func setupTabStrip(in window: NSWindow) {
        let strip = UIToolbarTabStrip(frame: NSRect(x: 0, y: 0, width: 400, height: 32))
        strip.onTabSelected = { [weak self] symbol in
            self?.onTabSelected?(symbol)
            logger.info("选中标签: \(symbol)")
        }
        strip.onTabClosed = { symbol in
            logger.info("关闭标签: \(symbol)")
        }

        lock.lock()
        self.tabStrip = strip
        lock.unlock()

        // 将标签条作为工具栏项添加
        let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("tabstrip"))
        item.label = ""
        item.view = strip

        toolbar?.insertItem(withItemIdentifier: NSToolbarItem.Identifier("tabstrip"), at: 0)
        logger.info("已设置标签条到工具栏")
    }

    /// 添加标签到标签条
    /// - Parameters:
    ///   - identifier: 唯一标识符
    ///   - title: 显示标题
    ///   - badge: 角标（可选）
    ///   - metadata: 附加数据（可选）
    public func addTab(identifier: String, title: String, badge: String? = nil, metadata: [String: String] = [:]) {
        let item = UIToolbarTabItem(
            identifier: identifier,
            title: title,
            badge: badge,
            metadata: metadata
        )

        lock.lock()
        tabStrip?.addTab(item)
        lock.unlock()

        logger.info("添加标签: \(identifier) - \(title)")
    }

    /// 移除标签
    /// - Parameter identifier: 标签标识符
    public func removeTab(identifier: String) {
        lock.lock()
        tabStrip?.removeTab(identifier: identifier)
        lock.unlock()

        logger.info("移除标签: \(identifier)")
    }

    /// 选中标签
    /// - Parameter identifier: 标签标识符
    public func selectTab(identifier: String) {
        lock.lock()
        tabStrip?.selectTab(identifier: identifier)
        lock.unlock()

        logger.info("选中标签: \(identifier)")
    }

    /// 更新标签显示
    /// - Parameters:
    ///   - identifier: 标签标识符
    ///   - title: 新标题（可选）
    ///   - badge: 新角标（可选）
    ///   - metadata: 新数据（可选）
    public func updateTab(identifier: String, title: String? = nil, badge: String? = nil, metadata: [String: String]? = nil) {
        lock.lock()
        tabStrip?.updateTab(identifier: identifier, title: title, badge: badge, metadata: metadata)
        lock.unlock()

        logger.info("更新标签: \(identifier)")
    }

    /// 获取当前所有标签的标识符
    public var allTabIdentifiers: [String] {
        lock.lock()
        let ids = tabStrip?.tabs.map { $0.tabItem.identifier } ?? []
        lock.unlock()
        return ids
    }

    /// 获取项定义
    /// - Parameter identifier: 项标识符
    /// - Returns: 项定义或nil
    public func item(for identifier: String) -> UIToolbarDataItem? {
        let fullId = "item.\(identifier)"
        lock.lock()
        let dataItem = dataItems[fullId]
        lock.unlock()
        return dataItem
    }

    // MARK: - 按钮注册

    /// 注册模块的工具栏按钮
    public func registerButton(_ button: UIToolbarButtonDefinition, for moduleName: String) {
        lock.lock()
        var items = registeredItems[moduleName] ?? []
        // 如果已有相同identifier的按钮，先移除旧的
        if let existingIndex = items.firstIndex(where: { $0.identifier == button.identifier }) {
            items.remove(at: existingIndex)
            logger.info("模块 '\(moduleName)' 更新按钮: \(button.label)（覆盖旧定义）")
        }
        items.append(button)
        registeredItems[moduleName] = items
        lock.unlock()

        toolbar?.validateVisibleItems()
        logger.info("模块 '\(moduleName)' 注册按钮: \(button.label)")
    }

    /// 批量注册按钮
    public func registerButtons(_ buttons: [UIToolbarButtonDefinition], for moduleName: String) {
        for button in buttons {
            registerButton(button, for: moduleName)
        }
    }

    /// 注销模块的所有工具栏按钮
    public func unregisterButtons(for moduleName: String) {
        lock.lock()
        registeredItems.removeValue(forKey: moduleName)
        lock.unlock()

        toolbar?.validateVisibleItems()
        logger.info("已注销模块 '\(moduleName)' 的所有按钮")
    }

    /// 所有已注册的标识符列表
    public var allIdentifiers: [String] {
        lock.lock()
        var ids: [String] = []
        // 默认分隔符
        ids.append(NSToolbarItem.Identifier.flexibleSpace.rawValue)
        for (_, buttons) in registeredItems {
            for btn in buttons {
                ids.append(btn.identifier)
            }
        }
        lock.unlock()
        return ids
    }

    /// 获取按钮定义
    public func definition(for identifier: String) -> UIToolbarButtonDefinition? {
        lock.lock()
        for (_, buttons) in registeredItems {
            if let btn = buttons.first(where: { $0.identifier == identifier }) {
                lock.unlock()
                return btn
            }
        }
        lock.unlock()
        return nil
    }
}

// MARK: - 迁回自 UI-02：class UIToolbarTabView
public final class UIToolbarTabView: NSView , @unchecked Sendable{
    public let tabItem: UIToolbarTabItem
    public var onSelected: ((UIToolbarTabView) -> Void)?
    public var onClosed: ((UIToolbarTabView) -> Void)?

    private var titleLabel: NSTextField!
    private var badgeLabel: NSTextField?
    private var closeButton: NSButton?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    public init(frame: NSRect, tabItem: UIToolbarTabItem) {
        self.tabItem = tabItem
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        self.tabItem = UIToolbarTabItem(identifier: "", title: "")
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 4
        updateAppearance()

        // 标题标签
        titleLabel = NSTextField(labelWithString: tabItem.title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = tabItem.isSelected ? .controlAccentColor : .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // 角标（可选）
        if let badge = tabItem.badge {
            badgeLabel = NSTextField(labelWithString: badge)
            badgeLabel?.font = NSFont.systemFont(ofSize: 9, weight: .bold)
            badgeLabel?.textColor = .white
            badgeLabel?.backgroundColor = .systemRed
            badgeLabel?.wantsLayer = true
            badgeLabel?.layer?.cornerRadius = 6
            badgeLabel?.alignment = .center
            badgeLabel?.translatesAutoresizingMaskIntoConstraints = false
            if let bl = badgeLabel {
                addSubview(bl)
            }
        }

        // 关闭按钮（可关闭时显示）
        if tabItem.isCloseable {
            closeButton = NSButton(frame: NSRect(x: 0, y: 0, width: 14, height: 14))
            closeButton?.title = "×"
            closeButton?.font = NSFont.systemFont(ofSize: 12, weight: .bold)
            closeButton?.isBordered = false
            closeButton?.target = self
            closeButton?.action = #selector(closeButtonClicked)
            closeButton?.translatesAutoresizingMaskIntoConstraints = false
            closeButton?.alphaValue = 0  // 默认隐藏
            if let cb = closeButton {
                addSubview(cb)
            }
        }

        // 布局
        var constraints: [NSLayoutConstraint] = [
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ]

        if let bl = badgeLabel {
            constraints.append(bl.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6))
            constraints.append(bl.centerYAnchor.constraint(equalTo: centerYAnchor))
            constraints.append(bl.widthAnchor.constraint(greaterThanOrEqualToConstant: 14))
            constraints.append(bl.heightAnchor.constraint(equalToConstant: 14))
        }

        if let cb = closeButton {
            let anchor = badgeLabel?.trailingAnchor ?? titleLabel.trailingAnchor
            constraints.append(cb.leadingAnchor.constraint(equalTo: anchor, constant: 6))
            constraints.append(cb.centerYAnchor.constraint(equalTo: centerYAnchor))
            constraints.append(cb.widthAnchor.constraint(equalToConstant: 14))
            constraints.append(cb.heightAnchor.constraint(equalToConstant: 14))
            constraints.append(cb.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8))
        } else {
            constraints.append(titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8))
        }

        NSLayoutConstraint.activate(constraints)
    }

    private func updateAppearance() {
        if tabItem.isSelected {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            titleLabel?.textColor = .controlAccentColor
        } else if isHovered {
            layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
            titleLabel?.textColor = .labelColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            titleLabel?.textColor = .secondaryLabelColor
        }
    }

    @objc private func closeButtonClicked() {
        onClosed?(self)
    }

    public override func mouseDown(with event: NSEvent) {
        // 选中标签
        onSelected?(self)
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
        closeButton?.animator().alphaValue = 1
        updateAppearance()
    }

    public override func mouseExited(with event: NSEvent) {
        isHovered = false
        closeButton?.animator().alphaValue = 0
        updateAppearance()
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea {
            removeTrackingArea(ta)
        }
        let ta = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(ta)
        trackingArea = ta
    }

    public func setSelected(_ selected: Bool) {
        var item = tabItem
        item.isSelected = selected
        updateAppearance()
    }
}

// MARK: - 迁回自 UI-02：class UIToolbarTabStrip
public final class UIToolbarTabStrip: NSView , @unchecked Sendable{
    public var tabs: [UIToolbarTabView] = []
    public var onTabSelected: ((String) -> Void)?
    public var onTabClosed: ((String) -> Void)?

    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private var selectedTabId: String?

    public override init(frame: NSRect) {
        super.init(frame: frame)
        setupScrollView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScrollView()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// 添加标签
    public func addTab(_ item: UIToolbarTabItem) {
        let tabView = UIToolbarTabView(frame: NSRect(x: 0, y: 0, width: 100, height: 28), tabItem: item)
        tabView.onSelected = { [weak self] tab in
            self?.selectTab(tab)
        }
        tabView.onClosed = { [weak self] tab in
            self?.removeTab(tab)
            self?.onTabClosed?(tab.tabItem.identifier)
        }

        if item.isSelected {
            selectedTabId = item.id.uuidString
        }

        tabs.append(tabView)
        contentView.addSubview(tabView)
        relayoutTabs()
    }

    /// 移除标签
    @discardableResult
    public func removeTab(_ tabView: UIToolbarTabView) -> Bool {
        guard let index = tabs.firstIndex(where: { $0 === tabView }) else { return false }

        if tabView.tabItem.id.uuidString == selectedTabId {
            // 选中标签被关闭，选中前一个
            if index > 0 {
                selectTab(tabs[index - 1])
            } else if tabs.count > 1 {
                selectTab(tabs[1])
            }
        }

        tabView.removeFromSuperview()
        tabs.remove(at: index)
        relayoutTabs()
        return true
    }

    /// 移除指定标识符标签
    @discardableResult
    public func removeTab(identifier: String) -> Bool {
        guard let tab = tabs.first(where: { $0.tabItem.identifier == identifier }) else { return false }
        return removeTab(tab)
    }

    /// 选中标签
    public func selectTab(_ tabView: UIToolbarTabView) {
        // 取消之前选中
        for tab in tabs {
            tab.setSelected(false)
        }

        // 设置新选中
        tabView.setSelected(true)
        selectedTabId = tabView.tabItem.id.uuidString

        onTabSelected?(tabView.tabItem.identifier)
    }

    /// 选中指定标识符
    public func selectTab(identifier: String) {
        guard let tab = tabs.first(where: { $0.tabItem.identifier == identifier }) else { return }
        selectTab(tab)
    }

    /// 更新标签显示
    public func updateTab(identifier: String, title: String? = nil, badge: String? = nil, metadata: [String: String]? = nil) {
        guard let tab = tabs.first(where: { $0.tabItem.identifier == identifier }) else { return }

        var newItem = tab.tabItem
        if let title = title {
            newItem = UIToolbarTabItem(
                identifier: identifier,
                title: title,
                isSelected: newItem.isSelected,
                isCloseable: newItem.isCloseable,
                badge: badge ?? newItem.badge,
                metadata: metadata ?? newItem.metadata
            )
        } else if badge != nil || metadata != nil {
            newItem = UIToolbarTabItem(
                identifier: identifier,
                title: newItem.title,
                isSelected: newItem.isSelected,
                isCloseable: newItem.isCloseable,
                badge: badge ?? newItem.badge,
                metadata: metadata ?? newItem.metadata
            )
        }

        let newTab = UIToolbarTabView(frame: tab.frame, tabItem: newItem)
        newTab.onSelected = tab.onSelected
        newTab.onClosed = tab.onClosed
        newTab.setSelected(tab.tabItem.isSelected)

        if let index = tabs.firstIndex(where: { $0 === tab }) {
            tab.removeFromSuperview()
            tabs[index] = newTab
            contentView.addSubview(newTab)
            relayoutTabs()
        }
    }

    /// 重新布局所有标签
    private func relayoutTabs() {
        var x: CGFloat = 0
        let tabHeight: CGFloat = 28
        let spacing: CGFloat = 2

        for tab in tabs {
            let tabWidth = calculateTabWidth(tab)
            tab.frame = NSRect(x: x, y: 0, width: tabWidth, height: tabHeight)
            x += tabWidth + spacing
        }

        // 更新内容视图大小
        contentView.frame = NSRect(x: 0, y: 0, width: max(x, bounds.width), height: tabHeight)
    }

    private func calculateTabWidth(_ tab: UIToolbarTabView) -> CGFloat {
        let baseWidth: CGFloat = 60
        let titleWidth = tab.tabItem.title.width(withFont: NSFont.systemFont(ofSize: 12))
        let badgeWidth: CGFloat
        if let badge = tab.tabItem.badge {
            badgeWidth = badge.width(withFont: NSFont.systemFont(ofSize: 9)) + 16
        } else {
            badgeWidth = 0
        }
        let closeWidth: CGFloat = tab.tabItem.isCloseable ? 20 : 0

        return baseWidth + titleWidth + badgeWidth + closeWidth
    }

    public override func layout() {
        super.layout()
        relayoutTabs()
    }
}

// MARK: - 迁回自 UI-02：extension String
extension String {
    func width(withFont font: NSFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: attributes)
        return size.width
    }
}

// MARK: - 迁回自 UI-02：class UIToolbarButtonContainer
public final class UIToolbarButtonContainer: NSView , @unchecked Sendable{
    public let offsetX: CGFloat
    public let hoverScale: CGFloat
    public let hoverBackgroundColor: NSColor?
    public let normalBackgroundColor: NSColor?
    private var trackingArea: NSTrackingArea?
    private var iconView: NSImageView?
    public var target: AnyObject?
    public var action: Selector?

    public init(frame: NSRect, offsetX: CGFloat = 0, hoverScale: CGFloat = 1.1,
                hoverBackgroundColor: NSColor? = nil, normalBackgroundColor: NSColor? = nil) {
        self.offsetX = offsetX
        self.hoverScale = hoverScale
        self.hoverBackgroundColor = hoverBackgroundColor
        self.normalBackgroundColor = normalBackgroundColor
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        self.offsetX = 0
        self.hoverScale = 1.1
        self.hoverBackgroundColor = nil
        self.normalBackgroundColor = nil
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        wantsLayer = true
        layer?.cornerRadius = frame.height / 2
        if let bg = normalBackgroundColor {
            layer?.backgroundColor = bg.cgColor
        }
        // 初始偏移
        updateTransform(scale: 1.0)
    }

    private func updateTransform(scale: CGFloat) {
        var t = CATransform3DMakeTranslation(offsetX, 0, 0)
        t = CATransform3DScale(t, scale, scale, 1.0)
        layer?.transform = t
    }

    public func setIcon(_ image: NSImage?) {
        if let iv = iconView {
            iv.removeFromSuperview()
        }
        guard let image = image else { return }
        let iv = NSImageView(frame: bounds)
        iv.image = image
        iv.imageScaling = .scaleProportionallyDown
        iv.autoresizingMask = [.width, .height]
        addSubview(iv)
        iconView = iv
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea {
            removeTrackingArea(ta)
        }
        let ta = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(ta)
        trackingArea = ta
    }

    public override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            if let bg = hoverBackgroundColor {
                self.animator().layer?.backgroundColor = bg.cgColor
            }
            self.updateTransform(scale: hoverScale)
        }, completionHandler: nil)
    }

    public override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            if let bg = normalBackgroundColor {
                self.animator().layer?.backgroundColor = bg.cgColor
            }
            self.updateTransform(scale: 1.0)
        }, completionHandler: nil)
    }

    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let target = target, let action = action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    public override func layout() {
        super.layout()
        layer?.cornerRadius = frame.height / 2
    }
}

// MARK: - 迁回自 UI-02：class UIToolbarManagerDelegate
private class UIToolbarManagerDelegate: NSObject, NSToolbarDelegate , @unchecked Sendable{

    weak var manager: UIToolbarManagerV2?

    init(manager: UIToolbarManagerV2) {
        self.manager = manager
        super.init()
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        guard let manager = manager else { return [] }
        return manager.allIdentifiers.map { NSToolbarItem.Identifier($0) }
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let manager = manager,
              let def = manager.definition(for: itemIdentifier.rawValue) else {
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = def.label
        item.paletteLabel = def.label
        item.toolTip = def.tooltip
        item.isBordered = def.isBordered

        // 液态玻璃风格
        if let iconName = def.iconName {
            item.image = NSImage(systemSymbolName: iconName, accessibilityDescription: def.label)
        }

        // 使用 UIToolbarButtonContainer 替代 NSButton，支持偏移和悬停效果
        let container = UIToolbarButtonContainer(
            frame: NSRect(x: 0, y: 0, width: 60, height: 36),
            offsetX: def.offsetX,
            hoverScale: def.hoverScale,
            hoverBackgroundColor: def.hoverBackgroundColor,
            normalBackgroundColor: def.normalBackgroundColor
        )
        container.setIcon(item.image)
        container.target = self
        container.action = #selector(toolbarButtonClicked(_:))
        item.view = container

        return item
    }

    @objc private func toolbarButtonClicked(_ sender: NSButton) {
        // 通过manager的闭包回调通知模块
        guard let manager = manager else { return }
        // 查找按钮对应的identifier
        let identifier = sender.identifier?.rawValue ?? ""
        let label = sender.toolTip ?? ""
        manager.onButtonClicked?(identifier, label)
        logger.info("按钮被点击: \(label)")
    }
}

// MARK: - 迁回自 UI-02：struct UIToolbarButtonDefinition
// MARK: - UI-GL-16 批量去重合并（顶层解析）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-16_types.swift
// 版本: 2.0
// MARK: - 工具栏按钮定义
/// 工具栏按钮定义
public struct UIToolbarButtonDefinition {
    public let identifier: String
    public let label: String
    public let iconName: String?    // SF Symbol名
    public let tooltip: String?
    public let isBordered: Bool
    public let offsetX: CGFloat     // 水平偏移量（解决工具栏布局忽略x坐标的问题）
    public let hoverScale: CGFloat // 悬停放大比例
    public let hoverBackgroundColor: NSColor? // 悬停背景色
    public let normalBackgroundColor: NSColor? // 正常背景色

    public init(identifier: String, label: String, iconName: String? = nil, tooltip: String? = nil,
                isBordered: Bool = false,
                offsetX: CGFloat = 0, hoverScale: CGFloat = 1.1,
                hoverBackgroundColor: NSColor? = nil, normalBackgroundColor: NSColor? = nil) {
        self.identifier = identifier
        self.label = label
        self.iconName = iconName
        self.tooltip = tooltip
        self.isBordered = isBordered
        self.offsetX = offsetX
        self.hoverScale = hoverScale
        self.hoverBackgroundColor = hoverBackgroundColor
        self.normalBackgroundColor = normalBackgroundColor
    }
}

// MARK: - 迁回自 UI-02：enum UIToolbarSizeMode
// MARK: - 最小化状态记录
/// 单个窗口的最小化状态记录，用于追踪和恢复
// 已迁回 UI-GL-15_窗口最小化行为自定义.swift：class UIMinimizeStateRecord（公共类型文件禁止功能实现）

// MARK: - 窗口最小化管理器
/// 全局窗口最小化行为管理器（单例）
/// 负责自定义窗口的最小化行为，支持三种模式：
/// 1. 默认Dock：调用系统原生的最小化行为
/// 2. 自定义动画：将窗口以动画方式缩放到屏幕角落
/// 3. 预览缩略图：最小化后以缩略图形式保留在屏幕角落，点击可恢复
/// 线程安全：所有公开方法均使用 NSRecursiveLock 保护共享状态
// 已迁回 UI-GL-15_窗口最小化行为自定义.swift：class UIWindowMinimizeManager（公共类型文件禁止功能实现）

// MARK: - 自定义窗口代理（拦截最小化操作）
/// 窗口代理，用于拦截系统的最小化操作，将其重定向到UIWindowMinimizeManager
// 已迁回 UI-GL-15_窗口最小化行为自定义.swift：class UIMinimizeWindowDelegate（公共类型文件禁止功能实现）

// MARK: - 预览面板代理（点击恢复）
/// 预览面板代理，处理预览面板的事件，点击预览面板时恢复原始窗口
// 已迁回 UI-GL-15_窗口最小化行为自定义.swift：class UIPreviewPanelDelegate（公共类型文件禁止功能实现）


// MARK: - UI-GL-16 批量补充合并（修正解析器）
// 来源: /tmp/仙人指路2-min_UI功能类型迁移_20260610_163203/UI-GL-16_types.swift
// 版本: 2.0
// MARK: - 工具栏高度配置
/// 工具栏显示尺寸模式
public enum UIToolbarSizeMode: CustomStringConvertible {
    case small    // 小尺寸（图标较小，32px高）
    case regular  // 常规尺寸（默认44px高）
    case large    // 大尺寸（图标较大，54px高）

    /// 推荐按钮高度
    public var buttonHeight: CGFloat {
        switch self {
        case .small: return 28
        case .regular: return 36
        case .large: return 48
        }
    }

    /// 推荐按钮宽度
    public var buttonWidth: CGFloat {
        switch self {
        case .small: return 44
        case .regular: return 60
        case .large: return 72
        }
    }

    /// 映射到NSToolbarSizeMode
    public var nsSizeMode: NSToolbar.SizeMode {
        switch self {
        case .small: return .small
        case .regular: return .regular
        case .large: return .regular
        }
    }

    public var description: String {
        switch self {
        case .small: return "small"
        case .regular: return "regular"
        case .large: return "large"
        }
    }
}

// MARK: - 迁回自 UI-02：struct UIToolbarDataItem
// MARK: - 数据项定义
/// 通用工具栏数据项定义，支持任意类型数据展示（价格、数量、状态等）
public struct UIToolbarDataItem: Identifiable {
    public var id = UUID()
    public let identifier: String          // 唯一标识符（如 "BTC/USDT" 或 "news-panel"）
    public let title: String               // 显示标题
    public let displayPrecision: Int         // 数值显示精度
    public var currentValue: Double?       // 当前数值（价格、数量、指标值等）
    public var changeValue: Double?          // 变化值（涨跌幅、增量等）
    public var isSelected: Bool              // 是否选中
    public var metadata: [String: String]    // 附加数据（调用者自由使用）

    public init(identifier: String, title: String,
                displayPrecision: Int = 2, currentValue: Double? = nil,
                changeValue: Double? = nil, isSelected: Bool = false,
                metadata: [String: String] = [:]) {
        self.identifier = identifier
        self.title = title
        self.displayPrecision = displayPrecision
        self.currentValue = currentValue
        self.changeValue = changeValue
        self.isSelected = isSelected
        self.metadata = metadata
    }

    /// 格式化数值显示
    public var formattedValue: String {
        guard let value = currentValue else { return "--" }
        return String(format: "%.*f", displayPrecision, value)
    }

    /// 格式化变化值显示
    public var formattedChange: String {
        guard let change = changeValue else { return "--" }
        let sign = change >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, change)
    }

    /// 变化值颜色（涨绿跌红）
    public var changeColor: NSColor {
        guard let change = changeValue else { return .secondaryLabelColor }
        return change >= 0 ? .systemGreen : .systemRed
    }
}

// MARK: - 迁回自 UI-02：struct UIToolbarTabItem
// MARK: - 工具栏管理器（液态玻璃方案）
/// 管理主窗口工具栏，支持模块动态添加/移除按钮、间距、弹性空间
// 已迁回 UI-GL-16_工具栏管理器.swift：class UIToolbarManagerV2（公共类型文件禁止功能实现）

// MARK: - 标签页项定义
/// 通用工具栏标签页项，类似浏览器标签
public struct UIToolbarTabItem: Identifiable {
    public var id = UUID()
    public let identifier: String          // 唯一标识符（如 "BTC/USDT" 或 "chart-panel-1"）
    public let title: String               // 显示标题
    public var isSelected: Bool            // 是否选中
    public var isCloseable: Bool           // 是否可关闭
    public var badge: String?              // 角标（如未读消息数、价格变动标记）
    public var metadata: [String: String]  // 附加数据（调用者自由使用）

    public init(identifier: String, title: String, isSelected: Bool = false,
                isCloseable: Bool = true, badge: String? = nil,
                metadata: [String: String] = [:]) {
        self.identifier = identifier
        self.title = title
        self.isSelected = isSelected
        self.isCloseable = isCloseable
        self.badge = badge
        self.metadata = metadata
    }
}

// MARK: - 工具栏通用多选弹出面板

public struct UIToolbarMultiSelectItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let tooltip: String?

    public init(id: String, title: String, tooltip: String? = nil) {
        self.id = id
        self.title = title
        self.tooltip = tooltip
    }
}

public struct UIToolbarMultiSelectPopoverConfiguration: Sendable {
    public let title: String
    public let minSelectionCount: Int
    public let maxSelectionCount: Int
    public let width: CGFloat
    public let height: CGFloat
    public let columnCount: Int

    public init(title: String,
                minSelectionCount: Int = 1,
                maxSelectionCount: Int = 8,
                width: CGFloat = 420,
                height: CGFloat = 178,
                columnCount: Int = 5) {
        self.title = title
        self.minSelectionCount = minSelectionCount
        self.maxSelectionCount = maxSelectionCount
        self.width = width
        self.height = height
        self.columnCount = columnCount
    }
}

@MainActor
public final class UIToolbarMultiSelectPopoverPresenter: NSObject, NSPopoverDelegate {
    public static let shared = UIToolbarMultiSelectPopoverPresenter()

    private var popover: NSPopover?
    private var items: [UIToolbarMultiSelectItem] = []
    private var selectedIDs: Set<String> = []
    private var onClose: (([String]) -> Void)?

    private override init() {
        super.init()
    }

    public func show(anchorView: NSView,
                     anchorRect: NSRect? = nil,
                     configuration: UIToolbarMultiSelectPopoverConfiguration,
                     items: [UIToolbarMultiSelectItem],
                     selectedIDs: [String],
                     onClose: @escaping ([String]) -> Void) {
        close(applyClose: false)
        self.items = items
        self.selectedIDs = Set(selectedIDs)
        self.onClose = onClose

        let content = UIToolbarMultiSelectPopoverContent(
            configuration: configuration,
            items: items,
            selectedIDs: Set(selectedIDs),
            onChange: { [weak self] ids in
                self?.selectedIDs = ids
            }
        )

        let nextPopover = NSPopover()
        nextPopover.contentViewController = NSHostingController(rootView: content)
        nextPopover.behavior = .transient
        nextPopover.animates = true
        nextPopover.contentSize = NSSize(width: configuration.width, height: configuration.height)
        nextPopover.delegate = self
        popover = nextPopover

        let rect = anchorRect ?? NSRect(x: anchorView.bounds.midX - 1,
                                        y: anchorView.bounds.maxY - 1,
                                        width: 2,
                                        height: 2)
        nextPopover.show(relativeTo: rect, of: anchorView, preferredEdge: .maxY)
    }

    public func close(applyClose: Bool = true) {
        if applyClose {
            onClose?(orderedIDs(from: selectedIDs))
        }
        popover?.close()
        cleanup()
    }

    public func popoverDidClose(_ notification: Notification) {
        onClose?(orderedIDs(from: selectedIDs))
        cleanup()
    }

    private func cleanup() {
        popover = nil
        items = []
        selectedIDs = []
        onClose = nil
    }

    private func orderedIDs(from ids: Set<String>) -> [String] {
        items.map(\.id).filter { ids.contains($0) }
    }
}

private struct UIToolbarMultiSelectPopoverContent: View {
    let configuration: UIToolbarMultiSelectPopoverConfiguration
    let items: [UIToolbarMultiSelectItem]
    let onChange: (Set<String>) -> Void

    @State private var selectedIDs: Set<String>

    init(configuration: UIToolbarMultiSelectPopoverConfiguration,
         items: [UIToolbarMultiSelectItem],
         selectedIDs: Set<String>,
         onChange: @escaping (Set<String>) -> Void) {
        self.configuration = configuration
        self.items = items
        self.onChange = onChange
        self._selectedIDs = State(initialValue: selectedIDs)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: max(1, configuration.columnCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(configuration.title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("已选 \(selectedIDs.count)/\(configuration.maxSelectionCount)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor))

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(items) { item in
                    UIToolbarMultiSelectCell(
                        title: item.title,
                        isSelected: selectedIDs.contains(item.id),
                        action: { toggle(item.id) }
                    )
                    .help(item.tooltip ?? item.title)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .frame(width: configuration.width)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 10)
    }

    private func toggle(_ id: String) {
        var next = selectedIDs
        if next.contains(id) {
            guard next.count > configuration.minSelectionCount else { return }
            next.remove(id)
        } else {
            guard next.count < configuration.maxSelectionCount else { return }
            next.insert(id)
        }
        selectedIDs = next
        onChange(next)
    }
}

private struct UIToolbarMultiSelectCell: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: isSelected ? 1.4 : 0.6)
        )
    }
}
