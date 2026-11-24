---
task: review-model-override
date: 2026-11-24
rounds: 1
verdict: pass
---

# 任务小结:评审模型的指定入口,版本分级规则补"维护者裁量"

## 改动

| 文件 | 摘要 |
|---|---|
| `.ai-workflow/scripts/plan-review.sh` | 读 plan.md frontmatter 的 `plan_review_model` / `plan_review_effort`,转成 `codex exec` 的 `-m` 与 `-c model_reasoning_effort`;形态不对时 exit 3、不消耗轮次 |
| `.ai-workflow/scripts/review.sh` | 同上,读 `impl_review_model` / `impl_review_effort` |
| `CLAUDE.md` | 硬规则新增一条:评审模型缺省用 Codex 默认配置,仅用户点名时写字段 |
| `.claude/skills/rawf-plan/SKILL.md`、`.claude/skills/rawf-review/SKILL.md` | 各补本阶段两个字段的写入条件与出错处置 |
| `README.md` | 「机制速览」新增评审模型一条;「版本与升级」分级表下新增"维护者裁量"一段 |
| `docs/decisions/t0016-review-model-override.md` | 新增决策记录 |
| `docs/decisions/t0008-template-versioning.md` | 顶部补注:分级规则增加维护者裁量条款 |
| `CHANGELOG.md`、`.ai-workflow/TEMPLATE-VERSION` | 1.6.0 条目与升级指引;版本号 |
| `.ai/2026-11-24/review-model-override/assets/tests/` | 8 条用例的断言脚本与记录 codex 启动参数的桩包装 |

## 评审历程

plan 评审与实现评审都用 Codex 默认模型(本任务没有用户点名的模型)。

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| plan 01 | pass | 问题清单与建议均为空;「范围核对」2 条交用户裁决 |
| impl 01 | pass | 问题清单、测试缺口、建议、范围核对均为空 |

## 范围核对

交付与「需求原文」一致:停车场第一拨剩下的两条——评审模型的指定入口、README 版本
分级规则的措辞。第二拨(各消费仓库检查路径清单)不在本仓库,按用户指示不做。

- **追加类偏差**:无。
- **其余偏差**(D-01、D-02,均为替代):review.sh 的解析放在证据核验通过之后;
  "字段写在正文里不生效"对两个脚本各验了一次。
- **plan 评审「范围核对」节的条目及用户裁决**(2026-11-24 确认闸):
  - 新增两个推理强度字段及"只指定强度"的能力,超出需求原文明确提出的模型指定
    入口 —— 用户裁定保留。
  - 1.6.0 发版准备未被需求原文明确要求 —— 用户裁定按 1.6.0 发布。
  - 其余 3 条(配套规则与决策文档服务于核心交付;先提交上一任务以隔离评审范围;
    非目标未进入实施范围)无需裁决。
- **实现评审「范围核对」节**:无。
- **停车场条目**(见实现记录):评审文件不记录所用模型;两个脚本各有一份相同的
  解析函数;上一任务留下的 4 项不变。去向待用户决定。

## 遗留 minor 及处置

取自 `review.sh __minors`:无。plan 评审也没有 minor。

## 评审建议及处置

取自 `review.sh __minors`:无(实现评审没有测试缺口与建议;plan 评审没有建议)。
