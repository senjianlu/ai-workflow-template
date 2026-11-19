#!/usr/bin/env bash
# review-fingerprint-evidence-bloat 的测试脚本(plan TC-01 ~ TC-07、TC-09)。
# 用法(在项目根执行):bash <本脚本> tcNN
# 夹具全部建在项目外(mktemp -d),不写项目内文件;exit 0 = 全部断言成立。
# 每条断言打印涉及的指纹值 / 退出码。
set -u
export LC_ALL=C
ROOT=$(git rev-parse --show-toplevel)
REVIEW_SH="$ROOT/.ai-workflow/scripts/review.sh"
BASELINE_SHA=fd5d23a   # 改前实现所在提交(TC-06 的对照基线,写死)
W=$(mktemp -d /tmp/rawf-fp.XXXXXX)
cleanup() { chmod -R u+rwX "$W" 2>/dev/null; rm -rf "$W"; }
trap cleanup EXIT
FAILS=0
ok()  { echo "  ok   - $1"; }
bad() { echo "  FAIL - $1"; FAILS=$((FAILS+1)); }
finish() {
  echo
  if [ "$FAILS" -eq 0 ]; then echo "RESULT: all assertions passed"; exit 0
  else echo "RESULT: $FAILS assertion(s) failed"; exit 1; fi
}

# wh <dir>:取指纹,结果放 H(stdout)、RC(退出码)、ERR(stderr 文件路径)
ERR="$W/last.stderr"
wh() {
  H=$(cd "$1" && CLAUDE_PROJECT_DIR="$1" bash "$REVIEW_SH" __workspace_hash 2>"$ERR"); RC=$?
}
# 断言族:取一次指纹并与基线 BASE 比较
expect_diff() { wh "$D"; if [ "$RC" = 0 ] && [ -n "$H" ] && [ "$H" != "$BASE" ]; then ok "$1:指纹变化 ($H, rc=$RC)"; else bad "$1:应变化,实际 $H (基线 $BASE, rc=$RC)"; fi; }
expect_same() { wh "$D"; if [ "$RC" = 0 ] && [ "$H" = "$BASE" ]; then ok "$1:指纹 = 基线 ($H, rc=$RC)"; else bad "$1:应等于基线 $BASE,实际 $H (rc=$RC)"; fi; }
take_base()   { wh "$D"; BASE=$H; if [ "$RC" = 0 ] && [ -n "$BASE" ]; then ok "基线指纹 $BASE (rc=$RC)"; else bad "基线取值失败 (rc=$RC, stderr: $(cat "$ERR"))"; fi; }

# mk_repo <dir>:已提交基线(src/main.js、.gitignore 含 .env)
mk_repo() {
  mkdir -p "$1/src"
  git -C "$1" init -q .
  git -C "$1" config user.email t@t; git -C "$1" config user.name t
  echo base > "$1/src/main.js"
  printf '.env\n' > "$1/.gitignore"
  git -C "$1" add -A >/dev/null && git -C "$1" commit -q -m init
}
# mk_base <dir>:mk_repo + 未跟踪普通文件、可执行文件、符号链接、被忽略的 .env
mk_base() {
  mk_repo "$1"
  printf 'aaaa\n' > "$1/a.txt"; printf 'bbbb\n' > "$1/b.txt"
  printf '#!/bin/sh\necho hi\n' > "$1/run.sh"; chmod +x "$1/run.sh"
  ln -s a.txt "$1/link"
  printf 'KEY=1111\n' > "$1/.env"
}

