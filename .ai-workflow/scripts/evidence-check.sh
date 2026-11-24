#!/usr/bin/env bash
# 证据机器核验:以 plan.md 测试用例表为基准,逐条核对实现记录
# implementation-round-<NN>.md 的测试结果表及其引用的 rawf-evidence v1 文件
# (规则见 review-standards.md「测试证据档位」与 docs/decisions/t0010、t0015)。
# 证据由本脚本判定,评审者不核。机器负责的只有四件事:记录与 plan 用例表逐条
# 对应且档位一致;每条用例结果为 pass;A 档证据结构完整、归属本用例、退出码
# 为 0;B / C 档证据栏非空。被包住的命令是否真的验证了用例、用例是否充分、
# B / C 档陈述是否属实,由实现者自证。
# 只读,不改任何文件。review.sh 在评审启动前调用;实现者写完记录后也应自跑。
#
# 用法:evidence-check.sh [NN]   (缺省 = 最新实现轮)
# 退出码:0 = 全部通过;1 = 存在不通过项(报告表在 stdout,补交清单在 stderr);
#        3 = 脚本自身错误(无任务、无实现记录等)。
# 判定标记:
#   OK            A 档证据文件结构完整、归属本用例、退出码为 0
#   采信          B / C 档,证据栏非空;陈述由实现者自证,不核验内容
#   NO-FORMAT     plan 未声明 evidence_format: v1
#   DUP-ID        plan 用例表或实现记录中用例编号重复
#   BAD-TIER      plan 用例表的档位不是 A / B / C
#   NOT-PASS      结果不是 pass(blocked 另报 BLOCKED)
#   NO-REF        A 档行的证据单元格未引用任何 *.log 文件
#   MISSING       引用的证据文件不存在
#   NO-HEADER     首行不是 "# rawf-evidence v1"
#   BAD-HEADER    头部缺 tc:/cmd:/cwd:/git_head:/started: 之一(或为空)
#   NO-BODY       缺 "--- output ---" 行
#   NO-FOOTER     最后一个 "--- end ---" 之后缺 exit:/finished:/bytes:
#   BAD-EXIT      exit: 不是 0..255 整数
#   TRUNCATED     正文区字节数 ≠ bytes:
#   TC-MISMATCH   A 档证据文件头的 tc: 与所在记录行的编号不同
#   EXIT-NONZERO  A 档证据文件 exit: 不为 0(A 档以 exit 0 表示用例通过)
#   NO-EVIDENCE   B / C 档行的证据栏为空
#   BLOCKED       结果为 blocked(不得进评审)
#   MISSING-ROW   plan 有此用例、记录无
#   TIER-MISMATCH 记录档位 ≠ plan 档位
#   EXTRA-ROW     记录有、plan 无(只列出,不影响退出码)
#   EMPTY-TABLE   plan 用例表或记录测试结果表缺失/为空
set -uo pipefail
export LC_ALL=C

proj="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$proj" ] && [ -d "$proj" ] || { echo "无法定位项目根" >&2; exit 3; }
task_rel=$(cat "$proj/.ai/.current-task" 2>/dev/null) || { echo "无进行中任务(.ai/.current-task 不存在)" >&2; exit 3; }
task_dir="$proj/$task_rel"
[ -d "$task_dir" ] || { echo "任务目录不存在:$task_rel" >&2; exit 3; }
plan="$task_dir/plan.md"
[ -f "$plan" ] || { echo "plan.md 不存在:$task_rel/plan.md" >&2; exit 3; }

if [ -n "${1:-}" ]; then
  nn=$(printf '%02d' "$((10#$1))") 2>/dev/null || { echo "轮次须为数字" >&2; exit 3; }
else
  shopt -s nullglob
  rounds=("$task_dir"/implementation-round-*.md)
  shopt -u nullglob
  [ "${#rounds[@]}" -gt 0 ] || { echo "尚无实现记录" >&2; exit 3; }
  nn=$(printf '%02d' "${#rounds[@]}")
fi
record="$task_dir/implementation-round-$nn.md"
[ -f "$record" ] || { echo "实现记录不存在:$task_rel/implementation-round-$nn.md" >&2; exit 3; }

