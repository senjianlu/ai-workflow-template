评审当前工作区的未提交改动(git diff HEAD 及未跟踪的新文件)。

本轮任务上下文:
- 方案:{{TASK_DIR}}/plan.md
- 本轮实现记录:{{TASK_DIR}}/implementation-round-{{ROUND}}.md
- 若轮次大于 01,请对照上一轮 review-round-*-fail.md 逐项核验修复是否到位

评审角色约束、标准、严重度定义与可执行动作以 .ai-workflow/review-standards.md
为唯一权威,评审前先完整阅读该文件。
核验实现记录中报告的测试结果是否属实:在该文件「评审动作边界」允许的
范围内重跑可运行的用例(静态检查、自终止且不起服务不访问网络的单元
测试,单条命令默认 5 分钟超时);边界外的用例(build / E2E / 需启动
服务类)不运行,改为审查 {{TASK_DIR}}/evidence/ 中的原始输出并与实现
记录交叉比对。证据缺失、矛盾或虚报的测试结果按 blocker 处理。

输出要求:你的最终回复由 --output-schema 强制为 JSON,字段语义如下。
verdict 必须按 review-standards.md 的判定规则给出——脚本会按严重度清单
独立复核,自报结论与清单矛盾的评审直接判无效。

- verdict:"pass" 或 "fail"
- issues:问题数组,无问题时为空数组;每项:
  - id:R-NN 两位递增编号(R-01、R-02……)
  - severity:plan-blocker | blocker | major | minor(定义见 review-standards.md)
  - summary:一句话结论
  - detail:文件:行号 / 问题说明 / 修复建议
- overall:两三句总评

plan-blocker 不计入 pass/fail 判定,但必须列出(渲染时置顶)。
