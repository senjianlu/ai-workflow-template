#!/usr/bin/env bash
# TC-05:.ai/ 下只有当前任务目录有变化,历史任务目录零改动
. "$(dirname "$0")/lib.sh"
T=.ai/2026-11-10/consumer-feedback-1.3.0/
echo "## git status --porcelain --untracked-files=all -- .ai"
st=$(git status --porcelain --untracked-files=all -- .ai); echo "$st"
other=$(echo "$st" | awk 'NF' | grep -vF " $T" || true)
[ -z "$other" ] && ok "变化全部位于 $T" || { bad "存在任务目录之外的变化"; echo "$other"; }
echo "## git diff HEAD --stat -- .ai"
d=$(git diff HEAD --stat -- .ai); echo "${d:-(空)}"
[ -z "$d" ] && ok "已跟踪的 .ai 历史文件无任何改动" || bad "已跟踪的 .ai 历史文件无任何改动"
echo "已跟踪的 .ai 文件数:$(git ls-files .ai | wc -l)"
finish
