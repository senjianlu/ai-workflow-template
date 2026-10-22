#!/usr/bin/env bash
# TC-01 首轮:快照与 plan 字节一致;模式为全量穷尽;无 diff、无上一轮;无占位残留
source "$(dirname "$0")/lib.sh"
new_proj; fake_codex fail; run_review
assert_eq "退出码" "$RC" "1"
assert_file "$TD/plan-review-round-01-fail.md"
assert_file "$TD/.plan-review-raw-01.plan.md"
if cmp -s "$TD/plan.md" "$TD/.plan-review-raw-01.plan.md"; then ok "快照与 plan.md 字节一致"; else bad "快照与 plan.md 不一致"; fi
assert_eq "模式行" "$(mode_line)" "本轮模式:全量穷尽评审"
assert_not_contains "prompt" "$PROMPT" '```diff'
assert_not_contains "prompt" "$PROMPT" "上一轮评审:"
assert_not_contains "prompt" "$PROMPT" "{{"
echo "--- 本轮上下文段:"; sed -n '/^## 本轮上下文/,/^## 严重度判据/p' <<<"$PROMPT"
finish
