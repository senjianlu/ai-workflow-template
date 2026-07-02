#!/usr/bin/env bash
set -euo pipefail

# 把未追踪的新文件标记为 intent-to-add，使其进入 diff（仅标记，不真正暂存内容）
git add -N .

diff=$(git diff HEAD)
if [ -z "$diff" ]; then
  echo "没有改动，跳过评审。"
  exit 0
fi

codex exec --sandbox workspace-write "作为独立代码评审者，评审下面的补丁。
严格遵循仓库根目录 AGENTS.md 的约定，不使用通用默认标准替代项目规则。

在 .ai/<date>/<task>/ 中定位与本次补丁对应的任务目录，结合 plan.md 和各轮 implementation-round-<NN>.md 进行审查；评审轮次须与当前最高实现轮次一致。
按 blocker / major / minor 分类列出问题，并区分「实现层」与「方案/架构层」。
实现层存在任一 blocker 或 major 判 fail；仅有 minor 或无问题判 pass。
方案/架构层 blocker 须在结论中标注【需升级人工/退回方案】，且不计入修复轮次。

将完整评审结果写入对应任务目录的 review-round-<NN>-<pass|fail>.md；除该评审文件外，禁止新增、修改或删除任何文件。

补丁:
$diff"
