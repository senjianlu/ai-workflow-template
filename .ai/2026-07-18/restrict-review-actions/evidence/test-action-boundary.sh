#!/usr/bin/env bash
# restrict-review-actions 自测:TC-01~TC-07(全部为静态文本断言)。
# 仓库根解析:$1 显式传参 > git -C <脚本所在目录> 的仓库根。
set -u
proj="${1:-$(git -C "$(cd "$(dirname "$0")" && pwd)" rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$proj" ] && [ -d "$proj/.ai-workflow" ] \
  || { echo "无法定位仓库根(可显式传参:$0 <repo-root>)" >&2; exit 2; }
echo "REPO: $proj"
std="$proj/.ai-workflow/review-standards.md"
prm="$proj/.ai-workflow/prompts/review.md"
imp="$proj/.claude/skills/rawf-implement/SKILL.md"
dec="$proj/docs/decisions/0004-review-action-boundary.md"
pass=0; fail=0

check() { # check <tc> <desc> <0|1 实际是否命中> (期望恒为命中)
  if [ "$3" -eq 0 ]; then
    echo "PASS $1 $2"; pass=$((pass+1))
  else
    echo "FAIL $1 $2"; fail=$((fail+1))
  fi
}
# has <file> <pattern...>:所有 pattern 均须在压平(去换行与空格)后命中
has() {
  local f=$1; shift
  local flat; flat=$(tr -d '\n ' < "$f")
  local p
  for p in "$@"; do
    printf '%s' "$flat" | grep -q "$(printf '%s' "$p" | tr -d ' ')" || return 1
  done
  return 0
}

# ---- TC-01 review-standards.md:边界小节 + 允许/禁止清单
has "$std" "## 评审动作边界" "自终止" "类型检查" "单元测试子集" \
  "安装或更新依赖" "构建" "启动任何服务器或长驻进程" "E2E" "访问网络"
check TC-01 "边界小节与允许/禁止清单齐备" $?

# ---- TC-02 prompts/review.md:旧表述消失,新表述引用边界并保留 blocker
old_gone=1
grep -q "请实际运行 plan.md 中的测试用例" "$prm" || old_gone=0
check TC-02a "旧表述'请实际运行 plan.md 中的测试用例'已消失" "$old_gone"
has "$prm" "评审动作边界" "虚报的测试结果按 blocker 处理"
check TC-02b "新表述引用动作边界且保留虚报按 blocker" $?

# ---- TC-03 两文件均有"边界外靠 evidence/ 证据核验"的兜底
has "$std" "边界外的测试用例" "evidence/" "完整原始输出" && \
  has "$prm" "边界外的用例" "evidence/"
check TC-03 "边界外用例的证据核验兜底表述存在于两文件" $?

# ---- TC-04 契约闭环:实现者强制留证,评审者不重跑;旧'评审者会重跑验证'消失
has "$imp" "完整原始输出必须" "evidence/" "评审者不重跑这类用例"
check TC-04a "实现者侧边界外用例证据契约存在" $?
old_gone=1
tr -d '\n ' < "$imp" | grep -q "评审者会重跑验证" || old_gone=0
check TC-04b "旧表述'评审者会重跑验证'已更新" "$old_gone"
has "$imp" "动作边界" && has "$std" "证据缺失或与实现记录矛盾"
check TC-04c "实现者留证↔评审者审证语义呼应" $?

# ---- TC-05 按性质判定 + 三条性质 + 超时 + 混合套件
has "$std" "按命令性质判定" "不以运行器名称" \
  "自终止、不启动服务或长驻进程、不访问网络" \
  "默认 5 分钟" "超时即中止" "只运行可明确限定的单元子集"
check TC-05 "按性质判定/三性质/超时中止/混合套件规则齐备" $?

# ---- TC-06 全仓残留:与新边界矛盾的"实际运行测试"类表述为零
resid=$(grep -rn "实际运行 plan.md 中的测试用例" "$proj" \
  --exclude-dir=.ai --exclude-dir=.git --exclude-dir=node_modules 2>/dev/null \
  | grep -v "docs/decisions/" || true)
[ -z "$resid" ]; check TC-06 "全仓无矛盾残留(排除 .ai/、docs/decisions 沿革)" $?
[ -n "$resid" ] && echo "  resid: $resid"

# ---- TC-07 决策文件 0004 完整性
[ -f "$dec" ] && has "$dec" "背景" "决定" "被否掉的备选" "read-only" "兜底" "证据契约" "影响"
check TC-07 "0004 决策文件存在且四段齐备(含被否备选与证据契约)" $?

echo; echo "RESULT: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
