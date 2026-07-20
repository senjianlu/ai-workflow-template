# Plan 评审:第 04 轮

## 问题清单
- [major] R-01 测试计划未覆盖 rawf-plan 与 rawf-review 两个被改 skill 的核心语义。
  - 详情:定位: .ai/2026-07-20/test-evidence-tiers/plan.md:46-48、136-137。改动范围明确要求 rawf-plan 第 5 步新增“逐条声明档位/证据形态”为硬要求，并要求 rawf-review 提示按档位核验、C 档误判可申诉；但测试只在 TC-07 检查三个 skill 的 frontmatter/name，TC-08 只 grep rawf-implement 正文。这样实现者漏改 rawf-plan 或 rawf-review 正文时，现有 TC 仍可能全部通过，后续计划生成和评审分流仍会沿用旧语义。建议新增 A 档静态校验：分别 grep rawf-plan 的档位声明硬要求、rawf-review 的按档位核验与 C 档误判申诉/分流提示。

## 总评
方案主体已和既有脚本、hooks、0005 决策沿革基本对齐，前几轮指出的时序死锁、旧规则残留与 docs 回写问题也已修正。但测试矩阵仍漏掉两个计划修改的 rawf skill 正文，无法真实覆盖验收范围；按 plan-review 判定规则，本轮 fail。

VERDICT: fail
