---
task: add-workers-stack
round: 01
date: 2026-11-09
---

# 实现记录:第 01 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `AGENTS.md` | 「技术栈」新增 `### Cloudflare Worker`(位于「爬虫」与「部署」之间):定位段、11 行标准表、四条形态级工程约定、对外契约文档三层;「目录约定 > 应用内」表新增「Worker 应用」列(8 行均四列) |
| `.ai-workflow/review-standards.md` | 「技术栈评审关注点」新增 `- Cloudflare Workers:` 条(位于 Scrapy 条之后、通用条之前) |
| `docs/decisions/0013-workers-standard-stack.md` | 新增决策记录:七项决定 + 被否备选(Hono + chanfana 定为标准、`src/` 布局、照 cscheap-link 现形) |
| `.gitignore` | 新增 Cloudflare Workers 块(五行,与 telegram / catalog 两仓一致) |
| `CHANGELOG.md` | 新增 `## [1.3.0] - 2026-11-09`:Added 四条 + 升级指引(AGENTS.md 需人工合并、`.ai-workflow/` 可整体替换、`.gitignore` 与 0013 按需自取) |
| `.ai-workflow/TEMPLATE-VERSION` | `version: 1.3.0` |

## plan 评审 minor 交接
| 来源 | 内容 | 处置 |
|---|---|---|
| 01/R-03 | 留证命令混用了仓库根与任务目录的相对路径 | 已在 plan 修订中解决(第 02 轮) |
| 01/R-04 | TC-02 混淆了表格列数与竖线数,且测试表内存在未转义竖线 | 已在 plan 修订中解决(第 02、03 轮) |
| 01/R-05 | TC-06 未展开未跟踪目录 | 已在 plan 修订中解决(`--untracked-files=all`) |
| 01/R-06 | 调研摘要声明采纳的部分规则没有进入实现清单 | 已在 plan 修订中解决 |
| 02/R-02 | TC-01 将三列表格的竖线数量误写为五个 | 已在 plan 修订中解决 |
| 02/R-03 | TC-02 仍包含会破坏 Markdown 分列的未转义竖线 | 已在 plan 修订中解决 |
| 02/R-04 | TC-08 的截取范围排除了它要求检查的决策引用 | 已在 plan 修订中解决 |
| 02/R-05 | 调研摘要仍将 --env 写成所有远端部署的要求 | 已在 plan 修订中解决 |

## 修复对照
| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|

## 测试结果
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01.log |
| TC-02 | A | pass | TC-02.log |
| TC-03 | A | pass | TC-03.log |
| TC-04 | A | pass | TC-04.log |
| TC-05 | A | pass | TC-05.log |
| TC-06 | A | pass | TC-06.log(git status 快照另存 git-status.txt) |
| TC-07 | A | pass | TC-07.log(内层 TC-01 断言对 HEAD 版本全部 MISS,外层 exit 0) |
| TC-08 | A | pass | TC-08.log |

断言脚本为 `evidence/tc-NN.sh`,公共辅助在 `evidence/lib.sh`(TC-01 与 TC-07 共用
`check_tc01`,保证反向对照与正向断言同款)。

## 与方案的偏差
| 编号 | 类型 | 内容 | 原因 | 处置 |
|---|---|---|---|---|
| D-01 | 替代 | AGENTS.md 工程约定第一条折行位置调整为"入口类\n不放辅助方法"(措辞与 plan 一致) | 原折行把"不放辅助方法"断成两行,TC-08 的 `grep -F` 逐词断言按 plan 要求须命中整词 | 如实记录;文字内容未变 |

## 停车场
- cscheap-link 与标准的偏差(`worker/` 子目录、普通 `ExportedHandler`、npm、健康检查路径 `/health`)只记在决策 0013,是否对齐由该仓另开任务决定。
