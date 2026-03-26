# ReMep Mobile 技术选型文档

## 项目概述

ReMep Mobile 是一个面向移动健康系统的Flutter应用基础架构，采用模块化设计，支持iOS和Android双平台。

---

## 核心技术栈

### 1. 框架与语言
| 技术 | 版本 | 说明 |
|------|------|------|
| Flutter | 3.x | 跨平台UI框架 |
| Dart | 3.x | 编程语言，支持空安全 |

### 2. 状态管理
| 技术 | 选型 | 理由 |
|------|------|------|
| **Riverpod** | flutter_riverpod ^2.4.0 | 编译时安全、可测试、支持依赖注入、无需BuildContext |

**替代方案对比**:
- Bloc: 学习曲线较陡，模板代码多
- Provider: 缺乏编译时安全检查
- GetX: 过于臃肿，违背Flutter设计理念

### 3. 网络请求
| 技术 | 选型 | 理由 |
|------|------|------|
| **Dio** | dio ^5.4.0 | 功能强大，支持拦截器、取消请求、文件上传 |
| **Retrofit** | retrofit ^4.0.0 | 类型安全的API定义，代码生成 |

**架构设计**:
```
ApiClient (Dio配置)
    ├── Interceptors (认证、日志、错误处理)
    ├── ApiService (Retrofit生成)
    └── Repository (数据层封装)
```

### 4. 蓝牙通信
| 技术 | 选型 | 理由 |
|------|------|------|
| **flutter_blue_plus** | flutter_blue_plus ^1.31.0 | 社区活跃、API简洁、支持BLE、跨平台一致性好 |

**功能支持**:
- BLE设备扫描与连接
- 服务与特征值读写
- 状态监听与通知
- 后台模式支持

### 5. MQTT通信
| 技术 | 选型 | 理由 |
|------|------|------|
| **mqtt_client** | mqtt_client ^10.0.0 | 成熟稳定、支持WebSocket、QoS级别控制 |

**功能支持**:
- MQTT 3.1.1/5.0 协议
- TLS/SSL加密
- 自动重连
- 消息持久化

### 6. 国际化 (i18n)
| 技术 | 选型 | 理由 |
|------|------|------|
| **slang** | slang ^3.0.0 + slang_flutter | 类型安全、编译时检查、代码提示友好 |
| **intl** | intl ^0.18.0 | 日期、数字格式化 |

**支持语言**:
- 中文 (zh_CN)
- 英文 (en_US)

### 7. UI组件库与设计
| 技术 | 选型 | 理由 |
|------|------|------|
| **Material 3** | Flutter内置 | 现代设计语言，动态配色 |
| **flutter_screenutil** | flutter_screenutil ^5.9.0 | 屏幕适配 |
| **google_fonts** | google_fonts ^6.1.0 | 丰富的字体选择 |
| **flutter_animate** | flutter_animate ^4.3.0 | 声明式动画 |

**设计原则**:
- Material Design 3 设计语言
- 支持深色/浅色主题
- 响应式布局
- 无障碍设计

### 8. 数据持久化
| 技术 | 选型 | 用途 |
|------|------|------|
| **Hive** | hive ^2.2.0 + hive_flutter | 轻量级键值存储 |
| **Drift** | drift ^2.14.0 | SQLite ORM，复杂数据 |
| **flutter_secure_storage** | flutter_secure_storage ^9.0.0 | 敏感数据加密存储 |

### 9. 依赖注入
| 技术 | 选型 | 理由 |
|------|------|------|
| **Riverpod Provider** | 内置于Riverpod | 统一的状态管理与依赖注入 |

### 10. 路由管理
| 技术 | 选型 | 理由 |
|------|------|------|
| **go_router** | go_router ^13.0.0 | 声明式路由、深链接支持、Web友好 |

### 11. 工具库
| 技术 | 用途 |
|------|------|
| freezed | 不可变数据类、联合类型 |
| json_serializable | JSON序列化 |
| logger | 日志记录 |
| connectivity_plus | 网络状态检测 |
| permission_handler | 权限管理 |
| package_info_plus | 应用信息 |
| device_info_plus | 设备信息 |

---

## 项目架构

### 模块化目录结构

```
lib/
├── main.dart                    # 应用入口
├── app.dart                     # App配置
│
├── core/                        # 核心基础设施 (跨模块共享)
│   ├── constants/               # 常量定义
│   ├── theme/                   # 主题配置
│   ├── router/                  # 路由配置
│   ├── network/                 # 网络层封装
│   │   ├── dio_client.dart
│   │   ├── interceptors/
│   │   └── api_result.dart
│   ├── bluetooth/               # 蓝牙服务封装
│   ├── mqtt/                    # MQTT服务封装
│   ├── storage/                 # 存储服务
│   ├── utils/                   # 工具类
│   └── errors/                  # 错误处理
│
├── shared/                      # 共享组件
│   ├── widgets/                 # 通用UI组件
│   ├── providers/               # 全局状态
│   └── models/                  # 共享数据模型
│
├── features/                    # 功能模块 (模块化)
│   ├── auth/                    # 认证模块
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── pages/
│   │       └── widgets/
│   │
│   ├── device/                  # 设备管理模块
│   ├── health/                  # 健康数据模块
│   └── settings/                # 设置模块
│
├── l10n/                        # 国际化
│   ├── strings.g.dart
│   ├── strings_en.g.dart
│   └── strings_zh_cn.g.dart
│
└── gen/                         # 生成代码
    └── assets.gen.dart
```

