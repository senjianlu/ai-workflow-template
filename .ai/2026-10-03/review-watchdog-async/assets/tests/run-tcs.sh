#!/usr/bin/env bash
# 执行 plan.md 的 TC-01~TC-20,证据逐条写 evidence/TC-NN.log(命令 + 完整输出 + 退出码 + 断言)。
# 用法:bash run-tcs.sh [TC 编号列表,如 01 03];默认全部。
set -uo pipefail
PROJ=$(cd "$(dirname "$0")/../../../../.." && pwd)
TESTS=$(cd "$(dirname "$0")" && pwd)
TASK=$(cd "$TESTS/../.." && pwd)
EVID="$TASK/evidence"
WORK=${RAWF_TEST_WORK:-/tmp/claude-1000/-home-rabbir-Projects-ai-workflow-template/33fe3994-31b4-4cb4-8c42-3f5146862277/scratchpad/tc-work}
mkdir -p "$WORK" "$EVID"
export PATH="$TESTS/stub-codex-bin:$PATH"
export RAWF_REVIEW_IDLE_SECONDS=3 RAWF_REVIEW_MAX_SECONDS=8 RAWF_REVIEW_POLL_SECONDS=1

LOG=; FAILS=0
log() { printf '%s\n' "$*" >> "$LOG"; }
run() {  # run <desc> <cmd...>:记录命令、完整 stdout+stderr、退出码;返回退出码,输出存 $OUT
  log "\$ $*"; OUT=$("$@" 2>&1); RC=$?; log "$OUT"; log "[exit=$RC]"; return $RC
}
sh_run() { log "\$ $1"; OUT=$(bash -c "$1" 2>&1); RC=$?; log "$OUT"; log "[exit=$RC]"; return $RC; }
check() {  # check <desc> <cond-exit-code>
  if [ "$2" -eq 0 ]; then log "[OK] $1"; else log "[FAIL] $1"; TCFAIL=1; fi
}
begin() { LOG="$EVID/TC-$1.log"; : > "$LOG"; TCFAIL=0; log "# TC-$1 $2"; log "# $(date '+%F %T') PROJ=$PROJ"; log "# env: IDLE=$RAWF_REVIEW_IDLE_SECONDS MAX=$RAWF_REVIEW_MAX_SECONDS POLL=$RAWF_REVIEW_POLL_SECONDS"; }
end() { if [ "$TCFAIL" = 0 ]; then log "TC-$1 RESULT: PASS"; echo "TC-$1 PASS"; else log "TC-$1 RESULT: FAIL"; echo "TC-$1 FAIL"; FAILS=$((FAILS+1)); fi; }

make_fixture() {  # 建临时 git 仓库 + 任务目录 + 当前任务;stdout 回传路径
  local fx="$WORK/fx-$1"; rm -rf "$fx"; mkdir -p "$fx"
  ( cd "$fx" && git init -q && git config user.email t@t && git config user.name t \
    && mkdir -p src .ai/2026-10-04/t/evidence .ai/2026-10-04/t/assets && echo 'print(1)' > src/app.py \
    && cp -r "$PROJ/.ai-workflow" . && mkdir -p .claude && cp -r "$PROJ/.claude/hooks" .claude/ && cp "$PROJ/.gitignore" . \
    && git add -A && git commit -qm init \
    && echo '.ai/2026-10-04/t' > .ai/.current-task \
    && printf -- '---\nstatus: approved\ntask: t\n---\n# plan\n' > .ai/2026-10-04/t/plan.md \
    && echo '# r1' > .ai/2026-10-04/t/implementation-round-01.md ) >/dev/null
  echo "$fx"
}
TD() { echo "$1/.ai/2026-10-04/t"; }
stub_pid() { pgrep -f 'stub-codex-bin/codex' | head -1; }
wait_file() { local i; for i in $(seq 1 100); do [ -e "$1" ] && return 0; sleep 0.1; done; return 1; }
lock_free() { flock -n -E 75 "$1" true; }   # 0=可获取 75=被持有
# bg_review <fx> <mode> <outfile>:后台启动评审脚本并记录命令;pid 存 $BG
bg_review() { log "\$ CLAUDE_PROJECT_DIR=$1 STUB_MODE=$2 bash $1/.ai-workflow/scripts/review.sh > $3 2>&1 &"; CLAUDE_PROJECT_DIR=$1 STUB_MODE=$2 bash "$1/.ai-workflow/scripts/review.sh" > "$3" 2>&1 & BG=$!; log "[bg pid=$BG]"; }
# sig <SIG> <pid...>:发信号并记录
sig() { log "\$ kill -$*"; kill "-$@" 2>&1 | tee -a "$LOG"; log "[exit=${PIPESTATUS[0]}]"; }
# wait_bg <pid> <outfile> <label>:等待后台评审并记录完整输出与退出码;结果存 RC/OUT
wait_bg() { log "\$ wait $1   # $3"; wait "$1"; RC=$?; OUT=$(cat "$2"); log "$OUT"; log "[exit=$RC]"; }

