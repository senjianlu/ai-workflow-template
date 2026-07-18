#!/usr/bin/env bash
# review-readonly TC-01/02/03 自测(真实 codex):
# TC-01 端到端一轮(证据齐全)、TC-02 只读沙箱探针、TC-03 证据置空打回。
# 用法:test-e2e-readonly.sh <evidence目录>(codex 完整输出落此)
set -uo pipefail

PROJ="/Users/xujinpeng/Projects/2026/ai-workflow-template"
REVIEW_SH="$PROJ/.ai-workflow/scripts/review.sh"
EVDIR="${1:?用法:test-e2e-readonly.sh <evidence目录>}"
WORK=$(mktemp -d "$HOME/.review-ro-e2e-XXXXXX")
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
check() {
  local desc=$1; shift
  if "$@"; then echo "  OK  $desc"; pass=$((pass+1))
  else echo "  FAIL $desc"; fail=$((fail+1)); fi
}
list_copies() { ls -d /tmp/rawf-review-* "${TMPDIR:-/tmp}"/rawf-review-* 2>/dev/null; }

# 看门狗:codex 偶发挂死(实测一次 >2h 无进展),单步限时,超时杀进程组
# 返回 124(macOS 无 coreutils timeout,用后台计时器实现)
WATCHDOG_SECS=900
run_with_watchdog() {
  "$@" &
  local pid=$!
  ( sleep "$WATCHDOG_SECS"; kill -TERM "$pid" 2>/dev/null; sleep 5; kill -KILL "$pid" 2>/dev/null ) &
  local wd=$!
  local rc=0
  wait "$pid"; rc=$?
  kill "$wd" 2>/dev/null; wait "$wd" 2>/dev/null
  if [ "$rc" -ge 128 ]; then echo "  [watchdog] 命令超时(${WATCHDOG_SECS}s)被终止" >&2; return 124; fi
  return "$rc"
}

# make_fixture <dir> <with_evidence:1|0>
make_fixture() {
  local fx=$1 with_ev=$2
  mkdir -p "$fx"
  cp -Rp "$PROJ/.ai-workflow" "$fx/.ai-workflow"
  cp -p "$PROJ/.gitignore" "$fx/.gitignore"
  local task_rel=".ai/2026-07-18/e2e-fixture"
  mkdir -p "$fx/$task_rel/evidence"
  printf '%s' "$task_rel" > "$fx/.ai/.current-task"
  cat > "$fx/$task_rel/plan.md" <<'EOF'
---
status: approved
task: e2e-fixture
date: 2026-07-18
approved_at: 2026-07-18
---

# 方案:新增 greet.sh

## 背景与目标
夹具任务:新增 greet.sh,运行输出 hello。

## 改动范围
新增 greet.sh,不动其他文件。

## 测试用例
| 编号 | 前置条件 | 步骤 | 预期结果 |
|---|---|---|---|
| TC-01 | 无 | bash greet.sh | 输出 hello,退出码 0 |
| TC-02 | 无 | bash greet.sh extra-arg | 仍输出 hello,退出码 0(参数被忽略,边界) |
EOF
  cat > "$fx/$task_rel/implementation-round-01.md" <<'EOF'
---
task: e2e-fixture
round: 01
date: 2026-07-18
---

# 实现记录:第 01 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| greet.sh | 新增,echo hello |

## 测试结果
| 编号 | 结果 | 证据 |
|---|---|---|
| TC-01 | 通过 | evidence/tc01-02.txt(命令+完整输出+退出码) |
| TC-02 | 通过 | 同上 |

## 与方案的偏差
无
EOF
  ( cd "$fx" && git init -q && git config user.email t@t && git config user.name t \
      && git add -A && git commit -qm init ) || return 1
  printf '#!/bin/sh\necho hello\n' > "$fx/greet.sh"
  if [ "$with_ev" = 1 ]; then
    {
      echo "\$ bash greet.sh"; ( cd "$fx" && bash greet.sh ); echo "exit: $?"
      echo "\$ bash greet.sh extra-arg"; ( cd "$fx" && bash greet.sh extra-arg ); echo "exit: $?"
    } > "$fx/$task_rel/evidence/tc01-02.txt" 2>&1
  fi
}

