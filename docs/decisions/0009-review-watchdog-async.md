# 0009:评审 codex 加事件流看门狗与 flock 锁,评审异步化(后台启动、完成通知唤回)

- 日期:2026-10-04
- 背景:Codex 评审反复"卡死":① codex 在 stdin 非终端时必读 stdin 到 EOF
  (`codex exec --help` 明示),而 Claude Code 后台 Bash 给的 stdin 形态不
  稳定(多数为 /dev/null,本任务第 5 轮 plan 评审即拿到 unix socket,codex
  阻塞 27 分钟、0% CPU、未创建会话);② codex 内部卡死(请求发出后再无
  响应)时脚本没有任何超时,唯一上限是 Claude Code 后台命令时限,到点杀
  外层 bash,codex 被遗弃、mkdir 锁目录残留;③ Stop hook 不区分"评审正在
  后台跑",skill 又要求"后台运行并等待完成",Claude 只能 sleep 轮询或被
  hook 拦下后自言自语再结束。历史数据(扫描 ~/.codex/sessions 中 1625 次
  评审):1595 次正常完成的 p99 总耗时 13.6 分钟、相邻事件最大间隔 p99
  2.9 分钟、最大 22.7 分钟;30 次未完成全部在 6 分钟内停止记录。
- 决定:
  - **stdin 兜底**:两个评审脚本调用 codex 一律 `</dev/null`。
  - **事件流看门狗而非 CPU 采样**:`codex exec --json` 事件流落盘,文件
    字节数不增长超过 `RAWF_REVIEW_IDLE_SECONDS`(默认 900)或总时长超过
    `RAWF_REVIEW_MAX_SECONDS`(默认 3600)即终止 codex、exit 3。按历史数据
    静默 15 分钟最多误杀 1 次(该次为 API 流断后反复重试),墙钟 60 分钟
    误杀 0 次。否掉 CPU 采样:codex 正常状态绝大多数时间也在等 API,CPU
    接近 0,找不到能分开"正常等待"与"卡死"的阈值;事件流是进度的直接度量。
  - **受管终止**:codex 经 `setsid` 启动,受管集合 = 同会话 ∪ 同进程组 ∪
    自身,TERM 等 10 秒后 KILL 升级;脚本 TERM/INT 时同样清理。强制要求
    Linux 的 util-linux 与 procps,不为无 setsid 的环境提供只杀直接子进程
    的降级路径(兑现不了完整清理)。
  - **flock 锁取代 mkdir 目录锁**:锁文件常驻、永不删除,fd 在脚本全程
    持有,持有进程(含继承 fd 的 codex)全部退出即自动释放——没有残留态,
    因此没有回收协议及其竞态。`flock -n -E 75` 以专用冲突码精确区分"被
    持有"与"探测错误"。脚本被 SIGKILL 而 codex 仍持锁时,下次评审经
    `/proc/<pid>/fdinfo` 的 FLOCK 锁行定位真正持锁进程并报告处置命令,
    **不自动杀进程**(用户裁定,避免按记录误杀)。旧版锁目录 → 报错 +
    一次性 rmdir 迁移指引。
  - **评审异步化**:skill 改为后台启动后直接结束回合,Claude Code 后台
    任务完成通知唤回后再分流;Stop hook 对当前任务的 `.review-lock` 做
    `flock -n` 试探,冲突码 75 即放行,其它一切(锁不存在、是目录、flock
    缺失、打开失败)fail-closed 维持拦截。否掉按 hook 输入 `background_tasks`
    的命令字符串匹配(无法区分仓库、任务与评审类型)。
  - 被否掉的其它备选:仅墙钟超时(会误杀 2/1595 的正常评审);轮询等待
    (浪费回合、与 hook 冲突)。
- 影响:
  - 评审脚本在 Linux 以外环境直接报缺少工具退出;consumer 升级时需合并
    .gitignore 两行并处理可能的旧版锁目录残留(见 CHANGELOG 升级指引)。
  - Stop hook 行为变更,发版建议按 MAJOR(实际由用户裁定按 PATCH 发布为 v1.0.1:变更仅为放宽放行条件)。
  - 异步唤回依赖交互会话;`claude -p` 无头模式在最终回复后约 5 秒杀后台
    shell,本机制不适用。
  - 残留风险:静默阈值若与 `--json` 事件粒度不匹配可调环境变量而不改结构;
    脚本被 SIGKILL 的罕见路径需用户按报告手动处置一次。
