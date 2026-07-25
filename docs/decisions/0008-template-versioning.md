# 0008:模板按 SemVer 版本化,consumer 记录采用版本并按 tag 差异增量升级

- 日期:2026-07-25
- 背景:模板持续演进(如 0007 新增爬虫栈),已采用模板的 consumer
  项目没有版本锚点,流程变更后只能与模板全量比较,升级成本高且易漏。
- 决定:
  1. 模板按 SemVer 发版,语义按闸门兼容性分级(MAJOR=闸门协议不
     兼容,MINOR=向后兼容新增,PATCH=向后兼容修复);每版打 git
     tag 并发布同名 GitHub Release(notes 取 CHANGELOG 条目),发版
     提交同步更新 CHANGELOG.md 与 .ai-workflow/TEMPLATE-VERSION,
     起点 v1.0.0;
  2. consumer 以 .ai-workflow/TEMPLATE-VERSION(version/source/
     adopted 三字段)记录采用版本;该文件置于 .ai-workflow/ 内,
     升级整目录拷贝时版本号自动随行;
  3. 升级在模板仓库的单独克隆中锚定 NEW tag 快照取增量,consumer
     不添加模板 remote、不引入模板 tag;受管路径分"可整体替换 /
     需人工合并"两类,清单固化在 CHANGELOG 头部归类行;
  4. 存量项目须先对 v1.0.0 完成全量基线对齐才可认领版本,对齐前
     记 unknown 并继续全量比较;
  5. 被否备选:copier/cruft 模板实例化工具(须全仓模板化改造,
     机制重,违背低维护偏好);发布/升级自动化脚本(发版低频,
     手工命令足够;曾按评审意见起草发布脚本并演化出十余个验收
     场景,由用户裁决回归最小实践,脚本整体移除)。
- 影响:每次发版三同步(CHANGELOG / TEMPLATE-VERSION / tag+Release),
  纪律靠人,无机器强制,频繁漏更再议 CI 校验;README「版本与升级」
  为 consumer 升级的权威操作指引;「存量项目迁移」新增版本认领步骤。
