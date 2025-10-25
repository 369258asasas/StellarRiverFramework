OneBot 机器人框架开发文档

目录

1. 框架简介
2. 快速开始
3. 配置说明
4. 插件开发指南
5. API 使用方法
6. 注意事项
7. 常见问题

框架简介

这是一个基于 OneBot 协议的 Python 机器人框架，具有以下特点：

核心功能

· 插件化架构 - 支持热加载插件，无需重启机器人
· 异步处理 - 基于 asyncio 的高性能异步处理
· API 管理 - 自动重试、请求去重、连接池管理
· 安全机制 - Token 验证、权限控制、目录清理
· 日志系统 - 分级日志、自动清理、插件独立日志

技术特性

· 支持 NapCat 后端
· 自动依赖安装
· 热重载机制
· 共享状态管理
· 事件去重处理

快速开始

环境要求

· Python 3.7+
· 安装依赖：pip install aiohttp

启动步骤

1. 配置 config.py 文件
2. 运行主程序：python main.py
3. 框架将自动创建必要目录和文件

目录结构

```
bot_framework/
├── main.py          # 主程序入口
├── config.py        # 配置文件
├── api.py           # API 接口封装
├── app.py           # 应用核心
├── server_manager.py # 服务器管理
├── shared_state.py  # 共享状态管理
├── plugins/         # 插件目录
└── logs/           # 日志目录
```

配置说明

基础配置 (config.py)

```python
# Token 配置 - 用于 API 认证
TOKEN = "your_secret_token_here"

# API 基础地址 - NapCat 服务地址
API_BASE_URL = "http://localhost:3000"

# 事件服务器配置
EVENT_SERVER_HOST = "0.0.0.0"  # 监听地址
EVENT_SERVER_PORT = 8080       # 监听端口
```

功能配置

```python
# 插件相关
PLUGINS_DIR = "plugins"                    # 插件目录
PLUGIN_EVENT_TIMEOUT = 20                  # 插件处理超时时间

# 日志配置
LOG_LEVEL = "INFO"                         # 日志级别
LOG_FILE_MAX_DAYS = 1                      # 日志保留天数

# 高级功能
ENABLE_DEBUG = False                       # 调试模式
HOT_RELOAD = True                         # 热重载
AUTO_INSTALL_MODULES = True               # 自动安装依赖
```

插件开发指南

插件基本结构

每个插件都是一个独立的 Python 文件，放在 plugins 目录下。

最简单的插件示例：

```python
# plugins/hello_plugin.py

class Plugin:
    def __init__(self, context):
        self.context = context
        self.logger = context.logger
        self.logger.info("Hello 插件已加载！")
    
    async def handle_event_async(self, event):
        # 处理收到的事件
        if event.get("post_type") == "message":
            self.logger.info(f"收到消息: {event.get('message')}")
```

完整插件模板

```python
# plugins/my_plugin.py

class Plugin:
    def __init__(self, context):
        """
        插件初始化
        context: 插件上下文，包含各种工具方法
        """
        self.context = context
        self.logger = context.logger
        self.plugin_name = context.plugin_name
        
        # 在共享状态中注册变量
        self.context.shared_vars.register_shared_var("message_count", 0)
        
        self.logger.info(f"{self.plugin_name} 插件初始化完成")
    
    async def handle_event_async(self, event):
        """
        异步处理事件的方法
        event: 收到的事件数据
        """
        try:
            # 1. 处理群消息
            if event.get("post_type") == "message" and event.get("message_type") == "group":
                await self.handle_group_message(event)
            
            # 2. 处理私聊消息
            elif event.get("post_type") == "message" and event.get("message_type") == "private":
                await self.handle_private_message(event)
            
            # 3. 处理艾特消息
            elif event.get("post_type") == "at_message":
                await self.handle_at_message(event)
                
        except Exception as e:
            self.logger.error(f"处理事件时出错: {e}")
    
    async def handle_group_message(self, event):
        """处理群消息"""
        message = event.get("raw_message", "").strip()
        group_id = event.get("group_id")
        user_id = event.get("user_id")
        
        # 更新消息计数
        count = self.context.shared_vars.get_shared_var("message_count", 0)
        self.context.shared_vars.set_shared_var("message_count", count + 1)
        
        # 响应特定命令
        if message == "!hello":
            from api import bot_api
            await bot_api.send_group_msg(group_id, f"你好！用户 {user_id}")
    
    async def handle_at_message(self, event):
        """处理艾特消息"""
        if event.get("bot_at_included"):
            message = event.get("message", "").strip()
            group_id = event.get("group_id")
            
            if "你好" in message:
                from api import bot_api
                await bot_api.send_group_msg(group_id, "你好呀！我在呢~")
    
    async def handle_private_message(self, event):
        """处理私聊消息"""
        message = event.get("raw_message", "").strip()
        user_id = event.get("user_id")
        
        if message == "帮助":
            from api import bot_api
            await bot_api.send_private_msg(user_id, "这是帮助信息...")
```

插件上下文说明

插件初始化时会收到一个 context 对象，包含以下属性：

· context.plugin_name - 插件名称
· context.logger - 插件专用的日志记录器
· context.global_vars - 只读的全局变量（框架层设置）
· context.shared_vars - 插件的共享变量（插件间通信）

共享变量使用

```python
# 注册共享变量（只在插件初始化时调用）
self.context.shared_vars.register_shared_var("user_data", {})

# 设置共享变量
self.context.shared_vars.set_shared_var("user_data", {"last_active": time.time()})

# 获取共享变量
user_data = self.context.shared_vars.get_shared_var("user_data", {})

# 获取本插件的所有共享变量
my_vars = self.context.shared_vars.get_plugin_shared_vars()
```

