//
//  KX-SJ-01_数据库连接.swift
//  仙人指路2-min｜K线模块
//
//  版本：2.0
//  职责：描述 K线数据库连接、schema、表名、读写边界
//  禁止事项：禁止真实连接执行、禁止写业务
//

import Foundation


// MARK: - 数据库连接配置 DTO

/// K线数据库连接配置描述 DTO。
///
/// 本类型只描述连接所需的静态配置，不持有连接句柄，不导入数据库驱动，
/// 不执行 SQL，不访问文件系统，也不请求网络。
public struct KXSJ01ConnectionConfigurationDTO: Codable, Equatable, Sendable {
    public let identifier: String
    public let engine: String
    public let databaseName: String
    public let schemaName: String
    public let hostAlias: String
    public let portDescription: String
    public let roleName: String
    public let sslModeDescription: String
    public let readonly: Bool
    public let connectionPoolDescription: String
    public let timeoutPolicyDescription: String

    public init(
        identifier: String = "kl-db-main",
        engine: String = "PostgreSQL-compatible descriptor",
        databaseName: String = KXSJ01DatabaseCatalog.defaultDatabaseName,
        schemaName: String = KXSJ01DatabaseCatalog.defaultSchemaName,
        hostAlias: String = "由上层运行环境注入，本文件不读取环境变量",
        portDescription: String = "由上层运行环境注入，本文件不读取端口配置",
        roleName: String = "kline_module_role",
        sslModeDescription: String = "由部署环境决定，本文件仅记录描述",
        readonly: Bool = false,
        connectionPoolDescription: String = "连接池由仓储/基础设施层创建，本文件不创建连接池",
        timeoutPolicyDescription: String = "超时策略由调用方执行，本文件不启动计时器"
    ) {
        self.identifier = identifier
        self.engine = engine
        self.databaseName = databaseName
        self.schemaName = schemaName
        self.hostAlias = hostAlias
        self.portDescription = portDescription
        self.roleName = roleName
        self.sslModeDescription = sslModeDescription
        self.readonly = readonly
        self.connectionPoolDescription = connectionPoolDescription
        self.timeoutPolicyDescription = timeoutPolicyDescription
    }

    public var connectionDescriptor: KLDatabaseConnectionDescriptor {
        KLDatabaseConnectionDescriptor(
            identifier: identifier,
            databaseName: databaseName,
            schemaName: schemaName,
            readonly: readonly
        )
    }
}

// MARK: - Schema 与表名目录

public enum KXSJ01TableName: String, Codable, Sendable, CaseIterable {
    case candles = "kl_candles"
    case tradingPairs = "kl_trading_pairs"
    case syncStates = "kl_sync_states"
    case gapRanges = "kl_gap_ranges"
    case backfillTasks = "kl_backfill_tasks"
    case visibleWindows = "kl_visible_windows"
    case markerEvents = "kl_marker_events"
    case alertRules = "kl_alert_rules"
    case alertEvents = "kl_alert_events"

    public var primaryKeys: [String] {
        switch self {
        case .candles:
            return ["symbol", "timeframe", "open_time"]
        case .tradingPairs:
            return ["symbol", "exchange_id", "instrument_id"]
        case .syncStates:
            return ["symbol", "timeframe"]
        case .gapRanges:
            return ["symbol", "timeframe", "start_time", "end_time"]
        case .backfillTasks:
            return ["id"]
        case .visibleWindows:
            return ["workspace_id", "symbol", "timeframe"]
        case .markerEvents:
            return ["id"]
        case .alertRules:
            return ["id"]
        case .alertEvents:
            return ["id"]
        }
    }

