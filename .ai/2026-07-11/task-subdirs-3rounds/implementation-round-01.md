---
task: task-subdirs-3rounds
round: 01
date: 2026-07-11
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/plan-review.sh` | 轮次闸 `-ge 2`→`-ge 3`;注释「2 轮机器上限/count>=2」与 stderr「已达 2 轮上限」同步为 3(唯一逻辑改动) |
| `CLAUDE.md` | ① 工作流 1b、硬规则区「最多 2 轮」→「最多 3 轮」;② 硬规则区新增「与用户沟通一律使用简体中文」(限面向用户的自然语言,不约束代码/注释) |
| `AGENTS.md` | ① 通用硬规则「plan-review,最多 2 轮」→ 3;② 目录约定表 `.ai/` 单元格补注每个任务目录含 `evidence/`、`assets/` |
| `.claude/skills/rawf-plan/SKILL.md` | ① 第 2 步建任务目录时一并建 `evidence/`、`assets/` 并各放 `.gitkeep`;② round 文字「最多 2 轮/2 轮上限」→ 3 |
| `.claude/skills/rawf-implement/SKILL.md` | 第 5 步补充:大体量证据落 `evidence/`、素材落 `assets/`,且须评审前落盘(`.ai/` 计入指纹) |
| `docs/decisions/0001-plan-stage-review.md` | 决定句 2→3,并追加 2026-07-11 修订说明记录放宽动机 |
| `docs/decisions/0002-task-evidence-assets-dirs.md` | 新增:记录 evidence/ + assets/ 子目录约定与「均入库」决定、落盘时机约束、残留风险 |
| `.ai-workflow/templates/plan.md` | 「风险与回滚」上方加注释,指引证据/素材落点 |

## 修复对照

（第 1 轮,无上一轮评审问题。plan 阶段评审 R-01/R-02 已在 plan.md 修订中处理，非本实现轮。）

## 测试结果

| 编号 | 结果 | 证据 |
|---|---|---|
| TC-01 | 通过 | `grep 'count" -ge 3' plan-review.sh` 命中;`grep -rnE '最多 2 轮\|2 轮上限\|-ge 2'` 于脚本/skills/docs/CLAUDE/AGENTS **无残留**(「第 2 轮」实现轮与 0001 修订说明属另一语义,已排除)。见 evidence/self-test-round-01.log |
| TC-02 | 通过 | `mkdir evidence assets` + `.gitkeep`;`git check-ignore` 对两 `.gitkeep` 均返回非 0(未被忽略,可入库) |
| TC-03（异常） | 通过 | 隔离临时工作区 + PATH 假 codex 桩,任务目录含 3 个 round 文件 → 脚本 exit 3、stderr「已达 3 轮上限」、标记文件不存在(codex 未被调用) |
| TC-04（放行） | 通过 | 同上,含 2 个 round 文件 → 假 codex 标记文件存在(被调用一次)、产出 `plan-review-round-03-pass.md`、无「3 轮上限」误报 |
| TC-05 | 通过 | 向 gate-plan.sh 喂 `.ai/<task>/evidence/x.log` 写入(draft 场景),hook exit 0 且无 deny 输出(走 `.ai/` 放行分支) |
| TC-06 | 通过 | `grep '与用户沟通一律使用简体中文' CLAUDE.md` 命中 |

自测汇总:PASS=13 FAIL=0(13 项断言覆盖 6 条用例)。测试脚本 evidence/run-tests.sh,日志 evidence/self-test-round-01.log。

## 与方案的偏差

无。8 个文件、逻辑改动点、测试方法均与 approved plan 一致。

注:自测脚本 TC-01 的 grep 断言在初次运行时过宽(匹配到「第 2 轮」等另一语义文本),
已在测试脚本内收紧为 `最多 2 轮|2 轮上限|-ge 2` 精确匹配——这是测试断言修正,
非产品实现改动,产品文件未因此改动。
