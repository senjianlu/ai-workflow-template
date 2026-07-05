---
status: approved
task: absorb-conventions
date: 2026-07-05
approved_at: 2026-07-05 19:53
---

# 方案:吸收三个真实项目的工程化约定(docs 树/Skill 基线/可执行提交规范)

## 背景与目标

对照 senjianlu/dopilot、senjianlu/cscheap-api、cscheap-frontend 三个真实
项目的审计发现,模板缺三类它们不约而同长出来的工程化资产。本任务吸收
其中用户选定的三项,并回答"模板能否取代存量项目全部约束"——以 README
迁移清单的形式落地:

1. **docs/ 持久文档树**:.ai/ 只是过程痕迹,持久设计真相(架构/决策)
   在模板中没有家;三个项目均收敛到 docs/architecture + decisions 形态,
   且有"决策变更须回写文档"纪律。
2. **Skill 基线约定**:三个项目均采用 `.agents/skills/` 随仓库提交 +
   `skills-lock.json` 内容哈希锁定,cscheap-api 的 AGENTS.md 另有
   「Skill Baseline」小节区分项目内建与每机自装。
3. **可执行提交规范**:dopilot 有 `.gitmessage` 模板 + `.githooks/commit-msg`
   零依赖钩子强制 Conventional Commits(11 类型、可选 scope、≤72 字符、
   footer 约定),比模板现有纸面规范(6 类型、无强制)更全,且与存量
   项目提交历史一致。

## 改动范围

新增:

| 文件 | 内容 |
|---|---|
| `docs/README.md` | docs/ 与 .ai/ 的分工(持久真相 vs 过程痕迹)、组织约定、回写纪律 |
| `docs/architecture.md` | TEMPLATE 占位骨架(系统形态/组件/数据/部署小节) |
| `docs/decisions/README.md` | 决策记录约定:`NNNN-<slug>.md` 轻量 ADR(背景/决定/理由/影响) |
| `.gitmessage` | 提交信息模板(类型/格式提示,spec 指向 AGENTS.md) |
| `.githooks/commit-msg` | 零依赖 POSIX sh 钩子,改编自 dopilot(校验 header 格式/长度/句号,放行 Merge/Revert/fixup!/squash!) |

修改:

| 文件 | 改动 |
|---|---|
| `AGENTS.md` | ①硬规则补一行 docs/ 与 .ai/ 分工;②「Git 提交规范」重写:11 类型、可选 scope、≤72、footer 约定,**rawf 标记从摘要内后缀改为 footer `Rawf: <yyyy-mm-dd>/<task-slug>`**;③新增「Skill 基线」节(TEMPLATE):项目内建 `.agents/skills/` + `skills-lock.json`,每机自装清单占位,新机初始化提示 |
| `CLAUDE.md` | 硬规则补一行:任务改变架构/关键决策时,收尾前同步 docs/(见 rawf-report) |
| `.claude/skills/rawf-report/SKILL.md` | ①汇报步骤前加检查:本任务是否改变架构/决策,是则同步 docs/ 并纳入同一提交;②提交信息格式改为 header + `Rawf:` footer |
| `README.md` | ①「开新项目」步骤补:安装栈 skills(项目内建入库或全局)、`git config core.hooksPath .githooks`、架构写入 docs/;②新增「存量项目迁移」节(见实现方案 4) |

操作(非文件):本仓库执行 `git config core.hooksPath .githooks`(仅本
克隆生效)。

明确不动:`.ai-workflow/scripts/review.sh`、两个 gate hooks、评审
schema/prompt、`.ai/` 历史产物;模板自身不新建 `.agents/`(约定文本,
不 vendor skill)。

## 实现方案

1. **docs/ 树**:三个新文件按上表落地。README.md 写清分工边界——
   docs/ 存"现在为什么是这样"(架构、已确认决策),.ai/ 存"当时怎么
   做的"(方案/实现/评审轮次);决策变更的回写时机 = rawf-report 收尾
   前,与代码同一提交。architecture.md 全 TEMPLATE 注释占位,不预设
   内容。
2. **Skill 基线**:AGENTS.md 新节采用 cscheap-api 的二分法:项目内建
   (`.agents/skills/` + `skills-lock.json`,随仓库走)/每机自装(全局
   安装,列清单 + "新机器先装再开工"提示);TEMPLATE 注释引导按项目
   填表。README 开新项目步骤同步一行。
