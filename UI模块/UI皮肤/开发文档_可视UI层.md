# 仙人指路2.0 — 可视UI层（皮肤层）开发文档

> 文档编号：SKIN-DOC-001  
> 版本：v1.0  
> 作者：码农  
> 日期：2026-06-06  
> 对应代码：/Users/songxiaoxiao/Desktop/仙人指路2-min/仙人指路2-min/AppDelegate.swift + UI 皮肤/ 目录下9个皮肤文件

---

## 一、架构总览

```
┌─────────────────────────────────────────────┐
│              用户交互层                        │
│  ┌──────────────┐  ┌──────────────────┐     │
│  │ ⚙ 设置按钮   │  │ 手势（双指滑动）   │     │
│  │ 悬停+弹起   │  │ 窗口级事件监听     │     │
│  └──────────────┘  └──────────────────┘     │
├─────────────────────────────────────────────┤
│              视图层（皮肤层）                  │
│  ┌──────────────┐  ┌──────────────────┐     │
│  │ 设置面板      │  │ 无限画布          │     │
│  │ 相册堆叠式    │  │ 5000x5000滚动区域 │     │
│  │ 6张主题卡片   │  │                   │     │
│  │ 悬停散开效果  │  │                   │     │
│  └──────────────┘  └──────────────────┘     │
├─────────────────────────────────────────────┤
│              皮肤系统（Bundle式）              │
│  ┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐    │
│  │浅色││深色││高对││红盲││绿盲││玻璃│    │
│  │    ││    ││比度││    ││    ││    │    │
│  └────┘└────┘└────┘└────┘└────┘└────┘    │
│  共6个主题皮肤，每个独立编译为.bundle          │
├─────────────────────────────────────────────┤
│              底层引擎                          │
│  Skin-01 入口 → Skin-02 引擎 → Skin-03 注册表 │
│  LRU缓存 · 颜色解析 · 字体管理 · 间距配置       │
└─────────────────────────────────────────────┘
```

---

## 二、模块清单

| 序号 | 模块 | 文件/类 | 状态 | 说明 |
|------|------|---------|------|------|
| 1 | 主窗口 | AppDelegate | ✅ 完成 | Finder风格窗口 + 原生工具栏 |
| 2 | 设置按钮 | GlassSettingsButton | ✅ 完成 | 44x44玻璃底座 + 悬停动画 |
| 3 | 设置面板 | SettingsPanelView | ✅ 完成 | 相册堆叠式6卡片 + 悬停散开 |
| 4 | 主题卡片 | ThemeCardView | ✅ 完成 | 260x170卡片 + 点击切换皮肤 |
| 5 | 无限画布 | createCanvas | ✅ 完成 | NSScrollView 5000x5000 |
| 6 | 皮肤入口 | Skin-01 | ✅ 完成 | 42个公开接口 + 26个测试 |
| 7 | 皮肤引擎 | Skin-02 | ✅ 完成 | LRU缓存 + 颜色/字体/间距 |
| 8 | 皮肤注册表 | Skin-03 | ✅ 完成 | 扫描/解析/搜索/热插拔 |
| 9 | 深色主题 | Skin-04 | ✅ 完成 | #1E1E1E/#0A84FF |
| 10 | 高对比度 | Skin-05 | ✅ 完成 | 黑底黄字 + 加粗字体 |
| 11 | 红色盲 | Skin-06 | ✅ 完成 | 红→黄橙重映射 |
| 12 | 绿色盲 | Skin-07 | ✅ 完成 | 绿→蓝紫重映射 |
| 13 | 浅色主题 | Skin-08 | ✅ 完成 | 系统默认浅色 |
| 14 | 玻璃皮肤 | Skin-09 | ✅ 完成 | 整套UI显示层 + 原生语义色 |

---

## 三、核心交互流程

### 3.1 打开设置面板

