#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj T; cd "$T"; good_plan "$T"; good_record "$T" 01; good_evidence "$T"
OUT=$(mktemp -d /tmp/rawf-fake.XXXXXX); fake_codex "$T" "$OUT" pass
git -C "$T" add -A >/dev/null; git -C "$T" commit -q -m fixtures
out=$(cd "$T" && env CLAUDE_PROJECT_DIR="$T" PATH="$T/bin:$PATH" bash "$SCRIPTS/review.sh" 2>&1); rc=$?
echo "$out"
assert_eq "第 1 轮退出码" "$rc" "0"
assert_file "$OUT/invoked"
p=$(cat "$OUT/prompt.txt")
assert_contains "prompt 含机器核验表" "$p" "| TC-01 | A | pass | TC-01.log | OK | 0 |"
assert_not_contains "prompt 无残留占位" "$p" "{{"
r="$T/.ai/2026-10-22/t/review-round-01-pass.md"; assert_file "$r"
assert_contains "评审文件" "$(cat "$r")" "## 范围核对"
assert_contains "评审文件" "$(sed -n '/## 范围核对/,/## 总评/p' "$r")" "- X"
# 第 2 轮:假 codex 不输出 scope_findings → 渲染容错,该节写"无"(review.sh 无 __publish_round 入口,以第二轮替代)
good_record "$T" 02; fake_codex "$T" "$OUT" noscope
out=$(cd "$T" && env CLAUDE_PROJECT_DIR="$T" PATH="$T/bin:$PATH" bash "$SCRIPTS/review.sh" 2>&1); rc=$?
assert_eq "第 2 轮退出码" "$rc" "0"
r2="$T/.ai/2026-10-22/t/review-round-02-pass.md"; assert_file "$r2"
assert_eq "范围核对节为无" "$(sed -n '/## 范围核对/{n;p}' "$r2")" "无"
echo "--- review-round-01-pass.md:"; cat "$r"
finish
