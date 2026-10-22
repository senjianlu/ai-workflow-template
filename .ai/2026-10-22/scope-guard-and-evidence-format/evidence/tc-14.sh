#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
W="$ROOT/.ai-workflow"; K="$ROOT/.claude/skills"
chk() { if grep -qF -- "$2" "$1"; then ok "$(basename "$1") 含 $(printf %q "$2")"; else bad "$(basename "$1") 不含 $(printf %q "$2")"; fi; }
nchk() { if grep -qF -- "$2" "$1"; then bad "$(basename "$1") 不应含 $(printf %q "$2")"; else ok "$(basename "$1") 不含 $(printf %q "$2")"; fi; }
chk "$W/prompts/review.md" "{{EVIDENCE_REPORT}}"; chk "$W/prompts/review.md" "## 范围核对(固定问题)"; chk "$W/prompts/review.md" "scope_findings"
chk "$W/prompts/plan-review.md" "范围自省(固定问题)"; chk "$W/prompts/plan-review.md" "scope_findings"
# 旧 A 档主规则("evidence/ 中须有该用例的完整原始输出;缺失或不完整 → blocker")已移除;
# "缺失或不完整 → blocker"字样仅保留在历史任务(未经机器核验)的兜底条款里
nchk "$W/review-standards.md" "中须有该用例的完整原始输出"
chk "$W/review-standards.md" "rawf-evidence v1 格式"; chk "$W/review-standards.md" "两种留证写法"; chk "$W/review-standards.md" "## 范围核对(不计入 pass/fail)"
chk "$W/templates/plan.md" "evidence_format: v1"; chk "$W/templates/plan.md" "## 需求原文"; chk "$W/templates/plan.md" "## 非目标"
chk "$W/templates/implementation-round.md" "收窄"; chk "$W/templates/implementation-round.md" "替代"; chk "$W/templates/implementation-round.md" "追加"; chk "$W/templates/implementation-round.md" "## 停车场"
chk "$W/templates/summary.md" "## 范围核对"
chk "$K/rawf-plan/SKILL.md" "范围自省"; chk "$K/rawf-plan/SKILL.md" "需求原文"
chk "$K/rawf-implement/SKILL.md" "evidence.sh"; chk "$K/rawf-implement/SKILL.md" "evidence-check"; chk "$K/rawf-implement/SKILL.md" "停车场"
chk "$K/rawf-review/SKILL.md" "证据核验未通过"; chk "$K/rawf-review/SKILL.md" "范围核对"
chk "$K/rawf-report/SKILL.md" "停车场"; chk "$K/rawf-report/SKILL.md" "范围核对"
chk "$ROOT/CLAUDE.md" "evidence.sh"; chk "$ROOT/CLAUDE.md" "追加类偏差不得自行实现"
finish
