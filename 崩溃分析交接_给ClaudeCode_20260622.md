# 仙人指路 K线模块 — 间歇性约束崩溃 交接分析材料

> 给 Claude Code 的请求：请阅读下列源码文件，独立分析这个**间歇性崩溃**的根因，并给出**一次性、稳定**的修复方案（不要引入新的 Auto Layout 风险）。我（码农）已做了大量取证，但前三次根因判断都错了，需要你交叉验证我最新的结论是否正确，以及修复方向是否最优。

---

## 一、项目与环境路径

- **项目根目录**：`/Users/songxiaoxiao/Desktop/仙人指路测试项目`
- **Xcode 工程**：`/Users/songxiaoxiao/Desktop/仙人指路测试项目/仙人指路.xcodeproj`
- **scheme**：`仙人指路`
- **构建命令**：
  ```
  cd "/Users/songxiaoxiao/Desktop/仙人指路测试项目" && xcodebuild -project "仙人指路.xcodeproj" -scheme "仙人指路" -configuration Debug build
  ```
- **DerivedData**：`/Users/songxiaoxiao/Library/Developer/Xcode/DerivedData/仙人指路-hjvlqaweoiipbdgccflnecdsbapz/`
- **编译产物二进制**：`.../Build/Products/Debug/仙人指路.app/Contents/MacOS/仙人指路`
- **运行时真实日志**（app 未启用沙盒）：`/Users/songxiaoxiao/Documents/KLineLogs/KLineModule.log`
- **崩溃报告目录**：`~/Library/Logs/DiagnosticReports/仙人指路-*.ips`
- **系统**：macOS 26.5.1 (25F80)，Mac Studio M3 Ultra，arm64

---

## 二、涉及的源码文件（请重点阅读）

| 文件 | 绝对路径 | 角色 |
|---|---|---|
| **KX-UI-18 工具栏** | `/Users/songxiaoxiao/Desktop/仙人指路测试项目/K线模块/UI组件层/KX-UI-18_工具栏.swift` | **最新怀疑的真凶**：内部用 Auto Layout，第321行 `heightAnchor.constraint(greaterThanOrEqualToConstant: 32)` |
| **KX-UI-09 OKX风格面板** | `/Users/songxiaoxiao/Desktop/仙人指路测试项目/K线模块/UI组件层/KX-UI-09_OKX风格面板.swift` | 面板布局，把工具栏/标签栏 addSubview 并用 autoresizingMask + frame 布局；toolH 在最小化时=0 |
| **KX-UI-10 币对标签栏** | `/Users/songxiaoxiao/Desktop/仙人指路测试项目/K线模块/UI组件层/KX-UI-10_币对标签栏.swift` | 我反复改的文件（纯 frame 布局），**当前是回退稳定版**。一度被误判为崩溃元凶 |
| KX-UI-08 面板入口 | `/Users/songxiaoxiao/Desktop/仙人指路测试项目/K线模块/UI组件层/KX-UI-08_面板入口.swift` | openPanel 入口，restore 调用点 |
| KX-FN-18 启动恢复管道 | `/Users/songxiaoxiao/Desktop/仙人指路测试项目/K线模块/业务功能层/KX-FN-18_启动恢复管道.swift` | 启动恢复（已修一个 DB 卡主线程 bug，见下） |
| KX-SJ-09 PostgreSQL适配 | `/Users/songxiaoxiao/Desktop/仙人指路测试项目/K线模块/数据服务层/KX-SJ-09_PostgreSQL适配.swift` | DB 层（已修，见下） |

### 我实际修改过的文件（本次会话）
1. `KX-UI-10_币对标签栏.swift` — 反复改"等宽+自适应"又反复回退，**当前=按字符数计宽的纯 frame 稳定版**。
2. `KX-FN-18_启动恢复管道.swift` — 修复了启动期 DB 卡主线程（已验证通过，与本崩溃**不同**问题）。
3. `KX-SJ-09_PostgreSQL适配.swift` — 加了主线程 DB 调用告警（防回归）。

---

## 三、崩溃现象

- **现象**：K线面板打开后，app 运行一段时间后**自杀崩溃**（EXC_BREAKPOINT / SIGTRAP）。
- **间歇性**：有时 10 秒崩，有时 50 秒崩，有时 90 秒崩，有时不崩。**这点非常关键**。
- **三份崩溃报告**（均为同一崩溃签名）：
  - `~/Library/Logs/DiagnosticReports/仙人指路-2026-06-22-044325.ips`（PID 68513，跑约87秒后崩）
  - `~/Library/Logs/DiagnosticReports/仙人指路-2026-06-22-045512.ips`（PID 69801，跑约74秒后崩）
  - `~/Library/Logs/DiagnosticReports/仙人指路-2026-06-22-050820.ips`

