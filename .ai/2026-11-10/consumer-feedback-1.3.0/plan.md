---
status: approved
task: consumer-feedback-1.3.0
date: 2026-11-10
approved_at: 2026-11-10 11:41:58
evidence_format: v1
---

# 方案:处理 cscheap-catalog 对模板 1.3.0 的四条反馈(模板决策改 t 前缀等)

## 需求原文

> 这个项目里目前有个优化建议目录,你看下

> 我觉得用 a001 这种来做彻底区分?

> 如果有其它独立前缀推荐,我觉得也可以用你的。

反馈原文:`evidence/from-catalog/README.md`(四条:决策撞号、参考仓未提交、
「领域逻辑超过三个文件成目录」缺口径、CHANGELOG 等被带进派生仓)。

后续对齐结论:

- 撞号用**独立前缀**彻底区分(不采用「项目从 0100 起编」);前缀由我推荐,
  定为小写 `t` + 原四位编号(`0003-…` → `t0003-…`)。
- 四条一起做。

**本任务交付**:模板决策全部改名为 `tNNNN-<slug>.md` 并同步仓内引用,纯数字
`NNNN` 整段留给派生项目;AGENTS.md 补 Worker 目录成型规则的判定口径、参考仓
只点名已推送的仓;README / CHANGELOG 写明派生仓里哪些文件属项目自有;以 1.4.0
发版并给出存量仓升级指引。

## 背景与目标

四条反馈的事实已在本仓与三个派生仓(只读)逐条核对属实:

1. 模板 `0013` 与 telegram / link / catalog 各自的 `0013` 撞号,模板每新增一条
   决策都会再撞。
2. AGENTS.md 点名的参考仓 cscheap-catalog 远端只有 Initial commit(本地 52 个
   未提交改动),照着去看的人看不到 Worker 收敛形。
3. 「领域逻辑超过三个文件成目录」没有定义「领域」「横切」与外部协议目录的门槛,
   catalog 根上的 `ndjson.ts`、`link.ts` 两可。
4. `CHANGELOG.md`、`logo.svg`、`.ai/` 模板任务历史被原样带进派生仓,不在任何
   受管路径归类里,三仓三种处理。

目标:四条各给出模板侧的明确口径,存量仓按升级指引可机械迁移、不改自有编号。

### 供评审核验的事实来源(只读)

- `/home/rabbir/Projects/cscheap-telegram`、`cscheap-link`、`cscheap-catalog`:
  `docs/decisions/` 文件清单、根目录源码布局、`CHANGELOG.md` 第 3 行、`.ai/` 清单
- 本仓:`docs/decisions/`、README「开新项目」「版本与升级」、CHANGELOG 头部归类

## 改动范围

| 文件 | 改动 |
|---|---|
| `docs/decisions/0001-…md` ~ `0013-…md`(13 个) | `git mv` 为 `t0001-…` ~ `t0013-…`,slug 不变;正文里的模板决策编号(标题、互相引用、相对链接)同步加 `t`。t0013 中「telegram(其 0015)与 catalog(其 0014)」是派生仓编号,保持不变;t0013 末尾追加一条「沿革」记录反馈 2、3 的澄清 |
| `docs/decisions/t0014-template-decision-namespace.md` | 新增决策:模板决策独立命名空间,及派生仓里模板文件与项目自有文件的归属划分(反馈 1、4) |
| `docs/decisions/README.md` | 写明两个系列的命名与归属,及旧编号对应关系(见实现方案 1) |
| `docs/README.md` | 组织表 `decisions/` 行的文件名约定同步 |
| `README.md` | ① 全部 `docs/decisions/NNNN` 引用加 `t`;②「开新项目」新增一步(反馈 4);③「发布纪律」加参考仓一条(反馈 2);④「升级流程」的 diff 路径清单加 `'docs/decisions/t*'` 与 `docs/decisions/README.md` |
| `CHANGELOG.md` | ① 头部归类:「可整体替换」加 `docs/decisions/t*.md`,「需人工合并」加 `docs/decisions/README.md`,新增第三类「项目自有,创建后即脱钩」;② 新增 `## [1.4.0] - 2026-11-10` 条目与升级指引。1.3.0 及更早条目一字不改 |
| `AGENTS.md` | ① Worker 节「参考」只点名 cscheap-telegram(反馈 2);② 工程约定第 2 条补判定口径与正反例,目录表 Worker 列指向该口径(反馈 3);③ `docs/decisions/0013` 引用加 `t` |
| `CLAUDE.md` | 4 处 `docs/decisions/NNNN` 引用加 `t` |
| `.ai-workflow/review-standards.md` | 4 处引用加 `t` |
| `.ai-workflow/scripts/{review,plan-review,evidence,evidence-check}.sh`、`.claude/hooks/gate-review.sh`、`.gitignore` | 注释里的 `docs/decisions/NNNN` 加 `t`;**只改注释行,不改任何可执行行** |
| `.ai-workflow/TEMPLATE-VERSION` | `version: 1.4.0` |

