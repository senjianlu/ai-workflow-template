# Changelog

本文件记录 ai-workflow-template 的版本历史,体例遵循
[Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/),版本号遵循
[SemVer](https://semver.org/lang/zh-CN/)(语义分级规则见 README
「版本与升级」)。

受管路径归类(每个版本条目的升级指引按此标注文件所属类别):

- 可整体替换:.ai-workflow/、.claude/hooks/、.claude/skills/rawf-*、.claude/settings.json、.githooks/、.gitmessage
- 需人工合并:AGENTS.md、CLAUDE.md、README.md、.agents/skills/、skills-lock.json

(需人工合并的原因:前三者 consumer 已按项目裁剪;后两者为项目内建
skill 目录及其内容哈希锁,consumer 可能持有自有条目,须经锁机制合并。
settings.local.json 属本机个人授权,不受管。)

每个版本条目必须含「升级指引」小节,逐文件标注归类与迁移动作。

## [1.0.0] - 2026-07-25

首个版本,当前形态:rawf 开发工作流(plan 与实现两级 Codex 评审、
测试证据协议、hooks 硬闸门)、标准技术栈(前端两套 / 后端 FastAPI /
爬虫 Scrapy)、版本与升级机制(TEMPLATE-VERSION + 本文件 + README
升级流程)。

### 升级指引

基线版本,无升级来源。
