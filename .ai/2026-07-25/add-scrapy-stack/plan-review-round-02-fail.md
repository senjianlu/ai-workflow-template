# Plan 评审:第 02 轮

## 问题清单
- [plan-blocker] R-01 Scrapyd 部署链路仍缺少可运行所必需的 egg 入口点与调度接口契约。
  - 详情:定位：plan.md「1. AGENTS.md『### 爬虫』小节」的打包/部署链路，以及「4. rawf-stack-scrapy SKILL.md」初始化要求。方案只要求 setup.py 作为“.egg 打包入口”，未要求 egg 声明 `scrapy` 到 `<package>.settings` 的 entry point；Scrapyd 的 addversion 接收的 egg 必须具有该入口点，单有 scrapy.cfg 不能让已上传 egg 被 Scrapyd 发现 spider。注册后又写 dopilot 以 `scrapy crawl <spider>` 形态定时执行，未定义由 Scrapyd 的 `schedule.json` 以 project/spider（必要时 version）调度，因而可能绕开已注册的 egg。补充这两项责任与配置归属（包括 setup.py/等价构建元数据、dopilot 调用的接口和参数），并加入对应验收断言；参见 [Scrapyd API](https://scrapyd.readthedocs.io/en/latest/api.html)。
- [major] R-02 测试表未真实覆盖方案的核心验收要求，主要是宽泛关键词和文件骨架检查。
  - 详情:定位：TC-01 至 TC-07。TC-01 只确认五个词，TC-02 只确认 fixture，TC-04 只确认 skill 标题；即使遗漏 pydantic-settings、redis/httpx、pyproject.toml 与 setup.py 的职责边界、具名包/蛇形模块、阻塞下沉、pipeline 替身测试、selector/异常/去重限速重试关注点，测试仍可通过。现有 TC-05/TC-06 仅覆盖改动范围和文案存在，未覆盖上述契约的错误/缺失路径。应将每项关键约定改为精确、可失败的断言，特别补充缺少 Scrapyd entry point、错误调度接口、遗漏离线 fixture 或关键评审关注点时必然失败的边界用例。

## 总评
逐条档位与证据形态均已声明为 A，C 档为 0，证据契约本身合规；reactor 路径和决策回写也已修正。部署链路尚不能保证上传后的项目可被 Scrapyd 调度，且测试无法拦住关键约定遗漏，按 plan 阶段规则应判 fail。

VERDICT: fail
