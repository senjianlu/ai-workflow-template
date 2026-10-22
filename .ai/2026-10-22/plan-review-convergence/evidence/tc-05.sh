#!/usr/bin/env bash
# TC-05 第 3 轮但缺上一轮快照(模拟升级前历史轮次):回退为全量,不给 diff
source "$(dirname "$0")/lib.sh"
new_proj; fake_codex fail; run_review
sed -i 's/^旧行$/新行/' "$TD/plan.md"; fake_codex fail; run_review
rm -f "$TD/.plan-review-raw-02.plan.md"
sed -i 's/^新行$/第三行/' "$TD/plan.md"; fake_codex pass; run_review
assert_eq "第 03 轮退出码" "$RC" "0"
assert_eq "模式行" "$(mode_line)" "本轮模式:全量穷尽评审(无上一轮快照)"
assert_contains "prompt" "$PROMPT" "$TASK/plan-review-round-02-"
assert_contains "prompt" "$PROMPT" "无上一轮快照"
assert_not_contains "prompt" "$PROMPT" '```diff'

# 修复轮 02(评审 R-01):上一轮快照存在但 diff 执行失败,不得被当作"未修订"
# ② 上一轮快照不可读
new_proj; fake_codex fail; run_review
sed -i 's/^旧行$/新行/' "$TD/plan.md"; fake_codex fail; run_review
sed -i 's/^新行$/第三行/' "$TD/plan.md"
chmod 000 "$TD/.plan-review-raw-02.plan.md"
fake_codex pass; run_review
chmod 644 "$TD/.plan-review-raw-02.plan.md"
assert_eq "② 快照不可读:退出码" "$RC" "3"
assert_contains "② stderr" "$ERR" "修订 diff 生成失败"
ERR2=$ERR
assert_nofile "$OUT/invoked"
assert_nofile "$TD/plan-review-round-03-pass.md"
# ③ diff 命令本身失败(PATH 前置退出码 2 的假 diff)
printf '#!/usr/bin/env bash\nexit 2\n' > "$T/bin/diff"; chmod +x "$T/bin/diff"
fake_codex pass; run_review
rm -f "$T/bin/diff"
assert_eq "③ diff 失败:退出码" "$RC" "3"
assert_contains "③ stderr" "$ERR" "diff 退出码 2"
assert_nofile "$OUT/invoked"
assert_nofile "$TD/plan-review-round-03-pass.md"
# ④ 排除故障后重跑:仍为第 03 轮,收敛模式,diff 正常
fake_codex pass; run_review
assert_eq "④ 重跑退出码" "$RC" "0"
assert_eq "④ 模式行" "$(mode_line)" "本轮模式:收敛评审"
assert_contains "④ diff" "$PROMPT" "+第三行"
assert_file "$TD/plan-review-round-03-pass.md"
echo "--- ② stderr:"; echo "$ERR2"
finish
