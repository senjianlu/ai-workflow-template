# Plan 评审:第 01 轮

## 问题清单
- [major] R-01 核心安全与资源验收没有绑定到 review.sh 的实际执行路径
  - 详情:plan.md:109-111 的 TC-01 只比较运行前后临时目录；即使 review.sh 仍创建并在退出前删除 2.4G 副本，该用例也会通过，无法覆盖“消除运行期全量复制/资源峰值”的核心目标。TC-02 又是独立执行 `codex exec --sandbox read-only`，不经过 review.sh；即使脚本误保留 `workspace-write` 或对原仓库开放写入，TC-02 仍会通过。应增加直接约束脚本实际路径的测试：用 codex 桩记录并断言 review.sh 传入 `--sandbox read-only` 和 `-C <原仓库>`；静态断言或在运行期间监测不存在 `mktemp`、`cp -Rp`、`rawf-review-*` 副本创建；并让桩在 review.sh 调用期间尝试写仓库，断言写入被拒且不发布受污染结果。

## 总评
方案的架构取舍、文档与 skill 契约同既有 rawf 分流总体自洽，证据缺失等异常路径也有覆盖。但测试无法证明实际 review.sh 已取消瞬时副本且确实以只读沙箱直审原仓库，这两项正是本次变更的核心验收，需补强后再实施。

VERDICT: fail
