//
//  KX-GL-02_注册表.swift
//  仙人指路测试项目｜K线模块
//
//  版本：2.0
//  职责：登记所有 K线模块目标文件、路径、版本、职责、完整性校验骨架
//  禁止事项：禁止业务实现、数据库读写、网络请求、UI适配、缓存实现、同步任务实现
//

import Foundation


// MARK: - 统一注册清单

public enum KXUnifiedRegistry {
    public static let version = KXVersion(major: 2, minor: 0)
    public static var expectedFileCount: Int { allFiles.count }

    public static func descriptor(id: String) -> KXFileDescriptor? {
        allFiles.first { $0.id == id }
    }

    public static func descriptors(layer: KXModuleLayer) -> [KXFileDescriptor] {
        allFiles.filter { $0.layer == layer }
    }

    public static var allFiles: [KXFileDescriptor] = [
        // MARK: 核心管理层
        KXFileDescriptor(id: "KX-GL-01", fileName: "KX-GL-01_入口.swift", layer: .management, relativePath: "核心管理层/KX-GL-01_入口.swift", version: .init(major: 2, minor: 0), duty: "统一入口、装配、自检、调用注册表、启动链路检查清单"),
        KXFileDescriptor(id: "KX-GL-02", fileName: "KX-GL-02_注册表.swift", layer: .management, relativePath: "核心管理层/KX-GL-02_注册表.swift", version: .init(major: 2, minor: 0), duty: "登记所有 K线模块文件、路径、版本、职责、完整性校验骨架"),
        KXFileDescriptor(id: "KX-GL-03", fileName: "KX-GL-03_公共类型.swift", layer: .management, relativePath: "核心管理层/KX-GL-03_公共类型.swift", version: .init(major: 2, minor: 0), duty: "公共类型、公共协议、错误类型、数据模型、描述符、协议签名、初始化器"),

        // MARK: 业务功能层
        KXFileDescriptor(id: "KX-FN-01", fileName: "KX-FN-01_交易对管理.swift", layer: .function, relativePath: "业务功能层/KX-FN-01_交易对管理.swift", version: .init(major: 2, minor: 0), duty: "读取交易对目录、过滤交易对、给 UI 和收藏服务提供交易对清单"),
        KXFileDescriptor(id: "KX-FN-02", fileName: "KX-FN-02_周期管理.swift", layer: .function, relativePath: "业务功能层/KX-FN-02_周期管理.swift", version: .init(major: 2, minor: 0), duty: "维护周期枚举、周期排序、周期显示名、周期秒数转换"),
        KXFileDescriptor(id: "KX-FN-03", fileName: "KX-FN-03_数据聚合调度.swift", layer: .function, relativePath: "业务功能层/KX-FN-03_数据聚合调度.swift", version: .init(major: 2, minor: 0), duty: "协调成交明细或低周期 K线聚合为目标周期的调度骨架"),
        KXFileDescriptor(id: "KX-FN-04", fileName: "KX-FN-04_数据标准化.swift", layer: .function, relativePath: "业务功能层/KX-FN-04_数据标准化.swift", version: .init(major: 2, minor: 0), duty: "把外部 K线数据转换为统一 OHLCV 数据模型的骨架"),
        KXFileDescriptor(id: "KX-FN-05", fileName: "KX-FN-05_缺口检测.swift", layer: .function, relativePath: "业务功能层/KX-FN-05_缺口检测.swift", version: .init(major: 2, minor: 0), duty: "检查指定币对、周期、时间范围内的 K线缺口"),
        KXFileDescriptor(id: "KX-FN-06", fileName: "KX-FN-06_补洞任务生成.swift", layer: .function, relativePath: "业务功能层/KX-FN-06_补洞任务生成.swift", version: .init(major: 2, minor: 0), duty: "把缺口区间转换为补洞任务描述"),
        KXFileDescriptor(id: "KX-FN-07", fileName: "KX-FN-07_多标签订阅管理.swift", layer: .function, relativePath: "业务功能层/KX-FN-07_多标签订阅管理.swift", version: .init(major: 2, minor: 0), duty: "维护每个标签的币对、周期、订阅状态、缓存状态"),
        KXFileDescriptor(id: "KX-FN-08", fileName: "KX-FN-08_可视窗口切片.swift", layer: .function, relativePath: "业务功能层/KX-FN-08_可视窗口切片.swift", version: .init(major: 2, minor: 0), duty: "按 UI 可视窗口返回 K线切片的接口骨架"),
        KXFileDescriptor(id: "KX-FN-09", fileName: "KX-FN-09_预加载调度.swift", layer: .function, relativePath: "业务功能层/KX-FN-09_预加载调度.swift", version: .init(major: 2, minor: 0), duty: "按滚动方向生成预加载请求和缓存预热计划"),
        KXFileDescriptor(id: "KX-FN-10", fileName: "KX-FN-10_坐标映射.swift", layer: .function, relativePath: "业务功能层/KX-FN-10_坐标映射.swift", version: .init(major: 2, minor: 0), duty: "时间价格与屏幕坐标的映射骨架"),
        KXFileDescriptor(id: "KX-FN-11", fileName: "KX-FN-11_高低点吸附.swift", layer: .function, relativePath: "业务功能层/KX-FN-11_高低点吸附.swift", version: .init(major: 2, minor: 0), duty: "为画线工具提供高点、低点、开收盘等吸附点"),
        KXFileDescriptor(id: "KX-FN-12", fileName: "KX-FN-12_OKX周期映射.swift", layer: .function, relativePath: "业务功能层/KX-FN-12_OKX周期映射.swift", version: .init(major: 2, minor: 0), duty: "KXTimeframe ↔ OKX bar/channel 映射、存储策略"),
        KXFileDescriptor(id: "KX-FN-13", fileName: "KX-FN-13_价格轴刻度.swift", layer: .function, relativePath: "业务功能层/KX-FN-13_价格轴刻度.swift", version: .init(major: 2, minor: 0), duty: "价格轴刻度生成与格式化"),
        KXFileDescriptor(id: "KX-FN-14", fileName: "KX-FN-14_时间轴刻度.swift", layer: .function, relativePath: "业务功能层/KX-FN-14_时间轴刻度.swift", version: .init(major: 2, minor: 0), duty: "时间轴刻度生成与格式化"),
        KXFileDescriptor(id: "KX-FN-15", fileName: "KX-FN-15_视口缩放平移.swift", layer: .function, relativePath: "业务功能层/KX-FN-15_视口缩放平移.swift", version: .init(major: 2, minor: 0), duty: "图表视口的缩放和平移逻辑"),
        KXFileDescriptor(id: "KX-FN-16", fileName: "KX-FN-16_实时价格线模型.swift", layer: .function, relativePath: "业务功能层/KX-FN-16_实时价格线模型.swift", version: .init(major: 2, minor: 0), duty: "实时价格线的模型和逻辑"),
        KXFileDescriptor(id: "KX-FN-17", fileName: "KX-FN-17_面板状态模型.swift", layer: .function, relativePath: "业务功能层/KX-FN-17_面板状态模型.swift", version: .init(major: 2, minor: 0), duty: "K线面板状态的模型和序列化"),
        KXFileDescriptor(id: "KX-FN-18", fileName: "KX-FN-18_启动恢复管道.swift", layer: .function, relativePath: "业务功能层/KX-FN-18_启动恢复管道.swift", version: .init(major: 2, minor: 0), duty: "K线模块启动时的恢复管道逻辑"),
        KXFileDescriptor(id: "KX-FN-19", fileName: "KX-FN-19_指标管理.swift", layer: .function, relativePath: "业务功能层/KX-FN-19_指标管理.swift", version: .init(major: 2, minor: 0), duty: "技术指标管理、分类、搜索、加载"),

        // MARK: 业务功能层（接口）
        KXFileDescriptor(id: "KX-FN-20", fileName: "KX-FN-20_CandleDataSource适配.swift", layer: .function, relativePath: "业务功能层/KX-FN-20_CandleDataSource适配.swift", version: .init(major: 2, minor: 0), duty: "适配 K线形态识别模块需要的 Candle 数据源"),
        KXFileDescriptor(id: "KX-FN-21", fileName: "KX-FN-21_指标模块数据接口.swift", layer: .function, relativePath: "业务功能层/KX-FN-21_指标模块数据接口.swift", version: .init(major: 2, minor: 0), duty: "向指标模块提供标准 OHLCV 数据"),
        KXFileDescriptor(id: "KX-FN-23", fileName: "KX-FN-23_UI图表数据接口.swift", layer: .function, relativePath: "业务功能层/KX-FN-23_UI图表数据接口.swift", version: .init(major: 2, minor: 0), duty: "向 UI 提供蜡烛、成交量、标记、叠加层、状态数据"),
        KXFileDescriptor(id: "KX-FN-24", fileName: "KX-FN-24_提示音事件接口.swift", layer: .function, relativePath: "业务功能层/KX-FN-24_提示音事件接口.swift", version: .init(major: 2, minor: 0), duty: "把形态、价格突破、成交量异常转换为提示音事件描述"),
        KXFileDescriptor(id: "KX-FN-25", fileName: "KX-FN-25_跨模块叠加显示接口.swift", layer: .function, relativePath: "业务功能层/KX-FN-25_跨模块叠加显示接口.swift", version: .init(major: 2, minor: 0), duty: "指标、形态、回撤、预测、交易等跨模块图表叠加显示接口"),
        KXFileDescriptor(id: "KX-FN-26", fileName: "KX-FN-26_跨模块提示事件接口.swift", layer: .function, relativePath: "业务功能层/KX-FN-26_跨模块提示事件接口.swift", version: .init(major: 2, minor: 0), duty: "跨模块提示事件接口定义"),
        KXFileDescriptor(id: "KX-FN-27", fileName: "KX-FN-27_跨模块K线数据查询接口.swift", layer: .function, relativePath: "业务功能层/KX-FN-27_跨模块K线数据查询接口.swift", version: .init(major: 2, minor: 0), duty: "跨模块K线数据查询接口定义"),
        KXFileDescriptor(id: "KX-FN-29", fileName: "KX-FN-29_统一指标注册表.swift", layer: .function, relativePath: "业务功能层/KX-FN-29_统一指标注册表.swift", version: .init(major: 2, minor: 0), duty: "统一登记指标服务层全部指标"),
        KXFileDescriptor(id: "KX-FN-32", fileName: "KX-FN-32_专业指标协议.swift", layer: .function, relativePath: "业务功能层/KX-FN-32_专业指标协议.swift", version: .init(major: 2, minor: 0), duty: "专业指标系统模板协议、计算上下文、输出结构"),
        KXFileDescriptor(id: "KX-FN-33", fileName: "KX-FN-33_指标设置Schema.swift", layer: .function, relativePath: "业务功能层/KX-FN-33_指标设置Schema.swift", version: .init(major: 2, minor: 0), duty: "指标设置面板的分区、字段、控件类型和提交规则"),
        KXFileDescriptor(id: "KX-FN-34", fileName: "KX-FN-34_指标Overlay适配器.swift", layer: .function, relativePath: "业务功能层/KX-FN-34_指标Overlay适配器.swift", version: .init(major: 2, minor: 0), duty: "把指标计算输出转换为标准 KLExternalChartOverlay 数组"),
        KXFileDescriptor(id: "KX-FN-35", fileName: "KX-FN-35_专业指标实例管理器.swift", layer: .function, relativePath: "业务功能层/KX-FN-35_专业指标实例管理器.swift", version: .init(major: 2, minor: 0), duty: "管理指标实例的 CRUD、计算、overlay 提交、通知刷新"),


        // MARK: 数据服务层
        KXFileDescriptor(id: "KX-SJ-01", fileName: "KX-SJ-01_数据库连接.swift", layer: .data, relativePath: "数据服务层/KX-SJ-01_数据库连接.swift", version: .init(major: 2, minor: 0), duty: "数据库连接管理、连接池"),
        KXFileDescriptor(id: "KX-SJ-02", fileName: "KX-SJ-02_交易对目录访问.swift", layer: .data, relativePath: "数据服务层/KX-SJ-02_交易对目录访问.swift", version: .init(major: 2, minor: 0), duty: "交易对目录数据库访问"),
        KXFileDescriptor(id: "KX-SJ-03", fileName: "KX-SJ-03_OHLCV表访问.swift", layer: .data, relativePath: "数据服务层/KX-SJ-03_OHLCV表访问.swift", version: .init(major: 2, minor: 0), duty: "OHLCV表数据库访问"),
        KXFileDescriptor(id: "KX-SJ-04", fileName: "KX-SJ-04_成交明细访问.swift", layer: .data, relativePath: "数据服务层/KX-SJ-04_成交明细访问.swift", version: .init(major: 2, minor: 0), duty: "成交明细数据库访问"),
        KXFileDescriptor(id: "KX-SJ-05", fileName: "KX-SJ-05_同步状态访问.swift", layer: .data, relativePath: "数据服务层/KX-SJ-05_同步状态访问.swift", version: .init(major: 2, minor: 0), duty: "同步状态数据库访问"),
        KXFileDescriptor(id: "KX-SJ-06", fileName: "KX-SJ-06_收藏表访问.swift", layer: .data, relativePath: "数据服务层/KX-SJ-06_收藏表访问.swift", version: .init(major: 2, minor: 0), duty: "收藏表数据库访问"),
        KXFileDescriptor(id: "KX-SJ-07", fileName: "KX-SJ-07_标记事件访问.swift", layer: .data, relativePath: "数据服务层/KX-SJ-07_标记事件访问.swift", version: .init(major: 2, minor: 0), duty: "标记事件数据库访问"),
        KXFileDescriptor(id: "KX-SJ-08", fileName: "KX-SJ-08_叠加层访问.swift", layer: .data, relativePath: "数据服务层/KX-SJ-08_叠加层访问.swift", version: .init(major: 2, minor: 0), duty: "叠加层数据库访问"),
        KXFileDescriptor(id: "KX-SJ-09", fileName: "KX-SJ-09_PostgreSQL适配.swift", layer: .data, relativePath: "数据服务层/KX-SJ-09_PostgreSQL适配.swift", version: .init(major: 2, minor: 0), duty: "PostgreSQL适配层"),
        KXFileDescriptor(id: "KX-SJ-10", fileName: "KX-SJ-10_内存缓存.swift", layer: .data, relativePath: "数据服务层/KX-SJ-10_内存缓存.swift", version: .init(major: 2, minor: 0), duty: "内存缓存管理"),
        KXFileDescriptor(id: "KX-SJ-11", fileName: "KX-SJ-11_周期缓存索引.swift", layer: .data, relativePath: "数据服务层/KX-SJ-11_周期缓存索引.swift", version: .init(major: 2, minor: 0), duty: "周期缓存索引管理"),
        KXFileDescriptor(id: "KX-SJ-12", fileName: "KX-SJ-12_可视窗口缓存.swift", layer: .data, relativePath: "数据服务层/KX-SJ-12_可视窗口缓存.swift", version: .init(major: 2, minor: 0), duty: "可视窗口缓存管理"),
        KXFileDescriptor(id: "KX-SJ-13", fileName: "KX-SJ-13_滑动窗口缓存.swift", layer: .data, relativePath: "数据服务层/KX-SJ-13_滑动窗口缓存.swift", version: .init(major: 2, minor: 0), duty: "滑动窗口缓存管理"),

        // MARK: 网络同步层
        KXFileDescriptor(id: "KX-SY-01", fileName: "KX-SY-01_交易对同步.swift", layer: .sync, relativePath: "网络同步层/KX-SY-01_交易对同步.swift", version: .init(major: 2, minor: 0), duty: "交易对同步任务"),
        KXFileDescriptor(id: "KX-SY-02", fileName: "KX-SY-02_历史K线同步.swift", layer: .sync, relativePath: "网络同步层/KX-SY-02_历史K线同步.swift", version: .init(major: 2, minor: 0), duty: "历史K线同步任务"),
        KXFileDescriptor(id: "KX-SY-04", fileName: "KX-SY-04_限流与重试.swift", layer: .sync, relativePath: "网络同步层/KX-SY-04_限流与重试.swift", version: .init(major: 2, minor: 0), duty: "限流与重试策略"),
        KXFileDescriptor(id: "KX-SY-05", fileName: "KX-SY-05_断线恢复.swift", layer: .sync, relativePath: "网络同步层/KX-SY-05_断线恢复.swift", version: .init(major: 2, minor: 0), duty: "断线恢复策略"),
        KXFileDescriptor(id: "KX-SY-06", fileName: "KX-SY-06_REST执行器.swift", layer: .sync, relativePath: "网络同步层/KX-SY-06_REST执行器.swift", version: .init(major: 2, minor: 0), duty: "REST API执行器"),
        KXFileDescriptor(id: "KX-SY-07", fileName: "KX-SY-07_WebSocket执行器.swift", layer: .sync, relativePath: "网络同步层/KX-SY-07_WebSocket执行器.swift", version: .init(major: 2, minor: 0), duty: "WebSocket执行器"),
        KXFileDescriptor(id: "KX-SY-08", fileName: "KX-SY-08_实时K线运行时.swift", layer: .sync, relativePath: "网络同步层/KX-SY-08_实时K线运行时.swift", version: .init(major: 2, minor: 0), duty: "实时K线运行时"),

        // MARK: 指标服务层
        KXFileDescriptor(id: "KX-IN-09-ROC", fileName: "KX-IN-09_ROC.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-09_ROC.swift", version: .init(major: 2, minor: 0), duty: "ROC指标"),
        KXFileDescriptor(id: "KX-IN-10-Momentum", fileName: "KX-IN-10_Momentum.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-10_Momentum.swift", version: .init(major: 2, minor: 0), duty: "Momentum指标"),
        KXFileDescriptor(id: "KX-IN-01-Vortex", fileName: "KX-IN-01_Vortex.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-01_Vortex.swift", version: .init(major: 2, minor: 0), duty: "Vortex指标"),
        KXFileDescriptor(id: "KX-IN-02-EMV", fileName: "KX-IN-02_EMV.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-02_EMV.swift", version: .init(major: 2, minor: 0), duty: "EMV指标"),
        KXFileDescriptor(id: "KX-IN-02-OBV", fileName: "KX-IN-02_OBV.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-02_OBV.swift", version: .init(major: 2, minor: 0), duty: "OBV指标"),
        KXFileDescriptor(id: "KX-IN-03-VWAP", fileName: "KX-IN-03_VWAP.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-03_VWAP.swift", version: .init(major: 2, minor: 0), duty: "VWAP指标"),
        KXFileDescriptor(id: "KX-IN-04-ForceIndex", fileName: "KX-IN-04_ForceIndex.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-04_ForceIndex.swift", version: .init(major: 2, minor: 0), duty: "Force Index指标"),
        KXFileDescriptor(id: "KX-IN-05-VPT", fileName: "KX-IN-05_VPT.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-05_VPT.swift", version: .init(major: 2, minor: 0), duty: "VPT指标"),
        KXFileDescriptor(id: "KX-IN-06-ChaikinMoneyFlow", fileName: "KX-IN-06_ChaikinMoneyFlow.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-06_ChaikinMoneyFlow.swift", version: .init(major: 2, minor: 0), duty: "CMF指标"),
        KXFileDescriptor(id: "KX-IN-06-成交量分析", fileName: "KX-IN-06_成交量分析.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-06_成交量分析.swift", version: .init(major: 2, minor: 0), duty: "成交量分析指标"),
        KXFileDescriptor(id: "KX-IN-07-POC", fileName: "KX-IN-07_POC.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-07_POC.swift", version: .init(major: 2, minor: 0), duty: "POC指标"),
        KXFileDescriptor(id: "KX-IN-10-ADLine", fileName: "KX-IN-10_ADLine.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-10_ADLine.swift", version: .init(major: 2, minor: 0), duty: "ADL指标"),
        KXFileDescriptor(id: "KX-IN-12-MFI", fileName: "KX-IN-12_MFI.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-12_MFI.swift", version: .init(major: 2, minor: 0), duty: "MFI指标"),
        KXFileDescriptor(id: "KX-IN-13-NVI", fileName: "KX-IN-13_NVI.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-13_NVI.swift", version: .init(major: 2, minor: 0), duty: "NVI指标"),
        KXFileDescriptor(id: "KX-IN-13-VolumeProfile", fileName: "KX-IN-13_VolumeProfile.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-13_VolumeProfile.swift", version: .init(major: 2, minor: 0), duty: "成交量分布指标"),
        KXFileDescriptor(id: "KX-IN-14-PVI", fileName: "KX-IN-14_PVI.swift", layer: .indicator, relativePath: "指标服务层/成交量指标/KX-IN-14_PVI.swift", version: .init(major: 2, minor: 0), duty: "PVI指标"),
        KXFileDescriptor(id: "KX-IN-14-BBW", fileName: "KX-IN-14_BBW.swift", layer: .indicator, relativePath: "指标服务层/波动率指标/KX-IN-14_BBW.swift", version: .init(major: 2, minor: 0), duty: "布林带宽指标"),
        KXFileDescriptor(id: "KX-IN-15-ATR", fileName: "KX-IN-15_ATR.swift", layer: .indicator, relativePath: "指标服务层/波动率指标/KX-IN-15_ATR.swift", version: .init(major: 2, minor: 0), duty: "ATR指标"),
        KXFileDescriptor(id: "KX-IN-15-StdDevChannel", fileName: "KX-IN-15_StdDevChannel.swift", layer: .indicator, relativePath: "指标服务层/波动率指标/KX-IN-15_StdDevChannel.swift", version: .init(major: 2, minor: 0), duty: "标准差通道指标"),
        KXFileDescriptor(id: "KX-IN-16-ChaikinVolatility", fileName: "KX-IN-16_ChaikinVolatility.swift", layer: .indicator, relativePath: "指标服务层/波动率指标/KX-IN-16_ChaikinVolatility.swift", version: .init(major: 2, minor: 0), duty: "蔡金波动率指标"),
        KXFileDescriptor(id: "KX-IN-27-多空比", fileName: "KX-IN-27_多空比.swift", layer: .indicator, relativePath: "指标服务层/统计指标/KX-IN-27_多空比.swift", version: .init(major: 2, minor: 0), duty: "多空比指标"),
        KXFileDescriptor(id: "KX-IN-01-MA", fileName: "KX-IN-01_MA.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-01_MA.swift", version: .init(major: 2, minor: 0), duty: "MA指标"),
        KXFileDescriptor(id: "KX-IN-02-EMA", fileName: "KX-IN-02_EMA.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-02_EMA.swift", version: .init(major: 2, minor: 0), duty: "EMA指标"),
        KXFileDescriptor(id: "KX-IN-03-ADX", fileName: "KX-IN-03_ADX.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-03_ADX.swift", version: .init(major: 2, minor: 0), duty: "ADX指标"),
        KXFileDescriptor(id: "KX-IN-05-ParabolicSAR", fileName: "KX-IN-05_ParabolicSAR.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-05_ParabolicSAR.swift", version: .init(major: 2, minor: 0), duty: "Parabolic SAR指标"),
        KXFileDescriptor(id: "KX-IN-06-CoppockCurve", fileName: "KX-IN-06_CoppockCurve.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-06_CoppockCurve.swift", version: .init(major: 2, minor: 0), duty: "Coppock Curve指标"),
        KXFileDescriptor(id: "KX-IN-07-TRIX", fileName: "KX-IN-07_TRIX.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-07_TRIX.swift", version: .init(major: 2, minor: 0), duty: "TRIX指标"),
        KXFileDescriptor(id: "KX-IN-08-Aroon", fileName: "KX-IN-08_Aroon.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-08_Aroon.swift", version: .init(major: 2, minor: 0), duty: "Aroon指标"),
        KXFileDescriptor(id: "KX-IN-21-SuperTrend", fileName: "KX-IN-21_SuperTrend.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-21_SuperTrend.swift", version: .init(major: 2, minor: 0), duty: "SuperTrend指标"),
        KXFileDescriptor(id: "KX-IN-01-布林带", fileName: "KX-IN-01_布林带.swift", layer: .indicator, relativePath: "指标服务层/波动率指标/KX-IN-01_布林带.swift", version: .init(major: 2, minor: 0), duty: "布林带指标"),
        KXFileDescriptor(id: "KX-IN-04-一目均衡图", fileName: "KX-IN-04_一目均衡图.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-04_一目均衡图.swift", version: .init(major: 2, minor: 0), duty: "Ichimoku指标"),
        KXFileDescriptor(id: "KX-IN-12-KAMA", fileName: "KX-IN-12_KAMA.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-12_KAMA.swift", version: .init(major: 2, minor: 0), duty: "KAMA指标"),
        KXFileDescriptor(id: "KX-IN-16-PivotPoints", fileName: "KX-IN-16_PivotPoints.swift", layer: .indicator, relativePath: "指标服务层/统计指标/KX-IN-16_PivotPoints.swift", version: .init(major: 2, minor: 0), duty: "枢纽点指标"),
        KXFileDescriptor(id: "KX-IN-17-KeltnerChannel", fileName: "KX-IN-17_KeltnerChannel.swift", layer: .indicator, relativePath: "指标服务层/波动率指标/KX-IN-17_KeltnerChannel.swift", version: .init(major: 2, minor: 0), duty: "肯特纳通道指标"),
        KXFileDescriptor(id: "KX-IN-18-DonchianChannel", fileName: "KX-IN-18_DonchianChannel.swift", layer: .indicator, relativePath: "指标服务层/波动率指标/KX-IN-18_DonchianChannel.swift", version: .init(major: 2, minor: 0), duty: "Donchian Channel指标"),
        KXFileDescriptor(id: "KX-IN-20-Fibonacci", fileName: "KX-IN-20_Fibonacci.swift", layer: .indicator, relativePath: "指标服务层/统计指标/KX-IN-20_Fibonacci.swift", version: .init(major: 2, minor: 0), duty: "斐波那契指标"),
        KXFileDescriptor(id: "KX-IN-20-HMA", fileName: "KX-IN-20_HMA.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-20_HMA.swift", version: .init(major: 2, minor: 0), duty: "HMA指标"),
        KXFileDescriptor(id: "KX-IN-25-rainbow", fileName: "KX-IN-25_rainbow.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-25_rainbow.swift", version: .init(major: 2, minor: 0), duty: "彩虹均线指标"),
        KXFileDescriptor(id: "KX-IN-29-支撑阻力", fileName: "KX-IN-29_支撑阻力.swift", layer: .indicator, relativePath: "指标服务层/趋势指标/KX-IN-29_支撑阻力.swift", version: .init(major: 2, minor: 0), duty: "支撑阻力指标"),
        KXFileDescriptor(id: "KX-IN-17-活跃地址数", fileName: "KX-IN-17_活跃地址数.swift", layer: .indicator, relativePath: "指标服务层/链上指标/KX-IN-17_活跃地址数.swift", version: .init(major: 2, minor: 0), duty: "活跃地址数指标"),
        KXFileDescriptor(id: "KX-IN-22-MVRV", fileName: "KX-IN-22_MVRV.swift", layer: .indicator, relativePath: "指标服务层/链上指标/KX-IN-22_MVRV.swift", version: .init(major: 2, minor: 0), duty: "MVRV指标"),
        KXFileDescriptor(id: "KX-IN-24-NUPL", fileName: "KX-IN-24_NUPL.swift", layer: .indicator, relativePath: "指标服务层/链上指标/KX-IN-24_NUPL.swift", version: .init(major: 2, minor: 0), duty: "NUPL指标"),
        KXFileDescriptor(id: "KX-IN-25-Ahr999", fileName: "KX-IN-25_Ahr999.swift", layer: .indicator, relativePath: "指标服务层/链上指标/KX-IN-25_Ahr999.swift", version: .init(major: 2, minor: 0), duty: "AHR999指标"),
        KXFileDescriptor(id: "KX-IN-26-彩虹图", fileName: "KX-IN-26_彩虹图.swift", layer: .indicator, relativePath: "指标服务层/链上指标/KX-IN-26_彩虹图.swift", version: .init(major: 2, minor: 0), duty: "彩虹图指标"),
        KXFileDescriptor(id: "KX-IN-28-资金费率", fileName: "KX-IN-28_资金费率.swift", layer: .indicator, relativePath: "指标服务层/链上指标/KX-IN-28_资金费率.swift", version: .init(major: 2, minor: 0), duty: "资金费率指标"),
        KXFileDescriptor(id: "KX-IN-01-RSI", fileName: "KX-IN-01_RSI.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-01_RSI.swift", version: .init(major: 2, minor: 0), duty: "RSI指标"),
        KXFileDescriptor(id: "KX-IN-02-MACD", fileName: "KX-IN-02_MACD.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-02_MACD.swift", version: .init(major: 2, minor: 0), duty: "MACD指标"),
        KXFileDescriptor(id: "KX-IN-03-KDJ", fileName: "KX-IN-03_KDJ.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-03_KDJ.swift", version: .init(major: 2, minor: 0), duty: "KDJ指标"),
        KXFileDescriptor(id: "KX-IN-04-CCI", fileName: "KX-IN-04_CCI.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-04_CCI.swift", version: .init(major: 2, minor: 0), duty: "CCI指标"),
        KXFileDescriptor(id: "KX-IN-05-WilliamsR", fileName: "KX-IN-05_WilliamsR.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-05_WilliamsR.swift", version: .init(major: 2, minor: 0), duty: "Williams %R指标"),
        KXFileDescriptor(id: "KX-IN-06-StochasticRSI", fileName: "KX-IN-06_StochasticRSI.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-06_StochasticRSI.swift", version: .init(major: 2, minor: 0), duty: "Stochastic RSI指标"),
        KXFileDescriptor(id: "KX-IN-07-UltimateOscillator", fileName: "KX-IN-07_UltimateOscillator.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-07_UltimateOscillator.swift", version: .init(major: 2, minor: 0), duty: "Ultimate Oscillator指标"),
        KXFileDescriptor(id: "KX-IN-08-PO", fileName: "KX-IN-08_PO.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-08_PO.swift", version: .init(major: 2, minor: 0), duty: "PO指标"),
        KXFileDescriptor(id: "KX-IN-09-DPO", fileName: "KX-IN-09_DPO.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-09_DPO.swift", version: .init(major: 2, minor: 0), duty: "DPO指标"),
        KXFileDescriptor(id: "KX-IN-11-RVI", fileName: "KX-IN-11_RVI.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-11_RVI.swift", version: .init(major: 2, minor: 0), duty: "RVI指标"),
        KXFileDescriptor(id: "KX-IN-18-CMO", fileName: "KX-IN-18_CMO.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-18_CMO.swift", version: .init(major: 2, minor: 0), duty: "CMO指标"),
        KXFileDescriptor(id: "KX-IN-19-牛熊力量", fileName: "KX-IN-19_牛熊力量.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-19_牛熊力量.swift", version: .init(major: 2, minor: 0), duty: "牛熊力量指标"),
        KXFileDescriptor(id: "KX-IN-23-KD", fileName: "KX-IN-23_KD.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-23_KD.swift", version: .init(major: 2, minor: 0), duty: "KD指标"),
        KXFileDescriptor(id: "KX-IN-30-ChandeForecast", fileName: "KX-IN-30_ChandeForecast.swift", layer: .indicator, relativePath: "指标服务层/震荡指标/KX-IN-30_ChandeForecast.swift", version: .init(major: 2, minor: 0), duty: "钱德预测指标"),

        // MARK: UI组件层
        KXFileDescriptor(id: "KX-UI-01", fileName: "KX-UI-01_应用状态适配.swift", layer: .ui, relativePath: "UI组件层/KX-UI-01_应用状态适配.swift", version: .init(major: 2, minor: 0), duty: "应用状态适配、主题切换、窗口状态管理"),
        KXFileDescriptor(id: "KX-UI-02", fileName: "KX-UI-02_虚拟滚动适配.swift", layer: .ui, relativePath: "UI组件层/KX-UI-02_虚拟滚动适配.swift", version: .init(major: 2, minor: 0), duty: "虚拟滚动适配"),
        KXFileDescriptor(id: "KX-UI-03", fileName: "KX-UI-03_十字光标适配.swift", layer: .ui, relativePath: "UI组件层/KX-UI-03_十字光标适配.swift", version: .init(major: 2, minor: 0), duty: "十字光标适配"),
        KXFileDescriptor(id: "KX-UI-04", fileName: "KX-UI-04_画线工具适配.swift", layer: .ui, relativePath: "UI组件层/KX-UI-04_画线工具适配.swift", version: .init(major: 2, minor: 0), duty: "画线工具适配"),
        KXFileDescriptor(id: "KX-UI-05", fileName: "KX-UI-05_收藏列表适配.swift", layer: .ui, relativePath: "UI组件层/KX-UI-05_收藏列表适配.swift", version: .init(major: 2, minor: 0), duty: "收藏列表适配"),
        KXFileDescriptor(id: "KX-UI-06", fileName: "KX-UI-06_工作区数据适配.swift", layer: .ui, relativePath: "UI组件层/KX-UI-06_工作区数据适配.swift", version: .init(major: 2, minor: 0), duty: "工作区数据适配"),
        KXFileDescriptor(id: "KX-UI-07", fileName: "KX-UI-07_布局模板适配.swift", layer: .ui, relativePath: "UI组件层/KX-UI-07_布局模板适配.swift", version: .init(major: 2, minor: 0), duty: "布局模板适配"),
        KXFileDescriptor(id: "KX-UI-08", fileName: "KX-UI-08_面板入口.swift", layer: .ui, relativePath: "UI组件层/KX-UI-08_面板入口.swift", version: .init(major: 2, minor: 0), duty: "K线模块面板View入口、状态持久化"),
        KXFileDescriptor(id: "KX-UI-09", fileName: "KX-UI-09_OKX风格面板.swift", layer: .ui, relativePath: "UI组件层/KX-UI-09_OKX风格面板.swift", version: .init(major: 2, minor: 0), duty: "OKX风格K线主面板视图、组合工具栏+图表容器"),
        KXFileDescriptor(id: "KX-UI-10", fileName: "KX-UI-10_币对标签栏.swift", layer: .ui, relativePath: "UI组件层/KX-UI-10_币对标签栏.swift", version: .init(major: 2, minor: 0), duty: "币对标签栏"),
        KXFileDescriptor(id: "KX-UI-11", fileName: "KX-UI-11_时间框架选择.swift", layer: .ui, relativePath: "UI组件层/KX-UI-11_时间框架选择.swift", version: .init(major: 2, minor: 0), duty: "K线时间框架选择器与周期切换 UI"),
        KXFileDescriptor(id: "KX-UI-12", fileName: "KX-UI-12_图表视图.swift", layer: .ui, relativePath: "UI组件层/KX-UI-12_图表视图.swift", version: .init(major: 2, minor: 0), duty: "K线图表完整视图容器"),
        KXFileDescriptor(id: "KX-UI-13", fileName: "KX-UI-13_图表覆盖层.swift", layer: .ui, relativePath: "UI组件层/KX-UI-13_图表覆盖层.swift", version: .init(major: 2, minor: 0), duty: "图表覆盖层"),
        KXFileDescriptor(id: "KX-UI-14", fileName: "KX-UI-14_成交量视图.swift", layer: .ui, relativePath: "UI组件层/KX-UI-14_成交量视图.swift", version: .init(major: 2, minor: 0), duty: "成交量视图组件"),
        KXFileDescriptor(id: "KX-UI-15", fileName: "KX-UI-15_可拖拽分割线.swift", layer: .ui, relativePath: "UI组件层/KX-UI-15_可拖拽分割线.swift", version: .init(major: 2, minor: 0), duty: "可拖拽分割线组件"),
        KXFileDescriptor(id: "KX-UI-16", fileName: "KX-UI-16_交易对选择器.swift", layer: .ui, relativePath: "UI组件层/KX-UI-16_交易对选择器.swift", version: .init(major: 2, minor: 0), duty: "交易对选择器控件"),
        KXFileDescriptor(id: "KX-UI-17", fileName: "KX-UI-17_指标选择器.swift", layer: .ui, relativePath: "UI组件层/KX-UI-17_指标选择器.swift", version: .init(major: 2, minor: 0), duty: "技术指标选择器"),
        KXFileDescriptor(id: "KX-UI-18", fileName: "KX-UI-18_工具栏.swift", layer: .ui, relativePath: "UI组件层/KX-UI-18_工具栏.swift", version: .init(major: 2, minor: 0), duty: "工具栏组件"),
        KXFileDescriptor(id: "KX-UI-19", fileName: "KX-UI-19_图表Overlay渲染器.swift", layer: .ui, relativePath: "UI组件层/KX-UI-19_图表Overlay渲染器.swift", version: .init(major: 2, minor: 0), duty: "消费 KLExternalChartOverlay 并渲染各类指标图形"),
        KXFileDescriptor(id: "KX-UI-20", fileName: "KX-UI-20_指标浮动标签层.swift", layer: .ui, relativePath: "UI组件层/KX-UI-20_指标浮动标签层.swift", version: .init(major: 2, minor: 0), duty: "指标实例在对应 pane 顶部的小 chip 浮动标签"),
        KXFileDescriptor(id: "KX-UI-21", fileName: "KX-UI-21_指标设置面板.swift", layer: .ui, relativePath: "UI组件层/KX-UI-21_指标设置面板.swift", version: .init(major: 2, minor: 0), duty: "根据指标 settings schema 生成设置面板"),

        // MARK: 标记层
        KXFileDescriptor(id: "KX-MK-00", fileName: "KX-MK-00_标记层入口.swift", layer: .ui, relativePath: "标记层/KX-MK-00_标记层入口.swift", version: .init(major: 1, minor: 0), duty: "标记层统一入口，只做跨模块标记 overlay 分发，不计算、不绘图业务外泄"),
        KXFileDescriptor(id: "KX-MK-01", fileName: "KX-MK-01_K线形态标记渲染.swift", layer: .ui, relativePath: "标记层/KX-MK-01_K线形态标记渲染.swift", version: .init(major: 1, minor: 0), duty: "独立渲染K线形态标记标签、连接线与避让布局"),
        KXFileDescriptor(id: "KX-MK-02", fileName: "KX-MK-02_指标标签标记渲染.swift", layer: .ui, relativePath: "标记层/KX-MK-02_指标标签标记渲染.swift", version: .init(major: 1, minor: 0), duty: "独立渲染指标/模块输出文字标签"),

        // MARK: 工具服务层
        KXFileDescriptor(id: "KX-UT-01", fileName: "KX-UT-01_日志工具.swift", layer: .utility, relativePath: "工具服务层/KX-UT-01_日志工具.swift", version: .init(major: 2, minor: 0), duty: "日志工具"),
        KXFileDescriptor(id: "KX-UT-02", fileName: "KX-UT-02_收藏服务.swift", layer: .utility, relativePath: "工具服务层/KX-UT-02_收藏服务.swift", version: .init(major: 2, minor: 0), duty: "币对收藏、取消收藏、筛选、排序服务"),
        KXFileDescriptor(id: "KX-UT-03", fileName: "KX-UT-03_周期组合收藏.swift", layer: .utility, relativePath: "工具服务层/KX-UT-03_周期组合收藏.swift", version: .init(major: 2, minor: 0), duty: "周期组合收藏服务"),
        KXFileDescriptor(id: "KX-UT-04", fileName: "KX-UT-04_指标组合收藏.swift", layer: .utility, relativePath: "工具服务层/KX-UT-04_指标组合收藏.swift", version: .init(major: 2, minor: 0), duty: "指标组合收藏服务"),
        KXFileDescriptor(id: "KX-UT-05", fileName: "KX-UT-05_标记模型.swift", layer: .utility, relativePath: "工具服务层/KX-UT-05_标记模型.swift", version: .init(major: 2, minor: 0), duty: "标记类型、来源、位置、置信度、文本等模型"),
        KXFileDescriptor(id: "KX-UT-07", fileName: "KX-UT-07_手动标记管理.swift", layer: .utility, relativePath: "工具服务层/KX-UT-07_手动标记管理.swift", version: .init(major: 2, minor: 0), duty: "用户手动标记的新增、删除、更新服务"),
        KXFileDescriptor(id: "KX-UT-08", fileName: "KX-UT-08_标记叠加输出.swift", layer: .utility, relativePath: "工具服务层/KX-UT-08_标记叠加输出.swift", version: .init(major: 2, minor: 0), duty: "向图表输出可叠加标记数据"),
        KXFileDescriptor(id: "KX-UT-09", fileName: "KX-UT-09_提示音模型.swift", layer: .utility, relativePath: "工具服务层/KX-UT-09_提示音模型.swift", version: .init(major: 2, minor: 0), duty: "提示音事件类型、来源、触发条件、开关模型"),
        KXFileDescriptor(id: "KX-UT-11", fileName: "KX-UT-11_价格突破提示音.swift", layer: .utility, relativePath: "工具服务层/KX-UT-11_价格突破提示音.swift", version: .init(major: 2, minor: 0), duty: "价格突破事件的提示音生成"),
        KXFileDescriptor(id: "KX-UT-12", fileName: "KX-UT-12_成交量提示音.swift", layer: .utility, relativePath: "工具服务层/KX-UT-12_成交量提示音.swift", version: .init(major: 2, minor: 0), duty: "成交量异常事件的提示音生成"),
    ]

