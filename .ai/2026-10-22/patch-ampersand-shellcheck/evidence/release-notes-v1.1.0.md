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

