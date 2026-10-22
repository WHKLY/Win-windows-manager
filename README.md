# WindowswindowsManager

基于 AutoHotkey v2 与 Win32 API 的 Windows 智能浮动窗口编排器。

程序不会强制平铺窗口，而是把当前显示器上的普通窗口作为整体进行优化：合理放置新窗口，在收益足够明显时协同移动少量已有窗口，也支持用户主动重排当前显示器、锁定窗口和撤销最近一次布局。

当前版本：`0.1.0`。

## 当前状态

- 源码、默认配置、自动测试和 64 位 `.exe` 均已生成。
- 自动化与受控真机测试已通过：语法、几何/规划、平滑动画、真实外部窗口分类、新窗口事件链、手动重排、锁定和 Undo。
- 修复窗口事件稳定性问题后的初步真实使用测试已通过：新增日志无 ERROR、无 WARN、无队列溢出。
- Windows 10/11 大范围兼容、多屏负坐标、125%/150% DPI、虚拟桌面和特殊应用兼容仍需继续验收。
- 未执行的验收项明确保留为 `Not tested`，详见 [验收记录](docs/records/acceptance.md)。

## 直接运行

解压 `dist/WindowswindowsManager-0.1.0.zip`，保持 `WindowswindowsManager.exe` 与 `config.ini` 位于同一目录，然后运行：

```text
WindowswindowsManager.exe
```

- 程序默认在托盘中运行，不创建主窗口。
- 不需要管理员权限。
- 退出后不自动恢复已经完成的布局；需要恢复时使用 Undo。
- 开机启动只会在用户点击托盘菜单后写入当前用户注册表。

交付文件：

- `dist/WindowswindowsManager.exe`
- `dist/WindowswindowsManager-0.1.0.zip`
- `dist/SHA256SUMS.txt`

## 默认快捷键

| 动作 | 快捷键 |
|---|---|
| 暂停/恢复自动管理 | `Ctrl+Alt+Shift+P` |
| 重新排布当前显示器 | `Ctrl+Alt+Shift+L` |
| 撤销上次布局 | `Ctrl+Alt+Shift+Z` |
| 锁定/解锁当前窗口 | `Ctrl+Alt+Shift+K` |
| 重新放置当前窗口 | `Ctrl+Alt+Shift+O` |
| 重新加载配置 | `Ctrl+Alt+Shift+R` |

托盘菜单提供同样的操作，并增加“重新排布所有显示器”“打开日志”“开机启动”和“退出”。

## 布局行为

### 新窗口

- 可缩放的新窗口以工作区宽度的 65%、高度的 70% 为目标尺寸，并保留 16 px 安全边距。
- 自动模式分别计算“只动新窗口”和“协同移动少量已有窗口”两种方案。
- 只有协同方案达到 `MinimumQualityImprovementRatio`（默认 8%）且扰动约束满足时才会移动旧窗口。
- 自动模式默认最多移动 3 个已有窗口，默认不缩放已有窗口。
- 最近 5 秒内被用户移动或缩放的窗口，在自动模式中会被重点保留。

### 手动重排

- 默认只处理触发快捷键时活动窗口所在显示器。
- 包含脚本启动前已经存在的合格普通窗口。
- 使用原有布局和规则网格作为两个候选起点，再在有限时间预算内做确定性坐标下降。
- 手动模式默认允许在最小尺寸比例约束内缩放已有窗口。
- 所有显示器模式逐个显示器独立求解，不会跨屏搬运窗口。

### 锁定与保护

- 显式锁定窗口不会移动或缩放，但会作为其他窗口的障碍物。
- 正在拖动/缩放的窗口不会被布局覆盖。
- 最小化窗口、已有最大化窗口、系统窗口、拥有者对话框、cloaked 窗口和独占全屏窗口默认跳过。
- 不改变焦点、Z-order、置顶属性或最小化状态。

## 平滑移动

平滑移动默认开启，由 [config.ini](config.ini) 控制：

```ini
[Motion]
SmoothMovement=1
SmoothDurationMs=160
SmoothFrameIntervalMs=16
SmoothMaxDurationMs=260
```

执行器使用 SmoothStep 缓动，在约 16 ms 的帧间隔内同步插值所有发生变化窗口的位置和尺寸。最终几何会重新读回验证。用户开始拖动/缩放或窗口失效时，动画会立即停止，不会在取消后强行跳到目标位置。

关闭平滑移动后，执行器使用完全相同的最终目标，只是直接提交几何。

## 配置

默认配置位于 [config.ini](config.ini)。常用配置组：

- `[General]`：启用状态、DryRun、新窗口自动重排、最大化新窗口处理。
- `[WindowSize]`：新窗口比例、边距和最小缩放比例。
- `[AutoReflow]`：自动模式的质量阈值、旧窗口移动上限、去抖和冷却时间。
- `[ManualReflow]`：手动模式缩放和求解迭代约束。
- `[Placement]`：候选网格、求解预算和显示器策略。
- `[Motion]`：平滑移动开关、时长和帧间隔。
- `[Scoring]`：重叠、焦点、尺寸、移动、间距和中心倾向权重。
- `[Exclusions]`：按进程名或窗口类名排除。
- `[Hotkeys]`：AHK 快捷键字符串；`^`、`!`、`+` 分别表示 Ctrl、Alt、Shift。

配置值会做范围检查；缺失的键使用安全默认值。手动编辑后可按 `Ctrl+Alt+Shift+R` 重载。

## 从源码运行

已在 AutoHotkey v2.0.30 验证：

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey.exe' '.\main.ahk'
```

测试启动模式会强制 DryRun、禁用自动重排并在一秒内退出：

```powershell
& '.\dist\WindowswindowsManager.exe' '--smoke-test'
```

## 构建与测试

测试会短暂创建并移动独立的 AutoHotkey 测试窗口，不会操作其他应用的窗口：

```powershell
& '.\scripts\test.ps1'
```

构建 64 位可执行文件与发布压缩包：

```powershell
& '.\scripts\build.ps1'
```

本地构建脚本优先使用 `.tools/Ahk2Exe/Ahk2Exe.exe`，并以
`C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` 作为基础运行器。`.tools/` 和 `dist/` 不纳入 Git，但构建产物保留在工作区中供交付。

## 文档

- [任务定义](docs/requirements/task-definition.md)
- [原始任务书 v2](docs/requirements/original-spec-v2.md)
- [架构与平滑执行设计](docs/guides/architecture.md)
- [分阶段实施计划](docs/plans/implementation-plan.md)
- [本轮测试报告](docs/records/test-report-2026-10-23.md)
- [阶段与测试验收](docs/records/acceptance.md)
- [Windows 手动测试计划](docs/guides/manual-test-plan.md)
- [已知限制](docs/records/known-limitations.md)
- [改动记录](docs/records/change-log.md)
- [本地环境](docs/environment.md)

## 已知限制

- 当前测试环境只能代表本机 Windows build 26200；Windows 10、双屏负坐标、不同 DPI 和窗口较多的真实应用组合未完成全量验收。
- 虚拟桌面过滤目前依赖 DWM cloaked 判断；无法可靠区分时仍存在误操作风险，后续应接入 `IVirtualDesktopManager`。
- 应用最小/最大尺寸通常无法在外部精确读取，最终以 `SetWindowPos` 后的读回结果为准。
- `ManualIncludeMaximized=1` 目前只让最大化窗口进入障碍物计算，不会先恢复最大化状态。
- Undo 只保存在当前进程内，退出或重载脚本后清空。
- 未签名 `.exe` 可能触发 Windows SmartScreen 提示。
- 不默认提权，管理员窗口中可能无法修改。
