#!/usr/bin/env bash
# TC-12 __minors 汇总全部轮次的 minor(最终轮未重复列出的也在其中)
source "$(dirname "$0")/lib.sh"
new_proj
printf '# Plan 评审:第 01 轮\n\n## 问题清单\n- [major] R-01 大\n  - 详情:d\n- [minor] R-02 甲\n  - 详情:d\n\nVERDICT: fail\n' > "$TD/plan-review-round-01-fail.md"
printf '# Plan 评审:第 02 轮\n\n## 问题清单\n- [major] R-02 另一条\n  - 详情:d\n- [minor] R-01 乙(收敛降级)\n  - 详情:d\n\nVERDICT: fail\n' > "$TD/plan-review-round-02-fail.md"
printf '# Plan 评审:第 03 轮\n\n## 问题清单\n无\n\nVERDICT: pass\n' > "$TD/plan-review-round-03-pass.md"
out=$(bash "$SCRIPTS/plan-review.sh" __minors "$TD"); rc=$?
echo "$out"
assert_eq "① 退出码" "$rc" "0"
assert_eq "① 输出" "$out" "$(printf '| 01/R-02 | 甲 |\n| 02/R-01 | 乙(收敛降级) |')"
sed -i '/^- \[minor\]/d' "$TD/plan-review-round-01-fail.md" "$TD/plan-review-round-02-fail.md"
out=$(bash "$SCRIPTS/plan-review.sh" __minors "$TD"); rc=$?
assert_eq "② 退出码" "$rc" "0"; assert_eq "② 输出" "$out" "无"
finish
