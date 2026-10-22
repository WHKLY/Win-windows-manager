# 改动记录

本文件记录每次任务修改了哪些文件、为什么修改以及做了哪些验证。功能测试结果另行记录在 `acceptance.md`。

## 2026-10-23：工作区与需求基线初始化

阶段：G0

状态：文档与 Git 初始化完成；功能实现未开始。

| 文件 | 变化 | 用途 |
|---|---|---|
| `Windows_Smart_Window_Placement_AHKv2_Agent_Spec_v2.md` → `docs/requirements/original-spec-v2.md` | 移动并保持内容不变 | 将用户原始需求归档到统一文档目录 |
| `docs/requirements/task-definition.md` | 新增 | 明确目标、P0 范围、非目标、完成定义和待确认事项 |
| `docs/plans/implementation-plan.md` | 新增 | 固定阶段 A-E 的工作项、退出条件和重点验收 |
| `docs/environment.md` | 新增 | 记录 Windows、AutoHotkey、Git 与本地工具环境 |
| `docs/README.md` | 新增 | 说明文档目录结构、命名与维护规则 |
| `docs/records/change-log.md` | 新增 | 记录改动文件和验证情况 |
| `docs/records/acceptance.md` | 新增 | 维护阶段验收及 T01-T26 测试状态 |
| `README.md` | 新增 | 提供项目目标、当前状态和文档入口 |
| `.gitignore` | 新增 | 排除日志、构建、编辑器和临时文件 |
| `.gitattributes` | 新增 | 固定文档与 AHK/配置文件的默认换行策略 |
| `.editorconfig` | 新增 | 统一 UTF-8、缩进和换行规则 |

用户追加决策：

- 最终交付物必须包含可直接运行的 `.exe`。
- 窗口移动必须支持平滑过渡，并可通过配置关闭。
- 完成初始提交后立即开始阶段 A 构建。

验证：

- 原始规格已完整读取，共 625 行。
- AutoHotkey 运行器实际版本确认为 2.0.30。
- 本轮未创建功能源码，未运行功能测试或真机布局测试。
- 验收状态统一保持为 `Not started` 或 `Not tested`。

## 2026-10-23：v0.1.0 MVP 构建

阶段：A-D 主流程实现，E 兼容性验收进行中。

| 文件 | 变化 | 用途 |
|---|---|---|
| `main.ahk` | 新增 | AHK v2 入口、DPI 设置、异常处理和编译元数据 |
| `config.ini` | 新增 | 自动/手动策略、平滑移动、评分、撤销、排除和快捷键 |
| `lib/Geometry.ahk` | 新增 | 矩形、边界、相交、插值和缓动 |
| `lib/Config.ahk` | 新增 | 配置读取、默认值和范围校验 |
| `lib/Logger.ahk` | 新增 | 脱敏日志 |
| `lib/WindowEvents.ahk` | 新增 | WinEvent hook 生命周期 |
| `lib/WindowRegistry.ahk` | 新增 | 窗口身份、分类、显示器、锁定和交互状态 |
| `lib/LayoutPlanner.ahk` | 新增 | 自动协同、手动联合优化、评分和预算控制 |
| `lib/LayoutExecutor.ahk` | 新增 | 预检查、平滑帧执行、最终读回和取消 |
| `lib/LayoutHistory.ahk` | 新增 | 布局前快照与历史 |
| `lib/WindowManagerApp.ahk` | 新增 | 触发控制、托盘、快捷键、日志、Undo 和自启 |
| `scripts/test.ps1` | 新增 | 统一测试入口 |
| `scripts/build.ps1` | 新增 | 编译 exe、复制配置/文档、生成 SHA-256 和 zip |
| `tests/run_tests.ahk` | 新增 | 18 项纯逻辑测试 |
| `tests/motion_integration.ahk` | 新增 | 11 项真实测试窗口平滑动画测试 |
| `tests/window_registry_integration.ahk` | 新增 | 7 项真实外部窗口分类和移动测试 |
| `tests/new_window_integration.ahk` | 新增 | 新窗口事件到 DryRun 布局的集成测试 |
| `tests/manual_undo_integration.ahk` | 新增 | 锁定、手动重排与 Undo 集成测试 |
| `tests/app_smoke.ahk` | 新增 | 启动窗口、热键、日志和退出冒烟测试 |
| `tests/helpers/window_host.ahk` | 新增 | 隔离测试窗口宿主 |
| `README.md` | 重写 | 运行、配置、平滑移动、构建和限制说明 |
| `docs/guides/architecture.md` | 新增 | 模块和事务/动画设计 |
| `docs/guides/manual-test-plan.md` | 新增 | T01-T26 与 S01-S05 手动验收步骤 |
| `docs/records/test-report-2026-10-23.md` | 新增 | 自动测试、编译和 exe 冒烟证据 |
| `docs/records/known-limitations.md` | 新增 | 当前兼容性和安全限制 |
| `docs/records/acceptance.md` | 更新 | 自动化、阶段和真机验收状态 |
| `.gitignore` | 更新 | 忽略 `.tools/` 与测试运行目录 |

验证：

- `scripts/test.ps1` 退出码 0。
- 18 项 Core、11 项 Motion、7 项 Registry、1 项新窗口、5 项手动/Undo、1 项启动检查通过。
- 编译产物 `dist/WindowswindowsManager.exe` 以 `--smoke-test` 启动，退出码 0。
- 详细结果见 `docs/records/test-report-2026-10-23.md`。

## 2026-10-23：窗口事件稳定性修复

阶段：真实日志诊断与回归。

复现症状：

