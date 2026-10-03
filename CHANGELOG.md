# Changelog

本文件记录 ai-workflow-template 的版本历史,体例遵循
[Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/),版本号遵循
[SemVer](https://semver.org/lang/zh-CN/)(语义分级规则见 README
「版本与升级」)。

受管路径归类(每个版本条目的升级指引按此标注文件所属类别):

- 可整体替换:.ai-workflow/、.claude/hooks/、.claude/skills/rawf-*、.claude/settings.json、.githooks/、.gitmessage
- 需人工合并:AGENTS.md、CLAUDE.md、README.md、.agents/skills/、skills-lock.json

(需人工合并的原因:前三者 consumer 已按项目裁剪;后两者为项目内建
skill 目录及其内容哈希锁,consumer 可能持有自有条目,须经锁机制合并。
settings.local.json 属本机个人授权,不受管。)

每个版本条目必须含「升级指引」小节,逐文件标注归类与迁移动作。

## [1.0.1] - 2026-10-04

### Changed

- 评审脚本(review.sh / plan-review.sh)互斥锁由 mkdir 目录改为 flock
  文件(`.review-lock` / `.plan-review-lock`,常驻任务目录、永不删除,
  随持有进程退出自动释放);codex 以 `--json` 事件流落盘作进度信号,
  静默 15 分钟或总时长 60 分钟由看门狗按会话 + 进程组终止并 exit 3
  (`RAWF_REVIEW_IDLE_SECONDS` / `RAWF_REVIEW_MAX_SECONDS` /
  `RAWF_REVIEW_POLL_SECONDS` 可调);codex 的 stdin 固定接 /dev/null。
  运行环境要求 Linux 的 util-linux(flock、setsid)与 procps(pgrep)。
- gate-review.sh(Stop hook):当前任务的 `.review-lock` 被 flock 持有
  (评审进行中)时放行;其它情形维持原拦截。**hook 行为变更**(仅放宽:
  评审进行中不再拦截),按修复发布为 PATCH。
- rawf-review / rawf-plan skill:评审改为后台启动后直接结束回合,由完成
  通知唤回再分流;删除手工 pgrep / 删锁流程。
- 决策记录 docs/decisions/0009。

### Fixed

- codex 在 stdin 为管道/套接字时阻塞等待 EOF 导致评审永不开始;codex
  内部卡死(0% CPU)时评审无任何兜底;评审脚本被杀后残留锁目录。

### 升级指引

- 可整体替换:`.ai-workflow/scripts/review.sh`、
  `.ai-workflow/scripts/plan-review.sh`、`.claude/hooks/gate-review.sh`、
  `.claude/skills/rawf-review/SKILL.md`、`.claude/skills/rawf-plan/SKILL.md`。
- 需人工合并:`.gitignore`(增 `.ai/**/.review-lock`、
  `.ai/**/.plan-review-lock` 两行)、`README.md`(前置依赖与机制速览)。
- **旧版锁目录迁移**:升级前若有评审被杀而遗留 `.review-lock/` 或
  `.plan-review-lock/` **目录**,新脚本会报"旧版锁目录"并 exit 3;确认
  `pgrep -f 'codex exec'` 无旧评审进程后 `rmdir` 该目录再重跑,一次性操作。
- 新增环境要求:util-linux(flock、setsid)、procps(pgrep);macOS 需
  自行补齐。

## [1.0.0] - 2026-07-25

首个版本,当前形态:rawf 开发工作流(plan 与实现两级 Codex 评审、
测试证据协议、hooks 硬闸门)、标准技术栈(前端两套 / 后端 FastAPI /
爬虫 Scrapy)、版本与升级机制(TEMPLATE-VERSION + 本文件 + README
升级流程)。

### 升级指引

基线版本,无升级来源。
