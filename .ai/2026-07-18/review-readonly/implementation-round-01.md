---
task: review-readonly
round: 01
date: 2026-07-18
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 删除副本机制(mktemp/cp -Rp/raw 回搬),`codex exec --sandbox read-only -C "$proj"` 直审原仓库;raw 输出直接落任务目录(CLI 层写入,不经沙箱,循 plan-review.sh 先例);指纹函数上移顶层并新增 `__workspace_hash` 测试入口;异常路径不再需要"从副本抢救 raw"的 cp;锁/轮次/同轮唯一/指纹比对/交叉校验/渲染/mv -n 发布/退出码全部保持;头部与指纹注释按新语义更新 |
| `.ai-workflow/review-standards.md` | 「评审动作边界」重写:只读沙箱前提;允许只读检索与确无写副作用的静态检查(写失败不算代码缺陷,转证据核验);**不运行任何测试**;证据协议统一适用——缺失/不完整 → blocker 且 detail 必须列明补交清单,矛盾 → 虚报 blocker;开头段"运行边界内检查产生的产物除外"改为"只读沙箱机器强制" |
| `.ai-workflow/prompts/review.md` | "重跑可运行用例"段改为证据核验协议表述(不跑测试、逐条审 evidence/、缺证据开清单打回) |
| `.claude/skills/rawf-implement/SKILL.md` | 第 5 步:所有测试用例完整原始输出(命令/输出/退出码)必须落 evidence/,删去"边界外才强制"的区分 |
| `README.md` | 机制速览:副本条目替换为"只读直审 + 证据协议 + 指纹双保险";已知限制补"评审者不复跑测试"条目 |
| `docs/decisions/0005-review-readonly.md` | 新增:取消副本改只读直审的完整决策(背景含事故与 slim-review-copy 废弃任务的实证结论、被否备选、残留风险与抽查机制预留) |
| `docs/decisions/0004-review-action-boundary.md` | 顶部加"已被 0005 取代"标注(历史不删除) |

## 修复对照

(第 1 轮,不适用)

## 测试结果

测试脚本与完整输出均在 `evidence/`(test-script-units.sh /
test-e2e-readonly.sh / tc01-03-e2e.txt / tc04-08-units.txt 及各 codex
完整原始输出)。TC-01/02/03 为真实 codex;TC-05~08 经 PATH 前置 codex
桩绑定 review.sh 实际执行路径。

| 编号 | 结果 | 证据 |
|---|---|---|
| TC-01 | 通过 | 端到端真实一轮(证据齐全夹具):verdict=pass、退出码 0 一致;运行前后均无 rawf-review-* 副本目录;指纹通过。完整输出+退出码:tc01-review-full-output.txt,结论文件副本:tc01-review-round-01-pass.md |
| TC-02 | 通过 | 真实 read-only 探针:codex 退出码 0,`touch probe.txt` 被拒(输出含拒绝证据),夹具无 probe.txt、`git status` 干净。完整输出:tc02-readonly-probe-full-output.txt |
| TC-03 | 通过 | 证据置空夹具:verdict=fail、退出码 1;blocker detail 逐条开出补交清单(TC-01/TC-02 各自的命令、完整输出、退出码)——打回协议实证生效。完整输出:tc03-review-full-output.txt,结论文件副本:tc03-review-round-01-fail.md |
| TC-04 | 通过 | `__workspace_hash`:改已跟踪文件指纹变、还原复原、仅写 .claude/settings.local.json 指纹不变。tc04-08-units.txt |
| TC-05 | 通过 | 预置 .review-lock → exit 3,stderr 含"已有评审在进行中" |
| TC-06 | 通过 | 已有 review-round-01 → exit 3,stderr 含"拒绝重评" |
| TC-07 | 通过 | 桩记录 argv:含 `--sandbox read-only`、不含 workspace-write、`-C` 值即夹具根路径(直审非副本);桩调用时刻无 rawf-review-* 目录;结论正常发布、退出码 0 |
| TC-08 | 通过 | 桩于评审期间追写已跟踪文件 → exit 3、stderr 含"主工作区在评审期间发生改动"、无 review-round 发布(指纹否决生效) |

合计:单测 17 断言 + 端到端 14 断言,全部通过。

## 与方案的偏差

- review-standards.md 开头段("不在工作区新建或改动任何文件"的措辞)
  随只读语义顺带从"运行产物除外"改为"机器强制",plan 未逐字列出该句,
  属"动作边界重写"范围内的同质修订,无语义外溢。
- 其余与 plan 一致,无偏差。
