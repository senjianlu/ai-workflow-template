#!/usr/bin/env bash
# TC-05 回归:plan-review-convergence 的行为断言脚本(plan-review.sh)
source "$(dirname "$0")/lib.sh"
D="$ROOT/.ai/2026-10-22/plan-review-convergence/evidence"
for n in 01 02 03 04 05 06 10 12; do
  echo "===== plan-review-convergence tc-$n.sh"
  out=$(bash "$D/tc-$n.sh" 2>&1); rc=$?
  echo "$out"
  assert_eq "plan-review-convergence tc-$n.sh 退出码" "$rc" "0"
done
finish
