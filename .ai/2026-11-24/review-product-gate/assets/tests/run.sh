#!/usr/bin/env bash
# 执行 plan.md 的测试用例。用法:bash run.sh tcNN
# 在项目外(mktemp -d)构造 git 夹具并拷入改后的 .ai-workflow/;除 tc08 外都用
# codex 桩(stub-codex-bin/codex)。每条断言打印 [OK] / [FAIL];全部成立 exit 0,
# 否则 exit 1。
set -uo pipefail

TESTS=$(cd "$(dirname "$0")" && pwd)
PROJ=$(cd "$TESTS/../../../../.." && pwd)
STUB_BIN="$TESTS/stub-codex-bin"
WORK=$(mktemp -d)
# RAWF_TEST_KEEP=1 时保留夹具目录供排查(路径打印在末尾)
cleanup() {
  chmod -R u+rw "$WORK" 2>/dev/null
  if [ "${RAWF_TEST_KEEP:-}" = 1 ]; then echo "夹具保留在:$WORK"; else rm -rf "$WORK"; fi
}
trap cleanup EXIT
export RAWF_REVIEW_POLL_SECONDS=1
unset CLAUDE_PROJECT_DIR STUB_OUT STUB_OUT_SEQ STUB_DIR STUB_TOUCH EXTRA_BIN REAL_CP
TASK=.ai/2026-01-01/t
S='输入 x → 返回错误结果'

FAILS=0
ok() { echo "[OK] $*"; }
ng() { echo "[FAIL] $*"; FAILS=$((FAILS + 1)); }
check() { local d=$1; shift; if "$@"; then ok "$d"; else ng "$d"; fi; }
has() { grep -qF -- "$2" <<< "$1"; }       # has <文本> <子串>
hasnt() { ! grep -qF -- "$2" <<< "$1"; }
empty() { [ -z "$1" ]; }
nonempty() { [ -n "$1" ]; }
quiet() { "$@" >/dev/null 2>&1; }
# sect <评审文件> <节标题前缀>:输出该节(从 "## 标题" 到下一个 "## " 之前)
sect() { [ -f "$1" ] && awk -v h="$2" '/^## / { on = (index($0, h) == 4) } on' "$1"; }
# expect_rc <说明> <期望退出码>:比对 RC,不符时打印脚本输出
expect_rc() {
  if [ "$RC" -eq "$2" ]; then ok "$1(exit $2)"; else ng "$1:期望 exit $2,实际 $RC"; printf '%s\n' "$OUT" | sed 's/^/    | /'; fi
}

# --- 夹具 -------------------------------------------------------------------
# base_repo <名字>:项目外 git 夹具,基线已提交,任务目录与 .current-task 就绪
base_repo() {
  local fx="$WORK/$1"
  mkdir -p "$fx"
  (
    cd "$fx" || exit 1
    git init -q . && git config user.email t@example.invalid && git config user.name t || exit 1
    cp -r "$PROJ/.ai-workflow" . && cp "$PROJ/.gitignore" . || exit 1
    mkdir -p src tests docs scripts .claude/skills/demo
    printf 'def f():\n    return 1\n' > src/app.py
    printf 'def g():\n    return 2\n' > src/other.py
    printf 'x = 1\n' > src/gone.py
    printf 'def test_f():\n    assert True\n' > tests/test_app.py
    echo '# doc' > docs/x.md
    printf '#!/bin/sh\necho hi\n' > scripts/run.sh
    echo 'demo skill' > .claude/skills/demo/SKILL.md
    ln -s src/app.py link
    git add -A && git commit -qm init || exit 1
    mkdir -p "$TASK/evidence" "$TASK/assets"
    echo "$TASK" > .ai/.current-task
  ) >/dev/null 2>&1 || { echo "夹具 $1 构造失败" >&2; return 1; }
  echo "$fx"
}
write_plan() {   # write_plan <夹具> [用例表行]
  local rows=${2:-'| TC-01 | A | - | - | - | evidence.sh |'}
  cat > "$1/$TASK/plan.md" <<EOF
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
$rows
EOF
}
write_record() {   # write_record <夹具> <NN> [结果表行]
  local rows=${3:-'| TC-01 | A | pass | TC-01.log |'}
  cat > "$1/$TASK/implementation-round-$2.md" <<EOF
# 实现记录:第 $2 轮

## 测试结果
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
$rows
EOF
}
ev() {   # ev <夹具> <evidence.sh 的参数...>
  local fx=$1; shift
  ( cd "$fx" && CLAUDE_PROJECT_DIR="$fx" bash .ai-workflow/scripts/evidence.sh "$@" ) >/dev/null 2>&1
}
impl_fixture() {   # base_repo + plan + 第 01 轮记录 + TC-01 证据(exit 0)
  local fx; fx=$(base_repo "$1") || return 1
  write_plan "$fx"; write_record "$fx" 01; ev "$fx" TC-01 -- true
  echo "$fx"
}
plan_fixture() {   # base_repo + draft plan
  local fx; fx=$(base_repo "$1") || return 1
  write_plan "$fx"; sed -i 's/^status: approved/status: draft/' "$fx/$TASK/plan.md"
  echo "$fx"
}

# --- 运行与取证 ---------------------------------------------------------------
run_script() {   # run_script <夹具> <脚本名> [参数...]:结果存 RC / OUT
  # EXTRA_BIN(可选)排在 PATH 最前,用来放 cp 之类的替身
  local fx=$1 script=$2; shift 2
  OUT=$(cd "$fx" && PATH="${EXTRA_BIN:+$EXTRA_BIN:}$STUB_BIN:$PATH" CLAUDE_PROJECT_DIR="$fx" \
        STUB_DIR="$WORK/stub-${fx##*/}" bash ".ai-workflow/scripts/$script" "$@" 2>&1); RC=$?
}
run_review() { run_script "$1" review.sh; }
run_plan_review() { run_script "$1" plan-review.sh; }
run_evcheck() { run_script "$1" evidence-check.sh; }
calls() { local f="$WORK/stub-${1##*/}/calls"; if [ -f "$f" ]; then wc -l < "$f"; else echo 0; fi; }
prompt() { cat "$WORK/stub-${1##*/}/prompt-$2.txt" 2>/dev/null; }
reviews() {   # reviews <夹具> <glob 前缀>:匹配的评审文件个数
  local n=0 f
  for f in "$1/$TASK"/$2*.md; do [ -e "$f" ] && n=$((n + 1)); done
  echo "$n"
}

# --- 评审 JSON 构造 -----------------------------------------------------------
issue() {   # issue <severity> <id> <file> <scenario> [line]
  jq -cn --arg sev "$1" --arg id "$2" --arg f "$3" --arg sc "$4" --argjson l "${5:-0}" \
    '{id: $id, severity: $sev, file: $f, line: $l, summary: ("summary " + $id), scenario: $sc, detail: "detail"}'
}
impl_json() {   # impl_json <输出文件> <issue 对象,每行一个> [test_gaps] [advisories] [scope]
  printf '%s\n' "$2" | jq -s --argjson t "${3:-[]}" --argjson a "${4:-[]}" --argjson s "${5:-[]}" \
    '{issues: ., test_gaps: $t, advisories: $a, scope_findings: $s, overall: "ok"}' > "$1"
}
pissue() {   # pissue <severity> <id> <category> <consequence>
  jq -cn --arg sev "$1" --arg id "$2" --arg c "$3" --arg cq "$4" \
    '{id: $id, severity: $sev, category: $c, summary: ("summary " + $id), consequence: $cq, detail: "detail"}'
}
plan_json() {   # plan_json <输出文件> <issue 对象,每行一个> [advisories] [scope]
  printf '%s\n' "$2" | jq -s --argjson a "${3:-[]}" --argjson s "${4:-[]}" \
    '{issues: ., advisories: $a, scope_findings: $s, overall: "ok"}' > "$1"
}

