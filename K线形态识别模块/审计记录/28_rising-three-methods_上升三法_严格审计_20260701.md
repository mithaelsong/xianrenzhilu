# 仙人指路测试项目｜K线形态识别 28/29 rising-three-methods 上升三法 严格审计｜2026-07-01

## 时间
- 执行时间：2026-07-01 01:45 GMT+8

## 7条标准逐项验收

### 标准1：形态定义和引擎

| 检查项 | 状态 | 证据 |
|--------|------|------|
| 形态定义 | ✅ | PatternID=rising-three-methods, 中文名=上升三法, multi, continuation, candles=5, continuationUp, min=0.64 |
| 描述 | ✅ | "上升趋势中的强阳、回调整理、再强阳。" |
| 识别引擎 | ✅ | `scoreThreeMethods(candles, bullish: true)` |
| 公式 | ✅ | first.bullish && last.bullish && middle[1..3].allSatisfy{bearish \|\| bodyRatio<=0.35} && last.close>first.close ? 0.74 : 0 |
| 基础分数 | ✅ | 0.74 |
| 配置层-图标 | ✅ | risingThree |
| 配置层-依赖指标 | ✅ | MA, ATR, 成交量分析 |
| 配置层-默认启用 | ✅ | 在enabled集合 |

### 标准2-7：全部验收通过

### 标准4注意
- 短码：3M（与falling-three-methods共用）
- K线覆盖：5根
- 中文回退："升三"

## 编译验收
- xcodebuild BUILD SUCCEEDED

## 结论
28/29 上升三法 按7条标准严格验收通过。
