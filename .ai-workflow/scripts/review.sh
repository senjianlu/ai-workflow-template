#!/usr/bin/env bash
# 调用 Codex 评审当前改动。退出码:0=pass 1=fail 3=评审执行异常(含看门狗终止)
# 评审以只读沙箱(--sandbox read-only)直审原仓库,不建副本(与
# plan-review.sh 同构;取消副本的决策见 docs/decisions/t0005)。评审者不
# 运行任何测试,也不核验证据——证据由 evidence-check.sh 在评审启动前机器判定。
# 完整性哈希保留为双保险:检测评审期间主工作区的并发写入,兜底沙箱失效;
# 只读沙箱生效且无并发写入时理应永不触发。
#
# 判定(docs/decisions/t0015):评审者不自报结论。脚本先校验输出结构,再按
# 问题的 file 做路径归类,把指向非产品路径或缺失败场景的问题降为建议,余下有
# blocker/major 即 fail。每轮保存所审改动的清单与内容快照,第 2 轮起据此生成
# 轮间差异,评审者只审修复(规则见 review-standards.md「分轮模式」)。
# 评审模型缺省用 Codex 自身配置的默认值;用户明确点名时在 plan.md frontmatter 记
# impl_review_model / impl_review_effort,脚本据此给 codex exec 加 -m 与
# -c model_reasoning_effort(见 docs/decisions/t0016)。
#
# 卡死治理(docs/decisions/t0009):codex 的 stdin 接 /dev/null(codex 在 stdin
# 非终端时必读到 EOF);--json 事件流落盘作进度信号,静默超过
# RAWF_REVIEW_IDLE_SECONDS 或总时长超过 RAWF_REVIEW_MAX_SECONDS 即按会话 +
# 进程组终止 codex 并 exit 3;锁为 flock 文件,随持有进程退出自动释放。
# 运行环境要求 Linux:util-linux(flock、setsid)、procps(pgrep)、
# coreutils(sha1sum)、findutils(xargs)与 diffutils(diff、cmp)。
set -euo pipefail

# --- 完整性指纹(封装于顶层,兼作可控测试点)-----------------------------
# 快照口径:已跟踪改动 + 未跟踪文件(符号链接记链接目标、不跟随;普通文件记
# 可执行位 + 内容哈希)。分三段,各自先哈希再合并,无跨段拼接歧义:
#   diff 段      git diff HEAD
#   元数据子段   逐条 NUL 定界:symlink\0路径\0链接目标\0 / file\0路径\0x|-\0
#   内容子段     sha1sum -z 的记录:<sha1>  ./<路径>\0
# 内容子段按参数容量分批交给 sha1sum(xargs),不为每个文件单独启动哈希进程
# ——未跟踪文件上万时,逐文件启动进程的开销是分钟级的。路径一律加 ./ 前缀:
# sha1sum 把操作数 - 当作标准输入,-- 消不掉这层含义。
# 失败语义:sha1sum 对个别文件失败(不可读)时 xargs 返回 123,容忍(该文件无
# 内容记录,同批与后续批次照常计入);其它失败(工具缺失、异常退出)使
# workspace_hash 返回非 0 且不输出指纹,调用点据此 exit 3。
# 未跟踪文件不按 .gitignore 排除(防 .env 等被忽略文件遭篡改而不被发现),
# 只排除明确允许的评审/测试产物。
# .claude/ 例外排除:评审强制后台运行,主会话在评审期间仍活跃,而 Claude
# Code 会自动写 .claude/settings.local.json(记录权限授予,不经工具、无从拦截),
# 若纳入指纹会把这类并发写入误判为"隔离失败"致评审无效。故整目录不计入。
# .review-lock:flock 锁文件常驻任务目录(永不删除),评审前后都在,排除只为
# 让 git status 在评审期间保持干净。
# TEMPLATE: 按项目构建产物增删排除项。
hash_excludes=(
  --exclude='.review-raw-*'
  --exclude='.review-lock'
  --exclude='.claude/'
  --exclude='__pycache__/' --exclude='*.pyc' --exclude='.pytest_cache/'
  --exclude='.venv/' --exclude='node_modules/' --exclude='dist/' --exclude='.next/'
  --exclude='.DS_Store'
)
untracked_meta() {
  local f m
  git ls-files --others -z "${hash_excludes[@]}" \
    | while IFS= read -r -d '' f; do
        if [ -L "$f" ]; then
          printf 'symlink\0%s\0' "$f"
          readlink "$f"
          printf '\0'
        else
          if [ -x "$f" ]; then m=x; else m=-; fi
          printf 'file\0%s\0%s\0' "$f" "$m"
        fi
      done
}
untracked_content() {
  local f rc=0
  git ls-files --others -z "${hash_excludes[@]}" \
    | while IFS= read -r -d '' f; do
        [ -L "$f" ] || printf './%s\0' "$f"
      done \
    | xargs -0 -r sha1sum -z -- || rc=$?
  case "$rc" in
    0|123) return 0 ;;
    *) return "$rc" ;;
  esac
}
workspace_hash() {
  local d m c
  d=$(git diff HEAD -- . ':(exclude).claude' | shasum) || return 1
  m=$(untracked_meta | shasum) || return 1
  c=$(untracked_content | shasum) || return 1
  printf '%s\n%s\n%s\n' "$d" "$m" "$c" | shasum | cut -d' ' -f1
}

# 测试可控入口:脱离 codex 与主流程单测指纹敏感性(CLAUDE_PROJECT_DIR
# 指向测试用临时工作区),循 plan-review.sh __publish_round 先例。
if [ "${1:-}" = "__workspace_hash" ]; then
  proj="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
  cd "$proj"
  workspace_hash
  exit $?
fi

# --- 判定:输入校验、路径归类、降级与渲染(docs/decisions/t0015)-------------
# 路径归类:命中 product_globs → 产品路径;否则命中 nonproduct_globs → 非产品
# 路径;其余(含空串、无法定位或越出仓库根的路径)→ 产品路径。匹配对象是词法
# 归一后的仓库相对路径。清单项按写法分四种,目录按路径组件匹配、文件名规则
# 只匹配 basename,通配符不会跨过 /:
#   '/dir/'   以 / 开头并以 / 结尾:从仓库根起的目录('/docs/' 命中 docs/ 下的一切)
#   'name/'   只以 / 结尾:任意层级的目录名('tests/' 命中 tests/x 与 a/tests/x,
#             不命中 a/mytests/x)
#   '/glob'   只以 / 开头:仓库根目录下的文件名通配('/README.md')
#   'glob'    其余:任意层级的文件名通配('test_*.py' 命中 a/test_x.py,不命中
#             apps/test_management/api.py)
# TEMPLATE: 按项目增删。product_globs 优先于 nonproduct_globs,用于把"文档即
# 产品"一类路径从非产品清单里挖出来(如 '/docs/site/')。
product_globs=()
nonproduct_globs=(
  '/.ai/' '/docs/'
  '/README.md' '/CHANGELOG.md'
  'tests/' 'test/' '__tests__/' 'e2e/'
  'test_*.py' '*_test.py' '*.test.*' '*.spec.*' 'conftest.py'
)

# path_matches <归一后的路径> <清单项>:按上面四种写法判断是否命中。
path_matches() {
  local p=$1 g=$2
  case "$g" in
    /*/) case "/$p" in "$g"*) return 0 ;; esac ;;
    */)  case "/$p" in *"/$g"*) return 0 ;; esac ;;
    /*)
      case "$p" in */*) return 1 ;; esac
      # shellcheck disable=SC2254  # 清单项就是要按通配解释
      case "$p" in ${g#/}) return 0 ;; esac ;;
    *)
      # shellcheck disable=SC2254
      case "${p##*/}" in $g) return 0 ;; esac ;;
  esac
  return 1
}

