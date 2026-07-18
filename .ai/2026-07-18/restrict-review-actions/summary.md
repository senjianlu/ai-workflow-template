---
task: restrict-review-actions
date: 2026-07-18
rounds: 1
verdict: pass
---

# 任务小结:实现层评审动作边界(静态检查 + 受限单元测试)

## 改动

| 文件 | 摘要 |
|---|---|
| .ai-workflow/review-standards.md | 新增「评审动作边界」小节(唯一权威):按命令性质判定(自终止 / 不起服务或长驻进程 / 不访问网络),单命令默认 5 分钟超时,混合套件只跑可限定的单元子集,禁止依赖安装 / build / 启动服务 / E2E / 网络,边界外用例改审 evidence/ 证据 |
| .ai-workflow/prompts/review.md | "实际运行 plan.md 中的测试用例"改为"边界内重跑、边界外审 evidence/ 证据并交叉比对",证据缺失/矛盾/虚报按 blocker |
| .claude/skills/rawf-implement/SKILL.md | 证据契约收紧:边界外用例完整原始输出必须评审前落 evidence/;"评审者会重跑验证"改为按边界分别重跑/审证 |
| docs/decisions/0004-review-action-boundary.md | 新增决策:边界定义、证据契约、被否备选 A(read-only 纯静态)、兜底(副本隔离 + 沙箱断网) |

## 评审历程

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| plan-01 | fail | R-01 证据契约未闭环(须纳入 rawf-implement);R-02 按运行器名划白名单不严谨 → 改按性质判定 + 超时 + 混合套件规则 |
| plan-02 | pass | 无问题 |
| impl-01 | pass | 无问题;评审者在新边界内重跑自测脚本,10 项检查全过 |

## 遗留 minor 及处置

无(评审问题清单为空)。
