#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj T; cd "$T"; good_plan "$T"; good_record "$T" 01; good_evidence "$T"
out=$(env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence-check.sh"); rc=$?
echo "$out"
assert_eq "退出码" "$rc" "0"
assert_contains "TC-01 行" "$(grep '^| TC-01' <<<"$out")" "| OK | 0 | bash -c echo\\ one |"
assert_contains "TC-02 行" "$(grep '^| TC-02' <<<"$out")" "| OK | 7 |"
assert_contains "TC-03 行" "$(grep '^| TC-03' <<<"$out")" "评审核验"
assert_contains "TC-04 行" "$(grep '^| TC-04' <<<"$out")" "评审核验"
finish
