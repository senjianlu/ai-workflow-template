---
status: approved
task: scope-guard-and-evidence-format
date: 2026-10-22
approved_at: 2026-10-22 10:34:23
evidence_format: v1
---

# 方案:范围自省提醒 + A 档证据标准格式与机器核验

## 需求原文

> 看下 cscheap-api、cscheap-frontend、steammarket-spider、steammarket-refinery
> 的 ai 工作流运行情况,并优化两项:
> 1. 在 plan 和改修的 review 后总能自省是否偏移或是让需求无端扩张了
>    (度很难量化);
> 2. codex 的改修 review 总会抓着测试证据,减少这种时间和 token 浪费。
>
> 后续对齐:偏移**不量化**,仅通过固定位置的提醒让 agent 自行判断;证据
> 改修方向正确,所有文件对 codex 开放按需读取,不设目录级禁区;留证脚本
> 不得在多项目并行时产生竞态,也不得被评审脚本的查杀误伤。

**本任务交付**:模板 1.1.0——(a)plan / 实现 / 评审 / 收尾四个阶段各有
一处固定的范围自省提醒;(b)A 档证据改为 `evidence.sh` 产出的标准格式文件,
由 `evidence-check.sh` 在评审前机器核验,评审者只核内容不核格式。

## 调研结论(驱动本方案的事实)

四个 consumer 项目 332 个任务、737 轮实现评审、1059 轮 plan 评审:

| 事实 | 数据 |
|---|---|
| 首轮 fail 中含"证据格式"问题(缺命令/缺退出码/被截断) | 212 次首轮 fail 中 127 次(37 次纯格式、90 次混合) |
| 第 2 轮起仍在追证据格式 | 46 条 |
| 实现记录"与方案的偏差"非空 | 762 份中 740 份,大量"plan 之外追加 X""只加强不放宽" |
| 实现评审提到范围外改动 | 737 轮中 3 条(prompt 未问) |
| plan 与用户原始需求的偏移 | 无任何记录位置 |
| 留证方式 | 每任务自造 run_tcNN.sh / transcript,无统一格式 |

## 改动范围

新增:

- `.ai-workflow/scripts/evidence.sh`:包住一条命令,产出 rawf-evidence v1 格式文件
- `.ai-workflow/scripts/evidence-check.sh`:按实现记录逐条机器核验 A 档证据的结构完整性
- `docs/decisions/0010-evidence-format-v1.md`、`docs/decisions/0011-scope-reflection.md`

修改:

- `.ai-workflow/scripts/review.sh`:评审启动前调用 evidence-check;报告注入 prompt;渲染新增「范围核对」节
- `.ai-workflow/scripts/plan-review.sh`:渲染新增「范围核对」节
- `.ai-workflow/schemas/review.schema.json`、`plan-review.schema.json`:新增必填字段 `scope_findings`
- `.ai-workflow/prompts/review.md`、`prompts/plan-review.md`:证据核验职责重划、范围固定问题、新字段语义
- `.ai-workflow/review-standards.md`:A 档证据形态与逐档核验规则改写;新增「范围核对」与「证据阅读建议」
- `.ai-workflow/templates/plan.md`、`implementation-round.md`、`summary.md`:新节与新列
- `.claude/skills/rawf-plan|rawf-implement|rawf-review|rawf-report/SKILL.md`
- `CLAUDE.md`(硬规则两条)、`README.md`(机制速览)、`CHANGELOG.md`、`.ai-workflow/TEMPLATE-VERSION`
- `docs/decisions/0006-test-evidence-tiers.md`:顶部标注"A 档证据形态与核验规则已被 0010 部分取代"

明确不动:`.claude/hooks/*`、`.claude/settings.json`(闸门行为不变);
`.gitignore`;AGENTS.md;四个 consumer 项目(升级由各项目按 CHANGELOG 指引自行执行)。

## 非目标

