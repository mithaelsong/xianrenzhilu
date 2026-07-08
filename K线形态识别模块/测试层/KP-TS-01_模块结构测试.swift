// KP-TS-01_模块结构测试.swift
// K线形态识别模块结构测试
// 职责：按数据库审计标准验证注册表、文件身份、公共类型纯净性、形态库数量和旧命名残留。
// 禁止事项：禁止修改项目文件、禁止网络/数据库读写、禁止 UI 绘制。

import Foundation

public enum KPModuleStructureTests {
    public static func runAllTests(basePath: String) {
        testRegistryFilesExist(basePath: basePath)
        testSkeletonDescriptorsMatchRegistry()
        testPatternLibraryCount()
        testNoLegacyFileIdentity(basePath: basePath)
        testPublicTypeFilePurity(basePath: basePath)
    }

    /// 验证 KP-01 注册表登记的文件全部存在。
    public static func testRegistryFilesExist(basePath: String) {
        print("\n🧪 Test 1: KP 注册表文件存在性")
        let normalizedBasePath = (basePath as NSString).standardizingPath
        for descriptor in KPModuleRegistry.files {
            let fullPath = (normalizedBasePath as NSString).appendingPathComponent(descriptor.relativePath)
            guard FileManager.default.fileExists(atPath: fullPath) else {
                fatalError("❌ Test 1 failed: 注册文件不存在 \(descriptor.id) \(descriptor.relativePath)")
            }
        }
        print("✅ Test 1 passed: KP 注册表登记文件全部存在")
    }

    /// 验证关键文件骨架描述符与 KP-01 注册表一致。
    public static func testSkeletonDescriptorsMatchRegistry() {
        print("\n🧪 Test 2: KP 骨架描述符与注册表一致性")
        let skeletonDescriptors: [KPFileDescriptor] = [
            KPDF03CustomPatternSkeleton.descriptor,
            KPEN02PatternWatcherSkeleton.descriptor,
            KPAD02Skeleton.descriptor,
            KPAD03PatternMarkerConverterSkeleton.descriptor,
            KPAD04Skeleton.descriptor,
            KPAD05PatternResultMarkerBridgeSkeleton.descriptor,
            KPEV02PatternSignalGenerator.descriptor
        ]
        for descriptor in skeletonDescriptors {
            guard let registered = KPModuleRegistry.files.first(where: { $0.id == descriptor.id }) else {
                fatalError("❌ Test 2 failed: 骨架描述符未登记 \(descriptor.id)")
            }
            guard registered.fileName == descriptor.fileName else {
                fatalError("❌ Test 2 failed: 文件名不一致 \(descriptor.id)")
            }
            guard registered.relativePath == descriptor.relativePath else {
                fatalError("❌ Test 2 failed: 路径不一致 \(descriptor.id)")
            }
            guard registered.layer == descriptor.layer else {
                fatalError("❌ Test 2 failed: 层级不一致 \(descriptor.id)")
            }
        }
        print("✅ Test 2 passed: KP 骨架描述符与注册表一致")
    }

    /// 验证形态库数量符合模块启动标准。
    public static func testPatternLibraryCount() {
        print("\n🧪 Test 3: 形态库数量")
        let count = CandlePatternLibrary.shared.allPatterns.count
        guard count >= KPModuleRegistry.expectedPatternCount else {
            fatalError("❌ Test 3 failed: 形态库数量不足，当前 \(count)，要求 \(KPModuleRegistry.expectedPatternCount)")
        }
        print("✅ Test 3 passed: 形态库数量满足要求")
    }

