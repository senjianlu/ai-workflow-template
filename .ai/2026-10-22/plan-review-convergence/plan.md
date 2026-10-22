---
status: approved
task: plan-review-convergence
date: 2026-10-22
approved_at: 2026-10-22 11:44:21
evidence_format: v1
---

# 方案:plan 评审"前两轮穷尽、第 3 轮起收敛"+ 默认 5 轮 + shellcheck 补跑

## 需求原文

> 提交,提交流程就按你说的那么来。
> 关于停车场的事情,不要动其他仓库,仅处理我们流程相关的,合并为一次优化修正。

> "每一轮都从零全审,并能挑出前几轮没有提过的新问题",是否意味着我们需要让
> 第一轮评审拥有更高的完整评审需求?或是放宽到默认最大 5 轮评审,并第 1、2 轮
> 评审完整且完全,后续收敛。你觉得呢?

> 这个 plan 也需要过 review

对齐结论:两个方向一起做——首轮(及第 2 轮)穷尽评审是治本,第 3 轮起收敛、
默认 5 轮是兜底;实现层修复默认 3 轮不变。

上一任务停车场中与流程相关的两条:"plan 评审 fail 率约 75% 的成因分析与收敛"、
"安装 shellcheck 后补跑 TC-13 的 shellcheck 部分"。

**本任务交付**:模板 1.2.0——plan 评审第 1、2 轮为全量穷尽评审(固定检查维度、
一次列全、含 minor),第 3 轮起为收敛评审;plan 评审默认上限 3 → 5 轮;plan 阶段
major 落到"留到实现阶段是否返工"的判据;shellcheck 纳入流程脚本验证。

## 调研结论(四个 consumer 项目 .ai/ 只读统计)

| 事实 | 数据 |
|---|---|
| 跑过 plan 评审的任务 / 轮次 | 252 个 / 1059 轮 |
| 首轮通过率 | 12%(30/252) |
| 第 2 ~ 6 轮单轮通过率 | 35% / 33% / 23% / 28% / 20%,不随轮次上升 |
| 轮次分布 | 中位 3 轮;6 轮以上 56 个,最长 24 轮 |
| 首轮报出的 plan-blocker/major 条数 | 0 条 30 份、1~2 条 117 份、3~4 条 77 份、≥5 条 28 份 |
| 首轮报出 minor 的评审 | 252 份中仅 1 份 |
| 第 2 轮起的问题中与上一轮修订相关的 | 17%(188/1102);83% 是此前各轮未提过的新问题 |
| 涉及具体用例编号的问题 | 各轮约 21%(预期值算术、正则转义、排序等细节为主) |
| plan 平均行数 | 1~2 轮 182 行;3~5 轮 268 行;6 轮以上 385 行 |
| 轮次上限覆盖 | 252 处,均为用户明确要求放宽(多为 8 ~ 15 轮) |
| Codex 推理强度 | 全局配置已为 high |

成因:

1. **首轮没有审全**:评审者每轮只报最显眼的两三条就收手,几乎从不报 minor;
   后续各轮的"新问题"主要是首轮遗漏的存量逐轮释放。
2. **没有收敛机制**:`prompts/plan-review.md` 不给上一轮评审、不区分修订与未修订
   部分,每轮都从零全审。实现层评审的 prompt 有"对照上一轮逐项核验",plan 没有。
3. **major 判据不落地**:用例算术、转义这类实现时自然暴露、顺手可修的细节按 major
   判,整轮 fail。
4. **评审面随修订膨胀**:修订往 plan 里加文字,新增文字成为下一轮的评审面。
5. 推理强度已为 high,不是可用杠杆;完整性只能靠 prompt 约束。

shellcheck:临时 venv 中装 0.11.0 跑全部流程脚本,error 级 0 条;warning/note 级
5 条,均为误报或无害(trap 字符串调用的函数、未用的局部变量与循环变量)。

## 背景与目标

让 plan 评审的问题在前两轮集中暴露、在后续轮次收敛:第 1、2 轮按固定维度穷尽列出
全部问题(含 minor),plan 作者一次改完;第 3 轮起评审面只剩"上一轮未解决的问题 +
本轮修订引入的问题 + 新发现的 plan-blocker"。同时把 plan 阶段 major 的判据写成一句
可执行的话,把机械性用例细节降为 minor 并允许实现者按明确意图修正。

## 改动范围

