# 评审:第 01 轮

## 问题清单
- [blocker] R-01 部分 A 档用例未保留完整执行证据。
  - 详情:定位：.ai/2026-10-03/review-watchdog-async/evidence/TC-15.log:14，以及 assets/tests/run-tcs.sh:72、85、94、104、169（同任务目录）。需补交：TC-15 的完整 events.jsonl（原始 stdout，现仅首尾两行）；TC-05、TC-06 的后台评审启动命令；TC-07、TC-08、TC-18 的启动、发信号及 wait 命令；TC-07、TC-18 首次被终止评审的完整 stdout/stderr 和退出码。另外，TC-18 未执行 plan 要求的 opener 存活断言，须补充该检查的命令、输出和退出码。请将证据完整落入 evidence/，不能仅以测试源码或 PASS 标记替代。
- [major] R-02 持锁者扫描结束后未复核状态，会把正常完成的评审误报为遗留进程。
  - 详情:定位：.ai-workflow/scripts/review.sh:150–163；plan-review.sh:172–183 同样存在。TC-06.log:7–18 已展示实际触发：两个 PID 的 /proc/cmdline 均已不存在，A 正常退出 0，但 B 仍宣称它们是被强杀后遗留的进程并给出 kill 指令。扫描结果是过期快照，不能以读取 cmdline 失败推断遗留。建议输出前重新核验锁冲突及目标仍持锁的事实；已结束时提示重跑，不输出过期终止名单，并增加该交错场景的断言。
- [major] R-03 codex 主进程先退出时会跳过后代清理，遗留进程可继续持锁。
  - 详情:定位：.ai-workflow/scripts/review.sh:248–249；plan-review.sh:261–262。非看门狗路径在 wait 后立即清空 codex_pid，使 EXIT cleanup 不再清理受管会话。例如 codex 启动后代后异常退出，后代仍运行并继承 fd 9，脚本会返回 exit 3，但看门狗已停止，后续评审仍被锁阻塞。建议在清空会话标识前检查并清理剩余受管进程，覆盖正常及异常退出路径；补充主进程先退出、后代继续存活的回归用例。

## 总评
实现总体遵循方案，但存在并发诊断失真、退出清理遗漏及 A 档证据不完整的问题，本轮判定 fail。已逐条核对 20 条 A 档用例，完成只读 Shell 语法与 diff 检查；未运行任何测试。

VERDICT: fail
