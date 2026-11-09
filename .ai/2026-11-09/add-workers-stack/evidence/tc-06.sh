# TC-06:CHANGELOG / 版本号、既有栈回归、改动范围
set -u
E=.ai/2026-11-09/add-workers-stack/evidence
. "$E/lib.sh"
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
# ① CHANGELOG 与版本号
l130=$(grep -n -x '## \[1.3.0\] - 2026-11-09' CHANGELOG.md | cut -d: -f1)
l121=$(grep -n '^## \[1.2.1\]' CHANGELOG.md | cut -d: -f1)
if [ -n "$l130" ] && [ -n "$l121" ] && [ "$l130" -lt "$l121" ]; then echo "changelog order: 1.3.0@$l130 < 1.2.1@$l121"; else miss "changelog: [1.3.0]@$l130 [1.2.1]@$l121"; fi
awk '/^## \[1.3.0\]/{f=1; next} f&&/^## \[/{exit} f' CHANGELOG.md > "$w/c.txt"
need "$w/c.txt" CHANGELOG 升级指引 AGENTS.md review-standards.md .gitignore
v=$(head -1 .ai-workflow/TEMPLATE-VERSION)
[ "$v" = "version: 1.3.0" ] && echo "TEMPLATE-VERSION: $v" || miss "TEMPLATE-VERSION: $v"
# ② 既有栈未破坏
for h in '### 前端' '### 后端' '### 爬虫' '### 部署'; do grep -q -x -- "$h" AGENTS.md || miss "AGENTS.md: $h"; done
for k in '- Scrapy:' '- Python/FastAPI:'; do grep -F -q -- "$k" .ai-workflow/review-standards.md || miss "review-standards: $k"; done
[ "$FAILS" -eq 0 ] && echo REGRESSION-OK
# ③ 改动范围
git status --porcelain --untracked-files=all > "$E/git-status.txt"
cat "$E/git-status.txt"
allowed='AGENTS.md .ai-workflow/review-standards.md docs/decisions/0013-workers-standard-stack.md .gitignore CHANGELOG.md .ai-workflow/TEMPLATE-VERSION'
out=0
while IFS= read -r line; do
  p=${line:3}
  case "$p" in .ai/2026-11-09/add-workers-stack/*) continue ;; esac
  ok=0; for a in $allowed; do [ "$p" = "$a" ] && ok=1; done
  [ "$ok" -eq 1 ] || { miss "out of scope: $p"; out=1; }
done < "$E/git-status.txt"
[ "$out" -eq 0 ] && echo SCOPE-OK
finish