# =============================================================================
tc01() {
  local fx f adv q id
  one() {   # one <名字> <期望 exit>:建夹具、跑一次完整评审,设置 fx 与 f
    fx=$(impl_fixture "$1") || { ng "($1) 夹具"; return 1; }
    [ -n "${3:-}" ] && eval "$3"
    export STUB_OUT="$WORK/$1.json"; run_review "$fx"
    expect_rc "($1) review.sh" "$2"
    if [ "$2" -eq 0 ]; then f="$fx/$TASK/review-round-01-pass.md"; else f="$fx/$TASK/review-round-01-fail.md"; fi
    check "($1) 发布 ${f##*/}" [ -f "$f" ]
    adv=$(sect "$f" 建议); q=$(sect "$f" 问题清单)
  }

  impl_json "$WORK/i.json" "$(issue major R-01 tests/test_app.py "$S"; issue major R-02 "$TASK/assets/check.sh" "$S"; issue major R-03 docs/x.md "$S")"
  one i 0 && {
    for id in R-01 R-02 R-03; do check "(i) $id 在建议节并带非产品路径标记" has "$adv" "$id 〔降级:非产品路径〕"; done
    check "(i) 问题清单不含这三条" hasnt "$q" "R-0"
  }

  impl_json "$WORK/ii.json" "$(issue major R-01 src/app.py "$S" 2)"
  one ii 1 && check "(ii) R-01 在问题清单" has "$q" "[major] R-01"

  impl_json "$WORK/iii.json" "$(issue major R-01 src/app.py '   ' 2)"
  one iii 0 && check "(iii) R-01 在建议节并带缺失败场景标记" has "$adv" "R-01 〔降级:缺失败场景〕"

  impl_json "$WORK/iv.json" "$(issue minor R-01 tests/test_app.py '')"
  one iv 0 && {
    check "(iv) minor 在建议节并带非产品路径标记" has "$adv" "[minor] R-01 〔降级:非产品路径〕"
    check "(iv) minor 不在问题清单" hasnt "$q" "R-01"
  }

  impl_json "$WORK/v.json" "$(issue plan-blocker R-01 tests/test_app.py "$S"; issue plan-blocker R-02 "$TASK/plan.md" "$S")" '[]' '[]' '["scope-item-1"]'
  one v 0 && {
    check "(v) 指向 plan.md 的 plan-blocker 置顶在问题清单" has "$(printf '%s\n' "$q" | sed -n '2p')" "[plan-blocker] R-02"
    check "(v) 指向测试文件的 plan-blocker 在建议节" has "$adv" "[plan-blocker] R-01 〔降级:非产品路径〕"
    check "(v) 范围核对节照常渲染" has "$(sect "$f" 范围核对)" "scope-item-1"
  }

  impl_json "$WORK/vi.json" "$(issue major R-01 docs/site/page.md "$S")"
  one vi 1 "mkdir -p \"\$fx/docs/site\" && echo page > \"\$fx/docs/site/page.md\" && sed -i \"s|^product_globs=()|product_globs=('/docs/site/')|\" \"\$fx/.ai-workflow/scripts/review.sh\"" \
    && check "(vi) 产品路径例外下的问题留在问题清单" has "$q" "[major] R-01"

  impl_json "$WORK/vii.json" "$(issue major R-01 src/nonexistent.py "$S")"
  one vii 1 && check "(vii) 无法定位的路径按产品路径处理" has "$q" "[major] R-01"

  # (viii) 需要夹具路径,先建夹具再生成 JSON
  fx=$(impl_fixture viii) || { ng "(viii) 夹具"; return; }
  impl_json "$WORK/viii.json" "$(issue major R-01 ./src/app.py "$S"; issue major R-02 "$fx/src/app.py" "$S"; issue major R-03 src/app.py:12 "$S"; issue major R-04 tests/../src/app.py "$S"; issue major R-05 src/../docs/x.md "$S")"
  export STUB_OUT="$WORK/viii.json"; run_review "$fx"; expect_rc "(viii) review.sh" 1
  f="$fx/$TASK/review-round-01-fail.md"; adv=$(sect "$f" 建议); q=$(sect "$f" 问题清单)
  for id in R-01 R-02 R-03 R-04; do check "(viii) $id 归为产品路径,在问题清单" has "$q" "[major] $id"; done
  check "(viii) R-05 在建议节并带非产品路径标记" has "$adv" "R-05 〔降级:非产品路径〕"
  check "(viii) R-05 不在问题清单" hasnt "$q" "R-05"

  impl_json "$WORK/ix.json" "$(issue major R-01 tests/test_app.py "$S"; issue major R-02 tests/test_app.py "$S")" \
    '["g1","g2","g3","g4","g5"]' '["a1","a2","a3","a4","a5","a6","a7","a8"]'
  one ix 0 && {
    local tg; tg=$(sect "$f" 测试缺口)
    check "(ix) 测试缺口恰 3 条" [ "$(grep -c '^- T-' <<< "$tg")" -eq 3 ]
    check "(ix) 测试缺口编号 T-01 ~ T-03" has "$tg" "- T-03 g3"
    check "(ix) 自拟建议恰 5 条" [ "$(grep -c '^- A-' <<< "$adv")" -eq 5 ]
    check "(ix) 自拟建议编号到 A-05" has "$adv" "- A-05 a5"
    check "(ix) 注明另有 3 条未列出" has "$adv" "另有 3 条"
    check "(ix) 降级条目 R-01 保留" has "$adv" "R-01 〔降级:非产品路径〕"
    check "(ix) 降级条目 R-02 保留" has "$adv" "R-02 〔降级:非产品路径〕"
  }

  # 以下两组是第 1 轮评审之后补的回归断言(impl/01/R-01、R-02 与测试缺口 T-01、T-02)
  # (x) 失败场景分两段、中间有空行:不是空白,不得降级
  impl_json "$WORK/x.json" "$(issue major R-01 src/app.py $'触发条件:输入 x\n\n错误结果:返回 None' 2)"
  one x 1 && check "(x) 中间有空行的失败场景不被当作空白" has "$q" "[major] R-01"

  # (xi) 目录按路径组件匹配、文件名规则只匹配 basename
  impl_json "$WORK/xi.json" "$(issue major R-01 apps/test_management/api.py "$S"; issue major R-02 mytests/x.py "$S"; \
    issue major R-03 sub/README.md "$S"; issue major R-04 docs2/x.md "$S"; issue major R-05 a/tests/x.py "$S"; \
    issue major R-06 pkg/test_util.py "$S"; issue major R-07 web/app.test.ts "$S"; issue major R-08 pkg/conftest.py "$S"; \
    issue major R-09 README.md "$S")"
  one xi 1 && {
    for id in R-01 R-02 R-03 R-04; do check "(xi) $id 是产品路径,留在问题清单" has "$q" "[major] $id"; done
    for id in R-05 R-06 R-07 R-08 R-09; do check "(xi) $id 是非产品路径,降为建议" has "$adv" "$id 〔降级:非产品路径〕"; done
  }
}

tc02() {
  local fx f q adv i list=
  fx=$(impl_fixture cap) || { ng "夹具"; return; }
  for i in 1 2 3 4 5 6 7; do list+="$(issue major "R-0$i" src/app.py "$S" "$i")"$'\n'; done
  list+="$(issue blocker R-08 src/app.py "$S" 8)"
  impl_json "$WORK/cap.json" "$list"
  export STUB_OUT="$WORK/cap.json"; run_review "$fx"; expect_rc "review.sh" 1
  f="$fx/$TASK/review-round-01-fail.md"; q=$(sect "$f" 问题清单); adv=$(sect "$f" 建议)
  check "8 条全部在问题清单" [ "$(grep -c '^- \[' <<< "$q")" -eq 8 ]
  check "blocker 排第一" has "$(grep '^- \[' <<< "$q" | sed -n '1p')" "[blocker] R-08"
  check "major 保持原顺序" [ "$(grep -o '^- \[major\] R-0[0-9]' <<< "$q" | tr -d '\n')" = "- [major] R-01- [major] R-02- [major] R-03- [major] R-04- [major] R-05- [major] R-06- [major] R-07" ]
  check "建议节没有这 8 条" hasnt "$adv" "R-0"
}

