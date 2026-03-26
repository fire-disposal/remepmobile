import os
import re

def convert_file(file_path):
    """将 retrofit 客户端文件转换为 Dio 客户端"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 提取类名
    class_match = re.search(r'abstract class (\w+)', content)
    if not class_match:
        return
    class_name = class_match.group(1)
    
    # 提取导入
    imports = re.findall(r"import '\.\./models/(.*?)';", content)
    
    # 提取方法
    methods = []
    method_pattern = r'@(GET|POST|PUT|DELETE|PATCH)\(\'([^\']+)\'\)\s+Future<(\w+)?>\s+(\w+)\(\{([^}]*)\}\)'
    for match in re.finditer(method_pattern, content, re.DOTALL):
        http_method = match.group(1)
        path = match.group(2)
        return_type = match.group(3) or 'void'
        method_name = match.group(4)
        params_str = match.group(5)
        
        # 解析参数
        params = []
        path_params = []
        query_params = []
        body_param = None
        
        for param in params_str.split(','):
            param = param.strip()
            if not param:
                continue
            
            # 检查 @Path
            path_match = re.search(r"@Path\('([^']+)'\)\s+required\s+(\w+)\s+(\w+)", param)
            if path_match:
                path_params.append(path_match.group(1))
                params.append(f'{path_match.group(2)} {path_match.group(3)}')
                continue
            
            # 检查 @Query
            query_match = re.search(r"@Query\('([^']+)'\)\s+(required\s+)?(\w+)\s+(\w+)", param)
            if query_match:
                query_params.append((query_match.group(1), query_match.group(3), query_match.group(4)))
                required = query_match.group(2) or ''
                params.append(f'{required}{query_match.group(3)} {query_match.group(4)}'.strip())
                continue
            
            # 检查 @Body
            body_match = re.search(r'@Body\(\)\s+(required\s+)?(\w+)\s+(\w+)', param)
            if body_match:
                body_param = (body_match.group(2), body_match.group(3))
                params.append(f'{body_match.group(2)} {body_match.group(3)}')
                continue
        
        methods.append({
            'http_method': http_method,
            'path': path,
            'return_type': return_type,
            'name': method_name,
            'params': params,
            'path_params': path_params,
            'query_params': query_params,
            'body_param': body_param,
        })
    
    # 生成 Dio 客户端代码
    dio_code = f'''// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:dio/dio.dart';
'''
    for imp in imports:
        dio_code += f"import '../models/{imp}';\n"
    
    dio_code += f'''
/// {class_name} - Dio 客户端
class {class_name} {{
  final Dio _dio;

  {class_name}(this._dio);
'''
    
    for method in methods:
        # 处理方法路径
        path = method['path']
        for param in method['path_params']:
            path = path.replace(f'{{{param}}}', f'${param}')
        
        # 构建查询参数
        query_str = ''
        if method['query_params']:
            query_pairs = [f"'{name}': {var_name}" for name, _, var_name in method['query_params']]
            query_str = f", queryParameters: {{{', '.join(query_pairs)}}}"
        
        # 构建 body
        body_str = ''
        if method['body_param']:
            body_str = f", data: {method['body_param'][1]}.toJson()"
        
        # 构建返回
        if method['return_type'] == 'void':
            return_str = ''
        else:
            return_str = f"return {method['return_type']}.fromJson("
            return_str_end = ")"
        
        # 生成方法
        params_str = ', '.join(method['params'])
        dio_code += f'''
  /// {method['name']}
  Future<{method['return_type']}> {method['name']}({params_str}) async {{
    final response = await _dio.{method['http_method'].lower()}('{path}'{query_str}{body_str});
    {return_str} response.data{return_str_end if method['return_type'] != 'void' else ''};
  }}
'''
    
    dio_code += '}\n'
    
    # 写回文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(dio_code)
    
    print(f'Converted: {file_path}')

def main():
    api_dir = 'api'
    for root, dirs, files in os.walk(api_dir):
        for file in files:
            if file.endswith('_client.dart') and 'rest_client' not in file:
                file_path = os.path.join(root, file)
                convert_file(file_path)

if __name__ == '__main__':
    main()