    // MARK: - 完整性检查

    public static func integrityReport(basePath: String) -> KXHealthReport {
        klineLogger.info("开始注册表完整性检查，共\(allFiles.count)个注册项")
        var items: [KXHealthCheckItem] = []

        // 1. 检查重复ID
        let ids = allFiles.map { $0.id }
        let duplicatedIDs = Set(ids.filter { id in ids.filter { $0 == id }.count > 1 })
        items.append(KXHealthCheckItem(
            name: "重复ID检查",
            passed: duplicatedIDs.isEmpty,
            message: duplicatedIDs.isEmpty ? "无重复ID" : "重复ID：\(duplicatedIDs.joined(separator: ","))"
        ))

        // 2. 检查文件存在性
        var missingFiles: [String] = []
        for descriptor in allFiles {
            let fullPath = (basePath as NSString).appendingPathComponent(descriptor.relativePath)
            let exists = FileManager.default.fileExists(atPath: fullPath)
            if !exists {
                missingFiles.append(descriptor.fileName)
            }
        }
        items.append(KXHealthCheckItem(
            name: "文件存在性检查",
            passed: missingFiles.isEmpty,
            message: missingFiles.isEmpty
                ? "\(allFiles.count)个文件全部存在"
                : "缺失\(missingFiles.count)个：\(missingFiles.joined(separator: ","))"
        ))

        // 3. 版本号统一检查
        let versionMismatches = allFiles.filter { $0.version != version }
        items.append(KXHealthCheckItem(
            name: "版本号统一检查",
            passed: versionMismatches.isEmpty,
            message: versionMismatches.isEmpty
                ? "全部注册项版本为\(version)"
                : "版本不一致：\(versionMismatches.map { "\($0.id)=\($0.version)" }.joined(separator: ","))"
        ))

        // 4. 按层统计
        let layerCounts = Dictionary(grouping: allFiles, by: { $0.layer.rawValue }).mapValues { $0.count }
        let layerMsg = layerCounts.sorted(by: { $0.key < $1.key }).map { "\($0.key):\($0.value)个" }.joined(separator: " ")
        items.append(KXHealthCheckItem(
            name: "按层统计",
            passed: true,
            message: "共\(allFiles.count)个文件，\(layerMsg)"
        ))

        return KXHealthReport(moduleName: "K线模块", version: version, items: items)
    }
}
