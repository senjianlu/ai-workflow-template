# Plan 评审:第 04 轮

## 问题清单
- [plan-blocker] R-01 方案将 plan 评审上限设为 10，但任务产物没有用户明确放宽的授权记录。
  - 详情:定位：plan.md frontmatter 的 `plan_review_max_rounds: 10`，以及已有三份 `plan-review-round-*-fail.md`。CLAUDE.md、rawf-plan 和 decisions/0003 都要求该字段仅在用户明确要求放宽时写入，并在面向用户的方案摘要或实现记录中声明；当前任务产物未记录该授权。该字段会让 plan-review.sh 在默认三轮后继续运行，绕过既有闸门。修复建议：无明确授权则删除字段并按三轮上限转人工；如确有授权，在方案摘要中记录用户指定的 10 轮及其确认来源。
- [major] R-02 测试命令仍以宽泛关键词存在性代替关键部署和工程约定的验收，无法真实覆盖方案。
  - 详情:定位：TC-01、TC-03、TC-04、TC-07。比如 TC-01 只要求出现 `addversion.json`、`schedule.json` 等词，遗漏 addversion 必填的 project/version/egg、schedule 必填的 project/spider、禁止绕过 Scrapyd 直接 crawl、直连路径的 scrapy.cfg `[settings]`/`[deploy]` 约定仍可通过；TC-04 未核验声明的包骨架和 HtmlResponse/TextResponse 离线测试方式；TC-07 也未核验决策记录要求的日期、背景、决定、影响四段。TC-08 只证明改动前没有 reactor 关键词，不能弥补这些遗漏。修复建议：为每项关键契约增加精确且可失败的断言，按对应小节验证必填参数、禁止路径、目录/测试构造与决策四段；对删除任一关键约定的反向情形应失败。

## 总评
测试用例逐条声明为 A 档，证据形态合规，且 C 档为 0。部署方案本身已明确 egg entry point 与 Scrapyd 接口，但上述工作流授权缺口和验收覆盖不足会导致流程绕过或实现偏离，需修订后重评。

VERDICT: fail