# normalize_issue_path <路径>:去掉项目根绝对前缀与尾部 :行号,折叠 .、.. 与重复
# 的 /。输出归一后的仓库相对路径;越出仓库根(.. 多于层数,或仓库外的绝对路径)
# 时输出以 "../" 开头的串,由 classify_issue_path 按产品路径处理。依赖全局 proj。
normalize_issue_path() {
  local p=$1 seg escaped=0 joined
  local -a segs=() out=()
  while [[ "$p" =~ ^(.*):[0-9]+(-[0-9]+)?$ ]]; do p=${BASH_REMATCH[1]}; done
  case "$p" in
    "$proj"/*) p=${p#"$proj"/} ;;
    "$proj") p= ;;
    /*) printf '../%s\n' "${p#/}"; return 0 ;;
  esac
  IFS=/ read -r -a segs <<< "$p" || true
  for seg in "${segs[@]}"; do
    case "$seg" in
      ''|.) ;;
      ..) if [ "${#out[@]}" -gt 0 ]; then unset 'out[-1]'; else escaped=1; fi ;;
      *) out+=("$seg") ;;
    esac
  done
  joined=$(IFS=/; printf '%s' "${out[*]}")
  if [ "$escaped" = 1 ]; then printf '../%s\n' "$joined"; else printf '%s\n' "$joined"; fi
}

# classify_issue_path <归一后的路径>:输出 product | nonproduct | taskplan。
# taskplan = 本任务的 plan.md(plan-blocker 允许指向它)。依赖全局 task_rel。
classify_issue_path() {
  local p=$1 g
  case "$p" in ''|../*) echo product; return 0 ;; esac
  if [ "$p" = "$task_rel/plan.md" ]; then echo taskplan; return 0; fi
  for g in "${product_globs[@]}"; do
    if path_matches "$p" "$g"; then echo product; return 0; fi
  done
  for g in "${nonproduct_globs[@]}"; do
    if path_matches "$p" "$g"; then echo nonproduct; return 0; fi
  done
  echo product
}

# issue_classes <raw_json>:逐条 issue 归类,输出与 issues 等长的 JSON 数组。
issue_classes() {
  local f cls
  local -a out=()
  while IFS= read -r f; do
    cls=$(classify_issue_path "$(normalize_issue_path "$f")")
    out+=("$cls")
  done < <(jq -r '.issues[] | .file | gsub("[\r\n]"; " ")' "$1")
  if [ "${#out[@]}" -eq 0 ]; then echo '[]'; else printf '%s\n' "${out[@]}" | jq -R . | jq -cs .; fi
}

# validate_review_json <raw_json>:最低输入校验。评审者不再自报 verdict,结论完全
# 由脚本推导,因此结构不合法的输出(空对象、缺字段、类型错误、非法严重度)必须
# 在这里拦下,不得渲染成 pass。
validate_review_json() {
  jq -e '
    def strs: type == "array" and all(.[]; type == "string");
    # 枚举按"是字符串且与某一项严格相等"判定(index 会把数组当作子序列查找)
    def one_of($xs): . as $v | ($v | type) == "string" and any($xs[]; . == $v);
    # 键集合必须与 schema 完全一致:缺字段、多字段(如旧版的 verdict)都不合法
    def keys_are($xs): keys == ($xs | sort);
    (type == "object")
    and keys_are(["issues", "test_gaps", "advisories", "scope_findings", "overall"])
    and ((.issues | type) == "array")
    and all(.issues[];
          type == "object"
          and keys_are(["id", "severity", "file", "line", "summary", "scenario", "detail"])
          and ([.id, .file, .summary, .scenario, .detail] | all(.[]; type == "string"))
          and ((.line | type) == "number") and (.line == (.line | floor))
          and (.severity | one_of(["plan-blocker", "blocker", "major", "minor"])))
    and (.test_gaps | strs) and (.advisories | strs) and (.scope_findings | strs)
    and ((.overall | type) == "string")
  ' "$1" >/dev/null 2>&1
}

# jq 前导:并入归类结果 $cls 后推导每条 issue 的降级原因(_why 为空串 = 留在问题
# 清单)与结论。规则:非 plan-blocker 位于非产品路径(含任务目录)→ 降级;
# plan-blocker 只接受本任务 plan.md、空串或产品路径;plan-blocker / blocker /
# major 的失败场景为空白 → 降级;余下有 blocker/major → fail。
# shellcheck disable=SC2016  # jq 程序里的 $ 是 jq 变量
jq_derive='
  # 空白 = 不含任何非空白字符(不依赖 ^ / $ 的行锚点语义)
  def blank: test("\\S") | not;
  def oneline: gsub("\\s*\\n\\s*"; " ");
  def pad2: tostring | if length < 2 then "0" + . else . end;
  def sev_rank: {"plan-blocker": 0, "blocker": 1, "major": 2, "minor": 3};
  .issues = [ .issues | to_entries[] | .value + {_cls: $cls[.key]} ]
  | .issues |= map(. + {_why: (
      if .severity == "plan-blocker" then
        (if ._cls == "nonproduct" then "非产品路径"
         elif (.scenario | blank) then "缺失败场景" else "" end)
      elif ._cls != "product" then "非产品路径"
      elif (.severity != "minor") and (.scenario | blank) then "缺失败场景"
      else "" end)})
  | .kept = [ .issues[] | select(._why == "") ]
  | .demoted = [ .issues[] | select(._why != "") ]
  | .verdict = (if any(.kept[]; .severity == "blocker" or .severity == "major")
                then "fail" else "pass" end)
'

# derive_verdict <raw_json> <cls_json>:输出 pass | fail。
derive_verdict() {
  jq -r --argjson cls "$2" "$jq_derive | .verdict" "$1"
}

# render_review <raw_json> <NN> <cls_json>:渲染评审文件。问题清单按严重度排序
# (plan-blocker 置顶,同级保持原顺序);测试缺口取前 3 条、评审者自拟建议取前
# 5 条,超出部分只注明条数;脚本降级的条目保留原编号并带标记,不受条数限制。
# --arg render 1 为渲染调用的特征标记,便于测试注入,对 jq 语义无影响。
render_review() {
  # shellcheck disable=SC2016
  jq -r --arg render 1 --arg nn "$2" --argjson cls "$3" "$jq_derive"'
    | def loc: (if .file == "" then ""
                else "\n  - 位置:\(.file)\(if .line > 0 then ":\(.line)" else "" end)" end);
      def scn: (if (.scenario | blank) then "" else "\n  - 失败场景:\(.scenario | oneline)" end);
      def item: "\(.summary | oneline)\(loc)\(scn)\n  - 详情:\(.detail | oneline)";
    "# 评审:第 \($nn) 轮\n\n## 问题清单",
    (if (.kept | length) == 0 then "无"
     else (.kept | sort_by(sev_rank[.severity]) | .[] | "- [\(.severity)] \(.id) \(item)") end),
    "\n## 测试缺口(不计入 pass/fail)",
    (if (.test_gaps | length) == 0 then "无"
     else (.test_gaps[0:3] | to_entries[] | "- T-\(.key + 1 | pad2) \(.value | oneline)") end),
    (if (.test_gaps | length) > 3
     then "(另有 \((.test_gaps | length) - 3) 条超出上限未列出,见原始输出)" else empty end),
    "\n## 建议(不计入 pass/fail)",
    (if ((.advisories | length) + (.demoted | length)) == 0 then "无" else empty end),
    (.advisories[0:5] | to_entries[] | "- A-\(.key + 1 | pad2) \(.value | oneline)"),
    (if (.advisories | length) > 5
     then "(另有 \((.advisories | length) - 5) 条超出上限未列出,见原始输出)" else empty end),
    (.demoted[] | "- [\(.severity)] \(.id) 〔降级:\(._why)〕\(item)"),
    "\n## 范围核对",
    (if (.scope_findings | length) == 0 then "无" else (.scope_findings[] | "- \(oneline)") end),
    "\n## 总评\n\(.overall)\n\nVERDICT: \(.verdict)"
  ' "$1"
}

# list_minors <任务目录>:汇总全部实现评审轮次的非阻断条目(minor、测试缺口、
# 建议、降级条目),每条一行 "| impl/NN/<编号> | <类别>:<概要> |";无则输出"无"。
# 供 rawf-report 收尾汇总——修复轮只审修复,首轮的 minor 不会在末轮重复出现。
# 1.5.0 之前的旧格式评审文件没有测试缺口与建议两节,只提取出 minor。只读。
list_minors() {
  local td=${1:-} f nn out all=
  [ -d "$td" ] || { echo "任务目录不存在:$td" >&2; return 3; }
  shopt -s nullglob
  local files=("$td"/review-round-*.md)
  shopt -u nullglob
  for f in "${files[@]}"; do
    nn=${f##*/review-round-}; nn=${nn%%-*}
    out=$(awk -v ref="impl/$nn" '
      function row(id, text) { gsub(/\|/, "\\|", text); printf "| %s/%s | %s |\n", ref, id, text }
      /^## / { sec = $0; next }
      sec ~ /^## 问题清单/ && /^- \[minor\] R-[0-9]+ / {
        t = $0; sub(/^- \[minor\] R-[0-9]+ /, "", t); row($3, "minor:" t); next }
      sec ~ /^## 测试缺口/ && /^- T-[0-9]+ / {
        t = $0; sub(/^- T-[0-9]+ /, "", t); row($2, "测试缺口:" t); next }
      sec ~ /^## 建议/ && /^- A-[0-9]+ / {
        t = $0; sub(/^- A-[0-9]+ /, "", t); row($2, "建议:" t); next }
      sec ~ /^## 建议/ && /^- \[[a-z-]+\] R-[0-9]+ / {
        t = $0; sub(/^- \[[a-z-]+\] R-[0-9]+ /, "", t); row($3, "降级" $2 ":" t); next }
    ' "$f")
    [ -n "$out" ] && all+="$out"$'\n'
  done
  if [ -z "$all" ]; then echo "无"; else printf '%s' "$all"; fi
}

