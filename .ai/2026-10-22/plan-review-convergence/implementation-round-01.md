---
task: plan-review-convergence
round: 01
date: 2026-10-22
---

# 实现记录:第 01 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/plan-review.sh` | 默认上限 3 → 5;上限检查后先快照 plan.md 为 `.plan-review-raw-NN.plan.md`;`build_round_context` 生成 `{{ROUND_CONTEXT}}`(模式行 + 上一轮评审路径 + 两轮快照间 diff;第 1、2 轮全量穷尽,第 3 轮起收敛,无上一轮快照回退全量,未修订时注明);占位替换前关闭 `patsub_replacement`,ROUND_CONTEXT 最后替换;发布前比对 plan.md 与快照 sha256,不一致 exit 3、不发布;新增只读入口 `__minors`;头注释同步 |
| `.ai-workflow/prompts/plan-review.md` | 重写:`{{ROUND_CONTEXT}}`、返工判据、全量穷尽五维度(一次列全、含 minor、overall 逐维度)、收敛三条规则、未修 minor 不要求逐轮重复 |
| `.ai-workflow/review-standards.md` | 「plan 阶段评审语义」新增「返工判据」「分轮模式」两小节;「逐档核验规则」新增"机械性更正"条款 |
| `.ai-workflow/templates/implementation-round.md` | 新增「plan 评审 minor 交接」节 |
| `.claude/skills/rawf-plan/SKILL.md` | 写作粒度;默认 5 轮;分轮模式与修订纪律;评审运行期间不得修改 plan.md |
| `.claude/skills/rawf-implement/SKILL.md` | 第 1 轮前 `__minors` 跨轮交接;机械性更正(回写 plan 测试表 + 标注 + 记"替代") |
| `CLAUDE.md`、`AGENTS.md` | plan 评审默认 5 轮;实现层修复默认 3 轮 |
| `README.md` | 机制速览一条 |
| `docs/decisions/0012-plan-review-convergence.md`(新)、`0001`、`0003` | 决策记录;0001 修订沿革;0003 部分取代标注 |
| `CHANGELOG.md`、`.ai-workflow/TEMPLATE-VERSION` | 1.2.0 |

## plan 评审 minor 交接
| 来源 | 内容 | 处置 |
|---|---|---|
| — | 无:`plan-review.sh __minors` 输出"无",本任务第 01 ~ 03 轮 plan 评审均未报 minor | — |

## 修复对照
(第 1 轮,无)

## 测试结果
<!-- 留证写法 (b):每条用例一个断言脚本 evidence/tc-NN.sh(公共库 evidence/lib.sh),由
     evidence.sh 包住产出;exit 0 = 全部断言成立。共留证三次:无标签一次、-l r2、-l r3,
     每次都是全部通过;重留原因是 plan-review.sh 两次修整自身新代码引入的 shellcheck
     提示(见偏差 D-02),最终以 r3 为准,前两次保留不动(.ai/ 只增不改)。 -->
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01-r3.log |
| TC-02 | A | pass | TC-02-r3.log |
| TC-03 | A | pass | TC-03-r3.log |
| TC-04 | A | pass | TC-04-r3.log |
| TC-05 | A | pass | TC-05-r3.log |
| TC-06 | A | pass | TC-06-r3.log |
| TC-07 | A | pass | TC-07-r3.log |
| TC-08 | A | pass | TC-08-r3.log(shellcheck 0.11.0,装于 /tmp 临时 venv;error 级 0 条;默认级别仅剩 5 条既有 warning/note,与改动前相同) |
| TC-09 | A | pass | TC-09-r3.log |
| TC-10 | A | pass | TC-10-r3.log |
| TC-11 | A | pass | TC-11-r3.log |
| TC-12 | A | pass | TC-12-r3.log |

## 与方案的偏差
| 编号 | 类型 | 内容 | 原因 | 处置 |
|---|---|---|---|---|
| D-01 | 替代 | 占位替换前关闭 bash 5.2 默认开启的 `patsub_replacement`(plan 未写明);TC-02 的修订行改为含 `&&`、`2>&1` 的文本,并加断言"diff 原样含该行""无 `{{ROUND_CONTEXT}}` 残留" | 实测:开启时替换文本里的 `&` 被改写为占位原文,plan 的 diff 注入会被破坏;属实现"注入修订 diff"所必需,不新增对外行为;TC-02 断言覆盖关闭后的正确行为 | 只加断言,不改 TC-02 预期结果 |
| D-02 | 替代 | `build_round_context` 查找上一轮评审文件由 `ls` 改为 glob 循环,并为代码栅栏的字面反引号加 `shellcheck disable=SC2016` 注释 | 首次留证后 TC-08 默认级别输出中出现本任务新代码引入的 2 条 note(SC2012、SC2016);修整中一度又引入 SC1007,随即改正。最终 plan-review.sh 的 shellcheck 输出与改动前相同 | 行为不变;证据以 r3 为准 |

## 停车场
- review.sh 注入证据报告(`{{EVIDENCE_REPORT}}`)时同样受 `patsub_replacement` 影响:报告 cmd 列中 `%q` 转义的 `\&` 会丢失反斜杠(只影响显示,不影响核验结论)。review.sh 在本任务"明确不动"清单内,未处理
- shellcheck warning/note 级的既有条目(review.sh、plan-review.sh 的未用变量,evidence.sh 经 trap 调用的函数被误报为未调用),均无害,本任务非目标
