#!/usr/bin/env bash
# plan 阶段 Codex 评审:>10 文件改动在实现前先审方案(plan.md)。
# 只读运行 codex(--sandbox read-only),与 review.sh 同构;因 plan 阶段
# 无"评审期间禁改工作区"约束,不设 review.sh 那道完整性哈希双保险。
# 退出码:0=pass 1=fail 3=评审执行异常。
#
# 判定语义以 .ai-workflow/review-standards.md「plan 阶段评审」小节为权威:
# 存在任一 plan-blocker 或 major → fail;仅 minor 或无问题 → pass。
# 轮次上限默认 3;用户明确要求放宽时在 plan.md frontmatter 记
# plan_review_max_rounds(正整数),以该值为准(见 docs/decisions/0003)。
#
# 卡死治理(docs/decisions/0009,与 review.sh 同构):codex 的 stdin 接
# /dev/null;--json 事件流落盘作进度信号,静默超过 RAWF_REVIEW_IDLE_SECONDS
# 或总时长超过 RAWF_REVIEW_MAX_SECONDS 即按会话 + 进程组终止 codex 并 exit 3;
# 锁为 flock 文件 .plan-review-lock,随持有进程退出自动释放。
# 运行环境要求 Linux:util-linux(flock、setsid)与 procps(pgrep)。
set -euo pipefail

