//
//  KX-SY-07_WebSocket执行器.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.1
//  职责：OKX WebSocket 真实执行器。用 API Key 登录私有频道（business），为交易模块铺路。
//        交易所推送模式，不轮询。支持断线自动重连+恢复订阅。
//  禁止事项：禁止UI绘制、禁止直接写数据库（数据由三方决定）
//

import Foundation

import CommonCrypto

// MARK: - 登录消息

private struct KLOKXWSLoginArg: Codable {
    let apiKey: String
    let passphrase: String
    let timestamp: String
    let sign: String
}

// MARK: - 订阅消息结构

public struct KLOKXWSSubscription: Codable, Sendable {
    public let channel: String
    public let instID: String
    public init(channel: String, instID: String) {
        self.channel = channel
        self.instID = instID
    }
}

// MARK: - 配置

public struct KLOKXWSConfig: Sendable, Codable {
    public let baseURL: String
    public let apiKey: String
    public let secretKey: String
    public let passphrase: String
    /// 自动重连间隔（秒）
    public let reconnectDelay: Double

    public init(baseURL: String = "wss://ws.okx.com:8443/ws/v5/business",
                apiKey: String, secretKey: String, passphrase: String,
                reconnectDelay: Double = 2.0) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.secretKey = secretKey
        self.passphrase = passphrase
        self.reconnectDelay = reconnectDelay
    }

    /// 开发用的默认配置
    public static var development: KLOKXWSConfig {
        KLOKXWSConfig(
            apiKey: "53BC12C6ECC8A64A1D879097438FEB66",
            secretKey: "d90d8aae-15f7-4a6f-85d4-d0767ae25250",
            passphrase: "SQTadd..0204"
        )
    }
}

// MARK: - 执行协议

public protocol KLOKXWSExecuting: AnyObject {
    var config: KLOKXWSConfig { get }
    func connect() async throws
    func disconnect()
    func subscribe(channel: String, instID: String) async throws
    func subscribeMultiple(_ subscriptions: [KLOKXWSSubscription]) async throws
    func unsubscribe(channel: String, instID: String) async throws
    func reconnect() async throws
    func restoreSubscriptions() async throws
    var onMessage: ((Data) -> Void)? { get set }
    var onConnected: (() -> Void)? { get set }
    var onDisconnected: ((Error?) -> Void)? { get set }
}

// MARK: - 真实执行器

