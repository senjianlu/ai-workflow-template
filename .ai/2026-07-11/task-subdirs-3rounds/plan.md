---
status: approved
task: task-subdirs-3rounds
date: 2026-07-11
approved_at: 2026-07-11 19:56:05 +0800
---

# 方案:plan 评审轮次上限 2→3;任务目录增设 evidence/ 与 assets/ 子目录

## 背景与目标

三项工作流规范调整,合并为一个任务:

1. **plan 评审轮次上限 2→3**:`plan-review.sh` 目前在已有 2 轮 plan 评审后
   强制转人工(`-ge 2`)。放宽到 3 轮,给 plan 层面的分歧多一次自动收敛机会。
2. **每个任务目录增设两个固定子目录**:
   - `evidence/` — 证据:测试输出、截图、验证记录(implement 阶段产出)
   - `assets/` — 资源:Design 稿、参考图、外部素材(plan / implement 阶段引用)

   给过程产物一个约定的落点,而非散落在任务目录根或临时路径。两者均随任务
   一起入库(与 `.ai/` 作为「随任务提交的过程痕迹」一致)。
3. **CLAUDE.md 新增简体中文沟通硬规则**:
   - **需求来源**:用户明确要求「再在 CLAUDE.md 中加一条强制要求,与用户的
     沟通使用简体中文」。
   - **适用范围**:仅约束 Claude Code 面向用户的自然语言沟通语言(对话、
     摘要、汇报);不改变代码、标识符、注释或既有产物的语言,不涉及其它工具。
   - **依据**:本仓库是中文优先的工作流模板(CLAUDE.md / AGENTS.md / skills
     均为简体中文),把沟通语言固化为硬规则与既有基调一致。
   - **落点**:CLAUDE.md「## 硬规则」区,作为一条与工作流并列的通用纪律。

## 改动范围

「2 轮」是**同一语义在 5 处的副本**,必须同步;唯一的逻辑闸在 plan-review.sh,
其余四处是文字。子目录约定是新增,无逻辑闸配合(gate 与指纹均无需改)。

涉及文件(共 8,≤10,**不触发 plan 阶段 Codex 评审闸**):

| 文件 | 改动 |
|---|---|
| `.ai-workflow/scripts/plan-review.sh` | L71/76/77:`-ge 2`→`-ge 3`;注释与 stderr「2 轮上限」→「3 轮上限」(**唯一逻辑改动**) |
| `.claude/skills/rawf-plan/SKILL.md` | ① round 文字「最多 2 轮 / 2 轮上限」→ 3;② 第 2 步建任务目录时,一并 `mkdir` `evidence/` `assets/` 并各放 `.gitkeep` |
| `.claude/skills/rawf-implement/SKILL.md` | 增一句:验证证据落 `evidence/`,引用素材放 `assets/`;两者须在**评审前**落盘(评审期间写 `.ai/` 会污染指纹) |
| `CLAUDE.md` | ① L11、L25「最多 2 轮」→「最多 3 轮」;② 硬规则区新增一条:与用户沟通一律用简体中文 |
| `AGENTS.md` | ① L168「最多 2 轮」→ 3;② 目录约定表 `.ai/` 行补注两个子目录的用途 |
| `docs/decisions/0001-plan-stage-review.md` | L8 数字 2→3 + 底部追加带日期(2026-07-11)的修订说明,记录放宽动机,不静默改历史 |
| `docs/decisions/0002-task-evidence-assets-dirs.md`(**新增**) | 记录 evidence/ + assets/ 子目录约定与「均入库」决定 |
| `.ai-workflow/templates/plan.md` | 末尾补一行指引:证据/资源分别归 `evidence/`、`assets/` |

**明确不动**:
- `gate-plan.sh` — 已对 `.ai/` 下所有路径无条件放行([gate-plan.sh:39](../../../.claude/hooks/gate-plan.sh)),新子目录自动覆盖。
- `review.sh` 指纹逻辑 — `.ai/` 仍计入指纹,证据在 implement 阶段(评审前)落盘即安全;此约束靠 rawf-implement 文字与既有硬规则保证,不改脚本。
- `.ai/.gitignore` — 两目录均入库,不新增忽略项。

