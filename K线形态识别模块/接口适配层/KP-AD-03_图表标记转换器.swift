// KP-AD-03_图表标记转换器.swift
// K线形态识别模块｜接口适配层
// 职责：保留图表标记转换器文件身份，实际 KPAD04 标记输出类型在 KP-AD-04 中承载。
// 禁止事项：禁止运行形态识别算法、禁止维护注册表、禁止 UI 绘制、禁止网络/数据库读写。

import Foundation

public struct KPAD03PatternMarkerConverter: Sendable {
    public let wrapped: KPAD04PatternMarkerConverter
    public init(policy: KPAD04ConversionPolicy = KPAD04ConversionPolicy()) { self.wrapped = KPAD04PatternMarkerConverter(policy: policy) }
    public func convert(_ signals: [KPAD04PatternSignalInput], createdAt: Date = Date()) -> KPAD04ConversionResult { wrapped.convert(signals, createdAt: createdAt) }
    public func convert(_ signal: KPAD04PatternSignalInput, createdAt: Date = Date()) -> KLMarkerDescriptor? { wrapped.convert(signal, createdAt: createdAt) }
}

public enum KPAD03PatternMarkerConverterSkeleton: KPFileSkeletonProtocol {
    public static let descriptor = KPModuleRegistry.descriptor(id: "KP-AD-03") ?? KPFileDescriptor(id: "KP-AD-03", fileName: "KP-AD-03_图表标记转换器.swift", layer: .adapter, relativePath: "接口适配层/KP-AD-03_图表标记转换器.swift", duty: "图表标记转换器文件身份与健康检查")
    public static func skeletonStatus() -> KPHealthCheckItem {
        KPHealthCheckItem(name: descriptor.id, passed: true, message: "KP-AD-03 保留转换器文件身份；KPAD04 标准标记输出类型由 KP-AD-04 承载")
    }
}
