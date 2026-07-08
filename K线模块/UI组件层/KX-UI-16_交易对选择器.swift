//
//  KX-UI-16_交易对选择器.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：先选交易板块（现货/U本位永续/币本位永续），再选该板块下的真实 OKX instId
//  禁止事项：禁止直接请求 OKX、禁止直接查库
//

import AppKit
import Foundation

// MARK: - 文件级辅助常量和函数（避免 Swift 6 @MainActor 隔离）

private let kSpotTop20: [String] = [
    "BTC-USDT", "ETH-USDT", "SOL-USDT", "XRP-USDT", "DOGE-USDT",
    "ADA-USDT", "AVAX-USDT", "DOT-USDT", "LINK-USDT", "MATIC-USDT",
    "BCH-USDT", "UNI-USDT", "LTC-USDT", "ATOM-USDT", "XLM-USDT",
    "ETC-USDT", "FIL-USDT", "TRX-USDT", "APT-USDT", "ARB-USDT"
]

private let kSwapTop20: [String] = [
    "BTC-USDT-SWAP", "ETH-USDT-SWAP", "SOL-USDT-SWAP", "XRP-USDT-SWAP", "DOGE-USDT-SWAP",
    "ADA-USDT-SWAP", "AVAX-USDT-SWAP", "DOT-USDT-SWAP", "LINK-USDT-SWAP", "MATIC-USDT-SWAP",
    "BCH-USDT-SWAP", "UNI-USDT-SWAP", "LTC-USDT-SWAP", "ATOM-USDT-SWAP", "XLM-USDT-SWAP",
    "ETC-USDT-SWAP", "FIL-USDT-SWAP", "TRX-USDT-SWAP", "APT-USDT-SWAP", "ARB-USDT-SWAP"
]

private let kFuturesTop20: [String] = [
    // OKX 币本位永续真实 instId：BTC-USD-SWAP，不是过期交割合约 BTC-USD-230927。
    "BTC-USD-SWAP", "ETH-USD-SWAP", "SOL-USD-SWAP", "XRP-USD-SWAP", "DOGE-USD-SWAP",
    "ADA-USD-SWAP", "AVAX-USD-SWAP", "DOT-USD-SWAP", "LINK-USD-SWAP", "MATIC-USD-SWAP",
    "BCH-USD-SWAP", "UNI-USD-SWAP", "LTC-USD-SWAP", "ATOM-USD-SWAP", "XLM-USD-SWAP",
    "ETC-USD-SWAP", "FIL-USD-SWAP", "TRX-USD-SWAP", "APT-USD-SWAP", "ARB-USD-SWAP"
]

private let kInstrumentCacheQueue = DispatchQueue(label: "com.xianren.kline.instrument-selector.cache")
private var kCachedInstrumentsByType: [KLMarketType: [String]] = [:]

private func kFallbackInstruments(for type: KLMarketType) -> [String] {
    switch type {
    case .spot: return kSpotTop20
    case .swap: return kSwapTop20
    case .futures: return kFuturesTop20
    default: return kSpotTop20
    }
}

private func kOkxInstrumentType(for type: KLMarketType) -> String {
    switch type {
    case .spot: return "SPOT"
    case .swap, .futures: return "SWAP"
    case .margin: return "MARGIN"
    case .option: return "OPTION"
    }
}

private func kInstrumentMatchesMarketType(_ instID: String, type: KLMarketType) -> Bool {
    switch type {
    case .spot:
        return !instID.hasSuffix("-SWAP")
    case .swap:
        return instID.hasSuffix("-USDT-SWAP") || instID.hasSuffix("-USDC-SWAP")
    case .futures:
        return instID.hasSuffix("-USD-SWAP")
    case .margin, .option:
        return true
    }
}

private func kMergePreferred(_ preferred: [String], with all: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for inst in preferred + all {
        let trimmed = inst.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
        result.append(trimmed)
    }
    return result
}

