# Plan 评审:第 05 轮

## 问题清单
- [plan-blocker] R-01 Scrapyd 部署链路未规定爬虫依赖在运行时如何被安装，含数据层依赖的 egg 无法保证可运行。
  - 详情:定位：plan.md「1. AGENTS.md『### 爬虫』小节」的部署链路与「4. rawf-stack-scrapy」初始化。方案只构建、上传并注册项目 egg；pyproject.toml 仅声明依赖，Scrapyd 注册 egg 不会安装 SQLAlchemy、psycopg、redis 等项目依赖，调度后可能在导入时失败。需在方案中明确并固化 Scrapyd 运行环境的依赖供给与版本约束责任（例如由 dopilot 管理的基础镜像/运行环境按项目依赖安装），并为该约定补验收断言。
- [major] R-02 TC-01/TC-04 的关键词检查仍不能覆盖关键部署契约，错误实现可通过全部用例。
  - 详情:定位：TC-01、TC-04 及其命令。两处只检查 `entry_points={"scrapy"` 前缀，未验证必须的 `settings = <snake_name>.settings` 映射；TC-01 也未断言 CI 构建、GitHub Release 发布、dopilot 从 Release 拉取并调用 addversion 的三段责任，以及 Postgres/psycopg 数据层选择。删除或写错这些核心约定仍会通过 TC-01 至 TC-08。应改为逐项可失败的精确断言，至少验证完整 settings entry point、三段发布/注册责任及 Postgres+psycopg 约束。

## 总评
证据档位逐条声明为 A，且 C 档为 0，证据契约形式合规；现有用例也包含范围与反向边界检查。但运行时依赖链路缺失属于部署架构问题，核心契约的验收覆盖也仍不足，需修订方案后重评。

VERDICT: fail
