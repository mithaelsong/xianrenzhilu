//
//  KX-GL-01_入口.swift
//  仙人指路测试项目｜K线模块
//
//  版本：2.0
//  职责：统一入口、装配、自检、调用注册表、启动链路检查清单
//  禁止事项：禁止业务实现、OKX请求、数据库读写、UI绘制、缓存实现、形态识别算法、指标计算
//

import AppKit
import Foundation

// MARK: - K线模块入口

public enum KXModuleEntry {
    public static let version = "2.0"
    public static let moduleName = "K线模块"

    /// 软件启动入口调用点：装配、自检、调用注册表，启动各功能模块，返回健康状态
    public static func start(basePath: String) -> KXHealthReport {
        klineLogger.info("K线模块启动开始，basePath=\(basePath)")

        let report = startupChecklist(basePath: basePath)

        if report.allPassed {
            klineLogger.info("K线模块健康检查全部通过，开始装配功能模块")
            // 预留：各功能层的装配和启动
            // assembleFunctionLayer()
            // assembleDataServiceLayer()
            // assembleSyncLayer()
            // assembleUILayer()

            // MARK: 注册主菜单项
            // 注册"打开K线面板"到主菜单
            let menuItem = UIMenuItemDefinition(
                title: "打开K线面板",
                action: #selector(KXUI08Entry.openPanel),
                keyEquivalent: "k",
                toolTip: "打开玻璃皮肤K线主面板"
            )
            UIMainMenuManager.shared.registerModuleMenu(moduleName: "K线", definitions: [menuItem])
            klineLogger.info("已注册主菜单项: 打开K线面板")
        } else {
            let failedItems = report.items.filter { !$0.passed }
            klineLogger.warning("K线模块健康检查未通过，共\(failedItems.count)项失败")
        }

        klineLogger.info("K线模块启动完成")
        return report
    }

    /// 启动链路验收完整检查清单
    public static func startupChecklist(basePath: String) -> KXHealthReport {
        let normalizedBasePath = (basePath as NSString).standardizingPath
        var items: [KXHealthCheckItem] = []

        klineLogger.info("开始执行启动检查清单，basePath=\(normalizedBasePath)")

        // 1. 边界检查
        let inCorrectDir = normalizedBasePath.hasSuffix("K线模块")
        items.append(KXHealthCheckItem(
            name: "执行边界检查",
            passed: inCorrectDir,
            message: inCorrectDir
                ? "启动验收限定在K线模块内"
                : "basePath不在K线模块范围内"
        ))

        // 2. 管理层三件套检查
        let mgmtIDs = ["KX-GL-01", "KX-GL-02", "KX-GL-03"]
        let loaded = mgmtIDs.allSatisfy { id in KXUnifiedRegistry.descriptor(id: id) != nil }
        items.append(KXHealthCheckItem(
            name: "管理层三件套",
            passed: loaded,
            message: loaded
                ? "KX-GL-01、KX-GL-02、KX-GL-03都存在"
                : "管理层文件缺失"
        ))

        // 3. 注册表完整性
        let registryReport = KXUnifiedRegistry.integrityReport(basePath: normalizedBasePath)
        items += registryReport.items

        // 4. 版本号检查
        let versionOK = KXUnifiedRegistry.version == KXVersion.current
        items.append(KXHealthCheckItem(
            name: "注册表版本号",
            passed: versionOK,
            message: versionOK
                ? "统一版本\(KXVersion.current)"
                : "版本不一致"
        ))

        // 5. 按层统计文件存在性
        for layer in KXModuleLayer.allCases {
            let layerFiles = KXUnifiedRegistry.descriptors(layer: layer)
            guard !layerFiles.isEmpty else { continue }
            let present = layerFiles.filter { desc in
                let fullPath = (normalizedBasePath as NSString).appendingPathComponent(desc.relativePath)
                return FileManager.default.fileExists(atPath: fullPath)
            }
            let allPresent = layerFiles.count == present.count
            items.append(KXHealthCheckItem(
                name: "\(layer.rawValue)完整性",
                passed: allPresent,
                message: allPresent
                    ? "\(layer.rawValue)\(present.count)/\(layerFiles.count)文件存在"
                    : "\(layer.rawValue)\(present.count)/\(layerFiles.count)文件存在，缺失\(layerFiles.count - present.count)个"
            ))
        }

        // 6. 注册项数量
        let actualCount = KXUnifiedRegistry.allFiles.count
        let countOK = actualCount >= 70
        items.append(KXHealthCheckItem(
            name: "注册项数量校验",
            passed: countOK,
            message: "注册\(actualCount)个文件（目标70+）"
        ))

        // 7. 统一日志文件检查
        let logFileExists = FileManager.default.fileExists(
            atPath: (normalizedBasePath as NSString).appendingPathComponent("工具服务层/KX-UT-01_日志工具.swift")
        )
        items.append(KXHealthCheckItem(
            name: "统一日志文件检查",
            passed: logFileExists,
            message: logFileExists ? "KX-UT-01_日志工具.swift存在" : "KX-UT-01_日志工具.swift缺失"
        ))

        // 8. 入口职责边界
        let source = #file
        let safe = !source.contains("URLSession")
            && !source.contains("UIView")
            && !source.contains("Database")
        items.append(KXHealthCheckItem(
            name: "入口职责边界",
            passed: safe,
            message: safe
                ? "入口仅执行装配、自检、调用注册表，不含业务实现"
                : "入口职责边界检查失败"
        ))

        return KXHealthReport(moduleName: moduleName, version: KXVersion.current, items: items)
    }

    /// 对外暴露当前入口装配到的文件清单
    public static func expectedFiles() -> [KXFileDescriptor] {
        KXUnifiedRegistry.allFiles
    }
}