- 偏移的任何量化手段(diff 预算、路径白名单、文件数阈值)——用户明确不要
- plan 评审 ~75% 的 fail 率、评审轮次上限——不在本任务
- 评审者可读文件范围——不设任何目录级禁区,只给阅读顺序建议
- B / C 档证据规则——不变
- 为四个 consumer 项目执行升级

## 实现方案

### 1. 范围自省:四个固定位置,只提醒不量化

| 阶段 | 位置 | 内容 |
|---|---|---|
| plan | `templates/plan.md` 新增「需求原文」(用户原话引用 + 一句话交付物)与「非目标」两节;rawf-plan 第 7 步摘要必带"范围自省"三问:需求要什么 / 改动范围里哪些不是需求直接要求的、为何保留 / 哪些顺手项已移入非目标 | 由 agent 自判,无阈值 |
| plan 评审 | `prompts/plan-review.md` 固定问题 4:方案是否超出「需求原文」,顺手项是否已列入「非目标」;结论写入 `scope_findings`(字符串数组,可为空),**不定严重度、不计入 pass/fail**,渲染为「范围核对」节供用户裁决 | 同上 |
| 实现 | `templates/implementation-round.md`「与方案的偏差」改为表格,列:编号 / 类型(**收窄 \| 替代 \| 追加**)/ 内容 / 原因 / 处置;新增「停车场」节(范围外发现,本任务不做)。rawf-implement 硬规则:**追加类不得自行实现**——停下问用户,或写入停车场;"只加强不放宽"不是自授权理由 | |
| 实现评审 | `prompts/review.md` 固定问题:diff 中是否存在 plan「改动范围」之外或偏差表未声明的改动;同样写 `scope_findings`,不定严重度 | |
| 收尾 | `templates/summary.md` 新增「范围核对」节:追加项及用户裁决、停车场条目及去向(记入后续 / 放弃);rawf-report 第 4 步就停车场条目征求决定 | |

rawf-review 分流:`scope_findings` 非空时原样呈给用户裁决,与 minor 一并带入收尾;不触发修复轮。

### 2. A 档证据:格式归机器,内容归评审

**evidence.sh** —— `bash .ai-workflow/scripts/evidence.sh <TC-id> [-l <label>] -- <命令...>`

- 项目根取 `CLAUDE_PROJECT_DIR` 或 `git rev-parse --show-toplevel`;任务目录取 `.ai/.current-task`
- 目标文件 `<task>/evidence/<TC-id>[-<label>].log`;**已存在则拒绝覆盖,exit 3**(与".ai/ 只增不改"一致;重跑须另起 label)
- TC-id 须匹配 `^TC-[0-9]+[A-Za-z0-9]*$`,label 须匹配 `^[A-Za-z0-9_.-]+$`;不合法 exit 3
- 格式(rawf-evidence v1)。**必填字段与完整性定义**(机器核验的唯一依据):

  ```
  # rawf-evidence v1          ← 第 1 行,逐字
  tc: TC-07                   ← 必填,匹配 TC-id 规则
  label: r02                  ← 可空
  cmd: pytest tests/test_x.py -v   ← 必填非空;argv 逐项 %q 引用,原样可复跑
  cwd: /abs/path              ← 必填
  git_head: <sha>[ dirty]     ← 必填
  started: 2026-10-22T10:00:00+08:00   ← 必填
  --- output ---              ← 正文起始标记,独占一行
  <stdout 与 stderr 合流,完整,不截断;同时 tee 到终端>
  --- end ---                 ← 尾部起始标记,独占一行;evidence.sh 总在正文后先写一个换行再写本行
  exit: 0                     ← 必填,0..255 整数
  finished: 2026-10-22T10:00:05+08:00   ← 必填
  bytes: 1234                 ← 必填 = 正文区字节数(见下)
  ```

  正文区 = `--- output ---\n` 之后、**最后一个** `\n--- end ---\n` 之前的全部
  字节,其长度必须等于 `bytes:`(evidence.sh 按实际写出的字节计数)。正文本身
  出现 `--- end ---` 字样不影响判定(取最后一个)。正文被截断但保留尾部 →
  bytes 不等 → 判 TRUNCATED。
