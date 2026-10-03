---
task: review-watchdog-async
round: 02
date: 2026-10-04
---

# 实现记录:第 02 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 持有者扫描改 `find -lname` 单进程完成(原逐 fd `readlink` fork 数千次,快照过期)并吞掉 find 的非零退出;冲突分支输出前复核:锁已释放 → "评审刚结束,请重跑";名单只保留仍存活的进程;cmdline 读取失败不再刷屏;正常退出路径在清空 `codex_pid` 前检查受管后代,仍存活则告警并 `kill_codex_tree` |
| `.ai-workflow/scripts/plan-review.sh` | 同上 |
| `assets/tests/run-tcs.sh` | 后台启动、发信号、wait 统一经 `bg_review`/`sig`/`wait_bg` 记录命令、完整输出与退出码;TC-15 记录完整 events.jsonl;TC-18 增 opener 存活断言;TC-06 增"B 文案不含 遗留/kill -TERM"断言;新增 TC-21(codex 主进程先退出、后代持锁)|
| `assets/tests/stub-codex-bin/codex` | 增 `early` 模式(起后台子进程后立即退出 0、不写输出) |

## 修复对照
| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| R-01 | blocker | 补齐 A 档证据:TC-05/06/07/08/18 的后台启动命令、信号与 wait 均记录到 evidence(含首次被终止评审的完整 stdout/stderr 与退出码);TC-15 记录完整 events.jsonl;TC-18 补 opener 存活断言。全部 21 条日志为同一次完整运行产出 |
| R-02 | major | 根因是持有者扫描过慢(逐 fd fork readlink),快照在 A 正常结束后才输出。改为 `find -lname` 单进程扫描;输出前复核锁是否仍被持有(已释放 → "评审刚结束,请重跑",不输出名单)、名单过滤为仍存活进程;TC-06 新增断言 B 的文案不含"遗留"/`kill -TERM`(evidence/TC-06.log) |
| R-03 | major | 正常退出路径 `wait` 后、清空 `codex_pid` 前检查 `managed_pids`,非空则告警并 `kill_codex_tree`;新增回归用例 TC-21(evidence/TC-21.log):桩起 `sleep 300 &` 后立即退出 0 且不写输出,脚本 exit 3、后代被清理、锁可立即获取 |

## 测试结果
执行方式同第 1 轮:`bash .ai/2026-10-03/review-watchdog-async/assets/tests/run-tcs.sh`
一次完整运行(IDLE=3 / MAX=8 / POLL=1),21 条全部 PASS,无遗留桩进程。

| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | evidence/TC-01.log |
| TC-02 | A | pass | evidence/TC-02.log |
| TC-03 | A | pass | evidence/TC-03.log |
| TC-04 | A | pass | evidence/TC-04.log |
| TC-05 | A | pass | evidence/TC-05.log |
| TC-06 | A | pass | evidence/TC-06.log |
| TC-07 | A | pass | evidence/TC-07.log |
| TC-08 | A | pass | evidence/TC-08.log |
| TC-09 | A | pass | evidence/TC-09.log |
| TC-10 | A | pass | evidence/TC-10.log |
| TC-11 | A | pass | evidence/TC-11.log |
| TC-12 | A | pass | evidence/TC-12.log |
| TC-13 | A | pass | evidence/TC-13.log |
| TC-14 | A | pass | evidence/TC-14.log |
| TC-15 | A | pass | evidence/TC-15.log |
| TC-16 | A | pass | evidence/TC-16.log |
| TC-17 | A | pass | evidence/TC-17.log |
| TC-18 | A | pass | evidence/TC-18.log |
| TC-19 | A | pass | evidence/TC-19.log |
| TC-20 | A | pass | evidence/TC-20.log |
| TC-21(评审 R-03 新增回归)| A | pass | evidence/TC-21.log |

自测中发现并修正:`find /proc/*/fd` 对无权限条目返回非零,`set -e`/pipefail 下令
`holders=$(lock_holders)` 失败、脚本静默 exit 1(TC-06/TC-18 首跑暴露),已 `|| true` 吞掉。

## 与方案的偏差
- 第 1 轮记录的两条偏差(遗留判定按 cmdline、桩 comm 为 bash)不变。
- 新增 TC-21 为评审 R-03 要求的回归用例,plan 未列;只增不改既有用例预期。
- 其余无变化。

## 备注
- 第 1 轮 /rawf-review 实际表现:review.sh 自身后台运行、stdin=/dev/null、独立会话、
  Stop hook 探测放行,评审正常产出;第 1 轮 codex 对 .ai/ 内测试资产与证据做了逐条核对。
