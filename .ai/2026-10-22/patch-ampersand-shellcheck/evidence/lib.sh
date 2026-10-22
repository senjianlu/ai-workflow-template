# 测试公共库(1.2.1 补丁):临时项目、假 codex、断言。被 tc-NN.sh source。
set -u
ROOT=$(git rev-parse --show-toplevel)
SCRIPTS="$ROOT/.ai-workflow/scripts"
TASK=.ai/2026-10-22/t
FAILS=0
ok()   { echo "  ok   - $1"; }
bad()  { echo "  FAIL - $1"; FAILS=$((FAILS+1)); }
assert_eq() { if [ "$2" = "$3" ]; then ok "$1 == $(printf %q "$3")"; else bad "$1: 期望 $(printf %q "$3"),实际 $(printf %q "$2")"; fi; }
assert_contains() { if grep -qF -- "$3" <<<"$2"; then ok "$1 含 $(printf %q "$3")"; else bad "$1 不含 $(printf %q "$3")"; fi; }
assert_not_contains() { if grep -qF -- "$3" <<<"$2"; then bad "$1 不应含 $(printf %q "$3")"; else ok "$1 不含 $(printf %q "$3")"; fi; }
finish() { echo; if [ "$FAILS" -eq 0 ]; then echo "RESULT: all assertions passed"; exit 0; else echo "RESULT: $FAILS assertion(s) failed"; exit 1; fi; }

# new_proj:临时 git 项目(复制 .ai-workflow),plan 含 TC-01(A)、TC-02(B)、TC-03(C);
# 设置 T(项目根)、TD(任务目录)、OUT(项目外假 codex 输出目录),并放好假 codex
new_proj() {
  T=$(mktemp -d /tmp/rawf-121.XXXXXX)
  git -C "$T" init -q . && git -C "$T" commit -q --allow-empty -m init
  cp -r "$ROOT/.ai-workflow" "$T/.ai-workflow"
  mkdir -p "$T/$TASK/evidence"; echo "$TASK" > "$T/.ai/.current-task"; TD="$T/$TASK"
  cat > "$TD/plan.md" <<'P'
---
status: approved
evidence_format: v1
---
## 测试用例
| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | x | y | z | (a) TC-01.log |
| TC-02 | B | x | y | z | 文件:行号 |
| TC-03 | C | x | y | z | 陈述(不可自动化:目测) |
P
  cat > "$TD/implementation-round-01.md" <<'R'
## 测试结果
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01.log |
| TC-02 | B | pass | a.sh:12 & b.sh:3 |
| TC-03 | C | pass | 目测 A&B 一致 |
R
  OUT=$(mktemp -d /tmp/rawf-121out.XXXXXX)
  mkdir -p "$T/bin"
  cat > "$T/bin/codex" <<C
#!/usr/bin/env bash
touch "$OUT/invoked"
last=
while [ \$# -gt 0 ]; do
  if [ "\$1" = "--output-last-message" ]; then last=\$2; shift 2; continue; fi
  prompt=\$1; shift
done
printf '%s' "\$prompt" > "$OUT/prompt.txt"
printf '%s\n' '{"verdict":"pass","issues":[],"scope_findings":[],"overall":"o"}' > "\$last"
echo '{"type":"item.completed"}'
C
  chmod +x "$T/bin/codex"
}
run_review() {
  local ef; ef=$(mktemp /tmp/rawf-121err.XXXXXX)
  (cd "$T" && env CLAUDE_PROJECT_DIR="$T" PATH="$T/bin:$PATH" bash "$SCRIPTS/review.sh" >/dev/null 2>"$ef"); RC=$?
  ERR=$(cat "$ef"); rm -f "$ef"
  PROMPT=$(cat "$OUT/prompt.txt" 2>/dev/null || true)
}