# round1 <夹具>:第 1 轮前的改动 + 第 1 轮评审(桩返回 fail,另带一条产品 minor)
round1() {
  local fx=$1
  ( cd "$fx" && echo '# r1' >> src/app.py && echo '# r1' >> src/other.py && echo 'echo r1' >> scripts/run.sh \
      && echo 'r1' >> .claude/skills/demo/SKILL.md && echo n1 > "$TASK/assets/note.txt" ) || return 1
  mkdir -p "$WORK/seq-${fx##*/}"
  impl_json "$WORK/seq-${fx##*/}/1.json" "$(issue major R-01 src/app.py "$S" 1; issue minor R-02 src/app.py '' 2)"
  impl_json "$WORK/pass.json" ""
  export STUB_OUT_SEQ="$WORK/seq-${fx##*/}" STUB_OUT="$WORK/pass.json"
  run_review "$fx"
}

tc03() {
  local fx td p1 p2 list name
  fx=$(impl_fixture ctx) || { ng "夹具"; return; }
  td="$fx/$TASK"
  round1 "$fx"; expect_rc "第 1 轮" 1
  ( cd "$fx" && echo '# r2' >> src/app.py && chmod +x scripts/run.sh && git checkout -q -- src/other.py \
      && echo 'r2' >> .claude/skills/demo/SKILL.md && echo n2 >> "$TASK/assets/note.txt" \
      && echo 'new = 1' > src/new.py && rm src/gone.py && rm link && ln -s src/other.py link ) || ng "第 2 轮改动"
  write_record "$fx" 02
  run_review "$fx"; expect_rc "第 2 轮" 0
  p1=$(prompt "$fx" 1); p2=$(prompt "$fx" 2)
  check "第 1 轮指令模式为全量评审" has "$p1" "本轮模式:全量评审"
  check "第 2 轮指令模式为修复核验" has "$p2" "本轮模式:修复核验"
  check "第 2 轮指令含上一轮评审文件路径" has "$p2" "$TASK/review-round-01-fail.md"
  check "第 2 轮指令含轮间差异文件路径" has "$p2" "$TASK/.review-raw-02.delta.diff"
  check "轮间差异文件存在" [ -f "$td/.review-raw-02.delta.diff" ]
  list=$(grep '^- `.*`(' <<< "$p2")
  for name in src/app.py scripts/run.sh src/other.py .claude/skills/demo/SKILL.md src/new.py src/gone.py link; do
    check "变化文件列表含 $name" has "$list" "- \`$name\`("
  done
  check "变化文件列表恰 7 项" [ "$(grep -c . <<< "$list")" -eq 7 ]
  check "变化文件列表不含 .ai/ 下文件" hasnt "$p2" "note.txt"
  check "可执行位一项标为元数据变化" has "$(grep -F '`scripts/run.sh`' <<< "$list")" "元数据变化:可执行位"
  check "符号链接一项标为元数据变化" has "$(grep -F '`link`' <<< "$list")" "元数据变化:符号链接"
  check "第 1 轮指令不残留占位" hasnt "$p1" "{{"
  check "第 2 轮指令不残留占位" hasnt "$p2" "{{"
  run_script "$fx" review.sh __minors "$TASK"
  check "__minors 仍含第 1 轮的 minor" has "$OUT" "| impl/01/R-02 | minor:"

  # 回退:上一轮的清单 / 评审文件 / 快照缺失,或 HEAD 变化 → 全量评审
  # legacy-incompatible 是第 3 轮评审之后补的(impl/03/R-01、T-01):上一轮清单没有格式
  # 标记且含 %(旧写法,路径未统一编码)→ 不按当前格式解读,回退全量评审
  local v
  for v in no-manifest no-review no-snap head-moved legacy-incompatible; do
    fx=$(impl_fixture "fb-$v") || { ng "($v) 夹具"; continue; }
    td="$fx/$TASK"
    round1 "$fx"
    case "$v" in
      legacy-incompatible)
        sed -i '1d' "$td/.review-raw-01.manifest"
        printf 'F\t-\tdeadbeef\t1\tsrc/rate%%25.py\n' >> "$td/.review-raw-01.manifest" ;;
      no-manifest) rm -f "$td/.review-raw-01.manifest" ;;
      no-review) rm -f "$td/review-round-01-fail.md" ;;
      no-snap) rm -rf "$td/.review-raw-01.snap" ;;
      head-moved) ( cd "$fx" && git add -A && git commit -qm wip ) >/dev/null 2>&1 ;;
    esac
    ( cd "$fx" && echo '# r2' >> src/app.py )
    write_record "$fx" 02
    run_review "$fx"; expect_rc "($v) 第 2 轮" 0
    p2=$(prompt "$fx" 2)
    check "($v) 第 2 轮模式为全量评审" has "$p2" "本轮模式:全量评审"
    check "($v) 第 2 轮不是修复核验" hasnt "$p2" "本轮模式:修复核验"
  done

  # 第 3 轮评审之后补的(impl/03/R-01):没有格式标记但通篇不含 % 的旧清单,与当前格式
  # 逐字节等价,照常做修复核验
  fx=$(impl_fixture fb-legacy-ok) || { ng "(旧清单可读) 夹具"; return; }
  td="$fx/$TASK"
  round1 "$fx"
  sed -i '1d' "$td/.review-raw-01.manifest"
  ( cd "$fx" && echo '# r2' >> src/app.py )
  write_record "$fx" 02
  run_review "$fx"; expect_rc "(旧清单可读) 第 2 轮" 0
  check "(旧清单可读) 第 2 轮仍为修复核验" has "$(prompt "$fx" 2)" "本轮模式:修复核验"
  check "(旧清单可读) 本轮清单带格式标记" [ "$(head -n 1 "$td/.review-raw-02.manifest")" = $'rawf-manifest\t1' ]

  # 第 3 轮评审之后补的(impl/03/R-04):证据报告不需要落盘时,落盘路径被目录占用不影响
  # 评审(需要落盘而被占用的情形见 tc10 的"长证据"夹具)
  fx=$(impl_fixture ev-occupied) || { ng "(证据路径占用) 夹具"; return; }
  td="$fx/$TASK"
  impl_json "$WORK/pass.json" ""
  unset STUB_OUT_SEQ; export STUB_OUT="$WORK/pass.json"
  mkdir -p "$td/.review-raw-01.evidence.md/sub"
  run_review "$fx"; expect_rc "(证据路径占用) 报告内联时照常评审" 0
  check "(证据路径占用) 占用的目录未被动过" [ -d "$td/.review-raw-01.evidence.md/sub" ]

  # 第 4 轮评审之后补的(impl/04/R-03、T-03):项目目录不存在时,启动阶段就以 3 结束
  # (不是 1),调用方不会把它读成"评审不通过"
  fx=$(impl_fixture gone) || { ng "(项目目录不存在) 夹具"; return; }
  OUT=$(cd "$fx" && PATH="$STUB_BIN:$PATH" CLAUDE_PROJECT_DIR="$WORK/no-such-dir" STUB_DIR="$WORK/stub-gone" \
        bash .ai-workflow/scripts/review.sh 2>&1); RC=$?
  expect_rc "(项目目录不存在) review.sh" 3
  check "(项目目录不存在) 提示无法进入项目目录" has "$OUT" "无法进入项目目录"

  # 占名:本轮快照目录名被普通文件占用 → 生成失败,exit 3,不调用 codex
  fx=$(impl_fixture occupied) || { ng "(占名) 夹具"; return; }
  td="$fx/$TASK"
  round1 "$fx"
  : > "$td/.review-raw-02.snap"
  ( cd "$fx" && echo '# r2' >> src/app.py )
  write_record "$fx" 02
  run_review "$fx"; expect_rc "(占名) 第 2 轮" 3
  check "(占名) 桩未被再次调用" [ "$(calls "$fx")" -eq 1 ]
  check "(占名) 无第 2 轮评审文件" [ "$(reviews "$fx" review-round-02)" -eq 0 ]

  # 第 1 轮评审之后补的回归断言(impl/01/R-03 与测试缺口 T-03):评审"进行中"所审文件被改
  # ——改的是 .claude/ 下的 skill,不在工作区指纹里——评审无效、不发布
  fx=$(impl_fixture drift) || { ng "(一致性) 夹具"; return; }
  ( cd "$fx" && echo '# r1' >> src/app.py )
  impl_json "$WORK/pass.json" ""
  unset STUB_OUT_SEQ
  export STUB_OUT="$WORK/pass.json" STUB_TOUCH="$fx/.claude/skills/demo/SKILL.md"
  run_review "$fx"; expect_rc "(一致性) 评审期间 skill 被改" 3
  check "(一致性) 提示所审改动发生了变化" has "$OUT" "所审改动在本轮快照生成之后发生了变化"
  check "(一致性) 不发布评审文件" [ "$(reviews "$fx" review-round-)" -eq 0 ]
  unset STUB_TOUCH
  run_review "$fx"; expect_rc "(一致性) 不再变动后同一轮可重跑" 0
  check "(一致性) 重跑发布第 01 轮" [ -f "$fx/$TASK/review-round-01-pass.md" ]

  # 第 2 轮评审之后补的回归断言(impl/02/R-01 与测试缺口 T-01):复制出来的快照副本与
  # 清单记录的内容不是同一版本(cp 替身在复制后改写副本)→ 快照生成失败,不调用 codex
  fx=$(impl_fixture tamper) || { ng "(副本校验) 夹具"; return; }
  ( cd "$fx" && echo '# r1' >> src/app.py )
  REAL_CP=$(command -v cp); export REAL_CP EXTRA_BIN="$TESTS/fake-cp-bin"
  run_review "$fx"; expect_rc "(副本校验) 副本被改写" 3
  check "(副本校验) 提示内容快照与清单不一致" has "$OUT" "内容快照与清单不一致"
  check "(副本校验) 桩未被调用" [ "$(calls "$fx")" -eq 0 ]
  check "(副本校验) 不发布评审文件" [ "$(reviews "$fx" review-round-)" -eq 0 ]
  unset EXTRA_BIN REAL_CP
  run_review "$fx"; expect_rc "(副本校验) 恢复正常 cp 后同一轮可重跑" 0
}

