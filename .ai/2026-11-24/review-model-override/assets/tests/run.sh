#!/usr/bin/env bash
# 执行 plan.md 的测试用例。用法:bash run.sh tcNN
# 在项目外(mktemp -d)构造 git 夹具并拷入改后的 .ai-workflow/;codex 桩用同目录
# stub-codex-bin/codex(记录启动参数后转交 1.5.0 任务的桩)。tc06 调用真实 codex。
# 每条断言打印 [OK] / [FAIL];全部成立 exit 0,否则 exit 1。
set -uo pipefail

TESTS=$(cd "$(dirname "$0")" && pwd)
PROJ=$(cd "$TESTS/../../../../.." && pwd)
STUB_BIN="$TESTS/stub-codex-bin"
SUITE_150="$PROJ/.ai/2026-11-24/review-product-gate/assets/tests/run.sh"
SUITE_151="$PROJ/.ai/2026-11-24/snapshot-excludes-prompt-limit/assets/tests/run.sh"
WORK=$(mktemp -d)
# RAWF_TEST_KEEP=1 时保留夹具目录供排查(路径打印在末尾)
cleanup() {
  chmod -R u+rw "$WORK" 2>/dev/null
  if [ "${RAWF_TEST_KEEP:-}" = 1 ]; then echo "夹具保留在:$WORK"; else rm -rf "$WORK"; fi
}
trap cleanup EXIT
export RAWF_REVIEW_POLL_SECONDS=1
unset CLAUDE_PROJECT_DIR STUB_OUT STUB_OUT_SEQ STUB_DIR STUB_TOUCH STUB_EXIT
TASK=.ai/2026-01-01/t
NOTE='评审模型按 plan.md frontmatter 的指定'

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
# base_repo <名字>:项目外 git 夹具,基线已提交
base_repo() {
  local fx="$WORK/$1"
  mkdir -p "$fx"
  (
    cd "$fx" || exit 1
    git init -q . && git config user.email t@example.invalid && git config user.name t || exit 1
    cp -r "$PROJ/.ai-workflow" . && cp "$PROJ/.gitignore" . || exit 1
    mkdir -p src
    printf 'def f():\n    return 1\n' > src/app.py
    git add -A && git commit -qm init || exit 1
    mkdir -p "$TASK/evidence" "$TASK/assets"
    echo "$TASK" > .ai/.current-task
  ) >/dev/null 2>&1 || { echo "夹具 $1 构造失败" >&2; return 1; }
  echo "$fx"
}
# write_plan <夹具> <status> [frontmatter 追加行...]:追加行原样写进 frontmatter
write_plan() {
  local fx=$1 st=$2; shift 2
  {
    printf -- '---\nstatus: %s\ntask: t\ndate: 2026-01-01\nevidence_format: v1\n' "$st"
    if [ "$#" -gt 0 ]; then printf '%s\n' "$@"; fi
    cat <<'EOF'
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
  } > "$fx/$TASK/plan.md"
}
# plan_fixture <名字> [frontmatter 追加行...]:base_repo + draft plan
plan_fixture() {
  local name=$1 fx; shift
  fx=$(base_repo "$name") || return 1
  write_plan "$fx" draft "$@"
  echo "$fx"
}
# impl_fixture <名字> [frontmatter 追加行...]:base_repo + approved plan + 第 01 轮
# 实现记录 + TC-01 证据 + 一处产品改动
impl_fixture() {
  local name=$1 fx; shift
  fx=$(base_repo "$name") || return 1
  write_plan "$fx" approved "$@"
  cat > "$fx/$TASK/implementation-round-01.md" <<'EOF'
# 实现记录:第 01 轮

## 测试结果
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01.log |
EOF
  ( cd "$fx" && CLAUDE_PROJECT_DIR="$fx" bash .ai-workflow/scripts/evidence.sh TC-01 -- true \
      && echo '# changed' >> src/app.py ) >/dev/null 2>&1 || return 1
  echo "$fx"
}

