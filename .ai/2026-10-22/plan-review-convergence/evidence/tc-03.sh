#!/usr/bin/env bash
# TC-03 第 3 轮:收敛评审;diff 只含第 02 轮以来的修订
source "$(dirname "$0")/lib.sh"
new_proj; fake_codex fail; run_review
sed -i 's/^旧行$/新行/' "$TD/plan.md"; fake_codex fail; run_review
sed -i 's/^新行$/第三行/' "$TD/plan.md"; fake_codex pass; run_review
assert_eq "第 03 轮退出码" "$RC" "0"
assert_eq "模式行" "$(mode_line)" "本轮模式:收敛评审"
assert_contains "prompt" "$PROMPT" "$TASK/plan-review-round-02-fail.md"
assert_contains "diff" "$PROMPT" "-新行"
assert_contains "diff" "$PROMPT" "+第三行"
assert_not_contains "diff" "$PROMPT" "-旧行"
assert_contains "prompt" "$PROMPT" '即本轮的"修订部分"'
assert_file "$TD/plan-review-round-03-pass.md"
echo "--- 本轮上下文段:"; sed -n '/^## 本轮上下文/,/^## 严重度判据/p' <<<"$PROMPT"
finish