# dsec <差异文件> <路径>:该路径的 diff 段(到下一个文件头之前)
dsec() { awk -v h="--- 上一轮/$2" '$0 == h { on = 1; print; next } /^--- 上一轮\// { on = 0 } on' "$1"; }

tc10() {
  local fx td delta s lst
  [ "$(id -u)" -ne 0 ] || { ng "须以非 root 身份运行(不可读文件用例对 root 无效)"; return; }
  ok "以非 root 身份运行"
  fx=$(base_repo delta) || { ng "夹具"; return; }
  td="$fx/$TASK"
  (
    cd "$fx" || exit 1
    printf 'A1\nA2\nA3\nA4\nA5\nA6\n' > a.txt; echo B-orig > b.txt; echo D-orig > d.txt
    awk 'BEGIN { for (i = 0; i < 65536; i++) print "0123456789abcde" }' > big1
    { awk 'BEGIN { for (i = 0; i < 65536; i++) print "0123456789abcde" }'; printf x; } > big2
    mkdir -p bin && printf '#!/bin/sh\necho tool\n' > bin/tool && chmod +x bin/tool
    echo shared-config > shared.cfg && ln -s shared.cfg cfg && ln -s shared.cfg lnk
    cp big2 big3   # 超过 1 MiB 的已跟踪文件,第 1 轮不动、第 2 轮删除
    git add a.txt b.txt d.txt big1 big2 big3 bin/tool shared.cfg cfg lnk && git commit -qm more || exit 1
    # 第 1 轮前的改动
    sed -i '2s/.*/A2-r1/' a.txt; echo B-r1 > b.txt
    sed -i '1s/^0/X/' big1; sed -i '1s/^0/X/' big2
    printf 'C1\nC2\n' > c.txt; printf 'E1\nE2\nE3\n' > e.txt
    echo W1 > $'we\tird.txt'
    # 文件名含制表符的文件,以及文件名逐字等于其 shell 转义写法的另一个文件
    echo T1 > $'!a\tb.py'; echo L1 > "$(printf '%q' $'!a\tb.py')"
    # 文件名含 % 的文件,以及文件名逐字等于其编码结果的另一个文件
    echo P1 > 'rate%.py'; echo Q1 > 'rate%25.py'
    # 文件名含回车的文件,以及文件名逐字等于其编码结果的另一个文件(两者第 2 轮都改)
    echo CR1 > $'a\r.py'; echo EN1 > 'a%0D.py'
  ) >/dev/null 2>&1 || { ng "夹具内容"; return; }
  check "big1 恰为 1048576 字节" [ "$(wc -c < "$fx/big1")" -eq 1048576 ]
  check "big2 恰为 1048577 字节" [ "$(wc -c < "$fx/big2")" -eq 1048577 ]
  write_plan "$fx"; write_record "$fx" 01; ev "$fx" TC-01 -- true
  mkdir -p "$WORK/seq-delta"
  impl_json "$WORK/seq-delta/1.json" "$(issue major R-01 a.txt "$S" 2)"
  impl_json "$WORK/pass.json" ""
  export STUB_OUT_SEQ="$WORK/seq-delta" STUB_OUT="$WORK/pass.json"
  run_review "$fx"; expect_rc "第 1 轮" 1
  (
    cd "$fx" || exit 1
    sed -i '5s/.*/A5-r2/' a.txt; git checkout -q -- b.txt; echo D-r2 > d.txt
    rm c.txt; echo F1 > f.txt
    sed -i '2s/^0/Y/' big1; sed -i '2s/^0/Y/' big2
    sed -i '2s/.*/E2-r2/' e.txt; chmod 000 e.txt
    # 第 1 轮评审之后补的场景(impl/01/R-04、R-05、R-06)
    mkdir -p pkg && : > pkg/__init__.py          # 新增空文件
    chmod -x bin/tool                            # 相对 HEAD 首次去掉可执行位,内容不变
    rm cfg && echo local-config > cfg            # 符号链接换成有内容的普通文件
    echo W2 > $'we\tird.txt'                     # 路径含制表符的文件连续两轮修改
    # 第 2 轮评审之后补的场景(impl/02/R-02、R-04)
    echo T2 > $'!a\tb.py'                        # 只改带制表符的那个,转义同名的那个不动
    rm lnk && ln -s $'shared.cfg\n' lnk          # 链接目标只在末尾多一个换行
    # 第 3 轮评审之后补的场景(impl/03/R-02、R-03)
    echo P2 > 'rate%.py'                         # 只改名字带 % 的那个
    rm big3                                      # 删除 HEAD 中超过 1 MiB 的文件
    # 第 4 轮评审之后补的场景(impl/04/R-01)
    echo CR2 > $'a\r.py'; echo EN2 > 'a%0D.py'   # 含回车的文件与其编码同名的文件都改
  ) || ng "第 2 轮改动"
  write_record "$fx" 02
  run_review "$fx"; expect_rc "第 2 轮" 0
  delta="$td/.review-raw-02.delta.diff"
  check "轮间差异文件存在" [ -f "$delta" ]
  lst=$(sect "$delta" 变化文件)

  s=$(dsec "$delta" a.txt)
  check "a:含第 2 轮改的那一行" has "$s" "+A5-r2"
  check "a:只有一处改动(一删一增)" [ "$(grep -c '^[-+][^-+]' <<< "$s")" -eq 2 ]
  check "a:第 1 轮的改动不在增删行里" [ "$(grep -c '^[-+]A2' <<< "$s")" -eq 0 ]
  s=$(dsec "$delta" b.txt)
  check "b:差异是第 1 轮改动的撤回(删 B-r1)" has "$s" "-B-r1"
  check "b:差异是第 1 轮改动的撤回(增 B-orig)" has "$s" "+B-orig"
  s=$(dsec "$delta" d.txt)
  check "d:以 HEAD 版本为基线(删 D-orig)" has "$s" "-D-orig"
  check "d:以 HEAD 版本为基线(增 D-r2)" has "$s" "+D-r2"
  s=$(dsec "$delta" c.txt)
  check "c:整份为删除" has "$s" "-C1"
  check "c:没有新增行" [ "$(grep -c '^+[^+]' <<< "$s")" -eq 0 ]
  check "c:列表标为删除" has "$(grep -F '`c.txt`' <<< "$lst")" "删除"
  s=$(dsec "$delta" f.txt)
  check "f:整份为新增" has "$s" "+F1"
  check "f:没有删除行" [ "$(grep -c '^-[^-]' <<< "$s")" -eq 0 ]
  check "f:列表标为新增" has "$(grep -F '`f.txt`' <<< "$lst")" "新增"
  check "1048576 字节的文件有 diff" nonempty "$(dsec "$delta" big1)"
  check "1048577 字节的文件不出 diff" empty "$(dsec "$delta" big2)"
  check "1048577 字节的文件列为未快照" has "$(grep -F '`big2`' <<< "$lst")" "未快照"
  check "1048577 字节的文件注明整份按本轮变化对待" has "$(grep -F '`big2`' <<< "$lst")" "整份按本轮变化对待"
  check "不可读文件不出 diff" empty "$(dsec "$delta" e.txt)"
  check "不可读文件列为未快照" has "$(grep -F '`e.txt`' <<< "$lst")" "未快照"
  check "第 2 轮正常调用桩" [ "$(calls "$fx")" -eq 2 ]
  check "第 2 轮发布评审文件" [ -f "$td/review-round-02-pass.md" ]

  # 第 1 轮评审之后补的回归断言(impl/01/R-04、R-05、R-06)
  check "新增空文件被列出" has "$(grep -F '`pkg/__init__.py`' <<< "$lst")" "新增;空文件"
  check "相对 HEAD 的纯可执行位变化被列出" has "$(grep -F '`bin/tool`' <<< "$lst")" "元数据变化:可执行位 x → -"
  check "符号链接换成普通文件:列为类型变化" has "$(grep -F '`cfg`' <<< "$lst")" "类型变化:符号链接(→ shared.cfg) → 普通文件"
  check "符号链接换成普通文件:普通文件的内容出现在 diff 里" has "$(dsec "$delta" cfg)" "+local-config"
  check "路径含制表符的文件连续两轮修改:列为未快照" has "$(grep -F 'ird.txt' <<< "$lst")" "未快照"

  # 第 2 轮评审之后补的回归断言(impl/02/R-02、R-04 与测试缺口 T-03)
  local lit; lit=$(printf '%q' $'!a\tb.py')
  check "带制表符的文件被列出(编码为 %09)" has "$(grep -F '`!a%09b.py`' <<< "$lst")" "未快照"
  check "文件名逐字等于其转义写法的文件未改动,不被列出" hasnt "$lst" "\`$lit\`"
  check "链接目标末尾多一个换行被列出" has "$(grep -F '`lnk`' <<< "$lst")" "元数据变化:符号链接目标 shared.cfg → shared.cfg%0A"

  # 第 3 轮评审之后补的回归断言(impl/03/R-02、R-03 与测试缺口 T-02、T-03)
  check "名字带 % 的文件按真实路径列出" has "$lst" '- `rate%.py`(内容变化)'
  check "名字等于其编码结果的另一个文件未改动,不被列出" hasnt "$lst" '`rate%25.py`'
  check "diff 标签用真实路径" has "$(cat "$delta")" '--- 上一轮/rate%.py'
  check "含控制字符的路径带编码标注" has "$(grep -F '`!a%09b.py`' <<< "$lst")" "〔含控制字符,按 %XX 编码显示〕"
  check "删除 HEAD 中超过 1 MiB 的文件:标明删除" has "$(grep -F '`big3`' <<< "$lst")" "删除"
  check "删除 HEAD 中超过 1 MiB 的文件:同时标明未快照" has "$(grep -F '`big3`' <<< "$lst")" "未快照:原内容未保存,不出 diff"

  # 第 4 轮评审之后补的回归断言(impl/04/R-01 与测试缺口 T-01):含回车的文件不出 diff,
  # diff 标签不会出现两个文件共用一个路径
  check "名字等于编码结果的文件按真实路径列出并出 diff" has "$lst" '- `a%0D.py`(内容变化)'
  check "含回车的文件带编码标注并列为未快照" has "$(grep -F '`a%0D.py`〔含控制字符' <<< "$lst")" "未快照"
  check "diff 里标签为 a%0D.py 的段只有一个" [ "$(grep -cxF -- '--- 上一轮/a%0D.py' "$delta")" -eq 1 ]
  check "那一段是名字等于编码结果的文件的改动" has "$(dsec "$delta" 'a%0D.py')" "+EN2"

  # 变化文件很多且路径很长:内联列表按字节数截断(impl/01/R-09)
  local long p2 inl
  fx=$(impl_fixture many) || { ng "(长列表) 夹具"; return; }
  round1 "$fx"; expect_rc "(长列表) 第 1 轮" 1
  long=$(printf 'a%.0s' $(seq 1 100))
  ( cd "$fx" && mkdir -p deep && for s in $(seq 1 300); do echo x > "deep/$long-$s.txt"; done ) || ng "(长列表) 改动"
  write_record "$fx" 02
  run_review "$fx"; expect_rc "(长列表) 第 2 轮" 0
  p2=$(prompt "$fx" 2); inl=$(grep '^- `.*`(' <<< "$p2")
  check "(长列表) 内联列表不超过 16384 字节" [ "$(printf '%s\n' "$inl" | wc -c)" -le 16384 ]
  check "(长列表) 注明总数与已列条数" has "$p2" "共 300 项,此处只列前 $(grep -c . <<< "$inl") 项"
  check "(长列表) 完整列表在轮间差异文件里" [ "$(sect "$fx/$TASK/.review-raw-02.delta.diff" 变化文件 | grep -c '^- `')" -eq 300 ]

  # 第 2 轮评审之后补的回归断言(impl/02/R-03 与测试缺口 T-02):证据报告很长(700 条用例,
  # 约 160 KiB)且变化文件列表也很长时,指令仍远低于单参数上限,评审照常进行
  local prow rrow k pad p1 evf
  pad=$(printf 'e%.0s' $(seq 1 150))
  prow='| TC-01 | A | - | - | - | evidence.sh |'; rrow='| TC-01 | A | pass | TC-01.log |'
  for k in $(seq 1 700); do
    prow+=$'\n'"| TC-B$k | B | - | - | - | 引用 |"
    rrow+=$'\n'"| TC-B$k | B | pass | src/app.py:1 $pad |"
  done
  fx=$(base_repo longev) || { ng "(长证据) 夹具"; return; }
  write_plan "$fx" "$prow"; write_record "$fx" 01 "$rrow"; ev "$fx" TC-01 -- true
  # 第 3 轮评审之后补的(impl/03/R-04):需要落盘而落盘路径被目录占用 → exit 3(不是 1),
  # 不调用 codex;移走后同一轮可重跑
  mkdir -p "$fx/$TASK/.review-raw-01.evidence.md/sub"
  impl_json "$WORK/pass.json" ""; unset STUB_OUT_SEQ; export STUB_OUT="$WORK/pass.json"
  run_review "$fx"; expect_rc "(长证据) 落盘路径被目录占用" 3
  check "(长证据) 提示无法清理落盘路径" has "$OUT" "无法清理证据核验报告的落盘路径"
  check "(长证据) 占用时桩未被调用" [ "$(calls "$fx")" -eq 0 ]
  rm -rf "$fx/$TASK/.review-raw-01.evidence.md"
  round1 "$fx"; expect_rc "(长证据) 第 1 轮" 1
  ( cd "$fx" && mkdir -p deep && for s in $(seq 1 300); do echo x > "deep/$long-$s.txt"; done ) || ng "(长证据) 改动"
  write_record "$fx" 02 "$rrow"
  run_review "$fx"; expect_rc "(长证据) 第 2 轮" 0
  p1=$(prompt "$fx" 1); p2=$(prompt "$fx" 2); evf="$fx/$TASK/.review-raw-02.evidence.md"
  check "(长证据) 证据报告本身超过 128 KiB" [ "$(wc -c < "$evf")" -gt 131072 ]
  check "(长证据) 第 1 轮指令不超过 64 KiB" [ "$(printf '%s' "$p1" | wc -c)" -le 65536 ]
  check "(长证据) 第 2 轮指令不超过 64 KiB" [ "$(printf '%s' "$p2" | wc -c)" -le 65536 ]
  check "(长证据) 指令给出证据报告文件路径" has "$p2" "$TASK/.review-raw-02.evidence.md"
  check "(长证据) 指令保留结论行" has "$p2" "结论:记录与 plan 用例清单一致"
  check "(长证据) 落盘的报告是全文" grep -qF '| TC-B700 |' "$evf"
}