public final class KLOKXDefaultWSExecutor: NSObject, KLOKXWSExecuting, @unchecked Sendable {
    public let config: KLOKXWSConfig
    public var onMessage: ((Data) -> Void)?
    public var onConnected: (() -> Void)?
    public var onDisconnected: ((Error?) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var session: URLSession
    private var subscriptions: [KLOKXWSSubscription] = []
    // 保护 subscriptions 数组，避免多 async task 并发 append/removeAll 造成内存损坏(SIGSEGV)。
    // 与 K线模块前端统一用串行队列做锁（同型号），不用 NSLock、不引框架模块的锁。
    private let subscriptionsQueue = DispatchQueue(label: "com.kline.ws.subscriptions")

    // 线程安全地读取订阅快照
    private func subscriptionsSnapshot() -> [KLOKXWSSubscription] {
        subscriptionsQueue.sync { subscriptions }
    }
    // 线程安全地添加订阅(去重)
    private func addSubscriptionLocked(_ s: KLOKXWSSubscription) {
        subscriptionsQueue.sync {
            if !subscriptions.contains(where: { $0.channel == s.channel && $0.instID == s.instID }) {
                subscriptions.append(s)
            }
        }
    }
    // 线程安全地移除订阅
    private func removeSubscriptionLocked(channel: String, instID: String) {
        subscriptionsQueue.sync {
            subscriptions.removeAll { $0.channel == channel && $0.instID == instID }
        }
    }
    private var shouldReconnect = true
    private var reconnectWork: DispatchWorkItem?

    public init(config: KLOKXWSConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    deinit { disconnect() }

    // MARK: - 连接（含登录）

    public func connect() async throws {
        disconnect()
        shouldReconnect = true
        guard let url = URL(string: config.baseURL) else {
            throw KLOKXAPIError(code: "WS_URL", message: "无效WS地址")
        }
        task = session.webSocketTask(with: url)
        task?.resume()
        // 公开行情频道（business candle）不需要登录。强制登录会干扰订阅确认与错误处理。
        // 私有交易频道后续由交易模块显式调用登录流程。
        receiveLoop()
        onConnected?()
    }

    private func login() async throws {
        let ts = KLOKXSigner.isoTimestamp()
        let _ = "\(ts)GET/users/self/verify"
        guard let sign = KLOKXSigner.sign(timestamp: ts, method: "GET", path: "/users/self/verify", body: "", secretKey: config.secretKey) else {
            throw KLOKXAPIError(code: "WS_LOGIN_SIGN", message: "WS登录签名失败")
        }
        let loginArg: [String: Any] = [
            "op": "login",
            "args": [[
                "apiKey": config.apiKey,
                "passphrase": config.passphrase,
                "timestamp": ts,
                "sign": sign
            ]]
        ]
        let data = try JSONSerialization.data(withJSONObject: loginArg)
        try await send(data: data)
        // 等待登录确认
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
    }

    // MARK: - 接收循环

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(let d): self.onMessage?(d)
                case .string(let s):
                    if let d = s.data(using: .utf8) { self.onMessage?(d) }
                @unknown default: break
                }
                self.receiveLoop()
            case .failure(let error):
                self.onDisconnected?(error)
                self.autoReconnect()
            }
        }
    }

    // MARK: - 发送

    private func send(data: Data) async throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw KLOKXAPIError(code: "WS_SEND_ENCODING", message: "订阅消息不是有效UTF-8")
        }
        try await task?.send(.string(text))
    }

    // MARK: - 订阅/取消

    public func subscribe(channel: String, instID: String) async throws {
        let sub: [String: Any] = [
            "op": "subscribe",
            "args": [["channel": channel, "instId": instID]]
        ]
        let data = try JSONSerialization.data(withJSONObject: sub)
        try await send(data: data)
        addSubscriptionLocked(KLOKXWSSubscription(channel: channel, instID: instID))
    }

    public func subscribeMultiple(_ subscriptions: [KLOKXWSSubscription]) async throws {
        let args = subscriptions.map { ["channel": $0.channel, "instId": $0.instID] }
        let sub: [String: Any] = ["op": "subscribe", "args": args]
        let data = try JSONSerialization.data(withJSONObject: sub)
        try await send(data: data)
        for s in subscriptions {
            addSubscriptionLocked(s)
        }
    }

    public func unsubscribe(channel: String, instID: String) async throws {
        let unsub: [String: Any] = [
            "op": "unsubscribe",
            "args": [["channel": channel, "instId": instID]]
        ]
        let data = try JSONSerialization.data(withJSONObject: unsub)
        try await send(data: data)
        removeSubscriptionLocked(channel: channel, instID: instID)
    }

    public func disconnect() {
        shouldReconnect = false
        reconnectWork?.cancel()
        reconnectWork = nil
        task?.cancel()
        task = nil
    }

    public func reconnect() async throws {
        shouldReconnect = true
        try await connect()
        try await restoreSubscriptions()
    }

    public func restoreSubscriptions() async throws {
        let snapshot = subscriptionsSnapshot()
        guard !snapshot.isEmpty else { return }
        try await subscribeMultiple(snapshot)
    }

    // MARK: - 自动重连

    private func autoReconnect() {
        guard shouldReconnect else { return }
        reconnectWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { [weak self] in
                guard let self = self, self.shouldReconnect else { return }
                try? await self.connect()
                try? await self.restoreSubscriptions()
            }
        }
        reconnectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + config.reconnectDelay, execute: work)
    }
}

// MARK: - KXFileSkeletonProtocol

public enum KXSY07Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"
    public static let descriptor = KXFileDescriptor(
        id: "KX-SY-07", fileName: "KX-SY-07_WebSocket执行器.swift", layer: .sync,
        relativePath: "网络同步层/KX-SY-07_WebSocket执行器.swift", duty: "WebSocket执行器"
    )
    public static func skeletonStatus() -> KXHealthCheckItem {
        klineLogger.info("WebSocket执行器骨架校验通过")
        return KXHealthCheckItem(name: "WebSocket执行器", passed: true, message: "已实现OKX WebSocket执行器")
    }
}
