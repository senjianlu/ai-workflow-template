# t0013:Cloudflare Worker 入标准栈,模板只定形态与基座,不写实现纪律

- 日期:2026-11-09
- 背景:模板已派生出三个 Cloudflare Worker 仓——cscheap-link(无状态公网 API +
  自托管中文参考文档)、cscheap-telegram(RPC 对内 + webhook / Bearer 接口 + Cron +
  D1)、cscheap-catalog(RPC 对内 + Cron 同步 + D1)。三仓都把模板的前端 / 后端 /
  爬虫栈裁掉后各自补写 Worker 约定;telegram(其 0015)与 catalog(其 0014)已收敛到
  同一套布局与工具链,catalog 明确建议回写模板为「Worker 应用」列。Cloudflare 官方
  「Workers Best Practices」给出配置、测试、可观测与反模式的通用建议。
- 决定:
  1. **Worker 入 AGENTS.md 标准栈,取两仓收敛形**:`WorkerEntrypoint` 默认导出承载
     fetch / scheduled / RPC 三类入口;`index.ts` 薄适配、`app.ts` 组合根;横切单文件
     模块平铺于根,每个外部协议一个目录,领域逻辑超过三个文件成目录;Vitest +
     @cloudflare/vitest-plugin;ESLint 类型感知 Promise 规则 + Prettier;pnpm;
     目录约定表新增「Worker 应用」列。
  2. **模板只写形态与基座,不写实现纪律**:D1 写入纪律、RPC 入参校验与返回形状、
     HTTP 信封与路径 / 错误码约定、幂等与"结果不确定"语义、Workers 限额数字都留在
     项目自己的 docs/ 与 review-standards 自改小节。评审关注点一节例外——它本是
     代码级反模式清单(同 Scrapy 条),收录官方列出的通用 Workers 反模式。
  3. **不新建栈 skill**:形态与基座写在 AGENTS.md 即可,初始化与测试的细节由项目
     按参考仓自取(用户裁决)。
  4. **D1 按需而非默认**:cscheap-link 无状态、无数据库,同样是合法形态;单环境的
     适用条件含"无状态"。
  5. **`nodejs_compat` 默认不开**:偏离官方"建议开启",理由是参考仓零运行时依赖、
     不需要 Node 内置模块;依赖需要时再开并记项目 decisions。
  6. **密钥管理工具不点名**:写"`wrangler secret` 或外部密钥管理同步(项目决策)",
     具体选型属项目私有(同 t0007 可选扩展的做法)。
  7. **对外契约文档分三层**:仓内 docs/architecture/(overview / 契约 / deploy);
     面向公网调用方的服务自托管 HTML + `/llms.txt` + 机器契约,与执行同源;RPC 以
     导出类型为契约,不另做公网文档。
  - 被否:把 Hono + chanfana(官方 OpenAPI 库)定为标准路由——HTTP 面小的仓
    (telegram 三条路由、catalog 一条)引入框架得不偿失,需要时项目自行引入并记
    decisions;`src/` 布局——与"应用一律平铺"冲突,官方文档也未规定目录;照
    cscheap-link 现形(`worker/` 子目录、普通 `ExportedHandler`、npm)定标准——它
    早于另两仓,形态未收敛。
- 影响:AGENTS.md 新增「技术栈 > Cloudflare Worker」与目录表一列;
  review-standards.md 新增 Workers 评审关注点;`.gitignore` 新增 Workers 本地变量与
  生成文件条目。consumer 升级时 AGENTS.md 按需人工合并。cscheap-link 与标准的偏差
  (目录、入口形态、包管理)只在此记录,是否对齐由该仓另开任务决定。

## 沿革

- 2026-11-10(1.4.0):两处澄清,决定本身不变。① AGENTS.md 的「参考」暂只点名
  cscheap-telegram——cscheap-catalog 当时尚未推送到远端,照着去看的人看不到收敛形;
  README「发布纪律」同时加一条:被点名的参考仓须已推送且远端可复核。上文背景里对
  catalog 的叙述是当时的事实,保持原样。② 决定 1 的「横切单文件模块平铺于根,每个
  外部协议一个目录,领域逻辑超过三个文件成目录」补了判定口径(什么算横切、外部
  协议目录的门槛、领域逻辑怎么计数),以 AGENTS.md「技术栈 > Cloudflare Worker」
  工程约定为准。来源:`.ai/2026-11-10/consumer-feedback-1.3.0/`。
