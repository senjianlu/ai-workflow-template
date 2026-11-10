#!/usr/bin/env bash
# TC-08:开新项目 9 步与新步骤、存量迁移引用、CHANGELOG 三类归类、升级 diff 清单、决策索引
. "$(dirname "$0")/lib.sh"
new=$(sed -n '/^## 开新项目$/,/^## 存量项目迁移$/p' README.md)
steps=$(echo "$new" | grep -cE '^[0-9]+\. ')
echo "## 开新项目步骤编号:$(echo "$new" | grep -oE '^[0-9]+\. ' | tr -d '\n')"
[ "$steps" -eq 9 ] && ok "开新项目共 9 步" || bad "开新项目共 9 步(实际 $steps)"
s3=$(echo "$new" | sed -n '/^3\. /,/^4\. /p' | sed '$d')
echo "## 第 3 步原文"; echo "$s3"
for k in 'CHANGELOG.md' 'logo.svg' '.ai/'; do echo "$s3" | grep -qF -- "$k" && ok "第 3 步提到 $k" || bad "第 3 步提到 $k"; done
echo "$new" | grep -qE '^4\. 启用提交约束' && ok "git config 一步现为第 4 步" || bad "git config 一步现为第 4 步"
check "存量迁移引用「开新项目」第 4 步" has README.md '并执行「开新项目」第 4 步的'
! grep -qF '「开新项目」第 3 步的' README.md && ok "不再引用旧的第 3 步(git config)" || bad "不再引用旧的第 3 步(git config)"
hdr=$(sed -n '1,/^## \[/p' CHANGELOG.md)
echo "## CHANGELOG 头部归类行"; echo "$hdr" | grep -E '^- '
[ "$(echo "$hdr" | grep -cE '^- (可整体替换|需人工合并|项目自有,创建后即脱钩):')" -eq 3 ] && ok "头部归类共三类" || bad "头部归类共三类"
echo "$hdr" | grep -E '^- 可整体替换:' | grep -qF 'docs/decisions/t*.md' && ok "可整体替换含 docs/decisions/t*.md" || bad "可整体替换含 docs/decisions/t*.md"
echo "$hdr" | grep -E '^- 需人工合并:' | grep -qF 'docs/decisions/README.md' && ok "需人工合并含 docs/decisions/README.md" || bad "需人工合并含 docs/decisions/README.md"
own=$(echo "$hdr" | grep -E '^- 项目自有')
for k in 'CHANGELOG.md' 'logo.svg' '.ai/'; do echo "$own" | grep -qF -- "$k" && ok "项目自有类含 $k" || bad "项目自有类含 $k"; done
cmd=$(sed -n '/^git diff "v\$OLD\.\.v\$NEW"/,/^```$/p' README.md)
echo "## README 升级 diff 命令"; echo "$cmd"
echo "$cmd" | grep -qF "'docs/decisions/t*'" && ok "diff 清单含 'docs/decisions/t*'" || bad "diff 清单含 'docs/decisions/t*'"
echo "$cmd" | grep -qF 'docs/decisions/README.md' && ok "diff 清单含 docs/decisions/README.md" || bad "diff 清单含 docs/decisions/README.md"
D=docs/decisions/README.md
for k in '`tNNNN-<slug>.md`' '`NNNN-<slug>.md`' '## 沿革:旧编号对应' '`0001` → `t0001`' '`0013` → `t0013`'; do check "决策索引含:$k" has "$D" "$k"; done
check "docs/README.md 组织表同步两个系列" has docs/README.md '模板决策 `tNNNN-<slug>.md`,项目决策 `NNNN-<slug>.md`'
finish
