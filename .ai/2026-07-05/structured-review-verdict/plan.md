---
status: approved
task: structured-review-verdict
date: 2026-07-05
approved_at: 2026-07-05 17:14:00
---

# 方案:评审结论结构化(--output-schema 替代末行 VERDICT 解析)

## 背景与目标

review.sh 目前靠 `sed` 解析评审自然语言输出的末行 `VERDICT: pass|fail`
([review.sh:102](../../..//.ai-workflow/scripts/review.sh))。Codex CLI 现已提供官方结构化输出
`codex exec --output-schema <schema.json>`(本机 v0.142.5 经 `codex exec --help`
实测支持),这是 2026 年官方推荐的"自动化流程需要稳定字段"方案。目标:

1. 评审最终输出强制符合 JSON Schema,脚本用 jq 解析,消除自然语言末行契约的脆弱性;
2. 附带强化:脚本按严重度清单**推导** pass/fail(判定规则本就是严重度的纯函数),
   与评审者自报 verdict 交叉校验,矛盾结论直接判执行异常,不再被采纳;
3. 评审历史文件保持人类可读的 markdown(由 JSON 渲染,与既有轮次文件同构),
   `.ai/` 审计痕迹的阅读体验不变。

## 改动范围

| 文件 | 动作 |
|---|---|
| `.ai-workflow/schemas/review.schema.json` | 新增:评审结论 JSON Schema |
| `.ai-workflow/scripts/review.sh` | ① raw 文件改名 `.review-raw-<NN>.json`(hash_excludes 同步为 `.review-raw-*`)② codex exec 追加 `--output-schema`(指向副本内 schema)③ 解析段重写:jq 校验/提取/推导/交叉校验 ④ 发布内容由"拷贝 raw"改为"jq 渲染 markdown 后原子发布"(锁与 mv -n 机制不动) |
| `.ai-workflow/prompts/review.md` | 输出格式段重写:废除末行 VERDICT 契约,改为 JSON 字段语义说明(id 格式 R-NN、severity 取值、detail 须含文件:行号/说明/修复建议) |
| `.gitignore` | `.ai/**/.review-raw-*.md` → `.ai/**/.review-raw-*` |
| `README.md` | 机制速览:"末行 VERDICT"改为"--output-schema 结构化结论,由 JSON 渲染评审文件";依赖节注明 Codex CLI 需支持 --output-schema 的版本 |

**明确不动**:gate-plan.sh、gate-review.sh、review-standards.md(严重度定义与
判定规则不变)、五个 skills、templates、review.sh 的隔离副本/原子锁/mv -n 原子
发布机制、既有历史评审文件。

## 实现方案

### Schema(OpenAI structured-output 兼容子集,不用 pattern 等扩展关键字)

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["verdict", "issues", "overall"],
  "properties": {
    "verdict": { "type": "string", "enum": ["pass", "fail"] },
    "issues": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["severity", "id", "summary", "detail"],
        "properties": {
          "severity": { "type": "string",
            "enum": ["plan-blocker", "blocker", "major", "minor"] },
          "id": { "type": "string" },
          "summary": { "type": "string" },
          "detail": { "type": "string" }
        }
      }
    },
    "overall": { "type": "string" }
  }
}
```

### review.sh 解析段(替换现第 102-109 行)

```bash
# 结构化解析:JSON 合法性 → 字段提取 → 按判定规则推导并交叉校验
if ! jq -e . "$raw_copy" >/dev/null 2>&1; then
  cp "$raw_copy" "$task_dir/$raw_name" 2>/dev/null || true
  echo "评审输出不是合法 JSON,原始输出保留在 $task_rel/$raw_name" >&2
  exit 3
fi
verdict=$(jq -r '.verdict // empty' "$raw_copy")
blocking=$(jq '[.issues[] | select(.severity == "blocker" or .severity == "major")] | length' "$raw_copy")
[ "$blocking" -gt 0 ] && derived=fail || derived=pass
if [ "$verdict" != "$derived" ]; then
  cp "$raw_copy" "$task_dir/$raw_name" 2>/dev/null || true
  echo "评审自报结论($verdict)与严重度清单推导($derived)矛盾,按判定规则该评审无效,原始输出保留在 $task_rel/$raw_name" >&2
  exit 3
