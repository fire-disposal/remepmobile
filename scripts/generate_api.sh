#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="openapi_generator.yaml"
OUTPUT_DIR="lib/core/api/generated/client"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "未找到 $CONFIG_FILE"
  exit 1
fi

rm -rf "$OUTPUT_DIR"

# 使用 openapi_generator 包执行生成。
dart run openapi_generator generate \
  --config "$CONFIG_FILE"

# 修复 / 更新 API 生成代码依赖。
dart run build_runner build --delete-conflicting-outputs

echo "✅ OpenAPI 客户端生成完成：$OUTPUT_DIR"
