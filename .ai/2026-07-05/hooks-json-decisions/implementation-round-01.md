---
task: hooks-json-decisions
round: 01
date: 2026-07-05
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `.claude/hooks/gate-plan.sh` | 新增 `deny()`(jq 构造 `hookSpecificOutput.permissionDecision: deny` JSON + exit 0),plan 未获批拦截点改为调用它;放行路径保持 exit 0 零输出(不输出 allow,交还正常权限流);头部注释同步 |
| `.claude/hooks/gate-review.sh` | ① 新增 `block()`(jq 构造 `{decision: block, reason}` JSON + exit 0),未评审拦截点改为调用它 ② 计数与评审文件存在性判断改为 nullglob 数组(见偏差第 1 条),修复潜伏崩溃;头部注释同步 |

## 修复对照

不适用(首轮)。

## 测试结果

驱动更新:gate-plan 用例断言由"rc=2"改为"rc=0 + stdout 合法 JSON +
permissionDecision==deny + reason 含拦截文案";新增 `deny_ok`/`allow_ok`
断言辅助与 GR-01〜GR-04(gate-review 首次纳入驱动覆盖)。

| plan 编号 | 驱动标号 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | TC-09/11/12 | 通过 | 五种 deny 场景(闸门/脚本/源码/`.ai/../` 穿越/两类符号链接逃逸)均 rc=0 且 stdout JSON 含 hookEventName==PreToolUse、permissionDecision==deny、reason 含"rawf 工作流拦截" |
| TC-02 | TC-10 | 通过 | 三种放行(draft 写 .ai/、approved 写控制文件、无任务)均 rc=0 且 stdout 为空 |
| TC-03 | GR-01 | 通过 | 有实现无评审 → rc=0,`.decision`=="block",reason 含轮次"01"与"/rawf-review" |
| TC-04 | GR-02 | 通过 | 已有 review-round-01-pass.md → rc=0 且零输出 |
| TC-05 | GR-03 | 通过 | `{"stop_hook_active":true}` → rc=0 且零输出(防循环) |
| TC-06 | GR-04 | 通过 | 无 .current-task / 任务目录缺失 / 无实现轮 三种状态均 rc=0 且零输出 |
| TC-07 | 全量 | 通过 | 34/34:S-01〜S-08 + TC-02〜TC-23 + GR-01〜GR-04 |
| TC-08 | 真机(部分) | 通过 | 本轮实现期间全部 Write/Edit 实际经过新 gate-plan 放行路径(approved 状态,零输出零干扰);deny/block 真机路径以驱动直调覆盖(实现期 plan 已 approved,deny 无法真机触发,与 plan 预期一致) |

首跑曾两处失败并当场修复(过程留痕):
1. GR-04 暴露既有潜伏 bug:`count=$(ls ...|wc -l)` 在 set -e/pipefail 下,
   无实现轮时(plan 阶段常态)hook 以退出码 1 崩溃——旧接口下 exit 1 恰被
   视为非阻塞错误而"侥幸放行",JSON 化后此侥幸不复存在,必须修;
2. 修复 1 引入的 nullglob 使后续 `ls review-round-*.md` 空 glob 误列当前
   目录,GR-01 当场抓住 → 评审文件判断同改数组、用后即关 nullglob。
修复后全量复跑 34/34。`bash -n` 两 hook 均通过;settings.json 全程无 diff。

## 与方案的偏差

1. gate-review.sh 的计数/存在性判断重写(nullglob 数组)不在 plan 字面改动
   清单中:系 plan 自身 TC-06(GR-04)暴露的既有崩溃,不修则该用例无法通过;
   改动仍在 plan 范围内文件,拦截语义与文案不变。
2. plan 笔误更正:gate-plan.sh 实际仅一处拦截点(plan 写"两处"),改动范围不变。
3. **范围外发现(未动,提请处置)**:review.sh 第 25 行存在同型 `ls|wc` 计数,
   无实现轮时脚本会在到达"尚无实现记录 exit 3"之前以 ls 的退出码 1 崩溃,
   恰与"评审结论 fail"的退出码语义冲突。因 plan 明确不动 review.sh,留待
   汇报阶段由用户决定(建议后续以同法修复)。