### 架构模式

采用 **Clean Architecture** + **Feature-First** 模块化架构:

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  (Widgets, Pages, Providers/Controllers)                     │
├─────────────────────────────────────────────────────────────┤
│                     Domain Layer                              │
│  (Entities, Use Cases, Repository Interfaces)               │
├─────────────────────────────────────────────────────────────┤
│                      Data Layer                               │
│  (Repository Implementations, Data Sources, Models)          │
└─────────────────────────────────────────────────────────────┘
```

**模块间通信**:
- 通过 Domain Layer 的接口定义
- 使用 Riverpod Provider 进行依赖注入
- 事件总线 (可选) 用于跨模块通信

---

## 后端API集成

### 基础配置
- Base URL: `https://iomt.205716.xyz`
- 认证方式: JWT Token (Bearer)
- 数据格式: JSON

### API模块划分
```
core/network/
├── api_client.dart          # Dio实例配置
├── interceptors/
│   ├── auth_interceptor.dart    # 认证拦截器
│   ├── logging_interceptor.dart # 日志拦截器
│   └── error_interceptor.dart   # 错误处理拦截器
├── api_result.dart          # 统一返回结果封装
└── exceptions.dart          # 异常定义
```

---

## 开发规范

### 代码风格
- 使用 `very_good_analysis` 或 `flutter_lints` 作为lint规则
- 遵循 Effective Dart 规范
- 使用 `dart format` 格式化代码

### 命名约定
| 类型 | 命名风格 | 示例 |
|------|----------|------|
| 类 | PascalCase | `UserProfile` |
| 变量/方法 | camelCase | `getUserProfile()` |
| 常量 | camelCase | `maxRetryCount` |
| 文件 | snake_case | `user_profile.dart` |

### Git提交规范
```
feat: 新功能
fix: 修复bug
docs: 文档更新
style: 代码格式
refactor: 重构
test: 测试
chore: 构建/工具
```

---

## 测试策略

| 类型 | 工具 | 覆盖范围 |
|------|------|----------|
| 单元测试 | flutter_test | Domain层、工具类 |
| Widget测试 | flutter_test | UI组件 |
| 集成测试 | integration_test | 关键流程 |
| Mock | mocktail | 依赖模拟 |

---

## 构建与部署

### 环境配置
```
.env.development   # 开发环境
.env.staging       # 预发布环境
.env.production    # 生产环境
```

### 构建命令
```bash
# 开发
flutter run --flavor development

# 构建 APK
flutter build apk --flavor production

# 构建 iOS
flutter build ios --flavor production
```

---

## 依赖版本汇总

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 状态管理
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
  
  # 网络
  dio: ^5.4.0
  retrofit: ^4.0.3
  pretty_dio_logger: ^1.3.1
  
  # 蓝牙
  flutter_blue_plus: ^1.31.0
  
  # MQTT
  mqtt_client: ^10.0.0
  
  # 存储
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  drift: ^2.14.0
  flutter_secure_storage: ^9.0.0
  
  # 国际化
  slang: ^3.25.0
  slang_flutter: ^3.25.0
  intl: ^0.18.1
  
  # UI
  flutter_screenutil: ^5.9.0
  google_fonts: ^6.1.0
  flutter_animate: ^4.3.0
  
  # 路由
  go_router: ^13.0.0
  
  # 工具
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  logger: ^2.0.2
  connectivity_plus: ^5.0.2
  permission_handler: ^11.0.1
  package_info_plus: ^5.0.1
  device_info_plus: ^9.1.0
  flutter_dotenv: ^5.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  
  # 代码生成
  build_runner: ^2.4.7
  riverpod_generator: ^2.3.9
  retrofit_generator: ^8.0.6
  freezed: ^2.4.6
  json_serializable: ^6.7.1
  hive_generator: ^2.0.1
  drift_dev: ^2.14.0
  slang_build_runner: ^3.25.0
  mocktail: ^1.0.2
```

---

## 下一步计划

1. ✅ 项目初始化
2. ✅ 技术选型文档
3. ⏳ 模块化目录结构搭建
4. ⏳ 核心基础设施代码
5. ⏳ 国际化配置
6. ⏳ 主题系统配置
7. ⏳ 示例模块实现