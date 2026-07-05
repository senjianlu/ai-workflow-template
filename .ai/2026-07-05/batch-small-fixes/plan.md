---
status: approved
task: batch-small-fixes
date: 2026-07-05
approved_at: 2026-07-05 17:52:00
---

# 方案:批量小修(5 项)

## 背景与目标

清算积累的已知小问题。清单经用户确认(2026-07-05),其中"评审模型固定"
一项经用户裁决移除(减少维护心智负担,跟随本机 codex 默认配置);新增
一项方案阶段现场发现的闸门误拦:

1. **review.sh 计数崩溃**(hooks-json-decisions 的范围外发现):无实现轮时
   `ls|wc` 在 set -e/pipefail 下以 ls 的退出码 1 崩溃,与"评审结论 fail"的
   退出码语义冲突,到不了预设的"尚无实现记录 exit 3"。
2. **gate-plan 项目外路径误拦**(本方案撰写时现场发现):plan 未批时,对
   **本仓库之外**的文件写入(如 `~/.claude/` 下的会话记忆)也被拦截。闸门
   的职责边界是本项目的源码与工作流文件,项目外路径不归它管。
3. **模板自洽性**:README"开新项目"引用不存在的 `.github/workflows/ci-*`
   与复数个 `rawf-stack-*`(实际仅 scrapy 一个)。
4. **Git 提交规范**(用户新增):AGENTS.md 缺提交信息规范,需简明最佳实践约定。
5. **技术栈表格化**(用户新增):AGENTS.md 技术栈改表格,便于人工辨认修改。

## 改动范围

| 文件 | 动作 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 第 1 项:计数改 nullglob 数组(用后即关,与 gate-review 同法) |
| `.claude/hooks/gate-plan.sh` | 第 2 项:`in_ai_dir()` 重构为统一的物理归属判定——物理位于项目外的普通路径直接放行;`.ai/` 豁免与"符号链接一律走状态闸"的既有语义不变 |
| `README.md` | 第 3 项:"开新项目"第 3 步措辞对齐现状 |
| `AGENTS.md` | 第 4 项:新增"Git 提交规范"章节;第 5 项:技术栈改两列表格(层 / 技术选型),TEMPLATE 注释保留 |

**明确不动**:gate-review.sh、prompts、schema、skills、CLAUDE.md、templates、
.gitignore。评审模型不固定(用户裁决)。

## 实现方案

### 第 1 项:review.sh 计数

```bash
shopt -s nullglob
rounds=("$task_dir"/implementation-round-*.md)
shopt -u nullglob   # 立即关闭,后续 review-round 存在性 glob 依赖非空语义
count=${#rounds[@]}
[ "$count" -gt 0 ] || { echo "尚无实现记录,先完成 /rawf-implement" >&2; exit 3; }
```

### 第 2 项:gate-plan 物理归属判定

以物理路径统一判定归属,替代现有 `in_ai_dir()`:

```bash
# 最近已存在祖先目录的物理路径;解析失败按项目内处理(fail-closed)
d=$(dirname "$abs")
while [ ! -d "$d" ]; do d=$(dirname "$d"); done
phys_dir=$(cd "$d" && pwd -P) || phys_dir="$proj_phys"

# 符号链接一律走状态闸(防经链接写入项目内);普通路径按物理归属分流
if [ ! -L "$abs" ]; then
  case "$phys_dir/" in
    "$proj_phys/.ai/"*) exit 0 ;;   # 任务产物目录:永远可写
    "$proj_phys/"*) ;;              # 项目内其它:走 plan 状态闸
    *) exit 0 ;;                    # 物理位于项目外:不归本闸管
  esac
fi
```

语义变化仅一处:物理在项目外的**普通文件**放行(原为误拦);`.. `穿越、
项目内外的符号链接、项目内非 .ai 路径的行为均与现状一致。

### 第 3 项:README 开新项目第 3 步

改为:"按需增删栈约定:模板自带 .claude/skills/rawf-stack-scrapy,可参照其
结构为你的栈新建 rawf-stack-*;.github/workflows/ 为空目录,按需添加 CI。
栈调整时同步 .ai-workflow/review-standards.md 的技术栈关注点。"

### 第 4 项:AGENTS.md Git 提交规范(新章节)

- 提交信息 `<type>: <一句话摘要>`,type 取 feat | fix | refactor | docs | test | chore
- 摘要用祈使句,简明扼要;正文(如有)说明动机与影响
- rawf 任务的提交在摘要后附 `(rawf: <yyyy-mm-dd>/<task-slug>)`
- 一次提交一个主题;代码与其决策痕迹(.ai/ 任务目录)同一提交

### 第 5 项:AGENTS.md 技术栈表格

"层 / 技术选型"两列,前端 / 后端 / 爬虫 / 部署 四行,内容不变。

## 测试用例

| 编号 | 前置条件 | 步骤 | 预期结果 |
|---|---|---|---|
| TC-01 | fixture 删除 implementation-round 文件(异常路径) | `bash review.sh; echo $?` | rc=**3**(修复前实测 rc=1)且 stderr 含"尚无实现记录";无评审文件产生 |
| TC-02 | fixture plan `status: draft` | 以 fixture **外**的普通路径(如驱动目录下文件)喂 gate-plan | rc=0 且 stdout 为空(放行,修复前为 deny) |
| TC-03 | 同上(对抗路径) | 在 fixture 外建符号链接指向 fixture 内源码,以链接路径喂 gate-plan | rc=0 且输出 deny JSON(不得经外部链接绕闸) |
| TC-04 | 同上 | 既有 gate 用例(draft 拦源码/穿越/项目内符号链接;三种放行)全部复跑 | 与现状一致:该拦的 deny JSON,该放的零输出 |
| TC-05 | 改动完成 | grep README 与 AGENTS.md | README 无 `ci-*` 引用;AGENTS.md 含"Git 提交规范"章节与 type 枚举;技术栈为表格(可匹配 `\| 前端 \|`) |
| TC-06 | 全量回归 | 驱动套件全跑(S 块 + TC 块 + GR 块 + 本次新增) | 全部通过 |

## 风险与回滚

- **gate 放行面扩大的方向性**:仅放行"物理位于项目外的普通文件";经符号
  链接指向项目内的路径仍走状态闸(TC-03 专门覆盖),项目内行为零变化
  (TC-04 回归)。
- **nullglob 作用域**:用后立即关闭,gate-review 同型修复已验证该手法。
- **文档改动**:纯措辞/结构调整,无行为变化;提交规范与 rawf-report 既有
  格式一致。
- **回滚**:单 commit,`git revert` 整体回滚。
