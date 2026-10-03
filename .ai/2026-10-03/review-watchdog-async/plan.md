---
status: approved
task: review-watchdog-async
date: 2026-10-03
approved_at: 2026-10-04 00:05
plan_review_max_rounds: 8
impl_fix_max_rounds: 8
---

# 方案:Codex 评审卡死治理——stdin 兜底、事件流看门狗、flock 锁、评审异步化

> frontmatter 的 `plan_review_max_rounds: 8` / `impl_fix_max_rounds: 8` 为
> **用户在本任务中明确要求**("plan 和改修的评审最大 8 轮"),非自行写入。

## 背景与目标

现状(调研结论,证据见文末「评审者独立核查清单」与 assets/):

1. **codex 在 stdin 非终端时必读 stdin 到 EOF**。`codex exec --help` 原文:
   "If stdin is piped and a prompt is also provided, stdin is appended as a
   `<stdin>` block";本机探针(assets/codex-json-probe-stderr.log)在
   `</dev/null` 下仍打印 "Reading additional input from stdin..."。两个评审
   脚本都未重定向 stdin,一旦调用方给的是不关闭的管道/套接字,codex 永远
   等输入。**本任务第 5 轮 plan 评审即为现场标本**(assets/stdin-hang-specimen.log):
   Claude Code 后台 Bash 本次给 codex 的 stdin 是 unix socket,codex 打印
   "Reading additional input from stdin..." 后主线程阻塞在
   `unix_stream_data_wait`,27 分钟 0% CPU、未创建任何会话,被手动 TERM。
   同一调用方式在第 1~4 轮为 /dev/null 正常完成——stdin 形态完全取决于
   调用方且不稳定,脚本必须自保。
2. **codex 内部卡死(CPU 0%)无任何兜底**。脚本对 codex 没有超时;唯一上限
   是 Claude Code 后台命令时限(默认 30 分钟),到点杀的是外层 bash,codex
   子进程(含 codex-code-mode-host)可能被遗弃,锁目录可能残留。
3. **锁不可自愈**。锁为 mkdir 空目录、不记 pid,进程被杀后残留,残留与活锁
   无法区分,只能靠 Claude `pgrep` 后手删——rawf-review SKILL 第 1 步因此
   写进了手工删锁流程。
4. **Stop hook 与后台评审互相拧着**。gate-review.sh 在"最新实现轮无评审
   文件"时一律 block,不区分"评审正在后台跑"。SKILL 又要求"后台运行并等待
   完成",Claude 只能原地 sleep 轮询(本机现存一个 4 天前会话遗留的
   `sleep 15` 循环),或在被 block 后自言自语"评审已在后台运行"再结束一次
   (hook 第二次因 `stop_hook_active` 放行)。Claude Code 对后台 Bash 的定义
   是"跨回合继续运行,退出时重新唤起 Claude",Stop hook 输入也带
   `background_tasks` 数组——设计上就允许回合结束时有后台任务。

历史数据(assets/codex-review-session-stats.txt,扫描 ~/.codex/sessions 中
由 review.sh / plan-review.sh 发起的全部 1625 次 codex 评审):

| 1595 次正常完成 | 总耗时 | 相邻事件最大间隔 |
|---|---|---|
| p50 | 2.7 min | 0.3 min |
| p99 | 13.6 min | 2.9 min |
| 最大 | 43.7 min | 22.7 min(API 流断后重试 3 次,token 计数不变) |

30 次未完成的会话全部在 6 分钟内停止记录,最后事件均为正常工具输出/token
计数,之后再无事件——与"请求发出后再无响应"的卡死形态一致。

目标:

- 两个评审脚本自保:stdin 兜底;**事件流静默看门狗**(默认 15 分钟,对
  1595 次历史正常评审误杀 ≤ 1 次)+ **墙钟上限**(默认 60 分钟,误杀 0 次);
  超时杀 codex **整个进程组**,以 exit 3 明确报因;脚本被外部 TERM 时同样
  清理 codex 与锁。
- 锁改用内核文件锁 `flock`:持有者进程(含其 fork 出的 codex)全部退出即
  自动释放,**不存在残留锁,也就不需要任何回收协议**;并发第二实例
  `flock -n` 立即失败退出。
- Stop hook 识别"评审进行中":对**当前任务目录**的实现评审锁文件做
  `flock -n` 试探,被持有 → 放行;否则维持原拦截。不看 `background_tasks`
  的命令字符串(无法区分仓库/任务/评审类型)。
