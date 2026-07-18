---
status: approved
task: review-readonly
date: 2026-07-18
approved_at: 2026-07-18 18:00 (plan 评审 2 轮收敛后经用户确认)
---

# 方案:评审只读直审原仓库(取消副本),测试核验改走证据打回协议

## 背景与目标

现行 review.sh 为让评审者可写(跑测试产生缓存/临时文件)而将整个工作区
`cp -Rp` 到 /tmp 副本、以 workspace-write 沙箱评审。该机制的代价已被证实
过高:下游 cscheap-frontend 2026-07-17 因内存/swap 耗尽两次整机失去响应,
全量复制(实测单次 2.4G)是工作流侧主要放大器;而尝试"副本瘦身"
(rsync 排除 + 依赖软链,同日任务 slim-review-copy,已废弃)又引出软链
写穿探针、`..` 父目录穿越、/tmp 布局护栏等一整层新复杂度——为"评审者
能跑受限单元测试"这一点残余能力持续付出的机制成本,超过其核验收益。

用户决定(推翻 docs/decisions/0004 中曾被否的备选 A,依据是上述新证据
与历史事实——既往任务中 Codex 复跑与 Claude 自测从未出现结果分歧,
分歧全部发生在证据完备性上,而证据完备性只读即可审):

- review.sh 取消副本,以 `--sandbox read-only` 直审原仓库(与
  plan-review.sh 同构,该形态已稳定运行多轮);
- 评审者不再运行任何测试;全部测试用例一律核验任务目录 `evidence/`
  中实现者留存的完整原始输出,证据不足 → fail 并**在问题 detail 中
  点名需要补交的证据清单**(打回协议),由实现者补跑补交进入下一轮;
- 保留完整性指纹(pre/post hash)作为双保险:防主会话在评审期间并发
  写入,亦兜底沙箱失效。

## 改动范围

| 文件 | 改动 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 核心:删除副本机制(mktemp/复制/raw 回搬),`codex exec --sandbox read-only -C "$proj"`,raw 输出直接落任务目录(循 plan-review.sh 先例,.gitignore 与 hash_excludes 已覆盖);新增 `__workspace_hash` 测试入口(循 `__publish_round` 先例);锁、轮次、同轮唯一、指纹、解析与交叉校验、渲染、mv -n 原子发布、退出码全部保持 |
| `.ai-workflow/review-standards.md` | 重写「评审动作边界」:允许只读检索与确无写入副作用的静态检查(命令因 read-only 写失败报错时不视为代码缺陷,转证据核验);**不运行任何测试**;全部测试用例核 evidence/,证据缺失/不完整 → blocker 且 detail 必须列明需补交的证据清单,证据与记录矛盾 → blocker(虚报) |
| `.ai-workflow/prompts/review.md` | "重跑可运行用例"段改为证据核验协议表述,与新标准一致 |
| `.claude/skills/rawf-implement/SKILL.md` | 第 5 步证据条款:**所有**测试用例的完整原始输出必须落 evidence/(评审者一律不重跑测试),不再区分边界内外 |
| `README.md` | 机制速览:副本条目替换为"read-only 直审 + 指纹双保险";已知限制补一条"评审者不复跑测试,测试真实性依赖证据协议" |
| `docs/decisions/0005-review-readonly.md` | 新增决策记录:取消副本改只读直审 + 证据打回协议;记录取代 0004 的理由与新证据(事故、软链穿越面、沙箱 /tmp 默认可写),及被否备选(副本瘦身、cp -al 硬链) |
| `docs/decisions/0004-review-action-boundary.md` | 顶部加"已被 0005 取代"标注(按决策记录约定,不删除历史) |

**明确不改**:plan-review.sh(已是目标形态);gate-plan/gate-review hooks;
rawf-review skill(其锁清理、后台运行、分流规则与新机制兼容);
schemas/review.schema.json;严重度定义与判定规则(pass/fail 推导);
CLAUDE.md 硬规则(评审期间禁写由指纹继续强制)。

## 实现方案

### 1. review.sh:向 plan-review.sh 收敛

