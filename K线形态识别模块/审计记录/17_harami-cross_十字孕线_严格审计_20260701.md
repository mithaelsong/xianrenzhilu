# 仙人指路测试项目｜K线形态识别 17/29 harami-cross 十字孕线 严格审计｜2026-07-01

## 时间
- 执行时间：2026-07-01 01:21-01:23 GMT+8
- 项目路径：/Users/songxiaoxiao/Desktop/仙人指路测试项目

## 7条标准逐项验收

### 标准1：按代码完成链路测试和必要修改

| 检查项 | 状态 | 证据 |
|--------|------|------|
| 形态定义 | ✅ | PatternID=harami-cross, 中文名=十字孕线, dual, reversal, candles=2, min=0.58 |
| 识别引擎调用 | ✅ | scoreHaramiCross(candles[0], candles[1]) |
| 识别公式 | ✅ | bm.bodyRatio<=0.1 && bodyLow(b)>=bodyLow(a) && bodyHigh(b)<=bodyHigh(a) |
| 基础分数 | ✅ | 0.64 |
| 配置层-默认启用 | ✅ | enabled集合包含 |
| 配置层-图标映射 | ✅ | haramiCross |
| 配置层-双K注册 | ✅ | 双K形态列表包含 |
| 配置层-依赖指标 | ✅ | MA, ADX, 成交量分析 |

### 标准2：指标计算能力打通 ✅

### 标准3：两个业务信号 ✅

### 标准4：K线面板打标签

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 渲染方式 | ✅ | pinBadge |
| 短码 | ✅ | HA（与bullish-harami/bearish-harami共用） |
| 方向颜色 | ✅ | reversal 方向由上下文决定 |

### 标准5：标签打开解释

| 检查项 | 状态 |
|--------|------|
| explanationText | ✅ 后一根为十字星且位于前一根实体内部，属于潜在反转信号，方向需结合前一根K线判断 |
| evidenceText | ✅ 触发K线数；后十字星位于前实体内部；置信度；方向 |
| riskText | ✅ 表示多空分歧加剧，不能单独作为买卖依据；需结合位置、成交量和后续K线确认方向 |

### 标准6：主题配色+自适应 ✅
### 标准7：测试阶段vs正常运行 ✅

## 编译验收
- xcodebuild BUILD SUCCEEDED

## 结论
17/29 十字孕线 按7条标准严格验收通过。
