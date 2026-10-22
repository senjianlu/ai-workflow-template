#!/usr/bin/env bash
# TC-06 语法、版本、改动文件清单
source "$(dirname "$0")/lib.sh"
for f in review.sh plan-review.sh evidence.sh; do
  if bash -n "$SCRIPTS/$f"; then ok "bash -n $f"; else bad "bash -n $f"; fi
done
grep -qF '## [1.2.1]' "$ROOT/CHANGELOG.md" && ok "CHANGELOG 含 [1.2.1]" || bad "CHANGELOG 缺 [1.2.1]"
sed -n '/^## \[1.2.1\]/,/^## \[1.2.0\]/p' "$ROOT/CHANGELOG.md" | grep -qF '### 升级指引' && ok "1.2.1 条目含升级指引" || bad "1.2.1 条目缺升级指引"
assert_eq "TEMPLATE-VERSION" "$(sed -n 's/^version: //p' "$ROOT/.ai-workflow/TEMPLATE-VERSION")" "1.2.1"
changed=$(git -C "$ROOT" diff --name-only HEAD | LC_ALL=C sort)
echo "--- git diff --name-only HEAD:"; echo "$changed"
assert_eq "改动文件清单" "$changed" "$(printf '%s\n' .ai-workflow/TEMPLATE-VERSION .ai-workflow/scripts/evidence.sh .ai-workflow/scripts/plan-review.sh .ai-workflow/scripts/review.sh CHANGELOG.md | LC_ALL=C sort)"
finish
