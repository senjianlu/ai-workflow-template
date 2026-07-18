#!/usr/bin/env bash
# review-readonly TC-04~TC-08 自测:指纹敏感性、锁、同轮唯一、
# codex 桩传参/无副本断言、桩篡改触发指纹否决。
# 输出为"断言 + 承重原始数据"全量模式:每条断言涉及的中间值(指纹、
# 退出码、完整 stderr、桩 argv、发布文件内容等)均原样打印。
set -uo pipefail

PROJ="/Users/xujinpeng/Projects/2026/ai-workflow-template"
REVIEW_SH="$PROJ/.ai-workflow/scripts/review.sh"
WORK=$(mktemp -d "$HOME/.review-ro-units-XXXXXX")
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
check() {
  local desc=$1; shift
  if "$@"; then echo "  OK  $desc"; pass=$((pass+1))
  else echo "  FAIL $desc"; fail=$((fail+1)); fi
}
dump() { # dump <标题> <文件>
  echo "  ---- RAW: $1 ----"
  if [ -s "$2" ]; then sed 's/^/  | /' "$2"; else echo "  | (空)"; fi
  echo "  ---- END ----"
}

# make_fixture <dir>:含 .ai-workflow、approved plan、实现记录、evidence 的夹具
make_fixture() {
  local fx=$1
  mkdir -p "$fx"
  cp -Rp "$PROJ/.ai-workflow" "$fx/.ai-workflow"
  cp -p "$PROJ/.gitignore" "$fx/.gitignore"
  local task_rel=".ai/2026-07-18/unit-fixture"
  mkdir -p "$fx/$task_rel/evidence"
  printf '%s' "$task_rel" > "$fx/.ai/.current-task"
  printf -- '---\nstatus: approved\ntask: unit-fixture\ndate: 2026-07-18\napproved_at: 2026-07-18\n---\n\n# 方案:新增 greet.sh\n\n## 测试用例\n| 编号 | 前置条件 | 步骤 | 预期结果 |\n|---|---|---|---|\n| TC-01 | 无 | bash greet.sh | 输出 hello,退出码 0 |\n' > "$fx/$task_rel/plan.md"
  printf -- '---\ntask: unit-fixture\nround: 01\ndate: 2026-07-18\n---\n\n# 实现记录:第 01 轮\n\n## 测试结果\n| 编号 | 结果 | 证据 |\n|---|---|---|\n| TC-01 | 通过 | evidence/tc01.txt |\n' > "$fx/$task_rel/implementation-round-01.md"
  mkdir -p "$fx/src"
  echo "base" > "$fx/src/main.js"
  ( cd "$fx" && git init -q && git config user.email t@t && git config user.name t \
      && git add -A && git commit -qm init ) || return 1
  printf '#!/bin/sh\necho hello\n' > "$fx/greet.sh"
  { echo "\$ bash greet.sh"; ( cd "$fx" && bash greet.sh ); echo "exit: $?"; } \
    > "$fx/$task_rel/evidence/tc01.txt" 2>&1
}

# codex 桩:记录 argv 与调用时刻的副本目录,按 --output-last-message 写 pass JSON
STUBDIR="$WORK/stub-bin"
mkdir -p "$STUBDIR"
cat > "$STUBDIR/codex" <<'STUB'
#!/bin/bash
printf '%s\n' "$@" > "$STUB_LOG"
ls -d /tmp/rawf-review-* "${TMPDIR:-/tmp}"/rawf-review-* 2>/dev/null > "$STUB_COPIES"
out=""; prev=""
for a in "$@"; do
  [ "$prev" = "--output-last-message" ] && out="$a"
  prev="$a"
done
if [ -n "${TAMPER_FILE:-}" ]; then echo tampered >> "$TAMPER_FILE"; fi
printf '{"verdict":"pass","issues":[],"overall":"stub"}\n' > "$out"
exit 0
STUB
chmod +x "$STUBDIR/codex"

echo "== TC-04 指纹敏感性(__workspace_hash)=="
fx4="$WORK/fx4"; make_fixture "$fx4" || exit 1
h_base=$(CLAUDE_PROJECT_DIR="$fx4" bash "$REVIEW_SH" __workspace_hash); rc_a=$?
echo "  \$ CLAUDE_PROJECT_DIR=<fx4> review.sh __workspace_hash   # 基线"
echo "  hash=$h_base rc=$rc_a"
echo "changed" >> "$fx4/src/main.js"
h_mod=$(CLAUDE_PROJECT_DIR="$fx4" bash "$REVIEW_SH" __workspace_hash); rc_b=$?
echo "  \$ echo changed >> src/main.js && review.sh __workspace_hash"
echo "  hash=$h_mod rc=$rc_b"
check "改动已跟踪文件后指纹变化" test "$h_base" != "$h_mod"
( cd "$fx4" && git checkout -q -- src/main.js )
h_restored=$(CLAUDE_PROJECT_DIR="$fx4" bash "$REVIEW_SH" __workspace_hash); rc_c=$?
echo "  \$ git checkout -- src/main.js && review.sh __workspace_hash"
echo "  hash=$h_restored rc=$rc_c"
check "还原后指纹回到基线" test "$h_base" = "$h_restored"
mkdir -p "$fx4/.claude"
echo '{"permissions":{}}' > "$fx4/.claude/settings.local.json"
h_claude=$(CLAUDE_PROJECT_DIR="$fx4" bash "$REVIEW_SH" __workspace_hash); rc_d=$?
echo "  \$ 写 .claude/settings.local.json 后 review.sh __workspace_hash"
echo "  hash=$h_claude rc=$rc_d"
check "仅写 .claude/ 指纹不变(排除生效)" test "$h_base" = "$h_claude"
check "四次调用退出码均为 0" test "$rc_a$rc_b$rc_c$rc_d" = "0000"