tc01() {
  echo "== TC-01 敏感性回归 =="
  D="$W/fx1"; mk_base "$D"; take_base
  echo changed >> "$D/src/main.js";            expect_diff "改已跟踪文件"
  git -C "$D" checkout -q -- src/main.js;      expect_same "还原已跟踪文件"
  printf 'cccc\n' > "$D/a.txt";                expect_diff "改未跟踪文件内容(等长)"
  printf 'aaaa\n' > "$D/a.txt";                expect_same "还原未跟踪文件内容"
  chmod -x "$D/run.sh";                        expect_diff "去掉可执行位"
  chmod +x "$D/run.sh";                        expect_same "恢复可执行位"
  ln -sfn b.txt "$D/link";                     expect_diff "改符号链接目标"
  ln -sfn a.txt "$D/link";                     expect_same "还原符号链接目标"
  printf 'new\n' > "$D/new.txt";               expect_diff "新增未跟踪文件"
  rm "$D/new.txt";                             expect_same "删除新增的文件"
  rm "$D/b.txt";                               expect_diff "删除未跟踪文件"
  printf 'bbbb\n' > "$D/b.txt";                expect_same "恢复被删文件"
  mv "$D/a.txt" "$D/c.txt";                    expect_diff "重命名未跟踪文件"
  mv "$D/c.txt" "$D/a.txt";                    expect_same "改回原名"
}

tc02() {
  echo "== TC-02 排除清单与被忽略文件 =="
  D="$W/fx2"; mk_base "$D"; take_base
  mkdir -p "$D/.claude" "$D/node_modules"
  echo '{"permissions":{}}' > "$D/.claude/settings.local.json"
  echo '{}' > "$D/.review-raw-01.json"
  echo 'x' > "$D/node_modules/x.js"
  expect_same "只写 .claude/、.review-raw-*、node_modules/"
  if git -C "$D" check-ignore -q .env; then ok ".env 确被 .gitignore 忽略"; else bad ".env 未被忽略,夹具无效"; fi
  printf 'KEY=2222\n' > "$D/.env";             expect_diff "等长改写被忽略的 .env"
  printf 'KEY=1111\n' > "$D/.env";             expect_same "还原 .env"
}

tc03() {
  echo "== TC-03 特殊路径与符号链接 =="
  D="$W/fx3"; EXT="$W/ext3"; mkdir -p "$EXT"; mk_repo "$D"
  printf 'ext1\n' > "$EXT/target1"; printf 'ext2\n' > "$EXT/target2"
  local nl=$'new\nline.txt'
  local specials=("sp ace.txt" "$nl" "-dash.txt" "-" "中文.txt" "st*ar.txt")
  local f
  for f in "${specials[@]}"; do printf '1111\n' > "$D/$f"; done
  : > "$D/empty.txt"
  printf 'xxxx\n' > "$D/p.txt"; printf 'yyyy\n' > "$D/q.txt"
  ln -s nonexistent "$D/dangling"
  ln -s src "$D/dirlink"
  ln -s "$EXT/target1" "$D/extlink"
  take_base
  wh "$D"; if [ "$RC" = 0 ] && [ "$H" = "$BASE" ]; then ok "(1) 连续两次取值相等 ($H, rc=$RC)"; else bad "(1) 两次取值不等:$BASE / $H (rc=$RC)"; fi
  for f in "${specials[@]}"; do
    printf '2222\n' > "$D/$f"; expect_diff "(2) 等长改写 $(printf %q "$f")"
    printf '1111\n' > "$D/$f"; expect_same "(2) 还原 $(printf %q "$f")"
  done
  printf 'z\n' > "$D/empty.txt";               expect_diff "(3) 向空文件写入内容"
  : > "$D/empty.txt";                          expect_same "(3) 还原为空文件"
  printf 'yyyy\n' > "$D/p.txt"; printf 'xxxx\n' > "$D/q.txt"
  expect_diff "(4) 交换两个等长文件的内容"
  printf 'xxxx\n' > "$D/p.txt"; printf 'yyyy\n' > "$D/q.txt"
  expect_same "(4) 换回"
  printf 'EXT9\n' > "$EXT/target1";            expect_same "(5) 只改仓库外链接目标的内容"
  ln -sfn "$EXT/target2" "$D/extlink";         expect_diff "(6) 链接改指向另一个仓库外文件"
}

