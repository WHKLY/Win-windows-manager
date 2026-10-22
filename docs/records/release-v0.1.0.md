# Release v0.1.0

## 发布信息

| 项目 | 内容 |
|---|---|
| 产品 | Win-windows-manager |
| 版本 | 0.1.0 |
| Tag | `v0.1.0` |
| 仓库 | `Win-windows-manager`（public） |
| 状态 | 已准备本地提交和标签；等待用户授权 push |

## 发布资源

| 文件 | 用途 |
|---|---|
| `dist/Win-windows-manager-v0.1.0.exe` | 可执行程序和嵌入图标 |
| `dist/Win-windows-manager-v0.1.0.zip` | exe、默认配置、README、文档和校验文件 |
| `assets/Win-windows-manager.png` | 图标源文件 |
| `assets/Win-windows-manager.ico` | 应用与托盘多尺寸图标 |

EXE SHA-256：

```text
bbd9bf4008183dd7fb5cbe10a4b355e9b82be6c6c1a5c8e4f3d2da893861a26b
```

## 验证

- 全量 46 项自动/受控集成检查通过。
- 运行日志检查无 WARN 或 ERROR。
- exe 冒烟测试退出码 0。
- ProductName、FileDescription 和版本资源正确。
- exe 关联图标已提取确认。
- 编译版托盘图标加载无警告。
- 发布 ZIP 保留 exe、`config.ini`、README、文档和 SHA-256 校验文件。

## GitHub Release

用户确认 push 后：

1. 推送 `main` 和 `v0.1.0` tag。
2. 创建 GitHub Release `v0.1.0`。
3. 上传 `Win-windows-manager-v0.1.0.exe` 和 `Win-windows-manager-v0.1.0.zip`。
