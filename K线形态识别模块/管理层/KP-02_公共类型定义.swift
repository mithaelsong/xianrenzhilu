// KP-02_公共类型定义.swift
// K线形态识别模块公共类型定义
// 职责：仅存放独立模块公共 struct / enum / protocol / typealias，不放业务实现。

import Foundation

public struct Candle: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let symbol: String?
    public let timeframe: String?
    public let openTime: Date
    public let closeTime: Date?
    public let open: Decimal
    public let high: Decimal
    public let low: Decimal
    public let close: Decimal
    public let volume: Decimal
    public let isClosed: Bool

    public init(id: String = UUID().uuidString, symbol: String? = nil, timeframe: String? = nil, openTime: Date, closeTime: Date? = nil, open: Decimal, high: Decimal, low: Decimal, close: Decimal, volume: Decimal = 0, isClosed: Bool = true) {
        self.id = id
        self.symbol = symbol
        self.timeframe = timeframe
        self.openTime = openTime
        self.closeTime = closeTime
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.isClosed = isClosed
    }
}

public enum CandlePatternVolumeSignal: String, Codable, Sendable, CaseIterable {
    case unknown, low, normal, high, spike
}

public protocol CandleDataSource: AnyObject {
    func loadCandles(symbol: String, interval: String, limit: Int) -> [Candle]
}

public protocol KPFileSkeletonProtocol {
    static var descriptor: KPFileDescriptor { get }
    static func skeletonStatus() -> KPHealthCheckItem
}

public enum KPHealthSeverity: String, Codable, Sendable, CaseIterable {
    case info, warning, high
}

public struct KPHealthCheckItem: Codable, Equatable, Sendable {
    public let name: String
    public let passed: Bool
    public let message: String
    public let severity: KPHealthSeverity

    public init(name: String, passed: Bool, message: String, severity: KPHealthSeverity = .info) {
        self.name = name
        self.passed = passed
        self.message = message
        self.severity = severity
    }
}

public struct KPModuleStartupReport: Codable, Equatable, Sendable {
    public let moduleName: String
    public let rootDirectoryName: String
    public let fileCount: Int
    public let swiftFileCount: Int
    public let patternCount: Int
    public let settingOptionCount: Int
    public let healthItems: [KPHealthCheckItem]

    public init(moduleName: String, rootDirectoryName: String, fileCount: Int, swiftFileCount: Int, patternCount: Int, settingOptionCount: Int, healthItems: [KPHealthCheckItem]) {
        self.moduleName = moduleName
        self.rootDirectoryName = rootDirectoryName
        self.fileCount = fileCount
        self.swiftFileCount = swiftFileCount
        self.patternCount = patternCount
        self.settingOptionCount = settingOptionCount
        self.healthItems = healthItems
    }
}
