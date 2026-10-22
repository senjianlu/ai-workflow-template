#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj A; new_proj B
good_plan "$B"; good_record "$B" 01; good_evidence "$B"
OUT=$(mktemp -d /tmp/rawf-fake.XXXXXX); fake_codex "$B" "$OUT" hang
git -C "$B" add -A >/dev/null; git -C "$B" commit -q -m fixtures
errf=$(mktemp /tmp/rawf-tc19.XXXXXX)
(cd "$B" && env CLAUDE_PROJECT_DIR="$B" PATH="$B/bin:$PATH" RAWF_REVIEW_IDLE_SECONDS=2 RAWF_REVIEW_POLL_SECONDS=1 bash "$SCRIPTS/review.sh" >/dev/null 2>"$errf") & pb=$!
(cd "$A" && env CLAUDE_PROJECT_DIR="$A" bash "$SCRIPTS/evidence.sh" TC-01 -- bash -c 'sleep 8; echo done' >/dev/null 2>&1) & pa=$!
wait $pb; rb=$?; wait $pa; ra=$?
err=$(cat "$errf"); echo "--- B review.sh stderr:"; echo "$err"
assert_eq "B review.sh 退出码" "$rb" "3"; assert_contains "B stderr" "$err" "已终止"
assert_file "$OUT/invoked"
sleep 0.5
alive=$(pgrep -x sleep -a | grep -F ' 613' || true)
assert_eq "B 的假 codex 子树(sleep 613)不再存活" "$alive" ""
assert_eq "A evidence.sh 退出码" "$ra" "0"
fa="$A/.ai/2026-10-22/t/evidence/TC-01.log"
assert_contains "A 证据尾部" "$(cat "$fa")" "exit: 0"; assert_contains "A 证据正文" "$(cat "$fa")" "done"
good_plan "$A"; printf '## 测试结果\n| 编号 | 档位 | 结果 | 证据 |\n|---|---|---|---|\n| TC-01 | A | pass | TC-01.log |\n| TC-02 | A | pass | TC-01.log |\n| TC-03 | B | pass | a:1 |\n| TC-04 | C | pass | 看 |\n' > "$A/.ai/2026-10-22/t/implementation-round-01.md"
out=$(env CLAUDE_PROJECT_DIR="$A" bash "$SCRIPTS/evidence-check.sh"); rc=$?
assert_eq "A evidence-check 退出码" "$rc" "0"; assert_contains "A evidence-check" "$(grep '^| TC-01' <<<"$out")" "| OK | 0 |"
finish
