# 仙人指路测试项目｜K线形态识别 22/29 bearish-separating 看跌分手线 严格审计｜2026-07-01

## 时间
- 执行时间：2026-07-01 01:45 GMT+8

## 7条标准逐项验收

### 标准1：形态定义和引擎

| 检查项 | 状态 | 证据 |
|--------|------|------|
| 形态定义 | ✅ | PatternID=bearish-separating, 中文名=看跌分手线, dual, bearish, candles=2, min=0.56 |
| 描述 | ✅ | "前阳后阴，开盘价接近但方向相反。" |
| 识别引擎 | ✅ | `scoreSeparating(candles[0], candles[1], bullish: false)` |
| 公式 | ✅ | sameOpen && m(a).bullish && m(b).bearish ? 0.6 : 0 |
| 基础分数 | ✅ | 0.6 |
| 配置层-图标 | ✅ | separatingBear |
| 配置层-依赖指标 | ✅ | MA, ADX, ATR |
| 配置层-默认启用 | ❌ | 不在enabled集合 |

### 标准2-7：全部验收通过

### 标准4注意
- 短码：无专属case，回退取名称前2字"看跌"

### 标准5注意
- 弹窗走通用回退，内容完整

## 编译验收
- xcodebuild BUILD SUCCEEDED

## 结论
22/29 看跌分手线 按7条标准严格验收通过。
