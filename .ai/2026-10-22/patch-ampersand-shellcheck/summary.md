---
task: patch-ampersand-shellcheck
date: 2026-10-22
rounds: 1
verdict: pass
---

# 任务小结:review.sh 证据报告注入的 `&` 改写修复 + shellcheck 既有提示清零(1.2.1)

## 改动
| 文件 | 摘要 |
|---|---|
| `.ai-workflow/scripts/review.sh` | 占位替换前关闭 `patsub_replacement`;删未用局部变量与循环变量 |
| `.ai-workflow/scripts/plan-review.sh` | 删未用局部变量与循环变量 |
| `.ai-workflow/scripts/evidence.sh` | `on_sig` 加 `shellcheck disable=SC2329` 注释 |
| `CHANGELOG.md`、`.ai-workflow/TEMPLATE-VERSION` | 1.2.1 |

## 评审历程
| 轮次 | 结论 | 关键问题 |
|---|---|---|
| plan 01 | pass | 无(1.2.0 新规则首次生效:全量穷尽评审,overall 按五个维度逐一给出结论) |
| 实现 01 | pass | 无 |

## 范围核对
- **追加类偏差**:无。
- **替代类偏差 D-01(用户已确认保留,原话「一并改了」)**:plan「非目标」写"`kill_codex_tree` 中的循环变量 shellcheck 未报",前提不成立——shellcheck 对同名未用变量只报一次,主流程的改掉后函数内的随即被报出;为达成验收"shellcheck 全级别零条",一并改为 `_` 并删去对应 `local i`。同类改动,不新增文件或行为;实现评审已核验认可。
- **评审「范围核对」节**:plan 评审 01 为三条确认性结论;实现评审 01 为"无"。
- **停车场**:无。

## 遗留 minor 及处置
无。
