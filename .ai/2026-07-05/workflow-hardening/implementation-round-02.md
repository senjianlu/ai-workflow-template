---
task: workflow-hardening
round: 02
date: 2026-07-05
---

# 实现记录:第 02 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `.claude/hooks/gate-plan.sh` | `.ai/` 豁免改为物理路径判定:统一为绝对路径后,对最近已存在祖先目录 `pwd -P` 并要求位于 `<proj>/.ai/` 之下;目标已存在且为符号链接的不走豁免。挡住 `.ai/../` 穿越与符号链接(目录/文件)逃逸 |
| `.ai-workflow/scripts/review.sh` | ① 完整性哈希不再用 `--exclude-standard`,改为显式产物排除清单(`.review-raw-*`、`__pycache__`、`*.pyc`、`.pytest_cache`、`.venv`、`node_modules`、`dist`、`.next`、`.DS_Store`,含 TEMPLATE 注释),`.env` 等被忽略文件的篡改从此可被发现 ② codex 退出码先暂存,完整性复核在所有退出路径上先于失败映射执行,篡改后崩溃不再漏报 |
| `.claude/settings.json` | `git checkout` 恢复至 HEAD 版本(未提交改动整体丢弃) |

## 修复对照

| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| R-01 | blocker | gate-plan.sh 重写 `.ai/` 豁免判定:`in_ai_dir()` 以物理路径(最近存在祖先目录的 `pwd -P`)校验归属,拒绝符号链接目标。新增 TC-11(`.ai/../` 穿越)、TC-12(目录/文件符号链接逃逸)验证 |
| R-02 | major | 完整性哈希改为"未跟踪文件全量纳入,仅排除显式产物清单";新增 TC-13(篡改被忽略的 `.env` 被识别)、TC-15(合法测试产物不误伤)验证 |
| R-03 | major | `codex_rc` 暂存 + 复核前置:先比对 pre/post 哈希再映射执行失败;新增 TC-14(篡改后崩溃仍报"改动了工作区"且不生成评审文件)验证 |
| R-04 | major | `git checkout -- .claude/settings.json` 恢复;`git diff HEAD -- .claude/settings.json` 为空。成因说明:该 diff 来自本会话权限系统对"始终允许"授权的自动写入,非实现改动,故第 01 轮记录未披露;本轮起恢复并在收尾汇报中向用户提示(个人授权应留在不入库的 settings.local.json) |

## 测试结果

驱动脚本同第 01 轮(scratchpad `rawf-tests/run-tests.sh`),fixture 增加已提交的 `.gitignore` 条目 `.env` 与未跟踪的 `.env` 文件,stub codex 增加 `tamper-ignored`/`crash-tamper`/`produce` 三种行为;新增 TC-11〜TC-15,全量复跑:

| 编号 | 结果 | 证据 |
|---|---|---|
| TC-02〜TC-10 | 通过(回归) | 驱动输出 `TC-02..TC-10 PASS`,判定条件与第 01 轮一致 |
| TC-11 | 通过 | draft 下 file_path=`.ai/../.claude/hooks/gate-plan.sh` 与 `.ai/../src/app.py` → `TC-11 PASS (.ai/../ 穿越写闸门与源码均 rc=2 被拦)`(修复前实测 rc=0,即 R-01 的复现) |
| TC-12 | 通过 | `ln -s $FX/src $FX/.ai/lnk` 后写 `.ai/lnk/app.py`,及 `.ai/2026-07-05/x/evil.md -> src/app.py` 符号链接文件 → `TC-12 PASS (目录符号链接与文件符号链接逃逸均 rc=2 被拦)` |
| TC-13 | 通过 | stub 追加写被忽略的 `.env` → `TC-13 PASS (rc=3,被忽略文件 .env 的篡改被识别)`(修复前该篡改不可见,即 R-02 的复现) |
| TC-14 | 通过 | stub 先改 `src/new.py` 再以退出码 1 崩溃 → `TC-14 PASS (rc=3,codex 崩溃前的篡改仍被报告)`,stderr 为"改动了工作区"而非仅"执行失败"(R-03 复现) |
| TC-15 | 通过 | stub 生成 `__pycache__/a.pyc`、`.pytest_cache/z` → `TC-15 PASS (rc=0,产物不触发误判)` |
| 语法检查 | 通过 | `bash -n` review.sh 与 gate-plan.sh 均无输出 |
| R-04 复核 | 通过 | `git diff HEAD -- .claude/settings.json` 为空;`git status --porcelain` 不再含 settings.json |

合计 14/14 通过。

## 与方案的偏差

- 本轮为评审修复轮,改动严格限于 R-01〜R-04,无评审范围外的重构。
- gate-plan.sh 的 `.ai/` 豁免实现方式(物理路径判定)超出原 plan 第 7 项的字面描述(仅收窄白名单),属 R-01 修复的必要延伸,符合评审"规范化并校验目标路径确实位于 .ai/ 内"的修复建议。
- review.sh 的哈希排除机制由"跟随 .gitignore"改为"显式产物清单",与原 plan 第 5 项的字面描述(`--exclude-standard`)不同,属 R-02 修复的直接要求。
