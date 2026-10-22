#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj T; cd "$T"
env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-04 -- bash -c 'sleep 37.3' >/dev/null 2>&1 &
W=$!
sleep 1
kill -TERM "$W"
wait "$W"; rc=$?
f="$T/.ai/2026-10-22/t/evidence/TC-04.log"
assert_eq "包装器退出码" "$rc" "143"
c=$(cat "$f")
assert_contains "尾部" "$c" "--- end ---"; assert_contains "尾部" "$c" "exit: 143"; assert_contains "尾部" "$c" "bytes: 0"
sleep 0.5
alive=$(pgrep -x sleep -a | grep -F ' 37.3' || true)
assert_eq "子进程 sleep 不再存活" "$alive" ""
echo "--- 文件全文:"; cat "$f"

# (b) 子进程忽略 TERM:5 s 宽限后 KILL 整组,仍写尾部,退出码固定 143
start=$SECONDS
env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-04 -l ignore -- bash -c 'trap "" TERM; sleep 41.3' >/dev/null 2>&1 &
W=$!; sleep 1; kill -TERM "$W"; wait "$W"; rc=$?
el=$((SECONDS - start))
assert_eq "忽略 TERM:包装器退出码" "$rc" "143"
assert_contains "忽略 TERM:尾部" "$(cat "$T/.ai/2026-10-22/t/evidence/TC-04-ignore.log")" "exit: 143"
if [ "$el" -ge 4 ] && [ "$el" -le 12 ]; then ok "忽略 TERM:在宽限后收尾(${el}s)"; else bad "忽略 TERM:耗时异常 ${el}s"; fi
sleep 0.5
assert_eq "忽略 TERM:sleep 41.3 不再存活" "$(pgrep -x sleep -a | grep -F ' 41.3' || true)" ""

# (c) INT:退出码固定 130。无作业控制时 & 启动的后台进程按 POSIX 忽略 INT 且
#     无法 trap,故开 set -m,使被测脚本以未忽略 INT 的状态启动(与前台运行一致)
set -m
env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-04 -l int -- bash -c 'sleep 43.3' >/dev/null 2>&1 &
W=$!; set +m; sleep 1; kill -INT "$W"; wait "$W"; rc=$?
assert_eq "INT:包装器退出码" "$rc" "130"
assert_contains "INT:尾部" "$(cat "$T/.ai/2026-10-22/t/evidence/TC-04-int.log")" "exit: 130"
sleep 0.5
assert_eq "INT:sleep 43.3 不再存活" "$(pgrep -x sleep -a | grep -F ' 43.3' || true)" ""

# (d) 子进程捕获 TERM 后正常 exit 0:取消不得记为成功,仍 143
env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-04 -l trap0 -- bash -c 'trap "exit 0" TERM; sleep 45.3 & wait' >/dev/null 2>&1 &
W=$!; sleep 1; kill -TERM "$W"; wait "$W"; rc=$?
assert_eq "捕获 TERM 后 exit 0:包装器退出码" "$rc" "143"
assert_contains "捕获 TERM 后 exit 0:尾部" "$(cat "$T/.ai/2026-10-22/t/evidence/TC-04-trap0.log")" "exit: 143"
sleep 0.5
assert_eq "捕获 TERM:sleep 45.3 不再存活" "$(pgrep -x sleep -a | grep -F ' 45.3' || true)" ""