共 28 个文件(13 个改名 + 1 个新增 + 14 个修改)。

非需求直接要求、但实现必需的条目:

- **脚本 / hook / `.gitignore` 的注释、CLAUDE.md、review-standards.md**:它们引用
  决策路径,改名后不跟着改就是死链。
- **`docs/decisions/t*.md` 进「可整体替换」类与升级 diff 清单**:受管文件
  (CLAUDE.md、脚本)引用 t 系列,派生仓必须持有它们;有了独立前缀才能整体替换,
  取代 1.3.0 指引里「存量项目可不拷」的口径。
- **发版 1.4.0**:派生仓只能经 CHANGELOG 升级指引拿到改名口径,不发版则反馈 1
  对存量仓无法落地。取 MINOR:不改闸门协议(hook 行为、schema、产物命名、流程
  步骤均不变),是向后兼容的约定新增。

不动:`.ai/` 下全部历史任务目录(只增不改)、CHANGELOG 旧条目、prompts、
schemas、templates、skills、settings.json、任何派生仓。

## 非目标

- 修改任何派生仓(含推送 cscheap-catalog、给三仓改号或改 CHANGELOG);它们按
  1.4.0 升级指引各自处理
- catalog 推送后把它加回参考仓(另行任务)
- 改写 `.ai/` 历史记录与 CHANGELOG 旧条目里的旧编号(靠索引里的对应关系说明)
- 清理本仓自己的 `.ai/` 模板任务历史、替换本仓 logo(它们在模板仓是正当内容)
- 反馈附录「升级 1.2.1 → 1.3.0 操作记录」(与指引一致,无需改动)
- 打 tag 与创建 GitHub Release(提交后由用户操作,同 1.3.0 先例)
- 给脚本加决策文件名校验等新机制

## 实现方案

### 1. 模板决策改 `t` 前缀(反馈 1)

- 命名:模板决策 `tNNNN-<slug>.md`,编号与旧号一一对应(`0001` → `t0001`),
  后续模板决策从 `t0014` 续编;派生项目决策 `NNNN-<slug>.md`,新项目自 `0001`
  起编。
- 归属(写入 `docs/decisions/README.md`,该文件随模板进派生仓,所以两边口径
  写在同一处):
  - `t` 系列由模板维护,随模板升级整体替换;派生项目不新增、不修改 `t` 系列。
  - 纯数字系列属项目;模板仓自身只新增 `t` 系列。
  - 沿革:1.4.0 之前模板决策为纯数字 `0001` ~ `0013`;模板仓 `.ai/` 历史记录与
    CHANGELOG 旧条目里的 `docs/decisions/00NN` 即今 `t00NN`。
- 正文替换只作用于**模板决策编号**:标题 `# 0012:` → `# t0012:`、互相引用
  「被 0010 部分取代」→「被 t0010 部分取代」、相对链接目标。派生仓编号(t0013
  里的两处「其 00NN」)不动。
- 仓内其它文件里的 `docs/decisions/NNNN`、「0003、0012」并列写法同样加 `t`。
- 存量仓升级口径(写入 1.4.0 升级指引,在模板克隆 `/tmp/awt` 锚定 `v1.4.0` 后
  于派生仓根执行):
  1. 删除派生仓 `docs/decisions/` 中**与模板旧文件完整同名**(编号 + slug 都
     相同)的文件——删除候选是升级指引里**逐个列出的 13 个旧文件名**
     (`0001-plan-stage-review.md` ~ `0013-workers-standard-stack.md`),不从
     新版 `t*.md` 反推;项目自有的 `0013-<别的 slug>.md`、以及与今后模板新增
     决策同 slug 的项目文件都不在清单内,不会被删;
  2. 把 `/tmp/awt/docs/decisions/t*.md` 整体拷入;
  3. 项目自有决策**不改号**(从 0013 起编的继续沿用,前面空号不补);项目文档里
     指向模板决策的旧编号改写为 `tNNNN`;`docs/decisions/README.md` **人工合并**——
     只并入模板新版的两系列命名规则与旧号对应说明,项目自有的索引、裁剪说明、
     取代关系原样保留(三个派生仓都在该文件里维护了项目内容,不可覆盖)。