```
用户点击 ⚙ 按钮
    ↓
AppDelegate.settingsClicked()
    ↓
settingsPanelOpen == false
    ↓
openSettingsPanel(in: contentView)
    ↓
创建 SettingsPanelView（全屏尺寸）
    ↓
设置 identifier = "settingsPanel"（用于后续查找）
    ↓
初始位置：panel.frame.origin.x = contentView.bounds.maxX（在右侧外）
    ↓
NSAnimationContext 动画：0.5秒滑入到 x=0
    ↓
面板推入完成，显示6张卡片
    ↓
卡片入场动画：6张卡片依次从底部飞入（间隔60ms，弹簧效果）
```

### 3.2 关闭设置面板

```
用户再次点击 ⚙ 按钮
    ↓
settingsPanelOpen == true
    ↓
closeSettingsPanel(in: contentView)
    ↓
查找 subviews 中 identifier == "settingsPanel" 的面板
    ↓
NSAnimationContext 动画：0.4秒滑出到 x=contentView.bounds.maxX
    ↓
动画完成 → removeFromSuperview()
```

### 3.3 卡片悬停散开效果（核心）

```
鼠标在 SettingsPanelView 上移动
    ↓
mouseMoved(with:) 收到事件
    ↓
convert(event.locationInWindow, from: nil) → 获取鼠标在面板中的坐标
    ↓
遍历 allCards（倒序，最上面的卡片优先）
    ↓
检查 card.frame.contains(point) → 找到鼠标所在的卡片
    ↓
如果 foundCard != currentHoveredCard
    ↓
    ├─ 如果有旧卡片：onCardExit(old) → 所有卡片归位
    └─ 如果有新卡片：onCardEnter(new) → 散开动画
```

**散开动画细节：**

```swift
// 目标卡片（被hover的）
放大到 1.15 倍
往上弹起 15 像素
阴影加深（0.08 → 0.25，半径 8 → 15）
动画时长：0.25秒，easeOut

// 其他卡片
根据与目标卡片的距离决定散开方向：
    - 在目标左边：向左移（direction = -1）
    - 在目标右边：向右移（direction = +1）
散开距离：max(8, 20 - distance * 3) 像素
越远散开得越少
轻微缩小：max(0.85, 1.0 - distance * 0.02)
动画时长：0.3秒，easeOut
```

**归位动画细节：**

```swift
所有卡片回到 cardOriginalFrames 保存的原始位置
恢复原始大小（CATransform3DIdentity）
阴影恢复默认值（0.08，半径8）
动画时长：0.35秒，easeIn
```

### 3.4 点击卡片切换皮肤

```
用户点击某张主题卡片
    ↓
ThemeCardView.cardClicked()
    ↓
根据卡片名称映射到 skinId
    ↓
NotificationCenter.post(name: "switchSkin", object: skinId)
    ↓
AppDelegate.switchSkin(_:) 收到通知
    ↓
打印：切换皮肤: com.app.xxx
    ↓
（后续：实际调用 SkinService.setSkin()）
```

**skinId 映射表：**

| 卡片名称 | skinId | 对应文件 |
|----------|--------|----------|
| 浅色模式 | com.app.light | Skin-08 |
| 深色模式 | com.app.dark | Skin-04 |
| 高对比度 | com.app.high-contrast | Skin-05 |
| 红色盲 | com.app.protanopia | Skin-06 |
| 绿色盲 | com.app.deuteranopia | Skin-07 |
| 玻璃皮肤 | com.app.glass | Skin-09 |

---

## 四、动画系统参数

### 4.1 面板推入/收回

| 参数 | 打开 | 关闭 |
|------|------|------|
| 时长 | 0.5秒 | 0.4秒 |
| 缓动 | easeOut | easeIn |
| 起始位置 | x = bounds.maxX（右侧外） | x = 0 |
| 结束位置 | x = 0 | x = bounds.maxX（右侧外） |

### 4.2 卡片入场动画

| 参数 | 值 |
|------|-----|
| 触发时机 | 面板推入完成后 |
| 卡片间隔 | 60ms（第0张立即，第1张60ms后，第2张120ms后...） |
| 起始缩放 | 0.7 |
| 结束缩放 | 1.0 |
| 弹簧阻尼 | 10.0 |
| 初始速度 | 6.0 |
| 刚度 | 120.0 |
| 质量 | 0.6 |
| 时长 | 0.5秒 |

