# Changelog

本文件记录 ai-workflow-template 的版本历史,体例遵循
[Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/),版本号遵循
[SemVer](https://semver.org/lang/zh-CN/)(语义分级规则见 README
「版本与升级」)。

受管路径归类(每个版本条目的升级指引按此标注文件所属类别):

- 可整体替换:.ai-workflow/、.claude/hooks/、.claude/skills/rawf-*、.claude/settings.json、.githooks/、.gitmessage、docs/decisions/t*.md
- 需人工合并:AGENTS.md、CLAUDE.md、README.md、docs/decisions/README.md、.agents/skills/、skills-lock.json
- 项目自有,创建后即脱钩:CHANGELOG.md、logo.svg、.ai/ 下的任务目录、docs/decisions/ 纯数字系列(NNNN-*.md)

(需人工合并的原因:AGENTS.md、CLAUDE.md、README.md consumer 已按项目裁剪;
docs/decisions/README.md 里 consumer 维护着自己的决策索引;后两者为项目内建
skill 目录及其内容哈希锁,consumer 可能持有自有条目,须经锁机制合并。
项目自有类随 Use this template 带入,新建项目按 README「开新项目」第 3 步
重置或清理,此后模板升级不触碰。settings.local.json 属本机个人授权,不受管。)

每个版本条目必须含「升级指引」小节,逐文件标注归类与迁移动作。

## [1.5.1] - 2026-11-24

### Fixed

- 评审快照套用项目的排除清单:review.sh 生成每轮清单与内容快照时,未跟踪文件
  除了要未被 `.gitignore` 忽略,还要未被 `hash_excludes` 排除。此前登记在
  `hash_excludes` 里、但没有被 `.gitignore` 忽略的构建产物目录,每轮评审仍会被
  逐个算哈希并复制进任务目录。两套规则各自独立判断(排除清单里的反选模式不会
  把已忽略的文件带回快照);`.claude/` 下的未跟踪文件只看 `.gitignore`(其下的
  skill、hook 属于评审对象);已跟踪文件的改动不受影响。工作区指纹的口径不变。
- plan 评审的指令限长:两轮 plan 之间的修订 diff 超过 16 KiB 时落盘为
  `.plan-review-raw-NN.diff`,指令里只给路径与字节数;指令总长超过 100000 字节
  时拒绝启动并给出明确报错。此前修订 diff 全文内联,plan 很长且改动很大时
  codex 会以 `Argument list too long` 启动失败,原样重跑仍然失败。

### Changed

- 评审清单的 `head` 行增加第三列,记录纳入口径的摘要(`hash_excludes` 各项的
  哈希)。两轮清单的口径不同时回退为全量评审,不再逐项比对。
- 实现评审每一轮的指令都给出本轮清单的路径,评审对象以它为准:不在清单中的
  未跟踪文件不属于评审对象。实现评审指令与评审标准各补了这一句。

### 升级指引

- 可整体替换:`.ai-workflow/`(本版改了 scripts/review.sh、scripts/plan-review.sh、
  prompts/review.md、review-standards.md 与 TEMPLATE-VERSION)。consumer 若按
  `# TEMPLATE:` 注释在 review.sh 的 `hash_excludes` 里加过项目排除项,替换后须
  重新加回——加回之后它们对评审快照同样生效,不必再把同一批构建产物目录另行
  加进 `.gitignore`。review.sh 的 `nonproduct_globs` / `product_globs`、
  review-standards.md 末尾的「技术栈评审关注点」若做过裁剪,同样需要重新处理。
- 需人工合并:`README.md`——「机制速览」中 plan 评审一条,"注入修订 diff"之后
  补了"(超过 16 KiB 时落盘,指令里只给路径)"。
- 进行中的任务升级后,下一轮实现评审会回退为一次全量评审(1.5.0 写出的清单
  没有口径摘要),之后恢复修复核验;无需额外操作。
- hooks、settings.json、`.gitignore`、四个 rawf skill 未变。`.plan-review-raw-NN.diff`
  命中既有的 `.ai/**/.plan-review-raw-*` 忽略规则。

## [1.5.0] - 2026-11-24