| 文件 | 改动 |
|---|---|
| `.ai-workflow/scripts/plan-review.sh` | ① 默认上限 3 → 5(`resolve_max_rounds` 缺省值与注释);② 每轮先把 plan.md 快照为 `.plan-review-raw-NN.plan.md`(命中既有 gitignore 模式 `.ai/**/.plan-review-raw-*`),diff 基于快照生成;③ 生成 `{{ROUND_CONTEXT}}`(见实现方案 1);④ codex 结束后核对 plan.md 与快照一致,不一致拒绝发布、不消耗轮次;⑤ 新增只读入口 `__minors <任务目录>`:汇总**全部轮次**评审文件中的 minor |
| `.ai-workflow/prompts/plan-review.md` | `{{ROUND_CONTEXT}}` 占位;第 1、2 轮穷尽评审(五个固定维度、一次列全、含 minor、overall 逐维度一句);第 3 轮起收敛三条规则;引用返工判据 |
| `.ai-workflow/review-standards.md` | 「plan 阶段评审语义」新增:返工判据、明确判 minor 的类别、前两轮穷尽 / 第 3 轮起收敛的规则;「逐档核验规则」新增"机械性更正"条款(实现层评审以更正后的 plan 为基准,并核验更正是否只属机械性) |
| `.claude/skills/rawf-plan/SKILL.md` | 第 4 步加 plan 写作粒度;第 6 步默认 5 轮、修订纪律(只改被指出的问题、不顺带扩写)、未修的 minor 交实现阶段、评审运行期间不得修改 plan.md |
| `.claude/skills/rawf-implement/SKILL.md` | 第 1 轮实现前用 `__minors` 汇总全部轮次的 plan 评审 minor,逐条在实现记录写处置;用例中意图明确的机械性错误:回写 plan 测试表(保留原文与理由)+ 记"替代"偏差;改变意图或放宽断言仍须停下问用户 |
| `.ai-workflow/templates/implementation-round.md` | 新增「plan 评审 minor 交接」节(仅第 1 轮、仅跑过 plan 评审时填写) |
| `CLAUDE.md` | 第 1b 步"默认最多 3 轮"→ 5;硬规则"评审轮次上限默认均为 3 轮"改为"plan 评审默认 5 轮、实现层修复默认 3 轮" |
| `AGENTS.md` | 通用硬规则"plan-review,默认最多 3 轮"→ 5 |
| `README.md` | 机制速览新增一行:plan 评审前两轮穷尽、第 3 轮起收敛 |
| `docs/decisions/0012-plan-review-convergence.md`(新) | 决策记录 |
| `docs/decisions/0001-plan-stage-review.md` | 「修订」节追加 2026-10-22 条目指向 0012 |
| `docs/decisions/0003-configurable-review-round-caps.md` | 顶部标注"plan 评审默认值部分被 0012 取代" |
| `CHANGELOG.md`、`.ai-workflow/TEMPLATE-VERSION` | 1.2.0 |

共 14 个文件,> 10,确认闸前走 plan 评审。

明确不动:review.sh、`prompts/review.md`、`impl_fix_max_rounds` 默认 3(实现层评审
规则只增"机械性更正"一条,见上表);hooks 与 settings.json;`.gitignore`;放宽机制本身(仍只在用户明确要求时写 frontmatter);
四个 consumer 项目与其它任何仓库;本机其它会话遗留的进程。

## 非目标

- 实现层评审的收敛(中位 2 轮,新问题多为真实代码缺陷,另议)
- 把"全量轮数"做成可配置项(固定为前 2 轮,写在脚本与标准里)
- 修复 shellcheck 的 warning/note 级条目;把 shellcheck 列为模板运行依赖
- 停车场中的非流程项:steammarket-refinery 的孤儿轮询进程、consumer 升级

## 实现方案

### 1. plan-review.sh

在上限检查通过、`nn` 确定之后,组装 prompt 之前:

- `snap=$task_dir/.plan-review-raw-$nn.plan.md`;第 nn ≥ 02 轮时 `prev` = nn-1,
  `prev_review` = `plan-review-round-$prev-*.md`(唯一一份),`prev_snap` =
  `.plan-review-raw-$prev.plan.md`
- `{{ROUND_CONTEXT}}` 的首行固定为 `本轮模式:<模式>`,便于测试与评审者识别:

| 轮次 | 模式 | 其余内容 |
|---|---|---|
| 01 | 全量穷尽评审 | — |
| 02 | 全量穷尽评审 | 上一轮评审文件路径(先逐项核验);修订 diff(供定位) |
| ≥ 03 且 prev_snap 存在 | 收敛评审 | 上一轮评审文件路径;修订 diff(划定"修订部分") |
| ≥ 03 且 prev_snap 不存在 | 全量穷尽评审(无上一轮快照) | 上一轮评审文件路径;说明无法区分修订与未修订部分 |

