评审当前工作区的未提交改动(git diff HEAD 及未跟踪的新文件)。

本轮任务上下文:
- 方案:{{TASK_DIR}}/plan.md
- 本轮实现记录:{{TASK_DIR}}/implementation-round-{{ROUND}}.md
- 若轮次大于 01,请对照上一轮 review-round-*-fail.md 逐项核验修复是否到位

评审角色约束、标准与严重度定义以 .ai-workflow/review-standards.md 为
唯一权威,评审前先完整阅读该文件。
请实际运行 plan.md 中的测试用例,核验实现记录中报告的测试结果是否属实;
虚报的测试结果按 blocker 处理。

输出格式(严格遵守,末行将被脚本解析):

# 评审:第 {{ROUND}} 轮

## 问题清单
- [plan-blocker|blocker|major|minor] R-01 <一句话结论>
  - 详情:<文件:行号 / 问题说明 / 修复建议>
(每个问题一条,无问题写"无"。plan-blocker 置顶。)

## 总评
<两三句>

VERDICT: pass
(最后一行,单独一行,小写,pass 或 fail 二选一,按 review-standards.md 判定规则给出)
