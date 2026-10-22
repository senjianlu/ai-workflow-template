#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
for s in evidence.sh evidence-check.sh review.sh plan-review.sh; do
  if bash -n "$SCRIPTS/$s"; then ok "bash -n $s"; else bad "bash -n $s"; fi
done
if command -v shellcheck >/dev/null; then
  if shellcheck -S error "$SCRIPTS"/evidence.sh "$SCRIPTS"/evidence-check.sh "$SCRIPTS"/review.sh "$SCRIPTS"/plan-review.sh; then ok "shellcheck 无 error"; else bad "shellcheck 有 error"; fi
else
  echo "  info - shellcheck 未安装,跳过(plan 允许记录未安装)"
fi
finish
