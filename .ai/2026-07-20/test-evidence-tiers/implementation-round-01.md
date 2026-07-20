---
task: test-evidence-tiers
round: 01
date: 2026-07-20
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/review-standards.md` | 「评审动作边界」中的证据协议条目改为按档位核验的指针(删去原「全部测试用例统一适用」小节);新增「测试证据档位(证据契约)」章节:A/B/C 三档定义表、四条档位约束(A 档强制不得降档、C 档 ≤1/3 且总数<3 时至多 1 条并须写理由、形态优先级与截图不得为唯一证据、未声明档位回退 A 档)、以及「逐档核验规则」子节(A 缺失→blocker 并开补交清单;B 引用不存在→blocker、不支持结论→major;C 默认采信 + 三种判问题情形 + 不得仅以「无原始命令输出」判 blocker;任一档位矛盾→虚报 blocker) |
| `.ai-workflow/prompts/review.md` | 证据核验段重写为「按 plan 声明的档位逐条进行」,明示不得统一套用最严标准,并逐档给出要点;删去原无档位限定的「证据缺失或不完整按 blocker 处理」表述 |
| `.ai-workflow/prompts/plan-review.md` | 核心问题增列第 3 项「证据契约是否合规」,含三个 major 检查点:未逐条声明档位 / 可自动化用例被塞进 C 档 / C 档超限或缺理由 |
| `.ai-workflow/templates/plan.md` | 测试用例表增「档位」「证据形态」两列;表头注释补档位填写说明(三档语义、B 档引用须带 `文件:行号`、C 档须写明不可自动化的理由、1/3 上限与截图约束) |
| `.ai-workflow/templates/implementation-round.md` | 测试结果表增「档位」列;注释明确结果取值 pass/fail/`blocked`、blocked 语义(不得自行降档、须停下问用户、不进入评审)与逐档证据形态 |
| `.claude/skills/rawf-plan/SKILL.md` | 第 5 步增「证据契约同为硬要求」:逐条声明档位与证据形态、可自动化者一律 A 档不得降档、C 档 ≤1/3 且须写理由(并点明上限非下限)、证据优先取日志文本 |
| `.claude/skills/rawf-implement/SKILL.md` | 第 5 步改为按档位留证据(A/B/C 分述);新增第 6 步「实事求是」硬规则三条:不得下调档位或改写用例重要性、无法执行记 `blocked` 并停下向用户说明、禁止虚构或推测结果、存在 blocked 项不进入评审 |
| `.claude/skills/rawf-review/SKILL.md` | 新增第 3 步:分流前按 plan 声明的档位核对;评审仅因无原始输出打回 C 档属可向用户申诉的误报,不得自行修改 plan 档位迎合评审 |
| `docs/decisions/0006-test-evidence-tiers.md` | **新增** ADR:四段式记录档位制决策,含缘起案例、三档与约束、逐档核验、实现侧对称加固、被否掉的比例配额制备选,并显式限定「仅部分取代 0005 的证据协议条款」 |
| `docs/decisions/0005-review-readonly.md` | **仅顶部**加指向 0006 的部分取代标注,声明其余决定继续有效;正文一字未改,保留 2026-07-18 历史原貌 |

## 修复对照

不适用(第 01 轮)。

## 测试结果

plan 声明 14 条用例,**全部 A 档**(C 档 0 条),档位照抄 plan 未作下调。
全部完整原始输出(命令 + stdout/stderr + 退出码)已落 `evidence/`。

| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | `evidence/TC-01.log`——模板 L29 表头 `\| 编号 \| 档位 \| …\| 证据形态 \|`;L24 B 档须带 `文件:行号`;L26 C 档须写理由 |
| TC-02 | A | pass | `evidence/TC-02.log`——L46/47/48 三档定义行;L54 「总数的 1/3」;L58 「不得作为任一用例的唯一证据」 |
| TC-03 | A | pass | `evidence/TC-03.log`——L47 B 档须带 `文件:行号`;L70 「引用不存在 → blocker」;L71 「引用存在但不支持结论 → major」 |
| TC-04 | A | pass | `evidence/TC-04.log`——L72 「默认采信」;L73/74/75 三种判问题情形;L77 「不得仅以「无原始命令输出」为由对 C 档判 blocker」 |
| TC-05 | A | pass | `evidence/TC-05.log`——review.md:13 「按 plan 声明的档位」;plan-review.md:20/21/22 三个检查点 |
| TC-06 | A | pass | `evidence/TC-06.log`——L25 档位列表头;L21/22 `blocked` 取值与语义 |
| TC-07 | A | pass | `evidence/TC-07.log`——三个 SKILL.md 前 4 行 frontmatter 结构完整,`name` 仍为 rawf-plan / rawf-implement / rawf-review |
| TC-08 | A | pass | `evidence/TC-08.log`——L40 「不得下调」;L41 「停下向用户说明」;L43 「禁止虚构或推测测试结果」;L46 「不进入评审」 |
| TC-09 | A | pass | `evidence/TC-09.log`——L55 「总数 < 3 时至多 1 条」;L59/60 「未声明档位…按 A 档处理」 |
| TC-10 | A | pass | `evidence/TC-10.log`——三条反向 grep **退出码均为 1**(无命中):`全部测试用例统一适用`、`证据缺失或不完整按 blocker 处理`、`所有测试用例的完整原始输出` 均已删净 |
| TC-11 | A | pass | `evidence/TC-11.log`——全域 4 处「完整原始输出」命中行(plan.md:22、review-standards.md:46/67、rawf-implement:29)**全部含「A 档」**;筛出未限定行的管道退出码 1,结果为空 |
| TC-12 | A | pass | `evidence/TC-12.log`——rawf-plan L21 「逐条声明档位与证据形态」;L23 「可自动化者一律 A 档、不得降档」;L26 「C 档 ≤ 用例总数 1/3 且须写明不可自动化的理由」 |
| TC-13 | A | pass | `evidence/TC-13.log`——rawf-review L24 「按 plan 声明的档位」;L25 「仅因无原始输出打回 C 档」;L26 「可向用户申诉的误报」 |
| TC-14 | A | pass | `evidence/TC-14.log`——① 0006 四段式(日期/背景/决定/影响)齐备且 L42 含「部分取代」;② 0005 顶部 L3-L8 取代标注指向 0006;③ **正向断言通过**:0005 历史原句仍在(L27 「全部测试用例统一走」、L41 「所有用例完整原始输出强制落盘」),ADR 历史未被改写 |

## 与方案的偏差

无实质偏差,10 个文件与 plan「改动范围」逐一对应,14 条用例全部执行且通过。
两处**编号顺延**属实施细节,不改变方案内容:

- `rawf-implement/SKILL.md`:新增「实事求是」硬规则作为第 6 步,原第 6~8 步
  顺延为第 7~9 步(内容未变,第 8 步补一句「测试结果表的档位列照抄 plan」);
- `rawf-review/SKILL.md`:新增档位核对作为第 3 步,原第 3 步顺延为第 4 步,
  新第 3 步末尾指向「按第 4 条原样呈给用户裁决」保持引用自洽。

另:本轮无 `blocked` 项,无需用户裁决即可进入评审。新规则在评审端的实际
表现(Codex 是否仍以「无原始输出」打回 C 档)按 plan 约定不作为验收用例,
待本轮 review 产出后记录观察结果——本任务 C 档为 0 条,该观察本轮无从触发,
留待后续含 C 档用例的任务验证。