### 崩溃栈特征（三次完全一致）
崩在主线程，调用栈**全是 AppKit / CoreAutoLayout / QuartzCore，没有一帧业务代码**：
```
_crashOnException
→ LAYOUT_CONSTRAINTS_NOT_SATISFIABLE
→ -[NSView ... engine:willBreakConstraint:dueToMutuallyExclusiveConstraints:]
→ NSISEngine ... (约束引擎求解)
→ -[NSWindow updateConstraintsIfNeeded]
→ NSDisplayCycleFlush → CA::Transaction::commit()   ← 在显示周期/CATransaction 提交时爆炸
→ __CFRunLoopDoObservers / __CFRunLoopRun
```
另一条 asiBacktrace 还显示：
```
_postWindowNeedsUpdateConstraints
→ _informContainerThatSubviewsNeedUpdateConstraints (递归8层)
→ -[NSTextField updateConstraints]
```

---

## 四、lldb 取证拿到的真实异常（关键证据）

`open` 启动会丢 stderr，统一日志(`log show`)里也没有约束告警，app 自己的文件日志只记业务日志。**只有用 lldb 在 `objc_exception_throw` 下断点才抓到真实异常文本**：

取证命令：
```
lldb -b -o "b objc_exception_throw" -o "run" -o "po (id)\$x0" -o "bt 25" -o "quit" \
  "/Users/songxiaoxiao/Library/Developer/Xcode/DerivedData/仙人指路-hjvlqaweoiipbdgccflnecdsbapz/Build/Products/Debug/仙人指路.app/Contents/MacOS/仙人指路"
```

抓到的真实异常（多次复现，地址不同但结构一致）：
```
[AppKit] Conflicting constraints detected: (
    "<NSLayoutConstraint:0x... :0x<A>.height >= 32   (active)>",
    "<NSAutoresizingMaskLayoutConstraint:0x... h=-&- v=-&- :0x<A>.minY == 0   (active, names: '|':NSView:0x<B> )>",
    "<NSAutoresizingMaskLayoutConstraint:0x... h=-&- v=-&- V:|-(0)-[:0x<A>]   (active, names: '|':NSView:0x<B> )>",
    "<NSAutoresizingMaskLayoutConstraint:0x... h=-&- v=&-- NSView:0x<B>.height == 0   (active)>"
)
Will attempt to recover by breaking <NSLayoutConstraint:0x... :0x<A>.height >= 32 (active)>.
[Layout] Unable to simultaneously satisfy constraints ...
→ LAYOUT_CONSTRAINTS_NOT_SATISFIABLE → NSException → _crashOnException
```

**解读**：
- 视图 A：`height >= 32`（这是 Auto Layout 显式约束）。
- 容器 B：`height == 0`（此刻容器高度为 0）。
- A 被 autoresizing 钉死在容器顶部（minY==0、V:|-(0)-[A]）。
- 「A 高度≥32」 与 「容器高度==0 且 A 钉满容器」 **互相矛盾 → 不可满足**。

---

## 五、根因定位（我最新的结论，需你验证）

全局搜索 `height >= 32` 的来源：
- **`KX-UI-18_工具栏.swift:321`**：
  ```swift
  let baseConstraints = [
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 32)   // ← 就是这条
  ]
  NSLayoutConstraint.activate(baseConstraints + normalLayoutConstraints)
  ```
  即 `KXUI18ToolbarView` 给自己加了 `heightAnchor >= 32`（**Auto Layout**）。

- **`KX-UI-09_OKX风格面板.swift:114-115`** 把它这样加进去：
  ```swift
  let toolbarView = KXUI18ToolbarView(frame: .zero)
  toolbarView.autoresizingMask = [.width, .height]   // ← translatesAutoresizingMaskIntoConstraints 仍为 true
  ...
  toolbar.addSubview(toolbarView)
  ```

- **`KX-UI-09_OKX风格面板.swift:156-168`** 布局时，工具栏宿主高度在最小化/启动瞬间可为 0：
  ```swift
  let toolH: CGFloat = minimized ? 0 : 32
  ...
  toolbarHost?.frame = CGRect(x: 0, y: tbH, width: bounds.width, height: toolH)  // toolH 可能=0
  ```