# (e) 整组 INT(模拟终端 Ctrl-C:INT 同时打到留证器、tee 与计时器):tee 须存活并
#     收录子进程收到 INT 后的收尾输出;退出码 130;耗时远小于 5 s 宽限(子进程自行退出)
set -m
# 子进程用前台短 sleep 循环:后台 sleep 在无作业控制的 bash 里按 POSIX 忽略 INT,会让整组
# 拖满 5 s 宽限(那是留证器的正确行为,但不是本场景要测的"子进程自行收尾即结束")
env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-04 -l pgint -- bash -c 'trap "echo bye-after-int; exit 0" INT; while :; do sleep 0.473; done' >/dev/null 2>&1 &
W=$!; set +m; sleep 1
start=$SECONDS; kill -INT -- "-$W"; wait "$W"; rc=$?; el=$((SECONDS - start))
f5="$T/.ai/2026-10-22/t/evidence/TC-04-pgint.log"
assert_eq "整组 INT:包装器退出码" "$rc" "130"
body5=$(awk '/^--- output ---$/{f=1;next} /^--- end ---$/{f=0} f' "$f5")
assert_eq "整组 INT:正文恰为子进程收尾输出" "$(grep -v '^$' <<<"$body5")" "bye-after-int"
assert_contains "整组 INT:尾部" "$(cat "$f5")" "exit: 130"
if [ "$el" -le 3 ]; then ok "整组 INT:子进程自行退出后即收尾(${el}s)"; else bad "整组 INT:耗时异常 ${el}s"; fi
sleep 0.5
assert_eq "整组 INT:sleep 0.473 不再存活" "$(pgrep -x sleep -a | grep -F ' 0.473' || true)" ""

# (f) 不留孤儿:各中断场景结束后,不应残留任何被包命令的 sleep。只按本用例独有的
#     时长匹配——系统里其它会话的 sleep(如别处遗留的轮询循环)不归本用例判定
assert_eq "无残留 sleep(37.3/41.3/43.3/45.3/0.473)" "$(pgrep -x sleep -a | grep -E ' (37\.3|41\.3|43\.3|45\.3|0\.473)$' || true)" ""
# (g) 组长 = 新会话首进程:子进程 pid、pgid、sid 三者相等(setsid 未分叉)
env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-04 -l sid -- bash -c 'ps -o pid=,pgid=,sid= -p $$' >/dev/null 2>&1
read -r p1 p2 p3 < <(awk '/^--- output ---$/{f=1;next} f && NF==3 {print; exit}' "$T/.ai/2026-10-22/t/evidence/TC-04-sid.log")
if [ -n "$p1" ] && [ "$p1" = "$p2" ] && [ "$p2" = "$p3" ]; then ok "被包命令 pid=pgid=sid($p1)"; else bad "被包命令 pid/pgid/sid 不一致:$p1 $p2 $p3"; fi

# ---- 启动时序(第 03 轮,评审 R-01):用 PATH 前置的假命令制造可确定的时间窗,
#      不在生产脚本里加测试钩子 ----
ms() { date +%s%3N; }
FAKE=$(mktemp -d /tmp/rawf-fake.XXXXXX)
REAL_SETSID=$(command -v setsid); REAL_GIT=$(command -v git)
printf '#!/usr/bin/env bash\nsleep 2\nexec %q "$@"\n' "$REAL_SETSID" > "$FAKE/setsid"
chmod +x "$FAKE/setsid"

# (h) 进程组尚未建立(假 setsid 前 2 s)时收到 TERM,子进程忽略 TERM:转发逐拍重试,
#     宽限到点 KILL,收尾有界,退出码 143
t0=$(ms)
env PATH="$FAKE:$PATH" CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-04 -l pregroup -- bash -c 'trap "" TERM; sleep 51.3' >/dev/null 2>&1 &
W=$!; sleep 0.5; kill -TERM "$W"; wait "$W"; rc=$?; el=$(( $(ms) - t0 ))
assert_eq "组未建立时中断:包装器退出码" "$rc" "143"
assert_contains "组未建立时中断:尾部" "$(cat "$T/.ai/2026-10-22/t/evidence/TC-04-pregroup.log")" "exit: 143"
if [ "$el" -ge 4000 ] && [ "$el" -le 12000 ]; then ok "组未建立时中断:宽限后有界收尾(${el}ms)"; else bad "组未建立时中断:耗时异常 ${el}ms"; fi
sleep 0.5
assert_eq "组未建立时中断:sleep 51.3 不再存活" "$(pgrep -x sleep -a | grep -F ' 51.3' || true)" ""

