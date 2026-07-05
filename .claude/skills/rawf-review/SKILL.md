---
name: rawf-review
description: rawf 工作流第 4 步:通过 review.sh 调用 Codex 评审当前改动,并按结果分流(通过/修复轮/升级人工)。每轮 implementation-round 产物写完后立即使用。
---

# rawf-review:评审与分流

1. 运行 `bash .ai-workflow/scripts/review.sh`。评审只能经此脚本,不得以
   自查代替 Codex 评审。退出码非 0/1(即 3)= 评审执行异常,把 stderr
   报给用户后停下,不要自行绕过。
2. 读取新生成的 review-round-<NN>-<pass|fail>.md,按顺序分流:
   - 存在 plan-blocker → 不进入修复。向用户完整转述该问题,由用户决定
     退回 /rawf-plan 重做方案,或人工处理。
   - fail 且 NN < 3 → 进入 /rawf-implement 修复轮。
   - fail 且 NN = 3 → 停止修复。向用户汇报三轮未决的问题清单,交人工判断。
   - pass → 进入汇报收尾(遗留 minor 一并带上)。
3. 认为评审有误报时,不得"解释掉"后静默忽略:原样呈给用户裁决,用户
   同意不修的,在下一轮实现记录或汇报中注明。
