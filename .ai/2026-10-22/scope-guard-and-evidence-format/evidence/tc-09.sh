#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj T; cd "$T"; good_plan "$T"; good_record "$T" 01   # 记录引用的 TC-01.log/TC-02.log 不存在 → MISSING
OUT=$(mktemp -d /tmp/rawf-fake.XXXXXX); fake_codex "$T" "$OUT"
git -C "$T" add -A >/dev/null; git -C "$T" commit -q -m fixtures
err=$(cd "$T" && env CLAUDE_PROJECT_DIR="$T" PATH="$T/bin:$PATH" bash "$SCRIPTS/review.sh" 2>&1 >/dev/null); rc=$?
echo "$err"
assert_eq "review.sh 退出码" "$rc" "3"
assert_contains "stderr" "$err" "证据核验未通过"; assert_contains "stderr" "$err" "补交清单"; assert_contains "stderr" "$err" "MISSING"
assert_nofile "$OUT/invoked"
assert_eq "无评审文件" "$(ls "$T"/.ai/2026-10-22/t/review-round-01-*.md 2>/dev/null)" ""
finish
