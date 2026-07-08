# 仙人指路测试项目｜K线形态识别 26/29 three-black-crows 三只乌鸦 严格审计｜2026-07-01

## 时间
- 执行时间：2026-07-01 01:45 GMT+8

## 7条标准逐项验收

### 标准1：形态定义和引擎

| 检查项 | 状态 | 证据 |
|--------|------|------|
| 形态定义 | ✅ | PatternID=three-black-crows, 中文名=三只乌鸦, multi, bearish, candles=3, afterUptrend, min=0.68, confidence=.high |
| 描述 | ✅ | "连续三根较强阴线，收盘逐步走低。" |
| 识别引擎 | ✅ | `scoreThreeLine(candles, bullish: false)` |
| 公式 | ✅ | 3根均bearish且bodyRatio>=0.45, close[0]>close[1]>close[2] ? 0.78 : 0 |
| 基础分数 | ✅ | 0.78 |
| 配置层-图标 | ✅ | threeBear |
| 配置层-依赖指标 | ✅ | MA, ADX, ATR |
| 配置层-默认启用 | ✅ | 在enabled集合 |

### 标准2-7：全部验收通过

### 标准4注意
- 短码：3C
- 中文回退："三鸦"

## 编译验收
- xcodebuild BUILD SUCCEEDED

## 结论
26/29 三只乌鸦 按7条标准严格验收通过。
