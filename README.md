<p align="center">
  <img src="./logo.svg" alt="ai-workflow-template logo" width="240">
</p>

# ai-workflow-template

Claude Code 负责开发、OpenAI Codex 负责交叉评审的 AI 工作流模板。
方案与评审全程文件留痕,关键闸门由 hooks 硬约束,人只在两处出现:
确认方案、确认提交。

## 依赖

- Claude Code(主对话/开发者)
- OpenAI Codex CLI(评审者,需已 `codex login`,版本需支持
  `codex exec --output-schema`)
- jq(hooks 与评审结论解析/渲染用,`brew install jq`)

## 工作流

/rawf-plan → 【人工确认方案】→ /rawf-implement → /rawf-review
  → fail:修复轮(默认最多 3 轮,用户可明确放宽;plan 级问题直接升级人工)
  → pass:/rawf-report → 【人工确认提交】→ 任务关闭

产物:.ai/<yyyy-mm-dd>/<task-slug>/ 下的 plan.md、
implementation-round-NN.md、review-round-NN-<pass|fail>.md、summary.md,
全部随代码提交;运行时状态 .ai/.current-task 不入库。

## 开新项目

1. GitHub 上 Use this template,克隆到本地
2. 在 `.ai-workflow/TEMPLATE-VERSION` 填写 adopted 采用日期(新建
   项目内容即模板全量,天然处于基线)
3. 清理模板带来的项目自有文件(创建后即与模板脱钩,模板升级不再触碰):
   `CHANGELOG.md` 重置为项目自己的版本历史;`logo.svg` 替换或删除,并同步
   处理本文件顶部对它的引用;删除 `.ai/` 下模板带来的任务目录(模板历史在
   模板仓可查)。`docs/decisions/` 里的 `t` 系列(模板决策)保留,项目决策用
   纯数字、自 0001 起编
4. 启用提交约束(每克隆一次):`git config core.hooksPath .githooks
   && git config commit.template .gitmessage`
5. 全局搜索 `TEMPLATE:`,按各处注释裁剪(AGENTS.md 技术栈与 Skill
   基线、.ai-workflow/review-standards.md 评审关注点、docs/ 骨架)
6. 安装栈 skills:项目内建的入库 `.agents/skills/` + skills-lock.json,
   每机自装的记入 AGENTS.md「Skill 基线」清单
7. 按需增删栈约定:可为你的栈新建 .claude/skills/rawf-stack-*
   (SKILL.md 写初始化、编码与测试约定);.github/workflows/ 为空目录,
   按需添加 CI。栈调整时同步 .ai-workflow/review-standards.md 的
   技术栈关注点
8. 生成应用骨架(若建了 stack skill,按其"初始化"一节执行),架构
   落入 docs/architecture/;其中 README.md 只做汇总和导航,细节下沉
   到同目录其他文件
9. 开 Claude Code 会话,/rawf-plan 开始第一个任务

## 存量项目迁移

把既有项目切到本模板时分层处理,顺序不可倒:

1. **迁知识层(逐条搬家,不可随文件替换丢弃)**:老 CLAUDE.md 里的
   已确认决策、硬约束、现状描述,先搬入 docs/architecture/ 与
   docs/decisions/;老项目已有 docs/ 的,模板骨架并入而非覆盖。
2. **换工作流层(可整体替换)**:拷入 .ai-workflow/、.claude/、
   .githooks/、.gitmessage,CLAUDE.md 换为模板版,AGENTS.md 按模板
   结构重写。重写时**剔除与当前项目无关的技术栈**,且三处联动删除:
   AGENTS.md 技术栈表、.ai-workflow/review-standards.md 对应的技术栈
   评审关注点、.claude/skills/rawf-stack-* 对应的栈 skill——残留的
   无关栈会误导评审与开发。退役旧的代理治理文档(如
   docs/agent-governance/)与旧 AGENTS.md 中的角色/流程章节;历史
   阶段产物(如 docs/phases/)原样保留。
