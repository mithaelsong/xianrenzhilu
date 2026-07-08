// KP-01_模块注册表.swift
// K线形态识别模块统一文件注册表

import Foundation

public enum KPModuleLayer: String, Codable, Sendable, CaseIterable {
    case management = "管理层"
    case definition = "形态定义层"
    case engine = "识别引擎层"
    case adapter = "接口适配层"
    case configuration = "配置层"
    case event = "事件层"
    case test = "测试层"
    case document = "文档"
}

public struct KPFileDescriptor: Codable, Equatable, Sendable {
    public let id: String
    public let fileName: String
    public let layer: KPModuleLayer
    public let relativePath: String
    public let duty: String
    public let required: Bool

    public init(id: String, fileName: String, layer: KPModuleLayer, relativePath: String, duty: String, required: Bool = true) {
        self.id = id
        self.fileName = fileName
        self.layer = layer
        self.relativePath = relativePath
        self.duty = duty
        self.required = required
    }
}

public enum KPModuleRegistry {
    public static let moduleName = "K线形态识别模块"
    public static let rootDirectoryName = "K线形态识别模块"
    public static let version = "3.0"
    public static let expectedPatternCount = 29
    public static let expectedSettingOptionCount = 30

    public static let files: [KPFileDescriptor] = [
        KPFileDescriptor(id: "KP-00", fileName: "KP-00_模块入口.swift", layer: .management, relativePath: "管理层/KP-00_模块入口.swift", duty: "独立模块启动、文件校验、能力自检"),
        KPFileDescriptor(id: "KP-01", fileName: "KP-01_模块注册表.swift", layer: .management, relativePath: "管理层/KP-01_模块注册表.swift", duty: "模块文件清单和职责注册"),
        KPFileDescriptor(id: "KP-02", fileName: "KP-02_公共类型定义.swift", layer: .management, relativePath: "管理层/KP-02_公共类型定义.swift", duty: "公共类型、协议、健康检查模型"),
        KPFileDescriptor(id: "KP-DF-01", fileName: "KP-DF-01_形态类型定义.swift", layer: .definition, relativePath: "形态定义层/KP-DF-01_形态类型定义.swift", duty: "29个内置K线形态定义、形态库"),
        KPFileDescriptor(id: "KP-DF-03", fileName: "KP-DF-03_自定义形态定义.swift", layer: .definition, relativePath: "形态定义层/KP-DF-03_自定义形态定义.swift", duty: "用户自定义形态规则和计算器"),
        KPFileDescriptor(id: "KP-EN-01", fileName: "KP-EN-01_形态识别引擎.swift", layer: .engine, relativePath: "识别引擎层/KP-EN-01_形态识别引擎.swift", duty: "单根、双根、多根形态识别算法"),
        KPFileDescriptor(id: "KP-EN-02", fileName: "KP-EN-02_形态监听器.swift", layer: .engine, relativePath: "识别引擎层/KP-EN-02_形态监听器.swift", duty: "基于数据源的形态监听与增量检查"),
        KPFileDescriptor(id: "KP-AD-01", fileName: "KP-AD-01_外部上下文适配器.swift", layer: .adapter, relativePath: "接口适配层/KP-AD-01_外部上下文适配器.swift", duty: "K线模块Candle输入适配和指标上下文桥接"),
        KPFileDescriptor(id: "KP-AD-02", fileName: "KP-AD-02_形态信号输出接口.swift", layer: .adapter, relativePath: "接口适配层/KP-AD-02_形态信号输出接口.swift", duty: "形态识别结果到标准标记信号的转换"),
        KPFileDescriptor(id: "KP-AD-03", fileName: "KP-AD-03_图表标记转换器.swift", layer: .adapter, relativePath: "接口适配层/KP-AD-03_图表标记转换器.swift", duty: "形态信号到K线图表标记的转换和管理"),
        KPFileDescriptor(id: "KP-AD-04", fileName: "KP-AD-04_图表标记输出接口.swift", layer: .adapter, relativePath: "接口适配层/KP-AD-04_图表标记输出接口.swift", duty: "图表标记输出接口占位与健康检查"),
        KPFileDescriptor(id: "KP-AD-05", fileName: "KP-AD-05_形态结果标记桥.swift", layer: .adapter, relativePath: "接口适配层/KP-AD-05_形态结果标记桥.swift", duty: "识别结果到图表标记输入的桥接"),
        KPFileDescriptor(id: "KP-CF-01", fileName: "KP-CF-01_形态识别设置配置.swift", layer: .configuration, relativePath: "配置层/KP-CF-01_形态识别设置配置.swift", duty: "UI设置面板读取的形态识别设置项"),
        KPFileDescriptor(id: "KP-EV-02", fileName: "KP-EV-02_形态提醒事件.swift", layer: .event, relativePath: "事件层/KP-EV-02_形态提醒事件.swift", duty: "形态识别提醒事件生成"),
        KPFileDescriptor(id: "KP-TS-01", fileName: "KP-TS-01_模块结构测试.swift", layer: .test, relativePath: "测试层/KP-TS-01_模块结构测试.swift", duty: "模块结构和核心能力自检"),
        KPFileDescriptor(id: "KP-DOC-01", fileName: "K线形态识别图鉴.md", layer: .document, relativePath: "文档/K线形态识别图鉴.md", duty: "形态识别图鉴", required: false),
        KPFileDescriptor(id: "KP-DOC-02", fileName: "K线形态识别指标总表_20260626.md", layer: .document, relativePath: "文档/K线形态识别指标总表_20260626.md", duty: "形态指标总表", required: false)
    ]

    public static var swiftFiles: [KPFileDescriptor] { files.filter { $0.fileName.hasSuffix(".swift") } }
    public static func descriptor(id: String) -> KPFileDescriptor? { files.first { $0.id == id } }
    public static func descriptors(layer: KPModuleLayer) -> [KPFileDescriptor] { files.filter { $0.layer == layer } }
}
