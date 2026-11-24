#!/usr/bin/env bash
# 执行 plan.md 的测试用例。用法:bash run.sh tcNN
# 在项目外(mktemp -d)构造 git 夹具并拷入改后的 .ai-workflow/;codex 桩复用
# .ai/2026-11-24/review-product-gate/assets/tests/stub-codex-bin/codex。
# 每条断言打印 [OK] / [FAIL];全部成立 exit 0,否则 exit 1。
set -uo pipefail

TESTS=$(cd "$(dirname "$0")" && pwd)
PROJ=$(cd "$TESTS/../../../../.." && pwd)
PREV="$PROJ/.ai/2026-11-24/review-product-gate/assets/tests"
STUB_BIN="$PREV/stub-codex-bin"
WORK=$(mktemp -d)
# RAWF_TEST_KEEP=1 时保留夹具目录供排查(路径打印在末尾)
cleanup() {
  chmod -R u+rw "$WORK" 2>/dev/null
  if [ "${RAWF_TEST_KEEP:-}" = 1 ]; then echo "夹具保留在:$WORK"; else rm -rf "$WORK"; fi
}
trap cleanup EXIT
export RAWF_REVIEW_POLL_SECONDS=1
unset CLAUDE_PROJECT_DIR STUB_OUT STUB_OUT_SEQ STUB_DIR STUB_TOUCH
TASK=.ai/2026-01-01/t
S='输入 x → 返回错误结果'

FAILS=0
ok() { echo "[OK] $*"; }
ng() { echo "[FAIL] $*"; FAILS=$((FAILS + 1)); }
check() { local d=$1; shift; if "$@"; then ok "$d"; else ng "$d"; fi; }
has() { grep -qF -- "$2" <<< "$1"; }       # has <文本> <子串>
hasnt() { ! grep -qF -- "$2" <<< "$1"; }
expect_rc() {
  if [ "$RC" -eq "$2" ]; then ok "$1(exit $2)"; else ng "$1:期望 exit $2,实际 $RC"; printf '%s\n' "$OUT" | sed 's/^/    | /'; fi
}

# --- 夹具 -------------------------------------------------------------------
# base_repo <名字> [提交前在夹具根执行的命令]:项目外 git 夹具,基线已提交
base_repo() {
  local fx="$WORK/$1" pre=${2:-}
  mkdir -p "$fx"
  (
    cd "$fx" || exit 1
    git init -q . && git config user.email t@example.invalid && git config user.name t || exit 1
    cp -r "$PROJ/.ai-workflow" . && cp "$PROJ/.gitignore" . || exit 1
    mkdir -p src
    printf 'def f():\n    return 1\n' > src/app.py
    if [ -n "$pre" ]; then eval "$pre" || exit 1; fi
    git add -A && git commit -qm init || exit 1
    mkdir -p "$TASK/evidence" "$TASK/assets"
    echo "$TASK" > .ai/.current-task
  ) >/dev/null 2>&1 || { echo "夹具 $1 构造失败" >&2; return 1; }
  echo "$fx"
}
write_plan() {   # write_plan <夹具>
  cat > "$1/$TASK/plan.md" <<'EOF'
---
status: approved
task: t
date: 2026-01-01
evidence_format: v1
---

# 方案

## 需求原文
> demo

## 非目标
无

## 实现方案
初稿。

## 测试用例
| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | - | - | - | evidence.sh |
EOF
}
write_record() {   # write_record <夹具> <NN>
  cat > "$1/$TASK/implementation-round-$2.md" <<EOF
# 实现记录:第 $2 轮

## 测试结果
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01.log |
EOF
}
impl_fixture() {   # impl_fixture <名字> [提交前命令]:base_repo + plan + 第 01 轮记录 + TC-01 证据
  local fx; fx=$(base_repo "$1" "${2:-}") || return 1
  write_plan "$fx"; write_record "$fx" 01
  ( cd "$fx" && CLAUDE_PROJECT_DIR="$fx" bash .ai-workflow/scripts/evidence.sh TC-01 -- true ) >/dev/null 2>&1 || return 1
  echo "$fx"
}
plan_fixture() {   # plan_fixture <名字>:base_repo + draft plan
  local fx; fx=$(base_repo "$1") || return 1
  write_plan "$fx"; sed -i 's/^status: approved/status: draft/' "$fx/$TASK/plan.md"
  echo "$fx"
}

