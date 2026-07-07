---
status: approved
task: plan-stage-review
date: 2026-07-07
approved_at: 2026-07-07 06:03:45 +0000
---

# 方案:plan 阶段引入 Codex 评审(>10 文件改动)

## 背景与目标

实践中发现 plan-blocker(方案/架构层面的错误)在**实现层评审**(review.sh)
才被发现,代价高:实现工作全废、退回方案重做。根因是 plan-blocker 的检测点
太靠后。

**目标**:把 Codex 评审左移到 plan 阶段。对预计触及文件 **> 10** 的改动,在
"方案确认闸【人工】"**之前**先由 Codex 审查 plan.md,plan-blocker/major 就地
改进 plan.md,尽量一次改完;拿不准的问题交开发者(用户)敲定。使实现层评审
时几乎不再冒出 plan-blocker。

**非目标(本次不做)**:
- 不改现有实现层评审 review.sh 的行为与判定语义(plan-blocker 在实现层评审
  仍不计入 pass/fail)。
- 不引入 hook 强制拦截"未过 plan 评审就批准"。plan 阶段的文件数只是估计值,
  机器无法可靠核验,故 plan 评审的触发靠 skill 纪律 + CLAUDE.md 硬规则,不靠
  hook(见"风险")。

## 改动范围

新增:
1. `.ai-workflow/scripts/plan-review.sh` —— plan 阶段评审脚本。只读运行
   codex(`--sandbox read-only`),不改工作区,故无需 review.sh 那套副本隔离与
   完整性哈希。退出码 0=pass / 1=fail / 3=执行异常,与 review.sh 同构。
2. `.ai-workflow/prompts/plan-review.md` —— plan 评审指令。
3. `.ai-workflow/schemas/plan-review.schema.json` —— 输出 schema。severity 枚举
   为 `plan-blocker | major | minor`(plan 阶段无实现,去掉 `blocker`)。

修改:
4. `.ai-workflow/review-standards.md` —— **新增"plan 阶段评审语义"小节**,消解
   判定契约冲突(R-01):明确原判定规则(blocker/major→fail、plan-blocker 不
   计入)仅适用于**实现层评审(review.sh)**;plan 阶段评审(plan-review.sh)
   规则为"存在任一 **plan-blocker 或 major → fail**,仅 minor/无问题 → pass"。
5. `.claude/skills/rawf-plan/SKILL.md` —— 在"起草 plan"与"呈现摘要/确认闸"
   之间插入一步:预计文件 > 10 时跑 plan-review.sh,按结果分流。
6. `AGENTS.md` —— 工作流第 1 步补充 >10 文件的 plan 评审规则。
7. `CLAUDE.md` —— 开发工作流列表与硬规则补充对应条目。
8. `.gitignore` —— 忽略 plan 评审的原始输出与原子发布临时文件
   (`.ai/**/.plan-review-raw-*`、`.ai/**/.plan-review-out-*`)。

明确不动:review.sh、gate-plan.sh、gate-review.sh、rawf-implement/review/report
skill、既有 review.schema.json 与 review.md,以及 review-standards.md 中实现层
评审的原有判定规则。

## 实现方案

### 1. plan-review.sh 关键逻辑(与 review.sh 同构,去掉隔离)
- 定位任务:读 `.ai/.current-task` → task_dir;要求 `plan.md` 存在,否则 exit 3。
- **轮次模型(修正 R-02)**:`count` = 已有 `plan-review-round-*.md` 数量;
  `nn = count + 1`(两位数)。允许多轮:改完 plan 后重评即 round-02。
  **2 轮上限机器强制**:`count >= 2` 时直接 exit 3,提示已达上限、转人工——
  不再有 review.sh 那种"同轮已存在→拒绝"的检查(plan-review 无外部轮次驱动,
  该检查在此永不可触发,予以移除)。
- 原子锁:`mkdir "$task_dir/.plan-review-lock"`,并发第二实例 exit 3;trap 清理。
- 调用:`codex exec --sandbox read-only -C "$proj" --output-schema <plan schema>
  --output-last-message "$task_dir/.plan-review-raw-<nn>.json" "$prompt"`。
  prompt 从 `plan-review.md` 读入,替换 `{{TASK_DIR}}`、`{{ROUND}}`。
