#!/usr/bin/env bash
# TC-01 review.sh 注入的证据报告与 evidence-check 原始输出逐字一致(含 & 的证据格)
source "$(dirname "$0")/lib.sh"
new_proj
(cd "$T" && env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-01 -- bash -c 'true && true' >/dev/null 2>&1)
git -C "$T" add -A >/dev/null; git -C "$T" commit -q -m fixtures
report=$(env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence-check.sh"); rc=$?
assert_eq "① evidence-check 退出码" "$rc" "0"
echo "--- ① evidence-check 原始输出:"; echo "$report"
run_review
assert_eq "② review.sh 退出码" "$RC" "0"
n=0; miss=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  n=$((n+1))
  grep -qF -- "$line" <<<"$PROMPT" || { miss=$((miss+1)); echo "    缺行:$line"; }
done <<<"$report"
assert_eq "② 报告 $n 个非空行逐字出现在 prompt 中(缺失行数)" "$miss" "0"
assert_contains "② prompt" "$PROMPT" "a.sh:12 & b.sh:3"
assert_contains "② prompt" "$PROMPT" "目测 A&B 一致"
assert_contains "② prompt" "$PROMPT" '\&\&'
assert_not_contains "② prompt" "$PROMPT" "{{"
echo "--- ② prompt 中的证据核验段:"; sed -n '/^## 测试证据核验/,/^对 A 档证据只核三件事/p' <<<"$PROMPT"
finish