3. **版本认领(基线对齐前不得写版本)**:既有(无版本记录的)项目
   必须先完成对 v1.0.0 的**全量基线对齐**——工作流层(可整体替换类)
   整体拷入 + 需人工合并类逐文件对照模板核对——之后才可在
   `.ai-workflow/TEMPLATE-VERSION` 写入 version 与 adopted;对齐完成
   前 version 一律记 `unknown`,升级继续走全量比较,**不得直接认领**
   v1.0.0(对照物取模板克隆的 v1.0.0 checkout,见「版本与升级」)。
4. **前置依赖**:jq、codex CLI(须支持 --output-schema 与 --json)、
   Linux 的 util-linux(flock、setsid)与 procps(pgrep;评审脚本的锁与
   看门狗依赖它们,缺失时明确报错退出),并执行「开新项目」第 4 步的
   两条 git config。
5. **提交规范衔接**:模板规范是 Conventional Commits 的超集,存量
   历史无需改写;此后新提交按 AGENTS.md 执行。

## 机制速览

- gate-plan.sh(PreToolUse):方案未获用户确认前,拦截源码与工作流
  控制文件的写入(仅 .ai/ 产物豁免)
- gate-review.sh(Stop):最新实现轮未经评审前,不许结束回合;评审进行中
  (当前任务的 .review-lock 被 flock 持有)则放行——评审后台运行,完成通知
  唤回 Claude,不原地等待
- review.sh:codex exec --output-schema 结构化评审;**评审只拦产品缺陷,结论
  由脚本推导**——评审者不自报 pass/fail,脚本先校验输出结构,再按问题的文件
  路径归类,把指向测试、任务记录、文档或写不出失败场景的问题降为建议,余下
  有 blocker/major 即 fail(docs/decisions/t0015);JSON 渲染为评审文件;同轮
  已有评审文件则拒绝重评(历史只增不改);codex 的 stdin 接 /dev/null,--json 事件流
  作进度信号,静默 15 分钟 / 总时长 60 分钟的看门狗按会话终止 codex 并
  exit 3(环境变量 RAWF_REVIEW_IDLE_SECONDS / RAWF_REVIEW_MAX_SECONDS 可调);
  互斥锁为 flock 文件,随进程退出自动释放(见 docs/decisions/t0009)
- 评审以只读沙箱直审原仓库(无副本,零复制开销;见 docs/decisions/t0005);
  评审者不运行任何测试,也不核证据(档位制见 docs/decisions/t0006):
  A 档证据由 evidence.sh 包住命令产出 rawf-evidence v1 文件(命令 + 完整
  输出 + 退出码),以 exit 0 表示用例通过;review.sh 启动前先跑
  evidence-check.sh 以 plan 用例表为基准机器核验——记录与用例逐条对应、
  结果为 pass、A 档证据完整且归属本用例且退出码为 0、B/C 档证据栏非空,
  不通过直接拒绝启动并开出补交清单(不消耗评审轮次);命令是否真的验证了
  用例、用例是否充分由开发侧自证(docs/decisions/t0010、t0015);完整性哈希
  (含未跟踪文件内容/类型/可执行位)保留为双保险,评审期间主工作区被动过
  即判评审无效
- 修复轮只审修复:review.sh 每轮保存所审改动的清单与内容快照,第 2 轮起
  生成轮间差异并注入指令;评审者先核验上一轮的阻断问题,再审本轮变化,
  与本轮变化无关的新发现只收 blocker、其余至多 minor
- plan 评审只拦设计错误,分轮进行:第 1 轮全量评审(设计层问题一次列全,
  调查按需),第 2 轮起核验评审(只核上一轮阻断问题与修订部分,未修订部分
  只有 plan-blocker 可阻断);验收与用例表方面的意见是建议,不阻断;脚本
  每轮快照 plan.md 并注入修订 diff,评审期间 plan.md 被改则本轮作废;默认
  上限 3 轮;major 按"留到实现阶段是否返工"判定,跨轮 minor 与建议由实现
  阶段经 `plan-review.sh __minors` 汇总交接(docs/decisions/t0012、t0015)