# --- 运行与取证 ---------------------------------------------------------------
run_script() {   # run_script <夹具> <脚本名>:结果存 RC / OUT(stdout 与 stderr 合并)
  local fx=$1 script=$2
  OUT=$(cd "$fx" && PATH="$STUB_BIN:$PATH" CLAUDE_PROJECT_DIR="$fx" STUB_DIR="$WORK/stub-${fx##*/}" \
        bash ".ai-workflow/scripts/$script" 2>&1); RC=$?
}
run_review() { run_script "$1" review.sh; }
run_plan_review() { run_script "$1" plan-review.sh; }
calls() { local f="$WORK/stub-${1##*/}/calls"; if [ -f "$f" ]; then wc -l < "$f"; else echo 0; fi; }
argsf() { echo "$WORK/stub-${1##*/}/args-$2.txt"; }   # argsf <夹具> <第 n 次调用>
reviews() {   # reviews <夹具> <文件名前缀>:匹配的评审文件个数
  local n=0 f
  for f in "$1/$TASK"/$2*.md; do [ -e "$f" ] && n=$((n + 1)); done
  echo "$n"
}
# has_pair <参数文件> <选项> <值>:参数序列里有相邻的两项 <选项> <值>
has_pair() {
  [ -f "$1" ] || return 1
  awk -v f="$2" -v v="$3" 'prev == f && $0 == v { found = 1 } { prev = $0 } END { exit !found }' "$1"
}
no_arg() { [ -f "$1" ] && ! grep -qxF -e "$2" "$1"; }   # no_arg <参数文件> <整项>
no_text() { [ -f "$1" ] && ! grep -qF -e "$2" "$1"; }   # no_text <参数文件> <子串>

# --- 评审 JSON ---------------------------------------------------------------
impl_pass="$WORK/impl-pass.json"; plan_pass="$WORK/plan-pass.json"
jq -n '{issues: [], test_gaps: [], advisories: [], scope_findings: [], overall: "ok"}' > "$impl_pass"
jq -n '{issues: [], advisories: [], scope_findings: [], overall: "ok"}' > "$plan_pass"
use_plan() { export STUB_OUT="$plan_pass"; }
use_impl() { export STUB_OUT="$impl_pass"; }

# =============================================================================
tc01() {
  local fx td
  # plan 评审:四个字段都不写
  fx=$(plan_fixture p) || { ng "(plan) 夹具"; return; }
  td="$fx/$TASK"
  use_plan; run_plan_review "$fx"; expect_rc "(plan) plan-review.sh" 0
  check "(plan) 评审正常发布" [ -f "$td/plan-review-round-01-pass.md" ]
  printf '%s\n' exec --json --sandbox read-only -C "$fx" \
    --output-schema "$fx/.ai-workflow/schemas/plan-review.schema.json" \
    --output-last-message "$td/.plan-review-raw-01.json" > "$WORK/expected-plan.txt"
  check "(plan) codex 的参数序列与固定序列逐项相同" cmp -s "$WORK/expected-plan.txt" "$(argsf "$fx" 1)"
  check "(plan) 参数里没有 -m" no_arg "$(argsf "$fx" 1)" -m
  check "(plan) 参数里没有 -c" no_arg "$(argsf "$fx" 1)" -c
  check "(plan) stderr 没有模型说明行" hasnt "$OUT" "$NOTE"

  # 实现评审:四个字段都不写
  fx=$(impl_fixture i) || { ng "(impl) 夹具"; return; }
  td="$fx/$TASK"
  use_impl; run_review "$fx"; expect_rc "(impl) review.sh" 0
  check "(impl) 评审正常发布" [ -f "$td/review-round-01-pass.md" ]
  printf '%s\n' exec --json --sandbox read-only -C "$fx" \
    --output-schema "$fx/.ai-workflow/schemas/review.schema.json" \
    --output-last-message "$td/.review-raw-01.json" > "$WORK/expected-impl.txt"
  check "(impl) codex 的参数序列与固定序列逐项相同" cmp -s "$WORK/expected-impl.txt" "$(argsf "$fx" 1)"
  check "(impl) 参数里没有 -m" no_arg "$(argsf "$fx" 1)" -m
  check "(impl) 参数里没有 -c" no_arg "$(argsf "$fx" 1)" -c
  check "(impl) stderr 没有模型说明行" hasnt "$OUT" "$NOTE"
}

