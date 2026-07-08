// MARK: - UI-10: UI模块版本检查
// 功能编号: UI-11
// 版本: 2.0
// 职责: 验证模块与框架的兼容性，支持版本范围、语义化版本比较、自动搜索兼容版本
// 依赖: UI-12 日志

import Foundation

// UIVersion, UIVersionRange, UIVersionCompatibility 定义在 UI-02_公共类型定义.swift

// MARK: - 版本检查管理器
// 类型 UIModuleVersionChecker 已迁移到 UI-02_公共类型定义.swift

// MARK: - 测试
internal func test_UI10() {
    print("\n=== UI-10 版本检查模块测试 ===\n")

    let checker = UIModuleVersionChecker.shared

    // 重置框架版本
    let setOk = checker.setFrameworkVersion("2.0")
    guard setOk else {
        fatalError("❌ 准备失败: 设置框架版本应成功")
    }

    // MARK: 测试1: 版本解析
    print("🧪 测试1: 版本解析")
    let v1 = UIVersion.parse("2.0")
    guard v1 != nil else { fatalError("❌ 测试1失败: 2.0 应解析成功") }
    guard v1?.major == 1 else { fatalError("❌ 测试1失败: major 应为 1") }
    guard v1?.minor == 2 else { fatalError("❌ 测试1失败: minor 应为 2") }
    guard v1?.patch == 3 else { fatalError("❌ 测试1失败: patch 应为 3") }
    guard v1?.stringValue == "2.0" else { fatalError("❌ 测试1失败: stringValue 应为 2.0") }
    print("✅ 测试1通过: UIVersion.parse(\"2.0\") = \(v1!.stringValue)")

    // MARK: 测试2: 无效版本解析
    print("\n🧪 测试2: 无效版本解析返回nil")
    guard UIVersion.parse("abc") == nil else { fatalError("❌ 测试2失败: 'abc' 应返回nil") }
    guard UIVersion.parse("2.0") == nil else { fatalError("❌ 测试2失败: '2.0' 应返回nil") }
    guard UIVersion.parse("2.0") == nil else { fatalError("❌ 测试2失败: '2.0' 应返回nil") }
    guard UIVersion.parse("") == nil else { fatalError("❌ 测试2失败: 空字符串应返回nil") }
    print("✅ 测试2通过: 4种无效格式均返回nil")

    // MARK: 测试3: 版本比较
    print("\n🧪 测试3: 语义化版本比较")
    let v2 = UIVersion(major: 2, minor: 0, patch: 0)
    let v3 = UIVersion(major: 1, minor: 9, patch: 99)
    let v4 = UIVersion(major: 2, minor: 0, patch: 1)
    let v5 = UIVersion(major: 1, minor: 10, patch: 0)
    guard v3 < v2 else { fatalError("❌ 测试3失败: 1.9.99 < 2.0.0") }
    guard v2 < v4 else { fatalError("❌ 测试3失败: 2.0.0 < 2.0.1") }
    guard v2 <= v2 else { fatalError("❌ 测试3失败: 2.0.0 <= 2.0.0") }
    guard v4 > v2 else { fatalError("❌ 测试3失败: 2.0.1 > 2.0.0") }
    guard v2 >= v3 else { fatalError("❌ 测试3失败: 2.0.0 >= 1.9.99") }
    guard v5 > v3 else { fatalError("❌ 测试3失败: 1.10.0 > 1.9.99") }
    print("✅ 测试3通过: 6种比较运算符均正确")

    // MARK: 测试4: 版本范围
    print("\n🧪 测试4: 版本范围")
    let range = UIVersionRange(
        minVersion: UIVersion(major: 1, minor: 0, patch: 0),
        maxVersion: UIVersion(major: 2, minor: 5, patch: 0)
    )
    guard range.contains(UIVersion(major: 1, minor: 5, patch: 0)) else { fatalError("❌ 测试4失败: 2.0 应在范围内") }
    guard range.contains(UIVersion(major: 2, minor: 5, patch: 0)) else { fatalError("❌ 测试4失败: 2.5.0 应在范围内（边界）") }
    guard !range.contains(UIVersion(major: 3, minor: 0, patch: 0)) else { fatalError("❌ 测试4失败: 3.0.0 应在范围外") }
    guard !range.contains(UIVersion(major: 0, minor: 9, patch: 0)) else { fatalError("❌ 测试4失败: 2.0 应在范围外") }
    print("✅ 测试4通过: 范围判断包含/边界/排除均正确")

    // MARK: 测试5: isVersionCompatible
    print("\n🧪 测试5: isVersionCompatible")
    let c1 = checker.isVersionCompatible(UIVersion(major: 1, minor: 5, patch: 0), with: UIVersion(major: 1, minor: 0, patch: 0))
    guard c1 else { fatalError("❌ 测试5失败: 2.0 >= 1.0.0 应兼容") }
    let c2 = checker.isVersionCompatible(UIVersion(major: 3, minor: 0, patch: 0), with: UIVersion(major: 1, minor: 0, patch: 0))
    guard !c2 else { fatalError("❌ 测试5失败: 3.0.0 > 2.0.0 应不兼容") }
    let c3 = checker.isVersionCompatible(UIVersion(major: 0, minor: 5, patch: 0), with: UIVersion(major: 1, minor: 0, patch: 0))
    guard !c3 else { fatalError("❌ 测试5失败: 0.5.0 < 1.0.0 应不兼容") }
    let c4 = checker.isVersionCompatible(UIVersion(major: 2, minor: 0, patch: 0), with: UIVersion(major: 1, minor: 0, patch: 0))
    guard c4 else { fatalError("❌ 测试5失败: 2.0.0 精确匹配应兼容") }
    print("✅ 测试5通过: 4种兼容场景均正确")

    // MARK: 测试6: checkCompatibility 兼容
    print("\n🧪 测试6: checkCompatibility 兼容")
    let r1 = checker.checkCompatibility(moduleID: "Test-01", moduleVersion: "2.0", minFrameworkVersion: "2.0")
    guard case .compatible = r1 else { fatalError("❌ 测试6失败: 2.0/1.0.0 应兼容") }
    print("✅ 测试6通过: 兼容结果正确")

    // MARK: 测试7: checkCompatibility 需要更新
    print("\n🧪 测试7: checkCompatibility 需要更新")
    let r2 = checker.checkCompatibility(moduleID: "Test-02", moduleVersion: "2.0", minFrameworkVersion: "2.0")
    guard case .requiresUpdate(let cur, let req) = r2 else { fatalError("❌ 测试7失败: 2.0 < 1.0.0 应需要更新") }
    guard cur == UIVersion(major: 0, minor: 9, patch: 0) else { fatalError("❌ 测试7失败: 当前版本应为2.0") }
    guard req == UIVersion(major: 1, minor: 0, patch: 0) else { fatalError("❌ 测试7失败: 要求版本应为1.0.0") }
    print("✅ 测试7通过: 需要更新结果正确 (2.0 < 1.0.0)")

    // MARK: 测试8: checkCompatibility 不兼容（版本过高）
    print("\n🧪 测试8: checkCompatibility 不兼容（版本过高）")
    let r3 = checker.checkCompatibility(moduleID: "Test-03", moduleVersion: "2.0", minFrameworkVersion: "2.0")
    guard case .incompatible = r3 else { fatalError("❌ 测试8失败: 3.0.0 > 2.0.0 应不兼容") }
    print("✅ 测试8通过: 不兼容（版本过高）结果正确")

    // MARK: 测试9: checkCompatibility 废弃
    print("\n🧪 测试9: checkCompatibility 废弃")
    let r4 = checker.checkCompatibility(moduleID: "Test-04", moduleVersion: "2.0", minFrameworkVersion: "2.0")
    guard case .deprecated(let cur, let latest) = r4 else { fatalError("❌ 测试9失败: 1.0.0 < 2.0.0 主版本 应废弃") }
    guard cur == UIVersion(major: 1, minor: 0, patch: 0) else { fatalError("❌ 测试9失败: 当前版本应为1.0.0") }
    guard latest == UIVersion(major: 2, minor: 0, patch: 0) else { fatalError("❌ 测试9失败: 最新版本应为2.0.0") }
    print("✅ 测试9通过: 废弃结果正确")

    // MARK: 测试10: 无效版本格式
    print("\n🧪 测试10: 无效版本格式")
    let r6 = checker.checkCompatibility(moduleID: "Test-06", moduleVersion: "abc", minFrameworkVersion: "2.0")
    guard case .incompatible(let reason6) = r6 else { fatalError("❌ 测试10失败: 'abc' 应返回 incompatible") }
    guard reason6.contains("模块版本格式无效") else { fatalError("❌ 测试10失败: 原因应包含'模块版本格式无效'") }
    let r7 = checker.checkCompatibility(moduleID: "Test-07", moduleVersion: "2.0", minFrameworkVersion: "abc")
    guard case .incompatible(let reason7) = r7 else { fatalError("❌ 测试10失败: minVersion 'abc' 应返回 incompatible") }
    guard reason7.contains("最低框架版本格式无效") else { fatalError("❌ 测试10失败: 原因应包含'最低框架版本格式无效'") }
    print("✅ 测试10通过: 无效版本格式返回 incompatible")

    // MARK: 测试11: 设置/获取框架版本
    print("\n🧪 测试11: 设置/获取框架版本")
    let current = checker.currentFrameworkVersion()
    guard current.stringValue == "2.0" else { fatalError("❌ 测试11失败: 当前版本应为2.0.0，实际: \(current.stringValue)") }
    let badSet = checker.setFrameworkVersion("invalid")
    guard !badSet else { fatalError("❌ 测试11失败: 设置无效版本应返回false") }
    guard checker.currentFrameworkVersion().stringValue == "2.0" else { fatalError("❌ 测试11失败: 设置无效后版本不应变化") }
    print("✅ 测试11通过: 设置/获取框架版本正确")

    // MARK: 测试12: 设置新版本后重新兼容检查
    print("\n🧪 测试12: 设置新版本后重新检查")
    checker.setFrameworkVersion("2.0")
    guard checker.currentFrameworkVersion().stringValue == "2.0" else { fatalError("❌ 测试12失败: 新版本应为2.0") }
    let r12 = checker.checkCompatibility(moduleID: "Test-12", moduleVersion: "2.0", minFrameworkVersion: "2.0")
    guard case .incompatible = r12 else { fatalError("❌ 测试12失败: 2.0 > 2.0 应不兼容") }
    // 恢复
    checker.setFrameworkVersion("2.0")
    guard checker.currentFrameworkVersion().stringValue == "2.0" else { fatalError("❌ 测试12失败: 恢复后版本应为2.0.0") }
    print("✅ 测试12通过: 新版本检查正确，已恢复")

    // MARK: 测试13: 并发访问
    print("\n🧪 测试13: 并发访问")
    let concGroup = DispatchGroup()
    let concQueue = DispatchQueue(label: "test.version.concurrent", attributes: .concurrent)
    var concErrors = 0
    let concLock = NSLock()
    for i in 0..<20 {
        concGroup.enter()
        concQueue.async {
            let v = i % 5 + 1
            let result = checker.checkCompatibility(moduleID: "Concurrent-\(i)", moduleVersion: "\(v).0.0", minFrameworkVersion: "2.0")
            if case .incompatible = result {
                concLock.lock()
                concErrors += 1
                concLock.unlock()
            }
            concGroup.leave()
        }
    }
    let concWait = concGroup.wait(timeout: .now() + 5.0)
    guard concWait == .success else { fatalError("❌ 测试13失败: 并发访问超时") }
    // 部分版本（3.0.0/2.0/5.0.0）对框架 2.0.0 确实不兼容，不验证具体数量
    print("✅ 测试13通过: 20次并发兼容检查无崩溃\(concErrors > 0 ? "（其中 \(concErrors) 个不兼容，符合预期）" : "")")

    print("\n=== 全部 UI-10 版本检查模块测试通过 ✅ ===\n")
}

