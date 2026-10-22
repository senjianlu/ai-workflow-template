## [1.2.0] - 2026-10-22

### Added

- plan 评审分轮模式:第 1、2 轮全量穷尽评审(五个固定维度、一次列全、含
  minor,`overall` 逐维度一句结论),第 3 轮起收敛评审(先核上一轮
  plan-blocker/major,修订部分完整评审,未修订部分只报 plan-blocker)。
- plan-review.sh 每轮把 plan.md 快照为 `.plan-review-raw-NN.plan.md`,把模式行、
  上一轮评审文件与两轮快照间的修订 diff 注入 prompt 新占位 `{{ROUND_CONTEXT}}`;
  评审结束后核对 plan.md 与快照一致,不一致则本轮作废(exit 3,不发布、不消耗
  轮次)。注入前关闭 bash 5.2 默认开启的 `patsub_replacement`,diff 中的 `&`
  不会被改写。
- plan-review.sh 只读入口 `__minors <任务目录>`:汇总全部轮次的 minor;实现记录
  模板新增「plan 评审 minor 交接」节。
- review-standards.md:plan 阶段返工判据、分轮模式、实现层"机械性更正"条款。
- 决策记录 docs/decisions/0012。

### Changed

- plan 评审默认上限 3 → 5 轮(实现层修复默认 3 轮不变)。
- prompts/plan-review.md 按分轮模式与返工判据重写。
- rawf-plan:plan 写作粒度、修订纪律、评审运行期间不得修改 plan.md、默认 5 轮。
- rawf-implement:第 1 轮前经 `__minors` 做跨轮 minor 交接;机械性更正须回写
  plan 测试表并记"替代"偏差。
- CLAUDE.md、AGENTS.md:plan 评审默认 5 轮。

### 升级指引

- 可整体替换:`.ai-workflow/`(scripts、prompts、templates、review-standards.md——
  consumer 若在 review-standards.md 有项目自改小节,先摘出再覆盖)、
  `.claude/skills/rawf-*`。
- 需人工合并:`CLAUDE.md`(第 1b 步与轮次上限硬规则)、`AGENTS.md`(通用硬规则
  中的 plan 评审默认轮数)、`README.md`(机制速览)。
- 进行中的任务:plan 评审已跑过的轮次没有快照,第 3 轮起走全量回退分支,行为
  不劣于 1.1.0;frontmatter 已写 `plan_review_max_rounds` 的以其为准。
- `.gitignore`、hooks 与 settings.json 未变。

