# Plan 评审:第 01 轮

## 问题清单
- [major] R-01 TC-07 把评审轮次产物作为实现阶段自测用例,与现有 rawf 时序冲突。
  - 详情:plan.md「测试用例」TC-07 要求前置条件为“本任务自身走完 /rawf-review 一轮”,并以 review-round-01 产物证明新规则在评审端生效。但 CLAUDE.md 规定流程是 /rawf-implement 先实现、自测并写 implementation-round-<NN>.md,随后才 /rawf-review 产出 review-round-<NN>-*.md；.claude/hooks/gate-review.sh 也在存在 implementation-round 且无对应 review-round 时阻止结束。也就是说 TC-07 在实现记录阶段无法执行和留证,若按 plan 执行会只能标 blocked 并停下,不能进入评审,形成流程死锁。修复建议:不要把“本轮 review-round 是否误判”列为实现阶段测试用例；改为对 prompt/review-standards 的静态断言,或新增脚本/fixture 级可自动化检查来覆盖 C 档核验语义。
- [major] R-02 测试计划未真实覆盖 B 档核验语义,会让核心验收只停留在文本存在检查。
  - 详情:plan.md 的目标包含 A/B/C 三档分类核验,且实现方案明确 B 档应核验“文件:行号”或日志片段是否真实存在、是否支持结论。但测试用例 TC-01 至 TC-06 全是 grep 文本命中,TC-07 只观察 C 档误判；没有任何用例验证 B 档引用必须带行号、引用不存在应判问题、引用存在但不支持结论应判 major 等边界路径。按本次评审硬约束,测试只覆盖 happy path 或漏掉异常/边界路径属于 major。修复建议:补充针对 B 档的可自动化/静态验证用例,至少覆盖模板中 B 档字段要求、review-standards 中 B 档失败分支,以及 plan-review prompt 对 B 档声明质量的检查。

## 总评
方案的方向与“证据契约前移”目标基本一致,但当前测试设计有一个 rawf 时序死锁,且遗漏了 B 档这一核心分支的异常/边界覆盖。上述问题会在实现后直接返工,因此本轮 plan-review 判 fail。

VERDICT: fail