- 建议由开发 AI 处置:评审文件的「测试缺口」「建议」两节不计入 pass/fail、
  不触发修复轮,是否采纳由开发 AI 决定并留理由;收尾时经
  `review.sh __minors` 汇总全部轮次的 minor 与建议呈给用户
- 范围自省不量化、只提醒:plan 必填「需求原文」「非目标」,实现记录的偏差
  分收窄/替代/追加三类且追加须用户确认或入「停车场」,两级评审各有一个
  固定的范围核对问题,结论单列「范围核对」节、不计入 pass/fail,交用户裁决
  (docs/decisions/t0011)
- 严重度定义唯一权威在 .ai-workflow/review-standards.md;评审输出契约在
  .ai-workflow/schemas/review.schema.json 与 prompts/review.md 的字段语义
  说明(二者与 review.sh 解析/渲染逻辑绑定演化)

## 版本与升级

模板按 [SemVer](https://semver.org/lang/zh-CN/) 发版,版本语义按
**闸门兼容性**分级:

| 位 | 触发条件 |
|---|---|
| MAJOR | 闸门协议不兼容变更:hook 行为、评审 schema/产物命名、流程步骤 |
| MINOR | 向后兼容的新增能力:新标准栈、新 skill、新评审关注点 |
| PATCH | 向后兼容的缺陷修复(含脚本/hook 的 bug fix 与文案修正) |

**发布纪律**:发版提交须同步更新 CHANGELOG.md 与
`.ai-workflow/TEMPLATE-VERSION`,随后打 `v<版本>` tag 并创建同名
GitHub Release(notes 取 CHANGELOG 对应条目)。受管文件(AGENTS.md 等)
点名的参考仓,发版时须已推送到远端,且被引用的内容可在远端复核;不满足
的不点名。

**升级流程**(consumer 视角)。前提:consumer 经 Use this template
创建,git 历史与模板不同源,本地没有模板的 tag——增量一律在模板
仓库的单独克隆中读取;consumer 仓库**不添加模板 remote**、不 fetch
模板 tag,避免 tag 冲突。旧版本号取自项目内
`.ai-workflow/TEMPLATE-VERSION`:

```bash
OLD=1.0.0 NEW=1.1.0   # 按实际版本替换;OLD 取自项目内 TEMPLATE-VERSION
git clone https://github.com/senjianlu/ai-workflow-template /tmp/awt
cd /tmp/awt
git checkout --detach "v$NEW"   # 锚定 NEW 快照,diff/CHANGELOG/拷贝同源
git diff "v$OLD..v$NEW" -- .ai-workflow .claude/hooks \
  '.claude/skills/rawf-*' .claude/settings.json .githooks .gitmessage \
  'docs/decisions/t*' docs/decisions/README.md \
  CLAUDE.md AGENTS.md README.md .agents/skills skills-lock.json
```

随后三步:新版 CHANGELOG 的升级指引在该克隆中读取 → **可整体替换类**
(清单见 CHANGELOG 头部归类行)从克隆整目录拷入覆盖,
TEMPLATE-VERSION 随之更新 → **需人工合并类**按升级指引逐文件处理,
最后回 consumer 仓库更新 adopted。存量项目的基线认领规则见
「存量项目迁移」第 3 步。

## 已知限制

- hook 不拦 Bash 重定向写文件(纪律靠 CLAUDE.md 硬规则)
- plan 的 approved 状态由 Claude 在用户确认后翻转,存在理论上的
  误翻可能(approved_at 留有审计痕迹;可升级为仅人工翻转)
- 评审者不复跑测试、不核证据,也不评价测试是否充分:机器只确认用例留了证
  且退出码为 0,测试质量依赖开发侧纪律与用户抽查;若出现证据造假或测试
  空转的案例,可新增决策引入抽查机制(取舍见 docs/decisions/t0005、t0015)
