---
status: approved
task: patch-ampersand-shellcheck
date: 2026-10-22
approved_at: 2026-10-22 12:08:37
evidence_format: v1
---

# 方案:review.sh 证据报告注入的 `&` 改写修复 + shellcheck 既有提示清零(1.2.1)

## 需求原文

> 停车场的 2 条你准备怎么改?
> 确认,但是 plan 依旧需要过 review。

上一任务停车场的两条:
1. review.sh 注入证据报告时受 bash 5.2 `patsub_replacement` 影响
2. shellcheck warning/note 级的既有条目

对齐结论(上一条回复中提出、用户确认):第 1 条在 review.sh 占位替换前关闭
`patsub_replacement`;第 2 条按条目逐一消除,验收收紧为 shellcheck 全级别零条;
合并为一个 PATCH(1.2.1);本 plan 虽 ≤ 10 文件,按用户要求仍过 plan 评审。

**本任务交付**:review.sh 注入给评审者的证据报告与 evidence-check 原始输出逐字
一致;流程脚本 shellcheck 全级别零条;三个脚本对外行为不变。

## 调研结论

- review.sh:224 `prompt="${prompt//\{\{EVIDENCE_REPORT\}\}/$ev_report}"` 在 bash 5.2
  默认开启 `patsub_replacement` 时,替换文本中的 `&` 被改写为匹配原文、`\&` 丢反斜杠。
  实测影响两处:① B/C 档证据格原文带 `&`(evidence-check.sh:169 原样写入报告)→
  注入后变成 `{{EVIDENCE_REPORT}}` 字样;② A 档 cmd 列(`%q` 转义的 `\&`)丢反斜杠。
  A 档机器核验结论(OK / exit)不受影响;评审者也直接读实现记录,未造成误判,但注入
  的报告内容错误。上一任务停车场把它记为"仅显示",低估了①。
- shellcheck 0.11.0 默认级别对 `.ai-workflow/scripts/*.sh`、`.claude/hooks/*.sh`、
  `.githooks/*` 共 5 条,均为误报或无害:
  - review.sh:93、plan-review.sh:149 `lock_holders` 的 `local … target …` 未使用(SC2034)
  - review.sh:244、plan-review.sh:341 主流程 `for i in $(seq 1 20)` 的 `i` 未使用(SC2034)
  - evidence.sh:79 `on_sig` 经 trap 字符串调用,被误报为从未调用(SC2329)
- 回归基线:前两个任务的行为断言脚本(scope-guard-and-evidence-format 的 tc-01~11、
  tc-16~19,plan-review-convergence 的 tc-01~06、tc-10、tc-12,共 23 个)在当前代码上
  全部通过(耗时约 46 s)。

## 改动范围

| 文件 | 改动 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 占位替换前 `shopt -u patsub_replacement 2>/dev/null \|\| true`(附注释,同 plan-review.sh);`lock_holders` 删去未用的 `target`;主流程 `for i` → `for _` |
| `.ai-workflow/scripts/plan-review.sh` | `lock_holders` 删去未用的 `target`;主流程 `for i` → `for _` |
| `.ai-workflow/scripts/evidence.sh` | `on_sig` 前加 `# shellcheck disable=SC2329` 及原因注释 |
| `CHANGELOG.md`、`.ai-workflow/TEMPLATE-VERSION` | 1.2.1 |

共 5 个文件。不动:evidence-check.sh(报告内容本身正确,问题只在注入)、prompts、
schemas、hooks、settings.json、docs(无决策变化)、其它任何仓库。

## 非目标

- 把 shellcheck 接入 `.github/workflows`(新增能力,另议)
- 把 shellcheck 列为模板运行依赖(仍只作开发验证工具)
- 函数内 `local` 声明过的循环变量(`kill_codex_tree` 等处的 `i`,shellcheck 未报)
- 为 `v1.1.0` / `v1.2.0` / `v1.2.1` 打 tag 或建 GitHub Release

## 实现方案

