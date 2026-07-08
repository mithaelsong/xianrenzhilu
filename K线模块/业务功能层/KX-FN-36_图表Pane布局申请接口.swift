//
//  KX-FN-36_图表Pane布局申请接口.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：指标、回撤、预测、统计面板等业务能力向 K线面板申请/释放 Pane 布局空间
//  禁止事项：禁止 UI 绘制、禁止直接修改 KX-UI-12 frame、禁止数据库写入、禁止网络请求
//

import Foundation

// MARK: - Pane 类型

public enum KLChartPaneKind: String, Codable, Sendable, Equatable, CaseIterable {
    case main        // K线主图
    case volume      // 固定量柱区
    case indicator   // 指标副图区
    case annotation  // 浮动注解层，不占布局
    case reserved    // 指标参数/统计显示区
}

// MARK: - Pane 位置策略

public enum KLChartPanePlacement: String, Codable, Sendable, Equatable, CaseIterable {
    case overlayMain       // 叠加主图，不占空间
    case overlayVolume     // 叠加量柱，不占空间
    case belowMain         // 主图下方
    case aboveVolume       // 量柱上方
    case belowVolume       // 量柱下方
    case bottom            // 图表底部
    case floating          // 浮动，不占布局
}

// MARK: - Pane 高度策略

public enum KLChartPaneHeightPolicy: Codable, Sendable, Equatable {
    case fixed(Double)
    case ratio(Double)
    case minMax(min: Double, max: Double, preferred: Double)
    case contentDriven(min: Double, max: Double)

    private enum CodingKeys: String, CodingKey {
        case type, fixed, ratio, min, max, preferred
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "fixed": self = .fixed(try c.decode(Double.self, forKey: .fixed))
        case "ratio": self = .ratio(try c.decode(Double.self, forKey: .ratio))
        case "contentDriven": self = .contentDriven(min: try c.decode(Double.self, forKey: .min), max: try c.decode(Double.self, forKey: .max))
        default: self = .minMax(min: try c.decode(Double.self, forKey: .min), max: try c.decode(Double.self, forKey: .max), preferred: try c.decode(Double.self, forKey: .preferred))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .fixed(let value):
            try c.encode("fixed", forKey: .type)
            try c.encode(value, forKey: .fixed)
        case .ratio(let value):
            try c.encode("ratio", forKey: .type)
            try c.encode(value, forKey: .ratio)
        case .minMax(let min, let max, let preferred):
            try c.encode("minMax", forKey: .type)
            try c.encode(min, forKey: .min)
            try c.encode(max, forKey: .max)
            try c.encode(preferred, forKey: .preferred)
        case .contentDriven(let min, let max):
            try c.encode("contentDriven", forKey: .type)
            try c.encode(min, forKey: .min)
            try c.encode(max, forKey: .max)
        }
    }
}

// MARK: - Pane Y轴策略

public enum KLChartPaneScalePolicy: String, Codable, Sendable, Equatable, CaseIterable {
    case priceScale
    case volumeScale
    case auto
    case fixedZeroToHundred
    case centeredZero
    case custom
}

// MARK: - Pane 申请对象

public struct KLChartPaneRequest: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let moduleID: String
    public let instanceID: String
    public let indicatorID: String?
    public let title: String
    public let target: KLOverlayTarget
    public let kind: KLChartPaneKind
    public let placement: KLChartPanePlacement
    public let heightPolicy: KLChartPaneHeightPolicy
    public let scalePolicy: KLChartPaneScalePolicy
    public let canStackWithSameKind: Bool
    public let preferredOrder: Int
    public let closeWhenNoOverlay: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String,
        moduleID: String,
        instanceID: String,
        indicatorID: String? = nil,
        title: String,
        target: KLOverlayTarget,
        kind: KLChartPaneKind,
        placement: KLChartPanePlacement,
        heightPolicy: KLChartPaneHeightPolicy,
        scalePolicy: KLChartPaneScalePolicy,
        canStackWithSameKind: Bool = false,
        preferredOrder: Int = 100,
        closeWhenNoOverlay: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.moduleID = moduleID
        self.instanceID = instanceID
        self.indicatorID = indicatorID
        self.title = title
        self.target = target
        self.kind = kind
        self.placement = placement
        self.heightPolicy = heightPolicy
        self.scalePolicy = scalePolicy
        self.canStackWithSameKind = canStackWithSameKind
        self.preferredOrder = preferredOrder
        self.closeWhenNoOverlay = closeWhenNoOverlay
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Pane 申请协议

public protocol KLChartPaneRequesting: AnyObject {
    func requestPane(_ request: KLChartPaneRequest) throws
    func releasePane(moduleID: String, paneID: String) throws
    func releasePanes(moduleID: String, instanceID: String) throws
    func panes(moduleID: String) -> [KLChartPaneRequest]
    func allActivePanes(target: KLOverlayTarget) -> [KLChartPaneRequest]
}

// MARK: - 默认 Pane 管理器

public final class KLDefaultChartPaneManager: KLChartPaneRequesting, @unchecked Sendable {
    public static let shared = KLDefaultChartPaneManager()

    private var panesByModule: [String: [KLChartPaneRequest]] = [:]
    private let queue = DispatchQueue(label: "com.kline.chart.pane.manager")

    private init() {}

    public func requestPane(_ request: KLChartPaneRequest) throws {
        queue.sync {
            var list = panesByModule[request.moduleID] ?? []
            if let idx = list.firstIndex(where: { $0.id == request.id }) {
                list[idx] = request
            } else {
                list.append(request)
            }
            panesByModule[request.moduleID] = list
        }
    }

    public func releasePane(moduleID: String, paneID: String) throws {
        queue.sync {
            guard var list = panesByModule[moduleID] else { return }
            list.removeAll { $0.id == paneID }
            panesByModule[moduleID] = list
        }
    }

    public func releasePanes(moduleID: String, instanceID: String) throws {
        queue.sync {
            guard var list = panesByModule[moduleID] else { return }
            list.removeAll { $0.instanceID == instanceID }
            panesByModule[moduleID] = list
        }
    }

    public func panes(moduleID: String) -> [KLChartPaneRequest] {
        queue.sync { panesByModule[moduleID] ?? [] }
    }

    public func allActivePanes(target: KLOverlayTarget) -> [KLChartPaneRequest] {
        queue.sync {
            panesByModule.values.flatMap { $0 }.filter { request in
                request.target.instrumentID == target.instrumentID &&
                (request.target.appliesToAllTimeframes || request.target.timeframe == nil || target.timeframe == nil || request.target.timeframe == target.timeframe)
            }
            .sorted { lhs, rhs in
                if lhs.preferredOrder == rhs.preferredOrder { return lhs.createdAt < rhs.createdAt }
                return lhs.preferredOrder < rhs.preferredOrder
            }
        }
    }
}

// MARK: - 通知

public extension Notification.Name {
    static let KXIndicatorOverlayDidChange = Notification.Name("KXIndicatorOverlayDidChange")
    static let KXChartPaneLayoutDidChange = Notification.Name("KXChartPaneLayoutDidChange")
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN36Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-36", fileName: "KX-FN-36_图表Pane布局申请接口.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-36_图表Pane布局申请接口.swift", duty: "图表 Pane 布局申请与释放接口"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("图表 Pane 布局申请接口骨架校验通过")
        return KXHealthCheckItem(name: "图表Pane布局申请接口", passed: true, message: "已实现图表 Pane 布局申请与释放接口定义")
    }
}
