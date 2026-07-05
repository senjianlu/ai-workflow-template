#!/usr/bin/env bash
# 调用 Codex 评审当前改动。退出码:0=pass 1=fail 3=评审执行异常
set -euo pipefail

command -v codex >/dev/null || { echo "codex CLI 未安装或不在 PATH" >&2; exit 3; }

proj="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
cd "$proj"

task_rel=$(cat .ai/.current-task 2>/dev/null) || { echo "无进行中任务(.ai/.current-task 不存在)" >&2; exit 3; }
task_dir="$proj/$task_rel"
[ -d "$task_dir" ] || { echo "任务目录不存在:$task_rel" >&2; exit 3; }

count=$(ls "$task_dir"/implementation-round-*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$count" -gt 0 ] || { echo "尚无实现记录,先完成 /rawf-implement" >&2; exit 3; }
nn=$(printf '%02d' "$count")

prompt=$(cat .ai-workflow/prompts/review.md)
prompt="${prompt//\{\{TASK_DIR\}\}/$task_rel}"
prompt="${prompt//\{\{ROUND\}\}/$nn}"

# 完整性快照:评审者不得改动受跟踪代码
pre_hash=$(git diff HEAD | shasum | cut -d' ' -f1)

raw="$task_dir/.review-raw-$nn.md"
codex exec --sandbox workspace-write -C "$proj" \
  --output-last-message "$raw" "$prompt"

post_hash=$(git diff HEAD | shasum | cut -d' ' -f1)
if [ "$pre_hash" != "$post_hash" ]; then
  echo "评审者修改了受跟踪文件,本次评审无效。请 git diff 检查后重跑。" >&2
  exit 3
fi

verdict=$(sed -n 's/^VERDICT:[[:space:]]*//p' "$raw" | tail -1)
case "$verdict" in
  pass|fail) ;;
  *) echo "评审输出缺少合法 VERDICT 行,原始输出保留在 $raw" >&2; exit 3 ;;
esac

mv "$raw" "$task_dir/review-round-$nn-$verdict.md"
echo "review-round-$nn-$verdict.md"
[ "$verdict" = "pass" ]
