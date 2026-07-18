---
task: relax-review-round-caps
date: 2026-07-18
rounds: 2
verdict: pass
---

# 任务小结:评审轮次上限改为可由用户放宽的默认值

## 改动
| 文件 | 摘要 |
|---|---|
| .ai-workflow/scripts/plan-review.sh | 上限由硬编码 3 改为 `resolve_max_rounds` 解析 plan.md frontmatter 的 `plan_review_max_rounds`(字段未出现→缺省 3;出现但非正整数含空值→exit 3);加 `__resolve_max_rounds` 测试入口 |
| .claude/skills/rawf-plan/SKILL.md | plan 评审"最多 3 轮"改默认语义;字段仅用户明确要求时写入并须在摘要声明 |
| .claude/skills/rawf-implement/SKILL.md | 修复轮上限取 `impl_fix_max_rounds`(缺失/非法→默认 3),"NN > 3"改"NN > 上限" |
| .claude/skills/rawf-review/SKILL.md | 分流改与上限比较;补用户中途追加轮数的更新与留痕规则 |
| CLAUDE.md | 工作流 1b、5 步改默认语义;硬规则新增轮次上限条目(字段定义、防滥用、指向 0003) |
| AGENTS.md | 通用硬规则改"默认最多 3 轮,用户明确指定时以其为准" |
| README.md | 工作流图示同步默认语义 |
| docs/decisions/0001-plan-stage-review.md | 追加 2026-07-18 沿革条目 |
| docs/decisions/0003-configurable-review-round-caps.md | 新增决策:机制、防滥用约束、被否备选(环境变量/脚本参数) |

## 评审历程
| 轮次 | 结论 | 关键问题 |
|---|---|---|
| plan-01 | fail | 新决策编号 0002 与既有文件冲突 → 改 0003 |
| plan-02 | fail | README.md 固定表述未纳入范围;修复轮上限缺可复核验证 → 扩范围、增 TC-08/09 |
| plan-03 | pass | 无问题 |
| impl-01 | fail | R-01 空值被误判为缺省;R-02 测试脚本硬编码仓库路径 |
| impl-02 | pass | 两项 major 修复确认,12 项检查全过,无遗留 |

## 遗留 minor 及处置
无(最后一轮评审问题清单为空)。
