---
task: add-scrapy-stack
round: 01
date: 2026-07-25
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| AGENTS.md | 「### 后端」与「### 部署」之间新增「### 爬虫」小节:标准表(Scrapy 2.13+/AsyncioSelectorReactor、数据层复用后端 Postgres+SQLAlchemy+psycopg[binary]+redis-py、pydantic-settings、httpx、scrapyd-client 打包与完整 settings entry point)、三段部署链路(CI 构建 → GitHub Release → dopilot addversion.json 注册 + schedule.json 调度)、运行环境依赖供给(egg 不安装依赖,基础镜像按 pyproject.toml 预装)、可选扩展区(只列类别不点名工具)、工程约定(具名包/snake_case/阻塞下沉/离线可测),带 TEMPLATE 裁剪注释 |
| .ai-workflow/review-standards.md | 「技术栈评审关注点」Python/FastAPI 行后新增 `- Scrapy:` 条目(阻塞混入 reactor、selector 无防御、异常吞噬、去重/限速/重试被绕过、解析测试须用本地 fixture 响应) |
| README.md | 「存量项目迁移」第 2 步显式化:剔除与当前项目无关的技术栈,三处联动删除(AGENTS.md 技术栈表、review-standards.md 评审关注点、rawf-stack-* 栈 skill) |
| .claude/skills/rawf-stack-scrapy/SKILL.md | 新建:初始化(pyproject 唯一权威、包骨架、scrapy.cfg、setup.py 含 scrapy settings entry point、tests/fixtures/、.env.example)、编码(pydantic-settings、基类继承、阻塞下沉、selector 防御、DropItem、可选扩展记 decisions)、测试(HtmlResponse/TextResponse 离线测 parse、fakeredis/aiosqlite 替身、CLOSESPIDER_ITEMCOUNT 冒烟不进 CI) |
| docs/decisions/0007-scrapy-standard-stack.md | 新建决策记录:四段体例,固化数据层复用后端、scrapyd 三段部署链路、可选扩展只列类别不点名、迁移剔除三处联动四项取舍 |

## 修复对照

(第 1 轮,不适用)

## 测试结果

| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | evidence/tc-01.log(24 关键词全命中,OK,exit 0;节文本 evidence/spider-sec.txt) |
| TC-02 | A | pass | evidence/tc-02.log(七关键词全命中,OK,exit 0;条目文本 evidence/scrapy-entry.txt) |
| TC-03 | A | pass | evidence/tc-03.log(六关键词全命中,OK,exit 0;节文本 evidence/mig-sec.txt) |
| TC-04 | A | pass | evidence/tc-04.log(frontmatter/三节标题/17 实质关键词全命中,OK,exit 0) |
| TC-05 | A | pass | evidence/tc-05.log(REGRESSION-OK + SCOPE-OK,exit 0;git status 快照 evidence/git-status.txt,改动仅落允许清单) |
| TC-06 | A | pass | evidence/tc-06.log(具名包/snake_case/阻塞下沉三断言命中,OK,exit 0) |
| TC-07 | A | pass | evidence/tc-07.log(标题编号与四段体例逐段命中 + 三项取舍关键词,OK,exit 0) |
| TC-08 | A | pass | evidence/tc-08.log(改动前 HEAD 版本同款断言输出 `0`、`exit=1`,反向对照成立,脚本自身 exit 0) |

执行方式说明:8 条用例的命令块自 plan.md「测试命令」逐块提取执行,
每条证据文件含命令原文、完整 stdout/stderr 与退出码。

## 与方案的偏差

无。
