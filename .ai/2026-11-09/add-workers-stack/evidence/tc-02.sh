# TC-02:「应用内」表四列一致 + Worker 列逐行内容
set -u
E=.ai/2026-11-09/add-workers-stack/evidence
. "$E/lib.sh"
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
awk '/^\| 位置 \|/{f=1} f&&/^$/{exit} f' AGENTS.md > "$w/t.txt"
cat "$w/t.txt"
[ -s "$w/t.txt" ] || miss "table: 应用内表不存在"
head -1 "$w/t.txt" | grep -F -q 'Worker 应用' || miss "header: Worker 应用"
counts=$(awk '{print gsub(/\|/,"|")}' "$w/t.txt" | sort -u | tr '\n' ' ')
[ "$counts" = "5 " ] || miss "columns: 每行竖线数 [$counts],应全为 5(四列)"
col() { awk -F'|' -v k=" $1 " '$2==k{print $5}' "$w/t.txt"; }
chk() { local c; c=$(col "$1"); shift; local k; for k in "$@"; do grep -F -q -- "$k" <<<"$c" || miss "Worker 列: $k"; done; }
chk 源码 index.ts app.ts config.ts http.ts 每个外部协议一个目录 三个文件
chk 单元测试 test/ test/fixtures/
chk 端到端 '.ai/<任务>/assets/'
chk 数据迁移 migrations/ '有 D1 时'
chk '静态资源 / 国际化' public/ ASSETS
chk 应用配置 wrangler.jsonc pnpm-workspace.yaml .dev.vars.example
finish
