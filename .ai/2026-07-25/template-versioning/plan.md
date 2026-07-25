---
status: approved
task: template-versioning
date: 2026-07-25
approved_at: 2026-07-25 (最小版第 4 轮 plan 评审 pass 后经用户确认)
plan_review_max_rounds: 5
---

# 方案:为模板设立版本号与增量升级机制(最小实践版)

## 背景与目标

模板会持续演进,consumer 项目此前无法知道自己采用的是哪个版本,流程
变更后只能全量比较。目标:

1. 模板仓库采用 SemVer,按 git tag + GitHub Release 发布;
2. consumer 记录采用版本,升级时用 `git diff <旧tag>..<新tag> --
   <受管路径>` 取增量;
3. 版本纪律记入 `docs/decisions/0008`;
4. 起点 v1.0.0。

方案取舍:轻量路线(tag + 版本标记文件 + CHANGELOG),否掉
copier/cruft(机制重)。**不引入任何脚本**——发布是手工四条命令,
一年执行次数屈指可数,自动化脚本的维护与验收成本远超收益。

**流程与范围授权记录**:plan 评审为用户明确要求。此前 10 轮评审
针对的是含发布脚本的较大草案;用户 2026-07-25 明确裁决**回退到最小
实践、移除发布脚本**,并指示**删除全部历史评审文件、对本最小版重新
评审,上限 5 轮**(frontmatter `plan_review_max_rounds: 5` 即该
授权)。历轮评审中与机制本身相关的有效改进已保留(受管路径完整
清单、归类正确性、存量项目基线认领规则、CHANGELOG 条目级契约、
测试命令可执行性);仅与发布脚本相关的要求随脚本一并移除。发布
动作(push/tag/Release)已获用户"发布吧"授权,收尾提交确认后以
手工命令执行。

**范围锁(用户指令,防蔓延)**:本任务范围**锁定**为上表 4 文件、
零脚本、发布走手工命令。评审意见若要求扩大范围(新增文件、引入
脚本/CI/自动化机制、为手工发布命令增设自动验收)均**超出用户授权**,
不予就地采纳——将原样记录并交用户裁决。评审应聚焦:4 文件内容的
正确性与一致性、测试用例对文件内容的真实覆盖。

## 改动范围

| 文件 | 动作 |
|---|---|
| `CHANGELOG.md` | 新建。Keep a Changelog 体例;固定格式归类行;`[1.0.0]` 基线条目(含升级指引小节) |
| `.ai-workflow/TEMPLATE-VERSION` | 新建。version / source / adopted 三字段;随 .ai-workflow/ 整目录拷贝自动带版本 |
| `README.md` | 新增「版本与升级」节;「开新项目」「存量项目迁移」补 TEMPLATE-VERSION 与基线认领规则 |
| `docs/decisions/0008-template-versioning.md` | 新建决策记录(四段体例) |

明确不动:workflow 脚本与 hooks、AGENTS.md、.claude/skills/、
docs/architecture/、scripts/(不新建任何脚本)。共 4 文件。

发布动作(不属文件改动,在 /rawf-report 提交确认后手工执行,命令
见「实现方案 > 5」)。

## 实现方案

### 1. CHANGELOG.md

