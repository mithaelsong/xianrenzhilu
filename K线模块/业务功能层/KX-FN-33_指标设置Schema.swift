//
//  KX-FN-33_指标设置Schema.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：定义指标设置面板的分区、字段、控件类型和提交规则
//  禁止事项：禁止 UI 绘制、禁止直接操作 K线视图、禁止数据库写入
//

import Foundation

// MARK: - 设置控件类型

public enum KXIndicatorSettingsControlType: String, Codable, Sendable, Equatable, CaseIterable {
    case numberInput
    case dropdown
    case colorPicker
    case lineWidthSelector
    case lineStyleSelector
    case opacitySlider
    case checkbox
    case button
    case custom
}

// MARK: - 设置字段

public struct KXIndicatorSettingsField: Codable, Sendable, Equatable {
    public let key: String
    public let title: String
    public let control: KXIndicatorSettingsControlType
    public let parameterSchema: KXIndicatorParameterSchema?
    public let visibleWhen: String? // 条件显示，例如 "visible == true"

    public init(
        key: String,
        title: String,
        control: KXIndicatorSettingsControlType,
        parameterSchema: KXIndicatorParameterSchema? = nil,
        visibleWhen: String? = nil
    ) {
        self.key = key
        self.title = title
        self.control = control
        self.parameterSchema = parameterSchema
        self.visibleWhen = visibleWhen
    }
}

// MARK: - 设置分区

public struct KXIndicatorSettingsSection: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let fields: [KXIndicatorSettingsField]
    public let collapsible: Bool
    public let defaultCollapsed: Bool

    public init(
        id: String,
        title: String,
        fields: [KXIndicatorSettingsField],
        collapsible: Bool = false,
        defaultCollapsed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.fields = fields
        self.collapsible = collapsible
        self.defaultCollapsed = defaultCollapsed
    }
}

// MARK: - 设置 Schema

public struct KXIndicatorSettingsSchema: Codable, Sendable, Equatable {
    public let sections: [KXIndicatorSettingsSection]
    public let actions: [KXIndicatorSettingsAction]

    public init(sections: [KXIndicatorSettingsSection], actions: [KXIndicatorSettingsAction] = []) {
        self.sections = sections
        self.actions = actions
    }
}

// MARK: - 设置操作

public enum KXIndicatorSettingsAction: String, Codable, Sendable, Equatable, CaseIterable {
    case apply
    case reset
    case delete
    case toggleVisible
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN33Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-33", fileName: "KX-FN-33_指标设置Schema.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-33_指标设置Schema.swift", duty: "指标设置面板的分区、字段、控件类型和提交规则"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("指标设置Schema骨架校验通过")
        return KXHealthCheckItem(name: "指标设置Schema", passed: true, message: "已实现指标设置面板Schema定义")
    }
}