# (h2) 同一时间窗,子进程响应 TERM:第一次转发(组未建立)失败,组建立后重试成功,
#      子进程收尾输出被收录;耗时介于 1.5 s(组建立前未被误杀)与 4.5 s(未拖到宽限)之间
t0=$(ms)
env PATH="$FAKE:$PATH" CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-04 -l retry -- bash -c 'trap "echo got-term; exit 0" TERM; while :; do sleep 0.531; done' >/dev/null 2>&1 &
W=$!; sleep 0.5; kill -TERM "$W"; wait "$W"; rc=$?; el=$(( $(ms) - t0 ))
f8="$T/.ai/2026-10-22/t/evidence/TC-04-retry.log"
assert_eq "转发重试:包装器退出码" "$rc" "143"
# 正文可能另含子 bash 对被 TERM 杀掉的前台 sleep 的报告(如"已终止"/"Terminated"),属真实输出
assert_contains "转发重试:正文含子进程收尾输出" "$(awk '/^--- output ---$/{f=1;next} /^--- end ---$/{f=0} f' "$f8")" "got-term"
if [ "$el" -ge 1500 ] && [ "$el" -le 4500 ]; then ok "转发重试:组建立后即送达(${el}ms)"; else bad "转发重试:耗时异常 ${el}ms"; fi

# (i) 被包命令启动前(写头部阶段,假 git 每次调用慢 1.5 s)收到 TERM:不再启动被包命令,
#     正文为空,尾部完整,退出码 143
printf '#!/usr/bin/env bash\nsleep 1.5\nexec %q "$@"\n' "$REAL_GIT" > "$FAKE/git"; chmod +x "$FAKE/git"
MARK="$FAKE/should-not-exist"
t0=$(ms)
env PATH="$FAKE:$PATH" CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-04 -l prelaunch -- touch "$MARK" >/dev/null 2>&1 &
W=$!; sleep 0.5; kill -TERM "$W"; wait "$W"; rc=$?; el=$(( $(ms) - t0 ))
f9="$T/.ai/2026-10-22/t/evidence/TC-04-prelaunch.log"
assert_eq "启动前中断:包装器退出码" "$rc" "143"
assert_nofile "$MARK"
assert_contains "启动前中断:尾部" "$(cat "$f9")" "exit: 143"
assert_contains "启动前中断:正文为空" "$(cat "$f9")" "bytes: 0"
if [ "$el" -le 6000 ]; then ok "启动前中断:写完头部即收尾(${el}ms)"; else bad "启动前中断:耗时异常 ${el}ms"; fi

# 三个时序场景的证据文件均须通过 evidence-check 的结构核验
good_plan "$T"
printf '## 测试结果\n| 编号 | 档位 | 结果 | 证据 |\n|---|---|---|---|\n| TC-01 | A | pass | TC-04-pregroup.log TC-04-retry.log TC-04-prelaunch.log |\n| TC-02 | A | pass | TC-04-int.log TC-04-pgint.log TC-04-ignore.log TC-04-trap0.log |\n| TC-03 | B | pass | a:1 |\n| TC-04 | C | pass | 看 |\n' > "$T/.ai/2026-10-22/t/implementation-round-01.md"
out=$(env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence-check.sh" 2>&1); rc=$?
assert_eq "各中断场景证据结构核验" "$rc" "0"
[ "$rc" -eq 0 ] || echo "$out"
assert_eq "无残留 sleep(51.3/0.531)" "$(pgrep -x sleep -a | grep -E ' (51\.3|0\.531)$' || true)" ""
rm -rf "$FAKE"
echo "--- 各中断场景文件尾部:"; for x in "$T"/.ai/2026-10-22/t/evidence/TC-04-*.log; do echo "[$(basename "$x")]"; tail -n 4 "$x"; done
finish
