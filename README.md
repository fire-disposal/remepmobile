# ReMep Mobile

当前版本为**本地测试优先**应用：无登录、无后端鉴权依赖，主界面为顶部栏 + 卡片入口，用于快速验证 MQTT / 视觉跌倒 / IMU 跌倒 / 蓝牙接收调试。

## 当前模块

- MQTT 数据模拟
- 视觉跌倒检测（开发起点：依赖检查 + 模型加载占位 + 单次推理模拟）
- IMU 跌倒检测（开发起点：`sensors_plus` 实时流 + 阈值策略 + mock 采样）
- 蓝牙数据接收调试

## 关键依赖（视觉 + IMU）

```bash
flutter pub add camera tflite_flutter permission_handler path_provider sensors_plus
```

> 视觉模块默认按 `camera + tflite_flutter + assets/models` 的接入路径设计。
> IMU 模块默认按 `sensors_plus` 加速度流接入，阈值逻辑可直接替换为业务策略。

## 路由

- `/`：启动页（自动跳转）
- `/app/dashboard`：模块入口卡片页
- `/app/mqtt-simulator`
- `/app/vision-fall-detection`
- `/app/imu-fall-detection`
- `/app/bluetooth-debug`

## 快速开始

```bash
flutter pub get
flutter run
```
