---
task: consumer-feedback-1.3.0
round: 01
date: 2026-11-10
---

# 实现记录:第 01 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `docs/decisions/0001-…md` ~ `0013-…md` → `t0001-…md` ~ `t0013-…md`(13 个) | `git mv` 改名,slug 不变;正文里的模板决策编号(标题、互相引用、相对链接目标)加 `t`。t0013 的「其 0015」「其 0014」(派生仓编号)未动;t0013 末尾追加「沿革」一节,记反馈 2、3 的澄清 |
| `docs/decisions/t0014-template-decision-namespace.md` | 新增决策:模板决策 t 前缀独立编号、存量仓不改号、历史不回改、第三类归类「项目自有,创建后即脱钩」;含被否备选 |
| `docs/decisions/README.md` | 写明模板决策 / 项目决策两个系列的文件名与归属;新增「沿革:旧编号对应」一节 |
| `docs/README.md` | 组织表 `decisions/` 行同步两个系列的文件名约定 |
| `README.md` | 7 处 `docs/decisions/NNNN` 加 `t`;「开新项目」新增第 3 步(重置 CHANGELOG、处理 logo、删模板任务目录),原 3 ~ 8 步顺延为 4 ~ 9;「存量项目迁移」对 git config 一步的引用改为第 4 步;「发布纪律」加参考仓须已推送一条;升级 diff 清单加 `'docs/decisions/t*'` 与 `docs/decisions/README.md` |
| `CHANGELOG.md` | 头部归类:「可整体替换」加 `docs/decisions/t*.md`,「需人工合并」加 `docs/decisions/README.md`,新增第三类,括注说明随之更新;新增 `## [1.4.0] - 2026-11-10`(Changed / Added / 升级指引,含写死 13 个旧文件名的迁移命令)。`## [1.3.0]` 起的旧条目未动 |
| `AGENTS.md` | Worker 节「参考」只点名 cscheap-telegram;工程约定第 2 条补判定口径(横切模块 / 外部协议 / 领域逻辑)与成目录、不成目录各一例;目录表 Worker 列注明口径出处;`docs/decisions/0013` → `t0013` |
| `CLAUDE.md` | 4 处 `docs/decisions/NNNN` 加 `t` |
| `.ai-workflow/review-standards.md` | 4 处 `docs/decisions/NNNN` 加 `t` |
| `.ai-workflow/scripts/review.sh`、`plan-review.sh`、`evidence.sh`、`evidence-check.sh`,`.claude/hooks/gate-review.sh`,`.gitignore` | 仅注释行里的决策路径加 `t`(plan-review.sh 的「0003、0012」并列写法同样处理);无可执行行改动 |
| `.ai-workflow/TEMPLATE-VERSION` | `version: 1.4.0` |

合计 28 个文件(13 改名 + 1 新增 + 14 修改),与 plan 估计一致。任务目录内另有
`assets/lib.sh`(断言公共函数)与 `assets/tc01.sh` ~ `tc10.sh`(十条用例的断言脚本)。

实现说明:t0014 正文提到旧编号处写作「第 13 号」「旧第 1 号即 `t0001`」而不写裸的
四位数字,使 TC-04 ②「`t*.md` 中未带 `t` 的四位编号仅 t0013 两处」对全部 t 文件成立;
旧号与新号的逐一对应写在 `docs/decisions/README.md`「沿革」。

## plan 评审 minor 交接
| 来源 | 内容 | 处置 |
|---|---|---|
| `plan-review.sh __minors` | 输出「无」:两轮 plan 评审均未提 minor | 无需处置 |

## 修复对照
| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| — | — | 第 1 轮,不适用 |

## 测试结果
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01.log |
| TC-02 | A | pass | TC-02.log |
| TC-03 | A | pass | TC-03.log |
| TC-04 | A | pass | TC-04.log |
| TC-05 | A | pass | TC-05.log |
| TC-06 | A | pass | TC-06.log |
| TC-07 | A | pass | TC-07.log |
| TC-08 | A | pass | TC-08.log |
| TC-09 | A | pass | TC-09.log |
| TC-10 | A | pass | TC-10.log |

各用例均为 (b) 写法:`evidence.sh TC-NN -- bash assets/tcNN.sh`,exit 0 = 全部断言成立。
本机未安装 shellcheck,未运行;脚本只改注释,TC-06 以「增删行全为注释」与 `bash -n` 核验。

## 与方案的偏差
| 编号 | 类型 | 内容 | 原因 | 处置 |
|---|---|---|---|---|
| — | — | 无 | — | — |

## 停车场
- cscheap-catalog 推送到远端后,把它加回 AGENTS.md Worker 节的参考仓(plan 非目标)。
- cscheap-telegram、cscheap-link、cscheap-catalog 三仓按 1.4.0 升级指引迁移决策目录,
  并各自处理模板带入的 CHANGELOG / logo / `.ai/` 模板任务历史(在各仓内进行,本任务不动)。
- 本机没有 shellcheck:1.2.1 起流程脚本承诺 shellcheck 全级别零条,本次仅改注释未复核。
