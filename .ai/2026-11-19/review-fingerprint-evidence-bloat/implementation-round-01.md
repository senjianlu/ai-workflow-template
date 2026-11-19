---
task: review-fingerprint-evidence-bloat
round: 01
date: 2026-11-19
---

# 实现记录:第 01 轮

## 本轮改动

| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/review.sh` | `workspace_hash()` 拆为三段各自哈希再合并:diff 段(不变)、元数据子段 `untracked_meta`(shell 内建判断类型与可执行位,符号链接记目标)、内容子段 `untracked_content`(非符号链接路径加 `./` 前缀,经 `xargs -0 -r sha1sum -z --` 分批哈希;`xargs` 返回 0 / 123 视为成功,其它返回值原样传出)。任一段失败则 `workspace_hash` 返回非 0、不输出指纹。主流程工具预检补 `sha1sum`、`xargs`;`pre_hash` / `post_hash` 两处调用点失败即报错并 exit 3。头部运行环境说明与函数上方口径注释同步 |
| `CHANGELOG.md` | 新增 `[1.4.1] - 2026-11-19` 条目(Fixed / Changed / 升级指引) |
| `.ai-workflow/TEMPLATE-VERSION` | `version: 1.4.1` |
| `.ai/2026-11-19/review-fingerprint-evidence-bloat/assets/test-workspace-hash.sh` | 测试脚本:`tc01` ~ `tc07`、`tc09` 子命令,夹具建在项目外 |

发版范围(CHANGELOG、TEMPLATE-VERSION、TC-09)是用户在确认方案时追加的
("确认,发版并入本任务,发 1.4.1。"),已写入 plan.md 的需求原文、改动范围
与测试表;该处修订发生在 plan 评审第 2 轮 pass 之后,未再经 plan 评审。

## plan 评审 minor 交接

| 来源 | 内容 | 处置 |
|---|---|---|
| 01/R-04 | "进程数与文件数无关、常数级"的表述与选定算法不一致 | 已在 plan 修订中解决(改述为"按参数容量分批";第 2 轮确认) |
| 01/R-05 | 性能用例以可变 HEAD 作为旧实现来源,提交后无法按原意重跑 | 已在 plan 修订中解决;本轮实现处理:测试脚本写死基线 `fd5d23a` 并打印完整 SHA |
| 01/R-06 | 并发语义对前后指纹检测能力作了过强保证 | 已在 plan 修订中解决(改述为尽力检测;第 2 轮确认) |
| 02/R-01 | TC-03 在交换文件内容后遗漏还原步骤 | 已在 plan 修订中解决(步骤 (4) 补"换回再取"及对应预期);本轮实现处理:脚本 `tc03` 含换回断言 |

## 修复对照

不适用(第 1 轮)。

## 测试结果

| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01.log(exit 0;7 项改动各自"变化 / 还原回基线"共 14 条断言 + 基线) |
| TC-02 | A | pass | TC-02.log(exit 0;排除项不计入;`.env` 被忽略但计入) |
| TC-03 | A | pass | TC-03.log(exit 0;6 类特殊路径含文件名恰为 `-`,空文件,交换与换回,仓库外链接目标) |
| TC-04 | A | pass | TC-04.log(exit 0;非 root;实测 4 批 1110/1110/1110/670;stderr 含 Permission denied;同批与末批改写均被检出) |
| TC-05 | A | pass | TC-05.log(exit 0;三种情形完整流程均 exit 3;(1)(2) codex 桩未被调用,(3) 被调用且无评审文件) |
| TC-06 | A | pass | TC-06.log(exit 0;基线 fd5d23a 改前 62613 ms,改后 245 ms) |
| TC-07 | A | pass | TC-07.log(exit 0;正常场景 exit 0 并发布 pass 文件;篡改场景 exit 3 且不发布) |
| TC-08 | A | pass | TC-08.log(exit 0;`bash -n` 无输出) |
| TC-09 | A | pass | TC-09.log(exit 0;version 行、CHANGELOG 条目位置、升级指引小节) |

## 与方案的偏差

无。

## 停车场

- 消费仓 cscheap-frontend 的 6.1G 未提交 `.ai/**/evidence/`,以及
  `.open-next/` 等构建产物未加入其 `hash_excludes`:属消费仓自身事务,本仓
  不改其它仓库。
- 生产规模(30130 个文件、6.1G)下改后的实际耗时未实测;需消费仓升级到
  1.4.1 后在其环境里跑 `review.sh __workspace_hash` 确认。
- `sha1sum` 以 1–125 退出时 `xargs` 一律返回 123,与"个别文件不可读"无法
  区分,两者都被容忍;不可读文件是否应改为 fail-closed 已列入 plan 非目标。
- 打 `v1.4.1` tag 与创建 GitHub Release:提交之后的对外动作,待用户确认。
