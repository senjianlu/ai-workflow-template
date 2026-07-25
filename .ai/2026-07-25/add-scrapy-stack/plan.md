---
status: approved
task: add-scrapy-stack
date: 2026-07-25
approved_at: 2026-07-25 (第 7 轮 plan 评审 pass 后经用户确认)
plan_review_max_rounds: 10
---

# 方案:在模板中新增 Scrapy 爬虫标准栈

## 背景与目标

模板当前只定义了前端两套栈(Next.js)与后端一套栈(FastAPI),没有爬虫栈。
用户有存量 Scrapy 项目 steammarket-spider(将按本标准重构),需要:

1. 把 Scrapy 作为标准栈写入 AGENTS.md 技术栈,设计按最佳实践而非照搬现状:
   - 数据层复用后端标准(Postgres + SQLAlchemy async + redis-py/Valkey),
     不采纳现状的 MongoDB/beanie;
   - 部署形态写 .egg + scrapyd(dopilot 编排),这是实际生产路径;
   - 反爬对抗等按需组件列为"按需引入"的可选扩展区,不进标准表;且按
     用户 2026-07-25 的明确要求,**治理产物只写组件类别、不点名具体
     工具**(按需引用的具体选型不在模板中暴露),引入时仍须在项目
     docs/decisions/ 记录理由;
   - 沿用模板硬约定:Python 包具名(不得叫 `app`)、模块名 snake_case、
     依赖约束写 pyproject.toml(setup.py 仅承担 .egg 打包)。
2. Scrapy 纳入评审流程:review-standards.md「技术栈评审关注点」新增
   Scrapy 条目。
3. 明确存量项目迁移时须剔除与当前项目无关的技术栈(README 迁移步骤
   显式化,含技术栈表、评审关注点、栈 skill 三处联动裁剪)。
4. 新建栈 skill `.claude/skills/rawf-stack-scrapy/SKILL.md`(初始化、
   编码与测试约定);fastapi/frontend 两个空壳 skill 本次不动。
5. 本任务确立的是模板级关键决策(标准栈边界、数据层与部署形态取舍),
   按仓库收尾纪律回写 `docs/decisions/0007-scrapy-standard-stack.md`
   (回应评审 R-01)。

参考现状:steammarket-spider(Scrapy 2.13,包名 `app`,camelCase 模块名,
requirements.txt 管依赖,Mongo/beanie 数据层)——其偏差之处即本标准要
纠正的方向,重构该项目属后续独立任务,不在本任务范围。

**plan 评审轮次上限授权记录**(回应四轮 R-01):默认上限 3 轮已用尽
(第 1–3 轮均 fail 并逐轮修订);用户于 2026-07-25 会话中明确指示
"放宽到最大 10 轮",据此在 frontmatter 写入 `plan_review_max_rounds: 10`
(机制见 docs/decisions/0003)。该授权将在面向用户的方案摘要中一并声明。

## 改动范围

| 文件 | 动作 |
|---|---|
| `AGENTS.md` | 技术栈「后端」之后新增「### 爬虫」小节(标准表 + 可选扩展区 + 工程约定),带 `TEMPLATE:` 裁剪注释 |
| `.ai-workflow/review-standards.md` | 「技术栈评审关注点」新增 Scrapy 条目 |
| `README.md` | 「存量项目迁移」第 2 步显式写明剔除无关技术栈(AGENTS.md 表、review-standards 关注点、栈 skill 三处联动) |
| `.claude/skills/rawf-stack-scrapy/SKILL.md` | 新建(初始化、编码与测试约定) |
| `docs/decisions/0007-scrapy-standard-stack.md` | 新建决策记录(标准栈边界、数据层复用后端、scrapyd 部署链路、可选扩展区) |

明确不动:workflow 脚本(review.sh / plan-review.sh / hooks)、
`rawf-stack-fastapi` 与 `rawf-stack-frontend` 空目录、
`docs/architecture/`(本仓库自身形态未变,爬虫栈是模板输出物的约定,
落 decisions 即可;architecture 导航无需新增条目)、steammarket-spider
仓库本身。共 5 文件,≤ 10,plan 评审为用户主动要求执行。

## 实现方案

### 1. AGENTS.md「### 爬虫」小节

