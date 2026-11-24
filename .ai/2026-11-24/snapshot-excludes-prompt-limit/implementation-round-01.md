---
task: snapshot-excludes-prompt-limit
round: 01
date: 2026-11-24
---

# 实现记录:第 01 轮

## 本轮改动

7 个产品文件,与 plan 的范围一致。

| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/review.sh` | `review_paths` 改为:已跟踪改动全部纳入;未跟踪文件须同时通过标准忽略规则与 `hash_excludes`,两套规则各跑一次再取交集,`.claude/` 下的只看前者。新增 `snapshot_scope`,清单 `head` 行第三列记纳入口径摘要;上一轮口径与本轮不同(含没有这一列的清单)时回退全量评审。每一轮的轮次上下文末尾给出本轮清单路径与"评审对象以它为准"的说明。工具预检加入 `comm` |
| `.ai-workflow/scripts/plan-review.sh` | 修订 diff 超过 16384 字节时写入 `.plan-review-raw-NN.diff`,上下文里只给路径与字节数;落盘路径只在需要时才要求可用,清不掉或写不进去 → exit 3、不消耗轮次;拼好的指令超过 100000 字节 → exit 3 并说明原因 |
| `.ai-workflow/prompts/review.md` | 开头补一句:评审对象以「本轮上下文」给出的文件清单为准 |
| `.ai-workflow/review-standards.md` | 「评审对象」一栏补同一句;「分轮模式」的全量回退条件补"两轮清单的纳入口径不同",全量评审写明审"本轮清单中的全部改动" |
| `README.md` | 「机制速览」plan 评审一条补"(超过 16 KiB 时落盘,指令里只给路径)" |
| `CHANGELOG.md` | `[1.5.1]` 条目:Fixed 两条、Changed 两条、升级指引 |
| `.ai-workflow/TEMPLATE-VERSION` | 1.5.1 |
| `.ai/2026-11-24/snapshot-excludes-prompt-limit/assets/tests/run.sh` | 6 条用例的断言脚本;codex 桩复用上一个任务的 |

## plan 评审 minor 与建议交接

取自 `plan-review.sh __minors`(两轮合计 2 条 minor、5 条建议)。

| 来源 | 内容 | 处置 |
|---|---|---|
| plan/01/A-01 | TC-02 可明确逐字节比对所用的 `diff -u` 标签和末尾换行 | 已在 plan 修订中解决;测试按同样的标签生成期望输出并用 `cmp` 逐字节比对 |
| plan/01/A-02 | README 与 t0012 的「版本绑定」仍描述把修订 diff 注入指令,可补充长 diff 经路径交付 | 本轮实现处理 README。t0012 不改:它是 2026-10-22 的决策记录,落盘只是交付形式的细节,没有改变"版本绑定"这项决策 |
| plan/02/R-01 | 口径摘要只能识别排除参数的变化,识别不了 `--exclude-from` 所引规则文件的变化 | 不处理:模板约定的写法是在 `hash_excludes` 里直接写 `--exclude` 项,引用外部规则文件属于项目自行扩展。已在 `snapshot_scope` 的注释里注明这一限制,并记入停车场 |
| plan/02/R-02 | 同一 HEAD 下恢复 1.5.0 脚本时,旧读取器会把新增的 `scope` 行当成路径记录 | 已在 plan 修订中解决:摘要放在 `head` 行第三列而不另起一行,1.5.0 的脚本读到它时 HEAD 比对不上、回退全量评审 |
| plan/02/A-01 | 可明确区分快照和完整性指纹(`audit.log` 的反选仍计入指纹) | 已在 plan 修订中解决;review.sh 的口径注释末尾也写明"这里只定快照的口径" |
| plan/02/A-02 | 评审标准「分轮模式」的回退条件可同步;TC-06 可断言回退轮的指令仍给出本轮清单路径 | 本轮实现处理(两处都做了) |
| plan/02/A-03 | 1.5.1 升级指引可把 README 标为需人工合并 | 本轮实现处理 |

## 修复对照

无(第 1 轮)。

## 评审建议处置

无(第 1 轮)。

## 测试结果

留证命令在仓库根执行:
`bash .ai-workflow/scripts/evidence.sh TC-NN -- bash .ai/2026-11-24/snapshot-excludes-prompt-limit/assets/tests/run.sh tcNN`。
断言数:TC-01 25、TC-06 22、TC-02 16、TC-03 16、TC-04 8、TC-05 7,均无失败。

| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01.log |
| TC-06 | A | pass | TC-06.log |
| TC-02 | A | pass | TC-02.log |
| TC-03 | A | pass | TC-03.log |
| TC-04 | A | pass | TC-04.log |
| TC-05 | A | pass | TC-05.log |

TC-04 跑的是上一个任务的回归用例 tc03、tc06、tc10(修复轮上下文、plan 评审分轮、
轮间差异),三条均 exit 0,确认 1.5.0 的行为未被碰坏。

## 与方案的偏差

| 编号 | 类型 | 内容 | 原因 | 处置 |
|---|---|---|---|---|
| D-01 | 替代 | review.sh 的工具预检加入 `comm` | 两套规则取交集用的是 `comm -z`;缺少它时快照生成会以一条不直观的报错失败 | 已实现 |
| D-02 | 替代 | 轮次上下文里对清单的说明多写了一句编码规则(路径里的 `%`、制表符、换行、回车在清单中的写法) | plan 只说"给出本轮清单的路径";清单的路径列是编码过的,不说明的话评审者按字面读带 `%` 的路径会读错 | 已实现 |

没有追加类偏差。

## 停车场

- 口径摘要不覆盖 `--exclude-from` 所引规则文件的内容(plan/02/R-01)。项目若这样
  管理排除项并在两轮之间只改规则文件,下一轮不会回退全量评审。
- plan-review.sh 没有 review.sh 那道"退出码 1 只表示已发布 fail 评审"的总闸(本任务
  非目标)。
- review.sh 文件头的"运行环境要求"一行没有逐个列出 `comm`(它与 `sha1sum` 同属
  coreutils,该行已写 coreutils)。