tc01() { begin 01 "正常 pass"; local fx; fx=$(make_fixture 01); local td; td=$(TD "$fx")
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=pass run bash "$fx/.ai-workflow/scripts/review.sh"; check "退出码 0" $([ $RC -eq 0 ]; echo $?)
  check "生成 review-round-01-pass.md" $([ -f "$td/review-round-01-pass.md" ]; echo $?)
  sh_run "wc -l < '$td/.review-raw-01.events.jsonl'"; check "事件文件 3 行" $([ "$OUT" = 3 ]; echo $?)
  sh_run "cat '$td/.review-lock'"; check "锁文件内容为 script=<pid> 一行" $([[ "$OUT" =~ ^script=[0-9]+$ ]]; echo $?)
  run lock_free "$td/.review-lock"; check "锁可立即获取" $([ $RC -eq 0 ]; echo $?); end 01; }

tc02() { begin 02 "stdin 为永不关闭的 fifo"; local fx; fx=$(make_fixture 02); local td; td=$(TD "$fx")
  mkfifo "$fx/p"; sleep 300 > "$fx/p" & local prod=$!; log "producer pid=$prod (sleep 300 > p)"
  local t0=$SECONDS; CLAUDE_PROJECT_DIR=$fx STUB_MODE=stdin sh_run "timeout 60 bash '$fx/.ai-workflow/scripts/review.sh' < '$fx/p'"; local el=$((SECONDS-t0))
  log "elapsed=${el}s"; check "退出码 0 且 60 s 内返回" $([ $RC -eq 0 ] && [ $el -lt 60 ]; echo $?)
  check "生成 pass 文件" $([ -f "$td/review-round-01-pass.md" ]; echo $?)
  run kill -0 $prod; check "断言时生产者仍存活(管道确未关闭)" $([ $RC -eq 0 ]; echo $?)
  kill $prod 2>/dev/null; wait $prod 2>/dev/null; end 02; }

tc03() { begin 03 "静默卡死看门狗"; local fx; fx=$(make_fixture 03); local td; td=$(TD "$fx")
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=idle run bash "$fx/.ai-workflow/scripts/review.sh"; check "退出码 3" $([ $RC -eq 3 ]; echo $?)
  check "stderr 含 无新事件 与 已终止" $([[ "$OUT" == *无新事件* && "$OUT" == *已终止* ]]; echo $?)
  check "无 review-round 文件" $(! ls "$td"/review-round-* >/dev/null 2>&1; echo $?)
  sh_run "pgrep -f 'stub-codex-bin/code[x]' || echo none"; check "桩已被杀" $([ "$OUT" = none ]; echo $?)
  run lock_free "$td/.review-lock"; check "锁可立即获取" $([ $RC -eq 0 ]; echo $?); end 03; }

tc04() { begin 04 "墙钟兜底"; local fx; fx=$(make_fixture 04); local td; td=$(TD "$fx")
  local t0=$SECONDS; CLAUDE_PROJECT_DIR=$fx STUB_MODE=chatty run bash "$fx/.ai-workflow/scripts/review.sh"; local el=$((SECONDS-t0)); log "elapsed=${el}s"
  check "退出码 3" $([ $RC -eq 3 ]; echo $?); check "stderr 含 墙钟上限" $([[ "$OUT" == *墙钟上限* ]]; echo $?)
  sh_run "pgrep -f 'stub-codex-bin/code[x]' || echo none"; check "桩已被杀" $([ "$OUT" = none ]; echo $?)
  run lock_free "$td/.review-lock"; check "锁存在且可立即获取" $([ $RC -eq 0 ] && [ -f "$td/.review-lock" ]; echo $?)
  check "总耗时 < 20 s" $([ $el -lt 20 ]; echo $?); end 04; }

