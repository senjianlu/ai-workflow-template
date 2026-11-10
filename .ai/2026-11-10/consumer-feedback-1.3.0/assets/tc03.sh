#!/usr/bin/env bash
# TC-03:全部 docs/decisions/tNNNN 引用与决策目录内相对 .md 链接均有目标文件
. "$(dirname "$0")/lib.sh"
echo "## docs/decisions/tNNNN 引用(.ai/、.git/ 除外)"
refs=$(grep -rnIoE 'docs/decisions/t[0-9]{4}' . --exclude-dir=.git --exclude-dir=.ai)
echo "引用总数:$(echo "$refs" | wc -l)"
[ -n "$refs" ] && ok "存在 t 引用" || bad "存在 t 引用"
for id in $(echo "$refs" | sed -E 's#.*docs/decisions/(t[0-9]{4})#\1#' | sort -u); do
  n=$(echo "$refs" | grep -c "/$id\$")
  if ls docs/decisions/"$id"-*.md >/dev/null 2>&1; then ok "$id(被引用 $n 处)→ $(ls docs/decisions/"$id"-*.md)"; else bad "$id 无对应文件"; fi
done
echo "## 决策目录内相对 .md 链接"
links=$(grep -noE '\]\([^)#:]+\.md\)' docs/decisions/*.md || true)
echo "链接总数:$(echo "$links" | grep -c .)"
while IFS= read -r l; do
  [ -n "$l" ] || continue
  t=$(echo "$l" | sed -E 's/.*\]\(([^)]+)\)$/\1/')
  check "${l%%:*}:$(echo "$l" | cut -d: -f2) → $t" test -f "docs/decisions/$t"
done <<< "$links"
finish
