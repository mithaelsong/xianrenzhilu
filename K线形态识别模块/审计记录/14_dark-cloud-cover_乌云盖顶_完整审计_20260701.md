# 仙人指路测试项目｜K线形态识别 14/29 dark-cloud-cover 乌云盖顶 完整审计｜2026-07-01

## 时间
- 补做时间：2026-07-01 01:14-01:15 GMT+8
- 项目路径：/Users/songxiaoxiao/Desktop/仙人指路测试项目

## 7条标准验收

### 1. 按代码完成链路测试
| 检查项 | 状态 | 证据 |
|--------|------|------|
| 形态定义 | ✅ | PatternID=dark-cloud-cover, 中文名=乌云盖顶, dual, bearish, candles=2, afterUptrend, min=0.62 |
| 识别引擎 | ✅ | 调用 scoreDarkCloud(candles[0], candles[1]) |
| 识别公式 | ✅ | am.bullish && bm.bearish && b.open > a.close && b.close < midpoint(a) && b.close > a.open |
| 配置层 | ✅ | 默认启用集合包含, illustrations->darkCloud, 双K注册列表包含 |

### 2. 指标计算能力打通
| 检查项 | 状态 |
|--------|------|
| MA/ADX/成交量/支撑阻力/ATR | ✅ |

### 3. 两个业务信号
| 信号 | 状态 |
|------|------|
| 标签信号 | ✅ KXFN25PatternOverlayBridge |
| 声音信号 | ✅ KXFN26PatternAlertBridge |

### 4. K线面板打标签
| 检查项 | 状态 | 说明 |
|--------|------|------|
| 渲染方式 | ✅ | pinBadge |
| 短码 | ✅ | DC |
| 方向颜色 | ✅ | bearish 红色 |

### 5. 标签打开解释
| 检查项 | 状态 |
|--------|------|
| explanationText | ✅ 乌云盖顶表示上涨后一根阴线高开低走... |
| evidenceText | ✅ 阴线高开低走、收盘价深入前阳线实体一半以下 |
| riskText | ✅ 偏看跌，不能单独卖出... |

### 6. 主题配色+自适应 ✅
### 7. 测试阶段vs正常运行 ✅

## 编译验收
- xcodebuild BUILD SUCCEEDED

## 截图验收
- /tmp/仙人指路_14乌云盖顶_验收截图_20260701_011513.png (3840x2160)

## 结论
14/29 乌云盖顶 按7条标准完整验收通过。
