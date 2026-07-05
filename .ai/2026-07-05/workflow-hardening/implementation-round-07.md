---
task: workflow-hardening
round: 07
date: 2026-07-05
---

# 实现记录:第 07 轮

> 本轮依据第 06 轮评审后用户的明确授权("授权第 7 轮修复")执行。

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 评审结论改为原子发布:先在任务目录(同文件系统)写全临时文件 `.review-out-$nn.$$`,再 `mv -n` 原子改名为 `review-round-$nn-$verdict.md`;cp 失败只清理临时文件并 exit 3,不留半成品结论、不阻断重试;`mv -n` 被并发抢先(目标已存在)时清理临时文件并 exit 3 |
| `.gitignore` | 新增 `.ai/**/.review-out-*`:极端情形(cp 与 mv 之间被 SIGKILL)残留的发布临时文件不入库 |

## 修复对照

| 评审问题编号 | 严重度 | 修复方式 |
|---|---|---|
| R-01(第 06 轮) | major | `cp <目标结论>` 替换为"临时文件 + `mv -n` 原子 rename"。cp 中途失败时目标是临时文件,失败即 `rm -f` 清理,主工作区不出现半成品 `review-round-*.md`,同轮检查不会被半成品阻断,重试可正常完成。`mv -n` 的不覆盖语义 + `[ -e "$tmp_out" ]` 复检,兼作发布层并发防线(锁之后的深度防御)。TC-24 验证:注入 cp 失败 → rc=3、无半成品、无残留临时文件,随后重试 rc=0 正常发布 |

## 测试结果

新增假 `cp`(FAIL_CP 置位时使 `.review-out-*` 目标的 cp 失败,其余透传真 cp);TC-02〜TC-24 全量复跑:

| 编号 | 结果 | 证据 |
|---|---|---|
| TC-02〜TC-23 | 通过(回归) | 驱动输出 22 条 `PASS`,判定条件与第 06 轮一致;fixture 的 .gitignore 同步加入 `.review-out-*` 排除 |
| TC-24 | 通过 | `TC-24 PASS (发布失败 rc=3 无半成品/无残留临时文件,重试成功 rc=0)`:FAIL_CP 下 rc1=3、review-round 文件数=0、.review-out-* 残留数=0;去掉 FAIL_CP 重试 rc2=0 且正常生成 review-round-01-pass.md |
| 语法检查 | 通过 | `bash -n` review.sh 无输出 |
| settings.json 复核 | 通过 | 全量自测后 `git diff HEAD --quiet -- .claude/settings.json` 成立 |

合计 23/23 通过。

## 与方案的偏差

- 本轮为评审修复轮,改动严格限于第 06 轮 R-01,无评审范围外改动。
- 至此"检查-评审-发布"全链路原子性补全:原子锁(第 06 轮)保证过程互斥,
  原子 rename(本轮)保证结论发布不可分割,发布层的正确性达到 POSIX 文件
  系统保证的终点。
