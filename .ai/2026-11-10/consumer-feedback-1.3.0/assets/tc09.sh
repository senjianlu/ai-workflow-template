#!/usr/bin/env bash
# TC-09:版本号 1.4.0 与 CHANGELOG 条目
. "$(dirname "$0")/lib.sh"
echo "## TEMPLATE-VERSION"; cat .ai-workflow/TEMPLATE-VERSION
[ "$(head -n 1 .ai-workflow/TEMPLATE-VERSION)" = "version: 1.4.0" ] && ok "version: 1.4.0" || bad "version: 1.4.0"
echo "## CHANGELOG 版本标题"; grep -n '^## \[' CHANGELOG.md
a=$(grep -n '^## \[1\.4\.0\] - 2026-11-10$' CHANGELOG.md | cut -d: -f1)
b=$(grep -n '^## \[1\.3\.0\]' CHANGELOG.md | cut -d: -f1)
[ -n "$a" ] && ok "存在 ## [1.4.0] - 2026-11-10" || bad "存在 ## [1.4.0] - 2026-11-10"
[ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] && ok "1.4.0 条目位于 1.3.0 之前" || bad "1.4.0 条目位于 1.3.0 之前"
[ "$(grep -n '^## \[' CHANGELOG.md | head -1 | cut -d: -f1)" = "$a" ] && ok "1.4.0 是第一个版本条目" || bad "1.4.0 是第一个版本条目"
sed -n '/^## \[1\.4\.0\]/,/^## \[1\.3\.0\]/p' CHANGELOG.md | grep -q '^### 升级指引$' && ok "1.4.0 条目含「升级指引」小节" || bad "1.4.0 条目含「升级指引」小节"
finish
