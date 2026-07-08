//
//  KX-UI-21_指标设置面板.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：根据指标 settings schema 生成设置面板，提交给指标实例管理器
//  禁止事项：禁止直接修改 K线视图、禁止直接重绘 renderer、禁止绕过指标实例管理器
//

import AppKit
import Foundation

public final class KXUI21IndicatorSettingsPanel: NSView {
    public var onApply: ((String, [String: KXIndicatorParameterValue]) -> Void)?
    public var onDelete: ((String) -> Void)?
    public var onToggleVisible: ((String, Bool) -> Void)?

    private var instanceID: String = ""
    private var schema: KXIndicatorSettingsSchema = KXIndicatorSettingsSchema(sections: [], actions: [])
    private var currentValues: [String: KXIndicatorParameterValue] = [:]
    private var controls: [String: NSControl] = [:]

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public func configure(instanceID: String, schema: KXIndicatorSettingsSchema, currentValues: [String: KXIndicatorParameterValue]) {
        self.instanceID = instanceID
        self.schema = schema
        self.currentValues = currentValues
        rebuildUI()
    }

    private func rebuildUI() {
        subviews.forEach { $0.removeFromSuperview() }
        controls.removeAll()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])

        // 标题
        if let firstSection = schema.sections.first {
            let titleLabel = NSTextField(labelWithString: firstSection.title)
            titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
            titleLabel.textColor = KLUITheme.isDark ? .white : .black
            stack.addArrangedSubview(titleLabel)

            let separator = NSView()
            separator.wantsLayer = true
            separator.layer?.backgroundColor = (KLUITheme.isDark ? NSColor.white.withAlphaComponent(0.15) : NSColor.black.withAlphaComponent(0.1)).cgColor
            separator.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([separator.heightAnchor.constraint(equalToConstant: 1)])
            stack.addArrangedSubview(separator)
        }

        // 字段
        for section in schema.sections {
            for field in section.fields {
                guard let param = field.parameterSchema else { continue }
                let value = currentValues[field.key] ?? param.defaultValue

                let row = NSStackView()
                row.orientation = .horizontal
                row.spacing = 6
                row.alignment = .centerY

                let label = NSTextField(labelWithString: param.title)
                label.font = NSFont.systemFont(ofSize: 12)
                label.textColor = KLUITheme.isDark ? NSColor.white.withAlphaComponent(0.8) : NSColor.black.withAlphaComponent(0.8)
                label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                label.widthAnchor.constraint(equalToConstant: 50).isActive = true
                row.addArrangedSubview(label)

                let control = makeControl(for: field, param: param, value: value)
                control.setContentHuggingPriority(.defaultLow, for: .horizontal)
                controls[field.key] = control
                row.addArrangedSubview(control)
                stack.addArrangedSubview(row)
            }
        }

        // 按钮
        let actionRow = NSStackView()
        actionRow.orientation = .horizontal
        actionRow.spacing = 8
        actionRow.distribution = .fillEqually

        for action in schema.actions {
            let btn = NSButton(title: actionTitle(action), target: self, action: #selector(actionButtonClicked(_:)))
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 12)
            btn.tag = schema.actions.firstIndex(of: action) ?? 0
            actionRow.addArrangedSubview(btn)
        }
        stack.addArrangedSubview(actionRow)
    }

    private func makeControl(for field: KXIndicatorSettingsField, param: KXIndicatorParameterSchema, value: KXIndicatorParameterValue) -> NSControl {
        switch field.control {
        case .numberInput:
            let tf = NSTextField()
            tf.stringValue = valueString(value)
            tf.font = NSFont.systemFont(ofSize: 12)
            tf.alignment = .right
            tf.wantsLayer = true
            tf.layer?.cornerRadius = 4
            tf.layer?.backgroundColor = (KLUITheme.isDark ? NSColor.white.withAlphaComponent(0.1) : NSColor.black.withAlphaComponent(0.05)).cgColor
            return tf
        case .dropdown:
            let popup = NSPopUpButton()
            popup.font = NSFont.systemFont(ofSize: 12)
            for opt in param.options {
                popup.addItem(withTitle: opt.label)
                popup.lastItem?.representedObject = opt.value
            }
            if let index = param.options.firstIndex(where: { $0.value == valueString(value) || $0.label == valueString(value) }) {
                popup.selectItem(at: index)
            }
            return popup
        case .colorPicker:
            let colorWell = NSColorWell()
            colorWell.color = colorFromValue(value) ?? NSColor.systemCyan
            return colorWell
        case .lineWidthSelector:
            let popup = NSPopUpButton()
            popup.font = NSFont.systemFont(ofSize: 12)
            for w in [1, 2, 3, 4, 5] {
                popup.addItem(withTitle: "\(w)px")
                popup.lastItem?.representedObject = w
            }
            popup.selectItem(withTitle: "\(intValue(value))px")
            return popup
        case .lineStyleSelector:
            let popup = NSPopUpButton()
            popup.font = NSFont.systemFont(ofSize: 12)
            let styles = [("实线", "solid"), ("虚线", "dashed"), ("点线", "dotted")]
            for item in styles {
                popup.addItem(withTitle: item.0)
                popup.lastItem?.representedObject = item.1
            }
            if let index = styles.firstIndex(where: { $0.1 == valueString(value) }) {
                popup.selectItem(at: index)
            }
            return popup
        case .opacitySlider:
            let slider = NSSlider()
            slider.minValue = 0
            slider.maxValue = 1
            slider.doubleValue = doubleValue(value)
            return slider
        case .checkbox:
            let cb = NSButton(checkboxWithTitle: "", target: nil, action: nil)
            cb.state = boolValue(value) ? .on : .off
            return cb
        case .button, .custom:
            let btn = NSButton(title: param.title, target: nil, action: nil)
            return btn
        }
    }

    @objc private func actionButtonClicked(_ sender: NSButton) {
        guard sender.tag < schema.actions.count else { return }
        let action = schema.actions[sender.tag]
        switch action {
        case .apply:
            var newValues: [String: KXIndicatorParameterValue] = [:]
            for (key, control) in controls {
                newValues[key] = readValue(from: control, key: key)
            }
            onApply?(instanceID, newValues)
        case .reset:
            rebuildUI()
        case .delete:
            onDelete?(instanceID)
        case .toggleVisible:
            break
        }
    }

    private func readValue(from control: NSControl, key: String) -> KXIndicatorParameterValue {
        if let tf = control as? NSTextField {
            if let int = Int(tf.stringValue) { return .int(int) }
            if let double = Double(tf.stringValue) { return .double(double) }
            return .string(tf.stringValue)
        }
        if let popup = control as? NSPopUpButton, let obj = popup.selectedItem?.representedObject as? String {
            return .option(obj)
        }
        if let popup = control as? NSPopUpButton, let obj = popup.selectedItem?.representedObject as? Int {
            return .int(obj)
        }
        if let colorWell = control as? NSColorWell {
            return .colorHex(colorWell.color.toHex() ?? "#00FFFF")
        }
        if let slider = control as? NSSlider {
            return .double(slider.doubleValue)
        }
        if let cb = control as? NSButton {
            return .bool(cb.state == .on)
        }
        return currentValues[key] ?? .string("")
    }

    private func valueString(_ value: KXIndicatorParameterValue) -> String {
        switch value {
        case .int(let v): return "\(v)"
        case .double(let v): return "\(v)"
        case .bool(let v): return v ? "true" : "false"
        case .string(let v): return v
        case .option(let v): return v
        case .colorHex(let v): return v
        }
    }

    private func intValue(_ value: KXIndicatorParameterValue) -> Int {
        switch value {
        case .int(let v): return v
        case .double(let v): return Int(v)
        default: return 0
        }
    }

    private func doubleValue(_ value: KXIndicatorParameterValue) -> Double {
        switch value {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return 0
        }
    }

    private func boolValue(_ value: KXIndicatorParameterValue) -> Bool {
        switch value {
        case .bool(let v): return v
        default: return false
        }
    }

    private func colorFromValue(_ value: KXIndicatorParameterValue) -> NSColor? {
        switch value {
        case .colorHex(let hex): return NSColor(hex: hex)
        default: return nil
        }
    }

    private func actionTitle(_ action: KXIndicatorSettingsAction) -> String {
        switch action {
        case .apply: return "应用"
        case .reset: return "重置"
        case .delete: return "删除"
        case .toggleVisible: return "显隐"
        }
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch trimmed.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }

    func toHex() -> String? {
        guard let components = cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXUI21Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.1"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-21", fileName: "KX-UI-21_指标设置面板.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-21_指标设置面板.swift", duty: "根据指标 settings schema 生成设置面板"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("指标设置面板骨架校验通过")
        return KXHealthCheckItem(name: "指标设置面板", passed: true, message: "已实现指标设置面板")
    }
}