if [ "${1:-}" = "__minors" ]; then
  shift
  list_minors "$@"
  exit $?
fi

# --- 每轮所审改动的清单、内容快照与轮间差异 --------------------------------
# 路径口径(评审对象以这份清单为准):
#   已跟踪文件  相对 HEAD 有差异的全部纳入(含已删除),不受任何排除清单影响
#   未跟踪文件  须同时通过两套规则,各自独立判断、不合并进同一条命令——
#     规则甲  git ls-files --others --exclude-standard:未被 .gitignore 等标准规则忽略
#     规则乙  git ls-files --others + hash_excludes:未被项目的排除清单排除
#             (与工作区指纹列未跟踪文件用的是同一种调用)
#     纳入 = 通过规则甲,并且(位于 .claude/ 下,或通过规则乙)
#   另排除 .ai/(任务产物不是评审对象)、.claude/settings.local.json 与
#   .claude/worktrees/。
# 两套规则分开判断:git 里命令行模式的优先级高于标准忽略规则,合并后排除清单里
# 的反选模式(!…)会把 .gitignore 已忽略的文件重新带进快照。.claude/ 下的路径
# 只看规则甲:其下的 skill、hook 属于评审对象,而排除清单里 dist/ 这类不带锚点
# 的目录模式会命中 .claude/skills/dist/ 之类的嵌套目录(指纹排除 .claude/ 是因为
# Claude Code 会在评审期间自动写 settings.local.json,与快照无关)。
# 这里只定快照的口径;工作区指纹仍按 hash_excludes 原有的语义计算。
# 以下函数依赖全局 proj、task_dir、task_rel、scratch,且 cwd = proj。
review_pathspec=(':(exclude).ai' ':(exclude).claude/settings.local.json' ':(exclude).claude/worktrees')
snap_limit=1048576   # 单文件内容快照上限(字节);超过即"未快照"
# 指令经单个命令行参数传给 codex(Linux 上单个参数约 128 KiB)。两块可变长内容
# ——变化文件列表与证据报告——各自内联不超过 inline_budget 字节,超出部分落盘
# 供评审者按路径读取;拼好的指令再按 prompt_limit 做一次总量兜底。
inline_budget=16384
prompt_limit=100000

