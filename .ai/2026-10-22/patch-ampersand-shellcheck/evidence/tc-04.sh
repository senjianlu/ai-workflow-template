#!/usr/bin/env bash
# TC-04 回归:scope-guard-and-evidence-format 的行为断言脚本(evidence.sh / evidence-check / review.sh)
source "$(dirname "$0")/lib.sh"
D="$ROOT/.ai/2026-10-22/scope-guard-and-evidence-format/evidence"
for n in 01 02 03 04 05 06 07 08 09 10 11 16 17 18 19; do
  echo "===== scope-guard tc-$n.sh"
  out=$(bash "$D/tc-$n.sh" 2>&1); rc=$?
  echo "$out"
  assert_eq "scope-guard tc-$n.sh 退出码" "$rc" "0"
done
finish