### 2. 参考仓只点名已推送的(反馈 2)

- AGENTS.md Worker 节首句改为只参考 `senjianlu/cscheap-telegram`。
- README「发布纪律」加一条:受管文件点名的参考仓须已推送到远端,且被引用的
  内容可在远端复核;不满足的不点名。
- t0013 正文里对 catalog 的叙述是当时的背景事实,不改;在其「沿革」里注明
  1.4.0 起 AGENTS.md 暂不点名 catalog 及原因。

### 3. Worker 目录成型规则的判定口径(反馈 3)

AGENTS.md 工程约定第 2 条改为下列口径(目录表 Worker 列保留原短句并注「口径见
技术栈 > Cloudflare Worker 工程约定」):

- **横切模块**:与具体业务无关的基座与通用工具——入口、组合根、配置、HTTP
  适配,以及解析、编码、国际化这类通用工具。单文件平铺于根,不计入下面的计数。
- **外部协议**:对接一个外部系统的协议代码(客户端、类型、回调解析)。有两个
  及以上源文件时成目录;只有一个源文件(含单函数适配)时平铺于根。
- **领域逻辑**:本仓业务规则及其数据读写。只数源文件、不含测试;达到四个
  (即「超过三个」)时收进领域目录,三个及以下平铺于根。
- 例(成目录):telegram 对接 Telegram 的 `api.ts` + `webhook.ts` 两个文件 →
  `telegram/`。例(不成目录):某仓根上除基座外有 `items.ts`、`sync.ts`(领域,
  2 个)、`ndjson.ts`(通用解析,横切)、`link.ts`(单函数外部适配)→ 全部平铺。

例子在 AGENTS.md 里不写 catalog 的仓名(与第 2 项一致),只写文件形态。

### 4. 派生仓里的项目自有文件(反馈 4)

- README「开新项目」在第 2 步之后新增一步:`CHANGELOG.md` 重置为项目自己的
  版本历史;`logo.svg` 替换或删除(同时处理 README 顶部对它的引用);删除 `.ai/`
  下模板带来的任务目录(模板历史在模板仓可查);`docs/decisions/` 里 `t` 系列
  保留、项目决策自 `0001` 起编。原第 3 ~ 8 步顺延为 4 ~ 9;「存量项目迁移」里
  对「开新项目第 3 步」(两条 git config)的引用同步改为第 4 步。
- CHANGELOG 头部归类新增第三类「项目自有,创建后即脱钩」:`CHANGELOG.md`、
  `logo.svg`、`.ai/` 下的任务目录、`docs/decisions/` 纯数字系列。模板升级不触碰。

### 5. 版本

CHANGELOG 新增 `## [1.4.0] - 2026-11-10`:Changed(决策改名、Worker 口径、参考仓
点名)、Added(第三类归类、开新项目新步骤、发布纪律)与「升级指引」(逐类标注:
可整体替换含新增的 `docs/decisions/t*.md` 与第 1 节的三步;需人工合并的
AGENTS.md / CLAUDE.md / README.md 各改了什么)。TEMPLATE-VERSION 改 1.4.0。

## 测试用例

断言脚本放 `assets/`,均为非交互、exit 0 = 全部断言成立。

| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | 实现完成 | 列 `docs/decisions/` | 恰为 `t0001` ~ `t0014` 共 14 个决策文件加 `README.md`;不存在纯数字开头的 `.md`;t0001 ~ t0013 的 slug 与 HEAD 中旧文件一致 | (b) `evidence.sh TC-01 -- bash assets/tc01.sh` |
| TC-02 | A | 同上 | 在 `.ai/` 与 `.git/` 之外全仓 grep `decisions/[0-9]{4}`;比对 CHANGELOG 自 `## [1.3.0]` 标题起到文件末尾的内容与 HEAD 版本 | 除 CHANGELOG 旧条目外无任何纯数字决策路径;CHANGELOG 旧条目与 HEAD 逐字节相同 | (b) `evidence.sh TC-02 -- bash assets/tc02.sh` |
| TC-03 | A | 同上 | 提取 `.ai/`、`.git/` 之外全部 `docs/decisions/tNNNN` 引用,以及 `docs/decisions/*.md` 内的相对 `.md` 链接,逐个检查目标 | 每个引用都对应一个存在的文件,无死链 | (b) `evidence.sh TC-03 -- bash assets/tc03.sh` |
| TC-04 | A | 同上(边界用例) | ① 把 t0001 ~ t0012 里的 `t00NN` 去掉 `t` 后与 HEAD 中对应旧文件 diff;② 在 `docs/decisions/t*.md` 中 grep 未带 `t` 前缀的 `00NN` 四位编号 | ① 12 个文件均无差异(改名只动了决策编号);② 仅命中 t0013 的「其 0015」「其 0014」两处(派生仓编号未被误改) | (b) `evidence.sh TC-04 -- bash assets/tc04.sh` |
| TC-05 | A | 同上 | `git status --porcelain -- .ai` 与 `git diff HEAD --stat -- .ai` | 变化只出现在 `.ai/2026-11-10/consumer-feedback-1.3.0/` 下;历史任务目录无任何改动 | (b) `evidence.sh TC-05 -- bash assets/tc05.sh` |
| TC-06 | A | 同上 | 对四个脚本、`gate-review.sh`、`.gitignore` 取 `git diff HEAD` 的增删行;对五个 shell 文件跑 `bash -n` | 增删行全部以 `#` 开头(只改了注释);`bash -n` 全部 exit 0 | (b) `evidence.sh TC-06 -- bash assets/tc06.sh` |
| TC-07 | A | 同上 | grep AGENTS.md、README.md | AGENTS.md 不再出现 `cscheap-catalog`,Worker 节含「横切模块」「外部协议」「领域逻辑」三条口径与成目录 / 不成目录两个例子;README「发布纪律」含参考仓须已推送一条 | (b) `evidence.sh TC-07 -- bash assets/tc07.sh` |
| TC-08 | A | 同上 | grep README.md、CHANGELOG.md、`docs/decisions/README.md` | README「开新项目」共 9 步且新步骤同时提到 `CHANGELOG.md`、`logo.svg`、`.ai/`;「存量项目迁移」引用的是第 4 步;CHANGELOG 头部有三类,「可整体替换」含 `docs/decisions/t*.md`、「需人工合并」含 `docs/decisions/README.md`;README 升级 diff 清单含 `docs/decisions/t*` 与 `docs/decisions/README.md`;决策索引写明两个系列与旧号对应 | (b) `evidence.sh TC-08 -- bash assets/tc08.sh` |
| TC-09 | A | 同上 | 读 TEMPLATE-VERSION 与 CHANGELOG | `version: 1.4.0`;存在 `## [1.4.0] - 2026-11-10` 且其下有「升级指引」小节,位于 1.3.0 条目之前 | (b) `evidence.sh TC-09 -- bash assets/tc09.sh` |
| TC-10 | A | 同上(异常/边界用例) | 在临时目录造一个存量派生仓:`docs/decisions/` 放 HEAD 版的模板 `0001` ~ `0012` 原文件、被项目带入的模板 `0013-workers-standard-stack.md`、项目自有的 `0013-own-thing.md` 与 `0014-template-decision-namespace.md`(与模板新增的 t0014 同 slug)、一份带项目自有索引段落的 `README.md`;以本仓工作区充当模板克隆,逐字执行 1.4.0 升级指引里的命令 | 模板旧文件 `0001` ~ `0013` 全部消失,`t0001` ~ `t0014` 齐全;两个项目自有决策与带项目索引的 `README.md` 原样保留、内容未变;脚本同时断言所执行命令与 CHANGELOG 指引中的代码块一致 | (b) `evidence.sh TC-10 -- bash assets/tc10.sh` |

C 档 0 条。

## 风险与回滚

- **替换误伤**:四位数字在仓内还有其它含义(日期、`4000000 ms`、派生仓编号)。
  替换只针对 `decisions/NNNN` 路径与决策正文里的模板编号,TC-04、TC-06 兜底。
- **脚本被改坏**:脚本与 hook 只改注释,TC-06 断言增删行全是注释并跑 `bash -n`;
  本机没有 shellcheck,注释改动不引入新告警。
- **存量仓升级时误删自有决策**:删除候选是写死的 13 个旧文件名,
  TC-10 用撞号的 `0013` 与同 slug 的 `0014` 验证。派生仓若改写过带入的模板决策正文,整体替换会覆盖
  其改动,升级指引里写明先自查 diff。
- **旧编号仍留在历史记录里**:`.ai/` 与 CHANGELOG 旧条目不改,靠决策索引的对应
  说明;读者按「同号加 t」即可定位。
- **MINOR 还是 MAJOR**:派生仓的受管文件升级后会指向 `t` 路径,若不按指引拷入
  `t*.md` 会出现死链,但不影响任何闸门运行。按 README 的分级(以闸门兼容性
  为准)取 MINOR;如需按 MAJOR 发,由用户在确认闸裁决。
- 回滚:全部改动在一次提交内,`git revert` 即可;改名用 `git mv`,历史可追。
