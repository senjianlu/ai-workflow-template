#!/usr/bin/env bash
# TC-10:模拟存量派生仓,逐字执行 CHANGELOG 1.4.0 升级指引里的代码块
. "$(dirname "$0")/lib.sh"
ROOT=$PWD
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
C="$W/consumer"; mkdir -p "$C/docs/decisions"
# fixture:HEAD 版模板旧决策 0001~0013(含被带入的 0013-workers-standard-stack.md)
for p in $(git ls-tree --name-only HEAD docs/decisions/ | grep -E '/[0-9]{4}-'); do git show "HEAD:$p" > "$C/docs/decisions/${p##*/}"; done
printf '# 0013:项目自有决策(与模板撞号)\n\n- 日期:2026-10-01\n' > "$C/docs/decisions/0013-own-thing.md"
printf '# 0014:项目自有决策(与模板新增 t0014 同 slug)\n\n- 日期:2026-10-02\n' > "$C/docs/decisions/0014-template-decision-namespace.md"
{ git show HEAD:docs/decisions/README.md; printf '\n## 项目决策索引\n\n- 0013 own-thing\n- 0014 template-decision-namespace(项目自有)\n'; } > "$C/docs/decisions/README.md"
( cd "$C/docs/decisions" && sha256sum 0013-own-thing.md 0014-template-decision-namespace.md README.md ) > "$W/before.sum"
echo "## 升级前"; ls "$C/docs/decisions"
# 从 CHANGELOG 1.4.0 条目提取唯一的 bash 代码块(去掉列表缩进),原样执行
sed -n '/^## \[1\.4\.0\]/,/^## \[1\.3\.0\]/p' CHANGELOG.md | awk '/^  ```bash$/ {on=1; n++; next} /^  ```$/ {on=0} on {sub(/^  /, ""); print}' > "$W/upgrade.sh"
blocks=$(sed -n '/^## \[1\.4\.0\]/,/^## \[1\.3\.0\]/p' CHANGELOG.md | grep -c '^  ```bash$')
[ "$blocks" -eq 1 ] && ok "1.4.0 升级指引中恰有 1 个 bash 代码块" || bad "1.4.0 升级指引中恰有 1 个 bash 代码块(实际 $blocks)"
echo "## 所执行的命令(取自 CHANGELOG,逐字)"; cat "$W/upgrade.sh"
[ -s "$W/upgrade.sh" ] && ok "代码块非空" || bad "代码块非空"
( cd "$C" && AWT="$ROOT" bash -eu "$W/upgrade.sh" ); rc=$?
[ "$rc" -eq 0 ] && ok "升级命令 exit 0" || bad "升级命令 exit $rc"
echo "## 升级后"; ls "$C/docs/decisions"
left=$(ls "$C/docs/decisions" | grep -E '^[0-9]{4}-' | sort | tr '\n' ' ')
[ "$left" = "0013-own-thing.md 0014-template-decision-namespace.md " ] && ok "纯数字文件只剩两个项目自有决策(模板旧文件 0001~0013 全部消失)" || bad "纯数字文件只剩两个项目自有决策(实际:$left)"
for n in $(seq -w 1 14); do ls "$C/docs/decisions/t00$n-"*.md >/dev/null 2>&1 && ok "t00$n 已拷入" || bad "t00$n 已拷入"; done
[ "$(ls "$C/docs/decisions" | grep -c '^t[0-9]\{4\}-')" -eq 14 ] && ok "t 系列共 14 个" || bad "t 系列共 14 个"
( cd "$C/docs/decisions" && sha256sum -c "$W/before.sum" ) && ok "两个项目自有决策与带项目索引的 README.md 内容未变" || bad "两个项目自有决策与带项目索引的 README.md 内容未变"
grep -q '^## 项目决策索引$' "$C/docs/decisions/README.md" && ok "README.md 的项目索引段落仍在" || bad "README.md 的项目索引段落仍在"
finish