# --- 运行与取证 ---------------------------------------------------------------
run_script() {   # run_script <夹具> <脚本名>:结果存 RC / OUT
  local fx=$1 script=$2
  OUT=$(cd "$fx" && PATH="$STUB_BIN:$PATH" CLAUDE_PROJECT_DIR="$fx" STUB_DIR="$WORK/stub-${fx##*/}" \
        bash ".ai-workflow/scripts/$script" 2>&1); RC=$?
}
run_review() { run_script "$1" review.sh; }
run_plan_review() { run_script "$1" plan-review.sh; }
calls() { local f="$WORK/stub-${1##*/}/calls"; if [ -f "$f" ]; then wc -l < "$f"; else echo 0; fi; }
prompt() { cat "$WORK/stub-${1##*/}/prompt-$2.txt" 2>/dev/null; }
reviews() {   # reviews <夹具> <文件名前缀>:匹配的评审文件个数
  local n=0 f
  for f in "$1/$TASK"/$2*.md; do [ -e "$f" ] && n=$((n + 1)); done
  echo "$n"
}
# in_manifest <清单> <路径>:清单的路径列(最后一列)里有这个路径
in_manifest() { cut -f5 "$1" | grep -qxF -- "$2"; }
not_in_manifest() { ! in_manifest "$1" "$2"; }

# --- 评审 JSON ---------------------------------------------------------------
impl_pass="$WORK/impl-pass.json"; impl_fail="$WORK/impl-fail.json"; plan_gate="$WORK/plan-gate.json"
jq -n '{issues: [], test_gaps: [], advisories: [], scope_findings: [], overall: "ok"}' > "$impl_pass"
jq -n --arg sc "$S" '{issues: [{id: "R-01", severity: "major", file: "src/app.py", line: 1, summary: "s",
       scenario: $sc, detail: "d"}], test_gaps: [], advisories: [], scope_findings: [], overall: "ok"}' > "$impl_fail"
jq -n '{issues: [{id: "R-01", severity: "major", category: "contract", summary: "s",
       consequence: "照此实现会返工", detail: "d"}], advisories: [], scope_findings: [], overall: "ok"}' > "$plan_gate"

# add_excludes <夹具> <追加的 --exclude 项>:在夹具的 hash_excludes 末尾追加(模拟项目自定义)
add_excludes() {
  sed -i "s|^  --exclude='.DS_Store'\$|  --exclude='.DS_Store'\n  $2|" "$1/.ai-workflow/scripts/review.sh"
  grep -qF -- "$2" "$1/.ai-workflow/scripts/review.sh"
}

