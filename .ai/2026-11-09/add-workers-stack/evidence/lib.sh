# 断言辅助(工作目录为仓库根)。miss 打印 MISS 并记失败;finish 按失败数退出。
FAILS=0
miss() { echo "MISS: $*"; FAILS=$((FAILS + 1)); }
# need <文本文件> <标签> <关键词...>:逐词 grep -F
need() {
  local f=$1 tag=$2; shift 2
  local kw
  for kw in "$@"; do grep -F -q -- "$kw" "$f" || miss "$tag: $kw"; done
}
# row <表文本文件> <首列> :输出首列为该值的整行
row() { grep -F -- "| $2 |" "$1" | head -1; }
finish() { if [ "$FAILS" -eq 0 ]; then echo OK; exit 0; else echo "FAILS=$FAILS"; exit 1; fi; }
# worker_section <AGENTS.md 路径> <输出文件>:### Cloudflare Worker 到 ### 部署(不含)
worker_section() { awk '/^### Cloudflare Worker$/{f=1} /^### 部署$/{f=0} f' "$1" > "$2"; }
# check_tc01 <AGENTS.md 路径> <工作目录>:TC-01 的全部断言(TC-07 复用)
check_tc01() {
  local src=$1 w=$2
  worker_section "$src" "$w/sec.txt"
  [ -s "$w/sec.txt" ] || miss "section: ### Cloudflare Worker 不存在"
  # 节位置:紧随 ### 爬虫 之后、### 部署 之前
  local order
  order=$(grep -E '^### ' "$src" | grep -A1 -B1 -x '### Cloudflare Worker' | tr '\n' ',')
  [ "$order" = "### 爬虫,### Cloudflare Worker,### 部署," ] || miss "position: [$order]"
  # 标准表:表头至首个空行
  awk '/^\| 类别 \| 技术 \| 版本 \|$/{f=1} f&&/^$/{exit} f' "$w/sec.txt" > "$w/table.txt"
  [ -s "$w/table.txt" ] || miss "table: 标准表不存在"
  local bad
  bad=$(awk '{n=gsub(/\|/,"|"); if (n!=4) print NR": "n}' "$w/table.txt")
  [ -z "$bad" ] || miss "table: 非三列行 $bad"
  local r
  r=$(row "$w/table.txt" 运行时);       for k in compatibility_date nodejs_compat 默认不开; do grep -F -q -- "$k" <<<"$r" || miss "运行时: $k"; done
  r=$(row "$w/table.txt" 语言);         for k in strict noUncheckedIndexedAccess 5.x; do grep -F -q -- "$k" <<<"$r" || miss "语言: $k"; done
  r=$(row "$w/table.txt" 入口);         for k in WorkerEntrypoint fetch scheduled 'Service Binding RPC'; do grep -F -q -- "$k" <<<"$r" || miss "入口: $k"; done
  r=$(row "$w/table.txt" 数据);         for k in D1 按需 migrations/ 无状态; do grep -F -q -- "$k" <<<"$r" || miss "数据: $k"; done
  r=$(row "$w/table.txt" 出站);         for k in '原生 fetch'; do grep -F -q -- "$k" <<<"$r" || miss "出站: $k"; done
  r=$(row "$w/table.txt" '部署 CLI');   for k in wrangler 成对钉版本 4.x; do grep -F -q -- "$k" <<<"$r" || miss "部署 CLI: $k"; done
  r=$(row "$w/table.txt" 测试);         for k in @cloudflare/vitest-plugin '同 isolate' '5.x / 1.x'; do grep -F -q -- "$k" <<<"$r" || miss "测试: $k"; done
  r=$(row "$w/table.txt" 'Lint / 格式化'); for k in typescript-eslint 类型感知 Prettier '9.x / 8.x / 3.x'; do grep -F -q -- "$k" <<<"$r" || miss "Lint: $k"; done
  r=$(row "$w/table.txt" 包管理);       for k in pnpm 白名单 11.x; do grep -F -q -- "$k" <<<"$r" || miss "包管理: $k"; done
  r=$(row "$w/table.txt" 配置与密钥);   for k in wrangler.jsonc 'wrangler types' .dev.vars.example 'wrangler secret' keep_vars; do grep -F -q -- "$k" <<<"$r" || miss "配置与密钥: $k"; done
  r=$(row "$w/table.txt" 可观测);       for k in 'observability.enabled: true' '结构化 JSON 日志'; do grep -F -q -- "$k" <<<"$r" || miss "可观测: $k"; done
}
