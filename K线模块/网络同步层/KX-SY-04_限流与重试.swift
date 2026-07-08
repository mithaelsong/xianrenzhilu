//
//  KX-SY-04_限流与重试.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：同步限流、重试、错误恢复策略骨架
//  禁止事项：禁止直接执行业务同步
//

import Foundation


// MARK: - KL-02 同步策略类型兼容别名

public typealias KLSyncRetryPolicyDescriptor = KLRetryPolicyDescriptor
public typealias KLSyncRateLimitDescriptor = KLRateLimitDescriptor

// MARK: - 限流策略 DTO

public enum KXSY04RateLimitMode: String, Codable, Sendable, CaseIterable {
    case slidingWindow
    case tokenBucket
}

public struct KXSY04RateLimitPolicyDTO: Codable, Equatable, Sendable {
    public let descriptor: KLSyncRateLimitDescriptor
    public let mode: KXSY04RateLimitMode
    public let requestCost: Int

    public init(descriptor: KLSyncRateLimitDescriptor, mode: KXSY04RateLimitMode = .slidingWindow, requestCost: Int = 1) {
        self.descriptor = descriptor
        self.mode = mode
        self.requestCost = max(1, requestCost)
    }
}

public struct KXSY04WindowBudgetInput: Codable, Equatable, Sendable {
    public let policy: KXSY04RateLimitPolicyDTO
    public let now: Date
    public let recentRequestTimestamps: [Date]

    public init(policy: KXSY04RateLimitPolicyDTO, now: Date = Date(), recentRequestTimestamps: [Date]) {
        self.policy = policy
        self.now = now
        self.recentRequestTimestamps = recentRequestTimestamps
    }
}

public struct KXSY04WindowBudgetResult: Codable, Equatable, Sendable {
    public let scope: String
    public let allowed: Bool
    public let maxRequests: Int
    public let intervalSeconds: Double
    public let usedRequests: Int
    public let remainingRequests: Int
    public let requestCost: Int
    public let windowStartedAt: Date
    public let resetAt: Date
    public let nextAllowedAt: Date

    public init(scope: String, allowed: Bool, maxRequests: Int, intervalSeconds: Double, usedRequests: Int, remainingRequests: Int, requestCost: Int, windowStartedAt: Date, resetAt: Date, nextAllowedAt: Date) {
        self.scope = scope
        self.allowed = allowed
        self.maxRequests = maxRequests
        self.intervalSeconds = intervalSeconds
        self.usedRequests = usedRequests
        self.remainingRequests = remainingRequests
        self.requestCost = requestCost
        self.windowStartedAt = windowStartedAt
        self.resetAt = resetAt
        self.nextAllowedAt = nextAllowedAt
    }
}

public struct KXSY04TokenBudgetInput: Codable, Equatable, Sendable {
    public let policy: KXSY04RateLimitPolicyDTO
    public let now: Date
    public let lastRefillAt: Date
    public let currentTokens: Double

    public init(policy: KXSY04RateLimitPolicyDTO, now: Date = Date(), lastRefillAt: Date, currentTokens: Double) {
        self.policy = policy
        self.now = now
        self.lastRefillAt = lastRefillAt
        self.currentTokens = currentTokens
    }
}

public struct KXSY04TokenBudgetResult: Codable, Equatable, Sendable {
    public let scope: String
    public let allowed: Bool
    public let capacity: Double
    public let refillRatePerSecond: Double
    public let availableTokensBeforeCost: Double
    public let remainingTokensAfterCost: Double
    public let requestCost: Double
    public let nextRefillAt: Date
    public let nextAllowedAt: Date

    public init(scope: String, allowed: Bool, capacity: Double, refillRatePerSecond: Double, availableTokensBeforeCost: Double, remainingTokensAfterCost: Double, requestCost: Double, nextRefillAt: Date, nextAllowedAt: Date) {
        self.scope = scope
        self.allowed = allowed
        self.capacity = capacity
        self.refillRatePerSecond = refillRatePerSecond
        self.availableTokensBeforeCost = availableTokensBeforeCost
        self.remainingTokensAfterCost = remainingTokensAfterCost
        self.requestCost = requestCost
        self.nextRefillAt = nextRefillAt
        self.nextAllowedAt = nextAllowedAt
    }
}

// MARK: - 重试、退避与错误恢复 DTO

public enum KXSY04SyncErrorCategory: String, Codable, Sendable, CaseIterable {
    case transientNetwork
    case timeout
    case rateLimited
    case server
    case client
    case authentication
    case dataIntegrity
    case cancelled
    case unknown
}

