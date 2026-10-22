#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj A; new_proj B
(cd "$A" && env CLAUDE_PROJECT_DIR="$A" bash "$SCRIPTS/evidence.sh" TC-01 -- bash -c 'sleep 0.3; echo A; exit 0' >/dev/null 2>&1) & pa=$!
(cd "$B" && env CLAUDE_PROJECT_DIR="$B" bash "$SCRIPTS/evidence.sh" TC-01 -- bash -c 'sleep 0.3; echo B; exit 5' >/dev/null 2>&1) & pb=$!
wait $pa; ra=$?; wait $pb; rb=$?
assert_eq "A 退出码" "$ra" "0"; assert_eq "B 退出码" "$rb" "5"
fa="$A/.ai/2026-10-22/t/evidence/TC-01.log"; fb="$B/.ai/2026-10-22/t/evidence/TC-01.log"
ba=$(awk '/^--- output ---$/{f=1;next} /^--- end ---$/{f=0} f' "$fa" | grep -v '^$'); bb=$(awk '/^--- output ---$/{f=1;next} /^--- end ---$/{f=0} f' "$fb" | grep -v '^$')
assert_eq "A 正文" "$ba" "A"; assert_eq "B 正文" "$bb" "B"
assert_contains "A 尾部" "$(cat "$fa")" "exit: 0"; assert_contains "B 尾部" "$(cat "$fb")" "exit: 5"
assert_contains "A cwd" "$(cat "$fa")" "cwd: $A"; assert_contains "B cwd" "$(cat "$fb")" "cwd: $B"
assert_eq "A evidence/ 文件数" "$(ls "$A/.ai/2026-10-22/t/evidence" | wc -l)" "1"; assert_eq "B evidence/ 文件数" "$(ls "$B/.ai/2026-10-22/t/evidence" | wc -l)" "1"
finish