- skill 改为"后台启动评审后直接结束回合,完成通知唤回后再分流",删除手工
  pgrep/删锁指引。
- 不采用 CPU 采样判卡死:codex 正常状态绝大多数时间也在等 API,CPU 接近 0,
  3 分钟窗口找不到能分开"正常等待"与"卡死"的阈值;事件流是进度的直接度量,
  分布已量化。

## 改动范围

| 文件 | 改动 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 工具前置检查(flock/setsid/pgrep);stdin 兜底;`--json` 事件流落盘;看门狗(静默/墙钟);会话+进程组终止;TERM/INT trap;锁改 flock 文件;hash_excludes 增 `.review-lock` |
| `.ai-workflow/scripts/plan-review.sh` | 同上(无指纹段);锁文件 `.plan-review-lock` |
| `.claude/hooks/gate-review.sh` | 当前任务 `.review-lock` 被 flock 持有 → 放行;否则原拦截 |
| `.claude/skills/rawf-review/SKILL.md` | 第 1 步改为异步模式;删 pgrep/删锁指引;新增超时/残留锁的处置说明 |
| `.claude/skills/rawf-plan/SKILL.md` | 第 6 步同样改为异步模式 |
| `.gitignore` | 增 `.ai/**/.review-lock`、`.ai/**/.plan-review-lock`(锁文件常驻、不删除) |
| `README.md` | 「机制速览」更新 gate-review.sh 与 review.sh 两行;「前置依赖」增 util-linux(flock、setsid)与 procps(pgrep) |
| `CHANGELOG.md` | 新增 `[Unreleased]` 条目(含升级指引;发版号由用户在发版时定) |
| `docs/decisions/0009-review-watchdog-async.md` | 新增决策记录 |

共 9 个文件(≤ 10)。用户明确要求本任务仍走 plan 评审,且上限 8 轮。

明确不动:`.ai-workflow/prompts/*`、`schemas/*`、`review-standards.md`、
gate-plan.sh、rawf-implement / rawf-report SKILL、评审产物命名与退出码语义
(0=pass 1=fail 3=异常,超时归入 3)。

## 实现方案

### 1. 脚本公共形态(review.sh 与 plan-review.sh 同构实现,各自内联,不抽公共文件)

**参数**(环境变量,正整数;非法 → stderr 报错 exit 3):

| 变量 | 默认 | 含义 |
|---|---|---|
| `RAWF_REVIEW_IDLE_SECONDS` | 900 | 事件流连续无新字节的上限 |
| `RAWF_REVIEW_MAX_SECONDS` | 3600 | 墙钟上限(纯兜底) |
| `RAWF_REVIEW_POLL_SECONDS` | 5 | 看门狗轮询间隔(测试用小值) |

**stdin 兜底**:`codex exec ... </dev/null`。

**事件流落盘**:加 `--json`,stdout 重定向到 `$task_dir/.review-raw-NN.events.jsonl`
(plan:`.plan-review-raw-NN.events.jsonl`)。文件名命中既有 `.review-raw-*` /
`.plan-review-raw-*` 的 .gitignore 与 hash_excludes 模式,**不新增忽略项、
不扰动指纹**。codex stderr 仍直通脚本 stderr。探针已验证 `--json` 与
`--output-schema`、`--output-last-message` 可同用(assets/codex-json-probe-*)。

**工具前置检查**:脚本开头 `command -v flock setsid pgrep`,缺任一 → stderr
"需要 util-linux(flock、setsid)与 procps(pgrep)" exit 3。本模板明确以
Linux 为运行环境(macOS 可 `brew install util-linux` 补齐),不再为无 setsid
的环境提供降级清理路径——降级路径只覆盖直接子进程,兑现不了"完整清理"。

**启动与受管进程集合**:`setsid codex ... &`,codex 成为新会话与新进程组的
首进程,其全部后代默认同会话同组。受管集合 = `pgrep -s $pid`(同会话)∪
`pgrep -g $pid`(同进程组)∪ `$pid` 本身。终止流程 `kill_codex_tree`:
1. `kill -TERM -- -$pid`,并对受管集合逐 pid `kill -TERM`;
2. 轮询至多 10 秒,受管集合为空即结束;
3. 仍有存活 → 对当时的受管集合(重新 `pgrep` 取,覆盖中途改挂父进程的
   后代)逐 pid `kill -KILL` 并 `kill -KILL -- -$pid`;
