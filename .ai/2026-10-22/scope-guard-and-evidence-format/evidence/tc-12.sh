#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
for s in review plan-review; do
  f="$ROOT/.ai-workflow/schemas/$s.schema.json"
  assert_eq "$s required 含 scope_findings" "$(jq -r '.required | index("scope_findings") != null' "$f")" "true"
  assert_eq "$s scope_findings 为字符串数组" "$(jq -r '.properties.scope_findings | .type + "/" + .items.type' "$f")" "array/string"
  assert_eq "$s 合法 JSON" "$(jq -e . "$f" >/dev/null && echo yes)" "yes"
done
finish