tc04() {
  echo "== TC-04 无未跟踪文件 / 跨批 + 不可读文件 =="
  if [ "$(id -u)" = 0 ]; then bad "以 root 运行:chmod 000 不产生不可读文件,错误分支无法执行(按 plan 判失败,不跳过)"; return; fi
  ok "非 root 运行 (uid=$(id -u))"
  echo "-- 夹具 a:无未跟踪文件"
  D="$W/fx4a"; mk_repo "$D"
  local n; n=$(git -C "$D" ls-files --others | wc -l)
  if [ "$n" = 0 ]; then ok "未跟踪文件数 = 0"; else bad "夹具 a 有 $n 个未跟踪文件"; fi
  take_base; expect_same "第二次取值"

  echo "-- 夹具 b:路径总字节数跨多批,第一批混入不可读文件"
  D="$W/fx4b"; mk_repo "$D"
  local pad; pad=$(printf 'x%.0s' $(seq 1 80))
  local i dir
  for i in $(seq 1 4000); do
    dir="$D/d$(printf '%02d' $((i % 20)))_$pad"
    [ -d "$dir" ] || mkdir -p "$dir"
    printf 'c%04d\n' "$i" > "$dir/f$(printf '%04d' "$i")_abcdefghijklmnopqrst.txt"
  done
  # 按指纹实现同样的列举顺序与 ./ 前缀,用同样的 xargs 默认参数实测各批大小
  local sizes; sizes=$(cd "$D" && git ls-files --others -z | while IFS= read -r -d '' f; do printf './%s\0' "$f"; done \
    | xargs -0 -r sh -c 'echo "$#"' sh)
  local batches; batches=$(printf '%s\n' "$sizes" | wc -l)
  local first; first=$(printf '%s\n' "$sizes" | head -1)
  echo "  xargs 各批文件数:$(printf '%s ' $sizes)"
  if [ "$batches" -ge 3 ]; then ok "批数 = $batches (≥ 3)"; else bad "批数 = $batches,不足 3"; fi
  if [ "$first" -gt 10 ]; then ok "第一批文件数 = $first (> 10)"; else bad "第一批文件数 = $first,过小"; fi
  local unread same last
  unread=$(cd "$D" && git ls-files --others | sed -n 2p)
  same=$(cd "$D" && git ls-files --others | sed -n 10p)
  last=$(cd "$D" && git ls-files --others | tail -1)
  echo "  不可读文件(序号 2):$unread"
  echo "  同批可读文件(序号 10):$same"
  echo "  末批最后一个文件:$last"
  chmod 000 "$D/$unread"
  if [ -r "$D/$unread" ]; then bad "chmod 000 后仍可读,错误分支未生效"; else ok "chmod 000 后确不可读"; fi
  take_base
  if grep -q 'Permission denied' "$ERR"; then ok "stderr 含 sha1sum 的 Permission denied(错误分支确被执行):$(head -1 "$ERR")"; else bad "stderr 无 Permission denied:$(cat "$ERR")"; fi
  expect_same "第二次取值"
  local orig; orig=$(cat "$D/$same")
  printf 'ZZZZZ\n' > "$D/$same";               expect_diff "等长改写与不可读文件同批、其后的可读文件"
  printf '%s\n' "$orig" > "$D/$same";          expect_same "还原同批文件"
  orig=$(cat "$D/$last")
  printf 'ZZZZZ\n' > "$D/$last";               expect_diff "等长改写末批最后一个文件"
  printf '%s\n' "$orig" > "$D/$last";          expect_same "还原末批文件"
  chmod 644 "$D/$unread"
}