> **不兼容提示**:本版改变了评审输出 schema、评审文件格式与证据判定规则,与
> 1.4.x 不兼容。按 README「版本与升级」的分级本属 MAJOR,经维护者裁定以中版本
> 发布。升级前先收尾全部在途任务;`.ai-workflow/` 与四个 rawf skill 必须一起
> 替换,不能只换其中一部分。

评审重定向:否决权只留给产品缺陷(实现阶段)与设计错误(plan 阶段),证据核验
交给机器,每个阶段的轮次与每轮的评审范围有明确边界(docs/decisions/t0015)。

### Changed

- **实现评审只拦产品缺陷,结论由脚本推导。**评审者不再自报 pass/fail。每条问题
  带 `file`(首要位置)与 `scenario`(失败场景);review.sh 先校验输出结构,再按
  `file` 做路径归类,把指向非产品路径(`.ai/`、`docs/`、根目录 README / CHANGELOG、
  测试目录与测试文件)或失败场景为空白的问题降为建议并带标记渲染;余下有
  blocker 或 major 即 fail。
- **证据由机器核验,评审者不核。**A 档证据统一以 exit 0 表示用例通过(预期非零
  退出的被测命令用断言包一层)。evidence-check.sh 除结构完整性外,还判定:每条
  用例结果为 `pass`、用例编号不重复、A 档证据归属本用例且退出码为 0、B / C 档
  证据栏非空。命令是否真的验证了用例、用例是否充分,由开发 AI 自证。
- **plan 评审只拦设计错误,默认上限 5 → 3 轮。**plan-blocker 与 major 须标明缺陷
  类别(`category`)并写明实现后果(`consequence`);验收与用例表、证据档位、措辞
  方面的意见是建议,不阻断;单纯的范围扩张只进范围核对。第 1 轮全量评审(调查
  按需),第 2 轮起核验评审。
- **修复轮只审修复。**review.sh 每轮保存所审改动的清单与内容快照,第 2 轮起
  生成轮间差异文件;评审者先核验上一轮的阻断问题,再审本轮变化,与本轮变化
  无关的新发现只收 blocker、其余至多 minor。
- **失败场景须在正常使用中可能出现。**blocker / major 的触发条件应是真实用户、
  真实数据或正常运行环境会遇到的情形(攻击者可控的输入算在内);只有在刻意构造的
  环境下才会出现的问题至多 minor。
- **建议由开发 AI 处置。**评审文件新增「测试缺口」「建议」两节,不计入 pass/fail、
  不触发修复轮;是否采纳由开发 AI 决定并留理由,收尾时汇总给用户。
- 评审文件格式:问题条目新增「位置」「失败场景」(实现评审)或「类别」「后果」
  (plan 评审)行;`plan-review.sh __minors` 的首列改为 `plan/NN/<编号>`,并入各轮
  的建议与降级条目。
- review-standards.md 重写;两份评审指令、三份模板、四个 rawf skill、CLAUDE.md、
  AGENTS.md、README.md 同步。

### Added

- `review.sh __minors <任务目录>`:汇总全部实现评审轮次的 minor、测试缺口、建议
  与降级条目,供 rawf-report 收尾使用(修复轮只审修复,首轮的 minor 不会在末轮
  重复出现)。
- review.sh 内的两份路径清单 `nonproduct_globs` 与 `product_globs`(标
  `# TEMPLATE:`,按项目增删)。目录按路径组件匹配,文件名规则只匹配文件名本身,
  通配符不跨目录;四种写法见清单上方的注释。
- 所审内容一致性检查:送审前与评审结束后各重算一次清单,与本轮保存的不同(含
  `.claude/` 下的 skill 与 hook)即判评审无效,不发布、不消耗轮次;内容快照的副本
  逐个核对哈希。
- 评审指令限长:变化文件列表与证据核验报告各自内联不超过 16 KiB,超出时前者在
  轮间差异文件里给出完整列表,后者落盘为 `.review-raw-NN.evidence.md`;指令总长
  超过 100000 字节时拒绝启动并给出明确报错。
- 评审输出的输入校验按 schema 核对键集合:缺字段、多字段(如旧版的 `verdict`)、
  小数行号、非字符串的枚举值都判为结构不合法。
