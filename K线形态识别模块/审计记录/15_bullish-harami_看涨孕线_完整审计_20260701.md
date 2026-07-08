# 仙人指路测试项目｜K线形态识别 15/29 bullish-harami 看涨孕线 完整审计｜2026-07-01

## 时间
- 补做时间：2026-07-01 01:15 GMT+8
- 项目路径：/Users/songxiaoxiao/Desktop/仙人指路测试项目

## 本轮修改
- 补 explanationText / evidenceText / riskText 三处弹窗内容

## 7条标准验收

### 1. 按代码完成链路测试
| 检查项 | 状态 | 证据 |
|--------|------|------|
| 形态定义 | ✅ | PatternID=bullish-harami, 中文名=看涨孕线, dual, bullish, candles=2, afterDowntrend, min=0.58 |
| 识别引擎 | ✅ | 调用 scoreHarami(candles[0], candles[1], bullish: true) |
| 识别公式 | ✅ | bm.bodyRatio <= max(0.35, am.bodyRatio*0.75), bodyLow(b)>=bodyLow(a), bodyHigh(b)<=bodyHigh(a), am.bearish && bm.bullish |
| 配置层 | ✅ | 默认启用集合包含, illustrations->haramiBull, 双K注册列表包含 |

### 2. 指标计算能力打通 ✅
### 3. 两个业务信号 ✅
### 4. K线面板打标签
| 检查项 | 状态 | 说明 |
|--------|------|------|
| 渲染方式 | ✅ | pinBadge |
| 短码 | ✅ | HA（与bearish-harami/harami-cross共用） |
| 方向颜色 | ✅ | bullish 绿色 |

### 5. 标签打开解释
| 检查项 | 状态 |
|--------|------|
| explanationText | ✅ 下跌后小阳线实体完全位于前阴线实体内部... |
| evidenceText | ✅ 前阴后阳、后实体被前实体完全包含 |
| riskText | ✅ 偏看涨，不能单独买入... |

### 6. 主题配色+自适应 ✅
### 7. 测试阶段vs正常运行 ✅

## 编译验收
- xcodebuild BUILD SUCCEEDED

## 截图验收
- /tmp/仙人指路_15看涨孕线_验收截图_20260701_011545.png (3840x2160)

## 结论
15/29 看涨孕线 按7条标准完整验收通过。
