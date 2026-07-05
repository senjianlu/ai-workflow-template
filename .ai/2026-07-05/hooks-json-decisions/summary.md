---
task: hooks-json-decisions
date: 2026-07-05
rounds: 1
verdict: pass
---

# 任务小结:hooks 决策输出现代化(JSON 替代 exit 2)

## 改动

| 文件 | 摘要 |
|---|---|
| `.claude/hooks/gate-plan.sh` | 拒绝改为 `permissionDecision: deny` JSON(jq 构造)+ exit 0;放行保持零输出,不输出 allow |
| `.claude/hooks/gate-review.sh` | 拦截改为 `{decision: block, reason}` JSON + exit 0;顺带修复既有潜伏崩溃:`ls\|wc` 计数在 set -e/pipefail 下无实现轮时以退出码 1 崩溃(旧接口靠"exit 1 被视为非阻塞"侥幸放行),改 nullglob 数组计数,评审文件存在性判断同改数组 |

## 评审历程

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| 01 | **pass** | 无。评审者独立复跑 34 项测试全通过 |

## 遗留 minor 及处置

评审遗留 minor:无。

**范围外发现(实现记录偏差第 3 条,待用户处置)**:review.sh:25 存在同型
`ls|wc` 计数,无实现轮时脚本会在到达"尚无实现记录 exit 3"之前以 ls 的退出
码 1 崩溃,与"评审结论 fail"的退出码语义冲突。本任务 plan 明确不动
review.sh,故未修。用户决定:本次修 / 记入后续任务 / 放弃。

## 备注

- gate-review 首次纳入驱动测试覆盖(GR-01〜GR-04:block JSON、已评审放行、
  stop_hook_active 防循环、三种无任务状态)。
- 自测 34/34;真机侧:实现期间全部 Write/Edit 实际经过新 gate-plan 放行路径。
