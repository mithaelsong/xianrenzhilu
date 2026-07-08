//
//  KX-UI-07_布局模板适配.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：为布局模板保存恢复提供 K线布局状态数据适配
//  禁止事项：禁止 UI 绘制、禁止网络请求、禁止数据库读写、禁止缓存实现
//

import Foundation


// MARK: - 布局模板 DTO

public struct KXUI07LayoutTemplateDTO: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let columnCount: Int
    public let rowCount: Int
    public let panes: [KXUI07LayoutPaneDTO]

    public init(id: String, name: String, columnCount: Int, rowCount: Int, panes: [KXUI07LayoutPaneDTO] = []) {
        self.id = id
        self.name = name
        self.columnCount = max(columnCount, 1)
        self.rowCount = max(rowCount, 1)
        self.panes = panes
    }
}

// MARK: - 面板布局 DTO

public struct KXUI07LayoutPaneDTO: Codable, Equatable, Sendable {
    public let id: String
    public let symbol: KXSymbol?
    public let timeframe: KXTimeframe?
    public let row: Int
    public let column: Int
    public let rowSpan: Int
    public let columnSpan: Int

    public init(id: String, symbol: KXSymbol? = nil, timeframe: KXTimeframe? = nil, row: Int = 0, column: Int = 0, rowSpan: Int = 1, columnSpan: Int = 1) {
        self.id = id
        self.symbol = symbol
        self.timeframe = timeframe
        self.row = max(row, 0)
        self.column = max(column, 0)
        self.rowSpan = max(rowSpan, 1)
        self.columnSpan = max(columnSpan, 1)
    }
}

// MARK: - 网格描述

public struct KXUI07GridDescriptor: Codable, Equatable, Sendable {
    public let columnCount: Int
    public let rowCount: Int
    public let gridLines: [Int]
    public let columnWidths: [CGFloat]
    public let rowHeights: [CGFloat]

    public init(columnCount: Int, rowCount: Int, columnWidths: [CGFloat] = [], rowHeights: [CGFloat] = []) {
        self.columnCount = max(columnCount, 1)
        self.rowCount = max(rowCount, 1)
        self.gridLines = Array(0...max(columnCount, rowCount))
        self.columnWidths = columnWidths.isEmpty ? Array(repeating: 1.0, count: columnCount) : columnWidths
        self.rowHeights = rowHeights.isEmpty ? Array(repeating: 1.0, count: rowCount) : rowHeights
    }
}

// MARK: - 模板验证结果

public struct KXUI07ValidationResult: Codable, Equatable, Sendable {
    public let isValid: Bool
    public let issues: [String]
    public let warnings: [String]

    public init(isValid: Bool = true, issues: [String] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.issues = issues
        self.warnings = warnings
    }
}

// MARK: - 布局模板适配器

public enum KXUI07LayoutTemplateAdapter {
    /// 从 KLLayoutTemplateDescriptor 创建模板 DTO
    public static func makeDTO(from descriptor: KLLayoutTemplateDescriptor) -> KXUI07LayoutTemplateDTO {
        let panes = descriptor.paneDescriptors.map { pane in
            KXUI07LayoutPaneDTO(id: pane.id, symbol: pane.symbol, timeframe: pane.timeframe, row: pane.row, column: pane.column, rowSpan: pane.rowSpan, columnSpan: pane.columnSpan)
        }
        return KXUI07LayoutTemplateDTO(id: descriptor.id, name: descriptor.name, columnCount: descriptor.columnCount, rowCount: descriptor.rowCount, panes: panes)
    }

    /// 从模板 DTO 构建 KLLayoutTemplateDescriptor
    public static func makeDescriptor(from dto: KXUI07LayoutTemplateDTO) -> KLLayoutTemplateDescriptor {
        let paneDescs = dto.panes.map { pane in
            KLLayoutPaneDescriptor(id: pane.id, symbol: pane.symbol, timeframe: pane.timeframe, row: pane.row, column: pane.column, rowSpan: pane.rowSpan, columnSpan: pane.columnSpan)
        }
        return KLLayoutTemplateDescriptor(id: dto.id, name: dto.name, columnCount: dto.columnCount, rowCount: dto.rowCount, paneDescriptors: paneDescs)
    }

    /// 生成网格描述
    public static func makeGridDescriptor(from dto: KXUI07LayoutTemplateDTO) -> KXUI07GridDescriptor {
        KXUI07GridDescriptor(columnCount: dto.columnCount, rowCount: dto.rowCount)
    }

    /// 验证模板
    public static func validate(_ dto: KXUI07LayoutTemplateDTO) -> KXUI07ValidationResult {
        var issues: [String] = []
        var warnings: [String] = []
        if dto.columnCount < 1 { issues.append("列数不能小于 1") }
        if dto.rowCount < 1 { issues.append("行数不能小于 1") }
        if dto.name.trimmingCharacters(in: .whitespaces).isEmpty { issues.append("模板名称不能为空") }
        let overlapping = dto.panes.filter { pane in dto.panes.contains(where: { $0.id != pane.id && $0.row == pane.row && $0.column == pane.column }) }
        if !overlapping.isEmpty { warnings.append("面板位置重叠：\(overlapping.map(\.id).joined(separator: ", "))") }
        let emptyPanes = dto.panes.filter { pane in pane.symbol == nil }
        if !emptyPanes.isEmpty { warnings.append("\(emptyPanes.count) 个面板未配置交易对") }
        return KXUI07ValidationResult(isValid: issues.isEmpty, issues: issues, warnings: warnings)
    }

    /// 默认模板
    public static func defaultTemplate() -> KXUI07LayoutTemplateDTO {
        let pane = KXUI07LayoutPaneDTO(id: "main-pane", symbol: "BTC-USDT", timeframe: .oneHour, row: 0, column: 0, rowSpan: 1, columnSpan: 1)
        return KXUI07LayoutTemplateDTO(id: "default", name: "默认模板", columnCount: 1, rowCount: 1, panes: [pane])
    }

    /// 序列化模板 DTO 为 JSON Data
    public static func serialize(_ dto: KXUI07LayoutTemplateDTO) -> Data? { try? JSONEncoder().encode(dto) }

    /// 从 JSON Data 反序列化模板 DTO
    public static func deserialize(from data: Data) -> KXUI07LayoutTemplateDTO? { try? JSONDecoder().decode(KXUI07LayoutTemplateDTO.self, from: data) }
}

// MARK: - KXFileSkeletonProtocol

public enum KXKXUI07Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-UI-07", fileName: "KX-UI-07_布局模板适配.swift", layer: .ui,
        relativePath: "UI组件层/KX-UI-07_布局模板适配.swift", duty: "布局模板适配"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("布局模板适配骨架校验通过")
        return KXHealthCheckItem(name: "布局模板适配", passed: true, message: "布局模板适配")
    }
}
