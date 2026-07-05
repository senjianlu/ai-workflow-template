---
task: workflow-hardening
round: 01
date: 2026-07-05
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/review-standards.md` | 新增:评审者手册(承接原 AGENTS.md 全文),角色约束加强为"不修改代码、不在工作区新建/改动文件(忽略产物除外)" |
| `AGENTS.md` | 重写为跨工具通用项目说明:技术栈、通用硬规则、指向 CLAUDE.md 与 review-standards.md 的指针;不再指派任何角色 |
| `CLAUDE.md` | 首行 `@AGENTS.md` 导入;技术栈与两条通用硬规则迁至 AGENTS.md;硬规则补"禁止 Bash 重定向/临时脚本绕过 gate-plan 写入闸" |
| `.ai-workflow/prompts/review.md` | 评审权威指向 review-standards.md(第 8 行说明 + 第 26 行输出契约两处) |
| `.ai-workflow/scripts/review.sh` | ① 同轮已有评审文件则拒绝重评(exit 3)② 完整性哈希改为 `workspace_hash()`:git diff HEAD + 未跟踪文件内容(--exclude-standard 排除忽略产物)③ codex exec 失败显式映射 exit 3,不再与 verdict fail 的 exit 1 混淆 |
| `.claude/hooks/gate-plan.sh` | 永远可写白名单由 `.ai/*\|.ai-workflow/*\|.claude/*` 收窄为仅 `.ai/*`;拦截提示语补"或工作流文件" |
| `README.md` | 开新项目步骤、机制速览中的 AGENTS.md 引用改为 review-standards.md;机制速览补重评拒绝与完整性校验说明;删除已修复的"完整性校验只覆盖已跟踪文件"已知限制 |

## 修复对照

不适用(首轮)。

## 测试结果

TC-02〜TC-10 由自测驱动脚本执行:临时 git 仓库 fixture(已提交 `src/app.py`/`.gitignore`/`.ai-workflow`,未跟踪 `src/new.py` 与任务产物)+ PATH 前置的假 codex stub(按 `STUB_MODE` 模拟 pass/fail/崩溃/三类篡改)。驱动脚本:scratchpad `rawf-tests/run-tests.sh`。首次运行发现 fixture 自身缺陷(`git add -q` 非法参数致初始提交未建立,TC-07 未真正覆盖已跟踪路径),修正 fixture 并加 `git rev-parse --verify HEAD` 断言后全量复跑,以下为修正后结果:

| 编号 | 结果 | 证据 |
|---|---|---|
| TC-01 | 通过 | `grep -rn "AGENTS" README.md CLAUDE.md AGENTS.md .ai-workflow .claude`:仅剩 README:26(技术栈裁剪指引)、AGENTS.md:5(自述)、CLAUDE.md:1(`@AGENTS.md`)、CLAUDE.md:18(指针)四处合法引用;`head -1 CLAUDE.md` = `@AGENTS.md`;review-standards.md 含四级严重度定义;`grep -n '你是\|只评审' AGENTS.md` 无输出(rc=1)。首跑曾暴露 review.md:26 输出契约残留"按 AGENTS.md 判定",已修复并复验 |
| TC-02 | 通过 | 驱动输出 `TC-02 PASS (rc=0 且生成 review-round-01-pass.md)` |
| TC-03 | 通过 | `TC-03 PASS (rc=1 且生成 review-round-01-fail.md)` |
| TC-04 | 通过 | stub 以退出码 1 崩溃 → `TC-04 PASS (rc=3,无评审文件,stderr 含'执行失败')` |
| TC-05 | 通过 | stub 篡改未跟踪 src/new.py → `TC-05 PASS (rc=3,未跟踪文件篡改被识别)` |
| TC-06 | 通过 | stub 新建未忽略 stray.txt → `TC-06 PASS (rc=3,新增杂物文件被识别)` |
| TC-07 | 通过 | stub 篡改已跟踪 src/app.py → `TC-07 PASS (rc=3,已跟踪文件篡改被识别)` |
| TC-08 | 通过 | `TC-08 PASS (首评 rc=0,重评 rc=3,旧文件字节级未变)`(cmp 字节比对) |
| TC-09 | 通过 | plan=draft 下 file_path 为 gate-plan.sh / review.sh / src/app.py 三者 → `TC-09 PASS (hooks/scripts/源码 三者均 rc=2 被拦)` |
| TC-10 | 通过 | `TC-10 PASS (draft 写 .ai/、approved 写控制文件、无任务 三者均放行)` |

另:`bash -n` 语法检查 review.sh 与 gate-plan.sh 均通过;review.md 修复后全套 9 项 fixture 用例复跑仍 9/9 通过。

## 与方案的偏差

- review.md 存在方案实现细则未逐条列出的第二处 AGENTS.md 引用(第 26 行输出格式契约内),由 TC-01 检出,按方案第 1 项意图一并修正;改动文件仍在方案"改动范围"清单内,无范围外改动。
- 其余无偏差。
