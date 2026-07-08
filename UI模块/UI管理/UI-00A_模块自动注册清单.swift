// MARK: - UI-00A: UI模块自动注册清单
// 功能编号: UI-00A
// 版本: 2.0
// 职责: 维护UI模块注册清单，并将模块元数据写入UIUnifiedRegistry
// 依赖: UI-01 (UIUnifiedRegistry), UI-02 (公共类型)

import Foundation
import os

private let uiAutoRegisterLogger = Logger(subsystem: "com.xianrenzhilu.ui", category: "AutoRegisterList")

// MARK: - UI管理模块注册清单
public let uiManagementModuleRegistrations: [(id: String, name: String, version: String, dependencies: [String])] = [
    ("UI-00", "UI模块入口", "2.0", []),
    ("UI-00A", "模块自动注册清单", "2.0", ["UI-01", "UI-02"]),
    ("UI-01", "统一注册表", "2.0", ["UI-02"]),
    ("UI-02", "公共类型定义", "2.0", []),
    ("UI-03", "扫描UI模块目录", "2.0", ["UI-02"]),
    ("UI-04", "按顺序加载UI模块", "2.0", ["UI-02", "UI-03"]),
    ("UI-05", "调用UI模块的start", "2.0", ["UI-02", "UI-04"]),
    ("UI-06", "处理UI模块加载失败", "2.0", ["UI-02"]),
    ("UI-07", "动态卸载UI模块", "2.0", ["UI-02", "UI-01"]),
    ("UI-08", "动态加载UI模块", "2.0", ["UI-02", "UI-03", "UI-05", "UI-06"]),
    ("UI-09", "获取UI模块实例", "2.0", ["UI-02", "UI-01"]),
    ("UI-10", "UI模块热替换", "2.0", ["UI-02", "UI-07", "UI-08", "UI-09", "UI-11"]),
    ("UI-11", "UI模块版本检查", "2.0", ["UI-02"]),
    ("UI-12", "UI模块热重载", "2.0", ["UI-02", "UI-10"]),
    ("UI-13", "UI模块加载日志", "2.0", ["UI-02"]),
    ("UI-14", "UI模块列表UI", "2.0", ["UI-02", "UI-07", "UI-09", "UI-13"]),
    ("UI-15", "窗口生命周期管理", "2.0", ["UI-02"]),
    ("UI-16", "窗口层级管理", "2.0", ["UI-02"]),
    ("UI-17", "全局事件总线", "2.0", ["UI-02"]),
    ("UI-18", "应用状态管理", "2.0", ["UI-02"]),
    ("UI-19", "布局模板系统", "2.0", ["UI-02", "UI-18"]),
    ("UI-20", "主题切换", "2.0", ["UI-02", "UI-18"]),
    ("UI-21", "工作区管理", "2.0", ["UI-02", "UI-18", "UI-19"]),
]