tc05() { begin 05 "多层后代 + 忽略 TERM 的清理"; local fx; fx=$(make_fixture 05); local td; td=$(TD "$fx"); export STUB_DIR="$fx"
  bg_review "$fx" tree "$fx/out.txt"; local sp=$BG
  wait_file "$td/.review-raw-01.events.jsonl"; sleep 1
  local gc ig sid; gc=$(cat "$fx/grandchild.pid"); ig=$(cat "$fx/ignorer.pid"); sid=$(cat "$fx/stub.sid"); log "grandchild=$gc ignorer=$ig stub.sid=$sid"
  sh_run "pgrep -f 'sleep 30[0] & echo' || echo none"; check "前置:中间 bash 已退出" $([ "$OUT" = none ]; echo $?)
  run kill -0 $gc; check "前置:孙进程存活" $([ $RC -eq 0 ]; echo $?); run kill -0 $ig; check "前置:忽略 TERM 的进程存活" $([ $RC -eq 0 ]; echo $?)
  sh_run "ps -o sid= -p $gc | tr -d ' '; ps -o sid= -p $ig | tr -d ' '"; check "前置:二者 sid 等于 stub.sid" $([ "$OUT" = "$sid"$'\n'"$sid" ]; echo $?)
  sh_run "ps -o ppid= -p $gc | tr -d ' '"; log "孙进程当前 ppid=$OUT(已改挂)"
  wait_bg $sp "$fx/out.txt" "review.sh(tree)"; check "退出码 3" $([ $RC -eq 3 ]; echo $?)
  sh_run "pgrep -s $sid || echo none"; check "受管会话无存活进程" $([ "$OUT" = none ]; echo $?)
  run kill -0 $gc; check "孙进程已不存在" $([ $RC -ne 0 ]; echo $?); run kill -0 $ig; check "忽略 TERM 的进程已被 KILL" $([ $RC -ne 0 ]; echo $?)
  check "无 review-round 文件" $(! ls "$td"/review-round-* >/dev/null 2>&1; echo $?); unset STUB_DIR; end 05; }

tc06() { begin 06 "并发第二实例(确定性交错)"; local fx; fx=$(make_fixture 06); local td; td=$(TD "$fx")
  bg_review "$fx" slow "$fx/a.txt"; local A=$BG; log "A script pid=$A"
  local i; for i in $(seq 1 100); do lock_free "$td/.review-lock" 2>/dev/null; [ $? -eq 75 ] && break; sleep 0.2; done; log "锁已被 A 持有(flock 探测返回 75)"
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=pass run bash "$fx/.ai-workflow/scripts/review.sh"; local brc=$RC; local bout=$OUT
  check "B 退出码 3" $([ $brc -eq 3 ]; echo $?); check "B stderr 含 进行中 与 A 的脚本 pid" $([[ "$bout" == *进行中* && "$bout" == *"$A bash"* ]]; echo $?)
  check "B stderr 为正常并发文案:不含 遗留 / kill -TERM" $([[ "$bout" != *遗留* && "$bout" != *"kill -TERM"* ]]; echo $?)
  wait_bg $A "$fx/a.txt" "A(slow)"; check "A 退出码 0" $([ $RC -eq 0 ]; echo $?)
  sh_run "ls '$td'/review-round-*"; check "唯一的 review-round-01-pass.md" $([ "$OUT" = "$td/review-round-01-pass.md" ]; echo $?)
  sh_run "ls '$td'/.review-raw-*"; check "只有 A 的 raw 与 events 两个文件" $([ "$(echo "$OUT" | wc -l)" = 2 ]; echo $?); end 06; }

