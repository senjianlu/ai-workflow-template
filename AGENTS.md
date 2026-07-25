# 项目说明

<!-- TEMPLATE: 一两句话描述本项目。 -->

本文件面向进入本仓库的任何 AI 编码工具(AGENTS.md 开放标准),只描述
项目事实与通用约束,不为任何工具指派角色。

## 技术栈

<!-- TEMPLATE: 前端两套标准栈二选一,删除未选的一套;业务库与"按需"行按项目增删。 -->

版本号:前端以各项目锁文件(pnpm-lock.yaml)实际解析结果为准,后端
约束写在 pyproject.toml(无锁文件);表格只在大版本升级时更新,括号
内的注记是选型决策,不随版本浮动。

### 前端

两套标准栈,新项目二选一。共享底座:

| 类别 | 技术 | 版本 |
|---|---|---|
| 框架 | Next.js(App Router) | 16.x |
| UI 库 | React / React DOM | 19.x |
| 语言 | TypeScript | 5.x |
| 样式 | Tailwind CSS(@tailwindcss/postcss)+ tw-animate-css | 4.x / 1.x |
| 组件体系 | shadcn/ui(手写组件入库,非 npm 包) | — |
| 无障碍基座 | radix-ui(umbrella 包,聚合各 @radix-ui/*) | 1.x |
| 图标 | lucide-react | 1.x |
| 工具类 | clsx、tailwind-merge、class-variance-authority | — |
| 主题 | next-themes(light / dark / system) | 0.4.x |
| 包管理 | pnpm | — |

#### 栈 A:前后端分离、静态导出(参考 senjianlu/dopilot 的 apps/web)

Next `output: "export"` 产出纯静态文件,由后端(FastAPI)静态托管,
无 Node 生产运行时;数据一律经 axios 调后端 API。shadcn 取 new-york
风格、slate 基色。

业务相关库:

| 用途 | 库 | 版本 |
|---|---|---|
| 国际化 | i18next + react-i18next | 24.x / 15.x |
| HTTP 客户端 | axios | 1.x |
| 图表 | recharts | 3.x |
| 通知 toast | sonner | 2.x |

开发与测试工具:

| 类别 | 技术 | 版本 |
|---|---|---|
| 单元测试 | Vitest + jsdom + @testing-library(react / jest-dom / user-event) | 2.x / 25.x |
| E2E | Playwright | 1.x |
| Lint | ESLint(flat config)+ typescript-eslint + react-hooks 插件 | 9.x / 8.x |
| 类型检查 | tsc --noEmit(独立 script,不阻塞构建) | — |

#### 栈 B:Next 全栈一体(参考 cscheap-frontend)

独立 Next 应用,SSR 与服务端能力齐备,认证与数据层都在 Next 内解决。
shadcn 取 radix-nova 风格、neutral 基色。

业务相关库:

| 用途 | 库 | 版本 |
|---|---|---|
| 国际化 | next-intl | 4.x |
| 认证 | better-auth | 1.x |
| ORM 与数据库 | drizzle-orm / drizzle-kit + Neon serverless Postgres | 0.45.x / 0.31.x |
| 表单与校验 | react-hook-form + @hookform/resolvers + zod | 7.x / 5.x / 4.x |
| 文档站 | fumadocs(core / mdx / ui) | 16.x |
| 动画 | motion | 12.x |
| 字体 | geist | 1.x |

开发与测试工具:

| 类别 | 技术 | 版本 |
|---|---|---|
| Lint | ESLint + eslint-config-next + eslint-config-prettier | 9.x / 16.x |
| 格式化 | Prettier | 3.x |
| 单元测试 | 暂未引入 | — |

### 后端

一套标准栈(参考 senjianlu/dopilot 的 apps/server 与
senjianlu/cscheap-api)。全面异步:ORM 走 async engine,阻塞库经
asyncio.to_thread 下沉线程池,不得直接混入事件循环。

| 类别 | 技术 | 版本 |
|---|---|---|
| 语言 | Python | ≥3.11,新项目取 3.12 |
| Web 框架 | FastAPI + uvicorn | 0.110+ / 0.27+ |
| 校验与配置 | Pydantic(+ pydantic-settings 管环境配置) | 2.x |
| ORM 与数据库 | SQLAlchemy(asyncio)+ psycopg[binary],Postgres | 2.0.x / 3.x |
| 数据库迁移 | Alembic(schema 需演进时引入) | 1.x |
| 缓存与消息 | redis-py(Valkey 兼容;跨进程传输用 Redis Streams) | 5.x+ |
| HTTP 客户端 | httpx(异步;FastAPI TestClient 也依赖它) | 0.27+ |
| 任务调度 | APScheduler(按需) | 3.x |
| 打包 | hatchling 或 setuptools,提供 console-script 入口 | — |

依赖注意:解析易出事故的依赖(如 psycopg)可用 == 精确钉死并注明
理由,升级须手动、刻意。

开发与测试工具:

| 类别 | 技术 | 版本 |
|---|---|---|
| 测试 | pytest(异步用例开 asyncio_mode=auto);替身按需 fakeredis、aiosqlite | 8.x |
| Lint | ruff(select 至少 E / F / I / W / UP / B;行宽 88 或 100,项目内统一) | 0.x |
| 类型检查 | 暂未引入 | — |

### 爬虫

<!-- TEMPLATE: 无爬虫需求则整节删除;删除时同步删
     .ai-workflow/review-standards.md 的 Scrapy 关注点与
     .claude/skills/rawf-stack-scrapy skill。 -->

一套标准栈(数据层、配置与工具链尽量复用后端标准,降低维护心智负担)。

| 类别 | 技术 | 版本 |
|---|---|---|
| 语言 | Python(同后端) | ≥3.11,新项目取 3.12 |
| 爬虫框架 | Scrapy(2.13+ 默认启用 asyncio reactor,即 `TWISTED_REACTOR = "twisted.internet.asyncioreactor.AsyncioSelectorReactor"`;不得改回旧 reactor) | 2.13+ |
| 解析 | parsel(Scrapy 内置 Selector);beautifulsoup4 按需 | — / 4.x |
| 数据落地 | SQLAlchemy(asyncio)+ psycopg[binary],Postgres(同后端) | 2.0.x / 3.x |
| 缓存/去重/队列 | redis-py(Valkey 兼容,同后端) | 5.x+ |
| 配置 | pydantic-settings 管环境配置(同后端) | 2.x |
| 辅助 HTTP | httpx(同后端) | 0.27+ |
| 打包 | scrapyd-client(`scrapyd-deploy --build-egg` 构建 `.egg`);依赖约束仍写 pyproject.toml,setup.py 仅承担 .egg 打包,且**必须**声明 scrapyd 入口点 `entry_points={"scrapy": ["settings = <snake_name>.settings"]}`(scrapyd 靠它从 egg 定位 settings、发现 spider,缺失则注册后无法调度) | 2.x |

部署链路(三段式,接口与责任归属明确):

1. **构建**:CI(GitHub Actions)用 `scrapyd-deploy --build-egg` 产出
   `.egg`(egg 内含上表的 `scrapy` settings 入口点);
2. **发布**:CI 将 `.egg` 上传 GitHub Release;
3. **注册与调度**:dopilot 按 `dopilot.toml` 声明拉取 Release 产物,调用
   scrapyd `addversion.json`(必填 project/version/egg)注册;**定时与
   手动触发一律经 scrapyd `schedule.json`**(必填 project/spider,按需带
   `_version` 钉版本;爬虫参数 `-a key=value` 对应表单参数,设置覆盖
   `-s KEY=VALUE` 对应 `setting` 参数)——不直接 shell 执行
   `scrapy crawl`,否则绕开已注册的 egg 版本。

不经 dopilot 直连 scrapyd 的项目,改在 `scrapy.cfg` 配置 `[deploy]`
target(url/project),用 `scrapyd-deploy <target>` 完成构建+注册一步走,
调度同样经 `schedule.json`。两条路径都以 scrapyd 为运行时,`scrapy.cfg`
的 `[settings]` 段必须存在(本地 `scrapy crawl` 开发调试用)。

**运行环境依赖供给**:scrapyd 注册 egg **不安装依赖**,egg 只运载项目
代码;SQLAlchemy、psycopg、redis-py 等运行时依赖由 scrapyd 运行环境
预装——dopilot 路径下即 dopilot 管理的 scrapyd 基础镜像按项目
pyproject.toml 安装,项目依赖变更时镜像同步重建;直连路径下由 scrapyd
宿主环境的运维方承担同一责任。依赖版本约束的唯一权威仍是 pyproject.toml。

可选扩展(按需引入,引入时在项目 docs/decisions/ 记录理由;此处只列
**类别**、不点名具体工具——按需引用的具体选型属项目私有,不在模板中
暴露):浏览器渲染与指纹对抗、抓包代理、跨系统消息、AI 辅助解析、
对象存储上传等。

工程约定:

- 包具名(如 `<snake_name>/`),**不得命名为 `app`**(`app/` 只属于
  Next 路由目录,多应用同仓 `import app` 撞车);模块文件名 snake_case
- 包内按 Scrapy 惯例分子模块:`spiders/`(含 base.py 基类)、
  `pipelines/`、`middlewares/`、`extensions/`(按需)、`items.py`、
  `settings.py`;`scrapy.cfg` 在应用根;`tests/` 与包平级镜像包结构
  (同后端约定)
- 阻塞调用不得混入 reactor/事件循环:下沉 `asyncio.to_thread` 或
  Twisted `deferToThread`
- spider 解析逻辑必须可离线测试:响应样本(HTML/JSON fixture)入
  `tests/fixtures/`,用 `scrapy.http.HtmlResponse`/`TextResponse` 构造
  离线响应喂给 parse 方法;单元测试不访问真网
- 开发与测试工具同后端(pytest 8.x + ruff)

### 部署

- Docker(Dockerfile,必要时 docker-compose)
- GitHub Actions(.github/workflows/)

## 目录约定

<!-- TEMPLATE: 约定通用,无需裁剪;仅列承重目录,项目完整树见
docs/architecture/README.md。 -->

单应用仓库用扁平根布局(主流默认形)。**晋级规则**:出现第二个可
部署单元的那一刻,全仓升级为 apps/ + packages/,不允许"根上一个、
角落塞一个"的中间态。

仓库根:

| 目录 | 放什么 |
|---|---|
| `apps/<name>/` | 可部署单元(web、api、agent……) |
| `packages/<name>/` | 跨应用共享库;没有则不建 |
| `tests/` | 仅跨应用共享 fixtures;测试本体随各应用 |
| `docs/`、`.ai/` | 持久真相 / 过程痕迹(分工见 docs/README.md;`.ai/` 每个任务目录含 `evidence/` 证据与 `assets/` 资源子目录) |
| `deploy/` | Dockerfile 之外的编排(compose、反代配置) |
| `scripts/` | 仓库级辅助脚本 |
| `.github/workflows/`、`.agents/skills/` | CI / 项目内建 skill |

扁平态没有前三行,唯一应用的内部结构直接坐在根上;其余目录两态皆同。

应用内(扁平态与 apps/ 态规则一致,按应用类型取列):

| 位置 | 前端应用 | 后端应用 |
|---|---|---|
| 源码 | `app/`(Next 路由,框架固定)+ `components/`(`ui/` shadcn 手写件、`features/` 业务件)+ `lib/`、`hooks/` | `<snake_name>/` 具名 Python 包,按领域分子模块(routes/、jobs/、models/……) |
| 单元测试 | `__tests__/` 随源码同置 | `tests/` 与包平级,镜像包结构 |
| 端到端 | `e2e/`(specs/ + helpers/) | —(集成测试并入 tests/) |
| 数据迁移 | — | `migrations/` + alembic.ini(需要时) |
| 静态资源 / 国际化 | `public/`;`i18n/` + `messages/`(next-intl 栈) | — |
| 应用配置 | next.config.mjs、components.json | pyproject.toml |

原则:

- 应用一律平铺,不建 `src/`;packages/ 共享库可用 src-layout(打包
  最佳实践),本模板各参考库当前平铺
- `app/` 这个名字只属于 Next 路由目录;Python 包一律具名——多应用
  同仓时 `import app` 会撞车
- 多 Python 应用同仓时,根 pyproject.toml 只放共用 dev 工具配置
  (pytest 聚合 testpaths + importlib mode、ruff),不是可安装包
- 新顶级目录先记 docs/decisions/ 再开

## 通用硬规则(对任何 AI 工具生效)

- 永不主动 git commit / git push,必须用户明确确认
- `.ai/` 下是开发过程产物(方案/实现记录/评审记录),历史轮次文件只增不改
- `docs/` 下是持久设计真相(架构/决策),任务改变二者时须在收尾前回写,
  与代码同一提交(分工详见 docs/README.md)
- 开发必须走 rawf 工作流(由 Claude Code 驱动,细则见 CLAUDE.md),
  不得绕过其闸门与产物约定;预计触及文件 > 10 的改动,须在方案确认闸之前
  先经 plan 阶段 Codex 评审(plan-review,默认最多 3 轮,用户明确指定
  轮数时以其为准);≤ 10 不强制。
  细则见 CLAUDE.md
- 代码评审的角色约束、标准与严重度定义见 .ai-workflow/review-standards.md

## Git 提交规范

遵循 Conventional Commits,由 `.githooks/commit-msg` 钩子本地强制。
启用(克隆后执行一次):

```bash
git config core.hooksPath .githooks
git config commit.template .gitmessage
```

- header:`<type>(<scope>): <subject>`;scope 可选(小写短词,按项目
  约定);subject 祈使句、≤72 字符、不以句号结尾
- type 取 feat | fix | docs | refactor | perf | test | build | ci |
  chore | style | revert
- 正文(如有)说明动机与影响;不兼容变更用 `BREAKING CHANGE:` footer
  或 type 后加 `!`
- footer 约定:rawf 任务附 `Rawf: <yyyy-mm-dd>/<task-slug>`;引用权威
  文档用 `Refs:`;结对代理保留 `Co-Authored-By:`
- 一次提交一个主题;代码与其决策痕迹(.ai/ 任务目录)同一提交

## Skill 基线

<!-- TEMPLATE: 按项目填两份清单,空则写"(无)"。 -->

Agent skills 分两类管理:

- **项目内建**:随仓库提交在 `.agents/skills/`,由 `skills-lock.json`
  按内容哈希锁定(skills.sh CLI 安装/更新),对进入本仓库的任何 AI
  工具生效。当前:(无)
- **每机自装**:装在本机全局(如 `~/.claude/skills/`),不入库;新
  机器先按清单安装再开工。当前:(无)
