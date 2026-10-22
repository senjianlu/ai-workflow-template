#!/usr/bin/env bash
# TC-11 机械性更正标注不破坏 evidence-check 的表格解析
source "$(dirname "$0")/lib.sh"
new_proj
cat > "$TD/plan.md" <<'P'
---
status: approved
evidence_format: v1
---
## 测试用例
| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A | x | y | 消息列出 [570, 730, 252490]〔机械性更正:原文「[252490, 570, 730]」;理由:排序笔误;见实现记录 D-01〕 | (a) TC-01.log |
| TC-02 | B | x | y | z | 文件:行号 |
P
(cd "$T" && env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-01 -- bash -c 'echo "[570, 730, 252490]"' >/dev/null 2>&1)
printf '## 测试结果\n| 编号 | 档位 | 结果 | 证据 |\n|---|---|---|---|\n| TC-01 | A | pass | TC-01.log |\n| TC-02 | B | pass | a.sh:1 |\n' > "$TD/implementation-round-01.md"
out=$(env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence-check.sh" 2>&1); rc=$?
echo "$out"
assert_eq "退出码" "$rc" "0"
assert_contains "TC-01 行" "$(grep '^| TC-01' <<<"$out")" "| A | pass | TC-01.log | OK | 0 |"
finish