- 命令以 argv 形式直接执行(不经 shell);需要管道/重定向时调用方传 `-- bash -c '...'`
- 退出码:透传被包命令的退出码(脚本自身错误用 3,与评审脚本一致)
- 中断:trap INT/TERM 转发给子进程、等其退出,仍写出尾部(exit 130/143);SIGKILL 无法处理,留下无尾部文件,由 evidence-check 判不完整
- **无共享状态**:不用锁、不用项目外临时文件、不写任务目录以外的路径;多项目并行各写各的任务目录。不启动 codex,命令行不含 `codex exec`,不会被 review.sh 的会话/进程组查杀或 pgrep 模式命中
- 既有规则不变:评审进行中不得运行(evidence/ 计入指纹)

**evidence-check.sh** —— `bash .ai-workflow/scripts/evidence-check.sh [NN]`(缺省为最新实现轮)

- 若 plan.md frontmatter 无 `evidence_format: v1` → 打印"历史任务,跳过机器核验",**exit 2**
- 先解析 plan.md「测试用例」表得到基准清单(编号 → 档位),再解析
  implementation-round-NN.md「测试结果」表,**以 plan 清单为准对照**:
  - plan 有、记录无 → MISSING-ROW;记录档位 ≠ plan 档位 → TIER-MISMATCH
    (含降档与升档,均判不通过);记录有、plan 无 → EXTRA-ROW(列出,不判
    不通过,由评审按范围核对处理);测试结果表缺失或为空 → EMPTY-TABLE
  - 结果为 `blocked` 的任何行 → BLOCKED(不得进评审)
  - 档位 A 且结果 pass/fail 的行:证据单元格须引用 ≥1 个 `*.log` 文件名,
    每个文件逐项核验:存在(否则 MISSING)→ 首行逐字为 `# rawf-evidence v1`
    (否则 NO-HEADER)→ 头部含非空 `tc:`、`cmd:`、`cwd:`、`git_head:`、
    `started:`(否则 BAD-HEADER,列出缺项)→ 含 `--- output ---` 行(否则
    NO-BODY)→ 最后一个 `--- end ---` 之后含 `exit:`(0..255 整数)、
    `finished:`、`bytes:`(否则 NO-FOOTER / BAD-EXIT)→ 正文区长度 = bytes
    (否则 TRUNCATED);全部通过 → OK。证据单元格无引用 → NO-REF
  - 档位 B / C:只列出,标"按档位由评审核验",不判
- 输出 markdown 表(编号 / 档位 / 结果 / 证据文件 / 机器核验 / exit 值 / cmd 摘要)到 stdout;全部 A 行 OK、无 MISSING-ROW / TIER-MISMATCH / EMPTY-TABLE / BLOCKED → exit 0,否则 exit 1 并在 stderr 列补交清单(具体到编号与所缺项)。EXTRA-ROW 不影响退出码

**review.sh 接入**(在轮次确定之后、codex 启动之前):

- 调 evidence-check:rc 1 → 报告与补交清单打到 stderr,**exit 3**(stderr 含"证据核验未通过"),codex 不启动,不消耗评审轮次;rc 0 → 报告替换 prompt 中 `{{EVIDENCE_REPORT}}`;rc 2 → 占位替换为"历史任务:未经机器核验,A 档格式由评审自行核对"
- 渲染:新增 `## 范围核对` 节(`scope_findings` 为空时写"无");`.scope_findings // []` 容错
- 与 plan-review.sh 同构修改渲染

**prompts/review.md 与 review-standards.md 职责重划**:

- A 档证据形态定义改为"evidence.sh 产出的 rawf-evidence v1 文件";格式(命令、退出码、是否截断)由机器核验,**评审不再就格式提意见**
- 评审对 A 档只核三件事:① `cmd:` 是否对应用例步骤(测的是不是这条用例、
  是否覆盖用例要求的场景);② `exit:` 与正文是否**符合该用例在 plan 中写明的
  预期结果**——预期结果本身可以是非零退出码或报错输出,非零 ≠ 失败;③ 记录
  中的结果与证据是否一致