# enc_field / dec_field:清单字段(路径、符号链接目标)的无歧义编码——% → %25、
# 制表符 → %09、换行 → %0A、回车 → %0D,其余字节原样。编码是单射:不同的原文
# 不会得到相同的字段,不含这四种字符的普通路径编码后不变。结果放在 REPLY
# (不经子 shell,清单逐文件调用)。
enc_field() {
  REPLY=$1
  REPLY=${REPLY//\%/%25}; REPLY=${REPLY//$'\t'/%09}
  REPLY=${REPLY//$'\n'/%0A}; REPLY=${REPLY//$'\r'/%0D}
}
dec_field() {
  REPLY=$1
  REPLY=${REPLY//%0D/$'\r'}; REPLY=${REPLY//%0A/$'\n'}
  REPLY=${REPLY//%09/$'\t'}; REPLY=${REPLY//%25/%}
}
# disp_field <编码后的字段>:给评审者看的写法,结果放 REPLY。不含制表符/换行/回车
# 时就是真实内容(% 原样显示,可直接当路径用);含这些控制字符时显示编码形式并
# 带标注,不会与恰好长成那样的真实路径混淆。
disp_field() {
  local enc=$1
  dec_field "$enc"
  case "$REPLY" in
    *$'\t'*|*$'\n'*|*$'\r'*) REPLY="$enc〔含控制字符,按 %XX 编码显示〕" ;;
  esac
}

# 清单格式标记(首行)。读取上一轮清单时据此判断能否按当前格式解读。
manifest_magic=$'rawf-manifest\t1'

# manifest_readable <清单文件>:该清单能否按当前格式解读。带格式标记 → 能。不带
# 标记的是引入标记之前写出的清单(路径未统一编码):只有通篇不含 % 且没有以 $'
# 开头的字段(旧的 shell 转义写法)时,才与当前格式逐字节等价,否则不能。
manifest_readable() {
  if [ "$(head -n 1 "$1")" = "$manifest_magic" ]; then return 0; fi
  if grep -q '%' "$1" || grep -qF $'\t$\'' "$1"; then return 1; fi
  return 0
}

# snapshot_scope:本轮纳入口径的摘要 = hash_excludes 各项的哈希,记在清单 head 行
# 的第三列。两轮口径不同时不能逐项比对清单(上一轮纳入、这一轮排除的文件会被
# 报成"删除"),须回退为全量评审。摘要只覆盖数组里写的参数本身:项目若用
# --exclude-from 引用规则文件,文件内容的变化不在摘要里。
snapshot_scope() {
  printf '%s\0' "${hash_excludes[@]}" | sha1sum | cut -d' ' -f1
}

review_paths() {
  local p
  git diff HEAD --no-renames --name-only -z -- . "${review_pathspec[@]}" > "$scratch/rp-tracked" || return 1
  git ls-files --others --exclude-standard -z -- . "${review_pathspec[@]}" \
    | LC_ALL=C sort -z > "$scratch/rp-std" || return 1
  git ls-files --others -z "${hash_excludes[@]}" -- . "${review_pathspec[@]}" \
    | LC_ALL=C sort -z > "$scratch/rp-proj" || return 1
  {
    cat "$scratch/rp-tracked"
    # 两边都允许的未跟踪文件
    LC_ALL=C comm -z -12 "$scratch/rp-std" "$scratch/rp-proj"
    # .claude/ 下的未跟踪文件只看规则甲
    while IFS= read -r -d '' p; do
      case "$p" in .claude/*) printf '%s\0' "$p" ;; esac
    done < "$scratch/rp-std"
  } | sort -zu
}

# build_manifest <清单输出文件> [内容快照目录]:生成所审改动的清单;给了快照目录时
# 同时把可保存的内容复制进去。清单首行是格式标记,第二行
# "head<TAB><sha><TAB><纳入口径摘要>"(摘要见 snapshot_scope);其后每行
#   <类型><TAB><可执行位><TAB><内容哈希或链接目标><TAB><内容可保存 1|0><TAB><路径>
# 类型 F = 普通文件、L = 符号链接、D = 已删除、O = 其它;按路径排序。路径与
# 链接目标一律经 enc_field 编码,链接目标按完整字节读取(含末尾换行)。
# 大小超过 snap_limit、不可读、或路径含制表符/换行/回车的文件不保存内容(第 4 列为 0)。
# 内容哈希对所有可读的普通文件都计算(含路径特殊的文件):内容一变,清单记录
# 必变,这类文件在轮间差异里会被保守地列为"未快照"。
# 复制完成后重算副本的哈希并与清单逐个比对:复制期间文件被改写(副本与清单
# 记录的内容不是同一版本)即失败,不会留下与清单不符的快照。
# 哈希与复制按批交给 sha1sum / cp(xargs),不为每个文件单独启动进程。
build_manifest() {
  local man=$1 snap=${2:-}
  local p type mode hash saved field rec size name rc head_sha scope copied
  local -a paths=() regular=() sizable=() keep=()
  local -A sizes=() hashes=() kept=()
  review_paths > "$scratch/paths" || return 1
  mapfile -d '' -t paths < "$scratch/paths"
  for p in "${paths[@]}"; do
    if [ ! -L "$p" ] && [ -f "$p" ]; then
      regular+=("$p")
      case "$p" in *$'\t'*|*$'\n'*|*$'\r'*) ;; *) sizable+=("$p") ;; esac
    fi
  done
  if [ "${#sizable[@]}" -gt 0 ]; then
    printf '%s\0' "${sizable[@]}" | xargs -0 -r stat --printf '%s\t%n\0' -- > "$scratch/sizes" || return 1
    while IFS=$'\t' read -r -d '' size name; do sizes["$name"]=$size; done < "$scratch/sizes"
  fi
  if [ "${#regular[@]}" -gt 0 ]; then
    rc=0
    printf './%s\0' "${regular[@]}" | xargs -0 -r sha1sum -z -- > "$scratch/hashes" 2>/dev/null || rc=$?
    case "$rc" in 0|123) ;; *) return 1 ;; esac
    while IFS= read -r -d '' rec; do hashes["${rec#*  ./}"]=${rec%%  *}; done < "$scratch/hashes"
  fi
  for p in "${sizable[@]}"; do
    if [ -r "$p" ] && [ -n "${hashes[$p]:-}" ] && [ "${sizes[$p]:-$((snap_limit + 1))}" -le "$snap_limit" ]; then
      keep+=("$p"); kept["$p"]=1
    fi
  done
  if [ -n "$snap" ] && [ "${#keep[@]}" -gt 0 ]; then
    printf '%s\0' "${keep[@]}" | xargs -0 -r cp --parents -p -t "$snap" -- || return 1
    ( cd "$snap" && printf './%s\0' "${keep[@]}" | xargs -0 -r sha1sum -z -- ) > "$scratch/snaphashes" 2>/dev/null \
      || return 1
    copied=0
    while IFS= read -r -d '' rec; do
      name=${rec#*  ./}
      if [ "${hashes[$name]:-}" != "${rec%%  *}" ]; then
        echo "内容快照与清单不一致:$name 在生成快照期间被改写" >&2; return 1
      fi
      copied=$((copied + 1))
    done < "$scratch/snaphashes"
    if [ "$copied" -ne "${#keep[@]}" ]; then
      echo "内容快照不完整:应保存 ${#keep[@]} 个文件,实际核对到 $copied 个" >&2; return 1
    fi
  fi
  head_sha=$(git rev-parse HEAD) || return 1
  scope=$(snapshot_scope) || return 1
  {
    printf '%s\n' "$manifest_magic"
    # head 行第三列是纳入口径的摘要。放在 head 行而不另起一行:1.5.0 的脚本把
    # head 行的内容整体与当前 HEAD 比对,读到新清单时对不上、自然回退全量评审;
    # 另起一行则会被它当成文件记录。
    printf 'head\t%s\t%s\n' "$head_sha" "$scope"
    for p in "${paths[@]}"; do
      enc_field "$p"; field=$REPLY; saved=0; mode=-; hash=-
      if [ -L "$p" ]; then
        type=L
        # 命令替换会剥掉末尾换行:追加哨兵字符再去掉,只删 readlink 自己加的那个换行
        hash=$(readlink -- "$p" && printf x) || return 1
        hash=${hash%x}; hash=${hash%$'\n'}
        enc_field "$hash"; hash=$REPLY
      elif [ ! -e "$p" ]; then
        type=D
      elif [ -f "$p" ]; then
        type=F
        if [ -x "$p" ]; then mode=x; fi
        hash=${hashes[$p]:-unreadable}
        saved=${kept[$p]:-0}
      else
        type=O
      fi
      printf '%s\t%s\t%s\t%s\t%s\n' "$type" "$mode" "$hash" "$saved" "$field"
    done
  } > "$man" || return 1
}

# write_snapshot <NN>:写本轮的清单 .review-raw-NN.manifest 与内容快照
# .review-raw-NN.snap/,并清理更早的快照目录。
write_snapshot() {
  local n=$1 man="$task_dir/.review-raw-$1.manifest" snap="$task_dir/.review-raw-$1.snap" d k
  if [ -e "$snap" ] && [ ! -d "$snap" ]; then
    echo "内容快照路径已被占用且不是目录:$task_rel/${snap##*/}" >&2; return 1
  fi
  rm -rf "$snap" "$man" || return 1
  mkdir -p "$snap" || return 1
  build_manifest "$man" "$snap" || return 1
  # 只保留最近两轮的内容快照
  for d in "$task_dir"/.review-raw-*.snap; do
    [ -d "$d" ] || continue
    k=${d##*/.review-raw-}; k=${k%.snap}
    [[ "$k" =~ ^[0-9]+$ ]] || continue
    if [ "$((10#$k))" -lt "$((10#$n - 1))" ]; then rm -rf "$d"; fi
  done
  return 0
}

# kind_label <类型> <链接目标>:轮间差异里对一侧文件类型的说明
kind_label() {
  case "$1" in
    file) echo 普通文件 ;;
    link) echo "符号链接(→ $2)" ;;
    absent) echo 不存在 ;;
    *) echo 其它类型 ;;
  esac
}

