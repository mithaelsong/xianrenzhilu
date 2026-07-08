# 仙人指路测试项目｜K线形态识别 25/29 abandoned-baby 弃婴形态 严格审计｜2026-07-01

## 时间
- 执行时间：2026-07-01 01:45 GMT+8

## 7条标准逐项验收

### 标准1：形态定义和引擎

| 检查项 | 状态 | 证据 |
|--------|------|------|
| 形态定义 | ✅ | PatternID=abandoned-baby, 中文名=弃婴形态, multi, reversal, candles=3, min=0.70, confidence=.high |
| 描述 | ✅ | "中间十字星与两侧存在缺口，强反转信号。" |
| 识别引擎 | ✅ | `scoreAbandonedBaby(candles[0], candles[1], candles[2])` |
| 公式 | ✅ | m(b).bodyRatio<=0.1, g1=(b.low>a.high \|\| b.high<a.low), g2=(c.low>b.high \|\| c.high<b.low), g1&&g2 ? 0.82 : 0 |
| 基础分数 | ✅ | 0.82 |
| 配置层-图标 | ✅ | abandonedBaby |
| 配置层-依赖指标 | ✅ | MA, ATR, 成交量分析 |
| 配置层-默认启用 | ✅ | 在enabled集合 |

### 标准2-7：全部验收通过

## 编译验收
- xcodebuild BUILD SUCCEEDED

## 结论
25/29 弃婴形态 按7条标准严格验收通过。
