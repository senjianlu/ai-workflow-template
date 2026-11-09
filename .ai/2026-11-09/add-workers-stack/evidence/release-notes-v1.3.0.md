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

