#!/usr/bin/env bash
# TC-02:除 CHANGELOG 旧条目外无纯数字决策路径;CHANGELOG 旧条目与 HEAD 逐字节相同
. "$(dirname "$0")/lib.sh"
cut=$(grep -n '^## \[1\.3\.0\]' CHANGELOG.md | head -1 | cut -d: -f1)
echo "CHANGELOG 旧条目起始行:$cut"
echo "## 全仓(.ai/、.git/ 除外)grep decisions/[0-9]{4}"
hits=$(grep -rnIE 'decisions/[0-9]{4}' . --exclude-dir=.git --exclude-dir=.ai || true)
echo "$hits"
rest=$(echo "$hits" | awk -F: -v cut="$cut" 'NF && !($1 == "./CHANGELOG.md" && $2 + 0 >= cut)')
echo "## 其中不属于 CHANGELOG 旧条目的命中"; echo "${rest:-(无)}"
[ -z "$rest" ] && ok "CHANGELOG 旧条目之外无纯数字决策路径" || bad "CHANGELOG 旧条目之外无纯数字决策路径"
[ -n "$cut" ] && cmp -s <(git show HEAD:CHANGELOG.md | sed -n '/^## \[1\.3\.0\]/,$p') <(sed -n '/^## \[1\.3\.0\]/,$p' CHANGELOG.md) \
  && ok "CHANGELOG 自 [1.3.0] 起与 HEAD 逐字节相同" || bad "CHANGELOG 自 [1.3.0] 起与 HEAD 逐字节相同"
echo "旧条目行数:$(sed -n '/^## \[1\.3\.0\]/,$p' CHANGELOG.md | wc -l)(HEAD:$(git show HEAD:CHANGELOG.md | sed -n '/^## \[1\.3\.0\]/,$p' | wc -l))"
finish