tc07() { begin 07 "崩溃(KILL 脚本与桩会话)后无残留锁"; local fx; fx=$(make_fixture 07); local td; td=$(TD "$fx")
  bg_review "$fx" idle "$fx/a.txt"; local sp=$BG
  wait_file "$td/.review-raw-01.events.jsonl"; local st; st=$(stub_pid); log "script=$sp stub=$st"
  sig KILL $sp; sig KILL -- -$st; sleep 0.5; wait_bg $sp "$fx/a.txt" "首次评审(被 KILL)"
  sh_run "pgrep -s $st || echo none"; check "前置:桩会话全部死亡" $([ "$OUT" = none ]; echo $?)
  rm -f "$td/.review-raw-01.events.jsonl"
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=pass run bash "$fx/.ai-workflow/scripts/review.sh"; check "第二次运行退出码 0" $([ $RC -eq 0 ]; echo $?)
  check "不出现 进行中 / 回收 提示" $([[ "$OUT" != *进行中* && "$OUT" != *回收* ]]; echo $?)
  check "生成 pass 文件" $([ -f "$td/review-round-01-pass.md" ]; echo $?); end 07; }

tc08() { begin 08 "外部 TERM 终止脚本"; local fx; fx=$(make_fixture 08); local td; td=$(TD "$fx")
  bg_review "$fx" idle "$fx/a.txt"; local sp=$BG
  sleep 2; local st; st=$(stub_pid); log "script=$sp stub=$st"; sig TERM $sp; wait_bg $sp "$fx/a.txt" "review.sh(被 TERM)"
  check "退出码非 0" $([ $RC -ne 0 ]; echo $?)
  sh_run "pgrep -s $st || echo none"; check "桩会话无存活进程" $([ "$OUT" = none ]; echo $?)
  run lock_free "$td/.review-lock"; check "锁可立即获取" $([ $RC -eq 0 ]; echo $?)
  check "无 review-round 文件" $(! ls "$td"/review-round-* >/dev/null 2>&1; echo $?); end 08; }

tc09() { begin 09 "参数非法"; local fx; fx=$(make_fixture 09); local td; td=$(TD "$fx")
  CLAUDE_PROJECT_DIR=$fx RAWF_REVIEW_IDLE_SECONDS=abc STUB_MODE=pass run bash "$fx/.ai-workflow/scripts/review.sh"
  check "退出码 3" $([ $RC -eq 3 ]; echo $?); check "stderr 指出变量名与 正整数" $([[ "$OUT" == *RAWF_REVIEW_IDLE_SECONDS* && "$OUT" == *正整数* ]]; echo $?)
  check "未启动桩(无 events 文件)" $([ ! -e "$td/.review-raw-01.events.jsonl" ]; echo $?); end 09; }

tc10() { begin 10 "plan-review 正常 pass"; local fx; fx=$(make_fixture 10); local td; td=$(TD "$fx")
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=pass run bash "$fx/.ai-workflow/scripts/plan-review.sh"; check "退出码 0" $([ $RC -eq 0 ]; echo $?)
  check "生成 plan-review-round-01-pass.md" $([ -f "$td/plan-review-round-01-pass.md" ]; echo $?)
  check "events 文件存在" $([ -f "$td/.plan-review-raw-01.events.jsonl" ]; echo $?)
  run lock_free "$td/.plan-review-lock"; check ".plan-review-lock 存在且可立即获取" $([ $RC -eq 0 ] && [ -f "$td/.plan-review-lock" ]; echo $?); end 10; }

tc11() { begin 11 "plan-review 静默看门狗"; local fx; fx=$(make_fixture 11); local td; td=$(TD "$fx")
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=idle run bash "$fx/.ai-workflow/scripts/plan-review.sh"; check "退出码 3" $([ $RC -eq 3 ]; echo $?)
  check "stderr 含 已终止" $([[ "$OUT" == *已终止* ]]; echo $?)
  sh_run "pgrep -f 'stub-codex-bin/code[x]' || echo none"; check "桩已被杀" $([ "$OUT" = none ]; echo $?)
  run lock_free "$td/.plan-review-lock"; check "锁存在且可立即获取" $([ $RC -eq 0 ] && [ -f "$td/.plan-review-lock" ]; echo $?)
  check "无 round 文件" $(! ls "$td"/plan-review-round-* >/dev/null 2>&1; echo $?); end 11; }