- 两种留证写法都合法,plan 的证据形态列写明用的是哪种:(a) 直接包住被测
  命令,`exit:` 即被测命令退出码,评审拿它对照用例预期;(b) 包住一个断言脚本
  (脚本内部执行被测命令并断言输出/退出码),此时 `exit: 0` 表示全部断言成立,
  被测命令的退出码在正文里。本任务全部用例取 (b):`evidence/tc-NN.sh`
- 严重度映射:证据(exit / 正文)与用例预期结果矛盾却报 pass,或证据与记录
  矛盾 → blocker(虚报);cmd 未覆盖用例要求的场景或步骤 → major;格式 →
  不列(机器已核)
- 阅读建议(非禁区):所有文件按需可读;先读头部与尾部,再按疑点深入;大文件不必通读
- 历史任务(占位为"未经机器核验")沿用旧规则自行核对格式

### 3. 文档与版本

- 决策 0010(证据格式 v1 与机器核验,部分取代 0006 的 A 档条款)、0011(范围自省:提醒不量化,追加需用户确认或入停车场;记录被否的量化备选与理由)
- CHANGELOG 1.1.0:Added / Changed + 升级指引(可整体替换:.ai-workflow/、rawf-* skill;需人工合并:CLAUDE.md、README.md);TEMPLATE-VERSION 1.1.0
- 版本位:按 README 规则,hook 未变、历史任务经 `evidence_format` 标记兼容、新能力为主 → MINOR;若用户认为"追加须确认"属流程步骤变更而应 MAJOR,在确认闸一并定

### 4. 自举

本任务自身按新规则执行:plan 已带 `evidence_format: v1`,实现记录的 A 档证据全部由 evidence.sh 产出,review.sh 以新 prompt、新 schema、新 evidence-check 评审本任务。

## 测试用例

<!-- 全部 A 档:对象是脚本与文本文件,均可由非交互命令判定。无 C 档。
     留证写法统一取 (b):每条用例一个断言脚本 evidence/tc-NN.sh(内部执行步骤并断言
     预期,全部成立 exit 0),由 evidence.sh 包住产出 evidence/TC-NN.log;因此所有
     证据文件的 exit: 都应为 0,被测命令的退出码(如 TC-02 的 7、TC-04 的 143)
     在正文断言输出中。TC-01~TC-12、TC-16~TC-19 在临时 git 仓库中运行,与本仓库
     隔离:外层 evidence.sh 使用本项目,被测脚本经 env CLAUDE_PROJECT_DIR=<tmp>
     指向临时仓库。 -->
| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | 临时仓库有 .current-task 与任务目录 | `evidence.sh TC-01 -- bash -c 'echo out; echo err >&2; exit 0'` | 产出 evidence/TC-01.log:首行 `# rawf-evidence v1`,含 cmd:/cwd:/git_head:/started:,`--- output ---` 后同时含 out 与 err 行,尾部 `--- end ---`、`exit: 0`、`finished:`、`bytes:`;包装器退出码 0;终端也看到 out/err | evidence.sh 产出 TC-01.log(含 grep 断言脚本输出) |
| TC-02 | A | 同上 | 包住 `bash -c 'exit 7'` | 尾部 `exit: 7`,包装器退出码 7 | evidence.sh 产出 TC-02.log |
| TC-03 | A | TC-01 已产出文件 | 再次以 TC-01 运行;再以 `-l rerun` 运行 | 第一次 exit 3 且 stderr 含"已存在",原文件 sha256 不变;第二次产出 TC-01-rerun.log | evidence.sh 产出 TC-03.log |
| TC-04 | A | 同 TC-01 | 后台运行包住 `sleep 30` 的 evidence.sh,1 s 后向包装器发 TERM,wait | 文件含 `--- end ---` 与 `exit: 143`;子进程 sleep 不再存活 | evidence.sh 产出 TC-04.log |
| TC-05 | A | 临时仓库 | ① 删除 .current-task 后运行;② 以 `TC_x` 非法编号运行;③ 不带 `--` 运行 | 三者均 exit 3,stderr 分别含"无进行中任务"/"编号不合法"/"用法" | evidence.sh 产出 TC-05.log |
| TC-06 | A | 临时任务目录含 plan.md(evidence_format: v1)、implementation-round-01.md(A 行引用有效 .log,B 行、C 行各一)及对应证据文件 | `evidence-check.sh` | exit 0;stdout 表中 A 行标 OK 并显示 exit 值与 cmd,B/C 行标"按档位由评审核验" | evidence.sh 产出 TC-06.log |
| TC-07 | A | 实现记录含五种坏行:无引用、文件缺失、无头部、无尾部、结果 blocked | `evidence-check.sh` | exit 1;五行分别标 NO-REF / MISSING / NO-HEADER / NO-FOOTER / BLOCKED;stderr 补交清单逐条列出编号与所缺项;断言脚本本身 exit 0 | evidence.sh 产出 TC-07.log |
| TC-08 | A | plan.md 无 evidence_format 字段 | `evidence-check.sh` | exit 2;stdout 含"跳过机器核验" | evidence.sh 产出 TC-08.log |
| TC-09 | A | 临时仓库 PATH 前置假 `codex`(执行即写标记文件);实现记录为 TC-07 的坏记录 | `review.sh` | exit 3;stderr 含"证据核验未通过"与补交清单;标记文件不存在(codex 未启动);任务目录无 review-round-01-*.md | evidence.sh 产出 TC-09.log |
| TC-10 | A | 假 `codex` 把收到的 prompt 落盘并按 schema 写出含 `scope_findings:["X"]` 的 JSON;实现记录为 TC-06 的好记录 | `review.sh` | exit 0;落盘 prompt 含 evidence-check 的报告表且不含 `{{`;review-round-01-pass.md 含 `## 范围核对` 与 "X";同一 JSON 去掉 scope_findings 后用 `__publish_round` 路径重渲染不报错且该节写"无" | evidence.sh 产出 TC-10.log |
| TC-11 | A | — | `plan-review.sh __publish_round` 以含 scope_findings 的样例 JSON 渲染 | 产物含 `## 范围核对` 节与条目 | evidence.sh 产出 TC-11.log |
| TC-12 | A | — | `jq` 断言两份 schema:`required` 含 scope_findings,其 items.type 为 string | 两份均通过 | evidence.sh 产出 TC-12.log |
| TC-13 | A | — | `bash -n` 四个脚本;`shellcheck` 可用则运行 | bash -n 全部 exit 0;shellcheck 无 error 级(不可用时记录"未安装") | evidence.sh 产出 TC-13.log |
| TC-14 | A | — | grep 断言:review.md 含 `{{EVIDENCE_REPORT}}` 与范围固定问题;plan-review.md 含范围固定问题;review-standards.md A 档核验规则不再含"缺失或不完整 → blocker";templates/plan.md 含 `evidence_format: v1`、「需求原文」「非目标」;implementation-round.md 含 收窄/替代/追加 与「停车场」;summary.md 含「范围核对」;四个 skill 各含对应关键字(evidence.sh / evidence-check / 停车场 / 范围自省) | 全部命中 | evidence.sh 产出 TC-14.log |
| TC-15 | A | — | grep 断言:0006 顶部含"已被 0010 部分取代";0010、0011 含日期/背景/决定/影响四段;CHANGELOG 含 `## [1.1.0]` 与「升级指引」;TEMPLATE-VERSION `version: 1.1.0`;README 机制速览提到 evidence-check | 全部命中 | evidence.sh 产出 TC-15.log |
| TC-16 | A | 临时任务目录,四个格式反例文件:缺 cmd 行;`exit: abc`;正文截断但尾部保留(bytes 不等);正文内含 `--- end ---` 字样但结构完整 | `evidence-check.sh`;再以同一记录运行 `review.sh`(PATH 前置假 codex) | 前三者分别标 BAD-HEADER / BAD-EXIT / TRUNCATED,第四者 OK;exit 1;review.sh exit 3 且假 codex 未启动 | evidence.sh 产出 TC-16.log |
| TC-17 | A | 临时任务目录,plan 含 TC-01(A)、TC-02(A)、TC-03(B);实现记录四种变体:① 缺 TC-02 行;② TC-01 档位写 C;③ 测试结果表为空;④ 多出 plan 没有的 TC-09 行且其余正常 | 对四个变体各跑 `evidence-check.sh` | ①②③ exit 1,分别标 MISSING-ROW / TIER-MISMATCH / EMPTY-TABLE;④ exit 0 且 TC-09 标 EXTRA-ROW | evidence.sh 产出 TC-17.log |
| TC-18 | A | 两个独立临时 git 仓库 A、B,各有自己的 .current-task 与任务目录 | 同时(后台并行)在 A、B 中以相同 TC-id `TC-01` 运行 evidence.sh,A 包住 `bash -c 'echo A; exit 0'`,B 包住 `bash -c 'echo B; exit 5'`;wait 两者 | A 的 evidence/TC-01.log 正文只含 A、`exit: 0`、cwd 为 A 的路径;B 的只含 B、`exit: 5`、cwd 为 B 的路径;两包装器退出码分别为 0 与 5;两仓库 evidence/ 各仅一个文件 | evidence.sh 产出 TC-18.log |
| TC-19 | A | 临时仓库 B 的 PATH 前置假 `codex`(执行后 `sleep 600`,不产出);临时仓库 A 同 TC-01 前置 | 在 B 中以 `RAWF_REVIEW_IDLE_SECONDS=2 RAWF_REVIEW_POLL_SECONDS=1` 后台运行 review.sh(B 的实现记录为 TC-06 的好记录,前置核验通过);同时在 A 中运行 evidence.sh 包住 `sleep 8`;wait 两者 | B 的 review.sh exit 3 且 stderr 含"已终止",B 的假 codex 及其 sleep 进程均不再存活;A 的 TC-01.log 结构完整、`exit: 0`,对 A 运行 evidence-check 为 OK;A 的 evidence.sh 退出码 0 | evidence.sh 产出 TC-19.log |

