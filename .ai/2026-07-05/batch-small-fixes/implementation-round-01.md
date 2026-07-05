---
task: batch-small-fixes
round: 01
date: 2026-07-05
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 第 1 项:实现轮计数改 nullglob 数组(用后即关),无实现轮时正确走"尚无实现记录 exit 3",不再以 ls 退出码 1 崩溃 |
| `.claude/hooks/gate-plan.sh` | 第 2 项:`in_ai_dir()` 重构为统一物理归属分流——物理位于项目外的普通路径放行;`.ai/` 豁免、项目内路径走状态闸、符号链接一律走状态闸的语义不变;物理解析失败按项目内处理(fail-closed) |
| `README.md` | 第 3 项:"开新项目"第 3 步措辞对齐现状(scrapy skill 作参考模板,workflows 空目录按需添加 CI) |
| `AGENTS.md` | 第 4 项:新增"Git 提交规范"章节(type 枚举/祈使句/rawf 后缀/一次提交一个主题);第 5 项:技术栈改"层/技术选型"两列表格,TEMPLATE 注释保留 |

## 修复对照

不适用(首轮)。

## 测试结果

驱动新增 B-01〜B-04 与项目外路径测试辅助 `ga()`;全量复跑:

| plan 编号 | 驱动标号 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | B-01 | 通过 | fixture 删除实现轮后跑 review.sh → `rc=3 且 stderr 含'尚无实现记录'`,无评审文件(修复前该场景实测崩溃 rc=1) |
| TC-02 | B-02 | 通过 | draft 状态下以驱动目录(fixture 外)路径喂 gate-plan → rc=0 零输出放行(修复前被 deny 误拦,即本项的现场复现) |
| TC-03 | B-03 | 通过 | fixture 外建符号链接指向 fixture 内 src/app.py → rc=0 且输出 deny JSON,不得经外部链接绕闸 |
| TC-04 | TC-09〜12/GR 块 | 通过 | 既有 gate 行为全回归:draft 拦项目内源码/穿越/项目内符号链接,三种放行,gate-review 四态 |
| TC-05 | B-04 | 通过 | README 无 `ci-*` 残留;AGENTS.md 含"## Git 提交规范"与 type 枚举、技术栈表格(`\| 前端 \|` 匹配) |
| TC-06 | 全量 | 通过 | 38/38(S-01〜08 + TC-02〜23 + GR-01〜04 + B-01〜04) |

`bash -n` gate-plan.sh 与 review.sh 语法检查通过;settings.json 全程无 diff。

## 与方案的偏差

无。5 项均按 plan 落地,无范围外改动。
