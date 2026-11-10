# 断言脚本公共函数:从仓库根运行;任何断言失败 → exit 1
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
FAILS=0
ok()   { printf 'PASS  %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
has()  { grep -qF -- "$2" "$1"; }                 # has <file> <固定串>
finish() { echo "---"; echo "失败断言数:$FAILS"; [ "$FAILS" -eq 0 ]; exit $?; }