# 只认首个 --- 块内的 evidence_format: v1。未声明(或取值不是 v1)不再作为
# 历史任务豁免:评审者已不核证据,跳过机器核验就等于没有任何人核验。
fmt=$(awk '/^---[[:space:]]*$/ { n++; next } n == 1 && /^evidence_format:/ { sub(/^evidence_format:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }' "$plan")
if [ "$fmt" != "v1" ]; then
  echo "机器核验(evidence-check,$task_rel,第 $nn 轮):"
  echo
  echo "| 编号 | 档位 | 结果 | 证据文件 | 机器核验 | exit | cmd |"
  echo "|---|---|---|---|---|---|---|"
  echo "| — | — | — | — | NO-FORMAT |  | plan 未声明 evidence_format: v1 |"
  echo
  echo "结论:未通过(补交清单见 stderr)。"
  { echo "补交清单:"; echo "- NO-FORMAT plan.md frontmatter 未声明 evidence_format: v1;补上该字段并按 rawf-evidence v1(evidence.sh)留证后再送审"; } >&2
  exit 1
fi

# table_rows <file> <section-heading-regex>:输出该节内的表格数据行,
# 各列以 \t 分隔、去首尾空白,跳过表头(首列为"编号")与分隔行(|---)。
table_rows() {
  awk -v sec="$2" '
    /^## / { insec = ($0 ~ sec) ? 1 : 0; next }
    insec && /^\|/ {
      line = $0
      sub(/^\|/, "", line); sub(/\|[[:space:]]*$/, "", line)
      n = split(line, c, "|")
      out = ""
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", c[i])
        out = out (i > 1 ? "\t" : "") c[i]
      }
      if (c[1] ~ /^-+$/ || c[1] == "编号" || c[1] == "") next
      print out
    }' "$1"
}

# 基准:plan 用例表(编号 → 档位)。重复编号只保留首次出现的行,并记入 DUP-ID
declare -A plan_tier
plan_ids=(); plan_dups=()
while IFS=$'\t' read -r id tier _; do
  [[ "$id" =~ ^TC- ]] || continue
  if [ -n "${plan_tier[$id]+x}" ]; then plan_dups+=("$id"); continue; fi
  plan_tier["$id"]=$tier
  plan_ids+=("$id")
done < <(table_rows "$plan" '^## 测试用例')

# 记录:测试结果表(编号、档位、结果、证据)
declare -A rec_tier rec_result rec_evidence
rec_ids=(); rec_dups=()
while IFS=$'\t' read -r id tier result evidence _; do
  [[ "$id" =~ ^TC- ]] || continue
  if [ -n "${rec_tier[$id]+x}" ]; then rec_dups+=("$id"); continue; fi
  rec_tier["$id"]=$tier; rec_result["$id"]=${result:-}; rec_evidence["$id"]=${evidence:-}
  rec_ids+=("$id")
done < <(table_rows "$record" '^## 测试结果')

fail=0
rows=()      # 渲染行
todo=()      # 补交清单

add_row() { rows+=("| $1 | $2 | $3 | $4 | $5 | $6 | $7 |"); }
need() { fail=1; todo+=("$1"); }