### 4.3 卡片悬停散开

| 参数 | 目标卡片 | 其他卡片 |
|------|----------|----------|
| 缩放 | 1.15 | 0.85~0.98 |
| 垂直位移 | +15px | 0 |
| 水平位移 | 0 | ±(8~20)px |
| 阴影透明度 | 0.25 | 0.08 |
| 阴影半径 | 15 | 8 |
| 动画时长 | 0.25秒 | 0.3秒 |
| 缓动 | easeOut | easeOut |

### 4.4 卡片归位

| 参数 | 值 |
|------|-----|
| 动画时长 | 0.35秒 |
| 缓动 | easeIn |
| 恢复属性 | 位置、缩放、阴影 |

### 4.5 ⚙ 按钮悬停

| 参数 | 鼠标进入 | 鼠标离开 |
|------|----------|----------|
| 背景透明度 | 0.5 → 0.8 | 0.8 → 0.5 |
| 缩放 | 1.0 → 1.1 | 1.1 → 1.0 |
| 时长 | 0.2秒 | 0.3秒 |

---

## 五、布局系统

### 5.1 卡片堆叠布局（相册堆叠式）

```swift
let cardW: CGFloat = 260        // 卡片宽度
let cardH: CGFloat = 170        // 卡片高度
let offsetX: CGFloat = 40       // 水平间距
let offsetY: CGFloat = 15       // 垂直间距
let startX: CGFloat = (bounds.width - (cardW + (count-1) * offsetX)) / 2  // 水平居中
let startY: CGFloat = (bounds.height - (cardH + (count-1) * offsetY)) / 2 + 20  // 垂直居中+偏移
```

**卡片位置计算：**

```
索引 i（0~5）
frame.x = startX + i * offsetX          → 从左下到右上
frame.y = startY + (5-i) * offsetY    → 从右下到左上（倒序）
```

**视觉效果：**
- 第0张（浅色模式）：最下面，位置最左
- 第5张（玻璃皮肤）：最上面，位置最右
- 每张卡片比下一张偏移 (40, 15)，形成右下→左上堆叠

### 5.2 窗口布局

```
┌──────────────────────────────────────────┐
│ 标题栏（原生，带分割线）                   │
├──────────────────────────────────────────┤
│                                          │
│  ┌────────────────────────────────────┐  │
│  │                                    │  │
│  │        无限画布（可滚动）           │  │
│  │                                    │  │
│  │     ┌─────────────────┐            │  │
│  │     │ 设置面板（推入）│            │  │
│  │     │ ┌──┐┌──┐┌──┐  │            │  │
│  │     │ └──┘└──┘└──┘  │            │  │
│  │     │ 6张卡片堆叠     │            │  │
│  │     └─────────────────┘            │  │
│  │                                    │  │
│  └────────────────────────────────────┘  │
│                                    [⚙]  │
└──────────────────────────────────────────┘
```

---

## 六、皮肤系统（Bundle式）

### 6.1 编译流程

```
UI 皮肤/Skin-01_皮肤系统入口.swift   →  Skin-01.bundle
UI 皮肤/Skin-02_皮肤引擎.swift      →  Skin-02.bundle
UI 皮肤/Skin-03_皮肤注册表.swift    →  Skin-03.bundle
UI 皮肤/Skin-04_深色主题.swift  →  Skin-04.bundle
UI 皮肤/Skin-05_高对比度主题.swift  →  Skin-05.bundle
UI 皮肤/Skin-06_红色盲主题.swift    →  Skin-06.bundle
UI 皮肤/Skin-07_绿色盲主题.swift    →  Skin-07.bundle
UI 皮肤/Skin-08_浅色主题.swift  →  Skin-08.bundle
UI 皮肤/Skin-09_玻璃皮肤.swift      →  Skin-09.bundle
```

**编译脚本：** `build_bundle.sh`  
**触发方式：** Xcode Aggregate Target → 点▶ BuildBundles

### 6.2 皮肤注册

