---
task: relax-review-round-caps
round: 01
date: 2026-07-18
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| .ai-workflow/scripts/plan-review.sh | 新增 `resolve_max_rounds` 函数(只认 frontmatter 首块内行首 `plan_review_max_rounds:`;缺失→3;非正整数→stderr 报错返回 3)与 `__resolve_max_rounds` 测试入口;主流程上限由字面量 3 改为函数返回值,拒绝提示显示实际上限;顶部注释同步 |
| .claude/skills/rawf-plan/SKILL.md | 步骤 6:"最多 3 轮"改为"默认 3 轮";补充仅用户明确要求时写 `plan_review_max_rounds` 覆盖、须在摘要声明、不得自行/建议性写入 |
| .claude/skills/rawf-implement/SKILL.md | 前置检查:上限取 `impl_fix_max_rounds`,缺失或非正整数按默认 3;"NN > 3"改"NN > 上限";字段仅用户明确要求时写入 |
| .claude/skills/rawf-review/SKILL.md | 分流与上限比较(取值规则同 rawf-implement);"NN < 3 / NN = 3"改"NN < 上限 / NN ≥ 上限";补充用户中途追加轮数的更新与留痕规则 |
| CLAUDE.md | 第 1b、5 步改默认语义;硬规则新增"评审轮次上限默认均为 3 轮"条目(字段定义、防滥用、指向 0003) |
| AGENTS.md | 通用硬规则改"默认最多 3 轮,用户明确指定轮数时以其为准" |
| README.md | 工作流图示"最多 3 轮"改"默认最多 3 轮,用户可明确放宽" |
| docs/decisions/0001-plan-stage-review.md | 追加 2026-07-18 沿革条目,指向 0003 |
| docs/decisions/0003-configurable-review-round-caps.md | 新增决策记录:动机、字段载体、强制面、防滥用、被否备选(环境变量/脚本参数)、影响与残留风险 |

## 修复对照

(第 1 轮,不适用)

## 测试结果

| 编号 | 结果 | 证据 |
|---|---|---|
| TC-01 | 通过 | `plan-review.sh __resolve_max_rounds`(无字段 plan)→ 输出 3、exit 0;见 evidence/test-round-caps-output.txt |
| TC-02 | 通过 | 字段 5 → 输出 5、exit 0;同上 |
| TC-03 | 通过 | 字段 0 与 abc → 各 exit 3,stderr"…非法(须为正整数,实际为:0/abc)";同上 |
| TC-04 | 通过 | 字段仅在正文出现 → 仍输出 3(只认 frontmatter 块);同上 |
| TC-05 | 通过 | 假项目(CLAUDE_PROJECT_DIR)造 3 轮记录、无字段 → 主流程报"已达 3 轮上限"、exit 3,未触真实任务;同上 |
| TC-06 | 通过 | 同上但字段 5 + PATH 假 codex(exit 1)→ 不再报上限,死于"codex exec 执行失败"、exit 3,证明第 4 轮已放行;同上 |
| TC-07 | 通过 | `bash -n` 过;全仓 grep(排除 .ai/、.git/、docs/decisions 沿革)固定上限表述残留为零;同上 |
| TC-08 | 通过 | 两 skill 三项静态断言(字段来源 / 缺省与非法回退默认 3 / 达上限停止动作)全命中;同上 |
| TC-09 | 通过 | 5 场景走查逐条从 skill 文本唯一推导出预期分支;见 evidence/tc-09-scenario-walkthrough.md |

测试脚本副本:evidence/test-round-caps.sh(TC-05/06 在 scratchpad 假项目
中执行,未写入真实 `.ai/.current-task` 与任务目录)。

## 与方案的偏差

无。方案表格中 9 个文件全部改动,未动 review.sh 与 plan 模板,决策编号
按第 1 轮 plan 评审意见取 0003。
