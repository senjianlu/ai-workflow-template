---
name: rawf-implement
description: rawf 工作流第 3 步:按已确认的 plan.md 实现并自测,产出 implementation-round-<NN>.md;评审 fail 后的修复轮同样使用本 skill。仅在当前任务 plan 的 status 为 approved 后使用。
---

# rawf-implement:实现阶段

## 前置检查

1. 读 `.ai/.current-task` 定位任务目录;读 plan.md,确认 `status: approved`。
   不是 approved → 停,回到 /rawf-plan 的确认闸,不要试图绕过。
2. 计算轮次:NN = 目录中已有 implementation-round-*.md 数量 + 1(两位数)。
   若 NN > 3:停止实现,向用户说明已达修复轮上限,交人工判断。

## 实现

3. 第 1 轮:按 plan 实现。第 2 轮起:只修 review-round-<上一轮>-fail.md 中的
   blocker 与 major,逐项对应;不顺手重构无关代码,评审范围外的"改进"会
   污染下一轮 diff。
4. 与 plan 的任何偏差都必须记入产物的"与方案的偏差"一节。偏差若动到方案
   的核心(架构、接口、范围),先停下来问用户,不自作主张。

## 自测

5. 逐条执行 plan.md 的全部测试用例,记录真实结果与证据(实际命令 + 关键
   输出)。未执行的写"未执行"+原因,失败的写失败——评审者会重跑验证,
   虚报通过在评审中是 blocker 级问题。
6. 全部用例通过之前不进入评审;反复修不过,向用户说明卡点。

## 产物与交接

7. 按 .ai-workflow/templates/implementation-round.md 写
   implementation-round-<NN>.md 到任务目录。
8. 写完直接进入 /rawf-review,无需用户确认(评审不改代码)。