# check_file <path> → 输出 "<标记>\x1f<exit>\x1f<cmd 摘要>\x1f<tc>"(\x1f 分隔:tab 属 IFS 空白,空字段会被折叠)
check_file() {
  local f=$1
  [ -f "$f" ] || { printf 'MISSING\x1f\x1f\x1f\n'; return; }
  [ "$(head -n 1 "$f")" = "# rawf-evidence v1" ] || { printf 'NO-HEADER\x1f\x1f\x1f\n'; return; }
  # 头部 = 首个 --- output --- 之前
  local hdr; hdr=$(awk '/^--- output ---$/ { exit } { print }' "$f")
  local missing=() k v
  for k in tc cmd cwd git_head started; do
    v=$(printf '%s\n' "$hdr" | awk -v k="$k" 'index($0, k ": ") == 1 { sub("^" k ": ", ""); print; exit }')
    [ -n "$v" ] || missing+=("$k")
  done
  local cmd; cmd=$(printf '%s\n' "$hdr" | awk 'index($0, "cmd: ") == 1 { sub(/^cmd: /, ""); print; exit }')
  local cmd_short=${cmd:0:60}; [ "${#cmd}" -gt 60 ] && cmd_short="$cmd_short…"
  cmd_short=${cmd_short//|/\\|}
  local tcv; tcv=$(printf '%s\n' "$hdr" | awk 'index($0, "tc: ") == 1 { sub(/^tc: /, ""); print; exit }')
  if [ "${#missing[@]}" -gt 0 ]; then printf 'BAD-HEADER(缺 %s)\x1f\x1f%s\x1f%s\n' "$(IFS=,; echo "${missing[*]}")" "$cmd_short" "$tcv"; return; fi
  # 字节级定位:正文区起点 = 首个 output 行之后;终点 = 最后一个 end 行之前的换行
  local pos; pos=$(awk '
    { off = cum; cum += length($0) + 1
      if (!o && $0 == "--- output ---") { o = 1; start = cum }
      if ($0 == "--- end ---") { e = 1; endoff = off }
    }
    END { if (!o) print "NO-BODY"; else if (!e) print "NO-FOOTER"; else print start, endoff }' "$f")
  case "$pos" in
    NO-BODY|NO-FOOTER) printf '%s\x1f\x1f%s\x1f%s\n' "$pos" "$cmd_short" "$tcv"; return ;;
  esac
  local start endoff; read -r start endoff <<< "$pos"
  local footer; footer=$(tail -c +"$((endoff + 1))" "$f")
  local ex fin by
  ex=$(printf '%s\n' "$footer" | awk 'index($0, "exit: ") == 1 { sub(/^exit: /, ""); print; exit }')
  fin=$(printf '%s\n' "$footer" | awk 'index($0, "finished: ") == 1 { sub(/^finished: /, ""); print; exit }')
  by=$(printf '%s\n' "$footer" | awk 'index($0, "bytes: ") == 1 { sub(/^bytes: /, ""); print; exit }')
  if [ -z "$ex" ] || [ -z "$fin" ] || [ -z "$by" ]; then printf 'NO-FOOTER\x1f%s\x1f%s\x1f%s\n' "$ex" "$cmd_short" "$tcv"; return; fi
  if ! [[ "$ex" =~ ^[0-9]+$ ]] || [ "$ex" -gt 255 ]; then printf 'BAD-EXIT\x1f%s\x1f%s\x1f%s\n' "$ex" "$cmd_short" "$tcv"; return; fi
  local body_len=$((endoff - 1 - start))
  [ "$body_len" -lt 0 ] && body_len=0
  if ! [[ "$by" =~ ^[0-9]+$ ]] || [ "$body_len" -ne "$by" ]; then printf 'TRUNCATED(正文 %s 字节,bytes: %s)\x1f%s\x1f%s\x1f%s\n' "$body_len" "$by" "$ex" "$cmd_short" "$tcv"; return; fi
  printf 'OK\x1f%s\x1f%s\x1f%s\n' "$ex" "$cmd_short" "$tcv"
}

if [ "${#plan_ids[@]}" -eq 0 ]; then
  add_row "—" "—" "—" "—" "EMPTY-TABLE" "" "plan.md 无「测试用例」表或为空"
  need "EMPTY-TABLE plan.md 的「## 测试用例」表缺失或为空"
fi
if [ "${#rec_ids[@]}" -eq 0 ]; then
  add_row "—" "—" "—" "—" "EMPTY-TABLE" "" "implementation-round-$nn.md 无「测试结果」表或为空"
  need "EMPTY-TABLE implementation-round-$nn.md 的「## 测试结果」表缺失或为空"
fi
for id in "${plan_dups[@]}"; do
  add_row "$id" "—" "—" "—" "DUP-ID" "" "plan.md 用例表中该编号重复"
  need "$id:DUP-ID plan.md「## 测试用例」表中该编号出现多次,编号须唯一"
done
for id in "${rec_dups[@]}"; do
  add_row "$id" "—" "—" "—" "DUP-ID" "" "实现记录中该编号重复"
  need "$id:DUP-ID implementation-round-$nn.md「## 测试结果」表中该编号出现多次,每条用例只写一行"
done

for id in "${plan_ids[@]}"; do
  ptier=${plan_tier[$id]}
  # 档位只有 A / B / C 三种;未定义的档位不得按 B / C 档采信
  case "$ptier" in
    A|B|C) ;;
    *)
      add_row "$id" "${ptier:-(空)}" "—" "—" "BAD-TIER" "" "plan 的档位不是 A / B / C"
      need "$id:BAD-TIER plan.md 用例表的档位为「${ptier:-空}」,只能是 A、B、C"
      continue ;;
  esac
  if [ -z "${rec_tier[$id]+x}" ]; then
    add_row "$id" "$ptier" "—" "—" "MISSING-ROW" "" "plan 有此用例,记录无"
    need "$id:MISSING-ROW 实现记录缺少该用例行(plan 档位 $ptier)"
    continue
  fi
  rtier=${rec_tier[$id]}; result=${rec_result[$id]}; evcell=${rec_evidence[$id]}
  if [ "$rtier" != "$ptier" ]; then
    add_row "$id" "$rtier" "$result" "—" "TIER-MISMATCH" "" "plan 为 $ptier 档,记录写 $rtier"
    need "$id:TIER-MISMATCH 档位与 plan 不一致(plan $ptier,记录 $rtier),档位须照抄 plan"
    continue
  fi
  if [ "$result" = "blocked" ]; then
    add_row "$id" "$rtier" "$result" "—" "BLOCKED" "" "存在 blocked 项,须先经用户裁决"
    need "$id:BLOCKED 结果为 blocked,不得进入评审"
    continue
  fi
  if [ "$result" != "pass" ]; then
    add_row "$id" "$rtier" "${result:-(空)}" "—" "NOT-PASS" "" "结果须为 pass 才能送审"
    need "$id:NOT-PASS 结果为「${result:-空}」;全部用例通过之前不进入评审"
    continue
  fi
  if [ "$rtier" != "A" ]; then
    # 证据栏只有空白或占位横线视为空
    if [[ "$evcell" =~ ^[[:space:]—–-]*$ ]]; then
      add_row "$id" "$rtier" "$result" "—" "NO-EVIDENCE" "" "证据栏为空"
      need "$id:NO-EVIDENCE $rtier 档证据栏为空;B 档给出 文件:行号 或日志片段,C 档给出结果陈述与关键锚点"
    else
      add_row "$id" "$rtier" "$result" "${evcell//|/\\|}" "采信" "" "陈述已登记,由实现者自证"
    fi
    continue
  fi
  # A 档:提取证据单元格里的 *.log 文件名
  mapfile -t files < <(printf '%s\n' "$evcell" | grep -oE '[A-Za-z0-9_./-]+\.log' | sort -u)
  if [ "${#files[@]}" -eq 0 ]; then
    add_row "$id" "$rtier" "$result" "—" "NO-REF" "" "证据单元格未引用 *.log 文件"
    need "$id:NO-REF 证据单元格未引用任何 evidence.sh 产出的 *.log 文件"
    continue
  fi
  for f in "${files[@]}"; do
    name=${f##*/}
    IFS=$'\x1f' read -r mark ex cmd_short evtc <<< "$(check_file "$task_dir/evidence/$name")"
    # 结构完整之后再核归属与退出码:A 档以 exit 0 表示用例通过
    if [ "$mark" = OK ]; then
      if [ "$evtc" != "$id" ]; then
        mark="TC-MISMATCH(文件头 tc: $evtc)"
      elif [ "$ex" != 0 ]; then
        mark=EXIT-NONZERO
      fi
    fi
    add_row "$id" "$rtier" "$result" "$name" "$mark" "$ex" "$cmd_short"
    case "$mark" in
      OK) ;;
      TC-MISMATCH*) need "$id:evidence/$name → TC-MISMATCH 该证据文件属于 $evtc,不能作为 $id 的证据" ;;
      EXIT-NONZERO) need "$id:evidence/$name → EXIT-NONZERO exit: $ex;A 档以 exit 0 表示用例通过,预期非零退出的被测命令须用断言包一层后重新留证" ;;
      *) need "$id:evidence/$name → $mark" ;;
    esac
  done
done

for id in "${rec_ids[@]}"; do
  [ -z "${plan_tier[$id]+x}" ] || continue
  add_row "$id" "${rec_tier[$id]}" "${rec_result[$id]}" "${rec_evidence[$id]//|/\\|}" "EXTRA-ROW" "" "plan 无此用例,纳入范围核对"
done

echo "机器核验(evidence-check,$task_rel,第 $nn 轮):"
echo
echo "| 编号 | 档位 | 结果 | 证据文件 | 机器核验 | exit | cmd |"
echo "|---|---|---|---|---|---|---|"
printf '%s\n' "${rows[@]}"
echo
if [ "$fail" -eq 1 ]; then
  echo "结论:未通过(补交清单见 stderr)。"
  { echo "补交清单:"; printf -- '- %s\n' "${todo[@]}"; } >&2
  exit 1
fi
echo "结论:记录与 plan 用例清单一致,结果均为 pass。A 档:证据结构完整、归属本用例、命令退出码为 0;B、C 档:陈述已登记并采信(内容由实现者自证,未经核验)。"
exit 0