    public var duty: String {
        switch self {
        case .candles:
            return "存放标准化 K线蜡烛数据，按交易对、周期、开盘时间定位"
        case .tradingPairs:
            return "存放交易对与交易所映射、精度、上下线状态等基础资料"
        case .syncStates:
            return "记录每个交易对与周期的数据同步状态、进度与最近错误描述"
        case .gapRanges:
            return "记录历史 K线缺口范围，供补洞任务生成与审计"
        case .backfillTasks:
            return "记录缺口补洞任务描述、优先级、创建时间与重试次数"
        case .visibleWindows:
            return "记录图表可视窗口快照，用于恢复用户工作区视图"
        case .markerEvents:
            return "记录 K线标记、形态识别结果、手工标注与信号说明"
        case .alertRules:
            return "记录提示音/价格/成交量等告警规则描述"
        case .alertEvents:
            return "记录已生成的告警事件及投递状态"
        }
    }

    public var descriptor: KLTableDescriptor {
        KLTableDescriptor(name: rawValue, primaryKeys: primaryKeys, duty: duty)
    }
}

public enum KXSJ01DatabaseCatalog {
    public static let defaultDatabaseName = "xianren_kline"
    public static let defaultSchemaName = "kline"
    public static let defaultConnectionIdentifier = "kl-db-main"

    public static let defaultConnectionDescriptor = KLDatabaseConnectionDescriptor(
        identifier: defaultConnectionIdentifier,
        databaseName: defaultDatabaseName,
        schemaName: defaultSchemaName,
        readonly: false
    )

    public static let readOnlyConnectionDescriptor = KLDatabaseConnectionDescriptor(
        identifier: "kl-db-readonly",
        databaseName: defaultDatabaseName,
        schemaName: defaultSchemaName,
        readonly: true
    )

    public static let defaultConfiguration = KXSJ01ConnectionConfigurationDTO()
    public static let tableDescriptors = KXSJ01TableName.allCases.map { $0.descriptor }

    public static func descriptor(for tableName: KXSJ01TableName) -> KLTableDescriptor {
        tableName.descriptor
    }

    public static func schemaDescription() -> String {
        "默认 schema 为 \(defaultSchemaName)，仅作为 K线模块数据表命名空间描述；schema 创建、迁移和 SQL 执行不在本文件职责内。"
    }
}

// MARK: - 读写能力边界

public struct KXSJ01ReadWriteBoundaryDescriptor: Codable, Equatable, Sendable {
    public let readableTables: [String]
    public let writableTables: [String]
    public let appendOnlyTables: [String]
    public let updateAllowedTables: [String]
    public let deleteAllowedTables: [String]
    public let forbiddenOperations: [String]
    public let notes: [String]

    public init(
        readableTables: [String],
        writableTables: [String],
        appendOnlyTables: [String],
        updateAllowedTables: [String],
        deleteAllowedTables: [String],
        forbiddenOperations: [String],
        notes: [String]
    ) {
        self.readableTables = readableTables
        self.writableTables = writableTables
        self.appendOnlyTables = appendOnlyTables
        self.updateAllowedTables = updateAllowedTables
        self.deleteAllowedTables = deleteAllowedTables
        self.forbiddenOperations = forbiddenOperations
        self.notes = notes
    }
}

public enum KXSJ01AccessBoundaryCatalog {
    public static let descriptor = KXSJ01ReadWriteBoundaryDescriptor(
        readableTables: KXSJ01TableName.allCases.map(\.rawValue),
        writableTables: [
            KXSJ01TableName.candles.rawValue,
            KXSJ01TableName.tradingPairs.rawValue,
            KXSJ01TableName.syncStates.rawValue,
            KXSJ01TableName.gapRanges.rawValue,
            KXSJ01TableName.backfillTasks.rawValue,
            KXSJ01TableName.visibleWindows.rawValue,
            KXSJ01TableName.markerEvents.rawValue,
            KXSJ01TableName.alertRules.rawValue,
            KXSJ01TableName.alertEvents.rawValue
        ],
        appendOnlyTables: [
            KXSJ01TableName.candles.rawValue,
            KXSJ01TableName.alertEvents.rawValue
        ],
        updateAllowedTables: [
            KXSJ01TableName.tradingPairs.rawValue,
            KXSJ01TableName.syncStates.rawValue,
            KXSJ01TableName.gapRanges.rawValue,
            KXSJ01TableName.backfillTasks.rawValue,
            KXSJ01TableName.visibleWindows.rawValue,
            KXSJ01TableName.markerEvents.rawValue,
            KXSJ01TableName.alertRules.rawValue
        ],
        deleteAllowedTables: [
            KXSJ01TableName.visibleWindows.rawValue,
            KXSJ01TableName.markerEvents.rawValue,
            KXSJ01TableName.alertRules.rawValue
        ],
        forbiddenOperations: [
            "本文件禁止建立真实数据库连接",
            "本文件禁止执行 SQL 或迁移脚本",
            "本文件禁止导入任何数据库驱动",
            "本文件禁止读取环境变量、配置文件或钥匙串",
            "本文件禁止请求网络或访问文件系统",
            "本文件禁止跨 K线模块数据层直接写入其他模块"
        ],
        notes: [
            "读操作边界：仅描述 K线模块表的可读范围，实际查询由仓储层实现。",
            "写操作边界：仅描述允许写入的表集合，实际写入需由仓储层校验幂等、去重与事务策略。",
            "appendOnly 表只描述追加语义；若需要修正历史数据，应由后续迁移/审计任务定义专门策略。",
            "deleteAllowedTables 仅覆盖用户视图、标记、告警规则等可清理描述数据，不包含蜡烛主数据。"
        ]
    )
}

