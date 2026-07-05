# 项目

<!-- TEMPLATE: 一两句话描述本项目。 -->

## 技术栈

<!-- TEMPLATE: 保留适用的行,删除其余。 -->
- 前端:Node.js + TypeScript + Next.js + shadcn/ui
- 后端:Python 3 + FastAPI
- 爬虫:Python 3 + Scrapy
- 部署:GitHub Actions(.github/workflows/)

## 开发工作流(强制)

所有非琐碎改动必须走此流程,产物写入 `.ai/<yyyy-mm-dd>/<task-slug>/`:

1. `/rawf-plan` → 产出 plan.md(必须含测试用例),向用户呈现摘要
2. 【人工闸】用户确认 plan 前,禁止改动源码(有 hook 拦截)
3. `/rawf-implement` → 实现 + 自测,写 implementation-round-<NN>.md
4. `/rawf-review` → 跑 Codex 评审,产出 review-round-<NN>-<pass|fail>.md
5. fail → 按 rawf-review skill 的分流规则处理,实现层修复最多 3 轮
6. 汇报结果;提交前必须获得用户确认

例外:纯文档、拼写级改动可跳过流程,但需先向用户声明。

## 硬规则

- 永不主动 git commit / git push,必须用户明确确认
- `.ai/` 下的历史轮次文件只增不改
- 评审只能通过 `.ai-workflow/scripts/review.sh` 触发,不得自行替代
- 开新任务前先检查 `.ai/` 下是否有同日同名任务目录,避免覆盖
