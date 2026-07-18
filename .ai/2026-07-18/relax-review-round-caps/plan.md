---
status: approved
task: relax-review-round-caps
date: 2026-07-18
approved_at: 2026-07-18 15:11
---

# 方案:评审轮数上限可由用户放宽

## 背景与目标

当前工作流对两类自动评审都设了固定 3 轮上限(plan 评审曾为 2 轮,
2026-07-11 放宽到 3 轮):

- **plan 阶段评审**:`plan-review.sh` 硬编码 `count >= 3` 即拒绝(脚本
  71-79 行),另散落于 CLAUDE.md、AGENTS.md、rawf-plan skill、
  docs/decisions/0001。
- **实现修复轮**:纯文字约束——rawf-implement(NN > 3 停)、rawf-review
  (fail 且 NN = 3 停)、CLAUDE.md;review.sh 本身不设上限。

目标:把两处上限从"固定值"改为"**默认值**"——用户没有特殊要求时仍
按 3 轮;用户明确指定更多轮数时,以用户指定值为准。上限的存在意义
(防自动评审空转、兜底转人工)不变,只是把放宽的决定权交给用户。

## 改动范围

机制:在任务的 plan.md frontmatter 增加两个**可选**字段,仅在用户明确
提出时写入,作为用户授权的持久痕迹(随任务目录入库,可审计):

```yaml
plan_review_max_rounds: 5   # 可选,缺省 = 3
impl_fix_max_rounds: 6      # 可选,缺省 = 3
```

选择 frontmatter 而非环境变量/脚本参数的理由:脚本与各 skill 本就读
plan.md;授权留痕在任务目录内,而环境变量无痕、易被顺手设置绕过约束。

涉及文件(9 个):

| 文件 | 改动 |
|---|---|
| `.ai-workflow/scripts/plan-review.sh` | 上限从字面量 3 改为读 plan.md frontmatter 的 `plan_review_max_rounds`(缺省 3);解析封装为函数并加 `__resolve_max_rounds` 测试入口(仿现有 `__publish_round` 模式);非法值(非正整数)exit 3 |
| `.claude/skills/rawf-plan/SKILL.md` | 步骤 6:"最多 3 轮"改为"默认最多 3 轮,用户明确要求放宽时在 plan.md frontmatter 记 `plan_review_max_rounds` 并在方案摘要中声明";补充:该字段只能由用户明确提出后写入 |
| `.claude/skills/rawf-implement/SKILL.md` | 前置检查:"NN > 3 停"改为"NN > 上限停";上限取 plan.md frontmatter 的 `impl_fix_max_rounds`,字段缺失或非正整数一律按缺省 3 |
| `.claude/skills/rawf-review/SKILL.md` | 分流:"NN < 3 / NN = 3"改为与上限比较(上限取值规则同 rawf-implement,含缺省/非法回退);补充:用户中途要求追加轮数时,更新 frontmatter 字段并在下一轮实现记录中注明 |
| `CLAUDE.md` | 工作流第 1b、5 步及硬规则中"最多 3 轮"统一改为"默认 3 轮,用户明确指定时以其为准(记录于 plan.md frontmatter)" |
| `AGENTS.md` | 通用硬规则同步改为"默认最多 3 轮" |
| `README.md` | 第 21 行"修复轮(最多 3 轮…)"同步改为默认语义 |
| `docs/decisions/0001-plan-stage-review.md` | 追加沿革条目:2026-07-18 上限改为可配置默认值 |
| `docs/decisions/0003-configurable-review-round-caps.md` | 新增决策记录(0002 已被 task-evidence-assets-dirs 占用,按 README 递增取 0003):机制、字段定义、"仅用户明确要求可放宽"约束 |

明确不动:`review.sh`(本就不设上限)、`.ai-workflow/templates/plan.md`
(字段可选,不进模板,避免默认路径噪音;字段说明落在 0002 决策与 skill)。

## 实现方案

1. **plan-review.sh**:新增 `resolve_max_rounds <plan.md>` 函数——从
   frontmatter(首个 `---` 块内)grep `plan_review_max_rounds:`;无该行
   → 输出 3;有则校验为正整数(`^[1-9][0-9]*$`),非法 → stderr 报错并
   返回 3。主流程用其返回值替换字面量 3,拒绝提示同步显示实际上限值。
   顶部注释与 `__resolve_max_rounds` 测试入口同步更新。