// MARK: - 连接健康检查描述

public struct KXSJ01ConnectionHealthCheckDescriptor: Codable, Equatable, Sendable {
    public let name: String
    public let doesEstablishConnection: Bool
    public let checkedDescriptorFields: [String]
    public let expectedResultDescription: String
    public let failureMeaningDescription: String

    public init(
        name: String = "K线数据库连接描述健康检查",
        doesEstablishConnection: Bool = false,
        checkedDescriptorFields: [String] = ["identifier", "databaseName", "schemaName", "readonly", "tableDescriptors", "readWriteBoundary"],
        expectedResultDescription: String = "只校验描述对象是否齐全，不探测数据库可达性",
        failureMeaningDescription: String = "失败仅代表本地描述不完整，不代表数据库真实不可用"
    ) {
        self.name = name
        self.doesEstablishConnection = doesEstablishConnection
        self.checkedDescriptorFields = checkedDescriptorFields
        self.expectedResultDescription = expectedResultDescription
        self.failureMeaningDescription = failureMeaningDescription
    }

    public var healthItem: KLHealthCheckItem {
        KLHealthCheckItem(
            name: name,
            passed: !doesEstablishConnection,
            message: expectedResultDescription,
            severity: .info
        )
    }
}

// MARK: - K线数据库连接描述骨架

public enum KXSJ01Skeleton: KXFileSkeletonProtocol {
    public static let version = "2.0"

    public static let descriptor = KXFileDescriptor(
        id: "KX-SJ-01",
        fileName: "KX-SJ-01_K线数据库连接描述.swift",
        layer: .data,
        relativePath: "数据层/KX-SJ-01_K线数据库连接描述.swift",
        duty: "描述 K线数据库连接、schema、表名、读写边界"
    )

    public static let connectionConfiguration = KXSJ01DatabaseCatalog.defaultConfiguration
    public static let connectionDescriptor = KXSJ01DatabaseCatalog.defaultConnectionDescriptor
    public static let readOnlyConnectionDescriptor = KXSJ01DatabaseCatalog.readOnlyConnectionDescriptor
    public static let defaultSchemaName = KXSJ01DatabaseCatalog.defaultSchemaName
    public static let tableDescriptors = KXSJ01DatabaseCatalog.tableDescriptors
    public static let readWriteBoundary = KXSJ01AccessBoundaryCatalog.descriptor
    public static let healthCheckDescriptor = KXSJ01ConnectionHealthCheckDescriptor()

    public static func skeletonStatus() -> KLHealthCheckItem {
        healthCheckDescriptor.healthItem
    }

    public static func tableDescriptor(for tableName: KXSJ01TableName) -> KLTableDescriptor {
        KXSJ01DatabaseCatalog.descriptor(for: tableName)
    }

    public static func schemaDescription() -> String {
        KXSJ01DatabaseCatalog.schemaDescription()
    }
}
