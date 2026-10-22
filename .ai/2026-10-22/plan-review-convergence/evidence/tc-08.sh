#!/usr/bin/env bash
# TC-08 shellcheck:error 级 0 条;默认级别输出原样记录(不判)
source "$(dirname "$0")/lib.sh"
SC=${SHELLCHECK:-shellcheck}
command -v "$SC" >/dev/null || { bad "shellcheck 不可用:$SC"; finish; }
"$SC" --version | head -2
cd "$ROOT"
files=(.ai-workflow/scripts/*.sh .claude/hooks/*.sh .githooks/*)
echo "检查文件:${files[*]}"
if "$SC" -S error "${files[@]}"; then ok "shellcheck -S error 0 条"; else bad "shellcheck -S error 有条目"; fi
echo "--- 默认级别(仅供参考,不判):"
"$SC" -f gcc "${files[@]}" || true
finish
