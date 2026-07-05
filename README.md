<p align="center">
  <img src="./logo.svg" alt="ai-workflow-template logo" width="240">
</p>

# ai-workflow-template

Claude Code 负责开发、OpenAI Codex 负责交叉评审的 AI 工作流模板。
方案与评审全程文件留痕,关键闸门由 hooks 硬约束,人只在两处出现:
确认方案、确认提交。

## 依赖

- Claude Code(主对话/开发者)
- OpenAI Codex CLI(评审者,需已 `codex login`,版本需支持
  `codex exec --output-schema`)
- jq(hooks 与评审结论解析/渲染用,`brew install jq`)

## 工作流

/rawf-plan → 【人工确认方案】→ /rawf-implement → /rawf-review
  → fail:修复轮(最多 3 轮,plan 级问题直接升级人工)
  → pass:/rawf-report → 【人工确认提交】→ 任务关闭

产物:.ai/<yyyy-mm-dd>/<task-slug>/ 下的 plan.md、
implementation-round-NN.md、review-round-NN-<pass|fail>.md、summary.md,
全部随代码提交;运行时状态 .ai/.current-task 不入库。

## 开新项目

1. GitHub 上 Use this template,克隆到本地
2. 全局搜索 `TEMPLATE:`,按各处注释裁剪(AGENTS.md 技术栈、
   .ai-workflow/review-standards.md 评审关注点)
3. 按需增删栈约定:可为你的栈新建 .claude/skills/rawf-stack-*
   (SKILL.md 写初始化、编码与测试约定);.github/workflows/ 为空目录,
   按需添加 CI。栈调整时同步 .ai-workflow/review-standards.md 的
   技术栈关注点
4. 生成应用骨架(若建了 stack skill,按其"初始化"一节执行)
5. 开 Claude Code 会话,/rawf-plan 开始第一个任务

## 机制速览

- gate-plan.sh(PreToolUse):方案未获用户确认前,拦截源码与工作流
  控制文件的写入(仅 .ai/ 产物豁免)
- gate-review.sh(Stop):最新实现轮未经评审前,不许结束回合
- review.sh:codex exec --output-schema 结构化评审;脚本按严重度清单推导
  pass/fail 并与评审自报结论交叉校验,JSON 渲染为评审文件;同轮已有评审
  文件则拒绝重评(历史只增不改)
- 评审在工作区的一次性副本上执行,主工作区不在评审者可写范围,唯一取回
  的产物是评审结论文件;完整性哈希(含未跟踪文件内容/类型/可执行位)保留
  为双保险,主工作区被动过即判评审无效
- 严重度定义唯一权威在 .ai-workflow/review-standards.md;评审输出契约在
  .ai-workflow/schemas/review.schema.json 与 prompts/review.md 的字段语义
  说明(二者与 review.sh 解析/渲染逻辑绑定演化)

## 已知限制

- hook 不拦 Bash 重定向写文件(纪律靠 CLAUDE.md 硬规则)
- plan 的 approved 状态由 Claude 在用户确认后翻转,存在理论上的
  误翻可能(approved_at 留有审计痕迹;可升级为仅人工翻转)
