// KP-EN-02_形态监听器.swift
// 职责：通过 CandleDataSource 监听/检查形态识别结果；不直接联网、不读写数据库。

import Foundation

public final class CandlePatternWatcher {
    public static let shared = CandlePatternWatcher()
    public weak var dataSource: CandleDataSource?
    private let recognizer: CandlePatternRecognizer
    private var lastSeen: [String: Date] = [:]
    private let lock = NSLock()

    public init(dataSource: CandleDataSource? = nil, recognizer: CandlePatternRecognizer = .shared) { self.dataSource = dataSource; self.recognizer = recognizer }
    public func bind(dataSource: CandleDataSource?) { self.dataSource = dataSource }
    public func check(symbol: String, interval: String = "4h", limit: Int = 120, context: CandlePatternRecognitionContext = CandlePatternRecognitionContext()) -> [PatternMatchResult] { guard let dataSource else { return [] }; return recognizer.recognizeAll(candles: dataSource.loadCandles(symbol: symbol, interval: interval, limit: limit), context: context) }
    public func checkNew(symbol: String, interval: String = "4h", limit: Int = 120, context: CandlePatternRecognitionContext = CandlePatternRecognitionContext()) -> [PatternMatchResult] {
        let key = "\(symbol):\(interval)"
        let results = check(symbol: symbol, interval: interval, limit: limit, context: context)
        lock.lock()
        let lastTime = lastSeen[key]
        lock.unlock()
        let fresh = results.filter { item in guard let anchor = item.anchorTime, let lastTime else { return true }; return anchor > lastTime }
        if let newest = results.compactMap({ $0.anchorTime }).max() {
            lock.lock()
            lastSeen[key] = newest
            lock.unlock()
        }
        return fresh
    }
    public func checkAll(symbols: [String], interval: String = "4h", limit: Int = 120, context: CandlePatternRecognitionContext = CandlePatternRecognitionContext()) -> [String: [PatternMatchResult]] { Dictionary(uniqueKeysWithValues: symbols.map { ($0, check(symbol: $0, interval: interval, limit: limit, context: context)) }) }
}

public enum KPEN02PatternWatcherSkeleton: KPFileSkeletonProtocol {
    public static let descriptor = KPModuleRegistry.descriptor(id: "KP-EN-02") ?? KPFileDescriptor(id: "KP-EN-02", fileName: "KP-EN-02_形态监听器.swift", layer: .engine, relativePath: "识别引擎层/KP-EN-02_形态监听器.swift", duty: "基于数据源的形态监听与增量检查")
    public static func skeletonStatus() -> KPHealthCheckItem { KPHealthCheckItem(name: descriptor.id, passed: true, message: "Watcher通过CandleDataSource接入外部数据") }
}
