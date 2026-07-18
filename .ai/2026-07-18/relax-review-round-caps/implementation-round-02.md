---
task: relax-review-round-caps
round: 02
date: 2026-07-18
---

# 实现记录:第 02 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| .ai-workflow/scripts/plan-review.sh | `resolve_max_rounds` 用 awk "F=" 前缀标记字段命中,区分"字段未出现"(→缺省 3)与"出现但值为空/非正整数"(→报错 exit 3,空值提示"实际为:空");值两端空白在 awk 内裁剪 |
| .ai/…/evidence/test-round-caps.sh | 仓库根改为动态解析(`$1` 显式传参 > `git -C <脚本目录> rev-parse --show-toplevel`),解析失败即退出;工作目录改 mktemp 落仓库外并 trap 清理;TC-03 增补空值与纯空格用例 |
| .ai/…/evidence/test-round-caps-output-round02.txt | 新增:修复后从 evidence/ 无参数执行的完整输出(12 项全过),首行打印实际解析的 REPO 路径 |

## 修复对照

| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| R-01 | major | awk 输出加 "F=" 命中标记:无标记 → 缺省 3;有标记但值(裁剪空白后)非 `^[1-9][0-9]*$` → stderr 报"非法(须为正整数,实际为:<值|空>)"并 exit 3。TC-03 扩为 4 个非法形态(0 / abc / 空值 / 纯空格),均验证 exit 3 |
| R-02 | major | 测试脚本删除硬编码路径,改从脚本自身位置经 `git rev-parse --show-toplevel` 解析仓库根(支持 `$1` 显式覆盖),并打印 REPO 供人工核对;evidence/ 副本已同步,round02 输出首行可见其解析到的正是当前工作区 |

## 测试结果

| 编号 | 结果 | 证据 |
|---|---|---|
| TC-01 | 通过 | 无字段 → 3 / exit 0;evidence/test-round-caps-output-round02.txt |
| TC-02 | 通过 | 字段 5 → 5 / exit 0;同上 |
| TC-03 | 通过 | 0、abc、空值、纯空格 4 形态各 exit 3 且 stderr 报"非法"(空值报"实际为:空");同上 |
| TC-04 | 通过 | 正文伪造字段仍 → 3;同上 |
| TC-05 | 通过 | 缺省 3 轮闸拦截,exit 3;同上 |
| TC-06 | 通过 | 上限 5 放行第 4 轮,死于假 codex,不再报上限;同上 |
| TC-07 | 通过 | `bash -n` 过;全仓固定表述残留为零;同上 |
| TC-08 | 通过 | 两 skill 三项静态断言全命中;同上 |
| TC-09 | 通过 | 场景走查不受本轮改动影响,结论不变;evidence/tc-09-scenario-walkthrough.md |

本轮测试由 evidence/test-round-caps.sh **从 evidence/ 目录无参数执行**,
首行 `REPO: /Users/xujinpeng/Projects/2026/ai-workflow-template` 证明其
验证对象即当前工作区(R-02 的验收点)。

## 与方案的偏差

无新增偏差。R-01 属方案既定语义("非正整数 → exit 3")的实现补正;
R-02 属测试证据健壮性修复,不触及方案范围。round-01 的证据文件按
"历史只增不改"保留,新输出以 round02 后缀另存。
