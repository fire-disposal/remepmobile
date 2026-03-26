# ReMep Mobile

ReMep Mobile 是一个基于 Flutter + Modular 的移动健康系统客户端。

## 新架构概览

本仓库已按“核心能力 + 功能模块”拆分：

- `lib/core/`：基础设施（网络、存储、MQTT、权限、主题等）
- `lib/core/api/`：API 模块化配置（客户端配置、请求鉴权策略、自动生成产物目录）
- `lib/features/*`：按业务边界拆分的独立功能模块
- `lib/app_module.dart`：应用路由聚合与模块装配

### 匿名访问与鉴权能力

API 请求现在支持按请求粒度声明是否需要鉴权：

- 默认 `requireAuth = false`，即允许未登录访问“非鉴权功能”
- 对需要登录的接口显式传入 `requireAuth: true`
- `AuthInterceptor` 仅在 `requireAuth: true` 时注入 Bearer Token

## API 自动生成

仓库已提供 OpenAPI 自动生成配置：

- 配置文件：`openapi_generator.yaml`
- 生成脚本：`scripts/generate_api.sh`
- 默认输出：`lib/core/api/generated/client`

### 使用方式

```bash
./scripts/generate_api.sh
```

脚本会：

1. 按 `openapi_generator.yaml` 生成 dart-dio 客户端
2. 运行 `build_runner` 生成相关序列化依赖代码

## Getting Started

```bash
flutter pub get
flutter run
```
