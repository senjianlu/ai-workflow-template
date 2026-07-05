#!/usr/bin/env bash
# PreToolUse hook:plan 未获批时,拦截对源码的写入。
# 退出码 0 = 放行;退出码 2 = 拒绝,stderr 会作为反馈返回给 Claude。
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# 没有 file_path 的调用(非文件写入)一律放行
[ -z "$file_path" ] && exit 0

proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
rel="${file_path#"$proj"/}"

# 工作流自身的目录永远可写:产物、模板、配置
case "$rel" in
  .ai/*|.ai-workflow/*|.claude/*) exit 0 ;;
esac

# 没有进行中的任务:放行(琐碎改动路径,纪律靠 CLAUDE.md 约定)
current_file="$proj/.ai/.current-task"
[ -f "$current_file" ] || exit 0

plan="$proj/$(cat "$current_file")/plan.md"
[ -f "$plan" ] || exit 0

status=$(sed -n 's/^status:[[:space:]]*//p' "$plan" | head -1)
if [ "$status" != "approved" ]; then
  echo "rawf 工作流拦截:当前任务 plan 状态为 '$status',尚未获得用户确认。请先向用户呈现方案摘要并获得明确同意(/rawf-plan 第 6-7 步),再改动源码。" >&2
  exit 2
fi
exit 0