# --- 渲染与原子发布(封装为函数,兼作可控测试点)-------------------------
# render_review <raw_json> <nn>:把结构化输出渲染为与实现层评审同构的 md。
render_review() {
  jq -r --arg nn "$2" '
    def sev_rank: {"plan-blocker": 0, "major": 1, "minor": 2};
    "# Plan 评审:第 \($nn) 轮\n\n## 问题清单",
    (if ((.issues // []) | length) == 0 then "无"
     else ((.issues // []) | sort_by(sev_rank[.severity]) | .[]
       | "- [\(.severity)] \(.id) \(.summary)\n  - 详情:\(.detail)")
     end),
    "\n## 总评\n\(.overall)\n\nVERDICT: \(.verdict)"
  ' "$1"
}

# publish_round <task_dir> <nn> <verdict> <raw_json>:渲染到临时文件后
# mv -n 原子发布。目标已存在(并发发布/占位)则不覆盖并返回 3。
# 注:GNU mv -n 遇已存在目标会静默跳过并返回 0,故须用 [ -e "$tmp" ] 判定
# 是否真的搬走了临时文件(未搬走=发布失败),不能只看 mv 退出码。
publish_round() {
  local td=$1 n=$2 v=$3 raw=$4
  local final="$td/plan-review-round-$n-$v.md"
  local tmp="$td/.plan-review-out-$n.$$"
  if ! render_review "$raw" "$n" > "$tmp"; then
    rm -f "$tmp"; echo "渲染评审文件失败" >&2; return 3
  fi
  if ! mv -n "$tmp" "$final" || [ -e "$tmp" ]; then
    rm -f "$tmp"
    echo "评审结论已被并发发布($final 已存在),本次结果未覆盖" >&2; return 3
  fi
  echo "plan-review-round-$n-$v.md"
}

# resolve_max_rounds <plan.md>:解析轮次上限。只认首个 --- 块(frontmatter)
# 内行首的 plan_review_max_rounds: 字段;字段未出现 → 缺省 3;字段出现但值
# 非正整数(含空值)→ 报错返回 3(该字段仅在用户明确要求放宽时写入,不应
# 出现拼写外的形态)。awk 以 "F=" 前缀标记"字段命中",与"未出现"区分——
# 二者在裸值形态下同为空串,无法直接分辨。
resolve_max_rounds() {
  local hit val
  hit=$(awk '/^---[[:space:]]*$/ { n++; next }
             n == 1 && /^plan_review_max_rounds:/ {
               sub(/^plan_review_max_rounds:/, "")
               gsub(/^[[:space:]]+|[[:space:]]+$/, "")
               print "F=" $0; exit }
             n >= 2 { exit }' "$1")
  if [ -z "$hit" ]; then
    echo 3
    return 0
  fi
  val=${hit#F=}
  if [[ "$val" =~ ^[1-9][0-9]*$ ]]; then
    echo "$val"
  else
    echo "plan.md 的 plan_review_max_rounds 非法(须为正整数,实际为:${val:-空})" >&2
    return 3
  fi
}

# 测试可控入口:直接调用发布函数(绕过轮次计数),验证 mv -n 不覆盖行为;
# __resolve_max_rounds 同理,验证上限解析的缺省/合法/非法分支。
if [ "${1:-}" = "__publish_round" ]; then
  shift
  publish_round "$@"
  exit $?
fi
if [ "${1:-}" = "__resolve_max_rounds" ]; then
  shift
  resolve_max_rounds "$@"
  exit $?
fi

# --- 受管进程集合与终止(与 review.sh 同构)--------------------------------
managed_pids() {
  { pgrep -s "$1" || true; pgrep -g "$1" || true; echo "$1"; } 2>/dev/null \
    | sort -un | while read -r p; do kill -0 "$p" 2>/dev/null && echo "$p" || true; done
}
kill_codex_tree() {
  local sid=$1 p i alive
  kill -TERM -- "-$sid" 2>/dev/null || true
  for p in $(managed_pids "$sid"); do kill -TERM "$p" 2>/dev/null || true; done
  for i in $(seq 1 20); do
    alive=$(managed_pids "$sid"); [ -z "$alive" ] && return 0; sleep 0.5
  done
  kill -KILL -- "-$sid" 2>/dev/null || true
  for p in $(managed_pids "$sid"); do kill -KILL "$p" 2>/dev/null || true; done
  for i in $(seq 1 6); do
    alive=$(managed_pids "$sid"); [ -z "$alive" ] && return 0; sleep 0.5
  done
  echo "警告:以下受管进程仍存活:$(echo "$alive" | tr '\n' ' ')" >&2
}
# lock_holders:只列真正持有 flock 的进程(判据与 review.sh 相同:fdinfo 的
# lock: 行 + 锁文件 inode);调用前须先关闭本实例自己的锁 fd。
lock_holders() {
  local real ino fd target pid
  real=$(realpath "$lock" 2>/dev/null) || return 0
  ino=$(stat -c %i "$lock" 2>/dev/null) || return 0
  # find -lname 单进程完成全量匹配(逐 fd readlink 要 fork 数千次,快照会过期)
  # find 对无权限的 /proc 条目会返回非零,须吞掉,否则 set -e/pipefail 下整个
  # 命令替换失败、脚本静默退出
  { find /proc/[0-9]*/fd -maxdepth 1 -lname "$real" 2>/dev/null || true; } | while read -r fd; do
    pid=${fd#/proc/}; pid=${pid%%/*}
    [ "$pid" = "$$" ] && continue
    grep -qE "^lock:.*FLOCK.*:${ino}[[:space:]]" "/proc/$pid/fdinfo/${fd##*/}" 2>/dev/null || continue
    echo "$pid $(cat "/proc/$pid/comm" 2>/dev/null)"
  done | sort -un
}
positive_int() {
  [[ "$2" =~ ^[1-9][0-9]*$ ]] && return 0
  echo "$1 须为正整数,实际为:${2:-空}" >&2
  return 1
}

# --- 主流程(扁平于顶层:lock 等为全局变量,EXIT trap 可见)---------------
for tool in flock setsid pgrep; do
  command -v "$tool" >/dev/null \
    || { echo "需要 util-linux(flock、setsid)与 procps(pgrep):缺少 $tool" >&2; exit 3; }
done
command -v codex >/dev/null || { echo "codex CLI 未安装或不在 PATH" >&2; exit 3; }

idle_limit=${RAWF_REVIEW_IDLE_SECONDS:-900}
max_limit=${RAWF_REVIEW_MAX_SECONDS:-3600}
poll=${RAWF_REVIEW_POLL_SECONDS:-5}
positive_int RAWF_REVIEW_IDLE_SECONDS "$idle_limit" || exit 3
positive_int RAWF_REVIEW_MAX_SECONDS "$max_limit" || exit 3
positive_int RAWF_REVIEW_POLL_SECONDS "$poll" || exit 3

proj="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
cd "$proj"

task_rel=$(cat .ai/.current-task 2>/dev/null) \
  || { echo "无进行中任务(.ai/.current-task 不存在)" >&2; exit 3; }
task_dir="$proj/$task_rel"
[ -d "$task_dir" ] || { echo "任务目录不存在:$task_rel" >&2; exit 3; }
plan="$task_dir/plan.md"
[ -f "$plan" ] || { echo "plan.md 不存在,先完成 /rawf-plan 起草" >&2; exit 3; }

# 互斥由 flock 保证(语义同 review.sh):fd 9 全程持有,持有进程全部退出即
# 自动释放;锁文件常驻、永不删除。
lock="$task_dir/.plan-review-lock"
if [ -d "$lock" ]; then
  echo "检测到旧版锁目录 $task_rel/.plan-review-lock(升级前残留);确认 pgrep -f 'codex exec' 无旧评审进程后执行 rmdir 该目录再重跑" >&2
  exit 3
fi
if ! { true 9>>"$lock"; } 2>/dev/null; then
  echo "无法打开锁文件 $task_rel/.plan-review-lock" >&2; exit 3
fi
exec 9>>"$lock"
flock_rc=0
flock -n -E 75 9 || flock_rc=$?
case "$flock_rc" in
  0) ;;
  75)
    exec 9>&-
    recorded=$(sed -n 's/^script=//p' "$lock" | head -1)
    holders=$(lock_holders)
    # 持有者里是否还有评审脚本进程(按 cmdline 判断,不依赖锁文件元数据):
    # 有 → 正常并发;无 → 脚本被强杀后遗留的评审进程
    script_alive=0
    for hp in $(echo "$holders" | awk '{print $1}'); do
      if { tr '\0' ' ' < "/proc/$hp/cmdline"; } 2>/dev/null | grep -q 'plan-review.sh'; then script_alive=1; fi
    done
    # 快照可能过期(扫描期间评审刚结束):输出前复核锁仍被持有、名单仍存活
    recheck=0
    flock -n -E 75 "$lock" true 2>/dev/null || recheck=$?
    if [ "$recheck" -eq 0 ]; then
      echo "plan 评审刚结束,锁 $task_rel/.plan-review-lock 已释放;请重跑" >&2
      exit 3
    fi
    alive=$(echo "$holders" | while read -r hp hc; do
      [ -n "$hp" ] && kill -0 "$hp" 2>/dev/null && echo "$hp $hc" || true; done)
    {
      echo "已有 plan 评审在进行中,锁 $task_rel/.plan-review-lock 被以下进程持有:"
      echo "${alive:-(未定位到持有进程,可能刚结束;请重跑)}"
      if [ -n "$alive" ] && [ "$script_alive" = 0 ]; then
        echo "持有者中已无评审脚本进程(记录的脚本 pid ${recorded:-未知}),上述为脚本被强杀后遗留的评审进程;确认后执行 kill -TERM $(echo "$alive" | awk '{print $1}' | tr '\n' ' ')再重跑"
      elif [ -n "$alive" ]; then
        echo "待其结束后重跑"
      fi
    } >&2
    exit 3 ;;
  *) echo "锁探测失败(flock 退出码 $flock_rc)" >&2; exit 3 ;;
esac
printf 'script=%s\n' "$$" > "$lock"

codex_pid=
cleanup() { [ -n "$codex_pid" ] && kill_codex_tree "$codex_pid"; return 0; }
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

# 轮次:count=已有 plan-review-round-*.md 数量;nn=count+1。
# 机器上限:缺省 3,可被 plan.md frontmatter 的用户授权值放宽;
# count>=上限直接拒绝,交人工。
max_rounds=$(resolve_max_rounds "$plan") || exit 3
shopt -s nullglob
rounds=("$task_dir"/plan-review-round-*.md)
shopt -u nullglob
count=${#rounds[@]}
if [ "$count" -ge "$max_rounds" ]; then
  echo "plan 评审已达 $max_rounds 轮上限,仍未收敛;停止自动评审,交人工判断" >&2
  exit 3
fi
nn=$(printf '%02d' "$((count + 1))")

prompt=$(cat .ai-workflow/prompts/plan-review.md)
prompt="${prompt//\{\{TASK_DIR\}\}/$task_rel}"
prompt="${prompt//\{\{ROUND\}\}/$nn}"

# 原始输出与事件流直接落在任务目录(已由 .gitignore 忽略),非法/异常时保留供排查。
raw="$task_dir/.plan-review-raw-$nn.json"
events="$task_dir/.plan-review-raw-$nn.events.jsonl"
rm -f "$raw" "$events"

setsid codex exec --json --sandbox read-only -C "$proj" \
  --output-schema "$proj/.ai-workflow/schemas/plan-review.schema.json" \
  --output-last-message "$raw" "$prompt" </dev/null >"$events" &
codex_pid=$!
# 子进程要先执行到 setsid(2) 才成为会话首进程,最多等 2 s;已退出(极快完成)
# 则无需受管,直接放过。
sid_ok=0
for i in $(seq 1 20); do
  if ! kill -0 "$codex_pid" 2>/dev/null; then sid_ok=1; break; fi
  if [ "$(ps -o sid= -p "$codex_pid" 2>/dev/null | tr -d ' ')" = "$codex_pid" ]; then sid_ok=1; break; fi
  sleep 0.1
done
if [ "$sid_ok" != 1 ]; then
  echo "setsid 未按预期生效(codex pid $codex_pid 不是会话首进程),无法受管终止" >&2
  exit 3
fi

# 看门狗:以事件文件字节数为进度信号;醒来先查存活,已结束则不做超时判定
start=$SECONDS; last_size=0; last_change=$SECONDS; reason=
while kill -0 "$codex_pid" 2>/dev/null; do
  sleep "$poll" 9>&-   # 不让 sleep 继承锁 fd:脚本被强杀时它不应再持锁
  kill -0 "$codex_pid" 2>/dev/null || break
  size=$(wc -c < "$events" 2>/dev/null || echo 0)
  if [ "$size" != "$last_size" ]; then last_size=$size; last_change=$SECONDS; fi
  if [ $((SECONDS - last_change)) -ge "$idle_limit" ]; then reason=idle; break; fi
  if [ $((SECONDS - start)) -ge "$max_limit" ]; then reason=max; break; fi
done

codex_rc=0
if [ -n "$reason" ]; then
  kill_codex_tree "$codex_pid"
  wait "$codex_pid" 2>/dev/null || true
  codex_pid=
  case "$reason" in
    idle) echo "评审 ${idle_limit} 秒无新事件,判定卡死,已终止;请重跑评审" >&2 ;;
    max)  echo "评审超过墙钟上限 ${max_limit} 秒,已终止;请重跑评审" >&2 ;;
  esac
  exit 3
fi
wait "$codex_pid" || codex_rc=$?
# codex 主进程已退出但受管后代仍存活(继承锁 fd 会一直持锁)→ 一并清理
if [ -n "$(managed_pids "$codex_pid")" ]; then
  echo "警告:codex 已退出但受管后代仍存活,清理中" >&2
  kill_codex_tree "$codex_pid"
fi
codex_pid=

if [ "$codex_rc" -ne 0 ]; then
  echo "codex exec 执行失败(退出码 $codex_rc),评审未完成;检查 codex login/额度/网络后重跑" >&2
  exit 3
fi
[ -f "$raw" ] || { echo "codex 退出 0 但未产出评审输出文件,评审未完成;请重跑评审" >&2; exit 3; }

# 结构化解析 + 交叉校验:JSON 合法性 → verdict → 按严重度清单推导并比对。
if ! jq -e . "$raw" >/dev/null 2>&1; then
  echo "评审输出不是合法 JSON,原始输出保留在 $task_rel/.plan-review-raw-$nn.json" >&2
  exit 3
fi
verdict=$(jq -r '.verdict // empty' "$raw")
case "$verdict" in
  pass|fail) ;;
  *)
    echo "评审输出缺少合法 verdict 字段,原始输出保留在 $task_rel/.plan-review-raw-$nn.json" >&2
    exit 3 ;;
esac
blocking=$(jq '[.issues // [] | .[] | select(.severity == "plan-blocker" or .severity == "major")] | length' "$raw")
if [ "$blocking" -gt 0 ]; then derived=fail; else derived=pass; fi
if [ "$verdict" != "$derived" ]; then
  echo "评审自报结论($verdict)与严重度清单推导($derived)矛盾,按判定规则该评审无效,原始输出保留在 $task_rel/.plan-review-raw-$nn.json" >&2
  exit 3
fi

out=$(publish_round "$task_dir" "$nn" "$verdict" "$raw") || exit 3
echo "$out"
[ "$verdict" = "pass" ]
