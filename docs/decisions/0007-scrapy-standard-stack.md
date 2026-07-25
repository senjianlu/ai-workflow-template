# 0007:Scrapy 入标准栈,数据层复用后端标准,部署走 scrapyd 三段链路

- 日期:2026-07-25
- 背景:模板技术栈只有前端两套(Next.js)与后端一套(FastAPI),没有
  爬虫栈;存量 Scrapy 项目(steammarket-spider)将按模板标准重构,
  需要先把标准定下来。现状项目使用 MongoDB/beanie 数据层、包名 `app`、
  requirements.txt 管依赖,均与模板既有约定相悖,不宜照搬。
- 决定:Scrapy 2.13+ 进 AGENTS.md 标准栈,并作四项取舍——
  1. **数据层复用后端标准**(Postgres + SQLAlchemy async +
     psycopg[binary] + redis-py/Valkey),否掉照搬现状的 Mongo/beanie
     (避免同仓两套数据层的维护心智负担);
  2. **部署走 .egg → scrapyd 三段链路**(CI 构建、GitHub Release 发布、
     dopilot 调 addversion.json 注册 + schedule.json 调度;setup.py 必须
     声明 scrapy settings 入口点;运行环境依赖由 scrapyd 基础镜像按
     pyproject.toml 预装),否掉 Docker 统一部署(scrapyd 的版本管理与
     调度是实际生产路径);
  3. **反爬对抗等按需组件全部入可选扩展区**,否掉进标准表;且治理产物
     只写组件类别、不点名具体工具(按需引用的具体选型属项目私有),
     引入时在项目 docs/decisions/ 记录理由;
  4. **存量项目迁移时剔除无关技术栈须三处联动**:AGENTS.md 技术栈表、
     review-standards.md 评审关注点、rawf-stack-* 栈 skill 一并删。
- 影响:AGENTS.md 新增「技术栈 > 爬虫」小节;review-standards.md 新增
  Scrapy 评审关注点;新增 .claude/skills/rawf-stack-scrapy(操作细则,
  事实约束以 AGENTS.md 为权威);README 存量迁移步骤显式化剔除动作。
  steammarket-spider 后续重构(包改名、依赖归位、数据层迁移)以本决策
  为准,另开任务执行。
