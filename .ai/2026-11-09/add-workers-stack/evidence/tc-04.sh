# TC-04:决策 0013 存在、唯一、四段体例与要点
set -u
E=.ai/2026-11-09/add-workers-stack/evidence
. "$E/lib.sh"
f=docs/decisions/0013-workers-standard-stack.md
[ -f "$f" ] || { miss "file: $f"; finish; }
n=$(find docs/decisions -maxdepth 1 -name '0013-*' | wc -l)
[ "$n" -eq 1 ] || miss "unique: 0013-* 共 $n 个"
head -1 "$f" | grep -q '^# 0013:' || miss "title: $(head -1 "$f")"
need "$f" 体例 '- 日期:2026-11-09' '- 背景:' '- 决定:' '- 影响:'
need "$f" 要点 形态 实现纪律 skill nodejs_compat cscheap-link src/ chanfana 按需
head -1 "$f"
finish