置于「### 后端」与「### 部署」之间,开头 `<!-- TEMPLATE: 无爬虫需求则
整节删除;删除时同步删 review-standards.md 的 Scrapy 关注点与
rawf-stack-scrapy skill。 -->`。内容:

标准表(与后端栈共享的行注明"同后端"):

| 类别 | 技术 | 版本 |
|---|---|---|
| 语言 | Python(同后端) | ≥3.11,新项目取 3.12 |
| 爬虫框架 | Scrapy(2.13+ 默认启用 asyncio reactor,即 `TWISTED_REACTOR = "twisted.internet.asyncioreactor.AsyncioSelectorReactor"`;不得改回旧 reactor) | 2.13+ |
| 解析 | parsel(Scrapy 内置 Selector);beautifulsoup4 按需 | — / 4.x |
| 数据落地 | SQLAlchemy(asyncio)+ psycopg[binary],Postgres(同后端) | 2.0.x / 3.x |
| 缓存/去重/队列 | redis-py(Valkey 兼容,同后端) | 5.x+ |
| 配置 | pydantic-settings 管环境配置(同后端) | 2.x |
| 辅助 HTTP | httpx(同后端) | 0.27+ |
| 打包 | scrapyd-client(`scrapyd-deploy --build-egg` 构建 `.egg`);依赖约束仍写 pyproject.toml,setup.py 仅承担 .egg 打包,且**必须**声明 scrapyd 入口点 `entry_points={"scrapy": ["settings = <snake_name>.settings"]}`(scrapyd 靠它从 egg 定位 settings、发现 spider,缺失则 addversion 后无法调度) | 2.x |

部署链路(回应评审 R-03/二轮 R-01,三段式,接口与责任归属明确):

1. **构建**:CI(GitHub Actions)用 `scrapyd-deploy --build-egg` 产出
   `.egg`(egg 内含上表的 `scrapy` settings entry point);
2. **发布**:CI 将 `.egg` 上传 GitHub Release;
3. **注册与调度**:dopilot 按 `dopilot.toml` 声明拉取 Release 产物,调用
   scrapyd `addversion.json`(project/version/egg)注册;**定时与手动
   触发一律经 scrapyd `schedule.json`**(必带 project/spider,按需带
   `_version` 钉版本;爬虫参数 `-a key=value` 对应表单参数,设置覆盖
   `-s KEY=VALUE` 对应 `setting` 参数)——不直接 shell 执行
   `scrapy crawl`,否则绕开已注册的 egg 版本。

不经 dopilot 直连 scrapyd 的项目,改在 `scrapy.cfg` 配置 `[deploy]`
target(url/project),用 `scrapyd-deploy <target>` 完成构建+注册一步走,
调度同样经 `schedule.json`。两条路径都以 scrapyd 为运行时,`scrapy.cfg`
的 `[settings]` 段必须存在(本地 `scrapy crawl` 开发调试用)。

**运行环境依赖供给**(回应五轮 R-01):scrapyd 注册 egg **不安装依赖**,
egg 只运载项目代码;SQLAlchemy、psycopg、redis-py 等运行时依赖由
scrapyd 运行环境预装——dopilot 路径下即 dopilot 管理的 scrapyd
基础镜像按项目 pyproject.toml 安装,项目依赖变更时镜像同步重建;
直连路径下由 scrapyd 宿主环境的运维方承担同一责任。依赖版本约束的
唯一权威仍是 pyproject.toml。

可选扩展区(按需引入,引入时在项目 docs/decisions/ 记录理由;只列
**类别**、不点名具体工具——按需引用的具体选型属项目私有,不在模板
中暴露):浏览器渲染与指纹对抗、抓包代理、跨系统消息、AI 辅助解析、
对象存储上传等。

工程约定:

- 包具名(如 `<snake_name>/`),**不得命名为 `app`**(与 Next 路由目录
  规则冲突,多应用同仓 `import app` 撞车);模块文件名 snake_case
- 包内按 Scrapy 惯例分子模块:`spiders/`(含 base.py 基类)、
  `pipelines/`、`middlewares/`、`extensions/`、`items.py`、`settings.py`;
  `scrapy.cfg` 在应用根;`tests/` 与包平级镜像包结构(同后端约定)
- 阻塞调用不得混入 reactor/事件循环:下沉 `asyncio.to_thread` 或
  Twisted `deferToThread`
- spider 解析逻辑必须可离线测试:响应样本(HTML/JSON fixture)入
  `tests/fixtures/`,用 `scrapy.http.HtmlResponse`/`TextResponse` 构造
  离线响应喂给 parse 方法;单元测试不访问真网
- 开发与测试工具同后端(pytest 8.x + ruff)

### 2. review-standards.md Scrapy 关注点

在「技术栈评审关注点」列表 Python/FastAPI 行后新增一行,行首固定为
`- Scrapy:`(供评审 grep):

- Scrapy:阻塞调用混入 reactor/事件循环、selector 取值无防御
  (裸下标/无 default 导致页面结构变化即崩)、pipeline/middleware
  异常吞噬致 item 静默丢失、去重/限速/重试配置被关闭或绕过、
  解析测试依赖真网(须用本地 fixture 响应)

### 3. README 存量项目迁移显式剔除步骤

第 2 步「换工作流层」中"AGENTS.md 按模板结构重写(技术栈表按该项目
裁剪)"扩写为明确动作:**剔除与当前项目无关的技术栈**,且三处联动——
AGENTS.md 技术栈表、review-standards.md 对应评审关注点、
`.claude/skills/rawf-stack-*` 对应栈 skill,避免残留的无关栈误导
评审与开发。

### 4. rawf-stack-scrapy SKILL.md

路径 `.claude/skills/rawf-stack-scrapy/SKILL.md`。frontmatter:
`name: rawf-stack-scrapy`,description 说明"Scrapy 爬虫栈的初始化、
编码与测试约定,新建爬虫应用或为爬虫应用写代码/测试时使用"。
正文固定三节,标题为 `## 初始化`、`## 编码`、`## 测试`(供评审 grep;
SKILL.md 写操作细则,AGENTS.md 写事实约束,细则以引用为主):

