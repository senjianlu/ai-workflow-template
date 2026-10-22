#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj T; cd "$T"
err=$(env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC_x -- true 2>&1 >/dev/null); rc=$?
assert_eq "非法编号退出码" "$rc" "3"; assert_contains "stderr" "$err" "编号不合法"
err=$(env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-01 true 2>&1 >/dev/null); rc=$?
assert_eq "缺 -- 退出码" "$rc" "3"; assert_contains "stderr" "$err" "用法"
rm -f "$T/.ai/.current-task"
err=$(env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-01 -- true 2>&1 >/dev/null); rc=$?
assert_eq "无任务退出码" "$rc" "3"; assert_contains "stderr" "$err" "无进行中任务"
finish
