---
status: approved
task: restrict-review-actions
date: 2026-07-18
approved_at: 2026-07-18 15:41
---

# 方案:实现层评审动作边界(静态检查 + 单元测试,禁 build 与启动)

## 背景与目标

当前实现层评审(review.sh)把 Codex 放在一次性副本中以
`--sandbox workspace-write` 运行,且 prompts/review.md 要求"实际运行
plan.md 中的测试用例"——评审者理论上可以安装依赖、build、启动服务,
既慢又不可控(dev server 不自终止,会吊死后台评审)。

目标(用户选定的 B 方案):为评审者划定动作边界——允许静态检查
(lint / 类型检查)与**按性质判定**的自终止测试命令;禁止依赖安装、
构建(build)、启动任何服务或长驻进程、E2E、访问网络。边界外的测试
用例改为审查任务目录 `evidence/` 中实现者留存的证据,相应地实现者的
证据契约(rawf-implement)同步收紧。约束为 prompt 层软约束,副本隔离
与沙箱默认断网继续作为兜底,review.sh 不改。

## 改动范围

| 文件 | 改动 |
|---|---|
| .ai-workflow/review-standards.md | 新增「评审动作边界」小节(唯一权威):按性质判定的允许/禁止清单、超时与中止策略、混合套件处理、边界外用例的证据核验方式;开头角色段括注同步 |
| .ai-workflow/prompts/review.md | "实际运行 plan.md 中的测试用例"改为"在动作边界内运行可运行的用例,边界外靠 evidence/ 证据核验",并指向 review-standards.md |
| .claude/skills/rawf-implement/SKILL.md | 自测一节(第 5 步)收紧证据契约:边界外用例(build / E2E / 需启动服务)的完整原始输出必须落 evidence/(评审者不重跑,只审证据);"评审者会重跑验证"改为"评审者会在动作边界内重跑,边界外核验 evidence/ 证据" |
| docs/decisions/0004-review-action-boundary.md | 新建决策记录:动机、边界定义、证据契约、被否备选(A:read-only 纯静态)、兜底机制 |

明确不动:review.sh(保留 workspace-write 副本隔离作兜底)、
plan-review.sh(本就 read-only 且不运行测试)、rawf-plan / rawf-review /
rawf-report SKILL.md、CLAUDE.md / AGENTS.md(已通过"角色约束见
review-standards.md"间接覆盖)。

## 实现方案

1. review-standards.md 在「评审输入」与「严重度定义」之间插入
   「评审动作边界」小节。边界**按命令性质判定,不以运行器名称一刀切**
   (pytest / vitest 同样可能跑到集成用例或起服务的用例):
   - 允许:读取代码与 diff、grep 类检索;运行满足全部三条性质的检查
     命令——**自终止、不启动服务或长驻进程、不访问网络**。典型:lint
     (eslint / ruff check)、类型检查(tsc --noEmit)、限定到单元测试
     子集的 vitest run / pytest(以路径、marker 或项目 script 明确限定);
   - 超时与中止:单条命令设超时上限(默认 5 分钟,推荐 `timeout` 等
     机制),超时即中止、在评审输出中记录该用例"未能在边界内核验",
     不得反复重试拉长评审;疑似不自终止的命令一律不执行,按边界外处理;
   - 混合套件:单元与集成用例混杂时,只运行可明确限定的单元子集,
     其余按边界外用例处理,不得为"跑全量"而放宽限定;
   - 禁止:安装或更新依赖(npm/pnpm install、pip 等)、构建
     (next build 等)、启动任何服务器或长驻进程(next dev、uvicorn、
     docker 等)、E2E(playwright)、访问网络;
   - 边界外的测试用例(build / E2E / 需启动服务类):不运行,改为审查
     evidence/ 中实现者留存的原始输出,证据缺失或与实现记录矛盾按虚报
     处理(维持既有 blocker 语义)。
2. prompts/review.md 同步措辞,评审动作以 review-standards.md 为权威。
3. rawf-implement/SKILL.md 第 5 步同步证据契约,与上述边界闭环:
   - 边界外用例的**完整原始输出必须在评审前落 evidence/**(不再限于
     "体量较大"才落盘),实现记录引用之;缺失即会被评审按虚报处理;
   - "评审者会重跑验证"改为"评审者会在动作边界内重跑可运行的用例,
     边界外用例只核验 evidence/ 证据"。
4. 新建 docs/decisions/0004,记录 A/B 取舍、证据契约与兜底
   (副本隔离、沙箱断网)。

## 测试用例

| 编号 | 前置条件 | 步骤 | 预期结果 |
|---|---|---|---|
| TC-01 | 改动完成 | grep review-standards.md | 存在「评审动作边界」小节;允许清单含 lint/类型检查/限定单元子集,禁止清单含依赖安装、build、启动服务/长驻进程、E2E、网络 |
| TC-02 | 同上 | grep prompts/review.md | 旧表述"实际运行 plan.md 中的测试用例"已消失;新表述引用动作边界并保留"虚报按 blocker" |
| TC-03(边界) | 同上 | grep 两文件 | 存在"边界外用例靠 evidence/ 证据核验"的兜底表述——评审者遇到 build/E2E 用例时有明确替代动作,不致无所适从或擅自越界 |
| TC-04(契约闭环) | 同上 | grep rawf-implement/SKILL.md 与 review-standards.md | 实现者侧:边界外用例证据必须落 evidence/ 的要求存在,"评审者会重跑验证"旧表述已更新;两文件对边界外用例的处理(实现者留证 ↔ 评审者审证)语义一致,无"评审者重跑一切"类矛盾残留 |
| TC-05(按性质判定) | 同上 | grep review-standards.md | 存在"按性质判定/不以运行器名称"表述、三条性质(自终止/不起服务/不访问网络)、超时中止策略、混合套件只跑限定子集的规则 |
| TC-06(残留) | 同上 | 全仓 grep(排除 .ai/、.git/、docs/decisions/ 沿革) | 无与新边界矛盾的"实际运行测试"类残留表述 |
| TC-07 | 同上 | 检查 docs/decisions/ | 0004 文件存在,含背景、边界定义、证据契约、被否备选 A 及理由、兜底机制 |

## 风险与回滚

- **软约束风险**:边界靠 prompt 文字,Codex 仍可能尝试越界命令。兜底:
  评审跑在一次性副本上(主工作区隔离),codex workspace-write 沙箱默认
  断网(装依赖/外呼失败);最坏结果是评审变慢或该轮无效重跑,不伤工作区。
- **核验力度下降**:build/E2E 类用例不再被评审者重跑,靠证据审查。
  实现者自测(rawf-implement 第 5 步)仍要求真实运行全部用例,且边界外
  用例的完整原始输出强制落 evidence/(本方案同步收紧),补足审查抓手。
- **实现者负担略增**:边界外用例必须留完整原始输出,不再限于大体量
  证据才落盘;换来的是评审可核验性,属可接受代价。
- 回滚:纯文本改动,单提交 git revert 即可。