# --- 完整评审夹具(TC-05 / TC-07 共用)------------------------------------
# mk_review_proj <dir>:带 .ai-workflow 副本、approved plan、实现记录、合规 A 档证据
mk_review_proj() {
  local d=$1 task=.ai/2026-11-19/t
  mkdir -p "$d"
  git -C "$d" init -q .
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  git -C "$d" commit -q --allow-empty -m init
  cp -r "$ROOT/.ai-workflow" "$d/.ai-workflow"
  mkdir -p "$d/$task/evidence"
  echo "$task" > "$d/.ai/.current-task"
  git -C "$d" add -A >/dev/null && git -C "$d" commit -q -m setup
  cat > "$d/$task/plan.md" <<'P'
---
status: approved
task: t
evidence_format: v1
---
## 测试用例
| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | x | y | z | TC-01.log |
## 风险
P
  cat > "$d/$task/implementation-round-01.md" <<'R'
# 实现记录
## 测试结果
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | evidence.sh 产出 TC-01.log |
## 与方案的偏差
无
R
  (cd "$d" && CLAUDE_PROJECT_DIR="$d" bash "$ROOT/.ai-workflow/scripts/evidence.sh" TC-01 -- bash -c 'echo one' >/dev/null 2>&1)
  printf 'untracked\n' > "$d/notes.txt"
}
# mk_codex_stub <bindir> <outdir>:假 codex(项目外)。调用即落 <outdir>/invoked;
# <outdir>/hook 存在则在写出 pass JSON 之前 source 它。
mk_codex_stub() {
  mkdir -p "$1" "$2"
  cat > "$1/codex" <<C
#!/bin/bash
out="$2"
touch "\$out/invoked"
last=
while [ \$# -gt 0 ]; do
  if [ "\$1" = "--output-last-message" ]; then last=\$2; shift 2; continue; fi
  shift
done
[ -f "\$out/hook" ] && . "\$out/hook"
printf '{"verdict":"pass","issues":[],"scope_findings":[],"overall":"stub"}\n' > "\$last"
echo '{"type":"item.completed"}'
C
  chmod +x "$1/codex"
}
# run_review <dir> <PATH>:跑完整 review.sh,结果放 RRC、ROUT(stdout+stderr 文件)
run_review() {
  ROUT="$W/review.out"
  (cd "$1" && env PATH="$2" CLAUDE_PROJECT_DIR="$1" RAWF_REVIEW_POLL_SECONDS=1 \
     /bin/bash "$1/.ai-workflow/scripts/review.sh" >"$ROUT" 2>&1); RRC=$?
  echo "  review.sh 退出码 $RRC;输出:"; sed 's/^/  | /' "$ROUT"
}
expect_rc3() { if [ "$RRC" = 3 ]; then ok "$1:exit 3"; else bad "$1:应 exit 3,实际 $RRC"; fi; }
no_round_files() {
  local n; n=$(find "$1/.ai" -name 'review-round-*.md' | wc -l)
  if [ "$n" = 0 ]; then ok "$2:无 review-round-*.md"; else bad "$2:发布了评审文件:$(find "$1/.ai" -name 'review-round-*.md')"; fi
}

tc05() {
  echo "== TC-05 缺 sha1sum / sha1sum 运行期异常 =="
  local real; real=$(command -v sha1sum)
  local P="$W/path-no-sha1" f
  mkdir -p "$P"
  for f in /usr/bin/* /bin/*; do
    [ -x "$f" ] || continue
    [ "$(basename "$f")" = sha1sum ] && continue
    [ -e "$P/$(basename "$f")" ] || ln -s "$f" "$P/$(basename "$f")"
  done
  if PATH="$P" command -v sha1sum >/dev/null; then bad "受控 PATH 仍能找到 sha1sum"; else ok "受控 PATH (i) 不含 sha1sum"; fi
  local MARK="$W/fail-mark" P2="$W/path-stub-sha1"
  mkdir -p "$P2"
  cat > "$P2/sha1sum" <<S
#!/bin/bash
[ -e "$MARK" ] && exit 255
exec "$real" "\$@"
S
  chmod +x "$P2/sha1sum"

  echo "-- (1) PATH 不含 sha1sum"
  local D1="$W/fx5a" S1="$W/stub5a" O1="$W/out5a"
  mk_review_proj "$D1"; mk_codex_stub "$S1" "$O1"
  H=$(cd "$D1" && PATH="$P" CLAUDE_PROJECT_DIR="$D1" /bin/bash "$REVIEW_SH" __workspace_hash 2>"$ERR"); RC=$?
  if [ "$RC" != 0 ] && [ -z "$H" ]; then ok "__workspace_hash:退出码 $RC(非 0)且 stdout 无指纹"; else bad "__workspace_hash:rc=$RC stdout=$H"; fi
  run_review "$D1" "$S1:$P"
  expect_rc3 "(1) 完整流程"
  if grep -q '缺少 sha1sum' "$ROUT"; then ok "(1) stderr 指明缺少 sha1sum"; else bad "(1) 输出未指明缺 sha1sum"; fi
  if [ -e "$O1/invoked" ]; then bad "(1) codex 桩被调用"; else ok "(1) codex 桩未被调用"; fi
  no_round_files "$D1" "(1)"

  echo "-- (2) sha1sum 桩以 255 退出(标记已存在)"
  local D2="$W/fx5b" S2="$W/stub5b" O2="$W/out5b"
  mk_review_proj "$D2"; mk_codex_stub "$S2" "$O2"
  touch "$MARK"
  H=$(cd "$D2" && PATH="$P2:$P" CLAUDE_PROJECT_DIR="$D2" /bin/bash "$REVIEW_SH" __workspace_hash 2>"$ERR"); RC=$?
  if [ "$RC" != 0 ] && [ -z "$H" ]; then ok "__workspace_hash:退出码 $RC(非 0)且 stdout 无指纹"; else bad "__workspace_hash:rc=$RC stdout=$H"; fi
  run_review "$D2" "$S2:$P2:$P"
  expect_rc3 "(2) 完整流程(pre_hash 失败)"
  if [ -e "$O2/invoked" ]; then bad "(2) codex 桩被调用"; else ok "(2) codex 桩未被调用"; fi
  no_round_files "$D2" "(2)"
  rm -f "$MARK"

  echo "-- (3) 标记由 codex 桩在写出 JSON 前创建(post_hash 失败)"
  local D3="$W/fx5c" S3="$W/stub5c" O3="$W/out5c"
  mk_review_proj "$D3"; mk_codex_stub "$S3" "$O3"
  printf 'touch "%s"\n' "$MARK" > "$O3/hook"
  H=$(cd "$D3" && PATH="$P2:$P" CLAUDE_PROJECT_DIR="$D3" /bin/bash "$REVIEW_SH" __workspace_hash 2>"$ERR"); RC=$?
  if [ "$RC" = 0 ] && [ -n "$H" ]; then ok "对照:标记不存在时桩 sha1sum 下指纹正常 ($H, rc=$RC)"; else bad "对照失败:rc=$RC stdout=$H stderr=$(cat "$ERR")"; fi
  run_review "$D3" "$S3:$P2:$P"
  expect_rc3 "(3) 完整流程(post_hash 失败)"
  if [ -e "$O3/invoked" ]; then ok "(3) codex 桩被调用过"; else bad "(3) codex 桩未被调用"; fi
  if [ -e "$MARK" ]; then ok "(3) 标记已由桩创建"; else bad "(3) 标记未创建"; fi
  no_round_files "$D3" "(3)"
  rm -f "$MARK"
}

now_ms() { echo $(( $(date +%s%N) / 1000000 )); }
tc06() {
  echo "== TC-06 性能对比 =="
  D="$W/fx6"; mk_repo "$D"
  local i
  for i in $(seq 1 3000); do
    [ -d "$D/e/$((i % 50))" ] || mkdir -p "$D/e/$((i % 50))"
    head -c 20000 /dev/urandom > "$D/e/$((i % 50))/f$i.bin"
  done
  echo "  未跟踪文件数:$(git -C "$D" ls-files --others | wc -l)"
  local OLD="$W/review-old.sh"
  git -C "$ROOT" show "$BASELINE_SHA:.ai-workflow/scripts/review.sh" > "$OLD"
  echo "  改前实现:提交 $(git -C "$ROOT" rev-parse "$BASELINE_SHA") 的 .ai-workflow/scripts/review.sh"
  if grep -q 'shasum < "\$f"' "$OLD"; then ok "基线脚本确为逐文件 shasum 实现"; else bad "基线脚本不含逐文件 shasum"; fi
  local t0 t1 new_ms old_ms hn ho
  t0=$(now_ms); wh "$D"; t1=$(now_ms); new_ms=$((t1 - t0)); hn=$H
  if [ "$RC" = 0 ] && [ -n "$hn" ]; then ok "改后取值 $hn (rc=$RC)"; else bad "改后取值失败 rc=$RC"; fi
  t0=$(now_ms); ho=$(cd "$D" && CLAUDE_PROJECT_DIR="$D" bash "$OLD" __workspace_hash 2>/dev/null); RC=$?; t1=$(now_ms); old_ms=$((t1 - t0))
  if [ "$RC" = 0 ] && [ -n "$ho" ]; then ok "改前取值 $ho (rc=$RC)"; else bad "改前取值失败 rc=$RC"; fi
  echo "  改后耗时:${new_ms} ms"
  echo "  改前耗时:${old_ms} ms"
  if [ $((new_ms * 10)) -le "$old_ms" ]; then ok "改后 ≤ 改前的 1/10"; else bad "改后未达改前的 1/10"; fi
  if [ "$new_ms" -le 5000 ]; then ok "改后 ≤ 5 秒"; else bad "改后超过 5 秒"; fi
}

tc07() {
  echo "== TC-07 桩评审端到端 =="
  echo "-- 桩不动工作区"
  local D1="$W/fx7a" S1="$W/stub7a" O1="$W/out7a"
  mk_review_proj "$D1"; mk_codex_stub "$S1" "$O1"
  run_review "$D1" "$S1:$PATH"
  if [ "$RRC" = 0 ]; then ok "exit 0"; else bad "应 exit 0,实际 $RRC"; fi
  if [ -f "$D1/.ai/2026-11-19/t/review-round-01-pass.md" ]; then ok "发布 review-round-01-pass.md"; else bad "未发布 review-round-01-pass.md"; fi
  echo "-- 桩在写出 JSON 前改写未跟踪文件"
  local D2="$W/fx7b" S2="$W/stub7b" O2="$W/out7b"
  mk_review_proj "$D2"; mk_codex_stub "$S2" "$O2"
  printf 'printf "tampered!\\n" > "%s/notes.txt"\n' "$D2" > "$O2/hook"
  run_review "$D2" "$S2:$PATH"
  expect_rc3 "篡改场景"
  if grep -q '主工作区在评审期间发生改动' "$ROUT"; then ok "stderr 含\"主工作区在评审期间发生改动\""; else bad "输出不含预期报错"; fi
  if [ -e "$O2/invoked" ]; then ok "codex 桩被调用过"; else bad "codex 桩未被调用"; fi
  if [ "$(cat "$D2/notes.txt")" = "tampered!" ]; then ok "未跟踪文件确被桩改写"; else bad "未跟踪文件未被改写,场景无效"; fi
  no_round_files "$D2" "篡改场景"
}

tc09() {
  echo "== TC-09 发版文件 =="
  local v; v=$(grep -n '^version:' "$ROOT/.ai-workflow/TEMPLATE-VERSION")
  echo "  TEMPLATE-VERSION:$v"
  if [ "$v" = "1:version: 1.4.1" ]; then ok "version 行为 1.4.1"; else bad "version 行不符"; fi
  local l141 l140
  l141=$(grep -n '^## \[1\.4\.1\] - 2026-11-19$' "$ROOT/CHANGELOG.md" | cut -d: -f1)
  l140=$(grep -n '^## \[1\.4\.0\]' "$ROOT/CHANGELOG.md" | cut -d: -f1)
  echo "  CHANGELOG 行号:[1.4.1]=${l141:-无} [1.4.0]=${l140:-无}"
  if [ -n "$l141" ] && [ -n "$l140" ] && [ "$l141" -lt "$l140" ]; then ok "[1.4.1] - 2026-11-19 条目存在且位于 [1.4.0] 之前"; else bad "[1.4.1] 条目缺失或位置不对"; return; fi
  local g; g=$(sed -n "${l141},$((l140 - 1))p" "$ROOT/CHANGELOG.md" | grep -n '^### 升级指引$')
  echo "  条目内升级指引:${g:-无}"
  if [ -n "$g" ]; then ok "[1.4.1] 条目含「升级指引」小节"; else bad "[1.4.1] 条目缺「升级指引」"; fi
}

case "${1:-}" in
  tc01|tc02|tc03|tc04|tc05|tc06|tc07|tc09) "$1"; finish ;;
  *) echo "用法:$0 tc01|tc02|tc03|tc04|tc05|tc06|tc07|tc09" >&2; exit 2 ;;
esac
