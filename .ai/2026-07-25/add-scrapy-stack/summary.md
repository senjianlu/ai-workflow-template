---
task: add-scrapy-stack
date: 2026-07-25
rounds: 1
verdict: pass
---

# 任务小结:在模板中新增 Scrapy 爬虫标准栈

## 改动

| 文件 | 摘要 |
|---|---|
| AGENTS.md | 新增「技术栈 > 爬虫」小节:Scrapy 2.13+ 标准表(数据层复用后端 Postgres+SQLAlchemy+redis-py,pydantic-settings/httpx 同后端)、scrapyd 三段部署链路(CI 构建 egg → GitHub Release → dopilot addversion.json 注册 + schedule.json 调度,setup.py 必须含 scrapy settings entry point,运行环境依赖由基础镜像按 pyproject.toml 预装)、可选扩展区(只列类别不点名工具)、工程约定(具名包/snake_case/阻塞下沉/离线可测),带 TEMPLATE 裁剪注释 |
| .ai-workflow/review-standards.md | 技术栈评审关注点新增 Scrapy 条目(阻塞混入 reactor、selector 无防御、异常吞噬、去重/限速/重试被绕过、解析测试须用本地 fixture) |
| README.md | 存量项目迁移第 2 步显式化:剔除无关技术栈,三处联动删除(技术栈表、评审关注点、栈 skill) |
| .claude/skills/rawf-stack-scrapy/SKILL.md | 新建栈 skill:初始化/编码/测试三节操作细则,事实约束以 AGENTS.md 为权威 |
| docs/decisions/0007-scrapy-standard-stack.md | 新建决策记录:固化数据层复用、scrapyd 部署链路、可选扩展不点名、迁移三处联动四项取舍 |

## 评审历程

plan 阶段评审(用户主动要求执行;轮次上限经用户 2026-07-25 明确授权放宽至 10):

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| plan-01 | fail | 决策未回写 docs(plan-blocker)、scrapyd 注册环节缺失(plan-blocker)、reactor 路径错误、测试断言宽泛 |
| plan-02 | fail | egg 缺 scrapy settings entry point 契约、调度未定义走 schedule.json(plan-blocker)、测试覆盖不足 |
| plan-03 | fail | 表格内命令因 Markdown 转义不可执行(major) |
| plan-04 | fail | 10 轮授权无产物留痕(plan-blocker)、验收关键词不够精确 |
| plan-05 | fail | scrapyd 运行环境依赖供给未定义(plan-blocker)、entry point/三段责任/数据层断言缺失 |
| plan-06 | pass | 无问题 |
| plan-07 | pass | 用户要求可选扩展泛化不点名后复评,无问题 |

实现层评审:

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| 01 | pass | 无问题;TC-01~08 全 A 档证据逐项核验通过 |

## 遗留 minor 及处置

无(最后一轮评审问题清单为空)。
