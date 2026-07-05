---
name: rawf-stack-scrapy
description: 本项目爬虫(Python 3 + Scrapy)的初始化、编码与测试约定。在爬虫代码上写方案或开发时使用。
---

# Scrapy 栈约定

## 初始化(开新项目时执行一次)
- `uv init && uv add scrapy && uv add --dev pytest ruff`
- `uv run scrapy startproject <name> .`

## 编码约定
<!-- TEMPLATE: 按个人习惯增删。 -->
- 解析逻辑与请求逻辑分离,解析函数可脱离网络单测(喂本地 HTML fixture)
- 重试、去重、增量策略写在 settings/middleware,不散落在 spider 里
- 对目标站点保持克制:并发与延迟显式配置,不用默认值

## 测试与自测命令
- 解析单测:`uv run pytest`(用 tests/fixtures/ 下的 HTML 快照)
- 冒烟:`uv run scrapy crawl <spider> -s CLOSESPIDER_ITEMCOUNT=3`