4. 再轮询 3 秒,仍有存活 → stderr 列出残留 pid(不阻断脚本退出)。
受管集合以会话 id 为主键,中间进程退出后后代被 init 收养仍保留原 sid/pgid,
`pgrep -s` 仍能命中;只有后代主动 `setsid` 另起会话才会逃逸(codex 的
`/bin/bash -lc` 工具执行为非交互 shell,不另起会话)。

**看门狗循环**(替代裸 `wait`):

```
start=$SECONDS; last_size=0; last_change=$SECONDS; reason=
while kill -0 "$codex_pid" 2>/dev/null; do
  sleep "$poll"
  kill -0 "$codex_pid" 2>/dev/null || break   # 醒来先查:已结束则不做超时判定
  size=$(wc -c < "$events" 2>/dev/null || echo 0)
  [ "$size" != "$last_size" ] && { last_size=$size; last_change=$SECONDS; }
  [ $((SECONDS - last_change)) -ge "$idle" ] && { reason=idle; break; }
  [ $((SECONDS - start)) -ge "$max" ] && { reason=max; break; }
done
```
codex 在最后一个轮询窗口内正常结束时,醒来后的存活检查先于超时判定,
不会把已完成的评审误判为超时(TC-17)。`reason` 非空 → 终止进程组,stderr 报
"评审 N 秒无新事件,判定卡死,已终止;请重跑评审"(或"评审超过墙钟上限 N 秒,已终止"),
exit 3(走既有"codex 执行失败"分支语义);为空 → `wait $codex_pid` 取真实退出码,
后续流程不变。以文件字节数而非 mtime 作进度信号,避免 GNU/BSD `stat` 差异。

**trap**:`trap cleanup EXIT`,`trap 'exit 143' TERM`、`trap 'exit 130' INT`;
cleanup 仅做 `kill_codex_tree`(锁由内核随 fd 关闭自动释放,脚本不删锁文件)。
bash 的 `sleep` 结束后才处理信号,延迟 ≤ poll 秒。

**锁(flock)**:锁为任务目录下常驻的普通文件 `.review-lock`
(plan:`.plan-review-lock`)。文件内容为一行诊断信息 `script=<脚本 pid>`
(不参与互斥判定,也不参与持有者定位)。

获取流程 `acquire_lock`:
0. **旧协议残留**:`$lock` 存在且是目录(旧版 mkdir 锁残留)→ stderr
   "检测到旧版锁目录 $task_rel/.review-lock(升级前残留);确认
   `pgrep -f 'codex exec'` 无旧评审进程后执行 rmdir 再重跑" exit 3。
   一次性迁移步骤同时写入 CHANGELOG 升级指引与 rawf-review SKILL。
1. `exec 9>>"$lock"`(追加模式打开,不截断;打开失败 → "无法打开锁文件" exit 3)。
2. `flock -n -E 75 9`:退出 0 → 获得锁;**75(专用冲突码)→ 锁被持有,
   进入第 3 步**;其它退出码 → "锁探测失败(flock 退出码 N)" exit 3,
   不猜测。
3. 锁被持有时定位持有者:先 `exec 9>&-` 关闭本实例自己的锁 fd,再由
   `lock_holders` 扫描 `/proc/[0-9]*/fd/*`:对 `readlink` 指向锁文件
   (`realpath` 比对)的每个 fd,读其 `/proc/<pid>/fdinfo/<fd>`,**仅当**
   其中含 `lock:` 行、类型为 `FLOCK` 且 inode 与锁文件 `stat -c %i` 一致时
   计为持有者;排除本实例 pid;输出 `pid 命令名`。fdinfo 的 lock 行标识的
   是"持锁的打开文件描述",被继承的 fd 同样带该行,而仅打开未持锁的 fd
   没有(本机探针 assets/flock-fdinfo-probe.log:父进程被 KILL 后子进程
   fdinfo 仍含 lock 行;`/proc/locks` 里的 pid 则是已退出的 flock 命令进程,
   不可用)。**定位不依赖锁文件里的任何元数据**,因此不存在"codex 已启动、
   元数据尚未写入"的窗口;也不会把报错实例本身、扫描子进程或其它只打开
   文件的进程列入。stderr 报:
   "已有评审在进行中,锁 $task_rel/.review-lock 被以下进程持有:<pid 命令名
   列表>。若列表中已无 review.sh 脚本进程(记录的脚本 pid X 已退出),则为
   脚本被强杀后遗留的评审进程,确认后执行 `kill -TERM <pid 列表>` 再重跑",
   exit 3。**脚本不自动清理遗留进程**(是否终止由用户决定)。
