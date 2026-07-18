#!/usr/bin/env bash
# relax-review-round-caps 自测:TC-01~TC-08(TC-09 为人工场景走查,另行记录)
# 仓库根解析优先级:$1 > git -C <脚本所在目录> 的仓库根(脚本随任务落在
# evidence/ 时即当前工作区)。工作目录用 mktemp 落在仓库外,不污染工作区。
set -u
proj="${1:-$(git -C "$(cd "$(dirname "$0")" && pwd)" rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$proj" ] && [ -d "$proj/.ai-workflow" ] \
  || { echo "无法定位仓库根(可显式传参:$0 <repo-root>)" >&2; exit 2; }
echo "REPO: $proj"
script="$proj/.ai-workflow/scripts/plan-review.sh"
work=$(mktemp -d "${TMPDIR:-/tmp}/tc-round-caps.XXXXXX")
trap 'rm -rf "$work"' EXIT
pass=0; fail=0

check() { # check <tc> <desc> <expected> <actual>
  if [ "$3" = "$4" ]; then
    echo "PASS $1 $2"; pass=$((pass+1))
  else
    echo "FAIL $1 $2 (expect: $3, got: $4)"; fail=$((fail+1))
  fi
}

# ---- TC-01 无字段 → 3
cat > "$work/p1.md" <<'EOF'
---
status: draft
task: t
---
# 方案
EOF
out=$(bash "$script" __resolve_max_rounds "$work/p1.md"); rc=$?
check TC-01 "无字段缺省 3" "3/0" "$out/$rc"

# ---- TC-02 字段 5 → 5
cat > "$work/p2.md" <<'EOF'
---
status: draft
plan_review_max_rounds: 5
---
# 方案
EOF
out=$(bash "$script" __resolve_max_rounds "$work/p2.md"); rc=$?
check TC-02 "字段 5 生效" "5/0" "$out/$rc"

# ---- TC-03 非法值 0 / abc / 空值 / 纯空格 → exit 3(字段出现即须为正整数)
for bad in "0" "abc" "" "   "; do
  printf -- '---\nplan_review_max_rounds:%s\n---\n' "${bad:+ $bad}" > "$work/p3.md"
  out=$(bash "$script" __resolve_max_rounds "$work/p3.md" 2>"$work/p3.err"); rc=$?
  check TC-03 "非法值 [${bad:-<空>}] 拒绝" "/3" "$out/$rc"
  grep -q "非法" "$work/p3.err" && echo "  stderr: $(cat "$work/p3.err")"
done

# ---- TC-04 正文伪造字段不生效 → 3
cat > "$work/p4.md" <<'EOF'
---
status: draft
---
# 方案
正文里写 plan_review_max_rounds: 9 不应生效。
plan_review_max_rounds: 9
EOF
out=$(bash "$script" __resolve_max_rounds "$work/p4.md"); rc=$?
check TC-04 "正文伪造不生效" "3/0" "$out/$rc"

# ---- TC-05/06 主流程轮次闸(假项目 + CLAUDE_PROJECT_DIR,不触真实任务)
fake="$work/fakeproj"
mkdir -p "$fake/.ai/2026-07-18/tc-task" "$fake/.ai-workflow/prompts" "$fake/.ai-workflow/schemas"
echo ".ai/2026-07-18/tc-task" > "$fake/.ai/.current-task"
cp "$proj/.ai-workflow/prompts/plan-review.md" "$fake/.ai-workflow/prompts/"
cp "$proj/.ai-workflow/schemas/plan-review.schema.json" "$fake/.ai-workflow/schemas/"
td="$fake/.ai/2026-07-18/tc-task"
for i in 1 2 3; do echo x > "$td/plan-review-round-0$i-fail.md"; done

# TC-05:无字段,已 3 轮 → 上限拒绝
printf -- '---\nstatus: draft\n---\n# p\n' > "$td/plan.md"
out=$(CLAUDE_PROJECT_DIR="$fake" bash "$script" 2>&1); rc=$?
echo "$out" | grep -q "已达 3 轮上限"; hit=$?
check TC-05 "缺省 3 轮闸拦截" "0/3" "$hit/$rc"
echo "  msg: $out"

# TC-06:字段 5,已 3 轮,假 codex(exit 1)→ 过闸,死在 codex 阶段
printf -- '---\nstatus: draft\nplan_review_max_rounds: 5\n---\n# p\n' > "$td/plan.md"
mkdir -p "$work/bin"; printf '#!/bin/sh\nexit 1\n' > "$work/bin/codex"; chmod +x "$work/bin/codex"
out=$(CLAUDE_PROJECT_DIR="$fake" PATH="$work/bin:$PATH" bash "$script" 2>&1); rc=$?
echo "$out" | grep -q "codex exec 执行失败"; hit=$?
echo "$out" | grep -q "轮上限"; nocap=$?   # 期望 1:不再报上限
check TC-06 "上限 5 放行第 4 轮(死于假 codex)" "0/1/3" "$hit/$nocap/$rc"
echo "  msg: $out"

# ---- TC-07 语法 + 全仓固定表述残留检查(排除 .ai/ .git/ 与 decisions 沿革)
bash -n "$script"; check TC-07a "bash -n 语法" "0" "$?"
resid=$(grep -rnE "最多 3 轮|三轮|NN = 3|NN > 3|NN < 3" "$proj" \
  --exclude-dir=.ai --exclude-dir=.git --exclude-dir=node_modules 2>/dev/null \
  | grep -v "docs/decisions/" | grep -v "默认最多 3 轮" || true)
check TC-07b "无条件固定上限残留为零" "" "$resid"

# ---- TC-08 skill 静态断言
imp="$proj/.claude/skills/rawf-implement/SKILL.md"
rev="$proj/.claude/skills/rawf-review/SKILL.md"
ok=0
for f in "$imp" "$rev"; do
  # 断言 1:上限来源为 plan.md frontmatter 字段
  grep -q "impl_fix_max_rounds" "$f" || { echo "  miss[$f]: 字段来源"; ok=1; }
  # 断言 2:缺省/非法回退到 3(文本可能换行,压平后匹配)
  tr -d '\n ' < "$f" | grep -q "缺失或非正整数一律按\*\*默认3\*\*" \
    || { echo "  miss[$f]: 缺省回退"; ok=1; }
done
# 断言 3:达上限的停止动作
grep -q "NN > 上限:停止实现" "$imp" || { echo "  miss[imp]: 停止动作"; ok=1; }
grep -q "NN ≥ 上限 → 停止修复" "$rev" || { echo "  miss[rev]: 停止动作"; ok=1; }
check TC-08 "skill 三项断言(字段来源/缺省回退/停止动作)" "0" "$ok"

echo; echo "RESULT: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
