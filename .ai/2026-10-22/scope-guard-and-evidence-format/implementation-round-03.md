---
task: scope-guard-and-evidence-format
round: 03
date: 2026-10-22
---

# 实现记录:第 03 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/evidence.sh` | 中断处理按启动时序重排:① trap 在证据文件建立后**立即**安装(早于写头部);② 写完头部若已被中断,**不再启动**被包命令,直接写尾部;③ 去掉一切阻塞的 `wait`,主循环每 0.2 s 轮询,同时覆盖"等组长退出"与"等 tee 排空"两段;④ 转发改为 `try_forward`:kill 成功才置位,进程组未建立时逐拍重试;⑤ 中断后第 25 拍(5 s)KILL 整组与组长,第 30 拍仍未排空则终止 tee,全程有界;头注释同步 |
| `evidence/tc-04.sh` | 新增启动时序三场景:(h) 进程组未建立时中断且子进程忽略 TERM;(h2) 同一时间窗、子进程响应 TERM,验证转发重试;(i) 被包命令启动前中断。用 PATH 前置的假 `setsid` / 假 `git` 制造可确定的时间窗,不在生产脚本加测试钩子;各中断场景产出的证据文件再过一遍 evidence-check |

## 修复对照
| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| R-01 | major | 启动阶段的中断不再可能落入阻塞的 wait:主循环不用阻塞 wait,任何时刻到达的信号最迟下一拍(0.2 s)被处理;启动前到达则不启动被包命令;转发失败(进程组未建立)不置位、逐拍重试;宽限到点 KILL。同时收掉同类缺口:旧代码组长退出后对 tee 的阻塞 wait 在排空阶段收到中断时会提前写尾部,现并入同一轮询循环。验证(TC-04-r03.log):(h) 组未建立时中断、子进程忽略 TERM → 143,5954ms 收尾,子进程不存活;(h2) 组在 2 s 时建立,重试转发即送达,2265ms 收尾,正文含子进程收尾输出;(i) 启动前中断 → 被包命令未执行(标记文件不存在),正文 0 字节,143,3045ms;三者证据文件均通过 evidence-check |

## 测试结果
<!-- 留证写法 (b):每条用例一个断言脚本 evidence/tc-NN.sh(公共库 evidence/lib.sh),
     由 evidence.sh 包住产出;exit 0 = 该用例全部断言成立。evidence.sh 本轮有改动且
     全部用例依赖它,19 条全部以 -l r03 重新留证;前两轮证据文件保留不动。 -->
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01-r03.log |
| TC-02 | A | pass | TC-02-r03.log |
| TC-03 | A | pass | TC-03-r03.log |
| TC-04 | A | pass | TC-04-r03.log |
| TC-05 | A | pass | TC-05-r03.log |
| TC-06 | A | pass | TC-06-r03.log |
| TC-07 | A | pass | TC-07-r03.log |
| TC-08 | A | pass | TC-08-r03.log |
| TC-09 | A | pass | TC-09-r03.log |
| TC-10 | A | pass | TC-10-r03.log |
| TC-11 | A | pass | TC-11-r03.log |
| TC-12 | A | pass | TC-12-r03.log |
| TC-13 | A | pass | TC-13-r03.log(shellcheck 仍未安装,已在正文记录;bash -n 四个脚本通过) |
| TC-14 | A | pass | TC-14-r03.log |
| TC-15 | A | pass | TC-15-r03.log |
| TC-16 | A | pass | TC-16-r03.log |
| TC-17 | A | pass | TC-17-r03.log |
| TC-18 | A | pass | TC-18-r03.log |
| TC-19 | A | pass | TC-19-r03.log |

## 与方案的偏差
<!-- 第 01 轮 D-01 ~ D-04、第 02 轮 D-05 ~ D-06 仍然有效,不再重复。 -->
| 编号 | 类型 | 内容 | 原因 | 处置 |
|---|---|---|---|---|
| D-07 | 替代 | evidence.sh 由"阻塞 wait + 信号打断后转轮询"改为"全程 0.2 s 轮询";未中断时收尾延迟最多增加 0.2 s | 评审 R-01:阻塞 wait 在启动时序上无法保证有界 | 对外行为与 plan 一致 |
| D-08 | 替代 | TC-04 再增 (h)(h2)(i) 三场景,(a) 的步骤与预期不变 | 评审 R-01 明确要求"补充可确定触发首次 wait 前中断的验证" | 只增断言,不改 plan 的预期结果 |

## 停车场
- 本机存在 steammarket-refinery 旧会话遗留的孤儿轮询循环:`until … docker build … ; do sleep 5; done`,父进程已为 1,在等 2026-09-23/init-refinery 任务的构建日志,条件可能永远不满足。与本任务无关,未处理,交用户决定是否清理
- plan 评审 fail 率约 75%、实现评审中位 2 轮的成因分析与收敛(本任务非目标)
- 四个 consumer 项目升级到 1.1.0(按 CHANGELOG 升级指引,各项目自行执行)
- 本机未安装 shellcheck;安装后可补跑 TC-13 的 shellcheck 部分
