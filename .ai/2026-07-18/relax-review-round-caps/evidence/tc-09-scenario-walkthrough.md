# TC-09:实现修复轮上限分流场景走查

依据文本:改动后的 `.claude/skills/rawf-implement/SKILL.md`(前置检查第 2 条)
与 `.claude/skills/rawf-review/SKILL.md`(分流第 2 条)。

取值规则(两个 skill 一致):上限 = plan.md frontmatter 的
`impl_fix_max_rounds`;字段缺失或非正整数一律按默认 3。

| 场景 | 条件 | 依据的分流规则 | 推导结果 | 唯一无歧义 |
|---|---|---|---|---|
| (a) | 无字段,review NN=3 fail | 上限=3(缺失→默认);rawf-review "fail 且 NN ≥ 上限 → 停止修复" | 3 ≥ 3 → 停止修复,交人工 | ✓ |
| (b) | `impl_fix_max_rounds: 5`,NN=3 fail | 上限=5;"fail 且 NN < 上限 → 进入修复轮" | 3 < 5 → 继续修复;NN=4 fail 同理(4 < 5)继续 | ✓ |
| (c) | 同 (b),NN=5 fail | "fail 且 NN ≥ 上限 → 停止修复" | 5 ≥ 5 → 停止修复,交人工 | ✓ |
| (d) | 字段为 `0` 或 `abc`,任意 NN | "字段缺失或非正整数一律按默认 3" | 按上限 3 分流:NN=2 fail 继续,NN=3 fail 停止 | ✓ |
| (e) | 上限 3(缺省),已有 3 个 implementation-round-*.md,评审要求再修 | rawf-implement 前置检查:"NN = 已有数量 + 1 = 4;若 NN > 上限:停止实现" | 4 > 3 → 拒绝开轮,交人工 | ✓ |

结论:5 个场景均能从 skill 文本唯一推导出预期分支,无歧义、无遗漏分支
(fail 的 NN < 上限 / NN ≥ 上限、pass、plan-blocker 各有明确去向;
字段缺失与非法共用同一回退)。

另核对两处防滥用约束均已落文本:
- rawf-implement:"该字段仅当用户明确要求放宽时写入,不得自行添加"
- rawf-review:"用户中途明确要求追加修复轮数时,更新 plan.md 的
  `impl_fix_max_rounds` 并在下一轮实现记录中注明;不得未经用户提出而
  自行修改该字段"
