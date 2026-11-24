---
status: approved
task: review-model-override
date: 2026-11-24
approved_at: 2026-11-24 (用户确认:"确认";含保留推理强度字段、按 1.6.0 发布、上一任务先以 1.5.1 提交)
evidence_format: v1
---

# 方案:评审模型的指定入口,版本分级规则补"维护者裁量"

## 需求原文

> 前面 2 个我觉得可以一起做掉?

> 然后我希望不指定 plan 和改修模型的时候,都用默认模型。

> 我让你做的前两波啊!如果第二波不在这个仓库就别做!

"前两拨"指 1.5.0 收尾时停车场的分组:第一拨是本仓库内的 4 条,第二拨是随消费仓库
升级做的 1 条(不在本仓库,不做)。第一拨的前 2 条已由任务
`snapshot-excludes-prompt-limit` 完成,剩下 2 条的停车场原文:

> 评审模型没有工作流内的指定入口(本次 plan 评审靠任务之外的一次性包装命令指定)。

> README「版本与升级」的分级规则把"评审 schema / 产物格式不兼容"列为 MAJOR,本次按
> 用户裁定以 1.5.0 发布;是否修订分级规则或写明例外。

**本任务交付**:plan 评审与实现评审各有一个正式的模型指定入口(plan.md frontmatter 的
可选字段,不写就用 Codex 默认模型);README 的版本分级规则补一段"维护者裁量",与
1.5.0 的做法对齐;连同 1.6.0 的发版准备。

## 背景与目标

**评审模型。** 两个评审脚本启动 Codex 时不传模型参数,用的是 `~/.codex/config.toml`
的默认模型。1.5.0 的 plan 评审中用户点名要用另一个模型,当时只能在任务之外放一个
临时包装命令,往 `codex exec` 里塞 `-m`;每轮都要保证包装命令在 PATH 里,漏了就悄悄
回到默认模型,事后也看不出某一轮用的是哪个模型。目标:给"用户点名模型"一个随任务
入库、跨轮有效、脚本直接读取的载体;没点名时行为与现在完全相同。

已用本机的 Codex 实测(项目外空目录、一句话指令):

- `codex exec -m <模型>` 与 `-c model_reasoning_effort="<强度>"` 都被接受,启动信息里
  的 `model:` 与 `reasoning effort:` 随之变化;
- 不支持的模型或强度不会被静默忽略:`codex exec` 以退出码 1 结束并报错(强度的可选
  值由服务端给出,当前是 none / minimal / low / medium / high / xhigh / max)。

**版本分级。** README「版本与升级」把"评审 schema / 产物命名"的不兼容变更列为 MAJOR。
1.5.0 改了评审输出 schema 与评审文件格式,经用户裁定按 MINOR 发布,CHANGELOG 条目
开头加了「不兼容提示」。规则与做法不一致,下次遇到同类变更时没有依据。目标:把这次
裁定的条件与附带义务写进规则。

## 改动范围

| 文件 | 改动 |
|---|---|
| `.ai-workflow/scripts/plan-review.sh` | 读 `plan_review_model` / `plan_review_effort`,转成 codex 参数 |
| `.ai-workflow/scripts/review.sh` | 读 `impl_review_model` / `impl_review_effort`,转成 codex 参数 |
| `CLAUDE.md` | 硬规则补一条:评审模型缺省用 Codex 默认,仅用户点名时写字段 |
| `.claude/skills/rawf-plan/SKILL.md` | plan 评审一步补 `plan_review_*` 两个字段的写入条件 |
| `.claude/skills/rawf-review/SKILL.md` | 发起评审一步补 `impl_review_*` 两个字段的写入条件 |
| `README.md` | 「机制速览」补一条评审模型;「版本与升级」分级表下补"维护者裁量"一段 |
| `docs/decisions/t0016-review-model-override.md` | 新增决策记录 |
| `docs/decisions/t0008-template-versioning.md` | 顶部补注:分级规则增加维护者裁量条款 |
| `CHANGELOG.md`、`.ai-workflow/TEMPLATE-VERSION` | 1.6.0 条目与升级指引;版本号 |
| `.ai/2026-11-24/review-model-override/assets/tests/` | 测试脚本与记录 codex 参数的桩(非产品文件) |

不是需求直接要求、但实现必需的条目:

- CLAUDE.md 与两个 skill:字段由开发 AI 写入,"什么时候可以写"必须有规则,否则入口
  会被顺手使用(与轮次上限字段同样的考虑,见 t0003)。
- t0016、t0008 补注:前者是新增的关键决策,后者是分级规则的变化,按仓库约定回写 docs/。
- CHANGELOG、TEMPLATE-VERSION:发版三同步的前两项。

