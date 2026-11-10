#!/usr/bin/env bash
# TC-01:决策目录恰为 t0001~t0014 + README,无纯数字开头文件,slug 与 HEAD 一致
. "$(dirname "$0")/lib.sh"
echo "## docs/decisions 清单"; ls docs/decisions
want=$( { for n in $(seq -w 1 14); do echo "t00$n"; done; } )
got=$(ls docs/decisions | grep -v '^README\.md$' | sed -E 's/^(t[0-9]{4})-.*\.md$/\1/')
[ "$got" = "$want" ] && ok "决策文件编号恰为 t0001~t0014" || bad "决策文件编号恰为 t0001~t0014(实际:$(echo $got))"
check "存在 README.md" test -f docs/decisions/README.md
[ "$(ls docs/decisions | wc -l)" -eq 15 ] && ok "目录共 15 个条目" || bad "目录共 15 个条目"
[ -z "$(ls docs/decisions | grep -E '^[0-9]')" ] && ok "无纯数字开头的文件" || bad "无纯数字开头的文件"
echo "## HEAD 旧文件 → 新文件"
old=$(git ls-tree --name-only HEAD docs/decisions/ | sed 's#.*/##' | grep -E '^[0-9]{4}-')
[ "$(echo "$old" | wc -l)" -eq 13 ] && ok "HEAD 中有 13 个旧决策文件" || bad "HEAD 中有 13 个旧决策文件"
for f in $old; do check "slug 不变:$f → t$f" test -f "docs/decisions/t$f"; done
finish
