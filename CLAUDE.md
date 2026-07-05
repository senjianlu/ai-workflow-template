@AGENTS.md

# Claude Code 工作流

## 开发工作流(强制)

所有非琐碎改动必须走此流程,产物写入 `.ai/<yyyy-mm-dd>/<task-slug>/`:

1. `/rawf-plan` → 产出 plan.md(必须含测试用例),向用户呈现摘要
2. 【人工闸】用户确认 plan 前,禁止改动源码(有 hook 拦截)
3. `/rawf-implement` → 实现 + 自测,写 implementation-round-<NN>.md
4. `/rawf-review` → 跑 Codex 评审,产出 review-round-<NN>-<pass|fail>.md
5. fail → 按 rawf-review skill 的分流规则处理,实现层修复最多 3 轮
6. `/rawf-report` → 汇报;提交须用户确认

例外:纯文档、拼写级改动可跳过流程,但需先向用户声明。

## 硬规则(通用硬规则见 AGENTS.md,以下为 Claude Code 补充)

- 评审只能通过 `.ai-workflow/scripts/review.sh` 触发,不得自行替代
- 开新任务前先检查 `.ai/` 下是否有同日同名任务目录,避免覆盖
- 禁止用 Bash 重定向、临时脚本等方式绕过 gate-plan 对源码与工作流
  控制文件的写入闸
- 任务改变架构或关键决策时,收尾(/rawf-report)前把变化回写 docs/
  (architecture.md 或 decisions/),与代码同一提交
