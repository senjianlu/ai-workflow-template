# TC-08:形态约定与对外契约文档三层
set -u
E=.ai/2026-11-09/add-workers-stack/evidence
. "$E/lib.sh"
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
worker_section AGENTS.md "$w/sec.txt"
need "$w/sec.txt" 完整节 docs/decisions/0013
# 表后正文:标准表之后首个空行起
awk '/^\| 类别 \| 技术 \| 版本 \|$/{t=1} t&&/^$/{a=1} a' "$w/sec.txt" > "$w/after.txt"
cat "$w/after.txt"
[ -s "$w/after.txt" ] || miss "after: 表后正文为空"
need "$w/after.txt" 约定1 index.ts 不放辅助方法 app.ts 组合根
need "$w/after.txt" 约定2 平铺 每个外部协议一个目录 三个文件成目录
need "$w/after.txt" 约定3 依赖注入 真网
need "$w/after.txt" 约定4 单环境 可重建 preview production 顶层配置仅供本地 --env decisions
need "$w/after.txt" 文档1 docs/architecture/ overview 契约 'RPC 方法表' 'HTTP 接口表' deploy 'Cron / HTTP / RPC'
need "$w/after.txt" 文档2 公网 HTML /llms.txt /reference.json /openapi.json 同一份契约 版本 更新日期 ASSETS
need "$w/after.txt" 文档3 'RPC 调用方' '`index.ts` 导出的类型' 'wrangler types' 双方 不另做公网文档
finish