2. **三个 skill + CLAUDE.md + AGENTS.md**:上述表格所列措辞修改,统一
   口径:"默认 3 轮;用户明确指定更宽轮数时以 plan.md frontmatter 记录值
   为准;达上限仍不决 → 停下交人工"。并明确两条防滥用约束:
   - 字段**只能**在用户明确提出后写入/修改,写入后须在面向用户的摘要或
     实现记录中声明;
   - AI 不得以"预计轮次不够"为由自行建议性写入。
3. **docs 回写**:0001 追加沿革;新增 0003 记录本决策(动机、机制选型、
   被否方案:环境变量/脚本参数),标题用 `# 0003:`。

## 测试用例

| 编号 | 前置条件 | 步骤 | 预期结果 |
|---|---|---|---|
| TC-01 | 临时任务目录含 plan.md(无新字段) | `bash plan-review.sh __resolve_max_rounds <plan.md>` | 输出 `3`,exit 0 |
| TC-02 | plan.md frontmatter 含 `plan_review_max_rounds: 5` | 同上 | 输出 `5`,exit 0 |
| TC-03(异常) | plan.md 含 `plan_review_max_rounds: 0`(及 `abc` 各测一次) | 同上 | stderr 报非法值,exit 3 |
| TC-04(边界) | frontmatter 无字段,但正文含字符串 `plan_review_max_rounds: 9` | 同上 | 仍输出 `3`(只认 frontmatter 块) |
| TC-05 | 临时任务目录造 3 个 `plan-review-round-*.md`,plan.md 无字段,`.ai/.current-task` 指向该目录 | 运行 `plan-review.sh`(可用 PATH 假 codex 兜底,预期不会走到 codex) | stderr 报"已达 3 轮上限",exit 3 |
| TC-06 | 同 TC-05 但 plan.md 含 `plan_review_max_rounds: 5`,PATH 前置假 codex(直接 exit 1) | 运行 `plan-review.sh` | 通过轮次闸(不再报上限),在 codex 阶段报"执行失败",exit 3——证明上限已放宽 |
| TC-07 | 改动完成后的仓库 | `bash -n plan-review.sh`;对全仓(排除 `.ai/`、`.git/`)grep "最多 3 轮/三轮/NN = 3/NN > 3" 等固定上限表述 | 语法通过;除 docs/decisions 沿革记述外,所有现行工作流文档(含 README.md)均无无条件固定上限表述,残留为零 |
| TC-08(静态断言) | 改动完成后的 rawf-implement / rawf-review SKILL.md | grep 校验两个 skill 均明确:上限取 plan.md frontmatter 的 `impl_fix_max_rounds`;缺失或非法时取缺省 3;达上限的停止动作(停止实现 / 交人工) | 三项断言在两个 skill 中均命中 |
| TC-09(场景走查) | 上述 skill 文本 | 按场景表逐条对照 skill 分流规则并记录到 evidence/:(a) 无字段,NN=3 fail → 停;(b) `impl_fix_max_rounds: 5`,NN=3、4 fail → 继续修复;(c) 同 (b),NN=5 fail → 停;(d) 字段为 `0`/`abc`,任意 NN → 按缺省 3 分流;(e) rawf-implement 前置检查在 NN > 上限时拒绝开轮 | 每一场景都能从 skill 文本唯一推导出预期分支,无歧义、无遗漏;走查记录落 evidence/ |

TC-05/06 在 `.ai/` 任务目录外的临时目录(scratchpad)造数据,不污染真实
任务痕迹;测试证据落本任务 `evidence/`。实现修复轮上限维持纯文字约束
(与现状一致,不改 review.sh),故 TC-08/09 以静态断言 + 场景走查作为
可复核验证,而非仅检查旧措辞消失。

## 风险与回滚

- **frontmatter 解析健壮性**:bash grep 解析 YAML 属于弱解析,已限定
  "首个 `---` 块内、行首字段名"降低误匹配;TC-03/04 覆盖。
- **防滥用**:字段写入无技术闸,仅靠 skill 文字约束 + 摘要声明留痕;
  与现有工作流其余文字约束同一信任层级,可接受。
- **实现修复轮上限仍是纯文字约束**:与现状一致,本次不新增技术强制。
- 回滚:单提交改动,`git revert` 即可;plan.md 新字段对旧脚本无害
  (旧脚本不读它)。
