---
task: review-product-gate
round: 01
date: 2026-11-24
---

# 实现记录:第 01 轮

## 本轮改动

已跟踪文件 26 个,新增 1 个(t0015),另有任务目录下的测试与统计资产。plan 估计为
26 个,实际多出的一个是把新增的 t0015 与六份旧决策分开计数。

| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/review-standards.md` | 重写:评审对象与核心问题、动作边界(含 plan 评审按需调查)、严重度与"建议"、实现评审的失败场景/路径归类/判定规则/分轮模式/测试缺口、plan 评审的可阻断类别/判定/分轮、范围核对、建议的标识与处置、证据(机器判定与自证的分界、档位、v1 格式、evidence-check 判定表、机械性更正) |
| `.ai-workflow/prompts/review.md` | 重写:只审产品缺陷;新增 `{{ROUND_CONTEXT}}`;不逐条核证据;测试缺口、建议、范围核对三个不计入结论的问题;不要求自报结论 |
| `.ai-workflow/prompts/plan-review.md` | 重写:只有设计错误可阻断(类别表);第 1 轮全量、调查按需;第 2 轮起核验;范围扩张只进范围核对 |
| `.ai-workflow/schemas/review.schema.json` | 去掉 `verdict`;issue 增 `file`、`line`、`scenario`;新增 `test_gaps`、`advisories` |
| `.ai-workflow/schemas/plan-review.schema.json` | 去掉 `verdict`;issue 增 `category`、`consequence`;新增 `advisories` |
| `.ai-workflow/scripts/review.sh` | 输入校验;路径归类与降级;结论由脚本推导;新渲染格式;每轮清单、内容快照与轮间差异;`{{ROUND_CONTEXT}}`;`__minors` 入口;去掉 evidence-check 退出码 2 的分支 |
| `.ai-workflow/scripts/plan-review.sh` | 默认上限 5 → 3;第 1 轮全量、第 2 轮起核验;输入校验;按类别与实现后果降级并推导结论;新渲染格式;`__minors` 并入建议、首列改为 `plan/NN/编号` |
| `.ai-workflow/scripts/evidence-check.sh` | 新增 `NO-FORMAT`、`DUP-ID`、`NOT-PASS`、`TC-MISMATCH`、`EXIT-NONZERO`、`NO-EVIDENCE`;B/C 档标记改为"采信";取消退出码 2 |
| `.ai-workflow/templates/plan.md` | 用例表注释:编号不得重复、A 档以 exit 0 表示通过、证据由机器核验 |
| `.ai-workflow/templates/implementation-round.md` | 交接节改名并说明新来源格式;新增「评审建议处置」表;测试结果注释同步新判定 |
| `.ai-workflow/templates/summary.md` | 遗留 minor 改为取自 `review.sh __minors`;新增「评审建议及处置」节 |
| `.claude/skills/rawf-plan/SKILL.md` | 证据契约(exit 0)、plan 评审 3 轮与分轮、建议不阻断 |
| `.claude/skills/rawf-implement/SKILL.md` | 修复轮处置建议;A 档留证规则;证据由机器核验、内容自证 |
| `.claude/skills/rawf-review/SKILL.md` | 结论由脚本推导;三节不计入分流及各自去处;"结构不合法"重跑一次;删除两条证据档位申诉条款 |
| `.claude/skills/rawf-report/SKILL.md` | 汇总改用 `review.sh __minors`;评审建议及处置只汇总不逐条征询 |
| `CLAUDE.md` | 第 1b 步轮次说明;新增"评审只拦产品缺陷与设计错误"硬规则;轮次默认值 3;证据一条补 exit 0 与机器核验 |
| `AGENTS.md` | plan-review 默认轮数 5 → 3 |
| `README.md` | 机制速览中 review.sh、证据、plan 评审三条重写,新增"修复轮只审修复""建议由开发 AI 处置";已知限制末条改写 |
| `docs/decisions/t0015-review-product-gate.md`(新增) | 本次决策:背景统计、五项决定、沿用边界、被否备选、影响与残留风险 |
| `docs/decisions/t0003`、`t0005`、`t0006`、`t0010`、`t0012` | 顶部加"已被 t0015 部分取代"标注并写明范围 |
| `docs/decisions/t0001` | 修订节追加 2026-11-24 条目 |
| `CHANGELOG.md` | `[1.5.0]` 条目(不兼容提示、Changed / Added / Removed、升级指引) |
| `.ai-workflow/TEMPLATE-VERSION` | 1.5.0 |
| `.ai/2026-11-24/review-product-gate/assets/tests/` | `run.sh`(10 条用例的断言)与 codex 桩 |
| `.ai/2026-11-24/review-product-gate/assets/analysis/` | 诊断用的五个统计脚本(plan 阶段已放入) |

## plan 评审 minor 与建议交接

来源取自 `plan-review.sh __minors`(本任务的 plan 评审文件由 1.4.1 脚本生成,没有
建议节,只有 minor)。

| 来源 | 内容 | 处置 |
|---|---|---|
| plan/01/R-08 | 建议引用缺少评审阶段,汇总时可能出现同名编号 | 已在 plan 修订中解决(引用格式改为"阶段/轮次/编号"),并已按此实现 |
| plan/01/R-09 | 证据报告的统一表述错误地涵盖了 B/C 档退出码 | 已在 plan 修订中解决(分档表述),并已按此实现 |
| plan/04/R-01 | 版本改为 1.5.0 后,旧评审格式仍被笼统称为"1.x 格式" | 已在 plan 修订中解决(改为"1.5.0 之前的旧格式") |

## 修复对照

无(第 1 轮)。

## 评审建议处置

无(第 1 轮)。

## 测试结果

留证命令统一在仓库根执行:
`bash .ai-workflow/scripts/evidence.sh TC-NN -- bash .ai/2026-11-24/review-product-gate/assets/tests/run.sh tcNN`。
各条的断言数:TC-01 43、TC-02 5、TC-03 36、TC-10 27、TC-04 76、TC-05 23、TC-06 29、
TC-07 88、TC-08 4、TC-09 24,均无失败。

| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01.log |
| TC-02 | A | pass | TC-02.log |
| TC-03 | A | pass | TC-03.log |
| TC-10 | A | pass | TC-10.log |
| TC-04 | A | pass | TC-04.log |
| TC-05 | A | pass | TC-05.log |
| TC-06 | A | pass | TC-06.log |
| TC-07 | A | pass | TC-07.log |
| TC-08 | A | pass | TC-08.log |
| TC-09 | A | pass | TC-09.log |

TC-08 用真实 codex(本机默认模型)各跑了一次实现评审与 plan 评审:两次都正常发布,
退出码均为 1。评审文件全文在 TC-08.log 中留档。

## 与方案的偏差

| 编号 | 类型 | 内容 | 原因 | 处置 |
|---|---|---|---|---|
| D-01 | 收窄 | review-standards.md「技术栈评审关注点」删去三条针对测试的条目:Scrapy 的"解析测试依赖真网"、Workers 的"单元测试访问真网"、通用的"只测 happy path 即 major" | 测试方面的意见不再阻断;留着会引导评审者把测试问题列进 `issues`,随后被脚本降级,白费一轮注意力 | 已实现,属于 plan「重写评审标准」范围内 |
| D-02 | 替代 | 修复核验轮内联进指令的变化文件列表,超过 200 项时只列前 200 项并注明总数;完整列表在轮间差异文件的「变化文件」节 | plan 已指出指令经命令行参数传入、长度有上限,但只对 diff 做了"不内联"处理;文件列表同样可能过长 | 已实现 |
| D-03 | 替代 | "未快照"的条件在"超过 1 MiB 或不可读"之外多一项:路径含制表符或换行的文件 | 清单是按制表符分列的文本文件,这类路径无法无歧义地写入;按未快照处理时该文件整份视为本轮变化,不会漏审 | 已实现 |
| D-04 | 替代 | 轮间差异里"清单没有它而 HEAD 中有"的一侧,按 HEAD 中的类型取:普通文件取内容,符号链接取链接目标(列为元数据变化) | plan 的取法表只写了"HEAD 中的版本";对符号链接取"内容"没有意义 | 已实现,TC-03 的符号链接一项覆盖 |
| D-05 | 替代 | B/C 档"证据栏为空"的判定,把只有空白或占位横线(`-`、`—`)的证据栏也算作空 | 记录里常用横线表示"无",按字面非空放行会让 `NO-EVIDENCE` 形同虚设 | 已实现 |
| D-06 | 替代 | 测试缺口超过 3 条时,渲染里同样注明超出的条数 | plan 只对"建议"写了"超出部分只注明条数";测试缺口被截断时不注明会让人误以为只有 3 条 | 已实现 |

没有追加类偏差。

## 停车场

- README「版本与升级」的分级规则把"评审 schema / 产物格式不兼容"列为 MAJOR,本次
  按用户裁定以 1.5.0 发布。是否修订分级规则或写明例外,留给用户决定。
- 评审模型没有工作流内的指定入口:本次 plan 评审按用户指示改用 gpt-6-astra,靠任务
  之外的一次性包装命令传参实现(plan 非目标已排除"把评审模型做成配置项")。
- consumer 仓库升级到 1.5.0 时须逐仓检查 review.sh 的两份路径清单(例如文档站内容
  目录是否该算产品路径)。本仓不改其它仓库,已写入 CHANGELOG 升级指引。
- `assets/analysis/` 的统计脚本可在 consumer 升级运行一段时间后复跑,核对"只因测试
  而 fail 的轮次占比""不改产品代码的修复轮占比"是否下降。
