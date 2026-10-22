#!/usr/bin/env bash
# TC-04 第 2 轮前未修订 plan:注明未修订,不给 diff
source "$(dirname "$0")/lib.sh"
new_proj; fake_codex fail; run_review
fake_codex fail; run_review
assert_eq "第 02 轮退出码" "$RC" "1"
assert_contains "prompt" "$PROMPT" "plan.md 自第 01 轮评审以来未修订"
assert_not_contains "prompt" "$PROMPT" '```diff'
finish
