---
task: template-versioning
round: 01
date: 2026-07-25
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| CHANGELOG.md | 新建:Keep a Changelog / SemVer 引用;行首锚定的受管路径归类两行(可整体替换 6 项 / 需人工合并 5 项,附归类原因);条目规则(每版必含升级指引);`## [1.0.0]` 基线条目(升级指引:基线版本,无升级来源) |
| .ai-workflow/TEMPLATE-VERSION | 新建:version 1.0.0 / source 模板仓库 URL / adopted 占位(consumer 拷入时填写) |
| README.md | 新增「版本与升级」节(SemVer 按闸门兼容性分级表、发布纪律三同步、升级流程——模板克隆 + checkout --detach 锚定 NEW 快照 + 11 受管路径 diff 命令块、不添加模板 remote 声明);「开新项目」插入第 2 步填 adopted(后续步骤重编号 3-8,原第 4 步内部引用同步改为"第 3 步");「存量项目迁移」插入第 3 步版本认领/基线对齐规则(unknown、不得直接认领,后续步骤重编号 4-5) |
| docs/decisions/0008-template-versioning.md | 新建:四段体例,固化 SemVer+tag+Release 三同步、TEMPLATE-VERSION 落位、克隆锚定升级、基线认领、被否备选(copier/cruft、发布/升级脚本及否因) |

## 修复对照

(第 1 轮,不适用)

## 测试结果

| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | evidence/tc-01.log(结构关键词 + 归类两行集合严格等值比较通过 + 1.0.0 条目内升级指引/基线说明命中,OK,exit 0;中间产物 wholesale/manual-line*.txt、changelog-entry.txt) |
| TC-02 | A | pass | evidence/tc-02.log(version 语义化格式与 1.0.0、source URL、adopted 字段命中,OK,exit 0) |
| TC-03 | A | pass | evidence/tc-03.log(节内关键词含克隆命令与"不添加模板 remote";唯一 git diff 代码块、块内 git diff 恰 1 次、变量形式引用、checkout --detach 锚定、无尖括号占位符、11 受管路径逐一在命令续行内;开新项目/迁移节断言全过,OK,exit 0;中间产物 ver-sec/ver-block-1/diff-argv.txt) |
| TC-04 | A | pass | evidence/tc-04.log(0008 标题与四段行首逐段命中 + SemVer/tag/Release/TEMPLATE-VERSION/copier,OK,exit 0) |
| TC-05 | A | pass | evidence/tc-05.log(REGRESSION-OK + SCOPE-OK,exit 0;git status 快照确认改动仅落 4 文件 + .ai/) |
| TC-06 | A | pass | evidence/tc-06.log(改动前 HEAD 无「版本与升级」与 TEMPLATE-VERSION,NEGATIVE-OK,exit 0) |

执行方式:6 条用例命令块自 plan.md「测试命令」逐块提取执行,每份
证据含命令原文、完整 stdout/stderr 与退出码。

## 与方案的偏差

一处编号性偏差:README「开新项目」插入 adopted 步骤后,原第 4 步
「前置依赖」中"「开新项目」第 2 步的两条 git config"的交叉引用随
重编号改为"第 3 步"(纯编号一致性修正,不改变任何语义;plan 未
明确提及该交叉引用)。其余无偏差。
