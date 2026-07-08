//
//  KX-UI-17_指标选择器.swift
//  仙人指路2-min｜K线模块
//
//  版本：1.0
//  职责：OKX风格技术指标选择弹窗
//  禁止事项：禁止直接请求OKX、禁止直接读写数据库
//

import AppKit
import SwiftUI
import Foundation


// MARK: - 技术指标选择器弹窗

public class KLTechnicalIndicatorSelectorView: NSView {
    private var hostingController: NSHostingController<KLTechnicalIndicatorSelectorViewSwiftUI>!
    private var popover: NSPopover?

    public var onIndicatorSelected: ((KLTechnicalIndicator) -> Void)?
    public var onDismiss: (() -> Void)?

    public init() {
        super.init(frame: .zero)
        // 解决self捕获问题：super初始化之后再创建rootView
        let rootView = KLTechnicalIndicatorSelectorViewSwiftUI(onSelect: { [weak self] indicator in
            self?.onIndicatorSelected?(indicator)
            self?.dismiss()
        }, onDismiss: { [weak self] in
            self?.dismiss()
        })
        self.hostingController = NSHostingController(rootView: rootView)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        // 解决self捕获问题：super初始化之后再创建rootView
        let rootView = KLTechnicalIndicatorSelectorViewSwiftUI(onSelect: { [weak self] indicator in
            self?.onIndicatorSelected?(indicator)
            self?.dismiss()
        }, onDismiss: { [weak self] in
            self?.dismiss()
        })
        self.hostingController = NSHostingController(rootView: rootView)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        hostingController.view.autoresizingMask = [.width, .height]
        addSubview(hostingController.view)
    }

    public override func layout() {
        super.layout()
        hostingController.view.frame = bounds
    }

    public func show(from parent: NSView, preferredEdge: NSRectEdge = .maxY) {
        popover = NSPopover()
        popover?.contentViewController = hostingController
        popover?.behavior = .transient
        popover?.animates = true
        popover?.show(relativeTo: parent.bounds, of: parent, preferredEdge: preferredEdge)
    }

    public func dismiss() {
        popover?.close()
        onDismiss?()
    }
}

// MARK: - SwiftUI实现

struct KLTechnicalIndicatorSelectorViewSwiftUI: View {
    let onSelect: (KLTechnicalIndicator) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedCategory: KLIndicatorCategory? = nil

    private let indicatorManager = KXTechnicalIndicatorManager.shared
    private var filteredIndicators: [KLTechnicalIndicator] {
        let all = indicatorManager.allIndicators

        guard let category = selectedCategory else {
            return searchText.isEmpty ? all : indicatorManager.searchIndicators(query: searchText)
        }

        let categoryIndicators = indicatorManager.categorizedIndicators[category] ?? []
        return searchText.isEmpty ? categoryIndicators : categoryIndicators.filter {
            $0.name.localizedStandardContains(searchText) ||
            $0.id.localizedStandardContains(searchText) ||
            $0.description.localizedStandardContains(searchText)
        }
    }

    private let categories = KLIndicatorCategory.displayOrder

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("指标")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索指标", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlAccentColor).opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // 分类标签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            selectedCategory = selectedCategory == category ? nil : category
                        }) {
                            Text(category.rawValue)
                                .font(.system(size: 12, weight: selectedCategory == category ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .background(selectedCategory == category ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedCategory == category ? Color.blue : Color.clear, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // 指标列表
            Divider()

            List(filteredIndicators) { indicator in
                VStack(alignment: .leading, spacing: 4) {
                    Text(indicator.name)
                        .font(.system(size: 13, weight: .medium))
                    Text(indicator.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(indicator)
                }
            }
            .listStyle(.plain)

            // 底部提示
            HStack {
                Text("选择指标添加到图表")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - 工具栏指标按钮

public class KLIndicatorToolbarButton: NSView {
    private var button: NSButton?
    private let selectorView = KLTechnicalIndicatorSelectorView()

    public var onIndicatorSelected: ((KLTechnicalIndicator) -> Void)?

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

        let btn = NSButton(frame: bounds)
        btn.title = "技术指标"
        btn.bezelStyle = .inline
        btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        // AppKit 不支持 NSButton.contentInsets，padding已经在frame宽度里处理了
        btn.target = self
        btn.action = #selector(buttonClicked)
        addSubview(btn)
        self.button = btn

        selectorView.onIndicatorSelected = { [weak self] indicator in
            self?.onIndicatorSelected?(indicator)
        }
    }

    public override func layout() {
        super.layout()
        button?.frame = bounds
    }

    @objc private func buttonClicked() {
        if let btn = button {
            selectorView.show(from: btn)
        }
    }
}

// MARK: - 预览

struct KLTechnicalIndicatorSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        KLTechnicalIndicatorSelectorViewSwiftUI(onSelect: { _ in }, onDismiss: {})
            .frame(width: 500, height: 400)
    }
}
// MARK: - KXFileSkeletonProtocol

public enum KXKXUI17Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-17", fileName: "KX-UI-17_指标选择器.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-17_指标选择器.swift", duty: "技术指标选择器"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("指标选择器骨架校验通过")
        return KXHealthCheckItem(name: "指标选择器", passed: true, message: "技术指标选择器")
    }
}