每个皮肤在 Skin-03 注册表中注册：

```swift
SkinRegistry.register("com.app.light", bundle: lightSkinBundle)
SkinRegistry.register("com.app.dark", bundle: darkSkinBundle)
SkinRegistry.register("com.app.high-contrast", bundle: highContrastBundle)
SkinRegistry.register("com.app.protanopia", bundle: protanopiaBundle)
SkinRegistry.register("com.app.deuteranopia", bundle: deuteranopiaBundle)
SkinRegistry.register("com.app.glass", bundle: glassSkinBundle)
```

### 6.3 皮肤切换接口

```swift
// Skin-01 提供的公开接口
SkinService.setSkin("com.app.dark")        // 切换皮肤
SkinService.currentSkin()                   // 获取当前皮肤
SkinService.availableSkins()                // 获取所有可用皮肤
SkinService.skinDidChangeNotification       // 皮肤切换通知
```

---

## 七、手势系统

### 7.1 双指滑动（窗口级监听）

```swift
NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
    // 双指滑动事件
    // 不会被 scrollView 拦截
    return event
}
```

**特点：**
- 窗口级别监听，不被画布拦截
- 双指上下滑动触发
- 可扩展为面板推入手势

---

## 八、技术选型

| 技术 | 选择 | 原因 |
|------|------|------|
| 框架 | AppKit（macOS原生） | 原生质感，不用第三方 |
| 动画 | NSAnimationContext + animator() | 系统原生，线程安全 |
| 弹簧动画 | CASpringAnimation | 物理真实感 |
| 颜色 | NSColor 语义色 | 跟随浅色/深色自动切换 |
| 字体 | NSFont.systemFont | 跟随系统字体设置 |
| 阴影 | CALayer.shadow* | 原生，性能最佳 |
| 编译 | Bundle式（独立.swift→.bundle） | 源码不动，只生成产物 |

---

## 九、开发规范

### 9.1 代码规范（晓筱标准）

- ✅ 所有可见文字：中文（注释、日志、测试）
- ✅ 标识符：英文（类名、方法名、变量名）
- ✅ 测试格式：`guard + fatalError("❌ 中文")`
- ✅ 文件内分区：必须用 `// MARK:` 清晰分区
- ✅ 锁：NSRecursiveLock，手动 lock/unlock，零 defer
- ✅ 零强制解包、零 `[String:Any]` 通知

### 9.2 文件分区示例

```swift
// MARK: - 公开接口
// MARK: - 内部实现
// MARK: - 动画效果
// MARK: - 事件处理
// MARK: - 测试
```

---

## 十、已知问题与待办

### 10.1 已修复问题

| 问题 | 原因 | 修复方式 |
|------|------|----------|
| 卡片在左下角 | 写死 startX=40 | 改为自动计算居中 |
| 卡片太小 | 180x120 | 放大到 260x170 |
| 悬停无反应 | tracking area frame=0 | 改用 mouseMoved 面板级监听 |
| 面板动画无声 | keyPath "frameOrigin.x" 错误 | 改用 NSAnimationContext |
| 双指手势失效 | NSPanGesture 被 scrollView 拦截 | 改用窗口级 scrollWheel 监听 |

### 10.2 待实现功能

| 功能 | 状态 | 说明 |
|------|------|------|
| 皮肤切换实际调用 | ⏳ 待接入 | 当前只发通知，未调 SkinService.setSkin |
| 二级菜单页面 | ⏳ 待设计 | 点击卡片后进入详情/预览页 |
| 翻页效果（手势拖拽） | ⏳ 待实现 | 鼠标拖拽卡片跟随+弹性动画 |
| 画布内容填充 | ⏳ 待填充 | K线模块、指标模块、K线形态识别模块 |
| 手势呼出面板 | ⏳ 待实现 | 双指滑动呼出/关闭设置面板 |

---

## 十一、测试清单

### 11.1 已测试项