public enum KXSY04RecoveryStrategy: String, Codable, Sendable, CaseIterable {
    case retryAfterDelay
    case waitForRateLimit
    case refreshAuthentication
    case discardRequest
    case surfaceFailure
    case ignoreCancellation
}

public struct KXSY04SyncErrorDTO: Codable, Equatable, Sendable {
    public let httpStatusCode: Int?
    public let urlErrorCode: Int?
    public let message: String?
    public let retryAfterSeconds: Double?
    public let isTimeout: Bool
    public let isCancelled: Bool
    public let isDataIntegrityError: Bool

    public init(httpStatusCode: Int? = nil, urlErrorCode: Int? = nil, message: String? = nil, retryAfterSeconds: Double? = nil, isTimeout: Bool = false, isCancelled: Bool = false, isDataIntegrityError: Bool = false) {
        self.httpStatusCode = httpStatusCode
        self.urlErrorCode = urlErrorCode
        self.message = message
        self.retryAfterSeconds = retryAfterSeconds
        self.isTimeout = isTimeout
        self.isCancelled = isCancelled
        self.isDataIntegrityError = isDataIntegrityError
    }
}

public struct KXSY04RetryPolicyDTO: Codable, Equatable, Sendable {
    public let descriptor: KLSyncRetryPolicyDescriptor
    public let retryableCategories: [KXSY04SyncErrorCategory]
    public let nonRetryableCategories: [KXSY04SyncErrorCategory]

    public init(descriptor: KLSyncRetryPolicyDescriptor, retryableCategories: [KXSY04SyncErrorCategory] = [.transientNetwork, .timeout, .rateLimited, .server, .unknown], nonRetryableCategories: [KXSY04SyncErrorCategory] = [.client, .authentication, .dataIntegrity, .cancelled]) {
        self.descriptor = descriptor
        self.retryableCategories = retryableCategories
        self.nonRetryableCategories = nonRetryableCategories
    }
}

public struct KXSY04BackoffPlan: Codable, Equatable, Sendable {
    public let attemptIndex: Int
    public let rawExponentialDelaySeconds: Double
    public let jitterRatio: Double
    public let finalDelaySeconds: Double
    public let nextAttemptAt: Date

    public init(attemptIndex: Int, rawExponentialDelaySeconds: Double, jitterRatio: Double, finalDelaySeconds: Double, nextAttemptAt: Date) {
        self.attemptIndex = attemptIndex
        self.rawExponentialDelaySeconds = rawExponentialDelaySeconds
        self.jitterRatio = jitterRatio
        self.finalDelaySeconds = finalDelaySeconds
        self.nextAttemptAt = nextAttemptAt
    }
}

public struct KXSY04RetryDecision: Codable, Equatable, Sendable {
    public let shouldRetry: Bool
    public let category: KXSY04SyncErrorCategory
    public let recoveryStrategy: KXSY04RecoveryStrategy
    public let attemptIndex: Int
    public let maxRetries: Int
    public let remainingRetries: Int
    public let delaySeconds: Double
    public let nextAttemptAt: Date?
    public let reason: String

    public init(shouldRetry: Bool, category: KXSY04SyncErrorCategory, recoveryStrategy: KXSY04RecoveryStrategy, attemptIndex: Int, maxRetries: Int, remainingRetries: Int, delaySeconds: Double, nextAttemptAt: Date?, reason: String) {
        self.shouldRetry = shouldRetry
        self.category = category
        self.recoveryStrategy = recoveryStrategy
        self.attemptIndex = attemptIndex
        self.maxRetries = maxRetries
        self.remainingRetries = remainingRetries
        self.delaySeconds = delaySeconds
        self.nextAttemptAt = nextAttemptAt
        self.reason = reason
    }
}

// MARK: - 纯策略计算器

public enum KXSY04StrategyCalculator {
    public static func windowBudget(_ input: KXSY04WindowBudgetInput) -> KXSY04WindowBudgetResult {
        let descriptor = input.policy.descriptor
        let maxRequests = max(0, descriptor.maxRequests)
        let intervalSeconds = max(0, descriptor.intervalSeconds)
        let requestCost = max(1, input.policy.requestCost)
        let windowStartedAt = input.now.addingTimeInterval(-intervalSeconds)
        let timestampsInWindow = input.recentRequestTimestamps
            .filter { $0 >= windowStartedAt && $0 <= input.now }
            .sorted()
        let usedRequests = timestampsInWindow.count
        let remainingRequests = max(0, maxRequests - usedRequests)
        let allowed = maxRequests > 0 && intervalSeconds > 0 && remainingRequests >= requestCost
        let resetAt = timestampsInWindow.first?.addingTimeInterval(intervalSeconds) ?? input.now
        let nextAllowedAt = allowed ? input.now : resetAt

        return KXSY04WindowBudgetResult(
            scope: descriptor.scope,
            allowed: allowed,
            maxRequests: maxRequests,
            intervalSeconds: intervalSeconds,
            usedRequests: usedRequests,
            remainingRequests: remainingRequests,
            requestCost: requestCost,
            windowStartedAt: windowStartedAt,
            resetAt: resetAt,
            nextAllowedAt: nextAllowedAt
        )
    }

