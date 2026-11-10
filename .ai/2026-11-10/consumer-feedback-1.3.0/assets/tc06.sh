#!/usr/bin/env bash
# TC-06:脚本 / hook / .gitignore 的增删行全是注释;shell 文件 bash -n 通过
. "$(dirname "$0")/lib.sh"
SH=".ai-workflow/scripts/review.sh .ai-workflow/scripts/plan-review.sh .ai-workflow/scripts/evidence.sh .ai-workflow/scripts/evidence-check.sh .claude/hooks/gate-review.sh"
for f in $SH .gitignore; do
  lines=$(git diff HEAD -- "$f" | grep -E '^[+-]' | grep -vE '^(\+\+\+|---) ')
  echo "## $f 增删行"; echo "$lines"
  [ -n "$lines" ] && ok "$f 有改动" || bad "$f 有改动"
  nc=$(echo "$lines" | grep -vE '^[+-][[:space:]]*#' || true)
  [ -z "$nc" ] && ok "$f 增删行全部是注释" || { bad "$f 存在非注释改动"; echo "$nc"; }
done
for f in $SH; do check "bash -n $f" bash -n "$f"; done
finish
