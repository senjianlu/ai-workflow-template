# Plan 评审:第 03 轮

## 问题清单
- [plan-blocker] R-01 方案明确不更新 docs/decisions，和既有持久决策文档纪律冲突。
  - 详情:定位：plan.md:48-50 明确不动 docs，而 AGENTS.md 与 CLAUDE.md 要求任务改变架构或关键决策时在收尾前回写 docs/；docs/decisions/0005-review-readonly.md 当前仍把“全部测试用例统一走完整原始输出证据协议”作为决定与影响。本方案要把证据契约从一刀切改为 A/B/C 档，实质上是在修订 0005 的核心决定；若不新增/修订决策记录，持久真相会继续与 .ai-workflow/review-standards.md 冲突，后续评审者会读到两套互斥规则。修复建议：把 docs/decisions 纳入改动范围，新增一条取代/修订 0005 的决策记录，并按 docs/decisions/README.md 约定在旧决策顶部标注被取代或追加清晰沿革。

## 总评
方案主体与脚本/Hook 的运行机制基本自洽，测试表也覆盖了旧规则残留和若干边界路径。但它遗漏了对既有决策文档的必要回写，且现有 0005 会直接反驳本次证据档位制，因此实现前必须先修订方案。

VERDICT: fail
