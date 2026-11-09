---
status: approved
task: add-workers-stack
date: 2026-11-09
approved_at: 2026-11-09 22:25:19
evidence_format: v1
---

# 方案:Cloudflare Worker 入标准栈(形态与基座,不写实现纪律)

## 需求原文

> 请读取下 ../cscheap-link、catalog、telegram 等项目,了解它们的需求和功能点,然后为我
> 设计 cloudflare worker 项目的目录结构、rpc 接口、外部接口、外部展示文档等的最佳实践。
> 然后将其纳入 ai 工作流的目录结构规范和开发/测试规范中。评审都需要使用 6-astra high。
> 最佳实践你也最好去网上搜索下官方等的文档来进行了解。

后续对齐结论(用户裁决):

- "细节的实现似乎没有必要落文档。例如对 D1、RPC 等的约束?"——模板只写**形态与基座**
  (目录、入口形态、工具链、契约文档的形态),不写**实现纪律**(D1 写入纪律、RPC
  入参/返回形状、HTTP 信封与路径约定、幂等语义、限额数字),后者留在各项目自己的
  docs/ 与 review-standards 自改小节。
- "skill 也没必要吧"——不新建 `rawf-stack-workers` skill。
- 其余按默认:密钥管理工具在模板中不点名;`nodejs_compat` 默认不开;不做 CI 模板;
  不给评审脚本加模型透传(本任务评审经会话外 codex 包装器以 gpt-6-astra / high
  运行,仓内脚本与 `~/.codex/config.toml` 不改);plan 评审与实现评审全部轮次均用
  astra high;首轮 plan 评审须自主通读三个 Worker 仓后判断标准是否合适。
- 确认闸(plan 评审第 3 轮 pass 之后)用户追加:"确认,开始吧。做完之后发给中版本
  0.x+1.0 这样"——本任务一并发 MINOR 版 1.3.0(版本号进 CHANGELOG 与
  TEMPLATE-VERSION,同 1.2.1 先例);"之后的评审就用默认模型吧"——实现评审起
  不再经包装器,用 `~/.codex/config.toml` 默认模型。

**本任务交付**:AGENTS.md 新增「技术栈 > Cloudflare Worker」小节与目录约定表的
「Worker 应用」列;review-standards.md 新增 Workers 评审关注点;决策 0013;
`.gitignore` 的 Workers 条目;以 1.3.0 发版(CHANGELOG 条目与 TEMPLATE-VERSION)。

## 调研结论

三个 Worker 仓(均由本模板 1.2.1 创建):

| | cscheap-link | cscheap-telegram | cscheap-catalog |
|---|---|---|---|
| 形态 | 无状态公网 API + 自托管中文参考文档 | RPC 对内 + HTTP(webhook / Bearer 接口)+ Cron + D1 | RPC 对内 + Cron 同步 + D1,HTTP 仅健康检查 |
| 入口 | 普通 `ExportedHandler` | `WorkerEntrypoint` 默认导出 | `WorkerEntrypoint` 默认导出 |
| 布局 | `worker/` + `tests/`,npm | 根平铺 + 协议目录 `telegram/` + `test/`,pnpm | 根平铺 + `api/` + `sync/` + `test/`,pnpm |
| 对外文档 | `/` HTML + `/reference.json` + `/llms.txt`,与执行规则同源 | docs/architecture/notify.md 契约文 | docs/architecture/sync.md 契约草案 |
| 环境 | 单环境 + 自定义域名 | preview / production | 单环境(其 ADR 0018) |

- telegram(其 ADR 0015)与 catalog(其 ADR 0014)已收敛出同一套布局与工具链,
  catalog 的 ADR 明确写了"建议回写模板为「Worker 应用」列(另行任务)"。本方案
  以这套收敛形为标准。link 是更早形态,与标准有偏差;consumer 仓不改,只在决策里记。
- Cloudflare 官方「Workers Best Practices」中与**形态与基座**相关、本方案采纳的点:
  wrangler.jsonc 为配置真相源并钉 `compatibility_date`;`wrangler types` 生成运行时
  类型;secret 不入配置与源码;采用具名双环境时远端部署带 `--env`;
  `@cloudflare/vitest-plugin` 在 Workers 运行时内测试;开启 observability 与结构化
  日志;Service Binding 做 Worker 间调用。**刻意不采纳**:默认开 `nodejs_compat`
  (两仓零运行时依赖,需要时再开并记 decisions);`src/` 布局(与 AGENTS.md
  "应用一律平铺"冲突)。
