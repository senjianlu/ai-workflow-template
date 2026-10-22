---
task: patch-ampersand-shellcheck
round: 01
date: 2026-10-22
---

# 实现记录:第 01 轮

## 本轮改动
| 文件 | 改动摘要 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 读入 prompt 模板前 `shopt -u patsub_replacement 2>/dev/null \|\| true`(附原因注释);`lock_holders` 删去未用的 `target`;`kill_codex_tree` 删去 `local` 中的 `i`、两处循环变量改为 `_`;主流程 setsid 等待循环变量改为 `_` |
| `.ai-workflow/scripts/plan-review.sh` | `lock_holders` 删去未用的 `target`;`kill_codex_tree` 同上;主流程 setsid 等待循环变量改为 `_` |
| `.ai-workflow/scripts/evidence.sh` | `on_sig` 前加 `# shellcheck disable=SC2329` 及原因注释 |
| `CHANGELOG.md`、`.ai-workflow/TEMPLATE-VERSION` | 1.2.1(Fixed / Changed / 升级指引) |

## plan 评审 minor 交接
| 来源 | 内容 | 处置 |
|---|---|---|
| — | 无:`plan-review.sh __minors` 输出"无",第 01 轮 plan 评审未报 minor | — |

## 修复对照
(第 1 轮,无)

## 测试结果
<!-- 留证写法 (b):每条用例一个断言脚本 evidence/tc-NN.sh(公共库 evidence/lib.sh),由
     evidence.sh 包住产出;exit 0 = 全部断言成立。TC-06 在 CHANGELOG 描述补全后以 -l r2
     重新留证(首次 TC-06.log 同样全部通过,保留不动)。 -->
| 编号 | 档位 | 结果 | 证据 |
|---|---|---|---|
| TC-01 | A | pass | TC-01.log |
| TC-02 | A | pass | TC-02.log |
| TC-03 | A | pass | TC-03.log(shellcheck 0.11.0,装于 /tmp 临时 venv;全级别输出为空) |
| TC-04 | A | pass | TC-04.log(15 个回归脚本全部 exit 0,各脚本完整输出在正文) |
| TC-05 | A | pass | TC-05.log(8 个回归脚本全部 exit 0,各脚本完整输出在正文) |
| TC-06 | A | pass | TC-06-r2.log |

## 与方案的偏差
| 编号 | 类型 | 内容 | 原因 | 处置 |
|---|---|---|---|---|
| D-01 | 替代 | `kill_codex_tree`(review.sh、plan-review.sh 各一处)删去 `local` 中的 `i`、两处 `for i` 改为 `for _`;plan「非目标」原写"函数内 local 声明过的循环变量(`kill_codex_tree` 等处的 `i`,shellcheck 未报)" | 该非目标的前提不成立:shellcheck 对同名未用变量只报一次,主流程的 `i` 改掉后,`kill_codex_tree` 中的 `i` 随即被报出(review.sh:82、plan-review.sh:141,SC2034)。不改则 plan 的验收标准"shellcheck 全级别零条"(TC-03)无法达成;改法与已批准条目同类(未用循环变量改 `_`),不新增文件或行为 | 已实现;TC-04 回归中看门狗查杀用例(scope-guard tc-19)覆盖 `kill_codex_tree`;收尾时提请用户确认 |

## 停车场
无
