---
status: approved
task: workflow-hardening
date: 2026-07-05
approved_at: 2026-07-05 15:12:00
---

# 方案:工作流加固(评审发现第 1、4、5、6、7 项)

## 背景与目标

2026-07-05 对本模板做了一次"对照 2026 年中最佳实践"的全面评审,确认修复其中五项:

1. **AGENTS.md 角色冲突**:AGENTS.md 现为 Linux Foundation 托管的跨工具开放标准(30+ 工具原生读取),语义是"给任何进入仓库的 agent 的项目说明"。本仓库将其写成"你是评审者,只评审不改代码",依赖"Claude Code 恰好不读、Codex 恰好读"这一工具差,存在被其它工具误读、及 Claude Code 未来原生支持后自爆的风险。
4. **review.sh 退出码歧义**:`codex exec` 因登录过期/额度/网络以退出码 1 失败时,`set -e` 使脚本以 1 退出,被 rawf-review skill 误读为"评审结论 fail",而此时评审文件根本未生成。
5. **完整性校验盲区**:`git diff HEAD` 不含未跟踪文件,而提交前整个任务目录(plan.md、implementation-round)和新增源文件全是未跟踪的——评审者(workspace-write 沙箱)可篡改它们而不被发现。
6. **同轮重评覆盖**:review.sh 对同一轮可重复执行,可能产生 `review-round-NN-pass.md` 与 `review-round-NN-fail.md` 并存,违反".ai/ 历史只增不改",且使 gate-review.sh 的存在性判断歧义。
7. **闸门自我修改豁口**:gate-plan.sh 将 `.claude/*`、`.ai-workflow/*` 设为永远可写,plan 未批时闸门脚本、评审 prompt、review.sh 自身均可被改写;对爬虫项目,这是 prompt injection 的现实攻击面。

## 改动范围

| 文件 | 动作 |
|---|---|
| `.ai-workflow/review-standards.md` | 新增:评审者手册(原 AGENTS.md 全部内容+角色约束加强) |
| `AGENTS.md` | 重写:改为跨工具通用项目说明(技术栈、通用硬规则、指针) |
| `CLAUDE.md` | 首行 `@AGENTS.md` 导入;移除与 AGENTS.md 重复的内容;硬规则补"禁止 Bash 绕过写入闸" |
| `.ai-workflow/prompts/review.md` | 评审标准权威指向 review-standards.md |
| `.ai-workflow/scripts/review.sh` | 第 4/5/6 项三处修复 |
| `.claude/hooks/gate-plan.sh` | 永远可写白名单收窄为仅 `.ai/*` |
| `README.md` | 同步机制速览、已知限制、开新项目步骤中的引用 |

**明确不动**:五个 `.claude/skills/*/SKILL.md`、`.ai-workflow/templates/*`、`gate-review.sh`、`.claude/settings.json`、评审输出 VERDICT 末行契约(属评审发现第 2 项,本次不做)、hook 的 exit 2 拒绝方式(第 3 项,本次不做)。

## 实现方案

### 第 1 项:评审手册迁出 AGENTS.md

- 新建 `.ai-workflow/review-standards.md`:承接原 AGENTS.md 全部内容(评审输入、严重度定义、判定规则、技术栈关注点及其 TEMPLATE 注释);角色约束加强为"只评审,不修改任何代码,也不在工作区新建/改动任何文件(测试运行产生的、已被 .gitignore 忽略的产物除外)"——与第 5 项校验收紧配套。
- `AGENTS.md` 重写为通用项目说明:技术栈(自 CLAUDE.md 迁入)、对任何 AI 工具生效的通用硬规则(永不主动 commit/push;`.ai/` 产物只增不改)、两个指针(开发流程细则见 CLAUDE.md;评审标准见 .ai-workflow/review-standards.md)。保留 TEMPLATE 裁剪注释。
- `CLAUDE.md`:首行改为 `@AGENTS.md`(Claude Code 官方 import 语法,单一事实源);删除迁入 AGENTS.md 的技术栈与两条通用硬规则;保留工作流(强制)章节与 Claude 专属硬规则。
- `.ai-workflow/prompts/review.md`:"以仓库根目录 AGENTS.md 为唯一权威"改为"以 `.ai-workflow/review-standards.md` 为唯一权威,评审前先完整阅读该文件"。
- `README.md`:第 27 行裁剪指引、第 38-39 行权威来源说明同步改为 review-standards.md;第 26 行 CLAUDE.md 技术栈改为 AGENTS.md 技术栈。

### 第 4 项:codex 执行失败显式映射为 exit 3

review.sh 的 `codex exec` 调用追加失败分支:

```bash
codex exec --sandbox workspace-write -C "$proj" \
  --output-last-message "$raw" "$prompt" || {
  rc=$?
  echo "codex exec 执行失败(退出码 $rc),评审未完成;检查 codex login/额度/网络后重跑" >&2
  exit 3
}
```

退出码契约保持:0=pass,1=fail(且必有评审文件),3=执行异常。

### 第 5 项:完整性哈希纳入未跟踪文件

review.sh 中 `pre_hash`/`post_hash` 的计算替换为函数:

```bash
workspace_hash() {
  {
    git diff HEAD
    git ls-files --others --exclude-standard -z \
      | while IFS= read -r -d '' f; do shasum "$f"; done
  } | shasum | cut -d' ' -f1
}
```