- 官方反模式(进评审关注点):未处理的 Promise、模块级请求态、无界正文整体缓冲、
  密钥明文比较或入日志、`passThroughOnException` 代替错误处理。评审关注点一节是
  代码级反模式清单(同既有 Scrapy 条),不受"形态与基座"边界约束。

### 供评审自主核验的事实来源

评审在只读沙箱中可直接读取以下路径(无网络,官方文档以上文摘要为准):

- `/home/rabbir/Projects/cscheap-telegram`:AGENTS.md、docs/decisions/0015、
  docs/architecture/README.md、index.ts、app.ts、vitest.config.ts、test/helpers.ts
- `/home/rabbir/Projects/cscheap-catalog`:AGENTS.md、docs/decisions/0014、
  docs/architecture/README.md、index.ts、app.ts、.ai-workflow/review-standards.md
  「技术栈评审关注点」(项目级实现纪律的实例,本方案刻意**不**上提)
- `/home/rabbir/Projects/cscheap-link`:AGENTS.md、docs/architecture/api.md、
  worker/index.ts、wrangler.json(偏差样本与"同源文档"样本)
- 本仓对照物:AGENTS.md「技术栈 > 爬虫」与 docs/decisions/0007(上一次入栈的体例)

请评审者据此独立判断:标准表与形态约定是否忠实于两仓收敛结果、是否足以让新 Worker 仓
一眼可辨且不越界到实现纪律;有更合适的切分请直接提出。

## 改动范围

| 文件 | 改动 |
|---|---|
| `AGENTS.md` | 「技术栈」新增 `### Cloudflare Worker` 小节(标准表 + 形态级工程约定 + 对外契约文档三层),位于「爬虫」之后、「部署」之前;「目录约定 > 应用内」表新增「Worker 应用」列 |
| `.ai-workflow/review-standards.md` | 「技术栈评审关注点」新增 `- Cloudflare Workers:` 一条 |
| `docs/decisions/0013-workers-standard-stack.md` | 新增决策记录 |
| `.gitignore` | 新增 Cloudflare Workers 块(`.dev.vars`、`.dev.vars.*`、`!.dev.vars.example`、`worker-configuration.d.ts`、`.wrangler/`)。非需求直接要求,但入栈后 consumer 的本地变量与生成文件须默认不入库,两仓均已各自补加 |
| `CHANGELOG.md` | 新增 `## [1.3.0] - 2026-11-09`(Added)与「升级指引」(确认闸用户追加发版) |
| `.ai-workflow/TEMPLATE-VERSION` | `version: 1.3.0`(同上) |

共 6 个文件。不动:README.md(「开新项目」步骤已泛化到任意栈)、CLAUDE.md、
hooks、scripts、prompts、schemas、templates、任何 consumer 仓。

## 非目标

- 新建 `rawf-stack-workers` skill(用户裁决不建)
- 实现纪律:D1 写入纪律、RPC 入参校验与返回形状、HTTP 信封 / `/healthz` / `/v1/`
  路径约定、幂等与"结果不确定"语义、路由框架两档制、Workers 限额数字
- 迁移 cscheap-link 到标准形态;修改任何 consumer 仓
- Workers 的 CI 模板(.github/workflows 示例)
- review.sh / plan-review.sh 的模型 / effort 透传参数
- GitHub Release 页面的创建(本机无 gh CLI;同 1.2.1 先例,tag 推送后由用户在网页基于
  tag 创建,release notes 取 CHANGELOG 条目)

## 实现方案

### 1. AGENTS.md「技术栈 > Cloudflare Worker」

开头一句定位(单 Worker 应用;版本以 pnpm-lock 为准,表只在大版本升级时更新,
决策见 docs/decisions/0013),然后:

标准表(类别 / 技术 / 版本):

