# 本地环境记录

记录日期：2026-10-23（Asia/Shanghai）。

## 项目位置

| 项目 | 值 |
|---|---|
| 工作区 | `G:\Unknown_stuff\WindowswindowsManager` |
| Git 默认分支 | `main` |
| 文档目录 | `docs/` |

## 系统

| 项目 | 值 |
|---|---|
| Windows 版本号 | `10.0.26200.0` |
| 架构 | x64 |
| PowerShell | 7.6.5 |
| CPU | 13th Gen Intel Core i9-13900HX |
| 逻辑处理器 | 32 |
| 运行时可见内存 | 约 15.72 GB |
| GPU | NVIDIA GeForce RTX 5070 Ti Laptop GPU，12 GB |
| NVIDIA 驱动 | 610.62 |
| CUDA Toolkit | 13.0.48 |

## AutoHotkey

| 项目 | 值 |
|---|---|
| 用户提供的快捷方式 | `G:\AAA\code\AutoHotkey.lnk` |
| 快捷方式目标 | `C:\Program Files\AutoHotkey\UX\AutoHotkeyUX.exe` |
| UX 版本 | 2.0.30 |
| 推荐脚本运行器 | `C:\Program Files\AutoHotkey\v2\AutoHotkey.exe` |
| 脚本运行器版本 | 2.0.30 |
| 本地帮助文件 | `C:\Program Files\AutoHotkey\v2\AutoHotkey.chm` |
| Ahk2Exe | 1.1.37.02a2 |
| 本地编译器路径 | `.tools\Ahk2Exe\Ahk2Exe.exe`（不纳入 Git） |

用户要求最终交付可直接运行的 `.exe`。构建阶段已下载官方 Ahk2Exe 发布包到项目忽略目录，并以 AutoHotkey v2 64 位运行器成功生成 `dist/WindowswindowsManager.exe`。

## 工具

| 工具 | 版本/状态 |
|---|---|
| Git | 2.45.1 Windows.1 |
| Node.js | 24.14.1 |
| npm | 11.11.0 |
| Python | Miniconda base 3.11.14 |
| Rust | 1.95.0 |
| MinGW GCC/G++ | 8.1.0 |
| .NET | 6.0/8.0 运行时；未安装 SDK |
| CMake/Ninja | 未发现 |

## 环境限制

- Codex 当前沙箱内部分 WMI 查询被拒绝，因此系统信息使用了注册表、PowerShell 和 .NET 运行时可访问的数据。
- `conda info`/`conda env list` 在沙箱内因多进程管道权限失败；这不影响 AHK 项目，也不应被记录为 Conda 损坏。
- AHK 脚本、真实外部测试窗口、自动事件链和编译产物均已在当前环境完成受控测试。
