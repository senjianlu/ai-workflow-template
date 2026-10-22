#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj T; cd "$T"
raw=$(mktemp /tmp/rawf-raw.XXXXXX.json)
printf '{"verdict":"pass","issues":[],"scope_findings":["方案多做了 Y","非目标缺 Z"],"overall":"ok"}\n' > "$raw"
out=$(bash "$SCRIPTS/plan-review.sh" __publish_round "$T/.ai/2026-10-22/t" 01 pass "$raw"); rc=$?
assert_eq "退出码" "$rc" "0"; assert_eq "输出文件名" "$out" "plan-review-round-01-pass.md"
f="$T/.ai/2026-10-22/t/plan-review-round-01-pass.md"
assert_contains "产物" "$(cat "$f")" "## 范围核对"
assert_contains "产物" "$(cat "$f")" "- 方案多做了 Y"; assert_contains "产物" "$(cat "$f")" "- 非目标缺 Z"
printf '{"verdict":"pass","issues":[],"overall":"ok"}\n' > "$raw"
bash "$SCRIPTS/plan-review.sh" __publish_round "$T/.ai/2026-10-22/t" 02 pass "$raw" >/dev/null; rc=$?
assert_eq "无字段时退出码" "$rc" "0"
assert_eq "无字段时该节为无" "$(sed -n '/## 范围核对/{n;p}' "$T/.ai/2026-10-22/t/plan-review-round-02-pass.md")" "无"
cat "$f"
finish
