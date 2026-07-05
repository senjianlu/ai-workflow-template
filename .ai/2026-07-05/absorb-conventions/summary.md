---
task: absorb-conventions
date: 2026-07-05
rounds: 2
verdict: pass
---

# 任务小结:吸收工程化约定(docs 树/Skill 基线/可执行提交规范/迁移清单)

## 改动

| 文件 | 摘要 |
|---|---|
| `docs/README.md`、`docs/architecture.md`、`docs/decisions/README.md`(新增) | 持久设计文档树:docs/ 存现状真相、.ai/ 存过程痕迹;架构骨架与轻量决策记录约定;回写纪律 |
| `.gitmessage`、`.githooks/commit-msg`(新增) | 提交信息模板 + 零依赖 commit-msg 钩子(Conventional Commits、11 类型、可选 scope、≤72 字符按 UTF-8 字符计、三级 fail-closed 长度校验) |
| `AGENTS.md` | 硬规则补 docs/ 分工;「Git 提交规范」重写(rawf 标记改 footer `Rawf:`);新增「Skill 基线」节(项目内建/每机自装) |
| `CLAUDE.md` | 硬规则补:改架构/决策须收尾前回写 docs/ |
| `.claude/skills/rawf-report/SKILL.md` | 汇报流程新增回写检查步骤;提交信息格式对齐新规范 |
| `README.md` | 「开新项目」扩为 7 步(git config 启用、Skill 基线);新增「存量项目迁移」节(知识层先迁→工作流层替换,顺序不可倒) |

操作:本仓库已启用 `core.hooksPath=.githooks`、`commit.template=.gitmessage`。

## 评审历程

| 轮次 | 结论 | 关键问题 |
|---|---|---|
| 01 | fail | R-01(blocker):settings.json 混入方案外自动写入的权限块;R-02(major):locale 不可用时钩子长度校验 fail-open |
| 02 | **pass** | 两项修复确认;评审独立执行 23 项断言全过,无新问题、无遗留 minor |

## 遗留 minor 及处置

(无)

## 备注

- 回写检查(rawf-report 第 1 步,本任务首次执行):判定"否"——本模板
  仓库的 docs/ 是供下游项目裁剪的占位骨架,模板自身机制的权威文档是
  README「机制速览」,不向 docs/ 回写,以保持骨架纯净。
- 钩子相对 dopilot 蓝本的适配:长度按 UTF-8 字符计(中文摘要不被字节
  误判)、句号检查兼收"。"、三级 fail-closed;回归用例 TC-11(wc 失效
  不放行)、TC-12(settings.json 清洁)已入驱动。
- 自测驱动:scratchpad/absorb-tests/run.sh,19 断言。
