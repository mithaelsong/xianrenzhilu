//
//  KX-SJ-05_同步状态访问.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：同步状态表读写接口骨架
//  禁止事项：禁止网络重试实现
//

import Foundation


// MARK: - 同步状态表字段约定

public enum KLSyncStatusTableColumn: String, Codable, Sendable, CaseIterable {
    case symbol
    case timeframe
    case state
    case lastSyncedAt
    case lastError
    case progress
    case createdAt
    case updatedAt
}

// MARK: - 同步状态表记录 DTO

public struct KLSyncStatusTableRecord: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframeRawValue: String
    public let stateRawValue: String
    public let lastSyncedAt: Date?
    public let lastError: String?
    public let progress: Double?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        symbol: KXSymbol,
        timeframeRawValue: String,
        stateRawValue: String,
        lastSyncedAt: Date? = nil,
        lastError: String? = nil,
        progress: Double? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.symbol = symbol
        self.timeframeRawValue = timeframeRawValue
        self.stateRawValue = stateRawValue
        self.lastSyncedAt = lastSyncedAt
        self.lastError = lastError
        self.progress = progress
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 查询条件

public struct KLSyncStatusQueryCondition: Codable, Equatable, Sendable {
    public let symbol: KXSymbol?
    public let timeframe: KXTimeframe?
    public let state: KLSyncState?
    public let updatedAfter: Date?
    public let updatedBefore: Date?
    public let limit: Int?
    public let order: KLQuerySortOrder

    public init(
        symbol: KXSymbol? = nil,
        timeframe: KXTimeframe? = nil,
        state: KLSyncState? = nil,
        updatedAfter: Date? = nil,
        updatedBefore: Date? = nil,
        limit: Int? = nil,
        order: KLQuerySortOrder = .ascending
    ) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.state = state
        self.updatedAfter = updatedAfter
        self.updatedBefore = updatedBefore
        self.limit = limit
        self.order = order
    }

    public static func bySymbol(_ symbol: KXSymbol) -> KLSyncStatusQueryCondition {
        KLSyncStatusQueryCondition(symbol: symbol)
    }

    public static func byTimeframe(_ timeframe: KXTimeframe) -> KLSyncStatusQueryCondition {
        KLSyncStatusQueryCondition(timeframe: timeframe)
    }

    public static func byState(_ state: KLSyncState) -> KLSyncStatusQueryCondition {
        KLSyncStatusQueryCondition(state: state)
    }

    public static func bySymbolTimeframeState(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        state: KLSyncState? = nil
    ) -> KLSyncStatusQueryCondition {
        KLSyncStatusQueryCondition(symbol: symbol, timeframe: timeframe, state: state)
    }
}

// MARK: - 更新请求

public struct KLSyncStatusUpdatePatch: Codable, Equatable, Sendable {
    public let state: KLSyncState?
    public let lastSyncedAt: Date?
    public let lastError: String?
    public let shouldClearLastError: Bool
    public let progress: Double?
    public let updatedAt: Date?

    public init(
        state: KLSyncState? = nil,
        lastSyncedAt: Date? = nil,
        lastError: String? = nil,
        shouldClearLastError: Bool = false,
        progress: Double? = nil,
        updatedAt: Date? = nil
    ) {
        self.state = state
        self.lastSyncedAt = lastSyncedAt
        self.lastError = lastError
        self.shouldClearLastError = shouldClearLastError
        self.progress = progress
        self.updatedAt = updatedAt
    }
}

public struct KLSyncStatusUpdateRequest: Codable, Equatable, Sendable {
    public let symbol: KXSymbol
    public let timeframe: KXTimeframe
    public let patch: KLSyncStatusUpdatePatch

    public init(symbol: KXSymbol, timeframe: KXTimeframe, patch: KLSyncStatusUpdatePatch) {
        self.symbol = symbol
        self.timeframe = timeframe
        self.patch = patch
    }

    public static func updateLastSyncedAt(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        lastSyncedAt: Date,
        progress: Double? = nil,
        updatedAt: Date? = nil
    ) -> KLSyncStatusUpdateRequest {
        KLSyncStatusUpdateRequest(
            symbol: symbol,
            timeframe: timeframe,
            patch: KLSyncStatusUpdatePatch(lastSyncedAt: lastSyncedAt, progress: progress, updatedAt: updatedAt)
        )
    }

    public static func updateLastError(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        lastError: String,
        state: KLSyncState = .failed,
        updatedAt: Date? = nil
    ) -> KLSyncStatusUpdateRequest {
        KLSyncStatusUpdateRequest(
            symbol: symbol,
            timeframe: timeframe,
            patch: KLSyncStatusUpdatePatch(state: state, lastError: lastError, updatedAt: updatedAt)
        )
    }

