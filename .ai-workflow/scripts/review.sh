#!/usr/bin/env bash
# 调用 Codex 评审当前改动。退出码:0=pass 1=fail 3=评审执行异常
# 评审在工作区的一次性副本上执行(主工作区不在评审者可写范围内),
# 完整性哈希保留为双保险,隔离生效时理应永不触发。
set -euo pipefail

command -v codex >/dev/null || { echo "codex CLI 未安装或不在 PATH" >&2; exit 3; }

proj="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
cd "$proj"

task_rel=$(cat .ai/.current-task 2>/dev/null) || { echo "无进行中任务(.ai/.current-task 不存在)" >&2; exit 3; }
task_dir="$proj/$task_rel"
[ -d "$task_dir" ] || { echo "任务目录不存在:$task_rel" >&2; exit 3; }

# 同轮唯一性由原子锁保证:mkdir 原子性使"检查-评审-发布"全程互斥,
# 并发第二实例直接拒绝;锁为临时空目录,对 git 与完整性哈希均不可见
lock="$task_dir/.review-lock"
if ! mkdir "$lock" 2>/dev/null; then
  echo "已有评审在进行中($task_rel/.review-lock 存在);确认无并发评审后删除该目录重跑" >&2
  exit 3
fi
trap 'rm -rf "$lock"' EXIT

count=$(ls "$task_dir"/implementation-round-*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$count" -gt 0 ] || { echo "尚无实现记录,先完成 /rawf-implement" >&2; exit 3; }
nn=$(printf '%02d' "$count")

# 同一轮只评一次:.ai/ 历史只增不改
if ls "$task_dir"/review-round-"$nn"-*.md >/dev/null 2>&1; then
  echo "第 $nn 轮已有评审文件,按'历史只增不改'拒绝重评;确需重评请用户手动处置旧文件后重跑" >&2
  exit 3
fi

prompt=$(cat .ai-workflow/prompts/review.md)
prompt="${prompt//\{\{TASK_DIR\}\}/$task_rel}"
prompt="${prompt//\{\{ROUND\}\}/$nn}"

# 完整性快照(双保险):已跟踪改动 + 未跟踪文件逐条 NUL 定界记账
# (类型\0路径\0载荷\0;符号链接记链接目标,普通文件记可执行位+内容哈希),
# diff 段与未跟踪段各自先哈希再合并,无分隔符歧义与跨段拼接歧义。
# 未跟踪文件不按 .gitignore 排除(防 .env 等被忽略文件遭篡改而不被发现),
# 只排除明确允许的评审/测试产物。
# TEMPLATE: 按项目构建产物增删排除项。
hash_excludes=(
  --exclude='.review-raw-*.md'
  --exclude='__pycache__/' --exclude='*.pyc' --exclude='.pytest_cache/'
  --exclude='.venv/' --exclude='node_modules/' --exclude='dist/' --exclude='.next/'
  --exclude='.DS_Store'
)
workspace_hash() {
  {
    git diff HEAD | shasum
    git ls-files --others -z "${hash_excludes[@]}" \
      | while IFS= read -r -d '' f; do
          if [ -L "$f" ]; then
            printf 'symlink\0%s\0' "$f"
            readlink "$f"
            printf '\0'
          else
            if [ -x "$f" ]; then m=x; else m=-; fi
            printf 'file\0%s\0%s\0' "$f" "$m"
            shasum < "$f"
            printf '\0'
          fi
        done | shasum
  } | shasum | cut -d' ' -f1
}
pre_hash=$(workspace_hash)

# 评审在一次性副本上执行,结束即销毁
sandbox_root=$(mktemp -d "${TMPDIR:-/tmp}/rawf-review-XXXXXX") || { echo "创建评审副本目录失败" >&2; exit 3; }
trap 'rm -rf "$sandbox_root" "$lock"' EXIT
copy="$sandbox_root/repo"
cp -Rp "$proj" "$copy" || { echo "复制工作区到评审副本失败" >&2; exit 3; }

raw_name=".review-raw-$nn.md"
raw_copy="$copy/$task_rel/$raw_name"
rm -f "$raw_copy"   # 清除随副本带入的历史遗留输出,防陈旧 VERDICT 被误用

codex_rc=0
codex exec --sandbox workspace-write -C "$copy" \
  --output-last-message "$raw_copy" "$prompt" || codex_rc=$?

# 双保险:主工作区必须分毫未动(隔离生效时恒真)
post_hash=$(workspace_hash)
if [ "$pre_hash" != "$post_hash" ]; then
  echo "主工作区在评审期间发生改动(隔离未能阻止,或存在并发写入),本次评审无效。请 git status 检查后重跑。" >&2
  exit 3
fi

if [ "$codex_rc" -ne 0 ]; then
  echo "codex exec 执行失败(退出码 $codex_rc),评审未完成;检查 codex login/额度/网络后重跑" >&2
  exit 3
fi

if [ ! -f "$raw_copy" ]; then
  echo "codex 退出 0 但未产出评审输出文件,评审未完成;请重跑评审" >&2
  exit 3
fi

verdict=$(sed -n 's/^VERDICT:[[:space:]]*//p' "$raw_copy" | tail -1)
case "$verdict" in
  pass|fail) ;;
  *)
    cp "$raw_copy" "$task_dir/$raw_name" 2>/dev/null || true
    echo "评审输出缺少合法 VERDICT 行,原始输出保留在 $task_rel/$raw_name" >&2
    exit 3 ;;
esac

# 唯一从副本取回主工作区的产物:评审结论文件。
# 原子发布:先在同目录(同文件系统)写全临时文件,mv -n 原子改名发布;
# cp 中途失败只污染临时文件(随即清理),不会留下半成品结论、不阻断重试。
final="$task_dir/review-round-$nn-$verdict.md"
tmp_out="$task_dir/.review-out-$nn.$$"
if ! cp "$raw_copy" "$tmp_out"; then
  rm -f "$tmp_out"
  echo "取回评审文件失败" >&2
  exit 3
fi
if ! mv -n "$tmp_out" "$final" || [ -e "$tmp_out" ]; then
  rm -f "$tmp_out"
  echo "评审结论已被并发发布($final 已存在),本次结果未覆盖" >&2
  exit 3
fi
echo "review-round-$nn-$verdict.md"
[ "$verdict" = "pass" ]
