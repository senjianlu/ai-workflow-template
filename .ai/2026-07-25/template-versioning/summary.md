---
task: template-versioning
date: 2026-07-25
rounds: 1
verdict: pass
---

# 任务小结:为模板设立版本号与增量升级机制(最小实践)

## 改动

| 文件 | 摘要 |
|---|---|
| CHANGELOG.md | 新建:Keep a Changelog 体例;受管路径归类两行(可整体替换 6 项 / 需人工合并 5 项);每版必含升级指引的条目规则;[1.0.0] 基线条目 |
| .ai-workflow/TEMPLATE-VERSION | 新建:version/source/adopted;随 .ai-workflow/ 整目录拷贝自动带版本 |
| README.md | 新增「版本与升级」节(SemVer 按闸门兼容性分级、发布纪律三同步、模板克隆锚定 NEW 快照的升级流程);开新项目补 adopted 步骤;存量迁移补版本认领/基线对齐规则(unknown、不得直接认领) |
| docs/decisions/0008-template-versioning.md | 新建:固化版本纪律与被否备选(copier/cruft、发布/升级脚本) |

## 评审历程

plan 阶段(用户要求执行;含发布脚本的初版草案经 10 轮评审未收敛,
用户裁决回退最小实践、删除历史评审、重评上限 5 轮):

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| plan-01 | fail | consumer 无模板 tag,升级须在模板克隆中执行(plan-blocker);归类断言改集合等值 |
| plan-02 | fail | PATCH 语义漏向后兼容修复;diff 命令尖括号占位符不可执行 |
| plan-03 | fail | 克隆未锚定 NEW tag 快照 |
| plan-04 | pass | 无问题 |

实现层:

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| 01 | pass | 无问题;TC-01~06 全 A 档证据核验通过 |

## 遗留 minor 及处置

无(最后一轮评审问题清单为空)。
