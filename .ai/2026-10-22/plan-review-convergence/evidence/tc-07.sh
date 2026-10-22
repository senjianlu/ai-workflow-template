#!/usr/bin/env bash
# TC-07 规则文本断言(含反向断言)
source "$(dirname "$0")/lib.sh"
chk() { if grep -qF -- "$2" "$ROOT/$1"; then ok "$1 含 $(printf %q "$2")"; else bad "$1 不含 $(printf %q "$2")"; fi; }
nchk() { if grep -qF -- "$2" "$ROOT/$1"; then bad "$1 不应含 $(printf %q "$2")"; else ok "$1 不含 $(printf %q "$2")"; fi; }
S=.ai-workflow/review-standards.md; P=.ai-workflow/prompts/plan-review.md
chk $S "若该问题留到实现阶段才被发现,是否需要推翻已"; chk $S "用例中意图明确的机械性错误"; chk $S "第 1、2 轮:全量穷尽评审"; chk $S "第 3 轮起:收敛评审"
chk $S "机械性更正"; chk $S "以更正后的文字为验收基准"; chk $S "擅自"
chk $P "{{ROUND_CONTEXT}}"; chk $P "架构与正确性"; chk $P "与既有约定的冲突"; chk $P "验收覆盖"; chk $P "证据契约"; chk $P "范围自省"
chk $P "不得在找到前几条后停止"; chk $P "先逐项核验上一轮的 plan-blocker/major"; chk $P "未修订部分**的新发现**只报 plan-blocker"; chk $P "不要求逐轮重复列出"
K=.claude/skills
chk $K/rawf-plan/SKILL.md "写作粒度"; chk $K/rawf-plan/SKILL.md "修订纪律"; chk $K/rawf-plan/SKILL.md "**默认 5 轮**"; chk $K/rawf-plan/SKILL.md "评审运行期间不得修改 plan.md"
chk $K/rawf-implement/SKILL.md "__minors"; chk $K/rawf-implement/SKILL.md "全部"; chk $K/rawf-implement/SKILL.md "回写 plan 测试表"; chk $K/rawf-implement/SKILL.md "〔机械性更正"; chk $K/rawf-implement/SKILL.md "放宽断言"
chk .ai-workflow/templates/implementation-round.md "## plan 评审 minor 交接"; chk .ai-workflow/templates/implementation-round.md "__minors"
chk CLAUDE.md "默认最多 5 轮"; chk CLAUDE.md "plan 评审 5 轮、实现层修复 3 轮"; chk AGENTS.md "默认最多 5 轮"
D=docs/decisions/0012-plan-review-convergence.md
for k in "- 日期:" "- 背景:" "- 决定:" "- 影响:"; do chk $D "$k"; done
chk docs/decisions/0001-plan-stage-review.md "0012-plan-review-convergence.md"
chk docs/decisions/0003-configurable-review-round-caps.md "部分被 0012 取代"
chk CHANGELOG.md "## [1.2.0]"; chk CHANGELOG.md "### 升级指引"
assert_eq "TEMPLATE-VERSION" "$(sed -n 's/^version: //p' "$ROOT/.ai-workflow/TEMPLATE-VERSION")" "1.2.0"
chk README.md "收敛评审"
nchk $K/rawf-plan/SKILL.md "**默认 3 轮**"; nchk AGENTS.md "plan-review,默认最多 3 轮"; nchk .ai-workflow/scripts/plan-review.sh "缺省 3"
finish
