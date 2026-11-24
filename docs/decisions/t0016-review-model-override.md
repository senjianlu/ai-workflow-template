# t0016:评审模型缺省用 Codex 默认配置,用户点名时经 plan.md frontmatter 指定

- 日期:2026-11-24
- 背景:两个评审脚本启动 Codex 时不传模型参数,用的是 `~/.codex/config.toml` 的
  默认模型。1.5.0 的 plan 评审中用户点名换一个模型,当时只能在任务之外放一个临时
  包装命令,往 `codex exec` 里塞 `-m`:每一轮都要保证包装命令生效,漏了就悄悄回到
  默认模型,事后也看不出某一轮用的是哪个模型。
- 决定:
  1. 默认不指定。用户没有点名时,两级评审都用 Codex 自身配置的默认模型与推理
     强度,脚本调用 codex 的参数与此前逐项相同。
  2. 载体是当前任务 plan.md frontmatter 的四个可选字段:plan 评审读
     `plan_review_model` / `plan_review_effort`,实现评审读 `impl_review_model` /
     `impl_review_effort`;分别转成 `codex exec` 的 `-m <值>` 与
     `-c model_reasoning_effort="<值>"`。四个字段互相独立;解析口径同
     `plan_review_max_rounds`(只认首个 `---` 块内行首的字段,裸值、不加引号)。
  3. 脚本只校验形态(模型:以字母或数字开头,只含字母、数字与 `. _ : / -`;
     强度:小写字母),不维护模型名与强度的枚举。形态不对 → exit 3、评审未启动;
     取值是否受支持由 Codex 判定,不支持时 `codex exec` 以非零退出,按既有的
     "codex exec 执行失败"处理。两种情况都不发布评审、不消耗轮次。
  4. 写入约束同 [t0003](t0003-configurable-review-round-caps.md):字段只在用户
     明确点名后写入,并在方案摘要或实现记录中声明;AI 不得自行写入或建议性写入。
     指定只对当前任务有效。
  5. 被否掉的备选:环境变量或脚本参数——不留痕迹,每一轮都要重新传,开发 AI 的
     上下文被压缩后容易漏传而回到默认模型;项目级配置文件——多一个载体,而
     用户的用法是按任务点名。
- 影响:
  - 默认路径零变化;plan 模板不加新字段。
  - 涉及面:plan-review.sh、review.sh、CLAUDE.md、rawf-plan 与 rawf-review 两个
    skill、README「机制速览」。
  - 有字段生效时,脚本在启动 codex 前向 stderr 打印一行;评审文件不记录所用
    模型,追溯靠 plan.md frontmatter 与方案摘要、实现记录里的声明。
  - 在 plan 评审的两轮之间改 `plan_review_*`,改动会出现在下一轮的修订 diff 里;
    它不是方案内容,不做特殊处理。
  - 推理强度的可选值由 Codex 服务端决定,随 Codex 版本变化,模板不跟踪。
