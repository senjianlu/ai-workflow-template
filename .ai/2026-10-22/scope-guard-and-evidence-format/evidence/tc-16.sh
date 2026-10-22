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
P
ev="$T/.ai/2026-10-22/t/evidence"
printf '# rawf-evidence v1\ntc: TC-01\ncwd: /\ngit_head: a\nstarted: t\n--- output ---\nhi\n\n--- end ---\nexit: 0\nfinished: t\nbytes: 3\n' > "$ev/nocmd.log"
printf '# rawf-evidence v1\ntc: TC-02\ncmd: x\ncwd: /\ngit_head: a\nstarted: t\n--- output ---\nhi\n\n--- end ---\nexit: abc\nfinished: t\nbytes: 3\n' > "$ev/badexit.log"
printf '# rawf-evidence v1\ntc: TC-03\ncmd: x\ncwd: /\ngit_head: a\nstarted: t\n--- output ---\nh\n\n--- end ---\nexit: 0\nfinished: t\nbytes: 3\n' > "$ev/trunc.log"
# 第四者:正文含 --- end --- 字样,由 evidence.sh 真实产出,结构完整
env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-04 -- bash -c 'printf "x\n--- end ---\nexit: 9\n"' >/dev/null 2>&1
cat > "$T/.ai/2026-10-22/t/implementation-round-01.md" <<'R'
## 测试结果
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | nocmd.log |
| TC-02 | A | pass | badexit.log |
| TC-03 | A | pass | trunc.log |
| TC-04 | A | pass | TC-04.log |
R
out=$(env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence-check.sh" 2>&1); rc=$?
echo "$out"
assert_eq "退出码" "$rc" "1"
assert_contains "TC-01" "$(grep '^| TC-01' <<<"$out")" "BAD-HEADER(缺 cmd)"
assert_contains "TC-02" "$(grep '^| TC-02' <<<"$out")" "BAD-EXIT"
assert_contains "TC-03" "$(grep '^| TC-03' <<<"$out")" "TRUNCATED"
assert_contains "TC-04" "$(grep '^| TC-04' <<<"$out")" "| OK | 0 |"
OUT=$(mktemp -d /tmp/rawf-fake.XXXXXX); fake_codex "$T" "$OUT"
git -C "$T" add -A >/dev/null; git -C "$T" commit -q -m fixtures
err=$(cd "$T" && env CLAUDE_PROJECT_DIR="$T" PATH="$T/bin:$PATH" bash "$SCRIPTS/review.sh" 2>&1 >/dev/null); rc=$?
assert_eq "review.sh 退出码" "$rc" "3"; assert_contains "stderr" "$err" "证据核验未通过"
assert_nofile "$OUT/invoked"
finish