private func kFetchInstrumentsFromOKX(for type: KLMarketType) async -> [String] {
    do {
        let rest = KLOKXDefaultRESTExecutor(config: KLOKXRESTConfig.development)
        let rows = try await rest.fetchInstruments(instType: kOkxInstrumentType(for: type))
        let ids = rows.compactMap { row -> String? in
            let state = (row["state"] as? String) ?? "live"
            guard state == "live" else { return nil }
            guard let instID = (row["instId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !instID.isEmpty else { return nil }
            return kInstrumentMatchesMarketType(instID, type: type) ? instID : nil
        }
        return kMergePreferred(kFallbackInstruments(for: type), with: ids.sorted())
    } catch {
        klineLogger.info("[KLine][InstrumentSelector] OKX instruments fallback type=\(type.rawValue) error=\(error.localizedDescription)")
        return []
    }
}


// MARK: - 交易板块选择器（三角形下拉菜单版本）

public class KLMarketTypeSelectorView: NSView {
    private var popoverButton: NSButton?
    private var currentType: KLMarketType
    private var isMenuOpen = false

    public var onMarketTypeChanged: ((KLMarketType) -> Void)?
    public var onInstrumentSelected: ((String) -> Void)?

    public init(initialType: KLMarketType = .spot, frame: NSRect = .zero) {
        self.currentType = initialType
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.currentType = .spot
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        setupPopoverButton()
    }

    private func setupPopoverButton() {
        let btn = NSButton(frame: .zero)
        // 设置为三角形下拉按钮样式
        btn.bezelStyle = .inline
        btn.setButtonType(.momentaryLight)
        // 添加三角形图标
        btn.title = "  "
        btn.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "下拉菜单")
        btn.target = self
        btn.action = #selector(showMarketTypeMenu)
        btn.autoresizingMask = [.width, .height]
        addSubview(btn)
        self.popoverButton = btn
    }

    public override func layout() {
        super.layout()
        popoverButton?.frame = bounds
    }

    @objc private func showMarketTypeMenu() {
        let menu = NSMenu(title: "选择交易板块")

        let types: [KLMarketType] = [.spot, .swap, .futures]
        let labels: [KLMarketType: String] = [
            .spot: "现货",
            .swap: "U本位永续",
            .futures: "币本位永续"
        ]
        let icons: [KLMarketType: String] = [
            .spot: "circle",
            .swap: "yen.sign",
            .futures: "circle"
        ]

        for type in types {
            guard let label = labels[type], let icon = icons[type] else { continue }
            let item = NSMenuItem(title: label, action: #selector(marketTypeSelected(_:)), keyEquivalent: "")
            item.representedObject = type
            item.target = self
            item.image = NSImage(systemSymbolName: icon, accessibilityDescription: label)

            // 当前选中的项添加勾选标记
            if type == currentType {
                item.state = .on
            }

            menu.addItem(item)
        }

        if let btn = popoverButton {
            menu.popUp(positioning: nil, at: btn.bounds.origin, in: btn)
        }
    }

    @objc private func marketTypeSelected(_ sender: NSMenuItem) {
        guard let type = sender.representedObject as? KLMarketType else { return }
        currentType = type
        onMarketTypeChanged?(type)

        // 更新按钮显示当前选中的板块
        let labels: [KLMarketType: String] = [
            .spot: "现货",
            .swap: "U本位永续",
            .futures: "币本位永续"
        ]
        if let label = labels[type] {
            popoverButton?.title = label
            popoverButton?.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "下拉菜单")
        }
    }

    public func currentMarketType() -> KLMarketType {
        return currentType
    }
    
    /// 外部调用切换市场类型
    public func switchMarketType(_ type: KLMarketType) {
        currentType = type
        // 更新按钮显示当前选中的板块
        let labels: [KLMarketType: String] = [
            .spot: "现货",
            .swap: "U本位永续",
            .futures: "币本位永续"
        ]
        if let label = labels[type] {
            popoverButton?.title = label
            popoverButton?.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "下拉菜单")
        }
        onMarketTypeChanged?(type)
    }
}

// MARK: - 币对选择下拉

