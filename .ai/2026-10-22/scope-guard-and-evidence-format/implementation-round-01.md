---
task: scope-guard-and-evidence-format
round: 01
date: 2026-10-22
---

# 实现记录:第 01 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/evidence.sh`(新) | A 档留证器:rawf-evidence v1 头部/正文/尾部;noclobber 原子创建、同名拒绝覆盖;setsid 子会话 + FIFO 合流 tee;INT/TERM 转发整组并仍写尾部;透传退出码,自身错误 exit 3 |
| `.ai-workflow/scripts/evidence-check.sh`(新) | 以 plan 用例表为基准对照实现记录(MISSING-ROW / TIER-MISMATCH / EXTRA-ROW / EMPTY-TABLE / BLOCKED),逐个 A 档证据文件核结构(NO-REF / MISSING / NO-HEADER / BAD-HEADER / NO-BODY / NO-FOOTER / BAD-EXIT / TRUNCATED);exit 0/1/2/3 |
| `.ai-workflow/scripts/review.sh` | codex 启动前调用 evidence-check:rc 1 → stderr"证据核验未通过"+ 补交清单,exit 3,codex 不启动;rc 0 → 报告替换 `{{EVIDENCE_REPORT}}`;rc 2 → 历史任务占位;渲染新增「范围核对」节(`.scope_findings // []`) |
| `.ai-workflow/scripts/plan-review.sh` | 渲染新增「范围核对」节(同上容错) |
| `.ai-workflow/schemas/review.schema.json`、`plan-review.schema.json` | 新增必填 `scope_findings: string[]` |
| `.ai-workflow/prompts/review.md` | 重写:机器核验报告注入、A 档只核三件事、格式不再是评审意见、两种留证写法、阅读建议、范围核对固定问题、新字段语义 |
| `.ai-workflow/prompts/plan-review.md` | 新增固定问题 4(范围自省)、新字段语义、缺需求原文/非目标 → major |
| `.ai-workflow/review-standards.md` | A 档形态改为 rawf-evidence v1;新增「rawf-evidence v1 格式」「两种留证写法」小节;逐档核验规则 A 档改写(格式归机器、三件事、严重度映射、历史任务兜底);新增阅读建议与「范围核对」小节 |
| `.ai-workflow/templates/plan.md` | frontmatter `evidence_format: v1`;新增「需求原文」「非目标」;A 档证据说明改为 evidence.sh 与留证写法 |
| `.ai-workflow/templates/implementation-round.md` | 测试结果说明改为 evidence.sh 文件名 + 自跑 evidence-check;偏差改为表格(收窄/替代/追加 + 处置);新增「停车场」 |
| `.ai-workflow/templates/summary.md` | 新增「范围核对」节 |
| `.claude/skills/rawf-plan/SKILL.md` | 需求原文/非目标必填、evidence_format、A 档留证写法、摘要必带范围自省三问、范围核对条目转述 |
| `.claude/skills/rawf-implement/SKILL.md` | 偏差三类与追加规则、evidence.sh 留证、写完自跑 evidence-check |
| `.claude/skills/rawf-review/SKILL.md` | exit 3"证据核验未通过"分流(不开新轮)、范围核对条目交用户、A 档格式复判列为可申诉误报 |
| `.claude/skills/rawf-report/SKILL.md` | 汇总含范围核对;就停车场与范围核对条目征求裁决 |
| `CLAUDE.md` | 硬规则新增两条(A 档经 evidence.sh;追加类偏差不得自行实现) |
| `README.md` | 机制速览:证据机器核验与范围自省 |
| `CHANGELOG.md`、`.ai-workflow/TEMPLATE-VERSION` | 1.1.0 条目(Added / Changed / 升级指引);版本号 |
| `docs/decisions/0010-evidence-format-v1.md`、`0011-scope-reflection.md`(新) | 两条决策记录 |
| `docs/decisions/0006-test-evidence-tiers.md` | 顶部标注"已被 0010 部分取代" |

## 修复对照
(第 1 轮,无)

## 测试结果
<!-- 留证写法 (b):每条用例一个断言脚本 evidence/tc-NN.sh(公共库 evidence/lib.sh),
     由 evidence.sh 包住产出 TC-NN.log;exit 0 = 该用例全部断言成立,被测命令的
     退出码与输出在正文中。 -->
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
| TC-11 | A | pass | TC-11.log |
| TC-12 | A | pass | TC-12.log |
| TC-13 | A | pass | TC-13.log(shellcheck 未安装,已在正文记录,bash -n 四个脚本全部通过) |
| TC-14 | A | pass | TC-14-r2.log(首次 TC-14.log 因断言脚本自身写法错误 exit 1,见偏差 D-02;两份都保留) |
| TC-15 | A | pass | TC-15.log |
| TC-16 | A | pass | TC-16.log |
| TC-17 | A | pass | TC-17.log |
| TC-18 | A | pass | TC-18.log |
| TC-19 | A | pass | TC-19.log |

## 与方案的偏差
| 编号 | 类型 | 内容 | 原因 | 处置 |
|---|---|---|---|---|
| D-01 | 替代 | TC-10 后半"同一 JSON 去掉 scope_findings 后用 `__publish_round` 路径重渲染"改为:在同一临时项目再开第 02 轮,假 codex 输出不含 scope_findings 的 JSON,经 review.sh 正常路径渲染 | review.sh 没有 `__publish_round` 测试入口(只有 `__workspace_hash`),plan 把 plan-review.sh 的入口误写到了 review.sh;为不新增 plan 外的测试入口,改走真实路径 | 断言目标不变:不报错且「范围核对」节为"无" |
| D-02 | 替代 | TC-14 的断言"review-standards.md 不再含'缺失或不完整 → blocker'"改为"不再含旧 A 档主规则措辞'中须有该用例的完整原始输出'" | plan 第 2 节明确保留历史任务(无 evidence_format)的兜底条款,该条款仍需写"缺失或不完整 → blocker";同时首版断言用多行模式 `grep -F` 会按行拆分匹配,导致 TC-14.log 首跑 exit 1,修正后以 `-l r2` 重留证 | 两份证据均保留;断言意图(旧主规则已移除)不变 |
| D-03 | 替代 | evidence.sh 的 FIFO 用 `mktemp -u` 放在 `${TMPDIR:-/tmp}`(项目外),plan 写"不用项目外临时文件" | 合流 tee 需要一个 FIFO;放项目内会进评审指纹并污染工作区,放 /tmp 且唯一命名无竞态、EXIT trap 清理;仍满足"无锁、无共享状态、不写任务目录以外的项目路径" | 脚本头注释已说明;无其它影响 |
| D-04 | 替代 | TC-04 / TC-19 的被包命令用 `sleep 37.3` / `sleep 613` 代替 plan 的 `sleep 30` / `sleep 600`,存活判定用 `pgrep -x sleep -a` | `pgrep -f 'sleep 30'` 会命中 Claude Code 包装 shell 自身的命令行文本与无关进程;`-x sleep` + 唯一时长消除误判 | 断言语义不变 |

## 停车场
- plan 评审 fail 率约 75%、实现评审中位 2 轮的成因分析与收敛(本任务非目标)
- 四个 consumer 项目升级到 1.1.0(按 CHANGELOG 升级指引,各项目自行执行)
- 本机未安装 shellcheck;安装后可补跑 TC-13 的 shellcheck 部分