tc04() {
  local fx td v mark
  local P='| TC-01 | A | - | - | - | evidence.sh |
| TC-02 | B | - | - | - | 引用 |
| TC-03 | C | - | - | - | 陈述;须人工目视,无法自动化 |
| TC-04 | A | - | - | - | evidence.sh |'
  local R='| TC-01 | A | pass | TC-01.log |
| TC-02 | B | pass | `src/app.py:1` |
| TC-03 | C | pass | 目视确认页面正常,截图 shot.png |
| TC-04 | A | pass | TC-04.log |'
  good() {   # good <名字>:全部合规的夹具
    fx=$(base_repo "$1") || return 1
    td="$fx/$TASK"
    write_plan "$fx" "$P"; write_record "$fx" 01 "$R"
    ev "$fx" TC-01 -- true || return 1
    ev "$fx" TC-04 -- true || return 1
    ev "$fx" TC-01 -l bad -- false   # 故意留一份 exit 1 的证据(透传被包命令的退出码)
    return 0
  }
  impl_json "$WORK/pass.json" ""
  export STUB_OUT="$WORK/pass.json"

  good ok || { ng "合规夹具"; return; }
  run_evcheck "$fx"; expect_rc "(合规) evidence-check" 0
  check "(合规) B 档行为采信" has "$(grep -F '| TC-02 |' <<< "$OUT")" "| 采信 |"
  check "(合规) C 档行为采信" has "$(grep -F '| TC-03 |' <<< "$OUT")" "| 采信 |"
  check "(合规) A 档行为 OK" has "$(grep -F '| TC-01 |' <<< "$OUT")" "| OK |"

  # badtier 是第 1 轮评审之后补的(impl/01/R-08):未定义的档位不得按 B / C 档采信
  for v in exit1 multi notpass mismatch dup-record dup-plan noformat b-empty c-empty badtier; do
    good "ev-$v" || { ng "($v) 夹具"; continue; }
    case "$v" in
      badtier)    mark=BAD-TIER;     write_plan "$fx" "${P/| TC-02 | B |/| TC-02 | D |}"
                                     write_record "$fx" 01 "${R/| TC-02 | B |/| TC-02 | D |}" ;;
      exit1)      mark=EXIT-NONZERO; write_record "$fx" 01 "${R/TC-01.log/TC-01-bad.log}" ;;
      multi)      mark=EXIT-NONZERO; write_record "$fx" 01 "${R/TC-01.log/TC-01.log、TC-01-bad.log}" ;;
      notpass)    mark=NOT-PASS;     write_record "$fx" 01 "${R/| TC-02 | B | pass/| TC-02 | B | fail}" ;;
      mismatch)   mark=TC-MISMATCH;  write_record "$fx" 01 "${R/TC-04.log/TC-01.log}" ;;
      dup-record) mark=DUP-ID;       write_record "$fx" 01 "$R"$'\n''| TC-01 | A | pass | TC-01.log |' ;;
      dup-plan)   mark=DUP-ID;       write_plan "$fx" "$P"$'\n''| TC-02 | B | - | - | - | 引用 |' ;;
      noformat)   mark=NO-FORMAT;    sed -i '/^evidence_format:/d' "$td/plan.md" ;;
      b-empty)    mark=NO-EVIDENCE;  write_record "$fx" 01 "${R/\`src\/app.py:1\`/}" ;;
      c-empty)    mark=NO-EVIDENCE;  write_record "$fx" 01 "${R/目视确认页面正常,截图 shot.png/}" ;;
    esac
    run_evcheck "$fx"; expect_rc "($v) evidence-check" 1
    check "($v) 报告含 $mark" has "$OUT" "$mark"
    run_review "$fx"; expect_rc "($v) review.sh 拒绝启动" 3
    check "($v) 桩未被调用" [ "$(calls "$fx")" -eq 0 ]
    check "($v) 无评审文件" [ "$(reviews "$fx" review-round-)" -eq 0 ]
    # 只修复被破坏的那个条件
    write_plan "$fx" "$P"; write_record "$fx" 01 "$R"
    run_review "$fx"; expect_rc "($v) 修复后 review.sh" 0
    check "($v) 修复后桩被调用一次" [ "$(calls "$fx")" -eq 1 ]
    check "($v) 修复后只发布一份评审文件" [ "$(reviews "$fx" review-round-01-)" -eq 1 ]
  done
}

