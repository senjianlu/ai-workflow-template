# Plan 评审:第 02 轮

## 问题清单
- [major] R-01 改动范围遗漏 README.md，实施后仓库仍会保留固定“三轮上限”的冲突说明
  - 详情:README.md:21 仍写有“修复轮（最多 3 轮）”，但方案的涉及文件和 TC-07 均未覆盖 README.md。实施后顶层工作流说明会与 CLAUDE.md、AGENTS.md 和 rawf skills 的可配置语义冲突。应将 README.md 纳入改动范围，并把 TC-07 改为覆盖全部现行工作流文档的仓库级残留检查（排除 .ai/ 历史产物）。
- [major] R-02 测试只真实验证了 plan 评审上限，未覆盖实现修复轮上限这一半验收目标
  - 详情:TC-01～TC-06 均针对 plan-review.sh；TC-07 只检查若干文档不再出现无条件“最多 3 轮”，无法证明 rawf-implement/rawf-review 在缺省值和自定义值下做出正确分流。应至少覆盖：缺省上限时 NN=3 停止；配置为 5 时 NN=3/4 继续、NN=5 停止；rawf-implement 在下一轮超过上限时拒绝；以及缺失或非法 impl_fix_max_rounds 的处理。若实现修复轮继续采用纯文字约束，也应设计可复核的静态断言或场景化验证，明确检查这些分支，而非仅检查旧措辞消失。

## 总评
方案的 frontmatter 机制与现有 rawf 状态载体总体兼容，但改动范围留下了面向用户的冲突文档，且测试没有覆盖第二类上限的核心分流行为。存在 major，按 plan-review 判定规则应 fail，修订方案后重评。

VERDICT: fail
