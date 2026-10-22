#!/usr/bin/env bash
# TC-10 评审期间修改 plan.md:本轮作废、不发布、不消耗轮次;重跑仍为第 01 轮
source "$(dirname "$0")/lib.sh"
new_proj; fake_codex fail mutate; run_review
assert_eq "第一次退出码" "$RC" "3"
assert_contains "stderr" "$ERR" "评审期间被修改"
assert_eq "无评审文件" "$(ls "$TD"/plan-review-round-*.md 2>/dev/null)" ""
assert_file "$TD/.plan-review-raw-01.json"
fake_codex pass; run_review
assert_eq "重跑退出码" "$RC" "0"
assert_file "$TD/plan-review-round-01-pass.md"
if cmp -s "$TD/plan.md" "$TD/.plan-review-raw-01.plan.md"; then ok "重跑快照与当时 plan.md 一致"; else bad "重跑快照与 plan.md 不一致"; fi
echo "--- 第一次 stderr:"; echo "$ERR"
finish
