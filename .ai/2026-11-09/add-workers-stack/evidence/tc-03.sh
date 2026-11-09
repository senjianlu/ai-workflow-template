# TC-03:review-standards.md 的 Cloudflare Workers 评审关注点
set -u
E=.ai/2026-11-09/add-workers-stack/evidence
. "$E/lib.sh"
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
awk '/^- Cloudflare Workers:/{f=1; print; next} f&&/^- /{exit} f' .ai-workflow/review-standards.md > "$w/e.txt"
cat "$w/e.txt"
[ -s "$w/e.txt" ] || miss "entry: - Cloudflare Workers: 不存在"
need "$w/e.txt" 关注点 Promise waitUntil 模块级 缓冲 RPC timingSafeEqual passThroughOnException Cron 真网
finish