3. **提交规范**:`.githooks/commit-msg` 以 dopilot 版为蓝本,仅改 spec
   指向(AGENTS.md「Git 提交规范」);`.gitmessage` 同源改编,scope 示例
   给通用占位。AGENTS.md 规范重写要点:类型 11 个(补 perf/build/ci/
   style/revert)、scope 可选小写、祈使句、≤72 字符、不以句号结尾、
   footer 承载 `Co-Authored-By:`/`Refs:`/`Rawf:`/`BREAKING CHANGE:`(或
   type 后 `!`)。**兼容性**:钩子只校验 header,历史提交(含今天
   in-subject rawf 后缀式)不受影响;存量项目已是 Conventional Commits,
   新规范为其超集。
4. **README「存量项目迁移」节**,直接回答"能否取代存量约束":
   - 可整体替换的=工作流层:拷入 .ai-workflow/、.claude/(hooks+skills
     +settings)、.githooks/、.gitmessage、docs/ 骨架(并入既有 docs/),
     CLAUDE.md 换成模板工作流版,AGENTS.md 重写为事实型(技术栈表按该
     项目裁剪);退役 docs/agent-governance/ 与旧 AGENTS.md 的 Codex
     角色/治理节;docs/phases/ 历史保留不动。
   - 不可替换、只能迁移的=知识层:老 CLAUDE.md 里的已确认决策、硬
     约束、现状,逐条搬入 docs/architecture.md 与 docs/decisions/,
     **绝不随文件替换而丢弃**。
   - 前置依赖:jq、codex CLI(支持 --output-schema)、
     `git config core.hooksPath .githooks`。
5. 自测按下表执行;钩子测试在临时目录建一次性 git 仓库,不污染本仓库。

## 测试用例

| 编号 | 前置条件 | 步骤 | 预期结果 |
|---|---|---|---|
| TC-01 | 钩子文件就位 | `printf 'feat(server): add x' > m; .githooks/commit-msg m` | exit 0 |
| TC-02 | 同上 | 完整消息:中文 header `docs: 吸收工程化约定` + 空行 + 正文 + `Rawf: 2026-07-05/absorb-conventions` footer,跑钩子 | exit 0 |
| TC-03 | 同上 | header 为 `update stuff`(无 type 前缀) | exit 1,stderr 含期望格式与类型清单(异常路径) |
| TC-04 | 同上 | header 74 字符(>72) | exit 1,提示超长(异常路径) |
| TC-05 | 同上 | ①subject 以句号结尾;②`feat(BadScope): x`(scope 含大写) | 均 exit 1(异常路径) |
| TC-06 | 同上 | header 为 `Merge branch 'x'`、`fixup! foo` 各一次 | 均 exit 0(机器生成消息放行) |
| TC-07 | 同上 | 消息文件仅含注释与空行(header 为空) | exit 1(边界:空消息拒绝) |
| TC-08 | 临时 git 仓库,`core.hooksPath` 指向模板 .githooks | ①`git commit -m 'bad message'`;②`git commit -m 'chore: 初始化'` | ①提交被拒非零退出;②提交成功(端到端生效验证) |
| TC-09 | — | `sh -n .githooks/commit-msg`;`bash -n` 同 | 语法零错误 |
| TC-10 | 全部文件落地 | 自洽性 grep:README/AGENTS.md/CLAUDE.md/rawf-report SKILL.md 中引用的路径(docs/README.md、.gitmessage、.githooks/commit-msg 等)均存在;AGENTS.md 无"摘要后附 (rawf:"旧规则残留;rawf-report 含 `Rawf:` footer 与 docs 同步步骤 | 全部命中/零残留 |

## 风险与回滚

- **钩子须手动激活**:`core.hooksPath` 是本地 git 配置,克隆后不自动
  生效。接受此代价(不做安装魔法,低维护),README 步骤与 .gitmessage
  头部注释双处写明。
- **钩子同样约束 AI 提交**:Claude 经 Bash 提交也过钩子——预期行为,
  双向兜底。
- **规范变更的衔接**:rawf 标记移至 footer 后,今天已有的 5 个
  in-subject 后缀式历史提交不改(历史只增不改);钩子对其 header 依然
  放行,无追溯冲突。
- **docs/ 占位空置风险**:若新项目长期不填,docs/ 名不副实;靠 README
  引导 + rawf-report 回写检查步骤缓解,不加硬闸。
- **迁移清单是操作指引而非脚本**:知识层迁移是编辑工作,按清单人工
  执行;清单本身不保证老项目零改动可用。
- 回滚:整任务为新增文件 + 三处文档/skill 编辑,`git revert` 单提交
  即可整体回退;`core.hooksPath` 用 `git config --unset` 解除。
