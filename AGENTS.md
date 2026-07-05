# 项目说明

<!-- TEMPLATE: 一两句话描述本项目。 -->

本文件面向进入本仓库的任何 AI 编码工具(AGENTS.md 开放标准),只描述
项目事实与通用约束,不为任何工具指派角色。

## 技术栈

<!-- TEMPLATE: 保留适用的行,删除其余。 -->
- 前端:Node.js + TypeScript + Next.js + shadcn/ui
- 后端:Python 3 + FastAPI
- 爬虫:Python 3 + Scrapy
- 部署:GitHub Actions(.github/workflows/)

## 通用硬规则(对任何 AI 工具生效)

- 永不主动 git commit / git push,必须用户明确确认
- `.ai/` 下是开发过程产物(方案/实现记录/评审记录),历史轮次文件只增不改
- 开发必须走 rawf 工作流(由 Claude Code 驱动,细则见 CLAUDE.md),
  不得绕过其闸门与产物约定
- 代码评审的角色约束、标准与严重度定义见 .ai-workflow/review-standards.md
