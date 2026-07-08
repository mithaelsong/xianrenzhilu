//
//  KX-UI-11_时间框架选择.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：OKX式时间框架选择 UI：常用周期直显 + 更多周期弹层
//  禁止事项：禁止直接请求 OKX、禁止直接查库
//

import AppKit
import Foundation
import SwiftUI
import os.log

private let logger = klineLogger

public class KXUI11TimeframeSelectorView: NSView, NSPopoverDelegate {
    private var timeframeButtons: [NSButton] = []
    private var moreButton: NSButton?
    private var popover: NSPopover?
    private var highlightedButton: NSButton?
    private var pendingVisibleTimeframes: [KXTimeframe]?

    private let maxVisibleTimeframeCount = 8

    /// 工具栏直接显示的周期。默认只显示董事长当前选中的常用周期：15m、1H、4H、1D、1W、1M。
    /// 未被选中的 3m/5m 等周期只保留在弹层候选里，不能出现在顶部快捷栏。
    public var visibleTimeframes: [KXTimeframe] = [.fifteenMinutes, .oneHour, .fourHours, .oneDay, .oneWeek, .oneMonth] {
        didSet {
            visibleTimeframes = normalizedVisibleTimeframes(visibleTimeframes)
            invalidateIntrinsicContentSize()
            needsLayout = true
        }
    }

    /// 当前代码支持的全部周期。没有实现“分时”就不伪造分时，只展示现有真实周期。
    public let allTimeframes: [KXTimeframe] = KXFN02TimeframeManager.supportedTimeframes

    private var shortcutMap: [Int: KXTimeframe] {
        var result: [Int: KXTimeframe] = [:]
        for (idx, timeframe) in visibleTimeframes.prefix(9).enumerated() {
            result[idx + 1] = timeframe
        }
        return result
    }

    public var selectedTimeframe: KXTimeframe = .oneHour {
        didSet {
            // 只更新高亮。当前选择不等于“顶部快捷栏显示集合”，不能因为选中过 3m/5m 就把它们偷偷加回顶部。
            updateHighlight()
        }
    }

    public var onTimeframeSelected: ((KXTimeframe) -> Void)?
    /// 顶部快捷周期集合变更（弹层关闭应用多选结果后触发）。
    public var onVisibleTimeframesChanged: (([KXTimeframe]) -> Void)?

    /// 当前已建按钮对应的周期集合。layout() 只在它变化时重建按钮，否则只更新 frame，
    /// 避免每次 layout 都销毁重建 NSButton（点击撞上重建瞬间会落空 → 偶尔点击没反应）。
    private var laidOutTimeframes: [KXTimeframe] = []

    public override var intrinsicContentSize: NSSize {
        let height: CGFloat = 30
        let width = visibleTimeframes.reduce(CGFloat(4)) { partial, timeframe in
            partial + Self.buttonWidth(for: Self.compactTitle(for: timeframe)) + 6
        } + 32
        return NSSize(width: width, height: height)
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        visibleTimeframes = normalizedVisibleTimeframes(visibleTimeframes)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        // 优先命中按钮：避免 NSButton 默认 hitTest 因 tracking area/frame 边缘问题返回 nil，
        // 导致事件落到 timeframeSelector 自身而按钮收不到点击（第一个按钮尤其容易触边）。
        for btn in timeframeButtons.reversed() {
            if btn.frame.contains(point) { return btn }
        }
        if let more = moreButton, more.frame.contains(point) { return more }
        return nil
    }

