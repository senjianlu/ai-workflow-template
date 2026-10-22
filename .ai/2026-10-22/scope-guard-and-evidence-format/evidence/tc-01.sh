#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj T; cd "$T"
env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-01 -- bash -c 'echo out; echo err >&2; exit 0' > "$T/../$(basename "$T").term" 2>&1; rc=$?
term=$(cat "$T/../$(basename "$T").term"); rm -f "$T/../$(basename "$T").term"
f="$T/.ai/2026-10-22/t/evidence/TC-01.log"
assert_eq "包装器退出码" "$rc" "0"
assert_file "$f"
c=$(cat "$f")
assert_eq "首行" "$(head -n1 "$f")" "# rawf-evidence v1"
for k in "tc: TC-01" "cmd: bash -c" "cwd: $T" "git_head: " "started: " "--- output ---" "--- end ---" "exit: 0" "finished: " "bytes: 8"; do assert_contains "文件" "$c" "$k"; done
body=$(awk '/^--- output ---$/{f=1;next} /^--- end ---$/{f=0} f' "$f")
assert_contains "正文" "$body" "out"; assert_contains "正文" "$body" "err"
assert_contains "终端输出" "$term" "out"; assert_contains "终端输出" "$term" "err"
echo "--- 文件全文:"; cat "$f"
finish