tc02() {
  local fx td a
  # plan 评审读 plan_review_*,不受 impl_review_* 影响
  fx=$(plan_fixture p 'plan_review_model: gpt-test-1' 'plan_review_effort: high' 'impl_review_model: other-model') \
    || { ng "(plan) 夹具"; return; }
  td="$fx/$TASK"; a=$(argsf "$fx" 1)
  use_plan; run_plan_review "$fx"; expect_rc "(plan) plan-review.sh" 0
  check "(plan) 评审正常发布" [ -f "$td/plan-review-round-01-pass.md" ]
  check "(plan) 参数有相邻的 -m gpt-test-1" has_pair "$a" -m gpt-test-1
  check "(plan) 参数有相邻的 -c model_reasoning_effort=\"high\"" has_pair "$a" -c 'model_reasoning_effort="high"'
  check "(plan) 参数不含实现评审的取值" no_text "$a" other-model
  check "(plan) -m 只出现一次" [ "$(grep -cxF -e -m "$a")" -eq 1 ]
  check "(plan) 新参数紧跟在 exec 之后" [ "$(sed -n '1,2p' "$a" | tr '\n' ' ')" = "exec -m " ]
  check "(plan) stderr 写明生效的模型字段与值" has "$OUT" "$NOTE:plan_review_model=gpt-test-1,plan_review_effort=high"

  # 实现评审读 impl_review_*,不受 plan_review_* 影响
  fx=$(impl_fixture i 'impl_review_model: gpt-test-2' 'impl_review_effort: low' 'plan_review_model: other-model') \
    || { ng "(impl) 夹具"; return; }
  td="$fx/$TASK"; a=$(argsf "$fx" 1)
  use_impl; run_review "$fx"; expect_rc "(impl) review.sh" 0
  check "(impl) 评审正常发布" [ -f "$td/review-round-01-pass.md" ]
  check "(impl) 参数有相邻的 -m gpt-test-2" has_pair "$a" -m gpt-test-2
  check "(impl) 参数有相邻的 -c model_reasoning_effort=\"low\"" has_pair "$a" -c 'model_reasoning_effort="low"'
  check "(impl) 参数不含 plan 评审的取值" no_text "$a" other-model
  check "(impl) -m 只出现一次" [ "$(grep -cxF -e -m "$a")" -eq 1 ]
  check "(impl) 新参数紧跟在 exec 之后" [ "$(sed -n '1,2p' "$a" | tr '\n' ' ')" = "exec -m " ]
  check "(impl) stderr 写明生效的模型字段与值" has "$OUT" "$NOTE:impl_review_model=gpt-test-2,impl_review_effort=low"
}

tc03() {
  local fx td a
  # (1) 只指定 plan 评审的强度
  fx=$(plan_fixture effort-only 'plan_review_effort: xhigh') || { ng "(1) 夹具"; return; }
  td="$fx/$TASK"; a=$(argsf "$fx" 1)
  use_plan; run_plan_review "$fx"; expect_rc "(1) plan-review.sh" 0
  check "(1) 评审正常发布" [ -f "$td/plan-review-round-01-pass.md" ]
  check "(1) 有 -c model_reasoning_effort=\"xhigh\"" has_pair "$a" -c 'model_reasoning_effort="xhigh"'
  check "(1) 没有 -m" no_arg "$a" -m

  # (2) 只指定实现评审的模型
  fx=$(impl_fixture model-only 'impl_review_model: gpt-test-3') || { ng "(2) 夹具"; return; }
  td="$fx/$TASK"; a=$(argsf "$fx" 1)
  use_impl; run_review "$fx"; expect_rc "(2) review.sh" 0
  check "(2) 评审正常发布" [ -f "$td/review-round-01-pass.md" ]
  check "(2) 有 -m gpt-test-3" has_pair "$a" -m gpt-test-3
  check "(2) 没有 -c" no_arg "$a" -c

  # (3) 字段写在 frontmatter 之外的正文行首:不生效(两个脚本各验一次)
  fx=$(plan_fixture body-plan) || { ng "(3) plan 夹具"; return; }
  td="$fx/$TASK"; a=$(argsf "$fx" 1)
  printf 'plan_review_model: body-model\nplan_review_effort: high\n' >> "$td/plan.md"
  use_plan; run_plan_review "$fx"; expect_rc "(3) plan-review.sh" 0
  check "(3) plan 评审正常发布" [ -f "$td/plan-review-round-01-pass.md" ]
  check "(3) plan 评审没有 -m" no_arg "$a" -m
  check "(3) plan 评审没有 -c" no_arg "$a" -c
  fx=$(impl_fixture body-impl) || { ng "(3) impl 夹具"; return; }
  td="$fx/$TASK"; a=$(argsf "$fx" 1)
  printf 'impl_review_model: body-model\nimpl_review_effort: high\n' >> "$td/plan.md"
  use_impl; run_review "$fx"; expect_rc "(3) review.sh" 0
  check "(3) 实现评审正常发布" [ -f "$td/review-round-01-pass.md" ]
  check "(3) 实现评审没有 -m" no_arg "$a" -m
  check "(3) 实现评审没有 -c" no_arg "$a" -c
}