| 类别 | 技术 | 版本 |
|---|---|---|
| 运行时 | Cloudflare Workers(workerd;`compatibility_date` 钉定;`nodejs_compat` 默认不开,依赖需要 Node 内置模块时再开并记 decisions) | — |
| 语言 | TypeScript(strict + noUncheckedIndexedAccess) | 5.x |
| 入口 | `WorkerEntrypoint` 默认导出:`fetch`(HTTP)、`scheduled`(Cron)、公开方法即 Service Binding RPC | — |
| 数据 | D1 按需(有持久状态时;SQL 迁移在 `migrations/`,wrangler 管理);KV / R2 / Queues 按需;无状态服务不绑定数据层 | — |
| 出站 | 原生 fetch,不引 SDK(按需引入记 decisions) | — |
| 部署 CLI | wrangler(与 vitest 插件成对钉版本) | 4.x |
| 测试 | Vitest + @cloudflare/vitest-plugin(测试与 Worker 同 isolate,本地绑定) | 5.x / 1.x |
| Lint / 格式化 | ESLint flat + typescript-eslint(类型感知 Promise 规则)/ Prettier | 9.x / 8.x / 3.x |
| 包管理 | pnpm(安装脚本白名单在 pnpm-workspace.yaml) | 11.x |
| 配置与密钥 | wrangler.jsonc 放非密配置与绑定,`wrangler types` 生成运行时类型;本地 `.dev.vars`(`.dev.vars.example` 入库);远端 secret 经 `wrangler secret` 或外部密钥管理同步(项目决策;外部同步时 `keep_vars: true`) | — |
| 可观测 | `observability.enabled: true`,结构化 JSON 日志 | — |

形态级工程约定(只此四条):

- `index.ts` 只做 `WorkerEntrypoint` 适配(公开方法整体暴露为 RPC,不放辅助方法),
  实现在 `app.ts`(组合根:配置、依赖、服务类)
- 横切单文件模块平铺于根;每个外部协议一个目录;领域逻辑超过三个文件成目录
- 出站 fetch 与时钟经依赖注入,单元测试不访问真网
- 环境形态二选一并记 decisions:单环境(无状态,或派生数据可重建),或 preview +
  production(顶层配置仅供本地,远端一律 `--env`);部署经 Workers Builds 或 CI
  `wrangler deploy`

对外契约文档三层:

1. 仓内:`docs/architecture/` 至少 overview(生态位置、模块、数据模型)、契约
   (RPC 方法表 + HTTP 接口表)、deploy(环境、变量、runbook、回滚)三篇;README
   列 Cron / HTTP / RPC 三类入口
2. 面向公网调用方的服务:自托管参考文档 `/`(HTML)+ `/llms.txt` + 机器契约
   (`/reference.json` 或 `/openapi.json`),与路由 / 校验共用同一份契约定义,带版本与
   更新日期;静态资源经 ASSETS 绑定
3. RPC 调用方:契约 = `index.ts` 导出的类型(调用方以 `wrangler types` 同时传入双方
   配置生成)+ 仓内契约文,不另做公网文档

### 2. AGENTS.md「目录约定 > 应用内」表新增「Worker 应用」列

| 位置 | Worker 应用 |
|---|---|
| 源码 | 横切单文件模块平铺于根(`index.ts` 入口、`app.ts` 组合根、`config.ts`、`http.ts`);每个外部协议一个目录;领域逻辑超过三个文件成目录 |
| 单元测试 | `test/`(vitest 插件,含集成路径;离线样本放 `test/fixtures/`) |
| 端到端 | —(线上验收脚本随任务放 `.ai/<任务>/assets/`) |
| 数据迁移 | `migrations/`(有 D1 时;SQL,wrangler 管理) |
| 静态资源 / 国际化 | `public/`(仅自托管文档 / 资源时,ASSETS 绑定) |
| 应用配置 | wrangler.jsonc、package.json、pnpm-workspace.yaml、.dev.vars.example |

「原则」小节不加条目(已有"应用一律平铺,不建 `src/`"覆盖)。

### 3. review-standards.md 评审关注点

`- Cloudflare Workers:` 一条,体量与 Scrapy 条相当:未处理的 Promise(未 await /
return / `waitUntil`);模块级可变状态跨请求共享;无界请求 / 响应体整体缓冲(应流式);
`WorkerEntrypoint` 把辅助方法暴露成 RPC;密钥进日志或以普通字符串比较(应哈希后
`timingSafeEqual`);`passThroughOnException` 代替显式错误处理;Cron / 后台任务超出
CPU 与时长预算而未分页推进;单元测试访问真网。

### 4. docs/decisions/0013-workers-standard-stack.md

