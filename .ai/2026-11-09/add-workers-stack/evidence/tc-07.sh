# TC-07:反向对照——对改动前 AGENTS.md(HEAD)执行 TC-01 同款断言,须失败
set -u
E=.ai/2026-11-09/add-workers-stack/evidence
. "$E/lib.sh"
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
git show HEAD:AGENTS.md > "$w/AGENTS.head.md"
check_tc01 "$w/AGENTS.head.md" "$w"
echo "inner FAILS=$FAILS"
if [ "$FAILS" -gt 0 ]; then echo "OK: TC-01 断言对改动前版本失败(非恒真)"; exit 0; fi
echo "TC-01 断言对改动前版本竟然通过"; exit 1
