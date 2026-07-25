# Plan 评审:第 01 轮

## 问题清单
- [plan-blocker] R-01 方案将新增的爬虫标准栈这一关键架构决策排除在 docs 回写之外，违反仓库收尾纪律。
  - 详情:定位：计划「改动范围」明确“不动 docs/”，但 AGENTS.md、CLAUDE.md 与 docs/README.md 均要求架构或关键决策变更回写 docs/。Scrapy 标准栈确定了数据层、部署形态和可选扩展边界，属于关键决策。修复建议：将新的 decisions/NNNN-*.md（并按实际形态决定是否更新 architecture 导航）纳入范围、测试和收尾说明，并修正文件数估计。
- [plan-blocker] R-03 声明的“.egg + scrapyd”部署链路没有定义 egg 上传注册到 Scrapyd 的配置和责任。
  - 详情:定位：计划仅要求 setup.py 构建 egg 和 scrapy.cfg，未定义 [deploy] 配置、scrapyd-client/scrapyd-deploy，或由 dopilot 调用 addversion 上传的接口与交接。仅构建本地 egg 不能使 Scrapyd 调度项目。修复建议：明确完整部署边界及配置归属，并补相应验收。[Scrapyd 部署文档](https://scrapyd.readthedocs.io/en/latest/deploy.html)
- [major] R-02 计划给出的 asyncio reactor 导入路径错误，照此生成项目会无法加载 reactor。
  - 详情:定位：计划「1. AGENTS.md『### 爬虫』小节」将 TWISTED_REACTOR 写为 twisted.internet.asyncioreactor.AsyncioSelectorEventLoop。正确 reactor 路径为 twisted.internet.asyncioreactor.AsyncioSelectorReactor。修复建议：改为正确字符串，或说明 Scrapy 2.13+ 默认启用该 reactor，并增加精确断言。[Scrapy 设置文档](https://docs.scrapy.org/en/2.13/topics/settings.html)
- [major] R-04 测试表以宽泛关键词检索替代验收断言，且含不可执行或不能证明结论的用例。
  - 详情:定位：TC-01/02/03/04/06 只检索宽泛词，不能证明数据层、评审关注点、迁移三处联动和 skill 三节落实；TC-04 的“该文件”不是可执行路径；TC-05 的 git diff --stat 不包含未跟踪的新 SKILL.md，不能证明范围。修复建议：为每项验收写精确可执行断言，改用 git status --short 检查允许清单，修正 TC-04，并补错误配置/必填段缺失的边界覆盖。

## 总评
证据档位均声明为 A，且 C 档为 0，证据契约本身合规。方案仍存在关键决策回写、部署链路和 reactor 配置问题；按 plan 阶段规则应先修订后重评。

VERDICT: fail