    public static func tokenBudget(_ input: KXSY04TokenBudgetInput) -> KXSY04TokenBudgetResult {
        let descriptor = input.policy.descriptor
        let capacity = max(0, Double(descriptor.maxRequests))
        let intervalSeconds = max(0, descriptor.intervalSeconds)
        let requestCost = Double(max(1, input.policy.requestCost))
        let refillRatePerSecond = intervalSeconds > 0 ? capacity / intervalSeconds : 0
        let elapsedSeconds = max(0, input.now.timeIntervalSince(input.lastRefillAt))
        let refilledTokens = input.currentTokens + elapsedSeconds * refillRatePerSecond
        let availableTokens = min(capacity, max(0, refilledTokens))
        let allowed = capacity > 0 && refillRatePerSecond > 0 && availableTokens >= requestCost
        let remainingTokens = allowed ? max(0, availableTokens - requestCost) : availableTokens
        let deficit = max(0, requestCost - availableTokens)
        let secondsUntilAllowed = refillRatePerSecond > 0 ? deficit / refillRatePerSecond : Double.infinity
        let nextAllowedAt = allowed ? input.now : input.now.addingTimeInterval(secondsUntilAllowed.isFinite ? secondsUntilAllowed : 0)

        return KXSY04TokenBudgetResult(
            scope: descriptor.scope,
            allowed: allowed,
            capacity: capacity,
            refillRatePerSecond: refillRatePerSecond,
            availableTokensBeforeCost: availableTokens,
            remainingTokensAfterCost: remainingTokens,
            requestCost: requestCost,
            nextRefillAt: input.now,
            nextAllowedAt: nextAllowedAt
        )
    }

    public static func classifyError(_ error: KXSY04SyncErrorDTO) -> KXSY04SyncErrorCategory {
        if error.isCancelled { return .cancelled }
        if error.isDataIntegrityError { return .dataIntegrity }
        if error.isTimeout { return .timeout }

        if let statusCode = error.httpStatusCode {
            switch statusCode {
            case 401, 403:
                return .authentication
            case 408, 504:
                return .timeout
            case 425, 429:
                return .rateLimited
            case 500...599:
                return .server
            case 400...499:
                return .client
            default:
                break
            }
        }

        if let urlErrorCode = error.urlErrorCode {
            switch urlErrorCode {
            case -999:
                return .cancelled
            case -1001:
                return .timeout
            case -1003, -1004, -1005, -1009, -1011, -1200, -1202:
                return .transientNetwork
            default:
                break
            }
        }

        let lowercasedMessage = (error.message ?? "").lowercased()
        if lowercasedMessage.contains("timeout") || lowercasedMessage.contains("timed out") { return .timeout }
        if lowercasedMessage.contains("rate limit") || lowercasedMessage.contains("too many request") { return .rateLimited }
        if lowercasedMessage.contains("unauthorized") || lowercasedMessage.contains("forbidden") { return .authentication }
        if lowercasedMessage.contains("network") || lowercasedMessage.contains("connection") { return .transientNetwork }

        return .unknown
    }

    public static func recoveryStrategy(for category: KXSY04SyncErrorCategory) -> KXSY04RecoveryStrategy {
        switch category {
        case .transientNetwork, .timeout, .server, .unknown:
            return .retryAfterDelay
        case .rateLimited:
            return .waitForRateLimit
        case .authentication:
            return .refreshAuthentication
        case .client, .dataIntegrity:
            return .surfaceFailure
        case .cancelled:
            return .ignoreCancellation
        }
    }

