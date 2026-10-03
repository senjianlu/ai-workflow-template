---
task: review-watchdog-async
round: 01
date: 2026-10-04
---

# 实现记录:第 01 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 工具前置检查(flock/setsid/pgrep);看门狗参数(`RAWF_REVIEW_IDLE_SECONDS`/`MAX`/`POLL`,正整数校验);锁改 flock 文件 `.review-lock`(旧目录 → exit 3 迁移提示;`-E 75` 精确冲突码;冲突时关闭自身 fd 后按 fdinfo FLOCK 行定位持有者,持有者中无 review.sh 进程则报遗留 + `kill -TERM` 指引,不自动杀);codex 经 `setsid` 启动、`</dev/null`、`--json` 事件流落 `.review-raw-NN.events.jsonl`;看门狗循环(醒来先查存活);`kill_codex_tree` 会话+进程组 TERM→KILL;EXIT/TERM/INT trap;hash_excludes 增 `.review-lock` |
| `.ai-workflow/scripts/plan-review.sh` | 同上(锁 `.plan-review-lock`,事件 `.plan-review-raw-NN.events.jsonl`,无指纹段) |
| `.claude/hooks/gate-review.sh` | 无评审文件时,先对当前任务 `.review-lock` 做 `flock -n -E 75 ... true` 探测,退出码恰为 75 → 放行;其它一切维持 block |
| `.claude/skills/rawf-review/SKILL.md` | 第 1 步:后台启动(timeout ≥ 4000000 ms)后直接结束回合;exit 3 四类处置;删除 pgrep/删锁流程;保留一次性"旧版锁目录"迁移步骤 |
| `.claude/skills/rawf-plan/SKILL.md` | 第 6 步同款异步措辞 |
| `.gitignore` | 增 `.ai/**/.review-lock`、`.ai/**/.plan-review-lock` |
| `README.md` | 前置依赖增 `--json`、util-linux(flock、setsid)、procps(pgrep);机制速览更新 gate-review.sh 与 review.sh 两行 |
| `CHANGELOG.md` | 新增 `[Unreleased]`(Changed/Fixed/升级指引,含旧版锁目录迁移) |
| `docs/decisions/0009-review-watchdog-async.md` | 新增决策记录 |
| `.ai/.../assets/tests/` | codex 桩 `stub-codex-bin/codex` 与用例执行器 `run-tcs.sh`(测试资产,非源码) |

## 修复对照
(第 1 轮,不适用)

## 测试结果
执行方式:`bash .ai/2026-10-03/review-watchdog-async/assets/tests/run-tcs.sh`(一次完整运行,
看门狗参数 IDLE=3 / MAX=8 / POLL=1,fixture 为 scratchpad 下临时 git 仓库 + PATH 前置的
codex 桩;TC-15 使用真实 codex,TC-16 对本仓库文件 grep)。每条日志含命令、完整输出、
退出码与逐项断言,末行 `TC-NN RESULT: PASS`。

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

自测过程中发现并修正的实现缺陷(均已在最终完整运行中验证):
- `setsid codex &` 后立即检查 sid 存在竞态(子进程尚未执行到 setsid(2)),改为最多等 2 s 的轮询,
  进程已退出则直接放过;
- 看门狗的 `sleep` 子进程会继承锁 fd,脚本被 SIGKILL 后它仍短暂持锁(TC-07 第二次运行误报
  "进行中"),改为 `sleep ... 9>&-`;
- 遗留判定改按持有者 cmdline 是否含评审脚本名(见下节)。

## 与方案的偏差
- **遗留评审的判定依据**:plan 写"记录的脚本 pid 已退出 → 遗留";实现改为"持有者中没有
  cmdline 含 `review.sh`(plan 脚本为 `plan-review.sh`)的进程 → 遗留",锁文件的
  `script=` 行仅作为报错附注。原因:TC-18 明确要求锁文件被清空(无元数据)时仍能正确
  报告与恢复,按记录 pid 判定在该情形下退化为"待其结束后重跑"的错误分支;新依据与 plan
  的持有者定位一样不依赖元数据。范围仅限报错文案分支,互斥与定位逻辑不变。
- **测试桩的命令名**:TC-18 预期"名单含桩 pid 与命令名",桩是 bash 脚本,comm 为 `bash`
  而非 `codex`,断言按 `<pid> bash` 核对;真实 codex 的 comm 为 `codex`(TC-15 未涉及冲突
  路径,未验证该文案)。
- 其余按 plan 实现,无范围变化。

## 备注
- 本轮 /rawf-review 将由改动后的 review.sh 自身执行(后台启动、`</dev/null` 已内置、
  Stop hook 放行),评审进行中的实际表现在评审产出后记录。