    public override func layout() {
        super.layout()

        let btnHeight: CGFloat = 22
        let spacing: CGFloat = 4
        let moreButtonWidth: CGFloat = 24
        let centerY = (bounds.height - btnHeight) / 2
        let displayTimeframes = adaptiveVisibleTimeframes(for: max(0, bounds.width - moreButtonWidth - spacing - 8))

        // 周期集合未变：只重新定位现有按钮 frame，不销毁重建（避免点击落空）。
        if displayTimeframes == laidOutTimeframes,
           timeframeButtons.count == displayTimeframes.count,
           moreButton != nil {
            var x: CGFloat = 4
            for (i, timeframe) in displayTimeframes.enumerated() {
                let width = Self.buttonWidth(for: Self.compactTitle(for: timeframe))
                timeframeButtons[i].frame = CGRect(x: x, y: centerY, width: width, height: btnHeight)
                x += width + spacing
            }
            moreButton?.frame = CGRect(x: x, y: centerY, width: moreButtonWidth, height: btnHeight)
            updateHighlight()
            return
        }

        // 周期集合变化：重建按钮。
        for btn in timeframeButtons { btn.removeFromSuperview() }
        timeframeButtons.removeAll()
        moreButton?.removeFromSuperview()
        moreButton = nil

        var x: CGFloat = 4
        for timeframe in displayTimeframes {
            let label = Self.compactTitle(for: timeframe)
            let width = Self.buttonWidth(for: label)
            let btn = NSButton(frame: CGRect(x: x, y: centerY, width: width, height: btnHeight))
            btn.title = label
            btn.bezelStyle = .inline
            btn.setButtonType(.momentaryPushIn)
            btn.target = self
            btn.action = #selector(timeframeClicked(_:))
            btn.tag = allTimeframes.firstIndex(of: timeframe) ?? -1
            btn.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
            btn.toolTip = KXFN02TimeframeManager.displayName(for: timeframe) ?? timeframe.rawValue
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 3
            btn.addTrackingArea(NSTrackingArea(rect: btn.bounds,
                                               options: [.mouseEnteredAndExited, .activeAlways],
                                               owner: self,
                                               userInfo: ["button": btn, "timeframe": timeframe]))
            addSubview(btn)
            timeframeButtons.append(btn)
            x += width + spacing
        }

        // OKX风格：小箭头只是展开按钮，跟在当前可见周期最后面，不再写死“1月”。
        let moreBtn = NSButton(frame: CGRect(x: x, y: centerY, width: moreButtonWidth, height: btnHeight))
        moreBtn.title = ""
        moreBtn.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "更多周期")
        moreBtn.imagePosition = .imageOnly
        moreBtn.bezelStyle = .inline
        moreBtn.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        moreBtn.target = self
        moreBtn.action = #selector(moreClicked)
        moreBtn.toolTip = "选择更多时间框架"
        addSubview(moreBtn)
        self.moreButton = moreBtn

