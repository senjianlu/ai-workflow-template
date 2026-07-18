# 评审标准(评审者手册)

本文件是本项目代码评审的唯一权威标准,由评审指令
(.ai-workflow/prompts/review.md)显式引用。

评审者是本项目的独立代码评审者:只评审,不修改任何代码,也不在工作区
新建或改动任何文件(运行边界内检查产生的、已被 .gitignore 忽略的产物
除外);可执行的动作以下方「评审动作边界」为准。

## 评审输入

- 当前工作区的未提交改动(含新增文件)
- 本轮任务的 plan.md(路径由评审指令给出)

核心问题永远是两个:实现是否忠于 plan?plan 中的测试用例是否真实覆盖并通过?

## 评审动作边界

评审动作**按命令性质判定,不以运行器名称一刀切**(pytest / vitest 同样
可能跑到集成用例或需启动服务的用例):

- **允许**:读取代码与 diff、grep 类检索;运行同时满足三条性质的检查
  命令——**自终止、不启动服务或长驻进程、不访问网络**。典型:lint
  (eslint / ruff check)、类型检查(tsc --noEmit)、限定到单元测试子集
  的 vitest run / pytest(以路径、marker 或项目 script 明确限定)。
- **超时与中止**:单条命令设超时上限(默认 5 分钟,建议用 timeout 等
  机制强制),超时即中止并在评审输出中记录该用例"未能在边界内核验",
  不得反复重试拉长评审;疑似不自终止的命令一律不执行,按边界外处理。
- **混合套件**:单元与集成用例混杂时,只运行可明确限定的单元子集,
  其余按边界外用例处理;不得为"跑全量"而放宽限定。
- **禁止**:安装或更新依赖(npm / pnpm install、pip 等)、构建
  (next build 等)、启动任何服务器或长驻进程(next dev、uvicorn、
  docker 等)、E2E(playwright)、访问网络。
- **边界外的测试用例**(build / E2E / 需启动服务类):不运行,改为审查
  任务目录 evidence/ 中实现者留存的完整原始输出,并与实现记录交叉比对;
  证据缺失或与实现记录矛盾,按虚报测试处理(blocker)。

## 严重度定义(唯一权威来源)

- **plan-blocker**:方案/架构层面的错误,修改代码无法解决,必须退回方案阶段
- **blocker**:实现层错误,导致功能不可用、数据损坏或安全漏洞
- **major**:实现层缺陷,功能可用但存在正确性或健壮性问题,必须修复
- **minor**:风格、可读性、边缘优化,可修可不修

## 判定规则

以下规则适用于**实现层评审**(review.sh,对已实现的代码 diff):

- 存在任一 blocker 或 major → **fail**
- 仅有 minor 或无问题 → **pass**
- plan-blocker 单独列出,不计入 pass/fail,但必须置顶显著标注

## plan 阶段评审(plan-review)语义

**plan 阶段评审**(plan-review.sh,实现前审 plan.md)另用一套判定:此时尚无
实现,**不使用 blocker**;判定规则为——

- 存在任一 **plan-blocker 或 major → fail**(须就地修订 plan.md 后重评)
- 仅有 minor 或无问题 → **pass**

即:同一 plan-blocker 严重度,在实现层评审中不计入 pass/fail(单独升级),在
plan 阶段评审中直接计入 fail——因为 plan 阶段的全部目的就是拦截 plan-blocker。
两套规则分域适用,互不覆盖。

## 技术栈评审关注点

<!-- TEMPLATE: 按需删减。 -->
- TypeScript:类型逃逸(as any / @ts-ignore)、未处理的 Promise、状态管理一致性
- Python/FastAPI:阻塞调用混入 async 路径、Pydantic 校验缺失、异常吞噬
- 通用:plan 中测试用例是否被偷工减料(只测 happy path 即 major)
