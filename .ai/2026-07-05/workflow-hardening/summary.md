---
task: workflow-hardening
date: 2026-07-05
rounds: 7
verdict: pass
---

# 任务小结:工作流加固(评审发现第 1、4、5、6、7 项)

## 改动

| 文件 | 摘要 |
|---|---|
| `.ai-workflow/review-standards.md`(新增) | 评审者手册迁出 AGENTS.md:评审输入、四级严重度、判定规则、技术栈关注点;角色约束加强为"不改代码、不留任何新文件" |
| `AGENTS.md` | 重写为跨工具开放标准的通用项目说明(技术栈+通用硬规则+指针),不再指派评审者角色 |
| `CLAUDE.md` | 首行 `@AGENTS.md` 导入保持单一事实源;补"禁止 Bash 绕过写入闸"硬规则 |
| `.ai-workflow/prompts/review.md` | 评审权威指向 review-standards.md(两处) |
| `.ai-workflow/scripts/review.sh` | 核心加固:①codex 失败显式 exit 3(不与 fail 混淆)②完整性哈希纳入未跟踪文件内容/符号链接目标/可执行位,NUL 定界无歧义③同轮重评拒绝④原子锁互斥并发⑤评审在一次性副本上执行(主工作区隔离)⑥评审结论原子发布(临时文件+mv -n) |
| `.claude/hooks/gate-plan.sh` | 永久可写白名单收窄为仅 `.ai/`;物理路径判定挡 `.ai/../` 穿越与符号链接逃逸;闸门/脚本自身纳入 plan 闸保护 |
| `.gitignore` | 新增 `.ai/**/.review-out-*` 排除发布临时文件 |
| `README.md` | 同步机制速览、已知限制、开新项目裁剪指引 |

## 评审历程

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| 01 | fail | R-01 路径穿越绕过闸门(blocker)、忽略文件盲区、崩溃漏检、settings.json 混入个人授权 |
| 02 | fail | settings.json 复核证据失效(blocker)、符号链接互换绕过哈希 |
| 03 | fail | 符号链接序列化碰撞、codex 无输出误判为 fail |
| 04 | fail | 陈旧 raw 复用、可执行位盲区 → 触发 B 方案(隔离架构) |
| 05 | fail | 并发评审竞态(违反只增不改) |
| 06 | fail | 评审结论发布非原子(cp 半成品阻断重试) |
| 07 | **pass** | 无。全链路原子性补全,TC-01〜24 复跑通过 |

说明:超出默认 3 轮上限的第 4〜7 轮均经用户逐轮明确授权;第 4 轮起将安全
模型从"事后哈希检测"结构性升级为"一次性副本隔离 + 哈希双保险"(用户选 B)。

## 遗留 minor 及处置

无。第 07 轮 pass 评审问题清单为"无"。

## 已知代价(非缺陷)

- 评审前全量复制工作区,超大仓库(庞大 node_modules 等)会增加数秒〜数十秒;
  排除式复制留作后续优化(review.sh 的 hash_excludes 处有 TEMPLATE 注释)。
