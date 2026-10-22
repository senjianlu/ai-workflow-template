# 测试公共库:临时项目搭建与断言。被 tc-NN.sh source。
set -u
ROOT=$(git rev-parse --show-toplevel)
SCRIPTS="$ROOT/.ai-workflow/scripts"
FAILS=0
ok()   { echo "  ok   - $1"; }
bad()  { echo "  FAIL - $1"; FAILS=$((FAILS+1)); }
assert_eq() { if [ "$2" = "$3" ]; then ok "$1 == $(printf %q "$3")"; else bad "$1: 期望 $(printf %q "$3"),实际 $(printf %q "$2")"; fi; }
assert_contains() { if grep -qF -- "$3" <<<"$2"; then ok "$1 含 $(printf %q "$3")"; else bad "$1 不含 $(printf %q "$3")"; fi; }
assert_not_contains() { if grep -qF -- "$3" <<<"$2"; then bad "$1 不应含 $(printf %q "$3")"; else ok "$1 不含 $(printf %q "$3")"; fi; }
assert_file() { if [ -f "$1" ]; then ok "存在 $1"; else bad "缺文件 $1"; fi; }
assert_nofile() { if [ -e "$1" ]; then bad "不应存在 $1"; else ok "不存在 $1"; fi; }
finish() { echo; if [ "$FAILS" -eq 0 ]; then echo "RESULT: all assertions passed"; exit 0; else echo "RESULT: $FAILS assertion(s) failed"; exit 1; fi; }

# new_proj <var> [task_rel]:建临时 git 项目,含 .ai-workflow 副本、.current-task、任务目录(evidence/)。
new_proj() {
  local d; d=$(mktemp -d /tmp/rawf-tc.XXXXXX)
  git -C "$d" init -q . && git -C "$d" commit -q --allow-empty -m init
  cp -r "$ROOT/.ai-workflow" "$d/.ai-workflow"
  local task=${2:-.ai/2026-10-22/t}
  mkdir -p "$d/$task/evidence"
  echo "$task" > "$d/.ai/.current-task"
  git -C "$d" add -A >/dev/null && git -C "$d" commit -q -m setup
  printf -v "$1" '%s' "$d"
}
# good_plan <proj> [task_rel]:写带 evidence_format 的 plan(TC-01 A、TC-02 A、TC-03 B、TC-04 C)
good_plan() {
  cat > "$1/${2:-.ai/2026-10-22/t}/plan.md" <<'P'
---
status: approved
task: t
evidence_format: v1
---
## 测试用例
| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | x | y | z | TC-01.log |
| TC-02 | A | x | y | z | TC-02.log |
| TC-03 | B | x | y | z | 文件:行号 |
| TC-04 | C | x | y | z | 陈述 |
## 风险
P
}
# good_record <proj> <NN> [task_rel]:与 good_plan 对应的实现记录(A 行引用 TC-01.log/TC-02.log)
good_record() {
  cat > "$1/${3:-.ai/2026-10-22/t}/implementation-round-$2.md" <<'R'
# 实现记录
## 测试结果
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | evidence.sh 产出 TC-01.log |
| TC-02 | A | pass | TC-02.log(exit 7 为预期) |
| TC-03 | B | pass | foo.sh:12 |
| TC-04 | C | pass | 看到了 |
## 与方案的偏差
无
R
}
# good_evidence <proj> [task_rel]:用 evidence.sh 真实产出 TC-01.log / TC-02.log
good_evidence() {
  local d=$1
  (cd "$d" && env CLAUDE_PROJECT_DIR="$d" bash "$SCRIPTS/evidence.sh" TC-01 -- bash -c 'echo one' >/dev/null 2>&1)
  (cd "$d" && env CLAUDE_PROJECT_DIR="$d" bash "$SCRIPTS/evidence.sh" TC-02 -- bash -c 'echo two; exit 7' >/dev/null 2>&1)
}
# fake_codex <proj> <outdir> [mode]:在 <proj>/bin 放假 codex;prompt 与标记写到 outdir(项目外,不动指纹)。
# mode: pass(默认,含 scope_findings ["X"])| noscope(无 scope_findings)| hang(sleep 613 不产出)
fake_codex() {
  local d=$1 out=$2 mode=${3:-pass}
  mkdir -p "$d/bin" "$out"
  cat > "$d/bin/codex" <<C
#!/usr/bin/env bash
out="$out"; mode="$mode"
touch "\$out/invoked"
last=
while [ \$# -gt 0 ]; do
  if [ "\$1" = "--output-last-message" ]; then last=\$2; shift 2; continue; fi
  prompt=\$1; shift
done
printf '%s' "\$prompt" > "\$out/prompt.txt"
case "\$mode" in
  hang) exec sleep 613 ;;
  noscope) printf '{"verdict":"pass","issues":[],"overall":"ok"}\n' > "\$last" ;;
  *) printf '{"verdict":"pass","issues":[],"scope_findings":["X"],"overall":"ok"}\n' > "\$last" ;;
esac
echo '{"type":"item.completed"}'
C
  chmod +x "$d/bin/codex"
}
