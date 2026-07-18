---
task: restrict-review-actions
round: 01
date: 2026-07-18
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| .ai-workflow/review-standards.md | 新增「评审动作边界」小节:按命令性质判定(自终止 / 不起服务或长驻进程 / 不访问网络三条全满足才可运行),单命令默认 5 分钟超时并记录超时用例,混合套件只跑可限定的单元子集,禁止清单(依赖安装 / build / 启动服务或长驻进程 / E2E / 网络),边界外用例改审 evidence/ 完整原始输出;开头角色段括注指向该小节 |
| .ai-workflow/prompts/review.md | 删除"请实际运行 plan.md 中的测试用例"旧表述,改为"边界内重跑可运行用例、边界外审 {{TASK_DIR}}/evidence/ 证据并交叉比对",证据缺失/矛盾/虚报按 blocker;动作权威指向 review-standards.md |
| .claude/skills/rawf-implement/SKILL.md | 第 5 步收紧证据契约:边界外用例(build / E2E / 需启动服务类)完整原始输出**必须**评审前落 evidence/(评审者不重跑,缺失按虚报);"评审者会重跑验证"改为"边界内重跑、边界外核验证据" |
| docs/decisions/0004-review-action-boundary.md | 新建决策记录:背景、边界定义、证据契约、被否备选 A(read-only 纯静态)及否因、兜底机制(副本隔离 + 沙箱断网)与残留风险 |

## 修复对照

(第 1 轮,不适用)

## 测试结果

自测脚本 evidence/test-action-boundary.sh(从 evidence/ 无参执行,首行
`REPO: /Users/xujinpeng/Projects/2026/ai-workflow-template` 证明验证对象
为当前工作区),完整输出见 evidence/test-action-boundary-output-round01.txt,
10 项检查全过(pass=10 fail=0)。

| 编号 | 结果 | 证据 |
|---|---|---|
| TC-01 | 通过 | 边界小节 + 允许/禁止清单齐备(压平文本断言) |
| TC-02 | 通过 | 旧表述已消失(TC-02a);新表述引用动作边界且保留"虚报按 blocker"(TC-02b) |
| TC-03 | 通过 | review-standards.md 与 prompts/review.md 均含"边界外用例审 evidence/ 证据"兜底 |
| TC-04 | 通过 | 实现者侧"完整原始输出必须落 evidence/、评审者不重跑"存在(a);旧"评审者会重跑验证"已更新(b);两侧语义呼应(c) |
| TC-05 | 通过 | "按命令性质判定/不以运行器名称"、三条性质、默认 5 分钟超时即中止、混合套件只跑限定子集,断言全命中 |
| TC-06 | 通过 | 全仓 grep"实际运行 plan.md 中的测试用例"残留为零(排除 .ai/、.git/、docs/decisions 沿革引用) |
| TC-07 | 通过 | 0004 存在且含背景/决定/被否备选(read-only)/证据契约/影响与兜底 |

## 与方案的偏差

无。docs/decisions/README.md 经检查无索引列表,无需同步(方案未列入,
实际也不需要)。
