#!/usr/bin/env bash
# TC-04:① t0001~t0012 去掉 t 前缀后与 HEAD 旧文件无差异;② t*.md 中未带 t 的 00NN 仅 t0013 两处
. "$(dirname "$0")/lib.sh"
echo "## ① 改名只动了决策编号"
for n in $(seq -w 1 12); do
  old=$(git ls-tree --name-only HEAD docs/decisions/ | grep "/00$n-")
  new="docs/decisions/t${old##*/}"
  if d=$(diff <(git show "HEAD:$old") <(sed -E 's/t(00[0-9]{2})/\1/g' "$new")); then ok "$new 去 t 后与 HEAD:$old 相同"; else bad "$new 与旧文件有编号之外的差异"; echo "$d"; fi
  echo "    含 t 编号的行数:$(grep -cE 't00[0-9]{2}' "$new")"
done
echo "## ② 未带 t 前缀的 00NN"
hits=$(grep -noE '(^|[^0-9t])00[0-9]{2}([^0-9]|$)' docs/decisions/t*.md || true)
echo "$hits"
[ "$(echo "$hits" | grep -c .)" -eq 2 ] && ok "命中恰 2 处" || bad "命中恰 2 处"
[ -z "$(echo "$hits" | grep -v '^docs/decisions/t0013-workers-standard-stack.md:')" ] && ok "命中全部在 t0013" || bad "命中全部在 t0013"
check "t0013 保留「其 0015」" has docs/decisions/t0013-workers-standard-stack.md '其 0015'
check "t0013 保留「其 0014」" has docs/decisions/t0013-workers-standard-stack.md '其 0014'
finish