删除副本段(`sandbox_root`/`copy`/`cp -Rp`/`raw_copy` 回搬),codex 调用改:

```bash
raw="$task_dir/$raw_name"   # .review-raw-<nn>.json,直接落任务目录
rm -f "$raw"
codex exec --sandbox read-only -C "$proj" \
  --output-schema "$proj/.ai-workflow/schemas/review.schema.json" \
  --output-last-message "$raw" "$prompt" || codex_rc=$?
```

要点:

- `--output-last-message` 由 codex CLI 进程自身写入,不经受沙箱约束
  (沙箱只管模型生成的 shell 命令)——plan-review.sh 已验证该形态;
- raw 落主工作区任务目录:`.gitignore` 的 `.ai/**/.review-raw-*` 与
  hash_excludes 的 `--exclude='.review-raw-*'` 均已覆盖,不入库、不进
  指纹;异常路径不再需要"从副本抢救 raw"的 cp 逻辑,整体更简;
- 指纹(workspace_hash 与 pre/post 比对)原样保留,语义从"隔离双保险"
  变为"并发写入检测 + 沙箱失效兜底",头部注释同步;
- trap 只剩 lock 清理;退出码 0/1/3 语义不变;
- 新增 `__workspace_hash` 测试入口(置于主流程前、循 plan-review.sh
  `__publish_round` 先例):`CLAUDE_PROJECT_DIR=<夹具> review.sh
  __workspace_hash` 输出指纹,供指纹敏感性单测。

### 2. review-standards.md:动作边界重写

「评审动作边界」小节替换为:

- **允许**:读取代码与 diff、grep 检索;运行**确无写入副作用**的只读
  检查(如 `tsc --noEmit`、禁用缓存的 lint);命令因 read-only 沙箱
  写失败而报错时,不视为代码缺陷,该项转证据核验并在评审输出中注明;
- **不运行任何测试**(含单元测试——read-only 下多数 runner 需写缓存,
  且测试核验已整体改走证据协议);超时与中止条款保留(5 分钟上限);
- **证据协议**(全部测试用例统一适用):核验 evidence/ 完整原始输出,
  与实现记录交叉比对——证据缺失或不完整 → blocker,detail **必须列明
  需要补交的证据清单**(打回协议,实现者按单补交);证据与记录矛盾
  → blocker(虚报);
- 禁止条款(装依赖/build/起服务/E2E/联网)保留——read-only 下多数
  天然失败,保留为行为约束。

### 3. 文档与 skill 伴随更新

- prompts/review.md:核验测试段改为"不重跑任何用例,一律核
  {{TASK_DIR}}/evidence/ 并交叉比对;缺证据按标准打回";
- rawf-implement SKILL.md 第 5 步:所有测试用例完整原始输出必须落
  evidence/(删去"边界外才强制"的区分);
- README 机制速览与已知限制、0005 新决策、0004 顶部取代标注,见改动
  范围表。

## 测试用例

TC-01/02/03 需真实 codex,由实现者自测执行,codex 完整 stdout/stderr
与包装捕获的退出码一并落 `evidence/`;其余为纯脚本单测。其中 TC-07/08
用 **codex 桩**(PATH 前置的假 codex 脚本)把断言绑定到 review.sh 的
**实际执行路径**:桩在被 review.sh 调用的时刻记录完整 argv、探测副本
目录、可选地篡改仓库,分别证明"传参只读且直审原仓库"“运行期无副本"
“指纹否决受污染结果"三件事;TC-02 的真实沙箱探针与 TC-07 的传参断言
组合成完整证据链(脚本确实传 read-only + read-only 确实拦得住)。

