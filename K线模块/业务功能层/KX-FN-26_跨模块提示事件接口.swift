//
//  KX-FN-26_跨模块提示事件接口.swift
//  仙人指路测试项目｜K线模块
//
//  版本：2.0
//  职责：K线形态识别、指标信号、价格突破、成交量异常、交易事件等提示事件
//        外部模块通过本接口提交提示事件，K线模块可关联图表标记并转发给提示音模块
//  禁止事项：禁止直接播放声音、禁止UI绘制
//

import Foundation


// MARK: - 事件类型

public enum KLAlertEventType: String, Codable, Sendable {
    case candlePattern       // K线形态识别
    case indicatorSignal     // 指标信号
    case priceBreakout       // 价格突破
    case volumeAnomaly       // 成交量异常
    case retracementReached  // 回撤触发
    case predictionSignal    // 预测信号
    case tradeEvent          // 交易事件
    case custom              // 自定义
}

// MARK: - 严重程度

public enum KLAlertSeverity: String, Codable, Sendable {
    case info
    case warning
    case critical
}

// MARK: - 外部提示事件

public struct KLExternalAlertEvent: Codable, Sendable, Identifiable {
    public let id: String
    public let moduleID: String
    public let moduleName: String
    public let target: KLOverlayTarget
    public let eventType: KLAlertEventType
    public let title: String
    public let message: String
    public let severity: KLAlertSeverity
    public let anchorTime: Date?
    public let anchorPrice: Decimal?
    /// 关联的声音提示ID
    public let soundID: String?
    /// 是否应在图表上显示对应的标记
    public let shouldDisplayMarker: Bool
    public let createdAt: Date
    public var delivered: Bool

    public init(id: String = UUID().uuidString, moduleID: String, moduleName: String, target: KLOverlayTarget, eventType: KLAlertEventType, title: String, message: String, severity: KLAlertSeverity = .info, anchorTime: Date? = nil, anchorPrice: Decimal? = nil, soundID: String? = nil, shouldDisplayMarker: Bool = false, createdAt: Date = Date(), delivered: Bool = false) {
        self.id = id
        self.moduleID = moduleID
        self.moduleName = moduleName
        self.target = target
        self.eventType = eventType
        self.title = title
        self.message = message
        self.severity = severity
        self.anchorTime = anchorTime
        self.anchorPrice = anchorPrice
        self.soundID = soundID
        self.shouldDisplayMarker = shouldDisplayMarker
        self.createdAt = createdAt
        self.delivered = delivered
    }
}

// MARK: - 事件提交协议

public protocol KLAlertEventSubmitting: AnyObject {
    /// 提交提示事件
    func submitEvent(_ event: KLExternalAlertEvent) throws
    /// 批量提交
    func submitEvents(_ events: [KLExternalAlertEvent]) throws
    /// 标记已投递
    func markDelivered(eventID: String, moduleID: String) throws
    /// 移除事件
    func removeEvent(eventID: String, moduleID: String) throws
    /// 移除某模块所有事件
    func removeAllEvents(moduleID: String) throws
    /// 获取未投递的事件
    func undeliveredEvents() -> [KLExternalAlertEvent]
    /// 获取某模块所有事件
    func events(moduleID: String) -> [KLExternalAlertEvent]
}

// MARK: - 默认提示事件管理器

public final class KLDefaultAlertEventManager: KLAlertEventSubmitting, @unchecked Sendable {
    public static let shared = KLDefaultAlertEventManager()

    private var events: [KLExternalAlertEvent] = []
    private let queue = DispatchQueue(label: "com.kline.alert.event")

    private init() {}

    public func submitEvent(_ event: KLExternalAlertEvent) throws {
        queue.sync {
            events.append(event)
        }
    }

    public func submitEvents(_ events: [KLExternalAlertEvent]) throws {
        queue.sync {
            self.events.append(contentsOf: events)
        }
    }

    public func markDelivered(eventID: String, moduleID: String) throws {
        queue.sync {
            guard let idx = events.firstIndex(where: { $0.id == eventID && $0.moduleID == moduleID }) else { return }
            events[idx].delivered = true
        }
    }

    public func removeEvent(eventID: String, moduleID: String) throws {
        queue.sync {
            events.removeAll { $0.id == eventID && $0.moduleID == moduleID }
        }
    }

    public func removeAllEvents(moduleID: String) throws {
        queue.sync {
            events.removeAll { $0.moduleID == moduleID }
        }
    }

    public func undeliveredEvents() -> [KLExternalAlertEvent] {
        queue.sync {
            events.filter { !$0.delivered }
        }
    }

    public func events(moduleID: String) -> [KLExternalAlertEvent] {
        queue.sync {
            events.filter { $0.moduleID == moduleID }
        }
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXFN26Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-FN-26", fileName: "KX-FN-26_跨模块提示事件接口.swift", layer: .function,
        relativePath: "业务功能层/KX-FN-26_跨模块提示事件接口.swift", duty: "跨模块提示事件接口定义"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("跨模块提示事件接口骨架校验通过")
        return KXHealthCheckItem(name: "跨模块提示事件接口", passed: true, message: "已实现跨模块提示事件接口定义")
    }
}

// MARK: - 形态识别标准提示事件提交适配

/// K线模块只承载形态识别模块提交的标准提醒描述，不主动运行形态识别算法。
public enum KXFN26PatternAlertBridge {
    public static let moduleID = "candle-pattern-recognition"
    public static let moduleName = "K线形态识别"

    public static func makeEvents(
        from descriptors: [KLAlertEventDescriptor],
        target: KLOverlayTarget,
        generatedAt: Date = Date()
    ) -> [KLExternalAlertEvent] {
        descriptors.map { descriptor in
            KLExternalAlertEvent(
                id: "external.\(descriptor.id)",
                moduleID: moduleID,
                moduleName: moduleName,
                target: target,
                eventType: .candlePattern,
                title: descriptor.title,
                message: descriptor.message,
                severity: severity(from: descriptor),
                anchorTime: descriptor.occurredAt,
                anchorPrice: nil,
                soundID: descriptor.sound?.soundID,
                shouldDisplayMarker: true,
                createdAt: generatedAt,
                delivered: descriptor.deliveryState == .delivered
            )
        }
    }

    public static func submitEvents(
        from descriptors: [KLAlertEventDescriptor],
        target: KLOverlayTarget,
        manager: KLAlertEventSubmitting = KLDefaultAlertEventManager.shared,
        generatedAt: Date = Date()
    ) throws -> [KLExternalAlertEvent] {
        let events = makeEvents(from: descriptors, target: target, generatedAt: generatedAt)
        let oldEvents = manager.events(moduleID: moduleID).filter { event in
            event.target.instrumentID == target.instrumentID &&
            event.target.timeframe == target.timeframe &&
            event.target.tabID == target.tabID
        }
        for event in oldEvents {
            try manager.removeEvent(eventID: event.id, moduleID: moduleID)
        }
        try manager.submitEvents(events)
        return events
    }

    private static func severity(from descriptor: KLAlertEventDescriptor) -> KLAlertSeverity {
        if descriptor.deliveryState == .failed { return .warning }
        if descriptor.sound?.soundID == "pattern_critical" { return .critical }
        if descriptor.sound?.soundID == "pattern_high" { return .warning }
        return .info
    }
}
