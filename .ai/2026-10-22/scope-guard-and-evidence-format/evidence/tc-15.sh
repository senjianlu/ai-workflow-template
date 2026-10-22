#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
D="$ROOT/docs/decisions"
chk() { if grep -qF -- "$2" "$1"; then ok "$(basename "$1") 含 $(printf %q "$2")"; else bad "$(basename "$1") 不含 $(printf %q "$2")"; fi; }
chk "$D/0006-test-evidence-tiers.md" "已被 0010 部分取代"
for n in 0010-evidence-format-v1 0011-scope-reflection; do for k in "- 日期:" "- 背景:" "- 决定:" "- 影响:"; do chk "$D/$n.md" "$k"; done; done
chk "$ROOT/CHANGELOG.md" "## [1.1.0]"; chk "$ROOT/CHANGELOG.md" "### 升级指引"
assert_eq "TEMPLATE-VERSION" "$(sed -n 's/^version: //p' "$ROOT/.ai-workflow/TEMPLATE-VERSION")" "1.1.0"
chk "$ROOT/README.md" "evidence-check"
finish
