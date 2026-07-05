---
task: batch-small-fixes
date: 2026-07-05
rounds: 2
verdict: pass
---

# 任务小结:批量小修(5 项)

## 改动

| 文件 | 摘要 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 实现轮计数改 nullglob 数组,无实现轮时正确 exit 3(修复前崩溃 rc=1 与"评审 fail"语义冲突) |
| `.claude/hooks/gate-plan.sh` | 项目外路径不再被误拦:词法与物理均在项目外的普通文件放行(如会话记忆);仓库内符号链接指向外部的路径仍走状态闸 |
| `README.md` | "开新项目"第 3 步措辞对齐模板现状 |
| `AGENTS.md` | 新增"Git 提交规范"章节;技术栈改两列表格 |

## 评审历程

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| 01 | fail | R-01(major):仓库内目录符号链接指向外部时,其下写入绕过状态闸 |
| 02 | **pass** | 上轮修复确认;遗留 1 条 minor(见下) |

## 遗留 minor 及处置

| 编号 | 内容 | 用户决定 |
|---|---|---|
| R-01(第 02 轮) | README.md:32 文案写 `review-standards.md`,应补全目录前缀为 `.ai-workflow/review-standards.md` | 本次修(用户确认,提交前已补全) |

## 备注

- 评审模型固定项经用户裁决移除(减少维护心智负担),已记入会话记忆。
- 自测 39/39(新增 B-01〜B-05,其中 B-05 为第 01 轮 R-01 的回归用例)。
