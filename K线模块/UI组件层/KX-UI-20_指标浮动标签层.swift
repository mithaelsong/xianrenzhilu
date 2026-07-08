//
//  KX-UI-20_指标浮动标签层.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：指标 chip 快照类型定义（视图实现已迁移到 KX-UI-12 内建 overlay）
//  禁止事项：禁止使用 NSStackView 参与主布局、禁止修改 candleLayer/volumeLayer frame、禁止高度超过 24
//

import Foundation

public struct KXIndicatorChipSnapshot: Equatable, Sendable {
    public let instanceID: String
    public let outputKey: String?
    public let pane: KLOverlayPane
    public let paneID: String?
    public let text: String
    public let colorHex: String?
    public let visible: Bool

    public init(instanceID: String, outputKey: String? = nil, pane: KLOverlayPane, paneID: String? = nil, text: String, colorHex: String? = nil, visible: Bool = true) {
        self.instanceID = instanceID
        self.outputKey = outputKey
        self.pane = pane
        self.paneID = paneID
        self.text = text
        self.colorHex = colorHex
        self.visible = visible
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXUI20Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.1"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-20", fileName: "KX-UI-20_指标浮动标签层.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-20_指标浮动标签层.swift", duty: "指标 chip 快照类型定义"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("指标浮动标签层骨架校验通过")
        return KXHealthCheckItem(name: "指标浮动标签层", passed: true, message: "指标 chip 快照类型已保留")
    }
}
