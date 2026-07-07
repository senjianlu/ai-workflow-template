---
task: plan-stage-review
round: 01
date: 2026-07-07
---

# 实现记录:第 01 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/schemas/plan-review.schema.json`(新增) | plan 评审输出 schema;severity 枚举 `plan-blocker\|major\|minor`(无 blocker) |
| `.ai-workflow/prompts/plan-review.md`(新增) | plan 评审指令;评审对象为 plan.md,硬约束"只列返工/架构级问题",指向 review-standards.md 权威 |
| `.ai-workflow/scripts/plan-review.sh`(新增) | 只读跑 codex 评审 plan.md;轮次 count+1、2 轮机器上限;交叉校验(plan-blocker/major→fail);渲染+发布封装为 `publish_round` 函数(可控测试点);退出码 0/1/3 |
| `.ai-workflow/review-standards.md`(改) | 新增"plan 阶段评审(plan-review)语义"小节,分域界定:原判定规则限实现层评审;plan 阶段 plan-blocker/major 均计入 fail |
| `.claude/skills/rawf-plan/SKILL.md`(改) | 起草与确认闸之间插入"plan 评审闸"(仅 >10 文件),含分流与 2 轮上限;步骤重编号 |
| `AGENTS.md`(改) | 通用硬规则 rawf 指针处补一句:>10 文件确认闸前须经 plan 评审,细则见 CLAUDE.md |
| `CLAUDE.md`(改) | 开发工作流插入 1b 步;硬规则新增 >10 文件强制 plan 评审条目 |
| `.gitignore`(改) | 忽略 `.plan-review-raw-*` 与 `.plan-review-out-*` |

## 修复对照
<!-- 第 1 轮无上轮评审;plan 阶段两轮 Codex 评审的问题已在 plan.md 定稿前解决,非实现层修复。 -->
| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| （无实现层上轮） | — | 第 1 轮实现,无 review-round fail 待修 |

## 测试结果
<!-- 用 PATH 上的 codex 桩确定性执行,隔离于临时 CLAUDE_PROJECT_DIR;桩脚本与用例见 scratchpad/run-tests.sh。 -->
| 编号 | 结果 | 证据 |
|---|---|---|
| TC-01 pass | 通过 | RC=0;生成 `plan-review-round-01-pass.md` 含 `VERDICT: pass`;`.plan-review-lock` 已清理 |
| TC-02 fail | 通过 | RC=1;生成 `plan-review-round-01-fail.md` |
| TC-02b 排序 | 通过 | 乱序输入(minor/plan-blocker/major)渲染后实际行序 = `plan-blocker,major,minor` |
| TC-03 无 plan.md | 通过 | RC=3;stderr "plan.md 不存在";无评审文件 |
| TC-04 多轮 | 通过 | 已存在 round-01 时生成 `plan-review-round-02-pass.md`,RC=0 |
| TC-05 轮次上限 | 通过 | 已存在 01+02 时 RC=3;stderr "2 轮上限";无 round-03 |
| TC-06 交叉校验 | 通过 | verdict=pass 但含 major → RC=3 "矛盾";不发布 -pass.md |
| TC-07 并发锁 | 通过 | 预置锁 → RC=3 "评审在进行中";锁未被误删 |
| TC-08 codex 失败 | 通过 | 桩 exit 7 → RC=3 "codex exec 执行失败";无评审文件 |
| TC-09 退出0无输出 | 通过 | 桩 exit 0 不写输出 → RC=3 "未产出评审输出" |
| TC-10 非法JSON | 通过 | 桩写非 JSON → RC=3 "不是合法 JSON";`.plan-review-raw-01.json` 保留 |
| TC-11 发布冲突 | 通过 | `__publish_round` 直调,目标预置占位 → RC=3 "并发发布";原文件内容 `ORIGINAL` 未变 |
| TC-12 文档语义 | 通过 | rawf-plan skill / AGENTS.md / CLAUDE.md 均含 >10 触发、确认闸之前、2 轮语义 |
| TC-13 静态检查 | 通过 | `bash -n` 通过;schema 合法且 severity 枚举为三值 |

全部 14 条通过(PASS=14 FAIL=0)。自测中发现并修复的两处问题记于"与方案的偏差"。

## 与方案的偏差
1. **AGENTS.md 编辑位置**:plan 原写"AGENTS.md 工作流第 1 步补一行",但磁盘
   实际 AGENTS.md **无编号工作流章节**(工作流细则在 CLAUDE.md,AGENTS.md 仅
   在"通用硬规则"留 rawf 指针并声明"细则见 CLAUDE.md")。据实改为在该 rawf
   指针处补一句、保持"细则见 CLAUDE.md"的委派不重复细节。影响:范围不变,
   仍为 8 文件;仅落点调整,不涉及架构/接口。
2. **实现中修复的脚本 bug(自测发现)**:初版把主流程包进 `main()` 且 `lock`
   声明为 `local`,而 `trap ... EXIT` 在 main 返回后于全局作用域执行、此时
   `lock` 未定义,`set -u` 报 unbound variable 把 pass 的退出码 0 篡改为 1。
   改为参照 review.sh 的扁平写法(主流程置顶层、lock 为全局),保留
   render_review/publish_round 两函数与 `__publish_round` 测试入口。已由
   TC-01/TC-04 覆盖回归。
3. **测试用例编号**:plan 表中列了 TC-01…TC-13 共 13 项,实现时把"排序置顶"
   从 TC-02 拆出为独立 TC-02b(plan 的 R-05 要求单独验证排序),故实际执行
   14 条。属测试细化,不减少覆盖。