- **失败路径(与 review.sh 同构,均 exit 3)**:codex 非零退出;codex 退出 0 但
  无输出文件;输出非合法 JSON;缺合法 verdict 字段——非法 JSON/缺字段时把原始
  输出保留到 `$task_dir/.plan-review-raw-<nn>.json` 供排查。
- 结果校验(交叉复核):verdict∈{pass,fail} → 按严重度清单推导 `derived`
  (**含 plan-blocker 或 major → fail**,否则 pass)→ 自报 verdict 与 derived
  矛盾则判无效 exit 3。判定规则以 review-standards.md 新增小节为权威。
- 渲染与发布:jq 渲染 markdown,问题按 `plan-blocker < major < minor` 排序置顶;
  写全临时文件后 `mv -n` 原子发布到 `plan-review-round-<nn>-<verdict>.md`;
  渲染失败清理临时文件并 exit 3;`mv -n` 目标已存在则不覆盖、exit 3。
  **渲染+发布封装为函数 `publish_round(nn, verdict)`**,作为可控测试点(修正
  R-04):正常流程下 `.plan-review-lock` 已串行化运行、同轮发布冲突不可达,
  `mv -n` 属防御性冗余(类比 review.sh 完整性哈希),故其"不覆盖"行为由单测
  直接调用该函数、注入已存在的目标文件来验证,而非靠主流程构造竞争。
- 末尾 `[ "$verdict" = "pass" ]` 决定退出码 0/1。

### 2. plan-review.md 指令要点
- 评审对象:`{{TASK_DIR}}/plan.md`(方案本身),不是代码 diff。
- 权威标准指向 `.ai-workflow/review-standards.md`,评审前完整阅读;plan 阶段
  不使用 `blocker`,判定按新增的"plan 阶段评审语义"小节。
- **硬约束(防主观膨胀)**:只列会导致返工或架构错误的 `plan-blocker`/`major`;
  风格、个人偏好、等价写法之争一律不列(至多降为 minor)。核心只问两件事:
  方案是否有架构/正确性错误或与既有约定冲突?测试用例是否真实覆盖验收标准
  (只测 happy path 即 major)?
- 输出由 `--output-schema` 强制为 JSON;verdict 必须与严重度清单一致。

### 3. plan-review.schema.json
- 结构复用 review.schema.json,仅 severity 枚举改为
  `["plan-blocker","major","minor"]`。

### 4. review-standards.md 新增小节(修正 R-01)
在"判定规则"后追加:
> ## plan 阶段评审(plan-review)语义
> 上述判定规则适用于**实现层评审**(review.sh):blocker/major→fail,
> plan-blocker 单独列出、不计入 pass/fail。
> **plan 阶段评审**(plan-review.sh,实现前审方案)另用一套:此时尚无实现,
> 不使用 blocker;**存在任一 plan-blocker 或 major → fail**(须就地修订 plan),
> 仅 minor 或无问题 → pass。

### 5. rawf-plan skill 插入(现步骤 5 与 6 之间)
新增步骤(预计文件 > 10 才执行):
> 运行 `bash .ai-workflow/scripts/plan-review.sh`(后台等待完成)。分流:
> - fail(有 plan-blocker 或 major)→ 就地修订 plan.md(尽量一次改完),重跑
>   评审;脚本强制**最多 2 轮**,达上限(exit 3)仍不决 → 停止,交用户敲定。
> - pass(仅 minor / 无问题)→ 继续到呈现摘要。
> 拿不准是否采纳某条意见时,不自行"解释掉",呈给用户定夺。
呈现摘要时附上 plan 评审结论与轮次。

### 6/7. AGENTS.md 与 CLAUDE.md
- AGENTS.md 工作流第 1 步补一行:>10 文件在确认闸前先经 plan-review,
  plan-blocker/major 必须就地改 plan 再呈交,最多 2 轮,不决转人工。
- CLAUDE.md:开发工作流列表在"1 出方案"与"2 人工闸"之间插入 >10 文件的
  plan-review 步骤;硬规则新增一条对应说明。

## 测试用例
<!-- codex 非确定,统一用 PATH 上的 codex 桩:桩把预置 JSON 写到
     --output-last-message 指定路径并 exit(码可控),使全脚本可确定性执行。
     "无进行中任务/plan"等前置在临时任务目录内构造。 -->