# =============================================================================
tc01() {
  local fx td man snap p1 f
  # 夹具 a:项目自定义了排除清单(.open-next/、*.log 与反选的 audit.log)
  fx=$(impl_fixture a "mkdir -p .open-next && echo t0 > .open-next/tracked.js && sed -i '/^dist\\/\$/d' .gitignore && echo '*.log' >> .gitignore") \
    || { ng "(a) 夹具"; return; }
  td="$fx/$TASK"
  check "(a) 追加排除项" add_excludes "$fx" "--exclude='.open-next/' --exclude='*.log' --exclude='!audit.log'"
  ( cd "$fx" && echo a > .open-next/a.js && mkdir -p build-out && echo b > build-out/b.js \
      && mkdir -p .claude/skills/new .claude/skills/dist && echo n > .claude/skills/new/SKILL.md \
      && echo d > .claude/skills/dist/SKILL.md && echo log > audit.log && echo t1 >> .open-next/tracked.js ) \
    || ng "(a) 工作区改动"
  export STUB_OUT="$impl_pass"; unset STUB_OUT_SEQ
  run_review "$fx"; expect_rc "(a) review.sh" 0
  check "(a) 评审正常发布" [ -f "$td/review-round-01-pass.md" ]
  man="$td/.review-raw-01.manifest"; snap="$td/.review-raw-01.snap"
  for f in .open-next/a.js audit.log; do
    check "(a) 清单没有 $f" not_in_manifest "$man" "$f"
    check "(a) 快照没有 $f" [ ! -e "$snap/$f" ]
  done
  for f in build-out/b.js .claude/skills/new/SKILL.md .claude/skills/dist/SKILL.md .open-next/tracked.js; do
    check "(a) 清单有 $f" in_manifest "$man" "$f"
    check "(a) 快照有 $f" [ -f "$snap/$f" ]
  done
  p1=$(prompt "$fx" 1)
  check "(a) 指令给出本轮清单路径" has "$p1" "$TASK/.review-raw-01.manifest"
  check "(a) 指令写明不在清单中的未跟踪文件不属于评审对象" has "$p1" "不属于评审对象"

  # 夹具 b:不改排除清单;dist/ 没被 .gitignore 忽略,但在缺省的 hash_excludes 里
  fx=$(impl_fixture b "sed -i '/^dist\\/\$/d' .gitignore") || { ng "(b) 夹具"; return; }
  td="$fx/$TASK"
  ( cd "$fx" && mkdir -p dist && echo x > dist/x.js && echo '# c' >> src/app.py ) || ng "(b) 工作区改动"
  check "(b) dist/x.js 确实没有被 .gitignore 忽略" bash -c 'cd "$1" && ! git check-ignore -q dist/x.js' _ "$fx"
  run_review "$fx"; expect_rc "(b) review.sh" 0
  check "(b) 评审正常发布" [ -f "$td/review-round-01-pass.md" ]
  man="$td/.review-raw-01.manifest"; snap="$td/.review-raw-01.snap"
  check "(b) 清单没有 dist/x.js" not_in_manifest "$man" dist/x.js
  check "(b) 快照没有 dist/x.js" [ ! -e "$snap/dist/x.js" ]
  check "(b) 清单有被改动的 src/app.py" in_manifest "$man" src/app.py
  p1=$(prompt "$fx" 1)
  check "(b) 指令给出本轮清单路径" has "$p1" "$TASK/.review-raw-01.manifest"
  check "(b) 指令写明不在清单中的未跟踪文件不属于评审对象" has "$p1" "不属于评审对象"
}

tc06() {
  local fx td p2 v
  for v in c d; do
    fx=$(impl_fixture "$v") || { ng "($v) 夹具"; continue; }
    td="$fx/$TASK"
    ( cd "$fx" && mkdir -p .open-next && echo a > .open-next/a.js && echo '# r1' >> src/app.py ) || ng "($v) 工作区改动"
    mkdir -p "$WORK/seq-$v"; cp "$impl_fail" "$WORK/seq-$v/1.json"
    export STUB_OUT_SEQ="$WORK/seq-$v" STUB_OUT="$impl_pass"
    run_review "$fx"; expect_rc "($v) 第 1 轮" 1
    check "($v) 第 1 轮清单含 .open-next/a.js" in_manifest "$td/.review-raw-01.manifest" .open-next/a.js
    case "$v" in
      c) check "(c) 第 1 轮后给排除清单加上 .open-next/" add_excludes "$fx" "--exclude='.open-next/'" ;;
      d) sed -i 's/^\(head\t[0-9a-f]*\)\t.*$/\1/' "$td/.review-raw-01.manifest"
         check "(d) 上一轮清单的 head 行已去掉口径一列" [ "$(grep -c $'^head\t[0-9a-f]*$' "$td/.review-raw-01.manifest")" -eq 1 ] ;;
    esac
    ( cd "$fx" && echo '# r2' >> src/app.py )
    write_record "$fx" 02
    run_review "$fx"; expect_rc "($v) 第 2 轮" 0
    check "($v) 第 2 轮评审正常发布" [ -f "$td/review-round-02-pass.md" ]
    p2=$(prompt "$fx" 2)
    check "($v) 第 2 轮回退为全量评审" has "$p2" "本轮模式:全量评审"
    check "($v) 注明纳入口径不同" has "$p2" "纳入口径不同"
    check "($v) 不是修复核验" hasnt "$p2" "本轮模式:修复核验"
    check "($v) 指令附有上一轮评审文件路径" has "$p2" "$TASK/review-round-01-fail.md"
    check "($v) 指令附有本轮清单路径" has "$p2" "$TASK/.review-raw-02.manifest"
    check "($v) 没有把 .open-next/a.js 列为删除" hasnt "$p2" '`.open-next/a.js`'
  done
  unset STUB_OUT_SEQ
}