public class KLInstrumentSelectorView: NSView {
    private var popoverButton: NSButton?
    public var instruments: [String] = []
    public var onInstrumentSelected: ((String) -> Void)?
    private var customInstruments: [String] = []
    public var currentInstrument: String = "BTC-USDT"

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        let btn = NSButton(frame: .zero)
        currentInstrument = "BTC-USDT"
        btn.title = currentInstrument
        btn.bezelStyle = .rounded
        btn.target = self
        btn.action = #selector(showInstrumentMenu)
        btn.autoresizingMask = [.width, .height]
        addSubview(btn)
        self.popoverButton = btn
    }

    public override func layout() {
        super.layout()
        popoverButton?.frame = bounds
    }

    public static func fallbackInstruments(for type: KLMarketType) -> [String] {
        return kFallbackInstruments(for: type)
    }

    public static func instruments(for type: KLMarketType) -> [String] {
        // 主线程绝对禁止同步查询数据库(psql 子进程)或网络，否则构建菜单/工具栏时会阻塞主线程导致界面卡死转圈。
        // 这里只返回内存缓存或静态 fallback，真实全量列表由 refreshInstrumentsFromDatabaseOrOKX 后台异步填充。
        let cached = kInstrumentCacheQueue.sync { kCachedInstrumentsByType[type] ?? [] }
        if !cached.isEmpty { return cached }
        refreshInstrumentsFromDatabaseOrOKX(for: type, completion: nil)
        return kFallbackInstruments(for: type)
    }

    public static func refreshInstrumentsFromDatabaseOrOKX(for type: KLMarketType, completion: (([String]) -> Void)? = nil) {
        Task.detached(priority: .utility) {
            let result: [String]
            if let dbList = try? KLDefaultDatabaseExecutor.shared.queryInstrumentIDs(exchange: "OKX", marketType: type, liveOnly: true), !dbList.isEmpty {
                result = kMergePreferred(kFallbackInstruments(for: type), with: dbList)
            } else {
                let fetched = await kFetchInstrumentsFromOKX(for: type)
                result = fetched.isEmpty ? kFallbackInstruments(for: type) : fetched
            }
            kInstrumentCacheQueue.sync { kCachedInstrumentsByType[type] = result }
            await MainActor.run { completion?(result) }
        }
    }

    public static func defaultInstrument(for type: KLMarketType) -> String {
        instruments(for: type).first ?? "BTC-USDT"
    }


    /// 切换板块时调用
    public func switchMarketType(_ type: KLMarketType) {
        instruments = Self.instruments(for: type)
        currentInstrument = Self.defaultInstrument(for: type)
        popoverButton?.title = currentInstrument
        Self.refreshInstrumentsFromDatabaseOrOKX(for: type) { [weak self] list in
            guard let self else { return }
            self.instruments = list
        }
        onInstrumentSelected?(currentInstrument)
    }

    @objc private func showInstrumentMenu() {
        let menu = NSMenu(title: "选择币对")

        // 添加搜索框
        let searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        searchField.placeholderString = "搜索币对..."
        let searchItem = NSMenuItem()
        searchItem.view = searchField
        menu.addItem(searchItem)
        menu.addItem(NSMenuItem.separator())

        // 添加常用币对分组
        let popularGroup = NSMenu()
        popularGroup.title = "常用币对"
        for inst in instruments.prefix(10) {
            let item = NSMenuItem(title: inst, action: #selector(selectedInstrument(_:)), keyEquivalent: "")
            item.representedObject = inst
            item.target = self
            if inst == currentInstrument {
                item.state = .on
            }
            popularGroup.addItem(item)
        }
        let popularMenuItem = NSMenuItem(title: "常用币对", action: nil, keyEquivalent: "")
        popularMenuItem.submenu = popularGroup
        menu.addItem(popularMenuItem)

        if instruments.isEmpty { instruments = Self.instruments(for: .spot) }

        // 全部币对分组
        let allGroup = NSMenu()
        allGroup.title = "全部币对"
        for inst in instruments {
            let item = NSMenuItem(title: inst, action: #selector(selectedInstrument(_:)), keyEquivalent: "")
            item.representedObject = inst
            item.target = self
            if inst == currentInstrument {
                item.state = .on
            }
            allGroup.addItem(item)
        }
        let allMenuItem = NSMenuItem(title: "全部币对", action: nil, keyEquivalent: "")
        allMenuItem.submenu = allGroup
        menu.addItem(allMenuItem)

        // 最底部添加自定义选项
        menu.addItem(NSMenuItem.separator())
        let addItem = NSMenuItem(title: "添加自定义币对...", action: #selector(addCustomInstrument), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)

        if let btn = popoverButton {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: btn.bounds.height), in: btn)
        }
    }

    @objc private func selectedInstrument(_ sender: NSMenuItem) {
        guard let inst = sender.representedObject as? String else { return }
        currentInstrument = inst
        popoverButton?.title = inst
        onInstrumentSelected?(inst)
    }

    @objc private func addCustomInstrument() {
        let alert = NSAlert()
        alert.messageText = "添加自定义币对"
        alert.informativeText = "输入 OKX 真实 instId，如 SOL-USDT、SOL-USDT-SWAP、SOL-USD-SWAP"
        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "例如: SOL-USDT"
        alert.accessoryView = textField
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            let input = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !input.isEmpty else { return }
            currentInstrument = input
            popoverButton?.title = input
            // 临时追加到列表
            if !instruments.contains(input) {
                instruments.append(input)
            }
            onInstrumentSelected?(input)
        }
    }

    public func updateSelectedInstrument(_ instrument: String) {
        currentInstrument = instrument
        popoverButton?.title = instrument
    }
}