echo "== TC-01 端到端一轮(证据齐全,真实 codex)=="
fx1="$WORK/fx1"; make_fixture "$fx1" 1 || exit 1
echo "  \$ ls -d /tmp/rawf-review-* \${TMPDIR}/rawf-review-*   # 运行前原始清单"
pre_raw=$(list_copies); pre_copies=$(printf '%s' "$pre_raw" | grep -c . || true)
echo "  | ${pre_raw:-(无匹配)}"
echo "  \$ CLAUDE_PROJECT_DIR=<fx1> bash review.sh"
run_with_watchdog env CLAUDE_PROJECT_DIR="$fx1" bash "$REVIEW_SH" > "$EVDIR/tc01-review-full-output.txt" 2>&1
rc1=$?
echo "  \$ ls -d /tmp/rawf-review-* \${TMPDIR}/rawf-review-*   # 运行后原始清单"
post_raw=$(list_copies); post_copies=$(printf '%s' "$post_raw" | grep -c . || true)
echo "  | ${post_raw:-(无匹配)}"
echo "review.sh exit code: $rc1" | tee -a "$EVDIR/tc01-review-full-output.txt"
check "退出码为 0 或 1(评审完成,非执行异常)" test "$rc1" -eq 0 -o "$rc1" -eq 1
shopt -s nullglob
outs=("$fx1/.ai/2026-07-18/e2e-fixture"/review-round-01-*.md)
shopt -u nullglob
check "评审结论文件已产出" test "${#outs[@]}" -eq 1
if [ "${#outs[@]}" -eq 1 ]; then
  echo "  结论文件:$(basename "${outs[0]}")"
  sed 's/^/  | /' "${outs[0]}" | head -20
  cp "${outs[0]}" "$EVDIR/tc01-$(basename "${outs[0]}")"
  case "${outs[0]}" in
    *-pass.md) check "退出码与 verdict 一致(pass=0)" test "$rc1" -eq 0 ;;
    *-fail.md) check "退出码与 verdict 一致(fail=1)" test "$rc1" -eq 1 ;;
  esac
fi
check "运行前后均无 rawf-review-* 副本目录" test "$pre_copies" -eq 0 -a "$post_copies" -eq 0
grep -q '主工作区在评审期间发生改动' "$EVDIR/tc01-review-full-output.txt" && hb=0 || hb=1
check "指纹校验通过(无'评审无效'报错)" test "$hb" -eq 1

echo "== TC-02 只读沙箱探针(真实 codex)=="
fx2="$WORK/fx2"; make_fixture "$fx2" 1 || exit 1
( cd "$fx2" && git add -A && git commit -qm all ) # 干净基线便于断言无新增
echo "  \$ codex exec --sandbox read-only -C <fx2> '…touch probe.txt…'(完整命令与提示词见本行下方)"
echo "  | codex exec --sandbox read-only -C $fx2 \\"
echo "  |   '在当前目录执行命令:touch probe.txt;然后执行 ls -la 显示结果。…'"
run_with_watchdog codex exec --sandbox read-only -C "$fx2" \
  "在当前目录执行命令:touch probe.txt;然后执行 ls -la 显示结果。如实报告 touch 命令是否成功、失败时的完整错误输出。除此之外不要做任何其他操作。" \
  > "$EVDIR/tc02-readonly-probe-full-output.txt" 2>&1
rc2=$?
echo "  codex exec rc=$rc2"
check "codex exec 退出码 0(探针确实执行)" test "$rc2" -eq 0
grep -q 'probe.txt' "$EVDIR/tc02-readonly-probe-full-output.txt"
check "输出含探针命令痕迹" test $? -eq 0
grep -qi 'not permitted\|denied\|read-only\|只读\|失败' "$EVDIR/tc02-readonly-probe-full-output.txt"
check "输出含写入被拒证据" test $? -eq 0
check "夹具无 probe.txt" test ! -e "$fx2/probe.txt"
echo "  \$ git -C <fx2> status   # 探针后完整输出"
( cd "$fx2" && git status ) 2>&1 | sed 's/^/  | /'
st2=$(cd "$fx2" && git status --porcelain)
check "git status 无任何新增/改动" test -z "$st2"

echo "== TC-03 证据置空:评审打回并索要证据(真实 codex)=="
fx3="$WORK/fx3"; make_fixture "$fx3" 0 || exit 1
echo "  \$ CLAUDE_PROJECT_DIR=<fx3> bash review.sh > tc03-review-full-output.txt 2>&1; rc=\$?   # 包装命令"
run_with_watchdog env CLAUDE_PROJECT_DIR="$fx3" bash "$REVIEW_SH" > "$EVDIR/tc03-review-full-output.txt" 2>&1
rc3=$?
echo "review.sh exit code: $rc3" | tee -a "$EVDIR/tc03-review-full-output.txt"
check "退出码 1(fail)" test "$rc3" -eq 1
f3="$fx3/.ai/2026-07-18/e2e-fixture/review-round-01-fail.md"
check "review-round-01-fail.md 已发布" test -f "$f3"
if [ -f "$f3" ]; then
  sed 's/^/  | /' "$f3" | head -20
  cp "$f3" "$EVDIR/tc03-review-round-01-fail.md"
  grep -q 'blocker' "$f3"
  check "含 blocker 问题" test $? -eq 0
  grep -q '证据' "$f3"
  check "问题详情含证据索要(打回协议生效)" test $? -eq 0
fi

echo
echo "结果:$pass 通过,$fail 失败(TC-01 rc=$rc1,TC-02 rc=$rc2,TC-03 rc=$rc3)"
test "$fail" -eq 0
