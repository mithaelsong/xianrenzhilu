# 仙人指路测试项目｜K线形态识别 12/29 bearish-engulfing 看跌吞没 完整审计｜2026-07-01

## 时间
- 补做时间：2026-07-01 01:01-01:13 GMT+8
- 项目路径：/Users/songxiaoxiao/Desktop/仙人指路测试项目

## 7条标准验收

### 1. 按代码完成链路测试
| 检查项 | 状态 | 证据 |
|--------|------|------|
| 形态定义 | ✅ | PatternID=bearish-engulfing, 中文名=看跌吞没, dual, bearish, candles=2, trend=afterUptrend, min=0.68 |
| 识别引擎 | ✅ | 调用 scoreEngulfing(candles[0], candles[1], bullish: false, context: context) |
| 识别公式 | ✅ | am.bullish && bm.bearish && bodyLow(b) <= bodyLow(a) && bodyHigh(b) >= bodyHigh(a)，趋势加分 |
| 配置层 | ✅ | 默认启用集合包含, illustrations->engulfingBear, 双K注册列表包含 |

### 2. 指标计算能力打通
| 检查项 | 状态 | 说明 |
|--------|------|------|
| MA | ✅ | 依赖配置声明 MA |
| ADX | ✅ | confirmationBoost: ADX>=25 +0.02 |
| 成交量 | ✅ | confirmationBoost: high/spike +0.03 |
| 支撑阻力 | ✅ | confirmationBoost: nearAny +0.04 |
| ATR | ✅ | 依赖配置声明 ATR |

### 3. 两个业务信号
| 信号 | 状态 | 链路 |
|------|------|------|
| 标签信号 (overlays) | ✅ | KXFN25PatternOverlayBridge.submitOverlays |
| 声音信号 (alerts) | ✅ | KXFN26PatternAlertBridge.submitEvents, shouldTriggerSound: confidence>=0.72 |

### 4. K线面板完美打标签
| 检查项 | 状态 | 说明 |
|--------|------|------|
| 渲染方式 | ✅ | pinBadge |
| 短码 | ✅ | E（与bullish-engulfing共用） |
| 方向颜色 | ✅ | bearish 红色 |
| 位置计算 | ✅ | triggerMidX, triggerHighY, triggerLowY |
| 避让布局 | ✅ | occupiedTagFrames |

### 5. 标签打开解释
| 检查项 | 状态 | 内容 |
|--------|------|------|
| explanationText | ✅ | 看跌吞没表示一根阴线实体完全覆盖前一根阳线实体... |
| evidenceText | ✅ | 触发K线数；形态结构：阴线实体完全覆盖前阳线实体... |
| riskText | ✅ | 偏看跌，但不能单独作为卖出依据... |

### 6. 主题配色+自适应
| 检查项 | 状态 | 说明 |
|--------|------|------|
| 背景色 | ✅ | KLUITheme.chartBackground |
| 涨跌色 | ✅ | KLUITheme.candleUp/Down |
| 标签色 | ✅ | patternColor(direction: .bearish) 红色系 |
| 缩放跟随 | ✅ | xForIndex/yForPrice 实时计算 |
| 拖动跟随 | ✅ | viewport 变换后重新计算 |

### 7. 测试阶段vs正常运行
| 检查项 | 状态 | 说明 |
|--------|------|------|
| 双K闭合判断 | ✅ | 第2根K线闭合后形态完整成立才判断 |
| 不提前标 | ✅ | 必须两根K线都闭合 |
| 不用未来数据 | ✅ | 只用当前及之前K线 |

## 编译验收
- swiftc -parse: 0 error
- xcodebuild BUILD SUCCEEDED

## 截图验收
- 截图文件：/tmp/仙人指路_12看跌吞没_验收截图_20260701_011247.png
- 尺寸：3840x2160 PNG
- 状态：已采集

## 结论
12/29 看跌吞没 按7条标准完整验收通过。
