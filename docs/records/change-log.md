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
