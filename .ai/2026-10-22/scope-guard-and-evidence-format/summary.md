---
task: scope-guard-and-evidence-format
date: 2026-10-22
rounds: 3
verdict: pass
---

# 任务小结:范围自省提醒 + A 档证据标准格式与机器核验(模板 1.1.0)

## 改动
| 文件 | 摘要 |
|---|---|
| `.ai-workflow/scripts/evidence.sh`(新) | A 档留证器:rawf-evidence v1;同名拒绝覆盖;setsid 子会话;中断全程有界(5 s 宽限后 KILL,启动前中断不执行),退出码固定 INT=130 / TERM=143 |
| `.ai-workflow/scripts/evidence-check.sh`(新) | 以 plan 用例表为基准核对实现记录与每个 A 档证据文件的结构完整性;报告在 stdout,补交清单在 stderr |
| `.ai-workflow/scripts/review.sh` | 启动 codex 前跑 evidence-check,不通过 exit 3、不消耗轮次;报告注入 prompt;渲染「范围核对」节 |
| `.ai-workflow/scripts/plan-review.sh` | 渲染「范围核对」节 |
| `.ai-workflow/schemas/*.schema.json` | 新增必填 `scope_findings` |
| `.ai-workflow/prompts/review.md`、`plan-review.md` | 证据职责重划(格式归机器、内容归评审);范围固定问题 |
| `.ai-workflow/review-standards.md` | rawf-evidence v1 格式、两种留证写法、A 档新核验规则、阅读建议、范围核对 |
| `.ai-workflow/templates/plan.md`、`implementation-round.md`、`summary.md` | 需求原文 / 非目标;偏差三类 + 停车场;范围核对 |
| `.claude/skills/rawf-plan|implement|review|report/SKILL.md` | 承接上述流程 |
| `CLAUDE.md`、`README.md` | 硬规则两条;机制速览 |
| `CHANGELOG.md`、`.ai-workflow/TEMPLATE-VERSION` | 1.1.0 |
| `docs/decisions/0010`、`0011`(新)、`0006` | 证据格式决策、范围自省决策;0006 标注部分取代 |

## 评审历程
| 轮次 | 结论 | 关键问题 |
|---|---|---|
| plan 01 | fail | 4 major:机器核验字段不全、未以 plan 为基准对照、非零退出码误判虚报、TC-16 自举循环 |
| plan 02 | fail | 1 major:多项目并行与查杀隔离无用例 |
| plan 03 | pass | 无 |
| 实现 01 | fail | 3 major:忽略 TERM 时无法强杀收尾、中断退出码未固定、补交清单未写 stderr |
| 实现 02 | fail | 1 major:启动阶段中断仍可能阻塞于 wait、组未建立时转发不重试 |
| 实现 03 | pass | 无 |

三轮实现评审均未就 A 档证据格式提问题(第 1 轮总评明确"未复判证据格式"),
全部问题都是实质缺陷——新机制在本任务自举中按设计生效。

## 范围核对
- **追加类偏差**:无。各轮共 8 条偏差(D-01 ~ D-08)均为替代类,已在对应轮次实现记录说明。
- **评审「范围核对」节**:实现评审 01 / 02 / 03 均为"无";plan 评审 01 ~ 03 运行于旧版 prompt(该节尚未实现),无此节。
- **停车场条目**(待用户决定去向):
  1. 本机 steammarket-refinery 旧会话遗留的孤儿轮询循环(`until … docker build …; do sleep 5; done`,父进程为 1)
  2. plan 评审 fail 率约 75%、实现评审中位 2 轮的成因分析与收敛
  3. 四个 consumer 项目升级到 1.1.0
  4. 安装 shellcheck 后补跑 TC-13 的 shellcheck 部分

## 遗留 minor 及处置
无(最后一轮评审无 minor)。
