---
task: plan-review-convergence
round: 02
date: 2026-10-22
---

# 实现记录:第 02 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/plan-review.sh` | `build_round_context` 按 diff 退出码区分:0 = 未修订、1 = 有修订、其它 = 失败;失败时 stderr 报"修订 diff 生成失败(diff 退出码 N,上一轮快照 …)"并返回 3;主流程 `round_context=$(build_round_context) \|\| exit 3`,codex 不启动、不发布、不消耗轮次 |
| `evidence/tc-05.sh` | 新增 ② 上一轮快照不可读、③ diff 命令执行失败(PATH 前置退出码 2 的假 diff)、④ 排除故障后重跑仍为第 03 轮且为收敛模式 |

## plan 评审 minor 交接
(仅第 1 轮填写;见 implementation-round-01)

## 修复对照
| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| R-01 | major | 去掉 `\|\| true`,记录 diff 退出码;> 1 即报错返回 3 并经 `\|\| exit 3` 传到主流程,不再落入"未修订"分支。验证(TC-05-round02.log):② 快照 chmod 000 → exit 3、stderr 含"修订 diff 生成失败"、假 codex 未调用、无第 03 轮评审文件;③ 假 diff 退出 2 → exit 3、stderr 含"diff 退出码 2"、同上;④ 恢复后重跑 → exit 0、模式为收敛评审、diff 含 `+第三行`、生成第 03 轮评审文件 |

## 测试结果
<!-- 留证写法 (b),同第 01 轮。plan-review.sh 本轮有改动,12 条全部以 -l round02 重新留证。 -->
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01-round02.log |
| TC-02 | A | pass | TC-02-round02.log |
| TC-03 | A | pass | TC-03-round02.log |
| TC-04 | A | pass | TC-04-round02.log |
| TC-05 | A | pass | TC-05-round02.log |
| TC-06 | A | pass | TC-06-round02.log |
| TC-07 | A | pass | TC-07-round02.log |
| TC-08 | A | pass | TC-08-round02.log(error 级 0 条;默认级别与改动前相同) |
| TC-09 | A | pass | TC-09-round02.log |
| TC-10 | A | pass | TC-10-round02.log |
| TC-11 | A | pass | TC-11-round02.log |
| TC-12 | A | pass | TC-12-round02.log |

## 与方案的偏差
<!-- 第 01 轮 D-01、D-02 仍然有效,不再重复。 -->
| 编号 | 类型 | 内容 | 原因 | 处置 |
|---|---|---|---|---|
| D-03 | 替代 | TC-05 在原有"无上一轮快照回退"场景之外,增加 ②③④ 三个 diff 失败与恢复场景;原场景的步骤与预期不变 | 评审 R-01 明确要求"补充 diff 执行失败的异常用例" | 只增断言 |

## 停车场
- (同第 01 轮)review.sh 注入证据报告时受 `patsub_replacement` 影响,cmd 列 `\&` 丢反斜杠,仅影响显示;review.sh 在本任务"明确不动"清单内,未处理
- (同第 01 轮)shellcheck warning/note 级既有条目,本任务非目标