## 实现方案

1. **plan-review.sh 轮次闸**:改 `if [ "$count" -ge 2 ]` 为 `-ge 3`;同步注释
   「2 轮机器上限」「count>=2」与 stderr「已达 2 轮上限」中的数字。逻辑其余不动
   (nn 计算 `count+1` 天然适配)。
2. **五处 round 文字**同步为「3 轮」,保证全仓一致(grep 校验无残留「2 轮」指向 plan 闸)。
3. **子目录约定**:
   - rawf-plan SKILL 第 2 步:创建任务目录后 `mkdir -p <dir>/evidence <dir>/assets`,
     各 `touch .gitkeep`(空目录入库需占位)。
   - AGENTS.md 目录表 `.ai/` 行补注;plan 模板补指引;rawf-implement 补落点说明。
   - rawf-report 无需改:第 6 步 `git add` 本任务目录已整体覆盖两子目录。
4. **决策记录**:0001 追加修订说明(2→3);新增 0002 记录子目录约定。
5. **简体中文沟通硬规则**:在 CLAUDE.md「## 硬规则」区新增一条 bullet
   ——「与用户沟通一律使用简体中文」。

## 测试用例

| 编号 | 前置条件 | 步骤 | 预期结果 |
|---|---|---|---|
| TC-01 | plan-review.sh 已改为 `-ge 3` | 静态核对:`grep -n 'ge 3' plan-review.sh` 命中轮次闸;`grep -rn '2 轮' .ai-workflow .claude docs CLAUDE.md AGENTS.md` 无指向 plan 评审的残留 | 轮次闸为 `-ge 3`;无「2 轮」残留(implementation-round 模板里描述实现轮的「第 2 轮」不算,属另一语义) |
| TC-02 | 干净任务目录 | 执行 rawf-plan 第 2 步的建目录逻辑 | 生成 `evidence/.gitkeep` 与 `assets/.gitkeep`;`git status` 显示两者可被 add(未被 .gitignore 吞) |
| TC-03(边界/异常) | 隔离临时工作区(`CLAUDE_PROJECT_DIR=$TMP`,内含 `.ai-workflow/{schemas,prompts}` 拷贝、`.ai/.current-task` 指向测试任务目录、其内 plan.md + **3** 个 `plan-review-round-0{1,2,3}-*.md`);PATH 首位放**假 codex 桩**(被调用即 `touch $TMP/.codex-called` 并向 `--output-last-message` 写合法 pass JSON) | 运行 `plan-review.sh` | 打印「已达 3 轮上限…交人工」,exit 3;`$TMP/.codex-called` **不存在**(证明 codex 未被调用、未进入第 4 轮) |
| TC-04(边界/放行) | 同 TC-03,但仅 **2** 个既有 round 文件 | 运行 `plan-review.sh` | **不**打印「3 轮上限」;`$TMP/.codex-called` **存在**(codex 被调用一次=第 3 轮放行);产出 `plan-review-round-03-pass.md` |
| TC-05 | gate-plan hook 生效、无 approved plan | 向 `.ai/<task>/evidence/x.log` 写入 | hook 放行(`.ai/` 分支),不被 plan 状态闸拦截 |
| TC-06 | CLAUDE.md 已改 | `grep -n '简体中文' CLAUDE.md` | 硬规则区命中一条「与用户沟通一律使用简体中文」 |

## 风险与回滚

- **风险**:轮次数字散落 5 处,漏改一处会导致文档与脚本不一致。用 grep 全仓校验兜底(TC-01)。
- **风险**:空目录 `.gitkeep` 若被误清理则约定形同虚设;靠 rawf-plan 每次建目录时重建。
- **风险**:证据/资源含大二进制入库会膨胀 git 历史;本任务按用户决定「均入库」,
  后续若膨胀明显可另开任务改为 evidence gitignore(0002 决策里记为残留风险)。
- **回滚**:纯文本 + 一处脚本条件改动,`git revert` 单次提交即可全部回退。
