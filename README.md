# ReMep Mobile

ReMep Mobile 当前以「跌倒检测节点 + MQTT 模拟发送 + 遥控器模拟」为核心，优先保证体验高效、快捷、可靠。

## 设计原则（当前版本）

- **少层次、少跳转**：不强求每个功能都有独立 `Module`。
- **无鉴权优先**：当前环境默认无 MQTT 鉴权，连接时可不填写用户名/密码。
- **可配置连接参数**：Broker 域名/IP 与端口均可在页面自由配置。
- **功能接入最短路径**：新增功能通常只需要两步：
  1. 在 `app_sections.dart` 注册菜单项。
  2. 在 `app_module.dart` 增加一个 `ChildRoute` 页面。

## 核心结构

- `lib/core/`：基础设施与控制器统一注册（DI 集中管理）
- `lib/app_sections.dart`：内部模块注册表（菜单 + 路由）
- `lib/app_module.dart`：应用路由入口（登录态 + `/app/*`）
- `lib/pages/app_shell_page.dart`：后台壳层（NavigationRail + RouterOutlet）

## MQTT 协议约定（v2）

- `topic_pattern`: `remipedia/devices/{serial_number}/{device_type}`
- `qos`: `at_least_once (QoS1)`
- payload 必填：`timestamp (RFC3339)` 与 `value` 或 `data`
- payload 选填：`device_type`、`serial_number/sn`、`metadata`

## 路由

- `/`：启动页（恢复会话并重定向）
- `/login`：统一登录
- `/app/dashboard`
- `/app/mqtt-debug`
- `/app/fall-detector`
- `/app/settings`

`/app/*` 全部受 `AuthGuard` 保护。

## 快速开始

```bash
flutter pub get
flutter run
```