API 使用方法

基础 API 调用

```python
from api import bot_api

# 发送群消息
await bot_api.send_group_msg(group_id, "Hello World!")

# 发送私聊消息
await bot_api.send_private_msg(user_id, "私人消息")

# 获取群列表
result = await bot_api.get_group_list()
if result.get("status") == "ok":
    groups = result.get("data", [])
```

常用 API 方法

消息相关：

```python
# 发送消息（自动判断类型）
await bot_api.send_msg(message="消息内容", user_id=123, group_id=456)

# 撤回消息
await bot_api.recall_msg(message_id)

# 获取消息详情
msg_info = await bot_api.get_msg(message_id)
```

群管理相关：

```python
# 获取群信息
group_info = await bot_api.get_group_info(group_id)

# 获取群成员列表
members = await bot_api.get_group_member_list(group_id)

# 设置群管理员
await bot_api.set_group_admin(group_id, user_id, enable=True)

# 禁言用户
await bot_api.set_group_ban(group_id, user_id, duration=600)  # 10分钟
```

文件相关：

```python
# 上传群文件
await bot_api.upload_group_file(group_id, file_path, file_name)

# 获取图片信息
image_info = await bot_api.get_image(file_id)
```

API 响应格式

所有 API 调用返回统一的格式：

```python
{
    "status": "ok",      # 或 "failed"
    "retcode": 0,        # 返回码，0表示成功
    "data": {...},       # 响应数据
    "msg": "",           # 消息说明
    "wording": ""        # 详细说明
}
```

注意事项

安全注意事项

1. Token 安全
   · 使用强密码作为 Token
   · 长度至少16位，包含大小写字母、数字和特殊字符
   · 定期更换 Token
2. 插件安全
   · 只加载可信来源的插件
   · 定期检查插件代码
   · 使用插件上下文而非直接访问框架内部
3. 目录安全
   · 框架会自动清理非允许的文件
   · 不要手动修改框架核心文件

开发注意事项

1. 异步处理
   · 所有事件处理必须使用 async/await
   · 避免在插件中进行阻塞操作
   · 使用 asyncio.sleep() 而非 time.sleep()
2. 错误处理
   · 妥善处理所有异常
   · 使用插件日志记录错误信息
   · 避免插件崩溃影响框架运行
3. 资源管理
   · 及时关闭文件、网络连接等资源
   · 使用共享状态而非全局变量
   · 避免内存泄漏

性能优化

1. 减少 API 调用
   · 使用请求去重机制
   · 合并多个操作
   · 使用缓存机制
2. 优化事件处理
   · 快速处理事件，避免阻塞
   · 使用异步任务处理耗时操作
   · 合理设置超时时间

常见问题

Q: 插件没有加载怎么办？

A: 检查以下项目：

· 插件文件是否在 plugins 目录下
· 文件名是否以 .py 结尾
· 插件类是否命名为 Plugin
· 查看日志文件中的错误信息

Q: API 调用失败怎么办？

A: 排查步骤：

1. 检查 NapCat 服务是否正常运行
2. 验证 Token 配置是否正确
3. 查看 API 日志了解详细错误
4. 检查网络连接

Q: 热重载不生效怎么办？

A: 确保：

· HOT_RELOAD = True
· 插件文件修改后保存
· 等待热重载间隔（默认5秒）
· 检查插件语法是否正确

Q: 如何调试插件？

A: 调试方法：

1. 设置 ENABLE_DEBUG = True
2. 查看插件独立日志文件
3. 使用 self.logger.debug() 输出调试信息
4. 检查 logs/ 目录下的日志文件

Q: 插件间如何通信？

A: 使用共享状态：

```python
# 插件A设置数据
self.context.shared_vars.set_shared_var("shared_data", value)

# 插件B获取数据
data = self.context.shared_vars.get_shared_var("shared_data")
```

Q: 如何处理插件依赖？

A: 框架支持自动安装依赖：

· 设置 AUTO_INSTALL_MODULES = True
· 在插件中正常 import 所需模块
· 框架会自动检测并安装缺失模块

进阶功能

自定义事件处理

除了基础的 handle_event_async 方法，你还可以实现更精细的事件处理：

```python
async def handle_event_async(self, event):
    post_type = event.get("post_type")
    
    if post_type == "message":
        await self.handle_message(event)
    elif post_type == "notice":
        await self.handle_notice(event)
    elif post_type == "request":
        await self.handle_request(event)
    elif post_type == "meta_event":
        await self.handle_meta_event(event)

async def handle_message(self, event):
    # 专门处理消息事件
    pass

async def handle_notice(self, event):
    # 处理通知事件（群员增减、管理员变动等）
    notice_type = event.get("notice_type")
    if notice_type == "group_increase":
        # 处理新成员入群
        pass
```

定时任务处理

```python
import asyncio

class Plugin:
    def __init__(self, context):
        self.context = context
        # 启动定时任务
        asyncio.create_task(self.periodic_task())
    
    async def periodic_task(self):
        while True:
            try:
                # 每60秒执行一次的任务
                await self.do_something()
                await asyncio.sleep(60)
            except Exception as e:
                self.context.logger.error(f"定时任务出错: {e}")
                await asyncio.sleep(10)  # 出错后等待10秒重试
    
    async def do_something(self):
        # 定时执行的操作
        pass
```

---

重要提醒: 请遵守相关法律法规，合理使用机器人框架。不要用于骚扰、 spam 或其他不当用途。

如有更多问题，请查看框架日志或联系开发者。
