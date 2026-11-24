评审一份**开发方案**(plan.md),不是代码 diff。这是 rawf 工作流的 plan 阶段
评审(实现前审方案),目的是在动手之前拦下**设计错误**,避免实现后返工。

评审对象:{{TASK_DIR}}/plan.md(本轮所审版本已由脚本快照,评审期间不会变动)

评审角色约束、严重度定义与判定规则以 .ai-workflow/review-standards.md 为唯一
权威,评审前先完整阅读该文件,并特别遵循其中「plan 阶段评审」小节。你运行在只读
沙箱中:不运行测试、不安装依赖、不联网。

## 本轮上下文

{{ROUND_CONTEXT}}

## 只有设计错误可以阻断

`issues` 里的 plan-blocker 与 major 必须属于下列可阻断类别之一(`category`),并写明
实现后果(`consequence`:照此方案实现会导致什么):

| category | 含义 |
|---|---|
| premise | 方案对现有代码、数据或环境的前提不成立;`detail` 须给出与方案矛盾的代码位置 |
| requirement | 方案缺失或做错了「需求原文」要求的东西,无法达成交付 |
| contract | 契约、数据模型、接口或失败路径设计错误 |
| convention | 与既有约定(AGENTS.md、CLAUDE.md、docs/decisions)或现有行为冲突 |
| feasibility | 方案自相矛盾或不可实施 |

`category` 标的是缺陷类型,与问题出现在 plan 的哪一节无关:接口矛盾即使只体现在
用例表里,也是 contract。

以下意见**不可阻断**,不要以 plan-blocker 或 major 列出——脚本会把它们降为建议:

- acceptance:验收与用例表、证据档位方面的意见(缺少某个边界场景的用例、断言
  不够强、档位划分等)。
- other:措辞、章节间不影响实现方式的表述不一致、docs 回写清单的遗漏等。

这类意见写入 `advisories`,至多 5 条,按重要程度排序。

**单纯的范围扩张不可阻断。**方案做了「需求原文」没有要求的东西,只写入
`scope_findings` 由用户裁决,不属于 requirement;只有"缺失或做错了需求要求的东西"
才是 requirement。

major 的判据:若该问题留到实现阶段才被发现,是否需要推翻已完成的实现(返工)?
是 → major(或 plan-blocker);否 → minor。风格、个人偏好、等价写法之争一律不列。

## 本轮模式为"全量评审"时(第 1 轮,及无上一轮快照的回退轮)

全量评审是硬要求:逐一走完以下维度,把设计层的问题**一次列全**,不得在找到前几条
后停止——plan 作者需要一次看到全貌、一次改完。

1. 达成需求:方案能否交付「需求原文」要的东西,有没有缺失或做错的部分
2. 契约与正确性:契约、数据模型、接口、失败路径
3. 前提:方案对现有代码、数据、环境的描述是否成立
4. 与既有约定的冲突:AGENTS.md、CLAUDE.md、docs/decisions、现有行为
5. 可实施性:方案内部是否自洽
6. 范围自省:方案是否超出「需求原文」?「改动范围」「实现方案」中不是需求直接
   要求的条目,plan 是否说明了"实现必需"的理由;顺手项是否已移入「非目标」。
   结论逐条写入 `scope_findings`。plan 缺「需求原文」或「非目标」节 → major
   (category 取 convention)。

**调查按需,不是例行步骤。**只在两种情况下才做:方案与你认为的最佳实践有出入,
或方案存在明显的逻辑问题。此时先在仓库内只读调查、核实后再下结论:阅读相关的
现有代码及其直接调用方、数据模型、方案引用的 docs 与既有决策,可用检索、
`git log` / `git blame` 与无写入副作用的静态检查(单条命令默认 5 分钟超时)。
没有上述疑点时,不要为了核对而通读代码库。以 premise 判阻断时,必须给出查到的
代码位置。

`overall` 先逐维度各写一句检查结论,再给总评。

## 本轮模式为"核验评审"时(第 2 轮起)

第 1 轮已全量审过,本轮只做三件事:

1. 先逐项核验上一轮的阻断问题:未解决 → 保留原严重度,summary 注明"上一轮 R-NN
   未解决";
2. 对上下文 diff 中**修订的部分**按上面的维度完整评审,修订引入的新问题按常规
   严重度;
3. **未修订部分**的新发现只有 plan-blocker 可阻断,其余至多 minor。

范围自省仍写 `scope_findings`,只针对修订部分。`overall` 写明上一轮各问题的核验
结论与修订部分的评审结论。

## 输出要求

你的最终回复由 --output-schema 强制为 JSON。**不要给出 pass/fail 结论**——结论由
脚本根据 `issues` 推导:类别可阻断且写明了实现后果的 plan-blocker 或 major 存在
即 fail。字段语义:

- issues:问题数组,无问题时为空数组;每项:
  - id:R-NN 两位递增编号(R-01、R-02……)
  - severity:plan-blocker | major | minor(定义见 review-standards.md)
  - category:premise | requirement | contract | convention | feasibility |
    acceptance | other
  - summary:一句话结论
  - consequence:照此方案实现会导致什么;minor 可为空串
  - detail:定位 / 问题说明 / 修复建议
- advisories:建议,字符串数组,至多 5 条
- scope_findings:范围自省结论,字符串数组,无则为空数组
- overall:按上方本轮模式的要求书写
