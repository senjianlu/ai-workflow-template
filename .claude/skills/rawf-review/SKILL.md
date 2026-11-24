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
   - 含"证据核验未通过"(evidence-check 前置核验)→ codex 未启动、不消耗
     轮次。回到 /rawf-implement 按 stderr 的补交清单补齐证据或修正当前轮
     实现记录(当前轮尚未评审,直接改本轮记录,不开新轮),再重跑。
   - 含"已终止"(看门狗触发)或"结构不合法"(评审输出没通过脚本的输入
     校验,未发布)→ 直接重跑一次;再次异常 → 报用户停下。
   - 含"进行中"→ 确有评审进程存活(正常并发,或脚本被强杀后遗留的
     codex),把 stderr 中的持有者列表与处置命令原样报用户,不自行 kill。
   - 含"旧版锁目录"(仅升级后首次可能出现)→ 确认 `pgrep -f 'codex exec'`
     为空后按提示 rmdir 该目录,重跑一次。
   - 其它 → 把 stderr 报给用户后停下,不要自行绕过。
   评审模型默认不指定,用 Codex 默认模型。仅当**用户明确点名**实现评审的模型
   或推理强度时,才在发起评审之前往 plan.md frontmatter 写
   `impl_review_model: <模型名>` / `impl_review_effort: <强度>`(裸值,不加
   引号;两个字段互相独立),并在实现记录中注明,不得自行写入。写法不对,或
   Codex 不支持该取值(stderr 含"codex exec 执行失败")时脚本 exit 3、不消耗
   轮次,归入上面的"其它"处理。
2. 读取新生成的 review-round-<NN>-<pass|fail>.md,按顺序分流。结论由脚本
   根据「问题清单」推导:清单里有 blocker 或 major 即 fail。修复轮上限取
   plan.md frontmatter 的 `impl_fix_max_rounds`,字段缺失或非正整数一律按
   **默认 3**(取值规则与 rawf-implement 一致):
   - 「问题清单」里存在 plan-blocker → 不进入修复。向用户完整转述该问题,
     由用户决定退回 /rawf-plan 重做方案,或人工处理。
   - fail 且 NN < 上限 → 进入 /rawf-implement 修复轮。
   - fail 且 NN ≥ 上限 → 停止修复。向用户汇报未决的问题清单,交人工判断。
   - pass → 进入汇报收尾。
   用户中途明确要求追加修复轮数时,更新 plan.md 的 `impl_fix_max_rounds`
   并在下一轮实现记录中注明;不得未经用户提出而自行修改该字段。
3. 评审文件里**不计入分流**的三节,各有去处:
   - 「范围核对」(`scope_findings`):非空时原样转述给用户裁决——用户认可的
     范围外改动在下一轮实现记录或 summary 中注明,不认可的在修复轮回退或
     移入停车场;不自行解释掉。
   - 「测试缺口」与「建议」(含带〔降级〕标记的条目):**由你处置,不找用户**。
     进入修复轮时,在该轮实现记录的「评审建议处置」表逐条写采纳与否及理由;
     评审 pass 时不为它们另开一轮,留到 /rawf-report 写入小结。
4. 认为「问题清单」里的某条 blocker / major 是误报时,不得"解释掉"后静默
   忽略:原样呈给用户裁决,用户同意不修的,在下一轮实现记录或汇报中注明。
   带〔降级〕标记的条目已经不阻断,不需要申诉。