4. 获得锁后 `printf 'script=%s\n' "$$" > "$lock"`(仅用于报错时区分
   "正常并发"与"遗留")。

性质:① 获取是内核原子操作,无"mkdir 后写 pid"的初始化窗口;② 释放随
持有 fd 的全部进程退出自动发生——脚本与 codex 都死了锁就空出来,**没有
残留态,因此没有回收协议,也就没有第 1 轮 R-01 的两类竞态**;脚本被
SIGKILL 而 codex 仍持锁的路径不做自动清理,只精确报告持有者与处置命令
(第 3 步);③ 锁文件永不删除(删除-重建会让两个打开者
持有不同 inode 的锁),故加入 .gitignore 与 hash_excludes。
"检查—评审—发布"全程互斥由 fd 9 在脚本整个生命周期持有保证。
hash 影响:锁文件在 pre_hash 前已存在、post_hash 后仍存在且被排除,指纹
前后一致。

### 2. gate-review.sh

在现有"无评审文件 → block"之前插入一条放行判断,**只认一个精确信号**:
`$task_dir/.review-lock` 是普通文件,且 `flock -n -E 75 "$lock" true` 的
退出码**恰为 75**(专用冲突码 = 锁被持有)→ `exit 0` 放行。其它一切情形
均不放行、继续原拦截逻辑:锁文件不存在(不创建)、是目录(旧残留)、
flock 命令缺失、打开/权限/文件系统不支持等任何非 75 的非零退出码。
即探测错误一律 fail-closed。

该判定天然限定在**当前仓库、当前任务、实现层评审**(plan-review 用的是
另一把锁 `.plan-review-lock`,不放行);不解析 `background_tasks` 的命令
字符串——其它仓库/任务的评审、plan 评审、仅引用同名字符串的命令都不会
误放行。其余逻辑(nullglob 计数、`stop_hook_active` 只拦一次)不变。

### 3. skill 措辞

rawf-review 第 1 步改为:后台运行 `bash .ai-workflow/scripts/review.sh`
(Claude Code 中以 `run_in_background` 启动并把 `timeout` 设为不低于
4 000 000 ms,高于脚本墙钟上限 60 分钟),**随后直接结束回合、不轮询**;
评审完成的通知会唤回 Claude,届时读取结果再分流。exit 3 的处置改为:
看门狗终止(stderr 含"已终止")→ 直接重跑一次;仍异常 → 报用户。删除
`pgrep` 与手动删锁段落(锁随进程退出自动释放;"进行中"报错说明确有评审
进程存活,把报错里的持有者列表与处置命令原样报用户,不自行执行 kill)。
唯一保留的手工步骤是升级后一次性的:报错含"旧版锁目录"时,确认
`pgrep -f 'codex exec'` 为空后 `rmdir` 该目录再重跑。
rawf-plan 第 6 步同步改为异步措辞。

### 4. 文档

- README「机制速览」:gate-review.sh 一行补"评审进行中放行";review.sh 一行
  补"事件流看门狗 + 墙钟兜底、flock 锁";「前置依赖」增 util-linux(flock、
  setsid)与 procps(pgrep)。
- CHANGELOG `[Unreleased]`:按 Keep a Changelog 列 Changed/Fixed,「升级指引」
  标注:scripts/hook/skill 属可整体替换类,.gitignore/README 需人工合并;
  hook 行为变更 → 建议发版时按 MAJOR 处理,由用户定。
- docs/decisions/0009:四段式,记录"事件流看门狗而非 CPU 采样""异步评审
  依赖 Claude Code 后台任务唤回,`claude -p` 无头模式不适用"两个取舍与
  被否备选(CPU 采样、仅墙钟超时、轮询等待)。

## 测试用例