| 编号 | 前置条件 | 步骤 | 预期结果 |
|---|---|---|---|
| TC-01 | $HOME 下夹具项目:拷贝本仓 .ai-workflow、approved 的小任务 plan(新增 greet.sh)、实现记录、**齐全的** evidence/;git 已提交基线,greet.sh 为未提交改动 | 包装命令跑真实一轮:`CLAUDE_PROJECT_DIR=<夹具> bash review.sh; rc=$?`,前后各列一次 `/tmp` 与 `$TMPDIR` 下 `rawf-review-*` 目录 | 产出 review-round-01-<verdict>.md;退出码与 verdict 一致(pass=0/fail=1);运行前后均无 rawf-review-* 副本目录(副本机制确已移除);无"评审无效"报错(指纹通过);完整输出+退出码留存 evidence/ |
| TC-02 | TC-01 夹具 | `codex exec --sandbox read-only -C <夹具>` 令其执行 `touch probe.txt` 并如实报告(验证 read-only 沙箱在本环境的强制力,与 TC-07 的传参断言组成证据链) | codex 退出码 0;输出含写入被拒证据;夹具工作区无 probe.txt、`git status` 无新增(只读强制生效);完整输出留存 |
| TC-03 | 同 TC-01 夹具,但 evidence/ 置空(实现记录仍声称测试通过) | 包装命令跑真实一轮 review.sh | verdict=fail、退出码 1;问题清单含 blocker,其 detail 点名需要补交的证据(打回协议生效);完整输出留存 |
| TC-04 | 夹具 git 工作区;`__workspace_hash` 入口 | 取基线指纹→改动一个已跟踪文件→再取;还原后仅写 `.claude/settings.local.json` 再取 | 改已跟踪文件后指纹变化;仅动 .claude/ 时指纹不变(排除生效,后台评审期间权限记录写入不误伤) |
| TC-05 | 夹具任务目录预置 `.review-lock/` | 跑 review.sh | exit 3,stderr 含"已有评审在进行中" |
| TC-06 | 夹具任务目录已有 review-round-01-pass.md | 跑 review.sh(实现记录仍只有 1 轮) | exit 3,stderr 含"拒绝重评"(历史只增不改) |
| TC-07 | 夹具 + PATH 前置 codex 桩:被调用时把完整 argv 写入记录文件、探测并记录 /tmp 与 $TMPDIR 下 `rawf-review-*` 目录、按 `--output-last-message` 参数写出合法 pass JSON、退出 0 | 经桩跑 review.sh | 桩记录的 argv 含 `--sandbox read-only`,`-C` 的值为夹具根路径本身(直审原仓库,非副本);桩调用时刻无任何 `rawf-review-*` 副本目录(运行期无副本,而非仅事后无残留);review-round-01-pass.md 正常发布、退出码 0(主流程走通) |
| TC-08 | 同 TC-07 桩,但桩在写出 JSON 前**追加改动夹具的一个已跟踪文件**(模拟评审期间主工作区被污染) | 经桩跑 review.sh | exit 3;stderr 含"主工作区在评审期间发生改动";**无 review-round 文件发布**(指纹否决受污染结果,双保险生效) |

异常/边界路径:TC-02、TC-03、TC-05、TC-06、TC-08。

## 风险与回滚

- **失去独立复跑测试能力**(核心取舍,用户明确接受):抓虚报从"重跑
  比对"退化为"证据审查"。缓解:① 证据协议硬化——缺证据即 blocker
  且必须开出补交清单,形成可收敛的打回循环(本日 slim-review-copy 两轮
  评审已实证该循环有效);② 开发侧为顶级模型且历史无复跑分歧记录;
  ③ 已知限制中如实声明,若未来出现分歧案例,可新增决策引入抽查机制。
- **只读下静态检查的写失败误报**:lint 写缓存失败可能被误当代码问题;
  标准明确"写失败不算缺陷,转证据核验"兜住。
- **raw 输出落主工作区**:依赖 `--output-last-message` 为 CLI 层写入
  (不经沙箱)——plan-review.sh 同形态已多轮稳定运行,且 TC-01 端到端
  覆盖。
- **指纹语义弱化担忧**:指纹原样保留,评审期间禁写规则(CLAUDE.md)
  与 .claude/ 排除均不变,行为对主会话无感知差异。
- **回滚**:单提交 revert 即恢复副本机制(review.sh 为唯一机制承载点,
  其余是文档/标准表述)。

<!-- 过程产物落点:体量较大的验证证据(日志、截图)放任务目录 evidence/,
     引用素材(Design 稿、参考图)放 assets/;二者须在评审前落盘。 -->