        laidOutTimeframes = displayTimeframes
        updateHighlight()
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard let button = event.trackingArea?.userInfo?["button"] as? NSButton else { return }
        highlightedButton = button
        if button.state != .on {
            button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        }
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard let button = event.trackingArea?.userInfo?["button"] as? NSButton else { return }
        if button.state != .on {
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }
        highlightedButton = nil
    }

    @objc private func timeframeClicked(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < allTimeframes.count else { return }
        let timeframe = allTimeframes[sender.tag]
        select(timeframe)
        logger.info("[KLine][TF] toolbar selected timeframe=\(timeframe.rawValue)")
    }

    @objc private func moreClicked() {
        if let popover, popover.isShown {
            popover.close()
            return
        }

        pendingVisibleTimeframes = visibleTimeframes
        let popupView = KXTimeframePopupView(
            allTimeframes: allTimeframes,
            visibleTimeframes: visibleTimeframes,
            onVisibleTimeframesChanged: { [weak self] timeframes in
                // 只记录弹层内的多选结果，不立刻重排外层工具栏；否则锚点按钮被销毁，NSPopover 会关闭/不稳定。
                self?.pendingVisibleTimeframes = self?.sortedTimeframes(timeframes) ?? timeframes
            }
        )

        let nextPopover = NSPopover()
        nextPopover.contentViewController = NSHostingController<AnyView>(rootView: AnyView(popupView))
        nextPopover.behavior = .transient
        nextPopover.animates = true
        nextPopover.contentSize = NSSize(width: 330, height: 164)
        nextPopover.delegate = self
        popover = nextPopover

        if let btn = moreButton {
            logger.info("[KLine][TF] show timeframe popover visibleCount=\(self.visibleTimeframes.count)")
            // 锚点必须在按钮 bounds 内，否则 AppKit 可能直接不显示 popover。用按钮顶部内侧，视觉上比原位置稍靠上。
            let anchor = NSRect(x: btn.bounds.midX - 1, y: btn.bounds.maxY - 1, width: 2, height: 2)
            nextPopover.show(relativeTo: anchor, of: btn, preferredEdge: .maxY)
        }
    }

    public func popoverDidClose(_ notification: Notification) {
        if let pendingVisibleTimeframes {
            let next = sortedTimeframes(pendingVisibleTimeframes)
            let changed = next != visibleTimeframes
            visibleTimeframes = next
            updateHighlight()
            if changed { onVisibleTimeframesChanged?(next) }
        }
        pendingVisibleTimeframes = nil
        popover = nil
    }

    private func select(_ timeframe: KXTimeframe) {
        selectedTimeframe = timeframe
        onTimeframeSelected?(timeframe)
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // 如果当前焦点在文本输入框中，不处理时间框架快捷键
        // 避免设置面板中的数字输入干扰时间框架
        if let firstResponder = NSApp.keyWindow?.firstResponder as? NSText,
           firstResponder.isKind(of: NSTextField.self) || firstResponder.isKind(of: NSTextView.self) {
            return
        }
        guard let char = event.characters?.lowercased(),
              let number = Int(char),
              let timeframe = shortcutMap[number] else {
            return
        }
        select(timeframe)
        NSSound.beep()
    }

    private func updateHighlight() {
        for btn in timeframeButtons {
            guard btn.tag >= 0, btn.tag < allTimeframes.count else { continue }
            let timeframe = allTimeframes[btn.tag]
            if timeframe == selectedTimeframe {
                btn.state = .on
                btn.layer?.borderWidth = 1.5
                btn.layer?.borderColor = NSColor.controlAccentColor.cgColor
                btn.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
            } else {
                btn.state = .off
                btn.layer?.borderWidth = 0
                btn.layer?.borderColor = NSColor.clear.cgColor
                btn.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }

    private func normalizedVisibleTimeframes(_ timeframes: [KXTimeframe]) -> [KXTimeframe] {
        var result: [KXTimeframe] = []
        for timeframe in timeframes where allTimeframes.contains(timeframe) {
            if result.contains(timeframe) == false {
                result.append(timeframe)
            }
            if result.count == maxVisibleTimeframeCount { break }
        }
        return result.isEmpty ? [.fifteenMinutes, .oneHour, .fourHours, .oneDay, .oneWeek, .oneMonth] : sortedTimeframes(result)
    }

    private func sortedTimeframes(_ timeframes: [KXTimeframe]) -> [KXTimeframe] {
        let unique = timeframes.reduce(into: [KXTimeframe]()) { result, timeframe in
            if result.contains(timeframe) == false { result.append(timeframe) }
        }
        return unique.sorted { lhs, rhs in
            let lhsRank = Self.timeframeSortRank(lhs)
            let rhsRank = Self.timeframeSortRank(rhs)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.rawValue < rhs.rawValue
        }
    }

    private static func timeframeSortRank(_ timeframe: KXTimeframe) -> Int {
        switch timeframe {
        case .oneMonth: return 2_592_000      // 30 天：必须排在 1周之后
        case .threeMonths: return 7_776_000   // 90 天：必须排在 1月之后
        default: return KXFN02TimeframeManager.seconds(for: timeframe) ?? Int.max
        }
    }

    private static func compactTitle(for timeframe: KXTimeframe) -> String {
        let name = KXFN02TimeframeManager.displayName(for: timeframe) ?? timeframe.rawValue
        return name.replacingOccurrences(of: "分钟", with: "分")
    }

    private func adaptiveVisibleTimeframes(for availableWidth: CGFloat) -> [KXTimeframe] {
        guard availableWidth > 0 else { return [] }
        var result: [KXTimeframe] = []
        var usedWidth: CGFloat = 0
        let spacing: CGFloat = 4

        for timeframe in visibleTimeframes {
            let title = Self.compactTitle(for: timeframe)
            let width = Self.buttonWidth(for: title)
            let nextWidth = usedWidth + (result.isEmpty ? 0 : spacing) + width
            if nextWidth <= availableWidth {
                result.append(timeframe)
                usedWidth = nextWidth
            }
        }

        if result.isEmpty, let first = visibleTimeframes.first {
            return [first]
        }
        return result
    }

    private static func buttonWidth(for title: String) -> CGFloat {
        CGFloat(max(2, title.count) * 8) + 20
    }
}

// MARK: - 时间框架弹出面板

private struct KXTimeframePopupView: View {
    let allTimeframes: [KXTimeframe]
    let visibleTimeframes: [KXTimeframe]
    let onVisibleTimeframesChanged: ([KXTimeframe]) -> Void

    @State private var selectedShortcuts: Set<KXTimeframe>

    private let maxShortcutCount = 8
    private let gridItems = Array(repeating: SwiftUI.GridItem(.fixed(54), spacing: 5), count: 5)

    init(allTimeframes: [KXTimeframe],
         visibleTimeframes: [KXTimeframe],
         onVisibleTimeframesChanged: @escaping ([KXTimeframe]) -> Void) {
        self.allTimeframes = allTimeframes
        self.visibleTimeframes = visibleTimeframes
        self.onVisibleTimeframesChanged = onVisibleTimeframesChanged
        self._selectedShortcuts = State(initialValue: Set(visibleTimeframes))
    }

    var body: some View {
        SwiftUI.VStack(alignment: .leading, spacing: 0) {
            SwiftUI.HStack {
                SwiftUI.Text("时间框架")
                    .font(.system(size: 12, weight: .medium))
                SwiftUI.Spacer()
                SwiftUI.Text("已选 \(selectedShortcuts.count)/\(maxShortcutCount)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor))

            SwiftUI.LazyVGrid(columns: gridItems, spacing: 6) {
                ForEach(allTimeframes, id: \.rawValue) { timeframe in
                    TimeframeButton(
                        title: compactTitle(for: timeframe),
                        timeframe: timeframe,
                        isVisibleShortcut: selectedShortcuts.contains(timeframe),
                        action: { toggleShortcut(timeframe) }
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .frame(width: 330)
        .background(SwiftUI.Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 10)
    }

    private func toggleShortcut(_ timeframe: KXTimeframe) {
        if selectedShortcuts.contains(timeframe) {
            if selectedShortcuts.count > 1 {
                selectedShortcuts.remove(timeframe)
            }
        } else {
            if selectedShortcuts.count >= maxShortcutCount,
               let largest = sorted(Array(selectedShortcuts)).last {
                selectedShortcuts.remove(largest)
            }
            selectedShortcuts.insert(timeframe)
        }
        let next = sorted(Array(selectedShortcuts))
        onVisibleTimeframesChanged(next)
    }

    private func sorted(_ timeframes: [KXTimeframe]) -> [KXTimeframe] {
        let unique = timeframes.reduce(into: [KXTimeframe]()) { result, timeframe in
            if result.contains(timeframe) == false { result.append(timeframe) }
        }
        return unique.sorted { lhs, rhs in
            let lhsRank = timeframeSortRank(lhs)
            let rhsRank = timeframeSortRank(rhs)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.rawValue < rhs.rawValue
        }
    }

    private func timeframeSortRank(_ timeframe: KXTimeframe) -> Int {
        switch timeframe {
        case .oneMonth: return 2_592_000
        case .threeMonths: return 7_776_000
        default: return KXFN02TimeframeManager.seconds(for: timeframe) ?? Int.max
        }
    }

    private func compactTitle(for timeframe: KXTimeframe) -> String {
        let name = KXFN02TimeframeManager.displayName(for: timeframe) ?? timeframe.rawValue
        return name.replacingOccurrences(of: "分钟", with: "分")
    }
}

private struct TimeframeButton: View {
    let title: String
    let timeframe: KXTimeframe
    let isVisibleShortcut: Bool
    let action: () -> Void

    var body: some View {
        SwiftUI.Button(action: action) {
            SwiftUI.Text(title)
                .font(.system(size: 10.5, weight: isVisibleShortcut ? .semibold : .regular))
                .lineLimit(1)
                .frame(width: 54)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(isVisibleShortcut ? SwiftUI.Color.accentColor.opacity(0.10) : SwiftUI.Color.clear)
        .cornerRadius(4)
        .overlay(
            SwiftUI.RoundedRectangle(cornerRadius: 4)
                .stroke(isVisibleShortcut ? SwiftUI.Color.accentColor : SwiftUI.Color.secondary.opacity(0.18), lineWidth: isVisibleShortcut ? 1.4 : 0.6)
        )
    }
}

extension KXTimeframe {
    static let allCasesSorted: [KXTimeframe] = KXFN02TimeframeManager.supportedTimeframes
}

// MARK: - KXFileSkeletonProtocol

public enum KXKXUI11Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-11", fileName: "KX-UI-11_时间框架选择.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-11_时间框架选择.swift", duty: "时间框架选择器"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("时间框架选择骨架校验通过")
        return KXHealthCheckItem(name: "时间框架选择", passed: true, message: "时间框架选择器")
    }
}