<!-- 全部 A 档,C 档 0 条。脚本类用例统一使用 fixture + PATH 前置的 codex 桩
     (沿 .ai/2026-07-05、2026-07-07 两任务先例):fixture 为 scratchpad 下
     临时 git 仓库,含 .ai/.current-task、任务目录、implementation-round-01.md
     与 plan.md;桩行为由环境变量 STUB_MODE 控制,会解析 --output-last-message
     与 --json,按模式写文件/打事件/挂起/读 stdin。看门狗参数在测试中缩小:
     RAWF_REVIEW_IDLE_SECONDS=3、RAWF_REVIEW_MAX_SECONDS=8、
     RAWF_REVIEW_POLL_SECONDS=1。证据统一为:执行命令 + 完整 stdout/stderr +
     退出码,落 evidence/TC-NN.log。 -->

| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | fixture;桩 `pass`:打 3 行事件后写合法 pass JSON,exit 0 | `bash review.sh; echo $?` | 退出码 0;生成 `review-round-01-pass.md`;`.review-raw-01.events.jsonl` 存在且 3 行;`.review-lock` 存在、内容为 `script=<pid>` 一行、且 `flock -n .review-lock true` 立即成功 | 命令 + 完整输出 + 退出码 |
| TC-02 | A | fixture;桩 `stdin`:先 `cat` 读 stdin 到 EOF 再按 pass 行为;`mkfifo p`,独立启动写端生产者 `sleep 300 > p &` 并记录其 pid(**边界:stdin 兜底**) | `timeout 60 bash review.sh < p; echo $?`,只对 review.sh 计时;随后 `kill -0 $producer` 确认生产者仍存活,再 `kill $producer` 清理 | 退出码 0(60 s 内返回),生成 pass 文件;断言时生产者仍存活(证明 stdin 管道确未关闭,是脚本把 codex 的 stdin 接到了 /dev/null) | 命令 + 完整输出 + 退出码 |
| TC-03 | A | fixture;桩 `idle`:打 1 行事件后 `sleep 300`(**异常:静默卡死**) | `bash review.sh; echo $?` | 退出码 3;stderr 含"无新事件""已终止";无 review-round 文件;`pgrep -f stub-codex` 为空;锁可立即获取 | 命令 + 完整输出 + 退出码 |
| TC-04 | A | fixture;桩 `chatty`:每秒打 1 行事件,永不结束(**异常:墙钟兜底**) | 同上 | 退出码 3;stderr 含"墙钟上限";桩被杀;锁文件存在且 `flock -n .review-lock true` 立即成功;总耗时 < 20 s | 命令 + 完整输出 + 退出码 |
| TC-05 | A | fixture;桩 `tree`:① 中间进程 `bash -c 'sleep 300 & echo $! > grandchild.pid'`——它起后台孙进程后**立即退出**,孙进程改挂 init/subreaper;② `bash -c 'trap "" TERM; exec sleep 301' &`(忽略 TERM 的后代,exec 后 sleep 继承忽略态),pid 写 ignorer.pid;桩把自身 sid 写 stub.sid,再按 idle 行为(**边界:中间进程已退出的孙进程 + 忽略 TERM 的后代**) | 看门狗触发前(事件文件出现后 1 s)由测试断言:中间 bash 已退出(`pgrep -f 'sleep 300 &'` 无中间进程)、`kill -0 $(cat grandchild.pid)` 与 `kill -0 $(cat ignorer.pid)` 均存活、二者 sid 等于 stub.sid;然后等 `bash review.sh` 结束,`echo $?`;再查 `pgrep -s $(cat stub.sid)`、`kill -0` 两个 pid | 前置断言全部成立(场景真实构造出);退出码 3;受管会话无任何存活进程,孙进程与忽略 TERM 的进程均不存在(后者由 KILL 升级清掉);无 review-round 文件 | 命令 + 完整输出 + 退出码 |
| TC-06 | A | fixture;桩 `slow`(每秒打 1 行事件、持续 6 s 后写 pass JSON,不触发 idle=3);A 实例后台启动,轮询至 `flock -n .review-lock true` 失败(锁已被 A 持有)后再启动 B 实例(**边界:并发第二实例,确定性交错**) | `bash review.sh & A=$!; until ! flock -n .review-lock true; do sleep 0.2; done; bash review.sh; echo "B=$?"; wait $A; echo "A=$?"` | B 退出码 3 且 stderr 含"进行中"与 A 的脚本 pid;A 退出码 0 并生成唯一的 `review-round-01-pass.md`;`.review-raw-01.json` 只被 A 写过(B 未启动桩,无第二份事件文件) | 命令 + 完整输出 + 退出码 |
| TC-07 | A | fixture;桩 idle;`bash review.sh &` 后对脚本与桩会话全部 `kill -KILL`(模拟崩溃,trap 不执行)(**边界:崩溃后无残留锁**) | 确认全部死亡后立即再 `bash review.sh`(桩 pass);`echo $?` | 第二次运行退出码 0,**不出现**"进行中"或任何回收提示(锁随进程死亡由内核释放);生成 pass 文件 | 命令 + 完整输出 + 退出码 |
| TC-08 | A | fixture;桩 idle;`bash review.sh &` 启动后 2 s 向脚本 pid 发 TERM(**异常:外部终止**) | `kill -TERM $pid; wait $pid; echo $?`;再 `flock -n .review-lock true; echo $?` | 退出码非 0;桩会话无存活进程;锁可立即获取(退出码 0);无 review-round 文件 | 命令 + 完整输出 + 退出码 |
| TC-09 | A | fixture;`RAWF_REVIEW_IDLE_SECONDS=abc`(**异常:参数非法**) | `bash review.sh; echo $?` | 退出码 3;stderr 指出变量名与"正整数";未启动桩(无 events 文件) | 命令 + 完整输出 + 退出码 |
| TC-10 | A | fixture;桩 pass(plan 评审形态 JSON) | `bash plan-review.sh; echo $?` | 退出码 0;生成 `plan-review-round-01-pass.md`;`.plan-review-raw-01.events.jsonl` 存在;`.plan-review-lock` 存在且可立即获取 | 命令 + 完整输出 + 退出码 |
| TC-11 | A | fixture;桩 idle(**异常:plan 脚本看门狗**) | `bash plan-review.sh; echo $?` | 退出码 3;stderr 含"已终止";桩被杀;`.plan-review-lock` 存在且可立即获取;无 round 文件 | 命令 + 完整输出 + 退出码 |
| TC-12 | A | fixture 含 implementation-round-01.md、无 review 文件;另起进程 `flock .review-lock sleep 300 &` 持有当前任务的实现评审锁 | `echo '{}' \| bash gate-review.sh; echo $?` | 无 stdout 输出,退出码 0(放行) | 命令 + 完整输出 + 退出码 |
| TC-13 | A | 同上,无任何进程持锁(锁文件存在但空闲;再测锁文件不存在)(**原拦截回归**) | 同上,两次 | 两次均输出 `decision: block` JSON,reason 含"尚未经过 Codex 评审";退出码 0;锁文件不存在时 hook 不创建它 | 命令 + 完整输出 + 退出码 |
| TC-14 | A | 同上,无进程持 `.review-lock`;但 ① `flock .plan-review-lock sleep 300 &` 持有 plan 评审锁;② hook 输入 `background_tasks` 含 `{status:"running",command:"bash .ai-workflow/scripts/review.sh"}`;③ 另一任务目录的 `.review-lock` 被持有(**负例:plan 评审 / 命令字符串 / 其它任务均不放行**) | 分别运行三次 | 三次均输出 block JSON(放行只认当前任务目录的实现评审锁) | 命令 + 完整输出 + 退出码 |
| TC-15 | A | 真实 codex 可用 | 在 scratchpad 以真实 `codex exec --json --sandbox read-only --output-schema <简单 schema> --output-last-message out.json "..." </dev/null > events.jsonl` 跑一次微型任务 | 退出码 0;out.json 为符合 schema 的 JSON;events.jsonl 非空且首行 `thread.started`、末行 `turn.completed` | 命令 + 完整输出 + 退出码 |
| TC-17 | A | fixture;桩 `late`:每秒打 1 行事件,运行 7.5 s 后写 pass JSON 退出;`RAWF_REVIEW_MAX_SECONDS=8`、poll=1(**边界:最后一个轮询窗口内正常完成**) | `bash review.sh; echo $?` | 退出码 0,生成 pass 文件;stderr **不含**"墙钟上限"(醒来先查存活,不误判超时) | 命令 + 完整输出 + 退出码 |
| TC-18 | A | fixture;桩 idle;`bash review.sh &` 后**只**对脚本 pid `kill -KILL`,桩继续存活并持有继承的锁 fd;断言 `flock -n -E 75 .review-lock true` 退出 75;随后把锁文件**清空**(模拟元数据尚未写入/已丢失的最坏情形)(**异常:脚本被 KILL、codex 遗留持锁,且无元数据可依赖**) | 另起一个**只打开不持锁**的进程 `bash -c 'exec 8>>.review-lock; sleep 300' &`(记 opener.pid);再 `bash review.sh 2>err.txt; echo $?`;按 stderr 给出的命令终止列出的 pid;再 `bash review.sh`(桩 pass);`echo $?` | 第二次运行退出码 3;stderr 持有者名单**含**桩 pid 与命令名、含 `kill -TERM` 处置指引,**不含**第二次运行实例自身的 pid、不含 opener.pid、不含任何自动清理字样;桩与 opener 此时均仍存活;执行指引后(并 kill opener)第三次运行退出码 0 并生成 pass 文件 | 命令 + 完整输出 + 退出码 |
| TC-19 | A | fixture 含 implementation-round-01.md、无 review 文件;`.review-lock` 被预置为**目录**(旧协议残留);再测 `.review-lock` 为不可读文件(`chmod 000`)(**异常:hook 探测错误不放行**) | `echo '{}' \| bash gate-review.sh; echo $?`,两次 | 两次均输出 block JSON(非 75 退出码一律 fail-closed) | 命令 + 完整输出 + 退出码 |
| TC-20 | A | fixture;`.review-lock` 与 `.plan-review-lock` 均预置为**目录**(旧协议残留)(**异常:升级迁移**) | `bash review.sh; echo $?`;`bash plan-review.sh; echo $?` | 两者退出码 3,stderr 含"旧版锁目录"与 rmdir 指引;未启动桩(无 events 文件);目录原样保留 | 命令 + 完整输出 + 退出码 |
| TC-16 | A | 改动完成 | grep 文档与 skill:① 两个 SKILL 含"直接结束回合";**反向**:不再含"并等待完成"、"锁已存在"、"删除锁目录后重跑"(旧常规故障处理的删锁流程,三条反向 grep 退出码均为 1);**正向**:rawf-review SKILL 含升级迁移段(同时命中"旧版锁目录"、`pgrep -f 'codex exec'`、"rmdir");② README 机制速览含"看门狗";③ `docs/decisions/0009-review-watchdog-async.md` 存在且含「日期/背景/决定/影响」四段;④ CHANGELOG 含 `[Unreleased]`、「升级指引」与"旧版锁目录"迁移说明;⑤ .gitignore 含两条锁文件模式;⑥ review.sh hash_excludes 含 `.review-lock`;⑦ README 前置依赖含 flock、setsid、pgrep | 七项全部命中,反向项退出码为 1 | 命令 + 完整输出 + 退出码 |