明确不动:评审指令、评审输出 schema、评审文件格式、review-standards.md、AGENTS.md、
plan 模板(不加新字段,避免默认路径上的噪音,做法同 t0003)、hooks、rawf-implement 与
rawf-report 两个 skill。

## 非目标

- 在评审文件里记录本轮所用的模型(要改评审文件格式)。
- 校验模型名或强度是否真实存在(由 Codex 判定,见实现方案第 4 点)。
- 项目级或全局的默认评审模型配置:默认值就是 Codex 自己的配置,不另设一层。
- 第二拨:各消费仓库升级时检查路径清单——不在本仓库。
- 停车场其余条目:统计复跑、快照与轮间差异机制是否简化、plan-review.sh 的退出码
  总闸、口径摘要覆盖外部规则文件、review.sh 文件头列出 `comm`。
- 上一任务实现评审留下的 2 条测试缺口(impl/01/T-01、T-02)。本任务改的是 review.sh
  的另一处(codex 启动参数),不借机扩大测试范围;仍留在后续。
- 推送、打标签、GitHub Release:评审通过后另行请用户确认。

## 实现方案

### 一、评审模型的指定入口

**载体**:当前任务 plan.md frontmatter 的四个可选字段。

| 字段 | 读取方 | 传给 `codex exec` 的参数 |
|---|---|---|
| `plan_review_model` | plan-review.sh | `-m <值>` |
| `plan_review_effort` | plan-review.sh | `-c model_reasoning_effort="<值>"` |
| `impl_review_model` | review.sh | `-m <值>` |
| `impl_review_effort` | review.sh | `-c model_reasoning_effort="<值>"` |

**规则**:

1. 字段未出现 → 不传对应参数,Codex 用自身配置的默认值。四个字段都不写时,脚本
   调用 codex 的参数序列与 1.5.x 逐项相同。
2. 四个字段互相独立:可以只指定模型或只指定强度;plan 评审只读 `plan_review_*`,
   实现评审只读 `impl_review_*`。
3. 解析口径与 `plan_review_max_rounds` 相同:只认首个 `---` 块内、行首的字段;值去掉
   首尾空白;写裸值,不加引号。
4. 形态校验:模型须匹配 `^[A-Za-z0-9][A-Za-z0-9._:/-]*$`,强度须匹配 `^[a-z]+$`。字段
   出现但值为空或不匹配 → exit 3,报出字段名与实际值,评审未启动、不消耗轮次。校验
   只管形态(首字符限定同时避免值被 codex 当成命令行选项),不维护模型名与强度的
   枚举:取值是否受支持由 Codex 判定,不支持时 `codex exec` 以非零退出,两个脚本既有
   的处理是报"codex exec 执行失败"、exit 3、不发布评审、不消耗轮次。
5. 解析时机:定位任务目录之后,生成本轮任何产物与启动 codex 之前。
6. 有字段生效时,启动 codex 前向 stderr 打印一行,写明生效的字段与值;四个字段都
   没有时不打印,默认路径的输出不变。
7. 新参数放在 `codex exec` 之后、其余参数之前。评审文件格式不变。

**写入规则**(CLAUDE.md 硬规则,两个 skill 同步):用户没有点名时不写这四个字段,
评审用 Codex 默认模型;仅当用户明确点名模型或强度时,写入对应阶段的字段,并在方案
摘要或实现记录中声明;不得自行写入或建议性写入。指定只对当前任务有效。plan 评审
运行期间不得修改 plan.md(既有规则),要换模型在两轮之间改。

**被否掉的备选**:

- 环境变量或脚本参数:不留痕迹,每一轮都要重新传,开发 AI 的上下文被压缩后容易漏传
  而回到默认模型——正是这次临时包装命令的问题(t0003 否掉同类备选的理由相同)。
- 项目级配置文件:多一个载体;用户的用法是按任务点名。

**已知的小代价**:在 plan 评审的两轮之间改这两个字段,改动会出现在下一轮的修订 diff
里。它不是方案内容,评审者无可评之处;不为此做特殊处理。

### 二、版本分级规则补"维护者裁量"

README「版本与升级」的分级表保持不变,表下补一段(全文):

> **维护者裁量**:上表是默认分级。闸门协议有不兼容变更,但 consumer 收尾在途任务后、
> 按该版升级指引完成常规升级(整体替换与人工合并)即可继续使用,不需要迁移存量
> 任务产物或项目自有内容的,维护者可裁定按 MINOR 发布;该版 CHANGELOG 条目开头
> 必须有「不兼容提示」,写明不兼容之处与升级前提。先例:1.5.0。

t0008 顶部按决策目录的惯例补一行注记,指向这段规则与先例(t0015)。

### 三、发版与提交安排

