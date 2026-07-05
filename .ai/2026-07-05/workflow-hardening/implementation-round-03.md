---
task: workflow-hardening
round: 03
date: 2026-07-05
---

# 实现记录:第 03 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `.claude/settings.local.json`(不入库) | 承接全部本机个人授权:原有 8 条 + 本会话自动写入 settings.json 的 3 条(评审命令、update-config skill)+ 2 条自测所需(bash -n、测试驱动脚本) |
| `.claude/settings.json` | `git checkout` 恢复至 HEAD,当前 diff 为空 |
| `.ai-workflow/scripts/review.sh` | `workspace_hash()` 对符号链接不再跟随读内容,改按 `symlink <路径> -> <目标>` 记账,普通文件与符号链接互换即改变哈希 |

## 修复对照

| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| R-01 | blocker | 根因:本会话权限系统在用户每次点"始终允许"时自动把授权写入**受跟踪的**项目 settings.json——第 02 轮记录的复核证据在写下时为真,随后启动第 02 轮评审这一动作本身再次触发自动写入,评审时已失效(新增的 3 条:第 02 轮评审命令模式、update-config skill 两条)。根治而非再擦一次:全部个人授权迁移至 `.claude/settings.local.json`(经 `git check-ignore -v` 确认被 `~/.config/git/ignore` 全局排除,永不入库),settings.json 恢复至 HEAD;后续评审/自测所需命令模式均已在本地授权中,不会再触发新的授权写入。复核证据:`git diff HEAD -- .claude/settings.json` 为空,且在全量自测跑完后**复查仍为空**(见测试结果末行) |
| R-02 | major | `workspace_hash()` 中对 `-L` 的路径输出 `symlink <路径> -> <目标>` 行替代 `shasum` 跟随读内容;"未跟踪普通文件替换为指向同内容文件的符号链接"从此改变哈希。新增 TC-16 验证,并全量回归 |

## 测试结果

fixture 增加与 `src/new.py` 同内容的未跟踪文件 `src/twin.py`,stub codex 增加 `swap-symlink` 行为(`rm src/new.py; ln -s twin.py src/new.py`,输出 VERDICT: pass);TC-02〜TC-16 全量复跑:

| 编号 | 结果 | 证据 |
|---|---|---|
| TC-02〜TC-15 | 通过(回归) | 驱动输出 14 条 `PASS`,判定条件与第 02 轮一致 |
| TC-16 | 通过 | `TC-16 PASS (rc=3,同内容符号链接替换被识别)`——修复前该替换 pre/post 哈希相同、review.sh 返回 0(即上一轮 R-02 的复现),修复后 rc=3 且 stderr 报"改动了工作区" |
| 语法检查 | 通过 | `bash -n` review.sh 无输出 |
| R-01 复核 | 通过 | 全量自测(15 项)执行完毕后:`git diff HEAD --quiet -- .claude/settings.json` 成立,输出"settings.json 仍无 diff";`jq` 校验两个 settings 文件 JSON 合法;`git check-ignore -v .claude/settings.local.json` 命中全局排除规则 |

合计 15/15 通过。

## 与方案的偏差

- 本轮为评审修复轮,改动严格限于 R-01、R-02,无评审范围外改动。
- `.claude/settings.local.json` 不在原 plan 改动范围清单中:它不入库、不属于模板交付物,仅为承接个人授权(R-01 根治的必要一步);受跟踪文件的改动范围与 plan 一致。
