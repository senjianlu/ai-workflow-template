---
task: absorb-conventions
round: 01
date: 2026-07-05
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `docs/README.md`(新增) | docs/ 与 .ai/ 分工(持久真相 vs 过程痕迹)、组织表、回写纪律 |
| `docs/architecture.md`(新增) | TEMPLATE 占位骨架:系统形态/组件/数据/部署 |
| `docs/decisions/README.md`(新增) | 决策记录约定:`NNNN-<slug>.md` 四段式,推翻须新增记录不删历史 |
| `.gitmessage`(新增) | 提交信息模板:header/正文/footer 提示、类型清单、启用命令 |
| `.githooks/commit-msg`(新增,+x) | 零依赖 POSIX sh 钩子,校验 header 格式/≤72 字符/句号,放行 Merge/Revert/fixup!/squash! |
| `AGENTS.md` | 硬规则补 docs/ 分工一行;「Git 提交规范」重写(11 类型、可选 scope、Rawf footer、启用命令);新增「Skill 基线」节(项目内建/每机自装二分,TEMPLATE 占位) |
| `CLAUDE.md` | 硬规则补一行:改架构/决策须在收尾前回写 docs/ |
| `.claude/skills/rawf-report/SKILL.md` | 汇报第 1 步新增回写检查;提交信息格式改为 header + `Rawf:` footer;步骤重编号 1〜9 |
| `README.md` | 「开新项目」扩为 7 步(启用 git config、Skill 基线、架构落 docs);新增「存量项目迁移」节(知识层先迁→工作流层替换→前置依赖→提交规范衔接) |

操作(非文件):本仓库已执行 `git config core.hooksPath .githooks` 与
`git config commit.template .gitmessage`(仅本克隆生效)。

## 修复对照

(第 1 轮,不适用)

## 测试结果

驱动:`<scratchpad>/absorb-tests/run.sh`,一次性执行全部用例,输出
`PASS=15 FAIL=0`、`EXIT_CODE=0`。逐条:

| 编号 | 结果 | 证据 |
|---|---|---|
| TC-01 | 通过 | `feat(server): add x` → exit 0(PASS TC-01) |
| TC-02 | 通过 | 中文 header + 正文 + `Rawf:` footer 完整消息 → exit 0;补充断言 TC-02b:30 汉字 subject(字节数 >72、字符数 ≤72)→ exit 0,验证按字符计数 |
| TC-03 | 通过 | `update stuff` → exit 1,stderr 含"期望"与"types"清单 |
| TC-04 | 通过 | 74 字符 header → exit 1,stderr 含"超过 72" |
| TC-05 | 通过 | 英文句号(TC-05a)、中文句号(TC-05a2)、`feat(BadScope): x`(TC-05b)→ 均 exit 1 |
| TC-06 | 通过 | `Merge branch 'x'`、`fixup! foo` → 均 exit 0 |
| TC-07 | 通过 | 纯注释+空行消息 → exit 1(空 header 拒绝) |
| TC-08 | 通过 | 临时仓库 `core.hooksPath` 指向模板钩子:`git commit -m 'bad message'` 被拒(TC-08a);`git commit -m 'chore: 初始化'` 成功且 rev-list 计数 =1(TC-08b) |
| TC-09 | 通过 | `sh -n` 与 `bash -n` 均零输出 |
| TC-10 | 通过 | 5 个新文件存在;AGENTS.md 无"摘要后附 (rawf:"残留、含 docs 指引与「Skill 基线」;rawf-report 含"回写检查"与 `Rawf:`;README 含启用步骤与「存量项目迁移」 |

## 与方案的偏差

- **钩子相对 dopilot 蓝本的两处适配**(plan 允许"改编",此处明确):
  ①长度检查固定 `LC_ALL=en_US.UTF-8`,中文 subject 按字符计数——原版
  在 C locale 下按字节,常规中文摘要会被误判超长(TC-02b 为此增设);
  ②句号检查兼收中文"。"。
- **`git config commit.template .gitmessage` 一并写入启用命令**:plan
  仅列 `core.hooksPath`;交付 .gitmessage 而不给启用方式则形同虚设,
  属于第 3 项的自然补全,README/AGENTS.md/.gitmessage 三处一致。
- **README 迁移节的呈现顺序调整**:plan 原文先"工作流层"后"知识层",
  落地时改为知识层在前并标注"顺序不可倒"——plan 本身要求"搬入后才可
  替换文件",先迁后换是该要求的直接推论,防按序照做时先覆盖后迁移。
- 其余按 plan 实现,无范围外改动。