- **版本号 1.6.0**:新增模型指定入口属于"向后兼容的新增能力",按分级表是 MINOR。
  CHANGELOG 新增 `[1.6.0]` 条目(Added:模型指定入口;Changed:版本分级补维护者
  裁量;升级指引按 CHANGELOG 头部的归类行逐文件写),排在 `[1.5.1]` 之前。
- **前置:上一任务先以 1.5.1 提交。** 工作树里现在有 `snapshot-excludes-prompt-limit`
  的未提交改动(已通过实现评审)。实现评审审的是"相对 HEAD 的未提交改动",不先
  提交的话,本任务的评审会把上一任务的改动再审一遍。提交需要用户确认,与本方案
  一并请示;本任务的实现在该提交之上进行。

### 四、测试

断言脚本放在 `.ai/2026-11-24/review-model-override/assets/tests/run.sh`,夹具建在项目
之外(`mktemp -d`),拷入改后的 `.ai-workflow/`。codex 桩在同目录新建一个薄包装:把
收到的参数(除最后一个,即指令)逐行记到 `$STUB_DIR/args-<n>.txt`,支持用
`STUB_EXIT` 模拟 codex 以非零退出,其余行为转交 1.5.0 任务已入库的桩。留证命令在
仓库根执行:
`bash .ai-workflow/scripts/evidence.sh TC-NN -- bash .ai/2026-11-24/review-model-override/assets/tests/run.sh tcNN`。

## 测试用例

| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | plan 夹具与实现夹具的 plan.md 都不含四个字段 | 各跑一轮评审 | 两次 codex 调用的参数序列都与固定序列逐项相同(`exec --json --sandbox read-only -C <夹具> --output-schema <schema> --output-last-message <输出文件>`),没有 `-m`、`-c`;stderr 没有模型说明行;评审正常发布 | evidence.sh |
| TC-02 | A | plan 夹具写 `plan_review_model`、`plan_review_effort`,并写一个取值不同的 `impl_review_model`;实现夹具反过来 | 各跑一轮评审 | plan 评审的参数里有相邻的 `-m` 与所写模型、相邻的 `-c` 与 `model_reasoning_effort="<所写强度>"`,不含另一阶段的取值;实现评审同理;两者 stderr 各有一行写明生效的字段与值;评审正常发布 | evidence.sh |
| TC-03 | A | 三个夹具:只写 `plan_review_effort`;只写 `impl_review_model`;字段写在 frontmatter 之外的正文行首 | 各跑一轮评审 | 第一个有 `-c`、无 `-m`;第二个有 `-m`、无 `-c`;第三个两者都没有;均正常发布 | evidence.sh |
| TC-04 | A | 两个脚本各自的模型字段依次写入:空值、含空格、以 `-` 开头、带引号;强度字段依次写入:空值、大写、带标点 | 每种写法跑一次评审;随后改成合法值重跑 | 每种写法都 exit 3,stderr 指出字段名,桩未被调用,没有评审文件;改成合法值后发布的是第 01 轮 | evidence.sh |
| TC-05 | A | 字段合法,桩设为以非零退出且不写输出(模拟 Codex 拒绝不支持的模型) | plan 评审与实现评审各跑一次;恢复桩后重跑 | 两者 exit 3,stderr 含"codex exec 执行失败",没有评审文件;重跑发布的是第 01 轮 | evidence.sh |
| TC-06 | A | 本机 codex 已登录;`~/.codex/config.toml` 有默认模型 | 在项目外空目录用真实 codex 跑一句话指令,带 `-m <默认模型>` 与 `-c model_reasoning_effort="low"`(与脚本生成的形态相同) | exit 0;启动信息显示该模型与 `reasoning effort: low` | evidence.sh |
| TC-07 | A | - | 跑 1.5.0 任务套件的 tc03、tc06、tc10 与上一任务套件的 tc01、tc02、tc03、tc06;对两个脚本跑 `bash -n` | 全部 exit 0(上一任务的 tc05 断言版本号为 1.5.1,本任务升到 1.6.0 后不再适用,不跑) | evidence.sh |
| TC-08 | A | - | grep 断言 | CHANGELOG 的 `[1.6.0]` 在 `[1.5.1]` 之前且含「升级指引」;TEMPLATE-VERSION 为 1.6.0;README 有「维护者裁量」一段并列出四个字段;CLAUDE.md 硬规则列出四个字段;rawf-plan、rawf-review 各写明本阶段的两个字段;t0016 存在;t0008 顶部有补注 | evidence.sh |

## 风险与回滚

- 模型名的字符集如果偏窄,会拒绝个别合法的模型名(比如带 `@` 的)。报错写明字段与
  实际值,届时放宽正则即可。
- TC-06 依赖本机的 codex 登录与网络;失败时先区分是环境问题还是参数形态问题。
- 回滚:还原两个脚本,四个字段即被忽略,评审回到默认模型;文档改动各自还原。
