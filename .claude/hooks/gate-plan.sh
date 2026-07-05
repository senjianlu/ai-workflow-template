#!/usr/bin/env bash
# PreToolUse hook:plan 未获批时,拦截对源码与工作流控制文件的写入。
# 放行 = 无输出退出 0(交还正常权限流,不输出 allow);
# 拒绝 = stdout 输出 permissionDecision: deny 的 JSON 并退出 0。
set -euo pipefail

deny() {
  jq -n --arg r "$1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# 没有 file_path 的调用(非文件写入)一律放行
[ -z "$file_path" ] && exit 0

proj="${CLAUDE_PROJECT_DIR:-$(pwd)}"
proj_phys=$(cd "$proj" && pwd -P)

case "$file_path" in
  /*) abs="$file_path" ;;
  *)  abs="$proj/$file_path" ;;
esac

# 仅任务产物目录 .ai/ 永远可写。归属判定基于物理路径:对最近已存在的
# 祖先目录做 pwd -P,可挡 .. 穿越与符号链接目录逃逸;目标已存在且本身
# 是符号链接的,不走豁免。
in_ai_dir() {
  [ -L "$abs" ] && return 1
  local d
  d=$(dirname "$abs")
  while [ ! -d "$d" ]; do d=$(dirname "$d"); done
  d=$(cd "$d" && pwd -P) || return 1
  case "$d/" in
    "$proj_phys/.ai/"*) return 0 ;;
  esac
  return 1
}
in_ai_dir && exit 0

# 没有进行中的任务:放行(琐碎改动路径,纪律靠 CLAUDE.md 硬规则)
current_file="$proj/.ai/.current-task"
[ -f "$current_file" ] || exit 0

plan="$proj/$(cat "$current_file")/plan.md"
[ -f "$plan" ] || exit 0

status=$(sed -n 's/^status:[[:space:]]*//p' "$plan" | head -1)
if [ "$status" != "approved" ]; then
  deny "rawf 工作流拦截:当前任务 plan 状态为 '$status',尚未获得用户确认。请先向用户呈现方案摘要并获得明确同意(/rawf-plan 第 6-7 步),再改动源码或工作流文件。"
fi
exit 0