### 我判断的冲突机制
`KXUI18ToolbarView` **同时**：
1. 内部用 Auto Layout 给自己定了 `heightAnchor >= 32`；
2. 又被设了 `autoresizingMask = [.width, .height]`（`translatesAutoresizingMaskIntoConstraints == true`）→ AppKit 自动生成 `NSAutoresizingMaskLayoutConstraint`，把它的高度==宿主高度、minY==0。

当宿主（toolbar host）在**最小化或启动布局的某一瞬间高度=0**时：
- autoresizing 约束要求 toolbarView.height == 宿主.height == 0；
- 内部约束要求 toolbarView.height >= 32；
- 两者不可同时满足 → **不可满足约束**。

而这个 app（疑似在某处设置了 `NSConstraintBasedLayout` 致命化，或 `_crashOnException`/异常断言开启）把"不可满足约束"**升级成致命崩溃**（正常 app 只会打 warning 并自动 break 一条约束恢复，不崩）。

**这是 KX-UI-18 + KX-UI-09 的预先存在的设计冲突（autoresizingMask 与 heightAnchor 混用），与我反复改的标签栏 KX-UI-10 没有必然因果**——之前每次"改标签栏→崩"很可能是巧合（每次都恰好在显示周期撞上工具栏宿主 height==0 的时刻）。

---

## 六、我试过但被推翻的三次错误判断（供你避坑）

1. **第一次**：以为是给 NSButton 的 cell 设 `lineBreakMode = .byTruncatingTail` 触发坏约束。→ 去掉后仍崩，**推翻**。
2. **第二次**：以为是 `layout()` 里每次 `removeFromSuperview` + 重建按钮造成"约束更新风暴"。→ 纯 frame 重建也崩，**推翻**。
3. **第三次**：以为是给 `.rounded` NSButton 设 `btn.font` 启用了 intrinsic-size 约束(height>=32)。→ 去掉 font 仍崩，且约束来源经查是 KX-UI-18 工具栏不是标签按钮，**推翻**。

**方法论教训**：
- lldb 命中 `objc_exception_throw` ≠ 进程真崩溃（AppKit 对不可满足约束会 raise 一个可被内部 catch 恢复的异常，断点会拦到这种"可恢复 raise"）。真崩溃判据应是**进程真退出 + 生成新的 .ips**。
- 改 UI 前必须先用**未改动的稳定版**在相同条件下长跑建立基线，确认它本身崩不崩——我一直跳过这步导致误判。

---

## 七、需要你（Claude Code）回答的问题

1. 验证我第五节的根因结论是否正确：崩溃是否就是 `KXUI18ToolbarView` 的 `heightAnchor >= 32`（Auto Layout）与 `autoresizingMask=[.width,.height]`（autoresizing 转换约束）在宿主高度=0 时的冲突？
2. 这个 app 是在哪里把"不可满足约束"升级成了**致命崩溃**？（请在项目里搜：是否设置了 `NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints`、是否有自定义 `engine:willBreakConstraint:` 重写、是否开了异常断言、main.swift 或 AppDelegate 是否有相关设置。）若能去掉这个"致命化"，是否就能让 app 像正常 app 一样只 warning 不崩？
3. 给出**一次性、稳定**的修复方案，并说明优劣。我倾向的候选方向（请评估/纠正）：
   - 方案A：`KXUI18ToolbarView` 内部**不要**用 `heightAnchor >= 32` 这种硬约束；既然外层是 frame/autoresizing 布局，工具栏自身也应纯 frame，去掉自带的 Auto Layout 约束。
   - 方案B：把 `heightAnchor >= 32` 降低优先级（`priority = .defaultLow` 或 749），让它在冲突时可被无害打破。
   - 方案C：工具栏宿主高度永不为 0（最小化时用极小正值或 `isHidden=true` 代替 height=0）。
   - 方案D：去掉那个把约束冲突"致命化"的设置（治本，但需确认副作用）。
4. 修复后如何验证它**真的**不再崩（我的验证手段：lldb 跑 + 看是否生成新 .ips + 长跑覆盖最小化/显示周期）。

---

## 八、附：约束"致命化"可能的搜索线索
请在项目中搜索以下关键字，定位崩溃升级点：
- `_crashOnException` / `NSApplicationCrashOnExceptions`
- `setValue(true, forKey: "NSConstraintBasedLayout...")`
- `NSExceptionHandler` / `NSSetUncaughtExceptionHandler`
- `translatesAutoresizingMaskIntoConstraints`（确认 KXUI18ToolbarView 是否真未设为 false）
- Info.plist / UserDefaults 里 `NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints`

（材料整理人：码农。如需任何源码片段或重新取证，可让晓筱转达。）
