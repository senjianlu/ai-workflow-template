#!/usr/bin/env bash
# TC-02 第 2 轮:仍为全量穷尽;给出上一轮评审路径与修订 diff
source "$(dirname "$0")/lib.sh"
new_proj; fake_codex fail; run_review; assert_eq "第 01 轮退出码" "$RC" "1"
# 修订行带 & 字样:验证注入前已关闭 bash 5.2 的 patsub_replacement(否则 & 会被改写为占位原文)
sed -i 's/^旧行$/新行 a \&\& b 2>\&1/' "$TD/plan.md"
fake_codex fail; run_review
assert_eq "第 02 轮退出码" "$RC" "1"
assert_eq "模式行" "$(mode_line)" "本轮模式:全量穷尽评审"
assert_contains "prompt" "$PROMPT" "$TASK/plan-review-round-01-fail.md"
assert_contains "prompt" "$PROMPT" '```diff'
assert_contains "diff" "$PROMPT" "-旧行"
assert_contains "diff" "$PROMPT" "+新行 a && b 2>&1"
assert_not_contains "diff" "$PROMPT" "{{ROUND_CONTEXT}}"
assert_contains "第 02 轮快照" "$(cat "$TD/.plan-review-raw-02.plan.md")" "新行"
assert_not_contains "prompt" "$PROMPT" "{{"
echo "--- 本轮上下文段:"; sed -n '/^## 本轮上下文/,/^## 严重度判据/p' <<<"$PROMPT"
finish