- ✅ 窗口正常显示，标题栏有分割线
- ✅ ⚙ 按钮显示，44x44，有玻璃质感
- ✅ 点击 ⚙ 按钮，面板从右侧滑入
- ✅ 再次点击 ⚙ 按钮，面板滑出
- ✅ 6张卡片显示在正中间，堆叠效果
- ✅ 卡片有圆角、边框、阴影、底部细线
- ✅ 卡片入场动画：依次从底部飞入
- ✅ 鼠标悬停：目标卡片放大，其他散开
- ✅ 鼠标离开：所有卡片归位
- ✅ 点击卡片：发送皮肤切换通知
- ✅ 按钮悬停：背景变亮+放大

### 11.2 待测试项

- ⏳ 实际皮肤切换（等接入 SkinService）
- ⏳ 二级菜单页面
- ⏳ 翻页拖拽效果
- ⏳ 手势呼出面板

---

## 十二、文件路径

| 文件 | 路径 | 说明 |
|------|------|------|
| 主程序 | ~/Desktop/仙人指路2-min/仙人指路2-min/AppDelegate.swift | UI层主文件 |
| 皮肤入口 | ~/Desktop/仙人指路/仙人指路 2.0/UI模块/UI 皮肤/Skin-01_皮肤系统入口.swift | 42接口+26测试 |
| 皮肤引擎 | ~/Desktop/仙人指路/仙人指路 2.0/UI模块/UI 皮肤/Skin-02_皮肤引擎.swift | LRU+颜色/字体/间距 |
| 皮肤注册表 | ~/Desktop/仙人指路/仙人指路 2.0/UI模块/UI 皮肤/Skin-03_皮肤注册表.swift | 扫描/解析/热插拔 |
| 深色主题 | ~/Desktop/仙人指路/仙人指路 2.0/UI模块/UI 皮肤/Skin-04_深色主题.swift | #1E1E1E/#0A84FF |
| 高对比度 | ~/Desktop/仙人指路/仙人指路 2.0/UI模块/UI 皮肤/Skin-05_高对比度主题.swift | 黑底黄字 |
| 红色盲 | ~/Desktop/仙人指路/仙人指路 2.0/UI模块/UI 皮肤/Skin-06_红色盲主题.swift | 红→黄橙 |
| 绿色盲 | ~/Desktop/仙人指路/仙人指路 2.0/UI模块/UI 皮肤/Skin-07_绿色盲主题.swift | 绿→蓝紫 |
| 浅色主题 | ~/Desktop/仙人指路/仙人指路 2.0/UI模块/UI 皮肤/Skin-08_浅色主题.swift | 系统默认浅色 |
| 玻璃皮肤 | ~/Desktop/仙人指路/仙人指路 2.0/UI模块/UI 皮肤/Skin-09_玻璃皮肤.swift | 整套UI显示层 |
| 编译脚本 | ~/Desktop/仙人指路/仙人指路 2.0/build_bundle.sh | .swift→.bundle |
| 本文档 | ~/Desktop/仙人指路/仙人指路 2.0/UI模块/UI 皮肤/开发文档_可视UI层.md | 本文件 |

---

## 十三、附录：核心代码速查

### 13.1 设置面板入场动画

```swift
NSAnimationContext.runAnimationGroup({ ctx in
    ctx.duration = 0.5
    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
    panel.animator().frame.origin.x = 0
}, completionHandler: nil)
```

### 13.2 卡片悬停散开

```swift
// 目标卡片
CATransform3DMakeScale(1.15, 1.15, 1.0)  // 放大
frame.origin.y += 15                      // 弹起
shadowColor = 黑色0.25                    // 阴影加深
shadowRadius = 15                         // 阴影扩散

// 其他卡片（左边）
frame.origin.x -= spreadAmount           // 向左散

// 其他卡片（右边）
frame.origin.x += spreadAmount           // 向右散
```

### 13.3 弹簧动画参数

```swift
let s = CASpringAnimation(keyPath: "transform")
s.damping = 10.0      // 阻尼
s.stiffness = 120.0   // 刚度
s.mass = 0.6          // 质量
s.initialVelocity = 6.0  // 初始速度
```

---

> 本文档完成。后续修改代码时同步更新。