# round_delta <上一轮 NN> <本轮 NN>:比对两轮清单。stdout 输出变化文件列表
# (markdown 列表,每行一项;无变化时无输出),并把逐文件的 unified diff 写入
# .review-raw-<本轮>.delta.diff。某一轮"所审内容"的取法:
#   快照里有 → 快照副本;清单标为已删除,或清单没有它且 HEAD 中也没有 → 不存在;
#   清单没有它而 HEAD 中有(当时与 HEAD 相同)→ HEAD 版本;内容未保存(清单标为
#   未快照,或 HEAD 中的版本超过 snap_limit)→ 不出 diff。
# 存在性、文件类型、可执行位三项元数据对每个变化文件都独立判定并列出,与内容
# 是否可得无关:新增或删除空文件、只改可执行位、符号链接与普通文件互换都会列出
# (互换时普通文件一侧的内容照常出 diff);内容未保存的文件同样标明新增、删除或
# 可执行位变化,只是不出 diff。
# 列表与 diff 标签显示的是真实路径;路径含控制字符时显示编码形式并带标注
# (见 disp_field)。
round_delta() {
  local pn=$1 cn=$2
  local pman="$task_dir/.review-raw-$1.manifest" cman="$task_dir/.review-raw-$2.manifest"
  local psnap="$task_dir/.review-raw-$1.snap" csnap="$task_dir/.review-raw-$2.snap"
  local delta="$task_dir/.review-raw-$2.delta.diff"
  local type mode hash saved path key real name label pk ck pf cf drc i=0
  local pkind pmode phash psrc ckind cmode chash csrc
  local -A prec=() crec=() seen=()
  local -a keys=() list=() notes=()
  while IFS=$'\t' read -r type mode hash saved path; do
    case "$type" in head|rawf-manifest) continue ;; esac
    prec["$path"]="$type"$'\t'"$mode"$'\t'"$hash"$'\t'"$saved"; seen["$path"]=1
  done < "$pman"
  while IFS=$'\t' read -r type mode hash saved path; do
    case "$type" in head|rawf-manifest) continue ;; esac
    crec["$path"]="$type"$'\t'"$mode"$'\t'"$hash"$'\t'"$saved"; seen["$path"]=1
  done < "$cman"
  if [ "${#seen[@]}" -gt 0 ]; then
    mapfile -t keys < <(printf '%s\n' "${!seen[@]}" | LC_ALL=C sort)
  fi
  : > "$scratch/diffs"

  # side <清单记录或空> <真实路径>:取该轮"所审内容"的元数据,不取内容——
  #   sk  类型:file | absent | link | other
  #   sm  可执行位(x | -);sh  链接目标(编码后)
  #   sc  普通文件的内容来源:snap(该轮快照里有副本)| head(HEAD 中的版本)|
  #       none(内容未保存)
  local sk sm sh sc
  side() {
    local rec=$1 p=$2 t m h s hm
    sm=-; sh=-; sc=
    if [ -z "$rec" ]; then
      # 清单没有它:当时与 HEAD 相同,按 HEAD 中的类型取(不在 HEAD 中 = 不存在)。
      # 路径加 ./ 前缀:以 : 开头的文件名不会被当成 pathspec 魔法
      hm=$(git ls-tree HEAD -- "./$p" 2>/dev/null | awk '{ print $1; exit }')
      case "$hm" in
        '') sk=absent ;;
        120000)
          # blob 内容就是链接目标:按完整字节读取(哨兵防止末尾换行被剥掉),再编码
          sk=link
          sh=$(git show "HEAD:$p" && printf x) || return 1
          sh=${sh%x}; enc_field "$sh"; sh=$REPLY ;;
        100644|100755)
          sk=file
          if [ "$hm" = 100755 ]; then sm=x; fi
          # HEAD 中的版本同样受 snap_limit 约束:超过即内容未保存
          if [ "$(git cat-file -s "HEAD:$p" 2>/dev/null || echo 0)" -gt "$snap_limit" ]; then
            sc=none
          else
            sc=head
          fi ;;
        *) sk=other ;;
      esac
      return 0
    fi
    IFS=$'\t' read -r t m h s <<< "$rec"
    sm=$m; sh=$h
    case "$t" in
      D) sk=absent ;;
      L) sk=link ;;
      F) sk=file; if [ "$s" = 1 ]; then sc=snap; else sc=none; fi ;;
      *) sk=other ;;
    esac
  }

  for key in "${keys[@]}"; do
    pk=${prec[$key]:-}; ck=${crec[$key]:-}
    # 记录比较不含"内容可保存"一列
    [ "${pk%$'\t'*}" = "${ck%$'\t'*}" ] && continue
    i=$((i + 1))
    # 清单里的键是编码后的路径;取内容、查 HEAD 用解码后的真实路径
    dec_field "$key"; real=$REPLY
    case "$real" in
      *$'\t'*|*$'\n'*|*$'\r'*) label=$key; name="\`$key\`〔含控制字符,按 %XX 编码显示〕" ;;
      *) label=$real; name="\`$real\`" ;;
    esac
    side "$pk" "$real" || return 1
    pkind=$sk; pmode=$sm; phash=$sh; psrc=$sc
    side "$ck" "$real" || return 1
    ckind=$sk; cmode=$sm; chash=$sh; csrc=$sc
    # 清单说有副本而快照里找不到(快照被外力动过):按内容未保存处理,不中止
    if [ "$psrc" = snap ] && [ ! -f "$psnap/$real" ]; then psrc=none; fi
    if [ "$csrc" = snap ] && [ ! -f "$csnap/$real" ]; then csrc=none; fi
    # 路径含控制字符的文件一律不出 diff(无论内容来自快照还是 HEAD):diff 标签
    # 因此只会是真实路径,不会出现两个文件共用一个标签
    if [ "$label" != "$real" ]; then
      if [ "$pkind" = file ]; then psrc=none; fi
      if [ "$ckind" = file ]; then csrc=none; fi
    fi

    notes=()
    # 一、存在性与文件类型
    if [ "$pkind" = link ] && [ "$ckind" = link ]; then
      if [ "$phash" != "$chash" ]; then
        disp_field "$phash"; pf=$REPLY; disp_field "$chash"
        notes+=("元数据变化:符号链接目标 $pf → $REPLY")
      fi
    elif [ "$pkind" != "$ckind" ]; then
      case "$pkind>$ckind" in
        'absent>file') notes+=(新增) ;;
        'file>absent') notes+=(删除) ;;
        *)
          disp_field "$phash"; pf=$REPLY; disp_field "$chash"
          notes+=("类型变化:$(kind_label "$pkind" "$pf") → $(kind_label "$ckind" "$REPLY")") ;;
      esac
    fi
    # 二、可执行位(两侧都是普通文件时)
    if [ "$pkind" = file ] && [ "$ckind" = file ] && [ "$pmode" != "$cmode" ]; then
      notes+=("元数据变化:可执行位 $pmode → $cmode")
    fi
    # 三、内容:有一侧是普通文件就比内容,另一侧不是普通文件时按不存在处理;
    #     任一普通文件侧的内容未保存 → 不出 diff,只注明
    if [ "$pkind" = file ] || [ "$ckind" = file ]; then
      if { [ "$pkind" = file ] && [ "$psrc" = none ]; } || { [ "$ckind" = file ] && [ "$csrc" = none ]; }; then
        if [ "$ckind" = file ]; then
          notes+=("未快照:内容未保存,整份按本轮变化对待")
        else
          notes+=("未快照:原内容未保存,不出 diff")
        fi
      else
        pf=/dev/null; cf=/dev/null
        if [ "$pkind" = file ]; then
          if [ "$psrc" = snap ]; then pf="$psnap/$real"
          else pf="$scratch/head-p$i"; git show "HEAD:$real" > "$pf" || return 1; fi
        fi
        if [ "$ckind" = file ]; then
          if [ "$csrc" = snap ]; then cf="$csnap/$real"
          else cf="$scratch/head-c$i"; git show "HEAD:$real" > "$cf" || return 1; fi
        fi
        drc=0
        diff -u --label "上一轮/$label" --label "本轮/$label" "$pf" "$cf" >> "$scratch/diffs" || drc=$?
        [ "$drc" -le 1 ] || return 1
        if [ "$pkind" = file ] && [ "$ckind" = file ]; then
          if [ "$drc" -eq 1 ]; then notes+=(内容变化); fi
        elif [ "$drc" -eq 0 ]; then
          notes+=(空文件)
        fi
      fi
    fi
    [ "${#notes[@]}" -gt 0 ] || continue
    list+=("- $name($(IFS=';'; printf '%s' "${notes[*]}"))")
  done
  {
    printf '# 轮间差异:第 %s 轮所审内容 → 第 %s 轮所审内容\n\n' "$pn" "$cn"
    printf '路径按真实路径显示;含控制字符的路径以 %%XX 编码显示(%%09 制表符、%%0A 换行、%%0D 回车、%%25 百分号)并带标注。\n\n'
    printf '## 变化文件\n\n'
    if [ "${#list[@]}" -eq 0 ]; then echo "无"; else printf '%s\n' "${list[@]}"; fi
    printf '\n## diff\n\n'
    cat "$scratch/diffs"
  } > "$delta" || return 1
  [ "${#list[@]}" -eq 0 ] || printf '%s\n' "${list[@]}"
}

# --- 受管进程集合与终止 ---------------------------------------------------
# codex 经 setsid 启动,成为新会话与新进程组首进程;受管集合 = 同会话 ∪
# 同进程组 ∪ 自身。中间进程退出、后代改挂 init 后 sid/pgid 不变,仍能命中。
managed_pids() {
  { pgrep -s "$1" || true; pgrep -g "$1" || true; echo "$1"; } 2>/dev/null \
    | sort -un | while read -r p; do kill -0 "$p" 2>/dev/null && echo "$p" || true; done
}
# kill_codex_tree <sid>:TERM 整组 + 逐 pid,等至多 10 s;仍存活则 KILL 升级
# (按当时重新取得的集合),再等 3 s;残留只告警不阻断退出。
kill_codex_tree() {
  local sid=$1 p alive
  kill -TERM -- "-$sid" 2>/dev/null || true
  for p in $(managed_pids "$sid"); do kill -TERM "$p" 2>/dev/null || true; done
  for _ in $(seq 1 20); do
    alive=$(managed_pids "$sid"); [ -z "$alive" ] && return 0; sleep 0.5
  done
  kill -KILL -- "-$sid" 2>/dev/null || true
  for p in $(managed_pids "$sid"); do kill -KILL "$p" 2>/dev/null || true; done
  for _ in $(seq 1 6); do
    alive=$(managed_pids "$sid"); [ -z "$alive" ] && return 0; sleep 0.5
  done
  echo "警告:以下受管进程仍存活:$(echo "$alive" | tr '\n' ' ')" >&2
}

