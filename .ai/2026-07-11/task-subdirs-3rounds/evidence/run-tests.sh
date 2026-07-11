#!/usr/bin/env bash
# rawf task task-subdirs-3rounds 自测脚本。逐条执行 plan.md 用例,输出证据。
# REPO 从脚本自身位置解析,保证在任意 checkout(含 review.sh 的评审副本)
# 都指向当前工作区,而非某台机器的固定路径。
set -uo pipefail
die(){ echo "  ‼️ 准备步骤失败:$1" >&2; exit 1; }
REPO=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel) \
  || die "无法解析仓库根(git rev-parse)"
cd "$REPO" || die "无法进入仓库根 $REPO"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
no(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "REPO=$REPO"
echo "=== TC-01 全仓一致性:轮次闸为 -ge 3,无指向 plan 评审的「2 轮」残留 ==="
if grep -q 'count" -ge 3' .ai-workflow/scripts/plan-review.sh; then ok "plan-review.sh 轮次闸为 -ge 3"; else no "轮次闸未改为 -ge 3"; fi
# 精确查 plan 评审轮次表述残留;「第 2 轮」(实现修复轮)与 0001 修订说明
# 里「由 2 轮放宽」属另一语义,不在此列。
leftover=$(grep -rnE '最多 2 轮|2 轮上限|-ge 2' .ai-workflow/scripts .claude/skills docs CLAUDE.md AGENTS.md 2>/dev/null || true)
if [ -z "$leftover" ]; then ok "无 plan 评审「最多 2 轮/2 轮上限/-ge 2」残留"; else no "仍有 plan 评审 2 轮残留:"; echo "$leftover"; fi

echo "=== TC-02 建目录生成 evidence/.gitkeep、assets/.gitkeep 且可入库 ==="
TASK=".ai/2026-07-11/task-subdirs-3rounds"
mkdir -p "$TASK/evidence" "$TASK/assets" || die "建 evidence/assets 目录失败"
touch "$TASK/evidence/.gitkeep" "$TASK/assets/.gitkeep" || die "建 .gitkeep 失败"
if [ -f "$TASK/evidence/.gitkeep" ] && [ -f "$TASK/assets/.gitkeep" ]; then ok "两 .gitkeep 已建"; else no ".gitkeep 缺失"; fi
if git check-ignore -q "$TASK/evidence/.gitkeep"; then no "evidence/.gitkeep 被 .gitignore 吞"; else ok "evidence/.gitkeep 未被忽略(可入库)"; fi
if git check-ignore -q "$TASK/assets/.gitkeep"; then no "assets/.gitkeep 被 .gitignore 吞"; else ok "assets/.gitkeep 未被忽略(可入库)"; fi

echo "=== TC-06 CLAUDE.md 含简体中文沟通硬规则 ==="
if grep -q '与用户沟通一律使用简体中文' CLAUDE.md; then ok "硬规则区命中简体中文条款"; else no "未找到简体中文条款"; fi

echo "=== TC-05 gate-plan 对 .ai/<task>/evidence/ 写入放行(status 非 approved 场景) ==="
HOOK=".claude/hooks/gate-plan.sh"
inp=$(printf '{"tool_input":{"file_path":"%s/.ai/2026-07-11/task-subdirs-3rounds/evidence/x.log"}}' "$REPO")
out=$(echo "$inp" | CLAUDE_PROJECT_DIR="$REPO" bash "$HOOK" 2>/dev/null) || true
rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then ok "hook 对 .ai/ 下 evidence 写入放行(无 deny 输出)"; else no "hook 未放行:rc=$rc out=$out"; fi

echo "=== TC-03 / TC-04 隔离临时工作区 + 假 codex 桩 ==="
TMP=$(mktemp -d) || die "mktemp 失败"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.ai-workflow/schemas" "$TMP/.ai-workflow/prompts" || die "建临时 .ai-workflow 失败"
cp .ai-workflow/schemas/plan-review.schema.json "$TMP/.ai-workflow/schemas/" || die "拷贝 schema 失败"
cp .ai-workflow/prompts/plan-review.md "$TMP/.ai-workflow/prompts/" || die "拷贝 prompt 失败"
TT="$TMP/.ai/2026-07-11/harness"
mkdir -p "$TT" || die "建临时任务目录失败"
printf 'status: approved\ntask: harness\n' > "$TT/plan.md" || die "写临时 plan.md 失败"
echo ".ai/2026-07-11/harness" > "$TMP/.ai/.current-task" || die "写 .current-task 失败"

# 假 codex:被调用即 touch 标记,并向 --output-last-message 写合法 pass JSON
BIN="$TMP/bin"; mkdir -p "$BIN" || die "建 bin 失败"
cat > "$BIN/codex" <<'STUB' || die "写 codex 桩失败"
#!/usr/bin/env bash
touch "$CODEX_MARKER"
out=""
while [ $# -gt 0 ]; do
  if [ "$1" = "--output-last-message" ]; then out="$2"; shift 2; continue; fi
  shift
done
[ -n "$out" ] && printf '{"verdict":"pass","issues":[],"overall":"stub"}' > "$out"
exit 0
STUB
chmod +x "$BIN/codex" || die "chmod codex 桩失败"
export CODEX_MARKER="$TMP/.codex-called"

run_review(){ PATH="$BIN:$PATH" CLAUDE_PROJECT_DIR="$TMP" bash "$REPO/.ai-workflow/scripts/plan-review.sh" 2>"$TMP/err.txt"; echo $?; }

# TC-04:已有 2 轮 → 放行第 3 轮
rm -f "$CODEX_MARKER" "$TT"/plan-review-round-*.md
: > "$TT/plan-review-round-01-fail.md"; : > "$TT/plan-review-round-02-fail.md"
rc=$(run_review)
echo "  [TC-04] exit=$rc; stderr='$(cat "$TMP/err.txt")'"
if [ -f "$CODEX_MARKER" ]; then ok "TC-04 codex 被调用(第 3 轮放行)"; else no "TC-04 codex 未被调用(第 3 轮被误拦)"; fi
if [ -f "$TT/plan-review-round-03-pass.md" ]; then ok "TC-04 产出 plan-review-round-03-pass.md"; else no "TC-04 未产出 round-03-pass"; fi
if grep -q '3 轮上限' "$TMP/err.txt"; then no "TC-04 误报「3 轮上限」"; else ok "TC-04 未误报上限"; fi

# TC-03:已有 3 轮 → 拒绝,不调 codex
rm -f "$CODEX_MARKER"
: > "$TT/plan-review-round-03-manual.md"   # 现在共 3 个 round 文件
rc=$(run_review)
echo "  [TC-03] exit=$rc; stderr='$(cat "$TMP/err.txt")'"
if [ "$rc" -eq 3 ]; then ok "TC-03 exit 3"; else no "TC-03 exit≠3 (=$rc)"; fi
if grep -q '3 轮上限' "$TMP/err.txt"; then ok "TC-03 打印「3 轮上限」"; else no "TC-03 未打印上限提示"; fi
if [ -f "$CODEX_MARKER" ]; then no "TC-03 codex 被误调用"; else ok "TC-03 codex 未被调用"; fi

echo
echo "=== 汇总:PASS=$PASS FAIL=$FAIL ==="
[ "$FAIL" -eq 0 ]
