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

## [1.2.1] - 2026-10-22

### Fixed

- review.sh 注入证据报告(`{{EVIDENCE_REPORT}}`)前关闭 bash 5.2 默认开启的
  `patsub_replacement`:此前 B/C 档证据格原文中的 `&` 会被改写为占位字样、
  A 档 cmd 列 `%q` 转义的 `\&` 会丢反斜杠,注入给评审者的报告与 evidence-check
  原始输出不一致(A 档机器核验结论不受影响)。

### Changed

- 流程脚本 shellcheck 全级别零条:review.sh / plan-review.sh 删去 `lock_holders`
  中未用的局部变量;主流程与 `kill_codex_tree` 中未用的循环变量改为 `_`(并删去
  对应的 `local i`);evidence.sh 为经 trap 调用的 `on_sig` 加
  `shellcheck disable=SC2329` 注释。行为不变。

### 升级指引

- 可整体替换:`.ai-workflow/`(scripts 与 TEMPLATE-VERSION;consumer 若在
  review-standards.md 有项目自改小节,本版未改该文件,可只替换 scripts)。
- 无需人工合并项;hooks、settings.json、`.gitignore` 未变。

## [1.2.0] - 2026-10-22

### Added

- plan 评审分轮模式:第 1、2 轮全量穷尽评审(五个固定维度、一次列全、含
  minor,`overall` 逐维度一句结论),第 3 轮起收敛评审(先核上一轮
  plan-blocker/major,修订部分完整评审,未修订部分只报 plan-blocker)。
- plan-review.sh 每轮把 plan.md 快照为 `.plan-review-raw-NN.plan.md`,把模式行、
  上一轮评审文件与两轮快照间的修订 diff 注入 prompt 新占位 `{{ROUND_CONTEXT}}`;
  评审结束后核对 plan.md 与快照一致,不一致则本轮作废(exit 3,不发布、不消耗
  轮次)。注入前关闭 bash 5.2 默认开启的 `patsub_replacement`,diff 中的 `&`
  不会被改写。
- plan-review.sh 只读入口 `__minors <任务目录>`:汇总全部轮次的 minor;实现记录
  模板新增「plan 评审 minor 交接」节。
- review-standards.md:plan 阶段返工判据、分轮模式、实现层"机械性更正"条款。
- 决策记录 docs/decisions/0012。

### Changed

- plan 评审默认上限 3 → 5 轮(实现层修复默认 3 轮不变)。
- prompts/plan-review.md 按分轮模式与返工判据重写。
- rawf-plan:plan 写作粒度、修订纪律、评审运行期间不得修改 plan.md、默认 5 轮。
- rawf-implement:第 1 轮前经 `__minors` 做跨轮 minor 交接;机械性更正须回写
  plan 测试表并记"替代"偏差。
- CLAUDE.md、AGENTS.md:plan 评审默认 5 轮。

### 升级指引

- 可整体替换:`.ai-workflow/`(scripts、prompts、templates、review-standards.md——
  consumer 若在 review-standards.md 有项目自改小节,先摘出再覆盖)、
  `.claude/skills/rawf-*`。
- 需人工合并:`CLAUDE.md`(第 1b 步与轮次上限硬规则)、`AGENTS.md`(通用硬规则
  中的 plan 评审默认轮数)、`README.md`(机制速览)。
- 进行中的任务:plan 评审已跑过的轮次没有快照,第 3 轮起走全量回退分支,行为
  不劣于 1.1.0;frontmatter 已写 `plan_review_max_rounds` 的以其为准。
- `.gitignore`、hooks 与 settings.json 未变。

## [1.1.0] - 2026-10-22

### Added

- `evidence.sh`:A 档证据留证器,包住命令产出 rawf-evidence v1 文件
  (头部命令/cwd/git_head/时间,完整 stdout+stderr,尾部退出码/bytes);
  同名拒绝覆盖,中断仍写尾部,无锁无共享状态,与评审脚本的查杀无交集。
- `evidence-check.sh`:以 plan 用例表为基准机器核验实现记录(漏行、档位
  不符、空表、blocked)与每个 A 档证据文件的结构完整性(头部必填字段、
  退出码合法、bytes 与正文一致);不通过打印补交清单。review.sh 启动前
  调用,不通过直接 exit 3、codex 不启动、不消耗评审轮次;通过的报告注入
  评审 prompt。plan 无 `evidence_format: v1`(历史任务)则跳过。
- 范围自省(不量化、只提醒):plan 模板必填「需求原文」「非目标」;实现
  记录模板的偏差表分收窄/替代/追加三类并新增「停车场」;summary 模板新增
  「范围核对」;两级评审 prompt 各加一个固定范围问题,输出 schema 新增必填
  字段 `scope_findings`,渲染为评审文件的「范围核对」节(不计入 pass/fail)。
- 决策记录 docs/decisions/0010(证据格式 v1 与机器核验,部分取代 0006 的
  A 档条款)、0011(范围自省)。

### Changed

- review-standards.md:A 档证据形态改为 rawf-evidence v1;逐档核验规则中
  A 档的格式判定移交机器,评审只核命令对应、退出码与正文是否符合预期、
  记录与证据一致;新增「两种留证写法」(非零退出码不等于失败)、「阅读
  建议」与「范围核对」小节。
- prompts/review.md、prompts/plan-review.md:按上述职责重写;review.md 新增
  `{{EVIDENCE_REPORT}}` 占位。
- rawf-plan / rawf-implement / rawf-review / rawf-report skill:承接需求原文
  与非目标、范围自省三问、evidence.sh 留证与 evidence-check 自跑、追加类
  偏差须用户确认或入停车场、范围核对条目与停车场的裁决流程。
- CLAUDE.md 硬规则新增两条(A 档证据经 evidence.sh;追加类偏差不得自行
  实现)。

### 升级指引

- 可整体替换:`.ai-workflow/`(scripts、prompts、schemas、templates、
  review-standards.md——consumer 若在 review-standards.md「技术栈评审关注点」
  或项目特有小节有自改,先摘出再覆盖)、`.claude/skills/rawf-*`。
- 需人工合并:`CLAUDE.md`(硬规则增两条)、`README.md`(机制速览)。
- 进行中的任务:plan 无 `evidence_format: v1` 走历史路径,行为与 1.0.1
  相同;要启用新机制,在其 plan.md frontmatter 加该字段并把 A 档证据改由
  evidence.sh 产出。
- hooks 与 settings.json 未变。

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