#if FILEINDEPENDENT
// MARK: - 独立编译存根：UILoadingLogManager (UI-12)
// 类型 UILoadingLogManager 已迁移到 UI-02_公共类型定义.swift
#endif


// MARK: - 从 UI-02 公共类型定义迁回的功能实现（2026-06-11）
// 说明：这些是功能实现/扩展/顶层工具函数，按开发规则禁止留在 UI-02，已迁回本功能文件。

// MARK: - 迁回自 UI-02：class UIModuleVersionChecker
public final class UIModuleVersionChecker : @unchecked Sendable {
    public static let shared = UIModuleVersionChecker()

    let lock = NSRecursiveLock()
    private let logger = UILoadingLogManager.shared

    private var _frameworkVersion: UIVersion = UIVersion(major: 2, minor: 0, patch: 0)

    private init() {
        logger.info("版本检查", "框架版本初始化完成: \(_frameworkVersion.stringValue)")
    }

    // MARK: - 框架版本管理

    /// 设置框架版本号
    /// - Parameter version: 版本字符串（如 "2.0"）
    /// - Returns: 是否设置成功
    @discardableResult
    public func setFrameworkVersion(_ version: String) -> Bool {
        guard let v = UIVersion.parse(version) else {
            logger.error("版本检查", "设置框架版本失败: 格式无效 '\(version)'")
            return false
        }
        lock.lock()
        _frameworkVersion = v
        lock.unlock()
        logger.info("版本检查", "框架版本已更新: \(v.stringValue)")
        return true
    }