## 风险与回滚

- **误杀正常评审**:静默 15 分钟对历史 1595 次正常评审只会误杀 1 次(该次为
  API 流断后反复重试,杀掉重跑更快);墙钟 60 分钟误杀 0 次。两者均可用
  环境变量放宽。`--json` 事件按 item 完成粒度输出,与统计所用 rollout 日志
  粒度相当;若实际使用中发现静默分布更稀,调默认值即可,不改结构。
- **Claude Code 后台时限**:默认 30 分钟会先于脚本墙钟杀掉外层 bash;skill
  要求启动时把 timeout 设高于 60 分钟。即便被外层杀掉,TERM trap 也会清理
  codex 与锁(TC-08)。
- **异步唤回依赖交互会话**:`claude -p` 无头模式在最终回复后约 5 秒杀后台
  shell,本机制不适用;决策文档明示。
- **平台依赖**:强制 util-linux(flock、setsid)与 procps(pgrep),Linux
  发行版默认具备;macOS 需 brew 补齐。缺失时脚本与 hook 均明确失败/退化,
  不静默。
- **SIGKILL 下的遗留 codex**:脚本被 KILL 时 trap 不执行,codex 继承 fd 9
  继续持锁;下次评审经 /proc 扫描精确列出持有者并给出 kill 命令,由用户
  决定是否终止,脚本不自动杀进程(TC-18)。代价是这一罕见路径需人工
  一步,换取不引入"按记录杀进程"的误杀面。