- 修订 diff:`diff -u --label "第 $prev 轮所审 plan.md" --label "当前 plan.md"`,
  放进 ```diff 代码块;为空时写"plan.md 自第 $prev 轮评审以来未修订";第 02 轮
  无 prev_snap 时只写说明不给 diff
- **版本绑定**:上限检查通过后**先** `cp plan.md` 写出快照,diff 以"上一轮快照 vs
  本轮快照"生成(不读可变的 plan.md);codex 结束、解析结论之后、发布评审文件之前,
  比对当前 plan.md 与本轮快照的 sha256——不一致 → stderr 报"plan.md 在评审期间被
  修改,本轮结论作废"、exit 3、不发布评审文件(轮次号不被消耗,重跑仍为同一 NN),
  原始输出保留供排查。plan.md 评审运行期间不得修改,rawf-plan 第 6 步同步写明
- 快照同轮重跑覆盖,属运行时产物,与 `.plan-review-raw-NN.json` 同性质,不入库
- 上限检查先于快照:达上限拒绝时不写快照
- `__minors <任务目录>`:按轮次顺序扫描全部 `plan-review-round-*.md`,输出每条
  `- [minor]` 为一行 `| NN/R-xx | 概要 |`;无任何 minor 时输出"无"。只读,不受锁与
  上限约束(与既有 `__publish_round` / `__resolve_max_rounds` 同为测试/工具入口)
- 脚本头注释"无评审期间禁改约束"改为:plan.md 受上述一致性核对保护,工作区其它
  文件仍无禁改约束

### 2. prompts/plan-review.md 与 review-standards.md

**返工判据**(review-standards「plan 阶段评审语义」,prompt 引用):

> 若该问题留到实现阶段才被发现,是否需要推翻已完成的实现(返工)?是 → major
> (或 plan-blocker);否 → minor。

明确判 minor:用例中意图明确的机械性错误(笔误、排序、转义、算术、措辞);章节间
不影响实现方式的表述不一致;docs 回写清单的遗漏(实现层评审按回写规则核对)。
仍判 major:验收标准缺覆盖(含异常路径)、验收标准不可达或自相矛盾、契约/数据
模型/接口错误、证据契约违规、缺「需求原文」/「非目标」节。风格与个人偏好之争仍不列。

**第 1、2 轮:全量穷尽评审**——逐一走完五个维度,一次列出全部问题(含 minor),
不得在找到前几条后停止;`overall` 逐维度各写一句检查结论再给总评:

1. 架构与正确性(能否达成需求原文的交付;契约、数据模型、接口、失败路径)
2. 与既有约定的冲突(AGENTS.md、CLAUDE.md、docs/decisions、既有脚本行为)
3. 验收覆盖(每个验收点有用例;异常/边界路径;预期可达且自洽)
4. 证据契约(现有三条检查)
5. 范围自省(结论写 `scope_findings`)

第 2 轮另需先逐项核验上一轮的 plan-blocker/major。

**第 3 轮起:收敛评审**——

1. 先逐项核验上一轮的 plan-blocker/major:未解决 → 原严重度保留,summary 注明
   "上一轮 R-NN 未解决";
2. 对 diff 中修订的部分完整评审(五个维度),修订引入的新问题按常规严重度;
3. 未修订部分的新发现**只报 plan-blocker**,其它新问题至多 minor。

### 3. skill 与规则文本

- rawf-plan 第 4 步:plan 写到能判断方案对错、能验收为止(契约、数据模型、接口、
  验收标准、风险),不预写实现代码与逐行细节——plan 里每一句都是评审面。
- rawf-plan 第 6 步:默认 5 轮;第 1、2 轮的意见尽量一次改完;修订只改被指出的
  问题,不顺带扩写;minor 可顺手修,未修的随 plan 评审文件交实现阶段。
- **minor 跨轮交接**:评审不要求逐轮重复列出未修的 minor(prompt 写明,避免噪声);
  交接由实现阶段负责——rawf-implement 第 3 步:第 1 轮实现前运行
  `plan-review.sh __minors` 汇总**全部轮次**的 minor(含收敛轮因"未修订部分只报
  plan-blocker"而降级的问题),在 implementation-round-01 的「plan 评审 minor 交接」
  节逐条写处置:已在 plan 修订中解决 / 本轮实现处理 / 不处理(写理由)。
- rawf-implement 第 6 步:"不得改写用例预期结果"保留;例外是意图明确的机械性
  错误(笔误、排序、转义、算术),处理方式唯一:
  1. **回写 plan 测试表**:在原单元格内就地更正,并追加标注
     `〔机械性更正:原文「…」;理由:…;见实现记录 D-NN〕`(不新增 `|`,保持表格可被
     evidence-check 解析);
  2. 实现记录偏差表记"替代",写明原文、更正后文字与理由;
  3. 改变用例意图、删减场景或放宽断言 → 不属于机械性更正,停下问用户。
- review-standards「逐档核验规则」新增"机械性更正"条款:plan 测试表中带
  〔机械性更正〕标注的条目,以更正后的文字为验收基准;评审核验更正是否只修正
  笔误/排序/转义/算术、未改意图、未删减场景、未放宽断言——是 → 按更正后核验;
  否 → major(擅自改写用例),并在 detail 中给出原文与更正对照。
- CLAUDE.md / AGENTS.md:plan 评审默认 5 轮;实现层修复默认 3 轮;放宽机制不变。

### 4. 版本

1.2.0(MINOR):放宽默认上限与新增收敛机制,产物命名与闸门不变;历史任务无快照
时第 3 轮起走回退分支(全量)。

## 测试用例

<!-- 全部 A 档,留证写法 (b):每条一个断言脚本 evidence/tc-NN.sh,由 evidence.sh 包住
     产出 evidence/TC-NN.log,exit 0 = 全部断言成立。TC-01~TC-06 在临时 git 仓库中运行,
     PATH 前置假 codex:把收到的 prompt 落到项目外目录、记录调用,并按 schema 写出指定
     verdict 的 JSON。轮次模式只按 ROUND_CONTEXT 首行"本轮模式:…"断言(prompt 的静态
     规则文本对所有轮次相同)。无 C 档。 -->
| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | 临时项目,plan.md 含一行"旧行";假 codex 输出含 1 条 major 的 fail | 运行 plan-review.sh | exit 1;生成 plan-review-round-01-fail.md;`.plan-review-raw-01.plan.md` 与 plan.md 字节一致;prompt 含"本轮模式:全量穷尽评审",不含 ```diff 与"上一轮评审",无 `{{` 残留 | (b) TC-01.log |
| TC-02 | A | 接 TC-01;"旧行"改为"新行";假 codex 输出 fail | 第 2 轮 | exit 1;prompt 含"本轮模式:全量穷尽评审"、`plan-review-round-01-fail.md` 路径、```diff 块内有 `-旧行` 与 `+新行`;`.plan-review-raw-02.plan.md` 含"新行" | (b) TC-02.log |
| TC-03 | A | 接 TC-02;"新行"改为"第三行";假 codex 输出 pass | 第 3 轮 | exit 0;prompt 含"本轮模式:收敛评审"、`plan-review-round-02-fail.md` 路径、diff 有 `-新行` 与 `+第三行`(且不含 `-旧行`);生成 plan-review-round-03-pass.md | (b) TC-03.log |
| TC-04 | A | 另起临时项目做完第 01 轮,不改 plan.md | 第 2 轮 | prompt 含"自第 01 轮评审以来未修订",不含 ```diff | (b) TC-04.log |
| TC-05 | A | 另起临时项目做完两轮,删除 `.plan-review-raw-02.plan.md`(模拟升级前历史轮次) | 第 3 轮 | 正常完成;prompt 含"本轮模式:全量穷尽评审(无上一轮快照)"与 `plan-review-round-02-` 路径,不含 ```diff | (b) TC-05.log |
| TC-06 | A | 临时项目 | ① `__resolve_max_rounds` 对无字段 plan;② 无字段、已有 4 轮时运行;③ 无字段、已有 5 轮时运行;④ `plan_review_max_rounds: 1`、已有 1 轮时运行;⑤ `git check-ignore` 快照文件;⑥ `__publish_round` 渲染样例 JSON | ① 输出 5;② 假 codex 被调用、生成第 05 轮评审文件;③ exit 3、stderr 含"已达 5 轮上限"、假 codex 未调用、无 `.plan-review-raw-06.plan.md`;④ exit 3、stderr 含"已达 1 轮上限";⑤ 被忽略;⑥ 产物含「范围核对」节 | (b) TC-06.log |
| TC-07 | A | — | grep 断言:review-standards 含返工判据句、minor 类别、"第 1、2 轮"穷尽与"第 3 轮起"收敛;prompt 含 `{{ROUND_CONTEXT}}`、五个维度、"不得在找到前几条后停止"、收敛三条规则;rawf-plan 含写作粒度、修订纪律、"默认 5 轮";rawf-implement 含 `__minors`、"全部轮次"、"回写 plan 测试表"、`〔机械性更正` 标注格式与"放宽断言"停下问用户;review-standards 含"机械性更正"条款,且同时写明"以更正后的文字为验收基准"与"擅自改写用例"判 major;rawf-plan 含"评审运行期间不得修改 plan.md";implementation-round 模板含「plan 评审 minor 交接」节与 `__minors`;prompt 含"不要求逐轮重复列出"未修 minor;CLAUDE.md 含 plan 默认 5 轮与实现默认 3 轮;AGENTS.md 含"默认最多 5 轮";0012 四段;0001 修订节指向 0012;0003 顶部"部分被 0012 取代";CHANGELOG 含 `## [1.2.0]` 与升级指引;TEMPLATE-VERSION 1.2.0;README 提到收敛评审。反向断言:rawf-plan 不含"**默认 3 轮**"、AGENTS.md 不含"plan-review,默认最多 3 轮"、plan-review.sh 不含"缺省 3" | 全部成立 | (b) TC-07.log |
| TC-08 | A | shellcheck 路径经环境变量 `SHELLCHECK` 给出(本机为 /tmp 下临时 venv) | `shellcheck -S error` 检查 `.ai-workflow/scripts/*.sh`、`.claude/hooks/*.sh`、`.githooks/*`;另以默认级别输出全部条目 | error 级 0 条;默认级别输出原样记录,不判 | (b) TC-08.log |
| TC-09 | A | — | `bash -n` plan-review.sh | exit 0 | (b) TC-09.log |
| TC-10 | A | 临时项目;假 codex 在运行中向 plan.md 追加一行后再写出 fail 结论 | 运行 plan-review.sh;随后改用不改 plan 的假 codex 再运行一次 | 第一次:exit 3、stderr 含"评审期间被修改"、无 plan-review-round-01-*.md、`.plan-review-raw-01.json` 保留;第二次:生成 plan-review-round-**01**-*.md(轮次未被消耗),且其快照与当时 plan.md 一致 | (b) TC-10.log |
| TC-11 | A | 临时任务目录,plan 测试表某行预期结果单元格含 `〔机械性更正:原文「[252490, 570, 730]」;理由:排序笔误;见实现记录 D-01〕`,实现记录与证据齐全 | 运行 evidence-check.sh | exit 0;该行档位按 A 识别并标 OK(标注格式不破坏表格解析) | (b) TC-11.log |
| TC-12 | A | 临时任务目录含三份评审文件:第 01 轮 fail 含 `[minor] R-02 甲`;第 02 轮 fail 含 `[minor] R-01 乙(收敛降级)`;第 03 轮 pass 无 minor | ① `plan-review.sh __minors <任务目录>`;② 删去两条 minor 后再运行 | ① 输出同时含 `01/R-02` 与 `02/R-01` 两行及其概要,顺序为第 01 轮在前;② 输出"无" | (b) TC-12.log |

非 happy-path:TC-04、TC-05、TC-06 ③④、TC-10、TC-12 ②。本任务自身证据的完整核验由 review.sh 的前置
evidence-check 承担,不设用例。

## 风险与回滚

- **前两轮穷尽可能让单轮 token 上升**:换取总轮数下降;返工判据把细节归为 minor,
  列得全不等于 fail 得多
- **收敛规则可能放过未修订部分里的真实 major**:规则只降为 minor、不是不报,且降级后
  的 minor 经 `__minors` 跨轮汇总、在实现记录逐条写处置,不会在交接中丢失;收敛只从
  第 3 轮起生效,此前已有两轮全量;实现层评审仍按代码 diff 全量把关
- **默认 5 轮会让空转多跑两轮才转人工**:收敛机制约束第 3 轮起的评审面;放宽机制不变
- **假 codex 覆盖不到真实 codex 对新规则的理解**:本 plan 的评审用的是现行 prompt;新
  规则首次真实生效在下一个 > 10 文件的任务
- **机械性更正被滥用为改写用例**:更正必须回写 plan 并保留原文,评审按条款核验,
  越界判 major;改变意图仍须用户裁决
- 回滚:单提交 revert;历史任务无快照时走全量分支,行为不劣于 1.1.0
