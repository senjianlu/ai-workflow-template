# TC-05:.gitignore 行为(四项被忽略;示例文件不被忽略——反向断言)
set -u
E=.ai/2026-11-09/add-workers-stack/evidence
. "$E/lib.sh"
for p in .dev.vars .dev.vars.local worker-configuration.d.ts .wrangler/state/x; do
  if git check-ignore -q "$p"; then echo "ignored: $p"; else miss "should be ignored: $p"; fi
done
rc=0; git check-ignore -q .dev.vars.example || rc=$?
if [ "$rc" -eq 1 ]; then echo "not ignored (rc=1): .dev.vars.example"; else miss ".dev.vars.example rc=$rc,应为 1"; fi
finish