hook() { CLAUDE_PROJECT_DIR=$1 sh_run "echo '$2' | bash '$1/.claude/hooks/gate-review.sh'"; }
tc12() { begin 12 "hook:评审进行中放行"; local fx; fx=$(make_fixture 12); local td; td=$(TD "$fx")
  flock "$td/.review-lock" sleep 300 & local h=$!; sleep 0.3; log "holder pid=$h"
  hook "$fx" '{}'; check "无 stdout 输出且退出码 0" $([ -z "$OUT" ] && [ $RC -eq 0 ]; echo $?); kill $h 2>/dev/null; wait $h 2>/dev/null; end 12; }

tc13() { begin 13 "hook:原拦截回归"; local fx; fx=$(make_fixture 13); local td; td=$(TD "$fx")
  : > "$td/.review-lock"; hook "$fx" '{}'; check "锁空闲:输出 block JSON" $([[ "$OUT" == *'"block"'* && "$OUT" == *尚未经过* ]] && [ $RC -eq 0 ]; echo $?)
  rm -f "$td/.review-lock"; hook "$fx" '{}'; check "锁不存在:输出 block JSON" $([[ "$OUT" == *'"block"'* ]] && [ $RC -eq 0 ]; echo $?)
  check "hook 未创建锁文件" $([ ! -e "$td/.review-lock" ]; echo $?); end 13; }

tc14() { begin 14 "hook:三类负例不放行"; local fx; fx=$(make_fixture 14); local td; td=$(TD "$fx"); : > "$td/.review-lock"
  flock "$td/.plan-review-lock" sleep 300 & local h1=$!; sleep 0.3
  hook "$fx" '{}'; check "① plan 评审锁被持有:仍 block" $([[ "$OUT" == *'"block"'* ]]; echo $?); kill $h1; wait $h1 2>/dev/null
  hook "$fx" '{"background_tasks":[{"status":"running","command":"bash .ai-workflow/scripts/review.sh"}]}'; check "② 命令字符串匹配:仍 block" $([[ "$OUT" == *'"block"'* ]]; echo $?)
  mkdir -p "$fx/.ai/2026-10-04/other"; flock "$fx/.ai/2026-10-04/other/.review-lock" sleep 300 & local h2=$!; sleep 0.3
  hook "$fx" '{}'; check "③ 其它任务的锁被持有:仍 block" $([[ "$OUT" == *'"block"'* ]]; echo $?); kill $h2; wait $h2 2>/dev/null; end 14; }