非 happy-path:TC-03、TC-04、TC-05、TC-07、TC-08、TC-09、TC-16、TC-17、TC-19。并行与隔离:TC-18(多项目同 TC-id 并行留证互不串扰)、TC-19(另一项目看门狗查杀不误伤留证进程)。

本任务自身证据的完整核验不设用例(自举循环):由 review.sh 的前置 evidence-check 在评审启动前对 implementation-round-01.md 执行,不通过则评审不启动。

## 风险与回滚

- **review.sh 接入出错会卡住所有评审**:TC-09 / TC-10 以假 codex 端到端覆盖;回滚为 `git revert` 单个提交(hook 未动)
- **evidence-check 的表格解析对手写格式敏感**:只认 `|` 分隔的标准行,编号取首列、档位取第二列、证据单元格只提取 `*.log` 文件名,其余文本忽略;plan 的用例表与记录的测试结果表任一解析不到即 exit 1 并提示(EMPTY-TABLE)
- **假 codex 覆盖不到真实 codex 对新 prompt 的反应**:本任务自举评审即第一次真实运行;若 codex 对新字段/新职责理解偏差,按 rawf-review 第 4 条呈用户
- **历史任务**:无 `evidence_format` 的任务走 exit 2 分支,行为与 1.0.1 相同
- **版本位 MINOR vs MAJOR**:确认闸时由用户定,只影响 CHANGELOG / TEMPLATE-VERSION 两处文本

<!-- 过程产物落点:A 档证据全部由 evidence.sh 落 evidence/;无 assets。 -->
