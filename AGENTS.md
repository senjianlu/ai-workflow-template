# 项目说明

<!-- TEMPLATE: 一两句话描述本项目。 -->

本文件面向进入本仓库的任何 AI 编码工具(AGENTS.md 开放标准),只描述
项目事实与通用约束,不为任何工具指派角色。

## 技术栈

<!-- TEMPLATE: 按项目实际增删行。 -->

| 层 | 技术选型 |
|---|---|
| 前端 | Node.js + TypeScript + Next.js + shadcn/ui |
| 后端 | Python 3 + FastAPI |
| 爬虫 | Python 3 + Scrapy |
| 部署 | GitHub Actions(.github/workflows/) |

## 通用硬规则(对任何 AI 工具生效)

- 永不主动 git commit / git push,必须用户明确确认
- `.ai/` 下是开发过程产物(方案/实现记录/评审记录),历史轮次文件只增不改
- 开发必须走 rawf 工作流(由 Claude Code 驱动,细则见 CLAUDE.md),
  不得绕过其闸门与产物约定
- 代码评审的角色约束、标准与严重度定义见 .ai-workflow/review-standards.md

## Git 提交规范

- 提交信息:`<type>: <一句话摘要>`,type 取 feat | fix | refactor | docs | test | chore
- 摘要用祈使句,简明扼要;正文(如有)说明动机与影响
- rawf 任务的提交在摘要后附 `(rawf: <yyyy-mm-dd>/<task-slug>)`
- 一次提交一个主题;代码与其决策痕迹(.ai/ 任务目录)同一提交