- 日志反复出现 `Expected a Number but got a String`，`extra` 为 `hwnd:pid` 形式的窗口身份键。
- 日志反复出现 `new_window_queue_full`。
- 部分销毁事件在 `WinGetClass` 处产生 `Target window not found`。

根因：

1. `WindowRegistry.CompareWindows` 使用 `<`/`>` 比较非纯数字的窗口身份字符串，AHK 尝试数字转换并抛出异常。
2. 每个新窗口事件都重新安排去抖定时器，持续事件流会不断推迟处理，最终造成队列溢出。
3. 同一 `ProcessNewCandidates` 回调可能堆叠重入，放大窗口销毁竞态。

修复：

- 全部窗口身份排序改用 `StrCompare`。
- `CREATE` 事件不再直接入队，只在窗口 `SHOW` 时登记。
- 首个候选只安排一次处理定时器，后续事件不重置；回调开始时清除调度标志。
- 待处理上限从 64 提升到 256；队列满时不再把窗口永久标记为已处理。
- `WinGetClass` 和进程名读取增加窗口消失的局部异常处理。

新增回归：

- `tests/window_churn_regression.ahk`：200 个窗口分批创建/销毁。
- `tests/window_destroy_race_regression.ahk`：960 个短生命周期窗口触发分类/销毁边界。
- 两个压力场景结果均为 `queue_full=0`、`window_not_found=0`、`other_uncaught=0`。

修复后初步真实使用验证：

- 用户使用修复版 exe 完成自动放置、协同重排和手动重排。
- 检查时间范围内的 48 行新增日志：0 ERROR、0 WARN、0 队列溢出。
- 记录 38 次实际布局、11 次协同重排、7 次手动重排、6 次“当前布局已较优”。
- 用户确认初步测试通过。

## 2026-10-23：v0.1.0 发布前整理

- 产品、公开仓库和发布资源名称统一为 `Win-windows-manager`。
- 发布 exe 命名为 `Win-windows-manager-v0.1.0.exe`。
- 新增 `assets/` 图标源文件和 ICO 生成脚本。
- exe 构建时通过 Ahk2Exe 嵌入应用图标。
- 源码运行从 `assets/` 加载托盘图标，编译版从 exe 嵌入资源加载。
- 托盘提示、启动提示和开机启动注册表值更新为新产品名称。
- 日志文件更名为 `win-windows-manager.log`。

## v0.1.1：双击 CapsLock 重排快捷键

- 新增 `lib/DoubleTapGesture.ahk`，独立处理双击时间窗口。
- 注册 `~CapsLock`，保留单击 CapsLock 的大小写切换行为。
- 在按下事件计时，通过短定时器等待真实松开并过滤长按重复。
- 默认双击间隔为 500 ms，可在 `[Hotkeys] DoubleCapsIntervalMs` 调整。
- 增加开关 `EnableDoubleCapsReflow`。
- 按住 Ctrl、Alt、Shift 或 Win 时不会触发。
- 新增双击逻辑单元测试和集成测试。
- 该快捷键不包含在已发布的 `v0.1.0` 中。

## v0.1.1：高刷新率平滑动画

- 动画循环从 16 ms 的普通 `Sleep` 改为 QPC 微秒时钟调度。
- 使用 Windows 高分辨率可等待定时器，绕开当前环境约 15.6 ms 的 `Sleep` 粒度。
- 默认帧间隔从 16 ms 调整为 8 ms，目标约 120 FPS。
- 漏帧时重新建立下一帧时间点，不连续补帧造成抖动。
- 新增 5 窗口真实动画性能回归。
- 多次测试约 123.8–124.7 FPS，最大帧间隔 9.1–11.6 ms；优化前约 57–64 FPS、最大约 31 ms。

## v0.1.1：双击 CapsLock 处理全屏窗口

- 双击 CapsLock 的专用入口会检测当前显示器上的全屏和最大化窗口。
- 最大化窗口先异步恢复；非最大化全屏窗口以 `allowFullscreen` 分类进入规划。
- 全屏/最大化窗口与所有普通合格窗口共同参与手动联合重排。
- 保留 Topmost、焦点和 Z-order，不解除置顶属性。
- 普通手动快捷键和托盘重排行为不变。
- 新增 Topmost 最大化窗口 + 普通窗口的真实集成测试。

## v0.1.1：覆盖率与更积极的自动布局

- 评分新增工作区覆盖率，默认目标 90%，权重 4。
- 覆盖率通过窗口并集面积计算，避免把重叠面积重复计入。
- 手动网格改为填充单元格，并允许窗口在 0.70–1.30 倍原尺寸范围内调整。
- 自动模式允许已有窗口在 0.80–1.20 倍原尺寸范围内调整。
- 自动模式移动已有窗口上限从 3 调整为 6，协同收益门槛从 8% 调整为 4%。
- 近期被用户移动/缩放的窗口不再从自动候选集合排除，并取消额外移动成本。
- 正在拖动/缩放的窗口仍然完全不受布局接管。
- 新增覆盖率和更多自动协同规划测试。
- 网格枚举 1 到 N 列并选择覆盖率最高的布局；5 窗口测试覆盖从 57.63% 提升到 88.72%。

## 2026-10-23：v0.1.1 发布准备

- ProductVersion 和托盘版本文本更新为 `0.1.1`。
- 发布 exe 更新为 `Win-windows-manager-v0.1.1.exe`。
- 发布 ZIP 更新为 `Win-windows-manager-v0.1.1.zip`。
- 新增 `docs/records/release-v0.1.1.md`。
- exe SHA-256：`3bb1237a8a4702ff9e4437a3d9486ff48cf90d92cf6d6b5a7f37aabbe9bbe5b0`。
- v0.1.1 使用 annotated tag，完整回归共 74 项。
