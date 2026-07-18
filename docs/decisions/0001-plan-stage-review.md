# 0001:>10 文件的改动在方案确认前先经 Codex plan 阶段评审

- 日期:2026-07-07
- 背景:plan-blocker(方案/架构层面错误)原先只在**实现层评审**(review.sh)
  才被发现,此时实现已完成,退回方案重做代价高。需要把方案缺陷的检测左移。
- 决定:新增 plan 阶段评审(`.ai-workflow/scripts/plan-review.sh`),对预计触及
  文件 **> 10** 的改动,在"方案确认闸【人工】"之前先由 Codex 只读审查 plan.md,
  plan-blocker/major 就地修订 plan 后重评,脚本强制**最多 3 轮**,不决转人工。
  - 判定语义与实现层评审分域:plan 阶段 plan-blocker 与 major 均计入 fail
    (实现层评审中 plan-blocker 不计入 pass/fail),见 review-standards.md。
  - **被否掉的备选:用 hook 强制拦截"未过 plan 评审就批准"**。因 plan 阶段的
    文件数只是估计值、机器无法可靠核验,强制拦截会误伤且新增失败面;改为靠
    skill 纪律 + CLAUDE.md 硬规则触发。残留风险(AI 低估文件数漏触发)由
    rawf-implement"实际偏差需停下问用户"兜底。
- 影响:
  - >10 文件的任务在确认闸前多一道 plan 评审;≤10 不受影响。
  - 触发靠估计文件数,非机器强制;后续若要根治漏触发,需引入可核验的文件数
    契约(如 plan frontmatter 字段 + hook),届时新增决策记录取代本条。
  - 另注(非本决策):review.sh 评审整个工作区 diff,无关的未提交改动会污染
    任务评审;本任务靠"先提交无关改动"规避,根治可另开任务。

## 修订

- 2026-07-11:轮次上限由 **2 轮**放宽到 **3 轮**(`plan-review.sh` 的
  `count -ge 3`)。动机:2 轮对 plan 层面的分歧偏紧,常在第 2 轮仍差一步收敛
  即被迫转人工;放到 3 轮给自动收敛多一次机会,达上限转人工的兜底不变。
  见 `.ai/2026-07-11/task-subdirs-3rounds/`。
- 2026-07-18:固定上限改为**可配置默认值**——默认仍 3 轮,用户明确要求时
  可经 plan.md frontmatter 的 `plan_review_max_rounds` 放宽,机制见
  [0003](0003-configurable-review-round-caps.md)。