    public static func updateProgress(
        symbol: KXSymbol,
        timeframe: KXTimeframe,
        progress: Double,
        state: KLSyncState? = .syncing,
        updatedAt: Date? = nil
    ) -> KLSyncStatusUpdateRequest {
        KLSyncStatusUpdateRequest(
            symbol: symbol,
            timeframe: timeframe,
            patch: KLSyncStatusUpdatePatch(state: state, progress: progress, updatedAt: updatedAt)
        )
    }
}

// MARK: - 访问请求描述

public enum KLSyncStatusAccessRequest: Codable, Equatable, Sendable {
    case query(KLSyncStatusQueryCondition)
    case upsert(KLSyncStatusTableRecord)
    case update(KLSyncStatusUpdateRequest)
}

// MARK: - 结果摘要

public struct KLSyncStatusAccessResultSummary: Codable, Equatable, Sendable {
    public let request: KLSyncStatusAccessRequest
    public let matchedCount: Int
    public let changedCount: Int
    public let returnedCount: Int
    public let records: [KLSyncStatusTableRecord]
    public let generatedAt: Date
    public let note: String?

    public init(
        request: KLSyncStatusAccessRequest,
        matchedCount: Int = 0,
        changedCount: Int = 0,
        returnedCount: Int = 0,
        records: [KLSyncStatusTableRecord] = [],
        generatedAt: Date = Date(),
        note: String? = nil
    ) {
        self.request = request
        self.matchedCount = matchedCount
        self.changedCount = changedCount
        self.returnedCount = returnedCount
        self.records = records
        self.generatedAt = generatedAt
        self.note = note
    }
}

// MARK: - KL-02 同步状态类型与表记录纯映射

public enum KLSyncStatusTableMapper {
    public static func makeRecord(
        from descriptor: KLSyncStatusDescriptor,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) -> KLSyncStatusTableRecord {
        KLSyncStatusTableRecord(
            symbol: descriptor.symbol,
            timeframeRawValue: descriptor.timeframe.rawValue,
            stateRawValue: descriptor.state.rawValue,
            lastSyncedAt: descriptor.lastSyncedAt,
            lastError: descriptor.lastError,
            progress: descriptor.progress,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public static func makeDescriptor(from record: KLSyncStatusTableRecord) -> KLSyncStatusDescriptor? {
        guard let timeframe = KXTimeframe(rawValue: record.timeframeRawValue),
              let state = KLSyncState(rawValue: record.stateRawValue) else {
            return nil
        }

        return KLSyncStatusDescriptor(
            symbol: record.symbol,
            timeframe: timeframe,
            state: state,
            lastSyncedAt: record.lastSyncedAt,
            lastError: record.lastError,
            progress: record.progress
        )
    }

    public static func makeRecords(from descriptors: [KLSyncStatusDescriptor]) -> [KLSyncStatusTableRecord] {
        descriptors.map { makeRecord(from: $0) }
    }

    public static func makeDescriptors(from records: [KLSyncStatusTableRecord]) -> [KLSyncStatusDescriptor] {
        records.compactMap { makeDescriptor(from: $0) }
    }

    public static func makeRecord(
        byApplying request: KLSyncStatusUpdateRequest,
        to record: KLSyncStatusTableRecord
    ) -> KLSyncStatusTableRecord {
        let patch = request.patch
        return KLSyncStatusTableRecord(
            symbol: record.symbol,
            timeframeRawValue: record.timeframeRawValue,
            stateRawValue: patch.state?.rawValue ?? record.stateRawValue,
            lastSyncedAt: patch.lastSyncedAt ?? record.lastSyncedAt,
            lastError: patch.shouldClearLastError ? nil : (patch.lastError ?? record.lastError),
            progress: patch.progress ?? record.progress,
            createdAt: record.createdAt,
            updatedAt: patch.updatedAt ?? record.updatedAt
        )
    }
}

// MARK: - 同步状态表访问骨架

public enum KXSJ05Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-05",
        fileName: "KX-SJ-05_同步状态表访问.swift",
        layer: .data,
        relativePath: "数据层/KX-SJ-05_同步状态表访问.swift",
        duty: "同步状态表读写接口骨架"
    )

    public static func skeletonStatus() -> KLHealthCheckItem {
        KLHealthCheckItem(name: "同步状态表访问", passed: true, message: "已定义记录 DTO、查询条件、更新请求、结果摘要和纯映射；未执行 SQL 或数据库访问")
    }

    public static func placeholder() {
        // 本文件只提供同步状态表记录映射与访问请求描述。
        // 不执行 SQL、不连接数据库、不导入数据库驱动、不访问文件系统。
    }
}
