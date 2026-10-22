#!/usr/bin/env bash
# TC-06 默认上限 5 与既有入口回归
source "$(dirname "$0")/lib.sh"
new_proj
# ① 无字段 → 5
assert_eq "① __resolve_max_rounds 缺省" "$(bash "$SCRIPTS/plan-review.sh" __resolve_max_rounds "$TD/plan.md")" "5"
# ② 已有 4 轮 → 放行第 5 轮
for n in 01 02 03 04; do printf '# Plan 评审:第 %s 轮\n\nVERDICT: fail\n' "$n" > "$TD/plan-review-round-$n-fail.md"; done
fake_codex fail; run_review
if [ -f "$OUT/invoked" ]; then ok "② 第 5 轮假 codex 被调用"; else bad "② 第 5 轮假 codex 未被调用"; fi
assert_file "$TD/plan-review-round-05-fail.md"
# ③ 已有 5 轮 → 拒绝
fake_codex fail; run_review
assert_eq "③ 退出码" "$RC" "3"; assert_contains "③ stderr" "$ERR" "已达 5 轮上限"
assert_nofile "$OUT/invoked"; assert_nofile "$TD/.plan-review-raw-06.plan.md"
# ④ 显式上限 1、已有 1 轮 → 拒绝
new_proj
sed -i 's/^task: t$/task: t\nplan_review_max_rounds: 1/' "$TD/plan.md"
printf '# Plan 评审:第 01 轮\n\nVERDICT: fail\n' > "$TD/plan-review-round-01-fail.md"
fake_codex fail; run_review
assert_eq "④ 退出码" "$RC" "3"; assert_contains "④ stderr" "$ERR" "已达 1 轮上限"
assert_nofile "$OUT/invoked"
# ⑤ 快照被 git 忽略
touch "$TD/.plan-review-raw-01.plan.md"
if git -C "$T" check-ignore -q "$TASK/.plan-review-raw-01.plan.md"; then ok "⑤ 快照被 .gitignore 忽略"; else bad "⑤ 快照未被忽略"; fi
# ⑥ __publish_round 仍可渲染
raw=$(mktemp /tmp/rawf-raw.XXXXXX.json)
printf '{"verdict":"pass","issues":[],"scope_findings":["x"],"overall":"o"}\n' > "$raw"
out=$(bash "$SCRIPTS/plan-review.sh" __publish_round "$TD" 09 pass "$raw"); rc=$?
assert_eq "⑥ 退出码" "$rc" "0"
assert_contains "⑥ 产物" "$(cat "$TD/plan-review-round-09-pass.md")" "## 范围核对"
finish
