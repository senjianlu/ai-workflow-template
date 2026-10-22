#!/usr/bin/env bash
# TC-09 语法检查
source "$(dirname "$0")/lib.sh"
if bash -n "$SCRIPTS/plan-review.sh"; then ok "bash -n plan-review.sh"; else bad "bash -n plan-review.sh"; fi
finish
