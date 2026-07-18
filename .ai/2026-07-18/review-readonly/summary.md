---
task: review-readonly
date: 2026-07-18
rounds: 2
verdict: pass
---

# 任务小结:评审只读直审原仓库(取消副本),测试核验改走证据打回协议

## 改动

| 文件 | 摘要 |
|---|---|
| .ai-workflow/scripts/review.sh | 删除副本机制,`--sandbox read-only` 直审原仓库(与 plan-review.sh 同构);raw 输出直接落任务目录;新增 `__workspace_hash` 测试入口;锁/轮次/同轮唯一/指纹/交叉校验/mv -n 发布/退出码全部保持 |
| .ai-workflow/review-standards.md | 「评审动作边界」重写:只读前提;不运行任何测试;证据协议统一适用(缺失/不完整 → blocker 且必须开出补交清单;矛盾 → 虚报 blocker) |
| .ai-workflow/prompts/review.md | 评审指令切到证据核验协议 |
| .claude/skills/rawf-implement/SKILL.md | 第 5 步:所有测试用例完整原始输出强制落 evidence/ |
| README.md | 机制速览更新;依赖/限制如实声明"评审者不复跑测试" |
| docs/decisions/0005-review-readonly.md | 新增:完整决策(背景含 2026-07-17 下游事故与 slim-review-copy 废弃探索的实证结论、被否备选、残留风险与抽查预留) |
| docs/decisions/0004-review-action-boundary.md | 顶部加"已被 0005 取代"标注 |

背景:下游 cscheap-frontend 换页风暴事故(评审全量复制 2.4G 为主要
放大器)+ 同日副本瘦身探索(slim-review-copy,已废弃)证明副本路线
复杂度过高;用户拍板转只读直审,推翻 0004 的 B 案选择。

## 评审历程

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| plan-01 | fail | major:测试未绑定 review.sh 实际执行路径(补桩测试 TC-07/08) |
| plan-02 | pass | 无 |
| impl-01 | fail | blocker:证据只有断言结论,缺承重原始数据;minor:0004 多余空行 |
| impl-02 | pass | 遗留 1 minor(见下) |

自测规模:单测 18 断言 + 真实 codex 端到端 14 断言(正常一轮 pass、
只读探针写被拒、证据置空触发打回清单),全部通过,原始数据全量入档
evidence/。过程发现:一次 codex 进程挂死 >2h,测试脚本已加 900s
看门狗;review.sh 本身是否加超时留待后续任务。

## 遗留 minor 及处置

- R-01(impl-02 轮):plan-review.sh:3 顶部注释仍称"review.sh 那套
  副本隔离与完整性哈希",已过时 / 用户决定:本次修(已随收尾改为
  "与 review.sh 同构,仅不设完整性哈希双保险"的准确表述)
