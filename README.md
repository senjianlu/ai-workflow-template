# ai-workflow-template

Claude Code 负责开发、OpenAI Codex 负责交叉评审的 AI 工作流模板。
方案与评审全程文件留痕,关键闸门由 hooks 硬约束,人只在两处出现:
确认方案、确认提交。

## 依赖

- Claude Code(主对话/开发者)
- OpenAI Codex CLI(评审者,需已 `codex login`)
- jq(hooks 解析用,`brew install jq`)

## 工作流

/rawf-plan → 【人工确认方案】→ /rawf-implement → /rawf-review
  → fail:修复轮(最多 3 轮,plan 级问题直接升级人工)
  → pass:/rawf-report → 【人工确认提交】→ 任务关闭

产物:.ai/<yyyy-mm-dd>/<task-slug>/ 下的 plan.md、
implementation-round-NN.md、review-round-NN-<pass|fail>.md、summary.md,
全部随代码提交;运行时状态 .ai/.current-task 不入库。

## 开新项目

1. GitHub 上 Use this template,克隆到本地
2. 全局搜索 `TEMPLATE:`,按各处注释裁剪(CLAUDE.md 技术栈、
   AGENTS.md 评审关注点)
3. 删除不用的栈:.claude/skills/rawf-stack-* 与 .github/workflows/ci-*
   (skill 与 AGENTS.md 关注点、CI 三处同步删)
4. 按保留的 stack skill 中"初始化"一节生成应用骨架
5. 开 Claude Code 会话,/rawf-plan 开始第一个任务

## 机制速览

- gate-plan.sh(PreToolUse):方案未获用户确认前,拦截源码写入
- gate-review.sh(Stop):最新实现轮未经评审前,不许结束回合
- review.sh:codex exec 评审,末行 VERDICT 决定 pass/fail 文件名与退出码
- 严重度定义唯一权威在 AGENTS.md;评审输出格式契约在
  .ai-workflow/prompts/review.md(与 review.sh 解析逻辑绑定演化)

## 已知限制

- hook 不拦 Bash 重定向写文件(纪律靠 CLAUDE.md 硬规则)
- 评审完整性校验只覆盖已跟踪文件
- plan 的 approved 状态由 Claude 在用户确认后翻转,存在理论上的
  误翻可能(approved_at 留有审计痕迹;可升级为仅人工翻转)
