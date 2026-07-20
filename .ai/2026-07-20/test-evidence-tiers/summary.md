---
task: test-evidence-tiers
date: 2026-07-20
rounds: 1
verdict: pass
---

# 任务小结:测试证据契约改为 A/B/C 档位制

## 背景

原证据协议「全部测试用例统一」要求完整原始输出,而 plan 的测试用例表不声明
「这条怎么验、留什么证据」。证据契约缺位,评审端只能对全部用例统一套用最严
标准——人工交互类用例(视觉、剪贴板、系统弹窗)只能交截图或手工汇总,必然被
判证据缺失而 blocker 打回,且截图在只读沙箱中评审者无法读取。本任务把证据
契约前移到 plan 阶段,按档位分类核验。

## 改动

| 文件 | 摘要 |
|---|---|
| `.ai-workflow/review-standards.md` | 删去「全部测试用例统一适用」的证据协议,新增「测试证据档位」章节:A/B/C 三档定义、四条约束(A 档强制不得降档、C 档 ≤1/3 且须写理由、截图不得为唯一证据、未声明档位回退 A 档)与逐档核验规则 |
| `.ai-workflow/prompts/review.md` | 证据核验改为按 plan 声明的档位逐条进行;删去无档位限定的「证据缺失即 blocker」表述 |
| `.ai-workflow/prompts/plan-review.md` | 新增证据契约检查点(未逐条声明档位 / 可自动化项塞进 C 档 / C 档超限或缺理由,均 major) |
| `.ai-workflow/templates/plan.md` | 测试用例表增「档位」「证据形态」两列 + 填写说明 |
| `.ai-workflow/templates/implementation-round.md` | 测试结果表增「档位」列,明确 `blocked` 取值与语义 |
| `.claude/skills/rawf-plan/SKILL.md` | 第 5 步增证据契约硬要求:逐条声明档位、A 档不得降档、C 档 ≤1/3 且须写理由 |
| `.claude/skills/rawf-implement/SKILL.md` | 按档位留证据;新增硬规则:不得下调档位或改写用例重要性、无法执行记 `blocked` 并停下问用户、禁止虚构结果、有 blocked 不进评审 |
| `.claude/skills/rawf-review/SKILL.md` | 分流前按档位核对;仅因无原始输出打回 C 档属可申诉误报 |
| `docs/decisions/0006-test-evidence-tiers.md` | 新增 ADR,记录档位制决策与被否掉的比例配额制备选 |
| `docs/decisions/0005-review-readonly.md` | 仅顶部加部分取代标注,正文保留历史原貌 |

核心规则:

- **A 档**(可由非交互命令判定)= 命令 + 完整原始输出 + 退出码,**强制、不得降档**
- **B 档**(静态可确证)= 日志片段或代码引用,**须带 `文件:行号`**
- **C 档**(确无法自动化的人工交互)= 陈述 + 锚点,**评审默认采信,不得仅以
  「无原始命令输出」判 blocker**;C 档 ≤ 用例总数 1/3(总数 <3 时至多 1 条)
  且须逐条写明不可自动化的理由

## 评审历程

plan 阶段评审 7 轮(轮次上限经用户逐次授权放宽:3 → 5 → 6 → 7),实现层评审
1 轮通过。

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| plan-01 | fail | TC-07 依赖本轮 review 产物,与 rawf 时序冲突形成死锁;B 档核验语义无覆盖 |
| plan-02 | fail | 反向校验未打到真靶子(漏掉 review.md 与 rawf-implement 中的旧硬编码);TC-07 步骤自相矛盾 |
| plan-03 | fail | **plan-blocker**:未回写 docs/decisions,0005 现行表述与档位制互斥 |
| plan-04 | fail | 测试未覆盖 rawf-plan 与 rawf-review 两个被改 skill 的正文 |
| plan-05 | fail | 0005 正文改写违反 ADR「不删历史」;轮次放宽授权来源未记入产物 |
| plan-06 | fail | 改动范围表对 0005 的说明与后文「正文一字不改」自相矛盾(修订遗留) |
| plan-07 | **pass** | 无问题 |
| impl-01 | **pass** | 无问题;确认改动范围与 plan 一致,14 条 A 档证据的命令、输出、退出码齐备且支持 pass 结论 |

## 自测结果

14 条用例**全部 A 档**(C 档 0 条——本任务无不可自动化项,上限非下限),
全部 pass,完整原始输出落 `evidence/TC-01.log` ~ `TC-14.log`。覆盖:三档定义、
B 档失败分支、C 档采信语义、向后兼容与边界、旧规则残留反向校验(TC-10/11)、
三个 skill 正文、ADR 历史保留正向断言(TC-14)。

## 遗留 minor 及处置

无。plan 阶段与实现层最后一轮评审均无 minor 条目。

## 后续观察点

新规则在评审端对 **C 档**的实际表现,本任务无从触发(C 档 0 条),留待后续
含人工交互用例的任务验证。若出现 C 档被滥用(该自动化的项塞进 C 档),按
0006「残留风险」条目新增决策收紧。
