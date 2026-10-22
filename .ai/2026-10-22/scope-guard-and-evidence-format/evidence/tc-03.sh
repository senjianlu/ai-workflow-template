#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
new_proj T; cd "$T"
f="$T/.ai/2026-10-22/t/evidence/TC-01.log"
env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-01 -- bash -c 'echo first' >/dev/null 2>&1
h1=$(sha256sum "$f" | cut -d' ' -f1)
err=$(env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-01 -- bash -c 'echo second' 2>&1 >/dev/null); rc=$?
assert_eq "重复编号退出码" "$rc" "3"
assert_contains "stderr" "$err" "已存在"
assert_eq "原文件 sha256 不变" "$(sha256sum "$f" | cut -d' ' -f1)" "$h1"
env CLAUDE_PROJECT_DIR="$T" bash "$SCRIPTS/evidence.sh" TC-01 -l rerun -- bash -c 'echo second' >/dev/null 2>&1; rc=$?
assert_eq "带 label 退出码" "$rc" "0"
assert_file "$T/.ai/2026-10-22/t/evidence/TC-01-rerun.log"
assert_contains "label 文件正文" "$(cat "$T/.ai/2026-10-22/t/evidence/TC-01-rerun.log")" "second"
finish
