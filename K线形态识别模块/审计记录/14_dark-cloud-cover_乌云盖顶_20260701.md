# 仙人指路测试项目｜K线形态识别 14/29 dark-cloud-cover 乌云盖顶链路测试与严格审计

## 时间
- 执行时间：2026-07-01 00:38-00:41 GMT+8
- 当前形态：14/29 dark-cloud-cover / 乌云盖顶
- 项目路径：/Users/songxiaoxiao/Desktop/仙人指路测试项目

## 当前阶段边界
按用户保存到数据库的 7 条要求执行：
- 当前只做该 K线形态识别指标链路打通。
- 不做参数准确率优化。
- 不做回测收益验证。
- 不做交易级过滤优化。
- 做完一个必须测试一个，测试通过前不进入下一个。

## 操作范围
本轮实际修改：
1. `K线模块/标记层/KX-MK-03_形态标记详情弹窗.swift`
   - 补乌云盖顶专属解释、判断依据、风险提示。
   - 同时修复 `riskText` 里刺透形态重复 `if` 的 bug（两个完全相同的条件，第二个永远不会执行，已删除）。

本轮未修改：
- 识别引擎公式（`scoreDarkCloud` 已存在）；
- 指标参数；
- 设置面板图标逻辑（源码已有 `darkCloud` 图标）；
- 标签短码（已有 `DC`）；
- K线移动/缩放链路；
- 下一个形态。

## 源码定义审计
文件：`K线形态识别模块/形态定义层/KP-DF-01_形态类型定义.swift`

确认定义：
- PatternID：`dark-cloud-cover`
- 中文名：乌云盖顶
- 类型：`.dual`
- 方向：`.bearish`
- K线数量：`candles: 2`
- 描述：高开阴线跌入前阳线实体一半以下。
- 趋势语义：`trend: .afterUptrend`
- 最低阈值：`min: 0.62`

## 识别逻辑审计
文件：`K线形态识别模块/识别引擎层/KP-EN-01_形态识别引擎.swift`

确认识别调用：
```swift
case "dark-cloud-cover": score = scoreDarkCloud(candles[0], candles[1])
```

确认公式：
```swift
private func scoreDarkCloud(_ a: Candle, _ b: Candle) -> Double {
    let am = m(a), bm = m(b)
    return am.bullish && bm.bearish && d(b.open) > d(a.close) && d(b.close) < midpoint(a) && d(b.close) > d(a.open) ? 0.7 : 0
}
```

## 配置层审计
文件：`K线形态识别模块/配置层/KP-CF-01_形态识别设置配置.swift`

- illustrations 包含 `dark-cloud-cover` -> `darkCloud`
- 双K形态注册列表包含 `dark-cloud-cover`

## 标签渲染审计
文件：`K线模块/标记层/KX-MK-01_K线形态标记渲染.swift`

- 渲染方式：`pinBadge`
- 短码：`DC`
- 方向：看跌（红色）

## 弹窗解释审计
文件：`K线模块/标记层/KX-MK-03_形态标记详情弹窗.swift`

已补：
- `explanationText`：乌云盖顶表示上涨后一根阴线高开低走，收盘价深入前一根阳线实体一半以下，属于潜在看跌反转信号。
- `evidenceText`：触发K线数；形态结构：阴线高开低走、收盘价深入前阳线实体一半以下；置信度；方向。
- `riskText`：乌云盖顶偏看跌，但不能单独作为卖出依据；需要结合上涨位置、阻力位、成交量和后续K线确认，若阴线收盘未过半可能只是弱势回调。

## 额外修复
- `riskText` 中刺透形态有两个完全相同的 `if` 条件（line 207 和 line 210），第二个永远不会执行。已删除重复块。

## 编译验收
- `swiftc -parse KX-MK-03_形态标记详情弹窗.swift`：0 error
- `xcodebuild -project 仙人指路.xcodeproj -scheme 仙人指路 -configuration Debug build`：BUILD SUCCEEDED

## 测试结论
- 静态链路验收：通过
- 形态定义：✅
- 识别引擎：✅
- 配置层：✅
- 标签渲染：✅
- 弹窗解释：✅（本轮补充）
- 编译：✅

## 下一步
15/29 看涨孕线（bullish-harami）
