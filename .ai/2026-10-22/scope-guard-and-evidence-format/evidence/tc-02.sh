#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj T; cd "$T"
env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-02 -- bash -c 'exit 7'; rc=$?
assert_eq "包装器退出码透传" "$rc" "7"
assert_contains "尾部" "$(tail -n4 "$T/.ai/2026-10-22/t/evidence/TC-02.log")" "exit: 7"
finish