- 覆盖:未跟踪文件的内容篡改、新增、删除均改变哈希。
- 不误伤:`.review-raw-*.md` 与测试产物(`.pytest_cache/` 等)已在 .gitignore,被 `--exclude-standard` 排除,评审自身不会触发失配。
- 用 while-read 而非 xargs,规避 BSD/GNU xargs 对空输入行为差异。
- README"已知限制"中"评审完整性校验只覆盖已跟踪文件"一条删除。

### 第 6 项:拒绝同轮重评

review.sh 在计算出 `nn` 后、构建 prompt 前插入:

```bash
if ls "$task_dir"/review-round-"$nn"-*.md >/dev/null 2>&1; then
  echo "第 $nn 轮已有评审文件,按'历史只增不改'拒绝重评;确需重评请用户手动处置旧文件后重跑" >&2
  exit 3
fi
```

### 第 7 项:闸门文件纳入 plan 闸保护

gate-plan.sh 白名单由 `.ai/*|.ai-workflow/*|.claude/*` 收窄为仅 `.ai/*`;`.claude/`、`.ai-workflow/` 下所有文件与源码同样受 plan 确认闸约束。拦截提示语相应加"或工作流文件"字样。

- 不会锁死流程:rawf-plan 阶段写入的 plan.md、.current-task 均在 `.ai/` 下;plan approved 后(如本任务)控制文件可正常修改;无进行中任务时(模板裁剪场景)hook 本就直接放行。
- CLAUDE.md 硬规则补充一条:"禁止用 Bash 重定向、临时脚本等方式绕过 gate-plan 写入闸"(README 第 43 行早已声称此纪律在 CLAUDE.md,实际缺失,本次补齐)。

## 测试用例

review.sh 相关用例统一使用 fixture:在 scratchpad 建临时 git 仓库(含已提交文件 `src/app.py`、未跟踪新文件 `src/new.py`、`.ai/.current-task`、任务目录含 plan.md 与 implementation-round-01.md、与本仓库相同的 .gitignore 关键条目),并将 stub `codex` 脚本置于 PATH 前部模拟各类行为;gate-plan.sh 用例通过管道喂 hook JSON 并设 `CLAUDE_PROJECT_DIR` 指向 fixture。

| 编号 | 前置条件 | 步骤 | 预期结果 |
|---|---|---|---|
| TC-01 | 全部文件改动完成 | `grep -rn "AGENTS" README.md CLAUDE.md AGENTS.md .ai-workflow/ .claude/` 并检查 CLAUDE.md 首行、review-standards.md 存在性 | 评审权威唯一指向 review-standards.md;AGENTS.md 不再含评审者角色指令;CLAUDE.md 首行为 `@AGENTS.md`;review-standards.md 含四级严重度定义 |
| TC-02 | fixture;stub codex 写出含 `VERDICT: pass` 的输出文件,不动工作区 | `bash review.sh; echo $?` | 退出码 0;生成 `review-round-01-pass.md`;stdout 报文件名 |
| TC-03 | fixture;stub codex 输出 `VERDICT: fail` | 同上 | 退出码 1;生成 `review-round-01-fail.md` |
| TC-04 | fixture;stub codex 直接以退出码 1 失败、不写输出文件 | 同上 | 退出码 **3**(而非 1);无 review-round 文件生成;stderr 含"执行失败" |
| TC-05 | fixture;stub codex 篡改**未跟踪**文件(改 `src/new.py` 内容,模拟改 plan.md) | 同上 | 退出码 3;stderr 报评审无效;不生成 review-round 文件 |
| TC-06 | fixture;stub codex 新建一个未被 .gitignore 忽略的新文件 | 同上 | 退出码 3,评审无效 |
| TC-07 | fixture;stub codex 修改**已跟踪**文件 `src/app.py` | 同上 | 退出码 3,评审无效(既有行为回归) |
| TC-08 | fixture;任务目录已存在 `review-round-01-pass.md`;stub codex 正常 | 同上 | 退出码 3;拒绝重评;旧文件内容未被覆盖 |
| TC-09 | fixture;plan `status: draft` | 依次以 file_path=`.claude/hooks/gate-plan.sh`、`.ai-workflow/scripts/review.sh`、`src/app.py` 喂 gate-plan.sh | 三者均退出码 2 被拦截(前两者为本次新增覆盖) |
| TC-10 | fixture | 依次验证:draft 时 file_path=`.ai/2026-07-05/x/plan.md` → 0;改 approved 后 file_path=`.ai-workflow/scripts/review.sh` → 0;删除 .current-task 后任意路径 → 0 | 三种放行场景均退出码 0,流程不被锁死 |

## 风险与回滚

- **gate 收窄的误拦风险**:`.claude/`、`.ai-workflow/` 在有未批 plan 时不可写,若用户此时确需 Claude 改这些文件,需先批 plan 或删 .current-task(拦截信息会说明)。TC-10 保证三种合法场景不受影响。
- **完整性校验变严的误判风险**:评审者跑测试若产生未被 .gitignore 覆盖的产物会判评审无效(exit 3,可重跑)。已在 review-standards.md 明示"不留新文件",且常见产物已被忽略;若实际项目频繁误判,放宽点在 workspace_hash 单处。
- **`@AGENTS.md` 导入依赖 Claude Code 行为**:import 语法为官方文档特性;若极旧版本不支持,表现为 Claude 缺技术栈上下文,不影响闸门与评审。
- **回滚**:全部改动一次 commit,`git revert` 即可整体回滚;无状态迁移、无数据变更。
