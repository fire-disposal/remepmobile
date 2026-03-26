/// OpenAPI 自动生成约定。
///
/// 1. 通过 `scripts/generate_api.sh` 生成到 `lib/core/api/generated/client`。
/// 2. 生成后的 API client 依赖统一复用 `DioClient.dio`。
/// 3. 业务模块仅依赖本目录导出的 facade，不直接依赖生成器脚本。
abstract final class OpenApiGeneration {
  static const outputDir = 'lib/core/api/generated/client';
  static const inputSpec = 'openapi.json';
  static const configFile = 'openapi_generator.yaml';
}