- **初始化**:pyproject.toml(deps + ruff/pytest 配置)+ 具名包骨架
  (spiders/base.py、settings.py、items.py、pipelines/、middlewares/)+
  scrapy.cfg([settings] 必有;直连 scrapyd 时加 [deploy])+ setup.py
  (.egg 打包,必须含 `entry_points={"scrapy": ["settings =
  <snake_name>.settings"]}`)+ tests/ 镜像 + .env.example
- **编码**:settings 走 pydantic-settings;新 spider 继承 base.py 基类;
  阻塞下沉线程;可选扩展引入须记 docs/decisions/
- **测试**:fixture 响应离线测 parse(用 `scrapy.http.HtmlResponse` /
  `TextResponse` 构造,样本入 `tests/fixtures/`);pipeline 用内存/替身
  (fakeredis、aiosqlite)测;`scrapy check`/`scrapy crawl <spider>
  -s CLOSESPIDER_ITEMCOUNT=N` 仅作本地冒烟,不进 CI 断言

### 5. docs/decisions/0007-scrapy-standard-stack.md

按 decisions/README.md 四段体例:

- 日期:2026-07-25
- 背景:模板缺爬虫栈;存量 steammarket-spider 将按标准重构
- 决定:Scrapy 2.13+ 入标准栈;数据层复用后端 Postgres+SQLAlchemy
  (否掉照搬 Mongo/beanie 现状)、部署走 .egg → scrapyd/dopilot 三段
  链路(否掉 Docker 统一)、反爬组件全部入可选扩展区(否掉进标准表);
  存量迁移剔除无关栈须三处联动
- 影响:AGENTS.md 技术栈、review-standards.md 关注点、rawf-stack-scrapy
  skill;steammarket-spider 后续重构以此为准

## 测试用例

约定:命令均在仓库根执行,**权威命令在表格下方「测试命令」代码块中**
(回应三轮 R-01:命令不放表格内,避免 Markdown 表格对 `|` 的转义使其
不可执行);表格「步骤」列只引用对应代码块。中间产物(节文本、
git status 快照)一律落任务 `evidence/`。每条关键约定各有独立断言,
任一遗漏即打印 `MISS` 并以非 0 退出;TC-08 为反向对照,证明断言非恒真。

| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A(标准表与部署契约) | 改动完成 | 执行下方「TC-01 命令」 | 24 个关键词逐一命中:reactor 路径、数据层四件套(SQLAlchemy/psycopg[binary]/Postgres/redis-py)、依赖归属 pyproject、egg 构建与**完整** settings entry point 映射、三段责任(CI 构建 GitHub Actions、发布 GitHub Release、dopilot.toml 注册)、addversion.json 必填(project/version/egg)、schedule.json 必填(project/spider)与 `_version` 钉版、禁止绕过 scrapyd 直接 crawl、scrapy.cfg 的 [settings]/[deploy]、运行环境依赖供给(egg 不安装依赖、基础镜像按 pyproject 预装)、可选扩展区、TEMPLATE 注释;输出 OK、退出码 0,任一缺失则输出 `MISS: <词>`、退出码 1 | 命令 + 完整输出 + 退出码,落 evidence/ |
| TC-02 | A(评审关注点完整性) | 同上 | 执行下方「TC-02 命令」 | 行首 `- Scrapy:` 条目存在,五类关注点(阻塞混入 reactor、selector 无防御、异常吞噬、去重/限速/重试被绕过、离线 fixture)关键词逐一命中,输出 OK、退出码 0 | 同上 |
| TC-03 | A(迁移剔除三处联动) | 同上 | 执行下方「TC-03 命令」 | 迁移节含"剔除"动作并逐一点名 AGENTS.md 技术栈表、review-standards 评审关注点、rawf-stack 栈 skill 三处联动,输出 OK、退出码 0 | 同上 |
| TC-04 | A(skill 结构与实质内容) | 同上 | 执行下方「TC-04 命令」 | 文件在确定路径,frontmatter 与三节标题齐全,且逐项断言:scrapy entry point、pyproject 依赖归属、包骨架全件(spiders/base.py、settings.py、items.py、pipelines/、middlewares/、scrapy.cfg、setup.py、.env.example)、pydantic-settings、替身(fakeredis/aiosqlite)、离线响应构造(HtmlResponse/TextResponse + tests/fixtures/)、冒烟边界(CLOSESPIDER_ITEMCOUNT),输出 OK、退出码 0 | 同上 |
| TC-05 | A(非 happy-path,防回归与范围控制) | 同上 | 执行下方「TC-05 命令」 | 既有前端两栈、FastAPI 关注点、部署节未被破坏(REGRESSION-OK);含未跟踪文件在内改动仅落在 5 文件 + .ai/ 允许清单(SCOPE-OK);退出码 0,git status 快照留档 | 同上 |
| TC-06 | A(边界,规则一致性) | TC-01 已执行(复用其节文本) | 执行下方「TC-06 命令」 | 爬虫小节显式重申具名包(不得命名为 `app`)、snake_case 模块名、阻塞下沉线程三条工程约定,输出 OK、退出码 0 | 同上 |
| TC-07 | A(决策回写) | 改动完成 | 执行下方「TC-07 命令」 | 决策文件存在,标题编号与四段体例(日期 2026-07-25、背景、决定、影响)逐段断言,并覆盖部署、数据层、可选扩展区三项关键取舍,输出 OK、退出码 0 | 同上 |
| TC-08 | A(反向对照,证明断言可失败) | HEAD 仍为改动前提交 | 执行下方「TC-08 命令」 | 对改动前版本执行 TC-01 同款关键断言:输出 `0` 与 `exit=1`(无命中)——证明节内断言不是恒真式,确因本次改动才通过 | 同上 |

C 档 0 条(全部可由非交互命令判定)。

### 测试命令(权威,逐块整体复制执行)

TC-01 命令:

```bash
S=.ai/2026-07-25/add-scrapy-stack/evidence/spider-sec.txt
awk '/^### 爬虫/,/^### 部署/' AGENTS.md > "$S"
for kw in AsyncioSelectorReactor \
          SQLAlchemy 'psycopg[binary]' Postgres redis-py \
          pydantic-settings httpx pyproject.toml \
          scrapyd-deploy \
          'entry_points={"scrapy": ["settings = <snake_name>.settings"]}' \
          'GitHub Actions' 'GitHub Release' dopilot.toml \
          addversion.json 'project/version/egg' \
          schedule.json 'project/spider' '_version' \
          '不直接 shell 执行' '[settings]' '[deploy]' \
          '不安装依赖' 基础镜像 \
          可选扩展 'TEMPLATE:'; do
  if ! grep -F -q -- "$kw" "$S"; then echo "MISS: $kw"; exit 1; fi
done
echo OK
```

TC-02 命令:

```bash
E=.ai/2026-07-25/add-scrapy-stack/evidence/scrapy-entry.txt
grep -A6 '^- Scrapy:' .ai-workflow/review-standards.md > "$E"
for kw in 阻塞 selector 吞噬 去重 限速 重试 fixture; do
  if ! grep -q -- "$kw" "$E"; then echo "MISS: $kw"; exit 1; fi
done
echo OK
```

