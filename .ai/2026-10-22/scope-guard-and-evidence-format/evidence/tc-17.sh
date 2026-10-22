#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj T; cd "$T"
cat > "$T/.ai/2026-10-22/t/plan.md" <<'P'
---
status: approved
evidence_format: v1
---
## 测试用例
| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | x | y | z | log |
| TC-02 | A | x | y | z | log |
| TC-03 | B | x | y | z | 文件:行号 |
P
good_evidence "$T"
rec="$T/.ai/2026-10-22/t/implementation-round-01.md"
run() { env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence-check.sh" 2>&1; }
# ① 缺 TC-02 行
printf '## 测试结果\n| 编号 | 档位 | 结果 | 证据 |\n|---|---|---|---|\n| TC-01 | A | pass | TC-01.log |\n| TC-03 | B | pass | a.sh:1 |\n' > "$rec"
out=$(run); rc=$?; echo "$out" | grep -E '^\| TC-|结论'
assert_eq "① 退出码" "$rc" "1"; assert_contains "① TC-02" "$(grep '^| TC-02' <<<"$out")" "MISSING-ROW"
# ② TC-01 档位写 C
printf '## 测试结果\n| 编号 | 档位 | 结果 | 证据 |\n|---|---|---|---|\n| TC-01 | C | pass | 看了 |\n| TC-02 | A | pass | TC-02.log |\n| TC-03 | B | pass | a.sh:1 |\n' > "$rec"
out=$(run); rc=$?; echo "$out" | grep -E '^\| TC-|结论'
assert_eq "② 退出码" "$rc" "1"; assert_contains "② TC-01" "$(grep '^| TC-01' <<<"$out")" "TIER-MISMATCH"
# ③ 空表
printf '## 测试结果\n| 编号 | 档位 | 结果 | 证据 |\n|---|---|---|---|\n\n## 与方案的偏差\n无\n' > "$rec"
out=$(run); rc=$?; echo "$out" | grep -E 'EMPTY|结论'
assert_eq "③ 退出码" "$rc" "1"; assert_contains "③" "$out" "EMPTY-TABLE"
# ④ 多出 TC-09
printf '## 测试结果\n| 编号 | 档位 | 结果 | 证据 |\n|---|---|---|---|\n| TC-01 | A | pass | TC-01.log |\n| TC-02 | A | pass | TC-02.log |\n| TC-03 | B | pass | a.sh:1 |\n| TC-09 | A | pass | TC-01.log |\n' > "$rec"
out=$(run); rc=$?; echo "$out" | grep -E '^\| TC-|结论'
assert_eq "④ 退出码" "$rc" "0"; assert_contains "④ TC-09" "$(grep '^| TC-09' <<<"$out")" "EXTRA-ROW"
finish