    public static func deterministicJitterRatio(seed: String, attemptIndex: Int) -> Double {
        let source = "\(seed)#\(attemptIndex)"
        var hash: UInt64 = 14_695_981_039_346_656_037
        for scalar in source.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash &*= 1_099_511_628_211
        }
        let bucket = Double(hash % 10_000) / 10_000.0
        return bucket
    }

    public static func exponentialBackoff(policy: KLSyncRetryPolicyDescriptor, attemptIndex: Int, now: Date = Date(), jitterSeed: String = "") -> KXSY04BackoffPlan {
        let normalizedAttempt = max(0, attemptIndex)
        let baseDelay = max(0, policy.baseDelaySeconds)
        let maxDelay = max(0, policy.maxDelaySeconds)
        let exponent = min(normalizedAttempt, 30)
        let multiplier = pow(2.0, Double(exponent))
        let rawDelay = min(maxDelay, baseDelay * multiplier)
        let jitterRatio = policy.jitterEnabled ? deterministicJitterRatio(seed: jitterSeed, attemptIndex: normalizedAttempt) : 1
        let jitteredDelay = policy.jitterEnabled ? rawDelay * jitterRatio : rawDelay
        let finalDelay = min(maxDelay, max(0, jitteredDelay))
        let nextAttemptAt = now.addingTimeInterval(finalDelay)

        return KXSY04BackoffPlan(
            attemptIndex: normalizedAttempt,
            rawExponentialDelaySeconds: rawDelay,
            jitterRatio: jitterRatio,
            finalDelaySeconds: finalDelay,
            nextAttemptAt: nextAttemptAt
        )
    }

    public static func nextAttemptTime(now: Date = Date(), delaySeconds: Double, notBefore: Date? = nil) -> Date {
        let delayDate = now.addingTimeInterval(max(0, delaySeconds))
        guard let notBefore else { return delayDate }
        return max(delayDate, notBefore)
    }

    public static func retryDecision(policy: KXSY04RetryPolicyDTO, error: KXSY04SyncErrorDTO, attemptIndex: Int, now: Date = Date(), jitterSeed: String = "", rateLimitNextAllowedAt: Date? = nil) -> KXSY04RetryDecision {
        let normalizedAttempt = max(0, attemptIndex)
        let maxRetries = max(0, policy.descriptor.maxRetries)
        let category = classifyError(error)
        let strategy = recoveryStrategy(for: category)
        let categoryRetryable = policy.retryableCategories.contains(category) && !policy.nonRetryableCategories.contains(category)
        let hasRemainingRetry = normalizedAttempt < maxRetries
        let shouldRetry = categoryRetryable && hasRemainingRetry
        let remainingRetries = max(0, maxRetries - normalizedAttempt - (shouldRetry ? 1 : 0))

        guard shouldRetry else {
            let reason = categoryRetryable ? "已达到最大重试次数" : "错误类别不可重试"
            return KXSY04RetryDecision(
                shouldRetry: false,
                category: category,
                recoveryStrategy: strategy,
                attemptIndex: normalizedAttempt,
                maxRetries: maxRetries,
                remainingRetries: max(0, maxRetries - normalizedAttempt),
                delaySeconds: 0,
                nextAttemptAt: nil,
                reason: reason
            )
        }

        let backoff = exponentialBackoff(policy: policy.descriptor, attemptIndex: normalizedAttempt, now: now, jitterSeed: jitterSeed)
        let retryAfterDate = error.retryAfterSeconds.map { now.addingTimeInterval(max(0, $0)) }
        let notBefore = latestDate(retryAfterDate, rateLimitNextAllowedAt)
        let nextAttemptAt = nextAttemptTime(now: now, delaySeconds: backoff.finalDelaySeconds, notBefore: notBefore)
        let delaySeconds = max(0, nextAttemptAt.timeIntervalSince(now))

        return KXSY04RetryDecision(
            shouldRetry: true,
            category: category,
            recoveryStrategy: strategy,
            attemptIndex: normalizedAttempt,
            maxRetries: maxRetries,
            remainingRetries: remainingRetries,
            delaySeconds: delaySeconds,
            nextAttemptAt: nextAttemptAt,
            reason: "允许重试：\(category.rawValue)，下一次尝试时间已按退避、Retry-After 与限流预算合并计算"
        )
    }

    public static func latestDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case (.some(let left), .some(let right)):
            return max(left, right)
        case (.some(let left), .none):
            return left
        case (.none, .some(let right)):
            return right
        case (.none, .none):
            return nil
        }
    }
}

// MARK: - 同步限流与重试骨架

public enum KXSY04Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SY-04",
        fileName: "KX-SY-04_同步限流与重试.swift",
        layer: .sync,
        relativePath: "同步层/KX-SY-04_同步限流与重试.swift",
        duty: "同步限流、重试、错误恢复纯策略计算"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "同步限流与重试", passed: true, message: "已提供限流预算、重试退避、错误分类与下一次尝试时间纯策略计算")
    }

    public static func placeholder() {
        // 本文件只提供纯策略计算：不启动 Timer、不 sleep、不发请求、不连数据库、不写文件。
    }
}
