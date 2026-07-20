# Plan 评审:第 02 轮

## 问题清单
- [major] R-01 反向测试没有覆盖当前实际存在的一刀切硬编码，可能让新旧证据规则并存仍通过自测。
  - 详情:定位: `.ai/2026-07-20/test-evidence-tiers/plan.md:112`、`:116`。方案要求 `review.md` 去掉一刀切表述，但 TC-09 只 grep `全部测试用例统一适用`；当前真正冲突的旧文案在 `.ai-workflow/prompts/review.md:12-16` 是“逐条审查 evidence 完整原始输出 / 缺失按 blocker”。同类旧硬规则还在 `.claude/skills/rawf-implement/SKILL.md:30-32` 的“所有测试用例的完整原始输出必须”。如果实现者只新增“按 plan 声明的档位”而未删除这些旧句，TC-05/TC-09 仍可能通过，但评审和实现 skill 会继续按 A 档要求处理所有用例，直接违背本方案目标。建议增加针对现有旧句的负向校验，至少覆盖 `review.md` 与 `rawf-implement/SKILL.md` 中不再出现未被 A 档限定的“完整原始输出/所有测试用例”要求。
- [major] R-02 TC-07 的步骤与预期互相矛盾，按原步骤无法验证 implement skill 的硬规则。
  - 详情:定位: `.ai/2026-07-20/test-evidence-tiers/plan.md:114`。该用例写的是“对三个 SKILL.md 取 frontmatter 前 4 行并 grep 新硬规则原文”，但 `不得下调`、`blocked`、`禁止虚构` 应出现在正文，不在 frontmatter 前 4 行；按这个步骤执行会误判失败，或被实现者改成非计划内命令。建议拆成两个断言: 一个只检查三个 skill 的 frontmatter/name 未变，另一个对完整 `.claude/skills/rawf-implement/SKILL.md` grep 新硬规则，且最好精确覆盖 `blocked 须停下问用户/不进入评审` 语义。

## 总评
方案主体方向与现有脚本、schema、hooks 没有架构级冲突；不改 scripts 的判断基本成立，因为证据协议主要由标准、prompt 和 skill 文档驱动。但测试计划对旧规则清理的覆盖不足，且有一条测试步骤本身不可执行，修订后再进入实现更稳妥。

VERDICT: fail
