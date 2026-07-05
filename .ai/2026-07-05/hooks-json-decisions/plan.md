---
status: approved
task: hooks-json-decisions
date: 2026-07-05
approved_at: 2026-07-05 17:28:00
---

# 方案:hooks 决策输出现代化(JSON 替代 exit 2 + stderr)

## 背景与目标

两个 hook 目前用 exit code 2 + stderr 表达"拒绝/拦截"。Claude Code 现行
推荐接口是 JSON 决策输出(exit 2 仍被支持,但 PreToolUse 的 JSON
`permissionDecision` 是官方首选,且能表达 exit code 无法表达的 `ask`):

1. `gate-plan.sh`(PreToolUse):拒绝改为 stdout 输出
   `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`
   并 exit 0;
2. `gate-review.sh`(Stop):拦截改为 stdout 输出
   `{"decision":"block","reason":"…"}` 并 exit 0(Stop 事件的 JSON 契约与
   PreToolUse 不同,顶层 decision 字段对 Stop 是现行接口)。

**语义保持严格 1:1**:所有"放行"路径维持 exit 0 且**无输出**——绝不输出
`permissionDecision: "allow"`,因为显式 allow 会跳过用户自己的权限确认流程,
是行为变更;deny 场景不引入 `ask`,人工闸保持硬闸。JSON 用 jq 构造,杜绝
reason 文本(含中文/引号/变量)的转义问题。

## 改动范围

| 文件 | 动作 |
|---|---|
| `.claude/hooks/gate-plan.sh` | 新增 `deny()` 辅助函数(jq 构造 JSON + exit 0),两处 `echo >&2; exit 2` 改为调用它;头部注释的退出码契约说明同步 |
| `.claude/hooks/gate-review.sh` | 新增 `block()` 辅助函数(jq 构造 `{"decision":"block","reason":…}` + exit 0),一处拦截改为调用它;头部注释同步 |

**明确不动**:`.claude/settings.json`(hook 注册方式不变)、review.sh、skills、
templates、README/CLAUDE.md(经 grep 确认无退出码表述)、所有拦截提示文案
(仅搬运到 reason 字段)。

## 实现方案

gate-plan.sh:

```bash
deny() {
  jq -n --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
```

两处替换:plan 未获批的拦截、(保持现有文案不变传入 $1)。放行路径不变。

gate-review.sh:

```bash
block() {
  jq -n --arg r "$1" '{decision:"block",reason:$r}'
  exit 0
}
```

一处替换:未评审拦截。`stop_hook_active` 防循环检查与全部放行路径不变。

## 测试用例

沿用 fixture + 驱动(scratchpad rawf-tests/run-tests.sh)。gate-plan 既有用例
(旧 TC-09〜TC-12)的断言由"rc=2"改写为"rc=0 且 stdout 为合法 JSON 且
permissionDecision==deny";gate-review 此前无驱动覆盖,本次补上。

| 编号 | 前置条件 | 步骤 | 预期结果 |
|---|---|---|---|
| TC-01 | fixture;plan `status: draft` | 依次以 file_path=闸门脚本/review.sh/源码/`.ai/../` 穿越/符号链接逃逸 喂 gate-plan.sh | 每次 rc=0;stdout 经 jq 校验为合法 JSON;`.hookSpecificOutput.permissionDecision`=="deny";`permissionDecisionReason` 非空且含"rawf 工作流拦截";hookEventName=="PreToolUse" |
| TC-02 | fixture | 三种合法放行:draft 写 `.ai/` 产物、approved 后写控制文件、无 .current-task 写任意 | 每次 rc=0 且 stdout 为空(不输出 allow,交还正常权限流) |
| TC-03 | fixture;有 implementation-round-01 无评审文件 | `echo '{}' \| gate-review.sh` | rc=0;stdout 合法 JSON;`.decision`=="block";reason 含"第 01 轮"与"/rawf-review" |
| TC-04 | 同上但已存在 review-round-01-pass.md | 同上 | rc=0 且 stdout 为空(放行结束回合) |
| TC-05 | 同 TC-03(应拦截的状态) | `echo '{"stop_hook_active":true}' \| gate-review.sh` | rc=0 且 stdout 为空(防循环:已在 stop hook 续行中则不再拦) |
| TC-06 | 无 .current-task / 任务目录不存在 / 无实现轮 三种状态 | `echo '{}' \| gate-review.sh` | 三种均 rc=0 且 stdout 为空 |
| TC-07 | 改动完成 | 全量回归:S-01〜S-08 + 旧 TC-02〜TC-23(gate 断言改 JSON 后) | 全部通过 |
| TC-08(真机) | 本任务自身流程 | 实现期间的每次 Write/Edit 都实际经过新 gate-plan 放行路径;本轮实现记录写完、评审文件生成前若结束回合,新 gate-review 应以 JSON block 拦截 | 放行路径真机验证通过;拦截路径以驱动用例为准(实现期 plan 已 approved,deny 分支无法真机触发) |

## 风险与回滚

- **JSON 构造失败的失效方向**:jq 缺失/失败时 set -e 令脚本以非 0 非 2 退出,
  Claude Code 视为"非阻塞错误"→ 闸门失效方向是"开"。此风险现状已存在
  (两 hook 本就依赖 jq 解析输入,jq 缺失时同样失效),本次未新增依赖面;
  README 依赖节已列 jq 为硬依赖。
- **兼容性**:exit 2 与 JSON 决策输出并存于当前 Claude Code;JSON 为推荐
  接口,不存在旧版不识别 JSON 的回退问题(本机版本以 update-config 官方
  文档确认支持)。
- **行为变化面**:deny/block 的信息从 stderr 变为结构化 reason,Claude 收到
  的反馈内容不变(同文案);用户在 transcript 中看到的呈现形式可能略有差异。
- **回滚**:单 commit,`git revert` 即可。