    /// 获取当前框架版本号
    /// - Returns: 当前框架版本
    public func currentFrameworkVersion() -> UIVersion {
        lock.lock()
        defer { lock.unlock() }
        return _frameworkVersion
    }

    // MARK: - 兼容性检查

    /// 判断版本是否兼容（模块版本 ≥ 最低版本 且 ≤ 当前框架版本）
    /// - Parameters:
    ///   - version: 模块版本
    ///   - minVersion: 要求的最低版本
    /// - Returns: 是否兼容
    public func isVersionCompatible(_ version: UIVersion, with minVersion: UIVersion) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return version >= minVersion && version <= _frameworkVersion
    }

    /// 检查模块的版本兼容性
    /// - Parameters:
    ///   - moduleID: 模块ID
    ///   - moduleVersion: 模块版本字符串
    ///   - minFrameworkVersion: 要求的最低框架版本字符串
    /// - Returns: 兼容性检查结果
    public func checkCompatibility(moduleID: String, moduleVersion: String, minFrameworkVersion: String) -> UIVersionCompatibility {
        guard let mVersion = UIVersion.parse(moduleVersion) else {
            let reason = "模块版本格式无效: '\(moduleVersion)'"
            logger.error("版本检查", "模块 '\(moduleID)' \(reason)", moduleID: moduleID)
            return .incompatible(reason: reason)
        }

        guard let minVersion = UIVersion.parse(minFrameworkVersion) else {
            let reason = "最低框架版本格式无效: '\(minFrameworkVersion)'"
            logger.error("版本检查", "模块 '\(moduleID)' \(reason)", moduleID: moduleID)
            return .incompatible(reason: reason)
        }

        lock.lock()
        defer { lock.unlock() }
        let current = _frameworkVersion

        if mVersion < minVersion {
            let msg = "模块版本 \(mVersion.stringValue) 低于最低要求 \(minVersion.stringValue)"
            logger.warning("版本检查", "模块 '\(moduleID)' \(msg)", moduleID: moduleID)
            return .requiresUpdate(current: mVersion, required: minVersion)
        }

        if mVersion > current {
            let msg = "模块版本 \(mVersion.stringValue) 超过当前框架版本 \(current.stringValue)"
            logger.warning("版本检查", "模块 '\(moduleID)' \(msg)", moduleID: moduleID)
            return .incompatible(reason: msg)
        }

        if current.major > mVersion.major {
            let msg = "模块版本 \(mVersion.stringValue) 已过时，当前框架版本 \(current.stringValue)"
            logger.warning("版本检查", "模块 '\(moduleID)' \(msg)", moduleID: moduleID)
            return .deprecated(current: mVersion, latest: current)
        }

        logger.info("版本检查", "模块 '\(moduleID)' 版本 \(mVersion.stringValue) 与框架版本 \(current.stringValue) 兼容", moduleID: moduleID)
        return .compatible
    }
}
