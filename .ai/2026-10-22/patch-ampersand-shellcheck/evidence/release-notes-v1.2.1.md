## [1.2.1] - 2026-10-22

### Fixed

- review.sh 注入证据报告(`{{EVIDENCE_REPORT}}`)前关闭 bash 5.2 默认开启的
  `patsub_replacement`:此前 B/C 档证据格原文中的 `&` 会被改写为占位字样、
  A 档 cmd 列 `%q` 转义的 `\&` 会丢反斜杠,注入给评审者的报告与 evidence-check
  原始输出不一致(A 档机器核验结论不受影响)。

### Changed

- 流程脚本 shellcheck 全级别零条:review.sh / plan-review.sh 删去 `lock_holders`
  中未用的局部变量;主流程与 `kill_codex_tree` 中未用的循环变量改为 `_`(并删去
  对应的 `local i`);evidence.sh 为经 trap 调用的 `on_sig` 加
  `shellcheck disable=SC2329` 注释。行为不变。

### 升级指引

- 可整体替换:`.ai-workflow/`(scripts 与 TEMPLATE-VERSION;consumer 若在
  review-standards.md 有项目自改小节,本版未改该文件,可只替换 scripts)。
- 无需人工合并项;hooks、settings.json、`.gitignore` 未变。

