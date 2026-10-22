# 测试报告：2026-10-23

## 环境

| 项目 | 值 |
|---|---|
| Windows build | `10.0.26200.0` x64 |
| AutoHotkey | 2.0.30 x64 |
| Ahk2Exe | 1.1.37.02a2 |
| 编译基础运行器 | `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` |
| 工作区 | `G:\Unknown_stuff\WindowswindowsManager` |

## 自动测试

执行命令：

```powershell
& '.\scripts\test.ps1'
```

最终结果：退出码 `0`，全部测试套件通过。

| 套件 | 数量 | 结果 | 覆盖内容 |
|---|---:|---|---|
| AHK 语法 | 1 | Passed | `main.ahk` 及全部 Include 可解析 |
| Core | 30 | Passed | 矩形、边界、平滑插值、双击手势、覆盖率、近期调整零额外成本、自动协同与缩放候选、确定性、单窗口放置、固定尺寸 |
| Motion | 11 | Passed | 中间帧、最终几何、即时模式、焦点、Z-order、取消路径 |
| Motion Performance | 1 | Passed | 5 窗口 300 ms 动画多次约 123.8–124.7 FPS，最大帧间隔 9.1–11.6 ms |
| Registry | 7 | Passed | 独立外部进程窗口识别、显示器归属、锁定/解锁、真实移动 |
| New window | 1 | Passed | WinEvent -> 去抖 -> 分类 -> DryRun 规划日志 |
| Manual/Undo | 5 | Passed | 手动锁定保护、真实手动移动、Undo 恢复原几何 |
| Double CapsLock | 1 | Passed | `~CapsLock` 注册、慢速双按不触发、快速双按触发一次 |
| Fullscreen Double CapsLock | 14 | Passed | Topmost 最大化窗口与普通窗口共同恢复、缩小和重排 |
| Window churn | 1 | Passed | 200 个窗口分批创建/销毁，无队列溢出或未捕获错误 |
| Destroy race | 1 | Passed | 960 个短生命周期窗口，分类与销毁边界无异常 |
| Startup | 1 | Passed | 已存在窗口启动不移动、默认热键注册、日志、安全退出 |

合计 74 项自动/受控集成检查通过。

测试日志检查结果：测试运行目录内无 `WARN` 或 `ERROR` 条目。

## 编译产物

构建命令：

```powershell
& '.\scripts\build.ps1'
```

产物：

| 文件 | 大小 | 结果 |
|---|---:|---|
| `dist/Win-windows-manager-v0.1.1.exe` | 1,438,720 bytes | 已生成 |
| `dist/Win-windows-manager-v0.1.1.zip` | 随文档变化 | 已生成 |

可执行文件 SHA-256：

```text
3bb1237a8a4702ff9e4437a3d9486ff48cf90d92cf6d6b5a7f37aabbe9bbe5b0
```

版本资源：

- ProductName: `Win-windows-manager`
- FileDescription: `Win-windows-manager - smooth Windows window layout manager`
- FileVersion/ProductVersion: `0.1.1.0`

编译产物冒烟测试：

```powershell
& '.\dist\Win-windows-manager-v0.1.1.exe' '--smoke-test'
```

结果：退出码 `0`；日志确认 `compiled=1`、`dry_run=1`、`smoke_test=1`，并正常执行退出清理。

图标验证：

- `assets/Win-windows-manager.ico` 包含 16、24、32、48、64、128、256 px。
- 从编译后的 exe 成功提取出关联图标，视觉内容与源图一致。
- 编译版启动日志无 `tray_icon_load_failed` 或其他 WARN/ERROR。

## 初步真实使用验证

用户使用修复版程序进行实际桌面操作，随后对修复版进程新增日志进行统计：

| 指标 | 结果 |
|---|---:|
| 检查日志行数 | 48 |
| ERROR | 0 |
| WARN | 0 |
| 队列溢出 | 0 |
| 实际布局次数 | 38 |
| 协同重排次数 | 11 |
| 手动重排次数 | 7 |
| “当前布局已较优”次数 | 6 |

用户确认初步测试通过。该结论只覆盖本次真实使用范围，不替代尚未执行的 T01-T26 全量兼容矩阵。

## 未覆盖范围

- 未对真实用户常用的 5 个杂乱应用窗口执行全量自动验收。
- 未模拟拔插显示器、125%/150% DPI、双屏负坐标。
- 未验证跨虚拟桌面窗口的可靠过滤。
- 未进行应用拒绝调整几何、UWP 特殊窗口、全屏游戏和管理员权限窗口测试。
- 未执行长时间空闲 CPU、资源占用和压力测试。

这些项目保留为 `Not tested`，不应根据本报告推断为已兼容。