- review.sh 的退出码 1 只表示"已发布一份 fail 评审":脚本中途异常中止而没有发布
  评审文件时,一律以 3(执行异常)结束。
- 评审清单带格式标记;上一轮清单无法按当前格式解读时回退为全量评审。变化文件
  列表与 diff 标签显示真实路径,含控制字符的路径以 `%XX` 编码显示并带标注。
- evidence-check 判定标记 `NO-FORMAT`、`DUP-ID`、`BAD-TIER`、`NOT-PASS`、
  `TC-MISMATCH`、`EXIT-NONZERO`、`NO-EVIDENCE`。
- 实现记录模板的「评审建议处置」表,小结模板的「评审建议及处置」节。
- 决策记录 docs/decisions/t0015。

### Removed

- 评审输出的 `verdict` 字段,以及"自报结论与严重度清单交叉校验"。
- 评审者逐条核验证据("对 A 档只核三件事"、B / C 档核验)。
- "exit 即被测命令退出码、非零不等于失败"的留证写法。
- "plan 未声明 `evidence_format: v1` 即跳过机器核验"的历史任务豁免:未声明时
  evidence-check 报 `NO-FORMAT`,不再退出 2。
- plan 评审的"第 1、2 轮全量穷尽、第 3 轮起收敛"分轮模式,以及"验收标准缺覆盖
  即 major""档位违规即 major"两条判据。
- rawf-review 中两条关于证据档位误报的申诉条款。

### 升级指引

- **升级前先收尾在途任务。**升级后,在途任务里"预期非零退出"的旧 A 档证据会被
  判 `EXIT-NONZERO`,未声明 `evidence_format: v1` 的旧 plan 会被判 `NO-FORMAT`,
  旧格式的评审输出也无法通过新的输入校验。确需带着在途任务升级时:给 plan
  补上 `evidence_format: v1`,对预期非零的用例用断言包一层后另起 label 重新留证。
- 可整体替换:`.ai-workflow/`、`.claude/skills/rawf-*`、`docs/decisions/t*.md`
  (新增 t0015,t0001 / t0003 / t0005 / t0006 / t0010 / t0012 顶部加了取代标注)。
  替换 `.ai-workflow/` 后做两件事:
  1. consumer 若按 `# TEMPLATE:` 注释在 review.sh 的 `hash_excludes` 里加过项目
     排除项,须重新加回;
  2. 按项目检查 review.sh 的两份路径清单:`nonproduct_globs` 缺省把 `docs/`、
     测试目录与测试文件视为非产品路径(指向它们的问题不阻断);文档即产品的
     项目(如文档站内容放在 `docs/` 下)把相应路径加入 `product_globs`
     (如 `'/docs/site/'`)。
     review-standards.md 末尾的「技术栈评审关注点」若做过裁剪,同样需要重新
     裁剪。
- 需人工合并:
  - `CLAUDE.md`:工作流第 1b 步的轮次说明(5 轮 → 3 轮,分轮方式);硬规则里
    新增"评审只拦产品缺陷与设计错误,结论由脚本推导"一条,评审轮次默认值改为
    plan 评审 3 轮,证据一条补"以 exit 0 表示用例通过""证据由机器核验"。
  - `AGENTS.md`:通用硬规则中 plan-review 的默认轮数 5 → 3。
  - `README.md`:「机制速览」中 review.sh、证据、plan 评审三条重写,新增"修复轮
    只审修复""建议由开发 AI 处置"两条;「已知限制」最后一条改写。
- hooks、settings.json、`.gitignore` 未变。评审快照(`.review-raw-NN.manifest`、
  `.review-raw-NN.snap/`、`.review-raw-NN.delta.diff`、`.review-raw-NN.evidence.md`)
  命中既有的 `.ai/**/.review-raw-*` 忽略规则,无需新增。
- 评审快照会复制"相对 HEAD 有改动的已跟踪文件 + 未被 `.gitignore` 忽略的未跟踪
  文件"(单文件不超过 1 MiB,只留最近两轮)。仓库里若有未被忽略的构建产物目录,
  先把它们加入 `.gitignore`,否则每轮评审都会把它们复制进任务目录。
