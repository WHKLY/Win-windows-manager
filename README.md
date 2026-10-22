# WindowswindowsManager

基于 AutoHotkey v2 与 Win32 API 的 Windows 智能浮动窗口编排器。

项目目标不是强制平铺，而是在尽量不打扰用户的前提下，合理放置新窗口、协同调整少量已有窗口，并支持用户主动重排当前显示器、锁定窗口和撤销最近一次布局。

## 当前状态

- 阶段：规划与工作区初始化
- 功能开发：**尚未开始**
- 源码：**尚未创建**
- 最终交付：源码、默认配置以及可直接运行的 `.exe`
- 测试：**尚未执行，所有验收项均为 `Not tested`**
- 当前门禁：完成初始提交后进入阶段 A；用户已明确授权开始构建

用户已明确要求“先不开始构建”。原始任务书要求直接实现，与本轮指令冲突时，以本轮“先规划和初始化”的指令为准。

## 文档

- [任务定义](docs/requirements/task-definition.md)
- [原始任务书 v2](docs/requirements/original-spec-v2.md)
- [分阶段实施计划](docs/plans/implementation-plan.md)
- [本地环境](docs/environment.md)
- [改动记录](docs/records/change-log.md)
- [阶段与测试验收](docs/records/acceptance.md)
- [文档索引与维护约定](docs/README.md)

## 目录约定

```text
WindowswindowsManager/
├── README.md
├── docs/                       # 所有说明、计划、设计与验收文档
│   ├── requirements/           # 原始规格与整理后的任务定义
│   ├── plans/                  # 分阶段实施计划
│   └── records/                # 改动文件记录与阶段验收
└── .gitignore                  # 本地生成物与敏感/临时文件规则
```

后续功能源码、配置和自动测试会在获得开发授权后，按照任务书建议单独放入 `main.ahk`、`lib/`、`tests/` 等目录；说明类文件仍统一保存在 `docs/`。

## 交付原则

- 原始需求与整理后的任务定义分开保存。
- 布局变换应支持短时、可取消的平滑移动，同时保持无焦点切换和无 Z-order 变更。
- 每个阶段都同步更新改动文件列表、验证命令、验收状态和残余风险。
- 只有取得实际测试证据后才能标记 `Passed`；未执行、无法执行或证据不足均标记 `Not tested`。
- 不默认提权，不抢占焦点，不改变 Z-order，不持续强制重排，不采集敏感窗口内容。
