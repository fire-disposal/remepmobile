# ReMep Mobile

ReMep Mobile 当前以「统一登录 + 后台壳层 + 轻量路由」为核心，优先降低多人并行开发时的心智负担。

## 设计原则（当前版本）

- **少层次、少跳转**：不强求每个功能都有独立 `Module`。
- **鉴权全局化**：登录和会话管理只在基础设施层处理。
- **功能接入最短路径**：新增功能通常只需要两步：
  1. 在 `app_sections.dart` 注册菜单项。
  2. 在 `app_module.dart` 增加一个 `ChildRoute` 页面。

## 核心结构

- `lib/core/`：基础设施与控制器统一注册（DI 集中管理）
- `lib/app_sections.dart`：内部模块注册表（菜单 + 路由）
- `lib/app_module.dart`：应用路由入口（登录态 + `/app/*`）
- `lib/pages/app_shell_page.dart`：后台壳层（NavigationRail + RouterOutlet）

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
