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

### 部署

- Docker(Dockerfile,必要时 docker-compose)
- GitHub Actions(.github/workflows/)

## 通用硬规则(对任何 AI 工具生效)

- 永不主动 git commit / git push,必须用户明确确认
- `.ai/` 下是开发过程产物(方案/实现记录/评审记录),历史轮次文件只增不改
- 开发必须走 rawf 工作流(由 Claude Code 驱动,细则见 CLAUDE.md),
  不得绕过其闸门与产物约定
- 代码评审的角色约束、标准与严重度定义见 .ai-workflow/review-standards.md

## Git 提交规范

- 提交信息:`<type>: <一句话摘要>`,type 取 feat | fix | refactor | docs | test | chore
- 摘要用祈使句,简明扼要;正文(如有)说明动机与影响
- rawf 任务的提交在摘要后附 `(rawf: <yyyy-mm-dd>/<task-slug>)`
- 一次提交一个主题;代码与其决策痕迹(.ai/ 任务目录)同一提交
