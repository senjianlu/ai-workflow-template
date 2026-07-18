---
name: rawf-implement
description: rawf 工作流第 3 步:按已确认的 plan.md 实现并自测,产出 implementation-round-<NN>.md;评审 fail 后的修复轮同样使用本 skill。仅在当前任务 plan 的 status 为 approved 后使用。
---

# rawf-implement:实现阶段

## 前置检查

1. 读 `.ai/.current-task` 定位任务目录;读 plan.md,确认 `status: approved`。
   不是 approved → 停,回到 /rawf-plan 的确认闸,不要试图绕过。
2. 计算轮次:NN = 目录中已有 implementation-round-*.md 数量 + 1(两位数)。
   修复轮上限:取 plan.md frontmatter 的 `impl_fix_max_rounds`;字段缺失
   或非正整数一律按**默认 3**。该字段仅当用户明确要求放宽时写入,不得
   自行添加。若 NN > 上限:停止实现,向用户说明已达修复轮上限,交人工判断。

## 实现

3. 第 1 轮:按 plan 实现。第 2 轮起:只修 review-round-<上一轮>-fail.md 中的
   blocker 与 major,逐项对应;不顺手重构无关代码,评审范围外的"改进"会
   污染下一轮 diff。
4. 与 plan 的任何偏差都必须记入产物的"与方案的偏差"一节。偏差若动到方案
   的核心(架构、接口、范围),先停下来问用户,不自作主张。

## 自测

5. 逐条执行 plan.md 的全部测试用例,记录真实结果与证据(实际命令 + 关键
   输出)。未执行的写"未执行"+原因,失败的写失败——评审者在只读沙箱中
   **不重跑任何测试**(review-standards.md「评审动作边界」),测试真实性
   完全靠证据核验,虚报通过在评审中是 blocker 级问题。证据落盘:**所有
   测试用例的完整原始输出**(命令、输出、退出码)**必须**落任务目录
   `evidence/`——证据缺失或不完整,评审将按 blocker 打回并开出补交
   清单;截图等其他证据同样落 `evidence/`;引用的素材(Design 稿、
   参考图)放 `assets/`。以上均须在**评审前**落盘——`.ai/` 计入
   review.sh 指纹,评审进行中写入会使评审无效(见 CLAUDE.md 硬规则)。
6. 全部用例通过之前不进入评审;反复修不过,向用户说明卡点。

## 产物与交接

7. 按 .ai-workflow/templates/implementation-round.md 写
   implementation-round-<NN>.md 到任务目录。
8. 写完直接进入 /rawf-review,无需用户确认(评审不改代码)。
