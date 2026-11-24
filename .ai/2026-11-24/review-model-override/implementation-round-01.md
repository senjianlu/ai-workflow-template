---
task: review-model-override
round: 01
date: 2026-11-24
---

# 实现记录:第 01 轮

基线:上一任务 `snapshot-excludes-prompt-limit` 已按用户确认以 1.5.1 提交(`7df8371`),
本轮改动都在该提交之上。本任务没有用户点名的评审模型,plan.md 未写任何模型字段,
plan 评审与实现评审都用 Codex 默认模型。

## 本轮改动

10 个产品文件,与 plan 的范围一致。

| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/plan-review.sh` | 新增 `frontmatter_field` 与 `resolve_model_args`;解析轮次上限之后、生成本轮产物之前读 `plan_review_model` / `plan_review_effort`,形态不对 exit 3;启动 codex 时把 `-m <值>`、`-c model_reasoning_effort="<值>"` 放在 `exec` 之后;有字段生效时向 stderr 打印一行;文件头补说明 |
| `.ai-workflow/scripts/review.sh` | 同上,读 `impl_review_model` / `impl_review_effort`;解析放在证据核验通过之后、生成本轮产物之前 |
| `CLAUDE.md` | 「硬规则」在轮次上限一条之后新增"评审模型缺省用 Codex 默认配置"一条 |
| `.claude/skills/rawf-plan/SKILL.md` | 第 6 步补 `plan_review_*` 两个字段的写入条件与出错时的处置 |
| `.claude/skills/rawf-review/SKILL.md` | 第 1 步补 `impl_review_*` 两个字段的写入条件与出错时的处置 |
| `README.md` | 「机制速览」新增评审模型一条;「版本与升级」分级表下新增"维护者裁量"一段(措辞与用户确认的一致,仅按行宽折行) |
| `docs/decisions/t0016-review-model-override.md` | 新增决策记录 |
| `docs/decisions/t0008-template-versioning.md` | 顶部补注:分级规则增加维护者裁量条款,先例 1.5.0 |
| `CHANGELOG.md` | `[1.6.0]` 条目:Added、Changed、升级指引 |
| `.ai-workflow/TEMPLATE-VERSION` | 1.6.0 |
| `.ai/2026-11-24/review-model-override/assets/tests/` | `run.sh`(8 条用例)与记录 codex 启动参数的桩包装 `stub-codex-bin/codex`(非产品文件) |

## plan 评审 minor 与建议交接

`plan-review.sh __minors` 输出"无":plan 评审一轮通过,没有 minor、建议或降级条目。

| 来源 | 内容 | 处置 |
|---|---|---|
| 无 | - | - |

plan 评审「范围核对」节要求用户裁决的两条,已在确认闸裁定:保留推理强度两个字段;
按 1.6.0 发布。

## 修复对照

无(第 1 轮)。

## 评审建议处置

无(第 1 轮)。

## 测试结果

留证命令在仓库根执行:
`bash .ai-workflow/scripts/evidence.sh TC-NN -- bash .ai/2026-11-24/review-model-override/assets/tests/run.sh tcNN`。
断言数:TC-01 12、TC-02 16、TC-03 16、TC-04 62、TC-05 12、TC-06 4、TC-07 16、TC-08 19,
均无失败。

| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01.log |
| TC-02 | A | pass | TC-02.log |
| TC-03 | A | pass | TC-03.log |
| TC-04 | A | pass | TC-04.log |
| TC-05 | A | pass | TC-05.log |
| TC-06 | A | pass | TC-06.log |
| TC-07 | A | pass | TC-07.log |
| TC-08 | A | pass | TC-08.log |

- TC-01 用 `cmp` 把桩记录的参数序列与固定序列逐项比对,两个脚本的默认路径都没有变化。
- TC-06 调用的是本机真实的 codex(默认模型 + `reasoning effort: low`),一句话指令,
  在项目外的空目录执行;日志里只有断言结果,不含 codex 的原始输出。
- TC-07 跑了 1.5.0 任务套件的 tc03、tc06、tc10 与 1.5.1 任务套件的 tc01、tc02、tc03、
  tc06,全部 exit 0。

## 与方案的偏差

| 编号 | 类型 | 内容 | 原因 | 处置 |
|---|---|---|---|---|
| D-01 | 替代 | review.sh 的解析时机定在"证据核验通过之后",plan 写的是"定位任务目录之后" | 证据核验先确认 plan.md 存在且可解析,解析函数不必另外处理 plan.md 缺失;两者都在生成本轮产物与启动 codex 之前,都不消耗轮次 | 已实现 |
| D-02 | 替代 | TC-03 的第三种情形(字段写在正文里)对两个脚本各验了一次,plan 写的是一个夹具 | 两个脚本各有一份解析函数,只验一个不能说明另一个 | 已实现 |

没有追加类偏差。

## 停车场

- 评审文件不记录本轮所用的模型(plan 非目标):事后追溯靠 plan.md frontmatter 与
  摘要、实现记录里的声明。
- 两个脚本各有一份相同的 `frontmatter_field` / `resolve_model_args`(与
  `inline_budget` 等既有的重复做法一致);是否抽成公共文件留待以后。
- 上一任务留下的事项不变:2 条测试缺口的回归断言、口径摘要不覆盖外部规则文件、
  plan-review.sh 没有退出码总闸、review.sh 文件头未列出 `comm`。