fi
```

### 渲染与发布(发布段结构不变,tmp_out 的来源由 cp 改为 jq 渲染)

按严重度权重排序(plan-blocker → blocker → major → minor),渲染为与既有
历史文件同构的 markdown(`# 评审:第 NN 轮` / `## 问题清单` / `## 总评` /
末行 `VERDICT: <verdict>`,空清单写"无"),jq 渲染进 `$tmp_out` 后沿用
`mv -n` 原子发布;渲染调用携带 `--arg render 1` 特征参数(供测试故障注入
识别,对 jq 语义无影响)。渲染失败走既有的"清理临时文件 + exit 3"分支。

### prompt 输出格式段

改为:"你的最终回复将被 --output-schema 强制为 JSON,字段语义:verdict 按
review-standards.md 判定规则给出;issues 每项 id 为 R-NN 两位编号,severity
取 plan-blocker|blocker|major|minor,summary 一句话结论,detail 含 文件:行号 /
问题说明 / 修复建议;无问题时 issues 为空数组;overall 两三句总评。"

## 测试用例

沿用上一任务的 fixture + stub 驱动(scratchpad rawf-tests/run-tests.sh):
stub codex 的各模式输出由文本改为 JSON;新增假 jq(仅对含 `--arg render 1`
特征参数的调用注入失败,其余透传真 jq)。

| 编号 | 前置条件 | 步骤 | 预期结果 |
|---|---|---|---|
| TC-01 | 改动完成 | `jq -e .` 校验 schema 文件;检查 required/enum 字段 | schema 为合法 JSON 且含 verdict/issues/overall 三必填与四级 severity 枚举 |
| TC-02 | fixture;stub 输出 `{"verdict":"pass","issues":[],"overall":"ok"}` | `bash review.sh; echo $?` | rc=0;生成 review-round-01-pass.md;内容含"## 问题清单"+"无"+末行 `VERDICT: pass` |
| TC-03 | fixture;stub 输出 verdict fail + 一条 major issue | 同上 | rc=1;-fail.md;渲染含 `[major] R-01` 与详情行 |
| TC-04 | fixture;stub 输出非 JSON 文本(旧格式 `VERDICT: pass`) | 同上 | rc=3;stderr 含"不是合法 JSON";raw 取回主任务目录;无 review-round 文件 |
| TC-05 | fixture;stub 输出 verdict=pass 但 issues 含一条 blocker | 同上 | rc=3;stderr 含"矛盾";不发布任何 review-round 文件 |
| TC-06 | fixture;stub 输出 verdict=pass + 仅一条 plan-blocker | 同上 | rc=0(判定规则:plan-blocker 不计入 pass/fail);渲染中 plan-blocker 置顶 |
| TC-07 | fixture;假 jq 对渲染调用注入失败 | 同上;随后去掉注入重试 | 首跑 rc=3,无半成品 review-round、无 .review-out 残留;重试 rc=0 正常发布(承接原 TC-24 语义) |
| TC-08 | fixture;stub 输出乱序混合(minor、blocker、plan-blocker 各一,verdict=fail) | 同上 | rc=1;渲染顺序为 plan-blocker → blocker → minor |
| TC-09 | 上一任务全部既有用例 | stub 各模式改为 JSON 输出后全量复跑 TC-02〜TC-23(隔离/锁/哈希/闸门等) | 逐条判定与上一任务一致,全通过 |
| 真机 E2E | 本任务自身走 /rawf-review | 真实 codex exec --output-schema 评审本任务改动 | 评审正常产出结构化结论并渲染为评审文件(执行本身即验证) |

## 风险与回滚

- **Codex 版本兼容**:旧版 codex 无 `--output-schema` 时 exec 直接报错,落入
  既有 exit 3 路径,不会误判;README 依赖节注明版本要求(本机 v0.142.5 实测支持)。
- **结构化约束下评审表达受限**:detail 为单字符串字段,多行细节被压平;prompt
  中明确字段语义以保信息量,旧版自然语言的排版自由度换取解析确定性。
- **一致性校验更严**:评审者自报结论与严重度矛盾时,从"以 VERDICT 为准"变为
  exit 3 重跑,可能偶发增加重跑;矛盾结论本就不应被采纳,属预期收紧。
- **渲染层新增 jq 依赖点**:jq 本就是模板硬依赖(hooks 使用,README 已列),
  无新增外部依赖。
- **回滚**:单 commit,`git revert` 整体回滚;历史评审文件不受影响(只增不改)。
