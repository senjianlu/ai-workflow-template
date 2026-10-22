# 评审:第 01 轮

## 问题清单
- [major] R-01 子进程忽略 TERM 时，留证器无法执行强制终止并完成收尾。
  - 详情:.ai-workflow/scripts/evidence.sh:97：收到中断后，循环仍先阻塞于 wait "$child"；只有子进程退出才能进入第 102 行的五秒宽限及 KILL 分支。因此被包命令忽略 TERM 时，强制终止逻辑不可达，包装器持续等待且无法写出尾部。应在收到信号后立即进入有界清理流程，超时 KILL 后再回收子进程；补充忽略 TERM 的子进程场景。
- [major] R-02 中断后的退出码未按方案固定为 INT=130、TERM=143。
  - 详情:.ai-workflow/scripts/evidence.sh:81：INT 与 TERM 均被转换为 TERM，而最终记录及返回的是 wait 得到的子进程状态，interrupted 仅用于判断是否清理。INT 中断普通子进程会得到 143；子进程捕获 TERM 并正常退出时，还可能得到 0，使取消操作被记录为成功。应保留收到的信号，在清理完成后明确设置对应的 130/143；补充 INT 及子进程处理 TERM 后退出 0 的验证。
- [major] R-03 TC-07 未验证方案要求的 stderr 补交清单，实际实现也输出到了 stdout。
  - 详情:.ai/2026-10-22/scope-guard-and-evidence-format/evidence/tc-07.sh:31：断言脚本用 2>&1 合并两路输出，只检查合并内容，未覆盖 TC-07 明确要求的“stderr 补交清单逐条列出编号与所缺项”。.ai-workflow/scripts/evidence-check.sh:202 的 echo/printf 实际均写 stdout，独立调用时重定向报告会同时移走错误清单。应按方案将补交清单写入 stderr，并分别捕获 stdout/stderr 断言；同步调整 review.sh 的捕获方式，保留启动失败时的完整诊断。

## 范围核对
无

## 总评
已审查未提交改动及新增文件，并逐条核对 19 个用例的脚本与证据；TC-14 首次失败和重跑记录一致，未复判证据格式。发现两项中断处理缺陷及一项验收覆盖缺口，判定 fail；本轮未运行测试、未修改文件。

VERDICT: fail