tc05() {
  local fx f adv q C='照此实现会返工'
  pone() {   # pone <名字> <期望 exit>
    fx=$(plan_fixture "$1") || { ng "($1) 夹具"; return 1; }
    export STUB_OUT="$WORK/$1.json"; run_plan_review "$fx"
    expect_rc "($1) plan-review.sh" "$2"
    if [ "$2" -eq 0 ]; then f="$fx/$TASK/plan-review-round-01-pass.md"; else f="$fx/$TASK/plan-review-round-01-fail.md"; fi
    check "($1) 发布 ${f##*/}" [ -f "$f" ]
    adv=$(sect "$f" 建议); q=$(sect "$f" 问题清单)
  }
  plan_json "$WORK/p1.json" "$(pissue major R-01 acceptance "$C")"
  pone p1 0 && {
    check "(1) acceptance 类 major 降为建议" has "$adv" "[major] R-01 〔降级:acceptance 类不可阻断〕"
    run_script "$fx" plan-review.sh __minors "$TASK"
    check "(1) __minors 含该降级条目" has "$OUT" "| plan/01/R-01 | 降级[major]:"
  }
  plan_json "$WORK/p2.json" "$(pissue major R-01 contract "$C")"
  pone p2 1 && check "(2) contract 类 major 留在问题清单" has "$q" "[major] R-01"
  plan_json "$WORK/p3.json" "$(pissue major R-01 contract '  ')"
  pone p3 0 && check "(3) 缺实现后果的 major 降为建议" has "$adv" "[major] R-01 〔降级:缺实现后果〕"
  plan_json "$WORK/p4.json" "$(pissue plan-blocker R-01 acceptance "$C")"
  pone p4 0 && check "(4) acceptance 类 plan-blocker 降为建议" has "$adv" "[plan-blocker] R-01 〔降级:acceptance 类不可阻断〕"
  plan_json "$WORK/p5.json" "$(pissue plan-blocker R-01 premise "$C")"
  pone p5 1 && check "(5) premise 类 plan-blocker 留在问题清单" has "$q" "[plan-blocker] R-01"
  # 第 1 轮评审之后补的回归断言(impl/01/R-01):实现后果分两段、中间有空行,不是空白
  plan_json "$WORK/p6.json" "$(pissue major R-01 contract $'第一段:会返工\n\n第二段:接口要重做')"
  pone p6 1 && check "(6) 中间有空行的实现后果不被当作空白" has "$q" "[major] R-01"

  # 多轮汇总:两轮各带一条自拟建议与一条 minor
  fx=$(plan_fixture multi) || { ng "(多轮) 夹具"; return; }
  mkdir -p "$WORK/seq-multi"
  plan_json "$WORK/seq-multi/1.json" "$(pissue minor R-01 other '')" '["adv one"]'
  plan_json "$WORK/seq-multi/2.json" "$(pissue minor R-01 other '')" '["adv two"]'
  export STUB_OUT_SEQ="$WORK/seq-multi"; unset STUB_OUT
  run_plan_review "$fx"; expect_rc "(多轮) 第 1 轮" 0
  echo '修订一处。' >> "$fx/$TASK/plan.md"
  run_plan_review "$fx"; expect_rc "(多轮) 第 2 轮" 0
  run_script "$fx" plan-review.sh __minors "$TASK"
  check "(多轮) 含第 1 轮 minor" has "$OUT" "| plan/01/R-01 | minor:"
  check "(多轮) 含第 1 轮建议" has "$OUT" "| plan/01/A-01 | 建议:adv one |"
  check "(多轮) 含第 2 轮 minor" has "$OUT" "| plan/02/R-01 | minor:"
  check "(多轮) 含第 2 轮建议" has "$OUT" "| plan/02/A-01 | 建议:adv two |"
  unset STUB_OUT_SEQ

  # 旧格式(1.5.0 之前,无建议节)的评审文件只提取 minor
  mkdir -p "$WORK/old"
  cat > "$WORK/old/plan-review-round-01-fail.md" <<'EOF'
# Plan 评审:第 01 轮

## 问题清单
- [major] R-01 old major
  - 详情:d
- [minor] R-02 old minor
  - 详情:d

## 范围核对
无

## 总评
x

VERDICT: fail
EOF
  OUT=$(bash "$PROJ/.ai-workflow/scripts/plan-review.sh" __minors "$WORK/old" 2>&1)
  check "(旧格式) 只输出其 minor" [ "$OUT" = "| plan/01/R-02 | minor:old minor |" ]
}