- **升级迁移**:旧版 mkdir 锁目录残留会让新脚本报"旧版锁目录"并给出
  一次性 rmdir 指引(TC-20),不静默覆盖。
- **回滚**:所有改动集中在 9 个文件,`git revert` 本任务提交即可;事件文件与
  锁目录模式对旧版本无副作用。

## 评审者独立核查清单(首轮 plan 评审专项)

用户要求首轮评审由 Codex **独立调查核实**以下事实,而非仅审方案文本。请逐条
核查并把与下列结论不符之处列为问题(影响方案正确性的按 major):

1. `codex exec --help` 中关于 stdin 的说明是否如上引述;assets/codex-json-probe-stderr.log
   是否显示 `</dev/null` 下仍尝试读 stdin;assets/stdin-hang-specimen.log 的
   现场(stdin 为 socket、主线程 unix_stream_data_wait、无 rollout)是否支持
   "阻塞于 stdin"的判断。
2. 运行 `python3 .ai/2026-10-03/review-watchdog-async/assets/codex-review-session-stats.py`
   (只读扫描 `~/.codex/sessions`),核对分位数与"未完成会话"形态是否与
   assets/codex-review-session-stats.txt 及本文「背景」一致。
3. 阅读现行 review.sh / plan-review.sh / gate-review.sh,确认:无 stdin 重定向、
   无超时、锁为空目录不记 pid、hook 不区分评审进行中。
