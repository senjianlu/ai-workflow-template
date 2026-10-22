---
task: scope-guard-and-evidence-format
round: 02
date: 2026-10-22
---

# 实现记录:第 02 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/evidence.sh` | 中断处理重写:转发**收到的同一信号**给整组;wait 被信号打断后不再回到阻塞的 wait,改为有界轮询(0.2 s × 25,等整组消失),到点 KILL 整组;退出码固定 INT=130 / TERM=143;被包命令经 `( trap - INT; exec setsid … ) &` 启动,恢复默认 INT 处置;tee 加 `-i`;子进程启动前到达的信号补发;头注释补充后台启动时 INT 不可 trap、未中断时不清理子进程组 |
| `.ai-workflow/scripts/evidence-check.sh` | 补交清单改写到 **stderr**(报告表仍在 stdout);每条清单条目统一带判定标记(EMPTY-TABLE / MISSING-ROW / TIER-MISMATCH / BLOCKED / NO-REF,文件类条目原本已带) |
| `.ai-workflow/scripts/review.sh` | 调用 evidence-check 时 `2>&1` 合并捕获:通过时注入的仍是纯报告,未通过时报告与补交清单整段原样转 stderr |
| `evidence/tc-04.sh` | 新增 (b) 子进程忽略 TERM、(c) INT、(d) 子进程捕获 TERM 后 exit 0、(e) 整组 INT(模拟终端 Ctrl-C)、(f) 无残留进程、(g) 被包命令 pid=pgid=sid |
| `evidence/tc-07.sh` | stdout 与 stderr 分别捕获;断言补交清单在 stderr、逐条含编号与判定标记、stdout 不含清单条目 |

## 修复对照
| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| R-01 | major | wait 被信号打断后跳出阻塞循环,进入 5 s 有界轮询,到点 KILL 整组,随后照常写尾部;不另起计时器进程(先试过独立计时器,取消时有竞态会留下孤儿 sleep,已弃用)。组长退出后残留的后代同样在宽限内等待或被 KILL,不会卡住 tee。验证:TC-04 (b) 子进程 `trap "" TERM` 时约 5 s 后收尾、exit 143、子进程不存活;(f) 无残留进程 |
| R-02 | major | 记下收到的信号,清理完成后按信号固定退出码 INT=130、TERM=143,不取子进程状态;转发时用同一信号而非一律 TERM。修复中发现被包命令以 `&` 启动、按 POSIX 天生忽略 INT,转发的 INT 无效,改为子 shell 内 `trap - INT` 后 exec;tee 加 `-i` 使整组 INT 时仍能收录收尾输出。验证:TC-04 (c) INT → 130;(d) 子进程捕获 TERM 后 exit 0 → 仍为 143;(e) 整组 INT 时子进程收尾输出被完整收录、立即结束、exit 130;(g) setsid 未分叉 |
| R-03 | major | 补交清单写 stderr,条目统一带判定标记;review.sh 合并捕获两路输出,失败诊断完整保留。验证:TC-07 分别捕获两路并断言;TC-09、TC-16 断言 review.sh 的 stderr 仍含"证据核验未通过"与补交清单 |

## 测试结果
<!-- 留证写法 (b):每条用例一个断言脚本 evidence/tc-NN.sh(公共库 evidence/lib.sh),
     由 evidence.sh 包住产出;exit 0 = 该用例全部断言成立。三个脚本本轮均有改动,
     19 条全部以 -l r02 重新留证;第 01 轮证据文件保留不动(.ai/ 只增不改)。 -->
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01-r02.log |
| TC-02 | A | pass | TC-02-r02.log |
| TC-03 | A | pass | TC-03-r02.log |
| TC-04 | A | pass | TC-04-r02.log |
| TC-05 | A | pass | TC-05-r02.log |
| TC-06 | A | pass | TC-06-r02.log |
| TC-07 | A | pass | TC-07-r02.log |
| TC-08 | A | pass | TC-08-r02.log |
| TC-09 | A | pass | TC-09-r02.log |
| TC-10 | A | pass | TC-10-r02.log |
| TC-11 | A | pass | TC-11-r02.log |
| TC-12 | A | pass | TC-12-r02.log |
| TC-13 | A | pass | TC-13-r02.log(shellcheck 仍未安装,已在正文记录;bash -n 四个脚本通过) |
| TC-14 | A | pass | TC-14-r02.log |
| TC-15 | A | pass | TC-15-r02.log |
| TC-16 | A | pass | TC-16-r02.log |
| TC-17 | A | pass | TC-17-r02.log |
| TC-18 | A | pass | TC-18-r02.log |
| TC-19 | A | pass | TC-19-r02.log |

## 与方案的偏差
<!-- 第 01 轮的 D-01 ~ D-04 仍然有效,不再重复。 -->
| 编号 | 类型 | 内容 | 原因 | 处置 |
|---|---|---|---|---|
| D-05 | 替代 | evidence.sh 中断机制的具体做法:plan 写"trap INT/TERM 转发给子进程、等其退出,仍写出尾部";实现为转发同一信号 + 5 s 有界轮询后 KILL 整组 + 被包命令启动前恢复默认 INT + tee -i | 评审 R-01 / R-02;以及 plan 承诺的"转发 INT"在原实现下实际无法送达(被包命令天生忽略 INT) | 目标与 plan 一致,无新增对外行为 |
| D-06 | 替代 | TC-04 由单一 TERM 场景扩为 (a)~(g) 七个场景;(a) 的步骤与预期不变 | (b)(c)(d) 为评审 R-01 / R-02 明确要求补充;(e)(g) 验证 D-05 的修复点;(f) 验证无孤儿进程。(c)(e) 在断言脚本中以 `set -m` 后台启动,否则被测脚本按 POSIX 以忽略 INT 的状态启动,INT 无从送达 | 只增断言,不改 plan 的预期结果 |

## 停车场
- 本机存在 steammarket-refinery 旧会话遗留的孤儿轮询循环:`until … docker build … ; do sleep 5; done`,父进程已为 1,在等 2026-09-23/init-refinery 任务的构建日志,条件可能永远不满足。与本任务无关,未处理,交用户决定是否清理
- plan 评审 fail 率约 75%、实现评审中位 2 轮的成因分析与收敛(本任务非目标)
- 四个 consumer 项目升级到 1.1.0(按 CHANGELOG 升级指引,各项目自行执行)
- 本机未安装 shellcheck;安装后可补跑 TC-13 的 shellcheck 部分