| 编号 | 前置条件 | 步骤 | 预期结果 |
|---|---|---|---|
| TC-01(pass) | 任务目录含 plan.md;桩输出 `{"verdict":"pass","issues":[],"overall":"ok"}` 且 exit 0 | 运行 plan-review.sh | 退出码 0;生成 `plan-review-round-01-pass.md` 含 `VERDICT: pass`;锁已清理 |
| TC-02(fail) | 桩输出含一条 `plan-blocker`、`verdict:"fail"`,exit 0 | 运行 plan-review.sh | 退出码 1;生成 `plan-review-round-01-fail.md` |
| TC-02b(排序置顶,改正 R-05) | 桩按**乱序**输出三条:`minor`、`plan-blocker`、`major`,`verdict:"fail"` | 运行 plan-review.sh | 生成文件中问题实际顺序为 `plan-blocker → major → minor`(断言渲染后行序,非仅"存在") |
| TC-03(无 plan.md) | 任务目录无 plan.md | 运行 plan-review.sh | 退出码 3;提示 plan.md 不存在;不生成评审文件 |
| TC-04(多轮,改正 R-02) | 已存在 `plan-review-round-01-fail.md`;桩输出 pass | 运行 plan-review.sh | 退出码 0;生成 **`plan-review-round-02-pass.md`**(而非拒绝) |
| TC-05(轮次上限) | 已存在 `plan-review-round-01-*.md` 与 `-02-*.md`(count=2) | 运行 plan-review.sh | 退出码 3;提示已达 2 轮上限、转人工;不生成 round-03 |
| TC-06(交叉校验) | 桩输出 `verdict:"pass"` 但 issues 含一条 `major` | 运行 plan-review.sh | 退出码 3;判"自报与推导矛盾、评审无效";不发布 `-pass.md` |
| TC-07(并发锁) | 预先手动 `mkdir .plan-review-lock` | 运行 plan-review.sh | 退出码 3;提示锁已存在;不误删他人锁 |
| TC-08(codex 失败) | 桩 exit 非 0 | 运行 plan-review.sh | 退出码 3;提示 codex 执行失败;不生成评审文件 |
| TC-09(退出 0 无输出) | 桩 exit 0 但不写 output 文件 | 运行 plan-review.sh | 退出码 3;提示无评审输出 |
| TC-10(非法 JSON/缺字段) | 桩写入非 JSON 或缺 verdict,exit 0 | 运行 plan-review.sh | 退出码 3;原始输出保留在 `.plan-review-raw-<nn>.json`;不发布结论 |
| TC-11(发布冲突,改正 R-04) | 直接调用 `publish_round 03 pass`,且 `plan-review-round-03-pass.md` 已预置占位内容 | 单测调用发布函数(绕过轮次计数) | 退出码 3;提示已被并发发布;**断言原占位文件内容未变**(mv -n 未覆盖) |
| TC-12(阈值语义/文档) | 无 | 阅读 rawf-plan skill 与 AGENTS.md/CLAUDE.md | 均明确"> 10 触发、≤ 10 不触发、评审位于确认闸之前、最多 2 轮" |
| TC-13(静态检查) | 无 | `bash -n plan-review.sh`;`jq -e . plan-review.schema.json` | 语法通过;schema 合法且 severity 枚举为三值 |

## 风险与回滚

- **无代码可锚定,plan 评审更主观**:可能把偏好之争升级为 plan-blocker,撑大
  轮次。对策:prompt 硬约束"只列返工/架构级问题"、2 轮机器上限、用户终裁。
- **触发靠估计的文件数,无法机器强制**:>10 的判断在 plan 起草时估算,hook
  无法核验,故不做 hook 拦截,依赖 skill+硬规则。残留风险:AI 低估文件数而
  漏触发。缓解:rawf-implement 已有"实际偏差需停下问用户"的约束可兜底(本次
  不改该逻辑,仅在汇报中提示)。
- **契约一致性**:plan 评审判定与实现层评审判定并存,二者语义不同(plan-blocker
  是否计入 fail 相反)。已在 review-standards.md 用独立小节分域界定,防止再次
  互斥(R-01 根因)。
- **codex 不可用/超时**:脚本 exit 3 并提示,与 review.sh 一致;plan 阶段可由
  用户决定跳过评审直接进确认闸(人工兜底)。
- **回滚**:改动集中在新增 3 文件 + 5 处文档/配置增量,`git revert` 单个提交
  即可完全回退,不影响既有实现层评审链路。