tc06() {
  local fx i p
  plan_json "$WORK/gate.json" "$(pissue major R-01 contract '照此实现会返工')"
  export STUB_OUT="$WORK/gate.json"; unset STUB_OUT_SEQ

  fx=$(plan_fixture rounds) || { ng "夹具"; return; }
  for i in 1 2 3; do
    run_plan_review "$fx"; expect_rc "第 $i 次" 1
    echo "修订 $i。" >> "$fx/$TASK/plan.md"
  done
  p=$(prompt "$fx" 1)
  check "第 1 轮为全量评审" has "$p" "本轮模式:全量评审"
  check "第 1 轮指令写明调查按需" has "$p" "调查按需"
  check "第 1 轮指令含触发条件一(与最佳实践有出入)" has "$p" "方案与你认为的最佳实践有出入"
  check "第 1 轮指令含触发条件二(明显的逻辑问题)" has "$p" "方案存在明显的逻辑问题"
  check "第 1 轮指令写明范围扩张不可阻断" has "$p" "单纯的范围扩张不可阻断"
  check "第 1 轮指令写明范围扩张只进范围核对" has "$p" '`scope_findings` 由用户裁决,不属于 requirement'
  for i in 2 3; do
    p=$(prompt "$fx" "$i")
    check "第 $i 轮为核验评审" has "$p" "本轮模式:核验评审"
    check "第 $i 轮含上一轮评审文件路径" has "$p" "$TASK/plan-review-round-0$((i - 1))-fail.md"
    check "第 $i 轮含修订 diff" has "$p" '```diff'
    check "第 $i 轮的 diff 含本次修订" has "$p" "+修订 $((i - 1))。"
  done
  run_plan_review "$fx"; expect_rc "第 4 次(超限)" 3
  check "超限提示含 3 轮上限" has "$OUT" "3 轮上限"
  check "超限时未调用桩" [ "$(calls "$fx")" -eq 3 ]

  fx=$(plan_fixture relaxed) || { ng "(放宽) 夹具"; return; }
  sed -i 's/^date: 2026-01-01$/date: 2026-01-01\nplan_review_max_rounds: 4/' "$fx/$TASK/plan.md"
  for i in 1 2 3 4; do
    run_plan_review "$fx"; expect_rc "(放宽) 第 $i 次" 1
    echo "修订 $i。" >> "$fx/$TASK/plan.md"
  done
  check "(放宽) 第 4 轮确实调用了桩" [ "$(calls "$fx")" -eq 4 ]
  check "(放宽) 第 4 轮为核验评审" has "$(prompt "$fx" 4)" "本轮模式:核验评审"

  fx=$(plan_fixture nosnap) || { ng "(删快照) 夹具"; return; }
  run_plan_review "$fx"; expect_rc "(删快照) 第 1 次" 1
  rm -f "$fx/$TASK/.plan-review-raw-01.plan.md"
  echo "修订。" >> "$fx/$TASK/plan.md"
  run_plan_review "$fx"; expect_rc "(删快照) 第 2 次" 1
  check "(删快照) 第 2 轮回退为全量评审" has "$(prompt "$fx" 2)" "本轮模式:全量评审(无上一轮快照)"
}