// MARK: - UI功能模块注册清单
public let uiFunctionModuleRegistrations: [(id: String, name: String, version: String, dependencies: [String])] = [
    ("UI-GL-01", "窗口位置与状态持久化", "2.0", []),
    ("UI-GL-02", "多屏幕支持", "2.0", []),
    ("UI-GL-03", "窗口动画效果", "2.0", []),
    ("UI-GL-04", "窗口克隆", "2.0", []),
    ("UI-GL-05", "窗口玻璃效果", "2.0", []),
    ("UI-GL-06", "视图容器协议", "2.0", []),
    ("UI-GL-07", "窗口阴影自定义", "2.0", []),
    ("UI-GL-08", "面板类型系统", "2.0", []),
    ("UI-GL-09", "窗口背景与边框", "2.0", []),
    ("UI-GL-10", "面板停靠吸附", "2.0", []),
    ("UI-GL-11", "窗口工具栏", "2.0", []),
    ("UI-GL-12", "面板自动隐藏", "2.0", []),
    ("UI-GL-13", "透明度控制", "2.0", []),
    ("UI-GL-14", "主题皮肤系统", "2.0", []),
    ("UI-GL-15", "窗口最小化行为自定义", "2.0", []),
    ("UI-GL-16", "工具栏管理器", "2.0", []),
    ("UI-GL-17", "窗口大小与位置限制", "2.0", []),
    ("UI-GL-18", "工具栏可定制", "2.0", []),
    ("UI-GL-19", "窗口拖拽行为管理", "2.0", []),
    ("UI-GL-20", "主菜单管理器", "2.0", []),
    ("UI-GL-21", "窗口全屏管理", "2.0", []),
    ("UI-GL-22", "快捷键系统", "2.0", []),
    ("UI-GL-23", "窗口布局管理", "2.0", []),
    ("UI-GL-24", "窗口标签化（Tab管理）", "2.0", []),
    ("UI-GL-25", "模块间通信协议", "2.0", []),
    ("UI-GL-26", "窗口悬浮与置顶", "2.0", []),
    ("UI-GL-27", "窗口分组管理", "2.0", []),
    ("UI-GL-28", "状态持久化", "2.0", []),
    ("UI-GL-29", "撤销重做系统", "2.0", []),
    ("UI-GL-30", "视图渲染优化", "2.0", []),
    ("UI-GL-31", "异步加载器", "2.0", []),
    ("UI-GL-32", "内存警告处理", "2.0", []),
    ("UI-GL-33", "模块热加载", "2.0", []),
    ("UI-GL-34", "模块沙盒隔离", "2.0", []),
    ("UI-GL-35", "日志记录", "2.0", []),
    ("UI-GL-36", "开发者工具面板", "2.0", []),
    ("UI-GL-37", "脚本引擎", "2.0", []),
    ("UI-GL-38", "模块独立性", "2.0", []),
    ("UI-GL-39", "插件管理器", "2.0", []),
    ("UI-GL-40", "嵌套分割视图", "2.0", []),
    ("UI-GL-41", "布局管理器", "2.0", []),
    ("UI-GL-42", "布局序列化与恢复", "2.0", []),
    ("UI-GL-43", "字体管理器", "2.0", []),
    ("UI-GL-44", "视图组", "2.0", []),
    ("UI-GL-45", "布局模板市场", "2.0", []),
    ("UI-GL-46", "多行标签页", "2.0", []),
    ("UI-GL-47", "标签页脱离合并", "2.0", []),
    ("UI-GL-48", "标签页预览", "2.0", []),
    ("UI-GL-49", "标签页分组", "2.0", []),
    ("UI-GL-50", "固定标签页", "2.0", []),
    ("UI-GL-51", "时间轴缩放控件", "2.0", []),
    ("UI-GL-52", "十字光标跨窗口联动", "2.0", []),
    ("UI-GL-53", "画线工具库与模板", "2.0", []),
    ("UI-GL-54", "图表叠加模式", "2.0", []),
    ("UI-GL-55", "历史数据回放模式", "2.0", []),
    ("UI-GL-56", "停靠系统", "2.0", []),
    ("UI-GL-57", "固定机制", "2.0", []),
    ("UI-GL-58", "面板分组", "2.0", []),
    ("UI-GL-59", "自动隐藏区域", "2.0", []),
    ("UI-GL-60", "浮动窗口平铺管理", "2.0", []),
    ("UI-GL-61", "离屏渲染与缓存", "2.0", []),
    ("UI-GL-62", "帧率自适应", "2.0", []),
    ("UI-GL-63", "增量渲染", "2.0", []),
    ("UI-GL-64", "图表数据虚拟滚动", "2.0", []),
    ("UI-GL-65", "完整键盘导航", "2.0", []),
    ("UI-GL-66", "VoiceOver支持", "2.0", []),
    ("UI-GL-67", "高对比度模式", "2.0", []),
    ("UI-GL-68", "动态字体与缩放", "2.0", []),
    ("UI-GL-69", "颜色盲模式", "2.0", []),
    ("UI-GL-70", "命令面板", "2.0", []),
]

// MARK: - UI皮肤模块注册清单
public let uiSkinModuleRegistrations: [(id: String, name: String, version: String, dependencies: [String])] = [
    ("UI-PF-00", "皮肤注册桥接", "2.0", ["UI-01", "UI-02"]),
    ("UI-PF-01", "皮肤系统入口", "2.0", ["UI-PF-00"]),
    ("UI-PF-02", "皮肤引擎", "2.0", ["UI-PF-00"]),
    ("UI-PF-04", "深色主题", "2.0", []),
    ("UI-PF-05", "高对比度主题", "2.0", []),
    ("UI-PF-06", "红色盲主题", "2.0", []),
    ("UI-PF-07", "绿色盲主题", "2.0", []),
    ("UI-PF-08", "浅色主题", "2.0", []),
    ("UI-PF-09", "玻璃皮肤", "2.0", []),
]

// MARK: - 全部UI模块注册清单
public var uiAllModuleRegistrations: [(id: String, name: String, version: String, dependencies: [String])] {
    uiManagementModuleRegistrations + uiFunctionModuleRegistrations + uiSkinModuleRegistrations
}

// MARK: - 自动注册入口
public func registerAllUIModules() {
    uiAutoRegisterLogger.info("开始自动注册 UI 模块清单")
    let registry = UIUnifiedRegistry.shared
    for item in uiAllModuleRegistrations {
        let metadata = UIModuleMetadata(
            moduleID: item.id,
            moduleName: item.name,
            version: item.version,
            minFrameworkVersion: "2.0",
            dependencies: item.dependencies,
            author: "系统自动注册",
            description: "\(item.name)模块",
            isBuiltIn: true
        )
        let registration = UIModuleRegistration(
            name: item.id,
            aliases: [item.name],
            metadata: metadata,
            isEnabled: true
        )
        registry.registerModule(registration: registration)
    }
}
