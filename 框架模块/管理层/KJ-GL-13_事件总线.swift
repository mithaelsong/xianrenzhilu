// KJ-GL-13_事件总线.swift
// 功能实现已从 KJ-GL-02_公共类型定义.swift 迁回；KJ-GL-02 只保留公共类型定义。
import Foundation
import os

// MARK: - KJEventBus
// MARK: - 事件总线
public final class KJEventBus: @unchecked Sendable {
    public static let shared = KJEventBus()
    private init() {}
    
    private var handlers: [String: [(Any) -> Void]] = [:]
    private let queue = DispatchQueue(label: "com.framework.eventbus")
    
    public func on<T>(_ eventType: KJEventType<T>, handler: @escaping (T) -> Void) -> Self {
        queue.sync {
            let key = eventType.rawValue
            let wrapped: (Any) -> Void = { payload in
                guard let typedPayload = payload as? T else { return }
                handler(typedPayload)
            }
            var list = handlers[key] ?? []
            list.append(wrapped)
            handlers[key] = list
        }
        return self
    }
    
    public func emit<T>(_ eventType: KJEventType<T>, payload: T) {
        queue.sync {
            let key = eventType.rawValue
            guard let list = handlers[key] else { return }
            for handler in list {
                handler(payload)
            }
        }
    }
}

