#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj T; cd "$T"; good_plan "$T"; good_record "$T" 01
sed -i '/^evidence_format/d' "$T/.ai/2026-10-22/t/plan.md"
out=$(env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence-check.sh"); rc=$?
echo "$out"
assert_eq "退出码" "$rc" "2"; assert_contains "stdout" "$out" "跳过机器核验"
finish
