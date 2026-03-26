import 'package:flutter_modular/flutter_modular.dart';

import '../network/dio_client.dart';
import 'config/api_client_config.dart';

/// API 模块：集中管理网络配置与后续自动生成客户端依赖。
class ApiModule extends Module {
  @override
  void binds(Injector i) {
    i.addSingleton<ApiClientConfig>((_) => ApiClientConfig.fromEnv());

    // 统一 Dio 入口，生成 API 客户端时复用该实例。
    i.addSingleton<DioClient>(
      (i) => DioClient(config: i.get<ApiClientConfig>()),
    );
  }
}