echo "== TC-05 并发锁 =="
fx5="$WORK/fx5"; make_fixture "$fx5" || exit 1
mkdir "$fx5/.ai/2026-07-18/unit-fixture/.review-lock"
err5="$WORK/tc05.stderr"
echo "  \$ mkdir <task>/.review-lock && PATH=<stub>:\$PATH review.sh"
PATH="$STUBDIR:$PATH" STUB_LOG="$WORK/l5" STUB_COPIES="$WORK/c5" \
  CLAUDE_PROJECT_DIR="$fx5" bash "$REVIEW_SH" >/dev/null 2>"$err5"
rc5=$?
echo "  rc=$rc5"
dump "TC-05 review.sh 完整 stderr" "$err5"
check "exit 3" test "$rc5" -eq 3
grep -q '已有评审在进行中' "$err5"
check "stderr 提示锁存在" test $? -eq 0

echo "== TC-06 同轮唯一(已有 review-round-01)=="
fx6="$WORK/fx6"; make_fixture "$fx6" || exit 1
echo done > "$fx6/.ai/2026-07-18/unit-fixture/review-round-01-pass.md"
err6="$WORK/tc06.stderr"
echo "  \$ 预置 review-round-01-pass.md && PATH=<stub>:\$PATH review.sh"
PATH="$STUBDIR:$PATH" STUB_LOG="$WORK/l6" STUB_COPIES="$WORK/c6" \
  CLAUDE_PROJECT_DIR="$fx6" bash "$REVIEW_SH" >/dev/null 2>"$err6"
rc6=$?
echo "  rc=$rc6"
dump "TC-06 review.sh 完整 stderr" "$err6"
check "exit 3" test "$rc6" -eq 3
grep -q '拒绝重评' "$err6"
check "stderr 提示拒绝重评" test $? -eq 0

echo "== TC-07 桩断言:只读传参、直审原仓库、运行期无副本、正常发布 =="
fx7="$WORK/fx7"; make_fixture "$fx7" || exit 1
log7="$WORK/l7"; copies7="$WORK/c7"; out7="$WORK/tc07.out"; err7="$WORK/tc07.err"
echo "  \$ PATH=<stub>:\$PATH CLAUDE_PROJECT_DIR=<fx7> review.sh"
echo "  fx7=$fx7"
PATH="$STUBDIR:$PATH" STUB_LOG="$log7" STUB_COPIES="$copies7" \
  CLAUDE_PROJECT_DIR="$fx7" bash "$REVIEW_SH" >"$out7" 2>"$err7"
rc7=$?
echo "  rc=$rc7"
dump "TC-07 桩记录的完整 argv(每行一个参数)" "$log7"
dump "TC-07 桩调用时刻 rawf-review-* 目录探测原始输出" "$copies7"
dump "TC-07 review.sh 完整 stdout" "$out7"
dump "TC-07 review.sh 完整 stderr" "$err7"
check "退出码 0" test "$rc7" -eq 0
grep -qx -- '--sandbox' "$log7" && grep -qx 'read-only' "$log7"
check "argv 含 --sandbox read-only" test $? -eq 0
grep -qx 'workspace-write' "$log7" && ww=0 || ww=1
check "argv 不含 workspace-write" test "$ww" -eq 1
cpath=$(awk 'p{print;exit} $0=="-C"{p=1}' "$log7")
echo "  argv 中 -C 的值:$cpath"
check "-C 指向夹具原仓库本身(直审,非副本)" test "$cpath" = "$fx7"
check "桩调用时刻无 rawf-review-* 副本目录" test ! -s "$copies7"
pub7="$fx7/.ai/2026-07-18/unit-fixture/review-round-01-pass.md"
check "review-round-01-pass.md 已发布" test -f "$pub7"
[ -f "$pub7" ] && dump "TC-07 发布的结论文件内容" "$pub7"
grep -qx 'review-round-01-pass.md' "$out7"
check "stdout 输出结论文件名" test $? -eq 0

echo "== TC-08 桩篡改已跟踪文件:指纹否决,不发布 =="
fx8="$WORK/fx8"; make_fixture "$fx8" || exit 1
err8="$WORK/tc08.stderr"; out8="$WORK/tc08.out"
echo "  \$ TAMPER_FILE=<fx8>/src/main.js PATH=<stub>:\$PATH review.sh"
PATH="$STUBDIR:$PATH" STUB_LOG="$WORK/l8" STUB_COPIES="$WORK/c8" \
  TAMPER_FILE="$fx8/src/main.js" \
  CLAUDE_PROJECT_DIR="$fx8" bash "$REVIEW_SH" >"$out8" 2>"$err8"
rc8=$?
echo "  rc=$rc8"
dump "TC-08 review.sh 完整 stderr" "$err8"
dump "TC-08 review.sh 完整 stdout" "$out8"
echo "  \$ ls <task_dir>/review-round-*.md"
ls "$fx8/.ai/2026-07-18/unit-fixture"/review-round-*.md 2>&1 | sed 's/^/  | /'
check "exit 3" test "$rc8" -eq 3
grep -q '主工作区在评审期间发生改动' "$err8"
check "stderr 提示评审无效" test $? -eq 0
shopt -s nullglob
pub8=("$fx8/.ai/2026-07-18/unit-fixture"/review-round-*.md)
shopt -u nullglob
check "无 review-round 文件发布(污染结果被否决)" test "${#pub8[@]}" -eq 0

echo
echo "结果:$pass 通过,$fail 失败"
test "$fail" -eq 0
