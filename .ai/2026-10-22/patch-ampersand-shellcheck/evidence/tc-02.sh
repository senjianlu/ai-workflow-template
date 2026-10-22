#!/usr/bin/env bash
# TC-02 证据不完整时 review.sh 仍拒绝启动(修复不影响拒启路径)
source "$(dirname "$0")/lib.sh"
new_proj
printf '# rawf-evidence v1\ntc: TC-01\ncmd: x\ncwd: /\ngit_head: a\nstarted: t\n--- output ---\nhi\n' > "$TD/evidence/TC-01.log"
git -C "$T" add -A >/dev/null; git -C "$T" commit -q -m fixtures
run_review
echo "--- stderr:"; echo "$ERR"
assert_eq "退出码" "$RC" "3"
assert_contains "stderr" "$ERR" "证据核验未通过"
assert_contains "stderr" "$ERR" "补交清单"
assert_contains "stderr" "$ERR" "NO-FOOTER"
if [ -e "$OUT/invoked" ]; then bad "假 codex 不应被调用"; else ok "假 codex 未被调用"; fi
finish
