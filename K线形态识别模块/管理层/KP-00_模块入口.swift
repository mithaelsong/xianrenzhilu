// KP-00_模块入口.swift
// K线形态识别模块入口
// 职责：模块启动装配、文件清单校验、健康检查汇总。
// 禁止事项：禁止识别算法、禁止注册表实现、禁止监听器实现、禁止 UI 绘制、禁止网络/数据库读写。

import Foundation

/// K线形态识别独立模块入口。
/// 职责：按独立根目录校验文件清单，执行模块健康检查，输出启动报告。
/// 约束：不属于 K线模块内部启动；不拉取网络、不读写数据库、不绘制 UI。
public enum KPModuleEntry {
    public static let version = "3.0"
    public static let moduleName = KPModuleRegistry.moduleName

    public static func start(basePath: String) -> KPModuleStartupReport {
        let normalizedBasePath = (basePath as NSString).standardizingPath
        var items: [KPHealthCheckItem] = []

        let inCorrectDir = normalizedBasePath.hasSuffix(KPModuleRegistry.rootDirectoryName)
        items.append(KPHealthCheckItem(
            name: "执行边界检查",
            passed: inCorrectDir,
            message: inCorrectDir ? "启动验收限定在K线形态识别模块内" : "basePath不在K线形态识别模块范围内",
            severity: inCorrectDir ? .info : .high
        ))

        for descriptor in KPModuleRegistry.files {
            let fullPath = (normalizedBasePath as NSString).appendingPathComponent(descriptor.relativePath)
            let exists = FileManager.default.fileExists(atPath: fullPath)
            items.append(KPHealthCheckItem(
                name: "文件存在：\(descriptor.id)",
                passed: exists,
                message: exists ? "\(descriptor.relativePath)存在" : "\(descriptor.relativePath)缺失",
                severity: exists ? .info : .high
            ))
        }

        items.append(healthCheck())

        return KPModuleStartupReport(
            moduleName: moduleName,
            rootDirectoryName: KPModuleRegistry.rootDirectoryName,
            fileCount: KPModuleRegistry.files.count,
            swiftFileCount: KPModuleRegistry.swiftFiles.count,
            patternCount: CandlePatternLibrary.shared.allPatterns.count,
            settingOptionCount: KPPatternSettingsCatalog.builtinOptions().count,
            healthItems: items
        )
    }

    public static func healthCheck() -> KPHealthCheckItem {
        let patternCount = CandlePatternLibrary.shared.allPatterns.count
        let passed = patternCount >= KPModuleRegistry.expectedPatternCount
        return KPHealthCheckItem(
            name: "形态识别模块健康检查",
            passed: passed,
            message: passed ? "形态库已加载：\(patternCount)种" : "形态库数量不足：\(patternCount)/\(KPModuleRegistry.expectedPatternCount)",
            severity: passed ? .info : .high
        )
    }
}
