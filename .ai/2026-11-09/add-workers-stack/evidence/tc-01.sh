# TC-01:AGENTS.md「技术栈 > Cloudflare Worker」标准表逐行断言 + 节位置
set -u
E=.ai/2026-11-09/add-workers-stack/evidence
. "$E/lib.sh"
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
check_tc01 AGENTS.md "$w"
echo "--- 标准表 ---"; cat "$w/table.txt"
finish
