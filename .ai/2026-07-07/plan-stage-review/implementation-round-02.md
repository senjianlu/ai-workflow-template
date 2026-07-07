---
task: plan-stage-review
round: 02
date: 2026-07-07
---

# 实现记录:第 02 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `AGENTS.md`(改) | rawf 指针处补全 plan-review 语义:加"最多 2 轮"与"≤ 10 不强制",满足 TC-12 对 AGENTS.md 的验收要求 |
| `.claude/skills/rawf-plan/SKILL.md`(改) | plan 评审闸补明"(≤ 10 不走此闸)",使三处文档 ≤10 语义均显式 |
| (测试桩)`scratchpad/run-tests.sh` | 修正 TC-12:改为逐项校验三处文档均含 `>10 触发 / ≤10 不触发 / 确认闸之前 / 最多 2 轮`(此前对 AGENTS.md 断言写弱,是本轮 blocker 的直接成因) |

## 修复对照
| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| R-01 | blocker | TC-12 虚报:根因是①测试桩对 AGENTS.md 只查了 `>10`/`确认闸之前`,漏查 `≤10 不触发`/`最多 2 轮`;②AGENTS.md 实际缺这两项。已(a)在 AGENTS.md 补"最多 2 轮"与"≤ 10 不强制";(b)在 rawf-plan skill 补明"≤ 10 不走此闸";(c)把 TC-12 加严为逐项校验四项语义。重跑后 TC-12 真实通过,report 与实际一致。 |

## 测试结果
<!-- 全量重跑(隔离桩),非仅回归单条。 -->
| 编号 | 结果 | 证据 |
|---|---|---|
| TC-01 ~ TC-11、TC-13 | 通过 | 行为不变,全部复跑通过(见 round-01 记录,逻辑未改动) |
| TC-12(加严) | 通过 | `doc_ok` 逐项断言三处文档(rawf-plan skill / AGENTS.md / CLAUDE.md)均含 `>10`、`≤10`、`确认闸之前`、`2 轮`;命中 3/3 |

全量结果:PASS=14 FAIL=0。

## 与方案的偏差
- 无新增偏差。本轮仅修复 round-01 评审的 blocker(TC-12 虚报),未触碰
  plan-review.sh/schema/prompt 等核心逻辑,不顺手改无关代码。
- round-01 记录中的"AGENTS.md 落点"偏差仍成立且已被本轮补全内容覆盖:
  AGENTS.md 现同时含指针("细则见 CLAUDE.md")与 TC-12 所需的四项要点。