tc07() {
  local fx name body i=0 f
  impl_json "$WORK/valid-impl.json" ""
  plan_json "$WORK/valid-plan.json" ""
  unset STUB_OUT_SEQ

  local -a impl_bad=(
    'empty-object|{}'
    'no-issues|{"test_gaps":[],"advisories":[],"scope_findings":[],"overall":"x"}'
    'issues-string|{"issues":"none","test_gaps":[],"advisories":[],"scope_findings":[],"overall":"x"}'
    'issue-missing-field|{"issues":[{"id":"R-01","severity":"major","file":"src/app.py","line":1,"summary":"s","detail":"d"}],"test_gaps":[],"advisories":[],"scope_findings":[],"overall":"x"}'
    'issue-wrong-type|{"issues":[{"id":"R-01","severity":"major","file":"src/app.py","line":"12","summary":"s","scenario":"x","detail":"d"}],"test_gaps":[],"advisories":[],"scope_findings":[],"overall":"x"}'
    'bad-severity|{"issues":[{"id":"R-01","severity":"critical","file":"src/app.py","line":1,"summary":"s","scenario":"x","detail":"d"}],"test_gaps":[],"advisories":[],"scope_findings":[],"overall":"x"}'
    'non-string-in-array|{"issues":[],"test_gaps":[],"advisories":[1],"scope_findings":[],"overall":"x"}'
    'line-not-integer|{"issues":[{"id":"R-01","severity":"major","file":"src/app.py","line":1.5,"summary":"s","scenario":"x","detail":"d"}],"test_gaps":[],"advisories":[],"scope_findings":[],"overall":"x"}'
    'severity-array|{"issues":[{"id":"R-01","severity":["major"],"file":"src/app.py","line":1,"summary":"s","scenario":"x","detail":"d"}],"test_gaps":[],"advisories":[],"scope_findings":[],"overall":"x"}'
    'extra-top-field|{"verdict":"pass","issues":[],"test_gaps":[],"advisories":[],"scope_findings":[],"overall":"x"}'
    'extra-issue-field|{"issues":[{"id":"R-01","severity":"minor","file":"src/app.py","line":1,"summary":"s","scenario":"","detail":"d","note":"n"}],"test_gaps":[],"advisories":[],"scope_findings":[],"overall":"x"}'
  )
  for name in "${impl_bad[@]}"; do
    body=${name#*|}; name=${name%%|*}; i=$((i + 1))
    fx=$(impl_fixture "vi$i") || { ng "(实现/$name) 夹具"; continue; }
    printf '%s\n' "$body" > "$WORK/bad.json"
    export STUB_OUT="$WORK/bad.json"; run_review "$fx"
    expect_rc "(实现/$name) 非法输出" 3
    check "(实现/$name) 不发布评审文件" [ "$(reviews "$fx" review-round-)" -eq 0 ]
    check "(实现/$name) 原始输出保留" [ -f "$fx/$TASK/.review-raw-01.json" ]
    export STUB_OUT="$WORK/valid-impl.json"; run_review "$fx"
    expect_rc "(实现/$name) 换成合法输出后同一轮可发布" 0
    check "(实现/$name) 发布的是第 01 轮" [ -f "$fx/$TASK/review-round-01-pass.md" ]
  done
  fx=$(impl_fixture viok) && { export STUB_OUT="$WORK/valid-impl.json"; run_review "$fx"; expect_rc "(实现) 合法空数组" 0
    check "(实现) 合法空数组发布 pass 文件" [ -f "$fx/$TASK/review-round-01-pass.md" ]; }

  local -a plan_bad=(
    'empty-object|{}'
    'no-issues|{"advisories":[],"scope_findings":[],"overall":"x"}'
    'issues-string|{"issues":"none","advisories":[],"scope_findings":[],"overall":"x"}'
    'issue-missing-field|{"issues":[{"id":"R-01","severity":"major","category":"contract","summary":"s","detail":"d"}],"advisories":[],"scope_findings":[],"overall":"x"}'
    'issue-wrong-type|{"issues":[{"id":"R-01","severity":"major","category":"contract","summary":5,"consequence":"c","detail":"d"}],"advisories":[],"scope_findings":[],"overall":"x"}'
    'bad-severity|{"issues":[{"id":"R-01","severity":"blocker","category":"contract","summary":"s","consequence":"c","detail":"d"}],"advisories":[],"scope_findings":[],"overall":"x"}'
    'bad-category|{"issues":[{"id":"R-01","severity":"major","category":"testing","summary":"s","consequence":"c","detail":"d"}],"advisories":[],"scope_findings":[],"overall":"x"}'
    'non-string-in-array|{"issues":[],"advisories":[],"scope_findings":[{"a":1}],"overall":"x"}'
    'category-array|{"issues":[{"id":"R-01","severity":"major","category":["contract"],"summary":"s","consequence":"c","detail":"d"}],"advisories":[],"scope_findings":[],"overall":"x"}'
    'severity-array|{"issues":[{"id":"R-01","severity":["major"],"category":"contract","summary":"s","consequence":"c","detail":"d"}],"advisories":[],"scope_findings":[],"overall":"x"}'
    'extra-top-field|{"verdict":"pass","issues":[],"advisories":[],"scope_findings":[],"overall":"x"}'
    'extra-issue-field|{"issues":[{"id":"R-01","severity":"minor","category":"other","summary":"s","consequence":"","detail":"d","note":"n"}],"advisories":[],"scope_findings":[],"overall":"x"}'
  )
  i=0
  for name in "${plan_bad[@]}"; do
    body=${name#*|}; name=${name%%|*}; i=$((i + 1))
    fx=$(plan_fixture "vp$i") || { ng "(plan/$name) 夹具"; continue; }
    printf '%s\n' "$body" > "$WORK/bad.json"
    export STUB_OUT="$WORK/bad.json"; run_plan_review "$fx"
    expect_rc "(plan/$name) 非法输出" 3
    check "(plan/$name) 不发布评审文件" [ "$(reviews "$fx" plan-review-round-)" -eq 0 ]
    check "(plan/$name) 原始输出保留" [ -f "$fx/$TASK/.plan-review-raw-01.json" ]
    export STUB_OUT="$WORK/valid-plan.json"; run_plan_review "$fx"
    expect_rc "(plan/$name) 换成合法输出后同一轮可发布" 0
    check "(plan/$name) 发布的是第 01 轮" [ -f "$fx/$TASK/plan-review-round-01-pass.md" ]
  done
  fx=$(plan_fixture vpok) && { export STUB_OUT="$WORK/valid-plan.json"; run_plan_review "$fx"; expect_rc "(plan) 合法空数组" 0
    check "(plan) 合法空数组发布 pass 文件" [ -f "$fx/$TASK/plan-review-round-01-pass.md" ]; }

  for f in review.schema.json plan-review.schema.json; do
    check "$f 是合法 JSON" quiet jq -e . "$PROJ/.ai-workflow/schemas/$f"
    check "$f 每个对象节点 additionalProperties=false 且 required 覆盖全部属性" \
      quiet jq -e '[.. | objects | select(.type == "object")
              | (.additionalProperties == false) and ((.required | sort) == (.properties | keys))] | all' \
      "$PROJ/.ai-workflow/schemas/$f"
    check "$f 不含 verdict" quiet jq -e '[.. | objects | select(has("properties")) | .properties | has("verdict")] | any | not' \
      "$PROJ/.ai-workflow/schemas/$f"
  done
  for f in review.sh plan-review.sh evidence-check.sh; do
    check "bash -n $f" bash -n "$PROJ/.ai-workflow/scripts/$f"
  done
}

tc08() {
  local fx td n
  command -v codex >/dev/null || { ng "codex 不在 PATH"; return; }
  fx=$(base_repo real) || { ng "夹具"; return; }
  td="$fx/$TASK"
  cat > "$td/plan.md" <<'EOF'
---
status: approved
task: t
date: 2026-01-01
evidence_format: v1
---

# 方案:average 支持空列表

## 需求原文
> average 传入空列表时不要报错,返回 0。

**本任务交付**:`src/calc.py` 的 `average` 对空列表返回 0。

## 改动范围
`src/calc.py`、`tests/test_calc.py`。

## 非目标
无

## 实现方案
在 `average` 开头判断列表是否为空,为空返回 0;结果缓存进模块级字典,键用列表
对象本身(list 不可哈希,这一条本身有问题)。

## 测试用例
| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | - | 运行单元测试 | 通过 | evidence.sh 包住测试命令,exit 0 |
EOF
  write_record "$fx" 01; ev "$fx" TC-01 -- true
  printf 'def average(values):\n    return sum(values) / len(values)\n' > "$fx/src/calc.py"
  printf 'from src.calc import average\n\n\ndef test_average():\n    assert average([2, 4]) == 3\n' > "$fx/tests/test_calc.py"
  # 真实 codex:不前置桩
  OUT=$(cd "$fx" && CLAUDE_PROJECT_DIR="$fx" bash .ai-workflow/scripts/review.sh 2>&1); RC=$?
  printf '%s\n' "$OUT" | sed 's/^/    | /'
  check "review.sh 退出码为 0 或 1(实际 $RC)" [ "$RC" -eq 0 -o "$RC" -eq 1 ]
  n=$(reviews "$fx" review-round-01-)
  check "review.sh 发布一份评审文件" [ "$n" -eq 1 ]
  [ "$n" -eq 1 ] && { echo "---- 评审文件(仅供留档,不对内容做断言)----"; cat "$td"/review-round-01-*.md; echo "----"; }
  OUT=$(cd "$fx" && CLAUDE_PROJECT_DIR="$fx" bash .ai-workflow/scripts/plan-review.sh 2>&1); RC=$?
  printf '%s\n' "$OUT" | sed 's/^/    | /'
  check "plan-review.sh 退出码为 0 或 1(实际 $RC)" [ "$RC" -eq 0 -o "$RC" -eq 1 ]
  n=$(reviews "$fx" plan-review-round-01-)
  check "plan-review.sh 发布一份评审文件" [ "$n" -eq 1 ]
  [ "$n" -eq 1 ] && { echo "---- plan 评审文件(仅供留档,不对内容做断言)----"; cat "$td"/plan-review-round-01-*.md; echo "----"; }
}

tc09() {
  local f entry
  cd "$PROJ" || { ng "cd"; return; }
  for f in CLAUDE.md AGENTS.md README.md .claude/skills/rawf-plan/SKILL.md .claude/skills/rawf-implement/SKILL.md \
           .claude/skills/rawf-review/SKILL.md .claude/skills/rawf-report/SKILL.md; do
    check "$f 不再出现「5 轮」" bash -c '! grep -q "5 轮" "$1"' _ "$f"
    check "$f 不再出现「全量穷尽」" bash -c '! grep -q "全量穷尽" "$1"' _ "$f"
  done
  check "t0015 存在" [ -f docs/decisions/t0015-review-product-gate.md ]
  for f in t0003 t0005 t0006 t0010 t0012; do
    check "$f 顶部含指向 t0015 的标注" bash -c 'head -n 12 docs/decisions/"$1"-*.md | grep -q "t0015"' _ "$f"
  done
  check "CHANGELOG 有 [1.5.0] 条目" grep -q '^## \[1\.5\.0\]' CHANGELOG.md
  entry=$(awk '/^## \[1\.5\.0\]/ { on = 1; next } /^## \[/ { on = 0 } on' CHANGELOG.md)
  check "1.5.0 条目含「升级指引」" has "$entry" "### 升级指引"
  check "1.5.0 条目排在 1.4.1 之前" [ "$(grep -n '^## \[1\.5\.0\]' CHANGELOG.md | cut -d: -f1)" -lt "$(grep -n '^## \[1\.4\.1\]' CHANGELOG.md | cut -d: -f1)" ]
  check "TEMPLATE-VERSION 为 1.5.0" grep -qx 'version: 1.5.0' .ai-workflow/TEMPLATE-VERSION
  # 第 4 轮评审之后经用户同意追加:失败场景的现实性门槛写进了评审标准与评审指令
  check "评审标准写明失败场景须在正常使用中可能出现" grep -q '失败场景须在正常使用中可能出现' .ai-workflow/review-standards.md
  check "实现评审指令写明同一门槛" grep -q '正常使用中可能出现' .ai-workflow/prompts/review.md
}

case "${1:-}" in
  tc01|tc02|tc03|tc04|tc05|tc06|tc07|tc08|tc09|tc10) "$1" ;;
  *) echo "用法:bash run.sh tc01..tc10" >&2; exit 2 ;;
esac
echo "失败断言数:$FAILS"
[ "$FAILS" -eq 0 ]