四段体例。背景:三仓现状、两仓收敛并建议回写、官方最佳实践。决定:入标准栈并取
收敛形布局;D1 按需而非默认(link 无状态);模板只写形态与基座、不写实现纪律(列出留给
项目的类别);不建栈 skill;
`nodejs_compat` 默认不开(偏离官方建议及理由);密钥工具不点名;link 形态记为偏差、
不迁移;被否的备选(Hono + chanfana 定为标准路由、`src/` 布局、新建 skill)。影响:
AGENTS.md / review-standards / .gitignore 变更;consumer 升级时 AGENTS.md 需人工合并;
link 若对齐另开任务。

### 5. .gitignore 与 CHANGELOG

- `.gitignore` 末尾新增注释块 + 五行(与两仓一致)。
- CHANGELOG 在「受管路径归类」段之后、`## [1.2.1]` 之前插入 `## [1.3.0] - 2026-11-09`:
  Added 一条(Workers 标准栈,MINOR);升级指引:AGENTS.md 需人工合并(技术栈小节与
  目录表一列),`.ai-workflow/review-standards.md` 可整体替换(自改小节先摘出),
  `.gitignore` 不在受管路径、consumer 按需自取,`docs/decisions/0013` 作为模板历史随
  新建项目带入。TEMPLATE-VERSION 改为 `version: 1.3.0`。
- 发版:评审通过、用户已授权(确认闸原话)后提交,打 `v1.3.0` tag 并推送;release notes
  取 CHANGELOG 条目落任务 `evidence/release-notes-v1.3.0.md`。

## 测试用例

全部 A 档,留证写法 (b):每条一个断言脚本 `.ai/2026-11-09/add-workers-stack/evidence/tc-NN.sh`,
工作目录为仓库根,由 `bash .ai-workflow/scripts/evidence.sh TC-NN -- bash
.ai/2026-11-09/add-workers-stack/evidence/tc-NN.sh` 包住产出 `evidence/TC-NN.log`,exit 0 =
全部断言成立;任一断言失败打印 `MISS: <项>` 并 exit 1。关键词断言一律 `grep -F`
固定字符串、逐词检查。

| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | 改动完成;用例目标:标准表 | 用 awk 截取 AGENTS.md `### Cloudflare Worker` 到 `### 部署` 之间的节文本,再截取其中标准表(表头至首个空行),逐行断言 | 表为三列(每行四个竖线字符);逐行命中:运行时行 `compatibility_date`、`nodejs_compat` 与 `默认不开`;语言行 `strict`、`noUncheckedIndexedAccess`、`5.x`;入口行 `WorkerEntrypoint`、`fetch`、`scheduled`、`Service Binding RPC`;数据行 `D1`、`按需`、`migrations/`、`无状态`;出站行 `原生 fetch`;部署 CLI 行 `wrangler`、`成对钉版本`、`4.x`;测试行 `@cloudflare/vitest-plugin`、`同 isolate`、`5.x / 1.x`;Lint 行 `typescript-eslint`、`类型感知`、`Prettier`、`9.x / 8.x / 3.x`;包管理行 `pnpm`、`白名单`、`11.x`;配置行 `wrangler.jsonc`、`wrangler types`、`.dev.vars.example`、`wrangler secret`、`keep_vars`;可观测行 `observability.enabled: true`、`结构化 JSON 日志`;节文本紧随 `### 爬虫` 节之后、`### 部署` 之前;输出 OK、exit 0 | (b) TC-01.log |
| TC-02 | A | 改动完成;用例目标:目录表 | 截取 AGENTS.md「应用内」表(首个单元格为「位置」的表头行至首个空行) | 表头含 `Worker 应用`;每一行均为四列(五个竖线字符,且各行数量一致);Worker 列(第四列)按行命中:源码行 `index.ts`、`app.ts`、`config.ts`、`http.ts`、`每个外部协议一个目录`、`三个文件`;单元测试行 `test/`、`test/fixtures/`;端到端行 `.ai/<任务>/assets/`;迁移行 `migrations/`、`有 D1 时`;静态资源行 `public/`、`ASSETS`;配置行 `wrangler.jsonc`、`pnpm-workspace.yaml`、`.dev.vars.example`;输出 OK、exit 0 | (b) TC-02.log |
| TC-03 | A | 改动完成;用例目标:评审关注点 | grep review-standards.md 行首 `- Cloudflare Workers:` 条目(含续行至下一个行首 `- `) | 命中 `Promise`、`waitUntil`、`模块级`、`缓冲`、`RPC`、`timingSafeEqual`、`passThroughOnException`、`Cron`、`真网`;输出 OK、exit 0 | (b) TC-03.log |
| TC-04 | A | 改动完成;用例目标:决策记录 | 断言 `docs/decisions/0013-workers-standard-stack.md` 存在且 `docs/decisions/0013-*` 唯一;首行以 `# 0013:` 开头;含 `- 日期:2026-11-09`、`- 背景:`、`- 决定:`、`- 影响:`;含 `形态`、`实现纪律`、`skill`、`nodejs_compat`、`cscheap-link`、`src/`、`chanfana`、`按需` | 全部成立,输出 OK、exit 0 | (b) TC-04.log |
| TC-05 | A | 改动完成;用例目标:.gitignore 行为,含反向断言 | `git check-ignore -q` 依次测 `.dev.vars`、`.dev.vars.local`、`worker-configuration.d.ts`、`.wrangler/state/x`(应被忽略,返回码 0)与 `.dev.vars.example`(应**不**被忽略,返回码 1) | 四个被忽略、示例文件不被忽略,输出 OK、exit 0 | (b) TC-05.log |
| TC-06 | A | 改动完成;用例目标:CHANGELOG、既有栈回归、改动范围 | ① CHANGELOG 含 `## [1.3.0] - 2026-11-09` 且位于 `## [1.2.1]` 之前,其后到下一个 `## [` 之间含 `升级指引` 并点名 `AGENTS.md`、`review-standards.md`、`.gitignore`;TEMPLATE-VERSION 首行为 `version: 1.3.0`;② AGENTS.md 仍含 `### 前端`、`### 后端`、`### 爬虫`、`### 部署`,review-standards 仍含 `- Scrapy:`、`- Python/FastAPI:`;③ `git status --porcelain --untracked-files=all` 的每个路径都属于 6 个改动文件或以 `.ai/2026-11-09/add-workers-stack/` 开头 | REGRESSION-OK、SCOPE-OK,exit 0;git status 快照落 evidence/ | (b) TC-06.log |
| TC-07 | A | HEAD 为改动前提交;用例目标:反向对照 | 对 `git show HEAD:AGENTS.md` 的内容执行 TC-01 同款截取与断言,脚本在内层断言**失败**时 exit 0、成功时 exit 1 | 内层输出 `MISS`、脚本 exit 0——证明 TC-01 断言不是恒真式 | (b) TC-07.log |
| TC-08 | A | 改动完成;用例目标:形态约定与三层文档 | 对 TC-01 同一节的完整文本断言决策引用;对该节中标准表之后的部分逐项断言约定与文档 | 完整节含 `docs/decisions/0013`。表后正文——四条约定:`index.ts`、`不放辅助方法`、`app.ts`、`组合根`;`平铺`、`每个外部协议一个目录`、`三个文件成目录`;`依赖注入`、`真网`;`单环境`、`可重建`、`preview`、`production`、`顶层配置仅供本地`、`--env`、`decisions`;三层文档:`docs/architecture/`、`overview`、`契约`、`RPC 方法表`、`HTTP 接口表`、`deploy`、`Cron / HTTP / RPC`;`公网`、`HTML`、`/llms.txt`、`/reference.json`、`/openapi.json`、`同一份契约`、`版本`、`更新日期`、`ASSETS`;`RPC 调用方`、`index.ts` 导出的类型、`wrangler types`、`双方`、`不另做公网文档`;输出 OK、exit 0 | (b) TC-08.log |

C 档 0 条。非 happy-path:TC-05(示例文件不被忽略的反向断言)、TC-07(反向对照)。

## 风险与回滚

- **规定过深回到实现纪律**:以四条形态约定为上限,评审以「是否越界」为固定检查项;
  超出的内容移入项目 docs。
- **偏离官方建议(`nodejs_compat`)误导新项目**:决策 0013 写明理由与触发开启的条件,
  AGENTS.md 表内同句注明。
- **consumer 升级合并成本**:AGENTS.md 属需人工合并类,升级指引逐项写明插入位置;
  两仓已有同形内容,合并时以模板为准对齐措辞即可。
- 回滚:纯文档改动,`git revert` 单提交即可,无运行时影响。
