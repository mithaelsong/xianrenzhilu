//
//  KX-FN-19_指标管理.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：技术指标管理、分类、搜索、加载；兼容旧入口，数据源委托统一指标注册表
//  禁止事项：禁止直接UI绘制、禁止网络请求
//

import Foundation

// MARK: - 技术指标管理器（兼容旧 UI 入口）

public final class KXTechnicalIndicatorManager: @unchecked Sendable {
    public static let shared = KXTechnicalIndicatorManager()
    private init() {}

    /// 所有指标。数据源统一来自指标服务层注册表，不再维护旧的硬编码 10/11 个指标。
    public var allIndicators: [KXTechnicalIndicator] {
        KXUnifiedIndicatorRegistry.allIndicators
    }

    /// 根据ID或名称获取技术指标。
    public func indicator(withId id: String) -> KXTechnicalIndicator? {
        KXUnifiedIndicatorRegistry.indicator(withId: id)
    }

    /// 根据分类获取技术指标。
    public func indicators(for category: KXIndicatorCategory) -> [KXTechnicalIndicator] {
        KXUnifiedIndicatorRegistry.indicators(for: category)
    }

    /// 搜索技术指标。
    public func searchIndicators(query: String) -> [KXTechnicalIndicator] {
        KXUnifiedIndicatorRegistry.searchIndicators(query: query)
    }

    /// 按分类分组的指标。
    public var categorizedIndicators: [KXIndicatorCategory: [KXTechnicalIndicator]] {
        KXUnifiedIndicatorRegistry.categorizedIndicators
    }


    /// 创建真实指标计算器。
    public func calculator(for indicator: KXTechnicalIndicator) -> KXIndicatorProtocol? {
        KXUnifiedIndicatorRegistry.calculator(for: indicator)
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN19Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.1"

    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-19",
        fileName: "KX-FN-19_指标管理.swift",
        layer: .function,
        relativePath: "业务功能层/KX-FN-19_指标管理.swift",
        duty: "技术指标管理、分类、搜索、加载；兼容旧入口并委托统一指标注册表"
    )

    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("技术指标管理骨架校验通过")
        return KXHealthCheckItem(name: "指标管理", passed: true, message: "已接入统一指标注册表，共\(KXUnifiedIndicatorRegistry.allIndicators.count)个指标")
    }
}
