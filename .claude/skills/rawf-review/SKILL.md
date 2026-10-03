---
name: rawf-review
description: rawf 工作流第 4 步:通过 review.sh 调用 Codex 评审当前改动,并按结果分流(通过/修复轮/升级人工)。每轮 implementation-round 产物写完后立即使用。
---

# rawf-review:评审与分流

1. 以**后台方式**运行 `bash .ai-workflow/scripts/review.sh`(Claude Code 中
   用 Bash 工具的 `run_in_background`,并把 `timeout` 设为不低于
   4000000 ms,高于脚本 60 分钟的墙钟上限)。评审只能经此脚本,不得以
   自查代替 Codex 评审。启动后**直接结束回合,不轮询、不 sleep 等待**:
   脚本自带看门狗(事件流静默 15 分钟或总时长 60 分钟即终止 codex 并
   exit 3),评审完成的后台任务通知会唤回你,届时再读结果分流;Stop hook
   识别到评审进行中会放行。
   退出码非 0/1(即 3)= 评审执行异常,按 stderr 处置:
   - 含"已终止"(看门狗触发)→ 直接重跑一次;再次异常 → 报用户停下。
   - 含"进行中"→ 确有评审进程存活(正常并发,或脚本被强杀后遗留的
     codex),把 stderr 中的持有者列表与处置命令原样报用户,不自行 kill。
   - 含"旧版锁目录"(仅升级后首次可能出现)→ 确认 `pgrep -f 'codex exec'`
     为空后按提示 rmdir 该目录,重跑一次。
   - 其它 → 把 stderr 报给用户后停下,不要自行绕过。
2. 读取新生成的 review-round-<NN>-<pass|fail>.md,按顺序分流。修复轮
   上限取 plan.md frontmatter 的 `impl_fix_max_rounds`,字段缺失或非正
   整数一律按**默认 3**(取值规则与 rawf-implement 一致):
   - 存在 plan-blocker → 不进入修复。向用户完整转述该问题,由用户决定
     退回 /rawf-plan 重做方案,或人工处理。
   - fail 且 NN < 上限 → 进入 /rawf-implement 修复轮。
   - fail 且 NN ≥ 上限 → 停止修复。向用户汇报未决的问题清单,交人工判断。
   - pass → 进入汇报收尾(遗留 minor 一并带上)。
   用户中途明确要求追加修复轮数时,更新 plan.md 的 `impl_fix_max_rounds`
   并在下一轮实现记录中注明;不得未经用户提出而自行修改该字段。
3. 分流前先核对证据档位:评审须**按 plan 声明的档位**核验(定义见
   review-standards.md「测试证据档位」)。若评审**仅因无原始输出打回 C 档**
   用例,这属于可向用户申诉的误报——按第 4 条原样呈给用户裁决,不自行修改
   plan 的档位来迎合评审。
4. 认为评审有误报时,不得"解释掉"后静默忽略:原样呈给用户裁决,用户
   同意不修的,在下一轮实现记录或汇报中注明。