# lock_holders:只列真正持有 flock 的进程(pid 命令名)。判据是
# /proc/<pid>/fdinfo/<fd> 的 lock: 行(FLOCK + 锁文件 inode)——被继承的 fd
# 同样带该行,仅打开未持锁的 fd 没有;/proc/locks 里的 pid 是已退出的 flock
# 命令进程,不可用。调用前须先关闭本实例自己的锁 fd。
lock_holders() {
  local real ino fd pid
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

# frontmatter_field <plan.md> <字段名>:取 frontmatter(首个 --- 块)内行首
# "<字段名>:" 的值,去掉首尾空白。命中输出 "F=<值>"(值可为空串),未出现则无
# 输出——"F=" 前缀用来区分"字段出现但值为空"与"字段未出现"。
frontmatter_field() {
  awk -v key="$2:" '/^---[[:space:]]*$/ { n++; next }
       n == 1 && index($0, key) == 1 {
         v = substr($0, length(key) + 1)
         gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
         print "F=" v; exit }
       n >= 2 { exit }' "$1"
}

# resolve_model_args <plan.md> <模型字段> <强度字段>:把用户点名的评审模型与推理
# 强度转成 codex exec 的参数,写入全局数组 model_args;生效的指定记在 model_note,
# 启动 codex 前打印。字段未出现 → 不传对应参数,用 Codex 自身配置的默认值;两个
# 字段互相独立。与 plan-review.sh 的同名函数相同,那边读 plan_review_* 两个字段。
# 只校验形态(首字符限定同时避免值被 codex 当成命令行选项),不维护模型名与强度
# 的枚举:取值是否受支持由 Codex 判定,不支持时 codex exec 以非零退出,按下方
# "codex exec 执行失败"处理(exit 3、不发布、不消耗轮次)。字段只在用户明确点名
# 时写入(docs/decisions/t0016)。
model_args=(); model_note=
resolve_model_args() {
  local LC_ALL=C plan=$1 mkey=$2 ekey=$3 hit val
  model_args=(); model_note=
  hit=$(frontmatter_field "$plan" "$mkey") \
    || { echo "无法读取 plan.md 的 frontmatter;评审未启动、不消耗轮次" >&2; return 3; }
  if [ -n "$hit" ]; then
    val=${hit#F=}
    if ! [[ "$val" =~ ^[A-Za-z0-9][A-Za-z0-9._:/-]*$ ]]; then
      echo "plan.md 的 $mkey 非法(须为不带引号的模型名:以字母或数字开头,只含字母、数字与 . _ : / -;实际为:${val:-空});评审未启动、不消耗轮次" >&2
      return 3
    fi
    model_args+=(-m "$val"); model_note="$mkey=$val"
  fi
  hit=$(frontmatter_field "$plan" "$ekey") \
    || { echo "无法读取 plan.md 的 frontmatter;评审未启动、不消耗轮次" >&2; return 3; }
  if [ -n "$hit" ]; then
    val=${hit#F=}
    if ! [[ "$val" =~ ^[a-z]+$ ]]; then
      echo "plan.md 的 $ekey 非法(须为不带引号的小写字母,如 low、medium、high;实际为:${val:-空});评审未启动、不消耗轮次" >&2
      return 3
    fi
    model_args+=(-c "model_reasoning_effort=\"$val\""); model_note="${model_note:+$model_note,}$ekey=$val"
  fi
  return 0
}

# --- 主流程 ---------------------------------------------------------------
# 退出码 1 只有一个含义:已发布一份 fail 评审。脚本在 set -e 下运行,任何未被
# 显式处理的命令失败都会让它以该命令的退出码(常常就是 1)结束——那不是评审
# 结论。没有发布评审文件却以 1 结束时,一律改为 3(执行异常)。这道总闸在主流程
# 的第一步注册,覆盖进入项目目录、取锁等启动阶段的命令。
codex_pid=
scratch=
published=0
cleanup() {
  local rc=$?
  [ -n "$codex_pid" ] && kill_codex_tree "$codex_pid"
  [ -n "$scratch" ] && rm -rf "$scratch"
  if [ "$rc" -eq 1 ] && [ "$published" != 1 ]; then
    echo "review.sh 中途异常中止,未发布评审文件;按评审执行异常处理(exit 3),排查上方报错后重跑" >&2
    exit 3
  fi
  return 0
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

for tool in flock setsid pgrep; do
  command -v "$tool" >/dev/null \
    || { echo "需要 util-linux(flock、setsid)与 procps(pgrep):缺少 $tool" >&2; exit 3; }
done
for tool in sha1sum comm xargs diff cmp; do
  command -v "$tool" >/dev/null \
    || { echo "需要 coreutils(sha1sum、comm)、findutils(xargs)与 diffutils(diff、cmp):缺少 $tool" >&2; exit 3; }
done
command -v codex >/dev/null || { echo "codex CLI 未安装或不在 PATH" >&2; exit 3; }

idle_limit=${RAWF_REVIEW_IDLE_SECONDS:-900}
max_limit=${RAWF_REVIEW_MAX_SECONDS:-3600}
poll=${RAWF_REVIEW_POLL_SECONDS:-5}
positive_int RAWF_REVIEW_IDLE_SECONDS "$idle_limit" || exit 3
positive_int RAWF_REVIEW_MAX_SECONDS "$max_limit" || exit 3
positive_int RAWF_REVIEW_POLL_SECONDS "$poll" || exit 3

proj="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}" \
  || { echo "无法定位项目根(CLAUDE_PROJECT_DIR 未设置,当前目录也不在 git 仓库内)" >&2; exit 3; }
cd "$proj" 2>/dev/null || { echo "无法进入项目目录:$proj" >&2; exit 3; }

task_rel=$(cat .ai/.current-task 2>/dev/null) || { echo "无进行中任务(.ai/.current-task 不存在)" >&2; exit 3; }
task_dir="$proj/$task_rel"
[ -d "$task_dir" ] || { echo "任务目录不存在:$task_rel" >&2; exit 3; }

# 同轮唯一性由 flock 保证:fd 9 在脚本整个生命周期持有,"检查-评审-发布"
# 全程互斥;持有进程(含继承 fd 的 codex)全部退出即自动释放,没有残留态。
# 锁文件常驻、永不删除(删除-重建会让两个打开者持有不同 inode 的锁)。
lock="$task_dir/.review-lock"
if [ -d "$lock" ]; then
  echo "检测到旧版锁目录 $task_rel/.review-lock(升级前残留);确认 pgrep -f 'codex exec' 无旧评审进程后执行 rmdir 该目录再重跑" >&2
  exit 3
fi
if ! { true 9>>"$lock"; } 2>/dev/null; then
  echo "无法打开锁文件 $task_rel/.review-lock" >&2; exit 3
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
      if { tr '\0' ' ' < "/proc/$hp/cmdline"; } 2>/dev/null | grep -q 'review.sh'; then script_alive=1; fi
    done
    # 快照可能过期(扫描期间评审刚结束):输出前复核锁仍被持有、名单仍存活
    recheck=0
    flock -n -E 75 "$lock" true 2>/dev/null || recheck=$?
    if [ "$recheck" -eq 0 ]; then
      echo "评审刚结束,锁 $task_rel/.review-lock 已释放;请重跑" >&2
      exit 3
    fi
    alive=$(echo "$holders" | while read -r hp hc; do
      [ -n "$hp" ] && kill -0 "$hp" 2>/dev/null && echo "$hp $hc" || true; done)
    {
      echo "已有评审在进行中,锁 $task_rel/.review-lock 被以下进程持有:"
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

# nullglob 数组计数:无匹配为 0,避免 ls 管道在 set -e/pipefail 下以
# 非预期退出码崩溃(会与"评审结论 fail"的退出码 1 冲突)
shopt -s nullglob
rounds=("$task_dir"/implementation-round-*.md)
shopt -u nullglob   # 立即关闭:后续 review-round 存在性 glob 依赖非空语义
count=${#rounds[@]}
[ "$count" -gt 0 ] || { echo "尚无实现记录,先完成 /rawf-implement" >&2; exit 3; }
nn=$(printf '%02d' "$count")

# 同一轮只评一次:.ai/ 历史只增不改
if ls "$task_dir"/review-round-"$nn"-*.md >/dev/null 2>&1; then
  echo "第 $nn 轮已有评审文件,按'历史只增不改'拒绝重评;确需重评请用户手动处置旧文件后重跑" >&2
  exit 3
fi

# 证据机器核验(docs/decisions/t0010、t0015):证据由机器判定,评审者不核——
# 记录与 plan 用例表的对应、每条用例结果为 pass、A 档证据结构完整且归属本用例、
# 退出码为 0、B/C 档证据栏非空。任一不满足即不送评审,由脚本直接开出补交
# 清单,不消耗 codex 评审轮次;通过的报告注入 prompt,仅供评审者了解哪些用例
# 已留证。
# stdout(报告表)与 stderr(补交清单 / 错误诊断)按产生顺序合并捕获:
# 通过时 stderr 为空,注入 prompt 的就是纯报告;失败时整段原样转 stderr
ev_rc=0
ev_report=$(bash "$proj/.ai-workflow/scripts/evidence-check.sh" "$nn" 2>&1) || ev_rc=$?
case "$ev_rc" in
  0) ;;
  1)
    { echo "证据核验未通过(evidence-check),评审未启动;按补交清单补齐证据或修正实现记录后重跑 review.sh(当前轮尚未评审,不开新轮):"; echo "$ev_report"; } >&2
    exit 3 ;;
  *) echo "evidence-check 执行异常(退出码 $ev_rc):$ev_report" >&2; exit 3 ;;
esac

# 评审模型:在生成本轮任何产物之前解析,写法不对就不启动(plan.md 已由上面的
# 证据核验确认存在)
resolve_model_args "$task_dir/plan.md" impl_review_model impl_review_effort || exit 3

# 报告每条用例一行,用例很多时会很长:超过 inline_budget 就落盘(文件名命中
# .review-raw-* 的忽略与指纹排除模式),指令里只留路径与结论行
ev_inline=$ev_report
ev_file="$task_dir/.review-raw-$nn.evidence.md"
if [ "$(printf '%s' "$ev_report" | wc -c)" -gt "$inline_budget" ]; then
  # 只有需要落盘时才要求这个路径可用:先清掉同轮上一次留下的,清不掉(被目录
  # 占用、无权限)或写不进去都按执行异常处理
  if [ -e "$ev_file" ] || [ -L "$ev_file" ]; then
    rm -f "$ev_file" 2>/dev/null \
      || { echo "无法清理证据核验报告的落盘路径 $task_rel/${ev_file##*/}(被目录占用或无权限);处置后重跑" >&2; exit 3; }
  fi
  printf '%s\n' "$ev_report" > "$ev_file" \
    || { echo "无法写出证据核验报告 $task_rel/${ev_file##*/}" >&2; exit 3; }
  ev_inline="(证据核验报告较长,未内联;全文见 $task_rel/${ev_file##*/}。$(printf '%s\n' "$ev_report" | { grep '^结论:' || true; } | tail -n 1))"
elif [ -f "$ev_file" ] && [ ! -L "$ev_file" ]; then
  # 报告已内联:同轮上一次留下的落盘文件不再被引用,顺手清掉;清不掉不影响评审
  rm -f "$ev_file" 2>/dev/null || true
fi

# 本轮所审改动的清单与内容快照;第 02 轮起据此生成轮间差异。临时文件放项目外
# (不计入指纹),随脚本退出清理。
scratch=$(mktemp -d) || { echo "无法创建临时目录" >&2; exit 3; }
write_snapshot "$nn" \
  || { echo "本轮清单或内容快照生成失败,评审未启动、不消耗轮次;排查上方报错后重跑" >&2; exit 3; }

# build_round_context:生成 {{ROUND_CONTEXT}}。首行固定为"本轮模式:…"。
# 第 01 轮全量评审;第 02 轮起,上一轮的评审文件、清单、内容快照都在,HEAD 未变
# 且两轮清单的纳入口径相同 → 修复核验(附变化文件列表与轮间差异文件路径),
# 否则回退为全量评审。每一轮的上下文末尾都给出本轮清单的路径。
build_round_context() {
  local n=$((10#$nn)) prev prev_man prev_snap prev_review='' f why='' cur_head list shown total kept
  local prev_head='' prev_scope='' cur_scope
  # manifest_note:每一轮(含全量评审)都给出本轮清单的路径——评审对象以它为准,
  # 全量评审的取材范围、修复核验的变化文件列表、送审前后的一致性比对用的是
  # 同一份清单
  manifest_note() {
    printf '\n\n本轮所审改动的文件清单:%s/.review-raw-%s.manifest(每行最后一列是路径;路径里的 %%、制表符、换行、回车分别写作 %%25、%%09、%%0A、%%0D)。评审对象以它为准:工作区里不在清单中的未跟踪文件——被 .gitignore 忽略的,或项目登记在排除清单里的构建、运行期产物——不属于评审对象。' \
      "$task_rel" "$nn"
  }
  if [ "$n" -eq 1 ]; then
    printf '本轮模式:全量评审\n\n本轮为第 01 轮(首轮)。'
    manifest_note
    return 0
  fi
  prev=$(printf '%02d' "$((n - 1))")
  prev_man="$task_dir/.review-raw-$prev.manifest"
  prev_snap="$task_dir/.review-raw-$prev.snap"
  for f in "$task_dir"/review-round-"$prev"-*.md; do
    [ -f "$f" ] && { prev_review=${f##*/}; break; }
  done
  cur_head=$(git rev-parse HEAD) || return 1
  cur_scope=$(snapshot_scope) || return 1
  if [ -f "$prev_man" ]; then
    # head 行:head<TAB><sha>[<TAB><纳入口径摘要>];1.5.0 写出的清单没有第三列
    IFS=$'\t' read -r _ prev_head prev_scope < <(grep -m 1 $'^head\t' "$prev_man") || true
  fi
  if [ -z "$prev_review" ]; then why="未找到第 $prev 轮评审文件"
  elif [ ! -f "$prev_man" ]; then why="无上一轮清单"
  elif [ ! -d "$prev_snap" ]; then why="无上一轮内容快照"
  elif ! manifest_readable "$prev_man"; then why="上一轮清单是旧格式,无法按当前格式解读"
  elif [ "$prev_head" != "$cur_head" ]; then why="HEAD 自上一轮评审以来已变化"
  elif [ "$prev_scope" != "$cur_scope" ]; then why="两轮清单的纳入口径不同(排除清单有变化,或上一轮清单由旧版脚本生成)"
  fi
  if [ -n "$why" ]; then
    printf '本轮模式:全量评审(%s,无法给出轮间差异)\n\n本轮为第 %s 轮。' "$why" "$nn"
    if [ -n "$prev_review" ]; then
      printf '上一轮评审:%s/%s——其中的阻断问题须逐项核验是否已解决。' "$task_rel" "$prev_review"
    fi
    manifest_note
    return 0
  fi
  list=$(round_delta "$prev" "$nn") || return 1
  # 指令经命令行参数传入,单个参数的长度有上限(Linux 约 128 KiB):变化文件列表
  # 按字节数截断(与条数、路径长短无关),完整列表在轮间差异文件的「变化文件」节
  total=$(grep -c . <<< "$list" || true)
  shown=$(LC_ALL=C awk -v max="$inline_budget" '{ n += length($0) + 1; if (n > max) exit; print }' <<< "$list")
  kept=$(grep -c . <<< "$shown" || true)
  if [ "$kept" -lt "$total" ]; then
    list="$shown"$'\n'"(共 $total 项,此处只列前 $kept 项;完整列表见下方轮间差异文件的「变化文件」节)"
  fi
  printf '本轮模式:修复核验\n\n本轮为第 %s 轮。上一轮评审:%s/%s——先逐项核验其中的阻断问题是否已解决。\n\n' \
    "$nn" "$task_rel" "$prev_review"
  printf '自上一轮评审以来的变化文件(机器比对两轮清单):\n\n%s\n\n' "${list:-无}"
  printf '轮间差异(上一轮所审内容 → 本轮所审内容的 unified diff,即"本轮变化"):%s/.review-raw-%s.delta.diff' \
    "$task_rel" "$nn"
  manifest_note
}
round_context=$(build_round_context) \
  || { echo "轮次上下文或轮间差异生成失败,评审未启动、不消耗轮次;排查上方报错后重跑" >&2; exit 3; }

# bash 5.2 起 patsub_replacement 默认开启:替换文本里的 & 会被换成匹配原文、\& 丢
# 反斜杠,证据报告(B/C 档证据格原文、%q 转义的 cmd)会被改写。关闭后再做占位
# 替换(与 plan-review.sh 同一处理,见 docs/decisions/t0012)。ROUND_CONTEXT 与
# EVIDENCE_REPORT 最后替换,其内容里出现的占位字样不会被二次展开。
shopt -u patsub_replacement 2>/dev/null || true
prompt=$(cat .ai-workflow/prompts/review.md)
prompt="${prompt//\{\{TASK_DIR\}\}/$task_rel}"
prompt="${prompt//\{\{ROUND\}\}/$nn}"
prompt="${prompt//\{\{ROUND_CONTEXT\}\}/$round_context}"
prompt="${prompt//\{\{EVIDENCE_REPORT\}\}/$ev_inline}"
# 总量兜底:两块可变长内容都已限长,正常情况下远低于上限;模板被大幅改写等
# 情况下给出明确报错,而不是让 codex 启动时以 Argument list too long 失败
prompt_bytes=$(printf '%s' "$prompt" | wc -c)
if [ "$prompt_bytes" -gt "$prompt_limit" ]; then
  echo "评审指令长 $prompt_bytes 字节,超过上限 $prompt_limit(指令经单个命令行参数传入,系统上限约 128 KiB);评审未启动、不消耗轮次。请精简 .ai-workflow/prompts/review.md" >&2
  exit 3
fi

# 送审前复核:工作区须仍与本轮清单一致(快照生成之后到这一刻没有被改动)。
# 评审结束后还会再核一次,见下方"所审内容一致性"。
build_manifest "$scratch/manifest.pre" \
  || { echo "送审前清单重算失败,评审未启动、不消耗轮次;排查上方报错后重跑" >&2; exit 3; }
if ! cmp -s "$scratch/manifest.pre" "$task_dir/.review-raw-$nn.manifest"; then
  echo "所审改动在本轮快照生成之后、送审之前发生了变化,评审未启动、不消耗轮次。请确认工作区不再变动后重跑。" >&2
  exit 3
fi

pre_hash=$(workspace_hash) \
  || { echo "工作区指纹计算失败(评审前),评审未启动;排查上方报错后重跑" >&2; exit 3; }

# 原始输出直接落任务目录(已由 .gitignore 忽略、hash_excludes 排除),
# 由 codex CLI 进程自身写入,不经受沙箱约束(沙箱只管模型生成的 shell
# 命令);非法/异常时原地保留供排查,无需任何回搬逻辑。
# 事件流(--json)同样落任务目录,文件名命中 .review-raw-* 模式。
raw_name=".review-raw-$nn.json"
raw="$task_dir/$raw_name"
events="$task_dir/.review-raw-$nn.events.jsonl"
rm -f "$raw" "$events"   # 清除历史遗留输出,防陈旧结论被误用

# model_args 为空(字段都没写)时,下面的参数序列与 1.5.x 逐项相同
[ -z "$model_note" ] || echo "评审模型按 plan.md frontmatter 的指定:$model_note" >&2
setsid codex exec "${model_args[@]}" --json --sandbox read-only -C "$proj" \
  --output-schema "$proj/.ai-workflow/schemas/review.schema.json" \
  --output-last-message "$raw" "$prompt" </dev/null >"$events" &
codex_pid=$!
# 子进程要先执行到 setsid(2) 才成为会话首进程,最多等 2 s;已退出(极快完成)
# 则无需受管,直接放过。
sid_ok=0
for _ in $(seq 1 20); do
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

# 双保险:主工作区必须分毫未动(只读沙箱生效且无并发写入时恒真)
post_hash=$(workspace_hash) \
  || { echo "工作区指纹计算失败(评审后),无法确认主工作区未被改动,本次评审无效;排查上方报错后重跑" >&2; exit 3; }
if [ "$pre_hash" != "$post_hash" ]; then
  echo "主工作区在评审期间发生改动(沙箱未能阻止,或存在并发写入),本次评审无效。请 git status 检查后重跑。" >&2
  exit 3
fi

# 所审内容一致性:评审结束后按同一口径重算清单,必须与评审前保存的清单逐字节
# 相同(同一个 HEAD、同一批文件、同样的类型/可执行位/内容哈希)。它把本轮的
# 快照、轮间差异与即将发布的结论绑定到同一个工作区状态,补上指纹覆盖不到的
# 两处:快照生成到指纹首次计算之间的窗口,以及指纹排除掉的 .claude/ 下的
# skill 与 hook(它们属于评审对象,计入清单)。
build_manifest "$scratch/manifest.post" \
  || { echo "评审后清单重算失败,无法确认所审内容未变,本次评审无效;排查上方报错后重跑" >&2; exit 3; }
if ! cmp -s "$scratch/manifest.post" "$task_dir/.review-raw-$nn.manifest"; then
  echo "所审改动在本轮快照生成之后发生了变化(HEAD、文件内容、类型或可执行位;含 .claude/ 下的 skill 与 hook),本次评审无效、未发布评审文件。请确认工作区不再变动后重跑。" >&2
  exit 3
fi

if [ "$codex_rc" -ne 0 ]; then
  echo "codex exec 执行失败(退出码 $codex_rc),评审未完成;检查 codex login/额度/网络后重跑" >&2
  exit 3
fi

if [ ! -f "$raw" ]; then
  echo "codex 退出 0 但未产出评审输出文件,评审未完成;请重跑评审" >&2
  exit 3
fi

# 结构化解析:输入校验 → 路径归类 → 按判定规则推导结论。
# 结论是评审输出与路径清单的纯函数,评审者不自报;结构不合法的输出一律不发布。
if ! jq -e . "$raw" >/dev/null 2>&1; then
  echo "评审输出不是合法 JSON,原始输出保留在 $task_rel/$raw_name" >&2
  exit 3
fi
if ! validate_review_json "$raw"; then
  echo "评审输出结构不合法(缺字段、字段类型错误或严重度取值非法),未发布评审文件,原始输出保留在 $task_rel/$raw_name;请重跑评审" >&2
  exit 3
fi
classes=$(issue_classes "$raw") \
  || { echo "问题路径归类失败,原始输出保留在 $task_rel/$raw_name" >&2; exit 3; }
verdict=$(derive_verdict "$raw" "$classes") || verdict=
case "$verdict" in
  pass|fail) ;;
  *)
    echo "结论推导失败,原始输出保留在 $task_rel/$raw_name" >&2
    exit 3 ;;
esac

# 原子发布:先在同目录(同文件系统)写全临时文件,mv -n 原子改名发布;
# 渲染中途失败只污染临时文件(随即清理),不会留下半成品结论、不阻断重试。
final="$task_dir/review-round-$nn-$verdict.md"
tmp_out="$task_dir/.review-out-$nn.$$"
if ! render_review "$raw" "$nn" "$classes" > "$tmp_out"; then
  rm -f "$tmp_out"
  echo "渲染评审文件失败" >&2
  exit 3
fi
if ! mv -n "$tmp_out" "$final" || [ -e "$tmp_out" ]; then
  rm -f "$tmp_out"
  echo "评审结论已被并发发布($final 已存在),本次结果未覆盖" >&2
  exit 3
fi
published=1
echo "review-round-$nn-$verdict.md"
[ "$verdict" = "pass" ]
