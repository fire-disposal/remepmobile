// 运行方式：dart run scripts/convert_to_dio.dart

import 'dart:io';

void main() {
  final apiDir = Directory('api');
  
  if (!apiDir.existsSync()) {
    print('API 目录不存在');
    return;
  }

  // 查找所有客户端文件
  final clientFiles = apiDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_client.dart') && !f.path.contains('rest_client'))
      .toList();

  for (final file in clientFiles) {
    print('处理：${file.path}');
    convertToDioClient(file);
  }

  print('完成！共处理 ${clientFiles.length} 个文件');
}

void convertToDioClient(File file) {
  final content = file.readAsStringSync();
  
  // 提取类名
  final classMatch = RegExp(r'abstract class (\w+)').firstMatch(content);
  if (classMatch == null) return;
  final className = classMatch.group(1)!;
  
  // 提取模型导入
  final modelImports = <String>[];
  for (final match in RegExp(r"import '\.\./models/(.*?)';").allMatches(content)) {
    modelImports.add(match.group(1)!);
  }

  // 解析方法 - 简化版本
  final methods = <Method>[];
  final lines = content.split('\n');
  
  String? currentMethod;
  String? currentPath;
  String? currentReturnType;
  String? currentName;
  final currentParams = <String>[];
  bool inParams = false;
  
  for (final line in lines) {
    // 检查方法开始
    final methodMatch = RegExp(r'''@(GET|POST|PUT|DELETE|PATCH)\('([^']+)'\)''').firstMatch(line);
    if (methodMatch != null) {
      currentMethod = methodMatch.group(1);
      currentPath = methodMatch.group(2);
      continue;
    }
    
    // 检查返回类型和方法名
    final returnMatch = RegExp(r'Future<(\w+)?>\s+(\w+)').firstMatch(line);
    if (returnMatch != null && currentMethod != null) {
      currentReturnType = returnMatch.group(1) ?? 'void';
      currentName = returnMatch.group(2)!;
      inParams = true;
      continue;
    }
    
    // 收集参数
    if (inParams) {
      if (line.contains('});')) {
        inParams = false;
        if (currentMethod != null && currentPath != null && currentName != null) {
          methods.add(Method(
            httpMethod: currentMethod!,
            path: currentPath!,
            returnType: currentReturnType!,
            name: currentName!,
            params: List.from(currentParams),
          ));
        }
        currentMethod = null;
        currentPath = null;
        currentReturnType = null;
        currentName = null;
        currentParams.clear();
      } else if (line.contains('@Path') || line.contains('@Query') || line.contains('@Body')) {
        currentParams.add(line.trim());
      }
    }
  }

  // 生成 Dio 客户端代码
  final dioCode = '''// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:dio/dio.dart';
${modelImports.map((m) => "import '../models/$m';").join('\n')}

/// $className - Dio 客户端
class $className {
  final Dio _dio;

  $className(this._dio);
${methods.map((m) => m.toDioMethod()).join('\n')}
}
''';

  // 写入新文件
  file.writeAsStringSync(dioCode);
}

class Method {
  final String httpMethod;
  final String path;
  final String returnType;
  final String name;
  final List<String> params;

  Method({
    required this.httpMethod,
    required this.path,
    required this.returnType,
    required this.name,
    required this.params,
  });

  String toDioMethod() {
    final pathParams = <String>[];
    final queryParams = <(String, String)>[]; // (query name, var name)
    String? bodyParam;
    final cleanParams = <String>[];
    
    for (final part in params) {
      // 检查 @Path
      final pathMatch = RegExp(r"@Path\('([^']+)'\)").firstMatch(part);
      if (pathMatch != null) {
        final varMatch = RegExp(r'(\w+)\s+(\w+)').allMatches(part).last;
        if (varMatch.groupCount >= 2) {
          pathParams.add(varMatch.group(2)!);
          cleanParams.add('${varMatch.group(1)} ${varMatch.group(2)}');
        }
        continue;
      }
      
      // 检查 @Query
      final queryMatch = RegExp(r"@Query\('([^']+)'\)").firstMatch(part);
      if (queryMatch != null) {
        final varMatch = RegExp(r'(\w+)\s+(\w+)').allMatches(part).last;
        if (varMatch.groupCount >= 2) {
          queryParams.add((queryMatch.group(1)!, varMatch.group(2)!));
          cleanParams.add('${varMatch.group(1)} ${varMatch.group(2)}');
        }
        continue;
      }
      
      // 检查 @Body
      if (part.contains('@Body')) {
        final varMatch = RegExp(r'(\w+)\s+(\w+)').allMatches(part).last;
        if (varMatch.groupCount >= 2) {
          bodyParam = varMatch.group(2)!;
          cleanParams.add('${varMatch.group(1)} ${varMatch.group(2)}');
        }
        continue;
      }
    }

    // 处理方法路径
    var pathWithParams = path;
    for (final param in pathParams) {
      pathWithParams = pathWithParams.replaceFirst('{$param}', '\$${param}');
    }
    
    // 构建查询参数
    String queryParamsStr = '';
    if (queryParams.isNotEmpty) {
      final queryPairs = queryParams.map((q) => "'${q.$1}': ${q.$2}").join(', ');
      queryParamsStr = ', queryParameters: {$queryPairs}';
    }
    
    // 构建 body
    String bodyStr = '';
    if (bodyParam != null) {
      bodyStr = ', data: $bodyParam.toJson()';
    }
    
    // 构建返回
    String returnStr;
    if (returnType == 'void') {
      returnStr = 'return response.data';
    } else {
      returnStr = 'return $returnType.fromJson(response.data)';
    }
    
    final cleanParamsStr = cleanParams.join(', ');
    final methodCall = httpMethod.toLowerCase();
    
    return '''
  /// $name
  Future<$returnType> $name($cleanParamsStr) async {
    final response = await _dio.$methodCall('$pathWithParams'$queryParamsStr$bodyStr);
    $returnStr;
  }''';
  }
}