4. 阅读 rawf-review / rawf-plan SKILL,确认"后台运行并等待完成"与 pgrep 删锁
   指引现存。
5. assets/codex-json-probe-events.jsonl 是否证明 `--json` 与 `--output-schema`、
   `--output-last-message` 可同用,事件以 `item.*` 粒度输出。
6. 对本方案的看门狗阈值(静默 900 s / 墙钟 3600 s)、会话+进程组终止方式、
   flock 锁语义(含 fd 继承)以及 Stop hook 放行条件,给出独立判断。

## 修订记录

- 第 1 轮 plan 评审(fail,R-01~R-04)后修订:锁协议从"mkdir + pid 自愈"
  改为 `flock`,取消一切回收逻辑(R-01);强制 setsid,受管集合按会话 +
  进程组双重扫并 KILL 升级,新增多层后代/忽略 TERM/并发/崩溃四类用例
  TC-05~TC-07(R-02);Stop hook 放行条件改为仅试探当前任务目录的实现评审
  flock 锁,新增三类负例 TC-14(R-03);TC-02 改为 fifo 独立生产者、只对
  review.sh 计时并加总超时(R-04)。
- 第 2 轮 plan 评审(fail,R-01~R-06)后修订:TC-01/03/04/10/11 的"锁已删"
  改为"锁常驻且可立即获取",TC-06 桩改为持续发事件(R-01);TC-05 桩改为
  显式构造"中间进程退出后孙进程改挂 init"与"exec 继承忽略 TERM",并在
  清理前断言场景成立(R-02);看门狗醒来先查存活再判超时,新增 TC-17
  (R-03);锁文件记 `script=`/`sid=` 两行,孤儿评审(脚本死、会话活)自动
  清理后重试,新增 TC-18(R-04);flock 用 `-E 75` 专用冲突码,脚本与 hook
  均精确匹配、其它错误 fail-closed,新增 TC-19(R-05);旧版锁目录识别为
  exit 3 + 一次性 rmdir 迁移指引,写入 CHANGELOG 与 SKILL,新增 TC-20
  (R-06)。
- 第 3 轮 plan 评审(fail,R-01~R-02)后修订,并按用户"不要偏移和无端扩张"
  的要求收回第 2 轮加入的自动清理:持有者定位改为扫描 /proc fd(不依赖
  锁文件元数据,R-01 的"sid 写入前被杀"窗口随之消失),锁被遗留进程持有时
  只报告持有者与处置命令、不自动 kill;锁文件只记 `script=` 一行;TC-18 改为
  验证"清空元数据后仍能定位 + 报告不自动清理 + 按指引处置后恢复"(R-01);
  TC-16 反向项限定为旧常规删锁流程原句,迁移段改为正向验证(R-02)。
- 第 4 轮 plan 评审(fail,R-01)后修订:持有者定位改为"关闭自身 fd 后,
  按 fdinfo 的 `lock:` FLOCK 行 + inode 判定",只列真正持锁的进程,排除
  报错实例与仅打开者;新增探针 assets/flock-fdinfo-probe.log 作依据;
  TC-18 增加反向断言(不含自身 pid、不含仅打开者)。
- 第 5 轮首次运行时 codex 本身在启动前阻塞于 stdin(socket)27 分钟,手动
  终止后以 `</dev/null` 重跑;现场记录入 assets/stdin-hang-specimen.log,
  背景第 1 条据此改写(原"Claude Code stdin 恒为 /dev/null"的判断被推翻)。