    /// 验证独立 KP 模块不再残留旧 KX/KL 文件身份。
    public static func testNoLegacyFileIdentity(basePath: String) {
        print("\n🧪 Test 4: 旧文件身份残留扫描")
        let oldKX = "K" + "X"
        let oldKL = "K" + "L"
        let forbiddenTokens = [
            oldKX + "-UT-06",
            oldKX + "-FN-22",
            oldKL + "-IF-03",
            oldKX + "-IN-01_自定义形态",
            oldKX + "-UT-10",
            "标记层/" + oldKX,
            "接口层/" + oldKL,
            "业务功能层/" + oldKX,
            "指标服务层/" + "自定义指标",
            "提示音事件层/" + oldKX,
            oldKX + "FN222",
            oldKX + "UT06",
            oldKX + "UT10",
            oldKX + "FN22Skeleton",
            oldKX + "FileSkeletonProtocol",
            oldKX + "-IN-01",
            oldKX + "IndicatorProtocol",
            oldKX + "UnifiedIndicatorRegistry",
            oldKX + "FN221IndicatorDataInterface",
            "旧" + "版",
            "运行时服务注册表"
        ]
        let swiftFiles = listSwiftFiles(basePath: basePath)
        for file in swiftFiles {
            let content = readTextFile(file)
            for token in forbiddenTokens {
                guard !content.contains(token) else {
                    fatalError("❌ Test 4 failed: 发现旧文件身份残留 \(token) in \(file)")
                }
            }
        }
        print("✅ Test 4 passed: 未发现旧文件身份残留")
    }

    /// 验证 KP-02 公共类型文件不承载 class/actor/extension/顶层函数/顶层变量实现。
    public static func testPublicTypeFilePurity(basePath: String) {
        print("\n🧪 Test 5: KP-02 公共类型纯净性")
        let path = (basePath as NSString).appendingPathComponent("管理层/KP-02_公共类型定义.swift")
        let content = readTextFile(path)
        let lines = content.components(separatedBy: .newlines)
        var depth = 0
        for pair in lines.enumerated() {
            let lineNumber = pair.offset + 1
            let trimmed = pair.element.trimmingCharacters(in: .whitespacesAndNewlines)
            if depth == 0 {
                let forbiddenAtTopLevel = trimmed.hasPrefix("public class ") ||
                    trimmed.hasPrefix("class ") ||
                    trimmed.hasPrefix("public actor ") ||
                    trimmed.hasPrefix("actor ") ||
                    trimmed.hasPrefix("public extension ") ||
                    trimmed.hasPrefix("extension ") ||
                    trimmed.hasPrefix("public func ") ||
                    trimmed.hasPrefix("func ") ||
                    trimmed.hasPrefix("public let ") ||
                    trimmed.hasPrefix("let ") ||
                    trimmed.hasPrefix("public var ") ||
                    trimmed.hasPrefix("var ")
                guard !forbiddenAtTopLevel else {
                    fatalError("❌ Test 5 failed: KP-02 第 \(lineNumber) 行存在顶层禁止项")
                }
            }
            depth += pair.element.filter { $0 == "{" }.count
            depth -= pair.element.filter { $0 == "}" }.count
            guard depth >= 0 else {
                fatalError("❌ Test 5 failed: KP-02 第 \(lineNumber) 行括号层级异常")
            }
        }
        print("✅ Test 5 passed: KP-02 公共类型文件纯净")
    }

    private static func listSwiftFiles(basePath: String) -> [String] {
        let normalizedBasePath = (basePath as NSString).standardizingPath
        guard let enumerator = FileManager.default.enumerator(atPath: normalizedBasePath) else {
            fatalError("❌ Test helper failed: 无法枚举目录 \(normalizedBasePath)")
        }
        var files: [String] = []
        for case let relativePath as String in enumerator {
            guard relativePath.hasSuffix(".swift") else { continue }
            files.append((normalizedBasePath as NSString).appendingPathComponent(relativePath))
        }
        return files.sorted()
    }

    private static func readTextFile(_ path: String) -> String {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            fatalError("❌ Test helper failed: 无法读取文件 \(path): \(error.localizedDescription)")
        }
    }
}

public enum KPTS01ModuleStructureTestSkeleton: KPFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KPFileDescriptor(
        id: "KP-TS-01",
        fileName: "KP-TS-01_模块结构测试.swift",
        layer: .test,
        relativePath: "测试层/KP-TS-01_模块结构测试.swift",
        duty: "模块结构、注册表、命名和公共类型纯净性测试"
    )

    public static func skeletonStatus() -> KPHealthCheckItem {
        KPHealthCheckItem(name: "模块结构测试", passed: true, message: "KP-TS-01 提供 runAllTests 顺序测试入口")
    }
}