tc15() { begin 15 "真实 codex:--json + --output-schema + --output-last-message"; local d="$WORK/real"; rm -rf "$d"; mkdir -p "$d"
  printf '{"type":"object","properties":{"answer":{"type":"string"}},"required":["answer"],"additionalProperties":false}\n' > "$d/schema.json"
  ( PATH=${PATH#"$TESTS/stub-codex-bin:"}; cd "$d" && sh_run "codex exec --json --sandbox read-only -C '$d' --skip-git-repo-check --output-schema '$d/schema.json' --output-last-message '$d/out.json' 'Answer with the JSON object {\"answer\": \"ok\"} and nothing else.' </dev/null > '$d/events.jsonl'"; echo $RC > "$d/rc" ); RC=$(cat "$d/rc")
  check "退出码 0" $([ "$RC" -eq 0 ]; echo $?)
  sh_run "cat '$d/out.json'"; check "out.json 符合 schema" $(jq -e 'type=="object" and (.answer|type=="string") and (keys==["answer"])' "$d/out.json" >/dev/null 2>&1; echo $?)
  sh_run "cat '$d/events.jsonl'"; check "events 首行 thread.started、末行 turn.completed" $([[ "$(head -1 "$d/events.jsonl")" == *thread.started* && "$(tail -1 "$d/events.jsonl")" == *turn.completed* ]]; echo $?); end 15; }

tc16() { begin 16 "文档与 skill 正反向 grep"; cd "$PROJ"
  sh_run "grep -c '直接结束回合' .claude/skills/rawf-review/SKILL.md .claude/skills/rawf-plan/SKILL.md"; check "① 两个 SKILL 含 直接结束回合" $([[ "$OUT" != *":0"* ]]; echo $?)
  local p; for p in '并等待完成' '锁已存在' '删除锁目录后重跑'; do sh_run "grep -n '$p' .claude/skills/rawf-review/SKILL.md .claude/skills/rawf-plan/SKILL.md"; check "① 反向:不含 $p(退出码 1)" $([ $RC -eq 1 ]; echo $?); done
  sh_run "grep -c -e '旧版锁目录' -e \"pgrep -f 'codex exec'\" -e rmdir .claude/skills/rawf-review/SKILL.md"; check "① 正向:rawf-review 含迁移段三要素" $(grep -q '旧版锁目录' .claude/skills/rawf-review/SKILL.md && grep -q "pgrep -f 'codex exec'" .claude/skills/rawf-review/SKILL.md && grep -q rmdir .claude/skills/rawf-review/SKILL.md; echo $?)
  sh_run "grep -n '看门狗' README.md"; check "② README 机制速览含 看门狗" $([ $RC -eq 0 ]; echo $?)
  sh_run "grep -n -e '^- 日期' -e '^- 背景' -e '^- 决定' -e '^- 影响' docs/decisions/0009-review-watchdog-async.md"; check "③ 0009 存在且含四段" $([ "$(echo "$OUT" | wc -l)" = 4 ]; echo $?)
  sh_run "grep -n -e '\[Unreleased\]' -e '升级指引' -e '旧版锁目录' CHANGELOG.md"; check "④ CHANGELOG 三项" $(grep -q '\[Unreleased\]' CHANGELOG.md && grep -q '升级指引' CHANGELOG.md && grep -q '旧版锁目录' CHANGELOG.md; echo $?)
  sh_run "grep -n -e '^.ai/\*\*/.review-lock$' -e '^.ai/\*\*/.plan-review-lock$' .gitignore"; check "⑤ .gitignore 两条锁文件模式" $([ "$(echo "$OUT" | wc -l)" = 2 ]; echo $?)
  sh_run "grep -n \"exclude='.review-lock'\" .ai-workflow/scripts/review.sh"; check "⑥ hash_excludes 含 .review-lock" $([ $RC -eq 0 ]; echo $?)
  sh_run "grep -n -e flock -e setsid -e pgrep README.md"; check "⑦ README 前置依赖含 flock/setsid/pgrep" $(grep -q 'flock' README.md && grep -q setsid README.md && grep -q pgrep README.md; echo $?); end 16; }

tc17() { begin 17 "最后一个轮询窗口内正常完成"; local fx; fx=$(make_fixture 17); local td; td=$(TD "$fx")
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=late run bash "$fx/.ai-workflow/scripts/review.sh"; check "退出码 0" $([ $RC -eq 0 ]; echo $?)
  check "生成 pass 文件" $([ -f "$td/review-round-01-pass.md" ]; echo $?); check "stderr 不含 墙钟上限" $([[ "$OUT" != *墙钟上限* ]]; echo $?); end 17; }

tc18() { begin 18 "脚本被 KILL、桩遗留持锁、无元数据"; local fx; fx=$(make_fixture 18); local td; td=$(TD "$fx")
  bg_review "$fx" idle "$fx/a.txt"; local sp=$BG
  wait_file "$td/.review-raw-01.events.jsonl"; local st; st=$(stub_pid); log "script=$sp stub=$st"; sig KILL $sp; wait_bg $sp "$fx/a.txt" "首次评审(脚本被 KILL)"; sleep 0.3
  run kill -0 $st; check "前置:桩仍存活" $([ $RC -eq 0 ]; echo $?); run lock_free "$td/.review-lock"; check "前置:锁被持有(75)" $([ $RC -eq 75 ]; echo $?)
  : > "$td/.review-lock"; log "锁文件已清空"
  log "\$ bash -c \"exec 8>>'$td/.review-lock'; sleep 300\" &"; bash -c "exec 8>>'$td/.review-lock'; sleep 300" & local op=$!; sleep 0.3; log "opener pid=$op"
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=pass bash "$fx/.ai-workflow/scripts/review.sh" > "$fx/b.txt" 2>&1 & local B=$!; wait $B; RC=$?; OUT=$(cat "$fx/b.txt"); log "\$ bash review.sh (B pid=$B)"; log "$OUT"; log "[exit=$RC]"
  check "B 退出码 3" $([ $RC -eq 3 ]; echo $?)
  check "名单含桩 pid 与命令名(桩为 bash 脚本,comm=bash)、含 kill -TERM 指引" $([[ "$OUT" == *"$st bash"* && "$OUT" == *"kill -TERM"* ]]; echo $?)
  check "名单不含 B 自身 pid、不含 opener pid、不含自动清理字样" $([[ "$OUT" != *"$B "* && "$OUT" != *"$op "* && "$OUT" != *自动清理* && "$OUT" != *已清理* ]]; echo $?)
  run kill -0 $st; check "桩此时仍存活" $([ $RC -eq 0 ]; echo $?)
  run kill -0 $op; check "opener 此时仍存活" $([ $RC -eq 0 ]; echo $?)
  local cmd; cmd=$(grep -ao 'kill -TERM [0-9 ]*' "$fx/b.txt" | head -1); sh_run "$cmd"; sig TERM $op; wait $op 2>/dev/null; sleep 1
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=pass run bash "$fx/.ai-workflow/scripts/review.sh"; check "按指引处置后第三次运行退出码 0" $([ $RC -eq 0 ]; echo $?)
  check "生成 pass 文件" $([ -f "$td/review-round-01-pass.md" ]; echo $?); end 18; }

tc19() { begin 19 "hook:探测错误不放行"; local fx; fx=$(make_fixture 19); local td; td=$(TD "$fx")
  mkdir "$td/.review-lock"; hook "$fx" '{}'; check "锁为目录:block" $([[ "$OUT" == *'"block"'* ]]; echo $?); rmdir "$td/.review-lock"
  : > "$td/.review-lock"; chmod 000 "$td/.review-lock"; hook "$fx" '{}'; check "锁不可读:block" $([[ "$OUT" == *'"block"'* ]]; echo $?); chmod 644 "$td/.review-lock"; end 19; }

tc20() { begin 20 "旧版锁目录迁移"; local fx; fx=$(make_fixture 20); local td; td=$(TD "$fx"); mkdir "$td/.review-lock" "$td/.plan-review-lock"
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=pass run bash "$fx/.ai-workflow/scripts/review.sh"; check "review.sh 退出码 3 且含 旧版锁目录 与 rmdir" $([ $RC -eq 3 ] && [[ "$OUT" == *旧版锁目录* && "$OUT" == *rmdir* ]]; echo $?)
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=pass run bash "$fx/.ai-workflow/scripts/plan-review.sh"; check "plan-review.sh 退出码 3 且含 旧版锁目录 与 rmdir" $([ $RC -eq 3 ] && [[ "$OUT" == *旧版锁目录* && "$OUT" == *rmdir* ]]; echo $?)
  check "未启动桩(无 events 文件)" $([ ! -e "$td/.review-raw-01.events.jsonl" ] && [ ! -e "$td/.plan-review-raw-01.events.jsonl" ]; echo $?)
  check "目录原样保留" $([ -d "$td/.review-lock" ] && [ -d "$td/.plan-review-lock" ]; echo $?); end 20; }

tc21() { begin 21 "codex 主进程先退出、后代继续持锁 fd(评审 R-03 回归)"; local fx; fx=$(make_fixture 21); local td; td=$(TD "$fx"); export STUB_DIR="$fx"
  CLAUDE_PROJECT_DIR=$fx STUB_MODE=early run bash "$fx/.ai-workflow/scripts/review.sh"; local ch; ch=$(cat "$fx/child.pid"); log "child pid=$ch"
  check "退出码 3(codex 退出 0 但无输出文件)" $([ $RC -eq 3 ]; echo $?); check "stderr 含 后代仍存活,清理中" $([[ "$OUT" == *后代仍存活* ]]; echo $?)
  run kill -0 $ch; check "后代已被清理" $([ $RC -ne 0 ]; echo $?)
  run lock_free "$td/.review-lock"; check "锁可立即获取" $([ $RC -eq 0 ]; echo $?); unset STUB_DIR; end 21; }

list=${*:-01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21}
for n in $list; do "tc$n"; done
pkill -f 'stub-codex-bin/codex' 2>/dev/null; echo "failures=$FAILS"; exit $FAILS
