---
task: review-readonly
round: 02
date: 2026-07-18
---

# 实现记录:第 02 轮

## 本轮改动

修复第 01 轮评审的 1 blocker + 1 minor。除 R-02 的空行清理外,
**源码与文档零改动**,其余全部在测试/证据层。

| 文件 | 改动摘要 |
|---|---|
| `docs/decisions/0004-review-action-boundary.md` | R-02:删除取代标注后的两个多余空行 |
| `evidence/test-script-units.sh` | 升级为"断言 + 承重原始数据"全量模式:TC-04 打印四次指纹实际值与各命令退出码;TC-05/06 dump review.sh 完整 stderr 与 rc;TC-07 dump 桩完整 argv、副本探测原始输出、review.sh 完整 stdout/stderr、发布文件内容、`-C` 实际值;TC-08 dump 完整 stderr/stdout、发布文件 ls 原始输出 |
| `evidence/test-e2e-readonly.sh` | 同模式升级:TC-01 记录运行前后 rawf-review-* 原始清单;TC-02 记录探针完整命令、codex rc、探针后完整 `git status` 输出;TC-03 记录包装命令。另为三处 codex 调用加 900s 看门狗(自测中实测一次 codex 挂死 >2h,看门狗保证快速失败;不改变断言语义) |
| `evidence/tc04-08-units.txt` | 重跑输出:首行记录实际调用命令,末行记录最终退出码,中间为全部断言与原始数据(18 断言全过) |
| `evidence/tc01-03-e2e.txt` | 重跑输出:同上格式(14 断言全过);各 codex 完整原始输出同步刷新(tc01/tc02/tc03-*-full-output.txt 与结论文件副本) |

## 修复对照

| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| R-01 | blocker | 两份测试脚本升级为原始数据全量落盘并完整重跑。逐项对照索要清单:TC-01 运行前后 rawf-review-* 原始清单(tc01-03-e2e.txt "运行前/后原始清单"段,均为"(无匹配)");TC-02 探针命令、codex rc、探针后完整 git status(同文件 TC-02 段);TC-03 包装命令(同文件 TC-03 段首);TC-04 四个指纹实际值与四次 rc(tc04-08-units.txt TC-04 段);TC-05/06 review.sh 完整 stderr(同文件 RAW 段);TC-07 桩完整 argv、副本探测原始输出、review.sh stdout、结论文件内容、rc(同文件 RAW 段);TC-08 完整 stderr、发布文件检查原始输出、rc(同文件 RAW 段);两份脚本的实际调用命令与最终退出码(两份 .txt 的首行与末行) |
| R-02 | minor | 0004 取代标注后的多余空行已删除 |

## 测试结果

| 编号 | 结果 | 证据 |
|---|---|---|
| TC-01 | 通过(重跑) | verdict=pass、rc=0 一致;运行前后 rawf-review-* 原始清单均空;指纹通过。tc01-03-e2e.txt + tc01-review-full-output.txt + tc01-review-round-01-pass.md |
| TC-02 | 通过(重跑) | codex rc=0,touch 被拒,探针后完整 git status 干净。同上 + tc02-readonly-probe-full-output.txt |
| TC-03 | 通过(重跑) | verdict=fail、rc=1,blocker detail 逐条开出证据补交清单。同上 + tc03-review-full-output.txt + tc03-review-round-01-fail.md |
| TC-04~TC-08 | 通过(重跑) | 18 断言全过,含全部承重原始数据。tc04-08-units.txt |

合计:单测 18 断言 + 端到端 14 断言,全部通过,原始数据全量入档。

## 与方案的偏差

- 测试脚本为 codex 调用增加 900s 看门狗:自测过程中实测一次 codex 进程
  挂死超过 2 小时无进展(已终止重跑),看门狗仅保证测试快速失败,不改变
  任何断言语义;review.sh 本身未加超时(评审时长波动大,后台运行方式
  已由 rawf-review skill 约定,是否给正式评审加超时留待后续任务议定)。
- 其余无偏差。
