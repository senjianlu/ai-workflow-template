# 测试公共库(plan-review 收敛机制):临时项目、假 codex、断言。被 tc-NN.sh source。
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
assert_file() { if [ -f "$1" ]; then ok "存在 ${1#"$T"/}"; else bad "缺文件 ${1#"$T"/}"; fi; }
assert_nofile() { if [ -e "$1" ]; then bad "不应存在 ${1#"$T"/}"; else ok "不存在 ${1#"$T"/}"; fi; }
finish() { echo; if [ "$FAILS" -eq 0 ]; then echo "RESULT: all assertions passed"; exit 0; else echo "RESULT: $FAILS assertion(s) failed"; exit 1; fi; }

# new_proj:建临时 git 项目(含 .ai-workflow 与 .gitignore 副本、.current-task、任务目录、
# 含一行"旧行"的 plan.md),设置全局 T(项目根)、TD(任务目录)、OUT(项目外的假 codex 输出目录)
new_proj() {
  T=$(mktemp -d /tmp/rawf-pr.XXXXXX)
  git -C "$T" init -q . && git -C "$T" commit -q --allow-empty -m init
  cp -r "$ROOT/.ai-workflow" "$T/.ai-workflow"
  cp "$ROOT/.gitignore" "$T/.gitignore"
  mkdir -p "$T/$TASK/evidence"
  echo "$TASK" > "$T/.ai/.current-task"
  TD="$T/$TASK"
  printf -- '---\nstatus: draft\ntask: t\n---\n# 方案\n\n## 需求原文\n> x\n\n## 非目标\n无\n\n旧行\n' > "$TD/plan.md"
  git -C "$T" add -A >/dev/null && git -C "$T" commit -q -m setup
  OUT=$(mktemp -d /tmp/rawf-prout.XXXXXX)
}
# fake_codex <verdict: pass|fail> [mutate]:在 $T/bin 放假 codex。记录调用(OUT/invoked)、
# 把 prompt 写到 OUT/prompt.txt;mutate 时先向 plan.md 追加一行(模拟评审期间修改)
fake_codex() {
  local verdict=$1 mutate=${2:-}
  mkdir -p "$T/bin"
  local issues='[]'
  [ "$verdict" = fail ] && issues='[{"id":"R-01","severity":"major","summary":"s","detail":"d"}]'
  cat > "$T/bin/codex" <<C
#!/usr/bin/env bash
touch "$OUT/invoked"
last=
while [ \$# -gt 0 ]; do
  if [ "\$1" = "--output-last-message" ]; then last=\$2; shift 2; continue; fi
  prompt=\$1; shift
done
printf '%s' "\$prompt" > "$OUT/prompt.txt"
[ -n "$mutate" ] && echo "评审期间追加的一行" >> "$TD/plan.md"
printf '%s\n' '{"verdict":"$verdict","issues":$issues,"scope_findings":[],"overall":"o"}' > "\$last"
echo '{"type":"item.completed"}'
C
  chmod +x "$T/bin/codex"
  rm -f "$OUT/invoked" "$OUT/prompt.txt"
}
# run_review:运行 plan-review.sh,设置 RC、ERR(stderr)、PROMPT(本次假 codex 收到的 prompt)
run_review() {
  local ef; ef=$(mktemp /tmp/rawf-prerr.XXXXXX)
  (cd "$T" && env CLAUDE_PROJECT_DIR="$T" PATH="$T/bin:$PATH" bash "$SCRIPTS/plan-review.sh" >/dev/null 2>"$ef"); RC=$?
  ERR=$(cat "$ef"); rm -f "$ef"
  PROMPT=$(cat "$OUT/prompt.txt" 2>/dev/null || true)
}
mode_line() { grep -m1 '^本轮模式:' <<<"$PROMPT"; }
