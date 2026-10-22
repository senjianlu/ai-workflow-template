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
| TC-03 | A | x | y | z | log |
| TC-04 | A | x | y | z | log |
| TC-05 | A | x | y | z | log |
P
ev="$T/.ai/2026-10-22/t/evidence"
printf 'tc: TC-03\ncmd: x\ncwd: /\ngit_head: a\nstarted: t\n--- output ---\nhi\n\n--- end ---\nexit: 0\nfinished: t\nbytes: 3\n' > "$ev/nohdr.log"
printf '# rawf-evidence v1\ntc: TC-04\ncmd: x\ncwd: /\ngit_head: a\nstarted: t\n--- output ---\nhi\n' > "$ev/noend.log"
cat > "$T/.ai/2026-10-22/t/implementation-round-01.md" <<'R'
## 测试结果
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | 没有引用任何文件 |
| TC-02 | A | pass | missing.log |
| TC-03 | A | pass | nohdr.log |
| TC-04 | A | pass | noend.log |
| TC-05 | A | blocked | - |
R
errf=$(mktemp /tmp/rawf-tc07.XXXXXX)
out=$(env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence-check.sh" 2>"$errf"); rc=$?
err=$(cat "$errf"); rm -f "$errf"
echo "--- stdout:"; echo "$out"; echo "--- stderr:"; echo "$err"
assert_eq "退出码" "$rc" "1"
assert_contains "TC-01" "$(grep '^| TC-01' <<<"$out")" "NO-REF"
assert_contains "TC-02" "$(grep '^| TC-02' <<<"$out")" "MISSING"
assert_contains "TC-03" "$(grep '^| TC-03' <<<"$out")" "NO-HEADER"
assert_contains "TC-04" "$(grep '^| TC-04' <<<"$out")" "NO-FOOTER"
assert_contains "TC-05" "$(grep '^| TC-05' <<<"$out")" "BLOCKED"
assert_contains "stderr 有补交清单标题" "$err" "补交清单:"
for id in TC-01 TC-02 TC-03 TC-04 TC-05; do assert_contains "stderr 补交清单" "$err" "- $id"; done
assert_contains "stderr 列出所缺项" "$err" "NO-REF"; assert_contains "stderr 列出所缺项" "$err" "MISSING"; assert_contains "stderr 列出所缺项" "$err" "blocked"
assert_not_contains "stdout 不含补交清单条目" "$out" "- TC-01"
finish
