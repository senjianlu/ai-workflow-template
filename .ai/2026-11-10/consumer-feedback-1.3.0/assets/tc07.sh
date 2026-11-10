#!/usr/bin/env bash
# TC-07:AGENTS.md 参考仓点名与 Worker 判定口径;README 发布纪律
. "$(dirname "$0")/lib.sh"
echo "## AGENTS.md 中 cscheap-catalog 出现次数:$(grep -c 'cscheap-catalog' AGENTS.md)"
! grep -q 'cscheap-catalog' AGENTS.md && ok "AGENTS.md 不再出现 cscheap-catalog" || bad "AGENTS.md 不再出现 cscheap-catalog"
check "Worker 节参考只点名 telegram" has AGENTS.md '单个 Cloudflare Worker 应用(参考 senjianlu/cscheap-telegram)。'
sec=$(sed -n '/^### Cloudflare Worker$/,/^### 部署$/p' AGENTS.md)
for k in '**横切模块**' '**外部协议**' '**领域逻辑**' '例(成目录)' '例(不成目录)' '有两个' '达到四个'; do
  echo "$sec" | grep -qF -- "$k" && ok "Worker 节含:$k" || bad "Worker 节含:$k"
done
check "目录表 Worker 列指向口径" has AGENTS.md '(口径见「技术栈 > Cloudflare Worker」工程约定)'
echo "## Worker 节口径原文"; echo "$sec" | sed -n '/判定口径/,/全部平铺/p'
rel=$(sed -n '/^\*\*发布纪律\*\*/,/^$/p' README.md)
echo "## README 发布纪律原文"; echo "$rel"
echo "$rel" | grep -qF '点名的参考仓' && echo "$rel" | grep -qF '须已推送到远端' && ok "发布纪律含参考仓须已推送一条" || bad "发布纪律含参考仓须已推送一条"
finish
