---
name: rawf-stack-scrapy
description: Scrapy 爬虫栈的初始化、编码与测试约定。新建爬虫应用,或为爬虫应用写代码/测试时使用。事实约束(标准表、部署链路、工程约定)以 AGENTS.md「技术栈 > 爬虫」为唯一权威,本 skill 只写操作细则。
---

# rawf-stack-scrapy:Scrapy 栈约定

## 初始化

新建爬虫应用时按此顺序落骨架(包名取具名 `<snake_name>`,不得叫 `app`):

1. `pyproject.toml`:运行时依赖(scrapy、sqlalchemy、psycopg、redis、
   pydantic-settings、httpx 等)与 dev 工具(pytest、ruff)都写在这里,
   它是依赖版本约束的唯一权威;ruff / pytest 配置同后端约定。
2. 包骨架:
   - `<snake_name>/spiders/base.py`(spider 基类:统一 item 标注、
     信号挂接等横切逻辑)
   - `<snake_name>/settings.py`(Scrapy settings;敏感与环境相关值
     经 pydantic-settings 读入,不硬编码)
   - `<snake_name>/items.py`
   - `<snake_name>/pipelines/`、`<snake_name>/middlewares/`(包目录,
     模块文件名 snake_case)
3. `scrapy.cfg` 在应用根:`[settings]` 段必有;不经 dopilot 直连
   scrapyd 部署时加 `[deploy]` target。
4. `setup.py`:只承担 `.egg` 打包,**必须**声明
   `entry_points={"scrapy": ["settings = <snake_name>.settings"]}`,
   否则 scrapyd 注册后无法定位 settings 与 spider。
5. `tests/` 与包平级、镜像包结构;响应样本放 `tests/fixtures/`。
6. `.env.example`:列出全部环境变量及注释,不含真实值。

## 编码

- 配置一律走 pydantic-settings 的 Settings 类,settings.py 从中取值;
  禁止在代码里手拼连接串。
- 新 spider 继承 `spiders/base.py` 基类,站点差异收敛在子类
  `custom_settings` 内。
- 阻塞调用(同步驱动、重计算)不得混入 reactor/事件循环:下沉
  `asyncio.to_thread` 或 Twisted `deferToThread`。
- selector 取值必须有防御:用 `.get(default=...)` / `.getall()`,
  不裸下标;页面结构变化应表现为数据缺失告警,不是异常崩溃。
- pipeline / middleware 不得静默吞异常;丢弃 item 用 `DropItem`
  并记日志。
- 可选扩展(浏览器渲染与指纹对抗、抓包代理、跨系统消息、AI 辅助解析、
  对象存储上传等)按需引入,引入时在项目 docs/decisions/ 记录理由。

## 测试

- spider 解析逻辑离线测:样本入 `tests/fixtures/`,用
  `scrapy.http.HtmlResponse` / `TextResponse` 构造响应喂给 parse 方法,
  断言产出的 item;单元测试不访问真网。
- pipeline 用替身测:Redis 用 fakeredis,数据库用 aiosqlite(或按需
  内存实现),不依赖外部服务。
- `scrapy check` 与 `scrapy crawl <spider> -s CLOSESPIDER_ITEMCOUNT=N`
  仅作本地冒烟,不进 CI 断言。
