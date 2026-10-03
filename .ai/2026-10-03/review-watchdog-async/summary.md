---
task: review-watchdog-async
date: 2026-10-04
rounds: 2
verdict: pass
---

# 任务小结:Codex 评审卡死治理——stdin 兜底、事件流看门狗、flock 锁、评审异步化

## 改动
| 文件 | 摘要 |
|---|---|
| `.ai-workflow/scripts/review.sh` | codex `</dev/null`;`--json` 事件流落盘作进度信号;静默 15 min / 墙钟 60 min 看门狗(`RAWF_REVIEW_IDLE_SECONDS` / `MAX` / `POLL` 可调);setsid 启动,按会话 + 进程组 TERM→KILL 清理(含 codex 先退出时的后代);锁改 flock 文件 `.review-lock`(专用冲突码 75;冲突时按 fdinfo FLOCK 行定位持有者,复核后报告与处置命令,不自动杀;旧版锁目录 → 迁移提示);hash_excludes 增 `.review-lock` |
| `.ai-workflow/scripts/plan-review.sh` | 同上(锁 `.plan-review-lock`) |
| `.claude/hooks/gate-review.sh` | 当前任务 `.review-lock` 被 flock 持有(冲突码 75)→ 放行;其它一切 fail-closed 维持拦截 |
| `.claude/skills/rawf-review/SKILL.md`、`rawf-plan/SKILL.md` | 评审后台启动后直接结束回合,完成通知唤回再分流;exit 3 分类处置;删除 pgrep/手工删锁流程,保留一次性旧锁目录迁移步骤 |
| `.gitignore` | 增两条锁文件模式 |
| `README.md` | 前置依赖(--json、util-linux、procps);机制速览两行 |
| `CHANGELOG.md` | `[Unreleased]`:Changed/Fixed/升级指引(含旧锁目录迁移;hook 行为变更建议 MAJOR) |
| `docs/decisions/0009-review-watchdog-async.md` | 新增决策记录 |
| `.ai/2026-10-03/review-watchdog-async/` | plan(5 轮 plan 评审)、2 轮实现记录、评审记录、21 条 A 档证据、测试桩与执行器、现场标本与统计 |

## 评审历程
| 轮次 | 结论 | 关键问题 |
|---|---|---|
| plan 1 | fail | 锁回收竞态;无 setsid 清理不全;hook 按命令子串放行过宽;TC-02 管道计时无效 |
| plan 2 | fail | TC 预期与锁常驻矛盾;TC-05 桩不真实;看门狗醒来未先查存活;SIGKILL 后无法定位持锁者;flock 失败一律放行;旧锁目录无迁移 |
| plan 3 | fail | sid 写入前被杀的窗口;TC-16 与迁移指引冲突(同时按用户要求收回自动杀进程) |
| plan 4 | fail | /proc 扫描把"仅打开"误当"持锁" |
| plan 5 | pass | 无(首跑 codex 本身卡在 stdin socket,成为现场标本) |
| 实现 1 | fail | R-01 blocker:A 档证据不完整;R-02:持有者快照过期误报遗留;R-03:codex 先退出时后代未清理 |
| 实现 2 | pass | 无 |

## 遗留 minor 及处置
无(最后一轮评审问题清单为空)。