1. review.sh:在 `prompt=$(cat .ai-workflow/prompts/review.md)` 之前插入
   `shopt -u patsub_replacement 2>/dev/null || true` 与一行注释(说明原因,见
   docs/decisions/0012 对 plan-review.sh 的同一处理);三处占位替换顺序不变
   (EVIDENCE_REPORT 已是最后一个)。
2. 两个脚本的 `lock_holders`:`local real ino fd target pid` → `local real ino fd pid`。
3. 两个脚本主流程的 setsid 等待循环:`for i in $(seq 1 20)` → `for _ in $(seq 1 20)`。
4. evidence.sh:`on_sig() {` 上一行加
   `# shellcheck disable=SC2329  # 经 trap 字符串调用,静态分析识别不到`。
5. CHANGELOG 新增 `## [1.2.1]`(Fixed:review.sh 注入改写;Changed:shellcheck
   提示清零)与「升级指引」(可整体替换 `.ai-workflow/`,无需人工合并项);
   TEMPLATE-VERSION 1.2.1。

## 测试用例

<!-- 全部 A 档,留证写法 (b):每条一个断言脚本 evidence/tc-NN.sh,由 evidence.sh 包住
     产出 evidence/TC-NN.log,exit 0 = 全部断言成立。shellcheck 装在 /tmp 下临时 venv,
     路径经环境变量 SHELLCHECK 给出。无 C 档。 -->
| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | 临时 git 项目(复制 `.ai-workflow`),plan 含 TC-01(A)、TC-02(B)、TC-03(C);TC-01 证据由 evidence.sh 包住 `bash -c 'true && true'` 产出;实现记录中 TC-02 证据格为 `a.sh:12 & b.sh:3`、TC-03 证据格为 `目测 A&B 一致`;PATH 前置假 codex(把 prompt 落到项目外并写出 pass) | ① 单独运行 evidence-check.sh 取 stdout;② 运行 review.sh | review.sh exit 0;① 的每一行都逐字出现在 prompt 中;prompt 含 `a.sh:12 & b.sh:3`、`目测 A&B 一致` 与 `\&\&`;prompt 不含 `{{` | (b) TC-01.log |
| TC-02 | A | 同 TC-01,但 TC-01 证据缺尾部(evidence-check 不通过) | 运行 review.sh | exit 3、stderr 含"证据核验未通过"与补交清单、假 codex 未被调用(修复不影响拒启路径) | (b) TC-02.log |
| TC-03 | A | 临时 venv 中的 shellcheck | 对 `.ai-workflow/scripts/*.sh`、`.claude/hooks/*.sh`、`.githooks/*` 运行 shellcheck(默认级别) | exit 0 且无任何输出(全级别零条) | (b) TC-03.log |
| TC-04 | A | — | 依次运行 scope-guard-and-evidence-format 的 tc-01~11、tc-16~19 断言脚本 | 15 个全部 exit 0(覆盖 evidence.sh 留证与中断、evidence-check、review.sh 拒启/注入/渲染、看门狗查杀隔离) | (b) TC-04.log |
| TC-05 | A | — | 依次运行 plan-review-convergence 的 tc-01~06、tc-10、tc-12 断言脚本 | 8 个全部 exit 0(覆盖 plan-review.sh 各轮模式、上限、快照一致性、`__minors`) | (b) TC-05.log |
| TC-06 | A | — | `bash -n` 三个脚本;grep 断言 CHANGELOG 含 `## [1.2.1]` 与「升级指引」、TEMPLATE-VERSION 为 1.2.1;`git diff --name-only` 恰为改动范围中的 5 个文件(任务目录除外) | 全部成立 | (b) TC-06.log |

非 happy-path:TC-02(拒启路径);TC-04、TC-05 中的拒启、上限、中断、作废等异常路径。

## 风险与回滚

- **重命名循环变量或删 local 声明误伤逻辑**:三处均为未被引用的名字,TC-04/TC-05
  的 23 个行为脚本做回归
- **`shopt -u` 在不支持该选项的旧 bash 上报错**:`2>/dev/null || true` 兜底;旧 bash
  本无此行为
- 回滚:单提交 revert
