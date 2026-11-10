# 来自 cscheap-catalog 的反馈:模板 1.3.0 里不合理的四处(2026-11-10)

> 来源:2026-11-10 把 cscheap-catalog(由模板 1.2.1 创建,尚未提交)对齐到模板 1.3.0 时发现(catalog 仓 ADR 0019)。
> 每条给出事实、可复核的命令、影响与建议;都不阻断升级本身,由模板任务裁决是否修。

## 1. 模板决策与派生仓决策撞号

**事实**:模板 1.3.0 新增 `docs/decisions/0013-workers-standard-stack.md`。派生仓经 Use this template 带入 0001 ~ 0012,
项目决策自 0013 起编:

| 仓 | 自有决策 | 与模板 0013 |
|---|---|---|
| cscheap-telegram | 0013 ~ 0015 | 撞 |
| cscheap-link | 0013 ~ 0015 | 撞 |
| cscheap-catalog | 0013 ~ 0019 | 撞 |

```bash
for r in cscheap-telegram cscheap-link cscheap-catalog; do ls ../$r/docs/decisions | grep '^0013'; done
ls docs/decisions | grep '^0013'
```

**影响**:1.3.0 升级指引写「存量项目可不拷」绕开了这一次,但模板每新增一条决策都会再撞;派生仓 AGENTS.md / ADR
里写「0013」已有歧义(catalog 只能写成「模板决策 0013」)。新建项目带入模板 0013 后,项目决策从 0014 起,
同一组织内各仓的「项目决策起始号」随创建时的模板版本漂移。

**建议**(任选其一):
- 模板决策改独立前缀或子目录,如 `docs/decisions/template/NNNN-*.md` 或 `T0013-*.md`,派生仓的 `NNNN` 整段留给项目;
- 或规定项目决策从固定高位起编(如 0100),模板占 0001 ~ 0099。
两种都要在 README「开新项目 / 存量项目迁移」与 `docs/decisions/README.md` 模板里写明,并给已撞号的三仓一句迁移口径
(建议:存量不改号,只在索引注明)。

## 2. 参考仓 cscheap-catalog 尚未提交

**事实**:AGENTS.md「Cloudflare Worker」节与决策 0013 写「参考 senjianlu/cscheap-telegram 与 cscheap-catalog」,
但 catalog 的远端只有模板生成的初始提交,骨架全部在本地暂存区:

```bash
git -C ../cscheap-catalog log --oneline origin/master   # f19735a Initial commit
git -C ../cscheap-catalog status --short | wc -l        # 52(2026-11-10)
```

**影响**:照模板去看参考仓的人(或 AI 工具)看到的是未裁剪的模板占位,不是 Worker 收敛形。并且模板 0013 引用的
「catalog 其 0014」内容在 1.3.0 发布后又变了(catalog 0019 摊平了 `sync/`),参考对象在发布当时并不稳定。

**建议**:catalog 提交推送后再把它列为参考仓;或 1.3.x 先只点名 telegram。发布纪律里加一条「被点名的参考仓须已推送
且引用处可在远端复核」。

## 3. 「领域逻辑超过三个文件成目录」缺判定口径

**事实**:规则原文(AGENTS.md 工程约定第 2 条、目录表 Worker 列):「横切单文件模块平铺于根;每个外部协议一个目录;
领域逻辑超过三个文件成目录」。没有定义哪些文件算「领域逻辑」、哪些算「横切」。catalog 根上除四个基座文件
(`index.ts` / `app.ts` / `config.ts` / `http.ts`)外还有:

| 文件 | 是什么 | 算领域? |
|---|---|---|
| `items.ts` | `items` 表读写 | 是 |
| `sync.ts` | 每日同步编排 | 是 |
| `ndjson.ts` | 通用流式解析工具 | 两可 |
| `link.ts` | 指向 cscheap-link 的地址拼装(一个函数) | 两可(也可说是「外部协议」,那就该是目录) |

按最宽口径是四个 → 该成目录;按最窄口径是两个 → 平铺。catalog 选了平铺(其 ADR 0019)。telegram 的
`binding.ts` / `delivery.ts` / `i18n.ts` 同样两可。

**影响**:同一条规则不同人(或评审)得出相反结论,plan 评审会就此反复。

**建议**:补一句口径,例如「领域逻辑 = 本仓业务规则与其数据读写;通用工具(解析、编码)与单函数适配不计入;
计数只算源文件,不含测试」;并写明「外部协议目录」的门槛(是否一个函数也要成目录)。给一个正例一个反例。

## 4. 模板的 CHANGELOG.md 被原样带进派生仓,且不在受管路径归类里

**事实**:CHANGELOG 头部归类只有两类——可整体替换(`.ai-workflow/`、`.claude/hooks/`、`.claude/skills/rawf-*`、
`.claude/settings.json`、`.githooks/`、`.gitmessage`)与需人工合并(`AGENTS.md`、`CLAUDE.md`、`README.md`、
`.agents/skills/`、`skills-lock.json`)。`CHANGELOG.md`、`logo.svg`、`.ai/` 里的模板任务历史不在任何一类,README
「开新项目」八步也没提它们。结果:

```bash
sed -n 3p ../cscheap-telegram/CHANGELOG.md   # 本文件记录 ai-workflow-template 的版本历史…
ls ../cscheap-telegram/.ai | head -3         # 2026-07-05 …(模板自己的任务目录)
```

telegram 上线至今 CHANGELOG 仍是模板的版本历史;catalog 手工换成了项目自己的;link 则没带 CHANGELOG、logo 与模板历史
(其 0013 明说「不复制模板历史任务、logo」)。三仓三种处理。

**影响**:派生仓的 CHANGELOG 讲的是别的项目;`.ai/` 里几十个模板任务目录混在项目任务前面,检索与评审上下文被污染。

**建议**:README「开新项目」加一步:`CHANGELOG.md` 重置为项目自己的、`logo.svg` 替换或删除、`.ai/` 下模板任务目录
是否保留给出明确口径(建议清空,只留 `.gitkeep`;模板历史在模板仓可查);CHANGELOG 头部归类加第三类「项目自有,
创建后即脱钩」。

## 附:升级 1.2.1 → 1.3.0 的实际操作记录(供核对升级指引)

- `.ai-workflow/` 整体替换:只有 `review-standards.md` 与 `TEMPLATE-VERSION` 两个文件有差异,与指引一致。
- `review-standards.md`「技术栈评审关注点」:指引说「若有项目自改,先摘出再覆盖」,可行;catalog 保留了自改的 D1 与
  同步正确性两条,TypeScript 与 Workers 条取模板。
- `.gitignore`:catalog 已有相同的 Workers 块,另多一行 `coverage/`。
- AGENTS.md 人工合并:Worker 节与目录表列可原文并入,无冲突。
