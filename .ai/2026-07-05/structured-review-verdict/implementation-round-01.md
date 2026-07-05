---
task: structured-review-verdict
round: 01
date: 2026-07-05
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/schemas/review.schema.json` | 新增:评审结论 Schema(verdict 枚举 / issues[]{severity 四级枚举,id,summary,detail} / overall,均必填,additionalProperties: false) |
| `.ai-workflow/scripts/review.sh` | ① `codex exec` 追加 `--output-schema`(指向副本内 schema)② raw 文件改名 `.review-raw-<NN>.json`,hash_excludes 同步 `.review-raw-*` ③ 解析段重写:jq 校验 JSON → 提取 verdict(含 enum 守卫)→ 按判定规则从严重度清单推导 → 与自报 verdict 交叉校验,任一失败取回 raw 供排查并 exit 3 ④ 发布内容由拷贝 raw 改为 `render_review()` jq 渲染 markdown(问题按严重度排序、plan-blocker 置顶、与历史轮次同构),渲染调用带 `--arg render 1` 特征标记;原子锁与 mv -n 发布机制未动 |
| `.ai-workflow/prompts/review.md` | 输出格式段重写:废除末行 VERDICT 契约,改为 JSON 字段语义说明,并告知评审者脚本会独立复核结论 |
| `.gitignore` | `.ai/**/.review-raw-*.md` → `.ai/**/.review-raw-*` |
| `README.md` | 依赖节注明 codex 版本需支持 --output-schema;机制速览改为结构化评审+推导校验;输出契约位置更新为 schema+prompt 字段语义 |

## 修复对照

不适用(首轮)。

## 测试结果

自测驱动重写(scratchpad rawf-tests/run-tests.sh):stub codex 全部模式改为输出
JSON;新增假 jq(仅对携带 `--arg render 1` 特征参数的渲染调用按 FAIL_RENDER
注入失败,其余透传真 jq,经 REAL_JQ 定位)。驱动中 S-01〜S-08 对应本 plan 的
TC-01〜TC-08;回归块沿用上一任务用例编号,对应本 plan 的 TC-09。

| plan 编号 | 驱动标号 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | S-01 | 通过 | schema 为合法 JSON;required=issues,overall,verdict;severity 枚举=plan-blocker,blocker,major,minor |
| TC-02 | S-02 | 通过 | rc=0;渲染文件含"## 问题清单"+"无"+末行 `VERDICT: pass` |
| TC-03 | S-03 | 通过 | rc=1;渲染含 `- [major] R-01 问题概述` 与 `详情:src/app.py:1` |
| TC-04 | S-04 | 通过 | 旧文本格式输出 → rc=3,stderr 含"不是合法 JSON",`.review-raw-01.json` 取回主任务目录,无 review-round 文件 |
| TC-05 | S-05 | 通过 | verdict=pass 但含 blocker → rc=3,stderr 含"矛盾",不发布 |
| TC-06 | S-06 | 通过 | 仅 plan-blocker + pass → rc=0(不计入判定),渲染含置顶 plan-blocker 条目 |
| TC-07 | S-07 | 通过 | FAIL_RENDER 注入 → rc=3、review-round 数=0、.review-out 残留=0、stderr 含"渲染评审文件失败";去注入重试 rc=0 正常发布 |
| TC-08 | S-08 | 通过 | 乱序输入(minor,blocker,plan-blocker)→ 渲染顺序 `plan-blocker,blocker,minor` |
| TC-09 | TC-02〜TC-23 | 通过 | 上一任务全部 22 项既有用例(隔离/锁/哈希/闸门/原子发布)JSON 化后全量复跑通过;其中 TC-20 的陈旧 raw 改为 `.review-raw-01.json` 内容为合法 pass JSON,仍被正确拒用 |
| 真机 E2E | /rawf-review | 见评审轮 | 本轮评审即真实 `codex exec --output-schema` 执行 |

合计 30/30 通过(S-01〜S-08 + 回归 22 项)。`bash -n` 语法检查通过;全量自测后
`git diff HEAD -- .claude/settings.json` 为空(本会话一条自动写入的授权已按
既有做法迁移至不入库的 settings.local.json 后恢复)。

## 与方案的偏差

- 无功能性偏差。实现细节上较 plan 增加一处防御:verdict 字段的 enum 守卫
  (缺失/非法值时给出明确报错而非落入"矛盾"分支的含混信息),属 plan"字段
  提取"步骤的自然延伸,未扩大改动范围。