# bad_values <夹具> <plan 状态> <运行函数> <评审文件前缀> <字段> <非法值...>
bad_values() {
  local fx=$1 st=$2 runner=$3 prefix=$4 key=$5 v; shift 5
  for v in "$@"; do
    write_plan "$fx" "$st" "$key:${v:+ $v}"
    "$runner" "$fx"; expect_rc "$key 写成「$v」" 3
    check "$key 写成「$v」:stderr 指出字段名与非法" has "$OUT" "plan.md 的 $key 非法"
    check "$key 写成「$v」:桩未被调用" [ "$(calls "$fx")" -eq 0 ]
    check "$key 写成「$v」:没有评审文件" [ "$(reviews "$fx" "$prefix")" -eq 0 ]
  done
}

tc04() {
  local fx td
  # plan 评审
  fx=$(plan_fixture p) || { ng "(plan) 夹具"; return; }
  td="$fx/$TASK"; use_plan
  bad_values "$fx" draft run_plan_review plan-review-round- plan_review_model '' 'gpt 6' '--oss' '"gpt-6"'
  bad_values "$fx" draft run_plan_review plan-review-round- plan_review_effort '' 'High' 'high!'
  write_plan "$fx" draft 'plan_review_model: gpt-ok' 'plan_review_effort: medium'
  run_plan_review "$fx"; expect_rc "(plan) 改成合法值后重跑" 0
  check "(plan) 发布的是第 01 轮" [ -f "$td/plan-review-round-01-pass.md" ]
  check "(plan) 只有一份评审文件" [ "$(reviews "$fx" plan-review-round-)" -eq 1 ]

  # 实现评审
  fx=$(impl_fixture i) || { ng "(impl) 夹具"; return; }
  td="$fx/$TASK"; use_impl
  bad_values "$fx" approved run_review review-round- impl_review_model '' 'gpt 6' '--oss' '"gpt-6"'
  bad_values "$fx" approved run_review review-round- impl_review_effort '' 'High' 'high!'
  write_plan "$fx" approved 'impl_review_model: gpt-ok' 'impl_review_effort: medium'
  run_review "$fx"; expect_rc "(impl) 改成合法值后重跑" 0
  check "(impl) 发布的是第 01 轮" [ -f "$td/review-round-01-pass.md" ]
  check "(impl) 只有一份评审文件" [ "$(reviews "$fx" review-round-)" -eq 1 ]
}

tc05() {
  local fx td
  # plan 评审:codex 以非零退出(模拟拒绝不支持的模型)
  fx=$(plan_fixture p 'plan_review_model: no-such-model') || { ng "(plan) 夹具"; return; }
  td="$fx/$TASK"; use_plan
  export STUB_EXIT=1
  run_plan_review "$fx"; expect_rc "(plan) codex 拒绝" 3
  check "(plan) stderr 含 codex exec 执行失败" has "$OUT" "codex exec 执行失败"
  check "(plan) 桩确实被调用过,且带着该模型" has_pair "$(argsf "$fx" 1)" -m no-such-model
  check "(plan) 没有评审文件" [ "$(reviews "$fx" plan-review-round-)" -eq 0 ]
  unset STUB_EXIT
  run_plan_review "$fx"; expect_rc "(plan) 恢复后重跑" 0
  check "(plan) 发布的是第 01 轮" [ -f "$td/plan-review-round-01-pass.md" ]

  # 实现评审
  fx=$(impl_fixture i 'impl_review_model: no-such-model') || { ng "(impl) 夹具"; return; }
  td="$fx/$TASK"; use_impl
  export STUB_EXIT=1
  run_review "$fx"; expect_rc "(impl) codex 拒绝" 3
  check "(impl) stderr 含 codex exec 执行失败" has "$OUT" "codex exec 执行失败"
  check "(impl) 桩确实被调用过,且带着该模型" has_pair "$(argsf "$fx" 1)" -m no-such-model
  check "(impl) 没有评审文件" [ "$(reviews "$fx" review-round-)" -eq 0 ]
  unset STUB_EXIT
  run_review "$fx"; expect_rc "(impl) 恢复后重跑" 0
  check "(impl) 发布的是第 01 轮" [ -f "$td/review-round-01-pass.md" ]
}

