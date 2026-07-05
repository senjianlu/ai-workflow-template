#!/usr/bin/env bash
# Stop hook:最新一轮实现尚未评审时,不许结束回合(只拦一次)
set -euo pipefail

input=$(cat)
[ "$(echo "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
task_rel=$(cat "$proj/.ai/.current-task" 2>/dev/null) || exit 0
task_dir="$proj/$task_rel"
[ -d "$task_dir" ] || exit 0

count=$(ls "$task_dir"/implementation-round-*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$count" -gt 0 ] || exit 0
nn=$(printf '%02d' "$count")

if ! ls "$task_dir"/review-round-"$nn"-*.md >/dev/null 2>&1; then
  echo "rawf 工作流拦截:第 $nn 轮实现尚未经过 Codex 评审。请立即运行 /rawf-review;若因故必须先征询用户,说明原因后可再次结束。" >&2
  exit 2
fi
exit 0
