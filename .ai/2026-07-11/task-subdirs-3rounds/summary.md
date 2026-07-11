---
task: task-subdirs-3rounds
date: 2026-07-11
rounds: 2
verdict: pass
---

# 任务小结:plan 评审轮次上限 2→3;任务目录增设 evidence/ 与 assets/;新增简体中文沟通硬规则

## 改动

| 文件 | 摘要 |
|---|---|
| `.ai-workflow/scripts/plan-review.sh` | 轮次闸 `-ge 2`→`-ge 3`,注释与 stderr 同步(唯一逻辑改动) |
| `CLAUDE.md` | 轮次「最多 2 轮」→ 3(2 处);硬规则区新增「与用户沟通一律使用简体中文」 |
| `AGENTS.md` | 轮次表述 → 3;目录约定表 `.ai/` 补注含 `evidence/`、`assets/` |
| `.claude/skills/rawf-plan/SKILL.md` | 第 2 步建任务目录时一并建 `evidence/`、`assets/` + `.gitkeep`;轮次文字 → 3 |
| `.claude/skills/rawf-implement/SKILL.md` | 第 5 步补充证据/素材落点与评审前落盘约束 |
| `docs/decisions/0001-plan-stage-review.md` | 决定句 2→3 + 追加 2026-07-11 修订说明 |
| `docs/decisions/0002-task-evidence-assets-dirs.md` | 新增:evidence/ + assets/ 子目录约定与「均入库」决定 |
| `.ai-workflow/templates/plan.md` | 加注释指引证据/素材落点 |

范围外还原(修评审 R-01):`.claude/settings.json` `git checkout HEAD` 还原,清除会话自动写入的个人授权污染(不入库)。

## 评审历程

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| plan-review 01 | fail | R-01 TC-04 测试设计被前置检查干扰;R-02 简体中文规则超范围夹带 → plan 内修订 |
| plan-review 02 | pass | 无 |
| review 01 | fail | R-01 settings.json 混入计划外个人授权;R-02 证据脚本硬编码工作区路径且无 fail-fast |
| review 02 | pass | 无 |

实现修复轮:round 01(按 plan 实现)、round 02(修 review R-01/R-02)。

## 遗留 minor 及处置

无遗留 minor(review-round-02 问题清单为空)。

## 覆盖限制(告知,非缺陷)

`review.sh` 的评审 diff 排除 `.claude/`(为规避 settings.local.json 并发写入),
故本任务 2 个 skill 文件(rawf-plan、rawf-implement)未进入 Codex 评审范围;
其正确性由自测 TC-01(轮次文字一致性)与人工核对保证。