头部声明遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)
与 [SemVer](https://semver.org/lang/zh-CN/),并以**行首锚定的固定两行**
声明受管路径归类(供机器核验):

```
- 可整体替换:.ai-workflow/、.claude/hooks/、.claude/skills/rawf-*、.claude/settings.json、.githooks/、.gitmessage
- 需人工合并:AGENTS.md、CLAUDE.md、README.md、.agents/skills/、skills-lock.json
```

(.claude/settings.json 为 hook 注册所在;settings.local.json 属本机
个人授权不受管。需人工合并原因:前三者 consumer 已按项目裁剪;
.agents/skills/ 与 skills-lock.json 是项目内建 skill 及其哈希锁,
consumer 可能持有自有条目,须经锁机制合并。)

条目规则:每个版本条目必须含「升级指引」小节,逐文件标注归类与迁移
动作。`## [1.0.0]` 基线条目:一句话概括当前形态,升级指引写
"基线版本,无升级来源"。

### 2. .ai-workflow/TEMPLATE-VERSION

```
version: 1.0.0
source: https://github.com/senjianlu/ai-workflow-template
adopted: <yyyy-mm-dd,拷入 consumer 项目时填写;模板仓库内保持占位>
```

### 3. README.md「版本与升级」节

置于「机制速览」之后、「已知限制」之前:

- **版本语义**(按闸门兼容性,与 SemVer 对齐):MAJOR = 闸门协议
  不兼容变更(hook 行为、评审 schema/产物命名、流程步骤);MINOR =
  向后兼容的新增能力(新标准栈、新 skill、新评审关注点);PATCH =
  向后兼容的缺陷修复(含脚本/hook 的 bug fix 与文案修正,回应
  二轮 R-01);
- **发布纪律**:发版提交须同步更新 CHANGELOG.md 与 TEMPLATE-VERSION,
  随后打 tag 并创建同名 GitHub Release(notes 取 CHANGELOG 对应条目);
- **升级三步**(关键前提:consumer 经 Use this template 创建,git
  历史与模板不同源,本地**没有**模板的 tag——增量一律在**模板仓库
  的单独克隆**中读取;consumer 仓库不添加模板 remote、不 fetch 模板
  tag,避免 tag 冲突。回应新一轮 R-01),命令放独立 ```bash 代码块:

  ```bash
  OLD=1.0.0 NEW=1.1.0   # 按实际版本替换;OLD 取自项目内 TEMPLATE-VERSION
  git clone https://github.com/senjianlu/ai-workflow-template /tmp/awt
  cd /tmp/awt
  git checkout --detach "v$NEW"   # 锚定 NEW 快照:diff/CHANGELOG/拷贝同源
  git diff "v$OLD..v$NEW" -- .ai-workflow .claude/hooks \
    '.claude/skills/rawf-*' .claude/settings.json .githooks .gitmessage \
    CLAUDE.md AGENTS.md README.md .agents/skills skills-lock.json
  ```

  (命令须可整体复制执行,不得含 `<占位符>` 类 shell 元字符歧义,
  回应二轮 R-02。)

  克隆已 checkout 到 `v$NEW`(回应三轮 R-01:diff、新版 CHANGELOG
  与拷贝来源锚定同一 tag 快照,不受默认分支后续推进影响)。随后:
  可整体替换类从克隆整目录拷入覆盖(TEMPLATE-VERSION 随之更新)→
  需人工合并类按升级指引处理 → 回 consumer 仓库更新 adopted。旧版本号从项目内
  TEMPLATE-VERSION 读取;基线认领(存量项目)的"对照模板核对"同样
  以该克隆的 v1.0.0 checkout 为对照物。

「开新项目」加一步:克隆后填 adopted。「存量项目迁移」补**基线认领
规则**:既有无版本项目须先完成对 v1.0.0 的全量基线对齐(工作流层
整体拷入 + 需人工合并类逐文件核对)才可写 version;之前一律记
`unknown` 并继续全量比较,不得直接认领。

### 4. docs/decisions/0008-template-versioning.md

四段体例:日期 2026-07-25;背景(无版本锚点、全量比较);决定
(SemVer + tag + Release 同发、TEMPLATE-VERSION 落 .ai-workflow/、
归类双清单、基线认领规则;否掉 copier/cruft 与发布/升级脚本——
含被否原因);影响(发版三同步、README 为升级权威指引、起点 v1.0.0)。

### 5. 发布(收尾提交确认后手工执行,非交互)

```bash
N=.ai/2026-07-25/template-versioning/evidence/release-notes.md
awk '/^## \[1\.0\.0\]/{f=1} f && /^## \[/ && !/^## \[1\.0\.0\]/{exit} f' \
  CHANGELOG.md > "$N" && test -s "$N"
git push origin master
git tag v1.0.0 && git push origin v1.0.0
gh release create v1.0.0 --title "v1.0.0" --notes-file "$N"
gh release view v1.0.0 --json tagName,name -q '.tagName + " " + .name'
```

每条命令输出如实呈现;任何失败当场报告并交用户处置,不做自动补偿。
证据(release-notes.md 及命令输出记录)以追加提交收录
(`chore(release): v1.0.0 发布记录`)。

## 测试用例

约定:命令均在仓库根执行,权威命令在下方代码块(不放表格);中间
产物落任务 `evidence/`;关键词用 MISS 循环断言;TC-06 为反向对照。

| 编号 | 档位 | 前置条件 | 步骤 | 预期结果 | 证据形态 |
|---|---|---|---|---|---|
| TC-01 | A(CHANGELOG 结构与归类正确性) | 改动完成 | 执行下方「TC-01 命令」 | 归类两行解析为路径集合后与规定集合(6/5 项)**严格等值比较**——多列、漏列、双重归类均 FAIL;`[1.0.0]` 条目区间内含升级指引与基线说明(头部出现不算);输出 OK、退出码 0 | 命令 + 完整输出 + 退出码,落 evidence/ |
| TC-02 | A(版本标记格式) | 同上 | 执行下方「TC-02 命令」 | version 行严格匹配语义化格式且为 1.0.0,source 为模板仓库 URL,adopted 字段存在;输出 OK、退出码 0 | 同上 |
| TC-03 | A(README 升级契约) | 同上 | 执行下方「TC-03 命令」 | 「版本与升级」节含 MAJOR/MINOR/PATCH、闸门、CHANGELOG、GitHub Release、tag、TEMPLATE-VERSION,且含上游获取协议(模板仓库克隆命令、"不添加模板 remote"防 tag 冲突声明);从唯一含 git diff 的代码块提取命令及续行,11 个受管路径逐一在命令内(注释不算);开新项目节含 TEMPLATE-VERSION;迁移节含 adopted、基线对齐、unknown、不得直接认领;输出 OK、退出码 0 | 同上 |
| TC-04 | A(决策回写) | 同上 | 执行下方「TC-04 命令」 | `^# 0008` 与四段行首逐段命中,SemVer/tag/Release/TEMPLATE-VERSION/copier 关键词命中;输出 OK、退出码 0 | 同上 |
| TC-05 | A(非 happy-path,防回归与范围) | 同上 | 执行下方「TC-05 命令」 | 「机制速览」「已知限制」「### 爬虫」未破坏(REGRESSION-OK);含未跟踪文件在内改动仅落 4 文件 + .ai/ 允许清单(SCOPE-OK);退出码 0 | 同上 |
| TC-06 | A(反向对照) | HEAD 仍为改动前提交 | 执行下方「TC-06 命令」 | 改动前 HEAD 的 README 含「版本与升级」或 TEMPLATE-VERSION 即 UNEXPECTED 退出 1;实际输出 NEGATIVE-OK、退出码 0 | 同上 |

C 档 0 条。发布为手工命令(见实现方案 5),其输出在收尾如实留证,
不进本表。

### 测试命令(权威,逐块整体复制执行)

TC-01 命令:

```bash
f=CHANGELOG.md
for kw in keepachangelog semver '## [1.0.0]' 升级指引; do
  if ! grep -F -q -- "$kw" "$f"; then echo "MISS: $kw"; exit 1; fi
done
W=.ai/2026-07-25/template-versioning/evidence/wholesale-line.txt
M=.ai/2026-07-25/template-versioning/evidence/manual-line.txt
grep '^- 可整体替换:' "$f" > "$W" || { echo "MISS: 可整体替换行"; exit 1; }
grep '^- 需人工合并:' "$f" > "$M" || { echo "MISS: 需人工合并行"; exit 1; }
# 集合严格等值比较:多列、漏列、双重归类均失败(回应新一轮 R-02)
norm() { sed 's/^-[^:]*://' "$1" | tr '、' '\n' \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort; }
norm "$W" > "$W.set"
printf '%s\n' '.ai-workflow/' '.claude/hooks/' '.claude/skills/rawf-*' \
  '.claude/settings.json' '.githooks/' '.gitmessage' | sort > "$W.exp"
diff "$W.exp" "$W.set" || { echo "FAIL: 可整体替换集合与规定不等"; exit 1; }
norm "$M" > "$M.set"
printf '%s\n' 'AGENTS.md' 'CLAUDE.md' 'README.md' '.agents/skills/' \
  'skills-lock.json' | sort > "$M.exp"
diff "$M.exp" "$M.set" || { echo "FAIL: 需人工合并集合与规定不等"; exit 1; }
E1=.ai/2026-07-25/template-versioning/evidence/changelog-entry.txt
awk '/^## \[1\.0\.0\]/{f=1;print;next} f && /^## \[/{exit} f' "$f" > "$E1"
[ -s "$E1" ] || { echo "MISS: 1.0.0 条目为空"; exit 1; }
grep -F -q '升级指引' "$E1" || { echo "MISS-ENTRY: 条目内无升级指引"; exit 1; }
grep -F -q '基线版本' "$E1" || { echo "MISS-ENTRY: 条目内无基线说明"; exit 1; }
echo OK
```

TC-02 命令:

```bash
f=.ai-workflow/TEMPLATE-VERSION
grep -Eq '^version: [0-9]+\.[0-9]+\.[0-9]+$' "$f" || { echo "MISS: version 格式"; exit 1; }
grep -F -q 'version: 1.0.0' "$f" || { echo "MISS: 1.0.0"; exit 1; }
grep -F -q 'source: https://github.com/senjianlu/ai-workflow-template' "$f" \
  || { echo "MISS: source"; exit 1; }
grep -q '^adopted:' "$f" || { echo "MISS: adopted"; exit 1; }
echo OK
```

TC-03 命令:

```bash
V=.ai/2026-07-25/template-versioning/evidence/ver-sec.txt
awk '/^## 版本与升级/,/^## 已知限制/' README.md > "$V"
for kw in MAJOR MINOR PATCH 闸门 CHANGELOG 'GitHub Release' tag TEMPLATE-VERSION \
          'git clone https://github.com/senjianlu/ai-workflow-template' \
          '不添加模板 remote'; do
  if ! grep -F -q -- "$kw" "$V"; then echo "MISS: $kw"; exit 1; fi
done
D=.ai/2026-07-25/template-versioning/evidence
rm -f "$D"/ver-block-*.txt
awk -v d="$D" '/^```/{f=!f; if(f){n++; file=d"/ver-block-"n".txt"} next} f{print > file}' "$V"
hits=0; C=""
for b in "$D"/ver-block-*.txt; do
  [ -e "$b" ] || continue
  if grep -F -q 'git diff' "$b"; then hits=$((hits+1)); C="$b"; fi
done
[ "$hits" -eq 1 ] || { echo "FAIL: 含 git diff 的代码块数=$hits"; exit 1; }
[ "$(grep -c 'git diff' "$C")" -eq 1 ] || { echo "FAIL: git diff 须恰出现 1 次"; exit 1; }
A=.ai/2026-07-25/template-versioning/evidence/diff-argv.txt
awk '/git diff/{f=1} f{print; if(!/\\$/) exit}' "$C" > "$A"
grep -F -q 'v$OLD..v$NEW' "$A" || { echo "FAIL: diff 未用变量形式引用版本"; exit 1; }
grep -F -q 'git checkout --detach "v$NEW"' "$C" \
  || { echo "FAIL: 命令块未锚定 NEW 快照(checkout --detach)"; exit 1; }
grep -q '<' "$A" && { echo "FAIL: diff 命令含尖括号占位符,不可复制执行"; exit 1; }
for p in .ai-workflow .claude/hooks '.claude/skills/rawf-*' \
         .claude/settings.json .githooks .gitmessage \
         CLAUDE.md AGENTS.md README.md .agents/skills skills-lock.json; do
  if ! grep -F -q -- "$p" "$A"; then echo "MISS-IN-ARGV: $p"; exit 1; fi
done
N=.ai/2026-07-25/template-versioning/evidence/new-sec.txt
awk '/^## 开新项目/,/^## 存量项目迁移/' README.md > "$N"
grep -F -q 'TEMPLATE-VERSION' "$N" || { echo "MISS: 开新项目节"; exit 1; }
M=.ai/2026-07-25/template-versioning/evidence/mig-sec.txt
awk '/^## 存量项目迁移/,/^## 机制速览/' README.md > "$M"
for kw in adopted 基线对齐 unknown 不得直接认领; do
  if ! grep -F -q -- "$kw" "$M"; then echo "MISS: 迁移节 $kw"; exit 1; fi
done
echo OK
```

TC-04 命令:

```bash
f=docs/decisions/0008-template-versioning.md
for pat in '^# 0008' '^- 日期:2026-07-25' '^- 背景:' '^- 决定:' '^- 影响:'; do
  if ! grep -q -- "$pat" "$f"; then echo "MISS: $pat"; exit 1; fi
done
for kw in SemVer tag Release TEMPLATE-VERSION copier; do
  if ! grep -F -q -- "$kw" "$f"; then echo "MISS: $kw"; exit 1; fi
done
echo OK
```

TC-05 命令:

```bash
grep -q '^## 机制速览' README.md \
  && grep -q '^## 已知限制' README.md \
  && grep -q '^### 爬虫' AGENTS.md \
  && echo REGRESSION-OK || { echo REGRESSION-FAIL; exit 1; }
G=.ai/2026-07-25/template-versioning/evidence/git-status.txt
git status --short > "$G"
extra=$(awk '{print $NF}' "$G" | grep -Ev \
  '^(CHANGELOG\.md|\.ai-workflow/TEMPLATE-VERSION|README\.md|docs/decisions/0008-|\.ai/)' \
  || true)
if [ -n "$extra" ]; then echo "OUT-OF-SCOPE: $extra"; exit 1; fi
echo SCOPE-OK
```

TC-06 命令:

```bash
if git show HEAD:README.md | grep -q '^## 版本与升级'; then
  echo "UNEXPECTED: 改动前已存在「版本与升级」节"; exit 1
fi
if git show HEAD:README.md | grep -q 'TEMPLATE-VERSION'; then
  echo "UNEXPECTED: 改动前已存在 TEMPLATE-VERSION"; exit 1
fi
echo NEGATIVE-OK
```

## 风险与回滚

- **发版纪律靠人**:三同步(CHANGELOG/TEMPLATE-VERSION/tag)无机器
  强制,漏更靠 README 纪律与 decisions 提醒;频繁漏更再议 CI 校验。
- **手工发布可能出错**(tag 打错提交、Release 漏建):一年数次的低频
  操作,命令清单固化在 plan 与 README,出错当场可见、可手工纠正;
  这是用可接受的小风险换掉整个脚本的维护与验收成本(用户裁决)。
- **回滚**:纯文档新增,`git revert` 单提交;tag/Release 可删除重发。