# big_plan <夹具>:把 plan 撑到约 40 KiB(700 行)
big_plan() {
  local i
  for i in $(seq 1 700); do
    printf '原始内容第 %s 行:0123456789abcdefghijklmnopqrstuvwxyz0123456789\n' "$i"
  done >> "$1/$TASK/plan.md"
}

tc02() {
  local fx td p2 dfile
  export STUB_OUT="$plan_gate"; unset STUB_OUT_SEQ

  # 夹具 a:短 plan,小修订 → diff 内联
  fx=$(plan_fixture a) || { ng "(a) 夹具"; return; }
  td="$fx/$TASK"
  run_plan_review "$fx"; expect_rc "(a) 第 1 轮" 1
  echo '修订一行。' >> "$td/plan.md"
  run_plan_review "$fx"; expect_rc "(a) 第 2 轮" 1
  p2=$(prompt "$fx" 2)
  check "(a) 第 2 轮指令内联了 diff(代码栅栏)" has "$p2" '```diff'
  check "(a) 内联的 diff 含追加的那一行" has "$p2" '+修订一行。'
  check "(a) 没有落盘文件" [ ! -e "$td/.plan-review-raw-02.diff" ]

  # 夹具 b:约 40 KiB 的 plan,大部分行被改写 → diff 落盘
  fx=$(plan_fixture b) || { ng "(b) 夹具"; return; }
  td="$fx/$TASK"
  big_plan "$fx"
  check "(b) plan 超过 32 KiB" [ "$(wc -c < "$td/plan.md")" -gt 32768 ]
  run_plan_review "$fx"; expect_rc "(b) 第 1 轮" 1
  sed -i 's/^原始内容/修订内容/' "$td/plan.md"
  run_plan_review "$fx"; expect_rc "(b) 第 2 轮" 1
  check "(b) 第 2 轮评审正常发布" [ -f "$td/plan-review-round-02-fail.md" ]
  p2=$(prompt "$fx" 2); dfile="$td/.plan-review-raw-02.diff"
  check "(b) 第 2 轮指令不含代码栅栏" hasnt "$p2" '```diff'
  check "(b) 指令给出落盘文件路径" has "$p2" "$TASK/.plan-review-raw-02.diff"
  check "(b) 落盘文件存在" [ -f "$dfile" ]
  check "(b) 修订 diff 确实超过 16384 字节" [ "$(wc -c < "$dfile")" -gt 16384 ]
  check "(b) 指令给出该文件的字节数" has "$p2" "$(($(wc -c < "$dfile") - 1)) 字节"
  check "(b) 指令不超过 65536 字节" [ "$(printf '%s' "$p2" | wc -c)" -le 65536 ]
  diff -u --label "第 01 轮所审 plan.md" --label "本轮所审 plan.md" \
    "$td/.plan-review-raw-01.plan.md" "$td/.plan-review-raw-02.plan.md" > "$WORK/expected.diff"
  check "(b) 落盘内容与对两轮快照做 diff -u 的输出逐字节一致" cmp -s "$WORK/expected.diff" "$dfile"
}

