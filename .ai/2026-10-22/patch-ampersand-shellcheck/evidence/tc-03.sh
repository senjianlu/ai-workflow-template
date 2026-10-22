#!/usr/bin/env bash
# TC-03 shellcheck 全级别零条
source "$(dirname "$0")/lib.sh"
SC=${SHELLCHECK:-shellcheck}
command -v "$SC" >/dev/null || { bad "shellcheck 不可用:$SC"; finish; }
"$SC" --version | sed -n 2p
cd "$ROOT"
files=(.ai-workflow/scripts/*.sh .claude/hooks/*.sh .githooks/*)
echo "检查文件:${files[*]}"
out=$("$SC" -f gcc "${files[@]}" 2>&1); rc=$?
echo "--- shellcheck 输出(期望为空):"; echo "$out"
assert_eq "shellcheck 退出码" "$rc" "0"
assert_eq "shellcheck 输出" "$out" ""
finish