// MARK: - 复合选择器（统一级联菜单：交易板块 + 币对选择）

public class KLTradingPairSelectorView: NSView {
    private let button = NSButton(frame: .zero)
    private var selectedMarketType: KLMarketType
    private var selectedInstrument: String

    public var currentMarketType: KLMarketType { selectedMarketType }
    public var currentInstrument: String { selectedInstrument }

    public var onMarketTypeChanged: ((KLMarketType) -> Void)?
    public var onInstrumentSelected: ((String) -> Void)?

    public init(initialType: KLMarketType = .spot, frame: NSRect = .zero) {
        self.selectedMarketType = initialType
        self.selectedInstrument = KLInstrumentSelectorView.defaultInstrument(for: initialType)
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.selectedMarketType = .spot
        self.selectedInstrument = KLInstrumentSelectorView.defaultInstrument(for: .spot)
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryLight)
        button.target = self
        button.action = #selector(showUnifiedTradingPairMenu)
        button.autoresizingMask = [.width, .height]
        addSubview(button)
        updateButtonTitle()
    }

    public override func layout() {
        super.layout()
        button.frame = bounds
    }

    @objc private func showUnifiedTradingPairMenu() {
        // 先异步刷新一次当前板块的完整 OKX instId 列表；本次菜单用已有缓存/DB，刷新完成后下次打开即是最新全量。
        KLInstrumentSelectorView.refreshInstrumentsFromDatabaseOrOKX(for: selectedMarketType, completion: nil)

        let menu = NSMenu(title: "选择币对")
        menu.autoenablesItems = false

        for type in orderedMarketTypes {
            let item = NSMenuItem(title: label(for: type), action: nil, keyEquivalent: "")
            item.image = NSImage(systemSymbolName: iconName(for: type), accessibilityDescription: label(for: type))
            item.state = (type == selectedMarketType) ? .on : .off
            item.submenu = makeInstrumentSubmenu(for: type)
            menu.addItem(item)
        }

        if !menu.items.isEmpty { menu.addItem(NSMenuItem.separator()) }
        let customItem = NSMenuItem(title: "添加自定义币对...", action: #selector(addCustomInstrument), keyEquivalent: "")
        customItem.target = self
        menu.addItem(customItem)

        // AppKit 菜单弹出坐标在当前按钮坐标系内，y 增大时菜单视觉下移。
        // 稍微下移，避免一级菜单盖住二级工具栏本体。
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 8), in: button)
    }

    private func makeInstrumentSubmenu(for type: KLMarketType) -> NSMenu {
        let submenu = NSMenu(title: label(for: type))
        submenu.autoenablesItems = false
        let instruments = KLInstrumentSelectorView.instruments(for: type)

        let popular = Array(instruments.prefix(20))
        if !popular.isEmpty {
            let popularHeader = NSMenuItem(title: "常用币对", action: nil, keyEquivalent: "")
            popularHeader.isEnabled = false
            submenu.addItem(popularHeader)
            for inst in popular { appendInstrumentItem(inst, type: type, to: submenu) }
        }

        if instruments.count > popular.count {
            submenu.addItem(NSMenuItem.separator())
            let allHeader = NSMenuItem(title: "全部币对（\(instruments.count)）", action: nil, keyEquivalent: "")
            allHeader.isEnabled = false
            submenu.addItem(allHeader)
            for inst in instruments { appendInstrumentItem(inst, type: type, to: submenu) }
        }

        if instruments.isEmpty {
            let item = NSMenuItem(title: "正在加载币对目录...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        }
        return submenu
    }

    private func appendInstrumentItem(_ inst: String, type: KLMarketType, to submenu: NSMenu) {
        let item = NSMenuItem(title: inst, action: #selector(instrumentMenuItemSelected(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = KLTradingPairMenuSelection(type: type, instrument: inst)
        if type == selectedMarketType && inst == selectedInstrument { item.state = .on }
        submenu.addItem(item)
    }

    @objc private func instrumentMenuItemSelected(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? KLTradingPairMenuSelection else { return }
        let typeChanged = selection.type != selectedMarketType
        selectedMarketType = selection.type
        selectedInstrument = selection.instrument
        updateButtonTitle()
        if typeChanged { onMarketTypeChanged?(selection.type) }
        onInstrumentSelected?(selection.instrument)
    }

    @objc private func addCustomInstrument() {
        let alert = NSAlert()
        alert.messageText = "添加自定义币对"
        alert.informativeText = "输入 OKX 真实 instId，如 SOL-USDT、SOL-USDT-SWAP、SOL-USD-SWAP"
        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        textField.placeholderString = "例如: SOL-USDT"
        alert.accessoryView = textField
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let input = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        selectedInstrument = input
        updateButtonTitle()
        onInstrumentSelected?(input)
    }

    public func switchMarketType(_ type: KLMarketType) {
        selectedMarketType = type
        selectedInstrument = KLInstrumentSelectorView.defaultInstrument(for: type)
        updateButtonTitle()
        KLInstrumentSelectorView.refreshInstrumentsFromDatabaseOrOKX(for: type) { [weak self] list in
            guard let self, self.selectedMarketType == type else { return }
            if !list.isEmpty, !list.contains(self.selectedInstrument) {
                self.selectedInstrument = list[0]
                self.updateButtonTitle()
            }
        }
        onMarketTypeChanged?(type)
        onInstrumentSelected?(selectedInstrument)
    }

    public func updateSelectedInstrument(_ instrument: String) {
        selectedInstrument = instrument
        if instrument.contains("-USD-SWAP") {
            selectedMarketType = .futures
        } else if instrument.contains("-USDT-SWAP") {
            selectedMarketType = .swap
        } else {
            selectedMarketType = .spot
        }
        updateButtonTitle()
    }

    private var orderedMarketTypes: [KLMarketType] { [.spot, .swap, .futures] }

    private func updateButtonTitle() {
        button.title = "\(label(for: selectedMarketType))  \(selectedInstrument)"
        button.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "选择币对")
        button.imagePosition = .imageTrailing
    }

    private func label(for type: KLMarketType) -> String {
        switch type {
        case .spot: return "现货"
        case .swap: return "U本位永续"
        case .futures: return "币本位永续"
        default: return type.rawValue
        }
    }

    private func iconName(for type: KLMarketType) -> String {
        switch type {
        case .spot: return "circle"
        case .swap: return "dollarsign.circle"
        case .futures: return "bitcoinsign.circle"
        default: return "circle"
        }
    }
}

private final class KLTradingPairMenuSelection: NSObject {
    let type: KLMarketType
    let instrument: String

    init(type: KLMarketType, instrument: String) {
        self.type = type
        self.instrument = instrument
        super.init()
    }
}
// MARK: - KXFileSkeletonProtocol

public enum KXKXUI16Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-16", fileName: "KX-UI-16_交易对选择器.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-16_交易对选择器.swift", duty: "交易对选择器控件"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("交易对选择器骨架校验通过")
        return KXHealthCheckItem(name: "交易对选择器", passed: true, message: "交易对选择器控件")
    }
}