tc03() {
  local fx td
  export STUB_OUT="$plan_gate"; unset STUB_OUT_SEQ

  # (1) 需要落盘而落盘路径被目录占用 → exit 3、不消耗轮次;移走后同一轮可重跑
  fx=$(plan_fixture occ-big) || { ng "(1) 夹具"; return; }
  td="$fx/$TASK"
  big_plan "$fx"
  run_plan_review "$fx"; expect_rc "(1) 第 1 轮" 1
  mkdir -p "$td/.plan-review-raw-02.diff/sub"
  sed -i 's/^原始内容/修订内容/' "$td/plan.md"
  run_plan_review "$fx"; expect_rc "(1) 落盘路径被占用" 3
  check "(1) 提示无法清理落盘路径" has "$OUT" "无法清理修订 diff 的落盘路径"
  check "(1) 桩未被再次调用" [ "$(calls "$fx")" -eq 1 ]
  check "(1) 没有第 2 轮评审文件" [ "$(reviews "$fx" plan-review-round-02-)" -eq 0 ]
  rm -rf "$td/.plan-review-raw-02.diff"
  run_plan_review "$fx"; expect_rc "(1) 移走后重跑" 1
  check "(1) 重跑发布的仍是第 02 轮" [ -f "$td/plan-review-round-02-fail.md" ]
  check "(1) 重跑后 diff 已落盘" [ -f "$td/.plan-review-raw-02.diff" ]

  # (2) 不需要落盘时,落盘路径被占用不影响评审
  fx=$(plan_fixture occ-small) || { ng "(2) 夹具"; return; }
  td="$fx/$TASK"
  run_plan_review "$fx"; expect_rc "(2) 第 1 轮" 1
  mkdir -p "$td/.plan-review-raw-02.diff/sub"
  echo '修订一行。' >> "$td/plan.md"
  run_plan_review "$fx"; expect_rc "(2) 第 2 轮照常评审" 1
  check "(2) 第 2 轮评审正常发布" [ -f "$td/plan-review-round-02-fail.md" ]
  check "(2) 占位目录未被动过" [ -d "$td/.plan-review-raw-02.diff/sub" ]

  # (3) 指令模板本身超长 → exit 3,给出明确报错,不调用 codex
  fx=$(plan_fixture huge-template) || { ng "(3) 夹具"; return; }
  td="$fx/$TASK"
  head -c 110000 /dev/zero | tr '\0' 'x' >> "$fx/.ai-workflow/prompts/plan-review.md"
  run_plan_review "$fx"; expect_rc "(3) 指令超长" 3
  check "(3) 提示指令超过长度上限" has "$OUT" "超过上限"
  check "(3) 桩未被调用" [ "$(calls "$fx")" -eq 0 ]
  check "(3) 没有评审文件" [ "$(reviews "$fx" plan-review-round-)" -eq 0 ]
}

tc04() {
  local t f
  for t in tc03 tc06 tc10; do
    OUT=$(bash "$PREV/run.sh" "$t" 2>&1); RC=$?
    expect_rc "上一个任务的回归用例 $t" 0
    check "$t 没有失败断言" hasnt "$OUT" "[FAIL]"
  done
  for f in review.sh plan-review.sh; do
    check "bash -n $f" bash -n "$PROJ/.ai-workflow/scripts/$f"
  done
}

tc05() {
  local entry
  cd "$PROJ" || { ng "cd"; return; }
  check "CHANGELOG 有 [1.5.1] 条目" grep -q '^## \[1\.5\.1\]' CHANGELOG.md
  entry=$(awk '/^## \[1\.5\.1\]/ { on = 1; next } /^## \[/ { on = 0 } on' CHANGELOG.md)
  check "1.5.1 条目含「升级指引」" has "$entry" "### 升级指引"
  check "1.5.1 条目排在 1.5.0 之前" [ "$(grep -n '^## \[1\.5\.1\]' CHANGELOG.md | cut -d: -f1)" -lt "$(grep -n '^## \[1\.5\.0\]' CHANGELOG.md | cut -d: -f1)" ]
  check "TEMPLATE-VERSION 为 1.5.1" grep -qx 'version: 1.5.1' .ai-workflow/TEMPLATE-VERSION
  check "README 的 plan 评审一条提到超长 diff 落盘" grep -q '超过 16 KiB 时落盘' README.md
  check "实现评审指令写明评审对象以本轮清单为准" grep -q '评审对象以下方「本轮上下文」给出的文件清单为准' .ai-workflow/prompts/review.md
  check "评审标准写明评审对象以本轮清单为准" grep -q '评审对象以 review.sh 给出的本轮清单为准' .ai-workflow/review-standards.md
}

case "${1:-}" in
  tc01|tc02|tc03|tc04|tc05|tc06) "$1" ;;
  *) echo "用法:bash run.sh tc01..tc06" >&2; exit 2 ;;
esac
echo "失败断言数:$FAILS"
[ "$FAILS" -eq 0 ]