TC-03 命令:

```bash
M=.ai/2026-07-25/add-scrapy-stack/evidence/mig-sec.txt
awk '/^## 存量项目迁移/,/^## 机制速览/' README.md > "$M"
for kw in 剔除 AGENTS.md 技术栈表 review-standards 评审关注点 rawf-stack; do
  if ! grep -q -- "$kw" "$M"; then echo "MISS: $kw"; exit 1; fi
done
echo OK
```

TC-04 命令:

```bash
f=.claude/skills/rawf-stack-scrapy/SKILL.md
for pat in '^name: rawf-stack-scrapy' '^description:' \
           '^## 初始化' '^## 编码' '^## 测试'; do
  if ! grep -q -- "$pat" "$f"; then echo "MISS: $pat"; exit 1; fi
done
for kw in 'entry_points={"scrapy": ["settings = <snake_name>.settings"]}' \
          pyproject.toml 'spiders/base.py' \
          settings.py items.py pipelines/ middlewares/ scrapy.cfg \
          setup.py .env.example \
          pydantic-settings fakeredis aiosqlite \
          HtmlResponse TextResponse tests/fixtures/ CLOSESPIDER_ITEMCOUNT; do
  if ! grep -F -q -- "$kw" "$f"; then echo "MISS: $kw"; exit 1; fi
done
echo OK
```

TC-05 命令:

```bash
grep -q '^- Python/FastAPI:' .ai-workflow/review-standards.md \
  && grep -q '#### 栈 A' AGENTS.md \
  && grep -q '#### 栈 B' AGENTS.md \
  && grep -q '^### 部署' AGENTS.md \
  && echo REGRESSION-OK || { echo REGRESSION-FAIL; exit 1; }
G=.ai/2026-07-25/add-scrapy-stack/evidence/git-status.txt
git status --short > "$G"
extra=$(awk '{print $NF}' "$G" | grep -Ev \
  '^(AGENTS\.md|README\.md|\.ai-workflow/review-standards\.md|\.claude/skills/rawf-stack-scrapy/|docs/decisions/0007-|\.ai/)' \
  || true)
if [ -n "$extra" ]; then echo "OUT-OF-SCOPE: $extra"; exit 1; fi
echo SCOPE-OK
```

TC-06 命令:

```bash
S=.ai/2026-07-25/add-scrapy-stack/evidence/spider-sec.txt
grep -q '不得命名为' "$S" \
  && grep -q 'snake_case' "$S" \
  && grep -Eq 'to_thread|deferToThread' "$S" \
  && echo OK
```

TC-07 命令:

```bash
f=docs/decisions/0007-scrapy-standard-stack.md
for pat in '^# 0007' '^- 日期:2026-07-25' '^- 背景:' '^- 决定:' '^- 影响:'; do
  if ! grep -q -- "$pat" "$f"; then echo "MISS: $pat"; exit 1; fi
done
grep -q 'scrapyd' "$f" \
  && grep -Eq 'Postgres|SQLAlchemy' "$f" \
  && grep -q '可选扩展' "$f" \
  && echo OK
```

TC-08 命令:

```bash
git show HEAD:AGENTS.md | awk '/^### 爬虫/,/^### 部署/' \
  | grep -c 'AsyncioSelectorReactor'
echo "exit=$?"
```

## 风险与回滚

- **风险:标准与存量项目差距大**。steammarket-spider 的包名、模块命名、
  依赖管理、数据层均偏离本标准,后续重构工作量不小。缓解:本任务只定
  标准;重构另开任务,可分步(先命名与依赖,后数据层)。
- **风险:可选扩展区边界争议**。哪些组件算"标准"哪些算"按需"存在主观
  判断。缓解:已与用户确认取舍(数据层复用后端、反爬组件全部可选),
  并落 docs/decisions/0007 固化。
- **风险:部署链路描述与 dopilot 实际接口漂移**。dopilot 侧行为不受本
  仓库控制。缓解:AGENTS.md 只约定三段链路与责任归属,不复刻 dopilot
  配置细节;漂移时按 decisions 体例新增记录取代 0007。
- **回滚**:纯文档 + 新增 skill/决策文件,`git revert` 单提交即可完全
  回滚,无运行时影响。