- review.sh 新增对 diffutils(`diff`、`cmp`)的依赖,启动时预检,缺失即 exit 3。
- 已发布的历史评审文件不受影响:`__minors` 对旧格式评审文件只提取 minor。

## [1.4.1] - 2026-11-19

### Fixed

- review.sh 的工作区指纹不再为每个未跟踪文件单独启动一个 `shasum` 进程:内容
  哈希改为按参数容量分批交给 `sha1sum`(经 `xargs`)。未跟踪文件上万的仓库
  (典型是 `.ai/**/evidence/` 未提交)此前一次指纹要十分钟级,且每轮评审在
  Codex 前后各算一次;3000 个文件的夹具上实测由约一分钟降到 1 秒以内。指纹
  口径不变(类型 + 路径 + 可执行位 + 内容哈希,符号链接不跟随,排除清单不变;
  路径统一加 `./` 前缀交给 `sha1sum`,文件名恰为 `-` 的文件照旧按内容计入),
  指纹取值会变但只在单次运行内比对,无兼容影响。

### Changed

- review.sh 新增对 coreutils(`sha1sum`)与 findutils(`xargs`)的依赖,启动时
  预检,缺失即 exit 3。
- 指纹计算失败(工具缺失、哈希进程异常退出)时 review.sh 一律 exit 3:评审前
  失败不调用 Codex,评审后失败不发布评审文件。个别文件不可读仍按原行为容忍。

### 升级指引

- 可整体替换:`.ai-workflow/`(本版只改 scripts/review.sh 与 TEMPLATE-VERSION)。
  consumer 若按 `# TEMPLATE:` 注释在 review.sh 的 `hash_excludes` 里加过项目
  排除项,替换后须把这些排除项重新加回。
- 无需人工合并项;hooks、settings.json、`.gitignore` 未变。
- 运行环境须有 `sha1sum` 与 `xargs`(常见 Linux 发行版默认具备)。

## [1.4.0] - 2026-11-10

### Changed

- 模板决策改用 `t` 前缀独立编号:`docs/decisions/` 下的 `0001-*.md` ~ `0013-*.md`
  改名为 `t0001-*.md` ~ `t0013-*.md`(slug 不变,编号同号对应),正文互相引用与仓内全部
  `docs/decisions/NNNN` 引用同步加 `t`;纯数字 `NNNN` 整段留给派生项目。解决模板
  决策与派生仓自编决策撞号(docs/decisions/t0014)。流程脚本、gate-review.sh 与
  `.gitignore` 只改了注释里的路径,行为不变。
- AGENTS.md「技术栈 > Cloudflare Worker」:工程约定第 2 条补判定口径(横切模块 /
  外部协议 / 领域逻辑各自的定义与成目录门槛,附成目录与不成目录各一例),目录表
  Worker 列指向该口径;「参考」只点名 cscheap-telegram(cscheap-catalog 尚未推送)。

### Added

- 受管路径归类:「可整体替换」加入 `docs/decisions/t*.md`,「需人工合并」加入
  `docs/decisions/README.md`,新增第三类「项目自有,创建后即脱钩」(`CHANGELOG.md`、
  `logo.svg`、`.ai/` 下的任务目录、`docs/decisions/` 纯数字系列)。
- README「开新项目」新增第 3 步:重置 `CHANGELOG.md`、处理 `logo.svg`、删除 `.ai/`
  下模板带来的任务目录;原第 3 ~ 8 步顺延为 4 ~ 9。
- README「发布纪律」:受管文件点名的参考仓须已推送到远端且可复核。
- `docs/decisions/README.md` 写明模板决策与项目决策两个系列及旧编号对应。
- 决策记录 docs/decisions/t0014。

### 升级指引