tc06() {
  local model d
  model=$(sed -n 's/^model[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' \
            "${CODEX_HOME:-$HOME/.codex}/config.toml" 2>/dev/null | head -n 1)
  check "config.toml 里有默认模型" [ -n "$model" ]
  [ -n "$model" ] || return
  d="$WORK/real"; mkdir -p "$d"
  # 与脚本生成的参数形态相同:-m <模型>、-c model_reasoning_effort="<强度>"
  OUT=$(timeout 300 codex exec --ephemeral --skip-git-repo-check --sandbox read-only -C "$d" \
        -m "$model" -c 'model_reasoning_effort="low"' "Reply with the single word ok." </dev/null 2>&1); RC=$?
  expect_rc "真实 codex 接受 -m 与 -c model_reasoning_effort" 0
  check "启动信息显示所指定的模型" has "$OUT" "model: $model"
  check "启动信息显示 reasoning effort: low" has "$OUT" "reasoning effort: low"
}

tc07() {
  local t f
  for t in tc03 tc06 tc10; do
    OUT=$(bash "$SUITE_150" "$t" 2>&1); RC=$?
    expect_rc "1.5.0 任务的回归用例 $t" 0
    check "1.5.0 $t 没有失败断言" hasnt "$OUT" "[FAIL]"
  done
  for t in tc01 tc02 tc03 tc06; do
    OUT=$(bash "$SUITE_151" "$t" 2>&1); RC=$?
    expect_rc "1.5.1 任务的回归用例 $t" 0
    check "1.5.1 $t 没有失败断言" hasnt "$OUT" "[FAIL]"
  done
  for f in review.sh plan-review.sh; do
    check "bash -n $f" bash -n "$PROJ/.ai-workflow/scripts/$f"
  done
}

tc08() {
  local entry k
  cd "$PROJ" || { ng "cd"; return; }
  check "CHANGELOG 有 [1.6.0] 条目" grep -q '^## \[1\.6\.0\]' CHANGELOG.md
  entry=$(awk '/^## \[1\.6\.0\]/ { on = 1; next } /^## \[/ { on = 0 } on' CHANGELOG.md)
  check "1.6.0 条目含「升级指引」" has "$entry" "### 升级指引"
  check "1.6.0 条目排在 1.5.1 之前" [ "$(grep -n '^## \[1\.6\.0\]' CHANGELOG.md | cut -d: -f1)" -lt "$(grep -n '^## \[1\.5\.1\]' CHANGELOG.md | cut -d: -f1)" ]
  check "TEMPLATE-VERSION 为 1.6.0" grep -qx 'version: 1.6.0' .ai-workflow/TEMPLATE-VERSION
  check "README 有「维护者裁量」一段" grep -q '^\*\*维护者裁量\*\*' README.md
  for k in plan_review_model plan_review_effort impl_review_model impl_review_effort; do
    check "README 列出 $k" grep -qF "\`$k\`" README.md
    check "CLAUDE.md 硬规则列出 $k" grep -qF "\`$k\`" CLAUDE.md
  done
  for k in plan_review_model plan_review_effort; do
    check "rawf-plan 写明 $k" grep -qF "$k" .claude/skills/rawf-plan/SKILL.md
  done
  for k in impl_review_model impl_review_effort; do
    check "rawf-review 写明 $k" grep -qF "$k" .claude/skills/rawf-review/SKILL.md
  done
  check "t0016 存在" [ -f docs/decisions/t0016-review-model-override.md ]
  check "t0008 顶部有补注" bash -c 'sed -n "1,8p" docs/decisions/t0008-template-versioning.md | grep -q "维护者裁量"'
}

case "${1:-}" in
  tc01|tc02|tc03|tc04|tc05|tc06|tc07|tc08) "$1" ;;
  *) echo "用法:bash run.sh tc01..tc08" >&2; exit 2 ;;
esac
echo "失败断言数:$FAILS"
[ "$FAILS" -eq 0 ]