- 可整体替换:`docs/decisions/t*.md`(本版起纳入)。在模板克隆 `/tmp/awt`(已
  `git checkout --detach v1.4.0`)就绪后,于项目仓库根执行下列命令:先删除随建仓
  带入的模板旧决策文件(只删清单里这 13 个完整文件名,项目自有的同编号决策不受
  影响),再拷入 `t` 系列。若项目改写过带入的模板决策正文,先自查 diff 再执行。

  ```bash
  AWT=${AWT:-/tmp/awt}
  for f in 0001-plan-stage-review.md 0002-task-evidence-assets-dirs.md \
    0003-configurable-review-round-caps.md 0004-review-action-boundary.md \
    0005-review-readonly.md 0006-test-evidence-tiers.md \
    0007-scrapy-standard-stack.md 0008-template-versioning.md \
    0009-review-watchdog-async.md 0010-evidence-format-v1.md \
    0011-scope-reflection.md 0012-plan-review-convergence.md \
    0013-workers-standard-stack.md; do
    rm -f "docs/decisions/$f"
  done
  cp "$AWT"/docs/decisions/t*.md docs/decisions/
  ```

  项目自有决策**不改号**:1.4.0 之前创建的项目若从 0013 起编,保持原号,前面的
  空号不补。项目文档里指向模板决策的旧编号(`docs/decisions/00NN`)改写为
  `docs/decisions/t00NN`。
- 可整体替换:`.ai-workflow/`、`.claude/hooks/`——脚本、hook 与 review-standards.md
  只改了决策路径引用(review-standards.md 的「技术栈评审关注点」若有项目自改,先
  摘出再覆盖);TEMPLATE-VERSION 随之更新为 1.4.0。
- 需人工合并:`docs/decisions/README.md`(本版起纳入)——并入两个系列的命名规则与
  「沿革:旧编号对应」一节,项目自有的决策索引、裁剪说明、取代关系原样保留。
- 需人工合并:`CLAUDE.md`——4 处 `docs/decisions/NNNN` 引用加 `t`。
- 需人工合并:`AGENTS.md`——Worker 项目并入工程约定第 2 条的判定口径与目录表
  Worker 列的指向;Worker 节里的决策引用改为 `docs/decisions/t0013`。非 Worker 项目可不合并。
- 需人工合并:`README.md`——模板自述,consumer 一般已重写;若保留了「机制速览」
  「已知限制」,其中的决策路径加 `t`。
- 项目自有(本版起明确,模板升级不触碰):存量项目若仍留着模板的 `CHANGELOG.md`
  内容、`logo.svg` 或 `.ai/` 下的模板任务目录,可按 README「开新项目」第 3 步自行
  清理,不清理不影响升级。
- 按需自取:`.gitignore` 仅一处注释里的决策路径加 `t`;`docs/README.md` 组织表的
  文件名约定同步了两个系列。
- settings.json、prompts、schemas、templates、skills 未变。

## [1.3.0] - 2026-11-09

### Added

- Cloudflare Worker 入标准栈(参考 cscheap-telegram 与 cscheap-catalog 的收敛形):
  AGENTS.md 新增「技术栈 > Cloudflare Worker」小节——标准表、四条形态级工程约定
  (`index.ts` 薄适配 + `app.ts` 组合根、目录成型规则、出站依赖注入、环境形态二选一)
  与对外契约文档三层;「目录约定 > 应用内」表新增「Worker 应用」列。模板只定形态与
  基座,D1 / RPC / HTTP 等实现纪律留给项目(docs/decisions/0013)。
- review-standards.md 技术栈评审关注点新增 `Cloudflare Workers` 条(官方通用反模式)。
- `.gitignore` 新增 Workers 本地变量与生成文件条目(`.dev.vars*`、保留
  `.dev.vars.example`、`worker-configuration.d.ts`、`.wrangler/`)。
- 决策记录 docs/decisions/0013。

### 升级指引

- 需人工合并:`AGENTS.md`——Worker 项目把「技术栈 > Cloudflare Worker」小节(位于
  「爬虫」与「部署」之间)与「应用内」表的「Worker 应用」列并入,并按项目实际裁剪其余
  栈;非 Worker 项目可不合并。
- 可整体替换:`.ai-workflow/`(review-standards.md 的「技术栈评审关注点」若有项目自改,
  先摘出再覆盖;TEMPLATE-VERSION 随之更新为 1.3.0)。
- 按需自取:`.gitignore` 不在受管路径,Worker 项目把新增的 Workers 块并入即可;
  `docs/decisions/0013` 作为模板历史随新建项目带入,存量项目可不拷。
- hooks、scripts、prompts、schemas、templates 与 settings.json 未变。

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
